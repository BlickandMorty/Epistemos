---
role: aggregator
source_fleet: codex-own
slice: hermes-provider-surface-policy-pr8
date: 2026-05-02
detectives_consumed:
  - detectives/hermes-provider-surface-policy.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: none
    sources: []
    resolution: none
drift_signals:
  - none
tier: Pro
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
usefulness_reason: Makes Hermes cloud-gateway exclusivity explicit for named provider surfaces.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §6 treats Hermes as the Pro tunnel and gateway concept area.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §12 keeps App Store/Core separation load-bearing; this slice remains pure policy and does not touch Core runtime adapters.
- Card 10 says pure policy follow-up may edit `HermesGatewayPolicy.swift` and `HermesGatewayPolicyTests.swift`.

## Recommended Slice Shape

Add named cloud-provider surfaces to `HermesGatewaySurface`, expose a
`cloudProviderSurfaces` group, include those surfaces in
`externalGatewaySurfaces`, and test that every named cloud provider requires the
Hermes gateway, Pro/Research tier, network, and structured evidence return.

## Failure-Proof Guardrails

- grep: `rg -n "cloudProviderSurfaces|openAIProvider|anthropicProvider|googleProvider|openAICompatibleProvider|codexAccountProvider" Epistemos/LocalAgent/HermesGatewayPolicy.swift EpistemosTests/HermesGatewayPolicyTests.swift`
- forbidden grep: `rg -n "URLSession|Process\\.|MCPBridge|DockerClient|DockerBridge|docker run|LAContext|evaluatePolicy" Epistemos/LocalAgent/HermesGatewayPolicy.swift EpistemosTests/HermesGatewayPolicyTests.swift` returns no matches.
- log: `✔ Test "named cloud provider surfaces are gateway only" passed`
- test: `HermesGatewayPolicyTests`
