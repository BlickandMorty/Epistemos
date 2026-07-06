//
//  DerivedIndexDatabase.swift
//  Epistemos — KEELSTONE spine
//
//  The derived index is a CACHE, not truth. That single fact drives every
//  durability decision here:
//
//   • WAL mode + synchronous = NORMAL. NORMAL is corruption-safe; it can only
//     lose the LAST transaction(s) on power loss, never corrupt. For a cache
//     that's re-derivable from the vault, losing a trailing transaction is
//     fine — startup reconcile re-derives it. FULL would buy durability we
//     don't need and cost write throughput we do need at 100k notes. WAL also
//     lets readers and the single writer run concurrently, so search never
//     blocks indexing.
//
//   • Forward-only migrations via DatabaseMigrator. This is an APP rule, not a
//     library guarantee. eraseDatabaseOnSchemaChange is NEVER enabled in a
//     shipping build — but because the store is derived, a migration that fails
//     is recoverable by quarantine + rebuild rather than by risking user data.
//
//   • Self-heal is quarantine-and-rebuild, not SQLite recovery. Recovered data
//     from a corrupt DB is salvage, not truth. We already have truth on disk —
//     so on integrity failure we quarantine the file and rebuild from the vault.
//
//  WAL growth under a 100k-file sync storm is a real risk (see D9 / risk #2):
//  bound it with wal_autocheckpoint and an explicit TRUNCATE checkpoint after
//  bulk reconciliation. PRAGMA optimize at controlled maintenance points keeps
//  the FTS5 query planner sane without hot-path ANALYZE.
//
//  NOTE: import GRDB in the real target.
//

import Foundation
// import GRDB

public enum IndexDBError: Error, Sendable {
    case integrityFailed(String)
    case quarantined(URL)
    case open(Error)
}

public final class DerivedIndexDatabase: @unchecked Sendable {

    private let path: String
    // private let pool: DatabasePool

    public init(path: String) throws {
        self.path = path
        // var config = Configuration()
        // config.defaultTransactionKind = .immediate       // fewer busy retries
        // config.busyMode = .timeout(5.0)
        // config.qos = .userInitiated
        // config.prepareDatabase { db in
        //     try db.execute(sql: "PRAGMA journal_mode = WAL")
        //     try db.execute(sql: "PRAGMA synchronous = NORMAL")   // cache-appropriate
        //     try db.execute(sql: "PRAGMA wal_autocheckpoint = 1000")
        //     try db.execute(sql: "PRAGMA foreign_keys = ON")
        // }
        // self.pool = try DatabasePool(path: path, configuration: config)
        // try migrator.migrate(pool)
        // try healOrQuarantineOnLaunch()
    }

    // MARK: Migrations (forward-only)

    // private var migrator: DatabaseMigrator {
    //     var m = DatabaseMigrator()
    //     // Explicitly DO NOT set m.eraseDatabaseOnSchemaChange in production.
    //
    //     m.registerMigration("v1_pages_and_fts") { db in
    //         try db.execute(sql: """
    //             CREATE TABLE pages (
    //               id INTEGER PRIMARY KEY,
    //               rel_path TEXT UNIQUE NOT NULL,
    //               inode INTEGER,
    //               size INTEGER NOT NULL,
    //               mtime REAL NOT NULL,
    //               content_hash TEXT NOT NULL,
    //               tombstone INTEGER NOT NULL DEFAULT 0
    //             );
    //         """)
    //         // External-content FTS5 keeps the index lean at scale: the body
    //         // lives once in `pages`, FTS stores only the inverted index.
    //         try db.execute(sql: """
    //             CREATE VIRTUAL TABLE pages_fts USING fts5(
    //               body,
    //               content='pages',
    //               content_rowid='id'
    //             );
    //         """)
    //     }
    //
    //     m.registerMigration("v2_embeddings") { db in
    //         try db.execute(sql: """
    //             CREATE TABLE embeddings (
    //               page_id INTEGER PRIMARY KEY REFERENCES pages(id) ON DELETE CASCADE,
    //               vector BLOB NOT NULL,
    //               model TEXT NOT NULL,
    //               stale INTEGER NOT NULL DEFAULT 0
    //             );
    //         """)
    //     }
    //     return m
    // }

    // MARK: Integrity + self-heal

    /// Run on every launch after an unclean shutdown or a migration. quick_check
    /// is the fast O(N) pass; escalate to integrity_check only in soak/diagnostics.
    public func healOrQuarantineOnLaunch() throws {
        // let result = try pool.read { db in
        //     try String.fetchOne(db, sql: "PRAGMA quick_check") ?? "unknown"
        // }
        // guard result == "ok" else {
        //     try quarantineAndFlagRebuild()
        //     return
        // }
        // Cheap intra-DB drift repair: FTS rows missing for live pages, etc.
        // try repairFTSDrift()
    }

    /// The self-heal path. The DB is derived, so we never "recover" it — we move
    /// the corrupt file aside (for diagnostics) and signal a full rebuild from
    /// the vault. Note bytes are never at risk because they live on disk.
    private func quarantineAndFlagRebuild() throws {
        let src = URL(fileURLWithPath: path)
        let quarantine = src.deletingLastPathComponent()
            .appendingPathComponent("quarantine-\(Int(Date().timeIntervalSince1970)).sqlite")
        try? FileManager.default.moveItem(at: src, to: quarantine)
        throw IndexDBError.quarantined(quarantine)
        // Caller (index bootstrap) responds by calling fullRebuild(fromRoot:).
    }

    /// Call after a bulk reconcile (e.g. a big sync pull) to keep the WAL from
    /// growing without bound and to refresh planner stats.
    public func maintenanceCheckpoint() throws {
        // try pool.writeWithoutTransaction { db in
        //     try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        //     try db.execute(sql: "PRAGMA optimize")   // 3.46.0+ preferred over manual ANALYZE
        // }
    }

    /// Consistent forensic snapshot of a live DB without mutating it. Use for
    /// support bundles — VACUUM INTO / online backup, never a raw file copy.
    public func snapshot(to dest: URL) throws {
        // try pool.read { db in
        //     try db.execute(sql: "VACUUM INTO ?", arguments: [dest.path])
        // }
    }
}
