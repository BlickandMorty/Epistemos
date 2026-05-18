//! F-VaultRecall-50 fixture — canonical regression set for the Epistemos
//! vault retrieval contract.
//!
//! Each row is a (query, expected_paths, forbidden_paths, category) tuple
//! that the vault retrieval ladder must handle correctly for the
//! "first 7 irrelevant notes" failure to remain structurally impossible.
//! The fixture is the load-bearing F-VaultRecall-50 falsifier for the
//! M2 Pro hardware floor; it does NOT exercise retrieval here (that's
//! per-iter integration work) — it stages the typed contract so future
//! iters can wire it to the Settings → Diagnostics → "Vault recall health"
//! row (W-21) and the Brain Panel "Retrieved by" surface.
//!
//! Cross-references:
//! - `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` (root diagnosis)
//! - `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T21
//!   ("F-VaultRecall-50 fixture visible in diagnostics")
//! - `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` W-21
//!   (Settings → Diagnostics → "Vault recall health" row)
//! - `docs/fusion/DAY_IN_THE_LIFE_POWER_USER_2026_05_16.md` 1:15 PM scene

use serde::Serialize;

/// Categorical bucket for a fixture row. Used by the diagnostics surface
/// to break down pass rate per query class so the user can see which
/// failure modes regressed without scanning all 50 rows.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize)]
pub enum FVaultRecallCategory {
    /// User query with chatty prefix; signal terms are well-formed.
    /// Canonical example: "Pull my notes on residency governance".
    ChattyPrefix,
    /// User query without any chatter, just topical terms.
    SignalOnly,
    /// User query is entirely chatter (e.g. "show me my notes").
    /// Contract: ladder must defer or broaden, never silently return
    /// arbitrary index-order notes.
    PureChatter,
    /// Paraphrase: user terms don't exactly match doc terms.
    /// Lexical-only retrieval fails; semantic / fusion must save it.
    Paraphrase,
    /// Synthesis: correct answer requires citing 2+ notes.
    Synthesis,
    /// Adversarial: the docs lexically match chatter; correct answer
    /// requires semantic / graph signals.
    Adversarial,
    /// Unicode / non-ASCII query.
    Unicode,
}

/// One canonical row in the F-VaultRecall-50 set.
///
/// `&'static str` everywhere so the entire fixture lives in `.rodata`
/// and can be embedded into the Settings diagnostics surface with no
/// allocation or IO. Future overlay sources (e.g. power-user custom
/// fixtures from a JSON file in `~/.epistemos/`) wrap this type in
/// an owned variant rather than complicating the canonical case.
#[derive(Debug, Clone, Serialize)]
pub struct FVaultRecallRow {
    /// The user-facing query string fed to the retrieval ladder.
    pub query: &'static str,
    /// Vault paths that MUST appear in the top-`top_n` result set for
    /// this row to pass (must-contain). At least one is required.
    pub expected_paths: &'static [&'static str],
    /// Vault paths that MUST NOT appear in the top-`top_n` result set.
    /// For the canonical 1:15 PM scene this is the "first 7 irrelevant
    /// notes" set (UI design, Hermes branding, character DNA specs,
    /// user_hardware.md) that the original bug surfaced.
    pub forbidden_paths: &'static [&'static str],
    /// The query category, used by the diagnostics breakdown.
    pub category: FVaultRecallCategory,
    /// Top-N window the contract applies to. The canonical bug
    /// requires the expected paths to be in the top 7.
    pub top_n: usize,
    /// Free-form note for humans reading the fixture diff.
    pub note: &'static str,
}

/// The 50-row F-VaultRecall fixture. The full row set will grow one row
/// per iter so each addition is reviewable in isolation; this stub seeds
/// the canonical Day-in-the-Life 1:15 PM scene so the loader contract is
/// in place from iter-2 forward.
pub const F_VAULT_RECALL_50_FIXTURE: &[FVaultRecallRow] = &[
    FVaultRecallRow {
        query: "Pull my notes on residency governance",
        expected_paths: &["MASTER_FUSION/3_2_residency_governor.md"],
        forbidden_paths: &[
            "ui/hermes_branding.md",
            "ui/character_dna_specs.md",
            "user_hardware.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Day-in-the-Life 1:15 PM canonical bug — chatty prefix must \
               be stripped (Fix B, shipped iter 81) and BM25 scores must \
               be raw so the floor ladder works (Fix C, shipped iter b812ba618). \
               Residency-governance notes must outrank UI/branding/hardware \
               chatter. This is THE row that the entire T21 mission exists \
               to make pass.",
    },
    FVaultRecallRow {
        query: "Mamba SSM cache",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &["notes/generic_attention_overview.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "SignalOnly variant: three topical terms with no chatter. \
               Pins the no-op-strip path (strip_query_chatter returns the \
               input unchanged) AND the implicit-AND conjunction path \
               (3 surviving terms ≤ 3, so set_conjunction_by_default \
               fires). A doc must contain all three of {mamba, ssm, cache} \
               to rank; the generic-attention forbidden path tests that \
               an OR-shaped match cannot smuggle in unrelated notes that \
               share only some of the terms.",
    },
    FVaultRecallRow {
        // Diacritics are intentional — this row exists to pin the
        // non-ASCII tokenization path. Note `\u{00EF}` = ï, `\u{00E9}` = é.
        query: "naïve résumé filter",
        expected_paths: &["notes/unicode_resume_filter.md"],
        forbidden_paths: &["notes/ascii_only_resume.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Unicode variant: query carries diacritics (ï, é). Pins \
               Tantivy's default UTF-8 tokenizer behavior — the indexed \
               doc must contain the exact diacritic forms for the AND-\
               conjunction (3 surviving terms ≤ 3) to match. An ASCII-\
               only doc that says \"naive resume\" must NOT smuggle in \
               via lossy normalization (the forbidden path enforces \
               the no-fold contract; if Tantivy's tokenizer starts \
               folding diacritics by default, this row flips to FAIL \
               and the diagnosis surface flags the regression).",
    },
    FVaultRecallRow {
        query: "tier compression governance",
        expected_paths: &[
            "MASTER_FUSION/3_2_residency_governor.md",
            "MASTER_FUSION/4_compression_tier_doctrine.md",
        ],
        forbidden_paths: &["ui/hermes_branding.md"],
        category: FVaultRecallCategory::Synthesis,
        top_n: 7,
        note: "Synthesis variant: query implicates two related substrate \
               concepts (residency governance and tier compression). Pass \
               requires BOTH expected paths in top-7, not just one — \
               this is the row that catches \"answer cites just the most \
               obvious note and ignores the synthesis pair.\" 3 surviving \
               terms (no chatter) → AND conjunction fires; each expected \
               doc must contain all of {tier, compression, governance} \
               for the row to pass. Builds on the iter-2 row's residency \
               governor concept by demanding a second authoritative \
               source.",
    },
];

/// Load the canonical fixture. Returns the static slice in a typed wrapper
/// so future iters can extend with a JSON file overlay (for power-user
/// custom fixtures) without breaking the public signature.
pub fn load_canonical() -> &'static [FVaultRecallRow] {
    F_VAULT_RECALL_50_FIXTURE
}

/// Total row count, exposed so diagnostics can render "12 / 50 passing"
/// or similar without re-counting. Constant-eval'd at compile time.
pub const fn fixture_size() -> usize {
    F_VAULT_RECALL_50_FIXTURE.len()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The fixture must have at least one row (the canonical 1:15 PM
    /// scene) at all times. Future rows are added one at a time per
    /// the T21 iter cadence; this floor never goes to zero.
    #[test]
    fn fixture_has_at_least_canonical_row() {
        let fixture = load_canonical();
        assert!(
            !fixture.is_empty(),
            "F-VaultRecall-50 fixture must have ≥ 1 row"
        );
        assert_eq!(fixture.len(), fixture_size());
    }

    /// Structural invariant: every row must have a non-empty query and
    /// ≥ 1 expected_path. An empty expected_paths means "no positive
    /// contract" — that's not a meaningful regression row and must not
    /// land in the fixture even temporarily.
    #[test]
    fn every_row_has_non_empty_query_and_expectation() {
        for row in load_canonical() {
            assert!(
                !row.query.is_empty(),
                "fixture row has empty query: {:?}",
                row
            );
            assert!(
                !row.expected_paths.is_empty(),
                "fixture row has no expected_paths: query={:?}",
                row.query
            );
            assert!(row.top_n > 0, "top_n must be positive: {:?}", row);
        }
    }

    /// Canonical 1:15 PM scene must be present. This is the load-bearing
    /// regression — the entire T21 mission exists to make this row pass,
    /// so it must remain in the fixture from iter-2 forward.
    #[test]
    fn canonical_residency_governance_row_present() {
        let found = load_canonical()
            .iter()
            .any(|row| row.query == "Pull my notes on residency governance");
        assert!(
            found,
            "F-VaultRecall-50 must contain the canonical 1:15 PM scene query"
        );
    }

    /// `forbidden_paths` and `expected_paths` must not overlap on any row —
    /// a path cannot simultaneously be required and forbidden. Catches
    /// future-iter copy-paste mistakes before they confuse diagnostics.
    #[test]
    fn forbidden_and_expected_paths_are_disjoint_per_row() {
        for row in load_canonical() {
            for forbidden in row.forbidden_paths {
                assert!(
                    !row.expected_paths.contains(forbidden),
                    "row {:?} has path in both expected and forbidden: {}",
                    row.query,
                    forbidden
                );
            }
        }
    }

    /// Iter-6: the SignalOnly "Mamba SSM cache" row must be present, sit
    /// in the SignalOnly category, and have a top_n compatible with
    /// AND-conjunction expectations (3 surviving terms ≤ 3 means the
    /// `set_conjunction_by_default` path fires — see vault.rs).
    #[test]
    fn signal_only_mamba_row_present_and_well_formed() {
        let mamba = load_canonical()
            .iter()
            .find(|row| row.query == "Mamba SSM cache")
            .expect("F-VaultRecall-50 must contain the Mamba SSM cache SignalOnly row");
        assert_eq!(mamba.category, FVaultRecallCategory::SignalOnly);
        assert_eq!(
            mamba.query.split_whitespace().count(),
            3,
            "Mamba row must have exactly 3 signal terms to pin the AND-\
             conjunction path (≤ 3 surviving terms triggers \
             set_conjunction_by_default in vault.rs)"
        );
        assert!(
            !mamba.expected_paths.is_empty(),
            "SignalOnly row needs an expected hit"
        );
        assert!(
            !mamba.forbidden_paths.is_empty(),
            "SignalOnly row should pin at least one forbidden path so an \
             OR-shaped match cannot pass"
        );
    }

    /// Categories represented across the fixture should grow over iters.
    /// At iter-8, ChattyPrefix + SignalOnly + Unicode must all be covered;
    /// the other 4 categories (PureChatter / Paraphrase / Synthesis /
    /// Adversarial) are populated in follow-on iters.
    #[test]
    fn fixture_covers_chatty_prefix_and_signal_only_categories() {
        let categories: std::collections::HashSet<_> = load_canonical()
            .iter()
            .map(|row| row.category)
            .collect();
        assert!(
            categories.contains(&FVaultRecallCategory::ChattyPrefix),
            "fixture must cover ChattyPrefix (the canonical 1:15 PM bug class)"
        );
        assert!(
            categories.contains(&FVaultRecallCategory::SignalOnly),
            "fixture must cover SignalOnly (the no-chatter / AND-conjunction class)"
        );
        assert!(
            categories.contains(&FVaultRecallCategory::Unicode),
            "fixture must cover Unicode (the diacritic / UTF-8 tokenizer class)"
        );
        assert!(
            categories.contains(&FVaultRecallCategory::Synthesis),
            "fixture must cover Synthesis (the multi-source coverage class)"
        );
    }

    /// Iter-11: the Synthesis "tier compression governance" row must be
    /// present, sit in the Synthesis category, and have ≥ 2 expected
    /// paths (otherwise it's not a synthesis case — it's a single-source
    /// SignalOnly row mis-categorized).
    #[test]
    fn synthesis_row_present_with_multiple_expected_paths() {
        let synthesis = load_canonical()
            .iter()
            .find(|row| row.category == FVaultRecallCategory::Synthesis)
            .expect("F-VaultRecall-50 must contain at least one Synthesis row");
        assert!(
            synthesis.expected_paths.len() >= 2,
            "Synthesis row needs ≥ 2 expected_paths (the synthesis class \
             demands multi-source coverage): got {} for query {:?}",
            synthesis.expected_paths.len(),
            synthesis.query
        );
        assert_eq!(synthesis.query, "tier compression governance");
        assert!(
            !synthesis.forbidden_paths.is_empty(),
            "Synthesis row should pin at least one forbidden path"
        );
    }

    /// Iter-8: the Unicode "naïve résumé filter" row must be present,
    /// sit in the Unicode category, and actually contain non-ASCII
    /// codepoints (otherwise the row is mis-categorized).
    #[test]
    fn unicode_diacritic_row_present_and_carries_non_ascii() {
        let unicode_row = load_canonical()
            .iter()
            .find(|row| row.category == FVaultRecallCategory::Unicode)
            .expect("F-VaultRecall-50 must contain at least one Unicode row");
        assert!(
            !unicode_row.query.is_ascii(),
            "Unicode row's query must contain non-ASCII codepoints; \
             got query = {:?}",
            unicode_row.query
        );
        // Specifically the iter-8 canonical row.
        assert_eq!(unicode_row.query, "naïve résumé filter");
        assert!(
            !unicode_row.expected_paths.is_empty(),
            "Unicode row needs an expected hit"
        );
        assert!(
            !unicode_row.forbidden_paths.is_empty(),
            "Unicode row should pin a forbidden ASCII-only path to enforce \
             the no-diacritic-folding contract"
        );
    }

    /// Every row must serialize to JSON cleanly. The Settings diagnostics
    /// surface (W-21) will render fixture results as JSON to the Brain
    /// Panel; this test pins the serialize-side of that contract. The
    /// deserialize-side lands when the JSON overlay (power-user custom
    /// fixtures from `~/.epistemos/`) is wired in a later iter via a
    /// separate `FVaultRecallRowOwned` type.
    #[test]
    fn fixture_rows_serialize_to_json() {
        for row in load_canonical() {
            let encoded = serde_json::to_string(row).expect("serialize");
            assert!(
                encoded.contains(row.query),
                "encoded JSON missing query {:?}: {}",
                row.query,
                encoded
            );
            assert!(
                encoded.contains("expected_paths"),
                "encoded JSON missing expected_paths field: {}",
                encoded
            );
        }
    }
}
