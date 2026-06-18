import SwiftUI

/// P2.1 (UI) — in-chat tool control. A compact panel, opened from the composer,
/// that lists the agent tools the registry surfaces and lets the user turn each
/// on/off. This is REAL config, not decoration: the toggles flow into
/// `AgentCommandCenterState.toolToggles` → `disabledToolNames`, which
/// `ChatCoordinator.executionPlanGatedByUserToolToggles` applies to the main-chat
/// execution plan (commit a731469a6) — a tool turned off here is removed from the
/// plan's `tool_permissions` for this chat's agent turns.
///
/// Honest gating: destructive tools and tools that ask before acting are
/// badged, and a footer states the capability truth (local models chat + reason;
/// multi-step tool runs use a cloud model or the Pro harness). It only shows
/// tools the current build actually surfaces, so nothing here is a fake control.
@MainActor
struct AgentToolTogglePanel: View {
    let agentCommandCenter: AgentCommandCenterState
    let theme: EpistemosTheme

    /// Tools grouped by their owning agent, agents in a stable display order.
    private var groupedTools: [(agent: String, tools: [OmegaToolDefinition])] {
        let groups = Dictionary(grouping: agentCommandCenter.availableTools, by: \.agent)
        return groups
            .map { (agent: $0.key, tools: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.agent < $1.agent }
    }

    private var enabledCount: Int { agentCommandCenter.enabledToolNames.count }
    private var totalCount: Int { agentCommandCenter.availableTools.count }

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
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 320)

            Divider()

            Text("Local models chat + reason; multi-step tool runs use a cloud model or the Pro harness. Turning a tool off removes it from this chat's agent turns.")
                .font(.system(size: 10))
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 320)
        .task { mcpServers = MCPUrlServerDirectory.discover() }
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
