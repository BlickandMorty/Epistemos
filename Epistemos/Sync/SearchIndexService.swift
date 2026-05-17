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
    nonisolated private let agentProvenanceSyncRecorder: AgentToolProvenanceSyncRecorder
    nonisolated private let directPageSyncSearchToolSequence = Mutex<UInt64>(0)
    nonisolated private let blockSyncSearchToolSequence = Mutex<UInt64>(0)
    nonisolated private let fusedSyncSearchToolSequence = Mutex<UInt64>(0)
    private var agentProvenanceRecorder: AgentToolProvenanceRecorder?
    private var directPageAsyncSearchToolSequence: UInt64 = 0
    private var blockAsyncSearchToolSequence: UInt64 = 0
    private var fusedAsyncSearchToolSequence: UInt64 = 0

    init(
        databaseURL providedDatabaseURL: URL? = nil,
        agentProvenanceRecorder: AgentToolProvenanceRecorder? = nil,
        agentProvenanceSyncRecorder: AgentToolProvenanceSyncRecorder = AgentToolProvenanceSyncRecorder()
    ) throws {
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
        self.agentProvenanceRecorder = agentProvenanceRecorder
        self.agentProvenanceSyncRecorder = agentProvenanceSyncRecorder

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
                PRAGMA optimize;
                PRAGMA fullfsync = 0;
                PRAGMA checkpoint_fullfsync = 0;
            """)

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
                try createPageSearchArtifactsIfAvailable(db)
                try createBlockSearchArtifactsIfAvailable(db)
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
        let recorder = agentProvenanceSyncRecorder
        let runID = "search-index-page-sync-\(UUID().uuidString.uppercased())"
        let toolCallID = nextDirectPageSyncSearchToolCallID()
        let argumentsJSON = Self.limitedSearchArgumentsJSON(query: query, terms: terms, limit: limit)
        let baseMetadata = Self.limitedSearchMetadata(
            surface: "search",
            query: query,
            terms: terms,
            limit: limit
        )
        let actor = AgentProvenanceActor.agent(id: "search-index-service", modelID: nil)
        let lifecycleStart = DispatchTime.now()

        recordDirectPageSyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallRequested,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .requested,
            metadata: baseMetadata
        )
        recordDirectPageSyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallStarted,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .started,
            metadata: baseMetadata
        )

        do {
            let results = try searchPages(terms: terms, limit: limit)
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            let resultJSON = Self.searchIndexAgentJSON([
                "elapsed_ms": elapsedMs,
                "hit_count": results.count
            ])
            var metadata = baseMetadata
            metadata["hit_count"] = "\(results.count)"
            recordDirectPageSyncAgentEvent(
                recorder: recorder,
                runID: runID,
                kind: .toolCallCompleted,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: resultJSON,
                durationMs: elapsedMs,
                status: .completed,
                metadata: metadata
            )
            return results
        } catch {
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            let failureClass = Self.searchIndexFailureClass(for: error)
            recordDirectPageSyncFailure(
                recorder: recorder,
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                durationMs: elapsedMs,
                failureClass: failureClass,
                metadata: baseMetadata
            )
            throw error
        }
    }

    func searchAsync(query: String, limit: Int = 50) async throws -> [SearchResult] {
        let terms = Self.normalizedSearchTerms(query)
        guard !terms.isEmpty else { return [] }
        let recorder = await resolvedAgentProvenanceRecorder()
        let runID = "search-index-page-async-\(UUID().uuidString.uppercased())"
        let toolCallID = nextDirectPageAsyncSearchToolCallID()
        let argumentsJSON = Self.limitedSearchArgumentsJSON(query: query, terms: terms, limit: limit)
        let baseMetadata = Self.limitedSearchMetadata(
            surface: "search_async",
            query: query,
            terms: terms,
            limit: limit
        )
        let actor = AgentProvenanceActor.agent(id: "search-index-service", modelID: nil)
        let lifecycleStart = DispatchTime.now()

        await recordDirectPageAsyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallRequested,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .requested,
            metadata: baseMetadata
        )
        await recordDirectPageAsyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallStarted,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .started,
            metadata: baseMetadata
        )

        if Task.isCancelled {
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            await recordDirectPageAsyncFailure(
                recorder: recorder,
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                durationMs: elapsedMs,
                failureClass: .cancelled,
                metadata: baseMetadata
            )
            throw CancellationError()
        }

        do {
            let results = try await offloadSearch { [self, terms, limit] cancellation in
                try cancellation.check()
                let signpostId = Sig.storage.makeSignpostID()
                let state = Sig.storage.beginInterval("search", id: signpostId)
                defer { Sig.storage.endInterval("search", state) }
                return try searchPages(terms: terms, limit: limit, cancellation: cancellation)
            }
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            let resultJSON = Self.searchIndexAgentJSON([
                "elapsed_ms": elapsedMs,
                "hit_count": results.count
            ])
            var metadata = baseMetadata
            metadata["hit_count"] = "\(results.count)"
            await recordDirectPageAsyncAgentEvent(
                recorder: recorder,
                runID: runID,
                kind: .toolCallCompleted,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: resultJSON,
                durationMs: elapsedMs,
                status: .completed,
                metadata: metadata
            )
            return results
        } catch {
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            let failureClass = Self.searchIndexFailureClass(for: error)
            await recordDirectPageAsyncFailure(
                recorder: recorder,
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                durationMs: elapsedMs,
                failureClass: failureClass,
                metadata: baseMetadata
            )
            throw error
        }
    }

    // MARK: - Block Search

    nonisolated func searchBlocks(query: String, limit: Int = 50) throws -> [BlockSearchResult] {
        let terms = Self.normalizedSearchTerms(query)
        guard !terms.isEmpty else { return [] }
        let recorder = agentProvenanceSyncRecorder
        let runID = "search-index-block-sync-\(UUID().uuidString.uppercased())"
        let toolCallID = nextBlockSyncSearchToolCallID()
        let argumentsJSON = Self.limitedSearchArgumentsJSON(query: query, terms: terms, limit: limit)
        let baseMetadata = Self.limitedSearchMetadata(
            surface: "search_blocks",
            query: query,
            terms: terms,
            limit: limit
        )
        let actor = AgentProvenanceActor.agent(id: "search-index-service", modelID: nil)
        let lifecycleStart = DispatchTime.now()

        recordBlockSearchSyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallRequested,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .requested,
            metadata: baseMetadata
        )
        recordBlockSearchSyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallStarted,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .started,
            metadata: baseMetadata
        )

        do {
            let results = try searchBlocks(terms: terms, limit: limit)
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            let resultJSON = Self.searchIndexAgentJSON([
                "elapsed_ms": elapsedMs,
                "hit_count": results.count
            ])
            var metadata = baseMetadata
            metadata["hit_count"] = "\(results.count)"
            recordBlockSearchSyncAgentEvent(
                recorder: recorder,
                runID: runID,
                kind: .toolCallCompleted,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: resultJSON,
                durationMs: elapsedMs,
                status: .completed,
                metadata: metadata
            )
            return results
        } catch {
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            let failureClass = Self.searchIndexFailureClass(for: error)
            recordBlockSearchSyncFailure(
                recorder: recorder,
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                durationMs: elapsedMs,
                failureClass: failureClass,
                metadata: baseMetadata
            )
            throw error
        }
    }

    func searchBlocksAsync(query: String, limit: Int = 50) async throws -> [BlockSearchResult] {
        let terms = Self.normalizedSearchTerms(query)
        guard !terms.isEmpty else { return [] }
        let recorder = await resolvedAgentProvenanceRecorder()
        let runID = "search-index-block-async-\(UUID().uuidString.uppercased())"
        let toolCallID = nextBlockAsyncSearchToolCallID()
        let argumentsJSON = Self.limitedSearchArgumentsJSON(query: query, terms: terms, limit: limit)
        let baseMetadata = Self.limitedSearchMetadata(
            surface: "search_blocks_async",
            query: query,
            terms: terms,
            limit: limit
        )
        let actor = AgentProvenanceActor.agent(id: "search-index-service", modelID: nil)
        let lifecycleStart = DispatchTime.now()

        await recordBlockSearchAsyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallRequested,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .requested,
            metadata: baseMetadata
        )
        await recordBlockSearchAsyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallStarted,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .started,
            metadata: baseMetadata
        )

        if Task.isCancelled {
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            await recordBlockSearchAsyncFailure(
                recorder: recorder,
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                durationMs: elapsedMs,
                failureClass: .cancelled,
                metadata: baseMetadata
            )
            throw CancellationError()
        }

        do {
            let results = try await offloadSearch { [self, terms, limit] cancellation in
                try cancellation.check()
                return try searchBlocks(terms: terms, limit: limit, cancellation: cancellation)
            }
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            let resultJSON = Self.searchIndexAgentJSON([
                "elapsed_ms": elapsedMs,
                "hit_count": results.count
            ])
            var metadata = baseMetadata
            metadata["hit_count"] = "\(results.count)"
            await recordBlockSearchAsyncAgentEvent(
                recorder: recorder,
                runID: runID,
                kind: .toolCallCompleted,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: resultJSON,
                durationMs: elapsedMs,
                status: .completed,
                metadata: metadata
            )
            return results
        } catch {
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            let failureClass = Self.searchIndexFailureClass(for: error)
            await recordBlockSearchAsyncFailure(
                recorder: recorder,
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                durationMs: elapsedMs,
                failureClass: failureClass,
                metadata: baseMetadata
            )
            throw error
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
        let signpostId = Sig.storage.makeSignpostID()
        let state = Sig.storage.beginInterval("fused_search", id: signpostId)
        defer { Sig.storage.endInterval("fused_search", state) }

        let terms = Self.normalizedSearchTerms(query)
        guard !terms.isEmpty else { return [] }
        let sanitized = Self.sanitizeFTS5Query(terms)
        let recorder = agentProvenanceSyncRecorder
        let runID = "search-index-fused-sync-\(UUID().uuidString.uppercased())"
        let toolCallID = nextFusedSyncSearchToolCallID()
        let weightsProfile = weights == .default ? "default" : "custom"
        let queryCharacterCount = min(query.count, 500)
        let nowMs = Self.millisecondsSinceEpoch(now)
        let argumentsJSON = Self.searchIndexAgentJSON([
            "now_ms": nowMs,
            "query_char_count": queryCharacterCount,
            "query_term_count": terms.count,
            "weights_profile": weightsProfile
        ])
        let baseMetadata = [
            "source": "search_index_service",
            "surface": "fused_search",
            "query_char_count": "\(queryCharacterCount)",
            "query_term_count": "\(terms.count)",
            "weights_profile": weightsProfile
        ]
        let actor = AgentProvenanceActor.agent(id: "search-index-service", modelID: nil)
        let lifecycleStart = DispatchTime.now()

        recordFusedSyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallRequested,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .requested,
            metadata: baseMetadata
        )
        recordFusedSyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallStarted,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .started,
            metadata: baseMetadata
        )
        let startTime = DispatchTime.now()

        do {
            let results = try dbPool.read { db in
                try RRFFusionQuery.execute(
                    query: sanitized,
                    weights: weights,
                    now: now,
                    in: db
                )
            }
            let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds &- startTime.uptimeNanoseconds) / 1_000_000.0
            let escalationMetrics = Self.fusedSearchExactEscalationMetrics(
                query: query,
                results: results
            )
            SearchFusionMetrics.shared.record(
                latencyMs: elapsedMs,
                query: query,
                results: results,
                exactEscalationTargetCount: escalationMetrics.targetCount,
                exactEscalationQueryCount: escalationMetrics.queryCount
            )
            let lifecycleElapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            let resultJSON = Self.searchIndexAgentJSON(
                Self.fusedSearchCompletionPayload(
                    query: query,
                    elapsedMs: lifecycleElapsedMs,
                    results: results
                )
            )
            let metadata = Self.fusedSearchCompletionMetadata(
                baseMetadata: baseMetadata,
                query: query,
                results: results
            )
            recordFusedSyncAgentEvent(
                recorder: recorder,
                runID: runID,
                kind: .toolCallCompleted,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: resultJSON,
                durationMs: lifecycleElapsedMs,
                status: .completed,
                metadata: metadata
            )
            return results
        } catch {
            SearchFusionMetrics.shared.recordError(error)
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            let failureClass = Self.searchIndexFailureClass(for: error)
            recordFusedSyncFailure(
                recorder: recorder,
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                durationMs: elapsedMs,
                failureClass: failureClass,
                metadata: baseMetadata
            )
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
        let terms = Self.normalizedSearchTerms(query)
        guard !terms.isEmpty else { return [] }
        let sanitized = Self.sanitizeFTS5Query(terms)
        let recorder = await resolvedAgentProvenanceRecorder()
        let runID = "search-index-fused-async-\(UUID().uuidString.uppercased())"
        let toolCallID = nextFusedAsyncSearchToolCallID()
        let weightsProfile = weights == .default ? "default" : "custom"
        let queryCharacterCount = min(query.count, 500)
        let nowMs = Self.millisecondsSinceEpoch(now)
        let argumentsJSON = Self.searchIndexAgentJSON([
            "now_ms": nowMs,
            "query_char_count": queryCharacterCount,
            "query_term_count": terms.count,
            "weights_profile": weightsProfile
        ])
        let baseMetadata = [
            "source": "search_index_service",
            "surface": "fused_search_async",
            "query_char_count": "\(queryCharacterCount)",
            "query_term_count": "\(terms.count)",
            "weights_profile": weightsProfile
        ]
        let actor = AgentProvenanceActor.agent(id: "search-index-service", modelID: nil)
        let lifecycleStart = DispatchTime.now()

        await recordFusedAsyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallRequested,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .requested,
            metadata: baseMetadata
        )
        await recordFusedAsyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallStarted,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .started,
            metadata: baseMetadata
        )

        if Task.isCancelled {
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            await recordFusedAsyncFailure(
                recorder: recorder,
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                durationMs: elapsedMs,
                failureClass: .cancelled,
                metadata: baseMetadata
            )
            throw CancellationError()
        }

        do {
            let results = try await offloadSearch { [self, sanitized, weights, now] cancellation in
                try cancellation.check()
                let signpostId = Sig.storage.makeSignpostID()
                let state = Sig.storage.beginInterval("fused_search", id: signpostId)
                defer { Sig.storage.endInterval("fused_search", state) }

                let startTime = DispatchTime.now()

                do {
                    let results = try dbPool.read { db in
                        try Self.withSQLiteCancellation(db: db, cancellation: cancellation) {
                            try RRFFusionQuery.execute(
                                query: sanitized,
                                weights: weights,
                                now: now,
                                in: db
                            )
                        }
                    }
                    let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds &- startTime.uptimeNanoseconds) / 1_000_000.0
                    let escalationMetrics = Self.fusedSearchExactEscalationMetrics(
                        query: query,
                        results: results
                    )
                    SearchFusionMetrics.shared.record(
                        latencyMs: elapsedMs,
                        query: query,
                        results: results,
                        exactEscalationTargetCount: escalationMetrics.targetCount,
                        exactEscalationQueryCount: escalationMetrics.queryCount
                    )
                    return results
                } catch {
                    SearchFusionMetrics.shared.recordError(error)
                    throw error
                }
            }
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            let resultJSON = Self.searchIndexAgentJSON(
                Self.fusedSearchCompletionPayload(
                    query: query,
                    elapsedMs: elapsedMs,
                    results: results
                )
            )
            let metadata = Self.fusedSearchCompletionMetadata(
                baseMetadata: baseMetadata,
                query: query,
                results: results
            )
            await recordFusedAsyncAgentEvent(
                recorder: recorder,
                runID: runID,
                kind: .toolCallCompleted,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: resultJSON,
                durationMs: elapsedMs,
                status: .completed,
                metadata: metadata
            )
            return results
        } catch {
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            let failureClass = Self.searchIndexFailureClass(for: error)
            await recordFusedAsyncFailure(
                recorder: recorder,
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                durationMs: elapsedMs,
                failureClass: failureClass,
                metadata: baseMetadata
            )
            throw error
        }
    }

    private enum SearchIndexFailureClass: String, Sendable {
        case cancelled
        case sqlError = "sql_error"
        case unknownError = "unknown_error"
    }

    private func resolvedAgentProvenanceRecorder() async -> AgentToolProvenanceRecorder {
        if let agentProvenanceRecorder {
            return agentProvenanceRecorder
        }
        let recorder = await MainActor.run {
            AgentToolProvenanceRecorder()
        }
        agentProvenanceRecorder = recorder
        return recorder
    }

    private func nextFusedAsyncSearchToolCallID() -> String {
        fusedAsyncSearchToolSequence += 1
        return "search-index-fused-async:\(fusedAsyncSearchToolSequence)"
    }

    private func nextDirectPageAsyncSearchToolCallID() -> String {
        directPageAsyncSearchToolSequence += 1
        return "search-index-page-async:\(directPageAsyncSearchToolSequence)"
    }

    private func nextBlockAsyncSearchToolCallID() -> String {
        blockAsyncSearchToolSequence += 1
        return "search-index-block-async:\(blockAsyncSearchToolSequence)"
    }

    private nonisolated func nextFusedSyncSearchToolCallID() -> String {
        let sequence = fusedSyncSearchToolSequence.withLock { value -> UInt64 in
            value += 1
            return value
        }
        return "search-index-fused-sync:\(sequence)"
    }

    private nonisolated func nextDirectPageSyncSearchToolCallID() -> String {
        let sequence = directPageSyncSearchToolSequence.withLock { value -> UInt64 in
            value += 1
            return value
        }
        return "search-index-page-sync:\(sequence)"
    }

    private nonisolated func nextBlockSyncSearchToolCallID() -> String {
        let sequence = blockSyncSearchToolSequence.withLock { value -> UInt64 in
            value += 1
            return value
        }
        return "search-index-block-sync:\(sequence)"
    }

    private func recordDirectPageAsyncFailure(
        recorder: AgentToolProvenanceRecorder,
        runID: String,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        durationMs: UInt64,
        failureClass: SearchIndexFailureClass,
        metadata: [String: String]
    ) async {
        let resultJSON = Self.searchIndexAgentJSON([
            "elapsed_ms": durationMs,
            "hit_count": 0
        ])
        var failedMetadata = metadata
        failedMetadata["failure_class"] = failureClass.rawValue
        await recordDirectPageAsyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallFailed,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: .failed,
            errorMessage: failureClass.rawValue,
            metadata: failedMetadata
        )
    }

    private nonisolated func recordDirectPageSyncFailure(
        recorder: AgentToolProvenanceSyncRecorder,
        runID: String,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        durationMs: UInt64,
        failureClass: SearchIndexFailureClass,
        metadata: [String: String]
    ) {
        let resultJSON = Self.searchIndexAgentJSON([
            "elapsed_ms": durationMs,
            "hit_count": 0
        ])
        var failedMetadata = metadata
        failedMetadata["failure_class"] = failureClass.rawValue
        recordDirectPageSyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallFailed,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: .failed,
            errorMessage: failureClass.rawValue,
            metadata: failedMetadata
        )
    }

    private func recordBlockSearchAsyncFailure(
        recorder: AgentToolProvenanceRecorder,
        runID: String,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        durationMs: UInt64,
        failureClass: SearchIndexFailureClass,
        metadata: [String: String]
    ) async {
        let resultJSON = Self.searchIndexAgentJSON([
            "elapsed_ms": durationMs,
            "hit_count": 0
        ])
        var failedMetadata = metadata
        failedMetadata["failure_class"] = failureClass.rawValue
        await recordBlockSearchAsyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallFailed,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: .failed,
            errorMessage: failureClass.rawValue,
            metadata: failedMetadata
        )
    }

    private nonisolated func recordBlockSearchSyncFailure(
        recorder: AgentToolProvenanceSyncRecorder,
        runID: String,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        durationMs: UInt64,
        failureClass: SearchIndexFailureClass,
        metadata: [String: String]
    ) {
        let resultJSON = Self.searchIndexAgentJSON([
            "elapsed_ms": durationMs,
            "hit_count": 0
        ])
        var failedMetadata = metadata
        failedMetadata["failure_class"] = failureClass.rawValue
        recordBlockSearchSyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallFailed,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: .failed,
            errorMessage: failureClass.rawValue,
            metadata: failedMetadata
        )
    }

    private func recordFusedAsyncFailure(
        recorder: AgentToolProvenanceRecorder,
        runID: String,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        durationMs: UInt64,
        failureClass: SearchIndexFailureClass,
        metadata: [String: String]
    ) async {
        let resultJSON = Self.searchIndexAgentJSON([
            "elapsed_ms": durationMs,
            "hit_count": 0
        ])
        var failedMetadata = metadata
        failedMetadata["failure_class"] = failureClass.rawValue
        await recordFusedAsyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallFailed,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: .failed,
            errorMessage: failureClass.rawValue,
            metadata: failedMetadata
        )
    }

    private nonisolated func recordFusedSyncFailure(
        recorder: AgentToolProvenanceSyncRecorder,
        runID: String,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        durationMs: UInt64,
        failureClass: SearchIndexFailureClass,
        metadata: [String: String]
    ) {
        let resultJSON = Self.searchIndexAgentJSON([
            "elapsed_ms": durationMs,
            "hit_count": 0
        ])
        var failedMetadata = metadata
        failedMetadata["failure_class"] = failureClass.rawValue
        recordFusedSyncAgentEvent(
            recorder: recorder,
            runID: runID,
            kind: .toolCallFailed,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: .failed,
            errorMessage: failureClass.rawValue,
            metadata: failedMetadata
        )
    }

    private func recordFusedAsyncAgentEvent(
        recorder: AgentToolProvenanceRecorder,
        runID: String,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String]
    ) async {
        await recorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: kind,
            actor: actor,
            toolCallID: toolCallID,
            toolName: "search_index.fused_search_async",
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
    }

    private func recordDirectPageAsyncAgentEvent(
        recorder: AgentToolProvenanceRecorder,
        runID: String,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String]
    ) async {
        await recorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: kind,
            actor: actor,
            toolCallID: toolCallID,
            toolName: "search_index.search_async",
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
    }

    private func recordBlockSearchAsyncAgentEvent(
        recorder: AgentToolProvenanceRecorder,
        runID: String,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String]
    ) async {
        await recorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: kind,
            actor: actor,
            toolCallID: toolCallID,
            toolName: "search_index.search_blocks_async",
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
    }

    private nonisolated func recordFusedSyncAgentEvent(
        recorder: AgentToolProvenanceSyncRecorder,
        runID: String,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String]
    ) {
        recorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: kind,
            actor: actor,
            toolCallID: toolCallID,
            toolName: "search_index.fused_search",
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
    }

    private nonisolated func recordDirectPageSyncAgentEvent(
        recorder: AgentToolProvenanceSyncRecorder,
        runID: String,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String]
    ) {
        recorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: kind,
            actor: actor,
            toolCallID: toolCallID,
            toolName: "search_index.search",
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
    }

    private nonisolated func recordBlockSearchSyncAgentEvent(
        recorder: AgentToolProvenanceSyncRecorder,
        runID: String,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String]
    ) {
        recorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: kind,
            actor: actor,
            toolCallID: toolCallID,
            toolName: "search_index.search_blocks",
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
    }

    private nonisolated static func searchIndexFailureClass(for error: Error) -> SearchIndexFailureClass {
        if error is CancellationError {
            return .cancelled
        }
        if error is DatabaseError {
            return .sqlError
        }
        return .unknownError
    }

    private nonisolated static func limitedSearchArgumentsJSON(
        query: String,
        terms: [String],
        limit: Int
    ) -> String {
        searchIndexAgentJSON([
            "limit": limit,
            "query_char_count": min(query.count, 500),
            "query_term_count": terms.count
        ])
    }

    private nonisolated static func limitedSearchMetadata(
        surface: String,
        query: String,
        terms: [String],
        limit: Int
    ) -> [String: String] {
        [
            "source": "search_index_service",
            "surface": surface,
            "query_char_count": "\(min(query.count, 500))",
            "query_term_count": "\(terms.count)",
            "limit": "\(limit)"
        ]
    }

    private nonisolated static func millisecondsSinceEpoch(_ date: Date) -> Int64 {
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite else { return 0 }
        return Int64(milliseconds.rounded())
    }

    private nonisolated static func fusedSearchCompletionPayload(
        query: String,
        elapsedMs: UInt64,
        results: [FusedResult]
    ) -> [String: Any] {
        let counts = fusedSearchConfidenceCounts(results)
        let exactEscalationReasons = RRFFusionQuery.exactEscalationReasons(
            query: query,
            results: results
        )
        let exactEscalationTargets = exactEscalationReasons.isEmpty
            ? []
            : fusedSearchExactEscalationTargets(results)
        let exactEscalationQueries = exactEscalationReasons.isEmpty
            ? []
            : fusedSearchExactEscalationQueries(query: query, results: results)
        var payload: [String: Any] = [
            "contract_sufficient_count": counts.contractSufficient,
            "elapsed_ms": elapsedMs,
            "exact_escalation_query_char_limit": SearchFusionMetrics.exactEscalationQueryCharLimit,
            "exact_escalation_query_count": exactEscalationQueries.count,
            "exact_escalation_required": !exactEscalationReasons.isEmpty,
            "exact_escalation_snippet_char_limit": SearchFusionMetrics.exactEscalationSnippetCharLimit,
            "exact_escalation_target_count": exactEscalationTargets.count,
            "exact_escalation_target_limit": SearchFusionMetrics.exactEscalationTargetLimit,
            "high_confidence_count": counts.high,
            "hit_count": results.count,
            "low_confidence_count": counts.low,
            "medium_confidence_count": counts.medium,
            "vault_context_contract_schema": SearchFusionMetrics.vaultContextContractSchema
        ]
        if !exactEscalationReasons.isEmpty {
            payload["exact_escalation_reasons"] = exactEscalationReasons
            payload["exact_escalation_targets"] = exactEscalationTargets
            payload["exact_escalation_queries"] = exactEscalationQueries
        }
        if let topScoreMargin = RRFFusionQuery.topScoreMargin(results) {
            payload["top_score_margin"] = topScoreMargin
        }
        return payload
    }

    private nonisolated static func fusedSearchCompletionMetadata(
        baseMetadata: [String: String],
        query: String,
        results: [FusedResult]
    ) -> [String: String] {
        let counts = fusedSearchConfidenceCounts(results)
        let exactEscalationReasons = RRFFusionQuery.exactEscalationReasons(
            query: query,
            results: results
        )
        let exactEscalationTargets = exactEscalationReasons.isEmpty
            ? []
            : fusedSearchExactEscalationTargets(results)
        let exactEscalationQueries = exactEscalationReasons.isEmpty
            ? []
            : fusedSearchExactEscalationQueries(query: query, results: results)
        var metadata = baseMetadata
        metadata["contract_sufficient_count"] = "\(counts.contractSufficient)"
        metadata["exact_escalation_query_char_limit"] = "\(SearchFusionMetrics.exactEscalationQueryCharLimit)"
        metadata["exact_escalation_required"] = exactEscalationReasons.isEmpty ? "false" : "true"
        metadata["exact_escalation_snippet_char_limit"] = "\(SearchFusionMetrics.exactEscalationSnippetCharLimit)"
        metadata["exact_escalation_target_limit"] = "\(SearchFusionMetrics.exactEscalationTargetLimit)"
        metadata["exact_escalation_query_count"] = "\(exactEscalationQueries.count)"
        metadata["exact_escalation_target_count"] = "\(exactEscalationTargets.count)"
        if !exactEscalationReasons.isEmpty {
            metadata["exact_escalation_reasons"] = exactEscalationReasons.joined(separator: ",")
        }
        metadata["high_confidence_count"] = "\(counts.high)"
        metadata["hit_count"] = "\(results.count)"
        metadata["low_confidence_count"] = "\(counts.low)"
        metadata["medium_confidence_count"] = "\(counts.medium)"
        metadata["vault_context_contract_schema"] = SearchFusionMetrics.vaultContextContractSchema
        if let topScoreMargin = RRFFusionQuery.topScoreMargin(results) {
            metadata["top_score_margin"] = "\(topScoreMargin)"
        }
        return metadata
    }

    private nonisolated static func fusedSearchConfidenceCounts(
        _ results: [FusedResult]
    ) -> (contractSufficient: Int, high: Int, medium: Int, low: Int) {
        var contractSufficient = 0
        var high = 0
        var medium = 0
        var low = 0

        for result in results {
            if result.isContractSufficient {
                contractSufficient += 1
            }
            switch result.confidenceBand {
            case .high:
                high += 1
            case .medium:
                medium += 1
            case .low:
                low += 1
            }
        }

        return (contractSufficient, high, medium, low)
    }

    private nonisolated static func fusedSearchExactEscalationMetrics(
        query: String,
        results: [FusedResult]
    ) -> (targetCount: Int, queryCount: Int) {
        let exactEscalationReasons = RRFFusionQuery.exactEscalationReasons(
            query: query,
            results: results
        )
        guard !exactEscalationReasons.isEmpty else {
            return (0, 0)
        }
        return (
            rankedFusedEscalationResults(results).count,
            fusedSearchExactEscalationQueries(query: query, results: results).count
        )
    }

    private nonisolated static func fusedSearchExactEscalationTargets(
        _ results: [FusedResult],
        maxTargets: Int = SearchFusionMetrics.exactEscalationTargetLimit
    ) -> [[String: Any]] {
        rankedFusedEscalationResults(results, maxTargets: maxTargets)
            .map { result in
                var target: [String: Any] = [
                    "best_source_rank": result.bestSourceRank,
                    "confidence_band": result.confidenceBand.rawValue,
                    "contract_sufficient": result.isContractSufficient,
                    "entity_id": result.entityID,
                    "entity_kind": result.entityKind,
                    "fused_score": fusedSearchFiniteScore(result.fusedScore),
                    "match_reasons": result.matchReasons,
                    "parent_doc_id": result.parentDocID
                ]
                if let snippetBlockID = result.snippetBlockID,
                   !snippetBlockID.isEmpty {
                    target["snippet_block_id"] = snippetBlockID
                }
                let matchKeys = exactEscalationTargetMatchKeys(result)
                if !matchKeys.isEmpty {
                    target["match_keys"] = matchKeys
                }
                if let displayTitle = trimmedEscalationSnippet(result.displayTitle) {
                    target["display_title"] = displayTitle
                }
                if let snippet = trimmedEscalationSnippet(result.snippet) {
                    target["snippet"] = snippet
                }
                if let updatedAtUnix = result.updatedAtUnix,
                   updatedAtUnix.isFinite {
                    target["updated_at_unix"] = updatedAtUnix
                }
                return target
            }
    }

    private nonisolated static func fusedSearchExactEscalationQueries(
        query: String,
        results: [FusedResult],
        maxTargets: Int = SearchFusionMetrics.exactEscalationTargetLimit
    ) -> [String] {
        var queries: [String] = []
        appendExactEscalationQuery(&queries, query)
        for result in rankedFusedEscalationResults(results, maxTargets: maxTargets) {
            appendExactEscalationQuery(&queries, result.displayTitle)
            appendExactEscalationQuery(&queries, result.parentDocID)
            appendExactEscalationQuery(&queries, result.entityID)
            appendExactEscalationQuery(&queries, result.snippet)
        }
        return queries
    }

    private nonisolated static func rankedFusedEscalationResults(
        _ results: [FusedResult],
        maxTargets: Int = SearchFusionMetrics.exactEscalationTargetLimit
    ) -> [FusedResult] {
        let boundedMax = min(max(0, maxTargets), SearchFusionMetrics.exactEscalationTargetLimit)
        guard boundedMax > 0 else { return [] }

        return results.enumerated()
            .sorted { lhs, rhs in
                let lhsScore = fusedSearchFiniteScore(lhs.element.fusedScore)
                let rhsScore = fusedSearchFiniteScore(rhs.element.fusedScore)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                if lhs.element.bestSourceRank != rhs.element.bestSourceRank {
                    return lhs.element.bestSourceRank < rhs.element.bestSourceRank
                }
                return lhs.offset < rhs.offset
            }
            .prefix(boundedMax)
            .map(\.element)
    }

    private nonisolated static func exactEscalationTargetMatchKeys(
        _ result: FusedResult
    ) -> [String] {
        var matchKeys: [String] = []
        appendExactEscalationQuery(&matchKeys, result.displayTitle)
        appendExactEscalationQuery(&matchKeys, result.parentDocID)
        appendExactEscalationQuery(&matchKeys, result.entityID)
        return matchKeys
    }

    private nonisolated static func fusedSearchFiniteScore(_ score: Double) -> Double {
        guard score.isFinite else { return 0 }
        return max(0, score)
    }

    private nonisolated static func appendExactEscalationQuery(
        _ queries: inout [String],
        _ query: String?
    ) {
        guard let boundedQuery = boundedExactEscalationQuery(query) else { return }
        let alreadyPresent = queries.contains { existing in
            existing.compare(boundedQuery, options: [.caseInsensitive]) == .orderedSame
        }
        guard !alreadyPresent else { return }
        queries.append(boundedQuery)
    }

    private nonisolated static func boundedExactEscalationQuery(_ query: String?) -> String? {
        guard let query else { return nil }
        let trimmed = query
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
            .replacingOccurrences(of: "…", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(SearchFusionMetrics.exactEscalationQueryCharLimit))
    }

    private nonisolated static func trimmedEscalationSnippet(_ snippet: String?) -> String? {
        guard let snippet else { return nil }
        let trimmed = snippet
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
            .replacingOccurrences(of: "…", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(SearchFusionMetrics.exactEscalationSnippetCharLimit))
    }

    private nonisolated static func elapsedMilliseconds(since start: DispatchTime) -> UInt64 {
        (DispatchTime.now().uptimeNanoseconds &- start.uptimeNanoseconds) / 1_000_000
    }

    private nonisolated static func searchIndexAgentJSON(_ payload: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
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
        Self.notifyIndexChanged([.searchBlocks])
    }

    nonisolated func deleteBlock(blockId: String) throws {
        try dbPool.write { db in
            // Wave 2.3 dpp §1.1 Task 0.3 — cached prepared statement (hot path).
            let stmt = try db.cachedStatement(sql: "DELETE FROM indexed_blocks WHERE block_id = ?")
            stmt.setUncheckedArguments([blockId])
            try stmt.execute()
        }
        Self.notifyIndexChanged([.searchBlocks])
    }

    // MARK: - Upsert / Delete

    nonisolated func upsert(id: String, title: String, body: String, tags: String, updatedAt: Date) throws {
        try dbPool.write { db in
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
        }
        Self.notifyIndexChanged([.searchPages])
    }

    nonisolated func upsertPages(
        _ pages: [(id: String, title: String, body: String, tags: String, updatedAt: Date)]
    ) throws {
        guard !pages.isEmpty else { return }

        try dbPool.write { db in
            // Wave 2.3 dpp §1.1 Task 0.3 — cached prepared statement reused across batch.
            // 2026-05-13 hardening: switched from `cachedStatement` to a
            // freshly-prepared `makeStatement` for the batch. The cached
            // statement was occasionally left in a SQLITE error-state
            // after a row-level failure (constraint violation, large-blob
            // boundary, etc.), and the NEXT call to upsertPages would
            // retrieve the same cached statement and trip "invalid reuse
            // after initialization failure" because GRDB's reset path
            // returns the lingering step error. Preparing once per batch
            // costs a single `sqlite3_prepare_v2` but eliminates the
            // cross-call statement reuse hazard. Logged with `log.error`
            // on failure so future reproductions surface in Console.app.
            let stmt: Statement
            do {
                stmt = try db.makeStatement(sql: """
                    INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        title = excluded.title,
                        body = excluded.body,
                        tags = excluded.tags,
                        updatedAt = excluded.updatedAt
                """)
            } catch {
                self.log.error("SearchIndexService.upsertPages prepare failed: \(String(describing: error), privacy: .public)")
                throw error
            }
            for page in pages {
                stmt.setUncheckedArguments([
                    page.id,
                    page.title,
                    page.body,
                    page.tags,
                    page.updatedAt.timeIntervalSinceReferenceDate,
                ])
                do {
                    try stmt.execute()
                } catch {
                    self.log.error("SearchIndexService.upsertPages execute failed for id=\(page.id, privacy: .public): \(String(describing: error), privacy: .public)")
                    throw error
                }
            }
        }
        Self.notifyIndexChanged([.searchPages])
    }

    nonisolated func delete(pageId: String) throws {
        try dbPool.write { db in
            // Wave 2.3 dpp §1.1 Task 0.3 — cached prepared statement (hot path).
            let stmt = try db.cachedStatement(sql: "DELETE FROM indexed_pages WHERE id = ?")
            stmt.setUncheckedArguments([pageId])
            try stmt.execute()
        }
        Self.notifyIndexChanged([.searchPages])
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
            // Wave 2.3 dpp §1.1 Task 0.3 — cached prepared statement reused across batch.
            let stmt = try db.cachedStatement(sql: "DELETE FROM indexed_pages WHERE id = ?")
            for id in ids {
                stmt.setUncheckedArguments([id])
                try stmt.execute()
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
        let terms = Array(
            capped.lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { $0.count >= 2 }
                .map { $0.replacingOccurrences(of: "\"", with: "") }
                .filter { !$0.isEmpty }
                .prefix(20)
        )
        return vaultRecallSignalTerms(from: terms)
    }

    private nonisolated static let vaultRecallBoilerplateTerms: Set<String> = [
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

    private nonisolated static func vaultRecallSignalTerms(from terms: [String]) -> [String] {
        guard terms.count > 1 else { return terms }
        let stripped = terms.filter { !vaultRecallBoilerplateTerms.contains($0) }
        return stripped.isEmpty ? terms : stripped
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
