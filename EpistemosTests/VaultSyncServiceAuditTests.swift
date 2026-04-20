import Foundation
import SQLite3
import SwiftData
import Testing
@testable import Epistemos

@Suite("VaultSyncService Audit", .serialized)
@MainActor
struct VaultSyncServiceAuditTests {
    actor ExportCounter {
        private var count = 0

        func increment() {
            count += 1
        }

        func value() -> Int {
            count
        }
    }

    actor ExportGate {
        private var didStart = false
        private var didFinish = false
        private var startWaiters: [CheckedContinuation<Void, Never>] = []
        private var finishWaiters: [CheckedContinuation<Void, Never>] = []

        func markStarted() {
            guard !didStart else { return }
            didStart = true
            let waiters = self.startWaiters
            self.startWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }

        func waitUntilStarted() async {
            if didStart {
                return
            }

            await withCheckedContinuation { continuation in
                startWaiters.append(continuation)
            }
        }

        func markFinished() {
            guard !didFinish else { return }
            didFinish = true
            let waiters = self.finishWaiters
            self.finishWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }

        func waitUntilFinished() async {
            if didFinish {
                return
            }

            await withCheckedContinuation { continuation in
                finishWaiters.append(continuation)
            }
        }
    }

    final class ManagedBodyCountProbe: Sendable {
        private let lock = NSLock()
        nonisolated(unsafe) private var count = 0
        nonisolated(unsafe) private var ranOnMainThread = false
        private let result: Int

        init(result: Int) {
            self.result = result
        }

        nonisolated func record() -> Int {
            lock.lock()
            defer { lock.unlock() }
            count += 1
            ranOnMainThread = ranOnMainThread || Thread.isMainThread
            return result
        }

        nonisolated func invocationCount() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return count
        }

        nonisolated func executedOnMainThread() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return ranOnMainThread
        }
    }

    final class Locked<Value>: Sendable {
        private let lock = NSLock()
        nonisolated(unsafe) private var storage: Value

        init(_ value: Value) {
            storage = value
        }

        nonisolated func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
            lock.lock()
            defer { lock.unlock() }
            return body(&storage)
        }

        nonisolated var value: Value {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeRecoveryContainer() throws -> ModelContainer {
        let schema = Schema(EpistemosSchema.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vault-sync-audit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "VaultSyncServiceAuditTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private let vaultBookmarkKey = "epistemos.vaultBookmark"
    private let lastVaultPathKey = "epistemos.lastVaultPath"
    private let trustedSuspiciousVaultPathKey = "epistemos.confirmedSuspiciousVaultPath"

    private func waitUntil(
        timeout: Duration = .seconds(12),
        condition: @escaping @MainActor () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout

        while clock.now < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }

        Issue.record("Timed out waiting for condition")
    }

    private func sqliteRowCount(databaseURL: URL, table: String) throws -> Int {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else {
            throw CocoaError(.fileReadUnknown)
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \(table);", -1, &stmt, nil) == SQLITE_OK,
              let stmt else {
            throw CocoaError(.fileReadUnknown)
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw CocoaError(.fileReadUnknown)
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    private func latestSnapshotDirectory(in root: URL) throws -> URL {
        let snapshotDirs = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return try #require(snapshotDirs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).last)
    }

    @Test("restoreVaultFromBookmark is disabled under test hosts")
    func restoreVaultFromBookmarkDisabledUnderTests() {
        #expect(
            VaultSyncService.shouldRestoreVaultFromBookmark(
                processInfoEnvironment: ["XCTestConfigurationFilePath": "/tmp/test.xctest"]
            ) == false
        )
        #expect(
            VaultSyncService.shouldRestoreVaultFromBookmark(processInfoEnvironment: [:])
        )
    }

    @Test("restoreVaultFromBookmark respects explicit skip override")
    func restoreVaultFromBookmarkRespectsSkipOverride() {
        #expect(
            VaultSyncService.shouldRestoreVaultFromBookmark(
                processInfoEnvironment: ["EPISTEMOS_SKIP_VAULT_RESTORE": "1"]
            ) == false
        )
        #expect(
            VaultSyncService.shouldRestoreVaultFromBookmark(
                processInfoEnvironment: ["EPISTEMOS_SKIP_VAULT_RESTORE": "true"]
            ) == false
        )
        #expect(
            VaultSyncService.shouldRestoreVaultFromBookmark(
                processInfoEnvironment: ["EPISTEMOS_SKIP_VAULT_RESTORE": "0"]
            )
        )
    }

    @Test("startup bookmark validation rejects stale bookmarks")
    func startupBookmarkValidationRejectsStaleBookmarks() {
        let validation = VaultSyncService.startupBookmarkValidationForTesting(
            bookmarkExists: true,
            resolvedURL: URL(fileURLWithPath: "/tmp/vault", isDirectory: true),
            isStale: true,
            usedSecurityScope: false,
            accessGranted: true,
            isReadable: true
        )

        #expect(validation.bookmarkExists)
        #expect(validation.isReadyForAutomaticRestore == false)
        #expect(validation.failureReason == "Saved vault bookmark is stale and must be re-selected.")
    }

    @Test("pending startup restore can be cleared when automatic restore is paused")
    func pendingStartupRestoreCanBeClearedWhenAutomaticRestoreIsPaused() throws {
        let container = try makeRecoveryContainer()
        let defaults = makeIsolatedDefaults()
        defaults.set(Data("bookmark".utf8), forKey: vaultBookmarkKey)
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)

        #expect(service.isIndexing)

        service.clearPendingStartupRestoreForTesting()

        #expect(service.isIndexing == false)
    }

    @Test("startup bookmark validation accepts readable resolved bookmarks")
    func startupBookmarkValidationAcceptsReadableResolvedBookmarks() {
        let validation = VaultSyncService.startupBookmarkValidationForTesting(
            bookmarkExists: true,
            resolvedURL: URL(fileURLWithPath: "/tmp/vault", isDirectory: true),
            isStale: false,
            usedSecurityScope: true,
            accessGranted: true,
            isReadable: true
        )

        #expect(validation.bookmarkExists)
        #expect(validation.isReadyForAutomaticRestore)
        #expect(validation.failureReason == nil)
    }

    @Test("vault sync test hooks do not overwrite live vault defaults")
    func testHooksDoNotOverwriteLiveVaultDefaults() throws {
        let container = try makeRecoveryContainer()
        let service = VaultSyncService(modelContainer: container)
        let isolatedDefaults = makeIsolatedDefaults()
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let liveBookmark = UserDefaults.standard.data(forKey: vaultBookmarkKey)
        let livePath = UserDefaults.standard.string(forKey: lastVaultPathKey)

        service.setUserDefaultsForTesting(isolatedDefaults)
        service.persistVaultSelection(vaultURL)

        #expect(UserDefaults.standard.data(forKey: vaultBookmarkKey) == liveBookmark)
        #expect(UserDefaults.standard.string(forKey: lastVaultPathKey) == livePath)
        #expect(isolatedDefaults.string(forKey: lastVaultPathKey) == vaultURL.path)
    }

    @Test("vault sync defaults are isolated automatically under test hosts")
    func defaultTestInitDoesNotOverwriteLiveVaultDefaults() throws {
        let container = try makeRecoveryContainer()
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let liveBookmark = UserDefaults.standard.data(forKey: vaultBookmarkKey)
        let livePath = UserDefaults.standard.string(forKey: lastVaultPathKey)

        service.persistVaultSelection(vaultURL)

        #expect(UserDefaults.standard.data(forKey: vaultBookmarkKey) == liveBookmark)
        #expect(UserDefaults.standard.string(forKey: lastVaultPathKey) == livePath)
    }

    @Test("persist vault selection falls back to a plain bookmark when security scope creation fails")
    func persistVaultSelectionFallsBackToPlainBookmark() throws {
        let container = try makeRecoveryContainer()
        let service = VaultSyncService(modelContainer: container)
        let isolatedDefaults = makeIsolatedDefaults()
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        service.setUserDefaultsForTesting(isolatedDefaults)
        service.setBookmarkDataWriterForTesting { _, options in
            if options.contains(.withSecurityScope) {
                throw CocoaError(.fileReadUnknown)
            }
            return Data("plain-bookmark".utf8)
        }

        service.persistVaultSelection(vaultURL)

        #expect(isolatedDefaults.data(forKey: vaultBookmarkKey) == Data("plain-bookmark".utf8))
        #expect(isolatedDefaults.string(forKey: lastVaultPathKey) == vaultURL.path)
    }

    @Test("persist vault selection clears stale bookmark data when no bookmark can be stored")
    func persistVaultSelectionClearsStaleBookmarkWhenPersistenceFails() throws {
        let container = try makeRecoveryContainer()
        let service = VaultSyncService(modelContainer: container)
        let isolatedDefaults = makeIsolatedDefaults()
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        isolatedDefaults.set(Data("stale-bookmark".utf8), forKey: vaultBookmarkKey)
        service.setUserDefaultsForTesting(isolatedDefaults)
        service.setBookmarkDataWriterForTesting { _, _ in
            throw CocoaError(.fileReadUnknown)
        }

        service.persistVaultSelection(vaultURL)

        #expect(isolatedDefaults.data(forKey: vaultBookmarkKey) == nil)
        #expect(isolatedDefaults.string(forKey: lastVaultPathKey) == vaultURL.path)
    }

    @Test("persist vault selection stores suspicious-folder trust only for confirmed selections")
    func persistVaultSelectionStoresSuspiciousFolderTrustOnlyWhenConfirmed() throws {
        let container = try makeRecoveryContainer()
        let service = VaultSyncService(modelContainer: container)
        let isolatedDefaults = makeIsolatedDefaults()
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        isolatedDefaults.set("/tmp/old-trusted-path", forKey: trustedSuspiciousVaultPathKey)
        service.setUserDefaultsForTesting(isolatedDefaults)
        service.setBookmarkDataWriterForTesting { _, _ in
            Data("bookmark".utf8)
        }

        service.persistVaultSelection(vaultURL, userConfirmedSuspiciousFolder: true)

        #expect(
            isolatedDefaults.string(forKey: trustedSuspiciousVaultPathKey)
                == vaultURL.standardizedFileURL.path
        )

        service.persistVaultSelection(vaultURL, userConfirmedSuspiciousFolder: false)

        #expect(isolatedDefaults.string(forKey: trustedSuspiciousVaultPathKey) == nil)

        service.clearPersistedVaultSelection()

        #expect(isolatedDefaults.data(forKey: vaultBookmarkKey) == nil)
        #expect(isolatedDefaults.string(forKey: lastVaultPathKey) == nil)
        #expect(isolatedDefaults.string(forKey: trustedSuspiciousVaultPathKey) == nil)
    }

    @Test("automatic restore requires suspicious folders to be re-confirmed unless that exact path was trusted")
    func automaticRestoreRequiresSuspiciousFoldersToBeReconfirmedUnlessTrusted() {
        let suspiciousURL = URL(fileURLWithPath: "/tmp/fonts", isDirectory: true)
        let assessment = VaultIndexActor.VaultFolderSelectionAssessment(
            importableNoteFileCount: 2,
            otherRegularFileCount: 96,
            scannedRegularFileCount: 98,
            reachedScanLimit: false
        )

        let blockedReason = VaultSyncService.suspiciousVaultRestoreReconfirmationReasonForTesting(
            resolvedURL: suspiciousURL,
            assessment: assessment,
            trustedSuspiciousVaultPath: nil
        )

        #expect(blockedReason?.contains("must be confirmed again before automatic restore") == true)

        let allowedReason = VaultSyncService.suspiciousVaultRestoreReconfirmationReasonForTesting(
            resolvedURL: suspiciousURL,
            assessment: assessment,
            trustedSuspiciousVaultPath: suspiciousURL.standardizedFileURL.path
        )

        #expect(allowedReason == nil)
    }

    @Test("vault health snapshot counts managed bodies once off main")
    func vaultHealthSnapshotCountsManagedBodiesOffMain() async throws {
        let container = try makeRecoveryContainer()
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        let probe = ManagedBodyCountProbe(result: 4)
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        service.setManagedBodyCountProviderForTesting {
            probe.record()
        }

        _ = await service.detectRecoveryIssue(
            candidateVaultURL: vaultURL,
            bookmarkExists: true,
            restoreFailed: false
        )

        #expect(probe.invocationCount() == 1)
        #expect(probe.executedOnMainThread() == false)
    }

    @discardableResult
    private func insertDirtyPage(
        in context: ModelContext,
        title: String,
        body: String,
        lastSyncedHash: String,
        lastSyncedAt: Date
    ) -> SDPage {
        let page = SDPage(title: title)
        page.body = body
        page.needsVaultSync = true
        page.lastSyncedBodyHash = lastSyncedHash
        page.lastSyncedAt = lastSyncedAt
        context.insert(page)
        return page
    }

    @Test("saveAllDirtyPages keeps failed exports dirty")
    func saveAllDirtyPagesKeepsFailedExportsDirty() async throws {
        enum StubError: Error { case exportFailed }

        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        service.setVaultURLForTesting(vaultURL)

        let oldDate = Date(timeIntervalSince1970: 1_000)
        let successPage = insertDirtyPage(
            in: context,
            title: "Success",
            body: "success body",
            lastSyncedHash: "old-success-hash",
            lastSyncedAt: oldDate
        )
        let failedPage = insertDirtyPage(
            in: context,
            title: "Failure",
            body: "failed body",
            lastSyncedHash: "old-failed-hash",
            lastSyncedAt: oldDate
        )
        try context.save()
        let failedPageID = failedPage.id

        service.setExportPageOverrideForTesting { pageId, _ in
            if pageId == failedPageID {
                throw StubError.exportFailed
            }
            return ("/tmp/\(pageId).md", SDPage.bodyHash("success body"))
        }

        let task = service.saveAllDirtyPages()
        await task?.value

        let pages = try context.fetch(FetchDescriptor<SDPage>())
        guard let savedSuccess = pages.first(where: { $0.id == successPage.id }) else {
            Issue.record("Missing successful page after save")
            return
        }
        guard let savedFailure = pages.first(where: { $0.id == failedPage.id }) else {
            Issue.record("Missing failed page after save")
            return
        }

        #expect(savedSuccess.needsVaultSync == false)
        #expect(savedSuccess.lastSyncedAt != oldDate)
        #expect(savedSuccess.lastSyncedBodyHash == SDPage.bodyHash(savedSuccess.loadBody(mapped: true)))

        #expect(savedFailure.needsVaultSync)
        #expect(savedFailure.lastSyncedAt == oldDate)
        #expect(savedFailure.lastSyncedBodyHash == "old-failed-hash")
    }

    @Test("saveAllDirtyPages coalesces overlapping calls")
    func saveAllDirtyPagesCoalescesOverlappingCalls() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        service.setVaultURLForTesting(vaultURL)

        let page = insertDirtyPage(
            in: context,
            title: "Overlap",
            body: "body",
            lastSyncedHash: "old-overlap-hash",
            lastSyncedAt: Date(timeIntervalSince1970: 1_000)
        )
        try context.save()

        let counter = ExportCounter()
        service.setExportPageOverrideForTesting { pageId, _ in
            await counter.increment()
            try? await Task.sleep(for: .milliseconds(50))
            return ("/tmp/\(pageId).md", SDPage.bodyHash("body"))
        }

        let first = service.saveAllDirtyPages()
        let second = service.saveAllDirtyPages()
        await first?.value
        await second?.value

        #expect(await counter.value() == 1)

        let savedPage = try context.fetch(FetchDescriptor<SDPage>())
            .first(where: { $0.id == page.id })
        #expect(savedPage?.needsVaultSync == false)
    }

    @Test("saveAllDirtyPages reruns once if body changes during export")
    func saveAllDirtyPagesRerunsIfBodyChangesDuringExport() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        service.setVaultURLForTesting(vaultURL)

        let oldDate = Date(timeIntervalSince1970: 1_000)
        let page = insertDirtyPage(
            in: context,
            title: "Racing Edit",
            body: "body before export",
            lastSyncedHash: "old-race-hash",
            lastSyncedAt: oldDate
        )
        try context.save()
        let pageID = page.id
        let counter = ExportCounter()
        let gate = ExportGate()

        service.setExportPageOverrideForTesting { _, _ in
            await counter.increment()
            if await counter.value() == 1 {
                await gate.markStarted()
                try? await Task.sleep(for: .milliseconds(50))
                return ("/tmp/\(pageID).md", SDPage.bodyHash("body before export"))
            } else {
                return ("/tmp/\(pageID).md", SDPage.bodyHash("body after export started"))
            }
        }

        let task = service.saveAllDirtyPages()
        await gate.waitUntilStarted()

        let desc = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageID })
        if let mutatedPage = try context.fetch(desc).first {
            mutatedPage.body = "body after export started"
            mutatedPage.needsVaultSync = true
            try context.save()
        } else {
            Issue.record("Missing page during export mutation")
        }

        await task?.value

        let savedPage = try context.fetch(FetchDescriptor<SDPage>())
            .first(where: { $0.id == pageID })

        #expect(await counter.value() == 2)
        #expect(savedPage?.needsVaultSync == false)
        #expect(savedPage?.lastSyncedAt != oldDate)
        #expect(savedPage?.lastSyncedBodyHash == SDPage.bodyHash("body after export started"))
    }

    @Test("saveAllDirtyPages preserves tracked code files as raw source")
    func saveAllDirtyPagesPreservesTrackedCodeFilesAsRawSource() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        service.setVaultURLForTesting(vaultURL)

        let fileURL = vaultURL.appendingPathComponent("Tool.swift")
        let source = """
        struct Tool {
            func run() {
                print("ready")
            }
        }
        """

        let page = SDPage(title: "Tool")
        page.body = source
        page.filePath = fileURL.path
        page.needsVaultSync = true
        page.lastSyncedBodyHash = "old-code-hash"
        page.lastSyncedAt = Date(timeIntervalSince1970: 1_000)
        context.insert(page)
        try context.save()

        let task = service.saveAllDirtyPages()
        await task?.value

        let savedSource = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(savedSource == source)
        #expect(!savedSource.contains("\n---\n"))
        #expect(!savedSource.contains("title: Tool"))

        let refreshed = try #require(
            context.fetch(FetchDescriptor<SDPage>())
                .first(where: { $0.id == page.id })
        )
        #expect(refreshed.needsVaultSync == false)
        #expect(refreshed.lastSyncedBodyHash == SDPage.bodyHash(source))
    }

    @Test("saveAllDirtyPages removes stale instant recall entries for empty exported bodies")
    func saveAllDirtyPagesRemovesStaleInstantRecallEntriesForEmptyBodies() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        service.setVaultURLForTesting(vaultURL)

        guard let recall = AppBootstrap.shared?.instantRecallService else {
            Issue.record("Missing shared instant recall service")
            return
        }

        recall.clearIndex()

        let page = insertDirtyPage(
            in: context,
            title: "Cleared Recall Entry",
            body: "",
            lastSyncedHash: "old-empty-hash",
            lastSyncedAt: Date(timeIntervalSince1970: 1_000)
        )
        try context.save()

        recall.indexNote(noteId: page.id, text: "stale indexed content")
        #expect(recall.documentCount == 1)

        service.setExportPageOverrideForTesting { pageId, _ in
            return ("/tmp/\(pageId).md", SDPage.bodyHash(""))
        }

        let task = service.saveAllDirtyPages()
        await task?.value

        #expect(recall.documentCount == 0)
        #expect(recall.search(queryText: "stale indexed content", topK: 5).isEmpty)
    }

    @Test("savePage keeps newer edits dirty when export finishes with stale content")
    func savePageKeepsNewerEditsDirty() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        service.setVaultURLForTesting(vaultURL)

        let oldDate = Date(timeIntervalSince1970: 1_000)
        let page = SDPage(title: "Manual Save Race")
        page.body = "body before save"
        page.lastSyncedBodyHash = "old-save-hash"
        page.lastSyncedAt = oldDate
        page.needsVaultSync = true
        context.insert(page)
        try context.save()

        let pageID = page.id
        let gate = ExportGate()

        service.setExportPageOverrideForTesting { _, _ in
            await gate.markStarted()
            try? await Task.sleep(for: .milliseconds(50))
            await gate.markFinished()
            return ("/tmp/\(pageID).md", SDPage.bodyHash("body before save"))
        }

        service.savePage(pageId: pageID)
        await gate.waitUntilStarted()

        let desc = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageID })
        guard let mutatedPage = try context.fetch(desc).first else {
            Issue.record("Missing page during save mutation")
            return
        }

        mutatedPage.body = "body after save started"
        mutatedPage.needsVaultSync = true
        try context.save()

        await gate.waitUntilFinished()
        try? await Task.sleep(for: .milliseconds(50))

        guard let savedPage = try context.fetch(desc).first else {
            Issue.record("Missing page after save")
            return
        }

        #expect(savedPage.needsVaultSync)
        #expect(savedPage.lastSyncedAt == oldDate)
        #expect(savedPage.lastSyncedBodyHash == "old-save-hash")
    }

    @Test("savePage requests an editor flush before export")
    func savePageRequestsEditorFlushBeforeExport() async throws {
        actor FlushCapture {
            private var pageIds: [String] = []

            func record(_ pageId: String) {
                pageIds.append(pageId)
            }

            func snapshot() -> [String] {
                pageIds
            }
        }

        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        service.setVaultURLForTesting(vaultURL)

        let page = SDPage(title: "Flush Me")
        page.saveBody("# Flush Me\n\nBody")
        page.needsVaultSync = true
        context.insert(page)
        try context.save()

        let capture = FlushCapture()
        let token = NotificationCenter.default.addObserver(
            forName: NoteFileStorage.pageBodyWillRead,
            object: nil,
            queue: .main
        ) { notification in
            guard let pageId = notification.userInfo?["pageId"] as? String else { return }
            Task {
                await capture.record(pageId)
            }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        service.setExportPageOverrideForTesting { pageId, _ in
            return ("/tmp/\(pageId).md", SDPage.bodyHash("# Flush Me\n\nBody"))
        }

        let task = service.savePage(pageId: page.id)
        await task?.value
        try await Task.sleep(for: .milliseconds(50))

        #expect(await capture.snapshot() == [page.id])
    }

    @Test("searchFullAsync sees newly saved note bodies immediately")
    func searchFullAsyncSeesSavedBodiesImmediately() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        let searchURL = vaultURL.appendingPathComponent("search.sqlite")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        service.setSearchDatabaseURLForTesting(searchURL)
        service.startWatching(vaultURL: vaultURL)
        try await waitUntil(timeout: .seconds(30)) {
            service.isWatching && !service.isIndexing
        }

        let token = "vaultsearch\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let page = SDPage(title: "Searchable Chat Note")
        page.saveBody("Body text with \(token)")
        page.needsVaultSync = true
        context.insert(page)
        try context.save()

        let saveTask = try #require(service.savePage(pageId: page.id))
        await saveTask.value

        try await waitUntil {
            let hits = await service.searchFullAsync(query: token, limit: 5)
            return hits.contains { $0.pageId == page.id }
        }

        try await waitUntil {
            let pages = try? context.fetch(FetchDescriptor<SDPage>())
            return pages?.count == 1 && pages?.first?.id == page.id
        }

        let hits = await service.searchFullAsync(query: token, limit: 5)
        #expect(hits.contains { $0.pageId == page.id })
        #expect(hits.first(where: { $0.pageId == page.id })?.snippet.isEmpty == false)
    }

    @Test("movePage relocates the markdown file into the target vault subfolder")
    func movePageRelocatesFileIntoTargetSubfolder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        service.setVaultURLForTesting(vaultURL)

        let page = SDPage(title: "Daily Note")
        page.saveBody("Body")
        let originalURL = vaultURL.appendingPathComponent("Daily Note.md")
        try "Body".write(to: originalURL, atomically: true, encoding: .utf8)
        page.filePath = originalURL.path
        context.insert(page)
        try context.save()

        service.movePage(pageId: page.id, toSubfolder: "Daily Notes")

        let movedURL = vaultURL
            .appendingPathComponent("Daily Notes", isDirectory: true)
            .appendingPathComponent("Daily Note.md")
        let pageID = page.id

        let refreshed = try context.fetch(FetchDescriptor<SDPage>())
            .first(where: { $0.id == pageID })

        #expect(FileManager.default.fileExists(atPath: movedURL.path))
        #expect(!FileManager.default.fileExists(atPath: originalURL.path))
        #expect(refreshed?.subfolder == "Daily Notes")
        #expect(refreshed?.filePath == movedURL.path)
    }

    @Test("syncFromVault preserves existing dirty pages")
    func syncFromVaultPreservesExistingDirtyPages() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let noteURL = vaultURL.appendingPathComponent("Dirty.md")
        try "vault body".write(to: noteURL, atomically: true, encoding: .utf8)

        try await service.importVaultForTesting(from: vaultURL)

        let pageId = try #require(try context.fetch(FetchDescriptor<SDPage>()).first?.id)
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        let oldSyncedAt = Date(timeIntervalSince1970: 1_234)

        guard let page = try context.fetch(descriptor).first else {
            Issue.record("Imported page missing before sync")
            return
        }

        page.saveBody("local dirty body")
        page.needsVaultSync = true
        page.lastSyncedBodyHash = "prior-sync-hash"
        page.lastSyncedAt = oldSyncedAt
        try context.save()

        let conflicts = await service.syncFromVault()
        #expect(conflicts.isEmpty)

        guard let refreshed = try context.fetch(descriptor).first else {
            Issue.record("Imported page missing after sync")
            return
        }

        #expect(refreshed.loadBody() == "local dirty body")
        #expect(refreshed.needsVaultSync)
        #expect(refreshed.lastSyncedBodyHash == "prior-sync-hash")
        #expect(refreshed.lastSyncedAt == oldSyncedAt)
    }

    @Test("file watcher re-import does not delete tracked pages after disk removal")
    func fileWatcherImportIsNonDestructive() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        let searchURL = vaultURL.appendingPathComponent("search.sqlite")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let fileURL = vaultURL.appendingPathComponent("Watched.md")
        try """
        ---
        title: Watched
        ---

        body
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        service.setSearchDatabaseURLForTesting(searchURL)
        service.startWatching(vaultURL: vaultURL)
        try await waitUntil {
            service.isWatching && !service.isIndexing
        }

        let pageId = try #require(try context.fetch(FetchDescriptor<SDPage>()).first?.id)

        try FileManager.default.removeItem(at: fileURL)
        try? await Task.sleep(for: .seconds(4))

        let pages = try context.fetch(FetchDescriptor<SDPage>())
        #expect(pages.contains { $0.id == pageId })
    }

    @Test("disconnected local vault state triggers a prompted recovery issue")
    func disconnectedVaultStateTriggersRecoveryIssue() async throws {
        let container = try makeRecoveryContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        try """
        ---
        id: vault-a
        title: Vault A
        ---

        body
        """.write(
            to: vaultURL.appendingPathComponent("Vault A.md"),
            atomically: true,
            encoding: .utf8
        )
        try """
        ---
        id: vault-b
        title: Vault B
        ---

        body
        """.write(
            to: vaultURL.appendingPathComponent("Vault B.md"),
            atomically: true,
            encoding: .utf8
        )

        let disconnected = SDPage(title: "Disconnected")
        disconnected.saveBody("orphaned local body")
        disconnected.filePath = nil
        context.insert(disconnected)
        try context.save()
        service.setInitialImportCompletedForTesting(true)

        let issue = await service.detectRecoveryIssue(
            candidateVaultURL: vaultURL,
            bookmarkExists: true,
            restoreFailed: false
        )

        let snapshot = try #require(issue?.snapshot)
        #expect(snapshot.vaultMarkdownCount == 2)
        #expect(snapshot.indexedPageCount == 0)
        #expect(snapshot.indexedPagesWithFilePath == 0)
        #expect(snapshot.totalIndexedPageCount == 1)
        #expect(snapshot.nonVaultPageCount == 1)
        #expect(snapshot.duplicateTrackedPathCount == 0)
    }

    @Test("launch body cleanup is skipped while the vault index is clearly disconnected")
    func launchBodyCleanupSkipsDisconnectedState() async throws {
        let container = try makeRecoveryContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        try "body".write(
            to: vaultURL.appendingPathComponent("Readable.md"),
            atomically: true,
            encoding: .utf8
        )

        let disconnected = SDPage(title: "Disconnected")
        disconnected.saveBody("body")
        disconnected.filePath = nil
        context.insert(disconnected)
        try context.save()

        let shouldRun = await service.shouldRunBodyCleanup(candidateVaultURL: vaultURL)
        #expect(shouldRun == false)
    }

    @Test("detectRecoveryIssue explains severe vault index mismatches")
    func detectRecoveryIssueExplainsSevereIndexMismatch() async throws {
        let container = try makeRecoveryContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        for index in 0..<6 {
            try "Body \(index)".write(
                to: vaultURL.appendingPathComponent("Note-\(index).md"),
                atomically: true,
                encoding: .utf8
            )
        }

        let tracked = SDPage(title: "Tracked")
        tracked.filePath = vaultURL.appendingPathComponent("Note-0.md").path
        context.insert(tracked)
        try context.save()
        service.setInitialImportCompletedForTesting(true)

        let issue = await service.detectRecoveryIssue(
            candidateVaultURL: vaultURL,
            bookmarkExists: true,
            restoreFailed: false
        )

        let snapshot = try #require(issue?.snapshot)
        #expect(snapshot.vaultMarkdownCount == 6)
        #expect(snapshot.indexedPageCount == 1)
        #expect(snapshot.indexedPagesWithFilePath == 1)
        #expect(snapshot.hasSevereIndexMismatch)
        #expect(issue?.reason == "Epistemos indexed only a small fraction of the readable vault.")
    }

    @Test("detectRecoveryIssue explains collapsed body caches before the generic path-mapping warning")
    func detectRecoveryIssueExplainsCollapsedBodyCache() async throws {
        let container = try makeRecoveryContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        for index in 0..<4 {
            try "Body \(index)".write(
                to: vaultURL.appendingPathComponent("Note-\(index).md"),
                atomically: true,
                encoding: .utf8
            )
        }

        let disconnectedA = SDPage(title: "Disconnected A")
        disconnectedA.saveBody("cached local body")
        disconnectedA.filePath = nil
        context.insert(disconnectedA)

        let disconnectedB = SDPage(title: "Disconnected B")
        disconnectedB.saveBody("another cached local body")
        disconnectedB.filePath = nil
        context.insert(disconnectedB)
        try context.save()

        service.setInitialImportCompletedForTesting(true)
        service.setManagedBodyCountProviderForTesting { 1 }

        let issue = await service.detectRecoveryIssue(
            candidateVaultURL: vaultURL,
            bookmarkExists: true,
            restoreFailed: false
        )

        let snapshot = try #require(issue?.snapshot)
        #expect(snapshot.localBodyFileCount == 1)
        #expect(snapshot.totalIndexedPageCount == 2)
        #expect(snapshot.indexedPagesWithFilePath == 0)
        #expect(snapshot.hasCollapsedBodyCache)
        #expect(issue?.reason == "Epistemos kept only a collapsed local note-body cache after the vault stayed readable.")
    }

    @Test("recovery issues only block the workspace when a readable vault still has note files")
    func recoveryIssueBlocksWorkspaceOnlyWhenReadableVaultHasNoteFiles() {
        let blockingIssue = VaultRecoveryIssue(
            snapshot: VaultHealthSnapshot(
                vaultURL: URL(fileURLWithPath: "/tmp/blocking-vault", isDirectory: true),
                isVaultReadable: true,
                vaultMarkdownCount: 6,
                indexedPageCount: 1,
                indexedPagesWithFilePath: 1,
                totalIndexedPageCount: 2,
                nonVaultPageCount: 1,
                duplicateTrackedPathCount: 0,
                localBodyFileCount: 1,
                bookmarkExists: true,
                restoreFailed: false,
                initialImportCompleted: true,
                hadPriorLocalState: true
            ),
            reason: "Readable vault mismatch"
        )

        let nonBlockingIssue = VaultRecoveryIssue(
            snapshot: VaultHealthSnapshot(
                vaultURL: URL(fileURLWithPath: "/tmp/empty-vault", isDirectory: true),
                isVaultReadable: true,
                vaultMarkdownCount: 0,
                indexedPageCount: 0,
                indexedPagesWithFilePath: 0,
                totalIndexedPageCount: 1,
                nonVaultPageCount: 1,
                duplicateTrackedPathCount: 0,
                localBodyFileCount: 1,
                bookmarkExists: false,
                restoreFailed: true,
                initialImportCompleted: false,
                hadPriorLocalState: true
            ),
            reason: "Launch restore failed without a readable vault snapshot to repair against"
        )

        #expect(blockingIssue.blocksWorkspaceInteraction)
        #expect(nonBlockingIssue.blocksWorkspaceInteraction == false)
    }

    @Test("detectRecoveryIssue stays nil when indexed vault pages match readable files")
    func detectRecoveryIssueStaysNilWhenVaultIsHealthy() async throws {
        let container = try makeRecoveryContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        for index in 0..<3 {
            let fileURL = vaultURL.appendingPathComponent("Healthy-\(index).md")
            try "Body \(index)".write(to: fileURL, atomically: true, encoding: .utf8)

            let tracked = SDPage(title: "Healthy \(index)")
            tracked.filePath = fileURL.path
            context.insert(tracked)
        }
        try context.save()
        service.setInitialImportCompletedForTesting(true)

        let issue = await service.detectRecoveryIssue(
            candidateVaultURL: vaultURL,
            bookmarkExists: true,
            restoreFailed: false
        )

        #expect(issue == nil)
    }

    @Test("recovery snapshots local state and rebuilds pages, bodies, and search from the vault")
    func recoverySnapshotsAndRebuildsDerivedState() async throws {
        let container = try makeRecoveryContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let root = try makeTempDirectory()
        let vaultURL = root.appendingPathComponent("Vault", isDirectory: true)
        let appSupportURL = root.appendingPathComponent("Epistemos", isDirectory: true)
        let noteBodiesURL = appSupportURL.appendingPathComponent("note-bodies", isDirectory: true)
        let recoverySnapshotsURL = root.appendingPathComponent("Epistemos-Recovery", isDirectory: true)
        let preferencesURL = root.appendingPathComponent("com.epistemos.app.plist")
        let searchURL = appSupportURL.appendingPathComponent("search.sqlite")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: noteBodiesURL, withIntermediateDirectories: true)
        try "prefs".write(to: preferencesURL, atomically: true, encoding: .utf8)

        try """
        ---
        id: recovered-a
        title: Recovered A
        ---

        Body token: recover-alpha
        """.write(
            to: vaultURL.appendingPathComponent("Recovered A.md"),
            atomically: true,
            encoding: .utf8
        )
        try """
        ---
        id: recovered-b
        title: Recovered B
        ---

        Body token: recover-beta
        """.write(
            to: vaultURL.appendingPathComponent("Recovered B.md"),
            atomically: true,
            encoding: .utf8
        )

        let stalePage = SDPage(title: "Broken Local Page")
        stalePage.saveBody("stale body")
        context.insert(stalePage)
        try context.save()

        try await NoteFileStorage.withStorageDirectoryOverrideForTesting(noteBodiesURL, operation: { @MainActor in
            NoteFileStorage.writeBody(pageId: "orphan-body", content: "stale orphan")
            try "stale-search".write(to: searchURL, atomically: true, encoding: .utf8)

            service.setSearchDatabaseURLForTesting(searchURL)
            service.setAppSupportDirectoryURLForTesting(appSupportURL)
            service.setPreferencesFileURLForTesting(preferencesURL)
            service.setRecoverySnapshotRootURLForTesting(recoverySnapshotsURL)

            let recovered = await service.recoverFromVault(at: vaultURL)
            #expect(recovered)

            let pages = try context.fetch(FetchDescriptor<SDPage>())
            #expect(pages.count == 2)
            #expect(pages.allSatisfy { ($0.filePath?.isEmpty == false) })
            #expect(pages.contains { $0.id == "recovered-a" })
            #expect(pages.contains { $0.id == "recovered-b" })
            #expect(NoteFileStorage.bodyExists(pageId: "recovered-a"))
            #expect(NoteFileStorage.bodyExists(pageId: "recovered-b"))
            #expect(!NoteFileStorage.bodyExists(pageId: "orphan-body"))

            let searchHits = await service.searchFullAsync(query: "recover-alpha", limit: 5)
            #expect(searchHits.contains { $0.pageId == "recovered-a" })

            let snapshotDirs = try FileManager.default.contentsOfDirectory(
                at: recoverySnapshotsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            #expect(snapshotDirs.isEmpty == false)
            let latestSnapshot = try #require(snapshotDirs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).last)
            let snapshottedPrefs = latestSnapshot.appendingPathComponent(preferencesURL.lastPathComponent)
            let snapshottedAppSupport = latestSnapshot.appendingPathComponent(appSupportURL.lastPathComponent, isDirectory: true)
            #expect(FileManager.default.fileExists(atPath: snapshottedPrefs.path))
            #expect(FileManager.default.fileExists(atPath: snapshottedAppSupport.path))
        })
    }

    @Test("destructive stop snapshots local state before clearing vault data")
    func destructiveStopSnapshotsBeforeClearing() throws {
        let container = try makeRecoveryContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let root = try makeTempDirectory()
        let appSupportURL = root.appendingPathComponent("Epistemos", isDirectory: true)
        let noteBodiesURL = appSupportURL.appendingPathComponent("note-bodies", isDirectory: true)
        let recoverySnapshotsURL = root.appendingPathComponent("Epistemos-Recovery", isDirectory: true)
        let preferencesURL = root.appendingPathComponent("com.epistemos.app.plist")
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: noteBodiesURL, withIntermediateDirectories: true)
        try "prefs".write(to: preferencesURL, atomically: true, encoding: .utf8)

        let page = SDPage(title: "Snapshot Me")
        page.saveBody("local body")
        context.insert(page)
        try context.save()

        try NoteFileStorage.withStorageDirectoryOverrideForTesting(noteBodiesURL) {
            NoteFileStorage.writeBody(pageId: page.id, content: "local body")

            service.setVaultURLForTesting(root.appendingPathComponent("Vault", isDirectory: true))
            service.setAppSupportDirectoryURLForTesting(appSupportURL)
            service.setPreferencesFileURLForTesting(preferencesURL)
            service.setRecoverySnapshotRootURLForTesting(recoverySnapshotsURL)

            service.stopWatching(preserveData: false)

            let snapshotDirs = try FileManager.default.contentsOfDirectory(
                at: recoverySnapshotsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            #expect(snapshotDirs.isEmpty == false)
            #expect(try context.fetch(FetchDescriptor<SDPage>()).isEmpty)
        }
    }

    @MainActor
    @Test("destructive stop aborts the clear when the recovery snapshot fails")
    func destructiveStopAbortsClearWhenSnapshotFails() throws {
        let container = try makeRecoveryContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let root = try makeTempDirectory()
        let appSupportURL = root.appendingPathComponent("Epistemos", isDirectory: true)
        let noteBodiesURL = appSupportURL.appendingPathComponent("note-bodies", isDirectory: true)
        let snapshotRootFile = root.appendingPathComponent("snapshot-root-file")
        let preferencesURL = root.appendingPathComponent("com.epistemos.app.plist")
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: noteBodiesURL, withIntermediateDirectories: true)
        try "prefs".write(to: preferencesURL, atomically: true, encoding: .utf8)
        try "not-a-directory".write(to: snapshotRootFile, atomically: true, encoding: .utf8)

        let page = SDPage(title: "Keep Me")
        page.saveBody("local body")
        context.insert(page)
        try context.save()

        try NoteFileStorage.withStorageDirectoryOverrideForTesting(noteBodiesURL) {
            NoteFileStorage.writeBody(pageId: page.id, content: "local body")

            service.setVaultURLForTesting(root.appendingPathComponent("Vault", isDirectory: true))
            service.setAppSupportDirectoryURLForTesting(appSupportURL)
            service.setPreferencesFileURLForTesting(preferencesURL)
            service.setRecoverySnapshotRootURLForTesting(snapshotRootFile)

            service.stopWatching(preserveData: false)

            let pages = try context.fetch(FetchDescriptor<SDPage>())
            #expect(pages.count == 1)
            #expect(NoteFileStorage.bodyExists(pageId: page.id))
            #expect(service.recoveryIssue != nil)
            #expect(service.recoveryIssue?.reason.contains("clear was aborted") == true)
        }
    }

    @MainActor
    @Test("async destructive stop snapshots before clearing local data")
    func asyncDestructiveStopSnapshotsBeforeClearing() async throws {
        let container = try makeRecoveryContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let root = try makeTempDirectory()
        let appSupportURL = root.appendingPathComponent("Epistemos", isDirectory: true)
        let noteBodiesURL = appSupportURL.appendingPathComponent("note-bodies", isDirectory: true)
        let styleCacheURL = appSupportURL.appendingPathComponent("style-cache", isDirectory: true)
        let searchDatabaseURL = appSupportURL.appendingPathComponent("search.sqlite")
        let recoverySnapshotsURL = root.appendingPathComponent("Epistemos-Recovery", isDirectory: true)
        let preferencesURL = root.appendingPathComponent("com.epistemos.app.plist")
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: noteBodiesURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: styleCacheURL, withIntermediateDirectories: true)
        try "prefs".write(to: preferencesURL, atomically: true, encoding: .utf8)
        try "stale-search".write(to: searchDatabaseURL, atomically: true, encoding: .utf8)
        try "stale-style".write(
            to: styleCacheURL.appendingPathComponent("theme-cache.json"),
            atomically: true,
            encoding: .utf8
        )

        let page = SDPage(title: "Snapshot Me Async")
        page.saveBody("local body")
        context.insert(page)
        try context.save()

        try await NoteFileStorage.withStorageDirectoryOverrideForTesting(noteBodiesURL, operation: { @MainActor in
            NoteFileStorage.writeBody(pageId: page.id, content: "local body")

            service.setVaultURLForTesting(root.appendingPathComponent("Vault", isDirectory: true))
            service.setAppSupportDirectoryURLForTesting(appSupportURL)
            service.setPreferencesFileURLForTesting(preferencesURL)
            service.setSearchDatabaseURLForTesting(searchDatabaseURL)
            service.setRecoverySnapshotRootURLForTesting(recoverySnapshotsURL)

            let didClear = await service.stopWatchingAsync(preserveData: false)

            let snapshotDirs = try FileManager.default.contentsOfDirectory(
                at: recoverySnapshotsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            #expect(didClear)
            #expect(snapshotDirs.isEmpty == false)
            #expect(try context.fetch(FetchDescriptor<SDPage>()).isEmpty)
            #expect(!NoteFileStorage.bodyExists(pageId: page.id))
            #expect(!FileManager.default.fileExists(atPath: searchDatabaseURL.path))
            #expect(FileManager.default.fileExists(atPath: styleCacheURL.path))
            let styleCacheContents = try FileManager.default.contentsOfDirectory(
                at: styleCacheURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            #expect(styleCacheContents.isEmpty)
        })
    }

    @MainActor
    @Test("async destructive stop aborts the clear when the recovery snapshot fails")
    func asyncDestructiveStopAbortsClearWhenSnapshotFails() async throws {
        let container = try makeRecoveryContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let root = try makeTempDirectory()
        let appSupportURL = root.appendingPathComponent("Epistemos", isDirectory: true)
        let noteBodiesURL = appSupportURL.appendingPathComponent("note-bodies", isDirectory: true)
        let snapshotRootFile = root.appendingPathComponent("snapshot-root-file")
        let preferencesURL = root.appendingPathComponent("com.epistemos.app.plist")
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: noteBodiesURL, withIntermediateDirectories: true)
        try "prefs".write(to: preferencesURL, atomically: true, encoding: .utf8)
        try "not-a-directory".write(to: snapshotRootFile, atomically: true, encoding: .utf8)

        let page = SDPage(title: "Keep Me Async")
        page.saveBody("local body")
        context.insert(page)
        try context.save()

        try await NoteFileStorage.withStorageDirectoryOverrideForTesting(noteBodiesURL, operation: { @MainActor in
            NoteFileStorage.writeBody(pageId: page.id, content: "local body")

            service.setVaultURLForTesting(root.appendingPathComponent("Vault", isDirectory: true))
            service.setAppSupportDirectoryURLForTesting(appSupportURL)
            service.setPreferencesFileURLForTesting(preferencesURL)
            service.setRecoverySnapshotRootURLForTesting(snapshotRootFile)

            let didClear = await service.stopWatchingAsync(preserveData: false)

            let pages = try context.fetch(FetchDescriptor<SDPage>())
            #expect(!didClear)
            #expect(pages.count == 1)
            #expect(NoteFileStorage.bodyExists(pageId: page.id))
            #expect(service.recoveryIssue != nil)
            #expect(service.recoveryIssue?.reason.contains("clear was aborted") == true)
        })
    }

    @MainActor
    @Test("full reset fallback force clears derived local state after snapshot abort")
    func fullResetFallbackForceClearsDerivedLocalStateAfterSnapshotAbort() async throws {
        let container = try makeRecoveryContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let root = try makeTempDirectory()
        let appSupportURL = root.appendingPathComponent("Epistemos", isDirectory: true)
        let noteBodiesURL = appSupportURL.appendingPathComponent("note-bodies", isDirectory: true)
        let styleCacheURL = appSupportURL.appendingPathComponent("style-cache", isDirectory: true)
        let searchDatabaseURL = appSupportURL.appendingPathComponent("search.sqlite")
        let preferencesURL = root.appendingPathComponent("com.epistemos.app.plist")
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: noteBodiesURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: styleCacheURL, withIntermediateDirectories: true)
        try "prefs".write(to: preferencesURL, atomically: true, encoding: .utf8)
        try "stale-search".write(to: searchDatabaseURL, atomically: true, encoding: .utf8)
        try "stale-style".write(
            to: styleCacheURL.appendingPathComponent("theme-cache.json"),
            atomically: true,
            encoding: .utf8
        )

        let page = SDPage(title: "Reset Me")
        page.saveBody("local body")
        context.insert(page)
        try context.save()

        try await NoteFileStorage.withStorageDirectoryOverrideForTesting(noteBodiesURL, operation: { @MainActor in
            NoteFileStorage.writeBody(pageId: page.id, content: "local body")

            service.setVaultURLForTesting(root.appendingPathComponent("Vault", isDirectory: true))
            service.setAppSupportDirectoryURLForTesting(appSupportURL)
            service.setPreferencesFileURLForTesting(preferencesURL)
            service.setSearchDatabaseURLForTesting(searchDatabaseURL)
            service.recoveryIssue = VaultRecoveryIssue(
                snapshot: VaultHealthSnapshot(
                    vaultURL: nil,
                    isVaultReadable: false,
                    vaultMarkdownCount: 0,
                    indexedPageCount: 1,
                    indexedPagesWithFilePath: 0,
                    totalIndexedPageCount: 1,
                    nonVaultPageCount: 1,
                    duplicateTrackedPathCount: 0,
                    localBodyFileCount: 1,
                    bookmarkExists: false,
                    restoreFailed: true,
                    initialImportCompleted: true,
                    hadPriorLocalState: true
                ),
                reason: "snapshot failed"
            )

            await service.forceClearDerivedLocalStateForFullReset()

            let pages = try context.fetch(FetchDescriptor<SDPage>())
            #expect(pages.isEmpty)
            #expect(!NoteFileStorage.bodyExists(pageId: page.id))
            #expect(!FileManager.default.fileExists(atPath: searchDatabaseURL.path))
            #expect(FileManager.default.fileExists(atPath: styleCacheURL.path))
            let styleCacheContents = try FileManager.default.contentsOfDirectory(
                at: styleCacheURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            #expect(styleCacheContents.isEmpty)
            #expect(service.recoveryIssue == nil)
        })
    }

    @Test("destructive stop snapshots SQLite state via consistent backups instead of live file copies")
    func destructiveStopSnapshotsSQLiteStateViaConsistentBackups() async throws {
        let container = try makeRecoveryContainer()
        let service = VaultSyncService(modelContainer: container)
        let root = try makeTempDirectory()
        let appSupportURL = root.appendingPathComponent("Epistemos", isDirectory: true)
        let recoverySnapshotsURL = root.appendingPathComponent("Epistemos-Recovery", isDirectory: true)
        let preferencesURL = root.appendingPathComponent("com.epistemos.app.plist")
        let eventStoreURL = appSupportURL.appendingPathComponent("event-store.sqlite")
        let searchDatabaseURL = appSupportURL.appendingPathComponent("search.sqlite")
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try "prefs".write(to: preferencesURL, atomically: true, encoding: .utf8)
        try "keep-me".write(
            to: appSupportURL.appendingPathComponent("cache.txt"),
            atomically: true,
            encoding: .utf8
        )

        let eventStore = try #require(EventStore(databaseURL: eventStoreURL))
        eventStore.appendEvent(sessionId: "session-1", kind: .chatMessageSent(chatId: "chat-1", snippet: "hello"))
        for _ in 0..<20 {
            if eventStore.events(from: .distantPast, to: .now).count == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(eventStore.events(from: .distantPast, to: .now).count == 1)

        let searchService = try SearchIndexService(databaseURL: searchDatabaseURL)
        try searchService.upsert(
            id: "page-backup",
            title: "Backup coverage",
            body: "This search row must survive snapshotting.",
            tags: "backup",
            updatedAt: .now
        )

        service.setVaultURLForTesting(root.appendingPathComponent("Vault", isDirectory: true))
        service.setAppSupportDirectoryURLForTesting(appSupportURL)
        service.setPreferencesFileURLForTesting(preferencesURL)
        service.setRecoverySnapshotRootURLForTesting(recoverySnapshotsURL)

        service.stopWatching(preserveData: false)

        let snapshotURL = try latestSnapshotDirectory(in: recoverySnapshotsURL)
        let snapshottedAppSupport = snapshotURL.appendingPathComponent(appSupportURL.lastPathComponent, isDirectory: true)
        let snapshottedEventStoreURL = snapshottedAppSupport.appendingPathComponent("event-store.sqlite")
        let snapshottedSearchDatabaseURL = snapshottedAppSupport.appendingPathComponent("search.sqlite")

        #expect(FileManager.default.fileExists(atPath: snapshottedAppSupport.appendingPathComponent("cache.txt").path))
        #expect(FileManager.default.fileExists(atPath: snapshottedEventStoreURL.path))
        #expect(FileManager.default.fileExists(atPath: snapshottedSearchDatabaseURL.path))
        #expect(!FileManager.default.fileExists(atPath: URL(fileURLWithPath: snapshottedEventStoreURL.path + "-wal").path))
        #expect(!FileManager.default.fileExists(atPath: URL(fileURLWithPath: snapshottedEventStoreURL.path + "-shm").path))
        #expect(!FileManager.default.fileExists(atPath: URL(fileURLWithPath: snapshottedSearchDatabaseURL.path + "-wal").path))
        #expect(!FileManager.default.fileExists(atPath: URL(fileURLWithPath: snapshottedSearchDatabaseURL.path + "-shm").path))
        #expect(try sqliteRowCount(databaseURL: snapshottedEventStoreURL, table: "events") == 1)
        #expect(try sqliteRowCount(databaseURL: snapshottedSearchDatabaseURL, table: "indexed_pages") == 1)

        _ = searchService
    }

    @Test("recovery snapshot pruning keeps only the twenty most recent snapshots")
    func recoverySnapshotPruningKeepsOnlyTwentyMostRecentSnapshots() throws {
        let root = try makeTempDirectory()
        let snapshotsRoot = root.appendingPathComponent("Epistemos-Recovery", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: snapshotsRoot, withIntermediateDirectories: true)
        for index in 1...25 {
            let directory = snapshotsRoot.appendingPathComponent(
                String(format: "snapshot-%04d", index),
                isDirectory: true
            )
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        try VaultSyncService.pruneRecoverySnapshotsForTesting(at: snapshotsRoot, maxCount: 20)

        let remaining = try FileManager.default.contentsOfDirectory(
            at: snapshotsRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).map(\.lastPathComponent).sorted()

        #expect(remaining.count == 20)
        #expect(!remaining.contains("snapshot-0001"))
        #expect(!remaining.contains("snapshot-0005"))
        #expect(remaining.contains("snapshot-0006"))
        #expect(remaining.contains("snapshot-0025"))
    }

    @Test("APFS safety snapshot records newly created tmutil snapshots and prunes older app-owned entries")
    func apfsSafetySnapshotRecordsNewSnapshotsAndPrunesOlderAppOwnedEntries() throws {
        let root = try makeTempDirectory()
        let manifestURL = root.appendingPathComponent("apfs-snapshot-manifest.json")
        defer { try? FileManager.default.removeItem(at: root) }

        let commandLog = Locked<[String]>([])
        let createdSnapshots = Locked<Set<String>>([
            "2026-03-01-000001",
            "2026-03-02-000002",
            "2026-03-03-000003",
            "2026-03-04-000004",
            "2026-03-05-000005",
            "2026-03-06-000006",
            "2026-03-07-000007",
            "2026-03-08-000008",
            "2026-03-09-000009",
            "2026-03-10-000010",
            "2026-03-11-000011",
            "2026-03-12-000012",
            "2026-03-13-000013",
            "2026-03-14-000014",
            "2026-03-15-000015",
            "2026-03-16-000016",
            "2026-03-17-000017",
            "2026-03-18-000018",
            "2026-03-19-000019",
            "2026-03-20-000020",
        ])

        try VaultSyncService.writeAPFSSnapshotManifestForTesting(
            snapshotIDs: createdSnapshots.value.sorted(),
            reasons: Dictionary(
                uniqueKeysWithValues: createdSnapshots.value.map { ($0, "older-snapshot") }
            ),
            manifestURL: manifestURL
        )

        let created = try VaultSyncService.createAPFSSafetySnapshotForTesting(
            reason: "destructive-clear",
            manifestURL: manifestURL,
            maxCount: 20
        ) { arguments in
            commandLog.withLock { $0.append(arguments.joined(separator: " ")) }

            if arguments == ["listlocalsnapshots", "/"] {
                let lines = createdSnapshots.value.sorted().map { "com.apple.TimeMachine.\($0).local" }
                return (["Snapshots for disk /:"] + lines).joined(separator: "\n")
            }

            if arguments == ["localsnapshot"] {
                _ = createdSnapshots.withLock { snapshots in
                    snapshots.insert("2026-03-21-000021")
                }
                return "Created local snapshot with date: 2026-03-21-000021"
            }

            if arguments.count == 2, arguments[0] == "deletelocalsnapshots" {
                let snapshotID = arguments[1]
                _ = createdSnapshots.withLock { snapshots in
                    snapshots.remove(snapshotID)
                }
                return "Deleted local snapshot \(snapshotID)"
            }

            Issue.record("Unexpected tmutil arguments: \(arguments)")
            return ""
        }

        let manifestSnapshotIDs = try VaultSyncService.readAPFSSnapshotManifestForTesting(
            manifestURL: manifestURL
        )

        #expect(created == ["2026-03-21-000021"])
        #expect(manifestSnapshotIDs.count == 20)
        #expect(!manifestSnapshotIDs.contains("2026-03-01-000001"))
        #expect(manifestSnapshotIDs.contains("2026-03-02-000002"))
        #expect(manifestSnapshotIDs.contains("2026-03-21-000021"))
        #expect(commandLog.value.contains("listlocalsnapshots /"))
        #expect(commandLog.value.contains("localsnapshot"))
        #expect(commandLog.value.contains("deletelocalsnapshots 2026-03-01-000001"))
    }

    @Test("power mode changes restart vault maintenance timers when full mode returns")
    func powerModeChangesRestartVaultMaintenanceTimers() throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory()
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        service.startWatching(
            vaultURL: vaultURL,
            refreshAmbientManifestImmediately: false
        )

        service.handlePowerModeChangeForTesting(.full)
        let started = service.backgroundMaintenanceTimersStateForTesting()
        #expect(started.versionCaptureActive)
        #expect(started.manifestRefreshActive)

        service.handlePowerModeChangeForTesting(.eco)
        let disabled = service.backgroundMaintenanceTimersStateForTesting()
        #expect(!disabled.versionCaptureActive)
        #expect(!disabled.manifestRefreshActive)

        service.handlePowerModeChangeForTesting(.full)
        let restarted = service.backgroundMaintenanceTimersStateForTesting()
        #expect(restarted.versionCaptureActive)
        #expect(restarted.manifestRefreshActive)
    }

    @Test("eco mode keeps core vault sync active while background maintenance pauses")
    func ecoModeKeepsCoreVaultSyncActive() throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory()
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        service.autoSaveInterval = 30
        service.startWatching(
            vaultURL: vaultURL,
            refreshAmbientManifestImmediately: false
        )

        let startedCore = service.vaultCoreSyncStateForTesting()
        #expect(startedCore.isWatching)
        #expect(startedCore.autoSaveActive)
        #expect(startedCore.fileWatcherActive)

        service.handlePowerModeChangeForTesting(.eco)

        let ecoCore = service.vaultCoreSyncStateForTesting()
        #expect(ecoCore.isWatching)
        #expect(ecoCore.autoSaveActive)
        #expect(ecoCore.fileWatcherActive)

        let ecoMaintenance = service.backgroundMaintenanceTimersStateForTesting()
        #expect(!ecoMaintenance.versionCaptureActive)
        #expect(!ecoMaintenance.manifestRefreshActive)
    }
}
