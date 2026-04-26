import Combine
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

    public init(assetSubpath: String = "Editor") {
        self.assetSubpath = assetSubpath
    }

    public func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(EpdocBridgeError.invalidURL)
            return
        }
        // The path is e.g. `/editor.html`; strip the leading `/`.
        let relative = url.path.hasPrefix("/")
            ? String(url.path.dropFirst())
            : url.path
        guard !relative.isEmpty else {
            urlSchemeTask.didFailWithError(EpdocBridgeError.invalidURL)
            return
        }

        guard let assetURL = Bundle.main.resourceURL?
            .appendingPathComponent(assetSubpath, isDirectory: true)
            .appendingPathComponent(relative, isDirectory: false),
              let data = try? Data(contentsOf: assetURL) else {
            urlSchemeTask.didFailWithError(EpdocBridgeError.assetNotFound(path: relative))
            return
        }

        let mimeType = Self.mimeType(for: assetURL.pathExtension)
        let response = URLResponse(
            url: url,
            mimeType: mimeType,
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

    /// Minimal MIME-type table for the file extensions Tiptap actually
    /// emits. Falls back to `application/octet-stream` for unknown
    /// extensions; keeps the table small + auditable.
    private static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html":            return "text/html"
        case "js", "mjs":       return "text/javascript"
        case "css":             return "text/css"
        case "json":            return "application/json"
        case "wasm":            return "application/wasm"
        case "svg":             return "image/svg+xml"
        case "png":             return "image/png"
        case "jpg", "jpeg":     return "image/jpeg"
        case "woff", "woff2":   return "font/woff2"
        case "ttf":             return "font/ttf"
        default:                return "application/octet-stream"
        }
    }
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

/// JS → Swift messages over the WKScriptMessageHandler bridge. The JS
/// side posts these via `window.webkit.messageHandlers.epdoc.postMessage(...)`.
nonisolated public enum EpdocBridgeMessage: Sendable, Hashable {
    /// The editor produced a new ProseMirror JSON snapshot. Posted on
    /// every editor transaction by the JS side; debounced before save.
    case contentDidChange(json: Data)
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

    /// Decode a raw `WKScriptMessage.body` value into a typed message.
    /// Returns `nil` on shape failure. Accepted shapes:
    ///
    ///   `{"type": "contentDidChange", "json": "<stringified-prosemirror-json>"}`
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
        case .dismissBubbleMenu:
            return "window.epistemos.dismissBubbleMenu()"
        case .runCommand(let name, let argsJSON):
            let argsLiteral = String(data: argsJSON, encoding: .utf8) ?? "[]"
            // window.epistemos.runCommand(name, ...args)
            return "window.epistemos.runCommand(\(jsStringLiteral(name)), ...\(argsLiteral))"
        }
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

    public init(
        debounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(300),
        save: @escaping @MainActor @Sendable (Data) -> Void
    ) {
        subscription = subject
            .debounce(for: debounce, scheduler: DispatchQueue.main)
            .sink { json in
                MainActor.assumeIsolated {
                    save(json)
                }
            }
    }

    /// Push a content change. The pipeline coalesces back-to-back
    /// updates within the debounce window into one save.
    public func enqueue(json: Data) {
        subject.send(json)
    }

    // No deinit cancel needed: AnyCancellable cancels itself on
    // deinit. Adding a manual cancel() call here under Swift 6
    // strict concurrency triggers a "non-Sendable from nonisolated
    // deinit" error and isn't necessary for correctness.
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
