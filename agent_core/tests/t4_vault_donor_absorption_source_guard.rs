//! Source guard for the bounded T4 vault donor extraction.
//!
//! The preserved `Epistemos-t4-vault` worktree's useful uniqueness and
//! query-dedupe hunks are already absorbed by current head. Keep those
//! guardrails pinned here so future salvage loops do not re-port stale donor
//! code or weaken the current retrieval floor.

const RUST_VAULT_RECALL_RUNNER_SOURCE: &str =
    include_str!("../src/storage/f_vault_recall_runner.rs");
const RUST_VAULT_STORE_SOURCE: &str = include_str!("../src/storage/vault.rs");
const SWIFT_SEARCH_INDEX_SOURCE: &str =
    include_str!("../../Epistemos/Sync/SearchIndexService.swift");
const SWIFT_SEARCH_INDEX_TEST_SOURCE: &str =
    include_str!("../../EpistemosTests/SearchIndexTests.swift");

#[test]
fn vault_recall_runner_reports_unique_top_paths() {
    for fragment in [
        "let top_paths = unique_top_paths(&results, row.top_n);",
        "fn unique_top_paths(results: &[SearchResult], top_n: usize) -> Vec<String>",
        "HashSet::with_capacity(top_n.min(results.len()))",
        "seen.insert(path.to_lowercase())",
        "run_row_reports_unique_paths_inside_top_n_window",
    ] {
        assert!(
            RUST_VAULT_RECALL_RUNNER_SOURCE.contains(fragment),
            "current T4 vault recall runner must keep unique result reporting fragment `{fragment}`"
        );
    }
}

#[test]
fn vault_store_keeps_quoted_phrase_from_partial_title_rescue() {
    for fragment in [
        "allow_partial_title_match = quoted_segments(query).is_empty()",
        "title_match_score(&query_titles, &title_keys, allow_partial_title_match)",
        "if !allow_partial {\n        return None;",
        "hybrid_search_quoted_phrase_rejects_partial_title_overlap",
    ] {
        assert!(
            RUST_VAULT_STORE_SOURCE.contains(fragment),
            "current T4 vault store must keep quoted-phrase title fallback guard `{fragment}`"
        );
    }
}

#[test]
fn swift_search_index_keeps_vault_recall_term_dedupe() {
    for fragment in [
        "return uniqueSearchTerms(vaultRecallSignalTerms(from: terms), limit: 20)",
        "private nonisolated static func uniqueSearchTerms(_ terms: [String], limit: Int) -> [String]",
        "for term in terms where seen.insert(term).inserted",
        "#expect(result == \"\\\"recall\\\"*\")",
        "repeatedVaultRecallSignalTermsAreDeduped",
    ] {
        let haystack = if fragment.starts_with("#expect") || fragment.starts_with("repeated") {
            SWIFT_SEARCH_INDEX_TEST_SOURCE
        } else {
            SWIFT_SEARCH_INDEX_SOURCE
        };
        assert!(
            haystack.contains(fragment),
            "current Swift search index must keep vault recall term-dedupe fragment `{fragment}`"
        );
    }
}
