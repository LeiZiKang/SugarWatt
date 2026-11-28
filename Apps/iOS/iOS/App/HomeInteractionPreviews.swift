import SwiftUI
import KangChargeCore
import KangChargeUI

// MARK: - Interactive Navigation & Widget Store Prototypes (For Xcode Live Previews)

private enum HomeNavOption {
    case optionA_DevicePill
    case optionB_PlusAndMenu
    case optionC_DualTab
}

private enum WidgetStoreCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case live = "Live Power"
    case energy = "Energy"
    case controls = "Controls"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .live: return "bolt.fill"
        case .energy: return "chart.bar.fill"
        case .controls: return "slider.horizontal.3"
        }
    }

    func matches(_ module: HomeModule) -> Bool {
        switch self {
        case .all: return true
        case .live: return [.hero, .powerRing, .ports].contains(module)
        case .energy: return [.todayEnergy, .heatmap, .equivalents, .portDonut, .rhythm].contains(module)
        case .controls: return module == .controls
        }
    }
}

private struct HomeInteractionPrototype: View {
    let style: HomeNavOption
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var layout = HomeLayoutStore(previewWidgetGrid: true)
    @State private var editingBoard = false
    @State private var showingWidgetStore = false
    @State private var showingSettings = false
    @State private var selectedTab = 0
    @State private var selectedPort: PortSnapshot?
    @State private var showNavTip = true

    var body: some View {
        Group {
            if style == .optionC_DualTab {
                TabView(selection: $selectedTab) {
                    boardNavigationStack
                        .tabItem {
                            Label("Dashboard", systemImage: "bolt.circle.fill")
                        }
                        .tag(0)

                    SettingsView()
                        .environmentObject(model)
                        .tabItem {
                            Label("Device", systemImage: "cpu")
                        }
                        .tag(1)
                }
                .tint(KCStyle.accent)
            } else {
                boardNavigationStack
            }
        }
        .sheet(isPresented: $showingWidgetStore) {
            WidgetStoreSheetPrototype(layout: layout, snapshot: model.snapshot ?? KCDemo.snapshot())
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(model)
        }
        .sheet(item: $selectedPort) { port in
            PortDetailView(port: port)
                .environmentObject(model)
                .presentationDetents([.medium, .large])
                .presentationBackground(Color(.systemGroupedBackground))
        }
    }

    private var boardNavigationStack: some View {
        NavigationStack {
            ScrollView {
                if let snapshot = model.snapshot {
                    VStack(alignment: .leading, spacing: 14) {
                        // Dismissible Apple-style contextual Tip banner for Option B top-right buttons
                        if style == .optionB_PlusAndMenu && showNavTip && !editingBoard {
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
                                        showNavTip = false
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
                            showingGallery: $showingWidgetStore,
                            snapshot: snapshot,
                            onSelectPort: { selectedPort = $0 },
                            onRequestTurnOff: { _ in }
                        )

                        // Subtle first-time hint replacing the old permanent "Edit Widgets" toolbar button
                        if !editingBoard {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.caption)
                                    .foregroundStyle(KCStyle.accent)
                                Text("Long-press any widget to jiggle, drag & rearrange, or open the Widget Store.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.035))
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .background(KCStyle.canvasBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle(model.snapshot?.deviceName ?? "Desk Charger")
            .toolbar {
                // During jiggle edit mode, ALL options show native iOS Home Screen controls (+ and Done)
                if editingBoard {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingWidgetStore = true
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
                    switch style {
                    case .optionA_DevicePill:
                        // Option A: Single live device status pill on top-right (zero toolbar clutter)
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingSettings = true
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 7, height: 7)
                                    Text(String(format: "%.0fW", model.snapshot?.totalPower ?? 0))
                                        .font(.caption.weight(.bold))
                                        .monospacedDigit()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.07))
                                )
                            }
                            .buttonStyle(.plain)
                        }

                    case .optionB_PlusAndMenu:
                        // Option B: Polished frosted glass "+" (Widget Store) + "..." (Menu)
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showingWidgetStore = true
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
                                        showingWidgetStore = true
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
                                        showingSettings = true
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

                    case .optionC_DualTab:
                        // Option C: Zero top buttons in normal mode; Settings lives in bottom Device tab
                        ToolbarItem(placement: .topBarTrailing) {
                            EmptyView()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Interactive Widget Store Sheet Prototype

struct WidgetStoreSheetPrototype: View {
    @ObservedObject var layout: HomeLayoutStore
    let snapshot: ChargerSnapshot

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var category: WidgetStoreCategory = .all
    @State private var preferredSpans: [HomeModule: WidgetSpan] = [:]

    private var filteredModules: [HomeModule] {
        HomeModule.allCases.filter { category.matches($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Category filter bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(WidgetStoreCategory.allCases) { cat in
                                let selected = category == cat
                                Button {
                                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                                        category = cat
                                    }
                                } label: {
                                    Label(cat.rawValue, systemImage: cat.symbol)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule()
                                                .fill(selected ? KCStyle.accent : Color.primary.opacity(0.07))
                                        )
                                        .foregroundStyle(selected ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Live Widget Store Cards
                    VStack(spacing: 14) {
                        ForEach(filteredModules) { module in
                            widgetStoreCard(for: module)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Widget Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func widgetStoreCard(for module: HomeModule) -> some View {
        let existing = layout.items.first(where: { $0.module == module })
        let isAdded = existing?.enabled ?? false
        let span = preferredSpans[module] ?? existing?.span ?? module.defaultSpan

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: module.symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(KCStyle.accent)
                    .frame(width: 32, height: 32)
                    .background(KCStyle.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(module.title)
                        .font(.subheadline.weight(.bold))
                    Text(widgetSubtitle(for: module))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    toggleModule(module, span: span)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isAdded ? "checkmark" : "plus")
                            .font(.caption.weight(.bold))
                        Text(isAdded ? "Added" : "Add")
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isAdded ? Color.green.opacity(0.16) : KCStyle.accent)
                    )
                    .foregroundStyle(isAdded ? Color.green : Color.white)
                }
                .buttonStyle(.plain)
            }

            // Live mini preview of the widget rendered with real snapshot telemetry
            miniLivePreview(for: module, span: span)

            // Size toggle when widget supports both 1x1 and 2x1
            if module.supportsCompact {
                HStack {
                    Text("Tile Size")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { span },
                        set: { newSpan in
                            preferredSpans[module] = newSpan
                            if let idx = layout.items.firstIndex(where: { $0.module == module }) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    layout.items[idx].span = newSpan
                                }
                            }
                        }
                    )) {
                        Text("1×1 Square").tag(WidgetSpan.compact)
                        Text("2×1 Wide").tag(WidgetSpan.wide)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func miniLivePreview(for module: HomeModule, span: WidgetSpan) -> some View {
        let isCompact = span == .compact && module.supportsCompact
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                switch module {
                case .powerRing, .hero:
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", snapshot.totalPower))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("W")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text("\(snapshot.ports.filter { $0.power > 0.5 }.count) active ports · \(Int(snapshot.maxPower))W max")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                case .todayEnergy:
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("148")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("Wh")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text("Today's cumulative output")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                case .ports:
                    HStack(spacing: 6) {
                        ForEach(snapshot.ports.prefix(5)) { port in
                            VStack(spacing: 2) {
                                Text(port.name).font(.system(size: 10, weight: .bold))
                                Text(port.power > 0.5 ? "\(Int(port.power))W" : "–")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(port.power > 0.5 ? KCStyle.accent : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
                        }
                    }
                case .heatmap:
                    HStack(spacing: 3) {
                        ForEach(0..<14, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(KCStyle.accent.opacity(i % 3 == 0 ? 0.85 : (i % 2 == 0 ? 0.35 : 0.12)))
                                .frame(height: 16)
                        }
                    }
                case .equivalents:
                    HStack(spacing: 8) {
                        Image(systemName: "iphone")
                            .foregroundStyle(KCStyle.accent)
                        Text("≈ 8.7 iPhone 16 Pro charges")
                            .font(.caption.weight(.semibold))
                    }
                case .portDonut:
                    HStack(spacing: 8) {
                        Circle()
                            .stroke(KCStyle.accent, lineWidth: 5)
                            .frame(width: 24, height: 24)
                        Text("C1 62% · C2 24% · C4 14%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .rhythm:
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach([8, 14, 22, 18, 26, 12, 20], id: \.self) { h in
                            Capsule()
                                .fill(KCStyle.accent.opacity(0.8))
                                .frame(width: 8, height: CGFloat(h))
                        }
                    }
                case .controls:
                    HStack(spacing: 6) {
                        ForEach(["Smart", "Sleep", "Perf"], id: \.self) { label in
                            Text(label)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(label == "Smart" ? KCStyle.accent : Color.primary.opacity(0.08), in: Capsule())
                                .foregroundStyle(label == "Smart" ? .white : .primary)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: isCompact ? 175 : .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(KCStyle.canvasBackground(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
            if isCompact { Spacer() }
        }
    }

    private func widgetSubtitle(for module: HomeModule) -> String {
        switch module {
        case .hero: return "Live total wattage with real-time load curve"
        case .powerRing: return "Compact circular power gauge (1×1 or 2×1)"
        case .todayEnergy: return "Daily Wh counter synced across Mac & iPhone"
        case .ports: return "Live wattage, protocol & switches for all 5 ports"
        case .heatmap: return "GitHub-style daily charging energy calendar"
        case .equivalents: return "Turns raw kWh into fun real-world comparisons"
        case .portDonut: return "Share of total charging energy by port"
        case .rhythm: return "Hourly & weekday charging pattern chart"
        case .controls: return "Quick charging mode & thermal policy switches"
        }
    }

    private func toggleModule(_ module: HomeModule, span: WidgetSpan) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            if let idx = layout.items.firstIndex(where: { $0.module == module }) {
                layout.items[idx].enabled.toggle()
                layout.items[idx].span = span
            } else {
                layout.items.append(HomeModuleItem(module: module, enabled: true, span: span))
            }
        }
    }
}

// MARK: - Xcode Live Previews (Compare Options A / B / C & Widget Store)

#Preview("Option A · Device Pill Header") {
    HomeInteractionPrototype(style: .optionA_DevicePill)
        .environmentObject(AppModel(previewDemo: true))
}

#Preview("Option B · Native + & ••• Menu") {
    HomeInteractionPrototype(style: .optionB_PlusAndMenu)
        .environmentObject(AppModel(previewDemo: true))
}

#Preview("Option C · Dual Tab Bar") {
    HomeInteractionPrototype(style: .optionC_DualTab)
        .environmentObject(AppModel(previewDemo: true))
}

#Preview("Widget Store · Interactive Gallery") {
    WidgetStoreSheetPrototype(
        layout: HomeLayoutStore(previewWidgetGrid: true),
        snapshot: KCDemo.snapshot()
    )
}
