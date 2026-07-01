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
    @Environment(UIState.self) private var ui

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
    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }
    private var successTint: Color { ui.theme.resolved.accent.color }
    private var infoTint: Color { ui.theme.resolved.headingAccent.color }
    private var warningTint: Color { ui.theme.resolved.headingAccent.color }
    private var mutedTint: Color { ui.theme.resolved.mutedForeground.color }

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
                    ToolbarCapsuleButton(
                        title: nil,
                        systemImage: "arrow.clockwise",
                        role: .toolbarUtility,
                        chromePolicy: .bareUntilPressed,
                        helpText: "Refresh installed URL MCP servers",
                        accessibilityLabel: "Refresh installed URL MCP servers"
                    ) {
                        refreshInstalledServers()
                    }
                }

                if installedServers.isEmpty {
                    Text("No URL MCP servers are configured.")
                        .font(.caption)
                        .foregroundStyle(mutedTint)
                } else {
                    ForEach(installedServers) { server in
                        HStack(alignment: .top, spacing: 12) {
                            IntegrationBrandMarkView(
                                brand: .installedMCPServer(name: server.name, host: server.host),
                                size: 24
                            )
                            .foregroundStyle(mutedTint)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(server.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(server.host)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(mutedTint)
                                    .lineLimit(1)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            ChannelStatusPill(title: "HTTPS", tint: successTint)
                            ChannelStatusPill(
                                title: server.declaresAuth ? "Auth env" : "No auth",
                                tint: server.declaresAuth ? infoTint : mutedTint
                            )
                            ToolbarCapsuleButton(
                                title: nil,
                                systemImage: "trash",
                                role: .secondaryGhost,
                                chromePolicy: .bareUntilPressed,
                                helpText: "Remove \(server.name)",
                                accessibilityLabel: "Remove \(server.name)"
                            ) {
                                uninstall(server)
                            }
                        }
                        if server.id != installedServers.last?.id {
                            extensionSettingsRowGap()
                        }
                    }
                }

                if let statusMessage {
                    Label(
                        statusMessage,
                        systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(statusIsError ? warningTint : successTint)
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
                        .foregroundStyle(mutedTint)
                }

                HStack(spacing: 12) {
                    TextField("Name", text: $newServerName)
                        .settingsFlatInputChrome(theme: theme)
                    TextField("https://example.com/mcp", text: $newServerURL)
                        .settingsFlatInputChrome(theme: theme)
                }

                TextField("TOKEN_ENV_NAME (optional)", text: $newServerAuthEnv)
                    .settingsFlatInputChrome(theme: theme, maxWidth: 360)

                HStack(spacing: 10) {
                    ToolbarCapsuleButton(
                        title: "Install Server",
                        systemImage: "plus.circle",
                        role: .primaryAction,
                        chromePolicy: .alwaysSurface,
                        helpText: "Install URL MCP server",
                        accessibilityLabel: "Install URL MCP server"
                    ) {
                        installManualServer()
                    }
                    .disabled(!canInstallManualServer)

                    ChannelStatusPill(title: "Config write only", tint: infoTint)
                    ChannelStatusPill(title: "HTTPS required", tint: successTint)
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
                            .foregroundStyle(mutedTint)
                    }
                    Spacer()
                    if isSearchingRegistry {
                        ProgressView().controlSize(.small)
                    }
                }

                HStack(spacing: 10) {
                    TextField("Search MCP servers", text: $registryQuery)
                        .settingsFlatInputChrome(theme: theme)
                        .onSubmit {
                            Task { await searchMarketplace() }
                        }
                    ToolbarCapsuleButton(
                        title: "Search",
                        systemImage: "magnifyingglass",
                        role: .toolbarUtility,
                        chromePolicy: .alwaysSurface,
                        helpText: "Search MCP marketplace",
                        accessibilityLabel: "Search MCP marketplace"
                    ) {
                        Task { await searchMarketplace() }
                    }
                    .disabled(registryQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if registryEntries.isEmpty {
                    Text("Search results appear here. Stdio and skill-repo entries are shown honestly but not installed by the App Store-safe URL path.")
                        .font(.caption)
                        .foregroundStyle(mutedTint)
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
                                .foregroundStyle(mutedTint)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.name)
                                        .font(.subheadline.weight(.semibold))
                                    if !entry.description.isEmpty {
                                        Text(entry.description)
                                            .font(.caption)
                                            .foregroundStyle(mutedTint)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer()
                                ChannelStatusPill(title: entry.source.rawValue, tint: infoTint)
                                ChannelStatusPill(title: entry.installKind.displayName, tint: mutedTint)
                            }

                            HStack(spacing: 10) {
                                if entry.installKind == .remoteURL {
                                    ToolbarCapsuleButton(
                                        title: "Install",
                                        systemImage: "plus.circle",
                                        role: .primaryAction,
                                        chromePolicy: .alwaysSurface,
                                        helpText: "Install \(entry.name)",
                                        accessibilityLabel: "Install \(entry.name)"
                                    ) {
                                        installRegistryEntry(entry)
                                    }
                                } else {
                                    ToolbarCapsuleButton(
                                        title: nonURLInstallLabel(for: entry),
                                        systemImage: "lock",
                                        role: .secondaryGhost,
                                        chromePolicy: .bareUntilPressed,
                                        helpText: nonURLInstallLabel(for: entry),
                                        accessibilityLabel: nonURLInstallLabel(for: entry)
                                    ) {}
                                    .disabled(true)
                                }

                                Text(entry.installTarget)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(mutedTint.opacity(0.78))
                                    .lineLimit(1)
                                    .textSelection(.enabled)
                            }
                        }
                        if entry.id != registryEntries.last?.id {
                            extensionSettingsRowGap()
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

    @Environment(UIState.self) private var ui
    @State private var isApplying = false
    @State private var results: [BestOfPresetResult] = []
    @State private var rows: [BestOfPresetItem] = []
    private var successTint: Color { ui.theme.resolved.accent.color }
    private var warningTint: Color { ui.theme.resolved.headingAccent.color }
    private var mutedTint: Color { ui.theme.resolved.mutedForeground.color }

    var body: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Best-Of Preset")
                            .font(.headline)
                        Text("Enable the strongest already-wired tools and install the curated remote MCP entries that are safe for this build profile.")
                            .font(.caption)
                            .foregroundStyle(mutedTint)
                    }
                    Spacer()
                    if isApplying {
                        ProgressView().controlSize(.small)
                    }
                }

                HStack(spacing: 10) {
                    ToolbarCapsuleButton(
                        title: "Apply Preset",
                        systemImage: "checkmark.circle",
                        role: .primaryAction,
                        chromePolicy: .alwaysSurface,
                        helpText: "Apply best-of preset",
                        accessibilityLabel: "Apply best-of preset"
                    ) {
                        Task { await applyPreset() }
                    }
                    .disabled(isApplying)

                    ToolbarCapsuleButton(
                        title: "Revert Remote MCP",
                        systemImage: "arrow.uturn.backward",
                        role: .secondaryGhost,
                        chromePolicy: .bareUntilPressed,
                        helpText: "Revert remote MCP entries installed by the preset",
                        accessibilityLabel: "Revert remote MCP entries installed by the preset"
                    ) {
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
                        .foregroundStyle(mutedTint)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text(item.why)
                                .font(.caption)
                                .foregroundStyle(mutedTint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        ChannelStatusPill(title: item.kind.label, tint: mutedTint)
                        if let result = results.first(where: { $0.item.id == item.id }) {
                            ChannelStatusPill(title: result.status.title, tint: result.status.tint(theme: ui.theme))
                        } else if item.minDistribution == .proResearch {
                            ChannelStatusPill(title: "Pro row", tint: warningTint)
                        } else {
                            ChannelStatusPill(title: "Ready", tint: successTint)
                        }
                    }
                    if item.id != rows.last?.id {
                        extensionSettingsRowGap()
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
    @Environment(UIState.self) private var ui
    @State private var installedServers: [MCPUrlServerDirectory.ServerInfo] = []

    private var successTint: Color { ui.theme.resolved.accent.color }
    private var infoTint: Color { ui.theme.resolved.headingAccent.color }
    private var mutedTint: Color { ui.theme.resolved.mutedForeground.color }

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
                                    .foregroundStyle(mutedTint)
                            }
                            Spacer()
                            ToolbarCapsuleButton(
                                title: nil,
                                systemImage: "arrow.clockwise",
                                role: .toolbarUtility,
                                chromePolicy: .bareUntilPressed,
                                helpText: "Refresh connector status",
                                accessibilityLabel: "Refresh connector status"
                            ) {
                                refresh()
                            }
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
                                .foregroundStyle(status.isConnected ? successTint : mutedTint)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(status.connector.displayName)
                                        .font(.subheadline.weight(.semibold))
                                    Text(status.wiredServerName ?? "No matching URL MCP server configured.")
                                        .font(.caption)
                                        .foregroundStyle(mutedTint)
                                }
                                Spacer()
                                ChannelStatusPill(
                                    title: status.isConnected ? "Connected" : "Not connected",
                                    tint: status.isConnected ? successTint : mutedTint
                                )
                                if status.declaresAuth {
                                    ChannelStatusPill(title: "Auth env", tint: infoTint)
                                }
                            }
                            if status.id != connectorStatuses.last?.id {
                                extensionSettingsRowGap()
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

@ViewBuilder
private func extensionSettingsRowGap() -> some View {
    Color.clear.frame(height: 6)
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
    func tint(theme: EpistemosTheme) -> Color {
        switch self {
        case .alreadyEnabled, .installed, .removed:
            return theme.resolved.accent.color
        case .proLocked, .conflict, .unavailable:
            return theme.resolved.headingAccent.color
        case .failed:
            return theme.resolved.headingAccent.color
        }
    }
}
