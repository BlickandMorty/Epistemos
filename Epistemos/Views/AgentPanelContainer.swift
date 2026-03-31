import SwiftUI

// MARK: - Agent Panel Container

/// Tabbed container for the Hermes agent runtime panel.
/// Provides access to Chat, Skills, and Execution Graph views
/// all connected to the real Hermes agent system.
struct AgentPanelContainer: View {
    let viewModel: AgentViewModel

    @State private var selectedTab: AgentPanelTab = .chat

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(AgentPanelTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)

            Divider()

            // Content
            Group {
                switch selectedTab {
                case .chat:
                    AgentSessionPanel(viewModel: viewModel)
                case .skills:
                    HermesSkillsView(viewModel: viewModel)
                case .graph:
                    HermesExecutionGraphView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func tabButton(_ tab: AgentPanelTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.caption)
                Text(tab.label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                selectedTab == tab
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab Definition

enum AgentPanelTab: String, CaseIterable {
    case chat
    case skills
    case graph

    var label: String {
        switch self {
        case .chat: "Chat"
        case .skills: "Skills"
        case .graph: "Graph"
        }
    }

    var icon: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right"
        case .skills: "wrench.and.screwdriver"
        case .graph: "point.3.connected.trianglepath.dotted"
        }
    }
}
