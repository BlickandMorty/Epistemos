#if EPISTEMOS_EXPERIMENTAL
import AppKit
import SwiftUI
import UserNotifications
import WebKit

/// SwiftUI host for the Experimental agent surface. Boots the supervised
/// headless 1Code backend and shows its SPA in a WKWebView. The `epistemos`
/// script-message handler services the "native Swift" desktopApi bucket
/// (window/zoom/clipboard/badge/notification/open-external/save-file); the
/// backend-push and /host-dialog buckets ride ws (onecode-shim.js). Chat +
/// terminal stay web (§0 rule).
struct ExperimentalSurfaceView: View {
    @State private var supervisor = ExperimentalRuntimeSupervisor.shared
    // Owner 2026-07-05: a native "back to Epistemos" pill like the other agent surfaces have.
    @Environment(UIState.self) private var ui
    // Task 2 (DoD-2): the LIVE Epistemos theme projected onto the SPA.
    var theme: EpistemosTheme = .nativeDefault
    // Task 3 (DoD-3): the native chat-list sidebar.
    @State private var nativeSidebarShown = false

    init(theme: EpistemosTheme = .nativeDefault) {
        self.theme = theme
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch supervisor.status {
            case .running(let connection):
                ExperimentalWebView(uiBaseURL: connection.uiBaseURL, theme: theme)
                    .ignoresSafeArea()
                    // Pin prefers-color-scheme to the THEME's darkness (not the OS
                    // setting) so the donor's next-themes — and with it Tailwind
                    // dark: utilities, xterm, Monaco — follows the app theme
                    // (ProAgent precedent; the ledger's next-themes blocker
                    // dissolves at the appearance seam).
                    .colorScheme(theme.resolved.isDark ? .dark : .light)
            case .failed(let message), .unavailable(let message):
                statusCard(title: "Experimental surface unavailable", detail: message, retry: true)
            default:
                statusCard(title: "Starting the Experimental agent…", detail: supervisor.lastDiagnostic, retry: false)
            }

            // Task 3 (DoD-3): native sidebar over the web transcript — chat list
            // + New Chat, tRPC-driven; selection rides the atom bridge.
            if nativeSidebarShown, case .running(let connection) = supervisor.status {
                ExperimentalNativeSidebar(baseURL: connection.uiBaseURL)
                    .transition(.move(edge: .leading))
                    .zIndex(9)
            }

            // Native chrome strip — floats in the empty hidden-inset title-bar area,
            // right of the macOS traffic lights, above the SPA chrome (always
            // reachable, even while the surface is starting or failed).
            HStack(spacing: 8) {
                backToEpistemosPill
                if case .running(let connection) = supervisor.status {
                    ExperimentalChromeBar(
                        baseURL: connection.uiBaseURL,
                        sidebarShown: $nativeSidebarShown
                    )
                }
            }
            .padding(.top, 10)
            .padding(.leading, 92)
            .zIndex(10)
        }
        .onChange(of: nativeSidebarShown) { _, shown in
            // Yield the strip to the native sidebar: collapse the donor's web
            // sidebar while ours is open (same atom its own toggle writes).
            ExperimentalStateBridge.shared.setAtom("agentsSidebarOpenAtom", value: !shown)
        }
        .task {
            if case .idle = supervisor.status { supervisor.start() }
        }
        .onChange(of: theme.resolved) { _, _ in
            // Live theme switch: re-project the palette onto the loaded SPA —
            // never reload (a reload reboots the SPA and kills the session, §7).
            guard let webView = ExperimentalStateBridge.shared.webView else { return }
            webView.underPageBackgroundColor = ExperimentalThemeBridge.underPageColor(for: theme)
            webView.evaluateJavaScript(ExperimentalThemeBridge.applyScript(for: theme))
        }
    }

    private var backToEpistemosPill: some View {
        ToolbarCapsuleButton(
            title: "Epistemos",
            systemImage: "house",
            role: .secondaryGhost,
            helpText: "Back to Epistemos",
            accessibilityLabel: "Back to Epistemos"
        ) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                ui.homeContent = .greeting
            }
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
    let theme: EpistemosTheme

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
        // Task 2 (DoD-2): Epistemos theme tokens as HSL-triplet !important vars
        // + structural CSS (gradient kill, landmark font) from first paint.
        controller.addUserScript(WKUserScript(
            source: ExperimentalThemeBridge.userScript(for: theme),
            injectionTime: .atDocumentStart, forMainFrameOnly: true
        ))
        // Reply-capable handler for the native desktopApi bucket (callId round-trip).
        controller.addScriptMessageHandler(
            context.coordinator, contentWorld: .page, name: "epistemos"
        )
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground") // native underPage blend
        // Task 2 (§7): pre-paint blend + deterministic prefers-color-scheme.
        webView.underPageBackgroundColor = ExperimentalThemeBridge.underPageColor(for: theme)
        webView.appearance = NSAppearance(named: theme.resolved.isDark ? .darkAqua : .aqua)
        context.coordinator.webView = webView
        // Task 0 keystone: native chrome drives the SPA's Jotai atoms through here.
        ExperimentalStateBridge.shared.webView = webView
        context.coordinator.loadStart = ContinuousClock.now
        webView.load(URLRequest(url: uiBaseURL))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Keep the WebView's effective appearance pinned to the theme so
        // prefers-color-scheme (and next-themes) tracks live theme switches.
        let wantDark = theme.resolved.isDark
        if (webView.appearance?.name == .darkAqua) != wantDark {
            webView.appearance = NSAppearance(named: wantDark ? .darkAqua : .aqua)
        }
    }

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
            // EPISTEMOS (§2/§3 save-dialog rewire): saving an agent-generated file needs an
            // async NSSavePanel; reply() is synchronous, so intercept it here. Was unwired →
            // desktopApi.saveFile (e.g. "save image") silently no-op'd.
            if kind == "dialog:save-file" {
                return await handleSaveFile(payload: body["payload"])
            }
            return reply(to: kind, payload: body["payload"])
        }

        @MainActor
        private func handleSaveFile(payload: Any?) async -> (Any?, String?) {
            guard let obj = payload as? [String: Any],
                  let rawBase64 = obj["base64Data"] as? String else {
                return (["success": false], nil)
            }
            // Accept both a raw base64 string and a data: URL.
            let base64 = rawBase64.contains(",")
                ? String(rawBase64.split(separator: ",", maxSplits: 1).last ?? "")
                : rawBase64
            guard let data = Data(base64Encoded: base64) else {
                return (["success": false], nil)
            }
            guard let window = webView?.window else {
                return (["success": false], nil)
            }
            let panel = NSSavePanel()
            panel.nameFieldStringValue = (obj["filename"] as? String) ?? "download"
            panel.canCreateDirectories = true
            let response = await panel.beginSheetModal(for: window)
            guard response == .OK, let url = panel.url else {
                return (["success": false], nil)  // user cancelled
            }
            do {
                try data.write(to: url, options: .atomic)
                return (["success": true, "filePath": url.path], nil)
            } catch {
                return (["success": false], nil)
            }
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
            case "shell:open-external":
                // EPISTEMOS (§2 → NSWorkspace): open renderer external links. Coordinator had NO
                // handler → hit default/__unhandled, and the shim's window.open fallback only
                // fires on __noNative/__timeout — so links silently didn't open. (21st.dev is
                // already blocked in the shim before this call.) http(s) only — no file:/js: URLs.
                let urlStr = (payload as? String) ?? (payload as? [String: Any])?["url"] as? String
                if let urlStr, let url = URL(string: urlStr),
                   ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                    NSWorkspace.shared.open(url)
                }
                return (nil, nil)
            case "app:show-notification":
                // EPISTEMOS (§2 → UNUserNotificationCenter): fire a native notification for the
                // agent's task-complete/error/input alerts. Was a silent no-op (the shim's
                // browser fallback only triggers on {__noNative:true}, which we never returned),
                // so notifications never showed. Fire-and-forget (auth callback).
                if let obj = payload as? [String: Any] {
                    let title = String((obj["title"] as? String ?? "Epistemos").prefix(120))
                    let bodyText = String((obj["body"] as? String ?? "").prefix(500))
                    let center = UNUserNotificationCenter.current()
                    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        guard granted else { return }
                        let content = UNMutableNotificationContent()
                        content.title = title
                        content.body = bodyText
                        center.add(UNNotificationRequest(
                            identifier: UUID().uuidString, content: content, trigger: nil))
                    }
                }
                return (nil, nil)
            case "window:set-traffic-light-visibility",
                 "window:toggle-devtools", "window:unlock-devtools",
                 "app:set-badge-icon":
                // Traffic-light visibility is native chrome territory; devtools is Web Inspector;
                // badge-icon is covered by app:set-badge. No-op here.
                return (nil, nil)
            default:
                return (["__unhandled": true], nil)
            }
        }
    }
}
#endif
