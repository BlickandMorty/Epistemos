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
    @State private var loadError: String?

    var body: some View {
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
                            Text(loadError)
                                .font(.caption)
                                .foregroundStyle(.orange)
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
                        Text("No provider targets are configured yet.")
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

                GroupBox("Compiled Files") {
                    VStack(alignment: .leading, spacing: 8) {
                        VaultFileRow(
                            name: "knowledge_profile.md",
                            description: "Domain map, entity graph, and writing style fingerprint",
                            availability: compiledVaultCount == 0 ? "Not generated yet" : "Present in compiled vaults"
                        )
                        Divider()
                        VaultFileRow(
                            name: "concept_index.md",
                            description: "Ranked concepts distilled from your notes",
                            availability: compiledVaultCount == 0 ? "Not generated yet" : "Present in compiled vaults"
                        )
                        Divider()
                        VaultFileRow(
                            name: "active_context.md",
                            description: "Rolling active-context window plus recent chats",
                            availability: compiledVaultCount == 0 ? "Not generated yet" : "Present in compiled vaults"
                        )
                        Divider()
                        VaultFileRow(
                            name: "instructions.md",
                            description: "User-editable preferences and conventions per model",
                            availability: compiledVaultCount == 0 ? "Default instructions will be created on first compile" : "Present in compiled vaults"
                        )
                    }
                    .padding(4)
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
                loadError = nil
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    private func refreshStatus() async {
        let store = KnowledgeProfileStore()
        let targets = configuredTargets()
        var loadedVaults: [String: CompiledModelVault] = [:]

        for target in targets {
            do {
                if let vault = try await store.load(modelID: target.modelID) {
                    loadedVaults[target.modelID] = vault
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
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

        await MainActor.run {
            providerRows = rows
            compiledVaultCount = loadedVaults.count
            totalTargetCount = targets.count
            conceptCount = loadedVaults.values.reduce(0) { $0 + $1.metadata.conceptCount }
            lastRebuildDate = loadedVaults.values.map(\.metadata.compiledAt).max()
            if loadedVaults.isEmpty, loadError == nil {
                loadError = nil
            }
        }
    }

    private func configuredTargets() -> [ModelVaultTarget] {
        let configuredCloudProviders = Set(inference.configuredCloudProviders)
        let installedLocalTextModelIDs = Set(inference.releaseSelectableInstalledLocalTextModelIDs)
        var targets: [ModelVaultTarget] = [
            ModelVaultTarget(
                modelID: "apple-intelligence",
                displayName: "Apple Intelligence",
                conceptLimit: 12,
                activeWindowDays: 7
            )
        ]

        targets.append(
            contentsOf: CloudTextModelID.allCases
                .filter { configuredCloudProviders.contains($0.provider) }
                .map {
                    ModelVaultTarget(
                        modelID: $0.vendorModelID,
                        displayName: $0.displayName,
                        conceptLimit: 60,
                        activeWindowDays: 7
                    )
                }
        )

        targets.append(
            contentsOf: LocalModelCatalog.allDescriptors
                .filter { installedLocalTextModelIDs.contains($0.id) }
                .map {
                    ModelVaultTarget(
                        modelID: $0.id,
                        displayName: $0.displayName,
                        conceptLimit: 24,
                        activeWindowDays: 7
                    )
                }
        )

        var seen = Set<String>()
        return targets.filter { seen.insert($0.modelID).inserted }
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
                        .fill(row.status == .compiled ? .green : row.status == .outdated ? .orange : .red)
                        .frame(width: 8, height: 8)
                    Text(row.statusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let lastCompiledAt = row.lastCompiledAt {
                    Text(lastCompiledAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Vault File Row

private struct VaultFileRow: View {
    let name: String
    let description: String
    let availability: String

    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .frame(width: 20)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.monospaced())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(availability)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
