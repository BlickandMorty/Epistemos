import AppKit
import Observation
import SwiftUI
import WebKit

nonisolated enum BrowserURLGuard {
    static let searchTemplate = "https://duckduckgo.com/?q=%@"
    private static let allowedSchemes: Set<String> = ["http", "https"]
    private static let explicitlyBlockedSchemes: Set<String> = [
        "data",
        "file",
        "javascript",
        "mailto",
        "tel",
    ]

    static func resolve(raw: String, searchTemplate: String = Self.searchTemplate) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            if allows(url: url) {
                return url
            }
            if trimmed.contains("://") || hasBlockedExplicitScheme(trimmed) {
                return nil
            }
        }

        if hasBlockedExplicitScheme(trimmed) || hasUnsupportedAbsoluteScheme(trimmed) {
            return nil
        }

        if looksLikeHost(trimmed),
           let url = URL(string: "https://\(trimmed)"),
           allows(url: url) {
            return url
        }

        return searchURL(for: trimmed, template: searchTemplate)
    }

    static func allows(url: URL?) -> Bool {
        guard let url,
              let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme),
              url.host?.isEmpty == false,
              (url.user?.isEmpty ?? true),
              (url.password?.isEmpty ?? true) else {
            return false
        }
        return true
    }

    private static func looksLikeHost(_ raw: String) -> Bool {
        guard raw.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return false }
        let hostCandidate = raw.split(separator: "/", maxSplits: 1).first.map(String.init) ?? raw
        return hostCandidate.contains(".")
            || hostCandidate.lowercased().hasPrefix("localhost")
            || hostCandidate.contains(":")
    }

    private static func hasBlockedExplicitScheme(_ raw: String) -> Bool {
        guard let scheme = schemePrefix(in: raw) else { return false }
        return explicitlyBlockedSchemes.contains(scheme)
    }

    private static func hasUnsupportedAbsoluteScheme(_ raw: String) -> Bool {
        guard raw.contains("://"),
              let scheme = schemePrefix(in: raw) else {
            return false
        }
        return !allowedSchemes.contains(scheme)
    }

    private static func schemePrefix(in raw: String) -> String? {
        guard let colonIndex = raw.firstIndex(of: ":") else { return nil }
        let prefix = raw[..<colonIndex].lowercased()
        guard !prefix.isEmpty,
              prefix.first?.isLetter == true,
              prefix.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }) else {
            return nil
        }
        return String(prefix)
    }

    private static func searchURL(for query: String, template: String) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
        let url = URL(string: String(format: template, encoded))
        return allows(url: url) ? url : nil
    }
}

nonisolated enum BrowserNavigationErrorPolicy {
    static func userVisibleMessage(for error: Error) -> String? {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           nsError.code == NSURLErrorCancelled {
            return nil
        }
        return error.localizedDescription
    }
}

@MainActor @Observable
final class BrowserTab {
    var address = "https://www.apple.com"
    var currentURL: URL?
    var title = "Browser"
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var progress = 0.0
    var lastError: String?

    @ObservationIgnored var loadURL: ((URL) -> Void)?
    @ObservationIgnored var goBack: (() -> Void)?
    @ObservationIgnored var goForward: (() -> Void)?
    @ObservationIgnored var reloadPage: (() -> Void)?
    @ObservationIgnored var stopLoading: (() -> Void)?

    func submitAddress() {
        guard let url = BrowserURLGuard.resolve(raw: address) else {
            lastError = "Browser only opens http and https pages."
            return
        }
        lastError = nil
        address = url.absoluteString
        loadURL?(url)
    }

    func navigate(to url: URL) {
        guard BrowserURLGuard.allows(url: url) else {
            lastError = "Blocked non-web navigation."
            return
        }
        lastError = nil
        address = url.absoluteString
        loadURL?(url)
    }

    func back() { goBack?() }
    func forward() { goForward?() }
    func reload() { reloadPage?() }
    func stop() { stopLoading?() }
}

struct BrowserView: View {
    @Environment(UIState.self) private var ui
    @State private var tab = BrowserTab()
    @State private var showingLimits = false
    @FocusState private var addressFocused: Bool

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.mainChat) }

    var body: some View {
        @Bindable var tab = tab

        VStack(spacing: 0) {
            HStack(spacing: 8) {
                IntegrationBrandMarkView(brand: .browser, size: 18)
                    .foregroundStyle(.secondary)

                Button {
                    tab.back()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!tab.canGoBack)
                .help("Back")

                Button {
                    tab.forward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!tab.canGoForward)
                .help("Forward")

                Button {
                    tab.isLoading ? tab.stop() : tab.reload()
                } label: {
                    Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
                }
                .help(tab.isLoading ? "Stop" : "Reload")

                HStack(spacing: 7) {
                    Image(systemName: addressIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField("Search or enter website", text: $tab.address)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .focused($addressFocused)
                        .onSubmit { tab.submitAddress() }

                    Button {
                        tab.submitAddress()
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.resolved.accent.color)
                    .help("Go")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(theme.resolved.card.color.opacity(theme.isDark ? 0.74 : 0.92))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(theme.border.opacity(theme.isDark ? 0.35 : 0.28), lineWidth: 0.8)
                }

                Button {
                    showingLimits.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .help("Browser limits")
                .popover(isPresented: $showingLimits, arrowEdge: .bottom) {
                    BrowserLimitsPopover()
                        .padding(14)
                        .frame(width: 300, alignment: .leading)
                }
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if tab.isLoading {
                ProgressView(value: tab.progress)
                    .progressViewStyle(.linear)
                    .frame(height: 2)
                    .padding(.horizontal, 12)
                    .transition(.opacity)
            }

            if let error = tab.lastError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.resolved.card.color.opacity(0.5))
            }

            BrowserWebView(tab: tab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(Rectangle())
        }
        .background(theme.resolved.background.color)
        .onAppear {
            if tab.currentURL == nil,
               let url = BrowserURLGuard.resolve(raw: tab.address) {
                tab.navigate(to: url)
            }
        }
    }

    private var addressIcon: String {
        tab.currentURL?.scheme?.lowercased() == "https" ? "lock.fill" : "globe"
    }
}

private struct BrowserLimitsPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Browser")
                .font(.headline)
            Text("Human-driven WebKit tab. Cookies and cache are isolated from Safari in memory for this in-app browser session.")
            Text("No Safari extensions. Some premium DRM video may not play in WKWebView.")
        }
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct BrowserWebView: NSViewRepresentable {
    let tab: BrowserTab

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true

        context.coordinator.attach(webView: webView, tab: tab)
        if let url = BrowserURLGuard.resolve(raw: tab.address) {
            webView.load(URLRequest(url: url))
        }
        EpdocWebViewShared.notifyWebViewCreated()
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.attach(webView: webView, tab: tab)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        coordinator.shutdown()
        EpdocWebViewShared.notifyWebViewDismantled()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private weak var webView: WKWebView?
        private weak var tab: BrowserTab?
        private var observations: [NSKeyValueObservation] = []

        func attach(webView: WKWebView, tab: BrowserTab) {
            if self.webView !== webView {
                observations.forEach { $0.invalidate() }
                observations = []
                self.webView = webView
                observe(webView)
            }
            self.tab = tab
            installCommands(webView: webView, tab: tab)
            sync(from: webView)
        }

        func shutdown() {
            observations.forEach { $0.invalidate() }
            observations = []
            tab?.loadURL = nil
            tab?.goBack = nil
            tab?.goForward = nil
            tab?.reloadPage = nil
            tab?.stopLoading = nil
            webView = nil
            tab = nil
        }

        private func installCommands(webView: WKWebView, tab: BrowserTab) {
            tab.loadURL = { [weak webView] url in
                webView?.load(URLRequest(url: url))
            }
            tab.goBack = { [weak webView] in
                webView?.goBack()
            }
            tab.goForward = { [weak webView] in
                webView?.goForward()
            }
            tab.reloadPage = { [weak webView] in
                webView?.reload()
            }
            tab.stopLoading = { [weak webView] in
                webView?.stopLoading()
            }
        }

        private func observe(_ webView: WKWebView) {
            observations = [
                webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] view, _ in
                    Task { @MainActor in self?.tab?.progress = view.estimatedProgress }
                },
                webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] view, _ in
                    Task { @MainActor in self?.tab?.isLoading = view.isLoading }
                },
                webView.observe(\.title, options: [.initial, .new]) { [weak self] view, _ in
                    Task { @MainActor in self?.tab?.title = view.title ?? "Browser" }
                },
                webView.observe(\.url, options: [.initial, .new]) { [weak self] view, _ in
                    Task { @MainActor in
                        self?.tab?.currentURL = view.url
                        if let url = view.url, BrowserURLGuard.allows(url: url) {
                            self?.tab?.address = url.absoluteString
                        }
                    }
                },
                webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] view, _ in
                    Task { @MainActor in self?.tab?.canGoBack = view.canGoBack }
                },
                webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] view, _ in
                    Task { @MainActor in self?.tab?.canGoForward = view.canGoForward }
                },
            ]
        }

        private func sync(from webView: WKWebView) {
            tab?.progress = webView.estimatedProgress
            tab?.isLoading = webView.isLoading
            tab?.title = webView.title ?? "Browser"
            tab?.currentURL = webView.url
            tab?.canGoBack = webView.canGoBack
            tab?.canGoForward = webView.canGoForward
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard BrowserURLGuard.allows(url: navigationAction.request.url) else {
                tab?.lastError = "Blocked non-web navigation."
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
            if navigationAction.targetFrame == nil,
               BrowserURLGuard.allows(url: navigationAction.request.url) {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            tab?.lastError = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab?.lastError = nil
            sync(from: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            recordNavigationFailure(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            recordNavigationFailure(error)
        }

        private func recordNavigationFailure(_ error: Error) {
            guard let message = BrowserNavigationErrorPolicy.userVisibleMessage(for: error) else {
                return
            }
            tab?.lastError = message
        }
    }
}
