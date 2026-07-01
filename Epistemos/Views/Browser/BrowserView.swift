import AppKit
import Observation
import SwiftUI
import WebKit

nonisolated enum BrowserURLGuard {
    static let searchTemplate = "https://duckduckgo.com/?q=%@"
    static let maxRawInputLength = 4096
    private static let allowedSchemes: Set<String> = ["http", "https"]
    private static let explicitlyBlockedSchemes: Set<String> = [
        "data",
        "file",
        "javascript",
        "mailto",
        "tel",
    ]

    static func resolve(raw: String, searchTemplate: String = Self.searchTemplate) -> URL? {
        let bounded = String(raw.prefix(maxRawInputLength + 1))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= maxRawInputLength else { return nil }

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

nonisolated enum BrowserDisplayPolicy {
    static let maxAddressLength = 4096
    static let maxTitleLength = 256
    static let maxErrorLength = 512

    static func address(for url: URL) -> String {
        capped(url.absoluteString, limit: maxAddressLength)
    }

    static func title(_ rawTitle: String?) -> String {
        let title = rawTitle.map { trimmedCapped($0, limit: maxTitleLength) } ?? ""
        guard !title.isEmpty else {
            return "Browser"
        }
        return title
    }

    static func error(_ message: String) -> String {
        trimmedCapped(message, limit: maxErrorLength)
    }

    private static func capped(_ value: String, limit: Int) -> String {
        let bounded = String(value.prefix(limit + 1))
        guard bounded.count > limit else {
            return bounded
        }
        guard limit > 3 else {
            return String(bounded.prefix(limit))
        }
        return String(bounded.prefix(limit - 3)) + "..."
    }

    private static func trimmedCapped(_ value: String, limit: Int) -> String {
        let bounded = String(value.prefix(limit + 32))
        return capped(bounded.trimmingCharacters(in: .whitespacesAndNewlines), limit: limit)
    }
}

nonisolated enum BrowserNavigationErrorPolicy {
    static func userVisibleMessage(for error: Error) -> String? {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           nsError.code == NSURLErrorCancelled {
            return nil
        }
        return BrowserDisplayPolicy.error(
            "Navigation failed (domain=\(safeDomain(nsError.domain)) code=\(nsError.code))"
        )
    }

    private static func safeDomain(_ domain: String) -> String {
        let bounded = String(domain.prefix(96))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Error" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Error"
        }
        guard trimmed.count <= 80 else {
            let end = trimmed.index(trimmed.startIndex, offsetBy: 80)
            return String(trimmed[..<end])
        }
        return trimmed
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
        address = BrowserDisplayPolicy.address(for: url)
        loadURL?(url)
    }

    func navigate(to url: URL) {
        guard BrowserURLGuard.allows(url: url) else {
            lastError = "Blocked non-web navigation."
            return
        }
        lastError = nil
        address = BrowserDisplayPolicy.address(for: url)
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
    private var warningTint: Color { theme.resolved.headingAccent.color }

    var body: some View {
        @Bindable var tab = tab

        VStack(spacing: 0) {
            HStack(spacing: 8) {
                IntegrationBrandMarkView(brand: .browser, size: 18)
                    .foregroundStyle(theme.resolved.mutedForeground.color)

                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: "chevron.left",
                    role: .toolbarUtility,
                    chromePolicy: .bareUntilPressed,
                    helpText: "Back",
                    accessibilityLabel: "Back"
                ) {
                    tab.back()
                }
                .disabled(!tab.canGoBack)

                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: "chevron.right",
                    role: .toolbarUtility,
                    chromePolicy: .bareUntilPressed,
                    helpText: "Forward",
                    accessibilityLabel: "Forward"
                ) {
                    tab.forward()
                }
                .disabled(!tab.canGoForward)

                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: tab.isLoading ? "xmark" : "arrow.clockwise",
                    role: tab.isLoading ? .secondaryGhost : .toolbarUtility,
                    isActive: tab.isLoading,
                    chromePolicy: .bareUntilPressed,
                    helpText: tab.isLoading ? "Stop" : "Reload",
                    accessibilityLabel: tab.isLoading ? "Stop" : "Reload"
                ) {
                    tab.isLoading ? tab.stop() : tab.reload()
                }

                HStack(spacing: 7) {
                    Image(systemName: addressIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.resolved.mutedForeground.color)

                    TextField("Search or enter website", text: $tab.address)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .focused($addressFocused)
                        .onSubmit { tab.submitAddress() }

                    ToolbarCapsuleButton(
                        title: nil,
                        systemImage: "arrow.right.circle.fill",
                        role: .primaryAction,
                        isActive: addressFocused,
                        chromePolicy: .bareUntilPressed,
                        helpText: "Go",
                        accessibilityLabel: "Go"
                    ) {
                        tab.submitAddress()
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(theme.resolved.card.color.opacity(theme.isDark ? 0.74 : 0.92))
                }

                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: "info.circle",
                    role: .toolbarUtility,
                    chromePolicy: .bareUntilPressed,
                    helpText: "Browser limits",
                    accessibilityLabel: "Browser limits"
                ) {
                    showingLimits.toggle()
                }
                .popover(isPresented: $showingLimits, arrowEdge: .bottom) {
                    BrowserLimitsPopover()
                        .padding(14)
                        .frame(width: 300, alignment: .leading)
                }
            }
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
                .foregroundStyle(warningTint)
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
            Text("Common tracker and ad domains are blocked with a local WebKit content rule list.")
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
        configuration.userContentController = WKUserContentController()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        BrowserTrackerContentBlocker.install(on: configuration.userContentController)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.setValue(false, forKey: "drawsBackground")

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
                    Task { @MainActor in self?.tab?.title = BrowserDisplayPolicy.title(view.title) }
                },
                webView.observe(\.url, options: [.initial, .new]) { [weak self] view, _ in
                    Task { @MainActor in
                        self?.tab?.currentURL = view.url
                        if let url = view.url, BrowserURLGuard.allows(url: url) {
                            self?.tab?.address = BrowserDisplayPolicy.address(for: url)
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
            tab?.title = BrowserDisplayPolicy.title(webView.title)
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
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void
        ) {
            guard BrowserURLGuard.allows(url: navigationResponse.response.url) else {
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
            if navigationAction.targetFrame == nil {
                guard BrowserURLGuard.allows(url: navigationAction.request.url) else {
                    tab?.lastError = "Blocked non-web navigation."
                    return nil
                }
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
