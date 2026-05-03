---
role: aggregator
source_fleet: codex-own
slice: agent-event-local-mlx-generate-pr27
date: 2026-05-03
detectives_consumed:
  - detectives/local-mlx-generate-agent-event.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [PR26 deliberate packet, MLXInferenceService.swift]
    resolution: PR26 correctly refused to claim MLX text provenance; PR27 may add it as a separate narrow slice.
drift_signals:
  - Local MLX generate is live but has no AgentEvent recorder.
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
usefulness_reason: Authorizes a bounded MLX generate AgentEvent source without broad runtime changes.
---

## Reconciled findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` keeps AgentEvent in the substrate spine.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §9` anchors the local model/runtime lane.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` says remaining broader runtime AgentEvent coverage is still open after PR26.
- `Epistemos/Engine/MLXInferenceService.swift:541` is the direct MLX generate seam.
- `Epistemos/App/AppBootstrap.swift:1357` now has the shared local runtime recorder.

## Recommended slice shape

Instrument only `LocalMLXClient.generate(...)` with optional recorder injection, bounded metadata, and sanitized result/failure classes. Mount the same PR26 recorder into `LocalMLXClient` from `AppBootstrap`. Do not instrument `stream(...)`, change model loading/routing, or touch EventStore schema/UI/graph/Rust/Hermes/MCP/Sovereign/ANE surfaces.

## Failure-proof guardrails

- grep: `toolName: "local_generate.mlx"` in `Epistemos/Engine/MLXInferenceService.swift`
- log: `✔ Test "local mlx generate records sanitized AgentEvents" passed`
- test: `LocalBackendLLMClientTests/localMLXGenerateRecordsSanitizedAgentEvents`
