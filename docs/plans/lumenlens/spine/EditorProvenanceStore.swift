//
//  EditorProvenanceStore.swift
//  Epistemos — LUMENLENS spine (authored from Plan P5 + amendment L8, scale S4/SI-2)
//
//  Durable home of per-span suggestion provenance. AMENDED REALITY (L8):
//  agent_core's ClaimLedger is IN-MEMORY (Phase 1) — GRDB persistence for the
//  Rust ledger lands later. So the editor's span provenance persists HERE, in
//  the EXISTING per-vault GRDB database (KEELSTONE B4: never a second DB),
//  with a `claim_id` linkage column for when the Rust ledger gains
//  persistence. Do NOT build against a durable Rust ledger today.
//
//  The span record — the full Fork A metadata the suggestion libraries lack:
//    author / turn / ranges / before-after / rationale / source / accept-state
//
//  Scale (SI-2): NEVER append-forever. Retention = hard-cap + rolling trim
//  (resolved spans age out first), plus periodic compaction of accepted/
//  rejected spans into a summary row per (note, turn). WAL via the existing
//  DatabasePool; short write transactions; index on (note_rel_path, state)
//  and (turn_id).
//
//  NOTE: import GRDB in the real target; migration joins the EXISTING
//  migrator chain (forward-only; eraseDatabaseOnSchemaChange never shipped).
//

import Foundation
// import GRDB

public enum SuggestionState: String, Sendable {
    case pending      // visible tracked-change, not yet decided
    case accepted     // applied to base
    case rejected     // reverted
}

public enum EditSource: String, Sendable {
    case user
    case agent        // KINDRED companion / June capability
}

/// One tracked-change span. Mirrors the SuggestionAdapter's mark attrs 1:1
/// (suggestion-adapter.ts) — the JS side renders; this side is truth-at-rest.
public struct SuggestionSpanRecord: Sendable {
    public var id: String                 // stable UUID (NOT the lib's numeric id)
    public var noteRelativePath: String
    public var turnID: String             // agent turn that produced it ("" for user)
    public var author: String             // companion id / "user"
    public var source: EditSource
    public var kind: String               // insertion | deletion | modification (hwc names)
    /// ProseMirror positions AT CAPTURE TIME + the changeset step-map version,
    /// so spans can be remapped after later edits (Fork A: changeset carries
    /// the step data needed to invert/remap).
    public var fromPos: Int
    public var toPos: Int
    public var mapVersion: Int
    public var beforeText: String?        // deletion/modification payload
    public var afterText: String?         // insertion/modification payload
    public var rationale: String?         // agent-supplied why
    public var state: SuggestionState
    public var createdAt: Date
    public var decidedAt: Date?
    /// Linkage to agent_core ClaimLedger when it gains persistence (L8).
    public var claimID: String?
}

/// Storage facade over the EXISTING per-vault GRDB pool.
public protocol EditorProvenanceStoring: Sendable {
    func insert(_ span: SuggestionSpanRecord) async throws
    func decide(id: String, state: SuggestionState, decidedAt: Date) async throws
    /// "Press mascot → see edits": all spans for a turn, newest first.
    func spans(turnID: String) async throws -> [SuggestionSpanRecord]
    /// "Revert-all-by-companion": pending agent spans for a turn.
    func pendingAgentSpans(turnID: String) async throws -> [SuggestionSpanRecord]
    /// SI-2 retention: trim resolved spans past the cap; compact old turns
    /// into summary rows. Called at maintenance points, never hot-path.
    func compact(keepResolvedMost recent: Int) async throws
}

// Migration sketch (joins the existing migrator chain):
//
// m.registerMigration("lumenlens_v1_suggestion_spans") { db in
//     try db.execute(sql: """
//         CREATE TABLE suggestion_span (
//           id TEXT PRIMARY KEY,
//           note_rel_path TEXT NOT NULL,
//           turn_id TEXT NOT NULL,
//           author TEXT NOT NULL,
//           source TEXT NOT NULL,           -- user | agent
//           kind TEXT NOT NULL,             -- insertion | deletion | modification
//           from_pos INTEGER NOT NULL,
//           to_pos INTEGER NOT NULL,
//           map_version INTEGER NOT NULL,
//           before_text TEXT,
//           after_text TEXT,
//           rationale TEXT,
//           state TEXT NOT NULL DEFAULT 'pending',
//           created_at REAL NOT NULL,
//           decided_at REAL,
//           claim_id TEXT                    -- ledger linkage (L8)
//         );
//         CREATE INDEX idx_span_note_state ON suggestion_span(note_rel_path, state);
//         CREATE INDEX idx_span_turn ON suggestion_span(turn_id);
//     """)
// }
