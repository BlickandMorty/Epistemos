import Foundation
import SwiftData

// MARK: - EpdocGraphPersistence
//
// W7.14 follow-up: materialise the pure `.epdoc` graph projection into the
// SwiftData graph store. Filesystem package data remains durable; these nodes
// and edges are rebuildable projections.

@MainActor
enum EpdocGraphPersistence {
    static func upsert(
        projection: EpdocGraphProjection,
        context: ModelContext
    ) throws {
        let documentNode = try upsertDocumentNode(projection: projection, context: context)
        try replaceOutgoingProjectionEdges(
            from: documentNode,
            projection: projection,
            context: context
        )
        try context.save()
    }

    private static func upsertDocumentNode(
        projection: EpdocGraphProjection,
        context: ModelContext
    ) throws -> SDGraphNode {
        if let existing = try findNode(sourceID: projection.nodeID, context: context) {
            existing.type = projection.nodeType.rawValue
            existing.label = projection.nodeLabel.isEmpty ? "Untitled" : projection.nodeLabel
            existing.weight = projection.nodeWeight
            existing.updatedAt = .now
            return existing
        }

        let node = SDGraphNode(
            type: projection.nodeType,
            label: projection.nodeLabel.isEmpty ? "Untitled" : projection.nodeLabel,
            sourceId: projection.nodeID,
            weight: projection.nodeWeight
        )
        context.insert(node)
        return node
    }

    private static func replaceOutgoingProjectionEdges(
        from documentNode: SDGraphNode,
        projection: EpdocGraphProjection,
        context: ModelContext
    ) throws {
        let sourceNodeID = documentNode.id
        let projectedEdgeTypes = Set([
            GraphEdgeType.reference.rawValue,
            GraphEdgeType.contains.rawValue,
            GraphEdgeType.derivedFrom.rawValue,
            GraphEdgeType.generatedBy.rawValue,
            GraphEdgeType.producedDuring.rawValue,
            GraphEdgeType.summarizes.rawValue,
        ])
        let staleDescriptor = FetchDescriptor<SDGraphEdge>(
            predicate: #Predicate<SDGraphEdge> { $0.sourceNodeId == sourceNodeID }
        )
        for edge in try context.fetch(staleDescriptor) {
            guard !edge.isManual, projectedEdgeTypes.contains(edge.type) else { continue }
            context.delete(edge)
        }

        var emitted = Set<String>()
        for projectedEdge in projection.edges {
            let targetNodeID = try targetNodeID(for: projectedEdge, context: context)
            let key = "\(targetNodeID)|\(projectedEdge.kind.rawValue)"
            guard emitted.insert(key).inserted else { continue }
            let edge = SDGraphEdge(
                source: documentNode.id,
                target: targetNodeID,
                type: projectedEdge.kind,
                weight: projectedEdge.weight
            )
            context.insert(edge)
        }
    }

    private static func targetNodeID(
        for edge: EpdocGraphProjection.Edge,
        context: ModelContext
    ) throws -> String {
        if edge.targetIsLabel {
            return try findOrCreateLabelNode(label: edge.targetID, context: context).id
        }
        if let bySource = try findNode(sourceID: edge.targetID, context: context) {
            return bySource.id
        }
        if let byID = try findNode(id: edge.targetID, context: context) {
            return byID.id
        }
        return edge.targetID
    }

    private static func findOrCreateLabelNode(
        label: String,
        context: ModelContext
    ) throws -> SDGraphNode {
        var descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate<SDGraphNode> { $0.label == label }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let node = SDGraphNode(type: .idea, label: label, sourceId: nil, weight: 0.4)
        context.insert(node)
        return node
    }

    private static func findNode(
        sourceID: String,
        context: ModelContext
    ) throws -> SDGraphNode? {
        var descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate<SDGraphNode> { $0.sourceId == sourceID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func findNode(
        id: String,
        context: ModelContext
    ) throws -> SDGraphNode? {
        var descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate<SDGraphNode> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
