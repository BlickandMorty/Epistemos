import Testing
import Foundation
@testable import Epistemos

/// SS-U (owner 2026-06-19, "turning to dark and light mode often crashes the app"):
/// the HTML Workspace preview WKWebView must NOT be destroyed + recreated on an
/// appearance flip. Root cause was `previewRenderIdentity` folding the theme hash
/// into the SwiftUI `.id`, forcing dismantleNSView→makeNSView mid-render (a known
/// WebKit fault window). The identity must stay content-only; the live WebView
/// re-themes via updateNSView instead.
@Suite("Dark/light WebView crash (SS-U)")
struct DarkLightCrashTests {

    @Test("preview render identity no longer folds the theme hash into the WebView .id")
    func previewIdentityExcludesThemeHash() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift"
        )
        // Regression lock: the theme-hash component must NOT be appended to the
        // preview render identity — that forced a WebView teardown on every flip.
        #expect(!src.contains("-\\(workspaceThemeIdentity.hashValue)"))
        // The theme still reaches the LIVE preview as a render property (the
        // re-theme-in-place path that replaces the teardown).
        #expect(src.contains("themeIdentity: workspaceThemeIdentity"))
    }
}
