#if EPISTEMOS_BASE_JUNE
import SwiftUI

struct JuneCloudSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configuration = JuneCloudConfigurationStore.shared
    @State private var drafts: [JuneCloudProvider: String] = [:]
    @State private var status: [JuneCloudProvider: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("June uses cloud models only. Credentials are stored in Apple Keychain and are exposed only to June's in-process Goose agent while a turn is running.")
                        .foregroundStyle(.secondary)
                }

                ForEach(JuneCloudProvider.allCases, id: \.self) { provider in
                    Section(provider.displayName) {
                        SecureField("API key", text: draftBinding(for: provider))
                            .textContentType(.password)

                        HStack {
                            Button("Save Key") { save(provider) }
                            if configuration.isConfigured(provider) {
                                Button("Remove Key", role: .destructive) {
                                    configuration.deleteAPIKey(for: provider)
                                    drafts[provider] = ""
                                    status[provider] = "Removed"
                                }
                            }
                            Spacer()
                            Text(configuration.isConfigured(provider) ? "Configured" : "Not configured")
                                .foregroundStyle(configuration.isConfigured(provider) ? .green : .secondary)
                        }

                        Toggle(
                            "Allow June to send prompts and selected context to \(provider.displayName)",
                            isOn: Binding(
                                get: { configuration.hasConsent(provider) },
                                set: { configuration.setConsent($0, for: provider) }
                            )
                        )

                        Text("When enabled, June may send the current prompt, bounded chat history, and approved tool context to \(provider.dataDestination). The key stays in Keychain.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let status = status[provider] {
                            Text(status).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Models") {
                    Text("Choose the active cloud model from June's model control.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("June Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 560)
    }

    private func draftBinding(for provider: JuneCloudProvider) -> Binding<String> {
        Binding(
            get: { drafts[provider] ?? "" },
            set: { drafts[provider] = $0 }
        )
    }

    private func save(_ provider: JuneCloudProvider) {
        guard configuration.saveAPIKey(drafts[provider] ?? "", for: provider) else {
            status[provider] = "Enter a non-empty key that can be saved to Apple Keychain."
            return
        }
        drafts[provider] = ""
        status[provider] = "Saved to Apple Keychain"
    }
}
#endif
