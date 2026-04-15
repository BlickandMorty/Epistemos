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
        UserFacingModelOutput.finalVisibleText(from: intentSummary)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Flat display text for the typewriter animation.
    var displayText: String {
        var lines: [String] = []

        if !userNote.isEmpty {
            lines.append("\"\(userNote)\"")
            lines.append("")
        }

        if !sanitizedIntentSummary.isEmpty {
            lines.append(sanitizedIntentSummary)
            lines.append("")
        }

        var stats: [String] = []
        if noteCount > 0 { stats.append("\(noteCount) note\(noteCount == 1 ? "" : "s")") }
        if chatCount > 0 { stats.append("\(chatCount) chat\(chatCount == 1 ? "" : "s")") }
        if graphWasOpen { stats.append("knowledge graph") }
        if !stats.isEmpty {
            lines.append("Restored: \(stats.joined(separator: ", "))")
        }

        if !editedNoteTitles.isEmpty {
            let titles = editedNoteTitles.prefix(4).joined(separator: ", ")
            let suffix = editedNoteTitles.count > 4 ? " and \(editedNoteTitles.count - 4) more" : ""
            lines.append("Last edited: \(titles)\(suffix)")
        }

        if sessionMinutes > 0 {
            lines.append("Previous session: \(sessionMinutes) minute\(sessionMinutes == 1 ? "" : "s")")
        }

        return lines.joined(separator: "\n")
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
}

// MARK: - Workspace Service
// Captures and restores full workspace state — open note tabs, mini chats, utility panels,
// graph overlay, sidebar state, and editor cursor positions. Supports auto-save on quit
// and named workspace workflows.

@MainActor @Observable
final class WorkspaceService {
    private static let log = Logger(subsystem: "com.epistemos", category: "Workspace")
    private static let restoreDefaultsKey = "epistemos.restoreLastSession"
    private static let skipNextRestoreDefaultsKey = "epistemos.skipWorkspaceRestoreOnce"
    private static let skipNextAutoSaveDefaultsKey = "epistemos.skipWorkspaceAutoSaveOnce"

    var restoreLastSession: Bool {
        get { UserDefaults.standard.bool(forKey: Self.restoreDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.restoreDefaultsKey) }
    }

    /// Set after auto-restore — read by LandingView to show welcome-back overlay.
    var welcomeBack: WelcomeBackInfo?

    /// Time Machine service reference (set by AppBootstrap after init).
    var timeMachineService: TimeMachineService?

    /// Auto-save timer — fires every `autoSaveInterval` seconds when active.
    private var autoSaveTask: Task<Void, Never>?
    var autoSaveInterval: TimeInterval = 300 // 5 minutes

    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        // Default to true on first launch
        if UserDefaults.standard.object(forKey: Self.restoreDefaultsKey) == nil {
            UserDefaults.standard.set(true, forKey: Self.restoreDefaultsKey)
        }
    }

    // MARK: - Capture

    func captureSnapshot() -> WorkspaceSnapshot {
        guard let bootstrap = AppBootstrap.shared else {
            return WorkspaceSnapshot(
                activePanel: "home", activeChatId: nil, showChatSidebar: false,
                showLanding: true, openNoteTabs: [], activeNoteTabPageId: nil,
                openMiniChatIds: [], notesBrowserVisible: false, settingsVisible: false,
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
        let wordCountsByPageId = Dictionary(uniqueKeysWithValues: allPages.map { ($0.id, $0.wordCount) })

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
        if holo.isVisible {
            graphVisibility = holo.isMinimized ? .minimized : .full
        } else {
            graphVisibility = .hidden
        }

        // Vault-level note census for accurate Time Machine diffs
        let allPageIds = allPages.map(\.id)

        return WorkspaceSnapshot(
            activePanel: bootstrap.uiState.activePanel.rawValue,
            activeChatId: bootstrap.chatState.activeChatId,
            showChatSidebar: bootstrap.uiState.showChatSidebar,
            showLanding: bootstrap.chatState.showLanding,
            openNoteTabs: noteTabs,
            activeNoteTabPageId: bootstrap.notesUI.activePageId,
            openMiniChatIds: MiniChatWindowController.shared.openChatIds,
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
            allPageIds: allPageIds
        )
    }

    // MARK: - Restore

    func restoreSnapshot(_ snapshot: WorkspaceSnapshot) {
        guard let bootstrap = AppBootstrap.shared else { return }
        let context = modelContainer.mainContext

        // 1. Close existing windows
        NoteWindowManager.shared.resetForVaultRebuild()
        MiniChatWindowController.shared.closeAll()
        UtilityWindowManager.shared.hide(.notes)
        UtilityWindowManager.shared.hide(.settings)

        // 2. Main window state
        if let panel = NavTab(rawValue: snapshot.activePanel) {
            bootstrap.uiState.setActivePanel(panel.releaseSupportedVariant)
        }
        bootstrap.uiState.showChatSidebar = snapshot.showChatSidebar
        bootstrap.chatState.showLanding = snapshot.showLanding
        if let chatId = snapshot.activeChatId {
            bootstrap.loadChat(chatId: chatId)
        }

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

        // 5. Mini chat windows
        for chatId in snapshot.openMiniChatIds {
            let descriptor = FetchDescriptor<SDChat>(
                predicate: #Predicate<SDChat> { $0.id == chatId }
            )
            let chatExists: Bool
            do {
                chatExists = try context.fetch(descriptor).first != nil
            } catch {
                Self.log.error("Workspace restore: failed to fetch chat \(chatId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                continue
            }
            guard chatExists else {
                Self.log.info("Workspace restore: skipping deleted chat \(chatId, privacy: .public)")
                continue
            }
            MiniChatWindowController.shared.openChat(chatId)
        }

        // 6. Utility panels
        if snapshot.notesBrowserVisible {
            UtilityWindowManager.shared.show(.notes)
        }
        if snapshot.settingsVisible {
            UtilityWindowManager.shared.show(.settings)
        }

        // 7. Graph overlay
        switch snapshot.graphOverlay.visibility {
        case .full:
            HologramController.shared.show()
        case .minimized:
            HologramController.shared.show()
            // Slight delay to let the overlay initialize before minimizing
            Task { @MainActor in
                do {
                    try await Task.sleep(for: .milliseconds(200))
                } catch {
                    return
                }
                HologramController.shared.minimize()
            }
        case .hidden:
            break
        }

        // 8. Restore pinned graph nodes
        if let pinnedIds = snapshot.graphOverlay.pinnedNodeIds, !pinnedIds.isEmpty {
            bootstrap.graphState.restorePinnedNodes(Set(pinnedIds))
        }

        restoreMainWindowAfterSnapshot()

        Self.log.info("Workspace restored: \(snapshot.openNoteTabs.count) notes, \(snapshot.openMiniChatIds.count) mini chats")
    }

    private func restoreMainWindowAfterSnapshot() {
        HomeWindowIdentity.surfaceHomeWindow()
    }

    // MARK: - Auto-Save / Auto-Restore

    func autoSave() {
        let snapshot = captureSnapshot()
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
        do {
            if let existing = try context.fetch(FetchDescriptor(predicate: predicate)).first {
                existing.snapshotData = data
                existing.updatedAt = Date()
                savedWorkspace = existing
            } else {
                let workspace = SDWorkspace(name: "Last Session", isAutoSave: true)
                workspace.snapshotData = data
                context.insert(workspace)
                savedWorkspace = workspace
            }
        } catch {
            Self.log.error("Workspace auto-save: failed to fetch auto-save workspace: \(error.localizedDescription, privacy: .public)")
            return
        }

        do {
            try context.save()
        } catch {
            Self.log.error("Workspace auto-save: context save failed: \(error)")
            return
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

        // Only restore if there's actual content to restore
        guard !snapshot.openNoteTabs.isEmpty || !snapshot.openMiniChatIds.isEmpty
            || snapshot.notesBrowserVisible || snapshot.settingsVisible
            || snapshot.graphOverlay.visibility != .hidden else {
            return
        }

        restoreSnapshot(snapshot)

        // Build welcome-back info from the restored workspace
        let digest = snapshot.activityDigest
        welcomeBack = WelcomeBackInfo(
            intentSummary: WelcomeBackInfo.cleanedSummaryText(from: workspace.summary),
            userNote: workspace.userNote,
            noteCount: snapshot.openNoteTabs.count,
            chatCount: snapshot.openMiniChatIds.count,
            graphWasOpen: snapshot.graphOverlay.visibility != .hidden,
            sessionMinutes: digest?.sessionDurationMinutes ?? 0,
            editedNoteTitles: digest?.editedNotes.map(\.title) ?? []
        )
    }

    func prepareSkipRestoreRelaunch() {
        UserDefaults.standard.set(true, forKey: Self.skipNextRestoreDefaultsKey)
        UserDefaults.standard.set(true, forKey: Self.skipNextAutoSaveDefaultsKey)
        clearAutoSavedWorkspace()
        welcomeBack = nil
    }

    func consumeSkipRestoreRequest() -> Bool {
        let defaults = UserDefaults.standard
        let shouldSkip = defaults.bool(forKey: Self.skipNextRestoreDefaultsKey)
        if shouldSkip {
            defaults.removeObject(forKey: Self.skipNextRestoreDefaultsKey)
        }
        return shouldSkip
    }

    func consumeSkipAutoSaveRequest() -> Bool {
        let defaults = UserDefaults.standard
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
            try context.save()
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
                    || !MiniChatWindowController.shared.openChatIds.isEmpty
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
        let wordCountsByPageId = Dictionary(uniqueKeysWithValues: currentPages.map { ($0.id, $0.wordCount) })

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

        // Chat count delta
        let currentChatCount = MiniChatWindowController.shared.openChatIds.count
        diff.chatsStarted = max(0, currentChatCount - snapshot.openMiniChatIds.count)

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
        if let savedAllPageCount = snapshot.totalNoteCount {
            diff.graphNodesAdded = max(0, currentNodeCount - savedAllPageCount)
        }

        return diff
    }

    // MARK: - Named Workspaces

    func saveWorkspace(name: String) {
        let snapshot = captureSnapshot()
        let data: Data
        do {
            data = try JSONEncoder().encode(snapshot)
        } catch {
            Self.log.error("Workspace save: failed to encode snapshot for '\(name, privacy: .public)'")
            return
        }

        let context = modelContainer.mainContext
        let ws = SDWorkspace(name: name, isAutoSave: false)
        ws.snapshotData = data
        context.insert(ws)
        do { try context.save() } catch { Self.log.error("Workspace save: context save failed: \(error)") }
        Self.log.info("Workspace saved: \(name, privacy: .public)")
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
        do { try context.save() } catch { Self.log.error("Workspace delete: context save failed: \(error)") }
    }

    func renameWorkspace(_ workspace: SDWorkspace, to newName: String) {
        workspace.name = newName
        workspace.updatedAt = Date()
        do { try modelContainer.mainContext.save() } catch { Self.log.error("Workspace rename: context save failed: \(error)") }
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

    private static func wordCount(from text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
