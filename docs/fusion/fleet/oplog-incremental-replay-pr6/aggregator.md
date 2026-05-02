---
role: aggregator
source_fleet: codex-own
slice: oplog-incremental-replay-pr6
date: 2026-05-02
detectives_consumed:
  - detectives/oplog-incremental-replay.md
  - detectives/replay-boundary.md
web_consumed: []
claude_side_fleet_consumed:
  - claude-side-fleet/aggregator.md
canon_gaps_opened: []
conflicts:
  - id: C1
    sources: [claude-side-fleet/aggregator.md, detectives/replay-boundary.md]
    resolution: Claude suggests an optional bridge cursor; Codex allows it only if it calls existing iterate(after:) and remains in MutationOpLogReplay.swift.
  - id: C2
    sources: [claude-red-team/attacks.md, deliberation/oplog_incremental_replay_pr6_deliberation_2026_05_02.md]
    resolution: Red-team P0/P1 attacks are accepted; the brief now pins overlap, empty bootstrap, duplicate seeding, cutoff, and privacy tests.
drift_signals: []
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
  minus_one: 1
usefulness: +1
usefulness_reason: Converts the open incremental replay lane into a bounded PR6 brief.
---

## Reconciled findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §8 anchors this under Streaming / FFI / BoltFFI because the replay path must respect the existing Swift/Rust boundary.
- Current state leaves "Incremental replay" open at `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:654`.
- Card 6 names incremental replay as a future replay target at `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md:570`.
- Current code has full replay semantics in `MutationOpLogReplay.replay(...)` at `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:121`, including sequence sort, cutoff, duplicate detection, and ignored non-projection counting.
- Current tests cover full replay, rollback cutoff, duplicate detection, and PR5 bundle export in `/Users/jojo/Downloads/Epistemos/EpistemosTests/CognitiveSubstrateTests.swift:2788`.
- Claude side-fleet confirmed PR6 is feasible as a pure Swift fold and optional bridge cursor over existing `iterate(after:)`.

## Recommended slice shape

Add `MutationOpLogReplay.applyIncremental(snapshot:newEntries:upToSeq:)` as a pure Swift read-only fold that returns a new snapshot equivalent to full replay for ordered tails. Drop overlapping rows before counting, seed duplicate detection from prior records, and use `upToSeq` as the explicit returned cutoff when provided. Add `RustOpLogFFIClient.incrementalReplayMutationProjections(from:upToSeq:)` only if it bootstraps empty snapshots with `iterateAll()`, otherwise calls existing `iterate(after:)`, and stays in `MutationOpLogReplay.swift`. Tests must prove empty tails, projection tails, duplicate tails, non-projection tails, unicode ids, cutoff tails, PR5 bundle privacy, and bridge reachability.

## Failure-proof guardrails

- grep: `applyIncremental`
- grep: `incrementalReplayMutationProjections`
- forbidden grep: `oplog_append_payload_json|markMutationProjectionOutboxProjected|recordMutationProjectionOutboxFailure|claimMutationProjectionOutboxRows`
- log: `✔ Test "Mutation OpLog incremental replay matches full replay" passed`
- log: `✔ Test "Swift bridge incrementally replays mutation projections from real OpLog" passed`
- test: `OpLog Swift Bridge`
