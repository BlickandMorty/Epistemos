import Foundation
import Testing
@testable import Epistemos

@Suite("GraphState Semantic Backlinks", .serialized)
@MainActor
struct GraphStateSemanticBacklinksTests {
    private func makeNode(
        id: String,
        type: GraphNodeType = .note,
        sourceId: String?,
        label: String
    ) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id,
            type: type,
            label: label,
            sourceId: sourceId,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now
        )
    }

    private func makeEdge(
        id: String,
        source: String,
        target: String,
        type: GraphEdgeType
    ) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: id,
            sourceNodeId: source,
            targetNodeId: target,
            type: type,
            weight: 1.0,
            createdAt: .now
        )
    }

    @Test("incomingEdges returns semantic backlinks for note-backed pages")
    func incomingEdgesReturnsSemanticBacklinks() async {
        let state = GraphState()
        state.store.addNode(makeNode(id: "target", sourceId: "page-target", label: "Target"))
        state.store.addNode(makeNode(id: "supporting", sourceId: "page-support", label: "Supporting Note"))
        state.store.addNode(makeNode(id: "contradicting", sourceId: "page-contradict", label: "Contradicting Note"))
        state.store.addNode(makeNode(id: "reference", sourceId: "page-reference", label: "Reference Note"))
        state.store.addNode(makeNode(id: "tag-node", type: .tag, sourceId: nil, label: "Detached Tag"))

        state.store.addEdge(makeEdge(id: "supports", source: "supporting", target: "target", type: .supports))
        state.store.addEdge(makeEdge(id: "contradicts", source: "contradicting", target: "target", type: .contradicts))
        state.store.addEdge(makeEdge(id: "reference-edge", source: "reference", target: "target", type: .reference))
        state.store.addEdge(makeEdge(id: "tag-edge", source: "tag-node", target: "target", type: .questions))

        let results = await state.incomingEdges(forPageId: "page-target")

        #expect(results.count == 2)
        #expect(results.map(\.sourcePageId) == ["page-contradict", "page-support"])
        #expect(results.map(\.sourceTitle) == ["Contradicting Note", "Supporting Note"])
        #expect(results.map(\.edgeType) == ["contradicts", "supports"])
    }

    @Test("incomingEdges ignores pages without graph nodes")
    func incomingEdgesIgnoresUnknownPages() async {
        let state = GraphState()
        state.store.addNode(makeNode(id: "other", sourceId: "page-other", label: "Other"))

        let results = await state.incomingEdges(forPageId: "missing-page")

        #expect(results.isEmpty)
    }
}
