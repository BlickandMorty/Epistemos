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
}
