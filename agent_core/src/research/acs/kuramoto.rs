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
}
