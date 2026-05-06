//! HELIOS V5 — Self-Evolving Extension (L_SE) substrate (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-L-SE guard
//!
//! Per HELIOS v4 preservation `source_docs/epistemos_definitive_master.md`
//! §"PART IV: THE SELF-EVOLVING EXTENSION (L_SE)".
//!
//! L_SE is an extension of the 5-tier shadow-memory hierarchy
//! ([`crate::shadow_memory::MemoryTier`]). It runs ALONGSIDE L0-L4
//! rather than ordering them — it's the "self-evolving" tier where
//! online surprise-gradient updates (Titans-MAC) and nightly DoRA
//! consolidation (SEAL) accumulate user-specific patterns without
//! ever modifying the base model.
//!
//! ## Doctrinal anchor
//!
//! From the definitive master §IV:
//!
//! > "Base Qwen3-8B-4bit weights NEVER change. This protects from
//! >  catastrophic forgetting at the base; only the LMM accumulates."
//!
//! ## Hybrid (Titans-MAC online + SEAL-DoRA nightly)
//!
//! - **Titans-MAC** (arXiv:2501.00663): online neural long-term
//!   memory module slotted into L2. The LMM REPLACES the static
//!   FRP basis with a learnable surprise-driven memory whose
//!   retrieval IS the L2 sketch query.
//!
//! - **SEAL-DoRA** (arXiv:2506.10943): overnight consolidation into
//!   a per-user DoRA-parameterized adapter; outer-RL on self-edits.
//!   Fused after K nights.
//!
//! "Bet on the interface, not the implementation."
//!
//! ## Surprise gradient as unified confidence
//!
//! Per definitive master §IV.3, the surprise gradient
//!   g_t = ∇_M L_assoc(M_t; x_t)
//! is the unified confidence signal that supersedes all prior ad-hoc
//! calibrations across the 5-tier hierarchy.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// Mechanism candidates audited in definitive master §IV.1.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LseMechanism {
    /// SEAL — outer-RL on self-edits + LoRA per arXiv:2506.10943.
    /// Yes Mac fit (mlx-lm.lora). Acknowledged forgetting. ~50%
    /// obsolescence risk by EOY 2026.
    Seal,
    /// TTT-Linear/MLP — inner-loop SGD on hidden state = mini-net
    /// per arXiv:2407.04620. Yes Mac fit (MLX autograd). Bounded
    /// forgetting by capacity. ~20% obsolescence risk.
    TttLinearOrMlp,
    /// Titans MAC/MAG/MAL — surprise-gradient LMM + momentum +
    /// decay per arXiv:2501.00663. Yes Mac fit (~1B LMM). Decay
    /// mitigates forgetting. ~70% obsolescence risk (Hope/NL
    /// successor anticipated).
    TitansMacMagMal,
    /// Soft prompts / Mem0 baseline — no weight updates; growing
    /// prefix. Trivial fit; no forgetting. N/A obsolescence.
    SoftPromptsMem0,
}

impl LseMechanism {
    /// arXiv id (or "various" for the soft-prompt baseline).
    pub fn arxiv_anchor(self) -> &'static str {
        match self {
            LseMechanism::Seal => "2506.10943",
            LseMechanism::TttLinearOrMlp => "2407.04620",
            LseMechanism::TitansMacMagMal => "2501.00663",
            LseMechanism::SoftPromptsMem0 => "various",
        }
    }

    /// Returns true when the mechanism updates model parameters
    /// (excludes the soft-prompt baseline).
    pub fn updates_parameters(self) -> bool {
        !matches!(self, LseMechanism::SoftPromptsMem0)
    }
}

/// Two-phase L_SE pipeline per the canonical recommendation
/// (definitive master §IV.2): Titans-MAC online + SEAL-DoRA nightly.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LsePhase {
    /// Online phase — Titans-MAC LMM ingests every token, produces
    /// surprise gradient, updates online, emits memory-context
    /// vector that L2 retrieves against.
    OnlineTitansMac,
    /// Nightly phase — SEAL outer loop generates self-edits from
    /// the day's high-surprise events, reinforces positive-reward
    /// edits via ReST^EM, produces a DoRA delta.
    NightlySealDora,
}

/// Surprise-gradient escalation routing per definitive master §IV.3.
/// Names which tier the surprise signal feeds into next.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SurpriseEscalation {
    /// Inhibit eviction of about-to-be-surprising L0 tokens.
    LseToL0EvictInhibit,
    /// Reweight L1 Sherry codec prior per-user via LMM gating.
    LseToL1CodecReweight,
    /// LMM REPLACES the static FRP basis as L2 retrieval kernel.
    LseSwapsL2RetrievalKernel,
    /// Surprise > θ triggers L3 SSD oracle fetch.
    LseToL3SsdFetch,
    /// Surprise > θ_high after L3 fetch triggers L4 Hermes-405B.
    LseToL4HermesEscalate,
    /// Hermes responses added to the LMM training distribution.
    L4ToLseFeedback,
}

/// Drift-bound parameters for the T_SE term of the Master Inequality
/// (definitive master §IV.4).
///
/// Per Bottou-Curtis-Nocedal Theorem 4.7 + SEAL 2506.10943:
///   ‖f(x; M̂) − f(x; M*)‖ ≤ L_M · ‖M̂_T − M*‖
/// with
///   ‖M̂_T − M*‖ ≤ √(η²·E[‖g‖²]·T_eff + (1−α)²·‖M_0‖² + λ_decay²·H(M))
///   + ‖ΔW_SE^nightly‖_F
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct TSeBoundParams {
    /// Inner learning rate η.
    pub eta: f32,
    /// Expected squared gradient norm E[‖g‖²].
    pub expected_gradient_sq_norm: f32,
    /// Effective inner steps per block T_eff.
    pub t_eff: u32,
    /// Momentum coefficient α ∈ [0, 1).
    pub alpha: f32,
    /// Memory norm ‖M_0‖ at start of block.
    pub memory_initial_norm: f32,
    /// Weight decay coefficient λ_decay.
    pub lambda_decay: f32,
    /// Memory entropy H(M).
    pub memory_entropy: f32,
    /// Frobenius norm of the nightly SEAL DoRA delta.
    pub nightly_dora_delta_frobenius: f32,
    /// Lipschitz constant L_M of the network with respect to M.
    pub lipschitz_constant_lm: f32,
}

impl TSeBoundParams {
    /// Compute the upper-bound side of T_SE per the §IV.4 inequality.
    pub fn upper_bound(&self) -> f32 {
        // Inner term: √(η²·E[‖g‖²]·T_eff + (1−α)²·‖M_0‖² + λ_decay²·H(M))
        let inner_sq = self.eta * self.eta * self.expected_gradient_sq_norm * self.t_eff as f32
            + (1.0 - self.alpha).powi(2) * self.memory_initial_norm * self.memory_initial_norm
            + self.lambda_decay * self.lambda_decay * self.memory_entropy;
        let inner = inner_sq.sqrt();
        // Plus the nightly SEAL DoRA delta Frobenius norm.
        let m_drift = inner + self.nightly_dora_delta_frobenius;
        // Times the network Lipschitz constant.
        self.lipschitz_constant_lm * m_drift
    }
}

/// All four L_SE mechanism candidates from §IV.1 in canonical order.
pub const ALL_MECHANISMS: [LseMechanism; 4] = [
    LseMechanism::Seal,
    LseMechanism::TttLinearOrMlp,
    LseMechanism::TitansMacMagMal,
    LseMechanism::SoftPromptsMem0,
];

/// Both phases of the canonical L_SE pipeline.
pub const ALL_PHASES: [LsePhase; 2] =
    [LsePhase::OnlineTitansMac, LsePhase::NightlySealDora];

/// All six surprise-gradient escalation paths.
pub const ALL_ESCALATIONS: [SurpriseEscalation; 6] = [
    SurpriseEscalation::LseToL0EvictInhibit,
    SurpriseEscalation::LseToL1CodecReweight,
    SurpriseEscalation::LseSwapsL2RetrievalKernel,
    SurpriseEscalation::LseToL3SsdFetch,
    SurpriseEscalation::LseToL4HermesEscalate,
    SurpriseEscalation::L4ToLseFeedback,
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn four_mechanisms_in_canonical_order() {
        assert_eq!(ALL_MECHANISMS.len(), 4);
        assert_eq!(ALL_MECHANISMS[0], LseMechanism::Seal);
        assert_eq!(ALL_MECHANISMS[3], LseMechanism::SoftPromptsMem0);
    }

    #[test]
    fn four_mechanisms_are_distinct() {
        let set: std::collections::HashSet<LseMechanism> =
            ALL_MECHANISMS.iter().copied().collect();
        assert_eq!(set.len(), 4);
    }

    #[test]
    fn three_active_mechanisms_update_parameters_baseline_does_not() {
        for m in ALL_MECHANISMS {
            if m == LseMechanism::SoftPromptsMem0 {
                assert!(!m.updates_parameters());
            } else {
                assert!(m.updates_parameters());
            }
        }
    }

    #[test]
    fn arxiv_anchors_match_canonical_doctrine() {
        assert_eq!(LseMechanism::Seal.arxiv_anchor(), "2506.10943");
        assert_eq!(LseMechanism::TttLinearOrMlp.arxiv_anchor(), "2407.04620");
        assert_eq!(LseMechanism::TitansMacMagMal.arxiv_anchor(), "2501.00663");
        assert_eq!(LseMechanism::SoftPromptsMem0.arxiv_anchor(), "various");
    }

    #[test]
    fn two_phases_are_distinct() {
        let set: std::collections::HashSet<LsePhase> =
            ALL_PHASES.iter().copied().collect();
        assert_eq!(set.len(), 2);
    }

    #[test]
    fn six_escalations_are_distinct() {
        let set: std::collections::HashSet<SurpriseEscalation> =
            ALL_ESCALATIONS.iter().copied().collect();
        assert_eq!(set.len(), 6);
    }

    #[test]
    fn t_se_upper_bound_zero_when_all_params_zero() {
        let p = TSeBoundParams {
            eta: 0.0,
            expected_gradient_sq_norm: 0.0,
            t_eff: 0,
            alpha: 0.0,
            memory_initial_norm: 0.0,
            lambda_decay: 0.0,
            memory_entropy: 0.0,
            nightly_dora_delta_frobenius: 0.0,
            lipschitz_constant_lm: 1.0,
        };
        assert_eq!(p.upper_bound(), 0.0);
    }

    #[test]
    fn t_se_upper_bound_scales_with_lipschitz_constant() {
        let mut p = TSeBoundParams {
            eta: 0.01,
            expected_gradient_sq_norm: 1.0,
            t_eff: 100,
            alpha: 0.9,
            memory_initial_norm: 1.0,
            lambda_decay: 1e-4,
            memory_entropy: 0.5,
            nightly_dora_delta_frobenius: 0.01,
            lipschitz_constant_lm: 1.0,
        };
        let bound1 = p.upper_bound();
        p.lipschitz_constant_lm = 10.0;
        let bound10 = p.upper_bound();
        assert!((bound10 - 10.0 * bound1).abs() < 1e-5);
    }

    #[test]
    fn t_se_upper_bound_dominated_by_nightly_dora_when_inner_zero() {
        let p = TSeBoundParams {
            eta: 0.0,
            expected_gradient_sq_norm: 0.0,
            t_eff: 0,
            alpha: 1.0,
            memory_initial_norm: 0.0,
            lambda_decay: 0.0,
            memory_entropy: 0.0,
            nightly_dora_delta_frobenius: 0.5,
            lipschitz_constant_lm: 1.0,
        };
        // Inner term = 0; bound = 1.0 · 0.5 = 0.5.
        assert!((p.upper_bound() - 0.5).abs() < 1e-6);
    }

    #[test]
    fn lse_mechanism_serializes_in_snake_case() {
        for (m, expected) in [
            (LseMechanism::Seal, "\"seal\""),
            (LseMechanism::TttLinearOrMlp, "\"ttt_linear_or_mlp\""),
            (LseMechanism::TitansMacMagMal, "\"titans_mac_mag_mal\""),
            (LseMechanism::SoftPromptsMem0, "\"soft_prompts_mem0\""),
        ] {
            assert_eq!(serde_json::to_string(&m).unwrap(), expected);
        }
    }

    #[test]
    fn lse_phase_serializes_in_snake_case() {
        for (p, expected) in [
            (LsePhase::OnlineTitansMac, "\"online_titans_mac\""),
            (LsePhase::NightlySealDora, "\"nightly_seal_dora\""),
        ] {
            assert_eq!(serde_json::to_string(&p).unwrap(), expected);
        }
    }

    #[test]
    fn round_trip_through_json_for_all_three_enums() {
        for m in ALL_MECHANISMS {
            let json = serde_json::to_string(&m).unwrap();
            let parsed: LseMechanism = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, m);
        }
        for p in ALL_PHASES {
            let json = serde_json::to_string(&p).unwrap();
            let parsed: LsePhase = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, p);
        }
        for e in ALL_ESCALATIONS {
            let json = serde_json::to_string(&e).unwrap();
            let parsed: SurpriseEscalation = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, e);
        }
    }
}
