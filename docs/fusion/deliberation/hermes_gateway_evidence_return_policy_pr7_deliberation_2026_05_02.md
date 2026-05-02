# Hermes Gateway Evidence Return Policy PR7 Deliberation - 2026-05-02

## Tier

Core. Pure local policy helper; no provider, subprocess, MCP, browser, Docker, entitlement, graph, Rust, generated transport, or UI path.

Gate: SovereignGate touchpoint? none.

## Slice

Extend `HermesGatewayPolicy` so route classification also declares the required evidence-return shape. Direct local substrate remains direct, local Hermes-family prompt formatting remains in-process, and every external Hermes gateway surface must return structured evidence/provenance rather than graph/Rex authority.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §6` - Hermes / Pro Tunnels / MCP.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §12` - App Store release / Core-MAS split.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md Card 10` - Hermes Gateway Directness.
- `docs/fusion/deliberation/hermes_cloud_gateway_architecture_decision_2026_05_02.md` - Hermes returns evidence, not substrate authority.

## Current Code Truth

- `Epistemos/LocalAgent/HermesGatewayPolicy.swift` currently classifies tier, network, subprocess need, direct-substrate preservation, and route.
- `EpistemosTests/HermesGatewayPolicyTests.swift` currently proves PR4-PR6 policy invariants with 8 tests.
- No production runtime adapter is needed for this slice.

## Allowed Files/Subsystems

- `Epistemos/LocalAgent/HermesGatewayPolicy.swift`
- `EpistemosTests/HermesGatewayPolicyTests.swift`
- `docs/fusion/fleet/hermes-gateway-evidence-return-policy-pr7/**`
- `docs/fusion/deliberation/hermes_gateway_evidence_return_policy_pr7_deliberation_2026_05_02.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `docs/fusion/fleet/REGISTRY.md`

## Forbidden Files/Subsystems

- Provider adapters, cloud requests, URL sessions, subprocess launchers, MCP bridges, browser/computer-use actions, Docker/devcontainer routes, OAuth/auth services, entitlements, Xcode project files.
- `Epistemos/Views/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- generated bindings, generated libraries, DerivedData, `.xcresult`, benchmark JSON artifacts.

## Implementation Contract

- Add a small sendable enum such as `HermesGatewayEvidenceReturn` with cases for no gateway evidence, in-process prompt context, and structured evidence/provenance.
- Add the evidence-return field to `HermesGatewayDecision`.
- Add helper methods so call sites can ask `evidenceReturn(for:)` and `requiresStructuredEvidenceReturn(_:)`.
- Direct local substrate and local prompt formatting must not require Hermes gateway evidence.
- Every `Surface.externalGatewaySurfaces` member must require structured evidence/provenance.
- Do not add runtime routing, provider calls, subprocesses, MCP/web calls, prompt wording, App Store entitlements, or UI.

## Acceptance

- Red test fails first because `HermesGatewayEvidenceReturn`, `evidenceReturn(for:)`, and `requiresStructuredEvidenceReturn(_:)` do not exist.
- Green focused tests prove direct substrate returns no gateway evidence.
- Green focused tests prove local prompt formatting is in-process evidence/context, not external structured evidence.
- Green focused tests prove every external gateway surface requires structured evidence/provenance and uses `.hermesGateway`.
- Guardrails prove no provider/subprocess/MCP/browser/Docker/runtime/entitlement/UI/Rust/generated files changed.

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 10 - Hermes Gateway Directness.
- Deviation: none. This is a pure policy follow-up explicitly allowed by Card 10.

## Failure-Proof Guardrails (Post-Merge)

- grep: `HermesGatewayEvidenceReturn`
- grep: `requiresStructuredEvidenceReturn`
- grep: `structuredEvidenceProvenance`
- forbidden grep: `Process\\.|URLSession|MCPBridge|Docker|LAContext|evaluatePolicy`
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core Epistemos.xcodeproj`
- log: `Hermes Gateway Policy`
- test: `EpistemosTests/HermesGatewayPolicyTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/hermes-gateway-evidence-return-policy-pr7/aggregator.md`
- `docs/fusion/fleet/hermes-gateway-evidence-return-policy-pr7/detectives/hermes-gateway.md`
- `docs/fusion/fleet/hermes-gateway-evidence-return-policy-pr7/detectives/core-mas-boundary.md`
- `docs/fusion/fleet/hermes-gateway-evidence-return-policy-pr7/red-team/attacks.md` (added after red team returns)

## Usefulness

usefulness: +1
usefulness_reason: Makes the Hermes-as-gateway philosophy executable in policy without adding gateway tax to direct local substrate paths.
