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

nonisolated enum HTMLWorkspaceHTMLImporter {
    struct ImportedSources {
        var html: String
        var css: String
        var js: String
        var dataJSON: String
    }

    private static let generatedStyleIDs: Set<String> = [
        "epistemos-font-face",
        "epistemos-theme-guard",
        "epistemos-theme-host",
    ]
    private static let generatedScriptIDs: Set<String> = [
        "epistemos-workspace-runtime",
    ]

    static func importSources(from source: String) -> ImportedSources {
        let dataJSON = firstCapture(
            pattern: #"(?is)<script[^>]*id\s*=\s*["']workspace-data["'][^>]*>(.*?)</script>"#,
            in: source
        ).map(decodeScriptData) ?? ""
        let css = styleBodies(in: source).joined(separator: "\n\n")
        let js = scriptBodies(in: source).joined(separator: "\n\n")

        let rawBody = firstCapture(pattern: #"(?is)<body[^>]*>(.*?)</body>"#, in: source) ?? source
        let cleanedBody = rawBody
            .replacingOccurrences(
                of: #"(?is)<script[^>]*>.*?</script>"#,
                with: "",
                options: [.regularExpression]
            )
            .replacingOccurrences(
                of: #"(?is)<style[^>]*>.*?</style>"#,
                with: "",
                options: [.regularExpression]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ImportedSources(
            html: cleanedBody.isEmpty ? "<main></main>" : cleanedBody,
            css: css,
            js: js,
            dataJSON: dataJSON
        )
    }

    private static func captures(pattern: String, in source: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.matches(in: source, range: range).compactMap { match in
            guard let captureRange = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func firstCapture(pattern: String, in source: String) -> String? {
        captures(pattern: pattern, in: source).first
    }

    private static func styleBodies(in source: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: #"(?is)<style\b([^>]*)>(.*?)</style>"#) else {
            return []
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.matches(in: source, range: range).compactMap { match in
            guard let attributesRange = Range(match.range(at: 1), in: source),
                  let bodyRange = Range(match.range(at: 2), in: source) else { return nil }
            let attributes = String(source[attributesRange])
            if let styleID = capturedID(in: attributes)?.lowercased(), generatedStyleIDs.contains(styleID) {
                return nil
            }
            return String(source[bodyRange])
        }
    }

    private static func scriptBodies(in source: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: #"(?is)<script\b([^>]*)>(.*?)</script>"#) else {
            return []
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.matches(in: source, range: range).compactMap { match in
            guard let attributesRange = Range(match.range(at: 1), in: source),
                  let bodyRange = Range(match.range(at: 2), in: source) else { return nil }
            let attributes = String(source[attributesRange])
            if !shouldImportScript(type: capturedAttribute("type", in: attributes)) {
                return nil
            }
            if let scriptID = capturedID(in: attributes)?.lowercased(),
               generatedScriptIDs.contains(scriptID) || scriptID == "workspace-data" {
                return nil
            }
            let body = String(source[bodyRange])
            if body.contains("Object.defineProperty(window, 'HTMLWorkspace'") {
                return nil
            }
            return body
        }
    }

    private static func shouldImportScript(type rawType: String?) -> Bool {
        guard let rawType else { return true }
        let normalized = rawType
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard !normalized.isEmpty else { return true }
        return normalized == "module"
            || normalized == "text/javascript"
            || normalized == "application/javascript"
            || normalized == "text/ecmascript"
            || normalized == "application/ecmascript"
    }

    private static func capturedID(in attributes: String) -> String? {
        capturedAttribute("id", in: attributes)
    }

    private static func capturedAttribute(_ name: String, in attributes: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        guard let expression = try? NSRegularExpression(pattern: #"(?is)\b\#(escapedName)\s*=\s*["']([^"']+)["']"#) else {
            return nil
        }
        let range = NSRange(attributes.startIndex..<attributes.endIndex, in: attributes)
        guard let match = expression.firstMatch(in: attributes, range: range),
              let idRange = Range(match.range(at: 1), in: attributes) else {
            return nil
        }
        return String(attributes[idRange])
    }

    private static func decodeBasicHTMLEntities(_ source: String) -> String {
        source
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func decodeScriptData(_ source: String) -> String {
        decodeBasicHTMLEntities(source)
            .replacingOccurrences(of: #"<\/script"#, with: "</script", options: [.caseInsensitive])
            .replacingOccurrences(of: #"<\!--"#, with: "<!--")
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
        let lines = max(1, source.split(separator: "\n", omittingEmptySubsequences: false).count)
        return "\(lines) lines / \(source.count) chars"
    }
}

struct HTMLWorkspaceToolbarIconButtonStyle: ButtonStyle {
    let theme: EpistemosTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(theme.resolved.accent.color)
            .frame(width: 32, height: 30)
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
