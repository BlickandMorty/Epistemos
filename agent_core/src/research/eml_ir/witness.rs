use super::oracle::{
    run_fulp_oracle, AdversarialReferenceStats, AxisStats, CpuFloatIntrinsicEvaluator,
    FulpEvaluator, FulpOperation, FulpRunConfig, OperationStats, ReferenceRoundedEvaluator,
    WorstCase, FULP_BUDGET_TARGET_MILLIS, FULP_BUDGET_TARGET_SECONDS,
};
use super::StressAxis;
use serde::de::{self, MapAccess, Visitor};
use serde::{Deserialize, Serialize};
use serde_json::value::RawValue;
use std::collections::{BTreeMap, BTreeSet};
use std::fmt;

pub const FULP_WITNESS_SCHEMA_VERSION: u32 = 12;
const OPERATION_STATS_JSON_FIELDS: &[&str] = &[
    "operation",
    "evaluated",
    "max_ulp",
    "gate_tier",
    "mean_ulp",
    "axis_stats",
    "worst_case",
];
const AXIS_STATS_JSON_FIELDS: &[&str] = &["axis", "evaluated", "max_ulp", "mean_ulp", "worst_case"];
const WORST_CASE_JSON_FIELDS: &[&str] = &[
    "operation",
    "point_index",
    "axis",
    "x",
    "y",
    "reference",
    "reference_fp16_bits",
    "candidate_fp16_bits",
    "ulp_error",
];

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

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum FulpConfigMismatchKind {
    FixtureGrid,
    UlpTolerance,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum FulpBudgetMismatchKind {
    TargetSeconds,
    TargetMillis,
    ObservedWallClock,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum FulpCountMismatchKind {
    PointCount,
    OperationEvaluations,
    AdversarialFixtureCount,
    AdversarialReferenceStats,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum FulpStatsMismatchKind {
    OperationEvaluated {
        operation: FulpOperation,
    },
    OperationMaxUlp {
        operation: FulpOperation,
    },
    OperationGateTier {
        operation: FulpOperation,
    },
    OperationMeanUlp {
        operation: FulpOperation,
    },
    AxisEvaluated {
        operation: FulpOperation,
        axis: StressAxis,
    },
    AxisMaxUlp {
        operation: FulpOperation,
        axis: StressAxis,
    },
    AxisMeanUlp {
        operation: FulpOperation,
        axis: StressAxis,
    },
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum FulpUnsupportedEvaluatorKind {
    ReferenceRounded,
    Unknown,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum FulpInvalidJsonKind {
    DuplicateField,
    EmptyInput,
    ForbiddenHardwareIdentifier,
    InvalidLength,
    Malformed,
    MissingField,
    NumberOutOfRange,
    RootShape,
    TrailingData,
    TruncatedInput,
    TypeMismatch,
    UnknownField,
}

#[derive(Clone, Debug, PartialEq)]
pub enum FulpReplayError {
    InvalidJson {
        message: String,
        kind: FulpInvalidJsonKind,
    },
    WitnessSerialize(String),
    UnsupportedEvaluator {
        variant: String,
        kind: FulpUnsupportedEvaluatorKind,
    },
    Oracle(String),
    BudgetMismatch {
        kind: FulpBudgetMismatchKind,
    },
    BudgetTargetSecondsMismatch {
        expected_seconds: u32,
        actual_seconds: u32,
    },
    BudgetTargetMillisMismatch {
        expected_millis: u64,
        actual_millis: u64,
    },
    ObservedWallClockBudgetMismatch {
        target_millis: u64,
        observed_millis: u64,
    },
    ConfigMismatch {
        kind: FulpConfigMismatchKind,
    },
    CountMismatch {
        kind: FulpCountMismatchKind,
    },
    FingerprintMismatch {
        kind: FingerprintKind,
        expected: String,
        actual: String,
    },
    HardwareMismatch {
        expected: HardwarePin,
        actual: HardwarePin,
    },
    MissionMismatch {
        expected: String,
        actual: String,
    },
    SchemaMismatch {
        expected: u32,
        actual: u32,
    },
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
    OperationMaxUlpMismatch {
        operation: FulpOperation,
        expected: u32,
        actual: u32,
    },
    OperationMeanUlpMismatch {
        operation: FulpOperation,
        expected: f64,
        actual: f64,
    },
    AxisStatsMismatch {
        operation: FulpOperation,
        expected_axis: StressAxis,
        actual_axis: StressAxis,
    },
    AxisMaxUlpMismatch {
        operation: FulpOperation,
        axis: StressAxis,
        expected: u32,
        actual: u32,
    },
    AxisMeanUlpMismatch {
        operation: FulpOperation,
        axis: StressAxis,
        expected: f64,
        actual: f64,
    },
    WorstCaseMismatch {
        operation: FulpOperation,
        axis: StressAxis,
        point_index: usize,
    },
    StatsMismatch {
        kind: FulpStatsMismatchKind,
    },
    PassMismatch {
        expected: bool,
        actual: bool,
    },
}

impl FulpReplayError {
    pub fn is_invalid_json(&self) -> bool {
        matches!(self, Self::InvalidJson { .. })
    }

    pub fn invalid_json_message(&self) -> Option<&str> {
        match self {
            Self::InvalidJson { message, .. } => Some(message.as_str()),
            _ => None,
        }
    }

    pub fn invalid_json_kind(&self) -> Option<FulpInvalidJsonKind> {
        match self {
            Self::InvalidJson { kind, .. } => Some(*kind),
            _ => None,
        }
    }

    pub fn unsupported_evaluator(&self) -> Option<&str> {
        match self {
            Self::UnsupportedEvaluator { variant, .. } => Some(variant.as_str()),
            _ => None,
        }
    }

    pub fn unsupported_evaluator_kind(&self) -> Option<FulpUnsupportedEvaluatorKind> {
        match self {
            Self::UnsupportedEvaluator { kind, .. } => Some(*kind),
            _ => None,
        }
    }

    pub fn is_hardware_mismatch(&self) -> bool {
        matches!(self, Self::HardwareMismatch { .. })
    }

    pub fn hardware_mismatch_pair(&self) -> Option<(&HardwarePin, &HardwarePin)> {
        match self {
            Self::HardwareMismatch { expected, actual } => Some((expected, actual)),
            _ => None,
        }
    }

    pub fn is_mission_mismatch(&self) -> bool {
        matches!(self, Self::MissionMismatch { .. })
    }

    pub fn mission_mismatch_pair(&self) -> Option<(&str, &str)> {
        match self {
            Self::MissionMismatch { expected, actual } => {
                Some((expected.as_str(), actual.as_str()))
            }
            _ => None,
        }
    }

    pub fn is_budget_mismatch(&self) -> bool {
        matches!(
            self,
            Self::BudgetMismatch { .. }
                | Self::BudgetTargetSecondsMismatch { .. }
                | Self::BudgetTargetMillisMismatch { .. }
                | Self::ObservedWallClockBudgetMismatch { .. }
        )
    }

    pub fn budget_mismatch_kind(&self) -> Option<FulpBudgetMismatchKind> {
        match self {
            Self::BudgetMismatch { kind } => Some(*kind),
            Self::BudgetTargetSecondsMismatch { .. } => Some(FulpBudgetMismatchKind::TargetSeconds),
            Self::BudgetTargetMillisMismatch { .. } => Some(FulpBudgetMismatchKind::TargetMillis),
            Self::ObservedWallClockBudgetMismatch { .. } => {
                Some(FulpBudgetMismatchKind::ObservedWallClock)
            }
            _ => None,
        }
    }

    pub fn budget_target_seconds_mismatch(&self) -> Option<(u32, u32)> {
        match self {
            Self::BudgetTargetSecondsMismatch {
                expected_seconds,
                actual_seconds,
            } => Some((*expected_seconds, *actual_seconds)),
            _ => None,
        }
    }

    pub fn budget_target_millis_mismatch(&self) -> Option<(u64, u64)> {
        match self {
            Self::BudgetTargetMillisMismatch {
                expected_millis,
                actual_millis,
            } => Some((*expected_millis, *actual_millis)),
            _ => None,
        }
    }

    pub fn observed_wall_clock_budget_mismatch(&self) -> Option<(u64, u64)> {
        match self {
            Self::ObservedWallClockBudgetMismatch {
                target_millis,
                observed_millis,
            } => Some((*target_millis, *observed_millis)),
            _ => None,
        }
    }

    pub fn is_config_mismatch(&self) -> bool {
        matches!(self, Self::ConfigMismatch { .. })
    }

    pub fn config_mismatch_kind(&self) -> Option<FulpConfigMismatchKind> {
        match self {
            Self::ConfigMismatch { kind } => Some(*kind),
            _ => None,
        }
    }

    pub fn is_count_mismatch(&self) -> bool {
        matches!(self, Self::CountMismatch { .. })
    }

    pub fn count_mismatch_kind(&self) -> Option<FulpCountMismatchKind> {
        match self {
            Self::CountMismatch { kind } => Some(*kind),
            _ => None,
        }
    }

    pub fn is_stats_mismatch(&self) -> bool {
        matches!(
            self,
            Self::StatsMismatch { .. }
                | Self::OperationMaxUlpMismatch { .. }
                | Self::OperationMeanUlpMismatch { .. }
                | Self::AxisMaxUlpMismatch { .. }
                | Self::AxisMeanUlpMismatch { .. }
        )
    }

    pub fn stats_mismatch_kind(&self) -> Option<FulpStatsMismatchKind> {
        match self {
            Self::StatsMismatch { kind } => Some(*kind),
            Self::OperationMaxUlpMismatch { operation, .. } => {
                Some(FulpStatsMismatchKind::OperationMaxUlp {
                    operation: *operation,
                })
            }
            Self::OperationMeanUlpMismatch { operation, .. } => {
                Some(FulpStatsMismatchKind::OperationMeanUlp {
                    operation: *operation,
                })
            }
            Self::AxisMaxUlpMismatch {
                operation, axis, ..
            } => Some(FulpStatsMismatchKind::AxisMaxUlp {
                operation: *operation,
                axis: *axis,
            }),
            Self::AxisMeanUlpMismatch {
                operation, axis, ..
            } => Some(FulpStatsMismatchKind::AxisMeanUlp {
                operation: *operation,
                axis: *axis,
            }),
            _ => None,
        }
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

    pub fn operation_max_ulp_mismatch(&self) -> Option<(FulpOperation, u32, u32)> {
        match self {
            Self::OperationMaxUlpMismatch {
                operation,
                expected,
                actual,
            } => Some((*operation, *expected, *actual)),
            _ => None,
        }
    }

    pub fn operation_mean_ulp_mismatch(&self) -> Option<(FulpOperation, f64, f64)> {
        match self {
            Self::OperationMeanUlpMismatch {
                operation,
                expected,
                actual,
            } => Some((*operation, *expected, *actual)),
            _ => None,
        }
    }

    pub fn axis_max_ulp_mismatch(&self) -> Option<(FulpOperation, StressAxis, u32, u32)> {
        match self {
            Self::AxisMaxUlpMismatch {
                operation,
                axis,
                expected,
                actual,
            } => Some((*operation, *axis, *expected, *actual)),
            _ => None,
        }
    }

    pub fn axis_mean_ulp_mismatch(&self) -> Option<(FulpOperation, StressAxis, f64, f64)> {
        match self {
            Self::AxisMeanUlpMismatch {
                operation,
                axis,
                expected,
                actual,
            } => Some((*operation, *axis, *expected, *actual)),
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

    pub fn pass_mismatch_pair(&self) -> Option<(bool, bool)> {
        match self {
            Self::PassMismatch { expected, actual } => Some((*expected, *actual)),
            _ => None,
        }
    }

    pub fn is_schema_mismatch(&self) -> bool {
        matches!(self, Self::SchemaMismatch { .. })
    }

    pub fn schema_mismatch_pair(&self) -> Option<(u32, u32)> {
        match self {
            Self::SchemaMismatch { expected, actual } => Some((*expected, *actual)),
            _ => None,
        }
    }

    pub fn shader_entrypoint_mismatch(&self) -> Option<(&str, &str)> {
        match self {
            Self::ShaderEntrypointMismatch { expected, actual } => {
                Some((expected.as_str(), actual.as_str()))
            }
            _ => None,
        }
    }

    pub fn shader_mismatch(&self) -> Option<(&str, &str)> {
        match self {
            Self::ShaderMismatch { expected, actual } => Some((expected.as_str(), actual.as_str())),
            _ => None,
        }
    }

    pub fn is_shader_mismatch(&self) -> bool {
        self.shader_mismatch().is_some()
    }

    pub fn fingerprint_mismatch_kind(&self) -> Option<&FingerprintKind> {
        match self {
            Self::FingerprintMismatch { kind, .. } => Some(kind),
            _ => None,
        }
    }

    pub fn fingerprint_mismatch(&self) -> Option<(&FingerprintKind, &str, &str)> {
        match self {
            Self::FingerprintMismatch {
                kind,
                expected,
                actual,
            } => Some((kind, expected.as_str(), actual.as_str())),
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
    if json.trim().is_empty() {
        return Err(FulpReplayError::InvalidJson {
            message: "empty witness JSON".to_string(),
            kind: FulpInvalidJsonKind::EmptyInput,
        });
    }
    reject_stats_length_json(json)?;

    let expected: FulpWitness = serde_json::from_str(json).map_err(invalid_json_error)?;
    if expected.config != FulpRunConfig::ACCEPTANCE {
        let kind = if expected.config.ulp_tolerance != FulpRunConfig::ACCEPTANCE.ulp_tolerance {
            FulpConfigMismatchKind::UlpTolerance
        } else {
            FulpConfigMismatchKind::FixtureGrid
        };
        return Err(FulpReplayError::ConfigMismatch { kind });
    }
    let actual = if expected.evaluator_variant == CpuFloatIntrinsicEvaluator.variant_name() {
        run_fulp_oracle(expected.config, &CpuFloatIntrinsicEvaluator)
    } else {
        let kind = if expected.evaluator_variant == ReferenceRoundedEvaluator.variant_name() {
            FulpUnsupportedEvaluatorKind::ReferenceRounded
        } else {
            FulpUnsupportedEvaluatorKind::Unknown
        };
        return Err(FulpReplayError::UnsupportedEvaluator {
            variant: expected.evaluator_variant,
            kind,
        });
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
        return Err(FulpReplayError::SchemaMismatch {
            expected: expected.schema_version,
            actual: actual.schema_version,
        });
    }
    if actual.mission != expected.mission {
        return Err(FulpReplayError::MissionMismatch {
            expected: expected.mission,
            actual: actual.mission,
        });
    }
    if actual.hardware != expected.hardware {
        return Err(FulpReplayError::HardwareMismatch {
            expected: expected.hardware.clone(),
            actual: actual.hardware.clone(),
        });
    }
    let expected_target_millis = u64::from(expected.budget_target_seconds) * 1_000;
    let actual_target_millis = u64::from(actual.budget_target_seconds) * 1_000;
    if expected.budget_target_seconds != FULP_BUDGET_TARGET_SECONDS
        || actual.budget_target_seconds != FULP_BUDGET_TARGET_SECONDS
    {
        return Err(FulpReplayError::BudgetTargetSecondsMismatch {
            expected_seconds: expected.budget_target_seconds,
            actual_seconds: actual.budget_target_seconds,
        });
    }
    if expected.budget_target_millis != FULP_BUDGET_TARGET_MILLIS
        || actual.budget_target_millis != FULP_BUDGET_TARGET_MILLIS
        || expected.budget_target_millis != expected_target_millis
        || actual.budget_target_millis != actual_target_millis
    {
        return Err(FulpReplayError::BudgetTargetMillisMismatch {
            expected_millis: expected.budget_target_millis,
            actual_millis: actual.budget_target_millis,
        });
    }
    if expected.observed_wall_clock_millis > expected_target_millis
        || actual.observed_wall_clock_millis > expected_target_millis
    {
        let observed_millis = expected
            .observed_wall_clock_millis
            .max(actual.observed_wall_clock_millis);
        return Err(FulpReplayError::ObservedWallClockBudgetMismatch {
            target_millis: expected_target_millis,
            observed_millis,
        });
    }
    if actual.point_count != expected.point_count {
        return Err(FulpReplayError::CountMismatch {
            kind: FulpCountMismatchKind::PointCount,
        });
    }
    if actual.operation_evaluations != expected.operation_evaluations {
        return Err(FulpReplayError::CountMismatch {
            kind: FulpCountMismatchKind::OperationEvaluations,
        });
    }
    if actual.adversarial_fixture_count != expected.adversarial_fixture_count {
        return Err(FulpReplayError::CountMismatch {
            kind: FulpCountMismatchKind::AdversarialFixtureCount,
        });
    }
    if actual.adversarial_reference_stats != expected.adversarial_reference_stats {
        return Err(FulpReplayError::CountMismatch {
            kind: FulpCountMismatchKind::AdversarialReferenceStats,
        });
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

fn reject_stats_length_json(json: &str) -> Result<(), FulpReplayError> {
    reject_raw_top_level_unsigned_json(json)?;
    reject_raw_stats_number_json(json)?;
    let value: serde_json::Value = serde_json::from_str(json).map_err(invalid_json_error)?;
    let Some(stats_value) = value.get("stats") else {
        return Ok(());
    };
    let Some(stats) = stats_value.as_array() else {
        return Err(FulpReplayError::InvalidJson {
            message: "invalid type for stats, expected array".to_string(),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    };
    let expected_stats_len = FulpOperation::ALL.len();
    if stats.len() != expected_stats_len {
        return Err(FulpReplayError::InvalidJson {
            message: format!(
                "invalid length {} for stats, expected {expected_stats_len}",
                stats.len()
            ),
            kind: FulpInvalidJsonKind::InvalidLength,
        });
    }
    required_top_level_object_json(&value, "hardware")?;
    reject_unknown_nested_json_fields(
        &value,
        "hardware",
        &[
            "model",
            "model_identifier",
            "chip",
            "cpu_cores",
            "gpu_cores",
            "memory_gb",
            "uma",
            "memory_bandwidth_gb_s",
            "source",
        ],
    )?;
    required_nested_string_json(&value, "hardware", "model")?;
    required_nested_string_json(&value, "hardware", "model_identifier")?;
    required_nested_string_json(&value, "hardware", "chip")?;
    required_nested_u8_json(&value, "hardware", "cpu_cores")?;
    required_nested_u8_json(&value, "hardware", "gpu_cores")?;
    required_nested_u16_json(&value, "hardware", "memory_gb")?;
    required_nested_bool_json(&value, "hardware", "uma")?;
    required_nested_u16_json(&value, "hardware", "memory_bandwidth_gb_s")?;
    required_nested_string_json(&value, "hardware", "source")?;
    reject_hardware_identifier_text_json(&value)?;
    required_top_level_string_json(&value, "mission")?;
    required_top_level_string_json(&value, "evaluator_variant")?;
    required_top_level_string_json(&value, "shader_entrypoint")?;
    required_top_level_string_json(&value, "shader_fingerprint")?;
    required_top_level_string_json(&value, "operation_catalog_fingerprint")?;
    required_top_level_string_json(&value, "axis_catalog_fingerprint")?;
    required_top_level_string_json(&value, "grid_fingerprint")?;
    required_top_level_string_json(&value, "adversarial_fixture_fingerprint")?;
    required_top_level_string_json(&value, "adversarial_reference_fingerprint")?;
    let point_count = top_level_unsigned_integer_json(&value, "point_count")?;
    let operation_evaluations = top_level_unsigned_integer_json(&value, "operation_evaluations")?;
    let adversarial_fixture_count =
        top_level_unsigned_integer_json(&value, "adversarial_fixture_count")?;
    top_level_u32_json(&value, "budget_target_seconds")?;
    top_level_unsigned_integer_json(&value, "budget_target_millis")?;
    top_level_unsigned_integer_json(&value, "observed_wall_clock_millis")?;
    required_top_level_bool_json(&value, "pass")?;
    reject_adversarial_reference_stats_json(&value, adversarial_fixture_count)?;
    let Some(max_point_index_exclusive) = point_count else {
        return Ok(());
    };
    let expected_len = StressAxis::ALL.len();
    for (operation_index, stat) in stats.iter().enumerate() {
        let Some(stat_object) = stat.as_object() else {
            return Err(FulpReplayError::InvalidJson {
                message: format!("invalid type for stats[{operation_index}], expected object"),
                kind: FulpInvalidJsonKind::TypeMismatch,
            });
        };
        reject_unknown_object_json_fields(
            stat_object,
            &format!("stats[{operation_index}]"),
            OPERATION_STATS_JSON_FIELDS,
        )?;
        let Some(operation_value) = stat.get("operation") else {
            return Err(FulpReplayError::InvalidJson {
                message: format!("missing field stats[{operation_index}].operation"),
                kind: FulpInvalidJsonKind::MissingField,
            });
        };
        if !operation_value.is_string() {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "invalid type for stats[{operation_index}].operation, expected string"
                ),
                kind: FulpInvalidJsonKind::TypeMismatch,
            });
        }
        if !matches!(operation_value.as_str(), Some("Exp" | "Ln" | "Eml")) {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "unknown variant for stats[{operation_index}].operation, expected Exp, Ln, or Eml"
                ),
                kind: FulpInvalidJsonKind::Malformed,
            });
        }
        let Some(evaluated_value) = stat.get("evaluated") else {
            return Err(FulpReplayError::InvalidJson {
                message: format!("missing field stats[{operation_index}].evaluated"),
                kind: FulpInvalidJsonKind::MissingField,
            });
        };
        let Some(evaluated) = evaluated_value.as_u64() else {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "invalid type for stats[{operation_index}].evaluated, expected unsigned integer"
                ),
                kind: FulpInvalidJsonKind::TypeMismatch,
            });
        };
        if let Some(operation_evaluations) = operation_evaluations {
            if evaluated > operation_evaluations {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "number out of range for stats[{operation_index}].evaluated, expected <= operation_evaluations"
                    ),
                    kind: FulpInvalidJsonKind::NumberOutOfRange,
                });
            }
        }
        let Some(max_ulp_value) = stat.get("max_ulp") else {
            return Err(FulpReplayError::InvalidJson {
                message: format!("missing field stats[{operation_index}].max_ulp"),
                kind: FulpInvalidJsonKind::MissingField,
            });
        };
        let Some(max_ulp) = max_ulp_value.as_u64() else {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "invalid type for stats[{operation_index}].max_ulp, expected unsigned integer"
                ),
                kind: FulpInvalidJsonKind::TypeMismatch,
            });
        };
        if max_ulp > u64::from(u32::MAX) {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "number out of range for stats[{operation_index}].max_ulp, expected u32"
                ),
                kind: FulpInvalidJsonKind::NumberOutOfRange,
            });
        }
        let Some(mean_ulp_value) = stat.get("mean_ulp") else {
            return Err(FulpReplayError::InvalidJson {
                message: format!("missing field stats[{operation_index}].mean_ulp"),
                kind: FulpInvalidJsonKind::MissingField,
            });
        };
        if !mean_ulp_value.is_number() {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "invalid type for stats[{operation_index}].mean_ulp, expected number"
                ),
                kind: FulpInvalidJsonKind::TypeMismatch,
            });
        }
        let Some(mean_ulp) = mean_ulp_value.as_f64() else {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "number out of range for stats[{operation_index}].mean_ulp, expected finite f64"
                ),
                kind: FulpInvalidJsonKind::NumberOutOfRange,
            });
        };
        if !mean_ulp.is_finite() {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "number out of range for stats[{operation_index}].mean_ulp, expected finite f64"
                ),
                kind: FulpInvalidJsonKind::NumberOutOfRange,
            });
        }
        if mean_ulp > f64::from(u32::MAX) {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "number out of range for stats[{operation_index}].mean_ulp, expected <= u32::MAX"
                ),
                kind: FulpInvalidJsonKind::NumberOutOfRange,
            });
        }
        let Some(gate_tier_value) = stat.get("gate_tier") else {
            return Err(FulpReplayError::InvalidJson {
                message: format!("missing field stats[{operation_index}].gate_tier"),
                kind: FulpInvalidJsonKind::MissingField,
            });
        };
        if !gate_tier_value.is_string() {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "invalid type for stats[{operation_index}].gate_tier, expected string"
                ),
                kind: FulpInvalidJsonKind::TypeMismatch,
            });
        }
        if !matches!(
            gate_tier_value.as_str(),
            Some("Primary" | "Fallback" | "Fail")
        ) {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "unknown variant for stats[{operation_index}].gate_tier, expected Primary, Fallback, or Fail"
                ),
                kind: FulpInvalidJsonKind::Malformed,
            });
        }
        let Some(axis_stats_value) = stat.get("axis_stats") else {
            return Err(FulpReplayError::InvalidJson {
                message: format!("missing field stats[{operation_index}].axis_stats"),
                kind: FulpInvalidJsonKind::MissingField,
            });
        };
        let Some(axis_stats) = axis_stats_value.as_array() else {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "invalid type for stats[{operation_index}].axis_stats, expected array"
                ),
                kind: FulpInvalidJsonKind::TypeMismatch,
            });
        };
        if axis_stats.len() != expected_len {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "invalid length {} for stats[{operation_index}].axis_stats, expected {expected_len}",
                    axis_stats.len()
                ),
                kind: FulpInvalidJsonKind::InvalidLength,
            });
        }
        for (axis_index, axis_stat) in axis_stats.iter().enumerate() {
            let Some(axis_stat_object) = axis_stat.as_object() else {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "invalid type for stats[{operation_index}].axis_stats[{axis_index}], expected object"
                    ),
                    kind: FulpInvalidJsonKind::TypeMismatch,
                });
            };
            reject_unknown_object_json_fields(
                axis_stat_object,
                &format!("stats[{operation_index}].axis_stats[{axis_index}]"),
                AXIS_STATS_JSON_FIELDS,
            )?;
            let Some(axis_value) = axis_stat.get("axis") else {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "missing field stats[{operation_index}].axis_stats[{axis_index}].axis"
                    ),
                    kind: FulpInvalidJsonKind::MissingField,
                });
            };
            if !axis_value.is_string() {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "invalid type for stats[{operation_index}].axis_stats[{axis_index}].axis, expected string"
                    ),
                    kind: FulpInvalidJsonKind::TypeMismatch,
                });
            }
            if !matches!(
                axis_value.as_str(),
                Some(
                    "LogSampled"
                        | "ClosedIntervalEdge"
                        | "ExpOutputMidpoint"
                        | "LnOutputMidpoint"
                        | "EmlCrossMidpoint"
                )
            ) {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "unknown variant for stats[{operation_index}].axis_stats[{axis_index}].axis"
                    ),
                    kind: FulpInvalidJsonKind::Malformed,
                });
            }
            let Some(evaluated_value) = axis_stat.get("evaluated") else {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "missing field stats[{operation_index}].axis_stats[{axis_index}].evaluated"
                    ),
                    kind: FulpInvalidJsonKind::MissingField,
                });
            };
            let Some(evaluated) = evaluated_value.as_u64() else {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "invalid type for stats[{operation_index}].axis_stats[{axis_index}].evaluated, expected unsigned integer"
                    ),
                    kind: FulpInvalidJsonKind::TypeMismatch,
                });
            };
            if let Some(operation_evaluations) = operation_evaluations {
                if evaluated > operation_evaluations {
                    return Err(FulpReplayError::InvalidJson {
                        message: format!(
                            "number out of range for stats[{operation_index}].axis_stats[{axis_index}].evaluated, expected <= operation_evaluations"
                        ),
                        kind: FulpInvalidJsonKind::NumberOutOfRange,
                    });
                }
            }
            let Some(max_ulp_value) = axis_stat.get("max_ulp") else {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "missing field stats[{operation_index}].axis_stats[{axis_index}].max_ulp"
                    ),
                    kind: FulpInvalidJsonKind::MissingField,
                });
            };
            let Some(max_ulp) = max_ulp_value.as_u64() else {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "invalid type for stats[{operation_index}].axis_stats[{axis_index}].max_ulp, expected unsigned integer"
                    ),
                    kind: FulpInvalidJsonKind::TypeMismatch,
                });
            };
            if max_ulp > u64::from(u32::MAX) {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "number out of range for stats[{operation_index}].axis_stats[{axis_index}].max_ulp, expected u32"
                    ),
                    kind: FulpInvalidJsonKind::NumberOutOfRange,
                });
            }
            let Some(mean_ulp_value) = axis_stat.get("mean_ulp") else {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "missing field stats[{operation_index}].axis_stats[{axis_index}].mean_ulp"
                    ),
                    kind: FulpInvalidJsonKind::MissingField,
                });
            };
            if !mean_ulp_value.is_number() {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "invalid type for stats[{operation_index}].axis_stats[{axis_index}].mean_ulp, expected number"
                    ),
                    kind: FulpInvalidJsonKind::TypeMismatch,
                });
            }
            let Some(mean_ulp) = mean_ulp_value.as_f64() else {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "number out of range for stats[{operation_index}].axis_stats[{axis_index}].mean_ulp, expected finite f64"
                    ),
                    kind: FulpInvalidJsonKind::NumberOutOfRange,
                });
            };
            if !mean_ulp.is_finite() {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "number out of range for stats[{operation_index}].axis_stats[{axis_index}].mean_ulp, expected finite f64"
                    ),
                    kind: FulpInvalidJsonKind::NumberOutOfRange,
                });
            }
            if mean_ulp > f64::from(u32::MAX) {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "number out of range for stats[{operation_index}].axis_stats[{axis_index}].mean_ulp, expected <= u32::MAX"
                    ),
                    kind: FulpInvalidJsonKind::NumberOutOfRange,
                });
            }
            let Some(axis_worst_case_value) = axis_stat.get("worst_case") else {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "missing field stats[{operation_index}].axis_stats[{axis_index}].worst_case"
                    ),
                    kind: FulpInvalidJsonKind::MissingField,
                });
            };
            if !axis_worst_case_value.is_object() {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "invalid type for stats[{operation_index}].axis_stats[{axis_index}].worst_case, expected object"
                    ),
                    kind: FulpInvalidJsonKind::TypeMismatch,
                });
            }
            let axis_worst_case_path =
                format!("stats[{operation_index}].axis_stats[{axis_index}].worst_case");
            reject_worst_case_fields_json(
                axis_worst_case_value,
                &axis_worst_case_path,
                max_point_index_exclusive,
            )?;
        }
        let Some(worst_case_value) = stat.get("worst_case") else {
            return Err(FulpReplayError::InvalidJson {
                message: format!("missing field stats[{operation_index}].worst_case"),
                kind: FulpInvalidJsonKind::MissingField,
            });
        };
        if !worst_case_value.is_object() {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "invalid type for stats[{operation_index}].worst_case, expected object"
                ),
                kind: FulpInvalidJsonKind::TypeMismatch,
            });
        }
        let worst_case_path = format!("stats[{operation_index}].worst_case");
        reject_worst_case_fields_json(
            worst_case_value,
            &worst_case_path,
            max_point_index_exclusive,
        )?;
    }
    Ok(())
}

fn top_level_unsigned_integer_json(
    value: &serde_json::Value,
    field: &str,
) -> Result<Option<u64>, FulpReplayError> {
    let Some(field_value) = value.get(field) else {
        return Ok(None);
    };
    let Some(field_value) = field_value.as_u64() else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {field}, expected unsigned integer"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    };
    Ok(Some(field_value))
}

fn top_level_u32_json(
    value: &serde_json::Value,
    field: &str,
) -> Result<Option<u32>, FulpReplayError> {
    let Some(field_value) = top_level_unsigned_integer_json(value, field)? else {
        return Ok(None);
    };
    if field_value > u64::from(u32::MAX) {
        return Err(FulpReplayError::InvalidJson {
            message: format!("number out of range for {field}, expected u32"),
            kind: FulpInvalidJsonKind::NumberOutOfRange,
        });
    }
    Ok(Some(field_value as u32))
}

fn required_top_level_bool_json(
    value: &serde_json::Value,
    field: &str,
) -> Result<bool, FulpReplayError> {
    let Some(field_value) = value.get(field) else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {field}"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    let Some(field_value) = field_value.as_bool() else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {field}, expected boolean"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    };
    Ok(field_value)
}

fn required_top_level_string_json(
    value: &serde_json::Value,
    field: &str,
) -> Result<(), FulpReplayError> {
    let Some(field_value) = value.get(field) else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {field}"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    if !field_value.is_string() {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {field}, expected string"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    }
    Ok(())
}

fn required_top_level_object_json(
    value: &serde_json::Value,
    field: &str,
) -> Result<(), FulpReplayError> {
    let Some(field_value) = value.get(field) else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {field}"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    if !field_value.is_object() {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {field}, expected object"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    }
    Ok(())
}

fn reject_unknown_nested_json_fields(
    value: &serde_json::Value,
    parent: &str,
    allowed_fields: &[&str],
) -> Result<(), FulpReplayError> {
    let Some(parent_value) = value.get(parent) else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {parent}"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    let Some(parent_object) = parent_value.as_object() else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {parent}, expected object"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    };
    reject_unknown_object_json_fields(parent_object, parent, allowed_fields)
}

fn reject_unknown_object_json_fields(
    object: &serde_json::Map<String, serde_json::Value>,
    path: &str,
    allowed_fields: &[&str],
) -> Result<(), FulpReplayError> {
    if let Some(field) = object
        .keys()
        .find(|field| !allowed_fields.contains(&field.as_str()))
    {
        return Err(FulpReplayError::InvalidJson {
            message: format!("unknown field {path}.{field}"),
            kind: FulpInvalidJsonKind::UnknownField,
        });
    }
    Ok(())
}

fn required_nested_string_json(
    value: &serde_json::Value,
    parent: &str,
    field: &str,
) -> Result<(), FulpReplayError> {
    let Some(parent_value) = value.get(parent) else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {parent}"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    let Some(parent_object) = parent_value.as_object() else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {parent}, expected object"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    };
    let path = format!("{parent}.{field}");
    let Some(field_value) = parent_object.get(field) else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {path}"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    if !field_value.is_string() {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {path}, expected string"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    }
    Ok(())
}

fn reject_hardware_identifier_text_json(value: &serde_json::Value) -> Result<(), FulpReplayError> {
    let Some(hardware) = value.get("hardware").and_then(serde_json::Value::as_object) else {
        return Ok(());
    };
    for field in ["model", "model_identifier", "chip", "source"] {
        let Some(text) = hardware.get(field).and_then(serde_json::Value::as_str) else {
            continue;
        };
        if hardware_text_contains_identifier(text) || text_contains_ethernet_mac_shape(text) {
            return Err(FulpReplayError::InvalidJson {
                message: format!("forbidden hardware identifier token in hardware.{field}"),
                kind: FulpInvalidJsonKind::ForbiddenHardwareIdentifier,
            });
        }
    }
    Ok(())
}

fn hardware_text_contains_identifier(text: &str) -> bool {
    const FORBIDDEN: &[&str] = &[
        "serial",
        "uuid",
        "ecid",
        "hwid",
        "board_id",
        "board-id",
        "ioplatform",
        "imei",
        "meid",
        "udid",
        "idfa",
        "idfv",
        "host_id",
        "hostid",
        "chip_id",
        "chipid",
        "apchipid",
        "apnonce",
        "sepnonce",
        "provisioning",
        "dep_enrollment",
        "dep-enrollment",
    ];
    let lower = text.to_ascii_lowercase();
    FORBIDDEN.iter().any(|token| lower.contains(token))
}

fn text_contains_ethernet_mac_shape(text: &str) -> bool {
    let lower = text.to_ascii_lowercase();
    lower.as_bytes().windows(17).any(|window| {
        let is_hex_pair = |slice: &[u8]| {
            slice.len() == 2 && slice[0].is_ascii_hexdigit() && slice[1].is_ascii_hexdigit()
        };
        is_hex_pair(&window[0..2])
            && window[2] == b':'
            && is_hex_pair(&window[3..5])
            && window[5] == b':'
            && is_hex_pair(&window[6..8])
            && window[8] == b':'
            && is_hex_pair(&window[9..11])
            && window[11] == b':'
            && is_hex_pair(&window[12..14])
            && window[14] == b':'
            && is_hex_pair(&window[15..17])
    })
}

fn required_nested_bool_json(
    value: &serde_json::Value,
    parent: &str,
    field: &str,
) -> Result<bool, FulpReplayError> {
    let Some(parent_value) = value.get(parent) else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {parent}"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    let Some(parent_object) = parent_value.as_object() else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {parent}, expected object"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    };
    let path = format!("{parent}.{field}");
    let Some(field_value) = parent_object.get(field) else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {path}"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    let Some(field_value) = field_value.as_bool() else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {path}, expected boolean"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    };
    Ok(field_value)
}

fn required_nested_unsigned_integer_json(
    value: &serde_json::Value,
    parent: &str,
    field: &str,
) -> Result<u64, FulpReplayError> {
    let Some(parent_value) = value.get(parent) else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {parent}"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    let value = nested_unsigned_integer_json(parent_value, parent, field)?;
    let Some(value) = value else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {parent}.{field}"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    Ok(value)
}

fn required_nested_u8_json(
    value: &serde_json::Value,
    parent: &str,
    field: &str,
) -> Result<u8, FulpReplayError> {
    let value = required_nested_unsigned_integer_json(value, parent, field)?;
    if value > u64::from(u8::MAX) {
        return Err(FulpReplayError::InvalidJson {
            message: format!("number out of range for {parent}.{field}, expected u8"),
            kind: FulpInvalidJsonKind::NumberOutOfRange,
        });
    }
    Ok(value as u8)
}

fn required_nested_u16_json(
    value: &serde_json::Value,
    parent: &str,
    field: &str,
) -> Result<u16, FulpReplayError> {
    let value = required_nested_unsigned_integer_json(value, parent, field)?;
    if value > u64::from(u16::MAX) {
        return Err(FulpReplayError::InvalidJson {
            message: format!("number out of range for {parent}.{field}, expected u16"),
            kind: FulpInvalidJsonKind::NumberOutOfRange,
        });
    }
    Ok(value as u16)
}

fn reject_adversarial_reference_stats_json(
    value: &serde_json::Value,
    adversarial_fixture_count: Option<u64>,
) -> Result<(), FulpReplayError> {
    let Some(stats_value) = value.get("adversarial_reference_stats") else {
        return Ok(());
    };
    if !stats_value.is_object() {
        return Err(FulpReplayError::InvalidJson {
            message: "invalid type for adversarial_reference_stats, expected object".to_string(),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    }
    reject_unknown_nested_json_fields(
        value,
        "adversarial_reference_stats",
        &["finite_count", "rejected_count"],
    )?;
    let finite_count = Some(required_object_unsigned_integer_json(
        stats_value,
        "adversarial_reference_stats",
        "finite_count",
    )?);
    let rejected_count = Some(required_object_unsigned_integer_json(
        stats_value,
        "adversarial_reference_stats",
        "rejected_count",
    )?);
    reject_nested_count_above(
        "adversarial_reference_stats",
        "finite_count",
        finite_count,
        adversarial_fixture_count,
        "adversarial_fixture_count",
    )?;
    reject_nested_count_above(
        "adversarial_reference_stats",
        "rejected_count",
        rejected_count,
        adversarial_fixture_count,
        "adversarial_fixture_count",
    )?;
    reject_nested_count_sum_above(
        "adversarial_reference_stats",
        "finite_count",
        finite_count,
        "rejected_count",
        rejected_count,
        adversarial_fixture_count,
        "adversarial_fixture_count",
    )?;
    Ok(())
}

fn reject_nested_count_above(
    path: &str,
    field: &str,
    value: Option<u64>,
    max_value: Option<u64>,
    max_field: &str,
) -> Result<(), FulpReplayError> {
    let (Some(value), Some(max_value)) = (value, max_value) else {
        return Ok(());
    };
    if value > max_value {
        return Err(FulpReplayError::InvalidJson {
            message: format!("number out of range for {path}.{field}, expected <= {max_field}"),
            kind: FulpInvalidJsonKind::NumberOutOfRange,
        });
    }
    Ok(())
}

fn reject_nested_count_sum_above(
    path: &str,
    left_field: &str,
    left_value: Option<u64>,
    right_field: &str,
    right_value: Option<u64>,
    max_value: Option<u64>,
    max_field: &str,
) -> Result<(), FulpReplayError> {
    let (Some(left_value), Some(right_value), Some(max_value)) =
        (left_value, right_value, max_value)
    else {
        return Ok(());
    };
    let Some(sum) = left_value.checked_add(right_value) else {
        return Err(FulpReplayError::InvalidJson {
            message: format!(
                "number out of range for {path}.{left_field}+{right_field}, expected <= {max_field}"
            ),
            kind: FulpInvalidJsonKind::NumberOutOfRange,
        });
    };
    if sum > max_value {
        return Err(FulpReplayError::InvalidJson {
            message: format!(
                "number out of range for {path}.{left_field}+{right_field}, expected <= {max_field}"
            ),
            kind: FulpInvalidJsonKind::NumberOutOfRange,
        });
    }
    Ok(())
}

fn nested_unsigned_integer_json(
    value: &serde_json::Value,
    path: &str,
    field: &str,
) -> Result<Option<u64>, FulpReplayError> {
    let Some(field_value) = value.get(field) else {
        return Ok(None);
    };
    let Some(field_value) = field_value.as_u64() else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {path}.{field}, expected unsigned integer"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    };
    Ok(Some(field_value))
}

fn required_object_unsigned_integer_json(
    value: &serde_json::Value,
    path: &str,
    field: &str,
) -> Result<u64, FulpReplayError> {
    let Some(value) = nested_unsigned_integer_json(value, path, field)? else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {path}.{field}"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    Ok(value)
}

fn nested_finite_f64_json(
    value: &serde_json::Value,
    path: &str,
    field: &str,
) -> Result<f64, FulpReplayError> {
    let Some(field_value) = value.get(field) else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {path}.{field}"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    if !field_value.is_number() {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {path}.{field}, expected number"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    }
    let Some(field_value) = field_value.as_f64() else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("number out of range for {path}.{field}, expected finite f64"),
            kind: FulpInvalidJsonKind::NumberOutOfRange,
        });
    };
    if !field_value.is_finite() {
        return Err(FulpReplayError::InvalidJson {
            message: format!("number out of range for {path}.{field}, expected finite f64"),
            kind: FulpInvalidJsonKind::NumberOutOfRange,
        });
    }
    Ok(field_value)
}

#[derive(Deserialize)]
struct RawTopLevelUnsigned<'a> {
    #[serde(default, borrow)]
    schema_version: Option<&'a RawValue>,
    #[serde(default, borrow)]
    hardware: Option<&'a RawValue>,
    #[serde(default, borrow)]
    config: Option<&'a RawValue>,
    #[serde(default, borrow)]
    adversarial_reference_stats: Option<&'a RawValue>,
    #[serde(default, borrow)]
    point_count: Option<&'a RawValue>,
    #[serde(default, borrow)]
    operation_evaluations: Option<&'a RawValue>,
    #[serde(default, borrow)]
    adversarial_fixture_count: Option<&'a RawValue>,
    #[serde(default, borrow)]
    budget_target_seconds: Option<&'a RawValue>,
    #[serde(default, borrow)]
    budget_target_millis: Option<&'a RawValue>,
    #[serde(default, borrow)]
    observed_wall_clock_millis: Option<&'a RawValue>,
}

fn reject_raw_top_level_unsigned_json(json: &str) -> Result<(), FulpReplayError> {
    reject_raw_object_duplicate_json(json, "")?;
    reject_raw_top_level_unknown_json(json)?;
    let Ok(raw_witness) = serde_json::from_str::<RawTopLevelUnsigned<'_>>(json) else {
        return Ok(());
    };
    if let Some(value) = raw_witness.schema_version {
        raw_u32_json(value, "schema_version")?;
    }
    if let Some(value) = raw_witness.hardware {
        reject_raw_hardware_unsigned_json(value)?;
    }
    if let Some(value) = raw_witness.config {
        reject_raw_config_unsigned_json(value)?;
    }
    if let Some(value) = raw_witness.adversarial_reference_stats {
        reject_raw_adversarial_reference_stats_unsigned_json(value)?;
    }
    if let Some(value) = raw_witness.point_count {
        raw_unsigned_integer_json(value, "point_count")?;
    }
    if let Some(value) = raw_witness.operation_evaluations {
        raw_unsigned_integer_json(value, "operation_evaluations")?;
    }
    if let Some(value) = raw_witness.adversarial_fixture_count {
        raw_unsigned_integer_json(value, "adversarial_fixture_count")?;
    }
    if let Some(value) = raw_witness.budget_target_seconds {
        raw_unsigned_integer_json(value, "budget_target_seconds")?;
    }
    if let Some(value) = raw_witness.budget_target_millis {
        raw_unsigned_integer_json(value, "budget_target_millis")?;
    }
    if let Some(value) = raw_witness.observed_wall_clock_millis {
        raw_unsigned_integer_json(value, "observed_wall_clock_millis")?;
    }
    Ok(())
}

fn reject_raw_top_level_unknown_json(json: &str) -> Result<(), FulpReplayError> {
    let Ok(raw_witness) = serde_json::from_str::<BTreeMap<String, Box<RawValue>>>(json) else {
        return Ok(());
    };
    if let Some(field) = raw_witness.keys().find(|field| {
        !matches!(
            field.as_str(),
            "schema_version"
                | "mission"
                | "hardware"
                | "config"
                | "evaluator_variant"
                | "shader_entrypoint"
                | "shader_fingerprint"
                | "point_count"
                | "operation_evaluations"
                | "operation_catalog_fingerprint"
                | "axis_catalog_fingerprint"
                | "grid_fingerprint"
                | "adversarial_fixture_count"
                | "adversarial_fixture_fingerprint"
                | "adversarial_reference_stats"
                | "adversarial_reference_fingerprint"
                | "stats"
                | "pass"
                | "budget_target_seconds"
                | "budget_target_millis"
                | "observed_wall_clock_millis"
        )
    }) {
        return Err(FulpReplayError::InvalidJson {
            message: format!("unknown field {field}"),
            kind: FulpInvalidJsonKind::UnknownField,
        });
    }
    Ok(())
}

fn reject_raw_hardware_unsigned_json(raw_hardware: &RawValue) -> Result<(), FulpReplayError> {
    if !raw_hardware.get().trim_start().starts_with('{') {
        return Ok(());
    }
    reject_raw_object_duplicate_json(raw_hardware.get(), "hardware")?;
    let Ok(raw_hardware) =
        serde_json::from_str::<BTreeMap<String, Box<RawValue>>>(raw_hardware.get())
    else {
        return Ok(());
    };
    if let Some(field) = raw_hardware.keys().find(|field| {
        !matches!(
            field.as_str(),
            "model"
                | "model_identifier"
                | "chip"
                | "cpu_cores"
                | "gpu_cores"
                | "memory_gb"
                | "uma"
                | "memory_bandwidth_gb_s"
                | "source"
        )
    }) {
        return Err(FulpReplayError::InvalidJson {
            message: format!("unknown field hardware.{field}"),
            kind: FulpInvalidJsonKind::UnknownField,
        });
    }
    if let Some(value) = raw_hardware.get("cpu_cores") {
        raw_u8_json(value, "hardware.cpu_cores")?;
    }
    if let Some(value) = raw_hardware.get("gpu_cores") {
        raw_u8_json(value, "hardware.gpu_cores")?;
    }
    if let Some(value) = raw_hardware.get("memory_gb") {
        raw_u16_json(value, "hardware.memory_gb")?;
    }
    if let Some(value) = raw_hardware.get("memory_bandwidth_gb_s") {
        raw_u16_json(value, "hardware.memory_bandwidth_gb_s")?;
    }
    Ok(())
}

fn reject_raw_config_unsigned_json(raw_config: &RawValue) -> Result<(), FulpReplayError> {
    if !raw_config.get().trim_start().starts_with('{') {
        return Err(FulpReplayError::InvalidJson {
            message: "invalid type for config, expected object".to_string(),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    }
    reject_raw_object_duplicate_json(raw_config.get(), "config")?;
    let Ok(raw_config) = serde_json::from_str::<BTreeMap<String, Box<RawValue>>>(raw_config.get())
    else {
        return Ok(());
    };
    if let Some(field) = raw_config.keys().find(|field| {
        !matches!(
            field.as_str(),
            "log_sampled_points" | "stress_points" | "ulp_tolerance"
        )
    }) {
        return Err(FulpReplayError::InvalidJson {
            message: format!("unknown field config.{field}"),
            kind: FulpInvalidJsonKind::UnknownField,
        });
    }
    let value = required_raw_json_field(
        raw_config
            .get("log_sampled_points")
            .map(|value| value.as_ref()),
        "config.log_sampled_points",
    )?;
    raw_unsigned_integer_json(value, "config.log_sampled_points")?;
    let value = required_raw_json_field(
        raw_config.get("stress_points").map(|value| value.as_ref()),
        "config.stress_points",
    )?;
    raw_unsigned_integer_json(value, "config.stress_points")?;
    let value = required_raw_json_field(
        raw_config.get("ulp_tolerance").map(|value| value.as_ref()),
        "config.ulp_tolerance",
    )?;
    raw_u32_json(value, "config.ulp_tolerance")?;
    Ok(())
}

fn reject_raw_adversarial_reference_stats_unsigned_json(
    raw_stats: &RawValue,
) -> Result<(), FulpReplayError> {
    if !raw_stats.get().trim_start().starts_with('{') {
        return Ok(());
    }
    reject_raw_object_duplicate_json(raw_stats.get(), "adversarial_reference_stats")?;
    let Ok(raw_stats) = serde_json::from_str::<BTreeMap<String, Box<RawValue>>>(raw_stats.get())
    else {
        return Ok(());
    };
    if let Some(field) = raw_stats
        .keys()
        .find(|field| !matches!(field.as_str(), "finite_count" | "rejected_count"))
    {
        return Err(FulpReplayError::InvalidJson {
            message: format!("unknown field adversarial_reference_stats.{field}"),
            kind: FulpInvalidJsonKind::UnknownField,
        });
    }
    if let Some(value) = raw_stats.get("finite_count") {
        raw_unsigned_integer_json(value, "adversarial_reference_stats.finite_count")?;
    }
    if let Some(value) = raw_stats.get("rejected_count") {
        raw_unsigned_integer_json(value, "adversarial_reference_stats.rejected_count")?;
    }
    Ok(())
}

fn reject_raw_object_duplicate_json(raw_json: &str, path: &str) -> Result<(), FulpReplayError> {
    if !raw_json.trim_start().starts_with('{') {
        return Ok(());
    }
    let mut deserializer = serde_json::Deserializer::from_str(raw_json);
    match serde::Deserializer::deserialize_map(&mut deserializer, RawDuplicateFieldVisitor { path })
    {
        Ok(()) => Ok(()),
        Err(error) => {
            let message = error.to_string();
            if message.contains("duplicate field") {
                Err(FulpReplayError::InvalidJson {
                    message,
                    kind: FulpInvalidJsonKind::DuplicateField,
                })
            } else {
                Ok(())
            }
        }
    }
}

fn reject_raw_object_unknown_json_fields(
    raw_json: &str,
    path: &str,
    allowed_fields: &[&str],
) -> Result<(), FulpReplayError> {
    let Ok(object) = serde_json::from_str::<BTreeMap<String, Box<RawValue>>>(raw_json) else {
        return Ok(());
    };
    if let Some(field) = object
        .keys()
        .find(|field| !allowed_fields.contains(&field.as_str()))
    {
        return Err(FulpReplayError::InvalidJson {
            message: format!("unknown field {path}.{field}"),
            kind: FulpInvalidJsonKind::UnknownField,
        });
    }
    Ok(())
}

fn reject_raw_object_missing_json_fields(
    raw_json: &str,
    path: &str,
    required_fields: &[&str],
) -> Result<(), FulpReplayError> {
    let Ok(object) = serde_json::from_str::<BTreeMap<String, Box<RawValue>>>(raw_json) else {
        return Ok(());
    };
    if let Some(field) = required_fields
        .iter()
        .find(|field| !object.contains_key(**field))
    {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {path}.{field}"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    }
    Ok(())
}

struct RawDuplicateFieldVisitor<'a> {
    path: &'a str,
}

impl<'a, 'de> Visitor<'de> for RawDuplicateFieldVisitor<'a> {
    type Value = ();

    fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("object")
    }

    fn visit_map<A>(self, mut map: A) -> Result<(), A::Error>
    where
        A: MapAccess<'de>,
    {
        let mut seen = BTreeSet::new();
        while let Some(field) = map.next_key::<String>()? {
            if !seen.insert(field.clone()) {
                let field_path = if self.path.is_empty() {
                    field
                } else {
                    format!("{}.{}", self.path, field)
                };
                return Err(de::Error::custom(format!("duplicate field {field_path}")));
            }
            let _ = map.next_value::<&RawValue>()?;
        }
        Ok(())
    }
}

fn required_raw_json_field<'a>(
    value: Option<&'a RawValue>,
    field: &str,
) -> Result<&'a RawValue, FulpReplayError> {
    let Some(value) = value else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {field}"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    Ok(value)
}

fn raw_u32_json(raw_value: &RawValue, field: &str) -> Result<u32, FulpReplayError> {
    Ok(raw_bounded_unsigned_integer_json(raw_value, field, u64::from(u32::MAX), "u32")? as u32)
}

fn raw_u16_json(raw_value: &RawValue, field: &str) -> Result<u16, FulpReplayError> {
    Ok(raw_bounded_unsigned_integer_json(raw_value, field, u64::from(u16::MAX), "u16")? as u16)
}

fn raw_u8_json(raw_value: &RawValue, field: &str) -> Result<u8, FulpReplayError> {
    Ok(raw_bounded_unsigned_integer_json(raw_value, field, u64::from(u8::MAX), "u8")? as u8)
}

fn raw_bounded_unsigned_integer_json(
    raw_value: &RawValue,
    field: &str,
    max: u64,
    expected: &str,
) -> Result<u64, FulpReplayError> {
    match serde_json::from_str::<u64>(raw_value.get()) {
        Ok(value) if value <= max => Ok(value),
        Ok(_) => Err(FulpReplayError::InvalidJson {
            message: format!("number out of range for {field}, expected {expected}"),
            kind: FulpInvalidJsonKind::NumberOutOfRange,
        }),
        Err(error) => {
            let message = error.to_string();
            if message.contains("number out of range") {
                Err(FulpReplayError::InvalidJson {
                    message: format!("number out of range for {field}, expected {expected}"),
                    kind: FulpInvalidJsonKind::NumberOutOfRange,
                })
            } else {
                Err(FulpReplayError::InvalidJson {
                    message: format!("invalid type for {field}, expected unsigned integer"),
                    kind: FulpInvalidJsonKind::TypeMismatch,
                })
            }
        }
    }
}

fn raw_unsigned_integer_json(raw_value: &RawValue, field: &str) -> Result<u64, FulpReplayError> {
    match serde_json::from_str::<u64>(raw_value.get()) {
        Ok(value) => Ok(value),
        Err(error) => {
            let message = error.to_string();
            if message.contains("number out of range") {
                Err(FulpReplayError::InvalidJson {
                    message: format!("number out of range for {field}, expected unsigned integer"),
                    kind: FulpInvalidJsonKind::NumberOutOfRange,
                })
            } else {
                Err(FulpReplayError::InvalidJson {
                    message: format!("invalid type for {field}, expected unsigned integer"),
                    kind: FulpInvalidJsonKind::TypeMismatch,
                })
            }
        }
    }
}

#[derive(Deserialize)]
struct RawWitnessWorstCases<'a> {
    #[serde(borrow)]
    stats: [&'a RawValue; 3],
}

#[derive(Deserialize)]
struct RawOperationWorstCases<'a> {
    #[serde(default, borrow)]
    evaluated: Option<&'a RawValue>,
    #[serde(default, borrow)]
    max_ulp: Option<&'a RawValue>,
    #[serde(borrow)]
    mean_ulp: &'a RawValue,
    #[serde(borrow)]
    axis_stats: [&'a RawValue; StressAxis::ALL.len()],
    #[serde(borrow)]
    worst_case: &'a RawValue,
}

#[derive(Deserialize)]
struct RawAxisWorstCase<'a> {
    #[serde(default, borrow)]
    evaluated: Option<&'a RawValue>,
    #[serde(default, borrow)]
    max_ulp: Option<&'a RawValue>,
    #[serde(borrow)]
    mean_ulp: &'a RawValue,
    #[serde(borrow)]
    worst_case: &'a RawValue,
}

#[derive(Deserialize)]
struct RawWorstCaseNumbers<'a> {
    #[serde(default, borrow)]
    point_index: Option<&'a RawValue>,
    #[serde(default, borrow)]
    reference_fp16_bits: Option<&'a RawValue>,
    #[serde(default, borrow)]
    candidate_fp16_bits: Option<&'a RawValue>,
    #[serde(default, borrow)]
    ulp_error: Option<&'a RawValue>,
    #[serde(borrow)]
    x: &'a RawValue,
    #[serde(borrow)]
    y: &'a RawValue,
    #[serde(borrow)]
    reference: &'a RawValue,
}

fn reject_raw_stats_number_json(json: &str) -> Result<(), FulpReplayError> {
    let Ok(raw_witness) = serde_json::from_str::<RawWitnessWorstCases<'_>>(json) else {
        return Ok(());
    };
    for (operation_index, stat) in raw_witness.stats.iter().enumerate() {
        let operation_path = format!("stats[{operation_index}]");
        reject_raw_object_duplicate_json(stat.get(), &operation_path)?;
        reject_raw_object_unknown_json_fields(
            stat.get(),
            &operation_path,
            OPERATION_STATS_JSON_FIELDS,
        )?;
        reject_raw_object_missing_json_fields(
            stat.get(),
            &operation_path,
            OPERATION_STATS_JSON_FIELDS,
        )?;
        let Ok(stat) = serde_json::from_str::<RawOperationWorstCases<'_>>(stat.get()) else {
            continue;
        };
        if let Some(value) = stat.evaluated {
            raw_unsigned_integer_json(value, &format!("{operation_path}.evaluated"))?;
        }
        if let Some(value) = stat.max_ulp {
            raw_u32_json(value, &format!("{operation_path}.max_ulp"))?;
        }
        raw_finite_f64_json(stat.mean_ulp, &operation_path, "mean_ulp")?;
        for (axis_index, axis_stat) in stat.axis_stats.iter().enumerate() {
            let axis_path = format!("stats[{operation_index}].axis_stats[{axis_index}]");
            reject_raw_object_duplicate_json(axis_stat.get(), &axis_path)?;
            reject_raw_object_unknown_json_fields(
                axis_stat.get(),
                &axis_path,
                AXIS_STATS_JSON_FIELDS,
            )?;
            reject_raw_object_missing_json_fields(
                axis_stat.get(),
                &axis_path,
                AXIS_STATS_JSON_FIELDS,
            )?;
            let Ok(axis_stat) = serde_json::from_str::<RawAxisWorstCase<'_>>(axis_stat.get())
            else {
                continue;
            };
            if let Some(value) = axis_stat.evaluated {
                raw_unsigned_integer_json(value, &format!("{axis_path}.evaluated"))?;
            }
            if let Some(value) = axis_stat.max_ulp {
                raw_u32_json(value, &format!("{axis_path}.max_ulp"))?;
            }
            raw_finite_f64_json(axis_stat.mean_ulp, &axis_path, "mean_ulp")?;
            let worst_case_path = format!("{axis_path}.worst_case");
            reject_raw_worst_case_numbers_raw_json(axis_stat.worst_case, &worst_case_path)?;
        }
        let worst_case_path = format!("{operation_path}.worst_case");
        reject_raw_worst_case_numbers_raw_json(stat.worst_case, &worst_case_path)?;
    }
    Ok(())
}

fn reject_raw_worst_case_numbers_raw_json(
    worst_case: &RawValue,
    path: &str,
) -> Result<(), FulpReplayError> {
    reject_raw_object_duplicate_json(worst_case.get(), path)?;
    reject_raw_object_unknown_json_fields(worst_case.get(), path, WORST_CASE_JSON_FIELDS)?;
    reject_raw_object_missing_json_fields(worst_case.get(), path, WORST_CASE_JSON_FIELDS)?;
    let Ok(worst_case) = serde_json::from_str::<RawWorstCaseNumbers<'_>>(worst_case.get()) else {
        return Ok(());
    };
    reject_raw_worst_case_numbers_json(&worst_case, path)
}

fn reject_raw_worst_case_numbers_json(
    worst_case: &RawWorstCaseNumbers<'_>,
    path: &str,
) -> Result<(), FulpReplayError> {
    if let Some(value) = worst_case.point_index {
        raw_unsigned_integer_json(value, &format!("{path}.point_index"))?;
    }
    if let Some(value) = worst_case.reference_fp16_bits {
        raw_u16_json(value, &format!("{path}.reference_fp16_bits"))?;
    }
    if let Some(value) = worst_case.candidate_fp16_bits {
        raw_u16_json(value, &format!("{path}.candidate_fp16_bits"))?;
    }
    if let Some(value) = worst_case.ulp_error {
        raw_u32_json(value, &format!("{path}.ulp_error"))?;
    }
    raw_finite_f64_json(worst_case.x, path, "x")?;
    raw_finite_f64_json(worst_case.y, path, "y")?;
    raw_finite_f64_json(worst_case.reference, path, "reference")?;
    Ok(())
}

fn raw_finite_f64_json(
    raw_value: &RawValue,
    path: &str,
    field: &str,
) -> Result<f64, FulpReplayError> {
    match serde_json::from_str::<f64>(raw_value.get()) {
        Ok(value) if value.is_finite() => Ok(value),
        Ok(_) => Err(FulpReplayError::InvalidJson {
            message: format!("number out of range for {path}.{field}, expected finite f64"),
            kind: FulpInvalidJsonKind::NumberOutOfRange,
        }),
        Err(error) => {
            let message = error.to_string();
            if message.contains("number out of range") {
                Err(FulpReplayError::InvalidJson {
                    message: format!("number out of range for {path}.{field}, expected finite f64"),
                    kind: FulpInvalidJsonKind::NumberOutOfRange,
                })
            } else {
                Err(FulpReplayError::InvalidJson {
                    message: format!("invalid type for {path}.{field}, expected number"),
                    kind: FulpInvalidJsonKind::TypeMismatch,
                })
            }
        }
    }
}

fn reject_worst_case_fields_json(
    worst_case_value: &serde_json::Value,
    path: &str,
    max_point_index_exclusive: u64,
) -> Result<(), FulpReplayError> {
    let Some(worst_case_object) = worst_case_value.as_object() else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {path}, expected object"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    };
    reject_unknown_object_json_fields(worst_case_object, path, WORST_CASE_JSON_FIELDS)?;
    let Some(operation_value) = worst_case_value.get("operation") else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {path}.operation"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    if !operation_value.is_string() {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {path}.operation, expected string"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    }
    if !matches!(operation_value.as_str(), Some("Exp" | "Ln" | "Eml")) {
        return Err(FulpReplayError::InvalidJson {
            message: format!("unknown variant for {path}.operation, expected Exp, Ln, or Eml"),
            kind: FulpInvalidJsonKind::Malformed,
        });
    }
    let Some(point_index_value) = worst_case_value.get("point_index") else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {path}.point_index"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    let Some(point_index) = point_index_value.as_u64() else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {path}.point_index, expected unsigned integer"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    };
    if point_index >= max_point_index_exclusive {
        return Err(FulpReplayError::InvalidJson {
            message: format!("number out of range for {path}.point_index, expected < point_count"),
            kind: FulpInvalidJsonKind::NumberOutOfRange,
        });
    }
    let Some(axis_value) = worst_case_value.get("axis") else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {path}.axis"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    if !axis_value.is_string() {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {path}.axis, expected string"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    }
    if !matches!(
        axis_value.as_str(),
        Some(
            "LogSampled"
                | "ClosedIntervalEdge"
                | "ExpOutputMidpoint"
                | "LnOutputMidpoint"
                | "EmlCrossMidpoint"
        )
    ) {
        return Err(FulpReplayError::InvalidJson {
            message: format!("unknown variant for {path}.axis"),
            kind: FulpInvalidJsonKind::Malformed,
        });
    }
    nested_finite_f64_json(worst_case_value, path, "x")?;
    nested_finite_f64_json(worst_case_value, path, "y")?;
    nested_finite_f64_json(worst_case_value, path, "reference")?;
    let Some(reference_bits_value) = worst_case_value.get("reference_fp16_bits") else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {path}.reference_fp16_bits"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    let Some(reference_bits) = reference_bits_value.as_u64() else {
        return Err(FulpReplayError::InvalidJson {
            message: format!(
                "invalid type for {path}.reference_fp16_bits, expected unsigned integer"
            ),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    };
    if reference_bits > u64::from(u16::MAX) {
        return Err(FulpReplayError::InvalidJson {
            message: format!("number out of range for {path}.reference_fp16_bits, expected u16"),
            kind: FulpInvalidJsonKind::NumberOutOfRange,
        });
    }
    let Some(candidate_bits_value) = worst_case_value.get("candidate_fp16_bits") else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {path}.candidate_fp16_bits"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    let Some(candidate_bits) = candidate_bits_value.as_u64() else {
        return Err(FulpReplayError::InvalidJson {
            message: format!(
                "invalid type for {path}.candidate_fp16_bits, expected unsigned integer"
            ),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    };
    if candidate_bits > u64::from(u16::MAX) {
        return Err(FulpReplayError::InvalidJson {
            message: format!("number out of range for {path}.candidate_fp16_bits, expected u16"),
            kind: FulpInvalidJsonKind::NumberOutOfRange,
        });
    }
    let Some(ulp_error_value) = worst_case_value.get("ulp_error") else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("missing field {path}.ulp_error"),
            kind: FulpInvalidJsonKind::MissingField,
        });
    };
    let Some(ulp_error) = ulp_error_value.as_u64() else {
        return Err(FulpReplayError::InvalidJson {
            message: format!("invalid type for {path}.ulp_error, expected unsigned integer"),
            kind: FulpInvalidJsonKind::TypeMismatch,
        });
    };
    if ulp_error > u64::from(u32::MAX) {
        return Err(FulpReplayError::InvalidJson {
            message: format!("number out of range for {path}.ulp_error, expected u32"),
            kind: FulpInvalidJsonKind::NumberOutOfRange,
        });
    }
    Ok(())
}

fn invalid_json_error(error: serde_json::Error) -> FulpReplayError {
    let message = error.to_string();
    let kind = if message.contains("unknown field") {
        FulpInvalidJsonKind::UnknownField
    } else if message.contains("duplicate field") {
        FulpInvalidJsonKind::DuplicateField
    } else if message.contains("expected struct FulpWitness") {
        FulpInvalidJsonKind::RootShape
    } else if message.contains("invalid length") {
        FulpInvalidJsonKind::InvalidLength
    } else if message.contains("missing field") {
        FulpInvalidJsonKind::MissingField
    } else if message.contains("number out of range") {
        FulpInvalidJsonKind::NumberOutOfRange
    } else if message.contains("trailing characters") {
        FulpInvalidJsonKind::TrailingData
    } else if message.contains("EOF") {
        FulpInvalidJsonKind::TruncatedInput
    } else if message.contains("invalid type") {
        FulpInvalidJsonKind::TypeMismatch
    } else {
        FulpInvalidJsonKind::Malformed
    };
    FulpReplayError::InvalidJson { message, kind }
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
        if expected.evaluated != actual.evaluated {
            return Err(FulpReplayError::StatsMismatch {
                kind: FulpStatsMismatchKind::OperationEvaluated {
                    operation: actual.operation,
                },
            });
        }
        if expected.max_ulp != actual.max_ulp {
            return Err(FulpReplayError::OperationMaxUlpMismatch {
                operation: actual.operation,
                expected: expected.max_ulp,
                actual: actual.max_ulp,
            });
        }
        if expected.gate_tier != actual.gate_tier {
            return Err(FulpReplayError::StatsMismatch {
                kind: FulpStatsMismatchKind::OperationGateTier {
                    operation: actual.operation,
                },
            });
        }
        if expected.mean_ulp != actual.mean_ulp {
            return Err(FulpReplayError::OperationMeanUlpMismatch {
                operation: actual.operation,
                expected: expected.mean_ulp,
                actual: actual.mean_ulp,
            });
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
        if expected.evaluated != actual.evaluated {
            return Err(FulpReplayError::StatsMismatch {
                kind: FulpStatsMismatchKind::AxisEvaluated {
                    operation,
                    axis: actual.axis,
                },
            });
        }
        if expected.max_ulp != actual.max_ulp {
            return Err(FulpReplayError::AxisMaxUlpMismatch {
                operation,
                axis: actual.axis,
                expected: expected.max_ulp,
                actual: actual.max_ulp,
            });
        }
        if !f64_replay_match(expected.mean_ulp, actual.mean_ulp) {
            return Err(FulpReplayError::AxisMeanUlpMismatch {
                operation,
                axis: actual.axis,
                expected: expected.mean_ulp,
                actual: actual.mean_ulp,
            });
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
    fn witness_json_excludes_ecid_text() {
        let json = acceptance_witness_json().unwrap();
        assert!(!json.to_ascii_lowercase().contains("ecid"));
    }

    #[test]
    fn witness_json_excludes_hwid_text() {
        let json = acceptance_witness_json().unwrap();
        assert!(!json.to_ascii_lowercase().contains("hwid"));
    }

    #[test]
    fn witness_json_excludes_board_id_text() {
        let json = acceptance_witness_json().unwrap();
        assert!(!json.to_ascii_lowercase().contains("board_id"));
        assert!(!json.to_ascii_lowercase().contains("board-id"));
    }

    #[test]
    fn witness_json_excludes_ioplatform_text() {
        let json = acceptance_witness_json().unwrap();
        assert!(!json.to_ascii_lowercase().contains("ioplatform"));
    }

    #[test]
    fn witness_json_excludes_imei_text() {
        let json = acceptance_witness_json().unwrap();
        assert!(!json.to_ascii_lowercase().contains("imei"));
    }

    #[test]
    fn witness_json_excludes_meid_text() {
        let json = acceptance_witness_json().unwrap();
        assert!(!json.to_ascii_lowercase().contains("meid"));
    }

    #[test]
    fn witness_json_excludes_udid_text() {
        let json = acceptance_witness_json().unwrap();
        assert!(!json.to_ascii_lowercase().contains("udid"));
    }

    #[test]
    fn witness_json_excludes_idfa_and_idfv_text() {
        let json = acceptance_witness_json().unwrap();
        let lower = json.to_ascii_lowercase();
        assert!(!lower.contains("idfa"));
        assert!(!lower.contains("idfv"));
    }

    #[test]
    fn witness_json_excludes_host_id_text() {
        let json = acceptance_witness_json().unwrap();
        let lower = json.to_ascii_lowercase();
        assert!(!lower.contains("host_id"));
        assert!(!lower.contains("hostid"));
    }

    #[test]
    fn witness_json_excludes_apple_chip_id_text() {
        let json = acceptance_witness_json().unwrap();
        let lower = json.to_ascii_lowercase();
        assert!(!lower.contains("chip_id"));
        assert!(!lower.contains("chipid"));
        assert!(!lower.contains("apchipid"));
    }

    #[test]
    fn witness_json_excludes_apple_nonce_text() {
        let json = acceptance_witness_json().unwrap();
        let lower = json.to_ascii_lowercase();
        assert!(!lower.contains("apnonce"));
        assert!(!lower.contains("sepnonce"));
    }

    #[test]
    fn witness_json_excludes_provisioning_identifier_text() {
        let json = acceptance_witness_json().unwrap();
        let lower = json.to_ascii_lowercase();
        assert!(!lower.contains("provisioning"));
        assert!(!lower.contains("dep_enrollment"));
        assert!(!lower.contains("dep-enrollment"));
    }

    #[test]
    fn witness_json_excludes_ethernet_mac_address_pattern() {
        let json = acceptance_witness_json().unwrap();
        let lower = json.to_ascii_lowercase();
        let bytes = lower.as_bytes();
        for window in bytes.windows(17) {
            let is_hex_pair = |slice: &[u8]| {
                slice.len() == 2 && slice[0].is_ascii_hexdigit() && slice[1].is_ascii_hexdigit()
            };
            let candidate = is_hex_pair(&window[0..2])
                && window[2] == b':'
                && is_hex_pair(&window[3..5])
                && window[5] == b':'
                && is_hex_pair(&window[6..8])
                && window[8] == b':'
                && is_hex_pair(&window[9..11])
                && window[11] == b':'
                && is_hex_pair(&window[12..14])
                && window[14] == b':'
                && is_hex_pair(&window[15..17]);
            assert!(
                !candidate,
                "witness json contains ethernet MAC-shaped substring {:?}",
                std::str::from_utf8(window).unwrap_or("<non-utf8>")
            );
        }
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
            "31785206461ee0c47016ab91bac98ac05dc099108485633ba363abefba5210e8"
        );
        assert_eq!(
            witness.adversarial_reference_fingerprint,
            adversarial_reference_fingerprint()
        );
        assert_eq!(
            witness.adversarial_reference_fingerprint,
            "e15b0a03b4ee8ea906bcdde227f3bcc08093768865fa0f8d68d9807ca3421aaa"
        );
        assert_eq!(witness.adversarial_reference_stats.finite_count, 13);
        assert_eq!(witness.adversarial_reference_stats.rejected_count, 13);
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
        assert_eq!(error.pass_mismatch_pair(), Some((false, true)));
    }

    #[test]
    fn replay_rejects_pass_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["pass"] = serde_json::Value::String("true".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("pass type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("pass"));
    }

    #[test]
    fn replay_rejects_missing_pass_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value
            .as_object_mut()
            .expect("witness object")
            .remove("pass");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("missing pass must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert_eq!(error.invalid_json_message(), Some("missing field pass"));
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
    fn replay_rejects_shader_entrypoint_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["shader_entrypoint"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("shader entrypoint type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for shader_entrypoint, expected string")
        );
    }

    #[test]
    fn replay_rejects_shader_fingerprint_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        let actual = witness.shader_fingerprint.clone();
        let expected = "0".repeat(64);
        witness.shader_fingerprint = expected.clone();
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("shader drift must fail replay");
        assert_eq!(
            error.shader_mismatch(),
            Some((expected.as_str(), actual.as_str()))
        );
    }

    #[test]
    fn replay_rejects_shader_fingerprint_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["shader_fingerprint"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("shader fingerprint type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for shader_fingerprint, expected string")
        );
    }

    #[test]
    fn replay_rejects_hardware_pin_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.hardware.chip = "Apple M2 Max".to_string();
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("hardware drift must fail replay");
        let (submitted, regenerated) = error
            .hardware_mismatch_pair()
            .expect("hardware mismatch details");
        assert_eq!(submitted.chip, "Apple M2 Max");
        assert_eq!(regenerated.chip, "Apple M2 Pro");
    }

    #[test]
    fn replay_rejects_hardware_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("hardware type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for hardware, expected object")
        );
    }

    #[test]
    fn replay_rejects_hardware_model_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["model"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("hardware model type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for hardware.model, expected string")
        );
    }

    #[test]
    fn replay_rejects_hardware_model_identifier_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["model_identifier"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("hardware model identifier type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for hardware.model_identifier, expected string")
        );
    }

    #[test]
    fn replay_rejects_hardware_chip_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["chip"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("hardware chip type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for hardware.chip, expected string")
        );
    }

    #[test]
    fn replay_rejects_hardware_cpu_cores_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["cpu_cores"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("hardware cpu cores type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for hardware.cpu_cores, expected unsigned integer")
        );
    }

    #[test]
    fn replay_rejects_hardware_cpu_cores_json_u8_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["cpu_cores"] =
            serde_json::Value::Number(serde_json::Number::from(u64::from(u8::MAX) + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("hardware cpu cores overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("number out of range for hardware.cpu_cores, expected u8")
        );
    }

    #[test]
    fn replay_rejects_hardware_cpu_cores_json_raw_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["cpu_cores"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"cpu_cores\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"cpu_cores\":1e999999", 1);
        let error =
            replay_witness_json(&json).expect_err("hardware cpu cores overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("number out of range for hardware.cpu_cores, expected u8")
        );
    }

    #[test]
    fn replay_rejects_hardware_gpu_cores_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["gpu_cores"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("hardware gpu cores type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for hardware.gpu_cores, expected unsigned integer")
        );
    }

    #[test]
    fn replay_rejects_hardware_memory_gb_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["memory_gb"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("hardware memory gb type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for hardware.memory_gb, expected unsigned integer")
        );
    }

    #[test]
    fn replay_rejects_hardware_memory_gb_json_u16_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["memory_gb"] =
            serde_json::Value::Number(serde_json::Number::from(u64::from(u16::MAX) + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("hardware memory gb overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("number out of range for hardware.memory_gb, expected u16")
        );
    }

    #[test]
    fn replay_rejects_hardware_uma_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["uma"] = serde_json::Value::String("true".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("hardware uma type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for hardware.uma, expected boolean")
        );
    }

    #[test]
    fn replay_rejects_hardware_memory_bandwidth_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["memory_bandwidth_gb_s"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("hardware memory bandwidth type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for hardware.memory_bandwidth_gb_s, expected unsigned integer")
        );
    }

    #[test]
    fn replay_rejects_hardware_memory_bandwidth_json_u16_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["memory_bandwidth_gb_s"] =
            serde_json::Value::Number(serde_json::Number::from(u64::from(u16::MAX) + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("hardware memory bandwidth overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("number out of range for hardware.memory_bandwidth_gb_s, expected u16")
        );
    }

    #[test]
    fn replay_rejects_hardware_source_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["source"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("hardware source type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for hardware.source, expected string")
        );
    }

    #[test]
    fn replay_rejects_hardware_source_with_identifier_text() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["source"] =
            serde_json::Value::String("serial number and UUID redacted".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("hardware identifier text must fail replay before pin comparison");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::ForbiddenHardwareIdentifier)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("forbidden hardware identifier token in hardware.source")
        );
    }

    #[test]
    fn replay_rejects_hardware_source_with_mac_address_shape() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["source"] =
            serde_json::Value::String("capture host 01:23:45:ab:cd:ef redacted".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("hardware MAC-shaped text must fail replay before pin comparison");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::ForbiddenHardwareIdentifier)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("forbidden hardware identifier token in hardware.source")
        );
    }

    #[test]
    fn replay_rejects_unknown_hardware_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["serial_number"] = serde_json::Value::String("redacted".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("unknown hardware field must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("unknown field hardware.serial_number")
        );
    }

    #[test]
    fn replay_rejects_unknown_hardware_json_field_before_raw_overflow() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["hardware"]["serial_number"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"serial_number\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"serial_number\":1e999999", 1);
        let error =
            replay_witness_json(&json).expect_err("unknown hardware field must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("unknown field hardware.serial_number")
        );
    }

    #[test]
    fn replay_rejects_budget_target_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        let regenerated_seconds = witness.budget_target_seconds;
        witness.budget_target_seconds = regenerated_seconds + 1;
        let submitted_seconds = witness.budget_target_seconds;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("budget drift must fail replay");
        assert_eq!(
            error.budget_mismatch_kind(),
            Some(FulpBudgetMismatchKind::TargetSeconds)
        );
        assert_eq!(
            error.budget_target_seconds_mismatch(),
            Some((submitted_seconds, regenerated_seconds))
        );
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
    fn falsifier_doc_records_wall_clock_budget_ceiling() {
        let doc_path = format!(
            "{}/../docs/falsifiers/F_ULP_ORACLE_2026_05_18.md",
            env!("CARGO_MANIFEST_DIR")
        );
        let doc = std::fs::read_to_string(doc_path).expect("f-ulp falsifier doc");
        assert!(doc.contains("budget_target_seconds = 90"));
        assert!(doc.contains("budget_target_millis = 90,000"));
        assert!(doc.contains("observed_wall_clock_millis <= budget_target_millis"));
    }

    #[test]
    fn replay_rejects_budget_target_millis_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        let regenerated_millis = witness.budget_target_millis;
        witness.budget_target_millis += 1;
        let submitted_millis = witness.budget_target_millis;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("budget millis drift must fail replay");
        assert_eq!(
            error.budget_mismatch_kind(),
            Some(FulpBudgetMismatchKind::TargetMillis)
        );
        assert_eq!(
            error.budget_target_millis_mismatch(),
            Some((submitted_millis, regenerated_millis))
        );
    }

    #[test]
    fn replay_rejects_budget_target_millis_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["budget_target_millis"] = serde_json::Value::String("90000".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("budget target millis type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("budget_target_millis"));
    }

    #[test]
    fn replay_rejects_budget_target_millis_json_overflow_with_path() {
        let json = acceptance_witness_json().unwrap();
        let needle = "\"budget_target_millis\": 90000";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"budget_target_millis\": 1e999999", 1);
        let error =
            replay_witness_json(&json).expect_err("budget target millis overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("budget_target_millis"));
    }

    #[test]
    fn replay_rejects_witness_with_empty_object_root() {
        let json = "{}";
        let error = replay_witness_json(json).expect_err("empty object root must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
    }

    #[test]
    fn replay_rejects_witness_after_compact_reserialization_with_unknown_key() {
        let original = acceptance_witness_json().expect("acceptance witness json");
        let mut value: serde_json::Value =
            serde_json::from_str(&original).expect("witness json value");
        let object = value
            .as_object_mut()
            .expect("witness json root must be object");
        object.insert(
            "unrecognized_top_level".to_string(),
            serde_json::Value::Number(serde_json::Number::from(1u64)),
        );
        let json = serde_json::to_string(&value).expect("compact witness json");
        let error = replay_witness_json(&json)
            .expect_err("witness with injected top-level key must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
    }

    #[test]
    fn replay_rejects_compact_reserialized_witness_with_unknown_nested_key() {
        let original = acceptance_witness_json().expect("acceptance witness json");
        let mut value: serde_json::Value =
            serde_json::from_str(&original).expect("witness json value");
        let hardware = value["hardware"]
            .as_object_mut()
            .expect("hardware json must be object");
        hardware.insert(
            "unrecognized_nested".to_string(),
            serde_json::Value::String("repacked".to_string()),
        );
        let json = serde_json::to_string(&value).expect("compact witness json");
        let error = replay_witness_json(&json)
            .expect_err("compact witness with injected nested key must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("unknown field hardware.unrecognized_nested")
        );
    }

    #[test]
    fn replay_accepts_witness_after_compact_reserialization() {
        let original = acceptance_witness_json().expect("acceptance witness json");
        let value: serde_json::Value = serde_json::from_str(&original).expect("witness json value");
        let compact = serde_json::to_string(&value).expect("compact witness json");
        assert_ne!(original, compact);
        let parsed_original = replay_witness_json(&original).expect("original replay");
        let parsed_compact = replay_witness_json(&compact).expect("compact replay");
        assert_eq!(parsed_original, parsed_compact);
    }

    #[test]
    fn replay_accepts_witness_with_leading_whitespace() {
        let original = acceptance_witness_json().expect("acceptance witness json");
        let padded = format!("\n\n  \t{}", original);
        let parsed_original = replay_witness_json(&original).expect("original replay");
        let parsed_padded = replay_witness_json(&padded).expect("padded replay");
        assert_eq!(parsed_original, parsed_padded);
    }

    #[test]
    fn replay_accepts_witness_with_trailing_whitespace() {
        let original = acceptance_witness_json().expect("acceptance witness json");
        let padded = format!("{}\n\n  \t\n", original);
        let parsed_original = replay_witness_json(&original).expect("original replay");
        let parsed_padded = replay_witness_json(&padded).expect("padded replay");
        assert_eq!(parsed_original, parsed_padded);
    }

    #[test]
    fn replay_accepts_witness_after_pretty_print_reformat() {
        let original = acceptance_witness_json().expect("acceptance witness json");
        let value: serde_json::Value = serde_json::from_str(&original).expect("witness json value");
        let pretty = serde_json::to_string_pretty(&value).expect("pretty witness json");
        assert_ne!(original, pretty);
        let parsed_original = replay_witness_json(&original).expect("original replay");
        let parsed_pretty = replay_witness_json(&pretty).expect("pretty replay");
        assert_eq!(parsed_original, parsed_pretty);
    }

    #[test]
    fn replay_round_trips_acceptance_witness_byte_equal_after_two_serializations() {
        let original = acceptance_witness_json().expect("acceptance witness json");
        let parsed = replay_witness_json(&original).expect("acceptance witness replay");
        let first = serde_json::to_string(&parsed).expect("first serialization");
        let reparsed = replay_witness_json(&first).expect("first reparse");
        let second = serde_json::to_string(&reparsed).expect("second serialization");
        assert_eq!(first, second);
    }

    #[test]
    fn replay_round_trips_acceptance_witness_serialization() {
        let original = acceptance_witness_json().expect("acceptance witness json");
        let parsed = replay_witness_json(&original).expect("acceptance witness replay");
        let reserialized = serde_json::to_string(&parsed).expect("reserialize");
        let reparsed = replay_witness_json(&reserialized).expect("reparse");
        assert_eq!(parsed, reparsed);
    }

    #[test]
    fn replay_accepts_observed_wall_clock_zero() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.observed_wall_clock_millis = 0;
        let json = serde_json::to_string(&witness).unwrap();
        let replayed =
            replay_witness_json(&json).expect("witness with zero observed wall clock must replay");
        assert_eq!(replayed.observed_wall_clock_millis, 0);
    }

    #[test]
    fn replay_accepts_observed_wall_clock_one_millisecond_under_budget() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        let target_millis = u64::from(witness.budget_target_seconds) * 1_000;
        let under_budget = target_millis - 1;
        witness.observed_wall_clock_millis = under_budget;
        let json = serde_json::to_string(&witness).unwrap();
        let replayed =
            replay_witness_json(&json).expect("witness one millisecond under budget must replay");
        assert_eq!(replayed.observed_wall_clock_millis, under_budget);
    }

    #[test]
    fn replay_rejects_observed_wall_clock_one_millisecond_over_budget() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        let target_millis = u64::from(witness.budget_target_seconds) * 1_000;
        witness.observed_wall_clock_millis = target_millis + 1;
        let observed_millis = witness.observed_wall_clock_millis;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("witness one millisecond over budget must fail replay");
        assert_eq!(
            error.budget_mismatch_kind(),
            Some(FulpBudgetMismatchKind::ObservedWallClock)
        );
        assert_eq!(
            error.observed_wall_clock_budget_mismatch(),
            Some((target_millis, observed_millis))
        );
    }

    #[test]
    fn replay_accepts_observed_wall_clock_exactly_at_budget() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        let target_millis = u64::from(witness.budget_target_seconds) * 1_000;
        witness.observed_wall_clock_millis = target_millis;
        let json = serde_json::to_string(&witness).unwrap();
        let replayed = replay_witness_json(&json).expect("at-budget witness must replay");
        assert_eq!(replayed.observed_wall_clock_millis, target_millis);
    }

    #[test]
    fn replay_rejects_observed_wall_clock_over_budget() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        let target_millis = u64::from(witness.budget_target_seconds) * 1_000;
        witness.observed_wall_clock_millis = target_millis + 1;
        let observed_millis = witness.observed_wall_clock_millis;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("over-budget witness must fail replay");
        assert_eq!(
            error.budget_mismatch_kind(),
            Some(FulpBudgetMismatchKind::ObservedWallClock)
        );
        assert_eq!(
            error.observed_wall_clock_budget_mismatch(),
            Some((target_millis, observed_millis))
        );
    }

    #[test]
    fn replay_rejects_observed_wall_clock_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["observed_wall_clock_millis"] = serde_json::Value::String("1".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("observed wall clock type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("observed_wall_clock_millis"));
    }

    #[test]
    fn replay_rejects_observed_wall_clock_json_overflow_with_path() {
        let json = acceptance_witness_json().unwrap();
        let observed = serde_json::from_str::<serde_json::Value>(&json).expect("witness json")
            ["observed_wall_clock_millis"]
            .as_u64()
            .expect("observed wall clock millis");
        let needle = format!("\"observed_wall_clock_millis\": {observed}");
        assert_eq!(json.matches(&needle).count(), 1);
        let json = json.replacen(&needle, "\"observed_wall_clock_millis\": 1e999999", 1);
        let error =
            replay_witness_json(&json).expect_err("observed wall clock overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("observed_wall_clock_millis"));
    }

    #[test]
    fn replay_rejects_ulp_tolerance_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.config.ulp_tolerance = 4;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("tolerance drift must fail replay");
        assert_eq!(
            error.config_mismatch_kind(),
            Some(FulpConfigMismatchKind::UlpTolerance)
        );
    }

    #[test]
    fn replay_rejects_config_ulp_tolerance_json_raw_overflow_with_path() {
        let json = acceptance_witness_json().unwrap();
        let tolerance = serde_json::from_str::<serde_json::Value>(&json).expect("witness json")
            ["config"]["ulp_tolerance"]
            .as_u64()
            .expect("ulp tolerance");
        let needle = format!("\"ulp_tolerance\": {tolerance}");
        assert_eq!(json.matches(&needle).count(), 1);
        let json = json.replacen(&needle, "\"ulp_tolerance\": 1e999999", 1);
        let error =
            replay_witness_json(&json).expect_err("ulp tolerance raw overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("config.ulp_tolerance"));
    }

    #[test]
    fn replay_rejects_config_ulp_tolerance_json_u32_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["config"]["ulp_tolerance"] =
            serde_json::Value::Number(serde_json::Number::from(u64::from(u32::MAX) + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("ulp tolerance u32 overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("config.ulp_tolerance"));
    }

    #[test]
    fn replay_rejects_missing_config_ulp_tolerance_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["config"]
            .as_object_mut()
            .expect("config object")
            .remove("ulp_tolerance");
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("missing config tolerance must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("missing field config.ulp_tolerance")
        );
    }

    #[test]
    fn replay_rejects_config_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["config"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("config type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for config, expected object")
        );
    }

    #[test]
    fn replay_rejects_unknown_config_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["config"]["corrupted_extra_field"] = serde_json::Value::Bool(true);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("unknown config field must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("unknown field config.corrupted_extra_field")
        );
    }

    #[test]
    fn replay_rejects_missing_config_log_sampled_points_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["config"]
            .as_object_mut()
            .expect("config object")
            .remove("log_sampled_points");
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("missing log sampled points must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("missing field config.log_sampled_points")
        );
    }

    #[test]
    fn replay_rejects_config_log_sampled_points_json_raw_overflow_with_path() {
        let json = acceptance_witness_json().unwrap();
        let log_sampled_points = serde_json::from_str::<serde_json::Value>(&json)
            .expect("witness json")["config"]["log_sampled_points"]
            .as_u64()
            .expect("log sampled points");
        let needle = format!("\"log_sampled_points\": {log_sampled_points}");
        assert_eq!(json.matches(&needle).count(), 1);
        let json = json.replacen(&needle, "\"log_sampled_points\": 1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("log sampled points raw overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("config.log_sampled_points"));
    }

    #[test]
    fn replay_rejects_missing_config_stress_points_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["config"]
            .as_object_mut()
            .expect("config object")
            .remove("stress_points");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("missing stress points must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("missing field config.stress_points")
        );
    }

    #[test]
    fn replay_rejects_config_stress_points_json_raw_overflow_with_path() {
        let json = acceptance_witness_json().unwrap();
        let stress_points = serde_json::from_str::<serde_json::Value>(&json).expect("witness json")
            ["config"]["stress_points"]
            .as_u64()
            .expect("stress points");
        let needle = format!("\"stress_points\": {stress_points}");
        assert_eq!(json.matches(&needle).count(), 1);
        let json = json.replacen(&needle, "\"stress_points\": 1e999999", 1);
        let error =
            replay_witness_json(&json).expect_err("stress points raw overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("config.stress_points"));
    }

    #[test]
    fn replay_rejects_point_count_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.point_count += 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("point count drift must fail replay");
        assert_eq!(
            error.count_mismatch_kind(),
            Some(FulpCountMismatchKind::PointCount)
        );
    }

    #[test]
    fn replay_rejects_point_count_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["point_count"] = serde_json::Value::String("bad-count".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("point count type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("point_count"));
    }

    #[test]
    fn replay_rejects_point_count_json_overflow_with_path() {
        let json = acceptance_witness_json().unwrap();
        let point_count = serde_json::from_str::<serde_json::Value>(&json).expect("witness json")
            ["point_count"]
            .as_u64()
            .expect("point count");
        let needle = format!("\"point_count\": {point_count}");
        assert_eq!(json.matches(&needle).count(), 1);
        let json = json.replacen(&needle, "\"point_count\": 1e999999", 1);
        let error = replay_witness_json(&json).expect_err("point count overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("point_count"));
    }

    #[test]
    fn replay_rejects_evaluation_count_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.operation_evaluations += 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("count drift must fail replay");
        assert_eq!(
            error.count_mismatch_kind(),
            Some(FulpCountMismatchKind::OperationEvaluations)
        );
    }

    #[test]
    fn replay_rejects_operation_evaluations_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["operation_evaluations"] = serde_json::Value::String("bad-count".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("operation evaluations type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("operation_evaluations"));
    }

    #[test]
    fn replay_rejects_operation_evaluations_json_overflow_with_path() {
        let json = acceptance_witness_json().unwrap();
        let operation_evaluations = serde_json::from_str::<serde_json::Value>(&json)
            .expect("witness json")["operation_evaluations"]
            .as_u64()
            .expect("operation evaluations");
        let needle = format!("\"operation_evaluations\": {operation_evaluations}");
        assert_eq!(json.matches(&needle).count(), 1);
        let json = json.replacen(&needle, "\"operation_evaluations\": 1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("operation evaluations overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("operation_evaluations"));
    }

    #[test]
    fn replay_rejects_operation_catalog_fingerprint_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.operation_catalog_fingerprint = "0".repeat(64);
        let json = serde_json::to_string(&witness).unwrap();
        let error =
            replay_witness_json(&json).expect_err("operation catalog drift must fail replay");
        let (kind, submitted, regenerated) = error
            .fingerprint_mismatch()
            .expect("fingerprint mismatch details");
        assert_eq!(kind, &FingerprintKind::OperationCatalog);
        assert_eq!(submitted, "0".repeat(64));
        assert_eq!(regenerated, operation_catalog_fingerprint());
    }

    #[test]
    fn replay_rejects_operation_catalog_fingerprint_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["operation_catalog_fingerprint"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("operation catalog fingerprint type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for operation_catalog_fingerprint, expected string")
        );
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
    fn replay_rejects_axis_catalog_fingerprint_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["axis_catalog_fingerprint"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("axis catalog fingerprint type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for axis_catalog_fingerprint, expected string")
        );
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
    fn replay_rejects_grid_fingerprint_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["grid_fingerprint"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("grid fingerprint type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for grid_fingerprint, expected string")
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
    fn replay_rejects_adversarial_fixture_fingerprint_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["adversarial_fixture_fingerprint"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("adversarial fixture fingerprint type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for adversarial_fixture_fingerprint, expected string")
        );
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
    fn replay_rejects_adversarial_reference_fingerprint_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["adversarial_reference_fingerprint"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("adversarial reference fingerprint type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for adversarial_reference_fingerprint, expected string")
        );
    }

    #[test]
    fn replay_rejects_adversarial_fixture_count_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.adversarial_fixture_count += 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error =
            replay_witness_json(&json).expect_err("adversarial fixture count drift must fail");
        assert_eq!(
            error.count_mismatch_kind(),
            Some(FulpCountMismatchKind::AdversarialFixtureCount)
        );
    }

    #[test]
    fn replay_rejects_adversarial_fixture_count_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["adversarial_fixture_count"] = serde_json::Value::String("bad-count".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("adversarial fixture count type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("adversarial_fixture_count"));
    }

    #[test]
    fn replay_rejects_adversarial_fixture_count_json_overflow_with_path() {
        let json = acceptance_witness_json().unwrap();
        let fixture_count = serde_json::from_str::<serde_json::Value>(&json).expect("witness json")
            ["adversarial_fixture_count"]
            .as_u64()
            .expect("adversarial fixture count");
        let needle = format!("\"adversarial_fixture_count\": {fixture_count}");
        assert_eq!(json.matches(&needle).count(), 1);
        let json = json.replacen(&needle, "\"adversarial_fixture_count\": 1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("adversarial fixture count overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("adversarial_fixture_count"));
    }

    #[test]
    fn replay_rejects_adversarial_reference_stats_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.adversarial_reference_stats.finite_count -= 1;
        witness.adversarial_reference_stats.rejected_count += 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error =
            replay_witness_json(&json).expect_err("adversarial reference stats drift must fail");
        assert_eq!(
            error.count_mismatch_kind(),
            Some(FulpCountMismatchKind::AdversarialReferenceStats)
        );
    }

    #[test]
    fn replay_rejects_adversarial_reference_finite_count_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["adversarial_reference_stats"]["finite_count"] =
            serde_json::Value::String("bad-count".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("adversarial reference finite count type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("adversarial_reference_stats.finite_count"));
    }

    #[test]
    fn replay_rejects_adversarial_reference_finite_count_json_raw_overflow_with_path() {
        let json = acceptance_witness_json().unwrap();
        let needle = "\"finite_count\": 13";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"finite_count\": 1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("adversarial reference finite count raw overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some(
                "number out of range for adversarial_reference_stats.finite_count, expected unsigned integer"
            )
        );
    }

    #[test]
    fn replay_rejects_missing_adversarial_reference_finite_count_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["adversarial_reference_stats"]
            .as_object_mut()
            .expect("adversarial reference stats object")
            .remove("finite_count");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("missing adversarial reference finite count must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("missing field adversarial_reference_stats.finite_count")
        );
    }

    #[test]
    fn falsifier_doc_records_rejected_count_corruption_replay() {
        let doc_path = format!(
            "{}/../docs/falsifiers/F_ULP_ORACLE_2026_05_18.md",
            env!("CARGO_MANIFEST_DIR")
        );
        let doc = std::fs::read_to_string(doc_path).expect("f-ulp falsifier doc");
        assert!(doc.contains("missing `rejected_count`"));
        assert!(doc.contains("raw-overflow `rejected_count`"));
        assert!(doc.contains("adversarial_reference_stats.rejected_count"));
    }

    #[test]
    fn replay_rejects_missing_adversarial_reference_rejected_count_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["adversarial_reference_stats"]
            .as_object_mut()
            .expect("adversarial reference stats object")
            .remove("rejected_count");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("missing adversarial reference rejected count must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("missing field adversarial_reference_stats.rejected_count")
        );
    }

    #[test]
    fn replay_rejects_adversarial_reference_rejected_count_json_raw_overflow_with_path() {
        let json = acceptance_witness_json().unwrap();
        let needle = "\"rejected_count\": 13";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"rejected_count\": 1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("adversarial reference rejected count raw overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some(
                "number out of range for adversarial_reference_stats.rejected_count, expected unsigned integer"
            )
        );
    }

    #[test]
    fn replay_rejects_unknown_adversarial_reference_stats_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["adversarial_reference_stats"]["corrupted_extra_field"] =
            serde_json::Value::Bool(true);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("unknown adversarial reference stats field must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("unknown field adversarial_reference_stats.corrupted_extra_field")
        );
    }

    #[test]
    fn replay_rejects_unknown_adversarial_reference_stats_json_field_before_raw_overflow() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["adversarial_reference_stats"]["corrupted_extra_field"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"corrupted_extra_field\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"corrupted_extra_field\":1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("unknown adversarial reference stats field must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("unknown field adversarial_reference_stats.corrupted_extra_field")
        );
    }

    #[test]
    fn replay_rejects_adversarial_reference_finite_count_above_fixture_count_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        let fixture_count = value["adversarial_fixture_count"]
            .as_u64()
            .expect("adversarial fixture count");
        value["adversarial_reference_stats"]["finite_count"] =
            serde_json::Value::Number(serde_json::Number::from(fixture_count + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("adversarial reference finite count above fixture count must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("adversarial_reference_stats.finite_count"));
    }

    #[test]
    fn replay_rejects_adversarial_reference_rejected_count_above_fixture_count_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        let fixture_count = value["adversarial_fixture_count"]
            .as_u64()
            .expect("adversarial fixture count");
        value["adversarial_reference_stats"]["rejected_count"] =
            serde_json::Value::Number(serde_json::Number::from(fixture_count + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err(
            "adversarial reference rejected count above fixture count must fail replay",
        );
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("adversarial_reference_stats.rejected_count"));
    }

    #[test]
    fn replay_rejects_adversarial_reference_count_sum_above_fixture_count_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        let fixture_count = value["adversarial_fixture_count"]
            .as_u64()
            .expect("adversarial fixture count");
        value["adversarial_reference_stats"]["finite_count"] =
            serde_json::Value::Number(serde_json::Number::from(fixture_count));
        value["adversarial_reference_stats"]["rejected_count"] =
            serde_json::Value::Number(serde_json::Number::from(1_u64));
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("adversarial reference count sum above fixture count must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("adversarial_reference_stats"));
    }

    #[test]
    fn replay_rejects_schema_version_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.schema_version = 2;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("schema drift must fail replay");
        assert_eq!(
            error.schema_mismatch_pair(),
            Some((2, FULP_WITNESS_SCHEMA_VERSION))
        );
    }

    #[test]
    fn replay_rejects_schema_version_json_u32_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["schema_version"] =
            serde_json::Value::Number(serde_json::Number::from(u64::from(u32::MAX) + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("schema version u32 overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("schema_version"));
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
        assert_eq!(
            error.mission_mismatch_pair(),
            Some(("not T12", "F-ULP-Oracle T12"))
        );
    }

    #[test]
    fn replay_rejects_mission_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["mission"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("mission type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for mission, expected string")
        );
    }

    #[test]
    fn replay_rejects_missing_mission_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value
            .as_object_mut()
            .expect("witness object")
            .remove("mission");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("missing mission must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert_eq!(error.invalid_json_message(), Some("missing field mission"));
    }

    #[test]
    fn replay_rejects_unknown_evaluator_variant() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.evaluator_variant = "metal_capture_v1".to_string();
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("unknown evaluator must fail replay");
        assert_eq!(error.unsupported_evaluator(), Some("metal_capture_v1"));
        assert_eq!(
            error.unsupported_evaluator_kind(),
            Some(FulpUnsupportedEvaluatorKind::Unknown)
        );
    }

    #[test]
    fn replay_rejects_evaluator_variant_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["evaluator_variant"] = serde_json::Value::Bool(false);
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("evaluator variant type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("invalid type for evaluator_variant, expected string")
        );
    }

    #[test]
    fn replay_rejects_reference_evaluator_as_candidate_witness() {
        let witness = run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &ReferenceRoundedEvaluator)
            .expect("reference witness");
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("reference evaluator must not replay as a candidate witness");
        assert_eq!(
            error.unsupported_evaluator_kind(),
            Some(FulpUnsupportedEvaluatorKind::ReferenceRounded)
        );
    }

    #[test]
    fn replay_rejects_fixture_config_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        witness.config.log_sampled_points -= 1;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("fixture config drift must fail replay");
        assert_eq!(
            error.config_mismatch_kind(),
            Some(FulpConfigMismatchKind::FixtureGrid)
        );
    }

    #[test]
    fn replay_rejects_unknown_top_level_json_field() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["corrupted_extra_field"] = serde_json::Value::Bool(true);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("unknown field must fail closed");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
    }

    #[test]
    fn replay_rejects_unknown_top_level_json_field_before_raw_overflow() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["corrupted_extra_field"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"corrupted_extra_field\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"corrupted_extra_field\":1e999999", 1);
        let error = replay_witness_json(&json).expect_err("unknown field must fail closed");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("unknown field corrupted_extra_field")
        );
    }

    #[test]
    fn replay_rejects_malformed_witness_json() {
        let error = replay_witness_json("{]").expect_err("malformed JSON must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::Malformed)
        );
    }

    #[test]
    fn replay_rejects_truncated_witness_json() {
        let error = replay_witness_json("{\"schema_version\": 12")
            .expect_err("truncated JSON must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TruncatedInput)
        );
    }

    #[test]
    fn replay_rejects_empty_witness_json() {
        let error = replay_witness_json("").expect_err("empty JSON must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::EmptyInput)
        );
    }

    #[test]
    fn replay_rejects_budget_target_seconds_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["budget_target_seconds"] = serde_json::Value::String("90".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("budget target seconds type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("budget_target_seconds"));
    }

    #[test]
    fn replay_rejects_budget_target_seconds_json_u32_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["budget_target_seconds"] =
            serde_json::Value::Number(serde_json::Number::from(u64::from(u32::MAX) + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("budget target seconds overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("budget_target_seconds"));
    }

    #[test]
    fn replay_rejects_budget_target_seconds_json_raw_overflow_with_path() {
        let json = acceptance_witness_json().unwrap();
        let seconds = serde_json::from_str::<serde_json::Value>(&json).expect("witness json")
            ["budget_target_seconds"]
            .as_u64()
            .expect("budget target seconds");
        let needle = format!("\"budget_target_seconds\": {seconds}");
        assert_eq!(json.matches(&needle).count(), 1);
        let json = json.replacen(&needle, "\"budget_target_seconds\": 1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("budget target seconds raw overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("budget_target_seconds"));
    }

    #[test]
    fn replay_rejects_stats_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"] = serde_json::Value::Null;
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("stats type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats"));
    }

    #[test]
    fn replay_rejects_operation_stats_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0] = serde_json::Value::Null;
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("operation stats type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0]"));
    }

    #[test]
    fn replay_rejects_unknown_operation_stats_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["corrupted_extra_field"] = serde_json::Value::Bool(true);
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("unknown operation stats field must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("unknown field stats[0].corrupted_extra_field")
        );
    }

    #[test]
    fn replay_rejects_unknown_operation_stat_field_before_raw_overflow() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["corrupted_extra_field"] = serde_json::Value::Bool(true);
        value["stats"][0]["max_ulp"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"max_ulp\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"max_ulp\":1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("unknown operation stat field must fail before raw overflow");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("unknown field stats[0].corrupted_extra_field")
        );
    }

    #[test]
    fn replay_rejects_axis_stats_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"] = serde_json::Value::Null;
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("axis stats type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats"));
    }

    #[test]
    fn replay_rejects_axis_stats_entry_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0] = serde_json::Value::Null;
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("axis stats entry type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0]"));
    }

    #[test]
    fn replay_rejects_missing_axis_stats_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]
            .as_object_mut()
            .expect("operation stats object")
            .remove("axis_stats")
            .expect("axis stats field");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("missing axis stats must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats"));
    }

    #[test]
    fn replay_rejects_missing_axis_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]
            .as_object_mut()
            .expect("axis stats object")
            .remove("axis")
            .expect("axis field");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("missing axis must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].axis"));
    }

    #[test]
    fn replay_rejects_missing_axis_field_before_raw_overflow() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]
            .as_object_mut()
            .expect("axis stats object")
            .remove("axis")
            .expect("axis field");
        value["stats"][0]["axis_stats"][0]["max_ulp"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"max_ulp\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"max_ulp\":1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("missing axis field must fail before raw overflow");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].axis"));
    }

    #[test]
    fn replay_rejects_axis_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["axis"] = serde_json::Value::Null;
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("axis type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].axis"));
    }

    #[test]
    fn replay_rejects_axis_unknown_variant_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["axis"] =
            serde_json::Value::String("UnexpectedAxis".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("unknown axis must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::Malformed)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].axis"));
    }

    #[test]
    fn replay_rejects_missing_axis_evaluated_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]
            .as_object_mut()
            .expect("axis stats object")
            .remove("evaluated")
            .expect("axis evaluated field");
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("missing axis evaluated must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].evaluated"));
    }

    #[test]
    fn replay_rejects_axis_evaluated_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["evaluated"] =
            serde_json::Value::String("bad-count".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("axis evaluated type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].evaluated"));
    }

    #[test]
    fn replay_rejects_axis_evaluated_json_raw_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["evaluated"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"evaluated\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"evaluated\":1e999999", 1);
        let error =
            replay_witness_json(&json).expect_err("axis evaluated overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some(
                "number out of range for stats[0].axis_stats[0].evaluated, expected unsigned integer"
            )
        );
    }

    #[test]
    fn replay_rejects_axis_evaluated_above_operation_evaluations_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        let operation_evaluations = value["operation_evaluations"]
            .as_u64()
            .expect("operation evaluations");
        value["stats"][0]["axis_stats"][0]["evaluated"] =
            serde_json::Value::Number(serde_json::Number::from(operation_evaluations + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("axis evaluated above operation evaluations must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].evaluated"));
    }

    #[test]
    fn replay_rejects_missing_axis_max_ulp_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]
            .as_object_mut()
            .expect("axis stats object")
            .remove("max_ulp")
            .expect("axis max ulp field");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("missing axis max ulp must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].max_ulp"));
    }

    #[test]
    fn replay_rejects_axis_max_ulp_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["max_ulp"] =
            serde_json::Value::String("bad-ulp".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("axis max ulp type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].max_ulp"));
    }

    #[test]
    fn replay_rejects_axis_max_ulp_json_u32_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["max_ulp"] =
            serde_json::Value::Number(serde_json::Number::from(u64::from(u32::MAX) + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("axis max ulp overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].max_ulp"));
    }

    #[test]
    fn replay_rejects_axis_max_ulp_json_raw_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["max_ulp"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"max_ulp\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"max_ulp\":1e999999", 1);
        let error = replay_witness_json(&json).expect_err("axis max ulp overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("number out of range for stats[0].axis_stats[0].max_ulp, expected u32")
        );
    }

    #[test]
    fn replay_rejects_duplicate_axis_stat_field_before_numeric_payload() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["max_ulp"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"max_ulp\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"max_ulp\":123456789,\"max_ulp\":1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("duplicate axis stat field must fail before numeric payload");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::DuplicateField)
        );
    }

    #[test]
    fn replay_rejects_missing_axis_mean_ulp_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]
            .as_object_mut()
            .expect("axis stats object")
            .remove("mean_ulp")
            .expect("axis mean ulp field");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("missing axis mean ulp must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].mean_ulp"));
    }

    #[test]
    fn replay_rejects_axis_mean_ulp_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["mean_ulp"] =
            serde_json::Value::String("bad-ulp".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("axis mean ulp type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].mean_ulp"));
    }

    #[test]
    fn replay_rejects_axis_mean_ulp_json_u32_domain_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["mean_ulp"] =
            serde_json::Value::Number(serde_json::Number::from(u64::from(u32::MAX) + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("axis mean ulp domain overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].mean_ulp"));
    }

    #[test]
    fn replay_rejects_missing_axis_worst_case_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]
            .as_object_mut()
            .expect("axis stats object")
            .remove("worst_case")
            .expect("axis worst case field");
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("missing axis worst case must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].worst_case"));
    }

    #[test]
    fn replay_rejects_non_object_axis_worst_case_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["worst_case"] =
            serde_json::Value::String("not an object".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("non-object axis worst case must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].worst_case"));
    }

    #[test]
    fn replay_rejects_missing_axis_worst_case_operation_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["worst_case"]
            .as_object_mut()
            .expect("axis worst case object")
            .remove("operation")
            .expect("worst case operation field");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("missing axis worst case operation must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats[0].worst_case.operation"));
    }

    #[test]
    fn replay_rejects_missing_operation_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]
            .as_object_mut()
            .expect("operation stats object")
            .remove("operation")
            .expect("operation field");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("missing operation must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].operation"));
    }

    #[test]
    fn replay_rejects_operation_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["operation"] = serde_json::Value::Null;
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("operation type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].operation"));
    }

    #[test]
    fn replay_rejects_operation_unknown_variant_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["operation"] = serde_json::Value::String("Sin".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("unknown operation must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::Malformed)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].operation"));
    }

    #[test]
    fn replay_rejects_missing_operation_evaluated_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]
            .as_object_mut()
            .expect("operation stats object")
            .remove("evaluated")
            .expect("operation evaluated field");
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("missing operation evaluated must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].evaluated"));
    }

    #[test]
    fn replay_rejects_operation_evaluated_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["evaluated"] = serde_json::Value::String("bad-count".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("operation evaluated type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].evaluated"));
    }

    #[test]
    fn replay_rejects_operation_evaluated_json_raw_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["evaluated"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"evaluated\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"evaluated\":1e999999", 1);
        let error =
            replay_witness_json(&json).expect_err("operation evaluated overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("number out of range for stats[0].evaluated, expected unsigned integer")
        );
    }

    #[test]
    fn replay_rejects_operation_evaluated_above_operation_evaluations_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        let operation_evaluations = value["operation_evaluations"]
            .as_u64()
            .expect("operation evaluations");
        value["stats"][0]["evaluated"] =
            serde_json::Value::Number(serde_json::Number::from(operation_evaluations + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("operation evaluated above operation evaluations must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].evaluated"));
    }

    #[test]
    fn replay_rejects_missing_operation_max_ulp_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]
            .as_object_mut()
            .expect("operation stats object")
            .remove("max_ulp")
            .expect("operation max ulp field");
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("missing operation max ulp must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].max_ulp"));
    }

    #[test]
    fn replay_rejects_operation_max_ulp_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["max_ulp"] = serde_json::Value::String("bad-ulp".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("operation max ulp type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].max_ulp"));
    }

    #[test]
    fn replay_rejects_operation_max_ulp_json_u32_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["max_ulp"] =
            serde_json::Value::Number(serde_json::Number::from(u64::from(u32::MAX) + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("operation max ulp overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].max_ulp"));
    }

    #[test]
    fn replay_rejects_operation_max_ulp_json_raw_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["max_ulp"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"max_ulp\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"max_ulp\":1e999999", 1);
        let error =
            replay_witness_json(&json).expect_err("operation max ulp overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("number out of range for stats[0].max_ulp, expected u32")
        );
    }

    #[test]
    fn replay_rejects_duplicate_operation_stat_field_before_numeric_payload() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["max_ulp"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"max_ulp\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"max_ulp\":123456789,\"max_ulp\":1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("duplicate operation stat field must fail before numeric payload");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::DuplicateField)
        );
    }

    #[test]
    fn replay_rejects_missing_operation_mean_ulp_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]
            .as_object_mut()
            .expect("operation stats object")
            .remove("mean_ulp")
            .expect("operation mean ulp field");
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("missing operation mean ulp must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].mean_ulp"));
    }

    #[test]
    fn replay_rejects_operation_mean_ulp_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["mean_ulp"] = serde_json::Value::String("bad-ulp".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("operation mean ulp type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].mean_ulp"));
    }

    #[test]
    fn replay_rejects_operation_mean_ulp_json_f64_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["mean_ulp"] = serde_json::Number::from_f64(123456789.125)
            .expect("finite sentinel")
            .into();
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"mean_ulp\":123456789.125";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"mean_ulp\":1e999999", 1);
        let error =
            replay_witness_json(&json).expect_err("operation mean ulp overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].mean_ulp"));
    }

    #[test]
    fn replay_rejects_operation_mean_ulp_json_u32_domain_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["mean_ulp"] =
            serde_json::Value::Number(serde_json::Number::from(u64::from(u32::MAX) + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("operation mean ulp domain overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].mean_ulp"));
    }

    #[test]
    fn replay_rejects_missing_operation_gate_tier_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]
            .as_object_mut()
            .expect("operation stats object")
            .remove("gate_tier")
            .expect("operation gate tier field");
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("missing operation gate tier must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].gate_tier"));
    }

    #[test]
    fn replay_rejects_missing_operation_gate_tier_before_raw_overflow() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]
            .as_object_mut()
            .expect("operation stats object")
            .remove("gate_tier")
            .expect("operation gate tier field");
        value["stats"][0]["max_ulp"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"max_ulp\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"max_ulp\":1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("missing operation gate tier must fail before raw overflow");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].gate_tier"));
    }

    #[test]
    fn replay_rejects_operation_gate_tier_json_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["gate_tier"] = serde_json::Value::Bool(true);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("operation gate tier type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].gate_tier"));
    }

    #[test]
    fn replay_rejects_operation_gate_tier_unknown_variant_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["gate_tier"] = serde_json::Value::String("UnexpectedGate".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("unknown operation gate tier must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::Malformed)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].gate_tier"));
    }

    #[test]
    fn replay_rejects_missing_operation_worst_case_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]
            .as_object_mut()
            .expect("operation stats object")
            .remove("worst_case")
            .expect("operation worst case field");
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("missing operation worst case must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case"));
    }

    #[test]
    fn replay_rejects_non_object_operation_worst_case_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"] = serde_json::Value::String("not an object".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("non-object operation worst case must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case"));
    }

    #[test]
    fn replay_rejects_unknown_operation_worst_case_json_field_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["corrupted_extra_field"] = serde_json::Value::Bool(true);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("unknown operation worst case field must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("unknown field stats[0].worst_case.corrupted_extra_field")
        );
    }

    #[test]
    fn replay_rejects_unknown_operation_worst_case_field_before_raw_overflow() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["corrupted_extra_field"] = serde_json::Value::Bool(true);
        value["stats"][0]["worst_case"]["point_index"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"point_index\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"point_index\":1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("unknown worst case field must fail before raw overflow");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("unknown field stats[0].worst_case.corrupted_extra_field")
        );
    }

    #[test]
    fn replay_rejects_missing_operation_worst_case_operation_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]
            .as_object_mut()
            .expect("operation worst case object")
            .remove("operation")
            .expect("worst case operation field");
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("missing worst case operation must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.operation"));
    }

    #[test]
    fn replay_rejects_missing_operation_worst_case_operation_before_raw_overflow() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]
            .as_object_mut()
            .expect("operation worst case object")
            .remove("operation")
            .expect("worst case operation field");
        value["stats"][0]["worst_case"]["point_index"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"point_index\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"point_index\":1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("missing worst case operation must fail before raw overflow");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.operation"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_operation_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["operation"] = serde_json::Value::Bool(true);
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("worst case operation type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.operation"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_operation_unknown_variant_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["operation"] =
            serde_json::Value::String("UnexpectedOperation".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("worst case operation unknown variant must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::Malformed)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.operation"));
    }

    #[test]
    fn replay_rejects_missing_operation_worst_case_point_index_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]
            .as_object_mut()
            .expect("operation worst case object")
            .remove("point_index")
            .expect("worst case point index field");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("missing worst case point index must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.point_index"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_point_index_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["point_index"] =
            serde_json::Value::String("not-an-index".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("worst case point index type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.point_index"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_point_index_outside_point_count_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        let point_count = value["point_count"].as_u64().expect("witness point count");
        value["stats"][0]["worst_case"]["point_index"] =
            serde_json::Value::Number(serde_json::Number::from(point_count));
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("worst case point index outside point count must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.point_index"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_point_index_json_raw_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["point_index"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"point_index\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"point_index\":1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("worst case point index overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("number out of range for stats[0].worst_case.point_index, expected unsigned integer")
        );
    }

    #[test]
    fn replay_rejects_duplicate_operation_worst_case_field_before_numeric_payload() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["point_index"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"point_index\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(
            needle,
            "\"point_index\":123456789,\"point_index\":1e999999",
            1,
        );
        let error = replay_witness_json(&json)
            .expect_err("duplicate worst case field must fail before numeric payload");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::DuplicateField)
        );
    }

    #[test]
    fn replay_rejects_missing_operation_worst_case_axis_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]
            .as_object_mut()
            .expect("operation worst case object")
            .remove("axis")
            .expect("worst case axis field");
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("missing worst case axis must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.axis"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_axis_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["axis"] = serde_json::Value::Bool(true);
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("worst case axis type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.axis"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_axis_unknown_variant_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["axis"] =
            serde_json::Value::String("UnexpectedAxis".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("worst case axis unknown variant must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::Malformed)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.axis"));
    }

    #[test]
    fn replay_rejects_missing_operation_worst_case_x_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]
            .as_object_mut()
            .expect("operation worst case object")
            .remove("x")
            .expect("worst case x field");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("missing worst case x must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.x"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_x_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["x"] =
            serde_json::Value::String("not-a-number".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("worst case x type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.x"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_x_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["x"] = serde_json::Number::from_f64(123456789.125)
            .expect("finite sentinel")
            .into();
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"x\":123456789.125";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"x\":1e999999", 1);
        let error = replay_witness_json(&json).expect_err("worst case x overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.x"));
    }

    #[test]
    fn replay_rejects_missing_operation_worst_case_y_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]
            .as_object_mut()
            .expect("operation worst case object")
            .remove("y")
            .expect("worst case y field");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("missing worst case y must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.y"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_y_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["y"] =
            serde_json::Value::String("not-a-number".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("worst case y type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.y"));
    }

    #[test]
    fn replay_rejects_missing_operation_worst_case_reference_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]
            .as_object_mut()
            .expect("operation worst case object")
            .remove("reference")
            .expect("worst case reference field");
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("missing worst case reference must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.reference"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_reference_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["reference"] =
            serde_json::Value::String("not-a-number".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("worst case reference type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.reference"));
    }

    #[test]
    fn replay_rejects_missing_operation_worst_case_reference_fp16_bits_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]
            .as_object_mut()
            .expect("operation worst case object")
            .remove("reference_fp16_bits")
            .expect("worst case reference fp16 bits field");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("missing worst case reference bits must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.reference_fp16_bits"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_reference_fp16_bits_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["reference_fp16_bits"] =
            serde_json::Value::String("0x3c00".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("worst case reference bits type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.reference_fp16_bits"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_reference_fp16_bits_u16_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["reference_fp16_bits"] =
            serde_json::Value::Number(serde_json::Number::from(u64::from(u16::MAX) + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("worst case reference bits overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.reference_fp16_bits"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_reference_fp16_bits_json_raw_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["reference_fp16_bits"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"reference_fp16_bits\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"reference_fp16_bits\":1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("worst case reference bits overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("number out of range for stats[0].worst_case.reference_fp16_bits, expected u16")
        );
    }

    #[test]
    fn replay_rejects_missing_operation_worst_case_candidate_fp16_bits_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]
            .as_object_mut()
            .expect("operation worst case object")
            .remove("candidate_fp16_bits")
            .expect("worst case candidate fp16 bits field");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("missing worst case candidate bits must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.candidate_fp16_bits"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_candidate_fp16_bits_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["candidate_fp16_bits"] =
            serde_json::Value::String("0x3c00".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("worst case candidate bits type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.candidate_fp16_bits"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_candidate_fp16_bits_u16_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["candidate_fp16_bits"] =
            serde_json::Value::Number(serde_json::Number::from(u64::from(u16::MAX) + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("worst case candidate bits overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.candidate_fp16_bits"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_candidate_fp16_bits_json_raw_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["candidate_fp16_bits"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"candidate_fp16_bits\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"candidate_fp16_bits\":1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("worst case candidate bits overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("number out of range for stats[0].worst_case.candidate_fp16_bits, expected u16")
        );
    }

    #[test]
    fn replay_rejects_missing_operation_worst_case_ulp_error_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]
            .as_object_mut()
            .expect("operation worst case object")
            .remove("ulp_error")
            .expect("worst case ulp error field");
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("missing worst case ulp error must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.ulp_error"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_ulp_error_type_drift_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["ulp_error"] = serde_json::Value::String("2".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json)
            .expect_err("worst case ulp error type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.ulp_error"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_ulp_error_u32_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["ulp_error"] =
            serde_json::Value::Number(serde_json::Number::from(u64::from(u32::MAX) + 1));
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("worst case ulp error overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].worst_case.ulp_error"));
    }

    #[test]
    fn replay_rejects_operation_worst_case_ulp_error_json_raw_overflow_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["worst_case"]["ulp_error"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"ulp_error\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"ulp_error\":1e999999", 1);
        let error =
            replay_witness_json(&json).expect_err("worst case ulp error overflow must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("number out of range for stats[0].worst_case.ulp_error, expected u32")
        );
    }

    #[test]
    fn replay_rejects_non_object_witness_json_root() {
        let error = replay_witness_json("[]").expect_err("non-object root must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::RootShape)
        );
    }

    #[test]
    fn replay_rejects_out_of_range_witness_json_number() {
        let original = acceptance_witness_json().unwrap();
        let json = original.replacen("\"schema_version\": 12", "\"schema_version\": 1e999999", 1);
        assert_ne!(json, original);
        let error = replay_witness_json(&json).expect_err("out-of-range number must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::NumberOutOfRange)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("schema_version"));
    }

    #[test]
    fn replay_rejects_trailing_witness_json() {
        let json = format!("{}\n{{}}", acceptance_witness_json().unwrap());
        let error = replay_witness_json(&json).expect_err("trailing JSON must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TrailingData)
        );
    }

    #[test]
    fn replay_rejects_missing_witness_json_field() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value
            .as_object_mut()
            .expect("witness object")
            .remove("schema_version");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("missing field must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::MissingField)
        );
    }

    #[test]
    fn replay_rejects_duplicate_witness_json_field() {
        let original = acceptance_witness_json().unwrap();
        let json = original.replacen(
            "\"schema_version\": 12",
            "\"schema_version\": 12,\n  \"schema_version\": 12",
            1,
        );
        assert_ne!(json, original);
        let error = replay_witness_json(&json).expect_err("duplicate field must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::DuplicateField)
        );
    }

    #[test]
    fn replay_rejects_duplicate_config_field_before_numeric_payload() {
        let original = acceptance_witness_json().unwrap();
        let log_sampled_points = serde_json::from_str::<serde_json::Value>(&original)
            .expect("witness json")["config"]["log_sampled_points"]
            .as_u64()
            .expect("log sampled points");
        let needle = format!("\"log_sampled_points\": {log_sampled_points}");
        let json = original.replacen(
            &needle,
            "\"log_sampled_points\": 4096,\n    \"log_sampled_points\": 18446744073709551616",
            1,
        );
        assert_ne!(json, original);
        let error = replay_witness_json(&json)
            .expect_err("duplicate field must fail before numeric payload");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::DuplicateField)
        );
    }

    #[test]
    fn replay_rejects_short_stats_array_json() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"]
            .as_array_mut()
            .expect("stats array")
            .pop()
            .expect("operation stats");
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("short stats array must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::InvalidLength)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats"));
    }

    #[test]
    fn replay_rejects_short_axis_stats_array_json_with_path() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"]
            .as_array_mut()
            .expect("axis stats array")
            .pop()
            .expect("axis stats entry");
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("short axis stats array must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::InvalidLength)
        );
        assert!(error
            .invalid_json_message()
            .expect("invalid json message")
            .contains("stats[0].axis_stats"));
    }

    #[test]
    fn replay_rejects_unknown_nested_axis_stats_json_field() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["corrupted_extra_field"] = serde_json::Value::Bool(true);
        let json = serde_json::to_string(&value).unwrap();
        let error =
            replay_witness_json(&json).expect_err("unknown axis stats field must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("unknown field stats[0].axis_stats[0].corrupted_extra_field")
        );
    }

    #[test]
    fn replay_rejects_unknown_axis_stat_field_before_raw_overflow() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["stats"][0]["axis_stats"][0]["corrupted_extra_field"] = serde_json::Value::Bool(true);
        value["stats"][0]["axis_stats"][0]["max_ulp"] =
            serde_json::Value::Number(serde_json::Number::from(123_456_789_u64));
        let json = serde_json::to_string(&value).unwrap();
        let needle = "\"max_ulp\":123456789";
        assert_eq!(json.matches(needle).count(), 1);
        let json = json.replacen(needle, "\"max_ulp\":1e999999", 1);
        let error = replay_witness_json(&json)
            .expect_err("unknown axis stat field must fail before raw overflow");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::UnknownField)
        );
        assert_eq!(
            error.invalid_json_message(),
            Some("unknown field stats[0].axis_stats[0].corrupted_extra_field")
        );
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
    fn replay_rejects_operation_max_ulp_jump() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        let replayed_max_ulp = witness.stats[0].max_ulp;
        witness.stats[0].max_ulp = replayed_max_ulp + 1;
        let witness_max_ulp = witness.stats[0].max_ulp;
        let json = serde_json::to_string(&witness).unwrap();
        let error =
            replay_witness_json(&json).expect_err("operation max ULP drift must fail replay");
        assert_eq!(
            error.stats_mismatch_kind(),
            Some(FulpStatsMismatchKind::OperationMaxUlp {
                operation: FulpOperation::Exp,
            })
        );
        assert_eq!(
            error.operation_max_ulp_mismatch(),
            Some((FulpOperation::Exp, witness_max_ulp, replayed_max_ulp))
        );
    }

    #[test]
    fn replay_rejects_operation_mean_ulp_jump() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        let replayed_mean_ulp = witness.stats[0].mean_ulp;
        witness.stats[0].mean_ulp = replayed_mean_ulp + 0.5;
        let witness_mean_ulp = witness.stats[0].mean_ulp;
        let json = serde_json::to_string(&witness).unwrap();
        let error =
            replay_witness_json(&json).expect_err("operation mean ULP drift must fail replay");
        assert_eq!(
            error.stats_mismatch_kind(),
            Some(FulpStatsMismatchKind::OperationMeanUlp {
                operation: FulpOperation::Exp,
            })
        );
        assert_eq!(
            error.operation_mean_ulp_mismatch(),
            Some((FulpOperation::Exp, witness_mean_ulp, replayed_mean_ulp))
        );
    }

    #[test]
    fn replay_rejects_per_axis_max_ulp_jump() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        let replayed_max_ulp = witness.stats[0].axis_stats[0].max_ulp;
        witness.stats[0].axis_stats[0].max_ulp = replayed_max_ulp + 1;
        let witness_max_ulp = witness.stats[0].axis_stats[0].max_ulp;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("axis max ULP drift must fail replay");
        assert_eq!(
            error.stats_mismatch_kind(),
            Some(FulpStatsMismatchKind::AxisMaxUlp {
                operation: FulpOperation::Exp,
                axis: StressAxis::LogSampled,
            })
        );
        assert_eq!(
            error.axis_max_ulp_mismatch(),
            Some((
                FulpOperation::Exp,
                StressAxis::LogSampled,
                witness_max_ulp,
                replayed_max_ulp,
            ))
        );
    }

    #[test]
    fn replay_rejects_per_axis_mean_ulp_jump() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
        let replayed_mean_ulp = witness.stats[0].axis_stats[0].mean_ulp;
        witness.stats[0].axis_stats[0].mean_ulp = replayed_mean_ulp + 0.5;
        let witness_mean_ulp = witness.stats[0].axis_stats[0].mean_ulp;
        let json = serde_json::to_string(&witness).unwrap();
        let error = replay_witness_json(&json).expect_err("axis mean ULP drift must fail replay");
        assert_eq!(
            error.stats_mismatch_kind(),
            Some(FulpStatsMismatchKind::AxisMeanUlp {
                operation: FulpOperation::Exp,
                axis: StressAxis::LogSampled,
            })
        );
        assert_eq!(
            error.axis_mean_ulp_mismatch(),
            Some((
                FulpOperation::Exp,
                StressAxis::LogSampled,
                witness_mean_ulp,
                replayed_mean_ulp,
            ))
        );
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
}
