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

enum NoteWorkspaceSurfaceStyle {
    static let minimumEditorSize = CGSize(width: 400, height: 300)
    static let editorCornerRadius: CGFloat = 26
    static let editorMaxWidth: CGFloat = 1080
    static let horizontalPadding: CGFloat = 28
    static let topPadding: CGFloat = 24
    static let bottomPadding: CGFloat = 72

    static func canvasBackground(for theme: EpistemosTheme) -> Color {
        if theme.usesNativeWindowBlur {
            return .clear
        }
        return MarkdownPreviewSurfaceStyle.canvasBackground(for: theme)
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
        ShortcutHint(key: "S", label: "Save to Disk"),
        ShortcutHint(key: "2", label: "Note Sidebar"),
    ]
}

enum NoteWorkspaceQuickAction: CaseIterable, Hashable {
    case saveToDisk
    case notesSidebar

    var glyph: NoteToolbarGlyph {
        switch self {
        case .saveToDisk:
            .saveToDisk
        case .notesSidebar:
            .notesSidebar
        }
    }

    var title: String {
        switch self {
        case .saveToDisk:
            "Save to Disk"
        case .notesSidebar:
            "Open Notes Sidebar"
        }
    }

    var shortcut: String {
        switch self {
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

enum NotePreviewPerformancePolicy {
    static let showsOverlayBadge = false
}

enum NotePreviewChromeMetrics {
    static let fallbackSingleTopInset: CGFloat = 46
    static let fallbackTabbedTopInset: CGFloat = 78

    static func contentTopInset(titlebarInset: CGFloat, hasMultipleTabs: Bool) -> CGFloat {
        guard titlebarInset > 0 else {
            return hasMultipleTabs ? fallbackTabbedTopInset : fallbackSingleTopInset
        }
        return titlebarInset
    }

    static func titlebarInset(for window: NSWindow) -> CGFloat {
        let inset = max(0, window.frame.height - window.contentLayoutRect.maxY)
        return inset.isFinite ? inset : 0
    }
}

enum NotePreviewDisplay {
    static func renderedMarkdown(_ markdown: String) -> String {
        markdown
    }
}

enum NoteDualPreviewLayout {
    static let minimumWidth: CGFloat = 1180
    static let pageSpacing: CGFloat = 28
    static let pageMaxWidth: CGFloat = 580
    static let defaultSinglePageMaxWidth: CGFloat = 920
    static let defaultEditorSurfaceMaxWidth: CGFloat = 1000
    static let tableSinglePageMaxWidth: CGFloat = 840
    static let tableReadableMaxWidth: CGFloat = 740
    static let tableEditorReadableMaxWidth: CGFloat = 520
    static let previewTextReadableMaxWidth: CGFloat = 760
    static let editorTextReadableMaxWidth: CGFloat = 840
    static let minimumTextHorizontalInset: CGFloat = 60
    static let outerPadding = EdgeInsets(top: 28, leading: 32, bottom: 40, trailing: 32)
    static let pagePadding = EdgeInsets(top: 34, leading: 38, bottom: 36, trailing: 38)
    static let sectionTargetCharacterCount = 900
    static let sectionSoftOverflowFloor = 160

    private enum PreviewBlockKind {
        case heading
        case prose
        case isolated
    }

    static func usesDualColumns(for availableWidth: CGFloat) -> Bool {
        availableWidth >= minimumWidth
    }

    static func containsTable(in markdown: String) -> Bool {
        paragraphBlocks(in: markdown).contains(where: isTableBlock)
    }

    static func singlePageMaxWidth(for markdown: String) -> CGFloat {
        containsTable(in: markdown) ? tableSinglePageMaxWidth : defaultSinglePageMaxWidth
    }

    static func singlePageWidth(for markdown: String, availableWidth: CGFloat) -> CGFloat {
        let usableWidth = max(0, availableWidth - outerPadding.leading - outerPadding.trailing)
        return min(singlePageMaxWidth(for: markdown), usableWidth)
    }

    static func dualPageWidth(for availableWidth: CGFloat) -> CGFloat {
        let usableWidth = max(
            0,
            availableWidth - outerPadding.leading - outerPadding.trailing - pageSpacing
        )
        return min(pageMaxWidth, usableWidth / 2)
    }

    static func readableWidth(for markdown: String, defaultWidth: CGFloat) -> CGFloat {
        containsTable(in: markdown) ? min(defaultWidth, tableReadableMaxWidth) : defaultWidth
    }

    static func editorReadableWidth(for markdown: String, defaultWidth: CGFloat) -> CGFloat {
        if containsTable(in: markdown) {
            return min(defaultWidth, tableEditorReadableMaxWidth)
        }
        return min(defaultWidth, defaultEditorSurfaceMaxWidth)
    }

    static func centeredTextInset(
        for availableWidth: CGFloat,
        markdown: String,
        maxReadableWidth: CGFloat
    ) -> CGFloat {
        guard availableWidth.isFinite else { return minimumTextHorizontalInset }
        guard !containsTable(in: markdown) else { return minimumTextHorizontalInset }

        let clampedWidth = max(0, availableWidth)
        return max(minimumTextHorizontalInset, (clampedWidth - maxReadableWidth) / 2)
    }

    static func paragraphBlocks(in markdown: String) -> [String] {
        var blocks: [String] = []
        var current: [String] = []
        var isInsideCodeFence = false

        func flushCurrent() {
            let block = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !block.isEmpty {
                blocks.append(block)
            }
            current.removeAll(keepingCapacity: true)
        }

        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let currentLine = String(line)
            let trimmed = currentLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                current.append(currentLine)
                isInsideCodeFence.toggle()
                continue
            }
            if !isInsideCodeFence && trimmed.isEmpty {
                flushCurrent()
                continue
            }
            current.append(currentLine)
        }

        flushCurrent()
        return blocks
    }

    static func bookSections(
        in markdown: String,
        targetCharacterCount: Int = sectionTargetCharacterCount
    ) -> [String] {
        let blocks = paragraphBlocks(in: markdown)
        guard !blocks.isEmpty else { return [] }

        var sections: [String] = []
        var current: [String] = []
        var currentWeight = 0

        func flushCurrent() {
            let section = current.joined(separator: "\n\n").trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if !section.isEmpty {
                sections.append(section)
            }
            current.removeAll(keepingCapacity: true)
            currentWeight = 0
        }

        for block in blocks {
            let kind = classify(block)
            let blockWeight = sectionWeight(block)

            switch kind {
            case .heading:
                flushCurrent()
                current = [block]
                currentWeight = blockWeight

            case .prose:
                if current.isEmpty {
                    current = [block]
                    currentWeight = blockWeight
                } else if shouldAppend(
                    blockWeight: blockWeight,
                    to: current,
                    currentWeight: currentWeight,
                    targetCharacterCount: targetCharacterCount
                ) {
                    current.append(block)
                    currentWeight += blockWeight
                } else {
                    flushCurrent()
                    current = [block]
                    currentWeight = blockWeight
                }

            case .isolated:
                if current.count == 1, classify(current[0]) == .heading {
                    current.append(block)
                    flushCurrent()
                } else {
                    flushCurrent()
                    sections.append(block)
                }
            }
        }

        flushCurrent()
        return sections
    }

    static func columnContents(
        in markdown: String,
        targetCharacterCount: Int = sectionTargetCharacterCount
    ) -> [String] {
        let sections = bookSections(in: markdown, targetCharacterCount: targetCharacterCount)
        guard !sections.isEmpty else { return [] }
        guard sections.count > 1 else { return sections }

        let weights = sections.map(sectionWeight)
        let target = weights.reduce(0, +) / 2
        var running = 0
        var bestSplit = 1
        var bestDelta = Int.max

        for index in 0..<(sections.count - 1) {
            running += weights[index]
            let delta = abs(target - running)
            if delta < bestDelta {
                bestDelta = delta
                bestSplit = index + 1
            }
        }

        return [
            sections[..<bestSplit].joined(separator: "\n\n"),
            sections[bestSplit...].joined(separator: "\n\n"),
        ]
    }

    private static func classify(_ block: String) -> PreviewBlockKind {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") {
            return .heading
        }
        if trimmed.hasPrefix("```")
            || trimmed == "---"
            || trimmed == "***"
            || trimmed == "___"
            || isTableBlock(trimmed)
        {
            return .isolated
        }
        return .prose
    }

    private static func isTableBlock(_ block: String) -> Bool {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: true)
        guard !lines.isEmpty else { return false }
        return lines.allSatisfy { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
        }
    }

    private static func sectionWeight(_ section: String) -> Int {
        let lineCount = section.split(separator: "\n", omittingEmptySubsequences: false).count
        return section.count + max(0, lineCount - 1) * 20
    }

    private static func shouldAppend(
        blockWeight: Int,
        to current: [String],
        currentWeight: Int,
        targetCharacterCount: Int
    ) -> Bool {
        let combinedWeight = currentWeight + blockWeight
        if combinedWeight <= targetCharacterCount {
            return true
        }
        if current.count == 1, classify(current[0]) == .heading {
            return true
        }
        if currentWeight < targetCharacterCount {
            let overflowAllowance = max(targetCharacterCount / 3, sectionSoftOverflowFloor)
            return combinedWeight <= targetCharacterCount + overflowAllowance
        }
        return false
    }
}

enum NoteToolbarGlyph: Sendable {
    case format
    case preview
    case edit
    case miniChat
    case writingTools
    case more
    case backlinks
    case history
    case recovery
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
        case .miniChat:
            "bubble.left.and.text.bubble.right"
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

    @Environment(NoteNavigationState.self) private var navState: NoteNavigationState?
    @Environment(GraphState.self) private var graphState
    @Environment(InferenceState.self) private var inference
    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(EventBus.self) private var eventBus
    @Environment(TriageService.self) private var triageService
    @Environment(\.modelContext) private var modelContext
    @Query private var pages: [SDPage]
    @State private var showDiffSheet = false
    @State private var showInfoPopover = false
    @State private var showPreview = false
    @State private var modeBodySnapshot: NoteModeBodySnapshot?
    @State private var persistedBody: String
    @State private var showLegacyRecoverySheet = false
    @State private var legacyRecoveryPresentation: NoteLegacyRecoveryPresentation?
    @State private var legacyRecoveryRefreshTask: Task<Void, Never>?

    @State private var showIdeasPopover = false
    @State private var showChatSidebar = false
    @State private var showBacklinksPopover = false
    @State private var hasMultipleTabs = false
    @State private var wordCount: Int = 0
    @State private var tocItems: [TOCItem] = []
    @State private var wordCountDebounce: Task<Void, Never>?
    @State private var metricsTask: Task<Void, Never>?
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
    /// Per-note AI chat state (one per open note tab).
    @State private var noteChatState: NoteChatState
    @AppStorage("epistemos.noteChatOperatingMode")
    private var noteChatOperatingModeRaw = EpistemosOperatingMode.fast.rawValue
    @MainActor
    init(pageId: String) {
        self.pageId = pageId
        _pages = Query(filter: #Predicate<SDPage> { $0.id == pageId })
        _noteChatState = State(initialValue: NoteChatState(pageId: pageId))
        _persistedBody = State(initialValue: NoteWindowManager.shared.currentBody(for: pageId))
    }

    static func resolvedPersistedBody(_ persistedBody: String, for page: SDPage) -> String {
        if !persistedBody.isEmpty {
            return persistedBody
        }
        return page.body
    }

    private var supportedNoteChatOperatingModes: [EpistemosOperatingMode] {
        let modes = inference.availableOperatingModes.filter { $0 != .agent }
        return modes.isEmpty ? [.fast] : modes
    }

    private var selectedNoteChatOperatingMode: EpistemosOperatingMode {
        get {
            MainChatOperatingModePreference.sanitize(
                EpistemosOperatingMode(rawValue: noteChatOperatingModeRaw) ?? .fast,
                for: inference,
                availableModes: supportedNoteChatOperatingModes
            )
        }
        nonmutating set {
            noteChatOperatingModeRaw = MainChatOperatingModePreference.sanitize(
                newValue,
                for: inference,
                availableModes: supportedNoteChatOperatingModes
            ).rawValue
        }
    }

    private var noteChatOperatingModeBinding: Binding<EpistemosOperatingMode> {
        Binding(
            get: { selectedNoteChatOperatingMode },
            set: { selectedNoteChatOperatingMode = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            noteCanvas
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            NoteWorkspaceSurfaceStyle.canvasBackground(for: ui.theme).ignoresSafeArea()
        }
        .toolbar {
            if let nav = navState, nav.hasBreadcrumb {
                ToolbarItem(placement: .navigation) {
                    wikilinksNavButtons(nav: nav)
                }
            }
            if !isCodeFile {
                ToolbarItem(placement: .principal) {
                    noteToolbarAskItem
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                noteToolbarPrimaryActions
            }
        }
        .preferredColorScheme(ui.preferredColorScheme)
        .background {
            // Hidden keyboard shortcut buttons
            Button("") {
                Task {
                    if let pageId = await vaultSync.createPage(title: "Untitled", allowVaultSelectionPrompt: true) {
                        NoteWindowManager.shared.open(pageId: pageId)
                    }
                }
            }
            .keyboardShortcut("n", modifiers: .command)
            .hidden()
            Button("") { vaultSync.savePage(pageId: pageId) }
                .keyboardShortcut("s", modifiers: .command)
                .hidden()
            Button("") { vaultSync.saveAllDirtyPages() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .hidden()
            Button("") { showDiffSheet = true }
                .keyboardShortcut("d", modifiers: .command)
                .hidden()
            Button("") { togglePreviewMode() }
                .keyboardShortcut("e", modifiers: .command)
                .hidden()

            Button("") { insertMarkdown("**", "**") }
                .keyboardShortcut("b", modifiers: .command)
                .hidden()
            Button("") { insertMarkdown("*", "*") }
                .keyboardShortcut("i", modifiers: .command)
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
            .hidden()
            Button("") { navState?.back() }
                .keyboardShortcut("[", modifiers: .command)
                .hidden()
            Button("") { navState?.forward() }
                .keyboardShortcut("]", modifiers: .command)
                .hidden()
            Button("") { notesUI.isFocusMode.toggle() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
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
            NotificationCenter.default.publisher(for: .init("ProseEditorUserDidType"))
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
            NotificationCenter.default.publisher(for: ProseTextView2.aiOperationNotification)
        ) { notif in
            guard let info = notif.userInfo as? [String: String],
                let op = info["operation"],
                info["pageId"] == pageId
            else { return }
            let selected = info["selectedText"]
            let instruction = info["instruction"]
            handleAIContextMenuOperation(op, selectedText: selected, instruction: instruction)
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
                        if showPreview {
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
                noteFooter
                .allowsHitTesting(false)
            }
            .overlay(alignment: .trailing) {
                let outlineMarkdown = pages.first.map(displayBody(for:)) ?? persistedBody
                NoteOutlineOverlay(
                    markdown: outlineMarkdown,
                    theme: ui.theme,
                    onNavigate: { charOffset in
                        scrollEditorTo(charOffset: charOffset)
                    },
                    externalItems: tocItems.isEmpty ? nil : tocItems
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NoteWorkspaceSurfaceStyle.canvasBackground(for: ui.theme))
            .environment(noteChatState)
            .onAppear {
                Task { @MainActor in
                    noteChatState.loadPersistedMessages(modelContext)
                    refreshTabCount()
                    if let page = pages.first {
                        let body = persistedBodyFor(page)
                        if persistedBody != body {
                            persistedBody = body
                        }
                        refreshLegacyRecoveryPresentation()
                        scheduleMetricsRefresh(
                            body: body,
                            includeMarkdownHeadings: true
                        )
                    } else {
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
                missingPageRecoveryTask?.cancel()
                missingPageRecoveryTask = nil
                legacyRecoveryRefreshTask?.cancel()
                legacyRecoveryRefreshTask = nil
                noteChatState.clear()
            }
            .onChange(of: pages.isEmpty) { _, isEmpty in
                if isEmpty {
                    queueMissingPageRecovery()
                } else {
                    missingPageRecoveryTask?.cancel()
                    missingPageRecoveryTask = nil
                    refreshLegacyRecoveryPresentation()
                }
            }
            .onChange(of: noteChatState.isStreaming) { wasStreaming, isNowStreaming in
                if wasStreaming && !isNowStreaming, let page = pages.first {
                    noteChatState.persistMessages(modelContext, noteTitle: page.title)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NoteFileStorage.pageBodyDidChange)) { notification in
                guard let changedId = notification.userInfo?["pageId"] as? String,
                      changedId == pageId else { return }
                let freshBody = NoteWindowManager.shared.currentBody(for: pageId)
                guard persistedBody != freshBody else { return }
                persistedBody = freshBody
                scheduleMetricsRefresh(body: freshBody, includeMarkdownHeadings: true)
                refreshLegacyRecoveryPresentation()
            }
        }
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

    /// Whether the current page is a code file (routed to CodeEditorView).
    private var isCodeFile: Bool {
        guard let page = pages.first,
              let path = page.filePath,
              CodeLanguage.detect(from: path) != nil else { return false }
        return true
    }

    private var noteFooter: some View {
        HStack(spacing: NoteWorkspaceFooterDisplay.chipSpacing) {
            // Code files have their own status bar — hide the word count overlay
            if !isCodeFile {
                noteFooterBubble {
                    Text("\(wordCount) words")
                        .font(AppDisplayTypography.font(size: 13))
                        .monospacedDigit()
                        .foregroundStyle(ui.theme.resolved.foreground.color.opacity(0.55))
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
        case .saveToDisk:
            vaultSync.savePage(pageId: pageId)
        case .notesSidebar:
            UtilityWindowManager.shared.show(.notes)
        }
    }

    private var codeFileLineCount: Int {
        guard let page = pages.first,
              let path = page.filePath else { return 0 }
        let content = codeFileContent(page: page, filePath: path)
        return content.components(separatedBy: "\n").count
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

    @ViewBuilder
    private func noteEditorSurface(page: SDPage, availableSize: CGSize) -> some View {
        if let path = page.filePath,
           let lang = CodeLanguage.detect(from: path) {
            CodeEditorView(
                content: codeFileContent(page: page, filePath: path),
                language: lang,
                filePath: path,
                onContentChange: { newContent in
                    saveCodeFileContent(page: page, filePath: path, content: newContent)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            let initialBodyOverride = currentModeBodySnapshot(for: page.id)
            let readableWidth = NoteDualPreviewLayout.editorReadableWidth(
                for: initialBodyOverride ?? currentEditorBody(for: page) ?? persistedBodyFor(page),
                defaultWidth: NoteWorkspaceSurfaceStyle.editorCardSize(for: availableSize).width
            )
            ProseEditorView(
                page: page,
                isEditable: true,
                initialBodyOverride: initialBodyOverride
            )
            .frame(width: readableWidth, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    /// Saves code file content back to disk and updates associated page state
    private func saveCodeFileContent(page: SDPage, filePath: String, content: String) {
        // Write to file
        do {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
            try Self.applyDirectCodeFileSave(
                content,
                to: page,
                modelContext: modelContext,
                graphState: AppBootstrap.shared?.graphState
            )
        } catch {
            Log.app.error("CodeEditor: failed to save code file: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    static func applyDirectCodeFileSave(
        _ content: String,
        to page: SDPage,
        modelContext: ModelContext,
        graphState: GraphState? = nil
    ) throws {
        // Code files are already written to their tracked vault path, so keep the page
        // synchronized without routing them back through markdown export.
        page.body = content
        page.blockReferences = SDPage.extractBlockReferences(from: content)
        page.wordCount = content.split(separator: " ").count
        page.updatedAt = .now
        page.lastSyncedBodyHash = SDPage.bodyHash(content)
        page.lastSyncedAt = .now
        page.needsVaultSync = false
        try modelContext.save()
        graphState?.needsRefresh = true
    }

    private var noteToolbarAskItem: some View {
        toolbarChatField(width: NoteToolbarMetrics.chatFieldWidth)
    }

    @ViewBuilder
    private var noteToolbarPrimaryActions: some View {
        Button {
            togglePreviewMode()
        } label: {
            Label(
                showPreview ? "Editor" : "Preview",
                systemImage: showPreview
                    ? (NoteToolbarGlyph.edit.symbolName ?? "pencil")
                    : (NoteToolbarGlyph.preview.symbolName ?? "eye")
            )
        }
        .help(showPreview ? "Editor (\u{2318}E)" : "Preview (\u{2318}E)")

        if !showPreview {
            Button {
                showChatSidebar.toggle()
            } label: {
                Label(
                    "Chat History",
                    systemImage: showChatSidebar
                        ? (NoteToolbarGlyph.history.activeSymbolName ?? "bubble.left.fill")
                        : (NoteToolbarGlyph.history.symbolName ?? "bubble.left")
                )
            }
            .help("Chat History")
            .popover(isPresented: $showChatSidebar, arrowEdge: .bottom) {
                NoteChatSidebar()
                    .environment(noteChatState)
                    .frame(width: 340, height: 380)
            }
        }

        moreMenu
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
            if includeMarkdownHeadings, tocItems != snapshot.headings {
                tocItems = snapshot.headings
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

    private func handleAIContextMenuOperation(
        _ op: String,
        selectedText: String?,
        instruction: String? = nil
    ) {
        // If selectedText wasn't in the notification,
        // grab the current selection from the first responder text view.
        let text: String =
            selectedText
            ?? {
                guard let tv = NoteEditorViewFinder.findEditorTextView(for: pageId) else {
                    return ""
                }
                let sel = tv.selectedRange()
                guard sel.length > 0 else { return "" }
                return (tv.string as NSString).substring(with: sel)
            }()
        let trimmedInstruction = instruction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let instructionSuffix =
            trimmedInstruction.isEmpty ? "" : "\n\nAdditional instruction: \(trimmedInstruction)"

        let mapping: (operation: NotesOperation, userPrompt: String) = {
            switch op {
            case "rewrite":
                return (
                    .rewrite,
                    "Rewrite the selected text to improve clarity and flow. Return only the rewritten text.\n\n\(text)\(instructionSuffix)"
                )
            case "proofread":
                return (
                    .rewrite,
                    "Fix grammar, spelling, and punctuation while preserving the original meaning and tone. Return only the corrected text.\n\n\(text)\(instructionSuffix)"
                )
            case "rewrite_friendly":
                return (
                    .rewrite,
                    "Rewrite the text in a warm, friendly, conversational tone. Return only the rewritten text.\n\n\(text)\(instructionSuffix)"
                )
            case "rewrite_professional":
                return (
                    .rewrite,
                    "Rewrite the text in a polished, professional tone. Return only the rewritten text.\n\n\(text)\(instructionSuffix)"
                )
            case "rewrite_concise":
                return (
                    .rewrite,
                    "Rewrite the text as concisely as possible while preserving the key meaning. Return only the rewritten text.\n\n\(text)\(instructionSuffix)"
                )
            case "summarize":
                return (
                    .summarize,
                    "Summarize the selected text concisely. Return only the summary.\n\n\(text)\(instructionSuffix)"
                )
            case "keyPoints":
                return (
                    .summarize,
                    "Extract the key points from the text as a concise markdown bullet list. Return only the bullet list.\n\n\(text)\(instructionSuffix)"
                )
            case "expand":
                return (
                    .expand,
                    "Expand the selected text with more detail and depth while keeping the same tone.\n\n\(text)\(instructionSuffix)"
                )
            case "simplify":
                return (
                    .rewrite,
                    "Simplify the text so it is easier to understand. Use shorter sentences. Return only the simplified text.\n\n\(text)\(instructionSuffix)"
                )
            case "toList":
                return (
                    .outline,
                    "Convert the text into a clean markdown bullet list. Return only the list.\n\n\(text)\(instructionSuffix)"
                )
            case "toTable":
                return (
                    .outline,
                    "Convert the text into a markdown table. Return only the table.\n\n\(text)\(instructionSuffix)"
                )
            case "continue":
                return (
                    .continueWriting,
                    "Continue writing from where this note ends. Match the existing tone and style. Return only the continuation.\(instructionSuffix)"
                )
            case "outline":
                return (
                    .outline,
                    "Generate a structured outline for this note using markdown headers and bullet points. Return only the outline.\(instructionSuffix)"
                )
            case "structure":
                return (
                    .analyze,
                    "Suggest a better structure for this note. Return only the reorganized version.\(instructionSuffix)"
                )
            case "restructure":
                return (
                    .analyze,
                    "Completely reorganize this note for better clarity, flow, and logical progression. Preserve all content and use markdown. Return only the full rewritten note.\(instructionSuffix)"
                )
            default:
                return (
                    .ask(query: text.isEmpty ? "Help me with this note." : text),
                    text.isEmpty
                        ? "Help me with this note.\(instructionSuffix)"
                        : "\(text)\(instructionSuffix)"
                )
            }
        }()

        noteChatState.submitQuery(
            mapping.userPrompt,
            operation: mapping.operation,
            triageService: triageService,
            operatingMode: selectedNoteChatOperatingMode
        )
    }

    // MARK: - Table of Contents Navigation

    private func scrollEditorTo(charOffset: Int) {
        // Find the active NSTextView and scroll to the character offset.
        guard let tv = NoteEditorViewFinder.findEditorTextView(for: pageId) else { return }

        let safeOffset = min(charOffset, tv.string.count)
        let range = NSRange(location: safeOffset, length: 0)
        tv.setSelectedRange(range)
        tv.scrollRangeToVisible(range)
        // Flash the line briefly by selecting the whole line
        let lineRange = (tv.string as NSString).lineRange(for: range)
        tv.showFindIndicator(for: lineRange)
    }

    // MARK: - Workspace Editor Restore

    private func applyEditorRestore(cursor: Int, scrollFraction: Double) {
        guard let tv = NoteEditorViewFinder.findEditorTextView(for: pageId) else { return }
        let safeCursor = min(cursor, tv.string.count)
        tv.setSelectedRange(NSRange(location: safeCursor, length: 0))
        if let scrollView = tv.enclosingScrollView,
           let docHeight = scrollView.documentView?.bounds.height, docHeight > 0 {
            let scrollY = scrollFraction * docHeight
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
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

    /// Load code file content: try managed storage first, fall back to reading the source file directly.
    private func codeFileContent(page: SDPage, filePath: String) -> String {
        if let snapshot = currentModeBodySnapshot(for: page.id), !snapshot.isEmpty {
            return snapshot
        }
        let managed = NoteWindowManager.shared.currentBody(for: page.id)
        if !managed.isEmpty {
            return managed
        }
        // Direct file read as final fallback (covers newly imported code files
        // whose body hasn't been written to NoteFileStorage yet)
        do {
            return try String(contentsOfFile: filePath, encoding: .utf8)
        } catch {
            Log.notes.error(
                "NoteDetailWorkspaceView: failed to read code file \(filePath, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return ""
        }
    }

    private func currentEditorBody(for page: SDPage) -> String? {
        if let responder = NoteEditorViewFinder.findEditorTextView(for: pageId) {
            return responder.string
        }
        return showPreview ? currentModeBodySnapshot(for: page.id) ?? persistedBodyFor(page) : nil
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
        guard NoteFileStorage.scheduleWriteBody(pageId: pageId, content: fullText) != nil else {
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
        flushCurrentEditor()
        showPreview.toggle()
    }

    @ViewBuilder
    private func notePreview(body: String) -> some View {
        AdaptiveNotePreviewView2(
            content: NotePreviewDisplay.renderedMarkdown(body),
            theme: ui.theme,
            hasMultipleTabs: hasMultipleTabs
        )
    }

    private func navigateToWikilink(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let exactDesc = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.title == trimmed }
        )
        let lowered = trimmed.lowercased()
        let exactMatch: SDPage?
        do {
            exactMatch = try modelContext.fetch(exactDesc).first
        } catch {
            Log.notes.error(
                "NoteDetailWorkspaceView: failed to fetch exact wikilink target: \(error.localizedDescription, privacy: .public)"
            )
            exactMatch = nil
        }
        let existing: SDPage? = exactMatch ?? {
            let allDesc = FetchDescriptor<SDPage>()
            do {
                let pages = try modelContext.fetch(allDesc)
                return pages.first(where: { $0.title.lowercased() == lowered })
            } catch {
                Log.notes.error(
                    "NoteDetailWorkspaceView: failed to fetch wikilink target pages: \(error.localizedDescription, privacy: .public)"
                )
                return nil
            }
        }()

        if let existing {
            if let navState {
                navState.push(pageId: existing.id, title: existing.title)
            } else {
                NoteWindowManager.shared.open(pageId: existing.id)
            }
        } else {
            Task {
                if let newId = await vaultSync.createPage(
                    title: trimmed,
                    allowVaultSelectionPrompt: true
                ) {
                    if let navState {
                        navState.push(pageId: newId, title: trimmed)
                    } else {
                        NoteWindowManager.shared.open(pageId: newId)
                    }
                }
            }
        }
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
            try? await Task.sleep(for: .milliseconds(Int(holdTime * 1000)))
            withAnimation(.easeOut(duration: 0.35)) {
                transitionOpacity = 0
            }
            try? await Task.sleep(for: .milliseconds(350))
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

    private var toolbarAskStatusPhase: AssistantComposerStatusPhase {
        AssistantComposerStatusPhase(notePhase: noteChatState.toolbarStatusPhase)
    }

    private var toolbarAskAccentColor: Color {
        ui.theme.resolved.accent.color
    }

    private var toolbarAskCapability: ChatCapability {
        let trimmed = noteChatState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCloudProvider: Bool = {
            switch inference.effectiveChatSurfaceSelection(for: selectedNoteChatOperatingMode) {
            case .cloud:
                return true
            case .localMLX, .appleIntelligence:
                return false
            }
        }()

        if !trimmed.isEmpty {
            return ChatCapability.predictIntent(
                text: trimmed,
                isCloudProvider: isCloudProvider
            ).predicted
        }

        return ChatCapability.classify(
            isCloudProvider: isCloudProvider,
            isAgentExecuting: false,
            isResearchMode: false,
            isThinkingMode: selectedNoteChatOperatingMode == .thinking || selectedNoteChatOperatingMode == .pro
        )
    }

    // MARK: - Toolbar Chat Field

    private func toolbarChatField(width: CGFloat) -> some View {
        @Bindable var chat = noteChatState

        return AssistantToolbarAskBar(
            text: $chat.inputText,
            placeholder: "Ask this note",
            phase: toolbarAskStatusPhase,
            theme: ui.theme,
            accent: toolbarAskAccentColor,
            isStreaming: noteChatState.isStreaming,
            fieldWidth: width,
            chromeTuning: .noteAskBar,
            analyzingText: "Loading \(inference.activeChatModelDisplayName)…",
            onSubmit: {
                submitToolbarAskInline()
            },
            onStop: {
                noteChatState.stopStreaming()
            }
        ) {
            HStack(spacing: 6) {
                LocalModelToolbarMenu(
                    variant: .toolbar,
                    operatingMode: noteChatOperatingModeBinding,
                    availableOperatingModes: supportedNoteChatOperatingModes
                )
                ChatCapabilityPill(
                    capability: toolbarAskCapability
                )
                Button(action: routeToolbarAskToMainChat) {
                    Label("Send to Main Chat", systemImage: "arrow.up.forward.app")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .disabled(
                    noteChatState.isStreaming
                        || noteChatState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                .help("Send this ask to main chat")
            }
        }
    }

    private var noteChatContextAttachment: ContextAttachment? {
        guard let page = pages.first else { return nil }
        return ContextAttachment(
            kind: .note,
            targetId: page.id,
            title: page.title.isEmpty ? "Untitled" : page.title
        )
    }

    private func submitToolbarAskInline() {
        let trimmed = noteChatState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        noteChatState.submitToolbarQuery(
            trimmed,
            triageService: triageService,
            operatingMode: selectedNoteChatOperatingMode
        )
    }

    private func routeToolbarAskToMainChat() {
        let trimmed = noteChatState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let bootstrap = AppBootstrap.shared else {
            submitToolbarAskInline()
            return
        }

        noteChatState.inputText = ""
        bootstrap.chatState.startNewChat()
        if let attachment = noteChatContextAttachment {
            bootstrap.chatState.addContextAttachment(attachment)
        }
        ui.setActivePanel(.home)
        MainChatSubmissionRouter.submit(
            trimmed,
            operatingMode: selectedNoteChatOperatingMode,
            chat: bootstrap.chatState,
            orchestrator: bootstrap.orchestratorState,
            inference: inference
        )
    }

    private func openMiniChatForCurrentNote() {
        MiniChatWindowController.shared.openNewChat(attaching: noteChatContextAttachment)
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
            }

            Divider()

            if !showPreview {
                Button {
                    openMiniChatForCurrentNote()
                } label: {
                    Label("Open Mini Chat", systemImage: "bubble.left.and.text.bubble.right")
                }

                ForEach(NoteWorkspaceQuickAction.allCases, id: \.self) { action in
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
            Label("More", systemImage: NoteToolbarGlyph.more.symbolName ?? "ellipsis.circle")
        }
        .menuIndicator(.hidden)
        .popover(isPresented: $showBacklinksPopover, arrowEdge: .bottom) {
            if let page = pages.first {
                NoteBacklinksPopover(
                    pageTitle: page.title,
                    pageId: page.id,
                    onNavigate: { targetId in
                        showBacklinksPopover = false
                        navState?.push(pageId: targetId, title: "")
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

private struct NotePreviewView2: NSViewRepresentable {
    let body: String
    let theme: EpistemosTheme
    private static let verticalInset: CGFloat = 54

    func makeNSView(context: Context) -> NSScrollView {
        let (scrollView, textView) = ProseTextView2.makeTextKit2()
        textView.isEditable = false
        textView.isSelectable = true
        textView.allowsUndo = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(
            width: NoteDualPreviewLayout.minimumTextHorizontalInset,
            height: Self.verticalInset
        )
        textView.applyTheme(theme)
        textView.textStorage?.setAttributedString(NSAttributedString(string: body))
        textView.reparseAndInvalidate()

        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.wantsLayer = true
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        scrollView.contentView.postsFrameChangedNotifications = true
        context.coordinator.frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak textView] _ in
            guard let textView else { return }
            MainActor.assumeIsolated {
                Self.updateCenteringInsets(for: textView)
            }
        }

        context.coordinator.textView = textView
        context.coordinator.lastTheme = theme

        DispatchQueue.main.async {
            Self.updateCenteringInsets(for: textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        if context.coordinator.lastTheme != theme {
            context.coordinator.lastTheme = theme
            textView.applyTheme(theme)
        }

        if textView.string != body {
            textView.textStorage?.setAttributedString(NSAttributedString(string: body))
            textView.reparseAndInvalidate()
        } else {
            textView.updateVisibleLineRange()
        }

        Self.updateCenteringInsets(for: textView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        nonisolated(unsafe) var textView: ProseTextView2?
        var lastTheme: EpistemosTheme?
        nonisolated(unsafe) var frameObserver: (any NSObjectProtocol)?

        deinit {
            if let frameObserver {
                NotificationCenter.default.removeObserver(frameObserver)
            }
        }
    }

    private static func updateCenteringInsets(for textView: ProseTextView2) {
        guard let scrollView = textView.enclosingScrollView else { return }
        let availableWidth = scrollView.contentSize.width
        let horizontalInset = NoteDualPreviewLayout.centeredTextInset(
            for: availableWidth,
            markdown: textView.string,
            maxReadableWidth: NoteDualPreviewLayout.previewTextReadableMaxWidth
        )
        let currentInset = textView.textContainerInset
        if abs(currentInset.width - horizontalInset) > 0.5
            || abs(currentInset.height - verticalInset) > 0.5
        {
            textView.textContainerInset = NSSize(width: horizontalInset, height: verticalInset)
        }
    }
}

private struct AdaptiveNotePreviewView2: View {
    let content: String
    let theme: EpistemosTheme
    let hasMultipleTabs: Bool
    private let pageContents: [String]
    @State private var titlebarInset: CGFloat = 0

    init(content: String, theme: EpistemosTheme, hasMultipleTabs: Bool) {
        self.content = content
        self.theme = theme
        self.hasMultipleTabs = hasMultipleTabs
        self.pageContents = NoteDualPreviewLayout.columnContents(in: content)
    }

    var body: some View {
        GeometryReader { proxy in
            let usesDualColumns = NoteDualPreviewLayout.usesDualColumns(for: proxy.size.width)
                && pageContents.count > 1
            let dualPageWidth = NoteDualPreviewLayout.dualPageWidth(for: proxy.size.width)
            let contentTopInset = NotePreviewChromeMetrics.contentTopInset(
                titlebarInset: titlebarInset,
                hasMultipleTabs: hasMultipleTabs
            )
            let outerPadding = EdgeInsets(
                top: NoteDualPreviewLayout.outerPadding.top + contentTopInset,
                leading: NoteDualPreviewLayout.outerPadding.leading,
                bottom: NoteDualPreviewLayout.outerPadding.bottom,
                trailing: NoteDualPreviewLayout.outerPadding.trailing
            )

            ScrollView {
                if usesDualColumns {
                    HStack(alignment: .top, spacing: NoteDualPreviewLayout.pageSpacing) {
                        ForEach(Array(pageContents.enumerated()), id: \.offset) { _, pageContent in
                            NoteBookPreviewPage(markdown: pageContent, theme: theme)
                                .equatable()
                                .frame(
                                    width: dualPageWidth,
                                    alignment: .topLeading
                                )
                        }
                    }
                    .padding(outerPadding)
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    NoteBookPreviewPage(markdown: content, theme: theme)
                        .equatable()
                        .frame(
                            maxWidth: NoteDualPreviewLayout.singlePageWidth(
                                for: content,
                                availableWidth: proxy.size.width
                            ),
                            alignment: .topLeading
                        )
                        .padding(outerPadding)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .background(.regularMaterial)
            .background {
                NotePreviewTitlebarInsetReader(titlebarInset: $titlebarInset)
                    .frame(width: 0, height: 0)
            }
            .overlay(alignment: .topTrailing) {
                if NotePreviewPerformancePolicy.showsOverlayBadge {
                    notePreviewBadge
                        .padding(.top, NoteDualPreviewLayout.outerPadding.top)
                        .padding(.trailing, NoteDualPreviewLayout.outerPadding.trailing)
                }
            }
        }
    }

    private var notePreviewBadge: some View {
        HStack(spacing: 8) {
            ASCIIFrameAnimationText(
                configuration: .previewScanner,
                font: .system(size: 10, weight: .semibold, design: .monospaced),
                color: theme.fontAccent.opacity(0.78)
            )
            Text("Preview")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(theme.isDark ? Color.white.opacity(0.045) : Color.black.opacity(0.03))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    theme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                    lineWidth: 0.5
                )
        )
    }
}

private struct NotePreviewTitlebarInsetReader: NSViewRepresentable {
    @Binding var titlebarInset: CGFloat

    func makeNSView(context: Context) -> NotePreviewTitlebarInsetView {
        let view = NotePreviewTitlebarInsetView()
        view.onChange = { inset in
            guard abs(titlebarInset - inset) > 0.5 else { return }
            titlebarInset = inset
        }
        return view
    }

    func updateNSView(_ nsView: NotePreviewTitlebarInsetView, context: Context) {
        nsView.onChange = { inset in
            guard abs(titlebarInset - inset) > 0.5 else { return }
            titlebarInset = inset
        }
        nsView.refreshInset()
    }
}

private final class NotePreviewTitlebarInsetView: NSView {
    var onChange: ((CGFloat) -> Void)?
    private var lastReportedInset: CGFloat = -1

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshInset()
    }

    override func layout() {
        super.layout()
        refreshInset()
    }

    func refreshInset() {
        guard let window else { return }
        let inset = NotePreviewChromeMetrics.titlebarInset(for: window)
        guard abs(lastReportedInset - inset) > 0.5 else { return }
        lastReportedInset = inset
        onChange?(inset)
    }
}

private struct NoteBookPreviewPage: View, Equatable {
    let markdown: String
    let theme: EpistemosTheme

    var body: some View {
        MarkdownTextView(
            content: markdown,
            theme: theme,
            rippleStyle: .none
        )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(NoteDualPreviewLayout.pagePadding)
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
