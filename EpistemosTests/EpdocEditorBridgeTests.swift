import Foundation
import Testing

@testable import Epistemos

/// Wave 7.2 base source-guard for the Tiptap WKWebView bridge surface
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.2,
///  cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §4).
///
/// Tests cover:
///   - The custom URL scheme constant (must match the JS bridge)
///   - JS → Swift message decoding (every shape per the bridge protocol)
///   - Swift → JS command emission (canonical JS expressions)
///   - Save pipeline debounce semantics (matches the 300ms research finding)
///
/// The actual WKWebView integration + Tiptap JS bundle live in a
/// follow-up. The bridge code is exercised in isolation here.
@Suite("Epdoc editor bridge (Wave 7.2 base)")
nonisolated struct EpdocEditorBridgeTests {

    // MARK: - URL scheme

    @Test("custom URL scheme is the canonical epistemos-doc")
    func canonicalScheme() {
        #expect(epdocEditorURLScheme == "epistemos-doc",
                "the custom scheme MUST be epistemos-doc — the JS bundle hard-codes the same string in its loader; drift breaks asset fetches")
    }

    @Test("asset resolver prefers Brotli transfer assets without changing MIME type")
    func assetResolverPrefersBrotliTransferAssets() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epdoc-editor-assets-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let scriptURL = root.appendingPathComponent("editor.js")
        let brotliURL = root.appendingPathComponent("editor.js.br")
        try Data("console.log('plain')".utf8).write(to: scriptURL)
        try Data([0x1b, 0x00, 0x00, 0x00]).write(to: brotliURL)

        let resolved = try EpdocEditorAssetResolver.resolve(
            relativePath: "/editor.js",
            assetRoot: root
        )

        #expect(resolved.fileURL == brotliURL)
        #expect(resolved.mimeType == "text/javascript")
        #expect(resolved.contentEncoding == "br")
    }

    @Test("asset resolver can serve Brotli-only production transfer assets")
    func assetResolverServesBrotliOnlyProductionAssets() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epdoc-editor-assets-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let brotliURL = root.appendingPathComponent("editor.js.br")
        try Data([0x1b, 0x00, 0x00, 0x00]).write(to: brotliURL)

        let resolved = try EpdocEditorAssetResolver.resolve(
            relativePath: "/editor.js",
            assetRoot: root
        )

        #expect(resolved.fileURL == brotliURL)
        #expect(resolved.mimeType == "text/javascript")
        #expect(resolved.contentEncoding == "br")
    }

    @Test("asset resolver rejects traversal and uses precise font MIME types")
    func assetResolverRejectsTraversalAndMapsFonts() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epdoc-editor-assets-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fontURL = root
            .appendingPathComponent("vendor", isDirectory: true)
            .appendingPathComponent("katex", isDirectory: true)
            .appendingPathComponent("fonts", isDirectory: true)
        try FileManager.default.createDirectory(at: fontURL, withIntermediateDirectories: true)
        let woffURL = fontURL.appendingPathComponent("KaTeX_Main-Regular.woff")
        try Data([0x00, 0x01]).write(to: woffURL)

        let resolved = try EpdocEditorAssetResolver.resolve(
            relativePath: "/vendor/katex/fonts/KaTeX_Main-Regular.woff",
            assetRoot: root
        )

        #expect(resolved.fileURL == woffURL)
        #expect(resolved.mimeType == "font/woff")
        #expect(resolved.contentEncoding == nil)
        #expect(throws: EpdocBridgeError.self) {
            try EpdocEditorAssetResolver.resolve(relativePath: "/../editor.js", assetRoot: root)
        }
    }

    @Test("bundled font fallback covers OTF and TTF display fonts")
    func bundledFontFallbackCoversDisplayFontLibrary() {
        let fontNames = Set(EpdocEditorAssetResolver.bundledFontAssets.map(\.filename))

        #expect(EpdocEditorAssetResolver.mimeType(for: "otf") == "font/otf")
        #expect(fontNames.contains("MatrixTypeDisplay-Bold.otf"))
        #expect(fontNames.contains("ReturnOfGanonReg.ttf"))
        #expect(fontNames.contains("VTFMisterPixel.otf"))
        #expect(fontNames.contains("AtlantisHeadline-Bold.otf"))
        #expect(fontNames.contains("DisposableDroidBB-BoldItalic.ttf"))
        #expect(fontNames.contains("CodersCrux.ttf"))
    }

    @Test("document asset resolver accepts only flat package asset paths")
    func documentAssetResolverAcceptsOnlyFlatPackageAssetPaths() {
        #expect(EpdocEditorAssetResolver.documentAssetName(relativePath: "/assets/image-abc.png") == "image-abc.png")
        #expect(EpdocEditorAssetResolver.documentAssetName(relativePath: "assets/image-abc.png") == "image-abc.png")
        #expect(EpdocEditorAssetResolver.documentAssetName(relativePath: "/assets/") == nil)
        #expect(EpdocEditorAssetResolver.documentAssetName(relativePath: "/assets/../secret.png") == nil)
        #expect(EpdocEditorAssetResolver.documentAssetName(relativePath: "/assets/nested/image.png") == nil)
        #expect(EpdocEditorAssetResolver.documentAssetName(relativePath: "/editor.js") == nil)
    }

    // MARK: - JS → Swift messages

    @Test("contentDidChange decodes from canonical body shape")
    func contentDidChangeDecodes() {
        let body: [String: Any] = [
            "type": "contentDidChange",
            "json": #"{"type":"doc","content":[]}"#,
        ]
        guard case let .contentDidChange(data)? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .contentDidChange")
            return
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        #expect(text.contains("\"type\":\"doc\""))
    }

    @Test("markdownDidChange decodes from canonical body shape")
    func markdownDidChangeDecodes() {
        let body: [String: Any] = [
            "type": "markdownDidChange",
            "markdown": "# Claim\n\nBody",
        ]
        guard case let .markdownDidChange(markdown)? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .markdownDidChange")
            return
        }
        #expect(markdown == "# Claim\n\nBody")
    }

    @Test("editorReady decodes from canonical body shape")
    func editorReadyDecodes() {
        let body: [String: Any] = ["type": "editorReady"]
        guard case .editorReady? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .editorReady")
            return
        }
    }

    @Test("documentStatsChanged decodes live word and character counts")
    func documentStatsChangedDecodes() {
        let body: [String: Any] = [
            "type": "documentStatsChanged",
            "wordCount": 12,
            "characterCount": 96,
        ]
        guard case let .documentStatsChanged(wordCount, characterCount)? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .documentStatsChanged")
            return
        }
        #expect(wordCount == 12)
        #expect(characterCount == 96)
    }

    @Test("storeImageAsset decodes pasted or dropped image bytes")
    func storeImageAssetDecodes() {
        let image = Data([0x89, 0x50, 0x4e, 0x47])
        let body: [String: Any] = [
            "type": "storeImageAsset",
            "requestID": "img-1",
            "filename": "sample.png",
            "mimeType": "image/png",
            "base64": image.base64EncodedString(),
        ]
        guard case let .storeImageAsset(requestID, filename, mimeType, data)? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .storeImageAsset")
            return
        }
        #expect(requestID == "img-1")
        #expect(filename == "sample.png")
        #expect(mimeType == "image/png")
        #expect(data == image)
    }

    @MainActor
    @Test("chrome controller pushes initial document JSON when the editor becomes ready")
    func chromeControllerPushesInitialDocumentJSONOnReady() {
        let controller = EpdocEditorChromeController()
        let json = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        var commands: [EpdocEditorCommand] = []

        controller.loadInitialContent(json, title: "Loaded Doc")
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)
        controller.handleBridgeMessage(.editorReady)

        #expect(controller.documentTitle == "Loaded Doc")
        #expect(commands == [.setContent(json: json), .focusStart],
                "editorReady must push the package's canonical content exactly once, then focus the editor.")
    }

    @MainActor
    @Test("chrome controller waits for dispatch installation before pushing initial content")
    func chromeControllerWaitsForDispatchBeforeInitialContentPush() {
        let controller = EpdocEditorChromeController()
        let json = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        var commands: [EpdocEditorCommand] = []

        controller.loadInitialContent(json, title: "Late Dispatch")
        controller.handleBridgeMessage(.editorReady)
        #expect(commands.isEmpty)

        controller.installEditorDispatch { command in
            commands.append(command)
        }

        #expect(commands == [.setContent(json: json), .focusStart],
                "If WKWebView emits editorReady before SwiftUI updateNSView installs dispatch, initial content must still flush after dispatch is installed.")
    }

    @MainActor
    @Test("chrome controller pushes Markdown when markdown-canonical source is loaded")
    func chromeControllerPushesMarkdownCanonicalInitialContent() {
        let controller = EpdocEditorChromeController()
        let json = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = "# Canonical\n\n[[Note]]\n"
        var commands: [EpdocEditorCommand] = []

        controller.loadInitialContent(json, title: "Loaded MD", markdownSource: markdown)
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)
        controller.handleBridgeMessage(.editorReady)

        #expect(controller.latestMarkdownSnapshot == markdown)
        #expect(commands == [.setMarkdown(markdown: markdown), .focusStart],
                "markdownCanonical loads must initialize TipTap through setMarkdown, not stale package JSON.")
    }

    @MainActor
    @Test("chrome controller restores canonical note width without echoing persistence")
    func chromeControllerRestoresMarkdownCanonicalWidth() {
        let controller = EpdocEditorChromeController()
        let json = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = "# Canonical\n\n[[Note]]\n"
        let width = NoteWidthMode.custom(px: 1_040)
        var commands: [EpdocEditorCommand] = []
        var persistedWidthChanges: [NoteWidthMode] = []

        controller.onContentWidthChanged = { persistedWidthChanges.append($0) }
        controller.loadInitialContent(
            json,
            title: "Loaded MD",
            markdownSource: markdown,
            widthMode: width
        )
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)

        #expect(controller.toolbarModel.widthMode == width)
        #expect(controller.canonicalWidthMode == width)
        #expect(commands == [
            .setMarkdown(markdown: markdown),
            .setContentWidth(mode: width),
            .focusStart,
        ])
        #expect(persistedWidthChanges.isEmpty)
    }

    @MainActor
    @Test("chrome controller reports user note-width changes to the host")
    func chromeControllerReportsUserWidthChanges() {
        let controller = EpdocEditorChromeController()
        var commands: [EpdocEditorCommand] = []
        var persistedWidthChanges: [NoteWidthMode] = []

        controller.onContentWidthChanged = { persistedWidthChanges.append($0) }
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.dispatch(.setContentWidth(mode: .wide))

        #expect(controller.toolbarModel.widthMode == .wide)
        #expect(controller.canonicalWidthMode == .wide)
        #expect(commands == [.setContentWidth(mode: .wide)])
        #expect(persistedWidthChanges == [.wide])
    }

    @MainActor
    @Test("chrome controller turns the frontmatter command into durable metadata intent")
    func chromeControllerReportsFrontmatterMetadataIntent() {
        let controller = EpdocEditorChromeController()
        var commands: [EpdocEditorCommand] = []
        var frontmatterRequests = 0

        controller.onEnsureFrontmatterMetadata = {
            frontmatterRequests += 1
        }
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.dispatch(.runCommand(name: "insertEpdocFrontmatter", argsJSON: Data("[]".utf8)))

        #expect(frontmatterRequests == 1)
        #expect(commands == [.runCommand(name: "insertEpdocFrontmatter", argsJSON: Data("[]".utf8))])
    }

    @MainActor
    @Test("chrome controller computes status counters from loaded document JSON before JS emits updates")
    func chromeControllerComputesInitialStatusFromLoadedJSON() {
        let controller = EpdocEditorChromeController()
        let json = """
        {
          "type": "doc",
          "content": [
            {"type": "paragraph", "content": [{"type": "text", "text": "Alpha links to Beta"}]},
            {"type": "mermaid", "content": [{"type": "text", "text": "graph TD\\nA --> B"}]},
            {"type": "epdocImage", "attrs": {"src": "data:image/png;base64,abc", "alt": "", "title": ""}}
          ]
        }
        """.data(using: .utf8)!

        controller.loadInitialContent(json, title: "Loaded")

        #expect(controller.toolbarModel.wordCount > 0)
        #expect(controller.toolbarModel.characterCount > 0)
        #expect(controller.complexityBreakdown?.mermaidCount == 1)
        #expect(controller.complexityBreakdown?.embedCount == 1)
        #expect(controller.complexity > 0)
    }

    @MainActor
    @Test("chrome controller applies active marks from caretChanged payload")
    func chromeControllerAppliesActiveMarksFromCaretChanged() {
        let controller = EpdocEditorChromeController()
        controller.handleBridgeMessage(.caretChanged(
            rect: EpdocBridgeRect(x: 10, y: 20, width: 2, height: 18),
            selection: EpdocBridgeSelection(from: 4, to: 9, isEmpty: false),
            marks: EpdocBridgeActiveMarks(
                isBoldActive: true,
                isItalicActive: true,
                isStrikeActive: false,
                isCodeActive: false,
                isHighlightActive: true,
                activeHeadingLevel: 3
            )
        ))

        #expect(controller.toolbarModel.isBoldActive)
        #expect(controller.toolbarModel.isItalicActive)
        #expect(!controller.toolbarModel.isStrikeActive)
        #expect(!controller.toolbarModel.isCodeActive)
        #expect(controller.toolbarModel.isHighlightActive)
        #expect(controller.toolbarModel.activeHeadingLevel == 3)
    }

    @MainActor
    @Test("chrome controller retains full-fidelity markdown snapshots from the JS bridge")
    func chromeControllerRetainsMarkdownSnapshots() {
        let controller = EpdocEditorChromeController()
        var observed: [String] = []
        controller.onMarkdownChanged = { observed.append($0) }

        controller.handleBridgeMessage(.markdownDidChange(markdown: "# Canonical\n\n[[Note]]\n"))

        #expect(controller.latestMarkdownSnapshot == "# Canonical\n\n[[Note]]\n")
        #expect(observed == ["# Canonical\n\n[[Note]]\n"])
    }

    @MainActor
    @Test("loading a new initial JSON clears stale markdown snapshots")
    func chromeControllerClearsMarkdownSnapshotOnLoad() {
        let controller = EpdocEditorChromeController()
        controller.handleBridgeMessage(.markdownDidChange(markdown: "# Previous\n"))
        #expect(controller.latestMarkdownSnapshot == "# Previous\n")

        let json = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        controller.loadInitialContent(json, title: "Next")

        #expect(controller.latestMarkdownSnapshot == nil)
    }

    @MainActor
    @Test("chrome controller stores JS image asset requests and completes the pending insert")
    func chromeControllerCompletesImageAssetRequests() {
        let controller = EpdocEditorChromeController()
        var stored: (filename: String, mimeType: String, data: Data)?
        var commands: [EpdocEditorCommand] = []

        controller.onStoreDocumentAsset = { filename, mimeType, data in
            stored = (filename, mimeType, data)
            return "assets/image-hash.png"
        }
        controller.installEditorDispatch { command in
            commands.append(command)
        }

        let image = Data([1, 2, 3])
        controller.handleBridgeMessage(.storeImageAsset(
            requestID: "request-1",
            filename: "drop.png",
            mimeType: "image/png",
            data: image
        ))

        #expect(stored?.filename == "drop.png")
        #expect(stored?.mimeType == "image/png")
        #expect(stored?.data == image)
        guard case let .runCommand(name, argsJSON)? = commands.last else {
            #expect(Bool(false), "must dispatch a JS completion command")
            return
        }
        #expect(name == "completeImageAssetRequest")
        let rawArgs = try? JSONSerialization.jsonObject(with: argsJSON) as? [[String: String]]
        #expect(rawArgs?.first?["requestID"] == "request-1")
        #expect(rawArgs?.first?["src"] == "assets/image-hash.png")
    }

    @Test("error decodes from canonical body shape")
    func errorDecodes() {
        let body: [String: Any] = [
            "type": "error",
            "message": "boom",
        ]
        guard case let .error(msg)? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .error")
            return
        }
        #expect(msg == "boom")
    }

    @Test("malformed body returns nil")
    func malformedBodyReturnsNil() {
        // Non-dictionary body
        #expect(EpdocBridgeMessage.decode(messageBody: "garbage") == nil)
        // Missing type key
        #expect(EpdocBridgeMessage.decode(messageBody: ["json": "x"]) == nil)
        // Unknown type
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "unknown_kind"]) == nil)
        // contentDidChange missing required json
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "contentDidChange"]) == nil)
        // documentStatsChanged missing required counts
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "documentStatsChanged",
                                                       "wordCount": 1]) == nil)
        // error missing required message
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "error"]) == nil)
    }

    // MARK: - W7.17 inbound decode (caretChanged / requestSlashMenu / requestBubbleMenu)

    @Test("caretChanged decodes the rect + selection payload")
    func caretChangedDecodes() {
        let body: [String: Any] = [
            "type": "caretChanged",
            "rect": ["x": 12.5, "y": 34.0, "w": 1.0, "h": 18.0],
            "selection": ["from": 5, "to": 5, "empty": true],
            "marks": [
                "bold": true,
                "italic": false,
                "strike": true,
                "code": false,
                "highlight": true,
                "heading": 2,
            ],
        ]
        guard case let .caretChanged(rect, selection, marks) = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "expected .caretChanged")
            return
        }
        #expect(rect.x == 12.5)
        #expect(rect.y == 34.0)
        #expect(rect.width == 1.0)
        #expect(rect.height == 18.0)
        #expect(selection.from == 5)
        #expect(selection.to == 5)
        #expect(selection.isEmpty == true)
        #expect(marks.isBoldActive == true)
        #expect(marks.isItalicActive == false)
        #expect(marks.isStrikeActive == true)
        #expect(marks.isCodeActive == false)
        #expect(marks.isHighlightActive == true)
        #expect(marks.activeHeadingLevel == 2)
    }

    @Test("caretChanged remains compatible with cached bundles that omit marks")
    func caretChangedWithoutMarksDefaultsInactive() {
        let body: [String: Any] = [
            "type": "caretChanged",
            "rect": ["x": 12.5, "y": 34.0, "w": 1.0, "h": 18.0],
            "selection": ["from": 5, "to": 5, "empty": true],
        ]
        guard case let .caretChanged(_, _, marks) = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "expected .caretChanged")
            return
        }
        #expect(marks == .inactive)
    }

    @Test("requestSlashMenu decodes query + anchor")
    func requestSlashMenuDecodes() {
        let body: [String: Any] = [
            "type": "requestSlashMenu",
            "query": "head",
            "anchor": ["x": 100, "y": 200, "w": 1, "h": 18],
        ]
        guard case let .requestSlashMenu(query, anchor) = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "expected .requestSlashMenu")
            return
        }
        #expect(query == "head")
        #expect(anchor.x == 100)
        #expect(anchor.y == 200)
    }

    @Test("requestBubbleMenu decodes selection + anchor")
    func requestBubbleMenuDecodes() {
        let body: [String: Any] = [
            "type": "requestBubbleMenu",
            "selection": ["from": 10, "to": 25, "empty": false],
            "anchor": ["x": 50, "y": 60, "w": 200, "h": 18],
        ]
        guard case let .requestBubbleMenu(selection, anchor) = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "expected .requestBubbleMenu")
            return
        }
        #expect(selection.from == 10)
        #expect(selection.to == 25)
        #expect(selection.isEmpty == false)
        #expect(anchor.width == 200)
    }

    @Test("malformed W7.17 payloads return nil (defensive decoder)")
    func w717MalformedReturnsNil() {
        // caretChanged missing rect
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "caretChanged",
                                                       "selection": ["from": 0, "to": 0, "empty": true]]) == nil)
        // caretChanged with malformed provided marks
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "caretChanged",
                                                       "rect": ["x": 0, "y": 0, "w": 0, "h": 0],
                                                       "selection": ["from": 0, "to": 0, "empty": true],
                                                       "marks": ["bold": "true"]]) == nil)
        // caretChanged with incomplete provided marks
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "caretChanged",
                                                       "rect": ["x": 0, "y": 0, "w": 0, "h": 0],
                                                       "selection": ["from": 0, "to": 0, "empty": true],
                                                       "marks": ["bold": true]]) == nil)
        // caretChanged with non-integral heading
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "caretChanged",
                                                       "rect": ["x": 0, "y": 0, "w": 0, "h": 0],
                                                       "selection": ["from": 0, "to": 0, "empty": true],
                                                       "marks": [
                                                           "bold": false,
                                                           "italic": false,
                                                           "strike": false,
                                                           "code": false,
                                                           "highlight": false,
                                                           "heading": 2.5,
                                                       ]]) == nil)
        // caretChanged with bool heading
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "caretChanged",
                                                       "rect": ["x": 0, "y": 0, "w": 0, "h": 0],
                                                       "selection": ["from": 0, "to": 0, "empty": true],
                                                       "marks": [
                                                           "bold": false,
                                                           "italic": false,
                                                           "strike": false,
                                                           "code": false,
                                                           "highlight": false,
                                                           "heading": true,
                                                       ]]) == nil)
        // requestSlashMenu missing query
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "requestSlashMenu",
                                                       "anchor": ["x": 0, "y": 0, "w": 0, "h": 0]]) == nil)
        // requestBubbleMenu with non-bool empty
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "requestBubbleMenu",
                                                       "selection": ["from": 0, "to": 0, "empty": "true"],
                                                       "anchor": ["x": 0, "y": 0, "w": 0, "h": 0]]) == nil)
    }

    // MARK: - Swift → JS commands (W7.17 namespaced surface)

    @Test("setContent routes through window.epistemos.setContent with stringified JSON")
    func setContentRoutesThroughEpistemosNamespace() {
        let json = #"{"type":"doc","content":[]}"#.data(using: .utf8)!
        let cmd = EpdocEditorCommand.setContent(json: json)
        let expr = cmd.javaScriptExpression()
        #expect(expr == #"window.epistemos.setContent("{\"type\":\"doc\",\"content\":[]}")"#,
                "setContent must call window.epistemos.setContent(jsonString); got: \(expr)")
    }

    @Test("setMarkdown routes through window.epistemos.setMarkdown")
    func setMarkdownRoutesThroughEpistemosNamespace() {
        let cmd = EpdocEditorCommand.setMarkdown(markdown: "# Claim\n\nBody")
        #expect(cmd.javaScriptExpression() == "window.epistemos.setMarkdown(\"# Claim\\n\\nBody\")")
    }

    @Test("focusStart + focusEnd route through window.epistemos.focus*")
    func focusCommands() {
        #expect(EpdocEditorCommand.focusStart.javaScriptExpression() == "window.epistemos.focusStart()")
        #expect(EpdocEditorCommand.focusEnd.javaScriptExpression() == "window.epistemos.focusEnd()")
    }

    @Test("dismissSlashMenu + dismissBubbleMenu emit the canonical no-arg calls")
    func dismissCommands() {
        #expect(EpdocEditorCommand.dismissSlashMenu.javaScriptExpression() == "window.epistemos.dismissSlashMenu()")
        #expect(EpdocEditorCommand.dismissBubbleMenu.javaScriptExpression() == "window.epistemos.dismissBubbleMenu()")
    }

    @Test("insertSlashChoice emits the canonical block-type call (string-literal escaped)")
    func insertSlashChoiceCommand() {
        let cmd = EpdocEditorCommand.insertSlashChoice(blockType: "heading-1")
        #expect(cmd.javaScriptExpression() == #"window.epistemos.insertSlashChoice("heading-1")"#)
    }

    @Test("runCommand spreads the JSON args array")
    func runCommandSpreadArgs() {
        let argsJSON = "[{\"level\":2}]".data(using: .utf8)!
        let cmd = EpdocEditorCommand.runCommand(name: "toggleHeading", argsJSON: argsJSON)
        #expect(cmd.javaScriptExpression() == #"window.epistemos.runCommand("toggleHeading", ...[{"level":2}])"#)
    }

    @Test("AI diff commands use the settled preview bridge contract")
    func aiDiffCommandsUseSettledPreviewContract() throws {
        let request = try #require(EpdocAIDiffStageRequest(
            markdown: "Body",
            claimId: "claim-1",
            batchId: "batch-1"
        ))
        #expect(request.settled)
        #expect(EpdocAIDiffStageRequest(markdown: " ", claimId: "claim-1", batchId: "batch-1") == nil)
        #expect(EpdocAIDiffStageRequest(markdown: "Body", claimId: "", batchId: "batch-1") == nil)

        #expect(EpdocEditorCommand.stageAIDiff(request: request).javaScriptExpression()
                == #"window.epistemos.runCommand("stageEpdocAIDiff", ...[{"markdown":"Body","claimId":"claim-1","batchId":"batch-1","settled":true}])"#)
        #expect(EpdocEditorCommand.acceptAIDiff.javaScriptExpression()
                == #"window.epistemos.runCommand("acceptEpdocAIDiff", ...[])"#)
        #expect(EpdocEditorCommand.rejectAIDiff.javaScriptExpression()
                == #"window.epistemos.runCommand("rejectEpdocAIDiff", ...[])"#)
        #expect(EpdocEditorCommand.clearAIDiff.javaScriptExpression()
                == #"window.epistemos.runCommand("clearEpdocAIDiff", ...[])"#)
    }

    @Test("setContentWidth routes through the namespaced inbound bridge")
    func setContentWidthCommand() {
        #expect(EpdocEditorCommand.setContentWidth(mode: .normal).javaScriptExpression() == #"window.epistemos.setContentWidth("720px")"#)
        #expect(EpdocEditorCommand.setContentWidth(mode: .wide).javaScriptExpression() == #"window.epistemos.setContentWidth("none")"#)
        #expect(EpdocEditorCommand.setContentWidth(mode: .custom(px: 980)).javaScriptExpression() == #"window.epistemos.setContentWidth("980px")"#)
    }

    @Test("Find and Replace commands route through the namespaced inbound bridge")
    func findReplaceCommands() {
        #expect(EpdocEditorCommand.setFindQuery(query: "alpha", caseSensitive: false).javaScriptExpression() == #"window.epistemos.setFindQuery("alpha", false)"#)
        #expect(EpdocEditorCommand.findNext(query: "alpha", caseSensitive: true).javaScriptExpression() == #"window.epistemos.findNext("alpha", true)"#)
        #expect(EpdocEditorCommand.findPrevious(query: "alpha", caseSensitive: false).javaScriptExpression() == #"window.epistemos.findPrevious("alpha", false)"#)
        #expect(EpdocEditorCommand.replaceCurrent(query: "alpha", replacement: "beta", caseSensitive: true).javaScriptExpression() == #"window.epistemos.replaceCurrent("alpha", "beta", true)"#)
        #expect(EpdocEditorCommand.replaceAll(query: "alpha", replacement: "beta", caseSensitive: false).javaScriptExpression() == #"window.epistemos.replaceAll("alpha", "beta", false)"#)
        #expect(EpdocEditorCommand.clearFindHighlights.javaScriptExpression() == "window.epistemos.clearFindHighlights()")
    }

    @Test("jsStringLiteral escapes the dangerous JS literal characters")
    func jsStringLiteralEscapes() {
        #expect(jsStringLiteral("plain") == "\"plain\"")
        #expect(jsStringLiteral(#"with "quote""#) == #""with \"quote\"""#)
        #expect(jsStringLiteral("with\nnewline") == "\"with\\nnewline\"")
        #expect(jsStringLiteral("with\\backslash") == "\"with\\\\backslash\"")
        // U+2028 / U+2029 are JS string-terminators inside literals — escape them
        #expect(jsStringLiteral("a\u{2028}b") == "\"a\\u2028b\"")
    }

    @Test("Tiptap update path defers heavy JSON and stats work")
    func tiptapUpdatePathDefersHeavyWork() throws {
        let source = try loadMirroredSourceTextFile("js-editor/src/index.ts")

        guard let updateStart = source.range(of: "onUpdate: ({ editor: ed }) => {"),
              let createStart = source.range(of: "  onCreate:", range: updateStart.upperBound..<source.endIndex) else {
            #expect(Bool(false), "must find the Tiptap onUpdate block in js-editor/src/index.ts")
            return
        }

        let updateBlock = String(source[updateStart.lowerBound..<createStart.lowerBound])
        #expect(source.contains("const DOCUMENT_STATS_DEBOUNCE_MS"),
                "document stats must have their own debounce so large docs do not recount words at typing cadence.")
        #expect(source.contains("let pendingContentEditor: Editor | null"),
                "content save debounce must hold the editor and serialize once at flush time, not once per update.")
        #expect(updateBlock.contains("scheduleContentDidChange(ed)"))
        #expect(updateBlock.contains("scheduleDocumentStats(ed)"))
        #expect(!updateBlock.contains("JSON.stringify"),
                "full-document JSON serialization must not run in the live update callback.")
        #expect(!updateBlock.contains("postDocumentStats(ed)"),
                "CharacterCount word/character scans must not run in the live update callback.")
    }

    @Test("heavy epdoc blocks are paint-contained for scroll fluidity")
    func heavyEpdocBlocksArePaintContained() throws {
        let css = try loadMirroredSourceTextFile("js-editor/src/editor.css")

        #expect(css.contains(".ProseMirror pre,"))
        #expect(css.contains(".epdoc-legacy-diagram,"))
        #expect(css.contains(".epdoc-chart,"))
        #expect(css.contains(".ProseMirror img[data-epdoc-image]"))
        #expect(css.contains("contain: layout paint style;"),
                "heavy rendered blocks need paint containment so large code, legacy diagram source, chart, and image nodes do not invalidate the whole document surface.")
    }

    @Test(".epdoc H1-H3 typography tracks the native prose editor display scale")
    func epdocHeadingsTrackNativeProseDisplayScale() throws {
        let css = try loadMirroredSourceTextFile("js-editor/src/editor.css")
        let editorSource = try loadMirroredSourceTextFile("js-editor/src/index.ts")
        let webpack = try loadMirroredSourceTextFile("js-editor/webpack.config.js")
        let bridge = try loadMirroredSourceTextFile("Epistemos/Engine/EpdocEditorBridge.swift")

        #expect(css.contains(#"@font-face"#))
        #expect(css.contains(#"font-family: "Coral Pixels";"#))
        #expect(css.contains(#"src: url("/CoralPixels-Regular.ttf") format("truetype");"#))
        #expect(css.contains(#"font-family: "Retro Gaming";"#))
        #expect(css.contains(#"src: url("/RetroGaming.ttf") format("truetype");"#))
        #expect(css.contains(#"font-family: "MatrixTypeDisplay-Bold";"#))
        #expect(css.contains(#"src: url("/MatrixTypeDisplay-Bold.otf") format("opentype");"#))
        #expect(css.contains(#"font-family: "MatrixDotsDemoRegular";"#))
        #expect(css.contains(#"src: url("/MatrixDotsDemoRegular.ttf") format("truetype");"#))
        #expect(css.contains(#"font-family: "ReturnOfGanonReg";"#))
        #expect(css.contains(#"src: url("/VTFMisterPixel.otf") format("opentype");"#))
        #expect(css.contains(#"font-family: "Coder's-Crux";"#))
        #expect(!css.contains("basis33"))
        #expect(webpack.contains(#"url === '/CoralPixels-Regular.ttf'"#))
        #expect(webpack.contains(#"url === '/RetroGaming.ttf'"#))
        #expect(webpack.contains(#"url === '/MatrixTypeDisplay-Bold.otf'"#))
        #expect(webpack.contains(#"url === '/MatrixDotsDemoRegular.ttf'"#))
        #expect(webpack.contains(#"url === '/ReturnOfGanonReg.ttf'"#))
        #expect(webpack.contains(#"url === '/VTFMisterPixel.otf'"#))
        #expect(webpack.contains(#"url === '/CodersCrux.ttf'"#))
        #expect(!webpack.contains("basis33"),
                "The WKWebView editor should route the theme display pair without restoring Basis33.")
        #expect(bridge.contains("AppDisplayTypography.displayFontOptions.map"))
        #expect(bridge.contains("EpdocEditorAssetResolver.bundledFontAsset(relativePath: url.path)"))
        #expect(!bridge.contains("basis33"))
        #expect(css.contains("--epdoc-h1-size: 52px;"),
                "Prose H1 should stay large but no longer dominate the whole viewport.")
        #expect(css.contains("--epdoc-h2-size: 27px;"),
                "Prose H2 is display typography but should sit clearly below H1.")
        #expect(css.contains("--epdoc-h3-size: 17px;"),
                "Prose H3 stays in the display face while H4/H5 remain regular body typography.")
        #expect(css.contains(#"[data-epdoc-heading-size="medium"]"#))
        #expect(editorSource.contains("syncAdaptiveHeadingSizes"))
        #expect(editorSource.contains("data-epdoc-heading-size"))
        #expect(css.contains(#"--epdoc-display-font: "MatrixTypeDisplay""#))
        #expect(css.contains(#"--epdoc-h2-font: "ChonkyPixels""#))
        #expect(css.contains(#"--epdoc-h3-font: "ChonkyPixels""#))
        #expect(css.contains("--epdoc-h1-font: var(--epdoc-display-font);"))
        #expect(!css.contains(".ProseMirror h1,\n.ProseMirror h2,\n.ProseMirror h3 {"))
        #expect(!css.contains(".ProseMirror h4,\n.ProseMirror h5 {\n  font-family: var(--epdoc-display-font);"))
        #expect(css.contains("font-family: var(--epdoc-h1-font);"))
        #expect(css.contains("font-family: var(--epdoc-h2-font);"))
        #expect(css.contains("font-family: var(--epdoc-h3-font);"))
    }
}
