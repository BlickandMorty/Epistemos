import Testing
@testable import Epistemos

@Suite("Graph Data Models")
struct GraphModelTests {

    @Test("GraphNodeType has exactly 7 cases")
    func nodeTypeCaseCount() {
        #expect(GraphNodeType.allCases.count == 7)
    }

    @Test("All GraphNodeType cases have non-empty icon and displayName")
    func nodeTypeProperties() {
        for nodeType in GraphNodeType.allCases {
            #expect(!nodeType.icon.isEmpty, "icon should not be empty for \(nodeType)")
            #expect(!nodeType.displayName.isEmpty, "displayName should not be empty for \(nodeType)")
        }
    }

    @Test("SDGraphNode stores and retrieves metadata via JSON cache")
    func nodeMetadataRoundTrip() {
        let node = SDGraphNode(type: .source, label: "Test Paper")
        var meta = GraphNodeMetadata()
        meta.authors = ["Alice", "Bob"]
        meta.year = 2026
        meta.doi = "10.1234/test"
        meta.evidenceGrade = "A"
        node.meta = meta

        // Read back — should come from cache
        let retrieved = node.meta
        #expect(retrieved.authors == ["Alice", "Bob"])
        #expect(retrieved.year == 2026)
        #expect(retrieved.doi == "10.1234/test")
        #expect(retrieved.evidenceGrade == "A")

        // Verify underlying Data is non-nil (JSON was encoded)
        #expect(node.metadata != nil)
    }

    @Test("SDGraphNode defaults are correct")
    func nodeDefaults() {
        let node = SDGraphNode(type: .tag, label: "Epistemology")
        #expect(node.nodeType == .tag)
        #expect(node.label == "Epistemology")
        #expect(node.weight == 1.0)
        #expect(node.sourceId == nil)
        #expect(node.metadata == nil)
        #expect(!node.id.isEmpty)
    }

    @Test("SDGraphEdge stores relationship correctly")
    func edgeRelationship() {
        let edge = SDGraphEdge(
            source: "node-a",
            target: "node-b",
            type: .related,
            weight: 0.85
        )
        #expect(edge.sourceNodeId == "node-a")
        #expect(edge.targetNodeId == "node-b")
        #expect(edge.edgeType == .related)
        #expect(edge.weight == 0.85)
        #expect(!edge.id.isEmpty)
    }
}
