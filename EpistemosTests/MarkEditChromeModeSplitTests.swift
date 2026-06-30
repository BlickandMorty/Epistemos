import Foundation
import Testing

@Suite("MarkEdit L3-CHROME mode split guards (Plan 2)")
nonisolated struct MarkEditChromeModeSplitTests {
    @Test("Note workspace exposes Edit/Prose, Preview, and Source as explicit markdown modes")
    func noteWorkspaceExposesExplicitMarkdownModes() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(source.contains(#""Edit/Prose""#))
        #expect(source.contains(#""Preview""#))
        #expect(source.contains(#""Source""#))
        #expect(source.contains("return sourceFileRoute(for: page) == nil\n                ? [.edit, .preview]\n                : [.edit, .preview, .source]"))
        #expect(source.contains(".frame(width: modes.count >= 3 ? 306 : 214)"))
        #expect(source.contains(#".accessibilityLabel("Note view mode")"#))
        #expect(source.contains(#""Switch between Edit/Prose, Preview, and Source""#))
        #expect(source.contains("setNoteMode($0, for: page)"))
    }

    @Test("CodeEditorView selects markdown chrome, default code chrome, and legacy v1 fallback")
    func codeEditorViewSelectsMarkdownCodeAndLegacyFallback() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let iconSource = try loadMirroredSourceTextFile("Epistemos/Views/Notes/CodeFileIconView.swift")
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let editorContent = try Self.extractBlock(named: "editorContent", from: source)
        let codeChrome = try Self.extractBlock(named: "codeEditorChromeContent", from: source)
        let codeSurface = try Self.extractBlock(named: "codeEditorSurface", from: source)
        let livePreview = try Self.extractBlock(named: "codeLivePreview", from: source)

        #expect(source.contains("private var isMarkdownDocument"))
        #expect(source.contains(#"@AppStorage("codeEditor.useLegacyV1Editor") private var useLegacyV1Editor = false"#))
        #expect(source.contains("useLegacyV1Editor && !isMarkdownDocument"))
        #expect(settings.contains(#"@AppStorage("codeEditor.useLegacyV1Editor") private var useLegacyV1Editor = false"#))
        #expect(settings.contains(#"Toggle("Use v1 Legacy Code Editor", isOn: $useLegacyV1Editor)"#))
        #expect(editorContent.contains("if isMarkdownDocument"))
        #expect(editorContent.contains("MarkEditMarkdownEditorRepresentable("))
        #expect(editorContent.contains("codeEditorChromeContent"))
        #expect(codeSurface.contains("MarkEditCodeEditorRepresentable("))
        #expect(codeSurface.contains("WebKitCodeEditorView("))
        #expect(!codeSurface.contains("SourceEditor("))
        #expect(codeChrome.contains("""
            HStack(spacing: 0) {
                editorWithSearch
                outlineNavigator
                if CodeEditorReleasePolicy.semanticSidebarEnabled {
                    semanticSidebar
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            """))
        #expect(codeChrome.contains(".padding(.bottom, 12)\n        }\n        .frame(maxWidth: .infinity, maxHeight: .infinity)"))

        #expect(source.contains("showLivePreview.toggle()"))
        #expect(livePreview.contains("HTMLWorkspacePreviewView("))
        #expect(livePreview.contains("livePreviewPackage"))
        #expect(source.contains("CodeFileIconView(filePath: filePath, language: language, theme: codeEditorTheme)"))
        #expect(iconSource.contains("NSWorkspace.shared.icon(forFile: filePath)"))
    }

    @Test("Code live preview updates the existing WKWebView instead of rebuilding on text edits")
    func codeLivePreviewDoesNotKeyPreviewIdentityToText() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let livePreview = try Self.extractBlock(named: "codeLivePreview", from: source)

        #expect(livePreview.contains("HTMLWorkspacePreviewView("))
        #expect(!livePreview.contains(".id(livePreview"))
        #expect(source.contains("private var livePreviewThemeIdentity: String"))
        #expect(!source.contains("livePreviewText.hashValue"))
    }

    @Test("MarkEdit CoreEditor adapter uses vendored bundle and generated MarkEdit bridge surface")
    func markEditCoreEditorAdapterUsesVendoredBundleAndBridgeSurface() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
        let resources = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorRuntimeResources.swift")

        #expect(source.contains("struct MarkEditCodeEditorRepresentable"))
        #expect(source.contains("struct MarkEditMarkdownEditorRepresentable"))
        #expect(source.contains("MarkEditVerbatimMarkdownChromeRepresentable"))
        #expect(source.contains("makeNSViewController(context: Context) -> EditorViewController"))
        #expect(source.contains("#if canImport(MarkEditKit)"))
        #expect(source.contains("MarkEditCoreEditorBridge"))
        #expect(source.contains("MarkEditCoreEditorChunkLoader()"))
        #expect(resources.contains("final class MarkEditCoreEditorChunkLoader"))
        #expect(resources.contains("{{EDITOR_CONFIG}}"))
        #expect(source.contains("CoreEditor"))
        #expect(source.contains("webModules.core.resetEditor"))
        #expect(source.contains("window.webModules.core.getEditorText()"))
        #expect(source.contains("epistemosMarkEditCoreEditor"))
    }

    @Test("CoreEditor adapter waits for the JS bridge before the first reset")
    func markEditCoreEditorAdapterWaitsForBridgeBeforeInitialReset() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")

        #expect(source.contains("waitForCoreEditorReady"))
        #expect(source.contains("window.webModules?.core?.resetEditor"))
        #expect(source.contains("finishLoadingEditor(in: webView)"))
        #expect(source.contains("resetEditor(to: state, in: webView, documentChanged: true)"))
        #expect(!source.contains("lastAppliedState = initialState"))
    }

    @Test("CoreEditor embed registers MarkEdit native bridge and fails visibly when reset is blank")
    func markEditCoreEditorRegistersNativeBridgeAndBlankResetDiagnostics() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")

        #expect(source.contains(#"static let nativeMessageHandlerName = "bridge""#))
        #expect(source.contains(#"static let baseURL = URL(string: "http://localhost/")"#))
        #expect(source.contains("webView.loadHTMLString(html, baseURL: MarkEditCoreEditorBridge.baseURL)"))
        #expect(source.contains("WKScriptMessageHandlerWithReply"))
        #expect(source.contains("addScriptMessageHandler("))
        #expect(source.contains("removeScriptMessageHandler(\n            forName: MarkEditCoreEditorBridge.nativeMessageHandlerName,\n            contentWorld: .page"))
        #expect(source.contains("callAsyncJavaScript(script, in: nil, in: .page)"))
        #expect(!source.contains("(async () => {"))
        #expect(source.contains("setTimeout(finish, 100)"))
        #expect(source.contains("CoreEditor reset completed with no rendered CodeMirror text"))
        #expect(source.contains("resetFailureMessage(result: scriptResult, error: scriptError)"))
    }

    @Test("MarkEdit markdown chrome applies reset state only after async success")
    func markEditMarkdownChromeAppliesResetStateOnlyAfterAsyncSuccess() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")

        #expect(source.contains("private var applyingText: String?"))
        #expect(source.contains("private var applyTask: Task<Void, Never>?"))
        #expect(source.contains("applyTask?.cancel()"))
        #expect(source.contains("defer {\n                if generation == self.applyGeneration {"))
        #expect(source.contains("self.lastAppliedText = nextText"))
        #expect(!source.contains("lastAppliedText = nextText\n        updateLineCount(for: nextText)"))
    }

    @Test("CoreEditor WebView navigation allows only local bootstrap and chunk resources")
    func markEditCoreEditorWebViewNavigationAllowsOnlyLocalBootstrapAndChunks() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")

        #expect(source.contains("private static func isAllowedNavigation(_ navigationAction: WKNavigationAction) -> Bool"))
        #expect(source.contains("case MarkEditCoreEditorBridge.chunkScheme:"))
        #expect(source.contains(#"return url.host == "chunks""#))
        #expect(source.contains(#"return host == "localhost" || host == "127.0.0.1" || host == "::1""#))
        #expect(!source.contains("if navigationAction.navigationType == .other {\n            decisionHandler(.allow)"))
    }

    @Test("CoreEditor teardown invalidates callbacks before stopping the WKWebView")
    func markEditCoreEditorTeardownRemovesHandlersBeforeStoppingLoad() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
        let detach = try Self.extractFunction(
            signature: "func detach(from webView: WKWebView)",
            from: source
        )

        #expect(detach.contains("loadGeneration += 1"))
        #expect(Self.offset(of: "loadGeneration += 1", in: detach) < Self.offset(of: "webView.stopLoading()", in: detach))
        #expect(Self.offset(of: "removeScriptMessageHandler", in: detach) < Self.offset(of: "webView.stopLoading()", in: detach))
        #expect(!detach.contains("loadGeneration += 1\n        loadGeneration += 1"))
    }

    @Test("CoreEditor chunk loader rejects traversal and non-chunk hosts")
    func markEditCoreEditorChunkLoaderRejectsTraversalAndNonChunkHosts() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorRuntimeResources.swift")

        #expect(source.contains(#"host == "chunks""#))
        #expect(source.contains("isSafeRelativePathComponent"))
        #expect(source.contains(#"component != "..""#))
        #expect(source.contains("resolvingSymlinksInPath()"))
        #expect(source.contains("isRegularFile"))
        #expect(source.contains("mimeTypes[fileURL.pathExtension.lowercased()]"))
        #expect(source.contains("Bundle.main.url(forResource: relativePath, withExtension: nil)"))
        #expect(source.contains("Bundle.main.url(forResource: filename, withExtension: nil)"))
        #expect(source.contains("isDescendant(candidate, of: root)"))
        #expect(source.contains(#"Bundle.main.url(forResource: "index", withExtension: "html")"#))
        #expect(source.contains(#""Access-Control-Allow-Credentials": "true""#))
    }

    @Test("Runtime asset bundler preserves CoreEditor chunks inside the app bundle")
    func runtimeAssetBundlerPreservesCoreEditorChunks() throws {
        let source = try loadMirroredSourceTextFile("bundle-app-runtime-assets.sh")

        #expect(source.contains("CORE_EDITOR_SOURCE_DIR=\"$SRCROOT/Epistemos/Resources/CoreEditor\""))
        #expect(source.contains("CORE_EDITOR_BUNDLE_DIR=\"$RESOURCES_DIR/CoreEditor\""))
        #expect(source.contains("CORE_EDITOR_CHUNKS_SOURCE_DIR=\"$SRCROOT/Epistemos/Resources/chunks\""))
        #expect(source.contains("CORE_EDITOR_CHUNKS_BUNDLE_DIR=\"$RESOURCES_DIR/chunks\""))
        #expect(source.contains("rsync -a --delete \"$CORE_EDITOR_SOURCE_DIR/\" \"$CORE_EDITOR_BUNDLE_DIR/\""))
        #expect(source.contains("rsync -a --delete \"$CORE_EDITOR_CHUNKS_SOURCE_DIR/\" \"$CORE_EDITOR_CHUNKS_BUNDLE_DIR/\""))
        #expect(source.contains("bundle_coreeditor_resources"))
    }

    private static func extractBlock(named name: String, from source: String) throws -> String {
        guard let nameRange = source.range(of: "private var \(name): some View") else {
            throw MarkEditChromeModeSplitTestError.missingBlock(name)
        }
        guard let openBrace = source[nameRange.upperBound...].firstIndex(of: "{") else {
            throw MarkEditChromeModeSplitTestError.missingBlock(name)
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

        throw MarkEditChromeModeSplitTestError.missingBlock(name)
    }

    private static func extractFunction(signature: String, from source: String) throws -> String {
        guard let nameRange = source.range(of: signature) else {
            throw MarkEditChromeModeSplitTestError.missingFunction(signature)
        }
        guard let openBrace = source[nameRange.upperBound...].firstIndex(of: "{") else {
            throw MarkEditChromeModeSplitTestError.missingFunction(signature)
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

        throw MarkEditChromeModeSplitTestError.missingFunction(signature)
    }

    private static func offset(of needle: String, in haystack: String) -> Int {
        guard let range = haystack.range(of: needle) else { return Int.max }
        return haystack.distance(from: haystack.startIndex, to: range.lowerBound)
    }
}

private enum MarkEditChromeModeSplitTestError: Error, CustomStringConvertible {
    case missingBlock(String)
    case missingFunction(String)

    var description: String {
        switch self {
        case .missingBlock(let name):
            return "Missing CodeEditorView block: \(name)"
        case .missingFunction(let name):
            return "Missing MarkEdit CoreEditor function: \(name)"
        }
    }
}
