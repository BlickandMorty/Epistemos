use super::fixtures::{
    fixture_input, FixtureInput, LOG_SAMPLED_POINT_COUNT, STRESS_POINT_COUNT, TOTAL_FIXTURE_COUNT,
};
use super::fp16::Fp16Bits;
use super::witness::{m2_pro_2023_16gb_pin, FulpWitness};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

pub const ULP_TOLERANCE_FP16: u32 = 2;
pub const FALLBACK_ULP_TOLERANCE_FP16: u32 = 4;
pub const MORPH_ORACLE_ENTRYPOINT: &str = "morphOracleFp16";
const MORPH_SHADER_SOURCE: &str =
    include_str!("../../../../Epistemos/Shaders/morph_eval_reduced.metal");

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum UlpGateTier {
    Primary,
    Fallback,
    Fail,
}

pub const fn classify_ulp_gate(max_ulp: u32) -> UlpGateTier {
    if max_ulp <= ULP_TOLERANCE_FP16 {
        UlpGateTier::Primary
    } else if max_ulp <= FALLBACK_ULP_TOLERANCE_FP16 {
        UlpGateTier::Fallback
    } else {
        UlpGateTier::Fail
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum FulpOperation {
    Exp,
    Ln,
    Eml,
}

impl FulpOperation {
    pub const ALL: [Self; 3] = [Self::Exp, Self::Ln, Self::Eml];

    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Exp => "exp",
            Self::Ln => "ln",
            Self::Eml => "eml",
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct FulpRunConfig {
    pub log_sampled_points: usize,
    pub stress_points: usize,
    pub ulp_tolerance: u32,
}

impl FulpRunConfig {
    pub const ACCEPTANCE: Self = Self {
        log_sampled_points: LOG_SAMPLED_POINT_COUNT,
        stress_points: STRESS_POINT_COUNT,
        ulp_tolerance: ULP_TOLERANCE_FP16,
    };

    pub const fn total_points(self) -> usize {
        self.log_sampled_points + self.stress_points
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct WorstCase {
    pub operation: FulpOperation,
    pub point_index: usize,
    pub axis: super::StressAxis,
    pub x: f64,
    pub y: f64,
    pub reference: f64,
    pub reference_fp16_bits: u16,
    pub candidate_fp16_bits: u16,
    pub ulp_error: u32,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct OperationStats {
    pub operation: FulpOperation,
    pub evaluated: usize,
    pub max_ulp: u32,
    pub gate_tier: UlpGateTier,
    pub mean_ulp: f64,
    pub worst_case: WorstCase,
}

pub trait FulpEvaluator {
    fn variant_name(&self) -> &'static str;
    fn evaluate(
        &self,
        operation: FulpOperation,
        point: FixtureInput,
    ) -> Result<Fp16Bits, FulpOracleError>;
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ReferenceRoundedEvaluator;

impl FulpEvaluator for ReferenceRoundedEvaluator {
    fn variant_name(&self) -> &'static str {
        "fp64_reference_rounded_binary16_v1"
    }

    fn evaluate(
        &self,
        operation: FulpOperation,
        point: FixtureInput,
    ) -> Result<Fp16Bits, FulpOracleError> {
        Ok(Fp16Bits::from_f64(reference_value(operation, point)?))
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct CpuFloatIntrinsicEvaluator;

impl FulpEvaluator for CpuFloatIntrinsicEvaluator {
    fn variant_name(&self) -> &'static str {
        "cpu_float_intrinsic_morph_oracle_fp16_v1"
    }

    fn evaluate(
        &self,
        operation: FulpOperation,
        point: FixtureInput,
    ) -> Result<Fp16Bits, FulpOracleError> {
        let x = point.x as f32;
        let y = point.y as f32;
        let exp_value = x.exp();
        let ln_value = y.ln();
        let candidate = match operation {
            FulpOperation::Exp => exp_value,
            FulpOperation::Ln => ln_value,
            FulpOperation::Eml => exp_value - ln_value,
        };
        Ok(Fp16Bits::from_f64(candidate as f64))
    }
}

#[derive(Clone, Debug, PartialEq)]
pub enum FulpOracleError {
    EmptyGrid,
    InvalidGridCount {
        log_sampled: usize,
        stress: usize,
    },
    NonFiniteReference {
        operation: FulpOperation,
        point: FixtureInput,
        value: f64,
    },
    NanCandidate {
        operation: FulpOperation,
        point: FixtureInput,
    },
    NonFiniteCandidate {
        operation: FulpOperation,
        point: FixtureInput,
        bits: u16,
    },
    MissingWorstCase {
        operation: FulpOperation,
    },
}

pub fn reference_value(
    operation: FulpOperation,
    point: FixtureInput,
) -> Result<f64, FulpOracleError> {
    let value = match operation {
        FulpOperation::Exp => point.x.exp(),
        FulpOperation::Ln => point.y.ln(),
        FulpOperation::Eml => point.x.exp() - point.y.ln(),
    };
    if value.is_finite() {
        Ok(value)
    } else {
        Err(FulpOracleError::NonFiniteReference {
            operation,
            point,
            value,
        })
    }
}

pub fn run_fulp_oracle<E: FulpEvaluator>(
    config: FulpRunConfig,
    evaluator: &E,
) -> Result<FulpWitness, FulpOracleError> {
    if config.total_points() == 0 {
        return Err(FulpOracleError::EmptyGrid);
    }
    if config.log_sampled_points != LOG_SAMPLED_POINT_COUNT
        || config.stress_points != STRESS_POINT_COUNT
    {
        return Err(FulpOracleError::InvalidGridCount {
            log_sampled: config.log_sampled_points,
            stress: config.stress_points,
        });
    }

    let mut accumulators = [
        StatsAccumulator::new(FulpOperation::Exp),
        StatsAccumulator::new(FulpOperation::Ln),
        StatsAccumulator::new(FulpOperation::Eml),
    ];
    let mut grid_hasher = Sha256::new();

    for i in 0..config.total_points() {
        let point = fixture_input(i);
        update_grid_hash(&mut grid_hasher, point);
        evaluate_point(point, evaluator, &mut accumulators)?;
    }

    let stats = [
        accumulators[0].finish()?,
        accumulators[1].finish()?,
        accumulators[2].finish()?,
    ];
    let pass = stats
        .iter()
        .all(|stat| stat.evaluated == TOTAL_FIXTURE_COUNT && stat.max_ulp <= config.ulp_tolerance);

    Ok(FulpWitness {
        schema_version: 3,
        mission: "F-ULP-Oracle T12".to_string(),
        hardware: m2_pro_2023_16gb_pin(),
        config,
        evaluator_variant: evaluator.variant_name().to_string(),
        shader_entrypoint: MORPH_ORACLE_ENTRYPOINT.to_string(),
        shader_fingerprint: shader_fingerprint(),
        point_count: config.total_points(),
        operation_evaluations: config.total_points() * FulpOperation::ALL.len(),
        grid_fingerprint: hex(&grid_hasher.finalize()),
        stats,
        pass,
        budget_target_seconds: 90,
    })
}

fn evaluate_point<E: FulpEvaluator>(
    point: FixtureInput,
    evaluator: &E,
    accumulators: &mut [StatsAccumulator; 3],
) -> Result<(), FulpOracleError> {
    for (index, operation) in FulpOperation::ALL.iter().copied().enumerate() {
        let reference = reference_value(operation, point)?;
        let reference_bits = Fp16Bits::from_f64(reference);
        let candidate_bits = evaluator.evaluate(operation, point)?;
        if candidate_bits.is_nan() {
            return Err(FulpOracleError::NanCandidate { operation, point });
        }
        if !candidate_bits.is_finite() {
            return Err(FulpOracleError::NonFiniteCandidate {
                operation,
                point,
                bits: candidate_bits.bits(),
            });
        }
        let ulp_error = candidate_bits
            .ulp_distance(reference_bits)
            .expect("finite candidate and reference must have ULP distance");
        accumulators[index].observe(WorstCase {
            operation,
            point_index: point.index,
            axis: point.axis,
            x: point.x,
            y: point.y,
            reference,
            reference_fp16_bits: reference_bits.bits(),
            candidate_fp16_bits: candidate_bits.bits(),
            ulp_error,
        });
    }
    Ok(())
}

fn update_grid_hash(hasher: &mut Sha256, point: FixtureInput) {
    hasher.update((point.index as u64).to_le_bytes());
    hasher.update((point.kind as u8).to_le_bytes());
    hasher.update((point.axis as u8).to_le_bytes());
    hasher.update(point.x.to_bits().to_le_bytes());
    hasher.update(point.y.to_bits().to_le_bytes());
}

fn shader_fingerprint() -> String {
    let mut hasher = Sha256::new();
    hasher.update(MORPH_ORACLE_ENTRYPOINT.as_bytes());
    hasher.update(MORPH_SHADER_SOURCE.as_bytes());
    hex(&hasher.finalize())
}

fn hex(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        out.push(HEX[(byte >> 4) as usize] as char);
        out.push(HEX[(byte & 0x0f) as usize] as char);
    }
    out
}

#[derive(Clone, Copy, Debug)]
struct StatsAccumulator {
    operation: FulpOperation,
    evaluated: usize,
    sum_ulp: u64,
    max_ulp: u32,
    worst_case: Option<WorstCase>,
}

impl StatsAccumulator {
    const fn new(operation: FulpOperation) -> Self {
        Self {
            operation,
            evaluated: 0,
            sum_ulp: 0,
            max_ulp: 0,
            worst_case: None,
        }
    }

    fn observe(&mut self, sample: WorstCase) {
        self.evaluated += 1;
        self.sum_ulp += sample.ulp_error as u64;
        if self.worst_case.is_none() || sample.ulp_error > self.max_ulp {
            self.max_ulp = sample.ulp_error;
            self.worst_case = Some(sample);
        }
    }

    fn finish(self) -> Result<OperationStats, FulpOracleError> {
        let Some(worst_case) = self.worst_case else {
            return Err(FulpOracleError::MissingWorstCase {
                operation: self.operation,
            });
        };
        Ok(OperationStats {
            operation: self.operation,
            evaluated: self.evaluated,
            max_ulp: self.max_ulp,
            gate_tier: classify_ulp_gate(self.max_ulp),
            mean_ulp: self.sum_ulp as f64 / self.evaluated as f64,
            worst_case,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cpu_float_intrinsic_acceptance_witness_passes_two_ulp_gate() {
        let witness =
            run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &CpuFloatIntrinsicEvaluator).unwrap();
        assert!(witness.pass, "{witness:#?}");
        assert_eq!(witness.point_count, TOTAL_FIXTURE_COUNT);
        for stat in &witness.stats {
            assert_eq!(stat.evaluated, TOTAL_FIXTURE_COUNT);
            assert!(stat.max_ulp <= ULP_TOLERANCE_FP16, "{stat:#?}");
            assert_eq!(stat.gate_tier, UlpGateTier::Primary);
        }
    }

    #[test]
    fn reference_values_are_fp64_before_binary16_rounding() {
        let point = fixture_input(17);
        let value = reference_value(FulpOperation::Eml, point).unwrap();
        assert_eq!(
            Fp16Bits::from_f64(value),
            Fp16Bits::from_f64(point.x.exp() - point.y.ln())
        );
    }

    #[test]
    fn ulp_gate_ladder_marks_primary_and_fallback_without_hiding_failure() {
        assert_eq!(classify_ulp_gate(2), UlpGateTier::Primary);
        assert_eq!(classify_ulp_gate(3), UlpGateTier::Fallback);
        assert_eq!(classify_ulp_gate(4), UlpGateTier::Fallback);
        assert_eq!(classify_ulp_gate(5), UlpGateTier::Fail);
    }

    #[derive(Clone, Copy, Debug)]
    struct FixedCandidateEvaluator {
        variant_name: &'static str,
        bits: Fp16Bits,
    }

    impl FulpEvaluator for FixedCandidateEvaluator {
        fn variant_name(&self) -> &'static str {
            self.variant_name
        }

        fn evaluate(
            &self,
            _operation: FulpOperation,
            _point: FixtureInput,
        ) -> Result<Fp16Bits, FulpOracleError> {
            Ok(self.bits)
        }
    }

    #[test]
    fn oracle_rejects_nonfinite_candidate_before_ulp_stats() {
        let evaluator = FixedCandidateEvaluator {
            variant_name: "infinite_candidate_test",
            bits: Fp16Bits::from_f64(f64::INFINITY),
        };
        let error = run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &evaluator)
            .expect_err("infinite fp16 candidate must be an oracle error");
        assert!(matches!(error, FulpOracleError::NonFiniteCandidate { .. }));
    }

    #[test]
    fn oracle_rejects_nan_candidate_with_nan_error() {
        let evaluator = FixedCandidateEvaluator {
            variant_name: "nan_candidate_test",
            bits: Fp16Bits::from_f64(f64::NAN),
        };
        let error = run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &evaluator)
            .expect_err("nan fp16 candidate must be an oracle error");
        assert!(matches!(error, FulpOracleError::NanCandidate { .. }));
    }
}
