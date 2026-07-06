// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// P0 CONTRACT FIX: "row-level splice into the CSV" MUST mean splice-rows-IN-MEMORY, then write the
// WHOLE buffer through KEELSTONE's AtomicVaultWriter (coordinate → temp-on-same-volume → replace).
// Never in-place partial file IO — minimal-diff is a property of CONTENT, not the syscall. Gaps:
// AtomicVaultWriter.write takes String — XLSX/.icalc needs a Data overload (KEELSTONE seam item);
// and the "workbook truth written by agent_core" path must NOT bypass atomicity — either Rust does
// equivalent coordinated temp-then-replace or (preferred) Rust returns bytes and SWIFT writes via
// AtomicVaultWriter. Fuzz targets (BOM/CRLF/quoting) stand.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// F1 vault truth. CSV is the human-readable truth for flat datasets; XLSX/.icalc
// (written by agent_core, NOT the WebView — xlsx is absent from the wasm build)
// is the truth for formula-rich workbooks. A companion .dataset.md / frontmatter
// block carries what CSV cannot: dataset id, schema, formula cells, view + chart
// specs. GRDB stays derived. Writes go through minimal-diff writeback so vault
// sync sees small diffs.
// (Dependencies / hand-off seam: vault file I/O + watcher belong to the vault
// layer (EPI-RP-07-KEELSTONE); minimal-diff writeback is the
// EPI-RP-02-LUMENLENS pattern applied to CSV rows.)

import Foundation

enum VaultArtifact {
    /// Durable write after a committed edit: rewrite ONLY changed CSV rows.
    static func writeBack(ref: DatasetRef, changedRows: [Int]) throws {
        // TODO: row-level splice into the CSV; preserve delimiter/quoting/line
        // endings outside changed rows; workbook kind routes to agent_core xlsx.
    }

    /// Import: CSV/XLSX → agent_core parse → GRDB + IronCalc model → grid.
    static func importArtifact(at url: URL) throws -> DatasetRef {
        throw NSError(domain: "TODO", code: 0)
    }

    /// Export: always CSV; XLSX via agent_core csv_xlsx.rs on demand.
    static func export(ref: DatasetRef, as kind: DatasetRef.DatasetKind) throws -> URL {
        throw NSError(domain: "TODO", code: 0)
    }

    /// OQ-8: the promotion rule — the moment a dataset acquires formulas/styles/
    /// multiple sheets, truth promotes csvFlat → workbook EXPLICITLY (user-visible),
    /// never silently, so vault truth never silently loses data.
    static func shouldPromote(ref: DatasetRef) -> Bool { false /* TODO */ }
}
