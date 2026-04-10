import Foundation

nonisolated struct GraphData: Codable, Sendable {
    let nodes: [GraphNodeData]
    let edges: [GraphEdgeData]
    let communities: [GraphCommunityData]
}

nonisolated struct GraphNodeData: Codable, Sendable {
    let id: String
    let label: String
    let nodeType: String
    let properties: [String: String]
    let communityId: Int
    let centrality: Double
}

nonisolated struct GraphEdgeData: Codable, Sendable {
    let source: String
    let target: String
    let relation: String
    let confidence: String
    let score: Double
}

nonisolated struct GraphCommunityData: Codable, Sendable {
    let id: Int
    let size: Int
    let topNodes: [String]
}

func decodeGraphData(from data: Data) throws -> GraphData {
    let decoder = JSONDecoder()
    if let legacy = try? decoder.decode(GraphData.self, from: data) {
        return legacy
    }

    let ffiPayload = try decoder.decode(RustSessionGraphPayload.self, from: data)
    return GraphData(rustPayload: ffiPayload)
}

private nonisolated struct RustSessionGraphPayload: Codable, Sendable {
    let nodes: [RustGraphNodePayload]
    let edges: [RustGraphEdgePayload]
}

private nonisolated struct RustGraphNodePayload: Codable, Sendable {
    let id: String
    let label: String
    let nodeType: String
    let properties: [String: String]?
    let communityID: UInt32?

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case nodeType = "node_type"
        case properties
        case communityID = "community_id"
    }
}

private nonisolated struct RustGraphEdgePayload: Codable, Sendable {
    let source: String
    let target: String
    let relation: String
    let confidence: String
    let score: Double
}

private extension GraphData {
    init(rustPayload: RustSessionGraphPayload) {
        let degrees = rustPayload.edges.reduce(into: [String: Double]()) { partialResult, edge in
            partialResult[edge.source, default: 0] += 1
            partialResult[edge.target, default: 0] += 1
        }

        let nodes = rustPayload.nodes.map { node in
            GraphNodeData(
                id: node.id,
                label: node.label,
                nodeType: node.nodeType,
                properties: node.properties ?? [:],
                communityId: Int(node.communityID ?? 0),
                centrality: degrees[node.id, default: 0]
            )
        }

        let explicitCommunityIDs = Set(rustPayload.nodes.compactMap(\.communityID).map(Int.init))
        let communities: [GraphCommunityData]
        if explicitCommunityIDs.isEmpty {
            communities = []
        } else {
            communities = Dictionary(grouping: nodes.filter { explicitCommunityIDs.contains($0.communityId) }, by: \.communityId)
                .map { communityID, groupedNodes in
                    GraphCommunityData(
                        id: communityID,
                        size: groupedNodes.count,
                        topNodes: groupedNodes
                            .sorted { $0.centrality > $1.centrality }
                            .prefix(5)
                            .map(\.label)
                    )
                }
                .sorted { $0.id < $1.id }
        }

        self.init(
            nodes: nodes,
            edges: rustPayload.edges.map { edge in
                GraphEdgeData(
                    source: edge.source,
                    target: edge.target,
                    relation: edge.relation,
                    confidence: edge.confidence.lowercased(),
                    score: edge.score
                )
            },
            communities: communities
        )
    }
}
