//! HELIOS V5 — Five Mathematical Pillars taxonomy (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-MATHEMATICAL-PILLARS guard
//!
//! Per HELIOS v4 preservation `source_docs/epistemos_definitive_master.md`
//! §"PART I: THE FIVE PILLARS OF MATHEMATICAL FOUNDATION".
//!
//! Five proven mathematical foundations underwrite the Epistemos
//! cognitive substrate. Each pillar carries a peer-reviewed or
//! arXiv-posted theorem, an anchor citation with year/venue, and a
//! specific role in the Master Inequality (E4/H1 WBO).
//!
//! ## Pillars
//!
//! - **I. Wyner-Ziv Source Coding** — Zamir-Shamai-Erez (1996/2002).
//!   Bound: 0.5 bit/dimension gap between Wyner-Ziv R-D and
//!   conditional R_X|Y(D). Helios role: T_R (residual term).
//!
//! - **II. Babai/GPTQ Nearest-Plane** — Chen et al. arXiv:2507.18553
//!   v3 (ICLR 2026). Bound: ‖e‖² ≤ Σᵢ‖b*ᵢ‖²/4. Helios role: T_W
//!   (weight quantization). E_8 lattice: ~0.65 dB; Leech: ~1.03 dB.
//!
//! - **III. Softmax 1/2-Lipschitz** — Nair arXiv:2510.23012 (TMLR).
//!   Bound: ‖σ(x) − σ(y)‖_p ≤ ½ · ‖x − y‖_p ∀ p ≥ 1. Helios role:
//!   leading ½ on the Master Inequality bracket. The "single largest
//!   free win" in the stack.
//!
//! - **IV. Test-Time Regression** — Wang-Shi-Fox arXiv:2501.12352
//!   (Jan 2025). Framework: every sequence-modeling layer with
//!   associative recall = (regression_weights, regressor_class,
//!   optimizer) triple. Helios role: unifies L2 Shadow Sketch +
//!   Mamba-2 SSM track + Transformer track + L_SE.
//!
//! - **V. eml-Operator Universal Computation** — Odrzywolek
//!   arXiv:2603.21852 v2 (Apr 2026). Theorem: eml(x, y) = exp(x) −
//!   ln(y) generates the scientific calculator basis (Lean-formalized
//!   at `tomdif/eml-lean`). Helios role: universal compute primitive.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// One of the five mathematical pillars per the definitive master
/// spec §"PART I".
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MathematicalPillar {
    /// Pillar I — Wyner-Ziv Source Coding with Side Information.
    /// Anchor: Zamir-Shamai-Erez 1996/2002 + Zamir 2014 (Cambridge).
    WynerZivSourceCoding,
    /// Pillar II — Babai/GPTQ as Nearest-Plane on Hessian Lattice.
    /// Anchor: Chen et al. arXiv:2507.18553 v3 (ICLR 2026).
    BabaiGptqNearestPlane,
    /// Pillar III — Softmax is 1/2-Lipschitz Uniformly Across ℓ_p.
    /// Anchor: Nair arXiv:2510.23012 (TMLR Oct 27 2025).
    SoftmaxHalfLipschitz,
    /// Pillar IV — Test-Time Regression as Unifying Frame.
    /// Anchor: Wang-Shi-Fox arXiv:2501.12352 (Jan 2025).
    TestTimeRegression,
    /// Pillar V — eml-Operator Universal Computation.
    /// Anchor: Odrzywolek arXiv:2603.21852 v2 (Apr 2026) +
    /// `tomdif/eml-lean` Lean 4 formalization.
    EmlOperatorUniversal,
}

impl MathematicalPillar {
    /// Roman numeral I..V per the canonical pillar order.
    pub fn roman_numeral(self) -> &'static str {
        match self {
            MathematicalPillar::WynerZivSourceCoding => "I",
            MathematicalPillar::BabaiGptqNearestPlane => "II",
            MathematicalPillar::SoftmaxHalfLipschitz => "III",
            MathematicalPillar::TestTimeRegression => "IV",
            MathematicalPillar::EmlOperatorUniversal => "V",
        }
    }

    /// Anchor citation (paper title + arXiv id / year). Stable string;
    /// changes require explicit canon sign-off.
    pub fn anchor_citation(self) -> &'static str {
        match self {
            MathematicalPillar::WynerZivSourceCoding => {
                "Zamir-Shamai-Erez 1996/2002 + Zamir Cambridge 2014"
            }
            MathematicalPillar::BabaiGptqNearestPlane => {
                "Chen et al. arXiv:2507.18553 v3 (ICLR 2026)"
            }
            MathematicalPillar::SoftmaxHalfLipschitz => {
                "Nair arXiv:2510.23012 (TMLR Oct 27 2025)"
            }
            MathematicalPillar::TestTimeRegression => {
                "Wang-Shi-Fox arXiv:2501.12352 (Jan 2025)"
            }
            MathematicalPillar::EmlOperatorUniversal => {
                "Odrzywolek arXiv:2603.21852 v2 (Apr 2026)"
            }
        }
    }

    /// Role in the Master Inequality (E4/H1 WBO) — short label.
    pub fn master_inequality_role(self) -> &'static str {
        match self {
            MathematicalPillar::WynerZivSourceCoding => "T_R (residual)",
            MathematicalPillar::BabaiGptqNearestPlane => "T_W (weight quantization)",
            MathematicalPillar::SoftmaxHalfLipschitz => "leading 1/2",
            MathematicalPillar::TestTimeRegression => "unifying (W, F, O) frame",
            MathematicalPillar::EmlOperatorUniversal => "universal compute primitive",
        }
    }

    /// Returns true when the pillar is peer-reviewed or formally
    /// proven (Status::P per the definitive-master legend).
    /// All five are P; the method exists as an invariant assertion.
    pub fn is_proven(self) -> bool {
        // All five pillars are tagged P in the definitive master.
        // The method exists so the contract is encoded for any
        // future pillar that lands in EB or C state.
        matches!(
            self,
            MathematicalPillar::WynerZivSourceCoding
                | MathematicalPillar::BabaiGptqNearestPlane
                | MathematicalPillar::SoftmaxHalfLipschitz
                | MathematicalPillar::TestTimeRegression
                | MathematicalPillar::EmlOperatorUniversal
        )
    }
}

/// All five pillars in canonical order.
pub const FIVE_PILLARS: [MathematicalPillar; 5] = [
    MathematicalPillar::WynerZivSourceCoding,
    MathematicalPillar::BabaiGptqNearestPlane,
    MathematicalPillar::SoftmaxHalfLipschitz,
    MathematicalPillar::TestTimeRegression,
    MathematicalPillar::EmlOperatorUniversal,
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn five_pillars_listed_in_canonical_order() {
        assert_eq!(FIVE_PILLARS.len(), 5);
        assert_eq!(FIVE_PILLARS[0], MathematicalPillar::WynerZivSourceCoding);
        assert_eq!(FIVE_PILLARS[4], MathematicalPillar::EmlOperatorUniversal);
    }

    #[test]
    fn five_pillars_are_distinct() {
        let set: std::collections::HashSet<MathematicalPillar> =
            FIVE_PILLARS.iter().copied().collect();
        assert_eq!(set.len(), 5);
    }

    #[test]
    fn roman_numerals_match_canonical_order() {
        let expected = ["I", "II", "III", "IV", "V"];
        for (pillar, expected_numeral) in FIVE_PILLARS.iter().zip(expected.iter()) {
            assert_eq!(pillar.roman_numeral(), *expected_numeral);
        }
    }

    #[test]
    fn all_five_pillars_are_proven() {
        for pillar in FIVE_PILLARS {
            assert!(
                pillar.is_proven(),
                "Pillar {} ({}) must be Status::P per the definitive master",
                pillar.roman_numeral(),
                pillar.anchor_citation()
            );
        }
    }

    #[test]
    fn anchor_citation_includes_arxiv_id_for_post_2024_pillars() {
        // Pillars II-V are post-2024 papers with arXiv ids.
        for pillar in [
            MathematicalPillar::BabaiGptqNearestPlane,
            MathematicalPillar::SoftmaxHalfLipschitz,
            MathematicalPillar::TestTimeRegression,
            MathematicalPillar::EmlOperatorUniversal,
        ] {
            assert!(
                pillar.anchor_citation().contains("arXiv:"),
                "Pillar {} citation should reference arXiv id",
                pillar.roman_numeral()
            );
        }
    }

    #[test]
    fn pillar_iii_anchors_the_leading_half_of_master_inequality() {
        // Per the definitive master: Pillar III is "the leading 1/2"
        // and is "the single largest free win in the entire stack."
        let role = MathematicalPillar::SoftmaxHalfLipschitz.master_inequality_role();
        assert_eq!(role, "leading 1/2");
    }

    #[test]
    fn pillar_serializes_in_snake_case() {
        for (pillar, expected) in [
            (
                MathematicalPillar::WynerZivSourceCoding,
                "\"wyner_ziv_source_coding\"",
            ),
            (
                MathematicalPillar::BabaiGptqNearestPlane,
                "\"babai_gptq_nearest_plane\"",
            ),
            (
                MathematicalPillar::SoftmaxHalfLipschitz,
                "\"softmax_half_lipschitz\"",
            ),
            (
                MathematicalPillar::TestTimeRegression,
                "\"test_time_regression\"",
            ),
            (
                MathematicalPillar::EmlOperatorUniversal,
                "\"eml_operator_universal\"",
            ),
        ] {
            assert_eq!(serde_json::to_string(&pillar).unwrap(), expected);
        }
    }

    #[test]
    fn pillar_round_trips_through_json() {
        for pillar in FIVE_PILLARS {
            let json = serde_json::to_string(&pillar).unwrap();
            let parsed: MathematicalPillar = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, pillar);
        }
    }

    #[test]
    fn master_inequality_roles_are_non_empty() {
        for pillar in FIVE_PILLARS {
            assert!(!pillar.master_inequality_role().is_empty());
        }
    }
}
