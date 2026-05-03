---
role: detective
slice: phase5-ssm-state-provenance-pr37
concept: Phase5 SSM state AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §9
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase5Bridge.swift:31
  - /Users/jojo/Downloads/Epistemos/Epistemos/Vault/SSMStateService.swift:289
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/StreamingDelegate.swift:590
deliberations_consulted: []
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: false
  canon_says: "broader runtime AgentEvent coverage"
  code_says: "[paraphrase] Phase5Bridge has no AgentEvent recorder yet."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase5Bridge.swift
load_bearing_quote: "remaining broader runtime AgentEvent coverage"
verdict: open
usefulness: +1
usefulness_reason: Names the exact still-open runtime bridge and the no-save/load boundary.
---

## Findings

- `Phase5Bridge.manageSsmState(actionJson:)` currently returns JSON for `list`, `prune`, `total_size`, and explicit errors for `save` / `load`.
- `SSMStateService` exposes list/prune/total-size helpers without requiring live MLX cache access.
- `StreamingDelegate.manageSsmState(actionJson:)` already routes FFI calls through `Phase5Bridge.shared`, so instrumenting the bridge covers the Phase5 FFI entrypoint.

## Open questions

- None for this slice. `generateConstrained(prompt:grammarJson:)` remains a separate future Phase5 provenance slice.

## Recommendation

Instrument `manageSsmState` with sanitized requested/started/completed/failed AgentEvents, persisting only bounded action class, model scope, counts/bytes, and bounded failure class. Preserve the existing external JSON response behavior, including the deliberate `save`/`load` rejection.
