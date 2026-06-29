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
        let Some(open_idx) = raw.find(open) else {
            continue;
        };
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

/// Whether the raw output is STILL inside a reasoning block — an opening marker with no
/// matching close yet — i.e. the model is mid-thinking. A streaming UI uses this to HOLD
/// the answer until the reasoning closes, so partial thinking never renders as the
/// answer. `false` once the block closes, or when there is no reasoning marker.
pub fn thinking_in_progress(raw: &str) -> bool {
    for (open, close) in MARKER_PAIRS {
        if let Some(open_idx) = raw.find(open) {
            let after_open = open_idx + open.len();
            return raw[after_open..].find(close).is_none();
        }
    }
    false
}

/// FFI: split a local model's raw output into its preserved reasoning trace + the clean
/// answer, for the Swift UI (the GGUF / schema-engine path — Swift's `MLXInferenceBridge`
/// MLX path is untouched). Returns a JSON envelope
/// `{"thinking": <string|null>, "answer": <string>, "thinking_in_progress": <bool>}` so a
/// streaming UI can render only the clean ANSWER, surface the reasoning separately, and
/// HOLD the answer while `thinking_in_progress` is true. The reasoning is PRESERVED (never
/// stripped) — `thinking` is `null` only when the output truly has none. This makes the
/// schema engine's reasoning-token isolation callable from Swift (the determinism surfaced
/// visibly); it does NOT alter any live path on its own. Pure — no fallback, no fabrication.
#[uniffi::export]
pub fn split_reasoning_json(raw: String) -> String {
    let split = split_reasoning(&raw);
    let in_progress = thinking_in_progress(&raw);
    let thinking_json = match &split.thinking {
        Some(t) => serde_json::to_string(t).unwrap_or_else(|_| "null".to_string()),
        None => "null".to_string(),
    };
    let answer_json = serde_json::to_string(&split.answer).unwrap_or_else(|_| "\"\"".to_string());
    format!("{{\"thinking\":{thinking_json},\"answer\":{answer_json},\"thinking_in_progress\":{in_progress}}}")
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
        assert_eq!(
            split.thinking.as_deref(),
            Some("still reasoning and not done")
        );
        assert_eq!(split.answer, "");
    }

    #[test]
    fn empty_thinking_block_is_none() {
        let split = split_reasoning("<think></think>answer only");
        assert_eq!(split.thinking, None);
        assert_eq!(split.answer, "answer only");
    }

    #[test]
    fn thinking_in_progress_true_for_an_unclosed_block() {
        assert!(thinking_in_progress("<think>still reasoning"));
        assert!(thinking_in_progress("[Start thinking]planning the steps"));
    }

    #[test]
    fn thinking_in_progress_false_when_closed_or_no_marker() {
        assert!(!thinking_in_progress("<think>done</think>the answer"));
        assert!(!thinking_in_progress("just a plain answer"));
        assert!(!thinking_in_progress(""));
    }

    #[test]
    fn split_never_fabricates_or_drops_content() {
        // Honesty invariant: both parts come FROM the raw (no fabrication) and the
        // reasoning is PRESERVED (not stripped).
        let raw = "<think>the secret reasoning</think>the final answer";
        let split = split_reasoning(raw);
        let thinking = split.thinking.expect("thinking present");
        assert!(raw.contains(&thinking)); // not fabricated
        assert!(raw.contains(&split.answer)); // not fabricated
        assert!(thinking.contains("secret reasoning")); // preserved, not stripped
        assert!(split.answer.contains("final answer"));
    }

    #[test]
    fn ffi_envelope_for_a_complete_block() {
        let out = split_reasoning_json("<think>reasoning here</think>the answer".to_string());
        assert!(out.contains("\"thinking\":\"reasoning here\""));
        assert!(out.contains("\"answer\":\"the answer\""));
        assert!(out.contains("\"thinking_in_progress\":false"));
    }

    #[test]
    fn ffi_envelope_holds_answer_while_thinking_in_progress() {
        // Unclosed marker (mid-stream) → in-progress true so the UI holds the answer.
        let out = split_reasoning_json("partial<think>still reasoning".to_string());
        assert!(out.contains("\"thinking_in_progress\":true"));
        assert!(out.contains("\"thinking\":\"still reasoning\""));
        assert!(out.contains("\"answer\":\"partial\""));
    }

    #[test]
    fn ffi_envelope_null_thinking_when_no_marker() {
        let out = split_reasoning_json("just a plain answer".to_string());
        assert!(out.contains("\"thinking\":null"));
        assert!(out.contains("\"answer\":\"just a plain answer\""));
        assert!(out.contains("\"thinking_in_progress\":false"));
    }

    #[test]
    fn ffi_envelope_is_valid_json_and_escapes_safely() {
        // Quotes + newlines in the content must not break the envelope.
        let out =
            split_reasoning_json("<think>a \"quoted\" thought</think>line1\nline2".to_string());
        let parsed: serde_json::Value = serde_json::from_str(&out).expect("envelope is valid JSON");
        assert_eq!(
            parsed["thinking"],
            serde_json::json!("a \"quoted\" thought")
        );
        assert_eq!(parsed["answer"], serde_json::json!("line1\nline2"));
        assert_eq!(parsed["thinking_in_progress"], serde_json::json!(false));
    }
}
