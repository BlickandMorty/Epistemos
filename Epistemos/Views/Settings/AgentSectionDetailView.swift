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
        case blueprints = "Blueprints"
        case authority = "Authority"
        case overseer = "Overseer"
        // W9.6 — Agent spend dashboard. Visible in BOTH builds (MAS
        // and Pro) because cost transparency is a privacy/trust
        // surface that applies even when only AFM + local models
        // are wired. MAS/direct builds render unavailable provider
        // costs as unavailable, not as synthetic zero spend.
        case spend = "Spend"
        // StructureRegistry — transparency: every @Generable schema
        // the host knows about, with surface + storage + maturity.
        // Visible in BOTH builds because the registry IS the
        // anti-fake-features surface (PLAN_V2 §3.4 capability honesty
        // — the user can audit "what kinds of structured data does
        // this app actually produce?"). Wire-up for the orphan
        // StructureRegistry abstraction landed in audit+protocol
        // commit 75a579f4 — this tab is the first reader.
        case structures = "Structures"

        var id: String { rawValue }

        static var visibleTabs: [AgentTab] {
            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            [.authority, .spend, .structures]
            #else
            allCases
            #endif
        }

        var isVisibleInCurrentBuild: Bool {
            Self.visibleTabs.contains(self)
        }

        var systemImage: String {
            switch self {
            case .control: "slider.horizontal.3"
            case .blueprints: "person.crop.rectangle.stack"
            case .authority: "checkmark.shield.fill"
            case .overseer: "brain.head.profile"
            case .spend: "dollarsign.circle"
            case .structures: "rectangle.3.group"
            }
        }

        var shortDescription: String {
            switch self {
            case .control: "Tools, recent activity, sessions."
            case .blueprints: "Create and run typed local-agent missions."
            case .authority: "What the agent can do without asking you first."
            case .overseer: "Read-only audit trail of routing decisions per turn."
            case .spend: "Token usage, cache rate, and budget cap."
            case .structures: "Every structured-data schema this build produces."
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
        self._selectedTab = State(initialValue: initialTab.isVisibleInCurrentBuild ? initialTab : .authority)
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
                ForEach(AgentTab.visibleTabs) { tab in
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
        case .blueprints:
            AgentBlueprintSettingsView()
        case .authority:
            AuthoritySettingsView(store: authorityStore)
        case .overseer:
            OverseerSettingsView()
        case .spend:
            // W9.6 — Cost dashboard. N1 Phase 1 closure
            // (MASTER_BUILD_PLAN.md:311) wires real session_metrics
            // rows in: each row carries the input/output/cache token
            // counts that ChatCoordinator persists via
            // EventStore.saveSessionMetrics after each agent run. Provider
            // and per-session cost remain nil until the schema tracks them,
            // so the UI renders those fields as unavailable rather than
            // inventing $0.00 estimates.
            SpendDashboardHost()
        case .structures:
            // First reader of the StructureRegistry. Surfaces every
            // @Generable schema with surface + storage + maturity so
            // the user can audit what the app actually structures.
            // This is the WRV Visible signal for the registry —
            // before this tab landed, StructureRegistry.allSchemas
            // had zero callers in the production code paths.
            StructuredSurfacesView()
        }
    }
}

// MARK: - Spend dashboard host (N1 Phase 1 closure)
//
// Pulls the most recent session_metrics rows from EventStore and
// projects them into the [CostDashboardEntry] shape that
// CostDashboardView consumes. The .task block runs on tab switch and
// keeps the read off the main thread (EventStore.recentSessionMetrics
// is `nonisolated` so it dispatches onto the EventStore's serial
// SQLite queue).
//
// Provider and per-session USD are explicitly unavailable here because
// the session_metrics schema does not yet carry those columns. The W9.6
// success criterion per MASTER_BUILD_PLAN.md:390 is the aggregate cache
// hit rate, which depends only on the input + cache_read columns persisted
// in PR2.

private struct SpendDashboardHost: View {
    @State private var entries: [CostDashboardEntry] = []

    var body: some View {
        CostDashboardView(entries: entries)
            .task {
                let records = await Task.detached(priority: .userInitiated) {
                    EventStore.shared?.recentSessionMetrics(limit: 30) ?? []
                }.value
                entries = records.map { record in
                    CostDashboardEntry(
                        id: record.sessionId,
                        title: shortTitle(for: record.sessionId),
                        provider: nil,
                        inputTokens: record.inputTokens,
                        outputTokens: record.outputTokens,
                        estimatedCostUSD: nil,
                        startedAt: record.recordedAt,
                        cacheReadInputTokens: record.cacheReadInputTokens,
                        cacheCreationInputTokens: record.cacheCreationInputTokens
                    )
                }
            }
    }

    private func shortTitle(for sessionId: String) -> String {
        // Until session_metrics tracks an objective column, surface a
        // short prefix of the session id so the row is at least
        // identifiable. Trim to the first 8 chars to match the format
        // EventStore log lines already use ("session \(sessionId.prefix(8))").
        "Session \(sessionId.prefix(8))"
    }
}
