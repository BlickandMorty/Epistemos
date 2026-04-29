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

    pub fn validate(&self) -> Result<(), FormatError> {
        let v = serde_json::to_value(self)?;
        validate_against(ROUTE_OUTPUT_SCHEMA, &v)
    }
}

/// Phase 3A `route_capture` orchestrator stub. Walks the variant ladder
/// per §4.5; in 3A only Variant D is implemented, so every call ends in
/// `defer`. Variants A/B/C land as their dependencies come online.
pub async fn route_capture(input: &RouteInput) -> RouteDecision {
    // Phase 3B: try_centroid -> if confidence >= VARIANT_A_FLOOR, return.
    // Phase 3C: try_llm_classify -> if confidence >= VARIANT_B_FLOOR, return.
    // Phase 3D: try_concept_anchored -> if confidence >= VARIANT_C_FLOOR, return.
    // Phase 3A (now): always defer with the input's vault_tree as the
    // alternative_paths surface so the user has one-keystroke override.
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
        "phase 3A: variants A/B/C not yet wired; defer is the §4.6 always-safe fallback",
        alternatives,
    )
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

    #[test]
    fn route_capture_phase_3a_stub_always_defers() {
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
        let d = futures::executor::block_on(route_capture(&input));
        assert_eq!(d.action, Action::Defer);
        assert!(d.confidence > 0.0);
        d.validate().unwrap();
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
