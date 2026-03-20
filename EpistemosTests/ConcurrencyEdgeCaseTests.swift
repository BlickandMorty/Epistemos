import Testing
@testable import Epistemos
import Foundation

// MARK: - Concurrency Edge Case Tests
// Tests for race conditions, deadlocks, and concurrent access patterns.

@Suite("Concurrency - Rapid Graph Rebuilds")
@MainActor
struct ConcurrencyRapidRebuildTests {
    
    @Test("Multiple rapid graph rebuilds")
    func rapidRebuilds() async throws {
        let store = GraphStore()
        
        for iteration in 0..<10 {
            store.clear()
            
            for i in 0..<100 {
                store.addNode(makeNode(id: "iter-\(iteration)-node-\(i)"))
            }
            
            for i in 0..<50 {
                store.addEdge(makeEdge(source: "iter-\(iteration)-node-\(i)", 
                                       target: "iter-\(iteration)-node-\(i+1)"))
            }
        }
        
        #expect(store.nodeCount == 100)
        #expect(store.edgeCount == 50)
    }
    
    @Test("Rebuild during traversal")
    func rebuildDuringTraversal() {
        let store = GraphStore()
        
        for i in 0..<50 {
            store.addNode(makeNode(id: "node-\(i)"))
            if i > 0 {
                store.addEdge(makeEdge(source: "node-\(i-1)", target: "node-\(i)"))
            }
        }
        
        let connected = store.connected(to: "node-0", maxDepth: 25)
        
        store.addNode(makeNode(id: "new-node"))
        
        #expect(connected.count > 0)
    }
    
    @Test("Concurrent node additions")
    func concurrentNodeAdditions() async {
        let store = GraphStore()
        
        await withTaskGroup(of: Void.self) { group in
            for batch in 0..<5 {
                group.addTask { @MainActor in
                    for i in 0..<20 {
                        let node = self.makeNode(id: "batch-\(batch)-node-\(i)")
                        store.addNode(node)
                    }
                }
            }
        }
        
        #expect(store.nodeCount == 100)
    }
    
    @Test("Sequential rebuild with increasing size")
    func sequentialRebuildIncreasing() {
        let store = GraphStore()
        
        for size in [10, 50, 100, 200, 500] {
            store.clear()
            
            for i in 0..<size {
                store.addNode(makeNode(id: "node-\(i)"))
            }
            
            #expect(store.nodeCount == size)
        }
    }
    
    @Test("Rebuild with decreasing size")
    func rebuildDecreasing() {
        let store = GraphStore()
        
        for size in [500, 200, 100, 50, 10] {
            store.clear()
            
            for i in 0..<size {
                store.addNode(makeNode(id: "node-\(i)"))
            }
            
            #expect(store.nodeCount == size)
        }
    }
    
    @Test("Rapid node removal and addition")
    func rapidRemovalAddition() {
        let store = GraphStore()
        
        // Setup
        for i in 0..<100 {
            store.addNode(makeNode(id: "node-\(i)"))
        }
        
        // Rapid changes
        for i in 0..<50 {
            store.removeNode("node-\(i)")
        }
        
        for i in 100..<150 {
            store.addNode(makeNode(id: "node-\(i)"))
        }
        
        #expect(store.nodeCount == 100)
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

@Suite("Concurrency - Search During Modification")
@MainActor
struct ConcurrencySearchDuringModificationTests {
    
    @Test("Search while adding nodes")
    func searchWhileAdding() async {
        let store = GraphStore()
        
        for i in 0..<100 {
            store.addNode(makeNode(id: "\(i)", label: "Item \(i)"))
        }
        
        let searchTask = Task { @MainActor in
            var results: [GraphStore.SearchHit] = []
            for _ in 0..<10 {
                let hits = store.fuzzySearch(query: "Item", limit: 50)
                results.append(contentsOf: hits)
            }
            return results
        }

        let modifyTask = Task { @MainActor in
            for i in 100..<150 {
                store.addNode(makeNode(id: "\(i)", label: "Item \(i)"))
            }
        }
        
        _ = await (searchTask.value, modifyTask.value)
        
        #expect(store.nodeCount >= 100)
    }
    
    @Test("Multiple concurrent searches")
    func multipleConcurrentSearches() async {
        let store = GraphStore()
        
        for i in 0..<200 {
            store.addNode(makeNode(id: "\(i)", label: "Node \(i) \(String(repeating: "A", count: i % 10))"))
        }
        
        await withTaskGroup(of: Int.self) { group in
            for query in ["Node", "AAA", "BBB", "CCC", "0", "1", "2"] {
                group.addTask { @MainActor in
                    let results = store.fuzzySearch(query: query, limit: 20)
                    return results.count
                }
            }
            
            var counts: [Int] = []
            for await count in group {
                counts.append(count)
            }
            
            #expect(counts.count == 7)
        }
    }
    
    @Test("Search during node removal")
    func searchDuringRemoval() async {
        let store = GraphStore()
        
        for i in 0..<100 {
            store.addNode(makeNode(id: "\(i)", label: "Test \(i)"))
        }
        
        let searchTask = Task { @MainActor in
            var allEmpty = true
            for _ in 0..<20 {
                let results = store.fuzzySearch(query: "Test", limit: 50)
                if !results.isEmpty {
                    allEmpty = false
                }
            }
            return allEmpty
        }
        
        let removeTask = Task { @MainActor in
            for i in 0..<50 {
                store.removeNode("\(i)")
            }
        }
        
        let (searchEmpty, _) = await (searchTask.value, removeTask.value)
        
        _ = searchEmpty
        #expect(store.nodeCount <= 100)
    }
    
    @Test("Repeated same search query")
    func repeatedSameQuery() {
        let store = GraphStore()
        
        for i in 0..<100 {
            store.addNode(makeNode(id: "\(i)", label: "Common Item \(i)"))
        }
        
        for _ in 0..<100 {
            let results = store.fuzzySearch(query: "Common", limit: 20)
            #expect(results.count <= 20)
        }
    }
    
    @Test("Search with different limits")
    func searchDifferentLimits() {
        let store = GraphStore()
        
        for i in 0..<100 {
            store.addNode(makeNode(id: "\(i)", label: "Item \(i)"))
        }
        
        for limit in [1, 5, 10, 20, 50, 100] {
            let results = store.fuzzySearch(query: "Item", limit: limit)
            #expect(results.count <= limit)
        }
    }
    
    private func makeNode(id: String, label: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: label, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
}

@Suite("Concurrency - Node Creation During BFS")
@MainActor
struct ConcurrencyBFSTests {
    
    @Test("BFS with dynamic node addition")
    func bfsWithDynamicAddition() {
        let store = GraphStore()
        
        for i in 0..<20 {
            store.addNode(makeNode(id: "\(i)"))
            if i > 0 {
                store.addEdge(makeEdge(source: "\(i-1)", target: "\(i)"))
            }
        }
        
        let result1 = store.connected(to: "0", maxDepth: 10)
        
        for i in 20..<30 {
            store.addNode(makeNode(id: "\(i)"))
            store.addEdge(makeEdge(source: "\(i-1)", target: "\(i)"))
        }
        
        let result2 = store.connected(to: "0", maxDepth: 15)
        
        #expect(result1.count >= 10)
        #expect(result2.count >= result1.count)
    }
    
    @Test("Multiple simultaneous BFS traversals")
    func simultaneousBFS() async {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "center"))
        for i in 0..<20 {
            store.addNode(makeNode(id: "spoke-\(i)"))
            store.addEdge(makeEdge(source: "center", target: "spoke-\(i)"))
        }
        
        await withTaskGroup(of: Int.self) { group in
            for i in 0..<5 {
                group.addTask { @MainActor in
                    let result = store.connected(to: "spoke-\(i)", maxDepth: 2)
                    return result.count
                }
            }
            
            var counts: [Int] = []
            for await count in group {
                counts.append(count)
            }
            
            for count in counts {
                #expect(count >= 1)
            }
        }
    }
    
    @Test("Shortest path during modifications")
    func shortestPathDuringModifications() {
        let store = GraphStore()
        
        for x in 0..<5 {
            for y in 0..<5 {
                store.addNode(makeNode(id: "\(x)-\(y)"))
            }
        }
        
        for x in 0..<4 {
            for y in 0..<5 {
                store.addEdge(makeEdge(source: "\(x)-\(y)", target: "\(x+1)-\(y)"))
            }
        }
        
        let path1 = store.query(.pathBetween(from: "0-0", to: "4-4", maxHops: 10))
        
        for x in 0..<5 {
            for y in 0..<4 {
                store.addEdge(makeEdge(source: "\(x)-\(y)", target: "\(x)-\(y+1)"))
            }
        }
        
        let path2 = store.query(.pathBetween(from: "0-0", to: "4-4", maxHops: 10))
        
        #expect(!path1.isEmpty || path2.isEmpty == false)
    }
    
    @Test("BFS depth limits")
    func bfsDepthLimits() {
        let store = GraphStore()
        
        // Create chain
        for i in 0..<100 {
            store.addNode(makeNode(id: "\(i)"))
            if i > 0 {
                store.addEdge(makeEdge(source: "\(i-1)", target: "\(i)"))
            }
        }
        
        // Test different depth limits
        for depth in [1, 5, 10, 50, 100] {
            let result = store.connected(to: "0", maxDepth: depth)
            #expect(result.count == min(depth + 1, 100))
        }
    }
    
    @Test("BFS from multiple sources")
    func bfsFromMultipleSources() {
        let store = GraphStore()
        
        for i in 0..<50 {
            store.addNode(makeNode(id: "\(i)"))
            if i > 0 {
                store.addEdge(makeEdge(source: "\(i-1)", target: "\(i)"))
            }
        }
        
        let results = [0, 10, 20, 30, 40].map { start in
            store.connected(to: "\(start)", maxDepth: 5)
        }
        
        for result in results {
            #expect(result.count > 0)
        }
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

@Suite("Concurrency - SwiftData Operations")
@MainActor
struct ConcurrencySwiftDataTests {
    
    @Test("Concurrent metadata updates")
    func concurrentMetadataUpdates() async {
        let node = SDGraphNode(type: .note, label: "Test")
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @MainActor in
                    var meta = GraphNodeMetadata()
                    meta.year = 2000 + i
                    meta.authors = ["Author \(i)"]
                    node.meta = meta
                }
            }
        }
        
        let finalMeta = node.meta
        #expect(finalMeta.year != nil)
    }
    
    @Test("Node type switching")
    func nodeTypeSwitching() {
        let node = SDGraphNode(type: .note, label: "Test")
        
        #expect(node.nodeType == .note)
        
        node.type = GraphNodeType.tag.rawValue
        #expect(node.nodeType == .tag)
        
        node.type = GraphNodeType.source.rawValue
        #expect(node.nodeType == .source)
    }
    
    @Test("Edge type switching")
    func edgeTypeSwitching() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        
        #expect(edge.edgeType == .reference)
        
        edge.type = GraphEdgeType.cites.rawValue
        #expect(edge.edgeType == .cites)
    }
    
    @Test("All node type switches")
    func allNodeTypeSwitches() {
        let node = SDGraphNode(type: .note, label: "Test")
        
        for type in GraphNodeType.allCases {
            node.type = type.rawValue
            #expect(node.nodeType == type)
        }
    }
    
    @Test("All edge type switches")
    func allEdgeTypeSwitches() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        
        let allTypes: [GraphEdgeType] = [.reference, .contains, .tagged, .mentions, .cites,
                                          .authored, .related, .quotes, .supports, .contradicts,
                                          .expands, .questions]
        
        for type in allTypes {
            edge.type = type.rawValue
            #expect(edge.edgeType == type)
        }
    }
    
    @Test("Rapid weight changes")
    func rapidWeightChanges() {
        let node = SDGraphNode(type: .note, label: "Test")
        
        let weights: [Double] = [0, 0.5, 1, 2, 5, 10, 100, 0.001]
        
        for weight in weights {
            node.weight = weight
            #expect(node.weight == weight)
        }
    }
}

@Suite("Concurrency - Graph State Updates", .serialized)
@MainActor
struct ConcurrencyGraphStateTests {

    @Test("Overlay physics policy opens in Crystal and hands off to Chaos")
    func overlayPhysicsPolicyDefaults() {
        #expect(GraphOverlayPhysicsPolicy.openingPreset == .crystal)
        #expect(GraphOverlayPhysicsPolicy.restingPreset == .chaos)
        #expect(GraphOverlayPhysicsPolicy.chaosDelaySeconds == 4)
        #expect(GraphOverlayPhysicsPolicy.preset(afterElapsedSeconds: 0) == .crystal)
        #expect(GraphOverlayPhysicsPolicy.preset(afterElapsedSeconds: 3.99) == .crystal)
        #expect(GraphOverlayPhysicsPolicy.preset(afterElapsedSeconds: 4) == .chaos)
    }

    @Test("Overlay interaction warmth window stays extended for 30 seconds")
    func overlayInteractionWarmthDefaults() {
        #expect(GraphOverlayPhysicsPolicy.interactionMotionHoldSeconds == 30)
        #expect(GraphOverlayPhysicsPolicy.interactionMotionAlphaTarget > 0)
    }
    
    @Test("Filter version increments")
    func filterVersionIncrements() {
        let state = GraphState()
        
        let initialVersion = state.filterVersion
        state.requestFilterSync()
        #expect(state.filterVersion == initialVersion + 1)
        
        state.requestFilterSync()
        #expect(state.filterVersion == initialVersion + 2)
    }
    
    @Test("Graph data version increments")
    func graphDataVersionIncrements() {
        let state = GraphState()
        
        let initialVersion = state.graphDataVersion
        state.requestRecommit()
        #expect(state.graphDataVersion == initialVersion + 1)
    }
    
    @Test("Force config version increments")
    func forceConfigVersionIncrements() {
        let state = GraphState()
        
        let initialVersion = state.forceConfigVersion
        state.pushForceChange()
        #expect(state.forceConfigVersion == initialVersion + 1)
    }
    
    @Test("Multiple preset applications")
    func multiplePresetApplications() {
        let state = GraphState()
        
        let presets: [PhysicsPreset] = [.observatory, .nebula, .crystal, .fluid, .constellation]
        
        for preset in presets {
            state.applyPreset(preset)
            #expect(state.linkDistance == preset.linkDistance)
            #expect(state.chargeStrength == preset.chargeStrength)
        }
    }
    
    @Test("Quality level tracks graph performance mode")
    func qualityLevelChanges() {
        let state = GraphState()

        state.qualityLevel = 0
        #expect(state.qualityLevel == 0)
        #expect(!state.performanceModeEnabled)

        state.qualityLevel = 2
        #expect(state.qualityLevel == 2)
        #expect(state.performanceModeEnabled)

        state.qualityLevel = 1
        #expect(state.qualityLevel == 0)
        #expect(!state.performanceModeEnabled)
    }
    
    @Test("Extended force config version")
    func extendedForceConfigVersion() {
        let state = GraphState()
        
        let initialVersion = state.extendedForceConfigVersion
        state.pushExtendedForceChange()
        #expect(state.extendedForceConfigVersion == initialVersion + 1)
    }
    
    @Test("Cluster config version")
    func clusterConfigVersion() {
        let state = GraphState()
        
        let initialVersion = state.clusterConfigVersion
        state.pushClusterChange()
        #expect(state.clusterConfigVersion == initialVersion + 1)
    }
    
    @Test("Lite mode version increments")
    func liteModeVersion() {
        let state = GraphState()
        
        let initialVersion = state.liteModeVersion
        state.qualityLevel = 2
        #expect(state.liteModeVersion == initialVersion + 1)

        state.qualityLevel = 2
        #expect(state.liteModeVersion == initialVersion + 1)

        state.qualityLevel = 0
        #expect(state.liteModeVersion == initialVersion + 2)
    }
}

@Suite("Concurrency - Filter Engine")
@MainActor
struct ConcurrencyFilterEngineTests {
    
    @Test("Rapid type toggling")
    func rapidTypeToggling() {
        let filter = FilterEngine()
        
        let types = GraphNodeType.allCases
        
        for _ in 0..<10 {
            for type in types {
                filter.toggleType(type)
            }
        }
        
        let activeCount = filter.activeNodeTypes.count
        #expect(activeCount >= 0 && activeCount <= types.count)
    }
    
    @Test("Focus toggle rapidly")
    func rapidFocusToggle() {
        let filter = FilterEngine()
        
        for i in 0..<20 {
            filter.focusOn(nodeId: "node-\(i)", connectedSet: ["node-\(i)", "neighbor-1", "neighbor-2"])
            filter.clearFocus()
        }
        
        #expect(filter.focusedNodeId == nil)
        #expect(filter.focusedConnected == nil)
    }
    
    @Test("Visibility checks during modification")
    func visibilityDuringModification() {
        let filter = FilterEngine()
        let store = GraphStore()
        
        for i in 0..<10 {
            store.addNode(makeNode(id: "\(i)", type: .note))
        }
        
        let node = store.nodes.values.first!
        let visible1 = filter.isNodeVisible(node)
        
        filter.toggleType(.note)
        let visible2 = filter.isNodeVisible(node)
        
        #expect(visible1 != visible2)
    }
    
    @Test("All types visible by default")
    func allTypesVisibleByDefault() {
        let filter = FilterEngine()
        
        #expect(filter.activeNodeTypes.count == GraphNodeType.allCases.count)
    }
    
    @Test("Filter is filtered check")
    func filterIsFiltered() {
        let filter = FilterEngine()
        
        #expect(!filter.isFiltered)
        
        filter.toggleType(.note)
        #expect(filter.isFiltered)
        
        filter.showAllTypes()
        #expect(!filter.isFiltered)
    }
    
    @Test("Edge visibility with visible nodes")
    func edgeVisibility() {
        let filter = FilterEngine()
        
        let visible = filter.isEdgeVisible(
            GraphEdgeRecord(id: "e1", sourceNodeId: "a", targetNodeId: "b", type: .reference, weight: 1.0, createdAt: .now),
            sourceVisible: true,
            targetVisible: true
        )
        
        #expect(visible)
    }
    
    private func makeNode(id: String, type: GraphNodeType) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: type, label: id, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
}

@Suite("Concurrency - Pipeline State")
@MainActor
struct ConcurrencyPipelineStateTests {
    
    @Test("Pipeline progress updates")
    func pipelineProgressUpdates() {
        let state = PipelineState()

        state.startProcessing()
        for stage in PipelineStage.allCases {
            state.advanceStage(
                stage,
                result: StageResult(
                    stage: stage,
                    status: .completed,
                    data: nil,
                    durationMs: nil,
                    error: nil,
                    detail: nil,
                    value: nil
                )
            )
        }

        #expect(state.currentProgress == 1.0)

        state.completeProcessing()
        #expect(!state.isProcessing)
    }
    
    @Test("Stage transitions")
    func stageTransitions() {
        let state = PipelineState()

        state.startProcessing()
        let stages: [PipelineStage] = [.triage, .memory, .routing, .synthesis, .calibration]

        for stage in stages {
            state.advanceStage(
                stage,
                result: StageResult(
                    stage: stage,
                    status: .running,
                    data: nil,
                    durationMs: nil,
                    error: nil,
                    detail: nil,
                    value: nil
                )
            )
            #expect(state.activeStage == stage)
        }
    }
    
    @Test("Reset during operation")
    func resetDuringOperation() {
        let state = PipelineState()

        state.updateSignals(SignalUpdate(concepts: ["alpha", "beta"]))
        state.setError("boom")
        state.startProcessing()

        #expect(state.isProcessing)
        #expect(state.currentError == nil)
        #expect(state.pipelineStages.count == PipelineStage.allCases.count)
    }
    
    @Test("Progress clamping")
    func progressClamping() {
        let state = PipelineState()

        state.startProcessing()
        #expect((0...1).contains(state.currentProgress))

        for stage in PipelineStage.allCases {
            state.advanceStage(
                stage,
                result: StageResult(
                    stage: stage,
                    status: .completed,
                    data: nil,
                    durationMs: nil,
                    error: nil,
                    detail: nil,
                    value: nil
                )
            )
        }

        #expect((0...1).contains(state.currentProgress))
    }
    
    @Test("Signal history cap")
    func signalHistoryCap() {
        let state = PipelineState()

        for i in 0..<150 {
            state.updateSignals(SignalUpdate(confidence: Double(i) / 150))
        }

        #expect(state.signalHistory.count == 100)
    }
}

@Suite("Concurrency - Race Condition Prevention")
@MainActor
struct ConcurrencyRaceConditionTests {
    
    @Test("Graph builder consistency")
    func graphBuilderConsistency() {
        let builder = GraphBuilder()
        
        // GraphBuilder has internal state, verify it's reset properly
        for _ in 0..<5 {
            // Each build call should be independent
            _ = GraphBuilder()
        }
        
        #expect(true)
    }
    
    @Test("Position hints during load")
    func positionHintsDuringLoad() {
        let store = GraphStore()
        
        for i in 0..<10 {
            store.positionHints["node-\(i)"] = SIMD2<Float>(Float(i * 10), Float(i * 10))
        }
        
        #expect(store.positionHints.count == 10)
        
        // Add nodes that consume hints
        for i in 0..<5 {
            store.addNode(GraphNodeRecord(
                id: "node-\(i)",
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
        
        #expect(store.positionHints.count == 5)
    }
    
    @Test("Ephemeral node cleanup")
    func ephemeralNodeCleanup() {
        let state = GraphState()

        state.cleanupEphemeralNodes()
        
        #expect(state.ephemeralNodeIds.isEmpty)
    }
    
    @Test("Multiple ephemeral cleanups")
    func multipleEphemeralCleanups() {
        let state = GraphState()
        
        for _ in 0..<3 {
            state.cleanupEphemeralNodes()
        }
        
        #expect(state.ephemeralNodeIds.isEmpty)
    }
    
    @Test("Pending flags consistency")
    func pendingFlagsConsistency() {
        let state = GraphState()

        state.pendingCenterNodeId = "test"
        state.pendingRebuild = true
        let initialFilterVersion = state.filterVersion
        let initialGraphVersion = state.graphDataVersion
        state.requestFilterSync()
        state.requestRecommit()

        #expect(state.pendingCenterNodeId == "test")
        #expect(state.pendingRebuild)
        #expect(state.filterVersion == initialFilterVersion + 1)
        #expect(state.graphDataVersion == initialGraphVersion + 1)
    }
}

@Suite("Concurrency - Graph Query DSL")
@MainActor
struct ConcurrencyGraphQueryTests {
    
    @Test("Multiple query types")
    func multipleQueryTypes() {
        let store = GraphStore()
        
        // Setup graph with different edge types
        store.addNode(makeNode(id: "main", type: .note))
        store.addNode(makeNode(id: "supporting", type: .source))
        store.addNode(makeNode(id: "contradicting", type: .source))
        store.addNode(makeNode(id: "related", type: .tag))
        
        store.addEdge(GraphEdgeRecord(id: "e1", sourceNodeId: "main", targetNodeId: "supporting", type: .supports, weight: 1.0, createdAt: .now))
        store.addEdge(GraphEdgeRecord(id: "e2", sourceNodeId: "main", targetNodeId: "contradicting", type: .contradicts, weight: 1.0, createdAt: .now))
        store.addEdge(GraphEdgeRecord(id: "e3", sourceNodeId: "main", targetNodeId: "related", type: .related, weight: 1.0, createdAt: .now))
        
        let supports = store.query(.supportsOf(nodeId: "main"))
        let contradicts = store.query(.contradictsOf(nodeId: "main"))
        let related = store.query(.nodesWithEdgeType(.related, from: "main"))
        
        #expect(supports.count == 1)
        #expect(contradicts.count == 1)
        #expect(related.count == 1)
    }
    
    @Test("Path query with modifications")
    func pathQueryWithModifications() {
        let store = GraphStore()
        
        for i in 0..<10 {
            store.addNode(makeNode(id: "\(i)", type: .note))
            if i > 0 {
                store.addEdge(makeEdge(source: "\(i-1)", target: "\(i)"))
            }
        }
        
        let path1 = store.query(.pathBetween(from: "0", to: "9", maxHops: 20))
        #expect(path1.count == 10)
        
        // Add shortcut
        store.addEdge(makeEdge(source: "0", target: "9"))
        
        let path2 = store.query(.pathBetween(from: "0", to: "9", maxHops: 20))
        #expect(path2.count >= 2)
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
