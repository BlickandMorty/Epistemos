import SwiftUI

// MARK: - Agent Panel View
// Sidebar dashboard showing agent status cards.
// Tap a card to open the agent's thread/detail.

struct AgentPanelView: View {
    @Environment(AgentEngine.self) private var engine
    @Environment(UIState.self) private var ui

    @State private var selectedAgent: AgentID?

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.3)
            agentCards
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "person.3")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.accent)

            Text("Agents")
                .font(.epHeading)
                .foregroundStyle(theme.foreground)

            Spacer()

            Circle()
                .fill(engine.isRunning ? Color.green : theme.textTertiary)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Agent Cards

    private var agentCards: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(AgentID.allCases, id: \.self) { agentId in
                    AgentCardView(
                        agentId: agentId,
                        status: engine.status(for: agentId),
                        isSelected: selectedAgent == agentId
                    )
                    .onTapGesture {
                        withAnimation(Motion.smooth) {
                            selectedAgent = selectedAgent == agentId ? nil : agentId
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
    }
}

// MARK: - Agent Card View

struct AgentCardView: View {
    let agentId: AgentID
    let status: AgentStatus
    @Environment(UIState.self) private var ui

    let isSelected: Bool

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: agentId.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(agentId.displayName)
                        .font(.epBody)
                        .foregroundStyle(theme.foreground)

                    Text(status.label)
                        .font(.epCaption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if status.isActive {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .padding(Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? theme.accent.opacity(0.1) : theme.background.opacity(0.5))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? theme.accent.opacity(0.3) : .clear, lineWidth: 1)
        }
    }

    private var statusColor: Color {
        switch status {
        case .idle: theme.textTertiary
        case .thinking: theme.accent
        case .working: Color.green
        case .waitingForApproval: Color.orange
        case .error: Color.red
        }
    }
}
