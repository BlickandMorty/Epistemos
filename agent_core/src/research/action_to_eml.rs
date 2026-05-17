//! Source:
//! - `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md`
//!   §"Terminal B" Phase B.6.16 — T-Action-to-EML / F-Action-Demo
//!   ("killer demo" per V6.1). Lean-verified Euler-Lagrange chain
//!   from action principle to EML term tree.
//! - Goldstein, Poole & Safko, "Classical Mechanics" (3rd ed., 2002),
//!   Ch. 2 — Euler-Lagrange equations from the action principle.
//! - Companion to [`super::eml`] (Phase B.0 F-ULP-Oracle) — the EML
//!   grammar this demo terminates into.
//!
//! # Wave J B.6.16 — Action-to-EML substrate
//!
//! The action principle: a classical trajectory minimizes (or
//! extremizes) the action
//!
//! ```text
//! S[x] = ∫ L(x, ẋ, t) dt
//! ```
//!
//! and satisfies the Euler-Lagrange equation
//!
//! ```text
//! d/dt (∂L/∂ẋ) - ∂L/∂x = 0
//! ```
//!
//! Substrate floor:
//!
//! - [`Lagrangian`] trait — caller supplies `L(x, x_dot, t)` + the
//!   two partials (analytic or numerically estimated).
//! - [`euler_lagrange_residual`] — measures `d/dt(∂L/∂ẋ) − ∂L/∂x`
//!   along a discrete trajectory. The "killer demo" path: residual
//!   ≈ 0 along true solutions (e.g. cos(ωt) for the harmonic
//!   oscillator) and visibly nonzero along off-trajectory paths.
//! - Lean-verified version (F-Action-Demo) deferred — same pattern
//!   as Phase B.0 deferred B.0.2 vendoring (Lean toolchain not in
//!   the autonomous-loop scope).

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ActionError {
    EmptyTrajectory,
    LengthMismatch { x: usize, t: usize },
    NonUniformTimestep { i: usize, dt_here: f64, dt_zero: f64 },
    NonPositiveDt { dt: f64 },
}

impl ActionError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            ActionError::EmptyTrajectory => "empty_trajectory",
            ActionError::LengthMismatch { .. } => "length_mismatch",
            ActionError::NonUniformTimestep { .. } => "non_uniform_timestep",
            ActionError::NonPositiveDt { .. } => "non_positive_dt",
        }
    }

    /// Predicate: error pertains to trajectory shape (Empty /
    /// LengthMismatch).
    pub const fn is_shape_error(&self) -> bool {
        matches!(
            self,
            ActionError::EmptyTrajectory | ActionError::LengthMismatch { .. }
        )
    }

    /// Predicate: error pertains to timestep validation
    /// (NonUniformTimestep / NonPositiveDt). Cross-surface invariant:
    /// `is_shape_error XOR is_timestep_error` partitions all variants.
    pub const fn is_timestep_error(&self) -> bool {
        matches!(
            self,
            ActionError::NonUniformTimestep { .. } | ActionError::NonPositiveDt { .. }
        )
    }
}

pub trait Lagrangian {
    fn evaluate(&self, x: f64, x_dot: f64, t: f64) -> f64;
    fn d_dx(&self, x: f64, x_dot: f64, t: f64) -> f64;
    fn d_d_xdot(&self, x: f64, x_dot: f64, t: f64) -> f64;
}

pub struct HarmonicOscillator {
    pub mass: f64,
    pub k_spring: f64,
}

impl Lagrangian for HarmonicOscillator {
    fn evaluate(&self, x: f64, x_dot: f64, _t: f64) -> f64 {
        0.5 * self.mass * x_dot * x_dot - 0.5 * self.k_spring * x * x
    }
    fn d_dx(&self, x: f64, _x_dot: f64, _t: f64) -> f64 {
        -self.k_spring * x
    }
    fn d_d_xdot(&self, _x: f64, x_dot: f64, _t: f64) -> f64 {
        self.mass * x_dot
    }
}

impl HarmonicOscillator {
    /// Natural angular frequency `ω = sqrt(k/m)`. The analytic
    /// solution of the harmonic-oscillator EOM is `x(t) = A·cos(ωt
    /// + φ)`.
    pub fn omega(&self) -> f64 {
        (self.k_spring / self.mass).sqrt()
    }

    /// Total mechanical energy `½m·ẋ² + ½k·x²`. Conserved along any
    /// solution of the EOM (Noether: time-translation symmetry).
    pub fn total_energy(&self, x: f64, x_dot: f64) -> f64 {
        0.5 * self.mass * x_dot * x_dot + 0.5 * self.k_spring * x * x
    }
}

impl FreeParticleLagrangian {
    /// Kinetic energy `½m·ẋ²`. For the free particle the Lagrangian
    /// IS the kinetic energy (no potential), so this equals
    /// `evaluate(x, x_dot, t)` for any `x` and `t`. Cross-surface
    /// invariant: `kinetic_energy(v) == evaluate(_, v, _)`.
    pub fn kinetic_energy(&self, x_dot: f64) -> f64 {
        0.5 * self.mass * x_dot * x_dot
    }
}

/// Per-step Euler-Lagrange residual along a sampled trajectory.
/// Returns the maximum absolute residual across the interior of the
/// trajectory (boundary steps need second-order finite-difference
/// stencils that aren't substrate-floor scope).
pub fn euler_lagrange_residual<L: Lagrangian>(
    lagrangian: &L,
    x: &[f64],
    t: &[f64],
) -> Result<f64, ActionError> {
    if x.is_empty() || t.is_empty() {
        return Err(ActionError::EmptyTrajectory);
    }
    if x.len() != t.len() {
        return Err(ActionError::LengthMismatch { x: x.len(), t: t.len() });
    }
    if x.len() < 5 {
        return Err(ActionError::EmptyTrajectory);
    }
    let dt_zero = t[1] - t[0];
    if dt_zero <= 0.0 {
        return Err(ActionError::NonPositiveDt { dt: dt_zero });
    }
    for i in 1..t.len() - 1 {
        let dt = t[i + 1] - t[i];
        if (dt - dt_zero).abs() > 1e-9 {
            return Err(ActionError::NonUniformTimestep { i, dt_here: dt, dt_zero });
        }
    }
    let mut max_res: f64 = 0.0;
    for i in 2..x.len() - 2 {
        // Consistent central differences at every node (second-order accurate).
        let x_dot_im1 = (x[i] - x[i - 2]) / (2.0 * dt_zero);
        let x_dot_here = (x[i + 1] - x[i - 1]) / (2.0 * dt_zero);
        let x_dot_ip1 = (x[i + 2] - x[i]) / (2.0 * dt_zero);
        let p_im1 = lagrangian.d_d_xdot(x[i - 1], x_dot_im1, t[i - 1]);
        let p_ip1 = lagrangian.d_d_xdot(x[i + 1], x_dot_ip1, t[i + 1]);
        let dp_dt = (p_ip1 - p_im1) / (2.0 * dt_zero);
        let dl_dx = lagrangian.d_dx(x[i], x_dot_here, t[i]);
        let residual = (dp_dt - dl_dx).abs();
        if residual > max_res {
            max_res = residual;
        }
    }
    Ok(max_res)
}

// ── Additional Lagrangians + analytic-solution generators (iter 87) ────────
//
// The substrate-floor base shipped HarmonicOscillator. These sibling pieces
// expand the corpus the F-Action-Demo falsifier can exercise:
//   - FreeParticleLagrangian (`L = ½m·ẋ²`) — simplest non-trivial Lagrangian.
//   - harmonic_oscillator_solution(...) — analytic trajectory generator.
//   - free_particle_solution(...) — analytic trajectory generator.

/// Free particle: `L = ½m·ẋ²`. Euler-Lagrange gives `ẍ = 0`
/// (constant velocity).
pub struct FreeParticleLagrangian {
    pub mass: f64,
}

impl Lagrangian for FreeParticleLagrangian {
    fn evaluate(&self, _x: f64, x_dot: f64, _t: f64) -> f64 {
        0.5 * self.mass * x_dot * x_dot
    }
    fn d_dx(&self, _x: f64, _x_dot: f64, _t: f64) -> f64 {
        0.0
    }
    fn d_d_xdot(&self, _x: f64, x_dot: f64, _t: f64) -> f64 {
        self.mass * x_dot
    }
}

/// Analytic harmonic-oscillator trajectory `x(t) = amplitude · cos(ω·t)`.
/// Useful for testing `euler_lagrange_residual` against a known-good
/// solution. Returns `(x_samples, t_samples)` with `n` uniformly-spaced
/// samples at step `dt`.
pub fn harmonic_oscillator_solution(
    amplitude: f64,
    omega: f64,
    n: usize,
    dt: f64,
) -> Result<(Vec<f64>, Vec<f64>), ActionError> {
    if dt <= 0.0 {
        return Err(ActionError::NonPositiveDt { dt });
    }
    if n < 5 {
        return Err(ActionError::EmptyTrajectory);
    }
    let t: Vec<f64> = (0..n).map(|i| (i as f64) * dt).collect();
    let x: Vec<f64> = t.iter().map(|tv| amplitude * (omega * tv).cos()).collect();
    Ok((x, t))
}

/// Analytic free-particle trajectory `x(t) = x0 + v · t`.
pub fn free_particle_solution(
    x0: f64,
    v: f64,
    n: usize,
    dt: f64,
) -> Result<(Vec<f64>, Vec<f64>), ActionError> {
    if dt <= 0.0 {
        return Err(ActionError::NonPositiveDt { dt });
    }
    if n < 5 {
        return Err(ActionError::EmptyTrajectory);
    }
    let t: Vec<f64> = (0..n).map(|i| (i as f64) * dt).collect();
    let x: Vec<f64> = t.iter().map(|tv| x0 + v * tv).collect();
    Ok((x, t))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn harmonic_oscillator_lagrangian_zero_state_zero_energy() {
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        assert_eq!(h.evaluate(0.0, 0.0, 0.0), 0.0);
    }

    #[test]
    fn harmonic_oscillator_partials_correct() {
        let h = HarmonicOscillator { mass: 2.0, k_spring: 3.0 };
        assert_eq!(h.d_dx(1.0, 0.0, 0.0), -3.0);
        assert_eq!(h.d_d_xdot(0.0, 4.0, 0.0), 8.0);
    }

    #[test]
    fn empty_trajectory_errors() {
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        let err = euler_lagrange_residual(&h, &[], &[]).unwrap_err();
        assert_eq!(err, ActionError::EmptyTrajectory);
    }

    #[test]
    fn length_mismatch_errors() {
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        let err = euler_lagrange_residual(&h, &[1.0, 2.0, 3.0], &[0.0, 1.0]).unwrap_err();
        assert!(matches!(err, ActionError::LengthMismatch { .. }));
    }

    #[test]
    fn non_uniform_timestep_errors() {
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        let err = euler_lagrange_residual(
            &h,
            &[1.0, 1.0, 1.0, 1.0, 1.0],
            &[0.0, 0.1, 0.5, 0.6, 0.7],
        )
        .unwrap_err();
        assert!(matches!(err, ActionError::NonUniformTimestep { .. }));
    }

    #[test]
    fn cosine_trajectory_satisfies_harmonic_oscillator_eom() {
        // For m=1, k=1, omega = sqrt(k/m) = 1.
        // x(t) = cos(t) is the EOM solution.
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        let dt = 0.001_f64;
        let n = 200;
        let t: Vec<f64> = (0..n).map(|i| (i as f64) * dt).collect();
        let x: Vec<f64> = t.iter().map(|tv| tv.cos()).collect();
        let res = euler_lagrange_residual(&h, &x, &t).unwrap();
        // Finite-difference truncation gives O(dt²) ≈ 1e-6; allow margin.
        assert!(res < 1e-3, "residual={}", res);
    }

    #[test]
    fn parabolic_trajectory_does_not_satisfy_harmonic_oscillator_eom() {
        // x(t) = t² is NOT a solution; expect visibly nonzero residual.
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        let dt = 0.001_f64;
        let n = 200;
        let t: Vec<f64> = (0..n).map(|i| (i as f64) * dt).collect();
        let x: Vec<f64> = t.iter().map(|tv| tv * tv).collect();
        let res = euler_lagrange_residual(&h, &x, &t).unwrap();
        assert!(res > 1.0, "expected large residual, got {}", res);
    }

    #[test]
    fn cosine_with_different_omega_also_satisfies_when_lagrangian_matches() {
        // m=2, k=8, omega = sqrt(8/2) = 2. x(t) = cos(2t).
        let h = HarmonicOscillator { mass: 2.0, k_spring: 8.0 };
        let dt = 0.0005_f64;
        let n = 500;
        let t: Vec<f64> = (0..n).map(|i| (i as f64) * dt).collect();
        let x: Vec<f64> = t.iter().map(|tv| (2.0 * tv).cos()).collect();
        let res = euler_lagrange_residual(&h, &x, &t).unwrap();
        assert!(res < 1e-2, "residual={}", res);
    }

    #[test]
    fn short_trajectory_under_five_points_errors() {
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        let err = euler_lagrange_residual(
            &h,
            &[1.0, 2.0, 3.0, 4.0],
            &[0.0, 0.1, 0.2, 0.3],
        )
        .unwrap_err();
        assert_eq!(err, ActionError::EmptyTrajectory);
    }

    #[test]
    fn non_positive_dt_errors() {
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        let err = euler_lagrange_residual(
            &h,
            &[1.0; 5],
            &[0.0; 5],
        )
        .unwrap_err();
        assert!(matches!(err, ActionError::NonPositiveDt { .. }));
    }

    #[test]
    fn linear_trajectory_violates_harmonic_eom() {
        // x(t) = t — linear, not periodic; harmonic restoring force
        // makes the residual nonzero.
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        let dt = 0.001_f64;
        let n = 200;
        let t: Vec<f64> = (0..n).map(|i| (i as f64) * dt).collect();
        let x: Vec<f64> = t.clone();
        let res = euler_lagrange_residual(&h, &x, &t).unwrap();
        assert!(res > 0.05, "residual={}", res);
    }

    // ── FreeParticleLagrangian + solution generators (iter 87) ──────────────

    #[test]
    fn free_particle_partials_correct() {
        let p = FreeParticleLagrangian { mass: 3.0 };
        assert_eq!(p.evaluate(99.0, 2.0, 0.0), 6.0);  // ½·3·4 = 6
        assert_eq!(p.d_dx(99.0, 2.0, 0.0), 0.0);
        assert_eq!(p.d_d_xdot(99.0, 2.0, 0.0), 6.0); // m·v = 6
    }

    #[test]
    fn free_particle_constant_velocity_satisfies_eom() {
        let p = FreeParticleLagrangian { mass: 1.0 };
        let (x, t) = free_particle_solution(0.0, 1.5, 200, 0.001).unwrap();
        let res = euler_lagrange_residual(&p, &x, &t).unwrap();
        // Linear trajectory: every finite-difference derivative is exact;
        // residual should be ~0.
        assert!(res < 1e-9, "residual={}", res);
    }

    #[test]
    fn free_particle_cosine_violates_eom() {
        // Wrong trajectory for free particle: cosine — non-constant velocity.
        let p = FreeParticleLagrangian { mass: 1.0 };
        let (x, t) = harmonic_oscillator_solution(1.0, 1.0, 200, 0.001).unwrap();
        let res = euler_lagrange_residual(&p, &x, &t).unwrap();
        assert!(res > 0.01, "expected large residual, got {}", res);
    }

    #[test]
    fn harmonic_solution_generator_matches_inline_cosine_test() {
        // Reproduces `cosine_trajectory_satisfies_harmonic_oscillator_eom`
        // via the generator API to prove the helper is equivalent.
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        let (x, t) = harmonic_oscillator_solution(1.0, 1.0, 200, 0.001).unwrap();
        let res = euler_lagrange_residual(&h, &x, &t).unwrap();
        assert!(res < 1e-3, "residual={}", res);
    }

    #[test]
    fn harmonic_solution_generator_rejects_bad_inputs() {
        assert!(matches!(
            harmonic_oscillator_solution(1.0, 1.0, 200, 0.0).unwrap_err(),
            ActionError::NonPositiveDt { .. }
        ));
        assert!(matches!(
            harmonic_oscillator_solution(1.0, 1.0, 3, 0.001).unwrap_err(),
            ActionError::EmptyTrajectory
        ));
    }

    #[test]
    fn free_particle_solution_rejects_bad_inputs() {
        assert!(matches!(
            free_particle_solution(0.0, 1.0, 200, -0.5).unwrap_err(),
            ActionError::NonPositiveDt { .. }
        ));
        assert!(matches!(
            free_particle_solution(0.0, 1.0, 4, 0.001).unwrap_err(),
            ActionError::EmptyTrajectory
        ));
    }

    #[test]
    fn free_particle_zero_velocity_is_also_a_solution() {
        let p = FreeParticleLagrangian { mass: 1.0 };
        let (x, t) = free_particle_solution(7.0, 0.0, 200, 0.001).unwrap();
        let res = euler_lagrange_residual(&p, &x, &t).unwrap();
        assert!(res < 1e-9);
        // All positions equal x0.
        assert!(x.iter().all(|&v| (v - 7.0).abs() < 1e-12));
    }

    // ── diagnostic surface (iter 171) ────────────────────────────────────────

    #[test]
    fn action_error_cause_distinct() {
        let variants = [
            ActionError::EmptyTrajectory,
            ActionError::LengthMismatch { x: 1, t: 2 },
            ActionError::NonUniformTimestep { i: 0, dt_here: 0.1, dt_zero: 0.2 },
            ActionError::NonPositiveDt { dt: 0.0 },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 4);
    }

    #[test]
    fn action_error_classifiers_partition() {
        let variants = [
            ActionError::EmptyTrajectory,
            ActionError::LengthMismatch { x: 1, t: 2 },
            ActionError::NonUniformTimestep { i: 0, dt_here: 0.1, dt_zero: 0.2 },
            ActionError::NonPositiveDt { dt: 0.0 },
        ];
        // Cross-surface invariant: is_shape_error XOR is_timestep_error.
        for e in variants {
            assert_ne!(e.is_shape_error(), e.is_timestep_error());
        }
        assert_eq!(variants.iter().filter(|e| e.is_shape_error()).count(), 2);
        assert_eq!(variants.iter().filter(|e| e.is_timestep_error()).count(), 2);
    }

    #[test]
    fn harmonic_oscillator_omega_matches_sqrt_k_over_m() {
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        assert!((h.omega() - 1.0).abs() < 1e-12);
        let h = HarmonicOscillator { mass: 2.0, k_spring: 8.0 };
        assert!((h.omega() - 2.0).abs() < 1e-12); // sqrt(8/2) = 2
        let h = HarmonicOscillator { mass: 4.0, k_spring: 1.0 };
        assert!((h.omega() - 0.5).abs() < 1e-12); // sqrt(0.25) = 0.5
    }

    #[test]
    fn harmonic_oscillator_omega_squared_matches_k_over_m_invariant() {
        // Cross-surface invariant: omega² = k/m.
        for &(m, k) in &[(1.0_f64, 1.0), (2.0, 8.0), (4.0, 1.0), (0.5, 50.0)] {
            let h = HarmonicOscillator { mass: m, k_spring: k };
            let om = h.omega();
            assert!((om * om - k / m).abs() < 1e-9);
        }
    }

    #[test]
    fn harmonic_total_energy_at_rest_zero_state_is_zero() {
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        assert_eq!(h.total_energy(0.0, 0.0), 0.0);
    }

    #[test]
    fn harmonic_total_energy_pure_kinetic() {
        // x = 0, x_dot = 2 → KE = ½·1·4 = 2, PE = 0.
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        assert!((h.total_energy(0.0, 2.0) - 2.0).abs() < 1e-12);
    }

    #[test]
    fn harmonic_total_energy_pure_potential() {
        // x = 3, x_dot = 0 → KE = 0, PE = ½·1·9 = 4.5.
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        assert!((h.total_energy(3.0, 0.0) - 4.5).abs() < 1e-12);
    }

    #[test]
    fn harmonic_total_energy_conserved_along_cosine_solution() {
        // Cross-surface invariant (Noether): for x(t) = A·cos(ωt),
        // total_energy(x, ẋ) = constant = ½·k·A².
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        let amplitude = 2.0_f64;
        let omega = h.omega();
        let expected_energy = 0.5 * h.k_spring * amplitude * amplitude;
        for i in 0..20 {
            let t = i as f64 * 0.1;
            let x = amplitude * (omega * t).cos();
            let x_dot = -amplitude * omega * (omega * t).sin();
            let e = h.total_energy(x, x_dot);
            assert!((e - expected_energy).abs() < 1e-9, "t={} e={}", t, e);
        }
    }

    #[test]
    fn free_particle_kinetic_energy_matches_evaluate() {
        // Cross-surface invariant: KE = L (no potential for free particle).
        let p = FreeParticleLagrangian { mass: 2.0 };
        for v in &[-3.0_f64, 0.0, 1.5, 7.0] {
            let ke = p.kinetic_energy(*v);
            let l = p.evaluate(99.0, *v, 0.0); // x and t don't matter
            assert!((ke - l).abs() < 1e-12);
        }
    }

    #[test]
    fn free_particle_kinetic_energy_at_zero_velocity_is_zero() {
        let p = FreeParticleLagrangian { mass: 5.0 };
        assert_eq!(p.kinetic_energy(0.0), 0.0);
    }

    #[test]
    fn real_action_error_carries_matching_cause() {
        // Cross-surface: euler_lagrange_residual errors carry matching cause().
        let h = HarmonicOscillator { mass: 1.0, k_spring: 1.0 };
        let err = euler_lagrange_residual(&h, &[], &[]).unwrap_err();
        assert_eq!(err.cause(), "empty_trajectory");
        assert!(err.is_shape_error());

        let err = euler_lagrange_residual(&h, &[1.0, 2.0, 3.0], &[0.0, 1.0]).unwrap_err();
        assert_eq!(err.cause(), "length_mismatch");
        assert!(err.is_shape_error());

        let err = euler_lagrange_residual(&h, &[1.0; 5], &[0.0; 5]).unwrap_err();
        assert_eq!(err.cause(), "non_positive_dt");
        assert!(err.is_timestep_error());
    }
}
