---
role: detective
slice: shadow-search-agent-event-pr18
concept: ShadowSearch / Halo ambient recall backend
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §5
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/audits/AMBIENT_RECALL_WIRING_PLAN.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/ShadowSearchService.swift:19
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/ShadowFFIClient.swift:65
  - /Users/jojo/Downloads/Epistemos/Epistemos/Models/HaloState.swift:18
deliberations_consulted:
  - docs/fusion/deliberation/halo_v0_shadow_backend_route_pr1_deliberation_2026_05_01.md
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "V0: production-mounted with `ShadowSearchService` backend route."
  code_says: "[paraphrase] ShadowSearchService.search delegates to ShadowFFIClient and swallows errors into an empty hit array."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/ShadowSearchService.swift
load_bearing_quote: "`Epistemos/Engine/ShadowSearchService.swift` (ShadowFFI search wrapper)"
verdict: open
usefulness: +1
usefulness_reason: Identifies the live Halo backend chokepoint and the files PR18 must not expand beyond.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md:202` says V0 is production-mounted with the ShadowSearchService backend route.
- `MASTER_RESEARCH_INDEX_2026_05_02.md:213` gives the ambient-recall latency budget and stack, so recorder work must stay bounded.
- `ShadowSearchService.swift:31` is the single public async search boundary used by Halo/Contextual Shadows.
- `ShadowFFIClient.swift:65` defines the existing protocol and `StubShadowFFIClient`; tests can verify PR18 without Rust or generated bindings.

## Open questions
- No web validation is required for PR18 because it uses existing local Swift types and no external API/framework behavior.

## Recommendation
Instrument only `ShadowSearchService.search(text:domain:limit:)`. Do not edit HaloController, Halo views, graph, Rust, generated bindings, EventStore schema, `searchOrThrow`, or `stats`.
