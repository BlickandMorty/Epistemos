use super::oracle::{
    run_fulp_oracle, AdversarialReferenceStats, AxisStats, CpuFloatIntrinsicEvaluator,
    FulpEvaluator, FulpOperation, FulpRunConfig, OperationStats, ReferenceRoundedEvaluator,
    WorstCase, FULP_BUDGET_TARGET_MILLIS, FULP_BUDGET_TARGET_SECONDS,
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
    let expected_len = StressAxis::ALL.len();
    for (operation_index, stat) in stats.iter().enumerate() {
        if !stat.is_object() {
            return Err(FulpReplayError::InvalidJson {
                message: format!("invalid type for stats[{operation_index}], expected object"),
                kind: FulpInvalidJsonKind::TypeMismatch,
            });
        }
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
        let Some(evaluated_value) = stat.get("evaluated") else {
            return Err(FulpReplayError::InvalidJson {
                message: format!("missing field stats[{operation_index}].evaluated"),
                kind: FulpInvalidJsonKind::MissingField,
            });
        };
        if evaluated_value.as_u64().is_none() {
            return Err(FulpReplayError::InvalidJson {
                message: format!(
                    "invalid type for stats[{operation_index}].evaluated, expected unsigned integer"
                ),
                kind: FulpInvalidJsonKind::TypeMismatch,
            });
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
            if !axis_stat.is_object() {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "invalid type for stats[{operation_index}].axis_stats[{axis_index}], expected object"
                    ),
                    kind: FulpInvalidJsonKind::TypeMismatch,
                });
            }
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
            let Some(evaluated_value) = axis_stat.get("evaluated") else {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "missing field stats[{operation_index}].axis_stats[{axis_index}].evaluated"
                    ),
                    kind: FulpInvalidJsonKind::MissingField,
                });
            };
            if evaluated_value.as_u64().is_none() {
                return Err(FulpReplayError::InvalidJson {
                    message: format!(
                        "invalid type for stats[{operation_index}].axis_stats[{axis_index}].evaluated, expected unsigned integer"
                    ),
                    kind: FulpInvalidJsonKind::TypeMismatch,
                });
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
        }
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
        assert_eq!(error.pass_mismatch_pair(), Some((false, true)));
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
        assert_eq!(
            error.count_mismatch_kind(),
            Some(FulpCountMismatchKind::AdversarialFixtureCount)
        );
    }

    #[test]
    fn replay_rejects_adversarial_reference_stats_drift() {
        let mut witness: FulpWitness = serde_json::from_str(&acceptance_witness_json().unwrap())
            .expect("acceptance witness json");
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
    fn replay_rejects_witness_json_type_drift() {
        let mut value: serde_json::Value =
            serde_json::from_str(&acceptance_witness_json().unwrap()).expect("witness json");
        value["budget_target_seconds"] = serde_json::Value::String("90".to_string());
        let json = serde_json::to_string(&value).unwrap();
        let error = replay_witness_json(&json).expect_err("type drift must fail replay");
        assert_eq!(
            error.invalid_json_kind(),
            Some(FulpInvalidJsonKind::TypeMismatch)
        );
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

    fn assert_invalid_witness_json(json: &str) {
        let error = replay_witness_json(json).expect_err("invalid JSON must fail replay");
        assert!(error.is_invalid_json());
    }

    fn assert_invalid_witness_json_value(value: serde_json::Value) {
        let json = serde_json::to_string(&value).expect("corrupted JSON value");
        assert_invalid_witness_json(&json);
    }
}
