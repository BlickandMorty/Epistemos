---
role: aggregator
source_fleet: codex-own
slice: agent-event-search-index-block-search-pr22
date: 2026-05-03
detectives_consumed:
  - detectives/search-index-block-search-agent-event.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts: []
drift_signals:
  - searchBlocks/searchBlocksAsync remain uninstrumented while the current state keeps runtime AgentEvent coverage open.
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none
ready_for_pipeline_builder: true
missing_artifacts: []
input_usefulness_rollup:
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts the detected block-search provenance gap into a bounded build slice.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 anchors this to the substrate spine: AgentEvent is the durable provenance layer between runtime actions and projections.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §19 and §22 require local canon-first lookup and artifact-backed deliberation before code.
- `SearchIndexService.searchBlocks(query:limit:)` and `searchBlocksAsync(query:limit:)` are the only code targets. The private `searchBlocks(terms:limit:cancellation:)` SQL path remains unchanged.
- PR21 closed direct page search and intentionally excluded block-search tool names. PR22 should introduce block-specific tool names only inside block-search lifecycle helpers and tests.

## Recommended slice shape
Implement one additive provenance slice: valid non-empty block searches emit requested, started, and completed/failed AgentEvents with sanitized query counts, term counts, limits, hit counts, elapsed milliseconds, and closed failure classes. Preserve result behavior, SQL, fallback query behavior, fused search, page search, EventStore schema, UI, graph, Rust, generated bindings, and `VaultSyncService`.

## Failure-proof guardrails
- grep: `rg -n 'search_index\.search_blocks|search_index\.search_blocks_async|recordBlockSearch' Epistemos/Sync/SearchIndexService.swift EpistemosTests/SearchIndexServiceFusionTests.swift`
- log: `/tmp/epistemos-agent-event-search-index-block-pr22-green-pipefail-20260503.log` contains `** TEST SUCCEEDED **`
- test: `EpistemosTests/SearchIndexServiceFusionTests` and `EpistemosTests/SearchIndexServiceAgentEventSourceGuardTests`
