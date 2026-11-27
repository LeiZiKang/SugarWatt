import Foundation

/// A single fun, human-relatable equivalent for electrical energy (e.g. smartphone charges, EV km).
/// Supports static JSON hot-updating from a lightweight CDN endpoint with a bundled offline fallback.
public struct EnergyEquivalentRule: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let symbol: String
    public let kwhPerUnit: Double
    public let titleEn: String
    public let titleZh: String
    public let unitEn: String
    public let unitZh: String
    public let minKwh: Double?
    public let maxKwh: Double?

    public init(
        id: String,
        symbol: String,
        kwhPerUnit: Double,
        titleEn: String,
        titleZh: String,
        unitEn: String,
        unitZh: String,
        minKwh: Double? = nil,
        maxKwh: Double? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.kwhPerUnit = kwhPerUnit
        self.titleEn = titleEn
        self.titleZh = titleZh
        self.unitEn = unitEn
        self.unitZh = unitZh
        self.minKwh = minKwh
        self.maxKwh = maxKwh
    }

    public var localizedTitle: String { Locale.kcPrefersChinese ? titleZh : titleEn }
    public var localizedUnit: String { Locale.kcPrefersChinese ? unitZh : unitEn }
}

public struct ComputedEnergyEquivalent: Hashable, Identifiable, Sendable {
    public let id: String
    public let symbol: String
    public let formattedAmount: String
    public let unit: String
    public let title: String

    public init(id: String, symbol: String, formattedAmount: String, unit: String, title: String) {
        self.id = id
        self.symbol = symbol
        self.formattedAmount = formattedAmount
        self.unit = unit
        self.title = title
    }
}

/// Manages energy-equivalent conversion rules with an offline bundled fallback
/// and optional read-only static JSON hot-update (zero user data is ever sent).
public enum EnergyEquivalentsCatalog {
    /// Static read-only CDN endpoint hosted on the SugarWatt site (Cloudflare Pages).
    /// Returns a JSON array of `EnergyEquivalentRule` objects.
    public static let remoteURL = URL(string: "https://sugarwatt.levicraft.app/api/equivalents.json")!
    private static let cacheKey = "sugarwatt.equivalents.cache.v1"

    /// Curated, scientifically grounded offline fallback catalog.
    public static let bundledRules: [EnergyEquivalentRule] = [
        EnergyEquivalentRule(
            id: "iphone_charge",
            symbol: "iphone",
            kwhPerUnit: 0.017,
            titleEn: "iPhone 16 Pro charges",
            titleZh: "台 iPhone 充满电",
            unitEn: "charges",
            unitZh: "次",
            minKwh: 0.005,
            maxKwh: 25
        ),
        EnergyEquivalentRule(
            id: "espresso",
            symbol: "cup.and.saucer.fill",
            kwhPerUnit: 0.025,
            titleEn: "Cups of espresso brewed",
            titleZh: "杯意式浓缩咖啡",
            unitEn: "cups",
            unitZh: "杯",
            minKwh: 0.01,
            maxKwh: 40
        ),
        EnergyEquivalentRule(
            id: "macbook_charge",
            symbol: "laptopcomputer",
            kwhPerUnit: 0.070,
            titleEn: "MacBook Pro full charges",
            titleZh: "次 MacBook Pro 满充",
            unitEn: "charges",
            unitZh: "次",
            minKwh: 0.05,
            maxKwh: nil
        ),
        EnergyEquivalentRule(
            id: "kettle_boil",
            symbol: "flame.fill",
            kwhPerUnit: 0.11,
            titleEn: "1L kettles boiled",
            titleZh: "壶 1L 烧开的热水",
            unitEn: "kettles",
            unitZh: "壶",
            minKwh: 0.10,
            maxKwh: nil
        ),
        EnergyEquivalentRule(
            id: "ev_km",
            symbol: "car.fill",
            kwhPerUnit: 0.145,
            titleEn: "EV highway range",
            titleZh: "电动车续航里程",
            unitEn: "km",
            unitZh: "公里",
            minKwh: 0.50,
            maxKwh: nil
        ),
        EnergyEquivalentRule(
            id: "laundry",
            symbol: "washer.fill",
            kwhPerUnit: 0.85,
            titleEn: "Loads of laundry",
            titleZh: "桶滚筒洗衣机清洗",
            unitEn: "loads",
            unitZh: "次",
            minKwh: 2.0,
            maxKwh: nil
        ),
    ]

    public static func activeRules() -> [EnergyEquivalentRule] {
        if let data = AppConfig.defaults.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([EnergyEquivalentRule].self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        return bundledRules
    }

    /// Fetches the latest static JSON rules from the CDN (no user metrics are transmitted).
    /// Applies strict size and schema bounds so malformed remote payloads can never break the UI.
    public static func refreshFromRemoteIfAvailable() async {
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  data.count <= 65_536 else { return }
            let decoded = try JSONDecoder().decode([EnergyEquivalentRule].self, from: data)
            let sanitized = decoded.prefix(32).filter { rule in
                rule.kwhPerUnit.isFinite && rule.kwhPerUnit > 0.0001 && rule.kwhPerUnit < 10_000
                    && !rule.id.isEmpty && rule.id.count <= 64
                    && !rule.symbol.isEmpty && rule.symbol.count <= 64
                    && rule.titleEn.count <= 80 && rule.titleZh.count <= 80
            }
            guard !sanitized.isEmpty else { return }
            if let encoded = try? JSONEncoder().encode(Array(sanitized)) {
                AppConfig.defaults.set(encoded, forKey: cacheKey)
            }
        } catch {
            // Silently fall back to cached or bundled rules.
        }
    }

    /// Picks up to `limit` relatable equivalents scaled to the user's total accumulated energy.
    public static func equivalents(forTotalWattHours totalWh: Double, limit: Int = 3) -> [ComputedEnergyEquivalent] {
        let kwh = max(0, totalWh / 1000)
        guard kwh > 0.001 else { return [] }

        let rules = activeRules()
        let matched = rules.filter { rule in
            let aboveMin = rule.minKwh.map { kwh >= $0 } ?? true
            let belowMax = rule.maxKwh.map { kwh <= $0 } ?? true
            return aboveMin && belowMax && rule.kwhPerUnit > 0
        }

        let pool = matched.count >= limit ? matched : rules.filter { $0.kwhPerUnit > 0 }
        // Prefer larger-scale items when total kWh is large, smaller items when total kWh is small
        let ordered = kwh >= 5 ? pool.reversed() : pool
        return ordered.prefix(limit).map { rule in
            let count = kwh / rule.kwhPerUnit
            let formatted: String
            if count >= 100 {
                formatted = String(format: "%.0f", count)
            } else if count >= 10 {
                formatted = String(format: "%.1f", count)
            } else {
                formatted = String(format: "%.1f", max(0.1, count))
            }
            return ComputedEnergyEquivalent(
                id: rule.id,
                symbol: rule.symbol,
                formattedAmount: formatted,
                unit: rule.localizedUnit,
                title: rule.localizedTitle
            )
        }
    }
}
