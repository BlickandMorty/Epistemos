import SwiftUI

// MARK: - ProAgentHealthRow
//
// Agent-surface diagnostics (Plan 1-PRO / perf doctrine §4): the owner-visible
// producer for the [agent_surface] budget numbers — supervisor status, child
// ports, and the felt-speed measurements (cold open / SPA ready / warm
// reopen) against their contracts. Mirrors the read-only tone of the other
// Settings health rows. MAS builds render nothing (the Pro surface does not
// exist there).

@MainActor
struct ProAgentHealthRow: View {
    #if !EPISTEMOS_APP_STORE
    private var supervisor: ProAgentRuntimeSupervisor { .shared }
    private var metrics: ProAgentPerfMetrics { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Agent Surface (Pro)")
                .font(.system(size: 12, weight: .semibold))

            statusLine

            metricLine(
                label: "Cold open",
                value: metrics.coldOpenMs,
                budgetMs: 1_500
            )
            metricLine(
                label: "SPA ready",
                value: metrics.spaReadyMs,
                budgetMs: 1_000
            )
            metricLine(
                label: "Warm reopen",
                value: metrics.warmReopenMs,
                budgetMs: 100
            )

            if let diagnostic = supervisor.lastDiagnostic, !diagnostic.isEmpty {
                Text(diagnostic)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch supervisor.status {
        case .idle:
            detailText("supervisor idle — opens on first Agent visit (lazy start)")
        case .starting:
            detailText("starting children…")
        case .running(let connection):
            detailText(
                "running — ui :\(connection.uiPort) · opencode :\(connection.opencodePort)"
            )
        case .failed(let message):
            detailText("failed — \(message)")
        case .unavailable(let message):
            detailText("unavailable — \(message)")
        case .stopped:
            detailText("stopped")
        }
    }

    private func detailText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }

    private func metricLine(label: String, value: Double?, budgetMs: Double) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if let value {
                Text("\(Int(value.rounded())) ms")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(value <= budgetMs ? Color.green : Color.orange)
                Text("budget \(Int(budgetMs))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                Text("not exercised")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
    #else
    var body: some View { EmptyView() }
    #endif
}
