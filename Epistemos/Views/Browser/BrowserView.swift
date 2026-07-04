import AppKit
import Observation
import os
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

    /// BRW-2: schemes we hand off to the system default handler (Mail, Phone)
    /// instead of loading in-webview. Deliberately a tight allowlist — NOT
    /// data/file/javascript, which stay hard-blocked.
    private static let externalHandoffSchemes: Set<String> = ["mailto", "tel"]

    static func isExternalHandoff(url: URL?) -> Bool {
        guard let scheme = url?.scheme?.lowercased() else { return false }
        return externalHandoffSchemes.contains(scheme)
    }

    static func resolve(raw: String, searchTemplate: String = Self.searchTemplate) -> URL? {
        let bounded = String(raw.prefix(maxRawInputLength + 1))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= maxRawInputLength else { return nil }

        if hasNonHostExplicitSchemePrefix(trimmed) {
            if let url = URL(string: trimmed), allows(url: url) {
                return url
            }
            return nil
        }

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

    private static func hasNonHostExplicitSchemePrefix(_ raw: String) -> Bool {
        guard let colonIndex = raw.firstIndex(of: ":"),
              let scheme = schemePrefix(in: raw) else {
            return false
        }
        let afterColon = raw.index(after: colonIndex)
        if afterColon < raw.endIndex, raw[afterColon].isWhitespace {
            return false
        }
        return !isLikelyHostPortInput(raw, colonIndex: colonIndex, scheme: scheme)
    }

    private static func isLikelyHostPortInput(_ raw: String, colonIndex: String.Index, scheme: String) -> Bool {
        guard !allowedSchemes.contains(scheme),
              !explicitlyBlockedSchemes.contains(scheme) else {
            return false
        }

        let afterColon = raw.index(after: colonIndex)
        guard afterColon < raw.endIndex else { return false }

        let remainder = raw[afterColon...]
        let portEnd = remainder.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) ?? raw.endIndex
        let portText = remainder[..<portEnd]
        guard !portText.isEmpty,
              portText.allSatisfy(\.isNumber),
              let port = Int(portText),
              (1...65_535).contains(port) else {
            return false
        }

        let host = raw[..<colonIndex]
        return !host.isEmpty
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
        // RES-5: map common URL errors to plain language so a normal user isn't left with
        // a bare "domain=… code=…".
        if nsError.domain == NSURLErrorDomain,
           let plain = plainLanguage(forURLErrorCode: nsError.code) {
            return BrowserDisplayPolicy.error(plain)
        }
        return BrowserDisplayPolicy.error(
            "Navigation failed (domain=\(safeDomain(nsError.domain)) code=\(nsError.code))"
        )
    }

    private static func plainLanguage(forURLErrorCode code: Int) -> String? {
        switch code {
        case NSURLErrorNotConnectedToInternet: return "You're offline — check your internet connection."
        case NSURLErrorTimedOut: return "The connection timed out. Try again."
        case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed: return "Server not found — check the address."
        case NSURLErrorCannotConnectToHost: return "Couldn't connect to the server."
        case NSURLErrorNetworkConnectionLost: return "The network connection was lost."
        case NSURLErrorSecureConnectionFailed,
             NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateNotYetValid,
             NSURLErrorServerCertificateHasUnknownRoot:
            return "This site's security certificate isn't valid."
        case NSURLErrorUnsupportedURL: return "That address can't be opened."
        default: return nil
        }
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
    // Opens on the custom themed home page (owner 2026-07-03) unless a URL is given.
    var address = BrowserHomePage.marker
    var currentURL: URL?
    var title = "Browser"
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var progress = 0.0
    var lastError: String?
    /// Owner 2026-07-03: the floating toolbar hides on scroll-down and reappears on
    /// scroll-up so the page can take the full window. Driven by an injected scroll
    /// listener that posts direction to the `browserScroll` message handler.
    var toolbarHidden = false
    /// RES-8 follow-up: the in-progress download so the UI can offer Cancel — a stalled
    /// download must not trap the user. Set by the coordinator; cleared on finish/fail/cancel.
    var activeDownload: WKDownload?

    @ObservationIgnored var loadURL: ((URL) -> Void)?
    @ObservationIgnored var goBack: (() -> Void)?
    @ObservationIgnored var goForward: (() -> Void)?
    @ObservationIgnored var reloadPage: (() -> Void)?
    @ObservationIgnored var stopLoading: (() -> Void)?
    @ObservationIgnored var clearData: (() -> Void)?
    /// GAP-3: capture the live page's outerHTML + innerText for a real web clip.
    @ObservationIgnored var capturePageContent: ((@escaping (String?, String?) -> Void) -> Void)?

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
    func clearBrowsingData() { clearData?() }
}

struct BrowserView: View {
    @Environment(UIState.self) private var ui
    @State private var tab: BrowserTab
    @State private var isSavingToNotes = false
    @State private var showingLimits = false
    /// Measured height of the floating toolbar → inset the page below it (owner 2026-07-03:
    /// "page below the bar" — the page is no longer hidden behind the URL bar; when the
    /// toolbar hides on scroll the inset collapses to 0 so the page still goes full-window).
    @State private var toolbarHeight: CGFloat = 0
    @FocusState private var addressFocused: Bool

    init(initialAddress: String? = nil) {
        let browserTab = BrowserTab()
        if let initialAddress, !initialAddress.isEmpty {
            browserTab.address = initialAddress
        }
        _tab = State(initialValue: browserTab)
    }

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.mainChat) }
    private var warningTint: Color { theme.resolved.headingAccent.color }

    var body: some View {
        @Bindable var tab = tab

        ZStack(alignment: .top) {
            // Web view fills the whole window; the toolbar floats over it and hides on
            // scroll so the page can take the entire window (owner 2026-07-03).
            BrowserWebView(tab: tab, theme: theme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(Rectangle())
                // Page sits BELOW the toolbar (owner: "page below the bar"); collapses to
                // full-window when the toolbar hides on scroll.
                .padding(.top, tab.toolbarHidden ? 0 : toolbarHeight)
                .animation(.easeInOut(duration: 0.28), value: tab.toolbarHidden)

            // Floating, flat toolbar.
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
                .keyboardShortcut("[", modifiers: .command)  // GAP-22

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
                .keyboardShortcut("]", modifiers: .command)  // GAP-22

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
                .keyboardShortcut("r", modifiers: .command)  // GAP-22

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
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    // Flat URL field — no capsule bubble/border/shadow; the floating
                    // toolbar provides the surface (owner 2026-07-03: "make the url thing
                    // flat"). A subtle rounded fill keeps it legible without raised chrome.
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.resolved.foreground.color.opacity(0.06))
                }

                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: "text.badge.plus",
                    role: .toolbarUtility,
                    chromePolicy: .bareUntilPressed,
                    helpText: "Save this page to notes",
                    accessibilityLabel: "Save this page to notes"
                ) {
                    savePageToNotes()
                }
                .disabled(isSavingToNotes)

                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: "link",
                    role: .toolbarUtility,
                    chromePolicy: .bareUntilPressed,
                    helpText: "Copy page URL",
                    accessibilityLabel: "Copy page URL"
                ) {
                    copyCurrentURL()
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
                    BrowserLimitsPopover(onClearData: {
                        tab.clearBrowsingData()
                        showingLimits = false
                    })
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
                    if tab.activeDownload != nil {
                        Button("Cancel") {
                            tab.activeDownload?.cancel { _ in }
                            tab.activeDownload = nil
                            tab.lastError = nil
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }
                .font(.caption)
                .foregroundStyle(warningTint)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.resolved.card.color.opacity(0.5))
            }

            }
            .frame(maxWidth: .infinity, alignment: .top)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { toolbarHeight = $0 }
            .background(.ultraThinMaterial)
            .allowsHitTesting(!tab.toolbarHidden)
            .opacity(tab.toolbarHidden ? 0 : 1)
            .blur(radius: tab.toolbarHidden ? 6 : 0)
            .offset(y: tab.toolbarHidden ? -72 : 0)
            .animation(.easeInOut(duration: 0.28), value: tab.toolbarHidden)
        }
        .background(theme.resolved.background.color)
        .onAppear {
            if tab.currentURL == nil,
               let url = BrowserURLGuard.resolve(raw: tab.address) {
                tab.navigate(to: url)
            }
        }
        .background {
            // ⌘L: focus the address bar + force-show the toolbar. Standard browser shortcut,
            // and a keyboard escape so the URL bar can always be reached — a page could
            // otherwise spoof the (harmless) scroll bridge to keep the toolbar hidden.
            Button("") {
                tab.toolbarHidden = false
                addressFocused = true
            }
            .keyboardShortcut("l", modifiers: .command)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    // GAP-22 (audit 2026-07-03): copy the current page URL to the pasteboard.
    private func copyCurrentURL() {
        let urlString = tab.currentURL?.absoluteString ?? tab.address
        guard !urlString.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
    }

    private func savePageToNotes() {
        guard !isSavingToNotes else { return }
        let fallbackTitle = tab.title.isEmpty ? tab.address : tab.title
        let url = tab.address
        let capture = tab.capturePageContent
        isSavingToNotes = true

        // GAP-3 (audit 2026-07-03): build a REAL web clip from the live page (extracted
        // body + source_kind:web_clip front matter, via WebClipperMarkdownBuilder) instead
        // of a title+URL stub, so it's indexed and included by the web-clip context source.
        // Falls back to the stub if the page content can't be captured.
        Task { @MainActor in
            let captured: (html: String?, text: String?)? = await withCheckedContinuation { continuation in
                guard let capture else { continuation.resume(returning: nil); return }
                // RES-7: the capture completion may never fire if the webView is torn down
                // mid-capture — without a timeout the continuation would leak and
                // isSavingToNotes would stay true forever (Save-to-notes permanently
                // disabled). Resume exactly once: from the capture OR a 4s timeout (→ stub).
                let resumed = OSAllocatedUnfairLock(initialState: false)
                @Sendable func resumeOnce(_ value: (String?, String?)?) {
                    let shouldResume = resumed.withLock { done -> Bool in
                        if done { return false }
                        done = true
                        return true
                    }
                    if shouldResume { continuation.resume(returning: value) }
                }
                capture { html, text in resumeOnce((html, text)) }
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    resumeOnce(nil)
                }
            }

            let docTitle: String
            let body: String
            let frontMatter: [String: String]
            if let captured,
               let document = try? WebClipperMarkdownBuilder.document(
                   from: WebClipCaptureDraft(
                       title: tab.title,
                       sourceURL: url,
                       html: captured.html ?? "",
                       plainText: captured.text ?? "",
                       capturedAt: Date()
                   )
               ) {
                docTitle = document.title
                body = document.markdownBody
                frontMatter = document.frontMatter
            } else {
                docTitle = fallbackTitle
                body = """
                # \(fallbackTitle)

                **Source:** [\(url)](\(url))

                _Saved from the Epistemos browser._
                """
                frontMatter = ["source_kind": "web_clip", "source-url": url, "source_title": fallbackTitle]
            }

            let created = await AppBootstrap.shared?.vaultSync.createPage(
                title: docTitle,
                body: body,
                emoji: "🔖",
                subfolder: "Web Clips",
                allowVaultSelectionPrompt: true,
                frontMatter: frontMatter
            )
            isSavingToNotes = false
            if created != nil {
                ui.showToast("Saved to notes: \(docTitle)", type: .success)
            } else {
                ui.showToast("Couldn't save this page to notes", type: .error)
            }
        }
    }

    private var addressIcon: String {
        tab.currentURL?.scheme?.lowercased() == "https" ? "lock.fill" : "globe"
    }
}

private struct BrowserLimitsPopover: View {
    let onClearData: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Browser")
                .font(.headline)
            Text("Human-driven WebKit tab. Cookies and cache are isolated from Safari in memory for this in-app browser session.")
            Text("Common tracker and ad domains are blocked with a local WebKit content rule list.")
            Text("No Safari extensions. Some premium DRM video may not play in WKWebView.")
            Divider()
            Button(role: .destructive, action: onClearData) {
                Label("Clear browsing data now", systemImage: "trash")
            }
            .help("Wipe this session's cookies, cache, and site storage, then reload the page.")
        }
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct BrowserWebView: NSViewRepresentable {
    let tab: BrowserTab
    let theme: EpistemosTheme

    static let scrollMessageName = "browserScroll"
    /// Posts 'down' / 'up' to the `browserScroll` handler as the page scrolls, throttled
    /// to one message per animation frame and ignoring sub-6px jitter. Main-frame only.
    static let scrollDirectionScript = WKUserScript(
        source: """
        (function(){
          var lastY = 0, ticking = false;
          window.addEventListener('scroll', function(){
            if (ticking) return;
            ticking = true;
            window.requestAnimationFrame(function(){
              var y = window.scrollY || document.documentElement.scrollTop || 0;
              if (Math.abs(y - lastY) > 6) {
                try { window.webkit.messageHandlers.browserScroll.postMessage((y > lastY && y > 48) ? 'down' : 'up'); } catch(e){}
                lastY = y;
              }
              ticking = false;
            });
          }, { passive: true });
        })();
        """,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: true
    )

    /// Weak proxy so the userContentController doesn't strongly retain the Coordinator
    /// (which retains the webView) — the classic WKWebView message-handler leak.
    private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
        weak var target: Coordinator?
        init(_ target: Coordinator) { self.target = target }
        nonisolated func userContentController(
            _ controller: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            guard message.name == BrowserWebView.scrollMessageName,
                  let direction = message.body as? String else { return }
            // WKScriptMessageHandler callbacks are delivered on the main thread.
            MainActor.assumeIsolated { target?.setToolbarHidden(direction == "down") }
        }
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.userContentController = WKUserContentController()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        // Enterprise/App Store: pin Safe-Browsing phishing/malware warnings ON explicitly. WebKit
        // defaults this true, but the browser is a user-trust surface, so make the posture explicit
        // + refactor-proof. Complements the app-level BrowserURLGuard (allowlist + phishing blocks).
        configuration.preferences.isFraudulentWebsiteWarningEnabled = true
        BrowserTrackerContentBlocker.install(on: configuration.userContentController)
        // Force the Epistemos theme (palette + pixel heading font) onto every
        // page that loads — browsing stays canon with the app (owner 2026-07-03).
        configuration.userContentController.addUserScript(
            BrowserThemeInjection.userScript(for: theme)
        )
        // Owner 2026-07-03: drive the floating toolbar's hide-on-scroll-down /
        // show-on-scroll-up. WeakScriptMessageHandler breaks the userContentController →
        // handler → webView retain cycle (removed again in dismantleNSView).
        configuration.userContentController.addUserScript(Self.scrollDirectionScript)
        configuration.userContentController.add(
            WeakScriptMessageHandler(context.coordinator), name: Self.scrollMessageName
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.setValue(false, forKey: "drawsBackground")
        // Task 2 (owner 2026-07-03: "websites themselves stay light"): report the app's
        // light/dark to pages via the webview appearance, so sites that support dark mode
        // (Google, YouTube, most modern sites) honor prefers-color-scheme: dark and render
        // dark. Sites with NO dark styling can't be forced dark without weird full-invert.
        webView.appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)

        context.coordinator.attach(webView: webView, tab: tab)
        if BrowserHomePage.isHome(tab.address) {
            // Custom themed pixel-art home page (owner 2026-07-03).
            webView.loadHTMLString(BrowserHomePage.html(theme: theme), baseURL: nil)
        } else if let url = BrowserURLGuard.resolve(raw: tab.address) {
            webView.load(URLRequest(url: url))
        }
        EpdocWebViewShared.notifyWebViewCreated()
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.attach(webView: webView, tab: tab)
        // Re-apply the theme CSS only when the app theme ACTUALLY changes — not on
        // every page-load KVO invalidation (progress/title/url churn updateNSView
        // ~30-50x per load). The per-navigation user script handles fresh page loads.
        let key = BrowserThemeInjection.themeKey(for: theme)
        if context.coordinator.lastThemeKey != key {
            context.coordinator.lastThemeKey = key
            webView.appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)  // Task 2: keep dark signal in sync
            webView.evaluateJavaScript(BrowserThemeInjection.applyThemeJS(for: theme), completionHandler: nil)
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.configuration.userContentController
            .removeScriptMessageHandler(forName: Self.scrollMessageName)
        coordinator.shutdown()
        EpdocWebViewShared.notifyWebViewDismantled()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        private weak var webView: WKWebView?
        private weak var tab: BrowserTab?
        private var observations: [NSKeyValueObservation] = []
        /// Last theme identity applied via live re-injection; skips redundant evals.
        var lastThemeKey: String?

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

        /// Owner 2026-07-03: toolbar hide/show, driven by the injected scroll listener.
        func setToolbarHidden(_ hidden: Bool) {
            guard tab?.toolbarHidden != hidden else { return }
            tab?.toolbarHidden = hidden
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
            // BRW-4: explicit "clear browsing data" — wipe the (already in-memory-only,
            // non-persistent) cookies/cache/storage on demand, then reload the page so
            // it re-runs cleanly. Makes the browser's data isolation user-controllable.
            tab.clearData = { [weak webView] in
                guard let webView else { return }
                let store = webView.configuration.websiteDataStore
                store.removeData(
                    ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                    modifiedSince: .distantPast
                ) {
                    webView.reload()
                }
            }
            tab.capturePageContent = { [weak webView] completion in
                guard let webView else { completion(nil, nil); return }
                webView.evaluateJavaScript("document.documentElement.outerHTML") { html, _ in
                    webView.evaluateJavaScript("document.body ? document.body.innerText : ''") { text, _ in
                        completion(html as? String, text as? String)
                    }
                }
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
            // Our custom pixel-art home page loads via loadHTMLString, whose document
            // URL is about:blank. Allow the about: scheme so the guard doesn't block
            // our OWN home page as a "non-web navigation" (owner reported the home
            // showing "Blocked non-web navigation" 2026-07-03). about: cannot reach
            // external content in WKWebView, so this is safe.
            if navigationAction.request.url == nil || navigationAction.request.url?.scheme == "about" {
                decisionHandler(.allow)
                return
            }
            guard BrowserURLGuard.allows(url: navigationAction.request.url) else {
                // BRW-2: hand mailto:/tel: to the system default app (Mail/Phone) instead
                // of dead-ending as "Blocked". data:/file:/javascript: stay hard-blocked.
                if let url = navigationAction.request.url, BrowserURLGuard.isExternalHandoff(url: url) {
                    NSWorkspace.shared.open(url)
                    tab?.lastError = nil
                } else {
                    tab?.lastError = "Blocked non-web navigation."
                }
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
            // Allow the about: home-page document (loadHTMLString) — see navigationAction.
            if navigationResponse.response.url == nil || navigationResponse.response.url?.scheme == "about" {
                decisionHandler(.allow)
                return
            }
            guard BrowserURLGuard.allows(url: navigationResponse.response.url) else {
                tab?.lastError = "Blocked non-web navigation."
                decisionHandler(.cancel)
                return
            }
            // BRW-1: a response WebKit cannot render (attachment PDF, .zip, .dmg, …)
            // would otherwise silently dead-end. Route it to a download instead.
            if !navigationResponse.canShowMIMEType {
                decisionHandler(.download)
                return
            }
            decisionHandler(.allow)
        }

        // BRW-1: adopt the download once WebKit converts the response/action.
        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }

        // MARK: - WKDownloadDelegate (BRW-1)

        // RES-8: track the active download so its progress can be polled + shown.
        private var activeDownload: WKDownload?
        private var downloadProgressTask: Task<Void, Never>?

        func download(
            _ download: WKDownload,
            decideDestinationUsing response: URLResponse,
            suggestedFilename: String,
            completionHandler: @escaping @MainActor @Sendable (URL?) -> Void
        ) {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = suggestedFilename
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else {
                completionHandler(nil)  // user cancelled → WebKit cancels the download
                return
            }
            // WKDownload requires the destination to not already exist.
            try? FileManager.default.removeItem(at: url)
            tab?.lastError = "Downloading \(suggestedFilename)…"
            // RES-8: poll progress so a slow/stalled download shows a moving percentage
            // instead of a static "Downloading…" that reads as stuck.
            activeDownload = download
            tab?.activeDownload = download  // expose to the UI Cancel affordance
            let downloadName = suggestedFilename
            downloadProgressTask?.cancel()
            downloadProgressTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled,
                          let fraction = self?.activeDownload?.progress.fractionCompleted else { break }
                    self?.tab?.lastError = "Downloading \(downloadName)… \(Int((fraction * 100).rounded()))%"
                }
            }
            completionHandler(url)
        }

        func downloadDidFinish(_ download: WKDownload) {
            downloadProgressTask?.cancel()
            activeDownload = nil
            tab?.activeDownload = nil
            tab?.lastError = nil
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            downloadProgressTask?.cancel()
            activeDownload = nil
            tab?.activeDownload = nil
            // Mirror the navigation-error convention: a fixed domain+code format only,
            // never the raw localized error text (which can leak file paths / user content).
            let nsError = error as NSError
            // A user-initiated Cancel surfaces as a cancellation, not a failure — clear quietly.
            if nsError.code == NSURLErrorCancelled {
                tab?.lastError = nil
                return
            }
            tab?.lastError = "Download failed (domain=\(nsError.domain) code=\(nsError.code))"
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                guard let url = navigationAction.request.url,
                      BrowserURLGuard.allows(url: url) else {
                    tab?.lastError = "Blocked non-web navigation."
                    return nil
                }
                webView.load(URLRequest(url: url))
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

        /// Timestamp of the last renderer-crash reload, to break a reload loop.
        private var lastCrashReload: Date?

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // The web content process crashed (OOM / renderer fault) — the page goes blank with NO
            // navigation error. Reload once to recover (Apple-recommended). Guard against a reload loop
            // from a page that reliably kills the renderer: if it crashes again within 3s, stop and
            // surface an error instead of a silent blank or an infinite reload.
            guard webView.url != nil else { return }
            let now = Date()
            if let last = lastCrashReload, now.timeIntervalSince(last) < 3 {
                tab?.lastError = "This page crashed and couldn't be reloaded."
                tab?.toolbarHidden = false
                return
            }
            lastCrashReload = now
            webView.reload()
        }

        private func recordNavigationFailure(_ error: Error) {
            guard let message = BrowserNavigationErrorPolicy.userVisibleMessage(for: error) else {
                return
            }
            tab?.lastError = message
            tab?.toolbarHidden = false  // RES-5: force-show so the error isn't hidden by scroll-hide
        }
    }
}
