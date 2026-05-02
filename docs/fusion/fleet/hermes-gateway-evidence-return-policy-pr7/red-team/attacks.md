---
role: codex-red-team
slice: hermes-gateway-evidence-return-policy-pr7
brief: docs/fusion/deliberation/hermes_gateway_evidence_return_policy_pr7_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 5
p0_attacks: 0
p1_attacks: 0
p2_attacks: 3
p3_attacks: 2
verdict: brief-approved
usefulness: +1
usefulness_reason: Approves the brief while tightening tests so evidence return stays policy-only and route-coupled.
---

## Attacks

### A1 - Evidence/provenance must remain policy declaration only [P2]

**Surface:** PR7 implementation contract.

**Attack:** The brief is safe only if evidence/provenance remains a policy declaration, not an enforcement or persistence claim. It must not imply AgentEvent, MutationEnvelope, OpLog, graph mutation, or runtime adapter wiring exists.

**Evidence:** `hermes_cloud_gateway_architecture_decision_2026_05_02.md` says Hermes returns evidence to verify, not substrate authority.

**Mitigation proposed:** Keep PR7 limited to enum/field/helper/tests. Update docs with "policy-only" wording after implementation.

### A2 - Missing exhaustive external-surface test [P2]

**Surface:** `EpistemosTests/HermesGatewayPolicyTests.swift`.

**Attack:** A future surface could be added to `externalGatewaySurfaces` without requiring structured evidence unless the tests loop across the entire list.

**Evidence:** Existing tests already loop through `Surface.externalGatewaySurfaces` for tier and route.

**Mitigation proposed:** Add a test that every external surface returns `structuredEvidenceProvenance` and `requiresStructuredEvidenceReturn(...) == true`.

### A3 - Missing route/evidence coupling test [P2]

**Surface:** `EpistemosTests/HermesGatewayPolicyTests.swift`.

**Attack:** A surface could route through `.hermesGateway` but forget the evidence return requirement, or vice versa.

**Evidence:** PR6 introduced `route(for:)`; PR7 must mechanically tie evidence return to this route.

**Mitigation proposed:** Add an exhaustive test: `.hermesGateway` implies structured evidence; `.directSubstrate` and `.inProcessLocalPrompt` imply no structured external evidence requirement.

### A4 - Core tier wording could be misread [P3]

**Surface:** PR7 brief.

**Attack:** "Tier: Core" is acceptable for Core-safe policy code, but implementation/tests must preserve that the external surfaces themselves remain `.proResearch`.

**Evidence:** Card 10 PR3-PR6 classify external gateway surfaces as Pro/Research.

**Mitigation proposed:** Keep existing Pro/Research tests green and do not weaken `isAllowedInCoreAppStoreBuild`.

### A5 - Enum naming could drift into authority claims [P3]

**Surface:** planned enum naming.

**Attack:** Names that sound like graph/ledger authority could imply Hermes owns durable substrate state.

**Evidence:** Architecture decision forbids Hermes-as-graph/Rex/substrate authority.

**Mitigation proposed:** Use neutral policy names such as `.none`, `.inProcessPromptContext`, and `.structuredEvidenceProvenance`.

## Brief Verdict

Brief approved. No P0/P1 blockers found. Implement PR7 as a pure policy/test change only.
