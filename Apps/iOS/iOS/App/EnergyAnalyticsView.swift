import SwiftUI
import KangChargeCore
import KangChargeUI

/// Dedicated iOS Daily Energy Analytics screen reusing the shared KangChargeUI chart suite.
struct EnergyAnalyticsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero metrics strip
                HStack(spacing: 12) {
                    metricTile("Today", KCFormat.energy(wattHours: model.energySummary.todayWattHours), accent: KCStyle.charging)
                    metricTile("Last 7 Days", KCFormat.energy(wattHours: model.energySummary.last7DaysWattHours))
                    metricTile("Streak", "\(model.energySummary.currentStreak)d")
                }

                card {
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

                card {
                    EnergyEquivalentsCard(totalWattHours: model.energySummary.totalWattHours)
                }

                card {
                    PortEnergyDonutChart(shares: model.energyAnalytics.portShares)
                }

                card {
                    EnergyTimePatternChart(analytics: model.energyAnalytics)
                }
            }
            .padding(16)
        }
        .background(KCStyle.canvasBackground(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Daily Energy")
        .navigationBarTitleDisplayMode(.large)
    }

    private func metricTile(_ title: String, _ value: String, accent: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(accent ?? .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(KCStyle.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.75))
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KCStyle.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.75))
    }
}
