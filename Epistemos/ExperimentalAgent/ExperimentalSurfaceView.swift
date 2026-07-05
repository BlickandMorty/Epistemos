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
        context.coordinator.loadStart = ContinuousClock.now
        webView.load(URLRequest(url: uiBaseURL))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandlerWithReply {
        private let uiBaseURL: URL
        weak var webView: WKWebView?
        /// Monotonic instant the SPA load began — for the §16 spa-ready measurement.
        var loadStart: ContinuousClock.Instant?

        init(uiBaseURL: URL) { self.uiBaseURL = uiBaseURL }

        // §16 spa-ready measurement: WKWebView load -> first paint (navigation finished).
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let began = loadStart else { return }
            loadStart = nil
            let comps = (ContinuousClock.now - began).components
            let ms = Double(comps.seconds) * 1000 + Double(comps.attoseconds) / 1e15
            ExperimentalPerfMetrics.shared.recordSpaReady(milliseconds: ms)
            Sig.experimentalSurface.emitEvent("spa_ready", "\(Int(ms))ms")
        }

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

        // Async variant of WKScriptMessageHandlerWithReply — returns the reply directly
        // (Swift 6 clean: sidesteps the @Sendable/@MainActor escaping-closure isolation the
        // completion-handler overload requires under strict concurrency). All handling is
        // synchronous @MainActor work, so no suspension actually occurs.
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) async -> (Any?, String?) {
            guard let body = message.body as? [String: Any],
                  let kind = body["kind"] as? String else {
                return (nil, "malformed message")
            }
            return reply(to: kind, payload: body["payload"])
        }

        private func reply(to kind: String, payload: Any?) -> (Any?, String?) {
            // rows 10-11 (§14): store a user-pasted provider key straight into the macOS
            // Keychain — NEVER back into webview JS. Handled before the window guard (no
            // window needed). Provider must be in the allow-list; key is length-capped.
            if kind.hasPrefix("keychain:") {
                let obj = payload as? [String: Any]
                let provider = (obj?["provider"] as? String)?.lowercased() ?? ""
                guard ExperimentalRuntimeSupervisor.providerKeychainEnvMap[provider] != nil else {
                    return (nil, "unknown provider")
                }
                let slot = ExperimentalRuntimeSupervisor.providerKeychainKey(provider)
                switch kind {
                case "keychain:store-provider-key":
                    let key = (obj?["key"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !key.isEmpty, key.utf8.count <= 8192 else { return (nil, "empty or oversized key") }
                    let ok = Keychain.save(key, for: slot)
                    return (["ok": ok], nil)
                case "keychain:has-provider-key":
                    return (["stored": Keychain.load(for: slot) != nil], nil)
                case "keychain:delete-provider-key":
                    Keychain.delete(for: slot)
                    return (["ok": true], nil)
                default:
                    return (nil, "unknown keychain op")
                }
            }
            guard let window = webView?.window else {
                // Window-scoped intents no-op cleanly before the window exists.
                return (nil, nil)
            }
            switch kind {
            case "window:minimize":
                window.miniaturize(nil); return (nil, nil)
            case "window:maximize", "window:toggle-fullscreen":
                window.toggleFullScreen(nil); return (nil, nil)
            case "window:close":
                window.performClose(nil); return (nil, nil)
            case "window:is-maximized":
                return (window.isZoomed, nil)
            case "window:is-fullscreen":
                return (window.styleMask.contains(.fullScreen), nil)
            case "window:set-title":
                if let title = (payload as? [String: Any])?["title"] as? String ?? payload as? String {
                    window.title = title
                }
                return (nil, nil)
            case "window:zoom-in":
                webView.map { $0.pageZoom = min($0.pageZoom + 0.1, 3.0) }; return (nil, nil)
            case "window:zoom-out":
                webView.map { $0.pageZoom = max($0.pageZoom - 0.1, 0.5) }; return (nil, nil)
            case "window:zoom-reset":
                webView?.pageZoom = 1.0; return (nil, nil)
            case "window:get-zoom":
                return (Double(webView?.pageZoom ?? 1.0), nil)
            case "clipboard:write":
                let text = (payload as? [String: Any])?["text"] as? String ?? payload as? String ?? ""
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                return (nil, nil)
            case "clipboard:read":
                return (NSPasteboard.general.string(forType: .string) ?? "", nil)
            case "app:set-badge":
                let count = (payload as? [String: Any])?["count"] as? Int ?? (payload as? Int)
                NSApp.dockTile.badgeLabel = (count.map { $0 > 0 } ?? false) ? count.map(String.init) : nil
                return (nil, nil)
            case "window:set-traffic-light-visibility",
                 "window:toggle-devtools", "window:unlock-devtools",
                 "app:set-badge-icon", "app:show-notification":
                // Notifications + save/open dialogs already terminate over the
                // /host ws bridge; devtools is Web Inspector territory. No-op here.
                return (nil, nil)
            default:
                return (["__unhandled": true], nil)
            }
        }
    }
}
#endif
