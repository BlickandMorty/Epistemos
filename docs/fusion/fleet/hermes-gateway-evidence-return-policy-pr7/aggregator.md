---
role: aggregator
source_fleet: codex-own
slice: hermes-gateway-evidence-return-policy-pr7
date: 2026-05-02
detectives_consumed:
  - detectives/hermes-gateway.md
  - detectives/core-mas-boundary.md
web_consumed: []
claude_side_fleet_consumed:
  - none
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
  unclosed_core_blocker: none
ready_for_pipeline_builder: true
missing_artifacts: []
input_usefulness_rollup:
  plus_one: 2
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts the Hermes architecture decision into a small testable policy helper without runtime leakage.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §6` anchors Hermes as the external gateway domain; `MASTER_RESEARCH_INDEX_2026_05_02.md §12` anchors Core/MAS separation.
- Card 10 PR1-PR6 closed directness, fast path, tier boundary, App Store guard, and route policy; PR7 can add evidence-return semantics without runtime adapters.
- The new helper should preserve direct local substrate and in-process prompt formatting, and require structured evidence/provenance return for every `.hermesGateway` route.
- Preflight tier-leakage hits are existing policy classification references, not new runtime usage.

## Recommended Slice Shape

Approve a Core, pure-Swift PR7 that adds `HermesGatewayEvidenceReturn` plus `evidenceReturn(for:)` and `requiresStructuredEvidenceReturn(_:)` to `HermesGatewayPolicy`, with focused tests proving external gateway surfaces return structured evidence while local surfaces remain direct/in-process.

## Failure-Proof Guardrails

- grep: `HermesGatewayEvidenceReturn`
- grep: `requiresStructuredEvidenceReturn`
- grep: `structuredEvidenceProvenance`
- forbidden grep: `Process\\.|URLSession|MCPBridge|Docker|LAContext|evaluatePolicy`
- log: `Hermes Gateway Policy`
- test: `EpistemosTests/HermesGatewayPolicyTests`
