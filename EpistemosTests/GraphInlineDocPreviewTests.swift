import Testing
import Foundation

@testable import Epistemos

// SS-GE (A) first increment (L4435, owner "risky core"): a read-only INLINE note preview
// in the graph sidebar instead of bouncing to a detached Notes window. This pins the safe
// contract — flag default-OFF (byte-identical: note nodes keep opening a window), the
// sidebar gates the affordance + renders the card, and the preview is READ-ONLY (loads via
// loadBodyAsync, never a write) so there is no data-loss surface. Inline EDIT via the
// existing note-save pipeline is the next increment.
@Suite("SS-GE — inline doc preview (read-only, flag-gated)")
struct GraphInlineDocPreviewTests {

    @Test("the inline preview flag defaults OFF (note nodes keep opening a window until opt-in)")
    func flagDefaultsOff() {
        if ProcessInfo.processInfo.environment["EPISTEMOS_GRAPH_INLINE_DOC_EDIT_V0"] == nil {
            #expect(GraphInlineDocPreviewFlag.enabled == false)
        }
    }

    @Test("the sidebar gates the inline preview affordance behind the flag + renders the card")
    func sidebarWiresPreviewBehindFlag() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        #expect(src.contains("GraphInlineDocPreviewFlag.enabled"))
        #expect(src.contains("GraphInlineDocPreviewCard(pageId: pageId"))
        #expect(src.contains("showInlinePreview = true"))
    }

    @Test("the preview is read-only — loads via loadBodyAsync, never writes the vault")
    func previewIsReadOnly() throws {
        let card = try loadMirroredSourceTextFile("Epistemos/Views/Graph/GraphInlineDocPreview.swift")
        #expect(card.contains("loadBodyAsync"))
        // No write/save API in the read-only preview — the data-loss floor.
        #expect(!card.contains("saveBody"))
        #expect(!card.contains("modelContext.insert"))
        #expect(!card.contains("modelContext.delete"))
    }
}
