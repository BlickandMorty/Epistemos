// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// DELTA CONTRACT, NOT A REPLACEMENT. The LIVE EpdocEditorChromeView.swift is ~1000+ lines
// (toolbar, autosave pipeline EpdocEditorSavePipeline, WKWebView pooling/teardown, theme bridge)
// and is pinned by EpdocVisibilitySourceGuardTests. This 24-line skeleton expresses ONE addition:
// the #if KINDRED_ENABLED minichat dock slot. Apply as a surgical edit to the live file.
// ════════════════════════════════════════════════════════════════════════════════════════════════
//  EpdocEditorChromeView.swift
//  EPI-RP-02-LUMENLENS
//
//  The chrome around the Epdoc lens (toolbar, bubble). On 1Code it also hosts the
//  KINDRED minichat dock (external seam — see EPI-RP-05-KINDRED). On MAS the dock is
//  compiled out entirely (no companion surface).

import SwiftUI

struct EpdocEditorChromeView: View {
    let noteId: UUID

    var body: some View {
        VStack(spacing: 0) {
            // TODO: toolbar + lens switcher (prose/epdoc/preview/source).
            MarkdownDocumentSurface(noteId: noteId)

            #if KINDRED_ENABLED
            // KINDRED external seam: the docked minichat lives here, 1Code-only.
            // MinichatDock(companionId: ..., sessionId: ...)   // provided by EPI-RP-05
            #endif
        }
    }
}
