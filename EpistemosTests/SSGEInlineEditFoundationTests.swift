import Testing
import Foundation

@testable import Epistemos

// SS-GE (A) (owner 2026-06-21): the owner wants every surface editable INLINE in both graphs, not
// bounced to a detached "utility" window. GraphWorkspaceRoute only has .note / .folder, so editable
// DOCUMENT nodes (Epdoc .document, ProseMirror .proseNote) have no inline route and fall through to
// EpdocDocumentOpening.openDocument today. These pin the classifier that names the work list, so the
// inline-edit work targets exactly the fall-through kinds (and the classifier can't silently drift).
@Suite("SS-GE (A) — graph surface inline-editability classification")
struct SSGEInlineEditFoundationTests {

    @Test("note-like + folder nodes already open inline in the graph (.note / .folder route)")
    func notesAndFoldersOpenInline() {
        for type in [GraphNodeType.note, .person, .project, .topic, .decision, .event, .resource, .folder] {
            #expect(GraphSurfaceInlineEditability.opensInlineToday(type))
        }
    }

    @Test("Epdoc documents + ProseMirror notes do NOT open inline today (they bounce to the utility)")
    func documentsBounceToUtilityToday() {
        #expect(!GraphSurfaceInlineEditability.opensInlineToday(.document))
        #expect(!GraphSurfaceInlineEditability.opensInlineToday(.proseNote))
    }

    @Test("the SS-GE (A) work list = editable doc surfaces that fall through to the detached utility")
    func utilityFallthroughIsTheWorkList() {
        // The gap to close: editable documents that should be inline but aren't.
        #expect(GraphSurfaceInlineEditability.fallsThroughToUtility(.document))
        #expect(GraphSurfaceInlineEditability.fallsThroughToUtility(.proseNote))
        // Notes are already inline → not on the work list.
        #expect(!GraphSurfaceInlineEditability.fallsThroughToUtility(.note))
        #expect(!GraphSurfaceInlineEditability.fallsThroughToUtility(.resource))
        // Non-document entities/containers are not editable doc surfaces at all.
        #expect(!GraphSurfaceInlineEditability.fallsThroughToUtility(.tag))
        #expect(!GraphSurfaceInlineEditability.fallsThroughToUtility(.chat))
        #expect(!GraphSurfaceInlineEditability.fallsThroughToUtility(.folder))
    }

    @Test("editable-document classification: docs + notes yes, entities no")
    func editableDocumentSurfaceClassification() {
        #expect(GraphSurfaceInlineEditability.isEditableDocumentSurface(.note))
        #expect(GraphSurfaceInlineEditability.isEditableDocumentSurface(.document))
        #expect(GraphSurfaceInlineEditability.isEditableDocumentSurface(.proseNote))
        #expect(!GraphSurfaceInlineEditability.isEditableDocumentSurface(.folder))
        #expect(!GraphSurfaceInlineEditability.isEditableDocumentSurface(.tag))
        #expect(!GraphSurfaceInlineEditability.isEditableDocumentSurface(.run))
    }
}
