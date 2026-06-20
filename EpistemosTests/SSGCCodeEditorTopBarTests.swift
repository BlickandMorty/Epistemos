import Testing
import SwiftUI

@testable import Epistemos

// SS-GC item (3B, owner 2026-06-20): the code-editor TOP BAR showed as a white card slab
// against the darker landing surround when the editor is opened inside the embedded home
// graph — CodeEditorView was presentation-blind (no themeOverride, unlike the prose branch).
// Fix: thread themeOverride; with one (embedded graph) the top bar paints the SAME window
// backdrop as the graph surround (AppWindowBackdropStyle, as HomeGraphEmbeddedView does);
// without one (notes / detached window) it keeps the existing card slab — unchanged.
@Suite("SS-GC code-editor top-bar theming")
@MainActor
struct SSGCCodeEditorTopBarTests {

    @Test("no override (standalone / notes / detached) keeps the card top bar — unchanged")
    func noOverrideKeepsCard() {
        let base = EpistemosTheme.oled
        #expect(
            CodeEditorView.resolvedTopBarBackground(themeOverride: nil, base: base)
                == MarkdownPreviewSurfaceStyle.flatBackground(for: base.surfaceVariant(.other))
        )
    }

    @Test("an override (embedded home graph) paints the graph backdrop, matching the surround")
    func overridePaintsGraphBackdrop() {
        let base = EpistemosTheme.oled
        let landingVariant = base.surfaceVariant(.landing)
        // The same backdrop the embedded-graph surround paints (HomeGraphEmbeddedView:83)
        // → the top bar blends instead of popping as a white card.
        #expect(
            CodeEditorView.resolvedTopBarBackground(themeOverride: landingVariant, base: base)
                == AppWindowBackdropStyle.background(for: landingVariant)
        )
    }
}
