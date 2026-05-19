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
        assert!(FULP_FALSIFIER_DOC.contains("adversarial_fixture_count = 20"));
        assert!(FULP_FALSIFIER_DOC.contains("adversarial_fixture_fingerprint"));
        assert!(FULP_FALSIFIER_DOC.contains("adversarial_reference_fingerprint"));
        assert!(FULP_FALSIFIER_DOC.contains("adversarial_reference_stats"));
        assert!(FULP_FALSIFIER_DOC.contains("finite_count = 12"));
        assert!(FULP_FALSIFIER_DOC.contains("rejected_count = 8"));
        assert!(FULP_FALSIFIER_DOC.contains("morphOracleFp16"));
        assert!(FULP_FALSIFIER_DOC
            .contains("4a83ee96a1dffd0251307ebca42c33eb8982992a641dd641c540fd560a42bdb3"));
        assert!(FULP_FALSIFIER_DOC
            .contains("ad8e99b40e8c673bb255cdc4dfa10905479e6d8b8a5c6f1ac47809e247b0bc37"));
        assert!(FULP_FALSIFIER_DOC
            .contains("f0c1ec3142aafa93170de35d02e561368206e745aad481f7e32d865c5ee71537"));
        assert!(FULP_FALSIFIER_DOC
            .contains("207fffdef0c46b4d25e2568c2b8681b757c458f4de7cfcf9f3ea9e0b41afad19"));
        assert!(FULP_FALSIFIER_DOC
            .contains("6a008162a85703828be3de70fd1268defeeb3ed44f389dc2bff034f0bf27d8c7"));
        assert!(FULP_FALSIFIER_DOC
            .contains("17f0b3f9de6cf7398e54c242397b833e88a8d39b5c1b07a99085cae5717ac871"));
    }
}
