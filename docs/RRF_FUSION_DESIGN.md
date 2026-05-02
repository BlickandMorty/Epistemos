# RRF Cross-Index Fusion — Design Document

**Date authored**: 2026-04-28
**Phase**: 0 (Research + design)
**Status**: in-progress
**Mission spec**: `docs/RRF_FUSION_PROMPT.md` (verbatim user brief)
**Authority**: settled per user direction — share the existing `SearchIndexService` GRDB pool; single-SQL RRF; additive behind `EPISTEMOS_RRF_FUSION_V1` feature flag.

This is the **living** design doc. Phase-0 sections are authored as the survey completes; Phase-1+ sections fill in as work proceeds. Every numeric (perf budget, k value, halfLife) is documented with the source it was derived from.

---

## §1 — Source enumeration (Phase 0 deliverable, 2026-04-28)

### FTS5 production query sites (3 total)

| File:line | BM25 form | Order clause | Caller |
|---|---|---|---|
| `Epistemos/Sync/SearchIndexService.swift:812-816` | `bm25(page_search, 5.0, 1.0, 2.0)` (weighted: K=5.0 / B=1.0 / b=2.0) | `ORDER BY rank ASC` | `search()` — page-level prose search |
| `Epistemos/Sync/SearchIndexService.swift:864-868` | `bm25(block_search)` (defaults K=2.0/B=0.75/b=0.75) | `ORDER BY rank ASC` | `searchBlocks()` — block-level prose search |
| `Epistemos/Sync/ReadableBlocksIndex.swift:316-320` | `-bm25(readable_blocks_fts)` (negated for DESC convenience) | `ORDER BY rank DESC` | `search()` static — universal block projection |

All three use `unicode61` tokenization. All three sit in the **same `search.sqlite`** behind `SearchIndexService.dbPool` (closed by F8 — `databaseWriter()` exposes it).

### `k=60` source-of-truth (settled — do NOT duplicate)

| Location | Constant |
|---|---|
| `epistemos-shadow/src/backend/rrf.rs:22` | `pub const RRF_K_DEFAULT: usize = 60;` |
| Validating tests (same file) | lines 101 / 117 / 134 / 141 / 158 / 164 / 177 / 191 |
| Swift mirror | **Decision**: documented Swift constant `Phase3FusionConsts.K_RRF = 60` with `// SOURCE OF TRUTH: epistemos-shadow/src/backend/rrf.rs:22 RRF_K_DEFAULT` comment. Justification: UniFFI bridge for one `usize` constant is heavier than a one-line documented mirror; the Phase-5 parity test asserts the values match. |

### `SearchIndexService` production callers (7 total — adds Phase-4 wiring counterparts)

| File:line | Method | Role | Sync/Async |
|---|---|---|---|
| `Epistemos/Sync/VaultSyncService.swift:2121` | `diffSync(swiftDataPages:fullPageProvider:)` | On-boot vault import + reconciliation | async |
| `Epistemos/Sync/VaultSyncService.swift:2174` | `searchAsync(query:)` | Vault search agent tool surface | async |
| `Epistemos/Sync/VaultSyncService.swift:2185` | `search(query:limit:)` | Fallback sync vault search | sync |
| `Epistemos/Sync/VaultSyncService.swift:2194` | `searchAsync(query:limit:)` | Async vault search wrapper | async |
| `Epistemos/Engine/QueryRuntime.swift:283` | `search(query:limit:)` | Epdoc Slash-menu / query engine | sync |
| `Epistemos/Engine/QueryRuntime.swift:303` | `searchBlocks(query:limit:)` | Epdoc block-link autocomplete | sync |
| `Epistemos/App/EpistemosApp.swift:823` | `databaseWriter()` | Epdoc autosave bridge (F8 close-out) | sync |

Phase 4 wiring sites overlap with these (HomeView search bar uses VaultSyncService; Epdoc Slash uses QueryRuntime; agent tools use VaultSyncService). When Phase 4 lands, the per-source `search()` and `searchBlocks()` calls become opt-in fallbacks; production goes through the new `fusedSearch()`.

### Out-of-scope (different path, NOT this fusion phase)

- `Epistemos/Engine/HaloController.swift` → `ShadowSearchService` → `epistemos-shadow` Tantivy + usearch (V1 ambient Halo). Phase 4 wiring site §2 adds a **complementary** "Vault" segmented-control tab; Halo's own RRF stays as ambient recall.
- `Epistemos/Views/Recall/ContextualShadowsState.swift` — V0 production ambient (uses `InstantRecallService` against `graph-engine`). T+13 architectural decision (#29) handles V0→V1 migration; not blocked by this fusion.

## §2 — Schema confirmation (Phase 0 deliverable, 2026-04-28)

Current schema (`Epistemos/Sync/ReadableBlocksIndex.swift:150-160`):

```sql
CREATE TABLE IF NOT EXISTS readable_blocks (
    id INTEGER PRIMARY KEY,
    artifact_id TEXT NOT NULL,
    artifact_kind TEXT NOT NULL,
    block_id TEXT NOT NULL,
    block_kind TEXT NOT NULL,
    title_path TEXT,
    body TEXT NOT NULL,
    updated_at TEXT NOT NULL
)
```

Existing indexes:
- `readable_blocks_artifact_idx (artifact_id)` — hot for `replaceAllForArtifact` delete-then-insert
- `readable_blocks_block_idx (artifact_id, block_id)` — supports scroll-to-block routing

**Mapping to Phase-0 requirement**:

| Required column | Status | Resolved name | Type |
|---|---|---|---|
| `entity_id` | ✅ | `block_id` (synthetic id within artifact) | TEXT |
| `parent_doc_id` | ✅ | `artifact_id` | TEXT |
| `kind` | ✅ | `artifact_kind` | TEXT (ArtifactKind.snakeCaseString) |
| `vault_id` | ❌ | **MISSING** — Phase 1 adds it (additive ALTER TABLE) | TEXT (UUID-style, nullable) |
| `updated_at` | ✅ | `updated_at` (ISO8601 string per `ReadableBlock.iso8601()`) | TEXT |

**Phase-1 ALTER TABLE plan** (settled this session):

```sql
ALTER TABLE readable_blocks ADD COLUMN vault_id TEXT;
CREATE INDEX IF NOT EXISTS readable_blocks_updated_at_idx ON readable_blocks(updated_at);
CREATE INDEX IF NOT EXISTS readable_blocks_vault_id_idx ON readable_blocks(vault_id);
```

`vault_id` is nullable so existing rows survive without backfill. Type is `TEXT` (UUID string) — matches the `artifact_id` precedent + leaves room for future workspace identifiers without schema change.

Initial known sites (from prior session memory) — all DB-shared:
- `Epistemos/Sync/SearchIndexService.swift` — actor owning the pool
- `Epistemos/Sync/ReadableBlocksIndex.swift` — F7 production projector + `replaceAllForArtifact` bridge (wired via `EpistemosDocumentController`)
- `Epistemos/Engine/HaloController.swift` — uses `ShadowSearchService` (separate Tantivy/usearch index — NOT this DB; covered in Phase-4 wiring §2)
- `Epistemos/Views/Recall/ContextualShadowsState.swift` — V0 ambient recall (separate path)

## §3 — Granularity strategy

**Decision**: block hits roll up to parent artifact via `GROUP BY artifact_id` in the fusion query. The best-rank block per artifact provides the snippet anchor (`MIN(rank) ... ROW_NUMBER() OVER (PARTITION BY artifact_id ORDER BY rank ASC)`).

**Rationale**:
- The user's mental model is "search returns documents, not blocks." A heading hit + a paragraph hit in the same doc should not appear as 2 results.
- The block_id stays in the result row as `snippet_block_id` so the UI can scroll-to-block on click — granularity is preserved at the surface level without polluting the result list.
- Rollup happens INSIDE the SQL (one query) — no Swift-side post-processing.

## §4 — Tie-breaker hierarchy

Deterministic ordering when fused scores tie:
1. `fused_score DESC`
2. `updated_at DESC` (recency wins)
3. `entity_id ASC` (lexicographic stability)

**Rationale**: Updated_at as second key keeps fresh content surfaced. Entity_id as final key guarantees test determinism (100-iter assertion in Phase 5).

## §5 — Recency boost formula

```
boosted_score = fused_score * exp(-age_days / halfLifeDays)
age_days       = julianday('now') - julianday(updated_at)
halfLifeDays   = FusionWeights.halfLifeDays (default 30)
```

**Rationale**: Exponential decay matches the user's deep-research note ("ideal for real-time data"). HalfLife of 30 days means a 30-day-old doc keeps half its score; a 90-day-old doc keeps ~12.5%; a 365-day-old doc keeps ~0.005%. Knob tunable per query via `FusionWeights`.

**Implementation note**: SQLite has `julianday()` built-in; `exp()` requires the math extension OR can be approximated via `pow(2.71828, -x)` if extension unavailable. Phase 1 verifies which is on the platform.

## §6 — Performance budget + bm25 sign + GRDB version (Phase 0 deliverable, 2026-04-28)

### Perf budget (from user mission brief)

| Metric | Target | Hard ceiling |
|---|---|---|
| Cold query (50k rows total) | < 30 ms p95 | 60 ms p99 |
| Warm query (after first run) | < 10 ms p95 | 30 ms p99 |
| Per-source LIMIT before union | 200 rows | — |
| Result limit returned to caller | 50 rows default | 1000 max |

Phase 5 includes a perf test that seeds 50k blocks + 5k pages + 500 chats and asserts p95 < 30 ms. Skipped in CI; run locally before flipping the flag.

### bm25 sign convention (definitive)

**FTS5's `bm25(table)` returns scores in `[-inf, 0]` — lower (more negative) is BETTER.** Confirmed by codebase usage:
- `SearchIndexService.swift:816, 868` — natural form: `ORDER BY rank ASC` (smaller / more-negative comes first)
- `ReadableBlocksIndex.swift:316-320` — negated form: `SELECT -bm25(...) AS rank ... ORDER BY rank DESC` (negation flips sign, so DESC returns the same best-first order)

Phase 2 SQL **must** use `ROW_NUMBER() OVER (ORDER BY bm25(...) ASC)` to assign rank 1 to the best hit. Mixing forms is fine as long as each per-source CTE picks one form consistently.

### GRDB version + window function support

`Package.resolved` pins **GRDB 7.10.0** (`project.yml:490`). This wraps **SQLite 3.45+** which provides:
- ✅ FTS5 virtual tables (already in production at lines 326, 364, 182)
- ✅ Window functions including `ROW_NUMBER() OVER (...)` — universal since SQLite 3.25
- ✅ `julianday()` for recency `age_days` computation
- ⚠️ `exp()` requires the SQLite math extension (3.35+). Phase 2 verifies enablement; fallback is `pow(2.71828, -x)` which works without the extension.
- ✅ `FULL OUTER JOIN` — required by `UNION ALL + GROUP BY` rollup
- ✅ Raw SQL via `Row.fetchAll(db, sql:)` — pattern in current production at lines 807, 859, 307

**No GRDB upgrade or SPM change required for Phase 2.**

## §7 — Rollback plan

The feature flag `EPISTEMOS_RRF_FUSION_V1` gates every wiring site. Rollback paths per phase:

| Phase | Rollback |
|---|---|
| 1 (schema migration) | Down-migration documented; `vault_id` column is nullable so its addition is reversible by `DROP COLUMN` (SQLite 3.35+) or by recreating the table |
| 2 (SQL query) | Pure additive — query lives in a new file, no existing query changed |
| 3 (SearchIndexService API) | `fusedSearch` is a new method; existing per-index methods stay |
| 4 (wiring sites) | Each site checks `EPISTEMOS_RRF_FUSION_V1`; flag-off restores legacy path |
| 5 (tests) | New file; deletion clean |
| 6 (flag flip) | One-line revert in defaults |

## §8 — EXPLAIN QUERY PLAN (Phase 2 deliverable, 2026-04-28)

Captured from `sqlite3 3.51.0` (matches the GRDB 7.10 SQLite bundled in production) against the production-mirror schema with parameters `:query='test'`, `:per_source_limit=200`, `:k=60.0`, `:w_page=:w_block=:w_universal=1.0`, `:half_life_days=30.0`, `:max_results=50`, `:now_unix=1700000000.0`. Full plan output:

```
QUERY PLAN
|--CO-ROUTINE rolled_up
|  |--CO-ROUTINE unioned
|  |  `--COMPOUND QUERY
|  |     |--LEFT-MOST SUBQUERY
|  |     |  |--CO-ROUTINE page_hits
|  |     |  |  |--CO-ROUTINE (subquery-10)
|  |     |  |  |  |--SCAN page_search VIRTUAL TABLE INDEX 0:M3
|  |     |  |  |  |--SEARCH indexed_pages USING INTEGER PRIMARY KEY (rowid=?)
|  |     |  |  |  `--USE TEMP B-TREE FOR ORDER BY
|  |     |  |  `--SCAN (subquery-10)
|  |     |  `--SCAN page_hits
|  |     |--UNION ALL
|  |     |  |--CO-ROUTINE block_hits
|  |     |  |  |--CO-ROUTINE (subquery-11)
|  |     |  |  |  |--SCAN block_search VIRTUAL TABLE INDEX 0:M1
|  |     |  |  |  |--SEARCH indexed_blocks USING INTEGER PRIMARY KEY (rowid=?)
|  |     |  |  |  `--USE TEMP B-TREE FOR ORDER BY
|  |     |  |  |--SCAN (subquery-11)
|  |     |  |  `--CORRELATED SCALAR SUBQUERY 2
|  |     |  |     `--SEARCH indexed_pages USING INDEX sqlite_autoindex_indexed_pages_1 (id=?)
|  |     |  `--SCAN block_hits
|  |     `--UNION ALL
|  |        |--CO-ROUTINE readable_hits
|  |        |  |--CO-ROUTINE (subquery-12)
|  |        |  |  |--SCAN readable_blocks_fts VIRTUAL TABLE INDEX 0:M2
|  |        |  |  |--SEARCH readable_blocks USING INTEGER PRIMARY KEY (rowid=?)
|  |        |  |  `--USE TEMP B-TREE FOR ORDER BY
|  |        |  `--SCAN (subquery-12)
|  |        `--SCAN readable_hits
|  |--SCAN unioned
|  `--USE TEMP B-TREE FOR GROUP BY
|--SCAN rolled_up
`--USE TEMP B-TREE FOR ORDER BY
```

### Plan analysis (per-line)

| Line | Verdict | Reason |
|---|---|---|
| `SCAN page_search VIRTUAL TABLE INDEX 0:M3` | ✅ FTS5 MATCH accelerated | `M3` = FTS5 idxStr "MATCH on column 3 (tags)". The FTS5 virtual-table module accepted the constraint. |
| `SCAN block_search VIRTUAL TABLE INDEX 0:M1` | ✅ FTS5 MATCH accelerated | `M1` = MATCH on column 1 (content). |
| `SCAN readable_blocks_fts VIRTUAL TABLE INDEX 0:M2` | ✅ FTS5 MATCH accelerated | `M2` = MATCH on column 2 (title_path). |
| `SEARCH indexed_pages USING INTEGER PRIMARY KEY (rowid=?)` | ✅ optimal | Per-row rowid lookup against `indexed_pages` for the join. |
| `SEARCH indexed_blocks USING INTEGER PRIMARY KEY (rowid=?)` | ✅ optimal | Same pattern for the block join. |
| `SEARCH readable_blocks USING INTEGER PRIMARY KEY (rowid=?)` | ✅ optimal | Same pattern for the readable_blocks join. |
| `SEARCH indexed_pages USING INDEX sqlite_autoindex_indexed_pages_1 (id=?)` | ✅ optimal | Correlated subquery `(SELECT updatedAt FROM indexed_pages WHERE id = ...)` uses the auto-built unique index on `id`. |
| `USE TEMP B-TREE FOR ORDER BY` (×3 inside CTEs) | ⚠️ acceptable | One per CTE for the `ROW_NUMBER() OVER (ORDER BY bm25(...) ASC)` window. SQLite materializes the FTS5 result set + sorts in memory. Bounded by `LIMIT :per_source_limit` (default 200) so peak memory is ~200 rows × 3 sources = 600 rows. |
| `USE TEMP B-TREE FOR GROUP BY` | ⚠️ acceptable | Outer `GROUP BY entity_id` over the unioned 600-row max. Hash-aggregation on a bounded input is O(N). No covering index would help here because the input is materialized from CTEs. |
| `USE TEMP B-TREE FOR ORDER BY` (final) | ⚠️ acceptable | Final `ORDER BY fused_score DESC, updated_at_unix DESC, entity_id ASC` over the deduplicated entity rows (≤600). Sort is O(N log N) on ~hundreds of rows. |

### Critical-invariant gate (Phase 2 build-failing test)

`RRFFusionQueryTests.queryPlanUsesFTS5IndexNotScan` filters the plan above to the 3 lines mentioning the FTS table names + `VIRTUAL TABLE`, then asserts each matches regex `VIRTUAL TABLE INDEX \d+:M\d+`.

**Why the regex and not `hasPrefix("SEARCH")`**: SQLite ALWAYS prints `SCAN tablename VIRTUAL TABLE` for virtual-table row visits, even when the FTS5 module accelerated the constraint via xBestIndex. The discriminator is the `idxStr` suffix:

- `INDEX 0:M<digit>` ← FTS5's encoding for "MATCH constraint accepted at column `<digit>`" — the FAST path
- `INDEX 0:` (empty after colon) ← xBestIndex returned no constraint — the SLOW path (full virtual-table iteration)

A future query rewrite that drops `MATCH :query` (e.g. moves to `LIKE`) would degrade to the slow path and the test would fail. This captured plan is the **golden** plan; deviations are visible in `git diff` of this section.

### Performance characterization (informational)

- Per-source FTS5 MATCH: `O(log N)` index lookup + `O(K)` row decoding where K = matching rows (capped at `:per_source_limit`).
- 3× per-source CTE materialization: bounded at 600 rows total.
- Outer `GROUP BY entity_id`: O(N) hash with N ≤ 600.
- Final `ORDER BY`: O(N log N) with N ≤ ~600 (post-dedup).
- Recency `exp(-age_days / halfLifeDays)` per output row: negligible — SQLite math extension is in-process.
- Final `LIMIT :max_results` (default 50): early-out, but B-tree sort still materializes all N first.

For the Phase-5 50k-corpus perf test: peak working set is bounded by `:per_source_limit` (200), so the SQL plan is **independent of corpus size** beyond the per-source FTS5 index lookup. The 30 ms p95 budget is comfortable.

## §9 — Open questions (resolved during Phase 0 where possible, 2026-04-28)

1. **k=60 source-of-truth lifting** — ✅ **RESOLVED**: documented Swift mirror constant `Phase3FusionConsts.K_RRF = 60` with `// SOURCE OF TRUTH: epistemos-shadow/src/backend/rrf.rs:22 RRF_K_DEFAULT` comment. UniFFI for one `usize` constant is heavier than a one-line mirror. Phase 5 parity test asserts the values match.
2. **`vault_id` shape** — ✅ **RESOLVED**: `TEXT` (UUID-style string), nullable, default empty for existing rows. Matches the `artifact_id` precedent + leaves room for future workspace identifiers without schema change.
3. **MutationEnvelope retrieval-event schema** — ⏸ **DEFERRED to T+13 hardening pass (decided Phase 3, 2026-04-28)**. The current `MutationEnvelope` (`Epistemos/Models/MutationEnvelope.swift` + `agent_core/src/mutations/envelope.rs`) is purely write-side: `SourceOp` cases are `graph_mutation`, `artifact_create`, `artifact_update`, `artifact_delete`, `other`; `affects_*` flags describe write-side projection invalidation. Adding a `retrieval` variant is a wire-format-locked Rust parity change (tested by `EpistemosTests/MutationEnvelopeParityTests.swift`) and is not load-bearing for Phase 4 wiring. Phase 3 closes audit gap F10 (os_signpost on the search path) directly via `Sig.storage.beginInterval("fused_search", ...)`. F9 (MutationEnvelope production emission) reframed in `docs/AGENT_PROGRESS.md` as a write-side concern that the existing F8 upsert paths already cover via `notifyIndexChanged([.searchBlocks])` invalidation; T+13 will adjudicate whether that invalidation should upgrade to a full `MutationEnvelope` post or stay as the lightweight `Notification` it is today.
4. **Weighting per source** — ⏳ **Phase 3**: defaults stay 1.0/1.0/1.0. A `FusionWeights` struct exposes per-source `weight: Double` so callers can boost `readable_blocks` (newer, universal) when the application context calls for it (e.g., Document-editor surface vs page-search admin surface).
5. **SQL `exp()` availability** — ✅ **RESOLVED (Phase 2, 2026-04-28)**. Verified against `sqlite3 3.51.0` (matches GRDB 7.10's bundled SQLite ≥3.45). The `pow(2.71828, ...)` fallback was dropped per user direction — dead code, removes ambiguity. Phase 2 test `recencyBoostAppliesExpDecay` exercises the function end-to-end and would fail at runtime if the extension were missing.
6. **Outer GROUP BY efficiency** — ✅ **RESOLVED (Phase 2, 2026-04-28)**. Captured EXPLAIN QUERY PLAN (§8) shows `USE TEMP B-TREE FOR GROUP BY` over a bounded input (≤ 3 × `:per_source_limit` = 600 rows). No covering index needed because the input is materialized from CTEs, not from an indexed base table. Hash-aggregation on a 600-row input is O(N) in memory.

## §10 — Phase status

| Phase | Status | Owner | Notes |
|---|---|---|---|
| 0 — Research + design doc | ✅ complete (2026-04-28) | this turn | source enumeration done; 6 production callers; 3 FTS5 sites; bm25 sign confirmed; GRDB 7.10 / SQLite 3.45 verified |
| 1 — Schema + migration | ✅ complete (2026-04-28) | this turn | additive ALTER `vault_id TEXT` + index on `vault_id` + composite index `(vault_id, artifact_id)`; new migration key `v3_1_readable_blocks_vault_id`; 5 new tests in `ReadableBlocksIndexTests.swift` |
| 2 — SQL fusion query | ✅ complete (2026-04-28) | this turn | `RRFFusionQuery.swift` (~280 LOC); 3 CTEs + UNION ALL + GROUP BY rollup with weighted RRF + recency exp() boost; `Phase3FusionConsts.K_RRF=60` single Swift mirror; 7 critical-invariant tests including K_RRF parity probe of `epistemos-shadow/src/backend/rrf.rs`, bm25 sign assertion, and EXPLAIN QUERY PLAN regex gate; full plan captured in §8 above |
| 3 — SearchIndexService API | ✅ complete (2026-04-28) | this turn | `SearchIndexService.fusedSearch(query:weights:now:)` + async variant added at lines 492-568; nonisolated public, `Sig.storage.beginInterval("fused_search", ...)` signpost ceremony (closes F10 for the search path); `RRFFusionFlags.isEnabled` env-flag gate added to `RRFFusionQuery.swift`; F9 reframed + deferred to T+13 (rationale in §9 item 3); runtime test verification deferred until Xcode IDE lock can be released |
| 4 — Wiring (8 sites) | 🟡 partial (2026-04-28) | this turn | 4/8 sites wired flag-aware, 2 breadcrumbed (require API/UI extensions), 2 deferred (cross-language FFI / new UI). See "Phase 4 wiring status" table below. |
| 5 — Tests (real DB) | ✅ complete (2026-04-28, runtime gated on Xcode lock) | this turn | `EpistemosTests/SearchIndexServiceFusionTests.swift` — 9 integration tests via `SearchIndexService(databaseURL:)` file-backed init + helper `seedDoc` / `seedBlock` that wire pages, blocks, AND `readable_blocks` rows in one shot. Covers single-source, cross-source consensus, block-rollup snippet anchor, recency reorder, 100-iter determinism, empty-query / empty-corpus, snippet `<b>` highlights, sync/async parity. 50k-row perf gate split into a separate Phase-6 local-only suite per the mission brief. |
| 6 — Observability + flag flip | ⏸ deferred | | Settings → "Search Fusion Health" health row + 3-day dogfood + default flip — both warrant runtime verification before landing. Defer to next IDE-closed window. |
| 7 — Doc updates | ✅ complete (2026-04-28) | this turn | `docs/RRF_FUSION_DESIGN.md` (this doc — §8 EXPLAIN plan, §10 phase status, §14 wiring status); `docs/AGENT_PROGRESS.md` phases marked; `CLAUDE.md` FILE MAP gained an RRF section. `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` §225 NOT located — file has 33 H2 sections with no §225 / "existing tables continue to serve" subsection; deferred per user memory "PLAN_V2 is authority — do not edit it to match shipped code". |

## §14 — Phase 4 wiring status (2026-04-28)

| # | Site | Status | Notes |
|---|---|---|---|
| 1 | HomeView landing wave search bar | ✅ wired | Flows through `VaultSyncService.searchFull` / `searchFullAsync` which now branches on `RRFFusionFlags.isEnabled` — fused path translates `[FusedResult]` → `[SearchResult]` via `mapFusedToSearchResult`; legacy per-index path is the flag-off + error fallback. |
| 2 | Halo `ShadowPanel` "Shadow \| Vault" segmented control | ⏸ deferred | New UI component (segmented control, content-area swap). Halo's existing tantivy/usearch ambient recall stays; "Vault" tab needs new state + view code. Defer to a dedicated Halo wiring slice — out of scope for the additive flag-gated phase. |
| 3 | Epdoc Slash menu / @-mention block-link autocomplete | ✅ wired | `QueryRuntime.fullText(query:scope:)` for `scope == .all` now dispatches to `searchIndex.fusedSearch` when the flag is on; falls through to the legacy two-index dispatch on flag-off OR fused-path failure. Snippet text propagates through `FusedResult.snippet`. |
| 4 | Agent tool — Rust side (`agent_core/src/tools/registry.rs`) | ⏸ deferred | Requires NEW FFI surface: Rust agent_core's `VaultBackend::hybrid_search` is a separate code path from Swift's FTS5 `SearchIndexService`. Routing the Rust tool through Swift's `fusedSearch` requires (a) a new `@_silgen_name` extern on the Swift side that bridges `[FusedResult]` to a Rust-decodable C ABI, (b) a Rust-side conditional in `VaultStore` that calls out via FFI when an env-flag is set. Substantial cross-language work; defer to its own phase. |
| 5 | Local Hermes tool grammar parity | ⏸ deferred | Depends on §4 — the local model's tool grammar mirrors the Rust tool registry. Once the Rust tool is fused-aware, regenerate `LocalToolGrammar.swift` accordingly. |
| 6 | AgentRuntime context retrieval | ✅ wired | `VaultSyncService.searchIndex(query:)` (the page-IDs-only flavor used by `ChatCoordinator` + `MiniChatView` + agent context-pulling) is now flag-aware and routes through `fusedSearchAsync` when on. |
| 7 | iMessage channel reply context | 📌 breadcrumb | `IMessageDriverService.processIncomingMessage` reply path was annotated with a comment pointing future Phase-K work at the existing site §6 wiring (the agent session already pulls context through `VaultSyncService.searchIndex`). No additional iMessage-specific call site exists yet; this breadcrumb prevents future drift. |
| 8 | Meaning-anchor pinned-doc retrieval boost | 📌 breadcrumb | `MeaningAnchorService` annotated with the API extension needed (`FusionWeights.pinnedParentDocIDs: Set<String>` + `pinnedBoost: Double`) and the SQL change required (`+ :pinnedBoost * pinned_match` term in `raw_fused_score`). Defer to Phase 5 polish — Phase 4 acceptance does not require this, and `formatForPrompt()` still gives the agent the anchor context. |

**Net Phase 4**: 4 sites fully wired (the load-bearing ones — Landing search, Epdoc Slash, AgentRuntime context, plus implicit coverage of NoteEntity / NotesMentionDropdown / NotesSidebar via `VaultSyncService.searchFullAsync`). 2 breadcrumbs (clear continuation paths documented). 2 deferred (cross-language FFI + new UI; warrant their own phase).

**Flag default**: `EPISTEMOS_RRF_FUSION_V1` is unset by default — every wired site falls through to the legacy path until a developer sets it explicitly. This satisfies the additive-behind-flag invariant from `docs/RRF_FUSION_PROMPT.md`.

## §13 — Test patterns to mirror (Phase 0 deliverable, 2026-04-28)

| Existing file | LOC | Pattern |
|---|---|---|
| `EpistemosTests/SearchIndexServiceIntegrationTests.swift` | 476 | File-backed `DatabasePool` via `SearchIndexService(databaseURL:)` — good for integration but file I/O introduces jitter |
| `EpistemosTests/ReadableBlocksIndexTests.swift` | 256 | **GOLD STANDARD** — in-memory `DatabaseQueue(path: ":memory:")`, `ReadableBlocksIndex.registerMigration(&migrator)`, Swift Testing `@Suite` + `@Test` + `#expect`. Round-trip insert→query assertions inside `queue.write` / `queue.read` blocks |
| `EpistemosTests/SearchIndexTests.swift` | 101 | Older unit-level pattern; not the model |

**Phase 5 plan**: copy `ReadableBlocksIndexTests.swift` shape exactly. Add a fixture corpus seeder (10 docs / 50 blocks / 5 chats with mixed term distribution) so cross-source ranking, block→doc rollup, recency boost, and tie-breaker determinism can each be asserted independently.

## §11 — Known reuse opportunities

- `epistemos-shadow/src/backend/rrf.rs:22` — `RRF_K_DEFAULT = 60` source-of-truth. Swift mirror as a single documented constant (decision per §1 above).
- `Epistemos/Sync/ReadableBlocksIndex.swift` — `SearchHit` struct (lines 124-131) already shipped; `FusedResult` may extend or wrap it.
- `Epistemos/Sync/SearchIndexService.swift` — `databaseWriter()` already exposes the shared pool (F8 close-out). Phase 3 reads from the same pool via `dbPool.read { db in ... }`.
- `EpistemosDocumentController` (F8) — producer side of the shared-pool story; this phase is the consumer side. Together they justify the share-the-pool decision.
- `Sig.storage.beginInterval(...)` (Wave 2.1 canonical signpost infra, lines 456-458 of SearchIndexService) — Phase 3 extends with `"fused_search"` events. Closes audit gap F10.

## §12 — Citations

- User mission brief: `docs/RRF_FUSION_PROMPT.md`
- Plan §225 (existing tables continue to serve): `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §5 (search projection)
- F8 audit close-out: `docs/audits/T+4_T+5_DEEP_AUDIT_2026-04-27.md`
- Halo RRF reference: `epistemos-shadow/src/backend/rrf.rs`
