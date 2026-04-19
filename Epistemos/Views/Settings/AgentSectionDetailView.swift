import SwiftUI

/// Consolidated "Agent" section in Settings. Replaces the three separate
/// nav entries (Agent Control, Authority & Installs, Overseer) with one
/// detail view hosting all three under a segmented picker at the top.
/// User sees a single "Agent" row in the sidebar and switches tabs once
/// they arrive instead of navigating back-and-forth across three nav
/// entries that all govern agent behavior.
struct AgentSectionDetailView: View {
    enum AgentTab: String, CaseIterable, Identifiable {
        case control = "Overview"
        case authority = "Authority"
        case overseer = "Overseer"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .control: "slider.horizontal.3"
            case .authority: "checkmark.shield.fill"
            case .overseer: "brain.head.profile"
            }
        }

        var shortDescription: String {
            switch self {
            case .control: "Tools, recent activity, sessions."
            case .authority: "What the agent can do without asking you first."
            case .overseer: "Read-only audit trail of routing decisions per turn."
            }
        }
    }

    let authorityStore: AgentAuthorityStore

    @State private var selectedTab: AgentTab

    init(
        authorityStore: AgentAuthorityStore,
        initialTab: AgentTab = .control
    ) {
        self.authorityStore = authorityStore
        self._selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            segmentedHeader
            Divider().opacity(0.3)
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var segmentedHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Agent")
                    .font(.title2.weight(.semibold))
                Spacer()
            }

            Picker("Agent detail", selection: $selectedTab) {
                ForEach(AgentTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(selectedTab.shortDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .control:
            AgentControlDetailView()
        case .authority:
            AuthoritySettingsView(store: authorityStore)
        case .overseer:
            OverseerSettingsView()
        }
    }
}
