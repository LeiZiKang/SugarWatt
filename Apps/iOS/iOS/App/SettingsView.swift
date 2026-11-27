import SwiftUI
import KangChargeCore

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("kc.desk.keepAwake") private var deskKeepAwake = true
    @AppStorage("kc.desk.oledBlack") private var deskOLED = true
    @State private var iCloudSync = AppConfig.iCloudEnergySyncEnabled
    @State private var disconnecting = false
    @State private var clearingEnergy = false

    private var nickname: Binding<String> {
        Binding(get: { AppConfig.customDeviceName ?? "" }, set: { model.rename($0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Device") {
                    TextField("Device nickname", text: nickname)
                    LabeledContent("Model", value: SnapshotStore.loadFacts()?.localizedName ?? model.snapshot?.modelName ?? "—")
                    LabeledContent("Connection", value: ChargerSource.isDemo ? String(localized: "Sample data") : (AppConfig.serverURL?.host ?? "—"))
                    Button("Disconnect", role: .destructive) { disconnecting = true }
                        .disabled(!model.busyPorts.isEmpty || model.controlling)
                }

                Section {
                    Toggle("StandBy Mode (Keep Screen Awake)", isOn: $deskKeepAwake)
                    Toggle("Pure Black OLED Theme", isOn: $deskOLED)
                } header: {
                    Text("Landscape Desk Dashboard")
                } footer: {
                    Text("Rotate your iPhone sideways to turn it into an always-on charging dashboard. Enable StandBy Mode to keep the display awake while docked.")
                }

                Section {
                    Toggle("Sync daily energy via iCloud", isOn: Binding(
                        get: { iCloudSync },
                        set: { value in
                            iCloudSync = value
                            AppConfig.iCloudEnergySyncEnabled = value
                            if value {
                                EnergyLedger.shared.pullFromCloud()
                                EnergyLedger.shared.pushToCloudNow()
                            }
                        }
                    ))
                    Button("Clear Energy History", role: .destructive) { clearingEnergy = true }
                } header: {
                    Text("Daily Energy")
                } footer: {
                    Text("Automatically merges daily charging energy across your Mac and iPhone using your private iCloud Key-Value Store.")
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.0")
                    Link("Source code on GitHub", destination: URL(string: "https://github.com/LeiZiKang/KangCharge-iOS")!)
                    Text("MIT License · Free on App Store")
                } header: {
                    Text("About")
                } footer: {
                    Text("SugarWatt is an independent app and is not affiliated with CANDYSIGN.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Disconnect this charger?", isPresented: $disconnecting, titleVisibility: .visible) {
                Button("Disconnect", role: .destructive) {
                    Task { await model.disconnect(); dismiss() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The saved address and charger data will be removed from this iPhone.")
            }
            .confirmationDialog("Clear daily energy history?", isPresented: $clearingEnergy, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { model.resetEnergyHistory() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
