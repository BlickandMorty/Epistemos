//! Helios stage 8 — Long-context RULER+BABILong harness substrate-floor.
//!
//! Per `agent_core/src/helios/long_context_harness.rs` module docstring +
//! Helios v6.2 §8 acceptance: RULER 13 tasks + BABILong at 32k context
//! under 30-min wall-clock on M2 Pro 16 GB. Composition target subsumed
//! by F-LocalRecallIsland-32K + F-SemiseparableBlockScan composition.
//!
//! # Substrate-floor scope
//!
//! Exercises `agent_core::helios::{aggregate_results, run_synthetic_
//! harness, Task, HarnessReport, STAGE_8_BUDGET_MS}` end-to-end.
//! Production-PASS requires the harness wired into a live 32k-context
//! model running all 14 tasks; substrate-floor proves the scaffold +
//! aggregation logic is correct.

use agent_core::helios::{
    aggregate_results, run_synthetic_harness, HarnessReport, Task, TaskResult, STAGE_8_BUDGET_MS,
};

#[test]
fn aggregate_empty_results_errors() {
    let res: &[TaskResult] = &[];
    assert!(aggregate_results(32_000, STAGE_8_BUDGET_MS, res).is_err());
}

#[test]
fn run_synthetic_harness_passes_when_all_trials_pass() {
    let plan = [
        (Task::NiahSingle1, 10_u32, 10_u32, 1000_u64), // 100% pass, 1s per trial
        (Task::VariableTracking, 10, 10, 1000),
    ];
    let report = run_synthetic_harness(32_000, STAGE_8_BUDGET_MS, &plan).unwrap();
    assert_eq!(report.context_tokens, 32_000);
    assert!((report.overall_accuracy - 1.0).abs() < 1e-6);
    assert!(report.within_budget, "20 trials × 1s = 20s should fit in 30-min budget");
    assert_eq!(report.per_task_accuracy.len(), 2);
}

#[test]
fn run_synthetic_harness_reports_partial_pass() {
    let plan = [
        (Task::NiahSingle1, 10_u32, 8_u32, 100_u64), // 80%
        (Task::NiahMultikey1, 10, 5, 100),            // 50%
    ];
    let report = run_synthetic_harness(32_000, STAGE_8_BUDGET_MS, &plan).unwrap();
    assert!((report.overall_accuracy - 0.65).abs() < 1e-6, "overall = (8+5)/20 = 0.65");
}

#[test]
fn inconsistent_task_mix_errors() {
    // n_pass > n_trials is invalid.
    let plan = [(Task::NiahSingle1, 5_u32, 10_u32, 100_u64)];
    assert!(run_synthetic_harness(32_000, STAGE_8_BUDGET_MS, &plan).is_err());
}

#[test]
fn stage_8_budget_is_30_minutes() {
    assert_eq!(STAGE_8_BUDGET_MS, 30 * 60 * 1000);
}

#[test]
fn over_budget_run_flags_within_budget_false() {
    // 1 task × 1 trial × 31-min runtime = over budget.
    let plan = [(Task::NiahSingle1, 1_u32, 1_u32, 31_u64 * 60 * 1000)];
    let report = run_synthetic_harness(32_000, STAGE_8_BUDGET_MS, &plan).unwrap();
    assert!(!report.within_budget);
}

#[test]
fn ruler_thirteen_taxonomy_includes_all_canonical_tasks() {
    // Per Hsieh et al. arXiv:2404.06654 RULER paper.
    assert_eq!(Task::RULER_THIRTEEN.len(), 13);
    assert!(Task::RULER_THIRTEEN.contains(&Task::NiahSingle1));
    assert!(Task::RULER_THIRTEEN.contains(&Task::CommonWordExtraction));
    assert!(Task::RULER_THIRTEEN.contains(&Task::QuestionAnswering2));
}

#[test]
fn worst_task_accuracy_reports_minimum() {
    let plan = [
        (Task::NiahSingle1, 10_u32, 9_u32, 100_u64),  // 90%
        (Task::NiahMultikey1, 10, 4, 100),            // 40% — the worst
        (Task::VariableTracking, 10, 7, 100),         // 70%
    ];
    let report = run_synthetic_harness(32_000, STAGE_8_BUDGET_MS, &plan).unwrap();
    let worst = report.worst_task_accuracy().unwrap();
    assert!((worst - 0.4).abs() < 1e-6);
}

#[test]
fn tasks_below_threshold_lists_failures() {
    let plan = [
        (Task::NiahSingle1, 10_u32, 9_u32, 100_u64),  // 90% — above 0.95? no
        (Task::NiahMultikey1, 10, 10, 100),            // 100% — above
        (Task::VariableTracking, 10, 8, 100),          // 80% — below
    ];
    let report = run_synthetic_harness(32_000, STAGE_8_BUDGET_MS, &plan).unwrap();
    let below_95 = report.tasks_below_threshold(0.95);
    assert_eq!(below_95.len(), 2, "NiahSingle1 (90%) + VariableTracking (80%) both below 95%");
}

#[test]
fn budget_utilization_is_zero_when_no_work_done() {
    // Empty plan → error. So check a vacuous near-zero case: 1 trial × 0 ms.
    let plan = [(Task::NiahSingle1, 1_u32, 1_u32, 0_u64)];
    let report = run_synthetic_harness(32_000, STAGE_8_BUDGET_MS, &plan).unwrap();
    let util = report.budget_utilization().unwrap();
    assert_eq!(util, 0.0);
}

#[test]
fn task_codes_match_ruler_paper_strings() {
    // Per Hsieh et al. arXiv:2404.06654 task naming.
    assert_eq!(Task::NiahSingle1.code(), "niah_single_1");
    assert_eq!(Task::CommonWordExtraction.code(), "cwe");
    assert_eq!(Task::VariableTracking.code(), "vt");
    assert_eq!(Task::BabiLong.code(), "babi_long");
}
