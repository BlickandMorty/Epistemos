import Foundation
import Testing

@testable import Epistemos

@Suite("HTML Workspace full-surface regenerate synthesis")
nonisolated struct HTMLWorkspaceRegeneratePatchSynthesizerTests {
    @Test("regenerate loading preview is transient, escaped, and not persisted as the package")
    func regenerateLoadingPreviewIsTransientEscapedAndNotPersisted() {
        let package = HTMLWorkspacePackage.defaultPackage(title: "Proof")
        let loading = HTMLWorkspaceRegeneratePreview.loadingPackage(
            from: package,
            instruction: "Explain <script>alert(1)</script> as an animated dashboard"
        )

        #expect(loading.manifest.id == package.manifest.id)
        #expect(loading.manifest.title == "Regenerating Proof")
        #expect(loading.manifest.contentHash != package.manifest.contentHash)
        #expect(loading.indexHTML.contains("data-regenerate-preview"))
        #expect(loading.indexHTML.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
        #expect(!loading.indexHTML.contains("<script>alert(1)</script>"))
        #expect(loading.styleCSS.contains("regenerate-preview-pulse"))
        #expect(loading.styleCSS.contains("var(--epistemos-workspace-bg"))
        #expect(loading.styleCSS.contains("var(--epistemos-workspace-card"))
        #expect(loading.styleCSS.contains("var(--epistemos-workspace-accent"))
        #expect(!loading.styleCSS.contains("linear-gradient"))
        #expect(!loading.styleCSS.contains("border: 1px"))
        #expect(loading.scriptJS.isEmpty)
        #expect(loading.dataJSON.contains(#""status":"regenerating""#))
        #expect(loading.routes.isEmpty)
        #expect(loading.assets.isEmpty)
        #expect(package.indexHTML != loading.indexHTML)
    }

    @Test("regenerate loading preview carries selected preview target")
    func regenerateLoadingPreviewCarriesSelectedPreviewTarget() {
        let package = HTMLWorkspacePackage.defaultPackage(title: "Target Proof")
        let loading = HTMLWorkspaceRegeneratePreview.loadingPackage(
            from: package,
            instruction: "Use dropped context",
            selectedSurfaceContext: "selected_surface.selector: section.hero\nselected_surface.text: Hello <b>world</b>"
        )

        #expect(loading.indexHTML.contains("data-regenerate-preview-target"))
        #expect(loading.indexHTML.contains("Targeting selected preview section"))
        #expect(loading.indexHTML.contains("selected_surface.selector: section.hero"))
        #expect(loading.indexHTML.contains("Hello &lt;b&gt;world&lt;/b&gt;"))
        #expect(loading.styleCSS.contains(".regenerate-preview__target"))
        #expect(loading.styleCSS.contains("box-shadow: inset 3px 0 0 var(--epistemos-workspace-accent"))
        #expect(loading.dataJSON.contains(#""selected_surface_context":"selected_surface.selector: section.hero\nselected_surface.text: Hello <b>world</b>""#))
    }

    @Test("regenerate sheet exposes target workspace and hash before replace")
    func regenerateSheetExposesTargetWorkspaceAndHashBeforeReplace() throws {
        let sheet = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceRegenerateSurface.swift")
        let editor = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        let sidebar = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceRegenerateContextSidebar.swift")
        let picker = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspacePreviewContextPicker.swift")

        #expect(sheet.contains("let workspaceID: String"))
        #expect(sheet.contains("let expectedContentHash: String"))
        #expect(sheet.contains("@Binding var streamedText: String"))
        #expect(sheet.contains("@Binding var contextQuery: String"))
        #expect(sheet.contains("@Environment(UIState.self) private var ui"))
        #expect(sheet.contains("let hasPendingPreview: Bool"))
        #expect(sheet.contains("let hasVaultContext: Bool"))
        #expect(sheet.contains("let isRefreshingContext: Bool"))
        #expect(sheet.contains("let contextStatusText: String?"))
        #expect(sheet.contains("let contextItems: [HTMLWorkspaceRegenerateContextItem]"))
        #expect(sheet.contains("let canRestorePreviousSurface: Bool"))
        #expect(sheet.contains("let restoreSnapshotName: String?"))
        #expect(sheet.contains("let onRefreshContext: () -> Void"))
        #expect(sheet.contains("let onClearContext: () -> Void"))
        #expect(sheet.contains("let onFocusContextItem: (HTMLWorkspaceRegenerateContextItem) -> Void"))
        #expect(sheet.contains("let onRunPreset: (HTMLWorkspaceRegeneratePreset) -> Void"))
        #expect(sheet.contains("let onApplyPreview: () -> Void"))
        #expect(sheet.contains("let onRestorePreviousSurface: () -> Void"))
        #expect(sheet.contains("Label(\"Apply Preview\", systemImage: \"checkmark.circle\")"))
        #expect(sheet.contains("Label(\"Revert\", systemImage: \"clock.arrow.circlepath\")"))
        #expect(sheet.contains(".help(restoreSnapshotHelpText)"))
        #expect(sheet.contains("private var restoreSnapshotHelpText: String"))
        #expect(sheet.contains("Revert to snapshot \\(restoreSnapshotName)"))
        #expect(sheet.contains("Label(isRegenerating ? \"Streaming\" : \"Stream Preview\", systemImage: \"wand.and.sparkles\")"))
        #expect(sheet.contains("Label(\"Workspace Context\", systemImage: \"tray.full\")"))
        #expect(sheet.contains("TextField(\"Search notes, PDFs, folders, captures, clips, chats, graph, claims\", text: $contextQuery)"))
        #expect(sheet.contains("Label(isRefreshingContext ? \"Searching\" : \"Add Context\", systemImage: \"magnifyingglass.circle\")"))
        #expect(sheet.contains("HTMLWorkspaceRegenerateContextShortcut.all"))
        #expect(sheet.contains("let onRequestContextShortcut: (HTMLWorkspaceRegenerateContextShortcut) -> Void"))
        #expect(sheet.contains("onRequestContextShortcut(shortcut)"))
        #expect(sheet.contains("Load read-only workspace context for \\(query)"))
        #expect(sheet.contains("nonisolated struct HTMLWorkspaceRegenerateContextShortcut"))
        #expect(sheet.contains("private var pixelCaptionFont: Font"))
        #expect(sheet.contains("private var pixelControlFont: Font"))
        #expect(sheet.contains("private var pixelMicroFont: Font"))
        #expect(sheet.contains(".font(pixelCaptionFont)"))
        #expect(sheet.contains(".font(pixelControlFont)"))
        #expect(sheet.contains(".font(pixelMicroFont)"))
        #expect(sheet.contains(".font(pixelControlFont)\n            .buttonStyle(.plain)\n            .foregroundStyle(theme.resolved.foreground.color)\n            .padding(14)"))
        #expect(sheet.contains(".font(.caption)\n            .buttonStyle(.plain)"))
        #expect(sheet.contains(".font(pixelControlFont)\n            .buttonStyle(.plain)\n\n            ZStack"))
        #expect(!sheet.contains(".buttonStyle(.bordered"))
        #expect(sheet.contains("ForEach(contextItems)"))
        #expect(sheet.contains("Text(item.contextDescriptor)"))
        #expect(sheet.contains("Text(item.rankDescriptor)"))
        #expect(sheet.contains("Text(item.provenanceDescriptor)"))
        #expect(sheet.contains(".onDrag"))
        #expect(sheet.contains("item.dragItemProvider()"))
        #expect(sheet.contains("nonisolated struct HTMLWorkspaceRegenerateContextItem"))
        #expect(sheet.contains("var contextID: String"))
        #expect(sheet.contains("context_id: \\(safeContextID)"))
        #expect(sheet.contains("drop_action: regenerate_preview_context"))
        #expect(sheet.contains("readonly: true"))
        #expect(sheet.contains("static let previewDropUTType = UTType(exportedAs: \"com.epistemos.workspace-context\", conformingTo: .plainText)"))
        #expect(sheet.contains("static var previewDropUTTypes: [UTType]"))
        #expect(sheet.contains("static var previewDropTypeIdentifiers: [String]"))
        #expect(sheet.contains("func dragItemProvider() -> NSItemProvider"))
        #expect(sheet.contains("provider.registerDataRepresentation(forTypeIdentifier: Self.previewDropUTType.identifier"))
        #expect(sheet.contains("static func verifiedPreviewDropPayload(from payload: String) -> String?"))
        #expect(sheet.contains("static func verifiedPreviewDropPayload("))
        #expect(sheet.contains("matching package: HTMLWorkspacePackage"))
        #expect(sheet.contains("items(from: package).contains { $0.contextID == contextID }"))
        #expect(sheet.contains("private static func normalizedPayloadLines(from payload: String) -> [String]"))
        #expect(sheet.contains("hasLinePrefix(\"context_id: context_kind:\""))
        #expect(sheet.contains("hasLinePrefix(\"Provenance: \""))
        #expect(sheet.contains("HTMLWorkspaceRegeneratePreset.Family.allCases"))
        #expect(sheet.contains("FlowLayout(spacing: 6)"))
        #expect(sheet.contains("Label(\"Recovery response fallback\", systemImage: \"terminal\")"))
        #expect(sheet.contains("Label(\"Copy Recovery Prompt\", systemImage: \"doc.on.doc\")"))
        #expect(sheet.contains("Label(\"Preview Recovery Response\", systemImage: \"eye\")"))
        #expect(sheet.contains("Label(\"Apply Recovery Response\", systemImage: \"checkmark.circle\")"))
        #expect(sheet.contains("Paste a saved regenerate response only if live streaming failed."))
        #expect(!sheet.contains("Label(\"Copy Prompt\", systemImage: \"doc.on.doc\")"))
        #expect(!sheet.contains("Label(\"Preview Response\", systemImage: \"eye\")"))
        #expect(!sheet.contains("Label(\"Apply Response\", systemImage: \"checkmark.circle\")"))
        #expect(!sheet.contains("Label(\"Preview Stream\", systemImage: \"eye\")"))
        #expect(!sheet.contains("Label(\"Show Current\", systemImage: \"arrow.uturn.backward.circle\")"))
        #expect(!sheet.contains("Label(\"Apply Stream\", systemImage: \"checkmark.circle\")"))
        #expect(!sheet.contains("Label(isRegenerating ? \"Regenerating\" : \"Regenerate\", systemImage: \"wand.and.sparkles\")"))
        #expect(sheet.contains("let onCopyPrompt: () -> Void"))
        #expect(sheet.contains("let onRestorePreview: () -> Void"))
        #expect(sheet.contains("TextEditor(text: $streamedText)"))
        #expect(sheet.contains(#"Label("Target", systemImage: "scope")"#))
        #expect(sheet.contains("Text(\"\\(workspaceID.prefix(10)) / \\(expectedContentHash.prefix(10))\")"))
        #expect(sheet.contains("MarkdownPreviewSurfaceStyle.flatBackground(for: theme.surfaceVariant(.other))"))
        #expect(sheet.contains(".textFieldStyle(.plain)"))
        #expect(sheet.contains(".foregroundStyle(theme.error)"))
        #expect(!sheet.contains(".textFieldStyle(.roundedBorder)"))
        #expect(!sheet.contains("GroupBox"))
        #expect(!sheet.contains(".foregroundStyle(.red)"))
        #expect(editor.contains("workspaceID: package.manifest.id"))
        #expect(editor.contains("expectedContentHash: package.currentContentHash"))
        #expect(editor.contains("streamedText: $regenerateStreamText"))
        #expect(editor.contains("contextQuery: $regenerateContextQuery"))
        #expect(editor.contains("contextStatusText: regenerateContextStatusLine"))
        #expect(editor.contains("isRefreshingContext: isRefreshingRegenerateContext"))
        #expect(editor.contains("hasPendingPreview: canApplyPendingRegeneratePreview"))
        #expect(editor.contains("hasVaultContext: package.manifest.dataFeed != nil"))
        #expect(editor.contains("contextItems: regenerateContextItems"))
        #expect(editor.contains("private var regenerateContextItems: [HTMLWorkspaceRegenerateContextItem]"))
        #expect(editor.contains("private var canApplyPendingRegeneratePreview: Bool"))
        #expect(editor.contains("pendingRegenerateExpectedContentHash == package.currentContentHash"))
        #expect(editor.contains("private var shouldShowPreviewContextSidebar: Bool"))
        #expect(editor.contains("HTMLWorkspaceRegenerateContextSidebar("))
        #expect(editor.contains("HTMLWorkspacePreviewContextPicker("))
        #expect(editor.contains("shouldShowPreviewContextSidebar"))
        #expect(editor.contains("if shouldShowPreviewContextSidebar"))
        #expect(editor.contains("layoutMode == .preview || regenerateSheetPresented || package.manifest.dataFeed != nil"))
        #expect(editor.contains("onOpenContextSearch: openRegenerateSheet"))
        #expect(editor.contains("onRequestContextShortcut: refreshPreviewContextShortcut"))
        #expect(editor.contains("onPickContextItem: applyPreviewContextItem"))
        #expect(editor.contains("canRestorePreviousSurface: restoreSnapshotName != nil"))
        #expect(editor.contains("restoreSnapshotName: restoreSnapshotName"))
        #expect(editor.contains("private var restoreSnapshotName: String?"))
        #expect(editor.contains("private var restorePreviousSurfaceHelpText: String"))
        #expect(editor.contains(".help(restorePreviousSurfaceHelpText)"))
        #expect(editor.contains("statusText = \"Previous surface restored from \\(name)\""))
        #expect(editor.contains("onCopyPrompt: copyRegeneratePrompt"))
        #expect(editor.contains("onRefreshContext: refreshRegenerateVaultContext"))
        #expect(editor.contains("onClearContext: clearRegenerateVaultContext"))
        #expect(editor.contains("onRequestContextShortcut: refreshPreviewContextShortcut"))
        #expect(editor.contains("onFocusContextItem: focusRegenerateContextItem"))
        #expect(editor.contains("@State private var isPreviewContextDropTargeted = false"))
        #expect(editor.contains("of: HTMLWorkspaceRegenerateContextItem.previewDropUTTypes"))
        #expect(editor.contains("!current.contains(item.contextID)"))
        #expect(editor.contains("if isPreviewContextDropTargeted"))
        #expect(editor.contains("private var previewContextDropOverlay: some View"))
        #expect(editor.contains("Drop context to regenerate"))
        #expect(editor.contains("private var previewContextDropTargetText: String"))
        #expect(editor.contains("onRunPreset: runRegeneratePreset"))
        #expect(editor.contains("onApplyPreview: applyPendingRegeneratePreview"))
        #expect(editor.contains("onPreviewStream: previewRegenerateStreamText"))
        #expect(editor.contains("onApplyStream: applyRegenerateStreamText"))
        #expect(editor.contains("onRestorePreview: restorePreviewAfterRegenerate"))
        #expect(editor.contains("onRestorePreviousSurface: restorePreviousSurface"))
        #expect(editor.contains("Label(\"Revert Surface\", systemImage: \"clock.arrow.circlepath\")"))
        #expect(editor.contains(".help(restorePreviousSurfaceHelpText)"))
        #expect(editor.contains("@State private var regenerateContextQuery = \"\""))
        #expect(editor.contains("@State private var regenerateContextTask: Task<Void, Never>?"))
        #expect(editor.contains("@State private var regenerateContextRefreshNonce = 0"))
        #expect(editor.contains("@State private var pendingRegeneratePatchResponse: String?"))
        #expect(editor.contains("@State private var pendingRegenerateExpectedContentHash: String?"))
        #expect(editor.contains("private var regenerateContextStatusLine: String?"))
        #expect(editor.contains("private func refreshRegenerateVaultContext()"))
        #expect(editor.contains("private func expirePendingRegeneratePreviewIfNeeded(for newPackage: HTMLWorkspacePackage)"))
        #expect(editor.contains("private func stampPackageContentRevision()"))
        #expect(editor.contains("package.manifest.contentHash = package.currentContentHash"))
        #expect(editor.contains("stampPackageContentRevision()"))
        #expect(editor.contains("VaultSyncService.searchFullAsync") || editor.contains("vaultSync.searchFullAsync"))
        #expect(editor.contains("private func clearRegenerateVaultContext()"))
        #expect(editor.contains("package.dataJSON = HTMLWorkspaceDataFeedStatus.clearedDataJSON(from: package.dataJSON)"))
        #expect(editor.contains("private func focusRegenerateContextItem(_ item: HTMLWorkspaceRegenerateContextItem)"))
        #expect(editor.contains("Use this focused read-only workspace context item as a primary source"))
        #expect(editor.contains("Use this focused read-only workspace context item as a primary source; keep provenance visible and do not invent missing details.\n        \\(droppedPreviewTargetDirective())"))
        #expect(editor.contains("boundedDroppedContext(item.dragPayload)"))
        #expect(editor.contains("guard !isRegenerating,\n              !isRefreshingRegenerateContext,\n              isCurrentRegenerateContextItem(item) else"))
        #expect(editor.contains(#"statusText = "Pick a current Epistemos workspace context item""#))
        #expect(editor.components(separatedBy: "regenerateErrorText = nil\n            statusText = \"Pick a current Epistemos workspace context item\"").count >= 3)
        #expect(editor.contains("private func handlePreviewContextDrop(_ providers: [NSItemProvider]) -> Bool"))
        #expect(editor.contains("guard !isRegenerating,\n              !isRefreshingRegenerateContext,\n              let dropProvider = previewContextDropProvider(from: providers) else"))
        #expect(editor.contains("private func previewContextDropProvider(from providers: [NSItemProvider])"))
        #expect(editor.contains("HTMLWorkspaceRegenerateContextItem.previewDropTypeIdentifiers"))
        #expect(editor.contains("private static func previewContextPayload(from item: Any?) -> String?"))
        #expect(editor.contains("Self.previewContextPayload(from: item)"))
        #expect(editor.contains("private func applyDroppedPreviewContext(_ payload: String)"))
        #expect(editor.contains("HTMLWorkspaceRegenerateContextItem.verifiedPreviewDropPayload(from: payload, matching: package)"))
        #expect(editor.contains(#"statusText = "Drop a current Epistemos workspace context item""#))
        #expect(editor.contains("regenerateErrorText = nil\n            statusText = \"Drop a current Epistemos workspace context item\""))
        #expect(editor.contains("Use this dropped read-only context as a primary source"))
        #expect(editor.contains("private func applyPreviewContextItem(_ item: HTMLWorkspaceRegenerateContextItem)"))
        #expect(editor.contains("Use this picked read-only workspace context item as a primary source"))
        #expect(editor.contains("private func isCurrentRegenerateContextItem(_ item: HTMLWorkspaceRegenerateContextItem) -> Bool"))
        #expect(editor.contains("regenerateContextItems.contains { $0.contextID == item.contextID }"))
        #expect(editor.contains("private func refreshPreviewContextShortcut(_ shortcut: HTMLWorkspaceRegenerateContextShortcut)"))
        #expect(editor.contains("regenerateContextQuery = shortcut.query"))
        #expect(editor.contains("refreshRegenerateVaultContext()"))
        #expect(editor.contains("private func startRegenerateWithContextDirective(_ directive: String, status: String)"))
        #expect(editor.contains("private func startRegenerateWithContextDirective(_ directive: String, status: String) {\n        regenerateErrorText = nil"))
        #expect(editor.contains("regenerateContextStatusText = status"))
        #expect(editor.contains("private func droppedPreviewTargetDirective() -> String"))
        #expect(editor.contains("Target: update the selected preview element/section"))
        #expect(editor.contains("Target: update the current preview surface as a whole."))
        #expect(editor.contains("private func selectedRegenerateSurfaceContext() -> String?"))
        #expect(editor.contains("selected_surface.selector"))
        #expect(editor.contains("selected_surface.tag"))
        #expect(editor.contains("selected_surface.classes"))
        #expect(editor.contains("selected_surface.text"))
        #expect(editor.contains("beginRegenerateSurface(instructionOverride: regenerateInstruction)"))
        #expect(editor.contains("private func beginRegenerateSurfaceAttachingContextIfNeeded(instructionOverride: String?)"))
        #expect(editor.contains("private func shouldAttachRegenerateContextBeforeStreaming("))
        #expect(editor.contains("attachRegenerateVaultContext(\n            query: query,\n            requiredContextKind: requiredContextKind,\n            readyStatus: \"Workspace context ready\""))
        #expect(editor.contains("selectedSurfaceContext: selectedRegenerateSurfaceContext()"))
        #expect(editor.contains("HTMLWorkspaceRegeneratePreview.loadingPackage(\n            from: sourcePackage,\n            instruction: instruction,\n            selectedSurfaceContext: selectedRegenerateSurfaceContext()\n        )"))
        #expect(editor.contains("private func runRegeneratePreset(_ preset: HTMLWorkspaceRegeneratePreset)"))
        #expect(editor.contains("if preset.family == .vaultData"))
        #expect(editor.contains("private func runVaultDataRegeneratePreset(_ preset: HTMLWorkspaceRegeneratePreset)"))
        #expect(editor.contains("private func attachRegenerateVaultContext("))
        #expect(editor.contains("continueAfterAttach: (@MainActor () -> Void)? = nil"))
        #expect(editor.contains("requiredContextKind: preset.requiredContextKind"))
        #expect(editor.contains("HTMLWorkspaceDataFeedContextSources.results("))
        #expect(editor.contains("contextResults: contextResults"))
        #expect(editor.contains("beginRegenerateSurfaceAttachingContextIfNeeded(instructionOverride: preset.instruction)"))
        #expect(editor.contains("private func applyPendingRegeneratePreview()"))
        #expect(editor.contains("Regenerate preview is stale because the workspace changed."))
        #expect(editor.contains(#"statusText = "Regenerate preview expired""#))
        #expect(editor.contains("expirePendingRegeneratePreviewIfNeeded(for: newValue)"))
        #expect(editor.contains("clearPendingRegeneratePreview()\n            package = result.package"))
        #expect(editor.contains("pendingRegeneratePatchResponse = patchResponse"))
        #expect(editor.contains(#"statusText = "Regenerate preview ready""#))
        #expect(editor.contains(#"statusText = "Regenerate preview applied; Revert available""#))
        #expect(editor.contains(#"statusText = "Regenerate stream applied; Revert available""#))
        #expect(!editor.contains(#"statusText = "Regenerated surface""#))
        #expect(editor.contains("private func copyRegeneratePrompt()"))
        #expect(editor.contains("HTMLWorkspaceRegeneratePromptBuilder.clipboardPrompt("))
        #expect(editor.contains(#"statusText = "Regenerate recovery prompt copied""#))
        #expect(editor.contains("private func previewRegenerateStreamText()"))
        #expect(editor.contains("private func applyRegenerateStreamText()"))
        #expect(editor.contains("HTMLWorkspaceRegenerateApplication.apply("))
        #expect(editor.contains("HTMLWorkspaceRegeneratePreview.candidatePackage("))
        #expect(sidebar.contains("struct HTMLWorkspaceRegenerateContextSidebar: View"))
        #expect(sidebar.contains("let onRequestContextShortcut: (HTMLWorkspaceRegenerateContextShortcut) -> Void"))
        #expect(sidebar.contains("let onPickContextItem: (HTMLWorkspaceRegenerateContextItem) -> Void"))
        #expect(sidebar.contains("let targetText: String"))
        #expect(sidebar.contains("if !targetText.isEmpty"))
        #expect(sidebar.contains("Text(targetText)"))
        #expect(sidebar.contains("private var sourceShortcutGrid: some View"))
        #expect(sidebar.contains("ForEach(HTMLWorkspaceRegenerateContextShortcut.all)"))
        #expect(sidebar.contains("onRequestContextShortcut(shortcut)"))
        #expect(sidebar.contains("item.dragItemProvider()"))
        #expect(sidebar.contains("Drag into the preview or click to apply context"))
        #expect(sidebar.contains("Text(item.contextDescriptor)"))
        #expect(sidebar.contains("Text(item.rankDescriptor)"))
        #expect(sidebar.contains("Text(item.provenanceDescriptor)"))
        #expect(sidebar.contains("Text(\"Workspace Context\")"))
        #expect(sidebar.contains("private var pixelCaptionFont: Font"))
        #expect(sidebar.contains("private var pixelMicroFont: Font"))
        #expect(sidebar.contains(".font(pixelCaptionFont)"))
        #expect(sidebar.contains(".font(pixelMicroFont)"))
        #expect(editor.contains("targetText: previewContextDropTargetText"))
        #expect(picker.contains("struct HTMLWorkspacePreviewContextPicker: View"))
        #expect(picker.contains("let targetText: String"))
        #expect(picker.contains("if !targetText.isEmpty"))
        #expect(picker.contains("Text(targetText)"))
        #expect(picker.contains("Menu {"))
        #expect(picker.contains("Label(\"Add Context\", systemImage: \"plus.square.on.square\")"))
        #expect(picker.contains("Label(\"Search Context\", systemImage: \"magnifyingglass\")"))
        #expect(picker.contains(".disabled(isRegenerating || isRefreshingContext)"))
        #expect(picker.contains("Label(\"No context attached\", systemImage: \"tray\")"))
        #expect(picker.contains("let onOpenContextSearch: () -> Void"))
        #expect(picker.contains("onOpenContextSearch()"))
        #expect(picker.contains("let onRequestContextShortcut: (HTMLWorkspaceRegenerateContextShortcut) -> Void"))
        #expect(picker.contains("Section(\"Source Families\")"))
        #expect(picker.contains("ForEach(HTMLWorkspaceRegenerateContextShortcut.all)"))
        #expect(picker.contains("onRequestContextShortcut(shortcut)"))
        #expect(picker.contains("let onPickContextItem: (HTMLWorkspaceRegenerateContextItem) -> Void"))
        #expect(picker.contains("onPickContextItem(item)"))
        #expect(picker.contains("item.contextDescriptor"))
        #expect(picker.contains("Text(item.provenanceDescriptor)"))
        #expect(picker.contains("Text(item.rankDescriptor)"))
        #expect(picker.contains("item.systemImage"))
        #expect(picker.contains("Pick read-only context for this preview surface"))
    }

    @Test("context shortcuts expose source families without becoming regenerate presets")
    @MainActor
    func contextShortcutsExposeSourceFamilies() {
        #expect(HTMLWorkspaceRegenerateContextShortcut.all.map(\.title) == [
            "Notes",
            "PDFs",
            "Folders",
            "Captures",
            "Meetings",
            "Web clips",
            "Chats",
            "Related",
            "Claims",
        ])
        #expect(HTMLWorkspaceRegenerateContextShortcut.all.map(\.query) == [
            "notes",
            "pdf notes",
            "folder notes",
            "recent captures",
            "meeting notes",
            "web clips",
            "recent chats",
            "related notes",
            "provenance claims",
        ])
        let kinds = HTMLWorkspaceRegenerateContextShortcut.all
            .map { HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: $0.query) }
        #expect(kinds == [
            "note",
            "pdf_note",
            "folder_note",
            "recent_capture",
            "meeting_note",
            "web_clip",
            "recent_chat",
            "graph_related_note",
            "provenance_claim",
        ])
        #expect(HTMLWorkspaceRegeneratePreset.all.map(\.title).contains("Claims") == false)
    }

    @Test("regenerate presets expose required one-click categories")
    func regeneratePresetsExposeRequiredOneClickCategories() {
        #expect(HTMLWorkspaceRegeneratePreset.presets(in: .layout).map(\.title) == [
            "Dashboard",
            "Landing page",
            "Docs page",
            "Single-column article",
        ])
        #expect(HTMLWorkspaceRegeneratePreset.presets(in: .addThing).map(\.title) == [
            "Add chart",
            "Add search box",
            "Add table",
            "Add nav",
        ])
        #expect(HTMLWorkspaceRegeneratePreset.presets(in: .vaultData).map(\.title) == [
            "Notes -> cards",
            "Recent captures",
            "Related notes",
        ])
        #expect(HTMLWorkspaceRegeneratePreset.all.count == 11)
        #expect(HTMLWorkspaceRegeneratePreset.presets(in: .layout).allSatisfy { $0.instruction.contains("Regenerate") })
        #expect(HTMLWorkspaceRegeneratePreset.presets(in: .vaultData).allSatisfy { $0.instruction.contains("Regenerate") })
    }

    @Test("add-a-thing presets preserve the current surface")
    func addAThingPresetsPreserveCurrentSurface() {
        let addThingInstructions = HTMLWorkspaceRegeneratePreset.presets(in: .addThing).map(\.instruction)

        #expect(addThingInstructions.allSatisfy { $0.contains("Preserve the current surface") })
        #expect(addThingInstructions.allSatisfy { $0.contains("Do not wipe existing sections") })
        #expect(addThingInstructions.allSatisfy { $0.contains("inject") })
    }

    @Test("interactive presets bind controls to real data json records")
    func interactivePresetsBindControlsToRealDataJSONRecords() throws {
        let presets = Dictionary(
            uniqueKeysWithValues: HTMLWorkspaceRegeneratePreset.all.map { ($0.id, $0) }
        )
        let dashboard = try #require(presets["layout-dashboard"])
        let chart = try #require(presets["add-chart"])
        let search = try #require(presets["add-search"])
        let table = try #require(presets["add-table"])
        let nav = try #require(presets["add-nav"])
        let notes = try #require(presets["vault-notes-cards"])

        #expect(dashboard.instruction.contains("data.json provides records"))
        #expect(dashboard.instruction.contains("working local search/filter"))
        #expect(dashboard.instruction.contains("context-kind tabs"))
        #expect(chart.instruction.contains("available data.json records"))
        #expect(chart.instruction.contains("real rank, metric, or count fields"))
        #expect(chart.instruction.contains("source_label/provenance visible"))
        #expect(search.instruction.contains("title, snippet, page_id, source_label, context_kind, and provenance"))
        #expect(table.instruction.contains("page_id, title, snippet, rank, context_kind, source_label, and provenance"))
        #expect(nav.instruction.contains("data.json context_kind groups"))
        #expect(notes.instruction.contains("working local filter/tabs over data.json records"))
    }

    @Test("vault data presets seed specific real context queries")
    func vaultDataPresetsSeedSpecificRealContextQueries() throws {
        let presets = Dictionary(
            uniqueKeysWithValues: HTMLWorkspaceRegeneratePreset.presets(in: .vaultData).map { ($0.id, $0) }
        )
        let notes = try #require(presets["vault-notes-cards"])
        let captures = try #require(presets["vault-recent-captures"])
        let related = try #require(presets["vault-related-notes"])

        #expect(notes.contextQuery(typedQuery: "", packageTitle: "Project Atlas") == "notes Project Atlas")
        #expect(captures.contextQuery(typedQuery: "", packageTitle: "Project Atlas") == "recent captures Project Atlas")
        #expect(related.contextQuery(typedQuery: "", packageTitle: "Project Atlas") == "related notes Project Atlas")
        #expect(captures.contextQuery(typedQuery: " custom captures ", packageTitle: "Project Atlas") == "custom captures")
        #expect(notes.requiredContextKind == "note")
        #expect(captures.requiredContextKind == "recent_capture")
        #expect(related.requiredContextKind == "graph_related_note")
        #expect(notes.helpText.contains(#"context_kind "note""#))
        #expect(captures.helpText.contains(#"context_kind "recent_capture""#))
        #expect(related.helpText.contains(#"context_kind "graph_related_note""#))

        let instruction = captures.instruction(contextQuery: "recent captures Project Atlas")
        #expect(instruction.contains("VaultSyncService.searchFullAsync"))
        #expect(instruction.contains("Use only records present in data.json"))
        #expect(instruction.contains("notes, PDFs/arXiv papers, folders, captures, meeting notes, web clips, chats, provenance claims, or graph-related records"))
        #expect(instruction.contains("working local search/filter"))
        #expect(instruction.contains("context-kind tabs"))
        #expect(instruction.contains("bind them to data.json only"))
        #expect(instruction.contains(#"context_kind "recent_capture""#))
        #expect(instruction.contains("_epistemos.required_context_available"))
        #expect(instruction.contains("instead of relabeling generic vault results"))

        let relatedInstruction = related.instruction(contextQuery: "related notes Project Atlas")
        #expect(relatedInstruction.contains(#"context_kind "graph_related_note""#))
    }

    @Test("regenerate prompt includes verified data feed context and honest degradation")
    func regeneratePromptIncludesVerifiedDataFeedContextAndHonestDegradation() {
        var package = HTMLWorkspacePackage.defaultPackage(title: "Context Proof")
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "substrate provenance", limit: 2)
        package.manifest.dataFeed = feed
        package.dataJSON = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            results: [
                SearchResult(
                    pageId: "page-1",
                    title: "Research Note",
                    snippet: "substrate provenance witness",
                    rank: 0.87
                )
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_000),
            requiredContextKind: "recent_capture"
        )

        let prompt = HTMLWorkspaceRegeneratePromptBuilder.prompt(
            instruction: "Turn notes into cards",
            package: package,
            expectedContentHash: contentHash(for: package)
        )

        #expect(prompt.contains("Verified Epistemos context:"))
        #expect(prompt.contains("vault_search.query: substrate provenance"))
        #expect(prompt.contains("vault_search.context_kinds: vault_record"))
        #expect(prompt.contains("vault_search.required_context_kind: recent_capture"))
        #expect(prompt.contains("vault_search.required_context_available: false"))
        #expect(prompt.contains("vault_search.provenance: VaultSyncService.searchFullAsync"))
        #expect(prompt.contains("vault_search.results:\n- record:"))
        #expect(prompt.contains("  context_id: context_kind:vault_record|source:Vault search result|page_id:page-1"))
        #expect(prompt.contains("  page_id: page-1"))
        #expect(prompt.contains("  title: Research Note"))
        #expect(prompt.contains("  context_kind: vault_record"))
        #expect(prompt.contains("  source_label: Vault search result"))
        #expect(prompt.contains("  provenance: VaultSyncService.searchFullAsync"))
        #expect(prompt.contains("  rank: 0.8700"))
        #expect(prompt.contains("  snippet: substrate provenance witness"))
        #expect(prompt.contains("record_display_rule: show each attached record's source_label, context_kind, and provenance"))
        #expect(prompt.contains("grounding_rule: preserve real data provenance"))
        #expect(prompt.contains("fake_data_rule: do not create demo, sample, placeholder, mock, or synthetic records"))

        let emptyPrompt = HTMLWorkspaceRegeneratePromptBuilder.prompt(
            instruction: "Use related notes",
            package: HTMLWorkspacePackage.defaultPackage(title: "No Context"),
            expectedContentHash: "hash"
        )
        #expect(emptyPrompt.contains("vault_search: not attached"))
        #expect(emptyPrompt.contains("do not invent vault notes, PDFs/arXiv papers, folders, graph links, captures, meeting notes, web clips, chats, or provenance claims"))
    }

    @Test("regenerate context items decode feed results as draggable read-only sources")
    func regenerateContextItemsDecodeFeedResultsAsDraggableReadOnlySources() {
        var package = HTMLWorkspacePackage.defaultPackage(title: "Drag Context")
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "drag context", limit: 2)
        package.manifest.dataFeed = feed
        package.dataJSON = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            results: [
                SearchResult(pageId: "note-a", title: "Alpha Note", snippet: "alpha snippet", rank: 0.9),
                SearchResult(pageId: "note-b", title: "Beta Note", snippet: "beta snippet", rank: 0.7),
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )

        let items = HTMLWorkspaceRegenerateContextItem.items(from: package)

        #expect(items.map(\.pageID) == ["note-a", "note-b"])
        #expect(items.first?.id == "context_kind:vault_record|source:Vault search result|page_id:note-a")
        #expect(items.first?.contextID == "context_kind:vault_record|source:Vault search result|page_id:note-a")
        #expect(items.first?.title == "Alpha Note")
        #expect(items.first?.contextKind == "vault_record")
        #expect(items.first?.sourceLabel == "Vault search result")
        #expect(items.first?.provenance == "VaultSyncService.searchFullAsync")
        #expect(items.first?.contextDescriptor == "Vault search result / vault_record")
        #expect(items.first?.provenanceDescriptor == "via VaultSyncService.searchFullAsync")
        #expect(items.first?.rankDescriptor == "rank 0.9000")
        #expect(items.first?.systemImage == "doc.text")
        #expect(HTMLWorkspaceRegenerateContextItem.previewDropTypeIdentifiers.first == "com.epistemos.workspace-context")
        #expect(HTMLWorkspaceRegenerateContextItem.previewDropTypeIdentifiers.contains("public.plain-text"))
        #expect(items.first?.dragPayload.contains("Workspace context: Alpha Note [note-a]") == true)
        #expect(items.first?.dragPayload.contains("context_id: context_kind:vault_record|source:Vault search result|page_id:note-a") == true)
        #expect(items.first?.dragPayload.contains("drop_action: regenerate_preview_context") == true)
        #expect(items.first?.dragPayload.contains("readonly: true") == true)
        #expect(items.first?.dragPayload.contains("page_id: note-a") == true)
        #expect(items.first?.dragPayload.contains("title: Alpha Note") == true)
        #expect(items.first?.dragPayload.contains("context_kind: vault_record") == true)
        #expect(items.first?.dragPayload.contains("source_label: Vault search result") == true)
        #expect(items.first?.dragPayload.contains("rank: 0.9000") == true)
        #expect(items.first?.dragPayload.contains("Source: Vault search result / vault_record") == true)
        #expect(items.first?.dragPayload.contains("Provenance: VaultSyncService.searchFullAsync") == true)
        #expect(items.first?.dragPayload.contains("snippet: alpha snippet") == true)
        #expect(items.first?.dragItemProvider().hasItemConformingToTypeIdentifier("com.epistemos.workspace-context") == true)
        #expect(HTMLWorkspaceRegenerateContextItem.verifiedPreviewDropPayload(from: items.first?.dragPayload ?? "") == items.first?.dragPayload.trimmingCharacters(in: .whitespacesAndNewlines))
        #expect(HTMLWorkspaceRegenerateContextItem.verifiedPreviewDropPayload(from: items.first?.dragPayload ?? "", matching: package) == items.first?.dragPayload.trimmingCharacters(in: .whitespacesAndNewlines))
        #expect(HTMLWorkspaceRegenerateContextItem.verifiedPreviewDropPayload(from: items.first?.dragPayload ?? "", matching: .defaultPackage()) == nil)
        #expect(HTMLWorkspaceRegenerateContextItem.verifiedPreviewDropPayload(from: "random pasted text") == nil)
        #expect(HTMLWorkspaceRegenerateContextItem.verifiedPreviewDropPayload(from: items.first?.dragPayload.replacingOccurrences(of: "readonly: true", with: "readonly: false") ?? "") == nil)
        #expect(HTMLWorkspaceRegenerateContextItem.items(from: .defaultPackage()).isEmpty)
    }

    @Test("regenerate context items require a manifest feed matching data json")
    func regenerateContextItemsRequireMatchingFeedEnvelope() {
        let attachedFeed = HTMLWorkspaceDataFeed.vaultSearch(query: "attached context", limit: 2)
        let staleFeed = HTMLWorkspaceDataFeed.vaultSearch(query: "stale context", limit: 2)
        let wrongLimitFeed = HTMLWorkspaceDataFeed.vaultSearch(query: "attached context", limit: 4)
        var package = HTMLWorkspacePackage.defaultPackage(title: "Mismatched Context")
        package.manifest.dataFeed = attachedFeed
        package.dataJSON = HTMLWorkspaceDataFeedRenderer.render(
            feed: staleFeed,
            results: [
                SearchResult(pageId: "note-a", title: "Alpha Note", snippet: "alpha snippet", rank: 0.9),
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_003)
        )

        #expect(HTMLWorkspaceRegenerateContextItem.items(from: package).isEmpty)

        let prompt = HTMLWorkspaceRegeneratePromptBuilder.prompt(
            instruction: "Use attached context",
            package: package,
            expectedContentHash: "hash"
        )
        #expect(prompt.contains("vault_search.query: attached context"))
        #expect(prompt.contains("vault_search.status: missing or mismatched data.json envelope"))
        #expect(!prompt.contains("title: Alpha Note"))

        package.dataJSON = HTMLWorkspaceDataFeedRenderer.render(
            feed: wrongLimitFeed,
            results: [
                SearchResult(pageId: "note-b", title: "Beta Note", snippet: "beta snippet", rank: 0.8),
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_004)
        )
        #expect(HTMLWorkspaceRegenerateContextItem.items(from: package).isEmpty)

        package.manifest.dataFeed = nil
        #expect(HTMLWorkspaceRegenerateContextItem.items(from: package).isEmpty)
    }

    @Test("regenerate context items bound oversized UI and drag payload text")
    func regenerateContextItemsBoundOversizedUIAndDragPayloadText() throws {
        var package = HTMLWorkspacePackage.defaultPackage(title: "Bound Context")
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "bound context", limit: 1)
        let oversized = String(repeating: "x", count: 1_200)
        package.manifest.dataFeed = feed
        package.dataJSON = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            results: [
                SearchResult(pageId: oversized, title: oversized, snippet: oversized, rank: 1.0),
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_002)
        )

        let item = try #require(HTMLWorkspaceRegenerateContextItem.items(from: package).first)

        #expect(item.pageID.count == 120)
        #expect(item.title.count == 160)
        #expect(item.snippet.count == 360)
        #expect(item.pageID.hasSuffix("..."))
        #expect(item.title.hasSuffix("..."))
        #expect(item.snippet.hasSuffix("..."))
        #expect(item.dragPayload.count < 1_080)
    }

    @Test("regenerate context items pick icons from explicit context kind only")
    func regenerateContextItemsPickIconsFromExplicitContextKindOnly() {
        let capture = HTMLWorkspaceRegenerateContextItem(
            pageID: "capture-1",
            title: "Capture",
            snippet: "captured text",
            rank: 1,
            contextKind: "recent_capture",
            sourceLabel: "Recent capture",
            provenance: "CaptureStore"
        )
        let graph = HTMLWorkspaceRegenerateContextItem(
            pageID: "capture-1",
            title: "Graph",
            snippet: "related text",
            rank: 1,
            contextKind: "graph_related_note",
            sourceLabel: "Graph related note",
            provenance: "GraphState"
        )
        let claim = HTMLWorkspaceRegenerateContextItem(
            pageID: "packet-1",
            title: "Claim",
            snippet: "claim text",
            rank: 1,
            contextKind: "provenance_claim",
            sourceLabel: "Provenance claim",
            provenance: "AnswerPacketStore"
        )

        #expect(capture.systemImage == "tray.full")
        #expect(graph.systemImage == "point.3.connected.trianglepath.dotted")
        #expect(claim.systemImage == "checkmark.shield")
        #expect(HTMLWorkspaceRegenerateContextPresentation.systemImage(for: "pdf_note") == "doc.richtext")
        #expect(HTMLWorkspaceRegenerateContextPresentation.systemImage(for: "meeting_note") == "person.2")
        #expect(HTMLWorkspaceRegenerateContextPresentation.systemImage(for: "web_clip") == "globe")
        #expect(capture.pageID == graph.pageID)
        #expect(capture.id != graph.id)
        #expect(capture.contextDescriptor == "Recent capture / recent_capture")
        #expect(graph.provenanceDescriptor == "via GraphState")
    }

    @Test("regenerate preview package swaps reset stale route selection")
    func regeneratePreviewPackageSwapsResetStaleRouteSelection() throws {
        let editor = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")

        #expect(editor.contains("previewRouteName = nil\n        previewPackage = HTMLWorkspaceRegeneratePreview.loadingPackage("))
        #expect(editor.contains("previewRouteName = nil\n        previewPackage = candidate"))
        #expect(editor.contains("previewRouteName = nil\n        liveDOMSnapshot = nil\n        previewPackage = package"))
        #expect(editor.contains("previewRouteName = nil\n            previewPackage = result.package"))
        #expect(editor.components(separatedBy: "previewRouteName = nil").count >= 5)
    }

    @Test("context and feed mutations invalidate pending regenerate previews")
    func contextAndFeedMutationsInvalidatePendingRegeneratePreviews() throws {
        let editor = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        let refreshStart = try #require(editor.range(of: "private func refreshRegenerateVaultContext()"))
        let attachContextStart = try #require(editor.range(of: "private func attachRegenerateVaultContext"))
        let clearStart = try #require(editor.range(of: "private func clearRegenerateVaultContext()"))
        let focusStart = try #require(editor.range(of: "private func focusRegenerateContextItem"))
        let presetStart = try #require(editor.range(of: "private func runVaultDataRegeneratePreset"))
        let attachStart = try #require(editor.range(of: "private func attachStandaloneRegenerateContext"))
        let configureStart = try #require(editor.range(of: "private func configureVaultSearchFeed()"))
        let clearFeedStart = try #require(editor.range(of: "private func clearVaultSearchFeed()"))
        let clearConsoleStart = try #require(editor.range(of: "private func clearConsole()"))
        let restoreStart = try #require(editor.range(of: "private func restorePreviousSurface()"))
        let bridgeStart = try #require(editor.range(of: "private func testAppBridge()"))
        let refresh = String(editor[refreshStart.lowerBound..<attachContextStart.lowerBound])
        let attachContext = String(editor[attachContextStart.lowerBound..<clearStart.lowerBound])
        let clearContext = String(editor[clearStart.lowerBound..<focusStart.lowerBound])
        let preset = String(editor[presetStart.lowerBound..<attachStart.lowerBound])
        let configureFeed = String(editor[configureStart.lowerBound..<clearFeedStart.lowerBound])
        let clearFeed = String(editor[clearFeedStart.lowerBound..<clearConsoleStart.lowerBound])
        let restore = String(editor[restoreStart.lowerBound..<bridgeStart.lowerBound])

        #expect(refresh.contains("attachRegenerateVaultContext("))
        #expect(preset.contains("attachRegenerateVaultContext("))
        for body in [attachContext, clearContext, configureFeed, clearFeed, restore] {
            #expect(body.contains("clearPendingRegeneratePreview()"))
        }
        #expect(restore.contains("previewRouteName = nil"))
        #expect(restore.contains("regenerateErrorText = nil"))
        #expect(editor.contains("expirePendingRegeneratePreviewIfNeeded(for: newValue)"))
        #expect(editor.contains("guard let expected = pendingRegenerateExpectedContentHash,\n              expected != newPackage.currentContentHash else { return }"))
        #expect(editor.contains("regenerateErrorText = \"Regenerate preview is stale because the workspace changed.\""))
        #expect(editor.contains(#"statusText = "Regenerate preview expired""#))
    }

    @Test("copyable regenerate prompt includes system prompt and target hash")
    func copyableRegeneratePromptIncludesSystemPromptAndTargetHash() {
        let package = HTMLWorkspacePackage.defaultPackage(title: "Prompt Proof")
        let expectedHash = contentHash(for: package)
        let prompt = HTMLWorkspaceRegeneratePromptBuilder.clipboardPrompt(
            instruction: "Turn this into a live explainer",
            package: package,
            expectedContentHash: expectedHash
        )

        #expect(prompt.contains("System:"))
        #expect(prompt.contains(HTMLWorkspaceRegeneratePromptBuilder.systemPrompt))
        #expect(prompt.contains("User:"))
        #expect(prompt.contains("Regenerate this HTML Workspace as one complete live site."))
        #expect(prompt.contains("id: \(package.manifest.id)"))
        #expect(prompt.contains("expected_content_hash: \(expectedHash)"))
        #expect(prompt.contains("do not create a route named assets"))
        #expect(prompt.contains("routes/assets/<name>"))
        #expect(prompt.contains("Turn this into a live explainer"))
        #expect(prompt.contains("Selected preview context:"))
        #expect(prompt.contains("in-surface add-context picker/filter"))
        #expect(prompt.contains("picking a record should visibly add/pin that real record into the workspace"))
        #expect(prompt.contains("section-level context drop zones"))
        #expect(prompt.contains("unmatched drops must show an honest unavailable status"))
        #expect(prompt.contains("When selected preview context is present"))
        #expect(prompt.contains("Each data.json result carries page_id, title, snippet, rank, context_kind, source_label, and provenance."))
        #expect(prompt.contains("_epistemos.required_context_kind"))
        #expect(prompt.contains("_epistemos.required_context_available is false"))
        #expect(prompt.contains("Never create demo, sample, placeholder, mock, or synthetic data records."))
        #expect(prompt.contains("Do not infer captures, chats, graph links, folders, provenance claims, or record types from a title or query string."))
    }

    @Test("regenerate prompt includes selected preview surface context when present")
    func regeneratePromptIncludesSelectedPreviewSurfaceContextWhenPresent() {
        let package = HTMLWorkspacePackage.defaultPackage(title: "Selected Surface")
        let expectedHash = contentHash(for: package)
        let selectedContext = """
        selected_surface.selector: section.hero
        selected_surface.tag: section
        selected_surface.classes: hero, featured
        selected_surface.text: Opening statement
        """

        let prompt = HTMLWorkspaceRegeneratePromptBuilder.prompt(
            instruction: "Improve selected section",
            package: package,
            expectedContentHash: expectedHash,
            selectedSurfaceContext: selectedContext
        )
        let recovery = HTMLWorkspaceRegeneratePromptBuilder.clipboardPrompt(
            instruction: "Improve selected section",
            package: package,
            expectedContentHash: expectedHash,
            selectedSurfaceContext: selectedContext
        )

        #expect(prompt.contains("Selected preview context:"))
        #expect(prompt.contains("selected_surface.selector: section.hero"))
        #expect(prompt.contains("selected_surface.classes: hero, featured"))
        #expect(prompt.contains("selected_surface.text: Opening statement"))
        #expect(recovery.contains("selected_surface.selector: section.hero"))
    }

    @Test("complete streamed regenerate response can preview before final apply")
    func completeStreamedRegenerateResponseCanPreviewBeforeFinalApply() throws {
        let package = HTMLWorkspacePackage.defaultPackage(title: "Preview Source")
        let expectedHash = contentHash(for: package)
        let streamedResponse = """
        ```html
        <main id="stream-preview-proof"><h1>Streaming Preview Proof</h1></main>
        ```
        ```css
        #stream-preview-proof { display: grid; }
        ```
        ```javascript
        document.body.dataset.streamPreview = 'true';
        ```
        ```json
        {"preview":true}
        ```
        """

        let preview = try #require(HTMLWorkspaceRegeneratePreview.candidatePackage(
            from: streamedResponse,
            basePackage: package,
            expectedContentHash: expectedHash
        ))

        #expect(preview.indexHTML.contains("Streaming Preview Proof"))
        #expect(preview.styleCSS.contains("display: grid"))
        #expect(preview.scriptJS.contains("streamPreview"))
        #expect(preview.dataJSON == #"{"preview":true}"#)
        #expect(preview.manifest.id == package.manifest.id)
        #expect(preview.manifest.generationProvenance?.operation == .regenerate)
        #expect(preview.manifest.generationProvenance?.reversibleSnapshotName == HTMLWorkspacePatchApplier.reversibleSnapshotName(for: package))
        #expect(package.indexHTML != preview.indexHTML)
    }

    @Test("incomplete or wrong-target stream does not update the preview candidate")
    func incompleteOrWrongTargetStreamDoesNotUpdatePreviewCandidate() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let expectedHash = contentHash(for: package)
        let incompleteResponse = """
        ```html
        <main><h1>Only HTML So Far</h1></main>
        ```
        """

        #expect(HTMLWorkspaceRegeneratePreview.candidatePackage(
            from: incompleteResponse,
            basePackage: package,
            expectedContentHash: expectedHash
        ) == nil)

        let replacement = HTMLWorkspaceDocumentReplacement(
            title: "Wrong Workspace",
            html: "<main><h1>Wrong Workspace</h1></main>",
            css: "main { display: grid; }",
            js: "",
            dataJSON: "{}",
            provenanceOperation: .regenerate
        )
        let batch = HTMLWorkspacePatchCommandBatch(
            workspaceID: "not-\(package.manifest.id)",
            expectedContentHash: expectedHash,
            operations: [.replaceDocument(replacement)]
        )
        let data = try JSONEncoder.epdocCanonical.encode(batch)
        let wrongWorkspaceResponse = """
        ```epistemos-html-workspace-patch
        \(String(decoding: data, as: UTF8.self))
        ```
        """

        #expect(HTMLWorkspaceRegeneratePreview.candidatePackage(
            from: wrongWorkspaceResponse,
            basePackage: package,
            expectedContentHash: expectedHash
        ) == nil)
    }

    @Test("streamed Goose fenced blocks synthesize and apply a regenerate replacement")
    func streamedGooseFencedBlocksSynthesizeAndApplyRegenerateReplacement() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let expectedHash = contentHash(for: package)
        let streamedResponse = """
        Rebuilt the workspace as requested.

        ```html
        <main id="regenerate-proof"><h1>Regenerate Proof</h1></main>
        ```

        ```css
        #regenerate-proof { display: grid; gap: 12px; }
        ```

        ```javascript
        document.body.dataset.regenerated = 'true';
        ```

        ```json
        {"regenerated":true,"count":45}
        ```
        """

        let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
            from: streamedResponse,
            package: package,
            expectedContentHash: expectedHash
        )
        let parsed = try HTMLWorkspacePatchCommandParser.parse(patchResponse)

        let batch = try #require(parsed.batches.first)
        #expect(batch.workspaceID == package.manifest.id)
        #expect(batch.expectedContentHash == expectedHash)

        let operation = try #require(batch.operations.first)
        let replacement = try extractReplacement(from: operation)
        #expect(replacement.provenanceOperation == .regenerate)
        #expect(replacement.html.contains("Regenerate Proof"))
        #expect(replacement.css.contains("display: grid"))
        #expect(replacement.js.contains("dataset.regenerated"))
        #expect(replacement.dataJSON.contains(#""count":45"#))

        let updated = try HTMLWorkspacePatchApplier.apply(operation.patchOperation(), to: package)
        #expect(updated.indexHTML == replacement.html)
        #expect(updated.styleCSS == replacement.css)
        #expect(updated.scriptJS == replacement.js)
        #expect(updated.dataJSON == replacement.dataJSON)
        #expect(updated.manifest.generationProvenance?.operation == .regenerate)
    }

    @Test("regenerate application applies one full-surface replacement to the visible package")
    func regenerateApplicationAppliesVisiblePackageReplacement() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let expectedHash = contentHash(for: package)
        let streamedResponse = """
        ```html
        <main id="visible-regenerate-proof"><h1>Visible Regenerate Proof</h1></main>
        ```
        ```css
        #visible-regenerate-proof { min-height: 100vh; }
        ```
        ```javascript
        document.body.dataset.visibleRegenerate = 'true';
        ```
        ```json
        {"visible":true}
        ```
        """
        let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
            from: streamedResponse,
            package: package,
            expectedContentHash: expectedHash
        )

        let result = try HTMLWorkspaceRegenerateApplication.apply(
            patchResponse,
            to: package,
            expectedContentHash: expectedHash
        )

        #expect(result.appliedOperations == 1)
        #expect(result.package.indexHTML.contains("Visible Regenerate Proof"))
        #expect(result.package.styleCSS.contains("min-height: 100vh"))
        #expect(result.package.scriptJS.contains("visibleRegenerate"))
        #expect(result.package.dataJSON == #"{"visible":true}"#)
        #expect(result.package.manifest.generationProvenance?.operation == .regenerate)
        #expect(result.package.manifest.generationProvenance?.reversibleSnapshotName == HTMLWorkspacePatchApplier.reversibleSnapshotName(for: package))
    }

    @Test("regenerate application refuses stale current package before overwriting")
    func regenerateApplicationRefusesStaleCurrentPackage() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let expectedHash = contentHash(for: package)
        let streamedResponse = """
        ```html
        <main><h1>Stale Proof</h1></main>
        ```
        ```css
        main { display: block; }
        ```
        ```javascript
        document.body.dataset.staleProof = 'true';
        ```
        ```json
        {"stale":false}
        ```
        """
        let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
            from: streamedResponse,
            package: package,
            expectedContentHash: expectedHash
        )
        var editedPackage = package
        editedPackage.indexHTML += "\n<section>User edit while Goose streamed.</section>"

        #expect(throws: HTMLWorkspaceRegenerateApplicationError.self) {
            _ = try HTMLWorkspaceRegenerateApplication.apply(
                patchResponse,
                to: editedPackage,
                expectedContentHash: expectedHash
            )
        }
    }

    @Test("returned replaceDocument patch block is normalized to regenerate provenance")
    func returnedReplaceDocumentPatchBlockIsNormalizedToRegenerateProvenance() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let expectedHash = contentHash(for: package)
        let routeReplacement = ["about.html": "<main><h1>About Regenerate</h1></main>"]
        let assetReplacement = ["hero.txt": Data("asset regenerate proof".utf8)]
        let sourceReplacement = HTMLWorkspaceDocumentReplacement(
            title: "Patch Block Proof",
            html: "<main><h1>Patch Block Proof</h1></main>",
            css: "main { color: rebeccapurple; }",
            js: "document.body.dataset.patchBlock = 'true';",
            dataJSON: #"{"patchBlock":true}"#,
            routes: routeReplacement,
            assets: assetReplacement,
            provenanceOperation: .replaceDocument
        )
        let batch = HTMLWorkspacePatchCommandBatch(
            workspaceID: package.manifest.id,
            expectedContentHash: expectedHash,
            operations: [.replaceDocument(sourceReplacement)]
        )
        let data = try JSONEncoder.epdocCanonical.encode(batch)
        let response = """
        ```epistemos-html-workspace-patch
        \(String(decoding: data, as: UTF8.self))
        ```
        """

        let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
            from: response,
            package: package,
            expectedContentHash: expectedHash
        )
        let parsed = try HTMLWorkspacePatchCommandParser.parse(patchResponse)
        let operation = try #require(parsed.batches.first?.operations.first)
        let synthesizedReplacement = try extractReplacement(from: operation)

        #expect(synthesizedReplacement.title == "Patch Block Proof")
        #expect(synthesizedReplacement.provenanceOperation == .regenerate)
        #expect(synthesizedReplacement.routes == routeReplacement)
        #expect(synthesizedReplacement.assets == assetReplacement)
    }

    @Test("returned patch block workspace and hash metadata survive synthesis")
    func returnedPatchBlockWorkspaceAndHashMetadataSurviveSynthesis() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let replacement = HTMLWorkspaceDocumentReplacement(
            html: "<main><h1>Wrong Target Proof</h1></main>",
            css: "main { display: grid; }",
            js: "",
            dataJSON: "{}",
            provenanceOperation: .regenerate
        )
        let batch = HTMLWorkspacePatchCommandBatch(
            workspaceID: "wrong-workspace",
            expectedContentHash: "wrong-hash",
            operations: [.replaceDocument(replacement)]
        )
        let data = try JSONEncoder.epdocCanonical.encode(batch)
        let response = """
        ```epistemos-html-workspace-patch
        \(String(decoding: data, as: UTF8.self))
        ```
        """

        let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
            from: response,
            package: package,
            expectedContentHash: contentHash(for: package)
        )
        let parsed = try HTMLWorkspacePatchCommandParser.parse(patchResponse)

        #expect(parsed.batches.first?.workspaceID == "wrong-workspace")
        #expect(parsed.batches.first?.expectedContentHash == "wrong-hash")
        #expect(throws: HTMLWorkspaceRegenerateApplicationError.self) {
            _ = try HTMLWorkspaceRegenerateApplication.apply(
                patchResponse,
                to: package,
                expectedContentHash: contentHash(for: package)
            )
        }
    }

    @Test("returned patch block may use tolerant fence labels")
    func returnedPatchBlockMayUseTolerantFenceLabels() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let expectedHash = contentHash(for: package)
        let replacement = HTMLWorkspaceDocumentReplacement(
            title: "Tolerant Fence",
            html: "<main><h1>Tolerant Fence Proof</h1></main>",
            css: "main { display: grid; }",
            js: "",
            dataJSON: "{}",
            provenanceOperation: .replaceDocument
        )
        let batch = HTMLWorkspacePatchCommandBatch(
            workspaceID: package.manifest.id,
            expectedContentHash: expectedHash,
            operations: [.replaceDocument(replacement)]
        )
        let data = try JSONEncoder.epdocCanonical.encode(batch)
        let response = """
        ```EPISTEMOS-HTML-WORKSPACE-PATCH json
        \(String(decoding: data, as: UTF8.self))
        ```
        """

        let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
            from: response,
            package: package,
            expectedContentHash: expectedHash
        )
        let preview = try #require(HTMLWorkspaceRegeneratePreview.candidatePackage(
            from: patchResponse,
            basePackage: package,
            expectedContentHash: expectedHash
        ))

        #expect(preview.manifest.title == "Tolerant Fence")
        #expect(preview.indexHTML.contains("Tolerant Fence Proof"))
    }

    @Test("returned patch block must be exactly one full-surface replacement")
    func returnedPatchBlockMustBeExactlyOneFullSurfaceReplacement() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let expectedHash = contentHash(for: package)
        let sourceReplacement = HTMLWorkspaceDocumentReplacement(
            html: "<main><h1>Extra Operation Proof</h1></main>",
            css: "main { display: grid; }",
            js: "document.body.dataset.extraOperation = 'true';",
            dataJSON: #"{"extraOperation":true}"#,
            provenanceOperation: .regenerate
        )
        let batch = HTMLWorkspacePatchCommandBatch(
            workspaceID: package.manifest.id,
            expectedContentHash: expectedHash,
            operations: [
                .replaceDocument(sourceReplacement),
                .replaceCSS("body { color: red; }"),
            ]
        )
        let data = try JSONEncoder.epdocCanonical.encode(batch)
        let response = """
        ```epistemos-html-workspace-patch
        \(String(decoding: data, as: UTF8.self))
        ```
        """

        #expect(throws: HTMLWorkspaceRegeneratePatchSynthesizer.Error.self) {
            _ = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
                from: response,
                package: package,
                expectedContentHash: expectedHash
            )
        }
    }

    private func extractReplacement(from operation: HTMLWorkspacePatchCommand) throws -> HTMLWorkspaceDocumentReplacement {
        guard case .replaceDocument(let replacement) = operation else {
            throw RegeneratePatchSynthesizerTestError.expectedReplaceDocument
        }
        return replacement
    }

    private func contentHash(for package: HTMLWorkspacePackage) -> String {
        package.currentContentHash
    }
}

private enum RegeneratePatchSynthesizerTestError: Error {
    case expectedReplaceDocument
}
