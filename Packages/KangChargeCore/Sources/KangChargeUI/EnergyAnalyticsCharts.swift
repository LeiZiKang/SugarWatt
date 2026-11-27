import SwiftUI
import Charts
import KangChargeCore

// MARK: - 1. Reusable Port Energy Donut Chart

/// Restrained Apple-style Donut Chart showing each port's share of total accumulated energy.
@available(macOS 14.0, iOS 17.0, watchOS 10.0, *)
public struct PortEnergyDonutChart: View {
    public let shares: [PortEnergyShare]

    private static let palette: [Color] = [
        KCStyle.accent,
        KCStyle.charging,
        Color(red: 0.95, green: 0.64, blue: 0.11),
        Color(red: 0.35, green: 0.52, blue: 0.92),
        Color.secondary.opacity(0.65),
    ]

    public init(shares: [PortEnergyShare]) {
        self.shares = shares
    }

    private var zh: Bool { Locale.kcPrefersChinese }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(zh ? "端口用电占比" : "Energy by Port")
                    .font(.headline)
                if let top = shares.first {
                    Text(zh
                         ? "\(top.name) 占比最高（\(Int((top.fraction * 100).rounded()))%）"
                         : "\(top.name) leads at \(Int((top.fraction * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if shares.isEmpty {
                Text(zh ? "开始充电后将自动统计各端口用电占比。" : "Charge devices to build per-port energy breakdown.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
            } else {
                HStack(spacing: 16) {
                    ZStack {
                        Chart(Array(shares.enumerated()), id: \.element.id) { idx, item in
                            SectorMark(
                                angle: .value("Energy", item.wattHours),
                                innerRadius: .ratio(0.64),
                                angularInset: 2
                            )
                            .cornerRadius(4)
                            .foregroundStyle(Self.palette[idx % Self.palette.count])
                        }
                        .frame(width: 118, height: 118)

                        if let top = shares.first {
                            VStack(spacing: 1) {
                                Text("\(Int((top.fraction * 100).rounded()))%")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                Text(top.name.components(separatedBy: " · ").first ?? top.name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(shares.enumerated()), id: \.element.id) { idx, item in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Self.palette[idx % Self.palette.count])
                                    .frame(width: 7, height: 7)
                                Text(item.name)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(Int((item.fraction * 100).rounded()))%")
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                                Text(KCFormat.energy(wattHours: item.wattHours))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - 2. Reusable Time Pattern Line/Area Chart (By Hour / By Weekday)

public enum EnergyTimeGranularity: String, CaseIterable, Identifiable {
    case hourly
    case weekday

    public var id: String { rawValue }
}

/// Time-distribution Area/Line Chart with a segmented toggle between Hourly (0-23h) and Weekday (Mon-Sun),
/// plus an automatic peak-time insight callout underneath.
@available(macOS 14.0, iOS 17.0, watchOS 10.0, *)
public struct EnergyTimePatternChart: View {
    public let analytics: EnergyAnalytics
    @State private var mode: EnergyTimeGranularity

    public init(analytics: EnergyAnalytics, initialMode: EnergyTimeGranularity = .hourly) {
        self.analytics = analytics
        _mode = State(initialValue: initialMode)
    }

    private var zh: Bool { Locale.kcPrefersChinese }

    private var points: [(index: Int, label: String, wh: Double)] {
        switch mode {
        case .hourly:
            return analytics.hourlyWattHours.enumerated().map { idx, wh in
                (idx, String(format: "%02d", idx), wh)
            }
        case .weekday:
            let names = zh ? ["一", "二", "三", "四", "五", "六", "日"] : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            return analytics.weekdayWattHours.enumerated().map { idx, wh in
                (idx, names[idx], wh)
            }
        }
    }

    private var averageWh: Double {
        let nonZero = points.map(\.wh)
        guard !nonZero.isEmpty else { return 0 }
        return nonZero.reduce(0, +) / Double(nonZero.count)
    }

    private var peakSummary: String {
        switch mode {
        case .hourly:
            guard let peak = analytics.peakHour else {
                return zh ? "累计充电数据后将自动识别高峰时段。" : "Charge across the day to discover your peak hour."
            }
            let hourText = formatHour(peak)
            return zh ? "最常用电高峰在 \(hourText) 左右" : "Peak charging time is around \(hourText)"
        case .weekday:
            guard let peak = analytics.peakWeekday else {
                return zh ? "累计多日充电后将自动识别最活跃星期。" : "Charge over a week to discover your busiest day."
            }
            let fullNames = zh
                ? ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
                : ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            return zh ? "每周 \(fullNames[peak]) 用电最多" : "Most active day of the week is \(fullNames[peak])"
        }
    }

    private func formatHour(_ hour: Int) -> String {
        if zh {
            if hour < 6 { return "凌晨 \(hour):00" }
            if hour < 12 { return "上午 \(hour):00" }
            if hour == 12 { return "中午 12:00" }
            if hour < 18 { return "下午 \(hour - 12):00（\(hour):00）" }
            return "晚上 \(hour - 12):00（\(hour):00）"
        }
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }

    public var body: some View {
        let peakVal = max(points.map(\.wh).max() ?? 0, 20)
        let peakIdx = mode == .hourly ? analytics.peakHour : analytics.peakWeekday

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(zh ? "用电时段分布" : "Charging Rhythm")
                    .font(.headline)

                Spacer()

                // Segmented switcher (By Hour / By Weekday)
                HStack(spacing: 2) {
                    segmentButton(zh ? "按时段" : "By Hour", selected: mode == .hourly) {
                        withAnimation(.easeInOut(duration: 0.2)) { mode = .hourly }
                    }
                    segmentButton(zh ? "按星期" : "By Weekday", selected: mode == .weekday) {
                        withAnimation(.easeInOut(duration: 0.2)) { mode = .weekday }
                    }
                }
                .padding(2)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
            }

            Chart {
                if averageWh > 0 {
                    RuleMark(y: .value("Avg", averageWh))
                        .foregroundStyle(Color.secondary.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                ForEach(points, id: \.index) { pt in
                    AreaMark(
                        x: .value("Time", pt.index),
                        y: .value("Wh", pt.wh)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [KCStyle.accent.opacity(0.22), KCStyle.accent.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", pt.index),
                        y: .value("Wh", pt.wh)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(KCStyle.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))

                    if pt.index == peakIdx, pt.wh > 0 {
                        PointMark(
                            x: .value("Time", pt.index),
                            y: .value("Wh", pt.wh)
                        )
                        .foregroundStyle(KCStyle.accent)
                        .symbolSize(42)
                    }
                }
            }
            .chartYScale(domain: 0...(peakVal * 1.18))
            .chartXAxis {
                if mode == .hourly {
                    AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.primary.opacity(0.06))
                        AxisValueLabel {
                            if let h = value.as(Int.self) {
                                Text(String(format: "%02d", h))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                            }
                        }
                    }
                } else {
                    AxisMarks(values: Array(0..<7)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.primary.opacity(0.06))
                        AxisValueLabel {
                            if let d = value.as(Int.self), d >= 0, d < points.count {
                                Text(points[d].label)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.primary.opacity(0.06))
                    AxisValueLabel {
                        if let wh = value.as(Double.self), wh > 0 {
                            Text("\(Int(wh)) Wh")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .frame(height: 145)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(KCStyle.accent)
                Text(peakSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if averageWh > 0 {
                    Text(zh ? "虚线为均值" : "Dashed = avg")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func segmentButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(selected ? .semibold : .medium))
                .foregroundStyle(selected ? .primary : .secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(selected ? Color.primary.opacity(0.10) : .clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 3. Energy Equivalents Card

/// Translates total accumulated kWh into fun, tangible everyday equivalents (hot-updatable via static JSON).
public struct EnergyEquivalentsCard: View {
    public let totalWattHours: Double
    @Environment(\.colorScheme) private var colorScheme

    public init(totalWattHours: Double) {
        self.totalWattHours = totalWattHours
    }

    private var zh: Bool { Locale.kcPrefersChinese }

    public var body: some View {
        let items = EnergyEquivalentsCatalog.equivalents(forTotalWattHours: totalWattHours, limit: 3)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(zh
                         ? "累计 \(KCFormat.energy(wattHours: totalWattHours)) 相当于"
                         : "\(KCFormat.energy(wattHours: totalWattHours)) in real life")
                        .font(.headline)
                    Spacer()
                    Text(zh ? "趣味道具换算" : "Energy Equivalents")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 12) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(KCStyle.accent)
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("≈ \(item.formattedAmount)")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                Text(item.unit)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(KCStyle.surfaceTile(for: colorScheme))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                                )
                        )
                    }
                }
            }
        }
    }
}

// MARK: - 4. Reusable 8-Segment Hardware LED Power Pressure Meter

/// CoCan dot-matrix inspired segmented load/pressure gauge (green -> amber -> vermilion).
/// Communicates how close a port is to its maximum watt rating (e.g. 60 W / 60 W = all segments lit).
public struct PowerPressureMeter: View {
    public let watts: Double
    public let maxWatts: Double
    public var segments: Int
    public var segmentWidth: CGFloat
    public var segmentHeight: CGFloat
    public var animated: Bool

    @State private var pulse = false

    public init(
        watts: Double,
        maxWatts: Double,
        segments: Int = 8,
        segmentWidth: CGFloat = 7,
        segmentHeight: CGFloat = 7.5,
        animated: Bool = true
    ) {
        self.watts = watts
        self.maxWatts = maxWatts
        self.segments = max(4, segments)
        self.segmentWidth = segmentWidth
        self.segmentHeight = segmentHeight
        self.animated = animated
    }

    private var ratio: Double {
        guard maxWatts > 0, watts > 0.1 else { return 0 }
        return min(max(watts / maxWatts, 0), 1)
    }

    private var activeCount: Int {
        guard ratio > 0 else { return 0 }
        return min(segments, max(1, Int((ratio * Double(segments)).rounded(.up))))
    }

    private func color(for index: Int) -> Color {
        let pos = Double(index + 1) / Double(segments)
        if pos > 0.75 { return KCStyle.accent }
        if pos > 0.50 { return Color(red: 0.95, green: 0.64, blue: 0.11) }
        return KCStyle.charging
    }

    private var shouldAnimate: Bool {
        animated && ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
    }

    public var body: some View {
        let count = activeCount
        let anim = shouldAnimate
        HStack(spacing: 2.5) {
            ForEach(0..<segments, id: \.self) { idx in
                let isLit = idx < count
                let isLeading = isLit && idx == count - 1
                let isNextBuffer = anim && count > 0 && count < segments && idx == count

                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(
                        isLit
                            ? color(for: idx).opacity(isLeading && anim && pulse ? 0.62 : 1.0)
                            : (isNextBuffer
                                ? color(for: idx).opacity(pulse ? 0.28 : 0.08)
                                : Color.primary.opacity(0.09))
                    )
                    .frame(width: segmentWidth, height: segmentHeight)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: count)
        .onAppear {
            guard anim, count > 0 else { return }
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChange(of: count > 0) { _, active in
            if anim && active {
                withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    pulse = false
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Power load")
        .accessibilityValue("\(Int((ratio * 100).rounded()))%")
    }
}
