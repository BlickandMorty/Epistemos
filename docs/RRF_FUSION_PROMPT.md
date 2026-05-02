# RRF Cross-Index Fusion via Single SQL Query — Mission Brief

> **Index status**: CANONICAL-OPERATIONAL — Authoritative mission spec for the cross-index RRF fusion phase. User-authored 2026-04-28; preserved verbatim so future sessions inherit the full context (acceptance criteria, non-negotiables, exact wiring sites, perf budget).
> Companion docs:
> - `docs/RRF_FUSION_DESIGN.md` — phase-by-phase implementation design
> - `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` §225 — sub-section pointer
> - `docs/AGENT_PROGRESS.md` — phase status

## Mission
Implement Reciprocal Rank Fusion across `page_search`, `block_search`, and the new `readable_blocks` table as a SINGLE SQL query inside `SearchIndexService`'s shared GRDB pool. Then wire it into every site in the app where unified search is currently fragmented. Reuse the k=60 constant from the existing Halo RRF — do not re-derive.

## Context — read FIRST, in this order. Do not skip.
1. `CLAUDE.md` (non-negotiable constraints, file map, JS bundle rules, Halo k=60 reference)
2. `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` — find §225 "existing tables continue to serve"
3. `docs/AGENT_PROGRESS.md` — current phase status
4. `Epistemos/Sync/SearchIndexService.swift` — the production actor that owns search.sqlite + FTS5 + DatabasePool
5. `Epistemos/Sync/ReadableBlocksIndex.swift` — the index just shipped by F7
6. `EpistemosTests/SearchIndexServiceIntegrationTests.swift` + `EpistemosTests/ReadableBlocksIndexTests.swift` — existing test patterns to mirror
7. `epistemos-shadow/src/backend/rrf.rs` — the canonical RRF math (k=60), reuse the constant
8. `agent_core/src/storage/vault.rs` + `agent_core/src/tools/registry.rs` — Rust agent's vault search surface
9. `Epistemos/LocalAgent/LocalToolGrammar.swift` + `Epistemos/LocalAgent/HermesPromptBuilder.swift` — local-Hermes tool parity
10. `Epistemos/Views/Halo/ShadowPanel.swift` + `ShadowPanelContent.swift` — UI integration model
11. `docs/audits/DATA_PERSISTENCE_INDEXING_AUDIT.md` — gaps the audit already flagged

DO NOT GUESS file paths. Glob/grep first; verify every symbol exists before referencing it. If a doc says something contradictory to this prompt, surface the contradiction — do not silently override.

## Architectural decisions — SETTLED, do not re-litigate
- Share `SearchIndexService`'s `DatabasePool`. New `readable_blocks` table lives in the SAME `search.sqlite`. Plan §225 ("existing tables continue to serve") authorizes this.
- Single SQL RRF query, no Swift-side merging. The query returns a fused, ordered result set in one round-trip.
- Additive only. Existing per-index queries stay until Phase 6 deprecates them behind a feature flag.
- Feature flag: `EPISTEMOS_RRF_FUSION_V1` — default ON in dev, OFF in MAS until benchmarked.
- k=60 constant comes from `epistemos-shadow::backend::rrf` — DO NOT duplicate, expose it via FFI or mirror as a single Swift constant referencing the Rust source-of-truth in a comment.
- SQLite 3.51 (verified) has window functions; use `ROW_NUMBER() OVER (...)` for ranking.

## Phase 0 — Research + design doc (deliverable: brief + doc updates)
- Grep every existing FTS5 query, every k=60 reference, every site that calls `SearchIndexService`. Enumerate them in the design doc.
- Confirm `bm25(...)` returns negative scores in FTS5 (lower=better → ORDER BY bm25 ASC for top-N).
- Confirm GRDB version supports raw SQL with FTS5 + window functions (it does, but verify in `Package.resolved`).
- Confirm `readable_blocks` schema has `entity_id`, `parent_doc_id`, `kind`, `vault_id`, `updated_at`. If any are missing, add them additively in Phase 1.
- Decide granularity: block hits roll up to parent doc with their best block rank as snippet anchor. Document this choice with rationale.
- Write `docs/RRF_FUSION_DESIGN.md` covering: source enumeration, granularity strategy, tie-breakers, recency boost formula, perf budget (target <30ms p95 on 50k rows total), rollback plan.
- Update `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` §225 with a sub-section linking to the design doc.
- Add the phase to `docs/AGENT_PROGRESS.md`.

## Phase 1 — Schema + migration (additive, reversible)
- Verify `readable_blocks` carries the columns above; add any missing ones via additive ALTER TABLE.
- Add an `updated_at` index on each FTS5 content table for the recency tie-breaker.
- Migration is idempotent (re-running is a no-op) and has a documented down-migration.
- Run `swift test` covering migration up + idempotent re-run.

## Phase 2 — SQL fusion query (the load-bearing piece)
- Implement as a parameterized GRDB SQL request. ONE statement, three CTEs (one per source), `UNION ALL` into a `GROUP BY entity_id` rollup with `SUM(weight * 1.0/(60.0 + rank))`.
- Per-source `LIMIT 200` BEFORE the union to bound work.
- Knobs (in a `FusionWeights` struct): `k=60` (constant), per-source `weight` (default 1.0), recency `halfLifeDays` (default 30), `maxResults` (default 50).
- Result columns: `(entity_kind, entity_id, parent_doc_id, fused_score, best_source_rank, snippet_block_id, updated_at)`.
- Tie-breakers: `fused_score DESC, updated_at DESC, entity_id ASC` — deterministic.
- Recency boost: `fused_score * exp(-age_days / halfLifeDays)` where `age_days = (julianday('now') - julianday(updated_at))`.
- The query must EXPLAIN to a sane plan (no full table scans on FTS sources). Capture EXPLAIN QUERY PLAN output in the design doc.

## Phase 3 — SearchIndexService API
- New method on the actor: `func fusedSearch(query: String, kinds: Set<EntityKind>, limit: Int = 50, weights: FusionWeights = .default) async throws -> [FusedResult]`.
- All GRDB work in `nonisolated` methods (matches existing pattern); only the actor serializes orchestration.
- `FusedResult` and `FusionWeights` are `Sendable` structs.
- Add `os_signpost` events around the query: `fused_search.start` and `fused_search.end` with attributes `(query_len, kinds_count, result_count, latency_ms, per_source_hit_counts)`. This closes audit gap F10.
- Emit a `MutationEnvelope` retrieval-event (closes F9) capturing the query + result entity IDs for audit ground-truth.

## Phase 4 — Wire into the app (this is where the win compounds)
Each site is additive behind `EPISTEMOS_RRF_FUSION_V1`, with fallback to existing per-index path.

1. **HomeView landing wave search bar** — replace per-index dispatch with `fusedSearch`. Match the Liquid Wave reskin spec from `project_landing_wave_redesign.md` (compact flat bar, SF Mono 14pt / ~520pt).
2. **Halo `ShadowPanel`** — Halo's tantivy/usearch RRF is for the AMBIENT shadow index; the in-DB fused search complements it. Add a segmented control "Shadow | Vault" so users can pivot between ambient recall and explicit search.
3. **Epdoc Slash menu / `@`-mention block-link autocomplete** — `fusedSearch(kinds: [.block, .doc])`.
4. **Agent tool — Rust side** — `agent_core/src/tools/registry.rs` exposes a vault-search tool. Route its implementation through a new MCP-bridged FFI that calls Swift's `fusedSearch`. Update tool schema with `kinds`, `limit`, `weights` parameters.
5. **Local Hermes parity** — update `Epistemos/LocalAgent/LocalToolGrammar.swift` so the local model can call the same fused tool. Update `HermesPromptBuilder.swift` if the tool description changed.
6. **AgentRuntime context retrieval** — when the loop pulls context for prompt-building, swap any per-index lookups for one fused call. Improves quality AND reduces context budget by deduplicating across kinds.
7. **iMessage channel (Phase K future-proofing)** — once inbound iMessage lands, dispatch profiles need `fusedSearch` to pull reply context. Stub the call site now with a TODO referencing `project_imessage_channel.md` so Phase K just lights it up.
8. **Meaning anchors integration** — when an anchor is set, weight its parent doc's results higher via the `weights` parameter. The user's pinned attention skews retrieval. See `project_meaning_anchors.md`.

## Phase 5 — Tests (REAL DB, NO MOCKS — non-negotiable)
- New file `EpistemosTests/SearchIndexServiceFusionTests.swift` using Swift Testing (`@Test`, `#expect`). Use a `:memory:` `DatabasePool`, seed a fixture corpus (10 docs, 50 blocks, 5 chats — mixed term distribution), assert:
  - Single-source query returns that source's top hit first
  - Cross-source query interleaves correctly per RRF math (compute expected scores in test setup, compare to query output to within 1e-9)
  - Block→doc rollup picks best-rank block as snippet anchor
  - Recency boost reorders ties
  - Tie-breaker is deterministic across 100 repeated runs
  - Empty query, missing kinds, empty corpus do not crash
- Performance test (run locally, skip in CI): 50k blocks → p95 < 30ms.
- Integration test from each wiring site: HomeView search, Halo Vault tab, Epdoc Slash, Agent tool roundtrip via FFI.

## Phase 6 — Observability + flag flip
- Confirm signposts visible in Instruments (Time Profiler + Points of Interest).
- Add a Settings → "Search Fusion Health" row mirroring the `EditorBundleHealthRow` pattern: last query latency, hit rate per source, p95 over last hour.
- After 3 days of dev-build dogfooding with no regressions, flip `EPISTEMOS_RRF_FUSION_V1` to default-ON for MAS. Log this decision.

## Phase 7 — Doc updates (mandatory, before final commit)
- `docs/RRF_FUSION_DESIGN.md` — finalized with shipped numbers
- `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` — §225 sub-section marked complete
- `docs/AGENT_PROGRESS.md` — phases 0-7 marked ✅ with dates
- `docs/KNOWN_ISSUES_REGISTER.md` — close any related items, log new ones
- `CLAUDE.md` FILE MAP — add `Epistemos/Sync/SearchIndexService.swift` fused-search section + new test file path

## Verification gates (run BEFORE claiming each phase done)
- `xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify` → BUILD SUCCEEDED
- `swift test` → 0 failures, no regressions in 2,679-test suite
- `cargo test --manifest-path agent_core/Cargo.toml` → all green
- `swiftlint` → no new violations
- After Phase 4: launch app, run a query in HomeView, Halo Vault tab, Epdoc Slash, agent prompt — all four return fused results. Note results.

## Acceptance criteria
- [ ] Single SQL query produces fused, ordered results across 3 sources
- [ ] All 8 wiring sites use it
- [ ] Feature flag fallback exercised in tests
- [ ] Tests pass with real DB, no mocks, determinism verified
- [ ] p95 < 30ms on 50k rows
- [ ] Signposts + Settings health row live; F9 + F10 audit gaps closed
- [ ] Plan + progress + design docs updated
- [ ] Each phase committed separately, all pushed

## Non-negotiables
- No mocks for DB tests (`:memory:` pool with fixture corpus)
- @Observable + Swift Testing for new code
- Background actor; never block @MainActor
- DispatchQueue.main.async in UniFFI callbacks, NEVER .sync (deadlock)
- No `try!`, no force-unwraps, no `print()` in production paths
- Read every related doc first

## Theoretical foundation (preserved from user brief 2026-04-28)

The transition consolidates lexical (`page_search` BM25 / FTS5), block-level lexical (`block_search` FTS5), and the new universal projection (`readable_blocks_fts`) into a single SQL JOIN. Per the user's research synthesis:

- **k=60 industry standard** — empirically derived from SIGRR 2009; smoothing constant balancing precision against consensus rewards. Higher = broader recall; lower = more aggressive consensus.
- **Calibration problem solved** — RRF discards raw scores entirely (BM25 unbounded vs cosine bounded; incomparable distributions). Operates on ordinal rank only.
- **Single-DB-pool advantage** — atomic transaction wraps content + index updates; FULL OUTER JOIN includes "specialist" results found by only one modality (`COALESCE` handles missing-from-list cases as zero contribution per RRF math).
- **Window functions** — `ROW_NUMBER() OVER (ORDER BY bm25 ASC)` and `ORDER BY similarity DESC` materialise rank within CTEs; SQLite 3.45+ supports both in FTS5 and vector contexts.
- **Tie-breaker hierarchy** — `fused_score DESC, updated_at DESC, entity_id ASC` for determinism (verified by 100-iter test in Phase 5).
- **Recency exponential decay** — `fused_score * exp(-age_days / halfLifeDays)` where halfLife defaults to 30 days; tunable per `FusionWeights`.

Source: User's deep-research synthesis appended to the original prompt 2026-04-28.
