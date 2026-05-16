//! Source:
//! - Kuramoto, Y., "Self-entrainment of a population of coupled non-linear
//!   oscillators", International Symposium on Mathematical Problems in
//!   Theoretical Physics, 1975 — canonical model:
//!   `dθ_i/dt = ω_i + (K/N) · Σ_j sin(θ_j − θ_i)`.
//! - Dörfler & Bullo, "Synchronization in complex networks of phase
//!   oscillators: A survey", Automatica 50(6), 2014 — exact synchronization
//!   thresholds the ACS doctrine cites.
//! - `docs/fusion/jordan's research/kimis deep research/acs_meta_layer.md`
//!   — ACS cellular-resonance protocol grounded in this model.
//!
//! # J5 #1 — Kuramoto synchronization substrate (CPU reference)
//!
//! N phase oscillators on the unit circle with intrinsic frequencies ω_i.
//! Mean-field coupling pulls each phase toward the collective average; if
//! the coupling exceeds the critical threshold `K_c = 2 / (π · g(0))`,
//! the network synchronizes. The substrate floor owns:
//!
//! - The state container ([`KuramotoNetwork`]) + Euler integration step.
//! - The order parameter `r · e^{iψ} = (1/N) · Σ_j e^{iθ_j}` —
//!   `r ∈ [0, 1]` measures coherence (0 = incoherent, 1 = fully synced).
//!
//! Real adapters need adaptive timestepping + the higher-order
//! Strogatz-style ansatz for the asymptotic `r(K)`; substrate floor
//! stops at forward Euler and the raw mean-field sum.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct KuramotoOscillator {
    pub phase: f32,
    pub intrinsic_freq: f32,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct KuramotoNetwork {
    pub oscillators: Vec<KuramotoOscillator>,
    pub coupling: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct OrderParameter {
    /// Magnitude in `[0, 1]`.
    pub r: f32,
    /// Mean phase in radians.
    pub psi: f32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum KuramotoError {
    EmptyNetwork,
    NonPositiveDt { dt: f32 },
}

/// Forward-Euler step of `dθ_i/dt = ω_i + (K/N) · Σ_j sin(θ_j − θ_i)`.
/// Mutates the network's phases in place.
pub fn kuramoto_step(network: &mut KuramotoNetwork, dt: f32) -> Result<(), KuramotoError> {
    if network.oscillators.is_empty() {
        return Err(KuramotoError::EmptyNetwork);
    }
    if dt <= 0.0 {
        return Err(KuramotoError::NonPositiveDt { dt });
    }
    let n = network.oscillators.len() as f32;
    let phases: Vec<f32> = network.oscillators.iter().map(|o| o.phase).collect();
    for (i, osc) in network.oscillators.iter_mut().enumerate() {
        let mut coupling_sum: f32 = 0.0;
        for &p_j in &phases {
            coupling_sum += (p_j - phases[i]).sin();
        }
        let d_theta = osc.intrinsic_freq + (network.coupling / n) * coupling_sum;
        osc.phase += dt * d_theta;
    }
    Ok(())
}

/// Dörfler-Bullo critical coupling: `K_c = 2 / (π · g(0))`, where
/// `g(0)` is the natural-frequency distribution's density at zero.
/// For a uniform `[-Ω, Ω]` distribution `g(0) = 1 / (2Ω)`, so
/// `K_c = 4Ω/π`. For a normal `N(0, σ²)` distribution `g(0) =
/// 1/(σ·sqrt(2π))`, so `K_c = 2σ·sqrt(2π)/π = σ·sqrt(8/π)`.
///
/// Callers compute `g(0)` themselves and pass it in. Returns
/// `None` for non-finite or non-positive density (no useful K_c
/// exists in those cases).
pub fn critical_coupling_kc(natural_freq_density_at_zero: f32) -> Option<f32> {
    if !natural_freq_density_at_zero.is_finite() {
        return None;
    }
    if natural_freq_density_at_zero <= 0.0 {
        return None;
    }
    Some(2.0 / (std::f32::consts::PI * natural_freq_density_at_zero))
}

#[derive(Clone, Debug, PartialEq)]
pub struct SyncOutcome {
    pub final_r: f32,
    pub steps_taken: u32,
    pub reached_target: bool,
}

/// Step the network forward until the order parameter `r` reaches
/// `target_r` OR `max_steps` steps have elapsed. Returns the
/// outcome (final `r`, steps taken, whether target was met).
/// Rejects `target_r ∉ [0, 1]`.
pub fn run_until_sync(
    network: &mut KuramotoNetwork,
    target_r: f32,
    max_steps: u32,
    dt: f32,
) -> Result<SyncOutcome, KuramotoError> {
    if !target_r.is_finite() || !(0.0..=1.0).contains(&target_r) {
        return Err(KuramotoError::NonPositiveDt { dt: target_r });
    }
    let initial = order_parameter(network)?;
    if initial.r >= target_r {
        return Ok(SyncOutcome {
            final_r: initial.r,
            steps_taken: 0,
            reached_target: true,
        });
    }
    for step in 1..=max_steps {
        kuramoto_step(network, dt)?;
        let op = order_parameter(network)?;
        if op.r >= target_r {
            return Ok(SyncOutcome {
                final_r: op.r,
                steps_taken: step,
                reached_target: true,
            });
        }
    }
    let final_op = order_parameter(network)?;
    Ok(SyncOutcome {
        final_r: final_op.r,
        steps_taken: max_steps,
        reached_target: false,
    })
}

/// Compute `r · e^{iψ} = (1/N) · Σ_j e^{iθ_j}`.
pub fn order_parameter(network: &KuramotoNetwork) -> Result<OrderParameter, KuramotoError> {
    if network.oscillators.is_empty() {
        return Err(KuramotoError::EmptyNetwork);
    }
    let n = network.oscillators.len() as f32;
    let mut sum_cos: f32 = 0.0;
    let mut sum_sin: f32 = 0.0;
    for osc in &network.oscillators {
        sum_cos += osc.phase.cos();
        sum_sin += osc.phase.sin();
    }
    sum_cos /= n;
    sum_sin /= n;
    let r = (sum_cos * sum_cos + sum_sin * sum_sin).sqrt();
    let psi = sum_sin.atan2(sum_cos);
    Ok(OrderParameter { r, psi })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn uniform_network(n: usize, freq: f32, coupling: f32) -> KuramotoNetwork {
        KuramotoNetwork {
            oscillators: (0..n)
                .map(|i| KuramotoOscillator {
                    phase: (i as f32) * std::f32::consts::TAU / (n as f32),
                    intrinsic_freq: freq,
                })
                .collect(),
            coupling,
        }
    }

    #[test]
    fn empty_network_step_errors() {
        let mut net = KuramotoNetwork {
            oscillators: vec![],
            coupling: 1.0,
        };
        let err = kuramoto_step(&mut net, 0.01).unwrap_err();
        assert_eq!(err, KuramotoError::EmptyNetwork);
    }

    #[test]
    fn non_positive_dt_rejected() {
        let mut net = uniform_network(2, 1.0, 1.0);
        let err = kuramoto_step(&mut net, 0.0).unwrap_err();
        assert_eq!(err, KuramotoError::NonPositiveDt { dt: 0.0 });
    }

    #[test]
    fn single_oscillator_drifts_at_intrinsic_freq() {
        let mut net = KuramotoNetwork {
            oscillators: vec![KuramotoOscillator { phase: 0.0, intrinsic_freq: 1.0 }],
            coupling: 5.0,
        };
        kuramoto_step(&mut net, 0.1).unwrap();
        assert!((net.oscillators[0].phase - 0.1).abs() < 1e-6);
    }

    #[test]
    fn identical_phases_at_zero_coupling_drift_independently() {
        let mut net = KuramotoNetwork {
            oscillators: vec![
                KuramotoOscillator { phase: 0.0, intrinsic_freq: 1.0 },
                KuramotoOscillator { phase: 0.0, intrinsic_freq: 2.0 },
            ],
            coupling: 0.0,
        };
        for _ in 0..10 {
            kuramoto_step(&mut net, 0.01).unwrap();
        }
        let dp = net.oscillators[1].phase - net.oscillators[0].phase;
        assert!((dp - 0.1).abs() < 1e-4);
    }

    #[test]
    fn order_parameter_one_for_aligned_phases() {
        let net = KuramotoNetwork {
            oscillators: vec![
                KuramotoOscillator { phase: 1.5, intrinsic_freq: 0.0 },
                KuramotoOscillator { phase: 1.5, intrinsic_freq: 0.0 },
                KuramotoOscillator { phase: 1.5, intrinsic_freq: 0.0 },
            ],
            coupling: 0.0,
        };
        let op = order_parameter(&net).unwrap();
        assert!((op.r - 1.0).abs() < 1e-6);
    }

    #[test]
    fn order_parameter_zero_for_evenly_spaced_phases() {
        let n = 8;
        let net = uniform_network(n, 0.0, 0.0);
        let op = order_parameter(&net).unwrap();
        assert!(op.r < 1e-5);
    }

    #[test]
    fn strong_coupling_increases_order_parameter() {
        let mut net = uniform_network(8, 0.5, 5.0);
        let r_initial = order_parameter(&net).unwrap().r;
        for _ in 0..2000 {
            kuramoto_step(&mut net, 0.01).unwrap();
        }
        let r_final = order_parameter(&net).unwrap().r;
        assert!(r_final > r_initial + 0.5, "r_initial={}, r_final={}", r_initial, r_final);
    }

    #[test]
    fn zero_coupling_does_not_synchronize_dispersed_starts() {
        let mut net = uniform_network(8, 0.0, 0.0);
        let r_initial = order_parameter(&net).unwrap().r;
        for _ in 0..100 {
            kuramoto_step(&mut net, 0.01).unwrap();
        }
        let r_final = order_parameter(&net).unwrap().r;
        assert!((r_final - r_initial).abs() < 1e-4);
    }

    #[test]
    fn order_parameter_psi_matches_mean_phase_for_aligned() {
        let net = KuramotoNetwork {
            oscillators: vec![
                KuramotoOscillator { phase: 0.7, intrinsic_freq: 0.0 },
                KuramotoOscillator { phase: 0.7, intrinsic_freq: 0.0 },
            ],
            coupling: 0.0,
        };
        let op = order_parameter(&net).unwrap();
        assert!((op.psi - 0.7).abs() < 1e-5);
    }

    #[test]
    fn negative_coupling_disperses_phases() {
        let net0 = KuramotoNetwork {
            oscillators: vec![
                KuramotoOscillator { phase: 0.0, intrinsic_freq: 0.0 },
                KuramotoOscillator { phase: 0.1, intrinsic_freq: 0.0 },
                KuramotoOscillator { phase: -0.1, intrinsic_freq: 0.0 },
            ],
            coupling: -3.0,
        };
        let r_initial = order_parameter(&net0).unwrap().r;
        let mut net = net0.clone();
        for _ in 0..500 {
            kuramoto_step(&mut net, 0.01).unwrap();
        }
        let r_final = order_parameter(&net).unwrap().r;
        assert!(r_final < r_initial, "r_initial={}, r_final={}", r_initial, r_final);
    }

    #[test]
    fn network_roundtrips_through_serde_json() {
        let net = uniform_network(3, 1.0, 0.5);
        let json = serde_json::to_string(&net).unwrap();
        let back: KuramotoNetwork = serde_json::from_str(&json).unwrap();
        assert_eq!(net, back);
    }

    #[test]
    fn order_parameter_empty_errors() {
        let net = KuramotoNetwork { oscillators: vec![], coupling: 0.0 };
        let err = order_parameter(&net).unwrap_err();
        assert_eq!(err, KuramotoError::EmptyNetwork);
    }

    #[test]
    fn coupling_sum_self_term_is_zero_so_self_doesnt_inflate_order() {
        let mut net = KuramotoNetwork {
            oscillators: vec![KuramotoOscillator { phase: 1.0, intrinsic_freq: 0.0 }],
            coupling: 100.0,
        };
        let p_before = net.oscillators[0].phase;
        kuramoto_step(&mut net, 0.01).unwrap();
        assert!((net.oscillators[0].phase - p_before).abs() < 1e-6);
    }

    // ── critical_coupling_kc + run_until_sync tests (iter 109) ──────────────

    #[test]
    fn kc_uniform_distribution_matches_4_omega_over_pi() {
        // For uniform [-Ω, Ω], g(0) = 1/(2Ω), so K_c = 2/(π · 1/(2Ω)) = 4Ω/π.
        // With Ω = 1, K_c = 4/π ≈ 1.273.
        let g_zero = 1.0 / (2.0 * 1.0);
        let kc = critical_coupling_kc(g_zero).unwrap();
        assert!((kc - 4.0 / std::f32::consts::PI).abs() < 1e-6);
    }

    #[test]
    fn kc_normal_distribution_matches_sigma_sqrt_8_pi() {
        // For N(0, σ²), g(0) = 1/(σ·sqrt(2π)), so K_c = σ·sqrt(8/π).
        // With σ = 1, K_c = sqrt(8/π) ≈ 1.596.
        let sigma = 1.0_f32;
        let g_zero = 1.0 / (sigma * (2.0 * std::f32::consts::PI).sqrt());
        let kc = critical_coupling_kc(g_zero).unwrap();
        let expected = sigma * (8.0 / std::f32::consts::PI).sqrt();
        assert!((kc - expected).abs() < 1e-5);
    }

    #[test]
    fn kc_zero_density_returns_none() {
        assert!(critical_coupling_kc(0.0).is_none());
        assert!(critical_coupling_kc(-0.1).is_none());
        assert!(critical_coupling_kc(f32::NAN).is_none());
    }

    #[test]
    fn run_until_sync_reaches_target_under_strong_coupling() {
        // All oscillators have the same intrinsic frequency (zero
        // dispersion). Strong coupling and they sync instantly to
        // their mean phase. Target r = 0.99 is reachable.
        let mut net = uniform_network(8, 0.0, 5.0);
        let outcome = run_until_sync(&mut net, 0.99, 500, 0.05).unwrap();
        assert!(
            outcome.reached_target,
            "should sync; final_r = {}, steps = {}",
            outcome.final_r,
            outcome.steps_taken
        );
        assert!(outcome.final_r >= 0.99);
    }

    #[test]
    fn run_until_sync_returns_immediately_if_already_synced() {
        // Phases all equal → r = 1.0 immediately.
        let mut net = KuramotoNetwork {
            oscillators: vec![
                KuramotoOscillator { phase: 0.0, intrinsic_freq: 0.0 },
                KuramotoOscillator { phase: 0.0, intrinsic_freq: 0.0 },
            ],
            coupling: 0.0,
        };
        let outcome = run_until_sync(&mut net, 0.9, 100, 0.1).unwrap();
        assert!(outcome.reached_target);
        assert_eq!(outcome.steps_taken, 0);
    }

    #[test]
    fn run_until_sync_times_out_below_threshold() {
        // Zero coupling + spread phases → never syncs.
        let mut net = uniform_network(8, 1.0, 0.0);
        let outcome = run_until_sync(&mut net, 0.95, 50, 0.01).unwrap();
        assert!(!outcome.reached_target);
        assert_eq!(outcome.steps_taken, 50);
    }

    #[test]
    fn run_until_sync_invalid_target_rejected() {
        let mut net = uniform_network(2, 0.0, 1.0);
        assert!(run_until_sync(&mut net, 1.5, 10, 0.01).is_err());
        assert!(run_until_sync(&mut net, -0.1, 10, 0.01).is_err());
        assert!(run_until_sync(&mut net, f32::NAN, 10, 0.01).is_err());
    }
}
