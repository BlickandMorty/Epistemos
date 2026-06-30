import Foundation
import Network
import os

// Spike-B LOOPBACK-SERVE (owner 2026-06-24: "separate capability from presentation"; chosen over bundling the
// raw dist/). An EPISTEMOS-MANAGED, loopback-only HTTP server that serves the already-built OpenWork SPA (`dist/`)
// to the macOS-26 SwiftUI `WebView` over `http://127.0.0.1:<ephemeral>/` — a NORMAL web origin (unlike `file://`),
// so the donor app runs in its natural habitat: ES-module scripts, relative asset URLs, and `fetch` all work, and
// fewer features silently break than a too-early bundle.
//
// Ownership (owner's architecture): the Local Work runtime owns OpenCode/MCP/sessions; the WebView surface owns
// the rich OpenWork UI; this server is the Epistemos-controlled plumbing that hands the SPA to the WebView until
// the bundled runtime (`apps/server`) serves it itself. Signed/notarization-friendly by construction: pure Swift
// Network.framework, NO bundled binary, NO subprocess. Loopback-ONLY (`requiredInterfaceType = .loopback`) — never
// a routable interface. Reuses the proven `WorkMCPHTTPRequest.parse` (HTTP framing) + `WorkSPASchemeHandler`
// (path mapping + MIME + path-traversal guard).
/// The OpenWork worker connection seeded into the SPA so it auto-connects (no manual "Connect custom remote").
nonisolated struct WorkSPABootstrap: Sendable, Equatable {
    /// The local worker base URL (e.g. `http://localhost:8787`).
    let workerURL: String
    /// The worker's per-launch client bearer token.
    let token: String
    /// Optional Epistemos theme preference (`"dark"`/`"light"`) seeded into `openwork.themePref` so the SPA's OWN
    /// light/dark component logic (Tailwind `dark:` variants, icon/shadow variants) matches the reskin palette.
    /// Seeded in the EARLY-head bootstrap (before the SPA's inline boot `<script>` reads it).
    let themePref: String?

    init(workerURL: String, token: String, themePref: String? = nil) {
        self.workerURL = workerURL
        self.token = token
        self.themePref = themePref
    }
}

nonisolated struct WorkSPAStaticRoute: Sendable, Equatable {
    let path: String
    let contentType: String
    let body: Data

    init(path: String, contentType: String, body: Data) {
        self.path = path
        self.contentType = contentType
        self.body = body
    }
}

nonisolated final class WorkSPAServer: @unchecked Sendable {
    enum Status: Equatable, Sendable {
        case idle
        case starting
        /// Live; the loopback base URL the WebView loads (`http://127.0.0.1:<port>/`).
        case running(baseURL: URL)
        case failed(String)
        case stopped
    }

    let root: URL
    /// Optional auto-connect bridge: when set, a bootstrap `<script>` is injected into the served HTML so the SPA's
    /// localStorage carries the worker URL + token → it connects WITHOUT the manual "Connect custom remote" dialog.
    let bootstrap: WorkSPABootstrap?
    /// Optional Epistemos reskin: a `<style>` block (from `WorkSPAReskin.styleBlock`) injected at the END of the
    /// served HTML's `<head>` so the OpenWork SPA renders in the Epistemos palette WITHOUT an SPA rebuild
    /// (CSS-custom-property override; the block uses `!important` so it wins even over runtime-injected styles).
    let reskinCSS: String?
    let staticRoutes: [String: WorkSPAStaticRoute]
    /// Hostname advertised to WebView clients. The listener remains loopback-only; this only controls the URL
    /// string surfaced after NWListener picks an ephemeral port.
    let advertisedHost: String

    private static let logger = Logger(subsystem: "com.epistemos.server", category: "WorkSPAServer")
    private static let maxRequestBytes = 256 * 1024 // requests are small GET/HEAD lines

    private let queue = DispatchQueue(label: "com.epistemos.workspaserver", qos: .userInitiated)
    private var listener: NWListener?
    private let statusLock = NSLock()
    private var _status: Status = .idle

    var status: Status { statusLock.withLock { _status } }
    private func setStatus(_ newValue: Status) { statusLock.withLock { _status = newValue } }

    init(
        root: URL,
        bootstrap: WorkSPABootstrap? = nil,
        reskinCSS: String? = nil,
        staticRoutes: [WorkSPAStaticRoute] = [],
        advertisedHost: String = "localhost"
    ) {
        self.root = root
        self.bootstrap = bootstrap
        self.reskinCSS = reskinCSS
        self.staticRoutes = Dictionary(uniqueKeysWithValues: staticRoutes.map { ($0.path, $0) })
        self.advertisedHost = advertisedHost
    }

    // MARK: - Lifecycle

    func start() throws {
        guard listener == nil else { return }
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback // never a routable interface
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params) // ephemeral loopback port
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                if let port = listener.port?.rawValue,
                   let url = URL(string: "http://\(self.advertisedHost):\(port)/") {
                    self.setStatus(.running(baseURL: url))
                    Self.logger.info(
                        "WorkSPAServer ready on \(self.advertisedHost, privacy: .public):\(port, privacy: .public)"
                    )
                } else {
                    self.setStatus(.failed("listener ready but no bound port"))
                }
            case .failed(let error):
                let message = WorkServerDiagnostics.statusMessage(for: error, fallback: "listener failed")
                Self.logger.error("\(message, privacy: .public)")
                self.setStatus(.failed(message))
            case .cancelled:
                self.setStatus(.stopped)
            default:
                break
            }
        }
        setStatus(.starting)
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
        setStatus(.stopped)
    }

    // MARK: - Connection handling (mirrors WorkNativeMCPServer)

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, accumulated: Data())
    }

    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                let message = WorkServerDiagnostics.statusMessage(for: error, fallback: "receive error")
                Self.logger.debug("\(message, privacy: .public)")
                connection.cancel()
                return
            }
            var buffer = accumulated
            if let data { buffer.append(data) }
            if buffer.count > Self.maxRequestBytes {
                self.send(connection, Self.errorResponse(status: 413))
                return
            }
            switch WorkMCPHTTPRequest.parse(buffer, maxContentLength: Self.maxRequestBytes) {
            case .needMore:
                if isComplete { connection.cancel() } else { self.receive(connection, accumulated: buffer) }
            case .tooLarge:
                self.send(connection, Self.errorResponse(status: 413))
            case .invalid:
                self.send(connection, Self.errorResponse(status: 400))
            case .complete(let request):
                self.serve(request, on: connection)
            }
        }
    }

    private func serve(_ request: WorkMCPHTTPRequest, on connection: NWConnection) {
        let method = request.method.uppercased()
        guard method == "GET" || method == "HEAD" else {
            send(connection, Self.errorResponse(status: 405))
            return
        }
        if let staticRoute = staticRoutes[request.path] {
            let body = method == "HEAD" ? Data() : staticRoute.body
            send(connection, Self.staticRouteResponse(
                route: staticRoute,
                body: body,
                totalBytes: staticRoute.body.count
            ))
            return
        }
        do {
            let fileURL = try WorkSPASchemeHandler.resolve(path: request.path, root: root)
            var bytes = try WorkSPASchemeHandler.readServedFile(fileURL)
            // Inject into the served HTML: (1) the auto-connect bootstrap (worker URL+token → localStorage, so the
            // SPA skips the manual "Connect custom remote" dialog), and (2) the Epistemos reskin <style> at end of
            // <head> (overrides the SPA's theme tokens → the Epistemos look without an SPA rebuild).
            if fileURL.pathExtension.lowercased() == "html", let html = String(data: bytes, encoding: .utf8) {
                var injected = html
                if let bootstrap { injected = Self.injectBootstrap(intoHTML: injected, bootstrap: bootstrap) }
                if let reskinCSS { injected = Self.injectHeadSnippet(intoHTML: injected, snippet: reskinCSS) }
                bytes = Data(injected.utf8)
            }
            // HEAD: headers + the real Content-Length, no body.
            let body = method == "HEAD" ? Data() : bytes
            send(connection, Self.fileResponse(fileURL: fileURL, body: body, totalBytes: bytes.count))
        } catch WorkSPASchemeHandler.HandlerError.fileTooLarge {
            send(connection, Self.errorResponse(status: 413, includeBody: method != "HEAD"))
        } catch {
            send(connection, Self.errorResponse(status: 404, includeBody: method != "HEAD"))
        }
    }

    private func send(_ connection: NWConnection, _ data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
    }

    // MARK: - Pure framing (testable)

    /// Inject a bootstrap `<script>` that seeds the SPA's localStorage with the worker URL + token so it
    /// auto-connects (keys per OpenWork's server-provider.tsx: `openwork.server.token`/`.active`/`.list`). Placed
    /// right after `<head>` so it runs before the app's module scripts read localStorage.
    static func injectBootstrap(intoHTML html: String, bootstrap: WorkSPABootstrap) -> String {
        let url = jsStringLiteral(bootstrap.workerURL)
        let token = jsStringLiteral(bootstrap.token)
        var seeds = "localStorage.setItem(\"openwork.server.token\",\(token));localStorage.setItem(\"openwork.server.active\",u);localStorage.setItem(\"openwork.server.list\",JSON.stringify([u]));"
        if let pref = bootstrap.themePref {
            // Seeded BEFORE the SPA's inline boot script reads `openwork.themePref` → its `data-theme` matches.
            seeds += "localStorage.setItem(\"openwork.themePref\",\(jsStringLiteral(pref)));"
        }
        // SEAL ONBOARDING: set `openwork.preferences.hasCompletedOnboarding=true` (key/field per the donor
        // local-provider.tsx; readPersisted MERGES with defaults so seeding just the flag is safe + preserves other
        // prefs). Skips the welcome/create-workspace gate — whose "Local workspace = Desktop-only" + "Connect custom
        // remote" path is the "can't connect / can't continue" trap — sending the SPA straight to the
        // auto-registered, connected workspace.
        seeds += "try{var _p=JSON.parse(localStorage.getItem(\"openwork.preferences\")||\"{}\");_p.hasCompletedOnboarding=true;localStorage.setItem(\"openwork.preferences\",JSON.stringify(_p));}catch(_e){}"
        let script = "<script>(function(){try{var u=\(url);\(seeds)}catch(e){}})();</script>"
        if let headRange = html.range(of: "<head>") {
            return html.replacingCharacters(in: headRange, with: "<head>" + script)
        }
        return script + html // no <head> (unexpected) → prepend so it still runs first
    }

    /// Insert a raw HTML `snippet` at the END of `<head>` (after the SPA's own stylesheets, so a reskin `<style>`
    /// overrides them), falling back to right-after-`<head>` then prepend if the document has no head.
    static func injectHeadSnippet(intoHTML html: String, snippet: String) -> String {
        if let headClose = html.range(of: "</head>") {
            return html.replacingCharacters(in: headClose, with: snippet + "</head>")
        }
        if let headOpen = html.range(of: "<head>") {
            return html.replacingCharacters(in: headOpen, with: "<head>" + snippet)
        }
        return snippet + html
    }

    /// A safe JS string literal (JSON-encoded, quotes included) for embedding a value in injected script.
    static func jsStringLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return String(json.dropFirst().dropLast()) // `["x"]` → `"x"`
    }

    static func fileResponse(fileURL: URL, body: Data, totalBytes: Int) -> Data {
        let isHTML = fileURL.pathExtension.lowercased() == "html"
        var header = "HTTP/1.1 200 OK\r\n"
        header += "Content-Type: \(WorkSPASchemeHandler.mimeType(for: fileURL))\r\n"
        header += "Content-Length: \(totalBytes)\r\n"
        header += "Cache-Control: \(isHTML ? "no-store" : "no-cache")\r\n"
        header += "X-Content-Type-Options: nosniff\r\n"
        header += "Connection: close\r\n\r\n"
        var out = Data(header.utf8)
        out.append(body)
        return out
    }

    static func staticRouteResponse(route: WorkSPAStaticRoute, body: Data, totalBytes: Int) -> Data {
        var header = "HTTP/1.1 200 OK\r\n"
        header += "Content-Type: \(route.contentType)\r\n"
        header += "Content-Length: \(totalBytes)\r\n"
        header += "Cache-Control: no-store\r\n"
        header += "X-Content-Type-Options: nosniff\r\n"
        header += "Connection: close\r\n\r\n"
        var out = Data(header.utf8)
        out.append(body)
        return out
    }

    static func errorResponse(status: Int, includeBody: Bool = true) -> Data {
        let reason: String
        switch status {
        case 400: reason = "Bad Request"
        case 404: reason = "Not Found"
        case 405: reason = "Method Not Allowed"
        case 413: reason = "Payload Too Large"
        default: reason = "Error"
        }
        let body = includeBody ? Data("\(status) \(reason)".utf8) : Data()
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        header += "Content-Type: text/plain; charset=utf-8\r\n"
        header += "Cache-Control: no-store\r\n"
        header += "X-Content-Type-Options: nosniff\r\n"
        if status == 405 { header += "Allow: GET, HEAD\r\n" }
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n\r\n"
        var out = Data(header.utf8)
        out.append(body)
        return out
    }
}
