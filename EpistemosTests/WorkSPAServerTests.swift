import Foundation
import Testing
@testable import Epistemos

// End-to-end proof of the loopback-serve slice: start a REAL `WorkSPAServer` against a temp `dist/`-shaped root,
// then make actual loopback HTTP requests and assert it serves files (status, MIME, 404, SPA deep-link fallback).
// This runtime-proves the mechanism the Work surface relies on (the WebView render itself is owner-visual-proof).
@Suite("Work SPA loopback server — end-to-end serving")
struct WorkSPAServerTests {
    enum TestError: Error { case didNotStart }

    /// A temp `dist/`-shaped root: `index.html` + `assets/app.js`.
    private func makeRoot() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("work-spa-server-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: base.appendingPathComponent("assets"), withIntermediateDirectories: true)
        try "<html><body>root-marker</body></html>".write(
            to: base.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        try "export const x = 1;".write(
            to: base.appendingPathComponent("assets/app.js"), atomically: true, encoding: .utf8)
        return base
    }

    private func startAndAwait(_ server: WorkSPAServer) async throws -> URL {
        try server.start()
        for _ in 0..<100 {
            if case .running(let baseURL) = server.status { return baseURL }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw TestError.didNotStart
    }

    private func containsWorkerURL(_ html: String, _ rawURL: String = "http://localhost:8787") -> Bool {
        let escapedURL = String(WorkSPAServer.jsStringLiteral(rawURL).dropFirst().dropLast())
        return html.contains(rawURL) || html.contains(escapedURL)
    }

    @Test("Work SPA server source routes failures through diagnostics")
    func workSPAServerSourceRoutesFailuresThroughDiagnostics() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Work/WorkSPAServer.swift")

        #expect(source.contains("WorkServerDiagnostics.statusMessage(for: error"))
        #expect(!source.contains("error.localizedDescription"))
        #expect(!source.contains("String(describing: error)"))
    }

    @Test("serves index.html at / over loopback (200 + text/html)")
    func servesIndex() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = WorkSPAServer(root: root)
        defer { server.stop() }
        let baseURL = try await startAndAwait(server)
        #expect(baseURL.absoluteString.hasPrefix("http://localhost:"))
        let (data, response) = try await URLSession.shared.data(from: baseURL)
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)
        #expect((http.value(forHTTPHeaderField: "Content-Type") ?? "").contains("text/html"))
        #expect(http.value(forHTTPHeaderField: "Cache-Control") == "no-store")
        #expect(http.value(forHTTPHeaderField: "X-Content-Type-Options") == "nosniff")
        #expect((String(data: data, encoding: .utf8) ?? "").contains("root-marker"))
    }

    @Test("can advertise 127.0.0.1 while remaining loopback-only")
    func advertisesLoopbackIP() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = WorkSPAServer(root: root, advertisedHost: "127.0.0.1")
        defer { server.stop() }
        let baseURL = try await startAndAwait(server)
        #expect(baseURL.absoluteString.hasPrefix("http://127.0.0.1:"))
        let (data, response) = try await URLSession.shared.data(from: baseURL)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect((String(data: data, encoding: .utf8) ?? "").contains("root-marker"))
    }

    @Test("HEAD / returns the same headers as GET but no body")
    func headReturnsHeadersOnly() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = WorkSPAServer(root: root)
        defer { server.stop() }
        let baseURL = try await startAndAwait(server)
        var request = URLRequest(url: baseURL)
        request.httpMethod = "HEAD"
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)
        #expect((http.value(forHTTPHeaderField: "Content-Type") ?? "").contains("text/html"))
        let fixtureLength = String("<html><body>root-marker</body></html>".utf8.count)
        #expect(http.value(forHTTPHeaderField: "Content-Length") == fixtureLength)
        #expect(data.isEmpty)
    }

    @Test("non-GET/HEAD methods are rejected with 405")
    func rejectsUnsupportedMethods() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = WorkSPAServer(root: root)
        defer { server.stop() }
        let baseURL = try await startAndAwait(server)
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        let (_, response) = try await URLSession.shared.data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 405)
        #expect(http.value(forHTTPHeaderField: "Allow") == "GET, HEAD")
        #expect(http.value(forHTTPHeaderField: "Cache-Control") == "no-store")
    }

    @Test("oversized declared request bodies map to 413")
    func oversizedDeclaredRequestMapsTo413() {
        let raw = "GET / HTTP/1.1\r\nContent-Length: 300000\r\n\r\n"
        #expect(WorkMCPHTTPRequest.parse(Data(raw.utf8), maxContentLength: 256 * 1024) == .tooLarge)
        let response = String(decoding: WorkSPAServer.errorResponse(status: 413), as: UTF8.self)
        #expect(response.hasPrefix("HTTP/1.1 413 Payload Too Large"))
    }

    @Test("HEAD errors keep headers but no body")
    func headErrorsHaveNoBody() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = WorkSPAServer(root: root)
        defer { server.stop() }
        let baseURL = try await startAndAwait(server)
        var request = URLRequest(url: baseURL.appendingPathComponent("assets/missing.js"))
        request.httpMethod = "HEAD"
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 404)
        #expect(http.value(forHTTPHeaderField: "Content-Length") == "0")
        #expect(data.isEmpty)
    }

    @Test("serves an asset with the right MIME (text/javascript)")
    func servesAsset() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = WorkSPAServer(root: root)
        defer { server.stop() }
        let baseURL = try await startAndAwait(server)
        let (data, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("assets/app.js"))
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)
        #expect((http.value(forHTTPHeaderField: "Content-Type") ?? "").contains("javascript"))
        #expect(http.value(forHTTPHeaderField: "Cache-Control") == "no-cache")
        #expect(http.value(forHTTPHeaderField: "X-Content-Type-Options") == "nosniff")
        #expect((String(data: data, encoding: .utf8) ?? "").contains("export const x"))
    }

    @Test("unknown asset (with extension) → 404")
    func unknownAsset404() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = WorkSPAServer(root: root)
        defer { server.stop() }
        let baseURL = try await startAndAwait(server)
        let (_, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("assets/missing.js"))
        #expect((response as? HTTPURLResponse)?.statusCode == 404)
    }

    @Test("oversized served files return 413 without loading the file")
    func oversizedServedFileReturns413() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try createSparseSPAFile(
            root.appendingPathComponent("assets/oversized.js"),
            size: WorkSPASchemeHandler.maxServedFileBytes + 1
        )
        let server = WorkSPAServer(root: root)
        defer { server.stop() }
        let baseURL = try await startAndAwait(server)

        let (data, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("assets/oversized.js"))
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 413)
        #expect(String(data: data, encoding: .utf8)?.contains("Payload Too Large") == true)
    }

    @Test("extension-less deep link falls back to index.html (SPA client routing)")
    func deepLinkFallsBackToIndex() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = WorkSPAServer(root: root)
        defer { server.stop() }
        let baseURL = try await startAndAwait(server)
        let (data, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("settings/models"))
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)
        #expect((String(data: data, encoding: .utf8) ?? "").contains("root-marker"))
    }

    @Test("static JSON routes are served before SPA fallback and support HEAD")
    func servesStaticJSONRoutes() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let route = WorkSPAStaticRoute(
            path: "/agent/list_apps",
            contentType: "application/json; charset=utf-8",
            body: Data(#"{"apps":[]}"#.utf8)
        )
        let server = WorkSPAServer(root: root, staticRoutes: [route])
        defer { server.stop() }
        let baseURL = try await startAndAwait(server)

        let routeURL = baseURL.appendingPathComponent("agent/list_apps")
        let (data, response) = try await URLSession.shared.data(from: routeURL)
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)
        #expect(http.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=utf-8")
        #expect(http.value(forHTTPHeaderField: "Cache-Control") == "no-store")
        #expect(String(data: data, encoding: .utf8) == #"{"apps":[]}"#)

        var head = URLRequest(url: routeURL.appending(queryItems: [URLQueryItem(name: "session_id", value: "s")]))
        head.httpMethod = "HEAD"
        let (headData, headResponse) = try await URLSession.shared.data(for: head)
        let headHTTP = try #require(headResponse as? HTTPURLResponse)
        #expect(headHTTP.statusCode == 200)
        #expect(headHTTP.value(forHTTPHeaderField: "Content-Length") == String(route.body.count))
        #expect(headData.isEmpty)
    }

    @Test("Apps route has an explicit empty-list compatibility response")
    func appsCompatibilityRoute() {
        let route = WorkSPAStaticRoute(
            path: "/agent/list_apps",
            contentType: "application/json; charset=utf-8",
            body: Data(#"{"apps":[]}"#.utf8)
        )
        #expect(route.contentType == "application/json; charset=utf-8")
        #expect(String(data: route.body, encoding: .utf8) == #"{"apps":[]}"#)
    }

    // MARK: auto-connect bootstrap injection

    @Test("injectBootstrap seeds worker URL+token into localStorage via a <head> script")
    func injectsBootstrap() {
        let html = "<!doctype html><html><head><meta></head><body>app</body></html>"
        let out = WorkSPAServer.injectBootstrap(
            intoHTML: html, bootstrap: WorkSPABootstrap(workerURL: "http://localhost:8787", token: "tok-123"))
        #expect(out.contains("openwork.server.token"))
        #expect(out.contains("openwork.server.active"))
        #expect(out.contains("openwork.server.list"))
        #expect(out.contains("tok-123"))
        #expect(containsWorkerURL(out))
        // The seeding script runs before the app: it's inside <head>.
        let head = out.range(of: "<head>")
        let headClose = out.range(of: "</head>")
        let script = out.range(of: "<script>")
        if let head, let headClose, let script {
            #expect(script.lowerBound >= head.upperBound && script.lowerBound < headClose.lowerBound)
        }
    }

    @Test("injectBootstrap seeds openwork.themePref when set, omits it when nil")
    func injectsThemePref() {
        let html = "<!doctype html><html><head></head><body>app</body></html>"
        let withPref = WorkSPAServer.injectBootstrap(
            intoHTML: html,
            bootstrap: WorkSPABootstrap(workerURL: "http://localhost:8787", token: "t", themePref: "dark"))
        #expect(withPref.contains("openwork.themePref"))
        #expect(withPref.contains("\"dark\""))
        let noPref = WorkSPAServer.injectBootstrap(
            intoHTML: html, bootstrap: WorkSPABootstrap(workerURL: "http://localhost:8787", token: "t"))
        #expect(!noPref.contains("openwork.themePref"))
    }

    @Test("injectBootstrap always seals onboarding (openwork.preferences.hasCompletedOnboarding)")
    func sealsOnboarding() {
        let html = "<!doctype html><html><head></head><body>app</body></html>"
        let out = WorkSPAServer.injectBootstrap(
            intoHTML: html, bootstrap: WorkSPABootstrap(workerURL: "http://localhost:8787", token: "t"))
        #expect(out.contains("openwork.preferences"))
        #expect(out.contains("hasCompletedOnboarding"))
    }

    @Test("jsStringLiteral produces a safe quoted JS literal (escapes quotes)")
    func jsLiteralEscapes() {
        #expect(WorkSPAServer.jsStringLiteral("abc") == "\"abc\"")
        #expect(WorkSPAServer.jsStringLiteral("a\"b").contains("\\\"")) // embedded quote is escaped
        #expect(WorkSPAServer.jsStringLiteral("http://localhost:8787").contains("\\/"))
    }

    @Test("server injects the bootstrap into served index.html when bootstrap is set (end-to-end)")
    func servesWithBootstrap() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = WorkSPAServer(
            root: root, bootstrap: WorkSPABootstrap(workerURL: "http://localhost:8787", token: "tok-xyz"))
        defer { server.stop() }
        let baseURL = try await startAndAwait(server)
        let (data, _) = try await URLSession.shared.data(from: baseURL)
        let html = String(data: data, encoding: .utf8) ?? ""
        #expect(html.contains("openwork.server.token"))
        #expect(html.contains("tok-xyz"))
        #expect(containsWorkerURL(html))
        #expect(html.contains("root-marker")) // original content preserved
    }

    // MARK: reskin (CSS-variable injection)

    @Test("injectHeadSnippet inserts before </head> (after the SPA's own stylesheets)")
    func injectsHeadSnippet() {
        let html = "<html><head><link rel=\"stylesheet\"></head><body>x</body></html>"
        let out = WorkSPAServer.injectHeadSnippet(intoHTML: html, snippet: "<style>z</style>")
        #expect(out.contains("<style>z</style></head>"))
        // placed AFTER the existing stylesheet link so it overrides
        let styleIdx = out.range(of: "<style>z</style>")
        let linkIdx = out.range(of: "<link")
        if let styleIdx, let linkIdx { #expect(linkIdx.lowerBound < styleIdx.lowerBound) }
    }

    @Test("server injects the reskin <style> into served HTML when reskinCSS is set (end-to-end)")
    func servesWithReskin() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = WorkSPAServer(
            root: root,
            reskinCSS: "<style id=\"epistemos-reskin\">:root{--background:#123456!important;}</style>")
        defer { server.stop() }
        let baseURL = try await startAndAwait(server)
        let (data, _) = try await URLSession.shared.data(from: baseURL)
        let html = String(data: data, encoding: .utf8) ?? ""
        #expect(html.contains("epistemos-reskin"))
        #expect(html.contains("--background:#123456"))
        #expect(html.contains("root-marker")) // original content preserved
    }
}

private func createSparseSPAFile(_ url: URL, size: Int) throws {
    FileManager.default.createFile(atPath: url.path, contents: nil)
    let handle = try FileHandle(forWritingTo: url)
    try handle.truncate(atOffset: UInt64(size))
    try handle.close()
}
