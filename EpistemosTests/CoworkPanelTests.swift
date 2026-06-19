import Testing
import Foundation
@testable import Epistemos

/// REOPENED COWORK LAYOUT (P7.6) — locks the cohesive cowork panel: the sections
/// (Progress / Context / Working-folder / Queue / Connectors) wired to real run
/// telemetry with honest empty states, reachable from chat.
@Suite("Cowork panel layout")
struct CoworkPanelTests {

    @Test("the cowork panel assembles the sections from real telemetry with honest empty states")
    func panelAssemblesSections() throws {
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Chat/CoworkPanel.swift")
        #expect(panel.contains("@Environment(ChatState.self)"))
        // The five cohesive sections (the owner's Claude-Desktop layout).
        #expect(panel.contains("progressSection"))
        #expect(panel.contains("contextSection"))
        #expect(panel.contains("workingFolderSection"))
        #expect(panel.contains("queueSection"))
        #expect(panel.contains("connectorsSection"))
        // Connectors wired to the REAL surfaced-tools inventory (distribution-gated),
        // grouped by connector, with an honest empty state — no fake entries.
        #expect(panel.contains("OmegaToolRegistry.surfacedTools()"))
        #expect(panel.contains("connectorsByAgent"))
        #expect(panel.contains("No tools are surfaced on this build."))
        // Real telemetry sources.
        #expect(panel.contains("chat.isAgentExecuting"))
        #expect(panel.contains("chat.currentCapability.displayName"))
        #expect(panel.contains("CoworkRunContext.filesTouched("))
        #expect(panel.contains("queuedMessage"))
        // Honest empty states (not nothing / not fake).
        #expect(panel.contains("No files changed this run."))
        #expect(panel.contains("No message queued"))
        // Working folder stays Pro-gated (MAS-forbidden file mutation).
        #expect(panel.contains("!= .coreAppStore"))
    }

    @Test("the cowork panel is reachable from chat with the staged queue passed in")
    func panelReachableFromChat() throws {
        let composer = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        #expect(composer.contains("showCoworkPanel"))
        #expect(composer.contains("CoworkPanel(queuedMessage: messageQueue.pending)"))
        #expect(composer.contains(".popover(isPresented: $showCoworkPanel"))
    }
}
