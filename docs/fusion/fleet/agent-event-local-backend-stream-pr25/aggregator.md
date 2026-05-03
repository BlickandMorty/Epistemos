---
role: aggregator
source_fleet: codex-own
slice: agent-event-local-backend-stream-pr25
date: 2026-05-03
detectives_consumed:
  - detectives/local-backend-stream-agent-event.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts: []
drift_signals: []
tier: All
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
usefulness_reason: Turns current-state PR24 streaming gap into a bounded PR25 implementation brief.
---

## Reconciled findings
- MASTER_RESEARCH_INDEX_2026_05_02.md §2 and §8 keep AgentEvent and streaming in the substrate spine; this is a canonical runtime-provenance slice.
- MASTER_RESEARCH_INDEX_2026_05_02.md §9 keeps local model routing/inference in scope; `LocalBackendLLMClient.stream(...)` is the current Swift route seam.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` says PR24 closed `LocalGGUFClient.generate(...)` without streaming, and the next lane includes "remaining broader runtime AgentEvent coverage."
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 requires sanitized requested/started/completed/failed AgentEvents with run id and tool call identity.

## Recommended slice shape
Instrument `LocalBackendLLMClient.stream(...)` with optional recorder injection and backend-route stream lifecycle AgentEvents. Record bounded route metadata, resolved runtime when known, chunk/output character counts only, elapsed milliseconds, and bounded failure classes. Do not change token streaming, routing policy, lower runtime behavior, UI, EventStore schema, Hermes/MCP, graph, Rust, Sovereign Gate, or ANE/private APIs.

## Failure-proof guardrails
- grep: `rg -n 'local_backend\\.stream|local-backend-stream-|agentProvenanceRecorder' Epistemos/Engine/LocalBackendLLMClient.swift EpistemosTests/LocalBackendLLMClientTests.swift`
- log: `** TEST SUCCEEDED **` in `/tmp/epistemos-agent-event-local-backend-stream-pr25-green-20260503.log`
- test: `Local Backend LLM Client`
