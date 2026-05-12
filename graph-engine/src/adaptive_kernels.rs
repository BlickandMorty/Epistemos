//! Phase B Week 5-6 compute-kernel reference: FA2 adaptive speed +
//! wake-front propagation.
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Phase B —
//! Metal compute (8 weeks)" → §"Week 5-6: FA2 adaptive speed + GPU
//! sleep". The plan calls for two `.metal` files:
//!
//!   adaptive_speed.metal   — FA2 (ForceAtlas2) global-speed schedule
//!   wake_propagation.metal — wake-front sphere expansion + smootherstep warm zone
//!
//! Both are reductions: adaptive_speed sums per-node swing + traction
//! into globals, wake_propagation walks edges to extend the wake front.
//! The CPU reference here ships the algorithm; the MSL pass is a
//! threadgroup-reduce translation.
//!
//! ## FA2 reference
//!
//! Drop 6 verbatim:
//!   swing(i)    = length(F - F_prev)
//!   traction(i) = 0.5 * length(F + F_prev)
//!   global_swing    = sum of per-node swing
//!   global_traction = sum of per-node traction
//!   tolerance       = tol(N) — Gephi's three-bucket schedule by node count
//!     0.1  if N <   500
//!     1.0  if N <  5000
//!     10.0 otherwise
//!   global_speed = tol(N) * global_traction / max(global_swing, eps)
//!   multiply by reveal alpha_target so phases cooperate
//!
//! ## Wake propagation reference
//!
//! Per drop 5: wake fronts expand at `v_max * dt` per frame. A sleeping
//! node enters Warming when an expanding front overlaps its atmosphere
//! capsule, and the smootherstep warm-zone scaling (from `atmosphere`)
//! controls the integrator dt as the front passes.
//!
//! ## Determinism contract
//!
//! Same input arrays → bit-identical output. Tested via
//! `*_is_deterministic` per kernel.

/// Bucket schedule from Gephi's FA2 — drop 6 verbatim.
pub fn fa2_tolerance(node_count: usize) -> f32 {
    if node_count < 500 { 0.1 }
    else if node_count < 5_000 { 1.0 }
    else { 10.0 }
}

/// Per-node swing and traction → global reduce.
///
/// Returns `(global_swing, global_traction)` for the FA2 speed formula.
/// Mirrors the threadgroup-reduce pattern in adaptive_speed.metal:
/// each threadgroup sums its slice locally, then a final pass folds
/// into a single global value.
pub fn fa2_swing_traction(
    force_x: &[f32],
    force_y: &[f32],
    prev_force_x: &[f32],
    prev_force_y: &[f32],
) -> (f32, f32) {
    let n = force_x.len().min(force_y.len())
        .min(prev_force_x.len()).min(prev_force_y.len());
    let mut global_swing = 0.0_f32;
    let mut global_traction = 0.0_f32;
    for i in 0..n {
        let dfx = force_x[i] - prev_force_x[i];
        let dfy = force_y[i] - prev_force_y[i];
        let sfx = force_x[i] + prev_force_x[i];
        let sfy = force_y[i] + prev_force_y[i];
        let swing = (dfx * dfx + dfy * dfy).sqrt();
        let traction = 0.5 * (sfx * sfx + sfy * sfy).sqrt();
        global_swing += swing;
        global_traction += traction;
    }
    (global_swing, global_traction)
}

/// FA2 global speed: tol * traction / max(swing, ε), then multiply by
/// reveal `alpha_target` so the controller's alpha schedule co-operates
/// with the FA2 schedule.
pub fn fa2_global_speed(
    global_swing: f32,
    global_traction: f32,
    node_count: usize,
    alpha_target: f32,
) -> f32 {
    let tol = fa2_tolerance(node_count);
    let base = tol * global_traction / global_swing.max(1e-6);
    base * alpha_target.max(0.0)
}

/// Wake-front state. Each front carries a centre, growing radius, and a
/// max-velocity it expands at per frame. Multiple fronts can coexist
/// (user click + drag + search pulse) — the merger logic is the caller's.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct WakeFront {
    pub centre_x: f32,
    pub centre_y: f32,
    pub radius: f32,
    pub max_radius: f32,
    /// World units / frame.
    pub expansion_rate: f32,
}

impl WakeFront {
    /// Step the front forward one frame.
    pub fn advance(&mut self) {
        self.radius = (self.radius + self.expansion_rate).min(self.max_radius);
    }

    /// Has the front saturated (reached max_radius)?
    pub fn is_saturated(&self) -> bool {
        self.radius >= self.max_radius
    }
}

/// Per-frame wake-propagation step: advance all fronts, then test each
/// (node, front) pair for overlap. Nodes whose atmosphere overlaps a
/// front receive a wake signal (returned as `wake_mask[i] = true`).
///
/// This mirrors the wake_propagation.metal pattern: one thread per
/// node, walks all active fronts (small, typically ≤ 8), short-circuits
/// on saturated fronts that have already covered the world.
pub fn wake_propagation_step(
    fronts: &mut [WakeFront],
    pos_x: &[f32],
    pos_y: &[f32],
    atmosphere_radii: &[f32],
    wake_mask: &mut [bool],
) {
    for f in fronts.iter_mut() {
        f.advance();
    }
    let n = pos_x.len().min(pos_y.len()).min(atmosphere_radii.len()).min(wake_mask.len());
    for i in 0..n {
        let mut signalled = false;
        let r = atmosphere_radii[i];
        for f in fronts.iter() {
            let dx = pos_x[i] - f.centre_x;
            let dy = pos_y[i] - f.centre_y;
            let dist = (dx * dx + dy * dy).sqrt();
            // Wake when the atmosphere capsule overlaps the front sphere.
            if dist < (f.radius + r) {
                signalled = true;
                break;
            }
        }
        wake_mask[i] = signalled;
    }
}

/// K-frame threshold for sleep transitions per drop 5: a node must
/// stay "calm" (velocity below `SLEEP_VELOCITY_THRESHOLD`) for this many
/// consecutive frames before being eligible for `Sleeping`. The plan
/// pins these at 24 @ 120Hz and 12 @ 60Hz.
pub fn k_frame_threshold(fps: f32) -> u32 {
    if fps >= 100.0 { 24 } else { 12 }
}

/// Default velocity floor for the sleep counter — kept for backward
/// compatibility with existing call sites + tests. Production callers
/// should compute the canonical threshold via `sleep_velocity_threshold`
/// per canonical-plan locked decision #20.
pub const SLEEP_VELOCITY_THRESHOLD: f32 = 5e-3;

/// Canonical sleep velocity threshold per
/// `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Locked
/// architectural decisions" #20:
///
/// > Sleep velocity threshold: `|v| < 0.002 * ideal_edge_length_per_frame`
///
/// `ideal_edge_length` is the spring rest length (typically 30 in
/// production). `fps` is the frame rate the integrator is running at.
/// The product gives "how far an edge-length-sized translation moves
/// per frame at the current frame rate"; multiplying by 0.002 gives the
/// per-frame velocity below which a node counts as calm.
pub fn sleep_velocity_threshold(ideal_edge_length: f32, fps: f32) -> f32 {
    let edge_per_frame = ideal_edge_length / fps.max(1.0);
    0.002 * edge_per_frame
}

/// Canonical sleep force threshold per
/// `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Locked
/// architectural decisions" #21:
///
/// > Sleep force threshold: `|F| < 0.01 * repulsion_scale`
///
/// `repulsion_scale` is the integrator's repulsion strength constant
/// (the magnitude factor passed to `repulsion_kernel`). The product
/// gives the force magnitude below which a node's residual force
/// counts as negligible.
pub fn sleep_force_threshold(repulsion_scale: f32) -> f32 {
    0.01 * repulsion_scale
}

/// Per canonical-plan §"Locked architectural decisions" #5:
///
/// > Sleep activation: Disabled globally until Steady phase
///
/// During Idle / Seeding / Ramping / Settling phases, NO node should be
/// put to sleep, even if it would otherwise satisfy the velocity +
/// force thresholds. This prevents a premature-sleep pathology where
/// nodes that are momentarily quiet during the reveal animation get
/// stuck in `Sleeping` and never integrate the rest of the reveal.
///
/// The check takes a `RevealPhase` (from `crate::reveal::RevealPhase`)
/// and returns `true` only when sleep is globally enabled (Steady).
pub fn sleep_globally_enabled(phase: crate::reveal::RevealPhase) -> bool {
    use crate::reveal::RevealPhase;
    matches!(phase, RevealPhase::Steady)
}

/// Apply the canonical-plan decision #5 phase gate to a slice of
/// sleep proposals from `sleep_update_kernel*`. Caller invokes this
/// AFTER the kernel populates `propose_sleep` and BEFORE the integrator
/// flips `FLAG_SLEEPING` bits. When sleep is globally disabled, all
/// proposals are cleared.
///
/// This is a separate post-pass (rather than baked into the kernel
/// signature) because the canonical pipeline runs sleep_update inside
/// the GPU kernel — phase state lives on CPU, and we drop the gate
/// in CPU-side post-processing before propagating to the flag mask.
pub fn apply_sleep_phase_gate(
    propose_sleep: &mut [bool],
    phase: crate::reveal::RevealPhase,
) {
    if !sleep_globally_enabled(phase) {
        for p in propose_sleep.iter_mut() {
            *p = false;
        }
    }
}

/// Sleep-update kernel reference. Mirror of `sleep_update.metal`.
///
/// For each node:
/// - If `|v|² < velocity_threshold²` AND `|F|² < force_threshold²`,
///   increment `calm_frame_count[i]`
/// - Otherwise reset `calm_frame_count[i] = 0`
/// - When `calm_frame_count[i] >= k_threshold`, set `propose_sleep[i] = true`
///   (caller decides whether to flip the FLAG_SLEEPING bit — atmosphere
///   may override per drag-sticky + wake-front rules)
///
/// Per canonical-plan decisions #20 + #21, BOTH the velocity AND the
/// force must be sub-threshold for a node to count as calm. A node
/// that's moving slowly but still being pushed isn't ready to sleep.
///
/// The kernel does NOT directly mutate flags — that's the integrator's
/// job once it merges all sleep proposals with the atmosphere
/// wake-overrides.
///
/// Backward compatibility: when `force_x`/`force_y` are `None`, only
/// the velocity gate is applied (matches the iteration-3 behaviour).
#[allow(clippy::too_many_arguments)]
pub fn sleep_update_kernel(
    vel_x: &[f32],
    vel_y: &[f32],
    calm_frame_count: &mut [u32],
    propose_sleep: &mut [bool],
    k_threshold: u32,
) {
    sleep_update_kernel_with_force_gate(
        vel_x, vel_y,
        None, None,
        calm_frame_count, propose_sleep,
        k_threshold,
        SLEEP_VELOCITY_THRESHOLD,
        f32::INFINITY, // disable force gate (any force passes)
    );
}

/// Extended sleep-update kernel that gates on BOTH velocity AND force
/// per canonical-plan decisions #20 + #21. Production code should use
/// this; `sleep_update_kernel` is kept for backward compatibility with
/// callers that only have velocity data.
#[allow(clippy::too_many_arguments)]
pub fn sleep_update_kernel_with_force_gate(
    vel_x: &[f32],
    vel_y: &[f32],
    force_x: Option<&[f32]>,
    force_y: Option<&[f32]>,
    calm_frame_count: &mut [u32],
    propose_sleep: &mut [bool],
    k_threshold: u32,
    velocity_threshold: f32,
    force_threshold: f32,
) {
    let n = vel_x.len()
        .min(vel_y.len()).min(calm_frame_count.len()).min(propose_sleep.len());
    let v_thresh_sq = velocity_threshold * velocity_threshold;
    let f_thresh_sq = force_threshold * force_threshold;
    for i in 0..n {
        let speed_sq = vel_x[i] * vel_x[i] + vel_y[i] * vel_y[i];
        let v_calm = speed_sq < v_thresh_sq;
        let f_calm = match (force_x, force_y) {
            (Some(fx), Some(fy)) if i < fx.len() && i < fy.len() => {
                let f_sq = fx[i] * fx[i] + fy[i] * fy[i];
                f_sq < f_thresh_sq
            }
            _ => true, // no force data → force gate passes (legacy behaviour)
        };
        if v_calm && f_calm {
            calm_frame_count[i] = calm_frame_count[i].saturating_add(1);
        } else {
            calm_frame_count[i] = 0;
        }
        propose_sleep[i] = calm_frame_count[i] >= k_threshold;
    }
}

/// Helper — distance from a point to a wake front centre (used by tests
/// + telemetry; the kernels above compute their own distances inline).
pub fn distance_to_front(pos_x: f32, pos_y: f32, front: &WakeFront) -> f32 {
    let dx = pos_x - front.centre_x;
    let dy = pos_y - front.centre_y;
    (dx * dx + dy * dy).sqrt()
}

// ─── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fa2_tolerance_bucket_thresholds() {
        assert_eq!(fa2_tolerance(0), 0.1);
        assert_eq!(fa2_tolerance(499), 0.1);
        assert_eq!(fa2_tolerance(500), 1.0);
        assert_eq!(fa2_tolerance(4_999), 1.0);
        assert_eq!(fa2_tolerance(5_000), 10.0);
        assert_eq!(fa2_tolerance(1_000_000), 10.0);
    }

    #[test]
    fn fa2_swing_zero_when_forces_unchanged() {
        let fx = vec![1.0_f32, 2.0, 3.0];
        let fy = vec![1.0_f32, 2.0, 3.0];
        let (swing, traction) = fa2_swing_traction(&fx, &fy, &fx, &fy);
        assert!(swing.abs() < 1e-6, "swing zero when forces are stable");
        assert!(traction > 0.0, "traction > 0 when force magnitudes are non-zero");
    }

    #[test]
    fn fa2_swing_grows_when_force_flips() {
        let fx = vec![10.0_f32, 0.0];
        let fy = vec![0.0_f32, 0.0];
        let prev_fx = vec![-10.0_f32, 0.0];
        let prev_fy = vec![0.0_f32, 0.0];
        let (swing, traction) = fa2_swing_traction(&fx, &fy, &prev_fx, &prev_fy);
        // Sign flip → max swing.
        assert!(swing > 19.0 && swing < 21.0, "swing ≈ |F - F_prev| = 20, got {}", swing);
        // F + F_prev = (0, 0) → traction = 0.
        assert!(traction.abs() < 1e-6);
    }

    #[test]
    fn fa2_global_speed_alpha_zero_short_circuits() {
        let speed = fa2_global_speed(5.0, 10.0, 1000, 0.0);
        assert_eq!(speed, 0.0);
    }

    #[test]
    fn fa2_global_speed_growls_with_traction() {
        let s1 = fa2_global_speed(5.0, 10.0, 1000, 1.0);
        let s2 = fa2_global_speed(5.0, 50.0, 1000, 1.0);
        assert!(s2 > s1, "speed must scale with traction");
    }

    #[test]
    fn fa2_global_speed_drops_with_high_swing() {
        let s1 = fa2_global_speed(5.0, 10.0, 1000, 1.0);
        let s2 = fa2_global_speed(50.0, 10.0, 1000, 1.0);
        assert!(s2 < s1, "speed must drop when swing is high");
    }

    #[test]
    fn fa2_global_speed_protects_against_zero_swing() {
        // Division by zero would NaN out the integrator; assert finite output.
        let s = fa2_global_speed(0.0, 10.0, 1000, 1.0);
        assert!(s.is_finite(), "zero swing must not produce NaN, got {}", s);
    }

    #[test]
    fn wake_front_advances_at_expansion_rate() {
        let mut f = WakeFront {
            centre_x: 0.0, centre_y: 0.0, radius: 0.0,
            max_radius: 100.0, expansion_rate: 5.0,
        };
        f.advance();
        assert_eq!(f.radius, 5.0);
        f.advance();
        assert_eq!(f.radius, 10.0);
    }

    #[test]
    fn wake_front_saturates_at_max_radius() {
        let mut f = WakeFront {
            centre_x: 0.0, centre_y: 0.0, radius: 99.0,
            max_radius: 100.0, expansion_rate: 5.0,
        };
        f.advance();
        assert_eq!(f.radius, 100.0);
        assert!(f.is_saturated());
        f.advance();
        assert_eq!(f.radius, 100.0, "saturated front does not exceed max_radius");
    }

    #[test]
    fn wake_propagation_signals_overlapping_nodes() {
        let mut fronts = vec![WakeFront {
            centre_x: 0.0, centre_y: 0.0, radius: 4.0,
            max_radius: 100.0, expansion_rate: 1.0,
        }];
        let pos_x = vec![3.0_f32, 50.0, 0.0];
        let pos_y = vec![0.0_f32, 0.0, 50.0];
        let atmosphere_radii = vec![1.0_f32, 1.0, 1.0];
        let mut mask = vec![false; 3];
        wake_propagation_step(&mut fronts, &pos_x, &pos_y, &atmosphere_radii, &mut mask);
        // Front advanced to radius 5; node 0 at dist 3 with r=1 overlaps. Node 1 at dist 50 doesn't.
        assert!(mask[0], "node within reach must wake");
        assert!(!mask[1], "node far away must stay asleep");
        assert!(!mask[2]);
    }

    #[test]
    fn wake_propagation_no_fronts_no_signals() {
        let mut fronts: Vec<WakeFront> = vec![];
        let pos_x = vec![0.0_f32, 1.0, 2.0];
        let pos_y = vec![0.0_f32, 0.0, 0.0];
        let atmosphere_radii = vec![1.0_f32; 3];
        let mut mask = vec![true; 3]; // pre-set to true; kernel must reset.
        wake_propagation_step(&mut fronts, &pos_x, &pos_y, &atmosphere_radii, &mut mask);
        for &m in &mask {
            assert!(!m, "no fronts → no signals");
        }
    }

    #[test]
    fn wake_propagation_multi_front_or_logic() {
        // Two fronts: one wakes node 0, the other wakes node 1.
        let mut fronts = vec![
            WakeFront { centre_x: 0.0, centre_y: 0.0, radius: 1.5,
                        max_radius: 100.0, expansion_rate: 0.0 },
            WakeFront { centre_x: 10.0, centre_y: 0.0, radius: 1.5,
                        max_radius: 100.0, expansion_rate: 0.0 },
        ];
        let pos_x = vec![0.5_f32, 9.5, 100.0];
        let pos_y = vec![0.0_f32, 0.0, 0.0];
        let atmosphere_radii = vec![1.0_f32; 3];
        let mut mask = vec![false; 3];
        wake_propagation_step(&mut fronts, &pos_x, &pos_y, &atmosphere_radii, &mut mask);
        assert!(mask[0]);
        assert!(mask[1]);
        assert!(!mask[2], "node far from both fronts stays asleep");
    }

    #[test]
    fn wake_propagation_is_deterministic() {
        let mut a = vec![WakeFront {
            centre_x: 1.0, centre_y: 1.0, radius: 2.0,
            max_radius: 100.0, expansion_rate: 1.0,
        }];
        let mut b = a.clone();
        let pos_x = vec![0.0_f32, 10.0, 20.0];
        let pos_y = vec![0.0_f32, 0.0, 0.0];
        let r = vec![1.5_f32; 3];
        let mut mask_a = vec![false; 3];
        let mut mask_b = vec![false; 3];
        wake_propagation_step(&mut a, &pos_x, &pos_y, &r, &mut mask_a);
        wake_propagation_step(&mut b, &pos_x, &pos_y, &r, &mut mask_b);
        assert_eq!(mask_a, mask_b);
        assert_eq!(a[0].radius, b[0].radius);
    }

    #[test]
    fn distance_to_front_is_euclidean() {
        let f = WakeFront {
            centre_x: 3.0, centre_y: 4.0, radius: 0.0,
            max_radius: 10.0, expansion_rate: 1.0,
        };
        let d = distance_to_front(0.0, 0.0, &f);
        assert!((d - 5.0).abs() < 1e-6);
    }

    #[test]
    fn k_frame_threshold_matches_canonical_table() {
        // 24 @ 120Hz, 12 @ 60Hz per drop 5.
        assert_eq!(k_frame_threshold(120.0), 24);
        assert_eq!(k_frame_threshold(100.0), 24);
        assert_eq!(k_frame_threshold(60.0), 12);
        assert_eq!(k_frame_threshold(30.0), 12);
    }

    #[test]
    fn sleep_update_increments_calm_counter_when_still() {
        let vx = vec![0.0_f32, 0.0, 0.0];
        let vy = vec![0.0_f32, 0.0, 0.0];
        let mut counts = vec![0u32; 3];
        let mut propose = vec![false; 3];
        sleep_update_kernel(&vx, &vy, &mut counts, &mut propose, 12);
        assert_eq!(counts, vec![1, 1, 1]);
        assert!(propose.iter().all(|&p| !p), "1 < 12 → no proposal yet");
    }

    #[test]
    fn sleep_update_resets_counter_when_moving() {
        let vx = vec![0.0_f32, 100.0];
        let vy = vec![0.0_f32, 0.0];
        let mut counts = vec![5u32, 5];
        let mut propose = vec![false; 2];
        sleep_update_kernel(&vx, &vy, &mut counts, &mut propose, 12);
        assert_eq!(counts[0], 6, "still node keeps counting up");
        assert_eq!(counts[1], 0, "moving node resets");
        assert!(!propose[0]);
        assert!(!propose[1]);
    }

    #[test]
    fn sleep_update_proposes_at_threshold() {
        let vx = vec![0.0_f32];
        let vy = vec![0.0_f32];
        let mut counts = vec![11u32]; // one short of threshold 12
        let mut propose = vec![false];
        sleep_update_kernel(&vx, &vy, &mut counts, &mut propose, 12);
        // 11+1 = 12 → propose
        assert_eq!(counts, vec![12]);
        assert!(propose[0]);
    }

    #[test]
    fn sleep_update_proposes_past_threshold() {
        let vx = vec![0.0_f32];
        let vy = vec![0.0_f32];
        let mut counts = vec![100u32]; // already past
        let mut propose = vec![false];
        sleep_update_kernel(&vx, &vy, &mut counts, &mut propose, 12);
        assert!(propose[0]);
        assert_eq!(counts, vec![101]);
    }

    #[test]
    fn sleep_update_floor_excludes_fp_noise() {
        // Tiny FP noise must not reset the counter.
        let vx = vec![1e-4_f32];
        let vy = vec![1e-4_f32];
        let mut counts = vec![5u32];
        let mut propose = vec![false];
        sleep_update_kernel(&vx, &vy, &mut counts, &mut propose, 12);
        assert_eq!(counts[0], 6, "sub-threshold velocity counts as calm");
    }

    #[test]
    fn sleep_velocity_threshold_matches_canonical_decision_20() {
        // |v| < 0.002 * ideal_edge_length_per_frame
        // ideal_edge_length=30, fps=60 → edge_per_frame = 0.5 → threshold = 0.001
        let t = sleep_velocity_threshold(30.0, 60.0);
        assert!((t - 0.001).abs() < 1e-9, "30/60 case should give 0.001, got {}", t);

        // 120Hz tighter threshold
        let t120 = sleep_velocity_threshold(30.0, 120.0);
        assert!(t120 < t, "120Hz threshold tighter than 60Hz; got {} vs {}", t120, t);

        // Fps clamps to 1 floor
        let t_low = sleep_velocity_threshold(30.0, 0.0);
        assert!(t_low.is_finite() && t_low > 0.0);
    }

    #[test]
    fn sleep_force_threshold_matches_canonical_decision_21() {
        // |F| < 0.01 * repulsion_scale
        assert_eq!(sleep_force_threshold(100.0), 1.0);
        assert_eq!(sleep_force_threshold(50.0), 0.5);
        assert_eq!(sleep_force_threshold(0.0), 0.0);
    }

    #[test]
    fn sleep_update_with_force_gate_velocity_only_calm() {
        // Velocity calm, force HIGH → not calm.
        let vx = vec![0.0_f32];
        let vy = vec![0.0_f32];
        let fx = vec![100.0_f32]; // force well above threshold 1.0
        let fy = vec![0.0_f32];
        let mut counts = vec![0u32];
        let mut propose = vec![false];
        sleep_update_kernel_with_force_gate(
            &vx, &vy, Some(&fx), Some(&fy),
            &mut counts, &mut propose, 12,
            0.001, 1.0, // canonical thresholds
        );
        assert_eq!(counts[0], 0, "high force resets counter despite low velocity");
        assert!(!propose[0]);
    }

    #[test]
    fn sleep_update_with_force_gate_both_calm() {
        let vx = vec![0.0_f32];
        let vy = vec![0.0_f32];
        let fx = vec![0.001_f32]; // sub-threshold
        let fy = vec![0.0_f32];
        let mut counts = vec![11u32]; // one short of threshold
        let mut propose = vec![false];
        sleep_update_kernel_with_force_gate(
            &vx, &vy, Some(&fx), Some(&fy),
            &mut counts, &mut propose, 12,
            0.001, 1.0,
        );
        assert_eq!(counts[0], 12);
        assert!(propose[0], "both velocity + force calm at threshold → propose sleep");
    }

    #[test]
    fn sleep_update_with_no_force_data_is_velocity_only() {
        // Legacy behaviour: when force data is None, only velocity gate applies.
        let vx = vec![0.0_f32];
        let vy = vec![0.0_f32];
        let mut counts = vec![0u32];
        let mut propose = vec![false];
        sleep_update_kernel_with_force_gate(
            &vx, &vy, None, None,
            &mut counts, &mut propose, 12,
            0.001, 1.0,
        );
        assert_eq!(counts[0], 1);
    }

    #[test]
    fn sleep_globally_enabled_only_in_steady_phase() {
        use crate::reveal::RevealPhase;
        assert!(!sleep_globally_enabled(RevealPhase::Idle));
        assert!(!sleep_globally_enabled(RevealPhase::Seeding));
        assert!(!sleep_globally_enabled(RevealPhase::Ramping));
        assert!(!sleep_globally_enabled(RevealPhase::Settling));
        assert!(sleep_globally_enabled(RevealPhase::Steady));
    }

    #[test]
    fn apply_sleep_phase_gate_clears_proposals_pre_steady() {
        use crate::reveal::RevealPhase;
        let mut proposals = vec![true, true, false, true];
        apply_sleep_phase_gate(&mut proposals, RevealPhase::Ramping);
        // All cleared — sleep disabled during Ramping per decision #5.
        assert_eq!(proposals, vec![false, false, false, false]);
    }

    #[test]
    fn apply_sleep_phase_gate_passes_proposals_through_in_steady() {
        use crate::reveal::RevealPhase;
        let mut proposals = vec![true, false, true, true, false];
        apply_sleep_phase_gate(&mut proposals, RevealPhase::Steady);
        // Unchanged — sleep is globally enabled in Steady.
        assert_eq!(proposals, vec![true, false, true, true, false]);
    }

    #[test]
    fn apply_sleep_phase_gate_short_circuits_in_seeding() {
        // Even if every node is calm, NO sleep proposal survives during
        // Seeding. Important: a node that's calm at frame 0 (because the
        // reveal hasn't dropped it yet) must not get marked Sleeping
        // before it ever gets a chance to integrate.
        use crate::reveal::RevealPhase;
        let mut proposals = vec![true; 100];
        apply_sleep_phase_gate(&mut proposals, RevealPhase::Seeding);
        assert!(proposals.iter().all(|&p| !p));
    }

    #[test]
    fn sleep_update_saturates_at_u32_max() {
        let vx = vec![0.0_f32];
        let vy = vec![0.0_f32];
        let mut counts = vec![u32::MAX];
        let mut propose = vec![false];
        sleep_update_kernel(&vx, &vy, &mut counts, &mut propose, 12);
        // saturating_add prevents wrap.
        assert_eq!(counts, vec![u32::MAX]);
        assert!(propose[0]);
    }
}
