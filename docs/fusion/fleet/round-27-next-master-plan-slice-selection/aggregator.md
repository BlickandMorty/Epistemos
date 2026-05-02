---
role: aggregator
source_fleet: codex-own
slice: next-master-plan-slice-selection
date: 2026-05-02
detectives_consumed:
  - docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  - docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/aggregator.md
  - docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/codex-red-team/attacks.md
web_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md, docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/codex-red-team/attacks.md]
    resolution: PR20 remains desired but cannot be implemented directly; build a recorder-enabler slice first.
drift_signals:
  - PR20 brief was blocked by the MainActor recorder / nonisolated sync search mismatch.
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: AgentEvent sync provenance enabler needed before PR20.
ready_for_pipeline_builder: true
missing_artifacts:
  - none
input_usefulness_rollup:
  plus_one: 4
  zero: 1
  minus_one: 0
usefulness: +1
usefulness_reason: Selects a safe non-manual enabling slice that unblocks the next AgentEvent provenance lane without touching dirty runtime files.
---

## Reconciled Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 keeps AgentEvent in the substrate spine: "TypedArtifact -> MutationEnvelope -> RunEventLog / AgentEvent / GraphEvent".
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §22.1 requires local canon and code validation before even simple changes.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 has PR1-PR19 closed; the next named PR20 sync fused-search surface is blocked by current-code actor isolation, not by missing desire.
- `docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/codex-red-team/attacks.md` blocks direct PR20 because `SearchIndexService.fusedSearch(...)` is sync/nonisolated while `AgentToolProvenanceRecorder` is `@MainActor`.
- Current code confirms `EventStore.saveAgentEvent(_:)` is nonisolated and serialized on its own queue, so a sync-safe recorder sibling can persist directly without a main-actor hop if it owns thread-safe sequence state.

## Recommended Next Slice
Build `agent-event-sync-recorder-enabler-pr0`: an additive, pure-Swift sync-safe AgentEvent recorder path in `Epistemos/Engine/AgentToolProvenanceRecorder.swift`, with focused tests. The slice must not instrument `SearchIndexService.fusedSearch(...)` yet. It only provides the safe primitive PR20 needs.

## Why Other Lanes Wait
- R15 live MLX runtime evidence remains memory-gated and should not be forced without a runtime/manual evidence window.
- R16 and Halo runtime/manual closures are explicitly deferred until the user wants manual testing.
- GraphEvent Card 8 PR1-PR8 are closed; future live consumers need a fresh exact gate and currently risk graph/Halo dirty-file collisions.
- Hermes Card 10 PR1-PR7 are closed; provider/MCP subprocess work needs a fresh Pro/Research runtime gate.
- Sovereign Gate is viable later, but this AgentEvent enabler is a smaller unlock for multiple future provenance slices.

## Failure-Proof Guardrails
- grep: `final class AgentToolProvenanceRecorder`
- grep: `nonisolated public func fusedSearch(`
- forbidden grep: `Task\s*(\.detached)?\s*\{[^\n]*(recordToolEvent|AgentToolProvenanceRecorder)`
- log: `Test run with`
- test: `AgentToolProvenanceRecorder sync-safe enabler tests`
