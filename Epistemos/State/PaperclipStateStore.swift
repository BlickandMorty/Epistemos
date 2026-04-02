import Foundation
import os
import SQLite3

// MARK: - Paperclip State Store
//
// High-frequency agent tick storage using raw SQLite with WAL mode.
// The hybrid architecture from the Omniscient Manifesto:
//   - SwiftData for read-heavy, human-facing workloads (HologramOverlay, NightBrain)
//   - Raw SQLite WAL for write-heavy, machine-facing workloads (token ticks, heartbeats)
//
// WAL mode delivers 70K-100K writes/sec vs SwiftData's ORM overhead.
// The Swift actor serializes concurrent writes naturally — no explicit mutex needed.

// MARK: - Agent Tick Record

struct AgentTick: Sendable {
    let sessionId: String
    let agentId: String
    let timestamp: Date
    let inputTokens: Int
    let outputTokens: Int
    let toolName: String?
    let costMicroDollars: Int
    let turnNumber: Int
}

struct CronHeartbeat: Sendable {
    let agentId: String
    let scheduledAt: Date
    let executedAt: Date
    let durationMs: Int
    let success: Bool
    let errorMessage: String?
}

// MARK: - PaperclipStateStore Actor

actor PaperclipStateStore {
    private static let logger = Logger(
        subsystem: "com.epistemos.state",
        category: "PaperclipStore"
    )
    nonisolated(unsafe) private static let sqliteTransientDestructor =
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private var db: OpaquePointer?
    private let path: String

    init(path: String? = nil) throws {
        let storePath = path ?? Self.defaultPath()
        self.path = storePath

        // Ensure parent directory exists
        let dir = (storePath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        )

        var dbPtr: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        let rc = sqlite3_open_v2(storePath, &dbPtr, flags, nil)
        guard rc == SQLITE_OK, let dbPtr else {
            throw PaperclipError.openFailed(
                sqlite3_errmsg(dbPtr).map { String(cString: $0) } ?? "unknown error"
            )
        }
        self.db = dbPtr

        // Inline pragma + table setup (nonisolated init cannot call actor-isolated methods)
        var errorMsg: UnsafeMutablePointer<CChar>?
        sqlite3_exec(dbPtr, "PRAGMA journal_mode = WAL;", nil, nil, &errorMsg)
        sqlite3_exec(dbPtr, "PRAGMA synchronous = NORMAL;", nil, nil, &errorMsg)
        sqlite3_busy_timeout(dbPtr, 5000)
        sqlite3_exec(dbPtr, "PRAGMA mmap_size = 268435456;", nil, nil, &errorMsg)

        let createSQL = """
            CREATE TABLE IF NOT EXISTS agent_ticks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                agent_id TEXT NOT NULL,
                timestamp REAL NOT NULL,
                input_tokens INTEGER NOT NULL DEFAULT 0,
                output_tokens INTEGER NOT NULL DEFAULT 0,
                tool_name TEXT,
                cost_micro_dollars INTEGER NOT NULL DEFAULT 0,
                turn_number INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS cron_heartbeats (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                agent_id TEXT NOT NULL,
                scheduled_at REAL NOT NULL,
                executed_at REAL NOT NULL,
                duration_ms INTEGER NOT NULL,
                success INTEGER NOT NULL DEFAULT 1,
                error_message TEXT
            );
            CREATE TABLE IF NOT EXISTS agent_budgets (
                agent_id TEXT PRIMARY KEY,
                daily_budget_micro INTEGER NOT NULL DEFAULT 20000000,
                session_budget_micro INTEGER NOT NULL DEFAULT 5000000,
                spent_today_micro INTEGER NOT NULL DEFAULT 0,
                last_reset_date TEXT NOT NULL DEFAULT ''
            );
            CREATE INDEX IF NOT EXISTS idx_ticks_session ON agent_ticks(session_id);
            CREATE INDEX IF NOT EXISTS idx_ticks_agent ON agent_ticks(agent_id);
            CREATE INDEX IF NOT EXISTS idx_ticks_timestamp ON agent_ticks(timestamp);
            CREATE INDEX IF NOT EXISTS idx_heartbeats_agent ON cron_heartbeats(agent_id);
        """
        sqlite3_exec(dbPtr, createSQL, nil, nil, &errorMsg)

        Self.logger.info("PaperclipStateStore opened at \(storePath)")
    }

    /// Explicitly close the database. Call before releasing the actor.
    func close() {
        if let db {
            sqlite3_close_v2(db)
            self.db = nil
        }
    }

    // MARK: - Write Operations

    /// Record a batch of agent ticks in a single transaction for throughput.
    func recordTicks(_ ticks: [AgentTick]) throws {
        guard !ticks.isEmpty else { return }

        let sql = """
            INSERT INTO agent_ticks (
                session_id,
                agent_id,
                timestamp,
                input_tokens,
                output_tokens,
                tool_name,
                cost_micro_dollars,
                turn_number
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        let statement = try prepareStatement(sql)
        defer { sqlite3_finalize(statement) }

        try withTransaction {
            for tick in ticks {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)

                try bindText(tick.sessionId, at: 1, in: statement)
                try bindText(tick.agentId, at: 2, in: statement)
                try bindDouble(tick.timestamp.timeIntervalSince1970, at: 3, in: statement)
                try bindInt64(Int64(tick.inputTokens), at: 4, in: statement)
                try bindInt64(Int64(tick.outputTokens), at: 5, in: statement)
                try bindOptionalText(tick.toolName, at: 6, in: statement)
                try bindInt64(Int64(tick.costMicroDollars), at: 7, in: statement)
                try bindInt64(Int64(tick.turnNumber), at: 8, in: statement)
                try stepDone(statement)
            }
        }
    }

    /// Record a single agent tick.
    func recordTick(_ tick: AgentTick) throws {
        try recordTicks([tick])
    }

    /// Record a cron heartbeat execution.
    func recordHeartbeat(_ heartbeat: CronHeartbeat) throws {
        let sql = """
            INSERT INTO cron_heartbeats (
                agent_id,
                scheduled_at,
                executed_at,
                duration_ms,
                success,
                error_message
            ) VALUES (?, ?, ?, ?, ?, ?);
        """
        let statement = try prepareStatement(sql)
        defer { sqlite3_finalize(statement) }

        try bindText(heartbeat.agentId, at: 1, in: statement)
        try bindDouble(heartbeat.scheduledAt.timeIntervalSince1970, at: 2, in: statement)
        try bindDouble(heartbeat.executedAt.timeIntervalSince1970, at: 3, in: statement)
        try bindInt64(Int64(heartbeat.durationMs), at: 4, in: statement)
        try bindInt64(heartbeat.success ? 1 : 0, at: 5, in: statement)
        try bindOptionalText(heartbeat.errorMessage, at: 6, in: statement)
        try stepDone(statement)
    }

    // MARK: - Read Operations

    /// Total tokens consumed in the current session.
    func sessionTokenCount(sessionId: String) throws -> (input: Int, output: Int) {
        let sql = """
            SELECT COALESCE(SUM(input_tokens), 0), COALESCE(SUM(output_tokens), 0)
            FROM agent_ticks
            WHERE session_id = ?;
        """
        let statement = try prepareStatement(sql)
        defer { sqlite3_finalize(statement) }

        try bindText(sessionId, at: 1, in: statement)

        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_ROW else {
            throw PaperclipError.queryFailed(lastErrorMessage())
        }
        return (
            Int(sqlite3_column_int64(statement, 0)),
            Int(sqlite3_column_int64(statement, 1))
        )
    }

    /// Total cost in micro-dollars for a given agent today.
    func dailyCost(agentId: String) throws -> Int {
        let todayStart = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        let sql = """
            SELECT COALESCE(SUM(cost_micro_dollars), 0)
            FROM agent_ticks
            WHERE agent_id = ? AND timestamp >= ?;
        """
        let statement = try prepareStatement(sql)
        defer { sqlite3_finalize(statement) }

        try bindText(agentId, at: 1, in: statement)
        try bindDouble(todayStart, at: 2, in: statement)

        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_ROW else {
            throw PaperclipError.queryFailed(lastErrorMessage())
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    /// Recent heartbeats for an agent.
    func recentHeartbeats(agentId: String, limit: Int = 10) throws -> [CronHeartbeat] {
        let sql = """
            SELECT agent_id, scheduled_at, executed_at, duration_ms, success, error_message
            FROM cron_heartbeats
            WHERE agent_id = ?
            ORDER BY executed_at DESC
            LIMIT ?;
        """
        let statement = try prepareStatement(sql)
        defer { sqlite3_finalize(statement) }

        try bindText(agentId, at: 1, in: statement)
        try bindInt64(Int64(limit), at: 2, in: statement)

        var results: [CronHeartbeat] = []
        while true {
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_DONE {
                break
            }
            guard stepResult == SQLITE_ROW else {
                throw PaperclipError.queryFailed(lastErrorMessage())
            }

            let heartbeat = CronHeartbeat(
                agentId: String(cString: sqlite3_column_text(statement, 0)),
                scheduledAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)),
                executedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                durationMs: Int(sqlite3_column_int(statement, 3)),
                success: sqlite3_column_int(statement, 4) != 0,
                errorMessage: sqlite3_column_text(statement, 5).map { String(cString: $0) }
            )
            results.append(heartbeat)
        }
        return results
    }

    // MARK: - Maintenance

    /// Prune old ticks beyond a retention window (default 30 days).
    func pruneOldData(retentionDays: Int = 30) throws {
        let cutoff = Date().addingTimeInterval(TimeInterval(-retentionDays * 86400)).timeIntervalSince1970
        try exec("DELETE FROM agent_ticks WHERE timestamp < \(cutoff);")
        try exec("DELETE FROM cron_heartbeats WHERE executed_at < \(cutoff);")
        Self.logger.info("Pruned data older than \(retentionDays) days")
    }

    // MARK: - Helpers

    @discardableResult
    private func exec(_ sql: String) throws -> Int32 {
        guard let db else {
            throw PaperclipError.notOpen
        }
        var errorMessage: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        if rc != SQLITE_OK {
            let msg = errorMessage.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(errorMessage)
            throw PaperclipError.execFailed(msg)
        }
        return rc
    }

    private func withTransaction(_ body: () throws -> Void) throws {
        var transactionOpen = false
        do {
            try exec("BEGIN TRANSACTION;")
            transactionOpen = true
            try body()
            try exec("COMMIT;")
            transactionOpen = false
        } catch {
            if transactionOpen {
                do {
                    try exec("ROLLBACK;")
                } catch {
                    Self.logger.error("Paperclip transaction rollback failed: \(error.localizedDescription)")
                }
            }
            throw error
        }
    }

    private func prepareStatement(_ sql: String) throws -> OpaquePointer? {
        guard let db else {
            throw PaperclipError.notOpen
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw PaperclipError.queryFailed(lastErrorMessage())
        }
        return statement
    }

    private func bindText(_ value: String, at index: Int32, in statement: OpaquePointer?) throws {
        let string = value as NSString
        guard sqlite3_bind_text(statement, index, string.utf8String, -1, Self.sqliteTransientDestructor) == SQLITE_OK else {
            throw PaperclipError.queryFailed(lastErrorMessage())
        }
    }

    private func bindOptionalText(_ value: String?, at index: Int32, in statement: OpaquePointer?) throws {
        if let value {
            try bindText(value, at: index, in: statement)
            return
        }

        guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
            throw PaperclipError.queryFailed(lastErrorMessage())
        }
    }

    private func bindDouble(_ value: Double, at index: Int32, in statement: OpaquePointer?) throws {
        guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
            throw PaperclipError.queryFailed(lastErrorMessage())
        }
    }

    private func bindInt64(_ value: Int64, at index: Int32, in statement: OpaquePointer?) throws {
        guard sqlite3_bind_int64(statement, index, value) == SQLITE_OK else {
            throw PaperclipError.queryFailed(lastErrorMessage())
        }
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw PaperclipError.execFailed(lastErrorMessage())
        }
    }

    private func lastErrorMessage() -> String {
        guard let db, let message = sqlite3_errmsg(db) else {
            return "unknown error"
        }
        return String(cString: message)
    }

    private static func defaultPath() -> String {
        let support = FoundationSafety.userApplicationSupportDirectory()
            .appendingPathComponent("Epistemos")
        return support.appendingPathComponent("paperclip_state.db").path
    }
}

// MARK: - Errors

enum PaperclipError: Error, LocalizedError {
    case openFailed(String)
    case notOpen
    case execFailed(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let msg): return "Paperclip DB open failed: \(msg)"
        case .notOpen: return "Paperclip DB not open"
        case .execFailed(let msg): return "Paperclip SQL exec failed: \(msg)"
        case .queryFailed(let msg): return "Paperclip query failed: \(msg)"
        }
    }
}
