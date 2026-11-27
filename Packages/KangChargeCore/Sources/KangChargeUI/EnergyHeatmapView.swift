import SwiftUI
import KangChargeCore

/// Generic data point for `CalendarHeatmapView` so this component can be reused
/// across any SwiftUI project (habits, coding activity, energy usage, workouts, etc.).
public struct CalendarHeatmapCell: Hashable, Identifiable, Sendable {
    public let id: String
    public let date: Date
    /// Normalized intensity level in `0...4`.
    public let level: Int
    /// Optional human-readable value shown on hover/tap (e.g. "148 Wh").
    public let valueText: String

    public init(id: String, date: Date, level: Int, valueText: String) {
        self.id = id
        self.date = date
        self.level = min(max(level, 0), 4)
        self.valueText = valueText
    }
}

/// Reusable GitHub-style Calendar Heatmap component with optional Month (top) and Weekday (left) labels.
/// Renders the entire grid in a single SwiftUI `Canvas` + continuous hover/tap coordinate mapping
/// for <2 ms performance in live windows, Xcode Previews, and WidgetKit timelines.
public struct CalendarHeatmapView: View {
    public let cells: [CalendarHeatmapCell]
    public var tint: Color
    public var cellSpacing: CGFloat
    public var cornerRadius: CGFloat
    public var maxCellSize: CGFloat
    public var interactive: Bool
    public var showAxisLabels: Bool
    public var onSelect: ((CalendarHeatmapCell?) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedID: String?

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMM")
        return f
    }()

    public init(
        cells: [CalendarHeatmapCell],
        tint: Color = KCStyle.charging,
        cellSpacing: CGFloat = 3.5,
        cornerRadius: CGFloat = 3,
        maxCellSize: CGFloat = 13,
        interactive: Bool = true,
        showAxisLabels: Bool = true,
        onSelect: ((CalendarHeatmapCell?) -> Void)? = nil
    ) {
        self.cells = cells
        self.tint = tint
        self.cellSpacing = cellSpacing
        self.cornerRadius = cornerRadius
        self.maxCellSize = maxCellSize
        self.interactive = interactive
        self.showAxisLabels = showAxisLabels
        self.onSelect = onSelect
    }

    private var colCount: Int {
        max(1, (cells.count + 6) / 7)
    }

    private var weekdayLabelWidth: CGFloat { showAxisLabels ? 20 : 0 }
    private var monthHeaderHeight: CGFloat { showAxisLabels ? 16 : 0 }

    private func cellSize(for totalWidth: CGFloat) -> CGFloat {
        let gridWidth = max(40, totalWidth - weekdayLabelWidth)
        let totalHSpacing = cellSpacing * CGFloat(max(colCount - 1, 0))
        let fitWidth = (gridWidth - totalHSpacing) / CGFloat(colCount)
        return max(5, min(maxCellSize, floor(fitWidth * 2) / 2))
    }

    private func cell(at point: CGPoint, totalWidth: CGFloat) -> CalendarHeatmapCell? {
        let size = cellSize(for: totalWidth)
        let stride = size + cellSpacing
        guard stride > 0 else { return nil }
        let x = point.x - weekdayLabelWidth
        let y = point.y - monthHeaderHeight
        guard x >= 0, y >= 0 else { return nil }
        let col = Int(x / stride)
        let row = Int(y / stride)
        guard col >= 0, col < colCount, row >= 0, row < 7 else { return nil }
        let idx = col * 7 + row
        guard idx >= 0, idx < cells.count else { return nil }
        return cells[idx]
    }

    /// Computes (columnIndex, monthLabel) pairs for columns where a new month starts.
    private func monthMarkers() -> [(col: Int, label: String)] {
        let cal = Calendar.current
        var result: [(Int, String)] = []
        var lastMonth: Int?
        var lastCol = -4
        for col in 0..<colCount {
            let idx = col * 7
            guard idx < cells.count else { break }
            let date = cells[idx].date
            let month = cal.component(.month, from: date)
            if month != lastMonth {
                if col - lastCol >= 3 {
                    let label = Locale.kcPrefersChinese ? "\(month)月" : Self.monthFormatter.string(from: date)
                    result.append((col, label))
                    lastCol = col
                }
                lastMonth = month
            }
        }
        return result
    }

    public var body: some View {
        let scheme = colorScheme
        let palette = (0..<5).map { KCStyle.heatmapColor(level: $0, tint: tint, colorScheme: scheme) }
        let highlightStroke = Color.primary.opacity(0.65)
        let markers = showAxisLabels ? monthMarkers() : []
        let weekdayRows: [(Int, String)] = Locale.kcPrefersChinese
            ? [(1, "一"), (3, "三"), (5, "五")]
            : [(1, "M"), (3, "W"), (5, "F")]

        GeometryReader { geo in
            let size = cellSize(for: geo.size.width)
            let stride = size + cellSpacing
            let xOffset = weekdayLabelWidth
            let yOffset = monthHeaderHeight

            let canvas = Canvas { context, _ in
                // Month labels across top
                if showAxisLabels {
                    for marker in markers {
                        let x = xOffset + CGFloat(marker.col) * stride
                        let text = Text(marker.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        context.draw(text, at: CGPoint(x: x, y: 2), anchor: .topLeading)
                    }
                    // Weekday labels along left edge (rows 1, 3, 5)
                    for (row, label) in weekdayRows {
                        let y = yOffset + CGFloat(row) * stride + size / 2
                        let text = Text(label)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.tertiary)
                        context.draw(text, at: CGPoint(x: 0, y: y), anchor: .leading)
                    }
                }

                // Grid cells
                for idx in cells.indices {
                    let col = idx / 7
                    let row = idx % 7
                    guard col < colCount else { continue }
                    let item = cells[idx]
                    let rect = CGRect(
                        x: xOffset + CGFloat(col) * stride,
                        y: yOffset + CGFloat(row) * stride,
                        width: size,
                        height: size
                    )
                    let path = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
                    context.fill(path, with: .color(palette[item.level]))
                    if item.id == selectedID {
                        context.stroke(path, with: .color(highlightStroke), lineWidth: 1.2)
                    }
                }
            }

            if interactive {
                canvas
                    .contentShape(Rectangle())
                    #if os(macOS) || os(iOS)
                    .onTapGesture { location in
                        let hit = cell(at: location, totalWidth: geo.size.width)
                        selectedID = (hit?.id == selectedID) ? nil : hit?.id
                        onSelect?(selectedID == nil ? nil : hit)
                    }
                    #endif
                    #if os(macOS)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let hit = cell(at: location, totalWidth: geo.size.width)
                            selectedID = hit?.id
                            onSelect?(hit)
                        case .ended:
                            selectedID = nil
                            onSelect?(nil)
                        }
                    }
                    #endif
            } else {
                canvas
            }
        }
        .frame(height: monthHeaderHeight + 7 * maxCellSize + 6 * cellSpacing)
    }
}

/// Domain-specific SugarWatt Daily Energy Heatmap built on top of the reusable `CalendarHeatmapView`.
public struct EnergyHeatmapView: View {
    public let summary: EnergySummary
    public var tint: Color
    public var cellSpacing: CGFloat
    public var cornerRadius: CGFloat
    public var maxCellSize: CGFloat
    public var interactive: Bool
    public var showLegend: Bool
    public var showHeader: Bool
    public var showAxisLabels: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCell: CalendarHeatmapCell?

    public init(
        summary: EnergySummary,
        tint: Color = KCStyle.charging,
        cellSpacing: CGFloat = 3.5,
        cornerRadius: CGFloat = 3,
        maxCellSize: CGFloat = 13,
        interactive: Bool = true,
        showLegend: Bool = true,
        showHeader: Bool = true,
        showAxisLabels: Bool = true
    ) {
        self.summary = summary
        self.tint = tint
        self.cellSpacing = cellSpacing
        self.cornerRadius = cornerRadius
        self.maxCellSize = maxCellSize
        self.interactive = interactive
        self.showLegend = showLegend
        self.showHeader = showHeader
        self.showAxisLabels = showAxisLabels
    }

    private var scaleMaxWh: Double {
        max(summary.peakWattHours, 180)
    }

    private var heatmapCells: [CalendarHeatmapCell] {
        let maxWh = scaleMaxWh
        return summary.days.map { day in
            CalendarHeatmapCell(
                id: day.id,
                date: day.date,
                level: day.level(maxWattHours: maxWh),
                valueText: KCFormat.energy(wattHours: day.wattHours)
            )
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showHeader {
                headerRow
            }

            CalendarHeatmapView(
                cells: heatmapCells,
                tint: tint,
                cellSpacing: cellSpacing,
                cornerRadius: cornerRadius,
                maxCellSize: maxCellSize,
                interactive: interactive,
                showAxisLabels: showAxisLabels
            ) { cell in
                selectedCell = cell
            }

            if showLegend {
                legendRow
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let selectedCell {
                Text(selectedCell.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(selectedCell.valueText)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            } else {
                let zh = Locale.kcPrefersChinese
                Text(zh ? "今日 \(KCFormat.energy(wattHours: summary.todayWattHours))" : "Today \(KCFormat.energy(wattHours: summary.todayWattHours))")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(zh ? "近 7 天 \(KCFormat.energy(wattHours: summary.last7DaysWattHours))" : "7d \(KCFormat.energy(wattHours: summary.last7DaysWattHours))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if summary.activeDays > 0 {
                let zh = Locale.kcPrefersChinese
                Text(zh ? "\(summary.activeDays) 天活跃" : "\(summary.activeDays) active days")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var legendRow: some View {
        HStack(spacing: 4) {
            let zh = Locale.kcPrefersChinese
            Text(zh ? "合计 \(KCFormat.energy(wattHours: summary.totalWattHours))" : "Total \(KCFormat.energy(wattHours: summary.totalWattHours))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            Text(zh ? "少" : "Less")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(KCStyle.heatmapColor(level: level, tint: tint, colorScheme: colorScheme))
                    .frame(width: 9, height: 9)
            }
            Text(zh ? "多" : "More")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
