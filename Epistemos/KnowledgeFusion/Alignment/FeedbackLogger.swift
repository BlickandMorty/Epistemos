import Foundation
import SQLite3

// MARK: - Types

enum FeedbackType: String, Sendable, Codable {
    case acceptGhost = "accept_ghost"
    case acceptSummary = "accept_summary"
    case copyGenerated = "copy_generated"
    case explicitUp = "explicit_up"
    case rejectEdit = "reject_edit"
    case explicitDown = "explicit_down"
    case dismissSuggestion = "dismiss_suggestion"
    case rejectOverwrite = "reject_overwrite"
}

struct FeedbackSignal: Sendable, Identifiable {
    let id: String
    let prompt: String
    let completion: String
    let desirable: Bool
    let feedbackType: FeedbackType
    let contextSummary: String
    let createdAt: Date
}

// MARK: - PII Redaction

/// Redacts common PII patterns before storing feedback.
/// Required by ANCHOR 3, GAP 4 (privacy protection).
nonisolated struct PIIRedactor: Sendable {

    func redact(_ text: String) -> String {
        var result = text

        // Email addresses
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        result = result.replacingOccurrences(
            of: emailPattern, with: "[REDACTED_EMAIL]",
            options: .regularExpression
        )

        // Phone numbers (various formats)
        let phonePattern = #"(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#
        result = result.replacingOccurrences(
            of: phonePattern, with: "[REDACTED_PHONE]",
            options: .regularExpression
        )

        // SSN pattern
        let ssnPattern = #"\b\d{3}-\d{2}-\d{4}\b"#
        result = result.replacingOccurrences(
            of: ssnPattern, with: "[REDACTED_SSN]",
            options: .regularExpression
        )

        // Credit card patterns (basic)
        let ccPattern = #"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b"#
        result = result.replacingOccurrences(
            of: ccPattern, with: "[REDACTED_CC]",
            options: .regularExpression
        )

        return result
    }
}

// MARK: - FeedbackLogger

/// Captures implicit feedback signals from user behavior for KTO training.
///
/// Positive signals (desirable=true): accept ghost text, copy generated, thumbs up.
/// Negative signals (desirable=false): delete/overwrite within 3s, discard, edit >50%.
///
/// Storage: Separate SQLite database at ApplicationSupport/Epistemos/knowledge_fusion.db
/// (Not in main SwiftData container — avoids @Query refetch cascades.)
actor FeedbackLogger {

    private var db: OpaquePointer?
    private let redactor = PIIRedactor()
    private let databasePath: URL

    init(databasePath: URL? = nil) {
        if let path = databasePath {
            self.databasePath = path
        } else {
            let appSupport = FoundationSafety.userApplicationSupportDirectory()
            self.databasePath = appSupport
                .appendingPathComponent("Epistemos")
                .appendingPathComponent("knowledge_fusion.db")
        }
    }

    // MARK: - Database Lifecycle

    func open() throws {
        let fm = FileManager.default
        try fm.createDirectory(
            at: databasePath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var dbPointer: OpaquePointer?
        let status = sqlite3_open(databasePath.path, &dbPointer)
        guard status == SQLITE_OK, let pointer = dbPointer else {
            throw FeedbackLoggerError.databaseOpenFailed(status)
        }
        db = pointer

        // Enable WAL mode for concurrent reads
        try execute("PRAGMA journal_mode=WAL;")

        // Create table
        try execute("""
            CREATE TABLE IF NOT EXISTS kto_feedback (
                id TEXT PRIMARY KEY,
                prompt TEXT NOT NULL,
                completion TEXT NOT NULL,
                desirable INTEGER NOT NULL,
                feedback_type TEXT NOT NULL,
                context_summary TEXT,
                created_at REAL NOT NULL
            );
        """)

        // Index for date-range queries
        try execute("""
            CREATE INDEX IF NOT EXISTS idx_kto_feedback_created_at
            ON kto_feedback(created_at);
        """)
    }

    func close() {
        if let db {
            sqlite3_close(db)
        }
        db = nil
    }

    // MARK: - Logging

    func log(
        prompt: String,
        completion: String,
        desirable: Bool,
        feedbackType: FeedbackType,
        contextSummary: String = ""
    ) throws {
        guard let db else { throw FeedbackLoggerError.databaseNotOpen }

        let id = UUID().uuidString
        let redactedPrompt = redactor.redact(prompt)
        let redactedCompletion = redactor.redact(completion)
        let createdAt = Date().timeIntervalSince1970

        let sql = """
            INSERT INTO kto_feedback (id, prompt, completion, desirable, feedback_type, context_summary, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw FeedbackLoggerError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (redactedPrompt as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (redactedCompletion as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 4, desirable ? 1 : 0)
        sqlite3_bind_text(stmt, 5, (feedbackType.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 6, (contextSummary as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 7, createdAt)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw FeedbackLoggerError.insertFailed(lastError())
        }
    }

    // MARK: - Querying

    func countSignals(since date: Date) throws -> Int {
        guard let db else { throw FeedbackLoggerError.databaseNotOpen }

        let sql = "SELECT COUNT(*) FROM kto_feedback WHERE created_at >= ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw FeedbackLoggerError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, date.timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    func fetchSignals(since date: Date) throws -> [FeedbackSignal] {
        guard let db else { throw FeedbackLoggerError.databaseNotOpen }

        let sql = """
            SELECT id, prompt, completion, desirable, feedback_type, context_summary, created_at
            FROM kto_feedback WHERE created_at >= ? ORDER BY created_at ASC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw FeedbackLoggerError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, date.timeIntervalSince1970)

        var results: [FeedbackSignal] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let prompt = String(cString: sqlite3_column_text(stmt, 1))
            let completion = String(cString: sqlite3_column_text(stmt, 2))
            let desirable = sqlite3_column_int(stmt, 3) == 1
            let typeStr = String(cString: sqlite3_column_text(stmt, 4))
            let context = String(cString: sqlite3_column_text(stmt, 5))
            let timestamp = sqlite3_column_double(stmt, 6)

            results.append(FeedbackSignal(
                id: id,
                prompt: prompt,
                completion: completion,
                desirable: desirable,
                feedbackType: FeedbackType(rawValue: typeStr) ?? .explicitUp,
                contextSummary: context,
                createdAt: Date(timeIntervalSince1970: timestamp)
            ))
        }
        return results
    }

    /// Export feedback signals to KTO-format JSONL for training.
    func exportToJSONL(since date: Date, outputPath: URL) throws -> Int {
        let signals = try fetchSignals(since: date)
        guard !signals.isEmpty else { return 0 }

        let lines = try signals.map { signal -> String in
            let json: [String: Any] = [
                "prompt": signal.prompt,
                "completion": signal.completion,
                "label": signal.desirable,
            ]
            guard JSONSerialization.isValidJSONObject(json) else {
                throw FeedbackLoggerError.exportSerializationFailed
            }
            let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
            guard let line = String(data: data, encoding: .utf8) else {
                throw FeedbackLoggerError.exportEncodingFailed
            }
            return line
        }

        try lines.joined(separator: "\n").write(to: outputPath, atomically: true, encoding: .utf8)
        return signals.count
    }

    // MARK: - Stats

    struct FeedbackStats: Sendable {
        let totalAccepts: Int
        let totalRejects: Int
        let totalThisWeek: Int
    }

    func stats() throws -> FeedbackStats {
        guard let db else { throw FeedbackLoggerError.databaseNotOpen }

        let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600).timeIntervalSince1970

        func count(_ sql: String) throws -> Int {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int(stmt, 0))
        }

        let accepts = try count("SELECT COUNT(*) FROM kto_feedback WHERE desirable = 1;")
        let rejects = try count("SELECT COUNT(*) FROM kto_feedback WHERE desirable = 0;")

        var stmt: OpaquePointer?
        let weekSql = "SELECT COUNT(*) FROM kto_feedback WHERE created_at >= ?;"
        guard sqlite3_prepare_v2(db, weekSql, -1, &stmt, nil) == SQLITE_OK else {
            return FeedbackStats(totalAccepts: accepts, totalRejects: rejects, totalThisWeek: 0)
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, weekAgo)
        let thisWeek = sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0

        return FeedbackStats(totalAccepts: accepts, totalRejects: rejects, totalThisWeek: thisWeek)
    }

    // MARK: - Helpers

    private func execute(_ sql: String) throws {
        guard let db else { throw FeedbackLoggerError.databaseNotOpen }
        var errorMsg: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(db, sql, nil, nil, &errorMsg)
        if status != SQLITE_OK {
            let msg = errorMsg.map { String(cString: $0) } ?? "Unknown"
            sqlite3_free(errorMsg)
            throw FeedbackLoggerError.executeFailed(msg)
        }
    }

    private func lastError() -> String {
        guard let db else { return "No database" }
        return String(cString: sqlite3_errmsg(db))
    }
}

enum FeedbackLoggerError: Error, LocalizedError {
    case databaseOpenFailed(Int32)
    case databaseNotOpen
    case prepareFailed(String)
    case insertFailed(String)
    case executeFailed(String)
    case exportSerializationFailed
    case exportEncodingFailed

    var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let code): return "Failed to open feedback database (code: \(code))"
        case .databaseNotOpen: return "Feedback database not open"
        case .prepareFailed(let msg): return "SQL prepare failed: \(msg)"
        case .insertFailed(let msg): return "SQL insert failed: \(msg)"
        case .executeFailed(let msg): return "SQL execute failed: \(msg)"
        case .exportSerializationFailed: return "Failed to serialize feedback export as JSON"
        case .exportEncodingFailed: return "Failed to encode feedback export as UTF-8"
        }
    }
}
