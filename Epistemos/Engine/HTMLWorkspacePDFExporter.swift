import AppKit
import Foundation
import WebKit

enum HTMLWorkspacePDFExportError: Error, Equatable {
    case loadTimedOut
}

@MainActor
enum HTMLWorkspacePDFExporter {
    static func export(
        package: HTMLWorkspacePackage,
        theme: HTMLWorkspacePreviewTheme? = nil
    ) async throws -> Data {
        let exporter = Exporter(package: package, theme: theme)
        return try await exporter.export()
    }

    private final class Exporter: NSObject, WKNavigationDelegate {
        private static let loadTimeoutNanoseconds: UInt64 = 8_000_000_000

        private let package: HTMLWorkspacePackage
        private let theme: HTMLWorkspacePreviewTheme?
        private var loadContinuation: CheckedContinuation<Void, Error>?
        private var loadTimeoutTask: Task<Void, Never>?
        private let allowedNetworkSchemes: Set<String> = ["http", "https"]

        init(package: HTMLWorkspacePackage, theme: HTMLWorkspacePreviewTheme?) {
            self.package = package
            self.theme = theme
        }

        func export() async throws -> Data {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true

            let webView = WKWebView(
                frame: NSRect(x: 0, y: 0, width: 960, height: 720),
                configuration: configuration
            )
            webView.navigationDelegate = self
            defer {
                webView.navigationDelegate = nil
                loadTimeoutTask?.cancel()
                loadTimeoutTask = nil
                loadContinuation = nil
            }

            try await load(package: package, into: webView)

            let height = try await documentHeight(in: webView)
            let pdfConfiguration = WKPDFConfiguration()
            pdfConfiguration.rect = NSRect(
                x: 0,
                y: 0,
                width: 960,
                height: boundedPDFHeight(from: height)
            )
            let data = try await webView.pdf(configuration: pdfConfiguration)
            return data
        }

        private func load(package: HTMLWorkspacePackage, into webView: WKWebView) async throws {
            try await withCheckedThrowingContinuation { continuation in
                loadContinuation = continuation
                loadTimeoutTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: Self.loadTimeoutNanoseconds)
                    guard !Task.isCancelled else { return }
                    self?.finishLoad(.failure(HTMLWorkspacePDFExportError.loadTimedOut))
                }
                webView.loadHTMLString(
                    HTMLWorkspacePreviewDocument.render(package: package, theme: theme),
                    baseURL: nil
                )
            }
        }

        private func documentHeight(in webView: WKWebView) async throws -> CGFloat {
            let script = "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight, document.body.offsetHeight, document.documentElement.offsetHeight)"
            let value = try await webView.evaluateJavaScript(script)
            if let number = value as? NSNumber {
                return CGFloat(truncating: number)
            }
            if let double = value as? Double {
                return CGFloat(double)
            }
            return 720
        }

        private func boundedPDFHeight(from height: CGFloat) -> CGFloat {
            guard height.isFinite, height > 0 else { return 720 }
            return max(720, min(height, 24_000))
        }

        private func finishLoad(_ result: Result<Void, Error>) {
            guard let continuation = loadContinuation else { return }
            loadContinuation = nil
            loadTimeoutTask?.cancel()
            loadTimeoutTask = nil

            switch result {
            case .success:
                continuation.resume()
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            finishLoad(.success(()))
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            finishLoad(.failure(error))
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            finishLoad(.failure(error))
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
    }
}
