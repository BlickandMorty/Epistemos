import SwiftUI

// MARK: - CognitiveDagHealthRow
//
// V2 Final Lane (2026-05-05) settings diagnostic — read-only status row
// for the global Rust cognitive DAG. Mirrors the shape of
// EditorBundleHealthRow / SearchFusionHealthRow / OpLogProjectionHealthRow.
//
// Surfaces:
//   - Node count (typed cognitive nodes per cognitive_dag::NodeKind)
//   - Edge count (typed Merkle-signed edges per EdgeKind)
//   - First 12 chars of the BLAKE3 merkle root (the canonical content
//     hash of the entire DAG)
//   - "DAG empty" label when nothing has been mirrored yet
//
// Per cognitive DAG doctrine §10 the DAG is READ-ONLY from the app's
// perspective until Phase 8.H flips authority. This row is the doctrine-
// safe minimal surface that proves the DAG is reachable + observable
// from the running app — Phase 8.H will swap the read path so the legacy
// subsystem stores become read-only fallbacks.

@MainActor
public struct CognitiveDagHealthRow: View {

    @State private var stats: RustCognitiveDagStats = .empty
    @State private var refreshTask: Task<Void, Never>? = nil

    private let refreshInterval: TimeInterval

    public init(refreshInterval: TimeInterval = 5.0) {
        self.refreshInterval = refreshInterval
    }

    public var body: some View {
        row(
            label: "Cognitive DAG",
            symbol: "circle.grid.cross",
            ok: stats.schemaVersion > 0,
            detail: detailLabel
        )
        .onAppear {
            refresh()
            startTimer()
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    private var detailLabel: String {
        if stats.isEmpty {
            // ISSUE-2026-05-12-003 — make the empty state explanatory.
            // The DAG populates on skill loads, claim commits, procedure
            // recordings, and companion registrations. Tell the user what
            // they need to do to see this row turn green instead of
            // leaving "waiting for mirrors" as a mystery.
            return "empty — populates on skill / claim / procedure / companion events"
        }
        return "\(stats.nodeCount) nodes · \(stats.edgeCount) edges · root \(rootShort)"
    }

    private var rootShort: String {
        String(stats.merkleRootHex.prefix(12))
    }

    private func refresh() {
        let snapshot = RustCognitiveDagClient.stats()
        if snapshot != stats {
            stats = snapshot
        }
    }

    private func startTimer() {
        refreshTask?.cancel()
        let interval = refreshInterval
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { break }
                refresh()
            }
        }
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
            Image(systemName: ok ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(
                    ok ? Color.green : Color.secondary
                )
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Cognitive DAG: \(stats.nodeCount) nodes, \(stats.edgeCount) edges, schema version \(stats.schemaVersion)"
        )
    }
}
