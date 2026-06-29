import SwiftUI
import WebKit

nonisolated enum HTMLWorkspaceSafeAPI {
    static let messageHandlerName = "htmlWorkspaceSafeAPI"
}

nonisolated enum HTMLWorkspacePreviewIdentity {
    static func viewIdentity(for package: HTMLWorkspacePackage) -> String {
        "\(package.manifest.id)-\(contentShellHash(for: package))"
    }

    static func renderShellIdentity(
        for package: HTMLWorkspacePackage,
        previewTheme: HTMLWorkspacePreviewTheme?,
        themeGuardCSSOverride: String?,
        themeIdentity: String?
    ) -> String {
        let themeGuardCSS = themeGuardCSSOverride
            ?? previewTheme?.guardCSS
            ?? HTMLWorkspacePreviewTheme.defaultGuardCSS
        return [
            package.manifest.id,
            contentShellHash(for: package),
            package.manifest.sandboxPolicy.contentSecurityPolicy,
            previewTheme?.rawValue ?? "system",
            themeGuardCSS,
            HTMLWorkspacePreviewTheme.hostCSS,
            themeIdentity ?? "",
        ].joined(separator: "\u{0}")
    }

    private static func contentShellHash(for package: HTMLWorkspacePackage) -> String {
        HTMLWorkspaceDocument.contentHash(
            indexHTML: package.indexHTML,
            styleCSS: package.styleCSS,
            scriptJS: package.scriptJS,
            dataJSON: ""
        )
    }
}

/// SS-HW seam upgrade: the JS-console / error-capture bridge that was a deferred stub. Injects a
/// read-only capture script (window 'error' + unhandledrejection + console.error/warn → Swift) so
/// the already-built console pipeline (HTMLWorkspaceConsoleError + .recordConsoleError + the console
/// panel) finally shows real runtime errors. Behind EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0 (default OFF
/// → the bridge is not installed, byte-identical to before) because it changes WKWebView behavior +
/// records errors into the document.
nonisolated enum HTMLWorkspaceConsoleBridge {
    static let messageHandlerName = "epistemosWorkspaceConsole"

    static var enabled: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0"] == "1"
    }

    /// Read-only: forwards errors, never exposes an app API. Posts {message, source, line, column}.
    static let injectionScript = """
    (function(){
      function post(message, source, line, column){
        try {
          window.webkit.messageHandlers.epistemosWorkspaceConsole.postMessage({
            message: String(message), source: source || null, line: line || 0, column: column || 0
          });
        } catch (e) {}
      }
      window.addEventListener('error', function(e){ post(e.message || 'Error', e.filename, e.lineno, e.colno); });
      window.addEventListener('unhandledrejection', function(e){ post('Unhandled promise rejection: ' + e.reason, null, 0, 0); });
      var origError = console.error;
      console.error = function(){ post(Array.prototype.slice.call(arguments).join(' '), null, 0, 0); origError.apply(console, arguments); };
      var origWarn = console.warn;
      console.warn = function(){ post(Array.prototype.slice.call(arguments).join(' '), null, 0, 0); origWarn.apply(console, arguments); };
    })();
    """
}

struct HTMLWorkspacePreviewView: NSViewRepresentable {
    var package: HTMLWorkspacePackage
    var safeAPIEnabled: Bool = false
    var previewTheme: HTMLWorkspacePreviewTheme? = nil
    var themeGuardCSSOverride: String? = nil
    var themeIdentity: String? = nil
    var onConsoleError: (@MainActor (HTMLWorkspaceConsoleError) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            package: package,
            safeAPIEnabled: safeAPIEnabled,
            previewTheme: previewTheme,
            themeGuardCSSOverride: themeGuardCSSOverride,
            themeIdentity: themeIdentity,
            onConsoleError: onConsoleError
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        if safeAPIEnabled && package.manifest.sandboxPolicy.allowAppBridge {
            configuration.userContentController.add(
                context.coordinator,
                name: HTMLWorkspaceSafeAPI.messageHandlerName
            )
            context.coordinator.messageHandlerInstalled = true
        }
        if HTMLWorkspaceConsoleBridge.enabled, context.coordinator.onConsoleError != nil {
            configuration.userContentController.add(
                context.coordinator,
                name: HTMLWorkspaceConsoleBridge.messageHandlerName
            )
            configuration.userContentController.addUserScript(
                WKUserScript(
                    source: HTMLWorkspaceConsoleBridge.injectionScript,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: true
                )
            )
            context.coordinator.consoleHandlerInstalled = true
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        webView.setValue(false, forKey: "drawsBackground")
        loadPreview(into: webView, context: context)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.package = package
        context.coordinator.safeAPIEnabled = safeAPIEnabled
        context.coordinator.previewTheme = previewTheme
        context.coordinator.themeGuardCSSOverride = themeGuardCSSOverride
        context.coordinator.themeIdentity = themeIdentity
        context.coordinator.onConsoleError = onConsoleError
        context.coordinator.syncSafeAPIHandler(for: webView)
        loadPreview(into: webView, context: context)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.detach(from: webView)
    }

    private func loadPreview(into webView: WKWebView, context: Context) {
        let rendered = HTMLWorkspacePreviewDocument.render(
            package: package,
            theme: previewTheme,
            themeGuardCSSOverride: themeGuardCSSOverride
        )
        let shellIdentity = HTMLWorkspacePreviewIdentity.renderShellIdentity(
            for: package,
            previewTheme: previewTheme,
            themeGuardCSSOverride: themeGuardCSSOverride,
            themeIdentity: themeIdentity
        )
        if context.coordinator.canPatchDataOnly(
            shellIdentity: shellIdentity,
            dataJSON: package.dataJSON
        ) {
            context.coordinator.patchDataJSON(
                package.dataJSON,
                renderedFallbackHTML: rendered,
                in: webView
            )
            return
        }
        guard context.coordinator.lastRenderedHTML != rendered ||
                context.coordinator.lastRenderedThemeIdentity != themeIdentity else { return }
        context.coordinator.lastRenderedHTML = rendered
        context.coordinator.lastRenderedThemeIdentity = themeIdentity
        context.coordinator.lastRenderedShellIdentity = shellIdentity
        context.coordinator.lastRenderedDataJSON = package.dataJSON
        webView.loadHTMLString(rendered, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var package: HTMLWorkspacePackage
        var safeAPIEnabled: Bool
        var previewTheme: HTMLWorkspacePreviewTheme?
        var themeGuardCSSOverride: String?
        var themeIdentity: String?
        var lastRenderedHTML: String?
        var lastRenderedThemeIdentity: String?
        var lastRenderedShellIdentity: String?
        var lastRenderedDataJSON: String?
        var messageHandlerInstalled = false
        var consoleHandlerInstalled = false
        var onConsoleError: (@MainActor (HTMLWorkspaceConsoleError) -> Void)?
        private let allowedNetworkSchemes: Set<String> = ["http", "https"]

        init(
            package: HTMLWorkspacePackage,
            safeAPIEnabled: Bool,
            previewTheme: HTMLWorkspacePreviewTheme?,
            themeGuardCSSOverride: String?,
            themeIdentity: String?,
            onConsoleError: (@MainActor (HTMLWorkspaceConsoleError) -> Void)?
        ) {
            self.package = package
            self.safeAPIEnabled = safeAPIEnabled
            self.previewTheme = previewTheme
            self.themeGuardCSSOverride = themeGuardCSSOverride
            self.themeIdentity = themeIdentity
            self.onConsoleError = onConsoleError
        }

        func canPatchDataOnly(shellIdentity: String, dataJSON: String) -> Bool {
            guard lastRenderedHTML != nil,
                  lastRenderedShellIdentity == shellIdentity,
                  lastRenderedDataJSON != dataJSON else {
                return false
            }
            return true
        }

        func patchDataJSON(
            _ dataJSON: String,
            renderedFallbackHTML: String,
            in webView: WKWebView
        ) {
            lastRenderedHTML = renderedFallbackHTML
            lastRenderedDataJSON = dataJSON
            let rawLiteral = Self.javaScriptStringLiteral(dataJSON)
            let script = """
            (() => {
              const rawJSON = \(rawLiteral);
              let nextData;
              try {
                nextData = JSON.parse(rawJSON || '{}');
              } catch (error) {
                nextData = { error: 'Invalid data.json' };
                console.error('HTMLWorkspace data.json parse failed', error);
              }
              if (typeof window.__epistemosReplaceWorkspaceData === 'function') {
                window.__epistemosReplaceWorkspaceData(nextData, rawJSON);
                return 'patched';
              }
              return 'missing-runtime';
            })();
            """
            webView.evaluateJavaScript(script) { [weak self, weak webView] result, error in
                guard let self, let webView else { return }
                if error != nil || (result as? String) != "patched" {
                    webView.loadHTMLString(renderedFallbackHTML, baseURL: nil)
                }
            }
        }

        private static func javaScriptStringLiteral(_ value: String) -> String {
            guard let data = try? JSONEncoder().encode(value),
                  let literal = String(data: data, encoding: .utf8) else {
                return "\"\""
            }
            return literal
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.request.url?.scheme == "about" {
                decisionHandler(.allow)
                return
            }
            if package.manifest.sandboxPolicy.allowNetwork == false {
                decisionHandler(.cancel)
                return
            }
            guard let scheme = navigationAction.request.url?.scheme?.lowercased(),
                  allowedNetworkSchemes.contains(scheme) else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func syncSafeAPIHandler(for webView: WKWebView) {
            let shouldInstall = safeAPIEnabled && package.manifest.sandboxPolicy.allowAppBridge
            if shouldInstall, !messageHandlerInstalled {
                webView.configuration.userContentController.add(
                    self,
                    name: HTMLWorkspaceSafeAPI.messageHandlerName
                )
                messageHandlerInstalled = true
            } else if !shouldInstall, messageHandlerInstalled {
                webView.configuration.userContentController.removeScriptMessageHandler(
                    forName: HTMLWorkspaceSafeAPI.messageHandlerName
                )
                messageHandlerInstalled = false
            }
        }

        func detach(from webView: WKWebView) {
            webView.stopLoading()
            webView.navigationDelegate = nil
            if messageHandlerInstalled {
                webView.configuration.userContentController.removeScriptMessageHandler(
                    forName: HTMLWorkspaceSafeAPI.messageHandlerName
                )
                messageHandlerInstalled = false
            }
            if consoleHandlerInstalled {
                webView.configuration.userContentController.removeScriptMessageHandler(
                    forName: HTMLWorkspaceConsoleBridge.messageHandlerName
                )
                consoleHandlerInstalled = false
            }
            lastRenderedHTML = nil
            lastRenderedThemeIdentity = nil
            lastRenderedShellIdentity = nil
            lastRenderedDataJSON = nil
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            // SS-HW: the JS-console capture channel → record one runtime error into the document's
            // console pipeline (the safeAPI channel stays a deferred stub for now).
            guard message.name == HTMLWorkspaceConsoleBridge.messageHandlerName,
                  let body = message.body as? [String: Any] else { return }
            let error = HTMLWorkspaceConsoleError(
                message: (body["message"] as? String) ?? "Console error",
                source: body["source"] as? String,
                line: (body["line"] as? NSNumber)?.uint32Value ?? 0,
                column: (body["column"] as? NSNumber)?.uint32Value ?? 0,
                timestamp: Int64(Date().timeIntervalSince1970 * 1000)
            )
            onConsoleError?(error)
        }
    }
}
