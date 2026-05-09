import Testing
@testable import Epistemos

@Suite("Companion avatar grammar source guards")
struct CompanionAvatarGrammarSourceGuardTests {
    @Test("Companion bodies render through native avatar grammar, not SF Symbols")
    func companionBodiesUseNativeAvatarGrammar() throws {
        let companionView = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/Farm/CompanionView.swift"
        )
        let creationFlow = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/Farm/CompanionCreationFlow.swift"
        )
        let model = try loadMirroredSourceTextFile(
            "Epistemos/Models/Companion/CompanionModel.swift"
        )

        #expect(companionView.contains("CompanionAvatarGlyph("),
                "CompanionView must render the canonical Canvas avatar grammar")
        #expect(!companionView.contains("Image(systemName: entry.bodyKind.systemImageName)"),
                "CompanionView must not regress to SF Symbol companion bodies")

        #expect(creationFlow.contains("CompanionAvatarGlyph("),
                "The creation wizard must preview the same avatar grammar users see in the Farm")
        #expect(!creationFlow.contains("Image(systemName: kind.systemImageName)"),
                "The creation wizard body picker must not use SF Symbols")

        #expect(!model.contains("var systemImageName"),
                "CompanionBodyKind should not expose SF Symbol body identities")
    }

    @Test("Avatar grammar keeps farm body families explicit and reserves Hermes for graph faculty")
    func avatarGrammarKeepsFarmBodyFamiliesExplicitAndReservesHermesForGraphFaculty() throws {
        let glyph = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/Farm/CompanionAvatarGlyph.swift"
        )
        let model = try loadMirroredSourceTextFile(
            "Epistemos/Models/Companion/CompanionModel.swift"
        )
        let creationFlow = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/Farm/CompanionCreationFlow.swift"
        )

        for renderer in [
            "drawBlock",
            "drawSage",
            "drawOrb",
        ] {
            #expect(glyph.contains(renderer),
                    "CompanionAvatarGlyph must keep \(renderer) explicit and auditable")
        }
        #expect(!glyph.contains("drawHermesSnake"),
                "Hermes Snake is graph faculty, not a selectable Farm body renderer")
        #expect(glyph.contains("Canvas"),
                "The first T6 recovery slice should be native SwiftUI Canvas, not external image assets")
        #expect(glyph.contains("reduceMotion"),
                "Avatar grammar must preserve the reduce-motion static-pose fallback")

        for token in [
            "struct CompanionBodyKind",
            "CompanionBodyFamily",
            "CompanionBlockAspect",
            "CompanionLegStyle",
            "CompanionAntennaStyle",
            "CompanionEyeTreatment",
        ] {
            #expect(model.contains(token),
                    "CompanionBodyKind must be parameterized per Simulation DOCTRINE §5.1 via \(token)")
        }
        #expect(!model.contains("case hermesSnake"),
                "Farm CompanionBodyKind must not offer Hermes Snake as a body choice")
        #expect(creationFlow.contains("CompanionBodyKind.creationPresets"),
                "Creation must use the canonical Farm presets, not every persisted/legacy shape")
        #expect(!creationFlow.contains("CompanionBodyKind.allCases"),
                "Creation must not expose a fixed enum-all-cases body picker")

        // Hermes graph faculty glyph removed in the Hermes UI overlay
        // teardown (slice 1, 2026-05-05). The graph plane no longer
        // carries a brand-specific faculty marker; the Farm body
        // grammar checks above remain authoritative.
    }

    @Test("Landing Farm routes companions through static shelf without idle clocks")
    func landingFarmUsesStaticShelfWithoutIdleClocks() throws {
        let farm = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/Farm/LandingFarmView.swift"
        )
        let landing = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/LandingView.swift"
        )
        let roaming = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/Farm/CompanionRoamingField.swift"
        )
        let companion = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/Farm/CompanionView.swift"
        )

        #expect(farm.contains("CompanionRoamingField("),
                "LandingFarmView must mount the canonical landing agent shelf")
        #expect(!farm.contains("LazyVGrid("),
                "LandingFarmView should not regress to a large card/grid companion surface")

        for token in [
            "shelfPosition",
            "reduceMotion",
            "clamp",
            "staticSampleDate",
        ] {
            #expect(roaming.contains(token),
                    "CompanionRoamingField must preserve a bounded landing-only shelf via \(token)")
        }
        #expect(landing.contains("isAnimationActive: false"),
                "Landing must keep agent dock animation off by default to avoid hidden idle CPU")
        #expect(roaming.contains("if reduceMotion || !isAnimationActive"),
                "The landing shelf must collapse to a fixed sampled pose when animation is inactive")
        #expect(roaming.contains("nodes(at: Self.staticSampleDate, in: proxy.size)"),
                "Inactive landing agents must receive a fixed sampled date, not nil that creates per-node timelines")
        #expect(roaming.contains("isAnimationActive"),
                "The landing agent shelf should keep an explicit animation gate for future user-triggered actions")
        #expect(roaming.contains("companionNode(entry, at: date)"),
                "The landing shelf should pass its sampled date into each companion node")
        #expect(roaming.contains("sampledAnimationDate: date"),
                "Companion nodes should forward the shared sampled date into CompanionView")
        #expect(roaming.contains("showsMetadata: false"),
                "The landing dock must render small glyph agents, not full companion cards")
        #expect(!roaming.contains("DeterministicPRNG(seedString: \"\\(entry.identityHash):landing-roam\")"),
                "Landing agents should no longer wander around the page")
        #expect(!roaming.contains("roamingPosition("),
                "Landing agents should sit in a static top-right shelf")
        #expect(!companion.contains("if isActive { return .walk }"),
                "Active agents must not walk in place; selection is shown by the badge")
        #expect(companion.contains("var sampledAnimationDate: Date? = nil"),
                "CompanionView must allow the Farm to avoid per-node timelines")
        #expect(companion.contains("TimelineView(.periodic(from: .now, by: Self.breathingRefreshInterval))"),
                "Standalone companion breathing should use a coarse periodic clock")
        #expect(!roaming.contains(".animation(minimumInterval: 1.0 / 24.0)"),
                "Landing roaming must not regress to a 24 Hz display-style TimelineView")
        #expect(!roaming.contains("companionNode(entry, at: reduceMotion ? nil : date)"),
                "Inactive landing agents must not fall back to CompanionView's standalone timeline")
        #expect(!companion.contains(".animation(minimumInterval: 1.0 / 8.0)"),
                "Farm companion bodies should not run an extra per-node 8 Hz animation clock")
        #expect(!roaming.contains(".random"),
                "Landing roaming must be seeded from companion identity, not runtime randomness")
        #expect(!roaming.contains("repeatForever"),
                "Landing roaming must remain TimelineView-driven, not repeatForever animation")
    }

    @Test("Landing agents stay compact, chrome-free, and wired into chat prompts")
    func landingAgentsStayCompactChromeFreeAndPromptWired() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let farm = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/LandingFarmView.swift")
        let glyph = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/CompanionAvatarGlyph.swift")
        let companion = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/CompanionView.swift")
        let creation = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/CompanionCreationFlow.swift")
        let state = try loadMirroredSourceTextFile("Epistemos/State/Companion/CompanionState.swift")
        let pipeline = try loadMirroredSourceTextFile("Epistemos/Engine/PipelineService.swift")
        let coordinator = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")
        let bootstrap = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(landing.contains("private var landingAgentDock: some View"),
                "Landing must mount agents as a top-right dock, not a bottom companion panel")
        #expect(landing.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)"),
                "Landing agent dock must stay anchored top-right")
        #expect(!landing.contains(".padding(.bottom, 18)"),
                "Landing must not keep the old large bottom companion box")

        #expect(farm.contains("Text(\"AGENTS\")"),
                "The dock needs the requested retro AGENTS label")
        #expect(farm.contains("Text(\"+\")"),
                "The dock needs the requested compact retro add button")
        #expect(!farm.contains("panelBackground"),
                "The old companion card/panel chrome must stay removed")
        #expect(!farm.contains("New Companion"),
                "The visible landing surface should use agent language")

        #expect(!glyph.contains("drawHalo"),
                "Agent glyphs must not draw the old circular halo/orb wrapper")
        #expect(!glyph.contains(".drawingGroup()"),
                "Small landing agents should not force an extra offscreen render group")
        #expect(glyph.contains("solid body silhouettes"),
                "Small landing agents should keep the body shape but drop tiny internal square dividers")
        #expect(!glyph.contains("let beltY ="),
                "Agent bodies must not regress to internal belt pixels at dock scale")
        #expect(!glyph.contains("let spineX ="),
                "Agent bodies must not regress to internal spine pixels at dock scale")
        #expect(!glyph.contains("let mouthY ="),
                "Agent bodies must not regress to a tiny mouth row at dock scale")
        #expect(companion.contains("var showsMetadata: Bool = true"),
                "CompanionView must support compact metadata-free dock rendering")

        #expect(creation.contains("New Agent"))
        #expect(creation.contains("AgentColorPreset"))
        #expect(state.contains("Scout"),
                "Seeded agents should include a non-orb scout body")
        #expect(CompanionBodyKind.creationPresets.count >= 6,
                "Creation should expose more than the initial three block/sage body silhouettes")
        #expect(!creation.contains("@State private var bodyKind: CompanionBodyKind = .orb"),
                "New agents must not default to the circular orb body")

        #expect(state.contains("func activeAgentSystemInstruction() -> String?"),
                "Active landing agents must contribute to runtime prompts")
        #expect(state.contains("activateOnCreate: Bool = true"),
                "Newly created agents should become active so the user can use them immediately")
        #expect(pipeline.contains("activeCompanionInstructionProvider"),
                "Direct and local pipeline paths must receive active agent instructions")
        #expect(coordinator.contains("appendActiveLandingAgentSystemInstruction(to: &systemParts)"),
                "Managed cloud/Rust agent paths must receive active agent instructions")
        #expect(bootstrap.contains("activeCompanionInstructionProvider:"),
                "AppBootstrap must wire CompanionState into PipelineService")

        let graphSources = try [
            "Epistemos/Views/Graph/GraphWorkspaceContainer.swift",
            "Epistemos/Views/Graph/HologramOverlay.swift",
            "Epistemos/Views/Graph/MetalGraphView.swift",
            "Epistemos/Views/Graph/GraphFloatingControls.swift",
            "Epistemos/Views/Graph/GraphInspectModeView.swift",
        ].map { try loadMirroredSourceTextFile($0) }.joined(separator: "\n")
        #expect(!graphSources.contains("LandingFarmView("))
        #expect(!graphSources.contains("CompanionRoamingField("))
        #expect(!graphSources.contains("CompanionView("))
        #expect(!graphSources.contains("CompanionAvatarGlyph("))
    }

    @Test("Companion roaming phase math stays bounded for large absolute dates")
    func companionShelfPhaseMathStaysBoundedForLargeAbsoluteDates() {
        let model = CompanionModel(
            id: "phase-large-date",
            name: "Pulse",
            bodyKind: .orb,
            accentHex: "#7BA8E0",
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
        let entry = CompanionRosterEntry(from: model)
        let fieldSize = CGSize(width: 720, height: 272)
        let farFuture = Date(timeIntervalSinceReferenceDate: 1_000_000_000_000)

        let point = CompanionRoamingField.shelfPosition(
            index: 0,
            count: 3,
            in: fieldSize
        )
        let phase = CompanionView.breathePhase(at: farFuture, seedString: entry.identityHash)

        #expect(point.x.isFinite)
        #expect(point.y.isFinite)
        #expect(point.x >= 0)
        #expect(point.x <= fieldSize.width)
        #expect(point.y >= 0)
        #expect(point.y <= fieldSize.height)
        #expect(phase.isFinite)
        #expect(phase >= 0)
        #expect(phase <= 1)
    }

    @Test("Landing Farm does not expose deferred adapter hot-swap as a fake apply flow")
    func landingFarmDoesNotExposeDeferredAdapterHotSwapAsFakeApplyFlow() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let farm = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/LandingFarmView.swift")
        let roaming = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/CompanionRoamingField.swift")
        let adapter = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/CompanionAdapterView.swift")

        #expect(!landing.contains("farmAdapterTarget"),
                "Landing must not keep a sheet route for the deferred adapter pipeline")
        #expect(!landing.contains("CompanionAdapterView("),
                "Landing must not mount the deferred adapter scaffold as a v1 feature")
        #expect(!farm.contains("onApplyAdapter"),
                "LandingFarmView must not pass through an apply-adapter callback until hot-swap is real")
        #expect(!roaming.contains("Apply Adapter..."),
                "The companion context menu must not expose a fake adapter action")
        #expect(adapter.contains("Adapter Pipeline Deferred"),
                "The preserved scaffold must render an honest deferred state if a future caller presents it")
        #expect(!adapter.contains("Task.sleep"),
                "The scaffold must not simulate adapter work with a sleep")
        #expect(!adapter.contains("phase = .settled"),
                "The scaffold must not report a successful adapter apply without a loader")
        #expect(!adapter.contains("Paste path or use Open"),
                "The scaffold must not accept path input before validation and rollback are wired")
        #expect(!adapter.contains("Unwrap"),
                "The scaffold must not present the old fake apply button")
    }

    @Test("Companion body kind parser rejects unknown parameter values")
    func companionBodyKindParserRejectsUnknownParameterValues() {
        #expect(CompanionBodyKind(rawValue: "block.compact.stubs.none.filled") == .blockCompact)
        #expect(CompanionBodyKind(rawValue: "block.wide.multi.single.negativeSpace") == .blockWide)
        #expect(CompanionBodyKind(rawValue: "block.tall.stubs.double.filled") == .blockTall)
        #expect(CompanionBodyKind(rawValue: "block.compact.none.single.filled") == .blockSignal)
        #expect(CompanionBodyKind(rawValue: "block.wide.stubs.double.filled") == .blockTwin)

        #expect(CompanionBodyKind(rawValue: "block.bogus.stubs.none.filled") == nil)
        #expect(CompanionBodyKind(rawValue: "block.compact.bogus.none.filled") == nil)
        #expect(CompanionBodyKind(rawValue: "block.compact.stubs.bogus.filled") == nil)
        #expect(CompanionBodyKind(rawValue: "block.compact.stubs.none.bogus") == nil)
        #expect(CompanionBodyKind(rawValue: "block.compact.stubs.none.filled.extra") == nil)
        #expect(CompanionBodyKind(rawValue: "hermesSnake") == nil)
    }
}
