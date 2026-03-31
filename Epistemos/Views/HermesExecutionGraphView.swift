import SwiftUI

// MARK: - Hermes Execution Graph View

/// Visualizes the current Hermes agent execution as an interactive DAG.
/// Built from real RenderedBlock data flowing through the Hermes bridge —
/// each tool call, thinking block, and response becomes a graph node.
struct HermesExecutionGraphView: View {
    let viewModel: AgentViewModel

    @State private var selectedNodeId: String?
    @State private var zoomLevel: GraphZoomLevel = .steps

    private var subgraph: HermesExecutionSubgraph {
        HermesExecutionSubgraph.from(blocks: viewModel.contentBlocks)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if subgraph.nodes.isEmpty {
                emptyState
            } else {
                graphCanvas
                if let nodeId = selectedNodeId,
                   let node = subgraph.nodes.first(where: { $0.id == nodeId }) {
                    Divider()
                    nodeDetail(node)
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .foregroundStyle(.blue)
            Text("Execution Graph")
                .font(.headline)
            Spacer()
            Text("\(subgraph.nodes.count) nodes")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Zoom", selection: $zoomLevel) {
                ForEach(GraphZoomLevel.allCases, id: \.self) { level in
                    Text(level.label).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Execution Data", systemImage: "point.3.connected.trianglepath.dotted")
        } description: {
            Text("Send a message to Hermes to see the execution graph.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Graph Canvas

    private var graphCanvas: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let positions = computePositions(size: size)
                let visibleNodes = filteredNodes

                // Draw edges
                for edge in subgraph.edges {
                    guard let from = positions[edge.source],
                          let to = positions[edge.target] else { continue }
                    // Only draw edges where both nodes are visible
                    guard visibleNodes.contains(where: { $0.id == edge.source }),
                          visibleNodes.contains(where: { $0.id == edge.target }) else { continue }

                    var path = Path()
                    path.move(to: from)
                    path.addLine(to: to)
                    context.stroke(
                        path,
                        with: .color(edge.color.opacity(0.4)),
                        lineWidth: 1.5
                    )
                }

                // Draw nodes
                for node in visibleNodes {
                    guard let pos = positions[node.id] else { continue }
                    let radius = node.radius
                    let isSelected = selectedNodeId == node.id
                    let rect = CGRect(
                        x: pos.x - radius,
                        y: pos.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(node.color)
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
                selectedNodeId = filteredNodes.first { node in
                    guard let pos = positions[node.id] else { return false }
                    return hypot(pos.x - location.x, pos.y - location.y) < 20
                }?.id
            }
        }
        .background(.black.opacity(0.03))
    }

    // MARK: - Node Detail

    private func nodeDetail(_ node: HermesGraphNode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(node.color)
                    .frame(width: 10, height: 10)
                Text(node.label)
                    .font(.subheadline.bold())
                Spacer()
                Text(node.type.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                Button {
                    selectedNodeId = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            if !node.detail.isEmpty {
                Text(node.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .transition(.move(edge: .bottom))
    }

    // MARK: - Layout

    private func computePositions(size: CGSize) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]

        let promptNodes = subgraph.nodes.filter { $0.type == .prompt }
        let thinkingNodes = subgraph.nodes.filter { $0.type == .thinking }
        let toolNodes = subgraph.nodes.filter { $0.type == .tool }
        let responseNodes = subgraph.nodes.filter { $0.type == .response }

        layoutRow(promptNodes, y: size.height * 0.1, width: size.width, into: &positions)
        layoutRow(thinkingNodes, y: size.height * 0.3, width: size.width, into: &positions)
        layoutRow(toolNodes, y: size.height * 0.6, width: size.width, into: &positions)
        layoutRow(responseNodes, y: size.height * 0.85, width: size.width, into: &positions)

        return positions
    }

    private func layoutRow(
        _ nodes: [HermesGraphNode],
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

    // MARK: - Filtering

    private var filteredNodes: [HermesGraphNode] {
        switch zoomLevel {
        case .overview:
            return subgraph.nodes.filter { $0.type == .prompt || $0.type == .response }
        case .steps:
            return subgraph.nodes
        case .detail:
            return subgraph.nodes
        }
    }
}

// MARK: - Zoom Levels

enum GraphZoomLevel: String, CaseIterable {
    case overview
    case steps
    case detail

    var label: String {
        switch self {
        case .overview: "Overview"
        case .steps: "Steps"
        case .detail: "Detail"
        }
    }

    var showsLabels: Bool {
        self != .overview
    }
}

// MARK: - Graph Data Model (from Hermes RenderedBlocks)

struct HermesGraphNode: Identifiable, Sendable {
    let id: String
    let label: String
    let type: NodeType
    let detail: String

    enum NodeType: String, Sendable {
        case prompt
        case thinking
        case tool
        case response
        case status
    }

    var color: Color {
        switch type {
        case .prompt: .blue
        case .thinking: .orange
        case .tool: .purple
        case .response: .green
        case .status: .gray
        }
    }

    var radius: CGFloat {
        switch type {
        case .prompt: 14
        case .thinking: 10
        case .tool: 12
        case .response: 14
        case .status: 6
        }
    }
}

struct HermesGraphEdge: Sendable {
    let source: String
    let target: String
    let type: EdgeType

    enum EdgeType: Sendable {
        case flow       // sequential execution
        case toolCall   // thinking → tool
        case toolResult // tool → response
    }

    var color: Color {
        switch type {
        case .flow: .gray
        case .toolCall: .purple
        case .toolResult: .cyan
        }
    }
}

struct HermesExecutionSubgraph: Sendable {
    let nodes: [HermesGraphNode]
    let edges: [HermesGraphEdge]

    /// Build graph from AgentViewModel's content blocks.
    static func from(blocks: [RenderedBlock]) -> HermesExecutionSubgraph {
        var nodes: [HermesGraphNode] = []
        var edges: [HermesGraphEdge] = []
        var lastNodeId: String?

        for (index, block) in blocks.enumerated() {
            let nodeId = "node-\(index)"
            var node: HermesGraphNode?

            switch block {
            case .userPrompt(let text):
                node = HermesGraphNode(
                    id: nodeId,
                    label: String(text.prefix(40)),
                    type: .prompt,
                    detail: text
                )
            case .thinking(let text, let tokenCount):
                node = HermesGraphNode(
                    id: nodeId,
                    label: "Thinking (\(tokenCount) tokens)",
                    type: .thinking,
                    detail: String(text.prefix(200))
                )
            case .text(let text):
                node = HermesGraphNode(
                    id: nodeId,
                    label: String(text.prefix(40)),
                    type: .response,
                    detail: text
                )
            case .toolExecution(let name, let input, let result, let isError):
                node = HermesGraphNode(
                    id: nodeId,
                    label: name + (isError ? " (error)" : ""),
                    type: .tool,
                    detail: "Input: \(String(input.prefix(100)))\nResult: \(String((result ?? "").prefix(100)))"
                )
            case .status(let text):
                node = HermesGraphNode(
                    id: nodeId,
                    label: text,
                    type: .status,
                    detail: text
                )
            }

            if let node {
                nodes.append(node)

                // Connect sequential nodes
                if let prevId = lastNodeId {
                    let edgeType: HermesGraphEdge.EdgeType
                    switch node.type {
                    case .tool: edgeType = .toolCall
                    case .response: edgeType = .toolResult
                    default: edgeType = .flow
                    }
                    edges.append(HermesGraphEdge(
                        source: prevId,
                        target: nodeId,
                        type: edgeType
                    ))
                }
                lastNodeId = nodeId
            }
        }

        return HermesExecutionSubgraph(nodes: nodes, edges: edges)
    }
}
