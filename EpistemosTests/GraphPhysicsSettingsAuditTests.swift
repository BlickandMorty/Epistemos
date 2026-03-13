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

@Suite("Dialogue Game State")
struct DialogueGameStateAuditTests {

    @Test("citation-heavy content derives archivist persona")
    func archivistPersona() {
        let baseline = DialogueNodeProfile.derive(
            nodeId: "node-1-baseline",
            label: "Research Notes",
            nodeType: .note,
            noteBody: "",
            linkedNodeLabels: ["Method", "Evidence", "Study"]
        )
        let profile = DialogueNodeProfile.derive(
            nodeId: "node-1",
            label: "Research Notes",
            nodeType: .note,
            noteBody: """
            DOI:10.1000/example. Journal of Systems, 2024.
            This review cites multiple studies and compares methodologies.
            """,
            linkedNodeLabels: ["Method", "Evidence", "Study"]
        )

        #expect(profile.archetype == .archivist)
        #expect(profile.portrait.symbol == "books.vertical.fill")
        #expect(profile.care.health > baseline.care.health)
        #expect(!profile.focusKeywords.isEmpty)
    }

    @Test("question-heavy content derives examiner persona")
    func examinerPersona() {
        let profile = DialogueNodeProfile.derive(
            nodeId: "node-2",
            label: "Open Problems",
            nodeType: .idea,
            noteBody: """
            Why does this break under load? How should the system respond?
            What evidence would falsify the current hypothesis?
            """,
            linkedNodeLabels: ["Hypothesis", "Load Test"]
        )

        #expect(profile.archetype == .examiner)
        #expect(profile.portrait.symbol == "questionmark.circle.fill")
        #expect(profile.summary.contains("asks"))
    }

    @Test("interaction feed boosts attention and health")
    func interactionImprovesVitals() {
        var profile = DialogueNodeProfile.derive(
            nodeId: "node-3",
            label: "Sparse Note",
            nodeType: .note,
            noteBody: "",
            linkedNodeLabels: []
        )

        let initialHealth = profile.care.health
        let initialAttention = profile.care.attention

        profile.recordInteraction(userText: "How are you holding up?")

        #expect(profile.care.health > initialHealth)
        #expect(profile.care.attention > initialAttention)
        #expect(profile.care.interactionCount == 1)
    }

    @Test("explicit node insight drives depth tier and vitality")
    func explicitInsightShapesProfile() {
        let insight = DialogueNodeInsight(
            structureDepth: 0,
            contentWords: 2400,
            childCount: 18,
            tier: .root,
            prominence: 0.96
        )

        let baseline = DialogueNodeProfile.derive(
            nodeId: "folder-root",
            label: "Research Vault",
            nodeType: .folder,
            noteBody: "",
            linkedNodeLabels: ["Methods", "Sources", "Experiments"]
        )

        let profile = DialogueNodeProfile.derive(
            nodeId: "folder-root",
            label: "Research Vault",
            nodeType: .folder,
            noteBody: "",
            linkedNodeLabels: ["Methods", "Sources", "Experiments"],
            insight: insight
        )

        #expect(profile.insight == insight)
        #expect(profile.summary.contains("layer 0"))
        #expect(profile.care.health > baseline.care.health)
        #expect(profile.care.attention > baseline.care.attention)
    }

    @Test("fallback insight counts words and marks thin content")
    func fallbackInsightReflectsBodyMass() {
        let thin = DialogueNodeInsight.fallback(
            nodeType: .note,
            noteBody: "",
            linkedNodeCount: 0
        )
        let dense = DialogueNodeInsight.fallback(
            nodeType: .note,
            noteBody: "Alpha beta gamma delta epsilon zeta eta theta",
            linkedNodeCount: 2
        )

        #expect(thin.contentLabel == "thin")
        #expect(dense.contentWords == 8)
        #expect(dense.contentLabel == "8w")
        #expect(dense.prominence > thin.prominence)
    }
}
