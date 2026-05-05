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
        let graphFaculty = try loadMirroredSourceTextFile(
            "Epistemos/Views/Graph/HermesGraphFacultyGlyph.swift"
        )
        let hologramOverlay = try loadMirroredSourceTextFile(
            "Epistemos/Views/Graph/HologramOverlay.swift"
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

        #expect(graphFaculty.contains("HermesGraphFacultyGlyph"),
                "Hermes Snake must move to a graph-faculty glyph source")
        #expect(graphFaculty.contains("zPlusOne"),
                "Hermes graph-faculty placement must make the z+1 doctrine explicit")
        #expect(graphFaculty.contains("Canvas"),
                "Hermes graph faculty must keep a native SwiftUI Canvas placeholder until the Metal atlas lands")
        #expect(hologramOverlay.contains("HermesGraphFacultyGlyph("),
                "HologramOverlay must actually mount Hermes Snake as graph faculty above the graph plane")
        #expect(hologramOverlay.contains("hermesFacultyHostView"),
                "Graph faculty hosting must be explicit so route/mini visibility can keep it off non-canvas surfaces")
    }

    @Test("Landing Farm routes companions through deterministic roaming")
    func landingFarmUsesDeterministicRoamingField() throws {
        let farm = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/Farm/LandingFarmView.swift"
        )
        let roaming = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/Farm/CompanionRoamingField.swift"
        )

        #expect(farm.contains("CompanionRoamingField("),
                "LandingFarmView must mount the canonical roaming layer, not only a static roster grid")
        #expect(!farm.contains("LazyVGrid("),
                "LandingFarmView should not regress to the static grid-only companion surface")

        for token in [
            "TimelineView",
            "roamingPosition",
            "identityHash",
            "DeterministicPRNG",
            "reduceMotion",
            "clamp",
        ] {
            #expect(roaming.contains(token),
                    "CompanionRoamingField must preserve deterministic bounded roaming via \(token)")
        }
        #expect(!roaming.contains(".random"),
                "Landing roaming must be seeded from companion identity, not runtime randomness")
        #expect(!roaming.contains("repeatForever"),
                "Landing roaming must remain TimelineView-driven, not repeatForever animation")
    }

    @Test("Companion body kind parser rejects unknown parameter values")
    func companionBodyKindParserRejectsUnknownParameterValues() {
        #expect(CompanionBodyKind(rawValue: "block.compact.stubs.none.filled") == .blockCompact)
        #expect(CompanionBodyKind(rawValue: "block.wide.multi.single.negativeSpace") == .blockWide)

        #expect(CompanionBodyKind(rawValue: "block.bogus.stubs.none.filled") == nil)
        #expect(CompanionBodyKind(rawValue: "block.compact.bogus.none.filled") == nil)
        #expect(CompanionBodyKind(rawValue: "block.compact.stubs.bogus.filled") == nil)
        #expect(CompanionBodyKind(rawValue: "block.compact.stubs.none.bogus") == nil)
        #expect(CompanionBodyKind(rawValue: "block.compact.stubs.none.filled.extra") == nil)
        #expect(CompanionBodyKind(rawValue: "hermesSnake") == nil)
    }
}
