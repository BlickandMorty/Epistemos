import AppKit
import Foundation
import SwiftUI

enum HTMLWorkspaceLayoutMode: String, CaseIterable, Identifiable {
    case split
    case source
    case preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .split: "Split"
        case .source: "Source"
        case .preview: "Preview"
        }
    }
}

enum HTMLWorkspacePreviewThemeGuard {
    static func css(for workspaceTheme: EpistemosTheme) -> String {
        let background = MarkdownPreviewSurfaceStyle
            .canvasNSColor(for: workspaceTheme)
            .rgbSafeForCodeEditorTheme()
            .withAlphaComponent(1.0)
            .htmlWorkspaceCSSColor
        let foregroundSource = workspaceTheme.isDark
            ? NSColor(deviceWhite: 0.94, alpha: 1.0)
            : workspaceTheme.resolved.foreground.nsColor
        let mutedSource = workspaceTheme.isDark
            ? NSColor(deviceWhite: 0.80, alpha: 1.0)
            : workspaceTheme.resolved.mutedForeground.nsColor
        let foreground = foregroundSource
            .rgbSafeForCodeEditorTheme()
            .htmlWorkspaceCSSColor
        let muted = mutedSource
            .rgbSafeForCodeEditorTheme()
            .htmlWorkspaceCSSColor
        let card = workspaceTheme.resolved.card.nsColor
            .rgbSafeForCodeEditorTheme()
            .withAlphaComponent(1.0)
            .htmlWorkspaceCSSColor
        let border = workspaceTheme.resolved.glassBorder.nsColor
            .rgbSafeForCodeEditorTheme()
            .htmlWorkspaceCSSColor(opacity: workspaceTheme.isDark ? 0.48 : 0.32)
        let accent = workspaceTheme.resolved.accent.nsColor
            .rgbSafeForCodeEditorTheme()
            .htmlWorkspaceCSSColor
        let scheme = workspaceTheme.isDark ? "dark" : "light"

        return """
        :root {
          color-scheme: \(scheme);
          --epistemos-workspace-bg: \(background);
          --epistemos-workspace-fg: \(foreground);
          --epistemos-workspace-muted: \(muted);
          --epistemos-workspace-card: \(card);
          --epistemos-workspace-border: \(border);
          --epistemos-workspace-accent: \(accent);
          --epistemos-workspace-title-font: "MatrixTypeDisplay-Regular", "MatrixTypeDisplay", -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
          --epistemos-workspace-heading-font: "ChonkyPixels", "MatrixTypeDisplay-Regular", "MatrixTypeDisplay", -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
          --epistemos-workspace-body-font: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
        }

        html[data-epistemos-theme] body,
        html[data-epistemos-theme],
        html[data-epistemos-theme] main.workspace {
          background: var(--epistemos-workspace-bg) !important;
          color: var(--epistemos-workspace-fg) !important;
        }

        html[data-epistemos-theme="dark"] body,
        html[data-epistemos-theme="dark"] body :where(*):not(svg):not(path),
        html[data-epistemos-theme="dark"] body :is(p, li, span, div, small, strong, em, label, td, th, blockquote, pre, code, dd, dt, figcaption, summary, legend) {
          color: var(--epistemos-workspace-fg) !important;
        }

        html[data-epistemos-theme="dark"] body :is(.muted, .secondary, .subtle, .caption, .eyebrow, .meta, [data-muted]) {
          color: var(--epistemos-workspace-muted) !important;
        }

        html[data-epistemos-theme="light"] body :is(p, li, span, small, strong, em, label, td, th, blockquote, pre, code, dd, dt, figcaption, summary, legend) {
          color: inherit;
        }

        html[data-epistemos-theme] body :is(h1, h2, h3, h4, h5, h6) {
          color: var(--epistemos-workspace-fg) !important;
        }

        html[data-epistemos-theme] body a {
          color: var(--epistemos-workspace-accent) !important;
        }

        html[data-epistemos-theme] body :is(hr, table, th, td, fieldset, input, textarea, select) {
          border-color: var(--epistemos-workspace-border) !important;
        }

        html[data-epistemos-theme] :is(.metric-card, [data-metrics] article, .card, section[data-card]) {
          background: var(--epistemos-workspace-card);
          border-color: var(--epistemos-workspace-border);
        }
        """
    }
}

enum HTMLWorkspaceSourcePane: String, CaseIterable, Identifiable {
    case html
    case css
    case js
    case data
    case routes
    case dom
    case assets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .html: "HTML"
        case .css: "CSS"
        case .js: "JS"
        case .data: "Data"
        case .routes: "Routes"
        case .dom: "DOM"
        case .assets: "Assets"
        }
    }

    var fileName: String {
        switch self {
        case .html: "index.html"
        case .css: "style.css"
        case .js: "main.js"
        case .data: "data.json"
        case .routes: "routes/"
        case .dom: "DOM Outline"
        case .assets: "Package"
        }
    }

    var systemImage: String {
        switch self {
        case .html: "chevron.left.forwardslash.chevron.right"
        case .css: "paintbrush"
        case .js: "curlybraces"
        case .data: "tablecells"
        case .routes: "map"
        case .dom: "point.3.connected.trianglepath.dotted"
        case .assets: "shippingbox"
        }
    }

    var documentSurfacePane: DocumentSurfacePane {
        switch self {
        case .html: .html
        case .css: .css
        case .js: .js
        case .data: .data
        case .routes: .routes
        case .dom: .dom
        case .assets: .assets
        }
    }

    var codeEditorLanguage: String {
        switch self {
        case .html: "html"
        case .css: "css"
        case .js: "javascript"
        case .data: "json"
        case .routes, .dom, .assets: "text"
        }
    }

    var allowedPatchOperations: [String] {
        switch self {
        case .html:
            ["replaceDocument", "regenerate", "replaceHTML", "insertBlock", "insertChart", "setRoute", "removeRoute", "captureSnapshot", "restoreSnapshot"]
        case .css:
            ["replaceDocument", "regenerate", "replaceCSS", "updateStyleRule"]
        case .js:
            ["replaceDocument", "regenerate", "replaceJS"]
        case .data:
            ["replaceDocument", "regenerate", "replaceDataJSON", "setDataFeed", "insertChart"]
        case .routes:
            ["setRoute", "removeRoute", "replaceDocument", "regenerate", "restoreSnapshot"]
        case .dom:
            ["replaceDocument", "regenerate", "insertBlock", "insertChart", "setRoute", "removeRoute"]
        case .assets:
            ["replaceDocument", "regenerate", "addAsset", "removeAsset", "captureSnapshot", "restoreSnapshot"]
        }
    }

    func subtitle(
        for package: HTMLWorkspacePackage,
        domSnapshot: HTMLWorkspaceDOMSnapshot? = nil
    ) -> String {
        let resolvedDOMSnapshot = domSnapshot ?? HTMLWorkspaceDOMOutline.snapshot(for: package.indexHTML)
        return switch self {
        case .html: "DOM structure"
        case .css: "Presentation"
        case .js: "Local behavior"
        case .data: "Structured state"
        case .routes: "\(package.routes.count) routes"
        case .dom: "\(resolvedDOMSnapshot.nodeCount) \(resolvedDOMSnapshot.source.label) nodes"
        case .assets: "\(package.assets.count) assets, \(package.snapshots.count) snapshots"
        }
    }

    func metricText(
        for package: HTMLWorkspacePackage,
        domSnapshot: HTMLWorkspaceDOMSnapshot? = nil
    ) -> String {
        let resolvedDOMSnapshot = domSnapshot ?? HTMLWorkspaceDOMOutline.snapshot(for: package.indexHTML)
        return switch self {
        case .html: Self.counts(for: package.indexHTML)
        case .css: Self.counts(for: package.styleCSS)
        case .js: Self.counts(for: package.scriptJS)
        case .data: Self.counts(for: package.dataJSON)
        case .routes: "\(package.routes.count) routes"
        case .dom: "\(resolvedDOMSnapshot.nodeCount) \(resolvedDOMSnapshot.source.label) nodes"
        case .assets: "\(package.assets.count + package.snapshots.count) files"
        }
    }

    private static func counts(for source: String) -> String {
        agentTokenEstimateText(for: source)
    }

    static func agentTokenEstimateText(for source: String) -> String {
        let tokens = max(1, Int((Double(source.utf8.count) / 4.0).rounded(.up)))
        return "≈\(tokens.formatted()) agent tokens"
    }
}

enum HTMLWorkspacePythonDemoScaffold {
    static let scriptMarker = "epistemos-python-demo"

    static func apply(
        to package: HTMLWorkspacePackage,
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1_000)
    ) throws -> HTMLWorkspacePackage {
        var updated = package
        updated.manifest.sandboxPolicy.allowPythonRuntime = true
        if !updated.indexHTML.contains("data-python-output") {
            updated = try HTMLWorkspacePatchApplier.apply(
                .insertBlock(HTMLWorkspaceBlockInsertion(html: outputBlock, location: .beforeClosingBody)),
                to: updated
            )
        }
        updated = try addStyleRuleIfMissing(
            selector: ".python-demo",
            declarations: [
                "background": "var(--epistemos-workspace-card)",
                "border-radius": "14px",
                "display": "grid",
                "gap": "10px",
                "margin": "24px 0 0",
                "padding": "16px",
            ],
            to: updated
        )
        updated = try addStyleRuleIfMissing(
            selector: ".python-demo pre",
            declarations: [
                "background": "color-mix(in srgb, var(--epistemos-workspace-bg) 84%, var(--epistemos-workspace-accent) 16%)",
                "border-radius": "10px",
                "font-family": "ui-monospace, SFMono-Regular, Menlo, monospace",
                "margin": "0",
                "overflow": "auto",
                "padding": "12px",
            ],
            to: updated
        )
        if !updated.scriptJS.contains(scriptMarker) {
            updated = try HTMLWorkspacePatchApplier.apply(
                .replaceJS(appendingDemoScript(to: updated.scriptJS)),
                to: updated
            )
        }
        updated.manifest.updatedAt = updatedAt
        updated.manifest.contentHash = updated.currentContentHash
        return updated
    }

    private static let outputBlock = """
    <section class="python-demo" data-python-demo>
      <h2>Python Runtime</h2>
      <pre data-python-output>Python result will appear here.</pre>
    </section>
    """

    private static let demoScript = """
    // epistemos-python-demo
    (() => {
      const output = document.querySelector('[data-python-output]');
      const runtime = window.HTMLWorkspace && window.HTMLWorkspace.python;
      if (!output || !runtime) { return; }
      if (runtime.enabled !== true || runtime.available !== true) {
        const missing = runtime && runtime.missingResources && runtime.missingResources.length
          ? ' (' + runtime.missingResources.join(', ') + ')'
          : '';
        output.textContent = 'Python runtime: ' + (runtime && runtime.status ? runtime.status : 'unavailable') + missing;
        return;
      }
      output.textContent = 'Loading Python runtime...';
      const code = [
        'from statistics import mean',
        'values = [2, 3, 5, 8, 13]',
        'result = f"mean={mean(values):.2f}, max={max(values)}"',
        'result'
      ].join('\\n');
      runtime.run(code).then((result) => {
        output.textContent = 'Python ready: ' + String(result);
        window.HTMLWorkspace && window.HTMLWorkspace.app && window.HTMLWorkspace.app.record('python.demo.completed', {
          result: String(result)
        });
      }).catch((error) => {
        output.textContent = 'Python error: ' + (error && error.message ? error.message : String(error));
        console.error('HTML Workspace Python demo failed', error);
      });
    })();
    """

    private static func addStyleRuleIfMissing(
        selector: String,
        declarations: [String: String],
        to package: HTMLWorkspacePackage
    ) throws -> HTMLWorkspacePackage {
        guard !containsStyleSelector(selector, in: package.styleCSS) else { return package }
        return try HTMLWorkspacePatchApplier.apply(
            .updateStyleRule(HTMLWorkspaceStyleRulePatch(selector: selector, declarations: declarations)),
            to: package
        )
    }

    private static func containsStyleSelector(_ selector: String, in css: String) -> Bool {
        let pattern = #"(?m)^\s*\#(NSRegularExpression.escapedPattern(for: selector))\s*\{"#
        return css.range(of: pattern, options: .regularExpression) != nil
    }

    private static func appendingDemoScript(to script: String) -> String {
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return demoScript }
        return trimmed + "\n\n" + demoScript
    }
}

enum HTMLWorkspaceAppBridgeDemoScaffold {
    static let scriptMarker = "epistemos-app-bridge-demo"

    static func apply(
        to package: HTMLWorkspacePackage,
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1_000)
    ) throws -> HTMLWorkspacePackage {
        var updated = package
        updated.manifest.sandboxPolicy.allowAppBridge = true
        updated.manifest.sandboxPolicy.safeAPIVersion = max(1, updated.manifest.sandboxPolicy.safeAPIVersion)
        if !updated.indexHTML.contains("data-app-bridge-output") {
            updated = try HTMLWorkspacePatchApplier.apply(
                .insertBlock(HTMLWorkspaceBlockInsertion(html: outputBlock, location: .beforeClosingBody)),
                to: updated
            )
        }
        updated = try addStyleRuleIfMissing(
            selector: ".app-bridge-demo",
            declarations: [
                "background": "var(--epistemos-workspace-card)",
                "border-radius": "8px",
                "display": "grid",
                "gap": "10px",
                "margin": "24px 0 0",
                "padding": "16px",
            ],
            to: updated
        )
        updated = try addStyleRuleIfMissing(
            selector: ".app-bridge-demo button",
            declarations: [
                "appearance": "none",
                "background": "var(--epistemos-workspace-accent)",
                "border": "0",
                "border-radius": "8px",
                "color": "white",
                "cursor": "pointer",
                "font": "inherit",
                "justify-self": "start",
                "padding": "8px 12px",
            ],
            to: updated
        )
        updated = try addStyleRuleIfMissing(
            selector: ".app-bridge-demo output",
            declarations: [
                "background": "color-mix(in srgb, var(--epistemos-workspace-bg) 84%, var(--epistemos-workspace-accent) 16%)",
                "border-radius": "8px",
                "display": "block",
                "font-family": "ui-monospace, SFMono-Regular, Menlo, monospace",
                "padding": "12px",
            ],
            to: updated
        )
        if !updated.scriptJS.contains(scriptMarker) {
            updated = try HTMLWorkspacePatchApplier.apply(
                .replaceJS(appendingDemoScript(to: updated.scriptJS)),
                to: updated
            )
        }
        updated.manifest.updatedAt = updatedAt
        updated.manifest.contentHash = updated.currentContentHash
        return updated
    }

    private static let outputBlock = """
    <section class="app-bridge-demo" data-app-bridge-demo>
      <h2>App Bridge</h2>
      <button type="button" data-app-bridge-action>Ping App</button>
      <output data-app-bridge-output>Waiting for bridge...</output>
    </section>
    """

    private static let demoScript = """
    // epistemos-app-bridge-demo
    (() => {
      const root = document.querySelector('[data-app-bridge-demo]');
      const output = document.querySelector('[data-app-bridge-output]');
      const button = document.querySelector('[data-app-bridge-action]');
      const app = window.HTMLWorkspace && window.HTMLWorkspace.app;
      if (!root || !output || !app) { return; }
      const write = (message) => { output.textContent = message; };
      if (app.enabled !== true) {
        write('App bridge: disabled');
        return;
      }
      const probe = (label) => {
        const version = app.safeAPIVersion ? ' v' + app.safeAPIVersion : '';
        write('App bridge' + version + ': sending...');
        app.request('ping', label)
          .then((detail) => {
            const request = detail.requestId ? ' [' + detail.requestId + ']' : '';
            write((detail.message || 'App bridge response received') + request);
          })
          .catch((error) => {
            write('App bridge failed: ' + (error && error.message ? error.message : String(error)));
          });
        app.status();
        app.record('app.bridge.demo', { source: 'demo scaffold', probe: label });
      };
      button && button.addEventListener('click', () => probe('button probe'));
      probe('demo loaded');
    })();
    """

    private static func addStyleRuleIfMissing(
        selector: String,
        declarations: [String: String],
        to package: HTMLWorkspacePackage
    ) throws -> HTMLWorkspacePackage {
        guard !containsStyleSelector(selector, in: package.styleCSS) else { return package }
        return try HTMLWorkspacePatchApplier.apply(
            .updateStyleRule(HTMLWorkspaceStyleRulePatch(selector: selector, declarations: declarations)),
            to: package
        )
    }

    private static func containsStyleSelector(_ selector: String, in css: String) -> Bool {
        let pattern = #"(?m)^\s*\#(NSRegularExpression.escapedPattern(for: selector))\s*\{"#
        return css.range(of: pattern, options: .regularExpression) != nil
    }

    private static func appendingDemoScript(to script: String) -> String {
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return demoScript }
        return trimmed + "\n\n" + demoScript
    }
}

struct HTMLWorkspaceSiteFolderExportSummary: Equatable {
    let routeCount: Int
    let assetCount: Int
    let mirroredRouteAssets: Bool

    var statusText: String {
        var details: [String] = ["index"]
        if routeCount == 1 {
            details.append("1 route")
        } else if routeCount > 1 {
            details.append("\(routeCount) routes")
        }
        if assetCount == 1 {
            details.append(mirroredRouteAssets ? "1 route-relative asset mirror" : "1 asset")
        } else if assetCount > 1 {
            details.append(mirroredRouteAssets ? "\(assetCount) route-relative asset mirrors" : "\(assetCount) assets")
        }
        return "Site folder saved (\(details.joined(separator: ", ")))"
    }
}

// HW-EXPORT-1b (audit 2026-07-04): nonisolated so exportSiteFolder can run it off the main thread —
// it renders every route (N+1) + writes all files/assets to disk. All its work is nonisolated-safe
// (writeString/writeAssets are pure I/O; HTMLWorkspacePackage + render + validate are nonisolated).
nonisolated enum HTMLWorkspaceSiteFolderExporter {
    @discardableResult
    static func export(
        package: HTMLWorkspacePackage,
        theme: HTMLWorkspacePreviewTheme,
        to folderURL: URL
    ) throws -> HTMLWorkspaceSiteFolderExportSummary {
        try HTMLWorkspacePackage.validateRoutes(package.routes)
        try HTMLWorkspacePackage.validateAssets(package.assets)

        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )

        try writeString(
            HTMLWorkspacePreviewDocument.render(
                package: package,
                theme: theme,
                resourceMode: .packageLocal
            ),
            to: folderURL.appendingPathComponent(HTMLWorkspacePackageEntry.indexHTML)
        )
        try writeString(package.styleCSS, to: folderURL.appendingPathComponent(HTMLWorkspacePackageEntry.styleCSS))
        try writeString(package.scriptJS, to: folderURL.appendingPathComponent(HTMLWorkspacePackageEntry.scriptJS))
        try writeString(package.dataJSON, to: folderURL.appendingPathComponent(HTMLWorkspacePackageEntry.dataJSON))

        if !package.routes.isEmpty {
            let routesURL = folderURL.appendingPathComponent(HTMLWorkspacePackageEntry.routes, isDirectory: true)
            try fileManager.createDirectory(at: routesURL, withIntermediateDirectories: true)
            for routeName in package.routes.keys.sorted() {
                try writeString(
                    HTMLWorkspacePreviewDocument.render(
                        package: package,
                        routeName: routeName,
                        theme: theme,
                        resourceMode: .packageLocal
                    ),
                    to: routesURL.appendingPathComponent(routeName)
                )
            }
        }

        if !package.assets.isEmpty {
            let assetsURL = folderURL.appendingPathComponent(HTMLWorkspacePackageEntry.assets, isDirectory: true)
            try writeAssets(package.assets, to: assetsURL)
            if !package.routes.isEmpty {
                let routeAssetsURL = folderURL
                    .appendingPathComponent(HTMLWorkspacePackageEntry.routes, isDirectory: true)
                    .appendingPathComponent(HTMLWorkspacePackageEntry.assets, isDirectory: true)
                try writeAssets(package.assets, to: routeAssetsURL)
            }
        }

        return HTMLWorkspaceSiteFolderExportSummary(
            routeCount: package.routes.count,
            assetCount: package.assets.count,
            mirroredRouteAssets: !package.routes.isEmpty && !package.assets.isEmpty
        )
    }

    private static func writeString(_ value: String, to url: URL) throws {
        try Data(value.utf8).write(to: url, options: [.atomic])
    }

    private static func writeAssets(_ assets: [String: Data], to folderURL: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        for assetName in assets.keys.sorted() {
            guard let data = assets[assetName] else { continue }
            try data.write(
                to: folderURL.appendingPathComponent(assetName),
                options: [.atomic]
            )
        }
    }
}

struct HTMLWorkspaceToolbarIconButtonStyle: ButtonStyle {
    let theme: EpistemosTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(theme.resolved.accent.color)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minWidth: 34, minHeight: 30)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.resolved.accent.color.opacity(configuration.isPressed ? 0.22 : 0.11))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.resolved.accent.color.opacity(theme.isDark ? 0.26 : 0.20), lineWidth: 0.75)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

extension NSColor {
    var htmlWorkspaceCSSColor: String {
        htmlWorkspaceCSSColor(opacity: nil)
    }

    func htmlWorkspaceCSSColor(opacity overrideOpacity: CGFloat?) -> String {
        let color = usingColorSpace(.sRGB) ?? self
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        let alpha = overrideOpacity ?? color.alphaComponent
        if alpha >= 0.999 {
            return String(format: "#%02X%02X%02X", red, green, blue)
        }
        return String(format: "rgba(%d, %d, %d, %.3f)", red, green, blue, alpha)
    }
}
