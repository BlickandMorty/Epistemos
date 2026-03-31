import SwiftUI

// MARK: - Agent Execution Graph View (Omega-6)

/// Visualizes agent execution as an interactive DAG (directed acyclic graph).
///
/// Shows the task → steps → tools → results hierarchy with force-directed layout.
/// Color-coded by node type: task (blue), step (green/red), tool (purple), agent (orange).
/// Uses native SwiftUI Canvas for rendering (no Grape dependency required for basic visualization).
struct AgentGraphView: View {
    let subgraph: AgentGraphDataModel.ExecutionSubgraph

    @State private var selectedNodeId: String?
    @State private var zoomLevel: SemanticZoomLevel = .overview
    @State private var nodePositions: [String: CGPoint] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Execution Graph")
                    .font(.headline)
                Spacer()
                Text("\(subgraph.nodes.count) nodes, \(subgraph.edges.count) edges")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Zoom", selection: $zoomLevel) {
                    ForEach(SemanticZoomLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            // Graph canvas
            GeometryReader { geo in
                Canvas { context, size in
                    let positions = computePositions(size: size)

                    // Draw edges
                    for edge in subgraph.edges {
                        guard let from = positions[edge.source],
                              let to = positions[edge.target] else { continue }
                        var path = Path()
                        path.move(to: from)
                        path.addLine(to: to)
                        context.stroke(
                            path,
                            with: .color(edgeColor(edge.type_).opacity(0.4)),
                            lineWidth: edge.weight * 2
                        )
                    }

                    // Draw nodes
                    for node in filteredNodes {
                        guard let pos = positions[node.id] else { continue }
                        let radius = nodeRadius(node)
                        let isSelected = selectedNodeId == node.id
                        let rect = CGRect(
                            x: pos.x - radius,
                            y: pos.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )

                        // Node circle
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(nodeColor(node.type_))
                        )
                        if isSelected {
                            context.stroke(
                                Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)),
                                with: .color(.white),
                                lineWidth: 2
                            )
                        }

                        // Label
                        if zoomLevel.showsLabels {
                            let text = Text(node.label)
                                .font(.caption2)
                                .foregroundStyle(.primary)
                            context.draw(
                                context.resolve(text),
                                at: CGPoint(x: pos.x, y: pos.y + radius + 8)
                            )
                        }
                    }
                }
                .onTapGesture { location in
                    let positions = computePositions(size: geo.size)
                    selectedNodeId = positions.first { _, pos in
                        hypot(pos.x - location.x, pos.y - location.y) < 20
                    }?.key
                }
            }
            .background(.black.opacity(0.05))

            // Detail panel
            if let nodeId = selectedNodeId,
               let node = subgraph.nodes.first(where: { $0.id == nodeId }) {
                NodeDetailPanel(node: node)
                    .transition(.move(edge: .bottom))
            }
        }
    }

    // MARK: - Layout

    private func computePositions(size: CGSize) -> [String: CGPoint] {
        if !nodePositions.isEmpty { return nodePositions }

        var positions: [String: CGPoint] = [:]
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // Simple hierarchical layout: task at top, steps in middle, tools/results at bottom.
        let taskNodes = subgraph.nodes.filter { $0.type_ == .task }
        let agentNodes = subgraph.nodes.filter { $0.type_ == .agent }
        let stepNodes = subgraph.nodes.filter { $0.type_ == .step }
        let toolNodes = subgraph.nodes.filter { $0.type_ == .tool }
        let resultNodes = subgraph.nodes.filter { $0.type_ == .result }

        layoutRow(taskNodes, y: size.height * 0.1, width: size.width, into: &positions)
        layoutRow(agentNodes, y: size.height * 0.25, width: size.width, into: &positions)
        layoutRow(stepNodes, y: size.height * 0.5, width: size.width, into: &positions)
        layoutRow(toolNodes, y: size.height * 0.75, width: size.width, into: &positions)
        layoutRow(resultNodes, y: size.height * 0.9, width: size.width, into: &positions)

        return positions
    }

    private func layoutRow(
        _ nodes: [AgentGraphDataModel.ExecutionGraphNode],
        y: CGFloat,
        width: CGFloat,
        into positions: inout [String: CGPoint]
    ) {
        guard !nodes.isEmpty else { return }
        let spacing = width / CGFloat(nodes.count + 1)
        for (i, node) in nodes.enumerated() {
            positions[node.id] = CGPoint(x: spacing * CGFloat(i + 1), y: y)
        }
    }

    // MARK: - Filtering by Zoom Level

    private var filteredNodes: [AgentGraphDataModel.ExecutionGraphNode] {
        switch zoomLevel {
        case .overview:
            return subgraph.nodes.filter { $0.type_ == .task || $0.type_ == .agent }
        case .agents:
            return subgraph.nodes.filter { $0.type_ != .result }
        case .steps:
            return subgraph.nodes
        case .tools:
            return subgraph.nodes
        case .detail:
            return subgraph.nodes
        }
    }

    // MARK: - Styling

    private func nodeColor(_ type: AgentGraphDataModel.ExecutionGraphNode.NodeType) -> Color {
        switch type {
        case .task: .blue
        case .step: .green
        case .tool: .purple
        case .agent: .orange
        case .result: .cyan
        }
    }

    private func edgeColor(_ type: AgentGraphDataModel.ExecutionGraphEdge.EdgeType) -> Color {
        switch type {
        case .executedBy: .orange
        case .contains: .blue
        case .usedTool: .purple
        case .dependsOn: .yellow
        case .produced: .cyan
        }
    }

    private func nodeRadius(_ node: AgentGraphDataModel.ExecutionGraphNode) -> CGFloat {
        switch node.type_ {
        case .task: 16
        case .agent: 12
        case .step: 10
        case .tool: 8
        case .result: 6
        }
    }
}
