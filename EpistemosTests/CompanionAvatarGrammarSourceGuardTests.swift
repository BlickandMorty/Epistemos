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
            "CompanionHeadStyle",
            "CompanionArmStyle",
            "CompanionEyeShape",
            "CompanionAccessoryStyle",
        ] {
            #expect(model.contains(token),
                    "CompanionBodyKind must be parameterized per Simulation DOCTRINE §5.1 via \(token)")
        }
        #expect(!model.contains("case hermesSnake"),
                "Farm CompanionBodyKind must not offer Hermes Snake as a body choice")
        #expect(creationFlow.contains("CompanionBodyKind.creationPresets"),
                "Creation must use the canonical Farm presets, not every persisted/legacy shape")
        #expect(creationFlow.contains("bodyStyleControls"),
                "Creation must expose granular head, arm, eye, and accessory controls")
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

    @Test("Landing agents stay compact, chrome-free, and disconnected from chat prompts")
    func landingAgentsStayCompactChromeFreeAndDisconnectedFromPrompts() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let farm = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/LandingFarmView.swift")
        let glyph = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/CompanionAvatarGlyph.swift")
        let companion = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/CompanionView.swift")
        let creation = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/CompanionCreationFlow.swift")
        let state = try loadMirroredSourceTextFile("Epistemos/State/Companion/CompanionState.swift")
        let pipeline = try loadMirroredSourceTextFile("Epistemos/Engine/PipelineService.swift")
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
        #expect(creation.contains("pixelPanel(theme:"))
        #expect(creation.contains("PixelPanelTitle(text: isEditing ? \"Edit Agent\" : \"New Agent\""))
        #expect(creation.contains("settingsAppleCardChrome(theme:"))
        #expect(creation.contains("PixelPanelBackground.actionSurface(for: theme)"))
        #expect(!creation.contains(".background(.regularMaterial)"))
        #expect(!creation.contains("RoundedRectangle(cornerRadius: 16"))
        #expect(!creation.contains(".textFieldStyle(.roundedBorder)"))
        #expect(landing.contains("if (farmShowingCreate || farmEditTarget != nil)"))
        #expect(landing.contains("CompanionCreationFlow("))
        #expect(landing.contains("Color.clear"))
        #expect(!landing.contains(".sheet(isPresented: $farmShowingCreate)"))
        #expect(state.contains("Scout"),
                "Seeded agents should include a non-orb scout body")
        #expect(CompanionBodyKind.creationPresets.count >= 6,
                "Creation should expose more than the initial three block/sage body silhouettes")
        #expect(!creation.contains("@State private var bodyKind: CompanionBodyKind = .orb"),
                "New agents must not default to the circular orb body")

        #expect(!state.contains("activeAgentSystemInstruction"),
                "Companion state must not expose prompt-injection helpers")
        #expect(!state.contains("activeAgentBrainSection"),
                "Companion state must not expose per-mascot brain/runtime sections")
        #expect(!state.contains("agentSystemInstruction"),
                "Companion state must not synthesize chat system instructions")
        #expect(!state.contains("personaPrompt"),
                "Companion state must not store prompt/persona setup")
        #expect(!state.contains("loraAdapterPath"),
                "Companion state must not bind mascots to adapter overrides")
        #expect(!landing.contains("activeAgentName"),
                "Landing search placeholder must not route through active mascot identity")
        #expect(state.contains("activateOnCreate: Bool = true"),
                "Newly created companions should become visibly active")
        #expect(!pipeline.contains("activeCompanionInstructionProvider"),
                "The chat pipeline must not receive companion prompt instructions")
        #expect(!bootstrap.contains("activeCompanionInstructionProvider:"),
                "AppBootstrap must not wire companions into PipelineService prompts")

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

    @Test("Landing companions keep mascot editing without provider or tool routing")
    func landingCompanionsKeepMascotEditingWithoutRuntimeRouting() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let farm = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/LandingFarmView.swift")
        let roaming = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/CompanionRoamingField.swift")
        let creation = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/CompanionCreationFlow.swift")
        let model = try loadMirroredSourceTextFile("Epistemos/Models/Companion/CompanionModel.swift")
        let state = try loadMirroredSourceTextFile("Epistemos/State/Companion/CompanionState.swift")

        for retiredField in [
            "agentModelRoutingID",
            "agentModelDisplayName",
            "agentToolNamesRaw",
            "agentScopeRaw",
            "agentApprovalModeRaw",
            "customSystemPromptTemplate",
            "outputStructureJSON",
            "mcpServerConfigJSON",
            "memoryPinPattern",
            "toolSelectionModeRaw",
            "autonomousExecConfigJSON",
            "CompanionToolSelectionMode",
            "personaPrompt",
            "loraAdapterPath",
        ] {
            #expect(!model.contains(retiredField),
                    "CompanionModel must stay visual-only and omit \(retiredField)")
        }

        #expect(state.contains("func updateCompanion("),
                "Landing companions need an edit path, not create/delete only")
        #expect(!state.contains("agentModelChoice"),
                "Companion state must not expose a per-companion model route")

        #expect(!creation.contains("availableBrains"))
        #expect(!creation.contains("availableTools"))
        #expect(!creation.contains("selectedToolNames"))
        #expect(!creation.contains("Provider + model"))
        #expect(!creation.contains("Tools + guardrails"))
        #expect(!creation.contains("TextEditor"))
        #expect(!creation.contains("Behavior"))
        #expect(!creation.contains("personaPrompt"))

        #expect(farm.contains("onRequestEdit"),
                "The AGENTS dock must expose an edit route")
        #expect(!farm.contains("onStartChat"),
                "The AGENTS dock must not expose a direct chat route")
        #expect(roaming.contains("Label(\"Edit\", systemImage: \"pencil\")"),
                "Companion context menus must support editing the visible mascot")
        #expect(!roaming.contains("Label(\"Chat with \\(entry.name)\", systemImage: \"message.fill\")"),
                "Companion context menus must not launch chat from mascot visuals")
        #expect(landing.contains("farmEditTarget"),
                "Landing must distinguish create from edit instead of overwriting active companions")
        #expect(!landing.contains("private func startFarmAgentChat"),
                "Landing mascots must not keep direct chat-launch wiring")
        #expect(!landing.contains("onStartChat:"),
                "Landing must not pass a chat-launch callback into the mascot dock")
        #expect(!landing.contains("applyActiveLandingAgentRuntimePreference"),
                "Landing must not keep even an inert active-mascot runtime hook")
        #expect(!landing.contains("applyLandingAgentRuntimePreference(for: entry)"),
                "Direct companion chat must not apply a hidden per-companion model route")
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

    @Test("Landing Farm deletes deferred adapter hot-swap setup")
    func landingFarmDeletesDeferredAdapterHotSwapSetup() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let farm = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/LandingFarmView.swift")
        let roaming = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Farm/CompanionRoamingField.swift")

        #expect(!landing.contains("farmAdapterTarget"),
                "Landing must not keep a sheet route for the deferred adapter pipeline")
        #expect(!landing.contains("CompanionAdapterView("),
                "Landing must not mount the deferred adapter scaffold as a v1 feature")
        #expect(!farm.contains("onApplyAdapter"),
                "LandingFarmView must not pass through an apply-adapter callback until hot-swap is real")
        #expect(!roaming.contains("Apply Adapter..."),
                "The companion context menu must not expose a fake adapter action")
        #expect(!landing.contains("Adapter Pipeline Deferred"))
        #expect(!farm.contains("Adapter Pipeline Deferred"))
        #expect(!roaming.contains("Adapter Pipeline Deferred"))
    }

    @Test("Companion body kind parser rejects unknown parameter values")
    func companionBodyKindParserRejectsUnknownParameterValues() {
        #expect(CompanionBodyKind(rawValue: "block.compact.stubs.none.filled") == .blockCompact)
        #expect(CompanionBodyKind(rawValue: "block.wide.multi.single.negativeSpace") == .blockWide)
        #expect(CompanionBodyKind(rawValue: "block.tall.stubs.double.filled") == .blockTall)
        #expect(CompanionBodyKind(rawValue: "block.compact.none.single.filled") == .blockSignal)
        #expect(CompanionBodyKind(rawValue: "block.wide.stubs.double.filled") == .blockTwin)
        #expect(CompanionBodyKind(rawValue: "block.compact.stubs.none.filled.crown.wave.visor.glasses")?.resolvedAccessoryStyle == .glasses)
        #expect(CompanionBodyKind(rawValue: "sage.cap.side.bar.mustache")?.resolvedHeadStyle == .cap)

        #expect(CompanionBodyKind(rawValue: "block.bogus.stubs.none.filled") == nil)
        #expect(CompanionBodyKind(rawValue: "block.compact.bogus.none.filled") == nil)
        #expect(CompanionBodyKind(rawValue: "block.compact.stubs.bogus.filled") == nil)
        #expect(CompanionBodyKind(rawValue: "block.compact.stubs.none.bogus") == nil)
        #expect(CompanionBodyKind(rawValue: "block.compact.stubs.none.filled.crown.wave.visor.bogus") == nil)
        #expect(CompanionBodyKind(rawValue: "sage.cap.side.bogus.mustache") == nil)
        #expect(CompanionBodyKind(rawValue: "block.compact.stubs.none.filled.extra") == nil)
        #expect(CompanionBodyKind(rawValue: "hermesSnake") == nil)
    }
}
