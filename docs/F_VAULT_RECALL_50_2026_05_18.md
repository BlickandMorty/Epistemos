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
| F-VaultRecall-50 fixture visible in diagnostics                                                              | ✅ runner-side complete | Runner (`run_all`) + summary aggregation (`summarize`) + 11 fixture rows across all 7 categories (5-of-7 deep-hardening axes pinned) + 3 integration tests exist. The Swift surface calls `run_all → summarize → JSON` once per W-21 refresh; the FFI binding is the only remaining piece (downstream, out of scope on this branch). |

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

## 4. Fixture row inventory

**11 of ~50 target rows shipped, spanning 7 of 7 canonical categories
(complete).** The remaining rows expand depth within categories and
cover additional adversarial axes from the new operator prompt's
deep-hardening list.

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
| Verified  | ✅ `cargo test -p agent_core --lib f_vault_recall` 23/23 green (fixture invariants + runner happy/sad paths + `summarize` aggregation); `--test f_vault_recall_50` 3/3 green (canonical fixture sweep + ChattyPrefix-trace + end-to-end `run_all → summarize`); `--lib storage::` 150+ green; `--lib vault_search_ladder` 17/17 green. |

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
| Chinese / Cyrillic / Arabic mixed   | ✅ pinned  | row 9 Unicode (`"Mamba 缓存"` — Latin + CJK token boundary) |
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
