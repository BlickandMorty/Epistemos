use super::binary16::Fp16Bits;
use super::fixtures::{
    adversarial_fixture, stratified_point, FulpAxis, FulpPoint, ADVERSARIAL_POINT_COUNT,
    STRATIFIED_POINT_COUNT, TOTAL_POINT_COUNT,
};
use super::witness::{m2_pro_2023_16gb_pin, FulpWitness};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

pub const ULP_TOLERANCE_FP16: u32 = 2;

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
    pub stratified_points: usize,
    pub adversarial_points: usize,
    pub ulp_tolerance: u32,
}

impl FulpRunConfig {
    pub const ACCEPTANCE: Self = Self {
        stratified_points: STRATIFIED_POINT_COUNT,
        adversarial_points: ADVERSARIAL_POINT_COUNT,
        ulp_tolerance: ULP_TOLERANCE_FP16,
    };

    pub const fn total_points(self) -> usize {
        self.stratified_points + self.adversarial_points
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct WorstCase {
    pub operation: FulpOperation,
    pub point_index: usize,
    pub axis: FulpAxis,
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
    pub mean_ulp: f64,
    pub worst_case: WorstCase,
}

pub trait FulpEvaluator {
    fn variant_name(&self) -> &'static str;
    fn evaluate(
        &self,
        operation: FulpOperation,
        point: FulpPoint,
    ) -> Result<Fp16Bits, FulpOracleError>;
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ReferenceRoundedKernel;

impl FulpEvaluator for ReferenceRoundedKernel {
    fn variant_name(&self) -> &'static str {
        "cpu_reference_rounded_fp16_v1"
    }

    fn evaluate(
        &self,
        operation: FulpOperation,
        point: FulpPoint,
    ) -> Result<Fp16Bits, FulpOracleError> {
        Ok(Fp16Bits::from_f64(reference_value(operation, point)?))
    }
}

#[derive(Clone, Debug, PartialEq)]
pub enum FulpOracleError {
    EmptyGrid,
    InvalidGridCount {
        stratified: usize,
        adversarial: usize,
    },
    NonFiniteReference {
        operation: FulpOperation,
        point: FulpPoint,
        value: f64,
    },
    NanCandidate {
        operation: FulpOperation,
        point: FulpPoint,
    },
    MissingWorstCase {
        operation: FulpOperation,
    },
}

pub fn reference_value(operation: FulpOperation, point: FulpPoint) -> Result<f64, FulpOracleError> {
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
    if config.stratified_points != STRATIFIED_POINT_COUNT
        || config.adversarial_points != ADVERSARIAL_POINT_COUNT
    {
        return Err(FulpOracleError::InvalidGridCount {
            stratified: config.stratified_points,
            adversarial: config.adversarial_points,
        });
    }

    let mut accumulators = [
        StatsAccumulator::new(FulpOperation::Exp),
        StatsAccumulator::new(FulpOperation::Ln),
        StatsAccumulator::new(FulpOperation::Eml),
    ];
    let mut grid_hasher = Sha256::new();

    for i in 0..config.stratified_points {
        let point = stratified_point(i, config.stratified_points);
        update_grid_hash(&mut grid_hasher, point);
        evaluate_point(point, evaluator, &mut accumulators)?;
    }
    for i in 0..config.adversarial_points {
        let point = adversarial_fixture(i);
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
        .all(|s| s.evaluated == TOTAL_POINT_COUNT && s.max_ulp <= config.ulp_tolerance);

    Ok(FulpWitness {
        schema_version: 1,
        mission: "F-ULP-Oracle T12".to_string(),
        hardware: m2_pro_2023_16gb_pin(),
        config,
        evaluator_variant: evaluator.variant_name().to_string(),
        point_count: config.total_points(),
        operation_evaluations: config.total_points() * FulpOperation::ALL.len(),
        grid_fingerprint: hex(&grid_hasher.finalize()),
        stats,
        pass,
    })
}

fn evaluate_point<E: FulpEvaluator>(
    point: FulpPoint,
    evaluator: &E,
    accumulators: &mut [StatsAccumulator; 3],
) -> Result<(), FulpOracleError> {
    for (idx, operation) in FulpOperation::ALL.iter().copied().enumerate() {
        let reference = reference_value(operation, point)?;
        let reference_bits = Fp16Bits::from_f64(reference);
        let candidate_bits = evaluator.evaluate(operation, point)?;
        let Some(ulp_error) = candidate_bits.ulp_distance(reference_bits) else {
            return Err(FulpOracleError::NanCandidate { operation, point });
        };
        accumulators[idx].observe(WorstCase {
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

fn update_grid_hash(hasher: &mut Sha256, point: FulpPoint) {
    hasher.update((point.index as u64).to_le_bytes());
    hasher.update((point.kind as u8).to_le_bytes());
    hasher.update((point.axis as u8).to_le_bytes());
    hasher.update(point.x.to_bits().to_le_bytes());
    hasher.update(point.y.to_bits().to_le_bytes());
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
            mean_ulp: self.sum_ulp as f64 / self.evaluated as f64,
            worst_case,
        })
    }
}
