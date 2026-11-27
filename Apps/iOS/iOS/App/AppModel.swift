import SwiftUI
import WidgetKit
import KangChargeCore

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshot = SnapshotStore.load()
    @Published var energySummary: EnergySummary = ChargerSource.currentEnergySummary(weeks: 14)
    @Published var energyAnalytics: EnergyAnalytics = EnergyLedger.shared.analytics()
    @Published var pdStatus: [Int: PDStatus] = [:]
    @Published var isConfigured: Bool = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-kcDemo") {
            ChargerSource.isDemo = true
            let demo = KCDemo.snapshot()
            SnapshotStore.save(demo)
            AppConfig.lastStrategy = .fast
        }
        #endif
        return ChargerSource.isConfigured
    }()
    @Published var isOnline = ChargerSource.isDemo
    @Published var lastError: String?
    @Published var busyPorts: Set<Int> = []
    @Published var strategy = AppConfig.lastStrategy
    @Published var thermal = TemperatureMode(rawValue: SnapshotStore.load()?.temperatureMode ?? 0) ?? .power
    @Published var toast: String?
    @Published var connecting = false
    @Published var controlling = false

    private var polling: Task<Void, Never>?
    private var lastReload = Date.distantPast
    private var generation = 0
    private var fetching = false
    private var fetchTask: Task<ChargerSnapshot, Error>?
    private var toastTask: Task<Void, Never>?
    private var ledgerObserver: NSObjectProtocol?

    init(previewDemo: Bool = false) {
        if previewDemo || ChargerSource.isDemo {
            snapshot = previewDemo ? KCDemo.snapshot() : (SnapshotStore.load() ?? KCDemo.snapshot())
            energySummary = KCDemo.energySummary(weeks: 14)
            energyAnalytics = KCDemo.energyAnalytics()
            pdStatus = KCDemo.samplePDStatus()
            if previewDemo {
                isConfigured = true
                isOnline = true
                strategy = .fast
                thermal = .power
                return
            }
        }
        ledgerObserver = NotificationCenter.default.addObserver(
            forName: EnergyLedger.didUpdateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !ChargerSource.isDemo else { return }
                self.energySummary = ChargerSource.currentEnergySummary(weeks: 14)
                self.energyAnalytics = EnergyLedger.shared.analytics()
            }
        }
    }

    deinit {
        if let ledgerObserver { NotificationCenter.default.removeObserver(ledgerObserver) }
    }

    func start() {
        WatchSync.shared.push()
        guard polling == nil, isConfigured else { return }
        polling = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                do { try await Task.sleep(for: .seconds(3)) } catch { break }
            }
        }
    }

    func stop() {
        polling?.cancel()
        polling = nil
    }

    private func reload(force: Bool = false) {
        if force || Date().timeIntervalSince(lastReload) >= 60 {
            WidgetCenter.shared.reloadAllTimelines()
            lastReload = .now
        }
    }

    private func failed(_ error: Error) {
        let message: String
        switch error {
        case MCPError.server, MCPError.tool, is URLError:
            message = String(localized: "Couldn't connect to the charger. Check the address and try again.")
        default:
            message = describe(error)
        }
        lastError = message
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    func refresh() async {
        guard isConfigured, !fetching, busyPorts.isEmpty, !controlling else { return }
        fetching = true
        defer { fetching = false; fetchTask = nil }
        let epoch = generation
        do {
            let task = Task { try await ChargerSource.fetch() }
            fetchTask = task
            let fresh = try await task.value
            guard epoch == generation, !Task.isCancelled else { return }
            guard busyPorts.isEmpty, !controlling else { return }
            snapshot = fresh
            energySummary = ChargerSource.currentEnergySummary(weeks: 14)
            isOnline = true
            lastError = nil
            strategy = AppConfig.lastStrategy
            thermal = TemperatureMode(rawValue: fresh.temperatureMode ?? 0) ?? .power
            reload()
        } catch {
            guard epoch == generation, !Task.isCancelled else { return }
            isOnline = false
            failed(error)
        }
    }

    func loadPDStatusIfNeeded() async {
        if ChargerSource.isDemo {
            pdStatus = KCDemo.samplePDStatus()
            return
        }
        guard let api = try? ChargerAPI.current() else { return }
        if let list = try? await api.pdStatus() {
            pdStatus = Dictionary(list.map { ($0.port, $0) }, uniquingKeysWith: { $1 })
        }
    }

    func setPort(_ index: Int, on: Bool) async {
        guard !busyPorts.contains(index), let i = snapshot?.ports.firstIndex(where: { $0.index == index }) else { return }
        let previous = snapshot!.ports[i]
        busyPorts.insert(index)
        _ = try? await fetchTask?.value
        snapshot?.ports[i].enabled = on
        if !on { snapshot?.ports[i].power = 0 }
        defer { busyPorts.remove(index); reload(force: true) }
        do {
            try await ChargerSource.setPort(index, on: on)
            if let saved = SnapshotStore.load()?.ports.first(where: { $0.index == index }) {
                snapshot?.ports[i] = saved
            }
        } catch {
            snapshot?.ports[i] = previous
            failed(error)
        }
    }

    func setStrategy(_ value: ChargingStrategy) async {
        guard !controlling else { return }
        controlling = true
        _ = try? await fetchTask?.value
        defer { controlling = false; reload(force: true) }
        do {
            try await ChargerSource.setStrategy(value)
            strategy = value
        } catch {
            failed(error)
        }
    }

    func setThermal(_ value: TemperatureMode) async {
        guard !controlling else { return }
        controlling = true
        _ = try? await fetchTask?.value
        defer { controlling = false; reload(force: true) }
        do {
            try await ChargerSource.setTemperatureMode(value)
            thermal = value
        } catch {
            failed(error)
        }
    }

    func connect(urlString: String, nickname: String) async {
        guard !connecting else { return }
        connecting = true
        lastError = nil
        defer { connecting = false }
        guard let url = AppConfig.validatedServerURL(urlString) else {
            failed(MCPError.badURL)
            return
        }
        let probe = ChargerAPI(url: url)
        defer { probe.client.close() }
        do {
            let facts = try await ChargerSource.withTimeout(seconds: 20) { try await probe.machineFacts() }
            if AppConfig.serverURL != url || ChargerSource.isDemo {
                AppConfig.resetDeviceData()
                snapshot = nil
            }
            AppConfig.setServerURL(url)
            guard AppConfig.serverURL == url else { throw MCPError.notConfigured }
            AppConfig.customDeviceName = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            SnapshotStore.saveFacts(facts)
            ChargerSource.isDemo = false
            isConfigured = true
            strategy = AppConfig.lastStrategy
            energySummary = ChargerSource.currentEnergySummary(weeks: 14)
            start()
            reload(force: true)
            WatchSync.shared.push()
        } catch {
            failed(error)
        }
    }

    func startDemo() {
        stop()
        generation += 1
        AppConfig.resetDeviceData()
        ChargerSource.isDemo = true
        snapshot = KCDemo.snapshot()
        SnapshotStore.save(snapshot!)
        energySummary = KCDemo.energySummary(weeks: 14)
        energyAnalytics = KCDemo.energyAnalytics()
        pdStatus = KCDemo.samplePDStatus()
        AppConfig.lastStrategy = .fast
        isConfigured = true
        isOnline = true
        lastError = nil
        strategy = .fast
        thermal = .power
        reload(force: true)
        start()
        WatchSync.shared.push()
    }

    func rename(_ name: String) {
        AppConfig.customDeviceName = name
        snapshot?.deviceName = AppConfig.deviceName
        if let snapshot { SnapshotStore.save(snapshot) }
        reload(force: true)
        WatchSync.shared.push()
    }

    func resetEnergyHistory() {
        EnergyLedger.shared.reset()
        energySummary = ChargerSource.currentEnergySummary(weeks: 14)
        reload(force: true)
    }

    func disconnect() async {
        stop()
        generation += 1
        _ = try? await fetchTask?.value
        if !ChargerSource.isDemo { (try? ChargerAPI.current())?.client.close() }
        AppConfig.setServerURL(nil)
        ChargerSource.isDemo = false
        AppConfig.resetDeviceData()
        AppConfig.customDeviceName = nil
        snapshot = nil
        pdStatus = [:]
        isConfigured = false
        isOnline = false
        lastError = nil
        toast = nil
        strategy = nil
        thermal = .power
        reload(force: true)
        WatchSync.shared.push()
    }
}
