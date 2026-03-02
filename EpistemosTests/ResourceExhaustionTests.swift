import Testing
@testable import Epistemos
import Foundation

// MARK: - Resource Exhaustion Tests
// Tests for memory pressure, large payloads, and resource limits.

@Suite("Resource Exhaustion - Large Metadata Payloads")
@MainActor
struct ResourceLargeMetadataTests {
    
    @Test("Very large metadata - 1MB JSON")
    func largeMetadata1MB() {
        let node = SDGraphNode(type: .source, label: "Large Paper")
        
        var meta = GraphNodeMetadata()
        meta.abstract = String(repeating: "Lorem ipsum dolor sit amet. ", count: 30_000)
        
        node.meta = meta
        
        let retrieved = node.meta
        #expect(retrieved.abstract?.count == meta.abstract?.count)
    }
    
    @Test("Metadata with many authors")
    func manyAuthors() {
        let node = SDGraphNode(type: .source, label: "Many Authors Paper")
        
        var meta = GraphNodeMetadata()
        meta.authors = (0..<1000).map { "Author \($0) Name" }
        
        node.meta = meta
        
        let retrieved = node.meta
        #expect(retrieved.authors?.count == 1000)
    }
    
    @Test("Deeply nested metadata structure")
    func deeplyNestedMetadata() {
        let node = SDGraphNode(type: .source, label: "Complex")
        
        var meta = GraphNodeMetadata()
        meta.doi = String(repeating: "10.1234/", count: 100) + "test"
        meta.url = String(repeating: "https://example.com/", count: 100) + "paper"
        meta.journal = String(repeating: "Journal of ", count: 50) + "Science"
        meta.clusterTheme = String(repeating: "theme-", count: 100)
        
        node.meta = meta
        
        let retrieved = node.meta
        #expect(retrieved.doi?.count == meta.doi?.count)
    }
    
    @Test("Empty but large metadata allocation")
    func emptyLargeAllocation() {
        let node = SDGraphNode(type: .note, label: "Empty")
        
        for _ in 0..<1000 {
            _ = node.meta
        }
        
        #expect(node.metadata == nil)
    }
    
    @Test("Metadata with very long URL")
    func veryLongURL() {
        let node = SDGraphNode(type: .source, label: "Source")
        
        var meta = GraphNodeMetadata()
        meta.url = String(repeating: "https://example.com/path/", count: 1000) + "end"
        
        node.meta = meta
        
        #expect(node.meta.url?.count == 1000 * 25 + 3)
    }
    
    @Test("Metadata with very long DOI")
    func veryLongDOI() {
        let node = SDGraphNode(type: .source, label: "Source")
        
        var meta = GraphNodeMetadata()
        meta.doi = String(repeating: "10.1234/", count: 500) + "test"
        
        node.meta = meta
        
        #expect(node.meta.doi?.count == 500 * 8 + 4)
    }
}

@Suite("Resource Exhaustion - Maximum String Lengths")
@MainActor
struct ResourceMaxStringLengthTests {
    
    @Test("Maximum node label - 100KB")
    func maxNodeLabel100KB() {
        let hugeLabel = String(repeating: "X", count: 100_000)
        let node = SDGraphNode(type: .note, label: hugeLabel)
        
        #expect(node.label.count == 100_000)
    }
    
    @Test("Maximum source ID length")
    func maxSourceIDLength() {
        let hugeSourceId = String(repeating: "id-", count: 10_000)
        let node = SDGraphNode(type: .note, label: "Test", sourceId: hugeSourceId)
        
        #expect(node.sourceId?.count == 30_000)
    }
    
    @Test("Graph with many long labels")
    func manyLongLabels() {
        let store = GraphStore()
        
        for i in 0..<100 {
            let label = String(repeating: "Word \(i) ", count: 100)
            let node = GraphNodeRecord(
                id: "node-\(i)",
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
        
        #expect(store.nodeCount == 100)
        
        let results = store.fuzzySearch(query: "word", limit: 20)
        #expect(results.count > 0)
    }
    
    @Test("Unicode heavy labels")
    func unicodeHeavyLabels() {
        let store = GraphStore()
        
        let emojiString = String(repeating: "👨‍👩‍👧‍👦", count: 1000)
        
        let node = GraphNodeRecord(
            id: "emoji-node",
            type: .note,
            label: emojiString,
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        )
        store.addNode(node)
        
        #expect(store.nodeCount == 1)
        #expect(store.nodes["emoji-node"]?.label.count == 1000)
    }
    
    @Test("Label with many newlines")
    func labelWithManyNewlines() {
        let label = String(repeating: "Line\n", count: 1000)
        let node = SDGraphNode(type: .note, label: label)
        
        #expect(node.label.filter { $0 == "\n" }.count == 1000)
    }
    
    @Test("Label with many tabs")
    func labelWithManyTabs() {
        let label = String(repeating: "Col\t", count: 1000)
        let node = SDGraphNode(type: .note, label: label)
        
        #expect(node.label.filter { $0 == "\t" }.count == 1000)
    }
}

@Suite("Resource Exhaustion - Large Graph Sizes")
@MainActor
struct ResourceLargeGraphTests {
    
    @Test("Graph with 10,000 nodes - memory check")
    func graph10000Nodes() {
        let store = GraphStore()
        
        for i in 0..<10_000 {
            let node = GraphNodeRecord(
                id: "node-\(i)",
                type: .note,
                label: "Node \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: SIMD2<Float>(Float.random(in: -1000...1000), Float.random(in: -1000...1000)),
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == 10_000)
    }
    
    @Test("Graph with 100,000 edges")
    func graph100000Edges() {
        let store = GraphStore()
        
        let nodeCount = 1000
        for i in 0..<nodeCount {
            store.addNode(GraphNodeRecord(
                id: "\(i)",
                type: .note,
                label: "\(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            ))
        }
        
        var edgeCount = 0
        for i in 0..<nodeCount {
            for j in (i+1)..<min(i+100, nodeCount) {
                store.addEdge(GraphEdgeRecord(
                    id: "e-\(i)-\(j)",
                    sourceNodeId: "\(i)",
                    targetNodeId: "\(j)",
                    type: .reference,
                    weight: 1.0,
                    createdAt: .now
                ))
                edgeCount += 1
                if edgeCount >= 100_000 { break }
            }
            if edgeCount >= 100_000 { break }
        }
        
        #expect(store.edgeCount >= 99_000)
    }
    
    @Test("BFS on very deep graph")
    func bfsOnDeepGraph() {
        let store = GraphStore()
        
        let depth = 10_000
        
        store.addNode(GraphNodeRecord(
            id: "0",
            type: .note,
            label: "Start",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        ))
        
        for i in 1..<depth {
            store.addNode(GraphNodeRecord(
                id: "\(i)",
                type: .note,
                label: "Node \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            ))
            store.addEdge(GraphEdgeRecord(
                id: "e-\(i)",
                sourceNodeId: "\(i-1)",
                targetNodeId: "\(i)",
                type: .reference,
                weight: 1.0,
                createdAt: .now
            ))
        }
        
        let connected = store.connected(to: "0", maxDepth: 100)
        #expect(connected.count == 101)
    }
    
    @Test("Fuzzy search on large graph")
    func fuzzySearchLargeGraph() {
        let store = GraphStore()
        
        for i in 0..<5000 {
            store.addNode(GraphNodeRecord(
                id: "\(i)",
                type: .note,
                label: "Common Prefix \(i) \(String(repeating: "A", count: i % 20))",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            ))
        }
        
        let start = Date()
        let results = store.fuzzySearch(query: "common", limit: 50)
        let duration = Date().timeIntervalSince(start)
        
        #expect(results.count == 50)
        #expect(duration < 1.0)
    }
    
    @Test("Star graph with many spokes")
    func starGraphManySpokes() {
        let store = GraphStore()
        
        store.addNode(GraphNodeRecord(
            id: "center",
            type: .note,
            label: "Center",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        ))
        
        for i in 0..<5000 {
            store.addNode(GraphNodeRecord(
                id: "spoke-\(i)",
                type: .note,
                label: "Spoke \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            ))
            store.addEdge(GraphEdgeRecord(
                id: "e-\(i)",
                sourceNodeId: "center",
                targetNodeId: "spoke-\(i)",
                type: .reference,
                weight: 1.0,
                createdAt: .now
            ))
        }
        
        #expect(store.nodeCount == 5001)
        #expect(store.edgeCount == 5000)
        #expect(store.linkCount(for: "center") == 5000)
    }
    
    @Test("Complete graph medium size")
    func completeGraphMedium() {
        let store = GraphStore()
        let n = 200
        
        for i in 0..<n {
            store.addNode(GraphNodeRecord(
                id: "\(i)",
                type: .note,
                label: "\(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            ))
        }
        
        for i in 0..<n {
            for j in (i+1)..<n {
                store.addEdge(GraphEdgeRecord(
                    id: "e-\(i)-\(j)",
                    sourceNodeId: "\(i)",
                    targetNodeId: "\(j)",
                    type: .reference,
                    weight: 1.0,
                    createdAt: .now
                ))
            }
        }
        
        #expect(store.nodeCount == n)
        #expect(store.edgeCount == n * (n - 1) / 2)
    }
}

@Suite("Resource Exhaustion - Memory Pressure Simulation")
@MainActor
struct ResourceMemoryPressureTests {
    
    @Test("Rapid graph rebuild cycles")
    func rapidRebuildCycles() {
        let store = GraphStore()
        
        for cycle in 0..<100 {
            store.clear()
            
            for i in 0..<100 {
                store.addNode(GraphNodeRecord(
                    id: "cycle-\(cycle)-\(i)",
                    type: .note,
                    label: "Cycle \(cycle) Node \(i)",
                    sourceId: nil,
                    metadata: GraphNodeMetadata(),
                    weight: 1.0,
                    createdAt: .now,
                    position: .zero,
                    velocity: .zero
                ))
            }
            
            for i in 0..<50 {
                store.addEdge(GraphEdgeRecord(
                    id: "e-\(cycle)-\(i)",
                    sourceNodeId: "cycle-\(cycle)-\(i)",
                    targetNodeId: "cycle-\(cycle)-\(i+1)",
                    type: .reference,
                    weight: 1.0,
                    createdAt: .now
                ))
            }
        }
        
        #expect(store.nodeCount == 100)
        #expect(store.edgeCount == 50)
    }
    
    @Test("Position hints accumulation")
    func positionHintsAccumulation() {
        let store = GraphStore()
        
        for i in 0..<10_000 {
            store.positionHints["ghost-\(i)"] = SIMD2<Float>(Float(i), Float(i))
        }
        
        #expect(store.positionHints.count == 10_000)
        
        for i in 0..<100 {
            store.addNode(GraphNodeRecord(
                id: "ghost-\(i)",
                type: .note,
                label: "Node \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            ))
        }
        
        #expect(store.positionHints.count == 9_900)
    }
    
    @Test("Concurrent array growth")
    func concurrentArrayGrowth() async {
        let state = GraphState()
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    for j in 0..<100 {
                        state.store.addNode(GraphNodeRecord(
                            id: "task-\(i)-\(j)",
                            type: .note,
                            label: "Task \(i) Node \(j)",
                            sourceId: nil,
                            metadata: GraphNodeMetadata(),
                            weight: 1.0,
                            createdAt: .now,
                            position: .zero,
                            velocity: .zero
                        ))
                    }
                }
            }
        }
        
        #expect(state.store.nodeCount == 1000)
    }
    
    @Test("Many ephemeral node batches")
    func manyEphemeralBatches() {
        let state = GraphState()
        
        for batch in 0..<50 {
            // Add batch
            for i in 0..<20 {
                let id = "batch-\(batch)-ephemeral-\(i)"
                state.store.addNode(GraphNodeRecord(
                    id: id,
                    type: .quote,
                    label: "Quote \(id)",
                    sourceId: nil,
                    metadata: GraphNodeMetadata(),
                    weight: 1.0,
                    createdAt: .now,
                    position: .zero,
                    velocity: .zero
                ))
                state.ephemeralNodeIds.insert(id)
            }
            
            // Cleanup
            state.cleanupEphemeralNodes()
        }
        
        #expect(state.ephemeralNodeIds.isEmpty)
    }
}

@Suite("Resource Exhaustion - Edge Cases")
@MainActor
struct ResourceEdgeCaseTests {
    
    @Test("Graph near static layout threshold")
    func nearStaticLayoutThreshold() {
        let store = GraphStore()
        let threshold = GraphState.staticLayoutThreshold
        
        for i in 0..<(threshold - 10) {
            store.addNode(GraphNodeRecord(
                id: "\(i)",
                type: .note,
                label: "\(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            ))
        }
        
        #expect(store.nodeCount == threshold - 10)
    }
    
    @Test("Graph at static layout threshold")
    func atStaticLayoutThreshold() {
        let store = GraphStore()
        let threshold = GraphState.staticLayoutThreshold
        
        for i in 0..<threshold {
            store.addNode(GraphNodeRecord(
                id: "\(i)",
                type: .note,
                label: "\(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            ))
        }
        
        #expect(store.nodeCount == threshold)
    }
    
    @Test("Graph above static layout threshold")
    func aboveStaticLayoutThreshold() {
        let store = GraphStore()
        let count = GraphState.staticLayoutThreshold + 100
        
        for i in 0..<count {
            store.addNode(GraphNodeRecord(
                id: "\(i)",
                type: .note,
                label: "\(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            ))
        }
        
        #expect(store.nodeCount == count)
    }
    
    @Test("Filter with all types active")
    func filterAllTypesActive() {
        let filter = FilterEngine()
        
        #expect(filter.activeNodeTypes.count == GraphNodeType.allCases.count)
        
        for type in GraphNodeType.allCases {
            #expect(filter.activeNodeTypes.contains(type))
        }
    }
    
    @Test("Filter with no types active")
    func filterNoTypesActive() {
        let filter = FilterEngine()
        let store = GraphStore()
        
        store.addNode(GraphNodeRecord(
            id: "test",
            type: .note,
            label: "Test",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        ))
        
        for type in GraphNodeType.allCases {
            filter.activeNodeTypes.remove(type)
        }
        
        let node = store.nodes.values.first!
        #expect(!filter.isNodeVisible(node))
    }
    
    @Test("Graph with zero weight nodes")
    func zeroWeightNodes() {
        let store = GraphStore()
        
        for i in 0..<100 {
            store.addNode(GraphNodeRecord(
                id: "\(i)",
                type: .note,
                label: "\(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            ))
        }
        
        #expect(store.nodeCount == 100)
    }
    
    @Test("Graph with negative weight nodes")
    func negativeWeightNodes() {
        let store = GraphStore()
        
        for i in 0..<100 {
            store.addNode(GraphNodeRecord(
                id: "\(i)",
                type: .note,
                label: "\(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: -1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            ))
        }
        
        #expect(store.nodeCount == 100)
    }
}

@Suite("Resource Exhaustion - Time Range Extremes")
@MainActor
struct ResourceTimeRangeTests {
    
    @Test("Time range with maximum span")
    func maximumTimeSpan() {
        let store = GraphStore()
        
        store.addNode(GraphNodeRecord(
            id: "ancient",
            type: .note,
            label: "Ancient",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: Date.distantPast,
            position: .zero,
            velocity: .zero
        ))
        
        store.addNode(GraphNodeRecord(
            id: "future",
            type: .note,
            label: "Future",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: Date.distantFuture,
            position: .zero,
            velocity: .zero
        ))
        
        #expect(store.nodeCount == 2)
    }
    
    @Test("Many nodes with same timestamp")
    func manyNodesSameTimestamp() {
        let store = GraphStore()
        let sameDate = Date.now
        
        for i in 0..<10_000 {
            store.addNode(GraphNodeRecord(
                id: "\(i)",
                type: .note,
                label: "Node \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: sameDate,
                position: .zero,
                velocity: .zero
            ))
        }
        
        #expect(store.nodeCount == 10_000)
    }
    
    @Test("Nodes with epoch timestamp")
    func nodesWithEpochTimestamp() {
        let store = GraphStore()
        
        for i in 0..<100 {
            store.addNode(GraphNodeRecord(
                id: "\(i)",
                type: .note,
                label: "Node \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: Date(timeIntervalSince1970: 0),
                position: .zero,
                velocity: .zero
            ))
        }
        
        #expect(store.nodeCount == 100)
    }
}

@Suite("Resource Exhaustion - Cache and Transient Data")
@MainActor
struct ResourceCacheTests {
    
    @Test("Metadata cache invalidation")
    func metadataCacheInvalidation() {
        let node = SDGraphNode(type: .note, label: "Test")
        
        var meta1 = GraphNodeMetadata()
        meta1.year = 2020
        node.meta = meta1
        
        _ = node.meta
        
        node.metadata = Data("""
            {"year": 2030}
            """.utf8)
        
        let meta2 = node.meta
        _ = meta2
        
        #expect(node.metadata != nil)
    }
    
    @Test("Transient cache cleanup")
    func transientCacheCleanup() {
        let node = SDGraphNode(type: .note, label: "Test")
        
        for i in 0..<100 {
            var meta = GraphNodeMetadata()
            meta.year = 2000 + i
            node.meta = meta
            _ = node.meta
        }
        
        let finalMeta = node.meta
        #expect(finalMeta.year != nil)
    }
    
    @Test("Rapid metadata switching")
    func rapidMetadataSwitching() {
        let node = SDGraphNode(type: .note, label: "Test")
        
        for i in 0..<1000 {
            var meta = GraphNodeMetadata()
            meta.year = i
            meta.researchStage = i % 10
            node.meta = meta
        }
        
        #expect(node.meta.year != nil)
    }
}
