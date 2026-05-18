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
//! - every `row.expected_paths` entry appears in the top `row.top_n`
//!   results, AND
//! - no `row.forbidden_paths` entry appears in the top `row.top_n`
//!   results.
//!
//! Cross-references:
//! - `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md`
//! - `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T21
//!   ("F-VaultRecall-50 fixture visible in diagnostics")
//! - `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` W-21

use serde::Serialize;

use crate::storage::f_vault_recall_50_fixture::FVaultRecallRow;
use crate::storage::retrieval_trace::RetrievalTrace;
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

    let passed = expected_missed.is_empty() && forbidden_present.is_empty();

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
}
