//! Source:
//! - `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T12.
//! - `docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md` §3.5.
//! - `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` §1.1.
//!
//! F-ULP-Oracle verifies the fp16 arithmetic floor for `exp`, `ln`, and
//! `eml(x, y) = exp(x) - ln(y)` over the closed `[0.5, 2]` interval.

mod binary16;
mod fixtures;
mod oracle;
mod witness;

pub use binary16::{Fp16Bits, Fp16Class};
pub use fixtures::{
    adversarial_fixture, stratified_point, FulpAxis, FulpPoint, FulpPointKind,
    ADVERSARIAL_POINT_COUNT, CLOSED_INTERVAL_MAX, CLOSED_INTERVAL_MIN, STRATIFIED_POINT_COUNT,
    TOTAL_POINT_COUNT,
};
pub use oracle::{
    reference_value, run_fulp_oracle, FulpEvaluator, FulpOperation, FulpOracleError, FulpRunConfig,
    OperationStats, ReferenceRoundedKernel, WorstCase, ULP_TOLERANCE_FP16,
};
pub use witness::{
    acceptance_witness_json, replay_witness_json, FulpReplayError, FulpWitness, HardwarePin,
};

#[cfg(test)]
mod tests {
    use super::*;

    fn approx(a: f64, b: f64, tolerance: f64) -> bool {
        (a - b).abs() <= tolerance
    }

    #[test]
    fn fulp_oracle_acceptance_grid_counts_are_locked() {
        assert_eq!(STRATIFIED_POINT_COUNT, 412_000);
        assert_eq!(ADVERSARIAL_POINT_COUNT, 2_048);
        assert_eq!(TOTAL_POINT_COUNT, 414_048);
        assert_eq!(FulpRunConfig::ACCEPTANCE.total_points(), TOTAL_POINT_COUNT);
    }

    #[test]
    fn fulp_oracle_stratified_grid_is_closed_interval_log_sampled() {
        let first = stratified_point(0, STRATIFIED_POINT_COUNT);
        let last = stratified_point(STRATIFIED_POINT_COUNT - 1, STRATIFIED_POINT_COUNT);

        assert!(approx(first.x, CLOSED_INTERVAL_MIN, 1e-15));
        assert!(approx(last.x, CLOSED_INTERVAL_MAX, 1e-15));
        assert!(first.y >= CLOSED_INTERVAL_MIN && first.y <= CLOSED_INTERVAL_MAX);
        assert!(last.y >= CLOSED_INTERVAL_MIN && last.y <= CLOSED_INTERVAL_MAX);

        for i in [1, 17, 4_096, 111_111, 411_999] {
            let p = stratified_point(i, STRATIFIED_POINT_COUNT);
            assert!(p.x >= CLOSED_INTERVAL_MIN && p.x <= CLOSED_INTERVAL_MAX);
            assert!(p.y >= CLOSED_INTERVAL_MIN && p.y <= CLOSED_INTERVAL_MAX);
            assert_eq!(p.kind, FulpPointKind::Stratified);
            assert_eq!(p.axis, FulpAxis::StratifiedLog);
        }
    }

    #[test]
    fn fulp_oracle_adversarial_fixtures_cover_four_axes() {
        let mut counts = [0usize; 4];
        for i in 0..ADVERSARIAL_POINT_COUNT {
            let p = adversarial_fixture(i);
            assert!(
                p.x >= CLOSED_INTERVAL_MIN && p.x <= CLOSED_INTERVAL_MAX,
                "{p:?}"
            );
            assert!(
                p.y >= CLOSED_INTERVAL_MIN && p.y <= CLOSED_INTERVAL_MAX,
                "{p:?}"
            );
            assert_eq!(p.kind, FulpPointKind::Adversarial);
            match p.axis {
                FulpAxis::ClosedIntervalEdge => counts[0] += 1,
                FulpAxis::ExpOutputMidpoint => counts[1] += 1,
                FulpAxis::LnOutputMidpoint => counts[2] += 1,
                FulpAxis::EmlCrossMidpoint => counts[3] += 1,
                FulpAxis::StratifiedLog => panic!("adversarial fixture used stratified axis"),
            }
        }
        assert_eq!(counts, [512, 512, 512, 512]);
    }

    #[test]
    fn fulp_oracle_binary16_rounds_core_interval_values_exactly() {
        assert_eq!(Fp16Bits::from_f64(0.5).bits(), 0x3800);
        assert_eq!(Fp16Bits::from_f64(1.0).bits(), 0x3c00);
        assert_eq!(Fp16Bits::from_f64(2.0).bits(), 0x4000);
        assert_eq!(Fp16Bits::from_f64(2.0_f64.powi(-24)).bits(), 0x0001);
    }

    #[test]
    fn fulp_oracle_full_grid_reference_rounded_kernel_passes_two_ulp_gate() {
        let witness = run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &ReferenceRoundedKernel).unwrap();
        assert!(witness.pass, "{witness:#?}");
        assert_eq!(witness.point_count, TOTAL_POINT_COUNT);
        assert_eq!(
            witness.operation_evaluations,
            TOTAL_POINT_COUNT * FulpOperation::ALL.len()
        );
        for stat in &witness.stats {
            assert!(stat.max_ulp <= ULP_TOLERANCE_FP16, "{stat:#?}");
            assert_eq!(stat.evaluated, TOTAL_POINT_COUNT);
        }
    }

    #[test]
    fn fulp_oracle_witness_records_m2_pro_pin_without_serialized_device_ids() {
        let witness = run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &ReferenceRoundedKernel).unwrap();
        assert_eq!(witness.hardware.model, "MacBook Pro 14-inch 2023");
        assert_eq!(witness.hardware.chip, "Apple M2 Pro");
        assert_eq!(witness.hardware.memory_gb, 16);
        assert_eq!(witness.hardware.memory_bandwidth_gb_s, 200);
        assert!(witness.hardware.uma);
        assert_eq!(witness.budget_target_seconds, 90);
    }

    #[test]
    fn fulp_oracle_witness_json_replays_to_same_fingerprint() {
        let json = acceptance_witness_json().unwrap();
        let witness: FulpWitness = serde_json::from_str(&json).unwrap();
        let replayed = replay_witness_json(&json).unwrap();
        assert_eq!(replayed.grid_fingerprint, witness.grid_fingerprint);
        assert_eq!(replayed.pass, witness.pass);
        assert_eq!(replayed.stats, witness.stats);
    }

    #[test]
    fn fulp_oracle_replay_rejects_corrupt_grid_fingerprint() {
        let json = acceptance_witness_json().unwrap();
        let mut witness: FulpWitness = serde_json::from_str(&json).unwrap();
        let replacement = if witness.grid_fingerprint.starts_with('0') {
            "1"
        } else {
            "0"
        };
        witness.grid_fingerprint.replace_range(0..1, replacement);
        let corrupted = serde_json::to_string(&witness).unwrap();
        let err = replay_witness_json(&corrupted).unwrap_err();
        assert!(matches!(err, FulpReplayError::FingerprintMismatch { .. }));
    }

    #[test]
    fn fulp_oracle_replay_rejects_corrupt_stats() {
        let json = acceptance_witness_json().unwrap();
        let mut witness: FulpWitness = serde_json::from_str(&json).unwrap();
        witness.stats[0].max_ulp += ULP_TOLERANCE_FP16 + 1;
        let corrupted = serde_json::to_string(&witness).unwrap();
        let err = replay_witness_json(&corrupted).unwrap_err();
        assert_eq!(err, FulpReplayError::StatsMismatch);
    }

    #[test]
    fn fulp_oracle_replay_rejects_unsupported_evaluator_variant() {
        let json = acceptance_witness_json().unwrap();
        let mut witness: FulpWitness = serde_json::from_str(&json).unwrap();
        witness.evaluator_variant = "metal_capture_v1".to_string();
        let corrupted = serde_json::to_string(&witness).unwrap();
        let err = replay_witness_json(&corrupted).unwrap_err();
        assert_eq!(
            err,
            FulpReplayError::UnsupportedEvaluator("metal_capture_v1".to_string())
        );
    }

    #[test]
    fn fulp_oracle_rejects_invalid_acceptance_grid_counts() {
        let err = run_fulp_oracle(
            FulpRunConfig {
                stratified_points: STRATIFIED_POINT_COUNT - 1,
                adversarial_points: ADVERSARIAL_POINT_COUNT,
                ulp_tolerance: ULP_TOLERANCE_FP16,
            },
            &ReferenceRoundedKernel,
        )
        .unwrap_err();
        assert!(matches!(err, FulpOracleError::InvalidGridCount { .. }));
    }

    #[test]
    fn fulp_oracle_rejects_nan_candidate_bits() {
        struct NanKernel;

        impl FulpEvaluator for NanKernel {
            fn variant_name(&self) -> &'static str {
                "nan_kernel"
            }

            fn evaluate(
                &self,
                _operation: FulpOperation,
                _point: FulpPoint,
            ) -> Result<Fp16Bits, FulpOracleError> {
                Ok(Fp16Bits::from_f64(f64::NAN))
            }
        }

        let err = run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &NanKernel).unwrap_err();
        assert!(matches!(err, FulpOracleError::NanCandidate { .. }));
    }
}
