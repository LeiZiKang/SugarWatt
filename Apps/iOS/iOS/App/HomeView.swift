import SwiftUI
import Charts
import KangChargeCore
import KangChargeUI

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var layout = HomeLayoutStore()
    @State private var settings = false
    @State private var customizing = false
    @State private var editingBoard = false
    @State private var detail: PortSnapshot?
    @State private var pendingOff: PortSnapshot?
    @AppStorage("sugarwatt.ios.dismissedHomeTip") private var dismissedHomeTip = false

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height && geo.size.width >= 500
            Group {
                if isLandscape {
                    LandscapeDashboardView()
                } else {
                    portraitContent
                }
            }
            .animation(.easeInOut(duration: 0.22), value: isLandscape)
        }
    }

    private var portraitContent: some View {
        NavigationStack {
            ScrollView {
                if let snapshot = model.snapshot {
                    VStack(alignment: .leading, spacing: 14) {
                        if !dismissedHomeTip && !editingBoard {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(KCStyle.accent)
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Customize Your Charger Desk")
                                        .font(.caption.weight(.bold))
                                    Text("Tap + to browse the Widget Store, tap ••• for Device & Settings, or long-press any widget to jiggle & drag.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        dismissedHomeTip = true
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.tertiary)
                                        .padding(4)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(KCStyle.accent.opacity(colorScheme == .dark ? 0.12 : 0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(KCStyle.accent.opacity(0.28), lineWidth: 1)
                                    )
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        WidgetBoardCanvas(
                            layout: layout,
                            isEditing: $editingBoard,
                            showingGallery: $customizing,
                            snapshot: snapshot,
                            onSelectPort: { detail = $0 },
                            onRequestTurnOff: { pendingOff = $0 }
                        )

                        if !editingBoard {
                            Text("Long-press any widget to jiggle & rearrange, or rotate sideways for StandBy Desk Dashboard.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(16)
                } else {
                    VStack {
                        if let error = model.lastError {
                            ContentUnavailableView {
                                Label("Charger Offline", systemImage: "wifi.exclamationmark")
                            } description: {
                                Text(error)
                            } actions: {
                                Button("Try Again") { Task { await model.refresh() } }
                            }
                        } else {
                            ProgressView("Loading charger…")
                        }
                    }
                    .padding(.top, 80)
                }
            }
            .background(KCStyle.canvasBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle(model.snapshot?.deviceName ?? AppConfig.deviceName)
            .toolbar {
                if editingBoard {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            customizing = true
                        } label: {
                            Label("Widget Store", systemImage: "plus")
                                .fontWeight(.semibold)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                editingBoard = false
                            }
                        }
                        .fontWeight(.semibold)
                    }
                } else {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            customizing = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(KCStyle.accent)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().strokeBorder(KCStyle.accent.opacity(0.32), lineWidth: 1))
                        }
                        .accessibilityLabel("Open Widget Store")

                        Menu {
                            Section("Widgets") {
                                Button {
                                    customizing = true
                                } label: {
                                    Label("Widget Store", systemImage: "plus.square.on.square")
                                }
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                        editingBoard = true
                                    }
                                } label: {
                                    Label("Rearrange & Resize", systemImage: "square.grid.2x2")
                                }
                            }
                            Section("Charger") {
                                Button {
                                    settings = true
                                } label: {
                                    Label("Device & Settings", systemImage: "gearshape")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(.primary)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                        }
                        .accessibilityLabel("More Options & Settings")
                    }
                }
            }
            .refreshable { await model.refresh() }
            .sheet(isPresented: $customizing) {
                WidgetStoreSheetPrototype(layout: layout, snapshot: model.snapshot ?? KCDemo.snapshot())
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $settings) {
                SettingsView()
                    .environmentObject(model)
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
                Text("\(pendingOff?.deviceName ?? String(localized: "The connected device")) will stop charging.")
            }
            .overlay(alignment: .bottom) {
                if let toast = model.toast {
                    Text(toast)
                        .font(.callout)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding()
                        .accessibilityAddTraits(.updatesFrequently)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    @ViewBuilder
    private func moduleSection(_ module: HomeModule, snapshot: ChargerSnapshot) -> some View {
        switch module {
        case .powerRing, .todayEnergy:
            EmptyView()
        case .hero:
            Section {
                hero(snapshot)
            }
        case .ports:
            Section {
                ForEach(snapshot.ports) { port in
                    portRow(port)
                }
            } header: {
                Text("Ports")
            }
        case .heatmap:
            Section {
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
                .padding(.vertical, 6)

                NavigationLink {
                    EnergyAnalyticsView()
                        .environmentObject(model)
                } label: {
                    HStack {
                        Label("Energy Insights & Charts", systemImage: "chart.pie.fill")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(KCFormat.energy(wattHours: model.energySummary.totalWattHours))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } header: {
                HStack {
                    Text("Daily Energy")
                    Spacer()
                    if EnergyLedger.shared.isCloudAvailable && AppConfig.iCloudEnergySyncEnabled {
                        Label("iCloud", systemImage: "icloud")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .equivalents:
            Section {
                EnergyEquivalentsCard(totalWattHours: model.energySummary.totalWattHours)
                    .padding(.vertical, 4)
            }
        case .portDonut:
            Section {
                PortEnergyDonutChart(shares: model.energyAnalytics.portShares)
                    .padding(.vertical, 4)
            }
        case .rhythm:
            Section {
                EnergyTimePatternChart(analytics: model.energyAnalytics)
                    .padding(.vertical, 4)
            }
        case .controls:
            Section("Charging") {
                NavigationLink { ModePickerView() } label: {
                    LabeledContent("Mode", value: model.strategy?.localizedName ?? String(localized: "Not set"))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Thermal").font(.subheadline)
                    Picker("Thermal", selection: Binding(
                        get: { model.thermal },
                        set: { value in Task { await model.setThermal(value) } }
                    )) {
                        ForEach(TemperatureMode.allCases) { Text($0.localizedName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(model.controlling)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func hero(_ snapshot: ChargerSnapshot) -> some View {
        let fraction = snapshot.maxPower > 0 ? min(max(snapshot.totalPower / snapshot.maxPower, 0), 1) : 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(KCStyle.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.35), value: fraction)
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
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(KCFormat.watts(snapshot.totalPower))
                            .font(.system(size: 46, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: snapshot.totalPower))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text("W")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)

                    Text("\(snapshot.chargingCount) charging · \(KCFormat.watts(max(snapshot.maxPower - snapshot.totalPower, 0))) W free")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(model.isOnline ? KCStyle.charging : Color.secondary)
                            .frame(width: 6, height: 6)
                        if model.isOnline {
                            Text("Live")
                        } else {
                            Text(snapshot.fetchedAt, style: .relative)
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(model.isOnline ? KCStyle.charging : .secondary)

                    if ChargerSource.isDemo {
                        Text("Sample")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }

            if snapshot.history.count >= 2 {
                Chart(Array(snapshot.history.suffix(60)), id: \.date) { point in
                    AreaMark(x: .value("Time", point.date), y: .value("Power", point.watts))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [KCStyle.accent.opacity(0.24), KCStyle.accent.opacity(0.01)],
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
                .frame(height: 64)
                .accessibilityLabel("Recent power history")
            }
        }
        .padding(.vertical, 6)
    }

    private func portRow(_ port: PortSnapshot) -> some View {
        let batteryFraction = model.pdStatus[port.index]?.batteryFraction
        return HStack(spacing: 12) {
            Button { detail = port } label: {
                HStack(spacing: 11) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(port.isCharging ? 0.06 : 0.04))
                        Circle()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 2)
                        if let batteryFraction, port.isCharging {
                            Circle()
                                .trim(from: 0, to: batteryFraction)
                                .stroke(KCStyle.charging, style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        Text(KCFormat.portBadgeName(port))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(port.isCharging ? .primary : .tertiary)
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(port.deviceName ?? KCFormat.portDisplayName(port))
                                .font(.body.weight(.medium))
                                .foregroundStyle(port.isCharging ? .primary : .secondary)
                                .lineLimit(1)
                            if let batteryFraction, port.isCharging {
                                Text("\(Int((batteryFraction * 100).rounded()))%")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(KCStyle.charging)
                                    .monospacedDigit()
                            }
                        }
                        if port.isCharging {
                            Text(portSubtitle(port))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .lineLimit(1)
                        } else {
                            Text("Idle · Up to \(Int(port.maxPower)) W")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(port.isCharging ? "\(KCFormat.watts(port.power)) W" : (port.enabled ? "Idle" : "Off"))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(port.isCharging ? .primary : .tertiary)
                        PowerPressureMeter(
                            watts: port.isCharging ? port.power : 0,
                            maxWatts: port.maxPower,
                            segments: 6,
                            segmentWidth: 6,
                            segmentHeight: 6
                        )
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.quaternary)
                        .padding(.leading, 2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func portSubtitle(_ port: PortSnapshot) -> String {
        [
            KCFormat.protocolTag(port.protocolName),
            port.voltage > 0 ? KCFormat.volts(port.voltage) : nil,
            port.current > 0 ? KCFormat.amps(port.current) : nil
        ].compactMap { $0 }.joined(separator: " · ")
    }
}

struct PortBadge: View {
    let port: PortSnapshot

    var body: some View {
        Text(KCFormat.portBadgeName(port))
            .font(.caption.weight(.semibold))
            .frame(width: 34, height: 34)
            .foregroundStyle(port.isCharging ? Color.white : KCStyle.portTint(for: port))
            .background {
                Circle().fill(port.isCharging ? KCStyle.charging : Color.primary.opacity(0.06))
            }
            .overlay {
                if !port.isCharging {
                    Circle().strokeBorder(Color.primary.opacity(port.enabled ? 0.14 : 0.08), lineWidth: 1)
                }
            }
            .opacity(port.enabled ? 1 : 0.55)
    }
}

/// Fixed translucent-bleed sheet bug by using an explicit opaque grouped background
/// plus clean metric cards and on-demand USB PD / cable E-Marker telemetry.
struct PortDetailView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let port: PortSnapshot

    @State private var samples: [PortStatSample] = []
    @State private var loadingStats = false
    @State private var confirmOff = false

    private var livePort: PortSnapshot {
        model.snapshot?.ports.first(where: { $0.index == port.index }) ?? port
    }

    private var pd: PDStatus? {
        model.pdStatus[port.index]
    }

    private var displayedSamples: [PortStatSample] {
        if !samples.isEmpty { return samples }
        if ChargerSource.isDemo || model.snapshot?.deviceName == "Desk Charger" {
            return (0..<180).map { i in
                let watts = 46 + 14 * sin(Double(i) / 9) + (i > 120 ? -16 : 0)
                return PortStatSample(currentMa: watts / 20 * 1000, powerMw: watts * 1000, voltageMv: 20_000)
            }
        }
        return []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header with device icon + USB-PD battery ring + honest power action
                    HStack(spacing: 14) {
                        let batteryFraction = pd?.batteryFraction
                        ZStack {
                            Circle()
                                .fill(KCStyle.surfaceTile(for: colorScheme))
                            Circle()
                                .stroke(Color.primary.opacity(0.08), lineWidth: 2)
                            if let batteryFraction, livePort.isCharging {
                                Circle()
                                    .trim(from: 0, to: batteryFraction)
                                    .stroke(KCStyle.charging, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                            }
                            Image(systemName: KCDeviceSymbol.systemName(for: livePort))
                                .font(.system(size: 20))
                                .foregroundStyle(livePort.isCharging ? .primary : .secondary)
                        }
                        .frame(width: 48, height: 48)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(livePort.deviceName ?? KCFormat.portDisplayName(livePort))
                                .font(.title3.weight(.bold))
                            Text("\(KCFormat.portDisplayName(livePort)) · \(livePort.protocolName ?? (livePort.isCharging ? "Charging" : "Idle"))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if livePort.isCharging {
                            Button(role: .destructive) {
                                confirmOff = true
                            } label: {
                                Label("Cut Power", systemImage: "power")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button {
                                Task { await model.setPort(livePort.index, on: true) }
                            } label: {
                                Label("Wake", systemImage: "bolt.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    // Metrics + Hardware LED Pressure Meter
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            detailPill(title: "Power", value: "\(KCFormat.watts(livePort.power)) W", accent: true)
                            detailPill(title: "Voltage", value: KCFormat.volts(livePort.voltage))
                            detailPill(title: "Current", value: KCFormat.amps(livePort.current))
                        }

                        HStack {
                            Text("Port Pressure")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            PowerPressureMeter(
                                watts: livePort.isCharging ? livePort.power : 0,
                                maxWatts: livePort.maxPower,
                                segments: 8,
                                segmentWidth: 10,
                                segmentHeight: 8,
                                animated: ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
                            )
                            Text("of \(Int(livePort.maxPower)) W")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(KCStyle.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.75))
                    }

                    // 180-Sample Charger Memory Log Curve (matching macOS PortDetailCanvas)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Charger Memory Log")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if loadingStats {
                                ProgressView().controlSize(.small)
                            } else if !displayedSamples.isEmpty {
                                Text("\(displayedSamples.count) samples")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                            }
                        }

                        if displayedSamples.isEmpty {
                            Text("No memory samples recorded on this port yet.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 110, alignment: .center)
                        } else {
                            let peakY = max((displayedSamples.map { $0.powerMw / 1000 }.max() ?? 60) * 1.2, 20)
                            Chart(Array(displayedSamples.enumerated()), id: \.offset) { item in
                                AreaMark(x: .value("Sample", item.offset), y: .value("Watts", item.element.powerMw / 1000))
                                    .interpolationMethod(.monotone)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [KCStyle.accent.opacity(0.22), KCStyle.accent.opacity(0.0)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                LineMark(x: .value("Sample", item.offset), y: .value("Watts", item.element.powerMw / 1000))
                                    .interpolationMethod(.monotone)
                                    .foregroundStyle(KCStyle.accent)
                                    .lineStyle(StrokeStyle(lineWidth: 1.8))
                            }
                            .chartYScale(domain: 0...peakY)
                            .chartXAxis(.hidden)
                            .chartYAxis {
                                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.primary.opacity(0.06))
                                    AxisValueLabel {
                                        if let w = value.as(Double.self), w > 0 {
                                            Text("\(Int(w))W").font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
                                        }
                                    }
                                }
                            }
                            .frame(height: 125)
                        }
                    }
                    .padding(14)
                    .background(KCStyle.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.75))

                    // Telemetry & USB-PD / E-Marker specs card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("USB PD & Cable Telemetry")
                            .font(.subheadline.weight(.semibold))
                        specRow("Protocol", livePort.protocolName ?? "—")
                        specRow("Temperature", PortTemperature.localizedLabel(livePort.temperature) ?? "—")
                        if let mwh = livePort.sessionChargeMwh, mwh > 0 {
                            specRow("Session Energy", KCFormat.energy(mWh: mwh))
                        }
                        if let pd {
                            if let rev = pd.pdRevision { specRow("PD Revision", rev) }
                            if let v = pd.requestedVoltage {
                                specRow("Requested", String(format: "%.1f V / %.2f A", v, pd.requestedCurrent ?? 0))
                            }
                            if let pps = pd.ppsChargingSupported { specRow("PPS", pps ? "Supported" : "No") }
                            if let cable = pd.cableName { specRow("Cable", cable) }
                            if let maxV = pd.cableMaxVbusVoltage, let maxI = pd.cableMaxVbusCurrent {
                                specRow("Cable Rating", "\(maxV) · \(maxI)")
                            }
                        }
                    }
                    .padding(14)
                    .background(KCStyle.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.75))
                }
                .padding(16)
            }
            .background(KCStyle.canvasBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle(KCFormat.portDisplayName(livePort))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Cut power to \(KCFormat.portDisplayName(livePort))?", isPresented: $confirmOff, titleVisibility: .visible) {
                Button("Cut Power", role: .destructive) {
                    Task { await model.setPort(livePort.index, on: false) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                await model.loadPDStatusIfNeeded()
                await loadPortStats()
            }
        }
    }

    private func loadPortStats() async {
        guard !ChargerSource.isDemo, let api = try? ChargerAPI.current() else { return }
        loadingStats = true
        defer { loadingStats = false }
        if let res = try? await api.portStats(port: port.index) {
            samples = res.samples
        }
    }

    private func specRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.weight(.medium)).monospacedDigit()
        }
    }

    private func detailPill(title: String, value: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(accent ? KCStyle.accent : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(KCStyle.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.75))
    }
}

struct ModePickerView: View {
    @EnvironmentObject var model: AppModel
    @State private var pending: ChargingStrategy?

    var body: some View {
        List(ChargingStrategy.allCases) { strategy in
            Button {
                if strategy.needsConfirmation { pending = strategy }
                else { Task { await model.setStrategy(strategy) } }
            } label: {
                HStack {
                    Image(systemName: strategy.symbol)
                        .foregroundStyle(KCStyle.accent)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(strategy.localizedName)
                            .foregroundStyle(.primary)
                        Text(strategy.localizedSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.strategy == strategy {
                        Image(systemName: "checkmark")
                            .foregroundStyle(KCStyle.accent)
                    }
                }
                .padding(.vertical, 4)
            }
            .disabled(model.controlling)
        }
        .navigationTitle("Mode")
        .alert(
            "Change charging mode?",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })
        ) {
            Button("Apply") {
                if let pending { Task { await model.setStrategy(pending) } }
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            Text(pending?.localizedSummary ?? "")
        }
    }
}
