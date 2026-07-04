#if !EPISTEMOS_APP_STORE
import SwiftUI
import WebKit

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
    nonisolated static let startingStatus = "Agent starting. Booting the workspace runtime."

    /// Ready when React has replaced the donor's #initial-loading placeholder
    /// inside #root (the mount contract verified in the vendored dist).
    nonisolated static let renderProbeScript = """
    (() => {
      const root = document.getElementById('root');
      if (!root) return 'no-root';
      if (document.getElementById('initial-loading')) return 'initial-loading';
      if (root.children.length === 0) return 'empty-root';
      return 'ready';
    })()
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

    private var supervisor: ProAgentRuntimeSupervisor { .shared }

    init(theme: EpistemosTheme = .nativeDefault) {
        self.theme = theme
        let trustedOrigins = ProAgentTrustedLoopbackOrigins()
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.defaultNavigationPreferences.allowsContentJavaScript = true
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
        }
        .ignoresSafeArea()
        .task { await startSurface() }
        .onChange(of: supervisor.status) { _, status in
            handleRuntimeStatusChange(status)
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
            beginHealthMonitor(connection: connection)
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
        var renderAttempt = 0
        while !Task.isCancelled {
            _ = page.load(URLRequest(url: connection.uiBaseURL))
            if await waitForRenderedUI() {
                loadedConnectionKey = key
                overlayStatus = nil
                beginHealthMonitor(connection: connection)
                return
            }
            // White-screen class of failure: retry the load with backoff instead
            // of stranding a blank surface (the root-caused startup race fix).
            renderAttempt += 1
            overlayStatus = "Agent workspace stayed blank. Retry \(renderAttempt)."
            let delay = min(
                Self.initialRetryDelayNanoseconds << UInt64(min(renderAttempt, 4)),
                Self.maximumRetryDelayNanoseconds
            )
            try? await Task.sleep(nanoseconds: delay)
        }
    }

    private func waitForRenderedUI() async -> Bool {
        for _ in 0..<Self.renderProbeCount {
            guard !Task.isCancelled else { return false }
            if await renderProbe() == "ready" { return true }
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
