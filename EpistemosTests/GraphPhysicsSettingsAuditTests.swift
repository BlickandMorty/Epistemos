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

    private static func swiftSourceFiles(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                files.append(fileURL)
            }
        }
        return files
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

    @Test("Deferred graph inspect mode stays empty and unmounted")
    func deferredGraphInspectModeStaysEmptyAndUnmounted() throws {
        let inspectPath = "Epistemos/Views/Graph/GraphInspectModeView.swift"
        let inspectSource = try loadMirroredSourceTextFile(inspectPath)

        #expect(inspectSource.contains("Deferred inspect-mode shell"))
        #expect(inspectSource.contains("EmptyView()"))
        #expect(!inspectSource.contains("Placeholder for actual graph layer rendering"))
        #expect(!inspectSource.contains("Circle()"))
        #expect(!inspectSource.contains("5-layer depth parallax"))
        #expect(!inspectSource.contains("Full-screen immersive visualization"))
        #expect(!inspectSource.contains("Auto-enter inspect mode"))

        let sourceRoot = try sourceMirrorURL(for: "Epistemos")
        let sourceFiles = try Self.swiftSourceFiles(under: sourceRoot)
        let mounts = try sourceFiles.flatMap { fileURL -> [String] in
            let relativePath = fileURL.path
                .replacingOccurrences(of: sourceRoot.path + "/", with: "Epistemos/")
            if relativePath == inspectPath {
                return []
            }

            let source = try String(contentsOf: fileURL, encoding: .utf8)
            var matches: [String] = []
            if source.contains("GraphInspectModeView(") {
                matches.append("\(relativePath):GraphInspectModeView")
            }
            if source.contains("enterInspectMode(") {
                matches.append("\(relativePath):enterInspectMode")
            }
            return matches
        }

        #expect(mounts.isEmpty, "Deferred graph inspect mode must stay unmounted; mounts: \(mounts.sorted())")
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

    @Test("Graph defaults to cinematic pixel mode")
    func graphDefaultsToCinematicPixelMode() {
        clearPhysicsDefaults()

        let state = GraphState()

        #expect(!state.performanceModeEnabled)
        #expect(state.qualityLevel == 0)
        #expect(state.waterNodesEnabled)
    }

    @Test("Performance mode persists, restores, and disables cinematic pixel nodes")
    func performanceModePersistsAndDisablesCinematicPixelNodes() {
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
        #expect(graphState.contains("static let defaultGlobalCameraMagnification: Float = -0.08"))
        #expect(metalGraph.contains("forName: .graphRenderSettingsChanged"))
        #expect(metalGraph.contains("self.needsRender = true"))
        #expect(metalGraph.contains("graph_engine_zoom_to_fit(engine)"))
        #expect(!metalGraph.contains("graph_engine_center_camera(engine)"))
        #expect(settings.contains("label: \"Outer Labels\""))
        #expect(settings.contains("label: \"Base Size\""))
        #expect(settings.contains("label: \"Focus Shrink\""))
        #expect(settings.contains("labToggle(\n                    label: \"Elastic Edges\""))
        #expect(settings.contains("label: \"Edge Elasticity\""))
    }

    @Test("Cinematic graph renderer uses hard stepped pixel nodes without adding a third mode")
    func cinematicGraphRendererUsesHardSteppedPixelNodesWithoutThirdMode() throws {
        let renderer = try loadMirroredSourceTextFile("graph-engine/src/renderer.rs")
        let graphState = try loadMirroredSourceTextFile("Epistemos/Graph/GraphState.swift")
        let controls = try loadMirroredSourceTextFile("Epistemos/Views/Graph/GraphFloatingControls.swift")
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Graph/GraphForceSettings.swift")

        #expect(renderer.contains("bool cinematic_mode = in.is_lite < 0.5;"),
                "Cinematic pixel nodes must be the existing quality_level 0 shader path, not a new mode")
        #expect(renderer.contains("const float pixel_grid = 9.0;"),
                "Cinematic nodes must use a hard stepped pixel grid")
        #expect(renderer.contains("if (pixel_dist > 0.96) discard_fragment();"),
                "Cinematic node edges must be hard discarded, not smooth water/orb alpha")
        #expect(renderer.contains("const float cinematic_world_scale = 1.18;"),
                "Pixel nodes must keep a larger cinematic world-space scale at normal graph zoom")
        #expect(renderer.contains("const float cinematic_min_world_radius = 13.0;"),
                "Pixel nodes must remain large enough to show stepped edges without pinning screen size")
        #expect(!renderer.contains("cinematic_min_screen_radius"),
                "Cinematic pixel nodes must not clamp to screen pixels because that makes zoom feel fake")
        #expect(!renderer.contains("effective_radius = screen_radius /"),
                "Cinematic pixel nodes must scale through the real camera transform, not inverse-zoom sizing")
        #expect(renderer.contains("if (uniforms.lite_mode > 1.5 && speed > 1.0)"),
                "Cinematic pixel nodes must not squash/stretch like water beads")
        #expect(renderer.contains("float cinematic_click_wave = 1.0 - smoothstep"),
                "Cinematic pixel nodes must keep the selection/click pulse cue inside the pixel branch")
        #expect(!renderer.contains("float cinematic_click_sweep = 1.0 - smoothstep"),
                "Cinematic pixel nodes must not restore the old shine sweep while keeping the pulse")
        #expect(renderer.contains("bool large_folder_node = folder_node && in.depth >= 0.45;"),
                "Only high-degree/top-level folder hubs should receive the subtle pixel glare")
        #expect(renderer.contains("float folder_pixel_glare = smoothstep"),
                "Large folder hubs should keep a subtle opaque pixel-glare cue")
        #expect(renderer.contains("folder_pixel_glare * 0.24"),
                "Cinematic folder glare should be present but restrained, not a dramatic gradient")
        #expect(renderer.contains("folder_pixel_shadow * 0.06"),
                "Cinematic folder shadow should be a minimal solid-body shade cue")
        #expect(!renderer.contains("folder_pixel_glare * 0.62"),
                "Old heavy folder glare multiplier is too dramatic for the restored solid-node look")
        #expect(renderer.contains("folder_pixel_glare * 0.20"),
                "Balanced folder glare should also stay restrained while preserving the cue")
        #expect(!renderer.contains("folder_pixel_glare * 0.48"),
                "Balanced mode must not keep the previous heavier folder gradient")
        #expect(renderer.contains("out.node_radius_world = effective_radius;"),
                "Pixel click animation should scale from real graph radius, not screen overlay math")
        #expect(renderer.contains("return float4(pixel_color, max(in.color.a, 0.95));"),
                "Cinematic nodes must keep a solid opaque body while still allowing selection dimming")
        #expect(renderer.contains("draw_glow: false"),
                "Cinematic pixel nodes must not keep soft glow/orb instances around the stepped shape")
        #expect(graphState.contains("PowerGuard may throttle frame pacing/resolution"),
                "PowerGuard must not silently route the Pixel toolbar mode into performance shading")
        #expect(renderer.contains("bool performance_mode = in.is_lite > 1.5;"),
                "Performance mode must remain the existing quality_level >= 2 branch")

        #expect(controls.contains("title: \"Pixel\""))
        #expect(controls.contains("activeTitle: \"Fast\""))
        #expect(!controls.contains("title: \"Water\""))
        #expect(settings.contains("Hard stepped pixel nodes with the full graph surface."))
        #expect(!settings.contains("Water nodes are on by default"))
    }

    @Test("Graph labels use crisp monospaced SDF atlas")
    func graphLabelsUseCrispMonospacedSDFAtlas() throws {
        let script = try loadMirroredSourceTextFile("scripts/generate-sdf-atlas.sh")
        let renderer = try loadMirroredSourceTextFile("graph-engine/src/renderer.rs")
        let graphState = try loadMirroredSourceTextFile("Epistemos/Graph/GraphState.swift")
        let atlasText = try loadMirroredSourceTextFile("Epistemos/Resources/sdf_labels.json")

        #expect(script.contains("VARIANT=\"mono\""))
        #expect(script.contains("JetBrainsMono-Regular.ttf"))
        #expect(script.contains("-size 48"))
        #expect(script.contains("-dimensions 1024 1024"))
        #expect(graphState.contains("var displayName: String { \"Mono\" }"))
        #expect(renderer.contains("float atlas_glyph_px = inst.uv_rect.w * u.atlas_height;"))
        #expect(renderer.contains("float blur_widen = in.blur * 0.08;"))
        #expect(!renderer.contains("inst.size * (1.0 - blur * 0.5)"))

        let data = Data(atlasText.utf8)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let atlas = try #require(root["atlas"] as? [String: Any])
        #expect((atlas["width"] as? NSNumber)?.intValue == 1024)
        #expect((atlas["height"] as? NSNumber)?.intValue == 1024)
        #expect((atlas["size"] as? NSNumber)?.intValue == 48)

        let glyphs = try #require(root["glyphs"] as? [[String: Any]])
        func advance(for scalar: Unicode.Scalar) -> Double? {
            glyphs
                .first { ($0["unicode"] as? NSNumber)?.uint32Value == scalar.value }
                .flatMap { ($0["advance"] as? NSNumber)?.doubleValue }
        }

        let narrow = try #require(advance(for: "i"))
        let wide = try #require(advance(for: "W"))
        let digit = try #require(advance(for: "1"))
        #expect(abs(narrow - wide) < 0.0001)
        #expect(abs(narrow - digit) < 0.0001)
    }

    @Test("Graph label envelopes feed node collision radii")
    func graphLabelEnvelopesFeedNodeCollisionRadii() throws {
        let simulation = try loadMirroredSourceTextFile("graph-engine/src/simulation.rs")
        let envelope = try loadMirroredSourceTextFile("graph-engine/src/label_envelope.rs")
        let components = try loadMirroredSourceTextFile("graph-engine/src/ecs/components.rs")
        let bridge = try loadMirroredSourceTextFile("graph-engine/src/ecs/bridge.rs")
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Graph/GraphForceSettings.swift")

        #expect(envelope.contains("estimate_label_envelope"))
        #expect(envelope.contains("LABEL_ENVELOPE_MAX_CHARS"))
        #expect(envelope.contains("LABEL_ENVELOPE_WORLD_EM: f32 = 16.0"))
        #expect(envelope.contains("long_label_envelope_tracks_rendered_sdf_label_scale"))
        #expect(envelope.contains("bubble_radius"))
        #expect(simulation.contains("pub label_collision_radii: Vec<f32>"))
        #expect(simulation.contains("visual_shell.max(label_shell)"))
        #expect(simulation.contains("load_expands_collision_radii_for_wide_labels"))
        #expect(components.contains("pub label_half_width: f32"))
        #expect(components.contains("pub label_offset_y: f32"))
        #expect(bridge.contains("estimate_label_envelope(node.radius, &node.label)"))
        #expect(settings.contains("Label Bubbles"))
        #expect(settings.contains("Long labels expand node spacing"))
    }

    @Test("Graph label envelope does not rewrite force model")
    func graphLabelEnvelopeDoesNotRewriteForceModel() throws {
        let forces = try loadMirroredSourceTextFile("graph-engine/src/forces.rs")

        #expect(!forces.contains("label_collision_radii"))
        #expect(!forces.contains("label_half_width"))
        #expect(!forces.contains("estimate_label_envelope"))
    }

    @Test("Graph label density uses screen-rect overlap culling")
    func graphLabelDensityUsesScreenRectOverlapCulling() throws {
        let engine = try loadMirroredSourceTextFile("graph-engine/src/engine.rs")

        #expect(engine.contains("fn estimated_label_screen_rect("))
        #expect(engine.contains("occupied_label_rects"))
        #expect(engine.contains("existing.overlaps(&label_rect)"))
        #expect(engine.contains("let local_scale = 1.0 - 0.62 * smoothstep"))
        #expect(engine.contains("fn selected_neighbor_density_budget("))
        #expect(engine.contains("const LABEL_SELECTED_NEIGHBOR_SOFT_TARGET: usize = 12;"))
        #expect(engine.contains("const LABEL_SELECTED_NEIGHBOR_DENSITY_TARGET: usize = 8;"))
        #expect(engine.contains("sqrt().floor() as usize"))
        #expect(engine.contains("selected_high_degree_labels_stay_density_bounded"))
        #expect(engine.contains("label_screen_rect_overlap_detects_actual_text_width"))
        #expect(engine.contains("crowded_labels_shrink_aggressively_before_culling"))
    }

    @Test("Graph edge thickness derives from edge weight")
    func graphEdgeThicknessDerivesFromEdgeWeight() throws {
        let renderer = try loadMirroredSourceTextFile("graph-engine/src/renderer.rs")

        #expect(renderer.contains("const MIN_EDGE_WIDTH_PX: f32 = 1.15"))
        #expect(renderer.contains("const MAX_EDGE_WIDTH_PX: f32 = 4.20"))
        #expect(renderer.contains("fn edge_width_px_for_weight(weight: f32, p0_radius: f32, p1_radius: f32) -> f32"))
        #expect(renderer.contains("let thickness_px = edge_width_px_for_weight(edge.weight, source_radius, target_radius)"))
        #expect(renderer.contains("fn graph_edge_color_for_appearance(light_mode: bool) -> [f32; 4]"))
        #expect(renderer.contains("self.classic_edge_instance_color(world, edge, src_index, tgt_index)"))
        #expect(renderer.contains("float thickness_px;"))
        #expect(renderer.contains("clamp(inst.thickness_px, MIN_EDGE_WIDTH_PX, MAX_EDGE_WIDTH_PX) * 0.5"))
        #expect(renderer.contains("edge_weight_maps_to_clamped_screen_thickness"))
        #expect(renderer.contains("graph_edge_color_uses_single_appearance_color"))
        #expect(!renderer.contains("edge_color_with_endpoint_palette("))
    }

    @Test("Graph edge dead modes are removed from UI Swift and Rust")
    func graphEdgeDeadModesAreRemovedFromUISwiftAndRust() throws {
        let graphState = try loadMirroredSourceTextFile("Epistemos/Graph/GraphState.swift")
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Graph/GraphForceSettings.swift")
        let metalView = try loadMirroredSourceTextFile("Epistemos/Views/Graph/MetalGraphView.swift")
        let renderer = try loadMirroredSourceTextFile("graph-engine/src/renderer.rs")
        let engine = try loadMirroredSourceTextFile("graph-engine/src/engine.rs")
        let exports = try loadMirroredSourceTextFile("graph-engine/src/lib.rs")
        let header = try loadMirroredSourceTextFile("graph-engine-bridge/graph_engine.h")

        #expect(!graphState.contains("enum GraphEdgeStyle"))
        #expect(!graphState.contains("edgeStyle"))
        #expect(!settings.contains("Edge Style"))
        #expect(!settings.contains("Pixel-Art"))
        #expect(!metalView.contains("edgeStyleVersion"))
        #expect(!metalView.contains("graph_engine_set_edge_style"))
        let productionRenderer = renderer.split(separator: "mod tests", maxSplits: 1).first.map(String.init) ?? renderer
        #expect(!productionRenderer.contains("enum EdgeStyle"))
        #expect(!productionRenderer.contains("edge_style"))
        #expect(!productionRenderer.contains("PixelArt"))
        #expect(!productionRenderer.contains("EdgeGeometryKind"))
        #expect(renderer.contains("cinematic_quality_keeps_curved_edge_geometry"))
        #expect(!renderer.contains("screen0 = round(screen0);"))
        #expect(!renderer.contains("float  pixel_edge_style"))
        #expect(!renderer.contains("in.pixel_edge_style"))
        #expect(!renderer.contains("push_pixel_edge_stacked_segments"))
        #expect(renderer.contains("graph_edge_color_for_flag"))
        #expect(renderer.contains("selected_edges_focus_without_white_color_override"))
        #expect(!renderer.contains("float4(srgb_to_linear(float3(0.70, 0.90, 1.00)), 0.75)"))
        #expect(!engine.contains("pub fn set_edge_style"))
        #expect(!exports.contains("graph_engine_set_edge_style"))
        #expect(!header.contains("graph_engine_set_edge_style"))
    }

    @Test("Graph renderer keeps smooth curved edges connected under solid nodes")
    func graphRendererKeepsSmoothCurvedEdgesConnectedUnderSolidNodes() throws {
        let renderer = try loadMirroredSourceTextFile("graph-engine/src/renderer.rs")
        let graphLib = try loadMirroredSourceTextFile("graph-engine/src/lib.rs")

        #expect(!renderer.contains("crate::edge_trim::trim_line_endpoints("))
        #expect(!renderer.contains("crate::edge_trim::trim_curve_endpoints("))
        #expect(!graphLib.contains("pub mod edge_trim;"))
        #expect(renderer.contains("smooth_curve_edges_use_node_centers_so_nodes_occlude_connections"))
        let productionRenderer = renderer.split(separator: "mod tests", maxSplits: 1).first.map(String.init) ?? renderer
        #expect(!productionRenderer.contains("EdgeGeometryKind"))
        #expect(renderer.contains("fn performance_quality_keeps_curved_edge_geometry"))
    }

    @Test("Cinematic graph selection dimming stays visible while nodes remain solid")
    func cinematicGraphSelectionDimmingStaysVisibleWhileNodesRemainSolid() throws {
        let renderer = try loadMirroredSourceTextFile("graph-engine/src/renderer.rs")

        #expect(renderer.contains("float3 selection_dim_target = light"))
        #expect(renderer.contains(": srgb_to_linear(float3(0.06, 0.06, 0.06));"))
        #expect(renderer.contains("pixel_color = mix(pixel_color, selection_dim_target"))
        #expect(renderer.contains("float dim_alpha_floor = is_dimmed ? 0.95 : 0.85;"))
        #expect(renderer.contains("return float4(pixel_color, max(in.color.a, 0.95));"))
        #expect(renderer.contains("cinematic_pixel_nodes_apply_selection_dim_without_transparency"))
        #expect(renderer.contains("light_and_dark_node_highlight_flags_dim_non_neighbors"))
    }

    @Test("Graph selection sync restores neighborhood focus from every selection surface")
    func graphSelectionSyncRestoresNeighborhoodFocusFromEverySelectionSurface() throws {
        let graphState = try loadMirroredSourceTextFile("Epistemos/Graph/GraphState.swift")
        let header = try loadMirroredSourceTextFile("graph-engine-bridge/graph_engine.h")
        let engine = try loadMirroredSourceTextFile("graph-engine/src/engine.rs")
        let exports = try loadMirroredSourceTextFile("graph-engine/src/lib.rs")

        #expect(graphState.contains("graph_engine_select_node(engine"))
        #expect(graphState.contains("graph_engine_clear_selected_node(engine)"))
        #expect(header.contains("void graph_engine_select_node(Engine* engine, const char* uuid);"))
        #expect(header.contains("void graph_engine_clear_selected_node(Engine* engine);"))
        #expect(engine.contains("pub fn select_node(&mut self, uuid: &str)"))
        #expect(engine.contains("self.highlight_neighbors_by_id(node_id);"))
        #expect(engine.contains("pub fn clear_selected_node(&mut self)"))
        #expect(exports.contains("pub extern \"C\" fn graph_engine_select_node"))
        #expect(exports.contains("pub extern \"C\" fn graph_engine_clear_selected_node"))
        #expect(engine.contains("select_node_syncs_selection_and_neighborhood_focus"))
    }

    @MainActor
    @Test("Graph theme node palette keeps solid semantic node colors")
    func graphThemeNodePaletteKeepsSolidSemanticNodeColors() {
        let lightFolder = GraphThemeNodePalette.color(for: .folder, theme: .systemLight)
        let darkFolder = GraphThemeNodePalette.color(for: .folder, theme: .systemDark)
        let lightNote = GraphThemeNodePalette.color(for: .note, theme: .systemLight)
        let darkNote = GraphThemeNodePalette.color(for: .note, theme: .systemDark)
        let tanIdea = GraphThemeNodePalette.color(for: .idea, theme: .tan)
        let violetIdea = GraphThemeNodePalette.color(for: .idea, theme: .platinumViolet)

        #expect(lightFolder == (r: 0.0, g: 0.0, b: 0.0, a: 1.0))
        #expect(darkFolder == (r: 1.0, g: 1.0, b: 1.0, a: 1.0))
        #expect(lightNote.a == 1.0)
        #expect(darkNote.a == 1.0)
        #expect(lightNote.r > 0.85)
        #expect(lightNote.g < 0.25)
        #expect(lightNote.b < 0.25)
        #expect(darkNote.r > 0.85)
        #expect(darkNote.g < 0.25)
        #expect(darkNote.b < 0.25)
        #expect(tanIdea.a == 1.0)
        #expect(violetIdea.a == 1.0)
        #expect(abs(tanIdea.r - violetIdea.r) > 0.02 || abs(tanIdea.b - violetIdea.b) > 0.02)
    }

    @Test("Metal graph view refreshes node palette when UI theme changes")
    func metalGraphRefreshesNodePaletteWhenUIThemeChanges() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Graph/MetalGraphView.swift")

        #expect(source.contains("GraphThemeNodePalette.color(for: node.type, theme: resolvedTheme)"))
        #expect(source.contains("GraphThemeNodePalette.color(for: node.type, theme: theme)"))
        #expect(source.contains("cachedColorResolvedTheme"))
        #expect(source.contains("uiState.appearanceSyncKey"))
        #expect(source.contains("lastAppearanceSyncKey"))
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
