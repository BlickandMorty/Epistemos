# Hermes Gateway Directness PR1 Deliberation - 2026-05-02

## Decision

Approved for a narrow prompt-level gateway-boundary slice.

## Goal

Keep Hermes unified without making it a slow wrapper around deterministic local
substrate work. The local Hermes-family prompt should state that Hermes is the
tool-call/external-intelligence membrane, not the graph, Rex, or substrate
authority. It should still prefer direct answers when context is already
available and only call tools for missing context or explicit side effects.

## Authority Read First

- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §3, §6, Annex A.12
- `docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md` §3.8
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `Epistemos/LocalAgent/HermesPromptBuilder.swift`
- `EpistemosTests/HermesPromptBuilderTests.swift`

## Allowed Write Set

- `Epistemos/LocalAgent/HermesPromptBuilder.swift`
- `EpistemosTests/HermesPromptBuilderTests.swift`
- `docs/fusion/deliberation/hermes_gateway_directness_pr1_deliberation_2026_05_02.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`

## Forbidden Write Set

- `Epistemos/Views/Graph/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- `epistemos-core/**`
- provider clients, OAuth/auth services, subprocess launchers, MCP bridges,
  browser/computer-use, Docker/devcontainer, entitlements, Xcode project files,
  generated bindings, generated libraries, DerivedData, `.xcresult`, or
  protected note editor files.

## Implementation Contract

- Add only prompt-level directness/gateway guidance and a focused source test.
- Do not add a subprocess, provider route, cloud call, CLI call, MCP call, or
  runtime selection path.
- Preserve the existing NousResearch Hermes XML tool-call format.
- Preserve the direct-answer rule when the answer is already available in
  conversation context, attached note text, or provided material.
- Do not frame Hermes as graph/Rex/substrate authority.

## Tests And Logs

- Red:
  `/tmp/epistemos-hermes-gateway-directness-pr1-red-20260502.log`
- Green:
  `/tmp/epistemos-hermes-gateway-directness-pr1-green-20260502.log`
- Focused command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/HermesPromptBuilderTests test`
- Guardrails:
  `git diff --check`
  staged protected-path scan

## Acceptance

- `HermesPromptBuilder.systemPrompt` preserves Hermes XML tool format.
- The prompt explicitly keeps Hermes as a membrane/control surface rather than
  the graph, Rex, or deterministic substrate authority.
- The prompt explicitly preserves direct local answers and avoids tool calls
  unless missing context or external side effects require them.
- Focused Hermes prompt builder tests pass.

## Stop Triggers

- The slice needs any subprocess, provider client, cloud request, CLI route, MCP
  route, graph/Rex/Rust/generated transport edit, or entitlement change.
- The prompt starts hiding cloud/tool side effects or telling Hermes to own the
  deterministic graph/substrate.
