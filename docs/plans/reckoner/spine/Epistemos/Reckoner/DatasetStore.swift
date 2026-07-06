// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// DEFECTS: (1) The module builds under SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor — as written every
// commit/window read is MAIN-THREAD DB IO. Mark the class/members `nonisolated` (repo precedent:
// SearchIndexService). (2) POOL PLACEMENT UNPINNED — one sentence from a KEELSTONE-B4 violation:
// the injected pool MUST be SearchIndexService's existing DB, with DatasetMigrations.register()
// joining its migrator chain (ReadableBlocksIndex.registerMigration precedent). Never a new
// dataset.sqlite. (3) `formula` table is created but has no record type and commit() never writes
// it — add FormulaRow + the write. (4) Derived-cache honesty holds ONLY if CSV writeback is
// synchronous with each GRDB commit (R1 says it is) — deferred writeback would silently re-flip
// truth to GRDB and break reconciler convergence.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// GRDB is the DERIVED CACHE + transactional working store — never authoritative
// over the vault artifact (F1). DatabasePool = WAL; batch writes in one
// transaction with prepared statements; sparse storage (populated cells only).
// SQLite caveat encoded: WITHOUT ROWID rows spill at ~1/4 page (~1007B on 4096B
// pages) — keep cell payloads small, large text out-of-line.

import Foundation
import GRDB

struct DatasetRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "dataset"
    var id: String; var vaultPath: String; var kind: String
    var schemaJson: String; var createdAt: Date; var updatedAt: Date
}

struct CellRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "cell"
    var datasetId: String; var sheetIndex: Int; var row: Int; var col: Int
    var rawInput: String; var computedValue: String; var valueType: String
}

enum DatasetMigrations {
    static func register(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("reckoner-v1") { db in
            try db.create(table: "dataset") { t in
                t.column("id", .text).primaryKey()
                t.column("vaultPath", .text).notNull().indexed()
                t.column("kind", .text).notNull()
                t.column("schemaJson", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.execute(sql: """
                CREATE TABLE cell(
                  datasetId TEXT NOT NULL, sheetIndex INTEGER NOT NULL,
                  row INTEGER NOT NULL, col INTEGER NOT NULL,
                  rawInput TEXT NOT NULL, computedValue TEXT NOT NULL,
                  valueType TEXT NOT NULL,
                  PRIMARY KEY(datasetId, sheetIndex, row, col)
                ) WITHOUT ROWID
                """)
            try db.execute(sql: """
                CREATE TABLE formula(
                  datasetId TEXT NOT NULL, sheetIndex INTEGER NOT NULL,
                  row INTEGER NOT NULL, col INTEGER NOT NULL,
                  formulaSrc TEXT NOT NULL,
                  PRIMARY KEY(datasetId, sheetIndex, row, col)
                ) WITHOUT ROWID
                """)
        }
    }
}

final class DatasetStore {
    private let pool: DatabasePool // WAL
    init(pool: DatabasePool) { self.pool = pool }

    /// Batch commit of a calc result — one write transaction, prepared statements.
    func commit(datasetId: String, edits: [CellRow]) throws {
        try pool.write { db in
            for e in edits { try e.save(db) } // TODO: prepared-statement reuse for bulk
        }
    }

    /// Virtualized hydration for the grid: visible window + buffer, not the world.
    func window(datasetId: String, sheet: Int, rows: Range<Int>) throws -> [CellRow] {
        try pool.read { db in
            try CellRow
                .filter(Column("datasetId") == datasetId && Column("sheetIndex") == sheet)
                .filter(rows.contains(Column("row")))
                .fetchAll(db)
        }
    }
}
