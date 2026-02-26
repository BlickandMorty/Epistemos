import Testing
import simd
@testable import Epistemos

@Suite("ForceSimulation")
struct ForceSimulationTests {

    @Test("simulation separates overlapping nodes")
    func separatesOverlappingNodes() async {
        let sim = ForceSimulation()

        // Two nodes at nearly the same position — repulsion should push them apart
        await sim.load(
            nodes: [
                (id: "a", position: SIMD2<Float>(0, 0), weight: 1.0),
                (id: "b", position: SIMD2<Float>(1, 1), weight: 1.0),
            ],
            edges: []
        )

        var positions: [String: SIMD2<Float>] = [:]
        for _ in 0..<50 {
            positions = await sim.tick()
        }

        let posA = positions["a"] ?? .zero
        let posB = positions["b"] ?? .zero
        let distance = simd_length(posA - posB)

        #expect(distance > 10, "Overlapping nodes should separate (distance: \(distance))")
    }

    @Test("connected nodes attract")
    func connectedNodesAttract() async {
        let sim = ForceSimulation()

        // Two nodes far apart with a strong edge.
        // At large distances, repulsion (1/r^2) drops off faster than
        // spring attraction (proportional to distance), so attraction wins.
        let initialA = SIMD2<Float>(-500, 0)
        let initialB = SIMD2<Float>(500, 0)
        let initialDistance = simd_length(initialA - initialB)

        await sim.load(
            nodes: [
                (id: "a", position: initialA, weight: 1.0),
                (id: "b", position: initialB, weight: 1.0),
            ],
            edges: [
                (source: "a", target: "b", weight: Float(10.0)),
            ]
        )

        var positions: [String: SIMD2<Float>] = [:]
        for _ in 0..<100 {
            positions = await sim.tick()
        }

        let posA = positions["a"] ?? initialA
        let posB = positions["b"] ?? initialB
        let finalDistance = simd_length(posA - posB)

        #expect(
            finalDistance < initialDistance,
            "Connected nodes should attract (initial: \(initialDistance), final: \(finalDistance))"
        )
    }

    @Test("simulation auto-sleeps when settled")
    func autoSleepsWhenSettled() async {
        let sim = ForceSimulation()

        // Single node near origin — should settle quickly
        await sim.load(
            nodes: [
                (id: "alone", position: SIMD2<Float>(5, 5), weight: 1.0),
            ],
            edges: []
        )

        for _ in 0..<200 {
            _ = await sim.tick()
        }

        let isSleeping = await sim.sleeping
        #expect(isSleeping, "Simulation with a single node should auto-sleep after settling")
    }
}
