import SwiftUI

/// P2.1 (UI) — shared agent capability control. A compact panel, opened from
/// Landing or future AgentClone/fusion controls, that lists the agent tools the
/// registry surfaces and lets the user turn each on/off. This is REAL config,
/// not decoration: the toggles flow into `AgentCommandCenterState.toolToggles`
/// → `disabledToolNames`, which execution-plan gating applies to the main agent
/// plan (commit a731469a6) — a tool turned off here is removed from the plan's
/// `tool_permissions` for agent turns.
///
/// Honest gating: destructive tools and tools that ask before acting are
/// badged, and a footer states the capability truth (local models chat + reason;
/// multi-step tool runs use a cloud model or the Pro harness). It only shows
/// tools the current build actually surfaces, so nothing here is a fake control.
@MainActor
struct AgentToolTogglePanel: View {
    let agentCommandCenter: AgentCommandCenterState
    let theme: EpistemosTheme
    /// P2.4 — run a discovered skill from a launcher: primes the composer with the
    /// skill's `/identifier` slash invocation. nil → the Skills browser is
    /// read-only (still shows what's available + the honest create path).
    var onRunSkill: ((SkillDiscoveryEntry) -> Void)? = nil

    /// Tools grouped by their owning agent, agents in a stable display order.
    private var groupedTools: [(agent: String, tools: [OmegaToolDefinition])] {
        let groups = Dictionary(grouping: agentCommandCenter.availableTools, by: \.agent)
        return groups
            .map { (agent: $0.key, tools: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.agent < $1.agent }
    }

    private var enabledCount: Int { agentCommandCenter.enabledToolNames.count }
    private var totalCount: Int { agentCommandCenter.availableTools.count }

    /// True on the App Store (MAS) build, where git/shell/CLI-agent tools are
    /// forbidden — so the panel honestly states they're a Pro-build capability.
    private var showsProDeveloperNote: Bool {
        ToolSurfacePolicy.resolvedDistribution(.currentBuild) == .coreAppStore
    }

    /// P2.3 — the external (URL) MCP servers actually wired for the agent, read
    /// from the same config the Rust bridge forwards. Loaded once on appear.
    @State private var mcpServers: [MCPUrlServerDirectory.ServerInfo] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(groupedTools, id: \.agent) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(agentDisplayName(group.agent))
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(theme.textTertiary)
                                .textCase(.uppercase)
                            ForEach(group.tools, id: \.name) { tool in
                                toolRow(tool)
                            }
                        }
                    }

                    mcpServersSection

                    connectorsSection

                    skillsSection
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 320)

            Divider()

            Text("Local models can answer and reason; multi-step tool runs use a cloud model or the Pro harness. Turning a tool off removes it from agent turns.")
                .font(.system(size: 10))
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            // P2.5 — honest Pro-capability disclosure. Git, diff, shell, and
            // CLI-agent tools are Pro-only (cfg(feature = "pro-build") in the
            // Rust registry; the MAS build forbids them, locked by
            // `mas_sandbox_registry_excludes_unbounded_tools`). On the App Store
            // build they are intentionally absent from the list above, so state
            // that plainly rather than show a tool the build can't run.
            if showsProDeveloperNote {
                Text("Git, diff, shell, and CLI-agent tools (Codex, Claude Code) run only in the Pro build.")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(width: 320)
        .task {
            mcpServers = MCPUrlServerDirectory.discover()
            // P2.4 — populate the discovered-skill catalog (cached; cheap).
            agentCommandCenter.refreshSkillCatalog()
        }
    }

    /// P2.4 — in-chat skill browser. Lists the discovered skills (procedural
    /// memory) so the user can see + run them without remembering to type `/`.
    /// Running primes the composer with the skill's `/identifier` slash token —
    /// the same real run path the slash menu uses. Creation/editing stays the
    /// real authoring path (Settings → Skills, or asking the agent's skill tool),
    /// surfaced honestly rather than duplicated as a half-wired form here.
    @ViewBuilder
    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Skills")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
            if agentCommandCenter.availableSkills.isEmpty {
                Text("No skills yet. Create one in Settings → Skills, or ask the agent to capture a reusable skill.")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(agentCommandCenter.availableSkills) { skill in
                    skillRow(skill)
                }
                Text("Create or edit skills in Settings → Skills, or ask the agent to capture one.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.top, 1)
            }
        }
    }

    @ViewBuilder
    private func skillRow(_ skill: SkillDiscoveryEntry) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 10))
                .foregroundStyle(theme.textTertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(skill.title)
                    .font(.system(size: 12, weight: .medium))
                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 4)
            if let onRunSkill {
                Button("Run") { onRunSkill(skill) }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11, weight: .semibold))
            }
        }
    }

    /// P2.3 — read-only "MCP servers wired" view. Shows exactly the URL servers
    /// the Rust bridge forwards (never a fake row); the empty state names the
    /// honest next action (edit the config) rather than offering a dead button.
    @ViewBuilder
    private var mcpServersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MCP servers")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
            if mcpServers.isEmpty {
                Text("No external MCP servers configured. Add HTTPS servers to ~/.config/mcp/url_servers.json to extend the agent on cloud turns.")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(mcpServers) { server in
                    HStack(spacing: 6) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textTertiary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(server.name)
                                .font(.system(size: 12, weight: .medium))
                            Text(server.host)
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        if server.declaresAuth {
                            badge("auth", color: .green)
                        }
                    }
                }
            }
        }
    }

    /// P7.6 — cowork CONNECTORS: the well-known connectors (Slack/Gmail/Drive/
    /// Notion) and whether each is ACTUALLY backed by a wired MCP server. A
    /// connector reads "connected" only when a real server matches — unwired ones
    /// point at the real config path, never a fake toggle.
    private var connectorsSection: some View {
        let statuses = CoworkConnectorDirectory.statuses(servers: mcpServers)
        let connected = statuses.filter(\.isConnected).count
        return VStack(alignment: .leading, spacing: 6) {
            Text("Connectors")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
            ForEach(statuses) { status in
                HStack(spacing: 6) {
                    Image(systemName: status.connector.systemImage)
                        .font(.system(size: 10))
                        .foregroundStyle(status.isConnected ? theme.textPrimary : theme.textTertiary)
                        .frame(width: 14)
                    Text(status.connector.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(status.isConnected ? theme.textPrimary : theme.textTertiary)
                    Spacer(minLength: 4)
                    if status.isConnected {
                        if status.declaresAuth { badge("auth", color: .green) }
                        badge("connected", color: .green)
                    } else {
                        Text("not connected")
                            .font(.system(size: 9.5))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            Text(connected == 0
                ? "Connect a service by adding its HTTPS MCP server to ~/.config/mcp/url_servers.json (its token is read from the Keychain/env it declares, never stored here). Connectors run on cloud agent turns."
                : "\(connected) of \(statuses.count) connected via wired MCP servers. Add more in ~/.config/mcp/url_servers.json.")
                .font(.system(size: 10))
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Agent tools")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(enabledCount) of \(totalCount) on")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            Button("All on") { agentCommandCenter.enableAllTools() }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .semibold))
                .disabled(enabledCount == totalCount)
            if EpistemosBestOfPreset.isEnabled {
                Button("Recommended") { agentCommandCenter.applyBestOfPreset() }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11, weight: .semibold))
                    .help("Enable the curated best-of power set (the broadly-useful core tools)")
            }
            Button("All off") { agentCommandCenter.disableAllTools() }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .semibold))
                .disabled(enabledCount == 0)
        }
    }

    @ViewBuilder
    private func toolRow(_ tool: OmegaToolDefinition) -> some View {
        Toggle(isOn: Binding(
            get: { agentCommandCenter.toolToggles[tool.name] ?? true },
            set: { _ in agentCommandCenter.toggleTool(tool.name) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(toolDisplayName(tool.name))
                        .font(.system(size: 12, weight: .medium))
                    if tool.destructive {
                        badge("destructive", color: .red)
                    } else if tool.requiresConfirmation {
                        badge("asks first", color: .orange)
                    }
                }
                if !tool.description.isEmpty {
                    Text(tool.description)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
    }

    @ViewBuilder
    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    /// Friendly group header for an agent id (safari / file / notes / …).
    private func agentDisplayName(_ agent: String) -> String {
        switch agent.lowercased() {
        case "safari", "browser": "Web"
        case "file", "files": "Files"
        case "notes", "vault": "Vault & notes"
        case "terminal", "shell": "Terminal"
        case "automation", "computer": "Automation"
        case "memory": "Memory"
        default: agent.prefix(1).uppercased() + agent.dropFirst()
        }
    }

    /// Humanize a dotted tool id (e.g. "vault.search" → "Vault search").
    private func toolDisplayName(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        guard let first = cleaned.first else { return name }
        return first.uppercased() + cleaned.dropFirst()
    }
}
