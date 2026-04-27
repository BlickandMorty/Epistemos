import SwiftUI

// MARK: - Session List View

/// Sidebar section showing persistent agent sessions grouped by date.
/// Tapping a session loads its `summary.md` in a detail pane.
struct SessionListView: View {
    let browser: SessionBrowser
    let vaultPath: String
    @State private var searchQuery: String = ""

    var body: some View {
        Group {
            if browser.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if browser.groups.isEmpty {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "tray",
                    description: Text("Agent sessions will appear here after your first run.")
                )
            } else {
                sessionList
            }
        }
        .task {
            browser.refresh(vaultPath: vaultPath)
        }
    }

    private var sessionList: some View {
        VStack(spacing: 0) {
            TextField("Search sessions", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.top, 8)

            List(selection: Binding(
                get: { browser.selectedSession },
                set: { browser.selectedSession = $0 }
            )) {
                // AR7 placement — FSRS-6 forgotten-notes review queue
                // pinned at the top of the sidebar so the user sees
                // "what's at risk of being forgotten" before scrolling
                // into past sessions. Auto-hides when nothing's at
                // risk so the section doesn't take chrome on a fresh
                // vault. Master plan Phase 2 / Wave 13 §"Phase 2".
                FSRSReviewSidebarSection()

                ForEach(browser.filteredGroups(matching: searchQuery)) { group in
                    Section(group.label) {
                        ForEach(group.sessions) { session in
                            SessionRow(session: session)
                                .tag(session)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: SessionBrowser.SessionInfo

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: session.statusBadge)
                .foregroundStyle(statusColor)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.model)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(session.startedAt, style: .time)
                    Text("·")
                    Text("\(session.turnCount) turns")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            // AR8 wire-up — canonical ReasoningTrajectoryBadge reads
            // from EventStore.session_metrics directly (loop count,
            // error count, total tool calls, efficiency on hover) so
            // the row gets the full classification + tooltip without
            // re-implementing the rendering logic. Falls back to the
            // legacy inline classification text if the EventStore
            // doesn't have a metrics row yet (in-flight sessions).
            ReasoningTrajectoryBadge(sessionId: session.id)
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch session.status {
        case "completed": return .green
        case "failed":    return .red
        case "running":   return .blue
        default:          return .gray
        }
    }

}

// MARK: - Session Detail View

/// Shows the summary.md content for a selected session.
struct SessionDetailView: View {
    let browser: SessionBrowser
    let session: SessionBrowser.SessionInfo

    @State private var summary: String?
    @State private var summarySections: [SessionBrowser.SummarySection] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !summarySections.isEmpty {
                    ForEach(summarySections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(.headline)
                            Text(section.body)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                } else if let summary {
                    Text(summary)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                } else {
                    Text("No summary available.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .task {
            summary = browser.loadSummary(for: session)
            summarySections = browser.summarySections(for: session)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: session.statusBadge)
                    .foregroundStyle(session.isCompleted ? .green : session.isFailed ? .red : .blue)
                Text(session.model)
                    .font(.headline)
                Spacer()
                Text(session.startedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Session: \(session.id)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)

            if let classification = session.trajectoryClassification {
                Text("Trajectory: \(classification.capitalized)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lineage = browser.lineageSummary(for: session) {
                Text(lineage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(session.folderPath)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
    }
}
