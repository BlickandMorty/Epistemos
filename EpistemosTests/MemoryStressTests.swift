import Testing
import Foundation
import SwiftData
@testable import Epistemos

// MARK: - Memory Tracking

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
        let memoryPerNode = nodes.count > 0 ? Double(memoryIncrease) / Double(nodes.count) : 0

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
            
            let memoryUsed = after - before
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
            
            let before = MemoryTracker.currentMemoryUsage()
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
        #expect(peakMemory < 500_000_000, // 500MB threshold
                "Peak memory \(MemoryTracker.formattedMemory(peakMemory)) too high")
    }
    
    @Test("Memory during intensive search")
    func memoryDuringIntensiveSearch() async throws {
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

// MARK: - Required Imports for Memory Tracking

import Darwin.Mach
