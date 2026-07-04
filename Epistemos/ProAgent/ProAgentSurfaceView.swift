#if !EPISTEMOS_APP_STORE
import SwiftUI
import WebKit
import UserNotifications

/// SECURITY (ports the goose-surface deep-hardening H1 posture): the OpenChamber
/// web server origin is the ONLY http origin this surface may navigate to in the
/// WebView. Any other loopback port or remote origin is denied; external links
/// open in the user's default browser instead.
final class ProAgentTrustedLoopbackOrigins: @unchecked Sendable {
    private let lock = NSLock()
    private var ports: Set<Int> = []

    static func isLoopback(_ host: String?) -> Bool {
        guard let host, host.utf8.count <= 128, !host.utf8.contains(0) else { return false }
        let normalized = host.lowercased()
        return normalized == "127.0.0.1" || normalized == "localhost" || normalized == "::1"
    }

    func register(_ url: URL?) {
        guard let url, let port = url.port, Self.isLoopback(url.host) else { return }
        lock.lock(); ports.insert(port); lock.unlock()
    }

    func isAllowed(_ url: URL) -> Bool {
        guard Self.isLoopback(url.host), let port = url.port else { return false }
        lock.lock(); defer { lock.unlock() }
        return ports.contains(port)
    }
}

private struct ProAgentNavigationDecider: WebPage.NavigationDeciding {
    let trustedOrigins: ProAgentTrustedLoopbackOrigins

    func decidePolicy(
        for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences
    ) async -> WKNavigationActionPolicy {
        guard let url = action.request.url else { return .cancel }
        switch url.scheme?.lowercased() {
        case "about":
            return .allow
        case "http", "https":
            if trustedOrigins.isAllowed(url) { return .allow }
            // Chat markdown is full of outbound links; honor them in the user's
            // browser, never inside the pinned surface.
            if !ProAgentTrustedLoopbackOrigins.isLoopback(url.host) {
                NSWorkspace.shared.open(url)
            }
            return .cancel
        default:
            return .cancel
        }
    }
}

/// EPISTEMOS ProAgent JS->Swift desktop bridge. The vendored OpenChamber SPA
/// already calls window.__OPENCHAMBER_DESKTOP__.invoke(...) (lib/desktop.ts);
/// with no host implementation, native OS notifications on agent-turn completion
/// silently no-op. Implements desktop_notify -> UNUserNotificationCenter. One-way
/// handler (proven JuneAgentBridge pattern); injected invoke returns
/// Promise.resolve(true) so notifyWithDesktop's await resolves (best-effort).
/// Untrusted webview input validated: dict body, whitelisted command, capped strings.
@MainActor
final class EpistemosDesktopBridge: NSObject, WKScriptMessageHandler {
    static let shared = EpistemosDesktopBridge()
    static let handlerName = "epistemosDesktop"

    static let injectScript = """
    (function () {
      if (window.__OPENCHAMBER_DESKTOP__) { return; }
      window.__OPENCHAMBER_DESKTOP__ = {
        invoke: function (command, args) {
          try { window.webkit.messageHandlers.epistemosDesktop.postMessage({ command: command, args: args || {} }); } catch (e) {}
          return Promise.resolve(true);
        }
      };
    })();
    """

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let command = body["command"] as? String
        else { return }
        let args = body["args"] as? [String: Any] ?? [:]
        switch command {
        case "desktop_notify":
            postNotification(args: args)
        case "speak":
            // Read-aloud: synthesize NATIVE-SIDE via the shared on-device engine.
            // CONSUME EpistemosSpeechSynthesizer (owned by the app-wide voice
            // agent) — never edit it, never put voice/audio code in the webview.
            // Honest gate: speak() itself refuses when the model isn't ready (no
            // AVSpeech fallback); nil voice uses the user's ModelVoicePicker pick.
            let text = (args["text"] as? String) ?? ""
            if !text.isEmpty {
                _ = EpistemosSpeechSynthesizer.shared.speak(
                    String(text.prefix(EpistemosSpeechSynthesizer.maxTextToSpeechInputCharacters)))
            }
        case "speak_stop":
            EpistemosSpeechSynthesizer.shared.stop()
        default:
            break
        }
    }

    private func postNotification(args: [String: Any]) {
        let payload = args["payload"] as? [String: Any] ?? [:]
        let title = Self.capped((payload["title"] as? String) ?? "Epistemos", 120)
        let bodyText = Self.capped((payload["body"] as? String) ?? "", 500)
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            if !bodyText.isEmpty { content.body = bodyText }
            content.sound = .default
            try? await center.add(
                UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            )
        }
    }

    private static func capped(_ value: String, _ limit: Int) -> String {
        value.count <= limit ? value : String(value.prefix(limit))
    }
}

/// The Pro build's Agent destination: the vendored OpenChamber SPA served by the
/// supervised web server, hosted in a kept-alive WebView.
///
/// Instant-open recipe (Plan 1-PRO §13, ported from the pre-excision
/// GooseWebSurfaceView — read, not approximated):
///  1. Eager WebPage created in init(), placeholder painted immediately.
///  2. Server spawn happens off the main actor (supervisor's SpawnBox).
///  3. Startup fires lazily from `.task` on first appear.
///  4. Readiness is poll-waited while the placeholder shows.
///  5. WebView AND children stay alive across tab switches; the SPA URL is
///     loaded exactly once per connection (a reload kills the live session).
///  6. Non-persistent website data store.
struct ProAgentSurfaceView: View {
    nonisolated static let renderProbeCount = 80
    nonisolated static let renderProbeIntervalNanoseconds: UInt64 = 150_000_000
    nonisolated static let initialRetryDelayNanoseconds: UInt64 = 450_000_000
    nonisolated static let maximumRetryDelayNanoseconds: UInt64 = 5_000_000_000
    // Circuit-breaker ceiling (MED-8): stop respawning the 3-child runtime
    // after this many consecutive failed starts. Reset on a fresh startSurface.
    nonisolated static let maxRuntimeRetryAttempts = 8
    nonisolated static let startingStatus = "Agent starting. Booting the workspace runtime."

    /// Ready when React has replaced the donor's #initial-loading placeholder
    /// inside #root (the mount contract verified in the vendored dist). On a
    /// non-ready result, append any page errors captured by the trap script so
    /// a blank surface reports its own root cause.
    /// NOTE: WebPage.callJavaScript runs this as a FUNCTION BODY (async-JS
    /// semantics), so the value must be `return`ed — an IIFE's result is
    /// discarded and bridges to nil ("unexpected-probe-result", found in the
    /// first instrumented acceptance run).
    nonisolated static let renderProbeScript = """
    const errors = (window.__epistemosPageErrors || []).slice(0, 3).join(' | ');
    const suffix = errors ? ' errors: ' + errors : '';
    const root = document.getElementById('root');
    if (!root) return 'no-root [' + document.readyState + ']' + suffix;
    if (document.getElementById('initial-loading')) return 'initial-loading' + suffix;
    if (root.children.length === 0) return 'empty-root' + suffix;
    return 'ready';
    """

    /// Injected at document start: records uncaught errors + rejections so the
    /// render probe can surface them (WKWebView has no attached Web Inspector
    /// in acceptance runs).
    nonisolated static let errorTrapScript = """
    window.__epistemosPageErrors = [];
    window.addEventListener('error', (event) => {
      try {
        const source = event && event.filename ? ' @' + String(event.filename).split('/').pop() + ':' + event.lineno : '';
        window.__epistemosPageErrors.push(String((event && event.message) || event) + source);
      } catch (_) {}
    });
    window.addEventListener('unhandledrejection', (event) => {
      try {
        const reason = event && event.reason;
        window.__epistemosPageErrors.push('rejection: ' + String((reason && reason.message) || reason));
      } catch (_) {}
    });
    """

    var theme: EpistemosTheme = .nativeDefault

    @State private var page: WebPage
    @State private var trustedOrigins: ProAgentTrustedLoopbackOrigins
    @State private var surfaceStarted = false
    @State private var loadedConnectionKey: String?
    @State private var loadTask: Task<Void, Never>?
    @State private var healthTask: Task<Void, Never>?
    @State private var retryTask: Task<Void, Never>?
    @State private var retryAttempt = 0
    @State private var overlayStatus: String?
    @State private var lastProbeResult: String?
    @State private var showAllChatsSheet = false

    private var supervisor: ProAgentRuntimeSupervisor { .shared }

    init(theme: EpistemosTheme = .nativeDefault) {
        self.theme = theme
        let trustedOrigins = ProAgentTrustedLoopbackOrigins()
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.defaultNavigationPreferences.allowsContentJavaScript = true
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Self.errorTrapScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        // EPISTEMOS: JS->Swift desktop bridge (native OS notifications).
        configuration.userContentController.add(
            EpistemosDesktopBridge.shared,
            name: EpistemosDesktopBridge.handlerName
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: EpistemosDesktopBridge.injectScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        // EPISTEMOS read-aloud: expose TTS availability so the OpenChamber overlay
        // honest-gates the button (shared engine; no voice/audio code in JS).
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: "window.__EPISTEMOS_TTS_AVAILABLE__ = \(EpistemosSpeechSynthesizer.isTextToSpeechAvailable() ? "true" : "false");",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        // EPISTEMOS theme bridge (owner 2026-07-04): pin the OpenChamber
        // palette + accent to the LIVE Epistemos theme from the first paint —
        // light, dark, and custom (JuneThemeBridge precedent). Later theme
        // switches re-apply via .onChange(of: theme.resolved).
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: ProAgentThemeBridge.userScript(for: theme),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        let page = WebPage(
            configuration: configuration,
            navigationDecider: ProAgentNavigationDecider(trustedOrigins: trustedOrigins)
        )
        _ = page.load(html: Self.placeholderHTML(status: Self.startingStatus))
        _page = State(initialValue: page)
        _trustedOrigins = State(initialValue: trustedOrigins)
    }

    var body: some View {
        ZStack {
            WebView(page)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let overlayStatus {
                loadingOverlay(status: overlayStatus)
            }
            // Companion/mascot overlay HOOK (Plan 1-PRO §5 — hook only; the
            // full mascot spec is Plan 5). Native layer ABOVE the WebView,
            // never inside donor DOM.
            ProAgentMascotOverlayHook()
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        // Pin prefers-color-scheme to the THEME's own darkness (not the OS
        // setting) so the SPA's system mode always matches the app theme.
        .colorScheme(theme.resolved.isDark ? .dark : .light)
        .task { await startSurface() }
        .onChange(of: supervisor.status) { _, status in
            handleRuntimeStatusChange(status)
        }
        .onChange(of: theme.resolved) { _, _ in
            // Live theme switch: re-project the Epistemos palette onto the
            // already-loaded SPA (no reload; inline vars win the cascade).
            let script = ProAgentThemeBridge.applyScript(for: theme)
            Task { _ = try? await page.callJavaScript(script) }
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: .epistemosProAgentChromeIntent)
                .receive(on: RunLoop.main)
        ) { note in
            handleChromeIntent(note)
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: .epistemosProAgentAllChats)
                .receive(on: RunLoop.main)
        ) { _ in
            showAllChatsSheet = true
        }
        .sheet(isPresented: $showAllChatsSheet) {
            ProAgentAllChatsSheet(
                theme: theme,
                uiBaseURL: { () -> URL? in
                    if case .running(let connection) = supervisor.status {
                        return connection.uiBaseURL
                    }
                    return nil
                }(),
                onSelect: { sessionId in
                    showAllChatsSheet = false
                    NotificationCenter.default.post(
                        name: .epistemosProAgentChromeIntent,
                        object: nil,
                        userInfo: ["type": ProAgentChromeIntent.selectSession, "sessionId": sessionId]
                    )
                },
                onDismiss: { showAllChatsSheet = false }
            )
        }
        .onDisappear {
            // Keep-alive rule (§13.5): tear down ONLY view-local monitors. The
            // supervisor, its children, and the WebPage all survive tab-away so
            // re-opening is instant and the live session is never killed.
            loadTask?.cancel()
            loadTask = nil
            healthTask?.cancel()
            healthTask = nil
            retryTask?.cancel()
            retryTask = nil
        }
    }

    private func loadingOverlay(status: String) -> some View {
        ZStack {
            GooseSurfaceStyle.background(for: theme)
            VStack(alignment: .leading, spacing: 9) {
                Text("Epistemos Agent")
                    .font(GooseSurfaceStyle.bodyFont(16, weight: .semibold))
                    .foregroundStyle(theme.resolved.foreground.color)
                Text(status)
                    .font(GooseSurfaceStyle.bodyFont(12))
                    .foregroundStyle(theme.mutedForeground)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private nonisolated static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func startSurface() async {
        guard !Self.isRunningTests else {
            loadPlaceholder(status: "Agent runtime disabled under tests")
            return
        }
        // Reappear fast path: children kept running and the SPA is already
        // mounted in the kept-alive page — just resume the health monitor.
        if case .running(let connection) = supervisor.status,
           loadedConnectionKey == connection.uiBaseURL.absoluteString {
            // Perf doctrine §4: warm_reopen — the owner-critical instant
            // re-open. This path does no loading; the measurement proves it.
            let warmStart = ContinuousClock.now
            beginHealthMonitor(connection: connection)
            let warmElapsed = ContinuousClock.now - warmStart
            Sig.agentSurface.emitEvent("warm_reopen")
            ProAgentPerfMetrics.shared.recordWarmReopen(
                milliseconds: Double(warmElapsed.components.seconds) * 1_000
                    + Double(warmElapsed.components.attoseconds) / 1e15
            )
            return
        }
        surfaceStarted = true
        loadPlaceholder(status: Self.startingStatus)
        switch supervisor.status {
        case .running(let connection):
            driveSurface(connection: connection)
            return
        case .starting:
            break
        default:
            supervisor.start()
        }
        await loadWhenReady()
    }

    private func loadWhenReady() async {
        for _ in 0..<300 {
            guard !Task.isCancelled else { return }
            switch supervisor.status {
            case .running(let connection):
                driveSurface(connection: connection)
                return
            case .failed(let message):
                loadPlaceholder(status: "Agent runtime retrying: \(message)")
                scheduleRuntimeRetry()
                return
            case .unavailable(let message):
                loadPlaceholder(status: message)
                return
            default:
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        // Don't strand on a dead placeholder — the status observer drives the
        // load whenever readiness finally arrives (goose review H1).
        loadPlaceholder(status: Self.startingStatus)
    }

    private func handleRuntimeStatusChange(_ status: ProAgentRuntimeSupervisor.Status) {
        switch status {
        case .running(let connection):
            retryTask?.cancel()
            retryTask = nil
            retryAttempt = 0
            driveSurface(connection: connection)
        case .failed(let message):
            loadedConnectionKey = nil
            healthTask?.cancel()
            healthTask = nil
            loadTask?.cancel()
            loadTask = nil
            overlayStatus = nil
            loadPlaceholder(status: "Agent runtime retrying: \(message)")
            scheduleRuntimeRetry()
        case .unavailable(let message):
            loadedConnectionKey = nil
            healthTask?.cancel()
            healthTask = nil
            loadTask?.cancel()
            loadTask = nil
            overlayStatus = nil
            loadPlaceholder(status: message)
        default:
            break
        }
    }

    /// Load the SPA exactly once per connection. Re-running this for the same
    /// connection is a no-op — reloading the URL would reboot the SPA and kill
    /// the live session (§13.5 double-critical rule).
    private func driveSurface(connection: ProAgentConnection) {
        let key = connection.uiBaseURL.absoluteString
        guard loadedConnectionKey != key else { return }
        loadTask?.cancel()
        loadTask = Task { await loadAgentUI(connection: connection) }
    }

    private func loadAgentUI(connection: ProAgentConnection) async {
        let key = connection.uiBaseURL.absoluteString
        trustedOrigins.register(connection.uiBaseURL)
        overlayStatus = "Loading agent workspace"
        // DEBUG acceptance: default new drafts to a chosen engine so a scripted
        // keystroke-send exercises the goose path (the web engine chip is
        // AX-opaque to scripting). Production loads the bare URL.
        var loadURL = connection.uiBaseURL
        #if DEBUG
        if let engine = ProcessInfo.processInfo.environment["EPISTEMOS_DEFAULT_ENGINE"],
           engine == "goose" || engine == "opencode",
           var comps = URLComponents(url: connection.uiBaseURL, resolvingAgainstBaseURL: false) {
            comps.queryItems = (comps.queryItems ?? []) + [URLQueryItem(name: "epistemosDefaultEngine", value: engine)]
            loadURL = comps.url ?? connection.uiBaseURL
        }
        #endif
        // Perf doctrine §4: spa_ready = load driven -> render probe "ready".
        let spaClockStart = ContinuousClock.now
        let spaSignpostID = Sig.agentSurface.makeSignpostID()
        let spaSignpostState = Sig.agentSurface.beginInterval("spa_ready", id: spaSignpostID)
        var spaRecorded = false
        defer {
            if !spaRecorded {
                Sig.agentSurface.endInterval("spa_ready", spaSignpostState)
            }
        }
        var renderAttempt = 0
        // Circuit breaker (MED-8): a permanently-blank SPA (JS boot error, bad
        // bundle) must not reload every ~15s forever. Bound the reloads and
        // then leave an honest placeholder; the status observer still drives a
        // fresh load if readiness later arrives.
        while !Task.isCancelled && renderAttempt < Self.maxRuntimeRetryAttempts {
            _ = page.load(URLRequest(url: loadURL))
            if await waitForRenderedUI() {
                loadedConnectionKey = key
                overlayStatus = nil
                let elapsed = ContinuousClock.now - spaClockStart
                Sig.agentSurface.endInterval("spa_ready", spaSignpostState)
                spaRecorded = true
                ProAgentPerfMetrics.shared.recordSpaReady(
                    milliseconds: Double(elapsed.components.seconds) * 1_000
                        + Double(elapsed.components.attoseconds) / 1e15
                )
                beginHealthMonitor(connection: connection)
                #if DEBUG
                // Repeatable acceptance affordance (R7): auto-present the native
                // all-chats sheet once the surface is live, so the merged-list
                // render + dual-engine fetch can be screenshot-verified without
                // a human click (the SwiftUI pill is opaque to scripted AX).
                if ProcessInfo.processInfo.environment["EPISTEMOS_OPEN_ALLCHATS"] == "1" {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    showAllChatsSheet = true
                }
                #endif
                return
            }
            // White-screen class of failure: retry the load with backoff instead
            // of stranding a blank surface (the root-caused startup race fix).
            renderAttempt += 1
            let probeDetail = (lastProbeResult ?? "no probe result").prefix(220)
            overlayStatus = "Agent workspace stayed blank (\(probeDetail)). Retry \(renderAttempt)."
            let delay = min(
                Self.initialRetryDelayNanoseconds << UInt64(min(renderAttempt, 4)),
                Self.maximumRetryDelayNanoseconds
            )
            try? await Task.sleep(nanoseconds: delay)
        }
        // Exhausted the reload budget without a ready render — stop reloading
        // and surface an honest terminal state instead of looping forever.
        if !Task.isCancelled && loadedConnectionKey == nil {
            overlayStatus = nil
            loadPlaceholder(
                status: "Agent workspace didn't finish loading. Reopen the Agent tab to retry."
            )
        }
    }

    private func waitForRenderedUI() async -> Bool {
        for _ in 0..<Self.renderProbeCount {
            guard !Task.isCancelled else { return false }
            let result = await renderProbe()
            lastProbeResult = result
            if result == "ready" { return true }
            try? await Task.sleep(nanoseconds: Self.renderProbeIntervalNanoseconds)
        }
        return false
    }

    private func renderProbe() async -> String {
        do {
            let value = try await page.callJavaScript(Self.renderProbeScript)
            return (value as? String) ?? "unexpected-probe-result"
        } catch {
            return "probe-error"
        }
    }

    private func beginHealthMonitor(connection: ProAgentConnection) {
        healthTask?.cancel()
        healthTask = Task { [uiBaseURL = connection.uiBaseURL] in
            var missedChecks = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                if await ProAgentRuntimeSupervisor.webServerAlive(uiBaseURL: uiBaseURL) {
                    missedChecks = 0
                } else {
                    missedChecks += 1
                    if missedChecks >= 3 {
                        supervisor.markRuntimeFailed("Agent web server stopped answering after the surface loaded.")
                        return
                    }
                }
            }
        }
    }

    private func scheduleRuntimeRetry() {
        guard retryTask == nil else { return }
        // Circuit breaker (MED-8): a permanently broken runtime (bad node
        // bundle, port always taken, missing binary) must not respawn three
        // children every ~45s forever — a battery drain + spawn storm. After a
        // bounded number of attempts, stop and surface an honest terminal state
        // (a fresh startSurface — e.g. leaving and re-entering the Agent tab —
        // resets retryAttempt and tries again).
        guard retryAttempt < Self.maxRuntimeRetryAttempts else {
            supervisor.stop()
            loadPlaceholder(
                status: "Agent runtime failed to start after several attempts. Reopen the Agent tab to try again."
            )
            return
        }
        let attempt = retryAttempt
        retryAttempt += 1
        let delay = min(
            Self.initialRetryDelayNanoseconds << UInt64(min(attempt, 4)),
            Self.maximumRetryDelayNanoseconds
        )
        retryTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            retryTask = nil
            guard !Self.isRunningTests else { return }
            loadPlaceholder(status: Self.startingStatus)
            supervisor.stop()
            supervisor.start()
            await loadWhenReady()
        }
    }

    /// Pill-nav rule (§13.5): native chrome intents become a window
    /// CustomEvent inside the LIVE page — never a URL load.
    private func handleChromeIntent(_ note: Notification) {
        guard loadedConnectionKey != nil,
              let rawType = note.userInfo?["type"] as? String else { return }
        let type = String(rawType.prefix(64))
        let sessionId = (note.userInfo?["sessionId"] as? String).map { String($0.prefix(128)) }
        var detail: [String: String] = ["type": type]
        if let sessionId { detail["sessionId"] = sessionId }
        guard let payload = try? JSONSerialization.data(withJSONObject: detail),
              let json = String(data: payload, encoding: .utf8) else { return }
        let script = "window.dispatchEvent(new CustomEvent('epistemos-chrome-intent', { detail: \(json) }));"
        Task { @MainActor in
            _ = try? await page.callJavaScript(script)
        }
    }

    private func loadPlaceholder(status: String) {
        _ = page.load(html: Self.placeholderHTML(status: status))
    }

    nonisolated static func placeholderHTML(status: String) -> String {
        let safeStatus = status
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .prefix(512)
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
          :root { color-scheme: light dark; }
          html, body { margin: 0; height: 100%; background: transparent; }
          body { display: flex; align-items: center; justify-content: center;
                 font: 13px -apple-system, system-ui, sans-serif; color: #8a8f98; }
          .card { max-width: 560px; padding: 0 24px; text-align: left; }
          .title { font-weight: 600; font-size: 16px; color: #b7bcc4; margin-bottom: 8px; }
          @media (prefers-color-scheme: light) {
            body { color: #6a6f78; } .title { color: #3c4048; }
          }
        </style>
        </head>
        <body>
          <div class="card">
            <div class="title">Epistemos Agent</div>
            <div>\(safeStatus)</div>
          </div>
        </body>
        </html>
        """
    }
}
#endif
