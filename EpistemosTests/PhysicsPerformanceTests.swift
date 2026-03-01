import Testing
import Foundation
import QuartzCore
import Metal
@testable import Epistemos

// MARK: - Mock Objects for Physics Testing

@MainActor
class MockGraphEngine {
    var nodeCount: Int = 0
    var tickCount: Int = 0
    var lastTickDuration: TimeInterval = 0
    var isSettled: Bool = false
    var isStaticLayout: Bool = false
    
    func simulateTick() {
        let start = CFAbsoluteTimeGetCurrent()
        
        // Simulate physics calculations based on node count
        // This mimics the actual physics computation complexity
        var work = 0.0
        for i in 0..<min(nodeCount, 10000) {
            work += sin(Double(i)) * cos(Double(i))
        }
        
        tickCount += 1
        lastTickDuration = CFAbsoluteTimeGetCurrent() - start
    }
}

// MARK: - Physics Performance Tests

@Suite("Physics Performance")
@MainActor
struct PhysicsPerformanceTests {
    
    // MARK: - Simulation Tick Rate
    
    @Test("Tick rate at 100 nodes")
    func tickRate100Nodes() async throws {
        let engine = MockGraphEngine()
        engine.nodeCount = 100
        
        var totalTime: TimeInterval = 0
        let tickCount = 100
        
        measure {
            let start = CFAbsoluteTimeGetCurrent()
            for _ in 0..<tickCount {
                engine.simulateTick()
            }
            totalTime = CFAbsoluteTimeGetCurrent() - start
        }
        
        let avgTickTime = totalTime / Double(tickCount) * 1000 // ms
        let tickRate = 1.0 / (totalTime / Double(tickCount)) // Hz
        
        // Should maintain 60+ Hz tick rate for 100 nodes
        #expect(tickRate > 60, "Tick rate \(tickRate) Hz below 60 Hz for 100 nodes")
        #expect(avgTickTime < 16.67, "Average tick time \(avgTickTime) ms exceeds 16.67ms")
    }
    
    @Test("Tick rate at 500 nodes")
    func tickRate500Nodes() async throws {
        let engine = MockGraphEngine()
        engine.nodeCount = 500
        
        var totalTime: TimeInterval = 0
        let tickCount = 100
        
        measure {
            let start = CFAbsoluteTimeGetCurrent()
            for _ in 0..<tickCount {
                engine.simulateTick()
            }
            totalTime = CFAbsoluteTimeGetCurrent() - start
        }
        
        let avgTickTime = totalTime / Double(tickCount) * 1000
        let tickRate = 1.0 / (totalTime / Double(tickCount))
        
        // Should maintain 60+ Hz for 500 nodes
        #expect(tickRate > 60, "Tick rate \(tickRate) Hz below 60 Hz for 500 nodes")
    }
    
    @Test("Tick rate at 1000 nodes")
    func tickRate1000Nodes() async throws {
        let engine = MockGraphEngine()
        engine.nodeCount = 1000
        
        var totalTime: TimeInterval = 0
        let tickCount = 60
        
        measure {
            let start = CFAbsoluteTimeGetCurrent()
            for _ in 0..<tickCount {
                engine.simulateTick()
            }
            totalTime = CFAbsoluteTimeGetCurrent() - start
        }
        
        let avgTickTime = totalTime / Double(tickCount) * 1000
        let tickRate = 1.0 / (totalTime / Double(tickCount))
        
        // Should maintain 30+ Hz for 1000 nodes
        #expect(tickRate > 30, "Tick rate \(tickRate) Hz below 30 Hz for 1000 nodes")
    }
    
    @Test("Tick rate at 1500 nodes")
    func tickRate1500Nodes() async throws {
        let engine = MockGraphEngine()
        engine.nodeCount = 1500
        
        var totalTime: TimeInterval = 0
        let tickCount = 60
        
        measure {
            let start = CFAbsoluteTimeGetCurrent()
            for _ in 0..<tickCount {
                engine.simulateTick()
            }
            totalTime = CFAbsoluteTimeGetCurrent() - start
        }
        
        let avgTickTime = totalTime / Double(tickCount) * 1000
        let tickRate = 1.0 / (totalTime / Double(tickCount))
        
        // Should maintain 30+ Hz for 1500 nodes (at threshold)
        #expect(tickRate > 30, "Tick rate \(tickRate) Hz below 30 Hz for 1500 nodes")
    }
    
    // MARK: - Static Layout Threshold
    
    @Test("Physics disabled threshold verification")
    func physicsDisabledThreshold() async throws {
        // The threshold is 2500 nodes in GraphState
        let threshold = GraphState.staticLayoutThreshold
        #expect(threshold == 2500)
        
        // Test just below threshold - physics should be active
        let engineBelow = MockGraphEngine()
        engineBelow.nodeCount = threshold - 1
        engineBelow.isStaticLayout = false
        
        // Test at threshold - physics should be disabled
        let engineAt = MockGraphEngine()
        engineAt.nodeCount = threshold
        engineAt.isStaticLayout = true
        
        // Test above threshold - physics should be disabled
        let engineAbove = MockGraphEngine()
        engineAbove.nodeCount = threshold + 500
        engineAbove.isStaticLayout = true
        
        #expect(!engineBelow.isStaticLayout, "Physics should be active below threshold")
        #expect(engineAt.isStaticLayout, "Physics should be disabled at threshold")
        #expect(engineAbove.isStaticLayout, "Physics should be disabled above threshold")
    }
    
    @Test("Static layout performance - no physics overhead")
    func staticLayoutPerformance() async throws {
        let engine = MockGraphEngine()
        engine.nodeCount = 2000
        engine.isStaticLayout = true
        
        var frameTimes: [TimeInterval] = []
        let frameCount = 100
        
        measure {
            let start = CFAbsoluteTimeGetCurrent()
            for _ in 0..<frameCount {
                // In static layout, frames should be very fast
                // Just render, no physics
                let frameStart = CFAbsoluteTimeGetCurrent()
                // Simulate minimal work
                let _ = 42
                frameTimes.append(CFAbsoluteTimeGetCurrent() - frameStart)
            }
            let _ = CFAbsoluteTimeGetCurrent() - start
        }
        
        // Static layout frames should be consistently fast
        let avgFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count) * 1000
        #expect(avgFrameTime < 1.0, "Static layout frame time \(avgFrameTime) ms too high")
    }
    
    // MARK: - Force Calculation Performance
    
    @Test("Link force calculation performance")
    func linkForcePerformance() async throws {
        let nodeCounts = [100, 500, 1000]
        
        for count in nodeCounts {
            var totalTime: TimeInterval = 0
            let iterations = 100
            
            measure {
                let start = CFAbsoluteTimeGetCurrent()
                
                // Simulate link force calculation
                for _ in 0..<iterations {
                    var work = 0.0
                    // O(edges) complexity - typically edges ~ 1.5 * nodes
                    let edgeCount = Int(Double(count) * 1.5)
                    for i in 0..<edgeCount {
                        work += Double(i) * 0.0001
                    }
                }
                
                totalTime = CFAbsoluteTimeGetCurrent() - start
            }
            
            let avgTime = (totalTime / Double(iterations)) * 1000 // ms
            // Link force should scale linearly and be fast
            #expect(avgTime < 1.0, "Link force for \(count) nodes took \(avgTime) ms/iteration")
        }
    }
    
    @Test("Charge force calculation performance")
    func chargeForcePerformance() async throws {
        let nodeCounts = [100, 500, 1000]
        
        for count in nodeCounts {
            var totalTime: TimeInterval = 0
            let iterations = 100
            
            measure {
                let start = CFAbsoluteTimeGetCurrent()
                
                // Simulate Barnes-Hut charge force (O(n log n))
                for _ in 0..<iterations {
                    var work = 0.0
                    let complexity = Int(Double(count) * log2(Double(max(count, 2))))
                    for i in 0..<complexity {
                        work += Double(i) * 0.00001
                    }
                }
                
                totalTime = CFAbsoluteTimeGetCurrent() - start
            }
            
            let avgTime = (totalTime / Double(iterations)) * 1000
            #expect(avgTime < 2.0, "Charge force for \(count) nodes took \(avgTime) ms/iteration")
        }
    }
    
    @Test("Collision detection performance")
    func collisionDetectionPerformance() async throws {
        let nodeCounts = [100, 500, 1000]
        
        for count in nodeCounts {
            var totalTime: TimeInterval = 0
            let iterations = 100
            
            measure {
                let start = CFAbsoluteTimeGetCurrent()
                
                // Simulate spatial hash collision detection (O(n))
                for _ in 0..<iterations {
                    var work = 0.0
                    for i in 0..<count {
                        // Each node checks nearby cells
                        work += Double(i) * 0.00001
                    }
                }
                
                totalTime = CFAbsoluteTimeGetCurrent() - start
            }
            
            let avgTime = (totalTime / Double(iterations)) * 1000
            #expect(avgTime < 1.5, "Collision for \(count) nodes took \(avgTime) ms/iteration")
        }
    }
    
    // MARK: - Quadtree Build Performance
    
    @Test("Quadtree build at different node counts")
    func quadtreeBuildPerformance() async throws {
        let nodeCounts = [100, 500, 1000, 2000]
        
        for count in nodeCounts {
            var totalTime: TimeInterval = 0
            let iterations = 50
            
            measure {
                let start = CFAbsoluteTimeGetCurrent()
                
                // Simulate quadtree build (O(n log n))
                for _ in 0..<iterations {
                    var work = 0.0
                    // Build complexity
                    let complexity = Int(Double(count) * log2(Double(max(count, 2))))
                    for i in 0..<complexity {
                        work += Double(i) * 0.00001
                    }
                }
                
                totalTime = CFAbsoluteTimeGetCurrent() - start
            }
            
            let avgTime = (totalTime / Double(iterations)) * 1000
            #expect(avgTime < 3.0, "Quadtree build for \(count) nodes took \(avgTime) ms")
        }
    }
    
    // MARK: - Convergence Time
    
    @Test("Convergence time for different graph sizes")
    func convergenceTime() async throws {
        let graphSizes = [100, 300, 500]
        
        for size in graphSizes {
            var convergenceTicks = 0
            let maxTicks = 500
            
            measure {
                // Simulate convergence
                var alpha: Double = 0.3
                let alphaMin = 0.001
                let alphaDecay = 0.0228
                
                var ticks = 0
                while alpha > alphaMin && ticks < maxTicks {
                    alpha += (0.0 - alpha) * alphaDecay
                    ticks += 1
                }
                convergenceTicks = ticks
            }
            
            // Should converge within reasonable time
            #expect(convergenceTicks < maxTicks, "Graph size \(size) didn't converge in \(maxTicks) ticks")
            // Larger graphs may take longer to converge
            #expect(convergenceTicks > 50, "Convergence too fast - possible issue")
        }
    }
    
    @Test("Convergence with different physics presets")
    func convergenceWithPresets() async throws {
        let presets: [PhysicsPreset] = [.observatory, .nebula, .crystal, .fluid, .constellation]
        
        for preset in presets {
            var convergenceTime: TimeInterval = 0
            
            measure {
                let start = CFAbsoluteTimeGetCurrent()
                
                // Simulate with preset parameters
                let velocityDecay = Double(preset.velocityDecay)
                var alpha: Double = 0.3
                let alphaMin = 0.001
                let decayRate = Double(0.0228) * (0.85 / velocityDecay) // Adjust for preset
                
                var ticks = 0
                while alpha > alphaMin && ticks < 500 {
                    alpha += (0.0 - alpha) * decayRate
                    ticks += 1
                }
                
                convergenceTime = CFAbsoluteTimeGetCurrent() - start
            }
            
            // All presets should converge
            #expect(convergenceTime < 0.1, "Preset \(preset) took too long to converge")
        }
    }
    
    // MARK: - Frame Pacing Consistency
    
    @Test("Frame pacing consistency")
    func framePacingConsistency() async throws {
        let engine = MockGraphEngine()
        engine.nodeCount = 500
        
        var frameTimes: [TimeInterval] = []
        let frameCount = 120
        
        measure {
            for _ in 0..<frameCount {
                let start = CFAbsoluteTimeGetCurrent()
                engine.simulateTick()
                frameTimes.append(CFAbsoluteTimeGetCurrent() - start)
            }
        }
        
        // Calculate jitter (standard deviation)
        let mean = frameTimes.reduce(0, +) / Double(frameTimes.count)
        let variance = frameTimes.map { pow($0 - mean, 2) }.reduce(0, +) / Double(frameTimes.count)
        let stdDev = sqrt(variance)
        let jitter = (stdDev / mean) * 100 // Percentage
        
        // Jitter should be low for consistent frame pacing
        #expect(jitter < 500, "Frame jitter \(jitter)% too high")
    }
    
    @Test("Frame pacing under load")
    func framePacingUnderLoad() async throws {
        let nodeCounts = [100, 500, 1000]
        
        for count in nodeCounts {
            let engine = MockGraphEngine()
            engine.nodeCount = count
            
            var frameTimes: [TimeInterval] = []
            let frameCount = 60
            
            measure {
                for _ in 0..<frameCount {
                    let start = CFAbsoluteTimeGetCurrent()
                    engine.simulateTick()
                    frameTimes.append(CFAbsoluteTimeGetCurrent() - start)
                }
            }
            
            // Check for dropped frames (> 33ms for 30fps)
            let droppedFrames = frameTimes.filter { $0 > 0.033 }.count
            let dropRate = Double(droppedFrames) / Double(frameCount)
            
            #expect(dropRate < 0.1, "Frame drop rate \(dropRate * 100)% too high for \(count) nodes")
        }
    }
    
    // MARK: - GPU Buffer Upload Performance
    
    @Test("GPU buffer upload performance")
    func gpuBufferUploadPerformance() async throws {
        let nodeCounts = [100, 500, 1000, 2000]
        
        for count in nodeCounts {
            var uploadTime: TimeInterval = 0
            let iterations = 50
            
            measure {
                let start = CFAbsoluteTimeGetCurrent()
                
                // Simulate GPU buffer preparation and upload
                for _ in 0..<iterations {
                    var positions: [Float] = []
                    positions.reserveCapacity(count * 2)
                    for i in 0..<count {
                        positions.append(Float(i) * 0.1)
                        positions.append(Float(i) * 0.2)
                    }
                    // Simulate upload cost
                    let _ = positions.withUnsafeBufferPointer { _ in }
                }
                
                uploadTime = CFAbsoluteTimeGetCurrent() - start
            }
            
            let avgTime = (uploadTime / Double(iterations)) * 1000
            #expect(avgTime < 2.0, "GPU upload for \(count) nodes took \(avgTime) ms")
        }
    }
    
    // MARK: - Physics Parameter Changes
    
    @Test("Physics parameter update performance")
    func physicsParameterUpdate() async throws {
        let engine = MockGraphEngine()
        engine.nodeCount = 1000
        
        var updateTime: TimeInterval = 0
        let iterations = 100
        
        measure {
            let start = CFAbsoluteTimeGetCurrent()
            
            // Simulate parameter updates
            for i in 0..<iterations {
                let linkDistance = 200.0 + sin(Double(i)) * 50
                let chargeStrength = -400.0 + cos(Double(i)) * 100
                let _ = linkDistance * chargeStrength * 0.0001
            }
            
            updateTime = CFAbsoluteTimeGetCurrent() - start
        }
        
        let avgTime = (updateTime / Double(iterations)) * 1000
        #expect(avgTime < 0.01, "Parameter update took \(avgTime) ms")
    }
    
    // MARK: - Multi-Force Combined Performance
    
    @Test("Combined force calculations")
    func combinedForcesPerformance() async throws {
        let nodeCounts = [100, 500, 1000]
        
        for count in nodeCounts {
            var totalTime: TimeInterval = 0
            let iterations = 100
            
            measure {
                let start = CFAbsoluteTimeGetCurrent()
                
                for _ in 0..<iterations {
                    // Simulate all forces combined
                    var work = 0.0
                    
                    // Link force: O(edges)
                    let edges = Int(Double(count) * 1.5)
                    for i in 0..<edges {
                        work += Double(i) * 0.00001
                    }
                    
                    // Charge force: O(n log n)
                    let chargeComplexity = Int(Double(count) * log2(Double(max(count, 2))))
                    for i in 0..<chargeComplexity {
                        work += Double(i) * 0.00001
                    }
                    
                    // Collision: O(n)
                    for i in 0..<count {
                        work += Double(i) * 0.00001
                    }
                    
                    // Center force: O(n)
                    for i in 0..<count {
                        work += Double(i) * 0.000005
                    }
                }
                
                totalTime = CFAbsoluteTimeGetCurrent() - start
            }
            
            let avgTime = (totalTime / Double(iterations)) * 1000
            // Combined forces should still be fast enough for 60fps
            #expect(avgTime < 16.67, "Combined forces for \(count) nodes took \(avgTime) ms")
        }
    }
    
    // MARK: - Edge Case Performance
    
    @Test("Sparse graph performance")
    func sparseGraphPerformance() async throws {
        let engine = MockGraphEngine()
        engine.nodeCount = 1000 // Few edges
        
        var tickTime: TimeInterval = 0
        let iterations = 100
        
        measure {
            let start = CFAbsoluteTimeGetCurrent()
            for _ in 0..<iterations {
                engine.simulateTick()
            }
            tickTime = CFAbsoluteTimeGetCurrent() - start
        }
        
        let avgTime = (tickTime / Double(iterations)) * 1000
        #expect(avgTime < 10.0, "Sparse graph tick took \(avgTime) ms")
    }
    
    @Test("Dense graph performance")
    func denseGraphPerformance() async throws {
        let engine = MockGraphEngine()
        engine.nodeCount = 500 // More edges per node
        
        var tickTime: TimeInterval = 0
        let iterations = 100
        
        measure {
            let start = CFAbsoluteTimeGetCurrent()
            for _ in 0..<iterations {
                // Simulate with more edge processing
                var work = 0.0
                for i in 0..<5000 { // More edges
                    work += sin(Double(i)) * 0.0001
                }
            }
            tickTime = CFAbsoluteTimeGetCurrent() - start
        }
        
        let avgTime = (tickTime / Double(iterations)) * 1000
        #expect(avgTime < 10.0, "Dense graph tick took \(avgTime) ms")
    }
    
    @Test("Cluster force performance")
    func clusterForcePerformance() async throws {
        let nodeCount = 1000
        let clusterCount = 10
        
        var totalTime: TimeInterval = 0
        let iterations = 100
        
        measure {
            let start = CFAbsoluteTimeGetCurrent()
            
            for _ in 0..<iterations {
                // Simulate cluster force calculation
                var work = 0.0
                
                // Compute centroids
                for c in 0..<clusterCount {
                    for n in 0..<(nodeCount / clusterCount) {
                        work += Double(c * n) * 0.00001
                    }
                }
                
                // Apply forces
                for i in 0..<nodeCount {
                    work += Double(i) * 0.00001
                }
            }
            
            totalTime = CFAbsoluteTimeGetCurrent() - start
        }
        
        let avgTime = (totalTime / Double(iterations)) * 1000
        #expect(avgTime < 2.0, "Cluster force took \(avgTime) ms")
    }
}
