import SwiftUI
import WidgetKit
import KangChargeCore

struct PowerProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChargerEntry { .placeholder }
    func getSnapshot(in context: Context, completion: @escaping (ChargerEntry) -> Void) {
        if context.isPreview {
            completion(ChargerEntry(
                date: .now,
                snapshot: SnapshotStore.load() ?? KCDemo.snapshot(),
                energySummary: ChargerSource.currentEnergySummary(weeks: 14),
                state: .live,
                isDemo: ChargerSource.isDemo
            ))
        } else {
            Task { completion(await ChargerEntry.load()) }
        }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ChargerEntry>) -> Void) {
        Task {
            let entry = await ChargerEntry.load()
            completion(Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: entry.state == .stale ? 5 * 60 : 15 * 60))))
        }
    }
}

struct PowerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.widgetKind, provider: PowerProvider()) { entry in
            PowerWidgetView(entry: entry)
        }
        .configurationDisplayName("Charger Power")
        .description("Live power, trend, and interactive port switches.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct EnergyHeatmapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.heatmapWidgetKind, provider: PowerProvider()) { entry in
            EnergyHeatmapWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Energy")
        .description("GitHub-style daily charging energy heatmap.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct KangChargeWidgets: WidgetBundle {
    var body: some Widget {
        PowerWidget()
        EnergyHeatmapWidget()
    }
}
