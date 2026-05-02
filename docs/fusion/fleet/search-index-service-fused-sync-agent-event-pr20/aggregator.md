---
role: aggregator
source_fleet: codex-own
slice: search-index-service-fused-sync-agent-event-pr20
date: 2026-05-02
detectives_consumed:
  - detectives/agent-event-provenance.md
  - detectives/search-index-fused-sync.md
web_consumed: []
claude_side_fleet_consumed:
  - ../round-21-next-master-plan-slice-selection/claude-side-fleet/aggregator.md
canon_gaps_opened: []
conflicts:
  - id: C1
    sources: [round-21 claude-side-fleet, local code audit]
    resolution: "Claude correctly identified PR20 as the next parity gap; PR0 has now closed the recorder-isolation blocker."
drift_signals:
  - "PR19 intentionally left sync fusedSearch uninstrumented; PR20 may proceed only by using AgentToolProvenanceSyncRecorder from PR0."
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
usefulness_reason: Converts the former PR20 blocker into an implementation-ready sync provenance gate after PR0.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` anchors AgentEvent as substrate-spine state; sync fused search is a legitimate provenance gap after PR19.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §5` anchors recall/search rails; `SearchIndexService.fusedSearch` is user-reachable through `VaultSyncService` and `QueryRuntime`.
- The current sync method is `nonisolated public` and synchronous. PR0 adds `AgentToolProvenanceSyncRecorder`, so PR20 can emit lifecycle rows without actor hops or fire-and-forget work.
- Forbidden implementation shapes remain: `Task`, `Task.detached`, `DispatchQueue.main.sync`, `MainActor.assumeIsolated`, changing `fusedSearch` to actor-isolated/async, or touching `VaultSyncService` / `QueryRuntime` just to adapt to a signature break.

## Recommended Slice Shape

Approve a narrow PR20 implementation: inject a sync recorder into `SearchIndexService`, record requested/started/completed-or-failed AgentEvents inside `fusedSearch(...)`, keep the sync API direct, and preserve RRF SQL, metrics, signposts, and caller behavior.

## Failure-Proof Guardrails

- grep: `nonisolated public func fusedSearch(`
- grep: `AgentToolProvenanceSyncRecorder`
- forbidden grep: `Task\\s*(\\.detached)?\\s*\\{[^\\n]*(recordToolEvent|AgentToolProvenanceRecorder)`
- forbidden grep: `DispatchQueue\\.main\\.sync|MainActor\\.assumeIsolated`
- log: `fusedSearch sync records sanitized AgentEvents`
- test: `SearchIndexServiceAgentEventSourceGuardTests`
