import Foundation
import SQLite3
import Testing
@testable import Epistemos

@Suite("SearchIndexService Integration")
struct SearchIndexServiceIntegrationTests {
    private func makeDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("search-index-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("search.sqlite")
    }

    private func makeService() throws -> (service: SearchIndexService, databaseURL: URL) {
        let databaseURL = makeDatabaseURL()
        return (try SearchIndexService(databaseURL: databaseURL), databaseURL)
    }

    private func uniqueId(_ prefix: String = "search-test") -> String {
        "\(prefix)-\(UUID().uuidString)"
    }

    private func uniqueToken(_ prefix: String = "tok") -> String {
        "\(prefix)\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    }

    private func cleanup(_ service: SearchIndexService, ids: [String]) {
        for id in ids {
            try? service.delete(pageId: id)
        }
    }

    private func isDatabaseLocked(_ error: Error) -> Bool {
        String(describing: error).localizedCaseInsensitiveContains("database is locked")
    }

    private func withRetry<T>(
        attempts: Int = 20,
        delay: TimeInterval = 0.05,
        _ operation: () throws -> T
    ) throws -> T {
        var lastError: Error?
        for attempt in 1...attempts {
            do {
                return try operation()
            } catch {
                lastError = error
                guard isDatabaseLocked(error), attempt < attempts else { throw error }
                Thread.sleep(forTimeInterval: delay)
            }
        }
        throw lastError ?? SearchIndexError.noAppSupportDirectory
    }

    private func runSQLiteProcess(databaseURL: URL, schema: String) async throws -> Int32 {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
            process.arguments = [databaseURL.path, schema]
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        }.value
    }

    private func pragmaValue(databaseURL: URL, pragma: String) throws -> String {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw SearchIndexError.noAppSupportDirectory
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA \(pragma);", -1, &stmt, nil) == SQLITE_OK else {
            throw SearchIndexError.noAppSupportDirectory
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW, let text = sqlite3_column_text(stmt, 0) else {
            throw SearchIndexError.noAppSupportDirectory
        }
        return String(cString: text)
    }

    private func isBackupExcluded(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup) ?? false
    }

    private func makeLegacyFTSDatabase(_ databaseURL: URL) async throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let schema = """
        CREATE TABLE IF NOT EXISTS indexed_pages (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            tags TEXT,
            updatedAt REAL NOT NULL
        );
        CREATE VIRTUAL TABLE IF NOT EXISTS page_search USING fts5(
            title, body, tags,
            content='indexed_pages',
            content_rowid='rowid',
            tokenize='unicode61'
        );
        CREATE TRIGGER IF NOT EXISTS indexed_pages_ai AFTER INSERT ON indexed_pages BEGIN
            INSERT INTO page_search(rowid, title, body, tags)
            VALUES (new.rowid, new.title, new.body, new.tags);
        END;
        CREATE TRIGGER IF NOT EXISTS indexed_pages_ad AFTER DELETE ON indexed_pages BEGIN
            INSERT INTO page_search(page_search, rowid, title, body, tags)
            VALUES ('delete', old.rowid, old.title, old.body, old.tags);
        END;
        CREATE TRIGGER IF NOT EXISTS indexed_pages_au AFTER UPDATE ON indexed_pages BEGIN
            INSERT INTO page_search(page_search, rowid, title, body, tags)
            VALUES ('delete', old.rowid, old.title, old.body, old.tags);
            INSERT INTO page_search(rowid, title, body, tags)
            VALUES (new.rowid, new.title, new.body, new.tags);
        END;
        """

        let terminationStatus = try await runSQLiteProcess(databaseURL: databaseURL, schema: schema)
        #expect(terminationStatus == 0)
    }

    @Test("upsert + search returns inserted page")
    func upsertAndSearchRoundTrip() throws {
        let setup = try makeService()
        let service = setup.service
        let pageId = uniqueId()
        let token = uniqueToken()
        defer { cleanup(service, ids: [pageId]) }

        try withRetry {
            try service.upsert(
            id: pageId,
            title: "Title \(token)",
            body: "Body with \(token) detail",
            tags: "tag1 tag2",
            updatedAt: .now
        )
        }

        let results = try withRetry { try service.search(query: token, limit: 20) }
        #expect(results.contains { $0.pageId == pageId })
    }

    @Test("delete removes page from FTS results")
    func deleteRemovesPage() throws {
        let setup = try makeService()
        let service = setup.service
        let pageId = uniqueId()
        let token = uniqueToken("delete")
        defer { cleanup(service, ids: [pageId]) }

        try withRetry {
            try service.upsert(
            id: pageId,
            title: token,
            body: "Body",
            tags: "",
            updatedAt: .now
        )
        }
        let beforeDelete = try withRetry { try service.search(query: token) }
        #expect(beforeDelete.contains { $0.pageId == pageId })

        try withRetry { try service.delete(pageId: pageId) }
        let afterDelete = try withRetry { try service.search(query: token) }
        #expect(!afterDelete.contains { $0.pageId == pageId })
    }

    @Test("upsert conflict updates indexed content")
    func upsertConflictUpdatesContent() throws {
        let setup = try makeService()
        let service = setup.service
        let pageId = uniqueId()
        let oldToken = uniqueToken("old")
        let newToken = uniqueToken("new")
        defer { cleanup(service, ids: [pageId]) }

        try withRetry {
            try service.upsert(
            id: pageId,
            title: oldToken,
            body: "Old body",
            tags: "",
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        }
        try withRetry {
            try service.upsert(
            id: pageId,
            title: newToken,
            body: "New body \(newToken)",
            tags: "updated",
            updatedAt: Date(timeIntervalSince1970: 2)
        )
        }

        let newResults = try withRetry { try service.search(query: newToken) }
        let oldResults = try withRetry { try service.search(query: oldToken) }

        #expect(newResults.contains { $0.pageId == pageId })
        #expect(!oldResults.contains { $0.pageId == pageId })
    }

    @Test("search returns empty for blank query")
    func blankQueryReturnsEmpty() throws {
        let setup = try makeService()
        let service = setup.service
        #expect(try withRetry { try service.search(query: "   ") }.isEmpty)
        #expect(try withRetry { try service.search(query: "\n\t") }.isEmpty)
    }

    @Test("search respects result limit")
    func searchRespectsLimit() throws {
        let setup = try makeService()
        let service = setup.service
        let token = uniqueToken("limit")
        let ids = (0..<3).map { _ in uniqueId("limit-id") }
        defer { cleanup(service, ids: ids) }

        for (idx, id) in ids.enumerated() {
            try withRetry {
                try service.upsert(
                id: id,
                title: "\(token) \(idx)",
                body: "\(token) body",
                tags: "",
                updatedAt: .now
            )
            }
        }

        let results = try withRetry { try service.search(query: token, limit: 2) }
        #expect(results.count <= 2)
        #expect(results.allSatisfy { ids.contains($0.pageId) })
    }

    @Test("async search returns inserted page")
    func asyncSearchRoundTrip() async throws {
        let setup = try makeService()
        let service = setup.service
        let pageId = uniqueId("async-page")
        let token = uniqueToken("async")
        defer { cleanup(service, ids: [pageId]) }

        try withRetry {
            try service.upsert(
                id: pageId,
                title: "Async \(token)",
                body: "Body \(token)",
                tags: "async",
                updatedAt: .now
            )
        }

        let results = try await service.searchAsync(query: token, limit: 10)
        #expect(results.contains { $0.pageId == pageId })
    }

    @Test("async search cancellation leaves the index usable")
    func asyncSearchCancellationLeavesIndexUsable() async throws {
        let setup = try makeService()
        let service = setup.service
        let token = uniqueToken("cancel")
        let ids = (0..<32).map { _ in uniqueId("cancel-page") }
        defer { cleanup(service, ids: ids) }

        for (index, id) in ids.enumerated() {
            try withRetry {
                try service.upsert(
                    id: id,
                    title: "Cancel \(token) \(index)",
                    body: "Body \(token) \(index)",
                    tags: "cancel",
                    updatedAt: .now
                )
            }
        }

        let task = Task {
            try await service.searchAsync(query: token, limit: 100)
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancelled async search to fail")
        } catch is CancellationError {
            // expected
        } catch {
            #expect(String(describing: error).localizedCaseInsensitiveContains("interrupt"))
        }

        let freshResults = try await service.searchAsync(query: token, limit: 100)
        #expect(!freshResults.isEmpty)
        #expect(freshResults.allSatisfy { ids.contains($0.pageId) })
    }

    @Test("diffSync updates changed pages and deletes stale entries")
    func diffSyncUpdatesAndDeletes() async throws {
        let setup = try makeService()
        let service = setup.service
        let updatedId = uniqueId("diff-updated")
        let newId = uniqueId("diff-new")
        let staleId = uniqueId("diff-stale")
        let oldToken = uniqueToken("old")
        let newToken = uniqueToken("new")
        defer { cleanup(service, ids: [updatedId, newId, staleId]) }

        try withRetry {
            try service.upsert(
                id: updatedId,
                title: "Old \(oldToken)",
                body: "Old body \(oldToken)",
                tags: "",
                updatedAt: Date(timeIntervalSince1970: 1)
            )
        }
        try withRetry {
            try service.upsert(
                id: staleId,
                title: "Stale \(oldToken)",
                body: "Stale body \(oldToken)",
                tags: "",
                updatedAt: Date(timeIntervalSince1970: 1)
            )
        }

        try await service.diffSync(
            swiftDataPages: [
                (id: updatedId, updatedAt: Date(timeIntervalSince1970: 2)),
                (id: newId, updatedAt: Date(timeIntervalSince1970: 2)),
            ],
            fullPageProvider: { id in
                switch id {
                case updatedId:
                    return (
                        title: "Updated \(newToken)",
                        body: "Updated body \(newToken)",
                        tags: "fresh",
                        updatedAt: Date(timeIntervalSince1970: 2)
                    )
                case newId:
                    return (
                        title: "Inserted \(newToken)",
                        body: "Inserted body \(newToken)",
                        tags: "fresh",
                        updatedAt: Date(timeIntervalSince1970: 2)
                    )
                default:
                    return nil
                }
            }
        )

        let newResults = try withRetry { try service.search(query: newToken, limit: 10) }
        let oldResults = try withRetry { try service.search(query: oldToken, limit: 10) }

        #expect(newResults.contains { $0.pageId == updatedId })
        #expect(newResults.contains { $0.pageId == newId })
        #expect(!oldResults.contains { $0.pageId == staleId })
        #expect(!oldResults.contains { $0.pageId == updatedId })
    }

    @Test("async rebuild indexes full page snapshots")
    func asyncRebuildIndexesFullPageSnapshots() async throws {
        let setup = try makeService()
        let service = setup.service
        let pageId = uniqueId("rebuild")
        let token = uniqueToken("rebuild")
        defer { cleanup(service, ids: [pageId]) }

        try await service.rebuildFromSwiftDataAsync([
            (
                id: pageId,
                title: "Rebuild \(token)",
                body: "Body \(token)",
                tags: "fresh",
                updatedAt: .now
            ),
        ])

        let results = try withRetry { try service.search(query: token, limit: 20) }
        #expect(results.contains { $0.pageId == pageId })
    }

    @Test("stale FTS schema falls back to plain-table search when module is unavailable")
    func staleFTSSchemaFallsBackCleanly() async throws {
        let databaseURL = makeDatabaseURL()
        let pageId = uniqueId("legacy-fts")
        let token = uniqueToken("legacy")
        try await makeLegacyFTSDatabase(databaseURL)

        let service = try SearchIndexService(databaseURL: databaseURL)
        defer { cleanup(service, ids: [pageId]) }

        try withRetry {
            try service.upsert(
                id: pageId,
                title: "Legacy \(token)",
                body: "Body \(token)",
                tags: "fallback",
                updatedAt: .now
            )
        }

        let results = try withRetry { try service.search(query: token, limit: 10) }
        #expect(results.contains { $0.pageId == pageId })
    }

    @Test("database uses WAL FULL integrity check and protects live files")
    func databaseUsesDurablePragmasAndBackupExclusion() throws {
        let setup = try makeService()
        let service = setup.service
        let databaseURL = setup.databaseURL
        let pageId = uniqueId("pragma")
        defer { cleanup(service, ids: [pageId]) }

        try withRetry {
            try service.upsert(
                id: pageId,
                title: "Pragma coverage",
                body: "Ensure WAL FULL and backup exclusion are set",
                tags: "pragma",
                updatedAt: .now
            )
        }

        #expect(try pragmaValue(databaseURL: databaseURL, pragma: "journal_mode").lowercased() == "wal")
        #expect(try pragmaValue(databaseURL: databaseURL, pragma: "synchronous") == "2")
        #expect(try pragmaValue(databaseURL: databaseURL, pragma: "wal_autocheckpoint") == "1000")
        #expect(try pragmaValue(databaseURL: databaseURL, pragma: "integrity_check").lowercased() == "ok")

        let walURL = URL(fileURLWithPath: databaseURL.path + "-wal")
        let shmURL = URL(fileURLWithPath: databaseURL.path + "-shm")

        #expect(isBackupExcluded(databaseURL))
        if FileManager.default.fileExists(atPath: walURL.path) {
            #expect(isBackupExcluded(walURL))
        }
        if FileManager.default.fileExists(atPath: shmURL.path) {
            #expect(isBackupExcluded(shmURL))
        }
        let spotlightMarkerURL = databaseURL.deletingLastPathComponent().appendingPathComponent(".metadata_never_index")
        #expect(FileManager.default.fileExists(atPath: spotlightMarkerURL.path))
    }

    @Test("passive checkpoint keeps indexed content readable")
    func passiveCheckpointKeepsIndexedContentReadable() throws {
        let setup = try makeService()
        let service = setup.service
        let pageId = uniqueId("checkpoint")
        let token = uniqueToken("checkpoint")
        defer { cleanup(service, ids: [pageId]) }

        try withRetry {
            try service.upsert(
                id: pageId,
                title: "Checkpoint \(token)",
                body: "Body \(token)",
                tags: "checkpoint",
                updatedAt: .now
            )
        }

        try service.passiveCheckpoint()

        let results = try withRetry { try service.search(query: token, limit: 10) }
        #expect(results.contains { $0.pageId == pageId })
    }
}
