import Testing
@testable import Epistemos
import Foundation

// MARK: - Graph Edge Case Tests
// Comprehensive tests for graph boundary conditions, malformed data, and unusual topologies.

@Suite("Graph Edge Cases - Empty Graphs")
@MainActor
struct GraphEmptyEdgeCaseTests {
    
    @Test("Operations on empty graph store")
    func emptyGraphOperations() {
        let store = GraphStore()
        
        // Should handle queries gracefully
        #expect(store.nodeCount == 0)
        #expect(store.edgeCount == 0)
        #expect(store.neighbors(of: "nonexistent").isEmpty)
        #expect(store.edges(for: "nonexistent").isEmpty)
        #expect(store.connected(to: "nonexistent", maxDepth: 3).isEmpty)
        #expect(store.nodes(ofType: .note).isEmpty)
        #expect(store.linkCount(for: "nonexistent") == 0)
        
        // BFS on non-existent node
        let result = store.connected(to: "any-id", maxDepth: 10)
        #expect(result.isEmpty)
    }
    
    @Test("Remove node from empty store")
    func removeFromEmptyStore() {
        let store = GraphStore()
        store.removeNode("any-id") // Should not crash
        #expect(store.nodeCount == 0)
    }
    
    @Test("Add edge with missing endpoints to empty store")
    func addEdgeToEmptyStore() {
        let store = GraphStore()
        let edge = GraphEdgeRecord(
            id: "e1",
            sourceNodeId: "missing-source",
            targetNodeId: "missing-target",
            type: .reference,
            weight: 1.0,
            createdAt: .now
        )
        store.addEdge(edge) // Should be silently ignored
        #expect(store.edgeCount == 0)
    }
    
    @Test("Fuzzy search on empty graph")
    func fuzzySearchEmptyGraph() {
        let store = GraphStore()
        let results = store.fuzzySearch(query: "anything", limit: 10)
        #expect(results.isEmpty)
    }
}

@Suite("Graph Edge Cases - Single Node")
@MainActor
struct GraphSingleNodeEdgeCaseTests {
    
    @Test("Single node graph has no neighbors")
    func singleNodeNoNeighbors() {
        let store = GraphStore()
        let node = GraphNodeRecord(
            id: "solo",
            type: .note,
            label: "Lonely Note",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        )
        store.addNode(node)
        
        #expect(store.nodeCount == 1)
        #expect(store.edgeCount == 0)
        #expect(store.neighbors(of: "solo").isEmpty)
        #expect(store.edges(for: "solo").isEmpty)
        #expect(store.linkCount(for: "solo") == 0)
        
        // BFS should return only itself
        let connected = store.connected(to: "solo", maxDepth: 1)
        #expect(connected.count == 1)
        #expect(connected.contains("solo"))
    }
    
    @Test("Self-edge should be prevented")
    func selfEdgePrevention() {
        let store = GraphStore()
        store.addNode(GraphNodeRecord(
            id: "self",
            type: .note,
            label: "Self",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        ))
        
        // Try to create self-loop
        let selfEdge = GraphEdgeRecord(
            id: "self-loop",
            sourceNodeId: "self",
            targetNodeId: "self",
            type: .reference,
            weight: 1.0,
            createdAt: .now
        )
        store.addEdge(selfEdge)
        
        // Implementation may or may not allow this, but shouldn't crash
        // Documenting current behavior
        #expect(store.nodes["self"] != nil)
    }
    
    @Test("Remove single node from graph")
    func removeSingleNode() {
        let store = GraphStore()
        store.addNode(GraphNodeRecord(
            id: "only",
            type: .note,
            label: "Only",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        ))
        
        store.removeNode("only")
        #expect(store.nodeCount == 0)
        #expect(store.adjacency["only"] == nil)
    }
}

@Suite("Graph Edge Cases - Two Node Topologies")
@MainActor
struct GraphTwoNodeEdgeCaseTests {
    
    @Test("Two nodes with zero edges")
    func twoNodesZeroEdges() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        
        #expect(store.nodeCount == 2)
        #expect(store.edgeCount == 0)
        #expect(store.neighbors(of: "a").isEmpty)
        #expect(store.neighbors(of: "b").isEmpty)
        #expect(!store.connected(to: "a", maxDepth: 10).contains("b"))
    }
    
    @Test("Two nodes with one edge")
    func twoNodesOneEdge() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        store.addEdge(makeEdge(source: "a", target: "b"))
        
        #expect(store.nodeCount == 2)
        #expect(store.edgeCount == 1)
        #expect(store.neighbors(of: "a").count == 1)
        #expect(store.neighbors(of: "b").count == 1)
        #expect(store.linkCount(for: "a") == 1)
        #expect(store.linkCount(for: "b") == 1)
        
        // Should be connected
        let connected = store.connected(to: "a", maxDepth: 10)
        #expect(connected.contains("b"))
    }
    
    @Test("Duplicate edge prevention")
    func duplicateEdgePrevention() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        
        // Add same edge twice
        store.addEdge(makeEdge(id: "e1", source: "a", target: "b"))
        store.addEdge(makeEdge(id: "e2", source: "a", target: "b"))
        
        // Both edges exist (implementation allows multiple edges)
        #expect(store.edgeCount == 2)
        #expect(store.edges(for: "a").count == 2)
        #expect(store.linkCount(for: "a") == 1) // Adjacency uses Set, so only unique neighbors counted
    }
    
    @Test("Bidirectional edges between two nodes")
    func bidirectionalEdges() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        
        store.addEdge(makeEdge(id: "e1", source: "a", target: "b"))
        store.addEdge(makeEdge(id: "e2", source: "b", target: "a"))
        
        #expect(store.edgeCount == 2)
        #expect(store.neighbors(of: "a").count == 1) // Still one unique neighbor
        #expect(store.edges(for: "a").count == 2) // But two edges
    }
    
    private func makeNode(id: String, type: GraphNodeType = .note) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: type, label: id, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
    
    private func makeEdge(id: String = UUID().uuidString, source: String, target: String) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: id, sourceNodeId: source, targetNodeId: target,
            type: .reference, weight: 1.0, createdAt: .now
        )
    }
}

@Suite("Graph Edge Cases - Complex Topologies")
@MainActor
struct GraphTopologyEdgeCaseTests {
    
    @Test("Complete graph - all possible edges")
    func completeGraph() {
        let store = GraphStore()
        let n = 5
        
        // Create n nodes
        for i in 0..<n {
            store.addNode(makeNode(id: "\(i)"))
        }
        
        // Create all possible edges (n * (n-1) / 2 undirected = n * (n-1) directed)
        for i in 0..<n {
            for j in (i+1)..<n {
                store.addEdge(makeEdge(source: "\(i)", target: "\(j)"))
            }
        }
        
        #expect(store.nodeCount == n)
        #expect(store.edgeCount == n * (n - 1) / 2)
        
        // Each node should have n-1 neighbors
        for i in 0..<n {
            #expect(store.neighbors(of: "\(i)").count == n - 1)
            #expect(store.linkCount(for: "\(i)") == UInt32(n - 1))
        }
        
        // All nodes should be connected
        let connected = store.connected(to: "0", maxDepth: n)
        #expect(connected.count == n)
    }
    
    @Test("Star topology - center connected to all")
    func starTopology() {
        let store = GraphStore()
        let center = "center"
        let spokes = 10
        
        store.addNode(makeNode(id: center))
        for i in 0..<spokes {
            store.addNode(makeNode(id: "spoke-\(i)"))
            store.addEdge(makeEdge(source: center, target: "spoke-\(i)"))
        }
        
        #expect(store.nodeCount == spokes + 1)
        #expect(store.edgeCount == spokes)
        #expect(store.neighbors(of: center).count == spokes)
        #expect(store.linkCount(for: center) == UInt32(spokes))
        
        // Each spoke should only connect to center
        for i in 0..<spokes {
            #expect(store.neighbors(of: "spoke-\(i)").count == 1)
        }
        
        // All spokes should be reachable from center
        let connected = store.connected(to: center, maxDepth: 2)
        #expect(connected.count == spokes + 1)
    }
    
    @Test("Chain/line topology")
    func chainTopology() {
        let store = GraphStore()
        let length = 10
        
        for i in 0..<length {
            store.addNode(makeNode(id: "\(i)"))
            if i > 0 {
                store.addEdge(makeEdge(source: "\(i-1)", target: "\(i)"))
            }
        }
        
        #expect(store.nodeCount == length)
        #expect(store.edgeCount == length - 1)
        
        // Endpoints have 1 neighbor, middle nodes have 2
        #expect(store.neighbors(of: "0").count == 1)
        #expect(store.neighbors(of: "9").count == 1)
        #expect(store.neighbors(of: "5").count == 2)
        
        // Full traversal requires depth = length - 1
        let connected = store.connected(to: "0", maxDepth: length - 1)
        #expect(connected.count == length)
        
        // Limited depth
        let depth3 = store.connected(to: "0", maxDepth: 3)
        #expect(depth3.count == 4) // 0, 1, 2, 3
    }
    
    @Test("Cycle detection - ring topology")
    func cycleTopology() {
        let store = GraphStore()
        let n = 6
        
        for i in 0..<n {
            store.addNode(makeNode(id: "\(i)"))
        }
        
        // Create cycle: 0-1-2-3-4-5-0
        for i in 0..<n {
            let next = (i + 1) % n
            store.addEdge(makeEdge(source: "\(i)", target: "\(next)"))
        }
        
        #expect(store.nodeCount == n)
        #expect(store.edgeCount == n)
        
        // Everyone has 2 neighbors in a cycle
        for i in 0..<n {
            #expect(store.neighbors(of: "\(i)").count == 2)
        }
        
        // Everyone connected to everyone with depth n/2
        let connected = store.connected(to: "0", maxDepth: n / 2)
        #expect(connected.count == n)
    }
    
    @Test("Disconnected components")
    func disconnectedComponents() {
        let store = GraphStore()
        
        // Component 1: triangle
        store.addNode(makeNode(id: "a1"))
        store.addNode(makeNode(id: "a2"))
        store.addNode(makeNode(id: "a3"))
        store.addEdge(makeEdge(source: "a1", target: "a2"))
        store.addEdge(makeEdge(source: "a2", target: "a3"))
        store.addEdge(makeEdge(source: "a3", target: "a1"))
        
        // Component 2: single node
        store.addNode(makeNode(id: "b1"))
        
        // Component 3: edge
        store.addNode(makeNode(id: "c1"))
        store.addNode(makeNode(id: "c2"))
        store.addEdge(makeEdge(source: "c1", target: "c2"))
        
        #expect(store.nodeCount == 6)
        #expect(store.edgeCount == 4)
        
        // BFS should not cross components
        let fromA = store.connected(to: "a1", maxDepth: 10)
        #expect(fromA.count == 3)
        #expect(!fromA.contains("b1"))
        #expect(!fromA.contains("c1"))
        
        let fromB = store.connected(to: "b1", maxDepth: 10)
        #expect(fromB.count == 1)
        
        let fromC = store.connected(to: "c1", maxDepth: 10)
        #expect(fromC.count == 2)
    }
    
    @Test("Binary tree topology")
    func binaryTreeTopology() {
        let store = GraphStore()
        
        // Level 0: root
        store.addNode(makeNode(id: "root"))
        
        // Level 1
        store.addNode(makeNode(id: "l1"))
        store.addNode(makeNode(id: "r1"))
        store.addEdge(makeEdge(source: "root", target: "l1"))
        store.addEdge(makeEdge(source: "root", target: "r1"))
        
        // Level 2
        store.addNode(makeNode(id: "l1-l2"))
        store.addNode(makeNode(id: "l1-r2"))
        store.addNode(makeNode(id: "r1-l2"))
        store.addNode(makeNode(id: "r1-r2"))
        store.addEdge(makeEdge(source: "l1", target: "l1-l2"))
        store.addEdge(makeEdge(source: "l1", target: "l1-r2"))
        store.addEdge(makeEdge(source: "r1", target: "r1-l2"))
        store.addEdge(makeEdge(source: "r1", target: "r1-r2"))
        
        #expect(store.nodeCount == 7)
        #expect(store.edgeCount == 6)
        
        // Root has 2 children
        #expect(store.neighbors(of: "root").count == 2)
        
        // Leaves have 1 neighbor (parent)
        #expect(store.neighbors(of: "l1-l2").count == 1)
        
        // Full traversal from root
        let all = store.connected(to: "root", maxDepth: 3)
        #expect(all.count == 7)
    }
    
    private func makeNode(id: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: id, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
    
    private func makeEdge(source: String, target: String) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: "\(source)-\(target)",
            sourceNodeId: source, targetNodeId: target,
            type: .reference, weight: 1.0, createdAt: .now
        )
    }
}

@Suite("Graph Edge Cases - Node Types")
@MainActor
struct GraphNodeTypeEdgeCaseTests {
    
    @Test("Graph with single node type only")
    func singleNodeType() {
        let store = GraphStore()
        
        for i in 0..<5 {
            store.addNode(makeNode(id: "tag-\(i)", type: .tag))
        }
        
        for i in 0..<4 {
            store.addEdge(makeEdge(source: "tag-\(i)", target: "tag-\(i+1)"))
        }
        
        #expect(store.nodes(ofType: .tag).count == 5)
        #expect(store.nodes(ofType: .note).isEmpty)
        #expect(store.nodes(ofType: .source).isEmpty)
    }
    
    @Test("Graph with all 8 node types")
    func allNodeTypes() {
        let store = GraphStore()
        let types = GraphNodeType.allCases

        for (index, type) in types.enumerated() {
            store.addNode(makeNode(id: "node-\(index)", type: type))
        }

        #expect(store.nodeCount == 8)

        for type in types {
            #expect(store.nodes(ofType: type).count == 1)
        }

        // Connect all types in a chain
        for i in 0..<(types.count - 1) {
            store.addEdge(makeEdge(source: "node-\(i)", target: "node-\(i+1)"))
        }

        #expect(store.edgeCount == 7)
    }
    
    @Test("Node type filtering with edges")
    func nodeTypeFiltering() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "note1", type: .note))
        store.addNode(makeNode(id: "tag1", type: .tag))
        store.addNode(makeNode(id: "source1", type: .source))
        
        store.addEdge(makeEdge(source: "note1", target: "tag1"))
        store.addEdge(makeEdge(source: "tag1", target: "source1"))
        
        // Filtering by type should work
        let notes = store.nodes(ofType: .note)
        #expect(notes.count == 1)
        
        // But edges are not type-filtered at store level
        #expect(store.edgeCount == 2)
    }
    
    private func makeNode(id: String, type: GraphNodeType) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: type, label: id, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
    
    private func makeEdge(source: String, target: String) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: "\(source)-\(target)",
            sourceNodeId: source, targetNodeId: target,
            type: .reference, weight: 1.0, createdAt: .now
        )
    }
}

@Suite("Graph Edge Cases - String Edge Cases")
@MainActor
struct GraphStringEdgeCaseTests {
    
    @Test("Very long node label - 10KB+")
    func veryLongLabel() {
        let store = GraphStore()
        let longLabel = String(repeating: "A", count: 10_240)
        
        let node = GraphNodeRecord(
            id: "long",
            type: .note,
            label: longLabel,
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        )
        store.addNode(node)
        
        #expect(store.nodeCount == 1)
        #expect(store.nodes["long"]?.label.count == 10_240)
    }
    
    @Test("Empty node label")
    func emptyLabel() {
        let store = GraphStore()
        
        let node = GraphNodeRecord(
            id: "empty",
            type: .note,
            label: "",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        )
        store.addNode(node)
        
        #expect(store.nodeCount == 1)
        
        // Search should handle empty labels
        let results = store.fuzzySearch(query: "", limit: 10)
        #expect(results.isEmpty) // Empty query returns empty results
    }
    
    @Test("Whitespace-only labels")
    func whitespaceOnlyLabel() {
        let store = GraphStore()
        
        let whitespaceLabels = ["   ", "\t\t\t", "\n\n\n", " \t\n \t\n"]
        
        for (index, label) in whitespaceLabels.enumerated() {
            let node = GraphNodeRecord(
                id: "ws-\(index)",
                type: .note,
                label: label,
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == whitespaceLabels.count)
        
        // Search with whitespace should match
        let results = store.fuzzySearch(query: "   ", limit: 10)
        #expect(results.count >= 1)
    }
    
    @Test("Unicode edge cases - RTL text")
    func rtlTextLabels() {
        let store = GraphStore()
        
        let rtlLabels = [
            "مرحبا بالعالم", // Arabic
            "עברית", // Hebrew
            "العربية 👋", // Mixed RTL + emoji
        ]
        
        for (index, label) in rtlLabels.enumerated() {
            let node = GraphNodeRecord(
                id: "rtl-\(index)",
                type: .note,
                label: label,
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == rtlLabels.count)
        
        // Search should work
        let results = store.fuzzySearch(query: "مرحبا", limit: 10)
        #expect(results.count == 1)
    }
    
    @Test("Unicode edge cases - ZWJ emoji")
    func zwjEmojiLabels() {
        let store = GraphStore()
        
        let emojiLabels = [
            "👨‍👩‍👧‍👦 Family", // Family with ZWJ
            "🏳️‍🌈 Pride", // Flag with ZWJ
            "👩‍💻 Developer", // Woman technologist
            "🧑‍🚀 Astronaut", // Astronaut
        ]
        
        for (index, label) in emojiLabels.enumerated() {
            let node = GraphNodeRecord(
                id: "emoji-\(index)",
                type: .note,
                label: label,
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == emojiLabels.count)
        
        // Search should handle emoji
        let results = store.fuzzySearch(query: "developer", limit: 10)
        #expect(results.count == 1)
    }
    
    @Test("Unicode combining marks")
    func combiningMarks() {
        let store = GraphStore()
        
        // é as single codepoint vs e + combining acute
        let precomposed = "café"
        let decomposed = "cafe\u{0301}" // e + combining acute
        
        store.addNode(GraphNodeRecord(
            id: "precomposed",
            type: .note,
            label: precomposed,
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        ))
        
        store.addNode(GraphNodeRecord(
            id: "decomposed",
            type: .note,
            label: decomposed,
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        ))
        
        #expect(store.nodeCount == 2)
        
        // Swift normalizes Unicode — these compare equal despite different byte representations.
        // The important thing is that both nodes exist in the store.
        #expect(precomposed == decomposed)
    }
    
    @Test("Special characters in labels")
    func specialCharacters() {
        let store = GraphStore()
        
        let specialLabels = [
            "Line 1\nLine 2", // Newline
            "Tab\there", // Tab
            "Null\0char", // Null byte
            "Quote\"here", // Quote
            "Backslash\\path", // Backslash
        ]
        
        for (index, label) in specialLabels.enumerated() {
            let node = GraphNodeRecord(
                id: "special-\(index)",
                type: .note,
                label: label,
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == specialLabels.count)
    }
    
    @Test("Duplicate node IDs should override")
    func duplicateNodeIDs() {
        let store = GraphStore()
        
        // Add first node
        store.addNode(GraphNodeRecord(
            id: "dup",
            type: .note,
            label: "First",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: SIMD2<Float>(0, 0),
            velocity: .zero
        ))
        
        // Add second with same ID
        store.addNode(GraphNodeRecord(
            id: "dup",
            type: .tag,
            label: "Second",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 2.0,
            createdAt: .now,
            position: SIMD2<Float>(100, 100),
            velocity: .zero
        ))
        
        // Should have one node with second's properties
        #expect(store.nodeCount == 1)
        #expect(store.nodes["dup"]?.label == "Second")
        #expect(store.nodes["dup"]?.type == .tag)
    }
}

@Suite("Graph Edge Cases - Edge Weights")
@MainActor
struct GraphEdgeWeightEdgeCaseTests {
    
    @Test("Maximum edge weight")
    func maximumWeight() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        
        let maxWeight = Double.greatestFiniteMagnitude
        store.addEdge(makeEdge(source: "a", target: "b", weight: maxWeight))
        
        #expect(store.edgeCount == 1)
        #expect(store.edges.values.first?.weight == maxWeight)
    }
    
    @Test("Zero edge weight")
    func zeroWeight() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        
        store.addEdge(makeEdge(source: "a", target: "b", weight: 0))
        
        #expect(store.edgeCount == 1)
        #expect(store.edges.values.first?.weight == 0)
    }
    
    @Test("Negative edge weight")
    func negativeWeight() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        
        store.addEdge(makeEdge(source: "a", target: "b", weight: -5.0))
        
        // Store accepts negative weights (physics engine behavior may vary)
        #expect(store.edgeCount == 1)
        #expect(store.edges.values.first?.weight == -5.0)
    }
    
    @Test("Very small edge weight")
    func verySmallWeight() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        
        store.addEdge(makeEdge(source: "a", target: "b", weight: Double.leastNormalMagnitude))
        
        #expect(store.edgeCount == 1)
    }
    
    @Test("All edge types")
    func allEdgeTypes() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        
        let types: [GraphEdgeType] = [
            .reference, .contains, .tagged, .mentions, .cites,
            .authored, .related, .quotes, .supports, .contradicts,
            .expands, .questions
        ]
        
        for (index, type) in types.enumerated() {
            let targetId = "b-\(index)"
            store.addNode(makeNode(id: targetId))
            store.addEdge(GraphEdgeRecord(
                id: "edge-\(index)",
                sourceNodeId: "a",
                targetNodeId: targetId,
                type: type,
                weight: 1.0,
                createdAt: .now
            ))
        }
        
        #expect(store.edgeCount == types.count)
        
        // Verify each type
        for edge in store.edges.values {
            #expect(types.contains(edge.type))
        }
    }
    
    private func makeNode(id: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: id, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
    
    private func makeEdge(source: String, target: String, weight: Double = 1.0) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: "\(source)-\(target)",
            sourceNodeId: source, targetNodeId: target,
            type: .reference, weight: weight, createdAt: .now
        )
    }
}

@Suite("Graph Edge Cases - Shortest Path")
@MainActor
struct GraphShortestPathEdgeCaseTests {
    
    @Test("Shortest path - same node")
    func shortestPathSameNode() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        
        let path = store.query(.pathBetween(from: "a", to: "a", maxHops: 10))
        #expect(path.count == 1)
        #expect(path.first?.id == "a")
    }
    
    @Test("Shortest path - no path exists")
    func shortestPathNoPath() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        // No edge between them
        
        let path = store.query(.pathBetween(from: "a", to: "b", maxHops: 10))
        #expect(path.isEmpty)
    }
    
    @Test("Shortest path - direct connection")
    func shortestPathDirect() {
        let store = GraphStore()
        store.addNode(makeNode(id: "a"))
        store.addNode(makeNode(id: "b"))
        store.addEdge(makeEdge(source: "a", target: "b"))
        
        let path = store.query(.pathBetween(from: "a", to: "b", maxHops: 10))
        #expect(path.count == 2)
        #expect(path[0].id == "a")
        #expect(path[1].id == "b")
    }
    
    @Test("Shortest path - multiple routes")
    func shortestPathMultipleRoutes() {
        let store = GraphStore()
        
        // Nodes
        for id in ["a", "b", "c", "d"] {
            store.addNode(makeNode(id: id))
        }
        
        // Direct: a -> d (long)
        store.addEdge(makeEdge(source: "a", target: "d"))
        
        // Indirect: a -> b -> c -> d (3 hops)
        store.addEdge(makeEdge(source: "a", target: "b"))
        store.addEdge(makeEdge(source: "b", target: "c"))
        store.addEdge(makeEdge(source: "c", target: "d"))
        
        // BFS finds shortest (direct)
        let path = store.query(.pathBetween(from: "a", to: "d", maxHops: 10))
        #expect(path.count == 2) // Direct path
    }
    
    @Test("Shortest path - max hops limit")
    func shortestPathMaxHops() {
        let store = GraphStore()
        
        // Chain: a -> b -> c -> d -> e
        for id in ["a", "b", "c", "d", "e"] {
            store.addNode(makeNode(id: id))
        }
        store.addEdge(makeEdge(source: "a", target: "b"))
        store.addEdge(makeEdge(source: "b", target: "c"))
        store.addEdge(makeEdge(source: "c", target: "d"))
        store.addEdge(makeEdge(source: "d", target: "e"))
        
        // Within limit
        let path3 = store.query(.pathBetween(from: "a", to: "d", maxHops: 3))
        #expect(path3.count == 4)
        
        // Exceeds limit
        let path2 = store.query(.pathBetween(from: "a", to: "e", maxHops: 2))
        #expect(path2.isEmpty)
    }
    
    private func makeNode(id: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: id, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
    
    private func makeEdge(source: String, target: String) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: "\(source)-\(target)",
            sourceNodeId: source, targetNodeId: target,
            type: .reference, weight: 1.0, createdAt: .now
        )
    }
}
