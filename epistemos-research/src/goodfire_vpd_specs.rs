//! HELIOS V6.1 — Goodfire VPD canonical specs (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-GOODFIRE-VPD-SPECS guard
//!
//! Per `Epistemos V6_1 — Final Synthesis Lock` PART 6 — Goodfire's
//! Variational Parameter Decomposition specifics are upgraded
//! from `[NEEDS-SOURCE-FILE-VERIFICATION]` (V6 status) to
//! **`[VERIFIED-RESEARCH-DOCS-CONFIRMED-PUBLIC]`** (V6.1 status).
//!
//! Goodfire's public research page now exposes the full
//! decomposition specifics, allowing PCF to leave CANDIDATE
//! purgatory for atlas/observability claims.
//!
//! ## Confirmed-public specs
//!
//! - **67M parameters** (model size)
//! - **4-layer transformer**
//! - **38,912 rank-1 subcomponents** (decomposition cardinality)
//! - **9,972 alive components** (post-pruning live count)
//! - **205 active subcomponents per sequence position**
//! - **2.1% activation sparsity** (= 205 / 9972)
//!
//! Plus: QK decomposition into subcomponent pairs, cross-head
//! "previous-token" behavior, manual emoticon edits.
//!
//! ## What this changes operationally per V6.1
//!
//! - W36 (VPD/PCF extraction pipeline) — full Lane-3 scope greenlit
//! - T42 (Connectome-State Coupling) — immediately tractable
//! - Connectome Browser (Pro tier UI) — ships without disclosure
//!   caveat
//!
//! ## What V6.1 preserves
//!
//! - T40 (Connectome-RAG novel retrieval) — remains CANDIDATE
//! - T28 (Interpretability-to-Runtime, V5/Vault) — remains Vault-only
//!
//! Public confirmation of the *atlas* does NOT validate the
//! *retrieval-as-runtime-substrate* claim or the *full-runtime
//! replacement* claim. The discipline holds.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// Canonical Goodfire VPD numerics per V6.1 Part 6 (CONFIRMED-PUBLIC).
pub const VPD_PARAMETER_COUNT: u64 = 67_000_000;
pub const VPD_TRANSFORMER_LAYERS: u32 = 4;
pub const VPD_RANK1_SUBCOMPONENTS: u32 = 38_912;
pub const VPD_ALIVE_COMPONENTS: u32 = 9_972;
pub const VPD_ACTIVE_PER_POSITION: u32 = 205;
/// Activation sparsity = 205 / 9972 ≈ 0.02055 (2.1%) per V6.1 §6.
pub const VPD_ACTIVATION_SPARSITY: f32 = 0.0205_f32;

/// Status taxonomy for VPD claims per V6.1 sharpening point 3.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VpdClaimStatus {
    /// Atlas / observability / tracing / editing claims —
    /// upgraded to PUBLIC-CONFIRMED per V6.1.
    AtlasObservability,
    /// Runtime acceleration / Connectome-RAG retrieval — remains
    /// CANDIDATE (T40 unchanged).
    RuntimeAcceleration,
    /// Full-runtime replacement (T28 in V5/Vault) — remains
    /// Vault-only.
    FullRuntimeReplacement,
}

impl VpdClaimStatus {
    /// True when the claim is PUBLIC-CONFIRMED per V6.1 (atlas
    /// only).
    pub fn is_public_confirmed(self) -> bool {
        matches!(self, VpdClaimStatus::AtlasObservability)
    }

    /// True when the claim remains CANDIDATE per V6.1 preservation
    /// (runtime acceleration only).
    pub fn is_candidate(self) -> bool {
        matches!(self, VpdClaimStatus::RuntimeAcceleration)
    }

    /// True when the claim remains Vault-only.
    pub fn is_vault_only(self) -> bool {
        matches!(self, VpdClaimStatus::FullRuntimeReplacement)
    }
}

/// All three VPD claim statuses in canonical order.
pub const THREE_VPD_STATUSES: [VpdClaimStatus; 3] = [
    VpdClaimStatus::AtlasObservability,
    VpdClaimStatus::RuntimeAcceleration,
    VpdClaimStatus::FullRuntimeReplacement,
];

/// Compute the activation sparsity from the canonical numerics.
pub fn computed_activation_sparsity() -> f32 {
    VPD_ACTIVE_PER_POSITION as f32 / VPD_ALIVE_COMPONENTS as f32
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parameter_count_is_67m() {
        assert_eq!(VPD_PARAMETER_COUNT, 67_000_000);
    }

    #[test]
    fn transformer_has_4_layers() {
        assert_eq!(VPD_TRANSFORMER_LAYERS, 4);
    }

    #[test]
    fn decomposition_cardinality_is_38912() {
        assert_eq!(VPD_RANK1_SUBCOMPONENTS, 38_912);
    }

    #[test]
    fn alive_components_is_9972() {
        assert_eq!(VPD_ALIVE_COMPONENTS, 9_972);
    }

    #[test]
    fn active_per_position_is_205() {
        assert_eq!(VPD_ACTIVE_PER_POSITION, 205);
    }

    #[test]
    fn activation_sparsity_is_2_point_1_percent() {
        // Pinned constant.
        assert!((VPD_ACTIVATION_SPARSITY - 0.0205).abs() < 1e-4);
    }

    #[test]
    fn computed_sparsity_matches_pinned_constant_within_tolerance() {
        // 205 / 9972 = 0.020556... ≈ 0.0205 (rounded to 4 decimals).
        let computed = computed_activation_sparsity();
        assert!((computed - VPD_ACTIVATION_SPARSITY).abs() < 1e-3);
    }

    #[test]
    fn alive_components_strictly_less_than_decomposition_cardinality() {
        // 9972 alive ≤ 38912 decomposed. Pruning reduces the live
        // component count.
        assert!(VPD_ALIVE_COMPONENTS < VPD_RANK1_SUBCOMPONENTS);
    }

    #[test]
    fn active_per_position_strictly_less_than_alive_components() {
        // 205 active ≤ 9972 alive. Sparsity must hold.
        assert!(VPD_ACTIVE_PER_POSITION < VPD_ALIVE_COMPONENTS);
    }

    #[test]
    fn three_vpd_statuses_are_distinct() {
        let set: std::collections::HashSet<VpdClaimStatus> =
            THREE_VPD_STATUSES.iter().copied().collect();
        assert_eq!(set.len(), 3);
    }

    #[test]
    fn only_atlas_observability_is_public_confirmed() {
        assert!(VpdClaimStatus::AtlasObservability.is_public_confirmed());
        assert!(!VpdClaimStatus::RuntimeAcceleration.is_public_confirmed());
        assert!(!VpdClaimStatus::FullRuntimeReplacement.is_public_confirmed());
    }

    #[test]
    fn only_runtime_acceleration_is_candidate() {
        assert!(!VpdClaimStatus::AtlasObservability.is_candidate());
        assert!(VpdClaimStatus::RuntimeAcceleration.is_candidate());
        assert!(!VpdClaimStatus::FullRuntimeReplacement.is_candidate());
    }

    #[test]
    fn only_full_runtime_replacement_is_vault_only() {
        assert!(!VpdClaimStatus::AtlasObservability.is_vault_only());
        assert!(!VpdClaimStatus::RuntimeAcceleration.is_vault_only());
        assert!(VpdClaimStatus::FullRuntimeReplacement.is_vault_only());
    }

    #[test]
    fn three_vpd_statuses_are_in_pairwise_disjoint_classifications() {
        for s in THREE_VPD_STATUSES {
            let count = [s.is_public_confirmed(), s.is_candidate(), s.is_vault_only()]
                .iter()
                .filter(|&&b| b)
                .count();
            assert_eq!(count, 1, "{:?} should fit exactly one classification", s);
        }
    }

    #[test]
    fn vpd_claim_status_serializes_in_snake_case() {
        for (s, expected) in [
            (VpdClaimStatus::AtlasObservability, "\"atlas_observability\""),
            (VpdClaimStatus::RuntimeAcceleration, "\"runtime_acceleration\""),
            (VpdClaimStatus::FullRuntimeReplacement, "\"full_runtime_replacement\""),
        ] {
            assert_eq!(serde_json::to_string(&s).unwrap(), expected);
        }
    }

    #[test]
    fn vpd_claim_status_round_trips_through_json() {
        for s in THREE_VPD_STATUSES {
            let json = serde_json::to_string(&s).unwrap();
            let parsed: VpdClaimStatus = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, s);
        }
    }
}
