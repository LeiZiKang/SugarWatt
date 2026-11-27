import Foundation

/// Sample data shared across macOS, iOS, watchOS, previews, and screenshots.
public enum KCDemo {
    public static let basePower: [Int: Double] = [1: 4.8, 2: 61.4, 3: 18.2, 4: 0, 5: 6.1]

    public static func snapshot(date: Date = Date()) -> ChargerSnapshot {
        let zh = Locale.kcPrefersChinese
        let ports = [
            PortSnapshot(index: 1, name: "A", connector: "A", maxPower: 60, enabled: true, power: 4.8, voltage: 5.0, current: 0.96, protocolName: "Apple 2.4A", deviceName: "AirPods Pro", temperature: "cool", sessionChargeMwh: 2_400),
            PortSnapshot(index: 2, name: "C1", connector: "C", maxPower: 140, enabled: true, power: 61.4, voltage: 20.0, current: 3.07, protocolName: "PD Fixed 20V", deviceName: "MacBook Pro", temperature: "moderate", sessionChargeMwh: 41_800),
            PortSnapshot(index: 3, name: "C2", connector: "C", maxPower: 140, enabled: true, power: 18.2, voltage: 9.0, current: 2.02, protocolName: "PD PPS", deviceName: "iPhone 16 Pro", temperature: "cool", sessionChargeMwh: 13_200),
            PortSnapshot(index: 4, name: "C3", connector: "C", maxPower: 140, enabled: false, power: 0, voltage: 0, current: 0, protocolName: nil, deviceName: nil, temperature: "cool", sessionChargeMwh: 0),
            PortSnapshot(index: 5, name: "C4", connector: "C", maxPower: 140, enabled: true, power: 6.1, voltage: 5.1, current: 1.20, protocolName: "PD Fixed 5V", deviceName: "Apple Watch", temperature: "cool", sessionChargeMwh: 4_600),
        ]
        let history = (0..<90).map { i -> PowerPoint in
            let t = Double(i)
            return PowerPoint(
                date: date.addingTimeInterval((t - 90) * 60),
                watts: 78 + 14 * sin(t / 9) + 5 * sin(t / 2.7) + 8 * t / 90
            )
        }
        return ChargerSnapshot(
            deviceName: zh ? "书桌小电拼" : "Desk Charger",
            modelName: zh ? "小电拼 Mirror" : "CoCan Mirror",
            maxPower: 160,
            ports: ports,
            temperatureMode: 0,
            fetchedAt: date,
            history: history
        )
    }

    public static func tick(_ snapshot: ChargerSnapshot, date: Date = Date()) -> ChargerSnapshot {
        var next = snapshot
        let phase = date.timeIntervalSince1970 / 20
        for i in next.ports.indices where next.ports[i].enabled {
            let base = basePower[next.ports[i].index] ?? 0
            guard base > 0 else { continue }
            let wobble = 1 + 0.08 * sin(phase + Double(i) * 1.7)
            next.ports[i].power = (base * wobble * 10).rounded() / 10
            if next.ports[i].voltage > 0 {
                next.ports[i].current = next.ports[i].power / next.ports[i].voltage
            }
        }
        next.fetchedAt = date
        let recent = next.history.filter { date.timeIntervalSince($0.date) < 2 * 3600 }
        if recent.count < 20 { next.history = KCDemo.snapshot(date: date).history }
        next.history = SnapshotStore.appendingHistory(next.history, watts: next.totalPower, at: date)
        return next
    }

    /// Deterministic realistic daily energy ledger for demo mode, previews, and screenshots.
    public static func energySummary(weeks: Int = 16, endingAt endDate: Date = Date(), calendar: Calendar = .current) -> EnergySummary {
        let totalDays = max(1, min(weeks, 52)) * 7
        let start = calendar.startOfDay(for: endDate)
        var map: [String: Double] = [:]
        for offset in stride(from: -(totalDays - 1), through: 0, by: 1) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let idx = offset + totalDays
            let weekday = calendar.component(.weekday, from: day)
            let isWeekend = (weekday == 1 || weekday == 7)
            // Deterministic pseudo-random pattern with occasional idle days and heavy workdays.
            let wave = sin(Double(idx) * 0.41) * 0.5 + cos(Double(idx) * 1.13) * 0.5
            let rawWh: Double
            if offset == 0 {
                rawWh = 148 // Today in progress
            } else if idx % 19 == 0 {
                rawWh = 0 // Away from desk
            } else if isWeekend {
                rawWh = max(0, 65 + wave * 75)
            } else {
                rawWh = max(18, 175 + wave * 135)
            }
            if rawWh > 0 {
                map[EnergyLedger.dayKey(for: day, calendar: calendar)] = rawWh * 1000
            }
        }
        return EnergyLedger.buildSummary(from: map, weeks: weeks, endingAt: endDate, calendar: calendar)
    }

    public static func samplePDStatus() -> [Int: PDStatus] {
        [
            2: PDStatus(
                port: 2,
                pdRevision: "PD 3.1",
                ppsChargingSupported: true,
                requestEprModeCapable: true,
                requestPdoId: 4,
                operatingVoltage: 2000,
                operatingCurrent: 307,
                statusTemperature: "moderate",
                hasEmarker: true,
                cableIsActive: false,
                cableEprModeCapable: true,
                cableMaxVbusVoltage: "50 V",
                cableMaxVbusCurrent: "5 A",
                cableUsbHighestSpeed: "USB 2.0",
                cableLatency: "<10 ns",
                cableBrandZh: "Apple",
                cableBrandEn: "Apple",
                cableNameZh: "240W 编织线",
                cableNameEn: "240W Woven Cable",
                hasBattery: true,
                batteryPresentCapacity: 78,
                batteryDesignCapacity: 100,
                batteryLastFullChargeCapacity: 100,
                deviceNameZh: "MacBook Pro",
                deviceNameEn: "MacBook Pro"
            ),
            3: PDStatus(
                port: 3,
                pdRevision: "PD 3.0",
                ppsChargingSupported: true,
                requestEprModeCapable: false,
                requestPdoId: 3,
                operatingVoltage: 900,
                operatingCurrent: 202,
                statusTemperature: "cool",
                hasEmarker: true,
                cableIsActive: false,
                cableEprModeCapable: false,
                cableMaxVbusVoltage: "20 V",
                cableMaxVbusCurrent: "3 A",
                cableUsbHighestSpeed: "USB 2.0",
                cableBrandZh: "Apple",
                cableBrandEn: "Apple",
                cableNameZh: "60W USB-C 线",
                cableNameEn: "60W USB-C Cable",
                deviceNameZh: "iPhone 16 Pro",
                deviceNameEn: "iPhone 16 Pro"
            )
        ]
    }

    public static func energyAnalytics() -> EnergyAnalytics {
        let portShares: [PortEnergyShare] = [
            PortEnergyShare(portIndex: 2, name: "C1 · MacBook Pro", wattHours: 26_140, fraction: 0.58),
            PortEnergyShare(portIndex: 3, name: "C2 · iPhone 16 Pro", wattHours: 10_810, fraction: 0.24),
            PortEnergyShare(portIndex: 5, name: "C4 · Apple Watch", wattHours: 4_510, fraction: 0.10),
            PortEnergyShare(portIndex: 1, name: "USB-A · AirPods", wattHours: 3_600, fraction: 0.08),
        ]
        // Realistic desk-worker charging rhythm peaking around 15:00 (3 PM)
        let hourly: [Double] = [
            8, 6, 4, 3, 3, 5,
            12, 24, 48, 86, 118, 134,
            122, 146, 178, 214, 192, 165,
            132, 98, 76, 58, 36, 18
        ]
        // Mon...Sun in Wh/day average, peaking on Thursday
        let weekday: [Double] = [195, 224, 210, 268, 242, 148, 132]
        return EnergyAnalytics(
            portShares: portShares,
            hourlyWattHours: hourly,
            weekdayWattHours: weekday,
            totalWattHours: 45_060
        )
    }
}
