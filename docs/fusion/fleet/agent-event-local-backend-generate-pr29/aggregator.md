---
role: aggregator
source_fleet: codex-own
slice: agent-event-local-backend-generate-pr29
date: 2026-05-03
detectives_consumed:
  - detectives/local-backend-generate-agent-event.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts: []
drift_signals:
  - Canon says LocalBackend generate is uninstrumented; current code confirms it.
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
usefulness_reason: Converts an explicitly named gap into a narrow buildable PR29 brief.
---

## Reconciled findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §8 and §9 anchor this runtime provenance slice.
- Current state documents PR25 stream provenance as closed while naming `LocalBackendLLMClient.generate(...)` as not covered by PR26.
- Current code confirms generate delegates directly to lower clients without router-level AgentEvent lifecycle records.
- Existing PR25 helpers provide the closest implementation pattern, but the brief must require a shared helper rather than copy-pasting stream-only code.

## Recommended slice shape

Authorize one Core-only router-level provenance slice in `LocalBackendLLMClient.generate(...)`: requested and started before runtime refresh/resolve, completed after the selected lower client returns, failed on routing/runtime/backend errors, with generated output counted but not persisted.

## Failure-proof guardrails

- grep: `local_backend.generate` appears in `Epistemos/Engine/LocalBackendLLMClient.swift`
- log: `✔ Test run with 16 tests in 1 suite passed`
- test: `LocalBackendLLMClientTests`
