//! HELIOS V5 E5 — Duplex Fusion.
//!
//! HELIOS-E5 guard
//!
//! `ε_ℓ^fused ≤ (1 − ρ_ℓ*) · ε_ℓ⁰ + ρ_ℓ* · ε_ℓ¹ + ‖ρ_ℓ − ρ_ℓ*‖_∞ ·
//!  ‖P_{1,ℓ} − P_{0,ℓ}‖_∞`. Architecture-level not Mamba-specific.

use serde::{Deserialize, Serialize};

/// E5 fusion parameters.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct DuplexFusionInputs {
    pub eps_path0: f32,
    pub eps_path1: f32,
    pub rho_actual: f32,
    pub rho_target: f32,
    pub p_diff_inf_norm: f32,
}

/// Compute the E5 fused-error upper bound.
pub fn e5_fused_error_bound(inputs: &DuplexFusionInputs) -> f32 {
    let r = inputs.rho_target.clamp(0.0, 1.0);
    let term_path = (1.0 - r) * inputs.eps_path0 + r * inputs.eps_path1;
    let term_drift = (inputs.rho_actual - inputs.rho_target).abs() * inputs.p_diff_inf_norm;
    term_path + term_drift
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fused_bound_at_rho_zero_is_path0() {
        let i = DuplexFusionInputs {
            eps_path0: 0.5,
            eps_path1: 0.1,
            rho_actual: 0.0,
            rho_target: 0.0,
            p_diff_inf_norm: 1.0,
        };
        assert!((e5_fused_error_bound(&i) - 0.5).abs() < 1e-6);
    }

    #[test]
    fn fused_bound_at_rho_one_is_path1() {
        let i = DuplexFusionInputs {
            eps_path0: 0.5,
            eps_path1: 0.1,
            rho_actual: 1.0,
            rho_target: 1.0,
            p_diff_inf_norm: 1.0,
        };
        assert!((e5_fused_error_bound(&i) - 0.1).abs() < 1e-6);
    }

    #[test]
    fn drift_term_inflates_bound_when_rho_actual_diverges() {
        let i_clean = DuplexFusionInputs {
            eps_path0: 0.5,
            eps_path1: 0.1,
            rho_actual: 0.5,
            rho_target: 0.5,
            p_diff_inf_norm: 1.0,
        };
        let i_drift = DuplexFusionInputs {
            eps_path0: 0.5,
            eps_path1: 0.1,
            rho_actual: 0.8,
            rho_target: 0.5,
            p_diff_inf_norm: 1.0,
        };
        assert!(e5_fused_error_bound(&i_drift) > e5_fused_error_bound(&i_clean));
    }
}
