import SwiftData
import SwiftUI

// MARK: - ProseEditorView
// The single notes editor for the entire app. ONE persistent NSTextView —
// MarkdownTextStorage instances are swapped per page via PageStoragePool.
// Content loads instantly from pre-styled storage (no restyling needed).
//
// Data flow:
//   1. SDPage.body (SwiftData) -> @State bodyText -> ProseEditorRepresentable
//   2. User types -> Coordinator updates binding -> onChange debounces -> SDPage.body
//   3. SDPage.body is the sole source of truth — no live .md sync
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

    @State private var bodyText: String = ""
    /// Snapshot of the last body persisted to disk. Avoids disk reads on every keystroke.
    @State private var lastPersistedBody: String = ""
    @State private var isFocused = true
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        ProseEditorRepresentable(
            text: $bodyText,
            pageId: page.id,
            pageBody: bodyText,
            isFocused: isFocused,
            isDark: ui.theme.isDark,
            isEditable: isEditable,
            modelContext: modelContext,
            onWikilinkClick: handleWikilinkClick,
            onBlockRefClick: handleBlockRefClick,
            noteChatState: noteChatState,
            onPageFlush: { oldPageId, currentText in
                // Flush unsaved edits to the OLD page — body only, no metadata.
                // Called by Coordinator during page swap so all flush logic
                // lives in one place (updateNSView).
                guard !oldPageId.isEmpty else { return }
                let desc = FetchDescriptor<SDPage>(
                    predicate: #Predicate<SDPage> { $0.id == oldPageId }
                )
                if let oldPage = try? modelContext.fetch(desc).first {
                    oldPage.saveBody(currentText)
                    oldPage.needsVaultSync = true
                }
            }
        )
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
        // Detect external body changes (restore-to-version, sync, etc.)
        // page.body can change via DiffSheetView restore or VaultSync —
        // update bodyText so the NSTextView picks it up in updateNSView.
        // NOTE: post-migration body is always "" so this fires once and is harmless.
        .onChange(of: page.body) { _, newBody in
            guard newBody != bodyText else { return }
            saveTask?.cancel()
            bodyText = newBody
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
            guard !Task.isCancelled else { return }
            guard newValue != lastPersistedBody else { return }
            page.needsVaultSync = true
            // File write off main thread (nonisolated NoteFileStorage is thread-safe).
            await Task.detached(priority: .utility) {
                NoteFileStorage.writeBody(pageId: pageId, content: newValue)
            }.value
            // SwiftData mutation stays on main thread.
            if !page.body.isEmpty { page.body = "" }
            lastPersistedBody = newValue
            // Reconcile blocks — keep SDBlock entities in sync with edited markdown.
            // Runs on MainActor (same context as SwiftData writes). ~1ms for 200 blocks.
            BlockReconciler.reconcile(pageId: pageId, markdown: newValue, context: modelContext)
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
            BlockReconciler.initialPopulate(
                pageId: pageId, markdown: body, context: modelContext
            )
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
