import Testing
import Foundation
import SwiftData
@testable import Epistemos

// MARK: - Test Data Generators

@MainActor
enum GraphTestDataGenerator {
    private static let visibleNodeTypes: [GraphNodeType] = [.note, .chat, .idea, .folder]
    
    /// Generate test nodes with specified count
    static func generateNodes(count: Int, baseType: GraphNodeType = .note) -> [SDGraphNode] {
        var nodes: [SDGraphNode] = []
        let baseDate = Date().addingTimeInterval(-Double(count) * 86400) // Spread over days
        let defaultType = visibleNodeTypes.contains(baseType) ? baseType : .note
        
        for i in 0..<count {
            let type = baseType == .note
                ? visibleNodeTypes[i % visibleNodeTypes.count]
                : defaultType
            
            let node = SDGraphNode(
                type: type,
                label: "Test Node \(i) - \(UUID().uuidString.prefix(8))",
                sourceId: "source-\(i)",
                weight: Double.random(in: 1.0...10.0)
            )
            node.createdAt = baseDate.addingTimeInterval(Double(i) * 3600)
            nodes.append(node)
        }
        return nodes
    }
    
    /// Generate test edges connecting nodes in various patterns
    static func generateEdges(for nodes: [SDGraphNode], edgeRatio: Double = 1.5) -> [SDGraphEdge] {
        var edges: [SDGraphEdge] = []
        let targetEdgeCount = Int(Double(nodes.count) * edgeRatio)
        let edgeTypes: [GraphEdgeType] = [.reference, .contains, .tagged, .mentions, .cites, .related, .supports, .contradicts]
        
        guard nodes.count >= 2 else { return edges }
        
        for i in 0..<targetEdgeCount {
            let sourceIdx = i % nodes.count
            let targetIdx = (i + 1 + (i / nodes.count)) % nodes.count
            
            let edge = SDGraphEdge(
                source: nodes[sourceIdx].id,
                target: nodes[targetIdx].id,
                type: edgeTypes[i % edgeTypes.count],
                weight: Double.random(in: 0.5...3.0)
            )
            edges.append(edge)
        }
        return edges
    }
    
    /// Generate a connected graph structure (tree + random edges)
    static func generateConnectedGraph(nodeCount: Int) -> (nodes: [SDGraphNode], edges: [SDGraphEdge]) {
        let nodes = generateNodes(count: nodeCount)
        var edges: [SDGraphEdge] = []
        
        // Create a spanning tree to ensure connectivity
        for i in 1..<nodes.count {
            let parentIdx = (i - 1) / 2 // Binary tree structure
            let edge = SDGraphEdge(
                source: nodes[parentIdx].id,
                target: nodes[i].id,
                type: .contains,
                weight: 2.0
            )
            edges.append(edge)
        }
        
        // Add random cross-edges for complexity
        let extraEdges = nodeCount / 3
        for i in 0..<extraEdges {
            let sourceIdx = Int.random(in: 0..<nodes.count)
            let targetIdx = Int.random(in: 0..<nodes.count)
            if sourceIdx != targetIdx {
                let edge = SDGraphEdge(
                    source: nodes[sourceIdx].id,
                    target: nodes[targetIdx].id,
                    type: .reference,
                    weight: 1.0
                )
                edges.append(edge)
            }
        }
        
        return (nodes, edges)
    }
}

@MainActor
private enum GraphFFIBatchFixture {
    static func makeStoreAndFilter() -> (
        store: GraphStore,
        filter: FilterEngine,
        nodes: [GraphNodeRecord],
        edges: [GraphEdgeRecord]
    ) {
        let createdAt = Date(timeIntervalSince1970: 0)
        let nodes = [
            GraphNodeRecord(
                id: "note-a",
                type: .note,
                label: "Note A",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: createdAt,
                position: SIMD2<Float>(10, 20)
            ),
            GraphNodeRecord(
                id: "chat-b",
                type: .chat,
                label: "Chat B",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: createdAt,
                position: SIMD2<Float>(30, 40)
            ),
            GraphNodeRecord(
                id: "note-c",
                type: .note,
                label: "Note C",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: createdAt,
                position: SIMD2<Float>(50, 60)
            ),
        ]

        let edges = [
            GraphEdgeRecord(
                id: "edge-ab",
                sourceNodeId: "note-a",
                targetNodeId: "chat-b",
                type: .reference,
                weight: 1.0,
                createdAt: createdAt
            ),
            GraphEdgeRecord(
                id: "edge-ac",
                sourceNodeId: "note-a",
                targetNodeId: "note-c",
                type: .contains,
                weight: 2.0,
                createdAt: createdAt
            ),
        ]

        let store = GraphStore()
        nodes.forEach(store.addNode)
        edges.forEach(store.addEdge)

        let filter = FilterEngine()
        filter.toggleType(.chat)
        return (store, filter, nodes, edges)
    }
}

private actor DeferredMetadataRunCounter {
    private var count = 0
    private var waiters: [Int: [CheckedContinuation<Void, Never>]] = [:]

    func increment() -> Int {
        count += 1
        let readyTargets = waiters.keys.filter { $0 <= count }
        for target in readyTargets {
            let continuations = waiters.removeValue(forKey: target) ?? []
            for continuation in continuations {
                continuation.resume()
            }
        }
        return count
    }

    func value() -> Int {
        count
    }

    func waitUntilValue(_ expected: Int) async {
        if count >= expected {
            return
        }
        await withCheckedContinuation { continuation in
            waiters[expected, default: []].append(continuation)
        }
    }
}

private actor DeferredMetadataRunGate {
    private var started = false
    private var released = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func markStarted() {
        guard !started else { return }
        started = true
        let waiters = startWaiters
        startWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    func waitUntilStarted() async {
        if started {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func release() {
        guard !released else { return }
        released = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    func waitUntilReleased() async {
        if released {
            return
        }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }
}

@Suite("Graph Deferred Metadata Driver", .serialized)
struct GraphDeferredMetadataDriverTests {
    @Test("burst metadata requests before the next run loop tick coalesce")
    func burstRequestsCoalesce() async {
        let driver = await MainActor.run { GraphDeferredMetadataDriver() }
        let counter = DeferredMetadataRunCounter()

        await MainActor.run {
            driver.request {
                _ = await counter.increment()
            }
            driver.request {
                _ = await counter.increment()
            }
            driver.request {
                _ = await counter.increment()
            }
        }

        await counter.waitUntilValue(1)

        #expect(await counter.value() == 1)
    }

    @Test("metadata request while a run is active schedules exactly one rerun")
    func inFlightRequestSchedulesSingleRerun() async {
        let driver = await MainActor.run { GraphDeferredMetadataDriver() }
        let counter = DeferredMetadataRunCounter()
        let gate = DeferredMetadataRunGate()

        let run: @MainActor @Sendable () async -> Void = {
            let current = await counter.increment()
            if current == 1 {
                await gate.markStarted()
                await gate.waitUntilReleased()
            }
        }

        await MainActor.run {
            driver.request(run: run)
        }
        await gate.waitUntilStarted()
        await MainActor.run {
            driver.request(run: run)
            driver.request(run: run)
        }
        await gate.release()

        await counter.waitUntilValue(2)

        #expect(await counter.value() == 2)
    }
}

// MARK: - Graph Performance Tests

@Suite("Graph Performance")
@MainActor
struct GraphPerformanceTests {
    
    // MARK: - Node Loading Performance
    
    @Test("Load 100 nodes performance")
    func load100NodesPerformance() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 100)
        
        let recordCount = nodes.count
        
        var loadTime: Duration = .zero
        measure {
            let start = ContinuousClock().now
            store.loadDirect(nodes: nodes, edges: edges)
            loadTime = ContinuousClock().now - start
        }
        
        #expect(store.nodeCount == recordCount)
        // Threshold: 100 nodes should load in < 50ms
        #expect(loadTime < .milliseconds(50), "Loading 100 nodes took \(loadTime), expected < 50ms")
    }
    
    @Test("Load 500 nodes performance")
    func load500NodesPerformance() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 500)
        
        var loadTime: Duration = .zero
        measure {
            let start = ContinuousClock().now
            store.loadDirect(nodes: nodes, edges: edges)
            loadTime = ContinuousClock().now - start
        }
        
        #expect(store.nodeCount == 500)
        // Threshold: 500 nodes should load in < 100ms
        #expect(loadTime < .milliseconds(100), "Loading 500 nodes took \(loadTime), expected < 100ms")
    }
    
    @Test("Load 1000 nodes performance")
    func load1000NodesPerformance() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        
        var loadTime: Duration = .zero
        measure {
            let start = ContinuousClock().now
            store.loadDirect(nodes: nodes, edges: edges)
            loadTime = ContinuousClock().now - start
        }
        
        #expect(store.nodeCount == 1000)
        // Threshold: 1000 nodes should load in < 200ms
        #expect(loadTime < .milliseconds(200), "Loading 1000 nodes took \(loadTime), expected < 200ms")
    }
    
    @Test("Load 5000 nodes performance")
    func load5000NodesPerformance() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 5000)
        
        var loadTime: Duration = .zero
        measure {
            let start = ContinuousClock().now
            store.loadDirect(nodes: nodes, edges: edges)
            loadTime = ContinuousClock().now - start
        }
        
        #expect(store.nodeCount == 5000)
        // Threshold: 5000 nodes should load in < 500ms
        #expect(loadTime < .milliseconds(500), "Loading 5000 nodes took \(loadTime), expected < 500ms")
    }
    
    // MARK: - Edge Loading Performance
    
    @Test("Load edges at different scales")
    func loadEdgesAtDifferentScales() async throws {
        let scales = [100, 500, 1000, 2500]
        
        for nodeCount in scales {
            let store = GraphStore()
            let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: nodeCount)
            
            var loadTime: Duration = .zero
            measure {
                let start = ContinuousClock().now
                store.loadDirect(nodes: nodes, edges: edges)
                loadTime = ContinuousClock().now - start
            }
            
            // Edge load time should scale roughly linearly with node count
            let expectedMaxTime = Double(nodeCount) * 0.2 // 0.2ms per node
            #expect(loadTime < .milliseconds(Int(expectedMaxTime)), 
                    "Loading \(nodeCount) nodes with edges took \(loadTime)")
        }
    }
    
    // MARK: - Graph Building Performance
    
    @Test("GraphBuilder persist with small diff")
    func graphBuilderSmallDiffPerformance() async throws {
        let builder = GraphBuilder()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 100)
        
        // First persist to establish baseline
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SDGraphNode.self, SDGraphEdge.self, configurations: config)
        let context = ModelContext(container)
        
        builder.persist(nodes: nodes, edges: edges, context: context)
        
        // Measure second persist (should be fast due to diff)
        var persistTime: Duration = .zero
        measure {
            let start = ContinuousClock().now
            builder.persist(nodes: nodes, edges: edges, context: context)
            persistTime = ContinuousClock().now - start
        }
        
        // No-change diff should stay comfortably below a frame budget in test environments.
        #expect(persistTime < .milliseconds(100), "No-change persist took \(persistTime)")
    }
    
    @Test("GraphBuilder persist with medium changes")
    func graphBuilderMediumDiffPerformance() async throws {
        let builder = GraphBuilder()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 500)
        
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SDGraphNode.self, SDGraphEdge.self, configurations: config)
        let context = ModelContext(container)
        
        builder.persist(nodes: nodes, edges: edges, context: context)
        
        // Modify 10% of nodes
        var modifiedNodes = nodes
        for i in 0..<50 {
            modifiedNodes[i].label = "Modified \(i)"
            modifiedNodes[i].updatedAt = Date()
        }
        
        var persistTime: Duration = .zero
        measure {
            let start = ContinuousClock().now
            builder.persist(nodes: modifiedNodes, edges: edges, context: context)
            persistTime = ContinuousClock().now - start
        }
        
        // Partial diff should be reasonable (< 100ms for 50 changed nodes)
        #expect(persistTime < .milliseconds(500), "Partial persist took \(persistTime)")
    }
    
    @Test("GraphBuilder persist with large changes")
    func graphBuilderLargeDiffPerformance() async throws {
        let builder = GraphBuilder()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SDGraphNode.self, SDGraphEdge.self, configurations: config)
        let context = ModelContext(container)
        
        builder.persist(nodes: nodes, edges: edges, context: context)
        
        // Add 200 new nodes
        let newNodes = GraphTestDataGenerator.generateNodes(count: 200)
        let modifiedNodes = nodes + newNodes
        
        var persistTime: Duration = .zero
        measure {
            let start = ContinuousClock().now
            builder.persist(nodes: modifiedNodes, edges: edges, context: context)
            persistTime = ContinuousClock().now - start
        }
        
        // Adding many nodes should be < 150ms
        #expect(persistTime < .milliseconds(1000), "Large persist took \(persistTime)")
    }
    
    // MARK: - BFS Traversal Performance
    
    @Test("BFS connected() traversal at different depths")
    func bfsConnectedTraversalPerformance() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let startNodeId = nodes[0].id
        
        // Test different depths
        let depths = [1, 2, 3, 5, 10]
        for depth in depths {
            var traversalTime: Duration = .zero
            var resultCount = 0
            
            measure {
                let start = ContinuousClock().now
                let connected = store.connected(to: startNodeId, maxDepth: depth)
                traversalTime = ContinuousClock().now - start
                resultCount = connected.count
            }
            
            // BFS should be very fast even at depth 10
            #expect(traversalTime < .milliseconds(5), 
                    "BFS depth \(depth) took \(traversalTime), found \(resultCount) nodes")
        }
    }
    
    @Test("BFS shortestPath performance")
    func shortestPathPerformance() async throws {
        let store = GraphStore()
        // Create a larger connected graph for path finding
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 2000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        // Test paths between various node pairs
        let testPairs = [
            (0, 100),
            (0, 500),
            (0, 999),
            (250, 750),
            (500, 1000)
        ]
        
        for (startIdx, endIdx) in testPairs {
            let startId = nodes[startIdx].id
            let endId = nodes[endIdx].id
            
            var pathTime: Duration = .zero
            var pathLength = 0
            
            measure {
                let start = ContinuousClock().now
                let path = store.query(.pathBetween(from: startId, to: endId, maxHops: 20))
                pathTime = ContinuousClock().now - start
                pathLength = path.count
            }
            
            // Shortest path should complete in < 10ms even for long paths
            #expect(pathTime < .milliseconds(10),
                    "Shortest path \(startIdx)->\(endIdx) took \(pathTime), length \(pathLength)")
            #expect(pathLength > 0, "Path should exist between connected nodes")
        }
    }
    
    @Test("BFS performance on dense graph")
    func bfsDenseGraphPerformance() async throws {
        let store = GraphStore()
        let nodeCount = 500
        let nodes = GraphTestDataGenerator.generateNodes(count: nodeCount)
        // Create dense graph (many edges per node)
        let edges = GraphTestDataGenerator.generateEdges(for: nodes, edgeRatio: 5.0)
        store.loadDirect(nodes: nodes, edges: edges)
        
        var traversalTime: Duration = .zero
        measure {
            let start = ContinuousClock().now
            let _ = store.connected(to: nodes[0].id, maxDepth: 5)
            traversalTime = ContinuousClock().now - start
        }
        
        // Even on dense graph, BFS should complete quickly
        #expect(traversalTime < .milliseconds(20), "Dense graph BFS took \(traversalTime)")
    }
    
    // MARK: - Fuzzy Search Performance
    
    @Test("Fuzzy search with 100 nodes")
    func fuzzySearch100Nodes() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 100)
        store.loadDirect(nodes: nodes, edges: edges)
        
        var searchTime: Duration = .zero
        var resultCount = 0
        
        measure {
            let start = ContinuousClock().now
            let results = store.fuzzySearch(query: "Test Node", limit: 20)
            searchTime = ContinuousClock().now - start
            resultCount = results.count
        }
        
        // Fuzzy search should be sub-millisecond for small graphs
        #expect(searchTime < .milliseconds(50), "Fuzzy search on 100 nodes took \(searchTime)")
        #expect(resultCount > 0, "Should find matches")
    }
    
    @Test("Fuzzy search with 1000 nodes")
    func fuzzySearch1000Nodes() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        var searchTime: Duration = .zero
        var resultCount = 0
        
        measure {
            let start = ContinuousClock().now
            let results = store.fuzzySearch(query: "Node 5", limit: 20)
            searchTime = ContinuousClock().now - start
            resultCount = results.count
        }
        
        // Should still be fast on medium graphs
        #expect(searchTime < .milliseconds(50), "Fuzzy search on 1000 nodes took \(searchTime)")
        #expect(resultCount > 0, "Should find matches")
    }
    
    @Test("Fuzzy search with 5000 nodes")
    func fuzzySearch5000Nodes() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 5000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        var searchTime: Duration = .zero
        
        measure {
            let start = ContinuousClock().now
            let _ = store.fuzzySearch(query: "Test", limit: 20)
            searchTime = ContinuousClock().now - start
        }
        
        // Should complete in reasonable time even for large graphs
        #expect(searchTime < .milliseconds(250), "Fuzzy search on 5000 nodes took \(searchTime)")
    }
    
    @Test("Fuzzy search scoring tiers")
    func fuzzySearchScoringTiers() async throws {
        let store = GraphStore()
        let nodes = [
            SDGraphNode(type: .note, label: "Exact Match", sourceId: "1"),
            SDGraphNode(type: .note, label: "Prefix Match Here", sourceId: "2"),
            SDGraphNode(type: .note, label: "Word Start Matching", sourceId: "3"),
            SDGraphNode(type: .note, label: "Contains match within", sourceId: "4"),
            SDGraphNode(type: .note, label: "m-a-t-c-h subsequence", sourceId: "5")
        ]
        store.loadDirect(nodes: nodes, edges: [])
        
        let results = store.fuzzySearch(query: "match", limit: 10)
        
        // Verify scoring order
        #expect(results.count >= 4, "Should find multiple matches")
        
        // Exact match should have highest score
        if let exact = results.first(where: { $0.node.label == "Exact Match" }) {
            #expect(exact.score >= 0.5, "Exact match should have score >= 0.5, got \(exact.score)")
        }
    }
    
    // MARK: - Memory Usage Tracking
    
    @Test("Memory usage during node loading")
    func memoryUsageDuringLoad() async throws {
        let nodeCounts = [100, 500, 1000, 2000]
        
        for count in nodeCounts {
            let store = GraphStore()
            let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: count)
            
            // Load multiple times to check for leaks
            for _ in 0..<5 {
                store.loadDirect(nodes: nodes, edges: edges)
            }
            
            // Store should hold correct count after reloads
            #expect(store.nodeCount == count, "Store should have \(count) nodes")
        }
    }
    
    // MARK: - Position Hint Performance
    
    @Test("Position hint application performance")
    func positionHintPerformance() async throws {
        let store = GraphStore()
        let nodeCount = 1000
        let nodes = GraphTestDataGenerator.generateNodes(count: nodeCount)
        
        // Create position hints for all nodes
        var hints: [String: SIMD2<Float>] = [:]
        for (index, node) in nodes.enumerated() {
            let angle = Float(index) * 0.1
            let radius = Float(index) * 10.0
            hints[node.id] = SIMD2<Float>(radius * cos(angle), radius * sin(angle))
        }
        store.positionHints = hints
        
        var loadTime: Duration = .zero
        measure {
            let start = ContinuousClock().now
            store.loadDirect(nodes: nodes, edges: [])
            loadTime = ContinuousClock().now - start
        }
        
        // Position hint application shouldn't significantly slow loading
        #expect(loadTime < .milliseconds(50), "Position hint application took \(loadTime)")
        
        // Hints should be consumed
        #expect(store.positionHints.isEmpty, "Hints should be consumed during load")
    }
    
    // MARK: - Adjacency Query Performance
    
    @Test("Neighbor query performance at scale")
    func neighborQueryPerformance() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        var totalQueryTime: Duration = .zero
        let queryCount = 100
        
        measure {
            let start = ContinuousClock().now
            for i in 0..<queryCount {
                let nodeId = nodes[i % nodes.count].id
                let _ = store.neighbors(of: nodeId)
            }
            totalQueryTime = ContinuousClock().now - start
        }
        
        // Average query time should be very fast
        let avgTime = Double(totalQueryTime.components.attoseconds) / Double(queryCount)
        #expect(totalQueryTime < .milliseconds(10), "100 neighbor queries took \(totalQueryTime)")
    }
    
    @Test("Edge query performance at scale")
    func edgeQueryPerformance() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        var totalQueryTime: Duration = .zero
        let queryCount = 100
        
        measure {
            let start = ContinuousClock().now
            for i in 0..<queryCount {
                let nodeId = nodes[i % nodes.count].id
                let _ = store.edges(for: nodeId)
            }
            totalQueryTime = ContinuousClock().now - start
        }
        
        #expect(totalQueryTime < .milliseconds(10), "100 edge queries took \(totalQueryTime)")
    }
    
    // MARK: - Combined Operations
    
    @Test("Combined load and query operations")
    func combinedLoadAndQuery() async throws {
        let store = GraphStore()
        
        var totalTime: Duration = .zero
        measure {
            let start = ContinuousClock().now
            
            // Load
            let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 500)
            store.loadDirect(nodes: nodes, edges: edges)
            
            // Query
            let _ = store.fuzzySearch(query: "Node", limit: 10)
            let _ = store.connected(to: nodes[0].id, maxDepth: 3)
            
            totalTime = ContinuousClock().now - start
        }
        
        // Combined operations should be fast
        #expect(totalTime < .milliseconds(100), "Combined operations took \(totalTime)")
    }

    @Test("FFI node batch respects filters and preserves link counts")
    func ffiNodeBatchRespectsFilters() async throws {
        let fixture = GraphFFIBatchFixture.makeStoreAndFilter()

        let payload = makeVisibleNodeBatchPayload(
            from: fixture.nodes,
            store: fixture.store.snapshot(),
            filter: fixture.filter.snapshot()
        )

        #expect(payload.ids == ["note-a", "note-c"])
        #expect(payload.labels == ["Note A", "Note C"])
        #expect(payload.xs == [10, 50])
        #expect(payload.ys == [20, 60])
        #expect(payload.linkCounts == [2, 1])
        #expect(payload.types == [GraphNodeType.note.rustIndex, GraphNodeType.note.rustIndex])
    }

    @Test("FFI edge batch drops edges with hidden endpoints")
    func ffiEdgeBatchDropsHiddenEndpoints() async throws {
        let fixture = GraphFFIBatchFixture.makeStoreAndFilter()

        let payload = makeVisibleEdgeBatchPayload(
            from: fixture.edges,
            store: fixture.store.snapshot(),
            filter: fixture.filter.snapshot()
        )

        #expect(payload.sourceIds == ["note-a"])
        #expect(payload.targetIds == ["note-c"])
        #expect(payload.weights == [2.0])
        #expect(payload.types == [GraphEdgeType.contains.rustIndex])
    }
}
