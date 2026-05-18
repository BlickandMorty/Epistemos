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
        // 27th SignalOnly row (iter-246): single-term query in
        // Hebrew-script domain — "ש" (U+05E9 shin, single-
        // codepoint letter). EIGHTEENTH single-term-AND domain.
        // SIXTH non-ASCII script-block in the pin set (after
        // Latin-diacritic + Cyrillic + CJK + Arabic + Greek).
        // Hebrew is RTL — SECOND RTL script-block (after iter-231
        // Arabic) and second within Aramaic-descendant families.
        // Second single-codepoint non-ASCII token (after iter-238
        // λ). Token unique to iter-109 mamba_hebrew.md.
        query: "ש",
        expected_paths: &["notes/mamba_hebrew.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Twenty-seventh SignalOnly row (iter-246): single-\
               term Hebrew-script query — \"ש\" (U+05E9). \
               Eighteenth domain for single-term-AND. Sixth non-\
               ASCII script-block. Second RTL script (after \
               Arabic at iter-231) AND second Aramaic-descendant \
               family (after Arabic — Hebrew is in the same \
               Northwest-Semitic branch as Aramaic/Syriac). \
               Second single-codepoint non-ASCII token (after \
               Greek λ). Brings SignalOnly to depth 27.",
    },
    FVaultRecallRow {
        // 26th SignalOnly row (iter-238): single-term query in
        // Greek-script domain — "λ" (U+03BB lambda, single-
        // codepoint mathematical-and-Greek letter). SEVENTEENTH
        // single-term-AND domain. FIFTH non-ASCII token in the
        // pin set (after Latin-diacritic + Cyrillic + CJK +
        // Arabic). Token "λ" appears only in iter-93's
        // mamba_greek_lambda.md among all seeded docs. Pins
        // AND-on-1 across a fifth distinct Unicode script-block
        // — and the FIRST single-codepoint non-ASCII token (vs
        // multi-codepoint кэш/笔记/كاش/naïve). Proves single-
        // codepoint tokens tokenize the same as multi-codepoint
        // words.
        query: "λ",
        expected_paths: &["notes/mamba_greek_lambda.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Twenty-sixth SignalOnly row (iter-238): single-\
               term Greek-script query — \"λ\" (U+03BB). \
               Seventeenth domain for single-term-AND. Fifth non-\
               ASCII script-block after Latin-diacritic + \
               Cyrillic + CJK + Arabic. FIRST single-codepoint \
               token in the pin set (prior non-ASCII tokens were \
               multi-codepoint). Token unique to iter-93 \
               mamba_greek_lambda.md. Pins AND-on-1 across \
               single-codepoint token shape — proves Tantivy \
               SimpleTokenizer treats codepoint-cardinality \
               agnostically. Brings SignalOnly to depth 26.",
    },
    FVaultRecallRow {
        // 25th SignalOnly row (iter-231): single-term query in
        // Arabic-script domain — "كاش" (Arabic transliteration
        // of "cache", U+0643 U+0627 U+0634). SIXTEENTH single-
        // term-AND domain. FOURTH non-ASCII token in the single-
        // term-AND pin set (after Latin-diacritic + Cyrillic +
        // CJK). Arabic is RTL — Tantivy SimpleTokenizer is
        // direction-agnostic, so the RTL token tokenizes the
        // same as any other Unicode word. Token unique to iter-32
        // mamba_arabic.md. Pins AND-on-1 across a fourth distinct
        // Unicode script-block — and the FIRST RTL script in the
        // single-term-AND pin set.
        query: "كاش",
        expected_paths: &["notes/mamba_arabic.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Twenty-fifth SignalOnly row (iter-231): single-\
               term Arabic-script query — \"كاش\" (U+0643 U+0627 \
               U+0634). Sixteenth domain for single-term-AND. \
               Fourth non-ASCII token (after Latin-diacritic + \
               Cyrillic + CJK) and FIRST RTL script in the pin \
               set. Token unique to iter-32 mamba_arabic.md. \
               Pins AND-on-1 across both bidirectional rendering \
               (Tantivy SimpleTokenizer is direction-agnostic) \
               AND non-Latin script-block. Brings SignalOnly to \
               depth 25.",
    },
    FVaultRecallRow {
        // 24th SignalOnly row (iter-223): single-term query in
        // CJK-script domain — "笔记" (Chinese for "notes",
        // U+7B14 U+8BB0). FIFTEENTH single-term-AND domain.
        // THIRD non-ASCII token in the single-term-AND pin set
        // (after iter-210 Latin-diacritic and iter-217 Cyrillic).
        // Tantivy SimpleTokenizer treats consecutive CJK
        // codepoints as a single token (no CJK segmentation);
        // pure_chinese.md has 笔记 as one whitespace-bounded
        // token. Latin_only_ssm.md (iter-23 forbidden) has no
        // CJK codepoints at all, so AND-on-1 blocks it. Pins
        // AND-on-1 across the East Asian Han Ideograph block —
        // a third script-block beyond Latin-with-marks and
        // Cyrillic. Zero new seeds.
        query: "笔记",
        expected_paths: &["notes/pure_chinese.md"],
        forbidden_paths: &["notes/latin_only_ssm.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Twenty-fourth SignalOnly row (iter-223): single-\
               term CJK-script query — \"笔记\" (U+7B14 U+8BB0). \
               Fifteenth domain for single-term-AND. Third non-\
               ASCII token after iter-210 Latin-diacritic + \
               iter-217 Cyrillic. Tantivy treats consecutive CJK \
               codepoints as one token. Token unique to iter-23 \
               pure_chinese.md. Three non-ASCII script-blocks \
               now pin the AND-on-1 path (Latin-with-marks + \
               Cyrillic + Han Ideograph). Brings SignalOnly to \
               depth 24.",
    },
    FVaultRecallRow {
        // 23rd SignalOnly row (iter-217): single-term query in
        // Cyrillic-script domain — "кэш" (Cyrillic transliteration
        // of "cache", U+043A U+044D U+0448). FOURTEENTH single-
        // term-AND domain. SECOND non-ASCII token in the single-
        // term-AND pin set (after iter-210 Latin-diacritic). Token
        // "кэш" appears only in iter-28's mamba_cyrillic.md among
        // all seeded docs. iter-9 mamba_english_only.md (the
        // canonical forbidden) lacks Cyrillic codepoints entirely.
        // Pins the AND-on-1 path across a non-Latin script
        // boundary — proves it scales beyond Latin-diacritic
        // tokens into entirely separate Unicode script blocks.
        query: "кэш",
        expected_paths: &["notes/mamba_cyrillic.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Twenty-third SignalOnly row (iter-217): single-\
               term Cyrillic-script query — \"кэш\". Fourteenth \
               domain for the single-term-AND boundary. Second \
               non-ASCII token after iter-210 Latin-diacritic — \
               pins AND-on-1 across a non-Latin script-block \
               boundary, not just Latin-with-marks. Token unique \
               to iter-28's mamba_cyrillic.md. Reuses iter-28 \
               corpus; zero new seeds. Brings SignalOnly to \
               depth 23.",
    },
    FVaultRecallRow {
        // 22nd SignalOnly row (iter-210): single-term query in
        // Latin-diacritic domain — "naïve" (U+0069 + U+0308 / pre-
        // composed U+00EF). THIRTEENTH single-term-AND domain.
        // First non-ASCII token in the single-term-AND pin set —
        // proves the AND-on-1 path holds across the script
        // boundary too, not just ASCII identifiers. Tantivy's
        // SimpleTokenizer keeps diacritics intact (no NFKD
        // folding), so "naïve" stays distinct from "naive". The
        // iter-3 Unicode canonical unicode_resume_filter.md
        // carries "naïve" (with diacritic); the iter-3 forbidden
        // ascii_only_resume.md has "naive" (no diacritic) and
        // is blocked by AND. Reuses iter-3 corpus; zero new
        // seeds.
        query: "naïve",
        expected_paths: &["notes/unicode_resume_filter.md"],
        forbidden_paths: &["notes/ascii_only_resume.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Twenty-second SignalOnly row (iter-210): single-\
               term Latin-diacritic query — \"naïve\". Thirteenth \
               domain for the single-term-AND boundary alongside \
               the prior 12 ASCII-token domains. FIRST non-ASCII \
               token in the single-term-AND pin set — proves the \
               AND-on-1 path holds across the script boundary, \
               not just inside the ASCII identifier vocabulary. \
               Tantivy SimpleTokenizer keeps diacritics intact, \
               so \"naïve\" ≠ \"naive\". Reuses iter-3 Unicode \
               corpus; zero new seeds. Brings SignalOnly to \
               depth 22.",
    },
    FVaultRecallRow {
        // 21st SignalOnly row (iter-202): single-term query in
        // machine-learning domain — "machine". TWELFTH single-
        // term-AND domain. Token "machine" appears only in iter-86
        // canonical machine_learning_inference_cache.md among
        // seeded docs. The canonical doubles as the iter-86
        // Paraphrase failure target (acronym axis "ml" vs
        // "machine learning") but for SignalOnly the literal token
        // discriminates cleanly. Brings SignalOnly to depth 21 —
        // fourth category past the depth-20 horizon. Zero new
        // seeds.
        query: "machine",
        expected_paths: &["notes/machine_learning_inference_cache.md"],
        forbidden_paths: &["notes/generic_attention_overview.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Twenty-first SignalOnly row (iter-202): single-term \
               machine-learning query — \"machine\". Twelfth \
               domain for the single-term-AND boundary alongside \
               physics, storage-vault, agent-runtime, MLX-Swift, \
               Metal-compute, IR-BM25, hardware-falsifier, graph-\
               event, compression-doctrine, design-system, \
               tokenizer-indexing. TWELVE distinct domains pin \
               the AND-on-1 path. Same canonical doubles as the \
               iter-86 Paraphrase failure target (acronym \"ml\" \
               vs \"machine learning\") — proves the same doc \
               can be both a Paraphrase failure (acronym \
               expansion absent) AND a SignalOnly success \
               (literal-token retrieval). Brings SignalOnly to \
               depth 21. Zero new seeds.",
    },
    FVaultRecallRow {
        // 20th SignalOnly row (iter-195): single-term query in
        // tokenizer/indexing domain — "ngramtokenizer". ELEVENTH
        // single-term-AND domain. Token "ngramtokenizer" lowercases
        // out of the SimpleTokenizer pipeline (Tantivy's default
        // SimpleTokenizer lowercases) and appears only in the iter-85
        // pair-partner internals doc. The pair-partner overview doc
        // has SimpleTokenizer but not NGramTokenizer, so AND-on-1
        // discriminates between the two near-duplicate Synthesis
        // pair-partners — same lexical universe, different unique
        // token. Reuses iter-85 corpus; zero new seeds.
        query: "ngramtokenizer",
        expected_paths: &["notes/tokenizer_indexing_tantivy_internals.md"],
        forbidden_paths: &["notes/tokenizer_indexing_tantivy_overview.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Twentieth SignalOnly row (iter-195): single-term \
               tokenizer/indexing query — \"ngramtokenizer\". Eleventh \
               domain for the single-term-AND boundary alongside \
               physics, storage-vault, agent-runtime, MLX-Swift, \
               Metal-compute, IR-BM25, hardware-falsifier, graph-\
               event, compression-doctrine, design-system. ELEVEN \
               distinct domains now pin the AND-on-1 path. \
               Discriminates between the iter-85 near-duplicate \
               pair-partners: internals has NGramTokenizer (unique), \
               overview has SimpleTokenizer only. Lowercase-pipeline \
               proof: query \"ngramtokenizer\" matches via Tantivy's \
               default SimpleTokenizer lowercase pass. Brings \
               SignalOnly to depth 20 alongside Adversarial, \
               Synthesis, Paraphrase. Zero new seeds.",
    },
    FVaultRecallRow {
        // 19th SignalOnly row (iter-188): single-term query in
        // design-system domain — "specification". TENTH single-
        // term-AND domain. Token appears only in
        // design_system_hover_spec.md among seeded docs.
        query: "specification",
        expected_paths: &["notes/design_system_hover_spec.md"],
        forbidden_paths: &["notes/old_hover_brainstorm.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Nineteenth SignalOnly row (iter-188): single-term \
               design-system query — \"specification\". Tenth \
               domain for the single-term-AND boundary alongside \
               the prior 9. The token appears only in iter-15's \
               design_system_hover_spec.md. Zero new seeds.",
    },
    FVaultRecallRow {
        // 18th SignalOnly row (iter-182): single-term query in
        // compression-doctrine-canon (iter-89 near-duplicate
        // pair) domain — "revised". NINTH single-term-AND
        // domain. Token "revised" appears only in iter-89
        // partner v2 (the second copy of the near-duplicate
        // pair), distinguishing it from v1.
        query: "revised",
        expected_paths: &["notes/compression_doctrine_canon_v2.md"],
        forbidden_paths: &["notes/compression_doctrine_canon_v1.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Eighteenth SignalOnly row (iter-182): single-term \
               compression-doctrine-canon query — \"revised\". \
               Ninth domain for the single-term-AND boundary. \
               The token uniquely distinguishes iter-89 partner \
               v2 from v1 — the revision-marker on the near-\
               duplicate pair. Same lexical universe as the \
               iter-89 near-duplicate Synthesis pair but \
               exercises the single-token discrimination path \
               between the two near-identical docs. Zero new \
               seeds.",
    },
    FVaultRecallRow {
        // 17th SignalOnly row (iter-173): single-term query in
        // graph-event domain — "session" (from iter-27 canonical
        // body). EIGHTH single-term-AND domain alongside the
        // prior 7. Token "session" appears only in
        // canonical_graph_event_v3.md among seeded docs.
        query: "session",
        expected_paths: &["notes/canonical_graph_event_v3.md"],
        forbidden_paths: &["notes/graph_brainstorm.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Seventeenth SignalOnly row (iter-173): single-term \
               graph-event query — \"session\". Eighth domain for \
               the single-term-AND boundary alongside physics, \
               storage-vault, agent-runtime, MLX-Swift, Metal-\
               compute, IR-BM25, hardware-falsifier. EIGHT \
               distinct domains pin the AND-on-1 path. Zero new \
               seeds.",
    },
    FVaultRecallRow {
        // 16th SignalOnly row (iter-164): single-term query in
        // hardware-falsifier domain — "uma" (Unified Memory
        // Architecture, from iter-19 canonical's "M2 Pro 16 GB
        // UMA" body). SEVENTH single-term-AND domain. Token
        // appears only in m2_pro_hardware_floor.md; its iter-19
        // pair-partner falsifier_handbook lacks it. Zero new
        // seeds.
        query: "uma",
        expected_paths: &["notes/m2_pro_hardware_floor.md"],
        forbidden_paths: &["notes/falsifier_handbook.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Sixteenth SignalOnly row (iter-164): single-term \
               hardware-falsifier query — \"uma\". Seventh \
               domain for the single-term-AND boundary alongside \
               physics, storage-vault, agent-runtime, MLX-Swift, \
               Metal-compute, IR-BM25. Token \"uma\" (Unified \
               Memory Architecture) appears only in m2_pro_\
               hardware_floor.md — even its pair-partner \
               (falsifier_handbook) lacks it. Zero new seeds.",
    },
    FVaultRecallRow {
        // 15th SignalOnly row (iter-157): single-term query in
        // IR-BM25 domain — "ranking". SIXTH single-term-AND
        // domain alongside physics (iter-17), storage-vault
        // (iter-131), agent-runtime (iter-137), MLX-Swift
        // (iter-143), Metal-compute (iter-149). Token "ranking"
        // appears only in iter-84 canonical body. Zero new seeds.
        query: "ranking",
        expected_paths: &["notes/bm25_saturation_length_penalty.md"],
        forbidden_paths: &["notes/bm25_overview.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Fifteenth SignalOnly row (iter-157): single-term \
               IR-BM25 query — \"ranking\". Sixth domain for the \
               single-term-AND boundary (physics + storage-vault \
               + agent-runtime + MLX-Swift + Metal-compute + \
               IR-BM25). Six distinct domains pin the AND-on-1 \
               path. Zero new seeds.",
    },
    FVaultRecallRow {
        // 14th SignalOnly row (iter-149): single-term query in
        // Metal-compute domain — "kernel". FIFTH single-term-AND
        // domain alongside physics (iter-17), storage-vault
        // (iter-131), agent-runtime (iter-137), MLX-Swift
        // (iter-143). Token "kernel" appears only in iter-91
        // canonical among seeded docs. Reuses iter-91 corpus;
        // zero new seeds.
        query: "kernel",
        expected_paths: &["notes/metal_compute_shader_kernel.md"],
        forbidden_paths: &["notes/shader_misc_notes.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Fourteenth SignalOnly row (iter-149): single-term \
               Metal-compute query — \"kernel\". Fifth domain for \
               the single-term-AND boundary (physics + storage-\
               vault + agent-runtime + MLX-Swift + Metal-compute). \
               Five distinct domains pin the AND-on-1 path — the \
               contract holds across substrate-canon, IR-domain, \
               and Apple-platform vocabularies. Token appears \
               only in iter-91 canonical; zero new seeds.",
    },
    FVaultRecallRow {
        // 13th SignalOnly row (iter-143): single-term query in
        // MLX-Swift inference domain — "local" (from iter-100
        // canonical's "local model pipeline" context). Fourth
        // single-term-AND domain alongside iter-17 (physics),
        // iter-131 (vault-canon), iter-137 (agent-runtime).
        // Token "local" appears only in iter-100 canonical among
        // all seeded docs. Reuses iter-100 corpus; zero new seeds.
        query: "local",
        expected_paths: &["notes/mlx_swift_inference_backend.md"],
        forbidden_paths: &["notes/inference_misc_notes.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Thirteenth SignalOnly row (iter-143): single-term \
               MLX-Swift query — \"local\". Fourth domain for the \
               single-term-AND boundary alongside iter-17 \
               (physics: Hamiltonian), iter-131 (storage-vault: \
               vaultstore), iter-137 (agent-runtime: invader). \
               Four distinct domains pin the AND-on-1 path — \
               proves the contract isn't tied to any specific \
               token or domain family. Token \"local\" appears \
               only in iter-100 canonical; zero new seeds.",
    },
    FVaultRecallRow {
        // 12th SignalOnly row (iter-137): single-term query in
        // agent-runtime domain — "invader" (from iter-43
        // canonical's "System G Invader" context). Third single-
        // term SignalOnly row alongside iter-17 (Hamiltonian /
        // physics) and iter-131 (vaultstore / storage-vault).
        // Token "invader" appears only in iter-43 canonical
        // among all seeded docs; iter-75 partner has "System G
        // canon" but not Invader. Reuses iter-43 corpus; zero
        // new seeds.
        query: "invader",
        expected_paths: &["notes/agent_runtime_v2_substrate.md"],
        forbidden_paths: &["notes/agent_brainstorm.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Twelfth SignalOnly row (iter-137): single-term \
               agent-runtime query — \"invader\". Third domain \
               for single-term-AND boundary alongside iter-17 \
               (physics) and iter-131 (storage-vault). The token \
               appears only in iter-43 canonical among all \
               seeded docs (iter-75 partner has \"System G\" but \
               not \"Invader\"). Single-term boundary now pinned \
               across 3 distinct domains — proves the AND-on-1 \
               path is not coincidentally keyed to one specific \
               token. Zero new seeds.",
    },
    FVaultRecallRow {
        // 11th SignalOnly row (iter-131): single-term query in
        // vault-canon domain. Mirror of iter-17 ("Hamiltonian"
        // single-term in physics domain) but in storage/vault.
        // The token "vaultstore" appears only in iter-66's
        // canonical (from "VaultStore::reload_index" tokenizing
        // to vaultstore + reload + index — no other seed has
        // "vaultstore"). AND on 1 token matches only the
        // canonical. Reuses iter-66 corpus; zero new seeds.
        query: "vaultstore",
        expected_paths: &["notes/vault_index_reload_canon.md"],
        forbidden_paths: &["notes/tantivy_misc_notes.md"],
        category: FVaultRecallCategory::SignalOnly,
        top_n: 5,
        note: "Eleventh SignalOnly row (iter-131): single-term \
               vault-canon query — \"vaultstore\". Mirror of \
               iter-17 (\"Hamiltonian\" single-term in physics) \
               but in the storage/vault canon. Pins the 1-term \
               AND-conjunction path against an implementation-\
               vocabulary token: the token appears only in the \
               iter-66 canonical (from \"VaultStore::reload_index\" \
               tokenizing to vaultstore + reload + index). \
               Reuses iter-66 corpus, zero new seeds.",
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
        // 27th Unicode row (iter-249): Glagolitic-script
        // extension. Adds a 25th non-Latin script (Glagolitic,
        // U+2C00–U+2C5F) — the oldest Slavic alphabet,
        // attributed to Saints Cyril and Methodius (9th century),
        // predating Cyrillic itself. Same language community
        // (Slavic) as Cyrillic but different writing system —
        // SECOND Slavic script-block in the pin set, parallel to
        // the Han+Bopomofo+Yi pattern (three East-Asian script-
        // blocks for one community). Latin "Mamba" + Glagolitic
        // "ⰽ" (kako, U+2C2D) + Latin "cache".
        query: "Mamba ⰽ cache",
        expected_paths: &["notes/mamba_glagolitic.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Twenty-seventh Unicode row (iter-249): Glagolitic-\
               script extension. TWENTY-FIVE non-Latin scripts \
               pinned. Glagolitic is the oldest Slavic alphabet \
               (9th-century, attributed to Cyril and Methodius), \
               predating Cyrillic. Adds a SECOND Slavic script-\
               block — proves no-script-fold distinguishes \
               script BLOCKS even within one language community. \
               Brings Unicode to depth 27 — closes **uniform-\
               ≥-27 milestone**.",
    },
    FVaultRecallRow {
        // 26th Unicode row (iter-242): N'Ko-script extension.
        // Adds a 24th non-Latin script (N'Ko, U+07C0–U+07FF) — a
        // 1949-invented alphabet for Manding languages (Mande
        // family, West Africa), RTL. Distinct from prior African
        // scripts: Ethiopic (abugida, Horn of Africa), Tifinagh
        // (Berber alphabet, North Africa), Vai (syllabary, West
        // Africa). African-origin script count rises to 4
        // spanning four distinct writing-system typologies.
        // Latin "Mamba" + N'Ko "ߞ" (ka, U+07DE) + Latin "cache".
        // SECOND RTL script outside the Aramaic family (Arabic +
        // Syriac were both Aramaic-derived).
        query: "Mamba ߞ cache",
        expected_paths: &["notes/mamba_nko.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Twenty-sixth Unicode row (iter-242): N'Ko-script \
               extension. TWENTY-FOUR non-Latin scripts pinned. \
               N'Ko (1949-invented Mande-family alphabet, RTL) — \
               distinct from prior African scripts: Ethiopic + \
               Tifinagh + Vai. African-origin count now 4 \
               spanning four typologies (abugida + alphabet + \
               syllabary + RTL-alphabet). N'Ko is also the FIRST \
               RTL script outside the Aramaic family (Arabic + \
               Syriac were both Aramaic-derived) — pins RTL \
               coverage across independent script families. \
               Brings Unicode to depth 26 — closes **uniform-\
               ≥-26 milestone**.",
    },
    FVaultRecallRow {
        // 25th Unicode row (iter-235): Yi-script extension.
        // Adds a 23rd non-Latin script (Yi / Nuosu, U+A000–U+A48F)
        // — the modern syllabary for the Yi language family
        // (SW China). Distinct from Han Ideograph and Bopomofo
        // typologies: Yi is syllabic. Brings East-Asian script-
        // block count to 3 spanning three distinct typologies:
        // ideographic (Han) + phonetic-alphabet (Bopomofo) +
        // syllabary (Yi). Latin "Mamba" + Yi "ꀀ" (it, U+A000)
        // + Latin "cache".
        query: "Mamba ꀀ cache",
        expected_paths: &["notes/mamba_yi.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Twenty-fifth Unicode row (iter-235): Yi-script \
               extension. TWENTY-THREE non-Latin scripts pinned. \
               Yi (Nuosu, SW China) is a syllabary — distinct \
               from Han Ideograph and Bopomofo despite sharing \
               the East-Asian region. East-Asian script-block \
               count now 3 across THREE typologies: ideographic \
               + phonetic-alphabet + syllabary. Indigenous-\
               syllabary count now 5 (Cherokee + Vai + Japanese-\
               katakana + Korean-Hangul + Yi). Brings Unicode to \
               depth 25 — closes **uniform-≥-25 milestone**.",
    },
    FVaultRecallRow {
        // 24th Unicode row (iter-227): Bopomofo-script extension.
        // Adds a 22nd non-Latin script (Bopomofo / Zhuyin Fuhao,
        // U+3100–U+312F) — the Mandarin PHONETIC alphabet
        // developed early-20th-century to teach pronunciation
        // independent of Han Ideographs. Distinct from Han
        // Ideograph block: same language community (Chinese-
        // speaking), entirely different writing system
        // (alphabetic-phonetic vs ideographic). Adds a SECOND
        // East-Asian script-block alongside Han CJK, demonstrating
        // no-script-fold contract distinguishes script BLOCKS,
        // not language communities. Latin "Mamba" + Bopomofo
        // "ㄎ" (k, U+310E) + Latin "cache".
        query: "Mamba ㄎ cache",
        expected_paths: &["notes/mamba_bopomofo.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Twenty-fourth Unicode row (iter-227): Bopomofo-\
               script extension. TWENTY-TWO non-Latin scripts \
               pinned. Bopomofo (Zhuyin Fuhao) is the Mandarin \
               phonetic alphabet developed early-20th-century — \
               distinct from Han Ideograph script-block despite \
               serving the same Chinese-speaking community. Adds \
               a second East-Asian script-block alongside Han, \
               demonstrating no-script-fold distinguishes script \
               BLOCKS not language communities. Brings Unicode \
               to depth 24 — closes **uniform-≥-24 milestone**.",
    },
    FVaultRecallRow {
        // 23rd Unicode row (iter-220): Vai-script extension.
        // Adds a 21st non-Latin script (Vai, U+A500–U+A63F) — a
        // West African syllabary devised by Mɔmɔlu Duwalu Bukɛlɛ
        // ca. 1830s for the Vai language (Liberia/Sierra Leone).
        // Contemporary with Cherokee in the 19th-century
        // indigenous-syllabary wave. Brings the indigenous-
        // syllabary count to 4 (Cherokee + Vai + Japanese-
        // katakana + Korean-Hangul) and the African-origin
        // script count to 3 (Ethiopic + Tifinagh + Vai). Latin
        // "Mamba" + Vai "ꕞ" (U+A55E) + Latin "cache".
        query: "Mamba ꕞ cache",
        expected_paths: &["notes/mamba_vai.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Twenty-third Unicode row (iter-220): Vai-script \
               extension. TWENTY-ONE non-Latin scripts pinned. \
               Vai is a 19th-century West African syllabary \
               (Liberia/Sierra Leone), devised by Mɔmɔlu Duwalu \
               Bukɛlɛ ca. 1830s — contemporary with Cherokee in \
               the indigenous-syllabary wave. Brings indigenous-\
               syllabary count to 4 (Cherokee + Vai + Japanese-\
               katakana + Korean-Hangul) and African-origin \
               script count to 3 (Ethiopic abugida + Tifinagh \
               alphabet + Vai syllabary — three distinct \
               typologies). Brings Unicode to depth 23 — closes \
               **uniform-≥-23 milestone**.",
    },
    FVaultRecallRow {
        // 22nd Unicode row (iter-213): Tifinagh-script extension.
        // Adds a 20th non-Latin script (Tifinagh, U+2D30–U+2D7F)
        // — the alphabetic script for Berber languages (North
        // Africa). Pre-Punic origins; modern revival as Neo-
        // Tifinagh codified in Unicode 4.1. Pins an African-
        // origin script family distinct from Ethiopic (the only
        // prior African script — but a Semitic abugida, not
        // alphabetic-and-Berber). Latin "Mamba" + Tifinagh "ⴽ"
        // (yak, U+2D3D) + Latin "cache".
        query: "Mamba ⴽ cache",
        expected_paths: &["notes/mamba_tifinagh.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Twenty-second Unicode row (iter-213): Tifinagh-\
               script extension. TWENTY non-Latin scripts pinned. \
               Tifinagh is the alphabetic script for Berber \
               (North Africa) — pre-Punic origins, modern Neo-\
               Tifinagh codified in Unicode 4.1. Distinct from \
               every prior script family AND brings the African-\
               origin script count to 2 (Ethiopic abugida + \
               Tifinagh alphabet) — two distinct African \
               typological families. Brings Unicode to depth 22 \
               — **uniform-≥-22 milestone**: every category at \
               depth 22.",
    },
    FVaultRecallRow {
        // 21st Unicode row (iter-206): Syriac-script extension.
        // Adds a 19th non-Latin script (Syriac, U+0700–U+074F).
        // Syriac descends directly from Aramaic and is the SISTER
        // of Arabic — both are Aramaic-derived but on different
        // branches. Adds the second Aramaic-family branch beside
        // Mongolian (which descended Aramaic → Sogdian → Old
        // Uyghur → Mongolian). Together iter-198 + iter-206 pin
        // the Aramaic genealogical fan: one direct daughter
        // (Syriac) + one great-great-grand-daughter (Mongolian).
        // Latin "Mamba" + Syriac "ܟ" (kaph, U+071F) + Latin "cache".
        query: "Mamba ܟ cache",
        expected_paths: &["notes/mamba_syriac.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Twenty-first Unicode row (iter-206): Syriac-script \
               extension. NINETEEN non-Latin scripts pinned. \
               Syriac descends directly from Aramaic and is the \
               sister of Arabic — pins the second Aramaic-family \
               branch alongside iter-198 Mongolian (Aramaic-via-\
               Sogdian-Uyghur). Two Aramaic-family branches now: \
               direct daughter (Syriac) + great-great-grand-\
               daughter (Mongolian). Brings Unicode to depth 21 \
               — **uniform-≥-21 milestone**: every category now \
               at depth 21.",
    },
    FVaultRecallRow {
        // 20th Unicode row (iter-198): Mongolian-script extension.
        // Adds an 18th non-Latin script (Mongolian, U+1800–U+18AF).
        // Mongolian descends from Old Uyghur → Sogdian → Aramaic —
        // a distinct branch from Latin/Greek/Cyrillic AND every
        // Brahmic abugida. Alphabetic, traditionally vertical.
        // Latin "Mamba" + Mongolian "ᠺ" (kha, U+183A) + Latin
        // "cache". Brings Unicode to depth 20 alongside all other
        // categories.
        query: "Mamba ᠺ cache",
        expected_paths: &["notes/mamba_mongolian.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Twentieth Unicode row (iter-198): Mongolian-script \
               extension. EIGHTEEN non-Latin scripts pinned. \
               Mongolian descends from Old Uyghur → Sogdian → \
               Aramaic — a distinct ancestral branch from Latin/ \
               Greek/Cyrillic and from every Brahmic abugida \
               (Devanagari/Thai/Khmer/Tibetan/Lao/Myanmar). \
               Traditionally written vertically; alphabetic. Adds \
               the Aramaic-descendant family to the pin set, \
               demonstrating no-script-fold holds across an \
               entirely new genealogical branch. Brings Unicode to \
               depth 20 alongside Adversarial, ChattyPrefix, \
               PureChatter, SignalOnly, Synthesis, Paraphrase — \
               every category now at depth 20.",
    },
    FVaultRecallRow {
        // 19th Unicode row (iter-191): Cherokee-script extension.
        // Adds a 17th non-Latin script (Cherokee, U+13A0–U+13FF).
        // Cherokee is a 19th-century syllabary invented by
        // Sequoyah — distinct from any prior script. Brings
        // syllabaries-with-syllabic-blocks count to 3 (Japanese-
        // katakana + Korean-Hangul + Cherokee). Latin "Mamba" +
        // Cherokee "Ꭽ" (ga, U+13BD) + Latin "cache".
        query: "Mamba Ꭽ cache",
        expected_paths: &["notes/mamba_cherokee.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Nineteenth Unicode row (iter-191): Cherokee-script \
               extension. SEVENTEEN non-Latin scripts pinned. \
               Cherokee is a 19th-century syllabary distinct \
               from any prior script (invented by Sequoyah). \
               Brings the syllabary count to 3 (Japanese-katakana \
               + Korean-Hangul + Cherokee), demonstrating the \
               no-script-fold contract holds across both ancient \
               and modern syllabaries.",
    },
    FVaultRecallRow {
        // 18th Unicode row (iter-179): Myanmar-script extension.
        // Adds a 16th non-Latin script (Myanmar/Burmese, U+1000–
        // U+109F). Sixth Brahmic abugida — Devanagari + Thai +
        // Khmer + Tibetan + Lao + Myanmar. Latin "Mamba" +
        // Myanmar "က" (ka, placeholder) + Latin "cache".
        query: "Mamba က cache",
        expected_paths: &["notes/mamba_myanmar.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Eighteenth Unicode row (iter-179): Myanmar-script \
               extension. SIXTEEN non-Latin scripts pinned. Sixth \
               Brahmic abugida — Myanmar joins Devanagari/Thai/ \
               Khmer/Tibetan/Lao. The Brahmic family alone now \
               covers six scripts, demonstrating the no-script-\
               fold contract holds across all major Brahmic \
               descendants regardless of consonant-cluster or \
               vowel-mark shaping conventions.",
    },
    FVaultRecallRow {
        // 17th Unicode row (iter-176): Lao-script extension. Adds
        // a 15th non-Latin script (Lao, U+0E80–U+0EFF). Lao is a
        // Brahmic-family abugida closely related to Thai but with
        // its own distinct script. Five Brahmic abugidas now:
        // Devanagari + Thai + Khmer + Tibetan + Lao. Latin
        // "Mamba" + Lao "ແຄ" (kae, placeholder) + Latin "cache".
        query: "Mamba ແຄ cache",
        expected_paths: &["notes/mamba_lao.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Seventeenth Unicode row (iter-176): Lao-script \
               extension. FIFTEEN non-Latin scripts pinned. Lao \
               is the fifth Brahmic-family abugida — sibling to \
               Thai but its own distinct script. Five Brahmic \
               scripts now (Devanagari + Thai + Khmer + Tibetan \
               + Lao) — covers the major South/Southeast/Inner-\
               Asian and Sino-Tibetan-area writing traditions.",
    },
    FVaultRecallRow {
        // 16th Unicode row (iter-167): Tibetan-script extension.
        // Adds a 14th non-Latin script (Tibetan, U+0F00–U+0FFF).
        // Tibetan is its own Brahmic-family abugida distinct from
        // Devanagari/Thai/Khmer — uses stacked consonants and
        // its own vowel-mark conventions. Latin "Mamba" +
        // Tibetan "ཀེ" (ke, placeholder; U+0F40 U+0F7A) + Latin
        // "cache".
        query: "Mamba ཀེ cache",
        expected_paths: &["notes/mamba_tibetan.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Sixteenth Unicode row (iter-167): Tibetan-script \
               extension. FOURTEEN non-Latin scripts pinned. \
               Four Brahmic-family abugidas now (Devanagari + \
               Thai + Khmer + Tibetan) — exercising the \
               consonant-cluster + vowel-mark complexity across \
               four distinct South/Southeast/Inner-Asian writing \
               traditions. The Brahmic family alone pins more \
               scripts than the originally-named multilingual \
               axis (CJK + Cyrillic + Arabic = 3 scripts).",
    },
    FVaultRecallRow {
        // 15th Unicode row (iter-158): Khmer-script extension.
        // Adds a 13th non-Latin script (Khmer, U+1780–U+17FF).
        // Khmer is another Brahmic-family abugida (like Devanagari
        // and Thai) but with its own complex consonant-cluster
        // shaping. Latin "Mamba" + Khmer "ខែ" (khae, abbreviated
        // placeholder) + Latin "cache". SimpleTokenizer keeps
        // the Khmer cluster as a single token.
        query: "Mamba ខែ cache",
        expected_paths: &["notes/mamba_khmer.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Fifteenth Unicode row (iter-158): Khmer-script \
               extension. THIRTEEN non-Latin scripts pinned. \
               Khmer is a Brahmic-family abugida alongside \
               Devanagari (iter-117) and Thai (iter-123) — three \
               Brahmic scripts now pinned, exercising the \
               consonant-cluster + vowel-mark complexity across \
               three distinct South/Southeast-Asian writing \
               systems. Seven orthographic family types now \
               represented.",
    },
    FVaultRecallRow {
        // 14th Unicode row (iter-153): Ethiopic-script extension.
        // Adds a 12th non-Latin script (Ethiopic / Ge'ez, U+1200–
        // U+137F). Ethiopic is an abugida — each glyph encodes
        // both consonant and vowel — structurally distinct from
        // every prior script family. Latin "Mamba" + Ethiopic
        // "ካሽ" (kash, "cache") + Latin "cache". Two Amharic/
        // Ethiopic syllabic glyphs.
        query: "Mamba ካሽ cache",
        expected_paths: &["notes/mamba_ethiopic.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Fourteenth Unicode row (iter-153): Ethiopic-script \
               extension. TWELVE non-Latin scripts pinned. \
               Ethiopic / Ge'ez is an abugida (consonant-and-vowel \
               glyphs) — structurally distinct from logographic \
               (CJK), pure syllabaries (Japanese-katakana), \
               featural-syllabic blocks (Korean Hangul), \
               alphabets (Latin/Greek/Cyrillic/Armenian/Georgian), \
               consonant-only abjads (Hebrew/Arabic), and the \
               Brahmic family (Devanagari/Thai) which clusters \
               vowel marks separately. Five orthographic family \
               types now pinned across 12 scripts.",
    },
    FVaultRecallRow {
        // 13th Unicode row (iter-141): Georgian-script extension.
        // Adds an 11th non-Latin script (Georgian, U+10A0–U+10FF).
        // Georgian Mkhedruli is its own LTR alphabet — distinct
        // from Armenian (neighboring linguistic area, different
        // script) and from European Cyrillic/Greek. Latin "Mamba"
        // + Georgian "ქეში" (k'eshi, "cache") + Latin "cache".
        // Tantivy treats the Georgian token as a single
        // whitespace-separated token.
        query: "Mamba ქეში cache",
        expected_paths: &["notes/mamba_georgian.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Thirteenth Unicode row (iter-141): Georgian-script \
               extension. ELEVEN non-Latin scripts pinned. \
               Georgian Mkhedruli is structurally distinct from \
               its Armenian neighbor (different script entirely) \
               and from the European Cyrillic/Greek alphabets. \
               Three Caucasus-area scripts pinned alongside the \
               other families (RTL × 2, East-Asian × 3, European \
               × 3, Brahmic × 2, Armenian, Georgian).",
    },
    FVaultRecallRow {
        // 12th Unicode row (iter-138): Armenian-script extension.
        // Adds a 10th non-Latin script (Armenian, U+0530–U+058F)
        // alongside CJK + Cyrillic + Arabic + Greek + Japanese-
        // katakana + Hebrew + Devanagari + Thai + Korean-Hangul.
        // Armenian is an Indo-European alphabet distinct from
        // Latin / Greek / Cyrillic — its own letter-block. Latin
        // "Mamba" + Armenian "կեշ" (kesh, "cache") + Latin
        // "cache". SimpleTokenizer treats the Armenian token as
        // a single token (Letter Unicode property).
        query: "Mamba կեշ cache",
        expected_paths: &["notes/mamba_armenian.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Twelfth Unicode row (iter-138): Armenian-script \
               extension. TEN non-Latin scripts pinned: CJK + \
               Cyrillic + Arabic + Greek + Japanese-katakana + \
               Hebrew + Devanagari + Thai + Korean-Hangul + \
               Armenian. Armenian is its own Indo-European \
               alphabet block — distinct from Greek (whose letters \
               are visually unrelated) and Cyrillic. Three \
               European-family scripts now pinned (Cyrillic + \
               Greek + Armenian) alongside the other family pairs \
               (RTL + East-Asian × 3 + Brahmic). No-script-fold \
               contract: iter-9 forbidden seed lacks Armenian \
               codepoint range, AND blocks it.",
    },
    FVaultRecallRow {
        // 11th Unicode row (iter-129): Korean Hangul extension.
        // Adds a 9th non-Latin script (Korean Hangul Syllables,
        // U+AC00–U+D7AF). Distinct from Han ideographs (CJK
        // iter-19, logographic) AND from katakana (iter-101,
        // syllabary): Hangul uses precomposed syllabic blocks
        // — a featural alphabet packed into syllables. Latin
        // "Mamba" + Hangul "캐시" (kaesi, "cache") + Latin
        // "cache". Tantivy's SimpleTokenizer treats the Hangul
        // syllabic block as a single token.
        query: "Mamba 캐시 cache",
        expected_paths: &["notes/mamba_korean.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Eleventh Unicode row (iter-129): Korean Hangul \
               extension. NINE non-Latin scripts pinned: CJK + \
               Cyrillic + Arabic + Greek + Japanese-katakana + \
               Hebrew + Devanagari + Thai + Korean-Hangul. Hangul \
               is structurally distinct from prior East-Asian \
               scripts: Han ideographs are logographic (single \
               concept per glyph); katakana is a purely phonetic \
               syllabary; Hangul uses precomposed syllabic blocks \
               (a featural alphabet packed into syllables). \
               Three East-Asian scripts now pinned with distinct \
               structural properties — proves the no-script-fold \
               contract holds across logographic, syllabic, AND \
               syllabic-block scripts.",
    },
    FVaultRecallRow {
        // 10th Unicode row (iter-123): Thai-script extension. Adds
        // an 8th non-Latin script (Thai, U+0E00–U+0E7F) alongside
        // CJK (iter-19), Cyrillic (iter-28), Arabic (iter-32),
        // Greek (iter-93), Japanese-katakana (iter-101), Hebrew
        // (iter-109), Devanagari (iter-117). Latin "Mamba" + Thai
        // "แคช" (kæch, "cache") + Latin "cache". Thai is a
        // Brahmic script (like Devanagari) but uses pre-, above-,
        // and below-base vowel marks; SimpleTokenizer keeps the
        // grapheme cluster as a single token.
        query: "Mamba แคช cache",
        expected_paths: &["notes/mamba_thai.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Tenth Unicode row (iter-123): Thai-script extension. \
               EIGHT non-Latin scripts pinned: CJK + Cyrillic + \
               Arabic + Greek + Japanese-katakana + Hebrew + \
               Devanagari + Thai. Thai uses a complex grapheme \
               cluster (consonant + vowel marks above/below/pre-\
               base); SimpleTokenizer keeps the cluster as a \
               single token. The iter-9 forbidden seed lacks the \
               Thai codepoint range — AND blocks it. Eight non-\
               Latin scripts span 4 family pairs: 2 RTL (Hebrew + \
               Arabic) + 2 East-Asian (CJK + Japanese-katakana) + \
               2 European non-Latin (Cyrillic + Greek) + 2 Brahmic \
               (Devanagari + Thai).",
    },
    FVaultRecallRow {
        // 9th Unicode row (iter-117): Devanagari-script extension.
        // Adds a 7th non-Latin script (Devanagari, U+0900–U+097F)
        // alongside CJK (iter-19), Cyrillic (iter-28), Arabic
        // (iter-32), Greek (iter-93), Japanese-katakana (iter-101),
        // Hebrew (iter-109). Latin "Mamba" + Devanagari "कैश"
        // (kaish, "cache" in Hindi) + Latin "cache". Devanagari
        // tokens use diacritic-vowel marks (matras); Tantivy's
        // SimpleTokenizer keeps the cluster as a single token.
        query: "Mamba कैश cache",
        expected_paths: &["notes/mamba_devanagari.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::Unicode,
        top_n: 5,
        note: "Ninth Unicode row (iter-117): Devanagari-script \
               extension. SEVEN non-Latin scripts pinned now: CJK \
               (iter-19), Cyrillic (iter-28), Arabic (iter-32), \
               Greek (iter-93), Japanese-katakana (iter-101), \
               Hebrew (iter-109), Devanagari (iter-117). The \
               Devanagari token कैश (kaish) uses vowel-mark \
               diacritics (matras); SimpleTokenizer keeps the \
               cluster as a single token. The iter-9 forbidden \
               seed lacks the Devanagari codepoint range, AND \
               blocks it. Three RTL-or-complex scripts now \
               (Hebrew + Arabic + Devanagari) — Devanagari is \
               LTR but vowel-mark-clustered, distinct from \
               isolated-letter Hebrew or Arabic-cursive shapes.",
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
        // 27th PureChatter row (iter-248): 4-token noun+article
        // shape — "the notes my files". Articles + possessive +
        // chatter-nouns (notes / files), no verb / modal / wh-
        // word. Extends the small-input cardinality progression
        // to the 4-token boundary: iter-114 (1-token) + iter-170
        // (2-token) + iter-241 (3-token) + iter-248 (4-token) =
        // four-step progression past the 1-token edge.
        query: "the notes my files",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Twenty-seventh PureChatter row (iter-248): 4-\
               token noun+article shape (\"the notes my files\"). \
               Articles + possessive + chatter-nouns, no verb / \
               modal / wh-word. Extends the cardinality progression \
               to 4-token: iter-114 (1) + iter-170 (2) + iter-241 \
               (3) + iter-248 (4). Four-step progression past \
               the 1-token edge proves all_chatter_fallback fires \
               consistently at every small-input cardinality. \
               All 4 tokens in QUERY_CHATTER_WORDS. Brings \
               PureChatter to depth 27.",
    },
    FVaultRecallRow {
        // 26th PureChatter row (iter-241): 3-token degenerate
        // shape — "show me notes". Closes the small-input
        // cardinality boundary trio: iter-114 1-token ("files"),
        // iter-170 2-token ("the notes"), iter-241 3-token
        // ("show me notes"). All three small-input shapes now
        // pin all_chatter_fallback at the 1/2/3-token boundaries,
        // proving the fallback fires regardless of token count
        // when every token is chatter.
        query: "show me notes",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Twenty-sixth PureChatter row (iter-241): 3-token \
               degenerate shape (\"show me notes\"). Closes the \
               small-input cardinality trio: iter-114 1-token + \
               iter-170 2-token + iter-241 3-token. Three small-\
               input shapes now pin all_chatter_fallback at the \
               1/2/3-token boundaries — proves fallback fires \
               regardless of token count when every token is \
               chatter. All 3 tokens in QUERY_CHATTER_WORDS. \
               Brings PureChatter to depth 26.",
    },
    FVaultRecallRow {
        // 25th PureChatter row (iter-234): mixed-closed-class
        // cluster shape — "the i and please" stacks four tokens
        // from FOUR distinct grammatical sub-classes (determiner
        // + pronoun + conjunction + politeness marker). Counter-
        // point to iter-197/205/212/219/226 PURE-vocabulary
        // clusters which each used a single sub-class — iter-234
        // pins the inverse: that all_chatter_fallback fires when
        // chatter tokens cross sub-classes without forming a
        // sentence frame. Proves the fallback is keyed to the
        // chatter set membership, NOT to within-sub-class
        // grouping.
        query: "the i and please",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Twenty-fifth PureChatter row (iter-234): mixed-\
               closed-class cluster shape (\"the i and please\"). \
               Four tokens from FOUR distinct grammatical sub-\
               classes (determiner + pronoun + conjunction + \
               politeness). Counterpoint to iter-197/205/212/\
               219/226 single-sub-class clusters. Proves \
               all_chatter_fallback is keyed to chatter-set \
               membership, not to within-sub-class grouping. \
               Brings PureChatter to depth 25. All 4 tokens in \
               QUERY_CHATTER_WORDS.",
    },
    FVaultRecallRow {
        // 24th PureChatter row (iter-226): pure-modal-cluster
        // shape — "can could would should" stacks the four
        // canonical English modal verbs with no other token type.
        // Closes the modal-vocabulary axis alongside iter-197 wh-
        // cluster, iter-205 pronoun-cluster, iter-212 preposition-
        // cluster, iter-219 be-verb-cluster. FIVE pure-vocabulary-
        // cluster shapes now (wh + pronoun + preposition + be-verb
        // + modal). Distinct from iter-152 (stacked-modal mixed
        // with imperatives + pronouns) — iter-226 strips the rest
        // of the sentence away.
        query: "can could would should",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Twenty-fourth PureChatter row (iter-226): pure-\
               modal-cluster shape (\"can could would should\"). \
               Four canonical English modals stacked. Closes the \
               modal-vocabulary axis — FIVE pure-vocabulary-\
               cluster shapes (wh / pronoun / preposition / be-\
               verb / modal). Distinct from iter-152 (stacked-\
               modal + other tokens) — iter-226 isolates modals \
               only. Brings PureChatter to depth 24 — sixth \
               category past depth-23 horizon. All 4 tokens in \
               QUERY_CHATTER_WORDS.",
    },
    FVaultRecallRow {
        // 23rd PureChatter row (iter-219): pure-be-verb-cluster
        // shape — "is are was were" stacks the four tense/number
        // forms of "to be" with no other token type. Closes the
        // be-verb-vocabulary axis alongside iter-197 (wh-cluster),
        // iter-205 (pronoun-cluster), iter-212 (preposition-
        // cluster). Four pure-vocabulary-cluster shapes now —
        // wh + pronoun + preposition + be-verb — demonstrating
        // all_chatter_fallback fires on any QUERY_CHATTER_WORDS
        // grammatical class in isolation. Distinct from iter-107
        // BE-declarative which embedded a be-verb in a sentence
        // shape: iter-219 strips the sentence away.
        query: "is are was were",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Twenty-third PureChatter row (iter-219): pure-be-\
               verb-cluster shape (\"is are was were\"). Four \
               forms of \"to be\" stacked. Closes the be-verb \
               vocabulary axis — four pure-vocabulary-cluster \
               shapes now (wh / pronoun / preposition / be-verb). \
               Distinct from iter-107 BE-declarative (embedded \
               be-verb in sentence shape). Brings PureChatter to \
               depth 23 — fifth category past depth-22 horizon. \
               All 4 tokens in QUERY_CHATTER_WORDS.",
    },
    FVaultRecallRow {
        // 22nd PureChatter row (iter-212): pure-preposition-
        // cluster shape — "in on to for" stacks four prepositions
        // with no verb / pronoun / quantifier / modal / wh-word /
        // imperative. Closes the preposition-vocabulary axis
        // alongside iter-197 (wh-cluster) and iter-205 (pronoun-
        // cluster). Three pure-vocabulary-cluster shapes now —
        // wh + pronoun + preposition — demonstrating
        // all_chatter_fallback fires on any vocabulary stratum
        // sourced exclusively from QUERY_CHATTER_WORDS. All 4
        // tokens (in / on / to / for) are canonical chatter.
        query: "in on to for",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Twenty-second PureChatter row (iter-212): pure-\
               preposition-cluster shape (\"in on to for\"). Four \
               prepositions, no verb/pronoun/quantifier/modal/wh-\
               word/imperative. Closes the preposition-vocabulary \
               axis alongside iter-197 (wh-cluster) and iter-205 \
               (pronoun-cluster) — three pure-vocabulary-cluster \
               shapes demonstrate the fallback fires on any \
               stratum sourced exclusively from QUERY_CHATTER_\
               WORDS. Brings PureChatter to depth 22 — sixth \
               category past depth-21 horizon. All 4 tokens in \
               QUERY_CHATTER_WORDS.",
    },
    FVaultRecallRow {
        // 21st PureChatter row (iter-205): pure-pronoun-cluster
        // shape — "us our you your" stacks four pronouns with no
        // verb / quantifier / modal / wh-word / imperative /
        // possessive-object. Distinct from every prior shape
        // including iter-94 pronoun-led (pronoun + quantifier
        // inside) and iter-132 possessive-led (possessive +
        // object-noun). Closes the pronoun-vocabulary axis of the
        // all_chatter_fallback shape lattice (parallel to iter-197's
        // wh-cluster axis closure). All 4 tokens (us / our / you /
        // your) in QUERY_CHATTER_WORDS.
        query: "us our you your",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Twenty-first PureChatter row (iter-205): pure-\
               pronoun-cluster shape (\"us our you your\"). Four \
               pronouns stacked, no verb/quantifier/modal/wh-\
               word/imperative/possessive-object. Distinct from \
               iter-94 (pronoun + quantifier inside) and iter-132 \
               (possessive + object). Closes the pronoun-\
               vocabulary axis of the all_chatter_fallback shape \
               lattice — parallels iter-197's wh-cluster closure. \
               Brings PureChatter to depth 21 — sixth category \
               past the depth-20 horizon. All 4 tokens in \
               QUERY_CHATTER_WORDS.",
    },
    FVaultRecallRow {
        // 20th PureChatter row (iter-197): pure-wh-cluster shape
        // — "what where when how" leads with four interrogative
        // wh-words concatenated, no verb / pronoun / quantifier /
        // imperative / possessive. Distinct from every prior
        // PureChatter shape (imperative+object, pronoun-led,
        // quantifier-led, possessive-led, stacked-imperative,
        // 2-token degenerate, 1-token degenerate, tail-modal).
        // All 4 tokens in QUERY_CHATTER_WORDS (what/where/when/
        // how/why/which all canonical chatter). Proves
        // all_chatter_fallback fires on a wh-only sequence too —
        // closes the interrogative-vocabulary axis of the chatter
        // shape lattice.
        query: "what where when how",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Twentieth PureChatter row (iter-197): pure-wh-\
               cluster shape (\"what where when how\"). Four \
               interrogative wh-words, no verb/pronoun/quantifier/ \
               imperative/possessive. Distinct from every prior \
               PureChatter shape — closes the interrogative-\
               vocabulary axis of the all_chatter_fallback shape \
               lattice. Brings PureChatter to depth 20 alongside \
               Adversarial, ChattyPrefix, SignalOnly, Synthesis, \
               Paraphrase. All 4 tokens in QUERY_CHATTER_WORDS.",
    },
    FVaultRecallRow {
        // 19th PureChatter row (iter-190): bare-quantifier-led
        // shape — "any of my notes" leads with quantifier "any"
        // (no verb, no pronoun, no modal). Distinct from iter-49
        // imperative-led-with-quantifier and iter-94 subject-
        // pronoun-led-with-quantifier and iter-132 possessive-led.
        // All 4 tokens in QUERY_CHATTER_WORDS.
        query: "any of my notes",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Nineteenth PureChatter row (iter-190): bare-\
               quantifier-led shape (\"any of my notes\"). \
               Quantifier \"any\" leads, no verb/pronoun/modal. \
               Distinct from iter-49 (imperative + quantifier \
               inside) and iter-94 (pronoun + quantifier inside) \
               and iter-132 (possessive). All 4 tokens in \
               QUERY_CHATTER_WORDS.",
    },
    FVaultRecallRow {
        // 18th PureChatter row (iter-183): stacked-imperatives
        // shape — 4 imperative verbs concatenated with no
        // objects, modifiers, or pronouns. Distinct from prior
        // imperative-led shapes (iter-16/30/49) which had
        // imperative + direct-object structure. Tests
        // all_chatter_fallback on a verb-only sequence.
        query: "find show tell give",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Eighteenth PureChatter row (iter-183): stacked-\
               imperatives shape (\"find show tell give\"). Four \
               imperative verbs with no objects, modifiers, or \
               pronouns. Distinct from iter-16/30/49 (imperative \
               + object structure) — iter-183 is verb-only. \
               Proves all_chatter_fallback fires on pure-verb \
               sequences too. All 4 tokens in QUERY_CHATTER_\
               WORDS.",
    },
    FVaultRecallRow {
        // 17th PureChatter row (iter-170): 2-token degenerate
        // shape — "the notes". The smallest multi-token chatter
        // query. Sits between iter-114's single-token degenerate
        // ("files") and the larger 3-8 token shapes. Both tokens
        // (the + notes) in QUERY_CHATTER_WORDS.
        query: "the notes",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Seventeenth PureChatter row (iter-170): 2-token \
               degenerate shape (\"the notes\"). Sits between \
               iter-114's 1-token degenerate (\"files\") and the \
               larger 3-8 token shapes. Pins the all_chatter_\
               fallback at the 2-token input boundary, \
               completing the small-input cardinality coverage \
               (1 + 2 + 3-8 tokens). Zero new seeds.",
    },
    FVaultRecallRow {
        // 16th PureChatter row (iter-162): imperative + TAIL tag-
        // question shape ("find me notes please can you"). The
        // modal appears at the TAIL of the query, not the lead
        // (distinct from iter-83 modal-lead and iter-99 wh+modal
        // lead). Tests the all_chatter_fallback when the modal
        // verb appears in an unexpected position relative to
        // prior shapes. All 6 tokens in QUERY_CHATTER_WORDS.
        query: "find me notes please can you",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Sixteenth PureChatter row (iter-162): imperative + \
               tail tag-question. Modal verb (can) appears at \
               the END of the query, after the imperative body — \
               distinct from iter-83 modal-lead and iter-99 \
               wh+modal-lead. Proves the fallback detector is \
               position-independent w.r.t. specific token classes \
               (a modal can be anywhere in the chatter sequence). \
               All 6 tokens in QUERY_CHATTER_WORDS.",
    },
    FVaultRecallRow {
        // 15th PureChatter row (iter-159): wh-led + imperative-verb
        // shape ("why find some notes"). Distinct from iter-73
        // (wh + BE-verb: "where are the files") and iter-99
        // (compound wh+modal: "where could you"). This row pairs
        // a wh-word with an imperative verb directly (no BE,
        // no modal between them). All 4 tokens in
        // QUERY_CHATTER_WORDS (why + find + some + notes).
        query: "why find some notes",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Fifteenth PureChatter row (iter-159): wh + \
               imperative-verb shape (\"why find some notes\"). \
               Distinct from iter-73 (wh + BE: \"where are\") \
               and iter-99 (compound wh+modal: \"where could \
               you\") — this row pairs wh-word with imperative \
               verb directly. Fifteen distinct structural shapes \
               for the all_chatter_fallback detector.",
    },
    FVaultRecallRow {
        // 14th PureChatter row (iter-152): stacked-modal shape —
        // "could should i find notes" leads with TWO modals
        // stacked (could + should). Distinct from iter-83 (single
        // modal "could") and iter-99 (compound wh+modal). Tests
        // that the all_chatter_fallback fires when multiple
        // modal verbs accumulate at the lead. All 5 tokens in
        // QUERY_CHATTER_WORDS.
        query: "could should i find notes",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Fourteenth PureChatter row (iter-152): stacked-\
               modal shape (\"could should i find notes\"). Two \
               modals stacked at lead position. Distinct from \
               iter-83 (single modal: \"could you\") and iter-99 \
               (compound wh+modal: \"where could\"). Proves the \
               all_chatter_fallback fires when multiple modals \
               accumulate, not just when a single modal leads. \
               All 5 tokens in QUERY_CHATTER_WORDS.",
    },
    FVaultRecallRow {
        // 13th PureChatter row (iter-145): infinitive-led shape —
        // "to find some notes" leads with a bare infinitive
        // marker. Distinct from the 12 prior shapes: no
        // imperative (no finite verb at lead), no wh, no modal,
        // no pronoun, no BE-verb, no possessive, no chain, no
        // single-token, no disjunction. All 4 tokens in
        // QUERY_CHATTER_WORDS (to + find + some + notes).
        query: "to find some notes",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Thirteenth PureChatter row (iter-145): infinitive-\
               led shape (\"to find some notes\"). Bare \
               infinitive marker leads instead of a finite verb. \
               Distinct grammatical class from imperative \
               (iter-16/30/49), modal (iter-83), need-led \
               (iter-94), and possessive-led (iter-132) — those \
               start with verb-forms or pronouns. All 4 tokens \
               in QUERY_CHATTER_WORDS.",
    },
    FVaultRecallRow {
        // 12th PureChatter row (iter-136): disjunction-only shape
        // — "files or notes" uses OR-connective between generic
        // referents. Distinct from all 11 prior PureChatter
        // shapes: no imperative, no wh, no modal, no pronoun, no
        // BE-verb, no compound, no possessive, no chain. Pure
        // disjunction structure. All 3 tokens in
        // QUERY_CHATTER_WORDS (files + or + notes).
        query: "files or notes",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Twelfth PureChatter row (iter-136): disjunction-\
               only shape (\"files or notes\"). All 3 tokens in \
               QUERY_CHATTER_WORDS. Distinct grammatical class \
               from every prior shape: pure OR-connective \
               between generic referents, no imperative/wh/modal/\
               pronoun/BE/possessive/chain/single-token. \
               Demonstrates the all_chatter_fallback fires \
               regardless of whether the chatter tokens form a \
               coherent retrieval-intent expression OR a pure \
               logical-connective.",
    },
    FVaultRecallRow {
        // 11th PureChatter row (iter-132): POSSESSIVE-led shape —
        // distinct from iter-94's SUBJECT-PRONOUN-led ("i need...").
        // Both use first-person but different grammatical forms:
        // iter-94 leads with subject-pronoun "i"; iter-132 leads
        // with possessive "my". Tests that the fallback fires on
        // possessive-noun-phrase shapes too. Zero new seeds.
        query: "my notes about files",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Eleventh PureChatter row (iter-132): possessive-led \
               shape (\"my notes about files\") — distinct from \
               iter-94's subject-pronoun-led (\"i need some of my \
               notes\"). Both use first-person but iter-94 leads \
               with subject pronoun + need-verb, while iter-132 \
               leads with possessive determiner + noun. Together \
               with the 10 prior shapes, PureChatter now spans \
               imperative × 3 + wh + modal + subject-pronoun + \
               compound + BE-declarative + single-token + \
               generic-referent-chain + possessive — 11 \
               structurally distinct lead patterns.",
    },
    FVaultRecallRow {
        // 10th PureChatter row (iter-121): generic-referent chain
        // shape — 4 noun tokens, no verb/modal/wh/pronoun
        // structure. Distinct from every prior PureChatter shape
        // (imperative × 3 + wh + modal + need + compound + BE-
        // declarative + single-token). Proves the all_chatter_
        // fallback also fires on grammar-free noun sequences,
        // not just on structured retrieval-intent shapes.
        query: "files notes things stuff",
        expected_paths: &[],
        forbidden_paths: &[
            "notes/totally_unrelated_a.md",
            "notes/totally_unrelated_b.md",
        ],
        category: FVaultRecallCategory::PureChatter,
        top_n: 7,
        note: "Tenth PureChatter row (iter-121): generic-referent \
               chain — 4 generic-referent tokens {files, notes, \
               things, stuff} with no syntactic structure. \
               Distinct from imperative + wh + modal + need + \
               compound + BE-declarative + single-token shapes \
               (iters 16/30/49/73/83/94/99/107/114). Proves the \
               all_chatter_fallback fires on any all-chatter \
               sequence, including grammar-free noun chains.",
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
        // 11th ChattyPrefix row (iter-127): 2-term-AND boundary
        // case in agent-runtime domain. After strip only {agent,
        // runtime} survive — 2 terms still trigger AND-conjunction
        // (≤3). Distinct from iter-71/113's 3-term-AND in the same
        // domain. Tests the strip-robust contract at the smallest
        // multi-term survivor cardinality (2). Reuses iter-43
        // corpus; zero new seeds.
        query: "give me my agent runtime notes please",
        expected_paths: &["notes/agent_runtime_v2_substrate.md"],
        forbidden_paths: &[
            "notes/agent_brainstorm.md",
            "notes/runtime_old_design.md",
            "notes/substrate_concepts.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Eleventh ChattyPrefix row (iter-127): 2-term-AND \
               boundary in agent-runtime domain. iter-71 used \
               3-term-AND {agent, runtime, trace}; iter-113 used \
               3-term-AND {agent, runtime, substrate}; iter-127 \
               uses 2-term-AND {agent, runtime}. Proves strip-\
               robust survives at the smallest meaningful \
               survivor cardinality (2 terms, AND boundary). \
               iter-43 + iter-75 both match (both have agent + \
               runtime); single-term iter-43 decoys are blocked. \
               Zero new seeds.",
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
        // 16th Paraphrase row (iter-166): NEW axis — WORD-
        // SPLITTING (within-word spacing). User typed "Mam ba
        // SSM" splitting "Mamba" into two tokens. Tantivy
        // tokenizes to [mam, ba, ssm] — 3 surviving tokens
        // triggers AND-conjunction; canonical has [mamba, ssm,
        // cache] with no "mam" or "ba" tokens → AND blocks.
        // Distinct from iter-140 concatenation (whitespace
        // DELETION): this is whitespace INSERTION — opposite
        // direction on the tokenization-boundary axis. Query
        // kept at 3 tokens to stay in the AND-conjunction path
        // (>3 would route to OR and the canonical would rank).
        query: "Mam ba SSM",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Word-splitting Paraphrase axis (axis #15): user \
               typed \"Mam ba\" splitting \"Mamba\" with \
               internal whitespace. Three surviving tokens \
               {mam, ba, ssm} trigger AND-conjunction; canonical \
               has the joined \"mamba\" not \"mam\"+\"ba\" so \
               AND blocks. Distinct from iter-140 concatenation \
               (whitespace DELETION): iter-166 is whitespace \
               INSERTION — opposite direction on the \
               tokenization-boundary axis. Together iter-140 + \
               iter-166 pin both extremes of the whitespace-\
               boundary error class.",
    },
    FVaultRecallRow {
        // 27th Paraphrase row (iter-245): NEW axis — LEET /
        // NUMERIC-DIGIT SUBSTITUTION. User types "M4mba" with
        // digit "4" replacing letter "a" (leet-speak / 1337
        // convention). Tantivy SimpleTokenizer treats consecutive
        // alphanumerics as one token: "M4mba" → "m4mba" (single
        // token). 3-term AND on {m4mba, ssm, cache} blocks the
        // canonical (which has "mamba" not "m4mba"). Distinct
        // from iter-10 SSL alphabetic-substitution (letter→
        // letter typo, not letter→digit leet), iter-147
        // version-attached (digit appended at tail), iter-155
        // numeric-prefix-concat (digit at lead), and all
        // Damerau-Levenshtein subclasses. Twenty-fourth named
        // failure subclass; pins deferred alphanumeric-confusion
        // normalization work.
        query: "M4mba SSM cache",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Leet-substitution Paraphrase axis (axis #24): \
               user replaces letter \"a\" with digit \"4\" mid-\
               token (\"M4mba\"). Tantivy treats alphanumerics \
               as one token → \"m4mba\". 3-term AND on {m4mba, \
               ssm, cache} blocks the canonical. Distinct from \
               iter-10 alphabetic SSL-typo, iter-147 version-\
               suffix (digit-attached at tail), iter-155 \
               numeric-prefix (digit at lead), and 4 Damerau-\
               Levenshtein subclasses (alphabetic-only edits). \
               Twenty-fourth named failure subclass; pins \
               deferred alphanumeric-confusion / homoglyph-style \
               normalization. Brings Paraphrase to depth 27.",
    },
    FVaultRecallRow {
        // 26th Paraphrase row (iter-239): NEW axis — WORD
        // TRUNCATION / SUFFIX DROP. User shortens "cache" → "ch"
        // — a partial-word contraction (different from iter-86
        // acronym which collapsed multi-word "machine learning"
        // → "ml"). 3-term AND on {mamba, ssm, ch} blocks the
        // canonical (which has "cache" not "ch"). Distinct from
        // every prior axis: not an edit-distance error (deliberate
        // truncation, not typo), not an acronym (single-word
        // truncation, not multi-word collapse), not a synonym
        // (same word shortened, not different word). Twenty-
        // third named failure subclass; pins deferred prefix-
        // match / autocomplete-style retrieval work.
        query: "Mamba SSM ch",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Word-truncation Paraphrase axis (axis #23): user \
               shortens \"cache\" → \"ch\". 3-term AND on \
               {mamba, ssm, ch} blocks the canonical. Distinct \
               from iter-86 acronym (multi-word collapse, not \
               single-word truncation), all 4 typo subclasses \
               (deliberate contraction, not edit-distance \
               mistake), and synonym (same word shortened, not \
               different word). Twenty-third named failure \
               subclass; pins deferred prefix-match / \
               autocomplete retrieval. Brings Paraphrase to \
               depth 26.",
    },
    FVaultRecallRow {
        // 25th Paraphrase row (iter-232): NEW axis — ROMANIZATION
        // / TRANSLITERATION. User types the romanized form of a
        // non-Latin word — "kesh" (transliteration of Cyrillic
        // "кэш" / Arabic "كاش" / etc., all meaning cache). The
        // canonical body has Latin "cache" but no "kesh" token.
        // 3-term AND on {mamba, ssm, kesh} blocks the canonical.
        // Distinct from iter-86 abbreviation (acronym "ml" vs
        // "machine learning" within same language), iter-106
        // synonym (English-to-English "store" vs "cache"), and
        // every typo subclass (not a single-edit mistake — an
        // intentional cross-language romanization). Twenty-second
        // named failure subclass; pins deferred romanization /
        // transliteration normalization work.
        query: "Mamba SSM kesh",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Romanization Paraphrase axis (axis #22): user \
               types romanized form of a non-Latin equivalent — \
               \"kesh\" for Cyrillic кэш / Arabic كاش (cache). \
               Canonical has Latin \"cache\", not \"kesh\". \
               3-term AND on {mamba, ssm, kesh} blocks. Distinct \
               from synonym (cross-language, not English-to-\
               English), abbreviation (cross-language, not \
               acronym), and typo (intentional romanization, not \
               edit-distance mistake). Twenty-second named \
               failure subclass; pins deferred romanization / \
               transliteration normalization work. Brings \
               Paraphrase to depth 25.",
    },
    FVaultRecallRow {
        // 24th Paraphrase row (iter-224): NEW axis — TAIL-NOISE
        // (separate noise word at TAIL position). User typed
        // "Mamba SSM extra" — "extra" is a separate word not in
        // QUERY_CHATTER_WORDS, not in the canonical doc, and
        // attached at the suffix (TAIL) position. 3-term AND on
        // {mamba, ssm, extra} blocks the canonical. Closes the
        // position-symmetric trio of separate-noise axes:
        // PREFIX (iter-174 "Prof Mamba SSM"), INTERIOR (iter-178
        // "Mamba new SSM"), TAIL (iter-224 "Mamba SSM extra").
        // Distinct from concatenation axes (iter-147 / 155 / 216 /
        // 140) which fuse tokens — iter-224 keeps tokens
        // separate, just adds an extraneous one at tail.
        query: "Mamba SSM extra",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Tail-noise Paraphrase axis (axis #21): user \
               appends an unrelated word (\"extra\") at TAIL \
               position. Not in QUERY_CHATTER_WORDS so it \
               survives strip. 3-term AND on {mamba, ssm, \
               extra} blocks the canonical. Closes the position-\
               symmetric trio: prefix-noise (iter-174 LEAD) + \
               interior-noise (iter-178 MIDDLE) + tail-noise \
               (iter-224 TAIL). Twenty-first named failure \
               subclass. Brings Paraphrase to depth 24.",
    },
    FVaultRecallRow {
        // 23rd Paraphrase row (iter-216): NEW axis — PARTIAL
        // CONCATENATION (camelCase identifier style). User typed
        // "MambaSSM cache" — two of three tokens fused into a
        // camelCase identifier. Tantivy's SimpleTokenizer splits
        // on non-alphanumeric, NOT on case-change, so "MambaSSM"
        // becomes a single token "mambassm". Query tokenizes to
        // {mambassm, cache} — 2-term AND. Canonical has mamba +
        // ssm + cache separately, NOT "mambassm" → blocked.
        // Distinct from iter-140 FULL concatenation
        // ("MambaSSMcache" → 1-term AND on {mambassmcache}): the
        // partial form leaves a residual second token that still
        // matches the canonical, but AND still blocks because the
        // first token fails. Twentieth named failure subclass —
        // axis-of-degree (partial vs full fusion) distinct from
        // axis-of-kind. Pins deferred camelCase tokenization /
        // identifier-aware splitting work.
        query: "MambaSSM cache",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Partial-concatenation Paraphrase axis (axis #20): \
               user typed camelCase identifier \"MambaSSM\" + \
               separate token \"cache\". Tantivy SimpleTokenizer \
               does NOT split on case-change — \"MambaSSM\" \
               becomes single token \"mambassm\". 2-term AND on \
               {mambassm, cache} blocks the canonical (which has \
               mamba+ssm+cache as 3 separate tokens, no \
               \"mambassm\"). Distinct from iter-140 FULL \
               concatenation (1-term AND on {mambassmcache}) — \
               this partial form leaves a residual matching \
               token, but AND-on-2 still blocks. Twentieth named \
               failure subclass; axis-of-degree (partial vs full \
               fusion) distinct from axis-of-kind. Pins deferred \
               camelCase / identifier-aware tokenization. Brings \
               Paraphrase to depth 23.",
    },
    FVaultRecallRow {
        // 22nd Paraphrase row (iter-209): NEW axis — POSSESSIVE-S.
        // User typed "Mamba's SSM" — the apostrophe-s. Tantivy's
        // SimpleTokenizer splits on non-alphanumeric so the
        // query tokenizes to {mamba, s, ssm} (3 surviving terms
        // → AND-conjunction). The canonical body has no "s" as a
        // standalone token, so AND blocks it. Distinct from
        // plural/morphology (iter-201 "caches" — different
        // morphological feature: number vs possession),
        // version-suffix (iter-147 "Mamba2" — concatenated
        // digit), and every prior axis. Pins Fix-D deferred
        // possessive / apostrophe-handling work.
        query: "Mamba's SSM",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Possessive-S Paraphrase axis (axis #19): user \
               typed apostrophe-s (\"Mamba's\"). Tantivy's \
               SimpleTokenizer splits on non-alphanumeric — the \
               query tokenizes to {mamba, s, ssm}, 3-term AND-\
               conjunction. The canonical body has no standalone \
               \"s\" token. AND blocks the canonical. Distinct \
               from iter-201 plural/morphology (number-marker), \
               iter-147 version-suffix (concatenated digit), and \
               every prior axis. Nineteenth named failure \
               subclass. Pins deferred possessive / apostrophe-\
               handling as a future Fix path. Brings Paraphrase \
               to depth 22.",
    },
    FVaultRecallRow {
        // 21st Paraphrase row (iter-201): NEW axis — PLURAL /
        // MORPHOLOGY. User typed "caches" but the canonical body
        // has only "cache". SimpleTokenizer does NOT stem so the
        // tokens are distinct (caches ≠ cache). 3-term AND on
        // {mamba, ssm, caches} blocks the canonical — failure
        // subclass distinct from typo-substitution (single char
        // edit), version-suffix (Mamba2 attached digit), and the
        // 19 prior axes. Pins Fix-D deferred stemming/morphology
        // work. Brings Paraphrase to depth 21.
        query: "Mamba SSM caches",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Plural/morphology Paraphrase axis (axis #18): user \
               typed plural form \"caches\" but canonical body \
               has only singular \"cache\". SimpleTokenizer does \
               NOT stem; tokens stay distinct. 3-term AND on \
               {mamba, ssm, caches} blocks the canonical. \
               Distinct from typo-substitution (single-char \
               edit), version-suffix (digit attached), interior-\
               noise (separate noise word), and every prior \
               Paraphrase axis. Eighteenth named failure \
               subclass; pins deferred stemmer / morphology \
               expansion as a future Fix path. Brings Paraphrase \
               to depth 21. Zero new seeds.",
    },
    FVaultRecallRow {
        // 20th Paraphrase row (iter-193): 2nd interior-noise row,
        // vault-canon domain. iter-178 used "Mamba new SSM";
        // iter-193 uses "vault new index". Same axis (mid-
        // sentence noise word "new"), different domain. Extends
        // interior-noise pin from 1 to 2 domains.
        query: "vault new index",
        expected_paths: &["notes/vault_index_reload_canon.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Second interior-noise Paraphrase row (iter-193): \
               extends iter-178's mid-sentence-noise axis from \
               Mamba SSM to vault-canon domain. Same noise word \
               (\"new\") in the same position class (between \
               signal tokens), different signal corpus. Two \
               rows now prove the axis spans multiple domains. \
               Zero new seeds.",
    },
    FVaultRecallRow {
        // 18th Paraphrase row (iter-178): NEW axis — INTERIOR
        // NOISE WORD (extra unrelated token between signal
        // tokens). User typed "Mamba new SSM" — "new" is an
        // extra word not in QUERY_CHATTER_WORDS, not in the
        // canonical doc, and not at the prefix/suffix position.
        // 3-term AND on {mamba, new, ssm} blocks the canonical.
        // Distinct from iter-174 prefix-noise (Prof at LEAD),
        // iter-147 version-suffix (Mamba2 at TAIL), iter-155
        // numeric-prefix (1mamba CONCAT).
        query: "Mamba new SSM",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Interior-noise Paraphrase axis (axis #17): user \
               inserts an unrelated word (\"new\") BETWEEN signal \
               tokens. Not in QUERY_CHATTER_WORDS so it \
               survives strip. 3-term AND on {mamba, new, ssm} \
               blocks the canonical. Distinct from prefix-noise \
               (iter-174 \"Prof Mamba SSM\" — LEAD position), \
               suffix-numeric (iter-147 \"Mamba2\" — TAIL \
               attached), and prefix-concat (iter-155 \"1mamba\" \
               — concatenated): iter-178 is mid-sentence noise. \
               Seventeenth Paraphrase failure subclass.",
    },
    FVaultRecallRow {
        // 17th Paraphrase row (iter-174): NEW axis — TITLE-
        // PREFIX (separate noise token). User added "Prof" (a
        // title/honorific not in the chatter strip list) as a
        // separate prefix token. 3-term AND on {prof, mamba,
        // ssm} blocks the canonical (no "prof" token). Distinct
        // from iter-155 numeric-prefix-concat (1mamba): this is
        // a SEPARATE word prefix, not concatenated to the
        // identifier.
        query: "Prof Mamba SSM",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Title-prefix Paraphrase axis (axis #16): user \
               added \"Prof\" (a honorific/title) as a separate \
               prefix token. Not in QUERY_CHATTER_WORDS so it \
               survives strip. 3-term AND on {prof, mamba, ssm} \
               blocks the canonical. Distinct from iter-155 \
               numeric-prefix-CONCAT (1mamba is one token) and \
               iter-147 version-SUFFIX (Mamba2): this is a \
               SEPARATE WORD prefix. Sixteenth Paraphrase \
               failure subclass. Zero new seeds.",
    },
    FVaultRecallRow {
        // 15th Paraphrase row (iter-155): NEW axis — NUMERIC-
        // PREFIX adjacent to identifier. User typed "1mamba"
        // (perhaps a numbered list-item that the keyboard
        // auto-concatenated). SimpleTokenizer's alphanumeric-
        // contiguous tokenization keeps "1mamba" as a single
        // token distinct from "mamba". AND blocks the canonical.
        // Distinct from iter-147 version-number-SUFFIX axis
        // (Mamba2): this is a PREFIX number.
        query: "1mamba SSM cache",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Numeric-prefix Paraphrase axis (axis #14): user \
               typed \"1mamba\" (numeric prefix concatenated to \
               identifier, e.g. from a numbered list-item or \
               typo). SimpleTokenizer's alphanumeric-contiguous \
               tokenization keeps the digit-prefixed token \
               distinct from the canonical \"mamba\". AND blocks. \
               Distinct from iter-147 version-number-SUFFIX \
               (Mamba2): suffix and prefix are different \
               concatenation positions. Fourteenth Paraphrase \
               failure subclass.",
    },
    FVaultRecallRow {
        // 14th Paraphrase row (iter-147): NEW axis — VERSION-
        // NUMBER ADJACENT TO IDENTIFIER. User typed "Mamba2"
        // (referring to the Mamba-2 model variant) instead of
        // "Mamba". Tantivy's SimpleTokenizer keeps alphanumeric
        // sequences as single tokens, so "Mamba2" tokenizes as
        // "mamba2" — distinct from "mamba". AND-conjunction on
        // {mamba2, ssm, cache} blocks the iter-2 canonical
        // (which has "mamba" only).
        query: "Mamba2 SSM cache",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Version-number-adjacent-identifier Paraphrase axis \
               (axis #13): user typed \"Mamba2\" (the v2 model \
               variant) instead of \"Mamba\". SimpleTokenizer's \
               alphanumeric-contiguous tokenization treats \
               \"Mamba2\" as a distinct token from \"Mamba\". \
               AND-conjunction on {mamba2, ssm, cache} blocks \
               the iter-2 canonical. Thirteenth Paraphrase axis \
               distinct from long-form / inflection / 4 typo \
               subclasses / 2 synonym / abbreviation / ASCII-\
               folding / homoglyph / compound-typo / \
               concatenation. CURRENTLY FAILS by design — pin \
               for future version-aware tokenization or BERT-\
               style WordPiece subword splitting. Zero new \
               seeds.",
    },
    FVaultRecallRow {
        // 13th Paraphrase row (iter-140): NEW axis — CONCATENATION
        // (whitespace deletion). User typed "MambaSSMcache" (no
        // spaces) instead of "Mamba SSM cache". Tantivy tokenizes
        // the concatenated query as a single token; the canonical
        // has the 3 tokens separately, so AND on {mambassmcache}
        // blocks the canonical. Distinct from every prior
        // Paraphrase axis: it's not an edit-distance error or
        // synonym/abbreviation/homoglyph — it's a tokenization-
        // boundary mismatch (whitespace deleted).
        query: "MambaSSMcache",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Concatenation Paraphrase axis (axis #12): user typed \
               \"MambaSSMcache\" with no whitespace separators. \
               Tantivy's SimpleTokenizer splits only on non-\
               alphanumeric (whitespace is non-alphanumeric, but \
               so is `::` etc.), so contiguous alphanumerics \
               form a single token. The query becomes one token \
               (\"mambassmcache\"), and AND-conjunction can't \
               match any doc that lacks this exact concatenated \
               form. Twelfth Paraphrase axis distinct from long-\
               form / inflection / 4 typo subclasses / 2 synonym \
               / abbreviation / ASCII-folding / homoglyph / \
               compound-typo. CURRENTLY FAILS by design — pin \
               for future tokenization-aware fuzzy match (e.g. \
               subword tokenization, character-n-gram fallback, \
               or query-side word-segmentation step).",
    },
    FVaultRecallRow {
        // 12th Paraphrase row (iter-125): COMPOUND-TYPO subclass —
        // multiple edit operations in one query (edit distance ≥ 2).
        // Distinct from the 4 single-edit Damerau-Levenshtein
        // primitives (iter-20/90/97/104) AND from homoglyph
        // (iter-116). Query "Mamba SSI cahce" combines a
        // substitution (SSM → SSI) with a transposition (cache →
        // cahce). AND-conjunction on {Mamba, SSI, cahce} blocks
        // the canonical (which has neither SSI nor cahce). Reuses
        // iter-2 Mamba corpus; zero new seeds.
        query: "Mamba SSI cahce",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Compound-typo Paraphrase axis (axis #11): two edit \
               operations stacked — substitution (SSM → SSI) + \
               transposition (cache → cahce). Edit distance ≥ 2 \
               from the canonical spelling. Distinct from the 4 \
               single-edit Damerau-Levenshtein primitives \
               (iter-20/90/97/104) AND from homoglyph (iter-116). \
               Tests robustness for fuzzy matchers configured for \
               edit-distance > 1; many BK-tree or TermSetQuery \
               implementations cap at edit-distance = 1 by \
               default. When a fuzzy matcher with edit-distance ≥ \
               2 ships, this row flips to ✅ alongside iter-20/ \
               90/97/104 — proving the fix scales to multi-edit \
               errors, not just single-edit ones. Zero new seeds.",
    },
    FVaultRecallRow {
        // 19th Paraphrase row (iter-186): 2nd homoglyph row,
        // agent-runtime domain. iter-116 used Cyrillic "а"
        // inside "mamba"; iter-186 uses Cyrillic "е" (U+0435)
        // inside "agent" → "agеnt". Tantivy treats Latin-e and
        // Cyrillic-е as distinct codepoints; 3-term AND on
        // {agеnt, runtime, substrate} blocks the canonical (which
        // has Latin "agent"). Extends homoglyph axis to 2
        // domains.
        query: "agеnt runtime substrate",
        expected_paths: &["notes/agent_runtime_v2_substrate.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Paraphrase,
        top_n: 5,
        note: "Second homoglyph Paraphrase row (iter-186): \
               extends homoglyph axis (iter-116) from Mamba SSM \
               to agent-runtime domain. Cyrillic \"е\" (U+0435) \
               replaces Latin \"e\" inside \"agent\". Tantivy's \
               codepoint-aware tokenizer treats the two as \
               distinct; 3-term AND blocks the canonical. Two \
               rows now prove the homoglyph axis spans multiple \
               domains. Zero new seeds.",
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
        // 19th Synthesis row (iter-184): 2nd 2-term-AND subset
        // on iter-43 + iter-75 agent-runtime pair. iter-177 used
        // {agent, runtime}; iter-184 uses {runtime, substrate}.
        // Both pair-partners carry both; agent_brainstorm has
        // neither, runtime_old_design has runtime only,
        // substrate_concepts has substrate only — all blocked.
        // Zero new seeds.
        query: "runtime substrate",
        expected_paths: &[
            "notes/agent_runtime_v2_substrate.md",
            "notes/agent_runtime_substrate_v3.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Nineteenth Synthesis row (iter-184): second 2-term-\
               AND subset on agent-runtime pair. iter-177 \
               {agent, runtime} + iter-184 {runtime, substrate} — \
               two of the C(4,2) = 6 possible 2-term subsets on \
               the pair's shared 4-term vocab now covered. All \
               iter-43 single-term decoys are blocked by AND. \
               Zero new seeds.",
    },
    FVaultRecallRow {
        // 27th Synthesis row (iter-243). FIFTH 2-term-AND subset
        // on iter-19 hardware-falsifier pair: {floor, handbook}.
        // m2_pro_hardware_floor has both (handbook at tail);
        // falsifier_handbook has both. No other seed has either
        // "floor" or "handbook". AND matches only the pair. Five
        // of C(4,2)=6 surveyed. Only {falsifier, handbook}
        // remains for full C(4,2) closure on the hardware pair.
        query: "floor handbook",
        expected_paths: &[
            "notes/m2_pro_hardware_floor.md",
            "notes/falsifier_handbook.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Twenty-seventh Synthesis row (iter-243): fifth \
               2-term-AND subset on hardware pair. {floor, \
               handbook} — both tokens unique-to-pair. Five of \
               C(4,2)=6 surveyed. Only {falsifier, handbook} \
               remains. Brings Synthesis to depth 27. Zero new \
               seeds.",
    },
    FVaultRecallRow {
        // 26th Synthesis row (iter-236). FOURTH 2-term-AND
        // subset on iter-19 hardware-falsifier pair: {floor,
        // falsifier}. Both pair-partners have both tokens. No
        // other seed has "floor" or "falsifier" — these are
        // unique-to-the-pair tokens. AND-on-2 matches only the
        // pair. iter-214 + iter-221 + iter-229 + iter-236 = 4
        // of C(4,2)=6 surveyed.
        query: "floor falsifier",
        expected_paths: &[
            "notes/m2_pro_hardware_floor.md",
            "notes/falsifier_handbook.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Twenty-sixth Synthesis row (iter-236): fourth \
               2-term-AND subset on hardware pair. {floor, \
               falsifier} — both tokens unique-to-the-pair (no \
               other seed has either). Cleanest discriminator \
               yet on the hardware pair: zero competing docs at \
               all. Four of C(4,2)=6 surveyed (iter-214 + \
               iter-221 + iter-229 + iter-236). Two remain: \
               {floor, handbook}, {falsifier, handbook}. Brings \
               Synthesis to depth 26. Zero new seeds.",
    },
    FVaultRecallRow {
        // 25th Synthesis row (iter-229). THIRD 2-term-AND subset
        // on the iter-19 hardware-falsifier pair: {hardware,
        // handbook}. Both pair-partners carry both tokens (m2_pro
        // _hardware_floor.md has "...falsifier handbook" at tail;
        // falsifier_handbook.md has handbook in body). No other
        // seed has "handbook" token. user_hardware.md has hardware
        // only. AND on {hardware, handbook} matches only the pair.
        // Three of C(4,2)=6 subsets on hardware pair surveyed
        // (iter-214 + iter-221 + iter-229).
        query: "hardware handbook",
        expected_paths: &[
            "notes/m2_pro_hardware_floor.md",
            "notes/falsifier_handbook.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Twenty-fifth Synthesis row (iter-229): third \
               2-term-AND subset on hardware pair. {hardware, \
               handbook} — both pair-partners have both \
               (handbook is the unique tail-token on the \
               canonical pair); no other seed has \"handbook\". \
               Three of C(4,2)=6 surveyed (iter-214 {hardware, \
               floor} + iter-221 {hardware, falsifier} + \
               iter-229 {hardware, handbook}). Halfway through \
               the hardware-pair C(4,2) survey. Brings Synthesis \
               to depth 25. Zero new seeds.",
    },
    FVaultRecallRow {
        // 24th Synthesis row (iter-221). SECOND 2-term-AND subset
        // on the iter-19 hardware-falsifier pair: {hardware,
        // falsifier}. Both pair-partners carry both;
        // user_hardware.md has hardware only (no falsifier); no
        // other seed has "falsifier" token at all. AND on
        // {hardware, falsifier} matches only the pair. iter-214
        // started the hardware-pair C(4,2)=6 survey with
        // {hardware, floor}; iter-221 = 2 of 6.
        query: "hardware falsifier",
        expected_paths: &[
            "notes/m2_pro_hardware_floor.md",
            "notes/falsifier_handbook.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Twenty-fourth Synthesis row (iter-221): second \
               2-term-AND subset on iter-19 hardware-falsifier \
               pair. {hardware, falsifier} — both pair-partners \
               have both; user_hardware.md has hardware only; no \
               other seed has \"falsifier\" at all. Two of \
               C(4,2)=6 subsets on the hardware pair now \
               surveyed (iter-214 {hardware, floor} + iter-221 \
               {hardware, falsifier}). Brings Synthesis to \
               depth 24. Zero new seeds.",
    },
    FVaultRecallRow {
        // 23rd Synthesis row (iter-214). FIRST 2-term-AND subset
        // on the iter-19 hardware-falsifier pair (until now only
        // the C(4,3) survey ran on this pair). Pair-partner
        // m2_pro_hardware_floor.md and falsifier_handbook.md
        // both carry {hardware, floor, falsifier, handbook};
        // the only other seed with "hardware" is user_hardware.md
        // (no "floor"). AND on {hardware, floor} matches only
        // the pair. Starts C(4,2) survey on the hardware pair —
        // first of 6 possible 2-term subsets.
        //
        // (The agent-runtime pair's sixth subset {agent, canon}
        // is unreachable because agent_brainstorm.md carries
        // both tokens — that's a 5-of-6 ceiling on that pair,
        // not 6-of-6. Iter-214 pivots to the unexplored hardware
        // pair instead.)
        query: "hardware floor",
        expected_paths: &[
            "notes/m2_pro_hardware_floor.md",
            "notes/falsifier_handbook.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Twenty-third Synthesis row (iter-214): FIRST 2-\
               term-AND subset on iter-19 hardware-falsifier \
               pair. {hardware, floor} — both pair-partners have \
               both; user_hardware.md has hardware only (no \
               floor); every other seed lacks both. Opens the \
               C(4,2) = 6 survey on the hardware pair (which \
               previously only had the C(4,3) = 4 survey \
               complete). Notes the {agent, canon} ceiling on \
               the iter-43+iter-75 agent-runtime pair: \
               agent_brainstorm.md has both tokens so that \
               subset is unreachable — agent-runtime pair tops \
               out at 5 of C(4,2) = 6, not 6 of 6. Brings \
               Synthesis to depth 23. Zero new seeds.",
    },
    FVaultRecallRow {
        // 22nd Synthesis row (iter-208). FIFTH 2-term-AND subset
        // on iter-43 + iter-75 agent-runtime pair: {runtime,
        // canon}. iter-177 {agent, runtime}; iter-184 {runtime,
        // substrate}; iter-194 {substrate, canon}; iter-200
        // {agent, substrate}; iter-208 {runtime, canon}. Five of
        // C(4,2) = 6 possible 2-term subsets. Only the {agent,
        // canon} subset remains. Both pair-partners carry both
        // query tokens; agent_brainstorm has canon only (no
        // runtime); runtime_old_design has runtime only (no
        // canon); compression_doctrine_canon docs have canon only
        // — all blocked by AND-on-2.
        query: "runtime canon",
        expected_paths: &[
            "notes/agent_runtime_v2_substrate.md",
            "notes/agent_runtime_substrate_v3.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Twenty-second Synthesis row (iter-208): fifth \
               2-term-AND subset on agent-runtime pair. {runtime, \
               canon} — both pair-partners have both; the \
               compression_doctrine_canon_v1/v2 docs have canon \
               but no runtime, agent_brainstorm has canon only, \
               runtime_old_design has runtime only — all blocked. \
               Five of C(4,2) = 6 possible 2-term subsets now \
               covered on the pair's {agent, runtime, substrate, \
               canon} vocab. Only {agent, canon} remains. Brings \
               Synthesis to depth 22. Zero new seeds.",
    },
    FVaultRecallRow {
        // 21st Synthesis row (iter-200) — milestone iteration.
        // FOURTH 2-term-AND subset on iter-43 + iter-75 agent-
        // runtime pair: {agent, substrate}. iter-177 {agent,
        // runtime}; iter-184 {runtime, substrate}; iter-194
        // {substrate, canon}; iter-200 {agent, substrate}. Four
        // of the C(4,2) = 6 possible 2-term subsets on the pair's
        // shared vocab {agent, runtime, substrate, canon} now
        // covered. Both pair-partners carry both query tokens;
        // agent_brainstorm has agent only (no substrate);
        // substrate_concepts has substrate only (no agent);
        // runtime_old_design has neither; compression_doctrine_
        // canon docs have neither — all blocked by AND-on-2.
        // Brings Synthesis to depth 21. Zero new seeds.
        query: "agent substrate",
        expected_paths: &[
            "notes/agent_runtime_v2_substrate.md",
            "notes/agent_runtime_substrate_v3.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Twenty-first Synthesis row (iter-200, milestone): \
               fourth 2-term-AND subset on agent-runtime pair. \
               iter-177 + iter-184 + iter-194 + iter-200 = four \
               of C(4,2) = 6 possible 2-term subsets on the \
               pair's {agent, runtime, substrate, canon} vocab. \
               Brings Synthesis to depth 21 — second category \
               past the depth-20 horizon (Adversarial reached \
               21 at iter-199). Zero new seeds.",
    },
    FVaultRecallRow {
        // 20th Synthesis row (iter-194): 3rd 2-term-AND subset
        // on iter-43 + iter-75 agent-runtime pair. iter-177
        // {agent, runtime}; iter-184 {runtime, substrate};
        // iter-194 {substrate, canon}. Three of the C(4,2) = 6
        // possible 2-term subsets now covered. Zero new seeds.
        query: "substrate canon",
        expected_paths: &[
            "notes/agent_runtime_v2_substrate.md",
            "notes/agent_runtime_substrate_v3.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Twentieth Synthesis row (iter-194): third 2-term-\
               AND subset on agent-runtime pair. {substrate, \
               canon} — both pair-partners have both; \
               substrate_concepts has substrate only, \
               agent_brainstorm and compression_doctrine_canon \
               docs have canon only — all blocked by AND. Three \
               of C(4,2) = 6 possible 2-term subsets now \
               covered. Zero new seeds.",
    },
    FVaultRecallRow {
        // 18th Synthesis row (iter-177): 2-term-AND subset on
        // iter-43 + iter-75 agent-runtime pair. The pair's shared
        // 4-term vocabulary {agent, runtime, substrate, canon}
        // has C(4,2) = 6 possible 2-term subsets; iter-177 uses
        // {agent, runtime}. Both pair-partners carry both tokens;
        // all 3 iter-43 single-term decoys (agent_brainstorm /
        // runtime_old_design / substrate_concepts) are blocked
        // by AND. Zero new seeds.
        query: "agent runtime",
        expected_paths: &[
            "notes/agent_runtime_v2_substrate.md",
            "notes/agent_runtime_substrate_v3.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Eighteenth Synthesis row (iter-177): 2-term-AND on \
               iter-43 + iter-75 agent-runtime pair. iters 75/118/ \
               124/133 exhaust C(4,3) on the pair's 4-term \
               shared vocab; iter-177 opens the 2-term-AND \
               exploration (C(4,2) = 6 possible subsets). Both \
               pair-partners match; iter-43 single-term decoys \
               blocked. Top-2 retains the pair. Zero new seeds.",
    },
    FVaultRecallRow {
        // 12th Synthesis row (iter-133): fourth and FINAL 3-term
        // subset on iter-43 + iter-75 pair. With 4-element shared
        // vocabulary {agent, runtime, substrate, canon}, there are
        // exactly C(4,3) = 4 possible 3-term subsets. iter-75
        // {a,r,s} + iter-118 {a,r,c} + iter-124 {r,s,c} + iter-133
        // {a,s,c} — exhausts the subset space, proves pair-
        // retention holds against EVERY possible 3-term slice.
        query: "agent substrate canon",
        expected_paths: &[
            "notes/agent_runtime_v2_substrate.md",
            "notes/agent_runtime_substrate_v3.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 3,
        note: "Twelfth Synthesis row (iter-133): fourth and final \
               3-term subset on iter-43 + iter-75 pair. Four \
               subsets exhaust C(4,3) on the shared 4-element \
               vocab {agent, runtime, substrate, canon}: iter-75 \
               {a,r,s}, iter-118 {a,r,c}, iter-124 {r,s,c}, \
               iter-133 {a,s,c}. Pair-retention proven against \
               EVERY possible 3-term slice — the contract is not \
               coincidentally keyed to any specific query subset. \
               AND-conjunction on {agent, substrate, canon} \
               blocks every single-term decoy and every other-\
               domain seed. Zero new seeds.",
    },
    FVaultRecallRow {
        // 10th Synthesis row (iter-124): third 3-term query subset
        // on iter-43 + iter-75 pair. Subsets covered: iter-75
        // {agent, runtime, substrate}; iter-118 {agent, runtime,
        // canon}; iter-124 {runtime, substrate, canon}. Three
        // distinct subsets of {agent, runtime, substrate, canon}
        // all retain the pair — proves the pair-retention is
        // robust against ANY 3-term shared-vocabulary slice.
        query: "runtime substrate canon",
        expected_paths: &[
            "notes/agent_runtime_v2_substrate.md",
            "notes/agent_runtime_substrate_v3.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 3,
        note: "Tenth Synthesis row (iter-124): third 3-term subset \
               on iter-43 + iter-75 pair. Three distinct query \
               subsets of the pair's shared 4-term vocabulary \
               ({agent, runtime, substrate, canon}) all retain \
               the pair — proves the pair-retention contract is \
               robust against any 3-term subset. AND-conjunction \
               on {runtime, substrate, canon} blocks every \
               single-term decoy and every other-domain seed \
               (compression_doctrine_canon docs have canon but \
               not runtime/substrate). Zero new seeds.",
    },
    FVaultRecallRow {
        // 16th Synthesis row (iter-165): fourth and FINAL 3-term
        // subset on iter-19 hardware-falsifier pair. iter-45 +
        // iter-144 + iter-156 + iter-165 exhaust C(4,3) = 4 of
        // the pair's shared 4-term vocab {hardware, floor,
        // falsifier, handbook}. Mirror of iter-43+iter-75
        // C(4,3) exhaustion (iters 75/118/124/133). Both pairs
        // now C(4,3)-complete. Zero new seeds.
        query: "hardware floor handbook",
        expected_paths: &[
            "notes/m2_pro_hardware_floor.md",
            "notes/falsifier_handbook.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 3,
        note: "Sixteenth Synthesis row (iter-165): fourth and \
               final 3-term subset on iter-19 pair. C(4,3) = 4 \
               possible 3-term subsets on the pair's shared \
               4-term vocab {hardware, floor, falsifier, \
               handbook}: iter-45 + iter-144 + iter-156 + \
               iter-165 = exhaustive. The iter-19 hardware pair \
               now joins the iter-43+iter-75 agent-runtime pair \
               at C(4,3)-complete robustness pinning. Both pairs \
               proved robust against EVERY possible 3-term slice \
               of their shared vocabulary. Zero new seeds.",
    },
    FVaultRecallRow {
        // 15th Synthesis row (iter-156): third alt-subset on
        // iter-19 hardware-falsifier pair. iter-45 used {hardware,
        // floor, falsifier}; iter-144 used {hardware, falsifier,
        // handbook}; iter-156 uses {floor, falsifier, handbook}.
        // Three of the four C(4,3) subsets on the pair's shared
        // 4-term vocabulary {hardware, floor, falsifier,
        // handbook}. Zero new seeds.
        query: "floor falsifier handbook",
        expected_paths: &[
            "notes/m2_pro_hardware_floor.md",
            "notes/falsifier_handbook.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 3,
        note: "Fifteenth Synthesis row (iter-156): third 3-term \
               subset on iter-19 hardware-falsifier pair. Together \
               iter-45 + iter-144 + iter-156 exercise three of \
               the C(4,3) = 4 possible 3-term subsets on the \
               pair's shared 4-term vocabulary {hardware, floor, \
               falsifier, handbook}. Robustness pin across \
               multiple subsets on the same pair (mirror of the \
               C(4,3)-exhaustive series on the agent-runtime \
               pair, iters 75/118/124/133). Zero new seeds.",
    },
    FVaultRecallRow {
        // 13th Synthesis row (iter-144): alt-subset on iter-19
        // hardware-falsifier pair. iter-45 used {hardware, floor,
        // falsifier}; iter-144 uses {hardware, falsifier,
        // handbook}. Both canonicals (m2_pro_hardware_floor +
        // falsifier_handbook) carry all 3 terms — the token
        // "handbook" appears in both seeds. AND-conjunction
        // matches both; other seeds have none of these terms.
        // Zero new seeds.
        query: "hardware falsifier handbook",
        expected_paths: &[
            "notes/m2_pro_hardware_floor.md",
            "notes/falsifier_handbook.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 3,
        note: "Thirteenth Synthesis row (iter-144): alt-subset on \
               iter-19 hardware-falsifier pair. iter-45 surveys \
               {hardware, floor, falsifier}; iter-144 surveys \
               {hardware, falsifier, handbook}. Both canonicals \
               carry all 3 terms (handbook appears in both seeds \
               by design: \"falsifier handbook\" is the iter-19 \
               pair-partner's name, and m2_pro_hardware_floor's \
               body references it). Demonstrates pair-retention \
               robustness on iter-19 pair across alternate 3-term \
               subsets. Zero new seeds.",
    },
    FVaultRecallRow {
        // 9th Synthesis row (iter-118): alternate 3-term subset on
        // the iter-43 + iter-75 agent-runtime pair. iter-75 uses
        // {agent, runtime, substrate}; iter-118 uses {agent,
        // runtime, canon} — a different shared-vocabulary slice
        // of the same pair-partners. Both canonicals carry all 3
        // terms (canon appears in agent_runtime_v2_substrate
        // "System G Invader Agent canon" and in
        // agent_runtime_substrate_v3 "System G canon"). The 3
        // iter-43 single-term decoys are blocked by AND: agent_
        // brainstorm has agent+canon (2/3, missing runtime),
        // runtime_old_design has only runtime, substrate_concepts
        // has only substrate. The 2 compression_doctrine_canon
        // pair docs have canon but not agent/runtime — also
        // blocked. Zero new seeds.
        query: "agent runtime canon",
        expected_paths: &[
            "notes/agent_runtime_v2_substrate.md",
            "notes/agent_runtime_substrate_v3.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 3,
        note: "Ninth Synthesis row (iter-118): alternate 3-term \
               query subset on the iter-43 + iter-75 agent-runtime \
               pair. Proves the pair-retention contract holds \
               across multiple query subsets of the pair's shared \
               vocabulary (iter-75 uses {agent, runtime, \
               substrate}; iter-118 uses {agent, runtime, \
               canon}). AND-conjunction blocks all single-term \
               iter-43 decoys; agent_brainstorm gets 2/3 (agent + \
               canon, missing runtime) and is still blocked by \
               AND. Robustness pin: the pair-retention behavior \
               is not coincidentally keyed to one specific query \
               wording.",
    },
    FVaultRecallRow {
        // 14th Synthesis row (iter-151): alt 2-term subset on
        // Metal pair. iter-128 used {metal, pipeline}; iter-151
        // uses {compute, pipeline}. Both iter-91 canonical and
        // iter-95 partner carry both terms; compute_brainstorm
        // has compute only (no pipeline → AND blocks); other
        // seeds have neither. Tests 2-term-AND robustness across
        // multiple subsets of the same pair. Zero new seeds.
        query: "compute pipeline",
        expected_paths: &[
            "notes/metal_compute_shader_kernel.md",
            "notes/metal_compute_pipeline_v2.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Fourteenth Synthesis row (iter-151): alt 2-term \
               subset on Metal pair. iter-128 surveys {metal, \
               pipeline}; iter-151 surveys {compute, pipeline}. \
               Two 2-term subsets on the same iter-91 + iter-95 \
               pair both retain the pair under top-2. Robustness \
               pin: the 2-term-AND pair-retention is not \
               coincidentally tied to one specific shared-vocab \
               slice. Zero new seeds.",
    },
    FVaultRecallRow {
        // 17th Synthesis row (iter-172): third 2-term subset on
        // Metal pair. iter-128 {metal, pipeline}; iter-151
        // {compute, pipeline}; iter-172 {metal, compute}. All
        // C(3,2)=3 possible 2-term subsets of the pair's shared
        // 3-term vocabulary {metal, compute, pipeline} now
        // covered. Zero new seeds.
        query: "metal compute",
        expected_paths: &[
            "notes/metal_compute_shader_kernel.md",
            "notes/metal_compute_pipeline_v2.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Seventeenth Synthesis row (iter-172): third 2-term \
               subset on the Metal pair. iter-128 + iter-151 + \
               iter-172 exhaust C(3,2) = 3 possible 2-term \
               subsets on the pair's shared 3-term vocab {metal, \
               compute, pipeline}. Smaller-scale mirror of the \
               C(4,3)-complete pairs (iter-43+iter-75 + iter-19). \
               Zero new seeds.",
    },
    FVaultRecallRow {
        // 11th Synthesis row (iter-128): 2-term-AND boundary on
        // iter-91 + iter-95 Metal pair. iter-95 used 3-term AND
        // {metal, compute, pipeline}; iter-128 uses 2-term AND
        // {metal, pipeline} — the smallest meaningful subset.
        // Mirror of iter-127's ChattyPrefix 2-term-AND boundary,
        // but for Synthesis pair-retention. Tests the contract
        // at the AND-conjunction's narrow edge: 2 surviving
        // terms still trigger AND, and pair-retention still
        // holds. Zero new seeds.
        query: "metal pipeline",
        expected_paths: &[
            "notes/metal_compute_shader_kernel.md",
            "notes/metal_compute_pipeline_v2.md",
        ],
        forbidden_paths: &[],
        category: FVaultRecallCategory::Synthesis,
        top_n: 2,
        note: "Eleventh Synthesis row (iter-128): 2-term-AND \
               boundary on iter-91 + iter-95 Metal pair. The 2 \
               query tokens {metal, pipeline} are the smallest \
               meaningful subset on this pair's shared \
               vocabulary; AND-conjunction filters every other \
               seed (metal_archive has metal only; compute_\
               brainstorm and shader_misc_notes have neither; \
               every other domain seed lacks both). Pre-MMR \
               baseline: both pair-partners retained at top-2. \
               Zero new seeds.",
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
        // 17th ChattyPrefix row (iter-175): modal-led wrapper on
        // Mamba SSM domain with same 3-term survivors as iter-134.
        // iter-134 imperative \"Pull my notes on\"; iter-175
        // modal \"Could you find my\". Two wrapper shapes × same
        // survivors. Zero new seeds.
        query: "Could you find my Mamba SSM cache notes",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &["notes/generic_attention_overview.md"],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Seventeenth ChattyPrefix row (iter-175): modal-led \
               wrapper on Mamba SSM domain. iter-134 used \
               imperative \"Pull my notes on\" + survivors \
               {Mamba, SSM, cache}; iter-175 uses modal \"Could \
               you find my\" + same survivors. Different wrapper \
               shape, same signal domain. Zero new seeds.",
    },
    FVaultRecallRow {
        // 18th ChattyPrefix row (iter-181): hardware-falsifier
        // signal domain — 11th distinct signal universe for the
        // ChattyPrefix axis. Survivors after strip_query_chatter:
        // {hardware, floor, falsifier} — 3 terms → AND. Both
        // iter-19 pair-partners (m2_pro_hardware_floor +
        // falsifier_handbook) carry all 3 terms. Reuses iter-19
        // corpus; zero new seeds.
        query: "Pull my notes on hardware floor falsifier",
        expected_paths: &["notes/m2_pro_hardware_floor.md"],
        forbidden_paths: &[],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Eighteenth ChattyPrefix row (iter-181): hardware-\
               falsifier signal domain — extends strip-robust \
               coverage to an 11th distinct lexical universe. \
               Chatter prefix {Pull, my, notes, on}; survivors \
               {hardware, floor, falsifier} — 3 surviving terms \
               trigger AND-conjunction. Both iter-19 pair-\
               partners match (top_n=7 retains both); no decoys \
               in this domain exist. Zero new seeds.",
    },
    FVaultRecallRow {
        // 12th ChattyPrefix row (iter-134): Mamba SSM signal
        // domain — 10th distinct signal universe. iter-2 used
        // this canonical for SignalOnly (no chatter); iter-134
        // adds the chatter-wrapped variant. Survivors after
        // strip_query_chatter: {Mamba, SSM, cache} (3 terms →
        // AND). Reuses iter-2 corpus; zero new seeds.
        query: "Pull my notes on Mamba SSM cache",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &["notes/generic_attention_overview.md"],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Twelfth ChattyPrefix row (iter-134): Mamba SSM \
               signal domain — 10th distinct lexical universe. \
               Chatter prefix {Pull, my, notes, on}; survivors \
               {Mamba, SSM, cache} — 3 surviving terms trigger \
               AND. Mamba's mixed-script seed (mamba_chinese.md) \
               and the Unicode multilingual seeds (Cyrillic / \
               Arabic / Greek / katakana / Hebrew / Devanagari \
               / Thai / Korean variants) each have Mamba but \
               lack \"cache\"/\"SSM\" or have an interposing \
               non-Latin token — they don't satisfy 3-term AND. \
               Zero new seeds.",
    },
    FVaultRecallRow {
        // 13th ChattyPrefix row (iter-142): IR-BM25 domain,
        // different signal subset. iter-122 uses survivors
        // {bm25, saturation, length}; iter-142 uses survivors
        // {bm25, length, penalty}. Same prefix shape; different
        // signal-token slice. Tests strip-robust × alt-subset
        // pin in this domain. Reuses iter-84 corpus; zero new
        // seeds.
        query: "Show me my bm25 length penalty notes",
        expected_paths: &["notes/bm25_saturation_length_penalty.md"],
        forbidden_paths: &[
            "notes/bm25_overview.md",
            "notes/length_archive.md",
            "notes/penalty_misc_notes.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Thirteenth ChattyPrefix row (iter-142): IR-BM25 \
               domain, alternate signal subset. iter-122 surveys \
               {bm25, saturation, length}; iter-142 surveys \
               {bm25, length, penalty}. Same chatter wrapper \
               shape {Show, me, my, notes}; different signal-\
               token slice. Two rows on iter-84 corpus with \
               different 3-term survivors prove the strip-robust \
               contract is not coincidentally tied to the \
               specific subset of signal tokens. Zero new seeds.",
    },
    FVaultRecallRow {
        // 16th ChattyPrefix row (iter-168): modal-led wrapper in
        // IR-BM25 signal domain. iter-122 used "Show me my" wrapper
        // ({bm25, saturation, length} survivors); iter-168 uses
        // modal "Could you find my" wrapper with the same
        // survivors. Tests strip-robust across MULTIPLE chatter-
        // shape variants on the same signal-domain corpus.
        query: "Could you find my bm25 saturation length notes",
        expected_paths: &["notes/bm25_saturation_length_penalty.md"],
        forbidden_paths: &[
            "notes/bm25_overview.md",
            "notes/length_archive.md",
            "notes/penalty_misc_notes.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Sixteenth ChattyPrefix row (iter-168): modal-led \
               wrapper on iter-84 IR-BM25 corpus. iter-122 used \
               imperative \"Show me my\" + same survivors \
               {bm25, saturation, length}; iter-168 uses modal \
               \"Could you find my\" + same survivors. Tests \
               strip-robust on the SAME signal-token subset \
               across DIFFERENT chatter prefix shapes — \
               complements iter-122/142 which used the same \
               prefix shape across DIFFERENT signal subsets. \
               Zero new seeds.",
    },
    FVaultRecallRow {
        // 27th ChattyPrefix row (iter-247): Hebrew-multilingual
        // signal domain — 17th distinct lexical universe. Mixed
        // Latin + Hebrew survivors {Mamba, ש} (single-codepoint
        // Hebrew shin). 2-term AND matches only iter-109's
        // mamba_hebrew.md. SIXTH non-ASCII ChattyPrefix domain.
        // SECOND RTL ChattyPrefix (after iter-233 Arabic) — pins
        // chatter-strip + AND across both RTL-script families
        // in the Aramaic-descendant cluster.
        query: "Show me my Mamba ש notes",
        expected_paths: &["notes/mamba_hebrew.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Twenty-seventh ChattyPrefix row (iter-247): \
               Hebrew-multilingual signal domain — 17th distinct \
               lexical universe. Survivors {Mamba, ש} after \
               strip. 2-term AND matches only iter-109 mamba_\
               hebrew.md. Sixth non-ASCII ChattyPrefix (after \
               Latin-diacritic + Cyrillic + CJK + Arabic + \
               Greek). Second RTL ChattyPrefix (after Arabic). \
               Brings ChattyPrefix to depth 27. Zero new seeds.",
    },
    FVaultRecallRow {
        // 26th ChattyPrefix row (iter-240, milestone iteration):
        // Greek-multilingual signal domain — 16th distinct
        // lexical universe. Mixed Latin + Greek survivors
        // {Mamba, λ}. 2-term AND matches only iter-93's
        // mamba_greek_lambda.md. FIFTH non-ASCII ChattyPrefix
        // (after Latin-diacritic + Cyrillic + CJK + Arabic) and
        // FIRST single-codepoint non-ASCII signal-token in
        // ChattyPrefix (parallels iter-238 first single-codepoint
        // SignalOnly).
        query: "Show me my Mamba λ notes",
        expected_paths: &["notes/mamba_greek_lambda.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Twenty-sixth ChattyPrefix row (iter-240, \
               milestone): Greek-multilingual signal domain — \
               16th distinct lexical universe. Survivors \
               {Mamba, λ} after strip. 2-term AND matches only \
               iter-93 mamba_greek_lambda.md. FIFTH non-ASCII \
               ChattyPrefix and FIRST single-codepoint non-ASCII \
               signal-token (parallels iter-238 SignalOnly). \
               Brings ChattyPrefix to depth 26 — fourth category \
               past depth-25 horizon. Zero new seeds.",
    },
    FVaultRecallRow {
        // 25th ChattyPrefix row (iter-233): Arabic-multilingual
        // signal domain — 15th distinct lexical universe.
        // Survivors after strip {Mamba, كاش}. 2-term AND-
        // conjunction matches only iter-32's mamba_arabic.md
        // among 18 mamba_X.md seeds. FOURTH non-ASCII ChattyPrefix
        // (after Latin-diacritic + Cyrillic + CJK) and FIRST RTL
        // signal-domain. Pins chatter-strip + AND across both
        // bidirectional rendering AND non-Latin script blocks.
        query: "Show me my Mamba كاش notes",
        expected_paths: &["notes/mamba_arabic.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Twenty-fifth ChattyPrefix row (iter-233): Arabic-\
               multilingual signal domain — 15th distinct \
               lexical universe and FIRST RTL signal-domain. \
               Mixed Latin + Arabic survivors {Mamba, كاش} after \
               strip. 2-term AND matches only iter-32 \
               mamba_arabic.md. Fourth non-ASCII ChattyPrefix \
               (after Latin-diacritic + Cyrillic + CJK) — \
               parallels iter-231 (first RTL SignalOnly). \
               Brings ChattyPrefix to depth 25. Zero new seeds.",
    },
    FVaultRecallRow {
        // 24th ChattyPrefix row (iter-225): CJK-multilingual
        // signal domain — 14th distinct lexical universe.
        // Survivors after strip {Mamba, 缓存}. 2-term AND matches
        // only iter-9's mamba_chinese.md: mamba_english_only has
        // Mamba but no 缓存; pure_chinese has 缓存 but no Mamba;
        // every other mamba_X.md script has Mamba but lacks 缓存
        // — all blocked. THIRD non-ASCII ChattyPrefix row after
        // iter-211 Latin-diacritic and iter-218 Cyrillic — pins
        // strip+AND across THREE distinct non-Latin script
        // families (Latin-with-marks + Cyrillic + Han Ideograph).
        query: "Show me my Mamba 缓存 notes",
        expected_paths: &["notes/mamba_chinese.md"],
        forbidden_paths: &[
            "notes/mamba_english_only.md",
            "notes/pure_chinese.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Twenty-fourth ChattyPrefix row (iter-225): CJK-\
               multilingual signal domain — 14th distinct \
               lexical universe. Mixed Latin + CJK survivors \
               {Mamba, 缓存} after strip. 2-term AND-conjunction \
               matches only iter-9 mamba_chinese.md — Latin \
               token \"Mamba\" + CJK token \"缓存\" together \
               discriminate across the entire 17-row mamba_X \
               script-extension family AND the pure-CJK \
               pure_chinese.md. Third non-ASCII ChattyPrefix \
               after Latin-diacritic and Cyrillic. Brings \
               ChattyPrefix to depth 24. Zero new seeds.",
    },
    FVaultRecallRow {
        // 23rd ChattyPrefix row (iter-218): Cyrillic-multilingual
        // signal domain — 13th distinct lexical universe. Mixed
        // Latin + Cyrillic survivors: {Mamba, кэш} after chatter
        // strip. AND-on-2 matches only iter-28's mamba_cyrillic.md
        // (which carries both Latin "Mamba" and Cyrillic "кэш").
        // The iter-9 mamba_english_only.md has "Mamba" but no
        // Cyrillic, so AND blocks it. Every other mamba_X.md
        // (chinese / arabic / hebrew / katakana / ...) has Mamba
        // but lacks "кэш" specifically — all blocked. SECOND
        // non-ASCII ChattyPrefix row after iter-211 Latin-
        // diacritic — pins the chatter-strip across two distinct
        // non-ASCII script families.
        query: "Show me my Mamba кэш notes",
        expected_paths: &["notes/mamba_cyrillic.md"],
        forbidden_paths: &["notes/mamba_english_only.md"],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Twenty-third ChattyPrefix row (iter-218): \
               Cyrillic-multilingual signal domain — 13th \
               distinct lexical universe. Mixed Latin + Cyrillic \
               survivors {Mamba, кэш} after strip. 2-term AND-\
               conjunction matches only mamba_cyrillic.md among \
               17 mamba_X.md seeds — the Cyrillic token \"кэш\" \
               specifically discriminates within the Mamba \
               script-extension family. Second non-ASCII \
               ChattyPrefix after iter-211 Latin-diacritic. \
               Brings ChattyPrefix to depth 23. Zero new seeds.",
    },
    FVaultRecallRow {
        // 22nd ChattyPrefix row (iter-211): Latin-diacritic
        // signal domain — 12th distinct lexical universe.
        // Survivors after strip_query_chatter: {naïve, résumé,
        // filter} — 3 surviving terms triggers AND-conjunction.
        // Only iter-3's unicode_resume_filter.md carries all
        // three with diacritics intact; ascii_only_resume.md has
        // "naive"/"resume"/"filter" — AND on the diacritic
        // tokens rejects the ASCII variant. First ChattyPrefix
        // row with non-ASCII signal tokens — proves the chatter
        // strip + AND pipeline holds across the diacritic token
        // boundary, parallels iter-210's first-non-ASCII
        // SignalOnly entry. Reuses iter-3 corpus; zero new seeds.
        query: "Show me my naïve résumé filter notes",
        expected_paths: &["notes/unicode_resume_filter.md"],
        forbidden_paths: &["notes/ascii_only_resume.md"],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Twenty-second ChattyPrefix row (iter-211): Latin-\
               diacritic signal domain — 12th distinct lexical \
               universe. Chatter prefix {Show, me, my} + chatter \
               suffix {notes}; survivors {naïve, résumé, filter} \
               — 3-term AND-conjunction. AND on the diacritic \
               tokens rejects ascii_only_resume.md (which has \
               undiacritcized variants). First ChattyPrefix row \
               with non-ASCII signal tokens — parallels iter-210 \
               (first non-ASCII SignalOnly). Brings ChattyPrefix \
               to depth 22. Zero new seeds.",
    },
    FVaultRecallRow {
        // 21st ChattyPrefix row (iter-203): machine-learning
        // signal domain — 11th distinct lexical universe for
        // ChattyPrefix (alongside residency-governance × 2,
        // tier-compression, agent-runtime, storage/vault, Metal-
        // compute, MLX-Swift, IR-BM25, wh+about, mamba-ssm). The
        // iter-86 canonical doubles as a Paraphrase failure
        // (acronym "ml" vs "machine learning") AND a SignalOnly
        // success (iter-202) AND now a ChattyPrefix success —
        // same seed crosses three category paths. Survivors after
        // strip_query_chatter: {machine, learning} — 2 surviving
        // terms triggers AND-conjunction. Only the iter-86
        // canonical has both. Reuses iter-86 corpus; zero new
        // seeds. Brings ChattyPrefix to depth 21.
        query: "Show me my machine learning notes",
        expected_paths: &["notes/machine_learning_inference_cache.md"],
        forbidden_paths: &["notes/generic_attention_overview.md"],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Twenty-first ChattyPrefix row (iter-203): machine-\
               learning signal domain — 11th distinct lexical \
               universe. Chatter prefix {Show, me, my} + chatter \
               suffix {notes}; survivors {machine, learning} — \
               2-term AND-conjunction. The iter-86 canonical now \
               serves THREE category paths: Paraphrase failure \
               (acronym \"ml\"), SignalOnly success (iter-202), \
               and ChattyPrefix success (iter-203). Brings \
               ChattyPrefix to depth 21 — fifth category past \
               the depth-20 horizon. Zero new seeds.",
    },
    FVaultRecallRow {
        // 20th ChattyPrefix row (iter-196): FOURTH (final) alt-
        // signal-subset on iter-84 IR-BM25 corpus, completing the
        // C(4,3) = 4 survey. iter-122 = {bm25, saturation, length};
        // iter-142 = {bm25, length, penalty}; iter-189 = {bm25,
        // saturation, penalty}; iter-196 = {saturation, length,
        // penalty} — the only subset that DROPS the "bm25" token.
        // Same wrapper shape as iter-122/142/189 (imperative
        // "Show me my X notes") so the only variable is which
        // 3-of-4 signal terms survive the strip. Proves strip-
        // robust isn't keyed to retaining the most-frequent token
        // either; the canonical wins even when the AND triple lacks
        // "bm25". Zero new seeds.
        query: "Show me my saturation length penalty notes",
        expected_paths: &["notes/bm25_saturation_length_penalty.md"],
        forbidden_paths: &[
            "notes/bm25_overview.md",
            "notes/length_archive.md",
            "notes/penalty_misc_notes.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Twentieth ChattyPrefix row (iter-196): FOURTH alt-\
               subset on iter-84 IR-BM25 corpus, closing the \
               C(4,3) = 4 survey on the canonical's 4-token vocab. \
               iter-122 + iter-142 + iter-189 + iter-196 = all \
               four 3-term subsets of {bm25, saturation, length, \
               penalty}. iter-196 is the only one that DROPS the \
               'bm25' token — proves strip-robust isn't keyed to \
               the topic-anchor token either. Long-stuffed decoy \
               saturation_stuffed_decoy.md has only 'saturation', \
               no 'length', no 'penalty' — AND-on-3 blocks it. \
               Brings ChattyPrefix to depth 20 alongside \
               Adversarial, SignalOnly, Synthesis, Paraphrase. \
               Zero new seeds.",
    },
    FVaultRecallRow {
        // 19th ChattyPrefix row (iter-189): third alt-signal-
        // subset on iter-84 IR-BM25 corpus. iter-122 surveys
        // {bm25, saturation, length}; iter-142 {bm25, length,
        // penalty}; iter-189 {bm25, saturation, penalty} — three
        // of the C(4,3) = 4 possible 3-term subsets on the
        // canonical's {bm25, saturation, length, penalty} vocab.
        // Zero new seeds.
        query: "Show me my bm25 saturation penalty notes",
        expected_paths: &["notes/bm25_saturation_length_penalty.md"],
        forbidden_paths: &[
            "notes/bm25_overview.md",
            "notes/length_archive.md",
            "notes/penalty_misc_notes.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Nineteenth ChattyPrefix row (iter-189): third alt-\
               subset on iter-84 IR-BM25 corpus. iter-122 + \
               iter-142 + iter-189 = three of the C(4,3) = 4 \
               possible 3-term signal subsets on the canonical's \
               4-token vocab. Same wrapper shape as iter-122/142 \
               (imperative \"Show me my X notes\") so the only \
               variable is the signal subset — proves strip-\
               robust isn't keyed to a specific 3-term slice. \
               Zero new seeds.",
    },
    FVaultRecallRow {
        // 10th ChattyPrefix row (iter-122): BM25-saturation/IR-
        // ranking signal domain — 9th distinct signal universe.
        // Reuses iter-84's seed corpus entirely (zero new seeds).
        // Survivors after strip_query_chatter: {bm25, saturation,
        // length} — 3 terms triggers AND-conjunction. Only
        // iter-84 canonical carries all three; the 3 iter-84
        // single-term-or-stuffed decoys are blocked by AND.
        query: "Show me my bm25 saturation length notes",
        expected_paths: &["notes/bm25_saturation_length_penalty.md"],
        forbidden_paths: &[
            "notes/bm25_overview.md",
            "notes/length_archive.md",
            "notes/penalty_misc_notes.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Tenth ChattyPrefix row (iter-122): BM25-saturation/\
               IR-ranking signal domain — 9th distinct lexical \
               universe. Chatter prefix {Show, me, my} + chatter \
               suffix {notes}; survivors {bm25, saturation, \
               length} — 3 surviving terms triggers AND-\
               conjunction. Reuses iter-84's seeded canonical + \
               3 partial-overlap decoys. Together iters 2/31/47/ \
               71/82/92/98/105/113/122 cover 10 chatter shapes × \
               9 signal domains (residency-governance × 2 + \
               tier-compression + agent-runtime + storage/vault \
               + Metal-compute + MLX-Swift + IR-BM25 + wh+about \
               × 2).",
    },
    FVaultRecallRow {
        // 15th ChattyPrefix row (iter-161): 2-term-AND survivors
        // in Mamba SSM signal domain. iter-134 surveys 3-term
        // survivors {Mamba, SSM, cache}; iter-161 surveys 2-term
        // survivors {mamba, ssm}. Tests strip-robust at the
        // 2-term boundary in a fifth distinct signal domain
        // (alongside iter-127 agent-runtime, iter-128 Synthesis,
        // iter-148 Metal). Zero new seeds.
        query: "Show me my mamba ssm notes",
        expected_paths: &["notes/mamba_ssm_cache.md"],
        forbidden_paths: &["notes/generic_attention_overview.md"],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Fifteenth ChattyPrefix row (iter-161): 2-term-AND \
               survivors in Mamba SSM signal domain. iter-134 \
               uses 3-term survivors on the same canonical; \
               iter-161 shrinks to 2-term {mamba, ssm}. Tests \
               strip-robust at the 2-term boundary across 5 \
               domains (agent-runtime iter-127, Metal iter-148, \
               Mamba iter-161). Zero new seeds.",
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
        // 14th ChattyPrefix row (iter-148): 2-term-AND-survivors
        // in Metal-compute domain. After strip_query_chatter,
        // only {metal, pipeline} remain (2 terms → AND). iter-91
        // canonical and iter-95 partner both carry metal +
        // pipeline; single-term iter-91 decoys blocked. Tests
        // strip-robust at 2-term boundary in a fourth domain
        // alongside iter-127 (agent-runtime), iter-128 boundary
        // mirror (Synthesis), and iter-122/142 alt-subset
        // boundary tests. Zero new seeds.
        query: "What about my metal pipeline notes",
        expected_paths: &["notes/metal_compute_shader_kernel.md"],
        forbidden_paths: &["notes/metal_archive.md"],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Fourteenth ChattyPrefix row (iter-148): 2-term-AND \
               survivors in Metal-compute domain. Chatter wrapper \
               {What, about, my, notes} + survivors {metal, \
               pipeline}. iter-91 canonical and iter-95 pair-\
               partner both carry the 2 surviving terms (both \
               match AND); single-term iter-91 decoys (metal_\
               archive = metal only; compute_brainstorm has \
               neither; shader_misc_notes has neither) blocked. \
               Tests strip-robust at the 2-term boundary in a \
               fourth signal domain (iter-127 agent-runtime, \
               iter-128 Synthesis boundary, iter-148 Metal).",
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
        // 10th Adversarial row (iter-120): 6-term Adversarial —
        // longer-query robustness pin. Reuses iter-43 + iter-75
        // corpora; zero new seeds. All prior Adversarial rows use
        // 4-term OR; iter-120 tests 6-term OR. Canonical
        // (notes/agent_runtime_v2_substrate.md) carries all 6 of
        // {agent, runtime, substrate, trace, canon, invader};
        // iter-75 partner carries 4/6 (no trace, no invader);
        // single-term decoys 1-2/6 each. BM25 with 6 IDF
        // contributions to canonical wins decisively at top_n=1.
        query: "agent runtime substrate trace canon invader",
        expected_paths: &["notes/agent_runtime_v2_substrate.md"],
        forbidden_paths: &[
            "notes/agent_brainstorm.md",
            "notes/runtime_old_design.md",
            "notes/substrate_concepts.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Tenth Adversarial row (iter-120): 6-term query — \
               pins BM25 robustness with many-term OR-conjunction \
               (all prior Adversarial rows use 4 terms; this row \
               extends to 6). Canonical's 6/6 coverage \
               accumulates 6 IDF contributions; iter-75 partner \
               at 4/6 ranks #2; single-term decoys at 1-2/6 don't \
               threaten top_n=1. Demonstrates that the BM25 \
               ranking discrimination scales with query length — \
               more query terms means MORE BM25 signal advantage \
               for the canonical, not less. Zero new seeds.",
    },
    FVaultRecallRow {
        // 18th Adversarial row (iter-180): vault alt-query using
        // EXCLUSIVELY non-primary tokens. iter-66/130/150 all
        // included at least one of vault/tantivy. iter-180 drops
        // both: {reload, index, reader, visibility} are all
        // secondary tokens from the canonical's body. Tests BM25
        // discrimination when the query carries NONE of the
        // canonical's primary identifier vocabulary.
        query: "reload index reader visibility",
        expected_paths: &["notes/vault_index_reload_canon.md"],
        forbidden_paths: &[
            "notes/vault_brainstorm.md",
            "notes/old_index_design.md",
            "notes/tantivy_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Eighteenth Adversarial row (iter-180): vault alt-\
               query using EXCLUSIVELY non-primary tokens. \
               iter-66/130/150 all included vault or tantivy; \
               iter-180 drops both. {reload, index, reader, \
               visibility} all come from the canonical body's \
               secondary vocabulary. Tests BM25 discrimination \
               when the query carries NONE of the canonical's \
               primary-keyword tokens — only its incidental \
               implementation context. Canonical's 4/4 coverage \
               on these secondary tokens wins. Zero new seeds.",
    },
    FVaultRecallRow {
        // 27th Adversarial row (iter-244): agent-runtime alt-
        // query {agent, system, invader, canon} — drops 3 of 4
        // canonical primaries (runtime + substrate + trace) and
        // adds 3 secondaries (system + invader + canon). Reuses
        // iter-43 canonical AND iter-75 pair-partner: iter-43 has
        // all 4 (including the unique "invader" token); iter-75
        // partner has 3 of 4 (lacks "invader"). 4-term OR matches
        // both pair-partners but BM25 ranks iter-43 first (4/4
        // saturated > 3/4). Second Adversarial row that pins
        // canonical-wins-over-pair-partner discrimination (after
        // iter-199 Metal) — different pair, different
        // discriminating token. Pins BM25 ranking when query
        // exploits a UNIQUE token within an otherwise-shared
        // pair vocabulary.
        query: "agent system invader canon",
        expected_paths: &["notes/agent_runtime_v2_substrate.md"],
        forbidden_paths: &[
            "notes/agent_runtime_substrate_v3.md",
            "notes/agent_brainstorm.md",
            "notes/runtime_old_design.md",
            "notes/substrate_concepts.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Twenty-seventh Adversarial row (iter-244): agent-\
               runtime alt-query exploiting unique \"invader\" \
               token. Drops 3 of 4 primaries; iter-43 canonical \
               has all 4 (incl. invader); iter-75 partner has \
               only 3 of 4 (lacks invader). BM25 ranks iter-43 \
               first by saturated-contribution accumulation. \
               Second canonical-vs-pair-partner discrimination \
               Adversarial row (after iter-199 Metal). Brings \
               Adversarial to depth 27. Zero new seeds.",
    },
    FVaultRecallRow {
        // 26th Adversarial row (iter-237): MLX-Swift alt-query
        // {swift, inference, model, local} — drops BOTH "mlx"
        // and "backend" primaries, keeps swift + inference,
        // adds model + local from pipeline-context tail. Third
        // MLX-Swift Adversarial row alongside iter-100 (all 4
        // primaries) and iter-207 (swift+inference+backend+model
        // — drops mlx only). Demonstrates BM25 ranking holds
        // across a 2-of-4-primaries-dropped configuration on
        // MLX-Swift (parallel to iter-222 on graph-event).
        // Canonical has all 4; mlx_archive has 0 of 4;
        // swift_brainstorm + inference_misc_notes each have 1
        // of 4.
        query: "swift inference model local",
        expected_paths: &["notes/mlx_swift_inference_backend.md"],
        forbidden_paths: &[
            "notes/mlx_archive.md",
            "notes/swift_brainstorm.md",
            "notes/inference_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Twenty-sixth Adversarial row (iter-237): MLX-\
               Swift alt-query \"swift inference model local\" \
               drops 2 of 4 primaries (mlx + backend), keeps 2 \
               (swift + inference), adds 2 context tokens \
               (model + local). Third MLX-Swift row: iter-100 \
               (4/4 primaries), iter-207 (3/4 primaries + 1 \
               context), iter-237 (2/4 primaries + 2 context). \
               Together they pin BM25 ranking across the \
               full 4/4 → 3/4 → 2/4 primary-coverage spectrum \
               on MLX-Swift, parallel to graph-event's 4/4 → \
               3/4 → 2/4 coverage on iter-27/185/222. Brings \
               Adversarial to depth 26. Zero new seeds.",
    },
    FVaultRecallRow {
        // 25th Adversarial row (iter-230): vault-canon alt-query
        // mixing 1 primary token (tantivy) + 3 implementation
        // tokens (reader, visibility, vaultstore). SIXTH vault-
        // corpus Adversarial row exercising iter-66 canonical
        // from distinct angles: iter-66 (all 4 primaries),
        // iter-130 (vault+reader+visibility+tantivy), iter-150
        // (vault+tantivy+impl mix), iter-180 (non-primary only),
        // iter-192 (vault+3-impl), iter-230 (tantivy+3-impl).
        // Canonical has all 4 of {tantivy, reader, visibility,
        // vaultstore}; tantivy_misc_notes has tantivy only;
        // vault_brainstorm + old_index_design have 0 of 4.
        // Demonstrates BM25 ranking discrimination scales across
        // both primary↔implementation drop axes on vault corpus.
        query: "tantivy reader visibility vaultstore",
        expected_paths: &["notes/vault_index_reload_canon.md"],
        forbidden_paths: &[
            "notes/vault_brainstorm.md",
            "notes/old_index_design.md",
            "notes/tantivy_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Twenty-fifth Adversarial row (iter-230): vault \
               alt-query \"tantivy reader visibility \
               vaultstore\". Sixth Adversarial row on vault \
               corpus — drops \"vault\" primary while keeping \
               \"tantivy\" primary + 3 implementation tokens. \
               Symmetric counterpart to iter-192 (vault + 3-\
               impl): iter-192 keeps vault drops tantivy, \
               iter-230 keeps tantivy drops vault. Together they \
               prove BM25 ranking holds across BOTH possible \
               single-primary-retention configurations on vault \
               corpus. Brings Adversarial to depth 25. Zero new \
               seeds.",
    },
    FVaultRecallRow {
        // 24th Adversarial row (iter-222): graph-event alt-query
        // dropping BOTH "graph" + "node" primaries — {event,
        // update, session, log}. iter-27 used all 4 primaries
        // {graph, node, update, event}; iter-135 dropped 2
        // primaries (update/event), kept 2 (graph/node), added
        // {session, log}; iter-185 dropped 1 primary (graph),
        // kept 3 + adds; iter-222 drops 2 primaries (graph + node)
        // — most stringent of the alt-queries. Canonical has all
        // 4 query tokens; decoys graph_brainstorm + old_node_
        // design have 0 of 4; event_archive has 1 of 4. Tests
        // BM25 ranking when fully half the canonical's primary
        // vocabulary is unavailable.
        query: "event update session log",
        expected_paths: &["notes/canonical_graph_event_v3.md"],
        forbidden_paths: &[
            "notes/graph_brainstorm.md",
            "notes/old_node_design.md",
            "notes/event_archive.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Twenty-fourth Adversarial row (iter-222): graph-\
               event alt-query dropping BOTH graph + node \
               primaries (\"event update session log\"). 4 of 7 \
               graph-event Adversarial rows now exercise the \
               iter-27 canonical from distinct primary-coverage \
               angles: iter-27 (4/4 primaries), iter-135 (2/4 + \
               2 tail), iter-185 (3/4 + 1 tail), iter-222 (2/4 \
               + 2 tail with BOTH non-tail primaries dropped). \
               Tests BM25 ranking with half the canonical's \
               primary vocabulary missing from query. Brings \
               Adversarial to depth 24. Zero new seeds.",
    },
    FVaultRecallRow {
        // 23rd Adversarial row (iter-215): Apple-Metal alt-query
        // dropping "compute" primary in favor of "metal" primary.
        // {metal, shader, kernel, pipeline}. Reuses iter-91
        // canonical (has all 4: metal×3, shader×3, kernel×3,
        // pipeline×1) and iter-95 pair-partner (has metal×2,
        // pipeline×2 — 2 of 4). Distinct from iter-199 which
        // dropped "metal" instead of "compute" — together iter-
        // 199 + iter-215 prove BM25 ranking discrimination scales
        // across BOTH primary-token-drops on the same canonical.
        // Now 3 Adversarial rows on Metal corpus: iter-91 (all 4
        // primaries), iter-163 (drops "metal"), iter-199 (drops
        // "compute" + pair-partner forbid), iter-215 (drops
        // "compute" + pair-partner forbid, alternate mix).
        query: "metal shader kernel pipeline",
        expected_paths: &["notes/metal_compute_shader_kernel.md"],
        forbidden_paths: &[
            "notes/metal_compute_pipeline_v2.md",
            "notes/metal_archive.md",
            "notes/compute_brainstorm.md",
            "notes/shader_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Twenty-third Adversarial row (iter-215): Apple-\
               Metal alt-query \"metal shader kernel pipeline\". \
               Drops \"compute\" primary while keeping \"metal\" \
               primary — opposite primary-drop axis from iter-\
               199. Together iter-199 (drops metal) + iter-215 \
               (drops compute) prove BM25 ranking discrimination \
               holds across BOTH possible primary-token drops on \
               the same canonical. compute_brainstorm decoy has \
               0 of 4 query terms (does not appear in result \
               set at all) — first Adversarial row with a 0-of-\
               4-match decoy. Brings Adversarial to depth 23. \
               Zero new seeds.",
    },
    FVaultRecallRow {
        // 22nd Adversarial row (iter-207): MLX-Swift alt-query
        // — {swift, inference, backend, model}. Reuses iter-100
        // canonical mlx_swift_inference_backend.md (carries all 4
        // of swift/inference/backend/model — body has "mlx swift
        // inference backend mlx swift inference backend local
        // model pipeline notes"). Drops "mlx" primary token in
        // favor of "model" secondary token — proves BM25 ranking
        // discrimination holds when query mixes 3 primary +
        // 1 secondary vocab tokens. Decoys (mlx_archive,
        // swift_brainstorm, inference_misc_notes) each carry one
        // primary term; none carry "model". Zero new seeds.
        query: "swift inference backend model",
        expected_paths: &["notes/mlx_swift_inference_backend.md"],
        forbidden_paths: &[
            "notes/mlx_archive.md",
            "notes/swift_brainstorm.md",
            "notes/inference_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Twenty-second Adversarial row (iter-207): MLX-\
               Swift alt-query \"swift inference backend model\". \
               Reuses iter-100 canonical entirely. Drops the \"mlx\" \
               primary token in favor of the secondary \"model\" \
               token from the canonical's pipeline-context tail. \
               Demonstrates BM25 ranking discrimination scales \
               across the primary↔context vocabulary boundary on \
               MLX-Swift corpus the same way iter-180 demonstrated \
               it on vault-canon corpus. Second MLX-Swift Adversarial \
               row (alongside iter-100). Brings Adversarial to depth \
               22. Zero new seeds.",
    },
    FVaultRecallRow {
        // 21st Adversarial row (iter-199): Apple-Metal alt-query
        // — {compute, shader, kernel, pipeline}. Reuses iter-91
        // canonical (has all four: 3× compute, 3× shader, 3×
        // kernel, 1× pipeline) AND iter-95 pair-partner
        // metal_compute_pipeline_v2.md (has {metal, compute,
        // pipeline} but lacks shader/kernel). 4-term OR-
        // conjunction matches BOTH plus the single-term decoys;
        // BM25 must rank the canonical above the pair-partner in
        // top-1 (the pair-partner has only 2 of 4 query terms
        // and a shorter body). Forbidden set includes the iter-95
        // pair-partner — first Adversarial row that pins canonical-
        // wins-over-pair-partner discrimination. Zero new seeds.
        query: "compute shader kernel pipeline",
        expected_paths: &["notes/metal_compute_shader_kernel.md"],
        forbidden_paths: &[
            "notes/metal_compute_pipeline_v2.md",
            "notes/metal_archive.md",
            "notes/compute_brainstorm.md",
            "notes/shader_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Twenty-first Adversarial row (iter-199): Apple-\
               Metal alt-query \"compute shader kernel pipeline\". \
               Reuses iter-91 canonical (has all 4) AND iter-95 \
               pair-partner metal_compute_pipeline_v2.md (has \
               only {metal, compute, pipeline}; lacks shader and \
               kernel). 4-term OR-conjunction matches both; BM25 \
               must rank canonical above pair-partner in top-1 \
               (4/4 saturated contributions ≫ 2/4). First \
               Adversarial row that pins canonical-wins-over-\
               pair-partner discrimination. Brings Adversarial \
               to depth 21 — first category past the depth-20 \
               horizon. Zero new seeds.",
    },
    FVaultRecallRow {
        // 20th Adversarial row (iter-192): vault alt-query mixing
        // 1 primary token (vault) + 3 implementation tokens
        // (reload, reader, visibility). Five vault-corpus
        // Adversarial rows now exercise the iter-66 canonical
        // from distinct angles: iter-66 (all primary), iter-130
        // (vault+tantivy+2-impl), iter-150 (vault+tantivy+impl
        // mix), iter-180 (non-primary only), iter-192 (vault +
        // 3-impl).
        query: "vault reload reader visibility",
        expected_paths: &["notes/vault_index_reload_canon.md"],
        forbidden_paths: &[
            "notes/vault_brainstorm.md",
            "notes/old_index_design.md",
            "notes/tantivy_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Twentieth Adversarial row (iter-192): vault alt-\
               query \"vault reload reader visibility\". Five \
               Adversarial rows on vault corpus now: iter-66, \
               iter-130, iter-150, iter-180, iter-192. Each \
               uses a different mix of primary vs implementation \
               tokens; canonical's 4/4 coverage wins all five. \
               Demonstrates BM25 ranking is robust across the \
               full primary↔implementation token spectrum. Zero \
               new seeds.",
    },
    FVaultRecallRow {
        // 11th Adversarial row (iter-130): storage/vault domain,
        // alternate 4-term query — exploits internal-implementation
        // tokens (vaultstore, reader, visibility) that the iter-66
        // canonical carries by design. Query "vault reader
        // visibility tantivy" — canonical's content "VaultStore::
        // reload_index Tantivy reader visibility" tokenizes to
        // include reader + visibility as distinct tokens. Reuses
        // iter-66 corpus entirely; zero new seeds. Demonstrates
        // Adversarial robustness when query selects from a doc's
        // implementation-detail vocabulary, not just its primary
        // domain vocabulary.
        query: "vault reader visibility tantivy",
        expected_paths: &["notes/vault_index_reload_canon.md"],
        forbidden_paths: &[
            "notes/vault_brainstorm.md",
            "notes/tantivy_misc_notes.md",
            "notes/old_index_design.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Eleventh Adversarial row (iter-130): storage/vault \
               alt-query reuse. Selects 4 terms from the iter-66 \
               canonical's content — vault + tantivy from the \
               primary domain, reader + visibility from its \
               implementation-detail vocabulary (\"VaultStore::\
               reload_index Tantivy reader visibility\"). Tests \
               BM25 ranking against a query that mixes primary-\
               and implementation-vocabulary tokens. Canonical is \
               the only doc carrying all 4; single-term decoys \
               (vault_brainstorm = vault, tantivy_misc_notes = \
               tantivy, old_index_design = index — 0/4) all rank \
               below top_n = 1. Zero new seeds.",
    },
    FVaultRecallRow {
        // 19th Adversarial row (iter-185): graph-event alt-query
        // drops "graph" primary token. iter-27 + iter-135 + iter-
        // 185 now exercise the graph corpus from three angles:
        // primary 4-term, primary+context mix, and context-only
        // (drops graph identifier). Mirror of iter-160 (MLX),
        // iter-163 (Metal), iter-171 (agent-runtime) — four
        // domains now have an "alt-query without primary
        // identifier" row.
        query: "node update session log",
        expected_paths: &["notes/canonical_graph_event_v3.md"],
        forbidden_paths: &[
            "notes/graph_brainstorm.md",
            "notes/old_node_design.md",
            "notes/event_archive.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Nineteenth Adversarial row (iter-185): graph-event \
               alt-query \"node update session log\" — drops \
               \"graph\" primary token. Fourth domain (MLX \
               iter-160, Metal iter-163, agent-runtime iter-171, \
               graph iter-185) with a missing-primary-token alt-\
               query. Canonical's 4/4 coverage on the remaining \
               primary+context tokens wins; single-term decoys \
               blocked. Zero new seeds.",
    },
    FVaultRecallRow {
        // 12th Adversarial row (iter-135): graph/event domain alt-
        // query mixing primary + non-primary tokens. iter-27 used
        // {graph, node, update, event} — the primary domain
        // vocabulary. iter-135 uses {graph, node, session, log} —
        // 2 primary + 2 from the canonical's embedded context
        // ("session" + "log" appear in the iter-27 canonical body).
        // Reuses iter-27 corpus entirely; zero new seeds.
        query: "graph node session log",
        expected_paths: &["notes/canonical_graph_event_v3.md"],
        forbidden_paths: &[
            "notes/graph_brainstorm.md",
            "notes/old_node_design.md",
            "notes/event_archive.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Twelfth Adversarial row (iter-135): graph/event \
               alt-query mixing primary + non-primary tokens. \
               iter-27 used 4 primary tokens; iter-135 selects 2 \
               primary (graph, node) + 2 context tokens (session, \
               log) that the canonical carries in its body. \
               Demonstrates BM25 ranking is robust when the query \
               mixes the canonical's core domain vocabulary with \
               its incidental/contextual tokens — neither subset \
               by itself dominates. Zero new seeds.",
    },
    FVaultRecallRow {
        // 14th Adversarial row (iter-150): vault alt-query with
        // 2-of-4 partial-overlap competitor. iter-66 used {vault,
        // index, reload, tantivy}; iter-130 used {vault, reader,
        // visibility, tantivy} (1 primary + 3 implementation
        // tokens); iter-150 uses {vault, tantivy, reader, index}
        // — back to 2 primary + 2 implementation. notes/vault_
        // general_index.md (iter-102 PhraseQuery decoy) has 2 of
        // 4 query terms (vault + index), making it a competitor.
        // Canonical's 4/4 with high TFs still wins at top_n=1.
        query: "vault tantivy reader index",
        expected_paths: &["notes/vault_index_reload_canon.md"],
        forbidden_paths: &[
            "notes/vault_brainstorm.md",
            "notes/old_index_design.md",
            "notes/tantivy_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Fourteenth Adversarial row (iter-150): vault alt-\
               query — 2 primary tokens (vault, index) + 2 \
               implementation tokens (reader, tantivy). Tests \
               BM25 discrimination when notes/vault_general_index \
               (iter-102 PhraseQuery decoy) brings 2/4 partial \
               overlap to the candidate pool. Canonical's 4/4 \
               coverage with multiple-rep TFs dominates the \
               2-of-4 competitor. Zero new seeds.",
    },
    FVaultRecallRow {
        // 17th Adversarial row (iter-171): agent-runtime alt-query
        // drops "agent" primary token. Mirror of iter-160 (MLX
        // drops mlx) and iter-163 (Metal drops metal). Three
        // domains now have an "alt-query without primary
        // identifier" row: MLX, Metal, agent-runtime. Tests BM25
        // discrimination when the canonical's most distinctive
        // identifier is absent but other tokens it uniquely
        // carries remain.
        query: "runtime substrate trace canon",
        expected_paths: &["notes/agent_runtime_v2_substrate.md"],
        forbidden_paths: &[
            "notes/agent_brainstorm.md",
            "notes/runtime_old_design.md",
            "notes/substrate_concepts.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Seventeenth Adversarial row (iter-171): agent-\
               runtime alt-query \"runtime substrate trace canon\" \
               — drops \"agent\" primary token. Third domain (MLX \
               iter-160, Metal iter-163, agent-runtime iter-171) \
               with a missing-primary-token alt-query. Tests BM25 \
               robustness when the canonical's most-distinctive \
               identifier is absent. iter-43 canonical's 4/4 \
               coverage with trace+canon (unique to canonical) \
               wins over iter-75 partner's 3/4 (missing trace). \
               Zero new seeds.",
    },
    FVaultRecallRow {
        // 9th Adversarial row (iter-119): agent-runtime domain,
        // alternate 4-term query — reuses iter-43 + iter-75 corpora
        // entirely. Drops "runtime" from iter-43's original query
        // and adds "canon" (which both iter-43 canonical and
        // iter-75 partner carry). Tests BM25 ranking against the
        // 3-of-4 iter-75 partner competitor + 3 single-term
        // iter-43 decoys. Canonical's 4-of-4 coverage with high
        // per-term TFs wins at top_n = 1; the partner doc ranks
        // #2 with 3/4 terms.
        query: "agent substrate trace canon",
        expected_paths: &["notes/agent_runtime_v2_substrate.md"],
        forbidden_paths: &[
            "notes/agent_brainstorm.md",
            "notes/runtime_old_design.md",
            "notes/substrate_concepts.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Ninth Adversarial row (iter-119): agent-runtime \
               corpus, alternate 4-term query (drops \"runtime\", \
               adds \"canon\"). Tests BM25 robustness against a \
               richer competitor pool than iter-43's original \
               4-term row faced: the iter-75 pair-partner now \
               brings 3/4 query terms. Canonical's full 4/4 \
               coverage with TF≈2-3 on each term wins at top_n=1. \
               Zero new seeds. Cross-row safety: iter-43's \
               original top_n=1 contract on \"agent runtime \
               substrate trace\" remains intact (different \
               query); iter-75's top_n=3 Synthesis on \"agent \
               runtime substrate\" still retrieves both pair-\
               partners; iter-118's Synthesis on \"agent runtime \
               canon\" also holds.",
    },
    FVaultRecallRow {
        // 15th Adversarial row (iter-160): MLX-Swift alt-query.
        // Three Adversarial rows now exercise the iter-100 MLX
        // canonical from different angles: iter-100 {mlx, swift,
        // inference, backend}, iter-146 {mlx, local, model,
        // pipeline}, iter-160 {swift, inference, local, model} —
        // drops "mlx" + "backend" + "pipeline", keeps non-mlx
        // primary + context tokens. All-4-terms present only in
        // iter-100 canonical. Zero new seeds.
        query: "swift inference local model",
        expected_paths: &["notes/mlx_swift_inference_backend.md"],
        forbidden_paths: &[
            "notes/mlx_archive.md",
            "notes/swift_brainstorm.md",
            "notes/inference_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Fifteenth Adversarial row (iter-160): MLX-Swift \
               alt-query \"swift inference local model\" — drops \
               \"mlx\" itself from the query while keeping \
               primary + context tokens. Tests BM25 \
               discrimination when the canonical's *most-\
               distinctive* token (mlx) is absent from the query \
               but other tokens that the canonical uniquely \
               carries are present. iter-100/146/160 together \
               survey three distinct 4-term subsets of the \
               canonical's vocabulary.",
    },
    FVaultRecallRow {
        // 16th Adversarial row (iter-163): Metal alt-query that
        // drops the primary token "metal" itself. iter-91 used
        // {metal, compute, shader, kernel}; iter-110 used {metal,
        // kernel, pipeline, shader}; iter-163 uses {compute,
        // shader, kernel, pipeline} — Metal-domain query without
        // the word "metal". Mirror of iter-160 (drops "mlx" from
        // MLX-domain query). Tests BM25 discrimination when the
        // canonical's identifier-token is absent.
        query: "compute shader kernel pipeline",
        expected_paths: &["notes/metal_compute_shader_kernel.md"],
        forbidden_paths: &[
            "notes/metal_archive.md",
            "notes/compute_brainstorm.md",
            "notes/shader_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Sixteenth Adversarial row (iter-163): Metal alt-\
               query without the \"metal\" primary token. Mirror \
               of iter-160 (MLX without \"mlx\"). Three \
               Adversarial rows now exercise the iter-91 \
               canonical from different 4-term angles: iter-91 \
               original + iter-110 alt (drops compute, adds \
               pipeline) + iter-163 alt (drops metal itself). \
               Canonical's 4/4 coverage with TF multi-rep on \
               compute+shader+kernel wins despite iter-95 \
               partner's 2/4 (compute+pipeline). Zero new seeds.",
    },
    FVaultRecallRow {
        // 13th Adversarial row (iter-146): MLX-Swift domain alt-
        // query exploiting non-primary tokens (local, model,
        // pipeline). iter-100 used primary {mlx, swift, inference,
        // backend}; iter-146 uses {mlx, local, model, pipeline} —
        // 1 primary + 3 context tokens from the canonical's "local
        // model pipeline notes" tail. Tests BM25 robustness when
        // 3 of 4 query terms appear only in the canonical (no
        // partial-overlap from decoys).
        query: "mlx local model pipeline",
        expected_paths: &["notes/mlx_swift_inference_backend.md"],
        forbidden_paths: &[
            "notes/mlx_archive.md",
            "notes/swift_brainstorm.md",
            "notes/inference_misc_notes.md",
        ],
        category: FVaultRecallCategory::Adversarial,
        top_n: 1,
        note: "Thirteenth Adversarial row (iter-146): MLX-Swift \
               alt-query exploiting the canonical's context-\
               vocabulary tail. iter-100 surveys primary tokens; \
               iter-146 mixes 1 primary (mlx) + 3 context tokens \
               (local, model, pipeline) from the canonical body. \
               3-of-4 query terms appear ONLY in the canonical \
               among MLX-domain decoys — but \"pipeline\" appears \
               in iter-91/95 Metal canonicals too (1/4 there). \
               Canonical's 4/4 coverage with high TFs still wins \
               at top_n=1. Zero new seeds.",
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
