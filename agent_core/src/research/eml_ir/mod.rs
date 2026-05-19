//! Source:
//! - `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T12.
//! - `docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md` §3.5.
//! - `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` rows B2-B3.
//!
//! Research-only EML-IR arithmetic floor for the F-ULP-Oracle gate.

mod fixtures;
mod fp16;
mod oracle;
mod witness;

pub use fixtures::{
    adversarial_fixture, fixture_input, log_sampled_input, stress_input, AdversarialFixture,
    AdversarialOperation, FixtureInput, FixtureKind, StressAxis, ADVERSARIAL_FIXTURE_COUNT,
    CLOSED_INTERVAL_MAX, CLOSED_INTERVAL_MIN, LOG_SAMPLED_POINT_COUNT, STRESS_POINT_COUNT,
    TOTAL_FIXTURE_COUNT,
};
pub use fp16::{Fp16Bits, Fp16Class};
pub use oracle::{
    adversarial_fixture_fingerprint, adversarial_fixture_label_fingerprint,
    adversarial_reference_fingerprint, axis_catalog_fingerprint, classify_ulp_gate,
    operation_catalog_fingerprint, reference_value, run_fulp_oracle, AdversarialReferenceStats,
    AxisStats, CpuFloatIntrinsicEvaluator, FulpEvaluator, FulpOperation, FulpOracleError,
    FulpRunConfig, OperationStats, ReferenceRoundedEvaluator, UlpGateTier, WorstCase,
    FALLBACK_ULP_TOLERANCE_FP16, FULP_BUDGET_TARGET_MILLIS, FULP_BUDGET_TARGET_SECONDS,
    ULP_TOLERANCE_FP16,
};
pub use witness::{
    acceptance_witness_json, replay_witness_json, FingerprintKind, FulpReplayError, FulpWitness,
    HardwarePin, FULP_WITNESS_SCHEMA_VERSION,
};

#[cfg(test)]
mod tests {
    const MORPH_SHADER_SOURCE: &str =
        include_str!("../../../../Epistemos/Shaders/morph_eval_reduced.metal");
    const FULP_FALSIFIER_DOC: &str =
        include_str!("../../../../docs/falsifiers/F_ULP_ORACLE_2026_05_18.md");

    #[test]
    fn morph_eval_reduced_exports_combined_oracle_kernel() {
        assert!(
            MORPH_SHADER_SOURCE.contains("kernel void morphOracleFp16"),
            "morph_eval_reduced.metal must expose the combined T12 oracle kernel"
        );
    }

    #[test]
    fn morph_oracle_kernel_abi_uses_float_inputs_and_half_outputs() {
        assert!(MORPH_SHADER_SOURCE.contains("device const float* x"));
        assert!(MORPH_SHADER_SOURCE.contains("device const float* y"));
        assert!(MORPH_SHADER_SOURCE.contains("device       half* expOut"));
        assert!(MORPH_SHADER_SOURCE.contains("device       half* lnOut"));
        assert!(MORPH_SHADER_SOURCE.contains("device       half* emlOut"));
    }

    #[test]
    fn morph_oracle_kernel_uses_fp32_intrinsics_then_half_rounding() {
        assert!(MORPH_SHADER_SOURCE.contains("float expValue = exp(x[gid]);"));
        assert!(MORPH_SHADER_SOURCE.contains("float lnValue = log(y[gid]);"));
        assert!(MORPH_SHADER_SOURCE.contains("expOut[gid] = half(expValue);"));
        assert!(MORPH_SHADER_SOURCE.contains("lnOut[gid] = half(lnValue);"));
        assert!(MORPH_SHADER_SOURCE.contains("emlOut[gid] = half(expValue - lnValue);"));
    }

    #[test]
    fn morph_oracle_kernel_has_no_clamp_or_masking_fallback() {
        assert!(!MORPH_SHADER_SOURCE.contains("clamp("));
        assert!(!MORPH_SHADER_SOURCE.contains("isnan"));
        assert!(!MORPH_SHADER_SOURCE.contains("isinf"));
        assert!(!MORPH_SHADER_SOURCE.contains("fallback"));
    }

    #[test]
    fn morph_oracle_shader_avoids_unverified_latency_claims() {
        assert!(!MORPH_SHADER_SOURCE.contains("1-cycle"));
    }

    #[test]
    fn falsifier_doc_points_at_eml_ir_lane_and_shader() {
        assert!(FULP_FALSIFIER_DOC.contains("agent_core/src/research/eml_ir/"));
        assert!(FULP_FALSIFIER_DOC.contains("Epistemos/Shaders/morph_eval_reduced.metal"));
    }

    #[test]
    fn falsifier_doc_documents_apple_msl_spec_posture() {
        assert!(FULP_FALSIFIER_DOC.contains("## Apple MSL Spec Posture"));
        assert!(FULP_FALSIFIER_DOC.contains("Apple Metal Shading Language §6.5.4"));
        assert!(FULP_FALSIFIER_DOC.contains("unverified"));
        assert!(FULP_FALSIFIER_DOC.contains("`morphOracleFp16`"));
        assert!(FULP_FALSIFIER_DOC
            .contains("the floor of what the kernel can\nachieve, not the ceiling"));
    }

    #[test]
    fn falsifier_doc_documents_fp16_bit_pattern_pin() {
        assert!(FULP_FALSIFIER_DOC.contains("## Fp16 Bit Pattern Pin"));
        assert!(FULP_FALSIFIER_DOC.contains("`Fp16Bits`"));
        assert!(FULP_FALSIFIER_DOC.contains("`u16` binary16"));
        assert!(FULP_FALSIFIER_DOC.contains("round-to-nearest-even"));
        assert!(FULP_FALSIFIER_DOC.contains("`Zero`"));
        assert!(FULP_FALSIFIER_DOC.contains("`Subnormal`"));
        assert!(FULP_FALSIFIER_DOC.contains("`Normal`"));
        assert!(FULP_FALSIFIER_DOC.contains("`Infinity`"));
        assert!(FULP_FALSIFIER_DOC.contains("`Nan`"));
    }

    #[test]
    fn falsifier_doc_documents_closed_interval_semantics() {
        assert!(FULP_FALSIFIER_DOC.contains("## Closed Interval Semantics"));
        assert!(FULP_FALSIFIER_DOC.contains("closed at both endpoints"));
        assert!(FULP_FALSIFIER_DOC.contains("first input to `0.5`"));
        assert!(FULP_FALSIFIER_DOC.contains("last input to `2`"));
        assert!(FULP_FALSIFIER_DOC.contains("`0x3800`"));
        assert!(FULP_FALSIFIER_DOC.contains("`0x4000`"));
        assert!(FULP_FALSIFIER_DOC.contains("`± 1 ULP`"));
    }

    #[test]
    fn falsifier_doc_documents_mission_identity_pin() {
        assert!(FULP_FALSIFIER_DOC.contains("## Mission Identity Pin"));
        assert!(FULP_FALSIFIER_DOC.contains("`mission` field"));
        assert!(FULP_FALSIFIER_DOC.contains("`F-ULP-Oracle T12`"));
        assert!(FULP_FALSIFIER_DOC.contains("F-KV-Direct"));
        assert!(FULP_FALSIFIER_DOC.contains("F-70B-Cocktail"));
        assert!(FULP_FALSIFIER_DOC.contains("self-identifying"));
    }

    #[test]
    fn falsifier_doc_documents_pass_field_invariants() {
        assert!(FULP_FALSIFIER_DOC.contains("## Pass Field Invariants"));
        assert!(FULP_FALSIFIER_DOC.contains("`pass` field"));
        assert!(FULP_FALSIFIER_DOC.contains("`Primary` gate tier"));
        assert!(FULP_FALSIFIER_DOC.contains("recomputed verdict"));
        assert!(FULP_FALSIFIER_DOC.contains("`pass:\ntrue`"));
        assert!(FULP_FALSIFIER_DOC.contains("`pass: false`"));
    }

    #[test]
    fn falsifier_doc_documents_evaluator_variant_allowlist() {
        assert!(FULP_FALSIFIER_DOC.contains("## Evaluator Variant Allowlist"));
        assert!(FULP_FALSIFIER_DOC.contains("`evaluator_variant`"));
        assert!(FULP_FALSIFIER_DOC.contains("`cpu_float_intrinsic_morph_oracle_fp16_v1`"));
        assert!(FULP_FALSIFIER_DOC.contains("`ReferenceRoundedEvaluator`"));
        assert!(FULP_FALSIFIER_DOC.contains("self-referential loop"));
        assert!(FULP_FALSIFIER_DOC.contains("in lockstep with the\nschema version"));
    }

    #[test]
    fn falsifier_doc_documents_worst_case_witness_surface() {
        assert!(FULP_FALSIFIER_DOC.contains("## Worst-Case Witness Surface"));
        assert!(FULP_FALSIFIER_DOC.contains("`WorstCase`"));
        assert!(FULP_FALSIFIER_DOC.contains("candidate fp16 output"));
        assert!(FULP_FALSIFIER_DOC.contains("reference fp16 output"));
        assert!(FULP_FALSIFIER_DOC.contains("stress axis"));
        assert!(FULP_FALSIFIER_DOC.contains("gate tier the worst case mapped to"));
        assert!(FULP_FALSIFIER_DOC.contains("no hidden state"));
    }

    #[test]
    fn falsifier_doc_documents_adversarial_reference_stats() {
        assert!(FULP_FALSIFIER_DOC.contains("## Adversarial Reference Stats"));
        assert!(FULP_FALSIFIER_DOC.contains("`adversarial_reference_stats`"));
        assert!(FULP_FALSIFIER_DOC.contains("`finite_count = 12`"));
        assert!(FULP_FALSIFIER_DOC.contains("`rejected_count = 11`"));
        assert!(FULP_FALSIFIER_DOC.contains("collapse the rejected-by-IEEE"));
        assert!(FULP_FALSIFIER_DOC.contains("part of the\nfingerprint chain"));
    }

    #[test]
    fn falsifier_doc_documents_scope_lock_and_frozen_terminals() {
        assert!(FULP_FALSIFIER_DOC.contains("## Scope Lock and Frozen Terminals"));
        assert!(FULP_FALSIFIER_DOC.contains("`agent_core/src/research/operator_ir/`"));
        assert!(FULP_FALSIFIER_DOC.contains("`agent_core/src/research/scan_ir/`"));
        assert!(FULP_FALSIFIER_DOC.contains("`agent_core/src/research/tropical_ir/`"));
        assert!(FULP_FALSIFIER_DOC.contains("`agent_core/src/lattice_wbo/`"));
        assert!(FULP_FALSIFIER_DOC.contains("`agent_core/src/acs_admission/`"));
        assert!(FULP_FALSIFIER_DOC.contains("must be reverted"));
    }

    #[test]
    fn falsifier_doc_documents_fixture_fingerprint_chain() {
        assert!(FULP_FALSIFIER_DOC.contains("## Fixture Fingerprint Chain"));
        assert!(FULP_FALSIFIER_DOC.contains("SHA-256"));
        assert!(FULP_FALSIFIER_DOC.contains("`operation_catalog_fingerprint`"));
        assert!(FULP_FALSIFIER_DOC.contains("`axis_catalog_fingerprint`"));
        assert!(FULP_FALSIFIER_DOC.contains("`grid_fingerprint`"));
        assert!(FULP_FALSIFIER_DOC.contains("`adversarial_fixture_fingerprint`"));
        assert!(FULP_FALSIFIER_DOC.contains("`adversarial_reference_fingerprint`"));
        assert!(FULP_FALSIFIER_DOC.contains("`shader_fingerprint`"));
    }

    #[test]
    fn falsifier_doc_documents_witness_schema_version_gate() {
        assert!(FULP_FALSIFIER_DOC.contains("## Witness Schema Version"));
        assert!(FULP_FALSIFIER_DOC.contains("`schema_version = 12`"));
        assert!(FULP_FALSIFIER_DOC.contains("`FULP_WITNESS_SCHEMA_VERSION`"));
        assert!(FULP_FALSIFIER_DOC.contains("before any\nfingerprint check"));
        assert!(FULP_FALSIFIER_DOC.contains("fast-forward the schema"));
    }

    #[test]
    fn falsifier_doc_documents_live_metal_dispatch_capture_deferred() {
        assert!(FULP_FALSIFIER_DOC.contains("## Live Metal Dispatch Capture (Deferred)"));
        assert!(FULP_FALSIFIER_DOC.contains("does not execute the Metal"));
        assert!(FULP_FALSIFIER_DOC.contains("deferred until the GPU evidence harness"));
        assert!(FULP_FALSIFIER_DOC.contains("the surrogate is the floor, not the ceiling"));
    }

    #[test]
    fn falsifier_doc_documents_per_axis_regression_detection() {
        assert!(FULP_FALSIFIER_DOC.contains("## Per-Axis Regression Detection"));
        assert!(FULP_FALSIFIER_DOC.contains("`OperationStats`"));
        assert!(FULP_FALSIFIER_DOC.contains("`log_sampled`"));
        assert!(FULP_FALSIFIER_DOC.contains("per-axis max-ULP"));
        assert!(FULP_FALSIFIER_DOC.contains("per-axis mean-ULP"));
        assert!(FULP_FALSIFIER_DOC.contains("hides a regression"));
    }

    #[test]
    fn falsifier_doc_documents_replay_corruption_rejection() {
        assert!(FULP_FALSIFIER_DOC.contains("## Replay Corruption Rejection"));
        assert!(FULP_FALSIFIER_DOC.contains("`replay_witness_json`"));
        assert!(FULP_FALSIFIER_DOC.contains("`FulpWitness`"));
        assert!(FULP_FALSIFIER_DOC.contains("duplicate top-level key"));
        assert!(FULP_FALSIFIER_DOC.contains("unknown top-level field"));
        assert!(FULP_FALSIFIER_DOC.contains("type mismatch"));
        assert!(FULP_FALSIFIER_DOC.contains("out-of-range unsigned integer"));
        assert!(FULP_FALSIFIER_DOC.contains("`FulpReplayError`"));
        assert!(FULP_FALSIFIER_DOC.contains("corruption-after-emit attack"));
    }

    #[test]
    fn falsifier_doc_documents_wall_clock_budget() {
        assert!(FULP_FALSIFIER_DOC.contains("## Wall-Clock Budget"));
        assert!(FULP_FALSIFIER_DOC.contains("`budget_target_seconds = 90`"));
        assert!(FULP_FALSIFIER_DOC.contains("`budget_target_millis = 90,000`"));
        assert!(FULP_FALSIFIER_DOC.contains("`observed_wall_clock_millis`"));
        assert!(FULP_FALSIFIER_DOC.contains("`budget_mismatch_kind`"));
    }

    #[test]
    fn falsifier_doc_documents_hardware_identifier_exclusion() {
        assert!(FULP_FALSIFIER_DOC.contains("## Hardware Identifier Exclusion"));
        assert!(FULP_FALSIFIER_DOC.contains("serial number"));
        assert!(FULP_FALSIFIER_DOC.contains("software UUID"));
        assert!(FULP_FALSIFIER_DOC.contains("hardware UUID"));
        assert!(FULP_FALSIFIER_DOC.contains("ECID"));
        assert!(FULP_FALSIFIER_DOC.contains("`hwid`"));
        assert!(FULP_FALSIFIER_DOC.contains("board id"));
        assert!(FULP_FALSIFIER_DOC.contains("`ioplatform`"));
        assert!(FULP_FALSIFIER_DOC.contains("IMEI"));
        assert!(FULP_FALSIFIER_DOC.contains("MEID"));
        assert!(FULP_FALSIFIER_DOC.contains("UDID"));
        assert!(FULP_FALSIFIER_DOC.contains("IDFA"));
        assert!(FULP_FALSIFIER_DOC.contains("IDFV"));
        assert!(FULP_FALSIFIER_DOC.contains("host id"));
        assert!(FULP_FALSIFIER_DOC.contains("Apple chip id"));
        assert!(FULP_FALSIFIER_DOC.contains("Apple boot nonce"));
        assert!(FULP_FALSIFIER_DOC.contains("provisioning enrollment id"));
        assert!(FULP_FALSIFIER_DOC.contains("ethernet MAC-shaped"));
    }

    #[test]
    fn falsifier_doc_documents_reference_methodology() {
        assert!(FULP_FALSIFIER_DOC.contains("## Reference Methodology"));
        assert!(FULP_FALSIFIER_DOC.contains("`f64::exp(x) - f64::ln(y)` rounded"));
        assert!(FULP_FALSIFIER_DOC.contains("never recomputed in fp32"));
        assert!(FULP_FALSIFIER_DOC.contains("`cpu_float_intrinsic_morph_oracle_fp16_v1`"));
        assert!(FULP_FALSIFIER_DOC.contains("smuggled in as its own"));
    }

    #[test]
    fn falsifier_doc_documents_ulp_gate_tier_ladder() {
        assert!(FULP_FALSIFIER_DOC.contains("## ULP Gate Tier Ladder"));
        assert!(FULP_FALSIFIER_DOC.contains("`Primary`"));
        assert!(FULP_FALSIFIER_DOC.contains("`Fallback`"));
        assert!(FULP_FALSIFIER_DOC.contains("`Fail`"));
        assert!(FULP_FALSIFIER_DOC.contains("max-ULP `<= 2`"));
        assert!(FULP_FALSIFIER_DOC.contains("max-ULP in `[3, 4]`"));
        assert!(FULP_FALSIFIER_DOC.contains("max-ULP `>= 5`"));
    }

    #[test]
    fn falsifier_doc_documents_adversarial_fixture_purposes() {
        assert!(FULP_FALSIFIER_DOC.contains("## Adversarial Fixture Purposes"));
        assert!(FULP_FALSIFIER_DOC.contains("`exp_positive_zero`"));
        assert!(FULP_FALSIFIER_DOC.contains("`ln_negative_zero`"));
        assert!(FULP_FALSIFIER_DOC.contains("`ln_negative_one`"));
        assert!(FULP_FALSIFIER_DOC.contains("`ln_fp16_min_positive_subnormal`"));
        assert!(FULP_FALSIFIER_DOC.contains("`ln_fp16_min_negative_subnormal`"));
        assert!(FULP_FALSIFIER_DOC.contains("`nan_payload_x`"));
        assert!(FULP_FALSIFIER_DOC.contains("`positive_infinity_y`"));
        assert!(FULP_FALSIFIER_DOC.contains("`eml_fp16_max_positive_subnormal`"));
        assert!(FULP_FALSIFIER_DOC.contains("`ln_one_exact_zero`"));
    }

    #[test]
    fn falsifier_doc_documents_stress_fixture_axes() {
        assert!(FULP_FALSIFIER_DOC.contains("## Stress Fixture Axes"));
        assert!(FULP_FALSIFIER_DOC.contains("`log_sampled`"));
        assert!(FULP_FALSIFIER_DOC.contains("`closed_interval_edge`"));
        assert!(FULP_FALSIFIER_DOC.contains("`exp_output_midpoint`"));
        assert!(FULP_FALSIFIER_DOC.contains("`ln_output_midpoint`"));
        assert!(FULP_FALSIFIER_DOC.contains("`eml_cross_midpoint`"));
    }

    #[test]
    fn falsifier_doc_links_numerics_budget_sources() {
        assert!(FULP_FALSIFIER_DOC.contains("T_num"));
        assert!(FULP_FALSIFIER_DOC.contains("WBO-7 Master Inequality"));
        assert!(FULP_FALSIFIER_DOC.contains("E4 UST-1.5"));
        assert!(FULP_FALSIFIER_DOC.contains("HELIOS_V5_DOC_6_THEOREM_CANON.md"));
        assert!(FULP_FALSIFIER_DOC.contains("F1/F7a"));
        assert!(FULP_FALSIFIER_DOC.contains("HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md"));
        assert!(FULP_FALSIFIER_DOC.contains("Helios v3 §3.5"));
    }

    #[test]
    fn falsifier_doc_records_replay_schema_and_shader_fingerprint() {
        assert!(FULP_FALSIFIER_DOC.contains("schema_version = 12"));
        assert!(FULP_FALSIFIER_DOC.contains("cpu_float_intrinsic_morph_oracle_fp16_v1"));
        assert!(FULP_FALSIFIER_DOC.contains("shader_fingerprint"));
        assert!(FULP_FALSIFIER_DOC.contains("operation_catalog_fingerprint"));
        assert!(FULP_FALSIFIER_DOC.contains("axis_catalog_fingerprint"));
        assert!(FULP_FALSIFIER_DOC.contains("adversarial_fixture_count = 23"));
        assert!(FULP_FALSIFIER_DOC.contains("adversarial_fixture_fingerprint"));
        assert!(FULP_FALSIFIER_DOC.contains("adversarial_reference_fingerprint"));
        assert!(FULP_FALSIFIER_DOC.contains("adversarial_reference_stats"));
        assert!(FULP_FALSIFIER_DOC.contains("finite_count = 12"));
        assert!(FULP_FALSIFIER_DOC.contains("rejected_count = 11"));
        assert!(FULP_FALSIFIER_DOC.contains("morphOracleFp16"));
        assert!(FULP_FALSIFIER_DOC
            .contains("4a83ee96a1dffd0251307ebca42c33eb8982992a641dd641c540fd560a42bdb3"));
        assert!(FULP_FALSIFIER_DOC
            .contains("ad8e99b40e8c673bb255cdc4dfa10905479e6d8b8a5c6f1ac47809e247b0bc37"));
        assert!(FULP_FALSIFIER_DOC
            .contains("f0c1ec3142aafa93170de35d02e561368206e745aad481f7e32d865c5ee71537"));
        assert!(FULP_FALSIFIER_DOC
            .contains("78c5d0adee288b449acebb9e16324e64e6c648ecc036a82df3bc3b5b06539339"));
        assert!(FULP_FALSIFIER_DOC
            .contains("5624f053ca313b514e32d2965434fe1a77cd1fcfaa13a0c58ebe18003c220db4"));
        assert!(FULP_FALSIFIER_DOC
            .contains("17f0b3f9de6cf7398e54c242397b833e88a8d39b5c1b07a99085cae5717ac871"));
    }
}
