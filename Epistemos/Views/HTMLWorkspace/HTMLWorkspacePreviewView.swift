import SwiftUI
import WebKit

nonisolated enum HTMLWorkspaceSafeAPI {
    static let messageHandlerName = "htmlWorkspaceSafeAPI"
}

struct HTMLWorkspacePreviewView: NSViewRepresentable {
    var package: HTMLWorkspacePackage
    var safeAPIEnabled: Bool = false
    var previewTheme: HTMLWorkspacePreviewTheme? = nil
    var themeGuardCSSOverride: String? = nil
    var themeIdentity: String? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            package: package,
            safeAPIEnabled: safeAPIEnabled,
            previewTheme: previewTheme,
            themeGuardCSSOverride: themeGuardCSSOverride,
            themeIdentity: themeIdentity
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
        guard context.coordinator.lastRenderedHTML != rendered else { return }
        context.coordinator.lastRenderedHTML = rendered
        webView.loadHTMLString(rendered, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var package: HTMLWorkspacePackage
        var safeAPIEnabled: Bool
        var previewTheme: HTMLWorkspacePreviewTheme?
        var themeGuardCSSOverride: String?
        var themeIdentity: String?
        var lastRenderedHTML: String?
        var messageHandlerInstalled = false
        private let allowedNetworkSchemes: Set<String> = ["http", "https"]

        init(
            package: HTMLWorkspacePackage,
            safeAPIEnabled: Bool,
            previewTheme: HTMLWorkspacePreviewTheme?,
            themeGuardCSSOverride: String?,
            themeIdentity: String?
        ) {
            self.package = package
            self.safeAPIEnabled = safeAPIEnabled
            self.previewTheme = previewTheme
            self.themeGuardCSSOverride = themeGuardCSSOverride
            self.themeIdentity = themeIdentity
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
            lastRenderedHTML = nil
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
        }
    }
}
