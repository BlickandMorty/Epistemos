//! Wiring #3 (T17B lattice/WBO → oplog) — always-on accounting hook.
//!
//! Every successful `OpLog::append` increments the accounting counter
//! here. This is the "lattice/WBO accounting entry" called out in the
//! T17B wiring contract — a parallel ledger that proves no oplog
//! mutation can be hidden behind a UAS residency lease or a "free"
//! active-support budget.
//!
//! **No feature flag.** Per the canon (T17B / W-WBO-DriftLedger), the
//! accounting must be always-on so the F-WBO-DriftLedger falsifier has
//! a continuous audit trail to verify. The hook is cheap — a single
//! mutex-guarded counter increment per append — so it does not change
//! oplog hot-path semantics measurably.
//!
//! The chosen accounting residency tier is **L0 RAM Hot**: oplog
//! entries live in process memory and are appended at chat / vault /
//! note-write rates, matching the L0 tier's canonical operating
//! envelope. The tier's `primary_falsifier()` returns
//! `F-WBO-DriftLedger`, which is what the Settings → Diagnostics
//! `LatticeWBOHealthRow` surfaces as the falsifier-coverage chip.

use std::sync::Mutex;
use std::sync::OnceLock;

use crate::lattice_wbo::ResidencyTier;

/// Accounting tier for oplog mutation entries. Frozen by design — the
/// substrate-level meaning of an oplog append maps to L0 (RAM hot) by
/// the T17B residency register.
pub const OPLOG_ACCOUNTING_TIER: ResidencyTier = ResidencyTier::L0RamHot;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct LatticeWboOplogStats {
    pub appends_accounted: u64,
    pub tier: String,
    pub falsifier: String,
    pub last_actor_id: Option<String>,
    pub last_ts_unix_ms: Option<i64>,
}

#[derive(Debug)]
struct State {
    appends_accounted: u64,
    last_actor_id: Option<String>,
    last_ts_unix_ms: Option<i64>,
}

impl State {
    const fn new() -> Self {
        Self {
            appends_accounted: 0,
            last_actor_id: None,
            last_ts_unix_ms: None,
        }
    }
}

static STATE: OnceLock<Mutex<State>> = OnceLock::new();

fn state() -> &'static Mutex<State> {
    STATE.get_or_init(|| Mutex::new(State::new()))
}

/// Account one successful `OpLog::append`. Called from inside `append`
/// after the in-memory cache push so the counter never overcounts a
/// failed persistence path.
pub fn account_append(actor_id: &str, ts_unix_ms: i64) {
    if let Ok(mut s) = state().lock() {
        s.appends_accounted = s.appends_accounted.saturating_add(1);
        s.last_actor_id = Some(actor_id.to_string());
        s.last_ts_unix_ms = Some(ts_unix_ms);
    }
}

/// Read-only snapshot of the lattice/WBO oplog accounting state. Used
/// by the FFI export `oplog_lattice_wbo_stats_json` and by the
/// `LatticeWBOHealthRow` to render entry count + falsifier coverage.
pub fn snapshot() -> LatticeWboOplogStats {
    let s = state().lock().ok();
    LatticeWboOplogStats {
        appends_accounted: s.as_ref().map(|s| s.appends_accounted).unwrap_or(0),
        tier: OPLOG_ACCOUNTING_TIER.canonical_name().to_string(),
        falsifier: OPLOG_ACCOUNTING_TIER.primary_falsifier().to_string(),
        last_actor_id: s.as_ref().and_then(|s| s.last_actor_id.clone()),
        last_ts_unix_ms: s.as_ref().and_then(|s| s.last_ts_unix_ms),
    }
}

/// Test-only reset of the accounting state. Used by integration tests
/// that need to start from zero — production callers MUST NOT call
/// this (the always-on contract is one-directional accumulation).
#[doc(hidden)]
pub fn reset_for_tests() {
    if let Ok(mut s) = state().lock() {
        *s = State::new();
    }
}
