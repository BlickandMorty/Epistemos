import CryptoKit
import Foundation
import SwiftUI
import WebKit

nonisolated enum HTMLWorkspacePreviewIdentity {
    static func viewIdentity(for package: HTMLWorkspacePackage) -> String {
        "\(package.manifest.id)-\(contentShellHash(for: package))-\(assetShellHash(for: package))"
    }

    static func renderShellIdentity(
        for package: HTMLWorkspacePackage,
        routeName: String? = nil,
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
            package.manifest.sandboxPolicy.allowAppBridge ? "bridge-on" : "bridge-off",
            package.manifest.sandboxPolicy.allowPythonRuntime ? "python-on" : "python-off",
            HTMLWorkspacePythonRuntime.assetFingerprint,
            "\(package.manifest.sandboxPolicy.safeAPIVersion)",
            previewTheme?.rawValue ?? "system",
            themeGuardCSS,
            HTMLWorkspacePreviewTheme.hostCSS,
            routeName ?? HTMLWorkspacePackageEntry.indexHTML,
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

        let response = Self.response(url: url, asset: asset)
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(asset.data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private static func response(url: URL, asset: HTMLWorkspacePackageResource) -> URLResponse {
        var contentType = asset.mimeType
        if let encoding = asset.textEncodingName, !encoding.isEmpty {
            contentType += "; charset=\(encoding)"
        }
        let headers = [
            "Content-Type": contentType,
            "Content-Length": "\(asset.data.count)",
            "Cache-Control": "no-store",
        ]
        return HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) ?? URLResponse(
            url: url,
            mimeType: asset.mimeType,
            expectedContentLength: asset.data.count,
            textEncodingName: asset.textEncodingName
        )
    }

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
           components[0] == "runtime",
           components[1] == "python",
           HTMLWorkspacePackage.validateRuntimeResourceComponent(components[2]) {
            return "\(HTMLWorkspacePythonRuntime.urlPathPrefix)/\(components[2])"
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
    var routeName: String? = nil
    var safeAPIEnabled: Bool = false
    var previewTheme: HTMLWorkspacePreviewTheme? = nil
    var themeGuardCSSOverride: String? = nil
    var themeIdentity: String? = nil
    var onConsoleError: (@MainActor (HTMLWorkspaceConsoleError) -> Void)? = nil
    var onDOMSnapshot: (@MainActor (HTMLWorkspaceDOMSnapshot) -> Void)? = nil
    var isElementInspectorEnabled: Bool = false
    var onElementInspection: (@MainActor (HTMLWorkspaceElementInspection) -> Void)? = nil
    var appBridgeProbeNonce: Int = 0
    var consoleProbeNonce: Int = 0
    var pythonProbeNonce: Int = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(
            package: package,
            routeName: routeName,
            safeAPIEnabled: safeAPIEnabled,
            previewTheme: previewTheme,
            themeGuardCSSOverride: themeGuardCSSOverride,
            themeIdentity: themeIdentity,
            onConsoleError: onConsoleError,
            onDOMSnapshot: onDOMSnapshot,
            isElementInspectorEnabled: isElementInspectorEnabled,
            onElementInspection: onElementInspection,
            appBridgeProbeNonce: appBridgeProbeNonce,
            consoleProbeNonce: consoleProbeNonce,
            pythonProbeNonce: pythonProbeNonce
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
            context.coordinator.installConsoleBridgeUserScript(on: configuration.userContentController)
            context.coordinator.consoleHandlerInstalled = true
        }
        if isElementInspectorEnabled, context.coordinator.onElementInspection != nil {
            configuration.userContentController.add(
                context.coordinator,
                name: HTMLWorkspaceInspectorBridge.messageHandlerName
            )
            context.coordinator.inspectorHandlerInstalled = true
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView
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
        context.coordinator.routeName = routeName
        context.coordinator.safeAPIEnabled = safeAPIEnabled
        context.coordinator.previewTheme = previewTheme
        context.coordinator.themeGuardCSSOverride = themeGuardCSSOverride
        context.coordinator.themeIdentity = themeIdentity
        context.coordinator.onConsoleError = onConsoleError
        context.coordinator.onDOMSnapshot = onDOMSnapshot
        context.coordinator.isElementInspectorEnabled = isElementInspectorEnabled
        context.coordinator.onElementInspection = onElementInspection
        context.coordinator.webView = webView
        context.coordinator.syncSafeAPIHandler(for: webView)
        context.coordinator.syncConsoleHandler(for: webView)
        context.coordinator.syncInspectorHandler(for: webView)
        context.coordinator.requestAppBridgeProbe(appBridgeProbeNonce, in: webView)
        context.coordinator.requestConsoleProbe(consoleProbeNonce, in: webView)
        context.coordinator.requestPythonProbe(pythonProbeNonce, in: webView)
        loadPreview(into: webView, context: context)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.detach(from: webView)
        EpdocWebViewShared.notifyWebViewDismantled()
    }

    private func loadPreview(into webView: WKWebView, context: Context) {
        let rendered = HTMLWorkspacePreviewDocument.render(
            package: package,
            routeName: routeName,
            theme: previewTheme,
            themeGuardCSSOverride: themeGuardCSSOverride
        )
        let shellIdentity = HTMLWorkspacePreviewIdentity.renderShellIdentity(
            for: package,
            routeName: routeName,
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
                shellIdentity: shellIdentity,
                themeIdentity: themeIdentity,
                in: webView
            )
            return
        }
        context.coordinator.loadRenderedHTML(
            rendered,
            shellIdentity: shellIdentity,
            themeIdentity: themeIdentity,
            dataJSON: package.dataJSON,
            in: webView
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private struct PendingRender {
            let html: String
            let shellIdentity: String
            let themeIdentity: String?
            let dataJSON: String
        }

        var package: HTMLWorkspacePackage
        var routeName: String?
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
        var consoleUserScriptInstalled = false
        var inspectorHandlerInstalled = false
        var onConsoleError: (@MainActor (HTMLWorkspaceConsoleError) -> Void)?
        var onDOMSnapshot: (@MainActor (HTMLWorkspaceDOMSnapshot) -> Void)?
        var isElementInspectorEnabled: Bool
        var onElementInspection: (@MainActor (HTMLWorkspaceElementInspection) -> Void)?
        var lastAppBridgeProbeNonce: Int
        var pendingAppBridgeProbeNonce: Int?
        var lastConsoleProbeNonce: Int
        var pendingConsoleProbeNonce: Int?
        var lastPythonProbeNonce: Int
        var pendingPythonProbeNonce: Int?
        var lastInspectorProbeShellIdentity: String?
        var lastPythonProbeShellIdentity: String?
        weak var webView: WKWebView?
        lazy var urlSchemeHandler = HTMLWorkspacePreviewURLSchemeHandler { [weak self] resourcePath in
            self?.resourceResponse(for: resourcePath)
        }
        private let allowedNetworkSchemes: Set<String> = ["http", "https"]
        private var isDetached = false
        private var isLoadingPreview = false
        private var pendingRender: PendingRender?
        private var activeNavigation: WKNavigation?

        init(
            package: HTMLWorkspacePackage,
            routeName: String?,
            safeAPIEnabled: Bool,
            previewTheme: HTMLWorkspacePreviewTheme?,
            themeGuardCSSOverride: String?,
            themeIdentity: String?,
            onConsoleError: (@MainActor (HTMLWorkspaceConsoleError) -> Void)?,
            onDOMSnapshot: (@MainActor (HTMLWorkspaceDOMSnapshot) -> Void)?,
            isElementInspectorEnabled: Bool,
            onElementInspection: (@MainActor (HTMLWorkspaceElementInspection) -> Void)?,
            appBridgeProbeNonce: Int,
            consoleProbeNonce: Int,
            pythonProbeNonce: Int
        ) {
            self.package = package
            self.routeName = routeName
            self.safeAPIEnabled = safeAPIEnabled
            self.previewTheme = previewTheme
            self.themeGuardCSSOverride = themeGuardCSSOverride
            self.themeIdentity = themeIdentity
            self.onConsoleError = onConsoleError
            self.onDOMSnapshot = onDOMSnapshot
            self.isElementInspectorEnabled = isElementInspectorEnabled
            self.onElementInspection = onElementInspection
            self.lastAppBridgeProbeNonce = 0
            self.pendingAppBridgeProbeNonce = appBridgeProbeNonce > 0 ? appBridgeProbeNonce : nil
            self.lastConsoleProbeNonce = 0
            self.pendingConsoleProbeNonce = consoleProbeNonce > 0 ? consoleProbeNonce : nil
            self.lastPythonProbeNonce = 0
            self.pendingPythonProbeNonce = pythonProbeNonce > 0 ? pythonProbeNonce : nil
        }

        func canPatchDataOnly(shellIdentity: String, dataJSON: String) -> Bool {
            guard !isDetached,
                  !isLoadingPreview,
                  pendingRender == nil,
                  lastRenderedHTML != nil,
                  lastRenderedShellIdentity == shellIdentity,
                  lastRenderedDataJSON != dataJSON else {
                return false
            }
            return true
        }

        func loadRenderedHTML(
            _ html: String,
            shellIdentity: String,
            themeIdentity: String?,
            dataJSON: String,
            in webView: WKWebView
        ) {
            guard !isDetached else { return }
            let render = PendingRender(
                html: html,
                shellIdentity: shellIdentity,
                themeIdentity: themeIdentity,
                dataJSON: dataJSON
            )
            guard lastRenderedHTML != html ||
                    lastRenderedThemeIdentity != themeIdentity ||
                    lastRenderedShellIdentity != shellIdentity ||
                    lastRenderedDataJSON != dataJSON else {
                pendingRender = nil
                return
            }
            guard !isLoadingPreview, !webView.isLoading else {
                pendingRender = render
                return
            }
            startRender(render, in: webView)
        }

        private func startRender(_ render: PendingRender, in webView: WKWebView) {
            guard !isDetached else { return }
            pendingRender = nil
            isLoadingPreview = true
            lastRenderedHTML = render.html
            lastRenderedThemeIdentity = render.themeIdentity
            lastRenderedShellIdentity = render.shellIdentity
            lastRenderedDataJSON = render.dataJSON
            lastInspectorProbeShellIdentity = nil
            lastPythonProbeShellIdentity = nil
            activeNavigation = webView.loadHTMLString(
                render.html,
                baseURL: HTMLWorkspacePreviewURL.baseURL
            )
        }

        func patchDataJSON(
            _ dataJSON: String,
            renderedFallbackHTML: String,
            shellIdentity: String,
            themeIdentity: String?,
            in webView: WKWebView
        ) {
            guard !isDetached else { return }
            guard !isLoadingPreview, !webView.isLoading else {
                loadRenderedHTML(
                    renderedFallbackHTML,
                    shellIdentity: shellIdentity,
                    themeIdentity: themeIdentity,
                    dataJSON: dataJSON,
                    in: webView
                )
                return
            }
            lastRenderedHTML = renderedFallbackHTML
            lastRenderedThemeIdentity = themeIdentity
            lastRenderedShellIdentity = shellIdentity
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
                guard let self, let webView, !self.isDetached else { return }
                guard !self.isLoadingPreview,
                      !webView.isLoading,
                      self.lastRenderedShellIdentity == shellIdentity,
                      self.lastRenderedDataJSON == dataJSON,
                      self.lastRenderedHTML == renderedFallbackHTML else { return }
                if error != nil || (result as? String) != "patched" {
                    self.startRender(
                        PendingRender(
                            html: renderedFallbackHTML,
                            shellIdentity: shellIdentity,
                            themeIdentity: themeIdentity,
                            dataJSON: dataJSON
                        ),
                        in: webView
                    )
                } else {
                    self.refreshLiveDOMSnapshot(in: webView)
                }
            }
        }

        func refreshLiveDOMSnapshot(in webView: WKWebView) {
            guard !isDetached, !isLoadingPreview, !webView.isLoading, onDOMSnapshot != nil else { return }
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

        private static let appBridgeProbeScript = """
        (() => {
          const app = window.HTMLWorkspaceApp;
          if (!app || app.enabled !== true || typeof app.request !== 'function') { return 'missing'; }
          return app.request('ping', 'manual probe', { timeoutMs: 1500 })
            .then((detail) => detail && detail.message ? 'roundtrip: ' + detail.message : 'roundtrip')
            .catch((error) => 'failed: ' + (error && error.message ? error.message : String(error)));
        })();
        """

        private static let consoleProbeScript = """
        (() => {
          const handlers = window.webkit && window.webkit.messageHandlers;
          if (!handlers || !handlers.epistemosWorkspaceConsole) { return 'handler-missing'; }
          console.log('HTML Workspace log probe');
          console.info('HTML Workspace info probe');
          console.warn('HTML Workspace console probe');
          console.error('HTML Workspace error probe');
          window.dispatchEvent(new ErrorEvent('error', {
            message: 'HTML Workspace window error probe',
            filename: 'html-workspace-console-probe.js',
            lineno: 1,
            colno: 1
          }));
          setTimeout(() => {
            Promise.reject(new Error('HTML Workspace rejection probe'));
          }, 0);
          return 'posted';
        })();
        """

        private static let pythonProbeScript = """
        (() => {
          const runtime = window.HTMLWorkspace && window.HTMLWorkspace.python;
          if (!runtime || runtime.enabled !== true) { return 'disabled'; }
          if (runtime.available !== true) { return runtime.status || 'missing'; }
          runtime.run('sum(range(10))').then((result) => {
            console.warn('HTML Workspace Python probe: ' + String(result));
          }).catch((error) => {
            console.error('HTML Workspace Python probe failed', error);
          });
          return 'started';
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
                if let routeName = HTMLWorkspacePackageResources.packageRouteName(for: resourcePath),
                   routeName == HTMLWorkspacePackageEntry.indexHTML || package.routes[routeName] != nil {
                    return .text(
                        HTMLWorkspacePreviewDocument.render(
                            package: package,
                            routeName: routeName == HTMLWorkspacePackageEntry.indexHTML ? nil : routeName,
                            theme: previewTheme,
                            themeGuardCSSOverride: themeGuardCSSOverride
                        ),
                        mimeType: "text/html"
                    )
                }
                if let pythonResourceName = Self.pythonRuntimeResourceName(for: resourcePath),
                   package.manifest.sandboxPolicy.allowPythonRuntime {
                    return HTMLWorkspacePythonRuntime.resource(for: pythonResourceName)
                }
                return HTMLWorkspacePackageResources.resource(for: resourcePath, in: package)
            }
        }

        private static func pythonRuntimeResourceName(for resourcePath: String) -> String? {
            let prefix = "\(HTMLWorkspacePythonRuntime.urlPathPrefix)/"
            guard resourcePath.hasPrefix(prefix) else { return nil }
            let name = String(resourcePath.dropFirst(prefix.count))
            return HTMLWorkspacePackage.validateRuntimeResourceComponent(name) ? name : nil
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
            finishPreviewNavigation(navigation, in: webView, didLoadPage: true)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finishPreviewNavigation(navigation, in: webView, didLoadPage: false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            finishPreviewNavigation(navigation, in: webView, didLoadPage: false)
        }

        private func finishPreviewNavigation(
            _ navigation: WKNavigation?,
            in webView: WKWebView,
            didLoadPage: Bool
        ) {
            guard let activeNavigation, navigation === activeNavigation else { return }
            self.activeNavigation = nil
            isLoadingPreview = false
            guard !isDetached else { return }
            if let pendingRender {
                syncInspectorHandler(for: webView, allowScriptInstall: false)
                startRender(pendingRender, in: webView)
                return
            }
            syncInspectorHandler(for: webView, allowScriptInstall: didLoadPage)
            guard didLoadPage else { return }
            refreshLiveDOMSnapshot(in: webView)
            if let nonce = pendingAppBridgeProbeNonce {
                pendingAppBridgeProbeNonce = nil
                requestAppBridgeProbe(nonce, in: webView)
            }
            if let nonce = pendingConsoleProbeNonce {
                pendingConsoleProbeNonce = nil
                requestConsoleProbe(nonce, in: webView)
            }
            if let nonce = pendingPythonProbeNonce {
                pendingPythonProbeNonce = nil
                requestPythonProbe(nonce, in: webView)
            }
            requestPythonProbe(in: webView)
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

        func installConsoleBridgeUserScript(on userContentController: WKUserContentController) {
            guard !consoleUserScriptInstalled else { return }
            userContentController.addUserScript(
                WKUserScript(
                    source: HTMLWorkspaceConsoleBridge.injectionScript,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: true
                )
            )
            consoleUserScriptInstalled = true
        }

        func syncConsoleHandler(for webView: WKWebView) {
            let shouldInstall = HTMLWorkspaceConsoleBridge.enabled && onConsoleError != nil
            if shouldInstall {
                if !consoleHandlerInstalled {
                    webView.configuration.userContentController.add(
                        self,
                        name: HTMLWorkspaceConsoleBridge.messageHandlerName
                    )
                    consoleHandlerInstalled = true
                }
                let hadUserScript = consoleUserScriptInstalled
                installConsoleBridgeUserScript(on: webView.configuration.userContentController)
                if !hadUserScript, !isLoadingPreview, !webView.isLoading {
                    webView.evaluateJavaScript(HTMLWorkspaceConsoleBridge.injectionScript)
                }
            } else {
                if consoleHandlerInstalled {
                    webView.configuration.userContentController.removeScriptMessageHandler(
                        forName: HTMLWorkspaceConsoleBridge.messageHandlerName
                    )
                    consoleHandlerInstalled = false
                }
                if consoleUserScriptInstalled {
                    webView.configuration.userContentController.removeAllUserScripts()
                    consoleUserScriptInstalled = false
                }
            }
        }

        func requestAppBridgeProbe(_ nonce: Int, in webView: WKWebView) {
            guard nonce > 0, nonce != lastAppBridgeProbeNonce else { return }
            guard safeAPIEnabled, package.manifest.sandboxPolicy.allowAppBridge else {
                lastAppBridgeProbeNonce = nonce
                recordConsoleDiagnostic(
                    message: "App bridge probe skipped: sandbox gate is off",
                    source: HTMLWorkspaceSafeAPI.sourceName
                )
                return
            }
            guard !isLoadingPreview, !webView.isLoading else {
                pendingAppBridgeProbeNonce = nonce
                return
            }
            lastAppBridgeProbeNonce = nonce
            webView.evaluateJavaScript(Self.appBridgeProbeScript) { [weak self] result, error in
                guard let self, !self.isDetached else { return }
                let status = (result as? String) ?? (error == nil ? "unknown" : "failed")
                self.recordConsoleDiagnostic(
                    message: "App bridge probe: \(status)",
                    source: HTMLWorkspaceSafeAPI.sourceName
                )
            }
        }

        func requestConsoleProbe(_ nonce: Int, in webView: WKWebView) {
            guard nonce > 0, nonce != lastConsoleProbeNonce else { return }
            guard HTMLWorkspaceConsoleBridge.enabled, onConsoleError != nil else {
                lastConsoleProbeNonce = nonce
                recordConsoleDiagnostic(
                    message: "Console capture probe skipped: capture bridge is off",
                    source: HTMLWorkspaceConsoleBridge.messageHandlerName
                )
                return
            }
            guard !isLoadingPreview, !webView.isLoading else {
                pendingConsoleProbeNonce = nonce
                return
            }
            lastConsoleProbeNonce = nonce
            webView.evaluateJavaScript(Self.consoleProbeScript) { [weak self] result, error in
                guard let self, !self.isDetached else { return }
                let status = (result as? String) ?? (error == nil ? "unknown" : "failed")
                self.recordConsoleDiagnostic(
                    message: "Console capture probe: \(status)",
                    source: HTMLWorkspaceConsoleBridge.messageHandlerName
                )
            }
        }

        func syncInspectorHandler(
            for webView: WKWebView,
            allowScriptInstall: Bool = true
        ) {
            let shouldInstall = isElementInspectorEnabled && onElementInspection != nil
            if shouldInstall, !inspectorHandlerInstalled {
                webView.configuration.userContentController.add(
                    self,
                    name: HTMLWorkspaceInspectorBridge.messageHandlerName
                )
                inspectorHandlerInstalled = true
            } else if !shouldInstall, inspectorHandlerInstalled {
                guard !isLoadingPreview, !webView.isLoading else { return }
                webView.evaluateJavaScript(HTMLWorkspaceInspectorBridge.disableScript)
                webView.configuration.userContentController.removeScriptMessageHandler(
                    forName: HTMLWorkspaceInspectorBridge.messageHandlerName
                )
                inspectorHandlerInstalled = false
                lastInspectorProbeShellIdentity = nil
            }

            if allowScriptInstall, shouldInstall, !isLoadingPreview, !webView.isLoading {
                webView.evaluateJavaScript(HTMLWorkspaceInspectorBridge.installScript) { [weak self, weak webView] _, _ in
                    guard let self, let webView, !self.isDetached else { return }
                    self.requestInspectorProbe(in: webView)
                }
            }
        }

        private func requestInspectorProbe(in webView: WKWebView) {
            guard isElementInspectorEnabled, onElementInspection != nil, !isLoadingPreview, !webView.isLoading else { return }
            let shellIdentity = lastRenderedShellIdentity ?? "unrendered"
            guard lastInspectorProbeShellIdentity != shellIdentity else { return }
            lastInspectorProbeShellIdentity = shellIdentity
            webView.evaluateJavaScript(HTMLWorkspaceInspectorBridge.probeScript) { [weak self] result, error in
                guard let self, !self.isDetached else { return }
                let status = (result as? String) ?? (error == nil ? "unknown" : "failed")
                self.recordConsoleDiagnostic(
                    message: "DOM inspector probe: \(status)",
                    source: HTMLWorkspaceInspectorBridge.messageHandlerName
                )
            }
        }

        private func requestPythonProbe(in webView: WKWebView) {
            guard package.manifest.sandboxPolicy.allowPythonRuntime, !isLoadingPreview, !webView.isLoading else { return }
            let shellIdentity = lastRenderedShellIdentity ?? "unrendered"
            guard lastPythonProbeShellIdentity != shellIdentity else { return }
            lastPythonProbeShellIdentity = shellIdentity
            evaluatePythonProbe(in: webView, messagePrefix: "Python runtime probe")
        }

        func requestPythonProbe(_ nonce: Int, in webView: WKWebView) {
            guard nonce > 0, nonce != lastPythonProbeNonce else { return }
            guard package.manifest.sandboxPolicy.allowPythonRuntime else {
                lastPythonProbeNonce = nonce
                recordConsoleDiagnostic(
                    message: "Python runtime probe skipped: sandbox gate is off",
                    source: HTMLWorkspacePythonRuntime.urlPathPrefix
                )
                return
            }
            guard !isLoadingPreview, !webView.isLoading else {
                pendingPythonProbeNonce = nonce
                return
            }
            lastPythonProbeNonce = nonce
            evaluatePythonProbe(in: webView, messagePrefix: "Python runtime manual probe")
        }

        private func evaluatePythonProbe(in webView: WKWebView, messagePrefix: String) {
            webView.evaluateJavaScript(Self.pythonProbeScript) { [weak self] result, error in
                guard let self, !self.isDetached else { return }
                let status = (result as? String) ?? (error == nil ? "unknown" : "failed")
                self.recordConsoleDiagnostic(
                    message: "\(messagePrefix): \(status)",
                    source: HTMLWorkspacePythonRuntime.urlPathPrefix
                )
            }
        }

        func detach(from webView: WKWebView) {
            isDetached = true
            isLoadingPreview = false
            pendingRender = nil
            activeNavigation = nil
            pendingAppBridgeProbeNonce = nil
            pendingConsoleProbeNonce = nil
            pendingPythonProbeNonce = nil
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
            if consoleUserScriptInstalled {
                webView.configuration.userContentController.removeAllUserScripts()
                consoleUserScriptInstalled = false
            }
            if inspectorHandlerInstalled {
                webView.configuration.userContentController.removeScriptMessageHandler(
                    forName: HTMLWorkspaceInspectorBridge.messageHandlerName
                )
                inspectorHandlerInstalled = false
            }
            lastInspectorProbeShellIdentity = nil
            lastPythonProbeShellIdentity = nil
            lastRenderedHTML = nil
            lastRenderedThemeIdentity = nil
            lastRenderedShellIdentity = nil
            lastRenderedDataJSON = nil
            self.webView = nil
            webView.stopLoading()
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == HTMLWorkspaceSafeAPI.messageHandlerName {
                guard safeAPIEnabled, package.manifest.sandboxPolicy.allowAppBridge else {
                    recordConsoleDiagnostic(
                        message: "App bridge denied: sandbox gate is off",
                        source: HTMLWorkspaceSafeAPI.sourceName
                    )
                    return
                }
                guard let command = HTMLWorkspaceSafeAPI.Command.fromMessageBody(message.body) else {
                    recordConsoleDiagnostic(
                        message: "App bridge rejected malformed message",
                        source: HTMLWorkspaceSafeAPI.sourceName
                    )
                    return
                }
                recordConsoleDiagnostic(
                    message: HTMLWorkspaceSafeAPI.diagnosticMessage(for: command, package: package),
                    source: HTMLWorkspaceSafeAPI.sourceName
                )
                dispatchAppBridgeResponse(command: command, in: webView)
                return
            }

            // SS-HW: the JS-console capture channel -> record one runtime error into the document's
            // console pipeline. The safeAPI channel above is the gated app-message bridge.
            if message.name == HTMLWorkspaceInspectorBridge.messageHandlerName,
               isElementInspectorEnabled,
               let inspection = HTMLWorkspaceElementInspection.fromMessageBody(message.body) {
                onElementInspection?(inspection)
                return
            }
            guard message.name == HTMLWorkspaceConsoleBridge.messageHandlerName,
                  let diagnostic = HTMLWorkspaceConsoleBridge.DiagnosticPayload.fromMessageBody(message.body) else { return }
            recordConsoleDiagnostic(
                message: diagnostic.message,
                source: diagnostic.source ?? activeDocumentSourceName,
                line: diagnostic.line,
                column: diagnostic.column,
                severity: diagnostic.severity
            )
        }

        private func dispatchAppBridgeResponse(command: HTMLWorkspaceSafeAPI.Command, in webView: WKWebView?) {
            guard let webView, !isDetached else { return }
            guard !isLoadingPreview, !webView.isLoading else { return }
            let response = HTMLWorkspaceSafeAPI.diagnosticMessage(for: command, package: package)
            let isSupported = command.isSupported
            let script = """
            window.dispatchEvent(new CustomEvent('htmlworkspace:appbridge', {
              detail: {
                command: \(Self.javaScriptStringLiteral(command.name)),
                requestId: \(Self.optionalJavaScriptStringLiteral(command.requestID)),
                ok: \(isSupported ? "true" : "false"),
                error: \(Self.optionalJavaScriptStringLiteral(isSupported ? nil : response)),
                message: \(Self.javaScriptStringLiteral(response)),
                safeAPIVersion: \(package.manifest.sandboxPolicy.safeAPIVersion)
              }
            }));
            """
            webView.evaluateJavaScript(script)
        }

        private static func optionalJavaScriptStringLiteral(_ value: String?) -> String {
            guard let value else { return "null" }
            return javaScriptStringLiteral(value)
        }

        private func recordConsoleDiagnostic(
            message: String,
            source: String?,
            line: UInt32 = 0,
            column: UInt32 = 0,
            severity: HTMLWorkspaceConsoleSeverity = .diagnostic
        ) {
            let error = HTMLWorkspaceConsoleError(
                message: message,
                source: source,
                line: line,
                column: column,
                timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                severity: severity
            )
            onConsoleError?(error.boundedForPackage())
        }

        private var activeDocumentSourceName: String {
            if let routeName, !routeName.isEmpty {
                return "\(HTMLWorkspacePackageEntry.routes)/\(routeName)"
            }
            return HTMLWorkspacePackageEntry.indexHTML
        }
    }
}
