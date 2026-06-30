import Foundation
import Testing

@testable import Epistemos

@Suite("HTML Workspace source guards", .serialized)
nonisolated struct HTMLWorkspaceSourceGuardTests {
    private var repoRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func repoFileExists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: repoRootURL.appendingPathComponent(relativePath).path)
    }

    @Test("preview uses offline WKWebView defaults and no implicit app bridge")
    func previewUsesOfflineWKWebViewDefaults() throws {
        let previewSource = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspacePreviewView.swift")

        #expect(previewSource.contains("WKWebsiteDataStore.nonPersistent()"))
        #expect(previewSource.contains("loadHTMLString"))
        #expect(previewSource.contains("setURLSchemeHandler"))
        #expect(previewSource.contains("HTMLWorkspaceLocalResourceScheme.scheme"))
        #expect(previewSource.contains("HTMLWorkspacePreviewURL.baseURL"))
        #expect(previewSource.contains("HTMLWorkspacePreviewURLSchemeHandler"))
        #expect(previewSource.contains("resourceResponse(for:"))
        #expect(previewSource.contains("assetShellHash(for: package)"))
        #expect(!previewSource.contains("baseURL: nil"))
        #expect(previewSource.contains("allowNetwork == false"))
        #expect(previewSource.contains("decisionHandler(.cancel)"))
        #expect(previewSource.contains("allowedNetworkSchemes"))
        #expect(previewSource.contains("\"http\", \"https\""))
        #expect(previewSource.contains("syncSafeAPIHandler"))
        #expect(previewSource.contains("safeAPIEnabled"))
        #expect(previewSource.contains("HTMLWorkspaceSafeAPI.messageHandlerName"))
        #expect(previewSource.contains("HTMLWorkspaceConsoleBridge.enabled"))
        #expect(previewSource.contains("HTMLWorkspaceConsoleBridge.injectionScript"))
        #expect(previewSource.contains("onConsoleError != nil"))
        #expect(previewSource.contains("canPatchDataOnly"))
        #expect(previewSource.contains("patchDataJSON"))
        #expect(previewSource.contains("evaluateJavaScript(script)"))
        #expect(previewSource.contains("__epistemosReplaceWorkspaceData"))
        #expect(previewSource.contains("lastRenderedShellIdentity"))
        #expect(previewSource.contains("EpdocWebViewShared.notifyWebViewCreated()"))
        #expect(previewSource.contains("EpdocWebViewShared.notifyWebViewDismantled()"))
        #expect(previewSource.components(separatedBy: "addUserScript(").count == 2,
                "Preview may install exactly one user script: the env-gated console capture bridge.")
        #expect(previewSource.contains("configuration.userContentController.addUserScript("),
                "The only preview user script should be the env-gated, read-only console capture bridge.")
        // Security gate: the app-bridge handler installs ONLY when BOTH the user-enabled flag AND the
        // per-package sandbox policy allow it — the sole barrier against arbitrary rendered HTML
        // obtaining an app bridge. Dropping either condition is a real privilege-escalation hole, so
        // pin the conjunction. (The safe-API channel itself is still a deferred stub — safeAPI
        // messages are not wired — but the install gate must never weaken regardless.)
        #expect(previewSource.contains("safeAPIEnabled && package.manifest.sandboxPolicy.allowAppBridge"),
                "App-bridge install must require BOTH safeAPIEnabled AND the package's allowAppBridge sandbox policy.")
        // The app-bridge handler is torn down on detach — no leaked WKScriptMessageHandler across
        // workspace swaps (an installed-but-orphaned bridge is both a leak and a latent surface).
        #expect(previewSource.contains("removeScriptMessageHandler"))
        #expect(previewSource.contains("messageHandlerInstalled = false"))
    }

    @Test("HTML workspace exposes explicit attachment helpers")
    func htmlWorkspaceExposesExplicitAttachmentHelpers() throws {
        let chatTypes = try loadMirroredSourceTextFile("Epistemos/Models/ChatTypes.swift")
        let helpers = try loadMirroredSourceTextFile("Epistemos/Views/Chat/NotesMentionDropdown.swift")

        #expect(chatTypes.contains("case htmlWorkspace"))
        #expect(helpers.contains("htmlWorkspaceAttachment("))
        #expect(helpers.contains("htmlworkspace://"))
    }

    @Test("HTML Workspace is a separate document surface, not an Epdoc overload")
    func workspaceIsSeparateFromEpdoc() throws {
        let documentSource = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspaceDocument.swift")
        let editorSource = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        let epdocSlash = try loadMirroredSourceTextFile("js-editor/src/extensions/slash-menu.ts")

        #expect(documentSource.contains("HTMLWorkspaceDocument: NSDocument"))
        #expect(documentSource.contains("com.epistemos.html-workspace"))
        #expect(documentSource.contains("HTMLWorkspaceDocumentThemedRoot"))
        #expect(documentSource.contains(".preferredColorScheme(ui.preferredColorScheme)"))
        #expect(editorSource.contains("HTMLWorkspacePreviewView("))
        #expect(editorSource.contains("HTMLWorkspaceCodeEditor("))
        #expect(!editorSource.contains("TextEditor("))
        #expect(epdocSlash.contains("id: 'html-workspace'"))
        #expect(!epdocSlash.contains("html-dom"))
    }

    @Test("existing HTML Workspace selection avoids the generic AppKit open path")
    func existingWorkspaceSelectionUsesHTMLWorkspaceOpenHelper() throws {
        let sidebarSource = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NotesSidebar.swift")
        let graphSource = try loadMirroredSourceTextFile("Epistemos/Views/Graph/GraphWorkspaceContainer.swift")
        let controllerSource = try loadMirroredSourceTextFile("Epistemos/App/EpistemosDocumentController.swift")
        let documentSource = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspaceDocument.swift")

        #expect(controllerSource.contains("func openHTMLWorkspaceDocument(at url: URL) throws -> HTMLWorkspaceDocument"))
        #expect(controllerSource.contains("FileWrapper(url: standardizedURL, options: [.immediate])"))
        #expect(controllerSource.contains("document.loadOpenedPackage(package, fileURL: standardizedURL)"))
        #expect(documentSource.contains("func loadOpenedPackage(_ package: HTMLWorkspacePackage, fileURL: URL)"))
        #expect(sidebarSource.contains("url.pathExtension == \"htmlworkspace\""))
        #expect(sidebarSource.contains("openHTMLWorkspaceDocument(at: url)"))
        #expect(graphSource.contains("openHTMLWorkspaceDocument(at: url)"))
    }

    @Test("editor preview updates are debounced and diagnostics are collapsible")
    func editorDebouncesPreviewAndCollapsesDiagnostics() throws {
        let editorSource = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")

        #expect(editorSource.contains("previewPackage"))
        #expect(editorSource.contains("previewUpdateTask"))
        #expect(editorSource.contains("Task.sleep"))
        #expect(editorSource.contains("HTMLWorkspacePreviewView(package: previewPackage"))
        #expect(editorSource.contains("HTMLWorkspacePDFExporter.export"))
        #expect(editorSource.contains("importHTML()"))
        #expect(editorSource.contains("exportHTML()"))
        #expect(editorSource.contains("previewRenderIdentity"))
        #expect(editorSource.contains("HTMLWorkspacePreviewIdentity.viewIdentity(for: previewPackage)"))
        #expect(editorSource.contains("themeIdentity: workspaceThemeIdentity"))
        #expect(editorSource.contains("currentHTMLWorkspaceDocument()"))
        #expect(editorSource.contains("document.save(nil)"))
        #expect(editorSource.contains("failedStatus("))
        #expect(editorSource.contains("error.localizedDescription"))
        #expect(editorSource.contains("generatedScriptIDs"))
        #expect(editorSource.contains(#""epistemos-workspace-runtime""#))
        #expect(editorSource.contains("scriptBodies(in: source)"))
        #expect(editorSource.contains("shouldImportScript(type:"))
        #expect(editorSource.contains(#"normalized == "module""#))
        #expect(editorSource.contains(".onChange(of: colorScheme)"))
        #expect(editorSource.contains("DisclosureGroup"))
        #expect(editorSource.contains("Console"))
        #expect(editorSource.contains("bridgeStatusText"))
        #expect(editorSource.contains(#""Safe API deferred""#))
    }

    @Test("HTML Workspace live data feed is explicit and provenance-visible")
    func htmlWorkspaceLiveDataFeedIsExplicitAndProvenanceVisible() throws {
        let packageSource = try loadMirroredSourceTextFile("Epistemos/Models/HTMLWorkspacePackage.swift")
        let documentSource = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspaceDocument.swift")
        let editorSource = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        let feedSource = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceDataFeed.swift")
        let templateSource = try loadMirroredSourceTextFile("Epistemos/Models/HTMLWorkspaceTemplates.swift")
        let hostSource = try loadMirroredSourceTextFile("Epistemos/Views/Workspace/ArtifactHostView.swift")

        #expect(packageSource.contains("struct HTMLWorkspaceDataFeed"))
        #expect(packageSource.contains("HTMLWorkspaceDataFeedJSONEnvelope"))
        #expect(packageSource.contains("case dataFeed = \"data_feed\""))
        #expect(templateSource.contains("applyVaultSearchDashboardTemplate"))
        #expect(templateSource.contains("HTMLWorkspaceDataFeedJSONEnvelope.staleDataJSON"))
        #expect(templateSource.contains("renderVaultResults"))
        #expect(templateSource.contains("htmlworkspace:datachange"))
        #expect(documentSource.contains("notifyPackageDidChange()"))
        #expect(documentSource.contains(".htmlWorkspacePackageDidChange"))
        #expect(editorSource.contains(".htmlWorkspaceDataFeed(package: $package, statusText: $statusText)"))
        #expect(editorSource.contains("HTMLWorkspaceDataFeedStatusStrip(package: package, compact: true)"))
        #expect(editorSource.contains("Configure Vault Search Feed"))
        #expect(editorSource.contains("configureVaultSearchFeed()"))
        #expect(editorSource.contains("package.isStarterTemplateContent"))
        #expect(editorSource.contains("package.applyVaultSearchDashboardTemplate"))
        #expect(editorSource.contains("HTMLWorkspaceDataFeed.vaultSearch"))
        #expect(editorSource.contains("HTMLWorkspaceDataFeedJSONEnvelope.staleDataJSON"))
        #expect(editorSource.contains("package.manifest.dataFeed = nil"))
        #expect(feedSource.contains("VaultSyncService.searchFullAsync"))
        #expect(feedSource.contains("NotificationCenter.default.publisher(for: .searchIndexDidUpdate)"))
        #expect(feedSource.contains("HTMLWorkspaceDataFeedRenderer.staleRender"))
        #expect(feedSource.contains(#""VaultSyncService.searchFullAsync""#))
        #expect(feedSource.contains(#"case epistemos = "_epistemos""#))
        #expect(feedSource.contains("stale: true"))
        #expect(hostSource.contains("HTMLWorkspaceDataFeedStatusStrip(package: package)"))
        #expect(hostSource.contains(".htmlWorkspaceDataFeed(package: packageBinding, statusText: $dataFeedStatusText)"))
        #expect(hostSource.contains("setPackage(newPackage)"))
        #expect(hostSource.contains(".htmlWorkspacePackageDidChange"))
    }

    @Test("PDF export is timeout bounded on the macOS-26 WebPage API (no legacy WebKit NSView host)")
    func pdfExporterHasBoundedLoadAndCleanup() throws {
        let exporterSource = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspacePDFExporter.swift")

        #expect(exporterSource.contains("HTMLWorkspacePDFExportError"))
        #expect(exporterSource.contains("loadTimeoutNanoseconds"))
        #expect(exporterSource.contains("loadTimedOut"))
        // Timeout is a deadline checked as navigation events arrive (the @MainActor WebPage is never handed to a
        // child task, which would trip the region-based isolation checker).
        #expect(exporterSource.contains("ContinuousClock"))
        #expect(exporterSource.contains("deadline"))
        // macOS-26 SwiftUI WebKit migration: `WebPage` + a `NavigationDeciding` scheme allowlist (async policy,
        // not a delegate `decisionHandler`); content-sized PDF via `exported(as: .pdf(region: .rect(…)))`.
        #expect(exporterSource.contains("WebPage"))
        #expect(exporterSource.contains("NavigationDeciding"))
        #expect(exporterSource.contains("return .cancel"))
        #expect(exporterSource.contains("exported(as: .pdf"))
        #expect(exporterSource.contains("height.isFinite"))
        // No legacy WebKit NSView host / delegate / dispatch-after paths survive the migration.
        #expect(!exporterSource.contains("WKWebView"))
        #expect(!exporterSource.contains("navigationDelegate"))
        #expect(!exporterSource.contains("DispatchQueue.main.asyncAfter"))
    }

    @Test("editor exposes data DOM assets and AppKit-backed two-axis source editing")
    func editorExposesDOMDataAssetsAndTwoAxisSourceEditing() throws {
        let editorSource = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        let codeEditorSource = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceCodeEditor.swift")

        #expect(editorSource.contains("case data"))
        #expect(editorSource.contains("case dom"))
        #expect(editorSource.contains("case assets"))
        #expect(editorSource.contains("data.json"))
        #expect(editorSource.contains("DOM Outline"))
        #expect(codeEditorSource.contains("NSViewRepresentable"))
        #expect(codeEditorSource.contains("NSTextView"))
        #expect(codeEditorSource.contains("hasHorizontalScroller = true"))
        #expect(codeEditorSource.contains("widthTracksTextView = false"))
        #expect(codeEditorSource.contains("autoresizingMask = [.height]"))
        #expect(codeEditorSource.contains("LineNumberRulerView"))
        #expect(codeEditorSource.contains("hasVerticalRuler = true"))
        #expect(codeEditorSource.contains("rulersVisible = true"))
        #expect(codeEditorSource.contains("boundsDidChange"))
        #expect(codeEditorSource.contains("context.coordinator.invalidateLineNumbers(rebuild: true)"))
        #expect(codeEditorSource.contains("scrollView.contentView.drawsBackground = false"))
        #expect(codeEditorSource.contains("NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)"))
    }

    @Test("package model uses requested file layout and guards traversal")
    func packageModelUsesMainJSAndPathGuards() throws {
        let packageSource = try loadMirroredSourceTextFile("Epistemos/Models/HTMLWorkspacePackage.swift")

        #expect(packageSource.contains("main.js"))
        #expect(packageSource.contains("data.json"))
        #expect(packageSource.contains("HTMLWorkspaceLocalResourceScheme"))
        #expect(packageSource.contains("contentSecurityPolicySource"))
        #expect(packageSource.contains("HTMLWorkspacePreviewTheme"))
        #expect(packageSource.contains("epistemos-theme-guard"))
        #expect(packageSource.contains("epistemos-font-face"))
        #expect(packageSource.contains("epistemos-theme-host"))
        #expect(packageSource.contains("HTMLWorkspacePreviewFonts"))
        #expect(packageSource.contains("MatrixtypeDisplay-9MyE5"))
        #expect(packageSource.contains("ChonkyPixels"))
        #expect(packageSource.contains("fontDataURL"))
        #expect(packageSource.contains("html[data-epistemos-theme] body :is(h1, h2, .workspace-title, [data-display-title])"))
        #expect(packageSource.contains("font-synthesis: none"))
        #expect(packageSource.contains("data-metric-value"))
        #expect(packageSource.contains("html[data-epistemos-theme] .metric-card strong"))
        #expect(packageSource.contains("background: var(--epistemos-workspace-bg) !important"))
        #expect(packageSource.contains("color: var(--epistemos-workspace-fg) !important"))
        #expect(packageSource.contains("body :is(main, section, article"))
        #expect(packageSource.contains("border-color: var(--epistemos-workspace-border)"))
        #expect(packageSource.contains("legacyScriptJS"))
        #expect(packageSource.contains("validatePackageFileName"))
        #expect(packageSource.contains("case replaceDataJSON"))
        #expect(packageSource.contains("case updateStyleRule"))
        #expect(packageSource.contains("case addAsset"))
        #expect(packageSource.contains("case captureSnapshot"))
        #expect(packageSource.contains("case recordConsoleError"))
        #expect(packageSource.contains("maxManifestBytes"))
        #expect(packageSource.contains("maxAssetCount"))
        #expect(packageSource.contains("maxAssetsTotalBytes"))
        #expect(packageSource.contains("maxSnapshotsTotalBytes"))
        #expect(packageSource.contains("packageLimitExceeded"))
        #expect(packageSource.contains("validateAssets(updated.assets)"))
        #expect(packageSource.contains("validateSnapshots(updated.snapshots)"))
        #expect(packageSource.contains("!name.hasPrefix(\".\")"))
        #expect(packageSource.contains("CharacterSet.controlCharacters"))
        #expect(packageSource.contains("guard child.isRegularFile"))
        #expect(packageSource.contains("HTMLWorkspaceDocumentReplacement"))
        #expect(packageSource.contains("case replaceDocument(HTMLWorkspaceDocumentReplacement)"))
        #expect(packageSource.contains("case setDataFeed(HTMLWorkspaceDataFeed?)"))
        #expect(packageSource.contains(#"error: "Feed pending""#))
    }

    @Test("document surface exposes structured patch hooks without Epdoc internals")
    func documentExposesPatchHooks() throws {
        let documentSource = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspaceDocument.swift")
        let bridgeSource = try loadMirroredSourceTextFile("Epistemos/Engine/EpdocEditorBridge.swift")
        let surfaceSource = try loadMirroredSourceTextFile("Epistemos/Models/DocumentSurface.swift")

        #expect(surfaceSource.contains("struct DocumentSurface"))
        #expect(surfaceSource.contains("enum DocumentSurfaceKind"))
        #expect(surfaceSource.contains("enum DocumentSurfacePane"))
        #expect(surfaceSource.contains("struct DocumentSourceRange"))
        #expect(surfaceSource.contains("enum DocumentSurfaceCapability"))
        #expect(documentSource.contains("applyPatch("))
        #expect(documentSource.contains("chatContextSnapshot("))
        #expect(!documentSource.contains("EpdocDocument"))
        #expect(bridgeSource.contains("epistemos-doc"))
    }

    @Test("document save refuses starter template overwrite of existing workspaces")
    func documentSaveRefusesStarterTemplateOverwrite() throws {
        let documentSource = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspaceDocument.swift")
        let packageSource = try loadMirroredSourceTextFile("Epistemos/Models/HTMLWorkspacePackage.swift")

        #expect(packageSource.contains("isStarterTemplateContent"))
        #expect(documentSource.contains("validateNoStarterTemplateOverwrite"))
        #expect(documentSource.contains("Refusing to overwrite an existing HTML Workspace with the starter template"))
        #expect(documentSource.contains("existingPackage(at: existingFileURL)"))
        #expect(documentSource.contains("!existingPackage.isStarterTemplateContent"))
    }

    @Test("HTML Workspace DOM outline extracts attribute values instead of names")
    func htmlWorkspaceDOMOutlineExtractsAttributeValues() throws {
        let editorSource = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceCodeEditor.swift")

        #expect(editorSource.contains("captureAttribute(\"id\""))
        #expect(editorSource.contains("captureAttribute(\"class\""))
        #expect(editorSource.contains("match.numberOfRanges > 1"))
        #expect(editorSource.contains("Range(match.range(at: 1), in: attributes)"))
        #expect(!editorSource.contains("Range(match.range(at: 2), in: attributes)"))
    }

    @Test("HTML Workspace edits route through structured patch commands")
    func htmlWorkspaceRoutesStructuredPatches() throws {
        let routerSource = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspacePatchRouter.swift")
        let editorSource = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        let chatTypes = try loadMirroredSourceTextFile("Epistemos/Models/ChatTypes.swift")

        #expect(routerSource.contains("epistemos-html-workspace-patch"))
        #expect(routerSource.contains("HTMLWorkspacePatchCommandBatch"))
        #expect(routerSource.contains("expected_content_hash"))
        #expect(routerSource.contains("maxOperations"))
        #expect(routerSource.contains("replaceDataJSON"))
        #expect(routerSource.contains("setDataFeed"))
        #expect(routerSource.contains("case replaceDocument"))
        #expect(routerSource.contains("case regenerate"))
        #expect(routerSource.contains("Full-surface replacement: use replaceDocument/regenerate"))
        #expect(routerSource.contains("Live data operation: setDataFeed"))
        #expect(routerSource.contains("window.webkit.messagehandlers"))
        #expect(routerSource.contains("applyPatchCommands"))
        #expect(routerSource.contains("var visible = response"))
        #expect(routerSource.contains("Allowed Operations:"))
        #expect(routerSource.contains("replaceDocument, regenerate"))
        #expect(editorSource.contains(#""setDataFeed""#))
        #expect(editorSource.contains(#""replaceDocument", "regenerate""#))
        #expect(!routerSource.contains("var visible = parseResult.cleanedText"))
        #expect(chatTypes.contains("surfaceTarget"))
    }

    @Test("new visual creation routes to HTML Workspace, not Mermaid")
    func newVisualCreationRoutesToHTMLWorkspace() throws {
        let slash = try loadMirroredSourceTextFile("js-editor/src/extensions/slash-menu.ts")
        let inbound = try loadMirroredSourceTextFile("js-editor/src/bridge/inbound.ts")
        let outbound = try loadMirroredSourceTextFile("js-editor/src/bridge/outbound.ts")
        let editorIndex = try loadMirroredSourceTextFile("js-editor/src/index.ts")
        let legacyDiagram = try loadMirroredSourceTextFile("js-editor/src/extensions/legacy-diagram-node.ts")
        let editorManifest = try loadMirroredSourceTextFile("js-editor/package.json")
        let webpack = try loadMirroredSourceTextFile("js-editor/webpack.config.js")
        let toolbar = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocEditorToolbar.swift")
        let dock = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocCopilotDockView.swift")
        let bridge = try loadMirroredSourceTextFile("Epistemos/Engine/EpdocEditorBridge.swift")
        let app = try loadMirroredSourceTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(slash.contains("requestHTMLWorkspace"))
        #expect(slash.contains("id: 'html-workspace'"))
        #expect(!slash.contains("insertMermaid"))
        #expect(!slash.contains("RESEARCH_DIAGRAM_TEMPLATES"))
        #expect(!slash.contains("mermaid-flowchart"))
        #expect(!slash.contains("type: 'mermaid'"))
        #expect(!inbound.contains("insertEpdocGraphFromDocument"))
        #expect(outbound.contains("type: 'requestHTMLWorkspace'"))
        #expect(toolbar.contains("openHTMLWorkspace"))
        #expect(!toolbar.contains("insertEpdocGraphFromDocument"))
        #expect(dock.contains("requestHTMLWorkspace"))
        #expect(!dock.contains("insertEpdocGraphFromDocument"))
        #expect(bridge.contains("case requestHTMLWorkspace"))
        #expect(app.contains("New HTML Workspace"))
        #expect(editorIndex.contains("LegacyDiagramNode"))
        #expect(!editorIndex.contains("MermaidNode"))
        #expect(legacyDiagram.contains("Compatibility-only schema node"))
        #expect(legacyDiagram.contains("name: 'mermaid'"))
        #expect(legacyDiagram.contains("data-legacy-diagram"))
        #expect(!legacyDiagram.contains("loadMermaid"))
        #expect(!legacyDiagram.contains("mermaid.min.js"))
        #expect(!repoFileExists("js-editor/src/extensions/mermaid-node.ts"))
        #expect(!editorManifest.contains(#""mermaid":"#))
        #expect(!editorManifest.contains(#""mermaid": "#))
        #expect(!webpack.contains("vendor/mermaid"))
        #expect(!webpack.contains("mermaid.min.js"))
    }
}

@Suite("HTML Workspace DOM outline regressions", .serialized)
// UAS-EXEMPT: source-guard test fixture, not persisted substrate data.
nonisolated struct HTMLWorkspaceDOMOutlineRegressionTests {
    @Test("handles id and class attributes without capture crashes")
    func handlesAttributesWithoutCaptureCrash() {
        let outline = HTMLWorkspaceDOMOutline.outline(
            for: #"<main id="hero" class="workspace shell"><section data-panel="notes"></section></main>"#
        )

        #expect(outline.contains("<main#hero.workspace.shell>"))
        #expect(outline.contains("<section> data"))
    }
}

@Suite("HTML Workspace code editor regressions", .serialized)
// UAS-EXEMPT: source-guard test fixture, not persisted substrate data.
nonisolated struct HTMLWorkspaceCodeEditorRegressionTests {
    @Test("seeds visible text geometry before two-axis source editing")
    func seedsVisibleTextGeometryBeforeTwoAxisSourceEditing() throws {
        let editorSource = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceCodeEditor.swift")

        #expect(editorSource.contains("ensureVisibleTextGeometry(textView: textView, scrollView: scrollView)"))
        #expect(editorSource.contains("HTMLWorkspaceCodeEditor.ensureVisibleTextGeometry(textView: textView, scrollView: scrollView)"))
        #expect(editorSource.contains("let contentSize = NSSize("))
        #expect(editorSource.contains("width: max(scrollView.contentSize.width, scrollView.bounds.width)"))
        #expect(editorSource.contains("height: max(scrollView.contentSize.height, scrollView.bounds.height)"))
        #expect(editorSource.contains("textView.minSize = contentSize"))
        #expect(editorSource.contains("textView.frame.size = NSSize("))
        #expect(editorSource.contains("width: max(textView.frame.width, contentSize.width)"))
        #expect(editorSource.contains("height: max(textView.frame.height, contentSize.height)"))
        #expect(editorSource.contains("applyPlainTextAttributes(to: textView, foreground: palette.foreground)"))
        #expect(editorSource.contains("AppDisplayTypography.monoUIFont(size: 12.5, weight: .regular)"))
        #expect(!editorSource.contains("NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)"))
    }
}
