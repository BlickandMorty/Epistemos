---
role: detective
slice: hermes-gateway-evidence-return-policy-pr7
concept: Hermes gateway evidence return policy
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §6
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/hermes_cloud_gateway_architecture_decision_2026_05_02.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/hermes_gateway_route_policy_pr6_deliberation_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/LocalAgent/HermesGatewayPolicy.swift:45
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/HermesGatewayPolicyTests.swift:5
deliberations_consulted:
  - docs/fusion/deliberation/hermes_cloud_gateway_architecture_decision_2026_05_02.md
  - docs/fusion/deliberation/hermes_gateway_route_policy_pr6_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - hermes-parity
drift:
  detected: false
  canon_says: "structured evidence back into the substrate"
  code_says: "[paraphrase] HermesGatewayPolicy classifies route/tier today, but not required evidence-return shape."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/hermes_cloud_gateway_architecture_decision_2026_05_02.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/LocalAgent/HermesGatewayPolicy.swift
load_bearing_quote: "cloud output is evidence to verify"
verdict: open
usefulness: +1
usefulness_reason: Identifies a pure-policy PR7 that makes the Hermes gateway return contract mechanical.
---

## Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §6` anchors Hermes / Pro tunnels / MCP as the external gateway domain.
- Card 10 PR1-PR6 already closed prompt wording, Core/App Store allowance, and route classification.
- The architecture decision says Hermes returns structured evidence to the substrate, not graph/Rex authority, but `HermesGatewayPolicy.Decision` does not yet expose a mechanical evidence-return field.
- A policy-only addition can preserve direct local substrate speed while requiring every external gateway surface to return structured evidence/provenance.

## Open Questions

- None for this PR. Runtime/provider adapters remain forbidden until a later exact gate.

## Recommendation

Add a small evidence-return enum and helpers to `HermesGatewayPolicy`, then test that direct local substrate and in-process prompt formatting do not require gateway evidence while every external gateway route does.
