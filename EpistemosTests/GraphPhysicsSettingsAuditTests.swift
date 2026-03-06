import Testing
@testable import Epistemos
import Foundation

@Suite("Graph Physics Settings Audit")
@MainActor
struct GraphPhysicsSettingsAuditTests {
    private let physicsKeys: [String] = [
        "epistemos.physics.hasSavedSettings",
        "epistemos.physics.version",
        "epistemos.physics.linkDistance",
        "epistemos.physics.chargeStrength",
        "epistemos.physics.chargeRange",
        "epistemos.physics.linkStrength",
        "epistemos.physics.velocityDecay",
        "epistemos.physics.centerStrength",
        "epistemos.physics.collisionRadius",
        "epistemos.physics.clusterStrength",
        "epistemos.physics.centerMode",
        "epistemos.physics.semanticStrength",
        "epistemos.physics.useSemanticClustering",
        "epistemos.physics.userFrozen",
        "epistemos.physics.enableFluid",
        "epistemos.physics.enableTorsion",
        "epistemos.physics.enableElastic",
        "epistemos.physics.enableTension",
        "epistemos.physics.fluidViscosity",
        "epistemos.physics.edgeElasticity",
        "epistemos.physics.torsionRigidity",
        "epistemos.physics.boidsCohesion",
        "epistemos.physics.windX",
        "epistemos.physics.windY",
        "epistemos.physics.enableOrbital",
        "epistemos.physics.orbitalSpeed",
    ]

    private func clearPhysicsDefaults() {
        let defaults = UserDefaults.standard
        for key in physicsKeys {
            defaults.removeObject(forKey: key)
        }
    }

    @Test("Semantic strength change persists even before engine exists")
    func semanticStrengthPersistsWithoutEngine() {
        clearPhysicsDefaults()

        let state = GraphState()
        state.semanticStrength = 0.65

        let initialVersion = state.semanticForceConfigVersion
        state.pushSemanticChange()

        #expect(state.semanticForceConfigVersion == initialVersion + 1)
        #expect(
            abs(UserDefaults.standard.float(forKey: "epistemos.physics.semanticStrength") - 0.65) < 0.0001
        )
    }

    @Test("Presets reset lab state instead of inheriting stale toggles")
    func presetsResetLabState() {
        clearPhysicsDefaults()

        let state = GraphState()
        state.clusterStrength = 0.8
        state.centerMode = 2
        state.semanticStrength = 0.7
        state.enableFluidDynamics = true
        state.enableTorsionalSprings = true
        state.enableElasticEdges = false
        state.enableTensionColoring = false
        state.fluidViscosity = 0.9
        state.edgeElasticity = 0.9
        state.torsionRigidity = 0.9
        state.boidsCohesion = 0.8
        state.windX = 19.0
        state.windY = -11.0
        state.enableOrbital = true
        state.orbitalSpeed = 0.8

        state.applyPreset(.nebula)

        #expect(abs(state.clusterStrength) < 0.0001)
        #expect(state.centerMode == 0)
        #expect(abs(state.semanticStrength) < 0.0001)
        #expect(!state.enableFluidDynamics)
        #expect(!state.enableTorsionalSprings)
        #expect(state.enableElasticEdges)
        #expect(state.enableTensionColoring)
        #expect(abs(state.fluidViscosity - 0.5) < 0.0001)
        #expect(abs(state.edgeElasticity - 0.5) < 0.0001)
        #expect(abs(state.torsionRigidity - 0.5) < 0.0001)
        #expect(abs(state.boidsCohesion) < 0.0001)
        #expect(abs(state.windX) < 0.0001)
        #expect(abs(state.windY) < 0.0001)
        #expect(!state.enableOrbital)
        #expect(abs(state.orbitalSpeed - 0.3) < 0.0001)
    }

    @Test("Semantic clustering toggle persists immediately")
    func semanticClusteringTogglePersists() {
        clearPhysicsDefaults()

        let state = GraphState()
        state.useSemanticClustering = false

        #expect(!UserDefaults.standard.bool(forKey: "epistemos.physics.useSemanticClustering"))
    }
}
