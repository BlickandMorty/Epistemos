import SwiftUI

// MARK: - Session List View

/// Sidebar section showing persistent agent sessions grouped by date.
/// Tapping a session loads its `summary.md` in a detail pane.
struct SessionListView: View {
    let browser: SessionBrowser
    let vaultPath: String

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
        List(selection: Binding(
            get: { browser.selectedSession },
            set: { browser.selectedSession = $0 }
        )) {
            ForEach(browser.groups) { group in
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

            if let classification = session.trajectoryClassification {
                Text(classification.capitalized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(trajectoryColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(trajectoryColor.opacity(0.12), in: Capsule())
            }
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

    private var trajectoryColor: Color {
        switch session.trajectoryClassification {
        case "efficient": return .green
        case "exploratory": return .blue
        case "hesitating": return .orange
        case "stuck": return .yellow
        case "failed": return .red
        default: return .secondary
        }
    }
}

// MARK: - Session Detail View

/// Shows the summary.md content for a selected session.
struct SessionDetailView: View {
    let browser: SessionBrowser
    let session: SessionBrowser.SessionInfo

    @State private var summary: String?
    @State private var metadataJSON: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let summary {
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
            metadataJSON = browser.loadMetadata(for: session)
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

            Text(session.folderPath)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
    }
}
