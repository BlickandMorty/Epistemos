import Foundation

// SS-GE (A) (owner 2026-06-21): the owner wants to EDIT all surfaces INLINE inside BOTH graphs (the
// home tunnel + the embedded/mini overlay), not have a surface "open a UTILITY instead" — today an
// Epdoc document node bounces to a detached document window (EpdocDocumentOpening.openDocument /
// NoteWindowManager) rather than rendering an inline editor.
//
// Ground truth (verified): GraphWorkspaceRoute has exactly .canvas / .note(id) / .folder(id), and
// GraphWorkspaceContainer renders .note → GraphNotePage and .folder → GraphFolderPage inline. So only
// note-like + folder nodes have an inline route; editable DOCUMENT nodes (.document = .epdoc package,
// .proseNote = ProseMirror JSON) have no inline route and fall through to the detached utility window.
//
// This pure classifier is the foundation the inline-edit work builds on: it names exactly which graph
// node kinds open inline today vs which editable-document kinds still bounce to the utility — i.e. the
// SS-GE (A) work list. It mutates nothing and never touches the graph/vault store; converting the
// fall-through kinds to inline editing (reusing the one md-first editor, no clone) is the follow-on,
// and a kind that genuinely can't edit inline yet should show an honest affordance, not a silent no-op.
enum GraphSurfaceInlineEditability {

    /// True iff a graph node of this type already renders + edits INLINE inside the graph workspace
    /// today — i.e. it resolves to a GraphWorkspaceRoute case (.note or .folder). Every other kind
    /// bounces to a detached utility window.
    static func opensInlineToday(_ type: GraphNodeType) -> Bool {
        switch type {
        // Note-like kinds (plain notes + the folder-typed note subkinds) → `.note(id)` route.
        case .note, .person, .project, .topic, .decision, .event, .resource:
            return true
        // Folder container → `.folder(id)` route (GraphFolderPage).
        case .folder:
            return true
        default:
            return false
        }
    }

    /// True iff this kind is an EDITABLE document surface the owner expects to edit in-graph: a
    /// note-like markdown doc OR an Epdoc/ProseMirror document. Graph entities/artifacts (tag, chat,
    /// run, rawThought, …) and the folder container are NOT editable document surfaces.
    static func isEditableDocumentSurface(_ type: GraphNodeType) -> Bool {
        switch type {
        case .note, .person, .project, .topic, .decision, .event, .resource:
            return true
        case .document, .proseNote:
            return true
        default:
            return false
        }
    }

    /// The SS-GE (A) work list: editable document surfaces that SHOULD edit inline but currently fall
    /// through to a detached utility window (Epdoc .document + ProseMirror .proseNote today). The
    /// inline-edit-in-both-graphs work targets exactly these; notes are already inline, so they are
    /// not on the list.
    static func fallsThroughToUtility(_ type: GraphNodeType) -> Bool {
        isEditableDocumentSurface(type) && !opensInlineToday(type)
    }
}
