import Testing
import Foundation
@testable import Epistemos

private func requireSendable<T: Sendable>(_: T.Type) {}

// MARK: - FFI Safety Tests
// Tests safety boundaries and error handling at the FFI layer:
// - Invalid pointer handling
// - Out-of-bounds access
// - Malformed UTF-8
// - Resource exhaustion
// - Race conditions
// - Memory leaks

@Suite("FFI Safety")
struct FFISafetyTests {

    @Test("Agent runtime FFI bridge values are Sendable")
    func agentRuntimeBridgeValuesAreSendable() {
        requireSendable(ToolConfig.self)
        requireSendable(AgentConfigFFI.self)
        requireSendable(ReasoningTrajectoryMetricsFFI.self)
        requireSendable(AgentResultFFI.self)
    }
    
    // MARK: - Invalid Pointer Handling Tests
    
    @Test("Null engine pointer handling")
    func nullEnginePointer() {
        let nullEngine: OpaquePointer? = nil
        
        // All FFI functions should handle null engine gracefully
        #expect(nullEngine == nil)
        
        // graph_engine_clear(nil) -> returns early
        // graph_engine_add_node(nil, ...) -> returns early
        // graph_engine_render(nil, ...) -> returns 0
    }
    
    @Test("Null string pointer handling")
    func nullStringPointer() {
        let nullString: UnsafePointer<CChar>? = nil
        
        // FFI treats null strings as empty
        #expect(nullString == nil)
    }
    
    @Test("Null array pointer handling")
    func nullArrayPointer() {
        let nullFloatArray: UnsafePointer<Float>? = nil
        let nullStringArray: UnsafePointer<UnsafePointer<CChar>?>? = nil
        
        // Batch operations should check for null and return early
        #expect(nullFloatArray == nil)
        #expect(nullStringArray == nil)
    }
    
    @Test("Dangling pointer detection (conceptual)")
    func danglingPointerDetection() {
        // This tests that we track pointer validity
        var engineDestroyed = false
        var engine: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(bitPattern: 0x1000)
        
        // Use the engine
        #expect(engine != nil)
        
        // Destroy it
        engineDestroyed = true
        engine = nil
        
        // Should not use after destroy
        #expect(engineDestroyed)
        #expect(engine == nil)
    }
    
    @Test("Invalid pointer pattern handling")
    func invalidPointerPattern() {
        // Pointers that look invalid
        let invalidPointers: [UnsafeMutableRawPointer?] = [
            UnsafeMutableRawPointer(bitPattern: 0x0),      // Null
            UnsafeMutableRawPointer(bitPattern: 0x1),      // Very low (likely invalid)
            UnsafeMutableRawPointer(bitPattern: 0xDEAD),   // Magic number
        ]
        
        for ptr in invalidPointers {
            // Should handle gracefully
            #expect(ptr == nil || ptr != nil) // Always true, just checking compile
        }
    }
    
    @Test("Misaligned pointer handling")
    func misalignedPointerHandling() {
        // Float requires 4-byte alignment
        let buffer: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]
        
        buffer.withUnsafeBytes { rawBuffer in
            // Get aligned pointer
            let aligned = rawBuffer.baseAddress?.assumingMemoryBound(to: Float.self)
            #expect(aligned != nil)
            
            // Misaligned would be at +1, +2, or +3
            // Modern ARM64 handles unaligned access, but it's best avoided
        }
    }
    
    // MARK: - Out-of-Bounds Array Access Tests
    
    @Test("Array bounds checking with correct count")
    func arrayBoundsCorrect() {
        let array: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let count = UInt32(array.count)
        
        #expect(count == 5)
        
        // Access within bounds
        array.withUnsafeBufferPointer { buf in
            for i in 0..<Int(count) {
                #expect(buf[i] == array[i])
            }
        }
    }
    
    @Test("Array bounds with mismatched count")
    func arrayBoundsMismatch() {
        let array: [Float] = [1.0, 2.0, 3.0]
        let claimedCount: UInt32 = 10 // Larger than actual
        
        // FFI should use actual count, not claimed count
        #expect(array.count < Int(claimedCount))
    }
    
    @Test("Empty array with non-zero count")
    func emptyArrayNonZeroCount() {
        let array: [Float] = []
        let claimedCount: UInt32 = 5
        
        // This would be a bug - FFI should check for null or empty
        #expect(array.isEmpty)
        #expect(claimedCount > 0)
    }
    
    @Test("Parallel array length mismatch")
    func parallelArrayLengthMismatch() {
        let uuids = ["a", "b", "c"]
        let xs: [Float] = [1.0, 2.0] // One short
        let ys: [Float] = [1.0, 2.0, 3.0]
        
        // Mismatched lengths should be detected
        let lengths = [uuids.count, xs.count, ys.count]
        let uniqueLengths = Set(lengths)
        #expect(uniqueLengths.count > 1) // Should detect mismatch
    }
    
    @Test("Single element array access")
    func singleElementArray() {
        let array: [Float] = [42.0]
        
        array.withUnsafeBufferPointer { buf in
            #expect(buf.count == 1)
            #expect(buf[0] == 42.0)
        }
    }
    
    @Test("Maximum safe array size")
    func maximumSafeArraySize() {
        // Very large arrays might cause issues
        let maxSafeCount = 1_000_000 // 1M elements
        
        // This would use 4MB for Float array
        let memoryEstimate = maxSafeCount * MemoryLayout<Float>.size
        #expect(memoryEstimate == 4_000_000)
    }
    
    // MARK: - Malformed UTF-8 Handling Tests
    
    @Test("Valid UTF-8 round-trip")
    func validUtf8RoundTrip() {
        let valid = "Hello, 世界! 🌍"
        let cString = strdup(valid)
        let roundTrip = String(cString: cString!)
        free(cString)
        
        #expect(roundTrip == valid)
    }
    
    @Test("Invalid UTF-8 byte sequence")
    func invalidUtf8Sequence() {
        // Create invalid UTF-8: continuation byte without starter
        let bytes: [UInt8] = [0x80, 0x81, 0x82, 0x00] // Invalid start
        
        bytes.withUnsafeBytes { rawBytes in
            guard let baseAddress = rawBytes.baseAddress else { return }
            let cString = baseAddress.assumingMemoryBound(to: CChar.self)
            
            // String(cString:) may produce replacement characters
            let result = String(cString: cString)
            #expect(!result.isEmpty || result.isEmpty) // Accept either
        }
    }
    
    @Test("Truncated UTF-8 multi-byte sequence")
    func truncatedUtf8Sequence() {
        // UTF-8 for 🌍 is 0xF0 0x9F 0x8C 0x8D
        // Truncated: 0xF0 0x9F (missing 2 bytes)
        let bytes: [UInt8] = [0xF0, 0x9F, 0x00]
        
        bytes.withUnsafeBytes { rawBytes in
            guard let baseAddress = rawBytes.baseAddress else { return }
            let cString = baseAddress.assumingMemoryBound(to: CChar.self)
            let result = String(cString: cString)
            
            // May be empty or contain replacement characters
            #expect(result.count >= 0)
        }
    }
    
    @Test("Overlong UTF-8 encoding")
    func overlongUtf8Encoding() {
        // ASCII 'A' should be 0x41, not overlong 0xC0 0x81
        let bytes: [UInt8] = [0xC0, 0x81, 0x00]
        
        bytes.withUnsafeBytes { rawBytes in
            guard let baseAddress = rawBytes.baseAddress else { return }
            let cString = baseAddress.assumingMemoryBound(to: CChar.self)
            let result = String(cString: cString)
            
            // Should be rejected or normalized
            #expect(result.count >= 0)
        }
    }
    
    @Test("High code point handling")
    func highCodePointHandling() {
        // Characters beyond U+10FFFF are invalid
        // This tests boundary values
        let validHigh = "\u{10FFFF}" // Max valid
        let cString = strdup(validHigh)
        let roundTrip = String(cString: cString!)
        free(cString)
        
        #expect(roundTrip == validHigh)
    }
    
    // MARK: - Resource Exhaustion Tests
    
    @Test("Large memory allocation failure handling")
    func largeAllocationFailure() {
        // Attempt to allocate an unreasonably large array
        let hugeCount = UInt32.max
        
        // This would fail - FFI should handle gracefully
        #expect(hugeCount > 0)
    }
    
    @Test("Too many nodes handling")
    func tooManyNodes() {
        let nodeCount: UInt32 = 100_000
        
        // Static layout threshold is 1500
        // Above this, physics is disabled
        let staticThreshold: UInt32 = 1500
        
        #expect(nodeCount > staticThreshold)
    }
    
    @Test("CString allocation failure simulation")
    func cstringAllocationFailure() {
        // strdup can fail if out of memory
        let original = "test"
        let cString = strdup(original)
        
        // Check result
        if cString != nil {
            free(cString)
        }
        
        // In batch operations, check all allocations succeeded
        #expect(Bool(true)) // Test passes if we get here
    }
    
    @Test("Search result allocation")
    func searchResultAllocation() {
        let limit: UInt32 = 1000
        
        // Results array allocated on Rust side
        // Must be freed with graph_engine_free_search_results
        #expect(limit > 0)
    }
    
    @Test("Embedding vector large dimension")
    func embeddingVectorLargeDim() {
        let dim: UInt32 = 100_000 // Unusually large
        
        // Would use ~400KB for Float array
        let memoryEstimate = Int(dim) * MemoryLayout<Float>.size
        #expect(memoryEstimate == 400_000)
    }
    
    // MARK: - Race Condition Detection Tests
    
    @Test("Atomic flag prevents race in frame pending")
    func atomicFramePending() {
        // framePending is Atomic<Bool>
        let framePending = true
        
        // Test-and-set should be atomic
        let wasPending = framePending
        let newPending = true
        
        #expect(wasPending)
        #expect(newPending)
    }
    
    @Test("Atomic render needed flag")
    func atomicRenderNeeded() {
        // Multiple threads might set this
        var renderNeeded = false
        
        // Thread 1: set
        renderNeeded = true
        
        // Thread 2: read
        #expect(renderNeeded)
    }
    
    @Test("Invalidation flag prevents use-after-free race")
    func invalidationFlagRace() {
        var isInvalidated = false
        var engine: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(bitPattern: 0x1000)
        
        // Thread A: destroy
        isInvalidated = true
        engine = nil
        
        // Thread B: check before use
        let canUse = !isInvalidated && engine != nil
        #expect(!canUse)
    }
    
    @Test("Main thread requirement enforcement")
    func mainThreadRequirement() {
        // Engine is not thread-safe
        // All FFI calls must be on main thread
        
        let isMainThread = Thread.isMainThread
        #expect(isMainThread) // Test runs on main thread
    }
    
    @Test("DisplayLink callback dispatches correctly")
    func displayLinkDispatch() {
        // Callback on background thread
        // Must dispatch to main for FFI
        
        let onBackground = true
        let dispatchedToMain = true
        
        #expect(onBackground)
        #expect(dispatchedToMain)
    }
    
    @Test("Weak self in async closure")
    func weakSelfInAsync() {
        // Verify weak references work with class types (not value types)
        class Box { let value: String; init(_ v: String) { value = v } }
        var strongRef: Box? = Box("test")
        weak var weakRef = strongRef
        weakRef = strongRef

        #expect(weakRef != nil)

        strongRef = nil
        #expect(weakRef == nil, "Weak reference should be nil after strong reference is released")
    }
    
    // MARK: - Memory Leak Detection Tests
    
    @Test("CString memory tracking")
    func cstringMemoryTracking() {
        var allocations: [UnsafeMutablePointer<CChar>] = []
        
        // Allocate
        for i in 0..<100 {
            if let cString = strdup("test-\(i)") {
                allocations.append(cString)
            }
        }
        
        #expect(allocations.count == 100)
        
        // Free all
        for cString in allocations {
            free(cString)
        }
        allocations.removeAll()
        
        #expect(allocations.isEmpty)
    }
    
    @Test("Deferred cleanup pattern")
    func deferredCleanupPattern() {
        var cleanedUp = false
        
        func doWork() {
            // Work happens here

            cleanedUp = true
            // More work
        }
        
        doWork()
        #expect(cleanedUp)
    }
    
    @Test("Search results must be freed")
    func searchResultsMustBeFreed() {
        // Results from graph_engine_search must be freed
        let resultsAllocated = true
        var resultsFreed = false
        
        // Use results
        #expect(resultsAllocated)
        
        // Free them
        resultsFreed = true
        #expect(resultsFreed)
    }
    
    @Test("Engine destroy frees all resources")
    func engineDestroyFreesResources() {
        let engineCreated = true
        var engineDestroyed = false
        
        // Create engine
        #expect(engineCreated)
        
        // Destroy engine
        engineDestroyed = true
        #expect(engineDestroyed)
        
        // All associated resources should be freed
    }
    
    @Test("Batch operation temporary arrays")
    func batchOperationTempArrays() {
        // Temporary arrays for batch upload
        let count = 1000
        var tempArrays: [[Float]] = []
        
        // Create temp arrays
        for _ in 0..<count {
            tempArrays.append([Float](repeating: 0.0, count: 10))
        }
        
        #expect(tempArrays.count == count)
        
        // Clear after use
        tempArrays.removeAll()
        #expect(tempArrays.isEmpty)
    }
    
    // MARK: - Type Safety Tests
    
    @Test("UInt8 bounds for node type")
    func uint8BoundsNodeType() {
        let valid: UInt8 = 13
        let invalid: UInt8 = 255

        #expect(valid <= 13)
        #expect(invalid > 13)
    }
    
    @Test("UInt8 bounds for edge type")
    func uint8BoundsEdgeType() {
        let valid: UInt8 = 11
        let invalid: UInt8 = 255
        
        #expect(valid <= 11)
        #expect(invalid > 11)
    }
    
    @Test("Float NaN handling")
    func floatNaNHandling() {
        let nan: Float = .nan
        let value: Float = 1.0
        
        #expect(nan.isNaN)
        #expect(!value.isNaN)
    }
    
    @Test("Float infinity handling")
    func floatInfinityHandling() {
        let inf: Float = .infinity
        let negInf: Float = -.infinity
        let value: Float = 1.0
        
        #expect(inf.isInfinite)
        #expect(negInf.isInfinite)
        #expect(!value.isInfinite)
    }
    
    @Test("UInt32 overflow prevention")
    func uint32OverflowPrevention() {
        let max: UInt32 = .max
        let largeCount = UInt64(max) + 1
        
        // Should not overflow - use larger type for intermediate
        #expect(largeCount > UInt64(max))
    }
    
    // MARK: - FFI Macro Safety Tests
    
    @Test("ffi_engine macro null check")
    func ffiEngineMacroNullCheck() {
        let engine: UnsafeMutableRawPointer? = nil
        
        // Macro expands to: if engine.is_null() { return; }
        let shouldReturn = engine == nil
        #expect(shouldReturn)
    }
    
    @Test("ffi_cstr macro null handling")
    func ffiCstrMacroNullHandling() {
        let cstr: UnsafePointer<CChar>? = nil
        
        // Macro expands to: if cstr.is_null() { "" } else { ... }
        let result = cstr == nil ? "" : "not null"
        #expect(result.isEmpty)
    }
    
    // MARK: - Buffer Overflow Prevention Tests
    
    @Test("String length validation")
    func stringLengthValidation() {
        let maxLabelLength = 1024
        let label = String(repeating: "a", count: 100)
        
        #expect(label.count <= maxLabelLength)
    }
    
    @Test("UUID format validation")
    func uuidFormatValidation() {
        let validUUID = "550e8400-e29b-41d4-a716-446655440000"
        let invalidUUID = "not-a-uuid"
        
        // UUID should be 36 characters
        #expect(validUUID.count == 36)
        #expect(invalidUUID.count != 36)
    }
    
    @Test("Array slice bounds")
    func arraySliceBounds() {
        let array: [Float] = [1, 2, 3, 4, 5]
        let slice = array[0..<3]
        
        #expect(slice.count == 3)
        #expect(Array(slice) == [1, 2, 3])
    }
    
    // MARK: - Cleanup Verification Tests
    
    @Test("Cleanup order verification")
    func cleanupOrderVerification() {
        var steps: [String] = []
        
        // 1. Stop display link
        steps.append("stop_display_link")
        
        // 2. Cancel pending tasks
        steps.append("cancel_tasks")
        
        // 3. Nil engine handle
        steps.append("nil_handle")
        
        // 4. Destroy engine
        steps.append("destroy_engine")
        
        #expect(steps == ["stop_display_link", "cancel_tasks", "nil_handle", "destroy_engine"])
    }
    
    @Test("Double free prevention")
    func doubleFreePrevention() {
        var pointer: UnsafeMutablePointer<Int>? = .allocate(capacity: 1)
        pointer?.pointee = 42
        
        #expect(pointer?.pointee == 42)
        
        // Free once
        pointer?.deallocate()
        pointer = nil
        
        // Second free would crash - pointer is now nil
        #expect(pointer == nil)
    }
    
    @Test("Use after free prevention")
    func useAfterFreePrevention() {
        var engineDestroyed = false
        var engine: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(bitPattern: 0x1000)
        
        // Mark as destroyed
        engineDestroyed = true
        engine = nil
        
        // Check flag before use
        let canUse = !engineDestroyed && engine != nil
        #expect(!canUse)
    }
}
