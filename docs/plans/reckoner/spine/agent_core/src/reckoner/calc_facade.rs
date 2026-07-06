// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// FIXES: (1) pin — @ironcalc/wasm is =0.7.0 (no wasm 0.7.1); the RUST ironcalc crate pin is a
// separate decision — verify crates.io before the Cargo edit. (2) set_user_input must return
// Result (formula parse errors feed the suggestion UX). (3) evaluate()→CalcDelta{dirty} presumes
// a dirty-set the base Model doesn't expose — wasm side: snapshot-diff dependents; Rust side:
// UserModel EXISTS in the native crate (canon-verified) even though the wasm build lacks it — keep
// the distinction explicit. (4) Add a scratch/clone seam (from_bytes is Sized-only; &dyn consumers
// can't materialize a scratch engine — dataset_ops needs one for dry-runs). (5) from_bytes is
// 2-arg (bytes, language_id) on the shipped wasm. DEP VERDICT (repo-evidenced): ironcalc as an
// OPTIONAL dep behind a `reckoner` cargo feature INSIDE agent_core (lsp-runtime precedent), NOT a
// separate epistemos_calc crate — one UniFFI boundary exists and the facade already absorbs churn;
// canon §0.4's wrapper-crate line is superseded (recorded upstream).
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// THE stable calc contract. IronCalc is pre-1.0 and churning (v0.7.1, Jan 2026;
// "expect things to break until 1.0"), so Epistemos owns this facade and pins
// the crate (=0.7.1). Everything else in the app — Swift, the wasm shim, tools —
// speaks THIS interface; IronCalc API drift is absorbed here and nowhere else.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct CellAddr { pub sheet: u32, pub row: u32, pub col: u32 }

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CalcDelta {
    pub dirty: Vec<CellAddr>,
    pub formatted: Vec<(CellAddr, String)>,
}

pub trait CalcEngine: Send + Sync {
    fn set_user_input(&mut self, addr: CellAddr, input: &str);
    fn evaluate(&mut self) -> CalcDelta;
    fn formatted_value(&self, addr: CellAddr) -> String;
    /// Snapshot/restore so Swift can hand the WebView a model without rebuilding
    /// cell-by-cell across the bridge (IronCalc to_bytes / .icalc path).
    fn to_bytes(&self) -> Vec<u8>;
    fn from_bytes(bytes: &[u8]) -> Self where Self: Sized;
}

pub struct IronCalcEngine {/* TODO: ironcalc::Model, pinned =0.7.1 */}
impl CalcEngine for IronCalcEngine {
    fn set_user_input(&mut self, _addr: CellAddr, _input: &str) { todo!() }
    fn evaluate(&mut self) -> CalcDelta { todo!() }
    fn formatted_value(&self, _addr: CellAddr) -> String { todo!() }
    fn to_bytes(&self) -> Vec<u8> { todo!() }
    fn from_bytes(_bytes: &[u8]) -> Self { todo!() }
}
// OPEN QUESTIONS OQ-1/OQ-2 resolve HERE: ctor arity from the shipped .d.ts /
// crate docs, and whether wasm exports UserModel (diff history / undo /
// apply_external_diffs) — if yes, streamed agent edits lean on it; if no,
// dataset_ops.rs owns the diff layer.
