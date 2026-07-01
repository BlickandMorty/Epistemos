import AppKit
import Foundation
import SwiftUI
import WebKit

extension GooseWebSurfaceView {
    nonisolated static func runtimeRetryDelayNanoseconds(for attempt: Int) -> UInt64 {
        let shift = UInt64(min(max(attempt, 0), 8))
        let multiplier = UInt64(1) << shift
        let multiplied = initialRuntimeRetryDelayNanoseconds.multipliedReportingOverflow(by: multiplier)
        let delay = multiplied.overflow ? maximumRuntimeRetryDelayNanoseconds : multiplied.partialValue
        return min(delay, maximumRuntimeRetryDelayNanoseconds)
    }

    nonisolated static func webUIRenderRetryDelayNanoseconds(for attempt: Int) -> UInt64 {
        let shift = UInt64(min(max(attempt, 0), 8))
        let multiplier = UInt64(1) << shift
        let multiplied = initialWebUIRenderRetryDelayNanoseconds.multipliedReportingOverflow(by: multiplier)
        let delay = multiplied.overflow ? maximumWebUIRenderRetryDelayNanoseconds : multiplied.partialValue
        return min(delay, maximumWebUIRenderRetryDelayNanoseconds)
    }

    static func makePage(
        bootstrap: GooseWebBootstrap,
        gooseUIRoot: URL?,
        theme: EpistemosTheme = .nativeDefault,
        nativePromptBridge: GooseWebNativePromptBridge,
        nativeAffordanceBridge: GooseWebNativeAffordanceBridge,
        trustedOrigins: GooseTrustedLoopbackOrigins
    ) -> WebPage {
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.defaultNavigationPreferences.allowsContentJavaScript = true
        configuration.userContentController.addScriptMessageHandler(
            nativePromptBridge,
            contentWorld: .page,
            name: "epistemosGoosePrompt"
        )
        configuration.userContentController.addScriptMessageHandler(
            nativeAffordanceBridge,
            contentWorld: .page,
            name: "epistemosGooseNative"
        )
        if let gooseUIRoot, let scheme = URLScheme(gooseUISchemeName) {
            configuration.urlSchemeHandlers[scheme] = WorkSPASchemeHandler(
                root: gooseUIRoot,
                virtualBasePath: gooseUISurfaceVirtualBasePath
            )
        }
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: GooseWebBootShim.bootstrapScript(for: bootstrap) + "\n" + nativeFeelScript(theme: theme),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        trustedOrigins.register(bootstrap.baseURL)
        return WebPage(
            configuration: configuration,
            navigationDecider: GooseNavigationDecider(trustedOrigins: trustedOrigins)
        )
    }

    @MainActor
    static func makeBootProbePage(
        bootstrap: GooseWebBootstrap,
        gooseUIRoot: URL,
        theme: EpistemosTheme = .nativeDefault,
        nativePromptBridge: GooseWebNativePromptBridge = GooseWebNativePromptBridge(),
        nativeAffordanceBridge: GooseWebNativeAffordanceBridge = GooseWebNativeAffordanceBridge()
    ) -> WebPage {
        makePage(
            bootstrap: bootstrap,
            gooseUIRoot: gooseUIRoot,
            theme: theme,
            nativePromptBridge: nativePromptBridge,
            nativeAffordanceBridge: nativeAffordanceBridge,
            trustedOrigins: GooseTrustedLoopbackOrigins()
        )
    }

    static func resolvedGooseUIIndex() -> URL? {
        GooseWebUIResolver.indexURL()
    }

    static func resolvedGooseUIRoot() -> URL? {
        resolvedGooseUIIndex()?.deletingLastPathComponent()
    }

    nonisolated static func bootURL(for _: URL) -> URL {
        surfaceURL(hashRoute: "/?")
    }

    nonisolated static func routeURL(_ route: String) -> URL {
        surfaceURL(hashRoute: normalizedGooseRoute(route))
    }

    nonisolated static func loopbackURL(baseURL: URL, route: String) -> URL {
        let normalizedRoute = normalizedGooseRoute(route)
        var absolute = baseURL.absoluteString
        if !absolute.hasSuffix("/") {
            absolute += "/"
        }
        let fragment = normalizedRoute.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? ""
        return URL(string: "\(absolute)?v=\(gooseUISurfaceCacheToken)#\(fragment)") ?? baseURL
    }

    nonisolated static func normalizedGooseRoute(_ route: String) -> String {
        let boundedRoute = String(route.prefix(maxGooseRouteCharacters))
        guard !boundedRoute.isEmpty else { return "/?" }
        return boundedRoute.hasPrefix("/") ? boundedRoute : "/\(boundedRoute)"
    }

    nonisolated static func gooseStaticCompatibilityRoutes(
        bootstrappedIndexHTML: String? = nil
    ) -> [WorkSPAStaticRoute] {
        var routes = [
            WorkSPAStaticRoute(
                path: "/agent/list_apps",
                contentType: "application/json; charset=utf-8",
                body: Data(#"{"apps":[]}"#.utf8)
            ),
        ]
        if let bootstrappedIndexHTML {
            let body = Data(bootstrappedIndexHTML.utf8)
            routes.append(WorkSPAStaticRoute(
                path: "/",
                contentType: "text/html; charset=utf-8",
                body: body
            ))
            routes.append(WorkSPAStaticRoute(
                path: "/index.html",
                contentType: "text/html; charset=utf-8",
                body: body
            ))
        }
        return routes
    }

    static func waitForWebPageLoadFinished(
        page: WebPage,
        request: URLRequest,
        timeoutNanoseconds: UInt64
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await Self.consumeWebPageLoadUntilFinished(page: page, request: request)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return false
            }
            guard let result = await group.next() else {
                group.cancelAll()
                return false
            }
            group.cancelAll()
            return result
        }
    }

    @MainActor
    static func consumeWebPageLoadUntilFinished(page: WebPage, request: URLRequest) async -> Bool {
        do {
            for try await event in page.load(request) {
                if event == .finished { return true }
            }
        } catch {
            return false
        }
        return false
    }

    nonisolated static func runtimeHealthReady(baseURL: URL) async -> Bool {
        await GooseRuntimeSupervisor.healthCheck(base: baseURL)
    }

    nonisolated static func gooseUIReady(baseURL: URL) async -> Bool {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 1
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return false
        }
        return (http.value(forHTTPHeaderField: "Content-Type") ?? "")
            .localizedCaseInsensitiveContains("text/html")
    }

    static func bootstrappedGooseUIHTML(
        indexURL: URL,
        bootstrap: GooseWebBootstrap,
        theme: EpistemosTheme = .nativeDefault
    ) -> String? {
        guard let html = try? String(contentsOf: indexURL, encoding: .utf8) else { return nil }
        let snippet = """
        <script>
        \(GooseWebBootShim.bootstrapScript(for: bootstrap))
        \(nativeFeelScript(theme: theme))
        </script>
        """
        if let headRange = html.range(of: "<head>") {
            return html.replacingCharacters(in: headRange, with: "<head>" + snippet)
        }
        return snippet + html
    }

    static func placeholderHTML(status: String, acpURL: String) -> String {
        let boundedStatus = boundedPlaceholderStatus(status)
        let acpLine = placeholderACPLine(acpURL)
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            :root { color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; }
            body {
              margin: 0;
              min-height: 100vh;
              display: grid;
              place-items: center;
              background: var(--color-background-primary, Canvas);
              color: var(--color-text-primary, CanvasText);
              cursor: default;
            }
            main { width: min(560px, calc(100vw - 48px)); }
            h1 { font-size: 15px; font-weight: 650; margin: 0 0 10px; letter-spacing: 0; }
            p { font-size: 13px; line-height: 1.45; margin: 0 0 8px; color: var(--color-text-secondary, color-mix(in srgb, CanvasText 72%, transparent)); }
            code { font-family: "SF Mono", ui-monospace, monospace; font-size: 12px; }
          </style>
        </head>
        <body>
          <main>
            <h1>Epistemos Goose</h1>
            <p><code>\(escapeHTML(boundedStatus))</code></p>
            \(acpLine)
          </main>
        </body>
        </html>
        """
    }

    static func placeholderACPLine(_ acpURL: String) -> String {
        let trimmedACPURL = acpURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedACPURL.isEmpty else { return "" }
        return "<p class=\"detail\"><code>\(escapeHTML(trimmedACPURL))</code></p>"
    }

    nonisolated static func boundedPlaceholderStatus(_ status: String) -> String {
        let trimmed = status.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? "Goose surface unavailable." : trimmed
        guard value.count > maxPlaceholderStatusCharacters else { return value }
        return String(value.prefix(maxPlaceholderStatusCharacters))
    }

    static func nativeFeelScript(theme: EpistemosTheme) -> String {
        let css = nativeFeelCSS(theme: theme)
        return """
        (() => {
          const style = document.createElement('style');
          style.id = 'epistemos-goose-native-theme';
          style.textContent = \(jsStringLiteral(css));
          document.documentElement.appendChild(style);
          document.documentElement.dataset.epistemosTheme = \(jsStringLiteral(theme.rawValue));
          document.documentElement.classList.toggle('dark', \(theme.isDark ? "true" : "false"));
        })();
        """
    }

    static func nativeThemeUpdateScript(theme: EpistemosTheme) -> String {
        let css = nativeFeelCSS(theme: theme)
        let webTheme = theme.isDark ? "dark" : "light"
        return """
        return (() => {
          let style = document.getElementById('epistemos-goose-native-theme');
          if (!style) {
            style = document.createElement('style');
            style.id = 'epistemos-goose-native-theme';
            document.documentElement.appendChild(style);
          }
          style.textContent = \(jsStringLiteral(css));
          document.documentElement.dataset.epistemosTheme = \(jsStringLiteral(theme.rawValue));
          document.documentElement.classList.toggle('dark', \(theme.isDark ? "true" : "false"));
          document.documentElement.classList.toggle('light', \(theme.isDark ? "false" : "true"));
          document.documentElement.style.colorScheme = \(jsStringLiteral(webTheme));
          try {
            window.electron?.broadcastThemeChange?.({
              useSystemTheme: false,
              theme: \(jsStringLiteral(webTheme)),
              epistemosTheme: \(jsStringLiteral(theme.rawValue))
            });
          } catch {}
          return document.documentElement.dataset.epistemosTheme;
        })();
        """
    }

    static func nativeFeelCSS(theme: EpistemosTheme) -> String {
        let resolved = theme.resolved
        let background = cssColor(resolved.chatSurface)
        let surface = cssColor(resolved.card)
        let surfaceStrong = cssColor(resolved.floatingSurfaceTint)
        let foreground = cssColor(resolved.foreground)
        let mutedForeground = cssColor(resolved.mutedForeground)
        let border = cssColor(resolved.border)
        let accent = cssColor(resolved.accent)
        let inverseBackground = cssColor(resolved.foreground)
        let inverseText = cssColor(resolved.background)
        let colorScheme = theme.isDark ? "dark" : "light"

        return """
        :root,
        .goose-epistemos {
          color-scheme: \(colorScheme);
          --color-background-primary: \(background) !important;
          --color-background-secondary: \(surface) !important;
          --color-background-tertiary: \(surfaceStrong) !important;
          --color-background-inverse: \(inverseBackground) !important;
          --color-background-info: \(surface) !important;
          --color-text-primary: \(foreground) !important;
          --color-text-secondary: \(mutedForeground) !important;
          --color-text-tertiary: \(mutedForeground) !important;
          --color-text-inverse: \(inverseText) !important;
          --color-text-info: \(accent) !important;
          --color-border-primary: \(border) !important;
          --color-border-secondary: \(border) !important;
          --color-border-tertiary: \(border) !important;
          --color-border-info: \(accent) !important;
          --color-ring-primary: \(accent) !important;
          --color-ring-secondary: \(accent) !important;
          --color-ring-info: \(accent) !important;
          --epistemos-accent: \(accent) !important;
          --epistemos-theme-background: \(background) !important;
          --epistemos-theme-surface: \(surface) !important;
          --epistemos-theme-surface-strong: \(surfaceStrong) !important;
          --epistemos-theme-foreground: \(foreground) !important;
          --epistemos-theme-muted-foreground: \(mutedForeground) !important;
          --epistemos-theme-border: \(border) !important;
        }
        * { -webkit-font-smoothing: antialiased; }
        html,
        body {
          background: \(background) !important;
          cursor: default;
          overscroll-behavior: none;
        }
        ::-webkit-scrollbar {
          width: initial;
          height: initial;
        }
        """
    }

    private static func cssColor(_ token: EpistemosTheme.ResolvedColorToken) -> String {
        guard let srgb = token.nsColor.usingColorSpace(.sRGB) else { return "#000000" }
        let red = Int((srgb.redComponent * 255).rounded())
        let green = Int((srgb.greenComponent * 255).rounded())
        let blue = Int((srgb.blueComponent * 255).rounded())
        let alpha = srgb.alphaComponent
        if alpha >= 0.999 {
            return String(format: "#%02x%02x%02x", red, green, blue)
        }
        return String(format: "rgba(%d, %d, %d, %.3f)", red, green, blue, alpha)
    }

    private static func jsStringLiteral(_ value: String) -> String {
        guard JSONSerialization.isValidJSONObject([value]),
              let data = try? JSONSerialization.data(withJSONObject: [value]),
              let json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return String(json.dropFirst().dropLast())
    }

    static let gooseUIRenderProbeScript = """
    return (() => {
      const root = document.getElementById('root');
      if (!root || root.children.length === 0) return 'blank';
      const bodyTextLength = (document.body?.innerText || '').trim().length;
      const visibleElements = Array.from(document.body?.querySelectorAll(
        'button,input,textarea,[role="button"],nav,a,h1,h2,h3,p,main,section,form,[data-testid]'
      ) || []).filter((element) => {
        const style = window.getComputedStyle(element);
        if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity || '1') === 0) {
          return false;
        }
        const rect = element.getBoundingClientRect();
        return rect.width >= 4 && rect.height >= 4;
      }).length;
      return bodyTextLength > 0 || visibleElements >= 2 ? 'ready' : 'blank';
    })();
    """

    nonisolated private static func surfaceURL(hashRoute: String) -> URL {
        let base = "\(gooseUISchemeName)://\(gooseUISurfaceHost)\(gooseUISurfaceVirtualBasePath)/?v=\(gooseUISurfaceCacheToken)"
        let fragment = hashRoute.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? ""
        return URL(string: "\(base)#\(fragment)") ?? URL(string: base) ?? URL(fileURLWithPath: "/")
    }

    private static func escapeHTML(_ raw: String) -> String {
        raw.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// SECURITY (deep-hardening 2026-06-29 H1): the trusted loopback origins (the WorkSPA UI
/// server + the goose/goosed server) are the ONLY http/ws origins the surface may navigate
/// to. Allowing ANY 127.0.0.1/localhost/::1 page would let a foreign local page (reached via
/// a plain link or tool/MCP-influenced `window.location`) inherit the injected boot shim,
/// including `getSecretKey()` and the native FS bridge. We pin to the exact registered ports.
final class GooseTrustedLoopbackOrigins: @unchecked Sendable {
    private let lock = NSLock()
    private var ports: Set<Int> = []
    static let maxLoopbackHostCharacters = 128

    static func isLoopback(_ host: String?) -> Bool {
        guard let host,
              host.utf8.count <= maxLoopbackHostCharacters,
              !host.utf8.contains(0) else {
            return false
        }
        let normalizedHost = host.lowercased()
        return normalizedHost == "127.0.0.1" || normalizedHost == "localhost" || normalizedHost == "::1"
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

private struct GooseNavigationDecider: WebPage.NavigationDeciding {
    let trustedOrigins: GooseTrustedLoopbackOrigins

    func decidePolicy(
        for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences
    ) async -> WKNavigationActionPolicy {
        guard let url = action.request.url else { return .cancel }
        switch url.scheme?.lowercased() {
        case "about", GooseWebSurfaceView.gooseUISchemeName:
            return .allow
        case "http", "https":
            return trustedOrigins.isAllowed(url) ? .allow : .cancel
        default:
            return .cancel
        }
    }
}
