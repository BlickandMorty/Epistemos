import Foundation
import Testing
@testable import Epistemos

@Suite("Agent Capability Truth Closeout")
struct AgentCapabilityTruthCloseoutTests {
    @Test("RuntimeRouter derives honest, experimental, and off agent badges")
    func runtimeRouterDerivesAllAgentCapabilityStates() {
        let honest = RuntimeRouter.agentCapabilityBadgeData(
            forLocalModelID: LocalTextModelID.qwen3_8B4Bit.rawValue
        )
        #expect(honest.state == .honest)
        #expect(honest.title == "HONEST")
        #expect(honest.falsifier == "F-LocalToolUse")
        #expect(honest.witness.contains("RuntimeRouter"))

        let experimental = RuntimeRouter.agentCapabilityBadgeData(
            forLocalModelID: LocalTextModelID.devstralSmall2505_4Bit.rawValue
        )
        #expect(experimental.state == .experimental)
        #expect(experimental.title == "EXPERIMENTAL")
        #expect(experimental.falsifier == "F-LocalToolUse pending")

        let off = RuntimeRouter.agentCapabilityBadgeData(
            forLocalModelID: LocalTextModelID.smolLM3_3B4Bit.rawValue
        )
        #expect(off.state == .off)
        #expect(off.title == "OFF")
        #expect(off.toolCallMode == .none)
    }

    @Test("model picker, Settings, Active Constellation, and AgentBlueprint surfaces expose capability truth")
    func visibleSurfacesExposeCapabilityTruth() throws {
        let rootView = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let activeConstellation = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ActiveConstellationRow.swift")
        let agentBlueprintView = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AgentBlueprintSettingsView.swift")
        let agentBlueprint = try loadMirroredSourceTextFile("Epistemos/LocalAgent/AgentBlueprint.swift")

        #expect(rootView.contains("localModelSubtitleWithAgentBadge(for: model)"))
        #expect(rootView.contains("Agent \\(badge.title)"))
        #expect(settings.contains("localModelPickerLabel(for: descriptor.id)"))
        #expect(settings.contains("activeLocalAgentBadgeData.title"))
        #expect(activeConstellation.contains("model.agentCapabilityBadge.title"))
        #expect(activeConstellation.contains("LocalAgentDiagnostics.snapshot().routePolicySummary"))
        #expect(!activeConstellation.contains("placeholder routes"))
        #expect(!activeConstellation.contains("No production route table is available yet"))
        #expect(agentBlueprintView.contains("modelBadgeStrip(for: modelChoice)"))
        #expect(agentBlueprintView.contains("modelPickerRow("))
        #expect(agentBlueprint.contains("RuntimeRouter.agentCapabilityBadgeData(forLocalModelID: modelID)"))
        #expect(agentBlueprint.contains("strict_grammar: \\(model.strictGrammarStatus)"))
    }

    @Test("legacy AgentCommandCenter donor shell is not resurrected for capability truth")
    func legacyAgentCommandCenterShellStaysAbsent() {
        let repoRootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let legacyFiles = [
            "Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift",
            "Epistemos/Views/AgentCommandCenter/BrainPickerMenu.swift",
            "Epistemos/Views/AgentCommandCenter/CommandBarView.swift",
            "Epistemos/Views/AgentCommandCenter/InspectorPanelView.swift",
            "Epistemos/Views/AgentCommandCenter/SuggestionPopoverView.swift",
        ]

        for path in legacyFiles {
            #expect(!FileManager.default.fileExists(atPath: repoRootURL.appendingPathComponent(path).path))
        }
    }
}
