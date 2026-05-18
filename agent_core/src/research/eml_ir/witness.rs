use super::oracle::{
    run_fulp_oracle, AdversarialReferenceStats, AxisStats, CpuFloatIntrinsicEvaluator,
    FulpEvaluator, FulpOperation, FulpRunConfig, OperationStats, WorstCase,
    FULP_BUDGET_TARGET_MILLIS, FULP_BUDGET_TARGET_SECONDS,
};
use super::StressAxis;
use serde::{Deserialize, Serialize};

pub const FULP_WITNESS_SCHEMA_VERSION: u32 = 12;

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct HardwarePin {
    pub model: String,
    pub model_identifier: String,
    pub chip: String,
    pub cpu_cores: u8,
    pub gpu_cores: u8,
    pub memory_gb: u16,
    pub uma: bool,
    pub memory_bandwidth_gb_s: u16,
    pub source: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct FulpWitness {
    pub schema_version: u32,
    pub mission: String,
    pub hardware: HardwarePin,
    pub config: FulpRunConfig,
    pub evaluator_variant: String,
    pub shader_entrypoint: String,
    pub shader_fingerprint: String,
    pub point_count: usize,
    pub operation_evaluations: usize,
    pub operation_catalog_fingerprint: String,
    pub axis_catalog_fingerprint: String,
    pub grid_fingerprint: String,
    pub adversarial_fixture_count: usize,
    pub adversarial_fixture_fingerprint: String,
    pub adversarial_reference_stats: AdversarialReferenceStats,
    pub adversarial_reference_fingerprint: String,
    pub stats: [OperationStats; 3],
    pub pass: bool,
    pub budget_target_seconds: u32,
    pub budget_target_millis: u64,
    pub observed_wall_clock_millis: u64,
}

#[derive(Clone, Debug, PartialEq)]
pub enum FingerprintKind {
    OperationCatalog,
    AxisCatalog,
    Grid,
    AdversarialFixture,
    AdversarialReference,
}

#[derive(Clone, Debug, PartialEq)]
pub enum FulpReplayError {
    InvalidJson(String),
    WitnessSerialize(String),
    UnsupportedEvaluator(String),
    Oracle(String),
    BudgetMismatch,
    ConfigMismatch,
    CountMismatch,
    FingerprintMismatch {
        kind: FingerprintKind,
        expected: String,
        actual: String,
    },
    HardwareMismatch,
    MissionMismatch,
    SchemaMismatch,
    ShaderEntrypointMismatch {
        expected: String,
        actual: String,
    },
    ShaderMismatch {
        expected: String,
        actual: String,
    },
    OperationStatsMismatch {
        expected_operation: FulpOperation,
        actual_operation: FulpOperation,
    },
    AxisStatsMismatch {
        operation: FulpOperation,
        expected_axis: StressAxis,
        actual_axis: StressAxis,
    },
    WorstCaseMismatch {
        operation: FulpOperation,
        axis: StressAxis,
        point_index: usize,
    },
    StatsMismatch,
    PassMismatch {
        expected: bool,
        actual: bool,
    },
}

impl FulpReplayError {
    pub fn is_invalid_json(&self) -> bool {
        matches!(self, Self::InvalidJson(_))
    }

    pub fn is_hardware_mismatch(&self) -> bool {
        matches!(self, Self::HardwareMismatch)
    }

    pub fn is_budget_mismatch(&self) -> bool {
        matches!(self, Self::BudgetMismatch)
    }

    pub fn is_config_mismatch(&self) -> bool {
        matches!(self, Self::ConfigMismatch)
    }

    pub fn is_count_mismatch(&self) -> bool {
        matches!(self, Self::CountMismatch)
    }

    pub fn is_stats_mismatch(&self) -> bool {
        matches!(self, Self::StatsMismatch)
    }

    pub fn operation_stats_mismatch(&self) -> Option<(FulpOperation, FulpOperation)> {
        match self {
            Self::OperationStatsMismatch {
                expected_operation,
                actual_operation,
            } => Some((*expected_operation, *actual_operation)),
            _ => None,
        }
    }

    pub fn axis_stats_mismatch(&self) -> Option<(FulpOperation, StressAxis, StressAxis)> {
        match self {
            Self::AxisStatsMismatch {
                operation,
                expected_axis,
                actual_axis,
            } => Some((*operation, *expected_axis, *actual_axis)),
            _ => None,
        }
    }

    pub fn worst_case_mismatch(&self) -> Option<(FulpOperation, StressAxis, usize)> {
        match self {
            Self::WorstCaseMismatch {
                operation,
                axis,
                point_index,
            } => Some((*operation, *axis, *point_index)),
            _ => None,
        }
    }

    pub fn is_pass_mismatch(&self) -> bool {
        matches!(self, Self::PassMismatch { .. })
    }

    pub fn is_schema_mismatch(&self) -> bool {
        matches!(self, Self::SchemaMismatch)
    }

    pub fn shader_entrypoint_mismatch(&self) -> Option<(&str, &str)> {
        match self {
            Self::ShaderEntrypointMismatch { expected, actual } => {
                Some((expected.as_str(), actual.as_str()))
            }
            _ => None,
        }
    }

    pub fn is_shader_mismatch(&self) -> bool {
        matches!(self, Self::ShaderMismatch { .. })
    }

    pub fn fingerprint_mismatch_kind(&self) -> Option<&FingerprintKind> {
        match self {
            Self::FingerprintMismatch { kind, .. } => Some(kind),
            _ => None,
        }
    }

    pub fn is_fingerprint_mismatch(&self, expected_kind: FingerprintKind) -> bool {
        self.fingerprint_mismatch_kind() == Some(&expected_kind)
    }
}

pub fn acceptance_witness_json() -> Result<String, FulpReplayError> {
    let witness = run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &CpuFloatIntrinsicEvaluator)
        .map_err(|error| FulpReplayError::Oracle(format!("{error:?}")))?;
    serde_json::to_string_pretty(&witness)
        .map_err(|error| FulpReplayError::WitnessSerialize(error.to_string()))
}

pub fn replay_witness_json(json: &str) -> Result<FulpWitness, FulpReplayError> {
    let expected: FulpWitness = serde_json::from_str(json)
        .map_err(|error| FulpReplayError::InvalidJson(error.to_string()))?;
    if expected.config != FulpRunConfig::ACCEPTANCE {
        return Err(FulpReplayError::ConfigMismatch);
    }
    let actual = if expected.evaluator_variant == CpuFloatIntrinsicEvaluator.variant_name() {
        run_fulp_oracle(expected.config, &CpuFloatIntrinsicEvaluator)
    } else {
        return Err(FulpReplayError::UnsupportedEvaluator(
            expected.evaluator_variant,
        ));
    }
    .map_err(|error| FulpReplayError::Oracle(format!("{error:?}")))?;

    if actual.operation_catalog_fingerprint != expected.operation_catalog_fingerprint {
        return Err(FulpReplayError::FingerprintMismatch {
            kind: FingerprintKind::OperationCatalog,
            expected: expected.operation_catalog_fingerprint,
            actual: actual.operation_catalog_fingerprint,
        });
    }
    if actual.axis_catalog_fingerprint != expected.axis_catalog_fingerprint {
        return Err(FulpReplayError::FingerprintMismatch {
            kind: FingerprintKind::AxisCatalog,
            expected: expected.axis_catalog_fingerprint,
            actual: actual.axis_catalog_fingerprint,
        });
    }
    if actual.grid_fingerprint != expected.grid_fingerprint {
        return Err(FulpReplayError::FingerprintMismatch {
            kind: FingerprintKind::Grid,
            expected: expected.grid_fingerprint,
            actual: actual.grid_fingerprint,
        });
    }
    if actual.adversarial_fixture_fingerprint != expected.adversarial_fixture_fingerprint {
        return Err(FulpReplayError::FingerprintMismatch {
            kind: FingerprintKind::AdversarialFixture,
            expected: expected.adversarial_fixture_fingerprint,
            actual: actual.adversarial_fixture_fingerprint,
        });
    }
    if actual.adversarial_reference_fingerprint != expected.adversarial_reference_fingerprint {
        return Err(FulpReplayError::FingerprintMismatch {
            kind: FingerprintKind::AdversarialReference,
            expected: expected.adversarial_reference_fingerprint,
            actual: actual.adversarial_reference_fingerprint,
        });
    }
    if actual.schema_version != expected.schema_version {
        return Err(FulpReplayError::SchemaMismatch);
    }
    if actual.mission != expected.mission {
        return Err(FulpReplayError::MissionMismatch);
    }
    if actual.hardware != expected.hardware {
        return Err(FulpReplayError::HardwareMismatch);
    }
    let expected_target_millis = u64::from(expected.budget_target_seconds) * 1_000;
    let actual_target_millis = u64::from(actual.budget_target_seconds) * 1_000;
    if expected.budget_target_seconds != FULP_BUDGET_TARGET_SECONDS
        || actual.budget_target_seconds != FULP_BUDGET_TARGET_SECONDS
        || expected.budget_target_millis != FULP_BUDGET_TARGET_MILLIS
        || actual.budget_target_millis != FULP_BUDGET_TARGET_MILLIS
        || expected.budget_target_millis != expected_target_millis
        || actual.budget_target_millis != actual_target_millis
    {
        return Err(FulpReplayError::BudgetMismatch);
    }
    if expected.observed_wall_clock_millis > expected_target_millis
        || actual.observed_wall_clock_millis > expected_target_millis
    {
        return Err(FulpReplayError::BudgetMismatch);
    }
    if actual.point_count != expected.point_count
        || actual.operation_evaluations != expected.operation_evaluations
        || actual.adversarial_fixture_count != expected.adversarial_fixture_count
        || actual.adversarial_reference_stats != expected.adversarial_reference_stats
    {
        return Err(FulpReplayError::CountMismatch);
    }
    if actual.shader_entrypoint != expected.shader_entrypoint {
        return Err(FulpReplayError::ShaderEntrypointMismatch {
            expected: expected.shader_entrypoint,
            actual: actual.shader_entrypoint,
        });
    }
    if actual.shader_fingerprint != expected.shader_fingerprint {
        return Err(FulpReplayError::ShaderMismatch {
            expected: expected.shader_fingerprint,
            actual: actual.shader_fingerprint,
        });
    }
    stats_match_for_replay(&expected.stats, &actual.stats)?;
    if actual.pass != expected.pass {
        return Err(FulpReplayError::PassMismatch {
            expected: expected.pass,
            actual: actual.pass,
        });
    }
    Ok(expected)
}

fn stats_match_for_replay(
    expected: &[OperationStats; 3],
    actual: &[OperationStats; 3],
) -> Result<(), FulpReplayError> {
    for (expected, actual) in expected.iter().zip(actual.iter()) {
        if expected.operation != actual.operation {
            return Err(FulpReplayError::OperationStatsMismatch {
                expected_operation: expected.operation,
                actual_operation: actual.operation,
            });
        }
        if expected.evaluated != actual.evaluated
            || expected.max_ulp != actual.max_ulp
            || expected.gate_tier != actual.gate_tier
            || expected.mean_ulp != actual.mean_ulp
        {
            return Err(FulpReplayError::StatsMismatch);
        }
        if !worst_case_match_for_replay(&expected.worst_case, &actual.worst_case) {
            return Err(worst_case_mismatch(&actual.worst_case));
        }
        axis_stats_match_for_replay(expected.operation, &expected.axis_stats, &actual.axis_stats)?;
    }
    Ok(())
}

fn axis_stats_match_for_replay(
    operation: FulpOperation,
    expected: &[AxisStats; super::StressAxis::ALL.len()],
    actual: &[AxisStats; super::StressAxis::ALL.len()],
) -> Result<(), FulpReplayError> {
    for (expected, actual) in expected.iter().zip(actual.iter()) {
        if expected.axis != actual.axis {
            return Err(FulpReplayError::AxisStatsMismatch {
                operation,
                expected_axis: expected.axis,
                actual_axis: actual.axis,
            });
        }
        if expected.evaluated != actual.evaluated
            || expected.max_ulp != actual.max_ulp
            || !f64_replay_match(expected.mean_ulp, actual.mean_ulp)
        {
            return Err(FulpReplayError::StatsMismatch);
        }
        if !worst_case_match_for_replay(&expected.worst_case, &actual.worst_case) {
            return Err(worst_case_mismatch(&actual.worst_case));
        }
    }
    Ok(())
}

fn worst_case_mismatch(actual: &WorstCase) -> FulpReplayError {
    FulpReplayError::WorstCaseMismatch {
        operation: actual.operation,
        axis: actual.axis,
        point_index: actual.point_index,
    }
}

fn worst_case_match_for_replay(expected: &WorstCase, actual: &WorstCase) -> bool {
    expected.operation == actual.operation
        && expected.point_index == actual.point_index
        && expected.axis == actual.axis
        && f64_replay_match(expected.x, actual.x)
        && f64_replay_match(expected.y, actual.y)
        && f64_replay_match(expected.reference, actual.reference)
        && expected.reference_fp16_bits == actual.reference_fp16_bits
        && expected.candidate_fp16_bits == actual.candidate_fp16_bits
        && expected.ulp_error == actual.ulp_error
}

fn f64_replay_match(expected: f64, actual: f64) -> bool {
    if expected.to_bits() == actual.to_bits() {
        return true;
    }
    if !expected.is_finite() || !actual.is_finite() {
        return false;
    }
    let scale = expected.abs().max(actual.abs()).max(1.0);
    (expected - actual).abs() <= f64::EPSILON * 4.0 * scale
}

pub(crate) fn m2_pro_2023_16gb_pin() -> HardwarePin {
    HardwarePin {
        model: "MacBook Pro 14-inch 2023".to_string(),
        model_identifier: "Mac14,9".to_string(),
        chip: "Apple M2 Pro".to_string(),
        cpu_cores: 12,
        gpu_cores: 19,
        memory_gb: 16,
        uma: true,
        memory_bandwidth_gb_s: 200,
        source: "Local T12 hardware pin; unique hardware identifiers intentionally excluded"
            .to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::research::eml_ir::{
        adversarial_fixture_fingerprint, adversarial_reference_fingerprint,
        axis_catalog_fingerprint, operation_catalog_fingerprint, FulpOperation,
        ReferenceRoundedEvaluator, StressAxis, ADVERSARIAL_FIXTURE_COUNT,
    };

    #[test]
    fn witness_records_m2_pro_2023_16gb_hardware_pin() {
        let witness =
            run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &CpuFloatIntrinsicEvaluator).unwrap();
        assert_eq!(witness.schema_version, FULP_WITNESS_SCHEMA_VERSION);
        assert_eq!(witness.hardware.model, "MacBook Pro 14-inch 2023");
        assert_eq!(witness.hardware.chip, "Apple M2 Pro");
        assert_eq!(witness.hardware.memory_gb, 16);
        assert_eq!(witness.hardware.memory_bandwidth_gb_s, 200);
        assert!(witness.hardware.uma);
    }

    #[test]
    fn witness_json_excludes_serial_and_uuid_text() {
        let json = acceptance_witness_json().unwrap();
        assert!(!json.to_ascii_lowercase().contains("serial"));
        assert!(!json.to_ascii_lowercase().contains("uuid"));
    }

    #[test]
    fn witness_pins_morph_oracle_shader_source() {
        let witness =
            run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &CpuFloatIntrinsicEvaluator).unwrap();
        assert_eq!(witness.shader_entrypoint, "morphOracleFp16");
        assert_eq!(witness.shader_fingerprint.len(), 64);
        assert_eq!(
            witness.shader_fingerprint,
            "17f0b3f9de6cf7398e54c242397b833e88a8d39b5c1b07a99085cae5717ac871"
        );
        assert_ne!(witness.shader_fingerprint, witness.grid_fingerprint);
    }

    #[test]
    fn witness_grid_fingerprint_pins_acceptance_fixture() {
        let witness =
            run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &CpuFloatIntrinsicEvaluator).unwrap();
        assert_eq!(
            witness.operation_catalog_fingerprint,
            operation_catalog_fingerprint()
        );
        assert_eq!(
            witness.operation_catalog_fingerprint,
            "ad8e99b40e8c673bb255cdc4dfa10905479e6d8b8a5c6f1ac47809e247b0bc37"
        );
        assert_eq!(witness.axis_catalog_fingerprint, axis_catalog_fingerprint());
        assert_eq!(
            witness.axis_catalog_fingerprint,
            "f0c1ec3142aafa93170de35d02e561368206e745aad481f7e32d865c5ee71537"
        );
        assert_eq!(
            witness.grid_fingerprint,
            "4a83ee96a1dffd0251307ebca42c33eb8982992a641dd641c540fd560a42bdb3"
        );
    }

    #[test]
    fn witness_records_adversarial_fixture_fingerprint() {
        let witness =
            run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &CpuFloatIntrinsicEvaluator).unwrap();
        assert_eq!(witness.adversarial_fixture_count, ADVERSARIAL_FIXTURE_COUNT);
        assert_eq!(
            witness.adversarial_fixture_fingerprint,
            adversarial_fixture_fingerprint()
        );
        assert_eq!(
            witness.adversarial_fixture_fingerprint,
            "207fffdef0c46b4d25e2568c2b8681b757c458f4de7cfcf9f3ea9e0b41afad19"
        );
        assert_eq!(
            witness.adversarial_reference_fingerprint,
            adversarial_reference_fingerprint()
        );
        assert_eq!(
            witness.adversarial_reference_fingerprint,
            "6a008162a85703828be3de70fd1268defeeb3ed44f389dc2bff034f0bf27d8c7"
        );
        assert_eq!(witness.adversarial_reference_stats.finite_count, 12);
        assert_eq!(witness.adversarial_reference_stats.rejected_count, 8);
        assert_eq!(witness.adversarial_reference_fingerprint.len(), 64);
        let json = acceptance_witness_json().unwrap();
        assert!(json.contains("\"operation_catalog_fingerprint\""));
        assert!(json.contains("\"adversarial_fixture_count\""));
        assert!(json.contains("\"adversarial_fixture_fingerprint\""));
        assert!(json.contains("\"adversarial_reference_fingerprint\""));
        assert!(json.contains("\"adversarial_reference_stats\""));
    }

    #[test]
    fn witness_json_replays_same_grid_and_stats() {
        let json = acceptance_witness_json().unwrap();
        let witness: FulpWitness = serde_json::from_str(&json).unwrap();
        let replayed = replay_witness_json(&json).unwrap();
        assert_eq!(replayed.grid_fingerprint, witness.grid_fingerprint);
        assert_eq!(replayed.stats, witness.stats);
        assert_eq!(replayed.pass, witness.pass);
    }

    #[test]
    fn replay_rejects_pass_bit_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.pass = false;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("pass-bit drift must fail replay");
        assert!(error.is_pass_mismatch());
    }

    #[test]
    fn replay_rejects_shader_entrypoint_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.shader_entrypoint = "morphEmlFp16".to_string();
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("entrypoint drift must fail replay");
        assert_eq!(
            error.shader_entrypoint_mismatch(),
            Some(("morphEmlFp16", "morphOracleFp16"))
        );
    }

    #[test]
    fn replay_rejects_shader_fingerprint_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.shader_fingerprint = "0".repeat(64);
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("shader drift must fail replay");
        assert!(error.is_shader_mismatch());
    }

    #[test]
    fn replay_rejects_hardware_pin_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.hardware.chip = "Apple M2 Max".to_string();
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("hardware drift must fail replay");
        assert!(error.is_hardware_mismatch());
    }

    #[test]
    fn replay_rejects_budget_target_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.budget_target_seconds = 91;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("budget drift must fail replay");
        assert!(matches!(error, FulpReplayError::BudgetMismatch));
    }

    #[test]
    fn witness_records_observed_wall_clock_budget() {
        let witness =
            run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &CpuFloatIntrinsicEvaluator).unwrap();
        assert_eq!(witness.budget_target_seconds, FULP_BUDGET_TARGET_SECONDS);
        assert_eq!(
            FULP_BUDGET_TARGET_MILLIS,
            u64::from(FULP_BUDGET_TARGET_SECONDS) * 1_000
        );
        let target_millis = FULP_BUDGET_TARGET_MILLIS;
        assert_eq!(witness.budget_target_millis, target_millis);
        assert!(witness.observed_wall_clock_millis <= target_millis);
        let json = acceptance_witness_json().unwrap();
        assert!(json.contains("\"budget_target_millis\""));
        assert!(json.contains("\"observed_wall_clock_millis\""));
    }

    #[test]
    fn replay_rejects_budget_target_millis_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.budget_target_millis += 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("budget millis drift must fail replay");
        assert!(matches!(error, FulpReplayError::BudgetMismatch));
    }

    #[test]
    fn replay_rejects_observed_wall_clock_over_budget() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.observed_wall_clock_millis = u64::from(witness.budget_target_seconds) * 1_000 + 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("over-budget witness must fail replay");
        assert!(error.is_budget_mismatch());
    }

    #[test]
    fn replay_rejects_ulp_tolerance_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.config.ulp_tolerance = 4;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("tolerance drift must fail replay");
        assert!(error.is_config_mismatch());
    }

    #[test]
    fn replay_rejects_point_count_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.point_count += 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("point count drift must fail replay");
        assert!(error.is_count_mismatch());
    }

    #[test]
    fn replay_rejects_evaluation_count_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.operation_evaluations += 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("count drift must fail replay");
        assert!(matches!(error, FulpReplayError::CountMismatch));
    }

    #[test]
    fn replay_rejects_operation_catalog_fingerprint_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.operation_catalog_fingerprint = "0".repeat(64);
        let json = serde_json::to_string(&witness).unwrap();
        let error =
            replay_witness_json(&json).expect_err("operation catalog drift must fail replay");
        assert!(matches!(
            error,
            FulpReplayError::FingerprintMismatch {
                kind: FingerprintKind::OperationCatalog,
                ..
            }
        ));
    }

    #[test]
    fn replay_rejects_axis_catalog_fingerprint_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.axis_catalog_fingerprint = "0".repeat(64);
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("axis catalog drift must fail replay");
        assert!(error.is_fingerprint_mismatch(FingerprintKind::AxisCatalog));
    }

    #[test]
    fn replay_rejects_grid_fingerprint_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.grid_fingerprint = "0".repeat(64);
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("grid drift must fail replay");
        assert_eq!(
            error.fingerprint_mismatch_kind(),
            Some(&FingerprintKind::Grid)
        );
    }

    #[test]
    fn replay_rejects_adversarial_fixture_fingerprint_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.adversarial_fixture_fingerprint = "0".repeat(64);
        let json = serde_json::to_string(&witness).unwrap();
        let error =
            replay_witness_json(&json).expect_err("adversarial fixture drift must fail replay");
        assert!(matches!(error, FulpReplayError::FingerprintMismatch { .. }));
    }

    #[test]
    fn replay_rejects_adversarial_reference_fingerprint_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.adversarial_reference_fingerprint = "0".repeat(64);
        let json = serde_json::to_string(&witness).unwrap();
        let error =
            replay_witness_json(&json).expect_err("adversarial reference drift must fail replay");
        assert!(matches!(
            error,
            FulpReplayError::FingerprintMismatch {
                kind: FingerprintKind::AdversarialReference,
                ..
            }
        ));
    }

    #[test]
    fn replay_rejects_adversarial_fixture_count_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.adversarial_fixture_count += 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error =
            replay_witness_json(&json).expect_err("adversarial fixture count drift must fail");
        assert!(matches!(error, FulpReplayError::CountMismatch));
    }

    #[test]
    fn replay_rejects_adversarial_reference_stats_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.adversarial_reference_stats.rejected_count += 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error =
            replay_witness_json(&json).expect_err("adversarial reference stats drift must fail");
        assert!(matches!(error, FulpReplayError::CountMismatch));
    }

    #[test]
    fn replay_rejects_schema_version_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.schema_version = 2;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("schema drift must fail replay");
        assert!(error.is_schema_mismatch());
    }

    #[test]
    fn replay_rejects_visible_worst_case_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        let expected = witness.stats[0].worst_case;
        witness.stats[0].worst_case.x = 1.25;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("worst-case drift must fail replay");
        assert_eq!(
            error.worst_case_mismatch(),
            Some((expected.operation, expected.axis, expected.point_index))
        );
    }

    #[test]
    fn replay_rejects_mission_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.mission = "not T12".to_string();
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("mission drift must fail replay");
        assert!(matches!(error, FulpReplayError::MissionMismatch));
    }

    #[test]
    fn replay_rejects_unknown_evaluator_variant() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.evaluator_variant = "metal_capture_v1".to_string();
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("unknown evaluator must fail replay");
        assert!(matches!(error, FulpReplayError::UnsupportedEvaluator(_)));
    }

    #[test]
    fn replay_rejects_reference_evaluator_as_candidate_witness() {
        let witness = run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &ReferenceRoundedEvaluator)
            .expect("reference witness");
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("reference evaluator must not replay as a candidate witness");
        assert!(matches!(error, FulpReplayError::UnsupportedEvaluator(_)));
    }

    #[test]
    fn replay_rejects_fixture_config_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.config.log_sampled_points -= 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("fixture config drift must fail replay");
        assert!(matches!(error, FulpReplayError::ConfigMismatch));
    }

    #[test]
    fn replay_rejects_unknown_top_level_json_field() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["corrupted_extra_field"] = serde_json::Value::Bool(true);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("unknown field must fail closed");
        assert!(matches!(error, FulpReplayError::InvalidJson(_)));
    }

    #[test]
    fn replay_rejects_malformed_witness_json() {
        assert_invalid_witness_json("{");
    }

    #[test]
    fn replay_rejects_unknown_nested_axis_stats_json_field() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["corrupted_extra_field"] = serde_json::Value::Bool(true);
        assert_invalid_witness_json_value(value);
    }

    #[test]
    fn witness_json_records_per_axis_max_ulp_for_regression_alerts() {
        let json = acceptance_witness_json().unwrap();
        assert!(json.contains("\"axis_stats\""));
        assert!(json.contains("\"max_ulp\""));
        assert!(json.contains("\"LogSampled\""));
        assert!(json.contains("\"EmlCrossMidpoint\""));
    }

    #[test]
    fn replay_rejects_per_axis_max_ulp_jump() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.stats[0].axis_stats[0].max_ulp += 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("axis max ULP drift must fail replay");
        assert!(error.is_stats_mismatch());
    }

    #[test]
    fn replay_reports_per_axis_identity_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.stats[0].axis_stats[0].axis = StressAxis::ClosedIntervalEdge;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("axis identity drift must fail replay");
        assert_eq!(
            error.axis_stats_mismatch(),
            Some((
                FulpOperation::Exp,
                StressAxis::ClosedIntervalEdge,
                StressAxis::LogSampled,
            ))
        );
    }

    #[test]
    fn replay_reports_operation_stats_identity_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.stats[0].operation = FulpOperation::Ln;
        let json = serde_json::to_string(&witness).unwrap();
        let error =
            replay_witness_json(&json).expect_err("operation identity drift must fail replay");
        assert_eq!(
            error.operation_stats_mismatch(),
            Some((FulpOperation::Ln, FulpOperation::Exp))
        );
    }

    fn assert_invalid_witness_json(json: &str) {
        let error = replay_witness_json(json).expect_err("invalid JSON must fail replay");
        assert!(error.is_invalid_json());
    }

    fn assert_invalid_witness_json_value(value: serde_json::Value) {
        let json = serde_json::to_string(&value).expect("corrupted JSON value");
        assert_invalid_witness_json(&json);
    }
}
