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
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            Self.log.error(
                "EventStore: failed to create database directory at \(url.deletingLastPathComponent().path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
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

        // Quick integrity check on open — O(1) B-tree check, not full-table scan.
        // Full integrity_check is deferred to startup integrity service to avoid blocking launch.
        do {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(dbPtr, "PRAGMA quick_check;", -1, &stmt, nil) == SQLITE_OK else {
                Self.log.error("EventStore: could not prepare quick_check")
                sqlite3_close(dbPtr)
                return nil
            }
            defer { sqlite3_finalize(stmt) }
            var integrityOK = false
            if sqlite3_step(stmt) == SQLITE_ROW,
               let cStr = sqlite3_column_text(stmt, 0) {
                integrityOK = String(cString: cStr) == "ok"
            }
            if !integrityOK {
                Self.log.error("EventStore: quick_check failed — refusing to open corrupt database")
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

        execute("""
            CREATE TABLE IF NOT EXISTS session_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL UNIQUE,
                recorded_at REAL NOT NULL,
                classification TEXT NOT NULL,
                displacement REAL NOT NULL,
                path_length REAL NOT NULL,
                curvature_ratio REAL NOT NULL,
                loop_count INTEGER NOT NULL,
                error_count INTEGER NOT NULL,
                total_calls INTEGER NOT NULL,
                efficiency REAL NOT NULL,
                input_tokens INTEGER NOT NULL DEFAULT 0,
                output_tokens INTEGER NOT NULL DEFAULT 0,
                cache_read_input_tokens INTEGER NOT NULL DEFAULT 0,
                cache_creation_input_tokens INTEGER NOT NULL DEFAULT 0
            );
        """)
        execute("CREATE INDEX IF NOT EXISTS idx_session_metrics_classification ON session_metrics(classification);")
        // N1 Phase 1 closure migration (MASTER_BUILD_PLAN.md:311) —
        // existing databases predate the token columns; these ALTER
        // TABLE statements are idempotent (sqlite3 returns SQLITE_ERROR
        // on duplicate column add, swallowed by `execute`). Fresh
        // databases pick the columns up from the CREATE TABLE block
        // above; upgraded users get them on next open. NOT NULL
        // DEFAULT 0 keeps `SessionMetricsRecord` round-trips honest
        // for the historical rows that never tracked these fields.
        // input_tokens + output_tokens land alongside the cache pair
        // because the W9.6 cost dashboard's cached-tokens share is
        // `cache_read / (input + cache_read)` — without input_tokens
        // the dashboard would either lie (denominator only counting
        // cache, share rounds to 100 %) or stay silent.
        execute("ALTER TABLE session_metrics ADD COLUMN input_tokens INTEGER NOT NULL DEFAULT 0;")
        execute("ALTER TABLE session_metrics ADD COLUMN output_tokens INTEGER NOT NULL DEFAULT 0;")
        execute("ALTER TABLE session_metrics ADD COLUMN cache_read_input_tokens INTEGER NOT NULL DEFAULT 0;")
        execute("ALTER TABLE session_metrics ADD COLUMN cache_creation_input_tokens INTEGER NOT NULL DEFAULT 0;")

        execute("""
            CREATE TABLE IF NOT EXISTS mutation_envelopes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                mutation_id TEXT NOT NULL UNIQUE,
                recorded_at REAL NOT NULL,
                trace_id TEXT,
                status TEXT NOT NULL,
                artifact_id TEXT,
                artifact_kind TEXT,
                integrity_hash TEXT NOT NULL,
                json TEXT NOT NULL
            );
        """)
        execute("CREATE INDEX IF NOT EXISTS idx_mutation_envelopes_trace ON mutation_envelopes(trace_id);")
        execute("CREATE INDEX IF NOT EXISTS idx_mutation_envelopes_artifact ON mutation_envelopes(artifact_id);")

        execute("""
            CREATE TABLE IF NOT EXISTS mutation_projection_outbox (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                mutation_id TEXT NOT NULL UNIQUE,
                recorded_at REAL NOT NULL,
                trace_id TEXT,
                event_kind TEXT NOT NULL,
                status TEXT NOT NULL,
                artifact_id TEXT,
                artifact_kind TEXT,
                integrity_hash TEXT NOT NULL,
                payload TEXT NOT NULL,
                oplog_seq INTEGER,
                projected_at REAL,
                lease_owner TEXT,
                lease_until REAL,
                attempt_count INTEGER NOT NULL DEFAULT 0,
                last_error TEXT,
                dead_lettered_at REAL,
                dead_letter_reason TEXT
            );
        """)
        execute("ALTER TABLE mutation_projection_outbox ADD COLUMN oplog_seq INTEGER;")
        execute("ALTER TABLE mutation_projection_outbox ADD COLUMN projected_at REAL;")
        execute("ALTER TABLE mutation_projection_outbox ADD COLUMN lease_owner TEXT;")
        execute("ALTER TABLE mutation_projection_outbox ADD COLUMN lease_until REAL;")
        execute("ALTER TABLE mutation_projection_outbox ADD COLUMN attempt_count INTEGER NOT NULL DEFAULT 0;")
        execute("ALTER TABLE mutation_projection_outbox ADD COLUMN last_error TEXT;")
        execute("ALTER TABLE mutation_projection_outbox ADD COLUMN dead_lettered_at REAL;")
        execute("ALTER TABLE mutation_projection_outbox ADD COLUMN dead_letter_reason TEXT;")
        execute("CREATE INDEX IF NOT EXISTS idx_mutation_projection_outbox_trace ON mutation_projection_outbox(trace_id);")
        execute("CREATE INDEX IF NOT EXISTS idx_mutation_projection_outbox_kind ON mutation_projection_outbox(event_kind);")
        execute("CREATE INDEX IF NOT EXISTS idx_mutation_projection_outbox_pending ON mutation_projection_outbox(oplog_seq, id);")
        execute("CREATE INDEX IF NOT EXISTS idx_mutation_projection_outbox_claim ON mutation_projection_outbox(oplog_seq, lease_until, id);")
        execute("""
            CREATE INDEX IF NOT EXISTS idx_mutation_projection_outbox_claimable
            ON mutation_projection_outbox(oplog_seq, dead_lettered_at, lease_until, id);
        """)

        execute("""
            CREATE TABLE IF NOT EXISTS agent_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_id TEXT NOT NULL UNIQUE,
                run_id TEXT NOT NULL,
                trace_id TEXT,
                sequence INTEGER NOT NULL,
                kind TEXT NOT NULL,
                tool_name TEXT,
                occurred_at REAL NOT NULL,
                json TEXT NOT NULL
            );
        """)
        execute("CREATE INDEX IF NOT EXISTS idx_agent_events_run ON agent_events(run_id, sequence, occurred_at, id);")
        execute("CREATE INDEX IF NOT EXISTS idx_agent_events_trace ON agent_events(trace_id);")
        execute("CREATE INDEX IF NOT EXISTS idx_agent_events_tool ON agent_events(tool_name);")

        execute("""
            CREATE TABLE IF NOT EXISTS graph_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_id TEXT NOT NULL UNIQUE,
                mutation_id TEXT NOT NULL,
                run_id TEXT,
                trace_id TEXT,
                sequence INTEGER NOT NULL,
                kind TEXT NOT NULL,
                entity_id TEXT,
                entity_kind TEXT,
                occurred_at REAL NOT NULL,
                json TEXT NOT NULL
            );
        """)
        execute("CREATE INDEX IF NOT EXISTS idx_graph_events_mutation ON graph_events(mutation_id, sequence, occurred_at, id);")
        execute("CREATE INDEX IF NOT EXISTS idx_graph_events_trace ON graph_events(trace_id);")
        execute("CREATE INDEX IF NOT EXISTS idx_graph_events_entity ON graph_events(entity_id);")
        execute("CREATE INDEX IF NOT EXISTS idx_graph_events_kind ON graph_events(kind);")

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

            Self.log.info("EventStore: snapshot saved for session \(sessionId.prefix(8), privacy: .public)")
        }
    }

    struct SessionMetricsRecord: Sendable, Equatable {
        let sessionId: String
        let recordedAt: Date
        let classification: String
        let displacement: Double
        let pathLength: Double
        let curvatureRatio: Double
        let loopCount: Int
        let errorCount: Int
        let totalCalls: Int
        let efficiency: Double
        // N1 Phase 1 closure (MASTER_BUILD_PLAN.md:311) — token
        // accounting surfaced from AgentResultFFI. Default 0 for
        // historical rows. Input + output flow from
        // result.inputTokens / result.outputTokens; cache pair flows
        // from the Anthropic-only cacheReadInputTokens /
        // cacheCreationInputTokens fields added in PR1 (b8d779ca).
        let inputTokens: Int
        let outputTokens: Int
        let cacheReadInputTokens: Int
        let cacheCreationInputTokens: Int

        /// Computed: cache hit share for the W9.6 cost dashboard.
        /// `cache_read / (input + cache_read)` — cache_creation is the
        /// one-time write and does NOT enter the hit-rate denominator.
        /// Returns 0 when total billed input is 0.
        var cachedTokensShare: Double {
            let total = inputTokens + cacheReadInputTokens
            guard total > 0 else { return 0.0 }
            return min(max(Double(cacheReadInputTokens) / Double(total), 0.0), 1.0)
        }
    }

    nonisolated func saveSessionMetrics(
        sessionId: String,
        metrics: ReasoningTrajectoryMetricsFFI,
        inputTokens: UInt32 = 0,
        outputTokens: UInt32 = 0,
        cacheReadInputTokens: UInt32 = 0,
        cacheCreationInputTokens: UInt32 = 0
    ) {
        queue.async { [weak self] in
            guard let self else { return }
            let db = self.db
            let timestamp = Date().timeIntervalSince1970
            let sql = """
                INSERT INTO session_metrics (
                    session_id, recorded_at, classification, displacement, path_length,
                    curvature_ratio, loop_count, error_count, total_calls, efficiency,
                    input_tokens, output_tokens,
                    cache_read_input_tokens, cache_creation_input_tokens
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(session_id) DO UPDATE SET
                    recorded_at = excluded.recorded_at,
                    classification = excluded.classification,
                    displacement = excluded.displacement,
                    path_length = excluded.path_length,
                    curvature_ratio = excluded.curvature_ratio,
                    loop_count = excluded.loop_count,
                    error_count = excluded.error_count,
                    total_calls = excluded.total_calls,
                    efficiency = excluded.efficiency,
                    input_tokens = excluded.input_tokens,
                    output_tokens = excluded.output_tokens,
                    cache_read_input_tokens = excluded.cache_read_input_tokens,
                    cache_creation_input_tokens = excluded.cache_creation_input_tokens;
            """

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (sessionId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, timestamp)
            sqlite3_bind_text(stmt, 3, (metrics.classification as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 4, metrics.displacement)
            sqlite3_bind_double(stmt, 5, metrics.pathLength)
            sqlite3_bind_double(stmt, 6, metrics.curvatureRatio)
            sqlite3_bind_int(stmt, 7, Int32(metrics.loopCount))
            sqlite3_bind_int(stmt, 8, Int32(metrics.errorCount))
            sqlite3_bind_int(stmt, 9, Int32(metrics.totalCalls))
            sqlite3_bind_double(stmt, 10, metrics.efficiency)
            sqlite3_bind_int(stmt, 11, Int32(bitPattern: inputTokens))
            sqlite3_bind_int(stmt, 12, Int32(bitPattern: outputTokens))
            sqlite3_bind_int(stmt, 13, Int32(bitPattern: cacheReadInputTokens))
            sqlite3_bind_int(stmt, 14, Int32(bitPattern: cacheCreationInputTokens))
            sqlite3_step(stmt)
        }
    }

    /// W9.3 — read back the most recent metrics row for `sessionId`.
    /// Returns nil if no row has been recorded yet (session still in
    /// flight, or run completed before W9.3 wired the persistence path).
    /// Synchronous over `withDatabaseRead` so SwiftUI views can call it
    /// from a `.task` and bind to the result without an async dance.
    nonisolated func loadSessionMetrics(sessionId: String) -> SessionMetricsRecord? {
        withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = """
                SELECT recorded_at, classification, displacement, path_length,
                       curvature_ratio, loop_count, error_count, total_calls, efficiency,
                       input_tokens, output_tokens,
                       cache_read_input_tokens, cache_creation_input_tokens
                FROM session_metrics
                WHERE session_id = ?
                LIMIT 1;
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (sessionId as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            return SessionMetricsRecord(
                sessionId: sessionId,
                recordedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0)),
                classification: String(cString: sqlite3_column_text(stmt, 1)),
                displacement: sqlite3_column_double(stmt, 2),
                pathLength: sqlite3_column_double(stmt, 3),
                curvatureRatio: sqlite3_column_double(stmt, 4),
                loopCount: Int(sqlite3_column_int(stmt, 5)),
                errorCount: Int(sqlite3_column_int(stmt, 6)),
                totalCalls: Int(sqlite3_column_int(stmt, 7)),
                efficiency: sqlite3_column_double(stmt, 8),
                inputTokens: Int(sqlite3_column_int(stmt, 9)),
                outputTokens: Int(sqlite3_column_int(stmt, 10)),
                cacheReadInputTokens: Int(sqlite3_column_int(stmt, 11)),
                cacheCreationInputTokens: Int(sqlite3_column_int(stmt, 12))
            )
        }
    }

    // MARK: - Mutation Envelope Storage

    nonisolated static let mutationEnvelopeCommittedEventKind = "mutation_envelope_committed"
    nonisolated private static let mutationProjectionOutboxLastErrorMaximum = 512
    nonisolated private static let mutationProjectionOutboxReadLimitMaximum = 500
    nonisolated private static let agentEventReadLimitMaximum = 500
    nonisolated private static let graphEventReadLimitMaximum = 500
    nonisolated private static let mutationProjectionOutboxSelectColumns = """
        mutation_id, recorded_at, trace_id, event_kind, status,
        artifact_id, artifact_kind, integrity_hash, payload,
        oplog_seq, projected_at, lease_owner, lease_until, attempt_count,
        last_error, dead_lettered_at, dead_letter_reason
    """

    @discardableResult
    nonisolated func saveMutationEnvelope(_ envelope: MutationEnvelope, traceId: String? = nil) -> Bool {
        let json: String
        do {
            let data = try Self.payloadEncoder.encode(envelope)
            guard let encoded = String(data: data, encoding: .utf8) else {
                Self.log.error("EventStore: failed to encode mutation envelope as UTF-8 text")
                return false
            }
            json = encoded
        } catch {
            Self.log.error(
                "EventStore: failed to encode mutation envelope \(envelope.mutationID, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }

        let artifact = Self.mutationArtifactProjection(envelope.op)
        return withDatabaseRead { db in
            guard sqlite3_exec(db, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil) == SQLITE_OK else {
                Self.log.error(
                    "EventStore: failed to begin mutation envelope transaction: \(String(cString: sqlite3_errmsg(db)), privacy: .public)"
                )
                return false
            }

            var didCommit = false
            defer {
                if !didCommit {
                    sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                }
            }

            var stmt: OpaquePointer?
            let sql = """
                INSERT INTO mutation_envelopes (
                    mutation_id, recorded_at, trace_id, status, artifact_id,
                    artifact_kind, integrity_hash, json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(mutation_id) DO UPDATE SET
                    recorded_at = excluded.recorded_at,
                    trace_id = excluded.trace_id,
                    status = excluded.status,
                    artifact_id = excluded.artifact_id,
                    artifact_kind = excluded.artifact_kind,
                    integrity_hash = excluded.integrity_hash,
                    json = excluded.json;
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                Self.log.error(
                    "EventStore: failed to prepare mutation envelope save: \(String(cString: sqlite3_errmsg(db)), privacy: .public)"
                )
                return false
            }
            defer {
                if let stmt {
                    sqlite3_finalize(stmt)
                }
            }

            sqlite3_bind_text(stmt, 1, (envelope.mutationID as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
            Self.bindNullableText(traceId, to: stmt, index: 3)
            sqlite3_bind_text(stmt, 4, (envelope.status.rawValue as NSString).utf8String, -1, nil)
            Self.bindNullableText(artifact.id, to: stmt, index: 5)
            Self.bindNullableText(artifact.kind, to: stmt, index: 6)
            sqlite3_bind_text(stmt, 7, (envelope.integrityHash as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 8, (json as NSString).utf8String, -1, nil)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                Self.log.error(
                    "EventStore: failed to save mutation envelope \(envelope.mutationID, privacy: .public): \(String(cString: sqlite3_errmsg(db)), privacy: .public)"
                )
                return false
            }
            sqlite3_finalize(stmt)
            stmt = nil

            if envelope.status == .committed {
                guard Self.insertMutationProjectionOutbox(
                    envelope,
                    traceId: traceId,
                    artifact: artifact,
                    db: db
                ) else {
                    return false
                }
                guard Self.insertGraphEvents(
                    for: envelope,
                    traceId: traceId,
                    db: db
                ) else {
                    return false
                }
            }

            guard sqlite3_exec(db, "COMMIT;", nil, nil, nil) == SQLITE_OK else {
                Self.log.error(
                    "EventStore: failed to commit mutation envelope transaction \(envelope.mutationID, privacy: .public): \(String(cString: sqlite3_errmsg(db)), privacy: .public)"
                )
                return false
            }
            didCommit = true
            return true
        } ?? false
    }

    nonisolated func loadMutationEnvelope(mutationID: String) -> MutationEnvelope? {
        withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = "SELECT json FROM mutation_envelopes WHERE mutation_id = ? LIMIT 1;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (mutationID as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_ROW, let text = sqlite3_column_text(stmt, 0) else {
                return nil
            }

            let json = String(cString: text)
            do {
                return try JSONDecoder().decode(MutationEnvelope.self, from: Data(json.utf8))
            } catch {
                Self.log.error(
                    "EventStore: failed to decode mutation envelope \(mutationID, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                return nil
            }
        }
    }

    @discardableResult
    nonisolated func saveAgentEvent(_ event: AgentProvenanceEvent) -> Bool {
        let eventID = event.eventID.trimmingCharacters(in: .whitespacesAndNewlines)
        let runID = event.runID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !eventID.isEmpty,
              !runID.isEmpty,
              event.sequence <= UInt64(Int64.max) else {
            return false
        }
        let occurredAt = Double(event.occurredAtMs) / 1_000
        guard occurredAt.isFinite else { return false }

        let json: String
        do {
            let data = try Self.payloadEncoder.encode(event)
            guard let encoded = String(data: data, encoding: .utf8) else {
                Self.log.error("EventStore: failed to encode AgentProvenanceEvent as UTF-8 text")
                return false
            }
            json = encoded
        } catch {
            Self.log.error(
                "EventStore: failed to encode AgentProvenanceEvent \(event.eventID, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }

        return withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = """
                INSERT INTO agent_events (
                    event_id, run_id, trace_id, sequence, kind,
                    tool_name, occurred_at, json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(event_id) DO UPDATE SET
                    run_id = excluded.run_id,
                    trace_id = excluded.trace_id,
                    sequence = excluded.sequence,
                    kind = excluded.kind,
                    tool_name = excluded.tool_name,
                    occurred_at = excluded.occurred_at,
                    json = excluded.json;
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                Self.log.error(
                    "EventStore: failed to prepare AgentProvenanceEvent save: \(String(cString: sqlite3_errmsg(db)), privacy: .public)"
                )
                return false
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (eventID as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (runID as NSString).utf8String, -1, nil)
            Self.bindNullableText(event.traceID, to: stmt, index: 3)
            sqlite3_bind_int64(stmt, 4, Int64(event.sequence))
            sqlite3_bind_text(stmt, 5, (event.kind.rawValue as NSString).utf8String, -1, nil)
            Self.bindNullableText(event.tool?.toolName, to: stmt, index: 6)
            sqlite3_bind_double(stmt, 7, occurredAt)
            sqlite3_bind_text(stmt, 8, (json as NSString).utf8String, -1, nil)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                Self.log.error(
                    "EventStore: failed to save AgentProvenanceEvent \(event.eventID, privacy: .public): \(String(cString: sqlite3_errmsg(db)), privacy: .public)"
                )
                return false
            }
            return true
        } ?? false
    }

    nonisolated func loadAgentEvent(eventID: String) -> AgentProvenanceEvent? {
        let eventID = eventID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !eventID.isEmpty else { return nil }

        return withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = "SELECT json FROM agent_events WHERE event_id = ? LIMIT 1;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (eventID as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_ROW,
                  let json = Self.columnText(stmt, 0) else {
                return nil
            }
            return Self.decodeAgentEventJSON(json, context: eventID)
        }
    }

    nonisolated func agentEvents(runID: String, limit: Int = 100) -> [AgentProvenanceEvent] {
        let runID = runID.trimmingCharacters(in: .whitespacesAndNewlines)
        let boundedLimit = min(max(limit, 0), Self.agentEventReadLimitMaximum)
        guard !runID.isEmpty, boundedLimit > 0 else { return [] }

        return withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = """
                SELECT json
                FROM agent_events
                WHERE run_id = ?
                ORDER BY sequence ASC, occurred_at ASC, id ASC
                LIMIT ?;
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (runID as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 2, Int32(boundedLimit))

            var events: [AgentProvenanceEvent] = []
            events.reserveCapacity(boundedLimit)
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let json = Self.columnText(stmt, 0),
                      let event = Self.decodeAgentEventJSON(json, context: runID) else {
                    continue
                }
                events.append(event)
            }
            return events
        } ?? []
    }

    @discardableResult
    nonisolated func saveGraphEvent(_ event: DurableGraphEvent) -> Bool {
        withDatabaseRead { db in
            Self.insertGraphEvent(event, db: db)
        } ?? false
    }

    nonisolated func loadGraphEvent(eventID: String) -> DurableGraphEvent? {
        let eventID = eventID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !eventID.isEmpty else { return nil }

        return withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = "SELECT json FROM graph_events WHERE event_id = ? LIMIT 1;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (eventID as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_ROW,
                  let json = Self.columnText(stmt, 0) else {
                return nil
            }
            return Self.decodeGraphEventJSON(json, context: eventID)
        }
    }

    nonisolated func graphEvents(mutationID: String, limit: Int = 100) -> [DurableGraphEvent] {
        let mutationID = mutationID.trimmingCharacters(in: .whitespacesAndNewlines)
        let boundedLimit = min(max(limit, 0), Self.graphEventReadLimitMaximum)
        guard !mutationID.isEmpty, boundedLimit > 0 else { return [] }

        return withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = """
                SELECT json
                FROM graph_events
                WHERE mutation_id = ?
                ORDER BY sequence ASC, occurred_at ASC, id ASC
                LIMIT ?;
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (mutationID as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 2, Int32(boundedLimit))

            var events: [DurableGraphEvent] = []
            events.reserveCapacity(boundedLimit)
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let json = Self.columnText(stmt, 0),
                      let event = Self.decodeGraphEventJSON(json, context: mutationID) else {
                    continue
                }
                events.append(event)
            }
            return events
        } ?? []
    }

    nonisolated func recentGraphEvents(limit: Int = 100) -> [DurableGraphEvent] {
        let boundedLimit = min(max(limit, 0), Self.graphEventReadLimitMaximum)
        guard boundedLimit > 0 else { return [] }

        return withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = """
                SELECT json
                FROM graph_events
                ORDER BY occurred_at DESC, sequence DESC, id DESC
                LIMIT ?;
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int(stmt, 1, Int32(boundedLimit))

            var events: [DurableGraphEvent] = []
            events.reserveCapacity(boundedLimit)
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let json = Self.columnText(stmt, 0),
                      let event = Self.decodeGraphEventJSON(json, context: "recent") else {
                    continue
                }
                events.append(event)
            }
            return Array(events.reversed())
        } ?? []
    }

    nonisolated struct MutationProjectionOutboxRow: Equatable, Sendable {
        let mutationID: String
        let recordedAt: Date
        let traceID: String?
        let eventKind: String
        let status: String
        let artifactID: String?
        let artifactKind: String?
        let integrityHash: String
        let payload: String
        let opLogSeq: UInt64?
        let projectedAt: Date?
        let leaseOwner: String?
        let leaseUntil: Date?
        let attemptCount: Int
        let lastError: String?
        let deadLetteredAt: Date?
        let deadLetterReason: String?
    }

    nonisolated struct MutationProjectionOutboxDiagnostics: Equatable, Sendable {
        let totalRows: Int
        let pendingRows: Int
        let leasedRows: Int
        let projectedRows: Int
        let deadLetteredRows: Int
        let latestDeadLetter: MutationProjectionOutboxRow?

        nonisolated static let empty = MutationProjectionOutboxDiagnostics(
            totalRows: 0,
            pendingRows: 0,
            leasedRows: 0,
            projectedRows: 0,
            deadLetteredRows: 0,
            latestDeadLetter: nil
        )
    }

    nonisolated struct GraphEventDiagnostics: Equatable, Sendable {
        let totalRows: Int
        let distinctMutations: Int
        let latestEvent: DurableGraphEvent?

        var lastKind: DurableGraphEventKind? {
            latestEvent?.kind
        }

        nonisolated static let empty = GraphEventDiagnostics(
            totalRows: 0,
            distinctMutations: 0,
            latestEvent: nil
        )
    }

    nonisolated func graphEventDiagnostics() -> GraphEventDiagnostics {
        withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = """
                SELECT COUNT(*), COUNT(DISTINCT mutation_id)
                FROM graph_events;
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return .empty
            }
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW else {
                return .empty
            }

            return GraphEventDiagnostics(
                totalRows: Self.columnInt(stmt, 0),
                distinctMutations: Self.columnInt(stmt, 1),
                latestEvent: Self.latestGraphEvent(db: db)
            )
        } ?? .empty
    }

    nonisolated func mutationProjectionOutboxRows(mutationID: String) -> [MutationProjectionOutboxRow] {
        withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = """
                SELECT \(Self.mutationProjectionOutboxSelectColumns)
                FROM mutation_projection_outbox
                WHERE mutation_id = ?
                ORDER BY recorded_at ASC;
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (mutationID as NSString).utf8String, -1, nil)

            var rows: [MutationProjectionOutboxRow] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                rows.append(Self.mutationProjectionOutboxRow(from: stmt))
            }
            return rows
        } ?? []
    }

    nonisolated func mutationProjectionOutboxDiagnostics(
        now: Date = Date()
    ) -> MutationProjectionOutboxDiagnostics {
        let nowTimestamp = now.timeIntervalSince1970
        guard nowTimestamp.isFinite else { return .empty }

        return withDatabaseRead { db in
            let counts: (
                totalRows: Int,
                pendingRows: Int,
                leasedRows: Int,
                projectedRows: Int,
                deadLetteredRows: Int
            )

            do {
                var stmt: OpaquePointer?
                let sql = """
                    SELECT
                        COUNT(*),
                        SUM(CASE WHEN oplog_seq IS NULL
                                  AND dead_lettered_at IS NULL
                                  AND (lease_until IS NULL OR lease_until <= ?)
                                 THEN 1 ELSE 0 END),
                        SUM(CASE WHEN oplog_seq IS NULL
                                  AND dead_lettered_at IS NULL
                                  AND lease_until > ?
                                 THEN 1 ELSE 0 END),
                        SUM(CASE WHEN oplog_seq IS NOT NULL THEN 1 ELSE 0 END),
                        SUM(CASE WHEN dead_lettered_at IS NOT NULL THEN 1 ELSE 0 END)
                    FROM mutation_projection_outbox;
                """
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    return .empty
                }
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_double(stmt, 1, nowTimestamp)
                sqlite3_bind_double(stmt, 2, nowTimestamp)

                guard sqlite3_step(stmt) == SQLITE_ROW else {
                    return .empty
                }

                counts = (
                    totalRows: Self.columnInt(stmt, 0),
                    pendingRows: Self.columnInt(stmt, 1),
                    leasedRows: Self.columnInt(stmt, 2),
                    projectedRows: Self.columnInt(stmt, 3),
                    deadLetteredRows: Self.columnInt(stmt, 4)
                )
            }

            return MutationProjectionOutboxDiagnostics(
                totalRows: counts.totalRows,
                pendingRows: counts.pendingRows,
                leasedRows: counts.leasedRows,
                projectedRows: counts.projectedRows,
                deadLetteredRows: counts.deadLetteredRows,
                latestDeadLetter: Self.latestDeadLetteredMutationProjectionOutboxRow(db: db)
            )
        } ?? .empty
    }

    /// Bounded view of rows that are unprojected and not actively leased.
    /// RunEventLog/AgentEvent emission remains deferred to later gates.
    nonisolated func pendingMutationProjectionOutboxRows(
        limit: Int = 100,
        now: Date = Date()
    ) -> [MutationProjectionOutboxRow] {
        let boundedLimit = min(max(limit, 0), Self.mutationProjectionOutboxReadLimitMaximum)
        guard boundedLimit > 0 else { return [] }
        let nowTimestamp = now.timeIntervalSince1970
        guard nowTimestamp.isFinite else { return [] }

        return withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = """
                SELECT \(Self.mutationProjectionOutboxSelectColumns)
                FROM mutation_projection_outbox
                WHERE oplog_seq IS NULL
                  AND dead_lettered_at IS NULL
                  AND (lease_until IS NULL OR lease_until <= ?)
                ORDER BY id ASC
                LIMIT ?;
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_double(stmt, 1, nowTimestamp)
            sqlite3_bind_int(stmt, 2, Int32(boundedLimit))

            var rows: [MutationProjectionOutboxRow] = []
            rows.reserveCapacity(boundedLimit)
            while sqlite3_step(stmt) == SQLITE_ROW {
                rows.append(Self.mutationProjectionOutboxRow(from: stmt))
            }
            return rows
        } ?? []
    }

    nonisolated func claimMutationProjectionOutboxRows(
        limit: Int = 100,
        ownerID: String,
        leaseDuration: TimeInterval,
        now: Date = Date()
    ) -> [MutationProjectionOutboxRow] {
        let boundedLimit = min(max(limit, 0), Self.mutationProjectionOutboxReadLimitMaximum)
        let owner = ownerID.trimmingCharacters(in: .whitespacesAndNewlines)
        let nowTimestamp = now.timeIntervalSince1970
        let leaseUntilTimestamp = now.addingTimeInterval(leaseDuration).timeIntervalSince1970
        guard boundedLimit > 0,
              !owner.isEmpty,
              leaseDuration.isFinite,
              leaseDuration > 0,
              nowTimestamp.isFinite,
              leaseUntilTimestamp.isFinite else {
            return []
        }

        return withDatabaseRead { db in
            guard sqlite3_exec(db, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil) == SQLITE_OK else {
                return []
            }

            var didCommit = false
            defer {
                if !didCommit {
                    sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                }
            }

            let mutationIDs = Self.claimableMutationProjectionIDs(
                db: db,
                limit: boundedLimit,
                nowTimestamp: nowTimestamp
            )
            guard !mutationIDs.isEmpty else {
                sqlite3_exec(db, "COMMIT;", nil, nil, nil)
                didCommit = true
                return []
            }

            var claimedIDs: [String] = []
            claimedIDs.reserveCapacity(mutationIDs.count)
            for mutationID in mutationIDs where Self.claimMutationProjectionOutboxRow(
                db: db,
                mutationID: mutationID,
                ownerID: owner,
                nowTimestamp: nowTimestamp,
                leaseUntilTimestamp: leaseUntilTimestamp
            ) {
                claimedIDs.append(mutationID)
            }

            var rows: [MutationProjectionOutboxRow] = []
            rows.reserveCapacity(claimedIDs.count)
            for mutationID in claimedIDs {
                guard let row = Self.mutationProjectionOutboxRow(db: db, mutationID: mutationID),
                      row.leaseOwner == owner else {
                    continue
                }
                rows.append(row)
            }

            guard sqlite3_exec(db, "COMMIT;", nil, nil, nil) == SQLITE_OK else {
                return []
            }
            didCommit = true
            return rows
        } ?? []
    }

    @discardableResult
    nonisolated func recordMutationProjectionOutboxFailure(
        mutationID: String,
        ownerID: String,
        error: String,
        retryAfter: TimeInterval,
        now: Date = Date(),
        maxAttempts: Int? = nil
    ) -> Bool {
        let owner = ownerID.trimmingCharacters(in: .whitespacesAndNewlines)
        let nowTimestamp = now.timeIntervalSince1970
        let retryTimestamp = now.addingTimeInterval(retryAfter).timeIntervalSince1970
        guard !mutationID.isEmpty,
              !owner.isEmpty,
              retryAfter.isFinite,
              retryAfter >= 0,
              nowTimestamp.isFinite,
              retryTimestamp.isFinite else {
            return false
        }
        if let maxAttempts, maxAttempts <= 0 || maxAttempts > Int(Int32.max) {
            return false
        }

        let boundedError = String(error.prefix(Self.mutationProjectionOutboxLastErrorMaximum))
        return withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql: String
            if maxAttempts == nil {
                sql = """
                    UPDATE mutation_projection_outbox
                    SET lease_owner = NULL,
                        lease_until = ?,
                        last_error = ?,
                        dead_lettered_at = NULL,
                        dead_letter_reason = NULL
                    WHERE mutation_id = ?
                      AND oplog_seq IS NULL
                      AND lease_owner = ?;
                """
            } else {
                sql = """
                    UPDATE mutation_projection_outbox
                    SET lease_owner = NULL,
                        lease_until = CASE WHEN attempt_count >= ? THEN NULL ELSE ? END,
                        last_error = ?,
                        dead_lettered_at = CASE WHEN attempt_count >= ? THEN ? ELSE NULL END,
                        dead_letter_reason = CASE WHEN attempt_count >= ? THEN ? ELSE NULL END
                    WHERE mutation_id = ?
                      AND oplog_seq IS NULL
                      AND lease_owner = ?;
                """
            }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
            defer { sqlite3_finalize(stmt) }
            if let maxAttempts {
                sqlite3_bind_int(stmt, 1, Int32(maxAttempts))
                sqlite3_bind_double(stmt, 2, retryTimestamp)
                sqlite3_bind_text(stmt, 3, (boundedError as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 4, Int32(maxAttempts))
                sqlite3_bind_double(stmt, 5, nowTimestamp)
                sqlite3_bind_int(stmt, 6, Int32(maxAttempts))
                sqlite3_bind_text(stmt, 7, ("max_attempts_exceeded" as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 8, (mutationID as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 9, (owner as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_double(stmt, 1, retryTimestamp)
                sqlite3_bind_text(stmt, 2, (boundedError as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (mutationID as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (owner as NSString).utf8String, -1, nil)
            }
            return sqlite3_step(stmt) == SQLITE_DONE && sqlite3_changes(db) > 0
        } ?? false
    }

    @discardableResult
    nonisolated func markMutationProjectionOutboxProjected(
        mutationID: String,
        opLogSeq: UInt64,
        projectedAt: Date = Date(),
        ownerID: String? = nil
    ) -> Bool {
        guard opLogSeq <= UInt64(Int64.max) else { return false }
        let seq = Int64(opLogSeq)
        let projectedTimestamp = projectedAt.timeIntervalSince1970
        guard projectedTimestamp.isFinite else { return false }
        let owner = ownerID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let owner, owner.isEmpty { return false }

        return withDatabaseRead { db in
            var stmt: OpaquePointer?
            let ownerPredicate = owner == nil ? "" : " AND lease_owner = ?"
            let sql = """
                UPDATE mutation_projection_outbox
                SET oplog_seq = ?,
                    projected_at = COALESCE(projected_at, ?),
                    lease_owner = NULL,
                    lease_until = NULL,
                    last_error = NULL,
                    dead_lettered_at = NULL,
                    dead_letter_reason = NULL
                WHERE mutation_id = ?
                  AND (oplog_seq IS NULL OR oplog_seq = ?)\(ownerPredicate);
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, seq)
            sqlite3_bind_double(stmt, 2, projectedTimestamp)
            sqlite3_bind_text(stmt, 3, (mutationID as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 4, seq)
            if let owner {
                sqlite3_bind_text(stmt, 5, (owner as NSString).utf8String, -1, nil)
            }

            guard sqlite3_step(stmt) == SQLITE_DONE else { return false }
            if sqlite3_changes(db) > 0 {
                return true
            }

            var existing: OpaquePointer?
            let selectSQL = "SELECT oplog_seq FROM mutation_projection_outbox WHERE mutation_id = ? LIMIT 1;"
            guard sqlite3_prepare_v2(db, selectSQL, -1, &existing, nil) == SQLITE_OK else { return false }
            defer { sqlite3_finalize(existing) }
            sqlite3_bind_text(existing, 1, (mutationID as NSString).utf8String, -1, nil)
            guard sqlite3_step(existing) == SQLITE_ROW,
                  sqlite3_column_type(existing, 0) != SQLITE_NULL else {
                return false
            }
            let existingSeq = sqlite3_column_int64(existing, 0)
            guard existingSeq >= 0 else { return false }
            return UInt64(existingSeq) == opLogSeq
        } ?? false
    }

    // MARK: - W10.9 / AR3 — Structured SessionTelemetry persistence
    //
    // The Phase 9 @Generable SessionTelemetry classifier produces a
    // structured distillation of every agent session (decisions made,
    // unresolved friction, active themes, emotional trajectory).
    // This pair of methods persists the telemetry as a JSON blob keyed
    // by sessionId so the chat history surface, the daily-brief
    // surface, and the agent's continuation context can all read the
    // typed structure later without re-running AFM.
    //
    // Storage shape: a `session_telemetry` table mirroring the JSON
    // schema. We could split into normalised columns but the schema
    // evolves with the @Generable definition and JSON-blob storage
    // keeps migrations cheap.

    /// Persist a structured SessionTelemetry blob as JSON keyed on
    /// sessionId. Best-effort — failure is logged + swallowed (the
    /// telemetry pass is opportunistic; losing a row doesn't break
    /// the chat history).
    nonisolated func saveSessionTelemetry(
        sessionId: String,
        telemetryJSON: String
    ) {
        queue.async { [weak self] in
            guard let self else { return }
            let db = self.db
            let timestamp = Date().timeIntervalSince1970
            // Lazy-create table on first save so we don't need a
            // migration step in the Time-Machine schema bootstrap.
            sqlite3_exec(
                db,
                """
                CREATE TABLE IF NOT EXISTS session_telemetry (
                    session_id   TEXT PRIMARY KEY,
                    recorded_at  REAL NOT NULL,
                    json         TEXT NOT NULL
                );
                """,
                nil, nil, nil
            )
            let sql = """
                INSERT INTO session_telemetry (session_id, recorded_at, json)
                VALUES (?, ?, ?)
                ON CONFLICT(session_id) DO UPDATE SET
                    recorded_at = excluded.recorded_at,
                    json = excluded.json;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (sessionId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, timestamp)
            sqlite3_bind_text(stmt, 3, (telemetryJSON as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
    }

    /// Read back the structured SessionTelemetry JSON blob for a
    /// given session. Returns nil if no telemetry has been recorded
    /// (in-flight or pre-AR3 sessions).
    nonisolated func loadSessionTelemetryJSON(sessionId: String) -> String? {
        withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = "SELECT json FROM session_telemetry WHERE session_id = ? LIMIT 1;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (sessionId as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            return String(cString: sqlite3_column_text(stmt, 0))
        }
    }

    // MARK: - W10.16 / AR2 — ConversationState persistence

    /// Persist the current ConversationState JSON blob keyed on
    /// conversationId. Replaces the naive linear-log compaction with
    /// the structured projection per master plan Phase 16.
    nonisolated func saveConversationState(
        conversationId: String,
        stateJSON: String
    ) {
        queue.async { [weak self] in
            guard let self else { return }
            let db = self.db
            let timestamp = Date().timeIntervalSince1970
            sqlite3_exec(
                db,
                """
                CREATE TABLE IF NOT EXISTS conversation_state (
                    conversation_id TEXT PRIMARY KEY,
                    recorded_at     REAL NOT NULL,
                    json            TEXT NOT NULL
                );
                """,
                nil, nil, nil
            )
            let sql = """
                INSERT INTO conversation_state (conversation_id, recorded_at, json)
                VALUES (?, ?, ?)
                ON CONFLICT(conversation_id) DO UPDATE SET
                    recorded_at = excluded.recorded_at,
                    json = excluded.json;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (conversationId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, timestamp)
            sqlite3_bind_text(stmt, 3, (stateJSON as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
    }

    /// Read back the most-recent ConversationState JSON blob for a
    /// given conversation. Returns nil if no state has been recorded.
    nonisolated func loadConversationStateJSON(conversationId: String) -> String? {
        withDatabaseRead { db in
            var stmt: OpaquePointer?
            let sql = "SELECT json FROM conversation_state WHERE conversation_id = ? LIMIT 1;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (conversationId as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            return String(cString: sqlite3_column_text(stmt, 0))
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

    nonisolated func sessionMetrics(for sessionId: String) -> SessionMetricsRecord? {
        withDatabaseRead { db in
            let sql = """
                SELECT session_id, recorded_at, classification, displacement, path_length,
                       curvature_ratio, loop_count, error_count, total_calls, efficiency,
                       input_tokens, output_tokens,
                       cache_read_input_tokens, cache_creation_input_tokens
                FROM session_metrics
                WHERE session_id = ?
                LIMIT 1;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (sessionId as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

            return SessionMetricsRecord(
                sessionId: String(cString: sqlite3_column_text(stmt, 0)),
                recordedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                classification: String(cString: sqlite3_column_text(stmt, 2)),
                displacement: sqlite3_column_double(stmt, 3),
                pathLength: sqlite3_column_double(stmt, 4),
                curvatureRatio: sqlite3_column_double(stmt, 5),
                loopCount: Int(sqlite3_column_int(stmt, 6)),
                errorCount: Int(sqlite3_column_int(stmt, 7)),
                totalCalls: Int(sqlite3_column_int(stmt, 8)),
                efficiency: sqlite3_column_double(stmt, 9),
                inputTokens: Int(sqlite3_column_int(stmt, 10)),
                outputTokens: Int(sqlite3_column_int(stmt, 11)),
                cacheReadInputTokens: Int(sqlite3_column_int(stmt, 12)),
                cacheCreationInputTokens: Int(sqlite3_column_int(stmt, 13))
            )
        }
    }

    nonisolated func sessionMetricClassification(sessionId: String) -> String? {
        guard let record = sessionMetrics(for: sessionId), record.totalCalls > 0 else {
            return nil
        }
        return record.classification
    }

    /// N1 Phase 1 closure (MASTER_BUILD_PLAN.md:311) — power source for
    /// the W9.6 cost dashboard's `Cache hit rate` row + per-session
    /// list. Returns the most recent `limit` rows ordered by
    /// `recorded_at DESC`. Token aggregates (input / output / cache
    /// pair) come from AgentResultFFI; provider name + objective +
    /// per-session cost are NOT yet tracked in `session_metrics` and
    /// fall back to placeholders in the dashboard until a follow-up
    /// PR extends the schema (or projects from another store).
    nonisolated func recentSessionMetrics(limit: Int = 30) -> [SessionMetricsRecord] {
        withDatabaseRead { db in
            let sql = """
                SELECT session_id, recorded_at, classification, displacement, path_length,
                       curvature_ratio, loop_count, error_count, total_calls, efficiency,
                       input_tokens, output_tokens,
                       cache_read_input_tokens, cache_creation_input_tokens
                FROM session_metrics
                ORDER BY recorded_at DESC
                LIMIT ?;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int(stmt, 1, Int32(max(1, limit)))

            var results: [SessionMetricsRecord] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(SessionMetricsRecord(
                    sessionId: String(cString: sqlite3_column_text(stmt, 0)),
                    recordedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                    classification: String(cString: sqlite3_column_text(stmt, 2)),
                    displacement: sqlite3_column_double(stmt, 3),
                    pathLength: sqlite3_column_double(stmt, 4),
                    curvatureRatio: sqlite3_column_double(stmt, 5),
                    loopCount: Int(sqlite3_column_int(stmt, 6)),
                    errorCount: Int(sqlite3_column_int(stmt, 7)),
                    totalCalls: Int(sqlite3_column_int(stmt, 8)),
                    efficiency: sqlite3_column_double(stmt, 9),
                    inputTokens: Int(sqlite3_column_int(stmt, 10)),
                    outputTokens: Int(sqlite3_column_int(stmt, 11)),
                    cacheReadInputTokens: Int(sqlite3_column_int(stmt, 12)),
                    cacheCreationInputTokens: Int(sqlite3_column_int(stmt, 13))
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
            return sqlite3_last_insert_rowid(db)
        }
    }

    nonisolated func updateNightBrainRun(id: Int64, status: String, completedJobs: [String], completedAt: Double? = nil) {
        withDatabaseRead { db in
            let jobsJSON = Self.encodeCompletedJobs(completedJobs)
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
                let runId = sqlite3_column_int64(stmt, 0)
                let jobs = Self.decodeCompletedJobs(jobsJSON, runId: runId)
                let triggerPtr = sqlite3_column_text(stmt, 5)
                results.append(NightBrainRunRecord(
                    id: runId,
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
        do {
            let data = try payloadEncoder.encode(dict)
            guard let payload = String(data: data, encoding: .utf8) else {
                Self.log.error("EventStore: failed to encode event payload as UTF-8 text")
                return "{}"
            }
            return payload
        } catch {
            Self.log.error("EventStore: failed to encode event payload: \(error.localizedDescription, privacy: .public)")
            return "{}"
        }
    }

    nonisolated private static func encodeNoteEditedPayload(pageId: String, title: String, changed: Int, total: Int) -> String {
        do {
            let payloadObject: [String: Any] = [
                "changedParagraphs": changed,
                "pageId": pageId,
                "title": title,
                "totalParagraphs": total,
            ]
            let data = try JSONSerialization.data(withJSONObject: payloadObject, options: [.sortedKeys])
            guard let payload = String(data: data, encoding: .utf8) else {
                Self.log.error("EventStore: failed to encode note_edited payload as UTF-8 text")
                return "{}"
            }
            return payload
        } catch {
            Self.log.error("EventStore: failed to encode note_edited payload: \(error.localizedDescription, privacy: .public)")
            return "{}"
        }
    }

    nonisolated private static func bindNullableText(_ value: String?, to stmt: OpaquePointer?, index: Int32) {
        if let value {
            sqlite3_bind_text(stmt, index, (value as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    nonisolated private static func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL,
              let text = sqlite3_column_text(stmt, index) else {
            return nil
        }
        return String(cString: text)
    }

    nonisolated private static func columnUInt64(_ stmt: OpaquePointer?, _ index: Int32) -> UInt64? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        let value = sqlite3_column_int64(stmt, index)
        guard value >= 0 else { return nil }
        return UInt64(value)
    }

    nonisolated private static func columnInt(_ stmt: OpaquePointer?, _ index: Int32) -> Int {
        let value = sqlite3_column_int64(stmt, index)
        guard value > 0 else { return 0 }
        return value > Int64(Int.max) ? Int.max : Int(value)
    }

    nonisolated private static func columnDate(_ stmt: OpaquePointer?, _ index: Int32) -> Date? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        let timestamp = sqlite3_column_double(stmt, index)
        guard timestamp.isFinite else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    nonisolated private static func decodeAgentEventJSON(
        _ json: String,
        context: String
    ) -> AgentProvenanceEvent? {
        do {
            return try JSONDecoder().decode(AgentProvenanceEvent.self, from: Data(json.utf8))
        } catch {
            Self.log.error(
                "EventStore: failed to decode AgentProvenanceEvent \(context, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    nonisolated private static func decodeGraphEventJSON(
        _ json: String,
        context: String
    ) -> DurableGraphEvent? {
        do {
            return try JSONDecoder().decode(DurableGraphEvent.self, from: Data(json.utf8))
        } catch {
            Self.log.error(
                "EventStore: failed to decode DurableGraphEvent \(context, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    nonisolated private static func claimableMutationProjectionIDs(
        db: OpaquePointer,
        limit: Int,
        nowTimestamp: TimeInterval
    ) -> [String] {
        var stmt: OpaquePointer?
        let sql = """
            SELECT mutation_id
            FROM mutation_projection_outbox
            WHERE oplog_seq IS NULL
              AND dead_lettered_at IS NULL
              AND (lease_until IS NULL OR lease_until <= ?)
            ORDER BY id ASC
            LIMIT ?;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, nowTimestamp)
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var ids: [String] = []
        ids.reserveCapacity(limit)
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let mutationID = columnText(stmt, 0), !mutationID.isEmpty {
                ids.append(mutationID)
            }
        }
        return ids
    }

    nonisolated private static func claimMutationProjectionOutboxRow(
        db: OpaquePointer,
        mutationID: String,
        ownerID: String,
        nowTimestamp: TimeInterval,
        leaseUntilTimestamp: TimeInterval
    ) -> Bool {
        var stmt: OpaquePointer?
        let sql = """
            UPDATE mutation_projection_outbox
            SET lease_owner = ?,
                lease_until = ?,
                attempt_count = attempt_count + 1,
                last_error = NULL
            WHERE mutation_id = ?
              AND oplog_seq IS NULL
              AND dead_lettered_at IS NULL
              AND (lease_until IS NULL OR lease_until <= ?);
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (ownerID as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 2, leaseUntilTimestamp)
        sqlite3_bind_text(stmt, 3, (mutationID as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 4, nowTimestamp)
        return sqlite3_step(stmt) == SQLITE_DONE && sqlite3_changes(db) > 0
    }

    nonisolated private static func mutationProjectionOutboxRow(
        db: OpaquePointer,
        mutationID: String
    ) -> MutationProjectionOutboxRow? {
        var stmt: OpaquePointer?
        let sql = """
            SELECT \(mutationProjectionOutboxSelectColumns)
            FROM mutation_projection_outbox
            WHERE mutation_id = ?
            LIMIT 1;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (mutationID as NSString).utf8String, -1, nil)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return mutationProjectionOutboxRow(from: stmt)
    }

    nonisolated private static func latestDeadLetteredMutationProjectionOutboxRow(
        db: OpaquePointer
    ) -> MutationProjectionOutboxRow? {
        var stmt: OpaquePointer?
        let sql = """
            SELECT \(mutationProjectionOutboxSelectColumns)
            FROM mutation_projection_outbox
            WHERE dead_lettered_at IS NOT NULL
            ORDER BY dead_lettered_at DESC, id DESC
            LIMIT 1;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return mutationProjectionOutboxRow(from: stmt)
    }

    nonisolated private static func latestGraphEvent(
        db: OpaquePointer
    ) -> DurableGraphEvent? {
        var stmt: OpaquePointer?
        let sql = """
            SELECT json
            FROM graph_events
            ORDER BY occurred_at DESC, id DESC
            LIMIT 1;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let json = columnText(stmt, 0) else {
            return nil
        }
        return decodeGraphEventJSON(json, context: "latest")
    }

    nonisolated private static func mutationProjectionOutboxRow(
        from stmt: OpaquePointer?
    ) -> MutationProjectionOutboxRow {
        MutationProjectionOutboxRow(
            mutationID: columnText(stmt, 0) ?? "",
            recordedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
            traceID: columnText(stmt, 2),
            eventKind: columnText(stmt, 3) ?? "",
            status: columnText(stmt, 4) ?? "",
            artifactID: columnText(stmt, 5),
            artifactKind: columnText(stmt, 6),
            integrityHash: columnText(stmt, 7) ?? "",
            payload: columnText(stmt, 8) ?? "{}",
            opLogSeq: columnUInt64(stmt, 9),
            projectedAt: columnDate(stmt, 10),
            leaseOwner: columnText(stmt, 11),
            leaseUntil: columnDate(stmt, 12),
            attemptCount: Int(sqlite3_column_int(stmt, 13)),
            lastError: columnText(stmt, 14),
            deadLetteredAt: columnDate(stmt, 15),
            deadLetterReason: columnText(stmt, 16)
        )
    }

    nonisolated private static func mutationArtifactProjection(_ op: SourceOp) -> (id: String?, kind: String?) {
        switch op {
        case .artifactCreate(let id, let kind):
            return (id, kind)
        case .artifactUpdate(let id), .artifactDelete(let id):
            return (id, nil)
        case .graphMutation, .other:
            return (nil, nil)
        }
    }

    nonisolated private static func insertGraphEvent(
        _ event: DurableGraphEvent,
        db: OpaquePointer
    ) -> Bool {
        let eventID = event.eventID.trimmingCharacters(in: .whitespacesAndNewlines)
        let mutationID = event.mutationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !eventID.isEmpty,
              !mutationID.isEmpty,
              event.sequence <= UInt64(Int64.max) else {
            return false
        }
        let occurredAt = Double(event.occurredAtMs) / 1_000
        guard occurredAt.isFinite else { return false }

        let json: String
        do {
            let data = try payloadEncoder.encode(event)
            guard let encoded = String(data: data, encoding: .utf8) else {
                Self.log.error("EventStore: failed to encode DurableGraphEvent as UTF-8 text")
                return false
            }
            json = encoded
        } catch {
            Self.log.error(
                "EventStore: failed to encode DurableGraphEvent \(event.eventID, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }

        var stmt: OpaquePointer?
        let sql = """
            INSERT INTO graph_events (
                event_id, mutation_id, run_id, trace_id, sequence,
                kind, entity_id, entity_kind, occurred_at, json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(event_id) DO UPDATE SET
                mutation_id = excluded.mutation_id,
                run_id = excluded.run_id,
                trace_id = excluded.trace_id,
                sequence = excluded.sequence,
                kind = excluded.kind,
                entity_id = excluded.entity_id,
                entity_kind = excluded.entity_kind,
                occurred_at = excluded.occurred_at,
                json = excluded.json;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Self.log.error(
                "EventStore: failed to prepare DurableGraphEvent save: \(String(cString: sqlite3_errmsg(db)), privacy: .public)"
            )
            return false
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (eventID as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (mutationID as NSString).utf8String, -1, nil)
        bindNullableText(event.runID, to: stmt, index: 3)
        bindNullableText(event.traceID, to: stmt, index: 4)
        sqlite3_bind_int64(stmt, 5, Int64(event.sequence))
        sqlite3_bind_text(stmt, 6, (event.kind.rawValue as NSString).utf8String, -1, nil)
        bindNullableText(event.entityID, to: stmt, index: 7)
        bindNullableText(event.entityKind, to: stmt, index: 8)
        sqlite3_bind_double(stmt, 9, occurredAt)
        sqlite3_bind_text(stmt, 10, (json as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            Self.log.error(
                "EventStore: failed to save DurableGraphEvent \(event.eventID, privacy: .public): \(String(cString: sqlite3_errmsg(db)), privacy: .public)"
            )
            return false
        }
        return true
    }

    nonisolated private static func insertGraphEvents(
        for envelope: MutationEnvelope,
        traceId: String?,
        db: OpaquePointer
    ) -> Bool {
        guard let events = durableGraphEvents(for: envelope, traceId: traceId) else {
            return false
        }
        for event in events where !insertGraphEvent(event, db: db) {
            return false
        }
        return true
    }

    nonisolated private static func durableGraphEvents(
        for envelope: MutationEnvelope,
        traceId: String?
    ) -> [DurableGraphEvent]? {
        guard envelope.status == .committed else { return [] }
        let graphMutation = isGraphMutation(envelope.op)
        guard envelope.affectsGraph || !envelope.relationChanges.isEmpty || graphMutation else {
            return []
        }

        var events: [DurableGraphEvent] = []
        events.reserveCapacity((envelope.affectsGraph || graphMutation ? 1 : 0) + envelope.relationChanges.count)

        var index = 0
        if envelope.affectsGraph || graphMutation {
            guard let event = durableGraphEvent(for: envelope, traceId: traceId, index: index) else {
                return nil
            }
            events.append(event)
            index += 1
        }

        for relationChange in envelope.relationChanges {
            guard let event = durableGraphEvent(
                for: relationChange,
                envelope: envelope,
                traceId: traceId,
                index: index
            ) else {
                return nil
            }
            events.append(event)
            index += 1
        }

        return events
    }

    nonisolated private static func durableGraphEvent(
        for envelope: MutationEnvelope,
        traceId: String?,
        index: Int
    ) -> DurableGraphEvent? {
        guard let sequence = graphEventSequence(base: envelope.sequence, offset: index) else {
            return nil
        }
        let kind: DurableGraphEventKind
        let entityID: String?
        let entityKind: String?

        switch envelope.op {
        case .artifactCreate(let id, let artifactKind):
            kind = .nodeCreated
            entityID = id
            entityKind = artifactKind
        case .artifactUpdate(let id):
            kind = .nodeUpdated
            entityID = id
            entityKind = artifactKind(for: id, in: envelope)
        case .artifactDelete(let id):
            kind = .nodeDeleted
            entityID = id
            entityKind = artifactKind(for: id, in: envelope)
        case .graphMutation, .other:
            kind = .graphMutation
            entityID = nil
            entityKind = "graph"
        }

        return DurableGraphEvent(
            eventID: graphEventID(mutationID: envelope.mutationID, index: index),
            mutationID: envelope.mutationID,
            runID: envelope.runID,
            traceID: traceId,
            sequence: sequence,
            kind: kind,
            entityID: entityID,
            entityKind: entityKind,
            occurredAtMs: envelope.committedAtMs ?? envelope.createdAtMs,
            metadata: graphEventMetadata(envelope: envelope)
        )
    }

    nonisolated private static func durableGraphEvent(
        for relationChange: RelationChange,
        envelope: MutationEnvelope,
        traceId: String?,
        index: Int
    ) -> DurableGraphEvent? {
        guard let sequence = graphEventSequence(base: envelope.sequence, offset: index) else {
            return nil
        }
        let kind: DurableGraphEventKind
        let relation: DurableGraphEventRelation
        let relationOp: String

        switch relationChange {
        case .added(let fromID, let toID, let label):
            kind = .edgeCreated
            relationOp = "added"
            relation = DurableGraphEventRelation(fromID: fromID, toID: toID, label: label)
        case .removed(let fromID, let toID, let label):
            kind = .edgeDeleted
            relationOp = "removed"
            relation = DurableGraphEventRelation(fromID: fromID, toID: toID, label: label)
        case .updated(let fromID, let toID, let oldLabel, let newLabel):
            kind = .edgeUpdated
            relationOp = "updated"
            relation = DurableGraphEventRelation(
                fromID: fromID,
                toID: toID,
                label: newLabel,
                oldLabel: oldLabel,
                newLabel: newLabel
            )
        }

        var metadata = graphEventMetadata(envelope: envelope)
        metadata["relation_op"] = relationOp
        return DurableGraphEvent(
            eventID: graphEventID(mutationID: envelope.mutationID, index: index),
            mutationID: envelope.mutationID,
            runID: envelope.runID,
            traceID: traceId,
            sequence: sequence,
            kind: kind,
            entityID: graphEdgeEntityID(relation),
            entityKind: "edge",
            occurredAtMs: envelope.committedAtMs ?? envelope.createdAtMs,
            relation: relation,
            metadata: metadata
        )
    }

    nonisolated private static func graphEventSequence(base: UInt64, offset: Int) -> UInt64? {
        guard offset >= 0 else { return nil }
        let offset = UInt64(offset)
        guard UInt64.max - base >= offset else { return nil }
        return base + offset
    }

    nonisolated private static func graphEventID(mutationID: String, index: Int) -> String {
        "graph-event:\(mutationID):\(index)"
    }

    nonisolated private static func graphEdgeEntityID(_ relation: DurableGraphEventRelation) -> String {
        "\(relation.fromID)->\(relation.toID):\(relation.label)"
    }

    nonisolated private static func graphEventMetadata(envelope: MutationEnvelope) -> [String: String] {
        [
            "affects_graph": envelope.affectsGraph ? "true" : "false",
            "integrity_hash": envelope.integrityHash,
            "source": "mutation_envelope",
            "source_op": sourceOpLabel(envelope.op),
        ]
    }

    nonisolated private static func artifactKind(for artifactID: String, in envelope: MutationEnvelope) -> String? {
        if case .artifactCreate(let id, let kind) = envelope.op, id == artifactID {
            return kind
        }
        return envelope.touchedArtifacts.first { $0.id == artifactID }?.kind?.snakeCaseString
    }

    nonisolated private static func isGraphMutation(_ op: SourceOp) -> Bool {
        if case .graphMutation = op {
            return true
        }
        return false
    }

    nonisolated private static func sourceOpLabel(_ op: SourceOp) -> String {
        switch op {
        case .graphMutation:
            return "graph_mutation"
        case .artifactCreate:
            return "artifact_create"
        case .artifactUpdate:
            return "artifact_update"
        case .artifactDelete:
            return "artifact_delete"
        case .other(let label):
            return "other:\(label)"
        }
    }

    nonisolated private static func insertMutationProjectionOutbox(
        _ envelope: MutationEnvelope,
        traceId: String?,
        artifact: (id: String?, kind: String?),
        db: OpaquePointer
    ) -> Bool {
        var payloadFields = [
            "event_kind": mutationEnvelopeCommittedEventKind,
            "integrity_hash": envelope.integrityHash,
            "mutation_id": envelope.mutationID,
            "status": envelope.status.rawValue,
        ]
        if let traceId {
            payloadFields["trace_id"] = traceId
        }
        if let artifactID = artifact.id {
            payloadFields["artifact_id"] = artifactID
        }
        if let artifactKind = artifact.kind {
            payloadFields["artifact_kind"] = artifactKind
        }

        let payload = encodePayload(payloadFields)
        var stmt: OpaquePointer?
        let sql = """
            INSERT INTO mutation_projection_outbox (
                mutation_id, recorded_at, trace_id, event_kind, status,
                artifact_id, artifact_kind, integrity_hash, payload
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(mutation_id) DO NOTHING;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Self.log.error(
                "EventStore: failed to prepare mutation projection outbox insert: \(String(cString: sqlite3_errmsg(db)), privacy: .public)"
            )
            return false
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (envelope.mutationID as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
        bindNullableText(traceId, to: stmt, index: 3)
        sqlite3_bind_text(stmt, 4, (mutationEnvelopeCommittedEventKind as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 5, (envelope.status.rawValue as NSString).utf8String, -1, nil)
        bindNullableText(artifact.id, to: stmt, index: 6)
        bindNullableText(artifact.kind, to: stmt, index: 7)
        sqlite3_bind_text(stmt, 8, (envelope.integrityHash as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 9, (payload as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            Self.log.error(
                "EventStore: failed to enqueue mutation projection \(envelope.mutationID, privacy: .public): \(String(cString: sqlite3_errmsg(db)), privacy: .public)"
            )
            return false
        }
        return true
    }

    private static var databaseURL: URL {
        let appSupport = FoundationSafety.userApplicationSupportDirectory()
        let dir = appSupport.appendingPathComponent("Epistemos")
        return dir.appendingPathComponent("event-store.sqlite")
    }

    nonisolated private static func encodeCompletedJobs(_ completedJobs: [String]) -> String {
        do {
            let data = try payloadEncoder.encode(completedJobs)
            guard let payload = String(data: data, encoding: .utf8) else {
                Self.log.error("EventStore: failed to encode Night Brain jobs_completed payload as UTF-8 text")
                return "[]"
            }
            return payload
        } catch {
            Self.log.error(
                "EventStore: failed to encode Night Brain jobs_completed payload: \(error.localizedDescription, privacy: .public)"
            )
            return "[]"
        }
    }

    nonisolated private static func decodeCompletedJobs(_ jobsJSON: String, runId: Int64) -> [String] {
        do {
            return try JSONDecoder().decode([String].self, from: Data(jobsJSON.utf8))
        } catch {
            Self.log.error(
                "EventStore: failed to decode Night Brain jobs_completed payload for run \(runId, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
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
            guard FileManager.default.createFile(atPath: markerURL.path, contents: Data()) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
    }
}
