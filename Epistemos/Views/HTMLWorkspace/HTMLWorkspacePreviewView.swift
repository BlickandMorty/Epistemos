import CryptoKit
import SwiftUI
import WebKit

nonisolated enum HTMLWorkspaceSafeAPI {
    static let messageHandlerName = "htmlWorkspaceSafeAPI"
    static let deferredDiagnosticMessage = "Safe API message ignored: HTML Workspace app bridge is deferred"
}

nonisolated enum HTMLWorkspacePreviewIdentity {
    static func viewIdentity(for package: HTMLWorkspacePackage) -> String {
        "\(package.manifest.id)-\(contentShellHash(for: package))-\(assetShellHash(for: package))"
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
            assetShellHash(for: package),
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
            dataJSON: "",
            routes: package.routes
        )
    }

    private static func assetShellHash(for package: HTMLWorkspacePackage) -> String {
        guard !package.assets.isEmpty else { return "no-assets" }
        var data = Data()
        for name in package.assets.keys.sorted() {
            data.append(Data(name.utf8))
            data.append(0)
            data.append(package.assets[name] ?? Data())
            data.append(0)
        }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
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

nonisolated enum HTMLWorkspacePreviewURL {
    static let baseURL = URL(string: "\(HTMLWorkspaceLocalResourceScheme.scheme)://workspace/\(HTMLWorkspacePackageEntry.indexHTML)")!
}

@MainActor
final class HTMLWorkspacePreviewURLSchemeHandler: NSObject, WKURLSchemeHandler {
    private let resolver: @MainActor (String) -> HTMLWorkspacePackageResource?

    init(resolver: @escaping @MainActor (String) -> HTMLWorkspacePackageResource?) {
        self.resolver = resolver
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              let resourcePath = Self.resourcePath(for: url),
              let asset = resolver(resourcePath) else {
            urlSchemeTask.didFailWithError(Self.error(for: urlSchemeTask.request.url))
            return
        }

        let response = URLResponse(
            url: url,
            mimeType: asset.mimeType,
            expectedContentLength: asset.data.count,
            textEncodingName: asset.textEncodingName
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(asset.data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private static func resourcePath(for url: URL) -> String? {
        guard url.scheme?.lowercased() == HTMLWorkspaceLocalResourceScheme.scheme else { return nil }
        var path = (url.path.removingPercentEncoding ?? url.path)
        if path.hasPrefix("/") {
            path.removeFirst()
        }
        guard !path.isEmpty else { return HTMLWorkspacePackageEntry.indexHTML }

        let components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.isEmpty,
              components.allSatisfy(isSafePathComponent) else {
            return nil
        }
        if components.count == 1 {
            return components[0]
        }
        if components.count == 2, components[0] == HTMLWorkspacePackageEntry.assets {
            return "\(HTMLWorkspacePackageEntry.assets)/\(components[1])"
        }
        if components.count == 2, components[0] == HTMLWorkspacePackageEntry.routes {
            return "\(HTMLWorkspacePackageEntry.routes)/\(components[1])"
        }
        if components.count == 3,
           components[0] == HTMLWorkspacePackageEntry.routes,
           components[1] == HTMLWorkspacePackageEntry.assets {
            return "\(HTMLWorkspacePackageEntry.assets)/\(components[2])"
        }
        return nil
    }

    private static func isSafePathComponent(_ component: String) -> Bool {
        !component.isEmpty
            && component != "."
            && component != ".."
            && !component.contains("\\")
            && !component.contains("\0")
            && !component.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    }

    private static func error(for url: URL?) -> NSError {
        NSError(
            domain: "HTMLWorkspacePreviewURLSchemeHandler",
            code: NSURLErrorFileDoesNotExist,
            userInfo: [
                NSURLErrorFailingURLErrorKey: url as Any,
                NSLocalizedDescriptionKey: "HTML Workspace package resource not found",
            ]
        )
    }
}

struct HTMLWorkspacePreviewView: NSViewRepresentable {
    var package: HTMLWorkspacePackage
    var safeAPIEnabled: Bool = false
    var previewTheme: HTMLWorkspacePreviewTheme? = nil
    var themeGuardCSSOverride: String? = nil
    var themeIdentity: String? = nil
    var onConsoleError: (@MainActor (HTMLWorkspaceConsoleError) -> Void)? = nil
    var onDOMSnapshot: (@MainActor (HTMLWorkspaceDOMSnapshot) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            package: package,
            safeAPIEnabled: safeAPIEnabled,
            previewTheme: previewTheme,
            themeGuardCSSOverride: themeGuardCSSOverride,
            themeIdentity: themeIdentity,
            onConsoleError: onConsoleError,
            onDOMSnapshot: onDOMSnapshot
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.setURLSchemeHandler(
            context.coordinator.urlSchemeHandler,
            forURLScheme: HTMLWorkspaceLocalResourceScheme.scheme
        )
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
        EpdocWebViewShared.notifyWebViewCreated()
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.package = package
        context.coordinator.safeAPIEnabled = safeAPIEnabled
        context.coordinator.previewTheme = previewTheme
        context.coordinator.themeGuardCSSOverride = themeGuardCSSOverride
        context.coordinator.themeIdentity = themeIdentity
        context.coordinator.onConsoleError = onConsoleError
        context.coordinator.onDOMSnapshot = onDOMSnapshot
        context.coordinator.syncSafeAPIHandler(for: webView)
        loadPreview(into: webView, context: context)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.detach(from: webView)
        EpdocWebViewShared.notifyWebViewDismantled()
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
        webView.loadHTMLString(rendered, baseURL: HTMLWorkspacePreviewURL.baseURL)
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
        var onDOMSnapshot: (@MainActor (HTMLWorkspaceDOMSnapshot) -> Void)?
        lazy var urlSchemeHandler = HTMLWorkspacePreviewURLSchemeHandler { [weak self] resourcePath in
            self?.resourceResponse(for: resourcePath)
        }
        private let allowedNetworkSchemes: Set<String> = ["http", "https"]

        init(
            package: HTMLWorkspacePackage,
            safeAPIEnabled: Bool,
            previewTheme: HTMLWorkspacePreviewTheme?,
            themeGuardCSSOverride: String?,
            themeIdentity: String?,
            onConsoleError: (@MainActor (HTMLWorkspaceConsoleError) -> Void)?,
            onDOMSnapshot: (@MainActor (HTMLWorkspaceDOMSnapshot) -> Void)?
        ) {
            self.package = package
            self.safeAPIEnabled = safeAPIEnabled
            self.previewTheme = previewTheme
            self.themeGuardCSSOverride = themeGuardCSSOverride
            self.themeIdentity = themeIdentity
            self.onConsoleError = onConsoleError
            self.onDOMSnapshot = onDOMSnapshot
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
            webView.evaluateJavaScript(script) { [weak webView] result, error in
                guard let webView else { return }
                if error != nil || (result as? String) != "patched" {
                    webView.loadHTMLString(renderedFallbackHTML, baseURL: HTMLWorkspacePreviewURL.baseURL)
                } else {
                    self.refreshLiveDOMSnapshot(in: webView)
                }
            }
        }

        func refreshLiveDOMSnapshot(in webView: WKWebView) {
            guard onDOMSnapshot != nil else { return }
            webView.evaluateJavaScript(Self.liveDOMSnapshotScript) { [weak self] result, _ in
                guard let self else { return }
                let snapshot = Self.domSnapshot(from: result)
                    ?? HTMLWorkspaceDOMOutline.snapshot(for: self.package.indexHTML, source: .source)
                Task { @MainActor in
                    self.onDOMSnapshot?(snapshot)
                }
            }
        }

        private static func domSnapshot(from result: Any?) -> HTMLWorkspaceDOMSnapshot? {
            guard let payload = result as? [String: Any] else { return nil }
            let rows = payload["outline"] as? [String] ?? []
            let nodeCount = (payload["nodeCount"] as? NSNumber)?.intValue ?? rows.count
            return HTMLWorkspaceDOMSnapshot(
                outline: rows.isEmpty ? "No DOM nodes" : rows.joined(separator: "\n"),
                nodeCount: nodeCount,
                source: .live
            )
        }

        private static let liveDOMSnapshotScript = """
        (() => {
          const root = document.body || document.documentElement;
          if (!root) { return { outline: [], nodeCount: 0 }; }
          const excluded = new Set(['script', 'style', 'meta', 'link', 'title']);
          const nodes = Array.from(root.querySelectorAll('*')).filter((node) => {
            return !excluded.has(String(node.tagName || '').toLowerCase());
          });
          const outline = nodes.slice(0, 300).map((node) => {
            const tag = String(node.tagName || '').toLowerCase();
            const id = node.id ? '#' + node.id : '';
            const classes = Array.from(node.classList || []).slice(0, 6).map((name) => '.' + name).join('');
            const hasData = Array.from(node.attributes || []).some((attr) => attr.name.indexOf('data-') === 0);
            return '<' + tag + id + classes + '>' + (hasData ? ' data' : '');
          });
          if (nodes.length > outline.length) {
            outline.push('... ' + (nodes.length - outline.length) + ' more nodes');
          }
          return { outline, nodeCount: nodes.length };
        })();
        """

        func resourceResponse(for resourcePath: String) -> HTMLWorkspacePackageResource? {
            switch resourcePath {
            case "", HTMLWorkspacePackageEntry.indexHTML:
                return .text(
                    HTMLWorkspacePreviewDocument.render(
                        package: package,
                        theme: previewTheme,
                        themeGuardCSSOverride: themeGuardCSSOverride
                    ),
                    mimeType: "text/html"
                )
            default:
                return HTMLWorkspacePackageResources.resource(for: resourcePath, in: package)
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
            didFinish navigation: WKNavigation!
        ) {
            refreshLiveDOMSnapshot(in: webView)
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
            if navigationAction.request.url?.scheme?.lowercased() == HTMLWorkspaceLocalResourceScheme.scheme {
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
            if message.name == HTMLWorkspaceSafeAPI.messageHandlerName {
                recordConsoleDiagnostic(
                    message: HTMLWorkspaceSafeAPI.deferredDiagnosticMessage,
                    source: HTMLWorkspaceSafeAPI.messageHandlerName
                )
                return
            }

            // SS-HW: the JS-console capture channel -> record one runtime error into the document's
            // console pipeline. The safeAPI channel above remains diagnostic-only for now.
            guard message.name == HTMLWorkspaceConsoleBridge.messageHandlerName,
                  let body = message.body as? [String: Any] else { return }
            recordConsoleDiagnostic(
                message: (body["message"] as? String) ?? "Console error",
                source: body["source"] as? String,
                line: (body["line"] as? NSNumber)?.uint32Value ?? 0,
                column: (body["column"] as? NSNumber)?.uint32Value ?? 0
            )
        }

        private func recordConsoleDiagnostic(
            message: String,
            source: String?,
            line: UInt32 = 0,
            column: UInt32 = 0
        ) {
            let error = HTMLWorkspaceConsoleError(
                message: message,
                source: source,
                line: line,
                column: column,
                timestamp: Int64(Date().timeIntervalSince1970 * 1000)
            )
            onConsoleError?(error)
        }
    }
}
