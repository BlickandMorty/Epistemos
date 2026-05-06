//! HELIOS V6.1 — Interrupt-score equation substrate (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-INTERRUPT-SCORE guard
//!
//! Per `Epistemos V6_1 — Final Synthesis Lock` PART 2.2:
//!
//! ```text
//! u_t = α·H(p_t) + β·WBO_risk_t + γ·SheafResidual_t
//!     + δ·ToolNeed_t + ε·ConnectomeAlarm_t
//! ```
//!
//! Where:
//! - `α·H(p_t)` is the recurrent forecast's predictive entropy
//!   (semantic uncertainty)
//! - `β·WBO_risk_t` is the V5 work-budget-overrun risk term
//!   (continuity carry-forward)
//! - `γ·SheafResidual_t` is local consistency error from V5 sheaf
//!   machinery (continuity carry-forward — T2)
//! - `δ·ToolNeed_t` is the controller's estimate of tool-call need
//! - `ε·ConnectomeAlarm_t` is the Goodfire-VPD-derived signal
//!   (NEW in V6.1; ties Lane-3 PCF research to Lane-1 runtime gating)
//!
//! ## Three escalation levels per V6.1 §2.2
//!
//! - `u_t < τ_low` → pure recurrent step, zero attention/retrieval/tools
//! - `τ_low ≤ u_t < τ_high` → recall episode (sliding-window attention)
//! - `u_t ≥ τ_high` → full escalation (Atlas + tool + Heavy Mode)
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// Five canonical signal sources for the interrupt-score per V6.1 §2.2.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum InterruptSignalSource {
    /// α·H(p_t) — recurrent forecast predictive entropy.
    PredictiveEntropy,
    /// β·WBO_risk — V5 work-budget-overrun risk (carry-forward).
    WboRisk,
    /// γ·SheafResidual — local consistency error from V5 sheaf
    /// machinery (T2 carry-forward).
    SheafResidual,
    /// δ·ToolNeed — controller's tool-call need estimate.
    ToolNeed,
    /// ε·ConnectomeAlarm — Goodfire-VPD-derived component
    /// divergence signal (NEW in V6.1; bridges Lane 3 PCF to
    /// Lane 1 runtime).
    ConnectomeAlarm,
}

/// All five interrupt-score signal sources in canonical order.
pub const FIVE_SIGNALS: [InterruptSignalSource; 5] = [
    InterruptSignalSource::PredictiveEntropy,
    InterruptSignalSource::WboRisk,
    InterruptSignalSource::SheafResidual,
    InterruptSignalSource::ToolNeed,
    InterruptSignalSource::ConnectomeAlarm,
];

/// One interrupt-score sample at runtime.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct InterruptScore {
    pub h_predictive_entropy: f32,
    pub wbo_risk: f32,
    pub sheaf_residual: f32,
    pub tool_need: f32,
    pub connectome_alarm: f32,
}

/// Coefficients for the linear combination per V6.1 §2.2.
/// Per the doctrine, these are "learnable but constrained."
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct InterruptCoefficients {
    pub alpha: f32,
    pub beta: f32,
    pub gamma: f32,
    pub delta: f32,
    pub epsilon: f32,
}

impl InterruptCoefficients {
    /// Default uniform coefficients (1/5 each). Per the doctrine,
    /// these get tuned per workload via W40-class CI runs.
    pub const UNIFORM: InterruptCoefficients = InterruptCoefficients {
        alpha: 0.2,
        beta: 0.2,
        gamma: 0.2,
        delta: 0.2,
        epsilon: 0.2,
    };
}

impl InterruptScore {
    /// Compute u_t = α·H + β·WBO + γ·Sheaf + δ·Tool + ε·Connectome.
    pub fn compute(&self, coeffs: &InterruptCoefficients) -> f32 {
        coeffs.alpha * self.h_predictive_entropy
            + coeffs.beta * self.wbo_risk
            + coeffs.gamma * self.sheaf_residual
            + coeffs.delta * self.tool_need
            + coeffs.epsilon * self.connectome_alarm
    }
}

/// Three escalation levels per V6.1 §2.2.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EscalationLevel {
    /// `u_t < τ_low` — pure recurrent step. Zero attention,
    /// zero retrieval, zero tools.
    PureRecurrent,
    /// `τ_low ≤ u_t < τ_high` — recall episode. Sliding-window
    /// attention sentinel + pinned episodic anchors.
    RecallEpisode,
    /// `u_t ≥ τ_high` — full escalation. Atlas page fetch + tool
    /// call + connectome-RAG + possibly Heavy Mode parallel branches.
    FullEscalation,
}

/// Escalation thresholds per V6.1 §2.2.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct EscalationThresholds {
    pub tau_low: f32,
    pub tau_high: f32,
}

impl EscalationThresholds {
    /// Returns true when tau_low ≤ tau_high (well-formed thresholds).
    pub fn is_well_formed(&self) -> bool {
        self.tau_low.is_finite() && self.tau_high.is_finite() && self.tau_low <= self.tau_high
    }
}

/// Decide the escalation level from u_t and the thresholds per
/// V6.1 §2.2.
pub fn escalate(u_t: f32, thresholds: EscalationThresholds) -> EscalationLevel {
    if !u_t.is_finite() || !thresholds.is_well_formed() {
        return EscalationLevel::FullEscalation;
    }
    if u_t < thresholds.tau_low {
        EscalationLevel::PureRecurrent
    } else if u_t < thresholds.tau_high {
        EscalationLevel::RecallEpisode
    } else {
        EscalationLevel::FullEscalation
    }
}

/// T35 v6.1 falsifier threshold per V6.1 §2.3:
/// "If Epistemos's runtime fires escalation on more than ρ_max of
/// tokens on real workloads (say, ρ_max = 0.20), the architecture
/// has collapsed back to a static hybrid and the moat is gone."
pub const RHO_MAX_T35_V6_1: f32 = 0.20;

/// All three escalation levels in canonical V6.1 order.
pub const THREE_ESCALATION_LEVELS: [EscalationLevel; 3] = [
    EscalationLevel::PureRecurrent,
    EscalationLevel::RecallEpisode,
    EscalationLevel::FullEscalation,
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn five_signals_in_canonical_v6_1_order() {
        assert_eq!(FIVE_SIGNALS.len(), 5);
        assert_eq!(FIVE_SIGNALS[0], InterruptSignalSource::PredictiveEntropy);
        assert_eq!(FIVE_SIGNALS[4], InterruptSignalSource::ConnectomeAlarm);
    }

    #[test]
    fn five_signals_are_distinct() {
        let set: std::collections::HashSet<InterruptSignalSource> =
            FIVE_SIGNALS.iter().copied().collect();
        assert_eq!(set.len(), 5);
    }

    #[test]
    fn three_escalation_levels_are_distinct() {
        let set: std::collections::HashSet<EscalationLevel> =
            THREE_ESCALATION_LEVELS.iter().copied().collect();
        assert_eq!(set.len(), 3);
    }

    #[test]
    fn uniform_coefficients_sum_to_one() {
        let c = InterruptCoefficients::UNIFORM;
        let sum = c.alpha + c.beta + c.gamma + c.delta + c.epsilon;
        assert!((sum - 1.0).abs() < 1e-6);
    }

    #[test]
    fn rho_max_t35_v6_1_is_zero_point_2() {
        // Per V6.1 §2.3: if ρ > ρ_max, T35 falsified.
        assert_eq!(RHO_MAX_T35_V6_1, 0.20);
    }

    #[test]
    fn compute_zero_score_for_zero_signals() {
        let s = InterruptScore {
            h_predictive_entropy: 0.0,
            wbo_risk: 0.0,
            sheaf_residual: 0.0,
            tool_need: 0.0,
            connectome_alarm: 0.0,
        };
        assert_eq!(s.compute(&InterruptCoefficients::UNIFORM), 0.0);
    }

    #[test]
    fn compute_uniform_score_with_unit_signals() {
        let s = InterruptScore {
            h_predictive_entropy: 1.0,
            wbo_risk: 1.0,
            sheaf_residual: 1.0,
            tool_need: 1.0,
            connectome_alarm: 1.0,
        };
        // Uniform 1/5 × 5 = 1.0.
        let u = s.compute(&InterruptCoefficients::UNIFORM);
        assert!((u - 1.0).abs() < 1e-6);
    }

    #[test]
    fn well_formed_thresholds_have_low_below_high() {
        let t = EscalationThresholds { tau_low: 0.1, tau_high: 0.5 };
        assert!(t.is_well_formed());
        let bad = EscalationThresholds { tau_low: 0.5, tau_high: 0.1 };
        assert!(!bad.is_well_formed());
    }

    #[test]
    fn escalate_below_tau_low_yields_pure_recurrent() {
        let t = EscalationThresholds { tau_low: 0.1, tau_high: 0.5 };
        assert_eq!(escalate(0.05, t), EscalationLevel::PureRecurrent);
    }

    #[test]
    fn escalate_in_middle_band_yields_recall_episode() {
        let t = EscalationThresholds { tau_low: 0.1, tau_high: 0.5 };
        assert_eq!(escalate(0.3, t), EscalationLevel::RecallEpisode);
    }

    #[test]
    fn escalate_above_tau_high_yields_full_escalation() {
        let t = EscalationThresholds { tau_low: 0.1, tau_high: 0.5 };
        assert_eq!(escalate(0.8, t), EscalationLevel::FullEscalation);
    }

    #[test]
    fn escalate_at_tau_high_yields_full_escalation() {
        // Boundary: u_t == tau_high must escalate per V6.1 §2.2.
        let t = EscalationThresholds { tau_low: 0.1, tau_high: 0.5 };
        assert_eq!(escalate(0.5, t), EscalationLevel::FullEscalation);
    }

    #[test]
    fn escalate_nan_or_malformed_thresholds_default_full_escalation() {
        let t = EscalationThresholds { tau_low: 0.1, tau_high: 0.5 };
        // NaN u_t → safe default of FullEscalation
        assert_eq!(escalate(f32::NAN, t), EscalationLevel::FullEscalation);
        // Malformed thresholds → safe default of FullEscalation
        let bad = EscalationThresholds { tau_low: 0.5, tau_high: 0.1 };
        assert_eq!(escalate(0.3, bad), EscalationLevel::FullEscalation);
    }

    #[test]
    fn signal_source_serializes_in_snake_case() {
        assert_eq!(
            serde_json::to_string(&InterruptSignalSource::PredictiveEntropy).unwrap(),
            "\"predictive_entropy\""
        );
        assert_eq!(
            serde_json::to_string(&InterruptSignalSource::ConnectomeAlarm).unwrap(),
            "\"connectome_alarm\""
        );
    }

    #[test]
    fn escalation_level_serializes_in_snake_case() {
        for (level, expected) in [
            (EscalationLevel::PureRecurrent, "\"pure_recurrent\""),
            (EscalationLevel::RecallEpisode, "\"recall_episode\""),
            (EscalationLevel::FullEscalation, "\"full_escalation\""),
        ] {
            assert_eq!(serde_json::to_string(&level).unwrap(), expected);
        }
    }

    #[test]
    fn round_trip_through_json() {
        for s in FIVE_SIGNALS {
            let json = serde_json::to_string(&s).unwrap();
            let parsed: InterruptSignalSource = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, s);
        }
        for level in THREE_ESCALATION_LEVELS {
            let json = serde_json::to_string(&level).unwrap();
            let parsed: EscalationLevel = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, level);
        }
    }
}
