import Foundation
import SQLite3
import os

// MARK: - Event Store
// Dedicated SQLite database (separate from SwiftData) for persistent session telemetry.
// Uses WAL mode for lock-free concurrent reads/writes — background event appending
// never blocks the main thread. Stores both fine-grained events and periodic full
// workspace snapshots for O(log n) historical state reconstruction.

final class EventStore: @unchecked Sendable {
    static var shared: EventStore?

    private static let log = Logger(subsystem: "com.epistemos", category: "EventStore")
    private let queue = DispatchQueue(label: "com.epistemos.eventstore", qos: .utility)
    nonisolated(unsafe) private var db: OpaquePointer?

    init?() {
        let url = Self.databaseURL
        var dbPtr: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &dbPtr, flags, nil) == SQLITE_OK else {
            Self.log.error("EventStore: failed to open database at \(url.path, privacy: .public)")
            return nil
        }
        self.db = dbPtr

        // WAL mode for concurrent reads/writes
        execute("PRAGMA journal_mode=WAL;")
        execute("PRAGMA synchronous=NORMAL;")

        createTables()
        Self.log.info("EventStore: opened at \(url.path, privacy: .public)")
    }

    deinit {
        let dbPtr = db
        if let dbPtr { sqlite3_close(dbPtr) }
    }

    // MARK: - Schema

    private func createTables() {
        execute("""
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp REAL NOT NULL,
                session_id TEXT NOT NULL,
                kind TEXT NOT NULL,
                payload TEXT NOT NULL DEFAULT '{}'
            );
        """)
        execute("CREATE INDEX IF NOT EXISTS idx_events_time ON events(timestamp);")
        execute("CREATE INDEX IF NOT EXISTS idx_events_session ON events(session_id);")

        execute("""
            CREATE TABLE IF NOT EXISTS snapshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp REAL NOT NULL,
                session_id TEXT NOT NULL,
                snapshot_json TEXT NOT NULL,
                summary TEXT DEFAULT '',
                user_note TEXT DEFAULT ''
            );
        """)
        execute("CREATE INDEX IF NOT EXISTS idx_snapshots_time ON snapshots(timestamp);")
    }

    // MARK: - Event Logging

    func appendEvent(sessionId: String, kind: ActivityEventKind) {
        queue.async { [weak self] in
            guard let self, let db = self.db else { return }
            let timestamp = Date().timeIntervalSince1970
            let kindString: String
            let payload: String

            switch kind {
            case .noteEdited(let pageId, let title, let changed, let total):
                kindString = "note_edited"
                payload = "{\"pageId\":\"\(Self.escape(pageId))\",\"title\":\"\(Self.escape(title))\",\"changedParagraphs\":\(changed),\"totalParagraphs\":\(total)}"
            case .noteOpened(let pageId, let title):
                kindString = "note_opened"
                payload = "{\"pageId\":\"\(Self.escape(pageId))\",\"title\":\"\(Self.escape(title))\"}"
            case .noteClosed(let pageId, let title):
                kindString = "note_closed"
                payload = "{\"pageId\":\"\(Self.escape(pageId))\",\"title\":\"\(Self.escape(title))\"}"
            case .chatMessageSent(let chatId, let snippet):
                kindString = "chat_message"
                payload = "{\"chatId\":\"\(Self.escape(chatId))\",\"snippet\":\"\(Self.escape(snippet))\"}"
            }

            var stmt: OpaquePointer?
            let sql = "INSERT INTO events (timestamp, session_id, kind, payload) VALUES (?, ?, ?, ?);"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_double(stmt, 1, timestamp)
            sqlite3_bind_text(stmt, 2, (sessionId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (kindString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (payload as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
    }

    // MARK: - Snapshot Storage

    func saveSnapshot(sessionId: String, snapshotJSON: String, summary: String = "", userNote: String = "") {
        queue.async { [weak self] in
            guard let self, let db = self.db else { return }
            let timestamp = Date().timeIntervalSince1970

            var stmt: OpaquePointer?
            let sql = "INSERT INTO snapshots (timestamp, session_id, snapshot_json, summary, user_note) VALUES (?, ?, ?, ?, ?);"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_double(stmt, 1, timestamp)
            sqlite3_bind_text(stmt, 2, (sessionId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (snapshotJSON as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (summary as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 5, (userNote as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)

            Self.log.info("EventStore: snapshot saved for session \(sessionId.prefix(8), privacy: .public)")
        }
    }

    // MARK: - Queries (for Time Machine)

    struct StoredSnapshot {
        let timestamp: Date
        let sessionId: String
        let snapshotJSON: String
        let summary: String
        let userNote: String
    }

    /// Find the nearest snapshot at or before a given date. O(log n) via B-tree index.
    func nearestSnapshot(before date: Date) -> StoredSnapshot? {
        guard let db else { return nil }
        let timestamp = date.timeIntervalSince1970
        var stmt: OpaquePointer?
        let sql = "SELECT timestamp, session_id, snapshot_json, summary, user_note FROM snapshots WHERE timestamp <= ? ORDER BY timestamp DESC LIMIT 1;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, timestamp)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        return StoredSnapshot(
            timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0)),
            sessionId: String(cString: sqlite3_column_text(stmt, 1)),
            snapshotJSON: String(cString: sqlite3_column_text(stmt, 2)),
            summary: String(cString: sqlite3_column_text(stmt, 3)),
            userNote: String(cString: sqlite3_column_text(stmt, 4))
        )
    }

    /// Get events between two timestamps. Used to apply deltas after loading a snapshot.
    func events(from startDate: Date, to endDate: Date) -> [StoredEvent] {
        guard let db else { return [] }
        var stmt: OpaquePointer?
        let sql = "SELECT timestamp, session_id, kind, payload FROM events WHERE timestamp > ? AND timestamp <= ? ORDER BY timestamp ASC;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, startDate.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 2, endDate.timeIntervalSince1970)

        var results: [StoredEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(StoredEvent(
                timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0)),
                sessionId: String(cString: sqlite3_column_text(stmt, 1)),
                kind: String(cString: sqlite3_column_text(stmt, 2)),
                payload: String(cString: sqlite3_column_text(stmt, 3))
            ))
        }
        return results
    }

    struct StoredEvent {
        let timestamp: Date
        let sessionId: String
        let kind: String
        let payload: String
    }

    /// Get all snapshots (for timeline display). Returns lightweight metadata only.
    func allSnapshots() -> [SnapshotMeta] {
        guard let db else { return [] }
        var stmt: OpaquePointer?
        let sql = "SELECT id, timestamp, session_id, summary, user_note FROM snapshots ORDER BY timestamp DESC;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var results: [SnapshotMeta] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(SnapshotMeta(
                id: Int(sqlite3_column_int64(stmt, 0)),
                timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                sessionId: String(cString: sqlite3_column_text(stmt, 2)),
                summary: String(cString: sqlite3_column_text(stmt, 3)),
                userNote: String(cString: sqlite3_column_text(stmt, 4))
            ))
        }
        return results
    }

    struct SnapshotMeta: Identifiable {
        let id: Int
        let timestamp: Date
        let sessionId: String
        let summary: String
        let userNote: String
    }

    /// Event density per day (for semantic scrub bar).
    func eventDensityByDay(days: Int = 90) -> [Date: Int] {
        guard let db else { return [:] }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400).timeIntervalSince1970
        var stmt: OpaquePointer?
        let sql = "SELECT CAST(timestamp / 86400 AS INTEGER) as day, COUNT(*) FROM events WHERE timestamp > ? GROUP BY day;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, cutoff)

        var results: [Date: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let dayEpoch = sqlite3_column_int64(stmt, 0)
            let count = Int(sqlite3_column_int(stmt, 1))
            let date = Date(timeIntervalSince1970: Double(dayEpoch) * 86400)
            results[date] = count
        }
        return results
    }

    // MARK: - Helpers

    private func execute(_ sql: String) {
        guard let db else { return }
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private static func escape(_ string: String) -> String {
        string.replacingOccurrences(of: "\\", with: "\\\\")
              .replacingOccurrences(of: "\"", with: "\\\"")
              .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static var databaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Epistemos")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("event-store.sqlite")
    }
}
