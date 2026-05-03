---
role: aggregator
source_fleet: codex-own
slice: agent-event-local-gguf-stream-pr32
date: 2026-05-03
detectives_consumed:
  - detectives/local-gguf-stream-agent-event.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - pending
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md, r15-mlx-live-token-throughput-pr8-closure]
    resolution: R15 remains blocked by sufficient-memory conditions, so AgentEvent runtime coverage is the next code-safe lane.
drift_signals:
  - LocalGGUFClient.stream currently lacks durable AgentEvent records while current state asks for broader runtime AgentEvent coverage.
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
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts an exact open GGUF stream blind spot into a bounded implementation brief.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §9` anchors local model routing/inference as a substrate surface.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` keeps AgentEvent in the substrate spine: TypedArtifact to MutationEnvelope to RunEventLog, AgentEvent, GraphEvent.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:1170` permits future runtime AgentEvent work only when exact runtime files and tests are named.
- `LocalGGUFClient.swift:764` is the exact direct GGUF streaming seam and is not covered by PR24 generate, PR25 router stream, PR28 MLX stream, or PR29 router generate.
- `LocalGGUFClientTests.swift:166` already contains a local AgentEvent sink and sanitization assertions suitable for red-first focused coverage.

## Recommended slice shape
Add sanitized AgentEvent lifecycle records to direct `LocalGGUFClient.stream(...)` only. Use tool identity `local_stream.gguf`, run ids `local-gguf-stream-...`, tool call ids `local-gguf-stream:N`, source `local_gguf_client`, surface `stream`, provider `local_gguf`, and bounded prompt/system-count, runtime, reasoning, max-token, steering-present, elapsed, chunk-count, output-character-count, success, and failure-class metadata. Do not alter routing, model loading, runtime-control-plane policy, token delivery, EventStore schema, UI, graph, Rust, generated bindings, Hermes/MCP, browser/computer-use, Sovereign, LocalAuthentication, or ANE/private API surfaces.

## Failure-proof guardrails
- grep: `rg -n "local_stream\\.gguf|local-gguf-stream|surface.*stream" Epistemos/Engine/LocalGGUFClient.swift EpistemosTests/LocalGGUFClientTests.swift`
- log: `/tmp/epistemos-agent-event-local-gguf-stream-pr32-green-20260503.log`
- test: `EpistemosTests/LocalGGUFClientTests`
