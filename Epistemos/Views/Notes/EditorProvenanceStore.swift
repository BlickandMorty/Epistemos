import Foundation
import GRDB

nonisolated enum SuggestionState: String, Equatable, Sendable {
    case pending
    case accepted
    case rejected
}

nonisolated enum EditSource: String, Equatable, Sendable {
    case user
    case agent
}

nonisolated struct SuggestionSpanRecord: Equatable, Sendable {
    var id: String
    var noteRelativePath: String
    var turnID: String
    var author: String
    var source: EditSource
    var kind: String
    var fromPos: Int
    var toPos: Int
    var mapVersion: Int
    var beforeText: String?
    var afterText: String?
    var rationale: String?
    var sourceCitation: String?
    var state: SuggestionState
    var createdAt: Date
    var decidedAt: Date?
    var claimID: String?
}

nonisolated struct EditorProvenanceCompactionSummary: Equatable, Sendable {
    var noteRelativePath: String
    var turnID: String
    var compactedAt: Date
    var acceptedCount: Int
    var rejectedCount: Int
    var lastDecidedAt: Date?
    var claimIDs: [String]
}

nonisolated protocol EditorProvenanceStoring: Sendable {
    func insert(_ span: SuggestionSpanRecord) async throws
    func decide(id: String, state: SuggestionState, decidedAt: Date) async throws
    func spans(turnID: String) async throws -> [SuggestionSpanRecord]
    func pendingAgentSpans(turnID: String) async throws -> [SuggestionSpanRecord]
    func compact(keepResolvedMost recent: Int) async throws
}

nonisolated struct EditorProvenanceBridgeSink: Sendable {
    private let store: any EditorProvenanceStoring
    private let noteRelativePath: String

    init(store: any EditorProvenanceStoring, noteRelativePath: String) {
        self.store = store
        self.noteRelativePath = noteRelativePath
    }

    func persistApplied(
        _ payload: EpdocSuggestionSpanPayload,
        createdAt: Date = Date()
    ) async throws {
        try await store.insert(
            SuggestionSpanRecord(
                id: payload.id,
                noteRelativePath: noteRelativePath,
                turnID: payload.turnID,
                author: payload.author,
                source: .agent,
                kind: payload.kind,
                fromPos: payload.from,
                toPos: payload.to,
                mapVersion: payload.mapVersion,
                beforeText: payload.before,
                afterText: payload.after,
                rationale: payload.rationale,
                sourceCitation: payload.sourceCitation,
                state: .pending,
                createdAt: createdAt,
                decidedAt: nil,
                claimID: payload.claimID
            )
        )
    }

    func persistResolved(
        _ resolution: EpdocSuggestionResolution,
        decidedAt: Date = Date()
    ) async throws {
        try await store.decide(
            id: resolution.suggestionID,
            state: SuggestionState(resolution.state),
            decidedAt: decidedAt
        )
    }
}

nonisolated enum EditorProvenanceStoreError: Error, Equatable {
    case spanNotFound(String)
    case invalidPendingDecision(String)
    case invalidState(String)
    case invalidSource(String)
}

private extension SuggestionState {
    init(_ resolutionState: EpdocSuggestionResolutionState) {
        switch resolutionState {
        case .accepted:
            self = .accepted
        case .rejected:
            self = .rejected
        }
    }
}

actor EditorProvenanceGRDBStore: EditorProvenanceStoring {
    private let writer: any DatabaseWriter

    init(databaseWriter: any DatabaseWriter) {
        self.writer = databaseWriter
    }

    func insert(_ span: SuggestionSpanRecord) async throws {
        try await writer.write { db in
            try Self.installSchemaIfNeeded(db)
            try db.execute(
                sql: """
                    INSERT INTO suggestion_span(
                        id,
                        note_rel_path,
                        turn_id,
                        author,
                        source,
                        kind,
                        from_pos,
                        to_pos,
                        map_version,
                        before_text,
                        after_text,
                        rationale,
                        source_citation,
                        state,
                        created_at,
                        decided_at,
                        claim_id
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    span.id,
                    span.noteRelativePath,
                    span.turnID,
                    span.author,
                    span.source.rawValue,
                    span.kind,
                    span.fromPos,
                    span.toPos,
                    span.mapVersion,
                    span.beforeText,
                    span.afterText,
                    span.rationale,
                    span.sourceCitation,
                    span.state.rawValue,
                    span.createdAt.timeIntervalSince1970,
                    span.decidedAt?.timeIntervalSince1970,
                    span.claimID,
                ]
            )
        }
    }

    func decide(id: String, state: SuggestionState, decidedAt: Date) async throws {
        guard state != .pending else {
            throw EditorProvenanceStoreError.invalidPendingDecision(id)
        }

        try await writer.write { db in
            try Self.installSchemaIfNeeded(db)
            try db.execute(
                sql: """
                    UPDATE suggestion_span
                    SET state = ?, decided_at = ?
                    WHERE id = ?
                    """,
                arguments: [state.rawValue, decidedAt.timeIntervalSince1970, id]
            )
            if db.changesCount == 0 {
                throw EditorProvenanceStoreError.spanNotFound(id)
            }
        }
    }

    func spans(turnID: String) async throws -> [SuggestionSpanRecord] {
        try await ensureSchema()
        return try await writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM suggestion_span
                    WHERE turn_id = ?
                    ORDER BY created_at DESC, id DESC
                    """,
                arguments: [turnID]
            )
            return try rows.map(Self.spanRecord(from:))
        }
    }

    func pendingAgentSpans(turnID: String) async throws -> [SuggestionSpanRecord] {
        try await ensureSchema()
        return try await writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM suggestion_span
                    WHERE turn_id = ? AND source = ? AND state = ?
                    ORDER BY created_at DESC, id DESC
                    """,
                arguments: [turnID, EditSource.agent.rawValue, SuggestionState.pending.rawValue]
            )
            return try rows.map(Self.spanRecord(from:))
        }
    }

    func compact(keepResolvedMost recent: Int) async throws {
        let keepCount = max(0, recent)
        try await writer.write { db in
            try Self.installSchemaIfNeeded(db)
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM suggestion_span
                    WHERE state IN (?, ?)
                    ORDER BY COALESCE(decided_at, created_at) DESC, created_at DESC, id DESC
                    LIMIT -1 OFFSET ?
                    """,
                arguments: [
                    SuggestionState.accepted.rawValue,
                    SuggestionState.rejected.rawValue,
                    keepCount,
                ]
            )
            let compacted = try rows.map(Self.spanRecord(from:))
            guard !compacted.isEmpty else { return }

            var summaries: [CompactionKey: CompactionDelta] = [:]
            for span in compacted {
                let key = CompactionKey(
                    noteRelativePath: span.noteRelativePath,
                    turnID: span.turnID
                )
                summaries[key, default: CompactionDelta()].absorb(span)
                try db.execute(
                    sql: "DELETE FROM suggestion_span WHERE id = ?",
                    arguments: [span.id]
                )
            }

            let compactedAt = Date().timeIntervalSince1970
            for (key, delta) in summaries {
                let existingSummary = try Row.fetchOne(
                    db,
                    sql: """
                        SELECT claim_ids_json FROM suggestion_span_summary
                        WHERE note_rel_path = ? AND turn_id = ?
                        """,
                    arguments: [key.noteRelativePath, key.turnID]
                )
                let existingClaimIDs = try existingSummary
                    .map { row in try Self.decodeClaimIDs(row["claim_ids_json"]) }
                    ?? []
                let claimIDsJSON = try Self.encodeClaimIDs(
                    Self.mergedClaimIDs(existingClaimIDs, delta.claimIDs)
                )
                try db.execute(
                    sql: """
                        INSERT INTO suggestion_span_summary(
                            note_rel_path,
                            turn_id,
                            compacted_at,
                            accepted_count,
                            rejected_count,
                            last_decided_at,
                            claim_ids_json
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(note_rel_path, turn_id) DO UPDATE SET
                            compacted_at = excluded.compacted_at,
                            accepted_count = suggestion_span_summary.accepted_count + excluded.accepted_count,
                            rejected_count = suggestion_span_summary.rejected_count + excluded.rejected_count,
                            last_decided_at = MAX(
                                COALESCE(suggestion_span_summary.last_decided_at, 0),
                                COALESCE(excluded.last_decided_at, 0)
                            ),
                            claim_ids_json = excluded.claim_ids_json
                        """,
                    arguments: [
                        key.noteRelativePath,
                        key.turnID,
                        compactedAt,
                        delta.acceptedCount,
                        delta.rejectedCount,
                        delta.lastDecidedAt,
                        claimIDsJSON,
                    ]
                )
            }
        }
    }

    func compactionSummaries() async throws -> [EditorProvenanceCompactionSummary] {
        try await ensureSchema()
        return try await writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM suggestion_span_summary
                    ORDER BY note_rel_path ASC, turn_id ASC
                    """
            )
            return try rows.map(Self.summary(from:))
        }
    }

    func resetAllForTests() async throws {
        try await writer.write { db in
            try Self.installSchemaIfNeeded(db)
            try db.execute(sql: "DELETE FROM suggestion_span")
            try db.execute(sql: "DELETE FROM suggestion_span_summary")
        }
    }

    private func ensureSchema() async throws {
        try await writer.write { db in
            try Self.installSchemaIfNeeded(db)
        }
    }

    private nonisolated static func installSchemaIfNeeded(_ db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS suggestion_span (
                id TEXT PRIMARY KEY,
                note_rel_path TEXT NOT NULL,
                turn_id TEXT NOT NULL,
                author TEXT NOT NULL,
                source TEXT NOT NULL,
                kind TEXT NOT NULL,
                from_pos INTEGER NOT NULL,
                to_pos INTEGER NOT NULL,
                map_version INTEGER NOT NULL,
                before_text TEXT,
                after_text TEXT,
                rationale TEXT,
                source_citation TEXT,
                state TEXT NOT NULL DEFAULT 'pending',
                created_at REAL NOT NULL,
                decided_at REAL,
                claim_id TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_span_note_state
                ON suggestion_span(note_rel_path, state);
            CREATE INDEX IF NOT EXISTS idx_span_turn
                ON suggestion_span(turn_id);
            CREATE TABLE IF NOT EXISTS suggestion_span_summary (
                note_rel_path TEXT NOT NULL,
                turn_id TEXT NOT NULL,
                compacted_at REAL NOT NULL,
                accepted_count INTEGER NOT NULL DEFAULT 0,
                rejected_count INTEGER NOT NULL DEFAULT 0,
                last_decided_at REAL,
                claim_ids_json TEXT NOT NULL DEFAULT '[]',
                PRIMARY KEY(note_rel_path, turn_id)
            );
            CREATE INDEX IF NOT EXISTS idx_span_summary_turn
                ON suggestion_span_summary(turn_id);
            """)
        try addColumnIfMissing(
            db,
            table: "suggestion_span",
            column: "source_citation",
            definition: "source_citation TEXT"
        )
        try addColumnIfMissing(
            db,
            table: "suggestion_span",
            column: "claim_id",
            definition: "claim_id TEXT"
        )
        try addColumnIfMissing(
            db,
            table: "suggestion_span_summary",
            column: "claim_ids_json",
            definition: "claim_ids_json TEXT NOT NULL DEFAULT '[]'"
        )
    }

    private nonisolated static func spanRecord(from row: Row) throws -> SuggestionSpanRecord {
        let stateRaw: String = row["state"]
        guard let state = SuggestionState(rawValue: stateRaw) else {
            throw EditorProvenanceStoreError.invalidState(stateRaw)
        }
        let sourceRaw: String = row["source"]
        guard let source = EditSource(rawValue: sourceRaw) else {
            throw EditorProvenanceStoreError.invalidSource(sourceRaw)
        }
        let createdAt: Double = row["created_at"]
        let decidedAt: Double? = row["decided_at"]
        return SuggestionSpanRecord(
            id: row["id"],
            noteRelativePath: row["note_rel_path"],
            turnID: row["turn_id"],
            author: row["author"],
            source: source,
            kind: row["kind"],
            fromPos: row["from_pos"],
            toPos: row["to_pos"],
            mapVersion: row["map_version"],
            beforeText: row["before_text"],
            afterText: row["after_text"],
            rationale: row["rationale"],
            sourceCitation: row["source_citation"],
            state: state,
            createdAt: Date(timeIntervalSince1970: createdAt),
            decidedAt: decidedAt.map(Date.init(timeIntervalSince1970:)),
            claimID: row["claim_id"]
        )
    }

    private nonisolated static func summary(from row: Row) throws -> EditorProvenanceCompactionSummary {
        let compactedAt: Double = row["compacted_at"]
        let lastDecidedAt: Double? = row["last_decided_at"]
        let claimIDsJSON: String = row["claim_ids_json"]
        return EditorProvenanceCompactionSummary(
            noteRelativePath: row["note_rel_path"],
            turnID: row["turn_id"],
            compactedAt: Date(timeIntervalSince1970: compactedAt),
            acceptedCount: row["accepted_count"],
            rejectedCount: row["rejected_count"],
            lastDecidedAt: lastDecidedAt.map(Date.init(timeIntervalSince1970:)),
            claimIDs: try decodeClaimIDs(claimIDsJSON)
        )
    }

    private nonisolated static func encodeClaimIDs(_ claimIDs: [String]) throws -> String {
        let bytes = try JSONEncoder().encode(claimIDs.sorted())
        return String(decoding: bytes, as: UTF8.self)
    }

    private nonisolated static func decodeClaimIDs(_ json: String) throws -> [String] {
        guard let data = json.data(using: .utf8) else { return [] }
        return try JSONDecoder().decode([String].self, from: data)
    }

    private nonisolated static func mergedClaimIDs(_ lhs: [String], _ rhs: [String]) -> [String] {
        Array(Set(lhs + rhs)).sorted()
    }

    private nonisolated static func addColumnIfMissing(
        _ db: Database,
        table: String,
        column: String,
        definition: String
    ) throws {
        let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(\(table))")
        let names = Set(rows.map { row -> String in row["name"] })
        guard !names.contains(column) else { return }
        try db.execute(sql: "ALTER TABLE \(table) ADD COLUMN \(definition)")
    }

    private struct CompactionKey: Hashable {
        let noteRelativePath: String
        let turnID: String
    }

    private struct CompactionDelta {
        var acceptedCount = 0
        var rejectedCount = 0
        var lastDecidedAt: Double?
        var claimIDs: [String] = []

        mutating func absorb(_ span: SuggestionSpanRecord) {
            switch span.state {
            case .accepted:
                acceptedCount += 1
            case .rejected:
                rejectedCount += 1
            case .pending:
                return
            }
            let decidedAt = span.decidedAt?.timeIntervalSince1970
                ?? span.createdAt.timeIntervalSince1970
            if lastDecidedAt.map({ decidedAt > $0 }) ?? true {
                lastDecidedAt = decidedAt
            }
            if let claimID = span.claimID, !claimID.isEmpty {
                claimIDs.append(claimID)
            }
        }
    }
}
