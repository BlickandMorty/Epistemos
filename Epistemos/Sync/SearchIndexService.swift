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
    case diffVerificationFailed(expectedPageCount: Int, actualPageCount: Int, remainingOrphanBlockCount: Int)
    case duplicateRequiredPage(String)
    case noAppSupportDirectory
    case integrityCheckFailed(String)
    case journalModeRejected(String)
    case missingRequiredPage(String)
    case recoveryReopenFailed(String)
}

private nonisolated func searchIndexChangedDependencies(
    pagesChanged: Bool,
    blocksChanged: Bool
) -> Set<QueryDependencyKey> {
    var dependencies = Set<QueryDependencyKey>()
    if pagesChanged {
        dependencies.insert(.searchPages)
    }
    if blocksChanged {
        dependencies.insert(.searchBlocks)
    }
    return dependencies
}

nonisolated struct SearchIndexMutationReceipt: Sendable, Equatable {
    let upsertedPageCount: Int
    let deletedPageCount: Int
    let upsertedBlockCount: Int
    let deletedBlockCount: Int

    static let empty = SearchIndexMutationReceipt(
        upsertedPageCount: 0,
        deletedPageCount: 0,
        upsertedBlockCount: 0,
        deletedBlockCount: 0
    )

    var changedDependencies: Set<QueryDependencyKey> {
        searchIndexChangedDependencies(
            pagesChanged: upsertedPageCount > 0 || deletedPageCount > 0,
            blocksChanged: upsertedBlockCount > 0 || deletedBlockCount > 0
        )
    }

    func merging(_ other: SearchIndexMutationReceipt) -> SearchIndexMutationReceipt {
        SearchIndexMutationReceipt(
            upsertedPageCount: upsertedPageCount + other.upsertedPageCount,
            deletedPageCount: deletedPageCount + other.deletedPageCount,
            upsertedBlockCount: upsertedBlockCount + other.upsertedBlockCount,
            deletedBlockCount: deletedBlockCount + other.deletedBlockCount
        )
    }
}

nonisolated struct SearchIndexDiffReceipt: Sendable, Equatable {
    let sourcePageCount: Int
    let upsertedPageCount: Int
    let deletedPageCount: Int
    let deletedBlockCount: Int
    let finalIndexedPageCount: Int
    let finalIndexedBlockCount: Int
    let remainingOrphanBlockCount: Int

    var mutationReceipt: SearchIndexMutationReceipt {
        SearchIndexMutationReceipt(
            upsertedPageCount: upsertedPageCount,
            deletedPageCount: deletedPageCount,
            upsertedBlockCount: 0,
            deletedBlockCount: deletedBlockCount
        )
    }

    var changedDependencies: Set<QueryDependencyKey> {
        mutationReceipt.changedDependencies
    }
}

nonisolated struct SearchIndexSynchronizationReceipt: Sendable, Equatable {
    let suppressedImport: SearchIndexMutationReceipt
    let diff: SearchIndexDiffReceipt

    var total: SearchIndexMutationReceipt {
        suppressedImport.merging(diff.mutationReceipt)
    }

    var changedDependencies: Set<QueryDependencyKey> {
        total.changedDependencies
    }
}

nonisolated struct SearchIndexPageDeletionReceipt: Sendable, Equatable {
    let deletedPageCount: Int
    let deletedBlockCount: Int

    var mutationReceipt: SearchIndexMutationReceipt {
        SearchIndexMutationReceipt(
            upsertedPageCount: 0,
            deletedPageCount: deletedPageCount,
            upsertedBlockCount: 0,
            deletedBlockCount: deletedBlockCount
        )
    }

    var changedDependencies: Set<QueryDependencyKey> {
        mutationReceipt.changedDependencies
    }
}

nonisolated struct SearchIndexIntegrityDiagnostics: Sendable, Equatable {
    let databasePath: String
    let quickCheck: String
    let integrityCheck: String
    let manifest: [String: String]

    var isHealthy: Bool {
        quickCheck == "ok" && integrityCheck == "ok"
    }
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

    private struct PreparedDatabase: Sendable {
        let databaseURL: URL
        let dbPool: DatabasePool
        let features: SearchIndexFeatures
        let quarantinedFiles: [URL]
    }

    private nonisolated static let staticLog = Logger(subsystem: "com.epistemos", category: "SearchIndex")
    private nonisolated static let bulkCheckpointThreshold = 512
    private nonisolated static let manifestMigrationKey = "v4_keelstone_index_manifest"
    private let log = Logger(subsystem: "com.epistemos", category: "SearchIndex")
    nonisolated private let databaseURL: URL
    nonisolated private let dbPool: DatabasePool
    nonisolated private let workQueue: DispatchQueue
    nonisolated private let queryQueue: DispatchQueue
    nonisolated private let supportsPageFTS5: Bool
    nonisolated private let supportsBlockFTS5: Bool
    nonisolated private let supportsReadableBlocksFTS5: Bool
#if DEBUG
    nonisolated private let forceTruncateCheckpointFailureForTesting = Mutex(false)
#endif

    init(
        databaseURL providedDatabaseURL: URL? = nil
    ) throws {
        let resolvedDatabaseURL: URL
        if let providedURL = providedDatabaseURL {
            let parent = providedURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            resolvedDatabaseURL = providedURL
        } else {
            let appSupport = FoundationSafety.userApplicationSupportDirectory(fileManager: .default)
                .appendingPathComponent("Epistemos", isDirectory: true)
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            resolvedDatabaseURL = appSupport.appendingPathComponent("search.sqlite")
        }
        let workQueue = DispatchQueue(label: "com.epistemos.search-index", qos: .userInitiated)
        let queryQueue = DispatchQueue(
            label: "com.epistemos.search-index.query",
            qos: .userInitiated,
            attributes: .concurrent
        )
        let prepared = try Self.openPreparedDatabaseWithRecovery(at: resolvedDatabaseURL)

        self.databaseURL = resolvedDatabaseURL
        self.dbPool = prepared.dbPool
        self.workQueue = workQueue
        self.queryQueue = queryQueue
        supportsPageFTS5 = prepared.features.pageFTS5
        supportsBlockFTS5 = prepared.features.blockFTS5
        supportsReadableBlocksFTS5 = prepared.features.readableBlocksFTS5
        log.info(
            "SearchIndexService initialized at \(resolvedDatabaseURL.path, privacy: .public) fts5_pages=\(prepared.features.pageFTS5) fts5_blocks=\(prepared.features.blockFTS5) fts5_readable_blocks=\(prepared.features.readableBlocksFTS5)"
        )
        if !prepared.quarantinedFiles.isEmpty {
            log.warning(
                "SearchIndexService recovered by quarantining \(prepared.quarantinedFiles.count, privacy: .public) derived database file(s); vault files remain source of truth"
            )
        }
    }

    // MARK: - Schema Migration

    private struct SearchIndexFeatures: Sendable {
        let pageFTS5: Bool
        let blockFTS5: Bool
        let readableBlocksFTS5: Bool
    }

    private nonisolated static func openPreparedDatabaseWithRecovery(at databaseURL: URL) throws -> PreparedDatabase {
        do {
            let prepared = try openPreparedDatabase(at: databaseURL)
            return PreparedDatabase(
                databaseURL: prepared.databaseURL,
                dbPool: prepared.dbPool,
                features: prepared.features,
                quarantinedFiles: []
            )
        } catch {
            staticLog.error(
                "SearchIndexService open/migrate/check failed for \(databaseURL.path, privacy: .public): \(String(describing: error), privacy: .public). Quarantining derived index and rebuilding from vault cache."
            )
            let quarantinedFiles = try quarantineDerivedDatabaseFiles(at: databaseURL, reason: error)
            do {
                let prepared = try openPreparedDatabase(at: databaseURL)
                return PreparedDatabase(
                    databaseURL: prepared.databaseURL,
                    dbPool: prepared.dbPool,
                    features: prepared.features,
                    quarantinedFiles: quarantinedFiles
                )
            } catch {
                throw SearchIndexError.recoveryReopenFailed(String(describing: error))
            }
        }
    }

    private nonisolated static func openPreparedDatabase(at databaseURL: URL) throws -> PreparedDatabase {
        let dbPool = try DatabasePool(
            path: databaseURL.path,
            configuration: Self.databaseConfiguration()
        )
        try setupSchema(dbPool)
        try refreshDatabaseFileProtections(databaseURL)
        let features = try detectFeatures(dbPool)
        return PreparedDatabase(
            databaseURL: databaseURL,
            dbPool: dbPool,
            features: features,
            quarantinedFiles: []
        )
    }

    @discardableResult
    private nonisolated static func quarantineDerivedDatabaseFiles(
        at databaseURL: URL,
        reason: Error,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        let parent = databaseURL.deletingLastPathComponent()
        let quarantineDirectory = parent.appendingPathComponent("search-index-quarantine", isDirectory: true)
        try fileManager.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)

        let stamp = "\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString)"
        let liveFiles = [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm"),
        ]
        var moved: [URL] = []
        for fileURL in liveFiles where fileManager.fileExists(atPath: fileURL.path) {
            let targetName = "\(databaseURL.lastPathComponent).\(stamp).\(fileURL.lastPathComponent)"
            let targetURL = quarantineDirectory.appendingPathComponent(targetName)
            try fileManager.moveItem(at: fileURL, to: targetURL)
            moved.append(targetURL)
        }

        staticLog.warning(
            "Quarantined \(moved.count, privacy: .public) derived search-index file(s) after \(String(describing: reason), privacy: .public)"
        )
        return moved
    }

    private nonisolated static func databaseConfiguration() -> Configuration {
        var config = Configuration()
        config.prepareDatabase { db in
            RRFFusionQuery.installSQLiteFunctions(in: db)

            // Wave 2.3 canonical GRDB pragma block (dpp §1.1 Task 0.3).
            //
            // ZERO_CORRUPTION_SPEC interaction (FINAL DOCS/1. CORRUPTION §1.1):
            // The spec mandates F_FULLFSYNC (fcntl 51) for ACID-critical writes, and
            // notes that Apple's bundled SQLite silently replaces F_FULLFSYNC with
            // F_BARRIERFSYNC even when `PRAGMA fullfsync = ON` is set — i.e. system
            // SQLite cannot deliver true power-loss durability regardless of the
            // pragma. This SearchIndexService is a *derivative* full-text index
            // rebuildable from SwiftData + the vault (`rebuildFromSwiftData`,
            // `diffSync`); source-of-truth durability lives in the atomic file-write
            // layer per ZERO_CORRUPTION §1.2, not in this FTS5 cache. We therefore
            // adopt the dpp NORMAL/fullfsync=0 profile here for ~3–5× write
            // throughput; the spec's FULL+F_FULLFSYNC requirement still applies to
            // any future store that owns user source-of-truth bytes.
            // Memory-budget: this is a *derivative* FTS5 index (rebuildable
            // via `rebuildFromSwiftData` / `diffSync`), so we should NOT
            // anchor large amounts of resident memory on its behalf. The
            // dpp profile sized for the SoT store was inherited here by
            // copy-paste; trim aggressively for idle memory:
            //   - mmap_size 1 GiB → 256 MiB (kernel page cache fills any
            //     gap on hot reads via OS readahead — FTS5 sequential
            //     scans benefit more from page cache than per-DB cache)
            //   - cache_size 64 MiB → 8 MiB (pure resident savings; the
            //     B-tree indexed FTS rowid fetches are cheap to refault)
            // ~55 MB resident saved at idle on a vault that has the index
            // open. Cold-query latency may regress 5–15 ms; warm-query
            // latency unchanged (page cache absorbs).
            try db.execute(sql: """
                PRAGMA journal_mode = WAL;
                PRAGMA synchronous = NORMAL;
                PRAGMA temp_store = MEMORY;
                PRAGMA mmap_size = 268435456;
                PRAGMA cache_size = -8192;
                PRAGMA page_size = 4096;
                PRAGMA foreign_keys = ON;
                PRAGMA wal_autocheckpoint = 1000;
                PRAGMA fullfsync = 0;
                PRAGMA checkpoint_fullfsync = 0;
            """)

            if !db.configuration.readonly {
                try db.execute(sql: "PRAGMA optimize;")
            }

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

    /// Audit gap F8 close-out (per
    /// `docs/audits/T+4_T+5_DEEP_AUDIT_2026-04-27.md`) + plan §225
    /// ("Existing page_search + block_search tables continue to
    /// serve current Prose-only search; readable_blocks is the new
    /// universal projection that absorbs Documents + Raw Thoughts +
    /// Code + Source"). Hosts pass this writer to
    /// `EpistemosDocumentController(databaseWriter:)` so .epdoc
    /// saves refresh the universal FTS index in the same SQLite
    /// schema as the prose indices.
    ///
    /// Returning the underlying `DatabasePool` (which conforms to
    /// `DatabaseWriter`) keeps the cross-index ranking story whole:
    /// future RRF fusion across `page_search` + `block_search` +
    /// `readable_blocks` becomes a one-DB JOIN rather than an
    /// in-memory merge across pools.
    nonisolated public func databaseWriter() -> any DatabaseWriter {
        dbPool
    }

    /// Drop SQLite-side caches and ask GRDB to release any unused
    /// connections in the pool. Wired from the global memory-pressure
    /// handler in `EpistemosApp.RuntimeDiagnosticsMonitor.recordMemoryPressure`
    /// so a `.warning` event sheds page cache + idle connection slots
    /// without forcing a vacuum (vacuum is too expensive for the warning
    /// tier; reserve it for `.critical` if added later).
    ///
    /// - `PRAGMA optimize` — runs accumulated query-planner stats updates
    /// - `PRAGMA shrink_memory` — releases page cache held by this conn
    /// - `dbPool.releaseMemory()` — closes idle reader connections
    ///
    /// Best-effort; failures are logged and swallowed so memory-pressure
    /// recovery never throws back into the AppKit event loop.
    nonisolated public func releaseMemoryPressureCaches() {
        do {
            try dbPool.write { db in
                try db.execute(sql: "PRAGMA optimize;")
                try db.execute(sql: "PRAGMA shrink_memory;")
            }
            dbPool.releaseMemory()
        } catch {
            log.warning(
                "SearchIndexService: releaseMemoryPressureCaches failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    nonisolated func quickCheckForDiagnostics() throws -> String {
        try dbPool.read { db in
            try String.fetchOne(db, sql: "PRAGMA quick_check") ?? "unknown"
        }
    }

    nonisolated func integrityCheckForDiagnostics() throws -> String {
        try dbPool.read { db in
            try String.fetchOne(db, sql: "PRAGMA integrity_check") ?? "unknown"
        }
    }

    nonisolated func supportDiagnostics() throws -> SearchIndexIntegrityDiagnostics {
        let snapshot = try dbPool.read { db -> SearchIndexIntegrityDiagnostics in
            let quickCheck = try String.fetchOne(db, sql: "PRAGMA quick_check") ?? "unknown"
            let integrityCheck = try String.fetchOne(db, sql: "PRAGMA integrity_check") ?? "unknown"
            let manifest: [String: String]
            if try Self.tableExists("derived_index_manifest", db: db) {
                let rows = try Row.fetchAll(
                    db,
                    sql: "SELECT key, value FROM derived_index_manifest ORDER BY key"
                )
                manifest = Dictionary(
                    uniqueKeysWithValues: rows.map { row in
                        let key: String = row["key"]
                        let value: String = row["value"]
                        return (key, value)
                    }
                )
            } else {
                manifest = [:]
            }
            return SearchIndexIntegrityDiagnostics(
                databasePath: databaseURL.path,
                quickCheck: quickCheck,
                integrityCheck: integrityCheck,
                manifest: manifest
            )
        }
        return snapshot
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

        // Audit gap F8 close-out + implementation plan §225 — the
        // `readable_blocks` universal projection ships in the same
        // SQLite schema so the .epdoc autosave path can refresh it
        // in the same transaction as a future cross-index rewrite.
        // Migration key = "v3_readable_blocks" (defined as
        // `ReadableBlocksIndex.migrationKey`); idempotent across
        // process restarts.
        ReadableBlocksIndex.registerMigration(&migrator)

        migrator.registerMigration(manifestMigrationKey) { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS derived_index_manifest (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL,
                    updated_at REAL NOT NULL
                )
            """)
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
            } else {
                let hadReadableBlocksFTS = try tableExists("readable_blocks_fts", db: db)
                try createPageSearchArtifactsIfAvailable(db)
                try createBlockSearchArtifactsIfAvailable(db)
                try ReadableBlocksIndex.installFTSAndTriggersIfAvailable(in: db)
                if !hadReadableBlocksFTS,
                   try tableExists("readable_blocks_fts", db: db) {
                    try ReadableBlocksIndex.rebuildFTSIndexIfAvailable(in: db)
                }
            }

            let pageFTS5 = fts5Available ? try tableExists("page_search", db: db) : false
            let blockFTS5 = fts5Available ? try tableExists("block_search", db: db) : false
            let readableBlocksFTS5 = fts5Available ? try tableExists("readable_blocks_fts", db: db) : false
            return SearchIndexFeatures(
                pageFTS5: pageFTS5,
                blockFTS5: blockFTS5,
                readableBlocksFTS5: readableBlocksFTS5
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
        try db.execute(sql: "DROP TRIGGER IF EXISTS readable_blocks_ai")
        try db.execute(sql: "DROP TRIGGER IF EXISTS readable_blocks_ad")
        try db.execute(sql: "DROP TRIGGER IF EXISTS readable_blocks_au")
    }

    // MARK: - Search
    // nonisolated: DatabasePool is Sendable and let-bound, safe to access without actor hop.

    nonisolated func search(query: String, limit: Int = 50) throws -> [SearchResult] {
        let checkedLimit = try SearchRequestBounds.validatedResultLimit(limit)
        guard let checkedQuery = try SearchRequestBounds.validatedQuery(query) else { return [] }
        // Wave 2.1 canonical perf signpost (subsystem io.epistemos.core / storage).
        // Wraps the FTS5 page search dispatch. Per dpp §1.1 Task 0.1.
        // begin/defer-end pattern (not closure wrapper) for TSAN safety.
        let signpostId = Sig.storage.makeSignpostID()
        let state = Sig.storage.beginInterval("search", id: signpostId)
        defer { Sig.storage.endInterval("search", state) }

        let terms = Self.normalizedSearchTerms(checkedQuery)
        guard !terms.isEmpty else { return [] }
        return try searchPages(terms: terms, limit: checkedLimit)
    }

    func searchAsync(query: String, limit: Int = 50) async throws -> [SearchResult] {
        let checkedLimit = try SearchRequestBounds.validatedResultLimit(limit)
        guard let checkedQuery = try SearchRequestBounds.validatedQuery(query) else { return [] }
        let terms = Self.normalizedSearchTerms(checkedQuery)
        guard !terms.isEmpty else { return [] }
        if Task.isCancelled {
            throw CancellationError()
        }

        return try await offloadSearch { [self, terms, checkedLimit] cancellation in
            try cancellation.check()
            let signpostId = Sig.storage.makeSignpostID()
            let state = Sig.storage.beginInterval("search", id: signpostId)
            defer { Sig.storage.endInterval("search", state) }
            return try searchPages(terms: terms, limit: checkedLimit, cancellation: cancellation)
        }
    }

    // MARK: - Block Search

    nonisolated func searchBlocks(query: String, limit: Int = 50) throws -> [BlockSearchResult] {
        let checkedLimit = try SearchRequestBounds.validatedResultLimit(limit)
        guard let checkedQuery = try SearchRequestBounds.validatedQuery(query) else { return [] }
        let terms = Self.normalizedSearchTerms(checkedQuery)
        guard !terms.isEmpty else { return [] }
        return try searchBlocks(terms: terms, limit: checkedLimit)
    }

    func searchBlocksAsync(query: String, limit: Int = 50) async throws -> [BlockSearchResult] {
        let checkedLimit = try SearchRequestBounds.validatedResultLimit(limit)
        guard let checkedQuery = try SearchRequestBounds.validatedQuery(query) else { return [] }
        let terms = Self.normalizedSearchTerms(checkedQuery)
        guard !terms.isEmpty else { return [] }
        if Task.isCancelled {
            throw CancellationError()
        }

        return try await offloadSearch { [self, terms, checkedLimit] cancellation in
            try cancellation.check()
            return try searchBlocks(terms: terms, limit: checkedLimit, cancellation: cancellation)
        }
    }

    // MARK: - RRF Cross-Index Fusion (Phase 3)
    //
    // `fusedSearch` is a single-SQL Reciprocal Rank Fusion over three
    // FTS5 sources (page_search, block_search, readable_blocks_fts)
    // sharing this actor's `dbPool` (F8 close-out). The query lives in
    // `RRFFusionQuery.sql`; this method wraps it with the actor's
    // `Sig.storage` signpost ceremony (F10 close-out for the search
    // path) + the same nonisolated/async pair as the legacy methods.
    //
    // Phase 4 wiring sites switch from `search()` / `searchBlocks()` to
    // `fusedSearch()` behind the `EPISTEMOS_RRF_FUSION_V1` flag (read
    // via `RRFFusionFlags.isEnabled`).
    //
    // F9 (MutationEnvelope retrieval-event emission) is INTENTIONALLY
    // deferred from Phase 3: the existing `MutationEnvelope` schema is
    // write-side (SourceOp = artifact_create/update/delete/...) with no
    // retrieval variant. Adding a retrieval variant requires a Rust
    // parity-locked schema change and is tracked under §9 item 3 of
    // `docs/RRF_FUSION_DESIGN.md` for the T+13 hardening pass.

    /// Fused search across page-level prose, block-level prose, and
    /// the universal `readable_blocks` projection. Returns up to
    /// `weights.maxResults` ranked entities (deduplicated at the
    /// parent-doc level). Synchronous; `dbPool.read` is GRDB's
    /// own thread-safe entry.
    nonisolated public func fusedSearch(
        query: String,
        weights: FusionWeights = .default,
        now: Date = Date()
    ) throws -> [FusedResult] {
        let validatedWeights = try weights.validated(now: now)
        guard let checkedQuery = try SearchRequestBounds.validatedQuery(query) else {
            Self.recordEmptyFusedSearchMetricsSnapshot()
            return []
        }
        let signpostId = Sig.storage.makeSignpostID()
        let state = Sig.storage.beginInterval("fused_search", id: signpostId)
        defer { Sig.storage.endInterval("fused_search", state) }

        let terms = Self.normalizedSearchTerms(checkedQuery)
        guard !terms.isEmpty else {
            Self.recordEmptyFusedSearchMetricsSnapshot()
            return []
        }
        let sanitized = Self.sanitizeFTS5Query(terms)
        let startTime = DispatchTime.now()

        do {
            let results = try dbPool.read { db in
                let includePageSearch = try Self.tableExists("page_search", db: db)
                let includeBlockSearch = try Self.tableExists("block_search", db: db)
                let includeReadableBlocks = try Self.tableExists("readable_blocks_fts", db: db)
                guard includePageSearch, includeBlockSearch else {
                    return try Self.fusedSearchFallback(
                        terms: terms,
                        weights: validatedWeights,
                        now: now,
                        in: db
                    )
                }
                return try RRFFusionQuery.execute(
                    query: sanitized,
                    weights: validatedWeights,
                    now: now,
                    includeReadableBlocks: includeReadableBlocks,
                    in: db
                )
            }
            let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds &- startTime.uptimeNanoseconds) / 1_000_000.0
            SearchFusionMetrics.shared.record(latencyMs: elapsedMs, results: results)
            return results
        } catch {
            SearchFusionMetrics.shared.recordError(error)
            throw error
        }
    }

    /// Async variant offloaded onto the `queryQueue` with cooperative
    /// cancellation (matches `searchAsync` / `searchBlocksAsync`).
    public func fusedSearchAsync(
        query: String,
        weights: FusionWeights = .default,
        now: Date = Date()
    ) async throws -> [FusedResult] {
        let validatedWeights = try weights.validated(now: now)
        guard let checkedQuery = try SearchRequestBounds.validatedQuery(query) else {
            Self.recordEmptyFusedSearchMetricsSnapshot()
            return []
        }
        let terms = Self.normalizedSearchTerms(checkedQuery)
        guard !terms.isEmpty else {
            Self.recordEmptyFusedSearchMetricsSnapshot()
            return []
        }
        let sanitized = Self.sanitizeFTS5Query(terms)
        if Task.isCancelled {
            throw CancellationError()
        }

        return try await offloadSearch { [self, sanitized, validatedWeights, now] cancellation in
            try cancellation.check()
            let signpostId = Sig.storage.makeSignpostID()
            let state = Sig.storage.beginInterval("fused_search", id: signpostId)
            defer { Sig.storage.endInterval("fused_search", state) }

            let startTime = DispatchTime.now()

            do {
                let results = try dbPool.read { db in
                    return try Self.withSQLiteCancellation(db: db, cancellation: cancellation) {
                        let includePageSearch = try Self.tableExists("page_search", db: db)
                        let includeBlockSearch = try Self.tableExists("block_search", db: db)
                        let includeReadableBlocks = try Self.tableExists("readable_blocks_fts", db: db)
                        guard includePageSearch, includeBlockSearch else {
                            return try Self.fusedSearchFallback(
                                terms: terms,
                                weights: validatedWeights,
                                now: now,
                                in: db
                            )
                        }
                        return try RRFFusionQuery.execute(
                            query: sanitized,
                            weights: validatedWeights,
                            now: now,
                            includeReadableBlocks: includeReadableBlocks,
                            in: db
                        )
                    }
                }
                let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds &- startTime.uptimeNanoseconds) / 1_000_000.0
                SearchFusionMetrics.shared.record(latencyMs: elapsedMs, results: results)
                return results
            } catch {
                SearchFusionMetrics.shared.recordError(error)
                throw error
            }
        }
    }

    private nonisolated static func millisecondsSinceEpoch(_ date: Date) -> Int64 {
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite else { return 0 }
        return Int64(milliseconds.rounded())
    }

    private nonisolated static func recordEmptyFusedSearchMetricsSnapshot() {
        SearchFusionMetrics.shared.record(latencyMs: 0, results: [])
    }

    // MARK: - Block Upsert / Delete

    nonisolated func upsertBlock(blockId: String, pageId: String, content: String) throws {
        try dbPool.write { db in
            // Wave 2.3 dpp §1.1 Task 0.3 — cached prepared statement (hot path).
            let stmt = try db.cachedStatement(sql: """
                INSERT INTO indexed_blocks (block_id, page_id, content)
                VALUES (?, ?, ?)
                ON CONFLICT(block_id) DO UPDATE SET
                    page_id = excluded.page_id,
                    content = excluded.content
            """)
            stmt.setUncheckedArguments([blockId, pageId, content])
            try stmt.execute()
        }
        notifyIndexChanged([.searchBlocks])
    }

    nonisolated func deleteBlock(blockId: String) throws {
        try dbPool.write { db in
            // Wave 2.3 dpp §1.1 Task 0.3 — cached prepared statement (hot path).
            let stmt = try db.cachedStatement(sql: "DELETE FROM indexed_blocks WHERE block_id = ?")
            stmt.setUncheckedArguments([blockId])
            try stmt.execute()
        }
        notifyIndexChanged([.searchBlocks])
    }

    /// Atomically replace ALL block rows for a page: delete the page's prior rows,
    /// then insert its current SDBlock set. `block_search` (FTS5) is trigger-
    /// maintained on `indexed_blocks`, so the ad/ai triggers keep the FTS mirror
    /// consistent. This is the block-index write seam: previously `indexed_blocks`
    /// had NO production writer, so block search + the RRF `block` source returned
    /// empty. Derivative index — a failure here degrades block search only, and
    /// self-heals on the next save. Block ids are the stable SDBlock.id so
    /// "jump to block" from a search hit resolves.
    @discardableResult
    nonisolated func replaceBlocksForPage(
        pageId: String,
        blocks: [(blockId: String, content: String)],
        notifyObservers: Bool = true
    ) throws -> SearchIndexMutationReceipt {
        // RECONCILE, not truncate-reload. The incoming SDBlock.ids are STABLE across
        // edits (BlockMirror preserves them), so we touch only rows whose content
        // actually changed. indexed_blocks is external-content FTS5 with per-row
        // ai/ad triggers that re-tokenize on every INSERT/DELETE — so a blind
        // DELETE-all + INSERT-all made a save that changed 1 of N blocks pay ~2N
        // tokenizations. With this reconcile it pays ~2 (matters for the 100-500+
        // block long-form docs this index targets). End state is byte-identical to
        // the truncate-reload because the ids match.
        let changed = try dbPool.write { db -> (upserted: Int, deleted: Int) in
            var upsertedBlockCount = 0
            var deletedBlockCount = 0
            var existing: [String: String] = [:]
            let existingRows = try Row.fetchAll(
                db,
                sql: "SELECT block_id, content FROM indexed_blocks WHERE page_id = ?",
                arguments: [pageId]
            )
            for row in existingRows {
                let blockId: String = row["block_id"]
                let content: String = row["content"]
                existing[blockId] = content
            }
            let incomingIds = Set(blocks.map(\.blockId))
            // Drop rows whose block no longer exists on the page.
            for blockId in existing.keys where !incomingIds.contains(blockId) {
                try db.execute(sql: "DELETE FROM indexed_blocks WHERE block_id = ?", arguments: [blockId])
                deletedBlockCount += db.changesCount
            }
            // Insert new blocks; update only content-changed ones; skip unchanged
            // (their FTS rows are never re-tokenized).
            for block in blocks {
                if let current = existing[block.blockId] {
                    if current != block.content {
                        try db.execute(
                            sql: "UPDATE indexed_blocks SET content = ?, page_id = ? WHERE block_id = ?",
                            arguments: [block.content, pageId, block.blockId]
                        )
                        upsertedBlockCount += db.changesCount
                    }
                    // else: unchanged — leave the row (and its FTS entry) untouched.
                } else {
                    // New to this page. ON CONFLICT covers a block that moved in from
                    // another page: it keeps its stable id, gets this page_id.
                    try db.execute(
                        sql: """
                            INSERT INTO indexed_blocks (block_id, page_id, content)
                            VALUES (?, ?, ?)
                            ON CONFLICT(block_id) DO UPDATE SET
                                page_id = excluded.page_id,
                                content = excluded.content
                        """,
                        arguments: [block.blockId, pageId, block.content]
                    )
                    upsertedBlockCount += db.changesCount
                }
            }
            return (upsertedBlockCount, deletedBlockCount)
        }
        let receipt = SearchIndexMutationReceipt(
            upsertedPageCount: 0,
            deletedPageCount: 0,
            upsertedBlockCount: changed.upserted,
            deletedBlockCount: changed.deleted
        )
        // Only wake block-search observers when the index actually moved.
        if notifyObservers, !receipt.changedDependencies.isEmpty {
            notifyIndexChanged(receipt.changedDependencies)
        }
        return receipt
    }

    /// Remove all block rows for a page (on page delete) — the block-index analogue
    /// of `delete(pageId:)`.
    nonisolated func deleteBlocksForPage(pageId: String) throws {
        try dbPool.write { db in
            try db.execute(sql: "DELETE FROM indexed_blocks WHERE page_id = ?", arguments: [pageId])
        }
        notifyIndexChanged([.searchBlocks])
    }

    // MARK: - Upsert / Delete

    @discardableResult
    nonisolated func upsert(
        id: String,
        title: String,
        body: String,
        tags: String,
        updatedAt: Date,
        notifyObservers: Bool = true
    ) throws -> SearchIndexMutationReceipt {
        let upsertedPageCount = try dbPool.write { db in
            // Wave 2.3 dpp §1.1 Task 0.3 — cached prepared statement (hot path).
            let stmt = try db.cachedStatement(sql: """
                INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    title = excluded.title,
                    body = excluded.body,
                    tags = excluded.tags,
                    updatedAt = excluded.updatedAt
            """)
            stmt.setUncheckedArguments([id, title, body, tags, updatedAt.timeIntervalSinceReferenceDate])
            try stmt.execute()
            return db.changesCount
        }
        let receipt = SearchIndexMutationReceipt(
            upsertedPageCount: upsertedPageCount,
            deletedPageCount: 0,
            upsertedBlockCount: 0,
            deletedBlockCount: 0
        )
        if notifyObservers, !receipt.changedDependencies.isEmpty {
            notifyIndexChanged(receipt.changedDependencies)
        }
        return receipt
    }

    nonisolated func upsertPages(
        _ pages: [(id: String, title: String, body: String, tags: String, updatedAt: Date)],
        notifyObservers: Bool = true
    ) throws {
        guard !pages.isEmpty else { return }

        try dbPool.write { db in
            try upsertPages(pages, in: db)
        }
        if notifyObservers {
            notifyIndexChanged([.searchPages])
        }
    }

    @discardableResult
    nonisolated func delete(
        pageId: String,
        notifyObservers: Bool = true
    ) throws -> SearchIndexPageDeletionReceipt {
        let deleted = try dbPool.write { db in
            try Self.deletePageRows(ids: [pageId], in: db)
        }
        let receipt = SearchIndexPageDeletionReceipt(
            deletedPageCount: deleted.pages,
            deletedBlockCount: deleted.blocks
        )
        if notifyObservers, !receipt.changedDependencies.isEmpty {
            notifyIndexChanged(receipt.changedDependencies)
        }
        return receipt
    }

    // MARK: - Test Hooks

    /// Read a connection-scoped PRAGMA value through the live pool. Test-only
    /// surface for verifying the canonical pragma block (Wave 2.3).
    nonisolated func testReadPragmaInt(_ pragma: String) throws -> Int64 {
        try dbPool.read { db in
            try Int64.fetchOne(db, sql: "PRAGMA \(pragma)") ?? 0
        }
    }

    /// Read a connection-scoped PRAGMA value as String through the live pool.
    /// Test-only surface for verifying the canonical pragma block (Wave 2.3).
    nonisolated func testReadPragmaString(_ pragma: String) throws -> String? {
        try dbPool.read { db in
            try String.fetchOne(db, sql: "PRAGMA \(pragma)")
        }
    }

#if DEBUG
    nonisolated func setForceTruncateCheckpointFailureForTesting(_ enabled: Bool) {
        forceTruncateCheckpointFailureForTesting.withLock { forced in
            forced = enabled
        }
    }
#endif

    // MARK: - Maintenance

    nonisolated func passiveCheckpoint() throws {
        let stats = try dbPool.barrierWriteWithoutTransaction { db in
            try db.checkpoint(.passive)
        }
        log.info(
            "SearchIndexService passive checkpoint completed walFrames=\(stats.walFrameCount) checkpointed=\(stats.checkpointedFrameCount)"
        )
    }

    nonisolated func truncateCheckpoint() throws {
        let stats = try dbPool.barrierWriteWithoutTransaction { db in
#if DEBUG
            if forceTruncateCheckpointFailureForTesting.withLock({ $0 }) {
                throw NSError(
                    domain: "SearchIndexService.ForcedTruncateCheckpointFailure",
                    code: 1
                )
            }
#endif
            let stats = try db.checkpoint(.truncate)
            try Self.recordManifestValue(
                db,
                key: "last_truncate_checkpoint_at",
                value: String(Date().timeIntervalSinceReferenceDate)
            )
            return stats
        }
        log.info(
            "SearchIndexService truncate checkpoint completed walFrames=\(stats.walFrameCount) checkpointed=\(stats.checkpointedFrameCount)"
        )
    }

    // MARK: - Change Notification

    /// Post searchIndexDidUpdate on the main actor with the affected index domains.
    private nonisolated func notifyIndexChanged(_ dependencies: Set<QueryDependencyKey>) {
        Task {
            await notifyIndexChangedAsync(dependencies)
        }
    }

    @discardableResult
    nonisolated func notifyIndexChangedAsync(
        _ dependencies: Set<QueryDependencyKey>,
        when shouldNotify: (@MainActor @Sendable () -> Bool)? = nil
    ) async -> Bool {
        await MainActor.run {
            guard shouldNotify?() ?? true else { return false }
            NotificationCenter.default.post(
                name: .searchIndexDidUpdate,
                object: self,
                userInfo: QueryDependencyKey.userInfo(for: dependencies)
            )
            return true
        }
    }

    // MARK: - Full Rebuild

    nonisolated func rebuildFromSwiftData(
        _ pages: [(id: String, title: String, body: String, tags: String, updatedAt: Date)]
    ) throws {
        let deletedOrphanBlockCount = try dbPool.write { db -> Int in
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
            let deletedOrphanBlockCount = try Self.deleteOrphanBlockRows(in: db)
            try Self.recordManifestValue(
                db,
                key: "last_full_rebuild_page_count",
                value: String(pages.count)
            )
            try Self.recordManifestValue(
                db,
                key: "last_full_rebuild_at",
                value: String(Date().timeIntervalSinceReferenceDate)
            )
            return deletedOrphanBlockCount
        }
        do {
            try truncateCheckpoint()
        } catch {
            log.error(
                "Full rebuild committed but truncate checkpoint maintenance failed: \(String(describing: error), privacy: .public)"
            )
        }
        log.info("Rebuilt search index with \(pages.count) pages")
        notifyIndexChanged(searchIndexChangedDependencies(
            pagesChanged: true,
            blocksChanged: deletedOrphanBlockCount > 0
        ))
    }

    func rebuildFromSwiftDataAsync(
        _ pages: [(id: String, title: String, body: String, tags: String, updatedAt: Date)]
    ) async throws {
        try await offload { [self] in
            try rebuildFromSwiftData(pages)
        }
    }

    // MARK: - Diff Sync

    @discardableResult
    nonisolated func diffSync(
        swiftDataPages: [(id: String, updatedAt: Date)],
        fullPageProvider: @Sendable (String) async -> (title: String, body: String, tags: String, updatedAt: Date)?,
        notifyObservers: Bool = true
    ) async throws -> SearchIndexDiffReceipt {
        let grdbPages = try fetchAllTimestamps()

        var swiftDataIds = Set<String>()
        swiftDataIds.reserveCapacity(swiftDataPages.count)
        for page in swiftDataPages where !swiftDataIds.insert(page.id).inserted {
            throw SearchIndexError.duplicateRequiredPage(page.id)
        }
        let grdbIds = Set(grdbPages.keys)

        let toDelete = grdbIds.subtracting(swiftDataIds)

        // Resolve the complete replacement set before making any destructive
        // change. A missing source row means the projection is incomplete, so
        // deleting stale rows first would turn a recoverable read failure into
        // a partially-applied index.
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
                guard let full = await fullPageProvider(sd.id) else {
                    throw SearchIndexError.missingRequiredPage(sd.id)
                }
                pagesToUpsert.append((
                    id: sd.id,
                    title: full.title,
                    body: full.body,
                    tags: full.tags,
                    updatedAt: full.updatedAt
                ))
            }
        }

        let receipt = try applyDiff(
            sourcePageCount: swiftDataIds.count,
            deletingPageIDs: toDelete,
            upsertingPages: pagesToUpsert
        )
        if notifyObservers, !receipt.changedDependencies.isEmpty {
            await notifyIndexChangedAsync(receipt.changedDependencies)
        }

        if pagesToUpsert.count + toDelete.count >= Self.bulkCheckpointThreshold {
            do {
                try truncateCheckpoint()
            } catch {
                log.error(
                    "Diff sync committed but passive checkpoint maintenance failed: \(String(describing: error), privacy: .public)"
                )
            }
        }

        log.info(
            "Diff sync complete: \(receipt.upsertedPageCount) upserted, \(receipt.deletedPageCount) pages deleted, \(receipt.deletedBlockCount) blocks deleted"
        )
        return receipt
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

    private nonisolated func applyDiff(
        sourcePageCount: Int,
        deletingPageIDs: Set<String>,
        upsertingPages: [(id: String, title: String, body: String, tags: String, updatedAt: Date)]
    ) throws -> SearchIndexDiffReceipt {
        try dbPool.write { db in
            let deleted = try Self.deletePageRows(
                ids: deletingPageIDs.sorted(),
                in: db
            )
            let historicalOrphanBlockCount = try Self.deleteOrphanBlockRows(in: db)

            try upsertPages(upsertingPages, in: db)

            let finalPageCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM indexed_pages"
            ) ?? 0
            let finalBlockCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM indexed_blocks"
            ) ?? 0
            let remainingOrphanBlockCount = try Int.fetchOne(db, sql: """
                SELECT COUNT(*)
                FROM indexed_blocks
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM indexed_pages
                    WHERE indexed_pages.id = indexed_blocks.page_id
                )
            """) ?? 0
            guard finalPageCount == sourcePageCount,
                  remainingOrphanBlockCount == 0 else {
                throw SearchIndexError.diffVerificationFailed(
                    expectedPageCount: sourcePageCount,
                    actualPageCount: finalPageCount,
                    remainingOrphanBlockCount: remainingOrphanBlockCount
                )
            }

            return SearchIndexDiffReceipt(
                sourcePageCount: sourcePageCount,
                upsertedPageCount: upsertingPages.count,
                deletedPageCount: deleted.pages,
                deletedBlockCount: deleted.blocks + historicalOrphanBlockCount,
                finalIndexedPageCount: finalPageCount,
                finalIndexedBlockCount: finalBlockCount,
                remainingOrphanBlockCount: remainingOrphanBlockCount
            )
        }
    }

    private nonisolated static func deleteOrphanBlockRows(in db: Database) throws -> Int {
        try db.execute(sql: """
            DELETE FROM indexed_blocks
            WHERE NOT EXISTS (
                SELECT 1
                FROM indexed_pages
                WHERE indexed_pages.id = indexed_blocks.page_id
            )
        """)
        return db.changesCount
    }

    private nonisolated static func deletePageRows(
        ids: [String],
        in db: Database
    ) throws -> (pages: Int, blocks: Int) {
        guard !ids.isEmpty else { return (0, 0) }
        let blockStatement = try db.makeStatement(
            sql: "DELETE FROM indexed_blocks WHERE page_id = ?"
        )
        let pageStatement = try db.makeStatement(
            sql: "DELETE FROM indexed_pages WHERE id = ?"
        )
        var deletedPageCount = 0
        var deletedBlockCount = 0
        for id in ids {
            blockStatement.setUncheckedArguments([id])
            try blockStatement.execute()
            deletedBlockCount += db.changesCount

            pageStatement.setUncheckedArguments([id])
            try pageStatement.execute()
            deletedPageCount += db.changesCount
        }
        return (deletedPageCount, deletedBlockCount)
    }

    private nonisolated func upsertPages(
        _ pages: [(id: String, title: String, body: String, tags: String, updatedAt: Date)],
        in db: Database
    ) throws {
        guard !pages.isEmpty else { return }
        let statement: Statement
        do {
            statement = try db.makeStatement(sql: """
                INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    title = excluded.title,
                    body = excluded.body,
                    tags = excluded.tags,
                    updatedAt = excluded.updatedAt
            """)
        } catch {
            log.error(
                "SearchIndexService.upsertPages prepare failed: \(String(describing: error), privacy: .public)"
            )
            throw error
        }
        for page in pages {
            statement.setUncheckedArguments([
                page.id,
                page.title,
                page.body,
                page.tags,
                page.updatedAt.timeIntervalSinceReferenceDate,
            ])
            do {
                try statement.execute()
            } catch {
                log.error(
                    "SearchIndexService.upsertPages execute failed for id=\(page.id, privacy: .public): \(String(describing: error), privacy: .public)"
                )
                throw error
            }
        }
    }

    private nonisolated static func recordManifestValue(
        _ db: Database,
        key: String,
        value: String
    ) throws {
        try db.execute(
            sql: """
                INSERT INTO derived_index_manifest (key, value, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(key) DO UPDATE SET
                    value = excluded.value,
                    updated_at = excluded.updated_at
            """,
            arguments: [key, value, Date().timeIntervalSinceReferenceDate]
        )
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

    private nonisolated static func fusedSearchPagesFallback(
        _ db: Database,
        terms: [String],
        limit: Int
    ) throws -> [(result: SearchResult, updatedAtUnix: Double?)] {
        let filter = likeFilter(columns: ["title", "body", "coalesce(tags, '')"], terms: terms)
        let rows = try Row.fetchAll(db, sql: """
            SELECT
                id,
                title,
                CASE
                    WHEN body = '' THEN title
                    ELSE substr(body, 1, 160)
                END AS snippet,
                updatedAt
            FROM indexed_pages
            WHERE \(filter.sql)
            ORDER BY id ASC
            LIMIT ?
        """, arguments: StatementArguments(filter.arguments + [limit]))

        return rows.map { row in
            (
                result: SearchResult(
                    pageId: row["id"],
                    title: row["title"],
                    snippet: row["snippet"] ?? "",
                    rank: 0.0
                ),
                updatedAtUnix: unixTimestamp(fromReferenceDate: row["updatedAt"])
            )
        }
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

    private nonisolated static func fusedSearchFallback(
        terms: [String],
        weights: FusionWeights,
        now: Date,
        in db: Database
    ) throws -> [FusedResult] {
        let finalLimit = max(0, weights.maxResults)
        guard finalLimit > 0 else { return [] }
        let sourceLimit = max(finalLimit, weights.perSourceLimit)

        struct Accumulator {
            var entityKind: String
            var parentDocID: String
            var rawFusedScore: Double
            var bestSourceRank: Int64
            var snippetBlockID: String?
            var snippet: String?
            var updatedAtUnix: Double?
        }

        var rolledUp: [String: Accumulator] = [:]

        func merge(
            entityID: String,
            entityKind: String,
            sourceWeight: Double,
            sourceRank: Int,
            snippetBlockID: String?,
            snippet: String?,
            updatedAtUnix: Double?
        ) {
            let rank = Int64(sourceRank)
            let rawScore = sourceWeight / (Phase3FusionConsts.K_RRF + Double(sourceRank))
            if var existing = rolledUp[entityID] {
                existing.rawFusedScore += rawScore
                if let updatedAtUnix {
                    existing.updatedAtUnix = existing.updatedAtUnix.map {
                        max($0, updatedAtUnix)
                    } ?? updatedAtUnix
                }
                if rank < existing.bestSourceRank {
                    existing.entityKind = entityKind
                    existing.bestSourceRank = rank
                    existing.snippetBlockID = snippetBlockID
                    existing.snippet = snippet
                }
                rolledUp[entityID] = existing
            } else {
                rolledUp[entityID] = Accumulator(
                    entityKind: entityKind,
                    parentDocID: entityID,
                    rawFusedScore: rawScore,
                    bestSourceRank: rank,
                    snippetBlockID: snippetBlockID,
                    snippet: snippet,
                    updatedAtUnix: updatedAtUnix
                )
            }
        }

        func sourceWinners<Result>(
            _ results: [Result],
            pageID: (Result) -> String
        ) -> [(result: Result, sourceRank: Int)] {
            var seenPageIDs = Set<String>()
            var winners: [(result: Result, sourceRank: Int)] = []
            winners.reserveCapacity(results.count)

            for (offset, result) in results.enumerated() {
                guard seenPageIDs.insert(pageID(result)).inserted else { continue }
                winners.append((result: result, sourceRank: offset + 1))
            }

            return winners
        }

        for winner in sourceWinners(
            try fusedSearchPagesFallback(db, terms: terms, limit: sourceLimit),
            pageID: { $0.result.pageId }
        ) {
            let fallbackResult = winner.result
            let result = fallbackResult.result
            merge(
                entityID: result.pageId,
                entityKind: "page",
                sourceWeight: weights.pageWeight,
                sourceRank: winner.sourceRank,
                snippetBlockID: nil,
                snippet: result.snippet,
                updatedAtUnix: fallbackResult.updatedAtUnix
            )
        }

        for winner in sourceWinners(
            try fusedSearchBlocksFallback(db, terms: terms, limit: sourceLimit),
            pageID: { $0.result.pageId }
        ) {
            let fallbackResult = winner.result
            let result = fallbackResult.result
            merge(
                entityID: result.pageId,
                entityKind: "block",
                sourceWeight: weights.blockWeight,
                sourceRank: winner.sourceRank,
                snippetBlockID: result.blockId,
                snippet: result.snippet,
                updatedAtUnix: fallbackResult.updatedAtUnix
            )
        }

        return rolledUp
            .map { entityID, hit in
                FusedResult(
                    entityID: entityID,
                    entityKind: hit.entityKind,
                    parentDocID: hit.parentDocID,
                    fusedScore: recencyAdjustedScore(
                        rawScore: hit.rawFusedScore,
                        updatedAtUnix: hit.updatedAtUnix,
                        weights: weights,
                        now: now
                    ),
                    bestSourceRank: hit.bestSourceRank,
                    snippetBlockID: hit.snippetBlockID,
                    snippet: hit.snippet,
                    updatedAtUnix: hit.updatedAtUnix
                )
            }
            .sorted { lhs, rhs in
                guard lhs.fusedScore == rhs.fusedScore else {
                    return lhs.fusedScore > rhs.fusedScore
                }
                switch (lhs.updatedAtUnix, rhs.updatedAtUnix) {
                case let (left?, right?) where left != right:
                    return left > right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                default:
                    return lhs.entityID < rhs.entityID
                }
            }
            .prefix(finalLimit)
            .map { $0 }
    }

    private nonisolated static func fusedSearchBlocksFallback(
        _ db: Database,
        terms: [String],
        limit: Int
    ) throws -> [(result: BlockSearchResult, updatedAtUnix: Double?)] {
        let filter = likeFilter(columns: ["indexed_blocks.content"], terms: terms)
        let rows = try Row.fetchAll(db, sql: """
            SELECT
                indexed_blocks.block_id,
                indexed_blocks.page_id,
                substr(indexed_blocks.content, 1, 160) AS snippet,
                indexed_pages.updatedAt AS updatedAt
            FROM indexed_blocks
            LEFT JOIN indexed_pages ON indexed_pages.id = indexed_blocks.page_id
            WHERE \(filter.sql)
            ORDER BY indexed_blocks.page_id ASC, indexed_blocks.block_id ASC
            LIMIT ?
        """, arguments: StatementArguments(filter.arguments + [limit]))

        return rows.map { row in
            (
                result: BlockSearchResult(
                    blockId: row["block_id"],
                    pageId: row["page_id"],
                    snippet: row["snippet"] ?? "",
                    rank: 0.0
                ),
                updatedAtUnix: unixTimestamp(fromReferenceDate: row["updatedAt"])
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

    private nonisolated static func unixTimestamp(fromReferenceDate value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        let unixTimestamp = value + Date.timeIntervalBetween1970AndReferenceDate
        return unixTimestamp.isFinite ? unixTimestamp : nil
    }

    private nonisolated static func recencyAdjustedScore(
        rawScore: Double,
        updatedAtUnix: Double?,
        weights: FusionWeights,
        now: Date
    ) -> Double {
        guard let updatedAtUnix, updatedAtUnix.isFinite else { return rawScore }
        let ageDays = max(0, now.timeIntervalSince1970 - updatedAtUnix) / 86_400
        return rawScore * Foundation.exp(
            -Phase3FusionConsts.RECENCY_LN_2 * ageDays / weights.halfLifeDays
        )
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
        let terms = capped.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { token in
                // Keep 2+ character tokens. Also keep a SINGLE-character token
                // whose scalar is non-ASCII (CJK/ideographic and other scripts
                // where one character is a whole word) so e.g. "水" is searchable
                // instead of silently returning nothing; ASCII singletons
                // ("a", "i") stay dropped as low-signal noise.
                token.count >= 2 || token.unicodeScalars.contains { $0.value > 0x7F }
            }
            .map { $0.replacingOccurrences(of: "\"", with: "") }
            .filter { !$0.isEmpty }
        return uniqueSearchTerms(searchSignalTerms(from: terms), limit: 20)
    }

    private nonisolated static let searchBoilerplateTerms: Set<String> = [
        "about",
        "called",
        "find",
        "for",
        "from",
        "get",
        "give",
        "in",
        "list",
        "lookup",
        "me",
        "mention",
        "mentions",
        "my",
        "note",
        "notes",
        "on",
        "open",
        "original",
        "please",
        "pull",
        "reference",
        "references",
        "retrieve",
        "search",
        "show",
        "the",
        "title",
        "titled",
        "vault",
    ]

    private nonisolated static func searchSignalTerms(from terms: [String]) -> [String] {
        guard terms.count > 1 else { return terms }
        let stripped = terms.filter { !searchBoilerplateTerms.contains($0) }
        return stripped.isEmpty ? terms : stripped
    }

    private nonisolated static func uniqueSearchTerms(_ terms: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        unique.reserveCapacity(min(terms.count, limit))
        for term in terms where seen.insert(term).inserted {
            unique.append(term)
            if unique.count == limit {
                break
            }
        }
        return unique
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
