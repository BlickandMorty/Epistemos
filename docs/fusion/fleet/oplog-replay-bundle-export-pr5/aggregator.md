---
role: aggregator
source_fleet: codex-own
slice: oplog-replay-bundle-export-pr5
date: 2026-05-02
detectives_consumed:
  - detectives/oplog-replay-export.md
  - detectives/replay-bundle-boundary.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C0
    sources: []
    resolution: none
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
  plus_one: 2
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts the open ReplayBundle export lane into a bounded PR5 brief.
---

## Reconciled findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §1 makes current code and passing logs the top authority; current code has replay snapshots but no bundle export.
- Current state leaves "ReplayBundle export" open at `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:648`.
- Card 6 explicitly says future replay work can target ReplayBundle export at `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md:566`.
- The bundle must stay in the replay layer and avoid EventStore, Rust ABI, UI, repair, rollback execution, scheduling, or generated bindings.

## Recommended slice shape

Add an immutable `Codable` ReplayBundle value derived from `MutationOpLogReplaySnapshot`, plus deterministic JSON encoding and a `RustOpLogFFIClient` convenience method hosted in the existing replay file. Add focused tests for encode/decode determinism and real OpLog bridge reachability.

## Failure-proof guardrails

- grep: `rg -n "oplog_open_at|oplog_append_payload_json|@_silgen_name|markMutationProjectionOutboxProjected|recordMutationProjectionOutboxFailure|claimMutationProjectionOutboxRows|repair|rollback" Epistemos/Engine/MutationOpLogReplay.swift EpistemosTests/CognitiveSubstrateTests.swift`
- log: `** TEST SUCCEEDED **`
- test: `EpistemosTests/OpLogSwiftBridgeTests`
