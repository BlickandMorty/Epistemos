import AppKit
import Darwin
import Foundation
import Network
import SwiftUI
import Testing
import WebKit

@testable import Epistemos

@Suite("Plan 3 browser-use Web UI shell")
struct BrowserUseWebUIViewTests {
    private static let gradioDryRunSubmitMarker = "Epistemos browser-use WebUI dry-run task-submit complete"

    @Test("loopback guard allows only local Gradio URLs")
    func loopbackGuardAllowsOnlyLocalGradioURLs() throws {
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
        #expect(BrowserUseLoopbackGuard.allows(
            url: URL(string: "http://127.0.0.1:7788/gradio"),
            matchingOriginOf: try #require(URL(string: "http://127.0.0.1:7788/"))
        ))
        #expect(!BrowserUseLoopbackGuard.allows(
            url: URL(string: "http://127.0.0.1:8787/"),
            matchingOriginOf: try #require(URL(string: "http://127.0.0.1:7788/"))
        ))
        #expect(!BrowserUseLoopbackGuard.allows(
            url: URL(string: "http://localhost:7788/"),
            matchingOriginOf: try #require(URL(string: "http://127.0.0.1:7788/"))
        ))

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

    @Test("WKWebView smoke loads real Gradio shell controls without submitting")
    @MainActor
    func wkWebViewLoadsRealGradioShellControlsWithoutSubmitting() async throws {
        let port = try await freeLoopbackPort()
        let smoke = try BrowserUseGradioWebUISmokeProcess(
            repoRoot: repositoryRoot(),
            port: port
        )
        try smoke.start()
        defer { smoke.stop() }
        try await smoke.waitUntilReady()

        var blockedURL: URL?
        let hostingView = NSHostingView(
            rootView: BrowserUseLoopbackWebView(url: smoke.loopbackURL) { url in
                blockedURL = url
            }
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 960, height: 720)

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
            containing: "Browser Use WebUI",
            attempts: 400
        )
        #expect(bodyText.contains("Control your browser with AI assistance"))

        let controlsText = try await waitForGradioRunAgentControls(in: webView)
        #expect(controlsText.contains("Your Task or Response"))
        #expect(controlsText.contains("Submit Task"))

        let taskText = "Open a local dry-run fixture without submitting."
        #expect(try await fillGradioTask(taskText, in: webView) == taskText)

        let remoteURL = try #require(URL(string: "http://example.com:7788/browser-use-gradio-webview-smoke"))
        webView.load(URLRequest(url: remoteURL))
        try await waitUntil { blockedURL?.host == "example.com" }
        #expect(blockedURL == remoteURL)
        #expect(webView.url?.host == "127.0.0.1")
    }

    @Test("WKWebView smoke submits real Gradio dry-run task")
    @MainActor
    func wkWebViewSubmitsRealGradioDryRunTask() async throws {
        let port = try await freeLoopbackPort()
        let smoke = try BrowserUseGradioWebUISmokeProcess(
            repoRoot: repositoryRoot(),
            port: port,
            dryRunSubmit: true
        )
        try smoke.start()
        defer { smoke.stop() }
        try await smoke.waitUntilReady()

        var blockedURL: URL?
        let hostingView = NSHostingView(
            rootView: BrowserUseLoopbackWebView(url: smoke.loopbackURL) { url in
                blockedURL = url
            }
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 960, height: 720)

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

        _ = try await waitForBodyText(
            in: webView,
            containing: "Browser Use WebUI",
            attempts: 400
        )
        _ = try await waitForGradioRunAgentControls(in: webView)

        let taskText = "Epistemos no-provider dry-run submit smoke."
        #expect(try await fillGradioTask(taskText, in: webView) == taskText)
        let submitClickResult = try await clickGradioSubmitTask(in: webView)
        #expect(submitClickResult.contains("Submit Task"))

        let completedText = try await waitForBodyText(
            in: webView,
            containing: Self.gradioDryRunSubmitMarker,
            attempts: 600
        )
        #expect(completedText.contains(taskText))
        #expect(completedText.contains(Self.gradioDryRunSubmitMarker))
        #expect(webView.url?.host == "127.0.0.1")

        let remoteURL = try #require(URL(string: "http://example.com:7788/browser-use-gradio-submit-smoke"))
        webView.load(URLRequest(url: remoteURL))
        try await waitUntil { blockedURL?.host == "example.com" }
        #expect(blockedURL == remoteURL)
        #expect(webView.url?.host == "127.0.0.1")
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
        case repositoryRootMissing
        case gradioSmokeMissingArtifact(String)
        case gradioSmokeProcessExited(String)
        case gradioSmokeTimedOut(String)

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
            case .repositoryRootMissing:
                return "browser-use test could not find the repository root"
            case .gradioSmokeMissingArtifact(let message):
                return message
            case .gradioSmokeProcessExited(let log):
                return "browser-use Gradio process exited before readiness: \(log)"
            case .gradioSmokeTimedOut(let log):
                return "browser-use Gradio process did not become ready: \(log)"
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
    private func waitForBodyText(
        in webView: WKWebView,
        containing marker: String,
        attempts: Int = 160
    ) async throws -> String {
        var lastText = ""
        for _ in 0..<attempts {
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
    private func waitForGradioRunAgentControls(in webView: WKWebView) async throws -> String {
        var lastText = ""
        for _ in 0..<400 {
            _ = try? await evaluateString(
                """
                (() => {
                  const textFor = (element) => (element.innerText || element.textContent || '').replace(/\\s+/g, ' ').trim();
                  const visible = (element) => !element.closest('.visually-hidden')
                    && element.getClientRects().length > 0
                    && getComputedStyle(element).visibility !== 'hidden';
                  const candidates = Array.from(document.querySelectorAll('button, [role="tab"], label, span, div'))
                    .filter((element) => {
                      const text = textFor(element);
                      return visible(element) && text.endsWith('Run Agent') && !text.includes('Agent Settings') && text.length <= 40;
                    })
                    .sort((left, right) => {
                      const leftRole = left.getAttribute('role') === 'tab' ? 1 : 0;
                      const rightRole = right.getAttribute('role') === 'tab' ? 1 : 0;
                      return rightRole - leftRole || left.childElementCount - right.childElementCount;
                    });
                  const tabLabel = candidates[0];
                  const tab = tabLabel ? (tabLabel.closest('button, [role="tab"], label, [tabindex]') || tabLabel) : null;
                  const click = (element) => {
                    element.scrollIntoView({ block: 'center', inline: 'center' });
                    element.dispatchEvent(new MouseEvent('pointerdown', { bubbles: true, cancelable: true, view: window }));
                    element.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, view: window }));
                    element.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, cancelable: true, view: window }));
                    element.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
                    element.click();
                  };
                  if (tabLabel) { click(tabLabel); }
                  if (tab && tab !== tabLabel) { click(tab); }
                  return document.body ? document.body.innerText : '';
                })()
                """,
                in: webView
            )

            if let text = try? await evaluateString(
                "document.body ? document.body.innerText : ''",
                in: webView
            ) {
                lastText = text
                if text.contains("Your Task or Response"), text.contains("Submit Task") {
                    return text
                }
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw TestError.bodyTextTimedOut(lastText)
    }

    @MainActor
    private func fillGradioTask(_ taskText: String, in webView: WKWebView) async throws -> String {
        let taskLiteral = try javaScriptStringLiteral(taskText)
        return try await evaluateString(
            """
            (() => {
              const task = \(taskLiteral);
              const textarea = document.querySelector('#user_input textarea') || document.querySelector('textarea');
              if (!textarea) { return 'missing textarea'; }
              const setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set;
              setter.call(textarea, task);
              textarea.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: task }));
              textarea.dispatchEvent(new Event('change', { bubbles: true }));
              return textarea.value || '';
            })()
            """,
            in: webView
        )
    }

    @MainActor
    private func clickGradioSubmitTask(in webView: WKWebView) async throws -> String {
        try await evaluateString(
            """
            (() => {
              const textFor = (element) => (element.innerText || element.textContent || '').replace(/\\s+/g, ' ').trim();
              const visible = (element) => !element.closest('.visually-hidden')
                && element.getClientRects().length > 0
                && getComputedStyle(element).visibility !== 'hidden';
              const button = Array.from(document.querySelectorAll('button'))
                .filter((element) => {
                  const text = textFor(element);
                  return visible(element) && text.endsWith('Submit Task') && !text.includes('Submit Response');
                })[0];
              if (!button) { return 'missing Submit Task'; }
              button.scrollIntoView({ block: 'center', inline: 'center' });
              button.dispatchEvent(new MouseEvent('pointerdown', { bubbles: true, cancelable: true, view: window }));
              button.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, view: window }));
              button.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, cancelable: true, view: window }));
              button.click();
              return textFor(button);
            })()
            """,
            in: webView
        )
    }

    private func javaScriptStringLiteral(_ text: String) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: [text])
        let arrayLiteral = try #require(String(data: data, encoding: .utf8))
        return String(arrayLiteral.dropFirst().dropLast())
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

    private func freeLoopbackPort() async throws -> Int {
        let server = BrowserUseLoopbackFixtureServer()
        let url = try await server.startAndAwait()
        server.stop()
        return try #require(url.port)
    }

    private func repositoryRoot() throws -> URL {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let candidates = [
            sourceURL.deletingLastPathComponent(),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        ]

        for candidate in candidates {
            if let root = findRepositoryRoot(startingAt: candidate) {
                return root
            }
        }
        throw TestError.repositoryRootMissing
    }

    private func findRepositoryRoot(startingAt startURL: URL) -> URL? {
        let fileManager = FileManager.default
        var current = startURL
        while true {
            let project = current.appendingPathComponent("Epistemos.xcodeproj", isDirectory: true)
            let webui = current.appendingPathComponent("agent_core/vendor/browser-use/web-ui/webui.py")
            if fileManager.fileExists(atPath: project.path),
               fileManager.fileExists(atPath: webui.path) {
                return current
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                return nil
            }
            current = parent
        }
    }
}

private nonisolated final class BrowserUseGradioWebUISmokeProcess: @unchecked Sendable {
    let loopbackURL: URL

    private let process: Process
    private let logHandle: FileHandle
    private let logURL: URL
    private let stateRoot: URL

    init(repoRoot: URL, port: Int, dryRunSubmit: Bool = false) throws {
        let fileManager = FileManager.default
        let vendorRoot = repoRoot.appendingPathComponent("agent_core/vendor/browser-use", isDirectory: true)
        let python = repoRoot.appendingPathComponent("build/browser-use-pro/.venv/bin/python")
        let webui = vendorRoot.appendingPathComponent("web-ui/webui.py")
        let manifest = vendorRoot.appendingPathComponent("BUILD_MANIFEST.json")
        let playwright = vendorRoot.appendingPathComponent("playwright", isDirectory: true)
        let wheels = vendorRoot.appendingPathComponent("wheels", isDirectory: true)

        guard fileManager.isExecutableFile(atPath: python.path) else {
            throw BrowserUseWebUIViewTests.TestError.gradioSmokeMissingArtifact(
                "Missing executable staged Python at \(python.path)"
            )
        }
        for file in [webui, manifest] where !fileManager.fileExists(atPath: file.path) {
            throw BrowserUseWebUIViewTests.TestError.gradioSmokeMissingArtifact(
                "Missing browser-use smoke artifact at \(file.path)"
            )
        }
        for directory in [playwright, wheels] {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw BrowserUseWebUIViewTests.TestError.gradioSmokeMissingArtifact(
                    "Missing browser-use smoke directory at \(directory.path)"
                )
            }
        }

        stateRoot = fileManager.temporaryDirectory.appendingPathComponent(
            "epistemos-browser-use-gradio-webview-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: stateRoot.appendingPathComponent("home", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: stateRoot.appendingPathComponent("browser-use-home", isDirectory: true),
            withIntermediateDirectories: true
        )

        logURL = stateRoot.appendingPathComponent("webui.log")
        fileManager.createFile(atPath: logURL.path, contents: nil)
        logHandle = try FileHandle(forWritingTo: logURL)
        loopbackURL = try #require(URL(string: "http://127.0.0.1:\(port)/"))

        process = Process()
        process.executableURL = python
        process.arguments = [webui.path, "--ip", "127.0.0.1", "--port", "\(port)", "--theme", "Ocean"]
        process.currentDirectoryURL = stateRoot
        process.standardOutput = logHandle
        process.standardError = logHandle
        var environment = [
            "HOME": stateRoot.appendingPathComponent("home", isDirectory: true).path,
            "BROWSER_USE_HOME": stateRoot.appendingPathComponent("browser-use-home", isDirectory: true).path,
            "PLAYWRIGHT_BROWSERS_PATH": playwright.path,
            "PYTHON_DOTENV_DISABLED": "true",
            "ANONYMIZED_TELEMETRY": "false",
            "BROWSER_USE_CLOUD_SYNC": "false",
            "BROWSER_USE_VERSION_CHECK": "false",
            "GRADIO_ANALYTICS_ENABLED": "False",
            "PYTHONUNBUFFERED": "1",
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "TMPDIR": fileManager.temporaryDirectory.path,
        ]
        if dryRunSubmit {
            environment["EPISTEMOS_BROWSER_USE_WEBUI_DRY_RUN_SUBMIT"] = "1"
        }
        process.environment = environment
    }

    func start() throws {
        try process.run()
    }

    func waitUntilReady() async throws {
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            if !process.isRunning {
                throw BrowserUseWebUIViewTests.TestError.gradioSmokeProcessExited(logExcerpt())
            }

            var request = URLRequest(url: loopbackURL)
            request.timeoutInterval = 2
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               String(data: data, encoding: .utf8)?.localizedCaseInsensitiveContains("gradio") == true {
                return
            }

            try await Task.sleep(nanoseconds: 500_000_000)
        }
        throw BrowserUseWebUIViewTests.TestError.gradioSmokeTimedOut(logExcerpt())
    }

    func stop() {
        if process.isRunning {
            process.terminate()
            let deadline = Date().addingTimeInterval(3)
            while process.isRunning, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.1)
            }
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
                process.waitUntilExit()
            }
        }
        try? logHandle.close()
        try? FileManager.default.removeItem(at: stateRoot)
    }

    private func logExcerpt() -> String {
        guard let data = try? Data(contentsOf: logURL),
              let text = String(data: data, encoding: .utf8),
              !text.isEmpty else {
            return "<empty webui.log>"
        }
        return String(text.suffix(4_000))
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
