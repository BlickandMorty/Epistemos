---
role: aggregator
source_fleet: codex-own
slice: agent-event-v16-forward-variants-pr34
date: 2026-05-03
detectives_consumed:
  - detectives/agent-event-v16-forward-variants.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [codex-explorer/Boyle, codex-explorer/Hegel]
    resolution: Hegel's warning wins on live-runtime scope; Boyle's Swift vocabulary seed is allowed only as durable forward compatibility with tests and explicit no-emitter/no-UI boundary.
drift_signals:
  - H6 names simulation v1.6 variants as absent from main; main has no live Rust AgentEvent enum but does have Swift durable provenance vocabulary.
tier: Pro
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
usefulness_reason: Resolves H6 into a commit-sized vocabulary/persistence slice without claiming live simulation behavior.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §0 H6` corrects older canon: the six
  v1.6 variants are documented forward references, not shipped main runtime
  behavior.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §11` says simulation worktree material is
  Pro design DNA and donor-only while frozen.
- `Epistemos/Models/AgentProvenanceEvent.swift:3` is the live durable
  provenance vocabulary in main, so PR34 may add raw values there only.
- `Epistemos/State/EventStore.swift:217` stores kind text and full JSON; the
  slice can test persistence without changing schema.

## Recommended Slice Shape

Add `.steerRequested`, `.summaryStarted`, `.summaryDelta`,
`.summaryCompleted`, `.vaultCreated`, and `.vaultArchived` to
`AgentProvenanceEventKind` with lower-snake-case raw values. Add a focused
Swift Testing suite that proves vocabulary membership, Codable round-trip, and
EventStore persistence with `tool == nil` and `status=forward_variant_only`.

## Failure-Proof Guardrails

- grep: `rg -n 'steerRequested|summaryStarted|summaryDelta|summaryCompleted|vaultCreated|vaultArchived' Epistemos/Models/AgentProvenanceEvent.swift`
- log: `Test Suite 'Selected tests' passed`
- test: `EpistemosTests/AgentEventV16ForwardVariantTests`
