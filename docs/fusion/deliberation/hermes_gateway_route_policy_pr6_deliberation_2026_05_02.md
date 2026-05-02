# Hermes Gateway Route Policy PR6 Deliberation - 2026-05-02

## Slice

Card 10 Hermes Gateway Directness PR6 adds an explicit route classification to
the pure Swift Hermes gateway policy.

## Gate

Extend `HermesGatewayPolicy` so each Hermes-shaped surface has a route:
`directSubstrate`, `inProcessLocalPrompt`, or `hermesGateway`. Local
deterministic substrate work must stay direct, local Hermes-family prompt
formatting must stay in-process, and all external cloud/CLI/MCP/browser/Docker/
side-effect surfaces must route through the unified Hermes gateway.

## Boundaries

No provider adapter, cloud request, subprocess launcher, MCP bridge,
browser/computer-use action, Docker/devcontainer route, auth service, entitlement,
Xcode project, graph, Rust, generated transport, generated library, protected
graph, or protected editor changes.

## Files

- `Epistemos/LocalAgent/HermesGatewayPolicy.swift`
- `EpistemosTests/HermesGatewayPolicyTests.swift`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/deliberation/hermes_gateway_route_policy_pr6_deliberation_2026_05_02.md`

## Evidence

- Red log: `/tmp/epistemos-hermes-gateway-route-pr6-red-20260502.log`
- Green focused Swift Testing: `/tmp/epistemos-hermes-gateway-route-pr6-green-20260502.log`
- Note: the focused policy suite passed 8 tests with `TEST SUCCEEDED`; Xcode
  still printed known SwiftLint package-plugin noise after success.

## Approval

Approved for this exact PR6 only.
