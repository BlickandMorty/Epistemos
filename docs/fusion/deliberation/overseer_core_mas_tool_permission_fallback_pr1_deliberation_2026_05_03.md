# Overseer Core/MAS Tool Permission Fallback PR1 Deliberation

Slice:          Overseer Core/MAS tool permission fallback PR1
Tier:           Core
Files touched:
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/OverseerProtocol.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/OverseerProtocolTests.swift`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/overseer-core-mas-tool-permission-fallback-pr1/`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
Protected paths:
- no `Epistemos/Sovereign/` changes
- no `Epistemos/Bridge/ToolTierBridge.swift`, `Epistemos/Omega/**`, `agent_core/**`, `graph-engine/**`, generated bindings, entitlements, project files, UI, graph, providers, runtime routing, Hermes, MCP, subprocess, browser/computer-use, Docker, or ANE/private API changes
Gate:           SovereignGate touchpoint? none
Risks:          P0 if Core/App Store fallback advertises shell/CLI/browser/Docker/Hermes gateway names; P1 if Pro/Research fallback loses existing ask-mode behavior; P1 if the patch creates a second policy table instead of using `ToolSurfacePolicy`
Verification:   focused red/green Swift tests with logs under `/tmp/epistemos-overseer-core-mas-tool-permission-fallback-pr1-*.log`; shell source-shape guard; invariant grep; `git diff --check`
Rollback:       remove the helper/test additions and PR1 doc rows
Stop triggers:
- implementation touches ToolTierBridge, Omega dispatch, providers, Rust, generated bindings, entitlements, project files, UI, graph, or runtime routing
- implementation broadens `ToolSurfacePolicy.coreAppStoreAllowedToolNames`
- Core/App Store fallback still includes `run_command`, `open_url`, `search_web`, browser/computer-use, Docker, MCP, or Hermes gateway names
- focused red test cannot fail before implementation

## Scope

This slice closes a degraded-registry fallback leak in `OverseerProtocol`. When the live Omega tool registry produces no usable permissions, the fallback list must still obey the same Core/App Store tool surface policy that closed prior ToolSurface, Omega dispatch, Command Center, and ToolTier gates.

## Implementation Order

1. Add a focused failing `OverseerProtocolTests` test proving Core/App Store fallback permissions hide `run_command`, `open_url`, and `search_web` while keeping allowed Core names.
2. Add a focused test proving Pro/Research fallback still preserves the existing external ask-mode names.
3. Add `OverseerComplexityRouter.fallbackToolPermissions(distribution:)` and use it from the existing `toolPermissions(for:)` fallback branch.
4. Filter the fallback through `ToolSurfacePolicy.isSurfacedToolName` instead of creating a new allow-list.
5. Run focused tests, shell source-shape guard, forbidden-source greps, and `git diff --check`.

## Acceptance

- Core/App Store fallback permissions contain no `run_command`, `open_url`, `search_web`, browser/computer-use, Docker, MCP, or Hermes gateway names.
- Core/App Store fallback permissions only contain names that `ToolSurfacePolicy.isSurfacedToolName(..., distribution: .coreAppStore)` allows.
- Pro/Research fallback still includes the existing ask-mode external names when explicitly requested through the helper.
- No Core allow-list expansion, ToolTier/Omega/provider/Rust/runtime/UI work, or generated binding change is introduced.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §12
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` Core/MAS release split and ToolTier PR2 closure
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 10
- Apple App Review Guidelines 2.5.2, verified 2026-05-03

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 10 - Hermes Gateway Directness
- Deviation: This is a follow-on Core/MAS exact gate for an Overseer fallback branch, not a Hermes runtime/provider integration.

## Failure-Proof Guardrails (post-merge)

- grep: `awk '/private func toolPermissions\\(for route:/{flag=1} /private func permissionMode\\(for tool:/{flag=0} flag {print}' Epistemos/Engine/OverseerProtocol.swift | rg -n 'Self\\.fallbackToolPermissions\\(distribution: \\.currentBuild\\)|OverseerToolPermission\\(toolName: "run_command"'`
- log: `/tmp/epistemos-overseer-core-mas-tool-permission-fallback-pr1-green2-20260503.log` contains `** TEST SUCCEEDED **`
- test: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/OverseerProtocolTests test`

## Fleet Evidence Packet

- `docs/fusion/fleet/overseer-core-mas-tool-permission-fallback-pr1/detectives/overseer-core-mas-tool-permission-fallback.md`
- `docs/fusion/fleet/overseer-core-mas-tool-permission-fallback-pr1/web/apple-app-review-guideline-252.md`
- `docs/fusion/fleet/overseer-core-mas-tool-permission-fallback-pr1/aggregator.md`
- `docs/fusion/fleet/overseer-core-mas-tool-permission-fallback-pr1/claude-red-team/attacks.md` (to be added after Red Team)

## Usefulness

usefulness: +1
usefulness_reason: Closes a real Core/MAS degraded-registry fallback leak without reopening prior ToolTier/Omega/runtime gates.
