#if EPISTEMOS_APP_STORE
import Foundation
import WebKit
import os

/// Serves the vendored June bundle over `june://bundle/...` (Plan 1-MAS §1).
/// A custom scheme rather than `loadFileURL` because WebKit silently
/// CORS-blocks ES-module scripts on file:// origins (Phase 0 finding), and the
/// scheme gives the surface a pinnable origin per the hardening doctrine §3.A.
/// Reads happen off-main; every path is confined to the dist root.
final class JuneSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "june"
    static let entryURL = URL(string: "june://bundle/index.html")

    private static let log = Logger(subsystem: "com.epistemos", category: "JuneSchemeHandler")

    private let root: URL
    // Concurrent: a web bundle requests many assets at once on cold load, and
    // each Data(contentsOf:) read is independent. The task registry stays on
    // the main actor, so parallel reads are safe and shave cold-open latency.
    private let readQueue = DispatchQueue(
        label: "com.epistemos.june-scheme-read", qos: .userInitiated, attributes: .concurrent
    )
    /// Live tasks, kept on the main actor (WKURLSchemeTask is not Sendable).
    /// Removal on stop doubles as the didReceive-after-stop crash guard.
    private var activeTasks: [ObjectIdentifier: WKURLSchemeTask] = [:]

    private static let mimeByExtension: [String: String] = [
        "html": "text/html", "js": "application/javascript", "mjs": "application/javascript",
        "css": "text/css", "json": "application/json", "svg": "image/svg+xml",
        "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif",
        "webp": "image/webp", "ico": "image/x-icon", "woff": "font/woff", "woff2": "font/woff2",
        "ttf": "font/ttf", "otf": "font/otf", "wasm": "application/wasm", "map": "application/json",
        "txt": "text/plain", "webm": "video/webm", "mp4": "video/mp4", "mp3": "audio/mpeg",
        "wav": "audio/wav",
    ]

    /// Commercial fonts licensed to June upstream, NOT to Epistemos — never
    /// served, even when the dev fork's dist contains them (Plan 1-MAS R6).
    /// The UI falls back to Apple-bundled fonts via the stacks + the
    /// @font-face local() overrides injected by JuneAgentSurfaceView.
    private static let unlicensedFontFiles: Set<String> = [
        "BerkeleyMono-Regular.woff2", "BerkeleyMono-Oblique.woff2",
        "ABCDiatype-Regular.woff2", "ABCDiatype-Medium.woff2",
        "martina-plantijn-light.woff2",
    ]

    init(root: URL) {
        self.root = root.standardizedFileURL
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else { return }

        let rawPath = url.path
        let path = (rawPath.isEmpty || rawPath == "/") ? "/index.html" : rawPath
        let fileURL = root.appendingPathComponent(String(path.dropFirst())).standardizedFileURL
        // Confine to the bundle root — reject traversal outright.
        guard fileURL.path.hasPrefix(root.path + "/") || fileURL.path == root.path else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        guard !Self.unlicensedFontFiles.contains(fileURL.lastPathComponent) else {
            respond(to: urlSchemeTask, url: url, status: 404, mime: nil, data: nil)
            return
        }

        let taskID = ObjectIdentifier(urlSchemeTask)
        activeTasks[taskID] = urlSchemeTask
        readQueue.async { [weak self] in
            let data = try? Data(contentsOf: fileURL)
            let ext = fileURL.pathExtension.lowercased()
            Task { @MainActor [weak self] in
                guard let self, let task = self.activeTasks.removeValue(forKey: taskID) else { return }
                guard let data else {
                    Self.log.warning("june:// 404 \(path, privacy: .public)")
                    self.respond(to: task, url: url, status: 404, mime: nil, data: nil)
                    return
                }
                let mime = Self.mimeByExtension[ext] ?? "application/octet-stream"
                self.respond(to: task, url: url, status: 200, mime: mime, data: data)
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        activeTasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))
    }

    /// Hardening doctrine §3.A: no external hosts from the webview. All
    /// legitimate networking (engines, proxy) is Swift-side; page JS gets
    /// same-origin only. Inline script/style stay allowed (Vite output and
    /// React style attributes need them); user scripts bypass CSP by design.
    private static let contentSecurityPolicy =
        "default-src 'self'; script-src 'self' 'unsafe-inline'; " +
        "style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; " +
        "font-src 'self' data:; connect-src 'self'; media-src 'self' blob:; " +
        "object-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'"

    private func respond(to task: WKURLSchemeTask, url: URL, status: Int, mime: String?, data: Data?) {
        var headers: [String: String] = [:]
        if let mime { headers["Content-Type"] = mime }
        if let data { headers["Content-Length"] = String(data.count) }
        if mime == "text/html" {
            headers["Content-Security-Policy"] = Self.contentSecurityPolicy
        }
        guard let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers
        ) else { return }
        task.didReceive(response)
        if let data { task.didReceive(data) }
        task.didFinish()
    }
}
#endif
