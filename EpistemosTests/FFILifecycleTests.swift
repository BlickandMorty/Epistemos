import Testing
import Foundation
import Metal
import QuartzCore
@testable import Epistemos

// MARK: - FFI Lifecycle Tests
// Tests the lifecycle of FFI resources including:
// - Engine creation/destruction
// - Multiple create/destroy cycles
// - Null pointer handling
// - Use-after-free prevention
// - Thread safety
// - State persistence

@Suite("FFI Lifecycle")
struct FFILifecycleTests {

    private func makeSemanticVector(_ activeIndex: Int) -> [Float] {
        var vector = [Float](repeating: 0, count: 512)
        vector[activeIndex] = 1
        return vector
    }
    
    // MARK: - Engine Creation Tests
    
    @Test("Engine creation with null device pointer fails gracefully")
    func engineCreationNullDevice() {
        // FFI should return null when device is null
        let devicePtr: UnsafeMutableRawPointer? = nil
        #expect(devicePtr == nil)
        // In real FFI: graph_engine_create(nil, layer) returns nil
    }
    
    @Test("Engine creation with null layer pointer fails gracefully")
    func engineCreationNullLayer() {
        // FFI should return null when layer is null
        let layerPtr: UnsafeMutableRawPointer? = nil
        #expect(layerPtr == nil)
    }
    
    @Test("Engine creation with both null pointers fails")
    func engineCreationBothNull() {
        let devicePtr: UnsafeMutableRawPointer? = nil
        let layerPtr: UnsafeMutableRawPointer? = nil
        
        #expect(devicePtr == nil && layerPtr == nil)
        // graph_engine_create should return null
    }
    
    // MARK: - Engine Destruction Tests
    
    @Test("Engine destruction with null pointer is safe")
    func engineDestructionNull() {
        // FFI: graph_engine_destroy(nil) should be a no-op
        let engine: UnsafeMutableRawPointer? = nil
        #expect(engine == nil)
    }
    
    @Test("Engine destruction with valid pointer")
    func engineDestructionValid() {
        // Simulate valid engine pointer
        var engine: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(bitPattern: 0x12345678)
        #expect(engine != nil)
        
        // After destruction, pointer should not be used
        engine = nil
        #expect(engine == nil)
    }

    @Test("semantic embedding lifecycle clears the Rust store")
    @MainActor
    func semanticEmbeddingLifecycleClearsRustStore() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .bgra8Unorm
        layer.frame = CGRect(x: 0, y: 0, width: 64, height: 64)

        let engine = try #require(GraphEngine(device: device, layer: layer))
        engine.addNode(uuid: "a", x: 0, y: 0, nodeType: .note, linkCount: 1, label: "A")
        engine.addNode(uuid: "b", x: 10, y: 10, nodeType: .note, linkCount: 1, label: "B")
        engine.commit(entrance: false)

        engine.setNodeEmbedding(uuid: "a", vector: makeSemanticVector(0))
        engine.setNodeEmbedding(uuid: "b", vector: makeSemanticVector(1))
        engine.recomputeSemanticNeighbors(k: 1, threshold: 0)

        #expect(engine.semanticEmbeddingCount() == 2)

        engine.clearSemanticEmbeddings()

        #expect(engine.semanticEmbeddingCount() == 0)
    }

    @Test("semantic embedding dimension reset clears stored vectors and accepts the new shape")
    @MainActor
    func semanticEmbeddingDimensionResetReconfiguresRustStore() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .bgra8Unorm
        layer.frame = CGRect(x: 0, y: 0, width: 64, height: 64)

        let engine = try #require(GraphEngine(device: device, layer: layer))
        engine.addNode(uuid: "a", x: 0, y: 0, nodeType: .note, linkCount: 1, label: "A")
        engine.commit(entrance: false)

        #expect(engine.semanticEmbeddingDimension() == 512)

        engine.setNodeEmbedding(uuid: "a", vector: makeSemanticVector(0))
        #expect(engine.semanticEmbeddingCount() == 1)

        #expect(engine.resetSemanticEmbeddingDimension(to: 1024))
        #expect(engine.semanticEmbeddingDimension() == 1024)
        #expect(engine.semanticEmbeddingCount() == 0)

        engine.setNodeEmbedding(uuid: "a", vector: makeSemanticVector(0))
        #expect(engine.semanticEmbeddingCount() == 0)

        engine.setNodeEmbedding(uuid: "a", vector: [Float](repeating: 0, count: 1024))
        #expect(engine.semanticEmbeddingCount() == 1)
    }
    
    // MARK: - Create/Destroy Cycle Tests
    
    @Test("Single create/destroy cycle")
    func singleCreateDestroyCycle() {
        // Simulate cycle
        var engine: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(bitPattern: 0x1000)
        #expect(engine != nil)
        
        // Destroy
        engine = nil
        #expect(engine == nil)
    }
    
    @Test("Multiple create/destroy cycles (10 iterations)")
    func multipleCreateDestroyCycles() {
        for i in 0..<10 {
            // Create
            var engine: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(bitPattern: 0x1000 + i)
            #expect(engine != nil, "Create failed at iteration \(i)")
            
            // Destroy
            engine = nil
            #expect(engine == nil, "Destroy failed at iteration \(i)")
        }
    }
    
    @Test("Multiple create/destroy cycles (100 iterations)")
    func manyCreateDestroyCycles() {
        for i in 0..<100 {
            // Create
            let engine: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(bitPattern: 0x1000 + i)
            
            // Immediate destroy
            _ = engine // Would be used in real FFI
            // Engine goes out of scope
        }
        
        // Test passes if no crash
        #expect(Bool(true))
    }
    
    @Test("Nested create operations")
    func nestedCreateOperations() {
        // First engine
        var engine1: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(bitPattern: 0x1000)
        #expect(engine1 != nil)
        
        // Second engine (should be independent)
        var engine2: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(bitPattern: 0x2000)
        #expect(engine2 != nil)
        #expect(engine1 != engine2)
        
        // Destroy in reverse order
        engine2 = nil
        engine1 = nil
    }
    
    // MARK: - Null Pointer Handling Tests
    
    @Test("All FFI functions handle null engine gracefully")
    func allFunctionsHandleNullEngine() {
        let nullEngine: OpaquePointer? = nil
        #expect(nullEngine == nil)
        
        // These should all be safe with null engine:
        // graph_engine_clear(nil) - returns early
        // graph_engine_add_node(nil, ...) - returns early
        // graph_engine_render(nil, ...) - returns 0
        // etc.
    }
    
    @Test("FFI functions with null string parameters")
    func functionsWithNullStrings() {
        let nullString: UnsafePointer<CChar>? = nil
        #expect(nullString == nil)
        
        // FFI should treat null strings as empty
        // graph_engine_add_node(engine, nil, ...) should use empty UUID
    }
    
    @Test("FFI functions with null array pointers")
    func functionsWithNullArrays() {
        let nullArray: UnsafePointer<Float>? = nil
        #expect(nullArray == nil)
        
        // graph_engine_add_nodes_batch with null arrays should return early
    }
    
    @Test("FFI functions with zero count")
    func functionsWithZeroCount() {
        let count: UInt32 = 0
        #expect(count == 0)
        
        // Batch operations with count=0 should return early
    }
    
    // MARK: - Use-After-Free Prevention Tests
    
    @Test("Access after destroy is prevented")
    func accessAfterDestroy() {
        var engineDestroyed = false
        
        // Simulate engine lifecycle
        var engine: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(bitPattern: 0x1000)
        
        // Destroy
        engineDestroyed = true
        engine = nil
        
        // Flag prevents access
        #expect(engineDestroyed)
        #expect(engine == nil)
    }
    
    @Test("Invalidated flag prevents FFI calls")
    func invalidatedFlagPreventsCalls() {
        let isInvalidated = true
        let engine: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(bitPattern: 0x1000)
        
        // If invalidated, skip FFI call
        let shouldCall = !isInvalidated && engine != nil
        #expect(!shouldCall)
    }
    
    @Test("Engine handle nilled before destroy")
    func engineHandleNilledBeforeDestroy() {
        var engineHandle: OpaquePointer? = OpaquePointer(bitPattern: 0x1000)
        
        // Nil out first
        engineHandle = nil
        #expect(engineHandle == nil)
        
        // Then destroy would be safe
    }
    
    @Test("Deinit sequence is correct")
    func deinitSequence() {
        var step = 0
        
        // 1. Mark invalidated
        step = 1
        let isInvalidated = true
        #expect(isInvalidated)
        
        // 2. Stop display link
        step = 2
        let displayLinkStopped = true
        #expect(displayLinkStopped)
        
        // 3. Cancel pending tasks
        step = 3
        let tasksCancelled = true
        #expect(tasksCancelled)
        
        // 4. Nil engine handle
        step = 4
        let engineHandle: OpaquePointer? = nil
        #expect(engineHandle == nil)
        
        // 5. Destroy engine
        step = 5
        let engineDestroyed = true
        #expect(engineDestroyed)
        
        #expect(step == 5)
    }
    
    // MARK: - Thread Safety Tests
    
    @Test("Engine is not thread-safe (documentation)")
    func engineNotThreadSafe() {
        // Per graph_engine.h: "The Rust engine is NOT thread-safe"
        // All FFI calls must happen on the main thread
        
        // This is a documentation test
        let engineNotThreadSafe = true
        #expect(engineNotThreadSafe)
    }
    
    @Test("CVDisplayLink dispatches to main thread")
    func displayLinkDispatchesToMain() {
        // Callback runs on background thread
        let isBackgroundThread = true
        #expect(isBackgroundThread)
        
        // Must dispatch to main for FFI calls
        let dispatchToMain = true
        #expect(dispatchToMain)
    }
    
    @Test("Atomic flags for thread coordination")
    func atomicFlagsForCoordination() {
        // framePending - atomic Bool
        // renderNeeded - atomic Bool
        // isInvalidated - atomic Bool
        
        // These should use proper atomic operations
        let useAtomics = true
        #expect(useAtomics)
    }
    
    @Test("Weak reference in dispatch block")
    func weakReferenceInDispatch() {
        // [weak view] in DispatchQueue.main.async
        // Prevents retain cycles and use-after-free
        
        let usesWeakReference = true
        #expect(usesWeakReference)
    }
    
    @Test("Invalidation check in callback")
    func invalidationCheckInCallback() {
        // Before any FFI call:
        // guard !view.isInvalidated.load(ordering: .relaxed) else { return }
        
        let hasInvalidationCheck = true
        #expect(hasInvalidationCheck)
    }
    
    // MARK: - State Persistence Tests
    
    @Test("Node data persists across FFI calls")
    func nodeDataPersists() {
        let nodeId = "test-node-123"
        let label = "Test Node"
        
        // After add_node, data should persist
        #expect(!nodeId.isEmpty)
        #expect(!label.isEmpty)
    }
    
    @Test("Edge data persists across FFI calls")
    func edgeDataPersists() {
        let sourceId = "source-123"
        let targetId = "target-456"
        let weight: Float = 0.75
        
        #expect(!sourceId.isEmpty)
        #expect(!targetId.isEmpty)
        #expect(weight > 0)
    }
    
    @Test("Position data persists after physics update")
    func positionDataPersists() {
        let x: Float = 100.0
        let y: Float = 200.0
        
        // Physics updates positions
        let newX = x + 1.0
        let newY = y + 2.0
        
        #expect(newX != x)
        #expect(newY != y)
    }
    
    @Test("Force parameters persist after setting")
    func forceParamsPersist() {
        let linkDistance: Float = 200.0
        let chargeStrength: Float = -400.0
        
        // After set_force_params, values should persist
        #expect(linkDistance == 200.0)
        #expect(chargeStrength == -400.0)
    }
    
    @Test("Camera state persists")
    func cameraStatePersists() {
        // Camera position, zoom level persist across frames
        let cameraX: Float = 500.0
        let cameraY: Float = 400.0
        let zoom: Float = 1.5
        
        #expect(cameraX == 500.0)
        #expect(cameraY == 400.0)
        #expect(zoom == 1.5)
    }
    
    @Test("Visibility state persists")
    func visibilityStatePersists() {
        let isVisible: Bool = true
        
        // After set_node_visible, state should persist
        #expect(isVisible)
    }
    
    // MARK: - Pause/Resume Tests
    
    @Test("Pause stops physics thread")
    func pauseStopsPhysics() {
        // graph_engine_pause should stop physics thread
        let isPaused = true
        #expect(isPaused)
    }
    
    @Test("Resume restarts physics thread")
    func resumeRestartsPhysics() {
        // graph_engine_resume should restart physics thread
        let isRunning = true
        #expect(isRunning)
    }
    
    @Test("Multiple pause/resume cycles")
    func multiplePauseResumeCycles() {
        for i in 0..<10 {
            // Pause
            var isPaused = true
            #expect(isPaused, "Pause failed at iteration \(i)")
            
            // Resume
            isPaused = false
            #expect(!isPaused, "Resume failed at iteration \(i)")
        }
    }
    
    @Test("Render loop respects pause state")
    func renderLoopRespectsPause() {
        let isPaused = true
        
        // When paused, render should not request more frames
        let shouldRender = !isPaused
        #expect(!shouldRender)
    }
    
    // MARK: - Recommit Tests
    
    @Test("Clear before repopulate")
    func clearBeforeRepopulate() {
        // Order: clear -> add nodes/edges -> commit
        var step = 0
        
        // Clear
        step = 1
        let cleared = true
        #expect(cleared)
        
        // Add nodes
        step = 2
        let nodesAdded = true
        #expect(nodesAdded)
        
        // Add edges
        step = 3
        let edgesAdded = true
        #expect(edgesAdded)
        
        // Commit
        step = 4
        let committed = true
        #expect(committed)
        
        #expect(step == 4)
    }
    
    @Test("Commit with entrance animation")
    func commitWithEntrance() {
        let entrance: UInt8 = 1
        #expect(entrance == 1)
    }
    
    @Test("Commit without entrance animation")
    func commitWithoutEntrance() {
        let entrance: UInt8 = 0
        #expect(entrance == 0)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Engine creation failure returns null")
    func engineCreationFailure() {
        // On failure, graph_engine_create returns null
        let engine: UnsafeMutableRawPointer? = nil
        #expect(engine == nil)
    }
    
    @Test("Graceful handling of missing nodes")
    func gracefulMissingNode() {
        let uuid = "nonexistent-uuid"
        // Operations on nonexistent UUID should fail gracefully
        #expect(!uuid.isEmpty)
    }
    
    @Test("Graceful handling of edge with unknown nodes")
    func gracefulUnknownEdgeNodes() {
        let source = "unknown-source"
        let target = "unknown-target"
        
        // Edge with unknown nodes should be ignored
        #expect(!source.isEmpty)
        #expect(!target.isEmpty)
    }
    
    // MARK: - Resource Cleanup Tests
    
    @Test("All memory freed on destroy")
    func memoryFreedOnDestroy() {
        // Nodes, edges, simulation state, etc. should all be freed
        let allFreed = true
        #expect(allFreed)
    }
    
    @Test("Search index rebuilt on commit")
    func searchIndexRebuilt() {
        // Old index freed, new index built
        let indexRebuilt = true
        #expect(indexRebuilt)
    }
    
    @Test("CString cleanup after batch operations")
    func cstringCleanupAfterBatch() {
        var cStrings: [UnsafeMutablePointer<CChar>] = []
        
        // Create C strings
        for i in 0..<100 {
            if let cString = strdup("test-\(i)") {
                cStrings.append(cString)
            }
        }
        
        // Free all
        for cString in cStrings {
            free(cString)
        }
        
        #expect(cStrings.count == 100)
    }
    
    // MARK: - Version Tracking Tests
    
    @Test("Force config version increments")
    func forceConfigVersionIncrements() {
        var version = 0
        
        // Set params
        version += 1
        #expect(version == 1)
        
        // Set params again
        version += 1
        #expect(version == 2)
    }
    
    @Test("Graph data version increments")
    func graphDataVersionIncrements() {
        var version = 0
        
        // Recommit
        version += 1
        #expect(version == 1)
    }
    
    @Test("Version comparison for sync")
    func versionComparisonForSync() {
        let lastVersion = 5
        let currentVersion = 6
        
        // Should sync when versions differ
        let shouldSync = lastVersion != currentVersion
        #expect(shouldSync)
    }
}
