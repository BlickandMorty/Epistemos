import Testing
import SwiftUI
import AppKit

@testable import Epistemos

// SS-SH blank-sidebar diagnosis + render guard (owner 2026-06-20, item 2).
//
// DIAGNOSIS: the Settings sidebar going blank ON the Substrate Health page is NOT an
// independent sidebar bug — the SettingsView NavigationSplitView sidebar List is
// structurally sound and the detail column is already frame-bounded. It is a CASCADE from
// the blank DETAIL pane: a Form of collapsible Section(isExpanded:) renders DEGENERATE on
// macOS without .formStyle(.grouped), and a degenerate NavigationSplitView detail can
// collapse the whole split, blanking the sidebar column too. The .formStyle(.grouped) fix
// (commit 511b2a741) restores the detail's content, so both the panel and the cascading
// sidebar render. "No sidebar consumes the clock" (owner) is correct — this is layout, not
// the SubstrateHealthClock timer.
//
// This hardens the guard from a SUBSTRING match (which "never renders → missed the blank")
// to an actual RENDER / non-empty assertion on the REAL panel.
@Suite("SS-SH panel render guard (blank-panel + cascading blank-sidebar)")
struct SSSHPanelRenderGuardTests {

    @MainActor
    @Test("the real SubstrateHealthPanel renders non-blank")
    func panelRendersNonBlank() throws {
        // The mounted rows need only InferenceState injected; the panel self-injects its
        // SubstrateHealthClock via .environment. ImageRenderer takes a STATIC snapshot (it
        // does not run .task, so no FFI), so the rows render their initial honest state —
        // section headers + descriptions + per-row labels. WITHOUT .formStyle(.grouped) the
        // collapsible Form renders blank; this asserts it does not, on the actual panel.
        let panel = SubstrateHealthPanel()
            .environment(InferenceState())
            .frame(width: 460, height: 640)
        let renderer = ImageRenderer(content: panel)
        let image = try #require(renderer.nsImage, "the panel must render to an image")
        #expect(image.size.width >= 460)
        #expect(
            Self.hasRenderedContent(image),
            "the panel must render visible content, not a blank Form"
        )
    }

    /// True when the rendered bitmap has byte variation (actual content), not one flat color.
    @MainActor
    private static func hasRenderedContent(_ image: NSImage) -> Bool {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let bytes = rep.bitmapData else {
            return false
        }
        let total = rep.bytesPerRow * rep.pixelsHigh
        guard total > 64 else { return false }
        let first = bytes[0]
        var i = 0
        while i < total {
            if bytes[i] != first { return true }
            i += 13
        }
        return false
    }
}
