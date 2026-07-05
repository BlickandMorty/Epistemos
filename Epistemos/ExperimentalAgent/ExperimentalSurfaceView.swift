#if EPISTEMOS_EXPERIMENTAL
import AppKit
import SwiftUI
import WebKit

/// SwiftUI host for the Experimental agent surface. Boots the supervised
/// headless 1Code backend and shows its SPA in a WKWebView. The `epistemos`
/// script-message handler services the "native Swift" desktopApi bucket
/// (window/zoom/clipboard/badge/notification/open-external/save-file); the
/// backend-push and /host-dialog buckets ride ws (onecode-shim.js). Chat +
/// terminal stay web (§0 rule).
struct ExperimentalSurfaceView: View {
    @State private var supervisor = ExperimentalRuntimeSupervisor.shared

    var body: some View {
        ZStack {
            switch supervisor.status {
            case .running(let connection):
                ExperimentalWebView(uiBaseURL: connection.uiBaseURL)
                    .ignoresSafeArea()
            case .failed(let message), .unavailable(let message):
                statusCard(title: "Experimental surface unavailable", detail: message, retry: true)
            default:
                statusCard(title: "Starting the Experimental agent…", detail: supervisor.lastDiagnostic, retry: false)
            }
        }
        .task {
            if case .idle = supervisor.status { supervisor.start() }
        }
    }

    @ViewBuilder
    private func statusCard(title: String, detail: String?, retry: Bool) -> some View {
        VStack(spacing: 12) {
            if !retry { ProgressView() }
            Text(title).font(.headline)
            if let detail, !detail.isEmpty {
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 420)
            }
            if retry {
                Button("Retry") { supervisor.start() }
            }
        }
        .padding(32)
    }
}

/// NSViewRepresentable wrapping the WKWebView. Non-persistent data store
/// (§16 memory), no service worker persistence, keep-alive across tab switches
/// via the shared supervisor.
private struct ExperimentalWebView: NSViewRepresentable {
    let uiBaseURL: URL

    func makeCoordinator() -> Coordinator { Coordinator(uiBaseURL: uiBaseURL) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let controller = WKUserContentController()
        // onecode-shim.js @documentStart — replaces the Electron preload.
        if let shimSource = context.coordinator.shimSource() {
            controller.addUserScript(WKUserScript(
                source: shimSource, injectionTime: .atDocumentStart, forMainFrameOnly: true
            ))
        }
        // Reply-capable handler for the native desktopApi bucket (callId round-trip).
        controller.addScriptMessageHandler(
            context.coordinator, contentWorld: .page, name: "epistemos"
        )
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground") // native underPage blend
        context.coordinator.webView = webView
        webView.load(URLRequest(url: uiBaseURL))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandlerWithReply {
        private let uiBaseURL: URL
        weak var webView: WKWebView?

        init(uiBaseURL: URL) { self.uiBaseURL = uiBaseURL }

        func shimSource() -> String? {
            guard let root = ExperimentalRuntimeSupervisor.shared.currentShimScript else { return nil }
            return try? String(contentsOf: root, encoding: .utf8)
        }

        // Only the surface's own loopback origin may load in the WebView; outbound
        // links open in the user's browser (mirrors ProAgent H1 posture).
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else { return decisionHandler(.cancel) }
            switch url.scheme?.lowercased() {
            case "about":
                decisionHandler(.allow)
            case "http", "https":
                if isTrusted(url) {
                    decisionHandler(.allow)
                } else {
                    if let host = url.host?.lowercased(), !["127.0.0.1", "localhost", "::1"].contains(host) {
                        NSWorkspace.shared.open(url)
                    }
                    decisionHandler(.cancel)
                }
            default:
                decisionHandler(.cancel)
            }
        }

        private func isTrusted(_ url: URL) -> Bool {
            guard let host = url.host?.lowercased(), let port = url.port else { return false }
            return ["127.0.0.1", "localhost", "::1"].contains(host) && port == uiBaseURL.port
        }

        // MARK: - Native desktopApi bucket

        func userContentController(
            _ controller: WKUserContentController,
            didReceive message: WKScriptMessage,
            replyHandler: @escaping (Any?, String?) -> Void
        ) {
            guard let body = message.body as? [String: Any],
                  let kind = body["kind"] as? String else {
                replyHandler(nil, "malformed message")
                return
            }
            let payload = body["payload"]
            reply(to: kind, payload: payload, replyHandler: replyHandler)
        }

        private func reply(
            to kind: String, payload: Any?, replyHandler: @escaping (Any?, String?) -> Void
        ) {
            guard let window = webView?.window else {
                // Window-scoped intents no-op cleanly before the window exists.
                replyHandler(nil, nil)
                return
            }
            switch kind {
            case "window:minimize":
                window.miniaturize(nil); replyHandler(nil, nil)
            case "window:maximize", "window:toggle-fullscreen":
                window.toggleFullScreen(nil); replyHandler(nil, nil)
            case "window:close":
                window.performClose(nil); replyHandler(nil, nil)
            case "window:is-maximized":
                replyHandler(window.isZoomed, nil)
            case "window:is-fullscreen":
                replyHandler(window.styleMask.contains(.fullScreen), nil)
            case "window:set-title":
                if let title = (payload as? [String: Any])?["title"] as? String ?? payload as? String {
                    window.title = title
                }
                replyHandler(nil, nil)
            case "window:zoom-in":
                webView.map { $0.pageZoom = min($0.pageZoom + 0.1, 3.0) }; replyHandler(nil, nil)
            case "window:zoom-out":
                webView.map { $0.pageZoom = max($0.pageZoom - 0.1, 0.5) }; replyHandler(nil, nil)
            case "window:zoom-reset":
                webView?.pageZoom = 1.0; replyHandler(nil, nil)
            case "window:get-zoom":
                replyHandler(Double(webView?.pageZoom ?? 1.0), nil)
            case "clipboard:write":
                let text = (payload as? [String: Any])?["text"] as? String ?? payload as? String ?? ""
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                replyHandler(nil, nil)
            case "clipboard:read":
                replyHandler(NSPasteboard.general.string(forType: .string) ?? "", nil)
            case "app:set-badge":
                let count = (payload as? [String: Any])?["count"] as? Int
                    ?? (payload as? Int)
                NSApp.dockTile.badgeLabel = (count ?? 0) > 0 ? String(count!) : nil
                replyHandler(nil, nil)
            case "window:set-traffic-light-visibility",
                 "window:toggle-devtools", "window:unlock-devtools",
                 "app:set-badge-icon", "app:show-notification":
                // Notifications + save/open dialogs already terminate over the
                // /host ws bridge; devtools is Web Inspector territory. No-op here.
                replyHandler(nil, nil)
            default:
                replyHandler(["__unhandled": true], nil)
            }
        }
    }
}
#endif
