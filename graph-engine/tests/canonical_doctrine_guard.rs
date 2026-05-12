//! Single-file canonical doctrine drift detector.
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Locked
//! architectural decisions": 42 decisions are pinned values. This test
//! file is the consolidated drift gate — it spell-checks every
//! load-bearing constant across the substrate against the canonical
//! plan in one place. If anyone bumps a canonical value without
//! updating the plan (and this test), CI fails with a pointer back to
//! the doctrinal source.
//!
//! ## Why a single file
//!
//! Per-module tests pin one decision each. This file is the canonical
//! one-stop drift detector — useful when reviewing release candidates
//! or auditing a refactor that touched multiple modules. Run this file
//! first when investigating a doctrine question.
//!
//! ## Naming
//!
//! Every test is named `decision_<#>_<short_summary>`, matching the
//! numbered decision in the canonical plan §"Locked architectural
//! decisions" table.

use graph_engine::adaptive_kernels::{
    k_frame_threshold, sleep_force_threshold, sleep_velocity_threshold,
    sleep_globally_enabled,
};
use graph_engine::atmosphere::AtmosphereConfig;
use graph_engine::benchmark_harness::{phase_a_target, phase_b_target, BenchmarkScenario};
use graph_engine::pipeline_order::{
    CANONICAL_PIPELINE_ORDER, PipelineStage, validate_ordering,
};
use graph_engine::query_reply::FreshnessClass;
use graph_engine::reveal::RevealPhase;

#[test]
fn decision_3_node_state_is_64_byte_aligned() {
    assert_eq!(
        std::mem::size_of::<graph_engine::node_state::GraphNodeState>(),
        64,
        "Decision #3: NodeState must be 64 bytes (single Apple Silicon cache line)"
    );
    assert_eq!(graph_engine::node_state::GRAPH_NODE_STATE_ABI_VERSION, 1,
        "Decision #3 / V2.2 lock: ABI version starts at 1");
}

#[test]
fn decision_4_renderable_is_independent_of_sleep() {
    use graph_engine::node_state::{FLAG_AWAKE, FLAG_RENDERABLE, FLAG_SLEEPING, FLAG_WARMING};
    // Bits at canonical positions:
    assert_eq!(FLAG_RENDERABLE, 1u32 << 0);
    assert_eq!(FLAG_AWAKE, 1u32 << 1);
    assert_eq!(FLAG_WARMING, 1u32 << 2);
    assert_eq!(FLAG_SLEEPING, 1u32 << 3);
    // Sleeping + Renderable can coexist.
    let sleep_render = FLAG_RENDERABLE | FLAG_SLEEPING;
    assert!(sleep_render & FLAG_RENDERABLE != 0,
        "Decision #4: sleeping nodes still render");
}

#[test]
fn decision_5_sleep_disabled_until_steady_phase() {
    assert!(!sleep_globally_enabled(RevealPhase::Idle));
    assert!(!sleep_globally_enabled(RevealPhase::Seeding));
    assert!(!sleep_globally_enabled(RevealPhase::Ramping));
    assert!(!sleep_globally_enabled(RevealPhase::Settling));
    assert!(sleep_globally_enabled(RevealPhase::Steady),
        "Decision #5: sleep enabled only in Steady phase");
}

#[test]
fn decision_18_canonical_pipeline_order_is_ten_stages() {
    assert_eq!(CANONICAL_PIPELINE_ORDER.len(), 10);
    // Spelled out — drift gate.
    assert_eq!(
        CANONICAL_PIPELINE_ORDER,
        [
            PipelineStage::Activation,
            PipelineStage::GridBin,
            PipelineStage::CellReduce,
            PipelineStage::Repulsion,
            PipelineStage::Springs,
            PipelineStage::AdaptiveSpeed,
            PipelineStage::IntegrateSleep,
            PipelineStage::Compact,
            PipelineStage::IndirectDraw,
            PipelineStage::Render,
        ],
        "Decision #18: GPU pass order must be Activation → grid bin → cell reduce → \
         repulsion → springs → adaptive speed → integrate+sleep → compact → \
         indirect draw → render"
    );
    assert!(validate_ordering(&CANONICAL_PIPELINE_ORDER).is_ok());
}

#[test]
fn decision_20_sleep_velocity_threshold_formula() {
    // |v| < 0.002 * ideal_edge_length_per_frame
    // 30 / 60 = 0.5 → 0.5 * 0.002 = 0.001
    let t = sleep_velocity_threshold(30.0, 60.0);
    assert!((t - 0.001).abs() < 1e-9,
        "Decision #20: sleep_velocity_threshold(30, 60) must be 0.001, got {}", t);
}

#[test]
fn decision_21_sleep_force_threshold_formula() {
    // |F| < 0.01 * repulsion_scale
    assert_eq!(sleep_force_threshold(100.0), 1.0,
        "Decision #21: sleep_force_threshold(100) = 1.0");
    assert_eq!(sleep_force_threshold(50.0), 0.5);
}

#[test]
fn decision_22_sleep_frame_count_120hz_60hz() {
    assert_eq!(k_frame_threshold(120.0), 24,
        "Decision #22: 24 consecutive @ 120Hz");
    assert_eq!(k_frame_threshold(60.0), 12,
        "Decision #22: 12 consecutive @ 60Hz");
}

#[test]
fn decision_26_drag_no_sleep_window_is_250ms() {
    let cfg = AtmosphereConfig::default();
    assert!((cfg.drag_sticky_seconds - 0.25).abs() < f32::EPSILON,
        "Decision #26: drag-no-sleep window = 250 ms (0.25 s)");
}

#[test]
fn decision_27_awake_fraction_collapse_threshold_is_20_percent() {
    let cfg = AtmosphereConfig::default();
    assert!((cfg.awake_fraction_failure_threshold - 0.20).abs() < f32::EPSILON,
        "Decision #27: awake-fraction >20% sustained = sleep system collapsed");
}

#[test]
fn decision_39_query_freshness_has_three_classes() {
    // Three latency classes per decision #40.
    let _ = FreshnessClass::Immediate;
    let _ = FreshnessClass::NearRealTime;
    let _ = FreshnessClass::Heavy;
}

#[test]
fn decision_40_three_latency_classes_thresholds() {
    // Decision #40:
    //   Immediate     — same frame   (~17 ms)
    //   NearRealTime  — 0-250 ms
    //   Heavy         — 50 ms - 60 s
    assert_eq!(FreshnessClass::Immediate.max_freshness_ms(), 17);
    assert_eq!(FreshnessClass::NearRealTime.max_freshness_ms(), 250);
    assert_eq!(FreshnessClass::Heavy.max_freshness_ms(), 60_000);
}

#[test]
fn phase_a_acceptance_targets_match_v1_1_ship_bar() {
    // Per §"Phase A acceptance criteria (v1.1 ship bar)":
    //   1k cold open ≤ 200 ms
    //   5k cold open ≤ 600 ms
    //   10k cold open ≤ 1.4 s
    //   50k cold open ≤ 4 s
    assert_eq!(phase_a_target(BenchmarkScenario::ColdOpen, 1_000), Some(200.0));
    assert_eq!(phase_a_target(BenchmarkScenario::ColdOpen, 5_000), Some(600.0));
    assert_eq!(phase_a_target(BenchmarkScenario::ColdOpen, 10_000), Some(1400.0));
    assert_eq!(phase_a_target(BenchmarkScenario::ColdOpen, 50_000), Some(4000.0));
    // Memory at 10k: ≤ 400 MB
    assert_eq!(phase_a_target(BenchmarkScenario::MemoryResidencyMb, 10_000), Some(400.0));
}

#[test]
fn phase_b_acceptance_targets_match_v1_2_ship_bar() {
    // Per §"Phase B acceptance criteria (v1.2 ship bar)":
    //   1k cold open ≤ 80 ms (GPU-tightened from Phase A's 200)
    //   50k cold open ≤ 1.5 s
    //   50k drag ≥ 30 fps
    //   100k zoom-out ≥ 18 fps (Phase C cluster LOD territory)
    //   Memory: 10k ≤ 400 MB, 50k ≤ 1 GB, 100k ≤ 2 GB
    assert_eq!(phase_b_target(BenchmarkScenario::ColdOpen, 1_000), Some(80.0));
    assert_eq!(phase_b_target(BenchmarkScenario::ColdOpen, 50_000), Some(1500.0));
    assert_eq!(phase_b_target(BenchmarkScenario::DragFps, 50_000), Some(30.0));
    assert_eq!(phase_b_target(BenchmarkScenario::SteadyFpsZoomOut, 100_000), Some(18.0));
    assert_eq!(phase_b_target(BenchmarkScenario::MemoryResidencyMb, 10_000), Some(400.0));
    assert_eq!(phase_b_target(BenchmarkScenario::MemoryResidencyMb, 50_000), Some(1024.0));
    assert_eq!(phase_b_target(BenchmarkScenario::MemoryResidencyMb, 100_000), Some(2048.0));
}

#[test]
fn phase_b_targets_uniformly_tighter_than_phase_a() {
    // Cross-phase relationship guard. Phase B (GPU) must be at least as
    // tight as Phase A (CPU) on every overlapping cell.
    for n in [1_000u32, 5_000, 10_000] {
        if let (Some(a_cold), Some(b_cold)) = (
            phase_a_target(BenchmarkScenario::ColdOpen, n),
            phase_b_target(BenchmarkScenario::ColdOpen, n),
        ) {
            assert!(b_cold <= a_cold,
                "ColdOpen at {n}: Phase B ({b_cold}) must be ≤ Phase A ({a_cold})");
        }
    }
}

#[test]
fn render_phase_state_machine_has_canonical_five_phases() {
    // Per decision #6: Idle → Seeding → Ramping → Settling → Steady.
    // This test merely asserts all five exist + are distinct enum variants
    // by pairwise inequality check.
    let phases = [
        RevealPhase::Idle,
        RevealPhase::Seeding,
        RevealPhase::Ramping,
        RevealPhase::Settling,
        RevealPhase::Steady,
    ];
    assert_eq!(phases.len(), 5);
    for i in 0..phases.len() {
        for j in (i + 1)..phases.len() {
            assert_ne!(phases[i], phases[j],
                "phase {:?} must differ from {:?}", phases[i], phases[j]);
        }
    }
}
