# Hermes Gateway App Store Guard PR5 Deliberation - 2026-05-02

## Gate Decision

Approved for a tiny pure-Swift policy follow-up.

This PR may add a Core/App Store allowance helper to `HermesGatewayPolicy`.
It must not add runtime routing, provider calls, subprocess launchers, MCP,
browser/computer-use, Docker/devcontainer, entitlement, project, graph, Rust,
generated transport, or protected editor changes.

## Intent

- Preserve the unified Hermes gateway model without making Core/App Store builds
  pay an unnecessary gateway hop.
- Make the Core/App Store lane mechanically explicit: only deterministic local
  substrate answers and in-process local prompt formatting are allowed.
- Keep cloud providers, CLI delegation, MCP/web tools, Hermes subprocesses,
  browser/computer-use, Docker/devcontainer work, and explicit external side
  effects Pro/Research-only.

## Allowed Write Set

- `Epistemos/LocalAgent/HermesGatewayPolicy.swift`
- `EpistemosTests/HermesGatewayPolicyTests.swift`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- This deliberation note

## Evidence Plan

- Red:
  `/tmp/epistemos-hermes-gateway-app-store-guard-pr5-red-20260502.log`
- Green:
  `/tmp/epistemos-hermes-gateway-app-store-guard-pr5-green-20260502.log`
- Focused command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/HermesGatewayPolicyTests test`

## Acceptance

- Focused policy tests fail before the Core/App Store helper exists and pass
  after it.
- The helper allows only direct, local, no-network, no-subprocess surfaces.
- No runtime adapter, provider, subprocess, MCP, graph, Rust, generated
  transport, entitlement, protected editor, or project path is touched.
