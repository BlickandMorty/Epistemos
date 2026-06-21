import Testing
import Foundation

@testable import Epistemos

// L1201 / L2124 — owner: "powerful out of the box." A one-tap "Recommended" enables a curated
// best-of power set. These pin the deterministic core: the curation selects the broadly-useful
// tools, only ever from the LIVE catalog (real/working-only — it can't invent a tool), the apply
// is additive + catalog-bounded, and the control is flag-gated default-OFF.
@Suite("L1201 — best-of recommended power set")
struct EpistemosBestOfPresetTests {

    @Test("recommends the broadly-useful core tools from the live catalog; filters out the rest")
    func curation() {
        let available = [
            "vault_search", "vault_read", "vault_write", "web_fetch", "think",
            "memory_search", "note_list", "obscure_internal_tool", "danger_exec",
        ]
        let recommended = Set(EpistemosBestOfPreset.recommendedToolNames(from: available))
        #expect(recommended.contains("vault_search"))
        #expect(recommended.contains("web_fetch"))
        #expect(recommended.contains("think"))
        #expect(recommended.contains("memory_search"))
        // No matching fragment → excluded (not part of the recommended set).
        #expect(!recommended.contains("obscure_internal_tool"))
        #expect(!recommended.contains("danger_exec"))
    }

    @Test("only ever recommends names that exist in the supplied catalog (real/working only)")
    func realWorkingOnly() {
        let available = ["vault_search", "think"]
        #expect(EpistemosBestOfPreset.recommendedToolNames(from: available).allSatisfy { available.contains($0) })
        // Empty catalog → empty preset (never invents a tool).
        #expect(EpistemosBestOfPreset.recommendedToolNames(from: []).isEmpty)
    }

    @Test("the preset control flag defaults OFF")
    func flagDefaultsOff() {
        if ProcessInfo.processInfo.environment["EPISTEMOS_BEST_OF_PRESET_V0"] == nil {
            #expect(EpistemosBestOfPreset.isEnabled == false)
        }
    }

    @Test("apply is additive + catalog-bounded; the control is flag-gated")
    func applyWiring() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/State/AgentCommandCenterState.swift")
        #expect(src.contains("func applyBestOfPreset"))
        // Iterates EXISTING toggles, enabling only recommended ∩ catalog — additive, no reset.
        #expect(src.contains("for key in toolToggles.keys where recommended.contains(key)"))
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Chat/AgentToolTogglePanel.swift")
        #expect(panel.contains("EpistemosBestOfPreset.isEnabled"))
        #expect(panel.contains("agentCommandCenter.applyBestOfPreset()"))
    }
}
