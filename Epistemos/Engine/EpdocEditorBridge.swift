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

nonisolated enum EpdocEditorAssetResolver {
    static let documentAssetPrefix = "assets/"

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
        default:                return "application/octet-stream"
        }
    }

    static func bundleFont(named name: String, extension ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext)
            ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Fonts")
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
        } catch EpdocBridgeError.assetNotFound where url.path == "/CoralPixels-Regular.ttf" {
            guard let fontURL = EpdocEditorAssetResolver.bundleFont(named: "CoralPixels-Regular", extension: "ttf") else {
                urlSchemeTask.didFailWithError(EpdocBridgeError.assetNotFound(path: url.path))
                return
            }
            asset = EpdocEditorAssetResponse(
                fileURL: fontURL,
                mimeType: "font/ttf",
                contentEncoding: nil
            )
        } catch EpdocBridgeError.assetNotFound where url.path == "/RetroGaming.ttf" {
            guard let fontURL = EpdocEditorAssetResolver.bundleFont(named: "RetroGaming", extension: "ttf") else {
                urlSchemeTask.didFailWithError(EpdocBridgeError.assetNotFound(path: url.path))
                return
            }
            asset = EpdocEditorAssetResponse(
                fileURL: fontURL,
                mimeType: "font/ttf",
                contentEncoding: nil
            )
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
    public let from: Int
    public let to: Int
    public let isEmpty: Bool

    public init(from: Int, to: Int, isEmpty: Bool) {
        self.from = from
        self.to = to
        self.isEmpty = isEmpty
    }
}

// MARK: - Tri-Fusion mutation receiver

nonisolated public enum EpdocTriFusionMutationKind: String, CaseIterable, Sendable, Hashable {
    case insertBlock = "insert_block"
    case mutateBlock = "mutate_block"
    case linkBlock = "link_block"
    case transcludeBlock = "transclude_block"
}

nonisolated public struct EpdocTriFusionMutationDescriptor: Sendable, Hashable {
    public let mutationID: String
    public let documentID: String
    public let baseDocumentHash: String
    public let sourceFormat: String
    public let kind: EpdocTriFusionMutationKind
    public let actorKind: String

    public var isModelAuthored: Bool {
        actorKind == "agent"
    }

    public init(
        mutationID: String,
        documentID: String,
        baseDocumentHash: String,
        sourceFormat: String,
        kind: EpdocTriFusionMutationKind,
        actorKind: String = "user"
    ) {
        self.mutationID = mutationID
        self.documentID = documentID
        self.baseDocumentHash = baseDocumentHash
        self.sourceFormat = sourceFormat
        self.kind = kind
        self.actorKind = actorKind
    }
}

nonisolated public enum EpdocTriFusionMutationReceiver {
    private static let commonFields: Set<String> = [
        "mutation_id",
        "document_id",
        "base_document_hash",
        "actor",
        "source_format",
        "rationale",
        "kind",
    ]
    private static let sourceFormats: Set<String> = ["json", "markdown", "html"]

    public static func command(forEnvelopeJSON envelopeJSON: Data) throws -> EpdocEditorCommand {
        _ = try descriptor(forEnvelopeJSON: envelopeJSON)
        return .applyTriFusionMutation(envelopeJSON: envelopeJSON)
    }

    public static func descriptor(forEnvelopeJSON envelopeJSON: Data) throws -> EpdocTriFusionMutationDescriptor {
        let object = try jsonObject(from: envelopeJSON)
        let kindString = try readNonEmptyString(object["kind"], field: "kind")
        guard let kind = EpdocTriFusionMutationKind(rawValue: kindString) else {
            throw EpdocBridgeError.triFusionMutationMalformed(reason: "unknown mutation kind: \(kindString)")
        }

        try rejectUnexpectedFields(in: object, allowedFields: allowedFields(for: kind))
        let actorKind = try validateActor(object["actor"])
        try validateMutationPayload(object, kind: kind)
        _ = try readNonEmptyString(object["rationale"], field: "rationale")

        let sourceFormat = try readNonEmptyString(object["source_format"], field: "source_format")
        guard sourceFormats.contains(sourceFormat) else {
            throw EpdocBridgeError.triFusionMutationMalformed(reason: "unknown source_format: \(sourceFormat)")
        }

        let baseDocumentHash = try readNonEmptyString(
            object["base_document_hash"],
            field: "base_document_hash"
        )
        guard isLowercaseHexHash(baseDocumentHash) else {
            throw EpdocBridgeError.triFusionMutationMalformed(
                reason: "base_document_hash must be 64 lowercase hex characters"
            )
        }

        return EpdocTriFusionMutationDescriptor(
            mutationID: try readNonEmptyString(object["mutation_id"], field: "mutation_id"),
            documentID: try readNonEmptyString(object["document_id"], field: "document_id"),
            baseDocumentHash: baseDocumentHash,
            sourceFormat: sourceFormat,
            kind: kind,
            actorKind: actorKind
        )
    }

    private static func allowedFields(for kind: EpdocTriFusionMutationKind) -> Set<String> {
        switch kind {
        case .insertBlock:
            return commonFields.union(["artifact_id", "after_block_id", "block"])
        case .mutateBlock:
            return commonFields.union(["artifact_id", "block_id", "replacement"])
        case .linkBlock:
            return commonFields.union(["artifact_id", "from_block_id", "to_block_id", "relation"])
        case .transcludeBlock:
            return commonFields.union([
                "artifact_id",
                "after_block_id",
                "source_block_id",
                "transclusion_block_id",
            ])
        }
    }

    private static func jsonObject(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EpdocBridgeError.triFusionMutationMalformed(reason: "envelope must be a JSON object")
        }
        return object
    }

    private static func rejectUnexpectedFields(
        in object: [String: Any],
        allowedFields: Set<String>
    ) throws {
        let unexpected = Set(object.keys).subtracting(allowedFields)
        guard unexpected.isEmpty else {
            let fields = unexpected.sorted().joined(separator: ",")
            throw EpdocBridgeError.triFusionMutationMalformed(
                reason: "unexpected field: \(fields)"
            )
        }
    }

    private static func validateActor(_ raw: Any?) throws -> String {
        guard let actor = raw as? [String: Any] else {
            throw EpdocBridgeError.triFusionMutationMalformed(reason: "actor must be an object")
        }
        let kind = try readNonEmptyString(actor["kind"], field: "actor.kind")
        switch kind {
        case "user", "system":
            guard Set(actor.keys) == ["kind"] else {
                throw EpdocBridgeError.triFusionMutationMalformed(
                    reason: "\(kind) actor must not include run_id"
                )
            }
            return kind
        case "agent":
            guard Set(actor.keys) == ["kind", "run_id"] else {
                throw EpdocBridgeError.triFusionMutationMalformed(
                    reason: "agent actor requires exactly kind and run_id"
                )
            }
            _ = try readNonEmptyString(actor["run_id"], field: "actor.run_id")
            return kind
        default:
            throw EpdocBridgeError.triFusionMutationMalformed(reason: "unknown actor kind: \(kind)")
        }
    }

    private static func validateMutationPayload(
        _ object: [String: Any],
        kind: EpdocTriFusionMutationKind
    ) throws {
        _ = try readNonEmptyString(object["artifact_id"], field: "artifact_id")
        switch kind {
        case .insertBlock:
            try validateOptionalBlockID(object["after_block_id"], field: "after_block_id")
            try requireJSONObject(object["block"], field: "block")
        case .mutateBlock:
            _ = try readNonEmptyString(object["block_id"], field: "block_id")
            try requireJSONObject(object["replacement"], field: "replacement")
        case .linkBlock:
            _ = try readNonEmptyString(object["from_block_id"], field: "from_block_id")
            _ = try readNonEmptyString(object["to_block_id"], field: "to_block_id")
            _ = try readNonEmptyString(object["relation"], field: "relation")
        case .transcludeBlock:
            try validateOptionalBlockID(object["after_block_id"], field: "after_block_id")
            _ = try readNonEmptyString(object["source_block_id"], field: "source_block_id")
            _ = try readNonEmptyString(object["transclusion_block_id"], field: "transclusion_block_id")
        }
    }

    private static func validateOptionalBlockID(_ raw: Any?, field: String) throws {
        guard let raw, !(raw is NSNull) else { return }
        _ = try readNonEmptyString(raw, field: field)
    }

    private static func requireJSONObject(_ raw: Any?, field: String) throws {
        guard raw is [String: Any] else {
            throw EpdocBridgeError.triFusionMutationMalformed(reason: "\(field) must be a JSON object")
        }
    }

    private static func readNonEmptyString(_ raw: Any?, field: String) throws -> String {
        guard let string = raw as? String else {
            throw EpdocBridgeError.triFusionMutationMalformed(reason: "\(field) must be a string")
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EpdocBridgeError.triFusionMutationMalformed(reason: "\(field) must be non-empty")
        }
        return string
    }

    private static func isLowercaseHexHash(_ value: String) -> Bool {
        guard value.count == 64 else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            (48...57).contains(scalar.value) || (97...102).contains(scalar.value)
        }
    }
}

/// JS → Swift messages over the WKScriptMessageHandler bridge. The JS
/// side posts these via `window.webkit.messageHandlers.epdoc.postMessage(...)`.
nonisolated public enum EpdocBridgeMessage: Sendable, Hashable {
    /// The editor produced a new ProseMirror JSON snapshot. Posted on
    /// every editor transaction by the JS side; debounced before save.
    case contentDidChange(json: Data)
    /// JS-side CharacterCount update. Posted on create, setContent,
    /// and content-changing commands so the native chrome/footer does
    /// not display stale placeholder counts.
    case documentStatsChanged(wordCount: Int, characterCount: Int)
    /// The editor finished its initial mount and is ready to receive
    /// `editor.commands.setContent(...)`.
    case editorReady
    /// JS-side raised an unrecoverable error (parse failure, etc.).
    case error(message: String)
    /// W7.17 — caret position + selection state. Emitted on every
    /// transaction so the SwiftUI chrome (W7.17.a) can dock its
    /// floating panels next to the live document area.
    case caretChanged(rect: EpdocBridgeRect, selection: EpdocBridgeSelection)
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

    /// Decode a raw `WKScriptMessage.body` value into a typed message.
    /// Returns `nil` on shape failure. Accepted shapes:
    ///
    ///   `{"type": "contentDidChange", "json": "<stringified-prosemirror-json>"}`
    ///   `{"type": "documentStatsChanged", "wordCount": 10, "characterCount": 80}`
    ///   `{"type": "editorReady"}`
    ///   `{"type": "error", "message": "..."}`
    ///   `{"type": "caretChanged", "rect": {x,y,w,h}, "selection": {from,to,empty}}`
    ///   `{"type": "requestSlashMenu", "query": "...", "anchor": {x,y,w,h}}`
    ///   `{"type": "requestBubbleMenu", "selection": {from,to,empty}, "anchor": {x,y,w,h}}`
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
        case "documentStatsChanged":
            guard let wordCount = readInteger(dict["wordCount"]),
                  let characterCount = readInteger(dict["characterCount"]) else {
                return nil
            }
            return .documentStatsChanged(wordCount: wordCount, characterCount: characterCount)
        case "editorReady":
            return .editorReady
        case "error":
            guard let msg = dict["message"] as? String else { return nil }
            return .error(message: msg)
        case "caretChanged":
            guard let rect = parseRect(dict["rect"]),
                  let selection = parseSelection(dict["selection"]) else {
                return nil
            }
            return .caretChanged(rect: rect, selection: selection)
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
        default:
            return nil
        }
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

    /// Decode a `{from, to, empty}` selection payload.
    private static func parseSelection(_ raw: Any?) -> EpdocBridgeSelection? {
        guard let dict = raw as? [String: Any],
              let fromN = readNumber(dict["from"]),
              let toN = readNumber(dict["to"]),
              let isEmpty = dict["empty"] as? Bool else {
            return nil
        }
        return EpdocBridgeSelection(from: Int(fromN), to: Int(toN), isEmpty: isEmpty)
    }

    private static func readNumber(_ raw: Any?) -> Double? {
        if let d = raw as? Double { return d }
        if let i = raw as? Int { return Double(i) }
        if let n = raw as? NSNumber { return n.doubleValue }
        return nil
    }

    private static func readInteger(_ raw: Any?) -> Int? {
        guard let value = readNumber(raw), value.isFinite else { return nil }
        return Int(value)
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
    /// T1 Tri-Fusion — forward one validated structured mutation envelope
    /// to the editor receiver without replacing the full document body.
    case applyTriFusionMutation(envelopeJSON: Data)
    /// W7.17.b — collapse the selection to dismiss the bubble menu.
    case dismissBubbleMenu
    /// W7.17.b — generic Tiptap command dispatch. The JS inbound
    /// shim looks `name` up in `editor.commands` + invokes with `args`.
    /// Args are JSON-encoded; receiver decodes and spreads.
    case runCommand(name: String, argsJSON: Data)

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
        case .focusStart:
            return "window.epistemos.focusStart()"
        case .focusEnd:
            return "window.epistemos.focusEnd()"
        case .dismissSlashMenu:
            return "window.epistemos.dismissSlashMenu()"
        case .insertSlashChoice(let blockType):
            return "window.epistemos.insertSlashChoice(\(jsStringLiteral(blockType)))"
        case .applyTriFusionMutation(let envelopeJSON):
            let escaped = String(data: envelopeJSON, encoding: .utf8) ?? "{}"
            return Self.triFusionMutationJavaScriptExpression(envelopeJSON: escaped)
        case .dismissBubbleMenu:
            return "window.epistemos.dismissBubbleMenu()"
        case .runCommand(let name, let argsJSON):
            let argsLiteral = String(data: argsJSON, encoding: .utf8) ?? "[]"
            // window.epistemos.runCommand(name, ...args)
            return "window.epistemos.runCommand(\(jsStringLiteral(name)), ...\(argsLiteral))"
        }
    }

    private static func triFusionMutationJavaScriptExpression(envelopeJSON: String) -> String {
        let envelopeLiteral = jsStringLiteral(envelopeJSON)
        return """
        (() => {
          const envelopeJSON = \(envelopeLiteral);
          try {
            const envelope = JSON.parse(envelopeJSON);
            const editor = window.epdocEditor;
            const epistemos = window.epistemos || {};

            const cssEscape = (value) => {
              if (window.CSS && typeof window.CSS.escape === 'function') {
                return window.CSS.escape(value);
              }
              return String(value).replace(/[^a-zA-Z0-9_-]/g, '\\\\$&');
            };

            const touchedBlockIDs = (mutation) => {
              switch (mutation.kind) {
              case 'insert_block':
                return [blockIdentity(mutation.block)].filter(Boolean);
              case 'mutate_block':
                return [mutation.block_id].filter(Boolean);
              case 'link_block':
                return [mutation.from_block_id, mutation.to_block_id].filter(Boolean);
              case 'transclude_block':
                return [mutation.source_block_id, mutation.transclusion_block_id].filter(Boolean);
              default:
                return [];
              }
            };

            const installMarkerStyle = () => {
              const styleID = 'epdoc-tri-fusion-model-authored-style';
              if (document.getElementById(styleID)) return;
              const style = document.createElement('style');
              style.id = styleID;
              style.textContent = [
                '.epdoc-model-authored-block {',
                '  outline: 2px solid rgba(37, 99, 235, 0.72);',
                '  outline-offset: 3px;',
                '  background: rgba(37, 99, 235, 0.08);',
                '  border-radius: 4px;',
                '}',
                '.epdoc-model-authored-block::selection {',
                '  background: rgba(37, 99, 235, 0.24);',
                '}',
              ].join('\\n');
              document.head.appendChild(style);
            };

            const isModelAuthoredMutation = () => envelope
              && envelope.actor
              && envelope.actor.kind === 'agent';

            const markTouchedBlocks = () => {
              if (!isModelAuthoredMutation()) return;
              installMarkerStyle();
              for (const blockID of touchedBlockIDs(envelope)) {
                const escaped = cssEscape(blockID);
                const candidates = document.querySelectorAll([
                  `#${escaped}`,
                  `[data-block-id="${escaped}"]`,
                  `[data-epdoc-block-id="${escaped}"]`,
                ].join(','));
                for (const element of candidates) {
                  element.classList.add('epdoc-model-authored-block');
                  element.setAttribute('data-epdoc-model-authored', envelope.mutation_id || '');
                  element.setAttribute('data-epdoc-author-kind', 'model');
                }
              }
            };

            const blockIdentity = (node) => {
              const attrs = node && typeof node === 'object' ? node.attrs : null;
              if (!attrs || typeof attrs !== 'object') return null;
              return typeof attrs.id === 'string' && attrs.id.length > 0
                ? attrs.id
                : (typeof attrs.block_id === 'string' && attrs.block_id.length > 0 ? attrs.block_id : null);
            };

            const rootContent = (root) => Array.isArray(root && root.content) ? root.content : null;

            const findSlot = (content, blockID) => {
              if (!Array.isArray(content)) return null;
              for (let index = 0; index < content.length; index += 1) {
                const node = content[index];
                if (blockIdentity(node) === blockID) {
                  return { content, index, node };
                }
                const nested = findSlot(node && node.content, blockID);
                if (nested) return nested;
              }
              return null;
            };

            const rejectDuplicate = (root, blockID) => {
              if (typeof blockID !== 'string' || blockID.length === 0) return false;
              return findSlot(rootContent(root), blockID) === null;
            };

            const insertAfter = (root, afterBlockID, block) => {
              const content = rootContent(root);
              if (!content || !block) return false;
              const insertedID = blockIdentity(block);
              if (!rejectDuplicate(root, insertedID)) return false;
              if (afterBlockID === null || afterBlockID === undefined) {
                content.push(block);
                return true;
              }
              const slot = findSlot(content, afterBlockID);
              if (!slot) return false;
              slot.content.splice(slot.index + 1, 0, block);
              return true;
            };

            const replaceBlock = (root, blockID, replacement) => {
              const content = rootContent(root);
              if (!content || !replacement || blockIdentity(replacement) !== blockID) return false;
              const slot = findSlot(content, blockID);
              if (!slot) return false;
              slot.content[slot.index] = replacement;
              return true;
            };

            const linkBlocks = (root, fromBlockID, toBlockID, relation) => {
              const content = rootContent(root);
              const source = findSlot(content, fromBlockID);
              const target = findSlot(content, toBlockID);
              if (!source || !target || typeof relation !== 'string' || relation.trim().length === 0) {
                return false;
              }
              const attrs = source.node.attrs && typeof source.node.attrs === 'object' ? source.node.attrs : {};
              const links = Array.isArray(attrs.links) ? attrs.links.slice() : [];
              const link = { relation, target_block_id: toBlockID };
              if (!links.some((existing) => existing
                && existing.relation === link.relation
                && existing.target_block_id === link.target_block_id)) {
                links.push(link);
                links.sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
              }
              source.node.attrs = { ...attrs, links };
              return true;
            };

            const transcludeBlock = (root, afterBlockID, sourceBlockID, transclusionBlockID) => {
              if (!findSlot(rootContent(root), sourceBlockID)) return false;
              return insertAfter(root, afterBlockID, {
                type: 'transclusion',
                attrs: {
                  id: transclusionBlockID,
                  source_block_id: sourceBlockID,
                },
              });
            };

            const applyAgainstEditorJSON = () => {
              if (!editor || typeof editor.getJSON !== 'function' || !editor.commands
                || typeof editor.commands.setContent !== 'function') {
                return false;
              }
              const next = JSON.parse(JSON.stringify(editor.getJSON()));
              let didApply = false;
              switch (envelope.kind) {
              case 'insert_block':
                didApply = insertAfter(next, envelope.after_block_id, envelope.block);
                break;
              case 'mutate_block':
                didApply = replaceBlock(next, envelope.block_id, envelope.replacement);
                break;
              case 'link_block':
                didApply = linkBlocks(next, envelope.from_block_id, envelope.to_block_id, envelope.relation);
                break;
              case 'transclude_block':
                didApply = transcludeBlock(
                  next,
                  envelope.after_block_id,
                  envelope.source_block_id,
                  envelope.transclusion_block_id
                );
                break;
              default:
                didApply = false;
              }
              if (!didApply) return false;
              editor.commands.setContent(next, { emitUpdate: true });
              return true;
            };

            const directApply = typeof epistemos.applyTriFusionMutation === 'function'
              ? epistemos.applyTriFusionMutation.bind(epistemos)
              : null;
            const didApply = directApply
              ? directApply(envelopeJSON) !== false
              : applyAgainstEditorJSON();
            requestAnimationFrame(markTouchedBlocks);
            return didApply;
          } catch (error) {
            console.warn('[epdoc inbound] applyTriFusionMutation failed', error);
            return false;
          }
        })()
        """
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
    case triFusionMutationMalformed(reason: String)

    public var description: String {
        switch self {
        case .invalidURL:                        return "EpdocBridge: invalid URL on URLSchemeTask"
        case .assetNotFound(let path):           return "EpdocBridge: asset not found in bundle: \(path)"
        case .bridgeMessageMalformed:            return "EpdocBridge: malformed JS bridge message"
        case .triFusionMutationMalformed(let reason):
            return "EpdocBridge: malformed Tri-Fusion mutation: \(reason)"
        }
    }
}
