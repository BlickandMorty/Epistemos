//! Phase 3E — eval harness for `route_capture`.
//!
//! Plan §11 Phase 3 EXIT criterion: "Eval harness reports ≥85% top-1
//! accuracy on placed captures, defer rate within 8–15% target band,
//! zero schema violations on output."
//!
//! Plan §12 verification command:
//! `cargo run --bin route_eval -- --set agent_core/eval/route_v1.jsonl`
//!
//! This module ships the harness mechanics (fixture format, runner,
//! metrics, pass-criteria) and a small synthetic seed corpus for
//! validating the harness wiring. The real 200-case corpus lands when
//! Phase 6 wires actual MLX inference + the user dogfoods captures —
//! until then the synthetic corpus exercises the variant fall-through
//! paths and the §11 pass-criteria computation.
//!
//! ## Eval pass criteria (plan §11 Phase 3 EXIT)
//!
//! - top_1_accuracy ≥ 0.85
//! - 0.08 ≤ defer_rate ≤ 0.15
//! - schema_violations == 0
//!
//! "top-1 accuracy" here means: for `place` decisions, the chosen
//! folder matches the expected folder. For `defer / merge_into_
//! existing_note / create_folder`, the action matches expectation
//! (folder/target/new_name match where specified).

// Phase 11 — additional eval modules.
pub mod heal_recovery;

use std::io::BufRead;

use serde::{Deserialize, Serialize};

use crate::route::{Action, RouteCtx, RouteDecision, RouteInput, VaultTreeEntry};

/// One eval case — what the captured text was and what the canonical
/// routing decision should look like. Fields beyond `capture_text` +
/// `expected_action` are optional; the eval matcher applies them only
/// when present.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct EvalFixture {
    pub capture_text: String,
    pub expected_action: Action,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub expected_folder: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub expected_target_note_path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub expected_new_folder_name: Option<String>,
    /// Optional — the eval can simulate a vault state per-fixture. When
    /// absent the harness uses the global RouteCtx's folders.
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub vault_tree: Option<Vec<VaultTreeEntry>>,
}

#[derive(Debug, Clone)]
pub struct FixtureOutcome {
    pub fixture_id: usize,
    pub expected_action: Action,
    pub actual: RouteDecision,
    pub correct_top_1: bool,
    pub schema_valid: bool,
}

#[derive(Debug, Clone)]
pub struct EvalReport {
    pub total: usize,
    pub correct_top_1: usize,
    pub defer_count: usize,
    pub schema_violations: usize,
    pub outcomes: Vec<FixtureOutcome>,
}

impl EvalReport {
    pub fn top_1_accuracy(&self) -> f64 {
        if self.total == 0 {
            0.0
        } else {
            self.correct_top_1 as f64 / self.total as f64
        }
    }

    pub fn defer_rate(&self) -> f64 {
        if self.total == 0 {
            0.0
        } else {
            self.defer_count as f64 / self.total as f64
        }
    }

    /// Plan §11 Phase 3 EXIT criterion.
    pub fn passes_phase_3_exit(&self) -> bool {
        let acc = self.top_1_accuracy();
        let defer = self.defer_rate();
        acc >= 0.85 && defer >= 0.08 && defer <= 0.15 && self.schema_violations == 0
    }

    /// Human-readable single-line summary.
    pub fn summary(&self) -> String {
        format!(
            "total={} top_1={:.1}% defer={:.1}% schema_violations={} pass={}",
            self.total,
            self.top_1_accuracy() * 100.0,
            self.defer_rate() * 100.0,
            self.schema_violations,
            self.passes_phase_3_exit(),
        )
    }
}

/// Load JSONL fixtures from a reader. One fixture per line; blank
/// lines + lines starting with `#` are ignored (so the corpus file
/// can carry comments).
pub fn load_fixtures_jsonl<R: BufRead>(reader: R) -> Result<Vec<EvalFixture>, EvalError> {
    let mut out = Vec::new();
    for (line_no, line) in reader.lines().enumerate() {
        let line = line.map_err(|e| EvalError::Io(line_no + 1, e.to_string()))?;
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        let fixture: EvalFixture = serde_json::from_str(trimmed)
            .map_err(|e| EvalError::Parse(line_no + 1, e.to_string()))?;
        out.push(fixture);
    }
    Ok(out)
}

#[derive(Debug, thiserror::Error)]
pub enum EvalError {
    #[error("io error at line {0}: {1}")]
    Io(usize, String),
    #[error("parse error at line {0}: {1}")]
    Parse(usize, String),
}

/// Run the eval harness against a set of fixtures. Each fixture's
/// `vault_tree` (if set) overrides the ctx's `folders` for that one
/// invocation — useful for per-fixture vault-state simulation.
///
/// Validates each output against `route_capture.output.v1.json`
/// (catching the schema_violations metric per §11).
pub async fn run_route_eval(
    fixtures: &[EvalFixture],
    ctx: &RouteCtx,
) -> EvalReport {
    let mut outcomes = Vec::with_capacity(fixtures.len());
    let mut correct_top_1 = 0usize;
    let mut defer_count = 0usize;
    let mut schema_violations = 0usize;

    for (id, fixture) in fixtures.iter().enumerate() {
        let input = RouteInput {
            capture_text: fixture.capture_text.clone(),
            vault_tree: fixture.vault_tree.clone().unwrap_or_else(|| {
                // No per-fixture override — synthesize a vault_tree
                // from ctx.folders so the orchestrator's defer path
                // still has alternative_paths to surface.
                ctx.folders
                    .iter()
                    .map(|f| VaultTreeEntry {
                        path: f.path.clone(),
                        centroid_id: format!("c_{}", id),
                        note_count: f.note_count,
                        exemplar_titles: vec![],
                    })
                    .collect()
            }),
            recent_captures: Vec::new(),
        };
        let actual = crate::route::route_capture(&input, ctx).await;
        let schema_valid = actual.validate().is_ok();
        if !schema_valid {
            schema_violations += 1;
        }
        if actual.action == Action::Defer {
            defer_count += 1;
        }
        let correct = is_correct(&actual, fixture);
        if correct {
            correct_top_1 += 1;
        }
        outcomes.push(FixtureOutcome {
            fixture_id: id,
            expected_action: fixture.expected_action,
            actual,
            correct_top_1: correct,
            schema_valid,
        });
    }

    EvalReport {
        total: fixtures.len(),
        correct_top_1,
        defer_count,
        schema_violations,
        outcomes,
    }
}

fn is_correct(actual: &RouteDecision, expected: &EvalFixture) -> bool {
    if actual.action != expected.expected_action {
        return false;
    }
    match expected.expected_action {
        Action::Place => match (&expected.expected_folder, &actual.folder_path) {
            (Some(want), Some(got)) => want == got,
            (None, _) => true, // expected_folder unspecified — action match is enough
            _ => false,
        },
        Action::CreateFolder => {
            let folder_ok = match (&expected.expected_folder, &actual.folder_path) {
                (Some(want), Some(got)) => want == got,
                (None, _) => true,
                _ => false,
            };
            let new_name_ok = match (
                &expected.expected_new_folder_name,
                &actual.new_folder_name,
            ) {
                (Some(want), Some(got)) => want == got,
                (None, _) => true,
                _ => false,
            };
            folder_ok && new_name_ok
        }
        Action::MergeIntoExistingNote => {
            match (&expected.expected_target_note_path, &actual.target_note_path) {
                (Some(want), Some(got)) => want == got,
                (None, _) => true,
                _ => false,
            }
        }
        Action::Defer => true,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;

    fn null_ctx() -> RouteCtx {
        // Minimal stubs — orchestrator will reach Variant D defer.
        use async_trait::async_trait;
        use crate::route::{variant_b, variant_c};

        struct NullClassifier;
        #[async_trait]
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
        #[async_trait]
        impl variant_c::ConceptExtractor for NullExtractor {
            async fn extract(
                &self,
                _: &str,
            ) -> Result<Vec<variant_c::Concept>, variant_c::ExtractorError> {
                Ok(Vec::new())
            }
        }
        struct NullResolver;
        #[async_trait]
        impl variant_c::EntityResolver for NullResolver {
            async fn resolve(&self, _: &str) -> variant_c::Resolution {
                variant_c::Resolution::New
            }
        }
        struct NullNeighbours;
        #[async_trait]
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

    #[test]
    fn load_fixtures_jsonl_skips_blank_lines_and_comments() {
        let raw = r#"
# this is a comment
{"capture_text":"hello","expected_action":"defer"}

# blank line above intentionally
{"capture_text":"world","expected_action":"defer"}
"#;
        let fixtures = load_fixtures_jsonl(raw.as_bytes()).unwrap();
        assert_eq!(fixtures.len(), 2);
        assert_eq!(fixtures[0].capture_text, "hello");
        assert_eq!(fixtures[1].capture_text, "world");
    }

    #[test]
    fn load_fixtures_jsonl_reports_parse_error_with_line_number() {
        let raw = r#"
{"capture_text":"hello","expected_action":"defer"}
{ this is not json
{"capture_text":"world","expected_action":"defer"}
"#;
        let r = load_fixtures_jsonl(raw.as_bytes());
        match r {
            Err(EvalError::Parse(line, _)) => assert_eq!(line, 3),
            other => panic!("expected Parse error at line 3, got {:?}", other),
        }
    }

    #[tokio::test]
    async fn empty_fixtures_yields_zero_metrics() {
        let report = run_route_eval(&[], &null_ctx()).await;
        assert_eq!(report.total, 0);
        assert_eq!(report.top_1_accuracy(), 0.0);
        assert_eq!(report.defer_rate(), 0.0);
        assert!(!report.passes_phase_3_exit(), "0/0 doesn't satisfy ≥85%");
    }

    #[tokio::test]
    async fn null_ctx_makes_every_fixture_defer() {
        let fixtures = vec![
            EvalFixture {
                capture_text: "x".into(),
                expected_action: Action::Defer,
                expected_folder: None,
                expected_target_note_path: None,
                expected_new_folder_name: None,
                vault_tree: None,
            },
            EvalFixture {
                capture_text: "y".into(),
                expected_action: Action::Defer,
                expected_folder: None,
                expected_target_note_path: None,
                expected_new_folder_name: None,
                vault_tree: None,
            },
        ];
        let report = run_route_eval(&fixtures, &null_ctx()).await;
        assert_eq!(report.total, 2);
        assert_eq!(report.defer_count, 2);
        assert_eq!(report.correct_top_1, 2);
        assert_eq!(report.schema_violations, 0);
        assert_eq!(report.top_1_accuracy(), 1.0);
        assert_eq!(report.defer_rate(), 1.0);
        // 100% defer rate is OUTSIDE the §11 8-15% target band → fails.
        assert!(!report.passes_phase_3_exit());
    }

    #[tokio::test]
    async fn fixture_expected_place_but_orchestrator_defers_marks_incorrect() {
        let fixtures = vec![EvalFixture {
            capture_text: "test".into(),
            expected_action: Action::Place,
            expected_folder: Some("research/ml".into()),
            expected_target_note_path: None,
            expected_new_folder_name: None,
            vault_tree: None,
        }];
        let report = run_route_eval(&fixtures, &null_ctx()).await;
        assert_eq!(report.correct_top_1, 0, "defer != place expectation");
        assert_eq!(report.defer_count, 1);
    }

    #[test]
    fn phase_3_exit_pass_criteria_match_plan_11_literal() {
        // ≥85% top-1, 8-15% defer, zero schema violations.
        let pass = EvalReport {
            total: 200,
            correct_top_1: 170, // exactly 85%
            defer_count: 20,    // 10% — within band
            schema_violations: 0,
            outcomes: Vec::new(),
        };
        assert!(pass.passes_phase_3_exit());

        let acc_below = EvalReport {
            total: 200,
            correct_top_1: 169, // 84.5% — below 85
            defer_count: 20,
            schema_violations: 0,
            outcomes: Vec::new(),
        };
        assert!(!acc_below.passes_phase_3_exit());

        let defer_below = EvalReport {
            total: 200,
            correct_top_1: 200,
            defer_count: 15, // 7.5% — below 8% lower band
            schema_violations: 0,
            outcomes: Vec::new(),
        };
        assert!(!defer_below.passes_phase_3_exit());

        let defer_above = EvalReport {
            total: 200,
            correct_top_1: 200,
            defer_count: 31, // 15.5% — above 15% upper band
            schema_violations: 0,
            outcomes: Vec::new(),
        };
        assert!(!defer_above.passes_phase_3_exit());

        let schema_violation = EvalReport {
            total: 200,
            correct_top_1: 200,
            defer_count: 20,
            schema_violations: 1, // any > 0 fails
            outcomes: Vec::new(),
        };
        assert!(!schema_violation.passes_phase_3_exit());
    }

    #[test]
    fn summary_is_human_readable() {
        let r = EvalReport {
            total: 100,
            correct_top_1: 90,
            defer_count: 10,
            schema_violations: 0,
            outcomes: Vec::new(),
        };
        let s = r.summary();
        assert!(s.contains("total=100"));
        assert!(s.contains("top_1=90"));
        assert!(s.contains("defer=10"));
        assert!(s.contains("schema_violations=0"));
        assert!(s.contains("pass=true"));
    }

    #[test]
    fn fixture_round_trips_via_jsonl() {
        let f = EvalFixture {
            capture_text: "hello".into(),
            expected_action: Action::Place,
            expected_folder: Some("research/ml".into()),
            expected_target_note_path: None,
            expected_new_folder_name: None,
            vault_tree: None,
        };
        let s = serde_json::to_string(&f).unwrap();
        let p: EvalFixture = serde_json::from_str(&s).unwrap();
        assert_eq!(p, f);
    }

    #[tokio::test]
    async fn synthetic_seed_corpus_loads_and_runs_without_panic() {
        // The shipped seed corpus must at least parse + run through
        // the harness. Pass criteria isn't asserted here (real eval
        // requires Phase 6 MLX wiring); this is a smoke test for the
        // harness mechanics.
        let raw = include_str!("../../eval/route_v1.jsonl");
        let fixtures = load_fixtures_jsonl(raw.as_bytes()).unwrap();
        assert!(!fixtures.is_empty(), "seed corpus must not be empty");
        let report = run_route_eval(&fixtures, &null_ctx()).await;
        // With null ctx every fixture defers; harness mechanics work
        // regardless of correctness.
        assert_eq!(report.total, fixtures.len());
        assert_eq!(report.schema_violations, 0, "all defers are schema-valid");
    }
}
