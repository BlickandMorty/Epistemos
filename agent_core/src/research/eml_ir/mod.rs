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
    adversarial_fixture_fingerprint, adversarial_reference_fingerprint, classify_ulp_gate,
    reference_value, run_fulp_oracle, AxisStats, CpuFloatIntrinsicEvaluator, FulpEvaluator,
    FulpOperation, FulpOracleError, FulpRunConfig, OperationStats, ReferenceRoundedEvaluator,
    UlpGateTier, WorstCase, FALLBACK_ULP_TOLERANCE_FP16, ULP_TOLERANCE_FP16,
};
pub use witness::{
    acceptance_witness_json, replay_witness_json, FulpReplayError, FulpWitness, HardwarePin,
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
    fn falsifier_doc_links_numerics_budget_sources() {
        assert!(FULP_FALSIFIER_DOC.contains("T_num"));
        assert!(FULP_FALSIFIER_DOC.contains("HELIOS_V5_DOC_6_THEOREM_CANON.md"));
        assert!(FULP_FALSIFIER_DOC.contains("F1/F7a"));
        assert!(FULP_FALSIFIER_DOC.contains("HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md"));
        assert!(FULP_FALSIFIER_DOC.contains("Helios v3 §3.5"));
    }

    #[test]
    fn falsifier_doc_records_replay_schema_and_shader_fingerprint() {
        assert!(FULP_FALSIFIER_DOC.contains("schema_version = 8"));
        assert!(FULP_FALSIFIER_DOC.contains("cpu_float_intrinsic_morph_oracle_fp16_v1"));
        assert!(FULP_FALSIFIER_DOC.contains("shader_fingerprint"));
        assert!(FULP_FALSIFIER_DOC.contains("adversarial_fixture_fingerprint"));
        assert!(FULP_FALSIFIER_DOC.contains("adversarial_reference_fingerprint"));
        assert!(FULP_FALSIFIER_DOC.contains("morphOracleFp16"));
        assert!(FULP_FALSIFIER_DOC
            .contains("4a83ee96a1dffd0251307ebca42c33eb8982992a641dd641c540fd560a42bdb3"));
        assert!(FULP_FALSIFIER_DOC
            .contains("a7548c5410e0bb525dbe4bbf5c7a546a7ad59d35f672388db9e76259780419ed"));
        assert!(FULP_FALSIFIER_DOC
            .contains("991ab58926bc94a34fc0c97c56fdf991eb47f164dd8eb4ae736a793a5622cb8d"));
        assert!(FULP_FALSIFIER_DOC
            .contains("17f0b3f9de6cf7398e54c242397b833e88a8d39b5c1b07a99085cae5717ac871"));
    }
}
