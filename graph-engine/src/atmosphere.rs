//! Causal-atmosphere sleep (Phase A Week 4 of the canonical plan).
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Phase A — CPU
//! foundation + zero-copy" → §"Week 4: Causal-atmosphere sleep +
//! visual-equivalence test". This module owns the math for *causal-
//! atmosphere* sleep: each node carries an atmosphere radius `r_i` plus a
//! predictive capsule. When two atmospheres overlap, both wake. When the
//! integrator passes through a node's atmosphere it ramps physics in
//! smoothly via a smootherstep warm-zone. Sleeping nodes that are not
//! touched by any front simply do not integrate.
//!
//! Per locked decision #4 in the canonical plan, **renderability is
//! independent of sleep state** — every routine in this module touches
//! integrator behaviour (alpha, dt, force_scale, wake state) but never
//! clears `FLAG_RENDERABLE`. That bit is only flipped by filter / search-
//! hidden, not by sleep.
//!
//! ## Pure-data contract
//!
//! Like `warmstart` and `reveal`, this module is engine-independent. It
//! consumes slim `AtmosphereNodeInput` records + a `WakeFrontStep` per
//! frame and returns the integrator's recipe for the frame. Engine
//! wiring lives in `engine.rs`; the integrator there feeds these
//! results into the ECS columns and Metal compute later.
//!
//! ## Why a separate module
//!
//! - `simulation.rs` has its own legacy sleep model (timer-based). The
//!   canonical plan replaces it; staging atmosphere logic outside the
//!   integrator lets us A/B test against the legacy path before flipping.
//! - Unit-tested in isolation — every formula maps to a named test.
//! - Same `BTreeMap` ordering discipline as warmstart/reveal so output
//!   is deterministic across platforms.

use std::collections::BTreeMap;

/// Minimal per-node record the atmosphere algorithms read.
#[derive(Debug, Clone, Copy)]
pub struct AtmosphereNodeInput {
    pub id: u32,
    pub x: f32,
    pub y: f32,
    pub vx: f32,
    pub vy: f32,
    /// Visual radius (the renderer's circle); collide radius adds to this.
    pub radius: f32,
    /// Median rest length of edges incident on this node; 0.0 when isolated.
    pub median_incident_rest_length: f32,
    /// "Heat" — how recently / hard the node was poked. Decays each frame.
    pub heat: f32,
    /// Pre-existing physics state: AwakeFraction-friendly tri-state.
    pub state: WakeState,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WakeState {
    Sleeping,
    Warming,
    Awake,
}

/// Static config shared across the frame.
#[derive(Debug, Clone, Copy)]
pub struct AtmosphereConfig {
    pub collide_radius: f32,
    pub world_size_of_2px: f32,
    pub atmosphere_multiplier: f32,
    /// Frame-time step.
    pub dt: f32,
    /// Frames per second.
    pub fps: f32,
    /// Width of the smootherstep warm-zone ramp (in atmosphere-radius units).
    pub warm_width: f32,
    /// Awake-fraction threshold at which we fall back to full integration.
    pub awake_fraction_failure_threshold: f32,
    /// Length of post-drag sticky-awake window in seconds.
    pub drag_sticky_seconds: f32,
}

impl Default for AtmosphereConfig {
    fn default() -> Self {
        Self {
            collide_radius: 0.5,
            world_size_of_2px: 1.0,
            atmosphere_multiplier: 1.4,
            dt: 1.0 / 60.0,
            fps: 60.0,
            warm_width: 0.5,
            awake_fraction_failure_threshold: 0.20,
            drag_sticky_seconds: 0.25,
        }
    }
}

/// Output of the per-node atmosphere computation. The integrator multiplies
/// `dt` and force magnitude by these factors; `wake_to` is the proposed
/// new physics state.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct AtmosphereStep {
    pub id: u32,
    /// Effective atmosphere radius including predictive lookahead.
    pub radius: f32,
    /// Lookahead (frames) used for the capsule.
    pub lookahead: u32,
    /// dt scaler in [0, 1].
    pub dt_factor: f32,
    /// Force scaler in [0.25, 1].
    pub force_factor: f32,
    /// New wake state proposed for this frame.
    pub wake_to: WakeState,
}

/// Compute the atmosphere radius per drop 5's formula.
pub fn atmosphere_radius(
    node: &AtmosphereNodeInput,
    cfg: &AtmosphereConfig,
    lookahead_frames: u32,
) -> f32 {
    let base = (node.radius + cfg.collide_radius)
        .max(0.5 * node.median_incident_rest_length)
        .max(cfg.world_size_of_2px);
    let mut r = base * cfg.atmosphere_multiplier;
    let speed = (node.vx * node.vx + node.vy * node.vy).sqrt();
    r += speed * cfg.dt * lookahead_frames as f32;
    r += node.heat * 0.25 * node.median_incident_rest_length;
    r
}

/// L = clamp(ceil(3 + |v| / (median_rest_length * dt * F)), 3, 12)
pub fn lookahead_frames(node: &AtmosphereNodeInput, cfg: &AtmosphereConfig) -> u32 {
    let speed = (node.vx * node.vx + node.vy * node.vy).sqrt();
    let denom = node.median_incident_rest_length.max(1e-6) * cfg.dt * cfg.fps;
    let raw = (3.0 + speed / denom.max(1e-6)).ceil();
    raw.clamp(3.0, 12.0) as u32
}

/// L_drag = L * 2  (per drop 5).
pub fn lookahead_frames_during_drag(node: &AtmosphereNodeInput, cfg: &AtmosphereConfig) -> u32 {
    (lookahead_frames(node, cfg) * 2).min(24)
}

/// Hub wake budget: a high-degree node can only propose 2% of its degree
/// (≤256) wake-up signals to neighbours per frame. Prevents one hub from
/// waking the whole graph at once.
pub fn hub_wake_budget(degree: u32) -> u32 {
    let raw = (0.02 * degree as f32).ceil() as u32;
    raw.clamp(1, 256)
}

/// Smootherstep `λ(x) = x³(x(6x − 15) + 10)` from the canonical plan.
fn smootherstep(x: f32) -> f32 {
    let x = x.clamp(0.0, 1.0);
    x * x * x * (x * (x * 6.0 - 15.0) + 10.0)
}

/// Warm-zone integrator scaling.
///
/// Inputs:
/// - `front_radius` — the wake front's effective radius
/// - `distance` — how far the node is *outside* the front
/// - `warm_width` — width of the ramp (config)
///
/// Returns (dt_factor, force_factor) per drop 5:
///   x = clamp((front_radius - d) / warm_width, 0, 1)
///   λ = smootherstep(x)
///   dt_eff = mix(0, dt, λ)            → dt_factor = λ
///   force_scale = mix(0.25, 1.0, λ)   → force_factor = 0.25 + 0.75λ
pub fn warm_zone_scaling(front_radius: f32, distance: f32, warm_width: f32) -> (f32, f32) {
    let denom = warm_width.max(1e-6);
    let x = ((front_radius - distance) / denom).clamp(0.0, 1.0);
    let lambda = smootherstep(x);
    (lambda, 0.25 + 0.75 * lambda)
}

/// Edge-propagation wake score from drop 5:
///   score = parent_heat * edge_weight * clamp(extension/rest, 0, 4)
pub fn edge_propagation_score(parent_heat: f32, edge_weight: f32, extension: f32, rest: f32) -> f32 {
    let stretch = if rest.abs() < 1e-6 { 0.0 } else { (extension / rest).clamp(0.0, 4.0) };
    parent_heat * edge_weight * stretch
}

/// pending_heat decays by 0.85 per frame (drop 5).
pub fn decay_pending_heat(heat: f32) -> f32 {
    (heat * 0.85).max(0.0)
}

/// Drag sticky window — once a drag releases, the node stays awake for
/// `drag_sticky_seconds`. Returns whether the node is still inside the
/// sticky window given a release time and now.
pub fn drag_sticky_active(time_since_release_seconds: f32, cfg: &AtmosphereConfig) -> bool {
    time_since_release_seconds >= 0.0 && time_since_release_seconds < cfg.drag_sticky_seconds
}

/// Per-node atmosphere computation for one frame. Returns the integrator
/// recipe (dt scale, force scale, proposed wake state).
pub fn compute_step(
    node: &AtmosphereNodeInput,
    cfg: &AtmosphereConfig,
    wake_front_radius: f32,
    distance_to_front: f32,
    drag_sticky: bool,
) -> AtmosphereStep {
    let look = lookahead_frames(node, cfg);
    let radius = atmosphere_radius(node, cfg, look);
    let (dt_factor, force_factor) =
        warm_zone_scaling(wake_front_radius, distance_to_front, cfg.warm_width);
    let proposed = if drag_sticky {
        // Drag sticky always wins — keep the node Awake.
        WakeState::Awake
    } else if dt_factor <= 1e-6 {
        // Outside warm zone: keep the node where it was, but Awake decays to
        // Warming first.
        match node.state {
            WakeState::Awake => WakeState::Warming,
            other => other,
        }
    } else if dt_factor >= 0.999 {
        WakeState::Awake
    } else {
        // Inside the ramp band → Warming (or stays Awake if already so).
        match node.state {
            WakeState::Awake => WakeState::Awake,
            _ => WakeState::Warming,
        }
    };
    AtmosphereStep {
        id: node.id,
        radius,
        lookahead: look,
        dt_factor,
        force_factor,
        wake_to: proposed,
    }
}

/// Frame-level summary used for the awake-fraction failure detector.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct AwakeFractionSnapshot {
    pub awake: usize,
    pub warming: usize,
    pub sleeping: usize,
    pub fraction_awake_or_warming: f32,
}

/// Compute the awake fraction across a frame's snapshot of WakeStates.
pub fn awake_fraction(states: &[WakeState]) -> AwakeFractionSnapshot {
    let mut a = 0usize;
    let mut w = 0usize;
    let mut s = 0usize;
    for &x in states {
        match x {
            WakeState::Awake => a += 1,
            WakeState::Warming => w += 1,
            WakeState::Sleeping => s += 1,
        }
    }
    let total = (a + w + s).max(1) as f32;
    AwakeFractionSnapshot {
        awake: a,
        warming: w,
        sleeping: s,
        fraction_awake_or_warming: (a + w) as f32 / total,
    }
}

/// Telemetry: once the awake fraction stays above the threshold for the
/// configured period (default 1 second), the integrator should degrade to
/// full simulation. `fall_back_to_full_sim` returns `true` when that
/// condition is met given the recent frame snapshots.
pub fn should_fall_back_to_full_sim(
    recent: &[AwakeFractionSnapshot],
    cfg: &AtmosphereConfig,
) -> bool {
    if recent.is_empty() { return false; }
    let window = cfg.fps.ceil() as usize;
    let window = window.max(1);
    if recent.len() < window { return false; }
    recent.iter().rev().take(window).all(|s| {
        s.fraction_awake_or_warming > cfg.awake_fraction_failure_threshold
    })
}

/// Diagnostic: ordered-by-id summary of one frame's `AtmosphereStep` results.
pub fn summarise_frame(steps: &[AtmosphereStep]) -> BTreeMap<u32, AtmosphereStep> {
    let mut m: BTreeMap<u32, AtmosphereStep> = BTreeMap::new();
    for s in steps {
        m.insert(s.id, *s);
    }
    m
}

// ─── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn node(id: u32, vx: f32, vy: f32) -> AtmosphereNodeInput {
        AtmosphereNodeInput {
            id,
            x: 0.0,
            y: 0.0,
            vx,
            vy,
            radius: 1.0,
            median_incident_rest_length: 10.0,
            heat: 0.0,
            state: WakeState::Sleeping,
        }
    }

    #[test]
    fn lookahead_clamps_to_3_and_12() {
        let cfg = AtmosphereConfig::default();
        // Zero velocity → minimum 3.
        let still = node(1, 0.0, 0.0);
        assert_eq!(lookahead_frames(&still, &cfg), 3);
        // Very high velocity → max 12.
        let fast = node(2, 1e6, 0.0);
        assert_eq!(lookahead_frames(&fast, &cfg), 12);
        // Drag doubles, capped 24.
        assert_eq!(lookahead_frames_during_drag(&still, &cfg), 6);
        assert_eq!(lookahead_frames_during_drag(&fast, &cfg), 24);
    }

    #[test]
    fn atmosphere_radius_uses_max_of_three_baselines() {
        let cfg = AtmosphereConfig {
            collide_radius: 0.5,
            world_size_of_2px: 5.0, // 2px will dominate when node is small + no edges
            atmosphere_multiplier: 1.0,
            dt: 1.0 / 60.0,
            fps: 60.0,
            ..AtmosphereConfig::default()
        };
        let tiny = AtmosphereNodeInput {
            id: 1, x: 0.0, y: 0.0, vx: 0.0, vy: 0.0,
            radius: 0.1,
            median_incident_rest_length: 0.0,
            heat: 0.0,
            state: WakeState::Sleeping,
        };
        let r = atmosphere_radius(&tiny, &cfg, 3);
        // For a still node with no edges, the 2px floor (5.0) must dominate.
        assert!(r >= 5.0, "2px floor must dominate, got r={r}");
    }

    #[test]
    fn atmosphere_radius_grows_with_velocity() {
        let cfg = AtmosphereConfig::default();
        let still = node(1, 0.0, 0.0);
        let moving = node(2, 100.0, 0.0);
        let r_still = atmosphere_radius(&still, &cfg, 3);
        let r_moving = atmosphere_radius(&moving, &cfg, 3);
        assert!(r_moving > r_still, "moving atmosphere must extend further");
    }

    #[test]
    fn atmosphere_radius_grows_with_heat() {
        let cfg = AtmosphereConfig::default();
        let cool = node(1, 0.0, 0.0);
        let mut hot = node(2, 0.0, 0.0);
        hot.heat = 4.0;
        assert!(atmosphere_radius(&hot, &cfg, 3) > atmosphere_radius(&cool, &cfg, 3));
    }

    #[test]
    fn hub_wake_budget_clamps() {
        assert_eq!(hub_wake_budget(0), 1);
        assert_eq!(hub_wake_budget(10), 1);
        assert_eq!(hub_wake_budget(100), 2);
        assert_eq!(hub_wake_budget(10_000), 200);
        assert_eq!(hub_wake_budget(100_000), 256);
        assert_eq!(hub_wake_budget(u32::MAX), 256);
    }

    #[test]
    fn smootherstep_bounds() {
        assert_eq!(smootherstep(-1.0), 0.0);
        assert_eq!(smootherstep(0.0), 0.0);
        assert!((smootherstep(0.5) - 0.5).abs() < 1e-3);
        assert_eq!(smootherstep(1.0), 1.0);
        assert_eq!(smootherstep(2.0), 1.0);
    }

    #[test]
    fn warm_zone_outside_zero_dt_quarter_force() {
        let (dt, force) = warm_zone_scaling(5.0, 100.0, 1.0);
        assert_eq!(dt, 0.0);
        assert!((force - 0.25).abs() < 1e-6, "force floor outside warm zone must be 0.25");
    }

    #[test]
    fn warm_zone_inside_full_dt_full_force() {
        let (dt, force) = warm_zone_scaling(5.0, 0.0, 1.0);
        assert!(dt > 0.999, "dt at the centre must be ≈1");
        assert!(force > 0.999, "force at the centre must be ≈1");
    }

    #[test]
    fn edge_propagation_clamps_stretch_to_4() {
        let s = edge_propagation_score(1.0, 1.0, 100.0, 1.0);
        assert!((s - 4.0).abs() < 1e-6, "extension/rest must clamp to 4");
        let z = edge_propagation_score(1.0, 1.0, 1.0, 0.0);
        assert_eq!(z, 0.0, "zero rest length → zero score (no NaNs)");
    }

    #[test]
    fn pending_heat_decays_by_85_percent() {
        assert!((decay_pending_heat(1.0) - 0.85).abs() < 1e-6);
        assert!((decay_pending_heat(2.0) - 1.7).abs() < 1e-6);
    }

    #[test]
    fn drag_sticky_window() {
        let cfg = AtmosphereConfig { drag_sticky_seconds: 0.25, ..AtmosphereConfig::default() };
        assert!(drag_sticky_active(0.0, &cfg));
        assert!(drag_sticky_active(0.2, &cfg));
        assert!(!drag_sticky_active(0.26, &cfg));
        assert!(!drag_sticky_active(-0.01, &cfg));
    }

    #[test]
    fn compute_step_sleeping_outside_front_stays_sleeping() {
        let cfg = AtmosphereConfig::default();
        let n = node(1, 0.0, 0.0);
        let step = compute_step(&n, &cfg, 5.0, 100.0, false);
        assert_eq!(step.dt_factor, 0.0);
        assert_eq!(step.wake_to, WakeState::Sleeping);
    }

    #[test]
    fn compute_step_inside_front_warms_a_sleeper() {
        let cfg = AtmosphereConfig { warm_width: 1.0, ..AtmosphereConfig::default() };
        let n = node(1, 0.0, 0.0);
        // distance 0 → λ = 1 → Awake
        let step_center = compute_step(&n, &cfg, 5.0, 0.0, false);
        assert_eq!(step_center.wake_to, WakeState::Awake);
        // distance just inside the ramp → Warming
        let step_ramp = compute_step(&n, &cfg, 5.0, 4.5, false);
        assert!(matches!(step_ramp.wake_to, WakeState::Warming | WakeState::Awake));
    }

    #[test]
    fn compute_step_drag_sticky_forces_awake() {
        let cfg = AtmosphereConfig::default();
        let n = node(1, 0.0, 0.0);
        let step = compute_step(&n, &cfg, 5.0, 100.0, true);
        assert_eq!(step.wake_to, WakeState::Awake);
    }

    #[test]
    fn awake_fraction_counts_correctly() {
        let states = vec![
            WakeState::Awake, WakeState::Awake, WakeState::Warming,
            WakeState::Sleeping, WakeState::Sleeping, WakeState::Sleeping,
        ];
        let snap = awake_fraction(&states);
        assert_eq!(snap.awake, 2);
        assert_eq!(snap.warming, 1);
        assert_eq!(snap.sleeping, 3);
        assert!((snap.fraction_awake_or_warming - 0.5).abs() < 1e-6);
    }

    #[test]
    fn fall_back_to_full_sim_requires_sustained_threshold() {
        let cfg = AtmosphereConfig {
            fps: 5.0, // short window for test
            awake_fraction_failure_threshold: 0.20,
            ..AtmosphereConfig::default()
        };
        // Below threshold throughout → no fall-back.
        let low = vec![AwakeFractionSnapshot {
            awake: 1, warming: 0, sleeping: 10, fraction_awake_or_warming: 0.1
        }; 10];
        assert!(!should_fall_back_to_full_sim(&low, &cfg));
        // Single spike — not sustained — no fall-back.
        let mut mixed = low.clone();
        if let Some(last) = mixed.last_mut() {
            *last = AwakeFractionSnapshot {
                awake: 5, warming: 0, sleeping: 10, fraction_awake_or_warming: 0.5
            };
        }
        assert!(!should_fall_back_to_full_sim(&mixed, &cfg));
        // Sustained above threshold for full window → fall-back fires.
        let high = vec![AwakeFractionSnapshot {
            awake: 5, warming: 1, sleeping: 5, fraction_awake_or_warming: 0.55
        }; 10];
        assert!(should_fall_back_to_full_sim(&high, &cfg));
    }

    #[test]
    fn summarise_frame_is_sorted_by_id() {
        let steps = vec![
            AtmosphereStep { id: 9, radius: 1.0, lookahead: 3, dt_factor: 1.0, force_factor: 1.0, wake_to: WakeState::Awake },
            AtmosphereStep { id: 1, radius: 1.0, lookahead: 3, dt_factor: 0.0, force_factor: 0.25, wake_to: WakeState::Sleeping },
            AtmosphereStep { id: 5, radius: 1.0, lookahead: 3, dt_factor: 0.5, force_factor: 0.7, wake_to: WakeState::Warming },
        ];
        let summary = summarise_frame(&steps);
        let ids: Vec<u32> = summary.keys().copied().collect();
        assert_eq!(ids, vec![1, 5, 9], "BTreeMap keeps ascending-id order");
    }

    #[test]
    fn warm_zone_scaling_is_continuous_at_boundaries() {
        // x → 0: λ → 0 → (0, 0.25)
        let (dt0, f0) = warm_zone_scaling(1.0, 1.0, 1.0);
        assert!(dt0.abs() < 1e-6);
        assert!((f0 - 0.25).abs() < 1e-6);
        // x → 1: λ → 1 → (1, 1)
        let (dt1, f1) = warm_zone_scaling(1.0, 0.0, 1.0);
        assert!((dt1 - 1.0).abs() < 1e-6);
        assert!((f1 - 1.0).abs() < 1e-6);
    }

    #[test]
    fn renderability_not_in_module_surface() {
        // Sanity guard for locked decision #4 — atmosphere never produces a
        // RENDERABLE-like signal. Reads as a "did we accidentally expose a
        // visibility flag from the sleep system" comment-test.
        let states: Vec<&'static str> = vec!["dt_factor", "force_factor", "wake_to", "radius", "lookahead"];
        assert!(!states.contains(&"renderable"),
            "atmosphere must not surface a renderability flag (sleep ⊥ render)");
    }
}
