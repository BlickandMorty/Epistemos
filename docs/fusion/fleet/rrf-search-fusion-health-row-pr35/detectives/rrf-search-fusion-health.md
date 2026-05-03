---
role: detective
slice: rrf-search-fusion-health-row-pr35
concept: Swift RRF Cross-Index Fusion Phase 6 observability
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2
tier: Both
canonical_source: /Users/jojo/Downloads/Epistemos/docs/RRF_FUSION_PROMPT.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/RRF_FUSION_DESIGN.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/RRFFusionQuery.swift:43
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SearchFusionHealthRow.swift:23
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SettingsView.swift:697
deliberations_consulted:
  - docs/fusion/deliberation/query_runtime_rrf_fused_fulltext_pr34_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: true
  canon_says: "Add a Settings → \"Search Fusion Health\" row"
  code_says: "[paraphrase] Draft row exists and is mounted, but uses a polling task that should be event-driven before commit."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/RRF_FUSION_PROMPT.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SearchFusionHealthRow.swift
load_bearing_quote: "last query latency, hit rate per source, p95 over last hour"
verdict: partial
usefulness: +1
usefulness_reason: Closes the observable half of Phase 6 while keeping dogfood/default-flip deferred.
---

## Findings

- `docs/RRF_FUSION_PROMPT.md:90` requires Phase 6 observability and a later flag flip.
- `docs/RRF_FUSION_DESIGN.md:272` explicitly defers the Settings row plus dogfood/default flip until runtime verification.
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md:81` names Swift RRF Cross-Index Fusion as canonical and includes "Search Fusion Health" in aliases.
- `Epistemos/Sync/RRFFusionQuery.swift:43` already has `SearchFusionMetrics.shared`, so UI should read existing metrics rather than create new instrumentation.
- `Epistemos/Views/Settings/SearchFusionHealthRow.swift:75` uses polling; the slice should make refresh event-driven and source-guard that no timer loop remains.

## Open Questions

- None for implementation. The default flag flip remains blocked by the existing dogfood/runtime gate.

## Recommendation

Ship a read-only Settings row backed by `SearchFusionMetrics`, add a notification on metric changes to avoid polling, mount the row in Diagnostics, and add source/metrics tests. Do not modify RRF SQL, search behavior, feature flag defaults, or dogfood status.
