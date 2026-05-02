---
role: aggregator
source_fleet: codex-own
slice: oplog-replay-bundle-production-visibility-pr7
date: 2026-05-02
detectives_consumed:
  - detectives/oplog-replay-bundle.md
web_consumed: []
claude_side_fleet_consumed:
  - "none"
canon_gaps_opened: []
conflicts: []
drift_signals: []
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: "none"
ready_for_pipeline_builder: true
missing_artifacts: []
input_usefulness_rollup:
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: "Turns an open Card 6 visibility gap into a bounded read-only Settings/test slice."
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 keeps ReplayBundle inside the substrate spine, downstream of MutationEnvelope and OpLog.
- Card 6 says production ReplayBundle visibility remains a future gate after closed PR5 export and PR6 incremental replay.
- The existing Settings OpLog row can host read-only counts, but must not add repair buttons, timers, raw ABI calls, or mutation behavior.

## Recommended slice shape
Implement a read-only visibility report derived from `MutationOpLogReplayBundle`, expose it through `OpLogProjectionHealthRow`, and prove by source guard that the row stays read-only and raw ABI-free.

## Failure-proof guardrails
- grep: `MutationOpLogReplayBundleVisibilityReport`
- log: `OpLog ReplayBundle production visibility row is read-only`
- test: `OpLogFFIBoundaryGuardTests`
