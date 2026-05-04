import Foundation
import GRDB
import SQLite3
import Testing
@testable import Epistemos

// MARK: - GRDBPragmaTests
// Wave 2.3 (dpp §1.1 Task 0.3) — verify the derivative-index GRDB pragma
// block is applied end-to-end through SearchIndexService's DatabasePool.
//
// Most values are connection-scoped, so tests read them through the live
// pool. File-level values still get a raw sqlite3 cross-check.
//
// ZERO_CORRUPTION_SPEC interaction: this index is derivative (rebuildable
// from SwiftData + vault), so the dpp NORMAL/fullfsync=0 profile is
// intentional here — see databaseConfiguration() in SearchIndexService for
// the full rationale.

@Suite("GRDB Canonical Pragma Block (Wave 2.3)")
struct GRDBPragmaTests {

    // MARK: - Helpers (mirror SearchIndexServiceIntegrationTests)

    private func makeDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("grdb-pragma-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("search.sqlite")
    }

    /// Read a pragma value through a fresh read-only sqlite3 handle on the
    /// same file. Returns the first column of the first row as a String.
    private func pragmaString(databaseURL: URL, pragma: String) throws -> String? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(
            databaseURL.path,
            &db,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA \(pragma);", -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW, let text = sqlite3_column_text(stmt, 0) else {
            return nil
        }
        return String(cString: text)
    }

    private func pragmaInt(databaseURL: URL, pragma: String) throws -> Int64? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(
            databaseURL.path,
            &db,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA \(pragma);", -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return sqlite3_column_int64(stmt, 0)
    }

    // MARK: - Tests

    // Most pragmas in the canonical block (synchronous, temp_store, mmap_size,
    // cache_size, foreign_keys) are *connection-scoped* in SQLite — opening a
    // separate sqlite3_open_v2() handle does NOT see what `prepareDatabase`
    // set on GRDB's pool connections. We therefore read them through the live
    // pool via `testReadPragmaInt`. journal_mode and page_size are persisted
    // on the file itself and can be read with either approach; we use the
    // pool path uniformly for consistency.

    @Test("journal_mode is wal")
    func journalModeIsWAL() throws {
        let url = makeDatabaseURL()
        let service = try SearchIndexService(databaseURL: url)
        let mode = try service.testReadPragmaString("journal_mode")
        #expect(mode?.lowercased() == "wal")
        // Cross-check via raw sqlite3 — journal_mode is file-level persisted.
        let fileMode = try pragmaString(databaseURL: url, pragma: "journal_mode")
        #expect(fileMode?.lowercased() == "wal")
    }

    @Test("mmap_size is 256 MiB (268435456)")
    func mmapSizeIs256MiB() throws {
        let url = makeDatabaseURL()
        let service = try SearchIndexService(databaseURL: url)
        let value = try service.testReadPragmaInt("mmap_size")
        #expect(value == 268_435_456)
    }

    @Test("synchronous is NORMAL (1)")
    func synchronousIsNormal() throws {
        let url = makeDatabaseURL()
        let service = try SearchIndexService(databaseURL: url)
        let value = try service.testReadPragmaInt("synchronous")
        #expect(value == 1)
    }

    @Test("temp_store is MEMORY (2)")
    func tempStoreIsMemory() throws {
        let url = makeDatabaseURL()
        let service = try SearchIndexService(databaseURL: url)
        let value = try service.testReadPragmaInt("temp_store")
        #expect(value == 2)
    }

    @Test("cache_size is -8192 (8 MiB negative-kibibytes)")
    func cacheSizeIsNegative8MiB() throws {
        let url = makeDatabaseURL()
        let service = try SearchIndexService(databaseURL: url)
        let value = try service.testReadPragmaInt("cache_size")
        #expect(value == -8_192)
    }

    @Test("page_size is 4096")
    func pageSizeIs4096() throws {
        let url = makeDatabaseURL()
        let service = try SearchIndexService(databaseURL: url)
        let value = try service.testReadPragmaInt("page_size")
        #expect(value == 4096)
        // Cross-check via raw sqlite3 — page_size is persisted in the file
        // header on first write.
        let fileValue = try pragmaInt(databaseURL: url, pragma: "page_size")
        #expect(fileValue == 4096)
    }

    @Test("foreign_keys is ON (1)")
    func foreignKeysOn() throws {
        let url = makeDatabaseURL()
        let service = try SearchIndexService(databaseURL: url)
        let value = try service.testReadPragmaInt("foreign_keys")
        #expect(value == 1)
    }
}
