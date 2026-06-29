import SwiftUI

/// Native Epistemos "Models" surface — the SAFE FIRST native route of the per-route migration.
///
/// Parity contract with the WebView oracle (`/settings?section=models`): every provider and model
/// shown here is LIVE-ENUMERATED from the same ACP connection the WebView uses
/// (`liveProviderCatalog` / `liveProviderSupportedModels`), and the current selection is read from
/// (`liveDefaults`) and written to (`saveLiveDefaults`) the same `_goose/unstable/defaults` methods.
/// Nothing is Swift-hardcoded (GOLDEN RULE). When the bridge is not connected the view shows an
/// honest blocked state instead of inventing a roster.
struct GooseNativeModelsView: View {
    let bridge: GooseACPEventBridge

    /// Loading lifecycle, kept explicit so the view never shows a stale/empty roster as if it were
    /// real data.
    private enum LoadPhase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    @State private var phase: LoadPhase = .loading
    @State private var providers: [GooseACPProviderTemplateCatalogEntry] = []
    @State private var currentProviderId: String?
    @State private var currentModelId: String?

    @State private var selectedProviderId: String?
    @State private var models: [String] = []
    @State private var modelsLoading = false
    @State private var selectedModelId: String?

    @State private var isSaving = false
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            content
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 360)
        .task { await reload() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Models")
                .font(.title2.weight(.semibold))
            Text(currentDefaultSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading providers from Goose…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case let .failed(message):
            VStack(alignment: .leading, spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Button("Retry") { Task { await reload() } }
            }

        case .loaded:
            if providers.isEmpty {
                Label("No providers available.", systemImage: "tray")
                    .foregroundStyle(.secondary)
            } else {
                picker
            }
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Provider")
                    .font(.headline)
                Picker("Provider", selection: providerSelection) {
                    ForEach(providers, id: \.providerId) { provider in
                        Text(providerLabel(provider)).tag(Optional(provider.providerId))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Model")
                        .font(.headline)
                    if modelsLoading { ProgressView().controlSize(.small) }
                }
                if models.isEmpty && !modelsLoading {
                    Text(selectedProviderId == nil
                         ? "Choose a provider to list its models."
                         : "This provider exposes no enumerable models.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Model", selection: $selectedModelId) {
                        ForEach(models, id: \.self) { model in
                            Text(model).tag(Optional(model))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .disabled(modelsLoading)
                }
            }

            HStack(spacing: 12) {
                Button {
                    Task { await applySelection() }
                } label: {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Set as default")
                    }
                }
                .disabled(!canApply)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Derived

    private var providerSelection: Binding<String?> {
        Binding(
            get: { selectedProviderId },
            set: { newValue in
                selectedProviderId = newValue
                selectedModelId = nil
                models = []
                statusMessage = nil
                Task { await loadModels(for: newValue) }
            }
        )
    }

    private var currentDefaultSummary: String {
        guard let currentProviderId else {
            return "No default provider set yet."
        }
        let providerName = providers.first(where: { $0.providerId == currentProviderId })?.name ?? currentProviderId
        if let currentModelId {
            return "Current default: \(providerName) · \(currentModelId)"
        }
        return "Current default provider: \(providerName)"
    }

    private var canApply: Bool {
        guard !isSaving, let selectedProviderId else { return false }
        // Applying a provider with a chosen model, OR a provider that exposes no models (provider-only
        // default), is valid. Disallow only the no-selection case.
        return !selectedProviderId.isEmpty
    }

    private func providerLabel(_ provider: GooseACPProviderTemplateCatalogEntry) -> String {
        provider.modelCount > 0 ? "\(provider.name) (\(provider.modelCount))" : provider.name
    }

    // MARK: - Live data

    private func reload() async {
        phase = .loading
        statusMessage = nil
        do {
            async let catalog = bridge.liveProviderCatalog()
            async let defaults = bridge.liveDefaults()
            let catalogResult = try await catalog
            let defaultsResult = try await defaults

            providers = catalogResult.providers.sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            currentProviderId = defaultsResult.providerId
            currentModelId = defaultsResult.modelId
            // Seed the editable selection from the live default so the view opens on the real state.
            selectedProviderId = defaultsResult.providerId ?? providers.first?.providerId
            phase = .loaded
            await loadModels(for: selectedProviderId, preselect: defaultsResult.modelId)
        } catch GooseACPBridgeError.notConnected {
            phase = .failed("Goose is not connected. Open the Goose surface and try again.")
        } catch {
            phase = .failed("Could not load providers: \(error.localizedDescription)")
        }
    }

    private func loadModels(for providerId: String?, preselect: String? = nil) async {
        guard let providerId, !providerId.isEmpty else {
            models = []
            return
        }
        modelsLoading = true
        defer { modelsLoading = false }
        do {
            let response = try await bridge.liveProviderSupportedModels(providerId: providerId)
            // Only apply if the user hasn't switched provider since this load started.
            guard selectedProviderId == providerId else { return }
            models = response.models
            if let preselect, response.models.contains(preselect) {
                selectedModelId = preselect
            } else {
                selectedModelId = response.models.first
            }
        } catch GooseACPBridgeError.notConnected {
            guard selectedProviderId == providerId else { return }
            models = []
        } catch {
            guard selectedProviderId == providerId else { return }
            models = []
            statusMessage = "Could not list models: \(error.localizedDescription)"
        }
    }

    private func applySelection() async {
        guard let selectedProviderId else { return }
        isSaving = true
        statusMessage = nil
        defer { isSaving = false }
        do {
            let saved = try await bridge.saveLiveDefaults(
                providerId: selectedProviderId,
                modelId: selectedModelId
            )
            currentProviderId = saved.providerId ?? selectedProviderId
            currentModelId = saved.modelId ?? selectedModelId
            statusMessage = "Saved."
        } catch GooseACPBridgeError.notConnected {
            statusMessage = "Goose is not connected — nothing was saved."
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}
