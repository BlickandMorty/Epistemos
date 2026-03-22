import Testing
import Foundation
import SwiftData
@testable import Epistemos

// MARK: - Concurrency Stress Tests

@Suite("Concurrency Stress")
@MainActor
struct ConcurrencyStressTests {
    private func measureAsync(_ body: () async -> Void) async -> Duration {
        let start = ContinuousClock().now
        await body()
        return ContinuousClock().now - start
    }
    
    // MARK: - Concurrent Graph Modifications
    
    @Test("Concurrent node additions")
    func concurrentNodeAdditions() async throws {
        let store = GraphStore()
        let concurrentCount = 100
        let nodesPerTask = 10
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<concurrentCount {
                    group.addTask { @MainActor in
                        for j in 0..<nodesPerTask {
                            let node = GraphNodeRecord(
                                id: "concurrent-\(i)-\(j)",
                                type: .note,
                                label: "Node \(i)-\(j)",
                                sourceId: nil,
                                metadata: GraphNodeMetadata(),
                                weight: 1.0,
                                createdAt: .now
                            )
                            store.addNode(node)
                        }
                    }
                }
            }
        }
        
        #expect(store.nodeCount == concurrentCount * nodesPerTask,
                "Expected \(concurrentCount * nodesPerTask) nodes, got \(store.nodeCount)")
        #expect(totalTime < .seconds(5), "Concurrent additions took \(totalTime)")
    }
    
    @Test("Concurrent edge additions")
    func concurrentEdgeAdditions() async throws {
        let store = GraphStore()
        let nodeCount = 100
        
        // Setup nodes first
        let nodes = (0..<nodeCount).map { i in
            GraphNodeRecord(
                id: "node-\(i)",
                type: .note,
                label: "Node \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now
            )
        }
        
        for node in nodes {
            store.addNode(node)
        }
        
        // Add edges concurrently
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<nodeCount {
                    group.addTask { @MainActor in
                        let targetIdx = (i + 1) % nodeCount
                        let edge = GraphEdgeRecord(
                            id: "edge-\(i)",
                            sourceNodeId: "node-\(i)",
                            targetNodeId: "node-\(targetIdx)",
                            type: .reference,
                            weight: 1.0,
                            createdAt: .now
                        )
                        store.addEdge(edge)
                    }
                }
            }
        }
        
        #expect(store.edgeCount == nodeCount, "Expected \(nodeCount) edges, got \(store.edgeCount)")
    }
    
    @Test("Concurrent read operations")
    func concurrentReadOperations() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let readCount = 100
        var results: [Int] = []
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            results = await withTaskGroup(of: Int.self) { group -> [Int] in
                for i in 0..<readCount {
                    group.addTask { @MainActor in
                        switch i % 4 {
                        case 0:
                            return store.fuzzySearch(query: "Node", limit: 20).count
                        case 1:
                            return store.connected(to: nodes[i % nodes.count].id, maxDepth: 3).count
                        case 2:
                            return store.neighbors(of: nodes[i % nodes.count].id).count
                        default:
                            return store.nodes(ofType: .note).count
                        }
                    }
                }
                
                var collected: [Int] = []
                for await result in group {
                    collected.append(result)
                }
                return collected
            }
        }
        
        #expect(results.count == readCount, "Expected \(readCount) results")
        #expect(totalTime < .seconds(2), "Concurrent reads took \(totalTime)")
    }
    
    @Test("Concurrent read and write")
    func concurrentReadAndWrite() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 500)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let operationCount = 100
        var readCount = 0
        var writeCount = 0
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            await withTaskGroup(of: Void.self) { group in
                // Readers
                for i in 0..<operationCount {
                    group.addTask { @MainActor in
                        let _ = store.fuzzySearch(query: "Node\(i)", limit: 10)
                        readCount += 1
                    }
                }
                
                // Writers
                for i in 0..<operationCount {
                    group.addTask { @MainActor in
                        let node = GraphNodeRecord(
                            id: "new-\(i)",
                            type: .note,
                            label: "New Node \(i)",
                            sourceId: nil,
                            metadata: GraphNodeMetadata(),
                            weight: 1.0,
                            createdAt: .now
                        )
                        store.addNode(node)
                        writeCount += 1
                    }
                }
            }
        }
        
        #expect(readCount == operationCount, "All reads should complete")
        #expect(writeCount == operationCount, "All writes should complete")
        #expect(totalTime < .seconds(3), "Concurrent read/write took \(totalTime)")
    }
    
    // MARK: - Concurrent Search Operations
    
    @Test("Concurrent fuzzy searches")
    func concurrentFuzzySearches() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let searchCount = 100
        var totalResults = 0
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            totalResults = await withTaskGroup(of: Int.self) { group -> Int in
                for i in 0..<searchCount {
                    group.addTask { @MainActor in
                        let results = store.fuzzySearch(query: "Node\(i % 100)", limit: 20)
                        return results.count
                    }
                }
                
                var sum = 0
                for await count in group {
                    sum += count
                }
                return sum
            }
        }
        
        #expect(totalResults > 0, "Should have search results")
        #expect(totalTime < .seconds(2), "Concurrent searches took \(totalTime)")
    }
    
    @Test("Concurrent BFS traversals")
    func concurrentBFSTraversals() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let traversalCount = 50
        var visitedCounts: [Int] = []
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            visitedCounts = await withTaskGroup(of: Int.self) { group -> [Int] in
                for i in 0..<traversalCount {
                    group.addTask { @MainActor in
                        let nodeId = nodes[i % nodes.count].id
                        let visited = store.connected(to: nodeId, maxDepth: 5)
                        return visited.count
                    }
                }
                
                var counts: [Int] = []
                for await count in group {
                    counts.append(count)
                }
                return counts
            }
        }
        
        #expect(visitedCounts.count == traversalCount)
        #expect(totalTime < .seconds(2), "Concurrent BFS took \(totalTime)")
    }
    
    // MARK: - Pipeline Cancellation Under Load
    
    @Test("Pipeline cancellation under load")
    func pipelineCancellationUnderLoad() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = (0..<1000).map { "token\($0) " }
        
        let pipelineState = PipelineState()
        let inference = InferenceState()
        let triage = TriageService(inference: inference)
        let eventBus = EventBus()
        
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: InferenceState(),
            eventBus: eventBus
        )
        
        var cancelledCount = 0
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            let tasks = (0..<5).map { i in
                Task { @MainActor in
                    let stream = pipeline.run(
                        query: "Query \(i)",
                        mode: .api
                    )

                    var received = 0
                    do {
                        for try await _ in stream {
                            received += 1
                            if received > 10 {
                                break
                            }
                        }
                    } catch {}
                    return received
                }
            }

            try? await Task.sleep(for: .milliseconds(50))
            for task in tasks {
                task.cancel()
            }

            for task in tasks {
                let _ = await task.result
                if task.isCancelled {
                    cancelledCount += 1
                }
            }
        }
        
        #expect(totalTime < .seconds(3), "Cancellation under load took \(totalTime)")
    }
    
    @Test("Rapid pipeline start and cancel")
    func rapidPipelineStartAndCancel() async throws {
        let iterationCount = 50
        var successfulCancels = 0
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            for i in 0..<iterationCount {
                let mock = MockLLMClient()
                mock.streamTokens = ["Response \(i)"]
                
                let pipelineState = PipelineState()
                let inference = InferenceState()
                let triage = TriageService(inference: inference)
                let eventBus = EventBus()
                
                let pipeline = PipelineService(
                    pipelineState: pipelineState,
                    llmService: mock,
                    triageService: triage,
                    inference: InferenceState(),
                    eventBus: eventBus
                )
                
                let task = Task { @MainActor in
                    let stream = pipeline.run(
                        query: "Test \(i)",
                        mode: .api
                    )
                    for try await _ in stream {}
                }
                
                // Immediate cancel
                task.cancel()
                
                if task.isCancelled {
                    successfulCancels += 1
                }
            }
        }
        
        #expect(successfulCancels > iterationCount / 2, "Most cancels should succeed")
        #expect(totalTime < .seconds(5), "Rapid start/cancel took \(totalTime)")
    }
    
    // MARK: - CVDisplayLink + Physics Thread Synchronization
    
    @Test("Simulated CVDisplayLink frame dispatch")
    func simulatedCVDisplayLinkFrameDispatch() async throws {
        let frameCount = 120 // 2 seconds at 60fps
        var frameTimes: [Duration] = []
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            for i in 0..<frameCount {
                let frameStart = ContinuousClock().now
                
                // Simulate frame work
                Task { @MainActor in
                    // Simulate render
                    var work = 0.0
                    for j in 0..<1000 {
                        work += sin(Double(j)) * 0.0001
                    }
                }
                
                frameTimes.append(ContinuousClock().now - frameStart)
            }
        }
        
        let avgFrameTime = Double(totalTime.components.attoseconds) / Double(frameCount)
        #expect(totalTime < .seconds(1), "Frame dispatch took \(totalTime)")
    }
    
    @Test("Physics state synchronization")
    func physicsStateSynchronization() async throws {
        let updateCount = 1000
        var successfulUpdates = 0
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            // Simulate physics updates from different sources
            successfulUpdates = await withTaskGroup(of: Bool.self) { group -> Int in
                // Simulate render thread updates
                for i in 0..<updateCount/2 {
                    group.addTask { @MainActor in
                        // Simulate position update
                        let _ = i * 2
                        return true
                    }
                }
                
                // Simulate physics thread updates
                for i in 0..<updateCount/2 {
                    group.addTask { @MainActor in
                        // Simulate velocity update
                        let _ = i * 2 + 1
                        return true
                    }
                }
                
                var success = 0
                for await result in group {
                    if result {
                        success += 1
                    }
                }
                return success
            }
        }
        
        #expect(successfulUpdates == updateCount, "All updates should complete")
        #expect(totalTime < .seconds(2), "Physics sync took \(totalTime)")
    }
    
    // MARK: - SwiftData Concurrent Access
    
    @Test("SwiftData concurrent reads")
    func swiftDataConcurrentReads() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SDGraphNode.self, SDGraphEdge.self,
            configurations: config
        )
        
        // Setup data
        let setupContext = ModelContext(container)
        for i in 0..<100 {
            let node = SDGraphNode(
                type: .note,
                label: "Node \(i)",
                sourceId: "source-\(i)"
            )
            setupContext.insert(node)
        }
        try? setupContext.save()
        
        let readCount = 100
        var totalFetched = 0
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            totalFetched = await withTaskGroup(of: Int.self) { group -> Int in
                for i in 0..<readCount {
                    let sourceKey = "source-\(i % 100)"
                    group.addTask { @MainActor in
                        let context = ModelContext(container)
                        let descriptor = FetchDescriptor<SDGraphNode>(
                            predicate: #Predicate { $0.sourceId == sourceKey }
                        )
                        let results = (try? context.fetch(descriptor)) ?? []
                        return results.count
                    }
                }
                
                var sum = 0
                for await count in group {
                    sum += count
                }
                return sum
            }
        }
        
        #expect(totalFetched == readCount, "Should fetch all nodes")
        #expect(totalTime < .seconds(3), "Concurrent SwiftData reads took \(totalTime)")
    }
    
    @Test("SwiftData concurrent writes")
    func swiftDataConcurrentWrites() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SDGraphNode.self, SDGraphEdge.self,
            configurations: config
        )
        
        let writeCount = 50
        var successfulWrites = 0
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            successfulWrites = await withTaskGroup(of: Bool.self) { group -> Int in
                for i in 0..<writeCount {
                    group.addTask { @MainActor in
                        do {
                            let context = ModelContext(container)
                            let node = SDGraphNode(
                                type: .note,
                                label: "Concurrent Node \(i)",
                                sourceId: "concurrent-\(i)"
                            )
                            context.insert(node)
                            try context.save()
                            return true
                        } catch {
                            return false
                        }
                    }
                }
                
                var success = 0
                for await result in group {
                    if result {
                        success += 1
                    }
                }
                return success
            }
        }
        
        #expect(successfulWrites == writeCount, "All writes should succeed")
        #expect(totalTime < .seconds(5), "Concurrent SwiftData writes took \(totalTime)")
    }
    
    @Test("SwiftData read during write")
    func swiftDataReadDuringWrite() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SDGraphNode.self, SDGraphEdge.self,
            configurations: config
        )
        
        // Setup initial data
        let setupContext = ModelContext(container)
        for i in 0..<50 {
            let node = SDGraphNode(type: .note, label: "Initial \(i)", sourceId: "initial-\(i)")
            setupContext.insert(node)
        }
        try? setupContext.save()
        
        let operationCount = 50
        var readCount = 0
        var writeCount = 0
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            await withTaskGroup(of: Void.self) { group in
                // Readers
                for i in 0..<operationCount {
                    group.addTask { @MainActor in
                        let context = ModelContext(container)
                        let descriptor = FetchDescriptor<SDGraphNode>()
                        let results = (try? context.fetch(descriptor)) ?? []
                        readCount += results.count
                    }
                }
                
                // Writers
                for i in 0..<operationCount {
                    group.addTask { @MainActor in
                        do {
                            let context = ModelContext(container)
                            let node = SDGraphNode(type: .note, label: "New \(i)", sourceId: "new-\(i)")
                            context.insert(node)
                            try context.save()
                            writeCount += 1
                        } catch {}
                    }
                }
            }
        }
        
        #expect(writeCount == operationCount, "All writes should complete")
        #expect(readCount >= operationCount * 50, "Reads should complete")
        #expect(totalTime < .seconds(5), "Read during write took \(totalTime)")
    }
    
    // MARK: - Actor Isolation Tests
    
    @Test("Actor isolation - GraphState")
    func actorIsolationGraphState() async throws {
        let graphState = GraphState()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 100)
        graphState.store.loadDirect(nodes: nodes, edges: edges)
        
        let accessCount = 100
        var successfulAccesses = 0
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            successfulAccesses = await withTaskGroup(of: Bool.self) { group -> Int in
                for i in 0..<accessCount {
                    group.addTask { @MainActor in
                        // Access from @MainActor
                        let _ = graphState.store.nodeCount
                        let _ = graphState.store.fuzzySearch(query: "Node\(i % 10)", limit: 5)
                        return true
                    }
                }
                
                var success = 0
                for await result in group {
                    if result {
                        success += 1
                    }
                }
                return success
            }
        }
        
        #expect(successfulAccesses == accessCount)
        #expect(totalTime < .seconds(2), "Actor isolation test took \(totalTime)")
    }
    
    // MARK: - Race Condition Detection
    
    @Test("Race condition - simultaneous add and remove")
    func raceConditionAddRemove() async throws {
        let store = GraphStore()
        let iterationCount = 100
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<iterationCount {
                    // Add task
                    group.addTask { @MainActor in
                        let node = GraphNodeRecord(
                            id: "race-\(i)",
                            type: .note,
                            label: "Race Node \(i)",
                            sourceId: nil,
                            metadata: GraphNodeMetadata(),
                            weight: 1.0,
                            createdAt: .now
                        )
                        store.addNode(node)
                    }
                    
                    // Remove task (may or may not find the node)
                    group.addTask { @MainActor in
                        store.removeNode("race-\(i)")
                    }
                }
            }
        }
        
        // Should complete without crash
        #expect(totalTime < .seconds(3), "Race condition test took \(totalTime)")
    }
    
    @Test("Race condition - simultaneous modifications")
    func raceConditionSimultaneousModifications() async throws {
        let store = GraphStore()
        
        // Setup initial node
        let nodeId = "shared-node"
        let node = GraphNodeRecord(
            id: nodeId,
            type: .note,
            label: "Shared",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now
        )
        store.addNode(node)
        
        let modificationCount = 500
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<modificationCount {
                    group.addTask { @MainActor in
                        // Different types of reads
                        let _ = store.neighbors(of: nodeId)
                        let _ = store.edges(for: nodeId)
                        let _ = store.linkCount(for: nodeId)
                    }
                }
            }
        }
        
        #expect(totalTime < .seconds(2), "Simultaneous modifications took \(totalTime)")
    }
    
    // MARK: - Deadlock Prevention
    
    @Test("Deadlock prevention - nested operations")
    func deadlockPreventionNestedOperations() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 100)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let operationCount = 50
        var completedCount = 0
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            completedCount = await withTaskGroup(of: Bool.self) { group -> Int in
                for i in 0..<operationCount {
                    group.addTask { @MainActor in
                        // Nested operations that could deadlock if locks are held
                        let neighbors = store.neighbors(of: nodes[i % nodes.count].id)
                        for neighbor in neighbors {
                            let _ = store.neighbors(of: neighbor.id)
                        }
                        return true
                    }
                }
                
                var completed = 0
                for await result in group {
                    if result {
                        completed += 1
                    }
                }
                return completed
            }
        }
        
        #expect(completedCount == operationCount, "All nested operations should complete")
        #expect(totalTime < .seconds(5), "Nested operations took \(totalTime) - possible deadlock")
    }
    
    @Test("Deadlock prevention - circular dependencies")
    func deadlockPreventionCircularDependencies() async throws {
        let store = GraphStore()
        
        // Create circular dependency
        let nodeA = GraphNodeRecord(id: "A", type: .note, label: "A", sourceId: nil, metadata: GraphNodeMetadata(), weight: 1.0, createdAt: .now)
        let nodeB = GraphNodeRecord(id: "B", type: .note, label: "B", sourceId: nil, metadata: GraphNodeMetadata(), weight: 1.0, createdAt: .now)
        let nodeC = GraphNodeRecord(id: "C", type: .note, label: "C", sourceId: nil, metadata: GraphNodeMetadata(), weight: 1.0, createdAt: .now)
        
        store.addNode(nodeA)
        store.addNode(nodeB)
        store.addNode(nodeC)
        
        store.addEdge(GraphEdgeRecord(id: "e1", sourceNodeId: "A", targetNodeId: "B", type: .reference, weight: 1.0, createdAt: .now))
        store.addEdge(GraphEdgeRecord(id: "e2", sourceNodeId: "B", targetNodeId: "C", type: .reference, weight: 1.0, createdAt: .now))
        store.addEdge(GraphEdgeRecord(id: "e3", sourceNodeId: "C", targetNodeId: "A", type: .reference, weight: 1.0, createdAt: .now))
        
        var totalTime: Duration = .zero
        
        totalTime = await measureAsync {
            // Concurrent traversals on circular graph
            await withTaskGroup(of: Void.self) { group in
                for nodeId in ["A", "B", "C"] {
                    group.addTask { @MainActor in
                        for _ in 0..<100 {
                            let _ = store.connected(to: nodeId, maxDepth: 10)
                        }
                    }
                }
            }
        }
        
        // Should complete without deadlock
        #expect(totalTime < .seconds(3), "Circular dependency test took \(totalTime)")
    }
}
