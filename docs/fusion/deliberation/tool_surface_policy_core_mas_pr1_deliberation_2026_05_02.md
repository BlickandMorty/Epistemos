# Tool Surface Policy Core/MAS PR1 Deliberation — 2026-05-02

Slice:          Swift visible tool-surface Core/MAS guard for Pro/Research gateway tools.
Tier:           Core
Files touched:
- `/Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ToolTierBridge.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/ToolSurfacePolicyTests.swift`
Protected paths:
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `agent_core/**` code remains read-only for this slice.
Gate:           SovereignGate touchpoint? none
Risks:          P1 if the Swift visible catalog drifts from the Rust MAS runtime forbidden list; P1 if local bounded tools are hidden by accident.
Verification:   `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ToolSurfacePolicyTests test`, logs `/tmp/epistemos-tool-surface-policy-core-mas-pr1-red-20260502.log` and `/tmp/epistemos-tool-surface-policy-core-mas-pr1-green-20260502.log`.
Rollback:       Revert the two Swift files and this slice's fusion artifacts.
Stop triggers:
- Any new provider adapter, subprocess launcher, MCP bridge, entitlement, project, Rust, graph, or protected editor change appears.
- The test requires hiding bounded local/vault tools.
- Claude Red Team returns an unaddressed P0/P1.

## Plan
1. Add a failing Swift Testing case proving known Core/MAS-forbidden gateway surfaces disappear from `ToolSurfacePolicy.surfacedTools`.
2. Add a conservative Core/App Store visible-surface allow-list in `ToolSurfacePolicy`, using the Rust MAS allowed runtime names as a starting point but excluding routing primitives such as `route_private` so new gateway tools fail closed.
3. Keep `vault_search`, `vault_read`, `read_file`, `search_files`, `web_search`, and `graph_query` visible so direct local/research read paths remain fast.
4. Add sandbox-env override coverage so `.proResearch` cannot bypass a real sandboxed/Core build ceiling.

## Canon anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md §12`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §6`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2`

## Workcard match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md card: Card 10 - Hermes Gateway Directness`
- Deviation: This slice touches the Swift visible tool-surface policy rather than `HermesGatewayPolicy` because the current master-plan safe order explicitly calls for Core/MAS release split auditing after PR8.

## Failure-proof guardrails (post-merge)
- grep: `rg -n 'coreAppStoreAllowedToolNames|bash_execute|browser_navigate|mcp_discover' Epistemos/Bridge/ToolTierBridge.swift EpistemosTests/ToolSurfacePolicyTests.swift`
- log: `** TEST SUCCEEDED **`
- test: `EpistemosTests/ToolSurfacePolicyTests` including sandbox-env override coverage.

## Fleet evidence packet
- `docs/fusion/fleet/tool-surface-policy-core-mas-pr1/aggregator.md`
- `docs/fusion/fleet/tool-surface-policy-core-mas-pr1/claude-red-team/attacks.md`

## Usefulness
usefulness: +1
usefulness_reason: Turns the documented Core/MAS leakage rule into a focused visible-planning regression test.
