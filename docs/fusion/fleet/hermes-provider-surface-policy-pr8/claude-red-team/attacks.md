---
role: claude-red-team
slice: hermes-provider-surface-policy-pr8
brief: docs/fusion/deliberation/hermes_provider_surface_policy_pr8_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 3
p0_attacks: 0
p1_attacks: 2
p2_attacks: 1
p3_attacks: 0
verdict: brief-revise
usefulness: +1
usefulness_reason: Adds first-class named cloud surfaces with correct proResearch/hermesGateway/requiresNetwork/structuredEvidenceProvenance invariants while keeping local substrate Core-safe.
---

## Attacks

### A1 - `cloudProvider` absent from `cloudProviderSurfaces` - silent non-exhaustive set [P1]

**Surface:** `HermesGatewayPolicy.swift:36-42` / `HermesGatewayPolicyTests.swift:112-135`

**Attack:** `cloudProviderSurfaces` declares itself the canonical set of cloud provider surfaces but omits the legacy `.cloudProvider` case, which remains alive in the enum, in `externalGatewaySurfaces`, and in the `decision` switch arm sharing the same case group as the five named providers. Any future runtime consumer that iterates `cloudProviderSurfaces` to enumerate all cloud surfaces for policy enforcement will silently skip `.cloudProvider`.

**Evidence:** `HermesGatewayPolicy.swift:36-42` - `cloudProvider` not in `cloudProviderSurfaces`; `HermesGatewayPolicy.swift:44-57` - `cloudProvider` is in `externalGatewaySurfaces`; `HermesGatewayPolicyTests.swift:122` - equality check against the five-item array.

**Mitigation proposed:** Include `.cloudProvider` in `cloudProviderSurfaces` so the set is exhaustive.

### A2 - `externalGatewaySurfaces` does not compose from `cloudProviderSurfaces` - maintenance gap for future providers [P1]

**Surface:** `HermesGatewayPolicy.swift:44-57`

**Attack:** `externalGatewaySurfaces` manually re-lists all five named providers inline rather than including `cloudProviderSurfaces` as a sub-sequence. If a sixth named provider is added to the enum and to `cloudProviderSurfaces`, a developer must also remember to add it to `externalGatewaySurfaces`.

**Evidence:** `HermesGatewayPolicy.swift:44-57` - named providers manually enumerated; no `cloudProviderSurfaces` reference.

**Mitigation proposed:** Rewrite `externalGatewaySurfaces` to compose from `cloudProviderSurfaces` and add a test proving all cloud provider surfaces are also external gateway surfaces.

### A3 - `cloudProvider` omission from `cloudProviderSurfaces` is undocumented - future maintainer trap [P2]

**Surface:** `HermesGatewayPolicy.swift:36-42`

**Attack:** The exclusion of `.cloudProvider` from `cloudProviderSurfaces` is intentional or harmless right now, but there is no comment, deprecation marker, or test asserting the exact membership of the set.

**Evidence:** `HermesGatewayPolicyTests.swift:122` - array equality check; no comment in `cloudProviderSurfaces` explaining the `cloudProvider` omission.

**Mitigation proposed:** Include `.cloudProvider` in `cloudProviderSurfaces`, which removes the ambiguity.

## Brief verdict

The brief is correctly scoped: policy-only, no forbidden files touched, named providers all correctly wired as proResearch/hermesGateway/requiresNetwork/structuredEvidenceProvenance, and the core directness invariant is preserved. The initial PR introduced two structural gaps that undermine the cloud-provider surface contract: the generic `.cloudProvider` case was absent from the cloud provider set, and the external gateway list was not composed from that set. Both are small policy/test fixes.

## Codex Resolution

- A1 addressed: `.cloudProvider` is now included in `HermesGatewayPolicy.Surface.cloudProviderSurfaces`.
- A2 addressed: `externalGatewaySurfaces` now composes from `cloudProviderSurfaces`.
- A3 addressed: including `.cloudProvider` removes the undocumented-omission ambiguity.
- Verification: `/tmp/epistemos-hermes-provider-surface-pr8-green-20260502.log` shows 13 focused `HermesGatewayPolicyTests` passed, including `named cloud provider surfaces are gateway only` and `external gateway surfaces compose all cloud provider surfaces`.

CLAUDE-RETURN: role=RED-TEAM | slice=hermes-provider-surface-policy-pr8 | round=38 | artifact=docs/fusion/fleet/hermes-provider-surface-policy-pr8/claude-red-team/attacks.md | usefulness=+1 | p0=0 | p1=2
