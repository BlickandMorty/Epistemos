import SwiftUI

struct ExtensionsDetailView: View {
    @State private var selectedTab: ExtensionsSettingsTab = .skills

    var body: some View {
        VStack(spacing: 0) {
            Picker("Extensions", selection: $selectedTab) {
                ForEach(ExtensionsSettingsTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .frame(maxWidth: 520)

            Group {
                switch selectedTab {
                case .skills:
                    SkillsDetailView()
                case .mcpServers:
                    MCPServersDetailView()
                case .connectors:
                    ConnectorsDetailView()
                case .browserUse:
                    BrowserUseSettingsView()
                }
            }
        }
    }
}

private enum ExtensionsSettingsTab: String, CaseIterable, Identifiable {
    case skills
    case mcpServers
    case connectors
    case browserUse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .skills: "Skills"
        case .mcpServers: "MCP Servers"
        case .connectors: "Connectors"
        case .browserUse: "browser-use"
        }
    }
}

private struct MCPServersDetailView: View {
    @Environment(VaultSyncService.self) private var vaultSync

    @State private var installedServers: [MCPUrlServerDirectory.ServerInfo] = []
    @State private var registryQuery = ""
    @State private var registryEntries: [MCPRegistryEntry] = []
    @State private var isSearchingRegistry = false
    @State private var newServerName = ""
    @State private var newServerURL = ""
    @State private var newServerAuthEnv = ""
    @State private var statusMessage: String?
    @State private var statusIsError = false

    private let registryClient = MCPRegistryClient()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BestOfPresetCard(vaultPath: vaultSync.vaultURL?.path) {
                    refreshInstalledServers()
                }

                installedServersCard
                addServerCard
                marketplaceCard
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .topLeading)
        }
        .task {
            refreshInstalledServers()
        }
    }

    private var installedServersCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Installed URL MCP Servers")
                        .font(.headline)
                    Spacer()
                    Button {
                        refreshInstalledServers()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Refresh installed URL MCP servers")
                }

                if installedServers.isEmpty {
                    Text("No URL MCP servers are configured.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(installedServers) { server in
                        HStack(alignment: .top, spacing: 12) {
                            IntegrationBrandMarkView(
                                brand: .installedMCPServer(name: server.name, host: server.host),
                                size: 24
                            )
                            .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(server.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(server.host)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            ChannelStatusPill(title: "HTTPS", tint: .green)
                            ChannelStatusPill(
                                title: server.declaresAuth ? "Auth env" : "No auth",
                                tint: server.declaresAuth ? .blue : .secondary
                            )
                            Button(role: .destructive) {
                                uninstall(server)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .help("Remove \(server.name)")
                        }
                        if server.id != installedServers.last?.id {
                            Divider()
                        }
                    }
                }

                if let statusMessage {
                    Label(
                        statusMessage,
                        systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(statusIsError ? .orange : .green)
                }
            }
        }
    }

    private var addServerCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add HTTPS Server")
                        .font(.headline)
                    Text("Remote MCP servers are written to the same JSON file the Rust bridge forwards to the provider. Token values are not stored here; use an environment-variable name when auth is needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    TextField("Name", text: $newServerName)
                        .textFieldStyle(.roundedBorder)
                    TextField("https://example.com/mcp", text: $newServerURL)
                        .textFieldStyle(.roundedBorder)
                }

                TextField("TOKEN_ENV_NAME (optional)", text: $newServerAuthEnv)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 360)

                HStack(spacing: 10) {
                    Button("Install Server") {
                        installManualServer()
                    }
                    .disabled(!canInstallManualServer)

                    ChannelStatusPill(title: "Config write only", tint: .blue)
                    ChannelStatusPill(title: "HTTPS required", tint: .green)
                }
            }
        }
    }

    private var marketplaceCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Marketplace Browse")
                            .font(.headline)
                        Text("Search public MCP registries, then install remote HTTPS servers into the live URL-server config.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isSearchingRegistry {
                        ProgressView().controlSize(.small)
                    }
                }

                HStack(spacing: 10) {
                    TextField("Search MCP servers", text: $registryQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            Task { await searchMarketplace() }
                        }
                    Button("Search") {
                        Task { await searchMarketplace() }
                    }
                    .disabled(registryQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if registryEntries.isEmpty {
                    Text("Search results appear here. Stdio and skill-repo entries are shown honestly but not installed by the App Store-safe URL path.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(registryEntries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 12) {
                                IntegrationBrandMarkView(
                                    brand: .mcpRegistry(
                                        source: entry.source.rawValue,
                                        installKind: entry.installKind.rawValue,
                                        name: entry.name
                                    ),
                                    size: 24
                                )
                                .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.name)
                                        .font(.subheadline.weight(.semibold))
                                    if !entry.description.isEmpty {
                                        Text(entry.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer()
                                ChannelStatusPill(title: entry.source.rawValue, tint: .blue)
                                ChannelStatusPill(title: entry.installKind.displayName, tint: .secondary)
                            }

                            HStack(spacing: 10) {
                                if entry.installKind == .remoteURL {
                                    Button("Install") {
                                        installRegistryEntry(entry)
                                    }
                                } else {
                                    Button(nonURLInstallLabel(for: entry)) {}
                                        .disabled(true)
                                }

                                Text(entry.installTarget)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .textSelection(.enabled)
                            }
                        }
                        if entry.id != registryEntries.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var canInstallManualServer: Bool {
        !newServerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && newServerURL.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("https://")
    }

    private func refreshInstalledServers() {
        Task { @MainActor in
            let servers = await Task.detached(priority: .utility) {
                MCPUrlServerDirectory.discover()
            }.value
            guard !Task.isCancelled else { return }
            installedServers = servers
        }
    }

    private func installManualServer() {
        let entry = MCPUrlServerDirectory.WritableEntry(
            name: newServerName,
            url: newServerURL,
            authorizationTokenEnv: newServerAuthEnv
        )
        let displayName = newServerName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { @MainActor in
            let outcome = await Task.detached(priority: .utility) {
                mcpServerOperationOutcome {
                    try MCPUrlServerDirectory.install(entry)
                } successMessage: {
                    "Installed \(displayName)."
                }
            }.value
            applyMCPServerOperationOutcome(outcome, clearsManualForm: true)
        }
    }

    private func uninstall(_ server: MCPUrlServerDirectory.ServerInfo) {
        let name = server.name
        Task { @MainActor in
            let outcome = await Task.detached(priority: .utility) {
                mcpServerOperationOutcome {
                    try MCPUrlServerDirectory.uninstall(name: name)
                } successMessage: {
                    "Removed \(name)."
                }
            }.value
            applyMCPServerOperationOutcome(outcome, clearsManualForm: false)
        }
    }

    private func applyMCPServerOperationOutcome(
        _ outcome: MCPServerSettingsOperationOutcome,
        clearsManualForm: Bool
    ) {
        switch outcome {
        case .success(let message, let servers):
            statusMessage = message
            statusIsError = false
            if clearsManualForm {
                newServerName = ""
                newServerURL = ""
                newServerAuthEnv = ""
            }
            installedServers = servers
        case .failure(let message):
            statusMessage = message
            statusIsError = true
        }
    }

    private func searchMarketplace() async {
        let query = registryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearchingRegistry = true
        defer { isSearchingRegistry = false }
        registryEntries = await registryClient.searchAll(query: query)
    }

    private func installRegistryEntry(_ entry: MCPRegistryEntry) {
        let writableEntry = MCPUrlServerDirectory.WritableEntry(
            name: serverName(for: entry),
            url: entry.installTarget
        )
        let displayName = entry.name
        Task { @MainActor in
            let outcome = await Task.detached(priority: .utility) {
                mcpServerOperationOutcome {
                    try MCPUrlServerDirectory.install(writableEntry)
                } successMessage: {
                    "Installed \(displayName)."
                }
            }.value
            applyMCPServerOperationOutcome(outcome, clearsManualForm: false)
        }
    }

    private func serverName(for entry: MCPRegistryEntry) -> String {
        let allowed = entry.name.lowercased().map { character in
            character.isLetter || character.isNumber ? character : "-"
        }
        let normalized = String(allowed)
            .split(separator: "-")
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return normalized.isEmpty ? entry.id : normalized
    }

    private func nonURLInstallLabel(for entry: MCPRegistryEntry) -> String {
        switch entry.installKind {
        case .remoteURL:
            return "Install"
        case .stdioCommand:
            return "Pro only"
        case .skillRepo:
            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            return "Pro only"
            #else
            return "Install from Skills"
            #endif
        }
    }
}

nonisolated private func mcpServerOperationOutcome(
    operation: () throws -> [MCPUrlServerDirectory.ServerInfo],
    successMessage: () -> String
) -> MCPServerSettingsOperationOutcome {
    do {
        return .success(
            message: MCPServerSettingsStatus.message(successMessage(), fallback: "MCP server updated."),
            servers: try operation()
        )
    } catch {
        return .failure(MCPServerSettingsStatus.message(for: error, fallback: "MCP server operation failed."))
    }
}

nonisolated enum MCPServerSettingsStatus {
    static let maxStatusMessageCharacters = MCPUrlServerDirectory.Diagnostics.maxFailureReasonCharacters

    static func message(_ value: String, fallback: String) -> String {
        MCPUrlServerDirectory.Diagnostics.failureReason(value, fallback: fallback)
    }

    static func message(for error: Error, fallback: String) -> String {
        if let error = error as? MCPUrlServerDirectory.WriteError {
            return message(error.errorDescription ?? fallback, fallback: fallback)
        }
        return MCPUrlServerDirectory.Diagnostics.externalErrorDescription(error, fallback: fallback)
    }
}

private enum MCPServerSettingsOperationOutcome: Sendable {
    case success(message: String, servers: [MCPUrlServerDirectory.ServerInfo])
    case failure(String)
}

private struct BestOfPresetCard: View {
    let vaultPath: String?
    let onChange: () -> Void

    @State private var isApplying = false
    @State private var results: [BestOfPresetResult] = []
    @State private var rows: [BestOfPresetItem] = []

    var body: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Best-Of Preset")
                            .font(.headline)
                        Text("Enable the strongest already-wired tools and install the curated remote MCP entries that are safe for this build profile.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isApplying {
                        ProgressView().controlSize(.small)
                    }
                }

                HStack(spacing: 10) {
                    Button("Apply Preset") {
                        Task { await applyPreset() }
                    }
                    .disabled(isApplying)

                    Button("Revert Remote MCP") {
                        revertRemoteMCP()
                    }
                    .disabled(isApplying)
                }

                ForEach(rows) { item in
                    HStack(alignment: .top, spacing: 12) {
                        IntegrationBrandMarkView(
                            brand: .bestOfPreset(
                                kind: item.kind.rawValue,
                                id: item.id,
                                displayName: item.displayName
                            ),
                            size: 24
                        )
                        .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text(item.why)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        ChannelStatusPill(title: item.kind.label, tint: .secondary)
                        if let result = results.first(where: { $0.item.id == item.id }) {
                            ChannelStatusPill(title: result.status.title, tint: result.status.tint)
                        } else if item.minDistribution == .proResearch {
                            ChannelStatusPill(title: "Pro row", tint: .orange)
                        } else {
                            ChannelStatusPill(title: "Ready", tint: .blue)
                        }
                    }
                    if item.id != rows.last?.id {
                        Divider()
                    }
                }
            }
        }
        .task {
            loadRows()
        }
    }

    private func loadRows() {
        Task { @MainActor in
            let loadedRows = await Task.detached(priority: .utility) {
                BestOfPreset.manifest().items
            }.value
            guard !Task.isCancelled else { return }
            rows = loadedRows
        }
    }

    private func applyPreset() async {
        guard !isApplying else { return }
        isApplying = true
        let selectedVaultPath = vaultPath
        let presetResults = await Task.detached(priority: .utility) {
            await BestOfPreset.apply(vaultPath: selectedVaultPath)
        }.value
        guard !Task.isCancelled else {
            isApplying = false
            return
        }
        results = presetResults
        isApplying = false
        onChange()
    }

    private func revertRemoteMCP() {
        guard !isApplying else { return }
        isApplying = true
        Task { @MainActor in
            let presetResults = await Task.detached(priority: .utility) {
                BestOfPreset.revertRemoteMCP()
            }.value
            guard !Task.isCancelled else {
                isApplying = false
                return
            }
            results = presetResults
            isApplying = false
            onChange()
        }
    }
}

private struct ConnectorsDetailView: View {
    @State private var installedServers: [MCPUrlServerDirectory.ServerInfo] = []

    private var connectorStatuses: [CoworkConnectorDirectory.ConnectorStatus] {
        CoworkConnectorDirectory.statuses(servers: installedServers)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsSurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Connectors")
                                    .font(.headline)
                                Text("Connector status is derived only from URL MCP servers that are actually configured.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                refresh()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                            .help("Refresh connector status")
                        }

                        ForEach(connectorStatuses) { status in
                            HStack(spacing: 12) {
                                IntegrationBrandMarkView(
                                    brand: .connector(
                                        id: status.connector.id,
                                        displayName: status.connector.displayName
                                    ),
                                    size: 24
                                )
                                .foregroundStyle(status.isConnected ? .green : .secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(status.connector.displayName)
                                        .font(.subheadline.weight(.semibold))
                                    Text(status.wiredServerName ?? "No matching URL MCP server configured.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                ChannelStatusPill(
                                    title: status.isConnected ? "Connected" : "Not connected",
                                    tint: status.isConnected ? .green : .secondary
                                )
                                if status.declaresAuth {
                                    ChannelStatusPill(title: "Auth env", tint: .blue)
                                }
                            }
                            if status.id != connectorStatuses.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .topLeading)
        }
        .task {
            refresh()
        }
    }

    private func refresh() {
        Task { @MainActor in
            let servers = await Task.detached(priority: .utility) {
                MCPUrlServerDirectory.discover()
            }.value
            guard !Task.isCancelled else { return }
            installedServers = servers
        }
    }
}

private extension BestOfPresetItemKind {
    var label: String {
        switch self {
        case .builtinTool: "Built-in"
        case .skillRepo: "Skill"
        case .remoteMCP: "Remote MCP"
        }
    }
}

private extension BestOfPresetStatus {
    var tint: Color {
        switch self {
        case .alreadyEnabled, .installed, .removed:
            return .green
        case .proLocked, .conflict, .unavailable:
            return .orange
        case .failed:
            return .red
        }
    }
}
