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
        case let tv as ClickableTextView where matches(tv, pageId: pageId):
            return tv
        case let tv as ProseTextView2 where matches(tv, pageId: pageId):
            return tv
        default:
            return nil
        }
    }

    private static func matches(_ textView: NSTextView, pageId: String?) -> Bool {
        guard textView.isEditable else { return false }
        guard let pageId else { return true }
        switch textView {
        case let tv as ClickableTextView:
            return tv.pageId == pageId
        case let tv as ProseTextView2:
            return tv.pageId == pageId
        default:
            return false
        }
    }
}

enum NoteEditorNotifications {
    static let replaceRange = Notification.Name("EpistemosReplaceRange")
}

enum NoteToolbarMetrics {
    static let iconSide: CGFloat = 14
    static let buttonSide: CGFloat = 28
    static let spacing: CGFloat = 6
    static let chatFieldWidth: CGFloat = 180
    static let compactChatFieldWidth: CGFloat = 132
    static let containerHorizontalPadding: CGFloat = 8
    static let containerVerticalPadding: CGFloat = 3
    static let previewExpandedWidthBonus: CGFloat = 26
}

private enum NoteToolbarDensity {
    case full
    case compact
    case iconOnly
}

enum NoteToolbarPalette {
    static func iconOpacity(for theme: EpistemosTheme, isActive: Bool) -> Double {
        if isActive {
            return theme.isDark ? 0.94 : 0.88
        }
        return theme.isDark ? 0.78 : 0.66
    }
}

enum NotePreviewRenderer: Equatable {
    case textKit1
    case textKit2

    static func resolved(useTK2Editor: Bool) -> Self {
        useTK2Editor ? .textKit2 : .textKit1
    }
}

enum NotePreviewDisplay {
    static func renderedMarkdown(_ markdown: String, renderer: NotePreviewRenderer) -> String {
        guard renderer == .textKit1 else { return markdown }

        return markdown
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(transformHeadingLine)
            .joined(separator: "\n")
    }

    private static func transformHeadingLine<S: StringProtocol>(_ line: S) -> String {
        let rawLine = String(line)
        let leadingSpaces = rawLine.prefix(while: \.isWhitespace)
        let trimmed = String(rawLine.dropFirst(leadingSpaces.count))

        if trimmed.hasPrefix("### ") && !trimmed.hasPrefix("#### ") {
            return "\(leadingSpaces)### \(MarkdownHeadingDisplay.displayText(String(trimmed.dropFirst(4)), level: 3))"
        }
        if trimmed.hasPrefix("## ") && !trimmed.hasPrefix("### ") {
            return "\(leadingSpaces)## \(MarkdownHeadingDisplay.displayText(String(trimmed.dropFirst(3)), level: 2))"
        }
        if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
            return "\(leadingSpaces)# \(MarkdownHeadingDisplay.displayText(String(trimmed.dropFirst(2)), level: 1))"
        }

        return rawLine
    }
}

enum NoteDualPreviewLayout {
    static let minimumWidth: CGFloat = 1180
    static let pageSpacing: CGFloat = 28
    static let pageMaxWidth: CGFloat = 580
    static let defaultSinglePageMaxWidth: CGFloat = 920
    static let tableSinglePageMaxWidth: CGFloat = 840
    static let tableReadableMaxWidth: CGFloat = 740
    static let tableEditorReadableMaxWidth: CGFloat = 520
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
        defaultWidth
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
    case writingTools
    case more
    case backlinks
    case history

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
        }
    }

    var activeSymbolName: String? {
        switch self {
        case .history:
            "bubble.left.fill"
        default:
            symbolName
        }
    }
}

private struct NoteToolbarIcon: View {
    let glyph: NoteToolbarGlyph
    let theme: EpistemosTheme
    var isActive: Bool = false

    private var color: Color {
        theme.foreground.opacity(NoteToolbarPalette.iconOpacity(for: theme, isActive: isActive))
    }

    var body: some View {
        Group {
            if let symbolName = isActive ? glyph.activeSymbolName : glyph.symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .medium))
            } else {
                EmptyView()
            }
        }
        .foregroundStyle(color)
        .frame(width: NoteToolbarMetrics.buttonSide, height: NativeControlSystem.toolbar.height)
        .accessibilityHidden(true)
    }
}

private struct NoteToolbarButtonStyle: ButtonStyle {
    let theme: EpistemosTheme
    let isActive: Bool
    let morphID: String?

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let showsSurface = isActive || configuration.isPressed

        configuration.label
            .background {
                if showsSurface {
                    RoundedRectangle(
                        cornerRadius: NativeControlSystem.toolbar.cornerRadius,
                        style: .continuous
                    )
                    .fill(
                        theme.foreground.opacity(
                            configuration.isPressed
                                ? (theme.isDark ? 0.10 : 0.065)
                                : (theme.isDark ? 0.08 : 0.05)
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: NativeControlSystem.toolbar.cornerRadius,
                            style: .continuous
                        )
                        .strokeBorder(
                            theme.foreground.opacity(theme.isDark ? 0.11 : 0.075),
                            lineWidth: 0.55
                        )
                    }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.988 : 1.0)
            .toolbarMorphInteractionSync(
                id: morphID,
                isHovered: isHovered,
                isPressed: configuration.isPressed
            )
            .onHover { isHovered = $0 }
    }
}

private struct NoteToolbarControlCluster<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: NoteToolbarMetrics.spacing) {
            content
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
    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(ResearchState.self) private var researchState
    @Environment(EventBus.self) private var eventBus
    @Environment(TriageService.self) private var triageService
    @Environment(LLMService.self) private var llmService
    @Environment(InferenceState.self) private var inference
    @Environment(\.modelContext) private var modelContext
    @Query private var pages: [SDPage]
    @State private var showDiffSheet = false
    @State private var showInfoPopover = false
    @State private var showPreview = false
    @State private var modeBodySnapshot: NoteModeBodySnapshot?

    @State private var isScanningCitations = false
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
    init(pageId: String) {
        self.pageId = pageId
        _pages = Query(filter: #Predicate<SDPage> { $0.id == pageId })
        _noteChatState = State(initialValue: NoteChatState(pageId: pageId))
    }

    var body: some View {
        VStack(spacing: 0) {
            noteCanvas
        }
        .toolbar {
            if let nav = navState, nav.hasBreadcrumb {
                ToolbarItem(placement: .navigation) {
                    wikilinksNavButtons(nav: nav)
                }
            }
            ToolbarItem(placement: .principal) {
                noteToolbarStrip
            }
        }
        .preferredColorScheme(ui.theme.colorScheme)
        .background {
            // Hidden keyboard shortcut buttons
            Button("") {
                Task {
                    if let pageId = await vaultSync.createPage(title: "Untitled") {
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
                    page.isPinned.toggle()
                    do { try modelContext.save() } catch {
                        Log.notes.error(
                            "Save failed (pin shortcut): \(error.localizedDescription, privacy: .private)"
                        )
                    }
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
                noteInfoPanel(page: page)
            }
        }
        .popover(isPresented: $showIdeasPopover) {
            if let page = pages.first {
                IdeasPanel(
                    page: page,
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
                    pageId: page.id, currentTitle: page.title, currentBody: page.loadBody())
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
        .onChange(of: ui.theme) { _, newTheme in
            if let window = NSApp.keyWindow {
                window.appearance = NSAppearance(named: newTheme.isDark ? .darkAqua : .aqua)
                window.backgroundColor = newTheme.nsBackground
            }
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
            NotificationCenter.default.publisher(for: ClickableTextView.createIdeaNotification)
        ) { notif in
            guard (notif.userInfo as? [String: String])?["pageId"] == pageId else { return }
            snapshotEditorSelection()
            contextMenuIdeaTab = .ideas
            showIdeasPopover = true
        }
        .onReceive(
            NotificationCenter.default.publisher(for: ClickableTextView.createBrainDumpNotification)
        ) { notif in
            guard (notif.userInfo as? [String: String])?["pageId"] == pageId else { return }
            snapshotEditorSelection()
            contextMenuIdeaTab = .brainDumps
            showIdeasPopover = true
        }
        .onReceive(
            NotificationCenter.default.publisher(for: ClickableTextView.aiOperationNotification)
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
            NotificationCenter.default.publisher(for: ClickableTextView.blockPropertyNotification)
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
            NotificationCenter.default.publisher(for: ClickableTextView.translateNotification)
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
                    let previewRenderer = NotePreviewRenderer.resolved(
                        useTK2Editor: notesUI.useTK2Editor
                    )
                    VStack(spacing: 0) {
                        if showPreview {
                            notePreview(body: displayBody(for: page), renderer: previewRenderer)
                        } else {
                            ProseEditorView(
                                page: page,
                                isEditable: true,
                                initialBodyOverride: currentModeBodySnapshot(for: page.id)
                            )
                        }
                    }
                    .frame(minWidth: 400, minHeight: 300)
                } else {
                    ContentUnavailableView("Note not found", systemImage: "doc.questionmark")
                        .frame(minWidth: 400, minHeight: 300)
                }

                TransitionGreetingView(
                    message: transitionGreeting,
                    theme: ui.theme
                )
                .opacity(transitionOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(transitionOpacity > 0)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            ui.theme.background.opacity(0),
                            ui.theme.background.opacity(0.7),
                            ui.theme.background.opacity(0.95),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 44)
                    .allowsHitTesting(false)

                    ZStack {
                        HStack(spacing: 8) {
                            Text("\(wordCount) words")
                                .font(AppDisplayTypography.font(size: 13))
                                .monospacedDigit()
                                .foregroundStyle(ui.theme.foreground.opacity(0.55))
                        }

                        HStack(spacing: 3) {
                            Image(systemName: "command")
                                .font(.system(size: 10, weight: .medium))
                            Text("S")
                                .font(AppDisplayTypography.font(size: 10))
                            Text("Save to Disk")
                                .font(AppDisplayTypography.font(size: 10))
                                .padding(.leading, 2)
                            Spacer()
                            Image(systemName: "command")
                                .font(.system(size: 10, weight: .medium))
                            Text("2")
                                .font(AppDisplayTypography.font(size: 10))
                            Text("Note Sidebar")
                                .font(AppDisplayTypography.font(size: 10))
                                .padding(.leading, 2)
                        }
                        .foregroundStyle(ui.theme.foreground.opacity(0.35))
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                    .background(ui.theme.background.opacity(0.95))
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .trailing) {
                NoteOutlineOverlay(
                    markdown: notesUI.useTK2Editor
                        ? ""
                        : (PageStoragePool.shared.bodyText(for: pageId)
                            ?? pages.first?.loadBody() ?? ""),
                    theme: ui.theme,
                    onNavigate: { charOffset in
                        scrollEditorTo(charOffset: charOffset)
                    },
                    externalItems: notesUI.useTK2Editor ? tocItems : nil
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ui.theme.background)
            .environment(noteChatState)
            .onAppear {
                noteChatState.loadPersistedMessages(modelContext)
                refreshTabCount()
                if let page = pages.first {
                    scheduleMetricsRefresh(
                        body: page.loadBody(),
                        includeMarkdownHeadings: true
                    )
                } else {
                    queueMissingPageRecovery()
                }
            }
            .onDisappear {
                wordCountDebounce?.cancel()
                metricsTask?.cancel()
                missingPageRecoveryTask?.cancel()
                missingPageRecoveryTask = nil
                noteChatState.clear()
            }
            .onChange(of: pages.isEmpty) { _, isEmpty in
                if isEmpty {
                    queueMissingPageRecovery()
                } else {
                    missingPageRecoveryTask?.cancel()
                    missingPageRecoveryTask = nil
                }
            }
            .onChange(of: noteChatState.isStreaming) { wasStreaming, isNowStreaming in
                if wasStreaming && !isNowStreaming, let page = pages.first {
                    noteChatState.persistMessages(modelContext, noteTitle: page.title)
                }
            }
        }
    }

    private var noteToolbarStrip: some View {
        ViewThatFits(in: .horizontal) {
            noteToolbarStripLayout(
                chatFieldWidth: showPreview ? nil : NoteToolbarMetrics.chatFieldWidth,
                density: .full
            )
            noteToolbarStripLayout(
                chatFieldWidth: showPreview ? nil : NoteToolbarMetrics.compactChatFieldWidth,
                density: .compact
            )
            noteToolbarStripLayout(chatFieldWidth: nil, density: .iconOnly)
        }
    }

    private func noteToolbarStripLayout(
        chatFieldWidth: CGFloat?,
        density: NoteToolbarDensity
    ) -> some View {
        ToolbarMorphHost(style: .notePreviewStrip, baseSurface: .strip) {
            HStack(spacing: NoteToolbarMetrics.spacing) {
                if let chatFieldWidth {
                    toolbarChatField(width: chatFieldWidth)
                }

                noteToolbarControls(density: density)
            }
            .padding(.horizontal, NoteToolbarMetrics.containerHorizontalPadding)
            .padding(.vertical, NoteToolbarMetrics.containerVerticalPadding)
        }
    }

    @ViewBuilder
    private func noteToolbarControls(density: NoteToolbarDensity) -> some View {
        NoteToolbarControlCluster {
            if !showPreview && density == .full {
                formatToolbarMenu
            }

                if density == .iconOnly {
                    toolbarIconButton(
                        glyph: showPreview ? .edit : .preview,
                        isActive: showPreview,
                        help: showPreview ? "Editor (⌘E)" : "Preview (⌘E)",
                        morphID: NoteToolbarMorphID.preview.rawValue
                    ) {
                    togglePreviewMode()
                }
            } else {
                    ExpandingModeButton(
                        title: "Preview",
                        systemImage: showPreview ? "pencil" : "eye",
                        isActive: showPreview,
                        activeTitle: "Editor",
                        variant: .toolbar,
                        helpText: showPreview ? "Editor (⌘E)" : "Preview (⌘E)",
                        asciiAnimation: .compactToolbarStatus,
                        asciiFont: .system(size: 10, weight: .medium, design: .monospaced),
                        stableWidth: NativeControlSystem.reservedWidth(
                            for: ["Preview", "Editor"],
                            variant: .toolbar
                        ) + NoteToolbarMetrics.previewExpandedWidthBonus,
                        morphID: NoteToolbarMorphID.preview.rawValue
                    ) {
                        togglePreviewMode()
                    }
                }

                moreMenu

                if !showPreview {
                    if density == .full {
                        appleWritingToolsButton
                    }

                    backlinksToolbarControl()

                    noteChatToolbarControl()
                }
            }
    }

    private func backlinksToolbarControl() -> some View {
        toolbarIconButton(
            glyph: .backlinks,
            isActive: showBacklinksPopover,
            help: "Backlinks",
            morphID: NoteToolbarMorphID.backlinks.rawValue
        ) {
            showBacklinksPopover.toggle()
        }
        .popover(isPresented: $showBacklinksPopover, arrowEdge: .bottom) {
            backlinksPopoverContent
        }
    }

    private func noteChatToolbarControl() -> some View {
        toolbarIconButton(
            glyph: .history,
            isActive: showChatSidebar,
            help: "Chat History",
            morphID: NoteToolbarMorphID.history.rawValue
        ) {
            showChatSidebar.toggle()
        }
        .popover(isPresented: $showChatSidebar, arrowEdge: .bottom) {
            noteChatPopoverContent
        }
    }

    @ViewBuilder
    private var backlinksPopoverContent: some View {
        if let page = pages.first {
            NoteBacklinksPopover(
                pageTitle: page.title,
                onNavigate: { targetId in
                    showBacklinksPopover = false
                    navState?.push(pageId: targetId, title: "")
                }
            )
        }
    }

    private var noteChatPopoverContent: some View {
        NoteChatSidebar()
            .environment(noteChatState)
            .frame(width: 320, height: 380)
    }

    private var formatToolbarMenu: some View {
        Menu {
            formatMenuContent
        } label: {
            NoteToolbarIcon(glyph: .format, theme: ui.theme)
        }
        .menuStyle(.borderlessButton)
        .help("Format")
    }

    private func toolbarIconButton(
        glyph: NoteToolbarGlyph,
        isActive: Bool = false,
        help: String,
        morphID: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            NoteToolbarIcon(glyph: glyph, theme: ui.theme, isActive: isActive)
        }
        .buttonStyle(
            NoteToolbarButtonStyle(
                theme: ui.theme,
                isActive: isActive,
                morphID: morphID
            )
        )
        .toolbarMorphItem(id: morphID, isActive: isActive)
        .help(help)
        .accessibilityLabel(help)
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
        guard let allPages = try? modelContext.fetch(descriptor) else { return nil }
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

        let mapping: (operation: NotesOperation, systemPrompt: String, userPrompt: String) = {
            switch op {
            case "rewrite":
                return (
                    .rewrite,
                    "You are a writing assistant. Rewrite the selected text to improve clarity and flow. Output ONLY the rewritten text.",
                    "Rewrite this:\n\n\(text)\(instructionSuffix)"
                )
            case "proofread":
                return (
                    .rewrite,
                    "You are a proofreading assistant. Fix grammar, spelling, and punctuation errors. Preserve the original meaning and tone. Output ONLY the corrected text.",
                    "Proofread and correct this:\n\n\(text)\(instructionSuffix)"
                )
            case "rewrite_friendly":
                return (
                    .rewrite,
                    "You are a writing assistant. Rewrite the text in a warm, friendly, conversational tone. Output ONLY the rewritten text.",
                    "Rewrite in a friendly tone:\n\n\(text)\(instructionSuffix)"
                )
            case "rewrite_professional":
                return (
                    .rewrite,
                    "You are a writing assistant. Rewrite the text in a polished, professional tone. Output ONLY the rewritten text.",
                    "Rewrite in a professional tone:\n\n\(text)\(instructionSuffix)"
                )
            case "rewrite_concise":
                return (
                    .rewrite,
                    "You are a writing assistant. Rewrite the text to be as concise as possible while preserving the key meaning. Output ONLY the rewritten text.",
                    "Rewrite concisely:\n\n\(text)\(instructionSuffix)"
                )
            case "summarize":
                return (
                    .summarize,
                    "You are a summarization assistant. Summarize the selected text concisely. Output ONLY the summary.",
                    "Summarize this:\n\n\(text)\(instructionSuffix)"
                )
            case "keyPoints":
                return (
                    .summarize,
                    "You are an analysis assistant. Extract the key points from the text as a concise markdown bullet list. Output ONLY the bullet list.",
                    "Extract key points:\n\n\(text)\(instructionSuffix)"
                )
            case "expand":
                return (
                    .expand,
                    "You are a writing assistant. Expand the selected text with more detail and depth. Maintain the same tone.",
                    "Expand on this:\n\n\(text)\(instructionSuffix)"
                )
            case "simplify":
                return (
                    .rewrite,
                    "You are a writing assistant. Simplify the text to be easier to understand. Use shorter sentences. Output ONLY the simplified text.",
                    "Simplify this:\n\n\(text)\(instructionSuffix)"
                )
            case "toList":
                return (
                    .outline,
                    "You are a formatting assistant. Convert the text into a clean markdown bullet list. Output ONLY the list.",
                    "Convert to a bullet list:\n\n\(text)\(instructionSuffix)"
                )
            case "toTable":
                return (
                    .outline,
                    "You are a formatting assistant. Convert the text into a markdown table. Output ONLY the table.",
                    "Convert to a markdown table:\n\n\(text)\(instructionSuffix)"
                )
            case "continue":
                return (
                    .continueWriting,
                    "You are a writing assistant. Continue writing from where the note left off. Match the tone and style. Output ONLY the continuation.",
                    "Continue writing from where this note ends.\(instructionSuffix)"
                )
            case "outline":
                return (
                    .outline,
                    "You are a structural analysis assistant. Generate a structured outline using markdown headers and bullet points. Output ONLY the outline.",
                    "Generate a structured outline for this note.\(instructionSuffix)"
                )
            case "structure":
                return (
                    .analyze,
                    "You are a note organization assistant. Suggest a better structure for this note. Output a reorganized version.",
                    "Suggest a better structure for this note.\(instructionSuffix)"
                )
            case "restructure":
                return (
                    .analyze,
                    "You are a note restructuring assistant. Completely reorganize the entire note for better clarity, flow, and logical progression. Preserve ALL content. Use proper markdown formatting. Output the COMPLETE restructured note.",
                    "Restructure this entire note for better organization and flow.\(instructionSuffix)"
                )
            default:
                return (
                    .ask(query: text.isEmpty ? "Help me with this note." : text),
                    "You are a helpful note assistant. Answer concisely based on the note content.",
                    text.isEmpty
                        ? "Help me with this note.\(instructionSuffix)"
                        : "\(text)\(instructionSuffix)"
                )
            }
        }()

        noteChatState.submitQuery(
            mapping.userPrompt,
            operation: mapping.operation,
            systemPrompt: mapping.systemPrompt,
            triageService: triageService
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

    // MARK: - Editor Flush & Pool Reset (Mode Switching)
    // Flushes unsaved text from the current editor to page.body before switching modes,
    // preventing stale data in the new editor.
    // Also invalidates the PageStoragePool entry so the regular editor gets a fresh
    // MarkdownTextStorage with correct formatting when switching back from Preview.

    private func invalidateEditorCache() {
        guard !notesUI.useTK2Editor else { return }
        PageStoragePool.shared.saveToDisk(pageId: pageId)
        PageStoragePool.shared.remove(pageId: pageId)
    }

    private func displayBody(for page: SDPage) -> String {
        currentModeBodySnapshot(for: page.id) ?? currentEditorBody(for: page) ?? page.loadBody()
    }

    private func currentModeBodySnapshot(for pageId: String) -> String? {
        modeBodySnapshot?.body(ifMatches: pageId)
    }

    private func currentEditorBody(for page: SDPage) -> String? {
        if !notesUI.useTK2Editor, let poolText = PageStoragePool.shared.bodyText(for: pageId) {
            return poolText
        }
        if let responder = NoteEditorViewFinder.findEditorTextView(for: pageId) {
            return responder.string
        }
        return showPreview ? currentModeBodySnapshot(for: page.id) ?? page.loadBody() : nil
    }

    private func flushCurrentEditor() {
        guard let page = pages.first else { return }
        let fullText = currentEditorBody(for: page) ?? page.loadBody()
        modeBodySnapshot = NoteModeBodySnapshot(pageId: page.id, body: fullText)
        if fullText != page.loadBody() {
            page.saveBody(fullText)
            BlockMirror.sync(pageId: page.id, body: fullText, modelContext: modelContext)
            page.needsVaultSync = true
            page.updatedAt = .now
            try? modelContext.save()
            AppBootstrap.shared?.graphState.needsRefresh = true
        }
    }

    // MARK: - Mode Transition Helpers
    // Shows a solid label card that fully covers the view swap glitch.
    // Timing: appear instantly → mode swaps behind it → fade out after settling.

    private func togglePreviewMode() {
        guard !isTransitioning else { return }
        flushCurrentEditor()
        let destinationLabel = showPreview ? "Editor" : "Preview"
        performGreetingTransition(message: destinationLabel) {
            invalidateEditorCache()
            showPreview.toggle()
        }
    }

    @ViewBuilder
    private func notePreview(body: String, renderer: NotePreviewRenderer) -> some View {
        AdaptiveNotePreviewView2(
            content: NotePreviewDisplay.renderedMarkdown(body, renderer: renderer),
            theme: ui.theme
        )
    }

    private func navigateToWikilink(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let exactDesc = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.title == trimmed }
        )
        let lowered = trimmed.lowercased()
        let existing: SDPage? =
            (try? modelContext.fetch(exactDesc))?.first
            ?? {
                let allDesc = FetchDescriptor<SDPage>()
                guard let pages = try? modelContext.fetch(allDesc) else { return nil }
                return pages.first(where: { $0.title.lowercased() == lowered })
            }()

        if let existing {
            if let navState {
                navState.push(pageId: existing.id, title: existing.title)
            } else {
                NoteWindowManager.shared.open(pageId: existing.id)
            }
        } else {
            Task {
                if let newId = await vaultSync.createPage(title: trimmed) {
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

        // Scale hold time for larger documents — more text = more layout work.
        let bodyLength = pages.first?.loadBody().count ?? 0
        let holdTime: Double = bodyLength > 20_000 ? 1.4 : bodyLength > 5_000 ? 1.0 : 0.70

        // Instantly opaque — no animation, no insertion delay.
        // The overlay is already in the view tree, just invisible.
        transitionOpacity = 1

        // Swap mode after one frame (overlay is guaranteed visible).
        // Cache invalidation happens inside modeSwap so the old editor
        // isn't pulled out from under itself before SwiftUI tears it down.
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

    // MARK: - Toolbar Response Dropdown

    private var toolbarResponseDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ui.theme.accent)
                Text("Response")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if noteChatState.isStreaming {
                    ProgressView().controlSize(.mini)
                } else {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(noteChatState.responseText, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ui.theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            Divider().opacity(0.3)

            ScrollView {
                if noteChatState.responseText.isEmpty && noteChatState.isStreaming {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Thinking\u{2026}")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                } else {
                    Text(
                        noteChatState.responseText
                            + (noteChatState.isStreaming ? " \u{258D}" : "")
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
            }
            .frame(height: 260)

            Divider().opacity(0.3)

            // Follow-up + actions
            HStack(spacing: 8) {
                @Bindable var chat = noteChatState
                TextField("Follow up\u{2026}", text: $chat.inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        noteChatState.submitQuery(
                            noteChatState.inputText,
                            triageService: triageService,
                            llmService: llmService
                        )
                    }
                    .disabled(noteChatState.isStreaming)

                if noteChatState.isStreaming {
                    Button {
                        noteChatState.stopStreaming()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(ui.theme.error)
                    }
                    .buttonStyle(.plain)
                } else if !noteChatState.responseText.isEmpty {
                    Button {
                        noteChatState.acceptResponse()
                    } label: {
                        Label("Insert", systemImage: "text.insert")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(ui.theme.accent)

                    Button {
                        noteChatState.discardResponse()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ui.theme.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 420)
    }

    private var appleWritingToolsButton: some View {
        toolbarIconButton(
            glyph: .writingTools,
            help: "Apple Writing Tools",
            morphID: NoteToolbarMorphID.writingTools.rawValue
        ) {
            showAppleWritingTools()
        }
    }

    private func showAppleWritingTools() {
        NotificationCenter.default.post(
            name: WritingToolsBridge.showNotification,
            object: nil,
            userInfo: ["pageId": pageId]
        )
    }

    // MARK: - Toolbar Chat Field

    private func toolbarChatField(width: CGFloat) -> some View {
        HStack(spacing: 6) {
            @Bindable var chat = noteChatState
            Menu {
                Button {
                    noteChatState.chatMode = .auto
                    noteChatState.overrideProvider = nil
                } label: {
                    Label("Auto (Apple AI + Cloud)", systemImage: "apple.intelligence")
                }

                Button {
                    noteChatState.chatMode = .cloudOnly
                } label: {
                    Label(
                        "Cloud (\(inference.apiProvider.displayName))",
                        systemImage: inference.apiProvider.iconName
                    )
                }

                Divider()

                Menu("Manual Provider") {
                    ForEach(
                        [LLMProviderType.anthropic, .openai, .google, .kimi, .ollama], id: \.self
                    ) { provider in
                        Button {
                            noteChatState.chatMode = .provider
                            noteChatState.overrideProvider = provider
                        } label: {
                            Label(provider.displayName, systemImage: provider.iconName)
                        }
                    }
                }
            } label: {
                Image(systemName: noteChatRoutingIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(ui.theme.mutedForeground)
            }
            .menuStyle(.borderlessButton)
            .help(noteChatRoutingLabel)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(ui.theme.mutedForeground)
            TextField("Ask", text: $chat.inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .frame(width: width)
                .onSubmit {
                    noteChatState.submitQuery(
                        noteChatState.inputText,
                        triageService: triageService,
                        llmService: llmService
                    )
                }

            if noteChatState.isStreaming {
                Button {
                    noteChatState.stopStreaming()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(ui.theme.error)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .popover(
            isPresented: Binding(
                get: { noteChatState.hasResponse && noteChatState.useResponsePanel },
                set: { if !$0 { noteChatState.discardResponse() } }
            ),
            arrowEdge: .bottom
        ) {
            toolbarResponseDropdown
        }
    }

    // MARK: - More Menu

    private var moreMenu: some View {
        Menu {
            if !showPreview {
                Menu("Format") {
                    formatMenuContent
                }

                Button {
                    showAppleWritingTools()
                } label: {
                    Label("Apple Writing Tools", systemImage: NoteToolbarGlyph.writingTools.symbolName ?? "apple.intelligence")
                }

                Divider()
            }

            // Note actions
            if let page = pages.first {
                Button {
                    page.isPinned.toggle()
                    do { try modelContext.save() } catch {
                        Log.notes.error(
                            "Save failed (pin toggle): \(error.localizedDescription, privacy: .private)"
                        )
                    }
                } label: {
                    Label(
                        page.isPinned ? "Unpin" : "Pin",
                        systemImage: page.isPinned ? "pin.fill" : "pin")
                }
                Button {
                    page.isFavorite.toggle()
                    do { try modelContext.save() } catch {
                        Log.notes.error(
                            "Save failed (favorite toggle): \(error.localizedDescription, privacy: .private)"
                        )
                    }
                } label: {
                    Label(
                        page.isFavorite ? "Unfavorite" : "Favorite",
                        systemImage: page.isFavorite ? "star.fill" : "star")
                }
            }

            Divider()

            Button {
                togglePreviewMode()
            } label: {
                Label(
                    showPreview ? "Editor (\u{2318}E)" : "Preview (\u{2318}E)",
                    systemImage: showPreview ? "pencil" : "eye")
            }

            Button {
                withAnimation { showChatSidebar.toggle() }
            } label: {
                Label(
                    showChatSidebar ? "Hide Chat" : "Chat History",
                    systemImage: showChatSidebar ? "bubble.left.fill" : "bubble.left")
            }

            Divider()

            Button {
                vaultSync.savePage(pageId: pageId)
            } label: {
                Label("Save (\u{2318}S)", systemImage: "square.and.arrow.down")
            }

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
                scanForCitations()
            } label: {
                Label(
                    isScanningCitations ? "Scanning\u{2026}" : "Scan Sources",
                    systemImage: "text.magnifyingglass")
            }
            .disabled(isScanningCitations || pages.first == nil)

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

            Button {
                UtilityWindowManager.shared.show(.notes)
            } label: {
                Label("Notes Sidebar", systemImage: "sidebar.leading")
            }

            Divider()

            Button {
                notesUI.useTK2Editor.toggle()
            } label: {
                Label(
                    notesUI.useTK2Editor ? "Switch to Classic Editor" : "Long-Form Editor (Beta)",
                    systemImage: notesUI.useTK2Editor ? "1.square" : "2.square"
                )
            }
            .help(
                notesUI.useTK2Editor
                    ? "Switch back to the classic editor"
                    : "Optimised for long documents — smoother scrolling and rendering for 5,000+ word notes"
            )
        } label: {
            NoteToolbarIcon(glyph: .more, theme: ui.theme)
        }
        .menuStyle(.borderlessButton)
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

    private var noteChatRoutingIcon: String {
        switch noteChatState.chatMode {
        case .auto: "apple.intelligence"
        case .cloudOnly: inference.apiProvider.iconName
        case .provider: (noteChatState.overrideProvider ?? .openai).iconName
        }
    }

    private var noteChatRoutingLabel: String {
        switch noteChatState.chatMode {
        case .auto: "Auto routing"
        case .cloudOnly: "Cloud routing"
        case .provider: (noteChatState.overrideProvider ?? .openai).displayName
        }
    }

    // MARK: - Info Panel

    private func noteInfoPanel(page: SDPage) -> some View {
        let currentBody = page.loadBody()
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
        let text = "# \(page.title)\n\n\(page.loadBody())" as NSString
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

    // MARK: - Citation Scanning

    /// Scan the current note for sources, citations, and academic references,
    /// then add any found to the research library.
    private func scanForCitations() {
        guard let page = pages.first else { return }
        isScanningCitations = true

        let fullText = "# \(page.title)\n\n\(page.loadBody())"
        let papers = CitationExtractor.extract(
            from: fullText, source: "note-scan",
            originNoteTitle: page.title)

        if papers.isEmpty {
            eventBus.emitToast("No sources found in this note", type: .info)
        } else {
            for paper in papers {
                researchState.addSavedPaper(paper)
            }
            eventBus.emitToast(
                "Added \(papers.count) source\(papers.count == 1 ? "" : "s") to library",
                type: .success)
        }

        isScanningCitations = false
    }
}

// MARK: - Ideas & Brain Dumps Panel
// Popover for registering ideas and brain dumps anchored to specific lines in a note.
// Each idea captures the cursor line when created. Clicking navigates to that line.
// "Insert" pastes the idea at the anchor. "Integrate" uses Apple Intelligence to weave it in.

private struct IdeasPanel: View {
    let page: SDPage
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
        page.ideas = ideas
        page.updatedAt = .now
        do { try modelContext.save() } catch {
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
                .foregroundStyle(theme.accent.opacity(0.8))
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
                    let body = page.loadBody()
                    LazyVStack(spacing: 6) {
                        ForEach(filteredItems) { item in
                            IdeaRow(
                                item: item,
                                isBusy: busyItemId == item.id,
                                theme: theme,
                                pageBody: body,
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
                .foregroundStyle(showNewForm ? theme.mutedForeground : theme.accent)
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
                .foregroundStyle(theme.accent.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.accent.opacity(0.08), in: Capsule())
            }

            TextField(activeTab == .ideas ? "Idea title" : "Brain dump title", text: $newTitle)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .padding(8)
                .background(theme.glassBg, in: RoundedRectangle(cornerRadius: 8))

            TextEditor(text: $newBody)
                .font(.system(size: 11))
                .foregroundStyle(theme.foreground)
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

        let fullBody = page.loadBody()
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
                    You are rewriting a section of a note titled "\(noteTitle)".

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
                    systemPrompt:
                        "You are a writing assistant that rewrites text sections. You deeply merge new ideas into existing prose. You never append or list ideas separately — you weave them into the fabric of the existing text. Return only the rewritten text, nothing else."
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
                    systemPrompt:
                        "You clean up raw brain dumps into coherent, readable text. Preserve the author's voice and ideas."
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
                        .foregroundStyle(theme.foreground)
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
                    .foregroundStyle(theme.accent.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.accent.opacity(0.08), in: Capsule())
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
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.accent.opacity(0.1), in: Capsule())
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
                        .foregroundStyle(theme.accent.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(theme.accent.opacity(0.1), in: Capsule())
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

// MARK: - Note Preview View
// Read-only rendered markdown preview using MarkdownTextStorage.
// Reuses the same styling as the editor for visual consistency.

private struct NotePreviewView: NSViewRepresentable {
    let body: String
    let theme: EpistemosTheme

    private static let maxReadableWidth: CGFloat = 720
    private static let minHorizontalInset: CGFloat = 60
    private static let verticalInset: CGFloat = 54

    func makeNSView(context: Context) -> NSScrollView {
        let storage = MarkdownTextStorage()
        storage.isDark = theme.isDark
        storage.theme = theme

        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        layoutManager.backgroundLayoutEnabled = true
        storage.addLayoutManager(layoutManager)

        let container = NSTextContainer(
            size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let tv = NSTextView(frame: .zero, textContainer: container)
        tv.wantsLayer = true
        tv.isEditable = false
        tv.isSelectable = true
        tv.isRichText = false
        tv.usesFontPanel = false
        tv.usesRuler = false
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.textColor = NSColor(theme.foreground)
        tv.textContainerInset = NSSize(width: Self.minHorizontalInset, height: Self.verticalInset)
        tv.textContainer?.lineFragmentPadding = 0
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Set content
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.replaceCharacters(in: fullRange, with: body)

        let scrollView = NSScrollView()
        scrollView.documentView = tv
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.wantsLayer = true
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        // Centering observer
        scrollView.contentView.postsFrameChangedNotifications = true
        context.coordinator.frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak tv] _ in
            guard let tv else { return }
            MainActor.assumeIsolated {
                Self.updateCenteringInsets(for: tv)
            }
        }
        context.coordinator.storage = storage
        context.coordinator.lastTheme = theme

        DispatchQueue.main.async {
            Self.updateCenteringInsets(for: tv)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let storage = context.coordinator.storage else { return }

        var needsRestyle = false
        if context.coordinator.lastTheme != theme {
            context.coordinator.lastTheme = theme
            storage.isDark = theme.isDark
            storage.theme = theme
            if let tv = scrollView.documentView as? NSTextView {
                tv.textColor = NSColor(theme.foreground)
            }
            needsRestyle = true
        }

        // Update content if changed
        if storage.string != body {
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.replaceCharacters(in: fullRange, with: body)
        } else if needsRestyle {
            storage.reapplyAllStyles()
        }

        // Update centering
        if let tv = scrollView.documentView as? NSTextView {
            Self.updateCenteringInsets(for: tv)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var storage: MarkdownTextStorage?
        var lastTheme: EpistemosTheme?
        nonisolated(unsafe) var frameObserver: (any NSObjectProtocol)?

        deinit {
            if let observer = frameObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    private static func updateCenteringInsets(for tv: NSTextView) {
        guard let scrollView = tv.enclosingScrollView else { return }
        let availableWidth = scrollView.contentSize.width
        let horizontalInset = max(minHorizontalInset, (availableWidth - maxReadableWidth) / 2)
        let currentInset = tv.textContainerInset
        if abs(currentInset.width - horizontalInset) > 0.5
            || abs(currentInset.height - verticalInset) > 0.5
        {
            tv.textContainerInset = NSSize(width: horizontalInset, height: verticalInset)
        }
    }
}

private struct NotePreviewView2: NSViewRepresentable {
    let body: String
    let theme: EpistemosTheme

    private static let maxReadableWidth: CGFloat = 720
    private static let minHorizontalInset: CGFloat = 60
    private static let verticalInset: CGFloat = 54

    func makeNSView(context: Context) -> NSScrollView {
        let (scrollView, textView) = ProseTextView2.makeTextKit2()
        textView.isEditable = false
        textView.isSelectable = true
        textView.allowsUndo = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: Self.minHorizontalInset, height: Self.verticalInset)
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
        let horizontalInset = max(minHorizontalInset, (availableWidth - maxReadableWidth) / 2)
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

    private var pageContents: [String] {
        NoteDualPreviewLayout.columnContents(in: content)
    }

    var body: some View {
        GeometryReader { proxy in
            let usesDualColumns = NoteDualPreviewLayout.usesDualColumns(for: proxy.size.width)
                && pageContents.count > 1
            let dualPageWidth = NoteDualPreviewLayout.dualPageWidth(for: proxy.size.width)

            ScrollView {
                if usesDualColumns {
                    HStack(alignment: .top, spacing: NoteDualPreviewLayout.pageSpacing) {
                        ForEach(Array(pageContents.enumerated()), id: \.offset) { _, pageContent in
                            NoteBookPreviewPage(markdown: pageContent, theme: theme)
                                .frame(
                                    width: dualPageWidth,
                                    alignment: .topLeading
                                )
                        }
                    }
                    .padding(NoteDualPreviewLayout.outerPadding)
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    NoteBookPreviewPage(markdown: content, theme: theme)
                        .frame(
                            maxWidth: NoteDualPreviewLayout.singlePageWidth(
                                for: content,
                                availableWidth: proxy.size.width
                            ),
                            alignment: .topLeading
                        )
                        .padding(NoteDualPreviewLayout.outerPadding)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .background(theme.background)
        }
    }
}

private struct NoteBookPreviewPage: View {
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
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(theme.isDark ? Color.white.opacity(0.035) : Color.black.opacity(0.018))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(
                        theme.isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.055),
                        lineWidth: 0.6
                    )
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
    @State private var rippleTrigger = 0

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            ASCIIRippleText(
                text: message,
                font: AppDisplayTypography.font(size: 44),
                color: theme.fontAccent,
                shadowColor: theme.fontAccent.opacity(theme.isDark ? 0.18 : 0.10),
                shadowRadius: 8,
                manualTrigger: rippleTrigger,
                interactive: false
            )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .task(id: message) {
            rippleTrigger += 1
        }
    }
}
