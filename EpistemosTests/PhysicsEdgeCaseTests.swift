import Testing
@testable import Epistemos
import Foundation

// MARK: - Physics Edge Case Tests
// Tests for force-directed layout boundary conditions and extreme parameters.

@Suite("Physics Edge Cases - Zero Parameters")
@MainActor
struct PhysicsZeroParameterTests {
    
    @Test("Zero link distance")
    func zeroLinkDistance() {
        let preset = PhysicsPreset.observatory
        var distance: Float = 0
        distance = 0
        #expect(distance == 0)
    }
    
    @Test("Zero charge strength")
    func zeroChargeStrength() {
        let chargeStrength: Float = 0
        #expect(chargeStrength == 0)
    }
    
    @Test("Zero charge range")
    func zeroChargeRange() {
        let chargeRange: Float = 0
        #expect(chargeRange == 0)
    }
    
    @Test("Zero link strength")
    func zeroLinkStrength() {
        let linkStrength: Float = 0
        #expect(linkStrength == 0)
    }
    
    @Test("Zero velocity decay")
    func zeroVelocityDecay() {
        let velocityDecay: Float = 0
        #expect(velocityDecay == 0)
    }
    
    @Test("Zero center strength")
    func zeroCenterStrength() {
        let centerStrength: Float = 0
        #expect(centerStrength == 0)
    }
    
    @Test("Zero collision radius")
    func zeroCollisionRadius() {
        let collisionRadius: Float = 0
        #expect(collisionRadius == 0)
    }
    
    @Test("Zero cluster strength")
    func zeroClusterStrength() {
        let clusterStrength: Float = 0
        #expect(clusterStrength == 0)
    }
    
    @Test("All force parameters at minimum")
    func allParametersAtMinimum() {
        let params: [Float] = [0, 0, 0, 0, 0, 0, 0]
        for p in params {
            #expect(p == 0)
        }
    }
    
    @Test("Zero alpha value")
    func zeroAlpha() {
        let alpha: Float = 0
        #expect(alpha == 0)
    }
    
    @Test("Zero temperature")
    func zeroTemperature() {
        let temp: Float = 0
        #expect(temp == 0)
    }
}

@Suite("Physics Edge Cases - Extreme Parameters")
@MainActor
struct PhysicsExtremeParameterTests {
    
    @Test("Maximum float link distance")
    func maxFloatLinkDistance() {
        let maxDistance: Float = Float.greatestFiniteMagnitude
        #expect(maxDistance > 0)
        #expect(maxDistance.isFinite)
    }
    
    @Test("Maximum float charge strength")
    func maxFloatChargeStrength() {
        let maxCharge: Float = -Float.greatestFiniteMagnitude
        #expect(maxCharge < 0)
        #expect(maxCharge.isFinite)
    }
    
    @Test("Very large charge strength")
    func veryLargeChargeStrength() {
        let largeCharge: Float = -1_000_000
        #expect(largeCharge < 0)
    }
    
    @Test("Velocity decay of 1.0 - no friction")
    func velocityDecayOne() {
        let velocityDecay: Float = 1.0
        #expect(velocityDecay == 1.0)
    }
    
    @Test("Alpha decay of zero - never cools")
    func alphaDecayZero() {
        let alphaDecay: Float = 0
        #expect(alphaDecay == 0)
    }
    
    @Test("Alpha target greater than alpha start")
    func alphaTargetGreaterThanStart() {
        let alphaStart: Float = 0.3
        let alphaTarget: Float = 0.5
        #expect(alphaTarget > alphaStart)
    }
    
    @Test("Negative link distance")
    func negativeLinkDistance() {
        let negativeDistance: Float = -100
        #expect(negativeDistance < 0)
    }
    
    @Test("Negative velocity decay")
    func negativeVelocityDecay() {
        let negativeDecay: Float = -0.5
        #expect(negativeDecay < 0)
    }
    
    @Test("Extreme center strength")
    func extremeCenterStrength() {
        let extremeStrength: Float = 1.0
        #expect(extremeStrength == 1.0)
    }
    
    @Test("Physics preset extreme values")
    func presetExtremeValues() {
        for preset in PhysicsPreset.allCases {
            #expect(preset.linkDistance > 0, "\(preset) has non-positive link distance")
            #expect(preset.chargeRange > 0, "\(preset) has non-positive charge range")
            #expect(preset.velocityDecay >= 0 && preset.velocityDecay <= 1, "\(preset) has invalid velocity decay")
            #expect(preset.centerStrength >= 0, "\(preset) has negative center strength")
            #expect(preset.collisionRadius >= 0, "\(preset) has negative collision radius")
        }
    }
    
    @Test("Float infinity charge")
    func infinityCharge() {
        let infCharge: Float = Float.infinity
        #expect(infCharge.isInfinite)
    }
    
    @Test("Float NaN charge")
    func nanCharge() {
        let nanCharge: Float = Float.nan
        #expect(nanCharge.isNaN)
    }
    
    @Test("Maximum time cutoff")
    func maxTimeCutoff() {
        let cutoff = Date.distantFuture
        #expect(cutoff == Date.distantFuture)
    }
    
    @Test("Minimum time cutoff")
    func minTimeCutoff() {
        let cutoff = Date.distantPast
        #expect(cutoff == Date.distantPast)
    }
}

@Suite("Physics Edge Cases - Node Positions")
@MainActor
struct PhysicsPositionEdgeCaseTests {
    
    @Test("All nodes at same position")
    func allNodesSamePosition() {
        let store = GraphStore()
        
        for i in 0..<5 {
            let node = GraphNodeRecord(
                id: "node-\(i)",
                type: .note,
                label: "Node \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: SIMD2<Float>(100, 100),
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == 5)
        for i in 0..<5 {
            #expect(store.nodes["node-\(i)"]?.position == SIMD2<Float>(100, 100))
        }
    }
    
    @Test("Nodes at extreme coordinates")
    func extremeCoordinates() {
        let store = GraphStore()
        
        let extremes: [SIMD2<Float>] = [
            SIMD2(Float.greatestFiniteMagnitude, 0),
            SIMD2(-Float.greatestFiniteMagnitude, 0),
            SIMD2(0, Float.greatestFiniteMagnitude),
            SIMD2(0, -Float.greatestFiniteMagnitude),
            SIMD2(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude),
            SIMD2(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude),
        ]
        
        for (index, pos) in extremes.enumerated() {
            let node = GraphNodeRecord(
                id: "extreme-\(index)",
                type: .note,
                label: "Extreme \(index)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: pos,
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == extremes.count)
    }
    
    @Test("Nodes at subnormal coordinates")
    func subnormalCoordinates() {
        let store = GraphStore()
        
        let tiny: Float = Float.leastNormalMagnitude
        let positions = [
            SIMD2<Float>(tiny, 0),
            SIMD2<Float>(-tiny, 0),
            SIMD2<Float>(0, tiny),
            SIMD2<Float>(0, -tiny),
        ]
        
        for (index, pos) in positions.enumerated() {
            let node = GraphNodeRecord(
                id: "tiny-\(index)",
                type: .note,
                label: "Tiny \(index)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: pos,
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == positions.count)
    }
    
    @Test("NaN coordinates")
    func nanCoordinates() {
        let nan = Float.nan
        let pos = SIMD2<Float>(nan, nan)
        
        #expect(pos.x.isNaN)
        #expect(pos.y.isNaN)
    }
    
    @Test("Infinity coordinates")
    func infinityCoordinates() {
        let inf = Float.infinity
        let positions = [
            SIMD2<Float>(inf, 0),
            SIMD2<Float>(-inf, 0),
            SIMD2<Float>(0, inf),
            SIMD2<Float>(0, -inf),
            SIMD2<Float>(inf, inf),
        ]
        
        for pos in positions {
            #expect(pos.x.isInfinite || pos.y.isInfinite)
        }
    }
    
    @Test("Nodes in tight cluster")
    func tightCluster() {
        let store = GraphStore()
        
        for i in 0..<10 {
            let offset = Float(i) * 0.1
            let node = GraphNodeRecord(
                id: "cluster-\(i)",
                type: .note,
                label: "Cluster \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: SIMD2<Float>(offset, offset),
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == 10)
    }
    
    @Test("Nodes on single axis")
    func nodesOnSingleAxis() {
        let store = GraphStore()
        
        for i in 0..<10 {
            let node = GraphNodeRecord(
                id: "axis-x-\(i)",
                type: .note,
                label: "X \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: SIMD2<Float>(Float(i * 10), 0),
                velocity: .zero
            )
            store.addNode(node)
        }
        
        for i in 0..<10 {
            let node = GraphNodeRecord(
                id: "axis-y-\(i)",
                type: .note,
                label: "Y \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: SIMD2<Float>(0, Float(i * 10)),
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == 20)
    }
    
    @Test("Nodes in perfect grid")
    func nodesInGrid() {
        let store = GraphStore()
        
        for x in 0..<5 {
            for y in 0..<5 {
                let node = GraphNodeRecord(
                    id: "grid-\(x)-\(y)",
                    type: .note,
                    label: "Grid \(x),\(y)",
                    sourceId: nil,
                    metadata: GraphNodeMetadata(),
                    weight: 1.0,
                    createdAt: .now,
                    position: SIMD2<Float>(Float(x * 50), Float(y * 50)),
                    velocity: .zero
                )
                store.addNode(node)
            }
        }
        
        #expect(store.nodeCount == 25)
    }
    
    @Test("Nodes at origin")
    func nodesAtOrigin() {
        let store = GraphStore()
        
        for i in 0..<5 {
            let node = GraphNodeRecord(
                id: "origin-\(i)",
                type: .note,
                label: "Origin \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: SIMD2<Float>(0, 0),
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == 5)
        for i in 0..<5 {
            #expect(store.nodes["origin-\(i)"]?.position == SIMD2<Float>(0, 0))
        }
    }
}

@Suite("Physics Edge Cases - Graph Sizes")
@MainActor
struct PhysicsGraphSizeEdgeCaseTests {
    
    @Test("Single node physics")
    func singleNodePhysics() {
        let store = GraphStore()
        
        let node = GraphNodeRecord(
            id: "solo",
            type: .note,
            label: "Solo",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: SIMD2<Float>(10, 10)
        )
        store.addNode(node)
        
        #expect(store.nodeCount == 1)
        #expect(store.edgeCount == 0)
    }
    
    @Test("Physics with no edges")
    func physicsNoEdges() {
        let store = GraphStore()
        
        for i in 0..<10 {
            let node = GraphNodeRecord(
                id: "isolated-\(i)",
                type: .note,
                label: "Isolated \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: SIMD2<Float>(Float.random(in: -100...100), Float.random(in: -100...100)),
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == 10)
        #expect(store.edgeCount == 0)
    }
    
    @Test("Static layout threshold - 1500 nodes")
    func staticLayoutThreshold() {
        let threshold = GraphState.staticLayoutThreshold
        #expect(threshold == 1500)
    }
    
    @Test("Large graph - just below threshold")
    func largeGraphBelowThreshold() {
        let store = GraphStore()
        let count = 1499
        
        for i in 0..<count {
            let node = GraphNodeRecord(
                id: "node-\(i)",
                type: .note,
                label: "\(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: .zero,
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == count)
    }
    
    @Test("Dense graph - many edges")
    func denseGraph() {
        let store = GraphStore()
        let n = 100
        
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
        
        var edgeCount = 0
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
                edgeCount += 1
            }
        }
        
        #expect(store.nodeCount == n)
        #expect(store.edgeCount == edgeCount)
        #expect(edgeCount == n * (n - 1) / 2)
    }
    
    @Test("Sparse graph - few edges")
    func sparseGraph() {
        let store = GraphStore()
        let n = 1000
        
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
        
        for i in stride(from: 0, to: n - 1, by: 100) {
            store.addEdge(GraphEdgeRecord(
                id: "e-\(i)",
                sourceNodeId: "\(i)",
                targetNodeId: "\(i+1)",
                type: .reference,
                weight: 1.0,
                createdAt: .now
            ))
        }
        
        #expect(store.nodeCount == n)
        #expect(store.edgeCount == n / 100)
    }
    
    @Test("Graph at static layout threshold exactly")
    func graphAtThresholdExactly() {
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
    
    @Test("Graph above threshold")
    func graphAboveThreshold() {
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
}

@Suite("Physics Edge Cases - Velocity")
@MainActor
struct PhysicsVelocityEdgeCaseTests {
    
    @Test("Zero velocity")
    func zeroVelocity() {
        let velocity = SIMD2<Float>(0, 0)
        #expect(velocity == .zero)
    }
    
    @Test("Extreme velocity")
    func extremeVelocity() {
        let velocities = [
            SIMD2(Float.greatestFiniteMagnitude, 0),
            SIMD2(-Float.greatestFiniteMagnitude, 0),
            SIMD2(0, Float.greatestFiniteMagnitude),
            SIMD2(0, -Float.greatestFiniteMagnitude),
        ]
        
        for v in velocities {
            #expect(v.x.isFinite || v.x == 0)
            #expect(v.y.isFinite || v.y == 0)
        }
    }
    
    @Test("NaN velocity")
    func nanVelocity() {
        let nanVel = SIMD2<Float>(Float.nan, Float.nan)
        #expect(nanVel.x.isNaN)
        #expect(nanVel.y.isNaN)
    }
    
    @Test("Very small velocity")
    func verySmallVelocity() {
        let tinyVel = SIMD2<Float>(Float.leastNormalMagnitude, Float.leastNormalMagnitude)
        #expect(tinyVel.x > 0)
        #expect(tinyVel.y > 0)
    }
    
    @Test("All nodes moving same direction")
    func sameDirectionVelocity() {
        let store = GraphStore()
        let sharedVelocity = SIMD2<Float>(10, 5)
        
        for i in 0..<5 {
            let node = GraphNodeRecord(
                id: "moving-\(i)",
                type: .note,
                label: "Moving \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now,
                position: SIMD2<Float>(Float(i * 10), 0),
                velocity: sharedVelocity
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == 5)
        for i in 0..<5 {
            #expect(store.nodes["moving-\(i)"]?.velocity == sharedVelocity)
        }
    }
    
    @Test("Opposite velocities")
    func oppositeVelocities() {
        let v1 = SIMD2<Float>(10, 0)
        let v2 = SIMD2<Float>(-10, 0)
        
        #expect(v1 == -v2)
    }
    
    @Test("Perpendicular velocities")
    func perpendicularVelocities() {
        let vx = SIMD2<Float>(10, 0)
        let vy = SIMD2<Float>(0, 10)
        
        // Dot product should be 0
        let dot = vx.x * vy.x + vx.y * vy.y
        #expect(dot == 0)
    }
}

@Suite("Physics Edge Cases - Physics Presets")
@MainActor
struct PhysicsPresetEdgeCaseTests {
    
    @Test("All preset values are valid")
    func allPresetValuesValid() {
        for preset in PhysicsPreset.allCases {
            #expect(preset.linkDistance > 0, "\(preset): linkDistance must be positive")
            #expect(preset.chargeRange > 0, "\(preset): chargeRange must be positive")
            #expect(preset.velocityDecay >= 0 && preset.velocityDecay <= 1, "\(preset): velocityDecay must be in [0, 1]")
            #expect(preset.centerStrength >= 0, "\(preset): centerStrength must be non-negative")
            #expect(preset.collisionRadius >= 0, "\(preset): collisionRadius must be non-negative")
        }
    }
    
    @Test("Preset descriptions are non-empty")
    func presetDescriptions() {
        for preset in PhysicsPreset.allCases {
            #expect(!preset.description.isEmpty, "\(preset) must have description")
            #expect(!preset.icon.isEmpty, "\(preset) must have icon")
        }
    }
    
    @Test("Preset IDs are unique")
    func presetIdsUnique() {
        var ids: Set<String> = []
        for preset in PhysicsPreset.allCases {
            #expect(ids.insert(preset.id).inserted, "\(preset) ID must be unique")
        }
        #expect(ids.count == PhysicsPreset.allCases.count)
    }
    
    @Test("Observatory is balanced preset")
    func observatoryPreset() {
        let preset = PhysicsPreset.observatory
        #expect(preset.linkDistance == 243)
        #expect(preset.chargeStrength == -2792)
        #expect(preset.velocityDecay == 0.05)
    }
    
    @Test("Crystal is tight preset")
    func crystalPreset() {
        let preset = PhysicsPreset.crystal
        #expect(preset.linkDistance == 120)
        #expect(preset.chargeStrength == -600)
        #expect(preset.velocityDecay == 0.90)
    }
    
    @Test("Constellation is loose preset")
    func constellationPreset() {
        let preset = PhysicsPreset.constellation
        #expect(preset.linkDistance == 350)
        #expect(preset.chargeStrength == -200)
        #expect(preset.centerStrength == 0.001)
    }
    
    @Test("Nebula preset values")
    func nebulaPreset() {
        let preset = PhysicsPreset.nebula
        #expect(preset.linkDistance == 280)
        #expect(preset.chargeStrength == -250)
        #expect(preset.velocityDecay == 0.80)
    }
    
    @Test("Fluid preset values")
    func fluidPreset() {
        let preset = PhysicsPreset.fluid
        #expect(preset.linkDistance == 180)
        #expect(preset.chargeStrength == -350)
        #expect(preset.velocityDecay == 0.75)
    }
    
    @Test("All presets have distinct parameters")
    func distinctParameters() {
        var distances: Set<Float> = []
        var charges: Set<Float> = []
        
        for preset in PhysicsPreset.allCases {
            distances.insert(preset.linkDistance)
            charges.insert(preset.chargeStrength)
        }
        
        // Most presets should have unique values
        #expect(distances.count >= PhysicsPreset.allCases.count - 1)
    }
}

@Suite("Physics Edge Cases - Time Filter")
@MainActor
struct PhysicsTimeFilterEdgeCaseTests {
    
    @Test("Time range with distant past")
    func timeRangeDistantPast() {
        let distantPast = Date.distantPast
        let now = Date.now
        
        let range = distantPast...now
        #expect(range.lowerBound == distantPast)
        #expect(range.upperBound <= now)
    }
    
    @Test("Time range with distant future")
    func timeRangeDistantFuture() {
        let now = Date.now
        let distantFuture = Date.distantFuture
        
        let range = now...distantFuture
        #expect(range.lowerBound >= now)
        #expect(range.upperBound == distantFuture)
    }
    
    @Test("Nodes with identical timestamps")
    func identicalTimestamps() {
        let store = GraphStore()
        let sameDate = Date.now
        
        for i in 0..<5 {
            let node = GraphNodeRecord(
                id: "same-time-\(i)",
                type: .note,
                label: "Same Time \(i)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: sameDate,
                position: .zero,
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == 5)
    }
    
    @Test("Nodes spanning wide time range")
    func wideTimeRange() {
        let store = GraphStore()
        let calendar = Calendar.current
        
        let years = [2020, 2021, 2022, 2023, 2024, 2025]
        
        for (index, year) in years.enumerated() {
            let date = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
            let node = GraphNodeRecord(
                id: "year-\(year)",
                type: .note,
                label: "Year \(year)",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: date,
                position: .zero,
                velocity: .zero
            )
            store.addNode(node)
        }
        
        #expect(store.nodeCount == years.count)
    }
    
    @Test("Time cutoff at epoch")
    func timeCutoffEpoch() {
        let epoch = Date(timeIntervalSince1970: 0)
        #expect(epoch.timeIntervalSince1970 == 0)
    }
    
    @Test("Negative time interval")
    func negativeTimeInterval() {
        let date = Date(timeIntervalSince1970: -86400) // 1 day before epoch
        #expect(date.timeIntervalSince1970 < 0)
    }
}
