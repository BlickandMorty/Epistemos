use super::oracle::{
    run_fulp_oracle, AxisStats, CpuFloatIntrinsicEvaluator, FulpEvaluator, FulpRunConfig,
    OperationStats, WorstCase,
};
use serde::{Deserialize, Serialize};

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
    pub grid_fingerprint: String,
    pub adversarial_fixture_fingerprint: String,
    pub stats: [OperationStats; 3],
    pub pass: bool,
    pub budget_target_seconds: u32,
    pub observed_wall_clock_millis: u64,
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
    FingerprintMismatch { expected: String, actual: String },
    HardwareMismatch,
    MissionMismatch,
    SchemaMismatch,
    ShaderEntrypointMismatch { expected: String, actual: String },
    ShaderMismatch { expected: String, actual: String },
    StatsMismatch,
    PassMismatch { expected: bool, actual: bool },
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

    if actual.grid_fingerprint != expected.grid_fingerprint {
        return Err(FulpReplayError::FingerprintMismatch {
            expected: expected.grid_fingerprint,
            actual: actual.grid_fingerprint,
        });
    }
    if actual.adversarial_fixture_fingerprint != expected.adversarial_fixture_fingerprint {
        return Err(FulpReplayError::FingerprintMismatch {
            expected: expected.adversarial_fixture_fingerprint,
            actual: actual.adversarial_fixture_fingerprint,
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
    if actual.budget_target_seconds != expected.budget_target_seconds {
        return Err(FulpReplayError::BudgetMismatch);
    }
    let target_millis = u64::from(expected.budget_target_seconds) * 1_000;
    if expected.observed_wall_clock_millis > target_millis
        || actual.observed_wall_clock_millis > target_millis
    {
        return Err(FulpReplayError::BudgetMismatch);
    }
    if actual.point_count != expected.point_count
        || actual.operation_evaluations != expected.operation_evaluations
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
    if !stats_match_for_replay(&expected.stats, &actual.stats) {
        return Err(FulpReplayError::StatsMismatch);
    }
    if actual.pass != expected.pass {
        return Err(FulpReplayError::PassMismatch {
            expected: expected.pass,
            actual: actual.pass,
        });
    }
    Ok(expected)
}

fn stats_match_for_replay(expected: &[OperationStats; 3], actual: &[OperationStats; 3]) -> bool {
    expected
        .iter()
        .zip(actual.iter())
        .all(|(expected, actual)| {
            expected.operation == actual.operation
                && expected.evaluated == actual.evaluated
                && expected.max_ulp == actual.max_ulp
                && expected.gate_tier == actual.gate_tier
                && expected.mean_ulp == actual.mean_ulp
                && axis_stats_match_for_replay(&expected.axis_stats, &actual.axis_stats)
                && worst_case_match_for_replay(&expected.worst_case, &actual.worst_case)
        })
}

fn axis_stats_match_for_replay(
    expected: &[AxisStats; super::StressAxis::ALL.len()],
    actual: &[AxisStats; super::StressAxis::ALL.len()],
) -> bool {
    expected
        .iter()
        .zip(actual.iter())
        .all(|(expected, actual)| {
            expected.axis == actual.axis
                && expected.evaluated == actual.evaluated
                && expected.max_ulp == actual.max_ulp
                && f64_replay_match(expected.mean_ulp, actual.mean_ulp)
                && worst_case_match_for_replay(&expected.worst_case, &actual.worst_case)
        })
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
    use crate::research::eml_ir::{adversarial_fixture_fingerprint, ReferenceRoundedEvaluator};

    #[test]
    fn witness_records_m2_pro_2023_16gb_hardware_pin() {
        let witness =
            run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &CpuFloatIntrinsicEvaluator).unwrap();
        assert_eq!(witness.schema_version, 6);
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
            witness.grid_fingerprint,
            "4a83ee96a1dffd0251307ebca42c33eb8982992a641dd641c540fd560a42bdb3"
        );
    }

    #[test]
    fn witness_records_adversarial_fixture_fingerprint() {
        let witness =
            run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &CpuFloatIntrinsicEvaluator).unwrap();
        assert_eq!(
            witness.adversarial_fixture_fingerprint,
            adversarial_fixture_fingerprint()
        );
        assert_eq!(
            witness.adversarial_fixture_fingerprint,
            "c9db81383a026a40dfb87ab81f7cc670750384c7604624c01ff73cc0708118b3"
        );
        let json = acceptance_witness_json().unwrap();
        assert!(json.contains("\"adversarial_fixture_fingerprint\""));
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
    fn replay_rejects_shader_entrypoint_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.shader_entrypoint = "morphEmlFp16".to_string();
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("entrypoint drift must fail replay");
        assert!(matches!(
            error,
            FulpReplayError::ShaderEntrypointMismatch { .. }
        ));
    }

    #[test]
    fn replay_rejects_hardware_pin_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.hardware.chip = "Apple M2 Max".to_string();
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("hardware drift must fail replay");
        assert!(matches!(error, FulpReplayError::HardwareMismatch));
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
        let target_millis = u64::from(witness.budget_target_seconds) * 1_000;
        assert!(witness.observed_wall_clock_millis <= target_millis);
        let json = acceptance_witness_json().unwrap();
        assert!(json.contains("\"observed_wall_clock_millis\""));
    }

    #[test]
    fn replay_rejects_observed_wall_clock_over_budget() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.observed_wall_clock_millis = u64::from(witness.budget_target_seconds) * 1_000 + 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("over-budget witness must fail replay");
        assert!(matches!(error, FulpReplayError::BudgetMismatch));
    }

    #[test]
    fn replay_rejects_ulp_tolerance_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.config.ulp_tolerance = 4;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("tolerance drift must fail replay");
        assert!(matches!(error, FulpReplayError::ConfigMismatch));
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
    fn replay_rejects_schema_version_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.schema_version = 2;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("schema drift must fail replay");
        assert!(matches!(error, FulpReplayError::SchemaMismatch));
    }

    #[test]
    fn replay_rejects_visible_worst_case_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.stats[0].worst_case.x = 1.25;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("worst-case drift must fail replay");
        assert!(matches!(error, FulpReplayError::StatsMismatch));
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
        assert!(matches!(error, FulpReplayError::StatsMismatch));
    }
}
