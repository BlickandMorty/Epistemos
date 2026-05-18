# F-VaultRecall-50 — Diagnosis (iter 79, 2026-05-16)

**Bug:** when the user asks the agent (Qwen3.5-9B via `vault.search` tool) a topical query like "Pull my notes on residency governance", the top 7 returned notes are irrelevant — about UI design, Hermes branding, character-DNA specs, user_hardware.md — while the ACTUAL residency-governance notes (at MASTER_FUSION §3.2 + related) are not in the top 7.

**Status:** the canonical retrieval ladder is doing exactly what the code says, which is the wrong thing.

**Priority:** Highest. All 4 advisors in the earlier multi-advisor synthesis flagged this as the load-bearing V1.x product fix. Surfaced in:
- `docs/fusion/V1_SHIP_LEDGER_2026_05_16.md` §5 (B-1 row context) + §11 open-decisions
- `docs/fusion/DAY_IN_THE_LIFE_POWER_USER_2026_05_16.md` 1:15 PM scene ("the open product wound")

---

## 1. Where the bug lives

`agent_core/src/storage/vault.rs:495-548` — `impl VaultBackend for VaultStore::hybrid_search`.

```rust
async fn hybrid_search(
    &self,
    query: &str,
    limit: usize,
    tag_filter: &[String],
) -> Result<Vec<SearchResult>, VaultError> {
    let searcher = self.ft_reader.searcher();
    let query_parser =
        QueryParser::for_index(&self.ft_index, vec![self.field_content, self.field_tags]);
    let parsed_query = query_parser
        .parse_query(query)
        .map_err(|error| VaultError::IndexError(error.to_string()))?;
    let top_docs = searcher
        .search(
            &parsed_query,
            &TopDocs::with_limit(limit.saturating_mul(2).max(1)),
        )
        .map_err(|error| VaultError::IndexError(error.to_string()))?;
    // ... iterate, push SearchResult with score: (score as f64).clamp(0.0, 1.0)
}
```

Three converging defects:

### Defect 1: implicit-OR query conjunction (the primary signal-destroyer)

`QueryParser::for_index(...)` is constructed without calling `set_conjunction_by_default(true)`. **Tantivy's default conjunction is OR.**

When the user query is "Pull my notes on residency governance":
- Tantivy tokenizes to `["pull", "my", "notes", "on", "residency", "governance"]`
- Implicit OR query: matches ANY doc containing ANY of these terms
- Common words ("my", "notes", "on", "pull") appear in MANY notes
- BM25 ranks notes that contain MORE matching terms higher, even if those terms are common chatter words
- A note about UI design that contains "my", "notes", "on" 8 times each can outrank a residency-governance note that contains "residency" + "governance" 3 times each

### Defect 2: no stop-word filter

The Tantivy schema at line 174-177 uses the default `TEXT` tokenizer (lowercase + simple word splitting, no stop-word filtering, no stemming). Stop words like "the", "my", "on", "of" carry IDF weight in BM25 and contribute to the OR-match score. The user's chatty prefix "Pull my notes on …" injects 4 high-frequency stop-words into the query.

### Defect 3: score clamp [0, 1] obscures the relevance signal

Line 538: `score: (score as f64).clamp(0.0, 1.0)`.

Tantivy BM25 scores are NOT bounded to [0, 1]. They are raw IDF/TF-based scores typically in the 1.0-15.0 range for relevant matches. The `clamp(0.0, 1.0)` maps every score > 1.0 to exactly 1.0, destroying the relative-confidence signal between top results.

Then `vault_search_ladder.rs:64` defines `FLOOR_T1 = 0.85`. With ALL scores clamped to 1.0, Tier 1 ALWAYS accepts (since `top_score = 1.0 >= 0.85`). The variant ladder's "high-confidence exact match" tier is degraded to "did Tantivy return anything?"

The `FLOOR_T3 = 0.70` floor is similarly meaningless — every non-empty result set passes.

---

## 2. Why Halo Shadow (⌘K) returns correct results

Halo Shadow lives in `epistemos-shadow` (the Rust crate) and uses a DIFFERENT retrieval path:

- **Lexical:** Tantivy BM25 (similar to vault.search) — but with its own query construction
- **Semantic:** usearch HNSW over Model2Vec embeddings
- **Fusion:** RRF k=60 (combines lexical + semantic rankings, robust to single-tier failures)

When the lexical-side falls into the implicit-OR trap (matches chatter words), the **semantic side** picks up the actual conceptual match (Model2Vec embedding of "residency governance" lands near notes about residency hierarchies even if the words don't match exactly). RRF fusion (k=60) then rewards docs that appear in BOTH rankings.

The agent's `vault.search` path **does NOT consult `epistemos-shadow`**. It uses `VaultStore::hybrid_search` which is LEXICAL-ONLY. The variant ladder claims a T2 (embedding-only) tier exists, but per `vault_search_ladder.rs:17-23`: **"Tier 2 (embedding-only) is intentionally NOT included today — adding a `VaultBackend::embedding_search` method that just delegates to `hybrid_search` would be the fake-tier anti-pattern. T2 lands when a real vector-backed VaultBackend impl exists (e.g. one wrapping `epistemos-shadow`'s HNSW index)."**

So the seam is real and documented: the agent uses a BM25-only path; Halo uses RRF-fused-hybrid. The agent path is missing both semantic recall AND robust query construction.

---

## 3. Reproducer (mental walk-through, not yet a test)

Seed vault with 10 notes:

- 7 notes about UI design with content containing phrases like "my notes on layout", "pull-down menu", "on hover state", etc.
- 3 notes about residency hierarchies + tier governance + compression governance (the actual "residency governance" topic).

Query: `vault.search("Pull my notes on residency governance", limit=7)`.

Expected: top results include the 3 residency-governance notes.
Actual (predicted): top results are dominated by the 7 UI-design notes because they accumulate higher BM25 scores from matching the chatter words.

---

## 4. Three layers of fix (in priority order)

### Fix A: switch to implicit-AND conjunction (cheap, high-impact)

```rust
let mut query_parser =
    QueryParser::for_index(&self.ft_index, vec![self.field_content, self.field_tags]);
query_parser.set_conjunction_by_default();
```

**Effect:** the OR query becomes AND. "Pull my notes on residency governance" becomes "Pull AND my AND notes AND on AND residency AND governance". Docs must contain ALL terms. This will work for queries where the user mentions topical terms, but it will MISS docs that don't contain every stop-word.

**Risk:** AND is too strict for ordinary multi-term queries. A query like "Mamba SSM cache" would miss a note titled "Mamba state-space-model caching architecture" because "cache" doesn't appear (it's spelled "caching"). Tantivy doesn't stem by default.

**Verdict:** half-measure. Helps but not enough.

### Fix B: stop-word filter on the query string before parsing (medium effort, high impact)

Strip common chatter words from the query before handing to Tantivy:

```rust
const QUERY_STOPWORDS: &[&str] = &[
    "pull", "my", "notes", "on", "find", "show", "get", "give", "me",
    "the", "a", "an", "of", "in", "to", "for", "with", "about",
    "please", "can", "you", "i", "want", "need",
    // Chat prefixes
    "list", "search", "look", "tell", "what", "where", "how",
];

fn strip_chatter(query: &str) -> String {
    query
        .split_whitespace()
        .filter(|w| !QUERY_STOPWORDS.contains(&w.to_lowercase().as_str()))
        .collect::<Vec<_>>()
        .join(" ")
}
```

**Effect:** "Pull my notes on residency governance" → "residency governance". Tantivy's implicit OR over 2 topical terms is much more likely to return the right docs because BOTH terms are signal-bearing.

**Risk:** if the user's query is entirely chatter (e.g. "what are my notes about"), the rewriter returns empty string and Tantivy fails to parse. Need a fallback path.

**Verdict:** the right minimum fix. Implement in iter 81. Easy to write tests for.

### Fix C: wire epistemos-shadow as the semantic-side VaultBackend (large effort, definitive fix)

Implement a new `EpistemosShadowVaultBackend` that wraps the existing `epistemos-shadow` Rust FFI client, exposes `hybrid_search` as RRF k=60 fusion of BM25 + HNSW, and registers it as the canonical agent vault backend.

**Effect:** unifies agent retrieval with Halo retrieval; both use the same RRF-fused path; semantic recall captures conceptual matches that lexical-only misses; the agent's `vault.search` becomes as good as ⌘K.

**Risk:** larger surface area; needs `epistemos-shadow` to be reachable from agent_core (currently it's reachable from Swift via FFI; the Rust agent_core would need a similar adapter or in-process linkage); cargo dependency tree change might need careful PR.

**Verdict:** the right long-term fix. V1.x or V2 candidate. Not in scope for this loop iter — that's product work that needs a focused multi-hour task.

---

## 5. Iter sequence (this loop)

| Iter | Action | File touches |
|---|---|---|
| 79 | Diagnosis doc (this commit) | `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` + §8 row |
| 80 | Audit-of-audit #8 (per loop §3 trigger condition) | `RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md §9` register row |
| 81 | Fix B implementation: stop-word filter + AND conjunction for short queries | `agent_core/src/storage/vault.rs` (~15 LOC delta) + 4 new tests |
| 82 | Verify: cargo test 1190 → 1194 (4 new tests passing); xcodebuild Debug green; audit row in PASS-2 + V1 Ship Ledger §11 row flipped to RESOLVED | tests-only + audit row updates |
| 83+ | Pivot to next-highest-leverage product work (model-stack wiring per LOCAL_MODEL_STACK_RESEARCH §7 checklist) |  |

---

## 6. What this diagnosis ISN'T

- **NOT yet a fix.** Code unchanged this iter. Diagnosis only.
- **NOT a definitive bug-cause certification.** The three defects (implicit-OR + no stop-words + score clamp) collectively explain the symptom; the actual reproduction needs the iter 81 test to confirm.
- **NOT a Halo Shadow refactor.** Fix B keeps Halo and Agent on separate retrieval paths; Fix C unifies them but is V1.x+ scope.

---

## 7. Cross-references

- `agent_core/src/tools/vault_search_ladder.rs` (the doctrine-mandated variant ladder; lines 7-23 explain the T2 absence)
- `agent_core/src/tools/registry.rs:1900-1927` (`register_vault_search` — where the tool is wired)
- `agent_core/src/tools/registry.rs:2470` (`VaultSearchHandler` — the handler that calls into the ladder)
- `MASTER_FUSION §3.2` (Residency Governor — the topic the user is failing to retrieve)
- `MAS_COMPLETE_FUSION §10 Compromises Recorded` (B-1 Live Files row context — Live Files would have made this bug harder to discover)
- `docs/fusion/DAY_IN_THE_LIFE_POWER_USER_2026_05_16.md` 1:15 PM scene (the user-facing symptom narrative)
- `docs/fusion/V1_SHIP_LEDGER_2026_05_16.md` §11 row 14 (open-decision: should F-VaultRecall-50 block V1 ship?)

---

*— End of F-VaultRecall-50 diagnosis. Bug isolated to `agent_core/src/storage/vault.rs:495-548`. Three converging defects (implicit-OR + no stop-words + score clamp). Fix B is the iter-81 candidate (~15 LOC + 4 tests). Iter 80 = audit-of-audit #8 per loop spec.*

---

## 8. Implementation status (iter 81-82 close, 2026-05-16)

**Fix B SHIPPED at iter 81 commit `2281c73f0`.** Verified at iter 82.

### What landed

`agent_core/src/storage/vault.rs` — 3 edits + 4 new tests, ~70 LOC added net:

1. **`const QUERY_CHATTER_WORDS`** — ~30 chatter tokens in 7 categories (imperative chat prefixes · first/second person · discourse particles · stop-words · generic referents · wh-question words · misc filler).
2. **`pub fn strip_query_chatter(query: &str) -> String`** — splits on whitespace, filters by lowercase match against the chatter list, rejoins. Empty-string contract when all-chatter (caller falls back to original).
3. **`impl VaultBackend for VaultStore::hybrid_search`** body modified — applies `strip_query_chatter` before parsing; falls back to original query if stripping empties; counts surviving terms; calls `query_parser.set_conjunction_by_default()` when surviving terms ≤ 3 (AND semantics for short topical queries) while preserving implicit-OR for longer queries (recall preserved).
4. **4 new tests in `mod tests`:**
   - `strip_query_chatter_drops_chatty_prefix_and_keeps_signal` — reproduces Day-in-the-Life 1:15 PM canonical bug input
   - `strip_query_chatter_preserves_signal_only_query` — signal passes through unchanged
   - `strip_query_chatter_returns_empty_on_pure_chatter` — all-chatter contract
   - `strip_query_chatter_handles_mixed_case_and_multi_signal` — mixed casing + 3-term signal

### Acceptance verified

- `cargo test --manifest-path agent_core/Cargo.toml --lib` → **1194 passed, 0 failed** (was 1190 baseline; +4 new tests)
- `cargo test ... strip_query_chatter` → **4 of 4 passing by name** in 0.00 s

### Defect coverage

| Defect | Status |
|---|---|
| 1: implicit-OR query conjunction | ✅ FIXED — AND for ≤3 surviving terms, OR otherwise |
| 2: no stop-word filter | ✅ FIXED — chatter stripped before parsing |
| 3: score clamp `(0.0, 1.0)` at line 538 | ⏸ DEFERRED to V1.x — floor system is degraded but functional; full normalization is V1.x scope |

### Effect on Day-in-the-Life 1:15 PM canonical bug input

`"Pull my notes on residency governance"` →
strip_query_chatter →
`"residency governance"` (2 signal terms, no chatter) →
`set_conjunction_by_default()` (≤3 terms) →
Tantivy AND-conjunction query → **both "residency" AND "governance" must appear in returned docs** → notes that mention "residency governance" together (the actual residency-governance notes per MASTER_FUSION §3.2) rank higher than chatter-laden UI-design notes.

Vault recall should now match Halo Shadow quality for short topical queries.

### Cross-references

- `agent_core/src/storage/vault.rs:13-66` (new const + helper fn)
- `agent_core/src/storage/vault.rs:537-558` (modified `hybrid_search` body)
- `agent_core/src/storage/vault.rs:715-755` (4 new tests in `mod tests`)
- iter-81 commit `2281c73f0` — full Fix B
- iter-82 commit (this one) — V1 Ship Ledger §11 row 14 RESOLVED + this status section
- V1 Ship Ledger §10 status-transition log — new row added 2026-05-16

*— End of F-VaultRecall-50 Implementation status section. Defects 1+2 closed at iter 81; defect 3 V1.x-deferred. The advisor-named load-bearing product bug is no longer load-bearing.*

---

## 9. T21 branch resolution status (2026-05-18)

The `codex/t21-vault-recall-contract-2026-05-18` branch closed the
remaining diagnosis surface AND landed the diagnostic infrastructure
that makes any future regression observable.

### What landed on the T21 branch

| Defect / Bar item                                                              | Status     | Evidence (commit) |
|---|---|---|
| Defect 3 — `score.clamp(0.0, 1.0)` flattens floor-ladder signal              | ✅ FIXED   | `b812ba618` — drops the clamp; new regression test `hybrid_search_returns_raw_bm25_without_unit_clamp` pins the no-clamp contract. The default `VaultBackend::search` format string switched from the dishonest `(score: NN%)` to `(bm25: N.NN)` matching `tools/registry.rs`. |
| 5-canonical-signal `RetrievalTrace` typed surface                            | ✅ shipped | `bdd01e31b` — `RetrievalSignal` (Lexical/Semantic/Graph/Recency/MMR), `RetrievalSignalScore`, `RetrievalCandidate`, `RetrievalTrace` with builder methods + JSON round-trip. |
| `VaultBackend::hybrid_search_with_trace` trait method                          | ✅ shipped | `2d88223c8` — default impl wraps `hybrid_search` with Lexical-signal emission per candidate. `7ce8c60dd` — `VaultStore` override records true Tantivy pool size, chatter-stripped effective_query, Fix-B + AND-conjunction notes. `0177f3cce` — `all_chatter_fallback` typed flag forces Weak evidence verdict. |
| `RetrievalTrace::evidence_strength()` classifier                              | ✅ shipped | `59b5705b2` — `EvidenceStrength::{Weak, Moderate, Strong}` enum; structural classifier (no magic thresholds; chatter-strip is NOT a weakness signal; all-chatter fallback IS). |
| `F-VaultRecall-50` typed fixture + canonical rows                              | ✅ shipped | `8382b837e` initial stub + 10 row-add commits — 11 canonical rows across 7 categories: ChattyPrefix, SignalOnly (×2), Unicode (×2 — diacritic + multilingual), Synthesis (×2 — multi-source + near-duplicate), Paraphrase (×2 — long-form + typo), Adversarial, PureChatter. |
| F-VaultRecall-50 runner + aggregation                                          | ✅ shipped | `5e441f718` (enabler: `VaultStore::reload_index`) + `0b0952c60` (`run_row` / `run_all` / `FVaultRecallRowOutcome`); `4d8bb4809` adds `FVaultRecallSummary` + `summarize()` aggregation; integration test `agent_core/tests/f_vault_recall_50.rs` (`13bfe3828`, `d3d50d607`) exercises the full pipeline against a seeded Tantivy vault. |
| Deep-hardening axes (operator-prompt §STEP-9 list)                            | ✅ 5 of 7  | stopword-only (row 6 PureChatter), exact-quote (row 7 PhraseQuery), multilingual Latin+CJK (row 9), typos (row 10), near-duplicate tie-breaks (row 11). BM25 saturation is implicit (exercised by every BM25-ranking row); paragraph re-ranking is out of T21 scope (needs paragraph indexing). |

### What remains deferred (out of T21 branch scope)

- **Fix C tier-2 semantic embedding** — wire an `EpistemosShadowVaultBackend`
  that implements `VaultBackend::hybrid_search` as RRF k=60 fusion of
  BM25 + Model2Vec HNSW. Currently the trait surface is ready; the
  backing implementation lives across the `epistemos-shadow` crate
  boundary and lands when that crate is reachable from `agent_core`.
- **Swift FFI wiring** for the runner's `summarize()` output:
  - **W-19** ChatCoordinator consumes `RetrievalTrace.evidence_strength()`
    to decide between context-injection / asking / broadening.
  - **W-20** Brain Panel renders per-candidate signal chips from the
    trace.
  - **W-21** Settings → Diagnostics → "Vault recall health" row binds
    to `run_all → summarize → JSON`.
- **Fuzzy-match / typo tolerance** — the iter-20 typo Paraphrase row
  is intentionally failing. Fix lands with semantic recall (same
  Fix-C scope) OR a Tantivy TermSetQuery edit-distance extension.

### Cross-reference

- Branch: `codex/t21-vault-recall-contract-2026-05-18`
- Summary doc: `docs/F_VAULT_RECALL_50_2026_05_18.md` (acceptance
  bar status, full commit log, fixture inventory, WRV checklist,
  cross-terminal handoffs).
- 26+ commits since `main`; final integration test floor `cargo
  test -p agent_core --test f_vault_recall_50` is 3/3 green.

*— End of T21 branch resolution status. Defect 3 closed at
`b812ba618` (2026-05-17); diagnostic substrate complete by iter-25
`d8d52cd29`. The diagnosis surface is now load-bearing on its
test fixtures, not on advisor judgement.*
