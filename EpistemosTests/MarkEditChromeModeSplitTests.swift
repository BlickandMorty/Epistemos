import Foundation
import Testing

@Suite("MarkEdit L3-CHROME mode split guards (Plan 2)")
nonisolated struct MarkEditChromeModeSplitTests {
    @Test("CodeEditorView selects markdown versus code chrome with one isMarkdownDocument seam")
    func codeEditorViewSelectsMarkdownVersusCodeChromeWithOneSeam() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let editorContent = try Self.extractBlock(named: "editorContent", from: source)
        let codeSurface = try Self.extractBlock(named: "codeEditorSurface", from: source)
        let livePreview = try Self.extractBlock(named: "codeLivePreview", from: source)

        #expect(source.contains("private var isMarkdownDocument"))
        #expect(editorContent.contains("if isMarkdownDocument"))
        #expect(editorContent.contains("MarkEditMarkdownEditorRepresentable("))
        #expect(editorContent.contains("codeEditorChromeContent"))

        #expect(codeSurface.contains("MarkEditCodeEditorRepresentable("))
        #expect(!codeSurface.contains("WebKitCodeEditorView("))
        #expect(!codeSurface.contains("SourceEditor("))

        #expect(source.contains("showLivePreview.toggle()"))
        #expect(livePreview.contains("HTMLWorkspacePreviewView("))
        #expect(livePreview.contains("livePreviewPackage"))
    }

    @Test("MarkEdit CoreEditor adapter uses vendored bundle and generated MarkEdit bridge surface")
    func markEditCoreEditorAdapterUsesVendoredBundleAndBridgeSurface() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")

        #expect(source.contains("struct MarkEditCodeEditorRepresentable"))
        #expect(source.contains("struct MarkEditMarkdownEditorRepresentable"))
        #expect(source.contains("MarkEditVerbatimMarkdownChromeRepresentable"))
        #expect(source.contains("makeNSViewController(context: Context) -> EditorViewController"))
        #expect(source.contains("#if canImport(MarkEditKit)"))
        #expect(source.contains("MarkEditCoreEditorBridge"))
        #expect(source.contains("MarkEditCoreEditorChunkLoader"))
        #expect(source.contains("{{EDITOR_CONFIG}}"))
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

    @Test("CoreEditor chunk loader rejects traversal and non-chunk hosts")
    func markEditCoreEditorChunkLoaderRejectsTraversalAndNonChunkHosts() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")

        #expect(source.contains(#"host == "chunks""#))
        #expect(source.contains("isSafeRelativePathComponent"))
        #expect(source.contains(#"component != "..""#))
        #expect(source.contains("mimeTypes[fileURL.pathExtension.lowercased()]"))
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
}

private enum MarkEditChromeModeSplitTestError: Error, CustomStringConvertible {
    case missingBlock(String)

    var description: String {
        switch self {
        case .missingBlock(let name):
            return "Missing CodeEditorView block: \(name)"
        }
    }
}
