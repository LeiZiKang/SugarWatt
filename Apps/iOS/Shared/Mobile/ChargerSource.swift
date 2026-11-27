import Foundation
import WidgetKit
import KangChargeCore

/// Shared data source for iOS, watchOS, widgets, and App Intents.
enum ChargerSource {
    static let demoKey = "demoMode.v1"

    static var isDemo: Bool {
        get { AppConfig.defaults.bool(forKey: demoKey) }
        set { AppConfig.defaults.set(newValue, forKey: demoKey) }
    }

    static var isConfigured: Bool { isDemo || AppConfig.serverURL != nil }

    static func fetch() async throws -> ChargerSnapshot {
        if isDemo {
            let snapshot = KCDemo.tick(SnapshotStore.load() ?? KCDemo.snapshot())
            SnapshotStore.save(snapshot)
            return snapshot
        }
        EnergyLedger.shared.pullFromCloud()
        let api = try ChargerAPI.current()
        return try await withTimeout(seconds: 20) { try await api.fetchSnapshot() }
    }

    static func currentEnergySummary(weeks: Int = 14) -> EnergySummary {
        if isDemo {
            return KCDemo.energySummary(weeks: weeks)
        }
        EnergyLedger.shared.pullFromCloud()
        return EnergyLedger.shared.summary(weeks: weeks)
    }

    static func setPort(_ index: Int, on: Bool) async throws {
        if !isDemo {
            try await ChargerAPI.current().setPorts([index], on: on)
        }
        if var snapshot = SnapshotStore.load(), let i = snapshot.ports.firstIndex(where: { $0.index == index }) {
            snapshot.ports[i].enabled = on
            if !on { snapshot.ports[i].power = 0 }
            if on, isDemo { snapshot.ports[i].power = KCDemo.basePower[index] ?? 0 }
            SnapshotStore.save(snapshot)
        }
    }

    static func setStrategy(_ strategy: ChargingStrategy) async throws {
        if isDemo { AppConfig.lastStrategy = strategy; return }
        try await ChargerAPI.current().setStrategy(strategy)
    }

    static func setTemperatureMode(_ mode: TemperatureMode) async throws {
        if !isDemo { try await ChargerAPI.current().setTemperatureMode(mode) }
        if var snapshot = SnapshotStore.load() {
            snapshot.temperatureMode = mode.rawValue
            SnapshotStore.save(snapshot)
        }
    }

    static func withTimeout<T: Sendable>(seconds: Double, _ body: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await body() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw MCPError.timeout
            }
            let value = try await group.next()!
            group.cancelAll()
            return value
        }
    }
}

/// Timeline entry shared by iOS and watchOS widgets.
struct ChargerEntry: TimelineEntry {
    enum State { case live, stale, needsSetup }
    var date: Date
    var snapshot: ChargerSnapshot
    var energySummary: EnergySummary
    var state: State
    var isDemo = false

    static let placeholder = ChargerEntry(
        date: .now,
        snapshot: KCDemo.snapshot(),
        energySummary: KCDemo.energySummary(weeks: 14),
        state: .live
    )

    static func load() async -> ChargerEntry {
        guard ChargerSource.isConfigured else {
            return ChargerEntry(
                date: .now,
                snapshot: KCDemo.snapshot(),
                energySummary: KCDemo.energySummary(weeks: 14),
                state: .needsSetup
            )
        }
        do {
            let snapshot = try await ChargerSource.fetch()
            return ChargerEntry(
                date: .now,
                snapshot: snapshot,
                energySummary: ChargerSource.currentEnergySummary(weeks: 14),
                state: .live,
                isDemo: ChargerSource.isDemo
            )
        } catch {
            return ChargerEntry(
                date: .now,
                snapshot: SnapshotStore.load() ?? KCDemo.snapshot(),
                energySummary: ChargerSource.currentEnergySummary(weeks: 14),
                state: .stale,
                isDemo: ChargerSource.isDemo
            )
        }
    }
}

func describe(_ error: Error) -> String {
    if let error = error as? MCPError { return error.localizedDescription }
    if let error = error as? URLError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return String(localized: "You're offline.")
        case .timedOut:
            return String(localized: "The charger didn't respond in time.")
        default: break
        }
    }
    return error.localizedDescription
}
