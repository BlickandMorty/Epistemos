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
// Toolbar (left → right): New Note | Pin, Favorite, Lock | Format, Preview, Info, Share | Sidebar, Save, Diff, Chat

private struct NoteTabView: View {
    let pageId: String

    @Environment(UIState.self) private var ui
    @Environment(VaultSyncService.self) private var vaultSync
    @Query private var pages: [SDPage]
    @State private var showDiffSheet = false
    @State private var showInfoPopover = false
    @State private var showPreview = false
    @State private var showWriterMode = false

    init(pageId: String) {
        self.pageId = pageId
        _pages = Query(filter: #Predicate<SDPage> { $0.id == pageId })
    }

    var body: some View {
        ZStack {
            if let page = pages.first {
                if showWriterMode {
                    WriterModeView(page: page, isDark: ui.theme.isDark, isLocked: page.isLocked)
                        .frame(minWidth: 400, minHeight: 300)
                } else if showPreview {
                    NotePreviewView(body: page.body, isDark: ui.theme.isDark)
                        .frame(minWidth: 400, minHeight: 300)
                } else {
                    ProseEditorView(page: page, isEditable: !page.isLocked)
                        .frame(minWidth: 400, minHeight: 300)
                }
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

            // — Organization: Pin, Favorite, Lock —
            ToolbarItemGroup(placement: .primaryAction) {
                if let page = pages.first {
                    Button {
                        page.isPinned.toggle()
                    } label: {
                        Label("Pin", systemImage: page.isPinned ? "pin.fill" : "pin")
                    }
                    .help(page.isPinned ? "Unpin" : "Pin")

                    Button {
                        page.isFavorite.toggle()
                    } label: {
                        Label("Favorite", systemImage: page.isFavorite ? "star.fill" : "star")
                    }
                    .help(page.isFavorite ? "Unfavorite" : "Favorite")

                    Button {
                        page.isLocked.toggle()
                    } label: {
                        Label("Lock", systemImage: page.isLocked ? "lock.fill" : "lock.open")
                    }
                    .help(page.isLocked ? "Unlock" : "Lock")
                }
            }

            // — Editor: Writer, Format, Preview, Info, Share —
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showWriterMode.toggle()
                    if showWriterMode { showPreview = false }
                } label: {
                    Label("Writer", systemImage: showWriterMode ? "doc.plaintext" : "doc.richtext")
                }
                .help("Writer Mode (⌘R)")

                formatMenu

                Button {
                    showPreview.toggle()
                    if showPreview { showWriterMode = false }
                } label: {
                    Label("Preview", systemImage: showPreview ? "eye.slash" : "eye")
                }
                .help("Preview (⌘E)")

                Button {
                    showInfoPopover.toggle()
                } label: {
                    Label("Info", systemImage: "info.circle")
                }
                .help("Info")
                .popover(isPresented: $showInfoPopover) {
                    if let page = pages.first {
                        noteInfoPanel(page: page)
                    }
                }

                Button {
                    if let page = pages.first {
                        shareNote(page)
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .help("Share")
            }

            // — Window: Sidebar, Save, Diff, Chat —
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
            Button("") { showPreview.toggle() }
                .keyboardShortcut("e", modifiers: .command)
                .hidden()
            Button("") {
                showWriterMode.toggle()
                if showWriterMode { showPreview = false }
            }
            .keyboardShortcut("r", modifiers: .command)
            .hidden()
            Button("") { insertMarkdown("**", "**") }
                .keyboardShortcut("b", modifiers: .command)
                .hidden()
            Button("") { insertMarkdown("*", "*") }
                .keyboardShortcut("i", modifiers: .command)
                .hidden()
        }
        .sheet(isPresented: $showDiffSheet) {
            if let page = pages.first {
                DiffSheetView(pageId: page.id, currentTitle: page.title, currentBody: page.body)
            }
        }
    }

    // MARK: - Format Menu

    private var formatMenu: some View {
        Menu {
            Button("Bold") { insertMarkdown("**", "**") }
            Button("Italic") { insertMarkdown("*", "*") }
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
        .help("Format")
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
        let wordCount = page.body.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let charCount = page.body.count
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
        let text = "# \(page.title)\n\n\(page.body)"
        let picker = NSSharingServicePicker(items: [text])
        // Present from the toolbar area of the key window
        if let contentView = NSApp.keyWindow?.contentView {
            let buttonRect = NSRect(x: contentView.bounds.midX, y: contentView.bounds.maxY - 40,
                                    width: 1, height: 1)
            picker.show(relativeTo: buttonRect, of: contentView, preferredEdge: .minY)
        }
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
