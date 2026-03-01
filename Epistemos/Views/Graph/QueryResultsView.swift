import SwiftUI

// MARK: - QueryResultsView
// Displays results from the QueryEngine in the HologramSearchSidebar.
// Three display modes: list (default), aggregation table, edge list.

struct QueryResultsView: View {
    let result: QueryResult
    var onSelectNode: ((String) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                // Execution time
                HStack {
                    Text("\(result.nodes.count + result.edges.count + (result.aggregation?.rows.count ?? 0)) results")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.4))
                    Spacer()
                    Text(String(format: "%.1fms", result.executionTimeMs))
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.25))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                // Aggregation table
                if let agg = result.aggregation {
                    aggregationView(agg)
                }

                // Node results
                if !result.nodes.isEmpty {
                    ForEach(result.nodes) { node in
                        nodeResultRow(node)
                    }
                }

                // Edge results
                if !result.edges.isEmpty {
                    ForEach(result.edges) { edge in
                        edgeResultRow(edge)
                    }
                }

                if result.nodes.isEmpty && result.edges.isEmpty && result.aggregation == nil {
                    emptyState
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Node Row

    private func nodeResultRow(_ node: QueryResultNode) -> some View {
        Button {
            onSelectNode?(node.id)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(node.type.swiftUIColor)
                        .frame(width: 7, height: 7)

                    Text(node.label)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineLimit(1)

                    Spacer()

                    if let score = node.score {
                        Text(String(format: "%.1f", score))
                            .font(.system(size: 9, weight: .medium).monospacedDigit())
                            .foregroundStyle(.primary.opacity(0.25))
                    }

                    Text(node.type.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.3))
                }

                if let snippet = node.snippet, !snippet.isEmpty {
                    Text(snippet.replacingOccurrences(of: "<b>", with: "")
                        .replacingOccurrences(of: "</b>", with: ""))
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.4))
                        .lineLimit(2)
                        .padding(.leading, 15)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Edge Row

    private func edgeResultRow(_ edge: QueryResultEdge) -> some View {
        HStack(spacing: 6) {
            Text(edge.sourceLabel)
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.7))
                .lineLimit(1)

            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundStyle(.primary.opacity(0.3))

            Text(edge.type.rawValue)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.primary.opacity(0.4))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.primary.opacity(0.08), in: Capsule())

            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundStyle(.primary.opacity(0.3))

            Text(edge.targetLabel)
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.7))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    // MARK: - Aggregation

    private func aggregationView(_ agg: QueryAggregation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(agg.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.4)
                .padding(.horizontal, 12)
                .padding(.top, 4)

            ForEach(agg.rows, id: \.label) { row in
                HStack {
                    Text(row.label)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.8))

                    Spacer()

                    Text("\(row.value)")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(.primary.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundStyle(.primary.opacity(0.15))
            Text("No results found")
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
