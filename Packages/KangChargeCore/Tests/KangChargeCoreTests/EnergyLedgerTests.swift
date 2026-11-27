import XCTest
@testable import KangChargeCore

final class EnergyLedgerTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suite = "KangChargeCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testSameSessionAccumulatesDeltaOnly() {
        let defaults = makeDefaults()
        let ledger = EnergyLedger(defaults: defaults, enableCloudSync: false)
        let now = Date(timeIntervalSince1970: 1_764_150_000)

        let added1 = ledger.record(details: [PortDetail(port: 2, sessionChargeMwh: 10_000, sessionId: 42)], at: now)
        XCTAssertEqual(added1, 10_000, accuracy: 0.01)

        let added2 = ledger.record(details: [PortDetail(port: 2, sessionChargeMwh: 16_500, sessionId: 42)], at: now.addingTimeInterval(60))
        XCTAssertEqual(added2, 6_500, accuracy: 0.01)

        let dayKey = EnergyLedger.dayKey(for: now)
        XCTAssertEqual(ledger.dailyMap()[dayKey] ?? 0, 16_500, accuracy: 0.01)
    }

    func testNewSessionAddsFullSessionEnergy() {
        let defaults = makeDefaults()
        let ledger = EnergyLedger(defaults: defaults, enableCloudSync: false)
        let now = Date(timeIntervalSince1970: 1_764_150_000)

        _ = ledger.record(details: [PortDetail(port: 2, sessionChargeMwh: 20_000, sessionId: 1)], at: now)
        _ = ledger.record(details: [PortDetail(port: 2, sessionChargeMwh: 8_000, sessionId: 2)], at: now.addingTimeInterval(300))

        let dayKey = EnergyLedger.dayKey(for: now)
        XCTAssertEqual(ledger.dailyMap()[dayKey] ?? 0, 28_000, accuracy: 0.01)
    }

    func testCloudMergeUsesMonotonicMaxWithoutDoubleCounting() {
        let defaults = makeDefaults()
        let ledger = EnergyLedger(defaults: defaults, enableCloudSync: false)
        let now = Date(timeIntervalSince1970: 1_764_150_000)
        let dayKey = EnergyLedger.dayKey(for: now)

        _ = ledger.record(details: [PortDetail(port: 2, sessionChargeMwh: 30_000, sessionId: 1)], at: now)

        // Smaller remote value must not reduce local total.
        XCTAssertFalse(ledger.merge(remoteDailyMwh: [dayKey: 25_000], referenceDate: now))
        XCTAssertEqual(ledger.dailyMap()[dayKey] ?? 0, 30_000, accuracy: 0.01)

        // Larger remote value (e.g. Mac 8s polling) upgrades local total without summing.
        XCTAssertTrue(ledger.merge(remoteDailyMwh: [dayKey: 55_000], referenceDate: now))
        XCTAssertEqual(ledger.dailyMap()[dayKey] ?? 0, 55_000, accuracy: 0.01)
    }

    func testSummaryComputesStreakAndLevels() {
        let calendar = Calendar(identifier: .gregorian)
        let end = Date(timeIntervalSince1970: 1_764_150_000)
        let d0 = EnergyLedger.dayKey(for: end, calendar: calendar)
        let d1 = EnergyLedger.dayKey(for: calendar.date(byAdding: .day, value: -1, to: end)!, calendar: calendar)
        let d2 = EnergyLedger.dayKey(for: calendar.date(byAdding: .day, value: -2, to: end)!, calendar: calendar)

        let summary = EnergyLedger.buildSummary(from: [d0: 120_000, d1: 240_000, d2: 60_000], weeks: 4, endingAt: end, calendar: calendar)
        XCTAssertEqual(summary.days.count, 28)
        XCTAssertEqual(summary.todayWattHours, 120, accuracy: 0.01)
        XCTAssertEqual(summary.currentStreak, 3)
        XCTAssertEqual(summary.activeDays, 3)
    }

    func testExtractMCPURLFromCandySignParagraph() {
        let sample = """
        现在安装控制「AI 小电拼 Mirror」的技能：阅读 `https://mcp.thecandysign.com/0000000000000000/SKILL.md`。这台小电拼的名字是「Desk Charger」。MCP 服务器的地址是 `https://mcp.thecandysign.com/0000000000000000/deadbeef/sse`。
        """
        let extracted = AppConfig.extractMCPInput(from: sample)
        XCTAssertEqual(extracted?.url.absoluteString, "https://mcp.thecandysign.com/0000000000000000/deadbeef/sse")
        XCTAssertEqual(extracted?.suggestedNickname, "Desk Charger")
        XCTAssertEqual(extracted?.extractedFromText, true)
    }

    func testExtractMCPURLIgnoresSkillDocOnly() {
        let onlyDoc = "阅读 `https://mcp.thecandysign.com/0000000000000000/SKILL.md`。"
        XCTAssertNil(AppConfig.extractMCPInput(from: onlyDoc))
        XCTAssertNil(AppConfig.validatedServerURL(onlyDoc))
    }

    func testExtractMCPURLHandlesBareAddress() {
        let bare = "  https://mcp.thecandysign.com/0000000000000000/deadbeef/sse  "
        let extracted = AppConfig.extractMCPInput(from: bare)
        XCTAssertEqual(extracted?.url.absoluteString, "https://mcp.thecandysign.com/0000000000000000/deadbeef/sse")
        XCTAssertEqual(extracted?.extractedFromText, false)
    }
}
