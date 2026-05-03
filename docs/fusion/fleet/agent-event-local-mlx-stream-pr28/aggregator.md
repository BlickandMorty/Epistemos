---
role: aggregator
source_fleet: codex-own
slice: agent-event-local-mlx-stream-pr28
date: 2026-05-03
detectives_consumed:
  - detectives/local-mlx-stream-agent-event.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts: []
drift_signals:
  - Direct LocalMLX stream is still uninstrumented while current state calls for remaining broader runtime AgentEvent coverage.
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
usefulness_reason: Narrows the next build to a testable direct stream provenance patch.
---

## Reconciled findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §8 and §9 anchor streaming and local MLX runtime work.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` records PR27 closed and still calls for broader runtime AgentEvent coverage.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 allows another runtime provenance slice only with exact file names and focused tests.
- Direct `LocalMLXClient.stream(...)` is the smallest unclosed sibling to PR27: it is local/Core, no web dependency, and no UI/Rust/schema work is needed.

## Recommended slice shape

Add sanitized AgentEvent records to direct `LocalMLXClient.stream(...)` only. The patch should reuse PR27's direct MLX provenance policy, add stream-specific tool identity (`local_stream.mlx`, `local-mlx-stream:N`, `surface=stream`), include chunk/output counts instead of text, and preserve existing runtime-control-plane streaming semantics.

## Failure-proof guardrails

- grep: `local_stream\\.mlx|local-mlx-stream|surface.*stream`
- log: `Test run with 13 tests in 1 suite passed`
- test: `LocalBackendLLMClientTests/local mlx stream records sanitized AgentEvents`
