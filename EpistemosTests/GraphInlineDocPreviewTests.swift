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

    @Test("loads via the from-primitives async path (read display) — no raw file read of the SDPage")
    func loadsViaPrimitives() throws {
        let card = try loadMirroredSourceTextFile("Epistemos/Views/Graph/GraphInlineDocPreview.swift")
        #expect(card.contains("loadBodyAsyncFromPrimitives"))
    }

    @Test("inline EDIT persists through the EXISTING saveBody pipeline — never a raw write")
    func editSavesViaProvenPath() throws {
        let card = try loadMirroredSourceTextFile("Epistemos/Views/Graph/GraphInlineDocPreview.swift")
        // Edits flow through page.saveBody (→ NoteFileStorage.writeBody + derived state) then a
        // model-context save — the SAME path the note editor uses. The data-loss floor: NO raw
        // file write and NO insert/delete from the card itself.
        #expect(card.contains("page.saveBody(editedBody)"))
        #expect(card.contains("modelContext.save()"))
        #expect(!card.contains("FileManager"))
        #expect(!card.contains(".write(to:"))
        #expect(!card.contains("modelContext.insert"))
        #expect(!card.contains("modelContext.delete"))
    }

    @Test("editing is explicit (Edit → Save/Cancel), so no edit ever auto-writes the vault")
    func editIsExplicit() throws {
        let card = try loadMirroredSourceTextFile("Epistemos/Views/Graph/GraphInlineDocPreview.swift")
        #expect(card.contains("isEditing"))
        #expect(card.contains("TextEditor(text: $editedBody)"))
        // Cancel leaves edit mode without calling save.
        #expect(card.contains("Button(\"Cancel\") { isEditing = false }"))
    }
}
