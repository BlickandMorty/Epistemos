---
role: aggregator
source_fleet: codex-own
slice: agent-event-apple-intelligence-generate-pr33
date: 2026-05-03
detectives_consumed:
  - detectives/apple-intelligence-generate-agent-event.md
web_consumed:
  - web/apple-foundation-models.md
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
  zero: 1
  minus_one: 0
usefulness: +1
usefulness_reason: Opens a narrow runtime provenance slice with exact files and tests.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §0 H3 makes Apple Intelligence a real runtime path, not a placeholder.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §12 allows Apple Intelligence in the Core/App Store bounded execution profile.
- `AppleIntelligenceService.swift:34` is the direct service boundary and has no `AgentToolProvenanceRecorder` today.
- `AppleIntelligenceService.swift:165` may augment prompts from the model vault, so persisted provenance must exclude prompt text and augmented prompt content.

## Recommended Slice Shape

Add requested, started, completed, and failed AgentEvents around `AppleIntelligenceService.generate(...)` with sanitized provider/surface/count metadata, bounded failure classes, and test-only injectable seams. Do not alter FoundationModels, thermal, breaker, routing, UI, graph, Rust, generated bindings, or EventStore schema.

## Failure-Proof Guardrails

- grep: `toolName: "apple_intelligence.generate"` in `Epistemos/Engine/AppleIntelligenceService.swift`
- log: focused `AppleIntelligenceServiceAgentEventTests` red then green logs
- test: `AppleIntelligenceServiceAgentEventTests`
