import Testing
@testable import Epistemos
import Foundation

@Suite("Graph Physics Settings Audit", .serialized)
@MainActor
struct GraphPhysicsSettingsAuditTests {
    private let performanceModeKey = "epistemos.graph.performanceMode"
    private let waterNodesEnabledKey = "epistemos.waterNodes.enabled"
    private let waterNodesWobbleKey = "epistemos.waterNodes.wobble"
    private let visualThemeKey = "graphVisualTheme"
    private let visualThemeMigrationKey = "epistemos.graph.visualTheme.migratedClassicDefault"
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
        "epistemos.physics.selectedPreset",
        "epistemos.physics.schedulerMode",
        "epistemos.physics.simpleOpeningPresetKey",
        "epistemos.physics.simpleOpeningDelaySeconds",
        "epistemos.physics.simpleRestingPresetKey",
        "epistemos.physics.interactionMotionHoldSeconds",
        "epistemos.physics.interactionMotionAlphaTarget",
        "epistemos.physics.startupViewMode",
        "epistemos.physics.timelineSteps",
        "epistemos.physics.schedulerDefaultsVersion",
    ]

    private func clearPhysicsDefaults() {
        let defaults = UserDefaults.standard
        for key in physicsKeys {
            defaults.removeObject(forKey: key)
        }
        defaults.removeObject(forKey: performanceModeKey)
        defaults.removeObject(forKey: waterNodesEnabledKey)
        defaults.removeObject(forKey: waterNodesWobbleKey)
        defaults.removeObject(forKey: visualThemeKey)
        defaults.removeObject(forKey: visualThemeMigrationKey)
    }

    private func waitForPreset(
        _ preset: PhysicsPreset,
        in state: GraphState,
        timeout: Duration = .seconds(15)
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while state.selectedPhysicsPreset != preset {
            if ContinuousClock.now >= deadline {
                return false
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return true
    }

    private func timelineSignature(_ steps: [PhysicsScheduleStep]) -> [String] {
        steps.map { "\($0.delaySeconds):\($0.presetKey)" }
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

    @Test("Renderer camera smoothing stays on the 6.5 buttery baseline")
    func rendererCameraSmoothingStaysOnButteryBaseline() throws {
        let source = try loadMirroredSourceTextFile("graph-engine/src/renderer.rs")

        #expect(source.contains("const CAMERA_LAMBDA: f32 = 6.5;"))
        #expect(source.contains("Was 3.0 (too slow per user 2026-04-04)."))
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

    @Test("Featured graph presets include centered layouts without enabling lab forces")
    func featuredPresetsIncludeCenteredLayoutsWithoutLabForces() {
        let featured = Set(PhysicsPreset.allCases.filter(\.isFeatured))
        let centered: Set<PhysicsPreset> = [.crystal, .gravityWell, .halo, .nucleus]

        for preset in centered {
            #expect(featured.contains(preset))
            #expect(preset.motionCategory != .experimental)
            #expect(preset.centerStrength >= PhysicsPreset.crystal.centerStrength)
            #expect(preset.labOverrides.enableOrbital != true)
            #expect(preset.labOverrides.enableTorsion != true)
            #expect(preset.labOverrides.windX == nil || abs(preset.labOverrides.windX ?? 0) < 0.0001)
            #expect(preset.labOverrides.windY == nil || abs(preset.labOverrides.windY ?? 0) < 0.0001)
        }

        #expect(PhysicsPreset.gravityWell.centerStrength > PhysicsPreset.observatory.centerStrength)
        #expect(PhysicsPreset.nucleus.centerStrength > PhysicsPreset.gravityWell.centerStrength)
        #expect(PhysicsPreset.halo.chargeRange < PhysicsPreset.constellation.chargeRange)
    }

    @Test("Overlay cycle reaches chaos in 4 seconds from the constellation opening preset without enabling fluid wake")
    func overlayCycleKeepsFluidWakeOffByDefault() async {
        clearPhysicsDefaults()

        #expect(GraphOverlayPhysicsPolicy.chaosDelaySeconds == 4)
        #expect(GraphOverlayPhysicsPolicy.preset(afterElapsedSeconds: 3.99) == .constellation)
        #expect(GraphOverlayPhysicsPolicy.preset(afterElapsedSeconds: 4) == .chaos)

        let state = GraphState()
        state.startOverlayPhysicsCycle()

        #expect(await waitForPreset(.constellation, in: state))
        #expect(state.selectedPhysicsPreset == .constellation)
        #expect(!state.enableFluidDynamics)

        #expect(await waitForPreset(.chaos, in: state))
        #expect(state.selectedPhysicsPreset == .chaos)
        #expect(!state.enableFluidDynamics)
    }

    @Test("Graph rebuild requests restart in constellation and mark rebuild pending")
    func graphRebuildRequestStartsConstellationCycle() async {
        clearPhysicsDefaults()

        let state = GraphState()
        state.requestGraphRebuild()

        #expect(state.pendingRebuild)
        #expect(await waitForPreset(.constellation, in: state))
        #expect(state.selectedPhysicsPreset == .constellation)
        #expect(!state.enableFluidDynamics)
    }

    @Test("legacy default scheduler migrates to the new constellation opening cycle")
    func legacyDefaultSchedulerMigratesForward() throws {
        clearPhysicsDefaults()

        let seed = GraphState()
        seed.savePhysicsSettings()

        let defaults = UserDefaults.standard
        defaults.set(0, forKey: "epistemos.physics.schedulerDefaultsVersion")
        defaults.set(PhysicsSchedulerMode.timeline.rawValue, forKey: "epistemos.physics.schedulerMode")
        defaults.set("crystal", forKey: "epistemos.physics.simpleOpeningPresetKey")
        defaults.set(3.0, forKey: "epistemos.physics.simpleOpeningDelaySeconds")
        defaults.set("chaos", forKey: "epistemos.physics.simpleRestingPresetKey")
        let legacySteps = [
            PhysicsScheduleStep(delaySeconds: 0.0, presetKey: "crystal"),
            PhysicsScheduleStep(delaySeconds: 3.0, presetKey: "constellation"),
            PhysicsScheduleStep(delaySeconds: 4.0, presetKey: "chaos"),
        ]
        defaults.set(try JSONEncoder().encode(legacySteps), forKey: "epistemos.physics.timelineSteps")

        let state = GraphState()
        let signature = timelineSignature(state.timelineSteps)

        #expect(state.simpleOpeningPresetKey == GraphOverlayPhysicsPolicy.openingPresetKey)
        #expect(abs(state.simpleOpeningDelaySeconds - GraphOverlayPhysicsPolicy.chaosDelaySeconds) < 0.0001)
        #expect(state.simpleRestingPresetKey == GraphOverlayPhysicsPolicy.restingPresetKey)
        #expect(signature == GraphOverlayPhysicsPolicy.defaultTimelineSignature.map { "\($0.0):\($0.1)" })
        #expect(UserDefaults.standard.integer(forKey: "epistemos.physics.schedulerDefaultsVersion") == 2)
    }

    @Test("custom scheduler survives the default-schedule migration")
    func customSchedulerSurvivesMigration() throws {
        clearPhysicsDefaults()

        let seed = GraphState()
        seed.savePhysicsSettings()

        let defaults = UserDefaults.standard
        defaults.set(0, forKey: "epistemos.physics.schedulerDefaultsVersion")
        defaults.set(PhysicsSchedulerMode.timeline.rawValue, forKey: "epistemos.physics.schedulerMode")
        let customSteps = [
            PhysicsScheduleStep(delaySeconds: 0.0, presetKey: "observatory"),
            PhysicsScheduleStep(delaySeconds: 2.0, presetKey: "windTunnel"),
        ]
        defaults.set(try JSONEncoder().encode(customSteps), forKey: "epistemos.physics.timelineSteps")

        let state = GraphState()
        let signature = timelineSignature(state.timelineSteps)

        #expect(signature == customSteps.map { "\($0.delaySeconds):\($0.presetKey)" })
        #expect(UserDefaults.standard.integer(forKey: "epistemos.physics.schedulerDefaultsVersion") == 2)
    }

    @Test("Semantic clustering defaults off without saved settings")
    func semanticClusteringDefaultsOff() {
        clearPhysicsDefaults()

        let state = GraphState()

        #expect(!state.useSemanticClustering)
    }

    @Test("Semantic clustering toggle persists immediately")
    func semanticClusteringTogglePersists() {
        clearPhysicsDefaults()

        let state = GraphState()
        state.useSemanticClustering = false

        #expect(!UserDefaults.standard.bool(forKey: "epistemos.physics.useSemanticClustering"))
    }

    @MainActor
    @Test("Semantic clustering is disabled when prepared retrieval leaves apple fallback")
    func semanticClusteringDisablesOutsideAppleFallback() async throws {
        clearPhysicsDefaults()

        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)

        let state = GraphState()
        state.store.addNode(GraphNodeRecord(id: "n1", type: .note, label: "alpha", sourceId: nil, metadata: GraphNodeMetadata(), weight: 1, createdAt: .now))
        state.store.addNode(GraphNodeRecord(id: "n2", type: .note, label: "beta", sourceId: nil, metadata: GraphNodeMetadata(), weight: 1, createdAt: .now))
        state.store.addNode(GraphNodeRecord(id: "n3", type: .note, label: "gamma", sourceId: nil, metadata: GraphNodeMetadata(), weight: 1, createdAt: .now))
        state.store.addNode(GraphNodeRecord(id: "n4", type: .note, label: "delta", sourceId: nil, metadata: GraphNodeMetadata(), weight: 1, createdAt: .now))
        state.useSemanticClustering = true
        state.applyPreparedRetrievalRuntimeConfiguration(
            PreparedRetrievalRuntimeConfiguration(
                retriever: PreparedModelDescriptor(
                    key: "retriever_primary",
                    role: .retriever,
                    displayName: "BGE-M3",
                    artifactID: nil,
                    modelID: "BAAI/bge-m3",
                    servedModelID: "BAAI/bge-m3",
                    adapterPath: nil,
                    expectedAdapterBaseModelID: nil,
                    baseModelID: nil,
                    baseSnapshotPath: nil,
                    mergeOutputPath: nil,
                    mlxOutputPath: nil,
                    downloadPath: retrieverPath.path,
                    status: "downloaded",
                    trustRemoteCode: false
                )
            )
        )

        state.computeSemanticClusters()

        #expect(state.preparedRetrievalExecutionMode == .preparedAssetsPendingIndex(retrieverModelID: "BAAI/bge-m3"))
        #expect(!state.semanticClusteringAvailable)
        #expect(!state.useSemanticClustering)
        #expect(state.semanticClusterIds.isEmpty)
        #expect(state.semanticClusterVersion == 1)
    }

    @Test("Graph defaults to cinematic water mode")
    func graphDefaultsToCinematicWaterMode() {
        clearPhysicsDefaults()

        let state = GraphState()
        let powerOverrideForcesPerformance = PowerGuard.shared.shouldDisableBackground

        #expect(!state.performanceModeEnabled)
        #expect(state.qualityLevel == (powerOverrideForcesPerformance ? 2 : 0))
        #expect(state.waterNodesEnabled)
    }

    @Test("Performance mode persists, restores, and disables water nodes")
    func performanceModePersistsAndDisablesWaterNodes() {
        clearPhysicsDefaults()

        let state = GraphState()
        state.performanceModeEnabled = true

        #expect(UserDefaults.standard.bool(forKey: performanceModeKey))
        #expect(state.qualityLevel == 2)
        #expect(!state.waterNodesEnabled)

        let restored = GraphState()
        #expect(restored.performanceModeEnabled)
        #expect(restored.qualityLevel == 2)
        #expect(!restored.waterNodesEnabled)

        restored.performanceModeEnabled = false
        #expect(restored.waterNodesEnabled)
    }

    @Test("Graph settings expose section tabs and remove middle water/startup controls")
    func graphSettingsRemoveMiddleWaterAndStartupControls() throws {
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Graph/GraphForceSettings.swift")
        let overlay = try loadMirroredSourceTextFile("Epistemos/Views/Graph/HologramOverlay.swift")
        let graphState = try loadMirroredSourceTextFile("Epistemos/Graph/GraphState.swift")
        let metalGraph = try loadMirroredSourceTextFile("Epistemos/Views/Graph/MetalGraphView.swift")

        #expect(settings.contains("GraphForceSettingsSection"))
        #expect(settings.contains("case physics = \"Physics\""))
        #expect(!settings.contains("Picker(\"Opens in\""))
        #expect(!settings.contains("sectionHeader(\"Water Nodes\""))
        #expect(overlay.contains("static func surfaceTintColor"))
        #expect(overlay.contains("static func overlayTintColor(for theme: EpistemosTheme) -> NSColor"))
        #expect(overlay.contains("static func miniTintColor(for theme: EpistemosTheme) -> NSColor"))
        #expect(overlay.components(separatedBy: "surfaceTintColor(for: theme)").count >= 3)
        #expect(graphState.contains("notifyGraphRenderSettingsChanged()"))
        #expect(graphState.contains("NotificationCenter.default.post(name: .graphRenderSettingsChanged"))
        #expect(metalGraph.contains("forName: .graphRenderSettingsChanged"))
        #expect(metalGraph.contains("self.needsRender = true"))
    }

    @Test("Visual theme defaults to classic when unset")
    func visualThemeDefaultsToClassicWhenUnset() {
        clearPhysicsDefaults()

        let state = GraphState()

        #expect(state.visualTheme == .classic)
    }

    @Test("Visual theme restores persisted choice")
    func visualThemeRestoresPersistedChoice() {
        clearPhysicsDefaults()
        UserDefaults.standard.set(Int(GraphVisualTheme.dialogue.rawValue), forKey: visualThemeKey)
        UserDefaults.standard.set(true, forKey: visualThemeMigrationKey)

        let state = GraphState()

        #expect(state.visualTheme == .dialogue)
    }

    @Test("Legacy dialogue visual theme migrates to classic when no explicit choice remains")
    func legacyDialogueVisualThemeMigratesToClassic() {
        clearPhysicsDefaults()
        UserDefaults.standard.set(Int(GraphVisualTheme.dialogue.rawValue), forKey: visualThemeKey)

        let state = GraphState()

        #expect(state.visualTheme == .classic)
        #expect(UserDefaults.standard.integer(forKey: visualThemeKey) == Int(GraphVisualTheme.classic.rawValue))
        #expect(UserDefaults.standard.bool(forKey: visualThemeMigrationKey))
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
        #expect(profile.openingLine != "Ask about this node.")
        #expect(profile.summary.localizedCaseInsensitiveContains("evidence"))
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
        #expect(profile.care.mood == .curious)
        #expect(profile.portrait.symbol == "questionmark.bubble.fill")
        #expect(profile.summary.localizedCaseInsensitiveContains("questions"))
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
        #expect(profile.summary.localizedCaseInsensitiveContains("layer 0"))
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
