import Foundation

public extension Locale {
    static var kcPrefersChinese: Bool {
        if let preferred = Bundle.main.preferredLocalizations.first {
            return preferred.hasPrefix("zh")
        }
        return Locale.preferredLanguages.first?.hasPrefix("zh") == true
    }
}

// MARK: - Raw MCP payloads

public struct MachineFacts: Codable, Hashable, Sendable {
    public struct Port: Codable, Hashable, Sendable {
        public var index: Int
        public var name: String
        public var connectorType: String?
        public var power: Double

        public init(index: Int, name: String, connectorType: String? = nil, power: Double) {
            self.index = index
            self.name = name
            self.connectorType = connectorType
            self.power = power
        }
    }

    public var productFamily: String?
    public var brandEn: String?
    public var brandZh: String?
    public var friendlyNameEn: String?
    public var friendlyNameZh: String?
    public var maxPowerBudget: Double
    public var ports: [Port]

    public init(
        productFamily: String?,
        brandEn: String?,
        brandZh: String?,
        friendlyNameEn: String?,
        friendlyNameZh: String?,
        maxPowerBudget: Double,
        ports: [Port]
    ) {
        self.productFamily = productFamily
        self.brandEn = brandEn
        self.brandZh = brandZh
        self.friendlyNameEn = friendlyNameEn
        self.friendlyNameZh = friendlyNameZh
        self.maxPowerBudget = maxPowerBudget
        self.ports = ports
    }

    public static let fallback = MachineFacts(
        productFamily: "CP-02S", brandEn: "CANDYSIGN", brandZh: "制糖工厂",
        friendlyNameEn: "CoCan Mirror", friendlyNameZh: "小电拼 Mirror",
        maxPowerBudget: 160,
        ports: [
            Port(index: 1, name: "A", connectorType: "A", power: 60),
            Port(index: 2, name: "C1", connectorType: "C", power: 140),
            Port(index: 3, name: "C2", connectorType: "C", power: 140),
            Port(index: 4, name: "C3", connectorType: "C", power: 140),
            Port(index: 5, name: "C4", connectorType: "C", power: 140),
        ]
    )

    public var supportsExtendedDisplay: Bool {
        (productFamily ?? "").uppercased().replacingOccurrences(of: "-", with: "").hasPrefix("CP02S")
    }

    public func port(_ index: Int) -> Port? { ports.first { $0.index == index } }

    public var localizedName: String {
        (Locale.kcPrefersChinese ? friendlyNameZh ?? friendlyNameEn : friendlyNameEn ?? friendlyNameZh) ?? "CoCan"
    }

    public var localizedBrand: String {
        (Locale.kcPrefersChinese ? brandZh ?? brandEn : brandEn ?? brandZh) ?? "CANDYSIGN"
    }
}

public struct PortDetail: Codable, Hashable, Identifiable, Sendable {
    public var port: Int
    public var connected: Bool?
    public var dieTemperature: String?
    public var fcProtocol: String?
    public var ioutMa: Double?
    public var voutMv: Double?
    public var vinMv: Double?
    public var sessionChargeMwh: Double?
    public var sessionId: Int?
    public var deviceBrandEn: String?
    public var deviceBrandZh: String?
    public var deviceNameEn: String?
    public var deviceNameZh: String?

    public init(
        port: Int,
        connected: Bool? = nil,
        dieTemperature: String? = nil,
        fcProtocol: String? = nil,
        ioutMa: Double? = nil,
        voutMv: Double? = nil,
        vinMv: Double? = nil,
        sessionChargeMwh: Double? = nil,
        sessionId: Int? = nil,
        deviceBrandEn: String? = nil,
        deviceBrandZh: String? = nil,
        deviceNameEn: String? = nil,
        deviceNameZh: String? = nil
    ) {
        self.port = port
        self.connected = connected
        self.dieTemperature = dieTemperature
        self.fcProtocol = fcProtocol
        self.ioutMa = ioutMa
        self.voutMv = voutMv
        self.vinMv = vinMv
        self.sessionChargeMwh = sessionChargeMwh
        self.sessionId = sessionId
        self.deviceBrandEn = deviceBrandEn
        self.deviceBrandZh = deviceBrandZh
        self.deviceNameEn = deviceNameEn
        self.deviceNameZh = deviceNameZh
    }

    public var id: Int { port }
    public var voltage: Double { (voutMv ?? 0) / 1000 }
    public var current: Double { (ioutMa ?? 0) / 1000 }
    public var power: Double { (voutMv ?? 0) * (ioutMa ?? 0) / 1_000_000 }
    public var deviceName: String? {
        Locale.kcPrefersChinese ? (deviceNameZh ?? deviceNameEn) : (deviceNameEn ?? deviceNameZh)
    }
}

public struct PortDetailsResponse: Codable, Sendable {
    public var ports: [PortDetail]
    public init(ports: [PortDetail]) { self.ports = ports }
}

public struct ChargingStatus: Codable, Hashable, Sendable {
    public var statusBitmask: Int
    public init(statusBitmask: Int) { self.statusBitmask = statusBitmask }
    public func isOn(_ port: Int) -> Bool { statusBitmask & (1 << (port - 1)) != 0 }
}

public struct TemperatureModeResponse: Codable, Hashable, Sendable {
    public var mode: Int
    public var modeName: String?
    public init(mode: Int, modeName: String? = nil) {
        self.mode = mode
        self.modeName = modeName
    }
}

public struct DisplayConfig: Codable, Hashable, Sendable {
    public var level: String?
    public var displayMode: String?
    public var idleDisplay: String?
    public var hourlyChime: Bool?

    public init(level: String? = nil, displayMode: String? = nil, idleDisplay: String? = nil, hourlyChime: Bool? = nil) {
        self.level = level
        self.displayMode = displayMode
        self.idleDisplay = idleDisplay
        self.hourlyChime = hourlyChime
    }
}

public struct DeviceInfo: Codable, Hashable, Sendable {
    public var appVersion: String?
    public var fpgaVersion: String?
    public var model: String?
    public var psn: String?
    public var rssi: Int?
    public var ssid: String?
    public var channel: Int?
    public var bssid: String?

    public init(
        appVersion: String? = nil,
        fpgaVersion: String? = nil,
        model: String? = nil,
        psn: String? = nil,
        rssi: Int? = nil,
        ssid: String? = nil,
        channel: Int? = nil,
        bssid: String? = nil
    ) {
        self.appVersion = appVersion
        self.fpgaVersion = fpgaVersion
        self.model = model
        self.psn = psn
        self.rssi = rssi
        self.ssid = ssid
        self.channel = channel
        self.bssid = bssid
    }
}

public struct PDStatus: Codable, Hashable, Identifiable, Sendable {
    public var port: Int
    public var pdRevision: String?
    public var ppsChargingSupported: Bool?
    public var requestEprModeCapable: Bool?
    public var requestPdoId: Int?
    public var operatingVoltage: Double?
    public var operatingCurrent: Double?
    public var statusTemperature: String?
    public var hasEmarker: Bool?
    public var cableIsActive: Bool?
    public var cableEprModeCapable: Bool?
    public var cableMaxVbusVoltage: String?
    public var cableMaxVbusCurrent: String?
    public var cableUsbHighestSpeed: String?
    public var cableLatency: String?
    public var cableBrandZh: String?
    public var cableBrandEn: String?
    public var cableNameZh: String?
    public var cableNameEn: String?
    public var hasBattery: Bool?
    public var batteryPresentCapacity: Double?
    public var batteryDesignCapacity: Double?
    public var batteryLastFullChargeCapacity: Double?
    public var deviceNameZh: String?
    public var deviceNameEn: String?
    public var sinkMaximumPdp: Double?
    public var sinkOperationalPdp: Double?

    /// Device battery fraction (0...1) when reported over USB-PD Battery Status.
    public var batteryFraction: Double? {
        guard hasBattery == true,
              let present = batteryPresentCapacity,
              let full = batteryLastFullChargeCapacity ?? batteryDesignCapacity,
              full > 0, present.isFinite, full.isFinite else { return nil }
        return min(max(present / full, 0), 1)
    }

    public init(
        port: Int,
        pdRevision: String? = nil,
        ppsChargingSupported: Bool? = nil,
        requestEprModeCapable: Bool? = nil,
        requestPdoId: Int? = nil,
        operatingVoltage: Double? = nil,
        operatingCurrent: Double? = nil,
        statusTemperature: String? = nil,
        hasEmarker: Bool? = nil,
        cableIsActive: Bool? = nil,
        cableEprModeCapable: Bool? = nil,
        cableMaxVbusVoltage: String? = nil,
        cableMaxVbusCurrent: String? = nil,
        cableUsbHighestSpeed: String? = nil,
        cableLatency: String? = nil,
        cableBrandZh: String? = nil,
        cableBrandEn: String? = nil,
        cableNameZh: String? = nil,
        cableNameEn: String? = nil,
        hasBattery: Bool? = nil,
        batteryPresentCapacity: Double? = nil,
        batteryDesignCapacity: Double? = nil,
        batteryLastFullChargeCapacity: Double? = nil,
        deviceNameZh: String? = nil,
        deviceNameEn: String? = nil,
        sinkMaximumPdp: Double? = nil,
        sinkOperationalPdp: Double? = nil
    ) {
        self.port = port
        self.pdRevision = pdRevision
        self.ppsChargingSupported = ppsChargingSupported
        self.requestEprModeCapable = requestEprModeCapable
        self.requestPdoId = requestPdoId
        self.operatingVoltage = operatingVoltage
        self.operatingCurrent = operatingCurrent
        self.statusTemperature = statusTemperature
        self.hasEmarker = hasEmarker
        self.cableIsActive = cableIsActive
        self.cableEprModeCapable = cableEprModeCapable
        self.cableMaxVbusVoltage = cableMaxVbusVoltage
        self.cableMaxVbusCurrent = cableMaxVbusCurrent
        self.cableUsbHighestSpeed = cableUsbHighestSpeed
        self.cableLatency = cableLatency
        self.cableBrandZh = cableBrandZh
        self.cableBrandEn = cableBrandEn
        self.cableNameZh = cableNameZh
        self.cableNameEn = cableNameEn
        self.hasBattery = hasBattery
        self.batteryPresentCapacity = batteryPresentCapacity
        self.batteryDesignCapacity = batteryDesignCapacity
        self.batteryLastFullChargeCapacity = batteryLastFullChargeCapacity
        self.deviceNameZh = deviceNameZh
        self.deviceNameEn = deviceNameEn
        self.sinkMaximumPdp = sinkMaximumPdp
        self.sinkOperationalPdp = sinkOperationalPdp
    }

    public var id: Int { port }
    /// operating_voltage is reported in 10 mV units, operating_current in 10 mA units.
    public var requestedVoltage: Double? { operatingVoltage.flatMap { $0 > 0 ? $0 / 100 : nil } }
    public var requestedCurrent: Double? { operatingCurrent.flatMap { $0 > 0 ? $0 / 100 : nil } }
    public var cableName: String? {
        let name = Locale.kcPrefersChinese ? (cableNameZh ?? cableNameEn) : (cableNameEn ?? cableNameZh)
        let brand = Locale.kcPrefersChinese ? (cableBrandZh ?? cableBrandEn) : (cableBrandEn ?? cableBrandZh)
        if let name, let brand, name != brand { return "\(brand) \(name)" }
        return name ?? brand
    }
}

public struct PDStatusResponse: Codable, Sendable {
    public var ports: [PDStatus]
    public init(ports: [PDStatus]) { self.ports = ports }
}

public struct PortStatSample: Codable, Hashable, Sendable {
    public var currentMa: Double
    public var powerMw: Double
    public var voltageMv: Double

    public init(currentMa: Double, powerMw: Double, voltageMv: Double) {
        self.currentMa = currentMa
        self.powerMw = powerMw
        self.voltageMv = voltageMv
    }
}

public struct PortStatsResponse: Codable, Sendable {
    public var count: Int?
    public var port: Int?
    public var samples: [PortStatSample]

    public init(count: Int? = nil, port: Int? = nil, samples: [PortStatSample]) {
        self.count = count
        self.port = port
        self.samples = samples
    }
}

// MARK: - Control enums

public enum ChargingStrategy: Int, CaseIterable, Codable, Identifiable, Sendable {
    case fast = 0
    case slow = 1
    case usbA = 6
    case highPerformance = 7
    case singlePort = 8

    public var id: Int { rawValue }

    public var localizedName: String {
        let zh = Locale.kcPrefersChinese
        switch self {
        case .fast: return zh ? "自由流" : "Smart"
        case .slow: return zh ? "睡眠充" : "Sleep"
        case .usbA: return zh ? "小家电" : "Small Appliance"
        case .highPerformance: return zh ? "无线损" : "Performance"
        case .singlePort: return zh ? "独享 C1" : "C1 Only"
        }
    }

    public var localizedSummary: String {
        let zh = Locale.kcPrefersChinese
        switch self {
        case .fast:
            return zh ? "多设备按需定供，不断连、无分配，日常首选。" : "Power follows each device dynamically. Best for everyday use."
        case .slow:
            return zh ? "每个端口温和输出，安静低温，适合夜间。" : "Gentle output on every port. Cool and quiet overnight."
        case .usbA:
            return zh ? "C4 模拟 USB-A 兼容小风扇、台灯，切换将断电重连。" : "C4 behaves like a USB-A port for low-draw accessories. Ports reconnect when switching."
        case .highPerformance:
            return zh ? "最大化充电效率，适合紧急补电。" : "Maximum charging efficiency for a quick top-up."
        case .singlePort:
            return zh ? "仅 C1 输出最高 140 W，其他端口会被关闭。" : "Only C1 delivers power, up to 140 W. Other ports turn off."
        }
    }

    public var symbol: String {
        switch self {
        case .fast: return "bolt.fill"
        case .slow: return "moon.stars.fill"
        case .usbA: return "fan.fill"
        case .highPerformance: return "gauge.with.dots.needle.100percent"
        case .singlePort: return "1.circle.fill"
        }
    }

    public var needsConfirmation: Bool { self == .usbA || self == .singlePort }
}

public enum TemperatureMode: Int, CaseIterable, Identifiable, Sendable {
    case power = 0
    case temperature = 1

    public var id: Int { rawValue }

    public var localizedName: String {
        let zh = Locale.kcPrefersChinese
        return self == .power ? (zh ? "功率优先" : "Power First") : (zh ? "温度优先" : "Cool First")
    }

    public var localizedDetail: String {
        let zh = Locale.kcPrefersChinese
        return self == .power
            ? (zh ? "允许更高温度，换取更强输出" : "Higher thermal ceiling for sustained full power.")
            : (zh ? "主动温控，保持机身凉爽" : "Proactive thermal throttling to keep the charger cool.")
    }

    public var symbol: String { self == .power ? "flame.fill" : "snowflake" }
}

/// Raw values match the CANDYSIGN MCP protocol strings.
public enum DisplayLevel: String, CaseIterable, Identifiable, Sendable {
    case off = "关", low = "低", medium = "中", high = "高"
    public var id: String { rawValue }

    public var localizedName: String {
        if Locale.kcPrefersChinese { return rawValue }
        switch self {
        case .off: return "Off"
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        }
    }
}

public enum StatusDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case animation = "待机动画优先"
    case power = "功率显示优先"
    public var id: String { rawValue }

    public var localizedName: String {
        if Locale.kcPrefersChinese { return self == .animation ? "动画优先" : "功率优先" }
        return self == .animation ? "Animation" : "Power"
    }
}

public enum IdleDisplay: String, CaseIterable, Identifiable, Sendable {
    case meteor = "流星", petals = "落花", life = "康威的生命游戏", clock = "时间"
    public var id: String { rawValue }

    public var localizedName: String {
        if Locale.kcPrefersChinese { return self == .life ? "生命游戏" : rawValue }
        switch self {
        case .meteor: return "Meteor"
        case .petals: return "Petals"
        case .life: return "Life"
        case .clock: return "Clock"
        }
    }

    public var symbol: String {
        switch self {
        case .meteor: return "sparkles"
        case .petals: return "leaf.fill"
        case .life: return "square.grid.3x3.fill"
        case .clock: return "clock.fill"
        }
    }
}

public enum PortTemperature {
    public static func localizedLabel(_ raw: String?) -> String? {
        let zh = Locale.kcPrefersChinese
        switch raw?.lowercased() {
        case "cool": return zh ? "凉爽" : "Cool"
        case "moderate": return zh ? "温和" : "Warm"
        case "warm": return zh ? "偏热" : "Hot"
        case .some(let other) where !other.isEmpty: return other
        default: return nil
        }
    }
}

// MARK: - Snapshot shared with widgets

public struct PortSnapshot: Codable, Hashable, Identifiable, Sendable {
    public var index: Int
    public var name: String
    public var connector: String
    public var maxPower: Double
    public var enabled: Bool
    public var power: Double
    public var voltage: Double
    public var current: Double
    public var protocolName: String?
    public var deviceName: String?
    public var temperature: String?
    public var sessionChargeMwh: Double?

    public init(
        index: Int,
        name: String,
        connector: String,
        maxPower: Double,
        enabled: Bool,
        power: Double,
        voltage: Double,
        current: Double,
        protocolName: String? = nil,
        deviceName: String? = nil,
        temperature: String? = nil,
        sessionChargeMwh: Double? = nil
    ) {
        self.index = index
        self.name = name
        self.connector = connector
        self.maxPower = maxPower
        self.enabled = enabled
        self.power = power
        self.voltage = voltage
        self.current = current
        self.protocolName = protocolName
        self.deviceName = deviceName
        self.temperature = temperature
        self.sessionChargeMwh = sessionChargeMwh
    }

    public var id: Int { index }
    public var isCharging: Bool { enabled && power >= 0.5 }
}

public struct PowerPoint: Codable, Hashable, Sendable {
    public var date: Date
    public var watts: Double

    public init(date: Date, watts: Double) {
        self.date = date
        self.watts = watts
    }
}

public struct ChargerSnapshot: Codable, Hashable, Sendable {
    public var deviceName: String
    public var modelName: String
    public var maxPower: Double
    public var ports: [PortSnapshot]
    public var temperatureMode: Int?
    public var fetchedAt: Date
    public var history: [PowerPoint] = []

    public init(
        deviceName: String,
        modelName: String,
        maxPower: Double,
        ports: [PortSnapshot],
        temperatureMode: Int? = nil,
        fetchedAt: Date,
        history: [PowerPoint] = []
    ) {
        self.deviceName = deviceName
        self.modelName = modelName
        self.maxPower = maxPower
        self.ports = ports
        self.temperatureMode = temperatureMode
        self.fetchedAt = fetchedAt
        self.history = history
    }

    public var totalPower: Double { ports.filter(\.enabled).reduce(0) { $0 + $1.power } }
    public var chargingCount: Int { ports.filter(\.isCharging).count }
    public var enabledCount: Int { ports.filter(\.enabled).count }
    public var sessionEnergyMwh: Double { ports.compactMap(\.sessionChargeMwh).reduce(0, +) }
}

public extension JSONDecoder {
    static let snakeCase: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
