---
role: aggregator
source_fleet: codex-own
slice: agent-event-search-index-direct-page-pr21
date: 2026-05-03
detectives_consumed:
  - detectives/search-index-direct-page-agent-event.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [round-51-scouts, current-code]
    resolution: Direct SearchIndex page search wins for this round; VaultSync wrapper and GraphEvent consumer work are dirty/protected.
drift_signals:
  - none
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none
ready_for_pipeline_builder: true
missing_artifacts:
  - none
input_usefulness_rollup:
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Turns the remaining AgentEvent coverage instruction into a clean exact SearchIndex page-search PR.
---

## Reconciled findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 and current state require typed provenance-linked events before broader projections.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:285` through `:333` closes SearchIndex fused async/sync only; direct page search remains open.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:1001` through `:1008` permits future broader runtime instrumentation after a new exact gate.
- Current code shows clean candidate files and existing recorder/test helpers in `SearchIndexService.swift` and `SearchIndexServiceFusionTests.swift`.

## Recommended slice shape

Instrument direct page `search` and `searchAsync` only. Reuse the existing async and sync AgentEvent recorder surfaces, add monotonic per-instance direct-page tool call ids, emit only bounded query/result/failure metadata, and keep invalid normalized-empty inputs silent.

## Failure-proof guardrails

- grep: `search_index.search`
- grep: `search_index.search_async`
- grep: `directPage`
- log: `✔ Test "direct page search sync records sanitized AgentEvents" passed`
- log: `✔ Test "direct page search async records sanitized AgentEvents" passed`
- test: `SearchIndexServiceFusionTests`
- test: `SearchIndexServiceAgentEventSourceGuardTests`
