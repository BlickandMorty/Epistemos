//! Source:
//! - `docs/fusion/helios v6.2.md` 8-stage falsifier §8 — RULER +
//!   BABILong harness at 32K context under 30-min wall-clock on
//!   M2 Pro 16 GB.
//! - Hsieh et al., "RULER: What's the Real Context Size of Your
//!   Long-Context Language Models?", arXiv:2404.06654, 2024 — 13
//!   task categories (niah_single_1/2/3, niah_multikey_1/2/3,
//!   niah_multivalue, niah_multiquery, vt, cwe, fwe, qa_1, qa_2).
//! - Kuratov et al., "BABILong: Testing the Limits of LLMs with
//!   Long Context Reasoning-in-a-Haystack", arXiv:2406.10149, 2024
//!   — bAbi reasoning at long context.
//!
//! # Helios stage 8 — RULER + BABILong harness (completes B.2)
//!
//! Substrate-floor scaffold for the 32K acceptance run. Owns:
//!
//! - [`Task`] catalog covering the RULER 13 + BABILong categories.
//! - [`TaskResult`] per-trial outcome.
//! - [`HarnessReport`] aggregate with per-task accuracy + total
//!   wall-clock + whether the 30-min budget was met.
//! - [`run_synthetic_harness`] — substrate-floor runner with caller-
//!   supplied per-trial outcomes (real impl plugs in the live model).
//!
//! Real validation needs the 32K-context model + the actual task
//! prompts; this harness is the result shape that the Swift falsifier
//! driver fills in.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum Task {
    NiahSingle1,
    NiahSingle2,
    NiahSingle3,
    NiahMultikey1,
    NiahMultikey2,
    NiahMultikey3,
    NiahMultivalue,
    NiahMultiquery,
    VariableTracking,
    CommonWordExtraction,
    FrequentWordExtraction,
    QuestionAnswering1,
    QuestionAnswering2,
    BabiLong,
}

impl Task {
    pub const RULER_THIRTEEN: [Task; 13] = [
        Task::NiahSingle1,
        Task::NiahSingle2,
        Task::NiahSingle3,
        Task::NiahMultikey1,
        Task::NiahMultikey2,
        Task::NiahMultikey3,
        Task::NiahMultivalue,
        Task::NiahMultiquery,
        Task::VariableTracking,
        Task::CommonWordExtraction,
        Task::FrequentWordExtraction,
        Task::QuestionAnswering1,
        Task::QuestionAnswering2,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            Task::NiahSingle1 => "niah_single_1",
            Task::NiahSingle2 => "niah_single_2",
            Task::NiahSingle3 => "niah_single_3",
            Task::NiahMultikey1 => "niah_multikey_1",
            Task::NiahMultikey2 => "niah_multikey_2",
            Task::NiahMultikey3 => "niah_multikey_3",
            Task::NiahMultivalue => "niah_multivalue",
            Task::NiahMultiquery => "niah_multiquery",
            Task::VariableTracking => "vt",
            Task::CommonWordExtraction => "cwe",
            Task::FrequentWordExtraction => "fwe",
            Task::QuestionAnswering1 => "qa_1",
            Task::QuestionAnswering2 => "qa_2",
            Task::BabiLong => "babi_long",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct TaskResult {
    pub task: Task,
    pub passed: bool,
    pub wall_clock_ms: u64,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct HarnessReport {
    pub context_tokens: u32,
    pub per_task_accuracy: Vec<(Task, f32)>,
    pub overall_accuracy: f32,
    pub total_wall_clock_ms: u64,
    pub budget_ms: u64,
    pub within_budget: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum HarnessError {
    NoResults,
    InconsistentTaskMix,
}

/// Aggregate per-task results into a [`HarnessReport`].
pub fn aggregate_results(
    context_tokens: u32,
    budget_ms: u64,
    results: &[TaskResult],
) -> Result<HarnessReport, HarnessError> {
    if results.is_empty() {
        return Err(HarnessError::NoResults);
    }
    let mut by_task: std::collections::BTreeMap<Task, (u32, u32)> = Default::default();
    let mut total_ms: u64 = 0;
    let mut total_pass: u32 = 0;
    let mut total: u32 = 0;
    for r in results {
        let e = by_task.entry(r.task).or_insert((0, 0));
        e.0 += 1;
        if r.passed {
            e.1 += 1;
            total_pass += 1;
        }
        total += 1;
        total_ms = total_ms.saturating_add(r.wall_clock_ms);
    }
    let mut per_task: Vec<(Task, f32)> = by_task
        .into_iter()
        .map(|(t, (n, p))| (t, (p as f32) / (n as f32)))
        .collect();
    per_task.sort_by_key(|(t, _)| t.code());
    Ok(HarnessReport {
        context_tokens,
        per_task_accuracy: per_task,
        overall_accuracy: (total_pass as f32) / (total as f32),
        total_wall_clock_ms: total_ms,
        budget_ms,
        within_budget: total_ms <= budget_ms,
    })
}

/// Substrate-floor synthetic runner. Caller supplies per-task
/// outcomes + ms-per-trial; production swaps in the live model.
pub fn run_synthetic_harness(
    context_tokens: u32,
    budget_ms: u64,
    plan: &[(Task, u32, u32, u64)],
) -> Result<HarnessReport, HarnessError> {
    let mut results = Vec::new();
    for &(task, n_trials, n_pass, ms_per_trial) in plan {
        if n_pass > n_trials {
            return Err(HarnessError::InconsistentTaskMix);
        }
        for i in 0..n_trials {
            results.push(TaskResult {
                task,
                passed: i < n_pass,
                wall_clock_ms: ms_per_trial,
            });
        }
    }
    aggregate_results(context_tokens, budget_ms, &results)
}

pub const STAGE_8_BUDGET_MS: u64 = 30 * 60 * 1000;

impl HarnessReport {
    /// Minimum per-task accuracy. None if `per_task_accuracy` is
    /// empty. The actual bar value to compare to the §8 acceptance
    /// threshold.
    pub fn worst_task_accuracy(&self) -> Option<f32> {
        self.per_task_accuracy
            .iter()
            .map(|(_, a)| *a)
            .fold(None, |acc, a| match acc {
                None => Some(a),
                Some(b) => Some(if a < b { a } else { b }),
            })
    }

    /// (task, accuracy) pairs for every task below `threshold`.
    /// Used in the control-room "why did stage 8 fail?" view.
    pub fn tasks_below_threshold(&self, threshold: f32) -> Vec<(Task, f32)> {
        self.per_task_accuracy
            .iter()
            .filter_map(|&(t, a)| if a < threshold { Some((t, a)) } else { None })
            .collect()
    }

    /// `total_wall_clock_ms / budget_ms`. 0.0-1.0 = within budget;
    /// >1.0 = over budget. Returns `None` if `budget_ms == 0`.
    /// Useful for surfacing "we're at 80% of the wall-clock budget"
    /// before the boolean within_budget flips false.
    pub fn budget_utilization(&self) -> Option<f32> {
        if self.budget_ms == 0 {
            return None;
        }
        Some(self.total_wall_clock_ms as f32 / self.budget_ms as f32)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ruler_has_thirteen_distinct_tasks() {
        let set: std::collections::HashSet<_> = Task::RULER_THIRTEEN.iter().copied().collect();
        assert_eq!(set.len(), 13);
    }

    #[test]
    fn task_codes_are_stable_strings() {
        assert_eq!(Task::NiahSingle1.code(), "niah_single_1");
        assert_eq!(Task::VariableTracking.code(), "vt");
        assert_eq!(Task::BabiLong.code(), "babi_long");
    }

    #[test]
    fn stage_8_budget_is_30_minutes() {
        assert_eq!(STAGE_8_BUDGET_MS, 1_800_000);
    }

    #[test]
    fn empty_results_errors() {
        let err = aggregate_results(32_768, STAGE_8_BUDGET_MS, &[]).unwrap_err();
        assert_eq!(err, HarnessError::NoResults);
    }

    #[test]
    fn perfect_pass_report_at_thirty_minute_budget() {
        let plan: Vec<(Task, u32, u32, u64)> = Task::RULER_THIRTEEN
            .iter()
            .map(|&t| (t, 50, 50, 100))
            .collect();
        let report = run_synthetic_harness(32_768, STAGE_8_BUDGET_MS, &plan).unwrap();
        assert_eq!(report.context_tokens, 32_768);
        assert_eq!(report.overall_accuracy, 1.0);
        assert!(report.within_budget);
    }

    #[test]
    fn over_budget_reports_not_within_budget() {
        let plan = vec![(Task::NiahSingle1, 10, 10, 200_000)];
        let report = run_synthetic_harness(32_768, STAGE_8_BUDGET_MS, &plan).unwrap();
        assert_eq!(report.total_wall_clock_ms, 2_000_000);
        assert!(!report.within_budget);
    }

    #[test]
    fn partial_pass_reports_correct_per_task_accuracy() {
        let plan = vec![
            (Task::NiahSingle1, 10, 8, 50),
            (Task::NiahSingle2, 10, 5, 50),
        ];
        let report = run_synthetic_harness(32_768, STAGE_8_BUDGET_MS, &plan).unwrap();
        let by_code: std::collections::BTreeMap<_, _> = report
            .per_task_accuracy
            .iter()
            .map(|(t, a)| (t.code(), *a))
            .collect();
        assert!((by_code["niah_single_1"] - 0.8).abs() < 1e-6);
        assert!((by_code["niah_single_2"] - 0.5).abs() < 1e-6);
        assert!((report.overall_accuracy - 0.65).abs() < 1e-6);
    }

    #[test]
    fn inconsistent_pass_count_rejected() {
        let plan = vec![(Task::NiahSingle1, 10, 99, 50)];
        let err = run_synthetic_harness(32_768, STAGE_8_BUDGET_MS, &plan).unwrap_err();
        assert_eq!(err, HarnessError::InconsistentTaskMix);
    }

    #[test]
    fn report_roundtrips_through_serde_json() {
        let plan = vec![(Task::NiahSingle1, 5, 5, 100)];
        let report = run_synthetic_harness(32_768, STAGE_8_BUDGET_MS, &plan).unwrap();
        let json = serde_json::to_string(&report).unwrap();
        let back: HarnessReport = serde_json::from_str(&json).unwrap();
        assert_eq!(report, back);
    }

    #[test]
    fn task_result_roundtrips_through_serde_json() {
        let tr = TaskResult { task: Task::BabiLong, passed: true, wall_clock_ms: 250 };
        let json = serde_json::to_string(&tr).unwrap();
        let back: TaskResult = serde_json::from_str(&json).unwrap();
        assert_eq!(tr, back);
    }

    #[test]
    fn babi_long_not_in_ruler_thirteen() {
        assert!(!Task::RULER_THIRTEEN.contains(&Task::BabiLong));
    }

    #[test]
    fn per_task_accuracy_sorted_by_code() {
        let plan = vec![
            (Task::QuestionAnswering1, 5, 4, 50),
            (Task::NiahSingle1, 5, 5, 50),
        ];
        let report = run_synthetic_harness(32_768, STAGE_8_BUDGET_MS, &plan).unwrap();
        let codes: Vec<&str> =
            report.per_task_accuracy.iter().map(|(t, _)| t.code()).collect();
        let mut sorted = codes.clone();
        sorted.sort();
        assert_eq!(codes, sorted);
    }

    #[test]
    fn empty_task_in_plan_skipped_silently() {
        let plan = vec![(Task::NiahSingle1, 0, 0, 0), (Task::NiahSingle2, 1, 1, 100)];
        let report = run_synthetic_harness(32_768, STAGE_8_BUDGET_MS, &plan).unwrap();
        assert_eq!(report.per_task_accuracy.len(), 1);
        assert_eq!(report.per_task_accuracy[0].0, Task::NiahSingle2);
    }

    #[test]
    fn under_budget_at_30_minutes_with_realistic_per_task_load() {
        let plan: Vec<(Task, u32, u32, u64)> = Task::RULER_THIRTEEN
            .iter()
            .map(|&t| (t, 50, 48, 2_500))
            .collect();
        let report = run_synthetic_harness(32_768, STAGE_8_BUDGET_MS, &plan).unwrap();
        assert!(report.within_budget);
        assert!(report.overall_accuracy >= 0.95);
    }

    // ── worst_task_accuracy + tasks_below + budget_utilization (iter 127) ───

    fn approx(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn worst_task_accuracy_empty_returns_none() {
        let r = HarnessReport {
            context_tokens: 0,
            per_task_accuracy: vec![],
            overall_accuracy: 0.0,
            total_wall_clock_ms: 0,
            budget_ms: 1000,
            within_budget: true,
        };
        assert!(r.worst_task_accuracy().is_none());
    }

    #[test]
    fn worst_task_accuracy_picks_minimum() {
        let r = HarnessReport {
            context_tokens: 32_768,
            per_task_accuracy: vec![
                (Task::NiahSingle1, 0.96),
                (Task::NiahMultikey1, 0.88),
                (Task::VariableTracking, 0.99),
            ],
            overall_accuracy: 0.943,
            total_wall_clock_ms: 100,
            budget_ms: 1000,
            within_budget: true,
        };
        assert!(approx(r.worst_task_accuracy().unwrap(), 0.88, 1e-6));
    }

    #[test]
    fn tasks_below_threshold_empty_when_all_pass() {
        let r = HarnessReport {
            context_tokens: 32_768,
            per_task_accuracy: vec![
                (Task::NiahSingle1, 0.96),
                (Task::NiahMultikey1, 0.98),
            ],
            overall_accuracy: 0.97,
            total_wall_clock_ms: 100,
            budget_ms: 1000,
            within_budget: true,
        };
        assert!(r.tasks_below_threshold(0.95).is_empty());
    }

    #[test]
    fn tasks_below_threshold_returns_failures() {
        let r = HarnessReport {
            context_tokens: 32_768,
            per_task_accuracy: vec![
                (Task::NiahSingle1, 0.96),
                (Task::NiahMultikey1, 0.88),
                (Task::BabiLong, 0.92),
            ],
            overall_accuracy: 0.92,
            total_wall_clock_ms: 100,
            budget_ms: 1000,
            within_budget: true,
        };
        let failures = r.tasks_below_threshold(0.95);
        assert_eq!(failures.len(), 2);
        assert_eq!(failures[0].0, Task::NiahMultikey1);
        assert_eq!(failures[1].0, Task::BabiLong);
    }

    #[test]
    fn budget_utilization_zero_budget_returns_none() {
        let r = HarnessReport {
            context_tokens: 0,
            per_task_accuracy: vec![],
            overall_accuracy: 0.0,
            total_wall_clock_ms: 0,
            budget_ms: 0,
            within_budget: true,
        };
        assert!(r.budget_utilization().is_none());
    }

    #[test]
    fn budget_utilization_half_when_half_consumed() {
        let r = HarnessReport {
            context_tokens: 32_768,
            per_task_accuracy: vec![],
            overall_accuracy: 0.0,
            total_wall_clock_ms: 500,
            budget_ms: 1000,
            within_budget: true,
        };
        assert!(approx(r.budget_utilization().unwrap(), 0.5, 1e-6));
    }

    #[test]
    fn budget_utilization_over_one_when_over_budget() {
        let r = HarnessReport {
            context_tokens: 32_768,
            per_task_accuracy: vec![],
            overall_accuracy: 0.0,
            total_wall_clock_ms: 1500,
            budget_ms: 1000,
            within_budget: false,
        };
        assert!(approx(r.budget_utilization().unwrap(), 1.5, 1e-6));
    }

    #[test]
    fn budget_utilization_under_one_iff_within_budget_for_realistic_run() {
        // Cross-surface invariant: within_budget == (utilization <= 1.0).
        let plan: Vec<(Task, u32, u32, u64)> = Task::RULER_THIRTEEN
            .iter()
            .map(|&t| (t, 50, 48, 2_500))
            .collect();
        let report = run_synthetic_harness(32_768, STAGE_8_BUDGET_MS, &plan).unwrap();
        let util = report.budget_utilization().unwrap();
        assert_eq!(report.within_budget, util <= 1.0);
    }
}
