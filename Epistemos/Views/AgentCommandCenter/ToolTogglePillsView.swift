import SwiftUI

// MARK: - Tool Toggle Pills View
// Horizontal scrollable capsule row — one pill per tool from OmegaToolRegistry,
// grouped by agent. Tap to toggle. Dimmed + strikethrough when disabled.

struct ToolTogglePillsView: View {
    @Environment(AgentCommandCenterState.self) private var accState
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    private let agentIcons: [String: String] = [
        "safari": "safari",
        "file": "folder",
        "notes": "doc.text",
        "terminal": "terminal",
        "automation": "gearshape.2",
    ]

    private let agentOrder = ["safari", "file", "notes", "terminal", "automation"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Quick toggle all
                Button {
                    let allEnabled = accState.toolToggles.values.allSatisfy { $0 }
                    if allEnabled {
                        accState.disableAllTools()
                    } else {
                        accState.enableAllTools()
                    }
                } label: {
                    let allEnabled = accState.toolToggles.values.allSatisfy { $0 }
                    HStack(spacing: 4) {
                        Image(systemName: allEnabled ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 10, weight: .medium))
                        Text("All")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .foregroundStyle(allEnabled ? theme.resolved.accent.color : theme.mutedForeground.opacity(0.5))
                    .background(
                        allEnabled ? theme.resolved.accent.color.opacity(0.1) : theme.mutedForeground.opacity(0.04),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                allEnabled ? theme.resolved.accent.color.opacity(0.2) : theme.mutedForeground.opacity(0.08),
                                lineWidth: 0.5
                            )
                    }
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 18)
                    .opacity(0.3)

                // Tools by agent
                ForEach(agentOrder, id: \.self) { agent in
                    if let tools = accState.mcpToolsByAgent[agent], !tools.isEmpty {
                        ForEach(tools, id: \.name) { tool in
                            toolPill(tool: tool, agent: agent)
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func toolPill(tool: OmegaToolDefinition, agent: String) -> some View {
        let isEnabled = accState.toolToggles[tool.name] ?? true
        let icon = agentIcons[agent] ?? "wrench"
        let tint = agentTint(agent)

        return Button {
            accState.toggleTool(tool.name)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isEnabled ? tint : theme.mutedForeground.opacity(0.35))
                Text(tool.name)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .lineLimit(1)

                if tool.destructive {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(isEnabled ? Color.white.opacity(0.72) : theme.mutedForeground.opacity(0.35))
            .background(
                isEnabled ? tint.opacity(0.085) : theme.mutedForeground.opacity(0.02),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        isEnabled ? tint.opacity(0.24) : theme.mutedForeground.opacity(0.05),
                        lineWidth: 0.5
                    )
            }
            .strikethrough(!isEnabled, color: theme.mutedForeground.opacity(0.3))
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .help(tool.description)
        .animation(.easeInOut(duration: 0.15), value: isEnabled)
    }

    private func agentTint(_ agent: String) -> Color {
        switch agent {
        case "safari":
            Color(red: 0.36, green: 0.58, blue: 0.98)
        case "file":
            Color(red: 0.36, green: 0.82, blue: 0.56)
        case "notes":
            Color(red: 0.74, green: 0.48, blue: 1.0)
        case "terminal":
            Color(red: 0.96, green: 0.42, blue: 0.55)
        case "automation":
            Color(red: 0.91, green: 0.78, blue: 0.30)
        default:
            theme.resolved.accent.color
        }
    }
}
