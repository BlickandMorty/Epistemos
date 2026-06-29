import AppKit
import Foundation
import Network
import SwiftUI
import Testing
import WebKit

@testable import Epistemos

@Suite("Plan 3 browser-use Web UI shell")
struct BrowserUseWebUIViewTests {
    @Test("loopback guard allows only local Gradio URLs")
    func loopbackGuardAllowsOnlyLocalGradioURLs() {
        #expect(BrowserUseLoopbackGuard.allows(url: URL(string: "http://127.0.0.1:7788/")))
        #expect(BrowserUseLoopbackGuard.allows(url: URL(string: "http://localhost:7788/")))
        #expect(BrowserUseLoopbackGuard.allows(url: URL(string: "http://[::1]:7788/")))

        #expect(!BrowserUseLoopbackGuard.allows(url: URL(string: "https://127.0.0.1:7788/")))
        #expect(!BrowserUseLoopbackGuard.allows(url: URL(string: "http://example.com:7788/")))
        #expect(!BrowserUseLoopbackGuard.allows(url: URL(string: "http://127.0.0.1.evil.test:7788/")))
        #expect(!BrowserUseLoopbackGuard.allows(url: URL(string: "file:///tmp/browser-use.html")))
        #expect(!BrowserUseLoopbackGuard.allows(url: URL(string: "javascript:alert(1)")))
        #expect(!BrowserUseLoopbackGuard.allows(url: URL(string: "http://user:pass@127.0.0.1:7788/")))
        #expect(!BrowserUseLoopbackGuard.allows(url: URL(string: "http://127.0.0.1/")))

        #expect(BrowserUseLoopbackPolicy.loopbackURL(host: "127.0.0.1", port: 7788)?.absoluteString == "http://127.0.0.1:7788/")
        #expect(BrowserUseLoopbackPolicy.loopbackURL(host: "[::1]", port: 7788)?.absoluteString == "http://[::1]:7788/")
        #expect(BrowserUseLoopbackPolicy.loopbackURL(host: "example.com", port: 7788) == nil)
        #expect(BrowserUseLoopbackPolicy.loopbackURL(host: "[localhost]", port: 7788) == nil)
        #expect(BrowserUseLoopbackPolicy.loopbackURL(host: "[127.0.0.1]", port: 7788) == nil)
        #expect(BrowserUseLoopbackPolicy.loopbackURL(host: "[]127.0.0.1[]", port: 7788) == nil)
    }

    @Test("WKWebView dry-run loads a loopback fixture, submits, and blocks remote navigation")
    @MainActor
    func wkWebViewDryRunLoadsLoopbackFixtureSubmitsAndBlocksRemoteNavigation() async throws {
        let server = BrowserUseLoopbackFixtureServer()
        let fixtureURL = try await server.startAndAwait()
        defer { server.stop() }

        var blockedURL: URL?
        let hostingView = NSHostingView(
            rootView: BrowserUseLoopbackWebView(url: fixtureURL) { url in
                blockedURL = url
            }
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 640, height: 480)

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        defer { window.close() }

        let webView = try await waitForWebView(in: hostingView)
        #expect(!webView.configuration.websiteDataStore.isPersistent)

        let bodyText = try await waitForBodyText(
            in: webView,
            containing: BrowserUseLoopbackFixtureServer.readyMarker
        )
        #expect(bodyText.contains(BrowserUseLoopbackFixtureServer.readyMarker))

        let submitted = try await evaluateString(
            """
            document.getElementById('dry-run-submit').click();
            document.body.dataset.submitted || ''
            """,
            in: webView
        )
        #expect(submitted == "true")

        let remoteURL = try #require(URL(string: "http://example.com:7788/browser-use-dry-run"))
        webView.load(URLRequest(url: remoteURL))
        try await waitUntil { blockedURL?.host == "example.com" }
        #expect(blockedURL == remoteURL)
        #expect(webView.url?.host == fixtureURL.host)
    }

    @Test("web UI shell source keeps native Browser, Goose, Agent, and editor boundaries")
    func webUIShellSourceKeepsBoundaries() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/BrowserUse/BrowserUseWebUIView.swift")
        let policy = try loadMirroredSourceTextFile("Epistemos/BrowserUsePro/BrowserUseLoopbackPolicy.swift")

        for required in [
            "BrowserUseWebUIView",
            "BrowserUseLoopbackGuard",
            "BrowserUseRuntimeSupervisor",
            "BrowserUseLoopbackWebView",
            "NSViewRepresentable",
            "WKWebsiteDataStore.nonPersistent()",
            "BrowserUseLoopbackPolicy.allows",
            "struct BrowserUseLoopbackWebView: NSViewRepresentable",
            "self.settingsStore = settingsStore",
            "Task.detached(priority: .userInitiated)",
            "settingsStore.load()",
            "browser-use Pro settings could not be loaded",
            "readinessWorker?.cancel()",
            "supervisor.start",
            "shouldCancel: { Task.isCancelled }",
            "supervisor?.stop()",
            "startWorker?.cancel()",
            "if !readiness.isReady",
            "startRequestID = UUID()",
            "isStarting = false",
            "webView.stopLoading()",
            "navigationDelegate = nil",
            "uiDelegate = nil",
        ] {
            #expect(source.contains(required), "Missing browser-use Web UI shell string: \(required)")
        }
        #expect(!source.contains("loadOrDefault()"))

        #expect(policy.contains("normalizedAllowedHost("))
        #expect(policy.contains("trimmed.dropFirst().dropLast().contains(\":\")"))

        for forbidden in [
            "BrowserView(",
            "BrowserURLGuard",
            "WebKitBrowserEngine",
            "ObscuraBrowserEngine",
            "Epistemos/Goose",
            "Epistemos/Agent",
            "HTMLWorkspace",
            "PDFView",
            "EpdocWebViewShared",
            "NSWorkspace",
            "NSTask",
            "URLSession",
        ] {
            #expect(!source.contains(forbidden), "browser-use Web UI shell crossed boundary: \(forbidden)")
        }
    }

    enum TestError: Error, CustomStringConvertible {
        case fixtureServerDidNotStart
        case webViewMissing
        case bodyTextTimedOut(String)
        case conditionTimedOut

        var description: String {
            switch self {
            case .fixtureServerDidNotStart:
                return "browser-use loopback fixture server did not start"
            case .webViewMissing:
                return "browser-use loopback WKWebView was not created"
            case .bodyTextTimedOut(let lastText):
                return "browser-use loopback WKWebView body text never matched marker; last=\(lastText)"
            case .conditionTimedOut:
                return "browser-use loopback WKWebView condition timed out"
            }
        }
    }

    @MainActor
    private func waitForWebView(in root: NSView) async throws -> WKWebView {
        for _ in 0..<120 {
            root.layoutSubtreeIfNeeded()
            if let webView = findWebView(in: root) {
                return webView
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw TestError.webViewMissing
    }

    @MainActor
    private func findWebView(in root: NSView) -> WKWebView? {
        if let webView = root as? WKWebView {
            return webView
        }
        for subview in root.subviews {
            if let webView = findWebView(in: subview) {
                return webView
            }
        }
        return nil
    }

    @MainActor
    private func waitForBodyText(in webView: WKWebView, containing marker: String) async throws -> String {
        var lastText = ""
        for _ in 0..<160 {
            if let text = try? await evaluateString(
                "document.body ? document.body.innerText : ''",
                in: webView
            ) {
                lastText = text
                if text.contains(marker) {
                    return text
                }
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw TestError.bodyTextTimedOut(lastText)
    }

    @MainActor
    private func evaluateString(_ javaScript: String, in webView: WKWebView) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(javaScript) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: value as? String ?? "")
            }
        }
    }

    @MainActor
    private func waitUntil(_ predicate: @escaping @MainActor () -> Bool) async throws {
        for _ in 0..<120 {
            if predicate() {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw TestError.conditionTimedOut
    }
}

private nonisolated final class BrowserUseLoopbackFixtureServer: @unchecked Sendable {
    static let readyMarker = "browser-use WKWebView dry-run fixture ready"

    private let queue = DispatchQueue(label: "com.epistemos.browseruse.loopback-fixture", qos: .userInitiated)
    private let lock = NSLock()
    private var listener: NWListener?
    private var _baseURL: URL?

    func startAndAwait() async throws -> URL {
        try start()
        for _ in 0..<100 {
            if let baseURL {
                return baseURL
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw BrowserUseWebUIViewTests.TestError.fixtureServerDidNotStart
    }

    func stop() {
        listener?.cancel()
        listener = nil
        setBaseURL(nil)
    }

    private var baseURL: URL? {
        lock.lock()
        defer { lock.unlock() }
        return _baseURL
    }

    private func setBaseURL(_ url: URL?) {
        lock.lock()
        _baseURL = url
        lock.unlock()
    }

    private func start() throws {
        guard listener == nil else { return }
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        parameters.allowLocalEndpointReuse = true

        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self, let listener else { return }
            if case .ready = state, let port = listener.port?.rawValue {
                self.setBaseURL(URL(string: "http://127.0.0.1:\(port)/"))
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] _, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }
            connection.send(content: self.response(), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func response() -> Data {
        let body = """
        <!doctype html>
        <html>
        <head><meta charset="utf-8"><title>browser-use dry run</title></head>
        <body>
        <main>
        <p id="ready">\(Self.readyMarker)</p>
        <button id="dry-run-submit" onclick="document.body.dataset.submitted='true'">Submit dry-run task</button>
        </main>
        </body>
        </html>
        """
        let headers = [
            "HTTP/1.1 200 OK",
            "Content-Type: text/html; charset=utf-8",
            "Content-Length: \(body.utf8.count)",
            "Cache-Control: no-store",
            "Connection: close",
            "",
            "",
        ].joined(separator: "\r\n")
        return Data((headers + body).utf8)
    }
}
