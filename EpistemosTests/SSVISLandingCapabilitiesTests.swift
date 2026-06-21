import Testing
import Foundation

@testable import Epistemos

// SS-VIS (owner 2026-06-20): the ~50 agent tools + MCP + cowork + skills must be VISIBLE on the
// landing search page, not only in chat — the owner flagged this as a "muddy/hidden" surface-parity
// gap our checks failed to catch ("they are not working" = simply not surfaced, nothing broken).
// This pins the invariant at the surface: LandingView mounts the SAME AgentToolTogglePanel the chat
// composer uses (single registry, single picker — no clone), so a user can start a search already
// using a capability. If the landing launcher is ever dropped, this fails — which is exactly the
// surface-parity check that "has NOT been working."
@Suite("SS-VIS — chat capabilities surfaced on the landing search page")
struct SSVISLandingCapabilitiesTests {

    @Test("LandingView mounts the shared AgentToolTogglePanel from a stage-tools launcher")
    func landingSurfacesAgentToolPanel() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        // The launcher tile is wired into the search stage tools (visible on the search page).
        #expect(landing.contains("landingSearchCapabilitiesTool"))
        // It presents the SAME picker the chat composer uses — not a clone, not a new tool list.
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

    @Test("chat composer and landing use the SAME picker type (one registry, one picker, all places)")
    func chatAndLandingShareTheSamePicker() throws {
        let chat = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        // Both mount AgentToolTogglePanel — the parity the owner asked for ("all places it should be").
        #expect(chat.contains("AgentToolTogglePanel("))
        #expect(landing.contains("AgentToolTogglePanel("))
    }
}
