use super::oracle::{
    run_fulp_oracle, FulpEvaluator, FulpRunConfig, OperationStats, ReferenceRoundedKernel,
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
    pub budget_target_seconds: u32,
    pub config: FulpRunConfig,
    pub evaluator_variant: String,
    pub point_count: usize,
    pub operation_evaluations: usize,
    pub grid_fingerprint: String,
    pub stats: [OperationStats; 3],
    pub pass: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub enum FulpReplayError {
    InvalidJson(String),
    WitnessSerialize(String),
    UnsupportedEvaluator(String),
    Oracle(String),
    FingerprintMismatch { expected: String, actual: String },
    StatsMismatch,
    PassMismatch { expected: bool, actual: bool },
}

pub fn acceptance_witness_json() -> Result<String, FulpReplayError> {
    let witness = run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &ReferenceRoundedKernel)
        .map_err(|e| FulpReplayError::Oracle(format!("{e:?}")))?;
    serde_json::to_string_pretty(&witness)
        .map_err(|e| FulpReplayError::WitnessSerialize(e.to_string()))
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
        source: "system_profiler SPHardwareDataType on local rig; serial and UUID intentionally excluded".to_string(),
    }
}

pub fn replay_witness_json(json: &str) -> Result<FulpWitness, FulpReplayError> {
    let expected: FulpWitness =
        serde_json::from_str(json).map_err(|e| FulpReplayError::InvalidJson(e.to_string()))?;
    if expected.evaluator_variant != ReferenceRoundedKernel.variant_name() {
        return Err(FulpReplayError::UnsupportedEvaluator(
            expected.evaluator_variant,
        ));
    }
    let actual = run_fulp_oracle(expected.config, &ReferenceRoundedKernel)
        .map_err(|e| FulpReplayError::Oracle(format!("{e:?}")))?;

    if actual.grid_fingerprint != expected.grid_fingerprint {
        return Err(FulpReplayError::FingerprintMismatch {
            expected: expected.grid_fingerprint,
            actual: actual.grid_fingerprint,
        });
    }
    if actual.stats != expected.stats {
        return Err(FulpReplayError::StatsMismatch);
    }
    if actual.pass != expected.pass {
        return Err(FulpReplayError::PassMismatch {
            expected: expected.pass,
            actual: actual.pass,
        });
    }
    Ok(actual)
}
