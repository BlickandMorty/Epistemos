// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// The header's "drift = build failure" is currently FALSE — no enforcement exists. REQUIRED:
// custom Codable (kind discriminator + seq envelope matching the TS shape), enums (not String) for
// state/acceptState, epoch width decision (UInt64 vs JS 2^53), and a cross-language parity fixture
// test (LUMENLENS guard-test precedent). DTO gaps vs Rust TabularSuggestion: add dataset_id,
// source_citation, created_at_ms; before/after must serde as a MAP both sides (Rust Vec<(..)>
// serializes as array-of-pairs — change to BTreeMap).
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// Codable mirror of web/reckoner-grid/src/grid-bridge.ts. Drift = build failure.

import Foundation

typealias GridEpoch = UInt64

enum GridInbound: Codable {
    case loadDataset(epoch: GridEpoch, datasetId: String, snapshotB64: String?)
    case applyAcceptedSuggestion(epoch: GridEpoch, suggestionId: String)
    case stageSuggestion(epoch: GridEpoch, suggestion: TabularSuggestionDTO)
    case cancelSuggestion(epoch: GridEpoch, suggestionId: String)
}

enum GridOutbound: Codable {
    case loadApplied(epoch: GridEpoch, rowCount: Int, colCount: Int)
    case rawEdit(epoch: GridEpoch, sheet: Int, row: Int, col: Int, input: String)
    case calcCompleted(epoch: GridEpoch, dirtyCount: Int)
    case suggestionResolved(epoch: GridEpoch, suggestionId: String, state: String)
    case embedInvalidated(epoch: GridEpoch, datasetId: String)
    case bridgeError(epoch: GridEpoch, code: String, message: String)
}

struct TabularSuggestionDTO: Codable {
    let id: String
    let author: String             // companion identityHash | "june" | "user"
    let turnId: String
    let ranges: [String]           // A1
    let before: [String: String]
    let after: [String: String]
    let rationale: String?
    var acceptState: String        // proposed|accepted|rejected|superseded
}
// TODO: custom Codable (kind discriminator) matching the TS envelope incl. seq.
