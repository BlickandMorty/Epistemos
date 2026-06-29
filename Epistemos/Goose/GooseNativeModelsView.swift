import SwiftUI

/// Native Epistemos "Models" surface — the SAFE FIRST native route of the per-route migration.
///
/// Parity contract with the WebView oracle (`/settings?section=models`): every provider and model
/// shown here is LIVE-ENUMERATED from the same ACP connection the WebView uses. The picker source is
/// `providers/list` (`liveProviderInventory`) — the available providers (built-in + configured) each
/// carrying their models INLINE, so selecting a provider never triggers a per-provider live
/// enumeration that could hang. The current selection is read from (`liveDefaults`) and written to
/// (`saveLiveDefaults`) the same `_goose/unstable/defaults` methods. Nothing is Swift-hardcoded
/// (GOLDEN RULE). When the bridge is not connected the view shows an honest blocked state.
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
    @State private var providers: [GooseACPProviderInventoryEntry] = []
    @State private var currentProviderId: String?
    @State private var currentModelId: String?

    @State private var selectedProviderId: String?
    @State private var selectedModelId: String?

    @State private var isSaving = false
    @State private var statusMessage: String?
    /// Monotonic load token. A `reload()` only writes state if it is still the latest load — so an
    /// abandoned (timed-out) load completing late, or overlapping Retry taps, can never overwrite a
    /// newer load's result.
    @State private var loadGeneration = 0

    /// How long a single load may sit on `.loading` before surfacing a Retry. The ACP client has no
    /// per-request timeout (a server that accepts a request but never replies would otherwise hang
    /// the view forever); this gives the user an escape.
    private let loadTimeout: Duration = .seconds(20)

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
                    ForEach(providers) { provider in
                        Text(providerLabel(provider)).tag(Optional(provider.providerId))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(isSaving)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Model")
                    .font(.headline)
                if currentModels.isEmpty {
                    Text(selectedProviderId == nil
                         ? "Choose a provider to list its models."
                         : "This provider exposes no enumerable models. Configure it to refresh, "
                           + "or it can still be set as the default provider.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Model", selection: $selectedModelId) {
                        ForEach(currentModels, id: \.self) { model in
                            Text(model).tag(Optional(model))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .disabled(isSaving)
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

    private func provider(withId providerId: String?) -> GooseACPProviderInventoryEntry? {
        guard let providerId else { return nil }
        return providers.first { $0.providerId == providerId }
    }

    /// Inline model ids for a provider (from its `providers/list` entry — no extra call, no hang).
    private func modelIDs(forProviderId providerId: String?) -> [String] {
        guard let entry = provider(withId: providerId) else { return [] }
        return entry.models.map(\.id)
    }

    /// Models for the currently-selected provider.
    private var currentModels: [String] {
        modelIDs(forProviderId: selectedProviderId)
    }

    private var providerSelection: Binding<String?> {
        Binding(
            get: { selectedProviderId },
            set: { newValue in
                selectedProviderId = newValue
                statusMessage = nil
                // Models come inline with the entry; preselect this provider's default (or first).
                let entry = provider(withId: newValue)
                let entryModels = modelIDs(forProviderId: newValue)
                if let preferred = entry?.defaultModel, entryModels.contains(preferred) {
                    selectedModelId = preferred
                } else {
                    selectedModelId = entryModels.first
                }
            }
        )
    }

    private var currentDefaultSummary: String {
        guard let currentProviderId else {
            return "No default provider set yet."
        }
        let providerName = providers.first(where: { $0.providerId == currentProviderId })?.providerName ?? currentProviderId
        if let currentModelId {
            return "Current default: \(providerName) · \(currentModelId)"
        }
        return "Current default provider: \(providerName)"
    }

    private var canApply: Bool {
        guard !isSaving, let selectedProviderId else { return false }
        return !selectedProviderId.isEmpty
    }

    private func providerLabel(_ provider: GooseACPProviderInventoryEntry) -> String {
        var label = provider.providerName
        if provider.models.count > 0 {
            label += " (\(provider.models.count))"
        }
        if !provider.configured {
            label += " — not configured"
        }
        return label
    }

    // MARK: - Live data

    private func reload() async {
        loadGeneration += 1
        let generation = loadGeneration
        phase = .loading
        statusMessage = nil

        // Bound the load: the ACP client has no per-request timeout, so a server that accepts a
        // request but never replies would park the await forever. This sibling task flips the view
        // to an honest Retry state after `loadTimeout` if this load is still the latest and still
        // loading. The hung load (if any) is abandoned; its late completion is ignored by the
        // generation guard below.
        let timeout = Task { @MainActor in
            try? await Task.sleep(for: loadTimeout)
            guard generation == loadGeneration else { return }
            if case .loading = phase {
                phase = .failed("Timed out loading providers from Goose. Retry?")
            }
        }
        defer { timeout.cancel() }

        do {
            async let inventory = bridge.liveProviderInventory()
            async let defaults = bridge.liveDefaults()
            let inventoryResult = try await inventory
            let defaultsResult = try await defaults

            // A newer reload (Retry / re-appear) superseded this one — drop our writes.
            guard generation == loadGeneration else { return }

            providers = inventoryResult.sorted { lhs, rhs in
                lhs.providerName.localizedCaseInsensitiveCompare(rhs.providerName) == .orderedAscending
            }
            currentProviderId = defaultsResult.providerId
            currentModelId = defaultsResult.modelId

            // Seed the editable selection from the live default — but ONLY if that provider actually
            // exists in the inventory (else the Picker would have an invalid/blank selection). Fall
            // back to the first available provider otherwise.
            let defaultIsListed = providers.contains { $0.providerId == defaultsResult.providerId }
            let seedProviderId = (defaultIsListed ? defaultsResult.providerId : nil) ?? providers.first?.providerId
            selectedProviderId = seedProviderId
            let seedModels = modelIDs(forProviderId: seedProviderId)
            if let defaultModel = defaultsResult.modelId, seedModels.contains(defaultModel) {
                selectedModelId = defaultModel
            } else {
                selectedModelId = seedModels.first
            }
            phase = .loaded
        } catch GooseACPBridgeError.notConnected {
            guard generation == loadGeneration else { return }
            phase = .failed("Goose is not connected. Open the Goose surface and try again.")
        } catch {
            guard generation == loadGeneration else { return }
            phase = .failed("Could not load providers: \(error.localizedDescription)")
        }
    }

    private func applySelection() async {
        // Capture the selection ATOMICALLY before the await so a provider switch during the save
        // can never persist (or display) a provider/model mismatch: the post-await fallbacks below
        // use exactly what was sent, not whatever @State holds after suspension.
        guard let providerId = selectedProviderId else { return }
        let modelId = selectedModelId
        isSaving = true
        statusMessage = nil
        defer { isSaving = false }
        do {
            let saved = try await bridge.saveLiveDefaults(providerId: providerId, modelId: modelId)
            currentProviderId = saved.providerId ?? providerId
            currentModelId = saved.modelId ?? modelId
            statusMessage = "Saved."
        } catch GooseACPBridgeError.notConnected {
            statusMessage = "Goose is not connected — nothing was saved."
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}
