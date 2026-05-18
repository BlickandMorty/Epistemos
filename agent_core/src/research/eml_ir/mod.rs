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
    fixture_input, log_sampled_input, stress_input, FixtureInput, FixtureKind, StressAxis,
    CLOSED_INTERVAL_MAX, CLOSED_INTERVAL_MIN, LOG_SAMPLED_POINT_COUNT, STRESS_POINT_COUNT,
    TOTAL_FIXTURE_COUNT,
};
pub use fp16::{Fp16Bits, Fp16Class};
pub use oracle::{
    reference_value, run_fulp_oracle, CpuFloatIntrinsicEvaluator, FulpEvaluator, FulpOperation,
    FulpOracleError, FulpRunConfig, OperationStats, ReferenceRoundedEvaluator, WorstCase,
    ULP_TOLERANCE_FP16,
};
pub use witness::{
    acceptance_witness_json, replay_witness_json, FulpReplayError, FulpWitness, HardwarePin,
};

#[cfg(test)]
mod tests {
    const MORPH_SHADER_SOURCE: &str =
        include_str!("../../../../Epistemos/Shaders/morph_eval_reduced.metal");

    #[test]
    fn morph_eval_reduced_exports_combined_oracle_kernel() {
        assert!(
            MORPH_SHADER_SOURCE.contains("kernel void morphOracleFp16"),
            "morph_eval_reduced.metal must expose the combined T12 oracle kernel"
        );
    }
}
