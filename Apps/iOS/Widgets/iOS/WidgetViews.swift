import SwiftUI
import WidgetKit
import AppIntents
import KangChargeCore
import KangChargeUI

struct PowerWidgetView: View {
    let entry: ChargerEntry
    var overrideFamily: WidgetFamily? = nil
    @Environment(\.widgetFamily) private var envFamily
    @Environment(\.colorScheme) private var colorScheme

    private var family: WidgetFamily { overrideFamily ?? envFamily }
    private var snapshot: ChargerSnapshot { entry.snapshot }
    private var stale: Bool { entry.state == .stale }
    private var topPort: PortSnapshot? { snapshot.ports.filter(\.isCharging).max(by: { $0.power < $1.power }) }
    private var loadFraction: Double { snapshot.maxPower > 0 ? min(max(snapshot.totalPower / snapshot.maxPower, 0), 1) : 0 }

    var body: some View {
        Group {
            if entry.state == .needsSetup {
                VStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.title3)
                        .foregroundStyle(KCStyle.accent)
                        .widgetAccentable()
                    Text("Open SugarWatt to connect")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                switch family {
                case .accessoryCircular: circular
                case .accessoryRectangular: rectangular
                case .accessoryInline:
                    if stale {
                        Text("\(Int(snapshot.totalPower.rounded())) W · \(snapshot.chargingCount) charging · \(snapshot.fetchedAt, style: .relative)")
                    } else {
                        Text("\(Int(snapshot.totalPower.rounded())) W · \(snapshot.chargingCount) charging")
                    }
                case .systemMedium: medium
                case .systemLarge: large
                default: small
                }
            }
        }
        .opacity(stale ? 0.65 : 1)
        .containerBackground(for: .widget) {
            KCStyle.canvasBackground(for: colorScheme)
        }
        .widgetURL(URL(string: "kangcharge://home"))
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(KCStyle.accent)
                .widgetAccentable()
            Text(snapshot.deviceName)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }

    private var status: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(stale ? Color.secondary : KCStyle.charging)
                .frame(width: 5, height: 5)
            if stale {
                Text(snapshot.fetchedAt, style: .relative)
            } else {
                Text("Live").foregroundStyle(KCStyle.charging)
            }
        }
        .font(.caption2.weight(.medium))
        .lineLimit(1)
    }

    // MARK: - Small (Circular Power Ring + Wattage)

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                header
                Spacer(minLength: 2)
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.09), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: loadFraction)
                        .stroke(KCStyle.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int((loadFraction * 100).rounded()))%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(KCFormat.watts(snapshot.totalPower))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .widgetAccentable()
                        Text("W")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("of \(Int(snapshot.maxPower))W")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
            HStack {
                Text("\(snapshot.chargingCount) charging")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                status
            }
        }
    }

    // MARK: - Medium (Left Ring + Right 5-Port LED Meters)

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                header
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    ZStack {
                        Circle().stroke(Color.primary.opacity(0.09), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: loadFraction)
                            .stroke(KCStyle.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int((loadFraction * 100).rounded()))%")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(KCFormat.watts(snapshot.totalPower))
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text("W").font(.caption2).foregroundStyle(.secondary)
                        }
                        Text("\(snapshot.chargingCount) charging")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                status
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 7) {
                ForEach(snapshot.ports) { port in
                    HStack(spacing: 6) {
                        Image(systemName: KCDeviceSymbol.systemName(for: port))
                            .font(.system(size: 10))
                            .foregroundStyle(port.isCharging ? .primary : .tertiary)
                            .frame(width: 14)
                        Text(KCFormat.portBadgeName(port))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(port.isCharging ? .primary : .tertiary)
                            .frame(width: 20, alignment: .leading)
                        PowerPressureMeter(
                            watts: port.isCharging ? port.power : 0,
                            maxWatts: port.maxPower,
                            segments: 5,
                            segmentWidth: 5,
                            segmentHeight: 5,
                            animated: false
                        )
                        Spacer(minLength: 2)
                        Text(port.isCharging ? "\(KCFormat.watts(port.power))W" : "—")
                            .font(.caption2.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(port.isCharging ? .primary : .tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Large (Ring + Sparkline + Interactive 5-Port Rows)

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                header
                Spacer()
                status
                Button(intent: RefreshIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.09), lineWidth: 5.5)
                    Circle()
                        .trim(from: 0, to: loadFraction)
                        .stroke(KCStyle.accent, style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int((loadFraction * 100).rounded()))%")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(KCFormat.watts(snapshot.totalPower))
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                        Text("W").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("\(snapshot.chargingCount) charging · Today \(KCFormat.energy(wattHours: entry.energySummary.todayWattHours))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 4)
                Sparkline(values: snapshot.history.suffix(60).map(\.watts))
                    .frame(width: 96, height: 36)
            }

            Divider().opacity(0.5)

            VStack(spacing: 0) {
                ForEach(snapshot.ports) { port in
                    HStack(spacing: 9) {
                        Circle()
                            .fill(KCStyle.surfaceTile(for: colorScheme))
                            .frame(width: 26, height: 26)
                            .overlay {
                                Image(systemName: KCDeviceSymbol.systemName(for: port))
                                    .font(.system(size: 11))
                                    .foregroundStyle(port.isCharging ? .primary : .tertiary)
                            }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(port.deviceName ?? KCFormat.portDisplayName(port))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(port.isCharging ? .primary : .secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(port.isCharging ? "\(KCFormat.watts(port.power)) W" : "—")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(port.isCharging ? .primary : .tertiary)
                            PowerPressureMeter(
                                watts: port.isCharging ? port.power : 0,
                                maxWatts: port.maxPower,
                                segments: 6,
                                segmentWidth: 4.5,
                                segmentHeight: 4.5,
                                animated: false
                            )
                        }

                        if port.isCharging {
                            Button(intent: SetPortIntent(port: port.index, isOn: false)) {
                                PortSwitch(isOn: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(intent: SetPortIntent(port: port.index, isOn: true)) {
                                Text("Idle")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 34, alignment: .trailing)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4.5)
                    if port.index != snapshot.ports.last?.index {
                        Divider().opacity(0.4).padding(.leading, 35)
                    }
                }
            }
        }
    }

    // MARK: - Lock Screen Accessories

    private var circular: some View {
        Gauge(value: min(max(snapshot.totalPower, 0), max(snapshot.maxPower, 1)), in: 0...max(snapshot.maxPower, 1)) {
            Image(systemName: "bolt.fill")
        } currentValueLabel: {
            Text("\(Int(snapshot.totalPower.rounded()))").monospacedDigit()
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("⚡︎ \(KCFormat.watts(snapshot.totalPower)) W")
                .font(.headline)
                .monospacedDigit()
                .widgetAccentable()
            if let topPort {
                Text("\(snapshot.chargingCount) charging · \(topPort.deviceName ?? topPort.name) \(Int(topPort.power.rounded())) W")
                    .font(.caption)
                    .lineLimit(1)
            } else {
                Text("\(snapshot.chargingCount) charging")
                    .font(.caption)
            }
        }
    }
}

// MARK: - Daily Energy Heatmap Widget

struct EnergyHeatmapWidgetView: View {
    let entry: ChargerEntry
    var overrideFamily: WidgetFamily? = nil
    @Environment(\.widgetFamily) private var envFamily
    @Environment(\.colorScheme) private var colorScheme
    private var family: WidgetFamily { overrideFamily ?? envFamily }

    var body: some View {
        Group {
            if entry.state == .needsSetup {
                VStack(spacing: 6) {
                    Image(systemName: "bolt.fill").widgetAccentable()
                    Text("Open SugarWatt to connect").font(.caption)
                }
            } else if family == .systemLarge {
                large
            } else {
                medium
            }
        }
        .containerBackground(for: .widget) {
            KCStyle.canvasBackground(for: colorScheme)
        }
        .widgetURL(URL(string: "kangcharge://home"))
    }

    private var medium: some View {
        let trimmed = EnergySummary(days: Array(entry.energySummary.days.suffix(15 * 7)), todayKey: entry.energySummary.days.last?.dayKey ?? "")
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Daily Energy", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(KCFormat.energy(wattHours: trimmed.todayWattHours))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(KCStyle.charging)
            }

            EnergyHeatmapView(
                summary: trimmed,
                tint: KCStyle.charging,
                cellSpacing: 2.5,
                cornerRadius: 2.5,
                interactive: false,
                showLegend: false,
                showHeader: false,
                showAxisLabels: false
            )

            HStack {
                Text("7d \(KCFormat.energy(wattHours: trimmed.last7DaysWattHours))")
                Spacer()
                Text("Total \(KCFormat.energy(wattHours: trimmed.totalWattHours))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    private var large: some View {
        let trimmed = EnergySummary(days: Array(entry.energySummary.days.suffix(15 * 7)), todayKey: entry.energySummary.days.last?.dayKey ?? "")
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Energy").font(.headline)
                    Text(entry.snapshot.deviceName).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(KCFormat.energy(wattHours: trimmed.todayWattHours))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(KCStyle.charging)
                    Text("Today").font(.caption2).foregroundStyle(.secondary)
                }
            }

            EnergyHeatmapView(
                summary: trimmed,
                tint: KCStyle.charging,
                cellSpacing: 3,
                cornerRadius: 3,
                interactive: false,
                showLegend: true,
                showHeader: false,
                showAxisLabels: false
            )

            Divider().opacity(0.5)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last 7 Days").font(.caption2).foregroundStyle(.secondary)
                    Text(KCFormat.energy(wattHours: trimmed.last7DaysWattHours)).font(.callout.weight(.semibold)).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Peak Day").font(.caption2).foregroundStyle(.secondary)
                    Text(KCFormat.energy(wattHours: trimmed.peakWattHours)).font(.callout.weight(.semibold)).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Streak").font(.caption2).foregroundStyle(.secondary)
                    Text("\(trimmed.currentStreak)d").font(.callout.weight(.semibold)).monospacedDigit()
                }
            }
        }
    }
}

struct Sparkline: View {
    var values: [Double]

    var body: some View {
        GeometryReader { proxy in
            let points = normalized(in: proxy.size)
            if points.count > 1 {
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: proxy.size.height))
                        points.forEach { path.addLine(to: $0) }
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: proxy.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [KCStyle.accent.opacity(0.24), KCStyle.accent.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                    Path { path in
                        path.move(to: points[0])
                        points.dropFirst().forEach { path.addLine(to: $0) }
                    }
                    .stroke(KCStyle.accent, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func normalized(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, let lo = values.min(), let hi = values.max() else { return [] }
        let span = max(hi - lo, 1)
        return values.enumerated().map { i, v in
            CGPoint(x: size.width * Double(i) / Double(values.count - 1),
                    y: size.height * (1 - (v - lo) / span * 0.85) - 1)
        }
    }
}

struct PortSwitch: View {
    var isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(isOn ? KCStyle.charging : Color.secondary.opacity(0.2))
            Circle().fill(.white).padding(2).shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
        }
        .frame(width: 34, height: 20)
        .widgetAccentable()
    }
}
