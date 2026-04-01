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

nonisolated(unsafe) private let paperclipLog = Logger(subsystem: "com.epistemos.state", category: "PaperclipStore")

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

        paperclipLog.info("PaperclipStateStore opened at \(storePath)")
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

        try exec("BEGIN TRANSACTION;")
        defer {
            // Commit even if individual inserts fail — partial data is better than none
            _ = try? exec("COMMIT;")
        }

        for tick in ticks {
            try exec("""
                INSERT INTO agent_ticks (session_id, agent_id, timestamp, input_tokens, output_tokens, tool_name, cost_micro_dollars, turn_number)
                VALUES ('\(tick.sessionId)', '\(tick.agentId)', \(tick.timestamp.timeIntervalSince1970), \(tick.inputTokens), \(tick.outputTokens), \(tick.toolName.map { "'\($0)'" } ?? "NULL"), \(tick.costMicroDollars), \(tick.turnNumber));
            """)
        }
    }

    /// Record a single agent tick.
    func recordTick(_ tick: AgentTick) throws {
        try recordTicks([tick])
    }

    /// Record a cron heartbeat execution.
    func recordHeartbeat(_ heartbeat: CronHeartbeat) throws {
        let errorValue = heartbeat.errorMessage.map { "'\($0)'" } ?? "NULL"
        try exec("""
            INSERT INTO cron_heartbeats (agent_id, scheduled_at, executed_at, duration_ms, success, error_message)
            VALUES ('\(heartbeat.agentId)', \(heartbeat.scheduledAt.timeIntervalSince1970), \(heartbeat.executedAt.timeIntervalSince1970), \(heartbeat.durationMs), \(heartbeat.success ? 1 : 0), \(errorValue));
        """)
    }

    // MARK: - Read Operations

    /// Total tokens consumed in the current session.
    func sessionTokenCount(sessionId: String) throws -> (input: Int, output: Int) {
        var stmt: OpaquePointer?
        let sql = "SELECT COALESCE(SUM(input_tokens), 0), COALESCE(SUM(output_tokens), 0) FROM agent_ticks WHERE session_id = '\(sessionId)';"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PaperclipError.queryFailed("prepare failed")
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return (0, 0)
        }
        return (
            Int(sqlite3_column_int64(stmt, 0)),
            Int(sqlite3_column_int64(stmt, 1))
        )
    }

    /// Total cost in micro-dollars for a given agent today.
    func dailyCost(agentId: String) throws -> Int {
        let todayStart = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        var stmt: OpaquePointer?
        let sql = "SELECT COALESCE(SUM(cost_micro_dollars), 0) FROM agent_ticks WHERE agent_id = '\(agentId)' AND timestamp >= \(todayStart);"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PaperclipError.queryFailed("prepare failed")
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return 0
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// Recent heartbeats for an agent.
    func recentHeartbeats(agentId: String, limit: Int = 10) throws -> [CronHeartbeat] {
        var stmt: OpaquePointer?
        let sql = "SELECT agent_id, scheduled_at, executed_at, duration_ms, success, error_message FROM cron_heartbeats WHERE agent_id = '\(agentId)' ORDER BY executed_at DESC LIMIT \(limit);"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PaperclipError.queryFailed("prepare failed")
        }
        defer { sqlite3_finalize(stmt) }

        var results: [CronHeartbeat] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let heartbeat = CronHeartbeat(
                agentId: String(cString: sqlite3_column_text(stmt, 0)),
                scheduledAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                executedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
                durationMs: Int(sqlite3_column_int(stmt, 3)),
                success: sqlite3_column_int(stmt, 4) != 0,
                errorMessage: sqlite3_column_text(stmt, 5).map { String(cString: $0) }
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
        paperclipLog.info("Pruned data older than \(retentionDays) days")
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

    private static func defaultPath() -> String {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("Epistemos")
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
