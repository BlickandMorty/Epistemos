//! HELIOS V5 — Cross-domain unification lens (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-CROSS-DOMAIN-LENS guard
//!
//! Per HELIOS v4 preservation `source_docs/helios_v3.md` Part-VII
//! "The Deeper Interdisciplinary Weave" + the §"5 names, one
//! substance" koan:
//!
//! > "Centers correspond to silicon's actual seams. Ship the kernel.
//! >  Measure relentlessly. Priority ceilings hold. The koan: the
//! >  residual stream is the prediction error; the prediction error
//! >  is the surprise gradient; the surprise gradient is the Koopman
//! >  mode; the Koopman mode is the free cumulant. **Five names, one
//! >  substance.**" — Architect-Artisan, 3am
//!
//! This module makes the koan typed: every entry of `CrossDomainLens`
//! names the SAME mathematical object viewed through a different
//! disciplinary lens.
//!
//! ## The five lenses
//!
//! - **ResidualStream** (Transformer interpretability) — bit-identical
//!   substrate of K, V at every layer per Qasim et al.
//!   arXiv:2603.19664.
//! - **PredictionError** (Predictive coding / Friston) — Rao-Ballard
//!   1999; the cortex minimizes precision-weighted prediction error.
//! - **SurpriseGradient** (Self-evolving / Titans) — ∂F/∂μ in
//!   Friston's free energy decomposition; the L_SE substrate's
//!   unified confidence signal.
//! - **KoopmanMode** (Dynamical systems / SSMs) — Koopman 1931 lift
//!   of nonlinear dynamics to a linear operator on observables;
//!   Mamba-2 A-matrix is a discrete-time Koopman operator.
//! - **FreeCumulant** (Free probability / Voiculescu 1985) — the
//!   noncommutative-probability invariant that S-transforms compose
//!   multiplicatively under free convolution.
//!
//! Five names, one substance.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// One of five cross-domain lenses on the same mathematical
/// substance.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CrossDomainLens {
    /// Transformer interpretability: residual stream as the
    /// substrate from which K, V are bit-identical projections.
    /// Anchor: Qasim et al. arXiv:2603.19664 ("KV-Direct").
    ResidualStream,
    /// Predictive coding: prediction error ε_t = x_t − μ_t with
    /// the LM as the generative model.
    /// Anchor: Rao-Ballard 1999 + Friston 2010.
    PredictionError,
    /// Self-evolving substrate: surprise gradient g_t = ∇_M
    /// L_assoc(M_t; x_t). Equivalent to Friston's free-energy
    /// gradient ∂F/∂μ at unit precision.
    /// Anchor: Behrouz et al. arXiv:2501.00663 (Titans).
    SurpriseGradient,
    /// Dynamical systems: Koopman mode lift g(x_{t+1}) = K g(x_t).
    /// SSM A-matrix as discrete-time Koopman operator.
    /// Anchor: Koopman 1931 + Wang-Liang ICLR 2025 (MamKO).
    KoopmanMode,
    /// Free probability: the noncommutative-probability invariant
    /// of layerwise Jacobians under Hadamard whitening.
    /// Anchor: Voiculescu 1985 + Hayase-Collins-Inoue arXiv:2504.06983
    /// + Magee-de la Salle arXiv:2409.03626.
    FreeCumulant,
}

impl CrossDomainLens {
    /// The discipline that owns this lens, for telemetry /
    /// dashboards.
    pub fn discipline(self) -> &'static str {
        match self {
            CrossDomainLens::ResidualStream => "transformer_interpretability",
            CrossDomainLens::PredictionError => "predictive_coding",
            CrossDomainLens::SurpriseGradient => "self_evolving_titans",
            CrossDomainLens::KoopmanMode => "koopman_dynamical_systems",
            CrossDomainLens::FreeCumulant => "free_probability",
        }
    }

    /// Anchor citation for this lens.
    pub fn anchor_citation(self) -> &'static str {
        match self {
            CrossDomainLens::ResidualStream => {
                "Qasim et al. arXiv:2603.19664 (KV-Direct, Mar 2026)"
            }
            CrossDomainLens::PredictionError => {
                "Rao-Ballard 1999 + Friston 2010 (free energy)"
            }
            CrossDomainLens::SurpriseGradient => {
                "Behrouz et al. arXiv:2501.00663 (Titans)"
            }
            CrossDomainLens::KoopmanMode => {
                "Koopman 1931 + Wang-Liang ICLR 2025 (MamKO)"
            }
            CrossDomainLens::FreeCumulant => {
                "Voiculescu 1985 + Hayase-Collins-Inoue arXiv:2504.06983 + Magee-de la Salle arXiv:2409.03626"
            }
        }
    }
}

/// All five cross-domain lenses in canonical-koan order.
pub const FIVE_LENSES: [CrossDomainLens; 5] = [
    CrossDomainLens::ResidualStream,
    CrossDomainLens::PredictionError,
    CrossDomainLens::SurpriseGradient,
    CrossDomainLens::KoopmanMode,
    CrossDomainLens::FreeCumulant,
];

/// One safety-drift bound, parallel to (NOT inside) the WBO-6
/// Master Inequality. Per `helios_v3.md` Part VI.2: "WBO-6 + T_safety
/// as an *external constraint*, not a 7th term."
///
/// CMS-X v3 sits ON TOP of Helios as a constitutive field, not
/// inside the substrate. T_safety bounds the probability of
/// constitutional violation; it has different units, different
/// worst cases, and different remedies than the per-logit
/// numerical perturbation that WBO-6 bounds. Keep them separate.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct TSafetyBound {
    /// Probability of constitutional violation (∈ [0, 1]).
    pub p_violation: f32,
    /// Acceptance ceiling — typically 0.001 for hard constitutional
    /// constraints (bioweapons, CSAM, direct physical harm).
    pub ceiling: f32,
}

impl TSafetyBound {
    /// Returns true when the observed probability of violation
    /// respects the ceiling.
    pub fn respects(&self) -> bool {
        self.p_violation.is_finite()
            && self.ceiling.is_finite()
            && self.p_violation <= self.ceiling
    }

    /// Default canonical hard-constraint ceiling: 1e-3.
    pub const HARD_CONSTRAINT_CEILING: f32 = 1e-3;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn five_lenses_in_canonical_koan_order() {
        assert_eq!(FIVE_LENSES.len(), 5);
        assert_eq!(FIVE_LENSES[0], CrossDomainLens::ResidualStream);
        assert_eq!(FIVE_LENSES[4], CrossDomainLens::FreeCumulant);
    }

    #[test]
    fn five_lenses_are_distinct() {
        let set: std::collections::HashSet<CrossDomainLens> =
            FIVE_LENSES.iter().copied().collect();
        assert_eq!(set.len(), 5);
    }

    #[test]
    fn each_lens_has_a_distinct_discipline() {
        let disciplines: std::collections::HashSet<&'static str> =
            FIVE_LENSES.iter().map(|l| l.discipline()).collect();
        assert_eq!(disciplines.len(), 5);
    }

    #[test]
    fn each_lens_has_an_anchor_citation() {
        for lens in FIVE_LENSES {
            assert!(!lens.anchor_citation().is_empty());
        }
    }

    #[test]
    fn t_safety_respects_below_ceiling() {
        let b = TSafetyBound {
            p_violation: 5e-4,
            ceiling: TSafetyBound::HARD_CONSTRAINT_CEILING,
        };
        assert!(b.respects());
    }

    #[test]
    fn t_safety_respects_at_exact_ceiling() {
        let b = TSafetyBound {
            p_violation: TSafetyBound::HARD_CONSTRAINT_CEILING,
            ceiling: TSafetyBound::HARD_CONSTRAINT_CEILING,
        };
        assert!(b.respects());
    }

    #[test]
    fn t_safety_fails_above_ceiling() {
        let b = TSafetyBound {
            p_violation: 1.5e-3,
            ceiling: TSafetyBound::HARD_CONSTRAINT_CEILING,
        };
        assert!(!b.respects());
    }

    #[test]
    fn t_safety_fails_for_nan_or_infinity() {
        let nan_violation = TSafetyBound {
            p_violation: f32::NAN,
            ceiling: 1e-3,
        };
        assert!(!nan_violation.respects());
        let inf_ceiling = TSafetyBound {
            p_violation: 1e-4,
            ceiling: f32::INFINITY,
        };
        assert!(!inf_ceiling.respects());
    }

    #[test]
    fn hard_constraint_ceiling_is_one_thousandth() {
        assert_eq!(TSafetyBound::HARD_CONSTRAINT_CEILING, 1e-3);
    }

    #[test]
    fn cross_domain_lens_serializes_in_snake_case() {
        for (lens, expected) in [
            (CrossDomainLens::ResidualStream, "\"residual_stream\""),
            (CrossDomainLens::PredictionError, "\"prediction_error\""),
            (CrossDomainLens::SurpriseGradient, "\"surprise_gradient\""),
            (CrossDomainLens::KoopmanMode, "\"koopman_mode\""),
            (CrossDomainLens::FreeCumulant, "\"free_cumulant\""),
        ] {
            assert_eq!(serde_json::to_string(&lens).unwrap(), expected);
        }
    }

    #[test]
    fn cross_domain_lens_round_trips_through_json() {
        for lens in FIVE_LENSES {
            let json = serde_json::to_string(&lens).unwrap();
            let parsed: CrossDomainLens = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, lens);
        }
    }
}
