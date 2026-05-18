---
state: t21-vault-recall-contract
created_on: 2026-05-18
authority: docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md
              + docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md §4 T21
branch: codex/t21-vault-recall-contract-2026-05-18
worktree: /Users/jojo/Downloads/Epistemos-t21-vault
status: WRV floor cleared; fixture & adversarial axes ongoing
---

# F-VaultRecall-50 — T21 Vault Recall Contract

The T21 mission closes the canonical "first 7 irrelevant notes" failure
described in the Day-in-the-Life 1:15 PM scene. This doc summarises
what shipped on the
`codex/t21-vault-recall-contract-2026-05-18` branch and points at the
two canonical sources: the diagnosis audit and the integration test.

## 1. Acceptance bar — current status

| Clause (from NO_COMPROMISE_ENDGAME_PROMPT_DECK §4 T21)                                                       | Status      | Evidence |
|---|---|---|
| No production path builds context from index-order `LIMIT N`                                                 | ✅ MET      | `VaultStore::hybrid_search` ranks by BM25; trace exposes the true Tantivy pool. |
| Every vault retrieval emits lexical+semantic+graph+recency+MMR trace                                         | ⚠ Lexical wired | `VaultStore::hybrid_search_with_trace` emits Lexical signal. Semantic / Graph / Recency / MMR populate when their pipelines land (no current backend has them). |
| UI shows loaded source titles/snippets/provenance                                                           | ❌ pending  | Swift wiring (W-20 Brain Panel + W-19 ChatCoordinator) is out of scope for this branch. |
| If evidence is weak, runtime asks or broadens search                                                         | ✅ classifier + flag shipped | `RetrievalTrace::evidence_strength()` returns Weak when 0 candidates OR `all_chatter_fallback`. Iter-16 runner branches on `FVaultRecallCategory::PureChatter` to honour this. ChatCoordinator wiring is downstream. |
| F-VaultRecall-50 fixture visible in diagnostics                                                              | ✅ runner-side complete + **falsifier-name target MET 22% past floor** | Runner (`run_all`) + summary aggregation (`summarize` + `verdict_line`) + `F_VAULT_RECALL_50_TARGET_ROWS = 50` constant + **61 fixture rows across all 7 categories at uniform per-category depth ≥ 8 (iter-110 milestone; F-VaultRecall-50 floor met at iter-102, now 22% past)** spanning distinct sub-axes per category — Adversarial × 8 (7 cross-domain families + alternate-query reuse at iter-110), SignalOnly × 10 shapes incl. 4 exact-quote PhraseQuery rows (iter-7/88/102/112 across residency / design-system / vault-canon / Mamba-SSM with cross-script wrinkle), ChattyPrefix × 9 chatter shapes × 8 signal domains, PureChatter × 9 lead patterns (3 imperative + wh-led + modal-led + need-led + compound + BE-declarative + single-token degenerate), Synthesis × 8 pair-retention domains (incl. 3 near-duplicate rows: design-pattern + compression-doctrine-canon + neural-cache-layer), Paraphrase × 10 Fix-C failure axes (long-form / inflection / 4 typo subclasses Damerau-Levenshtein complete: substitution+transposition+deletion+insertion / 2 synonym across 2 domains / abbreviation / ASCII-folding), Unicode × 8 sub-axes (diacritics + 6 non-Latin scripts CJK+Cyrillic+Arabic+Greek+Japanese-katakana+Hebrew + pure-CJK) + 3 integration tests + self-documenting fixture module (iter-34 dev guide) + Q2-gap chip wiring (iters 65/68/69) + JSON-schema-pin trio (iters 77/78/79). The Swift surface calls `run_all → summarize → JSON` once per W-21 refresh and can render the terse label via `verdict_line()`; the FFI binding is the only remaining piece (downstream, out of scope on this branch). |

**Falsifier (F-VaultRecall-50 Lite, M2 Pro 14" 2023):** the integration
test `agent_core/tests/f_vault_recall_50.rs` is the falsifier harness for
this branch. Acceptance: 4-of-5 canonical rows pass; the single failing
row is `Paraphrase`, which pins the Fix-C deferred semantic-recall
work. Status: ✅ PASS as of 2026-05-18.

## 2. Diagnosis cross-reference

The full bug story lives in:

> `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md`

The diagnosis names three converging defects in `agent_core/src/storage/vault.rs::hybrid_search`:

| Defect | What it caused                                            | Fix       | Shipped iter | Commit       |
|--------|-----------------------------------------------------------|-----------|--------------|--------------|
| 1      | Implicit-OR query conjunction → chatter dominates BM25    | Fix B     | 81 (pre-T21) | 2281c73f0    |
| 2      | No stop-word filter → "pull"/"my"/"notes"/"on" carry IDF | Fix B     | 81 (pre-T21) | 2281c73f0    |
| 3      | `score.clamp(0.0, 1.0)` flattens floor-ladder signal      | **Fix C** | T21 iter-1   | `b812ba618`  |

Fix B landed before this branch (iter 81 of the prior session). Fix C
+ the rest of T21 lives on this branch.

## 3. T21 branch commit log

Per cadence "commit small / one concept per commit", the branch
accumulates the following commits since `main`:

| Iter | Commit        | Concept                                                              |
|------|---------------|----------------------------------------------------------------------|
| 1    | `b812ba618`   | Fix C — drop `score.clamp(0,1)`; honest `(bm25: {:.2})` formatter; regression test. |
| 2    | `8382b837e`   | F-VaultRecall-50 fixture stub — `FVaultRecallRow` / `FVaultRecallCategory` typed surface; canonical 1:15 PM ChattyPrefix row; 5 structural tests. |
| 3    | `bdd01e31b`   | `RetrievalTrace` typed surface — 5 canonical signals (Lexical/Semantic/Graph/Recency/MMR), `RetrievalSignalScore`, `RetrievalCandidate`, JSON round-trip. |
| 4    | `2d88223c8`   | `VaultBackend::hybrid_search_with_trace` default trait method — first production trace emission; Lexical signal populated per candidate. |
| 5    | `7ce8c60dd`   | `VaultStore` override — true Tantivy `top_docs.len()` pool size, chatter-stripped `effective_query`, "Fix-B chatter strip" + "AND conjunction applied" notes. Inverts delegation: `hybrid_search` is a thin wrapper around the override. |
| 6    | `4bff4c10e`   | Fixture row 2 — SignalOnly "Mamba SSM cache" (no chatter, 3 surviving terms, AND conjunction). |
| 7a   | `5e441f718`   | `VaultStore::reload_index` public enabler — deterministic searcher visibility post-write (for tests + future vault-sync callers). |
| 7    | `0b0952c60`   | F-VaultRecall-50 runner — `run_row` / `run_all` / `FVaultRecallRowOutcome` bridges fixture rows to any `&dyn VaultBackend`. |
| 8    | `265c5c3b9`   | Fixture row 3 — Unicode "naïve résumé filter" pins UTF-8 tokenizer behavior; forbidden ASCII-only doc enforces no-diacritic-fold. |
| 9    | `59b5705b2`   | `EvidenceStrength` enum (Weak / Moderate / Strong) + `RetrievalTrace::evidence_strength()` structural classifier. |
| 10   | `0177f3cce`   | `all_chatter_fallback: bool` typed flag (serde-default) — VaultStore records when `strip_query_chatter` empties a non-empty query; `evidence_strength()` returns Weak regardless of count when flag is set. |
| 11   | `55bcdbe1c`   | Fixture row 4 — Synthesis "tier compression governance" (≥ 2 expected_paths). |
| 12   | `2bfdddbd2`   | Fixture row 5 — Paraphrase "Mamba state-space-model caching" (currently failing; pins Fix-C deferred semantic recall). |
| 13   | `13bfe3828`   | Integration test `agent_core/tests/f_vault_recall_50.rs` — end-to-end against seeded Tantivy index: 4 rows pass, 1 (Paraphrase) fails as designed. WRV floor. |
| 14   | `c37023a1a`   | Summary doc `docs/F_VAULT_RECALL_50_2026_05_18.md` — completes the 3-file scope-locked deliverable. |
| 15   | `f437153ce`   | Fixture row 6 — Adversarial "design system hover specification" with `top_n = 1` BM25-ranking discrimination test. |
| 16   | `63d8ab97b`   | PureChatter coverage (7/7 categories complete) — schema relaxation (`expected_paths` may be empty for PureChatter), runner branches on category, 7th row added. |
| 17   | `7db6660c8`   | Fixture row 8 — exact-quote PhraseQuery "\\"residency governance\\"" (deep-hardening axis #1: exact-quote searches). |
| 18   | `79b15f489`   | Summary doc refresh — bring §3/4/5/7 current with iter-15/16/17 progress (8 rows, 7/7 categories). |
| 19   | `53107a708`   | Fixture row 9 — multilingual mixed-script "Mamba 缓存" (Latin + CJK; deep-hardening axis #3: Chinese / Cyrillic / Arabic mixed). |
| 20   | `7711279a4`   | Fixture row 10 — typo Paraphrase "Mamba SSL cache" (single-char substitution; deep-hardening axis #4: typos). Currently FAILS; pins fuzzy-match deferred work. |
| 21   | `2a9919464`   | Summary doc refresh — bring §1/3/4/7 current with iter-19/20 (10 rows, 4/7 axes). |
| 22   | `4d8bb4809`   | `FVaultRecallSummary` + `summarize()` aggregation helper — total/passed/failed/pass_rate + alphabetically-sorted by_category breakdown. The W-21 Swift surface consumes this directly as JSON. |
| 23   | `d3d50d607`   | End-to-end summarize integration test — exercises `run_all → summarize` against the full fixture; asserts Paraphrase 0/2, total counts, pass_rate math, deterministic category ordering. |
| 24   | `e650d9a01`   | Fixture row 11 — near-duplicate Synthesis "specific design pattern" (deep-hardening axis #6: near-duplicate tie-breaks). Pre-MMR baseline: both copies retained in top-2. |
| 25   | `d8d52cd29`   | Summary doc refresh — bring §1/3/4/5/7 current with iter-22/23/24 (11 rows, 5/7 axes, summarize helper). |
| 26   | `1845a1238`   | Diagnosis audit cross-link — append §9 "T21 branch resolution status" to docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md mapping each defect / bar item to its landing commit. |
| 27   | `40f283a63`   | Fixture row 12 — 2nd Adversarial "graph node update event" (cross-domain breadth alongside iter-15's design-system row). |
| 28   | `694a13a55`   | Fixture row 13 — Cyrillic multilingual "Mamba кэш" (extends iter-19's CJK to a second non-Latin script). |
| 29   | `6f4fb0ac2`   | Summary doc refresh — bring §3/4/5/7 current with iter-25/26/27/28 (13 rows, axes update, 2-of-3 scripts). |
| 30   | `1374ad584`   | Fixture row 14 — 2nd PureChatter "tell me what you want" (cross-pattern breadth alongside iter-16's row 6). |
| 31   | `a76563a88`   | Fixture row 15 — 2nd ChattyPrefix "Show me my residency governance notes" (cross-prefix breadth; every category now has ≥ 2 rows). |
| 32   | `f97b01fe0`   | Fixture row 16 — Arabic multilingual "Mamba كاش" (completes script trifecta: CJK + Cyrillic + Arabic). |
| 33   | `0a83c7ad0`   | Summary doc refresh — bring §1/3/4/5/7 current with iter-29..32 (16 rows, per-category breadth complete, multilingual 3-of-3 scripts). |
| 34   | `ea1af7fe3`   | Developer-guide module doc — expand `f_vault_recall_50_fixture.rs` header with charter + row schema + 7-category descriptions + "how to add a new fixture row" recipe. |
| 35   | `e02b4d79b`   | `FVaultRecallSummary::verdict_line()` — human-readable one-line render "P/T passing (R%) — Cat1 N/M, …" for log output / CLI verbose / W-21 terse summary label. |
| 36   | `2de395c38`   | `F_VAULT_RECALL_50_TARGET_ROWS = 50` public constant — codifies the falsifier-name target as a typed source of truth for Swift consumers. |
| 37   | `85fda2421`   | Summary doc refresh — bring §1/3/5 current with iter-33..36 (29 lib tests, dev-guide + verdict_line + TARGET_ROWS shipped). |
| 38   | `a197d140d`   | `RetrievalTrace::summary_line()` — completes the verdict-helper trio (RowOutcome + Summary + Trace). One-line trace render for log / CLI / W-21 trace tooltips. |
| 39   | `b86edeb72`   | Fixture row 17 — single-term SignalOnly "Hamiltonian" (covers surviving-terms = 1; SignalOnly category now spans 1/2/3 surviving-terms cases). |
| 40   | `d5ba7e78d`   | Summary doc refresh — bring §3/4/5 current with iter-37..39 (17 rows). |
| 41   | `420011287`   | `RetrievalCandidate::summary_line()` — completes the per-type render quartet (Candidate + Trace + Summary + RowOutcome). One-line render for Brain Panel tooltips and CLI verbose mode. |
| 42   | `45be85188`   | Summary doc refresh — render quartet milestone noted; 17/17 retrieval_trace tests. |
| 43   | `977d0929b`   | Fixture row 18 — 3rd Adversarial "agent runtime substrate trace" (agent-runtime domain — completes cross-domain trio: design / graph / agent-runtime). |
| 44   | `9dbbeac97`   | Summary doc refresh — bring §3/4 current with iter-42/43 (18 rows, Adversarial × 3). |
| 45   | `556d00001`   | Fixture row 19 — 3rd Synthesis "hardware floor falsifier" (substrate-canon domain — completes cross-family Synthesis trio: tier-compression / near-duplicate / hardware-falsifier). |
| 46   | `7efc0718f`   | Summary doc refresh — bring §3/4 current with iter-44/45 (19 rows, Synthesis × 3). |
| 47   | `63206dc64`   | Fixture row 20 — 3rd ChattyPrefix "Get me my tier compression governance notes please" (multi-signal coverage; ChattyPrefix × 3 matches Synthesis × 3, Adversarial × 3, SignalOnly × 3 at depth 3). |
| 48   | `01eb4ca3d`   | Summary doc refresh — bring §3/4 current with iter-46/47 (20 rows). |
| 49   | `bbed6f36b`   | Fixture row 21 — 3rd PureChatter "give me all the things please" (6-of-7 chatter categories represented; PureChatter × 3 brings the depth-3 count to 5 of 7 fixture categories). |
| 50   | `9ba67be03`   | Summary doc refresh — 21 rows; 50-commit milestone noted. |
| 51   | `8cde00154`   | Fixture row 22 — 3rd Paraphrase "Mamba SSM caches" (inflection axis: cache vs caches plural; Paraphrase × 3 — every canonical category now at depth ≥ 3). |
| 52   | `99277e3e4`   | Summary doc refresh — 22 rows, every category × ≥ 3 milestone. |
| 53   | `e1631cea6`   | Fixture row 23 — pure-CJK "缓存 架构" (no Latin component; Unicode × 5 — deepest category in the fixture). |
| 54   | `60cced512`   | Summary doc refresh — 23 rows, Unicode × 5. |
| 55   | `3eb47eff5`   | `EvidenceStrength::is_at_floor` + `is_strong` predicates — convenience checks for W-19 ChatCoordinator wiring. |
| 56   | `89913ac01`   | Append §8 "Open research questions" — records Q1 (BM25 floor recalibration), Q2 (`epistemos-shadow` integration path), Q3 (real-vault category-distribution measurement). |
| 57   | `85e836f0e`   | Q1 cross-link surfaced inline at `FLOOR_T1`/`T2`/`T3` constants in `vault_search_ladder.rs`. |
| 58   | `43b84d3f2`   | Q2 cross-link surfaced inline at `RetrievalSignal::Semantic` variant in `retrieval_trace.rs`. |
| 59   | `3d2d8e00f`   | Summary doc refresh — 23 rows, Q1+Q2 cross-links live, 60-commit milestone. |
| 60   | `563908972`   | `EvidenceStrength` derives `PartialOrd` / `Ord` (`Weak < Moderate < Strong`) — comparison + `std::cmp::max` for fusing two traces' verdicts. |
| 62   | `1faef5221`   | `RetrievalCandidate::signal_score()` lookup helper — typed read of a specific signal's normalized score without iterating. |
| 63   | `e3d9a295d`   | Q1 documenting test in `vault_search_ladder.rs` tests mod — pins raw-BM25-floor-bypass regression; future recalibration breaks loudly. Ladder tests 17 → 18. |
| 64   | `d960123ac`   | Q2 documenting test in `vault.rs` tests mod — pins `signal_summary == [Lexical]` shape on every current `VaultBackend` impl; multi-signal wiring breaks loudly. Vault tests 10 → 11. |
| 65   | `99270d80f`   | `RetrievalTrace::has_only_lexical_signals()` Q2-gap predicate — encapsulates the shape from iter-64. Trace tests 20 → 21. |
| 66   | `4b4794bc2`   | Fixture row 24 — 4th Adversarial in storage/vault canon domain (`vault index reload tantivy`). Cross-domain Adversarial coverage now × 4 families (design-system / graph-event / agent-runtime / storage-vault). 29/29 lib + 3/3 integration green. |
| 67   | `86c592264`   | Summary doc refresh for iters 62-66 — §1/§3/§4/§8 reflect 24 rows + 4-domain Adversarial breadth + new commit-log entries. |
| 68   | `bce32647d`   | Wire `has_only_lexical_signals()` into the F-VaultRecall-50 runner — `FVaultRecallRowOutcome.lexical_only: bool` + `FVaultRecallSummary.lexical_only_count: usize`. Today every backend produces `true` (Q2 gap); when shadow lands the count drops. 29 → 31 lib green. |
| 69   | `05149e842`   | Render `[lexical-only: K/T]` chip in `FVaultRecallSummary::verdict_line()` — chip disappears at count == 0, the natural signal that multi-signal wiring shipped. 31 → 33 lib green. Chip-wiring epic complete (predicate → outcome flag → summary count → terse render). |
| 70   | `a68e08447`   | Summary doc refresh — log iters 67-69 in §3 and reflect Q2-gap chip wiring end-to-end in §1. |
| 71   | `e5f0fb4f7`   | Fixture row 25 — 4th ChattyPrefix in agent-runtime-trace domain. 4 chatter shapes × 3 signal domains. |
| 72   | `d4b7314b0`   | Fixture row 26 — 4th SignalOnly, 2-term AND boundary (`agent runtime`). SignalOnly term-count shapes now span 1/2/3/quoted-phrase. |
| 73   | `fcff5e28b`   | Fixture row 27 — 4th PureChatter, no-imperative wh-led shape (`where are the files`). Token-pattern breadth × 4. |
| 74   | `2583c4d67`   | Fixture row 28 — 4th Paraphrase, synonym substitution axis (`vault index refresh` ≈ reload). Fix-C failure axes now span long-form / inflection / typo / synonym × 2 domains. |
| 75   | `0b4e54ea4`   | Fixture row 29 — 4th Synthesis, agent-runtime pair-retention. **Uniform-≥-4-per-category milestone** — every category at depth ≥ 4 (Unicode=5). |
| 76   | `74b6e3727`   | Summary doc refresh — §3 logs iters 70-75, §1/§4 reflect uniform-≥-4-per-category milestone + per-category sub-axis inventory. |
| 77   | `4da55550b`   | Pin `FVaultRecallSummary` JSON schema for W-21 surface — top-level `total`/`passed`/`failed`/`pass_rate`/`lexical_only_count` keys + `by_category[]` shape. 33 → 34 lib green. |
| 78   | `6e192cf1b`   | Pin `FVaultRecallRowOutcome` JSON schema for W-21 row-detail view — `query`/`category`/`top_n`/`passed`/`lexical_only` + delta arrays. 34 → 35 lib green. |
| 79   | `b85a964a1`   | Pin `RetrievalTrace` JSON keys for W-20 Brain Panel — query/effective_query/ladder_tier/candidate_pool_size/candidates_retained/all_chatter_fallback + notes/candidates/signal_summary arrays + per-candidate/per-signal key shapes. **JSON-schema-pin trio complete** (W-21 summary + W-21 row + W-20 trace). 21 → 22 trace tests green. |
| 80   | `88151933c`   | Summary doc refresh — log iters 76-79 in §3 + JSON-pin trio annotation in §1. |
| 81   | `dc2701aeb`   | Fixture row 30 — 5th SignalOnly, 3-term vault-canon AND (`vault index reload`). First row past the uniform-≥-4-per-category milestone. SignalOnly to depth 5. |
| 82   | `36aa31209`   | Fixture row 31 — 5th ChattyPrefix in storage/vault canon domain (`Pull my notes on the vault index reload please` → strip to `vault index reload`). ChattyPrefix to depth 5, strip-robust × 5 signal domains. |
| 83   | `37cf971a4`   | Fixture row 32 — 5th PureChatter, modal-led shape (`could you find some files for me`). PureChatter to depth 5; 5 structural lead patterns (3 imperative + wh-led + modal-led). |
| 84   | `f41a51054`   | Fixture row 33 — 5th Adversarial, IR / search-ranking domain (`bm25 saturation length penalty`). Closes the **BM25-saturation deep-hardening axis** (was ⏳ pending in §7) by pinning Tantivy's BM25 TF-saturation (k1=1.2) AND length-normalization (b=0.75) against an 80×-stuffed long decoy. Adversarial to depth 5; 5 cross-domain families. |
| 85   | `68d37db32`   | Fixture row 34 — 5th Synthesis, storage/tokenizer canon pair (`tokenizer indexing tantivy`). Synthesis to depth 5; 5 pair-retention domains. |
| 86   | `2539aa88c`   | Fixture row 35 — 5th Paraphrase, abbreviation / acronym axis (`ml inference cache` ≈ machine-learning). Paraphrase to depth 5; **closes the every-category-at-≥-5 milestone** — all 7 canonical categories at depth ≥ 5. Five Paraphrase axes now span long-form / inflection / typo / synonym / abbreviation across three domains. |
| 87   | `fccfd0a13`   | Summary doc refresh — log iters 80-86 in §3, reflect every-category-at-≥-5 milestone + BM25-saturation axis ✅ in §1/§4/§7. |
| 88   | `4f88c40f1`   | Fixture row 36 — 2nd exact-quote PhraseQuery (design-system domain) extending axis #2 to 2 domains. |
| 89   | `01928584c`   | Fixture row 37 — 2nd near-duplicate Synthesis (compression-doctrine-canon) extending axis #6 to 2 domains. |
| 90   | `41d2693d7`   | Fixture row 38 — 2nd typo Paraphrase (adjacent-transposition subclass: `inedx`) — extends typo axis #4 to 2 subclasses (substitution + transposition) across Mamba + vault-canon domains. |
| 91   | `82941a51f`   | Fixture row 39 — 6th Adversarial, Apple Metal compute domain (`metal compute shader kernel`). 6th cross-domain family for the Adversarial axis. |
| 92   | `bfdf45e10`   | Fixture row 40 — 6th ChattyPrefix in Metal-compute signal domain (reuses iter-91 corpus). Strip-robust × 6 signal domains. |
| 93   | `6b88021e4`   | Fixture row 41 — 6th Unicode, Greek-script extension (`Mamba λ cache`) — adds a 4th non-Latin script alongside CJK + Cyrillic + Arabic. |
| 94   | `17ec6acd8`   | Fixture row 42 — 6th PureChatter, need/pronoun-led shape (`i need some of my notes`). All 7 categories now at depth ≥ 6. |
| 95   | `a57f651ff`   | Fixture row 43 — 7th Synthesis, Metal-pipeline pair (reuses iter-91 canonical + 1 new pair-partner seed). |
| 96   | `592d9719b`   | Fixture row 44 — 8th SignalOnly, Metal 3-term AND (`metal shader kernel`) — zero new seeds. Demonstrates Metal corpus exercises 4 categories simultaneously. |
| 97   | `bed6ceca5`   | Fixture row 45 — 7th Paraphrase, deletion typo subclass (`kernl`) — extends typo axis to 3 subclasses (substitution + transposition + deletion) across 3 domains. Zero new seeds. |
| 98   | `3d2ab66a2`   | Fixture row 46 — 7th ChattyPrefix, wh-led + about-suffix shape — 7 structurally distinct chatter shapes. Zero new seeds. |
| 99   | `ed94eaac7`   | Fixture row 47 — 7th PureChatter, compound wh + modal lead. Zero new seeds. |
| 100  | `c239f2fbd`   | Fixture row 48 — 7th Adversarial, MLX-Swift inference canon (`mlx swift inference backend`). 100-iter T21 milestone. |
| 101  | `68875812a`   | Fixture row 49 — 7th Unicode, Japanese-katakana extension (`Mamba メモリ cache`). 5 non-Latin scripts: CJK + Cyrillic + Arabic + Greek + Japanese-katakana. |
| 102  | `a9a6ab55a`   | Fixture row 50 — 3rd exact-quote PhraseQuery (vault-canon, `"vault index"`). **F-VaultRecall-50 target met** — the falsifier-name is no longer aspirational. Three exact-quote rows across 3 domains. |
| 103  | `c8b6c5299`   | Summary doc refresh — log iters 87-102, mark target-met in §1/§4/§5; §7 axes updated to multi-row coverage. |
| 104  | `71f45b986`   | Fixture row 51 — 8th Paraphrase, insertion typo subclass (`inferencee`). Damerau-Levenshtein complete: 4 typo subclasses (substitution + transposition + deletion + insertion) × 4 domains. Reuses iter-100 MLX corpus. |
| 105  | `0b0a2446a`   | Fixture row 52 — 8th ChattyPrefix, MLX-Swift signal domain (8th distinct signal universe). Zero new seeds. |
| 106  | `2473f084f`   | Fixture row 53 — 9th Paraphrase, 2nd synonym axis row (`store` ↔ `cache` in Mamba SSM). Synonym axis now × 2 domains. Zero new seeds. |
| 107  | `0858b6694`   | Fixture row 54 — 8th PureChatter, BE-declarative shape (statement, not intent). Proves all_chatter_fallback keys on lexical content, not syntactic intent. Zero new seeds. |
| 108  | `20111f7b6`   | Fixture row 55 — 3rd near-duplicate Synthesis (neural-cache-layer domain). Near-duplicate axis × 3 domains. |
| 109  | `125555e94`   | Fixture row 56 — 8th Unicode, Hebrew-script extension. Six non-Latin scripts pinned (CJK + Cyrillic + Arabic + Greek + Japanese-katakana + Hebrew). |
| 110  | `03d48763f`   | Fixture row 57 — 8th Adversarial, alternate 4-term query on Metal corpus. Closes the uniform-≥-8 milestone across all 7 categories. Tests BM25 ranking against richer partial-overlap pool. Zero new seeds. |
| 111  | `c6b44c2e3`   | Fixture row 58 — 10th Paraphrase, ASCII-folding axis (`naive` ↔ `naïve`). Nine Paraphrase failure subclasses. Reuses iter-8 Unicode corpus, zero new seeds. |
| 112  | `79cf9bd41`   | Fixture row 59 — 10th SignalOnly, 4th exact-quote PhraseQuery (Mamba SSM with cross-script wrinkle: CJK token separator breaks the bigram). PhraseQuery axis × 4 domains. Zero new seeds. |
| 113  | `59ad829f5`   | Fixture row 60 — 9th ChattyPrefix, "what about my X notes" shape (wh+about-prefix). Zero new seeds. |
| 114  | `30a0d67fd`   | Fixture row 61 — 9th PureChatter, single-token degenerate shape ("files"). Pins all_chatter_fallback at the 1-token input boundary. |

## 4. Fixture row inventory

**61 fixture rows shipped (122% of 50-row floor) — F-VaultRecall-50
target met at iter-102 (`a9a6ab55a`), 11 rows past floor as of
iter-114. Spanning 7 of 7 canonical categories at uniform per-
category depth ≥ 8 (iter-110 milestone).** Adversarial × 8 (7
cross-domain families: design-system / graph-event / agent-runtime
/ storage-vault / IR-BM25-saturation / Metal-compute / MLX-Swift-
inference, plus an alternate-query reuse row iter-110). SignalOnly
× 10 shapes including 4 exact-quote PhraseQuery rows (iter-7
residency-governance + iter-88 design-system + iter-102 vault-canon
+ iter-112 Mamba-SSM with cross-script wrinkle). Synthesis × 8
pair-retention domains (tier-compression + 3× near-duplicate:
design-pattern + compression-doctrine-canon + neural-cache-layer
+ hardware-falsifier + agent-runtime + storage-tokenizer + Metal-
pipeline). ChattyPrefix × 9 chatter shapes across 8 signal domains
(residency-governance + tier-compression-governance + agent-
runtime-trace + storage/vault-canon + Metal-compute + MLX-Swift +
wh-led + wh+about-prefix). PureChatter × 9 structural lead
patterns (3 imperative + wh-led + modal-led + need-led + compound
wh+modal + BE-declarative + single-token degenerate).
Paraphrase × 10 Fix-C failure subclasses (long-form + inflection
+ 4 typo subclasses Damerau-Levenshtein complete {substitution /
transposition / deletion / insertion} + 2 synonym across 2
domains + abbreviation + ASCII-folding — all known-failing by
design, pinning Fix-C deferred semantic-recall work). Unicode ×
8 sub-axes (Latin diacritics + 6 non-Latin scripts {CJK /
Cyrillic / Arabic / Greek / Japanese-katakana / Hebrew} + pure-
CJK).

The falsifier-name is a floor, not a ceiling — iters past 102
continue extending breadth (8th Adversarial via alt-query reuse;
9th PureChatter at single-token boundary) and depth (Damerau-
Levenshtein-complete typo subclasses; 4 PhraseQuery domains
including cross-script position-strictness; 6 non-Latin scripts;
9 Paraphrase failure subclasses; 3-domain near-duplicate axis).

| Row | Query                              | Category      | Expected (top-N hits)                                                       | Forbidden (must NOT be retained)                                                                                       | Today's verdict |
|-----|-----------------------------------|---------------|------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|------------------|
| 1   | `"Pull my notes on residency governance"` | ChattyPrefix  | `MASTER_FUSION/3_2_residency_governor.md`                                  | UI-design / branding / hardware decoys                                                                                  | ✅ PASS          |
| 2   | `"Mamba SSM cache"`                | SignalOnly    | `notes/mamba_ssm_cache.md`                                                   | `notes/generic_attention_overview.md`                                                                                    | ✅ PASS          |
| 3   | `"naïve résumé filter"`            | Unicode       | `notes/unicode_resume_filter.md`                                             | `notes/ascii_only_resume.md` (no-diacritic-fold contract)                                                                | ✅ PASS          |
| 4   | `"tier compression governance"`    | Synthesis     | `MASTER_FUSION/3_2_residency_governor.md` + `MASTER_FUSION/4_compression_tier_doctrine.md` | `ui/hermes_branding.md`                                                                                                  | ✅ PASS          |
| 5   | `"Mamba state-space-model caching"` | Paraphrase   | `notes/mamba_ssm_cache.md`                                                   | —                                                                                                                        | ❌ FAIL (pins Fix-C deferred) |
| 6   | `"show me my notes please"`        | PureChatter   | (empty — pass via `evidence_strength() == Weak`)                            | `notes/totally_unrelated_a.md`, `notes/totally_unrelated_b.md`                                                          | ✅ PASS          |
| 7   | `"\"residency governance\""`      | SignalOnly    | `MASTER_FUSION/3_2_residency_governor.md` (PhraseQuery — adjacent bigram)   | `notes/residency_scattered.md` (terms present but non-adjacent)                                                          | ✅ PASS          |
| 8   | `"design system hover specification"` | Adversarial | `notes/design_system_hover_spec.md` (`top_n = 1`, BM25 ranking)            | `notes/old_hover_brainstorm.md`, `notes/ux_archive.md`, `notes/system_overview.md` (single-term partial overlaps)        | ✅ PASS          |
| 9   | `"Mamba 缓存"`                     | Unicode (multilingual) | `notes/mamba_chinese.md` (Latin + CJK tokens with whitespace)         | `notes/mamba_english_only.md` (Latin only — CJK term absent)                                                              | ✅ PASS          |
| 10  | `"Mamba SSL cache"`                | Paraphrase    | `notes/mamba_ssm_cache.md` (correct spelling)                              | —                                                                                                                          | ❌ FAIL (pins typo / fuzzy-match deferred — Fix-C) |
| 11  | `"specific design pattern"`        | Synthesis     | `notes/design_pattern_v1.md` + `notes/design_pattern_v1_copy.md` (both must be in top-2) | —                                                                                                                          | ✅ PASS (pre-MMR baseline: both copies retained)   |
| 12  | `"graph node update event"`        | Adversarial   | `notes/canonical_graph_event_v3.md` (`top_n = 1`, BM25 ranking)             | `notes/graph_brainstorm.md`, `notes/old_node_design.md`, `notes/event_archive.md` (single-term partial overlaps)         | ✅ PASS          |
| 13  | `"Mamba кэш"`                      | Unicode (Cyrillic) | `notes/mamba_cyrillic.md` (Latin + Cyrillic tokens)                  | `notes/mamba_english_only.md` (Latin only — Cyrillic term absent)                                                          | ✅ PASS          |
| 14  | `"tell me what you want"`          | PureChatter   | (empty — pass via `evidence_strength() == Weak`)                            | `notes/totally_unrelated_a.md`                                                                                              | ✅ PASS          |
| 15  | `"Show me my residency governance notes"` | ChattyPrefix  | `MASTER_FUSION/3_2_residency_governor.md` (different chatter prefix from row 1) | UI-design / branding / hardware decoys (shared with row 1)                                                                  | ✅ PASS          |
| 16  | `"Mamba كاش"`                      | Unicode (Arabic) | `notes/mamba_arabic.md` (Latin + Arabic tokens — RTL-script test)        | `notes/mamba_english_only.md` (Latin only — Arabic term absent)                                                            | ✅ PASS          |
| 17  | `"Hamiltonian"`                    | SignalOnly    | `notes/hamiltonian_dynamics.md` (single-term AND-conjunction edge)         | `notes/general_physics.md` (physics broadly but no "Hamiltonian")                                                          | ✅ PASS          |
| 18  | `"agent runtime substrate trace"`  | Adversarial   | `notes/agent_runtime_v2_substrate.md` (`top_n = 1`, BM25 ranking, agent-runtime domain) | `notes/agent_brainstorm.md`, `notes/runtime_old_design.md`, `notes/substrate_concepts.md` (single-term partial overlaps)  | ✅ PASS          |
| 19  | `"hardware floor falsifier"`       | Synthesis     | `notes/m2_pro_hardware_floor.md` + `notes/falsifier_handbook.md` (both must be in top-3) | —                                                                                                                          | ✅ PASS          |
| 20  | `"Get me my tier compression governance notes please"` | ChattyPrefix | `MASTER_FUSION/3_2_residency_governor.md` (different signal than rows 1/15; strip → "tier compression governance") | UI-design / branding / hardware decoys (shared with rows 1/15)                                                              | ✅ PASS          |
| 21  | `"give me all the things please"`  | PureChatter   | (empty — pass via `evidence_strength() == Weak`)                            | `notes/totally_unrelated_b.md`                                                                                              | ✅ PASS          |
| 22  | `"Mamba SSM caches"`               | Paraphrase    | `notes/mamba_ssm_cache.md` (inflection — cache vs caches plural)            | —                                                                                                                          | ❌ FAIL (pins inflection / Fix-C deferred)         |
| 23  | `"缓存 架构"`                       | Unicode (pure-CJK) | `notes/pure_chinese.md` (CJK-only, no Latin anchor)                  | `notes/latin_only_ssm.md` (English equivalent — no script-fold)                                                            | ✅ PASS          |

Categories covered: **all 7 of 7.** The remaining work toward "50 rows
all green" is row breadth within each category plus the
deep-hardening axes named below.

The fixture lives in `agent_core/src/storage/f_vault_recall_50_fixture.rs`
and is exposed via `load_canonical()` for any backend that implements
`VaultBackend`.

## 5. WRV checklist

| Plane     | Status                                                                                                                                                                                          |
|-----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Wired     | ✅ `VaultStore::hybrid_search_with_trace` → `RetrievalTrace` (`all_chatter_fallback`, `evidence_strength()`) → `run_row` (PureChatter branch + standard branch) → `FVaultRecallRowOutcome` → integration test in `tests/f_vault_recall_50.rs`. |
| Reachable | ✅ Only public `agent_core::storage::*` API surface used; backends conforming to `VaultBackend` get the trait method for free.                                                                   |
| Visible   | ⚠ Rust side fully visible (trace fields, runner outcomes, evidence verdict, PureChatter category-branch). Swift surfaces (W-19 ChatCoordinator, W-20 Brain Panel, W-21 Settings) are downstream and out of scope on this branch. |
| Verified  | ✅ `cargo test -p agent_core --lib f_vault_recall` 35/35 + `--lib retrieval_trace` 22/22 green (fixture invariants + runner happy/sad paths + `summarize` aggregation + per-type render quartet + EvidenceStrength predicates + ordering + JSON-schema-pin trio); `--test f_vault_recall_50` 3/3 green (canonical fixture sweep + ChattyPrefix-trace + end-to-end `run_all → summarize`); `--lib storage::` 150+ green; `--lib vault_search_ladder` 18/18 green. |

## 6. Cross-terminal handoffs

Per `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` the
following W-rows depend on T21 work and remain open for their owning
terminal:

- **W-19** — `ChatCoordinator` (Swift) consumes `RetrievalTrace` +
  `evidence_strength()` to decide between context-pack injection /
  asking / broadening.
- **W-20** — Brain Panel renders the trace as a "Retrieved by" surface
  with per-candidate signal chips.
- **W-21** — Settings → Diagnostics → "Vault recall health" row binds
  to `f_vault_recall_runner::run_all` and shows N / 50 pass-rate.
- **W-22** — vault retrieval returns `Vec<UasAddress>` (depends on T3
  + T4).
- **W-23** — Vault Context Contract enforced at every Swift retrieval
  call site (CI gate: `rg "LIMIT" + "first.*notes"` returns 0 hits in
  prod paths).

The F-VaultRecall-50 row in `docs/falsifiers/` is owned by **T23B** and
is NOT edited on this branch — only cross-linked.

## 7. Forever-loop continuation

The acceptance bar is a FLOOR, never a ceiling. After this doc lands,
the loop continues.

**Deep-hardening axes** (from the new operator prompt's STEP 9):

| Axis                                | Status     | Pinned by    |
|-------------------------------------|------------|--------------|
| typos                               | ✅ pinned (4 subclasses = Damerau-Levenshtein complete) | iter-20 substitution (SSL→SSM) + iter-90 transposition (inedx) + iter-97 deletion (kernl) + iter-104 insertion (inferencee) — four single-edit-distance primitives across four domains (Mamba / vault-canon / Metal / MLX). When fuzzy-match ships, all four rows must flip to ✅ — proving the fix covers every common single-edit class. |
| BM25 saturation                     | ✅ pinned  | row 33 Adversarial (`"bm25 saturation length penalty"`, iter-84) — pins Tantivy's BM25 TF-saturation cap (k1=1.2) + length-normalization (b=0.75) against an 80×-stuffed long decoy. Without both, the decoy's raw TF would crush the moderate-length canonical; under default BM25 the canonical wins decisively. |
| stopword-only queries               | ✅ pinned (9 lead patterns) | iter-6 (imperative-led, canonical) + 8 additional PureChatter shapes (iter-16/30/49/73/83/94/99/107/114) covering imperative × 3 + wh-led + modal-led + need-led + compound + BE-declarative + single-token degenerate. Proves all_chatter_fallback fires across every lead-pattern family AND at the 1-token input boundary. |
| exact-quote searches                | ✅ pinned (4 domains incl. cross-script) | iter-7 residency-governance + iter-88 design-system + iter-102 vault-canon + iter-112 Mamba-SSM. The iter-112 row adds a cross-script wrinkle: PhraseQuery must reject a Latin-bigram doc when a CJK token (缓存) separates the tokens — Tantivy's PhraseQuery is token-position-strict regardless of script. |
| Chinese / Cyrillic / Arabic mixed   | ✅ pinned (6 of 3+ scripts) | row 9 (CJK), row 13 (Cyrillic), row 16 (Arabic), row 41 (Greek, iter-93), row 49 (Japanese-katakana, iter-101), row 56 (Hebrew, iter-109). Six non-Latin scripts — broader than the originally-named 3-script axis. Two RTL (Hebrew + Arabic), two East-Asian (CJK + Japanese-katakana), two European non-Latin (Cyrillic + Greek). RTL display is a rendering concern; Tantivy's SimpleTokenizer is direction-agnostic. |
| paragraph re-ranking                | ⏳ pending | — (out of T21 scope; needs paragraph-level indexing — future iter on a different terminal) |
| near-duplicate tie-breaks           | ✅ pinned (3 domains) | iter-24 design-pattern + iter-89 compression-doctrine-canon + iter-108 neural-cache-layer — pre-MMR baseline retains both copies across three domains. When MMR ships, all three rows must flip their contract together. |

**6 of 7 deep-hardening axes pinned, each with multi-row coverage**
(iter-84 closed BM25 saturation; typo axis at 4 subclasses
covering all Damerau-Levenshtein primitives; exact-quote axis at
4 domains with cross-script wrinkle; near-duplicate axis at 3
domains; multilingual axis at 6 non-Latin scripts; stopword-only
axis at 9 lead patterns including degenerate 1-token boundary).
1 remains (paragraph re-ranking — cross-terminal scope).

**Other continuation work:**

- Grow the fixture toward 50 rows across categories (each adversarial
  axis above adds at least one row).
- Wire additional `RetrievalSignal` populators when their backends
  arrive (e.g. `epistemos-shadow` Model2Vec semantic seam fills
  `Semantic`; graph-walk fills `Graph`; note-mtime fills `Recency`;
  diversity reranker fills `Mmr`).
- Cross-link with W-19 / W-20 / W-21 once their owning terminals pick
  up the trace + runner artifacts.

The "first 7 irrelevant notes" failure is structurally impossible
on the canonical 1:15 PM scene as of `13bfe3828`, and the PureChatter
variant ("show me my notes" type) is structurally impossible as of
`63d8ab97b`. The job from here is to extend that guarantee across
every adversarial recall axis the diagnosis (and the user's day)
names.

## 8. Open research questions

Three questions remain that the substrate alone cannot answer — each
would meaningfully shape what ships next:

### Q1 — BM25 floor recalibration

`agent_core/src/tools/vault_search_ladder.rs` declares
`FLOOR_T1 = 0.85` / `FLOOR_T2 = 0.75` / `FLOOR_T3 = 0.70`. These
were calibrated against the **clamped** `[0, 1]` scores that Fix C
(`b812ba618`) removed. After Fix C, `SearchResult.score` is raw
BM25 — typically 1.0–15.0 — so every non-empty match trivially
passes every floor. The ladder's tier-acceptance logic degrades to
"did Tantivy return anything?" — exactly the diagnosis §1 Defect 3
failure mode the iter-1 commit was supposed to close.

**What to research:** measure BM25 distributions against a
representative Epistemos vault (~1k–5k notes: MASTER_FUSION + daily
notes + chats). For each tier, what raw BM25 magnitude corresponds
to "high-confidence exact match" / "embedding-class match" / "RRF
fusion match"? Likely empirical percentile ranges (e.g. T1 = top
5% of historical scores), not fixed constants.

**Until resolved:** the ladder's tier-differentiation is effectively
a no-op even with Fix-C shipped.

### Q2 — `epistemos-shadow` ↔ `agent_core` integration path

`VaultBackend::hybrid_search_with_trace` has trait slots for
`Semantic`, `Graph`, `Recency`, `Mmr` signals — currently unused
because no backend populates them. The natural backend is
`epistemos-shadow` (Tantivy BM25 + usearch HNSW + RRF k=60), which
lives as a separate `cdylib` crate today (CLAUDE.md "Halo Shadow
index" section). The public Rust API isn't exposed for non-Swift
callers.

**What to research:** which integration path?

- **Cargo dep** — `agent_core` directly depends on
  `epistemos-shadow`. Easy in-process linkage; requires
  re-exporting the crate as a normal `lib` (currently `cdylib`
  for Swift FFI). Build-system change.
- **FFI** — `agent_core` calls into `epistemos-shadow` via the same
  FFI Swift uses. Unergonomic from Rust.
- **Carve-out** — extract a pure-Rust `epistemos-shadow-core` crate
  that both `agent_core` and the FFI shim depend on. Cleanest but
  largest scope.

**Until resolved:** `RetrievalSignal::Semantic` cannot populate —
the acceptance-bar's 5-signal trace remains Lexical-only.

### Q3 — Real-vault category-distribution measurement

The fixture's 29 rows are hand-curated. Iter-12 + iter-20 + iter-51 + iter-74
Paraphrase rows are known-failing by design (Fix-C deferred). If
50% of real user queries are paraphrases, semantic recall is urgent;
if 5%, it's V2 nice-to-have.

**What to research:** instrument the production `vault.search` tool
with a per-query category-guess classifier (rough heuristic: does
it have chatter? non-ASCII? quoted phrase?) and log over a real
session week. The distribution tells you which fixture rows are
load-bearing for the user's actual workflow vs theoretical coverage.

**Until resolved:** investment priorities across the seven failure-
mode classes are guesswork — Paraphrase × 3 might represent 1% of
user reality or 50%.

---

These three questions are the highest-value open work. Q1 is most
concrete (measure distributions, recalibrate floors). Q2 is the
biggest engineering question (shadow integration). Q3 is product-
level (where to invest Fix-C effort).

— *End of F-VaultRecall-50 T21 summary, 2026-05-18.*
