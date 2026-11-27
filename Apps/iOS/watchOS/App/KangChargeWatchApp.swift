import SwiftUI
import KangChargeCore
import KangChargeUI

@main
struct KangChargeWatchApp: App {
    @StateObject private var model = WatchModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            let tabArg = UserDefaults.standard.integer(forKey: "kcWatchTab")
            WatchHomeView(model: model, initialTab: tabArg)
                .tint(KCStyle.accent)
                .task { model.setActive(scenePhase == .active) }
                .onChange(of: scenePhase) { _, phase in model.setActive(phase == .active) }
        }
    }
}

/// Restrained 3-page watchOS 10+ Digital Crown experience matching the SugarWatt design language:
/// 1) Sculpted circular power ring overview, 2) Honest 5-port cards with LED pressure meters, 3) Today's Energy.
struct WatchHomeView: View {
    @ObservedObject var model: WatchModel
    var initialTab: Int = 0
    @State private var selectedTab: Int
    @State private var pendingPort: PortSnapshot?

    init(model: WatchModel, initialTab: Int = 0) {
        self.model = model
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        Group {
            if !model.isConfigured {
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.98, green: 0.976, blue: 0.965))
                            .frame(width: 42, height: 42)
                        Image(systemName: "bolt.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(KCStyle.accent)
                    }
                    Text("SugarWatt")
                        .font(.headline)
                    Text("Open SugarWatt on your iPhone to connect.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Sample Data") { Task { await model.startDemo() } }
                        .font(.caption2)
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 8)
            } else if let snapshot = model.snapshot {
                NavigationStack {
                    TabView(selection: $selectedTab) {
                        overviewPage(snapshot)
                            .tag(0)
                        portsPage(snapshot)
                            .tag(1)
                        energyPage()
                            .tag(2)
                    }
                    .tabViewStyle(.verticalPage)
                    .navigationTitle(snapshot.deviceName)
                    .navigationBarTitleDisplayMode(.inline)
                }
            } else {
                VStack(spacing: 10) {
                    if model.isOnline { ProgressView() }
                    Text("Waiting for charger…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Refresh") { Task { await model.refresh() } }
                        .font(.caption)
                }
                .padding()
            }
        }
        .confirmationDialog("Cut power to \(pendingPort.map(KCFormat.portDisplayName) ?? "port")?", isPresented: Binding(
            get: { pendingPort != nil }, set: { if !$0 { pendingPort = nil } }
        ), titleVisibility: .visible) {
            if let port = pendingPort {
                Button("Cut Power", role: .destructive) {
                    pendingPort = nil
                    Task { await model.setPort(port.index, on: false) }
                }
            }
            Button("Cancel", role: .cancel) { pendingPort = nil }
        } message: {
            Text("\(pendingPort?.deviceName ?? "Connected device") will stop charging.")
        }
        .alert("Couldn't update port", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    // MARK: - Page 1: Circular Load Ring Overview

    private func overviewPage(_ snapshot: ChargerSnapshot) -> some View {
        let fraction = snapshot.maxPower > 0 ? min(max(snapshot.totalPower / snapshot.maxPower, 0), 1) : 0
        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 8.5)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(KCStyle.accent, style: StrokeStyle(lineWidth: 8.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: fraction)
                VStack(spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(KCFormat.watts(snapshot.totalPower))
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text("W")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("\(Int((fraction * 100).rounded()))% · \(Int(snapshot.maxPower))W")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 8)
            }
            .frame(width: 104, height: 104)
            .accessibilityElement(children: .combine)

            HStack(spacing: 5) {
                Circle()
                    .fill(model.isOnline ? KCStyle.charging : .secondary)
                    .frame(width: 6, height: 6)
                Text(model.isOnline ? "Live" : "Cached")
                    .foregroundStyle(model.isOnline ? KCStyle.charging : .secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(snapshot.chargingCount) charging")
                    .foregroundStyle(.primary)
            }
            .font(.caption2.weight(.medium))
            .monospacedDigit()
        }
        .padding(.top, 2)
    }

    // MARK: - Page 2: 5-Port Cards with Device Symbols & LED Pressure Meters

    private func portsPage(_ snapshot: ChargerSnapshot) -> some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(snapshot.ports) { port in
                    Button {
                        if port.isCharging {
                            pendingPort = port
                        } else {
                            Task { await model.setPort(port.index, on: true) }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.white.opacity(port.isCharging ? 0.12 : 0.06))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Image(systemName: KCDeviceSymbol.systemName(for: port))
                                        .font(.system(size: 12))
                                        .foregroundStyle(port.isCharging ? KCStyle.charging : .secondary)
                                }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(port.deviceName ?? KCFormat.portDisplayName(port))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(port.isCharging ? .primary : .secondary)
                                    .lineLimit(1)
                                Text(port.isCharging ? KCFormat.portDisplayName(port) : "Idle")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 2)

                            VStack(alignment: .trailing, spacing: 3) {
                                Text(port.isCharging ? "\(KCFormat.watts(port.power))W" : "—")
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(port.isCharging ? .primary : .secondary)
                                PowerPressureMeter(
                                    watts: port.isCharging ? port.power : 0,
                                    maxWatts: port.maxPower,
                                    segments: 5,
                                    segmentWidth: 4.5,
                                    segmentHeight: 4.5,
                                    animated: ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
                                )
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.busyPorts.isEmpty)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Page 3: Today's Energy & 7-Day Strip

    private func energyPage() -> some View {
        let recent = Array(model.energySummary.days.suffix(7))
        let maxWh = max(recent.map(\.wattHours).max() ?? 100, 50)
        return VStack(alignment: .leading, spacing: 8) {
            Label("Daily Energy", systemImage: "bolt.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(KCStyle.charging)

            Text(KCFormat.energy(wattHours: model.energySummary.todayWattHours))
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 6) {
                Text("7d \(KCFormat.energy(wattHours: model.energySummary.last7DaysWattHours))")
                Text("·").foregroundStyle(.tertiary)
                Text("\(model.energySummary.currentStreak)d streak")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()

            // Mini 7-day energy bar strip
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(recent) { day in
                    let h = max(4, CGFloat(day.wattHours / maxWh) * 28)
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(day.wattHours >= 1 ? KCStyle.charging : Color.white.opacity(0.12))
                        .frame(maxWidth: .infinity)
                        .frame(height: h)
                }
            }
            .frame(height: 30, alignment: .bottom)
            .padding(.top, 2)
        }
        .padding(.horizontal, 8)
    }
}
