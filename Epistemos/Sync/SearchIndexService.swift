import Foundation
import GRDB
import os
import SQLite3
import Synchronization

// MARK: - SearchIndexService
// FTS5 full-text search engine backed by GRDB.
// Lives outside SwiftData — owns its own search.sqlite file.
// Replaces the in-memory trigram index with a proper FTS5 virtual table
// that supports BM25 ranking, snippet() highlights, and unicode61 tokenization.
//
// Architecture:
// - GRDB DatabasePool is thread-safe (Sendable) and accessed via nonisolated methods
// - FTS5 content-sync triggers keep the virtual table in sync with indexed_pages
// - Startup diff-sync compares updatedAt between SwiftData and GRDB
// - Incremental: upsert/delete called from VaultIndexActor on each file change
//
// Swift 6 note: DatabasePool is Sendable. All GRDB operations are in nonisolated
// methods to avoid actor-hop overhead. The actor serializes only the async diff sync.

enum SearchIndexError: Error {
    case noAppSupportDirectory
    case integrityCheckFailed(String)
    case journalModeRejected(String)
}

actor SearchIndexService {
    private final class OffloadedSearchState<T: Sendable>: Sendable {
        private struct Storage: Sendable {
            var continuation: CheckedContinuation<T, Error>?
            var completed = false
            var cancelled = false
        }

        private let storage: Mutex<Storage>
        private let workItemLock = NSLock()
        nonisolated(unsafe) private var workItem: DispatchWorkItem?

        init(continuation: CheckedContinuation<T, Error>) {
            storage = Mutex(Storage(continuation: continuation))
        }

        func bind(workItem: DispatchWorkItem) {
            workItemLock.lock()
            self.workItem = workItem
            let shouldCancel = storage.withLock { storage in
                return storage.cancelled || storage.completed
            }
            workItemLock.unlock()
            if shouldCancel {
                workItem.cancel()
            }
        }

        func finish(with result: Result<T, Error>) {
            let continuation = storage.withLock { storage -> CheckedContinuation<T, Error>? in
                guard !storage.completed else {
                    return nil
                }
                storage.completed = true
                let continuation = storage.continuation
                storage.continuation = nil
                return continuation
            }
            continuation?.resume(with: result)
        }

        func isCancelled() -> Bool {
            storage.withLock { storage in
                storage.cancelled
            }
        }

        func cancel() {
            workItemLock.lock()
            let workItem = self.workItem
            let continuation = storage.withLock { storage -> CheckedContinuation<T, Error>? in
                guard !storage.completed else {
                    return nil
                }
                storage.completed = true
                storage.cancelled = true
                let continuation = storage.continuation
                storage.continuation = nil
                return continuation
            }
            workItemLock.unlock()
            workItem?.cancel()
            continuation?.resume(throwing: CancellationError())
        }
    }

    private final class OffloadedSearchStateBox<T: Sendable>: Sendable {
        private let state = Mutex<OffloadedSearchState<T>?>(nil)

        func set(_ state: OffloadedSearchState<T>) {
            self.state.withLock { currentState in
                currentState = state
            }
        }

        func cancel() {
            let currentState = state.withLock { state in
                state
            }
            currentState?.cancel()
        }
    }

    private struct OffloadedSearchCancellationProbe: Sendable {
        let isCancelled: @Sendable () -> Bool

        func check() throws {
            if isCancelled() {
                throw CancellationError()
            }
        }
    }

    private final class SQLiteCancellationContext: Sendable {
        let isCancelled: @Sendable () -> Bool

        init(isCancelled: @escaping @Sendable () -> Bool) {
            self.isCancelled = isCancelled
        }
    }

    private let log = Logger(subsystem: "com.epistemos", category: "SearchIndex")
    nonisolated private let databaseURL: URL
    nonisolated private let dbPool: DatabasePool
    nonisolated private let workQueue: DispatchQueue
    nonisolated private let queryQueue: DispatchQueue
    nonisolated private let supportsPageFTS5: Bool
    nonisolated private let supportsBlockFTS5: Bool

    init(databaseURL providedDatabaseURL: URL? = nil) throws {
        let resolvedDatabaseURL: URL
        let dbPool: DatabasePool
        if let providedURL = providedDatabaseURL {
            let parent = providedURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            resolvedDatabaseURL = providedURL
            dbPool = try DatabasePool(
                path: resolvedDatabaseURL.path,
                configuration: Self.databaseConfiguration()
            )
        } else {
            let appSupport = FoundationSafety.userApplicationSupportDirectory(fileManager: .default)
                .appendingPathComponent("Epistemos", isDirectory: true)
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            resolvedDatabaseURL = appSupport.appendingPathComponent("search.sqlite")
            dbPool = try DatabasePool(
                path: resolvedDatabaseURL.path,
                configuration: Self.databaseConfiguration()
            )
        }
        let workQueue = DispatchQueue(label: "com.epistemos.search-index", qos: .utility)
        let queryQueue = DispatchQueue(
            label: "com.epistemos.search-index.query",
            qos: .userInitiated,
            attributes: .concurrent
        )
        try Self.setupSchema(dbPool)
        try Self.refreshDatabaseFileProtections(resolvedDatabaseURL)
        let features = try Self.detectFeatures(dbPool)

        self.databaseURL = resolvedDatabaseURL
        self.dbPool = dbPool
        self.workQueue = workQueue
        self.queryQueue = queryQueue
        supportsPageFTS5 = features.pageFTS5
        supportsBlockFTS5 = features.blockFTS5

        log.info(
            "SearchIndexService initialized at \(resolvedDatabaseURL.path, privacy: .public) fts5_pages=\(features.pageFTS5) fts5_blocks=\(features.blockFTS5)"
        )
    }

    // MARK: - Schema Migration

    private struct SearchIndexFeatures: Sendable {
        let pageFTS5: Bool
        let blockFTS5: Bool
    }

    private nonisolated static func databaseConfiguration() -> Configuration {
        var config = Configuration()
        config.prepareDatabase { db in
            // Current durability stance: we still use system SQLite here. On macOS,
            // `synchronous = FULL` may not flush as strongly as a bundled
            // `SQLITE_HAVE_FULLFSYNC=1` build, so verified note-body storage and
            // startup integrity checks remain the compensating controls until that
            // SQLite bundling decision is implemented.
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA synchronous = FULL")
            try db.execute(sql: "PRAGMA wal_autocheckpoint = 1000")
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            let journalMode = try String.fetchOne(db, sql: "PRAGMA journal_mode")?.lowercased()
            guard journalMode == "wal" else {
                throw SearchIndexError.journalModeRejected(journalMode ?? "unknown")
            }

            // Quick check: O(1) B-tree verification, not full-table scan.
            // Full integrity_check deferred to startup integrity service.
            let integrity = try String.fetchOne(db, sql: "PRAGMA quick_check")
            guard integrity == "ok" else {
                throw SearchIndexError.integrityCheckFailed(integrity ?? "unknown")
            }
        }
        return config
    }

    private nonisolated static func excludeLiveDatabaseFilesFromBackup(_ databaseURL: URL) throws {
        let liveFiles = [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm"),
        ]

        for var fileURL in liveFiles where FileManager.default.fileExists(atPath: fileURL.path) {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try fileURL.setResourceValues(values)
        }
    }

    private nonisolated static func excludeDatabaseDirectoryFromSpotlight(_ databaseURL: URL) throws {
        let markerURL = databaseURL.deletingLastPathComponent().appendingPathComponent(".metadata_never_index")
        if !FileManager.default.fileExists(atPath: markerURL.path) {
            guard FileManager.default.createFile(atPath: markerURL.path, contents: Data()) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
    }

    private nonisolated static func refreshDatabaseFileProtections(_ databaseURL: URL) throws {
        try excludeLiveDatabaseFilesFromBackup(databaseURL)
        try excludeDatabaseDirectoryFromSpotlight(databaseURL)
    }

    private nonisolated func refreshBackupExclusion() throws {
        try Self.refreshDatabaseFileProtections(databaseURL)
    }

    private nonisolated static func setupSchema(_ db: DatabasePool) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS indexed_pages (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    body TEXT NOT NULL,
                    tags TEXT,
                    updatedAt REAL NOT NULL
                )
            """)

            try createPageSearchArtifactsIfAvailable(db)
        }
        migrator.registerMigration("v2_block_search") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS indexed_blocks (
                    block_id TEXT PRIMARY KEY,
                    page_id TEXT NOT NULL,
                    content TEXT NOT NULL
                )
            """)

            try createBlockSearchArtifactsIfAvailable(db)
        }
        try migrator.migrate(db)
    }

    private nonisolated static func createPageSearchArtifactsIfAvailable(_ db: Database) throws {
        do {
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS page_search USING fts5(
                    title, body, tags,
                    content='indexed_pages',
                    content_rowid='rowid',
                    tokenize='unicode61'
                )
            """)
        } catch {
            guard isMissingFTS5Module(error) else { throw error }
            return
        }

        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS indexed_pages_ai AFTER INSERT ON indexed_pages BEGIN
                INSERT INTO page_search(rowid, title, body, tags)
                VALUES (new.rowid, new.title, new.body, new.tags);
            END
        """)

        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS indexed_pages_ad AFTER DELETE ON indexed_pages BEGIN
                INSERT INTO page_search(page_search, rowid, title, body, tags)
                VALUES ('delete', old.rowid, old.title, old.body, old.tags);
            END
        """)

        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS indexed_pages_au AFTER UPDATE ON indexed_pages BEGIN
                INSERT INTO page_search(page_search, rowid, title, body, tags)
                VALUES ('delete', old.rowid, old.title, old.body, old.tags);
                INSERT INTO page_search(rowid, title, body, tags)
                VALUES (new.rowid, new.title, new.body, new.tags);
            END
        """)
    }

    private nonisolated static func createBlockSearchArtifactsIfAvailable(_ db: Database) throws {
        do {
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS block_search USING fts5(
                    content,
                    content='indexed_blocks',
                    content_rowid='rowid',
                    tokenize='unicode61'
                )
            """)
        } catch {
            guard isMissingFTS5Module(error) else { throw error }
            return
        }

        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS indexed_blocks_ai AFTER INSERT ON indexed_blocks BEGIN
                INSERT INTO block_search(rowid, content)
                VALUES (new.rowid, new.content);
            END
        """)

        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS indexed_blocks_ad AFTER DELETE ON indexed_blocks BEGIN
                INSERT INTO block_search(block_search, rowid, content)
                VALUES ('delete', old.rowid, old.content);
            END
        """)

        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS indexed_blocks_au AFTER UPDATE ON indexed_blocks BEGIN
                INSERT INTO block_search(block_search, rowid, content)
                VALUES ('delete', old.rowid, old.content);
                INSERT INTO block_search(rowid, content)
                VALUES (new.rowid, new.content);
            END
        """)
    }

    private nonisolated static func detectFeatures(_ db: DatabasePool) throws -> SearchIndexFeatures {
        try db.write { db in
            let fts5Available = try isFTS5Available(db)
            if !fts5Available {
                try dropFTSDependentTriggers(db)
            }

            let pageFTS5 = fts5Available ? try tableExists("page_search", db: db) : false
            let blockFTS5 = fts5Available ? try tableExists("block_search", db: db) : false
            return SearchIndexFeatures(
                pageFTS5: pageFTS5,
                blockFTS5: blockFTS5
            )
        }
    }

    private nonisolated static func tableExists(_ name: String, db: Database) throws -> Bool {
        try Bool.fetchOne(
            db,
            sql: "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?)",
            arguments: [name]
        ) ?? false
    }

    private nonisolated static func isMissingFTS5Module(_ error: Error) -> Bool {
        String(describing: error).localizedCaseInsensitiveContains("no such module: fts5")
    }

    private nonisolated static func isFTS5Available(_ db: Database) throws -> Bool {
        do {
            try db.execute(sql: "CREATE VIRTUAL TABLE temp.fts5_probe USING fts5(content)")
            try db.execute(sql: "DROP TABLE temp.fts5_probe")
            return true
        } catch {
            guard isMissingFTS5Module(error) else { throw error }
            return false
        }
    }

    private nonisolated static func dropFTSDependentTriggers(_ db: Database) throws {
        try db.execute(sql: "DROP TRIGGER IF EXISTS indexed_pages_ai")
        try db.execute(sql: "DROP TRIGGER IF EXISTS indexed_pages_ad")
        try db.execute(sql: "DROP TRIGGER IF EXISTS indexed_pages_au")
        try db.execute(sql: "DROP TRIGGER IF EXISTS indexed_blocks_ai")
        try db.execute(sql: "DROP TRIGGER IF EXISTS indexed_blocks_ad")
        try db.execute(sql: "DROP TRIGGER IF EXISTS indexed_blocks_au")
    }

    // MARK: - Search
    // nonisolated: DatabasePool is Sendable and let-bound, safe to access without actor hop.

    nonisolated func search(query: String, limit: Int = 50) throws -> [SearchResult] {
        // Wave 2.1 canonical perf signpost (subsystem io.epistemos.core / storage).
        // Wraps the FTS5 page search dispatch. Per dpp §1.1 Task 0.1.
        // begin/defer-end pattern (not closure wrapper) for TSAN safety.
        let signpostId = Sig.storage.makeSignpostID()
        let state = Sig.storage.beginInterval("search", id: signpostId)
        defer { Sig.storage.endInterval("search", state) }

        let terms = Self.normalizedSearchTerms(query)
        guard !terms.isEmpty else { return [] }
        return try searchPages(terms: terms, limit: limit)
    }

    func searchAsync(query: String, limit: Int = 50) async throws -> [SearchResult] {
        try await offloadSearch { [self] cancellation in
            let terms = Self.normalizedSearchTerms(query)
            guard !terms.isEmpty else { return [] }
            try cancellation.check()
            return try searchPages(terms: terms, limit: limit, cancellation: cancellation)
        }
    }

    // MARK: - Block Search

    nonisolated func searchBlocks(query: String, limit: Int = 50) throws -> [BlockSearchResult] {
        let terms = Self.normalizedSearchTerms(query)
        guard !terms.isEmpty else { return [] }

        return try searchBlocks(terms: terms, limit: limit)
    }

    func searchBlocksAsync(query: String, limit: Int = 50) async throws -> [BlockSearchResult] {
        try await offloadSearch { [self] cancellation in
            let terms = Self.normalizedSearchTerms(query)
            guard !terms.isEmpty else { return [] }
            try cancellation.check()
            return try searchBlocks(terms: terms, limit: limit, cancellation: cancellation)
        }
    }

    // MARK: - Block Upsert / Delete

    nonisolated func upsertBlock(blockId: String, pageId: String, content: String) throws {
        try dbPool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO indexed_blocks (block_id, page_id, content)
                    VALUES (?, ?, ?)
                    ON CONFLICT(block_id) DO UPDATE SET
                        page_id = excluded.page_id,
                        content = excluded.content
                """,
                arguments: [blockId, pageId, content]
            )
        }
        Self.notifyIndexChanged([.searchBlocks])
    }

    nonisolated func deleteBlock(blockId: String) throws {
        try dbPool.write { db in
            try db.execute(sql: "DELETE FROM indexed_blocks WHERE block_id = ?", arguments: [blockId])
        }
        Self.notifyIndexChanged([.searchBlocks])
    }

    // MARK: - Upsert / Delete

    nonisolated func upsert(id: String, title: String, body: String, tags: String, updatedAt: Date) throws {
        try dbPool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        title = excluded.title,
                        body = excluded.body,
                        tags = excluded.tags,
                        updatedAt = excluded.updatedAt
                """,
                arguments: [id, title, body, tags, updatedAt.timeIntervalSinceReferenceDate]
            )
        }
        Self.notifyIndexChanged([.searchPages])
    }

    nonisolated func upsertPages(
        _ pages: [(id: String, title: String, body: String, tags: String, updatedAt: Date)]
    ) throws {
        guard !pages.isEmpty else { return }

        try dbPool.write { db in
            for page in pages {
                try db.execute(
                    sql: """
                        INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                        VALUES (?, ?, ?, ?, ?)
                        ON CONFLICT(id) DO UPDATE SET
                            title = excluded.title,
                            body = excluded.body,
                            tags = excluded.tags,
                            updatedAt = excluded.updatedAt
                    """,
                    arguments: [
                        page.id,
                        page.title,
                        page.body,
                        page.tags,
                        page.updatedAt.timeIntervalSinceReferenceDate,
                    ]
                )
            }
        }
        Self.notifyIndexChanged([.searchPages])
    }

    nonisolated func delete(pageId: String) throws {
        try dbPool.write { db in
            try db.execute(sql: "DELETE FROM indexed_pages WHERE id = ?", arguments: [pageId])
        }
        Self.notifyIndexChanged([.searchPages])
    }

    // MARK: - Maintenance

    nonisolated func passiveCheckpoint() throws {
        let stats = try dbPool.barrierWriteWithoutTransaction { db in
            try db.checkpoint(.passive)
        }
        log.info(
            "SearchIndexService passive checkpoint completed walFrames=\(stats.walFrameCount) checkpointed=\(stats.checkpointedFrameCount)"
        )
    }

    // MARK: - Change Notification

    /// Post searchIndexDidUpdate on the main actor with the affected index domains.
    /// Static because nonisolated callers can't access instance state.
    private nonisolated static func notifyIndexChanged(_ dependencies: Set<QueryDependencyKey>) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .searchIndexDidUpdate,
                object: nil,
                userInfo: QueryDependencyKey.userInfo(for: dependencies)
            )
        }
    }

    // MARK: - Full Rebuild

    nonisolated func rebuildFromSwiftData(
        _ pages: [(id: String, title: String, body: String, tags: String, updatedAt: Date)]
    ) throws {
        try dbPool.write { db in
            try db.execute(sql: "DELETE FROM indexed_pages")
            if supportsPageFTS5 {
                try db.execute(sql: "INSERT INTO page_search(page_search) VALUES('rebuild')")
            }

            for page in pages {
                try db.execute(
                    sql: """
                        INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                        VALUES (?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        page.id, page.title, page.body, page.tags,
                        page.updatedAt.timeIntervalSinceReferenceDate,
                    ]
                )
            }
        }
        log.info("Rebuilt search index with \(pages.count) pages")
        Self.notifyIndexChanged([.searchPages])
    }

    func rebuildFromSwiftDataAsync(
        _ pages: [(id: String, title: String, body: String, tags: String, updatedAt: Date)]
    ) async throws {
        try await offload { [self] in
            try rebuildFromSwiftData(pages)
        }
    }

    // MARK: - Diff Sync

    nonisolated func diffSync(
        swiftDataPages: [(id: String, updatedAt: Date)],
        fullPageProvider: @Sendable (String) async -> (title: String, body: String, tags: String, updatedAt: Date)?
    ) async throws {
        let grdbPages = try fetchAllTimestamps()

        let swiftDataIds = Set(swiftDataPages.map(\.id))
        let grdbIds = Set(grdbPages.keys)

        // Delete stale pages (in GRDB but not SwiftData)
        let toDelete = grdbIds.subtracting(swiftDataIds)
        if !toDelete.isEmpty {
            try deletePages(ids: toDelete)
        }

        // Upsert pages newer in SwiftData or missing from GRDB
        var pagesToUpsert: [(id: String, title: String, body: String, tags: String, updatedAt: Date)] = []
        pagesToUpsert.reserveCapacity(swiftDataPages.count)
        for sd in swiftDataPages {
            let sdTimestamp = sd.updatedAt.timeIntervalSinceReferenceDate
            let needsUpsert: Bool
            if let grdbTs = grdbPages[sd.id] {
                needsUpsert = sdTimestamp > grdbTs + 0.001
            } else {
                needsUpsert = true
            }

            if needsUpsert {
                if let full = await fullPageProvider(sd.id) {
                    pagesToUpsert.append((
                        id: sd.id,
                        title: full.title,
                        body: full.body,
                        tags: full.tags,
                        updatedAt: full.updatedAt
                    ))
                }
            }
        }

        if !pagesToUpsert.isEmpty {
            try upsertPages(pagesToUpsert)
        } else if !toDelete.isEmpty {
            Self.notifyIndexChanged([.searchPages])
        }

        log.info("Diff sync complete: \(pagesToUpsert.count) upserted, \(toDelete.count) deleted")
    }

    // MARK: - Diff Sync Helpers (synchronous)

    /// Fetch all (id, updatedAt) from GRDB for diff comparison.
    private nonisolated func fetchAllTimestamps() throws -> [String: Double] {
        try dbPool.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT id, updatedAt FROM indexed_pages")
            var dict: [String: Double] = [:]
            for row in rows {
                let id: String = row["id"]
                let ts: Double = row["updatedAt"]
                dict[id] = ts
            }
            return dict
        }
    }

    /// Delete a set of page IDs from the GRDB index.
    private nonisolated func deletePages(ids: Set<String>) throws {
        try dbPool.write { db in
            for id in ids {
                try db.execute(sql: "DELETE FROM indexed_pages WHERE id = ?", arguments: [id])
            }
        }
    }

    // MARK: - FTS5 Query Sanitization

    private func offload<T: Sendable>(_ operation: @Sendable @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            workQueue.async {
                do {
                    continuation.resume(returning: try operation())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func offloadSearch<T: Sendable>(
        _ operation: @Sendable @escaping (OffloadedSearchCancellationProbe) throws -> T
    ) async throws -> T {
        let stateBox = OffloadedSearchStateBox<T>()

        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                let currentState = OffloadedSearchState(continuation: continuation)
                stateBox.set(currentState)

                var workItem: DispatchWorkItem?
                workItem = DispatchWorkItem { [currentState] in
                    guard let workItem else { return }
                    guard !workItem.isCancelled else {
                        currentState.finish(with: .failure(CancellationError()))
                        return
                    }
                    do {
                        let cancellation = OffloadedSearchCancellationProbe {
                            currentState.isCancelled()
                        }
                        currentState.finish(with: .success(try operation(cancellation)))
                    } catch {
                        currentState.finish(with: .failure(error))
                    }
                }

                if let workItem {
                    currentState.bind(workItem: workItem)
                    queryQueue.async(execute: workItem)
                }
            }
        } onCancel: {
            stateBox.cancel()
        }
    }

    private nonisolated func searchPages(
        terms: [String],
        limit: Int,
        cancellation: OffloadedSearchCancellationProbe? = nil
    ) throws -> [SearchResult] {
        if let cancellation {
            try cancellation.check()
        }

        return try dbPool.read { db in
            if let cancellation {
                try cancellation.check()
            }

            return try Self.withSQLiteCancellation(db: db, cancellation: cancellation) {
                if supportsPageFTS5 {
                    let sanitized = Self.sanitizeFTS5Query(terms)
                    let rows = try Row.fetchAll(db, sql: """
                        SELECT
                            ip.id,
                            ip.title,
                            snippet(page_search, 1, '<b>', '</b>', '…', 32) AS snippet,
                            bm25(page_search, 5.0, 1.0, 2.0) AS rank
                        FROM page_search ps
                        JOIN indexed_pages ip ON ip.rowid = ps.rowid
                        WHERE page_search MATCH ?
                        ORDER BY rank
                        LIMIT ?
                    """, arguments: [sanitized, limit])

                    if let cancellation {
                        try cancellation.check()
                    }

                    return rows.map { row in
                        SearchResult(
                            pageId: row["id"],
                            title: row["title"],
                            snippet: row["snippet"] ?? "",
                            rank: row["rank"] ?? 0.0
                        )
                    }
                }

                if let cancellation {
                    try cancellation.check()
                }
                return try Self.searchPagesFallback(db, terms: terms, limit: limit)
            }
        }
    }

    private nonisolated func searchBlocks(
        terms: [String],
        limit: Int,
        cancellation: OffloadedSearchCancellationProbe? = nil
    ) throws -> [BlockSearchResult] {
        if let cancellation {
            try cancellation.check()
        }

        return try dbPool.read { db in
            if let cancellation {
                try cancellation.check()
            }

            return try Self.withSQLiteCancellation(db: db, cancellation: cancellation) {
                if supportsBlockFTS5 {
                    let sanitized = Self.sanitizeFTS5Query(terms)
                    let rows = try Row.fetchAll(db, sql: """
                        SELECT
                            ib.block_id,
                            ib.page_id,
                            snippet(block_search, 0, '<b>', '</b>', '…', 32) AS snippet,
                            bm25(block_search) AS rank
                        FROM block_search bs
                        JOIN indexed_blocks ib ON ib.rowid = bs.rowid
                        WHERE block_search MATCH ?
                        ORDER BY rank
                        LIMIT ?
                    """, arguments: [sanitized, limit])

                    if let cancellation {
                        try cancellation.check()
                    }

                    return rows.map { row in
                        BlockSearchResult(
                            blockId: row["block_id"],
                            pageId: row["page_id"],
                            snippet: row["snippet"] ?? "",
                            rank: row["rank"] ?? 0.0
                        )
                    }
                }

                if let cancellation {
                    try cancellation.check()
                }
                return try Self.searchBlocksFallback(db, terms: terms, limit: limit)
            }
        }
    }

    private nonisolated static func withSQLiteCancellation<T>(
        db: Database,
        cancellation: OffloadedSearchCancellationProbe?,
        _ operation: () throws -> T
    ) throws -> T {
        guard let cancellation, let sqliteConnection = db.sqliteConnection else {
            return try operation()
        }

        let context = Unmanaged.passRetained(
            SQLiteCancellationContext(isCancelled: cancellation.isCancelled)
        )
        sqlite3_progress_handler(
            sqliteConnection,
            1_000,
            { rawContext in
                guard let rawContext else { return 0 }
                let context = Unmanaged<SQLiteCancellationContext>
                    .fromOpaque(rawContext)
                    .takeUnretainedValue()
                return context.isCancelled() ? 1 : 0
            },
            context.toOpaque()
        )
        defer {
            sqlite3_progress_handler(sqliteConnection, 0, nil, nil)
            context.release()
        }

        return try operation()
    }

    private nonisolated static func searchPagesFallback(
        _ db: Database,
        terms: [String],
        limit: Int
    ) throws -> [SearchResult] {
        let filter = likeFilter(columns: ["title", "body", "coalesce(tags, '')"], terms: terms)
        let rows = try Row.fetchAll(db, sql: """
            SELECT
                id,
                title,
                CASE
                    WHEN body = '' THEN title
                    ELSE substr(body, 1, 160)
                END AS snippet,
                updatedAt AS rank
            FROM indexed_pages
            WHERE \(filter.sql)
            ORDER BY updatedAt DESC
            LIMIT ?
        """, arguments: StatementArguments(filter.arguments + [limit]))

        return rows.map { row in
            SearchResult(
                pageId: row["id"],
                title: row["title"],
                snippet: row["snippet"] ?? "",
                rank: row["rank"] ?? 0.0
            )
        }
    }

    private nonisolated static func searchBlocksFallback(
        _ db: Database,
        terms: [String],
        limit: Int
    ) throws -> [BlockSearchResult] {
        let filter = likeFilter(columns: ["content"], terms: terms)
        let rows = try Row.fetchAll(db, sql: """
            SELECT
                block_id,
                page_id,
                substr(content, 1, 160) AS snippet
            FROM indexed_blocks
            WHERE \(filter.sql)
            ORDER BY rowid DESC
            LIMIT ?
        """, arguments: StatementArguments(filter.arguments + [limit]))

        return rows.map { row in
            BlockSearchResult(
                blockId: row["block_id"],
                pageId: row["page_id"],
                snippet: row["snippet"] ?? "",
                rank: 0.0
            )
        }
    }

    private nonisolated static func likeFilter(
        columns: [String],
        terms: [String]
    ) -> (sql: String, arguments: [String]) {
        var clauses: [String] = []
        var arguments: [String] = []
        clauses.reserveCapacity(terms.count)
        arguments.reserveCapacity(terms.count * columns.count)

        for term in terms {
            let columnClause = columns
                .map { "lower(\($0)) LIKE ?" }
                .joined(separator: " OR ")
            clauses.append("(\(columnClause))")
            let pattern = "%\(term)%"
            for _ in columns {
                arguments.append(pattern)
            }
        }

        return (clauses.joined(separator: " AND "), arguments)
    }

    private nonisolated static func normalizedSearchTerms(_ raw: String) -> [String] {
        let capped = raw.count > 500 ? String(raw.prefix(500)) : raw
        return Array(
            capped.lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { $0.count >= 2 }
                .map { $0.replacingOccurrences(of: "\"", with: "") }
                .filter { !$0.isEmpty }
                .prefix(20)
        )
    }

    nonisolated static func sanitizeFTS5Query(_ raw: String) -> String {
        sanitizeFTS5Query(normalizedSearchTerms(raw))
    }

    private nonisolated static func sanitizeFTS5Query(_ terms: [String]) -> String {
        guard !terms.isEmpty else { return "" }
        return terms.map { "\"\($0)\"*" }.joined(separator: " ")
    }
}

// MARK: - SearchResult

nonisolated struct SearchResult: Sendable {
    let pageId: String
    let title: String
    let snippet: String
    let rank: Double
}

// MARK: - BlockSearchResult

nonisolated struct BlockSearchResult: Sendable {
    let blockId: String
    let pageId: String
    let snippet: String
    let rank: Double
}
