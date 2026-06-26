import Testing
import Foundation

@testable import Epistemos

// The native landing search launcher was retired with the old Swift chat surface.
// Skills now live in the dedicated Skills settings surface and clone-backed tools,
// not in a hidden landing composer.
@Suite("SS-VIS — landing has no native skill-run search launcher")
struct SSVISLandingSkillRunTests {

    @Test("landing no longer mounts the shared agent tool panel")
    func landingDoesNotMountAgentToolPanel() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        #expect(!landing.contains("AgentToolTogglePanel("))
        #expect(!landing.contains("onRunSkill:"))
        #expect(!landing.contains("func runSkillFromLanding"))
    }

    @Test("landing no longer primes hidden chat search text")
    func landingDoesNotPrimeHiddenSearchText() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        #expect(!landing.contains("landingSearchText = invocation"))
        #expect(!landing.contains("isLandingSearchFocused = true"))
        #expect(!landing.contains("showLandingToolPanel = false"))
    }
}
