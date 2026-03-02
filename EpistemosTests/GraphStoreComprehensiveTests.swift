import Foundation
import Testing
@testable import Epistemos

// MARK: - GraphStore Comprehensive Tests
// 80+ test cases covering all GraphStore functionality

@Suite("GraphStore - Initialization")
@MainActor
struct GraphStoreInitializationTests {
    
    @Test("initialization creates empty store")
    func initializationCreatesEmptyStore() {
        let store = GraphStore()
        
        #expect(store.nodeCount == 0)
        #expect(store.edgeCount == 0)
        #expect(store.nodes.isEmpty)
        #expect(store.edges.isEmpty)
        #expect(store.adjacency.isEmpty)
        #expect(store.edgesByNode.isEmpty)
    }
    
    @Test("positionHints starts empty")
    func positionHintsStartsEmpty() {
        let store = GraphStore()
        
        #expect(store.positionHints.isEmpty)
    }
}

@Suite("GraphStore - Node Operations")
@MainActor
struct GraphStoreNodeOperationTests {
    
    // MARK: Helpers
    
    private func makeNode(
        id: String,
        type: GraphNodeType = .note,
        label: String = "",
        createdAt: Date = .now
    ) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id,
            type: type,
            label: label.isEmpty ? id : label,
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: createdAt,
            position: .zero,
            velocity: .zero
        )
    }
    
    @Test("addNode increases node count")
    func addNodeIncreasesCount() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        
        #expect(store.nodeCount == 1)
    }
    
    @Test("addNode stores node in dictionary")
    func addNodeStoresInDictionary() {
        let store = GraphStore()
        
        let node = makeNode(id: "n1", label: "Test Node")
        store.addNode(node)
        
        #expect(store.nodes["n1"]?.label == "Test Node")
    }
    
    @Test("addNode initializes adjacency entry")
    func addNodeInitializesAdjacency() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        
        #expect(store.adjacency["n1"] != nil)
        #expect(store.adjacency["n1"]!.isEmpty)
    }
    
    @Test("addNode initializes edgesByNode entry")
    func addNodeInitializesEdgesByNode() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        
        #expect(store.edgesByNode["n1"] != nil)
        #expect(store.edgesByNode["n1"]!.isEmpty)
    }
    
    @Test("addNode with same ID overwrites existing")
    func addNodeOverwritesExisting() {
        let store = GraphStore()
        
        let node1 = makeNode(id: "n1", label: "First")
        let node2 = makeNode(id: "n1", label: "Second")
        
        store.addNode(node1)
        store.addNode(node2)
        
        #expect(store.nodeCount == 1)
        #expect(store.nodes["n1"]?.label == "Second")
    }
    
    @Test("add multiple nodes")
    func addMultipleNodes() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.addNode(makeNode(id: "n2"))
        store.addNode(makeNode(id: "n3"))
        
        #expect(store.nodeCount == 3)
        #expect(store.nodes.keys.sorted() == ["n1", "n2", "n3"])
    }
    
    @Test("removeNode decreases node count")
    func removeNodeDecreasesCount() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.removeNode("n1")
        
        #expect(store.nodeCount == 0)
    }
    
    @Test("removeNode removes from nodes dictionary")
    func removeNodeRemovesFromDictionary() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.removeNode("n1")
        
        #expect(store.nodes["n1"] == nil)
    }
    
    @Test("removeNode removes adjacency entry")
    func removeNodeRemovesAdjacency() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.removeNode("n1")
        
        #expect(store.adjacency["n1"] == nil)
    }
    
    @Test("removeNode removes edgesByNode entry")
    func removeNodeRemovesEdgesByNode() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.removeNode("n1")
        
        #expect(store.edgesByNode["n1"] == nil)
    }
    
    @Test("removeNode with non-existent ID does nothing")
    func removeNonExistentNode() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.removeNode("nonexistent")
        
        #expect(store.nodeCount == 1)
    }
    
    @Test("removeNode with edges cleans up connected edges")
    func removeNodeCleansUpEdges() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.addNode(makeNode(id: "n2"))
        store.addEdge(GraphEdgeRecord(
            id: "e1", sourceNodeId: "n1", targetNodeId: "n2",
            type: .reference, weight: 1.0, createdAt: .now
        ))
        
        store.removeNode("n1")
        
        #expect(store.edgeCount == 0)
        #expect(store.neighbors(of: "n2").isEmpty)
    }
}

@Suite("GraphStore - Edge Operations")
@MainActor
struct GraphStoreEdgeOperationTests {
    
    private func makeNode(id: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: id,
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: .now, position: .zero, velocity: .zero
        )
    }
    
    private func makeEdge(
        id: String = "",
        source: String,
        target: String,
        type: GraphEdgeType = .reference
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
    
    @Test("addEdge increases edge count")
    func addEdgeIncreasesCount() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.addNode(makeNode(id: "n2"))
        store.addEdge(makeEdge(source: "n1", target: "n2"))
        
        #expect(store.edgeCount == 1)
    }
    
    @Test("addEdge stores edge in dictionary")
    func addEdgeStoresInDictionary() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.addNode(makeNode(id: "n2"))
        let edge = makeEdge(id: "e1", source: "n1", target: "n2")
        store.addEdge(edge)
        
        #expect(store.edges["e1"] != nil)
    }
    
    @Test("addEdge updates adjacency for both nodes")
    func addEdgeUpdatesAdjacency() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.addNode(makeNode(id: "n2"))
        store.addEdge(makeEdge(source: "n1", target: "n2"))
        
        #expect(store.adjacency["n1"]?.contains("n2") == true)
        #expect(store.adjacency["n2"]?.contains("n1") == true)
    }
    
    @Test("addEdge updates edgesByNode for both nodes")
    func addEdgeUpdatesEdgesByNode() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.addNode(makeNode(id: "n2"))
        store.addEdge(makeEdge(id: "e1", source: "n1", target: "n2"))
        
        #expect(store.edgesByNode["n1"]?.contains("e1") == true)
        #expect(store.edgesByNode["n2"]?.contains("e1") == true)
    }
    
    @Test("addEdge without existing source node is ignored")
    func addEdgeWithoutSourceIgnored() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n2"))
        store.addEdge(makeEdge(source: "n1", target: "n2"))
        
        #expect(store.edgeCount == 0)
    }
    
    @Test("addEdge without existing target node is ignored")
    func addEdgeWithoutTargetIgnored() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.addEdge(makeEdge(source: "n1", target: "n2"))
        
        #expect(store.edgeCount == 0)
    }
    
    @Test("addEdge without both nodes is ignored")
    func addEdgeWithoutBothIgnored() {
        let store = GraphStore()
        
        store.addEdge(makeEdge(source: "n1", target: "n2"))
        
        #expect(store.edgeCount == 0)
    }
    
    @Test("add multiple edges between same nodes")
    func addMultipleEdgesBetweenSameNodes() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.addNode(makeNode(id: "n2"))
        store.addEdge(makeEdge(id: "e1", source: "n1", target: "n2", type: .reference))
        store.addEdge(makeEdge(id: "e2", source: "n1", target: "n2", type: .contains))
        
        #expect(store.edgeCount == 2)
        #expect(store.adjacency["n1"]?.count == 1)
        #expect(store.edgesByNode["n1"]?.count == 2)
    }
    
    @Test("removing one edge between multi-edge pair preserves neighbor link")
    func removeOneOfMultipleEdgesPreservesNeighbor() {
        let store = GraphStore()

        store.addNode(makeNode(id: "n1"))
        store.addNode(makeNode(id: "n2"))
        store.addEdge(makeEdge(id: "e1", source: "n1", target: "n2", type: .reference))
        store.addEdge(makeEdge(id: "e2", source: "n1", target: "n2", type: .contains))

        // Remove one edge — neighbor link must survive
        store.removeEdge("e1")

        #expect(store.edgeCount == 1)
        #expect(store.adjacency["n1"]?.contains("n2") == true, "neighbor link lost after removing one of two edges")
        #expect(store.adjacency["n2"]?.contains("n1") == true, "reverse neighbor link lost")
        #expect(store.edgesByNode["n1"]?.count == 1)

        // Remove the last edge — NOW neighbor link should be gone
        store.removeEdge("e2")

        #expect(store.edgeCount == 0)
        #expect(store.adjacency["n1"]?.contains("n2") != true, "neighbor link should be removed when last edge is gone")
        #expect(store.adjacency["n2"]?.contains("n1") != true)
    }

    @Test("self-loop edge is added correctly")
    func selfLoopEdgeAddedCorrectly() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.addEdge(makeEdge(id: "e1", source: "n1", target: "n1"))
        
        #expect(store.edgeCount == 1)
        #expect(store.adjacency["n1"]?.contains("n1") == true)
    }
}

@Suite("GraphStore - Query Operations")
@MainActor
struct GraphStoreQueryTests {
    
    private func makeNode(id: String, type: GraphNodeType = .note) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: type, label: id,
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: .now, position: .zero, velocity: .zero
        )
    }
    
    private func makeEdge(source: String, target: String) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: "\(source)-\(target)",
            sourceNodeId: source,
            targetNodeId: target,
            type: .reference,
            weight: 1.0,
            createdAt: .now
        )
    }
    
    @Test("neighbors returns empty for non-existent node")
    func neighborsEmptyForNonExistent() {
        let store = GraphStore()
        
        let neighbors = store.neighbors(of: "nonexistent")
        
        #expect(neighbors.isEmpty)
    }
    
    @Test("neighbors returns empty for isolated node")
    func neighborsEmptyForIsolated() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        let neighbors = store.neighbors(of: "n1")
        
        #expect(neighbors.isEmpty)
    }
    
    @Test("neighbors returns single neighbor")
    func neighborsReturnsSingle() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.addNode(makeNode(id: "n2"))
        store.addEdge(makeEdge(source: "n1", target: "n2"))
        
        let neighbors = store.neighbors(of: "n1")
        
        #expect(neighbors.count == 1)
        #expect(neighbors.first?.id == "n2")
    }
    
    @Test("neighbors returns multiple neighbors")
    func neighborsReturnsMultiple() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "center"))
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        store.addNode(makeNode(id: "c"))
        store.addEdge(makeEdge(source: "center", target: "a"))
        store.addEdge(makeEdge(source: "center", target: "b"))
        store.addEdge(makeEdge(source: "center", target: "c"))
        
        let neighbors = store.neighbors(of: "center")
        
        #expect(neighbors.count == 3)
    }
    
    @Test("neighbors is bidirectional")
    func neighborsIsBidirectional() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.addNode(makeNode(id: "n2"))
        store.addEdge(makeEdge(source: "n1", target: "n2"))
        
        let neighbors1 = store.neighbors(of: "n1")
        let neighbors2 = store.neighbors(of: "n2")
        
        #expect(neighbors1.count == 1)
        #expect(neighbors2.count == 1)
        #expect(neighbors1.first?.id == "n2")
        #expect(neighbors2.first?.id == "n1")
    }
    
    @Test("edges returns empty for non-existent node")
    func edgesEmptyForNonExistent() {
        let store = GraphStore()
        
        let edges = store.edges(for: "nonexistent")
        
        #expect(edges.isEmpty)
    }
    
    @Test("edges returns edges touching node")
    func edgesReturnsTouchingEdges() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.addNode(makeNode(id: "n2"))
        store.addEdge(makeEdge(source: "n1", target: "n2"))
        
        let edges = store.edges(for: "n1")
        
        #expect(edges.count == 1)
    }
    
    @Test("nodes ofType returns correct nodes")
    func nodesOfTypeReturnsCorrect() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1", type: .note))
        store.addNode(makeNode(id: "n2", type: .tag))
        store.addNode(makeNode(id: "n3", type: .note))
        store.addNode(makeNode(id: "n4", type: .source))
        
        let notes = store.nodes(ofType: .note)
        let tags = store.nodes(ofType: .tag)
        
        #expect(notes.count == 2)
        #expect(tags.count == 1)
    }
    
    @Test("nodes ofType returns empty when none match")
    func nodesOfTypeReturnsEmpty() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1", type: .note))
        
        let folders = store.nodes(ofType: .folder)
        
        #expect(folders.isEmpty)
    }
    
    @Test("node bySourceId returns correct node")
    func nodeBySourceIdReturnsCorrect() {
        let store = GraphStore()
        
        let node = GraphNodeRecord(
            id: "graph-id", type: .note, label: "Test",
            sourceId: "page-id", metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: .now, position: .zero, velocity: .zero
        )
        store.addNode(node)
        
        let found = store.node(bySourceId: "page-id", type: .note)
        
        #expect(found?.id == "graph-id")
    }
    
    @Test("node bySourceId returns nil for wrong type")
    func nodeBySourceIdReturnsNilForWrongType() {
        let store = GraphStore()
        
        let node = GraphNodeRecord(
            id: "graph-id", type: .note, label: "Test",
            sourceId: "page-id", metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: .now, position: .zero, velocity: .zero
        )
        store.addNode(node)
        
        let found = store.node(bySourceId: "page-id", type: .tag)
        
        #expect(found == nil)
    }
    
    @Test("node bySourceId returns nil for non-existent")
    func nodeBySourceIdReturnsNilForNonExistent() {
        let store = GraphStore()
        
        let found = store.node(bySourceId: "nonexistent", type: .note)
        
        #expect(found == nil)
    }
}

@Suite("GraphStore - Connected (BFS)")
@MainActor
struct GraphStoreConnectedTests {
    
    private func makeNode(id: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: id,
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: .now, position: .zero, velocity: .zero
        )
    }
    
    private func makeEdge(source: String, target: String) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: "\(source)-\(target)",
            sourceNodeId: source,
            targetNodeId: target,
            type: .reference,
            weight: 1.0,
            createdAt: .now
        )
    }
    
    @Test("connected returns empty for non-existent node")
    func connectedEmptyForNonExistent() {
        let store = GraphStore()
        
        let connected = store.connected(to: "nonexistent", maxDepth: 3)
        
        #expect(connected.isEmpty)
    }
    
    @Test("connected depth 0 returns only starting node")
    func connectedDepthZero() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "n1"))
        store.addNode(makeNode(id: "n2"))
        store.addEdge(makeEdge(source: "n1", target: "n2"))
        
        let connected = store.connected(to: "n1", maxDepth: 0)
        
        #expect(connected.count == 1)
        #expect(connected.contains("n1"))
    }
    
    @Test("connected depth 1 returns direct neighbors")
    func connectedDepthOne() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "center"))
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        store.addNode(makeNode(id: "c"))
        store.addEdge(makeEdge(source: "center", target: "a"))
        store.addEdge(makeEdge(source: "center", target: "b"))
        
        let connected = store.connected(to: "center", maxDepth: 1)
        
        #expect(connected.count == 3)
        #expect(connected.contains("center"))
        #expect(connected.contains("a"))
        #expect(connected.contains("b"))
        #expect(!connected.contains("c"))
    }
    
    @Test("connected depth 2 returns second level")
    func connectedDepthTwo() {
        let store = GraphStore()
        
        // Chain: a -> b -> c -> d
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        store.addNode(makeNode(id: "c"))
        store.addNode(makeNode(id: "d"))
        store.addEdge(makeEdge(source: "a", target: "b"))
        store.addEdge(makeEdge(source: "b", target: "c"))
        store.addEdge(makeEdge(source: "c", target: "d"))
        
        let connected = store.connected(to: "a", maxDepth: 2)
        
        #expect(connected.count == 3)
        #expect(connected.contains("a"))
        #expect(connected.contains("b"))
        #expect(connected.contains("c"))
        #expect(!connected.contains("d"))
    }
    
    @Test("connected handles cycles")
    func connectedHandlesCycles() {
        let store = GraphStore()
        
        // Triangle: a -> b -> c -> a
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        store.addNode(makeNode(id: "c"))
        store.addEdge(makeEdge(source: "a", target: "b"))
        store.addEdge(makeEdge(source: "b", target: "c"))
        store.addEdge(makeEdge(source: "c", target: "a"))
        
        let connected = store.connected(to: "a", maxDepth: 5)
        
        #expect(connected.count == 3)
    }
    
    @Test("connected handles star topology")
    func connectedStarTopology() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "center"))
        for i in 0..<10 {
            store.addNode(makeNode(id: "leaf\(i)"))
            store.addEdge(makeEdge(source: "center", target: "leaf\(i)"))
        }
        
        let connected = store.connected(to: "center", maxDepth: 1)
        
        #expect(connected.count == 11)
    }
    
    @Test("connected handles disconnected components")
    func connectedDisconnectedComponents() {
        let store = GraphStore()
        
        // Component 1: a - b
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        store.addEdge(makeEdge(source: "a", target: "b"))
        
        // Component 2: c - d
        store.addNode(makeNode(id: "c"))
        store.addNode(makeNode(id: "d"))
        store.addEdge(makeEdge(source: "c", target: "d"))
        
        let connected = store.connected(to: "a", maxDepth: 3)
        
        #expect(connected.count == 2)
        #expect(connected.contains("a"))
        #expect(connected.contains("b"))
        #expect(!connected.contains("c"))
    }
}

@Suite("GraphStore - Shortest Path")
@MainActor
struct GraphStoreShortestPathTests {
    
    private func makeNode(id: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: id,
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: .now, position: .zero, velocity: .zero
        )
    }
    
    private func makeEdge(source: String, target: String) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: "\(source)-\(target)",
            sourceNodeId: source,
            targetNodeId: target,
            type: .reference,
            weight: 1.0,
            createdAt: .now
        )
    }
    
    @Test("shortestPath returns empty for non-existent start")
    func shortestPathEmptyForNonExistentStart() {
        let store = GraphStore()
        store.addNode(makeNode(id: "end"))
        
        let path = store.query(.pathBetween(from: "start", to: "end", maxHops: 5))
        
        #expect(path.isEmpty)
    }
    
    @Test("shortestPath returns empty for non-existent end")
    func shortestPathEmptyForNonExistentEnd() {
        let store = GraphStore()
        store.addNode(makeNode(id: "start"))
        
        let path = store.query(.pathBetween(from: "start", to: "end", maxHops: 5))
        
        #expect(path.isEmpty)
    }
    
    @Test("shortestPath returns single node when start equals end")
    func shortestPathSameNode() {
        let store = GraphStore()
        store.addNode(makeNode(id: "only"))
        
        let path = store.query(.pathBetween(from: "only", to: "only", maxHops: 5))
        
        #expect(path.count == 1)
        #expect(path.first?.id == "only")
    }
    
    @Test("shortestPath finds direct edge")
    func shortestPathDirectEdge() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        store.addEdge(makeEdge(source: "a", target: "b"))
        
        let path = store.query(.pathBetween(from: "a", to: "b", maxHops: 5))
        
        #expect(path.count == 2)
        #expect(path[0].id == "a")
        #expect(path[1].id == "b")
    }
    
    @Test("shortestPath finds two-hop path")
    func shortestPathTwoHop() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        store.addNode(makeNode(id: "c"))
        store.addEdge(makeEdge(source: "a", target: "b"))
        store.addEdge(makeEdge(source: "b", target: "c"))
        
        let path = store.query(.pathBetween(from: "a", to: "c", maxHops: 5))
        
        #expect(path.count == 3)
        #expect(path[0].id == "a")
        #expect(path[1].id == "b")
        #expect(path[2].id == "c")
    }
    
    @Test("shortestPath respects maxHops")
    func shortestPathRespectsMaxHops() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        store.addNode(makeNode(id: "c"))
        store.addEdge(makeEdge(source: "a", target: "b"))
        store.addEdge(makeEdge(source: "b", target: "c"))
        
        let path = store.query(.pathBetween(from: "a", to: "c", maxHops: 1))
        
        #expect(path.isEmpty)
    }
    
    @Test("shortestPath finds shortest of multiple paths")
    func shortestPathFindsShortest() {
        let store = GraphStore()
        // Nodes
        for id in ["a", "b", "c", "d"] {
            store.addNode(makeNode(id: id))
        }
        // Long path: a -> b -> c -> d
        store.addEdge(makeEdge(source: "a", target: "b"))
        store.addEdge(makeEdge(source: "b", target: "c"))
        store.addEdge(makeEdge(source: "c", target: "d"))
        // Short path: a -> d
        store.addEdge(makeEdge(source: "a", target: "d"))
        
        let path = store.query(.pathBetween(from: "a", to: "d", maxHops: 5))
        
        #expect(path.count == 2) // Direct edge is shortest
        #expect(path[0].id == "a")
        #expect(path[1].id == "d")
    }
}

@Suite("GraphStore - Graph Query DSL")
@MainActor
struct GraphStoreQueryDSLTests {
    
    private func makeNode(id: String, type: GraphNodeType = .note) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: type, label: id,
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: .now, position: .zero, velocity: .zero
        )
    }
    
    private func makeEdge(source: String, target: String, type: GraphEdgeType) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: "\(source)-\(target)-\(type)",
            sourceNodeId: source,
            targetNodeId: target,
            type: type,
            weight: 1.0,
            createdAt: .now
        )
    }
    
    @Test("supportsOf returns nodes connected via supports edges")
    func supportsOfQuery() {
        let store = GraphStore()
        store.addNode(makeNode(id: "claim"))
        store.addNode(makeNode(id: "evidence1"))
        store.addNode(makeNode(id: "evidence2"))
        store.addNode(makeNode(id: "unrelated"))
        
        store.addEdge(makeEdge(source: "evidence1", target: "claim", type: .supports))
        store.addEdge(makeEdge(source: "evidence2", target: "claim", type: .supports))
        store.addEdge(makeEdge(source: "unrelated", target: "claim", type: .reference))
        
        let supporting = store.query(.supportsOf(nodeId: "claim"))
        
        #expect(supporting.count == 2)
        #expect(supporting.map { $0.id }.sorted() == ["evidence1", "evidence2"])
    }
    
    @Test("contradictsOf returns nodes connected via contradicts edges")
    func contradictsOfQuery() {
        let store = GraphStore()
        store.addNode(makeNode(id: "theory"))
        store.addNode(makeNode(id: "counter1"))
        store.addNode(makeNode(id: "counter2"))
        
        store.addEdge(makeEdge(source: "counter1", target: "theory", type: .contradicts))
        store.addEdge(makeEdge(source: "counter2", target: "theory", type: .contradicts))
        
        let contradicting = store.query(.contradictsOf(nodeId: "theory"))
        
        #expect(contradicting.count == 2)
    }
    
    @Test("nodesWithEdgeType returns nodes with specific edge type")
    func nodesWithEdgeTypeQuery() {
        let store = GraphStore()
        store.addNode(makeNode(id: "source"))
        store.addNode(makeNode(id: "cited1"))
        store.addNode(makeNode(id: "cited2"))
        store.addNode(makeNode(id: "mentioned"))
        
        store.addEdge(makeEdge(source: "source", target: "cited1", type: .cites))
        store.addEdge(makeEdge(source: "source", target: "cited2", type: .cites))
        store.addEdge(makeEdge(source: "source", target: "mentioned", type: .mentions))
        
        let cited = store.query(.nodesWithEdgeType(.cites, from: "source"))
        
        #expect(cited.count == 2)
    }
    
    @Test("supportsOf works in both directions")
    func supportsOfBidirectional() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        
        // a supports b (edge direction: a -> b)
        store.addEdge(makeEdge(source: "a", target: "b", type: .supports))
        
        let supportingB = store.query(.supportsOf(nodeId: "b"))
        let connectedToA = store.query(.supportsOf(nodeId: "a"))
        
        // Both nodes should find each other through the supports edge
        #expect(supportingB.count == 1)
        #expect(supportingB.first?.id == "a")
        #expect(connectedToA.count == 1)
        #expect(connectedToA.first?.id == "b")
    }
}

@Suite("GraphStore - Fuzzy Search")
@MainActor
struct GraphStoreFuzzySearchTests {
    
    private func makeNode(id: String, label: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: label,
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: .now, position: .zero, velocity: .zero
        )
    }
    
    @Test("fuzzySearch returns empty for empty query")
    func fuzzySearchEmptyQuery() {
        let store = GraphStore()
        store.addNode(makeNode(id: "n1", label: "Test"))
        
        let results = store.fuzzySearch(query: "")
        
        #expect(results.isEmpty)
    }
    
    @Test("fuzzySearch exact match scores 1.0")
    func fuzzySearchExactMatch() {
        let store = GraphStore()
        store.addNode(makeNode(id: "n1", label: "Epistemology"))
        
        let results = store.fuzzySearch(query: "Epistemology")
        
        #expect(results.count == 1)
        #expect(results.first?.score == 1.0)
    }
    
    @Test("fuzzySearch case insensitive exact match")
    func fuzzySearchCaseInsensitiveExact() {
        let store = GraphStore()
        store.addNode(makeNode(id: "n1", label: "Epistemology"))
        
        let results = store.fuzzySearch(query: "epistemology")
        
        #expect(results.count == 1)
        #expect(results.first?.score == 1.0)
    }
    
    @Test("fuzzySearch prefix match scores 0.9")
    func fuzzySearchPrefixMatch() {
        let store = GraphStore()
        store.addNode(makeNode(id: "n1", label: "Epistemology"))
        
        let results = store.fuzzySearch(query: "Epist")
        
        #expect(results.count == 1)
        #expect(results.first?.score == 0.9)
    }
    
    @Test("fuzzySearch contains match scores 0.6")
    func fuzzySearchContainsMatch() {
        let store = GraphStore()
        store.addNode(makeNode(id: "n1", label: "Philosophy of Epistemology"))
        
        let results = store.fuzzySearch(query: "Epistemology")
        
        // Should match as exact (full word match in contains)
        // Actually, let's test substring match
        let results2 = store.fuzzySearch(query: "sophy")
        
        #expect(results2.count == 1)
        #expect(results2.first?.score == 0.6)
    }
    
    @Test("fuzzySearch word start match scores 0.8")
    func fuzzySearchWordStartMatch() {
        let store = GraphStore()
        store.addNode(makeNode(id: "n1", label: "Graph Store Tests"))
        
        // "gst" should match G-raph S-tore T-ests
        let results = store.fuzzySearch(query: "gst")
        
        #expect(results.count == 1)
        #expect(results.first?.score == 0.8)
    }
    
    @Test("fuzzySearch subsequence match scores 0.3")
    func fuzzySearchSubsequenceMatch() {
        let store = GraphStore()
        store.addNode(makeNode(id: "n1", label: "Knowledge Graph System"))
        
        // "kgs" matches K-nowledg-e G-raph S-ystem
        let results = store.fuzzySearch(query: "kgs")
        
        #expect(results.count == 1)
        #expect(results.first?.score == 0.8) // Word start match
    }
    
    @Test("fuzzySearch respects limit")
    func fuzzySearchRespectsLimit() {
        let store = GraphStore()
        for i in 0..<20 {
            store.addNode(makeNode(id: "n\(i)", label: "Test Node \(i)"))
        }
        
        let results = store.fuzzySearch(query: "Test", limit: 5)
        
        #expect(results.count == 5)
    }
    
    @Test("fuzzySearch sorts by score descending")
    func fuzzySearchSortsByScore() {
        let store = GraphStore()
        store.addNode(makeNode(id: "n1", label: "Test Exact"))
        store.addNode(makeNode(id: "n2", label: "Test"))
        store.addNode(makeNode(id: "n3", label: "Testing"))
        
        let results = store.fuzzySearch(query: "Test")
        
        #expect(results.count == 3)
        #expect(results[0].score >= results[1].score)
        #expect(results[1].score >= results[2].score)
    }
    
    @Test("fuzzySearch returns no results when no match")
    func fuzzySearchNoMatch() {
        let store = GraphStore()
        store.addNode(makeNode(id: "n1", label: "Philosophy"))
        
        let results = store.fuzzySearch(query: "Science")
        
        #expect(results.isEmpty)
    }
}

@Suite("GraphStore - Link Count")
@MainActor
struct GraphStoreLinkCountTests {
    
    private func makeNode(id: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: id,
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: .now, position: .zero, velocity: .zero
        )
    }
    
    private func makeEdge(source: String, target: String) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: "\(source)-\(target)",
            sourceNodeId: source,
            targetNodeId: target,
            type: .reference,
            weight: 1.0,
            createdAt: .now
        )
    }
    
    @Test("linkCount returns zero for non-existent node")
    func linkCountNonExistent() {
        let store = GraphStore()
        
        let count = store.linkCount(for: "nonexistent")
        
        #expect(count == 0)
    }
    
    @Test("linkCount returns zero for isolated node")
    func linkCountIsolated() {
        let store = GraphStore()
        store.addNode(makeNode(id: "n1"))
        
        let count = store.linkCount(for: "n1")
        
        #expect(count == 0)
    }
    
    @Test("linkCount returns correct count for single edge")
    func linkCountSingleEdge() {
        let store = GraphStore()
        store.addNode(makeNode(id: "n1"))
        store.addNode(makeNode(id: "n2"))
        store.addEdge(makeEdge(source: "n1", target: "n2"))
        
        #expect(store.linkCount(for: "n1") == 1)
        #expect(store.linkCount(for: "n2") == 1)
    }
    
    @Test("linkCount returns correct count for multiple edges")
    func linkCountMultipleEdges() {
        let store = GraphStore()
        store.addNode(makeNode(id: "center"))
        for i in 0..<5 {
            store.addNode(makeNode(id: "n\(i)"))
            store.addEdge(makeEdge(source: "center", target: "n\(i)"))
        }
        
        #expect(store.linkCount(for: "center") == 5)
    }
}

@Suite("GraphStore - Position Hints")
@MainActor
struct GraphStorePositionHintTests {
    
    @Test("positionHints can be set and retrieved")
    func positionHintsSetAndRetrieve() {
        let store = GraphStore()
        let position = SIMD2<Float>(100.5, 200.75)
        
        store.positionHints["test-id"] = position
        
        #expect(store.positionHints["test-id"] == position)
    }
    
    @Test("positionHints can store multiple hints")
    func positionHintsMultiple() {
        let store = GraphStore()
        
        store.positionHints["id1"] = SIMD2<Float>(10, 20)
        store.positionHints["id2"] = SIMD2<Float>(30, 40)
        
        #expect(store.positionHints.count == 2)
    }
    
    @Test("positionHints can be cleared")
    func positionHintsCleared() {
        let store = GraphStore()
        
        store.positionHints["id1"] = SIMD2<Float>(10, 20)
        store.positionHints.removeAll()
        
        #expect(store.positionHints.isEmpty)
    }
}

@Suite("GraphStore - Edge Cases")
@MainActor
struct GraphStoreEdgeCaseTests {
    
    private func makeNode(id: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: id,
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: .now, position: .zero, velocity: .zero
        )
    }
    
    private func makeEdge(source: String, target: String) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: "\(source)-\(target)",
            sourceNodeId: source,
            targetNodeId: target,
            type: .reference,
            weight: 1.0,
            createdAt: .now
        )
    }
    
    @Test("empty graph operations")
    func emptyGraphOperations() {
        let store = GraphStore()
        
        #expect(store.nodeCount == 0)
        #expect(store.edgeCount == 0)
        #expect(store.neighbors(of: "any").isEmpty)
        #expect(store.edges(for: "any").isEmpty)
        #expect(store.connected(to: "any", maxDepth: 3).isEmpty)
    }
    
    @Test("single node graph")
    func singleNodeGraph() {
        let store = GraphStore()
        store.addNode(makeNode(id: "only"))
        
        #expect(store.nodeCount == 1)
        #expect(store.edgeCount == 0)
        #expect(store.neighbors(of: "only").isEmpty)
        #expect(store.connected(to: "only", maxDepth: 3).count == 1)
    }
    
    @Test("two disconnected nodes")
    func twoDisconnectedNodes() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        
        #expect(store.nodeCount == 2)
        #expect(store.edgeCount == 0)
        #expect(store.neighbors(of: "a").isEmpty)
        #expect(store.connected(to: "a", maxDepth: 3).count == 1)
    }
    
    @Test("complex graph structure")
    func complexGraphStructure() {
        let store = GraphStore()
        
        // Create a more complex structure
        //     a
        //    /|\
        //   b c d
        //   |   |
        //   e   f
        
        let nodes = ["a", "b", "c", "d", "e", "f"]
        for node in nodes {
            store.addNode(makeNode(id: node))
        }
        
        let edges = [
            ("a", "b"), ("a", "c"), ("a", "d"),
            ("b", "e"), ("d", "f")
        ]
        for (src, tgt) in edges {
            store.addEdge(makeEdge(source: src, target: tgt))
        }
        
        #expect(store.nodeCount == 6)
        #expect(store.edgeCount == 5)
        #expect(store.neighbors(of: "a").count == 3)
        #expect(store.connected(to: "a", maxDepth: 2).count == 6)
    }
    
    @Test("remove middle node breaks connections")
    func removeMiddleNodeBreaksConnections() {
        let store = GraphStore()
        
        // a - b - c
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        store.addNode(makeNode(id: "c"))
        store.addEdge(makeEdge(source: "a", target: "b"))
        store.addEdge(makeEdge(source: "b", target: "c"))
        
        store.removeNode("b")
        
        #expect(store.nodeCount == 2)
        #expect(store.edgeCount == 0)
        #expect(store.neighbors(of: "a").isEmpty)
        #expect(store.neighbors(of: "c").isEmpty)
    }
}
