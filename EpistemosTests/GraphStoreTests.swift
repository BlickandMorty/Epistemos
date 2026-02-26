import Testing
@testable import Epistemos

@Suite("GraphStore")
@MainActor
struct GraphStoreTests {

    // MARK: - Helpers

    /// Create a minimal node record for testing.
    private func makeNode(
        id: String,
        type: GraphNodeType = .note,
        label: String = ""
    ) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id,
            type: type,
            label: label.isEmpty ? id : label,
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        )
    }

    /// Create a minimal edge record for testing.
    private func makeEdge(
        id: String = "",
        source: String,
        target: String,
        type: GraphEdgeType = .wikilink
    ) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: id.isEmpty ? "\(source)-\(target)" : id,
            sourceNodeId: source,
            targetNodeId: target,
            type: type,
            weight: 1.0,
            createdAt: .now
        )
    }

    // MARK: - Tests

    @Test("add and query nodes")
    func addAndQueryNodes() {
        let store = GraphStore()

        let noteNode = makeNode(id: "n1", type: .note, label: "My Note")
        let conceptNode = makeNode(id: "n2", type: .concept, label: "Epistemology")

        store.addNode(noteNode)
        store.addNode(conceptNode)

        #expect(store.nodeCount == 2)
        #expect(store.edgeCount == 0)

        let notes = store.nodes(ofType: .note)
        #expect(notes.count == 1)
        #expect(notes.first?.label == "My Note")

        let concepts = store.nodes(ofType: .concept)
        #expect(concepts.count == 1)
        #expect(concepts.first?.id == "n2")
    }

    @Test("add edges and query neighbors")
    func addEdgesAndQueryNeighbors() {
        let store = GraphStore()

        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))

        let edge = makeEdge(source: "a", target: "b")
        store.addEdge(edge)

        #expect(store.edgeCount == 1)

        // Bidirectional neighbors
        let neighborsOfA = store.neighbors(of: "a")
        #expect(neighborsOfA.count == 1)
        #expect(neighborsOfA.first?.id == "b")

        let neighborsOfB = store.neighbors(of: "b")
        #expect(neighborsOfB.count == 1)
        #expect(neighborsOfB.first?.id == "a")

        // Edge queries
        let edgesForA = store.edges(for: "a")
        #expect(edgesForA.count == 1)
        #expect(edgesForA.first?.id == edge.id)

        let edgesForB = store.edges(for: "b")
        #expect(edgesForB.count == 1)
    }

    @Test("BFS connected traversal")
    func bfsConnectedTraversal() {
        let store = GraphStore()

        // Chain: a -> b -> c -> d
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        store.addNode(makeNode(id: "c"))
        store.addNode(makeNode(id: "d"))

        store.addEdge(makeEdge(source: "a", target: "b"))
        store.addEdge(makeEdge(source: "b", target: "c"))
        store.addEdge(makeEdge(source: "c", target: "d"))

        // Depth 1: a and its direct neighbor b
        let depth1 = store.connected(to: "a", maxDepth: 1)
        #expect(depth1.contains("a"))
        #expect(depth1.contains("b"))
        #expect(!depth1.contains("c"))
        #expect(!depth1.contains("d"))
        #expect(depth1.count == 2)

        // Depth 2: a, b, c
        let depth2 = store.connected(to: "a", maxDepth: 2)
        #expect(depth2.count == 3)
        #expect(depth2.contains("c"))
        #expect(!depth2.contains("d"))

        // Depth 3: all nodes
        let depth3 = store.connected(to: "a", maxDepth: 3)
        #expect(depth3.count == 4)
        #expect(depth3.contains("d"))
    }

    @Test("remove node cleans up edges and adjacency")
    func removeNodeCleansUp() {
        let store = GraphStore()

        store.addNode(makeNode(id: "x"))
        store.addNode(makeNode(id: "y"))

        store.addEdge(makeEdge(source: "x", target: "y"))

        #expect(store.nodeCount == 2)
        #expect(store.edgeCount == 1)
        #expect(store.neighbors(of: "y").count == 1)

        // Remove x
        store.removeNode("x")

        #expect(store.nodeCount == 1)
        #expect(store.edgeCount == 0)

        // y should have no neighbors or edges
        #expect(store.neighbors(of: "y").isEmpty)
        #expect(store.edges(for: "y").isEmpty)

        // Adjacency for y should be empty
        #expect(store.adjacency["y"]?.isEmpty ?? true)
        #expect(store.edgesByNode["y"]?.isEmpty ?? true)

        // x should be fully gone
        #expect(store.nodes["x"] == nil)
        #expect(store.adjacency["x"] == nil)
        #expect(store.edgesByNode["x"] == nil)
    }
}
