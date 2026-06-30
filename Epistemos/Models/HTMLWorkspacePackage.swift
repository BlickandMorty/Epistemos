import CryptoKit
import Foundation

nonisolated public enum HTMLWorkspacePackageEntry {
    public static let manifest = "manifest.json"
    public static let indexHTML = "index.html"
    public static let styleCSS = "style.css"
    public static let scriptJS = "main.js"
    public static let legacyScriptJS = "script.js"
    public static let dataJSON = "data.json"
    public static let routes = "routes"
    public static let assets = "assets"
    public static let snapshots = "snapshots"
    public static let consoleErrors = "console-errors.json"
}

nonisolated public enum HTMLWorkspaceLocalResourceScheme {
    public static let scheme = "epistemos-html-workspace"
    public static let contentSecurityPolicySource = "\(scheme):"
}

nonisolated enum HTMLWorkspacePackageContentHasher {
    static func hash(
        indexHTML: String,
        styleCSS: String,
        scriptJS: String,
        dataJSON: String = "{}",
        routes: [String: String] = [:]
    ) -> String {
        var data = Data()
        data.append(Data(indexHTML.utf8))
        data.append(0)
        data.append(Data(styleCSS.utf8))
        data.append(0)
        data.append(Data(scriptJS.utf8))
        data.append(0)
        data.append(Data(dataJSON.utf8))
        data.append(0)
        for name in routes.keys.sorted() {
            data.append(Data(name.utf8))
            data.append(0)
            data.append(Data(routes[name, default: ""].utf8))
            data.append(0)
        }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated public enum HTMLWorkspacePackageLimits {
    public static let maxConsoleErrors = 48
    public static let maxSnapshots = 16
    public static let maxManifestBytes = 256 * 1024
    public static let maxIndexHTMLBytes = 2 * 1024 * 1024
    public static let maxStyleCSSBytes = 2 * 1024 * 1024
    public static let maxScriptJSBytes = 2 * 1024 * 1024
    public static let maxDataJSONBytes = 4 * 1024 * 1024
    public static let maxRouteCount = 64
    public static let maxRouteHTMLBytes = 2 * 1024 * 1024
    public static let maxRoutesTotalBytes = 32 * 1024 * 1024
    public static let maxAssetCount = 256
    public static let maxAssetBytes = 25 * 1024 * 1024
    public static let maxAssetsTotalBytes = 150 * 1024 * 1024
    public static let maxSnapshotBytes = 2 * 1024 * 1024
    public static let maxSnapshotsTotalBytes = 32 * 1024 * 1024
}

nonisolated public enum HTMLWorkspacePreviewTheme: String, Sendable, Hashable {
    case light
    case dark

    var colorSchemeCSS: String { rawValue }

    var guardCSS: String {
        switch self {
        case .light:
            """
            :root {
              color-scheme: light;
              --epistemos-workspace-bg: #f7f7f5;
              --epistemos-workspace-fg: #161616;
              --epistemos-workspace-muted: #676a70;
              --epistemos-workspace-card: #efefed;
              --epistemos-workspace-border: rgba(22, 22, 22, 0.14);
              --epistemos-workspace-accent: #2f6df6;
              --epistemos-workspace-title-font: "MatrixTypeDisplay-Regular", "MatrixTypeDisplay", -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
              --epistemos-workspace-heading-font: "ChonkyPixels", "MatrixTypeDisplay-Regular", "MatrixTypeDisplay", -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
              --epistemos-workspace-body-font: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
            }
            """
        case .dark:
            """
            :root {
              color-scheme: dark;
              --epistemos-workspace-bg: #111218;
              --epistemos-workspace-fg: #f4f4f1;
              --epistemos-workspace-muted: #a6a8b0;
              --epistemos-workspace-card: #1c1d25;
              --epistemos-workspace-border: rgba(244, 244, 241, 0.16);
              --epistemos-workspace-accent: #8aa7ff;
              --epistemos-workspace-title-font: "MatrixTypeDisplay-Regular", "MatrixTypeDisplay", -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
              --epistemos-workspace-heading-font: "ChonkyPixels", "MatrixTypeDisplay-Regular", "MatrixTypeDisplay", -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
              --epistemos-workspace-body-font: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
            }
            """
        }
    }

    static var defaultGuardCSS: String {
        """
        :root {
          color-scheme: light dark;
          --epistemos-workspace-bg: Canvas;
          --epistemos-workspace-fg: CanvasText;
          --epistemos-workspace-muted: color-mix(in srgb, CanvasText 64%, transparent);
          --epistemos-workspace-card: color-mix(in srgb, Canvas 94%, CanvasText 6%);
          --epistemos-workspace-border: color-mix(in srgb, CanvasText 14%, transparent);
          --epistemos-workspace-accent: LinkText;
          --epistemos-workspace-title-font: "MatrixTypeDisplay-Regular", "MatrixTypeDisplay", -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
          --epistemos-workspace-heading-font: "ChonkyPixels", "MatrixTypeDisplay-Regular", "MatrixTypeDisplay", -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
          --epistemos-workspace-body-font: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
        }
        """
    }

    static var hostCSS: String {
        """
        html[data-epistemos-theme],
        html[data-epistemos-theme] body {
          background: var(--epistemos-workspace-bg) !important;
          color: var(--epistemos-workspace-fg) !important;
        }

        html[data-epistemos-theme] body :is(main, section, article, aside, header, footer, div, p, li, td, th, blockquote, figcaption, small, span, strong, em) {
          color: inherit;
        }

        html[data-epistemos-theme="dark"] body :is(main, section, article, aside, header, footer, div, p, li, td, th, blockquote, figcaption, label, small, span, strong, em, b, i, code, pre, dd, dt, summary, caption, output, button) {
          color: var(--epistemos-workspace-fg) !important;
        }

        html[data-epistemos-theme="dark"] body :is(.muted, .subtitle, .subtle, .secondary, .meta, .caption, [class*="muted"], [class*="secondary"], [class*="subtle"], [class*="meta"], small, figcaption, caption, td:first-child, th:first-child) {
          color: color-mix(in srgb, var(--epistemos-workspace-fg) 84%, transparent) !important;
        }

        html[data-epistemos-theme] body :is(hr, .rule, .divider) {
          border-color: var(--epistemos-workspace-border);
          background-color: var(--epistemos-workspace-border);
        }

        html[data-epistemos-theme] body :is(a) {
          color: var(--epistemos-workspace-accent);
        }

        html[data-epistemos-theme="dark"] body :is(a, a:visited, a span, a small, a strong, a em) {
          color: var(--epistemos-workspace-accent) !important;
        }

        html[data-epistemos-theme="dark"] body ::placeholder {
          color: color-mix(in srgb, var(--epistemos-workspace-fg) 70%, transparent) !important;
        }

        html[data-epistemos-theme] body :is(h1, h2, .workspace-title, [data-display-title]) {
          font-family: var(--epistemos-workspace-title-font);
          font-weight: 400;
          font-synthesis: none;
          color: var(--epistemos-workspace-fg);
        }

        html[data-epistemos-theme] body :is(h3, h4, h5, h6) {
          color: var(--epistemos-workspace-fg);
        }

        html[data-epistemos-theme] .metric-card strong,
        html[data-epistemos-theme] [data-metrics] strong,
        html[data-epistemos-theme] .metric-value,
        html[data-epistemos-theme] [data-metric-value] {
          font-family: var(--epistemos-workspace-heading-font);
          font-weight: 400;
          font-synthesis: none;
          font-variant-numeric: tabular-nums;
        }

        html[data-epistemos-theme] :is(.metric-card, [data-metrics] article, .card, section[data-card]) {
          background: var(--epistemos-workspace-card);
          border-color: var(--epistemos-workspace-border);
        }
        """
    }
}

nonisolated private enum HTMLWorkspacePreviewFonts {
    private final class BundleProbe {}

    static let fontFaceCSS: String = {
        [
            fontFace(
                family: "MatrixTypeDisplay-Regular",
                fileName: "MatrixtypeDisplay-9MyE5",
                ext: "ttf",
                mimeType: "font/ttf",
                aliases: ["MatrixTypeDisplay"]
            ),
            fontFace(
                family: "ChonkyPixels",
                fileName: "ChonkyPixels",
                ext: "ttf",
                mimeType: "font/ttf"
            ),
        ].compactMap { $0 }.joined(separator: "\n\n")
    }()

    private static func fontFace(
        family: String,
        fileName: String,
        ext: String,
        mimeType: String,
        aliases: [String] = []
    ) -> String? {
        guard let dataURL = fontDataURL(fileName: fileName, ext: ext, mimeType: mimeType) else {
            return nil
        }
        let allFamilies = [family] + aliases
        return allFamilies.map { familyName in
            """
        @font-face {
          font-family: "\(familyName)";
          src: local("\(familyName)"), local("\(family)"), url("\(dataURL)") format("truetype");
          font-style: normal;
          font-weight: 400;
          font-synthesis: none;
          font-display: swap;
        }
        """
        }.joined(separator: "\n\n")
    }

    private static func fontDataURL(fileName: String, ext: String, mimeType: String) -> String? {
        guard let url = bundleFontURL(fileName: fileName, ext: ext),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    private static func bundleFontURL(fileName: String, ext: String) -> URL? {
        let bundles = [Bundle.main, Bundle(for: BundleProbe.self)] + Bundle.allBundles + Bundle.allFrameworks
        var visited = Set<String>()
        for bundle in bundles {
            let path = bundle.bundleURL.path
            guard visited.insert(path).inserted else { continue }
            if let url = bundle.url(forResource: fileName, withExtension: ext) {
                return url
            }
            if let url = bundle.url(
                forResource: fileName,
                withExtension: ext,
                subdirectory: "Fonts"
            ) {
                return url
            }
        }
        return nil
    }
}

nonisolated public struct HTMLWorkspaceSandboxPolicy: Codable, Sendable, Hashable {
    public var allowNetwork: Bool
    public var allowAppBridge: Bool
    public var safeAPIVersion: UInt32

    public init(
        allowNetwork: Bool,
        allowAppBridge: Bool,
        safeAPIVersion: UInt32
    ) {
        self.allowNetwork = allowNetwork
        self.allowAppBridge = allowAppBridge
        self.safeAPIVersion = safeAPIVersion
    }

    public static let offlineDefault = HTMLWorkspaceSandboxPolicy(
        allowNetwork: false,
        allowAppBridge: false,
        safeAPIVersion: 1
    )

    public var contentSecurityPolicy: String {
        let localResources = HTMLWorkspaceLocalResourceScheme.contentSecurityPolicySource
        if allowNetwork {
            return [
                "default-src 'none'",
                "img-src data: blob: https: \(localResources)",
                "style-src 'unsafe-inline' \(localResources)",
                "script-src 'unsafe-inline' \(localResources)",
                "font-src data: \(localResources)",
                "connect-src https: \(localResources)",
                "media-src data: blob: https: \(localResources)",
                "frame-src 'none'",
                "base-uri 'none'",
                "form-action 'none'",
            ].joined(separator: "; ")
        }
        return [
            "default-src 'none'",
            "img-src data: blob: \(localResources)",
            "style-src 'unsafe-inline' \(localResources)",
            "script-src 'unsafe-inline' \(localResources)",
            "font-src data: \(localResources)",
            "connect-src \(localResources)",
            "media-src data: blob: \(localResources)",
            "frame-src 'none'",
            "base-uri 'none'",
            "form-action 'none'",
        ].joined(separator: "; ")
    }
}

nonisolated public struct HTMLWorkspaceDataFeed: Codable, Sendable, Hashable {
    public enum Source: String, Codable, Sendable, Hashable {
        case vaultSearch = "vault_search"
    }

    public static let defaultLimit = 20
    public static let maxLimit = 50

    public var source: Source
    public var query: String
    public var limit: Int

    public init(
        source: Source = .vaultSearch,
        query: String,
        limit: Int = Self.defaultLimit
    ) {
        self.source = source
        self.query = query
        self.limit = limit
    }

    public static func vaultSearch(query: String, limit: Int = Self.defaultLimit) -> HTMLWorkspaceDataFeed {
        HTMLWorkspaceDataFeed(source: .vaultSearch, query: query, limit: limit)
    }

    public var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var effectiveLimit: Int {
        Self.clampedLimit(limit)
    }

    public var isRunnable: Bool {
        !normalizedQuery.isEmpty
    }

    public static func clampedLimit(_ limit: Int) -> Int {
        min(max(limit, 1), Self.maxLimit)
    }
}

nonisolated public enum HTMLWorkspaceDataFeedJSONEnvelope {
    public static let provenance = "VaultSyncService.searchFullAsync"

    public static func staleDataJSON(
        feed: HTMLWorkspaceDataFeed,
        error: String,
        refreshedAtMS: Int64 = 0
    ) -> String {
        let payload: [String: Any] = [
            "results": [[String: Any]](),
            "_epistemos": [
                "source": feed.source.rawValue,
                "query": feed.normalizedQuery,
                "limit": feed.effectiveLimit,
                "result_count": 0,
                "refreshed_at_ms": refreshedAtMS,
                "provenance": provenance,
                "stale": true,
                "status": "stale",
                "error": error,
            ] as [String: Any],
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"results":[],"_epistemos":{"source":"vault_search","query":"","limit":0,"result_count":0,"refreshed_at_ms":0,"provenance":"VaultSyncService.searchFullAsync","stale":true,"status":"stale","error":"data feed encoding failed"}}"#
        }
        return json
    }
}

nonisolated public struct HTMLWorkspaceManifest: Codable, Sendable, Hashable {
    public static let currentSchemaVersion: UInt32 = 1

    public var id: String
    public var schemaVersion: UInt32
    public var createdAt: Int64
    public var updatedAt: Int64
    public var title: String
    public var contentHash: String
    public var sandboxPolicy: HTMLWorkspaceSandboxPolicy
    public var dataFeed: HTMLWorkspaceDataFeed?
    public var generationProvenance: HTMLWorkspaceGenerationProvenance?

    public init(
        id: String,
        schemaVersion: UInt32,
        createdAt: Int64,
        updatedAt: Int64,
        title: String,
        contentHash: String,
        sandboxPolicy: HTMLWorkspaceSandboxPolicy,
        dataFeed: HTMLWorkspaceDataFeed? = nil,
        generationProvenance: HTMLWorkspaceGenerationProvenance? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.contentHash = contentHash
        self.sandboxPolicy = sandboxPolicy
        self.dataFeed = dataFeed
        self.generationProvenance = generationProvenance
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion = "schema_version"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case title
        case contentHash = "content_hash"
        case sandboxPolicy = "sandbox_policy"
        case dataFeed = "data_feed"
        case generationProvenance = "generation_provenance"
    }
}

nonisolated public struct HTMLWorkspacePackage: Sendable, Hashable {
    public var manifest: HTMLWorkspaceManifest
    public var indexHTML: String
    public var styleCSS: String
    public var scriptJS: String
    public var dataJSON: String
    public var routes: [String: String]
    public var assets: [String: Data]
    public var snapshots: [String: Data]
    public var consoleErrors: [HTMLWorkspaceConsoleError]

    public init(
        manifest: HTMLWorkspaceManifest,
        indexHTML: String,
        styleCSS: String,
        scriptJS: String,
        dataJSON: String = "{}",
        routes: [String: String] = [:],
        assets: [String: Data] = [:],
        snapshots: [String: Data] = [:],
        consoleErrors: [HTMLWorkspaceConsoleError] = []
    ) {
        self.manifest = manifest
        self.indexHTML = indexHTML
        self.styleCSS = styleCSS
        self.scriptJS = scriptJS
        self.dataJSON = dataJSON
        self.routes = routes
        self.assets = assets
        self.snapshots = snapshots
        self.consoleErrors = consoleErrors
    }

    public var isStarterTemplateContent: Bool {
        let starter = Self.defaultPackage()
        return indexHTML == starter.indexHTML
            && styleCSS == starter.styleCSS
            && scriptJS == starter.scriptJS
            && dataJSON == starter.dataJSON
            && routes.isEmpty
    }

    public static func defaultPackage(title: String = "Untitled HTML Workspace") -> HTMLWorkspacePackage {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let manifest = HTMLWorkspaceManifest(
            id: UUID().uuidString,
            schemaVersion: HTMLWorkspaceManifest.currentSchemaVersion,
            createdAt: now,
            updatedAt: now,
            title: title,
            contentHash: "",
            sandboxPolicy: .offlineDefault
        )
        return HTMLWorkspacePackage(
            manifest: manifest,
            indexHTML: """
            <main class="workspace">
              <section class="hero" data-dom-root>
                <p class="eyebrow">HTML Workspace</p>
                <h1 class="workspace-title" data-display-title>Untitled Workspace</h1>
                <p class="lede">Shape local data into live DOM, charts, and interactive components.</p>
                <div class="metric-grid" data-metrics></div>
              </section>
            </main>
            """,
            styleCSS: """
            :root {
              color-scheme: light dark;
              font-family: var(--epistemos-workspace-body-font);
            }

            body {
              margin: 0;
              min-height: 100vh;
              background: var(--epistemos-workspace-bg);
              color: var(--epistemos-workspace-fg);
            }

            .workspace {
              min-height: 100vh;
              display: grid;
              place-items: center;
              padding: 48px;
              box-sizing: border-box;
            }

            .hero {
              width: min(720px, 100%);
            }

            h1 {
              margin: 10px 0 0;
              font-family: var(--epistemos-workspace-title-font);
              font-weight: 400;
              font-synthesis: none;
              font-size: 46px;
              line-height: 1;
              letter-spacing: 0;
            }

            h2 {
              font-family: var(--epistemos-workspace-title-font);
              font-weight: 400;
              font-synthesis: none;
              letter-spacing: 0;
            }

            @media (max-width: 640px) {
              h1 {
                font-size: 32px;
              }
            }

            .lede {
              max-width: 56ch;
              line-height: 1.55;
              color: var(--epistemos-workspace-muted);
            }

            .metric-grid {
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
              gap: 10px;
              margin-top: 24px;
            }

            .metric-card {
              padding: 14px;
              border: 1px solid var(--epistemos-workspace-border);
              border-radius: 8px;
              background: var(--epistemos-workspace-card);
            }

            .metric-card strong {
              display: block;
              margin-top: 6px;
              font-family: var(--epistemos-workspace-heading-font);
              font-weight: 400;
              font-synthesis: none;
              font-variant-numeric: tabular-nums;
              font-size: 24px;
              line-height: 0.95;
            }

            .eyebrow {
              text-transform: uppercase;
              letter-spacing: 0.08em;
              font-size: 12px;
              color: var(--epistemos-workspace-muted);
            }
            """,
            scriptJS: """
            const metrics = HTMLWorkspace.data.metrics || [];
            const grid = HTMLWorkspace.q('[data-metrics]');
            if (grid) {
              metrics.forEach((metric) => {
                grid.append(HTMLWorkspace.el('article', { class: 'metric-card' }, [
                  HTMLWorkspace.el('span', {}, metric.label),
                  HTMLWorkspace.el('strong', { class: 'metric-value', 'data-metric-value': '' }, String(metric.value))
                ]));
              });
            }
            document.documentElement.dataset.htmlWorkspace = 'ready';
            """,
            dataJSON: """
            {
              "metrics": [
                { "label": "Nodes", "value": 128 },
                { "label": "Signals", "value": 42 },
                { "label": "Views", "value": 7 }
              ]
            }
            """
        )
    }
}

nonisolated public enum HTMLWorkspacePackageError: Error, CustomStringConvertible, LocalizedError {
    case missingManifest
    case missingIndexHTML
    case malformedManifest(underlying: Error)
    case manifestSchemaTooNew(version: UInt32)
    case wrongFileWrapperShape
    case malformedTextFile(name: String)
    case malformedConsoleErrors(underlying: Error)
    case invalidPackagePath(name: String)
    case invalidStyleRule(reason: String)
    case packageLimitExceeded(reason: String)

    public var description: String {
        switch self {
        case .missingManifest:
            return "HTMLWorkspacePackage: missing required manifest.json"
        case .missingIndexHTML:
            return "HTMLWorkspacePackage: missing required index.html"
        case .malformedManifest(let underlying):
            return "HTMLWorkspacePackage: malformed manifest.json - \(underlying)"
        case .manifestSchemaTooNew(let version):
            return "HTMLWorkspacePackage: manifest.json schema_version \(version) is newer than this build understands"
        case .wrongFileWrapperShape:
            return "HTMLWorkspacePackage: file wrapper is not a directory wrapper"
        case .malformedTextFile(let name):
            return "HTMLWorkspacePackage: \(name) is not valid UTF-8"
        case .malformedConsoleErrors(let underlying):
            return "HTMLWorkspacePackage: malformed console-errors.json - \(underlying)"
        case .invalidPackagePath(let name):
            return "HTMLWorkspacePackage: invalid package path \(name)"
        case .invalidStyleRule(let reason):
            return "HTMLWorkspacePackage: invalid style rule - \(reason)"
        case .packageLimitExceeded(let reason):
            return "HTMLWorkspacePackage: package limit exceeded - \(reason)"
        }
    }

    public var errorDescription: String? {
        description
    }
}

extension HTMLWorkspacePackage {
    nonisolated public func makeFileWrapper(jsonEncoder: JSONEncoder = .epdocCanonical) throws -> FileWrapper {
        var topLevel: [String: FileWrapper] = [:]
        let manifestData = try jsonEncoder.encode(manifest)
        let indexHTMLData = Data(indexHTML.utf8)
        let styleCSSData = Data(styleCSS.utf8)
        let scriptJSData = Data(scriptJS.utf8)
        let dataJSONData = Data(dataJSON.utf8)
        let routeFiles = routes.mapValues { Data($0.utf8) }

        try Self.validateDataSize(
            manifestData,
            maxBytes: HTMLWorkspacePackageLimits.maxManifestBytes,
            name: HTMLWorkspacePackageEntry.manifest
        )
        try Self.validateTextPayloads(
            indexHTMLData: indexHTMLData,
            styleCSSData: styleCSSData,
            scriptJSData: scriptJSData,
            dataJSONData: dataJSONData
        )
        try Self.validateRouteFiles(routeFiles)
        try Self.validateAssets(assets)
        try Self.validateSnapshots(snapshots)

        topLevel[HTMLWorkspacePackageEntry.manifest] = FileWrapper(
            regularFileWithContents: manifestData
        )
        topLevel[HTMLWorkspacePackageEntry.indexHTML] = FileWrapper(
            regularFileWithContents: indexHTMLData
        )
        topLevel[HTMLWorkspacePackageEntry.styleCSS] = FileWrapper(
            regularFileWithContents: styleCSSData
        )
        topLevel[HTMLWorkspacePackageEntry.scriptJS] = FileWrapper(
            regularFileWithContents: scriptJSData
        )
        topLevel[HTMLWorkspacePackageEntry.dataJSON] = FileWrapper(
            regularFileWithContents: dataJSONData
        )

        if !routes.isEmpty {
            topLevel[HTMLWorkspacePackageEntry.routes] = FileWrapper(
                directoryWithFileWrappers: try Self.fileWrappers(
                    from: routeFiles,
                    folderName: HTMLWorkspacePackageEntry.routes,
                    maxCount: HTMLWorkspacePackageLimits.maxRouteCount,
                    maxFileBytes: HTMLWorkspacePackageLimits.maxRouteHTMLBytes,
                    maxTotalBytes: HTMLWorkspacePackageLimits.maxRoutesTotalBytes
                )
            )
        }
        if !assets.isEmpty {
            topLevel[HTMLWorkspacePackageEntry.assets] = FileWrapper(
                directoryWithFileWrappers: try Self.fileWrappers(
                    from: assets,
                    folderName: HTMLWorkspacePackageEntry.assets,
                    maxCount: HTMLWorkspacePackageLimits.maxAssetCount,
                    maxFileBytes: HTMLWorkspacePackageLimits.maxAssetBytes,
                    maxTotalBytes: HTMLWorkspacePackageLimits.maxAssetsTotalBytes
                )
            )
        }
        if !snapshots.isEmpty {
            topLevel[HTMLWorkspacePackageEntry.snapshots] = FileWrapper(
                directoryWithFileWrappers: try Self.fileWrappers(
                    from: snapshots,
                    folderName: HTMLWorkspacePackageEntry.snapshots,
                    maxCount: HTMLWorkspacePackageLimits.maxSnapshots,
                    maxFileBytes: HTMLWorkspacePackageLimits.maxSnapshotBytes,
                    maxTotalBytes: HTMLWorkspacePackageLimits.maxSnapshotsTotalBytes
                )
            )
        }
        if !consoleErrors.isEmpty {
            topLevel[HTMLWorkspacePackageEntry.consoleErrors] = FileWrapper(
                regularFileWithContents: try jsonEncoder.encode(consoleErrors)
            )
        }

        return FileWrapper(directoryWithFileWrappers: topLevel)
    }

    nonisolated public init(
        fileWrapper: FileWrapper,
        jsonDecoder: JSONDecoder = .epdocCanonical
    ) throws {
        guard fileWrapper.isDirectory, let children = fileWrapper.fileWrappers else {
            throw HTMLWorkspacePackageError.wrongFileWrapperShape
        }
        guard let manifestWrapper = children[HTMLWorkspacePackageEntry.manifest],
              let manifestData = manifestWrapper.regularFileContents else {
            throw HTMLWorkspacePackageError.missingManifest
        }
        try Self.validateDataSize(
            manifestData,
            maxBytes: HTMLWorkspacePackageLimits.maxManifestBytes,
            name: HTMLWorkspacePackageEntry.manifest
        )

        let manifest: HTMLWorkspaceManifest
        do {
            manifest = try jsonDecoder.decode(HTMLWorkspaceManifest.self, from: manifestData)
        } catch {
            throw HTMLWorkspacePackageError.malformedManifest(underlying: error)
        }
        if manifest.schemaVersion > HTMLWorkspaceManifest.currentSchemaVersion {
            throw HTMLWorkspacePackageError.manifestSchemaTooNew(version: manifest.schemaVersion)
        }

        guard let indexWrapper = children[HTMLWorkspacePackageEntry.indexHTML],
              let indexData = indexWrapper.regularFileContents else {
            throw HTMLWorkspacePackageError.missingIndexHTML
        }

        self.init(
            manifest: manifest,
            indexHTML: try Self.string(
                from: indexData,
                name: HTMLWorkspacePackageEntry.indexHTML,
                maxBytes: HTMLWorkspacePackageLimits.maxIndexHTMLBytes
            ),
            styleCSS: try Self.optionalString(
                from: children[HTMLWorkspacePackageEntry.styleCSS],
                name: HTMLWorkspacePackageEntry.styleCSS,
                maxBytes: HTMLWorkspacePackageLimits.maxStyleCSSBytes
            ),
            scriptJS: try Self.scriptString(from: children),
            dataJSON: try Self.optionalString(
                from: children[HTMLWorkspacePackageEntry.dataJSON],
                name: HTMLWorkspacePackageEntry.dataJSON,
                maxBytes: HTMLWorkspacePackageLimits.maxDataJSONBytes
            ).nonEmptyJSONFallback,
            routes: try Self.readTextChildren(
                from: children[HTMLWorkspacePackageEntry.routes],
                folderName: HTMLWorkspacePackageEntry.routes,
                maxCount: HTMLWorkspacePackageLimits.maxRouteCount,
                maxFileBytes: HTMLWorkspacePackageLimits.maxRouteHTMLBytes,
                maxTotalBytes: HTMLWorkspacePackageLimits.maxRoutesTotalBytes
            ),
            assets: try Self.readChildren(
                from: children[HTMLWorkspacePackageEntry.assets],
                folderName: HTMLWorkspacePackageEntry.assets,
                maxCount: HTMLWorkspacePackageLimits.maxAssetCount,
                maxFileBytes: HTMLWorkspacePackageLimits.maxAssetBytes,
                maxTotalBytes: HTMLWorkspacePackageLimits.maxAssetsTotalBytes
            ),
            snapshots: try Self.readChildren(
                from: children[HTMLWorkspacePackageEntry.snapshots],
                folderName: HTMLWorkspacePackageEntry.snapshots,
                maxCount: HTMLWorkspacePackageLimits.maxSnapshots,
                maxFileBytes: HTMLWorkspacePackageLimits.maxSnapshotBytes,
                maxTotalBytes: HTMLWorkspacePackageLimits.maxSnapshotsTotalBytes
            ),
            consoleErrors: try Self.readConsoleErrors(from: children[HTMLWorkspacePackageEntry.consoleErrors], jsonDecoder: jsonDecoder)
        )
    }

    nonisolated private static func fileWrappers(
        from files: [String: Data],
        folderName: String,
        maxCount: Int,
        maxFileBytes: Int,
        maxTotalBytes: Int
    ) throws -> [String: FileWrapper] {
        try validateFileCollection(
            files,
            folderName: folderName,
            maxCount: maxCount,
            maxFileBytes: maxFileBytes,
            maxTotalBytes: maxTotalBytes
        )
        var wrappers: [String: FileWrapper] = [:]
        for (name, data) in files {
            wrappers[name] = FileWrapper(regularFileWithContents: data)
        }
        return wrappers
    }

    nonisolated private static func readChildren(
        from wrapper: FileWrapper?,
        folderName: String,
        maxCount: Int,
        maxFileBytes: Int,
        maxTotalBytes: Int
    ) throws -> [String: Data] {
        guard let wrapper, wrapper.isDirectory, let children = wrapper.fileWrappers else { return [:] }
        guard children.count <= maxCount else {
            throw HTMLWorkspacePackageError.packageLimitExceeded(reason: "\(folderName) count \(children.count) exceeds \(maxCount)")
        }
        var result: [String: Data] = [:]
        var totalBytes = 0
        for (name, child) in children {
            try validatePackageFileName(name)
            guard child.isRegularFile, let data = child.regularFileContents else {
                throw HTMLWorkspacePackageError.invalidPackagePath(name: "\(folderName)/\(name)")
            }
            try validateDataSize(data, maxBytes: maxFileBytes, name: "\(folderName)/\(name)")
            totalBytes += data.count
            guard totalBytes <= maxTotalBytes else {
                throw HTMLWorkspacePackageError.packageLimitExceeded(reason: "\(folderName) total \(totalBytes) bytes exceeds \(maxTotalBytes)")
            }
            result[name] = data
        }
        return result
    }

    nonisolated private static func readTextChildren(
        from wrapper: FileWrapper?,
        folderName: String,
        maxCount: Int,
        maxFileBytes: Int,
        maxTotalBytes: Int
    ) throws -> [String: String] {
        let files = try readChildren(
            from: wrapper,
            folderName: folderName,
            maxCount: maxCount,
            maxFileBytes: maxFileBytes,
            maxTotalBytes: maxTotalBytes
        )
        var result: [String: String] = [:]
        for (name, data) in files {
            guard let value = String(data: data, encoding: .utf8) else {
                throw HTMLWorkspacePackageError.malformedTextFile(name: "\(folderName)/\(name)")
            }
            result[name] = value
        }
        return result
    }

    nonisolated private static func readConsoleErrors(
        from wrapper: FileWrapper?,
        jsonDecoder: JSONDecoder
    ) throws -> [HTMLWorkspaceConsoleError] {
        guard let data = wrapper?.regularFileContents else { return [] }
        do {
            let decoded = try jsonDecoder.decode([HTMLWorkspaceConsoleError].self, from: data)
            return Array(decoded.suffix(HTMLWorkspacePackageLimits.maxConsoleErrors))
        } catch {
            throw HTMLWorkspacePackageError.malformedConsoleErrors(underlying: error)
        }
    }

    nonisolated private static func scriptString(from children: [String: FileWrapper]) throws -> String {
        if let wrapper = children[HTMLWorkspacePackageEntry.scriptJS] {
            return try optionalString(
                from: wrapper,
                name: HTMLWorkspacePackageEntry.scriptJS,
                maxBytes: HTMLWorkspacePackageLimits.maxScriptJSBytes
            )
        }
        return try optionalString(
            from: children[HTMLWorkspacePackageEntry.legacyScriptJS],
            name: HTMLWorkspacePackageEntry.legacyScriptJS,
            maxBytes: HTMLWorkspacePackageLimits.maxScriptJSBytes
        )
    }

    nonisolated private static func optionalString(
        from wrapper: FileWrapper?,
        name: String,
        maxBytes: Int
    ) throws -> String {
        guard let data = wrapper?.regularFileContents else { return "" }
        return try string(from: data, name: name, maxBytes: maxBytes)
    }

    nonisolated private static func string(from data: Data, name: String, maxBytes: Int) throws -> String {
        try validateDataSize(data, maxBytes: maxBytes, name: name)
        guard let value = String(data: data, encoding: .utf8) else {
            throw HTMLWorkspacePackageError.malformedTextFile(name: name)
        }
        return value
    }

    nonisolated static func validateAssets(_ files: [String: Data]) throws {
        try validateFileCollection(
            files,
            folderName: HTMLWorkspacePackageEntry.assets,
            maxCount: HTMLWorkspacePackageLimits.maxAssetCount,
            maxFileBytes: HTMLWorkspacePackageLimits.maxAssetBytes,
            maxTotalBytes: HTMLWorkspacePackageLimits.maxAssetsTotalBytes
        )
    }

    nonisolated static func validateRoutes(_ routes: [String: String]) throws {
        try validateRouteFiles(routes.mapValues { Data($0.utf8) })
    }

    nonisolated private static func validateRouteFiles(_ files: [String: Data]) throws {
        try validateFileCollection(
            files,
            folderName: HTMLWorkspacePackageEntry.routes,
            maxCount: HTMLWorkspacePackageLimits.maxRouteCount,
            maxFileBytes: HTMLWorkspacePackageLimits.maxRouteHTMLBytes,
            maxTotalBytes: HTMLWorkspacePackageLimits.maxRoutesTotalBytes
        )
    }

    nonisolated static func validateSnapshots(_ files: [String: Data]) throws {
        try validateFileCollection(
            files,
            folderName: HTMLWorkspacePackageEntry.snapshots,
            maxCount: HTMLWorkspacePackageLimits.maxSnapshots,
            maxFileBytes: HTMLWorkspacePackageLimits.maxSnapshotBytes,
            maxTotalBytes: HTMLWorkspacePackageLimits.maxSnapshotsTotalBytes
        )
    }

    nonisolated private static func validateTextPayloads(
        indexHTMLData: Data,
        styleCSSData: Data,
        scriptJSData: Data,
        dataJSONData: Data
    ) throws {
        try validateDataSize(indexHTMLData, maxBytes: HTMLWorkspacePackageLimits.maxIndexHTMLBytes, name: HTMLWorkspacePackageEntry.indexHTML)
        try validateDataSize(styleCSSData, maxBytes: HTMLWorkspacePackageLimits.maxStyleCSSBytes, name: HTMLWorkspacePackageEntry.styleCSS)
        try validateDataSize(scriptJSData, maxBytes: HTMLWorkspacePackageLimits.maxScriptJSBytes, name: HTMLWorkspacePackageEntry.scriptJS)
        try validateDataSize(dataJSONData, maxBytes: HTMLWorkspacePackageLimits.maxDataJSONBytes, name: HTMLWorkspacePackageEntry.dataJSON)
    }

    nonisolated private static func validateFileCollection(
        _ files: [String: Data],
        folderName: String,
        maxCount: Int,
        maxFileBytes: Int,
        maxTotalBytes: Int
    ) throws {
        guard files.count <= maxCount else {
            throw HTMLWorkspacePackageError.packageLimitExceeded(reason: "\(folderName) count \(files.count) exceeds \(maxCount)")
        }
        var totalBytes = 0
        for (name, data) in files {
            try validatePackageFileName(name)
            try validateDataSize(data, maxBytes: maxFileBytes, name: "\(folderName)/\(name)")
            totalBytes += data.count
            guard totalBytes <= maxTotalBytes else {
                throw HTMLWorkspacePackageError.packageLimitExceeded(reason: "\(folderName) total \(totalBytes) bytes exceeds \(maxTotalBytes)")
            }
        }
    }

    nonisolated private static func validateDataSize(_ data: Data, maxBytes: Int, name: String) throws {
        guard data.count <= maxBytes else {
            throw HTMLWorkspacePackageError.packageLimitExceeded(reason: "\(name) is \(data.count) bytes, max \(maxBytes)")
        }
    }

    nonisolated public static func validatePackageFileName(_ name: String) throws {
        guard !name.isEmpty,
              name != ".",
              name != "..",
              !name.hasPrefix("."),
              !name.contains("/"),
              !name.contains("\\"),
              !name.contains("\0"),
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw HTMLWorkspacePackageError.invalidPackagePath(name: name)
        }
    }
}

nonisolated public enum HTMLWorkspacePreviewDocument {
    public static func render(
        package: HTMLWorkspacePackage,
        routeName: String? = nil,
        theme: HTMLWorkspacePreviewTheme? = nil,
        themeGuardCSSOverride: String? = nil,
        resourceMode: HTMLWorkspacePreviewResourceMode = .packageLocal
    ) -> String {
        let package = switch resourceMode {
        case .packageLocal:
            package
        case .inlinePackageAssets:
            HTMLWorkspacePackageResources.packageWithInlineAssets(package)
        }
        let csp = package.manifest.sandboxPolicy.contentSecurityPolicy
        let themeAttribute = theme.map { #" data-epistemos-theme="\#($0.rawValue)""# } ?? ""
        let themeCSS = themeGuardCSSOverride ?? theme?.guardCSS ?? HTMLWorkspacePreviewTheme.defaultGuardCSS
        let routeHTML = routeName.flatMap { package.routes[$0] }
        let bodyHTML = routeHTML ?? package.indexHTML
        return """
        <!doctype html>
        <html\(themeAttribute)>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta http-equiv="Content-Security-Policy" content="\(escapeAttribute(csp))">
          <style id="epistemos-font-face">
        \(HTMLWorkspacePreviewFonts.fontFaceCSS)
          </style>
          <style id="epistemos-theme-guard">
        \(themeCSS)
          </style>
          <style>\(package.styleCSS)</style>
          <style id="epistemos-theme-host">
        \(HTMLWorkspacePreviewTheme.hostCSS)
          </style>
        </head>
        <body>
        \(bodyHTML)
          <script type="application/json" id="workspace-data">\(escapeScriptData(package.dataJSON))</script>
          <script id="epistemos-workspace-runtime">
        \(localDOMHelperJavaScript)
          </script>
          <script>\(package.scriptJS)</script>
        </body>
        </html>
        """
    }

    private static func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeScriptData(_ value: String) -> String {
        value
            .replacingOccurrences(of: "</script", with: "<\\/script", options: [.caseInsensitive])
    }

    private static let localDOMHelperJavaScript = """
    (() => {
      const dataNode = document.getElementById('workspace-data');
      const parseWorkspaceData = (raw) => {
        try {
          return JSON.parse(raw || '{}');
        } catch (error) {
          console.error('HTMLWorkspace data.json parse failed', error);
          return { error: 'Invalid data.json' };
        }
      };
      const state = {
        data: parseWorkspaceData(dataNode?.textContent || '{}')
      };
      const replaceWorkspaceData = (nextData, rawJSON = null, emitEvent = true) => {
        state.data = nextData;
        if (dataNode) {
          dataNode.textContent = rawJSON === null ? JSON.stringify(nextData) : String(rawJSON);
        }
        if (emitEvent) {
          try {
            window.dispatchEvent(new CustomEvent('htmlworkspace:datachange', { detail: nextData }));
          } catch (error) {
            console.warn('HTMLWorkspace datachange event failed', error);
          }
        }
        return true;
      };

      Object.defineProperty(window, '__epistemosReplaceWorkspaceData', {
        value(nextData, rawJSON = null) {
          return replaceWorkspaceData(nextData, rawJSON);
        },
        writable: false,
        configurable: false,
        enumerable: false
      });

      replaceWorkspaceData(state.data, dataNode?.textContent || '{}', false);

      const toArray = (children) => Array.isArray(children) ? children : [children];
      const api = {
        get data() {
          return state.data;
        },
        q(selector, scope = document) {
          return scope.querySelector(selector);
        },
        qa(selector, scope = document) {
          return Array.from(scope.querySelectorAll(selector));
        },
        el(tagName, attributes = {}, children = []) {
          const node = document.createElement(tagName);
          Object.entries(attributes || {}).forEach(([key, value]) => {
            if (value === false || value === null || value === undefined) { return; }
            if (key === 'class') {
              node.className = String(value);
            } else if (key === 'text') {
              node.textContent = String(value);
            } else {
              node.setAttribute(key, value === true ? '' : String(value));
            }
          });
          toArray(children).forEach((child) => {
            if (child === null || child === undefined) { return; }
            node.append(child instanceof Node ? child : document.createTextNode(String(child)));
          });
          return node;
        },
        mount(target, node) {
          const host = typeof target === 'string' ? document.querySelector(target) : target;
          if (!host || !node) { return null; }
          host.replaceChildren(node);
          return host;
        }
      };

      Object.defineProperty(window, 'HTMLWorkspace', {
        value: Object.freeze(api),
        writable: false,
        configurable: false,
        enumerable: false
      });
    })();
    """
}

nonisolated public struct HTMLWorkspaceDocumentReplacement: Sendable, Hashable {
    public var title: String?
    public var html: String
    public var css: String
    public var js: String
    public var dataJSON: String
    public var provenanceOperation: HTMLWorkspaceGenerationProvenance.Operation

    public init(
        title: String? = nil,
        html: String,
        css: String,
        js: String,
        dataJSON: String,
        provenanceOperation: HTMLWorkspaceGenerationProvenance.Operation = .replaceDocument
    ) {
        self.title = title
        self.html = html
        self.css = css
        self.js = js
        self.dataJSON = dataJSON
        self.provenanceOperation = provenanceOperation
    }
}

nonisolated public enum HTMLWorkspacePatchOperation: Sendable, Hashable {
    case replaceDocument(HTMLWorkspaceDocumentReplacement)
    case replaceHTML(String)
    case replaceCSS(String)
    case replaceJS(String)
    case replaceDataJSON(String)
    case setDataFeed(HTMLWorkspaceDataFeed?)
    case insertBlock(HTMLWorkspaceBlockInsertion)
    case insertChart(HTMLWorkspaceChartSpec)
    case updateStyleRule(HTMLWorkspaceStyleRulePatch)
    case setRoute(name: String, html: String)
    case removeRoute(name: String)
    case addAsset(HTMLWorkspaceAsset)
    case removeAsset(name: String)
    case captureSnapshot(name: String)
    case recordConsoleError(HTMLWorkspaceConsoleError)
}

nonisolated public struct HTMLWorkspaceBlockInsertion: Sendable, Hashable {
    public enum Location: Sendable, Hashable {
        case append
        case beforeClosingBody
    }

    public var html: String
    public var location: Location

    public init(html: String, location: Location = .append) {
        self.html = html
        self.location = location
    }
}

nonisolated public struct HTMLWorkspaceChartDatum: Codable, Sendable, Hashable {
    public var label: String
    public var value: Double

    public init(label: String, value: Double) {
        self.label = label
        self.value = value
    }
}

nonisolated public struct HTMLWorkspaceChartSpec: Codable, Sendable, Hashable {
    public var id: String
    public var title: String
    public var values: [HTMLWorkspaceChartDatum]

    public init(id: String, title: String, values: [HTMLWorkspaceChartDatum]) {
        self.id = id
        self.title = title
        self.values = values
    }
}

nonisolated public struct HTMLWorkspaceStyleRulePatch: Sendable, Hashable {
    public var selector: String
    public var declarations: [String: String]

    public init(selector: String, declarations: [String: String]) {
        self.selector = selector
        self.declarations = declarations
    }
}

nonisolated public struct HTMLWorkspaceAsset: Sendable, Hashable {
    public var name: String
    public var data: Data

    public init(name: String, data: Data) {
        self.name = name
        self.data = data
    }
}

nonisolated public struct HTMLWorkspaceConsoleError: Codable, Sendable, Hashable {
    public var message: String
    public var source: String?
    public var line: UInt32
    public var column: UInt32
    public var timestamp: Int64

    public init(
        message: String,
        source: String?,
        line: UInt32,
        column: UInt32,
        timestamp: Int64
    ) {
        self.message = message
        self.source = source
        self.line = line
        self.column = column
        self.timestamp = timestamp
    }
}

nonisolated public enum HTMLWorkspacePatchApplier {
    public static func apply(
        _ operation: HTMLWorkspacePatchOperation,
        to package: HTMLWorkspacePackage
    ) throws -> HTMLWorkspacePackage {
        var updated = package
        let mutationTimestamp = Int64(Date().timeIntervalSince1970 * 1_000)
        switch operation {
        case .replaceDocument(let replacement):
            let previousContentHash = contentHash(for: updated)
            let reversibleSnapshot = try reversibleSnapshots(for: updated)
            updated.snapshots = reversibleSnapshot.snapshots
            if let title = replacement.title {
                updated.manifest.title = title
            }
            updated.indexHTML = replacement.html
            updated.styleCSS = replacement.css
            updated.scriptJS = replacement.js
            updated.dataJSON = replacement.dataJSON
            updated.manifest.generationProvenance = HTMLWorkspaceGenerationProvenance(
                producer: .agent,
                operation: replacement.provenanceOperation,
                generatedAt: mutationTimestamp,
                previousContentHash: previousContentHash,
                contentHash: contentHash(for: updated),
                reversibleSnapshotName: reversibleSnapshot.name,
                toolId: HTMLWorkspaceGenerationProvenance.patchToolID
            )
        case .replaceHTML(let html):
            updated.indexHTML = html
        case .replaceCSS(let css):
            updated.styleCSS = css
        case .replaceJS(let js):
            updated.scriptJS = js
        case .replaceDataJSON(let json):
            updated.dataJSON = json
        case .setDataFeed(let feed):
            updated.manifest.dataFeed = feed
            if let feed {
                updated.dataJSON = HTMLWorkspaceDataFeedJSONEnvelope.staleDataJSON(
                    feed: feed,
                    error: "Feed pending"
                )
            }
        case .insertBlock(let insertion):
            updated.indexHTML = insert(insertion.html, into: updated.indexHTML, location: insertion.location)
        case .insertChart(let chart):
            updated.indexHTML = insert(chartHTML(for: chart), into: updated.indexHTML, location: .beforeClosingBody)
            if !updated.styleCSS.contains(".html-workspace-chart") {
                updated.styleCSS += "\n\n" + chartCSS
            }
            if !updated.scriptJS.contains("data-html-workspace-chart") {
                updated.scriptJS += "\n\n" + chartJS
            }
        case .updateStyleRule(let rule):
            updated.styleCSS = try updateStyleRule(rule, in: updated.styleCSS)
        case .setRoute(let name, let html):
            try HTMLWorkspacePackage.validatePackageFileName(name)
            updated.routes[name] = html
            try HTMLWorkspacePackage.validateRoutes(updated.routes)
        case .removeRoute(let name):
            try HTMLWorkspacePackage.validatePackageFileName(name)
            updated.routes.removeValue(forKey: name)
            try HTMLWorkspacePackage.validateRoutes(updated.routes)
        case .addAsset(let asset):
            try HTMLWorkspacePackage.validatePackageFileName(asset.name)
            updated.assets[asset.name] = asset.data
            try HTMLWorkspacePackage.validateAssets(updated.assets)
        case .removeAsset(let name):
            try HTMLWorkspacePackage.validatePackageFileName(name)
            updated.assets.removeValue(forKey: name)
            try HTMLWorkspacePackage.validateAssets(updated.assets)
        case .captureSnapshot(let name):
            try HTMLWorkspacePackage.validatePackageFileName(name)
            updated.snapshots[name] = Data(HTMLWorkspacePreviewDocument.render(package: updated).utf8)
            updated.snapshots = boundedSnapshots(updated.snapshots)
            try HTMLWorkspacePackage.validateSnapshots(updated.snapshots)
        case .recordConsoleError(let error):
            updated.consoleErrors.append(error)
            updated.consoleErrors = Array(updated.consoleErrors.suffix(HTMLWorkspacePackageLimits.maxConsoleErrors))
        }
        stampManifestRevision(&updated, updatedAt: mutationTimestamp)
        return updated
    }

    private static func stampManifestRevision(
        _ package: inout HTMLWorkspacePackage,
        updatedAt: Int64
    ) {
        package.manifest.updatedAt = updatedAt
        package.manifest.contentHash = contentHash(for: package)
    }

    private static func updateStyleRule(
        _ rule: HTMLWorkspaceStyleRulePatch,
        in css: String
    ) throws -> String {
        let selector = rule.selector.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selector.isEmpty,
              !selector.contains("{"),
              !selector.contains("}"),
              !selector.contains("<") else {
            throw HTMLWorkspacePackageError.invalidStyleRule(reason: "selector")
        }
        guard !rule.declarations.isEmpty else {
            throw HTMLWorkspacePackageError.invalidStyleRule(reason: "empty declarations")
        }

        let declarations = try rule.declarations
            .sorted { $0.key < $1.key }
            .map { key, value -> String in
                try validateStyleDeclaration(name: key, value: value)
                return "  \(key): \(value);"
            }
            .joined(separator: "\n")
        let replacement = "\(selector) {\n\(declarations)\n}"
        let pattern = #"(?s)(^|\n)\s*\#(NSRegularExpression.escapedPattern(for: selector))\s*\{[^}]*\}"#
        let expression = try NSRegularExpression(pattern: pattern)
        let range = NSRange(css.startIndex..<css.endIndex, in: css)
        if expression.firstMatch(in: css, range: range) == nil {
            return css.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + replacement
        }
        let updated = expression.stringByReplacingMatches(
            in: css,
            range: range,
            withTemplate: NSRegularExpression.escapedTemplate(for: "\n\(replacement)")
        )
        return updated.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func validateStyleDeclaration(name: String, value: String) throws {
        let property = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let validProperty = property.range(
            of: #"^[A-Za-z-]+$"#,
            options: .regularExpression
        ) != nil
        guard validProperty, property == name else {
            throw HTMLWorkspacePackageError.invalidStyleRule(reason: "property")
        }
        guard !value.contains("{"),
              !value.contains("}"),
              !value.contains("<"),
              value.count <= 512 else {
            throw HTMLWorkspacePackageError.invalidStyleRule(reason: "value")
        }
    }

    private struct ReversibleSnapshotResult {
        var snapshots: [String: Data]
        var name: String
    }

    private static func boundedSnapshots(
        _ snapshots: [String: Data],
        preserving preservedName: String? = nil
    ) -> [String: Data] {
        guard snapshots.count > HTMLWorkspacePackageLimits.maxSnapshots else { return snapshots }
        var keep = Set(snapshots.keys.sorted().suffix(HTMLWorkspacePackageLimits.maxSnapshots))
        if let preservedName, snapshots[preservedName] != nil, !keep.contains(preservedName) {
            keep.insert(preservedName)
            if let dropped = keep
                .filter({ $0 != preservedName })
                .sorted()
                .first {
                keep.remove(dropped)
            }
        }
        return snapshots.filter { keep.contains($0.key) }
    }

    private static func reversibleSnapshots(for package: HTMLWorkspacePackage) throws -> ReversibleSnapshotResult {
        var snapshots = package.snapshots
        let name = "pre-replace-\(contentHash(for: package).prefix(12)).html"
        snapshots[name] = Data(HTMLWorkspacePreviewDocument.render(package: package).utf8)
        snapshots = boundedSnapshots(snapshots, preserving: name)
        try HTMLWorkspacePackage.validateSnapshots(snapshots)
        return ReversibleSnapshotResult(snapshots: snapshots, name: name)
    }

    private static func contentHash(for package: HTMLWorkspacePackage) -> String {
        HTMLWorkspacePackageContentHasher.hash(
            indexHTML: package.indexHTML,
            styleCSS: package.styleCSS,
            scriptJS: package.scriptJS,
            dataJSON: package.dataJSON,
            routes: package.routes
        )
    }

    private static func insert(
        _ html: String,
        into source: String,
        location: HTMLWorkspaceBlockInsertion.Location
    ) -> String {
        switch location {
        case .append:
            return source + "\n" + html
        case .beforeClosingBody:
            guard let range = source.range(of: "</body>", options: [.caseInsensitive, .backwards]) else {
                return source + "\n" + html
            }
            var copy = source
            copy.insert(contentsOf: "\n\(html)\n", at: range.lowerBound)
            return copy
        }
    }

    private static func chartHTML(for chart: HTMLWorkspaceChartSpec) -> String {
        let safeID = escapeAttribute(chart.id)
        let maxValue = max(chart.values.map(\.value).max() ?? 1, 1)
        let bars = chart.values.map { datum in
            let width = max(2, min(100, (datum.value / maxValue) * 100))
            return """
              <div class="html-workspace-chart-row">
                <span>\(escapeHTML(datum.label))</span>
                <div class="html-workspace-chart-track"><i style="width: \(String(format: "%.2f", width))%"></i></div>
                <strong>\(String(format: "%.2f", datum.value))</strong>
              </div>
            """
        }.joined(separator: "\n")
        return """
        <section class="html-workspace-chart" data-html-workspace-chart="\(safeID)">
          <h2>\(escapeHTML(chart.title))</h2>
        \(bars)
        </section>
        """
    }

    private static let chartCSS = """
    .html-workspace-chart {
      display: grid;
      gap: 12px;
      width: min(720px, 100%);
      margin: 24px auto;
      padding: 18px;
      border: 1px solid color-mix(in srgb, CanvasText 14%, transparent);
      border-radius: 8px;
      background: color-mix(in srgb, Canvas 92%, CanvasText 8%);
    }

    .html-workspace-chart h2 {
      margin: 0 0 4px;
      font-size: 18px;
    }

    .html-workspace-chart-row {
      display: grid;
      grid-template-columns: minmax(88px, 0.7fr) minmax(120px, 2fr) minmax(48px, auto);
      align-items: center;
      gap: 10px;
      font-size: 13px;
    }

    .html-workspace-chart-track {
      height: 10px;
      overflow: hidden;
      border-radius: 999px;
      background: color-mix(in srgb, CanvasText 12%, transparent);
    }

    .html-workspace-chart-track i {
      display: block;
      height: 100%;
      border-radius: inherit;
      background: color-mix(in srgb, AccentColor 78%, CanvasText 22%);
    }
    """

    private static let chartJS = """
    document.querySelectorAll('[data-html-workspace-chart]').forEach((chart) => {
      chart.dataset.ready = 'true';
    });
    """

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeAttribute(_ value: String) -> String {
        escapeHTML(value).replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private extension String {
    nonisolated var nonEmptyJSONFallback: String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "{}" : self
    }
}
