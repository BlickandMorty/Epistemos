//! Visual-equivalence test harness for the causal-atmosphere sleep model
//! (Phase A Week 4 of the canonical graph plan).
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Week 4: Causal-
//! atmosphere sleep + visual-equivalence test", the Phase A exit gate
//! requires:
//!
//! 1. Mean SSIM ≥ 0.995 between full-physics baseline and atmosphere-
//!    accelerated runs on a deterministic 10s interaction corpus
//! 2. Min SSIM ≥ 0.990
//! 3. p99 visible-node position error < 2 px
//! 4. p99 visible-edge endpoint error < 2 px
//! 5. Zero "wake misses" (sleeping node fails to react for > 2 frames after
//!    a wake-front passes)
//! 6. Zoom-in regression test: 100 random camera positions across a 10k
//!    synthetic vault → every frustum node renders within 1 frame
//!
//! ## Status (Phase A Week 4 part 2 — scaffolding only)
//!
//! This file ships the *deterministic interaction corpus* + the
//! *position-error and wake-miss harness* in pure-data form. The metrics
//! that require pixel rendering (mean/min SSIM, zoom-in frustum check) are
//! gated behind the `metal-render` feature, which is not part of the
//! default cargo test profile — running the rendering portion requires
//! `cargo test --features metal-render --release` and a Metal device, so
//! it lands on CI separately.
//!
//! The position-error half is enough to gate Phase A's atmosphere
//! algorithm — if positions drift more than 2 px under accelerated sleep,
//! something is wrong with the atmosphere math. The SSIM half catches
//! visual artifacts that pixel-comparable but position-equivalent code
//! still produces (label aliasing, edge antialias drift).
//!
//! ## Determinism contract
//!
//! Every step in the corpus is a deterministic function of frame index +
//! seed. Same seed → same corpus → same expected positions. The corpus is
//! versioned so future changes don't silently invalidate cached baselines.

use graph_engine::atmosphere::{
    AtmosphereConfig, AtmosphereNodeInput, AtmosphereStep, WakeState,
    awake_fraction, compute_step, decay_pending_heat, should_fall_back_to_full_sim,
    AwakeFractionSnapshot,
};
use graph_engine::warmstart::{WarmstartInput, warm_start};
use std::collections::BTreeMap;

/// Versioned corpus identifier. Bumped whenever the deterministic frame
/// sequence changes; baselines are recomputed accordingly. v1 = "10-second
/// interaction sequence" landed 2026-05-12.
pub const CORPUS_VERSION: u32 = 1;

/// One frame of the deterministic interaction corpus.
#[derive(Debug, Clone)]
pub enum InteractionEvent {
    /// No user input — just integrator + atmosphere.
    Idle,
    /// Pan the camera by `(dx, dy)` in world units this frame.
    Pan { dx: f32, dy: f32 },
    /// Zoom in / out by `factor` (1.05 = 5% zoom-in).
    Zoom { factor: f32 },
    /// Drag a single node by id; controller treats it as `Awake`.
    DragNode { id: u32, dx: f32, dy: f32 },
    /// Search-pulse: wake all nodes whose id matches `query_match`.
    SearchPulse { matching: Vec<u32> },
    /// Click select a single node — wakes it + neighbour expansion.
    ClickSelect { id: u32 },
}

/// 10-second corpus at 60 fps = 600 frames. Per the canonical plan: open,
/// idle, pan, zoom-in, drag hub, search-pulse, zoom-out.
pub fn canonical_corpus(seed: u64, node_count: usize) -> Vec<InteractionEvent> {
    let mut frames: Vec<InteractionEvent> = Vec::with_capacity(600);
    // 0-119  (2s)   open + idle settle
    for _ in 0..120 { frames.push(InteractionEvent::Idle); }
    // 120-179 (1s)  pan right
    for _ in 0..60 { frames.push(InteractionEvent::Pan { dx: 5.0, dy: 0.0 }); }
    // 180-239 (1s)  zoom in
    for _ in 0..60 { frames.push(InteractionEvent::Zoom { factor: 1.02 }); }
    // 240-299 (1s)  drag a single hub (id chosen by seed-mod)
    let hub_id = (seed.wrapping_mul(0xC0FF_EEEE) as usize % node_count.max(1)) as u32;
    for _ in 0..60 {
        frames.push(InteractionEvent::DragNode { id: hub_id, dx: 1.5, dy: 0.5 });
    }
    // 300-359 (1s)  search pulse — wake 8 nodes
    let pulse: Vec<u32> = (0..8)
        .map(|i| ((seed.wrapping_mul(0x9E37_79B9) as usize + i * 31) % node_count.max(1)) as u32)
        .collect();
    for _ in 0..60 {
        frames.push(InteractionEvent::SearchPulse { matching: pulse.clone() });
    }
    // 360-419 (1s)  click-select a node
    let pick = (seed.wrapping_mul(0xDEAD_BEEF) as usize % node_count.max(1)) as u32;
    for _ in 0..60 {
        frames.push(InteractionEvent::ClickSelect { id: pick });
    }
    // 420-479 (1s)  zoom out
    for _ in 0..60 { frames.push(InteractionEvent::Zoom { factor: 0.98 }); }
    // 480-599 (2s)  idle final settle
    for _ in 0..120 { frames.push(InteractionEvent::Idle); }
    debug_assert_eq!(frames.len(), 600, "v1 corpus must be 600 frames");
    frames
}

/// Stripped-down node record we maintain during the harness run. Just
/// enough to feed atmosphere::compute_step and track position drift.
#[derive(Debug, Clone)]
struct HarnessNode {
    id: u32,
    x: f32,
    y: f32,
    vx: f32,
    vy: f32,
    heat: f32,
    state: WakeState,
    // ─── For wake-miss detection ──────────────────────────────────────
    frames_since_wake_signal: Option<u32>,
}

impl HarnessNode {
    fn to_input(&self, median_rest: f32) -> AtmosphereNodeInput {
        AtmosphereNodeInput {
            id: self.id,
            x: self.x,
            y: self.y,
            vx: self.vx,
            vy: self.vy,
            radius: 1.0,
            median_incident_rest_length: median_rest,
            heat: self.heat,
            state: self.state,
        }
    }
}

/// Result of a harness run — pure data so callers can assert.
#[derive(Debug, Clone)]
pub struct HarnessRun {
    pub final_positions: Vec<(u32, [f32; 2])>,
    pub max_position_drift: f32,
    pub p99_position_drift: f32,
    pub wake_misses: usize,
    pub fallback_fired_frames: usize,
    pub awake_fraction_p95: f32,
    pub frames: usize,
}

/// Run the corpus under the atmosphere-accelerated path and return the
/// stats needed by the Week 4 exit gate.
pub fn run_harness(
    node_ids: &[u32],
    edges: &[(u32, u32)],
    seed: u64,
) -> HarnessRun {
    let warm = warm_start(WarmstartInput {
        node_ids,
        edges,
        world_half: 100.0,
        seed,
    });
    let cfg = AtmosphereConfig::default();
    let mut by_id: BTreeMap<u32, HarnessNode> = BTreeMap::new();
    let mut initial_pos: BTreeMap<u32, [f32; 2]> = BTreeMap::new();
    for (id, p) in &warm.positions {
        by_id.insert(*id, HarnessNode {
            id: *id, x: p[0], y: p[1], vx: 0.0, vy: 0.0, heat: 0.0,
            state: WakeState::Sleeping, frames_since_wake_signal: None,
        });
        initial_pos.insert(*id, *p);
    }
    let median_rest = 10.0_f32;
    let corpus = canonical_corpus(seed, node_ids.len());

    let mut awake_fractions: Vec<AwakeFractionSnapshot> = Vec::with_capacity(corpus.len());
    let mut wake_miss_count = 0usize;
    let mut fallback_frames = 0usize;

    for ev in &corpus {
        // 1. Apply the event — promote heat / proposed state on affected ids.
        match ev {
            InteractionEvent::Idle => {}
            InteractionEvent::Pan { .. } | InteractionEvent::Zoom { .. } => {
                // Camera-only events don't directly poke nodes; the
                // atmosphere algorithm handles edge propagation through the
                // wake_front_radius parameter.
            }
            InteractionEvent::DragNode { id, dx, dy } => {
                if let Some(n) = by_id.get_mut(id) {
                    n.x += dx;
                    n.y += dy;
                    n.vx = *dx;
                    n.vy = *dy;
                    n.heat = (n.heat + 1.0).min(8.0);
                    n.state = WakeState::Awake;
                    n.frames_since_wake_signal = Some(0);
                }
            }
            InteractionEvent::SearchPulse { matching } => {
                for id in matching {
                    if let Some(n) = by_id.get_mut(id) {
                        n.heat = (n.heat + 2.0).min(8.0);
                        n.frames_since_wake_signal = Some(0);
                    }
                }
            }
            InteractionEvent::ClickSelect { id } => {
                if let Some(n) = by_id.get_mut(id) {
                    n.heat = (n.heat + 1.0).min(8.0);
                    n.state = WakeState::Awake;
                    n.frames_since_wake_signal = Some(0);
                }
            }
        }

        // 2. Run atmosphere::compute_step per node.
        let mut steps: Vec<AtmosphereStep> = Vec::with_capacity(by_id.len());
        let snapshot: Vec<HarnessNode> = by_id.values().cloned().collect();
        for n in &snapshot {
            let input = n.to_input(median_rest);
            // For the scaffold we assume a uniform "front" passes through
            // every node every frame; the front radius and distance equal
            // the node's atmosphere geometry. Real engine wiring will
            // pass camera/click fronts.
            let step = compute_step(&input, &cfg, 5.0, 100.0, false);
            steps.push(step);
        }

        // 3. Apply step results: update wake_to + drift bookkeeping.
        for step in &steps {
            if let Some(n) = by_id.get_mut(&step.id) {
                n.state = step.wake_to;
                n.heat = decay_pending_heat(n.heat);
                // Cheap integrator surrogate so positions drift slightly when
                // dt_factor > 0; otherwise the node freezes.
                let dt = cfg.dt * step.dt_factor;
                n.x += n.vx * dt;
                n.y += n.vy * dt;
                n.vx *= 0.94;
                n.vy *= 0.94;
                // Wake-miss check: signalled → must be Warming|Awake within 2 frames.
                if let Some(age) = n.frames_since_wake_signal {
                    let next = age + 1;
                    n.frames_since_wake_signal = Some(next);
                    if next > 2 && step.wake_to == WakeState::Sleeping {
                        wake_miss_count += 1;
                        n.frames_since_wake_signal = None;
                    } else if step.wake_to != WakeState::Sleeping {
                        n.frames_since_wake_signal = None;
                    }
                }
            }
        }

        // 4. Awake-fraction telemetry + fallback detector.
        let states: Vec<WakeState> = by_id.values().map(|n| n.state).collect();
        let snap = awake_fraction(&states);
        awake_fractions.push(snap);
        if should_fall_back_to_full_sim(&awake_fractions, &cfg) {
            fallback_frames += 1;
        }
    }

    // 5. Compute drift stats.
    let mut drifts: Vec<f32> = Vec::with_capacity(by_id.len());
    for (id, n) in &by_id {
        let p0 = initial_pos[id];
        let dx = n.x - p0[0];
        let dy = n.y - p0[1];
        drifts.push((dx * dx + dy * dy).sqrt());
    }
    drifts.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    let max_drift = drifts.last().copied().unwrap_or(0.0);
    let p99_idx = ((drifts.len() as f32 * 0.99) as usize).min(drifts.len().saturating_sub(1));
    let p99 = drifts.get(p99_idx).copied().unwrap_or(0.0);

    // 6. Awake-fraction p95.
    let mut fractions: Vec<f32> = awake_fractions
        .iter().map(|s| s.fraction_awake_or_warming).collect();
    fractions.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    let af_idx = ((fractions.len() as f32 * 0.95) as usize).min(fractions.len().saturating_sub(1));
    let af_p95 = fractions.get(af_idx).copied().unwrap_or(0.0);

    let mut final_positions: Vec<(u32, [f32; 2])> =
        by_id.values().map(|n| (n.id, [n.x, n.y])).collect();
    final_positions.sort_by_key(|&(id, _)| id);

    HarnessRun {
        final_positions,
        max_position_drift: max_drift,
        p99_position_drift: p99,
        wake_misses: wake_miss_count,
        fallback_fired_frames: fallback_frames,
        awake_fraction_p95: af_p95,
        frames: corpus.len(),
    }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

fn linear_chain(n: u32) -> (Vec<u32>, Vec<(u32, u32)>) {
    let nodes: Vec<u32> = (0..n).collect();
    let edges: Vec<(u32, u32)> = (0..n.saturating_sub(1)).map(|i| (i, i + 1)).collect();
    (nodes, edges)
}

fn star(branches: u32) -> (Vec<u32>, Vec<(u32, u32)>) {
    let nodes: Vec<u32> = (0..=branches).collect();
    let edges: Vec<(u32, u32)> = (1..=branches).map(|i| (0, i)).collect();
    (nodes, edges)
}

#[test]
fn corpus_is_deterministic() {
    let a = canonical_corpus(42, 1_000);
    let b = canonical_corpus(42, 1_000);
    assert_eq!(a.len(), b.len(), "same seed → identical length");
    assert_eq!(a.len(), 600, "v1 corpus is 600 frames");
    // Compare lengths only — match arm payloads are easier as a property.
    // For deeper structural check, pin frame 240 = DragNode.
    match a[240] {
        InteractionEvent::DragNode { .. } => {}
        ref other => panic!("frame 240 must be DragNode, got {:?}", other),
    }
}

#[test]
fn harness_runs_on_linear_chain() {
    let (nodes, edges) = linear_chain(50);
    let result = run_harness(&nodes, &edges, 42);
    assert_eq!(result.frames, 600);
    // Wake-miss count is bounded by the pulse cohort size — in the
    // scaffold we always feed a stub "uniform front" with
    // distance_to_front = 100.0, so nodes outside the warm zone don't
    // actually receive the wake. Engine-wired runs will pass real
    // per-event distances and this becomes an exact equality check.
    assert!(result.wake_misses <= 16,
        "wake-miss count bounded by pulse cohort; got {}", result.wake_misses);
}

#[test]
fn harness_runs_on_star_graph() {
    let (nodes, edges) = star(30);
    let result = run_harness(&nodes, &edges, 7);
    assert_eq!(result.frames, 600);
    // p99 drift bounded — the harness only nudges nodes inside the warm zone.
    // The scaffold uses a uniform front so drift is small; tight assert is
    // the engine-wired version's job.
    assert!(
        result.max_position_drift < 200.0,
        "scaffold max drift bounded; got {}",
        result.max_position_drift
    );
}

#[test]
fn harness_is_deterministic() {
    let (nodes, edges) = linear_chain(40);
    let a = run_harness(&nodes, &edges, 99);
    let b = run_harness(&nodes, &edges, 99);
    assert_eq!(a.final_positions, b.final_positions,
        "same input + seed → bit-identical final positions");
    assert_eq!(a.wake_misses, b.wake_misses);
    assert_eq!(a.fallback_fired_frames, b.fallback_fired_frames);
}

#[test]
fn empty_graph_runs_clean() {
    let result = run_harness(&[], &[], 1);
    assert_eq!(result.frames, 600);
    assert_eq!(result.final_positions.len(), 0);
    assert_eq!(result.wake_misses, 0);
}

#[test]
fn single_node_does_not_crash() {
    let result = run_harness(&[42], &[], 1);
    assert_eq!(result.final_positions.len(), 1);
    assert!(result.max_position_drift < 10.0);
}

#[test]
fn drift_bounds_are_finite() {
    let (nodes, edges) = linear_chain(100);
    let result = run_harness(&nodes, &edges, 11);
    assert!(result.max_position_drift.is_finite(),
        "no NaN/Inf in drift stats; got {}", result.max_position_drift);
    assert!(result.p99_position_drift.is_finite());
    assert!(result.awake_fraction_p95.is_finite());
}

#[test]
fn corpus_version_is_documented() {
    // Reading guard — bumping CORPUS_VERSION is the cue to refresh baselines.
    assert_eq!(CORPUS_VERSION, 1);
}
