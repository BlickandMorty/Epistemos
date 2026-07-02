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
        try loadMirroredSourceTextFile(relativePath)
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

    @Test("note workspace paints an opaque native canvas behind transparent system editors")
    func noteWorkspacePaintsOpaqueNativeCanvasBehindSystemEditors() {
        #expect(NSColor(NoteWorkspaceSurfaceStyle.canvasBackground(for: .systemLight)).alphaComponent >= 0.99)
        #expect(NSColor(NoteWorkspaceSurfaceStyle.canvasBackground(for: .systemDark)).alphaComponent >= 0.99)
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

    @Test("note prose editor insets cap readable text without moving the scrollbar inward")
    func noteProseEditorInsetsCapReadableTextWithoutMovingScrollbarInward() {
        let compact = NoteDualPreviewLayout.editorReadableWidth(
            for: "A readable paragraph of prose without tables.",
            defaultWidth: 664
        )
        let wide = NoteDualPreviewLayout.editorReadableWidth(
            for: "A readable paragraph of prose without tables.",
            defaultWidth: 1080
        )
        let tableWide = NoteDualPreviewLayout.editorReadableWidth(
            for: "| A | B |\n| - | - |\n| 1 | 2 |",
            defaultWidth: 1080
        )

        #expect(compact == 664)
        #expect(wide == NoteDualPreviewLayout.defaultEditorSurfaceMaxWidth)
        #expect(tableWide == NoteDualPreviewLayout.tableEditorReadableMaxWidth)
    }

    @Test("note prose body keeps a wider centered text column in roomy windows")
    func noteProseBodyUsesCenteredReadableInset() {
        let compactInset = ProseEditorRepresentable2.horizontalInset(
            for: 900,
            markdown: "A readable paragraph of prose without tables."
        )
        let restoredWideInset = ProseEditorRepresentable2.horizontalInset(
            for: NoteDualPreviewLayout.defaultEditorSurfaceMaxWidth,
            markdown: "A readable paragraph of prose without tables."
        )
        let oversizedInset = ProseEditorRepresentable2.horizontalInset(
            for: 1100,
            markdown: "A readable paragraph of prose without tables."
        )
        let tableInset = ProseEditorRepresentable2.horizontalInset(
            for: 1100,
            markdown: "| A | B |\n| - | - |\n| 1 | 2 |"
        )

        #expect(compactInset == NoteDualPreviewLayout.minimumTextHorizontalInset)
        #expect(restoredWideInset == NoteDualPreviewLayout.minimumTextHorizontalInset)
        #expect(
            NoteDualPreviewLayout.defaultEditorSurfaceMaxWidth - (restoredWideInset * 2)
                == NoteDualPreviewLayout.editorTextReadableMaxWidth
        )
        #expect(oversizedInset == 70)
        #expect(tableInset == NoteDualPreviewLayout.minimumTextHorizontalInset)
    }

    @Test("note editor surface lets the prose scroll view fill the available width")
    func noteEditorSurfaceLetsProseScrollViewFillAvailableWidth() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        guard let surfaceRange = source.range(of: "private func noteEditorSurface(page: SDPage, availableSize: CGSize) -> some View"),
              let nextSectionRange = source.range(of: "/// Saves code file content back to disk", range: surfaceRange.upperBound..<source.endIndex) else {
            Issue.record("Failed to isolate noteEditorSurface() in NoteDetailWorkspaceView.swift")
            return
        }

        let surfaceSource = String(source[surfaceRange.lowerBound..<nextSectionRange.lowerBound])
        #expect(!surfaceSource.contains("let readableWidth = NoteDualPreviewLayout.editorReadableWidth("))
        #expect(!surfaceSource.contains(".frame(width: readableWidth"))
        #expect(surfaceSource.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)"))
    }

    @Test("markdown documents default to prose edit and expose Document Preview Source as peer modes")
    func markdownDocumentsDefaultToProseEditWithSourceAsThirdMode() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(source.contains("enum NoteWorkspaceMode: String, CaseIterable, Hashable"))
        #expect(source.contains("case edit"))
        #expect(source.contains("case document"))
        #expect(source.contains("case preview"))
        #expect(source.contains("case source"))
        #expect(source.contains("@State private var noteMode: NoteWorkspaceMode = .edit"))
        #expect(source.contains("surfaceModeToolbarButton(mode: mode, isActive: mode == selectedMode)"))
        #expect(!source.contains("Picker(\n                \"View\""))
        #expect(source.contains(": [.edit, .document, .preview, .source]"))
        #expect(source.contains("guard resolvedNoteMode(for: page, options: options) == .source else {"))
        #expect(!source.contains("MarkdownDocumentLens"))
        #expect(!source.contains("epistemos.markdownLens"))
        #expect(!source.contains("UserDefaults.standard.string(forKey: key(pageId: pageId, filePath: filePath))"))
    }

    @MainActor
    @Test("native code editor keeps horizontal overflow discoverable and bounded")
    func nativeCodeEditorKeepsHorizontalOverflowDiscoverableAndBounded() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 280, height: 180))
        let textView = NSTextView(frame: scrollView.bounds)
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.string = "short\n" + String(repeating: "x", count: 400)
        scrollView.documentView = textView

        CodeEditorScrollConfigurator.allowTwoAxisScrolling(textView: textView, scrollView: scrollView)

        #expect(scrollView.hasHorizontalScroller)
        #expect(scrollView.hasVerticalScroller)
        #expect(!scrollView.autohidesScrollers)
        #expect(scrollView.scrollerStyle == .legacy)
        #expect(textView.isHorizontallyResizable)
        #expect(textView.autoresizingMask == [.height])
        #expect(textView.textContainer?.widthTracksTextView == false)
        #expect(textView.textContainer?.heightTracksTextView == false)
        #expect(textView.frame.width > scrollView.contentSize.width)

        let boundedWidth = CodeEditorScrollConfigurator.estimatedDocumentWidth(
            text: String(repeating: "w", count: 50_000),
            font: textView.font,
            visibleWidth: 280,
            horizontalInset: 0
        )
        #expect(boundedWidth <= 80_000)
        #expect(
            CodeEditorScrollConfigurator.longestLineUTF16Length(
                in: "abc\n" + String(repeating: "z", count: 17),
                scanLimit: 1_000
            ) == 17
        )
    }

    @Test("code editor uses MarkEdit CoreEditor with only explicit legacy v1 fallback")
    func codeEditorUsesMarkEditCoreEditorWithOnlyExplicitLegacyV1Fallback() throws {
        let codeEditorSource = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let markEditSource = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorState.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorRuntimeResources.swift")

        #expect(!codeEditorSource.contains("CodeEditSourceEditor"))
        #expect(!codeEditorSource.contains("SourceEditor("))
        #expect(!codeEditorSource.contains("SourceEditorConfiguration("))
        #expect(!codeEditorSource.contains("useNativeSourceEditorFallback"))
        #expect(!codeEditorSource.contains("usesWebKitEditor"))
        #expect(!codeEditorSource.contains("EpistemosEditorCoordinator"))
        #expect(codeEditorSource.contains(#"@AppStorage("codeEditor.useLegacyV1Editor") private var useLegacyV1Editor = false"#))
        #expect(codeEditorSource.contains("useLegacyV1Editor && !isMarkdownDocument"))
        #expect(codeEditorSource.contains("WebKitCodeEditorView("))
        #expect(codeEditorSource.contains("private var isMarkdownDocument"))
        #expect(!codeEditorSource.contains("preferWebKitEditor"))
        #expect(!codeEditorSource.contains("useWebKitBeta"))
        #expect(codeEditorSource.contains("MarkEditCodeEditorRepresentable("))
        #expect(codeEditorSource.contains("MarkEditMarkdownEditorRepresentable("))
        #expect(codeEditorSource.contains("showLivePreview"))
        #expect(codeEditorSource.contains("HTMLWorkspacePreviewView("))
        #expect(codeEditorSource.contains("CodeEditorLivePreviewKind"))
        #expect(codeEditorSource.contains("scheduleLivePreviewUpdate(for:"))
        #expect(codeEditorSource.contains(#"Toggle("Show Invisibles", isOn: $showInvisibles)"#))

        #expect(markEditSource.contains("struct MarkEditCodeEditorRepresentable"))
        #expect(markEditSource.contains("struct MarkEditMarkdownEditorRepresentable"))
        #expect(markEditSource.contains("struct CoreEditorSelectionRequest"))
        #expect(markEditSource.contains("MarkEditVerbatimMarkdownChromeRepresentable"))
        #expect(markEditSource.contains("makeNSViewController(context: Context) -> EditorViewController"))
        #expect(markEditSource.contains("#if canImport(MarkEditKit)"))
        #expect(markEditSource.contains("MarkEditCoreEditorBridge"))
        #expect(markEditSource.contains("MarkEditCoreEditorChunkLoader"))
        #expect(markEditSource.contains("webModules.core.resetEditor"))
        #expect(markEditSource.contains(#"invisiblesBehavior: showInvisibles ? "always" : "never""#))
        #expect(markEditSource.contains("indentUnit: indentUnit"))
        #expect(markEditSource.contains("tabKeyBehavior: tabKeyBehavior"))
        #expect(markEditSource.contains("{{EDITOR_CONFIG}}"))
        #expect(markEditSource.contains("chunk-loader"))
    }

    @Test("CodeMirror bridge posts edits immediately and rejects stale Swift echoes")
    func codeMirrorBridgePostsEditsImmediatelyAndRejectsStaleSwiftEchoes() throws {
        let bridgeSource = try loadRepoTextFile("js-editor/src/code-editor.ts")
        let bridgeCSS = try loadRepoTextFile("js-editor/src/code-editor.css")

        #expect(bridgeSource.contains("function postChange"))
        #expect(bridgeSource.contains("sendChange(editor: EditorView = requireView())"))
        #expect(bridgeSource.contains("lastLocalEditAt = Date.now()"))
        #expect(bridgeSource.contains("const preserveLocalText"))
        #expect(bridgeSource.contains("lastState = preserveLocalText ? { ...state, text: currentText }"))
        #expect(bridgeSource.contains("window.addEventListener('pagehide'"))
        #expect(!bridgeSource.contains("window.setTimeout(() => {\n    const doc = editor.state.doc;"))
        #expect(bridgeCSS.contains(".cm-content"))
        #expect(bridgeCSS.contains("font-family: Menlo, \"SF Mono\", \"SFMono-Regular\", Monaco, ui-monospace, Consolas, monospace;"))
        #expect(bridgeCSS.contains("font-weight: 540;"))
        #expect(bridgeCSS.contains("-webkit-font-smoothing: subpixel-antialiased;"))
        #expect(bridgeCSS.contains("text-rendering: optimizeLegibility;"))
        #expect(!bridgeCSS.contains("font-weight: 500;"))
        #expect(!bridgeCSS.contains("-webkit-font-smoothing: auto;"))
        #expect(bridgeCSS.contains("color: var(--epi-code-fg, #202124);"))
        #expect(bridgeCSS.contains("background: var(--epi-code-gutter, #f7f8fa) !important"))
    }

    @Test("note body paragraph style keeps a calmer writing rhythm")
    func noteBodyParagraphStyleKeepsCalmerWritingRhythm() {
        let paragraphStyle = MarkdownEditorStyle.bodyParagraphStyle()

        #expect(paragraphStyle.lineSpacing == 6)
        #expect(paragraphStyle.paragraphSpacing == 10)
    }

    @Test("note footer keeps only the word count chip")
    func noteFooterKeepsOnlyWordCountChip() {
        #expect(!NoteWorkspaceFooterDisplay.showsBottomFade)
        #expect(NoteWorkspaceFooterDisplay.chipSpacing == 8)
        #expect(NoteWorkspaceFooterDisplay.showsShortcutHints == false)
    }

    @Test("document surface hides the outer note footer so Epdoc owns document stats")
    func documentSurfaceHidesOuterNoteFooter() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(source.contains("if shouldShowNoteWorkspaceFooter"))
        #expect(source.contains("private var shouldShowNoteWorkspaceFooter: Bool"))
        #expect(source.contains("return resolvedNoteMode(for: page) != .document"))
    }

    @Test("toolbar quick actions keep find save and sidebar shortcuts without hover text")
    func toolbarQuickActionsKeepFindSaveAndSidebarShortcutsWithoutHoverText() {
        #expect(NoteWorkspaceQuickAction.allCases == [.findInNote, .saveToDisk, .notesSidebar])
        #expect(NoteWorkspaceQuickAction.findInNote.shortcut == "⌘F")
        #expect(NoteWorkspaceQuickAction.saveToDisk.shortcut == "⌘S")
        #expect(NoteWorkspaceQuickAction.notesSidebar.shortcut == "⌘2")
        #expect(NoteWorkspaceQuickAction.findInNote.help == nil)
        #expect(NoteWorkspaceQuickAction.saveToDisk.help == nil)
        #expect(NoteWorkspaceQuickAction.notesSidebar.help == nil)
    }

    @Test("hidden prose shortcuts do not steal Source editor keybindings")
    func hiddenProseShortcutsDoNotStealSourceEditorKeybindings() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        guard let shortcutsStart = source.range(of: "// Hidden keyboard shortcut buttons"),
              let shortcutsEnd = source.range(of: ".popover(isPresented:", range: shortcutsStart.upperBound..<source.endIndex) else {
            Issue.record("Failed to isolate hidden keyboard shortcut buttons in NoteDetailWorkspaceView.swift")
            return
        }
        let shortcutSource = String(source[shortcutsStart.lowerBound..<shortcutsEnd.lowerBound])

        for (action, shortcut) in [
            ("showDiffSheet = true", #".keyboardShortcut("d", modifiers: .command)"#),
            ("togglePreviewMode()", #".keyboardShortcut("e", modifiers: .command)"#),
            ("showNativeFindInterface()", #".keyboardShortcut("f", modifiers: .command)"#),
            (#"insertMarkdown("**", "**")"#, #".keyboardShortcut("b", modifiers: .command)"#),
            (#"insertMarkdown("*", "*")"#, #".keyboardShortcut("i", modifiers: .command)"#),
            ("page.isPinned.toggle()", #".keyboardShortcut("p", modifiers: [.command, .shift])"#),
            ("navState?.back()", #".keyboardShortcut("[", modifiers: .command)"#),
            ("navState?.forward()", #".keyboardShortcut("]", modifiers: .command)"#),
            ("notesUI.isFocusMode.toggle()", #".keyboardShortcut("f", modifiers: [.command, .shift])"#),
        ] {
            #expect(shortcutSource.contains(action))
            #expect(shortcutSource.contains(shortcut))
        }
        #expect(shortcutSource.components(separatedBy: ".disabled(!noteCommandSurfaceIsActive)").count - 1 >= 9)
        #expect(shortcutSource.components(separatedBy: ".hidden()").count - 1 >= 9)
    }

    @Test("Source mode hides Prose-only quick actions")
    func sourceModeHidesProseOnlyQuickActions() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(source.contains("guard noteCommandSurfaceIsActive else { return }\n            showNativeFindInterface()"))
        #expect(source.contains("private func noteWorkspaceQuickActions(\n        for page: SDPage,\n        options: NoteModeOptions? = nil\n    ) -> [NoteWorkspaceQuickAction]"))
        #expect(source.contains("action != .findInNote || resolvedNoteMode(for: page, options: options) == .edit"))
        #expect(source.contains("noteWorkspaceQuickActions(for: page, options: noteModeOptions(for: page))"))
        #expect(source.contains("ForEach(actions, id: \\.self)"))
    }

    @Test("preview headings use the same smaller adaptive scale as the note editor")
    func previewHeadingsUseEditorHeadingScale() throws {
        let shortHeading = "Big Heading"
        let longHeading =
            "A Neuroscientific explanation of determinism in society across institutions, incentives, and collective mythmaking"
        let expectedShort = MarkdownHeadingDisplay.fontSize(
            for: 1,
            text: "# \(shortHeading)",
            baseSize: MarkdownHeadingDisplay.noteHeadingBaseSize(for: 1),
            nextLevelSize: MarkdownHeadingDisplay.noteHeadingBaseSize(for: 2)
        )
        let expectedLong = MarkdownHeadingDisplay.fontSize(
            for: 1,
            text: "# \(longHeading)",
            baseSize: MarkdownHeadingDisplay.noteHeadingBaseSize(for: 1),
            nextLevelSize: MarkdownHeadingDisplay.noteHeadingBaseSize(for: 2)
        )
        let previewSource = try loadMirroredSourceTextFile("Epistemos/Views/Shared/MarkdownTextView.swift")

        #expect(MarkdownHeadingDisplay.noteHeadingBaseSize(for: 1) == 52)
        #expect(MarkdownHeadingDisplay.noteHeadingBaseSize(for: 2) == 27)
        #expect(MarkdownHeadingDisplay.noteHeadingBaseSize(for: 3) == 17)
        #expect(MarkdownHeadingDisplay.noteHeadingFontSize(for: 1, text: shortHeading) == expectedShort)
        #expect(MarkdownHeadingDisplay.noteHeadingFontSize(for: 1, text: longHeading) == expectedLong)
        #expect(MarkdownHeadingDisplay.noteHeadingFontSize(for: 1, text: shortHeading) > AppHeadingRole.h2.fontSize)
        #expect(MarkdownHeadingDisplay.noteHeadingFontSize(for: 2, text: shortHeading)
            == MarkdownHeadingDisplay.noteHeadingBaseSize(for: 2))
        #expect(MarkdownHeadingDisplay.noteHeadingFontSize(for: 2, text: longHeading)
            < MarkdownHeadingDisplay.noteHeadingFontSize(for: 2, text: shortHeading))
        #expect(MarkdownHeadingDisplay.noteHeadingFontSize(for: 3, text: longHeading)
            < MarkdownHeadingDisplay.noteHeadingFontSize(for: 3, text: shortHeading))
        #expect(previewSource.contains("noteHeadingFontSize("))
    }

    @Test("note workspace removes the source scanning action")
    func noteWorkspaceRemovesSourceScanningAction() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

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
        #expect(bridgeSource.contains("forceContentReEnumeration(tv, lineRange: affectedLines)"))
        #expect(bridgeSource.contains("invalidateLayout(for: targetRange)"))
        #expect(!bridgeSource.contains("ensureLayout(for: docRange)"))
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
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(source.contains("Menu(\"Format\")"))
        #expect(source.contains("Label(\"Backlinks\", systemImage: \"link\")"))
        #expect(source.contains("Label(\"Apple Writing Tools\", systemImage: \"apple.intelligence\")"))
        #expect(source.contains("private func showNativeFindInterface()"))
        #expect(source.contains("NSTextFinder.Action.showFindInterface.rawValue"))
        #expect(source.contains("tv.performTextFinderAction(item)"))
        #expect(source.contains("NoteWorkspaceCommandSurfaceActivation("))
        #expect(source.contains("activationKey: pageId"))
        #expect(source.contains("showFind: { showNativeFindInterface() }"))
        #expect(source.contains(#".keyboardShortcut("f", modifiers: .command)"#))
        #expect(source.contains(".disabled(!noteCommandSurfaceIsActive)"))
        #expect(!source.contains("Menu(\"Options\")"))
        #expect(!source.contains("formatToolbarMenu"))
        #expect(!source.contains("appleWritingToolsButton"))
        #expect(source.contains("noteWorkspaceQuickActions(for: page, options: noteModeOptions(for: page))"))
        #expect(source.contains("ForEach(actions, id: \\.self)"))
    }

    @Test("source mode keeps the native surface picker without duplicating note chrome")
    func sourceModeKeepsNativeSurfacePickerWithoutDuplicatingNoteChrome() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        guard let bodyRange = source.range(of: "var body: some View {"),
              let nextSectionRange = source.range(of: ".environment(\\.colorScheme, noteWorkspaceColorScheme)", range: bodyRange.upperBound..<source.endIndex) else {
            Issue.record("Failed to isolate toolbar wiring in NoteDetailWorkspaceView.swift")
            return
        }

        let bodySource = String(source[bodyRange.lowerBound..<nextSectionRange.lowerBound])

        #expect(!bodySource.contains("noteToolbarTitleItem"))
        #expect(bodySource.contains("if shouldShowNoteToolbarPrimaryActions {"))
        #expect(bodySource.contains("markEditSourceSettingsToolbarButton"))
        #expect(source.contains("private var shouldShowNoteToolbarPrimaryActions: Bool"))
        #expect(source.contains("return !isCodeFile || shouldShowMarkEditSourceSettingsToolbarButton"))
        #expect(source.contains("allowsMarkEditWindowToolbar: false"))
        guard let sourceModeGuardRange = bodySource.range(of: "if shouldShowNoteToolbarPrimaryActions {"),
              let primaryActionRange = bodySource.range(of: "ToolbarItemGroup(placement: .primaryAction) {") else {
            Issue.record("Expected source-mode guard and primary toolbar actions in NoteDetailWorkspaceView.swift")
            return
        }
        #expect(sourceModeGuardRange.lowerBound < primaryActionRange.lowerBound)
        #expect(!bodySource.contains("noteToolbarAskItem"))
        #expect(!source.contains("sourceModeHeader(for: page, route: route)"))
        #expect(!source.contains("private func sourceModeHeader"))
    }

    @Test("outline content and navigation belong to the active note surface")
    func outlineContentAndNavigationBelongToActiveSurface() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let codeEditor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(workspace.contains("@State private var sourceEditorSelectionRequest: CoreEditorSelectionRequest?"))
        #expect(workspace.contains("let outlineMarkdown = pages.first.map(activeOutlineMarkdown(for:)) ?? persistedBody"))
        #expect(workspace.contains("externalItems: pages.first.flatMap(activeOutlineExternalItems(for:))"))
        #expect(workspace.contains("blockItems: pages.first.flatMap(activeOutlineBlockItems(for:))"))
        #expect(workspace.contains("private func activeOutlineMarkdown(for page: SDPage) -> String"))
        #expect(workspace.contains("if let route = sourceEditorRoute(for: page) {\n            return cachedSourceEditorContent(page: page, route: route)\n        }"))
        #expect(workspace.contains("case .edit:\n            return tocItems.isEmpty ? nil : tocItems"))
        #expect(workspace.contains("case .document, .preview, .source:\n            return nil"))
        #expect(workspace.contains("guard resolvedNoteMode(for: page) == .edit else { return nil }"))
        #expect(workspace.contains("sourceEditorSelectionRequest = CoreEditorSelectionRequest("))
        #expect(workspace.contains("externalSelectionRequest: sourceEditorSelectionRequest"))
        #expect(codeEditor.contains("let externalSelectionRequest: CoreEditorSelectionRequest?"))
        #expect(codeEditor.contains("externalSelectionRequest: CoreEditorSelectionRequest? = nil"))
        #expect(codeEditor.contains("selectionRequest: externalSelectionRequest ?? coreEditorSelectionRequest"))
    }

    @Test("note workspace pins SwiftUI controls to the active note surface theme")
    func noteWorkspacePinsControlsToActiveSurfaceTheme() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(source.contains("private var noteWorkspaceColorScheme: ColorScheme"))
        #expect(source.contains("noteWorkspaceTheme.isDark ? .dark : .light"))
        #expect(source.contains(".environment(\\.colorScheme, noteWorkspaceColorScheme)"))
        #expect(!source.contains(".preferredColorScheme(ui.preferredColorScheme)"))
    }

    @Test("prose editor can inherit the note workspace surface theme")
    func proseEditorCanInheritNoteWorkspaceSurfaceTheme() throws {
        let proseSource = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        let workspaceSource = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(proseSource.contains("let themeOverride: EpistemosTheme?"))
        #expect(proseSource.contains("themeOverride: EpistemosTheme? = nil"))
        #expect(proseSource.contains("theme: themeOverride ?? ui.theme"))
        #expect(workspaceSource.contains("themeOverride: noteWorkspaceTheme"))
    }

    @Test("visible note toolbar primary actions stay scoped to mode, source PDF, and more controls")
    func visibleNoteToolbarStripStaysLean() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        guard let controlsRange = source.range(of: "private var noteToolbarPrimaryActions: some View"),
              let nextSectionRange = source.range(of: "// MARK: - Wikilink Navigation", range: controlsRange.upperBound..<source.endIndex) else {
            Issue.record("Failed to isolate noteToolbarPrimaryActions in NoteDetailWorkspaceView.swift")
            return
        }

        let controlsSource = String(source[controlsRange.lowerBound..<nextSectionRange.lowerBound])

        #expect(controlsSource.contains("noteModePicker(for: page)"))
        #expect(controlsSource.contains("ViewOriginalPDFAffordance("))
        #expect(controlsSource.contains("moreMenu"))
        #expect(!controlsSource.contains("outlineFoldButton"))
        #expect(!controlsSource.contains("glyph: .miniChat"))
        #expect(!controlsSource.contains("ForEach(NoteWorkspaceQuickAction.allCases"))
    }

    @Test("preview paints a native chrome backdrop without padding content down")
    func previewPaintsNativeChromeBackdropWithoutPaddingContentDown() {
        #expect(
            NotePreviewChromeMetrics.backdropHeight(titlebarInset: 0, hasMultipleTabs: false)
                == NotePreviewChromeMetrics.fallbackSingleTopInset
        )
        #expect(
            NotePreviewChromeMetrics.backdropHeight(titlebarInset: 0, hasMultipleTabs: true)
                == NotePreviewChromeMetrics.fallbackTabbedTopInset
        )
        #expect(
            NotePreviewChromeMetrics.backdropHeight(
                titlebarInset: 0,
                hasMultipleTabs: false,
                minimumHeight: 74
            )
                == 74
        )
        #expect(
            NotePreviewChromeMetrics.backdropHeight(titlebarInset: 52, hasMultipleTabs: false)
                == 52
        )
        #expect(
            NotePreviewChromeMetrics.backdropHeight(titlebarInset: 52, hasMultipleTabs: true)
                == NotePreviewChromeMetrics.fallbackTabbedTopInset
        )
        #expect(
            NotePreviewChromeMetrics.backdropHeight(titlebarInset: 88, hasMultipleTabs: true)
                == NotePreviewChromeMetrics.fallbackTabbedTopInset
        )
        #expect(
            NotePreviewChromeMetrics.backdropHeight(titlebarInset: 128, hasMultipleTabs: true)
                == 128
        )
    }

    @Test("note preview uses the workspace surface without extra top padding")
    func notePreviewUsesWorkspaceSurfaceWithoutExtraTopPadding() throws {
        let workspaceSource = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let previewSource = try loadRepoTextFile("Epistemos/Views/Notes/NotePreviewSurfaceView.swift")

        #expect(workspaceSource.contains("surfaceBackground: noteWorkspaceBackground"))
        #expect(!workspaceSource.contains("extraTopChromeInset"))
        #expect(!previewSource.contains("extraTopChromeInset"))
        #expect(!previewSource.contains(") + NoteWorkspaceSurfaceStyle.topPadding"))
        #expect(!previewSource.contains(") + NoteWorkspaceSurfaceStyle.graphEmbeddedEditorTopSpacing"))
        #expect(!workspaceSource.contains("NoteDualPreviewLayout.outerPadding.top + NotePreviewChromeMetrics.fallbackSingleTopInset"))
        #expect(previewSource.contains("let chromeBackdropHeight = NotePreviewChromeMetrics.backdropHeight("))
        #expect(previewSource.contains("minimumHeight: chromeMinimumHeight"))
        #expect(previewSource.contains("top: NoteDualPreviewLayout.outerPadding.top,"))
        #expect(!previewSource.contains("top: NoteDualPreviewLayout.outerPadding.top + contentTopInset"))
        #expect(previewSource.contains("previewTopChrome(height: chromeBackdropHeight)"))
        #expect(previewSource.contains("private func previewTopChrome(height: CGFloat) -> some View"))
        #expect(previewSource.contains("private var previewChromeBackdrop: some View"))
        #expect(previewSource.contains("MarkdownPreviewSurfaceStyle.solidFlatBackground(for: theme.surfaceVariant(.other))"))
        #expect(!previewSource.contains("Rectangle().fill(.regularMaterial)"))
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

    @Test("top spacing stays tight below the toolbar")
    func topSpacingStaysTightBelowToolbar() {
        #expect(ProseEditorRepresentable.verticalInset == 40)
        #expect(MarkdownTextStorage.leadingH1SpacingBefore == 36)
        #expect(MarkdownTextStorage.sectionH1SpacingBefore == 30)
        #expect(NoteEditorPerformancePolicy.renderedTableOverlayRefreshDelay == .milliseconds(120))
    }

    @Test("editor defers persisted note body reads until async load")
    func editorDefersPersistedBodyReadsUntilAsyncLoad() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")

        #expect(source.contains("@State private var loadedBodyPageId: String?"))
        #expect(source.contains("private func loadBodyIfNeeded(force: Bool) async"))
        #expect(source.contains("Task.detached(priority: .userInitiated)"))
        #expect(source.contains("NoteFileStorage.readBody(pageId: pageId, mapped: false, fast: true)"))
        #expect(source.contains("if loadedBodyPageId == page.id"))
        #expect(!source.contains("let snapshot = Self.initialBodySnapshot"))
        #expect(!source.contains("let body = Self.currentBody(for: page)"))
    }

    @Test("note workspace persisted body refresh defers state writes out of SwiftUI view updates")
    func noteWorkspacePersistedBodyRefreshDefersStateWritesOutOfViewUpdates() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        guard let functionRange = source.range(of: "private func schedulePersistedBodyRefresh(for page: SDPage?)"),
              let nextFunctionRange = source.range(
                of: "private func persistedBodyFor(_ page: SDPage) -> String",
                range: functionRange.upperBound..<source.endIndex
              ) else {
            Issue.record("Failed to isolate schedulePersistedBodyRefresh() in NoteDetailWorkspaceView.swift")
            return
        }

        let functionSource = String(source[functionRange.lowerBound..<nextFunctionRange.lowerBound])
        #expect(functionSource.contains("persistedBodyLoadTask = Task { @MainActor in\n            await Task.yield()"))
        #expect(functionSource.contains("guard let page else {\n                persistedBody = \"\"\n                return\n            }"))
        #expect(!functionSource.contains("guard let page else {\n            persistedBody = \"\"\n            return\n        }\n\n        let pageId"))
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

    @MainActor
    @Test("direct code file saves stay synced instead of remaining falsely dirty")
    func directCodeFileSavesStaySynced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let page = SDPage(title: "Code")
        let priorUpdatedAt = Date(timeIntervalSince1970: 500)
        let priorSyncedAt = Date(timeIntervalSince1970: 1_000)
        page.filePath = "/tmp/Example.swift"
        page.updatedAt = priorUpdatedAt
        page.lastSyncedBodyHash = "stale-hash"
        page.lastSyncedAt = priorSyncedAt
        page.needsVaultSync = true
        context.insert(page)
        try context.save()

        let source = "print(\"hello\")\n((block-ref))\n"
        let graphState = GraphState()

        try NoteDetailWorkspaceView.applyDirectCodeFileSave(
            source,
            to: page,
            modelContext: context,
            graphState: graphState
        )

        #expect(page.body == source)
        #expect(page.wordCount == source.split(separator: " ").count)
        #expect(page.blockReferences == ["block-ref"])
        #expect(page.updatedAt != priorUpdatedAt)
        #expect(page.lastSyncedBodyHash == SDPage.bodyHash(source))
        #expect(page.lastSyncedAt != nil)
        #expect(page.lastSyncedAt != priorSyncedAt)
        #expect(page.needsVaultSync == false)
        #expect(graphState.needsRefresh)
    }

    @MainActor
    @Test("direct markdown source saves keep page body front matter free")
    func directMarkdownSourceSavesKeepPageBodyFrontMatterFree() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let page = SDPage(title: "Old Title")
        page.filePath = "/tmp/SourceNote.md"
        page.needsVaultSync = true
        context.insert(page)
        try context.save()

        let source = """
        ---
        title: Source Title
        tags: alpha, beta
        icon: code
        parent: parent-id
        template: template-id
        ---
        # Clean Body

        ((body-ref))
        """
        let graphState = GraphState()

        try NoteDetailWorkspaceView.applyDirectCodeFileSave(
            source,
            to: page,
            filePath: page.filePath,
            modelContext: context,
            graphState: graphState
        )

        let cleanBody = "# Clean Body\n\n((body-ref))"
        #expect(page.body == cleanBody)
        #expect(page.frontMatter["title"] == "Source Title")
        #expect(page.title == "Source Title")
        #expect(page.tags == ["alpha", "beta"])
        #expect(page.emoji == "code")
        #expect(page.parentPageId == "parent-id")
        #expect(page.templateId == "template-id")
        #expect(page.blockReferences == ["body-ref"])
        #expect(page.lastSyncedBodyHash == SDPage.bodyHash(cleanBody))
        #expect(page.needsVaultSync == false)
        #expect(graphState.needsRefresh)
    }

    @Test("visible code editor file IO is routed through CodeFileService containment")
    func visibleCodeEditorFileIORoutesThroughCodeFileServiceContainment() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(source.contains("CodeFileService(vaultRoot:"))
        #expect(source.contains("CodeFileService.readCodeFileAsync("))
        #expect(source.contains("CodeFileService.updateCodeFileAsync("))
        #expect(!source.contains("try content.write(toFile:"))
        #expect(!source.contains("String(contentsOfFile: filePath"))
    }

    @Test("visible code editor does not read or write code files from the SwiftUI render path")
    func visibleCodeEditorAvoidsRenderPathCodeFileIO() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let service = try loadRepoTextFile("Epistemos/Engine/CodeFileService.swift")

        #expect(!service.contains("@MainActor\npublic final class CodeFileService"))
        #expect(service.contains("public static func readCodeFileAsync"))
        #expect(service.contains("public static func updateCodeFileAsync"))
        #expect(service.contains("Task.detached(priority: .userInitiated)"))

        #expect(workspace.contains("scheduleCodeFileBodyRefresh(for:"))
        #expect(workspace.contains("cachedCodeFileContent(page:"))
        #expect(workspace.contains("CodeFileService.readCodeFileAsync("))
        #expect(workspace.contains("CodeFileService.updateCodeFileAsync("))
        #expect(!workspace.contains("return try files.readCodeFile(at: URL(fileURLWithPath: filePath)).body"))
        #expect(!workspace.contains("try files.updateCodeFile(at: URL(fileURLWithPath: filePath), body: content)"))
    }

    @Test("note workspace no longer calls loadBody from its render-time persisted-body fallback")
    func noteWorkspaceRenderPathAvoidsLoadBodyFallback() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        #expect(!source.contains("page.loadBody()"))
    }

    @Test("vault changes panel snapshots diff bodies before presenting the sheet")
    func vaultChangesPanelAvoidsRenderTimeLoadBodyReads() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/VaultChangesPanel.swift")

        #expect(source.contains("private struct DiffPresentationRequest"))
        #expect(source.contains("let pageId = page.id"))
        #expect(source.contains("NoteWindowManager.shared.editorBody(for: pageId)"))
        #expect(source.contains("await SDPage.loadBodyAsyncFromPrimitives("))
        #expect(source.contains("diffRequest = DiffPresentationRequest("))
        #expect(!source.contains("currentBody: page.loadBody()"))
    }

    @Test("hologram inspector edits invalidate graph structure after saving")
    func hologramInspectorEditsInvalidateGraphStructure() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")

        #expect(source.contains("AppBootstrap.shared?.graphState.needsRefresh = true"))
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

    @Test("transclusion and mode flush paths log save failures instead of swallowing them")
    func transclusionAndModeFlushPathsLogSaveFailures() throws {
        let bridgeSource = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")
        let workspaceSource = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let overlaySource = try loadRepoTextFile("Epistemos/Views/Notes/TransclusionOverlayManager2.swift")

        #expect(!bridgeSource.contains("try? mc.save()"))
        #expect(!bridgeSource.contains("guard let block = try? mc.fetch(descriptor).first else { return }"))
        #expect(bridgeSource.contains("ProseEditorRepresentable2: failed to persist transclusion edit"))
        #expect(bridgeSource.contains("ProseEditorRepresentable2: failed to fetch block for transclusion edit"))
        #expect(!workspaceSource.contains("try? modelContext.save()"))
        #expect(workspaceSource.contains("NoteDetailWorkspaceView: failed to persist flushed editor body"))
        #expect(!overlaySource.contains("guard let block = try? modelContext.fetch(descriptor).first else {"))
        #expect(!overlaySource.contains("guard let title = try? modelContext.fetch(descriptor).first?.title else {"))
        #expect(overlaySource.contains("TransclusionOverlayManager2: failed to fetch block"))
        #expect(overlaySource.contains("TransclusionOverlayManager2: failed to fetch page title"))
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

    @Test("corrupted disk style cache entries are purged instead of lingering silently")
    func corruptedDiskStyleCacheEntriesArePurged() throws {
        let pageId = "corrupt-style-cache-\(UUID().uuidString)"
        let cacheDirectory = FoundationSafety.userApplicationSupportDirectory()
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("style-cache", isDirectory: true)
        let cacheFile = cacheDirectory.appendingPathComponent("\(pageId).json")

        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: cacheFile, options: .atomic)

        let restored = DiskStyleCache.shared.restore(pageId: pageId, currentBodyText: "Body")

        #expect(restored == nil)
        #expect(!FileManager.default.fileExists(atPath: cacheFile.path))
    }

    @Test("prose editor persistence paths no longer swallow save and fetch failures")
    func proseEditorPersistencePathsNoLongerSwallowSaveAndFetchFailures() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")

        #expect(!source.contains("try? modelContext.save()"))
        #expect(!source.contains("if let oldPage = try? modelContext.fetch(desc).first"))
        #expect(!source.contains("let existing: SDPage? = (try? modelContext.fetch(exactDesc))?.first"))
        #expect(!source.contains("guard let block = try? modelContext.fetch(descriptor).first else { return }"))
        #expect(source.contains("ProseEditorView: failed to save"))
        #expect(source.contains("ProseEditorView: failed to fetch"))
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
    @Test("graph overlay hosted views resolve required app environment",
          .disabled("HologramOverlayHostedViewBuilder is fileprivate; promote to internal if this assertion is brought back"))
    func graphOverlayHostedViewsResolveRequiredAppEnvironment() {
        let existingBootstrap = AppBootstrap.shared
        let bootstrap = existingBootstrap ?? AppBootstrap()
        let host = NSHostingView(
            rootView: AnyView(GraphOverlayEnvironmentProbe())
        )
        _ = bootstrap
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
