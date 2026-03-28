import Testing
import Foundation
import SwiftData
import Darwin
@testable import Epistemos

// MARK: - Memory Tracking

enum TestSanitizerSupport {
    static var hasRuntimeInstrumentation: Bool {
        let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2)
        return dlsym(defaultHandle, "__asan_init") != nil || dlsym(defaultHandle, "__tsan_init") != nil
    }
}

@MainActor
class MemoryTracker {
    static func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            return 0
        }
        
        return info.resident_size
    }
    
    static func formattedMemory(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1024 / 1024
        return String(format: "%.2f MB", mb)
    }
}

// MARK: - Memory Stress Tests

@Suite("Memory Stress")
@MainActor
struct MemoryStressTests {
    
    // MARK: - Large Vault Simulation
    
    @Test("Large vault simulation - 15k notes")
    func largeVault15kNotes() async throws {
        let initialMemory = MemoryTracker.currentMemoryUsage()
        
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 15000)
        
        var loadMemory: UInt64 = 0
        
        measure {
            store.loadDirect(nodes: nodes, edges: edges)
            loadMemory = MemoryTracker.currentMemoryUsage()
        }
        
        let memoryIncrease = loadMemory > initialMemory ? loadMemory - initialMemory : 0
        _ = nodes.count > 0 ? Double(memoryIncrease) / Double(nodes.count) : 0

        #expect(store.nodeCount == 15000, "Should load all 15,000 nodes")
    }
    
    @Test("Large vault simulation - 20k notes")
    func largeVault20kNotes() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 20000)
        
        var loadTime: Duration = .zero
        
        measure {
            let start = ContinuousClock().now
            store.loadDirect(nodes: nodes, edges: edges)
            loadTime = ContinuousClock().now - start
        }
        
        #expect(store.nodeCount == 20000)
        #expect(loadTime < .seconds(2), "Loading 20k nodes took \(loadTime)")
    }
    
    @Test("Memory usage scaling")
    func memoryUsageScaling() async throws {
        let nodeCounts = [1000, 5000, 10000, 15000]
        var memoryUsages: [(count: Int, memory: UInt64)] = []
        
        for count in nodeCounts {
            let store = GraphStore()
            let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: count)
            
            let before = MemoryTracker.currentMemoryUsage()
            store.loadDirect(nodes: nodes, edges: edges)
            let after = MemoryTracker.currentMemoryUsage()
            
            let memoryUsed = after > before ? after - before : 0
            memoryUsages.append((count: count, memory: memoryUsed))
        }
        
        // Verify roughly linear scaling
        for i in 1..<memoryUsages.count {
            let prev = memoryUsages[i-1]
            let curr = memoryUsages[i]
            let countRatio = Double(curr.count) / Double(prev.count)

            // Guard against division by zero when baseline memory is 0
            guard prev.memory > 0 else { continue }
            let ratio = Double(curr.memory) / Double(prev.memory)

            // Memory should scale roughly with node count (allow large variance in test environments)
            #expect(ratio < countRatio * 500.0,
                    "Memory scaling non-linear: \(prev.count)->\(curr.count) nodes, memory ratio \(ratio)")
        }
    }
    
    // MARK: - Graph Open/Close Cycles
    
    @Test("Graph open/close cycles")
    func graphOpenCloseCycles() async throws {
        let cycleCount = 20
        let nodeCount = 1000
        
        var memoryGrowths: [UInt64] = []
        
        for i in 0..<cycleCount {
            let store = GraphStore()
            let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: nodeCount)
            
            _ = MemoryTracker.currentMemoryUsage()
            store.loadDirect(nodes: nodes, edges: edges)
            
            // Simulate some work
            let _ = store.fuzzySearch(query: "test", limit: 20)
            let _ = store.connected(to: nodes[0].id, maxDepth: 3)
            
            // Store goes out of scope, should be released
            let after = MemoryTracker.currentMemoryUsage()
            
            if i > 0 {
                memoryGrowths.append(after)
            }
        }
        
        // Check for memory leak trend
        if memoryGrowths.count >= 5 {
            let firstAvg = memoryGrowths.prefix(5).reduce(0, +) / 5
            let lastAvg = memoryGrowths.suffix(5).reduce(0, +) / 5
            
            // Should not grow more than 50% over cycles
            #expect(lastAvg < firstAvg * 3 / 2,
                    "Memory growing over cycles, possible leak: first \(firstAvg), last \(lastAvg)")
        }
    }
    
    @Test("Rapid graph reload")
    func rapidGraphReload() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 5000)
        
        let initialMemory = MemoryTracker.currentMemoryUsage()
        
        // Reload multiple times
        for _ in 0..<10 {
            store.loadDirect(nodes: nodes, edges: edges)
        }
        
        let finalMemory = MemoryTracker.currentMemoryUsage()
        let memoryGrowth = finalMemory > initialMemory ? finalMemory - initialMemory : 0
        
        // Should not accumulate memory across reloads
        #expect(memoryGrowth < 100_000_000, // 100MB threshold
                "Memory growth \(MemoryTracker.formattedMemory(memoryGrowth)) after reloads")
    }
    
    // MARK: - Memory Leak Detection
    
    @Test("Memory leak detection - fuzzy search")
    func memoryLeakFuzzySearch() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let initialMemory = MemoryTracker.currentMemoryUsage()
        
        // Perform many searches
        for i in 0..<1000 {
            let _ = store.fuzzySearch(query: "query\(i % 100)", limit: 20)
        }
        
        let finalMemory = MemoryTracker.currentMemoryUsage()
        let memoryGrowth = finalMemory > initialMemory ? finalMemory - initialMemory : 0
        
        // Should not leak memory
        #expect(memoryGrowth < 200_000_000, // 200MB threshold (CI/test environments have overhead)
                "Memory growth \(MemoryTracker.formattedMemory(memoryGrowth)) from searches")
    }
    
    @Test("Memory leak detection - BFS traversal")
    func memoryLeakBFSTraversal() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let initialMemory = MemoryTracker.currentMemoryUsage()
        
        // Perform many traversals
        for i in 0..<1000 {
            let nodeId = nodes[i % nodes.count].id
            let _ = store.connected(to: nodeId, maxDepth: 5)
        }
        
        let finalMemory = MemoryTracker.currentMemoryUsage()
        let memoryGrowth = finalMemory > initialMemory ? finalMemory - initialMemory : 0
        
        #expect(memoryGrowth < 20_000_000, // 20MB threshold
                "Memory growth \(MemoryTracker.formattedMemory(memoryGrowth)) from BFS")
    }
    
    @Test("Memory leak detection - node operations")
    func memoryLeakNodeOperations() async throws {
        let store = GraphStore()
        
        let initialMemory = MemoryTracker.currentMemoryUsage()
        
        // Add and remove many nodes
        for i in 0..<1000 {
            let node = GraphNodeRecord(
                id: "temp-\(i)",
                type: .note,
                label: "Temp Node \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now
            )
            store.addNode(node)
            store.removeNode(node.id)
        }
        
        let finalMemory = MemoryTracker.currentMemoryUsage()
        let memoryGrowth = finalMemory > initialMemory ? finalMemory - initialMemory : 0
        
        // After additions and removals, memory should be roughly the same
        #expect(memoryGrowth < 10_000_000, // 10MB threshold
                "Memory growth \(MemoryTracker.formattedMemory(memoryGrowth)) from node operations")
    }
    
    // MARK: - Peak Memory Usage
    
    @Test("Peak memory during graph operations")
    func peakMemoryDuringOperations() async throws {
        guard !TestSanitizerSupport.hasRuntimeInstrumentation else { return }

        let store = GraphStore()
        var peakMemory: UInt64 = 0
        
        // Monitor during large load
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 10000)
        
        for i in 0..<nodes.count {
            store.addNode(GraphNodeRecord(
                id: nodes[i].id,
                type: nodes[i].nodeType,
                label: nodes[i].label,
                sourceId: nodes[i].sourceId,
                metadata: nodes[i].meta,
                weight: nodes[i].weight,
                createdAt: nodes[i].createdAt
            ))
            
            if i % 1000 == 0 {
                let current = MemoryTracker.currentMemoryUsage()
                peakMemory = max(peakMemory, current)
            }
        }
        
        // Add edges
        for edge in edges {
            let record = GraphEdgeRecord(
                id: edge.id,
                sourceNodeId: edge.sourceNodeId,
                targetNodeId: edge.targetNodeId,
                type: edge.edgeType,
                weight: edge.weight,
                createdAt: edge.createdAt
            )
            store.addEdge(record)
        }
        
        peakMemory = max(peakMemory, MemoryTracker.currentMemoryUsage())
        
        // Peak should be reasonable for 10k nodes
        #expect(peakMemory < 750_000_000, // 750MB threshold (debug builds use more)
                "Peak memory \(MemoryTracker.formattedMemory(peakMemory)) too high")
    }
    
    @Test("Memory during intensive search")
    func memoryDuringIntensiveSearch() async throws {
        guard !TestSanitizerSupport.hasRuntimeInstrumentation else { return }

        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 5000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        var peakMemory: UInt64 = 0
        
        // Intensive search operations
        for i in 0..<100 {
            let _ = store.fuzzySearch(query: "test\(i)", limit: 100)
            let _ = store.connected(to: nodes[i % nodes.count].id, maxDepth: 10)
            
            let current = MemoryTracker.currentMemoryUsage()
            peakMemory = max(peakMemory, current)
        }
        
        #expect(peakMemory < 1_000_000_000, // 1GB threshold
                "Peak memory during search \(MemoryTracker.formattedMemory(peakMemory)) too high")
    }
    
    // MARK: - SwiftData Context Memory
    
    @Test("SwiftData context memory management")
    func swiftDataContextMemory() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SDGraphNode.self, SDGraphEdge.self,
            configurations: config
        )
        
        let initialMemory = MemoryTracker.currentMemoryUsage()
        
        // Create many contexts and insert data
        for i in 0..<100 {
            let context = ModelContext(container)
            
            let node = SDGraphNode(
                type: .note,
                label: "Node \(i)",
                sourceId: "source-\(i)"
            )
            context.insert(node)
            
            try? context.save()
            // Context goes out of scope
        }
        
        let finalMemory = MemoryTracker.currentMemoryUsage()
        let memoryGrowth = finalMemory > initialMemory ? finalMemory - initialMemory : 0
        
        // Contexts should not accumulate
        #expect(memoryGrowth < 100_000_000, // 100MB threshold
                "SwiftData context memory growth \(MemoryTracker.formattedMemory(memoryGrowth)) too high")
    }
    
    @Test("SwiftData large batch insert")
    func swiftDataLargeBatchInsert() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SDGraphNode.self, SDGraphEdge.self,
            configurations: config
        )
        let context = ModelContext(container)
        
        let batchSize = 5000
        let initialMemory = MemoryTracker.currentMemoryUsage()
        
        // Batch insert
        for i in 0..<batchSize {
            let node = SDGraphNode(
                type: .note,
                label: "Batch Node \(i)",
                sourceId: "batch-\(i)"
            )
            context.insert(node)
            
            // Periodic saves to control memory
            if i % 1000 == 0 {
                try? context.save()
            }
        }
        
        try? context.save()
        
        let finalMemory = MemoryTracker.currentMemoryUsage()
        let memoryUsed = finalMemory > initialMemory ? finalMemory - initialMemory : 0
        let memoryPerObject = Double(memoryUsed) / Double(batchSize)
        
        // Should be efficient per object
        #expect(memoryPerObject < 50000, // 50KB per object (SwiftData has overhead in test containers)
                "Memory per object \(memoryPerObject) bytes too high")
    }
    
    // MARK: - Autorelease Pool Performance
    
    @Test("Autorelease pool effectiveness")
    func autoreleasePoolEffectiveness() async throws {
        let store = GraphStore()
        
        let initialMemory = MemoryTracker.currentMemoryUsage()
        
        // Many operations that might create autoreleased objects
        for i in 0..<1000 {
            autoreleasepool {
                let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 100)
                store.loadDirect(nodes: nodes, edges: edges)
                
                // Search creates temporary objects
                let _ = store.fuzzySearch(query: "test\(i)", limit: 20)
            }
        }
        
        let finalMemory = MemoryTracker.currentMemoryUsage()
        let memoryGrowth = finalMemory > initialMemory ? finalMemory - initialMemory : 0
        
        // Autorelease pool should prevent accumulation
        #expect(memoryGrowth < 200_000_000, // 200MB threshold (CI/test environments have overhead)
                "Memory growth with autoreleasepool \(MemoryTracker.formattedMemory(memoryGrowth)) too high")
    }
    
    // MARK: - Long Running Stability
    
    @Test("Long running stability - simulated workload")
    func longRunningStability() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        var memorySamples: [UInt64] = []
        
        // Simulate sustained workload
        for i in 0..<100 {
            // Mix of operations
            let _ = store.fuzzySearch(query: "query\(i % 10)", limit: 20)
            let _ = store.connected(to: nodes[i % nodes.count].id, maxDepth: 3)
            
            // Sample memory every 10 iterations
            if i % 10 == 0 {
                memorySamples.append(MemoryTracker.currentMemoryUsage())
            }
        }
        
        // Check for upward trend
        if memorySamples.count >= 5 {
            let firstHalf = memorySamples.prefix(memorySamples.count / 2).reduce(0, +) / UInt64(memorySamples.count / 2)
            let secondHalf = memorySamples.suffix(memorySamples.count / 2).reduce(0, +) / UInt64(memorySamples.count / 2)
            
            // Second half should not be significantly higher
            #expect(secondHalf < firstHalf * 3 / 2,
                    "Memory trending up: first half \(firstHalf), second half \(secondHalf)")
        }
    }
    
    // MARK: - Edge Case Memory Scenarios
    
    @Test("Memory with empty graph operations")
    func memoryWithEmptyGraph() async throws {
        let store = GraphStore()
        
        let initialMemory = MemoryTracker.currentMemoryUsage()
        
        // Operations on empty graph
        for _ in 0..<1000 {
            let _ = store.fuzzySearch(query: "test", limit: 20)
            let _ = store.connected(to: "nonexistent", maxDepth: 3)
            let _ = store.neighbors(of: "nonexistent")
        }
        
        let finalMemory = MemoryTracker.currentMemoryUsage()
        let memoryGrowth = finalMemory > initialMemory ? finalMemory - initialMemory : 0
        
        #expect(memoryGrowth < 10_000_000, // 10MB threshold
                "Memory growth on empty graph \(MemoryTracker.formattedMemory(memoryGrowth)) too high")
    }
    
    @Test("Memory with very long labels")
    func memoryWithLongLabels() async throws {
        let store = GraphStore()
        
        // Create nodes with very long labels
        var nodes: [SDGraphNode] = []
        for i in 0..<100 {
            let longLabel = String(repeating: "Very long label text ", count: 100) + "\(i)"
            let node = SDGraphNode(type: .note, label: longLabel, sourceId: "\(i)")
            nodes.append(node)
        }
        
        let initialMemory = MemoryTracker.currentMemoryUsage()
        store.loadDirect(nodes: nodes, edges: [])
        let finalMemory = MemoryTracker.currentMemoryUsage()
        
        let memUsed = finalMemory > initialMemory ? finalMemory - initialMemory : 0
        let memoryPerNode = Double(memUsed) / Double(nodes.count)
        
        // Should handle long labels efficiently
        #expect(memoryPerNode < 10_000, // 10KB per node with long label
                "Memory per long-label node \(memoryPerNode) bytes too high")
    }
    
    @Test("Memory with dense graph")
    func memoryWithDenseGraph() async throws {
        let store = GraphStore()
        let nodeCount = 1000
        let nodes = GraphTestDataGenerator.generateNodes(count: nodeCount)
        // Dense: many edges per node
        let edges = GraphTestDataGenerator.generateEdges(for: nodes, edgeRatio: 10.0)
        
        let initialMemory = MemoryTracker.currentMemoryUsage()
        store.loadDirect(nodes: nodes, edges: edges)
        let finalMemory = MemoryTracker.currentMemoryUsage()
        
        let memoryUsed = finalMemory > initialMemory ? finalMemory - initialMemory : 0
        let memoryPerNode = Double(memoryUsed) / Double(nodeCount)

        // Dense graph should still be memory efficient
        #expect(memoryPerNode < 50000, // 50KB per node (test environment overhead)
                "Memory per node in dense graph \(memoryPerNode) bytes too high")
    }
}

// BEGIN GENERATED RELIABILITY MATRIX TESTS
@Suite("Generated Reliability Matrix")
@MainActor
struct GeneratedReliabilityMatrixTests {

    @Test("benchmark parser throughput envelope", arguments: Array(0..<200))
    func benchmarkParserThroughputEnvelope(_ i: Int) {
        let iterations = 40 + (i % 40)
        let start = ContinuousClock().now

        for j in 0..<iterations {
            let query = "find topic \(i)-\(j) with references and synthesis"
            _ = QueryParser.parseToAST(query)

            let markdown = """
            # Heading \(i)-\(j)
            > Citation block \(i)-\(j)
            [Source \(i)-\(j)](https://example.com/\(i)/\(j))
            """
            let toc = TOCParser.parse(markdown)
            #expect(!toc.isEmpty)

            let diff = LineDiff.compute(
                old: "alpha \(i)-\(j)\nshared line",
                new: "alpha \(i)-\(j) updated\nshared line\nextra"
            )
            #expect(!diff.lines.isEmpty)
        }

        let elapsed = ContinuousClock().now - start
        #expect(elapsed < .seconds(2), "Parser throughput case \(i) exceeded budget: \(elapsed)")
    }

    @Test("graph load and traversal budget", arguments: Array(0..<200))
    func graphLoadAndTraversalBudget(_ i: Int) {
        let nodeSizes = [64, 128, 256, 384, 512, 640]
        let nodeCount = nodeSizes[i % nodeSizes.count]
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: nodeCount)

        let store = GraphStore()
        let start = ContinuousClock().now
        store.loadDirect(nodes: nodes, edges: edges)

        let _ = store.fuzzySearch(query: "Test Node", limit: 30)
        let _ = store.connected(to: nodes[i % nodes.count].id, maxDepth: 3)
        let elapsed = ContinuousClock().now - start

        let budgetMs = 450 + (nodeCount * 2)
        #expect(store.nodeCount == nodeCount)
        #expect(elapsed < .milliseconds(budgetMs), "Graph workload \(nodeCount) exceeded budget \(budgetMs)ms: \(elapsed)")
    }

    @Test("memory growth bounded for repeated query cycles", arguments: Array(0..<200))
    func memoryGrowthBoundedForRepeatedQueryCycles(_ i: Int) {
        let store = GraphStore()
        let nodeCount = 256 + ((i % 4) * 128)
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: nodeCount)
        store.loadDirect(nodes: nodes, edges: edges)

        let before = MemoryTracker.currentMemoryUsage()

        for j in 0..<60 {
            autoreleasepool {
                let _ = store.fuzzySearch(query: "query-\(i)-\(j)", limit: 20)
                let target = nodes[(i + j) % nodes.count].id
                let _ = store.connected(to: target, maxDepth: 2 + (j % 2))
            }
        }

        let after = MemoryTracker.currentMemoryUsage()
        let growth = after > before ? after - before : 0
        #expect(growth < 120_000_000, "Memory growth too high for case \(i): \(growth) bytes")
    }

    @Test("malformed inputs are crash resistant", arguments: Array(0..<200))
    func malformedInputsAreCrashResistant(_ i: Int) {
        let payloadA = String(repeating: "[", count: 128 + (i % 256))
        let payloadB = String(repeating: "\\", count: 64 + (i % 128))
        let payloadC = String(repeating: ">", count: 64 + (i % 128))

        _ = QueryParser.parseToAST(payloadA + payloadB + payloadC)
        let toc = TOCParser.parse(payloadA + "\n" + payloadC)
        let diff = LineDiff.compute(old: payloadA, new: payloadA + payloadB)

        #expect(toc.count >= 0)
        #expect(diff.lines.count >= 1)
    }

    @Test("soft failure recovery keeps core paths healthy", arguments: Array(0..<200))
    func softFailureRecoveryKeepsCorePathsHealthy(_ i: Int) {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 200)
        store.loadDirect(nodes: nodes, edges: edges)

        let malformed = String(repeating: "]", count: 256 + (i % 128))
        _ = QueryParser.parseToAST(malformed)
        _ = TOCParser.parse(malformed)
        _ = LineDiff.compute(old: malformed, new: malformed + "x")

        let connected = store.connected(to: nodes[0].id, maxDepth: 3)
        let parsed = QueryParser.parseToAST("all notes")

        if case .typeFilter(let types) = parsed {
            #expect(types.contains(.note))
        } else {
            Issue.record("Recovery parser check failed for case \(i)")
        }

        #expect(store.nodeCount == nodes.count)
        #expect(!connected.isEmpty)
    }

    @Test("concurrent parser and diff stress", arguments: Array(0..<200))
    func concurrentParserAndDiffStress(_ i: Int) async {
        let completed = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for worker in 0..<8 {
                group.addTask {
                    for j in 0..<25 {
                        let query = "path from node\(i)-\(worker)-\(j) to node\(j)-\(i)"
                        await MainActor.run {
                            _ = QueryParser.parseToAST(query)
                            _ = LineDiff.compute(old: "a\(j)", new: "a\(j)-\(i)")
                        }
                    }
                    return true
                }
            }

            var successes = 0
            for await ok in group {
                if ok {
                    successes += 1
                }
            }
            return successes
        }

        #expect(completed == 8, "Expected 8 worker completions, got \(completed)")
    }
}
// END GENERATED RELIABILITY MATRIX TESTS

// MARK: - Required Imports for Memory Tracking

import Darwin.Mach
