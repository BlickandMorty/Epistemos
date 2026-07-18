import AppKit
import Foundation
import SwiftData
import os

// MARK: - Welcome Back Info
// Shown on the landing page after workspace auto-restore. Contains the AI summary,
// user note, and activity stats from the previous session.

struct WelcomeBackInfo {
    var intentSummary: String   // AI narrative (serif italic)
    var userNote: String        // User's note (pin icon)
    var noteCount: Int
    var chatCount: Int
    var graphWasOpen: Bool
    var sessionMinutes: Int
    var editedNoteTitles: [String]

    static func cleanedSummaryText(from raw: String) -> String {
        UserFacingModelOutput.finalVisibleText(from: raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var sanitizedIntentSummary: String {
        guard ProductCapabilityPolicy.allowsAIOutputPresentation else { return "" }
        return UserFacingModelOutput.finalVisibleText(from: intentSummary)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var presentedChatCount: Int? {
        ProductCapabilityPolicy.allowsChatPresentation ? chatCount : nil
    }

    var spokenSessionSummary: String {
        var parts = ["\(noteCount) notes"]
        if let presentedChatCount {
            parts.append("\(presentedChatCount) chats")
        }
        parts.append("graph \(graphWasOpen ? "open" : "off")")
        parts.append("\(sessionMinutes) minute session")
        return parts.joined(separator: ", ") + "."
    }

    /// Structured display text for the typewriter animation.
    var displayText: String {
        var sections: [String] = []

        let note = Self.cleanedDisplayLine(userNote)
        if !note.isEmpty {
            sections.append("Pinned Note\n- \(note)")
        }

        let points = summaryBulletPoints()
        if let resumePoint = points.first {
            sections.append("Resume Point\n- \(resumePoint)")
        } else {
            sections.append("Resume Point\n- Your workspace is ready.")
        }

        let workingMemory = Array(points.dropFirst().prefix(6))
        if !workingMemory.isEmpty {
            sections.append(
                "Working Memory\n" + workingMemory.map { "- \($0)" }.joined(separator: "\n")
            )
        }

        let restored = restoredSurfaceLines()
        if !restored.isEmpty {
            sections.append(
                "Restored Surface\n" + restored.map { "- \($0)" }.joined(separator: "\n")
            )
        }

        let recentTitles = editedNoteTitles
            .map(Self.cleanedDisplayLine)
            .filter { !$0.isEmpty }
        if !recentTitles.isEmpty {
            sections.append(
                "Recently Touched\n" + recentTitles.prefix(5).map { "- \($0)" }.joined(separator: "\n")
            )
        }

        return sections.joined(separator: "\n\n")
    }

    private func summaryBulletPoints() -> [String] {
        guard !sanitizedIntentSummary.isEmpty else { return [] }

        var points: [String] = []
        var seen = Set<String>()

        for rawLine in sanitizedIntentSummary.components(separatedBy: .newlines) {
            for candidate in Self.splitDenseSummaryLine(rawLine) {
                let cleaned = Self.cleanedSummaryPoint(candidate)
                guard !cleaned.isEmpty else { continue }

                let key = cleaned.lowercased()
                guard seen.insert(key).inserted else { continue }
                points.append(Self.truncatedDisplayLine(cleaned, maxLength: 180))
                if points.count >= 8 {
                    return points
                }
            }
        }

        return points
    }

    private func restoredSurfaceLines() -> [String] {
        var lines: [String] = []

        if noteCount > 0 {
            lines.append("\(noteCount) note\(noteCount == 1 ? "" : "s") restored")
        }
        if let presentedChatCount, presentedChatCount > 0 {
            lines.append("\(presentedChatCount) chat\(presentedChatCount == 1 ? "" : "s") restored")
        }
        if graphWasOpen {
            lines.append("Knowledge graph was open")
        }
        if sessionMinutes > 0 {
            lines.append("Previous session ran \(sessionMinutes) minute\(sessionMinutes == 1 ? "" : "s")")
        }

        return lines
    }

    private static func splitDenseSummaryLine(_ raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 220 else { return [trimmed] }

        let sentences = trimmed.components(separatedBy: ". ")
        guard sentences.count > 1 else { return [trimmed] }

        return sentences.map { sentence in
            var text = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty,
               !text.hasSuffix("."),
               !text.hasSuffix(":"),
               !text.hasSuffix("?"),
               !text.hasSuffix("!") {
                text += "."
            }
            return text
        }
    }

    private static func cleanedSummaryPoint(_ raw: String) -> String {
        var text = cleanedDisplayLine(raw)
        while text.hasPrefix("#") {
            text.removeFirst()
            text = cleanedDisplayLine(text)
        }

        let bulletPrefixes = ["- ", "* ", "+ ", "> "]
        var didStrip = true
        while didStrip {
            didStrip = false
            for prefix in bulletPrefixes where text.hasPrefix(prefix) {
                text.removeFirst(prefix.count)
                text = cleanedDisplayLine(text)
                didStrip = true
            }
        }

        if let range = text.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
            text.removeSubrange(range)
            text = cleanedDisplayLine(text)
        }

        if text.hasSuffix(":"), text.count < 72 {
            return ""
        }

        return text
    }

    private static func cleanedDisplayLine(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func truncatedDisplayLine(_ raw: String, maxLength: Int) -> String {
        guard raw.count > maxLength else { return raw }
        let end = raw.index(raw.startIndex, offsetBy: maxLength)
        return raw[..<end].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

// MARK: - Workspace Diff Summary

struct WorkspaceDiffSummary {
    var notesOpened: Int = 0
    var notesClosed: Int = 0
    var wordCountDeltas: [(title: String, delta: Int)] = []
    var chatsStarted: Int = 0
    var chatMessagesSent: Int = 0
    var graphNodesAdded: Int = 0

    var hasChanges: Bool {
        notesOpened > 0 || notesClosed > 0 || !wordCountDeltas.isEmpty
            || chatsStarted > 0 || chatMessagesSent > 0 || graphNodesAdded > 0
    }

    var presentedChatActivity: (started: Int, messagesSent: Int) {
        guard ProductCapabilityPolicy.allowsChatPresentation else {
            return (started: 0, messagesSent: 0)
        }
        return (started: chatsStarted, messagesSent: chatMessagesSent)
    }

    var hasPresentedChanges: Bool {
        notesOpened > 0 || notesClosed > 0 || !wordCountDeltas.isEmpty
            || presentedChatActivity.started > 0 || presentedChatActivity.messagesSent > 0
            || graphNodesAdded > 0
    }
}

enum WorkspaceSynthesisBuilder {
    static func title(for snapshot: WorkspaceSnapshot) -> String {
        if let activeDocument = snapshot.liveDocuments?.first(where: \.isActive) {
            return "Last Session - \(activeDocument.title)"
        }
        if snapshot.graphOverlay.visibility != .hidden {
            return "Last Session - Graph"
        }
        return "Last Session"
    }

    static func summary(for snapshot: WorkspaceSnapshot) -> String {
        var lines: [String] = []
        let documents = snapshot.liveDocuments ?? []
        let activeDocument = documents.first(where: \.isActive)

        var opening: [String] = []
        if let activeDocument {
            opening.append("Active focus: \(activeDocument.title)")
        }
        if !documents.isEmpty {
            opening.append("\(documents.count) live document\(documents.count == 1 ? "" : "s")")
        }
        if let graphRoute = snapshot.graphRoute {
            switch graphRoute.kind {
            case .canvas:
                if snapshot.graphOverlay.visibility != .hidden {
                    opening.append("graph canvas open")
                }
            case .note:
                opening.append("graph note open")
            case .folder:
                opening.append("graph folder open")
            }
        }
        if !opening.isEmpty {
            lines.append(opening.joined(separator: " · "))
        }

        if !documents.isEmpty {
            lines.append("Open document state:")
            for document in documents.prefix(8) {
                var detail = "- \(document.title) [\(document.source)] \(document.lineCount) lines, \(document.wordCount) words"
                if document.isActive {
                    detail += " (active)"
                }
                detail += "."
                if !document.preview.isEmpty {
                    detail += " Opening: \(document.preview)"
                }
                if !document.tailPreview.isEmpty, document.tailPreview != document.preview {
                    detail += " Latest: \(document.tailPreview)"
                }
                lines.append(detail)
            }
            if documents.count > 8 {
                lines.append("- \(documents.count - 8) additional live document\(documents.count - 8 == 1 ? "" : "s") captured.")
            }
        }

        if let graphRoute = snapshot.graphRoute {
            switch graphRoute.kind {
            case .canvas:
                if snapshot.graphOverlay.visibility != .hidden {
                    lines.append("Graph context: canvas \(snapshot.graphOverlay.visibility.rawValue), selected node \(graphRoute.selectedNodeId ?? "none").")
                }
            case .note:
                let noteTitle = documents.first(where: { $0.pageId == graphRoute.sourceId })?.title ?? graphRoute.sourceId ?? "unknown note"
                lines.append("Graph context: embedded note \(noteTitle), selected node \(graphRoute.selectedNodeId ?? "none").")
            case .folder:
                lines.append("Graph context: folder \(graphRoute.sourceId ?? "unknown folder"), selected node \(graphRoute.selectedNodeId ?? "none").")
            }
        }

        if let digest = snapshot.activityDigest {
            if !digest.editedNotes.isEmpty {
                let edited = digest.editedNotes.prefix(5).map(\.title).joined(separator: ", ")
                lines.append("Recent edits: \(edited).")
            }
            if digest.sessionDurationMinutes > 0 {
                lines.append("Tracked session length: \(digest.sessionDurationMinutes) minute\(digest.sessionDurationMinutes == 1 ? "" : "s").")
            }
        }

        return lines.joined(separator: "\n")
    }

}

// MARK: - Workspace Service
// Captures and restores full workspace state — open note tabs, utility panels,
// graph overlay, sidebar state, and editor cursor positions. Supports auto-save on quit
// and named workspace workflows.

@MainActor @Observable
final class WorkspaceService {
    private static let log = Logger(subsystem: "com.epistemos", category: "Workspace")
    private static let restoreDefaultsKey = "epistemos.restoreLastSession"
    private static let skipNextRestoreDefaultsKey = "epistemos.skipWorkspaceRestoreOnce"
    private static let skipNextAutoSaveDefaultsKey = "epistemos.skipWorkspaceAutoSaveOnce"

    var restoreLastSession: Bool {
        get { FoundationSafety.runtimeUserDefaults.bool(forKey: Self.restoreDefaultsKey) }
        set { FoundationSafety.runtimeUserDefaults.set(newValue, forKey: Self.restoreDefaultsKey) }
    }

    /// Set after auto-restore — read by LandingView to show welcome-back overlay.
    var welcomeBack: WelcomeBackInfo?

    /// Time Machine service reference (set by AppBootstrap after init).
    var timeMachineService: TimeMachineService?

    /// Auto-save timer — fires every `autoSaveInterval` seconds when active.
    private var autoSaveTask: Task<Void, Never>?
    var autoSaveInterval: TimeInterval = 90

    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        // Default to true on first launch
        if FoundationSafety.runtimeUserDefaults.object(forKey: Self.restoreDefaultsKey) == nil {
            FoundationSafety.runtimeUserDefaults.set(true, forKey: Self.restoreDefaultsKey)
        }
    }

    static func wordCountsByPageIdForSnapshot(_ pages: [SDPage]) -> [String: Int] {
        var counts: [String: Int] = [:]
        counts.reserveCapacity(pages.count)

        var duplicateCount = 0
        for page in pages {
            if counts[page.id] == nil {
                counts[page.id] = page.wordCount
            } else {
                duplicateCount += 1
            }
        }

        if duplicateCount > 0 {
            log.warning("Workspace snapshot ignored duplicate page IDs: \(duplicateCount, privacy: .public)")
        }

        return counts
    }

    // MARK: - Capture

    func captureSnapshot() -> WorkspaceSnapshot {
        guard let bootstrap = AppBootstrap.shared else {
            return WorkspaceSnapshot(
                activePanel: "home", activeChatId: nil, showChatSidebar: false,
                showLanding: true, openNoteTabs: [], activeNoteTabPageId: nil,
                notesBrowserVisible: false, settingsVisible: false,
                graphOverlay: GraphOverlaySnapshot(visibility: .hidden),
                expandedFolderIds: [], isJournalExpanded: false, isIdeasExpanded: false
            )
        }

        let context = modelContainer.mainContext
        let allPages: [SDPage]
        do {
            allPages = try context.fetch(FetchDescriptor<SDPage>())
        } catch {
            Self.log.error("Workspace capture: failed to fetch pages: \(error.localizedDescription, privacy: .public)")
            allPages = []
        }
        let graphNodeCount: Int
        do {
            graphNodeCount = try context.fetchCount(FetchDescriptor<SDGraphNode>())
        } catch {
            Self.log.error("Workspace capture: failed to fetch graph node count: \(error.localizedDescription, privacy: .public)")
            graphNodeCount = 0
        }
        let wordCountsByPageId = Self.wordCountsByPageIdForSnapshot(allPages)
        let pagesById = Self.pagesByIdForSnapshot(allPages)

        // Note tabs in tab-bar order
        let noteManager = NoteWindowManager.shared
        let orderedPageIds = noteManager.orderedPageIds()
        var noteTabs: [NoteTabSnapshot] = []
        for rootPageId in orderedPageIds {
            let nav = noteManager.navState(forTab: rootPageId)
            let editor = noteManager.editorState(for: rootPageId)
            let breadcrumbs = nav?.stack.map {
                BreadcrumbSnapshot(pageId: $0.id, title: $0.title)
            } ?? [BreadcrumbSnapshot(pageId: rootPageId, title: "")]
            let forward = nav?.forwardStack.map {
                BreadcrumbSnapshot(pageId: $0.id, title: $0.title)
            } ?? []

            let wordCount = noteManager.editorBody(for: rootPageId)
                .map(Self.wordCount(from:))
                ?? wordCountsByPageId[rootPageId]
                ?? 0

            noteTabs.append(NoteTabSnapshot(
                rootPageId: rootPageId,
                currentPageId: nav?.currentPageId ?? rootPageId,
                breadcrumbs: breadcrumbs,
                forwardStack: forward,
                cursorPosition: editor?.cursor,
                scrollFraction: editor?.scrollFraction,
                wordCount: wordCount
            ))
        }

        // Graph overlay state
        let holo = HologramController.shared
        let graphVisibility: GraphOverlaySnapshot.Visibility
        if noteManager.isGraphTabOpen {
            graphVisibility = .full
        } else if holo.isVisible {
            graphVisibility = holo.isMinimized ? .minimized : .full
        } else {
            graphVisibility = .hidden
        }

        // Vault-level note census for accurate Time Machine diffs
        let allPageIds = allPages.map(\.id)
        let graphRoute = Self.captureGraphRoute(from: bootstrap.graphState)
        let liveDocuments = Self.captureLiveDocuments(
            noteTabs: noteTabs,
            pagesById: pagesById,
            noteManager: noteManager,
            graphRoute: graphRoute,
            activePageId: bootstrap.notesUI.activePageId
        )
        return WorkspaceSnapshot(
            activePanel: bootstrap.uiState.activePanel.rawValue,
            activeChatId: nil,
            showChatSidebar: false,
            showLanding: true,
            openNoteTabs: noteTabs,
            activeNoteTabPageId: bootstrap.notesUI.activePageId,
            notesBrowserVisible: UtilityWindowManager.shared.isVisible(.notes),
            settingsVisible: UtilityWindowManager.shared.isVisible(.settings),
            graphOverlay: GraphOverlaySnapshot(
                visibility: graphVisibility,
                selectedNodeId: bootstrap.graphState.selectedNodeId,
                pinnedNodeIds: Array(bootstrap.graphState.pinnedNodeIds)
            ),
            expandedFolderIds: Array(bootstrap.notesUI.expandedFolderIds),
            isJournalExpanded: bootstrap.notesUI.isJournalExpanded,
            isIdeasExpanded: bootstrap.notesUI.isIdeasExpanded,
            activityDigest: bootstrap.activityTracker.buildDigest(
                since: bootstrap.activityTracker.trackingStartedAt ?? Date()
            ),
            totalNoteCount: allPages.count,
            graphNodeCount: graphNodeCount,
            allPageIds: allPageIds,
            liveDocuments: liveDocuments,
            graphRoute: graphRoute
        )
    }

    static func pagesByIdForSnapshot(_ pages: [SDPage]) -> [String: SDPage] {
        var result: [String: SDPage] = [:]
        result.reserveCapacity(pages.count)
        for page in pages where result[page.id] == nil {
            result[page.id] = page
        }
        return result
    }

    private static func captureLiveDocuments(
        noteTabs: [NoteTabSnapshot],
        pagesById: [String: SDPage],
        noteManager: NoteWindowManager,
        graphRoute: WorkspaceGraphRouteSnapshot?,
        activePageId: String?
    ) -> [WorkspaceDocumentState] {
        var documents: [WorkspaceDocumentState] = []
        var seen = Set<String>()

        func append(pageId: String, source: String, isActive: Bool) {
            guard seen.insert(pageId).inserted else {
                if isActive, let index = documents.firstIndex(where: { $0.pageId == pageId }) {
                    documents[index].isActive = true
                }
                return
            }
            let page = pagesById[pageId]
            let body = noteManager.currentBody(for: pageId, mapped: true)
            guard page != nil || !body.isEmpty else { return }
            let resolvedTitle = Self.resolvedDocumentTitle(page?.title, fallback: pageId)
            documents.append(WorkspaceDocumentState(
                pageId: pageId,
                title: resolvedTitle,
                source: source,
                lineCount: Self.lineCount(from: body),
                wordCount: Self.wordCount(from: body),
                bodyDigest: Self.stableDigest(for: body),
                preview: Self.compactPreview(body, limit: 260, fromTail: false),
                tailPreview: Self.compactPreview(body, limit: 260, fromTail: true),
                isActive: isActive
            ))
        }

        for tab in noteTabs {
            append(
                pageId: tab.rootPageId,
                source: tab.currentPageId == tab.rootPageId ? "note tab" : "note tab root",
                isActive: activePageId == tab.rootPageId
            )
            if tab.currentPageId != tab.rootPageId {
                append(
                    pageId: tab.currentPageId,
                    source: "note tab current page",
                    isActive: activePageId == tab.currentPageId
                )
            }
        }

        if graphRoute?.kind == .note, let sourceId = graphRoute?.sourceId {
            append(pageId: sourceId, source: "embedded graph note", isActive: true)
        }

        return documents
    }

    private static func captureGraphRoute(from graphState: GraphState) -> WorkspaceGraphRouteSnapshot {
        switch graphState.currentRoute {
        case .canvas:
            return WorkspaceGraphRouteSnapshot(
                kind: .canvas,
                sourceId: nil,
                selectedNodeId: graphState.selectedNodeId
            )
        case .note(let id):
            return WorkspaceGraphRouteSnapshot(
                kind: .note,
                sourceId: id,
                selectedNodeId: graphState.selectedNodeId
            )
        case .folder(let id):
            return WorkspaceGraphRouteSnapshot(
                kind: .folder,
                sourceId: id,
                selectedNodeId: graphState.selectedNodeId
            )
        }
    }

    private static func resolvedDocumentTitle(_ title: String?, fallback: String) -> String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func lineCount(from text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return text.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    private static func stableDigest(for text: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    private static func compactPreview(_ text: String, limit: Int, fromTail: Bool) -> String {
        let source = fromTail ? String(text.suffix(limit * 2)) : String(text.prefix(limit * 2))
        let words = source
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
        let collapsed = words.joined(separator: " ")
        guard collapsed.count > limit else { return collapsed }
        let clipped = fromTail ? String(collapsed.suffix(limit)) : String(collapsed.prefix(limit))
        return fromTail ? "...\(clipped)" : "\(clipped)..."
    }

    // MARK: - Restore

    func restoreSnapshot(_ snapshot: WorkspaceSnapshot) {
        guard let bootstrap = AppBootstrap.shared else { return }
        let context = modelContainer.mainContext

        // 1. Close existing windows
            NoteWindowManager.shared.resetForVaultRebuild()
        UtilityWindowManager.shared.hide(.notes)
        UtilityWindowManager.shared.hide(.settings)

        // 2. Main window state
        if let panel = NavTab(rawValue: snapshot.activePanel) {
            bootstrap.uiState.setActivePanel(panel.releaseSupportedVariant)
        }
        _ = snapshot.showChatSidebar

        // 3. Sidebar state
        bootstrap.notesUI.expandedFolderIds = Set(snapshot.expandedFolderIds)
        bootstrap.notesUI.isJournalExpanded = snapshot.isJournalExpanded
        bootstrap.notesUI.isIdeasExpanded = snapshot.isIdeasExpanded

        // 4. Note tabs (in order — first creates tab group, rest join)
        for tab in snapshot.openNoteTabs {
            let pageId = tab.rootPageId
            let descriptor = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == pageId }
            )
            let pageExists: Bool
            do {
                pageExists = try context.fetch(descriptor).first != nil
            } catch {
                Self.log.error("Workspace restore: failed to fetch page \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                continue
            }
            guard pageExists else {
                Self.log.info("Workspace restore: skipping deleted page \(pageId, privacy: .public)")
                continue
            }
            NoteWindowManager.shared.open(pageId: pageId)

            // Restore breadcrumb navigation if user had navigated via wikilinks
            if let nav = NoteWindowManager.shared.navState(forTab: pageId) {
                // Push breadcrumbs beyond the root (root is already in place from open)
                for crumb in tab.breadcrumbs.dropFirst() {
                    nav.push(pageId: crumb.pageId, title: crumb.title)
                }
                // Restore pending editor state
                if let cursor = tab.cursorPosition {
                    nav.pendingEditorRestore = (
                        cursor: cursor,
                        scrollFraction: tab.scrollFraction ?? 0
                    )
                }
            }
        }

        // Set active note tab
        if let activePageId = snapshot.activeNoteTabPageId {
            bootstrap.notesUI.openPage(activePageId)
        }

        // 5. Utility panels
        if snapshot.notesBrowserVisible {
            UtilityWindowManager.shared.show(.notes)
        }
        if snapshot.settingsVisible {
            UtilityWindowManager.shared.show(.settings)
        }

        // 7. Legacy graph-overlay snapshots migrate to the explicit
        // Multitask Graph tab. The retired floating overlay is no longer a
        // user-facing destination.
        switch snapshot.graphOverlay.visibility {
        case .full, .minimized:
            KnowledgeGraphShortcutDispatcher.openMultitaskGraph()
        case .hidden:
            break
        }

        // 7. Restore pinned graph nodes
        if let pinnedIds = snapshot.graphOverlay.pinnedNodeIds, !pinnedIds.isEmpty {
            bootstrap.graphState.restorePinnedNodes(Set(pinnedIds))
        }

        restoreMainWindowAfterSnapshot()

        Self.log.info("Workspace restored: \(snapshot.openNoteTabs.count) notes")
    }

    private func restoreMainWindowAfterSnapshot() {
        HomeWindowIdentity.surfaceHomeWindow()
    }

    static func hasRestorableMainChatWork(_ snapshot: WorkspaceSnapshot) -> Bool {
        false
    }

    static func hasRestorableSessionWork(_ snapshot: WorkspaceSnapshot) -> Bool {
        let hasLiveDocuments = snapshot.liveDocuments?.isEmpty == false
        let hasGraphRoute = snapshot.graphRoute?.kind != .canvas
        return !snapshot.openNoteTabs.isEmpty
            || hasLiveDocuments || hasGraphRoute
            || snapshot.notesBrowserVisible || snapshot.settingsVisible
            || snapshot.graphOverlay.visibility != .hidden
    }

    @discardableResult
    private func persistWorkspaceMutation(
        in context: ModelContext,
        failureMessage: String,
        restoreState: () -> Void
    ) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            restoreState()
            Self.log.error("\(failureMessage, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private static func welcomeBackInfo(
        summary: String,
        userNote: String,
        snapshot: WorkspaceSnapshot
    ) -> WelcomeBackInfo {
        let digest = snapshot.activityDigest
        return WelcomeBackInfo(
            intentSummary: WelcomeBackInfo.cleanedSummaryText(from: summary),
            userNote: userNote,
            noteCount: max(snapshot.openNoteTabs.count, snapshot.liveDocuments?.count ?? 0),
            chatCount: 0,
            graphWasOpen: snapshot.graphOverlay.visibility != .hidden || snapshot.graphRoute?.kind != .canvas,
            sessionMinutes: digest?.sessionDurationMinutes ?? 0,
            editedNoteTitles: digest?.editedNotes.map(\.title) ?? []
        )
    }

    // MARK: - Auto-Save / Auto-Restore

    func autoSave() {
        let snapshot = captureSnapshot()
        let liveTitle = WorkspaceSynthesisBuilder.title(for: snapshot)
        let liveSummary = WorkspaceSynthesisBuilder.summary(for: snapshot)
        let data: Data
        do {
            data = try JSONEncoder().encode(snapshot)
        } catch {
            Self.log.error("Workspace auto-save: failed to encode snapshot")
            return
        }

        let context = modelContainer.mainContext
        let predicate = #Predicate<SDWorkspace> { $0.isAutoSave == true }
        let savedWorkspace: SDWorkspace
        let restoreState: () -> Void
        do {
            if let existing = try context.fetch(FetchDescriptor(predicate: predicate)).first {
                let originalSnapshotData = existing.snapshotData
                let originalName = existing.name
                let originalUpdatedAt = existing.updatedAt
                let originalSummary = existing.summary
                let originalLastSummaryAt = existing.lastSummaryAt
                existing.snapshotData = data
                existing.name = liveTitle
                existing.updatedAt = Date()
                existing.summary = liveSummary
                existing.lastSummaryAt = Date()
                savedWorkspace = existing
                restoreState = {
                    savedWorkspace.snapshotData = originalSnapshotData
                    savedWorkspace.name = originalName
                    savedWorkspace.updatedAt = originalUpdatedAt
                    savedWorkspace.summary = originalSummary
                    savedWorkspace.lastSummaryAt = originalLastSummaryAt
                }
            } else {
                let workspace = SDWorkspace(name: liveTitle, isAutoSave: true)
                workspace.snapshotData = data
                workspace.summary = liveSummary
                workspace.lastSummaryAt = Date()
                context.insert(workspace)
                savedWorkspace = workspace
                restoreState = {
                    context.delete(savedWorkspace)
                }
            }
        } catch {
            Self.log.error("Workspace auto-save: failed to fetch auto-save workspace: \(error.localizedDescription, privacy: .public)")
            return
        }

        guard persistWorkspaceMutation(
            in: context,
            failureMessage: "Workspace auto-save: context save failed",
            restoreState: restoreState
        ) else {
            return
        }

        if welcomeBack != nil {
            welcomeBack = Self.welcomeBackInfo(
                summary: savedWorkspace.summary,
                userNote: savedWorkspace.userNote,
                snapshot: snapshot
            )
        }

        // Also save snapshot to EventStore for permanent session history
        if let bootstrap = AppBootstrap.shared,
           let snapshotJSON = String(data: data, encoding: .utf8) {
            EventStore.shared?.saveSnapshot(
                sessionId: bootstrap.activityTracker.sessionId,
                snapshotJSON: snapshotJSON,
                summary: savedWorkspace.summary,
                userNote: savedWorkspace.userNote
            )
        }
        Self.log.info("Workspace auto-saved")
    }

    func autoRestore() {
        if consumeSkipRestoreRequest() {
            welcomeBack = nil
            Self.log.info("Workspace auto-restore skipped by one-shot relaunch override")
            return
        }

        guard restoreLastSession else { return }

        let context = modelContainer.mainContext
        let predicate = #Predicate<SDWorkspace> { $0.isAutoSave == true }
        let workspace: SDWorkspace?
        do {
            workspace = try context.fetch(FetchDescriptor(predicate: predicate)).first
        } catch {
            Self.log.error("Workspace auto-restore: failed to fetch auto-save workspace: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard let workspace, !workspace.snapshotData.isEmpty else {
            return
        }

        let snapshot: WorkspaceSnapshot
        do {
            snapshot = try JSONDecoder().decode(WorkspaceSnapshot.self, from: workspace.snapshotData)
        } catch {
            Self.log.error("Workspace auto-restore: failed to decode snapshot")
            return
        }

        guard Self.hasRestorableSessionWork(snapshot) else {
            return
        }

        restoreSnapshot(snapshot)

        // Build welcome-back info from the restored workspace
        welcomeBack = Self.welcomeBackInfo(
            summary: workspace.summary,
            userNote: workspace.userNote,
            snapshot: snapshot
        )
    }

    func prepareSkipRestoreRelaunch() {
        FoundationSafety.runtimeUserDefaults.set(true, forKey: Self.skipNextRestoreDefaultsKey)
        FoundationSafety.runtimeUserDefaults.set(true, forKey: Self.skipNextAutoSaveDefaultsKey)
        clearAutoSavedWorkspace()
        welcomeBack = nil
    }

    func consumeSkipRestoreRequest() -> Bool {
        let defaults = FoundationSafety.runtimeUserDefaults
        let shouldSkip = defaults.bool(forKey: Self.skipNextRestoreDefaultsKey)
        if shouldSkip {
            defaults.removeObject(forKey: Self.skipNextRestoreDefaultsKey)
        }
        return shouldSkip
    }

    func consumeSkipAutoSaveRequest() -> Bool {
        let defaults = FoundationSafety.runtimeUserDefaults
        let shouldSkip = defaults.bool(forKey: Self.skipNextAutoSaveDefaultsKey)
        if shouldSkip {
            defaults.removeObject(forKey: Self.skipNextAutoSaveDefaultsKey)
        }
        return shouldSkip
    }

    func clearAutoSavedWorkspace() {
        let context = modelContainer.mainContext
        let predicate = #Predicate<SDWorkspace> { $0.isAutoSave == true }
        let descriptor = FetchDescriptor(predicate: predicate)

        do {
            let workspaces = try context.fetch(descriptor)
            guard !workspaces.isEmpty else { return }
            for workspace in workspaces {
                context.delete(workspace)
            }
            guard persistWorkspaceMutation(
                in: context,
                failureMessage: "Workspace skip-restore cleanup failed",
                restoreState: {
                    for workspace in workspaces {
                        context.insert(workspace)
                    }
                }
            ) else {
                return
            }
            Self.log.info("Cleared auto-saved workspace snapshot for skip-restore relaunch")
        } catch {
            Self.log.error("Workspace skip-restore cleanup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Auto-Save Timer

    func startAutoSave() {
        stopAutoSave()
        autoSaveTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(self?.autoSaveInterval ?? 300))
                } catch {
                    break
                }
                guard !Task.isCancelled, let self else { break }
                // Only auto-save if there's actual content open
                let hasWork = !NoteWindowManager.shared.orderedPageIds().isEmpty
                    || self.hasGraphWork()
                guard hasWork else { continue }
                self.autoSave()
                Self.log.info("Workspace auto-save timer fired")
            }
        }
    }

    func stopAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = nil
    }

    private func hasGraphWork() -> Bool {
        guard let graphState = AppBootstrap.shared?.graphState else { return false }
        return graphState.currentRoute != .canvas || HologramController.shared.isVisible
    }

    // MARK: - Workspace Diff (changes since last save)

    func changesSinceLastSave(for workspace: SDWorkspace) -> WorkspaceDiffSummary {
        guard !workspace.snapshotData.isEmpty else {
            return WorkspaceDiffSummary()
        }
        let snapshot: WorkspaceSnapshot
        do {
            snapshot = try JSONDecoder().decode(WorkspaceSnapshot.self, from: workspace.snapshotData)
        } catch {
            Self.log.error("Workspace diff: failed to decode saved snapshot: \(error.localizedDescription, privacy: .public)")
            return WorkspaceDiffSummary()
        }

        let context = modelContainer.mainContext
        var diff = WorkspaceDiffSummary()
        let currentPages: [SDPage]
        do {
            currentPages = try context.fetch(FetchDescriptor<SDPage>())
        } catch {
            Self.log.error("Workspace diff: failed to fetch current pages: \(error.localizedDescription, privacy: .public)")
            return WorkspaceDiffSummary()
        }
        let wordCountsByPageId = Self.wordCountsByPageIdForSnapshot(currentPages)

        // Current open note IDs
        let currentOpenIds = Set(NoteWindowManager.shared.orderedPageIds())
        let savedOpenIds = Set(snapshot.openNoteTabs.map(\.rootPageId))

        // Notes opened since save
        diff.notesOpened = currentOpenIds.subtracting(savedOpenIds).count
        // Notes closed since save
        diff.notesClosed = savedOpenIds.subtracting(currentOpenIds).count

        // Word count deltas for notes that were open at save time and still open
        for tab in snapshot.openNoteTabs {
            guard currentOpenIds.contains(tab.rootPageId) else { continue }
            let currentWords = NoteWindowManager.shared.editorBody(for: tab.rootPageId)
                .map(Self.wordCount(from:))
                ?? wordCountsByPageId[tab.rootPageId]
                ?? 0
            let savedWords = tab.wordCount ?? 0
            let delta = currentWords - savedWords
            if delta != 0 {
                let title = NoteWindowManager.shared.navState(forTab: tab.rootPageId)?.currentPageTitle ?? "Untitled"
                diff.wordCountDeltas.append((title: title, delta: delta))
            }
        }

        diff.chatsStarted = 0

        // Events since last save
        if let events = EventStore.shared?.events(from: workspace.updatedAt, to: Date()) {
            diff.chatMessagesSent = events.filter { $0.kind == "chat_message" }.count
        }

        // Graph node delta
        let currentNodeCount: Int
        do {
            currentNodeCount = try context.fetchCount(FetchDescriptor<SDGraphNode>())
        } catch {
            Self.log.error("Workspace diff: failed to fetch graph node count: \(error.localizedDescription, privacy: .public)")
            return diff
        }
        if let savedGraphNodeCount = snapshot.graphNodeCount {
            diff.graphNodesAdded = max(0, currentNodeCount - savedGraphNodeCount)
        }

        return diff
    }

    // MARK: - Named Workspaces

    @discardableResult
    func saveWorkspace(name: String) -> SDWorkspace? {
        let snapshot = captureSnapshot()
        let liveSummary = WorkspaceSynthesisBuilder.summary(for: snapshot)
        let data: Data
        do {
            data = try JSONEncoder().encode(snapshot)
        } catch {
            Self.log.error("Workspace save: failed to encode snapshot for '\(name, privacy: .public)'")
            return nil
        }

        let context = modelContainer.mainContext
        let ws = SDWorkspace(name: name, isAutoSave: false)
        ws.snapshotData = data
        ws.summary = liveSummary
        ws.lastSummaryAt = Date()
        context.insert(ws)
        guard persistWorkspaceMutation(
            in: context,
            failureMessage: "Workspace save: context save failed",
            restoreState: {
                context.delete(ws)
            }
        ) else {
            return nil
        }
        _ = enforceSavedWorkspaceLimit(AppDataRetentionPolicy.current().savedWorkspaceLimit)
        Self.log.info("Workspace saved: \(name, privacy: .public)")
        return ws
    }

    func loadWorkspace(_ workspace: SDWorkspace) {
        guard !workspace.snapshotData.isEmpty else {
            return
        }
        let snapshot: WorkspaceSnapshot
        do {
            snapshot = try JSONDecoder().decode(WorkspaceSnapshot.self, from: workspace.snapshotData)
        } catch {
            Self.log.error("Workspace load: failed to decode snapshot for '\(workspace.name, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return
        }
        restoreSnapshot(snapshot)
    }

    func deleteWorkspace(_ workspace: SDWorkspace) {
        let context = modelContainer.mainContext
        context.delete(workspace)
        _ = persistWorkspaceMutation(
            in: context,
            failureMessage: "Workspace delete: context save failed",
            restoreState: {
                context.insert(workspace)
            }
        )
    }

    func renameWorkspace(_ workspace: SDWorkspace, to newName: String) {
        let context = modelContainer.mainContext
        let originalName = workspace.name
        let originalUpdatedAt = workspace.updatedAt
        workspace.name = newName
        workspace.updatedAt = Date()
        _ = persistWorkspaceMutation(
            in: context,
            failureMessage: "Workspace rename: context save failed",
            restoreState: {
                workspace.name = originalName
                workspace.updatedAt = originalUpdatedAt
            }
        )
    }

    func listWorkspaces() -> [SDWorkspace] {
        let predicate = #Predicate<SDWorkspace> { $0.isAutoSave == false }
        let descriptor = FetchDescriptor<SDWorkspace>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        do {
            return try modelContainer.mainContext.fetch(descriptor)
        } catch {
            Self.log.error("Workspace list: failed to fetch saved workspaces: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    @discardableResult
    func enforceSavedWorkspaceLimit(_ limit: Int) -> Int {
        guard limit > 0 else { return 0 }
        let workspaces = listWorkspaces()
        guard workspaces.count > limit else { return 0 }

        let context = modelContainer.mainContext
        let overflow = Array(workspaces.dropFirst(limit))
        for workspace in overflow {
            context.delete(workspace)
        }

        guard persistWorkspaceMutation(
            in: context,
            failureMessage: "Workspace retention: context save failed",
            restoreState: {
                for workspace in overflow {
                    context.insert(workspace)
                }
            }
        ) else {
            return 0
        }

        Self.log.info("Workspace retention removed \(overflow.count, privacy: .public) saved workspace snapshots")
        return overflow.count
    }

    private static func wordCount(from text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
