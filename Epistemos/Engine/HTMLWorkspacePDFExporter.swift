import AppKit
import Foundation
import WebKit

// WebView migration (2026-06-24, WEBVIEW_MIGRATION_LEDGER B-cluster, first real migration): the headless HTML→PDF
// exporter on the macOS-26 SwiftUI WebKit API (`WebPage`) — NO legacy WebKit NSView host. Behavior-preserving:
//   - same non-persistent data store + content-JS-on;
//   - same scheme allowlist (about→allow; no-network sandbox→cancel; non-http(s)→cancel) via `NavigationDeciding`;
//   - same `documentHeight` measurement + bounded 960×height PDF rect via `exported(as: .pdf(region: .rect(…)))`;
//   - same 8s load timeout (`loadTimedOut`).
// RUNTIME-PROOF-OWED: the produced PDF (size/pagination/content completeness) is owner-verifiable by exporting one.

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

    /// Scheme allowlist preserved EXACTLY from the legacy navigation policy. macOS-26 `NavigationDeciding`
    /// (async, returns the policy) replaces the old delegate `decidePolicyFor` + `decisionHandler` callback.
    private struct SchemeNavigationDecider: WebPage.NavigationDeciding {
        let allowNetwork: Bool
        private let allowedNetworkSchemes: Set<String> = ["http", "https"]

        func decidePolicy(
            for action: WebPage.NavigationAction,
            preferences: inout WebPage.NavigationPreferences
        ) async -> WKNavigationActionPolicy {
            let url = action.request.url
            if url?.scheme == "about" { return .allow }
            if allowNetwork == false { return .cancel }
            guard let scheme = url?.scheme?.lowercased(),
                  allowedNetworkSchemes.contains(scheme) else { return .cancel }
            return .allow
        }
    }

    @MainActor
    private final class Exporter {
        private static let loadTimeoutNanoseconds: UInt64 = 8_000_000_000
        private static let renderWidth: CGFloat = 960

        private let package: HTMLWorkspacePackage
        private let theme: HTMLWorkspacePreviewTheme?

        init(package: HTMLWorkspacePackage, theme: HTMLWorkspacePreviewTheme?) {
            self.package = package
            self.theme = theme
        }

        func export() async throws -> Data {
            var configuration = WebPage.Configuration()
            configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
            configuration.defaultNavigationPreferences.allowsContentJavaScript = true

            let page = WebPage(
                configuration: configuration,
                navigationDecider: SchemeNavigationDecider(
                    allowNetwork: package.manifest.sandboxPolicy.allowNetwork
                )
            )

            try await load(into: page)

            let height = try await documentHeight(in: page)
            return try await page.exported(
                as: .pdf(
                    region: .rect(
                        NSRect(x: 0, y: 0, width: Self.renderWidth, height: boundedPDFHeight(from: height))
                    )
                )
            )
        }

        /// Drive the `load(html:)` navigation stream to `.finished` on the main actor while a timeout
        /// task races it. Checking a deadline only when navigation events arrive still hangs if the
        /// stream stalls before the next event.
        private func load(into page: WebPage) async throws {
            let html = HTMLWorkspacePreviewDocument.render(
                package: package,
                theme: theme,
                resourceMode: .inlinePackageAssets
            )
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await Self.waitForLoadFinished(page: page, html: html)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: Self.loadTimeoutNanoseconds)
                    throw HTMLWorkspacePDFExportError.loadTimedOut
                }
                defer { group.cancelAll() }
                _ = try await group.next()
            }
        }

        @MainActor
        private static func waitForLoadFinished(page: WebPage, html: String) async throws {
            for try await event in page.load(html: html) {
                if event == .finished { return }
            }
            throw HTMLWorkspacePDFExportError.loadTimedOut
        }

        private func documentHeight(in page: WebPage) async throws -> CGFloat {
            let script = "return Math.max(document.body.scrollHeight, document.documentElement.scrollHeight, document.body.offsetHeight, document.documentElement.offsetHeight)"
            let value = try await page.callJavaScript(script)
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
    }
}
