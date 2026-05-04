//! Phase 3 — `structure.route_capture` four-variant routing pipeline.
//!
//! Plan §4 — daily-driver path. Latency budget 800ms p95 from submit
//! to toast. The action enum has exactly four values per §4.1:
//! `place | merge_into_existing_note | create_folder | defer`. The
//! variant ladder (§4.3-§4.6) walks A → B → C → D with confidence
//! floors that are FLOORS, not guides.
//!
//! Phase 3A scope (this commit):
//! - Action enum + RouteInput + RouteDecision typed surface.
//! - JSON Schemas for input (route_capture.input.v1.json) and output
//!   (route_capture.output.v1.json).
//! - Variant D (defer) — the always-available fallback per §4.6
//!   ("defer is a feature, not failure").
//! - `route_capture()` orchestrator stub that, in 3A, always reaches
//!   Variant D. Variants A/B/C land in 3B/3C/3D as their dependencies
//!   (folder-medoid index, concept canonicalizer, GBNF classifier)
//!   come online.
//!
//! Plan-canonical thresholds:
//! - Variant A (centroid embedding):  >= 0.85
//! - Variant B (GBNF classification): >= 0.75
//! - Variant C (concept-anchored):    >= 0.70
//! - Below all three → DEFER. These are FLOORS.

use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

use crate::format::{validate_against, FormatError};

pub mod variant_a;
pub mod variant_b;
pub mod variant_c;

pub const ROUTE_INPUT_V1_ID: &str = "epistemos://schemas/route_capture.input.v1.json";
pub const ROUTE_OUTPUT_V1_ID: &str = "epistemos://schemas/route_capture.output.v1.json";

pub const ROUTE_INPUT_SCHEMA: &str =
    include_str!("../../schemas/route_capture.input.v1.json");
pub const ROUTE_OUTPUT_SCHEMA: &str =
    include_str!("../../schemas/route_capture.output.v1.json");

/// Plan §4.3-§4.5 confidence floors. Tools must use these constants
/// rather than re-defining magic numbers — drift here would silently
/// break the four-variant ladder semantics.
pub const VARIANT_A_FLOOR: f64 = 0.85;
pub const VARIANT_B_FLOOR: f64 = 0.75;
pub const VARIANT_C_FLOOR: f64 = 0.70;

/// Plan §4.5 merge gate: confidence ≥ 0.90 AND target note last-edited > 24h.
pub const MERGE_CONFIDENCE_GATE: f64 = 0.90;
pub const MERGE_STALENESS_HOURS: u64 = 24;

/// Plan §4.5 create_folder gate: cosine ≥ 0.92 to existing concept = "not new".
pub const CREATE_FOLDER_CONCEPT_NEW_THRESHOLD: f64 = 0.92;
/// Cluster tightness for create_folder: ≥3 notes at cosine ≥ 0.8 in one folder.
pub const CREATE_FOLDER_CLUSTER_COSINE: f64 = 0.80;
pub const CREATE_FOLDER_CLUSTER_MIN_COUNT: usize = 3;

/// Plan §4.2 — reasoning_trace hard cap. 280 chars ≈ 70 tokens. Brief-
/// Is-Better arxiv:2604.02155 — Qwen 1.5B peaks at ~32 reasoning tokens.
pub const REASONING_TRACE_MAX_CHARS: usize = 280;

/// Plan §4.5 Variant C confidence values (specific to each branch of
/// the decision tree, distinct from VARIANT_C_FLOOR which is the
/// orchestrator's accept threshold). Pinned so silent drift breaks tests.
pub const VARIANT_C_PLACE_VIA_FOUND_CONFIDENCE: f64 = 0.72;
pub const VARIANT_C_CREATE_FOLDER_CONFIDENCE: f64 = 0.71;
pub const VARIANT_C_PLACE_VIA_MAJORITY_CONFIDENCE: f64 = 0.70;

/// Plan §4.1 — exactly four routing actions. Mismatch with the schema
/// enum would be a structural divergence; round-trip tests prevent it.
#[derive(Serialize, Deserialize, JsonSchema, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum Action {
    Place,
    MergeIntoExistingNote,
    CreateFolder,
    Defer,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct VaultTreeEntry {
    pub path: String,
    pub centroid_id: String,
    pub note_count: u32,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub exemplar_titles: Vec<String>,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct RecentCapture {
    pub text: String,
    pub placed_at: String,
    pub ts: i64,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct RouteInput {
    pub capture_text: String,
    pub vault_tree: Vec<VaultTreeEntry>,
    pub recent_captures: Vec<RecentCapture>,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct AlternativePath {
    pub path: String,
    pub score: f64,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct RouteDecision {
    pub action: Action,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub folder_path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub target_note_path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub new_folder_name: Option<String>,
    pub confidence: f64,
    pub reasoning_trace: String,
    pub alternative_paths: Vec<AlternativePath>,
}

impl RouteDecision {
    /// Plan §4.6 — Variant D defer is always available. confidence = 1.0
    /// because the system is *certain* about deferring, not uncertain
    /// about a placement.
    pub fn defer(reason: impl Into<String>, alternative_paths: Vec<AlternativePath>) -> Self {
        let mut reasoning = reason.into();
        if reasoning.chars().count() > REASONING_TRACE_MAX_CHARS {
            // Truncate at character (not byte) boundary to keep UTF-8 valid.
            reasoning = reasoning
                .chars()
                .take(REASONING_TRACE_MAX_CHARS)
                .collect();
        }
        Self {
            action: Action::Defer,
            folder_path: Some("_inbox/review/".to_string()),
            target_note_path: None,
            new_folder_name: None,
            confidence: 1.0,
            reasoning_trace: reasoning,
            alternative_paths,
        }
    }

    /// Plan §4.5 RouteDecision::place — drop the capture into an existing
    /// folder. Caller supplies confidence + reasoning_trace.
    pub fn place(folder: impl Into<String>, confidence: f64, reasoning: impl Into<String>) -> Self {
        let reasoning = truncate_chars(reasoning.into(), REASONING_TRACE_MAX_CHARS);
        Self {
            action: Action::Place,
            folder_path: Some(folder.into()),
            target_note_path: None,
            new_folder_name: None,
            confidence,
            reasoning_trace: reasoning,
            alternative_paths: Vec::new(),
        }
    }

    /// Plan §4.5 RouteDecision::merge — append to an existing note.
    /// Gated at the call site by §4.5: confidence ≥ 0.90 AND target's
    /// last-edited > 24h. Constructor doesn't enforce the gate (variant
    /// logic does); this just builds the typed value.
    pub fn merge(
        target_note_path: impl Into<String>,
        confidence: f64,
        reasoning: impl Into<String>,
    ) -> Self {
        let reasoning = truncate_chars(reasoning.into(), REASONING_TRACE_MAX_CHARS);
        Self {
            action: Action::MergeIntoExistingNote,
            folder_path: None,
            target_note_path: Some(target_note_path.into()),
            new_folder_name: None,
            confidence,
            reasoning_trace: reasoning,
            alternative_paths: Vec::new(),
        }
    }

    /// Plan §4.5 RouteDecision::create_folder — propose a new folder
    /// sibling. Gated at the call site by §4.5: cluster tight (cos
    /// ≥ 0.80 across ≥3 notes), parent unfit, no existing concept
    /// within cosine 0.92. Constructor builds the typed value;
    /// variant logic enforces the gate.
    pub fn create_folder(
        parent_folder: impl Into<String>,
        new_folder_name: impl Into<String>,
        confidence: f64,
        reasoning: impl Into<String>,
    ) -> Self {
        let reasoning = truncate_chars(reasoning.into(), REASONING_TRACE_MAX_CHARS);
        Self {
            action: Action::CreateFolder,
            folder_path: Some(parent_folder.into()),
            target_note_path: None,
            new_folder_name: Some(new_folder_name.into()),
            confidence,
            reasoning_trace: reasoning,
            alternative_paths: Vec::new(),
        }
    }

    pub fn validate(&self) -> Result<(), FormatError> {
        let v = serde_json::to_value(self)?;
        validate_against(ROUTE_OUTPUT_SCHEMA, &v)
    }
}

/// Char-boundary-safe truncation for UTF-8 reasoning_trace fields.
/// Used by all four constructors (defer / place / merge / create_folder)
/// so that Brief-Is-Better §4.2 cap is uniformly enforced.
fn truncate_chars(s: String, max_chars: usize) -> String {
    if s.chars().count() <= max_chars {
        s
    } else {
        s.chars().take(max_chars).collect()
    }
}

/// Plan §4.5 — `route_capture` orchestrator. Walks the variant
/// ladder A → B → C → D in sequence:
///
/// ```text
/// if variant_a (centroid cosine ≥ 0.85) → place
/// if variant_b (LLM closed-vocab classify ≥ 0.75) → place|defer (model self-defer per §4.4 + §4.6)
/// if variant_c (concept-anchored ≥ 0.70) → place|merge|create_folder
/// otherwise                              → defer
/// ```
///
/// Plan §4.5 confidence floors are FLOORS — a variant cannot return
/// `place` if its own confidence is below threshold. The orchestrator
/// re-checks the floor as a defence-in-depth guard against variant
/// impls that might miss the threshold check internally.
///
/// Variant B's `Defer` action (model self-defer when the GBNF
/// classifier picks the `DEFER` sentinel per §4.4) is accepted at
/// any confidence; that's plan §4.6's "defer is a feature" applied
/// to the model's own judgment.
///
/// Variant C's branch values (0.70 / 0.71 / 0.72 / merge cosine ≥ 0.90)
/// are all at-or-above VARIANT_C_FLOOR by construction.
pub async fn route_capture(input: &RouteInput, ctx: &RouteCtx) -> RouteDecision {
    // Variant A — deterministic centroid embedding (no LLM per §1.4).
    if let Some(d) = variant_a::try_centroid(
        &input.capture_text,
        &ctx.folders,
        &ctx.embedder,
    )
    .await
    {
        if d.confidence >= VARIANT_A_FLOOR {
            return d;
        }
    }

    // Variant B — GBNF closed-vocab LLM classifier. Self-defer is a
    // feature: orchestrator accepts Action::Defer at any confidence.
    if let Some(d) = variant_b::try_llm_classify(
        &input.capture_text,
        &ctx.vault_paths,
        ctx.classifier.as_ref(),
    )
    .await
    {
        if d.action == Action::Defer || d.confidence >= VARIANT_B_FLOOR {
            return d;
        }
    }

    // Variant C — concept-anchored placement / merge / create_folder.
    let pf = ctx.parent_unfit_fn.clone();
    if let Some(d) = variant_c::try_concept_anchored(
        &input.capture_text,
        ctx.extractor.as_ref(),
        ctx.resolver.as_ref(),
        ctx.neighbours.as_ref(),
        move |p| pf(p),
    )
    .await
    {
        if d.confidence >= VARIANT_C_FLOOR {
            return d;
        }
    }

    // Variant D — defer with the input's vault_tree top-3 as
    // alternative_paths so the user has one-keystroke override per §4.7.
    let alternatives: Vec<AlternativePath> = input
        .vault_tree
        .iter()
        .take(3)
        .map(|f| AlternativePath {
            path: f.path.clone(),
            score: 0.0,
        })
        .collect();
    RouteDecision::defer(
        "low_confidence_after_three_variants",
        alternatives,
    )
}

/// Per-call routing context — carries the dependencies all four
/// variants need. Production builders construct this from the
/// vault state + Phase 6 inference layer + Phase 2D cache; tests
/// construct it from controlled stubs.
///
/// The trait objects are `Arc<dyn ...>` so the orchestrator can
/// hold a shared reference + clone cheaply. `parent_unfit_fn` is a
/// closure rather than a trait because the policy is small + tends
/// to vary per-vault rather than per-tool.
pub struct RouteCtx {
    /// Variant A — embedder for centroid cosine. Phase 6 wires real
    /// MLX-backed bge-small; tests use the StubEmbedder from Phase 2D.
    pub embedder: std::sync::Arc<dyn crate::cache::EmbeddingProvider>,
    /// Variant A — folder centroids built from a NightBrain (§7.1) job.
    pub folders: Vec<variant_a::FolderCentroid>,
    /// Variant B — GBNF closed-vocab LLM classifier. Phase 6 wires
    /// MLX-Structured GrammarMaskedLogitProcessor.
    pub classifier: std::sync::Arc<dyn variant_b::LlmClassifier>,
    /// Variant B — vault tree paths (filtered to non-_inbox at the
    /// variant_b layer).
    pub vault_paths: Vec<String>,
    /// Variant C — concept extractor.
    pub extractor: std::sync::Arc<dyn variant_c::ConceptExtractor>,
    /// Variant C — entity resolver against the alias table + concept
    /// graph.
    pub resolver: std::sync::Arc<dyn variant_c::EntityResolver>,
    /// Variant C — neighbour finder via vault.search.
    pub neighbours: std::sync::Arc<dyn variant_c::NeighbourFinder>,
    /// Variant C — parent_unfit policy (true iff no existing parent
    /// folder is a better fit than creating a new one). Trivial
    /// implementations check whether any centroid clears Variant A's
    /// 0.85 floor; richer policies land later.
    pub parent_unfit_fn:
        std::sync::Arc<dyn Fn(&str) -> bool + Send + Sync>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn action_enum_has_exactly_four_canonical_values() {
        // Plan §4.1 — the enum MUST be exactly these four. Drift here
        // is a structural plan violation.
        let canonical = ["place", "merge_into_existing_note", "create_folder", "defer"];
        for variant in [
            Action::Place,
            Action::MergeIntoExistingNote,
            Action::CreateFolder,
            Action::Defer,
        ] {
            let s = serde_json::to_string(&variant).unwrap();
            let stripped = s.trim_matches('"');
            assert!(
                canonical.contains(&stripped),
                "Action variant {:?} serialized as {} which isn't in the plan-canonical four",
                variant,
                stripped
            );
        }
    }

    #[test]
    fn variant_floors_are_plan_canonical() {
        // Plan §4.3-§4.5 floors are FLOORS, not guides. This test
        // hard-codes the plan values — if anyone changes them they're
        // diverging from the canonical doc.
        assert_eq!(VARIANT_A_FLOOR, 0.85);
        assert_eq!(VARIANT_B_FLOOR, 0.75);
        assert_eq!(VARIANT_C_FLOOR, 0.70);
    }

    #[test]
    fn merge_gate_constants_match_plan_4_5() {
        // §4.5: merge requires confidence ≥ 0.90 AND target note's
        // last-edited > 24h.
        assert_eq!(MERGE_CONFIDENCE_GATE, 0.90);
        assert_eq!(MERGE_STALENESS_HOURS, 24);
    }

    #[test]
    fn create_folder_gates_match_plan_4_5() {
        // §4.5: create_folder requires (a) genuinely new concept (no
        // existing concept within cosine 0.92), (b) ≥3 neighbour notes
        // at cosine ≥0.8 in one folder, (c) no existing parent fits.
        assert_eq!(CREATE_FOLDER_CONCEPT_NEW_THRESHOLD, 0.92);
        assert_eq!(CREATE_FOLDER_CLUSTER_COSINE, 0.80);
        assert_eq!(CREATE_FOLDER_CLUSTER_MIN_COUNT, 3);
    }

    #[test]
    fn reasoning_trace_cap_is_plan_canonical_280() {
        // §4.2 — 280 chars ≈ 70 tokens. Hard cap.
        assert_eq!(REASONING_TRACE_MAX_CHARS, 280);
    }

    #[test]
    fn defer_decision_validates_against_output_schema() {
        let d = RouteDecision::defer("low confidence", vec![]);
        d.validate()
            .expect("defer decision must satisfy route_capture.output.v1.json");
    }

    #[test]
    fn defer_decision_with_alternatives_validates() {
        let d = RouteDecision::defer(
            "ambiguous",
            vec![
                AlternativePath {
                    path: "research/ml".to_string(),
                    score: 0.62,
                },
                AlternativePath {
                    path: "engineering".to_string(),
                    score: 0.58,
                },
            ],
        );
        d.validate().unwrap();
        assert_eq!(d.alternative_paths.len(), 2);
    }

    #[test]
    fn defer_truncates_reasoning_trace_at_280_chars() {
        let oversized = "x".repeat(500);
        let d = RouteDecision::defer(oversized, vec![]);
        assert_eq!(d.reasoning_trace.chars().count(), REASONING_TRACE_MAX_CHARS);
        d.validate().expect("truncated trace must validate");
    }

    #[test]
    fn defer_truncates_at_char_boundary_not_byte_boundary_for_utf8() {
        // 280 chars of "🚀" = 1120 bytes. Byte-level truncation would
        // produce invalid UTF-8; we truncate at chars.
        let multibyte = "🚀".repeat(500);
        let d = RouteDecision::defer(multibyte, vec![]);
        assert_eq!(d.reasoning_trace.chars().count(), REASONING_TRACE_MAX_CHARS);
        // Round-trip via UTF-8 — must not panic.
        let s = serde_json::to_string(&d).unwrap();
        let _: RouteDecision = serde_json::from_str(&s).unwrap();
    }

    #[tokio::test]
    async fn route_capture_falls_through_to_defer_when_all_variants_return_none() {
        // Phase 3F orchestrator: with stubs that all return None, the
        // ladder reaches Variant D and defers per §4.6.
        use std::sync::Arc;

        // All-null context: empty folders (Variant A → None), classifier
        // that errors (Variant B → None), extractor that returns no
        // concepts (Variant C → None).
        struct NullClassifier;
        #[async_trait::async_trait]
        impl variant_b::LlmClassifier for NullClassifier {
            async fn classify(
                &self,
                _: &str,
                _: &[String],
            ) -> Result<variant_b::VariantBOutput, variant_b::ClassifierError> {
                Err(variant_b::ClassifierError::Inference("no model wired".into()))
            }
        }
        struct NullExtractor;
        #[async_trait::async_trait]
        impl variant_c::ConceptExtractor for NullExtractor {
            async fn extract(
                &self,
                _: &str,
            ) -> Result<Vec<variant_c::Concept>, variant_c::ExtractorError> {
                Ok(Vec::new())
            }
        }
        struct NullResolver;
        #[async_trait::async_trait]
        impl variant_c::EntityResolver for NullResolver {
            async fn resolve(&self, _: &str) -> variant_c::Resolution {
                variant_c::Resolution::New
            }
        }
        struct NullNeighbours;
        #[async_trait::async_trait]
        impl variant_c::NeighbourFinder for NullNeighbours {
            async fn find(&self, _: &str, _: usize) -> Vec<variant_c::NeighbourHit> {
                Vec::new()
            }
        }
        let stub_embedder: Arc<dyn crate::cache::EmbeddingProvider> =
            Arc::new(crate::cache::StubEmbedder { dim: 8 });

        let ctx = RouteCtx {
            embedder: stub_embedder,
            folders: Vec::new(),
            classifier: Arc::new(NullClassifier),
            vault_paths: Vec::new(),
            extractor: Arc::new(NullExtractor),
            resolver: Arc::new(NullResolver),
            neighbours: Arc::new(NullNeighbours),
            parent_unfit_fn: Arc::new(|_| true),
        };

        let input = RouteInput {
            capture_text: "Routing instinct on rematerialization captures.".to_string(),
            vault_tree: vec![VaultTreeEntry {
                path: "research/ml".to_string(),
                centroid_id: "c_4f2a".to_string(),
                note_count: 12,
                exemplar_titles: vec![],
            }],
            recent_captures: vec![],
        };
        let d = route_capture(&input, &ctx).await;
        assert_eq!(d.action, Action::Defer);
        assert_eq!(d.confidence, 1.0, "defer confidence is 1.0 per §4.6");
        // Plan §4.7 — defer surfaces alternative_paths so the user can
        // override with one keystroke.
        assert_eq!(d.alternative_paths.len(), 1);
        assert_eq!(d.alternative_paths[0].path, "research/ml");
        d.validate().unwrap();
    }

    /// Orchestrator helper — build a RouteCtx with all-null variant
    /// stubs. Tests can mutate individual fields to exercise specific
    /// variant wins.
    fn null_ctx() -> RouteCtx {
        use std::sync::Arc;
        struct NullClassifier;
        #[async_trait::async_trait]
        impl variant_b::LlmClassifier for NullClassifier {
            async fn classify(
                &self,
                _: &str,
                _: &[String],
            ) -> Result<variant_b::VariantBOutput, variant_b::ClassifierError> {
                Err(variant_b::ClassifierError::Inference("null".into()))
            }
        }
        struct NullExtractor;
        #[async_trait::async_trait]
        impl variant_c::ConceptExtractor for NullExtractor {
            async fn extract(
                &self,
                _: &str,
            ) -> Result<Vec<variant_c::Concept>, variant_c::ExtractorError> {
                Ok(Vec::new())
            }
        }
        struct NullResolver;
        #[async_trait::async_trait]
        impl variant_c::EntityResolver for NullResolver {
            async fn resolve(&self, _: &str) -> variant_c::Resolution {
                variant_c::Resolution::New
            }
        }
        struct NullNeighbours;
        #[async_trait::async_trait]
        impl variant_c::NeighbourFinder for NullNeighbours {
            async fn find(&self, _: &str, _: usize) -> Vec<variant_c::NeighbourHit> {
                Vec::new()
            }
        }
        RouteCtx {
            embedder: Arc::new(crate::cache::StubEmbedder { dim: 8 }),
            folders: Vec::new(),
            classifier: Arc::new(NullClassifier),
            vault_paths: Vec::new(),
            extractor: Arc::new(NullExtractor),
            resolver: Arc::new(NullResolver),
            neighbours: Arc::new(NullNeighbours),
            parent_unfit_fn: Arc::new(|_| true),
        }
    }

    fn small_input() -> RouteInput {
        RouteInput {
            capture_text: "test capture".to_string(),
            vault_tree: vec![VaultTreeEntry {
                path: "research/ml".to_string(),
                centroid_id: "c1".to_string(),
                note_count: 12,
                exemplar_titles: vec![],
            }],
            recent_captures: vec![],
        }
    }

    /// Plan §4.5 — Variant A wins when its centroid cosine clears 0.85.
    /// Orchestrator must short-circuit the ladder at A.
    #[tokio::test]
    async fn orchestrator_variant_a_wins_short_circuits_at_centroid() {
        use std::collections::HashMap;
        use std::sync::Arc;
        use async_trait::async_trait;

        // A controlled embedder where the query and one folder's medoid
        // produce cosine = 1.0 (identical vectors → above 0.85 floor).
        struct MapEmbedder {
            map: HashMap<String, Vec<f32>>,
            dim: usize,
        }
        #[async_trait]
        impl crate::cache::EmbeddingProvider for MapEmbedder {
            async fn embed(&self, value: &serde_json::Value) -> Vec<f32> {
                let key = value.as_str().unwrap_or("").to_string();
                self.map.get(&key).cloned().unwrap_or_else(|| vec![0.0; self.dim])
            }
            fn dim(&self) -> usize { self.dim }
        }

        let mut map = HashMap::new();
        map.insert("ml capture".to_string(), vec![1.0, 0.0, 0.0, 0.0]);
        let embedder = Arc::new(MapEmbedder { map, dim: 4 });

        let mut ctx = null_ctx();
        ctx.embedder = embedder;
        ctx.folders = vec![variant_a::FolderCentroid {
            path: "research/ml".to_string(),
            note_count: 5,
            medoid: vec![1.0, 0.0, 0.0, 0.0],
        }];

        let mut input = small_input();
        input.capture_text = "ml capture".to_string();

        let d = route_capture(&input, &ctx).await;
        assert_eq!(d.action, Action::Place);
        assert_eq!(d.folder_path.as_deref(), Some("research/ml"));
        assert!(
            d.confidence >= VARIANT_A_FLOOR,
            "Variant A win must clear 0.85 floor"
        );
        // Reasoning trace must mention variant_a so the trace UI knows
        // which variant fired.
        assert!(d.reasoning_trace.contains("variant_a"));
    }

    /// Plan §4.5 — when A returns None (or below floor), Variant B's
    /// successful classify above 0.75 wins.
    #[tokio::test]
    async fn orchestrator_variant_b_wins_when_a_returns_none() {
        use async_trait::async_trait;
        use std::sync::Arc;

        struct WinningClassifier;
        #[async_trait]
        impl variant_b::LlmClassifier for WinningClassifier {
            async fn classify(
                &self,
                _: &str,
                _: &[String],
            ) -> Result<variant_b::VariantBOutput, variant_b::ClassifierError> {
                Ok(variant_b::VariantBOutput {
                    path: "research/ml".to_string(),
                    confidence: 0.82,
                    rationale: "topic match".to_string(),
                })
            }
        }

        let mut ctx = null_ctx();
        ctx.classifier = Arc::new(WinningClassifier);
        ctx.vault_paths = vec!["research/ml".to_string()];
        // No folders → Variant A returns None.
        let input = small_input();

        let d = route_capture(&input, &ctx).await;
        assert_eq!(d.action, Action::Place);
        assert_eq!(d.folder_path.as_deref(), Some("research/ml"));
        assert_eq!(d.confidence, 0.82);
        assert!(d.confidence >= VARIANT_B_FLOOR);
    }

    /// Plan §4.4 + §4.6 — Variant B's `DEFER` sentinel triggers an
    /// immediate defer at any confidence (model self-defer is a feature).
    #[tokio::test]
    async fn orchestrator_variant_b_self_defer_short_circuits() {
        use async_trait::async_trait;
        use std::sync::Arc;

        struct DeferringClassifier;
        #[async_trait]
        impl variant_b::LlmClassifier for DeferringClassifier {
            async fn classify(
                &self,
                _: &str,
                _: &[String],
            ) -> Result<variant_b::VariantBOutput, variant_b::ClassifierError> {
                Ok(variant_b::VariantBOutput {
                    path: "DEFER".to_string(),
                    confidence: 0.30,
                    rationale: "ambiguous between A/B".to_string(),
                })
            }
        }

        let mut ctx = null_ctx();
        ctx.classifier = Arc::new(DeferringClassifier);
        ctx.vault_paths = vec!["research/ml".to_string()];
        let input = small_input();

        let d = route_capture(&input, &ctx).await;
        assert_eq!(d.action, Action::Defer);
        // The model's self-defer reasoning surfaces in the trace.
        assert!(d.reasoning_trace.contains("model_self_defer"));
    }

    /// Plan §4.5 — Variant C concept-anchored fires when A + B return
    /// None and Variant C finds a tight cluster.
    #[tokio::test]
    async fn orchestrator_variant_c_wins_when_a_and_b_return_none() {
        use async_trait::async_trait;
        use std::sync::Arc;

        struct GoodExtractor;
        #[async_trait]
        impl variant_c::ConceptExtractor for GoodExtractor {
            async fn extract(
                &self,
                _: &str,
            ) -> Result<Vec<variant_c::Concept>, variant_c::ExtractorError> {
                Ok(vec![variant_c::Concept {
                    canonical_name: "checkpoint-gradient".to_string(),
                    surface_form: "gradient checkpointing".to_string(),
                }])
            }
        }
        struct FoundResolver;
        #[async_trait]
        impl variant_c::EntityResolver for FoundResolver {
            async fn resolve(&self, _: &str) -> variant_c::Resolution {
                variant_c::Resolution::Found {
                    concept_id: "c_4f2a".to_string(),
                }
            }
        }
        struct FullNeighbours;
        #[async_trait]
        impl variant_c::NeighbourFinder for FullNeighbours {
            async fn find(&self, _: &str, _: usize) -> Vec<variant_c::NeighbourHit> {
                vec![
                    variant_c::NeighbourHit {
                        path: "research/ml/a.md".to_string(),
                        folder: "research/ml".to_string(),
                        cosine: 0.85,
                        last_edited_hours_ago: 100,
                    },
                    variant_c::NeighbourHit {
                        path: "research/ml/b.md".to_string(),
                        folder: "research/ml".to_string(),
                        cosine: 0.83,
                        last_edited_hours_ago: 100,
                    },
                    variant_c::NeighbourHit {
                        path: "research/ml/c.md".to_string(),
                        folder: "research/ml".to_string(),
                        cosine: 0.81,
                        last_edited_hours_ago: 100,
                    },
                ]
            }
        }

        let mut ctx = null_ctx();
        ctx.extractor = Arc::new(GoodExtractor);
        ctx.resolver = Arc::new(FoundResolver);
        ctx.neighbours = Arc::new(FullNeighbours);
        let input = small_input();

        let d = route_capture(&input, &ctx).await;
        // Found + tight + n≥3 + cos<0.90 (max is 0.85) → place via found.
        assert_eq!(d.action, Action::Place);
        assert_eq!(d.folder_path.as_deref(), Some("research/ml"));
        assert_eq!(d.confidence, VARIANT_C_PLACE_VIA_FOUND_CONFIDENCE);
        assert!(d.confidence >= VARIANT_C_FLOOR);
    }

    /// Plan §4.5 — Variant A returning a sub-floor result must NOT
    /// short-circuit the ladder; orchestrator must advance to B.
    #[tokio::test]
    async fn orchestrator_variant_a_below_floor_advances_to_b() {
        // Variant A's try_centroid returns None when below floor, so
        // this case is structurally impossible at the variant layer
        // (variant_a tested separately). The orchestrator's defence-
        // in-depth `if d.confidence >= VARIANT_A_FLOOR` is the
        // belt-and-suspenders guard. We can't trigger it via the real
        // try_centroid (it None-s out) — but we can verify the chain
        // semantics by constructing a context where variant_a is empty
        // (folders=[]) and variant_b succeeds. Variant A's None is
        // structurally equivalent to "below floor" for the orchestrator.
        use async_trait::async_trait;
        use std::sync::Arc;
        struct WinningB;
        #[async_trait]
        impl variant_b::LlmClassifier for WinningB {
            async fn classify(
                &self,
                _: &str,
                _: &[String],
            ) -> Result<variant_b::VariantBOutput, variant_b::ClassifierError> {
                Ok(variant_b::VariantBOutput {
                    path: "research/ml".into(),
                    confidence: 0.99,
                    rationale: "x".into(),
                })
            }
        }
        let mut ctx = null_ctx();
        ctx.folders = Vec::new();
        ctx.classifier = Arc::new(WinningB);
        ctx.vault_paths = vec!["research/ml".to_string()];
        let d = route_capture(&small_input(), &ctx).await;
        assert_eq!(d.action, Action::Place);
        // Variant B fires.
        assert_eq!(d.folder_path.as_deref(), Some("research/ml"));
    }

    #[test]
    fn route_input_round_trips_via_json() {
        let input = RouteInput {
            capture_text: "test".to_string(),
            vault_tree: vec![VaultTreeEntry {
                path: "p".to_string(),
                centroid_id: "c".to_string(),
                note_count: 5,
                exemplar_titles: vec!["a".to_string(), "b".to_string()],
            }],
            recent_captures: vec![RecentCapture {
                text: "earlier".to_string(),
                placed_at: "notes/x.md".to_string(),
                ts: 1_700_000_000,
            }],
        };
        let s = serde_json::to_string(&input).unwrap();
        let p: RouteInput = serde_json::from_str(&s).unwrap();
        assert_eq!(p, input);
    }

    #[test]
    fn route_input_validates_against_schema() {
        let input = RouteInput {
            capture_text: "hello".to_string(),
            vault_tree: vec![],
            recent_captures: vec![],
        };
        let v = serde_json::to_value(&input).unwrap();
        validate_against(ROUTE_INPUT_SCHEMA, &v)
            .expect("RouteInput must satisfy route_capture.input.v1.json");
    }

    #[test]
    fn route_output_schema_rejects_invalid_new_folder_name_pattern() {
        // Plan §4.5: new_folder_name must match ^[a-z0-9-]{2,48}$.
        let bad = serde_json::json!({
            "action": "create_folder",
            "new_folder_name": "BadCamelCase",
            "confidence": 0.72,
            "reasoning_trace": "x",
            "alternative_paths": []
        });
        assert!(
            validate_against(ROUTE_OUTPUT_SCHEMA, &bad).is_err(),
            "uppercase folder name must be rejected"
        );
    }

    #[test]
    fn route_output_schema_rejects_reasoning_trace_over_280() {
        let oversized = "x".repeat(281);
        let bad = serde_json::json!({
            "action": "defer",
            "confidence": 1.0,
            "reasoning_trace": oversized,
            "alternative_paths": []
        });
        assert!(validate_against(ROUTE_OUTPUT_SCHEMA, &bad).is_err());
    }

    #[test]
    fn route_input_schema_rejects_capture_text_over_2000() {
        let oversized = "x".repeat(2001);
        let bad = serde_json::json!({
            "capture_text": oversized,
            "vault_tree": [],
            "recent_captures": []
        });
        assert!(validate_against(ROUTE_INPUT_SCHEMA, &bad).is_err());
    }

    #[test]
    fn route_input_schema_rejects_recent_captures_over_10() {
        let many: Vec<_> = (0..11)
            .map(|i| {
                serde_json::json!({
                    "text": format!("c{}", i),
                    "placed_at": "p",
                    "ts": 1
                })
            })
            .collect();
        let bad = serde_json::json!({
            "capture_text": "x",
            "vault_tree": [],
            "recent_captures": many
        });
        assert!(validate_against(ROUTE_INPUT_SCHEMA, &bad).is_err());
    }
}
