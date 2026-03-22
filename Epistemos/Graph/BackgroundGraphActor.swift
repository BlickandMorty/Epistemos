import Foundation
import SwiftData

// MARK: - BackgroundGraphActor
// @ModelActor for loading graph data on a background thread.
// In Swift 6, @Model types are @MainActor-isolated. @ModelActor provides
// its own ModelContext and executor, allowing safe @Model access off-main.
// Pattern: fetch SDGraphNode/SDGraphEdge → convert to Sendable records → return.

@ModelActor
actor BackgroundGraphActor {

    /// Fetch all graph nodes and edges from SwiftData and convert to Sendable records.
    /// Runs on a background executor — does not block the main thread.
    func loadRecords(
        positionHints: [String: SIMD2<Float>]
    ) throws -> (nodes: [GraphNodeRecord], edges: [GraphEdgeRecord]) {
        let sdNodes = try modelContext.fetch(FetchDescriptor<SDGraphNode>())
            .filter { !GraphStore.hiddenNodeTypes.contains($0.nodeType) }
        let sdEdges = try modelContext.fetch(FetchDescriptor<SDGraphEdge>())
        let visibleNodeIds = Set(sdNodes.map(\.id))

        var hints = positionHints
        let golden = Float.pi * (3.0 - sqrt(5.0))

        let nodeRecords = sdNodes.enumerated().map { index, sdNode -> GraphNodeRecord in
            let position: SIMD2<Float> = hints.removeValue(forKey: sdNode.id)
                ?? {
                    let r: Float = 250.0 * sqrt(Float(index))
                    let theta = Float(index) * golden
                    return SIMD2<Float>(r * cos(theta), r * sin(theta))
                }()

            return GraphNodeRecord(
                id: sdNode.id,
                type: sdNode.nodeType,
                label: sdNode.label,
                sourceId: sdNode.sourceId,
                metadata: sdNode.meta,
                weight: sdNode.weight,
                createdAt: sdNode.createdAt,
                updatedAt: sdNode.updatedAt,
                position: position,
                velocity: .zero
            )
        }

        let edgeRecords = sdEdges.compactMap { sdEdge -> GraphEdgeRecord? in
            guard sdEdge.edgeType != .quotes,
                  visibleNodeIds.contains(sdEdge.sourceNodeId),
                  visibleNodeIds.contains(sdEdge.targetNodeId)
            else {
                return nil
            }

            return GraphEdgeRecord(
                id: sdEdge.id,
                sourceNodeId: sdEdge.sourceNodeId,
                targetNodeId: sdEdge.targetNodeId,
                type: sdEdge.edgeType,
                weight: sdEdge.weight,
                createdAt: sdEdge.createdAt
            )
        }

        return (nodeRecords, edgeRecords)
    }

    /// Run the full structural graph rebuild off main actor:
    /// build + persist + convert to Sendable records.
    /// GraphBuilder is @unchecked Sendable — safe when called from the actor that owns the context.
    func rebuildStructural(
        positionHints: [String: SIMD2<Float>]
    ) throws -> (nodes: [GraphNodeRecord], edges: [GraphEdgeRecord]) {
        let builder = GraphBuilder()
        let result = builder.build(context: modelContext)
        builder.persist(nodes: result.nodes, edges: result.edges, context: modelContext)
        return try loadRecords(positionHints: positionHints)
    }
}
