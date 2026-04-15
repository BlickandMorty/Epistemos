import Foundation
import SQLite3
import SwiftData
import Testing

@testable import Epistemos

private func loadWorkspaceSnapshotRepoTextFile(_ relativePath: String) throws -> String {
    try loadMirroredSourceTextFile(relativePath)
}

@Suite("WorkspaceSnapshot")
struct WorkspaceSnapshotTests {

    @Test("Round-trip encode/decode preserves all fields")
    func roundTrip() throws {
        let snapshot = WorkspaceSnapshot(
            activePanel: "notes",
            activeChatId: "chat-123",
            showChatSidebar: true,
            showLanding: false,
            openNoteTabs: [
                NoteTabSnapshot(
                    rootPageId: "page-1",
                    currentPageId: "page-3",
                    breadcrumbs: [
                        BreadcrumbSnapshot(pageId: "page-1", title: "Root Note"),
                        BreadcrumbSnapshot(pageId: "page-2", title: "Linked Note"),
                        BreadcrumbSnapshot(pageId: "page-3", title: "Deep Link"),
                    ],
                    forwardStack: [
                        BreadcrumbSnapshot(pageId: "page-4", title: "Future Note")
                    ],
                    cursorPosition: 42,
                    scrollFraction: 0.75
                ),
                NoteTabSnapshot(
                    rootPageId: "page-5",
                    currentPageId: "page-5",
                    breadcrumbs: [
                        BreadcrumbSnapshot(pageId: "page-5", title: "Simple Note")
                    ],
                    forwardStack: [],
                    cursorPosition: nil,
                    scrollFraction: nil
                ),
            ],
            activeNoteTabPageId: "page-1",
            openMiniChatIds: ["mini-1", "mini-2"],
            notesBrowserVisible: true,
            settingsVisible: false,
            graphOverlay: GraphOverlaySnapshot(
                visibility: .minimized,
                selectedNodeId: "node-xyz"
            ),
            expandedFolderIds: ["folder-a", "folder-b"],
            isJournalExpanded: true,
            isIdeasExpanded: false
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)

        #expect(decoded.activePanel == "notes")
        #expect(decoded.activeChatId == "chat-123")
        #expect(decoded.showChatSidebar == true)
        #expect(decoded.showLanding == false)
        #expect(decoded.openNoteTabs.count == 2)
        #expect(decoded.openNoteTabs[0].rootPageId == "page-1")
        #expect(decoded.openNoteTabs[0].currentPageId == "page-3")
        #expect(decoded.openNoteTabs[0].breadcrumbs.count == 3)
        #expect(decoded.openNoteTabs[0].forwardStack.count == 1)
        #expect(decoded.openNoteTabs[0].cursorPosition == 42)
        #expect(decoded.openNoteTabs[0].scrollFraction == 0.75)
        #expect(decoded.openNoteTabs[1].cursorPosition == nil)
        #expect(decoded.openNoteTabs[1].scrollFraction == nil)
        #expect(decoded.activeNoteTabPageId == "page-1")
        #expect(decoded.openMiniChatIds == ["mini-1", "mini-2"])
        #expect(decoded.notesBrowserVisible == true)
        #expect(decoded.settingsVisible == false)
        #expect(decoded.graphOverlay.visibility == .minimized)
        #expect(decoded.graphOverlay.selectedNodeId == "node-xyz")
        #expect(Set(decoded.expandedFolderIds) == Set(["folder-a", "folder-b"]))
        #expect(decoded.isJournalExpanded == true)
        #expect(decoded.isIdeasExpanded == false)
    }

    @Test("Empty workspace round-trips")
    func emptyRoundTrip() throws {
        let snapshot = WorkspaceSnapshot(
            activePanel: "home",
            activeChatId: nil,
            showChatSidebar: false,
            showLanding: true,
            openNoteTabs: [],
            activeNoteTabPageId: nil,
            openMiniChatIds: [],
            notesBrowserVisible: false,
            settingsVisible: false,
            graphOverlay: GraphOverlaySnapshot(visibility: .hidden),
            expandedFolderIds: [],
            isJournalExpanded: false,
            isIdeasExpanded: false
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)

        #expect(decoded.activePanel == "home")
        #expect(decoded.activeChatId == nil)
        #expect(decoded.openNoteTabs.isEmpty)
        #expect(decoded.openMiniChatIds.isEmpty)
        #expect(decoded.graphOverlay.visibility == .hidden)
        #expect(decoded.graphOverlay.selectedNodeId == nil)
    }

    @Test("GraphOverlaySnapshot visibility values")
    func graphVisibilityValues() throws {
        for visibility in [GraphOverlaySnapshot.Visibility.hidden, .full, .minimized] {
            let snapshot = GraphOverlaySnapshot(visibility: visibility)
            let data = try JSONEncoder().encode(snapshot)
            let decoded = try JSONDecoder().decode(GraphOverlaySnapshot.self, from: data)
            #expect(decoded.visibility == visibility)
        }
    }

    @Test("workspace restore returns the home window to the front after reopening secondary windows")
    func workspaceRestoreReturnsHomeWindowToFrontAfterReopeningSecondaryWindows() throws {
        let workspaceService = try loadWorkspaceSnapshotRepoTextFile("Epistemos/State/WorkspaceService.swift")
        let rootView = try loadWorkspaceSnapshotRepoTextFile("Epistemos/App/RootView.swift")

        #expect(workspaceService.contains("HomeWindowIdentity.surfaceHomeWindow()"))
        #expect(rootView.contains("static func surfaceHomeWindow()"))
        #expect(rootView.contains("mainWindow.orderFrontRegardless()"))
        #expect(rootView.contains("mainWindow.makeKeyAndOrderFront(nil)"))
    }
}

@Suite("WorkspaceService Persistence", .serialized)
struct WorkspaceServicePersistenceTests {
    @MainActor
    private func makeModelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(EpistemosSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    @Test("autoSave reuses the existing auto-save workspace instead of creating duplicates")
    func autoSaveReusesExistingAutoSaveWorkspace() throws {
        let container = try makeModelContainer()
        let service = WorkspaceService(modelContainer: container)
        let context = container.mainContext

        service.autoSave()
        service.autoSave()

        let workspaces = try context.fetch(FetchDescriptor<SDWorkspace>())
            .filter(\.isAutoSave)

        #expect(workspaces.count == 1)
        #expect(workspaces.first?.name == "Last Session")
        #expect(!(workspaces.first?.snapshotData.isEmpty ?? true))
    }
}

@Suite("EventStore")
struct EventStoreTests {
    private func pragmaValue(databaseURL: URL, pragma: String) throws -> String {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw CocoaError(.fileReadUnknown)
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA \(pragma);", -1, &stmt, nil) == SQLITE_OK else {
            throw CocoaError(.fileReadUnknown)
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW, let text = sqlite3_column_text(stmt, 0) else {
            throw CocoaError(.fileReadUnknown)
        }
        return String(cString: text)
    }

    private func isBackupExcluded(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup) ?? false
    }

    @Test("reads reflect queued snapshot and event writes")
    func readsReflectQueuedWrites() async throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("event-store-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("events.sqlite")
        let store = try #require(EventStore(databaseURL: dbURL))

        store.saveSnapshot(
            sessionId: "session-1",
            snapshotJSON: #"{"activePanel":"home"}"#,
            summary: "Saved",
            userNote: "Note"
        )
        store.appendEvent(sessionId: "session-1", kind: .chatMessageSent(chatId: "chat-1", snippet: "hello"))

        for _ in 0..<20 {
            if store.allSnapshots().count == 1, store.events(from: .distantPast, to: .now).count == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        let snapshot = try #require(store.nearestSnapshot(before: .now))
        #expect(snapshot.summary == "Saved")
        #expect(snapshot.userNote == "Note")

        let events = store.events(from: .distantPast, to: .now)
        #expect(events.map(\.kind) == ["chat_message"])

        let snapshots = store.allSnapshots()
        #expect(snapshots.count == 1)

        let density = store.eventDensityByDay(days: 1)
        #expect(!density.isEmpty)
    }

    @Test("event store uses durable pragmas and protects live database files")
    func eventStoreUsesDurablePragmasAndProtectsLiveFiles() async throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("event-store-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("events.sqlite")
        let store = try #require(EventStore(databaseURL: dbURL))

        store.appendEvent(sessionId: "session-1", kind: .chatMessageSent(chatId: "chat-1", snippet: "hello"))

        let walURL = URL(fileURLWithPath: dbURL.path + "-wal")
        let shmURL = URL(fileURLWithPath: dbURL.path + "-shm")
        for _ in 0..<20 {
            if FileManager.default.fileExists(atPath: walURL.path) {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(try pragmaValue(databaseURL: dbURL, pragma: "journal_mode").lowercased() == "wal")
        #expect(try pragmaValue(databaseURL: dbURL, pragma: "synchronous") == "2")
        #expect(try pragmaValue(databaseURL: dbURL, pragma: "wal_autocheckpoint") == "1000")
        #expect(try pragmaValue(databaseURL: dbURL, pragma: "integrity_check").lowercased() == "ok")
        #expect(isBackupExcluded(dbURL))
        if FileManager.default.fileExists(atPath: walURL.path) {
            #expect(isBackupExcluded(walURL))
        }
        if FileManager.default.fileExists(atPath: shmURL.path) {
            #expect(isBackupExcluded(shmURL))
        }
        let spotlightMarkerURL = dbURL.deletingLastPathComponent().appendingPathComponent(".metadata_never_index")
        #expect(FileManager.default.fileExists(atPath: spotlightMarkerURL.path))
    }

    @Test("session metrics round-trip through the event store")
    func sessionMetricsRoundTrip() async throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("event-store-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("events.sqlite")
        let store = try #require(EventStore(databaseURL: dbURL))

        let metrics = ReasoningTrajectoryMetricsFFI(
            displacement: 0.5,
            pathLength: 1.0,
            curvatureRatio: 2.0,
            loopCount: 1,
            errorCount: 0,
            totalCalls: 4,
            efficiency: 0.125,
            classification: "exploratory"
        )

        store.saveSessionMetrics(sessionId: "session-trajectory", metrics: metrics)

        var stored: EventStore.SessionMetricsRecord?
        for _ in 0..<20 {
            stored = store.sessionMetrics(for: "session-trajectory")
            if stored != nil {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        let record = try #require(stored)
        #expect(record.classification == "exploratory")
        #expect(record.totalCalls == 4)
        #expect(store.sessionMetricClassification(sessionId: "session-trajectory") == "exploratory")
    }
}

@Suite("Startup Integrity")
struct StartupIntegrityTests {
    @Test("startup integrity samples at least one managed body and caps at ten percent")
    func startupIntegritySamplesAtLeastOneManagedBodyAndCapsAtTenPercent() {
        let sampleOfThree = AppBootstrap.startupIntegritySamplePageIdsForTesting([
            "page-c", "page-a", "page-b",
        ])
        #expect(sampleOfThree.count == 1)
        #expect(sampleOfThree == ["page-a"])

        let twentyPageIDs = (1...20).map { "page-\($0)" }
        let sampleOfTwenty = AppBootstrap.startupIntegritySamplePageIdsForTesting(twentyPageIDs)
        #expect(sampleOfTwenty.count == 2)
        #expect(sampleOfTwenty == ["page-1", "page-9"])
    }

    @Test("startup integrity report blocks automatic vault restore after note-body verification failures")
    func startupIntegrityReportBlocksAutomaticVaultRestoreAfterVerificationFailures() {
        let report = AppBootstrap.startupIntegrityReportForTesting(
            samplePageIds: ["page-a", "page-b"],
            readBodyData: { pageId in
                pageId == "page-a" ? Data("ok".utf8) : nil
            },
            eventStoreAvailable: false
        )

        #expect(report.sampledPageIds == ["page-a", "page-b"])
        #expect(report.corruptedPageIds == ["page-b"])
        #expect(report.eventStoreAvailable == false)
        #expect(report.shouldBlockAutomaticVaultRestore)
    }

    @Test("startup integrity report blocks automatic vault restore after bookmark validation failures")
    func startupIntegrityReportBlocksAutomaticVaultRestoreAfterBookmarkValidationFailures() {
        let report = AppBootstrap.startupIntegrityReportForTesting(
            samplePageIds: ["page-a"],
            readBodyData: { _ in Data("ok".utf8) },
            eventStoreAvailable: true,
            vaultBookmarkValidation: VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: false,
                failureReason: "Saved vault bookmark is stale and must be re-selected."
            )
        )

        #expect(report.sampledPageIds == ["page-a"])
        #expect(report.corruptedPageIds.isEmpty)
        #expect(report.eventStoreAvailable)
        #expect(report.vaultBookmarkExists)
        #expect(report.vaultBookmarkReadyForAutomaticRestore == false)
        #expect(report.vaultBookmarkFailureReason == "Saved vault bookmark is stale and must be re-selected.")
        #expect(report.shouldBlockAutomaticVaultRestore)
    }

    @Test("startup integrity report flags notes with no body file inline body or vault source")
    func startupIntegrityReportFlagsNotesMissingAllBodySources() {
        let report = AppBootstrap.startupIntegrityReportForTesting(
            samplePageIds: [],
            readBodyData: { _ in Data("ok".utf8) },
            eventStoreAvailable: true,
            pageSnapshots: [
                StartupIntegrityPageSnapshot(
                    id: "orphaned-note",
                    filePath: nil,
                    hasInlineBody: false,
                    hasMeaningfulMetadata: true
                ),
                StartupIntegrityPageSnapshot(
                    id: "managed-note",
                    filePath: nil,
                    hasInlineBody: false,
                    hasMeaningfulMetadata: true
                ),
                StartupIntegrityPageSnapshot(
                    id: "vault-note",
                    filePath: "/tmp/vault-note.md",
                    hasInlineBody: false,
                    hasMeaningfulMetadata: true
                ),
                StartupIntegrityPageSnapshot(
                    id: "legacy-inline",
                    filePath: nil,
                    hasInlineBody: true,
                    hasMeaningfulMetadata: true
                ),
                StartupIntegrityPageSnapshot(
                    id: "fresh-empty",
                    filePath: nil,
                    hasInlineBody: false,
                    hasMeaningfulMetadata: false
                ),
            ],
            bodyFileExists: { pageId in pageId == "managed-note" },
            filePathReadable: { filePath in filePath == "/tmp/vault-note.md" }
        )

        #expect(report.unrecoverablePageIds == ["orphaned-note"])
        #expect(report.shouldBlockAutomaticVaultRestore == false)
    }

    @Test("startup integrity toast combines severe and unrecoverable warnings")
    func startupIntegrityToastCombinesWarnings() {
        let report = AppBootstrap.startupIntegrityReportForTesting(
            samplePageIds: ["page-a", "page-b"],
            readBodyData: { pageId in
                pageId == "page-a" ? Data("ok".utf8) : nil
            },
            eventStoreAvailable: false,
            vaultBookmarkValidation: VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: false,
                failureReason: "Saved vault bookmark is stale and must be re-selected."
            ),
            pageSnapshots: [
                StartupIntegrityPageSnapshot(
                    id: "orphaned-note",
                    filePath: nil,
                    hasInlineBody: false,
                    hasMeaningfulMetadata: true
                ),
            ],
            bodyFileExists: { _ in false },
            filePathReadable: { _ in false }
        )

        let toast = AppBootstrap.startupIntegrityToastForTesting(report: report)
        #expect(toast?.type == .error)
        #expect(
            toast?.message
                == "Startup integrity warning: session store is unavailable. Saved vault bookmark is stale and must be re-selected. Automatic vault restore was paused. quarantined 1 corrupted note body. Automatic vault restore was paused. found 1 note with no body file or vault source. Review them before editing."
        )
    }

    @Test("initial instant recall hydration is configured lazily")
    func initialInstantRecallHydrationIsConfiguredLazily() throws {
        let appBootstrap = try loadWorkspaceSnapshotRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(appBootstrap.contains("instantRecallService.configureInitialSnapshotProvider"))
        #expect(!appBootstrap.contains("if Self.shouldScheduleInitialInstantRecallSeed("))
        #expect(!appBootstrap.contains("scheduleInitialInstantRecallRebuild()"))
    }

    @Test("initial graph preload is skipped when automatic vault restore is ready")
    func initialGraphPreloadSkipsWhenAutomaticVaultRestoreIsReady() {
        let validation = VaultBookmarkStartupValidation(
            bookmarkExists: true,
            isReadyForAutomaticRestore: true,
            failureReason: nil
        )

        #expect(
            AppBootstrap.shouldScheduleInitialGraphLoadForTesting(
                vaultBookmarkValidation: validation
            ) == false
        )

        let appBootstrap = try? loadWorkspaceSnapshotRepoTextFile("Epistemos/App/AppBootstrap.swift")
        #expect(appBootstrap?.contains("Task(priority: .utility) { await graphState.loadGraph(container: container) }") == false)
    }

    @Test("initial graph preload stays lazy even when bookmark restore is unavailable")
    func initialGraphPreloadStaysLazyWhenBookmarkRestoreIsUnavailable() {
        let missingBookmark = VaultBookmarkStartupValidation(
            bookmarkExists: false,
            isReadyForAutomaticRestore: true,
            failureReason: nil
        )
        let staleBookmark = VaultBookmarkStartupValidation(
            bookmarkExists: true,
            isReadyForAutomaticRestore: false,
            failureReason: "Saved vault bookmark is stale and must be re-selected."
        )

        #expect(
            AppBootstrap.shouldScheduleInitialGraphLoadForTesting(
                vaultBookmarkValidation: missingBookmark
            ) == false
        )
        #expect(
            AppBootstrap.shouldScheduleInitialGraphLoadForTesting(
                vaultBookmarkValidation: staleBookmark
            ) == false
        )
    }

    @Test("knowledge fusion startup keeps full state hydration lazy")
    func knowledgeFusionStartupKeepsFullStateHydrationLazy() throws {
        let appBootstrap = try loadWorkspaceSnapshotRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let settingsView = try loadWorkspaceSnapshotRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(!appBootstrap.contains("await KnowledgeFusionViewModel.shared.loadState()"))
        #expect(appBootstrap.contains("KnowledgeFusionViewModel.shared.prepareBackgroundSchedulingIfNeeded()"))
        #expect(settingsView.contains("await vm.loadState()"))
    }

    @Test("workspace restore sanitizes retired omega snapshots back to home")
    func workspaceRestoreSanitizesRetiredOmegaSnapshots() throws {
        let workspaceService = try loadWorkspaceSnapshotRepoTextFile("Epistemos/State/WorkspaceService.swift")
        let navigationIntents = try loadWorkspaceSnapshotRepoTextFile("Epistemos/Intents/Custom/NavigationIntents.swift")
        let brandedTypes = try loadWorkspaceSnapshotRepoTextFile("Epistemos/Models/BrandedTypes.swift")

        #expect(workspaceService.contains("panel.releaseSupportedVariant"))
        #expect(navigationIntents.contains("tab.releaseSupportedVariant"))
        #expect(brandedTypes.contains("var releaseSupportedVariant: NavTab"))
        #expect(brandedTypes.contains("case .omega:"))
        #expect(brandedTypes.contains(".home"))
    }

    @Test("automatic vault restore waits for primary launch work when bookmark restore is ready")
    func automaticVaultRestoreWaitsForPrimaryLaunchWorkWhenBookmarkRestoreIsReady() {
        let validation = VaultBookmarkStartupValidation(
            bookmarkExists: true,
            isReadyForAutomaticRestore: true,
            failureReason: nil
        )

        #expect(
            AppBootstrap.shouldWaitForPrimaryLaunchBeforeAutomaticVaultRestoreForTesting(
                vaultBookmarkValidation: validation
            )
        )
    }

    @Test("automatic vault restore does not wait for primary launch work when bookmark restore is unavailable")
    func automaticVaultRestoreDoesNotWaitForPrimaryLaunchWorkWhenBookmarkRestoreIsUnavailable() {
        let missingBookmark = VaultBookmarkStartupValidation(
            bookmarkExists: false,
            isReadyForAutomaticRestore: true,
            failureReason: nil
        )
        let staleBookmark = VaultBookmarkStartupValidation(
            bookmarkExists: true,
            isReadyForAutomaticRestore: false,
            failureReason: "Saved vault bookmark is stale and must be re-selected."
        )

        #expect(
            AppBootstrap.shouldWaitForPrimaryLaunchBeforeAutomaticVaultRestoreForTesting(
                vaultBookmarkValidation: missingBookmark
            ) == false
        )
        #expect(
            AppBootstrap.shouldWaitForPrimaryLaunchBeforeAutomaticVaultRestoreForTesting(
                vaultBookmarkValidation: staleBookmark
            ) == false
        )
    }
}
