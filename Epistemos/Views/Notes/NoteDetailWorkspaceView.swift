import AppKit
import CoreSpotlight
import SwiftData
import SwiftUI
import Translation
import UniformTypeIdentifiers
import os

private struct EditorMetricsSnapshot: Sendable {
    let wordCount: Int
    let headings: [TOCItem]
}

struct NoteModeBodySnapshot: Equatable {
    let pageId: String
    let body: String

    func body(ifMatches currentPageId: String) -> String? {
        guard pageId == currentPageId else { return nil }
        return body
    }
}

private struct CodeFileBodySnapshot: Equatable, Sendable {
    let pageId: String
    let filePath: String
    let body: String

    func body(ifMatches currentPageId: String, filePath currentFilePath: String) -> String? {
        guard pageId == currentPageId, filePath == currentFilePath else { return nil }
        return body
    }
}

enum NoteWorkspaceMode: String, CaseIterable, Hashable {
    case edit
    case document
    case preview
    case source

    var label: String {
        switch self {
        case .edit:
            "Edit/Prose"
        case .document:
            "Document"
        case .preview:
            "Preview"
        case .source:
            "Source"
        }
    }

    /// Fuller hover description than the terse label — "Source" and "Document" aren't
    /// self-evident (owner discoverability request 2026-07-03).
    var helpText: String {
        switch self {
        case .edit:
            "Edit — write in rich prose"
        case .document:
            "Document — rich block editor (headings, lists, tables)"
        case .preview:
            "Preview — rendered, read-only view"
        case .source:
            "Source — the raw Markdown"
        }
    }

    var symbolName: String {
        switch self {
        case .edit:
            "pencil"
        case .document:
            "doc.richtext"
        case .preview:
            "eye"
        case .source:
            "chevron.left.forwardslash.chevron.right"
        }
    }
}

private struct SourceEditorRoute {
    let filePath: String
    let language: String
    /// True for a DISPLAY-ONLY note-backed markdown route (a note with no on-disk file yet).
    /// The filePath is a display label + snapshot key only — never written to page.filePath and
    /// never written to disk; the real dedup'd path is assigned by vault export. (source-toggle 2026-07-01)
    var isNoteBacked: Bool = false

    var isMarkdown: Bool {
        CodeLanguage.isMarkdownDocument(path: filePath)
    }
}

private struct NoteModeOptions {
    let modes: [NoteWorkspaceMode]
    let sourceRoute: SourceEditorRoute?
}

private struct SourceEditorPersistedContent {
    private struct MarkdownMetadata {
        let frontMatter: [String: String]
        let title: String
        let tags: [String]
        let emoji: String
        let parentPageId: String?
        let templateId: String?
    }

    let body: String
    private let markdownMetadata: MarkdownMetadata?

    var isMarkdownSource: Bool {
        markdownMetadata != nil
    }

    init(rawContent: String, filePath: String?) {
        guard CodeLanguage.isMarkdownDocument(path: filePath) else {
            body = rawContent
            markdownMetadata = nil
            return
        }

        let fileURL = filePath.map { URL(fileURLWithPath: $0) }
        let shouldParseFrontMatter = fileURL.map {
            VaultIndexActor.shouldWriteMarkdownFrontMatter(to: $0)
        } ?? false
        let parsed: ([String: String], String) = shouldParseFrontMatter
            ? VaultIndexActor.parseFrontMatter(rawContent)
            : ([:], rawContent)
        let title = parsed.0["title"] ?? fileURL?.deletingPathExtension().lastPathComponent ?? ""

        body = parsed.1
        markdownMetadata = MarkdownMetadata(
            frontMatter: parsed.0,
            title: title,
            tags: parsed.0["tags"]?.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            } ?? [],
            emoji: parsed.0["icon"] ?? "",
            parentPageId: parsed.0["parent"],
            templateId: parsed.0["template"]
        )
    }

    @MainActor
    func apply(to page: SDPage) {
        page.body = body
        if let metadata = markdownMetadata {
            page.frontMatter = metadata.frontMatter
            page.title = VaultIndexActor.sanitizeTitle(metadata.title.isEmpty ? page.title : metadata.title)
            page.tags = metadata.tags
            page.emoji = metadata.emoji
            page.parentPageId = metadata.parentPageId
            page.templateId = metadata.templateId
        }
        page.blockReferences = SDPage.extractBlockReferences(from: body)
        page.wordCount = body.split(separator: " ").count
    }
}

enum NoteEditorViewFinder {
    static func findEditorTextView(for pageId: String? = nil) -> NSTextView? {
        if let tv = noteEditorTextView(
            from: NSApp.keyWindow?.firstResponder as AnyObject?,
            matchingPageId: pageId
        ) {
            return tv
        }
        if let tv = noteEditorTextView(in: NSApp.keyWindow, matchingPageId: pageId) {
            return tv
        }
        if let tv = noteEditorTextView(in: NSApp.mainWindow, matchingPageId: pageId) {
            return tv
        }
        for window in noteWindows() {
            if let tv = noteEditorTextView(in: window, matchingPageId: pageId) {
                return tv
            }
        }
        return nil
    }

    static func findTextView(in view: NSView?, matchingPageId pageId: String? = nil) -> NSTextView?
    {
        guard let view else { return nil }
        if let tv = noteEditorTextView(from: view, matchingPageId: pageId) {
            return tv
        }
        for subview in view.subviews {
            if let tv = findTextView(in: subview, matchingPageId: pageId) {
                return tv
            }
        }
        return nil
    }

    private static func noteWindows() -> [NSWindow] {
        NSApp.windows.filter { $0.tabbingIdentifier == "epistemos-note-tabs" && $0.isVisible }
    }

    private static func noteEditorTextView(in window: NSWindow?, matchingPageId pageId: String?)
        -> NSTextView?
    {
        guard let window else { return nil }
        if let tv = noteEditorTextView(
            from: window.firstResponder as AnyObject?,
            matchingPageId: pageId
        ) {
            return tv
        }
        return findTextView(in: window.contentView, matchingPageId: pageId)
    }

    private static func noteEditorTextView(from object: AnyObject?, matchingPageId pageId: String?)
        -> NSTextView?
    {
        switch object {
        case let tv as ProseTextView2 where matches(tv, pageId: pageId):
            return tv
        default:
            return nil
        }
    }

    private static func matches(_ textView: NSTextView, pageId: String?) -> Bool {
        guard textView.isEditable else { return false }
        guard let tv = textView as? ProseTextView2 else { return false }
        guard let pageId else { return true }
        return tv.pageId == pageId
    }
}

enum NoteEditorNotifications {
    static let replaceRange = Notification.Name("EpistemosReplaceRange")
}

enum NoteToolbarMetrics {
    static let iconSide: CGFloat = 14
    static let buttonSide: CGFloat = 28
    static let stopBallSize: CGFloat = 22
    static let spacing: CGFloat = 6
    static let chatFieldWidth: CGFloat = 220
    static let stripGlowBlurRadius: CGFloat = 6
}

enum NoteToolbarPalette {
    static func stripGlowOpacity(for theme: EpistemosTheme) -> Double {
        0
    }

    static func iconOpacity(for theme: EpistemosTheme, isActive: Bool) -> Double {
        if isActive {
            return theme.isDark ? 0.92 : 0.82
        }
        return theme.isDark ? 0.86 : 0.74
    }
}

enum NoteToolbarDisplay {
    static let hidesMenuIndicators = true
}

enum NoteWorkspacePresentation: Equatable {
    case window
    case embeddedGraph

    var usesWindowToolbar: Bool { self == .window }
    var usesGraphEmbeddedChrome: Bool { self == .embeddedGraph }
}

enum NoteWorkspaceSurfaceStyle {
    static let minimumEditorSize = CGSize(width: 400, height: 300)
    static let editorCornerRadius: CGFloat = 26
    static let editorMaxWidth: CGFloat = 1080
    static let horizontalPadding: CGFloat = 28
    static let topPadding: CGFloat = 24
    static let bottomPadding: CGFloat = 72
    static let graphEmbeddedToolbarCornerRadius: CGFloat = 22
    static let graphEmbeddedEditorToolbarClearance: CGFloat = 74
    static let graphEmbeddedPreviewChromeMinimumHeight: CGFloat = 74

    static func canvasBackground(for theme: EpistemosTheme) -> Color {
        // Eighth pass + 1 (2026-05-13): paint the workspace canvas
        // with the SOLID variant of the preview-card hue. Three
        // requirements stack here:
        //   1. User wanted the workspace to match the preview card
        //      color dynamically per theme (eighth pass).
        //   2. User then noticed the Tiptap WKWebView (`drawsBackground
        //      = false`) was leaking the desktop / system blur through
        //      the canvas because `theme.card` carries a baked-in
        //      0.88-0.92 alpha in most theme palettes, on top of the
        //      0.92-0.96 opacity `flatBackground` was multiplying in.
        //      That gave an effective ~0.85 alpha → visible blur slot.
        //   3. User asked: "can i turn that blur … or do i just make
        //      the color be full solid" — yes, solid.
        // Fix: `solidFlatBackground` returns the same card hue with
        // alpha forced to 1.0 via `NSColor.withAlphaComponent(1.0)`,
        // so the workspace paints a fully opaque themed surface with
        // zero see-through. Preview cards keep their own translucent
        // `flatBackground` so they retain the subtle visual lift over
        // the (now-solid) canvas.
        let surfaceTheme = theme.surfaceVariant(.other)
        if surfaceTheme.usesNativeWindowBlur {
            return MarkdownPreviewSurfaceStyle.canvasBackground(for: surfaceTheme)
        }
        return MarkdownPreviewSurfaceStyle.solidFlatBackground(for: surfaceTheme)
    }

    static func editorCardSize(for availableSize: CGSize) -> CGSize {
        let width = min(
            editorMaxWidth,
            max(minimumEditorSize.width, availableSize.width - (horizontalPadding * 2))
        )
        let height = max(
            minimumEditorSize.height,
            availableSize.height - topPadding - bottomPadding
        )
        return CGSize(width: width, height: height)
    }
}

enum NoteWorkspaceFooterDisplay {
    struct ShortcutHint: Equatable {
        let key: String
        let label: String
    }

    static let showsBottomFade = false
    static let showsShortcutHints = false
    static let chipSpacing: CGFloat = 8
    static let chipHorizontalPadding: CGFloat = 12
    static let chipVerticalPadding: CGFloat = 6
    static let footerPadding: CGFloat = 8
    static let shortcuts: [ShortcutHint] = [
        ShortcutHint(key: "F", label: "Find in Note"),
        ShortcutHint(key: "S", label: "Save to Disk"),
        ShortcutHint(key: "2", label: "Note Sidebar"),
    ]
}

enum NoteWorkspaceQuickAction: CaseIterable, Hashable {
    case findInNote
    case saveToDisk
    case notesSidebar

    var glyph: NoteToolbarGlyph {
        switch self {
        case .findInNote:
            .findInNote
        case .saveToDisk:
            .saveToDisk
        case .notesSidebar:
            .notesSidebar
        }
    }

    var title: String {
        switch self {
        case .findInNote:
            "Find in Note"
        case .saveToDisk:
            "Save to Disk"
        case .notesSidebar:
            "Open Notes Sidebar"
        }
    }

    var shortcut: String {
        switch self {
        case .findInNote:
            "⌘F"
        case .saveToDisk:
            "⌘S"
        case .notesSidebar:
            "⌘2"
        }
    }

    var help: String? {
        nil
    }
}

enum NoteToolbarGlyph: Sendable {
    case format
    case preview
    case edit
    case writingTools
    case more
    case backlinks
    case history
    case recovery
    case findInNote
    case saveToDisk
    case notesSidebar

    var symbolName: String? {
        switch self {
        case .format:
            "textformat"
        case .preview:
            "eye"
        case .edit:
            "pencil"
        case .writingTools:
            "apple.intelligence"
        case .more:
            "ellipsis.circle"
        case .backlinks:
            "link"
        case .history:
            "bubble.left"
        case .recovery:
            "exclamationmark.triangle"
        case .findInNote:
            "magnifyingglass"
        case .saveToDisk:
            "square.and.arrow.down"
        case .notesSidebar:
            "sidebar.leading"
        }
    }

    var activeSymbolName: String? {
        switch self {
        case .history:
            "bubble.left.fill"
        case .recovery:
            "exclamationmark.triangle.fill"
        default:
            symbolName
        }
    }
}



// MARK: - Note Page Content
// Self-contained note editor for each page within a tab.
// Resolves pageId → SDPage via @Query, shows ProseEditorView,
// adds toolbar + Cmd+S / Cmd+Shift+S shortcuts.

struct NoteDetailWorkspaceView: View {
    let pageId: String
    let presentation: NoteWorkspacePresentation

    @Environment(NoteNavigationState.self) private var navState: NoteNavigationState?
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(EventBus.self) private var eventBus
    @Environment(ContextualShadowsState.self) private var contextualShadows
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.graphSurfacePresentation) private var graphSurfacePresentation
    @Query private var pages: [SDPage]
    @State private var showDiffSheet = false
    @State private var showInfoPopover = false
    @State private var showWebClipperSheet = false
    @State private var noteMode: NoteWorkspaceMode = .document
    @State private var showMarkEditSourceSettings = false
    @State private var sourcePDFViewerPresentation: SourcePDFViewerPresentation?
    @State private var modeBodySnapshot: NoteModeBodySnapshot?
    @State private var codeFileBodySnapshot: CodeFileBodySnapshot?
    @State private var sourceEditorSelectionRequest: CoreEditorSelectionRequest?
    @State private var persistedBody: String
    @State private var showLegacyRecoverySheet = false
    @State private var legacyRecoveryPresentation: NoteLegacyRecoveryPresentation?
    @State private var legacyRecoveryRefreshTask: Task<Void, Never>?

    @State private var showIdeasPopover = false
    @State private var showBacklinksPopover = false
    @State private var hasMultipleTabs = false
    @State private var wordCount: Int = 0
    @State private var tocItems: [TOCItem] = []
    /// KC block-outline rows for the outline panel's Blocks mode (Slice 3 cutover,
    /// Option 1). Empty unless the knowledgeCoreRuntimeV0 runtime is standing.
    @State private var blockOutlineItems: [TOCItem] = []
    @State private var hasModelDerivedSidecar = false
    @State private var deterministicOutlineState: KnowledgeCoreOutlineProjectionState
    @State private var wordCountDebounce: Task<Void, Never>?
    @State private var metricsTask: Task<Void, Never>?
    @State private var modelDerivedSidecarTask: Task<Void, Never>?
    @State private var codeFileLoadTask: Task<Void, Never>?
    @State private var persistedBodyLoadTask: Task<Void, Never>?
    @State private var missingPageRecoveryTask: Task<Void, Never>?
    @State private var showBlockPropertySheet = false
    @State private var blockPropertyLineText = ""
    @State private var blockPropertyLineRange = NSRange(location: 0, length: 0)
    @State private var showTranslation = false
    @State private var translationText = ""
    /// Pre-selected idea tab when opened from right-click context menu.
    @State private var contextMenuIdeaTab: IdeasPanel.IdeaTab?
    /// Editor selection captured BEFORE the popover steals focus.
    /// The popover becomes key, deselecting the editor — so we snapshot
    /// the selection range + text at the moment the user opens the panel.
    @State private var capturedSelection: NSRange?
    @State private var capturedSelectionText: String?
    /// Opacity of the greeting overlay (0 = invisible, 1 = fully covering).
    /// Kept always in the view tree to avoid insertion delay.
    @State private var transitionOpacity: Double = 0
    /// The greeting message shown during the current transition.
    @State private var transitionGreeting: String = ""
    /// True while a transition is in flight (prevents rapid re-trigger).
    @State private var isTransitioning = false
    @MainActor
    init(
        pageId: String,
        presentation: NoteWorkspacePresentation = .window,
        // Owner 2026-07-05: Epdoc (.document) is the default note view everywhere (graph embed,
        // in-place pane, windows). resolvedNoteMode falls back for code/non-markdown pages.
        initialMode: NoteWorkspaceMode = .document
    ) {
        self.pageId = pageId
        self.presentation = presentation
        _pages = Query(filter: #Predicate<SDPage> { $0.id == pageId })
        _noteMode = State(initialValue: initialMode)
        _persistedBody = State(initialValue: "")
        _deterministicOutlineState = State(
            initialValue: KnowledgeCoreOutlineProjectionState()
        )
    }

    static func resolvedPersistedBody(_ persistedBody: String, for page: SDPage) -> String {
        if !persistedBody.isEmpty {
            return persistedBody
        }
        return page.body
    }

    private var usesOverlayGraphToolbar: Bool {
        presentation.usesGraphEmbeddedChrome && !usesNativeGraphWindowToolbar
    }

    private var usesNativeGraphWindowToolbar: Bool {
        presentation.usesGraphEmbeddedChrome && graphSurfacePresentation.isEmbeddedHome
    }

    private var usesEmbeddedHomeGraphSurface: Bool {
        presentation.usesGraphEmbeddedChrome && graphSurfacePresentation.isEmbeddedHome
    }

    private var noteWorkspaceTheme: EpistemosTheme {
        usesEmbeddedHomeGraphSurface ? ui.theme.surfaceVariant(.landing) : ui.theme
    }

    private var graphEmbeddedToolbarTheme: EpistemosTheme {
        usesEmbeddedHomeGraphSurface ? noteWorkspaceTheme : ui.theme
    }

    private var noteWorkspaceBackground: Color {
        usesEmbeddedHomeGraphSurface
            ? AppWindowBackdropStyle.background(for: noteWorkspaceTheme)
            : NoteWorkspaceSurfaceStyle.canvasBackground(for: ui.theme)
    }

    private var noteWorkspaceColorScheme: ColorScheme {
        noteWorkspaceTheme.isDark ? .dark : .light
    }

    var body: some View {
        VStack(spacing: 0) {
            noteCanvas
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            noteWorkspaceBackground.ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            if usesOverlayGraphToolbar, let page = pages.first {
                overlayGraphEmbeddedToolbar(page: page)
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .zIndex(20)
            }
        }
        .toolbar {
            let usesNativeToolbar = presentation.usesWindowToolbar || usesNativeGraphWindowToolbar
            if usesNativeToolbar {
                if let nav = navState, nav.hasBreadcrumb {
                    ToolbarItem(placement: .navigation) {
                        wikilinksNavButtons(nav: nav)
                    }
                } else if usesNativeGraphWindowToolbar {
                    ToolbarItem(placement: .navigation) {
                        graphToolbarNavigationControls
                    }
                }
                if usesNativeGraphWindowToolbar, let page = pages.first {
                    ToolbarItem(placement: .principal) {
                        graphEmbeddedToolbarTitle(page)
                    }
                }
                if shouldShowNoteToolbarPrimaryActions {
                    ToolbarItemGroup(placement: .primaryAction) {
                        noteToolbarPrimaryActions
                    }
                }
                #if canImport(MarkEditKit)
                if isCodeFile && shouldShowMarkEditSourceSettingsToolbarButton {
                    ToolbarItem(placement: .primaryAction) {
                        markEditSourceSettingsToolbarButton
                    }
                }
                #endif
            }
        }
        .toolbarBackgroundVisibility(.automatic, for: .windowToolbar)
        .environment(\.colorScheme, noteWorkspaceColorScheme)
        .background {
            NoteWorkspaceCommandSurfaceActivation(
                activationKey: pageId,
                isActive: noteCommandSurfaceIsActive,
                save: saveCurrentNoteToDisk,
                showFind: { showNativeFindInterface() }
            )

            // Hidden keyboard shortcut buttons
            Button("") {
                Task {
                    await NoteCreationCoordinator.createAndOpen(vaultSync: vaultSync)
                }
            }
            .keyboardShortcut("n", modifiers: .command)
            .hidden()
            Button("") { saveCurrentNoteToDisk() }
                .keyboardShortcut("s", modifiers: .command)
                .hidden()
            Button("") { vaultSync.saveAllDirtyPages() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .hidden()
            Button("") { showDiffSheet = true }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(!noteCommandSurfaceIsActive)
                .hidden()
            Button("") { togglePreviewMode() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(!noteCommandSurfaceIsActive)
                .hidden()
            Button("") { showNativeFindInterface() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(!noteCommandSurfaceIsActive)
                .hidden()

            Button("") { insertMarkdown("**", "**") }
                .keyboardShortcut("b", modifiers: .command)
                .disabled(!noteCommandSurfaceIsActive)
                .hidden()
            Button("") { insertMarkdown("*", "*") }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(!noteCommandSurfaceIsActive)
                .hidden()
            Button("") {
                if let page = pages.first {
                    let originalShortcutPinned = page.isPinned
                    page.isPinned.toggle()
                    _ = persistPageMutation(
                        failureMessage: "Save failed (pin shortcut)",
                        restoreState: { page.isPinned = originalShortcutPinned }
                    )
                }
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(!noteCommandSurfaceIsActive)
            .hidden()
            Button("") { navState?.back() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!noteCommandSurfaceIsActive)
                .hidden()
            Button("") { navState?.forward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!noteCommandSurfaceIsActive)
                .hidden()
            Button("") { notesUI.isFocusMode.toggle() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(!noteCommandSurfaceIsActive)
                .hidden()
        }
        .popover(isPresented: $showInfoPopover) {
            if let page = pages.first {
                noteInfoPanel(page: page, currentBody: displayBody(for: page))
            }
        }
        .popover(isPresented: $showIdeasPopover) {
            if let page = pages.first {
                IdeasPanel(
                    page: page,
                    currentBody: displayBody(for: page),
                    initialTab: contextMenuIdeaTab,
                    autoShowForm: contextMenuIdeaTab != nil,
                    capturedSelection: capturedSelection,
                    capturedSelectionText: capturedSelectionText
                )
            }
        }
        .sheet(isPresented: $showDiffSheet) {
            if let page = pages.first {
                DiffSheetView(
                    pageId: page.id,
                    currentTitle: page.title,
                    currentBody: persistedBodyFor(page)
                )
            }
        }
        .sheet(item: $sourcePDFViewerPresentation) { presentation in
            SourcePDFViewerSheet(url: presentation.url)
        }
        .sheet(isPresented: $showWebClipperSheet) {
            WebClipperSheet(theme: ui.theme) { draft in
                try await createWebClip(from: draft)
            }
        }
        .sheet(isPresented: $showLegacyRecoverySheet) {
            if let legacyRecoveryPresentation {
                LegacyRecoverySheet(
                    title: pages.first?.title ?? "Untitled",
                    presentation: legacyRecoveryPresentation,
                    theme: ui.theme
                )
            }
        }
        .sheet(isPresented: $showBlockPropertySheet) {
            BlockPropertySheet(
                existing: BlockPropertyParser.parse(blockPropertyLineText).map {
                    ($0.key, $0.value)
                },
                onSave: { properties in
                    applyBlockProperties(properties, lineRange: blockPropertyLineRange)
                    showBlockPropertySheet = false
                },
                onCancel: { showBlockPropertySheet = false }
            )
        }
        .onChange(of: pages.first?.title) { _, newTitle in
            guard let newTitle, !newTitle.isEmpty else { return }
            navState?.syncTitle(pageId: pageId, title: newTitle)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSWindow.didBecomeMainNotification)
        ) { _ in refreshTabCount() }
        .onReceive(
            // RCA2-P1-012 fix-pass (2026-05-13): subscribe to the
            // unconditional `ProseEditorContentDidChange` notification
            // (fires on every type) instead of the length<=10-gated
            // `ProseEditorUserDidType`. Now word count + outline
            // metrics refresh live for notes of ANY length, not just
            // empty / near-empty ones.
            NotificationCenter.default.publisher(for: .init("ProseEditorContentDidChange"))
        ) { notification in
            guard (notification.userInfo as? [String: String])?["pageId"] == pageId else { return }
            wordCountDebounce?.cancel()
            metricsTask?.cancel()
            wordCountDebounce = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                refreshVisibleEditorMetrics()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: ProseTextView2.createIdeaNotification)
        ) { notif in
            guard (notif.userInfo as? [String: String])?["pageId"] == pageId else { return }
            snapshotEditorSelection()
            contextMenuIdeaTab = .ideas
            showIdeasPopover = true
        }
        .onReceive(
            NotificationCenter.default.publisher(for: ProseTextView2.createBrainDumpNotification)
        ) { notif in
            guard (notif.userInfo as? [String: String])?["pageId"] == pageId else { return }
            snapshotEditorSelection()
            contextMenuIdeaTab = .brainDumps
            showIdeasPopover = true
        }
        .onReceive(
            NotificationCenter.default.publisher(for: ProseTextView2.blockPropertyNotification)
        ) { notif in
            guard let info = notif.userInfo as? [String: Any],
                info["pageId"] as? String == pageId,
                let lineText = info["lineText"] as? String
            else { return }
            blockPropertyLineText = lineText
            if let rangeValue = info["lineRange"] as? NSValue {
                blockPropertyLineRange = rangeValue.rangeValue
            }
            showBlockPropertySheet = true
        }
        .onReceive(
            NotificationCenter.default.publisher(for: ProseTextView2.translateNotification)
        ) { notif in
            guard let info = notif.userInfo as? [String: String],
                info["pageId"] == pageId,
                let text = info["selectedText"], !text.isEmpty
            else { return }
            translationText = text
            showTranslation = true
        }
        .translationPresentation(isPresented: $showTranslation, text: translationText)
        .onChange(of: showIdeasPopover) { _, isShown in
            if !isShown {
                contextMenuIdeaTab = nil
                capturedSelection = nil
                capturedSelectionText = nil
            }
        }
    }

    private var noteCanvas: some View {
        HStack(spacing: 0) {
            ZStack {
                if let page = pages.first {
                    VStack(spacing: 0) {
                        if let legacyRecoveryPresentation,
                           legacyRecoveryPresentation.hasEncodingIssues
                        {
                            LegacyRecoveryBanner(theme: ui.theme) {
                                showLegacyRecoverySheet = true
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 12)
                            .padding(.bottom, 10)
                        }
                        if resolvedNoteMode(for: page) == .preview {
                            notePreview(body: displayBody(for: page))
                        } else {
                            GeometryReader { proxy in
                                noteEditorSurface(page: page, availableSize: proxy.size)
                            }
                        }
                    }
                    .frame(minWidth: 400, minHeight: 300)
                } else {
                    ContentUnavailableView("Note not found", systemImage: "doc.questionmark")
                        .frame(minWidth: 400, minHeight: 300)
                }

                // Transition overlay removed — direct swap between editor/preview
            }
            .overlay(alignment: .bottom) {
                if shouldShowNoteWorkspaceFooter {
                    noteFooter
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                contextualShadowsOverlay
                    .padding(.trailing, 18)
                    .padding(.bottom, 52)
            }
            .overlay(alignment: .trailing) {
                let outlineMarkdown = pages.first.map(activeOutlineMarkdown(for:)) ?? persistedBody
                NoteOutlineOverlay(
                    markdown: outlineMarkdown,
                    theme: ui.theme,
                    onNavigate: { charOffset in
                        navigateActiveOutline(to: charOffset)
                    },
                    externalItems: pages.first.flatMap(activeOutlineExternalItems(for:)),
                    blockItems: pages.first.flatMap(activeOutlineBlockItems(for:))
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(noteWorkspaceBackground)
            .onAppear {
                Task { @MainActor in
                    refreshTabCount()
                    if let page = pages.first {
                        schedulePersistedBodyRefresh(for: page)
                        let body = persistedBodyFor(page)
                        if persistedBody != body {
                            persistedBody = body
                        }
                        scheduleCodeFileBodyRefresh(for: page)
                        refreshModelDerivedSidecarBadge(for: page)
                        refreshLegacyRecoveryPresentation()
                        scheduleMetricsRefresh(
                            body: body,
                            includeMarkdownHeadings: true
                        )
                    } else {
                        refreshModelDerivedSidecarBadge(for: nil)
                        queueMissingPageRecovery()
                    }
                    // Apply pending workspace editor restore (cursor + scroll).
                    if let restore = navState?.pendingEditorRestore {
                        navState?.pendingEditorRestore = nil
                        try? await Task.sleep(for: .milliseconds(100))
                        applyEditorRestore(cursor: restore.cursor, scrollFraction: restore.scrollFraction)
                    }
                }
            }
            .onDisappear {
                wordCountDebounce?.cancel()
                metricsTask?.cancel()
                modelDerivedSidecarTask?.cancel()
                modelDerivedSidecarTask = nil
                codeFileLoadTask?.cancel()
                codeFileLoadTask = nil
                persistedBodyLoadTask?.cancel()
                persistedBodyLoadTask = nil
                missingPageRecoveryTask?.cancel()
                missingPageRecoveryTask = nil
                legacyRecoveryRefreshTask?.cancel()
                legacyRecoveryRefreshTask = nil
            }
            .onChange(of: pages.isEmpty) { _, isEmpty in
                if isEmpty {
                    schedulePersistedBodyRefresh(for: nil)
                    scheduleCodeFileBodyRefresh(for: nil)
                    refreshModelDerivedSidecarBadge(for: nil)
                    queueMissingPageRecovery()
                } else {
                    missingPageRecoveryTask?.cancel()
                    missingPageRecoveryTask = nil
                    schedulePersistedBodyRefresh(for: pages.first)
                    scheduleCodeFileBodyRefresh(for: pages.first)
                    refreshModelDerivedSidecarBadge(for: pages.first)
                    refreshLegacyRecoveryPresentation()
                }
            }
            .onChange(of: pages.first?.filePath) { _, _ in
                scheduleCodeFileBodyRefresh(for: pages.first)
                refreshModelDerivedSidecarBadge(for: pages.first)
            }
            .onReceive(NotificationCenter.default.publisher(for: NoteFileStorage.pageBodyDidChange)) { notification in
                guard let changedId = notification.userInfo?["pageId"] as? String,
                      changedId == pageId else { return }
                schedulePersistedBodyRefresh(for: pages.first)
            }
        }
    }

    private var contextualShadowsOverlay: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ContextualShadowsPanel(
                scopeKind: .note,
                scopeID: pageId,
                onOpen: openContextualShadowHit,
                onInsert: insertContextualShadowPassage
            )
            ContextualShadowsButton(scopeKind: .note, scopeID: pageId)
        }
    }

    private func openContextualShadowHit(_ hit: ContextualShadowsState.RecallHit) {
        switch hit.kind {
        case .note:
            NoteWindowManager.shared.open(pageId: hit.id)
        case .chat:
            break
        }
        contextualShadows.closePanel(kind: .note, originDocId: pageId)
    }

    private func insertContextualShadowPassage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let tv = commandTarget() else { return }
        let quoted = trimmed
            .components(separatedBy: .newlines)
            .map { line in line.isEmpty ? ">" : "> \(line)" }
            .joined(separator: "\n")
        tv.insertText("\n\n\(quoted)\n", replacementRange: tv.selectedRange())
        tv.window?.makeKeyAndOrderFront(nil)
    }

    private func refreshLegacyRecoveryPresentation() {
        legacyRecoveryRefreshTask?.cancel()
        let currentPageId = pageId
        legacyRecoveryRefreshTask = Task { @MainActor in
            let presentation = await Task.detached(priority: .utility) {
                NoteLegacyRecoveryPresentation.load(pageId: currentPageId)
            }.value
            guard !Task.isCancelled, self.pageId == currentPageId else { return }
            legacyRecoveryPresentation = presentation
            if presentation?.hasEncodingIssues != true {
                showLegacyRecoverySheet = false
            }
        }
    }

    /// Whether the current page is routed to the Source editor (code files always,
    /// markdown files only when the current view mode is Source).
    private var isCodeFile: Bool {
        guard let page = pages.first else { return false }
        return sourceEditorRoute(for: page) != nil
    }

    private var noteCommandSurfaceIsActive: Bool {
        guard let page = pages.first else { return false }
        return resolvedNoteMode(for: page) == .edit
    }

    private var shouldShowNoteWorkspaceFooter: Bool {
        guard let page = pages.first else { return false }
        return resolvedNoteMode(for: page) != .document
    }

    private var noteFooter: some View {
        HStack(spacing: NoteWorkspaceFooterDisplay.chipSpacing) {
            // Code files have their own status bar — hide the word count overlay
            if !isCodeFile {
                noteFooterBubble {
                    // 2026-05-13 sixth pass: route the word-count caption
                    // through `theme.captionFontName` so Ember renders
                    // it in MatrixTypeDisplay-Regular instead of the
                    // case-driven ColorBasic boxes. Classic + Platinum
                    // get their hero font as before.
                    Text("\(wordCount) words")
                        .font(.custom(ui.theme.captionFontName, size: 13))
                        .monospacedDigit()
                        .foregroundStyle(ui.theme.resolved.foreground.color.opacity(0.55))
                }

                if hasModelDerivedSidecar {
                    noteFooterBubble {
                        Label("Model-derived", systemImage: "sparkles")
                            .font(AppDisplayTypography.font(size: 12))
                            .foregroundStyle(ui.theme.resolved.foreground.color.opacity(0.58))
                    }
                }
            }

            if NoteWorkspaceFooterDisplay.showsShortcutHints {
                ForEach(NoteWorkspaceFooterDisplay.shortcuts, id: \.key) { shortcut in
                    noteFooterBubble {
                        HStack(spacing: 3) {
                            Image(systemName: "command")
                                .font(.system(size: 10, weight: .medium))
                            Text(shortcut.key)
                                .font(AppDisplayTypography.font(size: 10))
                            Text(shortcut.label)
                                .font(AppDisplayTypography.font(size: 10))
                                .padding(.leading, 2)
                        }
                        .foregroundStyle(ui.theme.resolved.foreground.color.opacity(0.35))
                    }
                }
            }
        }
        .padding(NoteWorkspaceFooterDisplay.footerPadding)
    }

    private func performNoteWorkspaceQuickAction(_ action: NoteWorkspaceQuickAction) {
        switch action {
        case .findInNote:
            guard noteCommandSurfaceIsActive else { return }
            showNativeFindInterface()
        case .saveToDisk:
            saveCurrentNoteToDisk()
        case .notesSidebar:
            UtilityWindowManager.shared.show(.notes)
        }
    }

    private func saveCurrentNoteToDisk() {
        if let page = pages.first,
           let route = sourceEditorRoute(for: page),
           let sourceContent = codeFileBodySnapshot?.body(ifMatches: page.id, filePath: route.filePath) {
            saveCodeFileContent(page: page, filePath: route.filePath, content: sourceContent, noteBacked: route.isNoteBacked)
            return
        }

        flushCurrentEditor()
        vaultSync.savePage(pageId: pageId)
    }

    private func noteWorkspaceQuickActions(
        for page: SDPage,
        options: NoteModeOptions? = nil
    ) -> [NoteWorkspaceQuickAction] {
        NoteWorkspaceQuickAction.allCases.filter { action in
            action != .findInNote || resolvedNoteMode(for: page, options: options) == .edit
        }
    }

    private func showNativeFindInterface() {
        guard let tv = NoteEditorViewFinder.findEditorTextView(for: pageId) else { return }
        tv.window?.makeFirstResponder(tv)
        let item = NSMenuItem()
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        tv.performTextFinderAction(item)
    }

    private var codeFileLineCount: Int {
        guard let page = pages.first,
              let route = sourceEditorRoute(for: page) else { return 0 }
        let content = cachedSourceEditorContent(page: page, route: route)
        return CodeEditorLineMetrics.lineCount(content)
    }

    private func activeOutlineMarkdown(for page: SDPage) -> String {
        if let route = sourceEditorRoute(for: page) {
            return cachedSourceEditorContent(page: page, route: route)
        }
        return displayBody(for: page)
    }

    private func activeOutlineExternalItems(for page: SDPage) -> [TOCItem]? {
        switch resolvedNoteMode(for: page) {
        case .edit:
            return tocItems.isEmpty ? nil : tocItems
        case .document, .preview, .source:
            return nil
        }
    }

    private func activeOutlineBlockItems(for page: SDPage) -> [TOCItem]? {
        guard resolvedNoteMode(for: page) == .edit else { return nil }
        return blockOutlineItems.isEmpty ? nil : blockOutlineItems
    }

    private func noteFooterBubble<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, NoteWorkspaceFooterDisplay.chipHorizontalPadding)
            .padding(.vertical, NoteWorkspaceFooterDisplay.chipVerticalPadding)
            .background(.clear, in: Capsule())
            .glassEffect(.regular.interactive(), in: Capsule())
    }

    private func refreshModelDerivedSidecarBadge(for page: SDPage?) {
        modelDerivedSidecarTask?.cancel()
        guard let path = page?.filePath,
              !path.isEmpty else {
            hasModelDerivedSidecar = false
            return
        }

        let sourceURL = URL(fileURLWithPath: path)
        modelDerivedSidecarTask = Task { @MainActor in
            let isModelDerived = await Task.detached(priority: .utility) {
                EpistemosSidecarStore.isModelDerived(for: sourceURL)
            }.value
            guard !Task.isCancelled else { return }
            hasModelDerivedSidecar = isModelDerived
        }
    }

    @ViewBuilder
    private func noteEditorSurface(page: SDPage, availableSize: CGSize) -> some View {
        Group {
            if resolvedNoteMode(for: page) == .document {
                MarkdownDocumentSurface(
                    pageId: page.id,
                    title: page.title,
                    markdown: displayBody(for: page),
                    theme: noteWorkspaceTheme,
                    saveMarkdown: { markdown in
                        saveMarkdownDocumentSurfaceContent(page: page, markdown: markdown)
                    },
                    surfaceToolbarAccessory: markdownDocumentSurfaceToolbarAccessory(for: page)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if let route = sourceEditorRoute(for: page) {
                VStack(spacing: 0) {
                    CodeEditorView(
                        content: cachedSourceEditorContent(page: page, route: route),
                        language: route.language,
                        filePath: route.filePath,
                        onTextSnapshot: { latestContent in
                            recordSourceEditorSnapshot(
                                page: page,
                                filePath: route.filePath,
                                content: latestContent
                            )
                        },
                        onContentChange: { newContent in
                            saveCodeFileContent(page: page, filePath: route.filePath, content: newContent, noteBacked: route.isNoteBacked)
                        },
                        // SS-GC: in the embedded home graph, give the code editor the same
                        // landing-variant theme the prose branch gets, so its top bar paints the
                        // graph backdrop instead of a white card. nil elsewhere = unchanged.
                        allowsMarkEditWindowToolbar: false,
                        externalSelectionRequest: sourceEditorSelectionRequest,
                        themeOverride: usesEmbeddedHomeGraphSurface ? noteWorkspaceTheme : nil
                    )
                    .id("\(page.id)::\(route.filePath)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .sheet(isPresented: $showMarkEditSourceSettings) {
                    #if canImport(MarkEditKit)
                    MarkEditSourceSettingsSheet()
                    #else
                    EmptyView()
                    #endif
                }
            } else {
                let initialBodyOverride = currentModeBodySnapshot(for: page.id)
                ProseEditorView(
                    page: page,
                    isEditable: true,
                    initialBodyOverride: initialBodyOverride,
                    navigationContext: presentation.usesGraphEmbeddedChrome ? .graph : .notes,
                    themeOverride: noteWorkspaceTheme
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(
            .top,
            usesOverlayGraphToolbar ? NoteWorkspaceSurfaceStyle.graphEmbeddedEditorToolbarClearance : 0
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    /// Saves code file content back to disk and updates associated page state
    private func saveCodeFileContent(page: SDPage, filePath: String, content: String, noteBacked: Bool = false) {
        if CodeLanguage.isMarkdownDocument(path: filePath) {
            saveMarkdownSourceContent(page: page, filePath: filePath, content: content, noteBacked: noteBacked)
            return
        }

        guard let vaultURL = vaultSync.vaultURL else {
            Log.app.error("CodeEditor: failed to save code file because no active vault contains \(filePath, privacy: .private)")
            return
        }

        let fileURL = URL(fileURLWithPath: filePath)
        Task { @MainActor in
            do {
                try await CodeFileService.updateCodeFileAsync(
                    at: fileURL,
                    vaultRoot: vaultURL,
                    body: content
                )
                codeFileBodySnapshot = CodeFileBodySnapshot(
                    pageId: page.id,
                    filePath: filePath,
                    body: content
                )
                try Self.applyDirectCodeFileSave(
                    content,
                    to: page,
                    filePath: filePath,
                    modelContext: modelContext,
                    graphState: AppBootstrap.shared?.graphState
                )
                persistedBody = page.body
                if CodeLanguage.isMarkdownDocument(path: filePath) {
                    modeBodySnapshot = NoteModeBodySnapshot(pageId: page.id, body: page.body)
                }
            } catch {
                Log.app.error("CodeEditor: failed to save code file: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func recordSourceEditorSnapshot(page: SDPage, filePath: String, content: String) {
        codeFileBodySnapshot = CodeFileBodySnapshot(
            pageId: page.id,
            filePath: filePath,
            body: content
        )
        guard CodeLanguage.isMarkdownDocument(path: filePath) else { return }
        let persistedContent = SourceEditorPersistedContent(rawContent: content, filePath: filePath)
        modeBodySnapshot = NoteModeBodySnapshot(pageId: page.id, body: persistedContent.body)
    }

    private func saveMarkdownSourceContent(page: SDPage, filePath: String, content: String, noteBacked: Bool = false) {
        let fileURL = URL(fileURLWithPath: filePath)
        Task { @MainActor in
            let pageId = page.id
            let persistedContent = SourceEditorPersistedContent(rawContent: content, filePath: filePath)
            let persistedSourceBody = persistedContent.body
            guard stageBodyWrite(pageId: pageId, fullText: persistedSourceBody) else { return }

            if noteBacked {
                // DISPLAY-ONLY route: never bind page.filePath to the synthesized path and never
                // write a file directly (that would create a spurious/colliding vault file and
                // corrupt the note's sync identity). Persist the body via the note pipeline and let
                // the normal vault export assign the real, dedup'd .md path + page.filePath. After
                // that first save the note has a real filePath and Source takes the on-disk branch. (source-toggle 2026-07-01)
                persistedContent.apply(to: page)
                page.updatedAt = .now
                page.needsVaultSync = true
                do {
                    try modelContext.save()
                } catch {
                    Log.app.error("CodeEditor: failed to save note-backed markdown Source state: \(error.localizedDescription, privacy: .public)")
                    return
                }
                codeFileBodySnapshot = CodeFileBodySnapshot(pageId: pageId, filePath: filePath, body: content)
                persistedBody = persistedSourceBody
                modeBodySnapshot = NoteModeBodySnapshot(pageId: pageId, body: persistedSourceBody)
                AppBootstrap.shared?.graphState.needsRefresh = true
                scheduleMetricsRefresh(body: persistedSourceBody, includeMarkdownHeadings: false)
                if let modelContainer = AppBootstrap.shared?.modelContainer {
                    Task {
                        await BlockMirrorSyncCoordinator.shared.scheduleSync(
                            pageId: pageId,
                            body: persistedSourceBody,
                            modelContainer: modelContainer
                        )
                    }
                }
                vaultSync.savePage(pageId: pageId)
                return
            }

            if page.filePath != filePath {
                page.filePath = filePath
            }
            persistedContent.apply(to: page)
            page.updatedAt = .now
            page.needsVaultSync = true

            do {
                try modelContext.save()
            } catch {
                Log.app.error("CodeEditor: failed to save markdown Source note state: \(error.localizedDescription, privacy: .public)")
                return
            }

            codeFileBodySnapshot = CodeFileBodySnapshot(
                pageId: pageId,
                filePath: filePath,
                body: content
            )
            persistedBody = persistedSourceBody
            modeBodySnapshot = NoteModeBodySnapshot(pageId: pageId, body: persistedSourceBody)
            AppBootstrap.shared?.graphState.needsRefresh = true
            scheduleMetricsRefresh(body: persistedSourceBody, includeMarkdownHeadings: false)

            if let modelContainer = AppBootstrap.shared?.modelContainer {
                Task {
                    await BlockMirrorSyncCoordinator.shared.scheduleSync(
                        pageId: pageId,
                        body: persistedSourceBody,
                        modelContainer: modelContainer
                    )
                }
            }

            guard let vaultURL = vaultSync.vaultURL else {
                Log.app.error("CodeEditor: saved markdown Source note state without an active vault for \(filePath, privacy: .private)")
                return
            }

            do {
                try await CodeFileService.updateCodeFileAsync(
                    at: fileURL,
                    vaultRoot: vaultURL,
                    body: content
                )
            } catch {
                Log.app.error("CodeEditor: failed to write markdown Source file directly: \(error.localizedDescription, privacy: .public)")
                vaultSync.savePage(pageId: pageId)
                return
            }

            guard codeFileBodySnapshot?.body(ifMatches: pageId, filePath: filePath) == content else {
                return
            }
            page.lastSyncedBodyHash = SDPage.bodyHash(persistedSourceBody)
            page.lastSyncedAt = .now
            page.needsVaultSync = false
            do {
                try modelContext.save()
            } catch {
                Log.app.error("CodeEditor: failed to save markdown Source sync state: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func saveMarkdownDocumentSurfaceContent(page: SDPage, markdown: String) {
        let pageId = page.id
        guard stageBodyWrite(pageId: pageId, fullText: markdown) else { return }
        page.body = markdown
        page.blockReferences = SDPage.extractBlockReferences(from: markdown)
        page.wordCount = markdown.split(separator: " ").count
        page.updatedAt = .now
        page.needsVaultSync = true

        do {
            try modelContext.save()
        } catch {
            Log.app.error("Document surface: failed to save markdown note state: \(error.localizedDescription, privacy: .public)")
            return
        }

        persistedBody = markdown
        modeBodySnapshot = NoteModeBodySnapshot(pageId: pageId, body: markdown)
        AppBootstrap.shared?.graphState.needsRefresh = true
        scheduleMetricsRefresh(body: markdown, includeMarkdownHeadings: false)

        if let modelContainer = AppBootstrap.shared?.modelContainer {
            Task {
                await BlockMirrorSyncCoordinator.shared.scheduleSync(
                    pageId: pageId,
                    body: markdown,
                    modelContainer: modelContainer
                )
            }
        }
        vaultSync.savePage(pageId: pageId)
    }

    private func codeFileServiceForActiveVault(filePath: String) -> CodeFileService? {
        guard let vaultURL = vaultSync.vaultURL else {
            Log.notes.error(
                "NoteDetailWorkspaceView: refusing code file IO with no active vault for \(filePath, privacy: .private)"
            )
            return nil
        }
        return CodeFileService(vaultRoot: vaultURL)
    }

    @MainActor
    static func applyDirectCodeFileSave(
        _ content: String,
        to page: SDPage,
        filePath: String? = nil,
        modelContext: ModelContext,
        graphState: GraphState? = nil
    ) throws {
        // Code files are already written to their tracked vault path, so keep the page
        // synchronized without routing them back through markdown export.
        let persistedContent = SourceEditorPersistedContent(rawContent: content, filePath: filePath)
        persistedContent.apply(to: page)
        page.updatedAt = .now
        page.lastSyncedBodyHash = SDPage.bodyHash(persistedContent.body)
        page.lastSyncedAt = .now
        page.needsVaultSync = false
        try modelContext.save()
        graphState?.needsRefresh = true
    }

    private var shouldShowMarkEditSourceSettingsToolbarButton: Bool {
        guard let page = pages.first,
              let route = sourceEditorRoute(for: page) else {
            return false
        }
        return route.isMarkdown
    }

    private var shouldShowNoteToolbarPrimaryActions: Bool {
        return !isCodeFile || shouldShowMarkEditSourceSettingsToolbarButton
    }

    private var isMarkdownDocumentSurfaceModeActive: Bool {
        guard let page = pages.first else { return false }
        return resolvedNoteMode(for: page) == .document
    }

    #if canImport(MarkEditKit)
    private var markEditSourceSettingsToolbarButton: some View {
        Button {
            showMarkEditSourceSettings = true
        } label: {
            Label("MarkEdit settings", systemImage: "gearshape")
        }
        .labelStyle(.iconOnly)
        .help("MarkEdit settings")
    }
    #endif

    @ViewBuilder
    private var noteToolbarPrimaryActions: some View {
        if let page = pages.first {
            if !isMarkdownDocumentSurfaceModeActive {
                noteModePicker(for: page)
            }

            ViewOriginalPDFAffordance(
                page: page,
                vaultURL: vaultSync.vaultURL,
                openOriginalPDF: { url in
                    sourcePDFViewerPresentation = SourcePDFViewerPresentation(url: url)
                }
            )
        }

        // TTS (2026-07-04): read the note aloud (Kokoro; honest-gated — disables to
        // "TTS unavailable" without the voice). Shows only when the note has body text.
        if !persistedBody.isEmpty {
            ReadAloudButton(
                text: EpistemosSpeechSynthesizer.plainTextForSpeech(fromMarkdown: persistedBody),
                style: .icon
            )
        }

        moreMenu
    }

    private func markdownDocumentSurfaceToolbarAccessory(for page: SDPage) -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                noteModePicker(for: page)
            }
        )
    }

    @ViewBuilder
    private func noteModePicker(for page: SDPage) -> some View {
        let options = noteModeOptions(for: page)
        let modes = options.modes
        if modes.count > 1 {
            let selectedMode = resolvedNoteMode(for: page, options: options)
            ForEach(modes, id: \.self) { mode in
                surfaceModeToolbarButton(mode: mode, isActive: mode == selectedMode) {
                    setNoteMode(mode, for: page, options: options)
                }
            }
        }
    }

    private func surfaceModeToolbarButton(
        mode: NoteWorkspaceMode,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let accent = noteWorkspaceTheme.resolved.accent.color
        let foreground = noteWorkspaceTheme.resolved.foreground.color

        return Button(action: action) {
            Image(systemName: mode.symbolName)
                .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isActive ? accent : foreground.opacity(0.78))
                .frame(width: 30, height: 30)
                .contentShape(Circle())
                // Owner 2026-07-03: individual NATIVE circular toolbar items (not one
                // merged pill), with a CIRCLE selection instead of the square box.
                .background {
                    Circle().fill(isActive ? accent.opacity(0.16) : Color.clear)
                }
                .overlay {
                    Circle().strokeBorder(isActive ? accent.opacity(0.42) : Color.clear, lineWidth: 1)
                }
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.label)
        .accessibilityHint("Switch between Prose, Document, Preview, and Source")
        .help(mode.helpText)
    }

    private var graphToolbarNavigationControls: some View {
        HStack(spacing: 6) {
            Button {
                graphState.goBack()
            } label: {
                Label("Back", systemImage: "chevron.backward")
                    .labelStyle(.iconOnly)
            }
            .disabled(!graphState.canGoBack)
            .accessibilityLabel("Back")
            .help("Back")

            Button {
                graphState.goForward()
            } label: {
                Label("Forward", systemImage: "chevron.forward")
                    .labelStyle(.iconOnly)
            }
            .disabled(!graphState.canGoForward)
            .accessibilityLabel("Forward")
            .help("Forward")

            Button {
                graphState.returnToCanvas()
            } label: {
                Label("Canvas", systemImage: "circle.grid.3x3.fill")
                    .labelStyle(.titleAndIcon)
            }
            .help("Return to graph canvas")
        }
    }

    private func graphEmbeddedToolbarTitle(_ page: SDPage) -> some View {
        GraphEmbeddedToolbarTitle(
            title: NoteTitleDisplay.resolvedTitle(page.title),
            theme: graphEmbeddedToolbarTheme
        )
    }

    private func overlayGraphEmbeddedToolbar(page: SDPage) -> some View {
        let toolbarTheme = graphEmbeddedToolbarTheme
        let shape = RoundedRectangle(
            cornerRadius: NoteWorkspaceSurfaceStyle.graphEmbeddedToolbarCornerRadius,
            style: .continuous
        )

        return HStack(spacing: 12) {
            graphToolbarNavigationControls

            Spacer(minLength: 12)

            graphEmbeddedToolbarTitle(page)

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                noteToolbarPrimaryActions
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .frame(maxWidth: 900)
        .unifiedFrostedGlass(
            theme: toolbarTheme,
            in: shape,
            extraDarkenOnDark: true,
            interactive: true,
            nativeGlass: true
        )
        .overlay(
            shape.strokeBorder(
                toolbarTheme.glassBorder.opacity(toolbarTheme.isDark ? 0.74 : 0.58),
                lineWidth: 0.75
            )
        )
        .shadow(
            color: Color.black.opacity(toolbarTheme.isDark ? 0.26 : 0.10),
            radius: 14,
            y: 8
        )
        .contentShape(shape)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Graph note toolbar")
    }

    // MARK: - Wikilink Navigation

    @ViewBuilder
    private func wikilinksNavButtons(nav: NoteNavigationState) -> some View {
        HStack(spacing: 2) {
            Button {
                nav.back()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!nav.canGoBack)

            Button {
                nav.forward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!nav.canGoForward)
        }
    }

    private struct GraphEmbeddedToolbarTitle: View {
        let title: String
        let theme: EpistemosTheme

        private var titleFont: Font {
            .system(size: 18, weight: .semibold, design: .rounded)
        }

        private var titleWidth: CGFloat {
            min(max(CGFloat(title.count) * 9.6 + 44, 132), 420)
        }

        var body: some View {
            Text(title)
                .font(titleFont)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            .frame(width: titleWidth)
            .accessibilityLabel(title)
        }
    }

    // MARK: - Selection Capture for Ideas Panel
    // The popover steals keyboard focus from the editor, which clears the selection.
    // We snapshot the selection BEFORE the popover opens so Integrate can use it.

    private func refreshTabCount() {
        let count = NSApp.keyWindow?.tabbedWindows?.count ?? 1
        hasMultipleTabs = count > 1
    }

    private func queueMissingPageRecovery() {
        guard let navState else { return }

        missingPageRecoveryTask?.cancel()
        let missingPageId = pageId
        let missingTitle = navState.currentPageTitle

        missingPageRecoveryTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            guard pages.isEmpty else { return }

            if let recovered = recoveredPageForMissingTitle(missingTitle) {
                _ = navState.retargetCurrentPage(
                    missingPageId: missingPageId,
                    replacementPageId: recovered.id,
                    replacementTitle: recovered.title
                )
            } else {
                _ = navState.discardCurrentPageIfMissing(missingPageId)
            }

            missingPageRecoveryTask = nil
        }
    }

    private func recoveredPageForMissingTitle(_ title: String?) -> SDPage? {
        guard let title else { return nil }
        let descriptor = FetchDescriptor<SDPage>()
        let allPages: [SDPage]
        do {
            allPages = try modelContext.fetch(descriptor)
        } catch {
            Log.notes.error(
                "NoteDetailWorkspaceView: failed to fetch pages for missing-page recovery: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
        let matches = allPages.filter { NoteTitleDisplay.resolvedTitle($0.title) == title }
        guard matches.count == 1 else { return nil }
        return matches[0]
    }

    private func refreshVisibleEditorMetrics() {
        guard let tv = NoteEditorViewFinder.findEditorTextView(for: pageId) else { return }
        scheduleMetricsRefresh(body: tv.string, includeMarkdownHeadings: true)
    }

    private func scheduleMetricsRefresh(body: String, includeMarkdownHeadings: Bool) {
        metricsTask?.cancel()
        metricsTask = Task { @MainActor in
            let snapshot = await Task.detached(priority: .utility) {
                EditorMetricsSnapshot(
                    wordCount: NLAnalysisService.wordCount(body),
                    headings: includeMarkdownHeadings
                        ? TOCParser.parse(body)
                        : []
                )
            }.value
            guard !Task.isCancelled else { return }
            if wordCount != snapshot.wordCount {
                wordCount = snapshot.wordCount
            }
            if includeMarkdownHeadings {
                let nextHeadings: [TOCItem]
                if deterministicOutlineState.isEnabled {
                    let result = await deterministicOutlineState.refresh(
                        pageId: pageId,
                        markdown: body,
                        fallbackHeadings: snapshot.headings
                    )
                    guard !Task.isCancelled else { return }
                    nextHeadings = result.appliedCount > 0
                        ? deterministicOutlineState.items
                        : snapshot.headings
                } else {
                    nextHeadings = snapshot.headings
                }
                if tocItems != nextHeadings {
                    tocItems = nextHeadings
                }
            }
            // Slice 3 cutover (Option 1) — KC block outline for the panel's Blocks
            // mode. Returns [] when the knowledgeCoreRuntimeV0 runtime is off, so
            // this is inherently flag-gated and the panel keeps headings-only.
            let nextBlocks = await KnowledgeCoreBlockOutline.items(pageId: pageId, markdown: body)
            guard !Task.isCancelled else { return }
            if blockOutlineItems != nextBlocks {
                blockOutlineItems = nextBlocks
            }
        }
    }

    private func snapshotEditorSelection() {
        guard let tv = NoteEditorViewFinder.findEditorTextView(for: pageId) else {
            capturedSelection = nil
            capturedSelectionText = nil
            return
        }
        let sel = tv.selectedRange()
        if sel.length > 0 {
            capturedSelection = sel
            capturedSelectionText = (tv.string as NSString).substring(with: sel)
        } else {
            capturedSelection = nil
            capturedSelectionText = nil
        }
    }

    private func captureSelectionAndOpenIdeas() {
        snapshotEditorSelection()
        showIdeasPopover.toggle()
    }

    // MARK: - AI Context Menu Operations

    private func applyBlockProperties(_ properties: [(String, PropertyValue)], lineRange: NSRange) {
        // Build the @key=value suffix string
        let suffix = properties.map { key, value in
            let valStr: String =
                switch value {
                case .string(let s): s
                case .float(let f): String(f)
                case .int(let i): String(i)
                case .bool(let b): b ? "true" : "false"
                }
            return "@\(key)=\(valStr)"
        }.joined(separator: " ")

        // Strip existing trailing @key=value from the line and append new ones
        let currentLine = blockPropertyLineText
        let stripped = currentLine.replacingOccurrences(
            of: #"\s+@\w+=\S+(?:\s+@\w+=\S+)*\s*$"#,
            with: "",
            options: .regularExpression
        )
        let newLine = suffix.isEmpty ? stripped : "\(stripped) \(suffix)"

        // Post notification to update the editor text
        NotificationCenter.default.post(
            name: NoteEditorNotifications.replaceRange,
            object: nil,
            userInfo: [
                "pageId": pageId,
                "range": NSValue(range: lineRange),
                "replacement": newLine,
            ]
        )
    }

    // MARK: - Table of Contents Navigation

    private func scrollEditorTo(charOffset: Int) {
        // Find the active NSTextView and scroll to the character offset.
        guard let tv = NoteEditorViewFinder.findEditorTextView(for: pageId) else { return }

        let safeOffset = max(0, min(charOffset, (tv.string as NSString).length))
        let range = NSRange(location: safeOffset, length: 0)
        tv.setSelectedRange(range)
        tv.scrollRangeToVisible(range)
        // Flash the line briefly by selecting the whole line
        let lineRange = (tv.string as NSString).lineRange(for: range)
        tv.showFindIndicator(for: lineRange)
    }

    private func navigateActiveOutline(to charOffset: Int) {
        guard let page = pages.first else { return }
        if sourceEditorRoute(for: page) != nil {
            sourceEditorSelectionRequest = CoreEditorSelectionRequest(
                range: NSRange(location: max(0, charOffset), length: 0)
            )
        } else {
            scrollEditorTo(charOffset: charOffset)
        }
    }

    // MARK: - Workspace Editor Restore

    private func applyEditorRestore(cursor: Int, scrollFraction: Double) {
        guard let tv = NoteEditorViewFinder.findEditorTextView(for: pageId) else { return }
        let safeCursor = max(0, min(cursor, (tv.string as NSString).length))
        tv.setSelectedRange(NSRange(location: safeCursor, length: 0))
        if let scrollView = tv.enclosingScrollView,
           let docHeight = scrollView.documentView?.bounds.height, docHeight > 0 {
            let scrollY = scrollFraction * docHeight
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    private func schedulePersistedBodyRefresh(for page: SDPage?) {
        persistedBodyLoadTask?.cancel()
        persistedBodyLoadTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            guard let page else {
                persistedBody = ""
                return
            }

            let pageId = page.id
            let fallbackBody = page.body
            let filePath = page.filePath
            if let liveBody = NoteWindowManager.shared.editorBody(for: pageId) {
                guard persistedBody != liveBody else { return }
                persistedBody = liveBody
                scheduleMetricsRefresh(body: liveBody, includeMarkdownHeadings: true)
                refreshModelDerivedSidecarBadge(for: page)
                refreshLegacyRecoveryPresentation()
                return
            }

            let loadedBody = await Task.detached(priority: .userInitiated) {
                await SDPage.loadBodyAsyncFromPrimitives(
                    pageId: pageId,
                    filePath: filePath,
                    inlineBody: fallbackBody,
                    mapped: false,
                    fast: true
                )
            }.value
            guard !Task.isCancelled,
                  pages.first?.id == pageId else { return }
            let body = loadedBody
            guard persistedBody != body else { return }
            persistedBody = body
            scheduleMetricsRefresh(body: body, includeMarkdownHeadings: true)
            refreshModelDerivedSidecarBadge(for: pages.first)
            refreshLegacyRecoveryPresentation()
        }
    }

    private func persistedBodyFor(_ page: SDPage) -> String {
        Self.resolvedPersistedBody(persistedBody, for: page)
    }

    private func displayBody(for page: SDPage) -> String {
        currentModeBodySnapshot(for: page.id) ?? currentEditorBody(for: page) ?? persistedBodyFor(page)
    }

    private func currentModeBodySnapshot(for pageId: String) -> String? {
        modeBodySnapshot?.body(ifMatches: pageId)
    }

    /// Load code file content from live editor/cache state only. Disk reads are
    /// scheduled separately so SwiftUI body construction stays IO-free.
    private func cachedCodeFileContent(page: SDPage, filePath: String) -> String {
        if let snapshot = currentModeBodySnapshot(for: page.id), !snapshot.isEmpty {
            return snapshot
        }
        let managed = NoteWindowManager.shared.editorBody(for: page.id) ?? ""
        if !managed.isEmpty {
            return managed
        }
        if let cached = codeFileBodySnapshot?.body(ifMatches: page.id, filePath: filePath) {
            return cached
        }

        return page.body
    }

    /// Markdown Source mode prefers a source snapshot when available, but it
    /// must always be able to mount from the note-backed body used by Prose.
    private func cachedSourceEditorContent(page: SDPage, route: SourceEditorRoute) -> String {
        if route.isMarkdown,
           let cached = codeFileBodySnapshot?.body(ifMatches: page.id, filePath: route.filePath) {
            return cached
        }

        return cachedCodeFileContent(page: page, filePath: route.filePath)
    }

    private func isMarkdownDocument(_ page: SDPage) -> Bool {
        CodeLanguage.isMarkdownDocument(path: page.filePath)
    }

    private func availableNoteModes(for page: SDPage) -> [NoteWorkspaceMode] {
        noteModeOptions(for: page).modes
    }

    private func noteModeOptions(for page: SDPage) -> NoteModeOptions {
        let sourceRoute = sourceFileRoute(for: page)
        // A note-backed note (no on-disk filePath) is a markdown/prose note, same as a resolved
        // .md file: offer the full Edit/Preview/Source set when a Source route is available.
        // Only a NON-markdown code file (a real non-.md filePath) is Source-only. This restores
        // the MarkEdit Source toggle that regressed away for note-backed notes. (source-toggle 2026-07-01)
        let isMarkdownBodied = isMarkdownDocument(page) || (page.filePath?.isEmpty ?? true)
        if isMarkdownBodied {
            return NoteModeOptions(
                modes: sourceRoute == nil ? [.edit, .document, .preview] : [.edit, .document, .preview, .source],
                sourceRoute: sourceRoute
            )
        }
        if sourceRoute != nil {
            return NoteModeOptions(modes: [.source], sourceRoute: sourceRoute)
        }
        return NoteModeOptions(modes: [.edit, .preview], sourceRoute: nil)
    }

    private func resolvedNoteMode(for page: SDPage, options: NoteModeOptions? = nil) -> NoteWorkspaceMode {
        let modes = (options ?? noteModeOptions(for: page)).modes
        if modes.contains(noteMode) {
            return noteMode
        }
        return modes.first ?? .edit
    }

    private func setNoteMode(_ mode: NoteWorkspaceMode, for page: SDPage, options: NoteModeOptions? = nil) {
        let options = options ?? noteModeOptions(for: page)
        let modes = options.modes
        guard modes.contains(mode),
              resolvedNoteMode(for: page, options: options) != mode else { return }
        flushCurrentEditor()
        noteMode = mode
        scheduleCodeFileBodyRefresh(for: page)
    }

    private func sourceFileRoute(for page: SDPage) -> SourceEditorRoute? {
        guard let path = page.filePath,
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // No on-disk filePath yet. vaultRelativeNotePath is DERIVED from filePath, so the
            // canonical-vault-path gate was unconditionally nil here — THAT was the toggle-missing
            // regression. Offer Source against a DISPLAY-ONLY note-backed markdown route mounted
            // from the note body. The synthesized path is never written to page.filePath or disk;
            // the first Source save runs the normal vault export, which assigns the real dedup'd
            // path + page.filePath, after which Source opens take the on-disk branch. (source-toggle 2026-07-01)
            return noteBackedSourceRoute(for: page)
        }
        if CodeLanguage.isMarkdownDocument(path: path) {
            let markdownPath = canonicalMarkdownSourcePath(for: page, fallbackPath: path)
            return SourceEditorRoute(filePath: markdownPath, language: "markdown")
        }
        guard let language = CodeLanguage.detect(from: path) else { return nil }
        return SourceEditorRoute(filePath: path, language: language)
    }

    /// DISPLAY-ONLY route for a note with no on-disk file yet. Anchored under the active vault
    /// only so the Source header/icon read a plausible location; NOTHING is written to this path
    /// (see saveMarkdownSourceContent's noteBacked branch). No dedup here — the real path +
    /// page.filePath are assigned by VaultIndexActor.exportPage on the first save. (source-toggle 2026-07-01)
    private func noteBackedSourceRoute(for page: SDPage) -> SourceEditorRoute {
        let base = noteBackedSourceDisplayName(for: page)
        let parent = vaultSync.vaultURL ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let displayPath = parent.appendingPathComponent("\(base).md", isDirectory: false).path
        return SourceEditorRoute(filePath: displayPath, language: "markdown", isNoteBacked: true)
    }

    private func noteBackedSourceDisplayName(for page: SDPage) -> String {
        let forbidden = CharacterSet(charactersIn: ":/\\?*\"<>|#^[]{}").union(.controlCharacters)
        var name = String(page.title.unicodeScalars.filter { !forbidden.contains($0) })
            .trimmingCharacters(in: .whitespaces)
        if name.count > 200 { name = String(name.prefix(200)) }
        return name.isEmpty ? "Untitled" : name
    }

    private func canonicalMarkdownSourcePath(for page: SDPage, fallbackPath: String) -> String {
        activeVaultMarkdownSourcePath(for: page) ?? fallbackPath
    }

    private func activeVaultMarkdownSourcePath(for page: SDPage) -> String? {
        guard let vaultURL = vaultSync.vaultURL,
              let relativePath = page.vaultRelativeNotePath?.trimmingCharacters(
                in: .whitespacesAndNewlines
              ),
              !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.hasPrefix("\\")
        else { return nil }

        let components = relativePath.split { character in
            character == "/" || character == "\\"
        }.map(String.init)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else { return nil }

        let normalizedPath = components.joined(separator: "/")
        let rootPath = lexicalFilePath(vaultURL.path)
        let candidatePath = lexicalFilePath(rootPath + "/" + normalizedPath)
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard candidatePath.hasPrefix(prefix),
              CodeLanguage.isMarkdownDocument(path: candidatePath)
        else { return nil }

        return candidatePath
    }

    private func lexicalFilePath(_ path: String) -> String {
        let isAbsolute = path.hasPrefix("/")
        var components: [String] = []
        for component in path.split(separator: "/", omittingEmptySubsequences: true) {
            if component == "." {
                continue
            }
            if component == ".." {
                if !components.isEmpty {
                    components.removeLast()
                }
                continue
            }
            components.append(String(component))
        }

        let joined = components.joined(separator: "/")
        if isAbsolute {
            return joined.isEmpty ? "/" : "/" + joined
        }
        return joined.isEmpty ? "." : joined
    }

    private func sourceEditorRoute(for page: SDPage) -> SourceEditorRoute? {
        let options = noteModeOptions(for: page)
        guard resolvedNoteMode(for: page, options: options) == .source else {
            return nil
        }
        return options.sourceRoute
    }

    private func scheduleCodeFileBodyRefresh(for page: SDPage?) {
        codeFileLoadTask?.cancel()
        guard let page,
              let route = sourceEditorRoute(for: page) else {
            codeFileBodySnapshot = nil
            return
        }

        let filePath = route.filePath
        let isMarkdownSource = route.isMarkdown
        let seededMarkdownSource = isMarkdownSource
            ? seedMarkdownSourceSnapshot(for: page, route: route)
            : nil

        if route.isNoteBacked {
            // No on-disk file yet: the snapshot seeded from the note body (seedMarkdownSourceSnapshot
            // above) is authoritative. Reading `filePath` from disk would fail, or worse, load an
            // unrelated vault file sharing the synthesized display name. (source-toggle 2026-07-01)
            return
        }

        guard let vaultURL = vaultSync.vaultURL else {
            Log.notes.error(
                "NoteDetailWorkspaceView: refusing async code file read with no active vault for \(filePath, privacy: .private)"
            )
            if !isMarkdownSource {
                codeFileBodySnapshot = CodeFileBodySnapshot(
                    pageId: page.id,
                    filePath: filePath,
                    body: page.body
                )
            }
            return
        }

        let pageId = page.id
        let fileURL = URL(fileURLWithPath: filePath)
        codeFileLoadTask = Task { @MainActor in
            do {
                let loaded = try await CodeFileService.readCodeFileAsync(
                    at: fileURL,
                    vaultRoot: vaultURL
                )
                guard !Task.isCancelled,
                      currentSourceRouteMatches(pageId: pageId, filePath: filePath) else { return }
                if isMarkdownSource {
                    guard let currentPage = pages.first,
                          currentPage.needsVaultSync != true,
                          markdownSourceFallbackContent(for: currentPage, filePath: filePath) == seededMarkdownSource,
                          codeFileBodySnapshot?.body(ifMatches: pageId, filePath: filePath) == seededMarkdownSource else {
                        return
                    }
                } else {
                    if let snapshot = currentModeBodySnapshot(for: pageId), !snapshot.isEmpty {
                        return
                    }
                    if let liveBody = NoteWindowManager.shared.editorBody(for: pageId),
                       !liveBody.isEmpty {
                        return
                    }
                }
                codeFileBodySnapshot = CodeFileBodySnapshot(
                    pageId: pageId,
                    filePath: filePath,
                    body: loaded.body
                )
                let persistedContent = SourceEditorPersistedContent(rawContent: loaded.body, filePath: filePath)
                persistedBody = persistedContent.body
                if persistedContent.isMarkdownSource {
                    modeBodySnapshot = NoteModeBodySnapshot(pageId: pageId, body: persistedContent.body)
                }
                scheduleMetricsRefresh(body: persistedContent.body, includeMarkdownHeadings: false)
            } catch {
                guard !Task.isCancelled,
                      currentSourceRouteMatches(pageId: pageId, filePath: filePath) else { return }
                Log.notes.error(
                    "NoteDetailWorkspaceView: failed to read code file \(filePath, privacy: .private): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func currentSourceRouteMatches(pageId: String, filePath: String) -> Bool {
        guard let currentPage = pages.first,
              currentPage.id == pageId,
              let currentRoute = sourceFileRoute(for: currentPage) else {
            return false
        }
        return currentRoute.filePath == filePath
    }

    @discardableResult
    private func seedMarkdownSourceSnapshot(for page: SDPage, route: SourceEditorRoute) -> String {
        let body = markdownSourceFallbackContent(for: page, filePath: route.filePath)
        codeFileBodySnapshot = CodeFileBodySnapshot(
            pageId: page.id,
            filePath: route.filePath,
            body: body
        )
        return body
    }

    private func markdownSourceFallbackContent(for page: SDPage, filePath: String? = nil) -> String {
        let body = markdownSourceFallbackBody(for: page)
        guard let sourcePath = filePath ?? page.filePath else {
            return body
        }
        let sourceURL = URL(fileURLWithPath: sourcePath)
        guard VaultIndexActor.shouldWriteMarkdownFrontMatter(to: sourceURL) else {
            return body
        }
        return VaultIndexActor.buildMarkdownSource(
            pageId: page.id,
            title: page.title,
            tags: page.tags,
            emoji: page.emoji,
            isJournal: page.isJournal,
            journalDate: page.journalDate,
            parentPageId: page.parentPageId,
            templateId: page.templateId,
            frontMatter: page.frontMatter,
            body: body
        )
    }

    private func markdownSourceFallbackBody(for page: SDPage) -> String {
        if let snapshot = currentModeBodySnapshot(for: page.id), !snapshot.isEmpty {
            return snapshot
        }
        let managed = NoteWindowManager.shared.editorBody(for: page.id) ?? ""
        if !managed.isEmpty {
            return managed
        }
        let persisted = persistedBodyFor(page)
        if !persisted.isEmpty {
            return persisted
        }
        return page.body
    }

    private func currentEditorBody(for page: SDPage) -> String? {
        if let responder = NoteEditorViewFinder.findEditorTextView(for: pageId) {
            return responder.string
        }
        switch resolvedNoteMode(for: page) {
        case .document, .source, .preview:
            return currentModeBodySnapshot(for: page.id) ?? persistedBodyFor(page)
        case .edit:
            return nil
        }
    }

    private func flushCurrentEditor() {
        guard let page = pages.first else { return }
        let baseline = persistedBodyFor(page)
        let fullText = currentEditorBody(for: page) ?? baseline
        modeBodySnapshot = NoteModeBodySnapshot(pageId: page.id, body: fullText)
        guard fullText != baseline else {
            persistedBody = fullText
            return
        }
        let pageId = page.id
        guard stageBodyWrite(pageId: pageId, fullText: fullText) else { return }
        persistedBody = fullText
        page.applyInteractiveDerivedState(from: fullText)
        Task { @MainActor in
            _ = await AppBootstrap.shared?.vaultSync.savePageBodyFileFirst(pageId: pageId, body: fullText)
        }
        if let modelContainer = AppBootstrap.shared?.modelContainer {
            Task {
                await BlockMirrorSyncCoordinator.shared.scheduleSync(
                    pageId: pageId,
                    body: fullText,
                    modelContainer: modelContainer
                )
            }
        }
        page.needsVaultSync = true
        page.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            Log.notes.error(
                "NoteDetailWorkspaceView: failed to persist flushed editor body for page \(String(pageId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        AppBootstrap.shared?.graphState.needsRefresh = true
    }

    @discardableResult
    private func stageBodyWrite(pageId: String, fullText: String) -> Bool {
        guard NoteFileStorage.stageBodyForImmediateRead(pageId: pageId, content: fullText) != nil else {
            Log.notes.error(
                "NoteDetailWorkspaceView: failed to stage flushed editor body for page \(String(pageId.prefix(8)), privacy: .public)"
            )
            return false
        }
        return true
    }

    // MARK: - Mode Transition Helpers
    // Shows a solid label card that fully covers the view swap glitch.
    // Timing: appear instantly → mode swaps behind it → fade out after settling.

    private func togglePreviewMode() {
        guard let page = pages.first else { return }
        let mode = resolvedNoteMode(for: page) == .preview ? NoteWorkspaceMode.edit : .preview
        setNoteMode(mode, for: page)
    }

    @ViewBuilder
    private func notePreview(body: String) -> some View {
        AdaptiveNotePreviewView2(
            content: body,
            theme: noteWorkspaceTheme,
            hasMultipleTabs: hasMultipleTabs,
            surfaceBackground: noteWorkspaceBackground,
            chromeMinimumHeight: usesOverlayGraphToolbar
                ? NoteWorkspaceSurfaceStyle.graphEmbeddedPreviewChromeMinimumHeight
                : 0
        )
    }

    private func navigateToWikilink(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let localHeading = WikilinkResolver.localHeadingTitle(forDestination: trimmed) {
            scrollToLocalWikilinkHeading(localHeading)
            return
        }

        guard !trimmed.isEmpty,
              let destination = WikilinkResolver.canonicalDestination(trimmed),
              let displayTitle = WikilinkResolver.displayTitle(forDestination: trimmed)
        else { return }

        let exactDesc = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.title == displayTitle }
        )
        let targetKeys = WikilinkResolver.lookupKeys(forDestination: destination)
        let loweredDisplayTitle = displayTitle.lowercased()
        let exactMatch: SDPage?
        do {
            exactMatch = try modelContext.fetch(exactDesc).first
        } catch {
            Log.notes.error(
                "NoteDetailWorkspaceView: failed to fetch exact wikilink target: \(error.localizedDescription, privacy: .public)"
            )
            exactMatch = nil
        }
        let existing: SDPage? = {
            let allDesc = FetchDescriptor<SDPage>()
            do {
                let pages = try modelContext.fetch(allDesc)
                return pageMatchingWikilinkDestination(targetKeys: targetKeys, pages: pages)
                    ?? exactMatch
                    ?? pages.first(where: { page in
                        page.title.lowercased() == loweredDisplayTitle
                    })
            } catch {
                Log.notes.error(
                    "NoteDetailWorkspaceView: failed to fetch wikilink target pages: \(error.localizedDescription, privacy: .public)"
                )
                return nil
            }
        }()

        if let existing {
            if presentation.usesGraphEmbeddedChrome {
                graphState.openNote(existing.id)
            } else if let navState {
                navState.push(pageId: existing.id, title: existing.title)
            } else {
                NoteWindowManager.shared.open(pageId: existing.id)
            }
        } else {
            Task {
                if let newId = await vaultSync.createPage(
                    title: displayTitle,
                    allowVaultSelectionPrompt: true
                ) {
                    if presentation.usesGraphEmbeddedChrome {
                        graphState.openNote(newId)
                    } else if let navState {
                        navState.push(pageId: newId, title: displayTitle)
                    } else {
                        NoteWindowManager.shared.open(pageId: newId)
                    }
                }
            }
        }
    }

    private func pageMatchingWikilinkDestination(targetKeys: [String], pages: [SDPage]) -> SDPage? {
        let pageKeys = pages.map { page in
            (
                page: page,
                keys: Set(WikilinkResolver.lookupKeysForPage(
                    title: page.title,
                    filePath: page.filePath,
                    vaultRelativePath: page.vaultRelativeNotePath
                ))
            )
        }

        for key in targetKeys {
            if let match = pageKeys.first(where: { $0.keys.contains(key) }) {
                return match.page
            }
        }
        return nil
    }

    private func scrollToLocalWikilinkHeading(_ headingTitle: String) {
        let normalizedHeading = normalizedLocalWikilinkHeading(headingTitle)
        guard !normalizedHeading.isEmpty else { return }

        let body = pages.first.map(displayBody(for:)) ?? persistedBody
        let headings = tocItems.isEmpty ? TOCParser.parse(body) : tocItems
        guard let target = headings.first(where: {
            $0.kind == .heading
                && normalizedLocalWikilinkHeading($0.title) == normalizedHeading
        }) else {
            return
        }
        scrollEditorTo(charOffset: target.charOffset)
    }

    private func normalizedLocalWikilinkHeading(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }

    private func performGreetingTransition(
        message: String,
        _ modeSwap: @escaping () -> Void
    ) {
        transitionGreeting = message
        isTransitioning = true

        let bodyLength = pages.first.map(persistedBodyFor)?.count ?? persistedBody.count
        let holdTime: Double = bodyLength > 20_000 ? 1.4 : bodyLength > 5_000 ? 1.0 : 0.70

        transitionOpacity = 1

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            modeSwap()
            let safeHoldTime = holdTime.isFinite ? max(0, holdTime) : 0
            try? await Task.sleep(for: .milliseconds(Int(safeHoldTime * 1000)))
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) {
                transitionOpacity = 0
            }
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(350))
            }
            isTransitioning = false
        }
    }

    private func showAppleWritingTools() {
        NotificationCenter.default.post(
            name: WritingToolsBridge.showNotification,
            object: nil,
            userInfo: ["pageId": pageId]
        )
    }

    @MainActor
    private func createWebClip(from draft: WebClipCaptureDraft) async throws {
        let document = try WebClipperMarkdownBuilder.document(from: draft)
        guard let pageId = await vaultSync.createPage(
            title: document.title,
            body: document.markdownBody,
            allowVaultSelectionPrompt: true,
            frontMatter: document.frontMatter
        ) else {
            throw WebClipperCreationError.vaultUnavailable
        }

        if presentation.usesGraphEmbeddedChrome {
            graphState.openNote(pageId)
        } else if let navState {
            navState.push(pageId: pageId, title: document.title)
        } else {
            NoteWindowManager.shared.open(pageId: pageId)
        }
    }

    @discardableResult
    private func persistPageMutation(
        failureMessage: String,
        restoreState: () -> Void
    ) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            restoreState()
            Log.notes.error(
                "\(failureMessage, privacy: .private): \(error.localizedDescription, privacy: .private)"
            )
            return false
        }
    }

    // MARK: - More Menu

    private var moreMenu: some View {
        Menu {
            // Note actions
            if let page = pages.first {
                Button {
                    let originalMenuPinned = page.isPinned
                    page.isPinned.toggle()
                    _ = persistPageMutation(
                        failureMessage: "Save failed (pin toggle)",
                        restoreState: { page.isPinned = originalMenuPinned }
                    )
                } label: {
                    Label(
                        page.isPinned ? "Unpin" : "Pin",
                        systemImage: page.isPinned ? "pin.fill" : "pin")
                }
                Button {
                    let originalIsFavorite = page.isFavorite
                    page.isFavorite.toggle()
                    _ = persistPageMutation(
                        failureMessage: "Save failed (favorite toggle)",
                        restoreState: { page.isFavorite = originalIsFavorite }
                    )
                } label: {
                    Label(
                        page.isFavorite ? "Unfavorite" : "Favorite",
                        systemImage: page.isFavorite ? "star.fill" : "star")
                }
                // GAP-24 (audit 2026-07-03): common note actions the menu was missing.
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("[[\(page.title)]]", forType: .string)
                } label: {
                    Label("Copy Wikilink", systemImage: "link.badge.plus")
                }
                Button {
                    // INT-2 fix: revealCurrentDocumentInKnowledgeGraph needs an Epdoc doc and
                    // resolves only .document nodes → opened an UNFOCUSED graph for a plain
                    // note. revealPage resolves the .note node (sourceId == page.id).
                    HologramController.shared.revealPage(page.id)
                } label: {
                    Label("Reveal in Graph", systemImage: "point.3.connected.trianglepath.dotted")
                }
                // DISC-1 (audit 2026-07-03): Focus Mode was reachable ONLY via a hidden ⌘⇧F
                // button with no visible affordance. Surface it as a menu toggle (the hidden
                // shortcut button stays, so ⌘⇧F is unchanged).
                Button {
                    notesUI.isFocusMode.toggle()
                } label: {
                    Label(notesUI.isFocusMode ? "Exit Focus Mode (⌘⇧F)" : "Focus Mode (⌘⇧F)",
                          systemImage: "rectangle.center.inset.filled")
                }
            }

            Divider()

            if pages.first.map({ page in
                let options = noteModeOptions(for: page)
                return resolvedNoteMode(for: page, options: options) != .preview
            }) ?? true {
                let actions = pages.first.map { page in
                    noteWorkspaceQuickActions(for: page, options: noteModeOptions(for: page))
                } ?? NoteWorkspaceQuickAction.allCases
                ForEach(actions, id: \.self) { action in
                    Button(action.title) {
                        performNoteWorkspaceQuickAction(action)
                    }
                }

                if let legacyRecoveryPresentation,
                   legacyRecoveryPresentation.hasEncodingIssues
                {
                    Button {
                        showLegacyRecoverySheet = true
                    } label: {
                        Label("Inspect Corrupted File", systemImage: "exclamationmark.triangle")
                    }
                }

                Menu("Format") {
                    formatMenuContent
                }

                Button {
                    showBacklinksPopover.toggle()
                } label: {
                    Label("Backlinks", systemImage: "link")
                }

                Button {
                    showAppleWritingTools()
                } label: {
                    Label("Apple Writing Tools", systemImage: "apple.intelligence")
                }

                Button {
                    showWebClipperSheet = true
                } label: {
                    Label("Clip Web Page", systemImage: "globe")
                }
            }

            Divider()

            Button {
                showInfoPopover.toggle()
            } label: {
                Label("Info", systemImage: "info.circle")
            }

            Button {
                captureSelectionAndOpenIdeas()
            } label: {
                Label("Ideas", systemImage: "lightbulb")
            }

            Button {
                if let page = pages.first { shareNote(page) }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                showDiffSheet = true
            } label: {
                Label("Diff (\u{2318}D)", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            Divider()

        } label: {
            Image(systemName: NoteToolbarGlyph.more.symbolName ?? "ellipsis.circle")
                .accessibilityLabel("More")
        }
        .menuIndicator(.hidden)
        .popover(isPresented: $showBacklinksPopover, arrowEdge: .bottom) {
            if let page = pages.first {
                NoteBacklinksPopover(
                    pageTitle: page.title,
                    pageId: page.id,
                    onNavigate: { targetId in
                        showBacklinksPopover = false
                        if presentation.usesGraphEmbeddedChrome {
                            graphState.openNote(targetId)
                        } else {
                            navState?.push(pageId: targetId, title: "")
                        }
                    },
                    graphState: graphState
                )
            }
        }
        .help("More")
    }

    @ViewBuilder
    private var formatMenuContent: some View {
        Button("Bold  \u{2318}B") { insertMarkdown("**", "**") }
        Button("Italic  \u{2318}I") { insertMarkdown("*", "*") }
        Button("Strikethrough") { insertMarkdown("~~", "~~") }
        Button("Inline Code") { insertMarkdown("`", "`") }
        Button("Link") { insertMarkdown("[", "](url)") }

        Divider()

        Menu("Heading") {
            Button("Heading 1") { insertLinePrefix("# ") }
            Button("Heading 2") { insertLinePrefix("## ") }
            Button("Heading 3") { insertLinePrefix("### ") }
            Button("Heading 4") { insertLinePrefix("#### ") }
        }

        Menu("Lists") {
            Button("Checklist") { toggleMarkdownPrefix("- [ ] ") }
            Button("Bullet List") { toggleMarkdownPrefix("- ") }
            Button("Numbered List") { toggleMarkdownPrefix("1. ") }
        }

        Menu("Quotes & Callouts") {
            Button("Quote") { toggleMarkdownPrefix("> ") }
            Divider()
            Button("Note Callout") { insertCallout(.note) }
            Button("Tip Callout") { insertCallout(.tip) }
            Button("Warning Callout") { insertCallout(.warning) }
            Button("Quote Callout") { insertCallout(.quote) }
        }

        Divider()

        Menu("Table") {
            Button("Insert Table") { insertMarkdownTable() }
            Divider()
            Button("Add Row Below") { insertTableRowBelow() }
            Button("Add Column Right") { insertTableColumnRight() }
            Button("Delete Row") { deleteTableRow() }
            Button("Delete Column") { deleteTableColumn() }
            Divider()
            Button("Realign Table") { realignTable() }
        }
        Button("Code Block") { insertCodeFence() }
        Button("Divider") { insertDivider() }
    }

    private func commandTarget() -> NSTextView? {
        guard let tv = NoteEditorViewFinder.findEditorTextView(for: pageId) else { return nil }
        tv.window?.makeFirstResponder(tv)
        return tv
    }

    private func applyEditorEdit(_ edit: MarkdownEditorCommands.TextEdit?) {
        guard let edit, let tv = commandTarget() else {
            return
        }
        _ = MarkdownEditorCommands.apply(edit, to: tv)
    }

    /// Wraps the current selection (or inserts at cursor) with markdown syntax.
    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        guard let tv = commandTarget() else { return }
        applyEditorEdit(
            MarkdownEditorCommands.wrapSelection(
                in: tv.string,
                selection: tv.selectedRange(),
                prefix: prefix,
                suffix: suffix
            )
        )
    }

    /// Sets the current line to the requested heading level.
    private func insertLinePrefix(_ prefix: String) {
        guard let level = prefix.firstIndex(of: " ").map({
            prefix.distance(from: prefix.startIndex, to: $0)
        }),
        let tv = commandTarget()
        else { return }
        applyEditorEdit(
            MarkdownEditorCommands.setHeading(
                in: tv.string,
                selection: tv.selectedRange(),
                level: level
            )
        )
    }

    private func toggleMarkdownPrefix(_ prefix: String) {
        guard let tv = commandTarget() else { return }
        applyEditorEdit(
            MarkdownEditorCommands.toggleLinePrefix(
                in: tv.string,
                selection: tv.selectedRange(),
                prefix: prefix
            )
        )
    }

    private func insertCallout(_ kind: NoteCalloutKind) {
        guard let tv = commandTarget() else { return }
        applyEditorEdit(
            MarkdownEditorCommands.insertCallout(
                in: tv.string,
                selection: tv.selectedRange(),
                kind: kind
            )
        )
    }

    private func insertMarkdownTable() {
        guard let tv = commandTarget() else { return }
        applyEditorEdit(
            MarkdownEditorCommands.insertMarkdownTable(
                in: tv.string,
                selection: tv.selectedRange()
            )
        )
    }

    private func insertTableRowBelow() {
        guard let tv = commandTarget() else { return }
        _ = MarkdownEditorCommands.handleTableNewline(in: tv)
    }

    private func insertTableColumnRight() {
        guard let tv = commandTarget(),
            let edit = MarkdownEditorCommands.insertTableColumnRight(
                in: tv.string, selection: tv.selectedRange())
        else { return }
        _ = MarkdownEditorCommands.apply(edit, to: tv)
    }

    private func deleteTableRow() {
        guard let tv = commandTarget(),
            let edit = MarkdownEditorCommands.deleteTableRow(
                in: tv.string, selection: tv.selectedRange())
        else { return }
        _ = MarkdownEditorCommands.apply(edit, to: tv)
    }

    private func deleteTableColumn() {
        guard let tv = commandTarget(),
            let edit = MarkdownEditorCommands.deleteTableColumn(
                in: tv.string, selection: tv.selectedRange())
        else { return }
        _ = MarkdownEditorCommands.apply(edit, to: tv)
    }

    private func realignTable() {
        guard let tv = commandTarget() else { return }
        _ = MarkdownEditorCommands.realignTable(in: tv)
    }

    private func insertCodeFence() {
        guard let tv = commandTarget() else { return }
        applyEditorEdit(
            MarkdownEditorCommands.insertCodeFence(
                in: tv.string,
                selection: tv.selectedRange()
            )
        )
    }

    private func insertDivider() {
        guard let tv = commandTarget() else { return }
        applyEditorEdit(
            MarkdownEditorCommands.insertDivider(
                in: tv.string,
                selection: tv.selectedRange()
            )
        )
    }

    // MARK: - Info Panel

    private func noteInfoPanel(page: SDPage, currentBody: String) -> some View {
        let wordCount = currentBody.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let charCount = currentBody.count
        let readingTime = max(1, wordCount / 200)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Note Info")
                .font(AppHeadingRole.h3.font)
                .foregroundStyle(ui.theme.fontAccent)
            Divider()
            infoRow("Words", "\(wordCount)")
            infoRow("Characters", "\(charCount)")
            infoRow("Reading time", "~\(readingTime) min")
            Divider()
            infoRow("Created", page.createdAt.formatted(date: .abbreviated, time: .shortened))
            infoRow("Modified", page.updatedAt.formatted(date: .abbreviated, time: .shortened))
        }
        .padding()
        .frame(width: 220)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.callout)
    }

    // MARK: - Share

    private func shareNote(_ page: SDPage) {
        let text = "# \(page.title)\n\n\(displayBody(for: page))" as NSString
        // Use NSApp.keyWindow directly (not from toolbar menu context where it can be nil).
        // Fall back to the note tab group windows.
        let window =
            NSApp.keyWindow
            ?? NSApp.windows.first(where: {
                $0.tabbingIdentifier == "epistemos-note-tabs" && $0.isVisible
            })
        guard let contentView = window?.contentView else { return }
        let picker = NSSharingServicePicker(items: [text])
        let buttonRect = NSRect(
            x: contentView.bounds.midX, y: contentView.bounds.maxY - 40,
            width: 1, height: 1)
        picker.show(relativeTo: buttonRect, of: contentView, preferredEdge: .minY)
    }

}

// MARK: - Ideas & Brain Dumps Panel
// Popover for registering ideas and brain dumps anchored to specific lines in a note.
// Each idea captures the cursor line when created. Clicking navigates to that line.
// "Insert" pastes the idea at the anchor. "Integrate" uses Apple Intelligence to weave it in.

private struct IdeasPanel: View {
    let page: SDPage
    let currentBody: String
    /// When opened from the right-click context menu, pre-select this tab.
    var initialTab: IdeaTab?
    /// When true, auto-show the new item form (right-click context menu flow).
    var autoShowForm: Bool = false
    /// Editor selection range captured BEFORE the popover opened (popover steals focus).
    var capturedSelection: NSRange?
    /// The selected text captured BEFORE the popover opened.
    var capturedSelectionText: String?

    @Environment(UIState.self) private var ui
    @Environment(EventBus.self) private var eventBus
    @Environment(\.modelContext) private var modelContext

    @State private var activeTab: IdeaTab = .ideas
    @State private var showNewForm = false
    @State private var newTitle = ""
    @State private var newBody = ""
    @State private var busyItemId: String?  // ID of the idea being processed by AI
    @State private var didApplyInitial = false

    private var theme: EpistemosTheme { ui.theme }

    enum IdeaTab: String, CaseIterable {
        case ideas = "Ideas"
        case brainDumps = "Brain Dumps"
    }

    private var filteredItems: [NoteIdea] {
        let targetType: NoteIdea.IdeaType = activeTab == .ideas ? .idea : .brainDump
        return readIdeas().filter { $0.type == targetType }.sorted { $0.createdAt > $1.createdAt }
    }

    private func readIdeas() -> [NoteIdea] {
        page.ideas
    }

    /// Write ideas through the computed property to keep @Transient cache in sync.
    private func writeIdeas(_ ideas: [NoteIdea]) {
        let originalIdeas = page.ideas
        let originalUpdatedAt = page.updatedAt
        page.ideas = ideas
        page.updatedAt = .now
        do { try modelContext.save() } catch {
            page.ideas = originalIdeas
            page.updatedAt = originalUpdatedAt
            Log.notes.error(
                "Save failed (write ideas): \(error.localizedDescription, privacy: .private)")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Ideas & Brain Dumps")
                    .font(AppHeadingRole.h3.font)
                    .foregroundStyle(theme.fontAccent)
                Spacer()
                Text("\(readIdeas().count)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.glassBg, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Tab picker
            Picker("", selection: $activeTab) {
                ForEach(IdeaTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Selection indicator — shows captured highlight so user knows Integrate will use it
            if let selText = capturedSelectionText, !selText.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "text.cursor")
                        .font(.system(size: 9))
                    Text("Selected: \"\(selText.prefix(40))\(selText.count > 40 ? "…" : "")\"")
                        .font(.system(size: 10))
                        .lineLimit(1)
                }
                .foregroundStyle(theme.resolved.accent.color.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }

            Divider()

            // Content — always a ScrollView with fixed height to prevent popover resize crash.
            // PopoverHostingView.updateAnimatedWindowSize crashes with EXC_BAD_ACCESS when
            // the popover content changes height dynamically (tab switch, form toggle, item expand).
            // Fixed frame = no window resize = no crash.
            ScrollView {
                if filteredItems.isEmpty && !showNewForm {
                    VStack(spacing: 8) {
                        Image(systemName: activeTab == .ideas ? "lightbulb" : "brain")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(theme.mutedForeground.opacity(0.3))
                        Text(activeTab == .ideas ? "No ideas yet" : "No brain dumps yet")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.mutedForeground.opacity(0.5))
                        Text(
                            activeTab == .ideas
                                ? "Place your cursor on a line, then add an idea"
                                : "Dump raw thoughts — format & insert with AI"
                        )
                        .font(.system(size: 10))
                        .foregroundStyle(theme.mutedForeground.opacity(0.3))
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredItems) { item in
                            IdeaRow(
                                item: item,
                                isBusy: busyItemId == item.id,
                                theme: theme,
                                pageBody: currentBody,
                                onGoToLine: { goToLine(item.lineAnchor) },
                                onInsert: { insertIdea(item) },
                                onIntegrate: { integrateWithAI(item) },
                                onFormat: { formatWithAI(item) },
                                onDelete: { deleteIdea(item.id) }
                            )
                        }

                        // New item form — inside ScrollView to avoid popover resize
                        if showNewForm {
                            Divider().padding(.vertical, 4)
                            newItemForm
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .frame(height: 340)

            Divider()

            // Add button
            Button {
                showNewForm.toggle()
                if showNewForm {
                    newTitle = ""
                    newBody = ""
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showNewForm ? "xmark" : "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text(
                        showNewForm
                            ? "Cancel" : (activeTab == .ideas ? "New Idea" : "New Brain Dump")
                    )
                    .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(showNewForm ? theme.mutedForeground : theme.resolved.accent.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .frame(width: 340)
        .onAppear {
            guard !didApplyInitial else { return }
            didApplyInitial = true
            if let tab = initialTab {
                activeTab = tab
            }
            if autoShowForm {
                showNewForm = true
                newTitle = ""
                newBody = ""
            }
        }
    }

    // MARK: - New Item Form

    private var newItemForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show current anchor line context
            let anchor = currentCursorLine()
            if let anchor {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 8))
                    Text("Anchored to line \(anchor.line)")
                        .font(.system(size: 9, weight: .medium))
                    if let ctx = anchor.context, !ctx.isEmpty {
                        Text("· \(ctx)")
                            .font(.system(size: 9))
                            .lineLimit(1)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .foregroundStyle(theme.resolved.accent.color.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.resolved.accent.color.opacity(0.08), in: Capsule())
            }

            TextField(activeTab == .ideas ? "Idea title" : "Brain dump title", text: $newTitle)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .padding(8)
                .background(theme.glassBg, in: RoundedRectangle(cornerRadius: 8))

            TextEditor(text: $newBody)
                .font(.system(size: 11))
                .foregroundStyle(theme.resolved.foreground.color)
                .scrollContentBackground(.hidden)
                .frame(height: 80)
                .padding(4)
                .background(theme.glassBg, in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Spacer()
                Button("Save") { saveNewItem() }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.bordered)
                    .disabled(
                        newTitle.trimmingCharacters(in: .whitespaces).isEmpty
                            && newBody.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Cursor / Line Helpers

    /// Get the current cursor line number (1-based) and the line's text content.
    @MainActor
    private func currentCursorLine() -> (line: Int, context: String?)? {
        // Walk the window list to find an NSTextView (editor might not be key when popover is open)
        guard let tv = NoteEditorViewFinder.findEditorTextView(for: self.page.id) else {
            return nil
        }
        let str = tv.string as NSString
        guard str.length > 0 else { return (1, nil) }
        let cursor = min(tv.selectedRange().location, str.length)
        let lineRange = str.lineRange(for: NSRange(location: cursor, length: 0))
        let lineText = str.substring(with: lineRange)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        // Count line number (1-based)
        var lineNum = 1
        str.enumerateSubstrings(
            in: NSRange(location: 0, length: min(cursor, str.length)),
            options: [
                NSString.EnumerationOptions.byLines,
                NSString.EnumerationOptions.substringNotRequired,
            ]
        ) { _, _, _, _ in lineNum += 1 }

        let snippet = lineText.isEmpty ? nil : String(lineText.prefix(80))
        return (lineNum, snippet)
    }

    // MARK: - Actions

    private func saveNewItem() {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = newBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedBody.isEmpty else { return }

        let anchor = currentCursorLine()

        let idea = NoteIdea(
            type: activeTab == .ideas ? .idea : .brainDump,
            title: trimmedTitle.isEmpty
                ? (activeTab == .ideas ? "Untitled Idea" : "Brain Dump") : trimmedTitle,
            body: trimmedBody,
            lineAnchor: anchor?.line,
            lineContext: anchor?.context
        )

        var ideas = readIdeas()
        ideas.append(idea)
        writeIdeas(ideas)

        newTitle = ""
        newBody = ""
        showNewForm = false
    }

    private func deleteIdea(_ id: String) {
        var ideas = readIdeas()
        ideas.removeAll { $0.id == id }
        writeIdeas(ideas)
    }

    /// Navigate the editor to the anchor line of an idea.
    private func goToLine(_ line: Int?) {
        guard let line, let tv = NoteEditorViewFinder.findEditorTextView(for: page.id) else {
            return
        }
        let str = tv.string as NSString
        var currentLine = 1
        var targetRange = NSRange(location: 0, length: 0)

        str.enumerateSubstrings(
            in: NSRange(location: 0, length: str.length),
            options: .byLines
        ) { _, substringRange, _, stop in
            if currentLine == line {
                targetRange = substringRange
                stop.pointee = true
            }
            currentLine += 1
        }

        tv.setSelectedRange(targetRange)
        tv.scrollRangeToVisible(targetRange)
        tv.window?.makeKeyAndOrderFront(nil)
    }

    /// Insert the idea's body text at the anchor line.
    private func insertIdea(_ item: NoteIdea) {
        guard let tv = NoteEditorViewFinder.findEditorTextView(for: page.id) else { return }
        let textToInsert = item.formattedBody ?? item.body
        guard !textToInsert.isEmpty else { return }

        let str = tv.string as NSString

        if let line = item.lineAnchor {
            // Find the end of the anchor line and insert after it
            var currentLine = 1
            var insertLocation = str.length

            str.enumerateSubstrings(
                in: NSRange(location: 0, length: str.length),
                options: .byLines
            ) { _, substringRange, enclosingRange, stop in
                if currentLine == line {
                    insertLocation = NSMaxRange(enclosingRange)
                    stop.pointee = true
                }
                currentLine += 1
            }

            let insertion = textToInsert.hasSuffix("\n") ? textToInsert : textToInsert + "\n"
            tv.insertText(insertion, replacementRange: NSRange(location: insertLocation, length: 0))
        } else {
            // No anchor — insert at cursor
            let insertion = textToInsert.hasSuffix("\n") ? textToInsert : textToInsert + "\n"
            tv.insertText(insertion, replacementRange: tv.selectedRange())
        }

        tv.window?.makeKeyAndOrderFront(nil)
        eventBus.emitToast("Inserted", type: .success)
    }

    /// Use Apple Intelligence to deeply integrate a brain dump / idea into the note.
    /// Uses the editor selection captured BEFORE the popover opened (popover steals focus).
    /// Sends the full note for context so AI understands the broader piece.
    private func integrateWithAI(_ item: NoteIdea) {
        guard busyItemId == nil else { return }

        let ideaText = item.formattedBody ?? item.body
        guard !ideaText.isEmpty else { return }

        let fullBody = currentBody
        let noteTitle = page.title

        // Use the selection captured before the popover opened
        let targetText: String
        let replaceRange: NSRange

        if let sel = capturedSelection, let selText = capturedSelectionText, !selText.isEmpty {
            // User had text highlighted when they opened the panel
            targetText = selText
            replaceRange = sel
        } else if let line = item.lineAnchor {
            // No selection — use the anchor line's paragraph
            let lines = fullBody.components(separatedBy: "\n")
            let safeIdx = min(max(line - 1, 0), lines.count - 1)
            let start = max(0, safeIdx - 3)
            let end = min(lines.count - 1, safeIdx + 3)
            targetText = lines[start...end].joined(separator: "\n")

            // Find the NSRange covering those lines
            let nsBody = fullBody as NSString
            var lineIdx = 0
            var rStart = 0
            var rEnd = nsBody.length
            nsBody.enumerateSubstrings(
                in: NSRange(location: 0, length: nsBody.length),
                options: .byLines
            ) { _, _, enclosingRange, stop in
                if lineIdx == start { rStart = enclosingRange.location }
                if lineIdx == end {
                    rEnd = NSMaxRange(enclosingRange)
                    stop.pointee = true
                }
                lineIdx += 1
            }
            replaceRange = NSRange(location: rStart, length: rEnd - rStart)
        } else {
            eventBus.emitToast("Highlight text first, then Integrate", type: .info)
            return
        }

        busyItemId = item.id

        // Build surrounding context — paragraphs before and after the target
        // so the AI understands what comes before and after.
        let nsBody = fullBody as NSString
        let beforeStart = max(0, replaceRange.location - 500)
        let beforeLen = replaceRange.location - beforeStart
        let afterStart = NSMaxRange(replaceRange)
        let afterLen = min(500, nsBody.length - afterStart)

        let textBefore =
            beforeLen > 0
            ? nsBody.substring(with: NSRange(location: beforeStart, length: beforeLen))
            : ""
        let textAfter =
            afterLen > 0
            ? nsBody.substring(with: NSRange(location: afterStart, length: afterLen))
            : ""

        Task {
            do {
                let prompt = """
                    Rewrite a section of the note titled "\(noteTitle)".

                    CONTEXT BEFORE the target section:
                    \(textBefore.isEmpty ? "(start of note)" : textBefore)

                    TARGET SECTION TO REWRITE (this is what you must replace):
                    ---
                    \(targetText)
                    ---

                    CONTEXT AFTER the target section:
                    \(textAfter.isEmpty ? "(end of note)" : textAfter)

                    NEW CONTENT TO INTEGRATE (brain dump / idea from the user):
                    Title: \(item.title)
                    Content: \(ideaText)

                    INSTRUCTIONS:
                    1. Combine the TARGET SECTION and the NEW CONTENT into ONE rewritten block.
                    2. The new content's ideas must be DEEPLY WOVEN into the existing text — not appended, not listed separately, not tacked on at the end.
                    3. The result must flow naturally from the CONTEXT BEFORE and into the CONTEXT AFTER.
                    4. Preserve the author's voice, markdown formatting, and academic tone.
                    5. Return ONLY the rewritten target section. No explanation, no preamble, no "Here is the rewritten section:" prefix.
                    """

                let result = try await AppleIntelligenceService.shared.generate(
                    prompt: prompt,
                    systemPrompt: nil
                )

                let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else {
                    busyItemId = nil
                    return
                }

                guard let tv = NoteEditorViewFinder.findEditorTextView(for: page.id) else {
                    busyItemId = nil
                    return
                }

                // Verify the range is still valid (user may have edited in between)
                let currentLength = (tv.string as NSString).length
                let safeRange: NSRange
                if NSMaxRange(replaceRange) <= currentLength {
                    safeRange = replaceRange
                } else {
                    // Range shifted — insert at end as fallback
                    safeRange = NSRange(location: currentLength, length: 0)
                }

                let replacement = cleaned.hasSuffix("\n") ? cleaned : cleaned + "\n"
                tv.insertText(replacement, replacementRange: safeRange)
                tv.window?.makeKeyAndOrderFront(nil)

                busyItemId = nil
                eventBus.emitToast("Integrated into note", type: .success)
            } catch {
                busyItemId = nil
                eventBus.emitToast(
                    "Apple Intelligence: \(error.localizedDescription)", type: .error)
            }
        }
    }

    /// Use Apple Intelligence to format a brain dump into coherent text.
    private func formatWithAI(_ item: NoteIdea) {
        guard busyItemId == nil else { return }
        busyItemId = item.id

        Task {
            do {
                let prompt = """
                    Take this raw brain dump and format it into a clear, coherent paragraph or set of points. \
                    Keep the original meaning and ideas intact. Don't add new ideas — just clean up the language, \
                    fix grammar, organize the thoughts, and make it readable. Return ONLY the formatted text.

                    Brain dump:
                    \(item.body)
                    """

                let result = try await AppleIntelligenceService.shared.generate(
                    prompt: prompt,
                    systemPrompt: nil
                )

                let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else {
                    busyItemId = nil
                    return
                }

                var ideas = readIdeas()
                if let idx = ideas.firstIndex(where: { $0.id == item.id }) {
                    ideas[idx].formattedBody = cleaned
                    writeIdeas(ideas)
                }
                busyItemId = nil
            } catch {
                busyItemId = nil
                eventBus.emitToast(
                    "Apple Intelligence: \(error.localizedDescription)", type: .error)
            }
        }
    }
}

// MARK: - Idea Row

private struct IdeaRow: View {
    let item: NoteIdea
    let isBusy: Bool
    let theme: EpistemosTheme
    let pageBody: String
    let onGoToLine: () -> Void
    let onInsert: () -> Void
    let onIntegrate: () -> Void
    let onFormat: () -> Void
    let onDelete: () -> Void

    @State private var isExpanded = false
    @State private var showFormatted = true

    /// Live line context — re-reads from current note body in case lines shifted.
    private var liveLineContext: String? {
        guard let line = item.lineAnchor else { return nil }
        let lines = pageBody.components(separatedBy: "\n")
        guard line >= 1, line <= lines.count else { return item.lineContext }
        let text = lines[line - 1].trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? item.lineContext : String(text.prefix(60))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title + anchor context
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: item.type == .idea ? "lightbulb.fill" : "brain")
                    .font(.system(size: 10))
                    .foregroundStyle(item.type == .idea ? .yellow : .purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.resolved.foreground.color)
                        .lineLimit(isExpanded ? nil : 1)

                    if !item.body.isEmpty {
                        let displayText = (showFormatted ? item.formattedBody : nil) ?? item.body
                        Text(displayText)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.mutedForeground)
                            .lineLimit(isExpanded ? nil : 2)
                            .lineSpacing(2)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { isExpanded.toggle() }

                Spacer()

                if isBusy {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.textTertiary)
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove idea")
                    .help("Remove")
                }
            }

            // Line anchor badge — click to navigate
            if let line = item.lineAnchor {
                Button {
                    onGoToLine()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin")
                            .font(.system(size: 7))
                        Text("Line \(line)")
                            .font(.system(size: 9, weight: .medium))
                        if let ctx = liveLineContext {
                            Text("· \(ctx)")
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .foregroundStyle(theme.resolved.accent.color.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.resolved.accent.color.opacity(0.08), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Go to line \(line)")
            }

            // Action bar — Insert / Integrate / Format
            if isExpanded && !isBusy {
                HStack(spacing: 8) {
                    // Insert at anchor
                    Button {
                        onInsert()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "text.insert")
                                .font(.system(size: 9))
                            Text("Insert")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(theme.resolved.accent.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.resolved.accent.color.opacity(0.1), in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Insert at anchor line")
                    .help("Insert text at anchor line")

                    // Integrate with AI
                    Button {
                        onIntegrate()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                            Text("Integrate")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1), in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Integrate with AI")
                    .help("AI integrates this into the note")

                    // Format brain dump (brain dumps only, no formatted body yet)
                    if item.type == .brainDump && item.formattedBody == nil && !item.body.isEmpty {
                        Button {
                            onFormat()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 9))
                                Text("Format")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1), in: Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Format with AI")
                        .help("Format with Apple Intelligence")
                    }

                    // Toggle raw/formatted (brain dumps with formatted body)
                    if item.type == .brainDump && item.formattedBody != nil {
                        Button {
                            showFormatted.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showFormatted ? "text.quote" : "text.alignleft")
                                    .font(.system(size: 9))
                                Text(showFormatted ? "Raw" : "Formatted")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundStyle(theme.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.glassBg, in: Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
            }

            // Timestamp + badges
            HStack(spacing: 8) {
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary.opacity(0.6))
                if item.formattedBody != nil {
                    Text("AI formatted")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(theme.resolved.accent.color.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(theme.resolved.accent.color.opacity(0.1), in: Capsule())
                }
            }
        }
        .padding(8)
        .background(theme.glassBg, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(theme.glassBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Transition Greeting View
// A solid full-screen overlay with a centered mode label.
// Fully opaque to mask the SwiftUI view-swap glitch during mode transitions.
// Background and text colors match the current theme.

private struct TransitionGreetingView: View {
    let message: String
    let theme: EpistemosTheme

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            Text(message)
                .font(AppDisplayTypography.font(size: 44))
                .foregroundStyle(theme.fontAccent)
        }
    }
}

nonisolated private struct NoteLegacyRecoveryPresentation: Equatable, @unchecked Sendable {
    let pageId: String
    let filePath: String
    let rawData: Data
    let rawDecodedText: String
    let analysis: CorruptionAnalysis
    let repairCandidates: [RepairCandidate]
    let binaryExtraction: BinaryTextExtraction?
    let paddingRatio: Double

    nonisolated init(
        pageId: String,
        filePath: String,
        rawData: Data,
        rawDecodedText: String,
        analysis: CorruptionAnalysis,
        repairCandidates: [RepairCandidate],
        binaryExtraction: BinaryTextExtraction?,
        paddingRatio: Double
    ) {
        self.pageId = pageId
        self.filePath = filePath
        self.rawData = rawData
        self.rawDecodedText = rawDecodedText
        self.analysis = analysis
        self.repairCandidates = repairCandidates
        self.binaryExtraction = binaryExtraction
        self.paddingRatio = paddingRatio
    }

    nonisolated var hasEncodingIssues: Bool {
        analysis.classification != "likely_clean" || paddingRatio >= 0.05
    }

    nonisolated var formattedClassification: String {
        analysis.classification
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    nonisolated var bestRepairCandidate: RepairCandidate? {
        repairCandidates.first(where: { $0.score >= 0.35 && $0.repairedText != rawDecodedText })
            ?? repairCandidates.first
    }

    nonisolated var preferredDecodedText: String {
        if let bestRepairCandidate, bestRepairCandidate.score >= 0.35 {
            return bestRepairCandidate.repairedText
        }
        if let binaryExtraction {
            let extracted = binaryExtraction.readableText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !extracted.isEmpty {
                return extracted
            }
        }
        return rawDecodedText
    }

    nonisolated var preferredDecodedTitle: String {
        if bestRepairCandidate != nil {
            return "Best Repair Candidate"
        }
        if binaryExtraction != nil {
            return "Extracted Text Regions"
        }
        return "Decoded UTF-8"
    }

    nonisolated var preferredDecodedSubtitle: String? {
        if let bestRepairCandidate {
            return "\(bestRepairCandidate.chain) • score \(String(format: "%.2f", bestRepairCandidate.score))"
        }
        if paddingRatio >= 0.05 {
            return "Recovered from binary-like regions"
        }
        return nil
    }

    nonisolated var prefersHexAutoMode: Bool {
        paddingRatio >= 0.08 && (bestRepairCandidate?.score ?? 0) < 0.55
    }

    nonisolated var prefersHexRawPane: Bool {
        paddingRatio >= 0.05
    }

    nonisolated static func load(pageId: String) -> NoteLegacyRecoveryPresentation? {
        guard let rawData = NoteFileStorage.readRawBodyData(pageId: pageId),
              let fileURL = NoteFileStorage.bodyFileURL(pageId: pageId) else {
            return nil
        }

        let bytes = [UInt8](rawData)
        let rawDecodedText = String(decoding: bytes, as: UTF8.self)
        let analysis = classifyCorruption(text: rawDecodedText, sourceEncoding: "utf-8")
        let paddingRatio = Double(rawData.lazy.filter { $0 == 0x00 || $0 == 0xFF }.count)
            / Double(max(rawData.count, 1))

        let shouldRepair = analysis.classification != "likely_clean"
            || rawDecodedText.contains("\u{FFFD}")
            || rawDecodedText.contains("Ã")
            || rawDecodedText.contains("Â")
        let repairCandidates = shouldRepair ? Array(repairMojibake(content: bytes).prefix(5)) : []

        let shouldExtractBinary =
            paddingRatio >= 0.05
            || rawData.contains(0x00 as UInt8)
            || rawData.contains(0xFF as UInt8)
        let binaryExtraction = shouldExtractBinary
            ? extractTextFromBinary(content: bytes, encodingLabel: "utf-8")
            : nil

        let presentation = NoteLegacyRecoveryPresentation(
            pageId: pageId,
            filePath: fileURL.path,
            rawData: rawData,
            rawDecodedText: rawDecodedText,
            analysis: analysis,
            repairCandidates: repairCandidates,
            binaryExtraction: binaryExtraction,
            paddingRatio: paddingRatio
        )
        return presentation.hasEncodingIssues ? presentation : nil
    }
}

private struct LegacyRecoveryBanner: View {
    let theme: EpistemosTheme
    let inspect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("This file appears to have encoding issues")
                    .font(AppDisplayTypography.font(size: 13))
                Text("Open recovery tools to inspect repaired text, raw bytes, and binary regions.")
                    .font(AppDisplayTypography.font(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button("Inspect", action: inspect)
                .buttonStyle(.borderedProminent)
                .tint(Color.orange.opacity(theme.isDark ? 0.9 : 0.75))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.28), lineWidth: 0.8)
        }
    }
}

private enum LegacyRecoveryViewMode: String, CaseIterable, Identifiable {
    case auto
    case dual
    case raw

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto:
            "Auto"
        case .dual:
            "Dual"
        case .raw:
            "Raw"
        }
    }
}

private struct LegacyRecoverySheet: View {
    let title: String
    let presentation: NoteLegacyRecoveryPresentation
    let theme: EpistemosTheme
    @State private var mode: LegacyRecoveryViewMode = .auto

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            content
        }
        .padding(20)
        .frame(minWidth: 920, minHeight: 680)
        .background(NoteWorkspaceSurfaceStyle.canvasBackground(for: theme).ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(AppDisplayTypography.font(size: 18))
                    Label("This file appears to have encoding issues", systemImage: "exclamationmark.triangle.fill")
                        .font(AppDisplayTypography.font(size: 13))
                        .foregroundStyle(Color.orange)
                    Text(presentation.analysis.detail)
                        .font(AppDisplayTypography.font(size: 12))
                        .foregroundStyle(.secondary)
                    Text(presentation.filePath)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 12)
                Picker("Mode", selection: $mode) {
                    ForEach(LegacyRecoveryViewMode.allCases) { candidate in
                        Text(candidate.label).tag(candidate)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }

            HStack(spacing: 8) {
                LegacyInfoChip(label: "Class", value: presentation.formattedClassification)
                LegacyInfoChip(label: "Encoding", value: presentation.analysis.likelyTrueEncoding)
                LegacyInfoChip(
                    label: "Padding",
                    value: "\(presentation.paddingRatio.isFinite ? Int((presentation.paddingRatio * 100).rounded()) : 0)%"
                )
                if let candidate = presentation.bestRepairCandidate {
                    LegacyInfoChip(
                        label: "Top Repair",
                        value: String(format: "%.2f", candidate.score)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .auto:
            if presentation.prefersHexAutoMode {
                LegacyHexViewer(data: presentation.rawData)
            } else {
                LegacyRecoveryTextPanel(
                    title: presentation.preferredDecodedTitle,
                    subtitle: presentation.preferredDecodedSubtitle,
                    text: presentation.preferredDecodedText
                )
            }
        case .dual:
            VStack(spacing: 14) {
                LegacyRecoveryTextPanel(
                    title: presentation.preferredDecodedTitle,
                    subtitle: presentation.preferredDecodedSubtitle,
                    text: presentation.preferredDecodedText
                )
                if presentation.prefersHexRawPane {
                    LegacyHexViewer(data: presentation.rawData, title: "Raw Original")
                } else {
                    LegacyRecoveryTextPanel(
                        title: "Raw Original",
                        subtitle: "Lossy UTF-8 decode from on-disk bytes",
                        text: presentation.rawDecodedText
                    )
                }
            }
        case .raw:
            LegacyHexViewer(data: presentation.rawData)
        }
    }
}

private struct LegacyInfoChip: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(AppDisplayTypography.font(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }
}

private struct LegacyRecoveryTextPanel: View {
    let title: String
    let subtitle: String?
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppDisplayTypography.font(size: 14))
            if let subtitle {
                Text(subtitle)
                    .font(AppDisplayTypography.font(size: 11))
                    .foregroundStyle(.secondary)
            }
            ScrollView([.vertical, .horizontal]) {
                Text(text.isEmpty ? "No readable text extracted." : text)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct LegacyHexViewer: View {
    let data: Data
    var title: String = "Raw Bytes"

    private var rows: [String] {
        let bytes = [UInt8](data)
        guard !bytes.isEmpty else { return ["00000000  --  (empty)"] }

        return stride(from: 0, to: bytes.count, by: 16).map { offset in
            let slice = Array(bytes[offset..<min(offset + 16, bytes.count)])
            let hex = slice.map { String(format: "%02X", $0) }.joined(separator: " ")
            let paddedHex = hex.padding(toLength: 47, withPad: " ", startingAt: 0)
            let ascii = slice.map { byte -> Character in
                if byte >= 0x20 && byte < 0x7F {
                    return Character(UnicodeScalar(byte))
                }
                return "·"
            }
            return String(format: "%08X  %@  %@", offset, paddedHex, String(ascii))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppDisplayTypography.font(size: 14))
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        Text(row)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
