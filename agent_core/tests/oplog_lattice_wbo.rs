//! Integration smoke test for the Wiring #3 (T17B lattice/WBO → oplog)
//! always-on accounting hook. Verifies that every `OpLog::append`
//! increments the accountant counter (always-on, no feature flag) and
//! that the snapshot's tier / falsifier identifiers match the T17B
//! contract (L0RamHot tier, F-WBO-DriftLedger falsifier).
//!
//! Lives in `tests/` (separate test binary) so the pre-existing lib-
//! test compilation errors in unrelated modules do not block
//! verification of the wiring hook.

use std::sync::Mutex;

use agent_core::bridge::oplog_lattice_wbo_stats_json;
use agent_core::lattice_wbo::{
    LatticeBudget, LatticeErrorContribution, ResidencyTier, WboLedgerEntry,
};
use agent_core::oplog::{OpLog, OpPayload};
use agent_core::oplog_lattice_wbo::{snapshot, LatticeWboOplogStats};

/// The lattice/WBO oplog accountant is process-global, so parallel
/// cargo-test workers racing through this file would otherwise produce
/// flaky `+N appends -> counter incremented by N` assertions. Wrap any
/// test that BOTH reads `snapshot().appends_accounted` and appends
/// to an `OpLog` in this mutex so the strict-equality contract still
/// holds under `cargo test` defaults.
static APPEND_COUNTER_LOCK: Mutex<()> = Mutex::new(());

#[test]
fn oplog_append_increments_lattice_wbo_accounting_counter() {
    let _guard = APPEND_COUNTER_LOCK.lock().unwrap();

    let baseline = snapshot().appends_accounted;

    let log = OpLog::new("test-actor-wiring3");
    let n = 4u64;
    for i in 0..n {
        log.append(OpPayload::NodeAdd {
            id: format!("node-{i}"),
            kind: "note".to_string(),
            title: format!("Test node {i}"),
        });
    }

    let after = snapshot();
    assert_eq!(
        after.appends_accounted - baseline,
        n,
        "lattice/WBO accountant must increment exactly once per OpLog::append"
    );
    assert_eq!(after.tier, ResidencyTier::L0RamHot.canonical_name());
    assert_eq!(after.falsifier, ResidencyTier::L0RamHot.primary_falsifier());
    assert_eq!(after.last_actor_id.as_deref(), Some("test-actor-wiring3"));
}

#[test]
fn oplog_lattice_wbo_stats_json_roundtrips_against_snapshot() {
    let raw = oplog_lattice_wbo_stats_json().expect("FFI export must not error on snapshot read");
    let decoded: LatticeWboOplogStats =
        serde_json::from_str(&raw).expect("snapshot JSON must round-trip");
    let direct = snapshot();
    assert_eq!(decoded.appends_accounted, direct.appends_accounted);
    assert_eq!(decoded.tier, direct.tier);
    assert_eq!(decoded.falsifier, direct.falsifier);
}

#[test]
fn l0_ram_hot_wbo_ledger_entry_validates_with_canonical_register_terms() {
    // T17B substrate invariant: a WboLedgerEntry built from the L0
    // tier's canonical register terms must validate. This pins the
    // Wiring #3 accounting choice to the substrate contract — if the
    // L0 tier's canonical terms drift, this test fails before the
    // wiring rests on a broken floor.
    let tier = ResidencyTier::L0RamHot;
    let term = tier
        .canonical_register_terms()
        .first()
        .copied()
        .expect("L0RamHot tier must declare at least one canonical register term");
    let contributions =
        vec![
            LatticeErrorContribution::new(term, "wiring3-oplog-accounting", 0.0_f64)
                .expect("zero-budget contribution must construct"),
        ];
    let budget = LatticeBudget::new(
        tier.primary_coder(),
        tier.primary_rate_milli_bits_per_symbol(),
        tier.primary_side_information(),
        contributions,
    );
    let entry = WboLedgerEntry::new_for_tier(
        tier,
        budget,
        None,
        tier.primary_falsifier(),
        "Wiring #3 oplog accounting — canonical baseline.",
    );
    entry
        .validate()
        .expect("L0RamHot WboLedgerEntry built from primary defaults must validate");
}

#[test]
fn lattice_wbo_oplog_accountant_is_monotone() {
    let _guard = APPEND_COUNTER_LOCK.lock().unwrap();
    let before = snapshot().appends_accounted;
    let log = OpLog::new("monotone-actor");
    log.append(OpPayload::NodeAdd {
        id: "monotone-id".to_string(),
        kind: "note".to_string(),
        title: "Monotone test".to_string(),
    });
    let after = snapshot().appends_accounted;
    assert!(after > before, "counter must strictly increase on append");
}
