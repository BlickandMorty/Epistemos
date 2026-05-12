//! Phase C Week 4 benchmark-harness scaffolding.
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Phase C —
//! Cluster-first multilevel for 50k+ (4 weeks)" → §"Week 4: 50k /
//! 100k performance validation + benchmark harness".
//!
//! The plan asks for "Run synthetic vault benchmarks at 1k / 5k / 10k
//! / 50k / 100k; record: cold open, time-to-fluid, steady fps
//! zoom-out, steady fps zoom-in, drag fps, search-pulse fps, memory
//! residency, awake-fraction during typical use".
//!
//! This module ships the *measurement contract*: typed records with
//! field semantics fixed so the engine/UI plumbing layer that
//! actually runs benchmarks emits the same shape every time. The
//! `BenchmarkScenario` enum maps 1:1 onto the canonical plan's
//! scenario list; `BenchmarkResult` carries the recorded numbers; the
//! exit-gate check is `meets_phase_target` (lookup against the
//! locked targets from §"Phase B acceptance criteria").
//!
//! Engine wiring (the actual timer + frame counter + memory poll) is
//! a Swift+Rust integration job. This file owns the contract.
//!
//! ## Pure-data contract
//!
//! `BenchmarkScenario` + `BenchmarkResult` are pure data + serde.
//! `meets_phase_target` is a pure function. No engine dependencies.
//!
//! ## Determinism contract
//!
//! Benchmark *outcomes* are not deterministic (they reflect hardware
//! variance). The *targets* and *contract* are deterministic — the
//! tests verify the contract structure.

use serde::{Deserialize, Serialize};

/// The canonical scenario list from the plan §"Week 4" deliverables.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub enum BenchmarkScenario {
    /// Time from "open vault" command to first non-blank frame.
    ColdOpen,
    /// Time from cold open until awake-fraction settles below 10%.
    TimeToFluid,
    /// Steady FPS at full zoom-out (cluster view if Phase C is engaged).
    SteadyFpsZoomOut,
    /// Steady FPS at maximum zoom-in (single node region).
    SteadyFpsZoomIn,
    /// FPS during a sustained drag of a hub node.
    DragFps,
    /// FPS during a search-pulse animation.
    SearchPulseFps,
    /// Resident memory after the integrator reaches Steady phase.
    MemoryResidencyMb,
    /// Awake-fraction during typical idle (averaged over 10s).
    AwakeFraction,
}

impl BenchmarkScenario {
    pub fn name(&self) -> &'static str {
        match self {
            Self::ColdOpen => "cold_open",
            Self::TimeToFluid => "time_to_fluid",
            Self::SteadyFpsZoomOut => "steady_fps_zoom_out",
            Self::SteadyFpsZoomIn => "steady_fps_zoom_in",
            Self::DragFps => "drag_fps",
            Self::SearchPulseFps => "search_pulse_fps",
            Self::MemoryResidencyMb => "memory_residency_mb",
            Self::AwakeFraction => "awake_fraction",
        }
    }

    /// Higher number is better? (For sorting / colour-coding in dashboards.)
    pub fn higher_is_better(&self) -> bool {
        matches!(self,
            Self::SteadyFpsZoomOut |
            Self::SteadyFpsZoomIn |
            Self::DragFps |
            Self::SearchPulseFps
        )
    }
}

/// One recorded benchmark measurement.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BenchmarkResult {
    pub scenario: BenchmarkScenario,
    /// Node count of the synthetic vault used for this benchmark.
    pub vault_node_count: u32,
    /// Hardware identifier — typically a compact M-series tag like "M2Pro16GB".
    pub hardware_tag: String,
    /// Software identifier — short branch + commit hash.
    pub build_tag: String,
    /// Measured value. Units depend on scenario:
    ///   ColdOpen / TimeToFluid: milliseconds
    ///   SteadyFpsZoomOut / SteadyFpsZoomIn / DragFps / SearchPulseFps: fps
    ///   MemoryResidencyMb: megabytes
    ///   AwakeFraction: 0.0–1.0
    pub value: f64,
    /// Unix epoch seconds at which the measurement completed.
    pub timestamp_secs: u64,
}

/// Canonical Phase B v1.2 target lookup. Returns the target value or
/// `None` when the (scenario, vault_size) combination has no published
/// target. Targets are pinned to the plan's §"Phase B acceptance
/// criteria" — bumping a target requires a plan revision + this map
/// update in the same commit.
pub fn phase_b_target(scenario: BenchmarkScenario, vault_node_count: u32) -> Option<f64> {
    use BenchmarkScenario::*;
    let bucket = match vault_node_count {
        0..=1_500 => "1k",
        1_501..=7_500 => "5k",
        7_501..=20_000 => "10k",
        20_001..=75_000 => "50k",
        _ => "100k",
    };
    match (scenario, bucket) {
        // ColdOpen — milliseconds (lower better)
        (ColdOpen, "1k")   => Some(80.0),
        (ColdOpen, "5k")   => Some(220.0),
        (ColdOpen, "10k")  => Some(500.0),
        (ColdOpen, "50k")  => Some(1500.0),
        (ColdOpen, "100k") => None, // Phase C territory
        // Steady FPS zoom-out (higher better)
        (SteadyFpsZoomOut, "1k")   => Some(120.0),
        (SteadyFpsZoomOut, "5k")   => Some(90.0),
        (SteadyFpsZoomOut, "10k")  => Some(60.0),
        (SteadyFpsZoomOut, "50k")  => Some(30.0),
        (SteadyFpsZoomOut, "100k") => Some(18.0),
        // Steady FPS zoom-in
        (SteadyFpsZoomIn, "1k")   => Some(120.0),
        (SteadyFpsZoomIn, "5k")   => Some(120.0),
        (SteadyFpsZoomIn, "10k")  => Some(90.0),
        (SteadyFpsZoomIn, "50k")  => Some(60.0),
        (SteadyFpsZoomIn, "100k") => Some(60.0),
        // DragFps
        (DragFps, "50k") => Some(30.0),
        // Memory residency caps (lower better)
        (MemoryResidencyMb, "10k")  => Some(400.0),
        (MemoryResidencyMb, "50k")  => Some(1_024.0),
        (MemoryResidencyMb, "100k") => Some(2_048.0),
        _ => None,
    }
}

/// Did this result meet its Phase B target? `None` when no target is
/// defined for this scenario × vault-size combination (treated as
/// "no gate" — caller decides whether that's a regression).
pub fn meets_phase_target(result: &BenchmarkResult) -> Option<bool> {
    let target = phase_b_target(result.scenario, result.vault_node_count)?;
    Some(if result.scenario.higher_is_better() {
        result.value >= target
    } else {
        result.value <= target
    })
}

/// Roll-up across many results: by-scenario means / per-bucket pass-or-fail.
#[derive(Debug, Clone, PartialEq)]
pub struct BenchmarkSummary {
    /// (scenario × vault_size) → arithmetic mean value
    pub mean_by_scenario_and_size: std::collections::BTreeMap<(BenchmarkScenario, u32), f64>,
    /// Total results consumed.
    pub result_count: usize,
    /// How many failed their target.
    pub failures: Vec<(BenchmarkScenario, u32)>,
}

pub fn summarise_results(results: &[BenchmarkResult]) -> BenchmarkSummary {
    let mut sums: std::collections::BTreeMap<(BenchmarkScenario, u32), (f64, u32)> =
        std::collections::BTreeMap::new();
    for r in results {
        let key = (r.scenario, r.vault_node_count);
        let entry = sums.entry(key).or_insert((0.0, 0));
        entry.0 += r.value;
        entry.1 += 1;
    }
    let mut means: std::collections::BTreeMap<(BenchmarkScenario, u32), f64> =
        std::collections::BTreeMap::new();
    for (key, (sum, count)) in &sums {
        if *count > 0 {
            means.insert(*key, sum / (*count as f64));
        }
    }
    // Failures: each result fails if it doesn't meet its target.
    let mut failures: Vec<(BenchmarkScenario, u32)> = Vec::new();
    let mut seen: std::collections::BTreeSet<(BenchmarkScenario, u32)> =
        std::collections::BTreeSet::new();
    for r in results {
        let key = (r.scenario, r.vault_node_count);
        if let Some(false) = meets_phase_target(r) {
            if seen.insert(key) {
                failures.push(key);
            }
        }
    }
    BenchmarkSummary {
        mean_by_scenario_and_size: means,
        result_count: results.len(),
        failures,
    }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn r(scenario: BenchmarkScenario, vault: u32, value: f64) -> BenchmarkResult {
        BenchmarkResult {
            scenario,
            vault_node_count: vault,
            hardware_tag: "M2Pro16GB".into(),
            build_tag: "test".into(),
            value,
            timestamp_secs: 0,
        }
    }

    #[test]
    fn scenario_name_round_trips_via_serde() {
        let s = BenchmarkScenario::ColdOpen;
        let j = serde_json::to_string(&s).unwrap();
        let back: BenchmarkScenario = serde_json::from_str(&j).unwrap();
        assert_eq!(s, back);
    }

    #[test]
    fn higher_is_better_for_fps_scenarios() {
        assert!(BenchmarkScenario::SteadyFpsZoomOut.higher_is_better());
        assert!(BenchmarkScenario::SteadyFpsZoomIn.higher_is_better());
        assert!(BenchmarkScenario::DragFps.higher_is_better());
        assert!(BenchmarkScenario::SearchPulseFps.higher_is_better());
        assert!(!BenchmarkScenario::ColdOpen.higher_is_better());
        assert!(!BenchmarkScenario::MemoryResidencyMb.higher_is_better());
        assert!(!BenchmarkScenario::AwakeFraction.higher_is_better());
    }

    #[test]
    fn phase_b_target_matches_plan_table() {
        // Plan §"Phase B acceptance criteria":
        // 1k: ≤ 80 ms cold open
        assert_eq!(phase_b_target(BenchmarkScenario::ColdOpen, 1_000), Some(80.0));
        // 50k: ≤ 1.5 s cold open
        assert_eq!(phase_b_target(BenchmarkScenario::ColdOpen, 50_000), Some(1500.0));
        // 50k: drag ≥ 30 fps
        assert_eq!(phase_b_target(BenchmarkScenario::DragFps, 50_000), Some(30.0));
        // Memory at 50k: ≤ 1 GB
        assert_eq!(phase_b_target(BenchmarkScenario::MemoryResidencyMb, 50_000), Some(1024.0));
        // Memory at 100k: ≤ 2 GB
        assert_eq!(phase_b_target(BenchmarkScenario::MemoryResidencyMb, 100_000), Some(2048.0));
    }

    #[test]
    fn phase_b_target_none_for_undefined() {
        // Cold open at 100k is Phase C territory.
        assert_eq!(phase_b_target(BenchmarkScenario::ColdOpen, 100_000), None);
        // SearchPulseFps has no published gate yet.
        assert_eq!(phase_b_target(BenchmarkScenario::SearchPulseFps, 10_000), None);
    }

    #[test]
    fn meets_phase_target_lower_better() {
        // Cold open 1k target = 80 ms; result of 60 → pass, 120 → fail.
        assert_eq!(meets_phase_target(&r(BenchmarkScenario::ColdOpen, 1_000, 60.0)), Some(true));
        assert_eq!(meets_phase_target(&r(BenchmarkScenario::ColdOpen, 1_000, 120.0)), Some(false));
    }

    #[test]
    fn meets_phase_target_higher_better() {
        // 10k zoom-in fps target = 90; 120 → pass, 60 → fail.
        assert_eq!(meets_phase_target(&r(BenchmarkScenario::SteadyFpsZoomIn, 10_000, 120.0)), Some(true));
        assert_eq!(meets_phase_target(&r(BenchmarkScenario::SteadyFpsZoomIn, 10_000, 60.0)), Some(false));
    }

    #[test]
    fn meets_phase_target_none_when_no_gate() {
        assert_eq!(meets_phase_target(&r(BenchmarkScenario::SearchPulseFps, 10_000, 60.0)), None);
    }

    #[test]
    fn summarise_results_means_by_key() {
        let results = vec![
            r(BenchmarkScenario::ColdOpen, 1_000, 70.0),
            r(BenchmarkScenario::ColdOpen, 1_000, 90.0),
            r(BenchmarkScenario::ColdOpen, 5_000, 200.0),
        ];
        let summary = summarise_results(&results);
        // 1k mean = 80; 5k mean = 200.
        let m1 = summary.mean_by_scenario_and_size[&(BenchmarkScenario::ColdOpen, 1_000)];
        assert!((m1 - 80.0).abs() < 1e-9);
        let m5 = summary.mean_by_scenario_and_size[&(BenchmarkScenario::ColdOpen, 5_000)];
        assert!((m5 - 200.0).abs() < 1e-9);
    }

    #[test]
    fn summarise_results_flags_failures_once_per_key() {
        let results = vec![
            r(BenchmarkScenario::ColdOpen, 1_000, 100.0), // 100 > 80 → fail
            r(BenchmarkScenario::ColdOpen, 1_000, 90.0),  // 90 > 80 → also fail
            r(BenchmarkScenario::ColdOpen, 1_000, 50.0),  // 50 < 80 → pass
        ];
        let summary = summarise_results(&results);
        assert_eq!(summary.failures.len(), 1, "failures are deduped per (scenario, size)");
        assert_eq!(summary.failures[0], (BenchmarkScenario::ColdOpen, 1_000));
    }

    #[test]
    fn benchmark_result_round_trips_via_serde() {
        let r = BenchmarkResult {
            scenario: BenchmarkScenario::ColdOpen,
            vault_node_count: 5_000,
            hardware_tag: "M2Pro16GB".into(),
            build_tag: "abc1234".into(),
            value: 200.0,
            timestamp_secs: 1_715_000_000,
        };
        let j = serde_json::to_string(&r).unwrap();
        let back: BenchmarkResult = serde_json::from_str(&j).unwrap();
        assert_eq!(r.scenario, back.scenario);
        assert_eq!(r.vault_node_count, back.vault_node_count);
        assert!((r.value - back.value).abs() < 1e-9);
    }

    #[test]
    fn empty_results_yields_empty_summary() {
        let summary = summarise_results(&[]);
        assert_eq!(summary.result_count, 0);
        assert!(summary.mean_by_scenario_and_size.is_empty());
        assert!(summary.failures.is_empty());
    }
}
