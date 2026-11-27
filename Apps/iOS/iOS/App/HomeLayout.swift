import SwiftUI
import KangChargeCore
import KangChargeUI

/// Size span of a widget tile on the modular 2-column dashboard canvas (like iOS Home Screen widgets).
enum WidgetSpan: String, Codable, Hashable {
    case compact // 1 column (square 1x1)
    case wide    // 2 columns (full width 2x1)
}

/// Modular dashboard widgets that users can freely combine, resize (1x1 / 2x1),
/// drag-and-drop to rearrange, and show/hide on both Portrait and Landscape canvases.
enum HomeModule: String, CaseIterable, Identifiable, Codable {
    case hero
    case powerRing
    case todayEnergy
    case ports
    case heatmap
    case equivalents
    case portDonut
    case rhythm
    case controls

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hero: return String(localized: "Live Power & Curve")
        case .powerRing: return String(localized: "Power Ring")
        case .todayEnergy: return String(localized: "Today's Energy")
        case .ports: return String(localized: "All 5 Ports")
        case .heatmap: return String(localized: "Calendar Heatmap")
        case .equivalents: return String(localized: "Energy Equivalents")
        case .portDonut: return String(localized: "Energy by Port")
        case .rhythm: return String(localized: "Charging Rhythm")
        case .controls: return String(localized: "Charging Controls")
        }
    }

    var symbol: String {
        switch self {
        case .hero: return "bolt.circle.fill"
        case .powerRing: return "gauge.with.dots.needle.67percent"
        case .todayEnergy: return "flame.fill"
        case .ports: return "cable.connector"
        case .heatmap: return "calendar"
        case .equivalents: return "sparkles"
        case .portDonut: return "chart.pie.fill"
        case .rhythm: return "chart.xyaxis.line"
        case .controls: return "slider.horizontal.3"
        }
    }

    var defaultSpan: WidgetSpan {
        switch self {
        case .powerRing, .todayEnergy: return .compact
        default: return .wide
        }
    }

    var supportsCompact: Bool {
        switch self {
        case .powerRing, .todayEnergy, .equivalents, .controls: return true
        default: return false
        }
    }

    static let defaultOrder: [HomeModule] = [
        .hero, .powerRing, .todayEnergy, .ports, .heatmap, .controls, .equivalents, .portDonut, .rhythm
    ]

    static let defaultEnabled: Set<HomeModule> = [
        .hero, .ports, .heatmap, .controls
    ]
}

struct HomeModuleItem: Codable, Hashable, Identifiable {
    var module: HomeModule
    var enabled: Bool
    var span: WidgetSpan
    var id: String { module.rawValue }

    init(module: HomeModule, enabled: Bool, span: WidgetSpan? = nil) {
        self.module = module
        self.enabled = enabled
        self.span = span ?? module.defaultSpan
    }
}

/// Persists the user's custom widget board order, visibility, and 1x1 / 2x1 sizes.
@MainActor
final class HomeLayoutStore: ObservableObject {
    private static let storageKey = "sugarwatt.ios.homeLayout.v2"

    @Published var items: [HomeModuleItem] {
        didSet { save() }
    }

    init(previewWidgetGrid: Bool = false) {
        if previewWidgetGrid {
            self.items = [
                HomeModuleItem(module: .powerRing, enabled: true, span: .compact),
                HomeModuleItem(module: .todayEnergy, enabled: true, span: .compact),
                HomeModuleItem(module: .ports, enabled: true, span: .wide),
                HomeModuleItem(module: .heatmap, enabled: true, span: .wide),
                HomeModuleItem(module: .equivalents, enabled: true, span: .wide),
                HomeModuleItem(module: .controls, enabled: false, span: .wide),
                HomeModuleItem(module: .hero, enabled: false, span: .wide),
                HomeModuleItem(module: .portDonut, enabled: false, span: .wide),
                HomeModuleItem(module: .rhythm, enabled: false, span: .wide),
            ]
            return
        }
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([HomeModuleItem].self, from: data),
           !decoded.isEmpty {
            let existing = Set(decoded.map(\.module))
            let missing = HomeModule.defaultOrder.filter { !existing.contains($0) }
                .map { HomeModuleItem(module: $0, enabled: HomeModule.defaultEnabled.contains($0)) }
            self.items = decoded + missing
        } else {
            self.items = Self.makeDefault()
        }
    }

    var visibleItems: [HomeModuleItem] {
        let active = items.filter(\.enabled)
        return active.isEmpty ? [HomeModuleItem(module: .hero, enabled: true), HomeModuleItem(module: .ports, enabled: true)] : active
    }

    var visibleModules: [HomeModule] {
        visibleItems.map(\.module)
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    /// Direct drag-and-drop swap on the iOS Home-Screen-style widget grid.
    func moveItem(_ dragged: HomeModule, before target: HomeModule) {
        guard dragged != target,
              let fromIndex = items.firstIndex(where: { $0.module == dragged }),
              let toIndex = items.firstIndex(where: { $0.module == target }) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            let item = items.remove(at: fromIndex)
            items.insert(item, at: toIndex)
        }
    }

    func toggle(_ module: HomeModule) {
        guard let idx = items.firstIndex(where: { $0.module == module }) else { return }
        if items[idx].enabled && items.filter(\.enabled).count <= 1 { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            items[idx].enabled.toggle()
        }
    }

    func toggleSpan(_ module: HomeModule) {
        guard module.supportsCompact,
              let idx = items.firstIndex(where: { $0.module == module }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            items[idx].span = (items[idx].span == .compact) ? .wide : .compact
        }
    }

    func reset() {
        items = Self.makeDefault()
    }

    /// Packs visible items into clean 2-column rows (two `.compact` 1x1 tiles share a row; `.wide` takes full width).
    func packedRows() -> [[HomeModuleItem]] {
        var rows: [[HomeModuleItem]] = []
        var pendingCompact: HomeModuleItem?

        for item in visibleItems {
            if item.span == .wide {
                if let pending = pendingCompact {
                    rows.append([pending])
                    pendingCompact = nil
                }
                rows.append([item])
            } else {
                if let pending = pendingCompact {
                    rows.append([pending, item])
                    pendingCompact = nil
                } else {
                    pendingCompact = item
                }
            }
        }
        if let pending = pendingCompact {
            rows.append([pending])
        }
        return rows
    }

    private static func makeDefault() -> [HomeModuleItem] {
        HomeModule.defaultOrder.map {
            HomeModuleItem(module: $0, enabled: HomeModule.defaultEnabled.contains($0))
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

/// Widget Gallery & Reorder Sheet (combines direct 1x1 / 2x1 widget picking with drag-to-reorder).
struct CustomizeHomeView: View {
    @ObservedObject var layout: HomeLayoutStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(layout.items) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.module.symbol)
                                .font(.body)
                                .foregroundStyle(item.enabled ? KCStyle.accent : .secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.module.title)
                                    .foregroundStyle(item.enabled ? .primary : .secondary)
                                if item.module.supportsCompact && item.enabled {
                                    Text(item.span == .compact ? "1×1 Square" : "2×1 Full Width")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if item.module.supportsCompact && item.enabled {
                                Button(item.span == .compact ? "1×1" : "2×1") {
                                    layout.toggleSpan(item.module)
                                }
                                .font(.caption2.weight(.semibold))
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                            Toggle("", isOn: Binding(
                                get: { item.enabled },
                                set: { _ in layout.toggle(item.module) }
                            ))
                            .labelsHidden()
                            .tint(KCStyle.charging)
                        }
                    }
                    .onMove(perform: layout.move)
                } header: {
                    Text("Widget Board")
                } footer: {
                    Text("Add, resize (1×1 or 2×1), and drag widgets to compose your ideal SugarWatt screen — or long-press directly on any widget on the Home canvas to drag & rearrange.")
                }

                Section {
                    Button("Reset to Default Layout", role: .destructive) {
                        withAnimation { layout.reset() }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Widget Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
