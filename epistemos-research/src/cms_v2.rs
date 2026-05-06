//! HELIOS V5 — Constitutive Moral Substrate v2 (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-CMS-V2 guard
//!
//! Per HELIOS v4 preservation `source_docs/CMS_v2_Final_Definitive.md`
//! (Pre-Submission Draft, April 2026). Defense-in-depth alignment
//! architecture: cryptographically bound, geometrically invariant,
//! philosophically honest. The substrate is **engineering design
//! patterns informed by neuroscience**, not brain-faithful
//! implementations.
//!
//! ## Six defense-in-depth layers
//!
//! Each layer targets a specific attack surface. A layer's
//! `defends_against` mapping is bijective in the canonical doctrine
//! per CMS v2 §Part II — every attack has exactly one primary
//! layer-of-defense. Composition (multiple layers reinforcing the
//! same attack) is layered defense, not redundancy.
//!
//! ## Three-tier moral structure
//!
//! Per CMS v2 §Part VII (Moral Evolution Problem):
//!
//! 1. **Hard constraints** — non-negotiable bright lines (bioweapons,
//!    CSAM, direct physical harm). Anchored in Curry et al. 2019
//!    seven-culture universals.
//! 2. **Soft guidance** — domain-adaptive moral filters, contextual
//!    norms, updateable via democratic mechanisms (ProgressGym,
//!    Collective Constitutional AI, RRC).
//! 3. **Meta-values** — transparency, consistency, proportionality,
//!    procedural legitimacy. The thin meta-layer from Wide Reflective
//!    Equilibrium (Brophy arXiv:2506.00415, 2025).
//!
//! ## Six genuinely unresolvable problems
//!
//! Per CMS v2 §1.3 — these are structural features of the moral
//! domain, not engineering challenges. CMS v2 operates rigorously
//! *within* them; it does NOT claim to solve them.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. NEVER ships in MAS. The default lib build
//! excludes this module; building it requires `--features research`.

use serde::{Deserialize, Serialize};

/// Six defense-in-depth layers of CMS v2 (§Part II).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CmsLayer {
    /// Layer 1: Mamba-based State-Space Temporal Auditing.
    /// Defeats multi-turn drift attacks (e.g. Crescendo, 98% ASR).
    /// Empirical support: DeepContext arXiv:2602.16935 F1=0.84.
    TemporalAuditing,
    /// Layer 2: Holographic Invariant Storage via VSA / HDC.
    /// Neutralizes the Waluigi effect by eliminating invertible
    /// safety directions; recovery fidelity ≥ 1/√2.
    HolographicStorage,
    /// Layer 3: Holographic Functional Encryption + TEE.
    /// Makes weight surgery provably self-destructive.
    /// Anchored in NVIDIA H100 Confidential Computing.
    FunctionalEncryption,
    /// Layer 4: TurboQuant + Latent Error-Correcting Codes.
    /// Prevents quantization-induced safety erasure
    /// (cf. Q-Misalign ICLR 2025; AAQ Nov 2025; CWP Jan 2026).
    LatentErrorCorrectingCodes,
    /// Layer 5: Paraconsistent Deontic Logic + Bayesian MVaR.
    /// Handles deontic paradoxes without explosion via DPI + LFI.
    ParaconsistentLogic,
    /// Layer 6: Null-Space Constrained Policy Optimization (NSPO,
    /// ICLR 2026). Mathematically eliminates the alignment tax —
    /// safety updates orthogonal to capability gradients.
    NullSpaceOptimization,
}

/// Six primary attack surfaces enumerated in CMS v2 (§Part II).
/// Each layer maps to exactly one canonical attack via [`defends_against`].
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CmsAttackVector {
    /// Crescendo / multi-turn semantic drift; 98% ASR on GPT-4.
    MultiTurnDrift,
    /// Waluigi effect — invertible safety directions in residual
    /// stream (Arditi et al., NeurIPS 2024).
    WaluigiInversion,
    /// Weight surgery — abliteration / LoRA fine-tuning;
    /// OBLITERATUS (Mar 2026) breaks 116 models in minutes.
    WeightSurgery,
    /// Quantization flip — RLHF guardrail erasure under PTQ;
    /// Q-Misalign (ICLR 2025) injects dormant misalignment.
    QuantizationFlip,
    /// Deontic explosion — Chisholm / Ross / Gentle Murderer
    /// paradoxes paralyze rigid SDL.
    DeonticParadox,
    /// Alignment tax — capability degradation
    /// (DirectRefusal: −30.91% reasoning; r = −0.85).
    AlignmentTax,
}

/// Three tiers of the CMS v2 moral structure (§Part VII).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MoralStructureTier {
    /// Non-negotiable bright lines. Curry et al. 2019 seven-culture
    /// universals (bioweapons, CSAM, direct physical harm).
    HardConstraint,
    /// Domain-adaptive filters; updateable via ProgressGym /
    /// Collective Constitutional AI / RRC democratic mechanisms.
    SoftGuidance,
    /// Thin meta-layer from Wide Reflective Equilibrium (Brophy
    /// arXiv:2506.00415, 2025) — transparency, consistency,
    /// proportionality, procedural legitimacy.
    MetaValue,
}

/// Six genuinely unresolvable problems of the moral domain (§1.3).
/// CMS v2 explicitly does NOT claim to solve these; it operates
/// rigorously within them.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UnresolvableProblem {
    /// Hume's is-ought gap — normative axioms must be stipulated.
    NormativeFoundations,
    /// Arrow's impossibility theorem on aggregate value preference.
    ValueIncommensurability,
    /// The frame problem applied to ethics.
    EthicalFrameProblem,
    /// Wittgenstein's rule-following paradox (PI §201).
    RuleFollowingParadox,
    /// Williams 1985 — integrity and moral agency.
    IntegrityAndAgency,
    /// Moral luck (Nagel 1979; Williams 1981).
    MoralLuck,
}

impl CmsLayer {
    /// The single primary attack each layer is designed to defend
    /// against in CMS v2 canonical doctrine. The mapping is bijective.
    pub fn defends_against(self) -> CmsAttackVector {
        match self {
            CmsLayer::TemporalAuditing => CmsAttackVector::MultiTurnDrift,
            CmsLayer::HolographicStorage => CmsAttackVector::WaluigiInversion,
            CmsLayer::FunctionalEncryption => CmsAttackVector::WeightSurgery,
            CmsLayer::LatentErrorCorrectingCodes => CmsAttackVector::QuantizationFlip,
            CmsLayer::ParaconsistentLogic => CmsAttackVector::DeonticParadox,
            CmsLayer::NullSpaceOptimization => CmsAttackVector::AlignmentTax,
        }
    }
}

impl CmsAttackVector {
    /// Inverse of [`CmsLayer::defends_against`].
    pub fn primary_defense(self) -> CmsLayer {
        match self {
            CmsAttackVector::MultiTurnDrift => CmsLayer::TemporalAuditing,
            CmsAttackVector::WaluigiInversion => CmsLayer::HolographicStorage,
            CmsAttackVector::WeightSurgery => CmsLayer::FunctionalEncryption,
            CmsAttackVector::QuantizationFlip => CmsLayer::LatentErrorCorrectingCodes,
            CmsAttackVector::DeonticParadox => CmsLayer::ParaconsistentLogic,
            CmsAttackVector::AlignmentTax => CmsLayer::NullSpaceOptimization,
        }
    }
}

/// All six CMS v2 layers in canonical order (Layer 1 → Layer 6).
pub const ALL_LAYERS: [CmsLayer; 6] = [
    CmsLayer::TemporalAuditing,
    CmsLayer::HolographicStorage,
    CmsLayer::FunctionalEncryption,
    CmsLayer::LatentErrorCorrectingCodes,
    CmsLayer::ParaconsistentLogic,
    CmsLayer::NullSpaceOptimization,
];

/// All six CMS v2 attack vectors in the order their layer-of-defense
/// appears in [`ALL_LAYERS`].
pub const ALL_ATTACKS: [CmsAttackVector; 6] = [
    CmsAttackVector::MultiTurnDrift,
    CmsAttackVector::WaluigiInversion,
    CmsAttackVector::WeightSurgery,
    CmsAttackVector::QuantizationFlip,
    CmsAttackVector::DeonticParadox,
    CmsAttackVector::AlignmentTax,
];

/// All six unresolvable problems in canonical CMS v2 order.
pub const ALL_UNRESOLVABLE_PROBLEMS: [UnresolvableProblem; 6] = [
    UnresolvableProblem::NormativeFoundations,
    UnresolvableProblem::ValueIncommensurability,
    UnresolvableProblem::EthicalFrameProblem,
    UnresolvableProblem::RuleFollowingParadox,
    UnresolvableProblem::IntegrityAndAgency,
    UnresolvableProblem::MoralLuck,
];

/// All three moral-structure tiers in canonical CMS v2 order.
pub const ALL_TIERS: [MoralStructureTier; 3] = [
    MoralStructureTier::HardConstraint,
    MoralStructureTier::SoftGuidance,
    MoralStructureTier::MetaValue,
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn six_layers_listed_in_canonical_order() {
        assert_eq!(ALL_LAYERS.len(), 6);
        assert_eq!(ALL_LAYERS[0], CmsLayer::TemporalAuditing);
        assert_eq!(ALL_LAYERS[5], CmsLayer::NullSpaceOptimization);
    }

    #[test]
    fn six_attacks_listed_in_canonical_order() {
        assert_eq!(ALL_ATTACKS.len(), 6);
        assert_eq!(ALL_ATTACKS[0], CmsAttackVector::MultiTurnDrift);
        assert_eq!(ALL_ATTACKS[5], CmsAttackVector::AlignmentTax);
    }

    #[test]
    fn defense_attack_mapping_is_bijective() {
        // For every layer L, primary_defense(defends_against(L)) == L
        for layer in ALL_LAYERS {
            assert_eq!(layer.defends_against().primary_defense(), layer);
        }
        // For every attack A, defends_against(primary_defense(A)) == A
        for attack in ALL_ATTACKS {
            assert_eq!(attack.primary_defense().defends_against(), attack);
        }
    }

    #[test]
    fn no_two_layers_defend_against_the_same_attack() {
        let mut seen = std::collections::HashSet::new();
        for layer in ALL_LAYERS {
            assert!(
                seen.insert(layer.defends_against()),
                "layer {:?} duplicates an attack mapping",
                layer
            );
        }
        assert_eq!(seen.len(), 6);
    }

    #[test]
    fn six_unresolvable_problems_are_distinct() {
        let set: std::collections::HashSet<UnresolvableProblem> =
            ALL_UNRESOLVABLE_PROBLEMS.iter().copied().collect();
        assert_eq!(set.len(), 6);
    }

    #[test]
    fn three_tiers_are_distinct() {
        let set: std::collections::HashSet<MoralStructureTier> =
            ALL_TIERS.iter().copied().collect();
        assert_eq!(set.len(), 3);
    }

    #[test]
    fn cms_layer_serializes_in_snake_case() {
        for (layer, expected) in [
            (CmsLayer::TemporalAuditing, "\"temporal_auditing\""),
            (CmsLayer::HolographicStorage, "\"holographic_storage\""),
            (CmsLayer::FunctionalEncryption, "\"functional_encryption\""),
            (CmsLayer::LatentErrorCorrectingCodes, "\"latent_error_correcting_codes\""),
            (CmsLayer::ParaconsistentLogic, "\"paraconsistent_logic\""),
            (CmsLayer::NullSpaceOptimization, "\"null_space_optimization\""),
        ] {
            assert_eq!(serde_json::to_string(&layer).unwrap(), expected);
        }
    }

    #[test]
    fn cms_attack_vector_serializes_in_snake_case() {
        for (attack, expected) in [
            (CmsAttackVector::MultiTurnDrift, "\"multi_turn_drift\""),
            (CmsAttackVector::WaluigiInversion, "\"waluigi_inversion\""),
            (CmsAttackVector::WeightSurgery, "\"weight_surgery\""),
            (CmsAttackVector::QuantizationFlip, "\"quantization_flip\""),
            (CmsAttackVector::DeonticParadox, "\"deontic_paradox\""),
            (CmsAttackVector::AlignmentTax, "\"alignment_tax\""),
        ] {
            assert_eq!(serde_json::to_string(&attack).unwrap(), expected);
        }
    }

    #[test]
    fn moral_structure_tier_serializes_in_snake_case() {
        for (tier, expected) in [
            (MoralStructureTier::HardConstraint, "\"hard_constraint\""),
            (MoralStructureTier::SoftGuidance, "\"soft_guidance\""),
            (MoralStructureTier::MetaValue, "\"meta_value\""),
        ] {
            assert_eq!(serde_json::to_string(&tier).unwrap(), expected);
        }
    }

    #[test]
    fn unresolvable_problem_serializes_in_snake_case() {
        assert_eq!(
            serde_json::to_string(&UnresolvableProblem::NormativeFoundations).unwrap(),
            "\"normative_foundations\""
        );
        assert_eq!(
            serde_json::to_string(&UnresolvableProblem::ValueIncommensurability).unwrap(),
            "\"value_incommensurability\""
        );
        assert_eq!(
            serde_json::to_string(&UnresolvableProblem::MoralLuck).unwrap(),
            "\"moral_luck\""
        );
    }

    #[test]
    fn cms_layer_round_trips_through_json() {
        for layer in ALL_LAYERS {
            let json = serde_json::to_string(&layer).unwrap();
            let parsed: CmsLayer = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, layer);
        }
    }

    #[test]
    fn cms_attack_round_trips_through_json() {
        for attack in ALL_ATTACKS {
            let json = serde_json::to_string(&attack).unwrap();
            let parsed: CmsAttackVector = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, attack);
        }
    }

    #[test]
    fn unresolvable_problem_round_trips_through_json() {
        for problem in ALL_UNRESOLVABLE_PROBLEMS {
            let json = serde_json::to_string(&problem).unwrap();
            let parsed: UnresolvableProblem = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, problem);
        }
    }

    #[test]
    fn moral_tier_round_trips_through_json() {
        for tier in ALL_TIERS {
            let json = serde_json::to_string(&tier).unwrap();
            let parsed: MoralStructureTier = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, tier);
        }
    }
}
