---
role: aggregator
source_fleet: codex-own
slice: agent-event-local-gguf-generate-pr24
date: 2026-05-03
detectives_consumed:
  - detectives/local-gguf-generate-agent-event.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts: []
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
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts an open local GGUF runtime provenance gap into a narrow implementation brief.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §9 anchors local text generation to GGUF primary; current code exposes that surface at `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalGGUFClient.swift:669`.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` leaves broader runtime AgentEvent coverage open after PR23, so this PR is in-order.
- Existing test infrastructure can inject an in-process fake GGUF engine and capture `AgentProvenanceEvent` through `AgentToolProvenanceRecorder`.
- The slice is Core-only and must not introduce Hermes, cloud, subprocess, MCP, browser/computer-use, private ANE, UI, graph, Rust, generated binding, or EventStore schema work.

## Recommended Slice Shape

Add optional `AgentToolProvenanceRecorder` injection to `LocalGGUFClient`, record requested/started/completed-or-failed lifecycle events around the non-streaming GGUF generation call, and add focused Swift Testing coverage for success and failure sanitization.

## Failure-Proof Guardrails

- grep: `rg -n "local_gguf_client|local_generate\\.gguf|local-gguf-generate" Epistemos/Engine/LocalGGUFClient.swift EpistemosTests/LocalGGUFClientTests.swift`
- log: `/tmp/epistemos-agent-event-local-gguf-generate-pr24-green-20260503.log` contains `** TEST SUCCEEDED **`
- test: `EpistemosTests/LocalGGUFClientTests`
