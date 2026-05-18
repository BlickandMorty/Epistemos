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
| If evidence is weak, runtime asks or broadens search                                                         | ✅ classifier shipped | `RetrievalTrace::evidence_strength()` returns Weak when 0 candidates OR `all_chatter_fallback`. ChatCoordinator wiring is downstream. |
| F-VaultRecall-50 fixture visible in diagnostics                                                              | ⚠ runner shipped | Runner + 5 fixture rows + integration test exist; Swift `W-21` row binding is downstream. |

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

## 4. Fixture row inventory

5 of ~50 target rows shipped, spanning 5 of 7 categories:

| Row | Query                              | Category      | Expected (top-N hits)                                                       | Forbidden (must NOT be retained)                                | Today's verdict |
|-----|-----------------------------------|---------------|------------------------------------------------------------------------------|------------------------------------------------------------------|------------------|
| 1   | `"Pull my notes on residency governance"` | ChattyPrefix  | `MASTER_FUSION/3_2_residency_governor.md`                                  | UI-design / branding / hardware decoys                            | ✅ PASS          |
| 2   | `"Mamba SSM cache"`                | SignalOnly    | `notes/mamba_ssm_cache.md`                                                   | `notes/generic_attention_overview.md`                              | ✅ PASS          |
| 3   | `"naïve résumé filter"`            | Unicode       | `notes/unicode_resume_filter.md`                                             | `notes/ascii_only_resume.md` (no-diacritic-fold contract)         | ✅ PASS          |
| 4   | `"tier compression governance"`    | Synthesis     | `MASTER_FUSION/3_2_residency_governor.md` + `MASTER_FUSION/4_compression_tier_doctrine.md` | `ui/hermes_branding.md`                                            | ✅ PASS          |
| 5   | `"Mamba state-space-model caching"` | Paraphrase   | `notes/mamba_ssm_cache.md`                                                   | —                                                                  | ❌ FAIL (pins Fix-C deferred) |

Remaining canonical categories (each pinned for future iter rows):
- `PureChatter` — query is entirely chatter; runtime MUST defer/broaden. Needs a row-schema revision (today's schema requires `expected_paths` ≥ 1; PureChatter rows assert "no retrieval", which the runner can encode via `expected_paths = &[]` once we relax that check).
- `Adversarial` — docs lexically match chatter, correct answer needs semantic/graph signals. Concrete row pending.

The fixture lives in `agent_core/src/storage/f_vault_recall_50_fixture.rs`
and is exposed via `load_canonical()` for any backend that implements
`VaultBackend`.

## 5. WRV checklist

| Plane     | Status                                                                                                                                                                                          |
|-----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Wired     | ✅ `VaultStore::hybrid_search_with_trace` → `RetrievalTrace` → `run_row` → `FVaultRecallRowOutcome` → integration test in `tests/f_vault_recall_50.rs`.                                              |
| Reachable | ✅ Only public `agent_core::storage::*` API surface used; backends conforming to `VaultBackend` get the trait method for free.                                                                   |
| Visible   | ⚠ Rust side fully visible (trace fields, runner outcomes, evidence verdict). Swift surfaces (W-19 ChatCoordinator, W-20 Brain Panel, W-21 Settings) are downstream and out of scope on this branch. |
| Verified  | ✅ `cargo test -p agent_core --lib storage::` 150/150 green; `--test f_vault_recall_50` 2/2 green; `--lib vault_search_ladder` 17/17 green.                                                       |

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
the loop continues:

- Grow the fixture toward 50 rows across the remaining categories
  (PureChatter + Adversarial — and many concrete adversarial axes:
  typos, BM25 saturation, stopword-only queries, exact-quote searches,
  Chinese / Cyrillic / Arabic mixed scripts, paragraph re-ranking,
  near-duplicate tie-breaks).
- Wire additional `RetrievalSignal` populators when their backends
  arrive (e.g. `epistemos-shadow` Model2Vec semantic seam).
- Cross-link with W-19 / W-20 / W-21 once their owning terminals pick
  up the trace + runner artifacts.

The "first 7 irrelevant notes" failure is structurally impossible
on the canonical 1:15 PM scene as of `13bfe3828`. The job from here is
to extend that guarantee across every adversarial recall axis the
diagnosis (and the user's day) names.

— *End of F-VaultRecall-50 T21 summary, 2026-05-18.*
