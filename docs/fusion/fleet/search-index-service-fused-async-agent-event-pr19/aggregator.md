---
role: aggregator
source_fleet: codex-own
slice: search-index-service-fused-async-agent-event-pr19
date: 2026-05-02
detectives_consumed:
  - detectives/agent-event-provenance.md
  - detectives/search-index-fused-async.md
web_consumed: []
claude_side_fleet_consumed:
  - ../round-19-next-master-plan-slice-selection/claude-side-fleet/aggregator.md
canon_gaps_opened: []
conflicts:
  - id: C1
    sources: [aggregator.md, claude-red-team/attacks.md]
    resolution: Claude Red Team wins on implementation shape: recorder calls must happen outside the non-async offload closure.
  - id: C2
    sources: [claude-red-team/attacks-r2.md, search_index_fused_async_agent_event_pr19_deliberation_2026_05_02.md]
    resolution: Round-2 Red Team cleared all P0/P1 findings and supplied P2 tightenings; fold them into the implementation contract without blocking code.
drift_signals:
  - Current-state open wording omitted closed ShadowSearch PR18; PR19 docs should narrow it.
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
  plus_one: 3
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts Claude's PR19 recommendation plus local code checks into a deliberation-ready slice, revised for Red Team isolation findings.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` anchors AgentEvent as part of the substrate spine, and Card 7 keeps live emission additive and bounded.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §5` anchors Halo/recall search as a load-bearing retrieval rail; `SearchIndexService.fusedSearchAsync` is the next uninstrumented RRF fused async chokepoint.
- Current code has no `AgentProvenance` or `saveAgentEvent` references in `Epistemos/Sync/SearchIndexService.swift`, `Epistemos/Sync/VaultSyncService.swift`, or `Epistemos/Engine/QueryRuntime.swift`.
- `SearchIndexService.fusedSearchAsync` already has signpost and `SearchFusionMetrics` boundaries, but its RRF body is inside a non-async offload closure. Recorder calls must be emitted before and after `offloadSearch`, not from inside the closure.

## Recommended slice shape
Approve a Core PR19 that optionally injects the existing `AgentToolProvenanceRecorder` into `SearchIndexService`, lazily creates and stores the production recorder on `MainActor` when needed, prepares normalized/sanitized query terms in actor scope, emits requested/started before `offloadSearch` dispatch and directly awaits completed-or-failed after it returns or throws, persists sanitized scalar metadata only, preserves thrown-error behavior, and leaves sync/legacy search methods untouched.

## Failure-proof guardrails
- grep: `search-index-fused-async-`
- grep: `toolName: "search_index.fused_search_async"`
- grep: `surface": "fused_search_async"`
- grep: `Task\\s*(\\.detached)?\\s*\\{[^\\n]*(recordToolEvent|AgentToolProvenanceRecorder)` returns empty
- grep: `git grep -n -A 35 "nonisolated public func fusedSearch(" Epistemos/Sync/SearchIndexService.swift | grep -E "(agentProvenanceRecorder|recordToolEvent)"` returns empty
- log: `✔ Test "fusedSearchAsync records sanitized AgentEvents" passed`
- test: `SearchIndexService - RRF Fusion (Phase 5)`
