import Foundation
import Testing

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
}
