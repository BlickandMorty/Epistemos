import Foundation
import Testing

@Suite("MarkEdit L3-CHROME mode split guards (Plan 2)")
nonisolated struct MarkEditChromeModeSplitTests {
    @Test("Note workspace exposes Prose, Document, Preview, and Source as explicit markdown modes")
    func noteWorkspaceExposesExplicitMarkdownModes() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let modePicker = try Self.extractFunction(
            signature: "private func noteModePicker(for page: SDPage) -> some View",
            from: source
        )

        #expect(source.contains(#""Edit/Prose""#))
        #expect(source.contains(#""Document""#))
        #expect(source.contains(#""Preview""#))
        #expect(source.contains(#""Source""#))
        #expect(source.contains("modes: sourceRoute == nil ? [.edit, .document, .preview] : [.edit, .document, .preview, .source]"))
        #expect(modePicker.contains("ForEach(modes, id: \\.self)"))
        #expect(modePicker.contains("surfaceModeToolbarButton("))
        #expect(!modePicker.contains("Picker("))
        #expect(!modePicker.contains(".pickerStyle(.segmented)"))
        #expect(!modePicker.contains(".frame(width: modes.count"))
        #expect(source.contains(#".accessibilityLabel(mode.label)"#))
        #expect(source.contains(#""Switch between Prose, Document, Preview, and Source""#))
        #expect(modePicker.contains("setNoteMode(mode, for: page, options: options)"))
    }

    @Test("Note workspace reuses mode routing instead of recomputing Source paths during toolbar render")
    func noteWorkspaceReusesModeRoutingForToolbarAndSourceMount() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(source.contains("private struct NoteModeOptions"))
        #expect(source.contains("private func noteModeOptions(for page: SDPage) -> NoteModeOptions"))
        #expect(source.contains("let options = noteModeOptions(for: page)"))
        #expect(source.contains("private func sourceEditorRoute(for page: SDPage) -> SourceEditorRoute? {\n        let options = noteModeOptions(for: page)"))
        #expect(!source.contains("return sourceFileRoute(for: page) == nil\n                ? [.edit, .preview]\n                : [.edit, .preview, .source]"))
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
        #expect(codeChrome.contains("HStack(spacing: 0)"))
        #expect(codeChrome.contains("editorWithSearch"))
        #expect(codeChrome.contains("outlineNavigator"))
        #expect(codeChrome.contains("if CodeEditorReleasePolicy.semanticSidebarEnabled"))
        #expect(codeChrome.contains("semanticSidebar"))
        #expect(codeChrome.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
        #expect(codeChrome.contains(".padding(.bottom, 12)\n        }\n        .frame(maxWidth: .infinity, maxHeight: .infinity)"))

        #expect(source.contains("showLivePreview.toggle()"))
        #expect(livePreview.contains("HTMLWorkspacePreviewView("))
        #expect(livePreview.contains("livePreviewPackage"))
        #expect(iconSource.contains("struct CodeFileIdentityChip: View"))
        #expect(iconSource.contains("static func identity(forFilePath filePath: String?, language: String) -> CodeFileIdentity"))
        #expect(!iconSource.contains("NSWorkspace.shared.icon(forFile: filePath)"))
        #expect(!iconSource.contains("UTType(filenameExtension: pathExtension)"))
        #expect(!iconSource.contains("NSWorkspace.shared.icon(for: contentType)"))
        #expect(iconSource.contains(#"case "swift":"#))
        #expect(iconSource.contains(#"symbolName: "swift""#))
        #expect(iconSource.contains(#"case "rust":"#))
        #expect(iconSource.contains(#"displayName: "Rust""#))
    }

    @Test("CodeEditorView top controls show file-kind icon without duplicating the file title")
    func codeEditorTopControlsShowFileKindIconWithoutDuplicatingTheFileTitle() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let topBar = try Self.extractBlock(named: "codeEditorTopBar", from: source)

        #expect(topBar.contains(#"Text("Ln \(cursorLine), Col \(cursorCol)")"#))
        #expect(topBar.contains("CodeFileIdentityChip(filePath: filePath, language: language, theme: codeEditorTheme)"))
        #expect(topBar.contains("showLivePreview.toggle()"))
        #expect(topBar.contains("showSearchBar.toggle()"))
        #expect(!topBar.contains("Text(codeEditorDisplayName)"))
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
        let source = try Self.markEditCoreEditorAdapterSource()
        let state = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorState.swift")
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
        #expect(!source.contains("private struct MarkEditCoreEditorConfig"))
        #expect(state.contains("struct MarkEditCoreEditorState"))
        #expect(state.contains("private struct MarkEditCoreEditorConfig"))
    }

    @Test("CoreEditor adapter waits for the JS bridge before the first reset")
    func markEditCoreEditorAdapterWaitsForBridgeBeforeInitialReset() throws {
        let source = try Self.markEditCoreEditorAdapterSource()

        #expect(source.contains("waitForCoreEditorReady"))
        #expect(source.contains("window.webModules?.core?.resetEditor"))
        #expect(source.contains("finishLoadingEditor(in: webView)"))
        #expect(source.contains("resetEditor(to: state, in: webView, documentChanged: true)"))
        #expect(!source.contains("lastAppliedState = initialState"))
    }

    @Test("CoreEditor embed registers MarkEdit native bridge and fails visibly when reset is blank")
    func markEditCoreEditorRegistersNativeBridgeAndBlankResetDiagnostics() throws {
        let source = try Self.markEditCoreEditorAdapterSource()

        #expect(source.contains(#"static let nativeMessageHandlerName = "bridge""#))
        #expect(source.contains(#"static let baseURL = URL(string: "http://localhost/")"#))
        #expect(source.contains("webView.loadHTMLString(html, baseURL: MarkEditCoreEditorBridge.baseURL)"))
        #expect(source.contains("WKScriptMessageHandlerWithReply"))
        #expect(source.contains("addScriptMessageHandler("))
        #expect(source.contains("removeScriptMessageHandler(\n            forName: MarkEditCoreEditorBridge.nativeMessageHandlerName,\n            contentWorld: .page"))
        #expect(source.contains("callAsyncJavaScript(script, in: nil, in: .page)"))
        #expect(!source.contains("(async () => {"))
        #expect(source.contains("beginCoreEditorReadyCheckAfterNativeLoadNotification()"))
        #expect(source.contains(#"methodName == "notifyWindowDidLoad""#))
        #expect(source.contains("documentChanged: true"))
        #expect(!source.contains("MarkEdit CoreEditor bootstrap reset failed"))
        #expect(!source.contains(#"const text = typeof config.text === "string" ? config.text : "";"#))
        #expect(source.contains("private static func nativeBridgeReply(moduleName: String?, methodName: String?) -> Any?"))
        #expect(source.contains(#"case ("api", "getPasteboardItems"):"#))
        #expect(source.contains(#"case ("foundationModels", "availability"):"#))
        #expect(source.contains("setTimeout(finish, 100)"))
        #expect(source.contains("CoreEditor reset completed with empty editor text"))
        #expect(source.contains("resetFailureMessage(result: scriptResult, error: scriptError)"))
    }

    @Test("Embedded Source preview widgets render through an Epistemos bridge instead of no-op native preview")
    func embeddedSourcePreviewWidgetsRenderThroughEpistemosBridge() throws {
        let coordinator = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift")
        let previewModule = try Self.loadRepoTextFile("LocalPackages/MarkEdit/CoreEditor/src/modules/preview/index.ts")
        let previewCSS = try Self.loadRepoTextFile("LocalPackages/MarkEdit/CoreEditor/src/modules/preview/index.css")

        #expect(coordinator.contains(#"case ("preview", "show"):"#),
                "The embedded CoreEditor bridge must explicitly handle MarkEdit's preview.show call.")
        #expect(coordinator.contains(#"{"handledBy":"epistemos-embedded-source"}"#),
                "The preview bridge reply should prove the click was handled instead of silently no-oping.")
        #expect(previewModule.contains("showEmbeddedPreview("),
                "Markdown Source preview widgets should have an embedded fallback when native preview is unavailable.")
        #expect(previewModule.contains("renderTablePreview("),
                "Source-mode table preview should render a readable table instead of only showing pipe text.")
        #expect(previewModule.contains("renderFallbackPreview("),
                "Math/diagram preview clicks should still surface visible content when their native renderer is absent.")
        #expect(previewModule.contains("className = 'cm-md-embeddedPreview'"))
        #expect(previewCSS.contains(".cm-md-embeddedPreview table"))
        #expect(previewCSS.contains(".cm-md-embeddedPreviewClose"))
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
        let source = try Self.markEditCoreEditorAdapterSource()

        #expect(source.contains("private static func isAllowedNavigation(_ navigationAction: WKNavigationAction) -> Bool"))
        #expect(source.contains("case MarkEditCoreEditorBridge.chunkScheme:"))
        #expect(source.contains(#"return url.host == "chunks""#))
        #expect(source.contains(#"return host == "localhost" || host == "127.0.0.1" || host == "::1""#))
        #expect(!source.contains("if navigationAction.navigationType == .other {\n            decisionHandler(.allow)"))
    }

    @Test("CoreEditor teardown invalidates callbacks before stopping the WKWebView")
    func markEditCoreEditorTeardownRemovesHandlersBeforeStoppingLoad() throws {
        let source = try Self.markEditCoreEditorAdapterSource()
        let detach = try Self.extractFunction(
            signature: "func detach(from webView: WKWebView)",
            from: source
        )

        #expect(source.contains("private var isDetached = false"))
        #expect(source.contains("private var pendingSelectionRequest: CoreEditorSelectionRequest?"))
        #expect(detach.contains("loadGeneration += 1"))
        #expect(detach.contains("isDetached = true"))
        #expect(Self.offset(of: "isDetached = true", in: detach) < Self.offset(of: "webView.stopLoading()", in: detach))
        #expect(Self.offset(of: "loadGeneration += 1", in: detach) < Self.offset(of: "webView.stopLoading()", in: detach))
        #expect(Self.offset(of: "removeScriptMessageHandler", in: detach) < Self.offset(of: "webView.stopLoading()", in: detach))
        #expect(!detach.contains("loadGeneration += 1\n        loadGeneration += 1"))
        #expect(source.contains("guard !isDetached else { return }"))
        #expect(source.contains("if hasLoadedEditor, !webView.isLoading"))
        #expect(source.contains("guard !isDetached, hasLoadedEditor, !webView.isLoading else"))
        #expect(source.contains("!self.isDetached else { return }"))
        #expect(source.contains("pendingSelectionRequest = selectionRequest"))
        #expect(source.contains("self.lastSelectionRequestID = selectionRequest.id"))
        #expect(detach.contains("webView.navigationDelegate = nil"))
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
        #expect(source.contains("subdirectory: MarkEditCoreEditorBridge.resourceSubpath"))
        #expect(!source.contains(#"Bundle.main.url(forResource: "index", withExtension: "html")"#))
        #expect(source.contains(#""Access-Control-Allow-Credentials": "true""#))
    }

    @Test("Runtime asset bundler preserves CoreEditor chunks inside the app bundle")
    func runtimeAssetBundlerPreservesCoreEditorChunks() throws {
        let source = try loadMirroredSourceTextFile("bundle-app-runtime-assets.sh")

        #expect(source.contains("CORE_EDITOR_SOURCE_DIR=\"$SRCROOT/Epistemos/Resources/CoreEditor\""))
        #expect(source.contains("CORE_EDITOR_BUNDLE_DIR=\"$RESOURCES_DIR/CoreEditor\""))
        #expect(source.contains("CORE_EDITOR_CHUNKS_SOURCE_DIR=\"$SRCROOT/Epistemos/Resources/CoreEditor/chunks\""))
        #expect(source.contains("CORE_EDITOR_CHUNKS_BUNDLE_DIR=\"$RESOURCES_DIR/chunks\""))
        #expect(source.contains("rsync -a --delete \"$CORE_EDITOR_SOURCE_DIR/\" \"$CORE_EDITOR_BUNDLE_DIR/\""))
        #expect(source.contains("rsync -a --delete \"$CORE_EDITOR_CHUNKS_SOURCE_DIR/\" \"$CORE_EDITOR_CHUNKS_BUNDLE_DIR/\""))
        #expect(source.contains("bundle_coreeditor_resources"))
    }

    private static func markEditCoreEditorAdapterSource() throws -> String {
        try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
            + "\n"
            + loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift")
    }

    private static func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
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
