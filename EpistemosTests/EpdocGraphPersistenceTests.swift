import Foundation
import SwiftData
import Testing

@testable import Epistemos

@MainActor
@Suite("EpdocGraphPersistence (Wave 7.14 follow-up)")
struct EpdocGraphPersistenceTests {

    @Test("upsert materializes .epdoc document and wikilink nodes")
    func upsertMaterializesDocumentAndWikilinkNodes() throws {
        let context = try Self.makeContext()
        let projection = EpdocGraphProjection(
            nodeID: "epdoc-doc-1",
            nodeLabel: "Research Packet",
            nodeWeight: 0.73,
            nodeType: .document,
            edges: [
                .init(
                    targetID: "Capability Sandwich",
                    kind: .reference,
                    targetIsLabel: true
                ),
            ]
        )

        try EpdocGraphPersistence.upsert(projection: projection, context: context)

        let doc = try #require(try Self.node(sourceID: "epdoc-doc-1", context: context))
        #expect(doc.nodeType == .document)
        #expect(doc.label == "Research Packet")
        #expect(doc.weight == 0.73)

        let label = try #require(try Self.node(label: "Capability Sandwich", context: context))
        #expect(label.nodeType == .idea)

        let edges = try Self.edges(from: doc.id, context: context)
        #expect(edges.count == 1)
        #expect(edges.first?.targetNodeId == label.id)
        #expect(edges.first?.edgeType == .reference)
    }

    @Test("upsert updates existing document and replaces only generated projection edges")
    func upsertReplacesGeneratedEdgesWithoutDeletingManualEdges() throws {
        let context = try Self.makeContext()
        let first = EpdocGraphProjection(
            nodeID: "epdoc-doc-2",
            nodeLabel: "Draft Title",
            nodeWeight: 0.2,
            nodeType: .document,
            edges: [
                .init(targetID: "Old Link", kind: .reference, targetIsLabel: true),
            ]
        )
        try EpdocGraphPersistence.upsert(projection: first, context: context)
        let doc = try #require(try Self.node(sourceID: "epdoc-doc-2", context: context))
        let manualTarget = SDGraphNode(type: .idea, label: "Manual Anchor")
        context.insert(manualTarget)
        let manualEdge = SDGraphEdge(
            source: doc.id,
            target: manualTarget.id,
            type: .reference
        )
        manualEdge.isManual = true
        context.insert(manualEdge)
        try context.save()

        let second = EpdocGraphProjection(
            nodeID: "epdoc-doc-2",
            nodeLabel: "Final Title",
            nodeWeight: 0.9,
            nodeType: .document,
            edges: [
                .init(targetID: "New Link", kind: .reference, targetIsLabel: true),
            ]
        )
        try EpdocGraphPersistence.upsert(projection: second, context: context)

        let updated = try #require(try Self.node(sourceID: "epdoc-doc-2", context: context))
        let documentNodeCount = try Self.nodes(sourceID: "epdoc-doc-2", context: context).count
        #expect(updated.id == doc.id)
        #expect(updated.label == "Final Title")
        #expect(updated.weight == 0.9)
        #expect(documentNodeCount == 1)

        let outgoing = try Self.edges(from: updated.id, context: context)
        let oldLink = try Self.node(label: "Old Link", context: context)
        let newLink = try Self.node(label: "New Link", context: context)
        #expect(outgoing.count == 2)
        #expect(outgoing.contains { $0.isManual && $0.targetNodeId == manualTarget.id })
        #expect(!outgoing.contains { $0.targetNodeId == oldLink?.id })
        #expect(outgoing.contains { $0.targetNodeId == newLink?.id })
    }

    @Test("upsert deduplicates repeated projection edges")
    func upsertDeduplicatesRepeatedProjectionEdges() throws {
        let context = try Self.makeContext()
        let projection = EpdocGraphProjection(
            nodeID: "epdoc-doc-3",
            nodeLabel: "Duplicate Links",
            nodeWeight: 0.5,
            nodeType: .document,
            edges: [
                .init(targetID: "Same Target", kind: .reference, targetIsLabel: true),
                .init(targetID: "Same Target", kind: .reference, targetIsLabel: true),
            ]
        )

        try EpdocGraphPersistence.upsert(projection: projection, context: context)

        let doc = try #require(try Self.node(sourceID: "epdoc-doc-3", context: context))
        let edgeCount = try Self.edges(from: doc.id, context: context).count
        #expect(edgeCount == 1)
    }

    private static func makeContext() throws -> ModelContext {
        let schema = Schema([SDGraphNode.self, SDGraphEdge.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private static func node(sourceID: String, context: ModelContext) throws -> SDGraphNode? {
        try nodes(sourceID: sourceID, context: context).first
    }

    private static func nodes(sourceID: String, context: ModelContext) throws -> [SDGraphNode] {
        let descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate<SDGraphNode> { $0.sourceId == sourceID }
        )
        return try context.fetch(descriptor)
    }

    private static func node(label: String, context: ModelContext) throws -> SDGraphNode? {
        var descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate<SDGraphNode> { $0.label == label }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func edges(from sourceID: String, context: ModelContext) throws -> [SDGraphEdge] {
        let descriptor = FetchDescriptor<SDGraphEdge>(
            predicate: #Predicate<SDGraphEdge> { $0.sourceNodeId == sourceID }
        )
        return try context.fetch(descriptor)
    }
}
