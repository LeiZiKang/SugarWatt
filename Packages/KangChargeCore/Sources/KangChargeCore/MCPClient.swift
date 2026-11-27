import Foundation

public enum MCPError: LocalizedError, Sendable {
    case badURL
    case notConfigured
    case timeout
    case disconnected
    case http(Int)
    case server(String)
    case tool(String)
    case decoding(String)

    public var errorDescription: String? {
        let zh = Locale.kcPrefersChinese
        switch self {
        case .badURL:
            return zh ? "MCP 服务器地址无效" : "That MCP server address doesn't look right."
        case .notConfigured:
            return zh ? "还没有设置 MCP 地址，请打开 Kang Charge 完成连接" : "Open Kang Charge to connect your charger."
        case .timeout:
            return zh ? "请求超时，充电器没有及时响应" : "The charger didn't respond in time."
        case .disconnected:
            return zh ? "与 MCP 服务器的连接已断开" : "Lost the connection to the charger."
        case .http(let code):
            return zh ? "服务器返回 HTTP \(code)" : "The server returned HTTP \(code)."
        case .server(let message):
            return zh ? "服务器错误：\(message)" : "Server error: \(message)"
        case .tool(let message):
            return zh ? "设备返回错误：\(message)" : "The charger reported an error: \(message)"
        case .decoding(let what):
            return zh ? "无法解析返回数据（\(what)）" : "Couldn't read the charger's response (\(what))."
        }
    }
}

/// Minimal MCP client over the legacy HTTP+SSE transport:
/// GET the SSE stream → receive an `endpoint` event → POST JSON-RPC messages there,
/// responses arrive back on the SSE stream and are matched by id.
public final class MCPClient: @unchecked Sendable {
    public let sseURL: URL

    private let session: URLSession
    private let lock = NSLock()
    private var endpoint: URL?
    private var endpointWaiters: [CheckedContinuation<URL, Error>] = []
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var nextID = 1
    private var generation = 0
    private var streamTask: Task<Void, Never>?
    private var connectTask: Task<Void, Error>?

    public init(sseURL: URL) {
        self.sseURL = sseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 7 * 24 * 3600
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    deinit {
        streamTask?.cancel()
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    public func close() {
        withLock {
            streamTask?.cancel()
            streamTask = nil
            generation += 1
        }
        teardown(MCPError.disconnected)
    }

    // MARK: Public API

    /// Calls a tool and returns the concatenated text content as UTF-8 data.
    public func callTool(_ name: String, arguments: [String: Any] = [:], timeout: TimeInterval = 25, retry: Bool = true) async throws -> Data {
        let params: [String: Any] = ["name": name, "arguments": arguments]
        let result: [String: Any]
        do {
            result = try await request("tools/call", params: params, timeout: timeout)
        } catch let error where retry && Self.isConnectionError(error) {
            result = try await request("tools/call", params: params, timeout: timeout)
        }
        let texts = (result["content"] as? [[String: Any]])?.compactMap { $0["text"] as? String } ?? []
        let text = texts.joined()
        if (result["isError"] as? Bool) == true {
            throw MCPError.tool(text.isEmpty ? name : text)
        }
        return Data(text.utf8)
    }

    public func request(_ method: String, params: [String: Any]?, timeout: TimeInterval = 25) async throws -> [String: Any] {
        try await ensureReady()
        return try await send(method, params: params, timeout: timeout)
    }

    // MARK: Connection

    private func ensureReady() async throws {
        let task: Task<Void, Error> = withLock {
            if let existing = connectTask {
                return existing
            }
            let created = Task { try await self.establish() }
            connectTask = created
            return created
        }
        do {
            try await task.value
        } catch {
            withLock {
                if connectTask == task { connectTask = nil }
            }
            throw error
        }
    }

    private func establish() async throws {
        let gen: Int = withLock {
            generation += 1
            return generation
        }
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            withLock {
                endpointWaiters.append(continuation)
            }
            startStream(generation: gen)
            Task {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                self.failEndpointWaiters(MCPError.timeout, generation: gen)
            }
        }
        _ = try await send("initialize", params: [
            "protocolVersion": "2024-11-05",
            "capabilities": [String: Any](),
            "clientInfo": ["name": "KangCharge", "version": "1.1"],
        ], timeout: 20)
        try await notify("notifications/initialized")
    }

    private func startStream(generation gen: Int) {
        withLock {
            streamTask?.cancel()
            let url = sseURL
            let session = self.session
            streamTask = Task { [weak self] in
                var request = URLRequest(url: url)
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        throw MCPError.http(http.statusCode)
                    }
                    var event = "message"
                    for try await line in bytes.lines {
                        if line.hasPrefix("event:") {
                            event = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                            self?.handle(event: event, data: payload)
                            event = "message"
                        }
                    }
                    throw MCPError.disconnected
                } catch {
                    self?.streamEnded(generation: gen, error: error)
                }
            }
        }
    }

    private func handle(event: String, data: String) {
        if event == "endpoint" {
            guard let url = URL(string: data, relativeTo: sseURL)?.absoluteURL else { return }
            let waiters: [CheckedContinuation<URL, Error>] = withLock {
                endpoint = url
                let current = endpointWaiters
                endpointWaiters.removeAll()
                return current
            }
            waiters.forEach { $0.resume(returning: url) }
            return
        }
        let raw = Data(data.utf8)
        guard let object = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else { return }
        let id: Int?
        if let number = object["id"] as? NSNumber {
            id = number.intValue
        } else if let string = object["id"] as? String {
            id = Int(string)
        } else {
            id = nil
        }
        if let id { resolve(id, .success(raw)) }
    }

    private func streamEnded(generation gen: Int, error: Error) {
        let isCurrent = withLock { gen == generation }
        guard isCurrent else { return }
        teardown(error is CancellationError ? MCPError.disconnected : error)
    }

    private func teardown(_ error: Error) {
        let (waiters, calls): ([CheckedContinuation<URL, Error>], [Int: CheckedContinuation<Data, Error>]) = withLock {
            endpoint = nil
            connectTask = nil
            let w = endpointWaiters
            endpointWaiters.removeAll()
            let c = pending
            pending.removeAll()
            return (w, c)
        }
        waiters.forEach { $0.resume(throwing: error) }
        calls.values.forEach { $0.resume(throwing: MCPError.disconnected) }
    }

    private func failEndpointWaiters(_ error: Error, generation gen: Int) {
        let waiters: [CheckedContinuation<URL, Error>] = withLock {
            guard gen == generation else { return [] }
            let current = endpointWaiters
            endpointWaiters.removeAll()
            return current
        }
        waiters.forEach { $0.resume(throwing: error) }
    }

    // MARK: JSON-RPC

    private func send(_ method: String, params: [String: Any]?, timeout: TimeInterval) async throws -> [String: Any] {
        let (url, id): (URL, Int) = try withLock {
            guard let url = endpoint else { throw MCPError.disconnected }
            let id = nextID
            nextID += 1
            return (url, id)
        }

        var body: [String: Any] = ["jsonrpc": "2.0", "id": id, "method": method]
        if let params { body["params"] = params }
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let data: Data = try await withCheckedThrowingContinuation { continuation in
            withLock { pending[id] = continuation }
            Task {
                do {
                    try await self.post(bodyData, to: url)
                } catch {
                    self.resolve(id, .failure(error))
                }
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self.resolve(id, .failure(MCPError.timeout))
            }
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPError.decoding(method)
        }
        if let error = object["error"] as? [String: Any] {
            throw MCPError.server(error["message"] as? String ?? "Unknown error")
        }
        return object["result"] as? [String: Any] ?? [:]
    }

    private func notify(_ method: String) async throws {
        let url: URL = try withLock {
            guard let url = endpoint else { throw MCPError.disconnected }
            return url
        }
        let body = try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "method": method])
        try await post(body, to: url)
    }

    private func post(_ body: Data, to url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if [400, 404, 410].contains(http.statusCode) {
                withLock {
                    streamTask?.cancel()
                    streamTask = nil
                    generation += 1
                }
                teardown(MCPError.disconnected)
                throw MCPError.disconnected
            }
            throw MCPError.http(http.statusCode)
        }
    }

    private func resolve(_ id: Int, _ result: Result<Data, Error>) {
        let continuation: CheckedContinuation<Data, Error>? = withLock {
            pending.removeValue(forKey: id)
        }
        continuation?.resume(with: result)
    }

    private static func isConnectionError(_ error: Error) -> Bool {
        if case MCPError.disconnected = error { return true }
        return error is URLError
    }
}
