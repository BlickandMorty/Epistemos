---
role: detective
slice: hermes-provider-surface-policy-pr8
concept: Hermes provider surface cloud gateway policy
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §6, §12, §22
tier: Pro
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/LocalAgent/HermesGatewayPolicy.swift:1
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/HermesGatewayPolicyTests.swift:1
deliberations_consulted:
  - docs/fusion/deliberation/hermes_gateway_evidence_return_policy_pr7_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "Cloud/provider/CLI/MCP/Hermes subprocess orchestration is Pro/Research only."
  code_says: "[paraphrase] Policy has a generic cloudProvider case but not named provider surfaces."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/LocalAgent/HermesGatewayPolicy.swift
load_bearing_quote: "Cloud/provider/CLI/MCP/Hermes subprocess orchestration is Pro/Research only."
verdict: open
usefulness: +1
usefulness_reason: Converts the user's Hermes-as-cloud-gateway preference into a named policy invariant without runtime churn.
---

## Findings

- Card 10 allows pure policy follow-up in `HermesGatewayPolicy.swift` and tests.
- Current policy already sends the generic `cloudProvider` surface to `.hermesGateway`, but named cloud provider routes are not yet mechanically represented.
- A small enum expansion keeps the policy direct: no provider adapters, no subprocess launchers, no MCP bridges, no network calls, and no App Store entitlement changes.

## Open Questions

- Runtime migration of live `CloudLLMClient` paths to Hermes remains a later Pro/Research gate.

## Recommendation

Add named cloud-provider surfaces to `HermesGatewaySurface`, group them in a
`cloudProviderSurfaces` list, and prove every named provider routes through the
Hermes gateway with structured evidence provenance.
