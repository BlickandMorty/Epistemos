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
    resolution: "Claude correctly identified PR20 as the next parity gap; local code audit adds that current recorder isolation blocks a safe one-file implementation."
drift_signals:
  - "PR19 intentionally left sync fusedSearch uninstrumented; PR20 must not simply invert that guard without solving recorder isolation."
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
usefulness_reason: Converts the PR20 candidate into a deliberation-ready blocker/enabling-slice decision instead of a risky code order.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` anchors AgentEvent as substrate-spine state; sync fused search is a legitimate provenance gap after PR19.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §5` anchors recall/search rails; `SearchIndexService.fusedSearch` is user-reachable through `VaultSyncService` and `QueryRuntime`.
- The current sync method is `nonisolated public` and synchronous. The existing recorder is `@MainActor`. A direct one-file patch cannot safely emit awaited lifecycle rows from that method.
- Forbidden implementation shapes: fire-and-forget recorder `Task`, `Task.detached`, `DispatchQueue.main.sync`, `MainActor.assumeIsolated`, changing `fusedSearch` to actor-isolated/async, or touching `VaultSyncService` / `QueryRuntime` just to adapt to a signature break.

## Recommended Slice Shape

Approve a **blocked PR20 deliberation** first: red-team the blocker, then either open a separate enabling slice for a sync-safe shared provenance recorder/event-builder, or mark sync fused search intentionally direct and move to the next master-plan slice. Do not issue Kimi/code orders for sync fused-search instrumentation until that decision is closed.

## Failure-Proof Guardrails

- grep: `nonisolated public func fusedSearch(`
- grep: `@MainActor\nfinal class AgentToolProvenanceRecorder`
- forbidden grep: `Task\\s*(\\.detached)?\\s*\\{[^\\n]*(recordToolEvent|AgentToolProvenanceRecorder)`
- forbidden grep: `DispatchQueue\\.main\\.sync|MainActor\\.assumeIsolated`
- log: `CLAUDE-RETURN: role=RED-TEAM`
- test: `SearchIndexServiceAgentEventSourceGuardTests`
