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
        #expect(!srcdoc.contains("window.webkit.messageHandlers"),
                "Preview HTML must not expose app bridge handlers unless an explicit safe API is enabled.")
    }

    @Test("default workspace uses display fonts for title and metric numerals")
    func defaultWorkspaceUsesDisplayTypography() {
        let package = HTMLWorkspacePackage.defaultPackage()

        #expect(package.styleCSS.contains("font-family: var(--epistemos-workspace-title-font);"))
        #expect(package.styleCSS.contains("font-family: var(--epistemos-workspace-heading-font);"))
        #expect(package.styleCSS.contains(".metric-card strong"))
        #expect(package.styleCSS.contains("line-height: 0.95"))
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

    @Test("MiniChat patch command parser accepts structured workspace edits")
    func miniChatPatchCommandParserAcceptsStructuredEdits() throws {
        let response = """
        I will add the visualization.

        ```epistemos-html-workspace-patch
        {"workspace_id":"html-workspace-test","operations":[{"type":"replaceDataJSON","json":"{\\"series\\":[1,2,3]}"},{"type":"insertBlock","html":"<section class=\\"viz\\"><h2>Signal</h2></section>","location":"append"},{"type":"updateStyleRule","selector":".viz","declarations":{"display":"grid","gap":"12px"}}]}
        ```
        """

        let result = try HTMLWorkspacePatchCommandParser.parse(response)
        #expect(result.batches.count == 1)
        #expect(result.cleanedText == "I will add the visualization.")
        #expect(result.batches[0].operations.count == 3)

        var package = Self.samplePackage()
        for command in result.batches[0].operations {
            package = try HTMLWorkspacePatchApplier.apply(command.patchOperation(), to: package)
        }
        #expect(package.indexHTML.contains("class=\"viz\""))
        #expect(package.dataJSON.contains("series"))
        #expect(package.styleCSS.contains(".viz {"))
        #expect(package.styleCSS.contains("display: grid;"))
    }

    @Test("Document surface target metadata captures HTML Workspace panes")
    func documentSurfaceTargetMetadataCapturesHTMLWorkspacePanes() {
        let surface = DocumentSurface(
            id: "workspace-1",
            kind: .htmlWorkspace,
            title: "Workspace",
            fileURL: URL(fileURLWithPath: "/tmp/workspace.htmlworkspace"),
            currentSelection: DocumentSourceRange(startLine: 2, startColumn: 1, endLine: 4, endColumn: 12),
            capabilities: [.read, .write, .patch, .exportHTML, .exportPDF, .importContent, .preview],
            contentHash: "abc123"
        )
        let target = MiniChatTarget(
            surface: surface,
            pane: .html,
            selectedRange: surface.currentSelection,
            snippet: "<section id=\"root\"></section>",
            allowedOperations: ["replaceHTML", "insertBlock", "insertChart"]
        )

        #expect(surface.kind == .htmlWorkspace)
        #expect(surface.capabilities.contains(.patch))
        #expect(target.surfaceID == "workspace-1")
        #expect(target.pane == .html)
        #expect(target.contentHash == "abc123")
        #expect(target.allowedOperations.contains("insertChart"))
    }

    @Test("MiniChat patch command parser rejects unsafe DOM and app bridge attempts")
    func miniChatPatchCommandParserRejectsUnsafeOperations() {
        let inlineHandler = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"insertBlock","html":"<button onclick=\\"alert(1)\\">Run</button>"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(inlineHandler)
        }

        let appBridgeProbe = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceJS","js":"window.webkit.messageHandlers.epdoc.postMessage({})"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(appBridgeProbe)
        }

        let malformedData = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceDataJSON","json":"{"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(malformedData)
        }
    }

    @Test("MiniChat patch command parser bounds operation counts and assets")
    func miniChatPatchCommandParserBoundsPayloads() {
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
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(traversal)
        }
    }
}
