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
// - SwiftData read/write
// - Debounced saves (coalesced to reduce UI churn)
// - Word count updates
// - Theme-aware dark mode
// - Wikilink navigation (via NotesUIState)

struct ProseEditorView: View {
    let page: SDPage

    @Environment(\.modelContext) private var modelContext
    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync

    @State private var bodyText: String = ""
    @State private var isFocused = true
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        ProseEditorRepresentable(
            text: $bodyText,
            pageId: page.id,
            pageBody: page.body,
            isFocused: isFocused,
            isDark: ui.theme.isDark,
            onWikilinkClick: handleWikilinkClick
        )
        .onAppear {
            bodyText = page.body
        }
        // Without .id(page.id), @State persists across page switches.
        // CRITICAL: When onChange fires, `page` already points to the NEW page,
        // but `bodyText` still holds the OLD page's content. We must flush
        // unsaved edits to the OLD page (by ID), NOT the current `page`.
        .onChange(of: page.id) { oldPageId, _ in
            saveTask?.cancel()

            // Flush unsaved edits to the OLD page — body only, no metadata.
            // Word count / updatedAt / H1 extraction are deferred to avoid
            // blocking MainActor during the page switch hot path.
            if !oldPageId.isEmpty && !bodyText.isEmpty {
                let desc = FetchDescriptor<SDPage>(
                    predicate: #Predicate<SDPage> { $0.id == oldPageId }
                )
                if let oldPage = try? modelContext.fetch(desc).first,
                    oldPage.body != bodyText
                {
                    oldPage.body = bodyText
                }
            }

            // Load new page content
            bodyText = page.body
        }
        .onChange(of: bodyText) { _, newValue in
            guard newValue != page.body else { return }
            debouncedSave(newValue)
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
        if page.body != bodyText {
            page.body = bodyText
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
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            guard newValue != page.body else { return }
            page.body = newValue
        }
    }

    // MARK: - Wikilink Navigation

    private func handleWikilinkClick(_ title: String) {
        let lowered = title.lowercased()

        // Search SwiftData for existing page with this title
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.title == lowered || $0.title == title }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            NoteWindowManager.shared.open(pageId: existing.id)
        } else {
            // Create new page for dangling wikilink
            Task {
                if let newId = await vaultSync.createPage(title: title) {
                    NoteWindowManager.shared.open(pageId: newId)
                }
            }
        }
    }
}
