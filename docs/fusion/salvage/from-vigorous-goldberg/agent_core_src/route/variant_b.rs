//! Phase 3C — Variant B: GBNF-constrained LLM classification.
//!
//! Plan §4.4: threshold 0.75. Build a one-shot grammar from the current
//! vault tree where the model picks one of: an existing folder path
//! OR `"NEW"` (signals Variant C should run) OR `"DEFER"`. The grammar
//! IS the dispatch — sampler-bound decoding makes invalid output
//! structurally impossible (§17.3).
//!
//! Few-shot prompt MUST include a DEFER exemplar — without it small
//! models avoid the "boring" answer (plan §4.4 verbatim).
//!
//! This module ships the variant logic + threshold + grammar
//! construction. The actual LLM inference is abstracted behind the
//! `LlmClassifier` trait — Phase 6's MLX-Structured wiring plugs in
//! the real impl. Tests use `StubClassifier` to drive deterministic
//! threshold behavior.

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::grammar::{schema_to_llg, GrammarError};

use super::{RouteDecision, VARIANT_B_FLOOR};

const INBOX_PREFIX: &str = "_inbox/";
const NEW_SENTINEL: &str = "NEW";
const DEFER_SENTINEL: &str = "DEFER";

/// Variant B's structured output. The grammar enforces this shape at
/// the logit level (§17.3). `path` is either an existing folder, the
/// `NEW` sentinel (advances to Variant C concept-anchored), or the
/// `DEFER` sentinel (skip directly to Variant D).
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct VariantBOutput {
    pub path: String,
    pub confidence: f64,
    #[serde(default)]
    pub rationale: String,
}

#[async_trait]
pub trait LlmClassifier: Send + Sync {
    /// Run a grammar-constrained classification. The grammar is built
    /// from `allowed_paths + ["NEW", "DEFER"]` with `confidence` and
    /// `rationale` fields. Returns the parsed output or an error
    /// (which the caller treats as Variant B miss → advance).
    ///
    /// Plan §4.4 contract: Few-shot prompt MUST include a DEFER exemplar.
    async fn classify(
        &self,
        capture_text: &str,
        allowed_paths: &[String],
    ) -> Result<VariantBOutput, ClassifierError>;
}

#[derive(Debug, thiserror::Error)]
pub enum ClassifierError {
    #[error("inference failed: {0}")]
    Inference(String),
    #[error("grammar build failed: {0}")]
    Grammar(#[from] GrammarError),
    #[error("response parse failed: {0}")]
    Parse(String),
}

/// Plan §4.4 verbatim — grammar shape: closed enum over allowed paths
/// + NEW + DEFER. Phase 6's inference layer compiles this into an
/// llguidance grammar via Phase 2A's `schema_to_llg`. This function
/// returns the JSON-Schema *shape* used to compile the grammar, so
/// callers can pass it through the same path Variant A's centroid
/// rebuild uses for invariant testing.
pub fn build_route_grammar_schema(allowed_paths: &[String]) -> Value {
    let mut path_options: Vec<Value> = allowed_paths
        .iter()
        .filter(|p| !p.starts_with(INBOX_PREFIX))
        .map(|p| json!(p))
        .collect();
    path_options.push(json!(NEW_SENTINEL));
    path_options.push(json!(DEFER_SENTINEL));

    json!({
        "type": "object",
        "additionalProperties": false,
        "required": ["path", "confidence"],
        "properties": {
            "path": { "enum": path_options },
            "confidence": { "type": "number", "minimum": 0, "maximum": 1 },
            "rationale": { "type": "string", "maxLength": 200 }
        }
    })
}

/// Compile the route grammar from the vault tree. Returns a
/// `TopLevelGrammar` that the inference layer feeds to llguidance's
/// sampler — model literally cannot emit a path that isn't in the set.
pub fn compile_route_grammar(
    allowed_paths: &[String],
) -> Result<llguidance::api::TopLevelGrammar, GrammarError> {
    let schema = build_route_grammar_schema(allowed_paths);
    schema_to_llg(&schema)
}

/// Plan §4.4 — Variant B. Returns Some(RouteDecision::Place) when
/// confidence >= 0.75 AND the model chose an existing folder.
/// Returns Some(RouteDecision::Defer) when the model chose the DEFER
/// sentinel at any confidence (model self-deferral is a feature).
/// Returns None when the model chose NEW (advance to Variant C) OR
/// confidence is below floor.
pub async fn try_llm_classify(
    capture_text: &str,
    vault_tree_paths: &[String],
    classifier: &dyn LlmClassifier,
) -> Option<RouteDecision> {
    if capture_text.is_empty() || vault_tree_paths.is_empty() {
        return None;
    }
    // Filter _inbox/* before passing to the classifier — those are
    // never destinations.
    let allowed: Vec<String> = vault_tree_paths
        .iter()
        .filter(|p| !p.starts_with(INBOX_PREFIX))
        .cloned()
        .collect();
    if allowed.is_empty() {
        return None;
    }

    let output = classifier.classify(capture_text, &allowed).await.ok()?;

    if output.path == NEW_SENTINEL {
        // Advance to Variant C — concept-anchored may find a
        // create_folder candidate.
        return None;
    }
    if output.path == DEFER_SENTINEL {
        // Plan §4.4 + §4.6: model self-defer is a feature. Variant B
        // can decide to skip directly to D.
        return Some(RouteDecision::defer(
            format!(
                "variant_b model_self_defer (conf {:.3}, {})",
                output.confidence, output.rationale
            ),
            Vec::new(),
        ));
    }
    if output.confidence < VARIANT_B_FLOOR {
        return None;
    }

    let trace = if output.rationale.is_empty() {
        format!(
            "variant_b llm_classify confidence {:.3} >= floor {:.2}",
            output.confidence, VARIANT_B_FLOOR
        )
    } else {
        format!(
            "variant_b conf {:.3}: {}",
            output.confidence, output.rationale
        )
    };

    Some(RouteDecision {
        action: super::Action::Place,
        folder_path: Some(output.path),
        target_note_path: None,
        new_folder_name: None,
        confidence: output.confidence,
        reasoning_trace: truncate_trace(trace),
        alternative_paths: Vec::new(), // Variant B only emits a single choice
    })
}

fn truncate_trace(s: String) -> String {
    if s.chars().count() <= super::REASONING_TRACE_MAX_CHARS {
        s
    } else {
        s.chars().take(super::REASONING_TRACE_MAX_CHARS).collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::route::Action;
    use std::sync::Mutex;

    /// Stub classifier returning a preconfigured response. Tests use
    /// this to engineer specific threshold + sentinel behaviors.
    struct StubClassifier {
        response: Mutex<Result<VariantBOutput, ClassifierError>>,
    }

    impl StubClassifier {
        fn new(out: VariantBOutput) -> Self {
            Self {
                response: Mutex::new(Ok(out)),
            }
        }
        fn failing() -> Self {
            Self {
                response: Mutex::new(Err(ClassifierError::Inference(
                    "stubbed failure".into(),
                ))),
            }
        }
    }

    #[async_trait]
    impl LlmClassifier for StubClassifier {
        async fn classify(
            &self,
            _capture_text: &str,
            _allowed_paths: &[String],
        ) -> Result<VariantBOutput, ClassifierError> {
            // Note: returns the stored response by cloning the Ok or by
            // re-creating an Err — ClassifierError isn't Clone, so we
            // re-create on miss.
            let g = self.response.lock().unwrap();
            match &*g {
                Ok(o) => Ok(o.clone()),
                Err(_) => Err(ClassifierError::Inference("stubbed failure".into())),
            }
        }
    }

    fn vault() -> Vec<String> {
        vec![
            "research/ml".to_string(),
            "research/inference".to_string(),
            "engineering/ux".to_string(),
            "_inbox/raw".to_string(),
        ]
    }

    #[tokio::test]
    async fn returns_place_when_classifier_picks_folder_above_threshold() {
        let cls = StubClassifier::new(VariantBOutput {
            path: "research/ml".to_string(),
            confidence: 0.81,
            rationale: "matches ML topic exemplars".to_string(),
        });
        let r = try_llm_classify("a capture about ml", &vault(), &cls).await;
        let d = r.expect("0.81 >= 0.75 must place");
        assert_eq!(d.action, Action::Place);
        assert_eq!(d.folder_path.as_deref(), Some("research/ml"));
        assert_eq!(d.confidence, 0.81);
    }

    #[tokio::test]
    async fn returns_none_below_threshold() {
        let cls = StubClassifier::new(VariantBOutput {
            path: "research/ml".to_string(),
            confidence: 0.50,
            rationale: "uncertain".to_string(),
        });
        let r = try_llm_classify("ambiguous capture", &vault(), &cls).await;
        assert!(r.is_none(), "0.50 < 0.75 must return None");
    }

    #[tokio::test]
    async fn returns_none_when_classifier_picks_new_sentinel() {
        let cls = StubClassifier::new(VariantBOutput {
            path: "NEW".to_string(),
            confidence: 0.95,
            rationale: "novel concept".to_string(),
        });
        let r = try_llm_classify("genuinely new idea", &vault(), &cls).await;
        // NEW → orchestrator advances to Variant C concept-anchored.
        assert!(r.is_none());
    }

    #[tokio::test]
    async fn returns_defer_when_classifier_picks_defer_sentinel() {
        let cls = StubClassifier::new(VariantBOutput {
            path: "DEFER".to_string(),
            confidence: 0.30,
            rationale: "ambiguous between projects/x and engineering/ux".to_string(),
        });
        let r = try_llm_classify("thinking about review queue", &vault(), &cls).await;
        let d = r.expect("DEFER sentinel produces a Defer decision");
        assert_eq!(d.action, Action::Defer);
        assert!(d.reasoning_trace.contains("model_self_defer"));
    }

    #[tokio::test]
    async fn returns_none_on_classifier_error() {
        let cls = StubClassifier::failing();
        let r = try_llm_classify("anything", &vault(), &cls).await;
        assert!(r.is_none(), "classifier failures advance to next variant");
    }

    #[tokio::test]
    async fn empty_capture_returns_none() {
        let cls = StubClassifier::new(VariantBOutput {
            path: "research/ml".into(),
            confidence: 0.99,
            rationale: "x".into(),
        });
        assert!(try_llm_classify("", &vault(), &cls).await.is_none());
    }

    #[tokio::test]
    async fn empty_vault_tree_returns_none() {
        let cls = StubClassifier::new(VariantBOutput {
            path: "research/ml".into(),
            confidence: 0.99,
            rationale: "x".into(),
        });
        assert!(try_llm_classify("x", &[], &cls).await.is_none());
    }

    #[tokio::test]
    async fn vault_tree_with_only_inbox_filters_to_empty_returns_none() {
        let cls = StubClassifier::new(VariantBOutput {
            path: "research/ml".into(),
            confidence: 0.99,
            rationale: "x".into(),
        });
        let inbox_only = vec!["_inbox/raw".to_string(), "_inbox/review".to_string()];
        assert!(try_llm_classify("x", &inbox_only, &cls).await.is_none());
    }

    #[test]
    fn grammar_schema_includes_allowed_paths_plus_sentinels() {
        let schema = build_route_grammar_schema(&[
            "research/ml".to_string(),
            "engineering".to_string(),
            "_inbox/raw".to_string(),
        ]);
        let path_enum = schema["properties"]["path"]["enum"].as_array().unwrap();
        let names: Vec<&str> = path_enum.iter().filter_map(|v| v.as_str()).collect();
        assert!(names.contains(&"research/ml"));
        assert!(names.contains(&"engineering"));
        assert!(!names.contains(&"_inbox/raw"), "_inbox/* filtered before grammar");
        assert!(names.contains(&"NEW"));
        assert!(names.contains(&"DEFER"));
    }

    #[test]
    fn grammar_schema_compiles_via_phase_2a_compiler() {
        let g = compile_route_grammar(&["research/ml".to_string(), "notes".to_string()]);
        g.expect("variant B grammar must compile via llguidance");
    }

    #[test]
    fn grammar_schema_has_additional_properties_false() {
        let schema = build_route_grammar_schema(&["x".to_string()]);
        assert_eq!(schema["additionalProperties"], json!(false));
    }

    #[test]
    fn grammar_schema_has_confidence_range_and_rationale_max_length() {
        let schema = build_route_grammar_schema(&["x".to_string()]);
        assert_eq!(schema["properties"]["confidence"]["minimum"], json!(0));
        assert_eq!(schema["properties"]["confidence"]["maximum"], json!(1));
        assert_eq!(schema["properties"]["rationale"]["maxLength"], json!(200));
    }

    #[tokio::test]
    async fn place_reasoning_trace_within_280_char_cap() {
        let cls = StubClassifier::new(VariantBOutput {
            path: "research/ml".to_string(),
            confidence: 0.85,
            rationale: "x".repeat(500),
        });
        let r = try_llm_classify("test", &vault(), &cls).await.unwrap();
        assert!(r.reasoning_trace.chars().count() <= super::super::REASONING_TRACE_MAX_CHARS);
    }
}
