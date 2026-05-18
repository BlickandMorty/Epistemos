use super::oracle::{
    run_fulp_oracle, CpuFloatIntrinsicEvaluator, FulpEvaluator, FulpRunConfig, OperationStats,
    ReferenceRoundedEvaluator,
};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
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
    pub stats: [OperationStats; 3],
    pub pass: bool,
    pub budget_target_seconds: u32,
}

#[derive(Clone, Debug, PartialEq)]
pub enum FulpReplayError {
    InvalidJson(String),
    WitnessSerialize(String),
    UnsupportedEvaluator(String),
    Oracle(String),
    BudgetMismatch,
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
    let actual = if expected.evaluator_variant == CpuFloatIntrinsicEvaluator.variant_name() {
        run_fulp_oracle(expected.config, &CpuFloatIntrinsicEvaluator)
    } else if expected.evaluator_variant == ReferenceRoundedEvaluator.variant_name() {
        run_fulp_oracle(expected.config, &ReferenceRoundedEvaluator)
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
                && expected.worst_case.operation == actual.worst_case.operation
                && expected.worst_case.point_index == actual.worst_case.point_index
                && expected.worst_case.axis == actual.worst_case.axis
                && f64_replay_match(expected.worst_case.x, actual.worst_case.x)
                && f64_replay_match(expected.worst_case.y, actual.worst_case.y)
                && f64_replay_match(expected.worst_case.reference, actual.worst_case.reference)
                && expected.worst_case.reference_fp16_bits == actual.worst_case.reference_fp16_bits
                && expected.worst_case.candidate_fp16_bits == actual.worst_case.candidate_fp16_bits
                && expected.worst_case.ulp_error == actual.worst_case.ulp_error
        })
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
        source: "Local T12 hardware pin; serial and hardware UUID intentionally excluded"
            .to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn witness_records_m2_pro_2023_16gb_hardware_pin() {
        let witness =
            run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &CpuFloatIntrinsicEvaluator).unwrap();
        assert_eq!(witness.schema_version, 3);
        assert_eq!(witness.hardware.model, "MacBook Pro 14-inch 2023");
        assert_eq!(witness.hardware.chip, "Apple M2 Pro");
        assert_eq!(witness.hardware.memory_gb, 16);
        assert_eq!(witness.hardware.memory_bandwidth_gb_s, 200);
        assert!(witness.hardware.uma);
    }

    #[test]
    fn witness_pins_morph_oracle_shader_source() {
        let witness =
            run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &CpuFloatIntrinsicEvaluator).unwrap();
        assert_eq!(witness.shader_entrypoint, "morphOracleFp16");
        assert_eq!(witness.shader_fingerprint.len(), 64);
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
    fn replay_rejects_evaluation_count_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.operation_evaluations += 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("count drift must fail replay");
        assert!(matches!(error, FulpReplayError::CountMismatch));
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
    fn replay_rejects_fixture_config_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.config.log_sampled_points -= 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("fixture config drift must fail replay");
        assert!(
            matches!(error, FulpReplayError::Oracle(message) if message.contains("InvalidGridCount"))
        );
    }
}
