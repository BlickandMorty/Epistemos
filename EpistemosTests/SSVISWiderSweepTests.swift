import Testing
import Foundation

@testable import Epistemos

// SS-VIS wider sweep (owner 2026-06-20: "all the things attached to the chat... on the search page and
// all places it should be"). The agent capability picker (AgentToolTogglePanel — the ~50 tools + MCP +
// cowork + skills) must be reachable from every chat surface, not only the main composer. The landing
// search launcher landed first (735940b7a); this extends the sweep to mini-chat. One registry, one
// picker — every surface mounts the SAME AgentToolTogglePanel (no clone). These pin that parity so a
// surface can't silently drop the capability affordance (the "muddy/hidden" gap the owner flagged).
@Suite("SS-VIS wider sweep — chat capabilities on more surfaces")
struct SSVISWiderSweepTests {

    @Test("mini-chat mounts the SHARED AgentToolTogglePanel, bound to the injected agentCommandCenter")
    func miniChatSurfacesAgentToolPanel() throws {
        let mini = try loadMirroredSourceTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        // Mounts the same picker the chat composer + landing search use.
        #expect(mini.contains("AgentToolTogglePanel("))
        // Bound to the single-source-of-truth catalog.
        #expect(mini.contains("agentCommandCenter: agentCommandCenter"))
        // Reads the injected state — crash-safe because withAppEnvironment injects
        // AgentCommandCenterState (AppEnvironment.swift) and the mini-chat window applies it.
        #expect(mini.contains("@Environment(AgentCommandCenterState.self)"))
    }

    @Test("graph-tunnel chat mounts the SHARED AgentToolTogglePanel, bound to injected agentCommandCenter")
    func graphChatSurfacesAgentToolPanel() throws {
        let sidebar = try loadMirroredSourceTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        #expect(sidebar.contains("AgentToolTogglePanel("))
        #expect(sidebar.contains("agentCommandCenter: agentCommandCenter"))
        // Crash-safe: injected via withAppEnvironment (overlay host re-applies it; embedded inherits).
        #expect(sidebar.contains("@Environment(AgentCommandCenterState.self)"))
    }

    @Test("note chat mounts the SHARED AgentToolTogglePanel, bound to injected agentCommandCenter")
    func noteChatSurfacesAgentToolPanel() throws {
        let note = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        #expect(note.contains("AgentToolTogglePanel("))
        #expect(note.contains("agentCommandCenter: agentCommandCenter"))
        // Crash-safe: injected via withAppEnvironment (the note window applies it; embedded inherits).
        #expect(note.contains("@Environment(AgentCommandCenterState.self)"))
    }

    @Test("the SAME panel is used across chat surfaces — one registry, one picker, no clone")
    func sharedPanelAcrossSurfaces() throws {
        for path in [
            "Epistemos/Views/Chat/ChatInputBar.swift",
            "Epistemos/Views/Landing/LandingView.swift",
            "Epistemos/Views/MiniChat/MiniChatView.swift",
            "Epistemos/Views/Graph/HologramSearchSidebar.swift",
            "Epistemos/Views/Notes/NoteDetailWorkspaceView.swift",
        ] {
            let src = try loadMirroredSourceTextFile(path)
            #expect(
                src.contains("AgentToolTogglePanel("),
                "\(path) must mount the shared AgentToolTogglePanel (capability parity across surfaces)"
            )
        }
    }
}
