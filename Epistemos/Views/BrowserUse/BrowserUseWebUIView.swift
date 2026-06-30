import AppKit
import SwiftUI
import WebKit

nonisolated enum BrowserUseLoopbackGuard {
    private static let maxNavigationDiagnosticLength = 120

    static func allows(url: URL?) -> Bool {
        BrowserUseLoopbackPolicy.allows(url: url)
    }

    static func allows(url: URL?, matchingOriginOf originURL: URL) -> Bool {
        guard let origin = BrowserUseLoopbackPolicy.origin(for: originURL) else {
            return false
        }
        return origin.allows(url: url)
    }

    static func redactedDescription(for url: URL) -> String {
        let sourceComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let scheme = sourceComponents?.scheme ?? url.scheme,
           let host = sourceComponents?.host ?? url.host,
           !host.isEmpty {
            var displayComponents = URLComponents()
            displayComponents.scheme = scheme
            displayComponents.host = host
            displayComponents.port = sourceComponents?.port ?? url.port
            return capped(displayComponents.string ?? "\(scheme)://\(host)")
        }

        if let scheme = (sourceComponents?.scheme ?? url.scheme)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !scheme.isEmpty {
            return capped("\(scheme) URL")
        }

        return "[blocked URL]"
    }

    private static func capped(_ value: String) -> String {
        guard value.count > maxNavigationDiagnosticLength else {
            return value
        }
        return String(value.prefix(maxNavigationDiagnosticLength)) + "..."
    }
}

nonisolated enum BrowserUseStatusTone {
    case ready
    case warning
    case info
    case muted
    case problem

    func color(in theme: EpistemosTheme) -> Color {
        switch self {
        case .ready:
            return theme.resolved.accent.color
        case .warning:
            return theme.resolved.headingAccent.color
        case .info:
            return theme.resolved.uiAccent.color
        case .muted:
            return theme.resolved.mutedForeground.color
        case .problem:
            return theme.resolved.headingAccent.color
        }
    }
}

struct BrowserUseWebUIView: View {
    @Environment(UIState.self) private var ui
    private let settingsStore: BrowserUseSettingsStore
    private let host: String
    private let port: Int
    private let themeName: String
    @State private var supervisor: BrowserUseRuntimeSupervisor?
    @State private var settings: BrowserUseSettings
    @State private var readiness: BrowserUseRuntimeReadiness
    @State private var loadedURL: URL?
    @State private var isStarting = false
    @State private var startRequestID = UUID()
    @State private var startTask: Task<Void, Never>?
    @State private var startWorker: Task<(BrowserUseRuntimeLaunchPlan?, String?), Never>?
    @State private var readinessRequestID = UUID()
    @State private var readinessTask: Task<Void, Never>?
    @State private var readinessWorker: Task<(BrowserUseSettings, BrowserUseRuntimeReadiness), Never>?
    @State private var blockedNavigationDescription: String?
    @State private var lastError: String?
    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    init(
        supervisor: BrowserUseRuntimeSupervisor? = BrowserUseRuntimeSupervisor(),
        settingsStore: BrowserUseSettingsStore = BrowserUseSettingsStore(),
        host: String = "127.0.0.1",
        port: Int = 7788,
        themeName: String = "Ocean"
    ) {
        self.settingsStore = settingsStore
        self.host = host
        self.port = port
        self.themeName = themeName
        _supervisor = State(initialValue: supervisor)
        _settings = State(initialValue: .default)
        _readiness = State(initialValue: .unavailable("Checking browser-use Pro readiness."))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if let loadedURL {
                BrowserUseLoopbackWebView(url: loadedURL, theme: theme) { url in
                    let description = BrowserUseLoopbackGuard.redactedDescription(for: url)
                    blockedNavigationDescription = description
                    lastError = "Blocked non-loopback browser-use navigation: \(description)"
                }
            } else {
                unavailableView
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .background {
            SettingsThemedBlurBackdrop(theme: theme, role: .page)
        }
        .onAppear {
            refreshReadiness()
        }
        .onDisappear {
            stopRuntime()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "network")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("browser-use Pro")
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusTint(readiness.isReady ? .muted : .warning))
                    .lineLimit(2)
            }

            Spacer()

            if let blockedNavigationDescription {
                Text(blockedNavigationDescription)
                    .font(.caption.monospaced())
                    .foregroundStyle(statusTint(.warning))
                    .lineLimit(1)
            }

            Button {
                refreshReadiness()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh browser-use Pro readiness")

            Button {
                startRuntime()
            } label: {
                Label("Open", systemImage: "play.fill")
            }
            .disabled(!readiness.isReady || isStarting)
            .help(readiness.isReady ? "Open browser-use Pro Web UI" : readiness.message)

            Button {
                stopRuntime()
            } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.borderless)
            .disabled(loadedURL == nil)
            .help("Stop browser-use Pro runtime")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            SettingsThemedBlurBackdrop(theme: theme, role: .sidebar)
        }
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: readiness.isReady ? "play.circle" : "lock.shield")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(statusTint(readiness.isReady ? .muted : .warning))
            Text(readiness.isReady ? "browser-use Pro is ready." : "browser-use Pro is unavailable.")
                .font(.headline)
            Text(lastError ?? readiness.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var statusText: String {
        if let loadedURL {
            return loadedURL.absoluteString
        }
        return readiness.message
    }

    private func statusTint(_ tone: BrowserUseStatusTone) -> Color {
        tone.color(in: theme)
    }

    private func refreshReadiness() {
        readinessTask?.cancel()
        readinessWorker?.cancel()

        let requestID = UUID()
        readinessRequestID = requestID

        let settingsStore = settingsStore
        let supervisor = supervisor
        let host = host
        let port = port
        let themeName = themeName
        let worker = Task.detached(priority: .userInitiated) { () -> (BrowserUseSettings, BrowserUseRuntimeReadiness) in
            let loadedSettings: BrowserUseSettings
            do {
                loadedSettings = try settingsStore.load()
            } catch {
                let message = BrowserUseDiagnostics.statusMessage(
                    for: error,
                    fallback: "settings load failed"
                )
                return (
                    .default,
                    .unavailable("browser-use Pro settings could not be loaded: \(message)")
                )
            }
            guard !Task.isCancelled else {
                return (loadedSettings, .unavailable("browser-use Pro readiness refresh was cancelled."))
            }
            let loadedReadiness = supervisor?.readiness(
                settings: loadedSettings,
                host: host,
                port: port,
                theme: themeName
            ) ?? .unavailable("browser-use Pro runtime source is not installed.")
            return (loadedSettings, loadedReadiness)
        }

        readinessWorker = worker
        readinessTask = Task { @MainActor in
            let outcome = await worker.value
            guard !Task.isCancelled, readinessRequestID == requestID else { return }
            settings = outcome.0
            readiness = outcome.1
            readinessTask = nil
            readinessWorker = nil
            if !readiness.isReady {
                cancelStartAttempt()
                supervisor?.stop()
                loadedURL = nil
                blockedNavigationDescription = nil
            }
        }
    }

    private func startRuntime() {
        guard let supervisor else {
            readiness = .unavailable("browser-use Pro runtime source is not installed.")
            loadedURL = nil
            return
        }

        startTask?.cancel()
        startWorker?.cancel()

        let requestID = UUID()
        startRequestID = requestID
        isStarting = true
        blockedNavigationDescription = nil
        lastError = nil

        let settings = settings
        let host = host
        let port = port
        let themeName = themeName
        let worker = Task.detached(priority: .userInitiated) { [supervisor, settings, host, port, themeName] () -> (BrowserUseRuntimeLaunchPlan?, String?) in
            do {
                let plan = try supervisor.start(
                    settings: settings,
                    host: host,
                    port: port,
                    theme: themeName,
                    shouldCancel: { Task.isCancelled }
                )
                guard !Task.isCancelled else { return (nil, nil) }
                return (plan, nil)
            } catch is CancellationError {
                return (nil, nil)
            } catch {
                let message = BrowserUseDiagnostics.statusMessage(
                    for: error,
                    fallback: "runtime start failed"
                )
                return (nil, message)
            }
        }

        startWorker = worker
        startTask = Task { @MainActor in
            let outcome = await worker.value
            guard !Task.isCancelled, startRequestID == requestID else { return }
            isStarting = false
            startTask = nil
            startWorker = nil

            if let plan = outcome.0 {
                guard BrowserUseLoopbackGuard.allows(url: plan.loopbackURL) else {
                    let message = "browser-use Pro returned a non-loopback URL."
                    supervisor.stop()
                    loadedURL = nil
                    lastError = message
                    readiness = .unavailable(message)
                    return
                }
                blockedNavigationDescription = nil
                lastError = nil
                loadedURL = plan.loopbackURL
                readiness = .ready(plan)
                return
            }

            if let message = outcome.1 {
                loadedURL = nil
                lastError = message
                readiness = .unavailable(message)
            }
        }
    }

    private func stopRuntime() {
        readinessTask?.cancel()
        readinessWorker?.cancel()
        readinessTask = nil
        readinessWorker = nil
        readinessRequestID = UUID()
        cancelStartAttempt()
        supervisor?.stop()
        loadedURL = nil
        blockedNavigationDescription = nil
    }

    private func cancelStartAttempt() {
        startTask?.cancel()
        startWorker?.cancel()
        startTask = nil
        startWorker = nil
        startRequestID = UUID()
        isStarting = false
    }
}

struct BrowserUseLoopbackWebView: NSViewRepresentable {
    let url: URL
    let theme: EpistemosTheme
    let onBlockedNavigation: (URL) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        BrowserUseWebTheme.installStartupScript(for: theme, in: userContentController)
        configuration.userContentController = userContentController
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.appearance = BrowserUseWebTheme.appearance(for: theme)
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.clear.cgColor
        context.coordinator.registerStartupTheme(theme)
        context.coordinator.allowedOrigin = BrowserUseLoopbackPolicy.origin(for: url)
        context.coordinator.onBlockedNavigation = onBlockedNavigation
        load(url, into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.allowedOrigin = BrowserUseLoopbackPolicy.origin(for: url)
        context.coordinator.onBlockedNavigation = onBlockedNavigation
        context.coordinator.applyTheme(theme, to: webView)
        guard webView.url != url else { return }
        load(url, into: webView)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.configuration.userContentController.removeAllUserScripts()
        coordinator.shutdown()
        coordinator.onBlockedNavigation = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func load(_ url: URL, into webView: WKWebView) {
        guard BrowserUseLoopbackGuard.allows(url: url, matchingOriginOf: self.url) else {
            onBlockedNavigation(url)
            return
        }
        webView.load(URLRequest(url: url))
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var allowedOrigin: BrowserUseLoopbackOrigin?
        var onBlockedNavigation: ((URL) -> Void)?
        private var isDetached = false
        private var installedStartupTheme: EpistemosTheme?
        private var requestedTheme: EpistemosTheme?
        private var pendingTheme: EpistemosTheme?
        private var lastAppliedTheme: EpistemosTheme?

        func registerStartupTheme(_ theme: EpistemosTheme) {
            installedStartupTheme = theme
            requestedTheme = theme
            pendingTheme = theme
        }

        func applyTheme(_ theme: EpistemosTheme, to webView: WKWebView) {
            guard !isDetached else { return }
            requestedTheme = theme
            webView.appearance = BrowserUseWebTheme.appearance(for: theme)
            webView.layer?.backgroundColor = NSColor.clear.cgColor
            if installedStartupTheme != theme {
                BrowserUseWebTheme.installStartupScript(for: theme, in: webView.configuration.userContentController)
                installedStartupTheme = theme
            }
            guard lastAppliedTheme != theme else { return }
            guard !webView.isLoading else {
                pendingTheme = theme
                return
            }
            applyThemeScript(theme, to: webView)
        }

        func shutdown() {
            isDetached = true
            pendingTheme = nil
            requestedTheme = nil
            lastAppliedTheme = nil
            installedStartupTheme = nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard allowsNavigation(to: navigationAction.request.url) else {
                if let url = navigationAction.request.url {
                    onBlockedNavigation?(url)
                }
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil,
                  let url = navigationAction.request.url else {
                return nil
            }

            if allowsNavigation(to: url) {
                webView.load(URLRequest(url: url))
            } else {
                onBlockedNavigation?(url)
            }
            return nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            lastAppliedTheme = nil
            if let requestedTheme {
                pendingTheme = requestedTheme
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            flushPendingTheme(in: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            pendingTheme = nil
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            pendingTheme = nil
        }

        private func allowsNavigation(to url: URL?) -> Bool {
            guard let allowedOrigin else {
                return false
            }
            return allowedOrigin.allows(url: url)
        }

        private func applyThemeScript(_ theme: EpistemosTheme, to webView: WKWebView) {
            guard !isDetached else { return }
            lastAppliedTheme = theme
            pendingTheme = nil
            webView.evaluateJavaScript(
                BrowserUseWebTheme.applyScript(for: theme),
                completionHandler: nil
            )
        }

        private func flushPendingTheme(in webView: WKWebView) {
            guard !isDetached, !webView.isLoading else { return }
            let theme = pendingTheme ?? requestedTheme
            guard let theme, lastAppliedTheme != theme else {
                pendingTheme = nil
                return
            }
            applyThemeScript(theme, to: webView)
        }
    }
}

private enum BrowserUseWebTheme {
    private static let styleElementID = "epistemos-browser-use-theme"

    static func appearance(for theme: EpistemosTheme) -> NSAppearance? {
        NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
    }

    static func installStartupScript(for theme: EpistemosTheme, in userContentController: WKUserContentController) {
        userContentController.addUserScript(
            WKUserScript(
                source: applyScript(for: theme),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
    }

    static func applyScript(for theme: EpistemosTheme) -> String {
        let css = stylesheet(for: theme)
        return """
        (function(){
          const css = \(jsStringLiteral(css));
          const themeName = \(jsStringLiteral(theme.rawValue));
          const themeIsDark = \(theme.isDark ? "true" : "false");
          window.__epistemosBrowserUseThemeState = { css, themeName, themeIsDark };

          function applyStyle(root, state) {
            if (!root || !root.querySelector) return;
            let style = root.querySelector("#\(styleElementID)");
            if (!style) {
              style = document.createElement("style");
              style.id = "\(styleElementID)";
              const target = root.head || root.documentElement || root.body || (root.nodeType === Node.DOCUMENT_FRAGMENT_NODE ? root : null);
              if (!target || !target.appendChild) return;
              target.appendChild(style);
            }
            if (style.textContent !== state.css) {
              style.textContent = state.css;
            }
          }

          window.__epistemosBrowserUseThemeApply = function() {
            const state = window.__epistemosBrowserUseThemeState;
            if (!state) return;
            const documentRoot = document.documentElement;
            if (documentRoot) {
              documentRoot.dataset.epistemosTheme = state.themeName;
              documentRoot.dataset.epistemosThemeDark = String(state.themeIsDark);
            }
            applyStyle(document, state);
            document.querySelectorAll("*").forEach(function(node) {
              if (node.shadowRoot) applyStyle(node.shadowRoot, state);
            });
          };

          window.__epistemosBrowserUseThemeApply();
          if (!window.__epistemosBrowserUseThemeObserver) {
            let scheduled = false;
            const scheduleApply = function() {
              if (scheduled) return;
              scheduled = true;
              requestAnimationFrame(function() {
                scheduled = false;
                if (window.__epistemosBrowserUseThemeApply) {
                  window.__epistemosBrowserUseThemeApply();
                }
              });
            };
            const observer = new MutationObserver(scheduleApply);
            observer.observe(document.documentElement || document, { childList: true, subtree: true });
            window.__epistemosBrowserUseThemeObserver = observer;
          }
        })();
        """
    }

    private static func stylesheet(for theme: EpistemosTheme) -> String {
        let resolved = theme.resolved
        let foreground = cssColor(resolved.foreground.nsColor)
        let mutedForeground = cssColor(resolved.mutedForeground.nsColor)
        let accent = cssColor(resolved.accent.nsColor)
        let accentSoft = cssColor(resolved.accent.nsColor.withAlphaComponent(theme.isDark ? 0.28 : 0.18))
        let headingAccent = cssColor(resolved.headingAccent.nsColor)
        let border = cssColor(resolved.border.nsColor)
        let card = cssColor(resolved.card.nsColor)
        let control = cssColor(resolved.glassBg.nsColor)
        let controlHover = cssColor(resolved.glassHover.nsColor)
        let code = cssColor(resolved.codeType.nsColor)
        let onAccent = cssColor(resolved.userBubbleText.nsColor)
        let colorScheme = theme.isDark ? "dark" : "light"

        return """
        :root, :host, gradio-app {
          color-scheme: \(colorScheme);
          --epistemos-browser-bg: transparent;
          --epistemos-browser-text: \(foreground);
          --epistemos-browser-muted: \(mutedForeground);
          --epistemos-browser-accent: \(accent);
          --epistemos-browser-accent-soft: \(accentSoft);
          --epistemos-browser-heading: \(headingAccent);
          --epistemos-browser-border: \(border);
          --epistemos-browser-card: \(card);
          --epistemos-browser-control: \(control);
          --epistemos-browser-control-hover: \(controlHover);
          --epistemos-browser-code: \(code);
          --epistemos-browser-on-accent: \(onAccent);
          --body-background-fill: transparent;
          --background-fill-primary: transparent;
          --background-fill-secondary: var(--epistemos-browser-card);
          --block-background-fill: var(--epistemos-browser-card);
          --block-border-color: var(--epistemos-browser-border);
          --body-text-color: var(--epistemos-browser-text);
          --body-text-color-subdued: var(--epistemos-browser-muted);
          --link-text-color: var(--epistemos-browser-accent);
          --color-accent: var(--epistemos-browser-accent);
          --button-primary-background-fill: var(--epistemos-browser-accent);
          --button-primary-text-color: var(--epistemos-browser-on-accent);
          --input-background-fill: var(--epistemos-browser-control);
          --input-border-color: var(--epistemos-browser-border);
          --radius-lg: 8px;
          --radius-md: 7px;
          --radius-sm: 6px;
        }

        html, body, gradio-app {
          background: transparent !important;
          color: var(--epistemos-browser-text) !important;
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif !important;
        }

        body, main, footer, .main, .wrap, .gradio-container, .contain, .app, .app.svelte-182fdeq {
          background: transparent !important;
        }

        .gradio-container {
          color: var(--epistemos-browser-text) !important;
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif !important;
        }

        h1, h2, h3, h4, h5, h6, label, legend {
          color: var(--epistemos-browser-heading) !important;
          letter-spacing: 0 !important;
        }

        p, span, div, label, textarea, input, select, button {
          font-family: inherit !important;
        }

        a {
          color: var(--epistemos-browser-accent) !important;
        }

        button, input, textarea, select, .block, .form, .panel, .tabs, .tab-nav, .input-container {
          border-color: var(--epistemos-browser-border) !important;
          border-radius: 8px !important;
        }

        input, textarea, select, .input-container, .block, .form, .panel, .tabitem {
          background: var(--epistemos-browser-control) !important;
          color: var(--epistemos-browser-text) !important;
        }

        button, .secondary-button {
          background: var(--epistemos-browser-control) !important;
          color: var(--epistemos-browser-text) !important;
        }

        button:hover, .secondary-button:hover {
          background: var(--epistemos-browser-control-hover) !important;
        }

        button.primary, button[class*="primary"], .primary {
          background: var(--epistemos-browser-accent) !important;
          color: var(--epistemos-browser-on-accent) !important;
          border-color: var(--epistemos-browser-accent) !important;
        }

        .selected, [aria-selected="true"], .tab-nav button.selected {
          background: var(--epistemos-browser-accent-soft) !important;
          color: var(--epistemos-browser-text) !important;
          border-color: var(--epistemos-browser-accent) !important;
        }

        pre, code, .prose pre, .prose code {
          background: var(--epistemos-browser-card) !important;
          color: var(--epistemos-browser-code) !important;
          border-color: var(--epistemos-browser-border) !important;
          border-radius: 8px !important;
        }

        *:focus-visible {
          outline: 2px solid var(--epistemos-browser-accent) !important;
          outline-offset: 2px !important;
        }
        """
    }

    private static func cssColor(_ color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let red = min(max(Int((rgb.redComponent * 255).rounded()), 0), 255)
        let green = min(max(Int((rgb.greenComponent * 255).rounded()), 0), 255)
        let blue = min(max(Int((rgb.blueComponent * 255).rounded()), 0), 255)
        let alpha = rgb.alphaComponent
        if alpha >= 0.999 {
            return String(format: "#%02X%02X%02X", red, green, blue)
        }
        return String(format: "rgba(%d, %d, %d, %.3f)", red, green, blue, alpha)
    }
}
