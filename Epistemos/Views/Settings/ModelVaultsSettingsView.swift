import SwiftUI

// MARK: - Model Vaults Settings
// Exposes the Cloud Knowledge Distillation system to users with live status
// pulled from the persisted model-vault store.

struct ModelVaultsSettingsView: View {
    @Environment(EpistemosConfig.self) private var config
    @Environment(InferenceState.self) private var inference

    @State private var isRebuilding = false
    @State private var lastRebuildDate: Date?
    @State private var conceptCount = 0
    @State private var compiledVaultCount = 0
    @State private var totalTargetCount = 0
    @State private var providerRows: [ProviderRowModel] = []
    @State private var vaultDetails: [ModelVaultDetailModel] = []
    @State private var loadError: String?

    var body: some View {
        let hasConfiguredCloudProviders = !inference.configuredCloudProviders.isEmpty
        let hasInstalledLocalModels = !inference.releaseSelectableInstalledLocalTextModelIDs.isEmpty

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model Vaults")
                        .font(.title2.weight(.semibold))

                    Text(
                        compiledVaultCount == 0
                            ? "Knowledge vaults distill your notes and recent chats into provider-specific context. Rebuild them to generate live vaults for the cloud providers you configured and the local models installed on this Mac."
                            : "Knowledge vaults distill your notes and recent chats into provider-specific context. The status below reflects the configured cloud providers and installed local models that are actually compiled on this Mac."
                    )
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Divider()

                GroupBox("Vault Status") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Last compiled", systemImage: "clock")
                            Spacer()
                            if let date = lastRebuildDate {
                                Text(date, style: .relative)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Never")
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        HStack {
                            Label("Vaults compiled", systemImage: "tray.full")
                            Spacer()
                            Text("\(compiledVaultCount) / \(totalTargetCount)")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Label("Concepts indexed", systemImage: "lightbulb")
                            Spacer()
                            Text("\(conceptCount)")
                                .foregroundStyle(.secondary)
                        }

                        if let loadError {
                            VStack(alignment: .leading, spacing: 6) {
                                Label {
                                    Text("Vault status couldn't load")
                                } icon: {
                                    Image(systemName: "tray.and.arrow.down")
                                }
                                .foregroundStyle(.orange)
                                .font(.caption.weight(.semibold))
                                Text("Try Rebuild All Vaults below. If that keeps failing, open Console.app and filter for “ModelVaults” or “CloudKnowledge” for the underlying reason.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                DisclosureGroup("Raw status") {
                                    Text(loadError)
                                        .font(.caption.monospaced())
                                        .textSelection(.enabled)
                                        .foregroundStyle(.orange)
                                }
                                .font(.caption2)
                            }
                        }

                        Divider()

                        Button {
                            rebuildVaults()
                        } label: {
                            HStack {
                                if isRebuilding {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Rebuilding...")
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Rebuild All Vaults")
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRebuilding)
                    }
                    .padding(4)
                }

                GroupBox("Provider Vaults") {
                    if providerRows.isEmpty {
                        Text(
                            hasConfiguredCloudProviders || hasInstalledLocalModels
                                ? "Configured providers and installed local models are ready, but no vault rows have been compiled yet."
                                : "No provider targets are configured yet."
                        )
                            .foregroundStyle(.secondary)
                            .padding(4)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(providerRows.enumerated()), id: \.element.id) { index, row in
                                ProviderRow(row: row)
                                if index < providerRows.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding(4)
                    }
                }

                GroupBox("Per-Model Vault Files") {
                    if vaultDetails.isEmpty {
                        Text("No model targets yet — configure a cloud provider or install a local model, then Rebuild All Vaults.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(4)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(vaultDetails) { detail in
                                ModelVaultDetailRow(detail: detail)
                            }
                        }
                        .padding(4)
                    }
                }

                GroupBox("Background Compilation") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(
                            "Enable Night Brain background compilation",
                            isOn: Binding(
                                get: { config.nightBrainEnabled },
                                set: { config.nightBrainEnabled = $0 }
                            )
                        )

                        Text(
                            config.nightBrainEnabled
                                ? "Night Brain can rebuild model vaults during idle maintenance windows. It is not a per-keystroke live compiler."
                                : "Background recompilation is off. Use Rebuild All Vaults when you want the distilled vaults refreshed."
                        )
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(4)
                }

                // DATA+FINETUNE part (5): the data + fine-tune PACK MARKETPLACE
                // browse surface (registry seeded from FineTunePackCatalog; honest
                // gating + empty state). Import/apply is the follow-on slice.
                FineTuneMarketplaceView()
            }
            .padding(24)
        }
        .task {
            await refreshStatus()
        }
    }

    private func rebuildVaults() {
        isRebuilding = true
        Task {
            defer { isRebuilding = false }
            guard let service = AppBootstrap.shared?.cloudKnowledgeDistillationService else {
                loadError = "Cloud knowledge distillation is not available in this app session."
                return
            }

            do {
                _ = try await service.rebuildModelVaults(for: configuredTargets())
                await refreshStatus()
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    private func refreshStatus() async {
        let store = KnowledgeProfileStore()
        let targets = configuredTargets()
        var loadedVaults: [String: CompiledModelVault] = [:]
        var firstErrorDescription: String?

        for target in targets {
            do {
                if let vault = try await store.load(modelID: target.modelID) {
                    loadedVaults[target.modelID] = vault
                }
            } catch {
                if firstErrorDescription == nil {
                    firstErrorDescription = error.localizedDescription
                }
            }
        }

        let rows = ProviderBucket.ordered.compactMap { bucket -> ProviderRowModel? in
            let bucketTargets = targets.filter { ProviderBucket.bucket(for: $0) == bucket }
            guard !bucketTargets.isEmpty else { return nil }
            let bucketVaults = bucketTargets.compactMap { loadedVaults[$0.modelID] }
            return ProviderRowModel(
                bucket: bucket,
                compiledCount: bucketVaults.count,
                totalCount: bucketTargets.count,
                lastCompiledAt: bucketVaults.map(\.metadata.compiledAt).max()
            )
        }

        // Owner 2026-06-18: real per-model file status, read from disk — not a
        // generic "Present in compiled vaults" claim. Probe each target's vault
        // directory for the canonical files (size + last-modified, honest
        // missing). Compiled models sort first so the eye lands on real data.
        let details: [ModelVaultDetailModel] = targets
            .map { target in
                let directory = store.modelVaultDirectoryURL(for: target.modelID)
                let files = ModelVaultFileInspector.probe(directory: directory)
                let preview = ModelVaultFileInspector.preview(
                    of: directory.appendingPathComponent("instructions.md")
                )
                return ModelVaultDetailModel(
                    modelID: target.modelID,
                    displayName: target.displayName,
                    iconName: ProviderBucket.bucket(for: target)?.icon ?? "doc.text",
                    files: files,
                    instructionsPreview: preview
                )
            }
            .sorted { lhs, rhs in
                if lhs.isCompiled != rhs.isCompiled { return lhs.isCompiled && !rhs.isCompiled }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

        await MainActor.run {
            providerRows = rows
            vaultDetails = details
            compiledVaultCount = loadedVaults.count
            totalTargetCount = targets.count
            conceptCount = loadedVaults.values.reduce(0) { $0 + $1.metadata.conceptCount }
            lastRebuildDate = loadedVaults.values.map(\.metadata.compiledAt).max()
            loadError = firstErrorDescription
        }
    }

    private func configuredTargets() -> [ModelVaultTarget] {
        inference.modelVaultTargets()
    }
}

// MARK: - Staleness

/// SS-MV (1, owner 2026-06-20): pure, testable age-staleness check for a compiled model
/// vault. The model-vault rows showed green ("Compiled") regardless of AGE — only
/// completeness was reflected — so a vault that froze days ago read fresh. This flags a
/// vault as stale once it's older than the advisory max-age, surfaced honestly in the row
/// so the user knows to Rebuild. (The on-note-change debounced auto-recompile is the
/// follow-on; this is the visible "it's stale" half.)
enum ModelVaultStaleness {
    static let staleAfter: TimeInterval = 24 * 60 * 60
    static func isStale(lastCompiledAt: Date?, now: Date = Date()) -> Bool {
        guard let lastCompiledAt else { return false }
        return now.timeIntervalSince(lastCompiledAt) > staleAfter
    }
}

// MARK: - Provider Rows

private struct ProviderRowModel: Identifiable {
    let bucket: ProviderBucket
    let compiledCount: Int
    let totalCount: Int
    let lastCompiledAt: Date?

    enum VaultStatus {
        case compiled, outdated, missing
    }

    var id: String { bucket.rawValue }

    var status: VaultStatus {
        if compiledCount == 0 {
            return .missing
        }
        return compiledCount == totalCount ? .compiled : .outdated
    }

    /// SS-MV (1, owner 2026-06-20): a compiled vault is STALE when it was compiled a while
    /// ago — `status` only reflects COMPLETENESS (compiledCount == totalCount), so a fully
    /// compiled but old vault read green even though the profile freezes while the notes
    /// change ("outdated even with one model"). This surfaces age-staleness HONESTLY so the
    /// user knows to Rebuild; the debounced on-note-change auto-recompile is the follow-on.
    /// Advisory 24-hour max-age (the pure check lives in ModelVaultStaleness, testable).
    var isStale: Bool {
        guard status != .missing else { return false }
        return ModelVaultStaleness.isStale(lastCompiledAt: lastCompiledAt)
    }

    var statusLabel: String {
        switch status {
        case .compiled:
            return "Compiled"
        case .outdated:
            return "Partial"
        case .missing:
            return "Missing"
        }
    }
}

private enum ProviderBucket: String, CaseIterable {
    case appleIntelligence
    case openAI
    case anthropic
    case google
    case deepseek
    case zai
    case kimi
    case minimax
    case local

    static let ordered: [ProviderBucket] = [
        .appleIntelligence,
        .openAI,
        .anthropic,
        .google,
        .deepseek,
        .zai,
        .kimi,
        .minimax,
        .local,
    ]

    var title: String {
        switch self {
        case .appleIntelligence:
            "Apple Intelligence"
        case .openAI:
            "OpenAI"
        case .anthropic:
            "Anthropic"
        case .google:
            "Google"
        case .deepseek:
            "DeepSeek"
        case .zai:
            "Z.AI / GLM"
        case .kimi:
            "Kimi / Moonshot"
        case .minimax:
            "MiniMax"
        case .local:
            "Local Models"
        }
    }

    var icon: String {
        switch self {
        case .appleIntelligence:
            "apple.intelligence"
        case .openAI:
            "sparkles.rectangle.stack"
        case .anthropic:
            "brain.head.profile"
        case .google:
            "diamond"
        case .deepseek:
            "water.waves"
        case .zai:
            "bolt.horizontal.circle"
        case .kimi:
            "moon.stars.fill"
        case .minimax:
            "paperplane.circle.fill"
        case .local:
            "memorychip"
        }
    }

    static func bucket(for target: ModelVaultTarget) -> ProviderBucket? {
        if target.modelID == "apple-intelligence" {
            return .appleIntelligence
        }
        if LocalTextModelID(rawValue: target.modelID) != nil {
            return .local
        }
        // Foundation GGUF chat models (Gemma / VibeThinker / coder) are local
        // too — they're descriptor IDs, not LocalTextModelID enum cases — so
        // bucket them with Local Models for an honest summary count.
        if EpistemosFoundationLineup.tier(forModelID: target.modelID) != nil {
            return .local
        }

        guard let model = CloudTextModelID.allCases.first(where: { $0.vendorModelID == target.modelID }) else {
            return nil
        }

        switch model.provider {
        case .openAI:
            return .openAI
        case .anthropic:
            return .anthropic
        case .google:
            return .google
        case .deepseek:
            return .deepseek
        case .zai:
            return .zai
        case .kimi:
            return .kimi
        case .minimax:
            return .minimax
        }
    }
}

private struct ProviderRow: View {
    let row: ProviderRowModel

    var body: some View {
        HStack {
            Image(systemName: row.bucket.icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.bucket.title)
                    .font(.body)
                Text("\(row.compiledCount) of \(row.totalCount) vaults compiled")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        // SS-MV (1): a compiled-but-STALE vault reads amber (not green), so
                        // age-staleness is visible instead of hidden behind a green dot.
                        .fill(row.status == .compiled ? (row.isStale ? .orange : .green) : row.status == .outdated ? .orange : .red)
                        .frame(width: 8, height: 8)
                    Text(row.isStale && row.status == .compiled ? "Compiled · stale" : row.statusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let lastCompiledAt = row.lastCompiledAt {
                    HStack(spacing: 3) {
                        if row.isStale {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.caption2)
                        }
                        Text(lastCompiledAt, style: .relative)
                            .font(.caption2)
                    }
                    .foregroundStyle(row.isStale ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                }
            }
        }
    }
}

// MARK: - Per-Model Vault Detail

/// One model's real compiled-vault status (owner 2026-06-18). Wraps the on-disk
/// file probe so the row renders honest size + timestamp data per file.
private struct ModelVaultDetailModel: Identifiable {
    let modelID: String
    let displayName: String
    let iconName: String
    let files: [ModelVaultFileStatus]
    let instructionsPreview: String?

    var id: String { modelID }
    var isCompiled: Bool { ModelVaultFileInspector.anyCompiled(files) }
    var totalBytes: Int { ModelVaultFileInspector.totalBytes(files) }
}

/// A collapsible per-model row: name + ID + compiled dot + total size in the
/// header; the canonical files with real size + last-modified (honest "Not
/// compiled" per file) when expanded.
private struct ModelVaultDetailRow: View {
    let detail: ModelVaultDetailModel
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(detail.files) { file in
                    HStack(spacing: 8) {
                        Image(systemName: file.exists ? "doc.text.fill" : "doc.text")
                            .font(.caption)
                            .foregroundStyle(file.exists ? .secondary : .tertiary)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(file.name)
                                .font(.caption.monospaced())
                                .foregroundStyle(file.exists ? .primary : .secondary)
                            Text(file.description)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if file.exists {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(ModelVaultFileInspector.formatBytes(file.sizeBytes))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if let modified = file.modifiedAt {
                                    Text(modified, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        } else {
                            Text("Not compiled")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Owner 2026-06-18: a real content preview of this model's
                // instructions.md (the user-editable steering file), so the row
                // shows what's actually in the vault — not a generic claim.
                if let preview = detail.instructionsPreview {
                    Divider()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("instructions.md preview")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                        Text(preview)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: detail.iconName)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(detail.displayName)
                        .font(.body)
                    Text(detail.modelID)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(detail.isCompiled ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    Text(detail.isCompiled ? ModelVaultFileInspector.formatBytes(detail.totalBytes) : "Not compiled")
                        .font(.caption2)
                        .foregroundStyle(detail.isCompiled ? .secondary : .tertiary)
                }
            }
        }
    }
}
