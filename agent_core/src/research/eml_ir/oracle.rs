use super::fixtures::{
    adversarial_fixture, fixture_input, FixtureInput, StressAxis, ADVERSARIAL_FIXTURE_COUNT,
    LOG_SAMPLED_POINT_COUNT, STRESS_POINT_COUNT, TOTAL_FIXTURE_COUNT,
};
use super::fp16::Fp16Bits;
use super::witness::{m2_pro_2023_16gb_pin, FulpWitness};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::time::Instant;

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
#[serde(deny_unknown_fields)]
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
#[serde(deny_unknown_fields)]
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
#[serde(deny_unknown_fields)]
pub struct OperationStats {
    pub operation: FulpOperation,
    pub evaluated: usize,
    pub max_ulp: u32,
    pub gate_tier: UlpGateTier,
    pub mean_ulp: f64,
    pub axis_stats: [AxisStats; StressAxis::ALL.len()],
    pub worst_case: WorstCase,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AxisStats {
    pub axis: StressAxis,
    pub evaluated: usize,
    pub max_ulp: u32,
    pub mean_ulp: f64,
    pub worst_case: WorstCase,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdversarialReferenceStats {
    pub finite_count: usize,
    pub rejected_count: usize,
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
    NonFiniteReferenceFp16 {
        operation: FulpOperation,
        point: FixtureInput,
        bits: u16,
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
    MissingAxisWorstCase {
        operation: FulpOperation,
        axis: StressAxis,
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
    let started_at = Instant::now();
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
        schema_version: 9,
        mission: "F-ULP-Oracle T12".to_string(),
        hardware: m2_pro_2023_16gb_pin(),
        config,
        evaluator_variant: evaluator.variant_name().to_string(),
        shader_entrypoint: MORPH_ORACLE_ENTRYPOINT.to_string(),
        shader_fingerprint: shader_fingerprint(),
        point_count: config.total_points(),
        operation_evaluations: config.total_points() * FulpOperation::ALL.len(),
        grid_fingerprint: hex(&grid_hasher.finalize()),
        adversarial_fixture_count: ADVERSARIAL_FIXTURE_COUNT,
        adversarial_fixture_fingerprint: adversarial_fixture_fingerprint(),
        adversarial_reference_stats: adversarial_reference_stats(),
        adversarial_reference_fingerprint: adversarial_reference_fingerprint(),
        stats,
        pass,
        budget_target_seconds: 90,
        observed_wall_clock_millis: elapsed_millis_u64(started_at),
    })
}

fn elapsed_millis_u64(started_at: Instant) -> u64 {
    let elapsed = started_at.elapsed().as_millis();
    elapsed.min(u128::from(u64::MAX)) as u64
}

fn evaluate_point<E: FulpEvaluator>(
    point: FixtureInput,
    evaluator: &E,
    accumulators: &mut [StatsAccumulator; 3],
) -> Result<(), FulpOracleError> {
    for (index, operation) in FulpOperation::ALL.iter().copied().enumerate() {
        let reference = reference_value(operation, point)?;
        let reference_bits = Fp16Bits::from_f64(reference);
        if !reference_bits.is_finite() {
            return Err(FulpOracleError::NonFiniteReferenceFp16 {
                operation,
                point,
                bits: reference_bits.bits(),
            });
        }
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

pub fn adversarial_fixture_fingerprint() -> String {
    let mut hasher = Sha256::new();
    for index in 0..ADVERSARIAL_FIXTURE_COUNT {
        let fixture = adversarial_fixture(index);
        hasher.update((fixture.index as u64).to_le_bytes());
        hasher.update(fixture.label.as_bytes());
        hasher.update([0]);
        hasher.update([fixture.operation.as_u8()]);
        hasher.update(fixture.x.to_bits().to_le_bytes());
        hasher.update(fixture.y.to_bits().to_le_bytes());
    }
    hex(&hasher.finalize())
}

pub fn adversarial_reference_fingerprint() -> String {
    let mut hasher = Sha256::new();
    visit_adversarial_references(|fixture, operation, result| {
        hasher.update((fixture.index as u64).to_le_bytes());
        hasher.update(fixture.label.as_bytes());
        hasher.update([0]);
        hasher.update(operation.as_str().as_bytes());
        match result {
            Ok(value) => {
                hasher.update([1]);
                hasher.update(value.to_bits().to_le_bytes());
                hasher.update(Fp16Bits::from_f64(value).bits().to_le_bytes());
            }
            Err(error) => update_reference_error_hash(&mut hasher, error),
        }
    });
    hex(&hasher.finalize())
}

pub fn adversarial_reference_stats() -> AdversarialReferenceStats {
    let mut stats = AdversarialReferenceStats {
        finite_count: 0,
        rejected_count: 0,
    };
    visit_adversarial_references(|_, _, result| match result {
        Ok(_) => stats.finite_count += 1,
        Err(_) => stats.rejected_count += 1,
    });
    stats
}

fn visit_adversarial_references(
    mut visitor: impl FnMut(
        &super::fixtures::AdversarialFixture,
        FulpOperation,
        Result<f64, FulpOracleError>,
    ),
) {
    for index in 0..ADVERSARIAL_FIXTURE_COUNT {
        let fixture = adversarial_fixture(index);
        let operation = adversarial_operation_to_fulp(fixture.operation);
        let result = reference_value(operation, fixture.to_fixture_input());
        visitor(&fixture, operation, result);
    }
}

fn update_reference_error_hash(hasher: &mut Sha256, error: FulpOracleError) {
    hasher.update([0]);
    match error {
        FulpOracleError::NonFiniteReference { value, .. } => {
            hasher.update([0]);
            hasher.update(value.to_bits().to_le_bytes());
        }
        FulpOracleError::NonFiniteReferenceFp16 { bits, .. } => {
            hasher.update([1]);
            hasher.update(bits.to_le_bytes());
        }
        FulpOracleError::NanCandidate { .. } => hasher.update([2]),
        FulpOracleError::NonFiniteCandidate { bits, .. } => {
            hasher.update([3]);
            hasher.update(bits.to_le_bytes());
        }
        FulpOracleError::EmptyGrid => hasher.update([4]),
        FulpOracleError::InvalidGridCount {
            log_sampled,
            stress,
        } => {
            hasher.update([5]);
            hasher.update((log_sampled as u64).to_le_bytes());
            hasher.update((stress as u64).to_le_bytes());
        }
        FulpOracleError::MissingWorstCase { operation } => {
            hasher.update([6]);
            hasher.update(operation.as_str().as_bytes());
        }
        FulpOracleError::MissingAxisWorstCase { operation, axis } => {
            hasher.update([7]);
            hasher.update(operation.as_str().as_bytes());
            hasher.update([axis as u8]);
        }
    }
}

const fn adversarial_operation_to_fulp(
    operation: super::fixtures::AdversarialOperation,
) -> FulpOperation {
    match operation {
        super::fixtures::AdversarialOperation::Exp => FulpOperation::Exp,
        super::fixtures::AdversarialOperation::Ln => FulpOperation::Ln,
        super::fixtures::AdversarialOperation::Eml => FulpOperation::Eml,
    }
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
    axis_accumulators: [AxisAccumulator; StressAxis::ALL.len()],
}

impl StatsAccumulator {
    fn new(operation: FulpOperation) -> Self {
        Self {
            operation,
            evaluated: 0,
            sum_ulp: 0,
            max_ulp: 0,
            worst_case: None,
            axis_accumulators: StressAxis::ALL.map(AxisAccumulator::new),
        }
    }

    fn observe(&mut self, sample: WorstCase) {
        self.evaluated += 1;
        self.sum_ulp += sample.ulp_error as u64;
        self.axis_accumulators[sample.axis.index()].observe(sample);
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
            axis_stats: finish_axis_stats(self.axis_accumulators, self.operation)?,
            worst_case,
        })
    }
}

#[derive(Clone, Copy, Debug)]
struct AxisAccumulator {
    axis: StressAxis,
    evaluated: usize,
    sum_ulp: u64,
    max_ulp: u32,
    worst_case: Option<WorstCase>,
}

impl AxisAccumulator {
    const fn new(axis: StressAxis) -> Self {
        Self {
            axis,
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

    fn finish(self, operation: FulpOperation) -> Result<AxisStats, FulpOracleError> {
        let Some(worst_case) = self.worst_case else {
            return Err(FulpOracleError::MissingAxisWorstCase {
                operation,
                axis: self.axis,
            });
        };
        Ok(AxisStats {
            axis: self.axis,
            evaluated: self.evaluated,
            max_ulp: self.max_ulp,
            mean_ulp: self.sum_ulp as f64 / self.evaluated as f64,
            worst_case,
        })
    }
}

fn finish_axis_stats(
    accumulators: [AxisAccumulator; StressAxis::ALL.len()],
    operation: FulpOperation,
) -> Result<[AxisStats; StressAxis::ALL.len()], FulpOracleError> {
    let [log_sampled, closed_edge, exp_midpoint, ln_midpoint, eml_cross] = accumulators;
    Ok([
        log_sampled.finish(operation)?,
        closed_edge.finish(operation)?,
        exp_midpoint.finish(operation)?,
        ln_midpoint.finish(operation)?,
        eml_cross.finish(operation)?,
    ])
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::research::eml_ir::{FixtureKind, StressAxis};

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
    fn reference_rejects_ln_branch_cut_inputs() {
        let point = FixtureInput {
            index: usize::MAX,
            kind: FixtureKind::Stress,
            axis: StressAxis::ClosedIntervalEdge,
            x: 1.0,
            y: -1.0,
        };
        let error = reference_value(FulpOperation::Ln, point)
            .expect_err("negative ln input must fail reference oracle");
        assert!(matches!(error, FulpOracleError::NonFiniteReference { .. }));
    }

    #[test]
    fn reference_rejects_ln_signed_zero_inputs() {
        for y in [0.0, -0.0] {
            let point = FixtureInput {
                index: usize::MAX,
                kind: FixtureKind::Stress,
                axis: StressAxis::ClosedIntervalEdge,
                x: 1.0,
                y,
            };
            let error = reference_value(FulpOperation::Ln, point)
                .expect_err("zero ln input must fail reference oracle");
            assert!(matches!(error, FulpOracleError::NonFiniteReference { .. }));
        }
    }

    #[test]
    fn reference_rejects_eml_when_ln_branch_cut_is_invalid() {
        let point = FixtureInput {
            index: usize::MAX,
            kind: FixtureKind::Stress,
            axis: StressAxis::ClosedIntervalEdge,
            x: 1.0,
            y: -1.0,
        };
        let error = reference_value(FulpOperation::Eml, point)
            .expect_err("eml reference must fail when ln branch cut is invalid");
        assert!(matches!(error, FulpOracleError::NonFiniteReference { .. }));
    }

    #[test]
    fn oracle_rejects_fp16_overflow_reference_before_candidate_scoring() {
        let point = FixtureInput {
            index: usize::MAX,
            kind: FixtureKind::Stress,
            axis: StressAxis::ClosedIntervalEdge,
            x: 12.0,
            y: 1.0,
        };
        let mut accumulators = [
            StatsAccumulator::new(FulpOperation::Exp),
            StatsAccumulator::new(FulpOperation::Ln),
            StatsAccumulator::new(FulpOperation::Eml),
        ];
        let error = evaluate_point(point, &ReferenceRoundedEvaluator, &mut accumulators)
            .expect_err("fp64 reference that overflows binary16 must be a reference error");
        assert!(matches!(
            error,
            FulpOracleError::NonFiniteReferenceFp16 { .. }
        ));
    }

    #[test]
    fn ulp_gate_ladder_marks_primary_and_fallback_without_hiding_failure() {
        assert_eq!(classify_ulp_gate(2), UlpGateTier::Primary);
        assert_eq!(classify_ulp_gate(3), UlpGateTier::Fallback);
        assert_eq!(classify_ulp_gate(4), UlpGateTier::Fallback);
        assert_eq!(classify_ulp_gate(5), UlpGateTier::Fail);
    }

    #[test]
    fn adversarial_fixture_fingerprint_pins_edge_lane() {
        assert_eq!(adversarial_fixture_fingerprint().len(), 64);
        assert_eq!(
            adversarial_fixture_fingerprint(),
            "a7548c5410e0bb525dbe4bbf5c7a546a7ad59d35f672388db9e76259780419ed"
        );
    }

    #[test]
    fn adversarial_reference_fingerprint_pins_edge_outcomes() {
        assert_eq!(adversarial_reference_fingerprint().len(), 64);
        assert_eq!(
            adversarial_reference_fingerprint(),
            "991ab58926bc94a34fc0c97c56fdf991eb47f164dd8eb4ae736a793a5622cb8d"
        );
    }

    #[test]
    fn adversarial_fixtures_execute_declared_reference_paths() {
        for index in 0..ADVERSARIAL_FIXTURE_COUNT {
            let fixture = adversarial_fixture(index);
            let point = fixture.to_fixture_input();
            let operation = adversarial_operation_to_fulp(fixture.operation);
            let result = reference_value(operation, point);
            match fixture.label {
                "exp_positive_zero" | "exp_negative_zero" => {
                    assert_eq!(Fp16Bits::from_f64(result.unwrap()).bits(), 0x3c00);
                }
                "ln_f64_min_positive_subnormal"
                | "ln_fp16_min_positive_subnormal"
                | "ln_fp16_max_positive_subnormal"
                | "ln_fp16_min_positive_normal"
                | "eml_fp16_max_positive_subnormal"
                | "eml_fp16_min_positive_normal" => {
                    assert!(result.unwrap().is_finite());
                }
                "negative_infinity_x" => {
                    assert_eq!(Fp16Bits::from_f64(result.unwrap()).bits(), 0x0000);
                }
                _ => {
                    assert!(result.is_err(), "{} should reject", fixture.label);
                }
            }
        }
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
