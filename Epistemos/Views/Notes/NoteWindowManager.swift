import AppKit
import SwiftData
import SwiftUI
import os

// MARK: - Note Window Manager
// Manages note editor windows as a native macOS tab group.
// Every note opens as a tab using NoteTabView (fixed pageId, self-contained).
// Single entry point: open(pageId:) — fetches page, highlights sidebar, opens tab.

@MainActor
final class NoteWindowManager {
    static let shared = NoteWindowManager()

    // All note windows — one per page, displayed as tabs
    private var windows: [String: NSWindow] = [:]
    private var observers: [String: any NSObjectProtocol] = [:]
    private let tabDelegate = NoteTabDelegate()
    nonisolated static let log = Logger(subsystem: "com.epistemos", category: "NoteWindow")

    private init() {}

    // MARK: - Open Note (Single Entry Point)

    /// Open a note by ID — fetches the page, highlights in sidebar, opens as tab.
    /// Single entry point for all note-opening actions across the app.
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
    }

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

        // Create hosting view with full environment injection
        let editorView = NoteTabView(pageId: page.id)
            .environment(bootstrap.uiState)
            .environment(bootstrap.chatState)
            .environment(bootstrap.pipelineState)
            .environment(bootstrap.notesUI)
            .environment(bootstrap.researchState)
            .environment(bootstrap.soarState)
            .environment(bootstrap.eventBus)
            .environment(bootstrap.inferenceState)
            .environment(bootstrap.llmService)
            .environment(bootstrap.triageService)
            .environment(bootstrap.researchService)
            .environment(bootstrap.vaultSync)
            .environment(bootstrap.threadState)
            .environment(bootstrap.dailyBriefState)
            .modelContainer(bootstrap.modelContainer)
            .preferredColorScheme(bootstrap.uiState.theme.colorScheme)

        let hostingView = NSHostingView(rootView: editorView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = page.title.isEmpty ? "Untitled" : page.title
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)
        window.setFrameAutosaveName("note-\(page.id)")

        // Native macOS Finder-style tab bar
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "epistemos-note-tabs"
        window.delegate = tabDelegate

        // Track window close — store observer token for removal
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

        // Add as a tab to existing note window group (Finder-style)
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

    private func handleWindowClose(_ window: NSWindow, pageId: String) {
        if let observer = observers.removeValue(forKey: pageId) {
            NotificationCenter.default.removeObserver(observer)
        }
        windows.removeValue(forKey: pageId)
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
            .preferredColorScheme(bootstrap.uiState.theme.colorScheme)

        let hostingView = NSHostingView(rootView: view)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let windowTitle = title.isEmpty ? "Untitled" : title
        window.title = "\(windowTitle) — \(dateStr)"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)

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
    func syncTheme(isDark: Bool) {
        let appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        let background = AppBootstrap.shared.map { NSColor($0.uiState.theme.background) }

        for w in windows.values {
            w.appearance = appearance
            if let bg = background { w.backgroundColor = bg }
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
        AppBootstrap.shared?.notesUI.openPage(pageId)
    }
}

// MARK: - Note Tab View
// Self-contained note editor for each tab window.
// Resolves pageId → SDPage via @Query, shows ProseEditorView,
// adds sidebar toggle + Cmd+S / Cmd+Shift+S shortcuts.

private struct NoteTabView: View {
    let pageId: String

    @Environment(UIState.self) private var ui
    @Environment(VaultSyncService.self) private var vaultSync
    @Query private var pages: [SDPage]
    @State private var showDiffSheet = false

    init(pageId: String) {
        self.pageId = pageId
        _pages = Query(filter: #Predicate<SDPage> { $0.id == pageId })
    }

    var body: some View {
        ZStack {
            if let page = pages.first {
                ProseEditorView(page: page)
                    .frame(minWidth: 400, minHeight: 300)
            } else {
                ContentUnavailableView("Note not found", systemImage: "doc.questionmark")
                    .frame(minWidth: 400, minHeight: 300)
            }
        }
        .background(ui.theme.background)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {
            // New Note — far left
            ToolbarItem(placement: .navigation) {
                Button {
                    Task {
                        if let pageId = await vaultSync.createPage(title: "Untitled") {
                            NoteWindowManager.shared.open(pageId: pageId)
                        }
                    }
                } label: {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .help("New Note (⌘N)")
            }

            // Note Title — retro font, centered
            ToolbarItem(placement: .principal) {
                if let page = pages.first {
                    Text(page.title.isEmpty ? "Untitled" : page.title)
                        .font(.custom("RetroGaming", size: 13))
                        .foregroundStyle(ui.theme.fontAccent)
                        .lineLimit(1)
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    UtilityWindowManager.shared.show(.notes)
                } label: {
                    Label("Sidebar", systemImage: "sidebar.leading")
                }
                .help("Notes Sidebar (⌘2)")

                Button {
                    vaultSync.savePage(pageId: pageId)
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .help("Save (⌘S)")

                Button {
                    showDiffSheet = true
                } label: {
                    Label("Diff", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .help("Diff (⌘D)")

                Button {
                    MiniChatWindowController.shared.toggle()
                } label: {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
                .help("Mini Chat")
            }
        }
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
        }
        .sheet(isPresented: $showDiffSheet) {
            if let page = pages.first {
                DiffSheetView(pageId: page.id, currentTitle: page.title, currentBody: page.body)
            }
        }
    }
}
