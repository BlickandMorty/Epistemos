import Foundation
import SQLite3
import os

// MARK: - Event Store
// Dedicated SQLite database (separate from SwiftData) for persistent session telemetry.
// Uses WAL mode for lock-free concurrent reads/writes — background event appending
// never blocks the main thread. Stores both fine-grained events and periodic full
// workspace snapshots for O(log n) historical state reconstruction.

// EventStore owns a single SQLite handle for the lifetime of the service.
// All SQLite work is serialized through `queue`, and the handle itself is immutable
// after initialization, so the type can use checked Sendable conformance.
final class EventStore: Sendable {
    nonisolated(unsafe) static var shared: EventStore?
    nonisolated private static let queueKey = DispatchSpecificKey<UInt8>()
    nonisolated private static let queueToken: UInt8 = 1

    nonisolated private static let log = Logger(subsystem: "com.epistemos", category: "EventStore")
    private let queue = DispatchQueue(label: "com.epistemos.eventstore", qos: .utility)
    nonisolated private let databaseURL: URL
    nonisolated(unsafe) private let db: OpaquePointer

    convenience init?() {
        self.init(databaseURL: Self.databaseURL)
    }

    init?(databaseURL url: URL) {
        self.databaseURL = url
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var dbPtr: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &dbPtr, flags, nil) == SQLITE_OK,
              let dbPtr else {
            Self.log.error("EventStore: failed to open database at \(url.path, privacy: .public)")
            return nil
        }
        self.db = dbPtr
        queue.setSpecific(key: Self.queueKey, value: Self.queueToken)

        // Current durability stance: this store still uses system SQLite. On macOS,
        // `synchronous = FULL` may not flush as strongly as a bundled
        // `SQLITE_HAVE_FULLFSYNC=1` build, so verified note-body storage and startup
        // integrity checks remain the compensating controls until bundled SQLite lands.
        guard executeRequired("PRAGMA journal_mode=WAL;"),
              pragmaTextValue("PRAGMA journal_mode;")?.lowercased() == "wal",
              executeRequired("PRAGMA synchronous=FULL;"),
              executeRequired("PRAGMA wal_autocheckpoint=1000;"),
              executeRequired("PRAGMA foreign_keys=ON;") else {
            Self.log.error("EventStore: durable SQLite pragmas failed during open")
            sqlite3_close(dbPtr)
            return nil
        }

        // Integrity check on open — catches corruption immediately (zero-corruption spec §3.2)
        do {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(dbPtr, "PRAGMA integrity_check;", -1, &stmt, nil) == SQLITE_OK else {
                Self.log.error("EventStore: could not prepare integrity_check")
                return nil
            }
            defer { sqlite3_finalize(stmt) }
            var integrityOK = false
            if sqlite3_step(stmt) == SQLITE_ROW,
               let cStr = sqlite3_column_text(stmt, 0) {
                integrityOK = String(cString: cStr) == "ok"
            }
            if !integrityOK {
                Self.log.error("EventStore: integrity_check failed — refusing to open corrupt database")
                sqlite3_close(dbPtr)
                return nil
            }
        }

        createTables()
        refreshFileProtections()
        Self.log.info("EventStore: opened at \(url.path, privacy: .public)")
    }

    deinit {
        sqlite3_close(db)
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

        // Cognitive substrate tables (Phase 0)
        execute("""
            CREATE TABLE IF NOT EXISTS captured_artifacts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_bundle_id TEXT NOT NULL,
                app_name TEXT NOT NULL,
                window_title TEXT,
                url TEXT,
                text_content TEXT NOT NULL,
                captured_at REAL NOT NULL,
                dedupe_hash TEXT NOT NULL UNIQUE,
                ocr_used INTEGER NOT NULL DEFAULT 0
            );
        """)
        execute("CREATE INDEX IF NOT EXISTS idx_artifacts_time ON captured_artifacts(captured_at);")

        execute("""
            CREATE TABLE IF NOT EXISTS friction_windows (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                note_id TEXT NOT NULL,
                session_id TEXT NOT NULL,
                window_start REAL NOT NULL,
                window_end REAL NOT NULL,
                pause_rate REAL NOT NULL,
                mean_pause_duration_ms REAL NOT NULL,
                mean_burst_length_chars REAL NOT NULL,
                burst_length_cv REAL NOT NULL,
                deletion_density REAL NOT NULL,
                regression_frequency REAL NOT NULL,
                friction_score REAL NOT NULL
            );
        """)
        execute("CREATE INDEX IF NOT EXISTS idx_friction_start ON friction_windows(window_start);")
        execute("CREATE INDEX IF NOT EXISTS idx_friction_note ON friction_windows(note_id);")

        execute("""
            CREATE TABLE IF NOT EXISTS night_brain_runs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                started_at REAL NOT NULL,
                completed_at REAL,
                status TEXT NOT NULL,
                jobs_completed TEXT NOT NULL DEFAULT '[]',
                trigger_reason TEXT
            );
        """)
        execute("CREATE INDEX IF NOT EXISTS idx_nightbrain_started ON night_brain_runs(started_at);")

        execute("""
            CREATE TABLE IF NOT EXISTS night_brain_checkpoints (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                run_id INTEGER NOT NULL REFERENCES night_brain_runs(id) ON DELETE CASCADE,
                job_type TEXT NOT NULL,
                checkpoint_data TEXT NOT NULL,
                recorded_at REAL NOT NULL
            );
        """)
        execute("CREATE INDEX IF NOT EXISTS idx_checkpoint_run ON night_brain_checkpoints(run_id);")
    }

    // MARK: - Event Logging

    func appendEvent(sessionId: String, kind: ActivityEventKind) {
        queue.async { [weak self] in
            guard let self else { return }
            let db = self.db
            let timestamp = Date().timeIntervalSince1970
            let kindString: String
            let payload: String

            switch kind {
            case .noteEdited(let pageId, let title, let changed, let total):
                kindString = "note_edited"
                payload = Self.encodeNoteEditedPayload(pageId: pageId, title: title, changed: changed, total: total)
            case .noteOpened(let pageId, let title):
                kindString = "note_opened"
                payload = Self.encodePayload(["pageId": pageId, "title": title])
            case .noteClosed(let pageId, let title):
                kindString = "note_closed"
                payload = Self.encodePayload(["pageId": pageId, "title": title])
            case .chatMessageSent(let chatId, let snippet):
                kindString = "chat_message"
                payload = Self.encodePayload(["chatId": chatId, "snippet": snippet])
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
            self.refreshFileProtections()
        }
    }

    // MARK: - Snapshot Storage

    func saveSnapshot(sessionId: String, snapshotJSON: String, summary: String = "", userNote: String = "") {
        queue.async { [weak self] in
            guard let self else { return }
            let db = self.db
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
            self.refreshFileProtections()

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
        withDatabaseRead { db in
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
    }

    /// Get events between two timestamps. Used to apply deltas after loading a snapshot.
    func events(from startDate: Date, to endDate: Date) -> [StoredEvent] {
        withDatabaseRead { db in
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
        } ?? []
    }

    struct StoredEvent {
        let timestamp: Date
        let sessionId: String
        let kind: String
        let payload: String
    }

    /// Get all snapshots (for timeline display). Returns lightweight metadata only.
    func allSnapshots() -> [SnapshotMeta] {
        withDatabaseRead { db in
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
        } ?? []
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
        withDatabaseRead { db in
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
        } ?? [:]
    }

    // MARK: - Captured Artifacts

    func insertCapturedArtifact(_ artifact: CapturedArtifact) {
        queue.async { [weak self] in
            guard let self else { return }
            let db = self.db
            var stmt: OpaquePointer?
            // INSERT OR IGNORE respects the UNIQUE constraint on dedupe_hash
            let sql = """
                INSERT OR IGNORE INTO captured_artifacts
                (source_bundle_id, app_name, window_title, url, text_content, captured_at, dedupe_hash, ocr_used)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (artifact.sourceBundleId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (artifact.appName as NSString).utf8String, -1, nil)
            if let title = artifact.windowTitle {
                sqlite3_bind_text(stmt, 3, (title as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            if let url = artifact.url {
                sqlite3_bind_text(stmt, 4, (url as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            sqlite3_bind_text(stmt, 5, (artifact.textContent as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 6, artifact.capturedAt)
            sqlite3_bind_text(stmt, 7, (artifact.dedupeHash as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 8, artifact.ocrUsed ? 1 : 0)
            sqlite3_step(stmt)
            self.refreshFileProtections()
        }
    }

    nonisolated func capturedArtifactCount() -> Int {
        withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = "SELECT COUNT(*) FROM captured_artifacts;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int(stmt, 0))
        } ?? 0
    }

    // MARK: - Friction Windows

    nonisolated func insertFrictionWindow(_ window: FrictionWindow) {
        withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = """
                INSERT INTO friction_windows
                (note_id, session_id, window_start, window_end, pause_rate, mean_pause_duration_ms,
                 mean_burst_length_chars, burst_length_cv, deletion_density, regression_frequency, friction_score)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (window.noteId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (window.sessionId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 3, window.windowStart)
            sqlite3_bind_double(stmt, 4, window.windowEnd)
            sqlite3_bind_double(stmt, 5, window.pauseRate)
            sqlite3_bind_double(stmt, 6, window.meanPauseDurationMs)
            sqlite3_bind_double(stmt, 7, window.meanBurstLengthChars)
            sqlite3_bind_double(stmt, 8, window.burstLengthCV)
            sqlite3_bind_double(stmt, 9, window.deletionDensity)
            sqlite3_bind_double(stmt, 10, window.regressionFrequency)
            sqlite3_bind_double(stmt, 11, window.frictionScore)
            sqlite3_step(stmt)
            refreshFileProtections()
        }
    }

    nonisolated func frictionWindows(limit: Int = 100) -> [FrictionWindow] {
        withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = """
                SELECT id, note_id, session_id, window_start, window_end, pause_rate,
                       mean_pause_duration_ms, mean_burst_length_chars, burst_length_cv,
                       deletion_density, regression_frequency, friction_score
                FROM friction_windows
                ORDER BY window_start ASC
                LIMIT ?;
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int(stmt, 1, Int32(limit))

            var results: [FrictionWindow] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(FrictionWindow(
                    id: sqlite3_column_int64(stmt, 0),
                    noteId: String(cString: sqlite3_column_text(stmt, 1)),
                    sessionId: String(cString: sqlite3_column_text(stmt, 2)),
                    windowStart: sqlite3_column_double(stmt, 3),
                    windowEnd: sqlite3_column_double(stmt, 4),
                    pauseRate: sqlite3_column_double(stmt, 5),
                    meanPauseDurationMs: sqlite3_column_double(stmt, 6),
                    meanBurstLengthChars: sqlite3_column_double(stmt, 7),
                    burstLengthCV: sqlite3_column_double(stmt, 8),
                    deletionDensity: sqlite3_column_double(stmt, 9),
                    regressionFrequency: sqlite3_column_double(stmt, 10),
                    frictionScore: sqlite3_column_double(stmt, 11)
                ))
            }
            return results
        } ?? []
    }

    // MARK: - Night Brain Runs

    /// Insert a new run and return its ID. Synchronous (called from Night Brain actor on its queue).
    nonisolated func insertNightBrainRun(status: String, triggerReason: String?) -> Int64? {
        withDatabaseRead { db in
            let timestamp = Date().timeIntervalSince1970
            var stmt: OpaquePointer?
            let sql = "INSERT INTO night_brain_runs (started_at, status, jobs_completed, trigger_reason) VALUES (?, ?, '[]', ?);"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_double(stmt, 1, timestamp)
            sqlite3_bind_text(stmt, 2, (status as NSString).utf8String, -1, nil)
            if let reason = triggerReason {
                sqlite3_bind_text(stmt, 3, (reason as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            guard sqlite3_step(stmt) == SQLITE_DONE else { return nil }
            refreshFileProtections()
            return sqlite3_last_insert_rowid(db)
        }
    }

    nonisolated func updateNightBrainRun(id: Int64, status: String, completedJobs: [String], completedAt: Double? = nil) {
        withDatabaseRead { db in
            let jobsJSON = (try? String(data: JSONEncoder().encode(completedJobs), encoding: .utf8)) ?? "[]"
            var stmt: OpaquePointer?
            let sql = "UPDATE night_brain_runs SET status = ?, jobs_completed = ?, completed_at = ? WHERE id = ?;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (status as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (jobsJSON as NSString).utf8String, -1, nil)
            if let completed = completedAt {
                sqlite3_bind_double(stmt, 3, completed)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            sqlite3_bind_int64(stmt, 4, id)
            sqlite3_step(stmt)
            refreshFileProtections()
        }
    }

    /// Write a checkpoint row for a completed job. Synchronous so it's durable before
    /// the pipeline advances to the next job.
    nonisolated func insertCheckpoint(runId: Int64, jobType: String, data: String) {
        withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = "INSERT INTO night_brain_checkpoints (run_id, job_type, checkpoint_data, recorded_at) VALUES (?, ?, ?, ?);"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_int64(stmt, 1, runId)
            sqlite3_bind_text(stmt, 2, (jobType as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (data as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 4, Date().timeIntervalSince1970)
            sqlite3_step(stmt)
            refreshFileProtections()
        }
    }

    /// Read completed job types from the checkpoint table for a given run.
    /// This is the authoritative source for resume — not the runs table's jobs_completed column.
    nonisolated func checkpointedJobTypes(runId: Int64) -> [String] {
        withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = "SELECT DISTINCT job_type FROM night_brain_checkpoints WHERE run_id = ? ORDER BY recorded_at ASC;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_int64(stmt, 1, runId)

            var results: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(String(cString: sqlite3_column_text(stmt, 0)))
            }
            return results
        } ?? []
    }

    struct NightBrainRunRecord {
        let id: Int64
        let startedAt: Date
        let completedAt: Date?
        let status: String
        let jobsCompleted: [String]
        let triggerReason: String?
    }

    /// Find the most recent interrupted run ID for resume. Returns nil if none.
    nonisolated func mostRecentInterruptedRun() -> Int64? {
        withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = "SELECT id FROM night_brain_runs WHERE status = 'interrupted' ORDER BY started_at DESC LIMIT 1;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            return sqlite3_column_int64(stmt, 0)
        }
    }

    nonisolated func completedNightBrainRuns(limit: Int = 10) -> [NightBrainRunRecord] {
        withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = "SELECT id, started_at, completed_at, status, jobs_completed, trigger_reason FROM night_brain_runs WHERE status = 'completed' ORDER BY started_at DESC LIMIT ?;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_int(stmt, 1, Int32(limit))

            var results: [NightBrainRunRecord] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let completedAtRaw = sqlite3_column_double(stmt, 2)
                let jobsJSON = String(cString: sqlite3_column_text(stmt, 4))
                let jobs = (try? JSONDecoder().decode([String].self, from: Data(jobsJSON.utf8))) ?? []
                let triggerPtr = sqlite3_column_text(stmt, 5)
                results.append(NightBrainRunRecord(
                    id: sqlite3_column_int64(stmt, 0),
                    startedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                    completedAt: completedAtRaw > 0 ? Date(timeIntervalSince1970: completedAtRaw) : nil,
                    status: String(cString: sqlite3_column_text(stmt, 3)),
                    jobsCompleted: jobs,
                    triggerReason: triggerPtr.map { String(cString: $0) }
                ))
            }
            return results
        } ?? []
    }

    // MARK: - Night Brain Maintenance Operations

    nonisolated func walCheckpointVacuum() {
        withDatabaseRead { db in
            sqlite3_exec(db, "PRAGMA wal_checkpoint(PASSIVE);", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA incremental_vacuum(100);", nil, nil, nil)
            Self.log.info("EventStore: WAL checkpoint + incremental vacuum completed")
        }
    }

    nonisolated func deduplicateArtifacts() {
        withDatabaseRead { db in
            // Keep the newest row for each dedupe_hash, delete older duplicates
            let sql = """
                DELETE FROM captured_artifacts WHERE id NOT IN (
                    SELECT MAX(id) FROM captured_artifacts GROUP BY dedupe_hash
                );
            """
            sqlite3_exec(db, sql, nil, nil, nil)
            Self.log.info("EventStore: artifact deduplication completed")
        }
    }

    nonisolated func compactSnapshots(olderThanDays: Int = 30) {
        withDatabaseRead { db in
            let cutoff = Date().addingTimeInterval(-Double(olderThanDays) * 86400).timeIntervalSince1970
            // Keep one snapshot per month for old data: the latest snapshot in each year-month bucket
            let sql = """
                DELETE FROM snapshots WHERE timestamp < ? AND id NOT IN (
                    SELECT MAX(id) FROM snapshots WHERE timestamp < ?
                    GROUP BY CAST(timestamp / 2592000 AS INTEGER)
                );
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_double(stmt, 1, cutoff)
            sqlite3_bind_double(stmt, 2, cutoff)
            sqlite3_step(stmt)
            Self.log.info("EventStore: snapshot compaction completed")
        }
    }

    /// Check if a table exists (for testing).
    nonisolated func tableExists(_ name: String) -> Bool {
        withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name=?;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
            return sqlite3_step(stmt) == SQLITE_ROW
        } ?? false
    }

    // MARK: - Helpers

    private func execute(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    @discardableResult
    private func executeRequired(_ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    private func pragmaTextValue(_ sql: String) -> String? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW, let text = sqlite3_column_text(stmt, 0) else {
            return nil
        }
        return String(cString: text)
    }

    nonisolated private func refreshFileProtections() {
        do {
            try Self.excludeLiveDatabaseFilesFromBackup(databaseURL)
            try Self.excludeParentDirectoryFromSpotlight(databaseURL)
        } catch {
            Self.log.error(
                "EventStore: failed to refresh database file protections: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    nonisolated private func withDatabaseRead<T>(_ body: (OpaquePointer) -> T?) -> T? {
        if DispatchQueue.getSpecific(key: Self.queueKey) == Self.queueToken {
            return body(db)
        }
        return queue.sync {
            return body(db)
        }
    }

    nonisolated private static let payloadEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    nonisolated private static func encodePayload(_ dict: [String: String]) -> String {
        (try? String(data: payloadEncoder.encode(dict), encoding: .utf8)) ?? "{}"
    }

    nonisolated private static func encodeNoteEditedPayload(pageId: String, title: String, changed: Int, total: Int) -> String {
        // Build JSON with proper numeric types using JSONSerialization
        let dict: [String: Any] = ["pageId": pageId, "title": title, "changedParagraphs": changed, "totalParagraphs": total]
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static var databaseURL: URL {
        let appSupport = FoundationSafety.userApplicationSupportDirectory()
        let dir = appSupport.appendingPathComponent("Epistemos")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("event-store.sqlite")
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

    private nonisolated static func excludeParentDirectoryFromSpotlight(_ databaseURL: URL) throws {
        let markerURL = databaseURL.deletingLastPathComponent().appendingPathComponent(".metadata_never_index")
        if !FileManager.default.fileExists(atPath: markerURL.path) {
            FileManager.default.createFile(atPath: markerURL.path, contents: Data())
        }
    }
}
