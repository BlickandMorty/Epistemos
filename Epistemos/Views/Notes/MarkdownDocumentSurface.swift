import AppKit
import SwiftUI

enum MarkdownDocumentSurfacePerformancePolicy {
    static let autosaveQuietWindow: Duration = .seconds(2)
    static let reloadSamePageExternalMarkdown = false
}

@MainActor
final class MarkdownDocumentSurfaceSaveRegistry {
    static let shared = MarkdownDocumentSurfaceSaveRegistry()

    private struct Entry {
        let token: UUID
        let flush: @MainActor () async -> Bool
    }

    private var flushers: [String: Entry] = [:]

    private init() {}

    func register(
        pageId: String,
        token: UUID,
        flush: @escaping @MainActor () async -> Bool
    ) {
        flushers[pageId] = Entry(token: token, flush: flush)
    }

    func unregister(pageId: String, token: UUID) {
        guard flushers[pageId]?.token == token else { return }
        flushers.removeValue(forKey: pageId)
    }

    @discardableResult
    func flush(pageId: String) async -> Bool? {
        guard let entry = flushers[pageId] else { return nil }
        return await entry.flush()
    }

    func flushAllSurfaces() async -> Bool {
        let snapshot = flushers.sorted { $0.key < $1.key }
        var allSaved = true
        for (_, entry) in snapshot {
            if !(await entry.flush()) {
                allSaved = false
            }
        }
        return allSaved
    }
}

struct MarkdownDocumentSurface: View {
    let pageId: String
    let title: String
    let markdown: String
    let theme: EpistemosTheme
    let noteRelativePath: String
    let isEditable: Bool
    let isActive: Bool
    let provenanceStore: (any EditorProvenanceStoring)?
    let onEditStarted: @MainActor () -> Void
    let saveMarkdown: @Sendable @MainActor (String) async -> Bool
    let surfaceToolbarAccessory: AnyView?

    init(
        pageId: String,
        title: String,
        markdown: String,
        theme: EpistemosTheme,
        noteRelativePath: String? = nil,
        isEditable: Bool = true,
        isActive: Bool = true,
        provenanceStore: (any EditorProvenanceStoring)? = nil,
        onEditStarted: @escaping @MainActor () -> Void = {},
        saveMarkdown: @escaping @Sendable @MainActor (String) async -> Bool,
        surfaceToolbarAccessory: AnyView? = nil
    ) {
        self.pageId = pageId
        self.title = title
        self.markdown = markdown
        self.theme = theme
        self.noteRelativePath = noteRelativePath ?? pageId
        self.isEditable = isEditable
        self.isActive = isActive
        self.provenanceStore = provenanceStore
        self.onEditStarted = onEditStarted
        self.saveMarkdown = saveMarkdown
        self.surfaceToolbarAccessory = surfaceToolbarAccessory
    }

    @State private var coordinator = MarkdownDocumentSurfaceCoordinator()

    var body: some View {
        EpdocEditorChromeView(
            controller: coordinator.controller,
            surfaceToolbarAccessory: surfaceToolbarAccessory,
            assistContextProvider: {
                JuneEpdocAssistContext(
                    noteID: pageId,
                    title: title,
                    vaultRelativePath: noteRelativePath,
                    activeLens: "document",
                    markdown: coordinator.markdownForAssistContext(hostMarkdown: markdown),
                    selection: JuneEpdocAssistSelection(coordinator.controller.latestSelection)
                )
            }
            )
            .onAppear {
                coordinator.beginSurfaceAppearance()
                configureCoordinator()
            }
            .onChange(of: markdown) { _, _ in
                configureCoordinator()
            }
            .onChange(of: title) { _, newTitle in
                coordinator.updateTitle(newTitle)
            }
            .onChange(of: isActive) { _, _ in
                configureCoordinator()
            }
            .onDisappear {
                let coordinator = coordinator
                guard let registration = coordinator.currentSurfaceRegistration() else { return }
                Task { @MainActor in
                    await coordinator.flushPendingSurfaceWrites()
                    coordinator.unregisterSurface(registration)
                }
            }
    }

    @MainActor
    private func configureCoordinator() {
        coordinator.configure(
            pageId: pageId,
            title: title,
            markdown: markdown,
            theme: theme,
            noteRelativePath: noteRelativePath,
            isEditable: isEditable,
            isActive: isActive,
            provenanceStore: provenanceStore,
            onEditStarted: onEditStarted,
            saveMarkdown: saveMarkdown
        )
    }
}

@MainActor
@Observable
final class MarkdownDocumentSurfaceCoordinator {
    struct SurfaceRegistration: Equatable {
        let pageId: String
        let token: UUID
    }

    let controller = EpdocEditorChromeController()
    private var registryToken: UUID?
    private var renewRegistryTokenOnNextConfigure = false
    private var configuredPageId: String?
    private var latestMarkdown: String = ""
    private var lastFlushedMarkdown: String = ""
    private var saveTask: Task<Void, Never>?
    private var markdownRevision: UInt64 = 0
    private var markdownDebounceGeneration: UInt64 = 0
    private var markdownSaveWorkerGeneration: UInt64 = 0
    private var markdownWriteGeneration: UInt64 = 0
    private var markdownWriteCompletedGeneration: UInt64 = 0
    private var markdownWriteTail: Task<Bool, Never>?
    private var markdownFlushGeneration: UInt64 = 0
    private var markdownFlushTask: Task<Bool, Never>?
    private var isEditable = true
    private var isActive = true
    private var pendingExternalMarkdownReload: String?
    private var provenanceBridgeSink: EditorProvenanceBridgeSink?
    private var provenanceWriteTail: Task<Void, Never>?
    private var provenanceWriteGeneration = 0
    private var onEditStarted: @MainActor () -> Void = {}
    private var saveMarkdown: (@Sendable @MainActor (String) async -> Bool)?
    private var snapshotFlushWaiters: [CheckedContinuation<Bool, Never>] = []

    func configure(
        pageId: String,
        title: String,
        markdown: String,
        theme: EpistemosTheme,
        noteRelativePath: String,
        isEditable: Bool,
        isActive: Bool,
        provenanceStore: (any EditorProvenanceStoring)?,
        onEditStarted: @escaping @MainActor () -> Void = {},
        saveMarkdown: @escaping @Sendable @MainActor (String) async -> Bool
    ) {
        let wasActive = self.isActive
        let becameActive = !wasActive && isActive
        let isSwitchingConfiguredPage = configuredPageId != nil && configuredPageId != pageId
        if isSwitchingConfiguredPage {
            let hadPendingDebounce = saveTask != nil
            cancelMarkdownSaveWorker()
            if hadPendingDebounce
                || markdownWriteCompletedGeneration < markdownWriteGeneration
                || latestMarkdown != lastFlushedMarkdown
                || controller.toolbarModel.isDirty {
                _ = enqueueMarkdownWrite(latestMarkdown, revision: markdownRevision)
            }
            markdownRevision &+= 1
        }
        controller.theme = theme
        self.isEditable = isEditable
        self.isActive = isActive
        self.provenanceBridgeSink = provenanceStore.map {
            EditorProvenanceBridgeSink(store: $0, noteRelativePath: noteRelativePath)
        }
        self.onEditStarted = onEditStarted
        self.saveMarkdown = saveMarkdown
        if let configuredPageId,
           configuredPageId != pageId,
           let registryToken {
            MarkdownDocumentSurfaceSaveRegistry.shared.unregister(
                pageId: configuredPageId,
                token: registryToken
            )
        }
        if renewRegistryTokenOnNextConfigure {
            registryToken = UUID()
        }
        let activeRegistryToken = registryToken ?? UUID()
        registryToken = activeRegistryToken
        renewRegistryTokenOnNextConfigure = false
        MarkdownDocumentSurfaceSaveRegistry.shared.register(
            pageId: pageId,
            token: activeRegistryToken
        ) { [weak self] in
            await self?.flushPendingMarkdown() ?? false
        }
        controller.onMarkdownChanged = { [weak self] markdown, writeback in
            guard let self else { return }
            defer { self.resumeSnapshotFlushWaiters(receivedSnapshot: true) }
            guard self.isEditable == true else {
                self.controller.toolbarModel.isDirty = false
                return
            }
            self.onEditStarted()
            self.scheduleMarkdownSave(markdown, writeback: writeback)
        }
        controller.onSuggestionApplied = { [weak self] payload in
            self?.enqueueProvenanceWrite(
                failureMessage: "failed to persist suggestion span",
                id: payload.id
            ) { sink in
                try await sink.persistApplied(payload)
            }
        }
        controller.onSuggestionResolved = { [weak self] resolution in
            self?.enqueueProvenanceWrite(
                failureMessage: "failed to persist suggestion decision",
                id: resolution.suggestionID
            ) { sink in
                try await sink.persistResolved(resolution)
            }
        }
        controller.onSave = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if await self.flushPendingMarkdown() {
                    self.controller.toolbarModel.isDirty = false
                }
            }
        }
        controller.onShowProjectionInfo = {
            MarkdownDocumentProjectionInfoPresenter.present()
        }

        guard configuredPageId != pageId else {
            updateTitle(title)
            if isActive, let pending = pendingExternalMarkdownReload {
                pendingExternalMarkdownReload = nil
                latestMarkdown = pending
                lastFlushedMarkdown = pending
                controller.loadInitialContent(
                    Self.emptyDocumentJSON,
                    title: title,
                    markdownSource: pending
                )
                return
            }
            if shouldRecoverVisibleBlankOnReactivation(
                markdown: markdown,
                becameActive: becameActive
            ) {
                latestMarkdown = markdown
                lastFlushedMarkdown = markdown
                controller.loadInitialContent(
                    Self.emptyDocumentJSON,
                    title: title,
                    markdownSource: markdown
                )
                return
            }
            if shouldProbeVisibleMarkdownOnCleanReactivation(
                markdown: markdown,
                becameActive: becameActive
            ) {
                if controller.requestCleanReactivationMarkdownProbe(expectedMarkdown: markdown) {
                    return
                }
            }
            guard markdown != latestMarkdown,
                  latestMarkdown == lastFlushedMarkdown,
                  !controller.toolbarModel.isDirty else {
                return
            }
            let shouldRecoverCleanEmptyInitialLoad = isActive
                && visibleMarkdownSnapshotIsEmptyOverNonEmptyHost(markdown)
            latestMarkdown = markdown
            lastFlushedMarkdown = markdown
            if shouldRecoverCleanEmptyInitialLoad {
                controller.loadInitialContent(
                    Self.emptyDocumentJSON,
                    title: title,
                    markdownSource: markdown
                )
                return
            }
            if !isActive {
                pendingExternalMarkdownReload = markdown
                return
            }
            if pendingExternalMarkdownReload == markdown {
                pendingExternalMarkdownReload = nil
                controller.loadInitialContent(
                    Self.emptyDocumentJSON,
                    title: title,
                    markdownSource: markdown
                )
                return
            }
            guard MarkdownDocumentSurfacePerformancePolicy.reloadSamePageExternalMarkdown else {
                return
            }
            controller.loadInitialContent(
                Self.emptyDocumentJSON,
                title: title,
                markdownSource: markdown
            )
            return
        }

        configuredPageId = pageId
        pendingExternalMarkdownReload = nil
        latestMarkdown = markdown
        lastFlushedMarkdown = markdown
        controller.loadInitialContent(
            Self.emptyDocumentJSON,
            title: title,
            markdownSource: markdown
        )
    }

    private func shouldRecoverVisibleBlankOnReactivation(
        markdown: String,
        becameActive: Bool
    ) -> Bool {
        guard becameActive,
              !controller.toolbarModel.isDirty,
              controller.toolbarModel.characterCount == 0,
              !Self.markdownBodyIsEmpty(markdown) else {
            return false
        }

        guard let rememberedMarkdown = preferredNonEmptyRememberedMarkdown(hostMarkdown: markdown) else {
            return false
        }
        return rememberedMarkdown == markdown || latestMarkdown == markdown
    }

    private func shouldProbeVisibleMarkdownOnCleanReactivation(
        markdown: String,
        becameActive: Bool
    ) -> Bool {
        guard becameActive,
              !controller.toolbarModel.isDirty,
              !Self.markdownBodyIsEmpty(markdown) else {
            return false
        }

        guard let rememberedMarkdown = preferredNonEmptyRememberedMarkdown(hostMarkdown: markdown) else {
            return false
        }
        return rememberedMarkdown == markdown || latestMarkdown == markdown
    }

    private func preferredNonEmptyRememberedMarkdown(hostMarkdown: String) -> String? {
        [
            controller.latestMarkdownSnapshot,
            latestMarkdown,
            hostMarkdown,
        ]
        .compactMap { $0 }
        .first { !Self.markdownBodyIsEmpty($0) }
    }

    func markdownForAssistContext(hostMarkdown: String) -> String {
        Self.resolvedAssistContextMarkdown(
            hostMarkdown: hostMarkdown,
            latestSnapshot: controller.latestMarkdownSnapshot,
            latestMarkdown: latestMarkdown,
            isDirty: controller.toolbarModel.isDirty
        )
    }

    static func resolvedAssistContextMarkdown(
        hostMarkdown: String,
        latestSnapshot: String?,
        latestMarkdown: String,
        isDirty: Bool
    ) -> String {
        guard isDirty else { return hostMarkdown }
        return latestSnapshot ?? latestMarkdown
    }

    private func visibleMarkdownSnapshotIsEmptyOverNonEmptyHost(_ hostMarkdown: String) -> Bool {
        guard !Self.markdownBodyIsEmpty(hostMarkdown) else { return false }
        if let latestSnapshot = controller.latestMarkdownSnapshot {
            return Self.markdownBodyIsEmpty(latestSnapshot)
        }
        return Self.markdownBodyIsEmpty(latestMarkdown)
    }

    func beginSurfaceAppearance() {
        renewRegistryTokenOnNextConfigure = true
    }

    func currentSurfaceRegistration() -> SurfaceRegistration? {
        guard let configuredPageId, let registryToken else { return nil }
        return SurfaceRegistration(pageId: configuredPageId, token: registryToken)
    }

    func unregisterSurface(_ registration: SurfaceRegistration) {
        MarkdownDocumentSurfaceSaveRegistry.shared.unregister(
            pageId: registration.pageId,
            token: registration.token
        )
        if configuredPageId == registration.pageId,
           registryToken == registration.token {
            registryToken = nil
        }
    }

    func updateTitle(_ title: String) {
        controller.documentTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled"
            : title
    }

    func flushPendingMarkdown() async -> Bool {
        if let markdownFlushTask {
            let generation = markdownFlushGeneration
            let result = await markdownFlushTask.value
            if markdownFlushGeneration == generation {
                self.markdownFlushTask = nil
            }
            guard result else { return false }
            if hasPendingMarkdownWork {
                return await flushPendingMarkdown()
            }
            return true
        }
        markdownFlushGeneration &+= 1
        let generation = markdownFlushGeneration
        let task = Task { @MainActor [weak self] in
            await self?.performPendingMarkdownFlush() ?? false
        }
        markdownFlushTask = task
        let result = await task.value
        if markdownFlushGeneration == generation {
            markdownFlushTask = nil
        }
        guard result else { return false }
        if hasPendingMarkdownWork {
            return await flushPendingMarkdown()
        }
        return true
    }

    private var hasPendingMarkdownWork: Bool {
        saveTask != nil
            || markdownWriteCompletedGeneration < markdownWriteGeneration
            || controller.toolbarModel.isDirty
    }

    private func performPendingMarkdownFlush() async -> Bool {
        let hadPendingSave = saveTask != nil
        cancelMarkdownSaveWorker()
        let hadOutstandingWrite = markdownWriteCompletedGeneration < markdownWriteGeneration
        guard hadPendingSave || hadOutstandingWrite || controller.toolbarModel.isDirty else {
            return true
        }
        let hasPendingMarkdownSnapshot = latestMarkdown != lastFlushedMarkdown
        if !hasPendingMarkdownSnapshot {
            let usedDirectSnapshot = await requestCurrentMarkdownSnapshotFromEditor()
            let receivedBridgeSnapshot = usedDirectSnapshot ? false : await requestFreshMarkdownSnapshotIfPossible()
            cancelMarkdownSaveWorker()
            guard usedDirectSnapshot || receivedBridgeSnapshot || !controller.toolbarModel.isDirty else {
                return false
            }
        }
        for _ in 0..<3 {
            cancelMarkdownSaveWorker()
            let hasOutstandingWrite = markdownWriteCompletedGeneration < markdownWriteGeneration
            if latestMarkdown == lastFlushedMarkdown, !hasOutstandingWrite {
                controller.toolbarModel.isDirty = false
                return true
            }
            let revision = markdownRevision
            let markdownToFlush = latestMarkdown
            let saved = await enqueueMarkdownWrite(
                markdownToFlush,
                revision: revision
            ).value
            guard saved else { return false }
            if markdownRevision == revision,
               latestMarkdown == markdownToFlush,
               lastFlushedMarkdown == markdownToFlush,
               markdownWriteCompletedGeneration == markdownWriteGeneration {
                return true
            }
        }
        return false
    }

    func flushPendingProvenanceWrites() async {
        let generation = provenanceWriteGeneration
        let tail = provenanceWriteTail
        await tail?.value
        if provenanceWriteGeneration == generation {
            provenanceWriteTail = nil
        }
    }

    @discardableResult
    func flushPendingSurfaceWrites() async -> Bool {
        let markdownSaved = await flushPendingMarkdown()
        await flushPendingProvenanceWrites()
        return markdownSaved
    }

    private func requestCurrentMarkdownSnapshotFromEditor() async -> Bool {
        guard let freshMarkdown = await controller.currentMarkdownSnapshotFromEditor() else {
            return false
        }
        if Self.markdownBodyIsEmpty(freshMarkdown),
           !Self.markdownBodyIsEmpty(latestMarkdown) {
            Log.notes.error(
                "MarkdownDocumentSurface: ignored empty direct editor snapshot over non-empty Markdown source"
            )
            return false
        }
        if freshMarkdown != latestMarkdown {
            if controller.toolbarModel.isDirty {
                onEditStarted()
            }
            markdownRevision &+= 1
        }
        latestMarkdown = freshMarkdown
        return true
    }

    private func requestFreshMarkdownSnapshotIfPossible() async -> Bool {
        await withCheckedContinuation { continuation in
            snapshotFlushWaiters.append(continuation)
            guard controller.requestDocumentSnapshotFlush() else {
                resumeSnapshotFlushWaiters(receivedSnapshot: false)
                return
            }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(450))
                self?.resumeSnapshotFlushWaiters(receivedSnapshot: false)
            }
        }
    }

    private func resumeSnapshotFlushWaiters(receivedSnapshot: Bool) {
        let waiters = snapshotFlushWaiters
        snapshotFlushWaiters.removeAll()
        waiters.forEach { $0.resume(returning: receivedSnapshot) }
    }

    private func enqueueProvenanceWrite(
        failureMessage: String,
        id: String,
        operation: @escaping @Sendable (EditorProvenanceBridgeSink) async throws -> Void
    ) {
        guard let sink = provenanceBridgeSink else { return }
        provenanceWriteGeneration += 1
        let previous = provenanceWriteTail
        let task = Task {
            await previous?.value
            do {
                try await operation(sink)
            } catch {
                Log.notes.error(
                    "MarkdownDocumentSurface: \(failureMessage, privacy: .public) \(id, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        provenanceWriteTail = task
    }

    private func scheduleMarkdownSave(_ markdown: String, writeback: EpdocMarkdownWritebackRegion?) {
        let markdownToSave = writeback
            .flatMap { Self.apply(writeback: $0, to: latestMarkdown) }
            ?? markdown
        markdownRevision &+= 1
        latestMarkdown = markdownToSave
        markdownDebounceGeneration &+= 1
        guard saveTask == nil else { return }
        markdownSaveWorkerGeneration &+= 1
        let workerGeneration = markdownSaveWorkerGeneration
        saveTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.markdownSaveWorkerGeneration == workerGeneration {
                    self.saveTask = nil
                }
            }
            while !Task.isCancelled {
                let debounceGeneration = self.markdownDebounceGeneration
                try? await Task.sleep(for: MarkdownDocumentSurfacePerformancePolicy.autosaveQuietWindow)
                guard !Task.isCancelled else { break }
                guard debounceGeneration == self.markdownDebounceGeneration else { continue }
                let markdownToSave = self.latestMarkdown
                let revision = self.markdownRevision
                guard markdownToSave != self.lastFlushedMarkdown else { break }
                _ = await self.enqueueMarkdownWrite(
                    markdownToSave,
                    revision: revision
                ).value
                guard !Task.isCancelled else { break }
                guard debounceGeneration != self.markdownDebounceGeneration else { break }
            }
        }
    }

    private func cancelMarkdownSaveWorker() {
        markdownDebounceGeneration &+= 1
        markdownSaveWorkerGeneration &+= 1
        saveTask?.cancel()
        saveTask = nil
    }

    @discardableResult
    private func enqueueMarkdownWrite(
        _ markdown: String,
        revision: UInt64
    ) -> Task<Bool, Never> {
        guard let saveMarkdown else {
            return Task { false }
        }
        let pageId = configuredPageId
        let predecessor = markdownWriteTail
        markdownWriteGeneration &+= 1
        let writeGeneration = markdownWriteGeneration
        let task = Task { @MainActor [weak self] in
            if let predecessor {
                _ = await predecessor.value
            }
            let saved = await saveMarkdown(markdown)
            guard let self else { return saved }
            self.markdownWriteCompletedGeneration = max(
                self.markdownWriteCompletedGeneration,
                writeGeneration
            )
            guard self.configuredPageId == pageId else { return saved }
            guard saved else {
                self.controller.toolbarModel.isDirty = true
                return false
            }
            self.lastFlushedMarkdown = markdown
            if self.markdownRevision == revision {
                self.controller.toolbarModel.isDirty = false
            } else {
                self.controller.toolbarModel.isDirty = true
            }
            return true
        }
        markdownWriteTail = task
        return task
    }

    private static func apply(writeback: EpdocMarkdownWritebackRegion, to markdown: String) -> String? {
        guard writeback.codeUnitFrom <= writeback.codeUnitTo else { return nil }

        let utf16 = markdown.utf16
        guard let fromUTF16 = utf16.index(
                utf16.startIndex,
                offsetBy: writeback.codeUnitFrom,
                limitedBy: utf16.endIndex
              ),
              let toUTF16 = utf16.index(
                utf16.startIndex,
                offsetBy: writeback.codeUnitTo,
                limitedBy: utf16.endIndex
              ),
              fromUTF16 <= toUTF16,
              let start = fromUTF16.samePosition(in: markdown),
              let end = toUTF16.samePosition(in: markdown) else {
            return nil
        }

        let byteFrom = markdown[..<start].utf8.count
        let byteTo = markdown[..<end].utf8.count
        guard byteFrom == writeback.byteFrom,
              byteTo == writeback.byteTo else {
            return nil
        }

        return String(markdown[..<start])
            + writeback.blockMarkdown
            + String(markdown[end...])
    }

    private static func markdownBodyIsEmpty(_ markdown: String) -> Bool {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else {
            return trimmed.isEmpty
        }

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first.map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) }) == "---" else {
            return trimmed.isEmpty
        }
        guard let closingIndex = lines.dropFirst().firstIndex(where: {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines) == "---"
        }) else {
            return trimmed.isEmpty
        }
        let body = lines.dropFirst(closingIndex + 1).joined(separator: "\n")
        return body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static let emptyDocumentJSON = Data(
        #"{"type":"doc","content":[{"type":"paragraph"}]}"#.utf8
    )
}

@MainActor
private enum MarkdownDocumentProjectionInfoPresenter {
    static func present() {
        let alert = NSAlert()
        alert.messageText = "Markdown Document Surface"
        alert.informativeText = """
        This Document view is another editor surface for the same Markdown note. It projects the .md body into rich blocks for editing, then saves Markdown back to the vault path used by Prose, Preview, and Source.

        The projection does not turn this note into a separate package.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
