import Testing
import Foundation

@testable import Epistemos

// SS-VIS (owner 2026-06-20: "if the user wants to start off using a tool they should be able to").
// The landing capabilities launcher mounts the shared AgentToolTogglePanel; this wires its onRunSkill
// so a discovered skill runs straight from the landing search field — primed
// with its `/identifier` invocation. The previous mount passed the nil
// browse-only default. These pin the wiring so it can't silently regress to
// browse-only.
@Suite("SS-VIS — run a skill from the landing launcher")
struct SSVISLandingSkillRunTests {

    @Test("the landing launcher passes a real onRunSkill handler (not the nil browse-only default)")
    func landingPanelGetsSkillHandler() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        #expect(landing.contains("onRunSkill:"))
        #expect(landing.contains("func runSkillFromLanding"))
    }

    @Test("the handler primes the landing search field with the skill invocation, then focuses it")
    func handlerPrimesSearchField() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        // Stages the `/identifier ` invocation into the search text (does not auto-run — honest).
        #expect(landing.contains("landingSearchText = invocation"))
        #expect(landing.contains("isLandingSearchFocused = true"))
        // Closes the popover so the field is usable.
        #expect(landing.contains("showLandingToolPanel = false"))
    }
}
