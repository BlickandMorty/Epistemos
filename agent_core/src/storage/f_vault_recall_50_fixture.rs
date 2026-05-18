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
    FVaultRecallRow {
        query: "Mamba state-space-model caching",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Paraphrase variant: query says \"state-space-model\" but \
               doc says \"SSM\"; query says \"caching\" but doc says \
               \"cache\". Tantivy's default tokenizer doesn't stem, so \
               this row CURRENTLY FAILS under lexical-only retrieval — \
               that's intentional. It pins the Fix-C deferred work \
               (semantic recall via Model2Vec embeddings, see \
               F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md §4 Fix C): \
               once an RRF-fused VaultBackend ships (e.g. an \
               epistemos-shadow adapter), this row should flip to PASS \
               and the diagnostics surface reflects the upgrade. Until \
               then, the W-21 row shows it as a known-failing \
               regression-test entry, not a bug.",
    },
    FVaultRecallRow {
        query: "show me my notes please",
        // PureChatter rows declare an empty expected_paths because the
        // pass contract is "no useful retrieval; runtime MUST defer or
        // broaden." The runner switches to evidence_strength == Weak
        // as the pass criterion for `FVaultRecallCategory::PureChatter`.
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 5,
        note: "PureChatter variant: every query token is in the chatter \
               list (show / me / my / notes / please). VaultStore's \
               `hybrid_search_with_trace` override detects this, sets \
               `trace.all_chatter_fallback = true`, and falls back to \
               the raw chatter-laden query. The runner's pass criterion \
               for PureChatter is `trace.evidence_strength() == Weak` \
               AND no forbidden path retained — encoding the T21 \
               acceptance bar's \"ask or broaden when evidence is weak\" \
               rule. Empty `expected_paths` is allowed for this category \
               by `every_row_has_non_empty_query_and_expectation`.",
    },
    FVaultRecallRow {
        query: "specific design pattern",
        expected_paths: &[
            "notes/design_pattern_v1.md",
            "notes/design_pattern_v1_copy.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Near-duplicate tie-breaks deep-hardening axis (axis #6): \
               two near-identical docs both carry every query term with \
               equal frequency. Pass requires BOTH retained in top-2 — \
               lexical retrieval under AND-conjunction (3 surviving \
               terms ≤ 3) returns both with effectively-equal BM25; the \
               row pins that no premature MMR / dedup mechanism collapses \
               them. Once a real MMR diversifier ships (Fix-C semantic-\
               recall era, RetrievalSignal::Mmr populated), this row \
               may need to flip its contract — either grow a forbidden \
               near-duplicate (encoding the dedup invariant) or tighten \
               top_n to 1 (one canonical winner). For now, the row \
               documents the pre-MMR baseline: ties retain both copies.",
    },
    FVaultRecallRow {
        query: "Mamba SSL cache",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Typo adversarial axis (axis #4): single-character \
               substitution — user typed \"SSL\" but the doc spells it \
               \"SSM\". Tantivy's default tokenizer doesn't do edit-\
               distance / fuzzy matching, so this row CURRENTLY FAILS — \
               same status class as the iter-12 \"state-space-model\" \
               Paraphrase row (Fix-C deferred). Pins regression coverage \
               for a future fuzzy-match upgrade (e.g. Tantivy's \
               TermSetQuery with edit-distance 1, or an external typo-\
               tolerant retriever). Until then the W-21 diagnostics \
               surface shows this row as a known-failing entry naming \
               the specific deferred work.",
    },
    FVaultRecallRow {
        // Cyrillic multilingual variant: Latin "Mamba" + Cyrillic
        // "кэш" (cache). Extends iter-19's CJK coverage to a second
        // non-Latin script.
        query: "Mamba кэш",
        expected_paths: &["notes/mamba_cyrillic.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Cyrillic multilingual variant (axis: Chinese / Cyrillic \
               / Arabic mixed scripts — 2nd script). Tantivy's default \
               SimpleTokenizer should keep Cyrillic tokens distinct \
               from Latin (no ASCII-folding equivalent for Cyrillic), \
               same uniform behavior as CJK. The iter-19 + iter-28 \
               pair proves the multilingual axis works across at \
               least two distinct non-Latin scripts; Arabic (RTL) is \
               a separate future row that may need bidi-aware \
               attention.",
    },
    FVaultRecallRow {
        // Mixed-script multilingual query: Latin + CJK. `\u{7F13}` is
        // 缓 (cache/buffer), `\u{5B58}` is 存 (store) — together
        // "缓存" = "cache" in Chinese.
        query: "Mamba 缓存",
        expected_paths: &["notes/mamba_chinese.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Multilingual mixed-script adversarial axis: query has \
               Latin (\"Mamba\") + CJK (\"缓存\") tokens separated by \
               whitespace. Tantivy's default SimpleTokenizer keeps CJK \
               chars as a single token (no internal CJK word \
               segmentation) — the indexed doc MUST contain both the \
               Latin and CJK tokens with whitespace between them for \
               the AND-conjunction (2 surviving terms ≤ 3) to match. \
               The forbidden English-only doc carries the Latin token \
               (\"mamba\") but lacks the CJK token, so AND-conjunction \
               must reject it. Pins the operator-prompt deep-hardening \
               axis \"Chinese / Cyrillic / Arabic mixed scripts.\"",
    },
    FVaultRecallRow {
        // Literal quotes are part of the query — Tantivy's QueryParser
        // recognizes them as a PhraseQuery, demanding positional adjacency
        // in the indexed text. `strip_query_chatter` splits on whitespace
        // only, so the quotes survive the strip intact.
        query: "\"residency governance\"",
        expected_paths: &["MASTER_FUSION/3_2_residency_governor.md"],
        forbidden_paths: &["notes/residency_scattered.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Exact-quote adversarial axis: query is a quoted phrase \
               (Tantivy PhraseQuery). The expected doc contains the \
               exact bigram \"residency governance\" at adjacent \
               positions; the forbidden doc contains both tokens but \
               separated (e.g. \"residency tier compression \
               governance\"), so PhraseQuery must reject it. This row \
               pins the deep-hardening axis the operator prompt names \
               under \"exact-quote searches\" — a future tokenizer or \
               parser change that breaks phrase-position semantics \
               flips this row to FAIL.",
    },
    FVaultRecallRow {
        query: "graph node update event",
        expected_paths: &["notes/canonical_graph_event_v3.md"],
        forbidden_paths: &[
            "notes/graph_brainstorm.md",
            "notes/old_node_design.md",
            "notes/event_archive.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        // top_n = 1 forces BM25 ranking discrimination; the OR-conjunction
        // (>3 surviving terms) matches every decoy, so wider top-K would
        // trivially accept them.
        top_n: 1,
        note: "Second Adversarial row (iter-27): different domain from \
               iter-15's design-system row — graph/event substrate. \
               Query has 4 surviving terms → OR-conjunction; decoys each \
               carry ONE of the four. BM25 must rank the canonical doc \
               (all four terms with high TF) above each one-term decoy. \
               The pair iter-15 + iter-27 proves the Adversarial axis \
               works across multiple contexts, not just a single domain.",
    },
    FVaultRecallRow {
        query: "design system hover specification",
        expected_paths: &["notes/design_system_hover_spec.md"],
        forbidden_paths: &[
            "notes/old_hover_brainstorm.md",
            "notes/ux_archive.md",
            "notes/system_overview.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        // top_n = 1 because Adversarial's pass condition is BM25-ranking-
        // discrimination, not bulk-recall. Wider top-K would trivially
        // accept all OR-matching decoys; top-1 forces the canonical to
        // beat them all on raw BM25.
        top_n: 1,
        note: "Adversarial variant: query lives in a chatter-laden \
               domain (UI design) where many docs share SOME query \
               terms. 4 surviving terms (>3) → implicit-OR conjunction \
               — the path most prone to the original \"first 7 \
               irrelevant notes\" bug. With OR-conjunction, every doc \
               matching ANY term is a candidate; the test is whether \
               BM25 ranks the doc with ALL four terms (design + system \
               + hover + specification) above the 3 partial-overlap \
               decoys, each of which carries only ONE of the four \
               terms. top_n = 1 forces that ranking discrimination — \
               wider top-K would trivially accept all OR-matching \
               decoys. If a future tokenizer change disrupts BM25 \
               ranking, this row flips to FAIL and the diagnostics \
               surface flags the regression at the most-prone failure \
               class.",
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

    /// Structural invariant: every row must have a non-empty query and a
    /// positive top_n. `expected_paths` is required for every category
    /// EXCEPT `PureChatter` — PureChatter rows declare "no useful
    /// retrieval; pass via `evidence_strength == Weak`" by carrying an
    /// empty `expected_paths` slice. Every other category MUST have at
    /// least one expected path (the row's positive contract).
    #[test]
    fn every_row_has_non_empty_query_and_expectation() {
        for row in load_canonical() {
            assert!(
                !row.query.is_empty(),
                "fixture row has empty query: {:?}",
                row
            );
            if row.category != FVaultRecallCategory::PureChatter {
                assert!(
                    !row.expected_paths.is_empty(),
                    "non-PureChatter fixture row has no expected_paths: \
                     query={:?} category={:?}",
                    row.query,
                    row.category
                );
            }
            assert!(row.top_n > 0, "top_n must be positive: {:?}", row);
        }
    }

    /// Iter-16: PureChatter rows MUST have empty `expected_paths` (the
    /// row's pass-via-weak-evidence contract assumes no positive hit).
    /// They MUST still have ≥ 1 forbidden decoy so the runner can verify
    /// the chatter-laden query doesn't smuggle in unrelated notes.
    #[test]
    fn pure_chatter_rows_have_empty_expected_and_non_empty_forbidden() {
        let pure_chatter = load_canonical()
            .iter()
            .find(|row| row.category == FVaultRecallCategory::PureChatter)
            .expect("F-VaultRecall-50 must contain at least one PureChatter row");
        assert!(
            pure_chatter.expected_paths.is_empty(),
            "PureChatter row's expected_paths must be empty (the pass \
             contract is evidence_strength == Weak, not a positive hit): \
             got {:?}",
            pure_chatter.expected_paths
        );
        assert!(
            !pure_chatter.forbidden_paths.is_empty(),
            "PureChatter row needs ≥ 1 forbidden decoy so the runner can \
             verify chatter terms don't smuggle in unrelated notes: \
             query = {:?}",
            pure_chatter.query
        );
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
        assert!(
            categories.contains(&FVaultRecallCategory::Paraphrase),
            "fixture must cover Paraphrase (the lexical-mismatch / future \
             semantic-recall class)"
        );
        assert!(
            categories.contains(&FVaultRecallCategory::Adversarial),
            "fixture must cover Adversarial (the canonical \"first 7 \
             irrelevant notes\" failure class)"
        );
        assert!(
            categories.contains(&FVaultRecallCategory::PureChatter),
            "fixture must cover PureChatter (the all-chatter / \
             evidence_strength == Weak class)"
        );
    }

    /// Iter-24: the near-duplicate Synthesis row must be present and
    /// declare ≥ 2 expected paths (the near-duplicate pair) with an
    /// empty forbidden list (no dedup invariant pinned until MMR
    /// ships). top_n MUST equal expected_paths.len() so the contract
    /// is "both copies retained," not "first copy retained."
    #[test]
    fn near_duplicate_synthesis_row_present() {
        let row = load_canonical()
            .iter()
            .find(|r| r.query == "specific design pattern")
            .expect("F-VaultRecall-50 must contain the near-duplicate Synthesis row");
        assert_eq!(row.category, FVaultRecallCategory::Synthesis);
        assert_eq!(
            row.expected_paths.len(),
            2,
            "near-duplicate row needs exactly 2 expected paths (the pair)"
        );
        assert_eq!(
            row.top_n, 2,
            "near-duplicate row needs top_n == expected_paths.len() so \
             the contract is 'both retained,' not 'first retained'"
        );
        assert!(
            row.forbidden_paths.is_empty(),
            "near-duplicate row has no forbidden paths until MMR ships \
             and the dedup contract becomes load-bearing"
        );
    }

    /// Iter-20: a second Paraphrase row covering the typo axis must
    /// exist. The two Paraphrase rows together pin "lexical mismatch
    /// via paraphrase" AND "lexical mismatch via typo" — both classes
    /// the Fix-C deferred semantic / fuzzy-match work would address.
    #[test]
    fn paraphrase_typo_row_present_with_single_char_substitution() {
        let typo_row = load_canonical()
            .iter()
            .find(|row| row.query == "Mamba SSL cache")
            .expect("F-VaultRecall-50 must contain the SSL typo Paraphrase row");
        assert_eq!(typo_row.category, FVaultRecallCategory::Paraphrase);
        // The query carries the typo ("SSL") and the expected doc
        // path implies the correct spelling ("ssm_cache").
        assert!(typo_row.query.contains("SSL"));
        assert!(typo_row.expected_paths.iter().any(|p| p.contains("ssm")));
    }

    /// Iter-20: the fixture must contain ≥ 2 Paraphrase rows now (the
    /// long-form variant from iter-12 and the typo variant from iter-20)
    /// — pins that the Paraphrase category has breadth, not just a
    /// single example.
    #[test]
    fn paraphrase_category_has_at_least_two_rows() {
        let count = load_canonical()
            .iter()
            .filter(|row| row.category == FVaultRecallCategory::Paraphrase)
            .count();
        assert!(
            count >= 2,
            "Paraphrase category needs ≥ 2 rows to demonstrate the \
             axis class has breadth (paraphrase + typo); got {count}"
        );
    }

    /// Iter-19: the multilingual mixed-script row must be present in
    /// the Unicode category and carry at least one CJK codepoint (the
    /// row's whole reason for existing is exercising non-Latin script
    /// tokenization, distinct from iter-8's diacritic row which is
    /// Latin-only).
    #[test]
    fn multilingual_mixed_script_row_present_with_cjk_codepoint() {
        let multi = load_canonical()
            .iter()
            .find(|row| row.query == "Mamba 缓存")
            .expect("F-VaultRecall-50 must contain the multilingual mixed-script row");
        assert_eq!(multi.category, FVaultRecallCategory::Unicode);
        // Verify a CJK codepoint is actually in the query — guards
        // against accidental normalization to ASCII.
        let has_cjk = multi
            .query
            .chars()
            .any(|c| matches!(c as u32, 0x4E00..=0x9FFF));
        assert!(
            has_cjk,
            "multilingual row must carry a CJK codepoint in the query; \
             got query = {:?}",
            multi.query
        );
        assert!(
            !multi.forbidden_paths.is_empty(),
            "multilingual row needs at least one forbidden Latin-only \
             decoy to pin the no-script-fold contract"
        );
    }

    /// Iter-28: the Cyrillic multilingual row must be present and
    /// carry at least one Cyrillic codepoint (Unicode range
    /// U+0400..U+04FF). Distinct from iter-19's CJK row — together
    /// they prove the multilingual axis covers two distinct non-Latin
    /// scripts, not just CJK.
    #[test]
    fn cyrillic_multilingual_row_present_with_cyrillic_codepoint() {
        let cyr = load_canonical()
            .iter()
            .find(|row| row.query == "Mamba кэш")
            .expect("F-VaultRecall-50 must contain the Cyrillic multilingual row");
        assert_eq!(cyr.category, FVaultRecallCategory::Unicode);
        let has_cyrillic = cyr
            .query
            .chars()
            .any(|c| matches!(c as u32, 0x0400..=0x04FF));
        assert!(
            has_cyrillic,
            "Cyrillic row must carry a Cyrillic codepoint in the query; \
             got query = {:?}",
            cyr.query
        );
        assert!(!cyr.forbidden_paths.is_empty());
    }

    /// Iter-17: the exact-quote PhraseQuery row must be present, carry
    /// literal `"` characters in its query string, and pin a forbidden
    /// non-adjacent decoy (the position-sensitivity test).
    #[test]
    fn exact_quote_phrase_row_present_with_literal_quotes() {
        let phrase_row = load_canonical()
            .iter()
            .find(|row| row.query == "\"residency governance\"")
            .expect("F-VaultRecall-50 must contain the exact-quote PhraseQuery row");
        assert!(
            phrase_row.query.starts_with('"') && phrase_row.query.ends_with('"'),
            "exact-quote row's query must be wrapped in literal `\"` chars: got {:?}",
            phrase_row.query
        );
        // Two quote characters required (start + end) — bare quote in
        // middle would be a SignalOnly-with-stray-char row, not a
        // PhraseQuery test.
        assert_eq!(
            phrase_row.query.chars().filter(|c| *c == '"').count(),
            2,
            "exact-quote row's query must contain exactly 2 `\"` chars"
        );
        assert_eq!(phrase_row.category, FVaultRecallCategory::SignalOnly);
        assert!(
            !phrase_row.forbidden_paths.is_empty(),
            "exact-quote row needs a non-adjacent decoy to pin PhraseQuery position semantics"
        );
    }

    /// Iter-15 + iter-27: the Adversarial category must have at least
    /// two rows (different domains: design-system + graph/event). Each
    /// row pins at least 3 forbidden decoys so the BM25 discrimination
    /// test is non-trivial; the pair proves the axis works across
    /// multiple contexts.
    #[test]
    fn adversarial_row_present_with_multiple_decoys() {
        let adversarials: Vec<&FVaultRecallRow> = load_canonical()
            .iter()
            .filter(|row| row.category == FVaultRecallCategory::Adversarial)
            .collect();
        assert!(
            adversarials.len() >= 2,
            "Adversarial category needs ≥ 2 rows (cross-domain breadth); got {}",
            adversarials.len()
        );
        for row in &adversarials {
            assert!(
                row.forbidden_paths.len() >= 3,
                "Adversarial row {:?} needs ≥ 3 forbidden decoys",
                row.query
            );
            for decoy in row.forbidden_paths {
                assert!(!decoy.is_empty(), "decoy path must not be empty");
            }
        }
        // Canonical iter-15 row remains.
        assert!(
            adversarials
                .iter()
                .any(|r| r.query == "design system hover specification"),
            "iter-15 design-system row must still be present"
        );
        // Iter-27 graph row.
        assert!(
            adversarials
                .iter()
                .any(|r| r.query == "graph node update event"),
            "iter-27 graph/event row must be present"
        );
    }

    /// Iter-12: the Paraphrase row must be present, sit in the Paraphrase
    /// category, and carry the canonical "lexical mismatch" form (query
    /// uses long-form / inflected terms that the doc spells differently).
    /// This row CURRENTLY FAILS under lexical-only retrieval — by design,
    /// it pins the Fix-C deferred semantic-recall work.
    #[test]
    fn paraphrase_row_present_and_well_formed() {
        let paraphrase = load_canonical()
            .iter()
            .find(|row| row.category == FVaultRecallCategory::Paraphrase)
            .expect("F-VaultRecall-50 must contain at least one Paraphrase row");
        assert_eq!(paraphrase.query, "Mamba state-space-model caching");
        assert!(
            !paraphrase.expected_paths.is_empty(),
            "Paraphrase row needs an expected hit (the row whose lexical \
             form differs from the query's wording)"
        );
        // The query MUST contain at least one term that the expected doc
        // is NOT expected to contain verbatim — otherwise it's a
        // SignalOnly row, not Paraphrase. We assert the canonical
        // hyphenated long-form "state-space-model" appears in the query;
        // the doc path's name spells the same concept as the bigram
        // "ssm_cache", so the mismatch is real.
        assert!(
            paraphrase.query.contains("state-space-model"),
            "Paraphrase row's query must carry a long-form term that \
             the doc spells differently (the lexical mismatch is the \
             point of this row): query = {:?}",
            paraphrase.query
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
    ///
    /// Rather than substring-matching the raw query (which fails for
    /// rows whose query carries literal `"` — JSON escapes those — see
    /// the iter-17 exact-quote PhraseQuery row), we check structural
    /// integrity: the encoded JSON contains the canonical field names
    /// and parses back to a `serde_json::Value` whose `query` field
    /// equals the row's query verbatim.
    #[test]
    fn fixture_rows_serialize_to_json() {
        for row in load_canonical() {
            let encoded = serde_json::to_string(row).expect("serialize");
            assert!(
                encoded.contains("\"query\":"),
                "encoded JSON missing query field: {}",
                encoded
            );
            assert!(
                encoded.contains("\"expected_paths\":"),
                "encoded JSON missing expected_paths field: {}",
                encoded
            );
            let parsed: serde_json::Value =
                serde_json::from_str(&encoded).expect("re-parse as Value");
            assert_eq!(
                parsed["query"].as_str(),
                Some(row.query),
                "round-tripped query must equal row.query verbatim (no \
                 JSON escaping artifacts): row={:?}",
                row.query
            );
        }
    }
}
