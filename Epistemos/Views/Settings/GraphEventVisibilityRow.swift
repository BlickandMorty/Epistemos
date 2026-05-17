import SwiftUI

// MARK: - GraphEventVisibilityRow

@MainActor
struct GraphEventVisibilityRow: View {
    @State private var diagnostics: EventStore.GraphEventDiagnostics
    @State private var projectionSnapshot: DurableGraphProjectionSnapshot
    @State private var auditProjectionReport: GraphEventAuditProjectionReport

    init() {
        _diagnostics = State(initialValue: Self.diagnosticsSnapshot())
        _projectionSnapshot = State(initialValue: Self.projectionSnapshot())
        _auditProjectionReport = State(initialValue: Self.auditReport())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "Graph events",
                symbol: "point.3.connected.trianglepath.dotted",
                ok: true,
                detail: graphEventDetail
            )
            row(
                label: "Latest graph event",
                symbol: diagnostics.latestEvent == nil ? "circle.dotted" : "clock.badge.checkmark",
                ok: true,
                detail: latestEventDetail
            )
            row(
                label: "Projection snapshot",
                symbol: projectionSnapshot.eventCount == 0 ? "circle.dotted" : "point.3.filled.connected.trianglepath.dotted",
                ok: true,
                detail: projectionDetail
            )
            row(
                label: "Audit projection",
                symbol: auditProjectionReport.isEmpty ? "circle.dotted" : "checkmark.seal",
                ok: true,
                detail: auditProjectionDetail
            )
        }
        .onAppear { refresh() }
    }

    func refresh() {
        diagnostics = Self.diagnosticsSnapshot()
        projectionSnapshot = Self.projectionSnapshot()
        auditProjectionReport = Self.auditReport()
    }

    private static func diagnosticsSnapshot() -> EventStore.GraphEventDiagnostics {
        EventStore.shared?.graphEventDiagnostics() ?? .empty
    }

    private static func projectionSnapshot() -> DurableGraphProjectionSnapshot {
        EventStore.shared?.graphEventProjectionSnapshot(limit: 100) ?? DurableGraphEventProjection.snapshot(from: [])
    }

    private static func auditReport() -> GraphEventAuditProjectionReport {
        GraphEventAuditProjectionService().auditReport(limit: 100)
    }

    private var graphEventDetail: String {
        guard diagnostics.totalRows > 0 else {
            return "No durable graph events yet"
        }
        return "\(diagnostics.totalRows) events across \(diagnostics.distinctMutations) mutation(s)"
    }

    private var latestEventDetail: String {
        guard let event = diagnostics.latestEvent else {
            return "Waiting for committed graph-affecting mutations"
        }
        let eventID = event.eventID.isEmpty ? "unknown" : String(event.eventID.prefix(12))
        let mutationID = event.mutationID.isEmpty ? "unknown" : String(event.mutationID.prefix(12))
        return "\(event.kind.rawValue) | \(eventID) | \(mutationID)"
    }

    private var projectionDetail: String {
        guard projectionSnapshot.eventCount > 0 else {
            return "No projection snapshot yet"
        }
        return "\(projectionSnapshot.eventCount) events | \(projectionSnapshot.nodes.count) nodes | \(projectionSnapshot.edges.count) edges"
    }

    private var auditProjectionDetail: String {
        guard !auditProjectionReport.isEmpty else {
            return "No audit projection report yet"
        }
        let latestEventID = auditProjectionReport.latestEventID.map { String($0.prefix(12)) } ?? "none"
        return "\(auditProjectionReport.eventCount) events | \(auditProjectionReport.nodeCount) nodes | \(auditProjectionReport.edgeCount) edges | latest \(latestEventID)"
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
                .foregroundStyle(ok ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.red))
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .diagnosticsRowAccessibility(label: label, detail: detail, isHealthy: ok)
    }
}
