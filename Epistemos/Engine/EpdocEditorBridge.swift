import Combine
import Compression
import Foundation
@preconcurrency import WebKit

// MARK: - EpdocEditorBridge
//
// Wave 7.2 base of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.2,
//  cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §4).
//
// Swift-side surface for the Tiptap WKWebView document editor. Per the
// Wave 7.2 research finding, the canonical 2026 macOS pattern is:
//   - Tiptap 3.0.x + ProseMirror 1.23+ for the editor
//   - WKURLSchemeHandler for a custom `epistemos-doc://` scheme
//     (NOT loadFileURL — can't intercept relative subresources reliably
//      under hardened runtime)
//   - ONE @MainActor singleton WKWebView shared across SwiftUI document
//     tabs (swap content via evaluateJavaScript, NOT one webview per
//     document — multi-second JS engine boot per webview)
//   - Combine 300ms debounce on the SWIFT side (JS-side debounce loses
//     events on tab switch and complicates the canonical-save invariant)
//   - Tiptap UniqueID extension to preserve block IDs across saves
//
// This commit ships the Swift-side bridge surface ONLY. The actual
// Tiptap JS bundle (npm install + Webpack build into Resources/Editor/)
// is a documented follow-up — without it the WKWebView won't render,
// but the bridge code below is exercised in isolation by the tests.

// MARK: - URL scheme

/// Canonical custom scheme served by `EpdocEditorURLSchemeHandler`.
/// Tiptap loads its index.html + JS + CSS via this scheme so we can
/// intercept every subresource fetch and serve from the app bundle
/// (or future per-document asset directory) rather than the network.
public let epdocEditorURLScheme = "epistemos-doc"

nonisolated struct EpdocEditorAssetResponse: Sendable, Equatable {
    let fileURL: URL
    let mimeType: String
    let contentEncoding: String?
}

nonisolated public struct EpdocEditorDocumentAsset: Sendable, Equatable {
    public let data: Data
    public let mimeType: String

    public init(data: Data, mimeType: String) {
        self.data = data
        self.mimeType = mimeType
    }
}

nonisolated struct EpdocBundledFontAsset: Sendable, Equatable {
    let resourceName: String
    let resourceExtension: String

    var filename: String { "\(resourceName).\(resourceExtension)" }
}

nonisolated enum EpdocEditorAssetResolver {
    static let documentAssetPrefix = "assets/"
    static var bundledFontAssets: [EpdocBundledFontAsset] {
        AppDisplayTypography.displayFontOptions.map {
            EpdocBundledFontAsset(
                resourceName: $0.resourceName,
                resourceExtension: $0.resourceExtension
            )
        }
    }

    static func resolve(relativePath: String, assetRoot: URL) throws -> EpdocEditorAssetResponse {
        let relative = relativePath.hasPrefix("/")
            ? String(relativePath.dropFirst())
            : relativePath
        let pathComponents = relative.split(separator: "/").map(String.init)
        guard !pathComponents.isEmpty,
              pathComponents.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw EpdocBridgeError.invalidURL
        }

        let requestedURL = pathComponents.reduce(assetRoot) { partial, component in
            partial.appendingPathComponent(component, isDirectory: false)
        }
        let requestedExtension = requestedURL.pathExtension
        let brotliURL = requestedURL.appendingPathExtension("br")

        if isBrotliEligible(extension: requestedExtension),
           FileManager.default.isReadableFile(atPath: brotliURL.path) {
            return EpdocEditorAssetResponse(
                fileURL: brotliURL,
                mimeType: mimeType(for: requestedExtension),
                contentEncoding: "br"
            )
        }

        guard FileManager.default.isReadableFile(atPath: requestedURL.path) else {
            throw EpdocBridgeError.assetNotFound(path: relative)
        }
        return EpdocEditorAssetResponse(
            fileURL: requestedURL,
            mimeType: mimeType(for: requestedExtension),
            contentEncoding: nil
        )
    }

    static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html":            return "text/html"
        case "js", "mjs":       return "text/javascript"
        case "css":             return "text/css"
        case "json":            return "application/json"
        case "wasm":            return "application/wasm"
        case "svg":             return "image/svg+xml"
        case "png":             return "image/png"
        case "jpg", "jpeg":     return "image/jpeg"
        case "gif":             return "image/gif"
        case "heic":            return "image/heic"
        case "webp":            return "image/webp"
        case "woff":            return "font/woff"
        case "woff2":           return "font/woff2"
        case "ttf":             return "font/ttf"
        case "otf":             return "font/otf"
        default:                return "application/octet-stream"
        }
    }

    static func bundleFont(named name: String, extension ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext)
            ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Fonts")
    }

    static func bundledFontAsset(relativePath: String) -> EpdocEditorAssetResponse? {
        let normalized = relativePath.hasPrefix("/")
            ? String(relativePath.dropFirst())
            : relativePath
        guard let asset = bundledFontAssets.first(where: { $0.filename == normalized }),
              let url = bundleFont(named: asset.resourceName, extension: asset.resourceExtension) else {
            return nil
        }
        return EpdocEditorAssetResponse(
            fileURL: url,
            mimeType: mimeType(for: asset.resourceExtension),
            contentEncoding: nil
        )
    }

    private static func isBrotliEligible(extension ext: String) -> Bool {
        switch ext.lowercased() {
        case "js", "mjs", "css":
            return true
        default:
            return false
        }
    }

    static func documentAssetName(relativePath: String) -> String? {
        let relative = relativePath.hasPrefix("/")
            ? String(relativePath.dropFirst())
            : relativePath
        guard relative.hasPrefix(documentAssetPrefix) else { return nil }
        let name = String(relative.dropFirst(documentAssetPrefix.count))
        guard !name.isEmpty,
              !name.contains("/"),
              !name.contains("\\"),
              name != ".",
              name != ".." else {
            return nil
        }
        return name
    }
}

// MARK: - URL scheme handler

/// `WKURLSchemeHandler` that serves Tiptap editor assets from the app
/// bundle's `Resources/Editor/` directory. Per the Wave 7.2 research
/// finding: this is the canonical 2026 pattern for app-bound
/// JavaScript loading inside WKWebView. `loadFileURL` is deprecated
/// for this use because it can't intercept relative-path subresource
/// fetches reliably under hardened runtime.
///
/// Path mapping: `epistemos-doc:///editor.html` → `Bundle.main/Resources/Editor/editor.html`.
/// Per-document asset overrides (the `assets/` folder inside an
/// `.epdoc` package) are a follow-up.
@MainActor
public final class EpdocEditorURLSchemeHandler: NSObject, WKURLSchemeHandler {

    /// Asset directory inside the app bundle. Defaults to `Editor/` so
    /// the bundled Tiptap build sits at `<bundle>/Resources/Editor/...`.
    /// Tests override this to point at a fixture directory.
    public let assetSubpath: String
    private let documentAssetResolver: @MainActor (String) -> EpdocEditorDocumentAsset?

    public init(
        assetSubpath: String = "Editor",
        documentAssetResolver: @escaping @MainActor (String) -> EpdocEditorDocumentAsset? = { _ in nil }
    ) {
        self.assetSubpath = assetSubpath
        self.documentAssetResolver = documentAssetResolver
    }

    public func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(EpdocBridgeError.invalidURL)
            return
        }
        if let assetName = EpdocEditorAssetResolver.documentAssetName(relativePath: url.path) {
            guard let asset = documentAssetResolver(assetName) else {
                urlSchemeTask.didFailWithError(EpdocBridgeError.assetNotFound(path: url.path))
                return
            }
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": asset.mimeType]
            ) ?? URLResponse(
                url: url,
                mimeType: asset.mimeType,
                expectedContentLength: asset.data.count,
                textEncodingName: nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(asset.data)
            urlSchemeTask.didFinish()
            return
        }

        guard let assetRoot = Bundle.main.resourceURL?
            .appendingPathComponent(assetSubpath, isDirectory: true) else {
            urlSchemeTask.didFailWithError(EpdocBridgeError.assetNotFound(path: assetSubpath))
            return
        }

        let asset: EpdocEditorAssetResponse
        do {
            asset = try EpdocEditorAssetResolver.resolve(relativePath: url.path, assetRoot: assetRoot)
        } catch EpdocBridgeError.assetNotFound {
            guard let fontAsset = EpdocEditorAssetResolver.bundledFontAsset(relativePath: url.path) else {
                urlSchemeTask.didFailWithError(EpdocBridgeError.assetNotFound(path: url.path))
                return
            }
            asset = fontAsset
        } catch let error as EpdocBridgeError {
            urlSchemeTask.didFailWithError(error)
            return
        } catch {
            urlSchemeTask.didFailWithError(EpdocBridgeError.invalidURL)
            return
        }

        guard let rawData = try? Data(contentsOf: asset.fileURL) else {
            urlSchemeTask.didFailWithError(EpdocBridgeError.assetNotFound(path: url.path))
            return
        }

        // Critical fix 2026-05-05: WKWebView's custom-URL-scheme handler
        // path does NOT auto-decompress `Content-Encoding: br` (only the
        // HTTPS path does). Prior behavior served `.br` bytes with the
        // Content-Encoding header set, expecting WKWebView to decode —
        // result: editor.css/.js bytes arrive at the renderer compressed,
        // CSS doesn't apply, Tiptap fails to initialize, the user sees a
        // blank editor (the "ep doc i dont see ant texts" report).
        // Fix: decompress brotli server-side via Compression.framework
        // before handing bytes to the renderer; advertise plain content
        // (no Content-Encoding header).
        //
        // RCA8-P1-004 fix-pass (2026-05-13): the Brotli decompression
        // for editor.js/.css (~213 KB compressed → ~1 MB plain) used to
        // run synchronously on @MainActor, adding 10-30 ms to cold-open
        // first-paint. Decompress off-actor, then return to the inherited
        // MainActor task before touching WKURLSchemeTask. That keeps Swift 6
        // concurrency clean while preserving the off-main decode work.
        let mimeType = asset.mimeType
        let urlForResponse = url
        if asset.contentEncoding == "br" {
            Task(priority: .userInitiated) {
                let decompressed = await Task.detached(priority: .userInitiated) {
                    decompressBrotli(rawData)
                }.value
                guard let decompressed else {
                    urlSchemeTask.didFailWithError(EpdocBridgeError.assetNotFound(path: urlForResponse.path))
                    return
                }
                let headers = ["Content-Type": mimeType]
                let response = HTTPURLResponse(
                    url: urlForResponse,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: headers
                ) ?? URLResponse(
                    url: urlForResponse,
                    mimeType: mimeType,
                    expectedContentLength: decompressed.count,
                    textEncodingName: "utf-8"
                )
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(decompressed)
                urlSchemeTask.didFinish()
            }
            return
        }

        let data = rawData
        let headers = [
            "Content-Type": asset.mimeType,
        ]
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) ?? URLResponse(
            url: url,
            mimeType: asset.mimeType,
            expectedContentLength: data.count,
            textEncodingName: "utf-8"
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    public func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // Synchronous bundle load above; nothing to cancel.
    }

}

// MARK: - Brotli decompression
//
// Apple's Compression.framework supports COMPRESSION_BROTLI on
// macOS 11+. The Tiptap editor.js bundle is ~213 KB compressed and
// decompresses to ~1 MB plain — well within a single
// `compression_decode_buffer` call. Returns nil on decode failure
// (corrupt brotli stream); the URL scheme handler then surfaces an
// asset-not-found error to the renderer.
//
// Buffer sizing rationale: brotli's worst-case expansion ratio is
// well under 32x for typical inputs (text/JS/CSS); a 64x safety
// margin handles pathological inputs without unbounded allocation.
// If the decompressed content exceeds the buffer, we retry with a
// larger one rather than truncating.
// RCA8-P1-004 fix-pass: `nonisolated` so the URL scheme handler can
// call this from a Task.detached without inheriting @MainActor.
nonisolated private func decompressBrotli(_ compressed: Data) -> Data? {
    var bufferSize = max(compressed.count * 64, 1024 * 1024)  // start at ≥1 MB
    let maxBufferSize = 64 * 1024 * 1024                       // cap at 64 MB
    while bufferSize <= maxBufferSize {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        let written = compressed.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
            guard let srcPtr = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                buffer, bufferSize,
                srcPtr, compressed.count,
                nil, COMPRESSION_BROTLI
            )
        }
        // If `written == bufferSize` we may have truncated; double the
        // buffer and retry. If `written == 0` and src is non-empty,
        // the stream is corrupt.
        if written == 0 && !compressed.isEmpty {
            return nil
        }
        if written < bufferSize {
            return Data(bytes: buffer, count: written)
        }
        bufferSize *= 2
    }
    return nil  // exceeded max buffer; treat as decode failure
}

// MARK: - Script-message bridge

/// Geometry payload — viewport-relative rect (x/y/w/h) emitted by the
/// JS side for caret + slash-menu + bubble-menu anchor positioning.
/// W7.17.a SwiftUI chrome translates these to window coords via the
/// WKWebView's frame.
nonisolated public struct EpdocBridgeRect: Sendable, Hashable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Selection state payload — character offsets + collapsed flag.
nonisolated public struct EpdocBridgeSelection: Sendable, Hashable {
    public static let maxSelectedTextCharacters = 4_000

    public let from: Int
    public let to: Int
    public let isEmpty: Bool
    public let selectedText: String?

    public init(from: Int, to: Int, isEmpty: Bool, selectedText: String? = nil) {
        self.from = from
        self.to = to
        self.isEmpty = isEmpty
        self.selectedText = selectedText.flatMap(Self.boundedSelectedText)
    }

    private static func boundedSelectedText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxSelectedTextCharacters))
    }
}

/// Active formatting state at the current selection. This is emitted
/// by the JS editor so native chrome never has to guess which marks
/// are active under the caret.
nonisolated public struct EpdocBridgeActiveMarks: Sendable, Hashable {
    public let isBoldActive: Bool
    public let isItalicActive: Bool
    public let isStrikeActive: Bool
    public let isCodeActive: Bool
    public let isHighlightActive: Bool
    public let activeHeadingLevel: Int?

    public static let inactive = EpdocBridgeActiveMarks()

    public init(
        isBoldActive: Bool = false,
        isItalicActive: Bool = false,
        isStrikeActive: Bool = false,
        isCodeActive: Bool = false,
        isHighlightActive: Bool = false,
        activeHeadingLevel: Int? = nil
    ) {
        self.isBoldActive = isBoldActive
        self.isItalicActive = isItalicActive
        self.isStrikeActive = isStrikeActive
        self.isCodeActive = isCodeActive
        self.isHighlightActive = isHighlightActive
        self.activeHeadingLevel = activeHeadingLevel
    }
}

nonisolated public struct EpdocMarkdownWritebackRegion: Sendable, Hashable {
    public let byteFrom: Int
    public let byteTo: Int
    public let codeUnitFrom: Int
    public let codeUnitTo: Int
    public let changedFrom: Int
    public let changedTo: Int
    public let blockIndexFrom: Int
    public let blockIndexTo: Int
    public let blockMarkdown: String

    public init(
        byteFrom: Int,
        byteTo: Int,
        codeUnitFrom: Int,
        codeUnitTo: Int,
        changedFrom: Int,
        changedTo: Int,
        blockIndexFrom: Int,
        blockIndexTo: Int,
        blockMarkdown: String
    ) {
        self.byteFrom = byteFrom
        self.byteTo = byteTo
        self.codeUnitFrom = codeUnitFrom
        self.codeUnitTo = codeUnitTo
        self.changedFrom = changedFrom
        self.changedTo = changedTo
        self.blockIndexFrom = blockIndexFrom
        self.blockIndexTo = blockIndexTo
        self.blockMarkdown = blockMarkdown
    }
}

nonisolated public enum EpdocSuggestionResolutionState: String, Sendable, Hashable {
    case accepted
    case rejected
}

nonisolated public struct EpdocSuggestionResolution: Sendable, Hashable {
    public let suggestionID: String
    public let state: EpdocSuggestionResolutionState

    public init(suggestionID: String, state: EpdocSuggestionResolutionState) {
        self.suggestionID = suggestionID
        self.state = state
    }
}

nonisolated public struct EpdocSuggestionSpanPayload: Sendable, Hashable {
    public let id: String
    public let author: String
    public let turnID: String
    public let kind: String
    public let from: Int
    public let to: Int
    public let mapVersion: Int
    public let before: String
    public let after: String
    public let rationale: String?
    public let sourceCitation: String?
    public let claimID: String?

    public init(
        id: String,
        author: String,
        turnID: String,
        kind: String,
        from: Int,
        to: Int,
        mapVersion: Int,
        before: String,
        after: String,
        rationale: String? = nil,
        sourceCitation: String? = nil,
        claimID: String? = nil
    ) {
        self.id = id
        self.author = author
        self.turnID = turnID
        self.kind = kind
        self.from = from
        self.to = to
        self.mapVersion = mapVersion
        self.before = before
        self.after = after
        self.rationale = rationale
        self.sourceCitation = sourceCitation
        self.claimID = claimID
    }
}

/// JS → Swift messages over the WKScriptMessageHandler bridge. The JS
/// side posts these via `window.webkit.messageHandlers.epdoc.postMessage(...)`.
nonisolated public enum EpdocBridgeMessage: Sendable, Hashable {
    /// The editor produced a new ProseMirror JSON snapshot. Posted on
    /// every editor transaction by the JS side; debounced before save.
    case contentDidChange(json: Data)
    /// Full-fidelity Markdown snapshot from the JS serializer. This is
    /// decoded ahead of the L1 markdown-on-disk flip, but does not drive
    /// autosave until that source-of-truth role changes explicitly.
    case markdownDidChange(markdown: String, writeback: EpdocMarkdownWritebackRegion?)
    /// JS-side CharacterCount update. Posted on create, setContent,
    /// and content-changing commands so the native chrome/footer does
    /// not display stale placeholder counts.
    case documentStatsChanged(wordCount: Int, characterCount: Int)
    /// JS reports that a host-driven load has settled through the
    /// epoch guard. The chrome uses this to close legacy echo
    /// suppression without trusting Tiptap's emitUpdate:false.
    case loadSettled
    /// The editor finished its initial mount and is ready to receive
    /// `editor.commands.setContent(...)`.
    case editorReady
    /// JS-side raised an unrecoverable error (parse failure, etc.).
    case error(message: String)
    /// W7.17 — caret position + selection state. Emitted on every
    /// transaction so the SwiftUI chrome (W7.17.a) can dock its
    /// floating panels next to the live document area.
    case caretChanged(
        rect: EpdocBridgeRect,
        selection: EpdocBridgeSelection,
        marks: EpdocBridgeActiveMarks
    )
    /// W7.17.b — slash menu activation. Emitted when `/` is typed
    /// + on every keystroke while the menu is visible. `query` is
    /// the substring after the `/` trigger; `anchor` is the caret
    /// rect the SwiftUI picker positions itself against.
    case requestSlashMenu(query: String, anchor: EpdocBridgeRect)
    /// W7.17.b — bubble menu activation. Emitted on non-empty
    /// selection.
    case requestBubbleMenu(selection: EpdocBridgeSelection, anchor: EpdocBridgeRect)
    /// JS intercepted a pasted/dropped image file and asks the native
    /// document host to store it in the `.epdoc` package assets folder.
    case storeImageAsset(requestID: String, filename: String, mimeType: String, data: Data)
    /// JS requested a first-class HTML Workspace instead of embedding
    /// arbitrary HTML/DOM runtime inside the Epdoc body.
    case requestHTMLWorkspace
    /// JS applied a tracked suggestion transaction. Posted only after
    /// the HWC adapter accepts the payload and mutates the document.
    case suggestionApplied(EpdocSuggestionSpanPayload)
    /// JS accepted or rejected a tracked suggestion. The payload carries
    /// only the decision event; original span insertion remains owned by
    /// the agent-edit ingestion path.
    case suggestionResolved(EpdocSuggestionResolution)

    /// Decode a raw `WKScriptMessage.body` value into a typed message.
    /// Returns `nil` on shape failure. Accepted shapes:
    ///
    ///   `{"type": "contentDidChange", "json": "<stringified-prosemirror-json>"}`
    ///   `{"type": "markdownDidChange", "markdown": "# Full-fidelity markdown"}`
    ///   `{"type": "documentStatsChanged", "wordCount": 10, "characterCount": 80}`
    ///   `{"type": "loadSettled", "epoch": 1}`
    ///   `{"type": "editorReady"}`
    ///   `{"type": "error", "message": "..."}`
    ///   `{"type": "caretChanged", "rect": {x,y,w,h}, "selection": {from,to,empty}, "marks": {...}}`
    ///   `{"type": "requestSlashMenu", "query": "...", "anchor": {x,y,w,h}}`
    ///   `{"type": "requestBubbleMenu", "selection": {from,to,empty}, "anchor": {x,y,w,h}}`
    ///   `{"type": "requestHTMLWorkspace"}`
    ///   `{"type": "suggestionApplied", "id": "...", "turnId": "...", ...}`
    ///   `{"type": "suggestionResolved", "suggestionId": "...", "state": "accepted"}`
    public static func decode(messageBody: Any) -> EpdocBridgeMessage? {
        guard let dict = messageBody as? [String: Any],
              let type = dict["type"] as? String else {
            return nil
        }
        switch type {
        case "contentDidChange":
            guard let jsonString = dict["json"] as? String,
                  let data = jsonString.data(using: .utf8) else {
                return nil
            }
            return .contentDidChange(json: data)
        case "markdownDidChange":
            guard let markdown = dict["markdown"] as? String else {
                return nil
            }
            return .markdownDidChange(
                markdown: markdown,
                writeback: parseWritebackRegion(dict["writeback"])
            )
        case "documentStatsChanged":
            guard let wordCount = readInteger(dict["wordCount"]),
                  let characterCount = readInteger(dict["characterCount"]) else {
                return nil
            }
            return .documentStatsChanged(wordCount: wordCount, characterCount: characterCount)
        case "loadSettled":
            return .loadSettled
        case "editorReady":
            return .editorReady
        case "error":
            guard let msg = dict["message"] as? String else { return nil }
            return .error(message: msg)
        case "caretChanged":
            guard let rect = parseRect(dict["rect"]),
                  let selection = parseSelection(dict["selection"]),
                  let marks = parseActiveMarks(dict["marks"]) else {
                return nil
            }
            return .caretChanged(rect: rect, selection: selection, marks: marks)
        case "requestSlashMenu":
            guard let query = dict["query"] as? String,
                  let anchor = parseRect(dict["anchor"]) else {
                return nil
            }
            return .requestSlashMenu(query: query, anchor: anchor)
        case "requestBubbleMenu":
            guard let selection = parseSelection(dict["selection"]),
                  let anchor = parseRect(dict["anchor"]) else {
                return nil
            }
            return .requestBubbleMenu(selection: selection, anchor: anchor)
        case "storeImageAsset":
            guard let requestID = readNonEmptyString(dict["requestID"]),
                  let filename = readNonEmptyString(dict["filename"]),
                  let mimeType = readNonEmptyString(dict["mimeType"]),
                  let base64 = dict["base64"] as? String,
                  let data = Data(base64Encoded: base64) else {
                return nil
            }
            return .storeImageAsset(
                requestID: requestID,
                filename: filename,
                mimeType: mimeType,
                data: data
            )
        case "requestHTMLWorkspace":
            return .requestHTMLWorkspace
        case "suggestionApplied":
            guard let payload = parseSuggestionSpanPayload(dict) else {
                return nil
            }
            return .suggestionApplied(payload)
        case "suggestionResolved":
            guard let suggestionID = readNonEmptyString(dict["suggestionId"]),
                  let stateRaw = readNonEmptyString(dict["state"]),
                  let state = EpdocSuggestionResolutionState(rawValue: stateRaw) else {
                return nil
            }
            return .suggestionResolved(
                EpdocSuggestionResolution(suggestionID: suggestionID, state: state)
            )
        default:
            return nil
        }
    }

    public static func decodeEpoch(messageBody: Any) -> Int? {
        guard let dict = messageBody as? [String: Any],
              let value = readIntegralInteger(dict["epoch"]),
              value >= 0 else {
            return nil
        }
        return value
    }

    public static func decodeEnvelope(messageBody: Any) -> [(message: EpdocBridgeMessage, epoch: Int?)] {
        if let dict = messageBody as? [String: Any],
           (dict["type"] as? String) == "batch",
           let messages = dict["messages"] as? [Any] {
            return messages.flatMap { decodeEnvelope(messageBody: $0) }
        }
        guard let decoded = decode(messageBody: messageBody) else {
            return []
        }
        return [(message: decoded, epoch: decodeEpoch(messageBody: messageBody))]
    }

    /// Decode a `{x, y, w, h}` rect payload into `EpdocBridgeRect`.
    /// Accepts numbers as either `Double` or `Int` (JS doesn't
    /// distinguish; the WKScriptMessage converter sometimes hands
    /// integer-valued numbers as NSNumber-Int).
    private static func parseRect(_ raw: Any?) -> EpdocBridgeRect? {
        guard let dict = raw as? [String: Any],
              let x = readNumber(dict["x"]),
              let y = readNumber(dict["y"]),
              let w = readNumber(dict["w"]),
              let h = readNumber(dict["h"]) else {
            return nil
        }
        return EpdocBridgeRect(x: x, y: y, width: w, height: h)
    }

    /// Decode a `{from, to, empty, text?}` selection payload.
    private static func parseSelection(_ raw: Any?) -> EpdocBridgeSelection? {
        guard let dict = raw as? [String: Any],
              let fromN = readNumber(dict["from"]),
              let toN = readNumber(dict["to"]),
              let isEmpty = dict["empty"] as? Bool else {
            return nil
        }
        let selectedText: String?
        if let rawText = dict["text"], !(rawText is NSNull) {
            guard let text = rawText as? String,
                  text.count <= EpdocBridgeSelection.maxSelectedTextCharacters + 3 else {
                return nil
            }
            selectedText = text
        } else {
            selectedText = nil
        }
        return EpdocBridgeSelection(
            from: Int(fromN),
            to: Int(toN),
            isEmpty: isEmpty,
            selectedText: selectedText
        )
    }

    /// Decode the optional active-mark payload. Missing marks are
    /// treated as inactive so older cached bundles can still mount,
    /// but malformed provided values fail closed.
    private static func parseActiveMarks(_ raw: Any?) -> EpdocBridgeActiveMarks? {
        guard let raw else { return .inactive }
        guard let dict = raw as? [String: Any] else { return nil }
        guard let bold = readBool(dict["bold"]),
              let italic = readBool(dict["italic"]),
              let strike = readBool(dict["strike"]),
              let code = readBool(dict["code"]),
              let highlight = readBool(dict["highlight"]) else {
            return nil
        }
        let heading: Int?
        if let rawHeading = dict["heading"], !(rawHeading is NSNull) {
            guard let value = readIntegralInteger(rawHeading), (1...6).contains(value) else {
                return nil
            }
            heading = value
        } else {
            heading = nil
        }
        return EpdocBridgeActiveMarks(
            isBoldActive: bold,
            isItalicActive: italic,
            isStrikeActive: strike,
            isCodeActive: code,
            isHighlightActive: highlight,
            activeHeadingLevel: heading
        )
    }

    private static func parseWritebackRegion(_ raw: Any?) -> EpdocMarkdownWritebackRegion? {
        guard let raw else { return nil }
        guard let dict = raw as? [String: Any],
              let byteFrom = readIntegralInteger(dict["byteFrom"] ?? dict["from"]),
              let byteTo = readIntegralInteger(dict["byteTo"] ?? dict["to"]),
              let codeUnitFrom = readIntegralInteger(dict["codeUnitFrom"]),
              let codeUnitTo = readIntegralInteger(dict["codeUnitTo"]),
              let changedFrom = readIntegralInteger(dict["changedFrom"]),
              let changedTo = readIntegralInteger(dict["changedTo"]),
              let blockIndexFrom = readIntegralInteger(dict["blockIndexFrom"]),
              let blockIndexTo = readIntegralInteger(dict["blockIndexTo"]),
              let blockMarkdown = dict["blockMarkdown"] as? String,
              byteFrom >= 0,
              byteTo >= byteFrom,
              codeUnitFrom >= 0,
              codeUnitTo >= codeUnitFrom,
              changedFrom >= 0,
              changedTo >= changedFrom,
              blockIndexFrom >= 0,
              blockIndexTo >= blockIndexFrom else {
            return nil
        }
        return EpdocMarkdownWritebackRegion(
            byteFrom: byteFrom,
            byteTo: byteTo,
            codeUnitFrom: codeUnitFrom,
            codeUnitTo: codeUnitTo,
            changedFrom: changedFrom,
            changedTo: changedTo,
            blockIndexFrom: blockIndexFrom,
            blockIndexTo: blockIndexTo,
            blockMarkdown: blockMarkdown
        )
    }

    private static func parseSuggestionSpanPayload(_ dict: [String: Any]) -> EpdocSuggestionSpanPayload? {
        guard let id = readNonEmptyString(dict["id"]),
              let author = readNonEmptyString(dict["author"]),
              let turnID = readNonEmptyString(dict["turnId"]),
              let kind = readNonEmptyString(dict["kind"]),
              let from = readIntegralInteger(dict["from"]),
              let to = readIntegralInteger(dict["to"]),
              let mapVersion = readIntegralInteger(dict["mapVersion"]),
              let before = dict["before"] as? String,
              let after = dict["after"] as? String,
              from >= 0,
              to >= from,
              mapVersion >= 0 else {
            return nil
        }
        return EpdocSuggestionSpanPayload(
            id: id,
            author: author,
            turnID: turnID,
            kind: kind,
            from: from,
            to: to,
            mapVersion: mapVersion,
            before: before,
            after: after,
            rationale: dict["rationale"] as? String,
            sourceCitation: dict["sourceCitation"] as? String,
            claimID: dict["claimId"] as? String
        )
    }

    private static func readNumber(_ raw: Any?) -> Double? {
        guard let raw, !isBridgeBoolean(raw) else { return nil }
        if let d = raw as? Double { return d }
        if let i = raw as? Int { return Double(i) }
        if let n = raw as? NSNumber { return n.doubleValue }
        return nil
    }

    private static func readInteger(_ raw: Any?) -> Int? {
        guard let value = readNumber(raw), value.isFinite else { return nil }
        return Int(value)
    }

    private static func readIntegralInteger(_ raw: Any?) -> Int? {
        guard let value = readNumber(raw),
              value.isFinite else {
            return nil
        }
        let intValue = Int(value)
        return Double(intValue) == value ? intValue : nil
    }

    private static func readBool(_ raw: Any?) -> Bool? {
        guard let raw, isBridgeBoolean(raw) else {
            return nil
        }
        return (raw as? Bool) ?? (raw as? NSNumber)?.boolValue
    }

    private static func isBridgeBoolean(_ raw: Any) -> Bool {
        if Swift.type(of: raw) == Bool.self {
            return true
        }
        guard let number = raw as? NSNumber else {
            return false
        }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func readNonEmptyString(_ raw: Any?) -> String? {
        guard let string = raw as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Swift → JS commands. Encoded into a JS expression evaluated via
/// `WKWebView.evaluateJavaScript`. Single-source-of-truth for the
/// command vocabulary so the JS handler can be regenerated when the
/// shape changes.
nonisolated public enum EpdocEditorCommand: Sendable, Hashable {
    /// Replace the editor's content with the given ProseMirror JSON.
    /// Used when swapping documents in the singleton WKWebView.
    case setContent(json: Data)
    /// Epoch-stamped host load. This is the LUMENLENS load-vs-edit
    /// path; the JS side stamps the underlying ProseMirror transaction
    /// and emits only matching-epoch update events.
    case setContentForLoad(json: Data, epoch: Int)
    /// Replace the editor's content from Markdown via the JS serializer.
    /// Reserved for the L1 source-of-truth flip; loader semantics match
    /// setContent and do not imply a native save by themselves.
    case setMarkdown(markdown: String)
    /// Epoch-stamped Markdown host load.
    case setMarkdownForLoad(markdown: String, epoch: Int)
    /// Replace only the first level-one heading for a clean host-owned title
    /// change. The JS transaction preserves the live editor tree, selection,
    /// viewport, and undo history while advancing the load epoch.
    case replaceDocumentTitle(title: String, epoch: Int)
    /// Ask JS to synchronously emit the current JSON + Markdown snapshots.
    /// Used before host-side saves, lens switches, and teardown so the
    /// Swift save path does not depend on the editor's debounce timer.
    case flushDocumentSnapshot
    /// Move the cursor to the start of the document. Used after a
    /// setContent to restore canonical focus state.
    case focusStart
    /// Move the cursor to the end of the document.
    case focusEnd
    /// W7.17.b — dismiss the slash menu Suggestion plugin (e.g. user
    /// hit Escape on the SwiftUI picker side).
    case dismissSlashMenu
    /// W7.17.b — user picked a slash-menu item; the JS Suggestion
    /// plugin reads this dispatch + runs the matching Tiptap command.
    /// `blockType` mirrors `SlashMenuItem.id` from
    /// `js-editor/src/extensions/slash-menu.ts`.
    case insertSlashChoice(blockType: String)
    /// W7.17.b — collapse the selection to dismiss the bubble menu.
    case dismissBubbleMenu
    /// W7.17.b — generic Tiptap command dispatch. The JS inbound
    /// shim looks `name` up in `editor.commands` + invokes with `args`.
    /// Args are JSON-encoded; receiver decodes and spreads.
    case runCommand(name: String, argsJSON: Data)
    /// L2 note-width control. Sets the editor content max-width CSS
    /// variable without mutating document content.
    case setContentWidth(mode: NoteWidthMode)
    /// Native Find/Replace panel support. These commands update
    /// ProseMirror decorations and selection only; they do not mutate
    /// document content except for replaceCurrent/replaceAll.
    case setFindQuery(query: String, caseSensitive: Bool)
    case findNext(query: String, caseSensitive: Bool)
    case findPrevious(query: String, caseSensitive: Bool)
    case replaceCurrent(query: String, replacement: String, caseSensitive: Bool)
    case replaceAll(query: String, replacement: String, caseSensitive: Bool)
    case clearFindHighlights
    /// LumenLens tracked suggestions. These stage one bounded span through the
    /// JS SuggestionAdapter and keep accept/reject as explicit user actions.
    case applySuggestion(payload: EpdocSuggestionSpanPayload)
    case acceptSuggestion(id: String)
    case rejectSuggestion(id: String)

    /// JS expression that the bridge evaluates inside the WKWebView.
    /// Assumes `window.epdocEditor` is the Tiptap editor instance the
    /// JS side exposes globally for the bridge + that
    /// `window.epistemos.*` is the namespaced command surface
    /// `js-editor/src/bridge/inbound.ts` installs.
    public func javaScriptExpression() -> String {
        switch self {
        case .setContent(let json):
            let escaped = String(data: json, encoding: .utf8) ?? "{}"
            // Stringify so window.epistemos.setContent(jsonString)
            // matches the inbound bridge shape.
            let asLiteral = jsStringLiteral(escaped)
            return "window.epistemos.setContent(\(asLiteral))"
        case .setContentForLoad(let json, let epoch):
            let escaped = String(data: json, encoding: .utf8) ?? "{}"
            let asLiteral = jsStringLiteral(escaped)
            return "window.epistemos.setContent(\(asLiteral), \(max(0, epoch)))"
        case .setMarkdown(let markdown):
            return "window.epistemos.setMarkdown(\(jsStringLiteral(markdown)))"
        case .setMarkdownForLoad(let markdown, let epoch):
            return "window.epistemos.setMarkdown(\(jsStringLiteral(markdown)), \(max(0, epoch)))"
        case .replaceDocumentTitle(let title, let epoch):
            return "window.epistemos.replaceDocumentTitle(\(jsStringLiteral(title)), \(max(0, epoch)))"
        case .flushDocumentSnapshot:
            return "window.epistemos.flushDocumentSnapshot()"
        case .focusStart:
            return "window.epistemos.focusStart()"
        case .focusEnd:
            return "window.epistemos.focusEnd()"
        case .dismissSlashMenu:
            return "window.epistemos.dismissSlashMenu()"
        case .insertSlashChoice(let blockType):
            return "window.epistemos.insertSlashChoice(\(jsStringLiteral(blockType)))"
        case .dismissBubbleMenu:
            return "window.epistemos.dismissBubbleMenu()"
        case .runCommand(let name, let argsJSON):
            // argsJSON is a JSON array spliced (spread) directly into the JS
            // expression, so it can't go through jsStringLiteral. Escape U+2028/U+2029
            // — JSON-legal inside string values but JS line terminators that would
            // break the expression parse (one-command DoS) — to their \u escapes,
            // which are valid in both JSON and JS (bridge audit 2026-07-03, LOW).
            let argsLiteral = (String(data: argsJSON, encoding: .utf8) ?? "[]")
                .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
                .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
            // window.epistemos.runCommand(name, ...args)
            return "window.epistemos.runCommand(\(jsStringLiteral(name)), ...\(argsLiteral))"
        case .setContentWidth(let mode):
            return "window.epistemos.setContentWidth(\(jsStringLiteral(mode.cssMaxWidthValue)))"
        case .setFindQuery(let query, let caseSensitive):
            return "window.epistemos.setFindQuery(\(jsStringLiteral(query)), \(caseSensitive))"
        case .findNext(let query, let caseSensitive):
            return "window.epistemos.findNext(\(jsStringLiteral(query)), \(caseSensitive))"
        case .findPrevious(let query, let caseSensitive):
            return "window.epistemos.findPrevious(\(jsStringLiteral(query)), \(caseSensitive))"
        case .replaceCurrent(let query, let replacement, let caseSensitive):
            return "window.epistemos.replaceCurrent(\(jsStringLiteral(query)), \(jsStringLiteral(replacement)), \(caseSensitive))"
        case .replaceAll(let query, let replacement, let caseSensitive):
            return "window.epistemos.replaceAll(\(jsStringLiteral(query)), \(jsStringLiteral(replacement)), \(caseSensitive))"
        case .clearFindHighlights:
            return "window.epistemos.clearFindHighlights()"
        case .applySuggestion(let payload):
            return "window.epistemos.runCommand(\"applySuggestion\", ...[\(Self.suggestionSpanPayloadLiteral(payload))])"
        case .acceptSuggestion(let id):
            return "window.epistemos.runCommand(\"acceptSuggestion\", ...[\(jsStringLiteral(id))])"
        case .rejectSuggestion(let id):
            return "window.epistemos.runCommand(\"rejectSuggestion\", ...[\(jsStringLiteral(id))])"
        }
    }

    private static func suggestionSpanPayloadLiteral(_ payload: EpdocSuggestionSpanPayload) -> String {
        var fields: [String] = [
            "\"id\":\(jsStringLiteral(payload.id))",
            "\"author\":\(jsStringLiteral(payload.author))",
            "\"turnId\":\(jsStringLiteral(payload.turnID))",
            "\"kind\":\(jsStringLiteral(payload.kind))",
            "\"from\":\(payload.from)",
            "\"to\":\(payload.to)",
            "\"mapVersion\":\(payload.mapVersion)",
            "\"before\":\(jsStringLiteral(payload.before))",
            "\"after\":\(jsStringLiteral(payload.after))",
        ]
        if let rationale = payload.rationale, !rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields.append("\"rationale\":\(jsStringLiteral(rationale))")
        }
        if let sourceCitation = payload.sourceCitation, !sourceCitation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields.append("\"sourceCitation\":\(jsStringLiteral(sourceCitation))")
        }
        if let claimID = payload.claimID, !claimID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields.append("\"claimId\":\(jsStringLiteral(claimID))")
        }
        return "{\(fields.joined(separator: ","))}"
    }
}

/// Escape a string for safe interpolation as a JS string literal.
/// Wraps in double quotes + escapes backslash, quote, newline, tab,
/// and the U+2028/U+2029 line/paragraph separators (which JS treats
/// as line terminators inside string literals — easy to miss).
nonisolated public func jsStringLiteral(_ s: String) -> String {
    var out = "\""
    out.reserveCapacity(s.count + 2)
    for c in s {
        switch c {
        case "\\": out.append("\\\\")
        case "\"": out.append("\\\"")
        case "\n": out.append("\\n")
        case "\r": out.append("\\r")
        case "\t": out.append("\\t")
        case "\u{2028}": out.append("\\u2028")
        case "\u{2029}": out.append("\\u2029")
        default:   out.append(c)
        }
    }
    out.append("\"")
    return out
}

// MARK: - Save pipeline

/// Combine-based debouncer that turns a stream of `contentDidChange`
/// messages into one save call per quiet window.
///
/// Per the Wave 7.2 research finding: 300ms is the canonical save cadence,
/// and the debounce MUST live on the Swift side (JS-side debounce loses
/// events on tab switch + complicates the canonical-save invariant).
@MainActor
public final class EpdocEditorSavePipeline {
    private let subject = PassthroughSubject<Data, Never>()
    private var subscription: AnyCancellable?
    // RCA13 perf+persistence: hold the most-recent enqueued JSON so a
    // synchronous flush can drain the in-flight debounce window. Without
    // this, an app quit / window close during the 300ms quiet period
    // dropped the last keystroke even though NSDocument was marked dirty.
    private var pendingJson: Data?
    private let save: @MainActor @Sendable (Data) -> Void

    public init(
        debounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(300),
        save: @escaping @MainActor @Sendable (Data) -> Void
    ) {
        self.save = save
        subscription = subject
            .debounce(for: debounce, scheduler: DispatchQueue.main)
            .sink { [weak self] json in
                MainActor.assumeIsolated {
                    save(json)
                    self?.pendingJson = nil
                }
            }
        Self.register(self)
    }

    /// Push a content change. The pipeline coalesces back-to-back
    /// updates within the debounce window into one save.
    public func enqueue(json: Data) {
        pendingJson = json
        subject.send(json)
    }

    /// Drain any in-flight debounce window. Safe to call when no save
    /// is pending — becomes a no-op. Used by `performTeardown()` so
    /// app quit can't drop the last keystroke.
    public func flushNow() {
        guard let json = pendingJson else { return }
        pendingJson = nil
        save(json)
    }

    // No deinit cancel needed: AnyCancellable cancels itself on
    // deinit. Adding a manual cancel() call here under Swift 6
    // strict concurrency triggers a "non-Sendable from nonisolated
    // deinit" error and isn't necessary for correctness.

    // MARK: - Shutdown drain registry

    private static var activeInstances: [Weak] = []

    private struct Weak {
        weak var pipeline: EpdocEditorSavePipeline?
    }

    private static func register(_ pipeline: EpdocEditorSavePipeline) {
        activeInstances.removeAll { $0.pipeline == nil }
        activeInstances.append(Weak(pipeline: pipeline))
    }

    /// Flush every live pipeline. Call from `applicationShouldTerminate`
    /// / `applicationWillTerminate` so the last keystroke in any open
    /// .epdoc editor is on disk before the process exits.
    public static func flushAllForShutdown() {
        for slot in activeInstances {
            slot.pipeline?.flushNow()
        }
    }
}

// MARK: - Errors

nonisolated public enum EpdocBridgeError: Error, CustomStringConvertible {
    case invalidURL
    case assetNotFound(path: String)
    case bridgeMessageMalformed

    public var description: String {
        switch self {
        case .invalidURL:                        return "EpdocBridge: invalid URL on URLSchemeTask"
        case .assetNotFound(let path):           return "EpdocBridge: asset not found in bundle: \(path)"
        case .bridgeMessageMalformed:            return "EpdocBridge: malformed JS bridge message"
        }
    }
}
