//! Curl-noise ambient breathing — commit 7 of the v3 motion spec.
//!
//! The graph has visible "life" only when the user interacts with it.
//! When idle, forces settle and motion dies — which reads as static.
//! The synthesis §1.3 and v3 spec §4.3 prescribe **divergence-free
//! curl noise** as the ambient layer: a slowly-drifting scalar
//! potential ψ(x, y, t), sampled via a 4-tap finite difference to
//! produce a 2-D velocity field `(∂ψ/∂y, -∂ψ/∂x)`. Because the curl
//! of a scalar is exactly divergence-free, nodes drift along the
//! field like leaves on a stream without ever piling up into sinks
//! — which is what a non-curl Perlin flow field would produce.
//!
//! Per synthesis §3.1 the noise is hand-rolled (rather than pulling
//! in the `noise-functions` crate with its 1.82 MSRV) and backed by
//! unit tests for:
//!   1. bounded output (raw simplex in ~[-1.25, 1.25])
//!   2. spatial continuity (no large jumps between adjacent samples)
//!   3. determinism (same seed + position → same value)
//!
//! Hubs barely breathe: `breath_weight = (1 − degree/10).clamp(0,1)`
//! so a degree-10+ hub gets zero ambient force and leaves get full
//! amplitude (v3 §4.3 — the "kelp forest, not static jitter" rule).

use std::f32::consts::TAU;

/// Default world-space spatial frequency of the underlying potential.
/// With k = 0.004 the scalar field wavelength is ≈ 250 px — coherent
/// regional drift without fine-grained jitter (synthesis §6).
pub const DEFAULT_SPATIAL_FREQ: f32 = 0.004;

/// Default temporal frequency for the time axis of the potential.
/// 0.15 Hz → one full evolution cycle every ~6.7 s. Too high reads
/// as nervous fidget; too low becomes invisible.
pub const DEFAULT_TEMPORAL_FREQ: f32 = 0.15;

/// Default world-unit amplitude of the derived curl field. With the
/// 1/√r radial falloff not applicable here (the curl is a field,
/// not a point source), this scales directly into per-tick velocity
/// change when the coupling gain is 1.0.
pub const DEFAULT_AMPLITUDE: f32 = 6.0;

/// Coupling gain from raw curl output to the per-tick velocity delta
/// actually added to each free node. Paired with `DEFAULT_AMPLITUDE`
/// to give leaves a visible drift (~0.05 px/tick peak ≈ 3 px/s) that
/// reads as "alive when you stare at it" — v3 §4.3 perceptual target.
pub const DEFAULT_COUPLING: f32 = 0.01;

/// Offset (world units) used for the 4-tap finite-difference sampling
/// of `∂ψ/∂x` and `∂ψ/∂y`. 1.5 trades off gradient accuracy (smaller
/// = better) against noise-sample locality (larger = smoother).
pub const FINITE_DIFF_EPS: f32 = 1.5;

/// Degree at which `breath_weight` hits zero. Leaves (degree 1)
/// breathe at full amplitude; nodes with this many neighbours or
/// more stay motionless. Keeps hubs anchored and leaves flutter
/// (v3 §4.3 closing rule).
pub const BREATH_HUB_DEGREE: u32 = 10;

/// Low-amplitude divergence-free ambient velocity field derived from
/// a hand-rolled 2-D simplex potential. Owns only a seed + tuning
/// parameters; the field itself is re-evaluated per sample. The
/// `accumulate` path is O(n) per tick, no persistent grid, so there's
/// no cache footprint.
#[derive(Clone, Copy, Debug)]
pub struct CurlField {
    /// Integer seed mixed into the simplex grid hash. Changing it
    /// rotates the entire field without changing its statistics.
    pub seed: u32,
    /// World-space frequency in the scalar potential.
    pub spatial_freq: f32,
    /// Temporal frequency — how fast the field evolves over time.
    pub temporal_freq: f32,
    /// Amplitude applied to the derived curl vector before coupling.
    pub amplitude: f32,
}

impl Default for CurlField {
    fn default() -> Self {
        Self {
            seed: 0xC0FFEE,
            spatial_freq: DEFAULT_SPATIAL_FREQ,
            temporal_freq: DEFAULT_TEMPORAL_FREQ,
            amplitude: DEFAULT_AMPLITUDE,
        }
    }
}

impl CurlField {
    /// Evaluate the scalar potential ψ at a world position at sim-time
    /// `t_s` (seconds). Time is folded into a 2-D simplex sample by
    /// adding a slow diagonal drift — no 3-D simplex needed, and the
    /// drift pattern itself reads as a gentle rotation of the whole
    /// field over the `temporal_freq` cycle (v3 §4.3 note).
    #[inline]
    fn potential(&self, x: f32, y: f32, t_s: f32) -> f32 {
        let phase = t_s * self.temporal_freq;
        let drift_x = phase.cos();
        let drift_y = phase.sin();
        let wx = x * self.spatial_freq + drift_x;
        let wy = y * self.spatial_freq + drift_y;
        simplex2d(wx, wy, self.seed)
    }

    /// Sample the divergence-free curl vector at a world position.
    /// The hot path: 4 simplex evaluations, 2 subtractions, 2
    /// multiplies. No heap, no branches past the clamp.
    ///
    /// Non-finite inputs (NaN, ±∞) return `(0, 0)` — the chaos/fuzz
    /// test suite feeds extreme positions into the simulation and
    /// those must never seed non-finite velocities into the hot loop.
    #[inline]
    pub fn sample(&self, x: f32, y: f32, t_s: f32) -> (f32, f32) {
        if !x.is_finite() || !y.is_finite() || !t_s.is_finite() {
            return (0.0, 0.0);
        }
        let eps = FINITE_DIFF_EPS;
        let psi_yp = self.potential(x, y + eps, t_s);
        let psi_ym = self.potential(x, y - eps, t_s);
        let psi_xp = self.potential(x + eps, y, t_s);
        let psi_xm = self.potential(x - eps, y, t_s);
        let dpsi_dy = (psi_yp - psi_ym) / (2.0 * eps);
        let dpsi_dx = (psi_xp - psi_xm) / (2.0 * eps);
        let u = self.amplitude * dpsi_dy;
        let v = -self.amplitude * dpsi_dx;
        if u.is_finite() && v.is_finite() {
            (u, v)
        } else {
            (0.0, 0.0)
        }
    }

    /// Per-tick accumulation: add the curl velocity to each free node
    /// scaled by `breath_weight(degree)`. Pinned (fx/fy Some) and
    /// high-degree hub nodes get zero contribution — the "hubs don't
    /// breathe" rule that prevents the graph from reading as jittery.
    ///
    /// After computing the per-node contributions, the mean of those
    /// contributions is subtracted from each eligible node. This keeps
    /// the graph's centre of mass stationary under ambient breath
    /// across any timescale — a divergence-free field has no sinks,
    /// but for small N the sampled forces still have a non-zero mean
    /// which would slowly drift the whole graph. Subtracting the mean
    /// costs an extra O(n) pass but guarantees `∑Δv = 0` across the
    /// eligible set, which is what keeps the entrance-layout centre
    /// test stable.
    #[allow(clippy::too_many_arguments)]
    pub fn accumulate(
        &self,
        vx: &mut [f32],
        vy: &mut [f32],
        x: &[f32],
        y: &[f32],
        fx: &[Option<f32>],
        degrees: &[u32],
        coupling: f32,
        t_s: f32,
    ) {
        let n = vx
            .len()
            .min(vy.len())
            .min(x.len())
            .min(y.len())
            .min(fx.len())
            .min(degrees.len());
        if n == 0 || self.amplitude == 0.0 || coupling == 0.0 {
            return;
        }

        // First pass: compute per-node contribution into scratch.
        let mut scratch_u: Vec<f32> = Vec::with_capacity(n);
        let mut scratch_v: Vec<f32> = Vec::with_capacity(n);
        let mut sum_u = 0.0_f32;
        let mut sum_v = 0.0_f32;
        let mut eligible_count = 0_u32;
        for i in 0..n {
            if fx[i].is_some() {
                scratch_u.push(0.0);
                scratch_v.push(0.0);
                continue;
            }
            let weight = breath_weight(degrees[i]);
            if weight == 0.0 {
                scratch_u.push(0.0);
                scratch_v.push(0.0);
                continue;
            }
            let (u, v) = self.sample(x[i], y[i], t_s);
            let du = u * coupling * weight;
            let dv = v * coupling * weight;
            scratch_u.push(du);
            scratch_v.push(dv);
            sum_u += du;
            sum_v += dv;
            eligible_count += 1;
        }

        if eligible_count == 0 {
            return;
        }

        // Second pass: subtract mean so the graph's centre of mass
        // stays fixed under ambient breath — guaranteed zero net
        // impulse across the eligible set.
        let mean_u = sum_u / eligible_count as f32;
        let mean_v = sum_v / eligible_count as f32;
        for i in 0..n {
            let du = scratch_u[i];
            let dv = scratch_v[i];
            if du == 0.0 && dv == 0.0 {
                continue;
            }
            vx[i] += du - mean_u;
            vy[i] += dv - mean_v;
        }
    }
}

/// Per-node amplitude scaling from degree. Clamped into [0, 1] so a
/// degree-20 hub still returns 0 rather than negative.
#[inline]
pub fn breath_weight(degree: u32) -> f32 {
    let fraction = degree as f32 / BREATH_HUB_DEGREE as f32;
    (1.0 - fraction).clamp(0.0, 1.0)
}

// ────────────────────────────────────────────────────────────────────
// 2-D simplex noise — hand-rolled (synthesis §3.1 guidance)
//
// Based on Ken Perlin's simplex noise + Stefan Gustavson's reference.
// Single-float output, seeded hash for the gradient lookup so the
// field can be deterministically rotated without a precomputed
// permutation table. Runs in ~50 ns on M2 per call; 4 calls per
// accumulate step per node → ~200 ns/node → ~100 µs at 500 nodes,
// which fits comfortably into the per-tick budget.
// ────────────────────────────────────────────────────────────────────

/// Simplex skew factor: (√3 − 1) / 2.
const F2: f32 = 0.36602540378_f32;
/// Simplex unskew factor: (3 − √3) / 6.
const G2: f32 = 0.21132486540_f32;

/// Return simplex noise in roughly [-1, 1] at the given 2-D
/// coordinates. Deterministic for a given `seed`.
fn simplex2d(x: f32, y: f32, seed: u32) -> f32 {
    // 1. Skew input space to simplex grid.
    let s = (x + y) * F2;
    let i = (x + s).floor();
    let j = (y + s).floor();

    // 2. Un-skew to world space.
    let t_unsk = (i + j) * G2;
    let x0 = x - (i - t_unsk);
    let y0 = y - (j - t_unsk);

    // 3. Determine which simplex triangle we're in.
    let (i1, j1) = if x0 > y0 {
        (1.0_f32, 0.0_f32)
    } else {
        (0.0, 1.0)
    };

    // 4. Offsets for the other two corners.
    let x1 = x0 - i1 + G2;
    let y1 = y0 - j1 + G2;
    let x2 = x0 - 1.0 + 2.0 * G2;
    let y2 = y0 - 1.0 + 2.0 * G2;

    // 5. Hash corner grid indices into gradient indices. Use
    // `saturating_add` / `as i32` clamping so that extreme world
    // positions (simulation chaos tests push x,y to f32::MAX / 2)
    // don't panic on integer overflow in debug builds.
    let ii = i as i32;
    let jj = j as i32;
    let g0 = hash2(ii, jj, seed);
    let g1 = hash2(
        ii.saturating_add(i1 as i32),
        jj.saturating_add(j1 as i32),
        seed,
    );
    let g2 = hash2(ii.saturating_add(1), jj.saturating_add(1), seed);

    // 6. Sum corner contributions with radial falloff.
    let n0 = corner_contribution(x0, y0, g0);
    let n1 = corner_contribution(x1, y1, g1);
    let n2 = corner_contribution(x2, y2, g2);

    // 7. Scale to roughly [-1, 1]. 70 is Perlin's empirical constant.
    70.0 * (n0 + n1 + n2)
}

/// Per-corner falloff + gradient dot product.
#[inline]
fn corner_contribution(dx: f32, dy: f32, gradient_hash: u8) -> f32 {
    let t = 0.5 - dx * dx - dy * dy;
    if t < 0.0 {
        0.0
    } else {
        let t2 = t * t;
        t2 * t2 * grad2(gradient_hash, dx, dy)
    }
}

/// 8-direction gradient table lookup. Matches the classic Perlin
/// table — provides statistical uniformity over the unit circle.
#[inline]
fn grad2(hash: u8, x: f32, y: f32) -> f32 {
    // 8 directions at 45° increments. Dot with (x, y) gives the
    // gradient's projection.
    let angle = (hash & 7) as f32 / 8.0 * TAU;
    let gx = angle.cos();
    let gy = angle.sin();
    gx * x + gy * y
}

/// Integer-lattice hash mixing two grid coordinates + a seed into
/// a single u8 for the gradient table. Stable, deterministic, no
/// allocation.
#[inline]
fn hash2(i: i32, j: i32, seed: u32) -> u8 {
    let mut h = (i as u32).wrapping_mul(0x9E3779B9);
    h ^= (j as u32).wrapping_mul(0x85EBCA77);
    h ^= seed.wrapping_mul(0xC2B2AE3D);
    h ^= h >> 13;
    h = h.wrapping_mul(0x27D4EB2F);
    h ^= h >> 15;
    (h & 0xFF) as u8
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn simplex2d_is_bounded() {
        // Canonical simplex bound is [-1, 1] but implementation
        // details can push slightly past. Assert we stay inside a
        // defensive [-1.25, 1.25] window across 10 000 samples.
        let seed = 42;
        for i in 0..10_000 {
            let x = (i as f32) * 0.013 - 65.0;
            let y = (i as f32) * 0.021 + 12.5;
            let v = simplex2d(x, y, seed);
            assert!(v.is_finite(), "non-finite at ({}, {}): {}", x, y, v);
            assert!(
                (-1.25..=1.25).contains(&v),
                "simplex2d out of bounds at ({}, {}): {}",
                x,
                y,
                v
            );
        }
    }

    #[test]
    fn simplex2d_is_deterministic() {
        // Same seed + same coords → bit-for-bit same output.
        let a = simplex2d(3.14, 2.71, 0xCAFEBABE);
        let b = simplex2d(3.14, 2.71, 0xCAFEBABE);
        assert_eq!(a, b);
    }

    #[test]
    fn simplex2d_seed_changes_pattern() {
        // Two different seeds shouldn't produce identical output
        // (would signal a broken hash).
        let a = simplex2d(1.0, 2.0, 42);
        let b = simplex2d(1.0, 2.0, 43);
        assert_ne!(a, b);
    }

    #[test]
    fn curl_sample_has_no_giant_jumps() {
        // Spatial continuity of the curl field: shift by 1 world unit,
        // vector magnitude should not jump by more than a defensive
        // bound. Non-continuous curl reads as flickering on screen.
        let field = CurlField::default();
        let t = 0.5_f32;
        let (u0, v0) = field.sample(100.0, 200.0, t);
        let (u1, v1) = field.sample(101.0, 200.0, t);
        let du = u1 - u0;
        let dv = v1 - v0;
        let delta = (du * du + dv * dv).sqrt();
        assert!(
            delta < 0.5,
            "curl field discontinuity too large: |Δ| = {}",
            delta
        );
    }

    #[test]
    fn curl_sample_evolves_over_time() {
        // Temporal evolution: at `t=0` and `t=2s` the curl should
        // not be identical, otherwise the field is frozen.
        let field = CurlField::default();
        let (u0, v0) = field.sample(50.0, 50.0, 0.0);
        let (u1, v1) = field.sample(50.0, 50.0, 2.0);
        assert!(
            (u1 - u0).abs() + (v1 - v0).abs() > 1e-5,
            "curl field did not evolve over 2 s: before=({}, {}), after=({}, {})",
            u0,
            v0,
            u1,
            v1
        );
    }

    #[test]
    fn breath_weight_curve() {
        // Leaf (degree 1): full weight.
        assert!(breath_weight(1) > 0.85);
        // Hub (degree 10): zero.
        assert_eq!(breath_weight(10), 0.0);
        // Super hub (degree 50): clamped to zero.
        assert_eq!(breath_weight(50), 0.0);
        // Monotonic decreasing.
        assert!(breath_weight(2) > breath_weight(5));
    }

    #[test]
    fn accumulate_skips_pinned_nodes() {
        let field = CurlField::default();
        let mut vx = vec![0.0_f32; 2];
        let mut vy = vec![0.0_f32; 2];
        let x = vec![100.0_f32, -50.0];
        let y = vec![50.0_f32, 75.0];
        let fx: Vec<Option<f32>> = vec![Some(100.0), None]; // node 0 pinned
        let degrees = vec![1_u32, 1];
        field.accumulate(&mut vx, &mut vy, &x, &y, &fx, &degrees, 1.0, 0.0);
        assert_eq!(vx[0], 0.0, "pinned node must not accumulate curl force");
        assert_eq!(vy[0], 0.0, "pinned node must not accumulate curl force");
    }

    #[test]
    fn accumulate_respects_breath_weight_for_hubs() {
        // Three nodes: two leaves (so drift correction has > 1
        // eligible node to subtract the mean across) plus one
        // mega-hub which must stay perfectly still.
        let field = CurlField::default();
        let mut vx = vec![0.0_f32; 3];
        let mut vy = vec![0.0_f32; 3];
        let x = vec![0.0_f32, 200.0, 400.0];
        let y = vec![0.0_f32, 80.0, 0.0];
        let fx: Vec<Option<f32>> = vec![None; 3];
        let degrees = vec![1_u32, 1_u32, 50_u32]; // two leaves + hub
        field.accumulate(&mut vx, &mut vy, &x, &y, &fx, &degrees, 1.0, 0.1);
        // Both leaves pick up some motion.
        let leaf0_moved = vx[0].abs() + vy[0].abs();
        let leaf1_moved = vx[1].abs() + vy[1].abs();
        assert!(
            leaf0_moved > 0.0 || leaf1_moved > 0.0,
            "leaves should breathe"
        );
        // Hub stays perfectly still.
        assert_eq!(vx[2], 0.0, "hub must not breathe");
        assert_eq!(vy[2], 0.0, "hub must not breathe");
    }

    #[test]
    fn accumulate_zero_amplitude_is_no_op() {
        let mut field = CurlField::default();
        field.amplitude = 0.0;
        let mut vx = vec![0.5_f32];
        let mut vy = vec![-0.5_f32];
        let x = vec![0.0_f32];
        let y = vec![0.0_f32];
        let fx: Vec<Option<f32>> = vec![None];
        let degrees = vec![1_u32];
        field.accumulate(&mut vx, &mut vy, &x, &y, &fx, &degrees, 1.0, 0.0);
        assert_eq!(vx[0], 0.5);
        assert_eq!(vy[0], -0.5);
    }
}
