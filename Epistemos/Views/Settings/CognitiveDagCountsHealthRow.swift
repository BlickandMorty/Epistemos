import SwiftUI

// MARK: - CognitiveDagCountsHealthRow
//
// W-26 consumer for Terminal D: live 1 Hz readout of cognitive DAG
// node / edge counts, plus compact per-kind breakdowns.

@MainActor
public struct CognitiveDagCountsHealthRow: View {
    @State private var snapshot: SubstrateHealthUnifiedSnapshot

    public init() {
        self._snapshot = State(initialValue: SubstrateHealthUnifiedClient.snapshot())
    }

    public var body: some View {
        let dag = snapshot.cognitiveDagCounts
        VStack(alignment: .leading, spacing: 8) {
            SubstrateHealthMetricLine(
                label: "Cognitive DAG counts",
                symbol: "circle.grid.cross",
                state: dag.ffiReachable ? .partial : .unavailable,
                detail: "\(dag.nodeCount) nodes; \(dag.edgeCount) edges; schema \(dag.schemaVersion)"
            )
            VerifiedFloorChipStrip(
                flag: "n/a",
                substrate: dag.ffiReachable ? "read-only mirror" : "unavailable",
                productionWired: false,
                falsifierPassed: false,
                falsifier: dag.falsifier,
                wiredToday: "Cognitive DAG counts and schema version are projected from the unified FFI snapshot.",
                stillStub: "Counts are status-only until ACS anchor addressing has a primary PASS witness."
            )
            SubstrateHealthMetricLine(
                label: "Node kinds",
                symbol: "list.bullet.rectangle",
                state: dag.nodeKindCounts.isEmpty ? .unavailable : .partial,
                detail: compactCounts(dag.nodeKindCounts)
            )
            SubstrateHealthMetricLine(
                label: "Edge kinds",
                symbol: "arrow.left.and.right",
                state: dag.edgeKindCounts.isEmpty ? .unavailable : .partial,
                detail: compactCounts(dag.edgeKindCounts)
            )
            SubstrateHealthMetricLine(
                label: "Merkle root",
                symbol: "number",
                state: dag.merkleRootHex.isEmpty ? .unavailable : .partial,
                detail: dag.merkleRootHex.isEmpty ? "unavailable" : String(dag.merkleRootHex.prefix(16))
            )
        }
        .substrateHealthPoll { refresh() }
    }

    private func compactCounts(_ counts: [String: Int]) -> String {
        guard !counts.isEmpty else { return "empty" }
        return counts
            .sorted { $0.key < $1.key }
            .prefix(5)
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
    }

    private func refresh() {
        // SS-SH: fetch OFF the MainActor so the 1Hz poll never blocks the panel.
        Task { snapshot = await SubstrateHealthUnifiedClient.snapshotAsync() }
    }
}

#if DEBUG
#Preview("CognitiveDagCountsHealthRow") {
    CognitiveDagCountsHealthRow()
        .padding()
        .frame(width: 460)
}
#endif
