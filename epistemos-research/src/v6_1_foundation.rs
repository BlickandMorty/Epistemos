//! EPISTENOS / HELIOS V6.1 foundation intake (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-V6_1-FOUNDATION guard
//!
//! Source: `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md`.
//!
//! This module records the May 7 foundation update that narrows the
//! next Helios step to an arithmetic floor:
//!
//! 1. EML is accepted as a computational primitive for elementary
//!    scientific computation, not as a primitive of the universe.
//! 2. `F-ULP-Oracle` gates `morph_eval_reduced.metal v0.1`.
//! 3. AnswerPacket schema freeze is downstream of that oracle.
//! 4. Goodfire VPD activity numerics stay public-confirmed after
//!    live-page revalidation; runtime acceleration stays candidate.

use serde::{Deserialize, Serialize};

use crate::hardware_profile::HardwareProfile;
use crate::theorem_status::TheoremStatus;

/// Canonical source path for this intake.
pub const V6_1_FOUNDATION_SOURCE_PATH: &str =
    "docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md";

/// Verified floor stays pinned through the update.
pub const VERIFIED_FLOOR_COMMIT: &str = "ac8c6d28";

/// The shippability rig remains the user's M2 Pro 16GB machine.
pub const FOUNDATION_HARDWARE_FLOOR: HardwareProfile = HardwareProfile::M2Pro16Gb;

/// EML operator as accepted by the foundation update.
pub const EML_OPERATOR_FORMULA: &str = "eml(x,y)=exp(x)-ln(y)";

/// The grammar is intentionally tiny, but it still needs the terminal.
pub const EML_GRAMMAR: &str = "S -> 1 | eml(S,S)";

/// The foundation update explicitly keeps constant-free generation open.
pub const CONSTANT_FREE_EML_GENERATOR_OPEN: bool = true;

/// AnswerPacket schema freeze is gated behind the arithmetic floor.
pub const ANSWER_PACKET_SCHEMA_FREEZE_REQUIRES_F_ULP_ORACLE: bool = true;

/// Goodfire live-page revalidation result from this intake.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FoundationGoodfireStatus {
    /// The page currently corroborates the 9972 / 205 / 0.021 table.
    ActivitySubnumbersPublicConfirmed,
    /// Atlas/observability is public-confirmed.
    AtlasObservabilityPublicConfirmed,
    /// Runtime acceleration remains a candidate claim.
    RuntimeAccelerationCandidate,
}

pub const FOUNDATION_GOODFIRE_STATUS: [FoundationGoodfireStatus; 3] = [
    FoundationGoodfireStatus::ActivitySubnumbersPublicConfirmed,
    FoundationGoodfireStatus::AtlasObservabilityPublicConfirmed,
    FoundationGoodfireStatus::RuntimeAccelerationCandidate,
];

/// One foundation artifact or theorem-family named by the update.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FoundationClaim {
    EmlIrLowering,
    EmlNormalForm,
    ActionToEml,
    TropicalAffine,
    GeometricLowering,
    SparseActiveAssembly,
    InterruptCalibration,
    LeanSchemaAuthority,
    MonnerotEmlStar,
    SingleQuantumShefferStroke,
}

impl FoundationClaim {
    pub fn status(self) -> TheoremStatus {
        match self {
            FoundationClaim::EmlIrLowering => TheoremStatus::EB,
            FoundationClaim::EmlNormalForm => TheoremStatus::C,
            FoundationClaim::ActionToEml => TheoremStatus::C,
            FoundationClaim::TropicalAffine => TheoremStatus::C,
            FoundationClaim::GeometricLowering => TheoremStatus::C,
            FoundationClaim::SparseActiveAssembly => TheoremStatus::C,
            FoundationClaim::InterruptCalibration => TheoremStatus::EB,
            FoundationClaim::LeanSchemaAuthority => TheoremStatus::C,
            FoundationClaim::MonnerotEmlStar => TheoremStatus::DROP,
            FoundationClaim::SingleQuantumShefferStroke => TheoremStatus::DROP,
        }
    }

    pub fn requires_hardware_falsifier(self) -> bool {
        self.status().requires_falsifier()
    }
}

/// All tracked foundation claims in canonical table order.
pub const FOUNDATION_CLAIMS: [FoundationClaim; 10] = [
    FoundationClaim::EmlIrLowering,
    FoundationClaim::EmlNormalForm,
    FoundationClaim::ActionToEml,
    FoundationClaim::TropicalAffine,
    FoundationClaim::GeometricLowering,
    FoundationClaim::SparseActiveAssembly,
    FoundationClaim::InterruptCalibration,
    FoundationClaim::LeanSchemaAuthority,
    FoundationClaim::MonnerotEmlStar,
    FoundationClaim::SingleQuantumShefferStroke,
];

/// `F-ULP-Oracle (W1)` spec.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct FulpOracleSpec {
    pub log_sampled_points: u32,
    pub stress_points: u32,
    pub max_ulp_fp16: u32,
    pub wall_clock_seconds_max: u32,
    pub checked_interval_min: f32,
    pub checked_interval_max: f32,
}

pub const F_ULP_ORACLE: FulpOracleSpec = FulpOracleSpec {
    log_sampled_points: 412_000,
    stress_points: 2_048,
    max_ulp_fp16: 2,
    wall_clock_seconds_max: 90,
    checked_interval_min: 0.5,
    checked_interval_max: 2.0,
};

/// Stage-0/1 commitment order from the foundation update.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FoundationCommitment {
    VendorOxiemlReadOnly,
    VendorEmlLeanAndVerifyNoSorry,
    LandMorphEvalReducedMetal,
    LandFulpOracleHarness,
    FreezeAnswerPacketSchemaBehindOracle,
    PinLeanToolchain,
    TrackCaveatsAsDrops,
}

pub const FOUNDATION_COMMITMENT_ORDER: [FoundationCommitment; 7] = [
    FoundationCommitment::VendorOxiemlReadOnly,
    FoundationCommitment::VendorEmlLeanAndVerifyNoSorry,
    FoundationCommitment::LandMorphEvalReducedMetal,
    FoundationCommitment::LandFulpOracleHarness,
    FoundationCommitment::FreezeAnswerPacketSchemaBehindOracle,
    FoundationCommitment::PinLeanToolchain,
    FoundationCommitment::TrackCaveatsAsDrops,
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn foundation_floor_and_hardware_are_pinned() {
        assert_eq!(VERIFIED_FLOOR_COMMIT, "ac8c6d28");
        assert_eq!(FOUNDATION_HARDWARE_FLOOR, HardwareProfile::M2Pro16Gb);
        assert_eq!(FOUNDATION_HARDWARE_FLOOR.unified_memory_gb(), 16);
    }

    #[test]
    fn eml_formula_has_no_plus_one_drift() {
        assert_eq!(EML_OPERATOR_FORMULA, "eml(x,y)=exp(x)-ln(y)");
        assert_eq!(EML_GRAMMAR, "S -> 1 | eml(S,S)");
        assert!(CONSTANT_FREE_EML_GENERATOR_OPEN);
    }

    #[test]
    fn f_ulp_oracle_is_the_schema_freeze_gate() {
        assert!(ANSWER_PACKET_SCHEMA_FREEZE_REQUIRES_F_ULP_ORACLE);
        assert_eq!(F_ULP_ORACLE.log_sampled_points, 412_000);
        assert_eq!(F_ULP_ORACLE.stress_points, 2_048);
        assert_eq!(F_ULP_ORACLE.max_ulp_fp16, 2);
        assert_eq!(F_ULP_ORACLE.wall_clock_seconds_max, 90);
        assert_eq!(F_ULP_ORACLE.checked_interval_min, 0.5);
        assert_eq!(F_ULP_ORACLE.checked_interval_max, 2.0);
    }

    #[test]
    fn goodfire_activity_numbers_are_public_confirmed_but_runtime_is_not() {
        assert!(FOUNDATION_GOODFIRE_STATUS
            .contains(&FoundationGoodfireStatus::ActivitySubnumbersPublicConfirmed));
        assert!(FOUNDATION_GOODFIRE_STATUS
            .contains(&FoundationGoodfireStatus::RuntimeAccelerationCandidate));
    }

    #[test]
    fn drop_claims_are_not_canon_eligible() {
        assert_eq!(FoundationClaim::MonnerotEmlStar.status(), TheoremStatus::DROP);
        assert_eq!(
            FoundationClaim::SingleQuantumShefferStroke.status(),
            TheoremStatus::DROP
        );
        assert!(!FoundationClaim::MonnerotEmlStar.status().is_canon_eligible());
    }

    #[test]
    fn hedged_claims_have_falsifiers() {
        for claim in FOUNDATION_CLAIMS {
            match claim.status() {
                TheoremStatus::EB | TheoremStatus::C => {
                    assert!(claim.requires_hardware_falsifier());
                }
                TheoremStatus::P | TheoremStatus::EV | TheoremStatus::DROP => {
                    assert!(!claim.requires_hardware_falsifier());
                }
            }
        }
    }

    #[test]
    fn commitment_order_puts_oracle_before_schema_freeze() {
        let oracle = FOUNDATION_COMMITMENT_ORDER
            .iter()
            .position(|item| *item == FoundationCommitment::LandFulpOracleHarness)
            .expect("oracle commitment must exist");
        let schema = FOUNDATION_COMMITMENT_ORDER
            .iter()
            .position(|item| *item == FoundationCommitment::FreezeAnswerPacketSchemaBehindOracle)
            .expect("schema-freeze commitment must exist");
        assert!(oracle < schema);
    }
}
