# Hermes Gateway Fast Path PR2 Deliberation - 2026-05-02

## Gate Decision

Approved for a prompt-only Hermes gateway invariant slice.

This PR may strengthen `HermesPromptBuilder.systemPrompt` and its focused
Swift Testing coverage so Hermes remains one unified gateway for external
intelligence while preserving the direct path for deterministic local substrate
answers.

## Intent

- Make Hermes feel unified without making it a wrapper around every answer.
- Keep cloud models, CLI delegation, MCP/web tools, and explicit external side
  effects behind one fast gateway concept.
- Prevent the gateway from adding latency when the answer is already available
  in local substrate context.
- Keep external evidence structured as artifacts and provenance, not graph,
  Rex, or durable-state authority.

## Allowed Write Set

- `Epistemos/LocalAgent/HermesPromptBuilder.swift`
- `EpistemosTests/HermesPromptBuilderTests.swift`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- This deliberation note

## Forbidden Without New Runtime Gate

- Provider adapters, direct cloud calls, auth/OAuth, secrets, entitlements, or
  Xcode project changes.
- Subprocess launchers, MCP bridges, browser/computer-use routes, Docker, or
  devcontainer orchestration.
- Graph renderer/controller files, `graph-engine/**`, `agent_core/**`,
  generated bindings, generated libraries, protected editor files, OpLog,
  GraphEvent, AgentEvent, Omega, or Sovereign surfaces.
- Any implementation that frames Hermes as Rex, graph authority, deterministic
  substrate authority, or durable state source of truth.

## Evidence Plan

- Red:
  `/tmp/epistemos-hermes-gateway-fast-path-pr2-red-20260502.log`
- Green:
  `/tmp/epistemos-hermes-gateway-fast-path-pr2-green-20260502.log`
- Focused command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/HermesPromptBuilderTests test`

## Acceptance

- The Hermes prompt states Hermes is the single fast gateway for cloud models,
  CLI delegation, MCP/web tools, and explicit external side effects.
- The prompt states deterministic local substrate answers stay on the direct
  path and must not pay a gateway hop when no external context is needed.
- The prompt states external evidence returns as structured artifacts and
  provenance rather than graph or Rex authority.
- Focused Hermes prompt tests fail before the prompt change and pass after it.
