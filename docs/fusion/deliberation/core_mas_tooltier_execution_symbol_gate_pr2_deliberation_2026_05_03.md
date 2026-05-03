# Core/MAS ToolTier Execution Symbol Gate PR2 Deliberation - 2026-05-03

Slice: `core-mas-tooltier-execution-symbol-gate-pr2`
Tier: Core

## Gate

Mirror the existing `MCPBridge` runtime policy gate in `ToolTierBridge` so hidden Core/App Store tool names are denied before Rust FFI execution.

## Approved Files

- `/Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ToolTierBridge.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/ToolSurfacePolicyTests.swift`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/**`

## Explicitly Not Approved

- `Epistemos/Omega/MCPBridge.swift`
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Engine/PipelineService.swift`
- `Epistemos/Omega/**`
- `agent_core/**`
- `graph-engine/**`
- generated bindings, entitlements, Xcode project files
- provider routing, Hermes subprocesses, MCP tunnels, browser/computer-use implementation
- note editor or graph rendering files

## Plan

1. Add a failing focused test proving `.coreAppStore` `ToolTierBridge.toolExecutor()` returns a local error for representative Pro-only tool names before FFI.
2. Add companion assertions that `.proResearch` still reaches the existing bindings-unavailable fallback in unit-test builds, proving Pro behavior was not blocked by the new gate.
3. Add a `ToolSurfacePolicy.Distribution` parameter to `ToolTierBridge`, defaulting to `.currentBuild`.
4. Use the distribution in `loadTools()` and in the execution closure.
5. Return the same "Tool not found" style local error used by MCP runtime policy for hidden Core/App Store tool names.

## Acceptance

- Core/App Store explicit tool calls such as `run_command`, `run_persistent`, `get_ui_tree`, `see`, `click`, `browser_navigate`, `docker_run`, and `hermes_subprocess` are denied before FFI.
- Allowed Core tools still reach the existing FFI/fallback path.
- Pro/Research still reaches the existing FFI/fallback path for Pro-only names.
- No provider, Omega, ChatCoordinator, PipelineService, Rust, entitlement, Xcode project, graph, or editor files are touched.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §12`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §6`
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:958`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:2129`

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md card: Card 10 - Hermes Gateway Directness`
- Deviation: This is the next Core/MAS release-split execution seam after visible/planning surfaces were already closed.

## Failure-Proof Guardrails (Post-Merge)

- grep: `rg -n "distribution: ToolSurfacePolicy.Distribution|Tool not found:|toolExecutorDeniesCoreAppStoreHiddenTools" Epistemos/Bridge/ToolTierBridge.swift EpistemosTests/ToolSurfacePolicyTests.swift`
- log: `** TEST SUCCEEDED **`
- test: `EpistemosTests/ToolSurfacePolicyTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/core-mas-tooltier-execution-symbol-gate-pr2/aggregator.md`
- `docs/fusion/fleet/core-mas-tooltier-execution-symbol-gate-pr2/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Closes a real execution-layer Core/MAS symbol-separation seam without expanding app capability.
