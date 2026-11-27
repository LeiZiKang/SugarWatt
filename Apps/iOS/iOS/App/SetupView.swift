import SwiftUI
import KangChargeCore
import KangChargeUI

struct SetupView: View {
    @EnvironmentObject var model: AppModel
    @State private var url = ""
    @State private var nickname = ""
    @State private var extractedHint: String?
    @State private var pasteError: String?

    private var hasValidURL: Bool { AppConfig.validatedServerURL(url) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "bolt.fill")
                            .font(.largeTitle)
                            .foregroundStyle(KCStyle.accent)
                            .frame(width: 68, height: 68)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(red: 0.985, green: 0.980, blue: 0.968))
                                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                            )
                        Text("SugarWatt")
                            .font(.largeTitle.weight(.semibold))
                        Text("Minimalist power monitor and control center for your CANDYSIGN CoCan charger.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section {
                    HStack {
                        TextField("Paste CANDYSIGN MCP text or /sse URL", text: $url)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .privacySensitive()
                            .onChange(of: url) { _, newValue in
                                if let extracted = AppConfig.extractMCPInput(from: newValue), extracted.extractedFromText {
                                    url = extracted.url.absoluteString
                                    if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                       let suggested = extracted.suggestedNickname {
                                        nickname = suggested
                                    }
                                    extractedHint = String(localized: "Extracted MCP server URL automatically.")
                                    pasteError = nil
                                }
                            }
                        Button {
                            pasteFromClipboard()
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if let extractedHint {
                        Label(extractedHint, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(KCStyle.charging)
                    }

                    TextField("Nickname (optional)", text: $nickname)
                    Button {
                        Task { await model.connect(urlString: url, nickname: nickname) }
                    } label: {
                        HStack {
                            Spacer()
                            if model.connecting { ProgressView() }
                            Text("Connect")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasValidURL || model.connecting)

                    if let error = pasteError ?? model.lastError {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("You can paste the full text copied from the CANDYSIGN app — SugarWatt automatically extracts the /sse server URL. Stored locally in your iPhone Keychain.")
                }

                Section {
                    DisclosureGroup("Where do I find this?") {
                        Text("In the CANDYSIGN app, open your charger's MCP settings and tap Copy. Then tap Paste above — SugarWatt extracts the /sse URL for you.")
                    }
                    Button("Try with Sample Data") { model.startDemo() }
                        .disabled(model.connecting)
                } footer: {
                    Text("SugarWatt is an independent open-source app and is not affiliated with CANDYSIGN.")
                }
            }
            .disabled(model.connecting)
        }
    }

    private func pasteFromClipboard() {
        guard let raw = UIPasteboard.general.string,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            pasteError = String(localized: "Clipboard is empty.")
            extractedHint = nil
            return
        }
        if let extracted = AppConfig.extractMCPInput(from: raw) {
            url = extracted.url.absoluteString
            if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let suggested = extracted.suggestedNickname {
                nickname = suggested
            }
            extractedHint = extracted.extractedFromText
                ? String(localized: "Extracted MCP server URL from copied text.")
                : String(localized: "Pasted MCP server URL.")
            pasteError = nil
        } else {
            url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            extractedHint = nil
            pasteError = String(localized: "Couldn't find an MCP server URL ending in /sse in the clipboard.")
        }
    }
}
