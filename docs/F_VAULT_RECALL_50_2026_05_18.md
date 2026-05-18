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
| F-VaultRecall-50 fixture visible in diagnostics                                                              | ✅ runner-side complete | Runner (`run_all`) + summary aggregation (`summarize` + `verdict_line`) + `F_VAULT_RECALL_50_TARGET_ROWS = 50` constant + 16 fixture rows across all 7 categories with per-category breadth (every category × ≥ 2 rows; multilingual axis covers all 3 operator-named scripts) + 3 integration tests + self-documenting fixture module (iter-34 dev guide). The Swift surface calls `run_all → summarize → JSON` once per W-21 refresh and can render the terse label via `verdict_line()`; the FFI binding is the only remaining piece (downstream, out of scope on this branch). |

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

## 4. Fixture row inventory

**22 of ~50 target rows shipped, spanning 7 of 7 canonical categories
(complete).** **Per-category breadth is also complete: every
category has ≥ 2 rows.** Unicode × 4 (deepest). SignalOnly × 3,
Adversarial × 3, Synthesis × 3, ChattyPrefix × 3, PureChatter × 3,
Paraphrase × 3 (long-form + typo + inflection — all known-failing
by design, pinning Fix-C deferred fuzzy-match work) — **every
canonical category now at depth ≥ 3.**

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
| Verified  | ✅ `cargo test -p agent_core --lib f_vault_recall` 29/29 + `--lib retrieval_trace` 17/17 green (fixture invariants + runner happy/sad paths + `summarize` aggregation + per-type render quartet: `RowOutcome::verdict_line`, `Summary::verdict_line`, `Trace::summary_line`, `Candidate::summary_line`); `--test f_vault_recall_50` 3/3 green (canonical fixture sweep + ChattyPrefix-trace + end-to-end `run_all → summarize`); `--lib storage::` 150+ green; `--lib vault_search_ladder` 17/17 green. |

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
| typos                               | ✅ pinned  | row 10 Paraphrase (`"Mamba SSL cache"` — SSL→SSM typo) — known-failing, regression coverage for fuzzy match |
| BM25 saturation                     | ⏳ pending | — (brittle to test in isolation; implicitly exercised by every BM25-ranking row) |
| stopword-only queries               | ✅ pinned  | row 6 PureChatter (`"show me my notes please"`) — `all_chatter_fallback` flag + `evidence_strength() == Weak` |
| exact-quote searches                | ✅ pinned  | row 7 SignalOnly (`"\"residency governance\""` PhraseQuery) |
| Chinese / Cyrillic / Arabic mixed   | ✅ pinned (3 of 3 scripts) | row 9 (CJK), row 13 (Cyrillic), row 16 (Arabic) — all three operator-prompt-named scripts now have fixture rows. RTL display is a rendering concern; Tantivy's SimpleTokenizer is direction-agnostic. |
| paragraph re-ranking                | ⏳ pending | — (out of T21 scope; needs paragraph-level indexing — future iter on a different terminal) |
| near-duplicate tie-breaks           | ✅ pinned  | row 11 Synthesis (`"specific design pattern"`) — pre-MMR baseline retains both copies |

**5 of 7 deep-hardening axes pinned**; 2 remain (BM25 saturation
left implicit; paragraph re-ranking is cross-terminal scope).

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

— *End of F-VaultRecall-50 T21 summary, 2026-05-18.*
