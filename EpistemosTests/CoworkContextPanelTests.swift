import Testing
import Foundation
@testable import Epistemos

/// REOPENED CONTEXT (P7.6) — locks the real CONTEXT panel: it aggregates the actual
/// run telemetry (context window, @-notes, files, files-touched-this-run), shows an
/// honest empty state (not nothing), and is reachable from chat (the context badge
/// opens it).
@Suite("Cowork context panel")
struct CoworkContextPanelTests {

    @Test("the context panel aggregates real run telemetry with an honest empty state")
    func panelAggregatesTelemetry() throws {
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Chat/CoworkContextPanel.swift")
        // Reads ChatState + aggregates the 4 real sources.
        #expect(panel.contains("@Environment(ChatState.self)"))
        #expect(panel.contains("chat.pendingContextAttachments"))   // @-mentioned notes
        #expect(panel.contains("chat.pendingAttachments"))          // file attachments
        #expect(panel.contains("CoworkRunContext.filesTouched("))   // files touched this run
        #expect(panel.contains("chat.contextUsageFraction"))        // context-window usage
        // Honest empty state (not nothing).
        #expect(panel.contains("Nothing attached yet"))
        // Files-touched stays Pro-gated (MAS-forbidden file mutation).
        #expect(panel.contains("!= .coreAppStore"))
    }

    @Test("the context panel is reachable from chat — the context badge opens it")
    func panelReachableFromChat() throws {
        let composer = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        #expect(composer.contains("showContextPanel"))
        #expect(composer.contains("CoworkContextPanel()"))
        #expect(composer.contains(".popover(isPresented: $showContextPanel"))
        // The badge itself is preserved (now the panel's tap target).
        #expect(composer.contains("ContextWindowCompactBadge("))
    }
}
