import Foundation
import GRDB
import os

// MARK: - SearchIndexService
// FTS5 full-text search engine backed by GRDB.
// Lives outside SwiftData — owns its own search.sqlite file.
// Replaces the in-memory trigram index with a proper FTS5 virtual table
// that supports BM25 ranking, snippet() highlights, and unicode61 tokenization.
//
// Architecture:
// - GRDB DatabaseQueue is thread-safe (Sendable) and accessed via nonisolated methods
// - FTS5 content-sync triggers keep the virtual table in sync with indexed_pages
// - Startup diff-sync compares updatedAt between SwiftData and GRDB
// - Incremental: upsert/delete called from VaultIndexActor on each file change
//
// Swift 6 note: DatabaseQueue is Sendable. All GRDB operations are in nonisolated
// methods to avoid actor-hop overhead. The actor serializes only the async diff sync.

actor SearchIndexService {
    private let log = Logger(subsystem: "com.epistemos", category: "SearchIndex")
    private let dbQueue: DatabaseQueue

    init() throws {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("Epistemos", isDirectory: true)
        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

        let dbPath = appSupport.appendingPathComponent("search.sqlite").path
        dbQueue = try DatabaseQueue(path: dbPath)

        try Self.setupSchema(dbQueue)
        log.info("SearchIndexService initialized at \(dbPath, privacy: .public)")
    }

    // MARK: - Schema Migration

    private nonisolated static func setupSchema(_ db: DatabaseQueue) throws {
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

            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS page_search USING fts5(
                    title, body, tags,
                    content='indexed_pages',
                    content_rowid='rowid',
                    tokenize='unicode61'
                )
            """)

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
        try migrator.migrate(db)
    }

    // MARK: - Search
    // nonisolated: DatabaseQueue is Sendable and let-bound, safe to access without actor hop.

    nonisolated func search(query: String, limit: Int = 50) throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let sanitized = Self.sanitizeFTS5Query(query)
        guard !sanitized.isEmpty else { return [] }

        return try dbQueue.read { db in
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

            return rows.map { row in
                SearchResult(
                    pageId: row["id"],
                    title: row["title"],
                    snippet: row["snippet"] ?? "",
                    rank: row["rank"] ?? 0.0
                )
            }
        }
    }

    // MARK: - Upsert / Delete

    nonisolated func upsert(id: String, title: String, body: String, tags: String, updatedAt: Date) throws {
        try dbQueue.write { db in
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
    }

    nonisolated func delete(pageId: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM indexed_pages WHERE id = ?", arguments: [pageId])
        }
    }

    // MARK: - Full Rebuild

    nonisolated func rebuildFromSwiftData(
        _ pages: [(id: String, title: String, body: String, tags: String, updatedAt: Date)]
    ) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM indexed_pages")
            try db.execute(sql: "INSERT INTO page_search(page_search) VALUES('rebuild')")

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
        var upsertCount = 0
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
                    try upsert(
                        id: sd.id, title: full.title, body: full.body,
                        tags: full.tags, updatedAt: full.updatedAt
                    )
                    upsertCount += 1
                }
            }
        }

        log.info("Diff sync complete: \(upsertCount) upserted, \(toDelete.count) deleted")
    }

    // MARK: - Diff Sync Helpers (synchronous)

    /// Fetch all (id, updatedAt) from GRDB for diff comparison.
    private nonisolated func fetchAllTimestamps() throws -> [String: Double] {
        try dbQueue.read { db in
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
        try dbQueue.write { db in
            for id in ids {
                try db.execute(sql: "DELETE FROM indexed_pages WHERE id = ?", arguments: [id])
            }
        }
    }

    // MARK: - FTS5 Query Sanitization

    private nonisolated static func sanitizeFTS5Query(_ raw: String) -> String {
        let words = raw.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }
        guard !words.isEmpty else { return "" }
        return words.map { "\"\($0)\"*" }.joined(separator: " ")
    }
}

// MARK: - SearchResult

nonisolated struct SearchResult: Sendable {
    let pageId: String
    let title: String
    let snippet: String
    let rank: Double
}
