import SwiftUI

// MARK: - Provider Dropdown
// Two-level menu: capsule shows active model name (e.g. "Sonnet 4.6").
// Menu opens to show model list for current provider, plus a submenu to switch providers.
// Used in both the chat toolbar and command palette tools row.

struct ProviderDropdown: View {
    @Environment(UIState.self) private var ui
    @Environment(InferenceState.self) private var inference

    private var provider: LLMProviderType { inference.apiProvider }

    var body: some View {
        Menu {
            // ── Current provider's models ──
            let models = inference.availableModels
            if !models.isEmpty {
                ForEach(models, id: \.id) { m in
                    Button {
                        inference.setActiveModel(m.id)
                    } label: {
                        HStack {
                            Text(m.name)
                            if m.id == inference.activeModel {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(m.id == inference.activeModel)
                }

                Divider()
            }

            // ── Switch provider ──
            Menu("Switch Provider") {
                ForEach(availableProviders, id: \.self) { p in
                    Button {
                        selectProvider(p)
                    } label: {
                        Label {
                            Text(p.displayName)
                        } icon: {
                            Image(systemName: p.iconName)
                        }
                    }
                    .disabled(p == provider)
                }
            }
        } label: {
            Label(inference.activeModelDisplayName, systemImage: "cpu")
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Helpers

    private var availableProviders: [LLMProviderType] {
        var providers: [LLMProviderType] = [.anthropic, .openai, .google, .kimi]
        if inference.ollamaAvailable {
            providers.append(.ollama)
        }
        return providers
    }

    private func selectProvider(_ p: LLMProviderType) {
        inference.setApiProvider(p)

        // Check if the newly selected provider needs an API key but doesn't have one
        if inference.needsApiKey && inference.apiKey.isEmpty {
            ui.showToast("No API key for \(p.displayName) — set it in Settings", type: .warning)
        }
    }
}
