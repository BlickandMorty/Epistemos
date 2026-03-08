import SwiftData
import SwiftUI

// MARK: - ProseEditorView
// The single notes editor for the entire app. ONE persistent NSTextView —
// MarkdownTextStorage instances are swapped per page via PageStoragePool.
// Content loads instantly from pre-styled storage (no restyling needed).
//
// Data flow:
//   1. Disk file (NoteFileStorage) -> @State bodyText -> ProseEditorRepresentable
//   2. User types -> Coordinator updates binding -> onChange debounces -> disk file
//   3. Disk file is the sole source of truth — page.body is always "" post-migration.
//      External changes (restore, vault sync) signal via NoteFileStorage.pageBodyDidChange.
//      Vault .md files are updated on explicit Save / Save All / auto-save interval.
//
// This view is the SwiftUI container that handles:
// - SwiftData read/write (via onPageFlush callback to Coordinator)
// - Debounced saves (coalesced to reduce UI churn)
// - Theme-aware dark mode
// - Wikilink navigation (via NoteWindowManager)

struct ProseEditorView: View {
    let page: SDPage
    var isEditable: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(NoteChatState.self) private var noteChatState
    @Environment(NoteNavigationState.self) private var navState: NoteNavigationState?
    @Environment(GraphState.self) private var graphState

    @State private var bodyText: String = ""
    /// Snapshot of the last body persisted to disk. Avoids disk reads on every keystroke.
    @State private var lastPersistedBody: String = ""
    @State private var isFocused = true
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        let flush: (String, String) -> Void = { oldPageId, currentText in
            guard !oldPageId.isEmpty else { return }
            let desc = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == oldPageId }
            )
            if let oldPage = try? modelContext.fetch(desc).first {
                oldPage.saveBody(currentText)
                oldPage.needsVaultSync = true
                try? modelContext.save()
            }
        }

        Group {
            if notesUI.useTK2Editor {
                ProseEditorRepresentable2(
                    text: $bodyText,
                    pageId: page.id,
                    pageBody: bodyText,
                    isFocused: isFocused,
                    theme: ui.theme,
                    isEditable: isEditable,
                    isFocusMode: notesUI.isFocusMode,
                    modelContext: modelContext,
                    onWikilinkClick: handleWikilinkClick,
                    onBlockRefClick: handleBlockRefClick,
                    noteChatState: noteChatState,
                    onPageFlush: flush,
                    graphState: graphState
                )
            } else {
                ProseEditorRepresentable(
                    text: $bodyText,
                    pageId: page.id,
                    pageBody: bodyText,
                    isFocused: isFocused,
                    isDark: ui.theme.isDark,
                    isEditable: isEditable,
                    isFocusMode: notesUI.isFocusMode,
                    modelContext: modelContext,
                    onWikilinkClick: handleWikilinkClick,
                    onBlockRefClick: handleBlockRefClick,
                    noteChatState: noteChatState,
                    onPageFlush: flush,
                    graphState: graphState
                )
            }
        }
        .onAppear {
            let body = page.loadBody()
            bodyText = body
            lastPersistedBody = body
            // Lazy block migration: create SDBlocks for pages that predate block outlining.
            lazyMigrateBlocks(body: body)
        }
        // @State management only — text flush is handled by Coordinator's onPageFlush.
        .onChange(of: page.id) { _, _ in
            saveTask?.cancel()
            let body = page.loadBody()
            bodyText = body
            lastPersistedBody = body
        }
        .onChange(of: bodyText) { _, newValue in
            guard newValue != lastPersistedBody else { return }
            debouncedSave(newValue)
        }
        // Detect external body changes (restore-to-version, vault sync, etc.)
        // page.body is always "" for migrated notes, so it's useless as a change signal.
        // Instead, listen for an explicit notification keyed by pageId.
        .onReceive(
            NotificationCenter.default.publisher(for: NoteFileStorage.pageBodyDidChange)
        ) { notification in
            guard let changedId = notification.userInfo?["pageId"] as? String,
                  changedId == page.id else { return }
            saveTask?.cancel()
            let fresh = page.loadBody()
            bodyText = fresh
            lastPersistedBody = fresh
        }
        .onDisappear {
            flushIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        ) { _ in
            flushIfNeeded()
        }
    }

    private func flushIfNeeded() {
        saveTask?.cancel()
        if lastPersistedBody != bodyText {
            page.saveBody(bodyText)
            lastPersistedBody = bodyText
            page.needsVaultSync = true
            try? modelContext.save()
        }
    }

    // MARK: - Debounced Save
    // PERF: Save debounce is 5s during active typing to avoid hammering SwiftData.
    // Every page.body write triggers @Query re-fetch -> full view tree re-evaluation.
    // Body-only — no word count, no H1 extraction, no updatedAt.
    // These are stripped to keep MainActor unblocked.
    //
    // No data loss risk: text lives in NSTextView + @State bodyText at all times.
    // onDisappear flushes immediately on page close/switch. The 5s debounce only
    // delays the SwiftData persist — comparable to Notion/Google Docs cadence.

    private func debouncedSave(_ newValue: String) {
        saveTask?.cancel()
        let pageId = page.id
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else {
                return
            }
            guard newValue != lastPersistedBody else {
                return
            }
            // File write FIRST — disk is source of truth. Must complete before
            // modelContext.save() so any @Query cascade reads correct content.
            await Task.detached(priority: .utility) {
                NoteFileStorage.writeBody(pageId: pageId, content: newValue)
            }.value
            lastPersistedBody = newValue
            // Persist dirty flag AFTER file write. This ensures loadBody() returns
            // the new content if @Query refetch triggers view re-evaluation.
            page.needsVaultSync = true
            try? modelContext.save()
        }
    }

    // MARK: - Block Migration

    /// Create SDBlock entities for pages that predate block outlining.
    /// Called once per page open — if blocks already exist, this is a no-op (fetchCount only).
    private func lazyMigrateBlocks(body: String) {
        guard !body.isEmpty else { return }
        let pageId = page.id
        let descriptor = FetchDescriptor<SDBlock>(
            predicate: #Predicate<SDBlock> { $0.pageId == pageId }
        )
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        if count == 0 {
            let parsed = BlockParser.parse(body)
            guard !parsed.isEmpty else { return }
            // Build parent chain: for each block at depth > 0, parent is closest preceding block at depth - 1.
            var depthStack: [(depth: Int, block: SDBlock)] = []
            for p in parsed {
                let block = SDBlock(
                    pageId: pageId,
                    content: p.content,
                    depth: p.depth,
                    order: p.order * 1000
                )
                while let last = depthStack.last, last.depth >= p.depth {
                    depthStack.removeLast()
                }
                if p.depth > 0, let parent = depthStack.last {
                    block.parentBlockId = parent.block.id
                }
                depthStack.append((p.depth, block))
                modelContext.insert(block)
            }
            try? modelContext.save()
        }
    }

    // MARK: - Wikilink Navigation

    private func handleWikilinkClick(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Step 1: Exact case-sensitive match (fast, uses SwiftData index).
        let exactDesc = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.title == trimmed }
        )
        // Step 2: Only if exact match fails, scan for case-insensitive match.
        let lowered = trimmed.lowercased()
        let existing: SDPage? = (try? modelContext.fetch(exactDesc))?.first ?? {
            let allDesc = FetchDescriptor<SDPage>()
            guard let pages = try? modelContext.fetch(allDesc) else { return nil }
            return pages.first(where: { $0.title.lowercased() == lowered })
        }()

        if let existing {
            navigateToPage(existing)
        } else {
            // Create new page for dangling wikilink — stay in same window
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

    /// Navigate to an existing page — in-place via navState if available, new tab otherwise.
    private func navigateToPage(_ target: SDPage) {
        let pageTitle = target.title.isEmpty ? "Untitled" : target.title
        // Skip if navigating to the current page
        guard target.id != page.id else { return }
        if let navState {
            navState.push(pageId: target.id, title: pageTitle)
        } else {
            NoteWindowManager.shared.open(pageId: target.id)
        }
    }

    // MARK: - Block Reference Navigation

    private func handleBlockRefClick(_ blockId: String) {
        guard !blockId.isEmpty else { return }
        // Resolve block ID to its source page via SDBlock lookup
        let descriptor = FetchDescriptor<SDBlock>(
            predicate: #Predicate<SDBlock> { $0.id == blockId }
        )
        guard let block = try? modelContext.fetch(descriptor).first else { return }
        // Skip if block is on the current page
        guard block.pageId != page.id else { return }

        // Look up the page title for the breadcrumb
        let targetPageId = block.pageId
        let pageDesc = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == targetPageId }
        )
        let title = (try? modelContext.fetch(pageDesc).first)?.title ?? "Untitled"
        if let navState {
            navState.push(pageId: block.pageId, title: title)
        } else {
            NoteWindowManager.shared.open(pageId: block.pageId)
        }
    }
}
