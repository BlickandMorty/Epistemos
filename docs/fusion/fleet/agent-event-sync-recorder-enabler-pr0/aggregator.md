---
role: aggregator
source_fleet: codex-own
slice: agent-event-sync-recorder-enabler-pr0
date: 2026-05-02
detectives_consumed:
  - detectives/agent-event-provenance.md
  - detectives/sync-recorder-constraint.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [search-index-service-fused-sync-agent-event-pr20, current code]
    resolution: Do not implement PR20 directly; add a sync-safe recorder enabler first.
drift_signals:
  - PR20 blocked by @MainActor recorder versus sync nonisolated search.
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none for this enabler; PR20 remains separate.
ready_for_pipeline_builder: true
missing_artifacts:
  - none
input_usefulness_rollup:
  plus_one: 2
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Approves a narrow recorder-enabler slice that can be tested without runtime/manual work.
---

## Reconciled Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 anchors AgentEvent as a substrate-spine projection target.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §22.1 requires local canon first and current-code validation before this seemingly simple refactor.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 closes PR1-PR19 and requires future live emissions to stay bounded, visible, and test-first.
- Current code confirms `EventStore.saveAgentEvent(_:)` is nonisolated and queue-serialized; the unsafe part is the recorder's mutable sequence dictionary being `@MainActor`.
- A sync-safe recorder sibling must be additive, share construction semantics, and avoid consumer call-site changes.

## Recommended Slice Shape
Add `AgentToolProvenanceSyncRecorder` beside `AgentToolProvenanceRecorder`, backed by `NSLock` for sequence state and the same event factory as the existing recorder. Add focused Swift Testing coverage in `CognitiveSubstrateTests`. Leave `SearchIndexService.swift` untouched except for source guards that prove it remains uninstrumented.

## Failure-Proof Guardrails
- grep: `final class AgentToolProvenanceSyncRecorder`
- grep: `private let sequenceLock = NSLock()`
- forbidden grep: `rg -n 'DispatchQueue\\.main\\.sync|MainActor\\.assumeIsolated|Task\\.detached|Task \\{' Epistemos/Engine/AgentToolProvenanceRecorder.swift`
- log: `Test run with`
- test: `Agent tool provenance sync recorder persists ordered lifecycle events`
