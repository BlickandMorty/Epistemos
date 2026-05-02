import SwiftUI

// MARK: - GraphEventVisibilityRow

@MainActor
struct GraphEventVisibilityRow: View {
    @State private var snapshot: EventStore.GraphEventDiagnostics

    init() {
        _snapshot = State(initialValue: Self.snapshot())
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

    private static func snapshot() -> EventStore.GraphEventDiagnostics {
        EventStore.shared?.graphEventDiagnostics() ?? .empty
    }

    private var graphEventDetail: String {
        guard snapshot.totalRows > 0 else {
            return "No durable graph events yet"
        }
        return "\(snapshot.totalRows) events across \(snapshot.distinctMutations) mutation(s)"
    }

    private var latestEventDetail: String {
        guard let event = snapshot.latestEvent else {
            return "Waiting for committed graph-affecting mutations"
        }
        let eventID = event.eventID.isEmpty ? "unknown" : String(event.eventID.prefix(12))
        let mutationID = event.mutationID.isEmpty ? "unknown" : String(event.mutationID.prefix(12))
        return "\(event.kind.rawValue) | \(eventID) | \(mutationID)"
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
    }
}
