// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// FIXES: (1) add reckoner/mod.rs + `pub mod reckoner;` in lib.rs (spine is uncompilable without).
// (2) SEAM: Rust never writes GRDB (Swift owns the one-transaction commit) and never writes vault
// files directly — return (model bytes, rows, ImportReport) and let Swift persist via
// DatasetStore + AtomicVaultWriter. (3) FFI: no tuple returns, no String errors — uniffi::Record
// ImportReport + AgentErrorFFI + ffi_guard! per bridge.rs contract; stateful engines cross FFI as
// opaque handles (Honest Handle doctrine). (4) drop unused CalcEngine import.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// XLSX READ/WRITE LIVES HERE AND ONLY HERE. Verified: the @ironcalc/wasm package
// "does not contain the xlsx writer and reader, only the engine" — so xlsx runs
// in the Rust `ironcalc` crate inside agent_core, never in the WebView.
// CSV import streams through Rust too: build the model here, snapshot with
// to_bytes, hand bytes to Swift/WebView — never build 100k cells across the JS
// bridge one message at a time.

use super::calc_facade::{CalcEngine, IronCalcEngine};

pub struct ImportReport { pub rows: u32, pub cols: u32, pub warnings: Vec<String> }

pub fn import_csv(_path: &str) -> Result<(IronCalcEngine, ImportReport), String> {
    todo!("stream-parse CSV → engine + GRDB rows; report schema inference warnings")
}

pub fn import_xlsx(_path: &str) -> Result<(IronCalcEngine, ImportReport), String> {
    todo!("ironcalc xlsx reader (Rust crate only)")
}

pub fn export_csv(_engine: &IronCalcEngine, _path: &str) -> Result<(), String> {
    todo!("always available; row-level minimal-diff handled Swift-side")
}

pub fn export_xlsx(_engine: &IronCalcEngine, _path: &str) -> Result<(), String> {
    todo!("ironcalc xlsx writer (Rust crate only); truth format for workbook kind")
}
