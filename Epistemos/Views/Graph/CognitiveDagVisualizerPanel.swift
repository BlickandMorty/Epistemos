import SwiftUI

nonisolated struct CognitiveDagVisualizerCountRow: Identifiable, Equatable, Sendable {
    let label: String
    let count: Int

    var id: String { label }
}

nonisolated struct CognitiveDagVisualizerModel: Equatable, Sendable {
    let nodeCount: Int
    let edgeCount: Int
    let schemaVersion: UInt32
    let merkleRootShort: String
    let nodeRows: [CognitiveDagVisualizerCountRow]
    let edgeRows: [CognitiveDagVisualizerCountRow]
    let isReachable: Bool

    init(dag: SubstrateHealthUnifiedSnapshot.CognitiveDagCounts) {
        nodeCount = dag.nodeCount
        edgeCount = dag.edgeCount
        schemaVersion = dag.schemaVersion
        merkleRootShort = dag.merkleRootHex.isEmpty
            ? "unavailable"
            : String(dag.merkleRootHex.prefix(12))
        nodeRows = Self.sortedCountRows(dag.nodeKindCounts)
        edgeRows = Self.sortedCountRows(dag.edgeKindCounts)
        isReachable = dag.ffiReachable
    }

    static let empty = CognitiveDagVisualizerModel(dag: .unavailable)

    static func sortedCountRows(
        _ counts: [String: Int],
        limit: Int = 5
    ) -> [CognitiveDagVisualizerCountRow] {
        counts
            .filter { $0.value > 0 }
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key < $1.key
            }
            .prefix(limit)
            .map { CognitiveDagVisualizerCountRow(label: $0.key, count: $0.value) }
    }
}

@MainActor
struct CognitiveDagVisualizerPanel: View {
    let theme: EpistemosTheme
    let refreshInterval: TimeInterval

    @State private var model: CognitiveDagVisualizerModel = .empty
    @State private var refreshTask: Task<Void, Never>?

    init(theme: EpistemosTheme, refreshInterval: TimeInterval = 1.0) {
        self.theme = theme
        self.refreshInterval = refreshInterval
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            countSummary
            countSection(title: "Node kinds", rows: model.nodeRows, emptyLabel: "no mirrored nodes")
            countSection(title: "Relationships", rows: model.edgeRows, emptyLabel: "no mirrored edges")
        }
        .padding(12)
        .frame(width: 306, alignment: .leading)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.glassBorder.opacity(theme.isDark ? 0.74 : 0.58), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(theme.isDark ? 0.24 : 0.10), radius: 14, y: 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            refresh()
            startRefreshTask()
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.grid.cross")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(model.isReachable ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Cognitive DAG")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text("read-only mirror · schema \(model.schemaVersion)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(model.isReachable ? "live" : "offline")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(model.isReachable ? Color.orange : Color.secondary)
        }
    }

    private var countSummary: some View {
        HStack(spacing: 8) {
            summaryPill(label: "nodes", value: model.nodeCount)
            summaryPill(label: "edges", value: model.edgeCount)
            VStack(alignment: .leading, spacing: 1) {
                Text("root")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(model.merkleRootShort)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func summaryPill(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
        }
        .frame(width: 54, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.glassBg.opacity(theme.isDark ? 0.82 : 0.72))
        )
    }

    @ViewBuilder
    private func countSection(
        title: String,
        rows: [CognitiveDagVisualizerCountRow],
        emptyLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            if rows.isEmpty {
                Text(emptyLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(rows) { row in
                        HStack(spacing: 8) {
                            Text(row.label)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 8)
                            Text("\(row.count)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(theme.card.opacity(theme.isDark ? 0.90 : 0.96))
    }

    private var accessibilityLabel: String {
        "Cognitive DAG live mirror, \(model.nodeCount) nodes, \(model.edgeCount) edges, schema \(model.schemaVersion)"
    }

    private func refresh() {
        let snapshot = SubstrateHealthUnifiedClient.snapshot()
        let next = CognitiveDagVisualizerModel(dag: snapshot.cognitiveDagCounts)
        if next != model {
            model = next
        }
    }

    private func startRefreshTask() {
        refreshTask?.cancel()
        let refreshInterval = refreshInterval
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(refreshInterval))
                if Task.isCancelled { break }
                refresh()
            }
        }
    }
}

#if DEBUG
#Preview("Cognitive DAG Visualizer") {
    CognitiveDagVisualizerPanel(theme: .platinumVioletDark)
        .padding()
        .frame(width: 360)
}
#endif
