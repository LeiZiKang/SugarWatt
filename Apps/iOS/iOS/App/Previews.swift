import SwiftUI
import KangChargeCore
import KangChargeUI

#Preview("1. iPhone Portrait · Light") {
    HomeView()
        .environmentObject(AppModel(previewDemo: true))
        .preferredColorScheme(.light)
}

#Preview("2. iPhone Portrait · Dark") {
    HomeView()
        .environmentObject(AppModel(previewDemo: true))
        .preferredColorScheme(.dark)
}

#Preview("3. Landscape Desk Dashboard · OLED Black", traits: .landscapeLeft) {
    LandscapeDashboardView()
        .environmentObject(AppModel(previewDemo: true))
}

#Preview("4. Daily Energy Analytics") {
    NavigationStack {
        EnergyAnalyticsView()
            .environmentObject(AppModel(previewDemo: true))
    }
}

#Preview("5. Port Detail (C1)") {
    let model = AppModel(previewDemo: true)
    PortDetailView(port: model.snapshot!.ports[1])
        .environmentObject(model)
}

#Preview("6. Setup · Smart Paste") {
    SetupView()
        .environmentObject(AppModel(previewDemo: false))
}

#Preview("7. Landscape Desk · Calendar Heatmap", traits: .landscapeLeft) {
    LandscapeDashboardView(initialRightPanel: .heatmap)
        .environmentObject(AppModel(previewDemo: true))
}

#Preview("8. Customize Home Modules") {
    CustomizeHomeView(layout: HomeLayoutStore(previewWidgetGrid: true))
}

#Preview("9. Widget Board · Edit Mode (1×1 + 2×1)") {
    NavigationStack {
        ScrollView {
            WidgetBoardCanvas(
                layout: HomeLayoutStore(previewWidgetGrid: true),
                isEditing: .constant(true),
                showingGallery: .constant(false),
                snapshot: KCDemo.snapshot(),
                onSelectPort: { _ in },
                onRequestTurnOff: { _ in }
            )
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Desk Charger")
    }
    .environmentObject(AppModel(previewDemo: true))
}
