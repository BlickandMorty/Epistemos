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
        // 5th ChattyPrefix row (iter-82). Survivors after
        // strip_query_chatter: {vault, index, reload} — 3 terms →
        // AND-conjunction. Reuses iter-66 storage/vault canon corpus
        // (canonical + 3 partial-overlap decoys). The retrieval
        // pattern matches iter-81's SignalOnly row, but THIS row
        // exercises the chatter-strip path (raw query has 7 chatter
        // tokens + 3 signal tokens). Pinning the strip in the
        // storage/vault domain — 5th distinct signal domain for
        // ChattyPrefix.
        query: "Pull my notes on the vault index reload please",
        expected_paths: &["notes/vault_index_reload_canon.md"],
        forbidden_paths: &[
            "notes/vault_brainstorm.md",
            "notes/old_index_design.md",
            "notes/tantivy_misc_notes.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Fifth ChattyPrefix row (iter-82): storage/vault canon \
               domain — 5th distinct signal domain after iters 2/31 \
               (residency-governance), iter-47 (tier-compression-\
               governance), iter-71 (agent-runtime-trace). Chatter \
               prefix {Pull, my, notes, on, the, please}; survivors \
               {vault, index, reload}. Same canonical/decoys as \
               iter-81 SignalOnly but exercises the strip path \
               instead of the no-op path — pins strip-robust × \
               5 signal domains.",
    },
    FVaultRecallRow {
        // 4th ChattyPrefix row (iter-71). Survivors after
        // strip_query_chatter: {agent, runtime, trace} — 3 terms →
        // AND-conjunction → only docs carrying all three match. The
        // iter-43 Adversarial seed corpus already contains the
        // canonical doc with all of {agent, runtime, substrate, trace}
        // and decoys each carrying ONE of them. AND-on-{agent, runtime,
        // trace} matches only the canonical (decoys have ≤ 1 of the 3
        // signal terms), so top_paths is just the canonical.
        query: "Can you find my agent runtime trace notes please",
        expected_paths: &["notes/agent_runtime_v2_substrate.md"],
        forbidden_paths: &[
            "notes/agent_brainstorm.md",
            "notes/runtime_old_design.md",
            "notes/substrate_concepts.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Fourth ChattyPrefix row (iter-71): new signal domain \
               (agent-runtime-trace) distinct from iters 2/31's \
               residency-governance and iter-47's tier-compression-\
               governance. Reuses the iter-43 Adversarial seed corpus \
               (canonical + 3 partial-overlap decoys) so no new \
               synthetic notes are needed. Chatter prefix {Can, you, \
               find, my, notes, please}; survivors {agent, runtime, \
               trace} — 3 terms triggers AND-conjunction (\
               set_conjunction_by_default) and only the canonical doc \
               carries all three signal terms. Together iters \
               2/31/47/71 cover four chatter shapes (\"Pull my … on\" / \
               \"Show me my … notes\" / \"Get me my … notes please\" / \
               \"Can you find my … notes please\") × three signal \
               domains (residency-governance / tier-compression-\
               governance / agent-runtime-trace) — proves the strip is \
               robust across both prefix-shape and signal-domain \
               variation.",
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
        // 5th SignalOnly row (iter-81): 3-term variant in storage/vault
        // canon domain. Reuses the iter-66 Adversarial seed corpus
        // (canonical with all 4 of {vault, index, reload, tantivy} +
        // 3 partial-overlap decoys). Survivors {vault, index, reload}
        // — 3 terms ≤ 3 → AND-conjunction; only the canonical doc
        // carries all three. Together iters 6/72/81 now span three
        // 3/2/3-term plain SignalOnly variants across three domains.
        query: "vault index reload",
        expected_paths: &["notes/vault_index_reload_canon.md"],
        forbidden_paths: &[
            "notes/vault_brainstorm.md",
            "notes/old_index_design.md",
            "notes/tantivy_misc_notes.md",
        ],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Fifth SignalOnly row (iter-81): 3-term variant in \
               storage/vault canon domain. Distinct from iter-6 \
               (Mamba SSM cache, ml domain), iter-7 (quoted phrase), \
               iter-39 (single term), iter-72 (2-term AND boundary, \
               agent-runtime). Reuses iter-66 seed corpus — no new \
               synthetic notes. AND-conjunction on {vault, index, \
               reload}: canonical has all 3, decoys each have ≤ 1, \
               so only canonical matches. Grows SignalOnly to depth \
               5 alongside Unicode; advances fixture toward 50-row \
               target.",
    },
    FVaultRecallRow {
        // 4th SignalOnly row (iter-72): two-term variant. Survivors
        // {agent, runtime} — 2 terms ≤ 3 → AND-conjunction. Reuses the
        // iter-43 Adversarial seed corpus (no new synthetic notes).
        query: "agent runtime",
        expected_paths: &["notes/agent_runtime_v2_substrate.md"],
        forbidden_paths: &[
            "notes/agent_brainstorm.md",
            "notes/runtime_old_design.md",
        ],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Fourth SignalOnly row (iter-72): two-term variant. \
               Distinct from iter-6's 3-term Mamba (\"Mamba SSM cache\"), \
               iter-7's quoted PhraseQuery (\"\\\"residency \
               governance\\\"\"), and iter-39's single-term Hamiltonian. \
               Pins the 2-term AND-conjunction boundary (still ≤ 3 → \
               set_conjunction_by_default fires); proves AND-filtering \
               works on the smallest multi-term query. Reuses iter-43 \
               agent-runtime seed corpus. Forbidden decoys each carry \
               only ONE of the two query terms, so AND filters them \
               out before BM25 ranks; substrate_concepts.md (carries \
               neither term) is naturally excluded. Together iters \
               6/7/39/72 span 4 SignalOnly term-count shapes: 1, 2, 3, \
               quoted-phrase.",
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
        // 5th PureChatter row (iter-83): MODAL-led shape — distinct
        // from imperatives (iters 16/30/49) and wh-led (iter-73).
        // Every token in QUERY_CHATTER_WORDS: could (discourse:
        // please/can/could/would/should), you (second-person), find
        // (imperative — but not at lead position), some (misc
        // filler), files (generic-referent), for (stop-word), me
        // (first-person). 7 tokens, 5 chatter categories.
        query: "could you find some files for me",
        expected_paths: &[],
        forbidden_paths: &["notes/totally_unrelated_a.md"],
        category: FVaultRecallCategory::PureChatter,
        top_n: 5,
        note: "Fifth PureChatter row (iter-83): modal-led shape. \
               Distinct from iters 16/30/49 (imperative-led) and \
               iter-73 (wh-led). Opens with the modal \"could\" at \
               lead position, followed by second-person you + \
               embedded imperative find. Pins all_chatter_fallback \
               against modal/polite request shapes that don't fit \
               the imperative or interrogative families. Together \
               iters 16/30/49/73/83 span five structural lead \
               patterns: 3 imperative-led + 1 wh-led + 1 modal-led.",
    },
    FVaultRecallRow {
        // 4th PureChatter row (iter-73): NO imperative — distinct
        // structural shape from iters 16/30/49 which all open with an
        // imperative (show / tell / give). Survivors after
        // strip_query_chatter: none — where/are/the/files are ALL in
        // QUERY_CHATTER_WORDS (wh-question / aux-verb / stop-word /
        // generic-referent). Pins all_chatter_fallback against a
        // wh-led pattern.
        query: "where are the files",
        expected_paths: &[],
        forbidden_paths: &["notes/totally_unrelated_a.md"],
        category: FVaultRecallCategory::PureChatter,
        top_n: 5,
        note: "Fourth PureChatter row (iter-73): structurally distinct \
               from iters 16/30/49 because it carries NO imperative. \
               Token shape: wh-question (\"where\") + auxiliary verb \
               (\"are\") + stop-word (\"the\") + generic-referent \
               (\"files\"). Every existing PureChatter row begins with \
               an imperative (show / tell / give); this row proves the \
               all_chatter_fallback detection works on declarative + \
               question shapes too, not just imperatives. Together \
               iters 16/30/49/73 span four structural patterns and \
               seven chatter-token categories.",
    },
    FVaultRecallRow {
        // 4th Synthesis row (iter-75): pair-retention in the
        // agent-runtime domain (iter-43 corpus + 1 new pair-partner
        // seed). Query has 3 surviving terms; AND-conjunction retains
        // only the two docs carrying ALL of {agent, runtime,
        // substrate}. The iter-43 decoys each carry one of the three
        // terms and are filtered out by AND.
        query: "agent runtime substrate",
        expected_paths: &[
            "notes/agent_runtime_v2_substrate.md",
            "notes/agent_runtime_substrate_v3.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 3,
        note: "Fourth Synthesis row (iter-75): agent-runtime canon \
               domain. Distinct from iter-11 (tier/compression/\
               governance), iter-45 (hardware/floor/falsifier), and \
               row-11 near-duplicate. Reuses iter-43's seed corpus \
               (canonical doc with all 4 of {agent, runtime, \
               substrate, trace}) plus one new pair-partner seed \
               (`notes/agent_runtime_substrate_v3.md`). 3-term AND-\
               conjunction on {agent, runtime, substrate} matches \
               BOTH pair-partner docs; the iter-43 decoys \
               (agent_brainstorm / runtime_old_design / \
               substrate_concepts) each carry only ONE of the three \
               terms and are filtered out before BM25 ranks. top_n = \
               3 retains the pair without smuggling false positives.",
    },
    FVaultRecallRow {
        // 5th Synthesis row (iter-85): pair-retention in the
        // storage/tokenizer domain. Distinct from iter-11
        // (tier/compression/governance), iter-24 near-duplicate,
        // iter-45 (hardware/floor/falsifier), iter-75 (agent-runtime).
        // Brings Synthesis to depth 5 alongside SignalOnly / ChattyPrefix /
        // PureChatter / Unicode / Adversarial — every-category-at-≥-5
        // milestone (Paraphrase is the lone remaining holdout at 4 — its
        // 5th row lands in a follow-on iter).
        query: "tokenizer indexing tantivy",
        expected_paths: &[
            "notes/tokenizer_indexing_tantivy_overview.md",
            "notes/tokenizer_indexing_tantivy_internals.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 3,
        note: "Fifth Synthesis row (iter-85): storage/tokenizer canon \
               domain — extends the iter-66 / iter-84 substrate-canon \
               coverage to a new sub-axis (how Tantivy tokenizes during \
               indexing). 3-term AND-conjunction on {tokenizer, \
               indexing, tantivy} matches BOTH pair-partner docs (each \
               carries all 3 terms 2-3×); every existing seed in the \
               vault (vault_index_reload_canon, tantivy_misc_notes, \
               bm25_saturation_length_penalty, etc.) carries ≤ 1 of \
               the 3 query terms and is filtered out by AND before \
               BM25 ranks. Closes the every-category-at-≥-5 milestone \
               for the Synthesis category (Paraphrase remains at 4 — \
               its 5th row lands in a follow-on iter). top_n = 3 \
               matches the iter-45 / iter-75 pattern: leaves room for \
               one stray decoy without invalidating the pair-retention \
               contract.",
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
        query: "Mamba SSM caches",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Third Paraphrase row (iter-51): inflection axis — query \
               uses plural \"caches\" but the doc spells it singular \
               \"cache\". Tantivy's default tokenizer doesn't stem, so \
               the AND-conjunction over {Mamba, SSM, caches} cannot \
               match a doc that only has \"cache\". Currently fails — \
               pinned as Fix-C deferred regression alongside iter-12 \
               (long-form expansion: \"state-space-model caching\") \
               and iter-20 (typo: \"SSL\"). Three Paraphrase variants \
               span three distinct lexical-mismatch axes: long-form, \
               typo, inflection. Paraphrase category × 3 — every \
               canonical category now at depth ≥ 3 (Paraphrase joins \
               the cohort).",
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
        // 4th Paraphrase row (iter-74): SYNONYM substitution axis.
        // Targets the iter-66 storage/vault canon corpus (no new
        // seeds needed). Canonical doc has {vault, index, reload,
        // tantivy} — query swaps "reload" for the synonym "refresh".
        // AND-conjunction on 3 terms {vault, index, refresh} blocks
        // the canonical (missing "refresh") and every decoy (each
        // missing 2+ terms). Row FAILS by design — lexical-only
        // retrieval cannot resolve synonyms.
        query: "vault index refresh",
        expected_paths: &["notes/vault_index_reload_canon.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Synonym adversarial axis (axis #5): user typed \
               \"refresh\" but the doc spells it \"reload\". Lexical \
               retrieval has no notion of synonymy, so 3-term AND \
               on {vault, index, refresh} blocks the canonical \
               (which has vault + index but NOT refresh). Distinct \
               from iters 12/20/51 (long-form / inflection / typo, \
               all against the Mamba SSM canonical) — this row \
               targets a NEW canonical (storage/vault canon, the \
               iter-66 corpus) AND a new lexical-mismatch axis. \
               CURRENTLY FAILS by design — pins Fix-C deferred \
               synonym-resolution work (e.g. epistemos-shadow's \
               semantic-embedding path, or a thesaurus expansion \
               step). Together iters 12/20/51/74 span four \
               Paraphrase failure axes (long-form / inflection / \
               typo / synonym) across two domains.",
    },
    FVaultRecallRow {
        // 5th Paraphrase row (iter-86): ABBREVIATION / ACRONYM
        // expansion axis. Query uses "ml" (acronym) while the doc
        // spells it "machine learning" (full form). Distinct from
        // iter-12 (long-form expansion: "state-space-model"),
        // iter-20 (typo: "SSL"), iter-51 (inflection: "caches"),
        // and iter-74 (synonym: "refresh"). Brings Paraphrase to
        // depth 5 — closes the every-category-at-≥-5 milestone
        // (the last category previously at 4). AND-conjunction on
        // 3 terms {ml, inference, cache} blocks the canonical
        // (doc has "machine" + "learning" + "inference" + "cache"
        // but NOT the token "ml") — row FAILS by design.
        query: "ml inference cache",
        expected_paths: &["notes/machine_learning_inference_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Abbreviation / acronym adversarial axis (axis #6): \
               user typed \"ml\" but the doc spells out \"machine \
               learning\". Lexical retrieval has no notion of \
               acronym expansion, so 3-term AND on {ml, inference, \
               cache} blocks the canonical (which has the full form \
               but no \"ml\" token). Distinct from iters 12/20/51 \
               (long-form / typo / inflection — all against the \
               Mamba SSM canonical) and iter-74 (synonym — vault \
               canon). Targets a NEW canonical (the machine-\
               learning-inference-cache doc, ML/inference-domain) \
               AND a new lexical-mismatch axis. CURRENTLY FAILS \
               by design — pins Fix-C deferred acronym/abbreviation \
               work (e.g. epistemos-shadow's semantic-embedding \
               path, a query-expansion preprocessor with an \
               acronym dictionary, or a hybrid match step). \
               Together iters 12/20/51/74/86 span FIVE Paraphrase \
               failure axes (long-form / inflection / typo / \
               synonym / abbreviation) across THREE domains. \
               Closes the every-category-at-≥-5 milestone.",
    },
    FVaultRecallRow {
        // Pure-CJK variant (iter-53): no Latin component. Two CJK
        // tokens with whitespace between so Tantivy's default
        // SimpleTokenizer keeps them as distinct tokens.
        // 缓存 = "cache", 架构 = "architecture".
        query: "缓存 架构",
        expected_paths: &["notes/pure_chinese.md"],
        forbidden_paths: &["notes/latin_only_ssm.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Pure-CJK Unicode variant (iter-53): no Latin tokens — \
               distinct from iter-19's mixed Latin+CJK and iter-8's \
               Latin diacritic. Tests Tantivy's SimpleTokenizer on \
               pure non-Latin script: whitespace-separated CJK tokens \
               must be kept distinct from each other, AND-conjunction \
               (2 surviving terms ≤ 3) must match a doc containing \
               both. A Latin-only forbidden doc with the same concept \
               in English (\"Mamba SSM cache architecture\") must be \
               rejected — proves no script-fold from CJK → Latin. \
               Unicode category now at depth 5 (deepest in the \
               fixture).",
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
        query: "vault index reload tantivy",
        expected_paths: &["notes/vault_index_reload_canon.md"],
        forbidden_paths: &[
            "notes/vault_brainstorm.md",
            "notes/old_index_design.md",
            "notes/tantivy_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        // top_n = 1 preserves the Adversarial contract: BM25 must rank
        // the canonical doc above each partial-overlap decoy. Storage /
        // vault canon adds a 4th domain family alongside design-system
        // (iter-15), graph/event (iter-27), agent-runtime (iter-43).
        top_n: 1,
        note: "Fourth Adversarial row (iter-66): storage / vault canon \
               — distinct from iter-15 design-system, iter-27 \
               graph/event, iter-43 agent-runtime. Same shape (4 \
               surviving terms → OR-conjunction; 3 partial-overlap \
               decoys; top_n = 1 forces BM25-ranking discrimination), \
               new lexical universe. Cross-domain coverage now: 4 \
               families × 1 Adversarial row each — proves the failure \
               mode generalizes across the substrate-canon vocabulary \
               (vault, index, reload, tantivy are all high-frequency \
               terms in the storage layer). A future tokenizer change \
               that disrupts BM25 ranking on this domain flips this \
               row to FAIL and the diagnostics surface flags the \
               regression at the storage-layer terms specifically.",
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
    FVaultRecallRow {
        query: "bm25 saturation length penalty",
        expected_paths: &["notes/bm25_saturation_length_penalty.md"],
        forbidden_paths: &[
            // Load-bearing decoy: a deliberately long doc that stuffs
            // ONLY the term "saturation" 80× amid unrelated junk. Without
            // BM25's TF-saturation cap (k1) + length-normalization (b),
            // raw TF alone would crush the moderate-length canonical.
            "notes/saturation_stuffed_decoy.md",
            // Single-term partial-overlap decoys — same shape as the
            // four prior Adversarial rows. Each carries exactly ONE of
            // the four query terms repeated a few times in a short body.
            "notes/bm25_overview.md",
            "notes/length_archive.md",
            "notes/penalty_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        // top_n = 1 preserves the Adversarial contract. With four query
        // terms → OR-conjunction (>3 surviving), every decoy carrying
        // ≥1 term is a candidate; the test is whether BM25's ranking —
        // specifically TF-saturation + length-normalization — keeps the
        // canonical above the long-stuffed decoy.
        top_n: 1,
        note: "Fifth Adversarial row (iter-84): IR / search-ranking \
               domain — distinct from iter-15 design-system, iter-27 \
               graph/event, iter-43 agent-runtime, iter-66 storage/vault. \
               Brings the Adversarial category to depth 5, matching \
               SignalOnly + ChattyPrefix + PureChatter + Unicode at 5. \
               Specifically pins BM25's TF-saturation cap (k1=1.2) AND \
               length-normalization (b=0.75) simultaneously. The \
               load-bearing decoy `saturation_stuffed_decoy.md` is a \
               long doc (≫ avgdl) that repeats only the term \
               \"saturation\" 80× in unrelated junk. Under naive raw-TF \
               ranking the decoy would trivially win (80 ≫ 3). Under \
               Tantivy's default BM25 the per-term contribution \
               saturates at ~IDF·(k1+1)/(k1·dl/avgdl + 1) — bounded — \
               AND the length-norm divisor blows up for the long doc; \
               meanwhile the canonical carries all four terms 2-3× \
               each in a moderate-length body, accumulating four \
               saturated contributions and winning decisively. Closes \
               the \"BM25 saturation\" deep-hardening axis (previously \
               ⏳ pending — see docs/F_VAULT_RECALL_50_2026_05_18.md \
               §7 table). A future ranker swap (raw TF, b=0, k1=∞, or \
               a non-BM25 scorer that ignores doc-length) regresses \
               this row to FAIL and the diagnostics surface flags the \
               regression at the ranker-tuning layer specifically.",
    },
    FVaultRecallRow {
        // 10th SignalOnly row (iter-112): 4th exact-quote
        // PhraseQuery — extends the position-sensitivity axis
        // from 3 domains to 4 (iter-7 residency-governance +
        // iter-88 design-system + iter-102 vault-canon + iter-112
        // Mamba SSM). Crucially, this row's forbidden decoy
        // (iter-9's notes/mamba_chinese.md) has both "mamba"
        // and "ssm" tokens BUT separated by a CJK token (缓存)
        // — PhraseQuery must reject this even though the Latin
        // bigram is theoretically reconstructible by ignoring
        // non-Latin tokens. Tantivy's PhraseQuery is token-
        // position-strict regardless of script — exactly the
        // contract we want.
        query: "\"mamba ssm\"",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &["notes/mamba_chinese.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Tenth SignalOnly row (iter-112): fourth exact-quote \
               PhraseQuery, in the Mamba SSM domain — extends the \
               position-sensitivity axis to four domains. Unique \
               cross-script wrinkle: the forbidden decoy \
               (mamba_chinese.md) has the Latin bigram \"Mamba\" \
               + \"ssm\" but with a CJK token (缓存) separator \
               between them. PhraseQuery must reject this even \
               though the Latin tokens are theoretically \
               adjacent-modulo-non-Latin. Tantivy's PhraseQuery \
               is token-position-strict regardless of script — \
               exactly the contract. The other doc with the \
               bigram (notes/mamba_english_only.md) has \"Mamba \
               ssm\" adjacent so it WOULD match; it's not in \
               forbidden_paths and is allowed in top-5.",
    },
    FVaultRecallRow {
        // 9th SignalOnly row (iter-102) — **50th fixture row,
        // landing the F-VaultRecall-50 falsifier-name target.**
        // 3rd exact-quote PhraseQuery row, in the storage/vault
        // canon domain — distinct from iter-7 (residency-
        // governance) and iter-88 (design-system). PhraseQuery
        // "vault index" requires the bigram at adjacent
        // positions; iter-66's canonical carries it adjacent
        // multiple times. A new forbidden seed
        // (notes/vault_general_index.md) carries both tokens
        // with intervening text so PhraseQuery does NOT match.
        // Three rows now prove the exact-quote axis works
        // across three domains.
        query: "\"vault index\"",
        expected_paths: &["notes/vault_index_reload_canon.md"],
        forbidden_paths: &["notes/vault_general_index.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Ninth SignalOnly row (iter-102) — 50th overall \
               fixture row, lands the F-VaultRecall-50 falsifier-\
               name target. Third exact-quote PhraseQuery row, \
               extending the position-sensitivity axis to a 3rd \
               domain: iter-7 residency-governance + iter-88 \
               design-system + iter-102 storage/vault. Literal \
               `\"…\"` quotes in the query become a Tantivy \
               PhraseQuery; expected doc carries the bigram \
               adjacent (iter-66's vault_index_reload_canon.md), \
               new forbidden seed (vault_general_index.md: \"vault \
               general overview index notes archive\") carries \
               both tokens with intervening text so the phrase \
               does NOT match. The 50-row contract closes a \
               named falsifier — the fixture name F-VaultRecall-50 \
               is no longer aspirational, it's met.",
    },
    FVaultRecallRow {
        // 8th Unicode row (iter-109): Hebrew-script extension. Adds
        // a 6th non-Latin script (Hebrew, U+0590–U+05FF) alongside
        // CJK (iter-19), Cyrillic (iter-28), Arabic (iter-32), Greek
        // (iter-93), Japanese-katakana (iter-101). Latin "Mamba" +
        // Hebrew "ש" (shin, U+05E9) + Latin "cache". Hebrew is RTL
        // like Arabic; Tantivy's SimpleTokenizer is direction-
        // agnostic so the single Hebrew letter tokenizes cleanly.
        query: "Mamba ש cache",
        expected_paths: &["notes/mamba_hebrew.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Eighth Unicode row (iter-109): Hebrew-script \
               extension. Six non-Latin scripts pinned now — CJK \
               (iter-19), Cyrillic (iter-28), Arabic (iter-32), \
               Greek (iter-93), Japanese-katakana (iter-101), \
               Hebrew (iter-109). The Hebrew letter ש (shin, \
               U+05E9) is in the Letter Unicode property so \
               SimpleTokenizer treats it as a distinct token. \
               The iter-9 forbidden seed lacks the Hebrew \
               codepoint so AND blocks it — same no-script-fold \
               contract as the other multilingual rows. Hebrew \
               + Arabic together pin two RTL scripts; CJK + \
               Japanese-katakana pin two East-Asian scripts; \
               Cyrillic + Greek pin two European non-Latin \
               scripts.",
    },
    FVaultRecallRow {
        // 7th Unicode row (iter-101): Japanese katakana — extends
        // the multilingual axis from 4 non-Latin scripts (CJK
        // iter-19, Cyrillic iter-28, Arabic iter-32, Greek iter-93)
        // to 5 by adding Japanese katakana. Distinct from CJK
        // (Han ideographs) — katakana is a syllabary covering
        // U+30A0–U+30FF. Latin "Mamba" + katakana "メモリ" (memory) +
        // Latin "cache" tokenized as three distinct tokens by
        // Tantivy's SimpleTokenizer.
        query: "Mamba メモリ cache",
        expected_paths: &["notes/mamba_japanese_katakana.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Seventh Unicode row (iter-101): Japanese-katakana \
               extension. Adds a 5th non-Latin script — Japanese \
               katakana (U+30A0–U+30FF, distinct from Han \
               ideographs U+4E00–U+9FFF) — alongside CJK \
               (iter-19), Cyrillic (iter-28), Arabic (iter-32), \
               Greek (iter-93). The katakana token メモリ \
               (\"memory\") tokenizes as one whitespace-separated \
               token under SimpleTokenizer. The iter-9 forbidden \
               seed (mamba_english_only.md) lacks the katakana \
               codepoint so AND blocks it — same no-script-fold \
               contract as the other multilingual rows. Unicode \
               sub-axes now: diacritics + 5 non-Latin scripts + \
               pure-CJK = 7.",
    },
    FVaultRecallRow {
        // 7th Adversarial row (iter-100): MLX-Swift inference
        // domain — extends cross-domain breadth to 7 families
        // (design-system / graph-event / agent-runtime / storage-
        // vault / IR-BM25 / Metal-compute / MLX-Swift). Same
        // 4-term OR-conjunction + 3 single-term decoys + top_n=1
        // BM25 discrimination shape. Per CLAUDE.md "MLX-Swift for
        // local inference" — substrate-canonical.
        query: "mlx swift inference backend",
        expected_paths: &["notes/mlx_swift_inference_backend.md"],
        forbidden_paths: &[
            "notes/mlx_archive.md",
            "notes/swift_brainstorm.md",
            "notes/inference_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Seventh Adversarial row (iter-100): MLX-Swift \
               inference canon — 7th cross-domain family. Same \
               shape (4-term OR-conjunction; 3 single-term \
               partial-overlap decoys; top_n = 1 forces BM25-\
               ranking discrimination), new lexical universe \
               from the on-device-inference substrate (per \
               CLAUDE.md \"MLX-Swift for local inference\"). A \
               future tokenizer or ranker change that disrupts \
               BM25 discrimination on the MLX vocabulary flips \
               this row to FAIL.",
    },
    FVaultRecallRow {
        // 9th PureChatter row (iter-114): DEGENERATE single-token
        // shape — shortest possible PureChatter query. Reuses
        // iter-16 totally-unrelated decoys — zero new seeds.
        // Tests the all_chatter_fallback path at the smallest
        // input boundary: one token. Token "files" is in
        // QUERY_CHATTER_WORDS (generic referent). Strip empties →
        // all_chatter_fallback flips → evidence Weak → row
        // passes. Distinct from the 8 prior multi-token shapes.
        query: "files",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Ninth PureChatter row (iter-114): degenerate single-\
               token shape — shortest possible chatter query \
               (\"files\"). Tests the all_chatter_fallback path at \
               the 1-token input boundary. The token \"files\" is \
               in QUERY_CHATTER_WORDS (generic referent). Strip \
               empties the query → fallback flips → evidence \
               Weak → row passes. Together with the 8 prior \
               multi-token shapes, proves the fallback fires at \
               every input cardinality from 1 token up.",
    },
    FVaultRecallRow {
        // 8th PureChatter row (iter-107): BE-declarative shape —
        // structurally distinct from every prior PureChatter row
        // (imperative iter-16/30/49, wh-led iter-73, modal-led
        // iter-83, need/pronoun-led iter-94, compound wh+modal
        // iter-99). The query is a STATEMENT not a question or
        // imperative — no retrieval intent at all — yet the
        // all_chatter_fallback path must still fire because every
        // token is in QUERY_CHATTER_WORDS. Proves the fallback
        // detection is keyed on lexical content (chatter words),
        // not on syntactic intent (question/imperative vs
        // declarative).
        query: "the file is in my notes",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Eighth PureChatter row (iter-107): BE-declarative \
               shape (\"the file is in my notes\") — a STATEMENT, \
               not a question or imperative. All 6 tokens {the, \
               file, is, in, my, notes} are in QUERY_CHATTER_WORDS. \
               Strip empties → all_chatter_fallback → evidence \
               Weak → row passes. Distinct from prior PureChatter \
               shapes which all encode retrieval-intent \
               (imperative / wh-question / modal request / need \
               / compound). This row proves all_chatter_fallback \
               keys on lexical content, not on syntactic intent.",
    },
    FVaultRecallRow {
        // 7th PureChatter row (iter-99): combined wh-led + modal-
        // led shape — distinct from iter-73 pure-wh ("where are
        // the files") and iter-83 pure-modal ("could you find
        // some files for me"). All 8 tokens {where, could, you,
        // find, some, of, my, notes} are in QUERY_CHATTER_WORDS.
        // Strip empties → all_chatter_fallback → evidence Weak →
        // PureChatter contract passes. Reuses iter-16's totally-
        // unrelated decoys — zero new seeds.
        query: "where could you find some of my notes",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Seventh PureChatter row (iter-99): combined wh-led + \
               modal-led shape (\"where could you\") — proves \
               all_chatter_fallback detection works on compound \
               lead patterns, not just single-family leads. \
               Distinct from iter-73 (pure-wh: \"where are\") and \
               iter-83 (pure-modal: \"could you\") — this row \
               stacks both. Together iters 16/30/49/73/83/94/99 \
               span seven structural lead patterns including a \
               compound-lead variant.",
    },
    FVaultRecallRow {
        // 9th ChattyPrefix row (iter-113): "what about my X notes"
        // shape — wh-led with "about" in the PREFIX (not suffix
        // like iter-98's "what are my X notes about"). Reuses
        // iter-43's agent-runtime corpus — zero new seeds.
        // Survivors after strip_query_chatter: {agent, runtime,
        // substrate} — 3 terms triggers AND-conjunction. iter-43
        // canonical and iter-75 pair-partner both match (both
        // have all 3 terms); the single-term iter-43 decoys are
        // blocked by AND. top_n = 7 retains both expected variants
        // without smuggling decoys.
        query: "What about my agent runtime substrate notes",
        expected_paths: &["notes/agent_runtime_v2_substrate.md"],
        forbidden_paths: &[
            "notes/agent_brainstorm.md",
            "notes/runtime_old_design.md",
            "notes/substrate_concepts.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Ninth ChattyPrefix row (iter-113): wh-led with \
               \"about\" in the PREFIX (not suffix). Distinct \
               structural shape from iter-98 (\"What are my X \
               notes about\" — about as suffix) — about appears \
               adjacent to \"what\" at the lead. Reuses iter-43 \
               + iter-75 corpora; AND on the 3 surviving signal \
               terms blocks the single-term partial-overlap \
               decoys. ChattyPrefix axis now spans 9 chatter \
               shapes across 9 distinct combinations of prefix/\
               suffix positions and lead-word families.",
    },
    FVaultRecallRow {
        // 7th ChattyPrefix row (iter-98): wh-led + about-suffix
        // shape — distinct from iter-2 (Pull my … on),
        // iter-31 (Show me my … notes), iter-47 (Get me my …
        // notes please), iter-71 (Can you find my … notes
        // please), iter-82 (Pull my notes on the … please),
        // iter-92 (Could you pull my notes on …). Reuses iter-2
        // residency-governance corpus — zero new seeds. Tokens
        // {what, are, my, notes, about} are all in
        // QUERY_CHATTER_WORDS; survivors {residency, governance}
        // — 2 terms triggers AND-conjunction.
        query: "What are my residency governance notes about",
        expected_paths: &["MASTER_FUSION/3_2_residency_governor.md"],
        forbidden_paths: &[
            "ui/hermes_branding.md",
            "ui/character_dna_specs.md",
            "user_hardware.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Seventh ChattyPrefix row (iter-98): wh-led + about-\
               suffix prefix shape (the query frames the request \
               as a meta-question, not an imperative or modal \
               polite request). Chatter prefix {what, are, my} + \
               chatter suffix {notes, about}; survivors {residency, \
               governance} — 2 surviving terms triggers AND-\
               conjunction. Reuses iter-2's residency-governance \
               canonical + UI/hardware decoys; the decoys carry \
               none of the surviving signal terms so AND filters \
               them. Together iters 2/31/47/71/82/92/98 span \
               seven structurally distinct chatter shapes, \
               proving the strip is robust across imperative + \
               polite-modal + wh-question framings.",
    },
    FVaultRecallRow {
        // 11th Paraphrase row (iter-116): NEW axis — HOMOGLYPH
        // substitution (visually-identical but distinct-codepoint
        // tokens). Query uses Cyrillic "а" (U+0430) where the
        // doc has Latin "a" (U+0061). Tantivy's SimpleTokenizer
        // is codepoint-aware: the two characters are different
        // Unicode codepoints, so "mаmba" (Cyrillic-a) and "mamba"
        // (Latin-a) are different tokens entirely. AND on
        // {mаmba, ssm, cache} blocks the canonical (which spells
        // "mamba" with Latin-a). Reuses iter-2 corpus; zero new
        // seeds. Distinct from every prior Paraphrase axis
        // (long-form / inflection / 4 typo subclasses / 2
        // synonym / abbreviation / ASCII-folding) — this is a
        // visually-equivalent codepoint substitution, not a
        // textual edit operation.
        query: "mаmba ssm cache",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Homoglyph adversarial axis (axis #10 for Paraphrase): \
               user types Cyrillic \"а\" (U+0430) instead of \
               Latin \"a\" (U+0061) in \"mamba\" — visually \
               identical but different Unicode codepoints. \
               Tantivy's SimpleTokenizer is codepoint-aware so \
               the two are distinct tokens; AND-conjunction \
               blocks the doc. TENTH Paraphrase axis distinct \
               from long-form / inflection / 4 typo subclasses / \
               2 synonym / abbreviation / ASCII-folding. Pins a \
               common security/spoofing failure mode: paste-from-\
               keyboard-layout-mismatch or homoglyph attacks. \
               CURRENTLY FAILS by design — pin for future \
               homoglyph-normalize step (e.g. Unicode confusable \
               detection per UTS #39 or a normalize-to-NFC \
               pipeline that maps confusables to a single \
               codepoint).",
    },
    FVaultRecallRow {
        // 10th Paraphrase row (iter-111): NEW axis — ASCII-folding /
        // diacritic-stripping. Reuses iter-8 Unicode corpus (zero
        // new seeds). Query "naive resume filter" lacks diacritics
        // (ASCII-only spelling); the expected doc
        // unicode_resume_filter.md spells "naïve résumé filter"
        // with diacritics intact. AND-conjunction on {naive,
        // resume, filter} blocks the expected doc (Tantivy treats
        // "naive" ≠ "naïve" as different tokens). Distinct from
        // every prior Paraphrase axis (long-form / inflection /
        // 4 typo subclasses / 2 synonym / abbreviation).
        query: "naive resume filter",
        expected_paths: &["notes/unicode_resume_filter.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "ASCII-folding adversarial axis (axis #9 for \
               Paraphrase): user typed \"naive resume\" (ASCII-\
               only) but the doc spells \"naïve résumé\" with \
               diacritics. Tantivy's SimpleTokenizer is Unicode-\
               aware but does NOT fold diacritics — \"naive\" and \
               \"naïve\" are distinct tokens. AND-conjunction \
               blocks the diacritic doc; iter-8 already pins the \
               INVERSE direction (query has diacritics → matches \
               diacritic doc, NOT the ASCII variant), so iter-111 \
               + iter-8 together prove the no-script-fold contract \
               from both sides. NINTH Paraphrase axis distinct \
               from long-form / inflection / 4 typo subclasses / \
               2 synonym / abbreviation. CURRENTLY FAILS by \
               design — when ASCII-folding tokenizer or normalize-\
               diacritics step ships, this row flips to ✅.",
    },
    FVaultRecallRow {
        // 9th Paraphrase row (iter-106): 2nd synonym-substitution
        // axis row — extends the synonym axis (iter-74: refresh ↔
        // reload in vault-canon) to a 2nd domain (Mamba SSM:
        // store ↔ cache). Query "mamba ssm store" uses "store" as
        // a near-synonym for "cache"; AND-conjunction on 3 terms
        // {mamba, ssm, store} blocks the canonical (which has
        // mamba + ssm + cache but NOT the token "store"). Reuses
        // iter-2's Mamba corpus — zero new seeds.
        query: "mamba ssm store",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Second synonym Paraphrase row (iter-106): \
               \"store\" ↔ \"cache\" in the Mamba SSM domain. \
               Distinct from iter-74's \"refresh\" ↔ \"reload\" \
               in vault-canon — same axis (synonym/near-synonym \
               substitution), 2nd domain. Lexical retrieval has \
               no notion of synonymy, so 3-term AND on {mamba, \
               ssm, store} blocks the canonical. Two synonym \
               rows now prove the axis spans multiple domains. \
               When semantic / thesaurus recall ships (e.g. \
               epistemos-shadow Model2Vec or a synonym-expansion \
               step), BOTH iter-74 and iter-106 must flip to ✅ \
               together — proving the fix covers more than one \
               domain-specific synonym pair.",
    },
    FVaultRecallRow {
        // 8th Paraphrase row (iter-104): typo INSERTION subclass —
        // extends the typo axis from 3 subclasses (substitution
        // iter-20, transposition iter-90, deletion iter-97) to 4
        // subclasses (+ insertion). Reuses iter-100's MLX corpus —
        // zero new seeds. Query "mlx inferencee backend" inserts
        // an extra "e" into "inference"; AND-conjunction on 3
        // terms {mlx, inferencee, backend} blocks the canonical
        // (which has "inference" not "inferencee"). Same
        // discriminator class as the prior 3 typo rows but a 4th
        // edit operation and a 4th domain.
        query: "mlx inferencee backend",
        expected_paths: &["notes/mlx_swift_inference_backend.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Eighth Paraphrase row (iter-104): typo INSERTION \
               subclass — \"inferencee\" inserts an extra \"e\" \
               into \"inference\". Together iters 20/90/97/104 \
               span four typo subclasses (substitution / \
               transposition / deletion / insertion) across four \
               domains (Mamba SSM / vault-canon / Apple Metal / \
               MLX-Swift). Tantivy's SimpleTokenizer has no edit-\
               distance tolerance — AND on the typoed token \
               blocks every doc. Reuses iter-100 MLX corpus, zero \
               new seeds. CURRENTLY FAILS by design. When fuzzy-\
               match ships, ALL FOUR typo rows must flip to ✅ \
               together — proving the fix covers every common \
               single-edit-distance class (Damerau-Levenshtein \
               primitives).",
    },
    FVaultRecallRow {
        // 7th Paraphrase row (iter-97): typo deletion subclass —
        // extends the typo axis from 2 subclasses (substitution
        // iter-20, transposition iter-90) to 3 subclasses
        // (+ deletion). Reuses iter-91's Metal corpus — zero new
        // seeds. Query "metal compute kernl" drops the "e" from
        // "kernel"; AND-conjunction on 3 terms {metal, compute,
        // kernl} blocks every doc in the corpus because no doc
        // has the token "kernl" — the canonical has "kernel" and
        // every other Metal seed has at most 2 of the 3 query
        // tokens. Row FAILS by design, pinning the deletion-typo
        // class.
        query: "metal compute kernl",
        expected_paths: &["notes/metal_compute_shader_kernel.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Seventh Paraphrase row (iter-97): typo deletion \
               subclass — \"kernl\" is \"kernel\" with the \"e\" \
               deleted. Together iters 20/90/97 span three typo \
               subclasses (single-char substitution / adjacent-\
               bigram transposition / single-char deletion) across \
               three domains (Mamba SSM / vault-canon / Apple \
               Metal). Tantivy's SimpleTokenizer treats every \
               token literally — no edit-distance tolerance — so \
               AND-conjunction on the typoed token blocks every \
               doc. Reuses iter-91 Metal corpus, zero new seeds. \
               CURRENTLY FAILS by design. When fuzzy-match ships, \
               ALL THREE typo rows must flip to ✅ — proving the \
               fix covers more than one specific edit operation \
               and more than one specific domain.",
    },
    FVaultRecallRow {
        // 8th SignalOnly row (iter-96): 3-term AND in the Apple
        // Metal compute domain — reuses iter-91 corpus, zero new
        // seeds. Surviving terms {metal, shader, kernel} (no
        // chatter) → 3 ≤ 3 → AND-conjunction. The iter-91
        // canonical (metal_compute_shader_kernel.md) carries all
        // three; iter-91's decoys carry at most one each
        // (metal_archive has metal, compute_brainstorm has none
        // of these, shader_misc_notes has shader); iter-95's
        // pair-partner (metal_compute_pipeline_v2.md) has metal
        // only — AND blocks. Same lexical universe as iter-91/92,
        // distinct term-set (drops "compute" to force 3-term-AND
        // path instead of iter-91's 4-term-OR path).
        query: "metal shader kernel",
        expected_paths: &["notes/metal_compute_shader_kernel.md"],
        forbidden_paths: &["notes/shader_misc_notes.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Eighth SignalOnly row (iter-96): Apple Metal compute \
               domain — 3-term AND-conjunction path. The Metal \
               substrate vocabulary now spans four categories \
               (Adversarial iter-91, ChattyPrefix iter-92, \
               Synthesis iter-95, SignalOnly iter-96) — proves a \
               single seeded corpus exercises every retrieval-\
               failure-mode the contract names. Zero new seeds — \
               this row reuses iter-91/iter-95's Metal corpus \
               entirely; the term set {metal, shader, kernel} \
               (drops \"compute\" to force AND-conjunction since \
               surviving-terms ≤ 3) discriminates the iter-91 \
               canonical from every decoy and the iter-95 pair-\
               partner.",
    },
    FVaultRecallRow {
        // 7th Synthesis row (iter-95): Metal pipeline pair —
        // distinct from iter-11 (tier-compression), iter-24 (near-
        // duplicate), iter-45 (hardware-floor), iter-75 (agent-
        // runtime), iter-85 (storage-tokenizer), iter-89 (near-
        // duplicate compression-canon). Reuses iter-91's
        // metal_compute_shader_kernel.md (which contains "pipeline")
        // as one pair-partner, plus one new seed
        // metal_compute_pipeline_v2.md. AND-conjunction on 3 terms
        // {metal, compute, pipeline} matches only this pair; the
        // 3 iter-91 single-term decoys are blocked.
        query: "metal compute pipeline",
        expected_paths: &[
            "notes/metal_compute_shader_kernel.md",
            "notes/metal_compute_pipeline_v2.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 3,
        note: "Seventh Synthesis row (iter-95): Apple Metal pipeline \
               pair-retention domain. Reuses iter-91's Adversarial \
               canonical (the metal_compute_shader_kernel seed \
               carries the bigram \"metal compute pipeline\" by \
               design) and adds one new pair-partner seed. AND-\
               conjunction on 3 terms {metal, compute, pipeline} \
               matches both pair-partner docs; iter-91's single-\
               term partial-overlap decoys (metal_archive / \
               compute_brainstorm / shader_misc_notes) each \
               carry ≤ 1 of the 3 terms and are filtered out by \
               AND. Pre-MMR baseline: both pair-partners retained \
               at top-3. Cross-row safety: iter-91's top_n=1 \
               contract on its 4-term query still holds because \
               the new pair-partner has metal+compute but no \
               shader/kernel, so iter-91's canonical (4/4 terms) \
               outranks it. Iter-92's ChattyPrefix contract also \
               holds: AND on {metal, compute, shader} blocks the \
               new pair-partner (no shader token).",
    },
    FVaultRecallRow {
        // 6th PureChatter row (iter-94): need/pronoun-led shape —
        // distinct from iter-16/30/49 imperative-led, iter-73 wh-led,
        // iter-83 modal-led. Tokens {i, need, some, of, my, notes}
        // are all in QUERY_CHATTER_WORDS (i + need + some + of + my +
        // notes all listed in vault.rs), so strip_query_chatter
        // empties the query → all_chatter_fallback flag flips →
        // evidence_strength() == Weak → row PASSES via the
        // PureChatter contract.
        query: "i need some of my notes",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Sixth PureChatter row (iter-94): need/pronoun-led \
               shape (first-person + need) — a 6th structural lead \
               pattern distinct from imperative (iters 16/30/49), \
               wh (iter-73), and modal (iter-83). All six tokens \
               {i, need, some, of, my, notes} are listed in \
               QUERY_CHATTER_WORDS (vault.rs) — the strip empties \
               the query → all_chatter_fallback flips → evidence \
               Weak. Together iters 16/30/49/73/83/94 span six \
               structural lead patterns, proving the \
               all_chatter_fallback detection isn't keyed to any \
               specific lead-token family.",
    },
    FVaultRecallRow {
        // 6th Unicode row (iter-93): Greek script — extends the
        // multilingual axis from 3 non-Latin scripts (CJK / Cyrillic
        // / Arabic; iters 19/28/32) to 4 by adding Greek (Latin +
        // λ + Latin). Greek codepoint range U+0370–U+03FF. Tantivy's
        // SimpleTokenizer treats single-letter Greek as a token
        // (Letter Unicode property), so AND on {Mamba, λ, cache}
        // matches the new seed and blocks the iter-9 Latin-only doc
        // for the same reason iters 19/28/32 do (no Greek token).
        query: "Mamba λ cache",
        expected_paths: &["notes/mamba_greek_lambda.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Sixth Unicode row (iter-93): Greek-script extension. \
               Adds a 4th non-Latin script — Greek λ (lambda, U+03BB) \
               — alongside CJK (iter-19), Cyrillic (iter-28), Arabic \
               (iter-32). Latin \"Mamba\" + Greek \"λ\" + Latin \
               \"cache\" tokenized as three distinct tokens. The \
               forbidden iter-9 seed (notes/mamba_english_only.md) \
               has Latin only — AND on the Greek token blocks it, \
               same no-script-fold contract as the other multilingual \
               rows. Unicode category now spans diacritics + 4 non-\
               Latin scripts + pure-CJK = 6 sub-axes.",
    },
    FVaultRecallRow {
        // 8th ChattyPrefix row (iter-105): MLX-Swift signal domain
        // — 8th distinct signal domain alongside residency-
        // governance (iter-2/31), tier-compression-governance
        // (iter-47), agent-runtime-trace (iter-71), storage/vault
        // (iter-82), Metal-compute (iter-92), wh+about (iter-98).
        // Reuses iter-100's MLX corpus entirely — zero new seeds.
        // Survivors after strip_query_chatter: {mlx, swift,
        // backend} — 3 terms triggers AND-conjunction. Only
        // iter-100's canonical carries all three; the 3 single-
        // term partial-overlap decoys are blocked by AND.
        query: "Show me my mlx swift backend notes",
        expected_paths: &["notes/mlx_swift_inference_backend.md"],
        forbidden_paths: &[
            "notes/mlx_archive.md",
            "notes/swift_brainstorm.md",
            "notes/inference_misc_notes.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Eighth ChattyPrefix row (iter-105): MLX-Swift signal \
               domain — extends strip-robust coverage to an 8th \
               distinct lexical universe. Chatter prefix {Show, \
               me, my} + chatter suffix {notes}; survivors {mlx, \
               swift, backend} — 3 surviving terms triggers AND-\
               conjunction. Reuses iter-100's seeded canonical + \
               3 partial-overlap decoys. Together iters 2/31/47/ \
               71/82/92/98/105 prove the strip is robust across \
               7+ chatter shapes × 8 signal domains. A future \
               tokenizer or stripper change that mishandles MLX-\
               vocabulary terms flips this row to FAIL.",
    },
    FVaultRecallRow {
        // 6th ChattyPrefix row (iter-92): new signal domain — Apple
        // Metal compute — distinct from iters 2/31 (residency-
        // governance), iter-47 (tier-compression-governance),
        // iter-71 (agent-runtime-trace), iter-82 (storage/vault).
        // Reuses iter-91's Adversarial seed corpus (canonical with
        // all of {metal, compute, shader, kernel} + 3 single-term
        // partial-overlap decoys). Survivors after strip_query_chatter:
        // {metal, compute, shader} — 3 terms triggers AND-conjunction
        // (set_conjunction_by_default), and only the canonical doc
        // carries all three signal terms. Decoys each carry ONE, so
        // AND blocks them and the forbidden contract holds at top-7.
        query: "Could you pull my notes on metal compute shader",
        expected_paths: &["notes/metal_compute_shader_kernel.md"],
        forbidden_paths: &[
            "notes/metal_archive.md",
            "notes/compute_brainstorm.md",
            "notes/shader_misc_notes.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Sixth ChattyPrefix row (iter-92): Apple Metal compute \
               signal domain — extends strip-robust coverage to a 6th \
               distinct lexical universe. Chatter prefix {Could, you, \
               pull, my, notes, on}; survivors {metal, compute, \
               shader} — 3 surviving terms triggers AND-conjunction. \
               Reuses iter-91's seeded canonical + 3 partial-overlap \
               decoys. Together iters 2/31/47/71/82/92 prove the \
               strip is robust across five-plus chatter shapes × six \
               signal domains. A future tokenizer or stripper change \
               that mishandles Metal-vocabulary terms flips this row \
               to FAIL.",
    },
    FVaultRecallRow {
        // 8th Adversarial row (iter-110): Apple Metal compute
        // domain, alternate 4-term query — reuses iter-91 corpus
        // entirely (zero new seeds). Drops "compute" from the
        // iter-91 query and adds "pipeline" (which iter-91's
        // canonical also carries, by design). Forces BM25 to
        // discriminate against a richer pool: iter-95's pair-
        // partner notes/metal_compute_pipeline_v2.md carries 2
        // of the 4 query terms (metal+pipeline) so it becomes
        // a NEW partial-overlap competitor that the prior iter-91
        // row didn't face. Canonical's 4-of-4 coverage with
        // higher per-term TFs still wins at top_n = 1.
        query: "metal kernel pipeline shader",
        expected_paths: &["notes/metal_compute_shader_kernel.md"],
        forbidden_paths: &[
            "notes/metal_archive.md",
            "notes/shader_misc_notes.md",
            "notes/compute_brainstorm.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Eighth Adversarial row (iter-110): same Metal corpus \
               as iter-91 but a different 4-term query subset \
               (drops \"compute\", adds \"pipeline\"). Forces BM25 \
               to discriminate against a 2-of-4 partial-overlap \
               competitor (iter-95's metal_compute_pipeline_v2 \
               carries metal+pipeline) that the original iter-91 \
               row didn't face. Canonical's 4-of-4 coverage with \
               TF≈3 on three terms wins at top_n = 1. Zero new \
               seeds; proves the BM25 ranking is robust against \
               richer partial-overlap pools, not just single-term \
               decoys.",
    },
    FVaultRecallRow {
        // 6th Adversarial row (iter-91): Apple Metal compute domain
        // — distinct from iter-15 (design-system), iter-27 (graph/
        // event), iter-43 (agent-runtime), iter-66 (storage/vault),
        // iter-84 (IR-search-ranking-BM25-saturation). Same shape:
        // 4 surviving terms → OR-conjunction; 3 partial-overlap
        // decoys each carrying ONE term; canonical carries ALL 4
        // 2-3× each so BM25 ranks it #1 at top_n = 1. Per CLAUDE.md
        // "Metal compute shaders" is a substrate-canonical domain.
        query: "metal compute shader kernel",
        expected_paths: &["notes/metal_compute_shader_kernel.md"],
        forbidden_paths: &[
            "notes/metal_archive.md",
            "notes/compute_brainstorm.md",
            "notes/shader_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Sixth Adversarial row (iter-91): Apple Metal compute \
               canon — extends the cross-domain breadth to 6 \
               families (design-system / graph-event / agent-runtime \
               / storage-vault / IR-BM25 / Metal-compute). Same \
               shape (4-term OR-conjunction; 3 single-term \
               partial-overlap decoys; top_n = 1 forces BM25-\
               ranking discrimination), new lexical universe. \
               A future tokenizer change that disrupts BM25 \
               ranking on Apple Metal vocabulary flips this row \
               to FAIL and the diagnostics surface flags the \
               regression at the Metal-substrate terms \
               specifically.",
    },
    FVaultRecallRow {
        // 2nd typo Paraphrase row (iter-90): extends the typo
        // deep-hardening axis (axis #4) from one subclass (single-
        // char substitution, iter-20: "SSL" ↔ "SSM") to two
        // subclasses (substitution + adjacent transposition).
        // Query "inedx" is "index" with the d-e bigram transposed
        // — a different lexical-edit class than substitution.
        // Reuses the iter-66 storage/vault-canon corpus (no new
        // seeds). Domain breadth: Mamba (iter-20) + vault-canon
        // (iter-90); subclass breadth: substitution + transposition.
        // CURRENTLY FAILS by design — AND on {vault, inedx, reload}
        // blocks the canonical because Tantivy's SimpleTokenizer
        // has no edit-distance / fuzzy matching.
        query: "vault inedx reload",
        expected_paths: &["notes/vault_index_reload_canon.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Adjacent-transposition typo subclass (axis #4 \
               extension): user typed \"inedx\" (the bigram \"de\" \
               in \"index\" transposed to \"ed\") instead of \
               \"index\". Tantivy's default SimpleTokenizer treats \
               every token literally — no edit-distance / \
               transposition tolerance — so 3-term AND on {vault, \
               inedx, reload} blocks the canonical (which has \
               vault + reload but NOT \"inedx\"). Distinct from \
               iter-20's single-char substitution subclass (SSL → \
               SSM): same axis (typos / lexical edit) but a \
               different edit operation. Two domains: Mamba SSM \
               (iter-20) + vault-canon (iter-90). Two typo \
               subclasses: substitution + transposition. \
               CURRENTLY FAILS by design — pins Fix-C deferred \
               fuzzy-match work (e.g. Tantivy's TermSetQuery with \
               edit-distance 1-2, BK-tree, or embedding-based \
               typo-robust retrieval). When fuzzy matching ships, \
               BOTH iter-20 AND iter-90 must flip to ✅ — proving \
               the fix covers more than one specific typo.",
    },
    FVaultRecallRow {
        // 3rd near-duplicate Synthesis row (iter-108): extends the
        // near-duplicate-tie-breaks axis (axis #6) from 2 domains
        // (iter-24 design-pattern + iter-89 compression-doctrine-
        // canon) to 3 domains by adding neural-cache-layer.
        // Pair of near-identical docs both carry every query term;
        // AND-conjunction returns both, top_n = 2 retains the
        // pair, pre-MMR baseline.
        query: "neural cache layer",
        expected_paths: &[
            "notes/neural_cache_layer_v1.md",
            "notes/neural_cache_layer_v2.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Third near-duplicate Synthesis row (iter-108): \
               neural-cache-layer domain. AND-conjunction on 3 \
               terms {neural, cache, layer} matches only the new \
               pair (no other seeded doc has all three — \
               mamba_ssm_cache has \"cache\" but no neural/layer; \
               every other seed lacks 2+ of the 3 terms). Three \
               near-duplicate rows now prove the axis works \
               across three domains, not two. Pre-MMR baseline: \
               both retained at top-2. Once MMR ships all three \
               near-duplicate rows must flip their contract \
               together (forbid the duplicate or tighten top_n).",
    },
    FVaultRecallRow {
        // 2nd near-duplicate Synthesis row (iter-89): extends the
        // near-duplicate-tie-breaks axis (axis #6) from one example
        // to two. Iter-24 pins design-pattern domain; iter-89 pins
        // compression-doctrine-canon domain. Pair of near-identical
        // docs both carry all 3 query terms with equal frequency;
        // AND-conjunction returns both, BM25 ranks them similarly,
        // top_n = 2 retains the pair. Pre-MMR baseline contract —
        // same as iter-24, different domain. When a real MMR
        // diversifier ships (RetrievalSignal::Mmr populated), this
        // row may need to flip its contract.
        query: "compression doctrine canon",
        expected_paths: &[
            "notes/compression_doctrine_canon_v1.md",
            "notes/compression_doctrine_canon_v2.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Second near-duplicate Synthesis row (iter-89): \
               compression-doctrine-canon domain — distinct from \
               iter-24's design-pattern domain. Pair of near-\
               identical docs both carry every query term with \
               equal frequency so BM25 ranks them similarly; AND-\
               conjunction on 3 terms {compression, doctrine, \
               canon} returns both. Pass requires top-2 to retain \
               both — pre-MMR baseline contract. Two rows now \
               prove the near-duplicate axis works across domains, \
               not just one example. Once a real MMR diversifier \
               ships (Fix-C semantic-recall era, \
               RetrievalSignal::Mmr populated), both rows may need \
               to flip their contract — either grow a forbidden \
               near-duplicate (encoding the dedup invariant) or \
               tighten top_n to 1 (one canonical winner).",
    },
    FVaultRecallRow {
        // 2nd exact-quote PhraseQuery row (iter-88): extends the
        // exact-quote axis (axis #2) to a 2nd domain — the iter-15
        // design-system corpus, distinct from iter-7's residency-
        // governance domain. Pins position-sensitivity: PhraseQuery
        // requires the bigram at ADJACENT positions; a forbidden
        // decoy carries both tokens but with intervening text and
        // must NOT match. With both rows the axis is no longer a
        // single example — it generalizes across two domains.
        query: "\"design system\"",
        expected_paths: &["notes/design_system_hover_spec.md"],
        forbidden_paths: &["notes/design_general_system.md"],
        category: FVaultRecallCategory::SignalOnly,
        // top_n = 5 mirrors iter-7's pattern — PhraseQuery + AND
        // already cuts the candidate pool to docs containing the
        // exact bigram; top-5 gives slack for any other adjacent-
        // bigram doc to land without breaking the forbidden
        // contract on the non-adjacent decoy.
        top_n: 5,
        note: "Second exact-quote PhraseQuery row (iter-88): \
               design-system domain — distinct from iter-7's \
               residency-governance domain. Same shape: literal \
               `\"…\"` quotes in the query become a Tantivy \
               PhraseQuery; expected doc carries the bigram at \
               adjacent token positions, forbidden decoy carries \
               both tokens but with intervening text so the phrase \
               does NOT match. Reuses iter-15's canonical \
               (design_system_hover_spec.md: \"design system hover \
               specification design system hover specification\" — \
               two adjacent occurrences of the bigram) and adds \
               one new forbidden seed (design_general_system.md: \
               \"design general overview system notes architecture\" \
               — both tokens present, non-adjacent). Two rows now \
               prove the exact-quote axis works across two \
               domains, not just one example.",
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
        // Iter-66 storage/vault canon row (4th Adversarial, 4th domain
        // family). Symmetric breadth across the substrate-canon
        // vocabulary.
        assert!(
            adversarials
                .iter()
                .any(|r| r.query == "vault index reload tantivy"),
            "iter-66 storage/vault canon row must be present"
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
