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
        #expect(previewSource.contains("allowNetwork == false"))
        #expect(previewSource.contains("decisionHandler(.cancel)"))
        #expect(previewSource.contains("allowedNetworkSchemes"))
        #expect(previewSource.contains("\"http\", \"https\""))
        #expect(previewSource.contains("syncSafeAPIHandler"))
        #expect(previewSource.contains("safeAPIEnabled"))
        #expect(previewSource.contains("HTMLWorkspaceSafeAPI.messageHandlerName"))
        #expect(!previewSource.contains("addUserScript("),
                "HTML Workspace preview should not inject app-internal scripts; expose only an explicit safe API.")
    }

    @Test("mini chat can target the active HTML workspace explicitly")
    func miniChatTargetsActiveHTMLWorkspace() throws {
        let chatTypes = try loadMirroredSourceTextFile("Epistemos/Models/ChatTypes.swift")
        let helpers = try loadMirroredSourceTextFile("Epistemos/Views/Chat/NotesMentionDropdown.swift")
        let controller = try loadMirroredSourceTextFile("Epistemos/Views/MiniChat/MiniChatWindowController.swift")

        #expect(chatTypes.contains("case htmlWorkspace"))
        #expect(helpers.contains("htmlWorkspaceAttachment("))
        #expect(helpers.contains("htmlworkspace://"))
        #expect(controller.contains("activeHTMLWorkspaceAttachment()"))
        #expect(controller.contains("resolvedAttachment = activeHTMLWorkspaceAttachment()"))
        #expect(controller.contains("?? activeEpdocAttachment()"),
                "HTML Workspace targeting should be a separate MiniChat context before the legacy Epdoc/file fallback.")
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
        #expect(editorSource.contains("MiniChatWindowController.shared.openNewChat(attaching: workspaceAttachment)"))
        #expect(editorSource.contains("importHTML()"))
        #expect(editorSource.contains("exportHTML()"))
        #expect(editorSource.contains("previewRenderIdentity"))
        #expect(editorSource.contains("currentHTMLWorkspaceDocument()"))
        #expect(editorSource.contains("document.save(nil)"))
        #expect(editorSource.contains(".onChange(of: colorScheme)"))
        #expect(editorSource.contains("DisclosureGroup"))
        #expect(editorSource.contains("Console"))
    }

    @Test("PDF export load path is timeout bounded and cleans up WebKit state")
    func pdfExporterHasBoundedLoadAndCleanup() throws {
        let exporterSource = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspacePDFExporter.swift")

        #expect(exporterSource.contains("HTMLWorkspacePDFExportError"))
        #expect(exporterSource.contains("loadTimeoutNanoseconds"))
        #expect(exporterSource.contains("loadTimeoutTask"))
        #expect(exporterSource.contains("Task.sleep"))
        #expect(exporterSource.contains("finishLoad("))
        #expect(exporterSource.contains("loadTimeoutTask?.cancel()"))
        #expect(exporterSource.contains("webView.navigationDelegate = nil"))
        #expect(exporterSource.contains("height.isFinite"))
        #expect(exporterSource.contains("decisionHandler(.cancel)"))
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
    }

    @Test("vault PDF and text ingestion is bounded before extraction")
    func vaultPDFAndTextIngestionIsBounded() throws {
        let parserSource = try loadMirroredSourceTextFile("Epistemos/KnowledgeFusion/DataIngestion/VaultParser.swift")

        #expect(parserSource.contains("maxTextFileBytes"))
        #expect(parserSource.contains("maxPDFFileBytes"))
        #expect(parserSource.contains("maxPDFPageCount"))
        #expect(parserSource.contains("maxPDFExtractedCharacters"))
        #expect(parserSource.contains("boundedTextFileString"))
        #expect(parserSource.contains("validateFileSize("))
        #expect(parserSource.contains("min(document.pageCount, Self.maxPDFPageCount)"))
        #expect(parserSource.contains("remainingCharacters"))
        #expect(parserSource.contains("case fileTooLarge"))
    }

    @Test("document surface exposes structured chat patch hooks without Epdoc internals")
    func documentExposesChatPatchHooks() throws {
        let documentSource = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspaceDocument.swift")
        let bridgeSource = try loadMirroredSourceTextFile("Epistemos/Engine/EpdocEditorBridge.swift")
        let surfaceSource = try loadMirroredSourceTextFile("Epistemos/Models/DocumentSurface.swift")

        #expect(surfaceSource.contains("struct DocumentSurface"))
        #expect(surfaceSource.contains("struct MiniChatTarget"))
        #expect(surfaceSource.contains("enum DocumentSurfaceKind"))
        #expect(surfaceSource.contains("enum DocumentSurfacePane"))
        #expect(surfaceSource.contains("struct DocumentSourceRange"))
        #expect(surfaceSource.contains("enum DocumentSurfaceCapability"))
        #expect(documentSource.contains("applyPatch("))
        #expect(documentSource.contains("chatContextSnapshot("))
        #expect(!documentSource.contains("EpdocDocument"))
        #expect(bridgeSource.contains("epistemos-doc"))
    }

    @Test("MiniChat routes HTML Workspace edits through structured patch commands")
    func miniChatRoutesHTMLWorkspaceStructuredPatches() throws {
        let routerSource = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspacePatchRouter.swift")
        let miniChatSource = try loadMirroredSourceTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let coordinatorSource = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")
        let chatTypes = try loadMirroredSourceTextFile("Epistemos/Models/ChatTypes.swift")

        #expect(routerSource.contains("epistemos-html-workspace-patch"))
        #expect(routerSource.contains("HTMLWorkspacePatchCommandBatch"))
        #expect(routerSource.contains("expected_content_hash"))
        #expect(routerSource.contains("maxOperations"))
        #expect(routerSource.contains("replaceDataJSON"))
        #expect(routerSource.contains("window.webkit.messagehandlers"))
        #expect(routerSource.contains("applyPatchCommands"))
        #expect(routerSource.contains("var visible = response"))
        #expect(routerSource.contains("MiniChat Target:"))
        #expect(routerSource.contains("Allowed Operations:"))
        #expect(!routerSource.contains("var visible = parseResult.cleanedText"),
                "Applied HTML Workspace patch/code blocks must stay visible in MiniChat after the patch is applied.")
        #expect(chatTypes.contains("surfaceTarget"))
        #expect(miniChatSource.contains("HTMLWorkspacePatchRouter.applyPatchCommands"))
        #expect(miniChatSource.contains("fetchHTMLWorkspaceContext"))
        #expect(coordinatorSource.contains("fetchHTMLWorkspaceContext"))
    }

    @Test("HTML Workspace toolbar exposes source target metadata for MiniChat")
    func editorExposesSourceTargetMetadataForMiniChat() throws {
        let editorSource = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        let chatTypes = try loadMirroredSourceTextFile("Epistemos/Models/ChatTypes.swift")
        let helpers = try loadMirroredSourceTextFile("Epistemos/Views/Chat/NotesMentionDropdown.swift")

        #expect(chatTypes.contains("var surfaceTarget: MiniChatTarget?"))
        #expect(helpers.contains("surfaceTarget: MiniChatTarget? = nil"))
        #expect(helpers.contains("htmlWorkspaceCapabilities"))
        #expect(editorSource.contains("sourceTarget(for: selectedPane)"))
        #expect(editorSource.contains("DocumentSurface("))
        #expect(editorSource.contains("MiniChatTarget("))
        #expect(editorSource.contains("pane.documentSurfacePane"))
        #expect(editorSource.contains("selectedPaneSourceSnippet"))
        #expect(editorSource.contains("copyPatchContext(for: selectedPane)"))
        #expect(editorSource.contains("openMiniChatForCurrentPane()"))
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
