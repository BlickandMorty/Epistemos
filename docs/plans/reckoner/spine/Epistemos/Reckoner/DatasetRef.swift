// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// Valid. One convention note: DatasetRow.id is String while DatasetRef.id is UUID — document the
// uuidString convention explicitly so the GRDB rows and refs can't drift.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// Stable dataset identity: UUID + vault-relative path. Notes link by frontmatter
// carrying both, so a vault move that keeps files adjacent round-trips; a move
// that separates them triggers embedInvalidated and a relink flow — never a crash.

import Foundation

struct DatasetRef: Codable, Hashable, Sendable {
    let id: UUID
    var vaultPath: String          // vault-relative
    var kind: DatasetKind
    var viewSpec: String           // JSON EmbedViewSpec default

    enum DatasetKind: String, Codable, Sendable {
        case csvFlat               // CSV is vault truth
        case workbook              // XLSX/.icalc truth (formulas/styles/multi-sheet)
    }
}

enum DatasetResolveResult {
    case resolved(URL)
    case moved(newPath: String)    // watcher found it elsewhere → rewrite frontmatter
    case missing                   // → relink UI, embedInvalidated event
}
// TODO: resolve(ref:) against the vault API; promotion csvFlat→workbook is OQ-8
// (the rule that decides WHEN formulas/styles force XLSX truth — never silently).
