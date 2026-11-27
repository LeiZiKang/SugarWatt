import Foundation

public struct EnergyDay: Codable, Hashable, Identifiable, Sendable {
    public let dayKey: String // yyyy-MM-dd in local calendar
    public let date: Date
    public let energyMwh: Double

    public var id: String { dayKey }
    public var wattHours: Double { energyMwh / 1000 }

    public init(dayKey: String, date: Date, energyMwh: Double) {
        self.dayKey = dayKey
        self.date = date
        self.energyMwh = max(0, energyMwh)
    }

    /// 0...4 intensity bucket matching GitHub contribution heatmaps.
    public func level(maxWattHours: Double = 320) -> Int {
        guard wattHours >= 1 else { return 0 }
        let ratio = wattHours / max(maxWattHours, 40)
        switch ratio {
        case ..<0.20: return 1
        case ..<0.45: return 2
        case ..<0.75: return 3
        default: return 4
        }
    }
}

public struct EnergySummary: Hashable, Sendable {
    public let days: [EnergyDay]
    public let todayWattHours: Double
    public let last7DaysWattHours: Double
    public let totalWattHours: Double
    public let activeDays: Int
    public let currentStreak: Int
    public let peakWattHours: Double

    public init(days: [EnergyDay], todayKey: String) {
        self.days = days
        self.todayWattHours = days.first(where: { $0.dayKey == todayKey })?.wattHours ?? 0
        self.last7DaysWattHours = days.suffix(7).reduce(0) { $0 + $1.wattHours }
        self.totalWattHours = days.reduce(0) { $0 + $1.wattHours }
        self.activeDays = days.filter { $0.wattHours >= 1 }.count
        self.peakWattHours = days.map(\.wattHours).max() ?? 0

        var streak = 0
        for day in days.reversed() {
            if day.wattHours >= 1 {
                streak += 1
            } else if day.dayKey == todayKey {
                // Today hasn't accumulated energy yet; don't break yesterday's streak.
                continue
            } else {
                break
            }
        }
        self.currentStreak = streak
    }
}

public struct PortEnergyShare: Hashable, Identifiable, Sendable {
    public let portIndex: Int
    public let name: String
    public let wattHours: Double
    public let fraction: Double

    public var id: Int { portIndex }

    public init(portIndex: Int, name: String, wattHours: Double, fraction: Double) {
        self.portIndex = portIndex
        self.name = name
        self.wattHours = wattHours
        self.fraction = fraction
    }
}

public struct EnergyAnalytics: Hashable, Sendable {
    public let portShares: [PortEnergyShare]
    /// 24 buckets indexed 0...23 (local hour of day), in Wh.
    public let hourlyWattHours: [Double]
    /// 7 buckets indexed 0...6 (Monday = 0 ... Sunday = 6), in Wh.
    public let weekdayWattHours: [Double]
    public let totalWattHours: Double

    public var topPort: PortEnergyShare? { portShares.first }

    public var peakHour: Int? {
        guard let maxVal = hourlyWattHours.max(), maxVal > 0 else { return nil }
        return hourlyWattHours.firstIndex(of: maxVal)
    }

    public var peakWeekday: Int? {
        guard let maxVal = weekdayWattHours.max(), maxVal > 0 else { return nil }
        return weekdayWattHours.firstIndex(of: maxVal)
    }

    public init(
        portShares: [PortEnergyShare] = [],
        hourlyWattHours: [Double] = Array(repeating: 0, count: 24),
        weekdayWattHours: [Double] = Array(repeating: 0, count: 7),
        totalWattHours: Double = 0
    ) {
        self.portShares = portShares
        self.hourlyWattHours = hourlyWattHours.count == 24 ? hourlyWattHours : Array(repeating: 0, count: 24)
        self.weekdayWattHours = weekdayWattHours.count == 7 ? weekdayWattHours : Array(repeating: 0, count: 7)
        self.totalWattHours = totalWattHours
    }

    public static let empty = EnergyAnalytics()
}

/// Local + optional iCloud KVS daily energy accumulator.
/// Tracks hardware-reported `session_charge_mwh` deltas per `(port, sessionId)` so
/// both frequent macOS polling and periodic iOS widget refreshes build an accurate
/// daily usage calendar without needing any custom backend server.
public final class EnergyLedger: @unchecked Sendable {
    public static let shared = EnergyLedger()
    public static let didUpdateNotification = Notification.Name("KangCharge.EnergyLedgerDidUpdate")

    private struct PortCursor: Codable, Hashable {
        var sessionId: Int?
        var lastMwh: Double
        var updatedAt: Date
    }

    private struct StorePayload: Codable {
        var dailyMwh: [String: Double]
        var cursors: [Int: PortCursor]
        var portMwh: [Int: Double]?
        var hourMwh: [Int: Double]?
        var weekdayMwh: [Int: Double]?
    }

    private let defaults: UserDefaults
    private let storageKey: String
    private let cloudKey: String
    private let calendar: Calendar
    private let lock = NSLock()
    private var payload: StorePayload
    private var cloudStore: NSUbiquitousKeyValueStore?
    private var cloudObserver: NSObjectProtocol?

    public static let maxRetentionDays = 365

    public init(
        defaults: UserDefaults = AppConfig.defaults,
        storageKey: String = "energyLedger.v1",
        cloudKey: String = "kangcharge.energy.daily.v1",
        enableCloudSync: Bool = true,
        calendar: Calendar = .current
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.cloudKey = cloudKey
        self.calendar = calendar
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(StorePayload.self, from: data) {
            self.payload = decoded
        } else {
            self.payload = StorePayload(dailyMwh: [:], cursors: [:])
        }

        if enableCloudSync && Self.hasICloudKVSEntitlement() {
            let store = NSUbiquitousKeyValueStore.default
            self.cloudStore = store
            store.synchronize()
            mergeFromCloudLocked()
            cloudObserver = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: store,
                queue: nil
            ) { [weak self] _ in
                self?.pullFromCloud()
            }
        }
    }

    deinit {
        if let cloudObserver { NotificationCenter.default.removeObserver(cloudObserver) }
    }

    /// True only when the running app/extension binary is signed with iCloud KVS entitlement.
    public static func hasICloudKVSEntitlement() -> Bool {
        // Opt-in flag in Info.plist set only on targets signed with iCloud KVS capability.
        Bundle.main.object(forInfoDictionaryKey: "KCiCloudSyncAvailable") as? Bool == true
    }

    public var isCloudAvailable: Bool { cloudStore != nil }

    /// Records a batch of port readings and accumulates positive energy deltas into today's bucket.
    @discardableResult
    public func record(details: [PortDetail], at date: Date = Date()) -> Double {
        let dayKey = Self.dayKey(for: date, calendar: calendar)
        var addedMwh: Double = 0

        lock.lock()
        for detail in details {
            guard let currentMwh = detail.sessionChargeMwh, currentMwh.isFinite, currentMwh >= 0 else {
                continue
            }
            let delta: Double
            if let prev = payload.cursors[detail.port] {
                let sameSession: Bool
                if let prevSession = prev.sessionId, let newSession = detail.sessionId {
                    sameSession = (prevSession == newSession)
                } else {
                    // When sessionId is absent, treat monotonic increase within 12 hours as same session.
                    sameSession = currentMwh >= prev.lastMwh && date.timeIntervalSince(prev.updatedAt) < 12 * 3600
                }
                if sameSession {
                    delta = max(0, currentMwh - prev.lastMwh)
                } else {
                    delta = currentMwh
                }
            } else {
                // First time seeing this port: count its current session energy if non-zero.
                delta = currentMwh
            }

            if delta > 0 {
                payload.dailyMwh[dayKey, default: 0] += delta
                var byPort = payload.portMwh ?? [:]
                byPort[detail.port, default: 0] += delta
                payload.portMwh = byPort

                let hour = calendar.component(.hour, from: date)
                var byHour = payload.hourMwh ?? [:]
                byHour[hour, default: 0] += delta
                payload.hourMwh = byHour

                // Calendar.weekday: 1 = Sun, 2 = Mon ... 7 = Sat -> map to 0 = Mon ... 6 = Sun
                let rawWeekday = calendar.component(.weekday, from: date)
                let mondayBased = (rawWeekday + 5) % 7
                var byWeekday = payload.weekdayMwh ?? [:]
                byWeekday[mondayBased, default: 0] += delta
                payload.weekdayMwh = byWeekday

                addedMwh += delta
            }
            payload.cursors[detail.port] = PortCursor(
                sessionId: detail.sessionId,
                lastMwh: currentMwh,
                updatedAt: date
            )
        }

        if addedMwh > 0 {
            pruneLocked(relativeTo: date)
            saveLocked()
            pushToCloudLocked()
        } else {
            saveLocked()
        }
        lock.unlock()

        if addedMwh > 0 {
            NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
        }
        return addedMwh
    }

    /// Merges remote daily energy totals (e.g. from iCloud KVS) using monotonic max per day
    /// so Mac + iPhone monitoring the same charger never double-count the same day's energy.
    @discardableResult
    public func merge(remoteDailyMwh: [String: Double], referenceDate: Date = Date()) -> Bool {
        var changed = false
        lock.lock()
        for (dayKey, remoteVal) in remoteDailyMwh where remoteVal.isFinite && remoteVal > 0 {
            let localVal = payload.dailyMwh[dayKey] ?? 0
            if remoteVal > localVal + 0.1 {
                payload.dailyMwh[dayKey] = remoteVal
                changed = true
            }
        }
        if changed {
            pruneLocked(relativeTo: referenceDate)
            saveLocked()
        }
        lock.unlock()
        if changed {
            NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
        }
        return changed
    }

    public func pullFromCloud() {
        guard AppConfig.iCloudEnergySyncEnabled else { return }
        lock.lock()
        let changed = mergeFromCloudLocked()
        lock.unlock()
        if changed {
            NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
        }
    }

    public func pushToCloudNow() {
        lock.lock()
        pushToCloudLocked()
        lock.unlock()
    }

    public func dailyMap() -> [String: Double] {
        lock.lock()
        defer { lock.unlock() }
        return payload.dailyMwh
    }

    public func summary(weeks: Int = 16, endingAt endDate: Date = Date()) -> EnergySummary {
        let map = dailyMap()
        return Self.buildSummary(from: map, weeks: weeks, endingAt: endDate, calendar: calendar)
    }

    /// Returns per-port, per-hour, and per-weekday breakdowns accumulated from hardware deltas.
    public func analytics(portNames: [Int: String] = [:]) -> EnergyAnalytics {
        lock.lock()
        let portMap = payload.portMwh ?? [:]
        let hourMap = payload.hourMwh ?? [:]
        let weekdayMap = payload.weekdayMwh ?? [:]
        let totalDailyWh = payload.dailyMwh.values.reduce(0, +) / 1000
        lock.unlock()

        let defaultNames: [Int: String] = [1: "USB-A", 2: "C1", 3: "C2", 4: "C3", 5: "C4"]
        let totalPortWh = portMap.values.reduce(0, +) / 1000
        let shares: [PortEnergyShare] = portMap
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { (port, mwh) in
                let wh = mwh / 1000
                let label = portNames[port] ?? defaultNames[port] ?? "P\(port)"
                return PortEnergyShare(
                    portIndex: port,
                    name: label,
                    wattHours: wh,
                    fraction: totalPortWh > 0 ? wh / totalPortWh : 0
                )
            }

        let hourly = (0..<24).map { (hourMap[$0] ?? 0) / 1000 }
        let weekday = (0..<7).map { (weekdayMap[$0] ?? 0) / 1000 }

        return EnergyAnalytics(
            portShares: shares,
            hourlyWattHours: hourly,
            weekdayWattHours: weekday,
            totalWattHours: max(totalDailyWh, totalPortWh)
        )
    }

    public func reset() {
        lock.lock()
        payload = StorePayload(dailyMwh: [:], cursors: [:])
        defaults.removeObject(forKey: storageKey)
        if AppConfig.iCloudEnergySyncEnabled, let cloudStore {
            cloudStore.removeObject(forKey: cloudKey)
            cloudStore.synchronize()
        }
        lock.unlock()
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
    }

    // MARK: - Helpers

    public static func buildSummary(
        from dailyMwh: [String: Double],
        weeks: Int = 16,
        endingAt endDate: Date = Date(),
        calendar: Calendar = .current
    ) -> EnergySummary {
        let clampedWeeks = max(1, min(weeks, 52))
        let totalDays = clampedWeeks * 7
        let endStart = calendar.startOfDay(for: endDate)
        let todayKey = dayKey(for: endStart, calendar: calendar)

        var days: [EnergyDay] = []
        days.reserveCapacity(totalDays)
        for offset in stride(from: -(totalDays - 1), through: 0, by: 1) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: endStart) else { continue }
            let key = dayKey(for: date, calendar: calendar)
            days.append(EnergyDay(dayKey: key, date: date, energyMwh: dailyMwh[key] ?? 0))
        }
        return EnergySummary(days: days, todayKey: todayKey)
    }

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    private func pruneLocked(relativeTo date: Date) {
        guard let cutoff = calendar.date(byAdding: .day, value: -Self.maxRetentionDays, to: calendar.startOfDay(for: date)) else { return }
        let cutoffKey = Self.dayKey(for: cutoff, calendar: calendar)
        payload.dailyMwh = payload.dailyMwh.filter { $0.key >= cutoffKey }
    }

    private func saveLocked() {
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: storageKey)
        }
    }

    @discardableResult
    private func mergeFromCloudLocked() -> Bool {
        guard AppConfig.iCloudEnergySyncEnabled,
              let cloudStore,
              let dict = cloudStore.dictionary(forKey: cloudKey) as? [String: Double] else {
            return false
        }
        var changed = false
        for (key, value) in dict where value.isFinite && value > 0 {
            if value > (payload.dailyMwh[key] ?? 0) + 0.1 {
                payload.dailyMwh[key] = value
                changed = true
            }
        }
        if changed {
            pruneLocked(relativeTo: Date())
            saveLocked()
        }
        return changed
    }

    private func pushToCloudLocked() {
        guard AppConfig.iCloudEnergySyncEnabled, let cloudStore else { return }
        // Merge existing cloud values first so we never overwrite a higher remote day total.
        var merged = (cloudStore.dictionary(forKey: cloudKey) as? [String: Double]) ?? [:]
        for (key, value) in payload.dailyMwh {
            merged[key] = max(merged[key] ?? 0, value)
        }
        cloudStore.set(merged, forKey: cloudKey)
        cloudStore.synchronize()
    }
}
