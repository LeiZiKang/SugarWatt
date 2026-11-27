import SwiftUI
import KangChargeCore

/// Restrained Apple-native + hardware-inspired design tokens shared across macOS, iOS, watchOS, and widgets.
/// Palette distilled from the charger's industrial finish: warm ceramic off-white, anodized titanium gray,
/// and surgical vermilion-orange accents.
public enum KCStyle {
    /// Signature vermilion-orange inspired by the charger's recessed port tongues (#E84C24).
    public static let accent = Color(red: 0.91, green: 0.30, blue: 0.14)
    /// Restrained Apple green for active power delivery and online indicators.
    public static let charging = Color(red: 0.19, green: 0.78, blue: 0.35)
    /// Warm amber inspired by the hardware's dot-matrix display (#F2A31B).
    public static let caution = Color(red: 0.95, green: 0.64, blue: 0.11)
    public static let hot = Color(red: 0.92, green: 0.25, blue: 0.20)

    /// Warm ceramic off-white light canvas (#FAF9F6) & deep graphite dark canvas (#18181A).
    public static func canvasBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.095, green: 0.095, blue: 0.102)
            : Color(red: 0.980, green: 0.976, blue: 0.965)
    }

    /// Subtle warm ceramic surface for icons, tiles, and widgets (#F2F0EB light / #222225 dark).
    public static func surfaceTile(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.145, green: 0.145, blue: 0.155)
            : Color(red: 0.945, green: 0.937, blue: 0.918)
    }

    /// Elevated card surface sitting cleanly on top of `canvasBackground` (#FFFFFF light / #1D1D20 dark).
    public static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.118, green: 0.118, blue: 0.128)
            : Color.white
    }

    public static func portTint(for port: PortSnapshot) -> Color {
        if !port.enabled { return .secondary.opacity(0.45) }
        return port.isCharging ? charging : .secondary
    }

    public static func temperatureColor(_ raw: String?) -> Color {
        switch raw?.lowercased() {
        case "cool": return charging
        case "moderate": return caution
        case "warm": return hot
        default: return .secondary
        }
    }

    /// 5-step restrained heatmap intensity colors (level 0...4).
    public static func heatmapColor(level: Int, tint: Color = charging, colorScheme: ColorScheme) -> Color {
        switch level {
        case 0:
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.055)
        case 1:
            return tint.opacity(colorScheme == .dark ? 0.30 : 0.24)
        case 2:
            return tint.opacity(colorScheme == .dark ? 0.52 : 0.46)
        case 3:
            return tint.opacity(colorScheme == .dark ? 0.76 : 0.70)
        default:
            return tint
        }
    }
}

public enum KCFormat {
    /// "58.2" below 100 W, "140" at/above 100 W, "0" at zero.
    public static func watts(_ value: Double) -> String {
        if value >= 100 || value < 0.05 { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }

    public static func volts(_ value: Double) -> String {
        value >= 10 ? String(format: "%.1f V", value) : String(format: "%.2f V", value)
    }

    public static func amps(_ value: Double) -> String {
        String(format: "%.2f A", value)
    }

    public static func energy(wattHours wh: Double) -> String {
        if wh >= 1000 { return String(format: "%.2f kWh", wh / 1000) }
        if wh >= 100 { return String(format: "%.0f Wh", wh) }
        if wh >= 1 { return String(format: "%.1f Wh", wh) }
        return "0 Wh"
    }

    public static func energy(mWh: Double) -> String {
        if mWh < 1000 && mWh > 0 { return String(format: "%.0f mWh", mWh) }
        return energy(wattHours: mWh / 1000)
    }

    public static func protocolTag(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let upper = raw.uppercased()
        for tag in ["PPS", "EPR", "PD", "FCP", "SCP", "AFC"] where upper.contains(tag) { return tag }
        if upper.contains("QC") || upper.contains("QUICK") { return "QC" }
        if upper.contains("LEGACY") || upper.contains("BC") { return "BC 1.2" }
        if upper.contains("APPLE") { return "Apple" }
        return raw.split(separator: " ").first.map(String.init)
    }

    public static func portDisplayName(_ port: PortSnapshot) -> String {
        port.connector == "A" && port.name == "A" ? "USB-A" : port.name
    }

    public static func portBadgeName(_ port: PortSnapshot) -> String {
        port.connector == "A" ? "A" : port.name
    }
}

/// Maps connected device names and port states to restrained Apple SF Symbols across macOS, iOS, watchOS, and widgets.
public enum KCDeviceSymbol {
    public static func systemName(for port: PortSnapshot) -> String {
        if !port.isCharging { return "power" }
        let name = (port.deviceName ?? "").lowercased()
        if name.contains("macbook") || name.contains("laptop") || name.contains("thinkpad") {
            return "laptopcomputer"
        }
        if name.contains("iphone") || name.contains("phone") || name.contains("pixel") || name.contains("galaxy") {
            return "iphone"
        }
        if name.contains("ipad") || name.contains("tablet") {
            return "ipad"
        }
        if name.contains("watch") {
            return "applewatch"
        }
        if name.contains("airpods") || name.contains("buds") {
            return "airpodspro"
        }
        if name.contains("headphone") || name.contains("max") {
            return "headphones"
        }
        if name.contains("switch") || name.contains("steam") || name.contains("deck") {
            return "gamecontroller"
        }
        if name.contains("camera") {
            return "camera"
        }
        return "bolt.fill"
    }
}

/// Thin capsule progress bar for total load and per-port load.
public struct KCLoadBar: View {
    public var fraction: Double
    public var color: Color
    public var height: CGFloat

    public init(fraction: Double, color: Color = KCStyle.accent, height: CGFloat = 6) {
        self.fraction = fraction
        self.color = color
        self.height = height
    }

    public var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(color)
                    .frame(width: clamped > 0 ? max(height, proxy.size.width * clamped) : 0)
            }
        }
        .frame(height: height)
    }
}
