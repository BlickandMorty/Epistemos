// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// DELTA CONTRACT, NOT A REPLACEMENT. The LIVE MarkdownDocumentSurface.swift already mounts Epdoc
// over the note body and saves via saveMarkdownDocumentSurfaceContent (guard-test-pinned). This
// skeleton expresses the ADDITIONS: the NoteSessionStateMachine binding + applyWriteback(region).
// The disk write goes through KEELSTONE's AtomicVaultWriter (whole-buffer atomic; the splice is in
// memory — minimal-diff = which BYTES change, never partial file IO).
// ════════════════════════════════════════════════════════════════════════════════════════════════
//  MarkdownDocumentSurface.swift
//  EPI-RP-02-LUMENLENS
//
//  Mounts the Epdoc lens over a note body and writes back through the markdown pipeline.
//  This is the surface that consumes minimal-diff writeback (Fork B): a `writeback`
//  outbound message replaces ONLY the changed block range in the on-disk buffer.

import SwiftUI

struct MarkdownDocumentSurface: View {
    let noteId: UUID
    @State private var session = NoteSessionStateMachine()

    var body: some View {
        // TODO: host the Epdoc WKWebView (EpdocEditorBridge) + wire the F6 bus.
        EmptyView()
    }

    /// Apply a minimal-diff writeback region to the on-disk note body.
    func applyWriteback(changedFrom: Int, changedTo: Int, blockMarkdown: String) {
        // TODO: splice [changedFrom, changedTo] in the on-disk buffer with blockMarkdown.
        //       Preserve line endings / indent / list markers everywhere else.
        _ = (changedFrom, changedTo, blockMarkdown)
    }
}
