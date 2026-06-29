import Testing
import Foundation

@testable import Epistemos

// SS-THX item (4b, owner 2026-06-20): the HTML workspace "never changes because of the theme
// process." The workspaceTheme already follows the in-app theme (the detached document's
// HTMLWorkspaceDocumentThemedRoot passes ui.theme.surfaceVariant(.other) as the `theme` prop),
// BUT the PREVIEW snapshot only refreshed on @Environment(\.colorScheme) (OS appearance) — so
// an in-app PAIR change (or any pair while the system stays dark) never repainted the preview.
// Fix: also refresh the preview on the `theme` prop, which tracks ui.theme.
@Suite("SS-THX HTML workspace theme repaint")
struct SSTHXHtmlWorkspaceThemeTests {

    @Test("the preview refreshes on an in-app theme change, not only OS colorScheme")
    func previewRefreshesOnThemeChange() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        // A theme-prop change now refreshes the preview snapshot (mirrors the colorScheme refresh).
        #expect(src.contains(".onChange(of: theme) {"))
        #expect(src.contains("themeIdentity: workspaceThemeIdentity"))
    }

    @Test("the WK preview render cache keys theme identity as well as HTML bytes")
    func previewCacheKeysThemeIdentity() throws {
        let preview = try loadMirroredSourceTextFile(
            "Epistemos/Views/HTMLWorkspace/HTMLWorkspacePreviewView.swift")
        #expect(preview.contains("lastRenderedThemeIdentity"))
        #expect(preview.contains("context.coordinator.lastRenderedThemeIdentity != themeIdentity"))
        #expect(preview.contains("context.coordinator.lastRenderedThemeIdentity = themeIdentity"))
    }

    @Test("the detached document feeds ui.theme into the workspace (so the theme prop tracks it)")
    func documentFeedsUIStateTheme() throws {
        let doc = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspaceDocument.swift")
        // The themed root passes the live in-app theme as the `theme` prop, so a pair/appearance
        // change flows into HTMLWorkspaceEditorView and now triggers the preview refresh above.
        #expect(doc.contains("HTMLWorkspaceEditorView(package: $package, theme: ui.theme.surfaceVariant(.other))"))
    }
}
