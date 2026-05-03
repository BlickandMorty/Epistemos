---
role: detective
slice: query-runtime-rrf-fused-fulltext-pr34
concept: QueryRuntime RRF fused full-text wiring
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2, Swift RRF Cross-Index Fusion
tier: Both
canonical_source: /Users/jojo/Downloads/Epistemos/docs/RRF_FUSION_PROMPT.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/RRF_FUSION_DESIGN.md
  - /Users/jojo/Downloads/Epistemos/CLAUDE.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/QueryRuntime.swift:349
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift:883
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/RRFFusionQuery.swift:143
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/QueryRuntimeTests.swift:841
deliberations_consulted:
  - docs/fusion/deliberation/sqlite_fts_fusion_floor_deliberation_2026_04_30.md
  - docs/fusion/deliberation/graph_event_query_projection_pr10_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main checkout
drift:
  detected: true
  canon_says: "QueryRuntime.fullText(query:scope:) for scope == .all now dispatches to searchIndex.fusedSearch"
  code_says: "[paraphrase] HEAD lacked the fusedSearch call; the current dirty hunk adds it."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/RRF_FUSION_DESIGN.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/QueryRuntime.swift
load_bearing_quote: "Each site is additive behind EPISTEMOS_RRF_FUSION_V1"
verdict: drift
usefulness: +1
usefulness_reason: Recovers a claimed Phase 4 canonical wiring site that was not present in HEAD.
---

## Findings

- `docs/RRF_FUSION_PROMPT.md:67` declares Phase 4 app wiring and line 72 names the Epdoc slash menu / at-mention block-link autocomplete site.
- `docs/RRF_FUSION_DESIGN.md:281` claims `QueryRuntime.fullText(query:scope:)` dispatches to `searchIndex.fusedSearch` for `scope == .all`.
- `CLAUDE.md:205` lists `QueryRuntime.fullText` as flag-aware RRF Phase 4 wiring, but `git show HEAD:Epistemos/Engine/QueryRuntime.swift` had no fused-search path.
- The candidate hunk in `Epistemos/Engine/QueryRuntime.swift:349` is additive behind `RRFFusionFlags.isEnabled && scope == .all`, passes `FusionWeights(maxResults: limit)`, and falls through to legacy per-index search on fused-path failure.
- `EpistemosTests/QueryRuntimeTests.swift:841` adds a real DB consumer test: readable-block-only content stays invisible with the flag off and in `.pages`, then appears through `.all` when the flag is set.

## Open questions

- Phase 4 sites 4 and 5 remain deferred because the Rust agent tool and local Hermes grammar require a new cross-language FFI bridge.
- Phase 6 dogfood/default flip remains deferred; this slice must not turn the flag on by default.

## Recommendation

Adopt the existing QueryRuntime hunk as PR34 with focused tests and source guards. Do not touch `VaultSyncService`, `SearchIndexService`, RRF SQL, graph renderer, protected editor files, Rust, generated bindings, or default flag policy.
