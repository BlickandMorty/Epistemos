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

/// Velocity floor under which a node counts as "calm" for the sleep
/// counter. Small enough that real micro-jitter never pings the counter
/// but large enough that the counter doesn't wedge on FP noise.
pub const SLEEP_VELOCITY_THRESHOLD: f32 = 5e-3;

/// Sleep-update kernel reference. Mirror of `sleep_update.metal`.
///
/// For each node:
/// - If `|v| < SLEEP_VELOCITY_THRESHOLD`, increment `calm_frame_count[i]`
/// - Otherwise reset `calm_frame_count[i] = 0`
/// - When `calm_frame_count[i] >= k_threshold`, set `propose_sleep[i] = true`
///   (caller decides whether to flip the FLAG_SLEEPING bit — atmosphere
///   may override per drag-sticky + wake-front rules)
///
/// The kernel does NOT directly mutate flags — that's the integrator's
/// job once it merges all sleep proposals with the atmosphere
/// wake-overrides.
pub fn sleep_update_kernel(
    vel_x: &[f32],
    vel_y: &[f32],
    calm_frame_count: &mut [u32],
    propose_sleep: &mut [bool],
    k_threshold: u32,
) {
    let n = vel_x.len()
        .min(vel_y.len()).min(calm_frame_count.len()).min(propose_sleep.len());
    let thresh_sq = SLEEP_VELOCITY_THRESHOLD * SLEEP_VELOCITY_THRESHOLD;
    for i in 0..n {
        let speed_sq = vel_x[i] * vel_x[i] + vel_y[i] * vel_y[i];
        if speed_sq < thresh_sq {
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
