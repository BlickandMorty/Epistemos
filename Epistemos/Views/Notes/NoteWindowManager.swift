import AppIntents
import AppKit
import CoreSpotlight
import SwiftData
import SwiftUI
import Translation
import os

// MARK: - Note Window Manager
// Manages note editor windows as a native macOS tab group.
// Every note opens as a tab using NoteTabShell (navigation) + NotePageContent (editor).
// Single entry point: open(pageId:) — fetches page, highlights sidebar, opens tab.

/// A single item in the wikilink navigation breadcrumb trail.
struct BreadcrumbItem: Identifiable {
    let id: String  // pageId
    var title: String
}

// MARK: - NoteNavigationState
// Per-tab navigation state for in-place wikilink traversal.
// Owns the breadcrumb stack — first item is the root page, last is current.
// The shell view uses .id(currentPageId) to force NotePageContent recreation
// on each navigation, giving a fresh @Query and @State.

@MainActor @Observable
final class NoteNavigationState {

    /// The breadcrumb stack — first item is the root page, last is current.
    private(set) var stack: [BreadcrumbItem]

    /// Pages popped by back() — enables forward navigation (Cmd+]).
    /// Cleared on any new push() (new navigation branch).
    private(set) var forwardStack: [BreadcrumbItem] = []

    /// Fallback ID — the root page this tab was opened with.
    let rootPageId: String

    /// The page currently displayed in this tab.
    var currentPageId: String {
        stack.last?.id ?? rootPageId
    }

    /// True when there's a navigation trail worth showing (2+ items or forward history).
    var hasBreadcrumb: Bool { stack.count > 1 || !forwardStack.isEmpty }

    /// True when back navigation is possible (2+ items in stack).
    var canGoBack: Bool { stack.count > 1 }

    /// True when forward navigation is possible (items in forward stack).
    var canGoForward: Bool { !forwardStack.isEmpty }

    init(rootPageId: String, rootTitle: String) {
        self.rootPageId = rootPageId
        self.stack = [BreadcrumbItem(id: rootPageId, title: rootTitle)]
    }

    /// Push a new page onto the navigation stack (wikilink click).
    /// Clears forward history — new navigation branch.
    func push(pageId: String, title: String) {
        guard !pageId.isEmpty else { return }
        guard pageId != currentPageId else { return }
        // If already in the stack, truncate to that point instead of duplicating.
        if let existingIndex = stack.firstIndex(where: { $0.id == pageId }) {
            stack = Array(stack[...existingIndex])
        } else {
            stack.append(BreadcrumbItem(id: pageId, title: title))
        }
        forwardStack.removeAll()
    }

    /// Navigate back one level. Returns the new current page ID, or nil if already at root.
    @discardableResult
    func back() -> String? {
        guard stack.count > 1 else { return nil }
        forwardStack.append(stack.removeLast())
        return currentPageId
    }

    /// Navigate forward one level. Returns the new current page ID, or nil if no forward history.
    @discardableResult
    func forward() -> String? {
        guard let item = forwardStack.popLast() else { return nil }
        stack.append(item)
        return currentPageId
    }

    /// Navigate to a breadcrumb item — truncates the stack to that point.
    /// Items after the target are moved to forward stack.
    func navigateTo(pageId: String) {
        guard let index = stack.firstIndex(where: { $0.id == pageId }) else { return }
        let removed = stack[(index + 1)...]
        forwardStack.append(contentsOf: removed.reversed())
        stack = Array(stack[...index])
    }

    /// Update a breadcrumb title when the page is renamed.
    func syncTitle(pageId: String, title: String) {
        if let idx = stack.firstIndex(where: { $0.id == pageId }) {
            guard stack[idx].title != title else { return }
            stack[idx].title = title
        }
        if let idx = forwardStack.firstIndex(where: { $0.id == pageId }) {
            forwardStack[idx].title = title
        }
    }
}

@MainActor
final class NoteWindowManager {
    static let shared = NoteWindowManager()

    // All note windows — one per page, displayed as tabs
    private var windows: [String: NSWindow] = [:]
    private var observers: [String: any NSObjectProtocol] = [:]
    private let tabDelegate = NoteTabDelegate()
    nonisolated static let log = Logger(subsystem: "com.epistemos", category: "NoteWindow")

    /// Per-tab navigation states — tracks in-place wikilink navigation.
    /// Key = root tab pageId, Value = NoteNavigationState for that tab.
    private var navigationStates: [String: NoteNavigationState] = [:]

    private init() {}

    // MARK: - Navigation State Registration

    func registerNavState(_ state: NoteNavigationState, forTab tabPageId: String) {
        navigationStates[tabPageId] = state
    }

    func unregisterNavState(forTab tabPageId: String) {
        navigationStates.removeValue(forKey: tabPageId)
    }

    /// The page currently displayed in the tab (may differ from root if user navigated via wikilinks).
    func currentPageId(forTab tabPageId: String) -> String {
        navigationStates[tabPageId]?.currentPageId ?? tabPageId
    }

    // MARK: - Open Note (Single Entry Point)

    /// Open a note by ID — fetches the page, highlights in sidebar, opens as tab.
    /// Single entry point for sidebar / command palette note opens.
    /// Wikilink navigation uses NoteNavigationState.push() instead.
    func open(pageId: String) {
        guard let bootstrap = AppBootstrap.shared else { return }
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == pageId }
        )
        guard let page = try? bootstrap.modelContainer.mainContext.fetch(descriptor).first else {
            return
        }

        bootstrap.notesUI.openPage(pageId)
        openWindow(for: page)

        // Donate Spotlight activity async — never block note opening on indexing.
        let pageId = page.id
        let pageTitle = page.title
        let pageTags = page.tags
        Task { @MainActor [weak self] in
            self?.donateNoteActivity(pageId: pageId, title: pageTitle, tags: pageTags)
        }
    }

    /// Donates an NSUserActivity for Spotlight Suggestions.
    /// Decoupled from SDPage to avoid SwiftData faults during donation.
    private func donateNoteActivity(pageId: String, title: String, tags: [String]) {
        let activity = NSUserActivity(activityType: "com.epistemos.openNote")
        activity.title = title
        activity.isEligibleForSearch = true
        activity.persistentIdentifier = pageId
        activity.userInfo = [CSSearchableItemActivityIdentifier: pageId]

        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = title
        attributes.contentDescription =
            tags.isEmpty
            ? "Note in Epistemos"
            : "Tags: \(tags.joined(separator: ", "))"
        activity.contentAttributeSet = attributes

        activeUserActivity = activity
        activity.becomeCurrent()
    }

    /// Tracks the current NSUserActivity so it stays alive while the note window is open.
    private var activeUserActivity: NSUserActivity?

    // MARK: - Tab Windows

    /// Open a note in a new tab window. If already open, bring to front.
    func openWindow(for page: SDPage) {
        // If window already exists for this page, bring to front
        if let existing = windows[page.id], existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        guard let bootstrap = AppBootstrap.shared else {
            Self.log.error("AppBootstrap not available — cannot open note window")
            return
        }

        let pageTitle = page.title.isEmpty ? "Untitled" : page.title

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = pageTitle
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)
        window.setFrameAutosaveName("note-\(page.id)")
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "epistemos-note-tabs"
        window.delegate = tabDelegate

        // Match system appearance and background to theme
        if let theme = AppBootstrap.shared?.uiState.theme {
            window.appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
            window.titlebarAppearsTransparent = true
            window.backgroundColor = theme.nsBackground
        }

        let editorView = NoteTabShell(pageId: page.id, pageTitle: pageTitle)
            .withAppEnvironment(bootstrap)
            .modelContainer(bootstrap.modelContainer)
        let hostingView = NSHostingView(rootView: editorView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = hostingView

        let pageId = page.id
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            Task { @MainActor in
                self?.handleWindowClose(window, pageId: pageId)
            }
        }
        observers[page.id] = observer

        if let existingWindow = windows.values.first {
            existingWindow.addTabbedWindow(window, ordered: .above)
        }
        window.makeKeyAndOrderFront(nil)
        windows[page.id] = window

        Self.log.info("Opened note tab for: \(page.title, privacy: .public)")
    }

    /// Reverse lookup: find the pageId for a given window.
    func pageId(for window: NSWindow) -> String? {
        windows.first(where: { $0.value === window })?.key
    }

    /// Forward lookup: find the NSWindow for a given pageId.
    func window(for pageId: String) -> NSWindow? {
        windows[pageId]
    }

    private func handleWindowClose(_ window: NSWindow, pageId: String) {
        if let observer = observers.removeValue(forKey: pageId) {
            NotificationCenter.default.removeObserver(observer)
        }
        windows.removeValue(forKey: pageId)
        navigationStates.removeValue(forKey: pageId)
    }

    // MARK: - Version Tab (Read-Only)

    /// Open a past version of a note as a read-only tab next to existing note tabs.
    func openVersionTab(title: String, body: String, date: Date) {
        guard let bootstrap = AppBootstrap.shared else { return }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateStr = formatter.string(from: date)

        let view = ReadOnlyVersionView(title: title, versionBody: body, dateLabel: dateStr)
            .environment(bootstrap.uiState)
            .modelContainer(bootstrap.modelContainer)
        let hostingView = NSHostingView(rootView: view)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let windowTitle = title.isEmpty ? "Untitled" : title
        window.title = "\(windowTitle) — \(dateStr)"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)

        // Sync window chrome to current theme
        let theme = bootstrap.uiState.theme
        window.appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)

        // Zoom instead of fullscreen
        window.collectionBehavior.remove(.fullScreenPrimary)

        // Join the note tab group
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "epistemos-note-tabs"

        // Add as tab next to existing note windows
        if let existingWindow = windows.values.first {
            existingWindow.addTabbedWindow(window, ordered: .above)
        }
        window.makeKeyAndOrderFront(nil)

        // Track with a unique key so it gets cleaned up
        let key = "version-\(UUID().uuidString)"
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            Task { @MainActor in
                self?.handleWindowClose(window, pageId: key)
            }
        }
        observers[key] = observer
        windows[key] = window

        Self.log.info(
            "Opened version tab: \(windowTitle, privacy: .public) (\(dateStr, privacy: .public))")
    }

    /// Sync appearance of all note windows to the current theme.
    func syncTheme(theme: EpistemosTheme) {
        let appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
        for w in windows.values {
            w.appearance = appearance
            w.backgroundColor = theme.nsBackground
        }
    }
}

// MARK: - Tab Delegate
// Handles the native macOS tab bar + button — creates a new untitled note as a tab.
// Also syncs activePageId when the user switches between tabs.

private final class NoteTabDelegate: NSObject, NSWindowDelegate {
    @MainActor func newWindowForTab(_ sender: NSWindow) {
        Task { @MainActor in
            guard let vaultSync = AppBootstrap.shared?.vaultSync else { return }
            if let pageId = await vaultSync.createPage(title: "Untitled") {
                NoteWindowManager.shared.open(pageId: pageId)
            }
        }
    }

    @MainActor func windowDidBecomeMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
            let pageId = NoteWindowManager.shared.pageId(for: window)
        else { return }
        AppBootstrap.shared?.notesUI.openPage(
            NoteWindowManager.shared.currentPageId(forTab: pageId))
    }
}

// MARK: - Note Tab Shell
// Thin wrapper that owns NoteNavigationState for in-tab wikilink navigation.
// Renders breadcrumb bar + NotePageContent. Uses .id(currentPageId) to force
// full view recreation on navigation (fresh @Query, @State, NoteChatState).

private struct NoteTabShell: View {
    @State private var navState: NoteNavigationState

    init(pageId: String, pageTitle: String) {
        _navState = State(
            initialValue: NoteNavigationState(
                rootPageId: pageId, rootTitle: pageTitle
            ))
    }

    var body: some View {
        NotePageContent(pageId: navState.currentPageId)
            .id(navState.currentPageId)
            .environment(navState)
        .onChange(of: navState.currentPageId) { _, newPageId in
            // Sync window title to the currently displayed page.
            let targetId = newPageId
            if let window = NSApp.keyWindow {
                let desc = FetchDescriptor<SDPage>(
                    predicate: #Predicate<SDPage> { $0.id == targetId }
                )
                if let page = try? AppBootstrap.shared?.modelContainer.mainContext.fetch(desc).first
                {
                    window.title = page.title.isEmpty ? "Untitled" : page.title
                }
            }
            AppBootstrap.shared?.notesUI.openPage(newPageId)
        }
        .onAppear {
            NoteWindowManager.shared.registerNavState(navState, forTab: navState.rootPageId)
        }
        .onDisappear {
            NoteWindowManager.shared.unregisterNavState(forTab: navState.rootPageId)
        }
    }
}

// MARK: - Note Page Content
// Self-contained note editor for each page within a tab.
// Resolves pageId → SDPage via @Query, shows ProseEditorView,
// adds toolbar + Cmd+S / Cmd+Shift+S shortcuts.

private struct NotePageContent: View {
    let pageId: String

    @Environment(NoteNavigationState.self) private var navState: NoteNavigationState?
    @Environment(UIState.self) private var ui
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(ResearchState.self) private var researchState
    @Environment(EventBus.self) private var eventBus
    @Environment(TriageService.self) private var triageService
    @Environment(LLMService.self) private var llmService
    @Environment(\.modelContext) private var modelContext
    @Query private var pages: [SDPage]
    @State private var showDiffSheet = false
    @State private var showInfoPopover = false
    @State private var showPreview = false
    @State private var showWriterMode = false
    @State private var isScanningCitations = false
    @State private var showIdeasPopover = false
    @State private var showChatSidebar = false
    @State private var showBacklinksPopover = false
    @State private var hasMultipleTabs = false
    @State private var wordCount: Int = 0
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
            HStack(spacing: 0) {
            ZStack {
                if let page = pages.first {
                    if showWriterMode {
                        WriterModeView(
                            page: page, isDark: ui.theme.isDark, theme: ui.theme,
                            isLocked: page.isLocked
                        )
                        .frame(minWidth: 400, minHeight: 300)
                    } else if showPreview {
                        NotePreviewView(body: page.loadBody(), isDark: ui.theme.isDark)
                            .frame(minWidth: 400, minHeight: 300)
                    } else {
                        ProseEditorView(page: page, isEditable: !page.isLocked)
                            .frame(minWidth: 400, minHeight: 300)
                    }
                } else {
                    ContentUnavailableView("Note not found", systemImage: "doc.questionmark")
                        .frame(minWidth: 400, minHeight: 300)
                }

                // Greeting overlay — always in the view tree (no insertion delay).
                // Opacity is flipped instantly to 1 before the mode swap, then
                // animated back to 0 after the new view has settled.
                TransitionGreetingView(
                    message: transitionGreeting,
                    theme: ui.theme
                )
                .opacity(transitionOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(transitionOpacity > 0)
            }
            .overlay(alignment: .bottom) {
                Text("\(wordCount) words")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: Capsule())
                    .padding(8)
            }
            .overlay(alignment: .trailing) {
                if let page = pages.first {
                    NoteOutlineOverlay(
                        markdown: page.loadBody(),
                        theme: ui.theme,
                        onNavigate: { charOffset in
                            scrollEditorTo(charOffset: charOffset)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ui.theme.background)
            .environment(noteChatState)
            .onAppear {
                noteChatState.loadPersistedMessages(modelContext)
                refreshTabCount()
                if let page = pages.first {
                    wordCount = NSSpellChecker.shared.countWords(
                        in: page.loadBody(), language: nil)
                }
            }
            .onDisappear {
                noteChatState.clear()
            }
            .onChange(of: noteChatState.isStreaming) { wasStreaming, isNowStreaming in
                if wasStreaming && !isNowStreaming, let page = pages.first {
                    noteChatState.persistMessages(modelContext, noteTitle: page.title)
                }
            }


        }
        }
        .toolbar {
            // Back / Forward (only when navigating wikilinks)
            if let nav = navState, nav.hasBreadcrumb {
                ToolbarItem(placement: .navigation) {
                    wikilinksNavButtons(nav: nav)
                }
            }

            // Format menu
            ToolbarItem {
                Menu {
                    Button("Bold  ⌘B") { insertMarkdown("**", "**") }
                    Button("Italic  ⌘I") { insertMarkdown("*", "*") }
                    Menu("Heading") {
                        Button("H1") { insertLinePrefix("# ") }
                        Button("H2") { insertLinePrefix("## ") }
                        Button("H3") { insertLinePrefix("### ") }
                    }
                    Divider()
                    Button("Strikethrough") { insertMarkdown("~~", "~~") }
                    Button("Code") { insertMarkdown("`", "`") }
                    Button("Link") { insertMarkdown("[", "](url)") }
                } label: {
                    Label("Format", systemImage: "textformat")
                }
                .help("Format")
            }

            // Preview toggle
            ToolbarItem {
                Button { togglePreviewMode() } label: {
                    Label(
                        showPreview ? "Editor" : "Preview",
                        systemImage: showPreview ? "pencil" : "eye")
                }
                .help(showPreview ? "Editor (⌘E)" : "Preview (⌘E)")
            }

            // More menu
            ToolbarItem {
                moreMenu
            }

            // Ask field (centered)
            if !showWriterMode && !showPreview {
                ToolbarItem(placement: .principal) {
                    toolbarChatField
                }
            }

            // Backlinks
            if !showWriterMode && !showPreview {
                ToolbarItem {
                    Button { showBacklinksPopover.toggle() } label: {
                        Label("Backlinks", systemImage: "link")
                    }
                    .help("Backlinks")
                    .popover(isPresented: $showBacklinksPopover, arrowEdge: .bottom) {
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
                }
            }

            // Chat History popover
            if !showWriterMode && !showPreview {
                ToolbarItem {
                    Button {
                        showChatSidebar.toggle()
                    } label: {
                        Label(
                            showChatSidebar ? "Hide Chat" : "Chat History",
                            systemImage: showChatSidebar ? "bubble.left.fill" : "bubble.left")
                    }
                    .help("Chat History")
                    .popover(isPresented: $showChatSidebar, arrowEdge: .bottom) {
                        NoteChatSidebar()
                            .environment(noteChatState)
                            .frame(width: 320, height: 420)
                    }
                }
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
            Button("") { toggleWriterMode() }
                .keyboardShortcut("r", modifiers: .command)
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
            Button("") {
                if let page = pages.first {
                    page.isLocked.toggle()
                    do { try modelContext.save() } catch {
                        Log.notes.error(
                            "Save failed (lock shortcut): \(error.localizedDescription, privacy: .private)"
                        )
                    }
                }
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .hidden()
            Button("") { navState?.back() }
                .keyboardShortcut("[", modifiers: .command)
                .hidden()
            Button("") { navState?.forward() }
                .keyboardShortcut("]", modifiers: .command)
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
            NotificationCenter.default.publisher(for: NSText.didChangeNotification)
        ) { _ in refreshWordCount() }
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
            handleAIContextMenuOperation(op, selectedText: selected)
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

    // MARK: - Wikilink Navigation (Native Toolbar Items)

    @ViewBuilder
    private func wikilinksNavButtons(nav: NoteNavigationState) -> some View {
        HStack(spacing: 2) {
            Button { nav.back() } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!nav.canGoBack)

            Button { nav.forward() } label: {
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

    private func refreshWordCount() {
        guard let tv = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        let count = NSSpellChecker.shared.countWords(in: tv.string, language: nil)
        if count != wordCount { wordCount = count }
    }

    private func snapshotEditorSelection() {
        guard let tv = NSApp.keyWindow?.firstResponder as? NSTextView else {
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
            name: NSNotification.Name("EpistemosReplaceRange"),
            object: nil,
            userInfo: [
                "pageId": pageId,
                "range": NSValue(range: lineRange),
                "replacement": newLine,
            ]
        )
    }

    private func handleAIContextMenuOperation(_ op: String, selectedText: String?) {
        let mapping: (operation: NotesOperation, systemPrompt: String, userPrompt: String) = {
            switch op {
            case "rewrite":
                return (
                    .rewrite,
                    "You are a writing assistant. Rewrite the selected text to improve clarity and flow. Output ONLY the rewritten text.",
                    "Rewrite this:\n\n\(selectedText ?? "")"
                )
            case "summarize":
                return (
                    .summarize,
                    "You are a summarization assistant. Summarize the selected text concisely. Output ONLY the summary.",
                    "Summarize this:\n\n\(selectedText ?? "")"
                )
            case "expand":
                return (
                    .expand,
                    "You are a writing assistant. Expand the selected text with more detail and depth. Maintain the same tone.",
                    "Expand on this:\n\n\(selectedText ?? "")"
                )
            case "simplify":
                return (
                    .rewrite,
                    "You are a writing assistant. Simplify the text to be easier to understand. Use shorter sentences. Output ONLY the simplified text.",
                    "Simplify this:\n\n\(selectedText ?? "")"
                )
            case "toList":
                return (
                    .outline,
                    "You are a formatting assistant. Convert the text into a clean markdown bullet list. Output ONLY the list.",
                    "Convert to a bullet list:\n\n\(selectedText ?? "")"
                )
            case "toTable":
                return (
                    .outline,
                    "You are a formatting assistant. Convert the text into a markdown table. Output ONLY the table.",
                    "Convert to a markdown table:\n\n\(selectedText ?? "")"
                )
            case "continue":
                return (
                    .continueWriting,
                    "You are a writing assistant. Continue writing from where the note left off. Match the tone and style. Output ONLY the continuation.",
                    "Continue writing from where this note ends."
                )
            case "outline":
                return (
                    .outline,
                    "You are a structural analysis assistant. Generate a structured outline using markdown headers and bullet points. Output ONLY the outline.",
                    "Generate a structured outline for this note."
                )
            case "structure":
                return (
                    .analyze,
                    "You are a note organization assistant. Suggest a better structure for this note. Output a reorganized version.",
                    "Suggest a better structure for this note."
                )
            case "restructure":
                return (
                    .analyze,
                    "You are a note restructuring assistant. Completely reorganize the entire note for better clarity, flow, and logical progression. Preserve ALL content. Use proper markdown formatting. Output the COMPLETE restructured note.",
                    "Restructure this entire note for better organization and flow."
                )
            default:
                return (
                    .ask(query: selectedText ?? "Help me with this note."),
                    "You are a helpful note assistant. Answer concisely based on the note content.",
                    selectedText ?? "Help me with this note."
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
        guard let window = NSApp.keyWindow else { return }
        // Walk the responder chain to find the text view, or search subviews.
        let textView: NSTextView? =
            window.firstResponder as? NSTextView
            ?? window.contentView?.findFirstTextView()
        guard let tv = textView else { return }

        let safeOffset = min(charOffset, tv.string.count)
        let range = NSRange(location: safeOffset, length: 0)
        tv.setSelectedRange(range)
        tv.scrollRangeToVisible(range)
        // Flash the line briefly by selecting the whole line
        let lineRange = (tv.string as NSString).lineRange(for: range)
        tv.showFindIndicator(for: lineRange)
    }

    // MARK: - Editor Flush & Pool Reset (Mode Switching)
    // Flushes unsaved text from the current editor (ProseEditor or Writer) to page.body
    // before switching modes, preventing stale data in the new editor.
    // Also invalidates the PageStoragePool entry so the regular editor gets a fresh
    // MarkdownTextStorage with correct formatting when switching back from Writer/Preview.

    private func invalidateEditorCache() {
        PageStoragePool.shared.saveToDisk(pageId: pageId)
        PageStoragePool.shared.remove(pageId: pageId)
    }

    private func flushCurrentEditor() {
        guard let page = pages.first else { return }
        // Read from PageStoragePool first — reliable regardless of first responder.
        // Falls back to NSTextView first responder for Writer Mode (separate storage).
        let fullText: String
        if let poolText = PageStoragePool.shared.bodyText(for: pageId) {
            fullText = poolText
        } else if let responder = NSApp.keyWindow?.firstResponder as? NSTextView {
            fullText = responder.layoutManager?.textStorage?.string ?? responder.string
        } else {
            return
        }
        if fullText != page.loadBody() {
            page.saveBody(fullText)
            page.needsVaultSync = true
            page.updatedAt = .now
            AppBootstrap.shared?.graphState.needsRefresh = true
        }
    }

    // MARK: - Mode Transition Helpers
    // Shows a solid greeting card that fully covers the view swap glitch.
    // Timing: appear instantly → mode swaps behind it → fade out after settling.

    private static let greetings = [
        "hey there...",
        "working hard?",
        "shhhhh....",
        "i love you",
        "giving yourself grace today?",
        "take a breath...",
        "you're doing great",
        "one step at a time",
        "be gentle with yourself",
        "deep breaths...",
        "almost there...",
        "you got this",
        "stay curious",
        "keep going...",
        "thoughts becoming words...",
        "words becoming worlds...",
    ]

    private func toggleWriterMode() {
        guard !isTransitioning else { return }
        guard !showPreview else { return }
        flushCurrentEditor()
        performGreetingTransition {
            invalidateEditorCache()
            showWriterMode.toggle()
        }
    }

    private func togglePreviewMode() {
        guard !isTransitioning else { return }
        guard !showWriterMode else { return }
        flushCurrentEditor()
        performGreetingTransition {
            invalidateEditorCache()
            showPreview.toggle()
        }
    }

    private func performGreetingTransition(_ modeSwap: @escaping () -> Void) {
        // Pick a random greeting
        transitionGreeting = Self.greetings.randomElement() ?? "hey there..."
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
                Text("Chat")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if !noteChatState.isStreaming {
                    Button {
                        noteChatState.discardResponse()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ui.theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            Divider().opacity(0.3)

            // Conversation thread
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(noteChatState.messages.enumerated()), id: \.element.id) { _, msg in
                            chatBubble(msg)
                        }

                        // Current streaming response (not yet in messages)
                        if noteChatState.isStreaming || !noteChatState.responseText.isEmpty {
                            streamingBubble
                                .id("streaming")
                        }
                    }
                    .padding(12)
                }
                .onChange(of: noteChatState.responseText.count) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
            .frame(minHeight: 200, idealHeight: 300, maxHeight: 500)

            Divider().opacity(0.3)

            // Follow-up input + actions
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
                        Image(systemName: "text.insert")
                            .font(.system(size: 11))
                            .foregroundStyle(ui.theme.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Insert last response into note")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 400, idealWidth: 480, maxWidth: 560)
    }

    private func chatBubble(_ msg: AssistantMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 60) }
            Text(msg.content)
                .font(.system(size: 12))
                .foregroundStyle(msg.role == .user ? ui.theme.userBubbleText : .primary)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    msg.role == .user
                        ? AnyShapeStyle(ui.theme.userBubbleBg)
                        : AnyShapeStyle(ui.theme.muted),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            if msg.role == .assistant { Spacer(minLength: 60) }
        }
    }

    private var streamingBubble: some View {
        HStack {
            if noteChatState.responseText.isEmpty && noteChatState.isStreaming {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Thinking\u{2026}")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ui.theme.muted, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Text(noteChatState.responseText + (noteChatState.isStreaming ? " \u{258D}" : ""))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ui.theme.muted, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            Spacer(minLength: 60)
        }
    }

    // MARK: - Toolbar Chat Field

    private var toolbarChatField: some View {
        HStack(spacing: 6) {
            @Bindable var chat = noteChatState
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            TextField("Ask", text: $chat.inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .frame(width: 200)
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
        .background(.clear, in: RoundedRectangle(cornerRadius: 6))
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
            // Format
            Menu {
                Button("Bold  \u{2318}B") { insertMarkdown("**", "**") }
                Button("Italic  \u{2318}I") { insertMarkdown("*", "*") }
                Menu("Heading") {
                    Button("Heading 1") { insertLinePrefix("# ") }
                    Button("Heading 2") { insertLinePrefix("## ") }
                    Button("Heading 3") { insertLinePrefix("### ") }
                    Button("Heading 4") { insertLinePrefix("#### ") }
                }
                Divider()
                Button("Strikethrough") { insertMarkdown("~~", "~~") }
                Button("Code") { insertMarkdown("`", "`") }
                Button("Link") { insertMarkdown("[", "](url)") }
            } label: {
                Label("Format", systemImage: "textformat")
            }

            Divider()

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
                    page.isLocked.toggle()
                    do { try modelContext.save() } catch {
                        Log.notes.error(
                            "Save failed (lock toggle): \(error.localizedDescription, privacy: .private)"
                        )
                    }
                } label: {
                    Label(
                        page.isLocked ? "Unlock" : "Lock",
                        systemImage: page.isLocked ? "lock.fill" : "lock.open")
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
                toggleWriterMode()
            } label: {
                Label(
                    showWriterMode ? "Editor (\u{2318}R)" : "Writer Mode (\u{2318}R)",
                    systemImage: showWriterMode ? "pencil" : "text.page")
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
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
        .help("More")
    }

    /// Wraps the current selection (or inserts at cursor) with markdown syntax.
    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        guard let tv = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        let range = tv.selectedRange()
        let selected = (tv.string as NSString).substring(with: range)
        tv.insertText("\(prefix)\(selected)\(suffix)", replacementRange: range)
    }

    /// Inserts a prefix at the start of the current line (for headings).
    private func insertLinePrefix(_ prefix: String) {
        guard let tv = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        let str = tv.string as NSString
        let cursor = tv.selectedRange().location
        let lineRange = str.lineRange(for: NSRange(location: cursor, length: 0))
        tv.insertText(prefix, replacementRange: NSRange(location: lineRange.location, length: 0))
    }

    // MARK: - Info Panel

    private func noteInfoPanel(page: SDPage) -> some View {
        let currentBody = page.loadBody()
        let wordCount = currentBody.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let charCount = currentBody.count
        let readingTime = max(1, wordCount / 200)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Note Info").font(.headline)
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.foreground)
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
            let anchor = Self.currentCursorLine()
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
    static func currentCursorLine() -> (line: Int, context: String?)? {
        // Walk the window list to find an NSTextView (editor might not be key when popover is open)
        guard let tv = findEditorTextView() else { return nil }
        let str = tv.string as NSString
        guard str.length > 0 else { return (1, nil) }
        let cursor = min(tv.selectedRange().location, str.length)
        let lineRange = str.lineRange(for: NSRange(location: cursor, length: 0))
        let lineText = str.substring(with: lineRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Count line number (1-based)
        var lineNum = 1
        str.enumerateSubstrings(
            in: NSRange(location: 0, length: min(cursor, str.length)),
            options: [.byLines, .substringNotRequired]
        ) { _, _, _, _ in lineNum += 1 }

        let snippet = lineText.isEmpty ? nil : String(lineText.prefix(80))
        return (lineNum, snippet)
    }

    /// Find the editor NSTextView — searches the note window's view hierarchy
    /// because the popover steals key focus from the editor.
    private static func findEditorTextView() -> NSTextView? {
        // First try the direct responder chain
        if let tv = NSApp.keyWindow?.firstResponder as? NSTextView,
            tv.isEditable
        {
            return tv
        }
        // Search all windows in the note tab group
        for window in NSApp.windows where window.tabbingIdentifier == "epistemos-note-tabs" {
            if let tv = findTextView(in: window.contentView) {
                return tv
            }
        }
        return nil
    }

    private static func findTextView(in view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let tv = view as? NSTextView, tv.isEditable { return tv }
        for sub in view.subviews {
            if let tv = findTextView(in: sub) { return tv }
        }
        return nil
    }

    // MARK: - Actions

    private func saveNewItem() {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = newBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedBody.isEmpty else { return }

        let anchor = Self.currentCursorLine()

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
        guard let line, let tv = Self.findEditorTextView() else { return }
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
        guard let tv = Self.findEditorTextView() else { return }
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

                guard let tv = Self.findEditorTextView() else {
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
    let isDark: Bool

    private static let maxReadableWidth: CGFloat = 720
    private static let minHorizontalInset: CGFloat = 60
    private static let verticalInset: CGFloat = 54

    func makeNSView(context: Context) -> NSScrollView {
        let storage = MarkdownTextStorage()
        storage.isDark = isDark

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

        DispatchQueue.main.async {
            Self.updateCenteringInsets(for: tv)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let storage = context.coordinator.storage else { return }

        // Update theme
        if context.coordinator.lastIsDark != isDark {
            context.coordinator.lastIsDark = isDark
            storage.isDark = isDark
            if let tv = scrollView.documentView as? NSTextView {
                let baseColor: NSColor =
                    isDark ? .white.withAlphaComponent(0.88) : NSColor(white: 0.1, alpha: 1)
                tv.textColor = baseColor
            }
            storage.reapplyAllStyles()
        }

        // Update content if changed
        if storage.string != body {
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.replaceCharacters(in: fullRange, with: body)
        }

        // Update centering
        if let tv = scrollView.documentView as? NSTextView {
            Self.updateCenteringInsets(for: tv)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var storage: MarkdownTextStorage?
        var lastIsDark = true
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

// MARK: - Transition Greeting View
// A solid full-screen overlay with a gentle centered message.
// Fully opaque to mask the SwiftUI view-swap glitch during mode transitions.
// Background and text colors match the current theme.

private struct TransitionGreetingView: View {
    let message: String
    let theme: EpistemosTheme

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            Text(message)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(theme.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - NSView Helper

extension NSView {
    /// Recursively find the first NSTextView in the subview hierarchy.
    fileprivate func findFirstTextView() -> NSTextView? {
        for subview in subviews {
            if let tv = subview as? NSTextView { return tv }
            if let found = subview.findFirstTextView() { return found }
        }
        return nil
    }
}
