import Foundation

/// Result of parsing a bare MCP URL or natural-language share text copied from the CANDYSIGN app.
public struct MCPInputExtraction: Sendable, Equatable {
    public let url: URL
    public let suggestedNickname: String?
    public let extractedFromText: Bool

    public init(url: URL, suggestedNickname: String? = nil, extractedFromText: Bool = false) {
        self.url = url
        self.suggestedNickname = suggestedNickname
        self.extractedFromText = extractedFromText
    }
}

public enum AppConfig {
    /// App Group shared by the app and its widgets. Injected at build time via `KCAppGroup` in Info.plist.
    public static let appGroup: String? = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "KCAppGroup") as? String,
              !value.isEmpty, !value.contains("$("),
              value != Bundle.main.bundleIdentifier else { return nil }
        return value
    }()

    public static let widgetKind = "KangChargeWidget"
    public static let heatmapWidgetKind = "KangChargeHeatmapWidget"

    public static let defaults: UserDefaults = appGroup.flatMap { UserDefaults(suiteName: $0) } ?? .standard

    public enum Key {
        public static let serverURL = "serverURL"
        public static let deviceName = "deviceName"
        public static let snapshot = "snapshot.v1"
        public static let facts = "machineFacts.v1"
        public static let lastStrategy = "lastStrategy"
        public static let iCloudEnergySync = "iCloudEnergySync.v1"
    }

    /// Personal MCP SSE endpoint copied from the CANDYSIGN app. Stored locally only.
    public static var serverURL: URL? {
        #if os(macOS)
        return defaults.string(forKey: Key.serverURL).flatMap(validatedServerURL)
        #else
        return SecureStore.string(forKey: Key.serverURL).flatMap(validatedServerURL)
        #endif
    }

    public static func setServerURL(_ url: URL?) {
        #if os(macOS)
        defaults.set(url?.absoluteString, forKey: Key.serverURL)
        #else
        SecureStore.set(url?.absoluteString, forKey: Key.serverURL)
        #endif
    }

    /// Extracts the MCP server URL from either a bare URL or a full share snippet copied from the CANDYSIGN app.
    /// Automatically ignores documentation links such as `SKILL.md` and prioritizes `/sse` endpoints.
    public static func extractMCPInput(from raw: String) -> MCPInputExtraction? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let pattern = #"https?://[^\s`"'<>()\[\]{}「」『』《》，。；、]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        let matches = regex.matches(in: trimmed, range: nsRange)

        var candidates: [URL] = []
        let trailingPunctuation = CharacterSet(charactersIn: ".,;:!?`'\")]}。，；：")
        for match in matches {
            guard let range = Range(match.range, in: trimmed) else { continue }
            var token = String(trimmed[range])
            while let last = token.unicodeScalars.last, trailingPunctuation.contains(last) {
                token.unicodeScalars.removeLast()
            }
            guard let url = URL(string: token),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http",
                  let host = url.host, !host.isEmpty else { continue }
            if url.path.lowercased().hasSuffix(".md") { continue }
            candidates.append(url)
        }

        guard !candidates.isEmpty else { return nil }

        let chosen = candidates.first(where: {
            ($0.host?.lowercased().contains("thecandysign.com") ?? false) && $0.path.lowercased().hasSuffix("/sse")
        })
            ?? candidates.first(where: { $0.path.lowercased().hasSuffix("/sse") })
            ?? candidates.first!

        var nickname: String?
        let namePatterns = [
            #"名字是[「『"“]([^」』"”]{1,40})[」』"”]"#,
            #"name is ["“]([^"”]{1,40})["”]"#,
        ]
        for np in namePatterns {
            if let nr = try? NSRegularExpression(pattern: np, options: [.caseInsensitive]),
               let m = nr.firstMatch(in: trimmed, range: nsRange),
               m.numberOfRanges > 1,
               let r = Range(m.range(at: 1), in: trimmed) {
                let value = String(trimmed[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    nickname = value
                    break
                }
            }
        }

        return MCPInputExtraction(
            url: chosen,
            suggestedNickname: nickname,
            extractedFromText: trimmed != chosen.absoluteString
        )
    }

    public static func validatedServerURL(_ raw: String) -> URL? {
        extractMCPInput(from: raw)?.url
    }

    public static var deviceName: String {
        if let custom = customDeviceName { return custom }
        return SnapshotStore.loadFacts()?.localizedName ?? "CoCan"
    }

    public static var customDeviceName: String? {
        get { defaults.string(forKey: Key.deviceName).flatMap { $0.isEmpty ? nil : $0 } }
        set { defaults.set(newValue, forKey: Key.deviceName) }
    }

    public static var lastStrategy: ChargingStrategy? {
        get { defaults.object(forKey: Key.lastStrategy).flatMap { ($0 as? Int).flatMap(ChargingStrategy.init(rawValue:)) } }
        set { defaults.set(newValue?.rawValue, forKey: Key.lastStrategy) }
    }

    /// Opt-in iCloud Key-Value Store sync for daily energy history (defaults to true when iCloud entitlement is present).
    public static var iCloudEnergySyncEnabled: Bool {
        get {
            if defaults.object(forKey: Key.iCloudEnergySync) == nil { return true }
            return defaults.bool(forKey: Key.iCloudEnergySync)
        }
        set {
            defaults.set(newValue, forKey: Key.iCloudEnergySync)
        }
    }

    public static func resetDeviceData() {
        for key in [Key.snapshot, Key.facts, Key.lastStrategy] { defaults.removeObject(forKey: key) }
    }
}

public enum SnapshotStore {
    public static func load() -> ChargerSnapshot? {
        guard let data = AppConfig.defaults.data(forKey: AppConfig.Key.snapshot) else { return nil }
        return try? JSONDecoder().decode(ChargerSnapshot.self, from: data)
    }

    public static func save(_ snapshot: ChargerSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppConfig.defaults.set(data, forKey: AppConfig.Key.snapshot)
    }

    public static func loadFacts() -> MachineFacts? {
        guard let data = AppConfig.defaults.data(forKey: AppConfig.Key.facts) else { return nil }
        return try? JSONDecoder().decode(MachineFacts.self, from: data)
    }

    public static func saveFacts(_ facts: MachineFacts) {
        guard let data = try? JSONEncoder().encode(facts) else { return }
        AppConfig.defaults.set(data, forKey: AppConfig.Key.facts)
    }

    /// Appends a total-power sample, keeping roughly the last 2 hours at ≥30 s spacing.
    public static func appendingHistory(_ history: [PowerPoint], watts: Double, at date: Date) -> [PowerPoint] {
        var result = history.filter { date.timeIntervalSince($0.date) < 2 * 3600 }
        if let last = result.last, date.timeIntervalSince(last.date) < 30 {
            result[result.count - 1] = PowerPoint(date: last.date, watts: max(last.watts, watts))
        } else {
            result.append(PowerPoint(date: date, watts: watts))
        }
        return Array(result.suffix(240))
    }
}

/// Typed wrapper around the CANDYSIGN ionbridge MCP tools.
public final class ChargerAPI: @unchecked Sendable {
    public let client: MCPClient

    public init(url: URL) {
        client = MCPClient(sseURL: url)
    }

    private static let lock = NSLock()
    private static var cached: ChargerAPI?

    /// Process-wide instance bound to the currently configured server URL.
    public static func current() throws -> ChargerAPI {
        lock.lock()
        defer { lock.unlock() }
        guard let url = AppConfig.serverURL else {
            cached?.client.close()
            cached = nil
            throw MCPError.notConfigured
        }
        if let cached, cached.client.sseURL == url { return cached }
        cached?.client.close()
        let api = ChargerAPI(url: url)
        cached = api
        return api
    }

    private func decode<T: Decodable>(_ type: T.Type, _ tool: String, arguments: [String: Any] = [:], timeout: TimeInterval = 25) async throws -> T {
        let data = try await client.callTool(tool, arguments: arguments, timeout: timeout)
        do {
            return try JSONDecoder.snakeCase.decode(T.self, from: data)
        } catch {
            let text = String(data: data, encoding: .utf8) ?? ""
            if !text.hasPrefix("{") && !text.isEmpty { throw MCPError.tool(text) }
            throw MCPError.decoding(tool)
        }
    }

    private func perform(_ tool: String, arguments: [String: Any] = [:]) async throws {
        _ = try await client.callTool(tool, arguments: arguments, timeout: 30, retry: true)
    }

    // MARK: Reads

    public func machineFacts() async throws -> MachineFacts { try await decode(MachineFacts.self, "get_machine_facts") }
    public func deviceInfo() async throws -> DeviceInfo { try await decode(DeviceInfo.self, "get_device_info") }
    public func portDetails() async throws -> [PortDetail] { try await decode(PortDetailsResponse.self, "get_port_details").ports }
    public func chargingStatus() async throws -> ChargingStatus { try await decode(ChargingStatus.self, "get_charging_status") }
    public func temperatureMode() async throws -> TemperatureModeResponse { try await decode(TemperatureModeResponse.self, "get_temperature_mode") }
    public func displayConfig() async throws -> DisplayConfig { try await decode(DisplayConfig.self, "get_display_config") }
    public func pdStatus() async throws -> [PDStatus] { try await decode(PDStatusResponse.self, "get_port_pd_status", timeout: 40).ports }
    public func portStats(port: Int) async throws -> PortStatsResponse {
        try await decode(PortStatsResponse.self, "get_port_stats", arguments: ["port": port], timeout: 60)
    }

    // MARK: Controls

    public func setStrategy(_ strategy: ChargingStrategy) async throws {
        if strategy == .usbA {
            try await perform("set_usba_charging_mode")
        } else {
            try await perform("set_charging_strategy", arguments: ["strategy": strategy.rawValue])
        }
        AppConfig.lastStrategy = strategy
    }

    public func setTemperatureMode(_ mode: TemperatureMode) async throws {
        try await perform("set_temperature_mode", arguments: ["mode": mode.rawValue])
    }

    public func setPorts(_ ports: [Int], on: Bool) async throws {
        try await perform(on ? "turn_on_port" : "turn_off_port", arguments: ["ports": ports])
    }

    public func setPowerAllocation(_ watts: [Int]) async throws {
        try await perform("set_port_power_allocation", arguments: ["power_allocation": watts])
    }

    public func setDisplayLevel(_ level: DisplayLevel) async throws {
        try await perform("set_display_intensity", arguments: ["level": level.rawValue])
    }

    public func setStatusDisplayMode(_ mode: StatusDisplayMode) async throws {
        try await perform("set_status_display_mode", arguments: ["mode": mode.rawValue])
    }

    public func setIdleDisplay(_ display: IdleDisplay) async throws {
        try await perform("set_idle_display", arguments: ["idle_display": display.rawValue])
    }

    public func setHourlyChime(_ enabled: Bool) async throws {
        try await perform("set_hourly_chime", arguments: ["enabled": enabled])
    }

    // MARK: Snapshot

    public static func makeSnapshot(
        facts: MachineFacts,
        details: [PortDetail],
        status: ChargingStatus?,
        temperatureMode: Int?,
        previous: ChargerSnapshot?,
        date: Date = Date(),
        recordEnergy: Bool = true
    ) -> ChargerSnapshot {
        if recordEnergy {
            EnergyLedger.shared.record(details: details, at: date)
        }
        let ports = facts.ports.sorted { $0.index < $1.index }.map { port -> PortSnapshot in
            let detail = details.first { $0.port == port.index }
            let enabled = status?.isOn(port.index) ?? previous?.ports.first { $0.index == port.index }?.enabled ?? true
            return PortSnapshot(
                index: port.index,
                name: port.name,
                connector: port.connectorType ?? (port.name.hasPrefix("A") ? "A" : "C"),
                maxPower: port.power,
                enabled: enabled,
                power: enabled ? (detail?.power ?? 0) : 0,
                voltage: detail?.voltage ?? 0,
                current: detail?.current ?? 0,
                protocolName: detail?.fcProtocol,
                deviceName: detail?.deviceName,
                temperature: detail?.dieTemperature,
                sessionChargeMwh: detail?.sessionChargeMwh
            )
        }
        var snapshot = ChargerSnapshot(
            deviceName: AppConfig.deviceName,
            modelName: facts.localizedName,
            maxPower: facts.maxPowerBudget,
            ports: ports,
            temperatureMode: temperatureMode ?? previous?.temperatureMode,
            fetchedAt: date,
            history: previous?.history ?? []
        )
        snapshot.history = SnapshotStore.appendingHistory(snapshot.history, watts: snapshot.totalPower, at: date)
        return snapshot
    }

    /// Fetches a fresh snapshot (used by widgets and App Intents) and persists it.
    public func fetchSnapshot() async throws -> ChargerSnapshot {
        let facts: MachineFacts
        if let cachedFacts = SnapshotStore.loadFacts() {
            facts = cachedFacts
        } else {
            facts = (try? await machineFacts()) ?? .fallback
            SnapshotStore.saveFacts(facts)
        }
        async let detailsTask = portDetails()
        async let statusTask = chargingStatus()
        async let temperatureTask = temperatureMode()
        let details = try await detailsTask
        let status = try? await statusTask
        let temperature = try? await temperatureTask
        let snapshot = Self.makeSnapshot(
            facts: facts,
            details: details,
            status: status,
            temperatureMode: temperature?.mode,
            previous: SnapshotStore.load()
        )
        SnapshotStore.save(snapshot)
        return snapshot
    }
}
