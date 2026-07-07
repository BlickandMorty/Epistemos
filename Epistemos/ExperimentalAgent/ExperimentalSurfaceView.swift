#if EPISTEMOS_EXPERIMENTAL
import AppKit
import SwiftUI
import UserNotifications
import WebKit

private extension Notification.Name {
    static let epistemosExperimentalKokoroInstallRequested =
        Notification.Name("EpistemosExperimentalKokoroInstallRequested")
}

/// SwiftUI host for the Experimental agent surface. Boots the supervised
/// headless 1Code backend and shows its SPA in a WKWebView. The `epistemos`
/// script-message handler services the "native Swift" desktopApi bucket
/// (window/zoom/clipboard/badge/notification/open-external/save-file); the
/// backend-push and /host-dialog buckets ride ws (onecode-shim.js). Chat +
/// terminal stay web (§0 rule).
struct ExperimentalSurfaceView: View {
    @State private var supervisor = ExperimentalRuntimeSupervisor.shared
    @State private var kokoroDownloader = KokoroModelDownloadService.shared
    @State private var showingKokoroInstallPrompt = false
    // Owner 2026-07-05: a native "back to Epistemos" pill like the other agent surfaces have.
    @Environment(UIState.self) private var ui
    // Task 2 (DoD-2): the LIVE Epistemos theme projected onto the SPA.
    var theme: EpistemosTheme = .nativeDefault
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
                    // (agent-surface precedent; the ledger's next-themes blocker
                    // dissolves at the appearance seam).
                    .colorScheme(theme.resolved.isDark ? .dark : .light)
            case .failed(let message), .unavailable(let message):
                statusCard(title: "Experimental surface unavailable", detail: message, retry: true)
            default:
                statusCard(title: "Starting the Experimental agent…", detail: supervisor.lastDiagnostic, retry: false)
            }

            // Owner directive 2026-07-05: the 1Code web UI stays as-is (sidebar,
            // recents, model picker — all web). EXACTLY ONE SwiftUI element on
            // this surface: the Home pill, June-MAS style, in the TRUE title-bar
            // strip (ignoresSafeArea) right of the traffic lights — not overlapping
            // the web sidebar's wordmark below.
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    backToEpistemosPill
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
                Spacer(minLength: 0)
            }
            .ignoresSafeArea()
            .zIndex(10)
        }
        .task {
            if case .idle = supervisor.status { supervisor.start() }
        }
        .onAppear {
            refreshReadAloudAvailability()
        }
        .onChange(of: kokoroDownloader.phase) { _, newPhase in
            if case .installed = newPhase {
                refreshReadAloudAvailability()
                if EpistemosSpeechSynthesizer.isTextToSpeechAvailable() {
                    showingKokoroInstallPrompt = false
                }
            }
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: .epistemosExperimentalKokoroInstallRequested)
                .receive(on: RunLoop.main)
        ) { _ in
            showingKokoroInstallPrompt = true
        }
        .onChange(of: theme.resolved) { _, _ in
            // Live theme switch: re-project the palette onto the loaded SPA —
            // never reload (a reload reboots the SPA and kills the session, §7).
            guard let webView = ExperimentalStateBridge.shared.webView else { return }
            webView.underPageBackgroundColor = ExperimentalThemeBridge.underPageColor(for: theme)
            webView.evaluateJavaScript(ExperimentalThemeBridge.applyScript(for: theme))
        }
        .sheet(isPresented: $showingKokoroInstallPrompt) {
            KokoroVoiceInstallPrompt()
                .environment(ui)
        }
    }

    private func returnHome() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            ui.homeContent = .greeting
        }
    }

    private func refreshReadAloudAvailability() {
        let available = EpistemosSpeechSynthesizer.isTextToSpeechAvailable()
        ExperimentalStateBridge.shared.webView?.evaluateJavaScript(
            "window.__EPISTEMOS_TTS_AVAILABLE__ = \(available ? "true" : "false"); "
                + "window.__EPISTEMOS_READALOUD_REFRESH__ && window.__EPISTEMOS_READALOUD_REFRESH__();"
        )
    }

    /// The ONE SwiftUI element on this surface (owner directive): a "Home"
    /// pill — June-MAS pill metrics (30pt slot, ChonkyPixels 12pt semibold,
    /// chevron.left) on a Liquid Glass capsule.
    private var backToEpistemosPill: some View {
        Button(action: returnHome) {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                Text("Home")
                    .font(Font.custom("ChonkyPixels", size: 12).weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 11)
            .frame(height: 30)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textPrimary.opacity(0.92))
        // June-pill parity (owner: match the pills, not a boxy glass slab): a clean
        // subtle capsule fill — the exact JuneAgentNavBar treatment.
        .background(theme.textPrimary.opacity(theme.resolved.isDark ? 0.07 : 0.045), in: Capsule())
        .help("Back to Epistemos")
        .accessibilityLabel("Back to Epistemos home")
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
        // Epistemos read-aloud fusion (app-wide TTS canon): the donor transcript's
        // speaker button routes through the app's on-device voice when available
        // (honest gate: unavailable speak/install attempts open the native installer).
        controller.addUserScript(WKUserScript(
            source: Self.readAloudUserScript(
                isAvailable: EpistemosSpeechSynthesizer.isTextToSpeechAvailable()
            ),
            injectionTime: .atDocumentStart, forMainFrameOnly: true
        ))
        controller.add(context.coordinator, name: "epistemosSpeak")
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

    private static func readAloudUserScript(isAvailable: Bool) -> String {
        """
        (function () {
          window.__EPISTEMOS_TTS_AVAILABLE__ = \(isAvailable ? "true" : "false");
          function ttsReady() { return window.__EPISTEMOS_TTS_AVAILABLE__ === true; }
          function post(action, text) {
            try {
              window.webkit.messageHandlers.epistemosSpeak.postMessage({ action: action, text: text || "" });
            } catch (e) {}
          }
          var pill = null;
          function ensurePill() {
            if (pill) return pill;
            pill = document.createElement("button");
            pill.type = "button";
            pill.className = "epistemos-experimental-read-selection";
            pill.style.cssText = "position:fixed;z-index:2147483647;display:none;align-items:center;gap:6px;padding:5px 10px;border-radius:8px;border:0.5px solid rgba(255,255,255,0.18);background:rgba(30,30,32,0.94);color:#fff;font-size:12px;font-weight:600;cursor:pointer;box-shadow:0 4px 14px rgba(0,0,0,0.28);";
            pill.addEventListener("mousedown", function (e) { e.preventDefault(); });
            pill.addEventListener("click", function (e) {
              e.preventDefault();
              e.stopPropagation();
              var sel = window.getSelection();
              var text = sel ? sel.toString().trim() : "";
              if (ttsReady()) {
                if (text) post("speak", text);
              } else {
                post("install", "");
              }
              hidePill();
            });
            document.documentElement.appendChild(pill);
            return pill;
          }
          function updatePillCopy() {
            if (!pill) return;
            pill.title = ttsReady() ? "Read aloud" : "Install Kokoro voice";
            pill.setAttribute("aria-label", pill.title);
            pill.innerHTML = ttsReady()
              ? '<span>Read aloud</span>'
              : '<span>Install voice</span>';
          }
          function hidePill() { if (pill) pill.style.display = "none"; }
          function showSelectionPill() {
            var sel = window.getSelection();
            var text = sel && sel.rangeCount ? sel.toString().trim() : "";
            if (!text) { hidePill(); return; }
            var rect = sel.getRangeAt(0).getBoundingClientRect();
            if (!rect || (!rect.width && !rect.height)) { hidePill(); return; }
            var p = ensurePill();
            updatePillCopy();
            p.style.display = "inline-flex";
            var top = rect.top - 38;
            if (top < 6) top = rect.bottom + 8;
            p.style.top = top + "px";
            p.style.left = Math.max(6, Math.min(rect.left, window.innerWidth - 130)) + "px";
          }
          function start() {
            document.addEventListener("mouseup", function () { setTimeout(showSelectionPill, 10); });
            document.addEventListener("scroll", hidePill, true);
            document.addEventListener("mousedown", function (e) {
              if (pill && e.target !== pill && !pill.contains(e.target)) hidePill();
            });
            document.addEventListener("selectionchange", function () {
              var s = window.getSelection();
              if (!s || !s.toString().trim()) hidePill();
            });
          }
          window.__EPISTEMOS_READALOUD_REFRESH__ = function () {
            updatePillCopy();
            showSelectionPill();
          };
          if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
          else start();
        })();
        """
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
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandlerWithReply,
                             WKScriptMessageHandler {
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
        // links open in the user's browser (same H1 posture as the other agent surfaces).
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
            // EPISTEMOS Cycle-2 frontier: ranked vault retrieval. Runs the app's REAL
            // RRF fused search (tantivy BM25 + usearch HNSW, epistemos-shadow) — the
            // context-assembly axis no standalone agent app can match — and returns
            // ranked {title, snippet, score, source} for grounded context. Async
            // because the search is async; reply() is sync, so intercept here.
            if kind == "vault:search-ranked" {
                return await handleRankedVaultSearch(payload: body["payload"])
            }
            // EPISTEMOS (owner-requested deep connection): a note/`.md` link clicked in the chat
            // opens IN the app's Notes editor instead of the external browser. Async because it
            // touches AppKit document opening; reply() is sync, so intercept here.
            if kind == "epistemos:open-note" {
                return await handleOpenNote(payload: body["payload"])
            }
            // EPISTEMOS (owner-requested): a web link clicked in the chat opens in the app's in-app
            // Browser (BrowserView) instead of the external browser.
            if kind == "epistemos:open-url" {
                return await handleOpenURL(payload: body["payload"])
            }
            // The agent-created note is a vault file. Keep the reply path async so the actual
            // coordinated replacement runs off the main actor.
            if kind == "vault:create-note" {
                return await handleCreateVaultNote(payload: body["payload"])
            }
            return reply(to: kind, payload: body["payload"])
        }

        // Read-aloud (fire-and-forget, non-reply channel): {action:"speak"|"stop",
        // text} → the shared on-device voice. Mirrors JuneAgentBridge's shape
        // validation; the agent helper caps length and applies user voice + filter.
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "epistemosSpeak",
                  let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }
            let synth = EpistemosSpeechSynthesizer.shared
            if action == "stop" {
                synth.stop()
                return
            }
            if action == "install" {
                NotificationCenter.default.post(name: .epistemosExperimentalKokoroInstallRequested, object: nil)
                return
            }
            guard action == "speak",
                  let text = body["text"] as? String,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            guard EpistemosSpeechSynthesizer.isTextToSpeechAvailable() else {
                NotificationCenter.default.post(name: .epistemosExperimentalKokoroInstallRequested, object: nil)
                return
            }
            _ = EpistemosAgentReadAloud.speak(text, synthesizer: synth)
        }

        // Open a vault note (.md) in the app's Notes editor when its link is clicked in the chat.
        // Vault-CONTAINED (no traversal outside the vault root) + .md-only + must exist; anything else
        // returns {handled:false} so the web caller falls back to its normal openExternal.
        @MainActor
        private func handleOpenNote(payload: Any?) async -> (Any?, String?) {
            let obj = payload as? [String: Any]
            guard let raw = (obj?["ref"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else {
                return (["handled": false], nil)
            }
            let ref = raw.removingPercentEncoding ?? raw
            guard ref.lowercased().hasSuffix(".md") else {
                return (["handled": false], nil) // only route markdown notes
            }
            guard let vaultURL = AppBootstrap.shared?.vaultSync.vaultURL else {
                return (["handled": false], nil)
            }
            let root = vaultURL.standardizedFileURL
            let target = root.appendingPathComponent(ref).standardizedFileURL
            // Containment: the resolved note must live inside the vault (blocks ../ traversal).
            guard target.path == root.path || target.path.hasPrefix(root.path + "/") else {
                return (["handled": false], nil)
            }
            guard FileManager.default.fileExists(atPath: target.path) else {
                return (["handled": false], nil) // not a real vault note → caller falls back
            }
            NSDocumentController.shared.openDocument(withContentsOf: target, display: true) { _, _, _ in }
            return (["handled": true], nil)
        }

        // Open a web link in the app's in-app Browser (BrowserView) rather than the external browser.
        // http(s) only; seeds UIState.browserInitialURL then navigates the home surface to .browser.
        // Returns {handled:false} for non-web refs so the web caller falls back to openExternal.
        @MainActor
        private func handleOpenURL(payload: Any?) async -> (Any?, String?) {
            let obj = payload as? [String: Any]
            guard let raw = (obj?["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let url = URL(string: raw),
                  ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  let ui = AppBootstrap.shared?.uiState else {
                return (["handled": false], nil)
            }
            ui.browserInitialURL = raw
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { ui.homeContent = .browser }
            return (["handled": true], nil)
        }

        // Ranked vault retrieval (Cycle-2): the app's RRF fused index (BM25+HNSW),
        // reachable from the embedded agent surface via the same round-trip as
        // vault:create-note. Returns {hits:[{title,snippet,score,source}]}.
        @MainActor
        private func handleRankedVaultSearch(payload: Any?) async -> (Any?, String?) {
            let obj = payload as? [String: Any]
            let query = ((obj?["query"] as? String) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard query.count >= 2 else {
                return (["hits": [[String: Any]]()], nil)
            }
            let limit = min(max((obj?["limit"] as? Int) ?? 6, 1), 20)
            guard let search = AppBootstrap.shared?.contextualShadowsState.haloSearchService else {
                // Recall not live (no vault / index not built) — honest empty, not an error.
                return (["hits": [[String: Any]](), "unavailable": true], nil)
            }
            let hits = await search.search(
                text: String(query.prefix(500)), domain: .notes, limit: limit)
            let payloadHits: [[String: Any]] = hits.map { hit in
                [
                    "title": hit.title,
                    // Strip the FTS highlight markup for clean injection into the prompt.
                    "snippet": hit.snippet
                        .replacingOccurrences(of: "<b>", with: "")
                        .replacingOccurrences(of: "</b>", with: ""),
                    "score": Double(hit.score),
                    "source": hit.source,
                ]
            }
            return (["hits": payloadHits], nil)
        }

        // Write an assistant reply into <vault>/notes/ as a titled markdown note.
        // Returns {success, path} to the web caller (which toasts on success).
        @MainActor
        private func handleCreateVaultNote(payload: Any?) async -> (Any?, String?) {
            guard let obj = payload as? [String: Any] else {
                return (["success": false, "error": "bad payload"], nil)
            }
            let rawBody = (obj["body"] as? String) ?? ""
            let body = String(rawBody.prefix(200_000)) // sane cap; agent replies aren't huge
            guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return (["success": false, "error": "empty body"], nil)
            }
            guard let vaultURL = AppBootstrap.shared?.vaultSync.vaultURL else {
                return (["success": false, "error": "no vault configured"], nil)
            }
            let rawTitle = (obj["title"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = rawTitle.isEmpty ? "Agent note" : String(rawTitle.prefix(120))

            // Slug from the title; keep it filesystem-safe + collision-resistant.
            let allowed = CharacterSet(charactersIn:
                "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_ ")
            let slugBase = String(title.unicodeScalars.filter { allowed.contains($0) })
                .replacingOccurrences(of: " ", with: "-")
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            let slug = slugBase.isEmpty ? "agent-note" : String(slugBase.prefix(60))
            let suffix = String(UUID().uuidString.prefix(8))

            let notesDir = vaultURL.appendingPathComponent("notes", isDirectory: true)
            let fileURL = notesDir.appendingPathComponent("\(slug)-\(suffix).md")

            // Minimal note: a heading + a source line + the reply. The vault MCP + Shadow index
            // both treat this as an ordinary markdown note.
            let noteText = "# \(title)\n\n_Saved from the Experimental agent._\n\n\(body)\n"
            do {
                try await Task.detached(priority: .utility) {
                    try AtomicVaultWriter.writeSynchronously(noteText, to: fileURL)
                }.value
                return (["success": true, "path": fileURL.path], nil)
            } catch {
                return (["success": false, "error": String(describing: error)], nil)
            }
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
                try await Task.detached(priority: .utility) {
                    try AtomicVaultWriter.writeSynchronously(data, to: url)
                }.value
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
            case "vault:create-note":
                return (["__unhandled": true], nil)
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
