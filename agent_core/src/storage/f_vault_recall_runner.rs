//! F-VaultRecall-50 runner — bridges fixture rows (data) to a
//! `VaultBackend` (retrieval) and produces a pass/fail verdict plus
//! the full [`RetrievalTrace`] for the W-21 "Vault recall health"
//! diagnostics surface.
//!
//! The runner is intentionally generic over `&dyn VaultBackend` so the
//! same code path serves:
//! - tests (against a seeded `VaultStore` in a tempdir),
//! - the Settings → Diagnostics row (against the user's real vault),
//! - future RRF-fused backends (e.g. an `epistemos-shadow` adapter).
//!
//! Pass contract:
//! - non-`PureChatter` rows pass iff every `row.expected_paths` entry
//!   appears in the top `row.top_n` results AND no `row.forbidden_paths`
//!   entry appears in the top `row.top_n` results.
//! - `PureChatter` rows pass iff `trace.evidence_strength() == Weak`
//!   AND no `row.forbidden_paths` entry appears in the top `row.top_n`
//!   results. PureChatter rows declare empty `expected_paths` because
//!   the contract is "no useful retrieval; runtime MUST defer or
//!   broaden" — encoded as the W-19 ChatCoordinator decision input.
//!
//! Cross-references:
//! - `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md`
//! - `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T21
//!   ("F-VaultRecall-50 fixture visible in diagnostics")
//! - `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` W-21

use serde::Serialize;

use crate::storage::f_vault_recall_50_fixture::{FVaultRecallCategory, FVaultRecallRow};
use crate::storage::retrieval_trace::{EvidenceStrength, RetrievalTrace};
use crate::storage::vault::{VaultBackend, VaultError};

/// Outcome of running one fixture row against a backend.
///
/// `passed` is a derived boolean — its inputs (`expected_missed` and
/// `forbidden_present`) are preserved so the W-21 surface can show
/// "missed: notes/foo.md" / "leaked: ui/bar.md" deltas instead of a
/// bare red/green light.
#[derive(Debug, Clone, Serialize)]
pub struct FVaultRecallRowOutcome {
    pub query: String,
    pub category: String,
    pub top_n: usize,
    pub passed: bool,
    pub expected_seen: Vec<String>,
    pub expected_missed: Vec<String>,
    pub forbidden_present: Vec<String>,
    pub top_paths: Vec<String>,
    /// T21 iter-68: snapshot of `trace.has_only_lexical_signals()` from
    /// the retrieval that produced this outcome. Today every
    /// `VaultBackend` impl produces `true` here (Q2 gap — see
    /// `docs/F_VAULT_RECALL_50_2026_05_18.md` §8). When
    /// epistemos-shadow integration lands, this surface flips per-row
    /// and the W-21 diagnostics can show "lexical-only" chips next to
    /// rows that didn't get a multi-signal retrieval.
    pub lexical_only: bool,
    /// Lowercase [`EvidenceStrength`] slug captured from the retrieval
    /// trace. This makes weak-evidence regressions visible in runner
    /// JSON without requiring the Swift diagnostics surface to
    /// re-classify trace internals.
    pub evidence_strength: String,
}

impl FVaultRecallRowOutcome {
    /// Quick human-readable verdict for a single row. The full breakdown
    /// (expected_missed, forbidden_present, top_paths) lives in the
    /// struct fields; this is for log lines.
    pub fn verdict_line(&self) -> String {
        if self.passed {
            format!("PASS  {:<32} ({} retrieved)", self.query, self.top_paths.len())
        } else {
            format!(
                "FAIL  {:<32} missed={:?} leaked={:?}",
                self.query, self.expected_missed, self.forbidden_present
            )
        }
    }
}

/// Run one F-VaultRecall-50 row against a backend.
///
/// Calls `backend.hybrid_search_with_trace(row.query, row.top_n, &[])`,
/// then evaluates the row's expected/forbidden contract against the
/// top `row.top_n` result paths. Returns both the outcome and the
/// trace so the diagnostics surface can show "why this passed/failed"
/// (signal_summary, candidate_pool_size, Fix-B notes).
pub async fn run_row(
    backend: &dyn VaultBackend,
    row: &FVaultRecallRow,
) -> Result<(FVaultRecallRowOutcome, RetrievalTrace), VaultError> {
    let (results, trace) = backend
        .hybrid_search_with_trace(row.query, row.top_n, &[])
        .await?;

    let top_paths: Vec<String> = results
        .iter()
        .take(row.top_n)
        .map(|r| r.path.clone())
        .collect();

    let mut expected_seen = Vec::new();
    let mut expected_missed = Vec::new();
    for expected in row.expected_paths {
        if top_paths.iter().any(|p| p == expected) {
            expected_seen.push((*expected).to_string());
        } else {
            expected_missed.push((*expected).to_string());
        }
    }

    let mut forbidden_present = Vec::new();
    for forbidden in row.forbidden_paths {
        if top_paths.iter().any(|p| p == forbidden) {
            forbidden_present.push((*forbidden).to_string());
        }
    }

    // T21 iter-16: PureChatter rows have empty `expected_paths` and pass
    // via the trace's evidence-strength verdict. Every other category
    // uses the standard expected/forbidden contract.
    let evidence_strength = trace.evidence_strength();
    let passed = if row.category == FVaultRecallCategory::PureChatter {
        evidence_strength == EvidenceStrength::Weak && forbidden_present.is_empty()
    } else {
        expected_missed.is_empty() && forbidden_present.is_empty()
    };

    let lexical_only = trace.has_only_lexical_signals();

    Ok((
        FVaultRecallRowOutcome {
            query: row.query.to_string(),
            category: format!("{:?}", row.category),
            top_n: row.top_n,
            passed,
            expected_seen,
            expected_missed,
            forbidden_present,
            top_paths,
            lexical_only,
            evidence_strength: evidence_strength.slug().to_string(),
        },
        trace,
    ))
}

/// Run every row in `fixture` against the backend, in order. Returns a
/// `Vec` of outcomes; callers (Settings → Diagnostics row, CI summary,
/// etc.) can compute the pass rate themselves via `outcomes.iter().
/// filter(|o| o.0.passed).count()`.
///
/// This is the function the W-21 diagnostics surface will call once
/// per index-update; each row is independent so a single failure does
/// not abort the run.
pub async fn run_all(
    backend: &dyn VaultBackend,
    fixture: &[FVaultRecallRow],
) -> Result<Vec<(FVaultRecallRowOutcome, RetrievalTrace)>, VaultError> {
    let mut outcomes = Vec::with_capacity(fixture.len());
    for row in fixture {
        let outcome = run_row(backend, row).await?;
        outcomes.push(outcome);
    }
    Ok(outcomes)
}

/// Per-category pass-rate breakdown — used by the W-21 Settings →
/// Diagnostics → "Vault recall health" row to render "Paraphrase: 0/2"
/// style stats. Categories are rendered as their `Debug` form (matches
/// `FVaultRecallRowOutcome::category`).
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct FVaultRecallCategoryStats {
    pub category: String,
    pub total: usize,
    pub passed: usize,
}

/// Aggregate summary of an F-VaultRecall-50 sweep. Computes the overall
/// pass count + rate AND a per-category breakdown so the W-21 surface
/// can show "23/50 (46%) passing — Paraphrase 0/2, ChattyPrefix 1/1,
/// …" without re-implementing the aggregation in Swift.
///
/// `pass_rate` is `passed / total` as `f64` in `[0.0, 1.0]`. Returns
/// `0.0` for an empty input rather than NaN.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct FVaultRecallSummary {
    pub total: usize,
    pub passed: usize,
    pub failed: usize,
    pub pass_rate: f64,
    /// Categories sorted by name for deterministic JSON output. The
    /// W-21 surface can re-sort as it likes.
    pub by_category: Vec<FVaultRecallCategoryStats>,
    /// T21 iter-68: count of outcomes whose retrieval ran against a
    /// Q2-gap backend (Lexical-only `signal_summary`). Today every
    /// sweep equals `total`; when epistemos-shadow integration lands
    /// this count drops and the W-21 surface can render
    /// "lexical-only: N/T" alongside the pass-rate label.
    pub lexical_only_count: usize,
    /// Count of row outcomes whose trace classified the evidence as
    /// weak. This is the runner-level typed signal for "ask, defer, or
    /// broaden search" behavior instead of burying the verdict in
    /// per-row trace JSON.
    pub weak_evidence_count: usize,
}

impl FVaultRecallSummary {
    /// T21 iter-35: human-readable one-line render of the summary.
    /// Mirrors `FVaultRecallRowOutcome::verdict_line()`. Format:
    /// `"P/T passing (R%) — Cat1 N/M, Cat2 P/Q, …"`. When at least
    /// one outcome was retrieved from a Q2-gap (lexical-only) backend
    /// (iter-68 / iter-69), the line gains a trailing chip
    /// `" [lexical-only: K/T]"`. The chip disappears when
    /// `lexical_only_count == 0` — that's the natural signal that
    /// epistemos-shadow multi-signal wiring is live.
    ///
    /// Used by log output, CLI verbose mode, and the W-21 surface's
    /// terse summary label. The full structured breakdown remains
    /// available via [`FVaultRecallSummary::by_category`].
    pub fn verdict_line(&self) -> String {
        let pct = (self.pass_rate * 100.0).round() as u32;
        let mut breakdown = String::new();
        for (i, cat) in self.by_category.iter().enumerate() {
            if i > 0 {
                breakdown.push_str(", ");
            }
            breakdown.push_str(&format!("{} {}/{}", cat.category, cat.passed, cat.total));
        }
        let breakdown = if breakdown.is_empty() {
            String::from("(no categories)")
        } else {
            breakdown
        };
        let lexical_chip = if self.lexical_only_count > 0 {
            format!(" [lexical-only: {}/{}]", self.lexical_only_count, self.total)
        } else {
            String::new()
        };
        let weak_chip = if self.weak_evidence_count > 0 {
            format!(" [weak-evidence: {}/{}]", self.weak_evidence_count, self.total)
        } else {
            String::new()
        };
        format!(
            "{}/{} passing ({pct}%) — {breakdown}{lexical_chip}{weak_chip}",
            self.passed, self.total
        )
    }
}

/// Compute aggregate pass-rate stats from a fixture sweep. Pure-data;
/// no IO. Called once per W-21 diagnostics refresh.
pub fn summarize(outcomes: &[FVaultRecallRowOutcome]) -> FVaultRecallSummary {
    let total = outcomes.len();
    let passed = outcomes.iter().filter(|o| o.passed).count();
    let failed = total - passed;
    let pass_rate = if total == 0 {
        0.0
    } else {
        passed as f64 / total as f64
    };

    // BTreeMap → deterministic sort by category name. `Outcome.category`
    // is the Debug rendering of `FVaultRecallCategory`, so categories
    // group cleanly.
    let mut grouped: std::collections::BTreeMap<&str, (usize, usize)> =
        std::collections::BTreeMap::new();
    for outcome in outcomes {
        let entry = grouped.entry(outcome.category.as_str()).or_insert((0, 0));
        entry.0 += 1;
        if outcome.passed {
            entry.1 += 1;
        }
    }
    let by_category: Vec<FVaultRecallCategoryStats> = grouped
        .into_iter()
        .map(|(cat, (total, passed))| FVaultRecallCategoryStats {
            category: cat.to_string(),
            total,
            passed,
        })
        .collect();

    let lexical_only_count = outcomes.iter().filter(|o| o.lexical_only).count();
    let weak_evidence_count = outcomes
        .iter()
        .filter(|o| o.evidence_strength == EvidenceStrength::Weak.slug())
        .count();

    FVaultRecallSummary {
        total,
        passed,
        failed,
        pass_rate,
        by_category,
        lexical_only_count,
        weak_evidence_count,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::f_vault_recall_50_fixture::{
        FVaultRecallCategory, FVaultRecallRow,
    };
    use crate::storage::vault::VaultStore;

    /// Build a row inline and run it through `run_row` against a vault
    /// seeded with the expected note. Asserts the pass case: outcome
    /// reports `passed = true`, the expected path appears in
    /// `expected_seen`, `forbidden_present` is empty, and the trace
    /// carries the Lexical signal.
    #[tokio::test]
    async fn run_row_passes_when_expected_note_outranks_others() {
        use crate::storage::retrieval_trace::RetrievalSignal;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");

        // Seed the expected note + 3 unrelated decoys.
        let docs: [(&str, &str); 4] = [
            (
                "notes/mamba_ssm_cache.md",
                "mamba ssm cache mamba ssm cache notes on the Mamba SSM cache architecture",
            ),
            ("notes/general_layout.md", "ui layout design general notes"),
            ("notes/random_a.md", "miscellaneous note about something else"),
            ("notes/random_b.md", "another miscellaneous note unrelated"),
        ];
        for (path, content) in docs.iter() {
            store
                .write(path, content, None, false)
                .await
                .expect("write note");
        }
        store.reload_index().expect("reload index");

        let row = FVaultRecallRow {
            query: "Mamba SSM cache",
            expected_paths: &["notes/mamba_ssm_cache.md"],
            forbidden_paths: &["notes/general_layout.md"],
            category: FVaultRecallCategory::SignalOnly,
            top_n: 5,
            note: "inline test row",
        };

        let (outcome, trace) = run_row(&store, &row).await.expect("run_row");
        assert!(
            outcome.passed,
            "expected pass; outcome = {:?}",
            outcome
        );
        assert_eq!(outcome.expected_seen, vec!["notes/mamba_ssm_cache.md"]);
        assert!(outcome.expected_missed.is_empty());
        assert!(outcome.forbidden_present.is_empty());
        assert_eq!(outcome.query, "Mamba SSM cache");
        assert_eq!(outcome.top_n, 5);
        assert!(
            trace.signal_summary.contains(&RetrievalSignal::Lexical),
            "trace must carry Lexical signal: {:?}",
            trace.signal_summary
        );
        assert!(
            outcome.verdict_line().starts_with("PASS  "),
            "verdict_line should start with PASS: {:?}",
            outcome.verdict_line()
        );
    }

    /// Failure-mode test: when the expected note is NOT in the vault,
    /// the outcome MUST report `passed = false`, the expected path
    /// MUST be in `expected_missed`, and the verdict line MUST start
    /// with "FAIL".
    #[tokio::test]
    async fn run_row_fails_when_expected_note_is_missing() {
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");

        // Seed only decoys — no `mamba_ssm_cache.md`.
        for (path, content) in [
            ("notes/general_layout.md", "ui layout design"),
            ("notes/random.md", "miscellaneous note"),
        ] {
            store
                .write(path, content, None, false)
                .await
                .expect("write note");
        }
        store.reload_index().expect("reload index");

        let row = FVaultRecallRow {
            query: "Mamba SSM cache",
            expected_paths: &["notes/mamba_ssm_cache.md"],
            forbidden_paths: &[],
            category: FVaultRecallCategory::SignalOnly,
            top_n: 5,
            note: "missing-expected fail case",
        };

        let (outcome, _trace) = run_row(&store, &row).await.expect("run_row");
        assert!(!outcome.passed, "expected fail when note is missing");
        assert!(outcome.expected_seen.is_empty());
        assert_eq!(outcome.expected_missed, vec!["notes/mamba_ssm_cache.md"]);
        assert!(outcome.forbidden_present.is_empty());
        assert!(
            outcome.verdict_line().starts_with("FAIL  "),
            "verdict_line should start with FAIL: {:?}",
            outcome.verdict_line()
        );
    }

    /// Iter-22: `summarize` on empty input returns all-zero stats with
    /// `pass_rate = 0.0` (not NaN — division-by-zero guarded).
    #[test]
    fn summarize_empty_returns_zero_pass_rate() {
        let summary = summarize(&[]);
        assert_eq!(summary.total, 0);
        assert_eq!(summary.passed, 0);
        assert_eq!(summary.failed, 0);
        assert_eq!(summary.pass_rate, 0.0);
        assert!(summary.by_category.is_empty());
        assert_eq!(summary.weak_evidence_count, 0);
    }

    /// Iter-22: `summarize` over a mixed pass/fail set computes the
    /// overall counts + rate correctly. Built directly from
    /// `FVaultRecallRowOutcome` instances (no retrieval) so the test
    /// pins the aggregation logic in isolation.
    #[test]
    fn summarize_mixed_pass_fail_computes_rate() {
        let outcomes = vec![
            FVaultRecallRowOutcome {
                query: "a".into(),
                category: "ChattyPrefix".into(),
                top_n: 5,
                passed: true,
                expected_seen: vec!["a.md".into()],
                expected_missed: vec![],
                forbidden_present: vec![],
                top_paths: vec!["a.md".into()],
                lexical_only: false,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
            FVaultRecallRowOutcome {
                query: "b".into(),
                category: "Paraphrase".into(),
                top_n: 5,
                passed: false,
                expected_seen: vec![],
                expected_missed: vec!["b.md".into()],
                forbidden_present: vec![],
                top_paths: vec![],
                lexical_only: false,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
            FVaultRecallRowOutcome {
                query: "c".into(),
                category: "ChattyPrefix".into(),
                top_n: 5,
                passed: true,
                expected_seen: vec!["c.md".into()],
                expected_missed: vec![],
                forbidden_present: vec![],
                top_paths: vec!["c.md".into()],
                lexical_only: false,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
        ];
        let summary = summarize(&outcomes);
        assert_eq!(summary.total, 3);
        assert_eq!(summary.passed, 2);
        assert_eq!(summary.failed, 1);
        assert!((summary.pass_rate - 2.0 / 3.0).abs() < 1e-9);
    }

    /// Iter-35: empty summary renders a stable "0/0 passing (0%)"
    /// line with a placeholder breakdown — guards the W-21 surface
    /// against panicking on an empty vault.
    #[test]
    fn verdict_line_empty_summary_is_stable() {
        let summary = summarize(&[]);
        let line = summary.verdict_line();
        assert!(
            line.starts_with("0/0 passing"),
            "empty summary line must start with 0/0: got {line:?}"
        );
        assert!(
            line.contains("(0%)"),
            "empty summary must render 0% pass rate: got {line:?}"
        );
        assert!(
            line.contains("no categories"),
            "empty summary must render a breakdown placeholder: got {line:?}"
        );
    }

    /// Iter-35: non-empty summary renders "P/T passing (R%) — Cat1
    /// N/M, …" with per-category breakdown in alphabetical order.
    #[test]
    fn verdict_line_renders_per_category_breakdown() {
        let outcomes = vec![
            FVaultRecallRowOutcome {
                query: "q1".into(),
                category: "Paraphrase".into(),
                top_n: 5,
                passed: false,
                expected_seen: vec![],
                expected_missed: vec!["x.md".into()],
                forbidden_present: vec![],
                top_paths: vec![],
                lexical_only: false,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
            FVaultRecallRowOutcome {
                query: "q2".into(),
                category: "ChattyPrefix".into(),
                top_n: 5,
                passed: true,
                expected_seen: vec!["y.md".into()],
                expected_missed: vec![],
                forbidden_present: vec![],
                top_paths: vec!["y.md".into()],
                lexical_only: false,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
            FVaultRecallRowOutcome {
                query: "q3".into(),
                category: "ChattyPrefix".into(),
                top_n: 5,
                passed: true,
                expected_seen: vec!["z.md".into()],
                expected_missed: vec![],
                forbidden_present: vec![],
                top_paths: vec!["z.md".into()],
                lexical_only: false,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
        ];
        let line = summarize(&outcomes).verdict_line();
        assert!(line.starts_with("2/3 passing"));
        assert!(line.contains("(67%)"));
        // ChattyPrefix sorts before Paraphrase (alphabetical).
        let chatty_idx = line
            .find("ChattyPrefix")
            .expect("ChattyPrefix must appear");
        let para_idx = line.find("Paraphrase").expect("Paraphrase must appear");
        assert!(
            chatty_idx < para_idx,
            "ChattyPrefix must sort before Paraphrase in verdict line: {line:?}"
        );
        assert!(line.contains("ChattyPrefix 2/2"));
        assert!(line.contains("Paraphrase 0/1"));
    }

    /// Iter-22: per-category breakdown groups outcomes correctly and
    /// emits stats sorted by category name (deterministic JSON).
    #[test]
    fn summarize_groups_by_category_with_deterministic_order() {
        let outcomes = vec![
            FVaultRecallRowOutcome {
                query: "q1".into(),
                category: "Paraphrase".into(),
                top_n: 5,
                passed: false,
                expected_seen: vec![],
                expected_missed: vec!["x.md".into()],
                forbidden_present: vec![],
                top_paths: vec![],
                lexical_only: false,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
            FVaultRecallRowOutcome {
                query: "q2".into(),
                category: "ChattyPrefix".into(),
                top_n: 5,
                passed: true,
                expected_seen: vec!["y.md".into()],
                expected_missed: vec![],
                forbidden_present: vec![],
                top_paths: vec!["y.md".into()],
                lexical_only: false,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
            FVaultRecallRowOutcome {
                query: "q3".into(),
                category: "ChattyPrefix".into(),
                top_n: 5,
                passed: true,
                expected_seen: vec!["z.md".into()],
                expected_missed: vec![],
                forbidden_present: vec![],
                top_paths: vec!["z.md".into()],
                lexical_only: false,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
            FVaultRecallRowOutcome {
                query: "q4".into(),
                category: "Paraphrase".into(),
                top_n: 5,
                passed: false,
                expected_seen: vec![],
                expected_missed: vec!["w.md".into()],
                forbidden_present: vec![],
                top_paths: vec![],
                lexical_only: false,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
        ];
        let summary = summarize(&outcomes);
        assert_eq!(summary.by_category.len(), 2);
        // Deterministic order: alphabetical by category name.
        assert_eq!(summary.by_category[0].category, "ChattyPrefix");
        assert_eq!(summary.by_category[0].total, 2);
        assert_eq!(summary.by_category[0].passed, 2);
        assert_eq!(summary.by_category[1].category, "Paraphrase");
        assert_eq!(summary.by_category[1].total, 2);
        assert_eq!(summary.by_category[1].passed, 0);
    }

    /// `run_all` returns one outcome per fixture row, in input order.
    /// Pure batched-iteration test; doesn't validate retrieval contracts
    /// (those are covered by `run_row` tests).
    #[tokio::test]
    async fn run_all_returns_outcome_per_row() {
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");

        let fixture: [FVaultRecallRow; 2] = [
            FVaultRecallRow {
                query: "alpha",
                expected_paths: &["a.md"],
                forbidden_paths: &[],
                category: FVaultRecallCategory::SignalOnly,
                top_n: 3,
                note: "",
            },
            FVaultRecallRow {
                query: "beta",
                expected_paths: &["b.md"],
                forbidden_paths: &[],
                category: FVaultRecallCategory::SignalOnly,
                top_n: 3,
                note: "",
            },
        ];

        let outcomes = run_all(&store, &fixture).await.expect("run_all");
        assert_eq!(outcomes.len(), 2);
        assert_eq!(outcomes[0].0.query, "alpha");
        assert_eq!(outcomes[1].0.query, "beta");
        // Empty vault means both fail (no expected hits found).
        assert!(!outcomes[0].0.passed);
        assert!(!outcomes[1].0.passed);
    }

    /// T21 iter-68: `run_row` MUST snapshot
    /// `trace.has_only_lexical_signals()` into the outcome's
    /// `lexical_only` field, and `summarize` MUST count those flags
    /// into `FVaultRecallSummary::lexical_only_count`. Today every
    /// `VaultBackend` impl is in the Q2-gap state, so `lexical_only`
    /// is `true` for every produced outcome and the summary count
    /// equals `outcomes.len()`. When epistemos-shadow integration
    /// lands and the multi-signal trace ships, this assertion breaks
    /// loudly — that's the desired alarm.
    #[tokio::test]
    async fn run_row_snapshots_lexical_only_and_summary_aggregates() {
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");
        // Seed a doc so the retrieval is non-empty (otherwise the
        // signal_summary is empty and `has_only_lexical_signals()`
        // returns false — that case is covered in iter-65 already).
        store
            .write(
                "notes/lexical_only_q2.md",
                "residency governance tier compression notes",
                None,
                false,
            )
            .await
            .expect("write");
        store.reload_index().expect("reload index");

        let row = FVaultRecallRow {
            query: "residency governance",
            expected_paths: &["notes/lexical_only_q2.md"],
            forbidden_paths: &[],
            category: FVaultRecallCategory::SignalOnly,
            top_n: 3,
            note: "iter-68 lexical-only flag wiring",
        };
        let (outcome, _trace) = run_row(&store, &row).await.expect("run_row");
        assert!(
            outcome.lexical_only,
            "Q2 gap: every current backend produces a Lexical-only \
             signal_summary; outcome.lexical_only must be true"
        );

        let summary = summarize(&[outcome]);
        assert_eq!(
            summary.lexical_only_count, 1,
            "summary must count the 1 lexical_only outcome; got {:?}",
            summary
        );
    }

    /// T21 iter-68: `summarize` correctly counts a mix of
    /// lexical-only and multi-signal outcomes. Builds synthetic
    /// outcomes directly so the test pins the aggregator's
    /// arithmetic without touching retrieval.
    #[test]
    fn summarize_lexical_only_count_aggregates_mixed_outcomes() {
        let outcomes = vec![
            FVaultRecallRowOutcome {
                query: "lexical".into(),
                category: "SignalOnly".into(),
                top_n: 5,
                passed: true,
                expected_seen: vec!["a.md".into()],
                expected_missed: vec![],
                forbidden_present: vec![],
                top_paths: vec!["a.md".into()],
                lexical_only: true,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
            FVaultRecallRowOutcome {
                query: "multi".into(),
                category: "SignalOnly".into(),
                top_n: 5,
                passed: true,
                expected_seen: vec!["b.md".into()],
                expected_missed: vec![],
                forbidden_present: vec![],
                top_paths: vec!["b.md".into()],
                lexical_only: false,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
            FVaultRecallRowOutcome {
                query: "also_lexical".into(),
                category: "Adversarial".into(),
                top_n: 1,
                passed: false,
                expected_seen: vec![],
                expected_missed: vec!["c.md".into()],
                forbidden_present: vec![],
                top_paths: vec!["d.md".into()],
                lexical_only: true,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
        ];
        let summary = summarize(&outcomes);
        assert_eq!(summary.lexical_only_count, 2);
        assert_eq!(summary.total, 3);
    }

    /// T21 iter-69: when `lexical_only_count > 0`, the verdict line
    /// gains a trailing chip `[lexical-only: K/T]` for the W-21
    /// surface to render alongside the pass-rate. Mirrors the chip
    /// position and bracketed style used elsewhere in the diagnostics
    /// surface.
    #[test]
    fn verdict_line_shows_lexical_only_chip_when_count_positive() {
        let outcomes = vec![
            FVaultRecallRowOutcome {
                query: "q1".into(),
                category: "SignalOnly".into(),
                top_n: 5,
                passed: true,
                expected_seen: vec!["a.md".into()],
                expected_missed: vec![],
                forbidden_present: vec![],
                top_paths: vec!["a.md".into()],
                lexical_only: true,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
            FVaultRecallRowOutcome {
                query: "q2".into(),
                category: "SignalOnly".into(),
                top_n: 5,
                passed: false,
                expected_seen: vec![],
                expected_missed: vec!["b.md".into()],
                forbidden_present: vec![],
                top_paths: vec![],
                lexical_only: false,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
            FVaultRecallRowOutcome {
                query: "q3".into(),
                category: "SignalOnly".into(),
                top_n: 5,
                passed: true,
                expected_seen: vec!["c.md".into()],
                expected_missed: vec![],
                forbidden_present: vec![],
                top_paths: vec!["c.md".into()],
                lexical_only: true,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
        ];
        let line = summarize(&outcomes).verdict_line();
        assert!(
            line.contains("[lexical-only: 2/3]"),
            "verdict line must show the lexical-only chip when count > 0; got: {line:?}"
        );
        // Pass-rate prefix unchanged.
        assert!(line.starts_with("2/3 passing"));
    }

    /// T21 iter-78: symmetric per-row JSON schema pin for
    /// `FVaultRecallRowOutcome`. The W-21 surface renders each row
    /// click-through as a "leaked / missed delta" view, consuming
    /// the per-row JSON. Pins key shape: `query`, `category`,
    /// `top_n`, `passed`, `expected_seen[]`, `expected_missed[]`,
    /// `forbidden_present[]`, `top_paths[]`, `lexical_only`, and
    /// `evidence_strength`. If any field gets renamed or dropped via
    /// `#[serde(...)]`, the Swift row-detail view fails silently —
    /// this test catches that.
    #[test]
    fn outcome_json_round_trip_pins_w21_row_detail_schema() {
        let outcome = FVaultRecallRowOutcome {
            query: "vault index refresh".into(),
            category: "Paraphrase".into(),
            top_n: 5,
            passed: false,
            expected_seen: vec![],
            expected_missed: vec!["notes/vault_index_reload_canon.md".into()],
            forbidden_present: vec![],
            top_paths: vec![],
            lexical_only: true,
            evidence_strength: EvidenceStrength::Weak.slug().into(),
        };
        let json = serde_json::to_string(&outcome).expect("serialize outcome");
        let parsed: serde_json::Value =
            serde_json::from_str(&json).expect("parse outcome JSON");

        // Identity fields.
        assert_eq!(parsed["query"], "vault index refresh");
        assert_eq!(parsed["category"], "Paraphrase");
        assert_eq!(parsed["top_n"], 5);
        // Pass/fail flag pinned at top level (not nested under
        // "verdict" or similar — Swift code reads it directly).
        assert_eq!(parsed["passed"], false);
        // Q2-gap row flag pinned (iter-68).
        assert_eq!(parsed["lexical_only"], true);
        // Weak-evidence row verdict pinned (iter-438).
        assert_eq!(parsed["evidence_strength"], "weak");
        // Delta arrays — must be JSON arrays so Swift maps to [String].
        assert!(parsed["expected_seen"].is_array());
        assert!(parsed["expected_missed"].is_array());
        assert!(parsed["forbidden_present"].is_array());
        assert!(parsed["top_paths"].is_array());
        assert_eq!(parsed["expected_missed"].as_array().unwrap().len(), 1);
        assert_eq!(
            parsed["expected_missed"][0], "notes/vault_index_reload_canon.md"
        );
    }

    /// T21 iter-77: pin the JSON schema the W-21 Settings →
    /// Diagnostics surface consumes. `FVaultRecallSummary` derives
    /// `Serialize` and the Swift side reads `total`, `passed`,
    /// `failed`, `pass_rate`, `by_category[]`, (iter-68)
    /// `lexical_only_count`, and (iter-438)
    /// `weak_evidence_count` by key. If any of these get renamed via
    /// `#[serde(rename = …)]` or removed, this test breaks loudly
    /// before the Swift consumer sees a silent decode failure.
    #[test]
    fn summary_json_round_trip_pins_w21_schema() {
        let outcomes = vec![
            FVaultRecallRowOutcome {
                query: "q1".into(),
                category: "SignalOnly".into(),
                top_n: 5,
                passed: true,
                expected_seen: vec!["a.md".into()],
                expected_missed: vec![],
                forbidden_present: vec![],
                top_paths: vec!["a.md".into()],
                lexical_only: true,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
            FVaultRecallRowOutcome {
                query: "q2".into(),
                category: "Paraphrase".into(),
                top_n: 5,
                passed: false,
                expected_seen: vec![],
                expected_missed: vec!["b.md".into()],
                forbidden_present: vec![],
                top_paths: vec![],
                lexical_only: false,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
        ];
        let summary = summarize(&outcomes);
        let json = serde_json::to_string(&summary).expect("serialize summary");
        let parsed: serde_json::Value =
            serde_json::from_str(&json).expect("parse summary JSON");

        // Core counts — pinned by key name.
        assert_eq!(parsed["total"], 2);
        assert_eq!(parsed["passed"], 1);
        assert_eq!(parsed["failed"], 1);
        // pass_rate is f64; assert via comparison rather than direct
        // JSON equality to avoid serde_json's number-shape footguns.
        let pass_rate = parsed["pass_rate"].as_f64().expect("pass_rate is f64");
        assert!((pass_rate - 0.5).abs() < 1e-9);

        // iter-68 contract: `lexical_only_count` must be present at
        // the top level (not nested) so the Swift surface can read it
        // alongside `passed` / `total`.
        assert_eq!(parsed["lexical_only_count"], 1);
        assert_eq!(parsed["weak_evidence_count"], 0);

        // by_category[] is the per-category breakdown the surface
        // renders as chips; must be an array of objects with
        // {category, total, passed}.
        let by_cat = parsed["by_category"]
            .as_array()
            .expect("by_category must be an array");
        assert_eq!(by_cat.len(), 2);
        for cat in by_cat {
            assert!(cat["category"].is_string(), "category key must be string");
            assert!(cat["total"].is_number(), "total key must be number");
            assert!(cat["passed"].is_number(), "passed key must be number");
        }
    }

    /// T21 iter-69: the chip disappears when `lexical_only_count == 0`
    /// — the natural signal that epistemos-shadow multi-signal wiring
    /// is live. Also covers the empty-summary case (already covered by
    /// `verdict_line_empty_summary_is_stable`; this is the non-empty
    /// zero-count case).
    #[test]
    fn verdict_line_omits_lexical_only_chip_when_count_zero() {
        let outcomes = vec![FVaultRecallRowOutcome {
            query: "q".into(),
            category: "SignalOnly".into(),
            top_n: 5,
            passed: true,
            expected_seen: vec!["a.md".into()],
            expected_missed: vec![],
            forbidden_present: vec![],
            top_paths: vec!["a.md".into()],
            lexical_only: false,
            evidence_strength: EvidenceStrength::Strong.slug().into(),
        }];
        let line = summarize(&outcomes).verdict_line();
        assert!(
            !line.contains("lexical-only"),
            "verdict line must NOT show the chip when count == 0; got: {line:?}"
        );
        assert!(line.starts_with("1/1 passing"));
    }

    /// T21 iter-438: weak evidence is a typed failure signal, not only
    /// an implicit trace verdict. The summary must aggregate rows that
    /// produced `EvidenceStrength::Weak` and the terse line must expose
    /// that count for W-21 diagnostics.
    #[test]
    fn summarize_weak_evidence_count_and_verdict_chip() {
        let outcomes = vec![
            FVaultRecallRowOutcome {
                query: "weak".into(),
                category: "PureChatter".into(),
                top_n: 5,
                passed: true,
                expected_seen: vec![],
                expected_missed: vec![],
                forbidden_present: vec![],
                top_paths: vec![],
                lexical_only: false,
                evidence_strength: EvidenceStrength::Weak.slug().into(),
            },
            FVaultRecallRowOutcome {
                query: "strong".into(),
                category: "SignalOnly".into(),
                top_n: 5,
                passed: true,
                expected_seen: vec!["a.md".into()],
                expected_missed: vec![],
                forbidden_present: vec![],
                top_paths: vec!["a.md".into()],
                lexical_only: true,
                evidence_strength: EvidenceStrength::Strong.slug().into(),
            },
        ];
        let summary = summarize(&outcomes);
        assert_eq!(summary.weak_evidence_count, 1);

        let line = summary.verdict_line();
        assert!(
            line.contains("[weak-evidence: 1/2]"),
            "verdict line must show the weak-evidence chip when count > 0; got: {line:?}"
        );
    }
}
