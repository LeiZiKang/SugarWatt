import SwiftUI
import Charts
import UIKit
import KangChargeCore
import KangChargeUI

/// StandBy-inspired full-screen Desk Dashboard shown automatically when iPhone is rotated to landscape.
struct LandscapeDashboardView: View {
    enum RightPanelMode: String, CaseIterable {
        case ports
        case heatmap
        case widgets

        var next: RightPanelMode {
            switch self {
            case .ports: return .heatmap
            case .heatmap: return .widgets
            case .widgets: return .ports
            }
        }

        var icon: String {
            switch self {
            case .ports: return "calendar"
            case .heatmap: return "square.grid.2x2"
            case .widgets: return "list.bullet"
            }
        }
    }

    @EnvironmentObject var model: AppModel
    @StateObject private var layout = HomeLayoutStore()
    @AppStorage("kc.desk.oledBlack") private var oledBlack = true
    @AppStorage("kc.desk.keepAwake") private var keepAwake = true
    @AppStorage("kc.desk.rightPanel") private var rightPanelRaw = RightPanelMode.ports.rawValue
    @State private var detail: PortSnapshot?
    @State private var pendingOff: PortSnapshot?
    @State private var editingBoard = false
    @State private var showingGallery = false
    private var overrideRightPanel: RightPanelMode?

    init(initialRightPanel: RightPanelMode? = nil) {
        self.overrideRightPanel = initialRightPanel
    }

    private var rightPanel: RightPanelMode {
        overrideRightPanel ?? (RightPanelMode(rawValue: rightPanelRaw) ?? .ports)
    }

    private var bgColor: Color {
        oledBlack ? Color.black : KCStyle.canvasBackground(for: .light)
    }

    private var cardBg: Color {
        oledBlack ? Color(white: 0.085) : Color.white.opacity(0.82)
    }

    private var borderStroke: Color {
        oledBlack ? Color.white.opacity(0.10) : Color.primary.opacity(0.07)
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if let snapshot = model.snapshot {
                GeometryReader { geo in
                    let leftWidth = max(295, min(360, geo.size.width * 0.43))
                    HStack(spacing: 14) {
                        leftHeroColumn(snapshot)
                            .frame(width: leftWidth)

                        if rightPanel == .heatmap {
                            rightHeatmapColumn()
                                .frame(maxWidth: .infinity)
                        } else if rightPanel == .widgets {
                            ScrollView {
                                WidgetBoardCanvas(
                                    layout: layout,
                                    isEditing: $editingBoard,
                                    showingGallery: $showingGallery,
                                    snapshot: snapshot,
                                    onSelectPort: { detail = $0 },
                                    onRequestTurnOff: { pendingOff = $0 },
                                    darkOLED: oledBlack
                                )
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            rightPortsColumn(snapshot)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            } else {
                ProgressView("Connecting to charger…")
                    .tint(KCStyle.accent)
            }
        }
        .preferredColorScheme(oledBlack ? .dark : nil)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = keepAwake
        }
        .onChange(of: keepAwake) { _, awake in
            UIApplication.shared.isIdleTimerDisabled = awake
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showingGallery) {
            CustomizeHomeView(layout: layout)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $detail) { port in
            PortDetailView(port: port)
                .environmentObject(model)
                .presentationDetents([.medium, .large])
                .presentationBackground(Color(.systemGroupedBackground))
        }
        .confirmationDialog(
            "Turn off \(pendingOff?.name ?? "")?",
            isPresented: Binding(get: { pendingOff != nil }, set: { if !$0 { pendingOff = nil } }),
            titleVisibility: .visible
        ) {
            if let port = pendingOff {
                Button("Turn Off", role: .destructive) {
                    Task { await model.setPort(port.index, on: false) }
                    pendingOff = nil
                }
            }
            Button("Cancel", role: .cancel) { pendingOff = nil }
        } message: {
            Text("\(pendingOff?.deviceName ?? "The connected device") will stop charging.")
        }
    }

    private func leftHeroColumn(_ snapshot: ChargerSnapshot) -> some View {
        let fraction = snapshot.maxPower > 0 ? snapshot.totalPower / snapshot.maxPower : 0
        return VStack(alignment: .leading, spacing: 12) {
            // Top bar: device name + status + quick controls
            HStack(spacing: 8) {
                Circle()
                    .fill(model.isOnline ? KCStyle.charging : .secondary)
                    .frame(width: 7, height: 7)
                Text(snapshot.deviceName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if ChargerSource.isDemo {
                    Text("Sample")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                Spacer(minLength: 4)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        rightPanelRaw = rightPanel.next.rawValue
                    }
                } label: {
                    Image(systemName: rightPanel.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(rightPanel != .ports ? KCStyle.charging : .secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .accessibilityLabel("Switch right panel: Ports, Calendar Heatmap, or Custom Widget Grid")

                Button {
                    keepAwake.toggle()
                } label: {
                    Image(systemName: keepAwake ? "sun.max.fill" : "moon.zzz")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(keepAwake ? KCStyle.accent : .secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .accessibilityLabel(keepAwake ? "Screen stays awake" : "Auto-lock enabled")

                Button {
                    oledBlack.toggle()
                } label: {
                    Image(systemName: oledBlack ? "circle.lefthalf.filled" : "circle.righthalf.filled")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .accessibilityLabel("Toggle OLED dark mode")

                Button {
                    Task { await model.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .accessibilityLabel("Refresh")
            }

            Spacer(minLength: 0)

            // Big StandBy power readout + circular load ring
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.10), lineWidth: 6.5)
                    Circle()
                        .trim(from: 0, to: min(max(fraction, 0), 1))
                        .stroke(KCStyle.accent, style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int((fraction * 100).rounded()))%")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("\(Int(snapshot.maxPower))W")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
                .frame(width: 66, height: 66)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(KCFormat.watts(snapshot.totalPower))
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: snapshot.totalPower))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("W")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Text("\(snapshot.chargingCount) charging")
                Text("·").foregroundStyle(.tertiary)
                Text("\(KCFormat.watts(max(snapshot.maxPower - snapshot.totalPower, 0))) W free")
                Text("·").foregroundStyle(.tertiary)
                Text("Today \(KCFormat.energy(wattHours: model.energySummary.todayWattHours))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            // Smooth power trend sparkline
            if snapshot.history.count >= 2 {
                Chart(Array(snapshot.history.suffix(60)), id: \.date) { point in
                    AreaMark(x: .value("Time", point.date), y: .value("Power", point.watts))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [KCStyle.accent.opacity(0.28), KCStyle.accent.opacity(0.01)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    LineMark(x: .value("Time", point.date), y: .value("Power", point.watts))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(KCStyle.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 62)
            }

            // Bottom mode & thermal pills
            HStack(spacing: 8) {
                if let strategy = model.strategy {
                    Label(strategy.localizedName, systemImage: strategy.symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                Label(model.thermal.localizedName, systemImage: model.thermal.symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                Spacer()
                if keepAwake {
                    Text("AWAKE")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(KCStyle.accent.opacity(0.85))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(cardBg))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(borderStroke, lineWidth: 0.75))
    }

    private func rightHeatmapColumn() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Energy")
                        .font(.headline)
                    Text("Hardware-metered charging calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 14) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(KCFormat.energy(wattHours: model.energySummary.todayWattHours))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KCStyle.charging)
                            .monospacedDigit()
                        Text("Today")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(KCFormat.energy(wattHours: model.energySummary.last7DaysWattHours))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        Text("7 Days")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(model.energySummary.currentStreak)d")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        Text("Streak")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            EnergyHeatmapView(
                summary: model.energySummary,
                tint: KCStyle.charging,
                cellSpacing: 4,
                cornerRadius: 3.5,
                maxCellSize: 16,
                interactive: true,
                showLegend: true,
                showHeader: false,
                showAxisLabels: true
            )

            Spacer(minLength: 0)

            let eqs = EnergyEquivalentsCatalog.equivalents(forTotalWattHours: model.energySummary.totalWattHours, limit: 3)
            if !eqs.isEmpty {
                HStack(spacing: 10) {
                    ForEach(eqs) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.symbol)
                                .font(.caption)
                                .foregroundStyle(KCStyle.accent)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("≈ \(item.formattedAmount) \(item.unit)")
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                Text(item.title)
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(cardBg))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(borderStroke, lineWidth: 0.75))
    }

    private func rightPortsColumn(_ snapshot: ChargerSnapshot) -> some View {
        VStack(spacing: 8) {
            ForEach(snapshot.ports) { port in
                DeskPortRow(
                    port: port,
                    batteryFraction: model.pdStatus[port.index]?.batteryFraction,
                    cardBg: cardBg,
                    borderStroke: borderStroke,
                    onInspect: { detail = port },
                    onToggle: { on in
                        if !on && port.isCharging {
                            pendingOff = port
                        } else {
                            Task { await model.setPort(port.index, on: on) }
                        }
                    },
                    disabled: model.busyPorts.contains(port.index)
                )
            }
        }
    }
}

private struct DeskPortRow: View {
    let port: PortSnapshot
    let batteryFraction: Double?
    let cardBg: Color
    let borderStroke: Color
    let onInspect: () -> Void
    let onToggle: (Bool) -> Void
    let disabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onInspect) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(port.isCharging ? 0.08 : 0.04))
                        Circle()
                            .stroke(Color.primary.opacity(0.10), lineWidth: 1.8)
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
                    .frame(width: 34, height: 34)

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
                                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                            }
                            if let batteryFraction, port.isCharging {
                                Text("\(Int((batteryFraction * 100).rounded()))%")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(KCStyle.charging)
                                    .monospacedDigit()
                            } else if let tag = KCFormat.protocolTag(port.protocolName), port.isCharging {
                                Text(tag)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(KCStyle.accent)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(KCStyle.accent.opacity(0.14), in: Capsule())
                            }
                        }

                        if port.isCharging {
                            HStack(spacing: 6) {
                                Text("\(KCFormat.volts(port.voltage)) · \(KCFormat.amps(port.current))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                if let temp = PortTemperature.localizedLabel(port.temperature) {
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(KCStyle.temperatureColor(port.temperature))
                                            .frame(width: 5, height: 5)
                                        Text(temp)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } else {
                            Text("Idle · Up to \(Int(port.maxPower)) W")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
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
                Toggle("", isOn: Binding(get: { true }, set: onToggle))
                    .labelsHidden()
                    .tint(KCStyle.charging)
                    .fixedSize()
                    .disabled(disabled)
            } else {
                Button("Idle") { onToggle(true) }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .buttonStyle(.plain)
                    .frame(width: 44, alignment: .trailing)
                    .disabled(disabled)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(cardBg))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(borderStroke, lineWidth: 0.75))
    }
}
