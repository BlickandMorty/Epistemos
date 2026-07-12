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

    @Test("Epdoc queues theme JavaScript until the Tiptap WebView finishes loading")
    func epdocThemeJavaScriptIsLoadGated() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Epdoc/EpdocEditorChromeView.swift"
        )
        let snapshot = try Self.extractFunction(
            signature: "private func evaluateCurrentMarkdownSnapshot() async -> String?",
            from: src
        )
        let dismantle = try Self.extractFunction(
            signature: "static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator)",
            from: src
        )

        #expect(src.contains("view.navigationDelegate = context.coordinator"))
        #expect(src.contains("private var pendingTheme: EpistemosTheme?"))
        #expect(src.contains("guard !webView.isLoading else"))
        #expect(src.contains("flushPendingTheme(in: webView)"))
        #expect(src.contains("isDetached = true"))
        #expect(snapshot.contains("guard !isDetached, let webView else { return nil }"))
        #expect(snapshot.contains("guard !webView.isLoading else"))
        #expect(snapshot.contains("return controller?.latestMarkdownSnapshot"))
        let loadingGuard = try #require(snapshot.range(of: "guard !webView.isLoading else"))
        let evaluation = try #require(snapshot.range(of: "webView.evaluateJavaScript(expression)"))
        #expect(loadingGuard.lowerBound < evaluation.lowerBound)
        #expect(Self.offset(of: "coordinator.shutdown()", in: dismantle) < Self.offset(of: "view.stopLoading()", in: dismantle))
        #expect(Self.offset(of: "view.navigationDelegate = nil", in: dismantle) < Self.offset(of: "view.stopLoading()", in: dismantle))
        #expect(Self.offset(of: "removeScriptMessageHandler", in: dismantle) < Self.offset(of: "view.stopLoading()", in: dismantle))
    }

    @Test("HTML Workspace coalesces preview reloads and data patches while WebView is loading")
    func htmlWorkspacePreviewReloadsAreLoadGated() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/HTMLWorkspace/HTMLWorkspacePreviewView.swift"
        )

        #expect(src.contains("private struct PendingRender"))
        #expect(src.contains("private var isLoadingPreview = false"))
        #expect(src.contains("private var pendingRender: PendingRender?"))
        #expect(src.contains("pendingRender = render"))
        #expect(src.contains("guard !isLoadingPreview, !webView.isLoading else"))
        #expect(src.contains("finishPreviewNavigation(in: webView, didLoadPage: true)"))
        #expect(!src.contains("webView.loadHTMLString(rendered, baseURL: HTMLWorkspacePreviewURL.baseURL)"))
    }

    @Test("legacy code editor invalidates callbacks before stopping WKWebView loads")
    func legacyCodeEditorTeardownIsCallbackAndLoadGated() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Notes/WebKitCodeEditorView.swift"
        )
        let detach = try Self.extractFunction(
            signature: "func detach(from webView: WKWebView)",
            from: src
        )
        let processRecovery = try Self.extractFunction(
            signature: "func webViewWebContentProcessDidTerminate(_ webView: WKWebView)",
            from: src
        )

        #expect(src.contains("private var isDetached = false"))
        #expect(src.contains("private var loadGeneration = 0"))
        #expect(src.contains("private var pendingSelectionRequest: WebKitCodeEditorSelectionRequest?"))

        #expect(detach.contains("isDetached = true"))
        #expect(Self.offset(of: "isDetached = true", in: detach) < Self.offset(of: "webView.stopLoading()", in: detach))
        #expect(Self.offset(of: "webView.navigationDelegate = nil", in: detach) < Self.offset(of: "webView.stopLoading()", in: detach))
        #expect(Self.offset(of: "removeScriptMessageHandler", in: detach) < Self.offset(of: "webView.stopLoading()", in: detach))

        #expect(src.contains("guard !isDetached else { return }"))
        #expect(src.contains("if hasLoadedEditor, !webView.isLoading"))
        #expect(src.contains("guard !isDetached, hasLoadedEditor, !webView.isLoading else"))
        #expect(src.contains("generation == self.loadGeneration"))
        #expect(src.contains("!self.isDetached else { return }"))
        #expect(src.contains("self.lastAppliedState = previousState"))
        #expect(src.contains("pendingSelectionRequest = selectionRequest"))
        #expect(processRecovery.contains("let recoveryState = pendingState ?? lastAppliedState"))
        #expect(processRecovery.contains("let recoverySelectionRequest = pendingSelectionRequest"))
        #expect(processRecovery.contains("loadEditor(into: webView)"))
        #expect(processRecovery.contains("pendingState = recoveryState"))
        #expect(processRecovery.contains("pendingSelectionRequest = recoverySelectionRequest"))
        #expect(!processRecovery.contains("editor blanked; reopen to recover"))
        #expect(src.contains("""
            guard !isDetached else {
                decisionHandler(.cancel)
                return
            }
            """))
    }

    private static func extractFunction(signature: String, from source: String) throws -> String {
        guard let nameRange = source.range(of: signature) else {
            throw DarkLightCrashTestError.missingFunction(signature)
        }
        guard let openBrace = source[nameRange.upperBound...].firstIndex(of: "{") else {
            throw DarkLightCrashTestError.missingFunction(signature)
        }

        var depth = 0
        var index = openBrace
        while index < source.endIndex {
            let character = source[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[openBrace...index])
                }
            }
            index = source.index(after: index)
        }

        throw DarkLightCrashTestError.missingFunction(signature)
    }

    private static func offset(of needle: String, in haystack: String) -> Int {
        guard let range = haystack.range(of: needle) else { return Int.max }
        return haystack.distance(from: haystack.startIndex, to: range.lowerBound)
    }
}

private enum DarkLightCrashTestError: Error, CustomStringConvertible {
    case missingFunction(String)

    var description: String {
        switch self {
        case .missingFunction(let name):
            return "Missing dark/light crash guard function: \(name)"
        }
    }
}
