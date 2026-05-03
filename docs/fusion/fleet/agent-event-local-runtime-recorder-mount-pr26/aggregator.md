---
role: aggregator
source_fleet: codex-own
slice: agent-event-local-runtime-recorder-mount-pr26
date: 2026-05-03
detectives_consumed:
  - detectives/local-runtime-recorder-mount.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md, AppBootstrap.swift]
    resolution: Current code wins for live mount truth; closed PR24/PR25 APIs stay valid but need this mount slice.
drift_signals:
  - PR24/PR25 recorders exist, but AppBootstrap has not mounted them into the live local runtime clients.
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
usefulness_reason: Converts closed local runtime provenance APIs into live app wiring.
---

## Reconciled findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` defines AgentEvent as part of the substrate spine, so live runtime provenance belongs in the existing EventStore path.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:386` and `:400` close PR24/PR25 implementation but do not prove `AppBootstrap` recorder injection.
- `Epistemos/App/AppBootstrap.swift:1358` constructs `LocalGGUFClient` and `:1374` constructs `LocalBackendLLMClient`; those are the exact live mount points.
- `Epistemos/Engine/LocalGGUFClient.swift:625` and `Epistemos/Engine/LocalBackendLLMClient.swift:21` already expose the optional injection API, so no new recorder abstraction is needed.

## Recommended slice shape

Mount one shared `AgentToolProvenanceRecorder` in `AppBootstrap` for the local runtime clients, pass it to `LocalGGUFClient` and `LocalBackendLLMClient`, and prove the mount with a source-guard test. Do not instrument `LocalBackendLLMClient.generate(...)` at the router because GGUF generation is already recorded by the lower GGUF client and MLX text generation remains a separate future gate.

## Failure-proof guardrails

- grep: `let localRuntimeAgentProvenanceRecorder = AgentToolProvenanceRecorder()` in `Epistemos/App/AppBootstrap.swift`
- log: `✔ Test "bootstrap mounts local runtime AgentEvent recorder" passed`
- test: `LocalBackendLLMClientTests/bootstrapMountsLocalRuntimeAgentEventRecorder`
