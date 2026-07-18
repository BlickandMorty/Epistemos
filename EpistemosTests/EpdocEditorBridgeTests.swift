import Foundation
import Testing
@preconcurrency import WebKit

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
        guard case let .markdownDidChange(markdown, writeback)? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .markdownDidChange")
            return
        }
        #expect(markdown == "# Claim\n\nBody")
        #expect(writeback == nil)
    }

    @Test("markdownDidChange decodes minimal writeback metadata")
    func markdownDidChangeDecodesMinimalWritebackMetadata() {
        let body: [String: Any] = [
            "type": "markdownDidChange",
            "markdown": "Alpha\n\nBravo updated\n\nCharlie\n",
            "writeback": [
                "byteFrom": 7,
                "byteTo": 12,
                "codeUnitFrom": 7,
                "codeUnitTo": 12,
                "changedFrom": 2,
                "changedTo": 3,
                "blockIndexFrom": 1,
                "blockIndexTo": 2,
                "blockMarkdown": "Bravo updated",
            ],
        ]
        guard case let .markdownDidChange(markdown, writeback)? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .markdownDidChange with writeback")
            return
        }
        #expect(markdown == "Alpha\n\nBravo updated\n\nCharlie\n")
        #expect(writeback == EpdocMarkdownWritebackRegion(
            byteFrom: 7,
            byteTo: 12,
            codeUnitFrom: 7,
            codeUnitTo: 12,
            changedFrom: 2,
            changedTo: 3,
            blockIndexFrom: 1,
            blockIndexTo: 2,
            blockMarkdown: "Bravo updated"
        ))
    }

    @Test("bridge decoder accepts WKScriptMessage NSNumber integers without treating them as booleans")
    func bridgeDecoderAcceptsWebKitNSNumberIntegers() {
        let body: [String: Any] = [
            "type": "markdownDidChange",
            "epoch": NSNumber(value: 1),
            "markdown": "Alpha\n\nBravo updated\n",
            "writeback": [
                "byteFrom": NSNumber(value: 7),
                "byteTo": NSNumber(value: 12),
                "codeUnitFrom": NSNumber(value: 7),
                "codeUnitTo": NSNumber(value: 12),
                "changedFrom": NSNumber(value: 2),
                "changedTo": NSNumber(value: 3),
                "blockIndexFrom": NSNumber(value: 1),
                "blockIndexTo": NSNumber(value: 1),
                "blockMarkdown": "Bravo updated",
            ],
        ]
        guard case let .markdownDidChange(markdown, writeback)? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode NSNumber-backed markdownDidChange values from WKScriptMessage")
            return
        }

        #expect(markdown == "Alpha\n\nBravo updated\n")
        #expect(writeback?.byteFrom == 7)
        #expect(writeback?.blockMarkdown == "Bravo updated")
        #expect(EpdocBridgeMessage.decodeEpoch(messageBody: body) == 1)
        #expect(EpdocBridgeMessage.decode(messageBody: [
            "type": "documentStatsChanged",
            "wordCount": NSNumber(value: true),
            "characterCount": NSNumber(value: 10),
        ]) == nil)
    }

    @Test("batched bridge envelope decodes messages with epochs")
    func batchedBridgeEnvelopeDecodesMessagesWithEpochs() {
        let body: [String: Any] = [
            "type": "batch",
            "messages": [
                [
                    "type": "contentDidChange",
                    "epoch": 9,
                    "json": #"{"type":"doc","content":[{"type":"paragraph"}]}"#,
                ],
                [
                    "type": "markdownDidChange",
                    "epoch": 9,
                    "markdown": "Alpha\n\nBravo updated\n",
                    "writeback": [
                        "byteFrom": 7,
                        "byteTo": 12,
                        "codeUnitFrom": 7,
                        "codeUnitTo": 12,
                        "changedFrom": 2,
                        "changedTo": 3,
                        "blockIndexFrom": 1,
                        "blockIndexTo": 1,
                        "blockMarkdown": "Bravo updated",
                    ],
                ],
                [
                    "type": "suggestionResolved",
                    "epoch": 9,
                    "suggestionId": "span-batch",
                    "state": "accepted",
                ],
            ],
        ]

        let decoded = EpdocBridgeMessage.decodeEnvelope(messageBody: body)

        #expect(decoded.count == 3)
        #expect(decoded.map(\.epoch) == [9, 9, 9])
        guard case .contentDidChange? = decoded.first?.message else {
            #expect(Bool(false), "first batch entry should decode as contentDidChange")
            return
        }
        guard case let .markdownDidChange(markdown, writeback)? = decoded.dropFirst().first?.message else {
            #expect(Bool(false), "second batch entry should decode as markdownDidChange")
            return
        }
        #expect(markdown == "Alpha\n\nBravo updated\n")
        #expect(writeback?.blockMarkdown == "Bravo updated")
        guard case let .suggestionResolved(resolution)? = decoded.last?.message else {
            #expect(Bool(false), "third batch entry should decode as suggestionResolved")
            return
        }
        #expect(resolution.suggestionID == "span-batch")
        #expect(resolution.state == .accepted)
    }

    @MainActor
    @Test("bundled WKWebView outbound bridge delivers writeback and provenance payloads")
    func bundledWKWebViewOutboundBridgeDeliversWritebackAndProvenancePayloads() async throws {
        let probe = EpdocWebKitBridgeProbe()
        let runtime = Self.makeBundledEditorWebView(probe: probe)
        let webView = runtime.webView
        let userContentController = runtime.userContentController
        defer {
            webView.stopLoading()
            webView.navigationDelegate = nil
            userContentController.removeScriptMessageHandler(forName: "epdoc")
        }

        let editorURL = try #require(URL(string: "\(epdocEditorURLScheme):///editor.html"))
        webView.load(URLRequest(url: editorURL))
        try await probe.waitForNavigation()
        try await Self.waitForBundledOutboundBridge(in: webView)

        try await Self.evaluateScript(
            """
            (() => {
              window.epdocOutboundBridge.post({
                type: 'markdownDidChange',
                epoch: 1,
                markdown: 'Alpha\\n\\nBravo updated\\n',
                writeback: {
                  from: 7,
                  to: 12,
                  byteFrom: 7,
                  byteTo: 12,
                  codeUnitFrom: 7,
                  codeUnitTo: 12,
                  changedFrom: 2,
                  changedTo: 3,
                  blockIndexFrom: 1,
                  blockIndexTo: 1,
                  blockMarkdown: 'Bravo updated'
                }
              });
              window.epdocOutboundBridge.post({
                type: 'suggestionApplied',
                epoch: 1,
                id: 'wk-span-1',
                author: 'lumen',
                turnId: 'turn-wk',
                kind: 'replacement',
                from: 7,
                to: 12,
                mapVersion: 3,
                before: 'Bravo',
                after: 'Bravo updated',
                rationale: 'runtime bridge smoke',
                sourceCitation: 'claim://wk',
                claimId: 'claim:wk'
              });
              window.epdocOutboundBridge.post({
                type: 'suggestionResolved',
                epoch: 1,
                suggestionId: 'wk-span-1',
                state: 'accepted'
              });
              window.epdocOutboundBridge.flushSync();
              return 'posted';
            })()
            """,
            in: webView
        )

        let decoded = try await probe.waitForDecodedMessages(
            containingSuggestionID: "wk-span-1",
            markdown: "Alpha\n\nBravo updated\n",
            writebackBlockMarkdown: "Bravo updated"
        )
        let injectedEntries = decoded.filter { entry in
            switch entry.message {
            case let .markdownDidChange(markdown, writeback):
                return markdown == "Alpha\n\nBravo updated\n"
                    && writeback?.blockMarkdown == "Bravo updated"
            case let .suggestionApplied(payload):
                return payload.id == "wk-span-1"
            case let .suggestionResolved(resolution):
                return resolution.suggestionID == "wk-span-1"
            default:
                return false
            }
        }
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        var markdownEvents: [(String, EpdocMarkdownWritebackRegion?)] = []
        var appliedPayloads: [EpdocSuggestionSpanPayload] = []
        var resolutions: [EpdocSuggestionResolution] = []

        controller.loadInitialContent(emptyJSON, title: "WK smoke")
        controller.onMarkdownChanged = { markdown, writeback in
            markdownEvents.append((markdown, writeback))
        }
        controller.onSuggestionApplied = { payload in
            appliedPayloads.append(payload)
        }
        controller.onSuggestionResolved = { resolution in
            resolutions.append(resolution)
        }

        for entry in injectedEntries {
            controller.handleBridgeMessage(entry.message, epoch: entry.epoch)
        }

        let didReceiveInjectedWriteback = markdownEvents.contains { event in
            event.0 == "Alpha\n\nBravo updated\n"
                && event.1?.blockMarkdown == "Bravo updated"
        }
        #expect(didReceiveInjectedWriteback)
        #expect(appliedPayloads.map(\.id) == ["wk-span-1"])
        #expect(appliedPayloads.first?.claimID == "claim:wk")
        #expect(appliedPayloads.first?.sourceCitation == "claim://wk")
        #expect(resolutions == [
            EpdocSuggestionResolution(suggestionID: "wk-span-1", state: .accepted),
        ])
    }

    @MainActor
    @Test("bundled WKWebView inbound suggestion commands drive adapter provenance")
    func bundledWKWebViewInboundSuggestionCommandsDriveAdapterProvenance() async throws {
        let probe = EpdocWebKitBridgeProbe()
        let runtime = Self.makeBundledEditorWebView(probe: probe)
        let webView = runtime.webView
        let userContentController = runtime.userContentController
        defer {
            webView.stopLoading()
            webView.navigationDelegate = nil
            userContentController.removeScriptMessageHandler(forName: "epdoc")
        }

        let editorURL = try #require(URL(string: "\(epdocEditorURLScheme):///editor.html"))
        webView.load(URLRequest(url: editorURL))
        try await probe.waitForNavigation()
        try await Self.waitForBundledOutboundBridge(in: webView)
        try await Self.waitForBundledInboundCommands(in: webView)

        let baseline = "Alpha Bravo Charlie"
        let baselineJSON = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Alpha Bravo Charlie"}]}]}"#
            .data(using: .utf8)!
        try await Self.evaluateScript(
            """
            (() => {
              \(EpdocEditorCommand.setContentForLoad(json: baselineJSON, epoch: 21).javaScriptExpression());
              window.epdocOutboundBridge.flushSync();
            })()
            """,
            in: webView
        )
        let loadedText = try await Self.waitForEditorText(baseline, in: webView)
        #expect(loadedText == baseline)

        let payload = EpdocSuggestionSpanPayload(
            id: "wk-command-span",
            author: "june",
            turnID: "turn-wk-command",
            kind: "replacement",
            from: 7,
            to: 12,
            mapVersion: 1,
            before: "Bravo",
            after: "Bravo updated",
            rationale: "runtime inbound command proof",
            sourceCitation: "claim://inbound",
            claimID: "claim:inbound"
        )
        try await Self.evaluateScript(
            """
            (() => {
              const didRun = \(EpdocEditorCommand.applySuggestion(payload: payload).javaScriptExpression());
              window.epdocOutboundBridge.flushSync();
              if (didRun !== true) throw new Error('applySuggestion returned ' + didRun);
            })()
            """,
            in: webView
        )
        let stagedMarkSummary = try await Self.evaluateString(
            """
            (() => {
              const editor = window.epdocEditor;
              if (!editor) return '';
              const marks = [];
              editor.state.doc.descendants((node, pos) => {
                if (!node.isText) return true;
                for (const mark of node.marks) {
                  if (['deletion', 'insertion', 'modification'].includes(mark.type.name)) {
                    marks.push(`${mark.type.name}:${String(mark.attrs.id)}:${node.text ?? ''}`);
                  }
                }
                return true;
              });
              return JSON.stringify({
                text: editor.state.doc.textBetween(0, editor.state.doc.content.size, ' ', ' '),
                marks,
              });
            })()
            """,
            in: webView
        )
        #expect(stagedMarkSummary.contains("deletion:wk-command-span:Bravo"))
        #expect(stagedMarkSummary.contains("insertion:wk-command-span:Bravo updated"))

        let acceptResult = try await Self.evaluateString(
            """
            (() => {
              const didRun = \(EpdocEditorCommand.acceptSuggestion(id: payload.id).javaScriptExpression());
              window.epdocOutboundBridge.flushSync();
              return String(didRun);
            })()
            """,
            in: webView
        )
        guard acceptResult == "true" else {
            #expect(Bool(false), "acceptSuggestion returned \(acceptResult); staged marks: \(stagedMarkSummary)")
            return
        }

        let decoded = try await probe.waitForSuggestionFlow(
            containingSuggestionID: payload.id,
            resolvedState: .accepted
        )
        let applied = try #require(decoded.compactMap { entry -> EpdocSuggestionSpanPayload? in
            if case let .suggestionApplied(payload) = entry.message {
                return payload
            }
            return nil
        }.last)
        let resolution = try #require(decoded.compactMap { entry -> EpdocSuggestionResolution? in
            if case let .suggestionResolved(resolution) = entry.message {
                return resolution
            }
            return nil
        }.last)
        let acceptedText = try await Self.waitForEditorText("Alpha Bravo updated Charlie", in: webView)

        #expect(applied.id == "wk-command-span")
        #expect(applied.author == "june")
        #expect(applied.turnID == "turn-wk-command")
        #expect(applied.kind == "replacement")
        #expect(applied.before == "Bravo")
        #expect(applied.after == "Bravo updated")
        #expect(applied.sourceCitation == "claim://inbound")
        #expect(applied.claimID == "claim:inbound")
        #expect(resolution == EpdocSuggestionResolution(
            suggestionID: "wk-command-span",
            state: .accepted
        ))
        #expect(acceptedText == "Alpha Bravo updated Charlie")

        let undoTrace = try await Self.evaluateString(
            """
            (() => {
              const editor = window.epdocEditor;
              const summarize = (label, didRun = null) => {
                const marks = [];
                editor.state.doc.descendants((node) => {
                  if (!node.isText) return true;
                  for (const mark of node.marks) {
                    if (['deletion', 'insertion', 'modification'].includes(mark.type.name)) {
                      marks.push(`${mark.type.name}:${String(mark.attrs.id)}:${node.text ?? ''}`);
                    }
                  }
                  return true;
                });
                return {
                  label,
                  didRun,
                  text: editor.state.doc.textBetween(0, editor.state.doc.content.size, ' ', ' '),
                  marks,
                };
              };
              const trace = [summarize('accepted')];
              for (let index = 1; index <= 5; index += 1) {
                const didRun = \(EpdocEditorCommand.runCommand(name: "undo", argsJSON: Data("[]".utf8)).javaScriptExpression());
                window.epdocOutboundBridge.flushSync();
                trace.push(summarize(`undo-${index}`, didRun));
              }
              return JSON.stringify(trace);
            })()
            """,
            in: webView
        )
        #expect(undoTrace.contains(#""text":"Alpha Bravo Charlie""#), "undo trace: \(undoTrace)")
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
            "epoch": 3,
            "wordCount": 12,
            "characterCount": 96,
        ]
        guard case let .documentStatsChanged(wordCount, characterCount)? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .documentStatsChanged")
            return
        }
        #expect(wordCount == 12)
        #expect(characterCount == 96)
        #expect(EpdocBridgeMessage.decodeEpoch(messageBody: body) == 3)
    }

    @Test("loadSettled decodes and carries the optional load epoch")
    func loadSettledDecodes() {
        let body: [String: Any] = [
            "type": "loadSettled",
            "epoch": 4,
        ]
        guard case .loadSettled? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .loadSettled")
            return
        }
        #expect(EpdocBridgeMessage.decodeEpoch(messageBody: body) == 4)
    }

    @Test("suggestionResolved decodes accepted and rejected decisions")
    func suggestionResolvedDecodes() {
        let body: [String: Any] = [
            "type": "suggestionResolved",
            "epoch": 5,
            "suggestionId": "agent-42",
            "state": "accepted",
        ]
        guard case let .suggestionResolved(resolution)? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .suggestionResolved")
            return
        }
        #expect(resolution.suggestionID == "agent-42")
        #expect(resolution.state == .accepted)
        #expect(EpdocBridgeMessage.decodeEpoch(messageBody: body) == 5)
        #expect(EpdocBridgeMessage.decode(messageBody: [
            "type": "suggestionResolved",
            "suggestionId": "agent-42",
            "state": "pending",
        ]) == nil)
    }

    @Test("suggestionApplied decodes the original tracked span payload")
    func suggestionAppliedDecodes() {
        let body: [String: Any] = [
            "type": "suggestionApplied",
            "epoch": 6,
            "id": "agent-42",
            "author": "lumen",
            "turnId": "turn-9",
            "kind": "replacement",
            "from": 10,
            "to": 14,
            "mapVersion": 2,
            "before": "old",
            "after": "new",
            "rationale": "tighten wording",
            "sourceCitation": "claim://abc",
            "claimId": "claim:abc",
        ]
        guard case let .suggestionApplied(payload)? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .suggestionApplied")
            return
        }
        #expect(payload.id == "agent-42")
        #expect(payload.author == "lumen")
        #expect(payload.turnID == "turn-9")
        #expect(payload.kind == "replacement")
        #expect(payload.from == 10)
        #expect(payload.to == 14)
        #expect(payload.mapVersion == 2)
        #expect(payload.before == "old")
        #expect(payload.after == "new")
        #expect(payload.rationale == "tighten wording")
        #expect(payload.sourceCitation == "claim://abc")
        #expect(payload.claimID == "claim:abc")
        #expect(EpdocBridgeMessage.decodeEpoch(messageBody: body) == 6)
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
        #expect(commands == [.setContentForLoad(json: json, epoch: 1), .focusStart],
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

        #expect(commands == [.setContentForLoad(json: json, epoch: 1), .focusStart],
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
        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 1), .focusStart],
                "markdownCanonical loads must initialize TipTap through setMarkdown, not stale package JSON.")
    }

    @MainActor
    @Test("chrome controller forwards suggestion resolution decisions")
    func chromeControllerForwardsSuggestionResolutionDecisions() {
        let controller = EpdocEditorChromeController()
        var resolutions: [EpdocSuggestionResolution] = []

        controller.onSuggestionResolved = { resolution in
            resolutions.append(resolution)
        }

        controller.handleBridgeMessage(
            .suggestionResolved(EpdocSuggestionResolution(suggestionID: "agent-7", state: .rejected)),
            epoch: 0
        )

        #expect(resolutions == [
            EpdocSuggestionResolution(suggestionID: "agent-7", state: .rejected),
        ])
    }

    @MainActor
    @Test("chrome controller forwards applied suggestion spans")
    func chromeControllerForwardsAppliedSuggestionSpans() {
        let controller = EpdocEditorChromeController()
        var payloads: [EpdocSuggestionSpanPayload] = []
        let payload = EpdocSuggestionSpanPayload(
            id: "agent-8",
            author: "lumen",
            turnID: "turn-8",
            kind: "insertion",
            from: 3,
            to: 3,
            mapVersion: 1,
            before: "",
            after: "inserted",
            claimID: "claim:8"
        )

        controller.onSuggestionApplied = { payload in
            payloads.append(payload)
        }

        controller.handleBridgeMessage(.suggestionApplied(payload), epoch: 0)

        #expect(payloads == [payload])
    }

    @MainActor
    @Test("chrome controller ignores stale epoch suggestion events")
    func chromeControllerIgnoresStaleEpochSuggestionEvents() {
        let controller = EpdocEditorChromeController()
        let json = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let stalePayload = EpdocSuggestionSpanPayload(
            id: "stale-agent-edit",
            author: "lumen",
            turnID: "turn-stale",
            kind: "replacement",
            from: 1,
            to: 3,
            mapVersion: 1,
            before: "old",
            after: "new",
            claimID: "claim:stale"
        )
        let freshPayload = EpdocSuggestionSpanPayload(
            id: "fresh-agent-edit",
            author: "lumen",
            turnID: "turn-fresh",
            kind: "insertion",
            from: 4,
            to: 4,
            mapVersion: 2,
            before: "",
            after: "fresh",
            claimID: "claim:fresh"
        )
        var payloads: [EpdocSuggestionSpanPayload] = []
        var resolutions: [EpdocSuggestionResolution] = []

        controller.onSuggestionApplied = { payloads.append($0) }
        controller.onSuggestionResolved = { resolutions.append($0) }
        controller.loadInitialContent(json, title: "Epoch 1")
        #expect(controller.currentLoadEpoch == 1)

        controller.handleBridgeMessage(.suggestionApplied(stalePayload), epoch: 0)
        controller.handleBridgeMessage(
            .suggestionResolved(EpdocSuggestionResolution(suggestionID: "stale-agent-edit", state: .accepted)),
            epoch: 0
        )
        controller.handleBridgeMessage(.suggestionApplied(freshPayload), epoch: 1)
        controller.handleBridgeMessage(
            .suggestionResolved(EpdocSuggestionResolution(suggestionID: "fresh-agent-edit", state: .accepted)),
            epoch: 1
        )

        #expect(payloads == [freshPayload])
        #expect(resolutions == [
            EpdocSuggestionResolution(suggestionID: "fresh-agent-edit", state: .accepted),
        ])
    }

    @MainActor
    @Test("chrome controller suppresses dirty save echoes from initial Markdown load")
    func chromeControllerSuppressesInitialMarkdownBridgeEchoes() {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let renderedJSON = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Loaded"}]}]}"#
            .data(using: .utf8)!
        let editedJSON = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Edited"}]}]}"#
            .data(using: .utf8)!
        let markdown = "# Loaded\n"
        var changedJSON: [Data] = []
        var changedMarkdown: [String] = []

        controller.onContentChanged = { changedJSON.append($0) }
        controller.onMarkdownChanged = { markdown, _ in changedMarkdown.append(markdown) }
        controller.toolbarModel.isDirty = true

        controller.loadInitialContent(emptyJSON, title: "Loaded MD", markdownSource: markdown)
        controller.installEditorDispatch { _ in }
        controller.handleBridgeMessage(.editorReady)
        controller.handleBridgeMessage(.contentDidChange(json: renderedJSON), epoch: 1)
        controller.handleBridgeMessage(.markdownDidChange(markdown: markdown, writeback: nil), epoch: 1)

        #expect(!controller.toolbarModel.isDirty)
        #expect(changedJSON.isEmpty)
        #expect(changedMarkdown.isEmpty)

        controller.handleBridgeMessage(.contentDidChange(json: editedJSON), epoch: 1)
        controller.handleBridgeMessage(.markdownDidChange(markdown: "# Edited\n", writeback: nil), epoch: 1)

        #expect(controller.toolbarModel.isDirty)
        #expect(changedJSON == [editedJSON])
        #expect(changedMarkdown == ["# Edited\n"])

        let raceController = EpdocEditorChromeController()
        var racedMarkdown: [String] = []
        raceController.onMarkdownChanged = { markdown, _ in racedMarkdown.append(markdown) }
        raceController.loadInitialContent(emptyJSON, title: "Loaded MD", markdownSource: markdown)
        raceController.installEditorDispatch { _ in }
        raceController.handleBridgeMessage(.editorReady)
        raceController.handleBridgeMessage(.markdownDidChange(markdown: "# User edit\n", writeback: nil), epoch: 1)
        #expect(racedMarkdown == ["# User edit\n"])
    }

    @MainActor
    @Test("chrome controller re-pushes non-empty Markdown source when initial bridge echo is empty")
    func chromeControllerRepushesNonEmptyMarkdownSourceAfterEmptyInitialEcho() {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = """
        ---
        title: Loaded table
        ---

        | A | B |
        | - | - |
        | 1 | 2 |
        """
        var commands: [EpdocEditorCommand] = []
        var changedMarkdown: [String] = []

        controller.onMarkdownChanged = { markdown, _ in
            changedMarkdown.append(markdown)
        }
        controller.loadInitialContent(emptyJSON, title: "Loaded table", markdownSource: markdown)
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)

        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 1), .focusStart])
        commands.removeAll()

        controller.handleBridgeMessage(.markdownDidChange(markdown: "", writeback: nil), epoch: 1)
        #expect(changedMarkdown.isEmpty)
        #expect(controller.latestMarkdownSnapshot == markdown)
        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 1)])

        commands.removeAll()
        controller.handleBridgeMessage(.markdownDidChange(markdown: "   \n", writeback: nil), epoch: 1)
        #expect(changedMarkdown.isEmpty)
        #expect(controller.latestMarkdownSnapshot == markdown)
        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 1)])

        commands.removeAll()
        controller.handleBridgeMessage(.markdownDidChange(markdown: "", writeback: nil), epoch: 1)
        #expect(changedMarkdown.isEmpty)
        #expect(controller.latestMarkdownSnapshot == markdown)
        #expect(commands.isEmpty)

        controller.handleBridgeMessage(.markdownDidChange(markdown: "# User edit\n", writeback: nil), epoch: 1)
        #expect(changedMarkdown == ["# User edit\n"])
        #expect(controller.latestMarkdownSnapshot == "# User edit\n")
    }

    @MainActor
    @Test("chrome controller re-pushes non-empty Markdown source after clean post-load blank snapshot")
    func chromeControllerRepushesNonEmptyMarkdownSourceAfterCleanPostLoadBlankSnapshot() {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = """
        # Post-load Blank Proof

        | A | B |
        | - | - |
        | 1 | 2 |
        """
        var commands: [EpdocEditorCommand] = []
        var changedMarkdown: [String] = []

        controller.onMarkdownChanged = { markdown, _ in
            changedMarkdown.append(markdown)
        }
        controller.loadInitialContent(emptyJSON, title: "Post-load Blank Proof", markdownSource: markdown)
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)
        controller.handleBridgeMessage(.markdownDidChange(markdown: markdown, writeback: nil), epoch: 1)
        controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()

        controller.handleBridgeMessage(.markdownDidChange(markdown: "", writeback: nil), epoch: 1)

        #expect(changedMarkdown.isEmpty)
        #expect(controller.latestMarkdownSnapshot == markdown)
        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 2), .focusStart])

        commands.removeAll()
        controller.handleBridgeMessage(.loadSettled, epoch: 2)
        controller.handleBridgeMessage(.contentDidChange(json: emptyJSON), epoch: 2)
        controller.handleBridgeMessage(.markdownDidChange(markdown: "", writeback: nil), epoch: 2)

        #expect(changedMarkdown == [""])
        #expect(controller.latestMarkdownSnapshot == "")
        #expect(controller.toolbarModel.isDirty)
        #expect(commands.isEmpty)
    }

    @MainActor
    @Test("Markdown Document surface reactivates from non-empty host when WebKit remembered an empty snapshot")
    func markdownDocumentSurfaceReactivatesFromNonEmptyHostWhenWebKitSnapshotWasEmpty() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = """
        # Host Recovery Source

        | A | B |
        | - | - |
        | 1 | 2 |
        """
        var commands: [EpdocEditorCommand] = []

        coordinator.configure(
            pageId: "empty-webkit-reactivation",
            title: "Host Recovery Source",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/empty-webkit-reactivation.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()

        coordinator.controller.loadInitialContent(emptyJSON, title: "Host Recovery Source", markdownSource: "")
        commands.removeAll()

        #expect(coordinator.controller.latestMarkdownSnapshot == "")
        #expect(coordinator.controller.toolbarModel.characterCount == 0)

        coordinator.configure(
            pageId: "empty-webkit-reactivation",
            title: "Host Recovery Source",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/empty-webkit-reactivation.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 3), .focusStart])
        #expect(coordinator.controller.latestMarkdownSnapshot == markdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @MainActor
    @Test("clean Epdoc assist context uses canonical host Markdown over a blank bridge snapshot")
    func cleanEpdocAssistContextUsesCanonicalHostMarkdown() {
        let hostMarkdown = """
        # June Context

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        #expect(
            MarkdownDocumentSurfaceCoordinator.resolvedAssistContextMarkdown(
                hostMarkdown: hostMarkdown,
                latestSnapshot: "",
                latestMarkdown: hostMarkdown,
                isDirty: false
            ) == hostMarkdown
        )
        #expect(
            MarkdownDocumentSurfaceCoordinator.resolvedAssistContextMarkdown(
                hostMarkdown: hostMarkdown,
                latestSnapshot: "",
                latestMarkdown: "",
                isDirty: true
            ).isEmpty
        )
        #expect(
            MarkdownDocumentSurfaceCoordinator.resolvedAssistContextMarkdown(
                hostMarkdown: hostMarkdown,
                latestSnapshot: "# Unsaved live edit\n",
                latestMarkdown: "# Unsaved live edit\n",
                isDirty: true
            ) == "# Unsaved live edit\n"
        )
    }

    @MainActor
    @Test("chrome controller re-arms last Markdown source for WebKit blank recovery")
    func chromeControllerRecoversLastMarkdownSourceAfterWebContentTermination() {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let editedJSON = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Edited table"}]}]}"#
            .data(using: .utf8)!
        let loadedMarkdown = """
        # Loaded table

        | A | B |
        | - | - |
        | 1 | 2 |
        """
        let editedMarkdown = """
        # Edited table

        | A | B |
        | - | - |
        | 3 | 4 |
        """
        var commands: [EpdocEditorCommand] = []
        var changedMarkdown: [String] = []

        controller.onMarkdownChanged = { markdown, _ in
            changedMarkdown.append(markdown)
        }
        controller.loadInitialContent(emptyJSON, title: "Loaded table", markdownSource: loadedMarkdown)
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)
        controller.handleBridgeMessage(.markdownDidChange(markdown: loadedMarkdown, writeback: nil), epoch: 1)
        controller.handleBridgeMessage(.contentDidChange(json: emptyJSON), epoch: 1)
        controller.handleBridgeMessage(.contentDidChange(json: editedJSON), epoch: 1)
        controller.handleBridgeMessage(.markdownDidChange(markdown: editedMarkdown, writeback: nil), epoch: 1)

        #expect(controller.latestMarkdownSnapshot == editedMarkdown)
        #expect(controller.toolbarModel.isDirty)
        #expect(changedMarkdown == [editedMarkdown])
        commands.removeAll()

        #expect(controller.prepareForWebContentProcessRecovery())
        #expect(controller.currentLoadEpoch == 2)
        #expect(controller.latestMarkdownSnapshot == editedMarkdown)
        #expect(controller.toolbarModel.isDirty)

        controller.handleBridgeMessage(.editorReady)
        #expect(commands == [.setMarkdownForLoad(markdown: editedMarkdown, epoch: 2), .focusStart])
        commands.removeAll()

        controller.handleBridgeMessage(.markdownDidChange(markdown: "", writeback: nil), epoch: 2)
        #expect(commands == [.setMarkdownForLoad(markdown: editedMarkdown, epoch: 2)])
        #expect(changedMarkdown == [editedMarkdown])
        #expect(controller.latestMarkdownSnapshot == editedMarkdown)
    }

    @MainActor
    @Test("chrome controller rejects epochless persistence and provenance events after host load")
    func chromeControllerRejectsEpochlessPersistenceAndProvenanceEventsAfterHostLoad() {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let editedJSON = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Edited"}]}]}"#
            .data(using: .utf8)!
        let payload = EpdocSuggestionSpanPayload(
            id: "epochless-agent-edit",
            author: "lumen",
            turnID: "turn-epochless",
            kind: "insertion",
            from: 1,
            to: 1,
            mapVersion: 1,
            before: "",
            after: "agent",
            claimID: "claim:epochless"
        )
        var changedJSON: [Data] = []
        var changedMarkdown: [String] = []
        var payloads: [EpdocSuggestionSpanPayload] = []
        var resolutions: [EpdocSuggestionResolution] = []

        controller.onContentChanged = { changedJSON.append($0) }
        controller.onMarkdownChanged = { markdown, _ in changedMarkdown.append(markdown) }
        controller.onSuggestionApplied = { payloads.append($0) }
        controller.onSuggestionResolved = { resolutions.append($0) }
        controller.loadInitialContent(emptyJSON, title: "Epoch Guard")

        controller.handleBridgeMessage(.contentDidChange(json: editedJSON))
        controller.handleBridgeMessage(.markdownDidChange(markdown: "# Edited\n", writeback: nil))
        controller.handleBridgeMessage(.documentStatsChanged(wordCount: 12, characterCount: 80))
        controller.handleBridgeMessage(.loadSettled)
        controller.handleBridgeMessage(.suggestionApplied(payload))
        controller.handleBridgeMessage(
            .suggestionResolved(EpdocSuggestionResolution(suggestionID: "epochless-agent-edit", state: .accepted))
        )

        #expect(changedJSON.isEmpty)
        #expect(changedMarkdown.isEmpty)
        #expect(payloads.isEmpty)
        #expect(resolutions.isEmpty)
        #expect(!controller.toolbarModel.isDirty)
        #expect(controller.toolbarModel.wordCount == 0)
        #expect(controller.toolbarModel.characterCount == 0)
    }

    @MainActor
    @Test("chrome controller ignores stale epoch editor updates after a newer host load")
    func chromeControllerIgnoresStaleEpochUpdates() {
        let controller = EpdocEditorChromeController()
        let json = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let stale = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Stale"}]}]}"#
            .data(using: .utf8)!
        let fresh = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Fresh"}]}]}"#
            .data(using: .utf8)!
        var observed: [Data] = []

        controller.onContentChanged = { observed.append($0) }
        controller.loadInitialContent(json, title: "Epoch 1")
        #expect(controller.currentLoadEpoch == 1)

        controller.handleBridgeMessage(.loadSettled, epoch: 1)
        controller.handleBridgeMessage(.contentDidChange(json: stale), epoch: 0)
        controller.handleBridgeMessage(.contentDidChange(json: fresh), epoch: 1)

        #expect(observed == [fresh])
        #expect(controller.toolbarModel.isDirty)
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
            .setMarkdownForLoad(markdown: markdown, epoch: 1),
            .setContentWidth(mode: width),
            .focusStart,
        ])
        #expect(persistedWidthChanges.isEmpty)
    }

    @MainActor
    @Test("chrome controller keeps user note-width changes presentation-only")
    func chromeControllerKeepsUserWidthChangesPresentationOnly() {
        let controller = EpdocEditorChromeController()
        var commands: [EpdocEditorCommand] = []
        var persistedWidthChanges: [NoteWidthMode] = []

        controller.onContentWidthChanged = { persistedWidthChanges.append($0) }
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.dispatch(.setContentWidth(mode: .wide))

        #expect(controller.toolbarModel.widthMode == .wide)
        #expect(commands == [.setContentWidth(mode: .wide)])
        #expect(persistedWidthChanges.isEmpty)
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
    @Test("chrome controller computes bounded initial status from loaded document JSON before JS emits updates")
    func chromeControllerComputesBoundedInitialStatusFromLoadedJSON() {
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
        let writeback = EpdocMarkdownWritebackRegion(
            byteFrom: 14,
            byteTo: 22,
            codeUnitFrom: 14,
            codeUnitTo: 22,
            changedFrom: 2,
            changedTo: 3,
            blockIndexFrom: 1,
            blockIndexTo: 2,
            blockMarkdown: "[[Note]]\n"
        )
        var observed: [(markdown: String, writeback: EpdocMarkdownWritebackRegion?)] = []
        controller.onMarkdownChanged = { markdown, writeback in
            observed.append((markdown, writeback))
        }

        controller.handleBridgeMessage(.markdownDidChange(
            markdown: "# Canonical\n\n[[Note]]\n",
            writeback: writeback
        ), epoch: 0)

        #expect(controller.latestMarkdownSnapshot == "# Canonical\n\n[[Note]]\n")
        #expect(observed.count == 1)
        #expect(observed.first?.markdown == "# Canonical\n\n[[Note]]\n")
        #expect(observed.first?.writeback == writeback)
    }

    @MainActor
    @Test("loading a new initial JSON clears stale markdown snapshots")
    func chromeControllerClearsMarkdownSnapshotOnLoad() {
        let controller = EpdocEditorChromeController()
        controller.handleBridgeMessage(.markdownDidChange(markdown: "# Previous\n", writeback: nil), epoch: 0)
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
            "selection": ["from": 5, "to": 9, "empty": false, "text": "seed"],
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
        #expect(selection.to == 9)
        #expect(selection.isEmpty == false)
        #expect(selection.selectedText == "seed")
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
            "selection": ["from": 10, "to": 25, "empty": false, "text": "selected claim"],
            "anchor": ["x": 50, "y": 60, "w": 200, "h": 18],
        ]
        guard case let .requestBubbleMenu(selection, anchor) = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "expected .requestBubbleMenu")
            return
        }
        #expect(selection.from == 10)
        #expect(selection.to == 25)
        #expect(selection.isEmpty == false)
        #expect(selection.selectedText == "selected claim")
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
        // requestBubbleMenu with oversized selection text
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "requestBubbleMenu",
                                                       "selection": [
                                                           "from": 0,
                                                           "to": 1,
                                                           "empty": false,
                                                           "text": String(repeating: "x", count: EpdocBridgeSelection.maxSelectedTextCharacters + 4),
                                                       ],
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

    @Test("epoch-stamped load commands pass the native load epoch into JS")
    func epochStampedLoadCommandsRouteThroughEpistemosNamespace() {
        let json = #"{"type":"doc","content":[]}"#.data(using: .utf8)!
        #expect(EpdocEditorCommand.setContentForLoad(json: json, epoch: 7).javaScriptExpression()
                == #"window.epistemos.setContent("{\"type\":\"doc\",\"content\":[]}", 7)"#)
        #expect(EpdocEditorCommand.setMarkdownForLoad(markdown: "# Claim", epoch: 8).javaScriptExpression()
                == ##"window.epistemos.setMarkdown("# Claim", 8)"##)
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

    @Test("tracked suggestion commands use the SuggestionAdapter bridge contract")
    func trackedSuggestionCommandsUseAdapterBridgeContract() {
        let payload = EpdocSuggestionSpanPayload(
            id: "span-1",
            author: "june",
            turnID: "turn-1",
            kind: "replacement",
            from: 5,
            to: 12,
            mapVersion: 1,
            before: "old",
            after: "new",
            rationale: "tighten",
            sourceCitation: "source:alpha",
            claimID: "claim-alpha"
        )

        #expect(EpdocEditorCommand.applySuggestion(payload: payload).javaScriptExpression()
                == #"window.epistemos.runCommand("applySuggestion", ...[{"id":"span-1","author":"june","turnId":"turn-1","kind":"replacement","from":5,"to":12,"mapVersion":1,"before":"old","after":"new","rationale":"tighten","sourceCitation":"source:alpha","claimId":"claim-alpha"}])"#)
        #expect(EpdocEditorCommand.acceptSuggestion(id: "span-1").javaScriptExpression()
                == #"window.epistemos.runCommand("acceptSuggestion", ...["span-1"])"#)
        #expect(EpdocEditorCommand.rejectSuggestion(id: "span-1").javaScriptExpression()
                == #"window.epistemos.runCommand("rejectSuggestion", ...["span-1"])"#)
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

        guard let updateStart = source.range(of: "onUpdate: ({ editor: ed, transaction }) => {"),
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
        #expect(source.contains("markdownProjectionMode"))
        #expect(source.contains("postMarkdownDidChange(editor, { preferWriteback: true })"))
        #expect(source.contains("LARGE_DOCUMENT_NODE_SIZE"))
    }

    @Test("document editor exposes immediate snapshot flush for native saves")
    func documentEditorExposesImmediateSnapshotFlushForNativeSaves() throws {
        let inbound = try loadMirroredSourceTextFile("js-editor/src/bridge/inbound.ts")
        let index = try loadMirroredSourceTextFile("js-editor/src/index.ts")
        let webkitTypes = try loadMirroredSourceTextFile("js-editor/src/types/webkit.d.ts")
        let chrome = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")

        #expect(EpdocEditorCommand.flushDocumentSnapshot.javaScriptExpression() == "window.epistemos.flushDocumentSnapshot()")
        #expect(inbound.contains("flushDocumentSnapshot(): void"))
        #expect(inbound.contains("getMarkdown(): string"))
        #expect(inbound.contains("postDocumentSnapshot(editor, callbacks.postMarkdownSnapshot)"))
        #expect(webkitTypes.contains("flushDocumentSnapshot(): void;"))
        #expect(webkitTypes.contains("getMarkdown(): string;"))
        #expect(index.contains("markdownSnapshotWithVisibleTextFallback(ed)"))
        #expect(index.contains("function markdownBodyText(markdown: string): string"))
        #expect(index.contains("visibleText.trim().length > 0 && markdownBodyText(markdown).trim().length === 0"),
                "Live markdownDidChange snapshots must not save frontmatter-only serializer output over visible document text.")
        #expect(chrome.contains("editor.state.doc.textBetween(0, editor.state.doc.content.size"),
                "Native save/lens-switch snapshots must fall back to live visible editor text if Markdown serialization returns empty or frontmatter-only.")
        #expect(chrome.contains("const markdownBodyText = (value) => {"))
        #expect(chrome.contains("markdownBodyText(markdown).trim().length === 0"))
        #expect(chrome.contains("if (typeof markdown === 'string' && markdown.trim().length > 0) return markdown;"))
        #expect(chrome.contains("if (typeof visibleText === 'string' && visibleText.trim().length > 0) return visibleText;"))
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

    @MainActor
    private static func makeBundledEditorWebView(
        probe: EpdocWebKitBridgeProbe
    ) -> (webView: WKWebView, userContentController: WKUserContentController) {
        let userContentController = WKUserContentController()
        userContentController.add(probe, name: "epdoc")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(
            EpdocEditorURLSchemeHandler(),
            forURLScheme: epdocEditorURLScheme
        )

        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 960, height: 640),
            configuration: configuration
        )
        webView.navigationDelegate = probe
        return (webView, userContentController)
    }

    @MainActor
    private static func waitForBundledOutboundBridge(in webView: WKWebView) async throws {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if try await evaluateBool(
                "typeof window.epdocOutboundBridge === 'object' && typeof window.epdocOutboundBridge.flushSync === 'function'",
                in: webView
            ) {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw EpdocWebKitBridgeProbeError.timeout("bundled outbound bridge did not initialize")
    }

    @MainActor
    private static func waitForBundledInboundCommands(in webView: WKWebView) async throws {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if try await evaluateBool(
                "typeof window.epistemos === 'object' && typeof window.epistemos.runCommand === 'function' && typeof window.epistemos.setMarkdown === 'function' && typeof window.epistemos.getMarkdown === 'function'",
                in: webView
            ) {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw EpdocWebKitBridgeProbeError.timeout("bundled inbound commands did not initialize")
    }

    @MainActor
    private static func evaluateBool(_ script: String, in webView: WKWebView) async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (result as? Bool) == true)
            }
        }
    }

    @MainActor
    private static func evaluateString(_ script: String, in webView: WKWebView) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result as? String ?? "")
            }
        }
    }

    @MainActor
    private static func waitForEditorText(
        _ expected: String,
        in webView: WKWebView,
        timeout: TimeInterval = 8
    ) async throws -> String {
        let script = """
        (() => {
          const editor = window.epdocEditor;
          if (!editor) return '';
          return editor.state.doc.textBetween(0, editor.state.doc.content.size, ' ', ' ');
        })()
        """
        let deadline = Date().addingTimeInterval(timeout)
        var latest = ""
        while Date() < deadline {
            latest = try await evaluateString(script, in: webView)
            if latest == expected {
                return latest
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw EpdocWebKitBridgeProbeError.timeout(
            "editor text did not become \(expected.debugDescription); latest \(latest.debugDescription)"
        )
    }

    @MainActor
    private static func evaluateScript(_ script: String, in webView: WKWebView) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            webView.evaluateJavaScript(script) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume()
            }
        }
    }
}

@MainActor
private final class EpdocWebKitBridgeProbe: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    private var didFinishNavigation = false
    private var navigationError: Error?
    private var messageBodies: [Any] = []

    func waitForNavigation(timeout: TimeInterval = 12) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let navigationError {
                throw navigationError
            }
            if didFinishNavigation {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw EpdocWebKitBridgeProbeError.timeout("WKWebView did not finish loading editor.html")
    }

    func waitForDecodedMessages(
        containingSuggestionID suggestionID: String,
        markdown expectedMarkdown: String,
        writebackBlockMarkdown expectedBlockMarkdown: String,
        timeout: TimeInterval = 8
    ) async throws -> [(message: EpdocBridgeMessage, epoch: Int?)] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let decoded = messageBodies.flatMap { body in
                EpdocBridgeMessage.decodeEnvelope(messageBody: body)
            }
            let hasWriteback = decoded.contains { entry in
                if case let .markdownDidChange(markdown, writeback) = entry.message {
                    return markdown == expectedMarkdown
                        && writeback?.blockMarkdown == expectedBlockMarkdown
                }
                return false
            }
            let hasApplied = decoded.contains { entry in
                if case let .suggestionApplied(payload) = entry.message {
                    return payload.id == suggestionID
                }
                return false
            }
            let hasResolved = decoded.contains { entry in
                if case let .suggestionResolved(resolution) = entry.message {
                    return resolution.suggestionID == suggestionID
                }
                return false
            }
            if hasWriteback && hasApplied && hasResolved {
                return decoded
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw EpdocWebKitBridgeProbeError.timeout(
            "WKWebView did not deliver writeback and suggestion bridge payloads; observed \(debugSummaryForMessageBodies())"
        )
    }

    func waitForSuggestionFlow(
        containingSuggestionID suggestionID: String,
        resolvedState: EpdocSuggestionResolutionState,
        timeout: TimeInterval = 8
    ) async throws -> [(message: EpdocBridgeMessage, epoch: Int?)] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let decoded = messageBodies.flatMap { body in
                EpdocBridgeMessage.decodeEnvelope(messageBody: body)
            }
            let hasApplied = decoded.contains { entry in
                if case let .suggestionApplied(payload) = entry.message {
                    return payload.id == suggestionID
                }
                return false
            }
            let hasResolved = decoded.contains { entry in
                if case let .suggestionResolved(resolution) = entry.message {
                    return resolution.suggestionID == suggestionID
                        && resolution.state == resolvedState
                }
                return false
            }
            if hasApplied && hasResolved {
                return decoded
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw EpdocWebKitBridgeProbeError.timeout(
            "WKWebView did not deliver inbound suggestion flow payloads; observed \(debugSummaryForMessageBodies())"
        )
    }

    private func debugSummaryForMessageBodies() -> String {
        guard !messageBodies.isEmpty else { return "0 bodies" }
        let summaries = messageBodies.suffix(12).enumerated().map { offset, body in
            let index = messageBodies.count - messageBodies.suffix(12).count + offset
            let rawDescription: String
            if let dict = body as? [String: Any],
               let type = dict["type"] as? String {
                if type == "batch",
                   let messages = dict["messages"] as? [Any] {
                    let types = messages.compactMap { item in
                        (item as? [String: Any])?["type"] as? String
                    }
                    rawDescription = "batch(\(types.joined(separator: ",")))"
                } else {
                    rawDescription = type
                }
            } else {
                rawDescription = String(describing: Swift.type(of: body))
            }
            let decoded = EpdocBridgeMessage.decodeEnvelope(messageBody: body)
                .map(Self.debugDescription(for:))
                .joined(separator: ",")
            return "#\(index): raw=\(rawDescription) decoded=[\(decoded)]"
        }
        return "\(messageBodies.count) bodies \(summaries.joined(separator: "; "))"
    }

    private static func debugDescription(for entry: (message: EpdocBridgeMessage, epoch: Int?)) -> String {
        let epoch = entry.epoch.map(String.init) ?? "nil"
        switch entry.message {
        case .editorReady:
            return "editorReady@\(epoch)"
        case let .markdownDidChange(markdown, writeback):
            let preview = String(markdown.prefix(32)).replacingOccurrences(of: "\n", with: "\\n")
            let block = writeback?.blockMarkdown.replacingOccurrences(of: "\n", with: "\\n") ?? "nil"
            return "markdown@\(epoch)(\(preview),writeback:\(block))"
        case let .suggestionApplied(payload):
            return "suggestionApplied@\(epoch)(\(payload.id))"
        case let .suggestionResolved(resolution):
            return "suggestionResolved@\(epoch)(\(resolution.suggestionID):\(resolution.state.rawValue))"
        case .contentDidChange:
            return "contentDidChange@\(epoch)"
        case .loadSettled:
            return "loadSettled@\(epoch)"
        case .documentStatsChanged:
            return "documentStatsChanged@\(epoch)"
        case .caretChanged:
            return "caretChanged@\(epoch)"
        case .requestSlashMenu:
            return "requestSlashMenu@\(epoch)"
        case .requestBubbleMenu:
            return "requestBubbleMenu@\(epoch)"
        case .storeImageAsset:
            return "storeImageAsset@\(epoch)"
        case .requestHTMLWorkspace:
            return "requestHTMLWorkspace@\(epoch)"
        case let .error(message):
            return "error@\(epoch)(\(message))"
        }
    }

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        MainActor.assumeIsolated {
            messageBodies.append(message.body)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didFinishNavigation = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationError = error
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        navigationError = error
    }
}

private enum EpdocWebKitBridgeProbeError: Error, CustomStringConvertible {
    case timeout(String)

    var description: String {
        switch self {
        case .timeout(let message):
            return message
        }
    }
}
