import AppKit
import SwiftData
import Testing
import SwiftUI
@testable import Epistemos

private final class LayoutNotificationCounts: Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var frameCount = 0
    nonisolated(unsafe) private var boundsCount = 0

    nonisolated func recordFrameChange() {
        lock.lock()
        defer { lock.unlock() }
        frameCount += 1
    }

    nonisolated func recordBoundsChange() {
        lock.lock()
        defer { lock.unlock() }
        boundsCount += 1
    }

    nonisolated func frameChanges() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return frameCount
    }

    nonisolated func boundsChanges() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return boundsCount
    }
}

@MainActor
@Suite("Note Editor Layout")
struct NoteEditorLayoutTests {
    @MainActor
    private final class HostingViewFixtureRetainer {
        static let shared = HostingViewFixtureRetainer()
        private var views: [NSView] = []

        func retain(_ view: NSView) {
            view.removeFromSuperview()
            views.append(view)
        }
    }

    @MainActor
    private func retainHostingFixture(_ view: NSView) {
        HostingViewFixtureRetainer.shared.retain(view)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
        return try String(
            contentsOf: repoRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    @MainActor
    @Test("Notes UI state no longer exposes a legacy editor-engine toggle")
    func notesUIStateNoLongerExposesLegacyEditorToggle() throws {
        let source = try loadRepoTextFile("Epistemos/State/NotesUIState.swift")
        #expect(!source.contains("useTK2Editor"))
        #expect(!source.contains("tk2DefaultsKey"))
    }

    @Test("TK2 editor stays transparent in native system themes so the window blur can show through")
    func tk2EditorKeepsTransparentNativeSurface() {
        #expect(ProseTextView2.editorBackgroundColor(for: .systemLight) == .clear)
        #expect(ProseTextView2.editorBackgroundColor(for: .systemDark) == .clear)
    }

    @MainActor
    @Test("TK2 editor host preserves the redraw-safe scroll configuration")
    func tk2EditorHostPreservesLegacyScrollConfiguration() {
        let (scrollView, _) = ProseTextView2.makeTextKit2()

        #expect(scrollView.borderType == .noBorder)
        #expect(scrollView.wantsLayer)
        #expect(scrollView.contentView.wantsLayer)
        #expect(scrollView.contentView.layerContentsRedrawPolicy == .onSetNeedsDisplay)
        #expect(!scrollView.automaticallyAdjustsContentInsets)
        #expect(scrollView.contentInsets.top == 0)
        #expect(scrollView.contentInsets.left == 0)
        #expect(scrollView.contentInsets.bottom == 0)
        #expect(scrollView.contentInsets.right == 0)
    }

    @Test("TK2 editor scroll observers coalesce viewport and overlay work")
    func tk2EditorScrollObserversCoalesceViewportAndOverlayWork() throws {
        let proseSource = try loadRepoTextFile("Epistemos/Views/Notes/ProseTextView2.swift")
        let bridgeSource = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")

        #expect(proseSource.contains("scheduleVisibleLineRangeUpdate()"))
        #expect(proseSource.contains("scrollVisibleLineRangeCoalescer"))
        #expect(bridgeSource.contains("scheduleScrollOverlayRefresh()"))
        #expect(bridgeSource.contains("scrollOverlayRefreshCoalescer"))
    }

    @MainActor
    @Test("TK2 editor reclaims first responder from toolbar chrome on update")
    func tk2EditorReclaimsFirstResponderOnUpdate() {
        let editor = ProseEditorRepresentable2(
            text: .constant("Body"),
            pageId: "page-a",
            pageBody: "Body",
            isFocused: true,
            theme: .systemLight,
            isEditable: true,
            isFocusMode: false
        )
        let coordinator = editor.makeCoordinator()
        let (scrollView, textView) = ProseTextView2.makeTextKit2()
        coordinator.textView = textView
        coordinator.scrollView = scrollView
        coordinator.currentPageId = "page-a"
        coordinator.lastSyncedText = "Body"
        coordinator.lastPersistedText = "Body"
        coordinator.lastTheme = .systemLight
        coordinator.lastIsEditable = true
        coordinator.lastIsFocusMode = false

        let host = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        scrollView.frame = host.bounds
        host.addSubview(scrollView)

        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.makeFirstResponder(nil)

        coordinator.handleUpdate()

        #expect(window.firstResponder === textView)
    }

    @Test("note editor card keeps a readable minimum size in compact windows")
    func noteEditorCardKeepsReadableMinimumSize() {
        let roomy = NoteWorkspaceSurfaceStyle.editorCardSize(
            for: CGSize(width: 720, height: 552)
        )
        let cramped = NoteWorkspaceSurfaceStyle.editorCardSize(
            for: CGSize(width: 320, height: 220)
        )

        #expect(roomy.width == 664)
        #expect(roomy.height == 456)
        #expect(cramped.width == NoteWorkspaceSurfaceStyle.minimumEditorSize.width)
        #expect(cramped.height == NoteWorkspaceSurfaceStyle.minimumEditorSize.height)
    }

    @Test("note footer keeps only the word count chip")
    func noteFooterKeepsOnlyWordCountChip() {
        #expect(!NoteWorkspaceFooterDisplay.showsBottomFade)
        #expect(NoteWorkspaceFooterDisplay.chipSpacing == 8)
        #expect(NoteWorkspaceFooterDisplay.showsShortcutHints == false)
    }

    @Test("toolbar quick actions keep save and sidebar shortcuts without hover text")
    func toolbarQuickActionsKeepShortcutsWithoutHoverText() {
        #expect(NoteWorkspaceQuickAction.allCases == [.saveToDisk, .notesSidebar])
        #expect(NoteWorkspaceQuickAction.saveToDisk.shortcut == "⌘S")
        #expect(NoteWorkspaceQuickAction.notesSidebar.shortcut == "⌘2")
        #expect(NoteWorkspaceQuickAction.saveToDisk.help == nil)
        #expect(NoteWorkspaceQuickAction.notesSidebar.help == nil)
    }

    @Test("preview H1 uses the same heading scale as the note editor")
    func previewH1UsesEditorHeadingScale() throws {
        let shortHeading = "Big Heading"
        let longHeading =
            "A Neuroscientific explanation of determinism in society across institutions, incentives, and collective mythmaking"
        let expectedShort = MarkdownHeadingDisplay.fontSize(
            for: 1,
            text: "# \(shortHeading)",
            baseSize: MarkdownTextStorage.noteBaseFontSize + 31,
            nextLevelSize: MarkdownTextStorage.noteBaseFontSize + 5
        )
        let expectedLong = MarkdownHeadingDisplay.fontSize(
            for: 1,
            text: "# \(longHeading)",
            baseSize: MarkdownTextStorage.noteBaseFontSize + 31,
            nextLevelSize: MarkdownTextStorage.noteBaseFontSize + 5
        )
        let previewSource = try String(
            contentsOf: repoRootURL().appendingPathComponent(
                "Epistemos/Views/Shared/MarkdownTextView.swift"
            ),
            encoding: .utf8
        )

        #expect(MarkdownHeadingDisplay.noteHeadingFontSize(for: 1, text: shortHeading) == expectedShort)
        #expect(MarkdownHeadingDisplay.noteHeadingFontSize(for: 1, text: longHeading) == expectedLong)
        #expect(MarkdownHeadingDisplay.noteHeadingFontSize(for: 1, text: shortHeading) > AppHeadingRole.h2.fontSize)
        #expect(previewSource.contains("MarkdownHeadingDisplay.noteHeadingFontSize("))
    }

    @Test("note workspace removes the source scanning action")
    func noteWorkspaceRemovesSourceScanningAction() throws {
        let source = try String(
            contentsOf: repoRootURL().appendingPathComponent(
                "Epistemos/Views/Notes/NoteDetailWorkspaceView.swift"
            ),
            encoding: .utf8
        )

        #expect(!source.contains("Scan Sources"))
        #expect(!source.contains("scanForCitations"))
        #expect(!source.contains("isScanningCitations"))
    }

    @Test("interactive note flush paths use the lightweight derived-state helper")
    func interactiveNoteFlushPathsUseLightweightDerivedStateHelper() throws {
        let proseSource = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        let workspaceSource = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let syncSource = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(proseSource.contains("applyInteractiveDerivedState("))
        #expect(workspaceSource.contains("applyInteractiveDerivedState("))
        #expect(syncSource.contains("applyInteractiveDerivedState("))
    }

    @Test("interactive save paths defer version maintenance off the main actor")
    func interactiveSavePathsDeferVersionMaintenance() throws {
        let syncSource = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(syncSource.contains("scheduleVersionCaptureIfNeeded(pageId: pageId, context: context)"))
        #expect(syncSource.contains("scheduleVersionCaptureIfNeeded(pageId: page.id, context: context)"))
        #expect(syncSource.contains("Task.detached(priority: .utility)"))
    }

    @Test("periodic version capture reuses the deferred dirty-page path")
    func periodicVersionCaptureReusesDeferredDirtyPagePath() throws {
        let syncSource = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        guard let autoCaptureRange = syncSource.range(of: "private func autoCaptureVersions()"),
              let createPageRange = syncSource.range(of: "func createPage(", range: autoCaptureRange.upperBound..<syncSource.endIndex) else {
            Issue.record("Failed to isolate autoCaptureVersions() in VaultSyncService.swift")
            return
        }

        let autoCaptureSource = String(syncSource[autoCaptureRange.lowerBound..<createPageRange.lowerBound])

        #expect(autoCaptureSource.contains("predicate: #Predicate<SDPage> { $0.needsVaultSync == true || $0.lastSyncedBodyHash == nil }"))
        #expect(autoCaptureSource.contains("scheduleVersionCaptureIfNeeded(pageId: page.id, context: context)"))
        #expect(!autoCaptureSource.contains("captureVersionIfNeeded(pageId:"))
        #expect(!autoCaptureSource.contains("let descriptor = FetchDescriptor<SDPage>()"))
        #expect(!autoCaptureSource.contains("let dirty = allPages.filter(\\.isDirtyVault)"))
    }

    @Test("fragile note save wiring keeps editor flushes on the deferred export path")
    func fragileNoteSaveWiringKeepsEditorFlushesOnDeferredExportPath() throws {
        let workspaceSource = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let proseSource = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        let syncSource = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(workspaceSource.contains("private func flushCurrentEditor()"))
        #expect(workspaceSource.contains("page.applyInteractiveDerivedState(from: fullText)"))
        #expect(workspaceSource.contains("NoteFileStorage.scheduleWriteBody(pageId: pageId, content: fullText)"))
        #expect(workspaceSource.contains("BlockMirrorSyncCoordinator.shared.scheduleSync("))
        #expect(workspaceSource.contains("vaultSync.savePage(pageId: pageId)"))
        #expect(workspaceSource.contains("vaultSync.saveAllDirtyPages()"))

        #expect(proseSource.contains("NoteFileStorage.scheduleWriteBody(pageId: pageId, content: currentBody)"))
        #expect(proseSource.contains("page.applyInteractiveDerivedState(from: currentBody)"))
        #expect(proseSource.contains("vaultSync.renamePageFile(pageId: pageId, newTitle: newTitle)"))

        #expect(syncSource.contains("preparePageForExport(pageId: pageId, context: context)"))
        #expect(syncSource.contains("scheduleVersionCaptureIfNeeded(pageId: pageId, context: context)"))
        #expect(syncSource.contains("await NoteFileStorage.flushPendingBodyToDisk(pageId: pageId)"))
        #expect(syncSource.contains("if let task = inFlightDirtySaveTask, !task.isCancelled {"))
        #expect(syncSource.contains("pendingDirtySaveRequest = true"))
        #expect(syncSource.contains("guard let initialBatch = nextDirtySaveBatch() else { return nil }"))
        #expect(syncSource.contains("await self.runDirtySaveLoop(startingWith: initialBatch)"))
    }

    @Test("fold gutter anchors to first-line typography and outline boot starts from a clean fold slate")
    func foldGutterAnchorsToFirstLineTypography() throws {
        let proseSource = try loadRepoTextFile("Epistemos/Views/Notes/ProseTextView2.swift")
        let bridgeSource = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")
        guard let layoutRange = proseSource.range(of: "private func foldIndicatorLayout("),
              let visibleFragmentsRange = proseSource.range(of: "// MARK: - Visible Fragment Enumeration", range: layoutRange.upperBound..<proseSource.endIndex),
              let drawRange = proseSource.range(of: "private func drawFoldIndicators(in dirtyRect: NSRect)"),
              let tableHelpersRange = proseSource.range(of: "// MARK: - Table Detection Helpers", range: drawRange.upperBound..<proseSource.endIndex),
              let mouseRange = proseSource.range(of: "override func mouseDown(with event: NSEvent)", range: drawRange.upperBound..<proseSource.endIndex),
              let dataDetectionRange = proseSource.range(of: "// Data detection click", range: mouseRange.upperBound..<proseSource.endIndex),
              let foldModeRange = bridgeSource.range(of: "func applyOutlineFoldMode(_ mode: OutlineFoldMode)"),
              let reenumRange = bridgeSource.range(of: "/// Force the content manager to re-enumerate all elements", range: foldModeRange.upperBound..<bridgeSource.endIndex) else {
            Issue.record("Failed to isolate fold-indicator source ranges")
            return
        }

        let layoutSource = String(proseSource[layoutRange.lowerBound..<visibleFragmentsRange.lowerBound])
        let drawSource = String(proseSource[drawRange.lowerBound..<tableHelpersRange.lowerBound])
        let mouseSource = String(proseSource[mouseRange.lowerBound..<dataDetectionRange.lowerBound])
        let foldModeSource = String(bridgeSource[foldModeRange.lowerBound..<reenumRange.lowerBound])

        #expect(layoutSource.contains("lineFrag.typographicBounds.origin.y"))
        #expect(layoutSource.contains("lineFrag.typographicBounds.height"))
        #expect(layoutSource.contains("lineRect = NSRect"))
        #expect(drawSource.contains("seenParagraphs"))
        #expect(drawSource.contains("size(withAttributes: attrs)"))
        #expect(drawSource.contains("indicator.lineRect.midY"))
        #expect(!drawSource.contains("fragFrame.midY - size / 2"))

        #expect(mouseSource.contains("indicator.hitRect.contains(clickPoint)"))
        #expect(!mouseSource.contains("clickPoint.x < lineLeft + 6 && clickPoint.x > lineLeft - 30"))

        #expect(foldModeSource.contains("markdown_clear_all_folds()"))
        #expect(foldModeSource.contains("delegate.recomputeHiddenLines(documentText: tv.string)"))
        #expect(foldModeSource.contains("forceContentReEnumeration(tv)"))
        #expect(bridgeSource.contains("coord.applyOutlineFoldMode(outlineFoldMode)"))
        #expect(bridgeSource.contains("applyOutlineFoldMode(parent.outlineFoldMode)"))
    }

    @Test("heading prefix styling covers H6 markers and respects tab indentation")
    func headingPrefixStylingCoversH6AndTabs() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/MarkdownContentStorage.swift")

        #expect(source.contains("case 5:"))
        #expect(source.contains("prefix: \"###### \""))
        #expect(source.contains("line.prefix { $0 == \" \" || $0 == \"\\t\" }.utf16.count"))
        #expect(!source.contains("line.prefix(while: { $0 == \" \" }).count"))
    }

    @Test("note toolbar keeps secondary actions in the top-level more menu")
    func noteToolbarKeepsSecondaryActionsInTopLevelMoreMenu() throws {
        let source = try String(
            contentsOf: repoRootURL().appendingPathComponent(
                "Epistemos/Views/Notes/NoteDetailWorkspaceView.swift"
            ),
            encoding: .utf8
        )

        #expect(source.contains("Menu(\"Format\")"))
        #expect(source.contains("Label(\"Backlinks\", systemImage: \"link\")"))
        #expect(source.contains("Label(\"Apple Writing Tools\", systemImage: \"apple.intelligence\")"))
        #expect(source.contains("glyph: .miniChat"))
        #expect(source.contains("openMiniChatForCurrentNote()"))
        #expect(source.contains("Button(action: { notesUI.cycleOutlineFoldMode() })"))
        #expect(!source.contains("Menu(\"Options\")"))
        #expect(!source.contains("formatToolbarMenu"))
        #expect(!source.contains("appleWritingToolsButton"))
        #expect(source.contains("ForEach(NoteWorkspaceQuickAction.allCases"))
    }

    @Test("toolbar ask field streams inline with siri glow instead of the old ascii status badge")
    func toolbarAskFieldStreamsInlineWithoutPopover() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        guard let toolbarRange = source.range(of: "private func toolbarChatField(width: CGFloat) -> some View"),
              let nextSectionRange = source.range(of: "private var noteChatContextAttachment", range: toolbarRange.upperBound..<source.endIndex) else {
            Issue.record("Failed to isolate toolbarChatField() in NoteDetailWorkspaceView.swift")
            return
        }

        let toolbarSource = String(source[toolbarRange.lowerBound..<nextSectionRange.lowerBound])

        #expect(toolbarSource.contains("noteChatState.submitToolbarQuery("))
        #expect(toolbarSource.contains(".siriGlow("))
        #expect(toolbarSource.contains("TextField(\"Ask this note\""))
        #expect(!toolbarSource.contains(".popover("))
        #expect(!toolbarSource.contains("ASCIIFrameAnimationText("))
        #expect(!toolbarSource.contains("ASCIIRippleText("))
        #expect(!toolbarSource.contains("noteChatAttachmentChip("))
        #expect(!toolbarSource.contains("toolbarAskStatusLabel"))
        #expect(!source.contains("private var toolbarResponseDropdown"))
        #expect(!source.contains("private var toolbarAskStatusAnimation"))
        #expect(!source.contains("private var toolbarAskStatusBadge"))
    }

    @Test("visible note toolbar strip stays lean with only preview history and more controls")
    func visibleNoteToolbarStripStaysLean() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        guard let controlsRange = source.range(of: "private var noteToolbarPrimaryActions: some View"),
              let nextSectionRange = source.range(of: "// MARK: - Wikilink Navigation", range: controlsRange.upperBound..<source.endIndex) else {
            Issue.record("Failed to isolate noteToolbarPrimaryActions in NoteDetailWorkspaceView.swift")
            return
        }

        let controlsSource = String(source[controlsRange.lowerBound..<nextSectionRange.lowerBound])

        // Uses standard Button + Label (matching main chat's toolbar pattern).
        #expect(controlsSource.contains("Label("))
        #expect(controlsSource.contains("Chat History"))
        #expect(controlsSource.contains("moreMenu"))
        #expect(!controlsSource.contains("outlineFoldButton"))
        #expect(!controlsSource.contains("glyph: .miniChat"))
        #expect(!controlsSource.contains("ForEach(NoteWorkspaceQuickAction.allCases"))
    }

    @Test("preview reserves the native titlebar inset and falls back higher for tab groups")
    func previewReservesTitlebarInset() {
        #expect(
            NotePreviewChromeMetrics.contentTopInset(titlebarInset: 0, hasMultipleTabs: false)
                == NotePreviewChromeMetrics.fallbackSingleTopInset
        )
        #expect(
            NotePreviewChromeMetrics.contentTopInset(titlebarInset: 0, hasMultipleTabs: true)
                == NotePreviewChromeMetrics.fallbackTabbedTopInset
        )
        #expect(
            NotePreviewChromeMetrics.contentTopInset(titlebarInset: 52, hasMultipleTabs: false)
                == 52
        )
        #expect(
            NotePreviewChromeMetrics.contentTopInset(titlebarInset: 88, hasMultipleTabs: true)
                == 88
        )
    }

    @MainActor
    @Test("native note windows keep the blur-backed wrapper around hosted content")
    func nativeNoteWindowsKeepBackdropWrapper() throws {
        let uiState = UIState()
        let host = NSHostingController(rootView: Color.clear)

        let controller = try #require(
            NoteWindowThemeStyler.themedContentController(
                hostingController: host,
                uiState: uiState
            ) as? NoteWindowBackdropController
        )

        #expect(controller.view.subviews.contains(host.view))
    }

    private func repoRootURL() -> URL {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        return testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
    }

    @Test("top spacing stays tight below the toolbar")
    func topSpacingStaysTightBelowToolbar() {
        #expect(ProseEditorRepresentable.verticalInset == 40)
        #expect(MarkdownTextStorage.leadingH1SpacingBefore == 36)
        #expect(MarkdownTextStorage.sectionH1SpacingBefore == 30)
        #expect(NoteEditorPerformancePolicy.renderedTableOverlayRefreshDelay == .milliseconds(120))
    }

    @MainActor
    @Test("editor bootstraps from persisted note body before the first onAppear")
    func editorBootstrapsFromPersistedBody() {
        let page = SDPage(title: "Bootstrap")
        page.saveBody("# Persisted\n\nBody")

        let snapshot = ProseEditorView.initialBodySnapshot(for: page)

        #expect(snapshot.bodyText == "# Persisted\n\nBody")
        #expect(snapshot.lastPersistedBody == "# Persisted\n\nBody")
    }

    @MainActor
    @Test("editor re-entry prefers the captured live body over an older persisted body")
    func editorReentryPrefersLiveBodySnapshot() {
        let page = SDPage(title: "Preview Toggle")
        page.saveBody("# Persisted\n\nOlder body")

        let snapshot = ProseEditorView.initialBodySnapshot(
            for: page,
            preferredBody: "# Persisted\n\nNewly pasted paragraph"
        )

        #expect(snapshot.bodyText == "# Persisted\n\nNewly pasted paragraph")
        #expect(snapshot.lastPersistedBody == "# Persisted\n\nNewly pasted paragraph")
    }

    @MainActor
    @Test("note workspace falls back to loadBody when its cached persisted body is empty")
    func noteWorkspacePersistedBodyFallsBackToLoadBody() {
        let page = SDPage(title: "Fallback")
        page.body = "# Inline\n\nRecovered body"

        let resolved = NoteDetailWorkspaceView.resolvedPersistedBody("", for: page)

        #expect(resolved == "# Inline\n\nRecovered body")
    }

    @Test("note workspace no longer calls loadBody from its render-time persisted-body fallback")
    func noteWorkspaceRenderPathAvoidsLoadBodyFallback() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        #expect(!source.contains("page.loadBody()"))
    }

    @Test("editor save path offloads block mirror sync from the main actor")
    func editorSavePathOffloadsBlockMirrorSyncFromMainActor() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")

        #expect(source.contains("private func scheduleBlockMirrorSync"))
        #expect(source.contains("await BlockMirrorSyncCoordinator.shared.scheduleSync("))
        #expect(!source.contains("BlockMirror.sync(pageId: pageId, body: newValue, modelContext: modelContext)"))
        #expect(!source.contains("private func syncBlocks(body: String) {\n        BlockMirror.sync("))
    }

    @Test("transclusion edits avoid synchronous block mirror fallback on the main actor")
    func transclusionEditsAvoidSynchronousBlockMirrorFallback() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")

        #expect(source.contains("BlockMirror.rewrittenBody("))
        #expect(source.contains("existingBlocks: pageBlocks"))
        #expect(!source.contains("BlockMirror.sync(pageId: sourcePageId, body: pageBody, modelContext: mc)"))
        #expect(!source.contains("Synchronous — when this returns, loadBody() reflects live edits."))
    }

    @Test("interactive note flush paths avoid synchronous durable writes on the main actor")
    func interactiveNoteFlushPathsAvoidSynchronousDurableWrites() throws {
        let proseSource = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        let workspaceSource = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let inspectorSource = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let diffSource = try loadRepoTextFile("Epistemos/Views/Notes/DiffSheetView.swift")

        #expect(proseSource.contains("await NoteFileStorage.writeBodyAsync("))
        #expect(proseSource.contains("NoteFileStorage.scheduleWriteBody("))
        #expect(!proseSource.contains("Task {\n                    await NoteFileStorage.writeBodyAsync("))
        #expect(!proseSource.contains("oldPage.saveBody(currentText)"))
        #expect(!proseSource.contains("page.saveBody(bodyText)"))
        #expect(!proseSource.contains("page.saveBody(sanitizedBody)"))

        #expect(workspaceSource.contains("NoteFileStorage.scheduleWriteBody("))
        #expect(!workspaceSource.contains("Task {\n            await NoteFileStorage.writeBodyAsync(pageId: pageId, content: fullText)\n        }"))
        #expect(!workspaceSource.contains("page.saveBody(fullText)"))
        #expect(!workspaceSource.contains("BlockMirror.sync(pageId: page.id, body: fullText, modelContext: modelContext)"))

        #expect(inspectorSource.contains("NoteFileStorage.scheduleWriteBody("))
        #expect(inspectorSource.contains("await NoteFileStorage.writeBodyAsync(pageId: pageId, content: text)"))
        #expect(!inspectorSource.contains("Task {\n            await NoteFileStorage.writeBodyAsync(pageId: pageId, content: editorText)\n        }"))
        #expect(!inspectorSource.contains("NoteFileStorage.writeBody(pageId: pageId, content: editorText)"))

        #expect(diffSource.contains("NoteFileStorage.stageBodyForImmediateRead(pageId: pageId, content: body)"))
        #expect(diffSource.contains("await NoteFileStorage.flushPendingBodyToDisk(pageId: pageId)"))
        #expect(!diffSource.contains("await NoteFileStorage.writeBodyAsync("))
        #expect(!diffSource.contains("page.saveBody(body)"))
        #expect(!diffSource.contains("BlockMirror.sync(pageId: page.id, body: body, modelContext: modelContext)"))
    }

    @Test("requestFlush stages the live editor body before downstream readers continue")
    func requestFlushStagesLiveEditorBodyBeforeDownstreamReadersContinue() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/NoteFileStorage.swift")

        #expect(source.contains("NoteWindowManager.shared.editorBody(for: pageId)"))
        #expect(source.contains("stageBodyForImmediateRead(pageId: pageId, content: liveBody)"))
        #expect(!source.contains("await writeBodyAsync(pageId: pageId, content: liveBody)"))
        #expect(!source.contains("Synchronous — disk is current when this returns."))
    }

    @Test("vault saves prepare live editor state before export")
    func vaultSavesPrepareLiveEditorStateBeforeExport() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(source.contains("private func preparePageForExport(pageId: String, context: ModelContext)"))
        #expect(source.contains("preparePageForExport(pageId: pageId, context: context)"))
        #expect(source.contains("preparePageForExport(pageId: page.id, context: context)"))
        #expect(source.contains("NoteWindowManager.shared.editorBody(for: pageId) ?? page.loadBody()"))
        #expect(source.contains("NoteFileStorage.stageBodyForImmediateRead("))
        #expect(source.contains("await NoteFileStorage.flushPendingBodyToDisk(pageId: pageId)"))
        #expect(source.contains("page.needsVaultSync = true"))
        #expect(source.contains("ProseEditorView.syncNoteTitleIfNeeded("))
    }

    @Test("page-body read requests stage editor text without forcing a full metadata flush on the main actor")
    func pageBodyReadRequestsStageEditorTextWithoutFullMetadataFlush() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")

        #expect(source.contains("stagePendingBodyForReadIfNeeded()"))
        #expect(source.contains("NoteFileStorage.scheduleWriteBody(pageId: pageId, content: currentBody)"))
        #expect(source.contains("NotificationCenter.default.publisher(for: NoteFileStorage.pageBodyWillRead)"))
    }

    @Test("preview handoff never reuses another note's captured body")
    func previewHandoffIgnoresOtherNotes() {
        let snapshot = NoteModeBodySnapshot(pageId: "note-a", body: "Body from note A")

        #expect(snapshot.body(ifMatches: "note-b") == nil)
    }

    @MainActor
    @Test("editor tables collapse into compact placeholders instead of full inline previews")
    func editorTablesCollapseIntoCompactPlaceholders() throws {
        let markdown = """
        | Name | Count |
        | --- | --- |
        | Pens | 12 |
        | Paper | 4 |

        After
        """

        let storage = MarkdownTextStorage()
        storage.isDark = false
        storage.theme = .light
        storage.usesRenderedTableOverlays = true

        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(
            size: NSSize(width: 640, height: CGFloat.greatestFiniteMagnitude)
        )
        container.lineFragmentPadding = 0
        container.widthTracksTextView = false

        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        storage.replaceCharacters(
            in: NSRange(location: 0, length: storage.length),
            with: markdown
        )
        layoutManager.ensureLayout(for: container)

        let text = storage.string as NSString
        let tableRange = try #require(MarkdownTableBlockRanges.ranges(in: text).first)
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: tableRange,
            actualCharacterRange: nil
        )
        let allocatedHeight = layoutManager.boundingRect(
            forGlyphRange: glyphRange,
            in: container
        ).height

        let table = try #require(MarkdownTableModel.parse(text.substring(with: tableRange)))
        let placeholder = NoteEditorRenderedTableHostingView(table: table, theme: .light)
        placeholder.update(
            table: table,
            theme: .light,
            frame: NSRect(x: 0, y: 0, width: 640, height: allocatedHeight)
        )

        let popoverPreviewSize = NoteEditorRenderedTablePopoverContent.preferredSize(for: table)

        #expect(allocatedHeight < popoverPreviewSize.height)
        #expect(placeholder.frame.height < popoverPreviewSize.height)
        #expect(placeholder.frame.height <= 28)
        #expect(placeholder.frame.width < 200)
    }

    @Test("legacy compatibility shim uses the same readable inset for table and prose notes")
    func classicEditorUsesSameInsetForTableAndProseNotes() {
        let proseInset = ProseEditorRepresentable.horizontalInset(
            for: 1000,
            markdown: "# Heading\n\nBody"
        )
        let tableInset = ProseEditorRepresentable.horizontalInset(
            for: 1000,
            markdown: """
            | Name | Count |
            | --- | --- |
            | Pens | 12 |
            """
        )

        #expect(tableInset == proseInset)
    }

    @Test("legacy compatibility shim typing attributes reset to body style")
    func classicEditorTypingAttributesResetToBodyStyle() throws {
        let attributes = ProseEditorRepresentable.typingAttributes(for: .light)
        let font = try #require(attributes[.font] as? NSFont)
        let paragraphStyle = try #require(attributes[.paragraphStyle] as? NSParagraphStyle)

        #expect(font.pointSize == MarkdownTextStorage.noteBaseFontSize)
        #expect(paragraphStyle.firstLineHeadIndent == MarkdownTextStorage.bodyParagraphStyle().firstLineHeadIndent)
        #expect(paragraphStyle.headIndent == MarkdownTextStorage.bodyParagraphStyle().headIndent)
    }

    @Test("legacy compatibility shim notification page matching rejects stale page ids")
    func classicEditorNotificationPageMatchingRejectsStalePageIds() {
        #expect(ProseEditorRepresentable.matchesNotificationPageId("page-a", coordinatorPageId: "page-a"))
        #expect(!ProseEditorRepresentable.matchesNotificationPageId("page-a", coordinatorPageId: "page-b"))
        #expect(!ProseEditorRepresentable.matchesNotificationPageId(nil, coordinatorPageId: "page-a"))
        #expect(!ProseEditorRepresentable.matchesNotificationPageId("page-a", coordinatorPageId: nil))
        #expect(!ProseEditorRepresentable.matchesNotificationPageId("", coordinatorPageId: "page-a"))
        #expect(!ProseEditorRepresentable.matchesNotificationPageId("page-a", coordinatorPageId: ""))
    }

    @MainActor
    @Test("legacy compatibility shim dismantle unregisters content-view observers before teardown")
    func classicEditorDismantleUnregistersContentViewObservers() {
        let editor = ProseEditorRepresentable(
            text: .constant("Body"),
            pageId: "page-a",
            pageBody: "Body",
            isFocused: false,
            theme: .light,
            isEditable: true,
            isFocusMode: false
        )
        let coordinator = editor.makeCoordinator()
        let scrollView = NSScrollView()
        let textView = ClickableTextView(frame: .zero, textContainer: nil)
        scrollView.documentView = textView
        coordinator.lastPageId = "page-a"

        let clipView = scrollView.contentView
        let notifications = LayoutNotificationCounts()

        coordinator.frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: clipView,
            queue: nil
        ) { _ in
            notifications.recordFrameChange()
        }
        coordinator.scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: nil
        ) { _ in
            notifications.recordBoundsChange()
        }

        ProseEditorRepresentable.dismantleNSView(scrollView, coordinator: coordinator)

        NotificationCenter.default.post(name: NSView.frameDidChangeNotification, object: clipView)
        NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: clipView)

        #expect(notifications.frameChanges() == 0)
        #expect(notifications.boundsChanges() == 0)
        #expect(coordinator.frameObserver == nil)
        #expect(coordinator.scrollObserver == nil)
    }

    @Test("overlay-backed table markdown source text is hidden in the legacy compatibility storage")
    func renderedTableOverlaysHideTextKit1SourceText() throws {
        let storage = MarkdownTextStorage()
        storage.isDark = false
        storage.theme = .light
        storage.usesRenderedTableOverlays = true
        storage.replaceCharacters(
            in: NSRange(location: 0, length: storage.length),
            with: """
            | Name | Count |
            | --- | --- |
            | Pens | 12 |
            """
        )

        let text = storage.string as NSString
        let nameRange = try #require(text.range(of: "Name").location != NSNotFound ? text.range(of: "Name") : nil)
        let color = try #require(
            storage.attribute(.foregroundColor, at: nameRange.location, effectiveRange: nil) as? NSColor
        )

        #expect(color.alphaComponent == 0)
    }

    @Test("table placeholders use the first non-empty header cell as the title")
    func tablePlaceholderUsesFirstNonEmptyHeaderCell() throws {
        let table = try #require(
            MarkdownTableModel.parse(
                """
                |   | Δ Count |
                | --- | --- |
                | Pens | 12 |
                """
            )
        )

        #expect(table.placeholderLabel == "Table: Δ Count")
    }

    @MainActor
    @Test("table popover renders a full-sized table surface")
    func tablePopoverRendersFullSizedTableSurface() throws {
        let table = try #require(
            MarkdownTableModel.parse(
                """
                | Subject | Score |
                | --- | --- |
                | Pens | 12 |
                | Paper | 4 |
                """
            )
        )

        let size = NoteEditorRenderedTablePopoverContent.preferredSize(for: table)
        let host = NSHostingView(
            rootView: NoteEditorRenderedTablePopoverContent(table: table, theme: .light)
        )
        defer { retainHostingFixture(host) }
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()

        #expect(host.fittingSize.width >= size.width - 20)
        #expect(host.fittingSize.height >= 80)
    }

    @MainActor
    @Test("table placeholder keeps typing click-through outside the preview hotspot")
    func tablePlaceholderKeepsTypingClickThroughOutsidePreviewHotspot() throws {
        let table = try #require(
            MarkdownTableModel.parse(
                """
                | Subject | Score |
                | --- | --- |
                | Pens | 12 |
                """
            )
        )

        let host = NoteEditorRenderedTableHostingView(table: table, theme: .light)
        host.update(
            table: table,
            theme: .light,
            frame: NSRect(x: 0, y: 0, width: 320, height: 26)
        )

        let textPoint = NSPoint(x: 6, y: host.bounds.midY)
        let hotspotPoint = NSPoint(x: host.bounds.maxX - 6, y: host.bounds.midY)

        #expect(host.hitTest(textPoint) == nil)
        #expect(host.hitTest(hotspotPoint) === host)
    }

    @Test("typing triple backticks expands into a fenced code block")
    func typingTripleBackticksExpandsIntoFence() throws {
        let edit = try #require(
            MarkdownEditorCommands.autoExpandCodeFence(
                in: "  ``",
                selection: NSRange(location: 4, length: 0),
                replacementString: "`"
            )
        )

        #expect(edit.replacementRange == NSRange(location: 2, length: 2))
        #expect(edit.replacementText == "```\n  \n  ```")
        #expect(edit.selectedRange == NSRange(location: 8, length: 0))
    }

    @Test("ascii ripple preserves spaces while scrambling the active wave front")
    func asciiRipplePreservesSpaces() {
        let configuration = ASCIIRippleConfiguration(
            duration: 1,
            characters: Array("~!"),
            preserveSpaces: true,
            spread: 1
        )
        let output = ASCIIRippleEngine.displayText(
            original: "A B",
            now: 0.2,
            waves: [ASCIIRippleWave(startIndex: 0, startTime: 0)],
            configuration: configuration
        )

        let characters = Array(output)
        #expect(characters.count == 3)
        #expect(characters[1] == " ")
    }

    @Test("ascii ripple maps hover x positions into stable character indices")
    func asciiRippleMapsHoverPositions() {
        #expect(ASCIIRippleEngine.characterIndex(forX: 0, width: 120, textLength: 6) == 0)
        #expect(ASCIIRippleEngine.characterIndex(forX: 60, width: 120, textLength: 6) == 3)
        #expect(ASCIIRippleEngine.characterIndex(forX: 120, width: 120, textLength: 6) == 5)
    }

    @Test("ascii frame animation cycles preview frames deterministically")
    func asciiFrameAnimationCyclesDeterministically() {
        let configuration = ASCIIFrameAnimationConfiguration(
            frames: ["[>]", "[>>]", "[>>>]"],
            frameDuration: 0.1
        )

        #expect(
            ASCIIFrameAnimationEngine.frame(
                now: 0,
                startTime: 0,
                configuration: configuration
            ) == "[>]"
        )
        #expect(
            ASCIIFrameAnimationEngine.frame(
                now: 0.12,
                startTime: 0,
                configuration: configuration
            ) == "[>>]"
        )
        #expect(
            ASCIIFrameAnimationEngine.frame(
                now: 0.24,
                startTime: 0,
                configuration: configuration
            ) == "[>>>]"
        )
        #expect(
            ASCIIFrameAnimationEngine.frame(
                now: 0.34,
                startTime: 0,
                configuration: configuration
            ) == "[>]"
        )
    }

    @Test("markdown ripple style scopes headings and body separately")
    func markdownRippleStyleScopesHeadingsAndBodySeparately() {
        #expect(MarkdownRippleStyle.heading1.ripplesHeading(level: 1))
        #expect(!MarkdownRippleStyle.heading1.ripplesHeading(level: 2))
        #expect(!MarkdownRippleStyle.heading1.includesBodyBlocks)
        #expect(MarkdownRippleStyle.headings123.ripplesHeading(level: 3))
        #expect(!MarkdownRippleStyle.headings123.ripplesHeading(level: 4))
        #expect(MarkdownRippleStyle.heading1AndBody.includesBodyBlocks)
        #expect(MarkdownRippleStyle.headings123AndBody.includesBodyBlocks)
    }

    @Test("markdown ripple text extractor preserves visible inline markdown text")
    func markdownRippleTextExtractorPreservesVisibleInlineMarkdownText() {
        let visible = MarkdownRippleTextExtractor.displayText(
            from: "**Bold** and [Link](https://example.com) with `Code`"
        )

        #expect(visible == "Bold and Link with Code")
    }

    @Test("synced note title extracts the first real H1 and ignores fenced code")
    func syncedNoteTitleExtractsFirstRealH1() {
        let title = ProseEditorView.syncedNoteTitle(
            from: """
            ```
            # Not The Title
            ```

            ## Section
            # Actual Title ###

            # Later Title
            """
        )

        #expect(title == "Actual Title")
    }

    @MainActor
    @Test("syncing note title from H1 updates page metadata and requests a rename")
    func syncingNoteTitleFromH1UpdatesPageMetadataAndRequestsRename() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = SDPage(title: "Old Title")
        context.insert(page)
        try context.save()

        var renameRequest: (pageId: String, title: String)?
        let changed = ProseEditorView.syncNoteTitleIfNeeded(
            from: "# New Title\n\nBody",
            for: page,
            modelContext: context
        ) { pageId, newTitle in
            renameRequest = (pageId, newTitle)
        }

        #expect(changed)
        #expect(page.title == "New Title")
        #expect(page.needsVaultSync)
        #expect(renameRequest?.pageId == page.id)
        #expect(renameRequest?.title == "New Title")
    }

    @MainActor
    @Test("syncing note title ignores bodies without an H1")
    func syncingNoteTitleIgnoresBodiesWithoutH1() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = SDPage(title: "Keep Title")
        context.insert(page)
        try context.save()

        var renameCount = 0
        let changed = ProseEditorView.syncNoteTitleIfNeeded(
            from: "Body only\n\n## Section",
            for: page,
            modelContext: context
        ) { _, _ in
            renameCount += 1
        }

        #expect(!changed)
        #expect(page.title == "Keep Title")
        #expect(renameCount == 0)
    }

    @MainActor
    @Test("graph overlay hosted views resolve required app environment")
    func graphOverlayHostedViewsResolveRequiredAppEnvironment() {
        let existingBootstrap = AppBootstrap.shared
        let bootstrap = existingBootstrap ?? AppBootstrap()
        let host = NSHostingView(
            rootView: HologramOverlayHostedViewBuilder.root(
                GraphOverlayEnvironmentProbe(),
                bootstrap: bootstrap
            )
        )
        defer { retainHostingFixture(host) }

        host.frame = NSRect(x: 0, y: 0, width: 240, height: 120)
        host.layoutSubtreeIfNeeded()

        if let existingBootstrap {
            #expect(bootstrap === existingBootstrap)
        }
        #expect(host.fittingSize.width >= 0)
    }
}

private struct GraphOverlayEnvironmentProbe: View {
    @Environment(UIState.self) private var ui
    @Environment(GraphState.self) private var graphState
    @Environment(QueryEngine.self) private var queryEngine

    var body: some View {
        Text(verbatim: "\(ui.theme.displayName) \(graphState.store.nodes.count) \(queryEngine.isProcessing)")
    }
}
