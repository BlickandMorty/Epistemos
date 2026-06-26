import Testing
import Foundation

@testable import Epistemos

// SS-VIS (owner 2026-06-20): the agent tools + MCP + cowork + skills must be
// VISIBLE on the landing search page. The owner flagged this as a
// "muddy/hidden" surface-parity gap our checks failed to catch ("they are not
// working" = simply not surfaced, nothing broken).
// This pins the invariant at the surface: LandingView mounts the shared
// AgentToolTogglePanel, so a user can start a search already using a capability.
// The old native chat composer was deleted; the rebuilt AgentClone/fusion chat
// must consume the same registry instead of reviving the old composer.
@Suite("SS-VIS — agent capabilities surfaced on the landing search page")
struct SSVISLandingCapabilitiesTests {

    @Test("LandingView mounts the shared AgentToolTogglePanel from a stage-tools launcher")
    func landingSurfacesAgentToolPanel() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        // The launcher tile is wired into the search stage tools (visible on the search page).
        #expect(landing.contains("landingSearchCapabilitiesTool"))
        // It presents the shared picker — not a clone, not a new tool list.
        #expect(landing.contains("AgentToolTogglePanel("))
        // Bound to the single-source-of-truth catalog (the app-wide agentCommandCenter).
        #expect(landing.contains("agentCommandCenter: agentCommandCenter"))
    }

    @Test("the launcher is placed in the search stage-tools row (reachable, not buried)")
    func launcherIsInTheStageToolsRow() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        // landingSearchStageTools is the row that holds the brain + tools tiles below the search line;
        // the capabilities tile must be a sibling there so it shows up alongside them.
        guard let stageRange = landing.range(of: "landingSearchBrainTool") else {
            Issue.record("landingSearchBrainTool anchor not found — LandingView search-tools layout moved")
            return
        }
        let afterBrain = landing[stageRange.lowerBound...]
        // The capabilities tile is referenced in the same stage-tools region (within the HStack).
        #expect(afterBrain.contains("landingSearchCapabilitiesTool"))
    }

    @Test("landing tool panel stays alongside the protected AgentClone route")
    func landingToolPanelStaysAlongsideAgentCloneRoute() throws {
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(root.contains("AgentClone.ContentView()"))
        #expect(landing.contains("AgentToolTogglePanel("))
    }
}
