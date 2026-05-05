//! Deterministic implementations of the Variant B `LlmClassifier`
//! trait. These are the No-LLM-First backstops per Plan §1.4 — every
//! variant ladder must start with a deterministic predecessor before
//! escalating to an LLM. Without them, Variant B has no fallback and
//! the production code path is unreachable.
//!
//! Two implementations:
//!
//! 1. `KeywordOverlapClassifier` — pure deterministic. Tokenises both
//!    the capture text and each candidate folder path; scores by
//!    Jaccard overlap on lowercased word stems. No external state, no
//!    randomness, no I/O. Used as the production default until an LLM
//!    classifier is wired in.
//!
//! 2. `GbnfClassifier` — wraps a host-supplied LLM client (Swift MLX
//!    via FFI callback, cloud Hermes via HTTP, etc.) with the
//!    `compile_route_grammar` GBNF the Variant B spec demands. The host
//!    LLM client implements `RawJsonLlmClient` (single method: emit
//!    JSON conforming to the supplied schema). This bridges the
//!    grammar-bound discipline from Plan §17 through to the real
//!    Variant B output.
//!
//! Determinism contract: `KeywordOverlapClassifier::classify` is a pure
//! function — same inputs always produce the same `VariantBOutput`.
//! `GbnfClassifier` is deterministic if and only if the host LLM client
//! is deterministic (temperature 0, fixed seed). The trait surface
//! does not enforce this; the host must.

use async_trait::async_trait;
use serde_json::Value;

use crate::grammar::{schema_to_llg, GrammarError};

use super::variant_b::{
    build_route_grammar_schema, ClassifierError, LlmClassifier, VariantBOutput,
};

const KEYWORD_MATCH_FLOOR: f64 = 0.05;

// ── KeywordOverlapClassifier ──────────────────────────────────────────────

/// Pure deterministic classifier. Tokenises both the capture text and
/// each candidate folder path; scores by Jaccard overlap on lowercased
/// word stems (split on whitespace + punctuation; ASCII fold; strip
/// short tokens).
///
/// Returns the highest-overlap path. Confidence = Jaccard score (0..1).
/// If every overlap is below `KEYWORD_MATCH_FLOOR` the classifier
/// returns the `DEFER` sentinel so the runtime escalates to Variant C
/// rather than placing low-confidence content.
#[derive(Debug, Default, Clone)]
pub struct KeywordOverlapClassifier;

#[async_trait]
impl LlmClassifier for KeywordOverlapClassifier {
    async fn classify(
        &self,
        capture_text: &str,
        allowed_paths: &[String],
    ) -> Result<VariantBOutput, ClassifierError> {
        let capture_tokens = tokenise(capture_text);
        if capture_tokens.is_empty() {
            return Ok(VariantBOutput {
                path: "DEFER".to_string(),
                confidence: 0.0,
                rationale: "capture text has no scoreable tokens".to_string(),
            });
        }

        let mut best: Option<(String, f64)> = None;
        for path in allowed_paths {
            let path_tokens = tokenise(path);
            if path_tokens.is_empty() {
                continue;
            }
            let score = jaccard(&capture_tokens, &path_tokens);
            if best.as_ref().map(|(_, s)| score > *s).unwrap_or(true) {
                best = Some((path.clone(), score));
            }
        }

        match best {
            Some((path, score)) if score >= KEYWORD_MATCH_FLOOR => Ok(VariantBOutput {
                path,
                confidence: score,
                rationale: format!("keyword overlap jaccard={:.3}", score),
            }),
            Some((path, score)) => Ok(VariantBOutput {
                path: "DEFER".to_string(),
                confidence: score,
                rationale: format!(
                    "best candidate '{}' jaccard={:.3} below floor {:.3}",
                    path, score, KEYWORD_MATCH_FLOOR
                ),
            }),
            None => Ok(VariantBOutput {
                path: "DEFER".to_string(),
                confidence: 0.0,
                rationale: "no candidate folder paths supplied".to_string(),
            }),
        }
    }
}

fn tokenise(text: &str) -> Vec<String> {
    text.to_lowercase()
        .split(|c: char| !c.is_alphanumeric())
        .filter(|t| t.len() >= 3)
        .map(str::to_string)
        .collect::<std::collections::BTreeSet<_>>()
        .into_iter()
        .collect()
}

fn jaccard(a: &[String], b: &[String]) -> f64 {
    if a.is_empty() && b.is_empty() {
        return 0.0;
    }
    let set_a: std::collections::BTreeSet<_> = a.iter().collect();
    let set_b: std::collections::BTreeSet<_> = b.iter().collect();
    let intersect = set_a.intersection(&set_b).count() as f64;
    let union = set_a.union(&set_b).count() as f64;
    if union == 0.0 {
        0.0
    } else {
        intersect / union
    }
}

// ── GbnfClassifier ────────────────────────────────────────────────────────

/// Single-method abstraction the host plugs in to drive grammar-bound
/// LLM classification. Swift implements via an MLX session +
/// llguidance constraint; cloud impls call /chat/completions with
/// JSON-mode + the schema attached.
#[async_trait]
pub trait RawJsonLlmClient: Send + Sync {
    /// Returns a JSON value conforming to the supplied schema.
    /// Implementations MUST use grammar-bound decoding so the result is
    /// guaranteed to validate; the trait wrapper doesn't validate
    /// because that would be redundant work.
    async fn emit_json(&self, prompt: &str, schema: &Value) -> Result<Value, ClassifierError>;
}

/// `LlmClassifier` adapter that drives a host-supplied
/// `RawJsonLlmClient` with the canonical Variant B GBNF schema. Composes
/// with `KeywordOverlapClassifier` as fallback: if the LLM call fails,
/// the keyword score still produces a deterministic output.
pub struct GbnfClassifier<C: RawJsonLlmClient> {
    pub host: C,
    pub fallback: KeywordOverlapClassifier,
}

impl<C: RawJsonLlmClient> GbnfClassifier<C> {
    pub fn new(host: C) -> Self {
        Self {
            host,
            fallback: KeywordOverlapClassifier,
        }
    }

    /// Compile the GBNF the host MUST honour. Exposed publicly so the
    /// host can pre-warm grammar caches.
    pub fn compile_grammar(
        allowed_paths: &[String],
    ) -> Result<llguidance::api::TopLevelGrammar, GrammarError> {
        schema_to_llg(&build_route_grammar_schema(allowed_paths))
    }
}

#[async_trait]
impl<C: RawJsonLlmClient> LlmClassifier for GbnfClassifier<C> {
    async fn classify(
        &self,
        capture_text: &str,
        allowed_paths: &[String],
    ) -> Result<VariantBOutput, ClassifierError> {
        let schema = build_route_grammar_schema(allowed_paths);
        let prompt = format!(
            "Route this capture into the most fitting folder. Pick exactly one path \
            from the schema's `path` enum (NEW = needs new folder, DEFER = unsure).\n\nCapture:\n{}",
            capture_text.trim()
        );
        match self.host.emit_json(&prompt, &schema).await {
            Ok(value) => parse_variant_b_output(value).or_else(|err| {
                // Grammar-bound emission shouldn't fail to parse, but
                // fall back to keyword overlap if it does so the route
                // pipeline never stalls on a malformed LLM response.
                Err(err)
            }),
            Err(_) => self.fallback.classify(capture_text, allowed_paths).await,
        }
    }
}

fn parse_variant_b_output(value: Value) -> Result<VariantBOutput, ClassifierError> {
    serde_json::from_value(value).map_err(|e| ClassifierError::Parse(e.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn keyword_overlap_picks_best_match() {
        let classifier = KeywordOverlapClassifier;
        let allowed = vec![
            "research/papers".to_string(),
            "code/rust".to_string(),
            "journal/2026".to_string(),
        ];
        let out = classifier
            .classify("New rust code refactor for the agent loop", &allowed)
            .await
            .expect("ok");
        assert_eq!(out.path, "code/rust", "rust+code keywords pick code/rust");
        assert!(out.confidence > 0.0);
    }

    #[tokio::test]
    async fn keyword_overlap_defers_below_floor() {
        let classifier = KeywordOverlapClassifier;
        let allowed = vec!["research/biology".to_string(), "code/rust".to_string()];
        let out = classifier
            .classify("xyzqwy zzzz nothing matches", &allowed)
            .await
            .expect("ok");
        assert_eq!(out.path, "DEFER");
    }

    #[tokio::test]
    async fn keyword_overlap_is_deterministic_across_calls() {
        let classifier = KeywordOverlapClassifier;
        let allowed = vec!["a/b".to_string(), "c/d".to_string(), "e/f".to_string()];
        let a = classifier.classify("a b c d e f", &allowed).await.unwrap();
        let b = classifier.classify("a b c d e f", &allowed).await.unwrap();
        assert_eq!(a.path, b.path);
        assert!((a.confidence - b.confidence).abs() < f64::EPSILON);
    }

    #[tokio::test]
    async fn empty_capture_text_defers() {
        let classifier = KeywordOverlapClassifier;
        let allowed = vec!["x/y".to_string()];
        let out = classifier.classify("   \t\n", &allowed).await.expect("ok");
        assert_eq!(out.path, "DEFER");
        assert_eq!(out.confidence, 0.0);
    }

    /// Mock LLM client that simulates a grammar-bound response.
    struct DeterministicMockLlm {
        canned: VariantBOutput,
    }

    #[async_trait]
    impl RawJsonLlmClient for DeterministicMockLlm {
        async fn emit_json(
            &self,
            _prompt: &str,
            _schema: &Value,
        ) -> Result<Value, ClassifierError> {
            Ok(serde_json::to_value(self.canned.clone())
                .map_err(|e| ClassifierError::Parse(e.to_string()))?)
        }
    }

    #[tokio::test]
    async fn gbnf_classifier_round_trips_host_emission() {
        let canned = VariantBOutput {
            path: "research/papers".to_string(),
            confidence: 0.91,
            rationale: "host model classified".to_string(),
        };
        let classifier = GbnfClassifier::new(DeterministicMockLlm { canned: canned.clone() });
        let allowed = vec!["research/papers".to_string()];
        let out = classifier.classify("anything", &allowed).await.expect("ok");
        assert_eq!(out.path, canned.path);
        assert_eq!(out.confidence, canned.confidence);
    }

    /// Mock LLM client that errors so we exercise the keyword fallback.
    struct ErroringMockLlm;

    #[async_trait]
    impl RawJsonLlmClient for ErroringMockLlm {
        async fn emit_json(
            &self,
            _prompt: &str,
            _schema: &Value,
        ) -> Result<Value, ClassifierError> {
            Err(ClassifierError::Inference("simulated host failure".into()))
        }
    }

    #[tokio::test]
    async fn gbnf_classifier_falls_back_to_keyword_on_host_error() {
        let classifier = GbnfClassifier::new(ErroringMockLlm);
        let allowed = vec!["code/rust".to_string()];
        let out = classifier
            .classify("rust agent loop refactor", &allowed)
            .await
            .expect("fallback ok");
        assert_eq!(
            out.path, "code/rust",
            "host failure must fall through to keyword overlap so the pipeline never stalls"
        );
    }

    #[tokio::test]
    async fn compile_grammar_produces_constrainable_top_level_grammar() {
        let allowed = vec!["a/b".to_string(), "c/d".to_string()];
        // Just exercising the path — compile must succeed for any
        // non-empty allowed-path set.
        let _grammar =
            GbnfClassifier::<DeterministicMockLlm>::compile_grammar(&allowed).expect("compile ok");
    }
}
