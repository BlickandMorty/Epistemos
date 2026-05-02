# Hermes Gateway Policy PR4 Deliberation - 2026-05-02

## Gate Decision

Approved for a tiny pure-Swift Hermes gateway policy slice.

This PR may add a canonical local policy object for deciding which
Hermes-shaped surfaces are Core-safe and which are Pro/Research gateway work.

## Intent

- Keep the user-facing architecture unified without making Hermes a slow wrapper
  around deterministic local substrate answers.
- Make it explicit that local Hermes-family prompt formatting can be Core-safe
  when it is in-process over local context.
- Make cloud providers, CLI delegation, MCP/web tools, Hermes subprocesses,
  browser/computer-use, Docker/devcontainer work, and explicit external side
  effects Pro/Research-only surfaces.
- Separate "needs network" from "requires Pro subprocess/external authority":
  local CLI delegation may be offline but is still a Pro/Research external
  gateway surface.

## Allowed Write Set

- `Epistemos/LocalAgent/HermesGatewayPolicy.swift`
- `Epistemos/LocalAgent/HermesPromptBuilder.swift`
- `EpistemosTests/HermesGatewayPolicyTests.swift`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- This deliberation note

## Forbidden Without New Runtime Gate

- Provider adapters, direct cloud calls, auth/OAuth, secrets, entitlements, or
  Xcode project changes.
- Subprocess launchers, MCP bridges, browser/computer-use routes, Docker, or
  devcontainer orchestration.
- Core/App Store route changes, production provider routing, graph, Rust,
  generated bindings, protected editor files, Omega, OpLog, AgentEvent, or
  GraphEvent surfaces.
- Any code that makes Hermes the graph, Rex, deterministic substrate, durable
  state authority, or required hop for already-local deterministic answers.

## Evidence Plan

- Red:
  `/tmp/epistemos-hermes-gateway-policy-pr4-red-20260502.log`
- Green:
  `/tmp/epistemos-hermes-gateway-policy-pr4-green-20260502.log`
- Focused command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/HermesGatewayPolicyTests -only-testing:EpistemosTests/HermesPromptBuilderTests test`

## Acceptance

- Focused policy tests fail before the policy exists and pass after it.
- `HermesPromptBuilder` pulls the tier-boundary wording from the policy rather
  than re-declaring it.
- No runtime adapter, provider, subprocess, MCP, graph, Rust, generated
  transport, entitlement, protected editor, or project path is touched.
