import CryptoKit
import Foundation
import SwiftUI
import WebKit

nonisolated enum HTMLWorkspaceSafeAPI {
    static let messageHandlerName = "htmlWorkspaceSafeAPI"
    static let sourceName = "epistemos://html-workspace/app-bridge"
    static let maxCommandLength = 96
    static let maxMessageLength = 280

    struct Command: Equatable, Sendable {
        let name: String
        let message: String?

        static func fromMessageBody(_ body: Any) -> Command? {
            if let raw = boundedString(body, limit: maxCommandLength) {
                return Command(name: raw, message: nil)
            }
            guard let payload = body as? [String: Any],
                  let name = boundedString(
                    payload["command"] ?? payload["type"] ?? payload["name"],
                    limit: maxCommandLength
                  ) else {
                return nil
            }
            let nestedPayload = payload["payload"] as? [String: Any]
            let message = boundedString(
                payload["message"] ?? payload["label"] ?? nestedPayload?["message"] ?? nestedPayload?["label"],
                limit: maxMessageLength
            )
            return Command(name: name, message: message)
        }

        private static func boundedString(_ value: Any?, limit: Int) -> String? {
            guard let raw = value as? String else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            guard trimmed.count > limit else { return trimmed }
            return String(trimmed.prefix(limit))
        }
    }

    static func diagnosticMessage(
        for command: Command,
        package: HTMLWorkspacePackage
    ) -> String {
        switch command.name.lowercased() {
        case "ping":
            if let message = command.message, !message.isEmpty {
                return "App bridge ping: \(message)"
            }
            return "App bridge ping: ok"
        case "workspace.status", "status":
            let network = package.manifest.sandboxPolicy.allowNetwork ? "network" : "offline"
            return "App bridge status: \(package.manifest.id) / \(network) / safeAPI v\(package.manifest.sandboxPolicy.safeAPIVersion)"
        case "event.record", "record":
            return "App bridge event: \(command.message ?? "received")"
        default:
            return "App bridge unsupported command: \(command.name)"
        }
    }
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
            package.manifest.sandboxPolicy.allowAppBridge ? "bridge-on" : "bridge-off",
            package.manifest.sandboxPolicy.allowPythonRuntime ? "python-on" : "python-off",
            HTMLWorkspacePythonRuntime.assetFingerprint,
            "\(package.manifest.sandboxPolicy.safeAPIVersion)",
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
    var safeAPIEnabled: Bool = false
    var previewTheme: HTMLWorkspacePreviewTheme? = nil
    var themeGuardCSSOverride: String? = nil
    var themeIdentity: String? = nil
    var onConsoleError: (@MainActor (HTMLWorkspaceConsoleError) -> Void)? = nil
    var onDOMSnapshot: (@MainActor (HTMLWorkspaceDOMSnapshot) -> Void)? = nil
    var isElementInspectorEnabled: Bool = false
    var onElementInspection: (@MainActor (HTMLWorkspaceElementInspection) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            package: package,
            safeAPIEnabled: safeAPIEnabled,
            previewTheme: previewTheme,
            themeGuardCSSOverride: themeGuardCSSOverride,
            themeIdentity: themeIdentity,
            onConsoleError: onConsoleError,
            onDOMSnapshot: onDOMSnapshot,
            isElementInspectorEnabled: isElementInspectorEnabled,
            onElementInspection: onElementInspection
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
        if isElementInspectorEnabled, context.coordinator.onElementInspection != nil {
            configuration.userContentController.add(
                context.coordinator,
                name: HTMLWorkspaceInspectorBridge.messageHandlerName
            )
            context.coordinator.inspectorHandlerInstalled = true
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
        context.coordinator.isElementInspectorEnabled = isElementInspectorEnabled
        context.coordinator.onElementInspection = onElementInspection
        context.coordinator.syncSafeAPIHandler(for: webView)
        context.coordinator.syncInspectorHandler(for: webView)
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
        var inspectorHandlerInstalled = false
        var onConsoleError: (@MainActor (HTMLWorkspaceConsoleError) -> Void)?
        var onDOMSnapshot: (@MainActor (HTMLWorkspaceDOMSnapshot) -> Void)?
        var isElementInspectorEnabled: Bool
        var onElementInspection: (@MainActor (HTMLWorkspaceElementInspection) -> Void)?
        lazy var urlSchemeHandler = HTMLWorkspacePreviewURLSchemeHandler { [weak self] resourcePath in
            self?.resourceResponse(for: resourcePath)
        }
        private let allowedNetworkSchemes: Set<String> = ["http", "https"]
        private var isDetached = false
        private var isLoadingPreview = false
        private var pendingRender: PendingRender?

        init(
            package: HTMLWorkspacePackage,
            safeAPIEnabled: Bool,
            previewTheme: HTMLWorkspacePreviewTheme?,
            themeGuardCSSOverride: String?,
            themeIdentity: String?,
            onConsoleError: (@MainActor (HTMLWorkspaceConsoleError) -> Void)?,
            onDOMSnapshot: (@MainActor (HTMLWorkspaceDOMSnapshot) -> Void)?,
            isElementInspectorEnabled: Bool,
            onElementInspection: (@MainActor (HTMLWorkspaceElementInspection) -> Void)?
        ) {
            self.package = package
            self.safeAPIEnabled = safeAPIEnabled
            self.previewTheme = previewTheme
            self.themeGuardCSSOverride = themeGuardCSSOverride
            self.themeIdentity = themeIdentity
            self.onConsoleError = onConsoleError
            self.onDOMSnapshot = onDOMSnapshot
            self.isElementInspectorEnabled = isElementInspectorEnabled
            self.onElementInspection = onElementInspection
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
            webView.loadHTMLString(render.html, baseURL: HTMLWorkspacePreviewURL.baseURL)
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
            finishPreviewNavigation(in: webView, didLoadPage: true)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finishPreviewNavigation(in: webView, didLoadPage: false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            finishPreviewNavigation(in: webView, didLoadPage: false)
        }

        private func finishPreviewNavigation(in webView: WKWebView, didLoadPage: Bool) {
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
            }

            if allowScriptInstall, shouldInstall, !isLoadingPreview, !webView.isLoading {
                webView.evaluateJavaScript(HTMLWorkspaceInspectorBridge.installScript)
            }
        }

        func detach(from webView: WKWebView) {
            isDetached = true
            isLoadingPreview = false
            pendingRender = nil
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
            if inspectorHandlerInstalled {
                webView.configuration.userContentController.removeScriptMessageHandler(
                    forName: HTMLWorkspaceInspectorBridge.messageHandlerName
                )
                inspectorHandlerInstalled = false
            }
            lastRenderedHTML = nil
            lastRenderedThemeIdentity = nil
            lastRenderedShellIdentity = nil
            lastRenderedDataJSON = nil
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
                source: diagnostic.source,
                line: diagnostic.line,
                column: diagnostic.column
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
            onConsoleError?(error.boundedForPackage())
        }
    }
}
