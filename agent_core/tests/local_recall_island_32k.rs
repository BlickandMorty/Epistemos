//! F-LocalRecallIsland-32K — substrate-floor integration harness.
//!
//! Per `docs/falsifiers/F-LocalRecallIsland-32K_2026_05_17.md`.
//!
//! # Substrate-floor scope
//!
//! Exercises `agent_core::helios::run_passkey_trials` at the 32k context
//! length with the canonical 5 depths × 50 trials per the falsifier §3.
//! Production-PASS requires the same protocol against a live 32k-context
//! model; substrate-floor here proves the helios CPU reference substrate
//! (RecallStore + passkey_retrieve + single_passkey_trial) is correct.

use agent_core::helios::run_passkey_trials;

#[test]
fn passkey_recall_at_32k_meets_95_percent_threshold() {
    let depths = vec![0.10, 0.25, 0.50, 0.75, 0.90];
    let report = run_passkey_trials(32_000, &depths, 50, 0xCAFE_BABE_DEAD_BEEF_u64)
        .expect("run_passkey_trials must succeed");

    // F-LocalRecallIsland-32K acceptance per falsifier §3 + Helios v6.2 §7:
    // - Average passkey rate ≥ 0.95
    // - Per-depth rate ≥ 0.90
    assert!(
        report.meets_threshold(0.95),
        "average passkey recall = {} < 0.95",
        report.overall_recall
    );

    for (depth, rate) in depths.iter().zip(report.per_depth_recall.iter()) {
        assert!(
            *rate >= 0.90,
            "depth {} recall = {} < 0.90 per-depth floor",
            depth,
            rate
        );
    }
}

#[test]
fn worst_depth_recall_is_reported() {
    let depths = vec![0.10, 0.50, 0.90];
    let report = run_passkey_trials(1_000, &depths, 10, 42).expect("trials must succeed");
    let worst = report.worst_depth_recall().expect("must have per-depth data");
    // worst should be in [0, 1]
    assert!((0.0..=1.0).contains(&worst));
}

#[test]
fn empty_depths_errors() {
    assert!(run_passkey_trials(32_000, &[], 50, 0).is_err());
}

#[test]
fn zero_trials_errors() {
    assert!(run_passkey_trials(32_000, &[0.5], 0, 0).is_err());
}

#[test]
fn depths_below_threshold_lists_failures() {
    let depths = vec![0.10, 0.25, 0.50, 0.75, 0.90];
    let report = run_passkey_trials(1_000, &depths, 20, 1234).expect("trials must succeed");
    let failing = report.depths_below_threshold(0.95);
    // Substrate-floor substrate is perfect — should be empty.
    assert!(failing.is_empty(), "substrate-floor recall should not fail any depth at threshold 0.95");
}

#[test]
fn single_depth_smaller_context_still_works() {
    let report = run_passkey_trials(256, &[0.50], 10, 0xBEEF).expect("trials must succeed");
    assert!(report.overall_recall >= 0.95);
    assert_eq!(report.per_depth_recall.len(), 1);
}
