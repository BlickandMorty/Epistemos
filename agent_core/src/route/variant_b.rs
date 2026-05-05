use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::grammar::{schema_to_llg, GrammarError};

use super::{Action, RouteDecision, VARIANT_B_FLOOR};

const INBOX_PREFIX: &str = "_inbox/";
const NEW_SENTINEL: &str = "NEW";
const DEFER_SENTINEL: &str = "DEFER";

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct VariantBOutput {
    pub path: String,
    pub confidence: f64,
    #[serde(default)]
    pub rationale: String,
}

#[async_trait]
pub trait LlmClassifier: Send + Sync {
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

fn allowed_route_paths(vault_tree_paths: &[String]) -> Vec<String> {
    let mut allowed = vault_tree_paths
        .iter()
        .filter(|path| !path.starts_with(INBOX_PREFIX))
        .cloned()
        .collect::<Vec<_>>();
    allowed.sort();
    allowed.dedup();
    allowed
}

pub fn build_route_grammar_schema(allowed_paths: &[String]) -> Value {
    let mut options = allowed_route_paths(allowed_paths)
        .into_iter()
        .map(|path| json!(path))
        .collect::<Vec<_>>();
    options.push(json!(NEW_SENTINEL));
    options.push(json!(DEFER_SENTINEL));

    json!({
        "type": "object",
        "required": ["path", "confidence"],
        "additionalProperties": false,
        "properties": {
            "path": { "enum": options },
            "confidence": { "type": "number", "minimum": 0, "maximum": 1 },
            "rationale": { "type": "string", "maxLength": 200 }
        }
    })
}

pub fn compile_route_grammar(
    allowed_paths: &[String],
) -> Result<llguidance::api::TopLevelGrammar, GrammarError> {
    schema_to_llg(&build_route_grammar_schema(allowed_paths))
}

pub async fn try_llm_classify(
    capture_text: &str,
    vault_tree_paths: &[String],
    classifier: &dyn LlmClassifier,
) -> Option<RouteDecision> {
    if capture_text.trim().is_empty() || vault_tree_paths.is_empty() {
        return None;
    }

    let allowed = allowed_route_paths(vault_tree_paths);
    if allowed.is_empty() {
        return None;
    }

    let output = classifier.classify(capture_text, &allowed).await.ok()?;
    match output.path.as_str() {
        NEW_SENTINEL => None,
        DEFER_SENTINEL => Some(RouteDecision::defer(
            format!(
                "variant_b model_self_defer (conf {:.3}, {})",
                output.confidence, output.rationale
            ),
            Vec::new(),
        )),
        _ if output.confidence < VARIANT_B_FLOOR => None,
        _ if !allowed.iter().any(|path| path == &output.path) => None,
        _ => Some(RouteDecision {
            action: Action::Place,
            folder_path: Some(output.path),
            target_note_path: None,
            new_folder_name: None,
            confidence: output.confidence,
            reasoning_trace: if output.rationale.is_empty() {
                format!(
                    "variant_b llm_classify confidence {:.3} >= floor {:.2}",
                    output.confidence, VARIANT_B_FLOOR
                )
            } else {
                format!(
                    "variant_b conf {:.3}: {}",
                    output.confidence, output.rationale
                )
            },
            alternative_paths: Vec::new(),
        }),
    }
}
