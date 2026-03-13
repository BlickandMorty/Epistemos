import Foundation
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
            return "/tmp/\(pageId).md"
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
            return "/tmp/\(pageId).md"
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
            }
            return "/tmp/\(pageID).md"
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
            return "/tmp/\(pageID).md"
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
        #expect(snapshot.indexedPageCount == 1)
        #expect(snapshot.indexedPagesWithFilePath == 0)
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
            NoteFileStorage.setStorageDirectoryOverrideForTesting(nil)
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

        NoteFileStorage.setStorageDirectoryOverrideForTesting(noteBodiesURL)
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
    }
}
