import SwiftUI

// MARK: - AgentEventVisibilityRow

@MainActor
struct AgentEventVisibilityRow: View {
    @State private var snapshot: EventStore.AgentEventDiagnostics

    init() {
        _snapshot = State(initialValue: Self.snapshot())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "Agent events",
                symbol: "checklist.checked",
                ok: true,
                detail: agentEventDetail
            )
            row(
                label: "Latest agent event",
                symbol: snapshot.latestEvent == nil ? "circle.dotted" : "clock.badge.checkmark",
                ok: true,
                detail: latestEventDetail
            )
        }
        .onAppear { refresh() }
    }

    func refresh() {
        snapshot = Self.snapshot()
    }

    private static func snapshot() -> EventStore.AgentEventDiagnostics {
        EventStore.shared?.agentEventDiagnostics() ?? .empty
    }

    private var agentEventDetail: String {
        guard snapshot.totalRows > 0 else {
            return "No durable agent events yet"
        }
        return "\(snapshot.totalRows) events across \(snapshot.distinctRuns) run(s), \(snapshot.distinctTools) tool(s)"
    }

    private var latestEventDetail: String {
        guard let event = snapshot.latestEvent else {
            return "Waiting for committed agent/tool provenance"
        }
        let eventID = event.eventID.isEmpty ? "unknown" : String(event.eventID.prefix(12))
        let runID = event.runID.isEmpty ? "unknown" : String(event.runID.prefix(12))
        if let toolName = event.tool?.toolName, !toolName.isEmpty {
            return "\(event.kind.rawValue) | \(eventID) | \(runID) | \(toolName)"
        }
        return "\(event.kind.rawValue) | \(eventID) | \(runID)"
    }

    @ViewBuilder
    private func row(label: String, symbol: String, ok: Bool, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? Color.green : Color.red)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .diagnosticsRowAccessibility(label: label, detail: detail, isHealthy: ok)
    }
}
