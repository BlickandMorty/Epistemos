import SwiftData
import SwiftUI
import os

// MARK: - ProseEditorView
// The single notes editor for the entire app.
// TextKit 2 keeps editing state in the representable coordinator and restores
// scroll/selection from DiskStyleCache on page swaps.
//
// Data flow:
//   1. Live editor body (if already open) or disk file -> @State bodyText -> ProseEditorRepresentable2
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
    private static let log = Logger(subsystem: "com.epistemos", category: "ProseEditorView")
    let page: SDPage
    var isEditable: Bool = true
    let initialBodyOverride: String?

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

    init(page: SDPage, isEditable: Bool = true, initialBodyOverride: String? = nil) {
        self.page = page
        self.isEditable = isEditable
        self.initialBodyOverride = initialBodyOverride
        let snapshot = Self.initialBodySnapshot(for: page, preferredBody: initialBodyOverride)
        _bodyText = State(initialValue: snapshot.bodyText)
        _lastPersistedBody = State(initialValue: snapshot.lastPersistedBody)
    }

    static func initialBodySnapshot(for page: SDPage) -> (bodyText: String, lastPersistedBody: String) {
        initialBodySnapshot(for: page, preferredBody: nil)
    }

    static func initialBodySnapshot(for page: SDPage, preferredBody: String? = nil) -> (bodyText: String, lastPersistedBody: String) {
        let body = currentBody(for: page, preferredBody: preferredBody)
        return (body, body)
    }

    private static func currentBody(for page: SDPage, preferredBody: String? = nil) -> String {
        let rawBody = preferredBody ?? NoteWindowManager.shared.currentBody(for: page.id)
        return stripOrphanedInlineAIResponse(in: rawBody, page: page)
    }

    private static func stripOrphanedInlineAIResponse(in body: String, page: SDPage) -> String {
        guard let dividerRange = NoteChatInlineResponse.dividerRange(in: body) else { return body }
        let title = page.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = title.isEmpty ? page.id : title
        log.warning("Found orphaned AI divider in note \(resolvedTitle, privacy: .public) — stripping")
        return String(body[..<dividerRange.lowerBound])
    }

    static func syncedNoteTitle(from body: String) -> String? {
        var activeFence: Character?
        var extractedTitle: String?

        body.enumerateLines { rawLine, stop in
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if let fence = activeFence {
                if (fence == "`" && trimmed.hasPrefix("```"))
                    || (fence == "~" && trimmed.hasPrefix("~~~"))
                {
                    activeFence = nil
                }
                return
            }

            if trimmed.hasPrefix("```") {
                activeFence = "`"
                return
            }
            if trimmed.hasPrefix("~~~") {
                activeFence = "~"
                return
            }

            guard let title = syncedNoteTitle(inLine: rawLine) else { return }
            extractedTitle = title
            stop = true
        }

        return extractedTitle
    }

    @MainActor
    @discardableResult
    static func syncNoteTitleIfNeeded(
        from body: String,
        for page: SDPage,
        modelContext: ModelContext,
        renamePageFile: (String, String) -> Void
    ) -> Bool {
        guard let syncedTitle = syncedNoteTitle(from: body),
              syncedTitle != page.title else { return false }
        page.title = syncedTitle
        page.updatedAt = .now
        page.needsVaultSync = true
        try? modelContext.save()
        renamePageFile(page.id, syncedTitle)
        return true
    }

    private static func syncedNoteTitle(inLine rawLine: String) -> String? {
        var line = rawLine[...]
        var leadingSpaces = 0
        while line.first == " " {
            leadingSpaces += 1
            guard leadingSpaces <= 3 else { return nil }
            line = line.dropFirst()
        }

        guard line.first == "#" else { return nil }
        line = line.dropFirst()
        guard let separator = line.first, separator == " " || separator == "\t" else { return nil }

        let heading = String(line)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: #"\s+#+\s*$"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heading.isEmpty else { return nil }
        return VaultIndexActor.sanitizeTitle(heading)
    }

    var body: some View {
        let flush: (String, String) -> Void = { oldPageId, currentText in
            guard !oldPageId.isEmpty else { return }
            let desc = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == oldPageId }
            )
            if let oldPage = try? modelContext.fetch(desc).first {
                oldPage.applyInteractiveDerivedState(from: currentText)
                _ = NoteFileStorage.scheduleWriteBody(pageId: oldPageId, content: currentText)
                scheduleBlockMirrorSync(pageId: oldPageId, body: currentText)
                Self.syncNoteTitleIfNeeded(
                    from: currentText,
                    for: oldPage,
                    modelContext: modelContext
                ) { pageId, newTitle in
                    vaultSync.renamePageFile(pageId: pageId, newTitle: newTitle)
                }
                oldPage.needsVaultSync = true
                try? modelContext.save()
            }
        }

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
            graphState: graphState,
            outlineFoldMode: notesUI.outlineFoldMode
        )
        .onAppear {
            repairOrphanedInlineAIResponseIfNeeded()
            syncBlocks(body: bodyText)
        }
        // @State management only — text flush is handled by Coordinator's onPageFlush.
        .onChange(of: page.id) { _, _ in
            saveTask?.cancel()
            let body = Self.currentBody(for: page)
            bodyText = body
            lastPersistedBody = body
            repairOrphanedInlineAIResponseIfNeeded()
            syncBlocks(body: body)
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
            let fresh = Self.currentBody(for: page)
            bodyText = fresh
            lastPersistedBody = fresh
            repairOrphanedInlineAIResponseIfNeeded()
        }
        // Flush in-memory edits to disk when another editor is about to read our body
        // (e.g. transclusion edit on one of our blocks from a different note).
        .onReceive(
            NotificationCenter.default.publisher(for: NoteFileStorage.pageBodyWillRead)
        ) { notification in
            guard let requestId = notification.userInfo?["pageId"] as? String,
                  requestId == page.id else { return }
            stagePendingBodyForReadIfNeeded()
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
            let pageId = page.id
            let currentBody = bodyText
            page.applyInteractiveDerivedState(from: currentBody)
            _ = NoteFileStorage.scheduleWriteBody(pageId: pageId, content: currentBody)
            scheduleBlockMirrorSync(pageId: pageId, body: currentBody)
            Self.syncNoteTitleIfNeeded(
                from: currentBody,
                for: page,
                modelContext: modelContext
            ) { pageId, newTitle in
                vaultSync.renamePageFile(pageId: pageId, newTitle: newTitle)
            }
            lastPersistedBody = currentBody
            page.needsVaultSync = true
            try? modelContext.save()
        }
    }

    private func stagePendingBodyForReadIfNeeded() {
        saveTask?.cancel()
        guard lastPersistedBody != bodyText else { return }
        let pageId = page.id
        let currentBody = bodyText
        guard NoteFileStorage.scheduleWriteBody(pageId: pageId, content: currentBody) != nil else {
            return
        }
        lastPersistedBody = currentBody
    }

    private func repairOrphanedInlineAIResponseIfNeeded() {
        guard NoteWindowManager.shared.editorBody(for: page.id) == nil else { return }
        let persistedBody = NoteFileStorage.readBody(pageId: page.id, mapped: false)
        let sanitizedBody = Self.stripOrphanedInlineAIResponse(in: persistedBody, page: page)
        guard sanitizedBody != persistedBody else { return }

        let pageId = page.id
        page.applyInteractiveDerivedState(from: sanitizedBody)
        _ = NoteFileStorage.scheduleWriteBody(pageId: pageId, content: sanitizedBody)
        scheduleBlockMirrorSync(pageId: pageId, body: sanitizedBody)
        bodyText = sanitizedBody
        lastPersistedBody = sanitizedBody
        page.needsVaultSync = true
        try? modelContext.save()
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
            Self.syncNoteTitleIfNeeded(
                from: newValue,
                for: page,
                modelContext: modelContext
            ) { pageId, newTitle in
                vaultSync.renamePageFile(pageId: pageId, newTitle: newTitle)
            }
            page.applyInteractiveDerivedState(from: newValue)
            // File write FIRST — disk is source of truth. Must complete before
            // modelContext.save() so any @Query cascade reads correct content.
            await NoteFileStorage.writeBodyAsync(pageId: pageId, content: newValue)
            scheduleBlockMirrorSync(pageId: pageId, body: newValue)
            lastPersistedBody = newValue
            // Persist dirty flag AFTER file write. This ensures loadBody() returns
            // the new content if @Query refetch triggers view re-evaluation.
            page.needsVaultSync = true
            try? modelContext.save()
        }
    }

    // MARK: - Block Mirror

    /// Keep SwiftData blocks aligned with the current markdown body.
    private func syncBlocks(body: String) {
        scheduleBlockMirrorSync(pageId: page.id, body: body)
    }

    private func scheduleBlockMirrorSync(pageId: String, body: String) {
        guard !pageId.isEmpty,
              let modelContainer = AppBootstrap.shared?.modelContainer else { return }
        Task {
            await BlockMirrorSyncCoordinator.shared.scheduleSync(
                pageId: pageId,
                body: body,
                modelContainer: modelContainer
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
