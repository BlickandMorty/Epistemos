import SwiftUI

// MARK: - Node Detail Panel (Omega-6)

/// Inspector panel showing details of a selected graph node.
/// Slides up from the bottom of the graph view when a node is tapped.
struct NodeDetailPanel: View {
    let node: AgentGraphDataModel.ExecutionGraphNode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Circle()
                    .fill(typeColor)
                    .frame(width: 10, height: 10)
                Text(node.type_.rawValue.capitalized)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(node.id.prefix(8))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }

            Text(node.label)
                .font(.body.bold())

            if !node.metadata.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading),
                ], spacing: 4) {
                    ForEach(Array(node.metadata.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                        Text(key)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(value.prefix(80)))
                            .font(.caption2.monospaced())
                            .lineLimit(2)
                    }
                }
            }

            if let output = node.metadata["output_preview"], !output.isEmpty {
                GroupBox("Output") {
                    ScrollView {
                        Text(output)
                            .font(.caption2.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 80)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var typeColor: Color {
        switch node.type_ {
        case .task: .blue
        case .step: .green
        case .tool: .purple
        case .agent: .orange
        case .result: .cyan
        }
    }
}
