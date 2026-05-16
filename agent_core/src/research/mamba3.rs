//! Source:
//! - "Mamba-3", arXiv:2603.15569, March 2026 — exponential-trapezoidal
//!   discretization · complex-valued state for state tracking · MIMO
//!   formulation · RoPE-trick recurrence. Reported +0.6-1.8 pts vs
//!   Gated DeltaNet at 1.5B per V6.1 integration §1.4.
//! - `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md`
//!   §"Terminal B" Phase B.1 J10.
//! - Gu et al., "Mamba: Linear-Time Sequence Modeling with Selective
//!   State Spaces", arXiv:2312.00752, 2023 — S6 predecessor (real state).
//! - Dao & Gu, "Transformers are SSMs", arXiv:2405.21060, 2024 — Mamba-2
//!   SSD (real-state, scalar).
//!
//! # Wave J10 — Mamba-3 substrate (complex-state SSM)
//!
//! Substrate floor for the four V6.1-cited Mamba-3 deltas:
//!
//! 1. **Exponential-trapezoidal discretization**:
//!    `a_d = (1 + a·Δt/2) / (1 - a·Δt/2)` — A-stable, second-order
//!    accurate; replaces Mamba's zero-order-hold (ZOH) `a_d = exp(a·Δt)`.
//! 2. **Complex-valued state**: each state channel carries a `(re, im)`
//!    pair so the recurrence can encode rotation explicitly (the
//!    RoPE-trick recurrence below).
//! 3. **MIMO formulation**: multiple inputs / multiple outputs per
//!    state channel; substrate floor here ships the SISO scalar (one
//!    input, one output, complex state) — MIMO matrix variant is a
//!    follow-up iter.
//! 4. **RoPE-trick recurrence**: when `a` is purely imaginary, the
//!    multiplicative update degenerates to a rotation in the
//!    complex plane — exactly the positional-encoding trick from
//!    RoPE (Su et al. arXiv:2104.09864).
//!
//! Math (scalar, per channel):
//!
//! ```text
//! state[t]   = a[t] * state[t-1] + b[t] * x[t]    (complex × × ×)
//! y[t]       = Re(c[t] * state[t])                (real readout)
//! ```
//!
//! Substrate floor: scalar single-channel reference. MIMO matrix
//! version + Metal port are NOT-STARTED here; this iter establishes
//! the contract that the Metal kernel (future
//! `Epistemos/Shaders/Mamba3Step.metal`) must match.

use serde::{Deserialize, Serialize};

/// Complex scalar (re, im). Substrate floor avoids `num-complex` dep
/// to keep the agent_core surface tight; if multi-channel MIMO ever
/// needs matrix complex ops, switch to `num-complex` then.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct C32 {
    pub re: f32,
    pub im: f32,
}

impl C32 {
    pub const ZERO: Self = Self { re: 0.0, im: 0.0 };
    pub const ONE: Self = Self { re: 1.0, im: 0.0 };
    pub const I: Self = Self { re: 0.0, im: 1.0 };

    pub fn new(re: f32, im: f32) -> Self {
        Self { re, im }
    }

    pub fn add(self, other: Self) -> Self {
        Self { re: self.re + other.re, im: self.im + other.im }
    }

    pub fn sub(self, other: Self) -> Self {
        Self { re: self.re - other.re, im: self.im - other.im }
    }

    pub fn mul(self, other: Self) -> Self {
        Self {
            re: self.re * other.re - self.im * other.im,
            im: self.re * other.im + self.im * other.re,
        }
    }

    pub fn scale(self, s: f32) -> Self {
        Self { re: self.re * s, im: self.im * s }
    }

    pub fn norm_sq(self) -> f32 {
        self.re * self.re + self.im * self.im
    }

    /// Magnitude `|z| = sqrt(re² + im²)`. Always non-negative.
    pub fn abs(self) -> f32 {
        self.norm_sq().sqrt()
    }

    pub fn conj(self) -> Self {
        Self { re: self.re, im: -self.im }
    }

    /// `1 / self` for nonzero `self`. Returns `None` if `self == 0`.
    pub fn inv(self) -> Option<Self> {
        let n = self.norm_sq();
        if n == 0.0 {
            return None;
        }
        Some(Self { re: self.re / n, im: -self.im / n })
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Mamba3Error {
    LengthMismatch { a: usize, b: usize, c: usize, x: usize },
    DiscretizationDivisionByZero,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Mamba3ScanResult {
    /// Real-readout outputs (`Re(c[t] * state[t])`).
    pub y: Vec<f32>,
    /// Terminal complex state for chained-block continuation.
    pub final_state: C32,
}

/// Exponential-trapezoidal (A-stable, second-order) discretization
/// of a continuous-time complex pole `a` over step `dt`:
/// `a_d = (1 + a·dt/2) / (1 - a·dt/2)`.
/// Returns `Err(DiscretizationDivisionByZero)` if `1 - a·dt/2 == 0`.
pub fn exponential_trapezoidal_discretize(a: C32, dt: f32) -> Result<C32, Mamba3Error> {
    let half_a_dt = a.scale(dt * 0.5);
    let num = C32::ONE.add(half_a_dt);
    let den = C32::ONE.sub(half_a_dt);
    match den.inv() {
        Some(d_inv) => Ok(num.mul(d_inv)),
        None => Err(Mamba3Error::DiscretizationDivisionByZero),
    }
}

/// Verify A-stability of the exponential-trapezoidal discretization
/// at pole `a` over step `dt`. The doctrine claim per V6.1 §1.4:
/// "exponential-trapezoidal is A-stable" (every left-half-plane
/// pole produces a discrete pole inside the unit disk; every
/// imaginary pole maps to the unit circle exactly).
///
/// Returns `Ok(true)` iff `Re(a) ≤ 0` AND the discretized
/// pole `a_d` has `|a_d| ≤ 1 + tol`. Returns `Ok(false)` when
/// `Re(a) > 0` (the pole is in the right half plane; the substrate
/// doesn't promise stability there).
///
/// `tol` accounts for fp32 rounding in the trapezoidal denominator.
/// `1e-6` is a reasonable default for production checks.
pub fn verify_a_stability(a: C32, dt: f32, tol: f32) -> Result<bool, Mamba3Error> {
    if a.re > 0.0 {
        return Ok(false);
    }
    let a_d = exponential_trapezoidal_discretize(a, dt)?;
    Ok(a_d.abs() <= 1.0 + tol)
}

/// Mamba-3 scalar SSM scan. Each `(a, b, c)` triple is per-step
/// already-discretized complex. Real readout: `y[t] = Re(c[t] * state[t])`.
pub fn mamba3_scan_scalar(
    a: &[C32],
    b: &[C32],
    c: &[C32],
    x: &[f32],
    initial_state: C32,
) -> Result<Mamba3ScanResult, Mamba3Error> {
    if a.len() != b.len() || b.len() != c.len() || c.len() != x.len() {
        return Err(Mamba3Error::LengthMismatch {
            a: a.len(),
            b: b.len(),
            c: c.len(),
            x: x.len(),
        });
    }
    let mut state = initial_state;
    let mut y = Vec::with_capacity(a.len());
    for i in 0..a.len() {
        state = a[i].mul(state).add(b[i].scale(x[i]));
        let out = c[i].mul(state);
        y.push(out.re);
    }
    Ok(Mamba3ScanResult { y, final_state: state })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx_c(a: C32, b: C32, tol: f32) -> bool {
        (a.re - b.re).abs() < tol && (a.im - b.im).abs() < tol
    }

    #[test]
    fn c32_constants_match_literal() {
        assert_eq!(C32::ZERO, C32::new(0.0, 0.0));
        assert_eq!(C32::ONE, C32::new(1.0, 0.0));
        assert_eq!(C32::I, C32::new(0.0, 1.0));
    }

    #[test]
    fn c32_i_squared_is_minus_one() {
        let i = C32::I;
        let r = i.mul(i);
        assert!(approx_c(r, C32::new(-1.0, 0.0), 1e-6));
    }

    #[test]
    fn c32_inv_of_one_is_one() {
        assert_eq!(C32::ONE.inv(), Some(C32::ONE));
    }

    #[test]
    fn c32_inv_of_zero_is_none() {
        assert!(C32::ZERO.inv().is_none());
    }

    #[test]
    fn c32_conj_negates_imag() {
        let z = C32::new(2.0, 3.0);
        assert_eq!(z.conj(), C32::new(2.0, -3.0));
    }

    #[test]
    fn c32_norm_sq_pythagorean() {
        let z = C32::new(3.0, 4.0);
        assert!((z.norm_sq() - 25.0).abs() < 1e-6);
    }

    #[test]
    fn exp_trapezoidal_zero_pole_returns_one() {
        let a_d = exponential_trapezoidal_discretize(C32::ZERO, 0.1).unwrap();
        assert!(approx_c(a_d, C32::ONE, 1e-6));
    }

    #[test]
    fn exp_trapezoidal_real_negative_pole_is_stable() {
        // a = -1 + 0i, dt = 0.5
        // a_d = (1 + (-1)*0.25) / (1 - (-1)*0.25) = 0.75 / 1.25 = 0.6
        let a = C32::new(-1.0, 0.0);
        let a_d = exponential_trapezoidal_discretize(a, 0.5).unwrap();
        assert!(approx_c(a_d, C32::new(0.6, 0.0), 1e-6));
    }

    #[test]
    fn exp_trapezoidal_imaginary_pole_lies_on_unit_circle() {
        // Pure imaginary pole → discrete pole on unit circle (lossless rotation).
        let a = C32::new(0.0, 2.0);
        let a_d = exponential_trapezoidal_discretize(a, 0.5).unwrap();
        assert!((a_d.norm_sq() - 1.0).abs() < 1e-5);
    }

    #[test]
    fn exp_trapezoidal_division_by_zero_errors() {
        // 1 - a·dt/2 = 0 when a·dt = 2. Use a=2+0i, dt=1: half = 1, den = 0.
        let err = exponential_trapezoidal_discretize(C32::new(2.0, 0.0), 1.0).unwrap_err();
        assert_eq!(err, Mamba3Error::DiscretizationDivisionByZero);
    }

    #[test]
    fn scan_length_mismatch_errors() {
        let err = mamba3_scan_scalar(
            &[C32::ZERO, C32::ZERO],
            &[C32::ZERO],
            &[C32::ZERO],
            &[0.0],
            C32::ZERO,
        )
        .unwrap_err();
        assert!(matches!(err, Mamba3Error::LengthMismatch { .. }));
    }

    #[test]
    fn scan_real_pole_unit_b_unit_c_recovers_running_state() {
        // a=1, b=1, c=1 → y[t] = sum of x[0..=t]
        let t = 4;
        let a = vec![C32::ONE; t];
        let b = vec![C32::ONE; t];
        let c = vec![C32::ONE; t];
        let x = vec![1.0_f32, 2.0, 3.0, 4.0];
        let r = mamba3_scan_scalar(&a, &b, &c, &x, C32::ZERO).unwrap();
        assert_eq!(r.y, vec![1.0, 3.0, 6.0, 10.0]);
    }

    #[test]
    fn scan_zero_a_drops_state_each_step() {
        let t = 3;
        let a = vec![C32::ZERO; t];
        let b = vec![C32::ONE; t];
        let c = vec![C32::ONE; t];
        let x = vec![5.0_f32, 7.0, 11.0];
        let r = mamba3_scan_scalar(&a, &b, &c, &x, C32::new(99.0, 0.0)).unwrap();
        assert_eq!(r.y, vec![5.0, 7.0, 11.0]);
    }

    #[test]
    fn rope_trick_imaginary_pole_produces_rotation() {
        // a = i, b = 1, c = 1, x = (1, 0, 0, 0), state0 = 0
        // step 1: state = i * 0 + 1 * 1 = 1     ; y = Re(1*1) = 1
        // step 2: state = i * 1 + 1 * 0 = i     ; y = Re(1*i) = 0
        // step 3: state = i * i + 0 = -1        ; y = -1
        // step 4: state = i * -1 + 0 = -i       ; y = 0
        let t = 4;
        let a = vec![C32::I; t];
        let b = vec![C32::ONE; t];
        let c = vec![C32::ONE; t];
        let x = vec![1.0_f32, 0.0, 0.0, 0.0];
        let r = mamba3_scan_scalar(&a, &b, &c, &x, C32::ZERO).unwrap();
        assert!((r.y[0] - 1.0).abs() < 1e-5);
        assert!(r.y[1].abs() < 1e-5);
        assert!((r.y[2] - (-1.0)).abs() < 1e-5);
        assert!(r.y[3].abs() < 1e-5);
    }

    #[test]
    fn result_roundtrips_through_serde_json() {
        let r = Mamba3ScanResult { y: vec![1.0, 2.0], final_state: C32::new(0.5, -0.5) };
        let json = serde_json::to_string(&r).unwrap();
        let back: Mamba3ScanResult = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn empty_scan_returns_empty_y_and_initial_state() {
        let r = mamba3_scan_scalar(&[], &[], &[], &[], C32::new(7.0, 3.0)).unwrap();
        assert!(r.y.is_empty());
        assert_eq!(r.final_state, C32::new(7.0, 3.0));
    }

    // ── C32::abs + verify_a_stability tests (iter 99) ───────────────────────

    fn approx_eq_f32(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn abs_of_zero_is_zero() {
        assert_eq!(C32::ZERO.abs(), 0.0);
    }

    #[test]
    fn abs_of_one_is_one() {
        assert_eq!(C32::ONE.abs(), 1.0);
    }

    #[test]
    fn abs_of_i_is_one() {
        assert_eq!(C32::I.abs(), 1.0);
    }

    #[test]
    fn abs_three_four_five() {
        // |3 + 4i| = 5
        let z = C32::new(3.0, 4.0);
        assert!(approx_eq_f32(z.abs(), 5.0, 1e-6));
    }

    #[test]
    fn abs_consistent_with_norm_sq() {
        for (re, im) in &[(1.0_f32, 0.0), (0.0, 1.0), (1.5, -2.5), (-3.0, 4.5)] {
            let z = C32::new(*re, *im);
            assert!(approx_eq_f32(z.abs() * z.abs(), z.norm_sq(), 1e-5));
        }
    }

    #[test]
    fn a_stability_left_half_plane_pole_satisfied() {
        // Re(a) < 0 → discretized pole inside unit disk.
        let a = C32::new(-1.0, 0.5);
        let stable = verify_a_stability(a, 0.1, 1e-6).unwrap();
        assert!(stable);
    }

    #[test]
    fn a_stability_right_half_plane_returns_false() {
        // Re(a) > 0 → substrate doesn't promise stability.
        let a = C32::new(1.0, 0.0);
        let stable = verify_a_stability(a, 0.1, 1e-6).unwrap();
        assert!(!stable);
    }

    #[test]
    fn a_stability_purely_imaginary_pole_on_unit_circle() {
        // Re(a) = 0, im(a) = ω → discretized pole on unit circle
        // exactly (the RoPE-trick recurrence). Should satisfy
        // |a_d| ≤ 1 within fp32 tolerance.
        let a = C32::new(0.0, 2.0);
        let a_d = exponential_trapezoidal_discretize(a, 0.1).unwrap();
        // The trapezoidal map sends iω onto the unit circle exactly.
        assert!(approx_eq_f32(a_d.abs(), 1.0, 1e-5));
        let stable = verify_a_stability(a, 0.1, 1e-5).unwrap();
        assert!(stable);
    }

    #[test]
    fn a_stability_origin_pole_stable() {
        // a = 0 → a_d = 1 (the integrator pole).
        let a = C32::ZERO;
        let a_d = exponential_trapezoidal_discretize(a, 0.1).unwrap();
        assert_eq!(a_d, C32::ONE);
        let stable = verify_a_stability(a, 0.1, 1e-6).unwrap();
        assert!(stable);
    }

    #[test]
    fn a_stability_passes_doctrine_over_diverse_left_plane_sweep() {
        // Sweep poles across the left half plane; A-stability claim
        // demands ALL satisfy |a_d| ≤ 1.
        for re in &[-0.1_f32, -1.0, -5.0, -100.0] {
            for im in &[-3.0_f32, 0.0, 1.5, 7.0] {
                let a = C32::new(*re, *im);
                let stable = verify_a_stability(a, 0.05, 1e-5).unwrap();
                assert!(
                    stable,
                    "doctrine violation at a = ({}, {}i)",
                    re, im
                );
            }
        }
    }
}
