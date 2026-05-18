//! Source:
//! - `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T12.
//! - `docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md` §3.5.
//! - `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` rows B2-B3.
//!
//! Research-only EML-IR arithmetic floor for the F-ULP-Oracle gate.

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
