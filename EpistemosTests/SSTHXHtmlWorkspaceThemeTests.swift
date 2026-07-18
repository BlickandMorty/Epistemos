import Testing
import Foundation

@testable import Epistemos

// SS-THX item (4b, owner 2026-06-20): the HTML workspace "never changes because of the theme
// process." The workspaceTheme follows the in-app theme, and HTMLWorkspaceEditorView owns
// the document/editor surface variant exactly once. The PREVIEW snapshot used to refresh only
// on @Environment(\.colorScheme) (OS appearance), so an in-app PAIR change (or any pair while
// the system stays dark) never repainted the preview. Fix: also refresh the preview on the
// `theme` prop, which tracks ui.theme.
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
        #expect(preview.contains("lastRenderedThemeIdentity != themeIdentity"))
        #expect(preview.contains("themeIdentity: themeIdentity"))
        #expect(preview.contains("lastRenderedThemeIdentity = render.themeIdentity"))
        #expect(preview.contains("lastRenderedThemeIdentity = themeIdentity"))
    }

    @Test("the detached document feeds ui.theme into the workspace (so the theme prop tracks it)")
    func documentFeedsUIStateTheme() throws {
        let doc = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspaceDocument.swift")
        let editor = try loadMirroredSourceTextFile(
            "Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        // The themed root passes the raw live in-app theme as the `theme` prop; the editor applies
        // its workspace surface variant exactly once so preset palettes do not drift.
        #expect(doc.contains("theme: ui.theme,"))
        #expect(!doc.contains("theme: ui.theme.surfaceVariant(.other),"))
        #expect(editor.contains("private var workspaceTheme: EpistemosTheme"))
        #expect(editor.contains("(theme ?? (colorScheme == .dark ? EpistemosTheme.oledSoft : EpistemosTheme.light))\n            .surfaceVariant(.other)"))
    }
}
