import AppKit
import SwiftUI
import WebKit

nonisolated enum BrowserUseLoopbackGuard {
    static func allows(url: URL?) -> Bool {
        BrowserUseLoopbackPolicy.allows(url: url)
    }

    static func allows(url: URL?, matchingOriginOf originURL: URL) -> Bool {
        guard let origin = BrowserUseLoopbackPolicy.origin(for: originURL) else {
            return false
        }
        return origin.allows(url: url)
    }
}

struct BrowserUseWebUIView: View {
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
    @State private var blockedURL: URL?
    @State private var lastError: String?

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
                BrowserUseLoopbackWebView(url: loadedURL) { url in
                    blockedURL = url
                    lastError = "Blocked non-loopback browser-use navigation: \(url.absoluteString)"
                }
            } else {
                unavailableView
            }
        }
        .frame(minWidth: 720, minHeight: 520)
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
                    .foregroundStyle(readiness.isReady ? Color.secondary : Color.orange)
                    .lineLimit(2)
            }

            Spacer()

            if let blockedURL {
                Text(blockedURL.host ?? blockedURL.absoluteString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.orange)
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
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: readiness.isReady ? "play.circle" : "lock.shield")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(readiness.isReady ? Color.secondary : Color.orange)
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
                return (
                    .default,
                    .unavailable("browser-use Pro settings could not be loaded: \(error.localizedDescription)")
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
                return (nil, error.localizedDescription)
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
                blockedURL = nil
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
    let onBlockedNavigation: (URL) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        context.coordinator.allowedOrigin = BrowserUseLoopbackPolicy.origin(for: url)
        context.coordinator.onBlockedNavigation = onBlockedNavigation
        load(url, into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.allowedOrigin = BrowserUseLoopbackPolicy.origin(for: url)
        context.coordinator.onBlockedNavigation = onBlockedNavigation
        guard webView.url != url else { return }
        load(url, into: webView)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
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

        private func allowsNavigation(to url: URL?) -> Bool {
            guard let allowedOrigin else {
                return false
            }
            return allowedOrigin.allows(url: url)
        }
    }
}
