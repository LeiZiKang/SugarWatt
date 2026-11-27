import SwiftUI
import Charts
import UIKit
import UniformTypeIdentifiers
import KangChargeCore
import KangChargeUI

/// Subtle iOS SpringBoard-style staggered jiggle animation shown in widget Edit Mode.
private struct SpringBoardJiggle: ViewModifier {
    let active: Bool
    let seed: Int
    @State private var rocking = false

    func body(content: Content) -> some View {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let shouldRock = active && !isPreview
        let angle: Double = (seed % 2 == 0) ? 1.15 : -1.15
        let duration: Double = 0.13 + Double(seed % 4) * 0.014
        let delay: Double = Double(seed % 5) * 0.025

        content
            .rotationEffect(.degrees(shouldRock ? (rocking ? angle : -angle) : (active ? angle * 0.7 : 0)))
            .animation(
                shouldRock
                    ? .easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)
                    : .spring(response: 0.25, dampingFraction: 0.85),
                value: rocking
            )
            .onChange(of: shouldRock) { _, isActive in
                rocking = isActive
            }
            .onAppear {
                if shouldRock { rocking = true }
            }
    }
}

/// Live SpringBoard-style DropDelegate: triggers immediate auto-reflow + haptic tick on `dropEntered`.
private struct WidgetAutoReflowDelegate: DropDelegate {
    let target: HomeModule
    @Binding var dragged: HomeModule?
    let layout: HomeLayoutStore

    func dropEntered(info: DropInfo) {
        guard let dragged, dragged != target else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        layout.moveItem(dragged, before: target)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dragged = nil
        return true
    }
}

/// iOS Home-Screen-style modular widget board supporting 1x1 square & 2x1 full-width tiles,
/// SpringBoard jiggle animation, tactile haptic feedback, live auto-reflow drag-and-drop, and Widget Gallery.
struct WidgetBoardCanvas: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var layout: HomeLayoutStore
    @Binding var isEditing: Bool
    @Binding var showingGallery: Bool
    let snapshot: ChargerSnapshot
    let onSelectPort: (PortSnapshot) -> Void
    let onRequestTurnOff: (PortSnapshot) -> Void
    var darkOLED: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @State private var draggedModule: HomeModule?

    private var tileBackground: Color {
        darkOLED ? Color(white: 0.085) : KCStyle.cardBackground(for: colorScheme)
    }

    private var tileBorder: Color {
        darkOLED ? Color.white.opacity(0.10) : Color.primary.opacity(0.06)
    }

    var body: some View {
        let rows = layout.packedRows()
        VStack(spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { colIdx, item in
                        let seed = rowIdx * 3 + colIdx + item.module.rawValue.count
                        let isDragged = draggedModule == item.module
                        widgetTile(item, seed: seed)
                            .frame(maxWidth: .infinity)
                            .opacity(isDragged ? 0.35 : 1.0)
                            .scaleEffect(isDragged ? 0.96 : 1.0)
                            .onDrag {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                if !isEditing {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isEditing = true
                                    }
                                }
                                draggedModule = item.module
                                return NSItemProvider(object: item.module.rawValue as NSString)
                            }
                            .onDrop(
                                of: [UTType.text],
                                delegate: WidgetAutoReflowDelegate(
                                    target: item.module,
                                    dragged: $draggedModule,
                                    layout: layout
                                )
                            )
                    }
                    if row.count == 1 && row[0].span == .compact {
                        // Empty half-slot invite in Edit Mode
                        if isEditing {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showingGallery = true
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(KCStyle.accent)
                                    Text("Add Widget")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 156)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                                        .foregroundStyle(Color.primary.opacity(0.18))
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.80), value: layout.items)
    }

    @ViewBuilder
    private func widgetTile(_ item: HomeModuleItem, seed: Int) -> some View {
        ZStack(alignment: .topLeading) {
            tileContent(item)
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: item.span == .compact ? 156 : nil, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(tileBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(isEditing ? KCStyle.accent.opacity(0.45) : tileBorder, lineWidth: isEditing ? 1.2 : 0.75)
                )
                .onLongPressGesture(minimumDuration: 0.4) {
                    if !isEditing {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isEditing = true
                        }
                    }
                }

            if isEditing {
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        layout.toggle(item.module)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.secondary)
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if item.module.supportsCompact {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            layout.toggleSpan(item.module)
                        } label: {
                            Text(item.span == .compact ? "1×1" : "2×1")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(KCStyle.accent))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .offset(x: -10, y: -10)
            }
        }
        .modifier(SpringBoardJiggle(active: isEditing && draggedModule != item.module, seed: seed))
    }

    @ViewBuilder
    private func tileContent(_ item: HomeModuleItem) -> some View {
        switch item.module {
        case .powerRing:
            compactPowerRing
        case .todayEnergy:
            compactTodayEnergy
        case .hero:
            wideHero
        case .ports:
            widePorts
        case .heatmap:
            wideHeatmap
        case .equivalents:
            if item.span == .compact {
                compactEquivalent
            } else {
                EnergyEquivalentsCard(totalWattHours: model.energySummary.totalWattHours)
            }
        case .portDonut:
            PortEnergyDonutChart(shares: model.energyAnalytics.portShares)
        case .rhythm:
            EnergyTimePatternChart(analytics: model.energyAnalytics)
        case .controls:
            wideControls
        }
    }

    // MARK: - 1x1 Compact Square Widgets

    private var compactPowerRing: some View {
        let fraction = snapshot.maxPower > 0 ? min(max(snapshot.totalPower / snapshot.maxPower, 0), 1) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Power", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KCStyle.accent)
                Spacer()
                Circle()
                    .fill(model.isOnline ? KCStyle.charging : .secondary)
                    .frame(width: 6, height: 6)
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.09), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(KCStyle.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(KCFormat.watts(snapshot.totalPower)) W")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Text("of \(Int(snapshot.maxPower))W")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
            Text("\(snapshot.chargingCount) ports active")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var compactTodayEnergy: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Today", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KCStyle.charging)
                Spacer()
                Text("\(model.energySummary.currentStreak)d")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            Text(KCFormat.energy(wattHours: model.energySummary.todayWattHours))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("7d · \(KCFormat.energy(wattHours: model.energySummary.last7DaysWattHours))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer(minLength: 0)
            Text("Total \(KCFormat.energy(wattHours: model.energySummary.totalWattHours))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
    }

    private var compactEquivalent: some View {
        let eq = EnergyEquivalentsCatalog.equivalents(forTotalWattHours: model.energySummary.totalWattHours, limit: 1).first
        return VStack(alignment: .leading, spacing: 6) {
            Image(systemName: eq?.symbol ?? "sparkles")
                .font(.title3)
                .foregroundStyle(KCStyle.accent)
            Spacer(minLength: 0)
            Text(eq.map { "≈ \($0.formattedAmount)" } ?? "—")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(eq?.title ?? "Energy Equivalent")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    // MARK: - 2x1 Full-Width Widgets

    private var wideHero: some View {
        let fraction = snapshot.maxPower > 0 ? min(max(snapshot.totalPower / snapshot.maxPower, 0), 1) : 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(KCStyle.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int((fraction * 100).rounded()))%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("\(Int(snapshot.maxPower))W")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(KCFormat.watts(snapshot.totalPower))
                            .font(.system(size: 42, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                        Text("W").font(.title3.weight(.medium)).foregroundStyle(.secondary)
                    }
                    Text("\(snapshot.chargingCount) charging · \(KCFormat.watts(max(snapshot.maxPower - snapshot.totalPower, 0))) W free")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    Circle().fill(model.isOnline ? KCStyle.charging : .secondary).frame(width: 6, height: 6)
                    Text(model.isOnline ? "Live" : "Offline")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(model.isOnline ? KCStyle.charging : .secondary)
            }

            if snapshot.history.count >= 2 {
                Chart(Array(snapshot.history.suffix(60)), id: \.date) { point in
                    AreaMark(x: .value("Time", point.date), y: .value("Power", point.watts))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [KCStyle.accent.opacity(0.24), KCStyle.accent.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Time", point.date), y: .value("Power", point.watts))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(KCStyle.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 54)
            }
        }
    }

    private var widePorts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ports")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(snapshot.ports) { port in
                let batteryFraction = model.pdStatus[port.index]?.batteryFraction
                HStack(spacing: 10) {
                    Button { onSelectPort(port) } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(KCStyle.surfaceTile(for: colorScheme).opacity(port.isCharging ? 1.0 : 0.65))
                                Circle()
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1.8)
                                if let batteryFraction, port.isCharging {
                                    Circle()
                                        .trim(from: 0, to: batteryFraction)
                                        .stroke(KCStyle.charging, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                }
                                Image(systemName: KCDeviceSymbol.systemName(for: port))
                                    .font(.system(size: 13.5, weight: .regular))
                                    .foregroundStyle(port.isCharging ? .primary : .tertiary)
                            }
                            .frame(width: 36, height: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    Text(port.deviceName ?? KCFormat.portDisplayName(port))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(port.isCharging ? .primary : .secondary)
                                        .lineLimit(1)
                                    if port.deviceName != nil {
                                        Text(KCFormat.portDisplayName(port))
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.tertiary)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(Color.primary.opacity(0.05)))
                                    }
                                    if let batteryFraction, port.isCharging {
                                        Text("\(Int((batteryFraction * 100).rounded()))%")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(KCStyle.charging)
                                            .monospacedDigit()
                                    }
                                }
                                Text(port.isCharging
                                     ? "\(KCFormat.volts(port.voltage)) · \(KCFormat.amps(port.current))"
                                     : "Idle · Up to \(Int(port.maxPower)) W")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Spacer(minLength: 4)
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(port.isCharging ? "\(KCFormat.watts(port.power)) W" : "—")
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(port.isCharging ? .primary : .tertiary)
                                PowerPressureMeter(
                                    watts: port.isCharging ? port.power : 0,
                                    maxWatts: port.maxPower,
                                    segments: 6,
                                    segmentWidth: 5.5,
                                    segmentHeight: 5.5,
                                    animated: ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
                                )
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if port.isCharging {
                        Toggle("", isOn: Binding(get: { true }, set: { if !$0 { onRequestTurnOff(port) } }))
                            .labelsHidden()
                            .tint(KCStyle.charging)
                            .fixedSize()
                    } else {
                        Button("Idle") { Task { await model.setPort(port.index, on: true) } }
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                            .buttonStyle(.plain)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                if port.index != snapshot.ports.last?.index {
                    Divider().opacity(0.45)
                }
            }
        }
    }

    private var wideHeatmap: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily Energy")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                NavigationLink {
                    EnergyAnalyticsView().environmentObject(model)
                } label: {
                    Text("Charts ›")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(KCStyle.accent)
                }
            }
            EnergyHeatmapView(
                summary: model.energySummary,
                tint: KCStyle.charging,
                cellSpacing: 3.5,
                cornerRadius: 3,
                interactive: true,
                showLegend: true,
                showHeader: true,
                showAxisLabels: true
            )
        }
    }

    private var wideControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Charging Mode")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(model.strategy?.localizedName ?? "Smart")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(KCStyle.accent)
            }
            Picker("Thermal", selection: Binding(
                get: { model.thermal },
                set: { value in Task { await model.setThermal(value) } }
            )) {
                ForEach(TemperatureMode.allCases) { Text($0.localizedName).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }
}
