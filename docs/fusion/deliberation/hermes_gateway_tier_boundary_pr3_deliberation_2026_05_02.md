# Hermes Gateway Tier Boundary PR3 Deliberation - 2026-05-02

## Gate Decision

Approved for a prompt-only Hermes tier-boundary invariant slice.

This PR may strengthen `HermesPromptBuilder.systemPrompt` and focused Swift
Testing coverage so future builders distinguish local Hermes-family prompt
formatting from Pro/Research external orchestration.

## Intent

- Keep the architecture unified without implying every Hermes-shaped path needs
  Wi-Fi, cloud, or a subprocess.
- Treat local Hermes-family prompt formatting as Core-safe only when it remains
  in-process over already-local context.
- Treat cloud providers, CLI delegation, MCP/web tools, and Hermes subprocess
  orchestration as Pro/Research-only external gateway work.
- Preserve the direct deterministic substrate path when no external context is
  needed.

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
- Core/App Store route changes, production provider routing, graph, Rust,
  generated bindings, protected editor files, Omega, OpLog, AgentEvent, or
  GraphEvent surfaces.
- Any wording that makes Hermes the graph, Rex, deterministic substrate, or
  durable state authority.

## Evidence Plan

- Red:
  `/tmp/epistemos-hermes-gateway-tier-boundary-pr3-red-20260502.log`
- Green:
  `/tmp/epistemos-hermes-gateway-tier-boundary-pr3-green-20260502.log`
- Focused command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/HermesPromptBuilderTests test`

## Acceptance

- The Hermes prompt says cloud/provider/CLI/MCP/Hermes subprocess
  orchestration is Pro/Research only.
- The prompt says local Hermes-family prompt formatting may remain Core-safe
  only when it runs in-process over local context.
- Focused Hermes prompt tests fail before the prompt change and pass after it.
