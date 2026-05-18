//! # F-VaultRecall-50 fixture
//!
//! Canonical regression set for the Epistemos vault retrieval contract.
//! Each row is a `(query, expected_paths, forbidden_paths, category)`
//! tuple the vault retrieval ladder must handle correctly for the
//! "first 7 irrelevant notes" failure (Day-in-the-Life 1:15 PM scene)
//! to remain structurally impossible.
//!
//! This module ships **the typed data only**. Retrieval execution is the
//! runner's job ([`crate::storage::f_vault_recall_runner`]); the W-21
//! Settings → Diagnostics → "Vault recall health" row is the Swift
//! surface that consumes the runner output.
//!
//! ## Row schema
//!
//! Every row is a [`FVaultRecallRow`] with `&'static str` fields so the
//! whole fixture lives in `.rodata`:
//!
//! - `query`: the user-facing query string fed to the retrieval ladder.
//!   May carry chatter (`"Pull my notes on …"`), literal `"` quotes for
//!   PhraseQuery (`"\"residency governance\""`), or non-ASCII codepoints
//!   (diacritics, CJK, Cyrillic, Arabic).
//! - `expected_paths`: vault paths that MUST appear in the top
//!   `top_n` result set for the row to pass. Empty only for
//!   [`FVaultRecallCategory::PureChatter`] rows (where the pass
//!   contract is "no useful retrieval; evidence_strength == Weak").
//! - `forbidden_paths`: vault paths that MUST NOT appear in the top
//!   `top_n` result set. Pin the canonical decoys for the row's
//!   failure-mode class (e.g. UI-design notes for the 1:15 PM scene's
//!   chatter-bait).
//! - `category`: failure-mode taxonomy. See category section below.
//! - `top_n`: top-N window the contract applies to. Use `1` for
//!   Adversarial rows whose pass criterion is BM25-ranking
//!   discrimination; `2` for near-duplicate Synthesis rows; `5`–`7`
//!   for ordinary "expected hit in top-K" contracts.
//! - `note`: free-form prose for humans reading the fixture diff —
//!   what the row pins, why this query, what failure mode it
//!   structurally prevents.
//!
//! ## Canonical categories (7 of 7 covered)
//!
//! 1. [`FVaultRecallCategory::ChattyPrefix`] — user query carries chatter
//!    prefix; signal terms are well-formed. Pass requires `strip_query_chatter`
//!    to surface signal-bearing terms. Canonical row: 1:15 PM scene
//!    `"Pull my notes on residency governance"`.
//! 2. [`FVaultRecallCategory::SignalOnly`] — query is well-formed topical
//!    terms with zero chatter. Pass requires the no-op-strip + AND-conjunction
//!    path to fire correctly.
//! 3. [`FVaultRecallCategory::PureChatter`] — every query token is in
//!    `QUERY_CHATTER_WORDS`. Strip empties → fallback to raw query →
//!    `all_chatter_fallback` flag flips → `evidence_strength == Weak`.
//!    `expected_paths` MUST be empty for this category.
//! 4. [`FVaultRecallCategory::Paraphrase`] — query terms don't lexically
//!    match doc terms (paraphrase, typo, inflection). Currently fails
//!    under lexical-only retrieval; pinned as Fix-C deferred regression.
//! 5. [`FVaultRecallCategory::Synthesis`] — query implicates ≥ 2
//!    related concepts; multiple expected hits in top-K. Includes
//!    near-duplicate variants (both copies retained pre-MMR).
//! 6. [`FVaultRecallCategory::Adversarial`] — docs lexically match
//!    chatter or partial-overlap with query; correct doc must rank
//!    above plausible decoys via BM25 ranking (typically `top_n = 1`).
//! 7. [`FVaultRecallCategory::Unicode`] — non-ASCII queries
//!    (diacritics, CJK, Cyrillic, Arabic). Pins Tantivy's UTF-8
//!    tokenizer behavior — no script-folding, direction-agnostic
//!    treatment of LTR + RTL scripts.
//!
//! ## How to add a new fixture row
//!
//! 1. Append a `FVaultRecallRow { … }` literal to
//!    [`F_VAULT_RECALL_50_FIXTURE`] (preserve category ordering for
//!    diff-friendly review; new rows of an existing category go next
//!    to their siblings).
//! 2. Add a structural test in `mod tests` if the row pins a
//!    category-specific invariant (canonical query string, codepoint
//!    range, decoy count). The category-coverage and structural
//!    invariant tests generalize automatically.
//! 3. If the row references paths NOT already seeded by the
//!    integration test, add them to `seed_synthetic_vault_for_fixture`
//!    in `agent_core/tests/f_vault_recall_50.rs`. Decoy content must
//!    NOT share signal terms with the row's query (otherwise the
//!    forbidden contract is trivially false).
//! 4. Verify: `cargo test -p agent_core --lib f_vault_recall` AND
//!    `cargo test -p agent_core --test f_vault_recall_50`. The
//!    integration test's pass/fail counts will adjust automatically
//!    via the `expected_pass_count = fixture.len() - paraphrase_count`
//!    derivation.
//! 5. Refresh `docs/F_VAULT_RECALL_50_2026_05_18.md` §4 inventory.
//!
//! ## Cross-references
//!
//! - [`docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md`](../../../../docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md)
//!   — root diagnosis (the 3 defects this fixture pins against).
//! - [`docs/F_VAULT_RECALL_50_2026_05_18.md`](../../../../docs/F_VAULT_RECALL_50_2026_05_18.md)
//!   — T21 branch summary (acceptance bar, commit log, WRV checklist).
//! - [`docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md`](../../../../docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md)
//!   §4 T21 — fixture-visible-in-diagnostics acceptance clause.
//! - [`docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md`](../../../../docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md)
//!   W-21 — the Settings diagnostics row this fixture binds to.
//! - [`docs/fusion/DAY_IN_THE_LIFE_POWER_USER_2026_05_16.md`](../../../../docs/fusion/DAY_IN_THE_LIFE_POWER_USER_2026_05_16.md)
//!   1:15 PM scene — the canonical failure user story.

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
        query: "Show me my residency governance notes",
        expected_paths: &["MASTER_FUSION/3_2_residency_governor.md"],
        forbidden_paths: &[
            "ui/hermes_branding.md",
            "ui/character_dna_specs.md",
            "user_hardware.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Second ChattyPrefix row (iter-31) — different chatter \
               prefix mix than iter-2's canonical 1:15 PM row \
               (\"Pull my notes on …\"). This one uses \"Show me my … \
               notes\" — chatter tokens {Show, me, my, notes} plus \
               signal {residency, governance}. After strip_query_chatter \
               both rows reduce to the same signal-only form \
               (\"residency governance\"), so they share the same \
               expected/forbidden contract. Pinning two ChattyPrefix \
               rows proves the chatter-strip is robust across prefix \
               variations (imperative \"Pull\" vs \"Show\", possessive \
               \"my\" + generic-referent \"notes\" in different \
               positions). Both rows must pass; together they prevent \
               the strip from being accidentally keyed to a single \
               chatter pattern.",
    },
    FVaultRecallRow {
        query: "Hamiltonian",
        expected_paths: &["notes/hamiltonian_dynamics.md"],
        forbidden_paths: &["notes/general_physics.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Single-term SignalOnly variant (iter-39): the minimal-\
               query path. One surviving term ≤ 3 → AND-conjunction \
               fires on the lone term; doc must contain \"hamiltonian\" \
               (case-folded). The forbidden general-physics doc \
               mentions physics broadly but not Hamiltonian \
               specifically — proves AND-on-one-token still filters \
               correctly. Distinguishes from iter-6's three-term Mamba \
               row and iter-7's quoted phrase by exercising the \
               single-token edge of the surviving-terms count.",
    },
    FVaultRecallRow {
        query: "Get me my tier compression governance notes please",
        expected_paths: &["MASTER_FUSION/3_2_residency_governor.md"],
        forbidden_paths: &[
            "ui/hermes_branding.md",
            "ui/character_dna_specs.md",
            "user_hardware.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Third ChattyPrefix row (iter-47): different topical signal \
               than iter-2 + iter-31 (residency governance) — this one \
               targets the tier-compression-governance trigram. Chatter \
               prefix {Get, me, my, notes, please}; signal terms \
               {tier, compression, governance}. After strip: \
               \"tier compression governance\" — same effective query as \
               the Synthesis row 4 (iter-11). The two rows share an \
               expected hit (residency_governor.md contains all three \
               terms) but Synthesis adds a 2nd expected (compression_\
               tier_doctrine.md) while this ChattyPrefix asserts only the \
               first. Demonstrates strip-robust + multi-signal-coverage.",
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
        query: "tell me what you want",
        // 2nd PureChatter variant. Every token in QUERY_CHATTER_WORDS:
        // "tell" (imperative), "me" (first-person), "what" (wh-question),
        // "you" (second-person), "want" (filler). Different chatter mix
        // than iter-16's row 6 — verifies the all_chatter_fallback
        // contract is not accidentally pinned to one specific token set.
        expected_paths: &[],
        forbidden_paths: &["notes/totally_unrelated_a.md"],
        category: FVaultRecallCategory::PureChatter,
        top_n: 5,
        note: "PureChatter variant 2 (iter-30): same contract shape as \
               iter-16's row 6 but a structurally distinct chatter \
               pattern (imperative + wh-question + filler vs row 6's \
               imperative + possessive + generic-referent + please). \
               Pinning two PureChatter rows proves the \
               all_chatter_fallback detection isn't accidentally \
               keyed to one specific token combination — any all-\
               chatter input must flip evidence_strength to Weak.",
    },
    FVaultRecallRow {
        query: "give me all the things please",
        // 3rd PureChatter variant (iter-49). Every token in
        // QUERY_CHATTER_WORDS: "give" (imperative), "me" (first-person),
        // "all" (misc filler), "the" (stop-word), "things" (generic-
        // referent), "please" (discourse particle). Six chatter
        // categories represented — broadest variant.
        expected_paths: &[],
        forbidden_paths: &["notes/totally_unrelated_b.md"],
        category: FVaultRecallCategory::PureChatter,
        top_n: 5,
        note: "PureChatter variant 3 (iter-49): same contract shape as \
               iter-16's row 6 and iter-30's row 14, but a structurally \
               distinct chatter mix that draws from SIX of the seven \
               chatter-token categories (imperative + first-person + \
               misc filler + stop-word + generic-referent + discourse). \
               Three PureChatter rows together prove the \
               all_chatter_fallback detection is robust across the \
               breadth of canonical chatter pattern combinations — not \
               just the most common subset. PureChatter category now \
               at depth 3 alongside SignalOnly / Synthesis / Adversarial \
               / ChattyPrefix.",
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
        query: "hardware floor falsifier",
        expected_paths: &[
            "notes/m2_pro_hardware_floor.md",
            "notes/falsifier_handbook.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 3,
        note: "Third Synthesis row (iter-45): hardware-falsifier domain \
               distinct from iter-11's tier/compression/governance domain \
               and iter-24's near-duplicate-design-pattern. Query has 3 \
               surviving terms → AND-conjunction; each expected doc must \
               contain all of {hardware, floor, falsifier} for the pair \
               to land in top-3. The three Synthesis rows now span \
               three concept families — generic synthesis (tier compression), \
               near-duplicate (design pattern), and substrate-canon \
               (hardware floor). top_n = 3 leaves room for one decoy \
               doc to slip into top-3 without invalidating the contract.",
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
        // Arabic multilingual variant (axis #3 final script): Latin
        // "Mamba" + Arabic "كاش" (kash — cache transliterated). Arabic
        // is RTL in rendering but Tantivy's SimpleTokenizer is
        // direction-agnostic: it tokenizes on whitespace and keeps
        // Arabic codepoints as a single token, same as CJK + Cyrillic.
        query: "Mamba كاش",
        expected_paths: &["notes/mamba_arabic.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Arabic multilingual variant (axis: Chinese / Cyrillic / \
               Arabic mixed scripts — completes the 3-script trifecta). \
               RTL display is a rendering concern, not a tokenization \
               one; Tantivy treats Arabic codepoints (U+0600..U+06FF) \
               the same as Cyrillic / CJK — whitespace-tokenized, no \
               script-folding. The iter-19 + iter-28 + iter-32 trio \
               proves the multilingual axis works uniformly across all \
               three operator-prompt-named non-Latin scripts.",
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
        query: "agent runtime substrate trace",
        expected_paths: &["notes/agent_runtime_v2_substrate.md"],
        forbidden_paths: &[
            "notes/agent_brainstorm.md",
            "notes/runtime_old_design.md",
            "notes/substrate_concepts.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Third Adversarial row (iter-43): agent-runtime domain — \
               distinct from iter-15's design-system and iter-27's \
               graph/event domains. Same structural shape (4 surviving \
               terms → OR conjunction; 3 partial-overlap decoys; \
               top_n = 1 forces BM25-ranking discrimination), different \
               lexical universe. Three Adversarial rows now span three \
               domain families — proves the failure mode is \
               domain-agnostic and the contract holds across the \
               substrate-canon vocabulary itself (\"agent\", \
               \"runtime\", \"substrate\", \"trace\" all heavy-use \
               terms in System G / Invader Agent canon).",
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

/// T21 iter-36 (2026-05-18): the canonical target row count baked into
/// the falsifier name (F-VaultRecall-**50**). Used by the W-21
/// diagnostics surface to render "16 / 50 passing" — the ratio shows
/// progress toward the full target. Adding rows beyond 50 is allowed
/// (the falsifier name is a floor, not a ceiling) — the constant
/// exists so a Swift caller has a single source of truth for the
/// nominal target.
pub const F_VAULT_RECALL_50_TARGET_ROWS: usize = 50;

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

    /// Iter-36: the falsifier's name (F-VaultRecall-**50**) implies a
    /// 50-row nominal target. The exposed `F_VAULT_RECALL_50_TARGET_ROWS`
    /// constant is the single source of truth for that target value.
    /// `fixture_size()` may grow past it (the name is a floor) but
    /// this sanity test guards against typo-style regressions (e.g.
    /// changing the constant from 50 to 0 or some accidental value).
    #[test]
    fn target_rows_constant_equals_falsifier_name_number() {
        assert_eq!(
            F_VAULT_RECALL_50_TARGET_ROWS, 50,
            "F-VaultRecall-50 implies 50 nominal rows; the constant \
             must match the falsifier's name"
        );
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

    /// Iter-16 + iter-30: every PureChatter row MUST have empty
    /// `expected_paths` (the row's pass-via-weak-evidence contract
    /// assumes no positive hit) AND ≥ 1 forbidden decoy so the runner
    /// can verify chatter terms don't smuggle in unrelated notes. The
    /// fixture must contain ≥ 2 PureChatter rows (iter-30: cross-
    /// pattern breadth ensures the all_chatter_fallback detection
    /// isn't accidentally keyed to one specific token combination).
    #[test]
    fn pure_chatter_rows_have_empty_expected_and_non_empty_forbidden() {
        let pure_chatter: Vec<&FVaultRecallRow> = load_canonical()
            .iter()
            .filter(|row| row.category == FVaultRecallCategory::PureChatter)
            .collect();
        assert!(
            pure_chatter.len() >= 2,
            "PureChatter category needs ≥ 2 rows for chatter-pattern \
             breadth; got {}",
            pure_chatter.len()
        );
        for row in &pure_chatter {
            assert!(
                row.expected_paths.is_empty(),
                "PureChatter row {:?} expected_paths must be empty",
                row.query
            );
            assert!(
                !row.forbidden_paths.is_empty(),
                "PureChatter row {:?} needs ≥ 1 forbidden decoy",
                row.query
            );
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

    /// Iter-31: the ChattyPrefix category must have ≥ 2 rows for cross-
    /// prefix breadth (each row must demonstrate a structurally distinct
    /// chatter mix). iter-2's row uses "Pull my notes on …"; iter-31's
    /// row uses "Show me my … notes" — different imperative + different
    /// chatter-token order. Both strip to the same signal-only form.
    #[test]
    fn chatty_prefix_category_has_at_least_two_rows() {
        let count = load_canonical()
            .iter()
            .filter(|row| row.category == FVaultRecallCategory::ChattyPrefix)
            .count();
        assert!(
            count >= 2,
            "ChattyPrefix category needs ≥ 2 rows for cross-prefix breadth; \
             got {count}"
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

    /// Iter-32: the Arabic multilingual row must be present and carry
    /// at least one Arabic codepoint (Unicode range U+0600..U+06FF).
    /// Completes the 3-script trifecta (CJK + Cyrillic + Arabic) for
    /// the multilingual deep-hardening axis.
    #[test]
    fn arabic_multilingual_row_present_with_arabic_codepoint() {
        let ar = load_canonical()
            .iter()
            .find(|row| row.query == "Mamba كاش")
            .expect("F-VaultRecall-50 must contain the Arabic multilingual row");
        assert_eq!(ar.category, FVaultRecallCategory::Unicode);
        let has_arabic = ar
            .query
            .chars()
            .any(|c| matches!(c as u32, 0x0600..=0x06FF));
        assert!(
            has_arabic,
            "Arabic row must carry an Arabic codepoint in the query; \
             got query = {:?}",
            ar.query
        );
        assert!(!ar.forbidden_paths.is_empty());
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
