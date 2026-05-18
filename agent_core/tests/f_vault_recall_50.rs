//! Integration test: F-VaultRecall-50 fixture end-to-end against a real
//! Tantivy-backed `VaultStore`.
//!
//! Seeds a temp vault with synthetic content matching each canonical
//! fixture row's contract, runs the iter-7 runner across the whole
//! fixture, and asserts that the known-passing categories
//! (`ChattyPrefix`, `SignalOnly`, `Unicode`, `Synthesis`) pass under
//! the current lexical-only retrieval, while the known-failing
//! `Paraphrase` row fails as designed — pinning the Fix-C deferred
//! semantic-recall work (per
//! `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` §4 Fix C).
//!
//! This is the WRV-floor test for T21: one execution exercises
//! - Fix-B (`strip_query_chatter` + `set_conjunction_by_default`)
//! - Fix-C (raw BM25, no clamp)
//! - `VaultStore::hybrid_search_with_trace` override (true pool size,
//!   effective_query, all-chatter detection)
//! - `RetrievalTrace` typed surface
//! - `F-VaultRecall-50` runner (`run_row`, `FVaultRecallRowOutcome`)
//!
//! Scope-locked: uses only public `agent_core::storage::*` APIs.

use agent_core::storage::f_vault_recall_50_fixture::{
    load_canonical, FVaultRecallCategory,
};
use agent_core::storage::f_vault_recall_runner::run_row;
use agent_core::storage::vault::{VaultBackend, VaultStore};

/// Seed a temp `VaultStore` with content that satisfies every canonical
/// fixture row's pass contract. The synthetic vault is structured so
/// that:
/// - Each `expected_paths` doc contains all of its query's signal terms
///   (so the AND-conjunction on ≤ 3 surviving terms matches).
/// - Each `forbidden_paths` doc contains plausible chatter / decoy
///   content but NONE of the query's signal terms (so the row's
///   "must not appear" contract holds).
/// - The shared docs (`MASTER_FUSION/3_2_residency_governor.md` is
///   expected by rows 1 + 4; `notes/mamba_ssm_cache.md` is expected by
///   row 2 + intentionally fails row 5's paraphrase query) carry
///   content that simultaneously satisfies the rows that name them.
async fn seed_synthetic_vault_for_fixture(store: &VaultStore) {
    // Pairs of (path, content). Content authored so the same set of
    // docs supports every canonical row's pass/fail expectations.
    let seeds: &[(&str, &str)] = &[
        // Rows 1 (ChattyPrefix) + 4 (Synthesis) — shared expected hit.
        (
            "MASTER_FUSION/3_2_residency_governor.md",
            "residency governance tier compression governance residency tier compression",
        ),
        // Row 4 Synthesis second authoritative source.
        (
            "MASTER_FUSION/4_compression_tier_doctrine.md",
            "tier compression governance doctrine compression tier governance tier",
        ),
        // Row 1 ChattyPrefix forbidden decoys — chatter-laden but no
        // residency-governance signal terms.
        ("ui/hermes_branding.md", "ui branding hermes design feel"),
        ("ui/character_dna_specs.md", "character dna design specs visual"),
        ("user_hardware.md", "user hardware specifications M2 Pro 16 GB"),
        // Rows 2 (SignalOnly) + 5 (Paraphrase) — shared doc.
        // Content has mamba/ssm/cache (Row 2 passes via AND-conjunction)
        // but explicitly NOT "state-space-model" or "caching" (so
        // Row 5's Paraphrase query fails the AND-conjunction — the
        // doc has only "Mamba" out of the 3 query terms).
        (
            "notes/mamba_ssm_cache.md",
            "mamba ssm cache mamba ssm cache architecture notes",
        ),
        // Row 2 SignalOnly forbidden — lexically distant doc.
        (
            "notes/generic_attention_overview.md",
            "attention softmax overview generic transformer notes",
        ),
        // Row 3 Unicode expected — content with diacritics.
        (
            "notes/unicode_resume_filter.md",
            "naïve résumé filter naïve résumé filter notes",
        ),
        // Row 3 Unicode forbidden — ASCII-only variant. Tantivy's
        // default tokenizer keeps diacritics, so "naïve" ≠ "naive";
        // the AND-conjunction must reject this doc.
        (
            "notes/ascii_only_resume.md",
            "naive resume filter naive resume filter notes",
        ),
    ];
    for (path, content) in seeds {
        store
            .write(path, content, None, false)
            .await
            .expect("write seed note");
    }
    store.reload_index().expect("reload index");
}

/// End-to-end: every fixture row evaluated against a synthetic vault
/// that satisfies its pass contract. Known-passing categories must
/// pass; the Paraphrase row must fail (pins Fix-C deferred work).
#[tokio::test]
async fn f_vault_recall_50_canonical_rows_against_seeded_vault() {
    let vault_root = tempfile::tempdir().expect("temp vault");
    let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
        .expect("open vault");
    seed_synthetic_vault_for_fixture(&store).await;

    let fixture = load_canonical();
    let mut passed_rows = Vec::new();
    let mut failed_rows = Vec::new();
    for row in fixture {
        let (outcome, _trace) = run_row(&store, row).await.expect("run_row");
        if outcome.passed {
            passed_rows.push((row.category, row.query, outcome));
        } else {
            failed_rows.push((row.category, row.query, outcome));
        }
    }

    // Categorize expected results.
    // Currently-passing (lexical-only retrieval, Fix-B + Fix-C in place):
    //   ChattyPrefix, SignalOnly, Unicode, Synthesis.
    // Currently-failing (pins V1.x Fix-C semantic recall):
    //   Paraphrase.
    let expected_pass_count = fixture
        .iter()
        .filter(|r| r.category != FVaultRecallCategory::Paraphrase)
        .count();
    let expected_fail_count = fixture.len() - expected_pass_count;

    assert_eq!(
        passed_rows.len(),
        expected_pass_count,
        "expected {} rows passing; got {}. Failed rows: {:#?}",
        expected_pass_count,
        passed_rows.len(),
        failed_rows
            .iter()
            .map(|(c, q, o)| (*c, *q, o.expected_missed.clone(), o.forbidden_present.clone()))
            .collect::<Vec<_>>()
    );
    assert_eq!(
        failed_rows.len(),
        expected_fail_count,
        "expected {} rows failing (Paraphrase pinned to Fix-C deferred); \
         got {}. Currently-failing categories: {:?}",
        expected_fail_count,
        failed_rows.len(),
        failed_rows.iter().map(|(c, _, _)| *c).collect::<Vec<_>>()
    );

    // The single failing row MUST be Paraphrase. If a different category
    // fails, something regressed.
    assert!(
        failed_rows
            .iter()
            .all(|(c, _, _)| *c == FVaultRecallCategory::Paraphrase),
        "only Paraphrase rows may fail under lexical-only retrieval; \
         got failures in: {:?}",
        failed_rows.iter().map(|(c, _, _)| *c).collect::<Vec<_>>()
    );

    // The Paraphrase row MUST report its missed expected path
    // (notes/mamba_ssm_cache.md) — the row exists to document exactly
    // this miss.
    let paraphrase_outcome = failed_rows
        .first()
        .map(|(_, _, o)| o.clone())
        .expect("at least one failing row must be Paraphrase");
    assert!(
        paraphrase_outcome
            .expected_missed
            .iter()
            .any(|p| p == "notes/mamba_ssm_cache.md"),
        "Paraphrase row must report mamba_ssm_cache.md as expected_missed; \
         got expected_missed = {:?}",
        paraphrase_outcome.expected_missed
    );
}

/// Smaller-scope sanity check: the canonical 1:15 PM ChattyPrefix row
/// passes against the seeded vault AND the trace records the Fix-B
/// chatter strip transformation (the load-bearing T21 evidence that
/// the original bug is structurally fixed).
#[tokio::test]
async fn canonical_chatty_prefix_row_passes_with_fix_b_trace() {
    let vault_root = tempfile::tempdir().expect("temp vault");
    let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
        .expect("open vault");
    seed_synthetic_vault_for_fixture(&store).await;

    let row = load_canonical()
        .iter()
        .find(|r| r.category == FVaultRecallCategory::ChattyPrefix)
        .expect("fixture must contain a ChattyPrefix row");
    let (outcome, trace) = run_row(&store, row).await.expect("run_row");

    assert!(
        outcome.passed,
        "the canonical 1:15 PM scene row MUST pass — this is the row \
         that the entire T21 mission exists to make pass. Outcome: {:?}",
        outcome
    );
    assert_eq!(outcome.expected_seen, vec!["MASTER_FUSION/3_2_residency_governor.md"]);
    assert!(outcome.forbidden_present.is_empty());

    // Fix-B is observable in the trace.
    assert_eq!(
        trace.effective_query, "residency governance",
        "Fix-B chatter strip must reduce the chatty input to its signal-bearing terms"
    );
    assert!(
        trace.notes.iter().any(|n| n.contains("Fix-B chatter strip")),
        "trace must carry the Fix-B note: {:?}",
        trace.notes
    );
    assert!(
        trace.notes.iter().any(|n| n.contains("AND conjunction applied")),
        "trace must carry the AND-conjunction note (2 surviving terms ≤ 3): {:?}",
        trace.notes
    );
}
