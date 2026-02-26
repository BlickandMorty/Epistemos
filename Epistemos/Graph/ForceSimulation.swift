import Foundation
import simd

// MARK: - ForceSimulation
// Actor that runs force-directed graph layout on a background thread.
// Consumed by the SpriteKit scene (Task 4), which calls tick() each frame
// and applies the returned positions to sprite nodes.
//
// Physics model: repulsion (Coulomb) + edge attraction (spring) + centering.
// For < 2000 nodes, direct O(n^2) repulsion. For >= 2000, Barnes-Hut O(n log n).

actor ForceSimulation {

    // MARK: - State

    private var positions: [String: SIMD2<Float>] = [:]
    private var velocities: [String: SIMD2<Float>] = [:]
    private var nodeWeights: [String: Float] = [:]
    private var edgeList: [(source: String, target: String, weight: Float)] = []
    private var pinnedNodes: Set<String> = []
    private var nodeIds: [String] = []   // stable ordering for iteration

    // MARK: - Tuning Constants

    private let repulsionStrength: Float = 5000
    private let attractionStrength: Float = 0.005
    private let centeringStrength: Float = 0.01
    private let damping: Float = 0.92
    private let minVelocity: Float = 0.1
    private let sleepThreshold: Float = 0.5

    // MARK: - Sleep State

    private var _sleeping: Bool = false

    /// Read-only: true when kinetic energy has dropped below threshold.
    var sleeping: Bool { _sleeping }

    // MARK: - Load Topology

    /// Initialize simulation from the graph topology.
    /// Positions should already be set (e.g., from GraphStore random assignment).
    func load(
        nodes: [(id: String, position: SIMD2<Float>, weight: Float)],
        edges: [(source: String, target: String, weight: Float)]
    ) {
        positions = [:]
        velocities = [:]
        nodeWeights = [:]
        nodeIds = []
        pinnedNodes = []
        _sleeping = false

        for node in nodes {
            positions[node.id] = node.position
            velocities[node.id] = .zero
            nodeWeights[node.id] = node.weight
            nodeIds.append(node.id)
        }

        self.edgeList = edges
    }

    // MARK: - Simulation Tick

    /// Run one physics step and return updated positions.
    func tick() -> [String: SIMD2<Float>] {
        guard !_sleeping, !nodeIds.isEmpty else { return positions }

        let count = nodeIds.count

        // Accumulate forces per node
        var forces: [String: SIMD2<Float>] = [:]
        for id in nodeIds {
            forces[id] = .zero
        }

        // 1. Repulsion
        if count < 2000 {
            applyDirectRepulsion(&forces)
        } else {
            applyBarnesHutRepulsion(&forces)
        }

        // 2. Edge attraction
        applyEdgeAttraction(&forces)

        // 3. Centering
        applyCentering(&forces)

        // 4. Integrate: apply forces as velocity, then velocity as position
        var totalKineticEnergy: Float = 0

        for id in nodeIds {
            guard !pinnedNodes.contains(id) else { continue }

            var vel = velocities[id] ?? .zero
            let force = forces[id] ?? .zero

            vel = (vel + force) * damping

            // Clamp tiny velocities to zero
            let speed = simd_length(vel)
            if speed < minVelocity {
                vel = .zero
            }

            velocities[id] = vel
            positions[id] = (positions[id] ?? .zero) + vel
            totalKineticEnergy += speed * speed
        }

        // 5. Auto-sleep when settled
        let avgEnergy = count > 0 ? totalKineticEnergy / Float(count) : 0
        if avgEnergy < sleepThreshold {
            _sleeping = true
        }

        return positions
    }

    // MARK: - Wake

    /// Clear sleeping state so the simulation resumes on next tick.
    func wake() {
        _sleeping = false
    }

    // MARK: - Pin / Drag Support

    /// Lock a node at a fixed position (it won't be moved by forces).
    func pinNode(_ nodeId: String, at position: SIMD2<Float>) {
        pinnedNodes.insert(nodeId)
        positions[nodeId] = position
        velocities[nodeId] = .zero
    }

    /// Update a node's position (drag support). Also wakes the simulation.
    func updateNodePosition(_ nodeId: String, position: SIMD2<Float>) {
        positions[nodeId] = position
        velocities[nodeId] = .zero
        _sleeping = false
    }

    // MARK: - Direct O(n^2) Repulsion

    private func applyDirectRepulsion(_ forces: inout [String: SIMD2<Float>]) {
        let count = nodeIds.count
        for i in 0..<count {
            let idA = nodeIds[i]
            let posA = positions[idA] ?? .zero
            let weightA = nodeWeights[idA] ?? 1.0

            for j in (i + 1)..<count {
                let idB = nodeIds[j]
                let posB = positions[idB] ?? .zero
                let weightB = nodeWeights[idB] ?? 1.0

                var delta = posA - posB
                var distSq = simd_length_squared(delta)

                // Avoid division by zero / explosion
                if distSq < 1.0 { distSq = 1.0 }

                let dist = sqrt(distSq)
                if dist < 0.001 {
                    // Nodes exactly overlapping — nudge apart randomly
                    delta = SIMD2<Float>(
                        Float.random(in: -1...1),
                        Float.random(in: -1...1)
                    )
                }

                let strength = repulsionStrength * weightA * weightB / distSq
                let forceVec = (delta / dist) * strength

                forces[idA] = (forces[idA] ?? .zero) + forceVec
                forces[idB] = (forces[idB] ?? .zero) - forceVec
            }
        }
    }

    // MARK: - Barnes-Hut O(n log n) Repulsion

    private func applyBarnesHutRepulsion(_ forces: inout [String: SIMD2<Float>]) {
        // Build quad tree
        let tree = QuadTree(bounds: QuadTree.Bounds(
            minX: -10000, minY: -10000, maxX: 10000, maxY: 10000
        ))

        for id in nodeIds {
            let pos = positions[id] ?? .zero
            let weight = nodeWeights[id] ?? 1.0
            tree.insert(QuadTree.Body(id: id, position: pos, mass: weight))
        }

        // Calculate forces
        for id in nodeIds {
            let pos = positions[id] ?? .zero
            let force = tree.calculateForce(
                on: pos,
                theta: 0.8,
                strength: repulsionStrength
            )
            forces[id] = (forces[id] ?? .zero) + force
        }
    }

    // MARK: - Edge Attraction

    private func applyEdgeAttraction(_ forces: inout [String: SIMD2<Float>]) {
        for edge in edgeList {
            guard let posA = positions[edge.source],
                  let posB = positions[edge.target] else { continue }

            let delta = posB - posA
            let dist = simd_length(delta)
            guard dist > 0.001 else { continue }

            let strength = attractionStrength * edge.weight
            let forceVec = (delta / dist) * dist * strength

            forces[edge.source] = (forces[edge.source] ?? .zero) + forceVec
            forces[edge.target] = (forces[edge.target] ?? .zero) - forceVec
        }
    }

    // MARK: - Centering

    private func applyCentering(_ forces: inout [String: SIMD2<Float>]) {
        for id in nodeIds {
            let pos = positions[id] ?? .zero
            let force = -pos * centeringStrength
            forces[id] = (forces[id] ?? .zero) + force
        }
    }

    // MARK: - QuadTree (Barnes-Hut)
    // Private spatial subdivision for efficient O(n log n) force calculation.
    // Each node contains at most one body; internal nodes store aggregate mass and center of mass.
    // Nested inside the actor so it inherits actor isolation and can be freely used.

    private final class QuadTree {

        struct Bounds {
            let minX: Float
            let minY: Float
            let maxX: Float
            let maxY: Float

            var midX: Float { (minX + maxX) * 0.5 }
            var midY: Float { (minY + maxY) * 0.5 }
            var width: Float { maxX - minX }

            func contains(_ point: SIMD2<Float>) -> Bool {
                point.x >= minX && point.x <= maxX &&
                point.y >= minY && point.y <= maxY
            }

            var nw: Bounds { Bounds(minX: minX, minY: midY, maxX: midX, maxY: maxY) }
            var ne: Bounds { Bounds(minX: midX, minY: midY, maxX: maxX, maxY: maxY) }
            var sw: Bounds { Bounds(minX: minX, minY: minY, maxX: midX, maxY: midY) }
            var se: Bounds { Bounds(minX: midX, minY: minY, maxX: maxX, maxY: midY) }
        }

        struct Body {
            let id: String
            let position: SIMD2<Float>
            let mass: Float
        }

        private let bounds: Bounds
        private var body: Body?
        private var totalMass: Float = 0
        private var centerOfMass: SIMD2<Float> = .zero
        private var children: [QuadTree]?
        private var isEmpty: Bool = true

        init(bounds: Bounds) {
            self.bounds = bounds
        }

        func insert(_ newBody: Body) {
            // Clamp to bounds
            guard bounds.contains(newBody.position) else {
                // Body outside bounds — still account for it at the boundary
                updateAggregates(newBody)
                return
            }

            if isEmpty {
                // Empty leaf — store directly
                body = newBody
                isEmpty = false
                updateAggregates(newBody)
                return
            }

            if children == nil {
                // Leaf with one body — subdivide
                children = [
                    QuadTree(bounds: bounds.nw),
                    QuadTree(bounds: bounds.ne),
                    QuadTree(bounds: bounds.sw),
                    QuadTree(bounds: bounds.se),
                ]

                // Re-insert existing body
                if let existing = body {
                    insertIntoChild(existing)
                    body = nil
                }
            }

            // Insert new body into appropriate child
            insertIntoChild(newBody)
            updateAggregates(newBody)
        }

        private func insertIntoChild(_ b: Body) {
            guard let children else { return }
            let mx = bounds.midX
            let my = bounds.midY

            if b.position.x <= mx {
                if b.position.y >= my {
                    children[0].insert(b)  // NW
                } else {
                    children[2].insert(b)  // SW
                }
            } else {
                if b.position.y >= my {
                    children[1].insert(b)  // NE
                } else {
                    children[3].insert(b)  // SE
                }
            }
        }

        private func updateAggregates(_ b: Body) {
            let newTotal = totalMass + b.mass
            if newTotal > 0 {
                centerOfMass = (centerOfMass * totalMass + b.position * b.mass) / newTotal
            }
            totalMass = newTotal
        }

        /// Calculate repulsive force on a point from this tree node.
        /// theta: Barnes-Hut opening angle threshold (0.8 typical).
        func calculateForce(
            on point: SIMD2<Float>,
            theta: Float,
            strength: Float
        ) -> SIMD2<Float> {
            guard !isEmpty else { return .zero }

            let delta = point - centerOfMass
            var distSq = simd_length_squared(delta)
            if distSq < 1.0 { distSq = 1.0 }
            let dist = sqrt(distSq)

            // If this is a leaf or the node is far enough away, treat as single body
            let ratio = bounds.width / dist
            if children == nil || ratio < theta {
                // Coulomb-like repulsion
                let forceMag = strength * totalMass / distSq
                return (delta / dist) * forceMag
            }

            // Otherwise recurse into children
            var force = SIMD2<Float>.zero
            if let children {
                for child in children {
                    force += child.calculateForce(on: point, theta: theta, strength: strength)
                }
            }
            return force
        }
    }
}
