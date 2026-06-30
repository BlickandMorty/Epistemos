import Foundation
import Testing

@testable import Epistemos

@Suite("HTML Workspace package and patch model")
nonisolated struct HTMLWorkspacePackageTests {
    private static let createdAt: Int64 = 1_700_000_000_000

    private static func sampleManifest() -> HTMLWorkspaceManifest {
        HTMLWorkspaceManifest(
            id: "html-workspace-test",
            schemaVersion: HTMLWorkspaceManifest.currentSchemaVersion,
            createdAt: createdAt,
            updatedAt: createdAt + 1_000,
            title: "Interactive Doc",
            contentHash: "sha256-fixture",
            sandboxPolicy: .offlineDefault
        )
    }

    private static func samplePackage() -> HTMLWorkspacePackage {
        HTMLWorkspacePackage(
            manifest: sampleManifest(),
            indexHTML: "<main><h1>Interactive Doc</h1><p>DOM workspace</p></main>",
            styleCSS: "main { display: grid; gap: 12px; }",
            scriptJS: "document.body.dataset.ready = 'true';",
            dataJSON: #"{"metrics":[{"label":"Nodes","value":3}]}"#,
            assets: ["texture.png": Data([0x89, 0x50, 0x4e, 0x47])],
            snapshots: ["initial.html": Data("<main>snapshot</main>".utf8)]
        )
    }

    @Test("HTMLWorkspacePackage round-trips index, style, script, data, assets, and manifest")
    func packageRoundTripsThroughFileWrapper() throws {
        let original = Self.samplePackage()

        let wrapper = try original.makeFileWrapper()
        #expect(wrapper.isDirectory)
        #expect(wrapper.fileWrappers?[HTMLWorkspacePackageEntry.manifest] != nil)
        #expect(wrapper.fileWrappers?[HTMLWorkspacePackageEntry.indexHTML] != nil)
        #expect(wrapper.fileWrappers?[HTMLWorkspacePackageEntry.styleCSS] != nil)
        #expect(wrapper.fileWrappers?[HTMLWorkspacePackageEntry.scriptJS] != nil)
        #expect(wrapper.fileWrappers?[HTMLWorkspacePackageEntry.dataJSON] != nil)
        #expect(HTMLWorkspacePackageEntry.scriptJS == "main.js")

        let recovered = try HTMLWorkspacePackage(fileWrapper: wrapper)
        #expect(recovered.manifest == original.manifest)
        #expect(recovered.indexHTML == original.indexHTML)
        #expect(recovered.styleCSS == original.styleCSS)
        #expect(recovered.scriptJS == original.scriptJS)
        #expect(recovered.dataJSON == original.dataJSON)
        #expect(recovered.assets == original.assets)
        #expect(recovered.snapshots == original.snapshots)
    }

    @Test("HTMLWorkspace manifest round-trips explicit vault search data feed")
    func manifestDataFeedRoundTrips() throws {
        var original = Self.samplePackage()
        original.manifest.dataFeed = .vaultSearch(query: "categorical imperative", limit: 99)

        let recovered = try HTMLWorkspacePackage(fileWrapper: try original.makeFileWrapper())

        #expect(recovered.manifest.dataFeed?.source == .vaultSearch)
        #expect(recovered.manifest.dataFeed?.normalizedQuery == "categorical imperative")
        #expect(recovered.manifest.dataFeed?.limit == 99)
        #expect(recovered.manifest.dataFeed?.effectiveLimit == HTMLWorkspaceDataFeed.maxLimit)
    }

    @Test("HTMLWorkspace vault search feed renders provenance and freshness metadata into data.json")
    func dataFeedRenderIncludesProvenanceMetadata() throws {
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "  substrate provenance  ", limit: 2)
        let rendered = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            results: [
                SearchResult(
                    pageId: "page-1",
                    title: "Research Note",
                    snippet: "substrate provenance witness",
                    rank: 0.87
                )
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(rendered.contains(#""_epistemos""#))
        #expect(rendered.contains(#""source" : "vault_search""#))
        #expect(rendered.contains(#""query" : "substrate provenance""#))
        #expect(rendered.contains(#""provenance" : "VaultSyncService.searchFullAsync""#))
        #expect(rendered.contains(#""stale" : false"#))
        #expect(rendered.contains(#""page_id" : "page-1""#))

        let metadata = try #require(HTMLWorkspaceDataFeedStatus.metadata(from: rendered))
        #expect(metadata.resultCount == 1)
        #expect(metadata.refreshedAtMS == 1_700_000_000_000)
        #expect(metadata.stale == false)
    }

    @Test("HTMLWorkspace vault search dashboard template seeds a live data feed shell")
    func vaultSearchDashboardTemplateSeedsLiveDataFeedShell() throws {
        var package = HTMLWorkspacePackage.defaultPackage()

        package.applyVaultSearchDashboardTemplate(query: "  substrate provenance  ", limit: 99)

        #expect(package.manifest.title == "Vault Search: substrate provenance")
        #expect(package.manifest.dataFeed?.source == .vaultSearch)
        #expect(package.manifest.dataFeed?.normalizedQuery == "substrate provenance")
        #expect(package.manifest.dataFeed?.limit == HTMLWorkspaceDataFeed.maxLimit)
        #expect(package.indexHTML.contains("data-vault-results"))
        #expect(package.styleCSS.contains(".result-card"))
        #expect(package.scriptJS.contains("renderVaultResults"))
        #expect(package.scriptJS.contains("htmlworkspace:datachange"))

        let metadata = try #require(HTMLWorkspaceDataFeedStatus.metadata(from: package.dataJSON))
        #expect(metadata.query == "substrate provenance")
        #expect(metadata.limit == HTMLWorkspaceDataFeed.maxLimit)
        #expect(metadata.provenance == "VaultSyncService.searchFullAsync")
        #expect(metadata.stale == true)

        let rendered = HTMLWorkspacePreviewDocument.render(package: package)
        #expect(rendered.contains("data-vault-results"))
        #expect(rendered.contains(#"id="workspace-data""#))
    }

    @Test("legacy script.js packages still load into the main JS source")
    func legacyScriptPackagesStillLoad() throws {
        let manifestData = try JSONEncoder.epdocCanonical.encode(Self.sampleManifest())
        let wrapper = FileWrapper(directoryWithFileWrappers: [
            HTMLWorkspacePackageEntry.manifest: FileWrapper(regularFileWithContents: manifestData),
            HTMLWorkspacePackageEntry.indexHTML: FileWrapper(regularFileWithContents: Data("<main></main>".utf8)),
            HTMLWorkspacePackageEntry.legacyScriptJS: FileWrapper(regularFileWithContents: Data("document.body.dataset.legacy = 'true';".utf8)),
        ])

        let package = try HTMLWorkspacePackage(fileWrapper: wrapper)
        #expect(package.scriptJS.contains("legacy"))
        #expect(package.dataJSON == "{}")
    }

    @Test("manifest validation rejects malformed or newer package schemas")
    func manifestValidationRejectsBadPackages() throws {
        let malformed = FileWrapper(directoryWithFileWrappers: [
            HTMLWorkspacePackageEntry.manifest: FileWrapper(regularFileWithContents: Data("{".utf8)),
            HTMLWorkspacePackageEntry.indexHTML: FileWrapper(regularFileWithContents: Data("<main></main>".utf8)),
        ])
        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try HTMLWorkspacePackage(fileWrapper: malformed)
        }

        var tooNewManifest = Self.sampleManifest()
        tooNewManifest.schemaVersion = HTMLWorkspaceManifest.currentSchemaVersion + 1
        let tooNew = FileWrapper(directoryWithFileWrappers: [
            HTMLWorkspacePackageEntry.manifest: FileWrapper(regularFileWithContents: try JSONEncoder.epdocCanonical.encode(tooNewManifest)),
            HTMLWorkspacePackageEntry.indexHTML: FileWrapper(regularFileWithContents: Data("<main></main>".utf8)),
        ])
        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try HTMLWorkspacePackage(fileWrapper: tooNew)
        }
    }

    @Test("offline preview injects CSP that blocks network and app internals by default")
    func offlinePreviewInjectsCSP() {
        let package = Self.samplePackage()
        let srcdoc = HTMLWorkspacePreviewDocument.render(package: package)
        let darkSrcdoc = HTMLWorkspacePreviewDocument.render(package: package, theme: .dark)
        #expect(package.manifest.sandboxPolicy.allowNetwork == false)
        #expect(package.manifest.sandboxPolicy.allowAppBridge == false)
        #expect(srcdoc.contains("Content-Security-Policy"))
        #expect(srcdoc.contains("default-src 'none'"))
        #expect(srcdoc.contains("connect-src 'none'"))
        #expect(srcdoc.contains(#"id="workspace-data""#))
        #expect(darkSrcdoc.contains(#"data-epistemos-theme="dark""#))
        #expect(darkSrcdoc.contains(#"id="epistemos-font-face""#))
        #expect(darkSrcdoc.contains(#"id="epistemos-theme-host""#))
        #expect(darkSrcdoc.contains("--epistemos-workspace-title-font"))
        #expect(darkSrcdoc.contains("MatrixTypeDisplay"))
        #expect(darkSrcdoc.contains(#"font-family: "MatrixTypeDisplay-Regular";"#))
        #expect(darkSrcdoc.contains(#"font-family: "MatrixTypeDisplay";"#))
        #expect(darkSrcdoc.contains(#"font-family: "ChonkyPixels";"#))
        #expect(darkSrcdoc.contains("data-metric-value"))
        #expect(darkSrcdoc.contains("font-synthesis: none"))
        #expect(srcdoc.contains("window, 'HTMLWorkspace'"))
        #expect(srcdoc.contains("get data()"))
        #expect(srcdoc.contains("__epistemosReplaceWorkspaceData"))
        #expect(srcdoc.contains("htmlworkspace:datachange"))
        #expect(!srcdoc.contains("window.webkit.messageHandlers"),
                "Preview HTML must not expose app bridge handlers unless an explicit safe API is enabled.")
    }

    @Test("importing exported HTML preserves user sources without host scaffold")
    func importingExportedHTMLPreservesUserSourcesWithoutHostScaffold() {
        let package = HTMLWorkspacePackage(
            manifest: Self.sampleManifest(),
            indexHTML: #"<main class="user-card"><h1>Imported</h1></main>"#,
            styleCSS: "  :root { --card-gap: 12px; }\n.user-card { display: grid; gap: var(--card-gap); }\n",
            scriptJS: "\ndocument.body.dataset.userScript = 'true';\n",
            dataJSON: #"{"message":"hello","danger":"</script><!--"}"#
        )

        let exported = HTMLWorkspacePreviewDocument.render(package: package, theme: .dark)
        let imported = HTMLWorkspaceHTMLImporter.importSources(from: exported)

        #expect(exported.contains(#"id="epistemos-workspace-runtime""#))
        #expect(exported.contains(#"<\/script><!--"#))
        #expect(imported.html == package.indexHTML)
        #expect(imported.css == package.styleCSS)
        #expect(imported.js == package.scriptJS)
        #expect(imported.dataJSON == package.dataJSON)
        #expect(!imported.css.contains("--epistemos-workspace-title-font"))
        #expect(!imported.css.contains("html[data-epistemos-theme]"))
        #expect(!imported.js.contains("Object.defineProperty(window, 'HTMLWorkspace'"))
    }

    @Test("HTML import keeps only executable user scripts")
    func htmlImportKeepsOnlyExecutableUserScripts() {
        let source = """
        <!doctype html>
        <html>
        <head>
          <style>.card { color: red; }</style>
        </head>
        <body>
          <main>Import</main>
          <script type="application/json; charset=utf-8">{"ignored":true}</script>
          <script type="importmap">{"imports":{"x":"/x.js"}}</script>
          <script type="module">export const moduleValue = 1;</script>
          <script type="text/javascript">window.plainScript = true;</script>
        </body>
        </html>
        """

        let imported = HTMLWorkspaceHTMLImporter.importSources(from: source)

        #expect(imported.css == ".card { color: red; }")
        #expect(imported.js.contains("export const moduleValue = 1;"))
        #expect(imported.js.contains("window.plainScript = true;"))
        #expect(!imported.js.contains(#""ignored":true"#))
        #expect(!imported.js.contains(#""imports""#))
    }

    @Test("default workspace uses display fonts for title and metric numerals")
    func defaultWorkspaceUsesDisplayTypography() {
        let package = HTMLWorkspacePackage.defaultPackage()

        #expect(package.styleCSS.contains("font-family: var(--epistemos-workspace-title-font);"))
        #expect(package.styleCSS.contains("font-family: var(--epistemos-workspace-heading-font);"))
        #expect(package.styleCSS.contains(".metric-card strong"))
        #expect(package.styleCSS.contains("line-height: 0.95"))
    }

    @Test("starter template detection distinguishes untouched defaults from edited workspaces")
    func starterTemplateDetectionDistinguishesEditedWorkspaces() {
        let starter = HTMLWorkspacePackage.defaultPackage()
        var edited = starter
        edited.indexHTML = "<main><h1>User pasted code</h1></main>"

        #expect(starter.isStarterTemplateContent)
        #expect(!edited.isStarterTemplateContent)
        #expect(!Self.samplePackage().isStarterTemplateContent)
    }

    @Test("structured patch operations update sources without arbitrary mutation strings")
    func structuredPatchOperationsApply() throws {
        var package = Self.samplePackage()
        package = try HTMLWorkspacePatchApplier.apply(.replaceHTML("<section id=\"root\"></section>"), to: package)
        package = try HTMLWorkspacePatchApplier.apply(.replaceCSS("#root { min-height: 200px; }"), to: package)
        package = try HTMLWorkspacePatchApplier.apply(.replaceJS("document.querySelector('#root')?.setAttribute('data-live', 'true');"), to: package)
        package = try HTMLWorkspacePatchApplier.apply(.replaceDataJSON(#"{"nodes":[1,2,3]}"#), to: package)
        package = try HTMLWorkspacePatchApplier.apply(.insertBlock(HTMLWorkspaceBlockInsertion(
            html: "<button>Run</button>",
            location: .beforeClosingBody
        )), to: package)

        #expect(package.indexHTML.contains("<section id=\"root\"></section>"))
        #expect(package.indexHTML.contains("<button>Run</button>"))
        #expect(package.styleCSS.contains("min-height"))
        #expect(package.scriptJS.contains("data-live"))
        #expect(package.dataJSON.contains("\"nodes\""))
    }

    @Test("replaceDocument swaps the generated source quad atomically")
    func replaceDocumentPatchOperationAppliesAtomically() throws {
        let original = Self.samplePackage()
        let replacement = HTMLWorkspaceDocumentReplacement(
            title: "Generated Explainer",
            html: "<main><h1>Generated Explainer</h1></main>",
            css: "main { display: grid; }",
            js: "document.body.dataset.generated = 'true';",
            dataJSON: #"{"generated":true}"#
        )

        let updated = try HTMLWorkspacePatchApplier.apply(.replaceDocument(replacement), to: original)

        #expect(updated.manifest.id == original.manifest.id)
        #expect(updated.manifest.sandboxPolicy == original.manifest.sandboxPolicy)
        #expect(updated.manifest.title == "Generated Explainer")
        #expect(updated.indexHTML == replacement.html)
        #expect(updated.styleCSS == replacement.css)
        #expect(updated.scriptJS == replacement.js)
        #expect(updated.dataJSON == replacement.dataJSON)
        #expect(updated.assets == original.assets)
        #expect(updated.snapshots == original.snapshots)
    }

    @Test("advanced structured operations are deterministic and path safe")
    func advancedStructuredPatchOperationsApply() throws {
        var package = Self.samplePackage()
        package.styleCSS += "\n.panel { color: red; }"

        package = try HTMLWorkspacePatchApplier.apply(
            .updateStyleRule(HTMLWorkspaceStyleRulePatch(
                selector: ".panel",
                declarations: ["color": "blue", "display": "grid"]
            )),
            to: package
        )
        package = try HTMLWorkspacePatchApplier.apply(
            .addAsset(HTMLWorkspaceAsset(name: "fixture.json", data: Data("{\"ok\":true}".utf8))),
            to: package
        )
        package = try HTMLWorkspacePatchApplier.apply(.captureSnapshot(name: "after-chart.html"), to: package)
        package = try HTMLWorkspacePatchApplier.apply(
            .recordConsoleError(HTMLWorkspaceConsoleError(
                message: "ReferenceError: nope",
                source: "main.js",
                line: 12,
                column: 4,
                timestamp: Self.createdAt + 2_000
            )),
            to: package
        )

        #expect(package.styleCSS.contains(".panel {"))
        #expect(package.styleCSS.contains("color: blue;"))
        #expect(!package.styleCSS.contains("color: red;"))
        #expect(package.assets["fixture.json"] == Data("{\"ok\":true}".utf8))
        #expect(package.snapshots["after-chart.html"] != nil)
        #expect(package.consoleErrors.last?.message == "ReferenceError: nope")

        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try HTMLWorkspacePatchApplier.apply(
                .addAsset(HTMLWorkspaceAsset(name: "../secret", data: Data())),
                to: package
            )
        }
    }

    @Test("console errors and snapshots remain bounded")
    func consoleErrorsAndSnapshotsRemainBounded() throws {
        var package = Self.samplePackage()

        for index in 0..<80 {
            package = try HTMLWorkspacePatchApplier.apply(
                .recordConsoleError(HTMLWorkspaceConsoleError(
                    message: "error-\(index)",
                    source: "main.js",
                    line: UInt32(index),
                    column: 0,
                    timestamp: Self.createdAt + Int64(index)
                )),
                to: package
            )
        }
        for index in 0..<24 {
            package = try HTMLWorkspacePatchApplier.apply(.captureSnapshot(name: "snap-\(index).html"), to: package)
        }

        #expect(package.consoleErrors.count == HTMLWorkspacePackageLimits.maxConsoleErrors)
        #expect(package.consoleErrors.first?.message == "error-32")
        #expect(package.snapshots.count == HTMLWorkspacePackageLimits.maxSnapshots)
        #expect(package.snapshots["snap-0.html"] == nil)
        #expect(package.snapshots["snap-23.html"] != nil)
    }

    @Test("chart helper inserts a visible local chart block")
    func chartHelperInsertsVisibleLocalChart() throws {
        let chart = HTMLWorkspaceChartSpec(
            id: "evidence-chart",
            title: "Evidence Mix",
            values: [
                HTMLWorkspaceChartDatum(label: "Primary", value: 8),
                HTMLWorkspaceChartDatum(label: "Bench", value: 5),
            ]
        )

        let updated = try HTMLWorkspacePatchApplier.apply(.insertChart(chart), to: Self.samplePackage())
        #expect(updated.indexHTML.contains("data-html-workspace-chart=\"evidence-chart\""))
        #expect(updated.indexHTML.contains("Evidence Mix"))
        #expect(updated.styleCSS.contains(".html-workspace-chart"))
        #expect(updated.scriptJS.contains("data-html-workspace-chart"))
    }

    @Test("hostile source still renders inside the offline CSP envelope")
    func hostileSourceKeepsOfflineEnvelope() {
        let hostile = HTMLWorkspacePackage(
            manifest: Self.sampleManifest(),
            indexHTML: "<a href=\"https://example.com\">escape</a><img src=\"https://example.com/pixel.png\">",
            styleCSS: "body { background: Canvas; }",
            scriptJS: "fetch('https://example.com'); window.webkit.messageHandlers.epdoc.postMessage({});"
        )

        let srcdoc = HTMLWorkspacePreviewDocument.render(package: hostile)
        #expect(srcdoc.contains("default-src 'none'"))
        #expect(srcdoc.contains("connect-src 'none'"))
        #expect(srcdoc.contains("frame-src 'none'"))
        #expect(!srcdoc.contains(HTMLWorkspaceSafeAPI.messageHandlerName))
    }

    @Test("HTML workspace patch command parser accepts structured workspace edits")
    func htmlWorkspacePatchCommandParserAcceptsStructuredEdits() throws {
        let response = """
        I will add the visualization.

        ```epistemos-html-workspace-patch
        {"workspace_id":"html-workspace-test","operations":[{"type":"setDataFeed","data_feed":{"source":"vault_search","query":"substrate provenance","limit":7}},{"type":"replaceDataJSON","json":"{\\"series\\":[1,2,3]}"},{"type":"insertBlock","html":"<section class=\\"viz\\"><h2>Signal</h2></section>","location":"append"},{"type":"updateStyleRule","selector":".viz","declarations":{"display":"grid","gap":"12px"}}]}
        ```
        """

        let result = try HTMLWorkspacePatchCommandParser.parse(response)
        #expect(result.batches.count == 1)
        #expect(result.cleanedText == "I will add the visualization.")
        #expect(result.batches[0].operations.count == 4)

        var package = Self.samplePackage()
        for command in result.batches[0].operations {
            package = try HTMLWorkspacePatchApplier.apply(command.patchOperation(), to: package)
        }
        #expect(package.manifest.dataFeed?.source == .vaultSearch)
        #expect(package.manifest.dataFeed?.normalizedQuery == "substrate provenance")
        #expect(package.manifest.dataFeed?.limit == 7)
        #expect(package.indexHTML.contains("class=\"viz\""))
        #expect(package.dataJSON.contains("series"))
        #expect(package.styleCSS.contains(".viz {"))
        #expect(package.styleCSS.contains("display: grid;"))

        let regenerate = """
        ```epistemos-html-workspace-patch
        {"workspace_id":"html-workspace-test","operations":[{"type":"regenerate","title":"Generated Explainer","html":"<main><h1>Generated</h1></main>","css":"main { display: grid; }","js":"document.body.dataset.generated = 'true';","json":"{\\"generated\\":true}"}]}
        ```
        """
        let regenerateResult = try HTMLWorkspacePatchCommandParser.parse(regenerate)
        var regenerated = Self.samplePackage()
        for command in regenerateResult.batches[0].operations {
            regenerated = try HTMLWorkspacePatchApplier.apply(command.patchOperation(), to: regenerated)
        }
        #expect(regenerated.manifest.title == "Generated Explainer")
        #expect(regenerated.indexHTML.contains("<h1>Generated</h1>"))
        #expect(regenerated.styleCSS.contains("display: grid"))
        #expect(regenerated.scriptJS.contains("generated"))
        #expect(regenerated.dataJSON.contains("generated"))
    }

    @Test("Document surface metadata captures HTML Workspace panes")
    func documentSurfaceMetadataCapturesHTMLWorkspacePanes() {
        let surface = DocumentSurface(
            id: "workspace-1",
            kind: .htmlWorkspace,
            title: "Workspace",
            fileURL: URL(fileURLWithPath: "/tmp/workspace.htmlworkspace"),
            currentSelection: DocumentSourceRange(startLine: 2, startColumn: 1, endLine: 4, endColumn: 12),
            capabilities: [.read, .write, .patch, .exportHTML, .exportPDF, .importContent, .preview],
            contentHash: "abc123"
        )

        #expect(surface.kind == .htmlWorkspace)
        #expect(surface.capabilities.contains(.patch))
        #expect(surface.currentSelection?.startLine == 2)
        #expect(surface.contentHash == "abc123")
    }

    @Test("HTML workspace patch command parser rejects unsafe DOM and app bridge attempts")
    func htmlWorkspacePatchCommandParserRejectsUnsafeOperations() {
        let inlineHandler = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"insertBlock","html":"<button onclick=\\"alert(1)\\">Run</button>"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(inlineHandler)
        }

        let spacedInlineHandler = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"insertBlock","html":"<button onclick = \\"alert(1)\\">Run</button>"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(spacedInlineHandler)
        }

        let appBridgeProbe = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceJS","js":"window.webkit.messageHandlers.epdoc.postMessage({})"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(appBridgeProbe)
        }

        let spacedAppBridgeProbe = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceJS","js":"window . webkit ?. messageHandlers.epdoc.postMessage({})"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(spacedAppBridgeProbe)
        }

        let optionalChainingAppBridgeProbe = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceJS","js":"window?.webkit?.messageHandlers.epdoc.postMessage({})"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(optionalChainingAppBridgeProbe)
        }

        let bracketAppBridgeProbe = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceJS","js":"window['webkit'][\\"messageHandlers\\"].epdoc.postMessage({})"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(bracketAppBridgeProbe)
        }

        let globalAppBridgeProbe = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceJS","js":"webkit.messageHandlers.epdoc.postMessage({})"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(globalAppBridgeProbe)
        }

        let malformedData = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceDataJSON","json":"{"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(malformedData)
        }

        let unsafeWholeDocumentHTML = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceDocument","html":"<main><script>alert(1)</script></main>","css":"","js":"","json":"{}"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(unsafeWholeDocumentHTML)
        }

        let unsafeWholeDocumentJS = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceDocument","html":"<main></main>","css":"","js":"localStorage.setItem('x','y');","json":"{}"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(unsafeWholeDocumentJS)
        }
    }

    @Test("HTML workspace patch command parser bounds operation counts and assets")
    func htmlWorkspacePatchCommandParserBoundsPayloads() {
        let operations = Array(repeating: #"{"type":"captureSnapshot","name":"snap.html"}"#, count: HTMLWorkspacePatchCommandLimits.maxOperations + 1)
            .joined(separator: ",")
        let tooMany = """
        ```epistemos-html-workspace-patch
        {"operations":[\(operations)]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(tooMany)
        }

        let traversal = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"addAsset","name":"../secret","base64":"AA=="}]}
        ```
        """
        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(traversal)
        }
    }

    @Test("HTML workspace patch errors keep useful localized descriptions")
    func htmlWorkspacePatchErrorsKeepLocalizedDescriptions() {
        let routerError = HTMLWorkspacePatchRouterError.unsafeSource(reason: "inline event handler")
        #expect(routerError.localizedDescription.contains("HTML Workspace patch contains unsafe source"))
        #expect(routerError.localizedDescription.contains("inline event handler"))

        let packageError = HTMLWorkspacePackageError.invalidPackagePath(name: "../secret")
        #expect(packageError.localizedDescription.contains("invalid package path"))
        #expect(packageError.localizedDescription.contains("../secret"))
    }
}
