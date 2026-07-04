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

enum ProseEditorNavigationContext {
    case notes
    case graph
}

enum LegacyInlineNoteResponse {
    nonisolated static let divider = "\n\n<!-- ai-response -->\n\n"

    nonisolated static func dividerRange(in text: String) -> Range<String.Index>? {
        text.range(of: divider, options: .backwards)
    }
}

struct ProseEditorView: View {
    private static let log = Logger(subsystem: "com.epistemos", category: "ProseEditorView")
    let page: SDPage
    var isEditable: Bool = true
    let initialBodyOverride: String?
    let navigationContext: ProseEditorNavigationContext
    let themeOverride: EpistemosTheme?

    @Environment(\.modelContext) private var modelContext
    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(NoteNavigationState.self) private var navState: NoteNavigationState?
    @Environment(GraphState.self) private var graphState

    @State private var bodyText: String = ""
    /// Snapshot of the last body persisted to disk. Avoids disk reads on every keystroke.
    @State private var lastPersistedBody: String = ""
    @State private var loadedBodyPageId: String?
    @State private var isFocused = true
    @State private var saveTask: Task<Void, Never>?
    @State private var draftTask: Task<Void, Never>?  // NOTE-4: crash-recovery draft debounce
    // noteReadAloud (owner 2026-06-20): one-shot guard so an opened note is auto-read at most once
    // (onAppear can re-fire on navigation; onChange fires on switch) — never re-read on re-render.
    @State private var lastAutoReadNoteId: String?

    init(
        page: SDPage,
        isEditable: Bool = true,
        initialBodyOverride: String? = nil,
        navigationContext: ProseEditorNavigationContext = .notes,
        themeOverride: EpistemosTheme? = nil
    ) {
        self.page = page
        self.isEditable = isEditable
        self.initialBodyOverride = initialBodyOverride
        self.navigationContext = navigationContext
        self.themeOverride = themeOverride
        if let initialBodyOverride {
            let body = Self.stripOrphanedInlineAIResponse(in: initialBodyOverride, page: page)
            _bodyText = State(initialValue: body)
            _lastPersistedBody = State(initialValue: body)
            _loadedBodyPageId = State(initialValue: page.id)
        }
    }

    static func initialBodySnapshot(for page: SDPage) -> (bodyText: String, lastPersistedBody: String) {
        initialBodySnapshot(for: page, preferredBody: nil)
    }

    static func initialBodySnapshot(for page: SDPage, preferredBody: String? = nil) -> (bodyText: String, lastPersistedBody: String) {
        let body = stripOrphanedInlineAIResponse(in: preferredBody ?? page.body, page: page)
        return (body, body)
    }

    /// noteReadAloud (owner 2026-06-20) — wire the previously do-nothing "auto-read long notes on
    /// open" voice toggle. Called on note open (onAppear + onChange of page.id), one-shot per
    /// note-id so a re-render never re-reads. Gated on .auto (default .manual = off) and a long
    /// note (>500 chars, per the Settings rationale). Speaks the inline-markdown-stripped body so
    /// the synthesizer doesn't read raw `**` / `[]()` syntax aloud.
    private func maybeAutoReadAloudOnOpen(noteId: String, body: String) {
        guard lastAutoReadNoteId != noteId else { return }
        lastAutoReadNoteId = noteId
        guard VoicePreferences.shared.noteReadAloud == .auto, body.count > 500 else { return }
        _ = EpistemosSpeechSynthesizer.shared.speak(MarkdownRippleTextExtractor.displayText(from: body))
    }

    private static func stripOrphanedInlineAIResponse(in body: String, page: SDPage) -> String {
        stripOrphanedInlineAIResponse(in: body, pageId: page.id, pageTitle: page.title)
    }

    private static func stripOrphanedInlineAIResponse(in body: String, pageId: String, pageTitle: String) -> String {
        guard let dividerRange = LegacyInlineNoteResponse.dividerRange(in: body) else { return body }
        let title = pageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = title.isEmpty ? pageId : title
        log.warning("Found orphaned AI divider in note \(resolvedTitle, privacy: .public) — stripping")
        return String(body[..<dividerRange.lowerBound])
    }

    private func loadBodyIfNeeded(force: Bool) async {
        let pageId = page.id
        let pageTitle = page.title
        let fallbackBody = page.body
        guard force || loadedBodyPageId != pageId else { return }

        let rawBody: String
        let shouldPersistInlineRepair: Bool
        if let initialBodyOverride {
            rawBody = initialBodyOverride
            shouldPersistInlineRepair = false
        } else if let liveBody = NoteWindowManager.shared.editorBody(for: pageId) {
            rawBody = liveBody
            shouldPersistInlineRepair = false
        } else {
            let loadedBody = await Task.detached(priority: .userInitiated) {
                NoteFileStorage.readBody(pageId: pageId, mapped: false, fast: true)
            }.value
            rawBody = loadedBody.isEmpty ? fallbackBody : loadedBody
            shouldPersistInlineRepair = true
        }

        guard !Task.isCancelled, page.id == pageId else { return }
        let sanitizedBody = Self.stripOrphanedInlineAIResponse(
            in: rawBody,
            pageId: pageId,
            pageTitle: pageTitle
        )
        // NOTE-2 companion: skip a no-op reload — if the reloaded body already matches what's
        // in this editor for this page, don't re-apply it (which would reset cursor/undo/
        // blocks). Keep lastPersistedBody synced so dirty-detection stays correct. This lets
        // the saving editor safely ignore its own pageBodyDidChange post.
        if loadedBodyPageId == pageId, sanitizedBody == bodyText {
            lastPersistedBody = sanitizedBody
            return
        }
        bodyText = sanitizedBody
        lastPersistedBody = sanitizedBody
        loadedBodyPageId = pageId
        syncBlocks(body: sanitizedBody)
        maybeAutoReadAloudOnOpen(noteId: pageId, body: sanitizedBody)
        if shouldPersistInlineRepair {
            persistOrphanedInlineAIRepair(rawBody: rawBody, sanitizedBody: sanitizedBody)
        }
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
        let originalTitle = page.title
        let originalUpdatedAt = page.updatedAt
        let originalNeedsVaultSync = page.needsVaultSync
        page.title = syncedTitle
        page.updatedAt = .now
        page.needsVaultSync = true
        do {
            try modelContext.save()
        } catch {
            page.title = originalTitle
            page.updatedAt = originalUpdatedAt
            page.needsVaultSync = originalNeedsVaultSync
            log.error(
                "ProseEditorView: failed to save synced note title for \(page.id, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
        if shouldRenameBackedFile(for: page) {
            renamePageFile(page.id, syncedTitle)
        }
        return true
    }

    private static func shouldRenameBackedFile(for page: SDPage) -> Bool {
        true
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
            guard Self.stageBodyWrite(pageId: oldPageId, currentBody: currentText, reason: "flush callback") else {
                return
            }
            scheduleBlockMirrorSync(pageId: oldPageId, body: currentText)
            let desc = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == oldPageId }
            )
            do {
                guard let oldPage = try modelContext.fetch(desc).first else {
                    Self.log.error("ProseEditorView: failed to fetch flushed page \(oldPageId, privacy: .public)")
                    return
                }
                oldPage.applyInteractiveDerivedState(from: currentText)
                Self.syncNoteTitleIfNeeded(
                    from: currentText,
                    for: oldPage,
                    modelContext: modelContext
                ) { pageId, newTitle in
                    vaultSync.renamePageFile(pageId: pageId, newTitle: newTitle)
                }
                oldPage.needsVaultSync = true
                saveModelContext(reason: "flush for page \(oldPageId)")
            } catch {
                Self.log.error(
                    "ProseEditorView: failed to fetch flushed page \(oldPageId, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        Group {
            if loadedBodyPageId == page.id {
                ProseEditorRepresentable2(
                    text: $bodyText,
                    pageId: page.id,
                    pageBody: bodyText,
                    isFocused: isFocused,
                    theme: themeOverride ?? ui.theme,
                    themeSyncKey: ui.appearanceSyncKey,
                    isEditable: isEditable,
                    isFocusMode: notesUI.isFocusMode,
                    modelContext: modelContext,
                    onWikilinkClick: handleWikilinkClick,
                    onBlockRefClick: handleBlockRefClick,
                    onPageFlush: flush,
                    graphState: graphState,
                    outlineFoldMode: notesUI.outlineFoldMode,
                    usesTransparentEditorBackground: navigationContext == .graph
                )
                .onAppear {
                    syncBlocks(body: bodyText)
                    maybeAutoReadAloudOnOpen(noteId: page.id, body: bodyText)
                }
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: page.id) {
            await loadBodyIfNeeded(force: false)
        }
        // @State management only — text flush is handled by Coordinator's onPageFlush.
        .onChange(of: page.id) { _, _ in
            saveTask?.cancel()
            loadedBodyPageId = nil
            Task { @MainActor in
                await loadBodyIfNeeded(force: true)
            }
        }
        .onChange(of: bodyText) { _, newValue in
            guard loadedBodyPageId == page.id else { return }
            guard newValue != lastPersistedBody else { return }
            debouncedSave(newValue)
            scheduleDraftWrite(newValue)  // NOTE-4: crash-recovery draft on a shorter debounce
        }
        // Detect external body changes (restore-to-version, vault sync, etc.)
        // page.body is always "" for migrated notes, so it's useless as a change signal.
        // Instead, listen for an explicit notification keyed by pageId.
        .onReceive(
            NotificationCenter.default.publisher(for: NoteFileStorage.pageBodyDidChange)
        ) { notification in
            guard let changedId = notification.userInfo?["pageId"] as? String,
                  changedId == page.id else { return }
            // NOTE-3 (audit): a background external change (vault sync) must NOT clobber the
            // user's UNSAVED in-memory edits. Reload only when the editor is clean (or not
            // loaded); if it's dirty, keep the user's live edits and defer the external change
            // (it reapplies once they save/close). Prevents silent loss of active typing.
            // Trade-off: an external edit to the ACTIVELY-edited note loses to the open editor
            // — the right default for a single user; a conflict indicator is a follow-up.
            let editorIsClean = loadedBodyPageId != page.id || bodyText == lastPersistedBody
            if editorIsClean {
                saveTask?.cancel()
                loadedBodyPageId = nil
                Task { @MainActor in
                    await loadBodyIfNeeded(force: true)
                }
            } else {
                Self.log.warning("NOTE-3: external body change for \(page.id, privacy: .public) deferred — editor has unsaved edits")
            }
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
            // NOTE-1 (audit 2026-07-03): flushIfNeeded only STAGES the body + schedules an
            // async detached write, which process exit can kill on Cmd-Q — losing a typing
            // burst. Persist this editor's current body SYNCHRONOUSLY here so the last edits
            // survive quit regardless of teardown-observer ordering (the app delegate
            // registers before these views, so the performTeardown drain can run first).
            // writeBody is idempotent, so this is safe even if already persisted.
            draftTask?.cancel()
            if loadedBodyPageId == page.id {
                NoteFileStorage.writeBody(pageId: page.id, content: bodyText)
                NoteDraftStore.delete(pageId: page.id)  // NOTE-4: clean quit persisted the body; clear the draft
            }
        }
    }

    private func flushIfNeeded() {
        saveTask?.cancel()
        guard loadedBodyPageId == page.id else { return }
        if lastPersistedBody != bodyText {
            let pageId = page.id
            let currentBody = bodyText
            guard Self.stageBodyWrite(pageId: pageId, currentBody: currentBody, reason: "flushIfNeeded") else {
                return
            }
            page.applyInteractiveDerivedState(from: currentBody)
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
            saveModelContext(reason: "flushIfNeeded for page \(pageId)")
        }
    }

    private func stagePendingBodyForReadIfNeeded() {
        saveTask?.cancel()
        guard loadedBodyPageId == page.id else { return }
        guard lastPersistedBody != bodyText else { return }
        let pageId = page.id
        let currentBody = bodyText
        guard Self.stageBodyWrite(pageId: pageId, currentBody: currentBody, reason: "stagePendingBodyForReadIfNeeded") else {
            return
        }
        lastPersistedBody = currentBody
    }

    private func persistOrphanedInlineAIRepair(rawBody: String, sanitizedBody: String) {
        guard sanitizedBody != rawBody else { return }
        let pageId = page.id
        guard Self.stageBodyWrite(pageId: pageId, currentBody: sanitizedBody, reason: "inline AI repair") else {
            return
        }
        page.applyInteractiveDerivedState(from: sanitizedBody)
        scheduleBlockMirrorSync(pageId: pageId, body: sanitizedBody)
        bodyText = sanitizedBody
        lastPersistedBody = sanitizedBody
        page.needsVaultSync = true
        saveModelContext(reason: "orphaned inline AI repair for page \(pageId)")
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
            guard await NoteFileStorage.writeBodyAsync(pageId: pageId, content: newValue) else {
                Self.log.error("Failed to persist editor body for \(pageId, privacy: .public); keeping model state unchanged")
                return
            }
            scheduleBlockMirrorSync(pageId: pageId, body: newValue)
            lastPersistedBody = newValue
            NoteDraftStore.delete(pageId: pageId)  // NOTE-4: durable body is current; clear the crash draft
            // Persist dirty flag AFTER file write. This ensures loadBody() returns
            // the new content if @Query refetch triggers view re-evaluation.
            page.needsVaultSync = true
            saveModelContext(reason: "debounced save for page \(pageId)")
        }
    }

    /// NOTE-4 (audit 2026-07-03): write a lightweight crash-recovery draft on a shorter
    /// debounce than the 5s durable save, so a HARD crash (no willTerminate fires) loses
    /// at most ~1.5s of edits. The draft is deleted once the durable body catches up
    /// (debouncedSave / quit); any surviving draft is reconciled at next launch.
    private func scheduleDraftWrite(_ newValue: String) {
        draftTask?.cancel()
        let pageId = page.id
        draftTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            NoteDraftStore.write(pageId: pageId, body: newValue)
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

    @discardableResult
    private static func stageBodyWrite(pageId: String, currentBody: String, reason: String) -> Bool {
        guard NoteFileStorage.scheduleWriteBody(pageId: pageId, content: currentBody) != nil else {
            log.error(
                "ProseEditorView: failed to stage body write for \(reason, privacy: .public) on page \(pageId, privacy: .public)"
            )
            return false
        }
        return true
    }

    // MARK: - Wikilink Navigation

    private func handleWikilinkClick(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let localHeading = WikilinkResolver.localHeadingTitle(forDestination: trimmed) {
            scrollToLocalWikilinkHeading(localHeading)
            return
        }

        guard !trimmed.isEmpty,
              let destination = WikilinkResolver.canonicalDestination(trimmed),
              let displayTitle = WikilinkResolver.displayTitle(forDestination: trimmed)
        else { return }

        switch existingPageForWikilink(destination: destination, displayTitle: displayTitle) {
        case .found(let existing):
            navigateToPage(existing)
        case .notFound:
            Task {
                if let newId = await vaultSync.createPage(
                    title: displayTitle,
                    allowVaultSelectionPrompt: true
                ) {
                    if navigationContext == .graph {
                        graphState.openNote(newId)
                    } else if let navState {
                        navState.push(pageId: newId, title: displayTitle)
                    } else {
                        NoteWindowManager.shared.open(pageId: newId)
                    }
                }
            }
        case .failed:
            return
        }
    }

    private func scrollToLocalWikilinkHeading(_ headingTitle: String) {
        let normalizedHeading = normalizedLocalWikilinkHeading(headingTitle)
        guard !normalizedHeading.isEmpty else { return }

        let headings = TOCParser.parse(bodyText)
        guard let target = headings.first(where: {
            $0.kind == .heading
                && normalizedLocalWikilinkHeading($0.title) == normalizedHeading
        }) else {
            return
        }

        NotificationCenter.default.post(
            name: ProseTextView2.scrollToOffsetNotification,
            object: nil,
            userInfo: [
                "pageId": page.id,
                "charOffset": target.charOffset,
            ]
        )
    }

    private func normalizedLocalWikilinkHeading(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }

    /// Navigate to an existing page — in-place via navState if available, new tab otherwise.
    private func navigateToPage(_ target: SDPage) {
        let pageTitle = target.title.isEmpty ? "Untitled" : target.title
        // Skip if navigating to the current page
        guard target.id != page.id else { return }
        if navigationContext == .graph {
            graphState.openNote(target.id)
        } else if let navState {
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
        let block: SDBlock
        do {
            guard let fetchedBlock = try modelContext.fetch(descriptor).first else { return }
            block = fetchedBlock
        } catch {
            Self.log.error(
                "ProseEditorView: failed to fetch block reference \(blockId, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return
        }
        // Skip if block is on the current page
        guard block.pageId != page.id else { return }

        // Look up the page title for the breadcrumb
        let targetPageId = block.pageId
        let pageDesc = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == targetPageId }
        )
        let title: String
        do {
            title = try modelContext.fetch(pageDesc).first?.title ?? "Untitled"
        } catch {
            Self.log.error(
                "ProseEditorView: failed to fetch block target page \(targetPageId, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            title = "Untitled"
        }
        if navigationContext == .graph {
            graphState.openNote(block.pageId)
        } else if let navState {
            navState.push(pageId: block.pageId, title: title)
        } else {
            NoteWindowManager.shared.open(pageId: block.pageId)
        }
    }

    private enum WikilinkLookupResult {
        case found(SDPage)
        case notFound
        case failed
    }

    private func existingPageForWikilink(destination: String, displayTitle: String) -> WikilinkLookupResult {
        do {
            // Fast exact-title path for common local notes.
            let exactDescriptor = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.title == displayTitle }
            )
            if let existing = try modelContext.fetch(exactDescriptor).first {
                return .found(existing)
            }

            let allPages = try modelContext.fetch(FetchDescriptor<SDPage>())
            let targetKeys = WikilinkResolver.lookupKeys(forDestination: destination)
            var lookup: [String: SDPage] = [:]
            var ambiguous = Set<String>()
            for page in allPages {
                for key in WikilinkResolver.lookupKeysForPage(
                    title: page.title,
                    filePath: page.filePath,
                    vaultRelativePath: page.vaultRelativeNotePath
                ) {
                    if let existing = lookup[key], existing.id != page.id {
                        lookup.removeValue(forKey: key)
                        ambiguous.insert(key)
                    } else if !ambiguous.contains(key) {
                        lookup[key] = page
                    }
                }
            }

            if let match = targetKeys.compactMap({ lookup[$0] }).first {
                return .found(match)
            }

            return .notFound
        } catch {
            Self.log.error(
                "ProseEditorView: failed to fetch wikilink target \(displayTitle, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return .failed
        }
    }

    private func saveModelContext(reason: String) {
        do {
            try modelContext.save()
        } catch {
            Self.log.error(
                "ProseEditorView: failed to save \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
