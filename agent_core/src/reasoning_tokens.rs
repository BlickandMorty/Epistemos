//! Reasoning-token isolation — Deterministic Schema Engine, P8.2 spec §B
//! (docs/DETERMINISTIC_SCHEMA_ENGINE_SPEC_2026_06_18.md).
//!
//! A local model's raw output is split into its REASONING TRACE and the clean ANSWER /
//! tool-args for execution. Per the honesty constraint, the thinking is NEVER stripped
//! — it is SEPARATED (preserved for UI tracing) while the answer is extracted cleanly.
//!
//! This is the Rust-core primitive for the GGUF / schema-engine path (Swift's
//! MLXInferenceBridge handles the MLX-Swift path separately; this does not touch it).
//! Pure + deterministic + unit-tested. Handles the marker formats used in-tree: Qwen-
//! style `<think>…</think>` and Gemma's `[Start thinking]…[End thinking]`.

/// Known reasoning-marker pairs across the local models in this product.
const MARKER_PAIRS: &[(&str, &str)] = &[
    ("<think>", "</think>"),
    ("[Start thinking]", "[End thinking]"),
];

/// A raw local-model output split into its preserved reasoning trace + the clean answer.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReasoningSplit {
    /// The reasoning trace, PRESERVED (never stripped). `None` if the output had none.
    pub thinking: Option<String>,
    /// The clean answer / tool-args, with the reasoning region removed.
    pub answer: String,
}

/// Split a raw output into its (preserved) reasoning trace + the clean answer.
///
/// - A complete `<open>…<close>` block → `thinking` = the inner trace, `answer` = the
///   text outside the block (the common "think first, then answer" shape gives a clean
///   answer with no markers).
/// - An UNCLOSED opening marker (mid-stream) → everything after it is the in-progress
///   `thinking`; `answer` is whatever preceded it.
/// - No marker → `thinking` is `None`, `answer` is the trimmed raw text.
pub fn split_reasoning(raw: &str) -> ReasoningSplit {
    for (open, close) in MARKER_PAIRS {
        let Some(open_idx) = raw.find(open) else { continue };
        let after_open = open_idx + open.len();

        if let Some(rel_close) = raw[after_open..].find(close) {
            let close_idx = after_open + rel_close;
            let thinking = raw[after_open..close_idx].trim().to_string();
            let before = &raw[..open_idx];
            let after = &raw[close_idx + close.len()..];
            return ReasoningSplit {
                thinking: non_empty(thinking),
                answer: format!("{before}{after}").trim().to_string(),
            };
        }

        // Opening marker but no close yet (streaming): the rest is thinking-in-progress.
        let thinking = raw[after_open..].trim().to_string();
        return ReasoningSplit {
            thinking: non_empty(thinking),
            answer: raw[..open_idx].trim().to_string(),
        };
    }

    ReasoningSplit {
        thinking: None,
        answer: raw.trim().to_string(),
    }
}

fn non_empty(s: String) -> Option<String> {
    if s.is_empty() {
        None
    } else {
        Some(s)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_a_closed_qwen_style_block() {
        let split = split_reasoning("<think>weigh the options</think>The answer is 42.");
        assert_eq!(split.thinking.as_deref(), Some("weigh the options"));
        assert_eq!(split.answer, "The answer is 42.");
    }

    #[test]
    fn splits_a_closed_gemma_block() {
        let split = split_reasoning("[Start thinking]plan the steps[End thinking]\nHere you go.");
        assert_eq!(split.thinking.as_deref(), Some("plan the steps"));
        assert_eq!(split.answer, "Here you go.");
    }

    #[test]
    fn preserves_thinking_never_strips_it() {
        // The honesty constraint: the reasoning is returned, not discarded.
        let raw = "<think>secret chain of thought</think>ok";
        let split = split_reasoning(raw);
        assert!(split.thinking.is_some());
        assert!(split.thinking.unwrap().contains("secret chain of thought"));
    }

    #[test]
    fn no_marker_returns_whole_text_as_answer() {
        let split = split_reasoning("  just a plain answer  ");
        assert_eq!(split.thinking, None);
        assert_eq!(split.answer, "just a plain answer");
    }

    #[test]
    fn unclosed_marker_treats_rest_as_in_progress_thinking() {
        let split = split_reasoning("<think>still reasoning and not done");
        assert_eq!(split.thinking.as_deref(), Some("still reasoning and not done"));
        assert_eq!(split.answer, "");
    }

    #[test]
    fn empty_thinking_block_is_none() {
        let split = split_reasoning("<think></think>answer only");
        assert_eq!(split.thinking, None);
        assert_eq!(split.answer, "answer only");
    }
}
