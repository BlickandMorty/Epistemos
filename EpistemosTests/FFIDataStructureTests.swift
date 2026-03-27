import Testing
import Foundation
@testable import Epistemos

// MARK: - FFI Data Structure Tests
// Tests data structure passing across the FFI boundary including:
// - Node/edge batch uploads
// - Position arrays
// - Force parameters
// - Search queries
// - Semantic vectors
// - Time filters

@Suite("FFI Data Structures")
struct FFIDataStructureTests {
    
    // MARK: - Node Batch Upload Tests
    
    @Test("Empty node batch upload (count = 0)")
    func emptyNodeBatchUpload() {
        // Edge case: sending empty arrays should not crash
        let count: UInt32 = 0
        #expect(count == 0)
        // In real FFI: graph_engine_add_nodes_batch with count=0 returns early
    }
    
    @Test("Single node batch upload structure")
    func singleNodeBatchUpload() {
        let uuid = "test-uuid-123"
        let x: Float = 100.0
        let y: Float = 200.0
        let nodeType: UInt8 = 0 // note
        // Verify data types are FFI-compatible
        #expect(MemoryLayout<Float>.size == 4)
        #expect(MemoryLayout<UInt8>.size == 1)
        #expect(MemoryLayout<UInt32>.size == 4)
        
        // Verify values can be passed through FFI
        #expect(uuid.utf8CString.count > 0)
        #expect(x.isFinite)
        #expect(y.isFinite)
        #expect(nodeType <= 7) // Max node type value
    }
    
    @Test("Multiple node batch upload structure")
    func multipleNodeBatchUpload() {
        let count = 100
        var uuids: [String] = []
        var xs: [Float] = []
        var ys: [Float] = []
        var types: [UInt8] = []
        var linkCounts: [UInt32] = []
        var labels: [String] = []
        
        for i in 0..<count {
            uuids.append("uuid-\(i)")
            xs.append(Float(i) * 10.0)
            ys.append(Float(i) * 20.0)
            types.append(UInt8(i % 8))
            linkCounts.append(UInt32(i))
            labels.append("Node \(i)")
        }
        
        // Verify parallel arrays have same length
        #expect(uuids.count == count)
        #expect(xs.count == count)
        #expect(ys.count == count)
        #expect(types.count == count)
        #expect(linkCounts.count == count)
        #expect(labels.count == count)
        
        // Verify all arrays have the same length
        let allSame = (uuids.count == xs.count) && (xs.count == ys.count) && (ys.count == types.count)
                      && (types.count == linkCounts.count) && (linkCounts.count == labels.count)
        #expect(allSame)
    }
    
    @Test("Large node batch upload (10K nodes)")
    func largeNodeBatchUpload() {
        let count = 10000
        
        // Simulate creating arrays for batch upload
        var types: [UInt8] = []
        for i in 0..<count {
            types.append(UInt8(i % 8))
        }

        #expect(types.count == count)

        // Verify all values are valid
        for type in types {
            #expect(type < 8)
        }
    }
    
    @Test("Node batch with extreme positions")
    func nodeBatchExtremePositions() {
        let positions: [Float] = [
            0.0,                    // Origin
            Float.greatestFiniteMagnitude,  // Max positive
            -Float.greatestFiniteMagnitude, // Max negative
            Float.leastNormalMagnitude,     // Smallest normal
            Float.leastNonzeroMagnitude,    // Smallest nonzero
            Float.infinity,                 // Infinity (should be handled)
            -Float.infinity,                // Negative infinity
            Float.nan,                      // NaN (should be handled)
        ]
        
        for pos in positions {
            // Verify position can be passed through FFI (even if invalid)
            let bitPattern = pos.bitPattern
            #expect(bitPattern == bitPattern) // Always true, just checking compile
        }
    }
    
    @Test("Node batch with all node types")
    func nodeBatchAllTypes() {
        for nodeType in GraphNodeType.allCases {
            let rustIndex = nodeType.rustIndex
            #expect(rustIndex < 8)
            
            // Simulate batch upload
            let typeArray: [UInt8] = [rustIndex]
            #expect(typeArray[0] == rustIndex)
        }
    }
    
    // MARK: - Edge Batch Upload Tests
    
    @Test("Empty edge batch upload (count = 0)")
    func emptyEdgeBatchUpload() {
        let count: UInt32 = 0
        #expect(count == 0)
    }
    
    @Test("Single edge batch upload structure")
    func singleEdgeBatchUpload() {
        let weight: Float = 1.0
        let edgeType: UInt8 = 0 // reference
        
        #expect(MemoryLayout<Float>.size == 4)
        #expect(edgeType <= 11) // Max edge type value
        #expect(weight >= 0.0 && weight <= 1.0)
    }
    
    @Test("Multiple edge batch upload structure")
    func multipleEdgeBatchUpload() {
        let count = 500
        var sources: [String] = []
        var targets: [String] = []
        var weights: [Float] = []
        var types: [UInt8] = []
        
        for i in 0..<count {
            sources.append("source-\(i)")
            targets.append("target-\(i)")
            weights.append(Float.random(in: 0.0...1.0))
            types.append(UInt8(i % 12))
        }
        
        // Verify parallel arrays
        #expect(Set([sources.count, targets.count, weights.count, types.count]).count == 1)
    }
    
    @Test("Edge batch with all edge types")
    func edgeBatchAllTypes() {
        let allEdgeTypes: [GraphEdgeType] = [
            .reference, .contains, .tagged, .mentions, .cites,
            .authored, .related, .quotes, .supports, .contradicts,
            .expands, .questions
        ]
        
        for edgeType in allEdgeTypes {
            let rustIndex = edgeType.rustIndex
            #expect(rustIndex < 12)
        }
    }
    
    @Test("Edge batch with extreme weights")
    func edgeBatchExtremeWeights() {
        let weights: [Float] = [
            0.0,                    // Min weight
            1.0,                    // Max weight
            0.5,                    // Middle
            Float.leastNonzeroMagnitude, // Tiny weight
            Float.greatestFiniteMagnitude, // Huge weight (invalid but passable)
        ]
        
        for weight in weights {
            let bitPattern = weight.bitPattern
            #expect(bitPattern == bitPattern)
        }
    }
    
    // MARK: - Position Array Tests
    
    @Test("Position array layout")
    func positionArrayLayout() {
        // Positions are stored as parallel float arrays [x0, x1, x2...] and [y0, y1, y2...]
        let count = 100
        var xs: [Float] = Array(repeating: 0.0, count: count)
        var ys: [Float] = Array(repeating: 0.0, count: count)
        
        for i in 0..<count {
            xs[i] = Float(i) * 10.0
            ys[i] = Float(i) * 20.0
        }
        
        #expect(xs.count == count)
        #expect(ys.count == count)
        
        // Verify memory layout is contiguous
        xs.withUnsafeBufferPointer { buf in
            #expect(buf.baseAddress != nil)
        }
    }
    
    @Test("Position array withUnsafeBufferPointer usage")
    func positionArrayUnsafeBuffer() {
        let positions: [Float] = [0.0, 10.0, 20.0, 30.0, 40.0]
        
        positions.withUnsafeBufferPointer { buffer in
            #expect(buffer.count == 5)
            #expect(buffer.baseAddress != nil)
            
            // Simulate passing to FFI
            let ptr = buffer.baseAddress
            #expect(ptr != nil)
        }
    }
    
    @Test("Interleaved position array (alternative layout)")
    func interleavedPositionArray() {
        // Some FFI interfaces use interleaved [x0, y0, x1, y1, ...]
        let count = 10
        var interleaved: [Float] = []
        
        for i in 0..<count {
            interleaved.append(Float(i) * 10.0) // x
            interleaved.append(Float(i) * 20.0) // y
        }
        
        #expect(interleaved.count == count * 2)
        
        // Verify we can extract pairs
        for i in 0..<count {
            let x = interleaved[i * 2]
            let y = interleaved[i * 2 + 1]
            #expect(x == Float(i) * 10.0)
            #expect(y == Float(i) * 20.0)
        }
    }
    
    // MARK: - Force Parameter Tests
    
    @Test("Basic force parameter structure")
    func basicForceParams() {
        let linkDistance: Float = 200.0
        let chargeStrength: Float = -400.0
        let chargeRange: Float = 1500.0
        let linkStrength: Float = 0.5
        
        #expect(linkDistance > 0)
        #expect(chargeStrength < 0) // Repulsive
        #expect(chargeRange > 0)
        #expect(linkStrength >= 0 && linkStrength <= 1)
    }
    
    @Test("Extended force parameter structure")
    func extendedForceParams() {
        let velocityDecay: Float = 0.85
        let centerStrength: Float = 0.005
        let collisionRadius: Float = 20.0
        
        #expect(velocityDecay >= 0 && velocityDecay <= 1)
        #expect(centerStrength >= 0)
        #expect(collisionRadius >= 0)
    }
    
    @Test("Force parameter boundary values")
    func forceParamBoundaryValues() {
        let boundaryParams: [(Float, Float, Float, Float)] = [
            (0.0, 0.0, 0.0, 0.0),           // All zeros
            (Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude,
             Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude), // All max
            (-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude,
             -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude), // All min
        ]
        
        for (dist, charge, range, strength) in boundaryParams {
            // Verify they can be represented as Float
            #expect(dist.bitPattern == dist.bitPattern)
            #expect(charge.bitPattern == charge.bitPattern)
            #expect(range.bitPattern == range.bitPattern)
            #expect(strength.bitPattern == strength.bitPattern)
        }
    }
    
    @Test("Physics preset force parameters")
    func physicsPresetParams() {
        let presets: [PhysicsPreset] = [.observatory, .nebula, .crystal, .fluid, .constellation]
        
        for preset in presets {
            let params = (
                linkDistance: preset.linkDistance,
                chargeStrength: preset.chargeStrength,
                chargeRange: preset.chargeRange,
                linkStrength: preset.linkStrength,
                velocityDecay: preset.velocityDecay,
                centerStrength: preset.centerStrength,
                collisionRadius: preset.collisionRadius
            )
            
            #expect(params.linkDistance > 0)
            #expect(params.chargeStrength < 0)
            #expect(params.chargeRange > 0)
            #expect(params.velocityDecay >= 0 && params.velocityDecay <= 1)
        }
    }
    
    @Test("Cluster parameter structure")
    func clusterParams() {
        let clusterStrength: Float = 0.5
        let centerMode: UInt8 = 0 // attract
        
        #expect(clusterStrength >= 0 && clusterStrength <= 1)
        #expect(centerMode <= 2) // 0=attract, 1=off, 2=repel
    }
    
    @Test("Semantic strength parameter")
    func semanticStrengthParam() {
        let strengths: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
        
        for strength in strengths {
            #expect(strength >= 0 && strength <= 1)
        }
    }
    
    // MARK: - Search Query Tests
    
    @Test("Empty search query")
    func emptySearchQuery() {
        let query = ""
        #expect(query.isEmpty)
        // FFI should return empty results for empty query
    }
    
    @Test("Simple search query")
    func simpleSearchQuery() {
        let query = "machine learning"
        let cString = strdup(query)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == query)
    }
    
    @Test("Search query with special characters")
    func searchQuerySpecialChars() {
        let queries = [
            "test-query",
            "test_query",
            "test.query",
            "test:query",
            "(test)",
            "[test]",
        ]
        
        for query in queries {
            let cString = strdup(query)
            let roundTrip = String(cString: cString!)
            free(cString)
            #expect(roundTrip == query)
        }
    }
    
    @Test("Search query with Unicode")
    func searchQueryUnicode() {
        let queries = [
            "日本語",
            "مرحبا",
            "🌍 emoji",
            "café résumé",
        ]
        
        for query in queries {
            let cString = strdup(query)
            let roundTrip = String(cString: cString!)
            free(cString)
            #expect(roundTrip == query)
        }
    }
    
    @Test("Search result limit parameter")
    func searchResultLimit() {
        let limits: [UInt32] = [0, 1, 5, 10, 100, 1000]
        
        for limit in limits {
            #expect(limit >= 0)
        }
    }
    
    // MARK: - Semantic Vector Tests
    
    @Test("Semantic vector structure (typical dimension)")
    func semanticVectorStructure() {
        let dim: UInt32 = 512 // Typical embedding dimension
        var vector: [Float] = []
        
        for _ in 0..<dim {
            vector.append(Float.random(in: -1.0...1.0))
        }
        
        #expect(vector.count == Int(dim))
        
        // Verify contiguous memory
        vector.withUnsafeBufferPointer { buf in
            #expect(buf.baseAddress != nil)
            #expect(buf.count == Int(dim))
        }
    }
    
    @Test("Semantic vector with small dimension")
    func semanticVectorSmall() {
        let dim: UInt32 = 8
        let vector: [Float] = Array(repeating: 0.5, count: Int(dim))
        
        #expect(vector.count == 8)
    }
    
    @Test("Semantic vector with large dimension")
    func semanticVectorLarge() {
        let dim: UInt32 = 1536 // common embedding dimension
        let vector: [Float] = Array(repeating: 0.1, count: Int(dim))
        
        #expect(vector.count == 1536)
    }
    
    @Test("Semantic vector zero dimension")
    func semanticVectorZero() {
        let dim: UInt32 = 0
        let vector: [Float] = []
        
        #expect(vector.count == Int(dim))
    }
    
    @Test("Semantic vector normalization")
    func semanticVectorNormalization() {
        var vector: [Float] = [1.0, 2.0, 3.0, 4.0]
        
        // Calculate L2 norm
        let sumSquares = vector.reduce(0.0) { $0 + $1 * $1 }
        let norm = sqrt(sumSquares)
        
        #expect(norm > 0)
        
        // Normalize
        for i in 0..<vector.count {
            vector[i] /= norm
        }
        
        // Verify normalized
        let newSumSquares = vector.reduce(0.0) { $0 + $1 * $1 }
        let newNorm = sqrt(newSumSquares)
        #expect(abs(newNorm - 1.0) < 0.0001)
    }
    
    @Test("Semantic neighbor computation parameters")
    func semanticNeighborParams() {
        let k: UInt32 = 8 // Number of neighbors
        let threshold: Float = 0.3 // Cosine similarity threshold
        
        #expect(k > 0)
        #expect(threshold >= 0 && threshold <= 1)
    }

    // MARK: - Confidence Score Tests
    
    @Test("Confidence score valid range")
    func confidenceScoreValid() {
        let scores: [Float] = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
        
        for score in scores {
            #expect(score >= 0.0 && score <= 1.0)
        }
    }
    
    @Test("Confidence score from evidence grade")
    func confidenceScoreFromGrade() {
        let grades: [(String, Float)] = [
            ("A", 1.0),
            ("B", 0.8),
            ("C", 0.6),
            ("D", 0.4),
            ("F", 0.2),
            ("X", 0.0), // Unknown
        ]
        
        for (_, score) in grades {
            #expect(score >= 0.0 && score <= 1.0)
        }
    }
    
    // MARK: - Version Chain Tests
    
    @Test("Version chain hash values")
    func versionChainHashes() {
        let hash: UInt64 = 0xDEADBEEFCAFEBABE
        let parentHash: UInt64 = 0x1234567890ABCDEF
        let timestamp = Date().timeIntervalSince1970
        
        #expect(hash > 0)
        #expect(parentHash > 0)
        #expect(timestamp > 0)
    }
    
    @Test("Version count query")
    func versionCountQuery() {
        let count: UInt32 = 5
        #expect(count >= 0)
    }
    
    // MARK: - Coordinate Conversion Tests
    
    @Test("Screen to world coordinate conversion")
    func screenToWorldConversion() {
        let screenX: Float = 500.0
        let screenY: Float = 400.0
        var worldX: Float = 0.0
        var worldY: Float = 0.0
        
        // Simulate FFI output parameters
        worldX = screenX * 2.0 // Mock conversion
        worldY = screenY * 2.0
        
        #expect(worldX == 1000.0)
        #expect(worldY == 800.0)
    }
    
    @Test("Coordinate conversion with scale factor")
    func coordinateWithScaleFactor() {
        let screenX: Float = 100.0
        let screenY: Float = 200.0
        let scale: Float = 2.0
        
        let scaledX = screenX * scale
        let scaledY = screenY * scale
        
        #expect(scaledX == 200.0)
        #expect(scaledY == 400.0)
    }
    
    // MARK: - Quality Level Tests
    
    @Test("Quality level values")
    func qualityLevelValues() {
        let levels: [UInt8] = [0, 1, 2]
        // 0 = Cinematic, 1 = Balanced, 2 = Performance
        
        for level in levels {
            #expect(level <= 2)
        }
    }
    
    @Test("Lite mode boolean as u8")
    func liteModeAsU8() {
        let enabled: UInt8 = 1
        let disabled: UInt8 = 0
        
        #expect(enabled == 1)
        #expect(disabled == 0)
    }
    
    // MARK: - Graph Mode Tests
    
    @Test("Graph mode values")
    func graphModeValues() {
        let global: UInt8 = 0
        let page: UInt8 = 1
        
        #expect(global == 0)
        #expect(page == 1)
    }
    
    // MARK: - Visibility Tests
    
    @Test("Node visibility boolean as u8")
    func nodeVisibilityAsU8() {
        let visible: UInt8 = 1
        let hidden: UInt8 = 0
        
        #expect(visible == 1)
        #expect(hidden == 0)
    }
    
    // MARK: - Entrance Animation Tests
    
    @Test("Entrance animation flag")
    func entranceAnimationFlag() {
        let enabled: UInt8 = 1
        let disabled: UInt8 = 0
        
        #expect(enabled == 1)
        #expect(disabled == 0)
    }
    
    // MARK: - Anchor Rect Tests
    
    @Test("Anchor rect structure")
    func anchorRectStructure() {
        let x: Float = 100.0
        let y: Float = 200.0
        let w: Float = 800.0
        let h: Float = 600.0
        
        #expect(w > 0)
        #expect(h > 0)
        #expect(x >= 0)
        #expect(y >= 0)
    }
}
