# T+5 V0 → V1 Recall Migration — Architectural Decision Brief (2026-04-28)

> Closes task #29 ("T+5 architectural decision: V0 → V1 recall
> migration"). Authored as a deliberation brief — the final call is
> the user's; this document lays out options, evidence, and the
> recommended path with explicit tradeoffs.

## Context: two recall stacks running side-by-side

Today the codebase ships TWO separate ambient-recall systems:

### V0 — `InstantRecallService` (graph-engine, original)
- **Source**: `Epistemos/KnowledgeFusion/InstantRecallService.swift` (~294 LOC)
- **Backend**: Rust `graph-engine` crate (HNSW only, no BM25)
- **Surface**: `Epistemos/State/ContextualShadowsState.swift` panel — gated by `EPISTEMOS_AMBIENT_RECALL_V0` env flag
- **Status**: shipped, in production for selective dogfooders
- **Performance**: <3 ms search SLA per `USER_WIRING_GAPS.md:G3`; in-memory only, rebuilt at startup

### V1 — `epistemos-shadow` (tantivy + usearch, V1 differentiator)
- **Source**: `epistemos-shadow/` Rust crate (cdylib)
- **Backend**: tantivy 0.22 BM25 + usearch 2.24 HNSW + RRF fusion (k=60), `model2vec-rs 0.1.4` for embeddings
- **Surface**: `HaloController` → `ShadowSearchService` → `RustShadowFFIClient` → `ShadowPanel` UI
- **Status**: 82% shipped per T+5 deliberation; trailing-edge anchor + cold-start polish still open
- **Performance**: <50 ms total recall budget per `cap1_contextual_shadows.md`; persists to `<vault>/.epcache/shadow`

## The decision

**Question**: As V1 hardens, what happens to V0?

Three options:

### Option A — Hard deprecate V0 immediately
Delete `InstantRecallService.swift`, `ContextualShadowsState.swift`, all V0-flagged paths. V1 is the only ambient-recall stack.

| Pros | Cons |
|---|---|
| One codebase, simpler mental model | V1 is still 82% — gaps in chat-bar surface + cold start mean some users would lose recall during the gap |
| Removes ~300 LOC of duplicated state | V0 has 10 tests in `ContextualShadowsStateTests.swift` that catch regressions in panel visibility / recall hits — would need V1 equivalents |
| Forces V1 hardening to ship | Big-bang rollout risk; user feedback channel narrows |

### Option B — Long-term parallel (V0 stays as opt-in)
Keep V0 behind its env flag indefinitely. V1 is default-on once V1 ships fully. V0 lives as a "classic mode" for users who prefer the lighter HNSW-only behavior.

| Pros | Cons |
|---|---|
| Zero migration risk; everyone keeps what they have | Long-term maintenance cost — two FFI surfaces, two indexers, two state managers |
| Useful A/B baseline if V1 has unexpected regressions | Confusing for end users — "which recall is on?" |
| InstantRecall has interesting per-note edges (graph-engine gives k-hop) that V1 doesn't model | Inhibits investment in either stack — the team always wonders which is "the real one" |

### Option C — Migrate V0 to V1 internals, retire V0 surface (RECOMMENDED)
Keep `ContextualShadowsState` as the panel state layer (UI shape is good). Replace its INTERNAL recall call from `InstantRecallService.search(...)` to `ShadowSearchService.search(...)` (V1's RRF). Delete `InstantRecallService.swift` once nothing reads it. Remove the `EPISTEMOS_AMBIENT_RECALL_V0` flag once the migration is verified — V1 becomes universal.

| Pros | Cons |
|---|---|
| One backend (V1), reused panel surface (V0's UI proven via 10 tests) | Migration ordering matters — must land in this order: (1) wire ShadowSearchService into ContextualShadowsState behind a new flag, (2) verify V1 backend passes the V0 test suite, (3) flip V1 default-on, (4) delete V0 internals |
| Tests carry forward (panel visibility, debounce, hit ordering all still relevant against V1 rankings) | k-hop graph edges from `graph-engine` would need to be replicated via tantivy's tag/metadata facets if any current panel UI depends on them (audit needed before migration) |
| RRF Phase 4 wiring (`SearchIndexService.fusedSearch`) provides another fusion layer that complements V1's internal RRF — i.e. V1 fuses BM25+HNSW within `epistemos-shadow`, while RRF Fusion v1 fuses 3 FTS5 sources at the SQL layer. Two complementary fusion layers, not redundant. | Requires careful review of any V0-specific behavior (graph k-hop) that V1 doesn't directly model |
| Removes ~300 LOC + simplifies the recall-system mental model | One-time engineering cost (~1 dev-day to migrate + verify) |

## Recommendation: Option C, gated on V1 reaching ≥95% shipped

**Why C**: V0's UI surface (`ContextualShadowsState`) is well-tested and ergonomic. V1's backend is more capable (BM25 + HNSW + RRF + persistence + per-vault scoping). Combining the two gives the best of both worlds without the long-term parallel-stack maintenance tax.

**Why "gated on V1 ≥95% shipped"**: T+5 deliberation lists V1 at 82% with critical gaps (trailing-edge anchor, cold start). Migrating V0 users onto V1 BEFORE V1 is fully baked would expose them to those regressions. Better to harden V1 first (gap #1 anchor + W9.21 honest handle + cold-start signal) THEN migrate.

**Sequencing**:
1. **Today (T+5)**: Both stacks in place. V0 default OFF, V1 default OFF.
2. **T+5.5–T+8**: Close V1 gaps. Trailing-edge anchor (gap #1) already shipped per T+5 close-out. W9.21 honest handle becomes blocking-or-not based on test re-run.
3. **T+9 (proposed)**: Audit V1 vs V0 for behavioral parity. Identify any panel UI that depends on V0-specific data (graph k-hop, in-memory speed). For each: verify V1 covers it OR add the missing capability to V1.
4. **T+10**: Wire `ContextualShadowsState` to call `ShadowSearchService.search(...)` instead of `InstantRecallService.search(...)`. Behind a NEW flag `EPISTEMOS_RECALL_V1_BACKEND` so V0-flag-on users can stay on V0 internals while testing.
5. **T+11**: 3-day dogfood. Compare hit relevance / recall@5 against the V0 baseline.
6. **T+12**: If parity confirmed, flip `EPISTEMOS_RECALL_V1_BACKEND` to default ON; remove V0 flag fall-through; delete `InstantRecallService.swift` + tests it owns.

**Decision authority**: User. This brief lays out the options; the final go/no-go on Option C lives with the user. If the user wants Option A (hard deprecate now) or Option B (parallel forever), the implementation paths are different and the brief should be revised.

## Risk register

| Risk | Mitigation |
|---|---|
| V1 internal RRF (BM25+HNSW within epistemos-shadow) collides with the SQL-layer RRF Fusion (Phase 0-7 just shipped) | Already non-conflicting: epistemos-shadow operates over `<vault>/.epcache/shadow`, while RRF Fusion v1 operates over `search.sqlite`. Different sources, different fusion levels. Document this in `docs/RRF_FUSION_DESIGN.md` §1 (already noted as out-of-scope). |
| V0 graph k-hop edges have no V1 equivalent | Audit at T+9 step before migration. If genuinely missing, either add to V1 or scope it out of V0 deprecation. |
| V0 tests rely on `InstantRecallService` mocks | Rewrite tests to stub `ShadowSearchService` at the same surface level. Test contract stays the same; backend swaps. |
| User has a strong preference for V0's <3ms in-memory behavior | Surface V0's perf as a separate concern (in-memory hot-cache layer above V1's persistent index). May warrant a small additive layer rather than full deprecation. |

## Open questions for the user

1. Do you want to commit to Option C? Or consider A or B?
2. If C: any constraints on the sequencing (T+9–T+12)?
3. If C: are there any V0-specific behaviors you've come to depend on that V1 doesn't currently cover? (graph k-hop edges, sub-3ms in-memory, etc.)
4. Should the V0 → V1 migration produce a user-facing "recall mode changed" notice, or is it a silent backend swap?

This brief stays open for user direction. No code changes land until Option A/B/C is selected.
