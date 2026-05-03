# Omega Tool Registry Core Planning PR1 Deliberation — 2026-05-02

Slice:          Distribution-aware Omega planning schemas and prompt block.
Tier:           Core
Files touched:
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/MCPBridge.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/OmegaToolSchemaGrammarTests.swift`
Protected paths:
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `agent_core/**` code remains read-only for this slice.
Gate:           SovereignGate touchpoint? none
Risks:          P1 if the full Omega MCP catalog remains visible in Core planning schemas; P1 if runtime registration/execution is changed.
Verification:   `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ToolSchemaGrammarTests test`, logs `/tmp/epistemos-omega-tool-registry-core-planning-pr1-red-20260502.log` and `/tmp/epistemos-omega-tool-registry-core-planning-pr1-green-final-20260502.log`.
Rollback:       Revert the two Swift files and this slice's fusion artifacts.
Stop triggers:
- Any runtime MCP dispatcher, tool execution, Rust, project, entitlement, graph, or protected editor change appears.
- Core/App Store prompt block still contains terminal, automation, or computer-use tools.
- Claude Red Team returns an unaddressed P0/P1.

## Plan
1. Add failing tests that call explicit `.coreAppStore` Omega planning helpers and prove terminal/automation/computer-use names disappear.
2. Implement distribution-aware `surfacedTools`, `planningSchemas`, `planningSchemasJson`, `catalogJson`, and `planningPromptBlock` helpers on `OmegaToolRegistry`.
3. Keep default current-build behavior so Pro/Research planning still has its full gateway catalog.
4. Keep `MCPBridge.builtinCatalogJson(distribution:)` Rust-authoritative by filtering raw `builtinToolsJson()` output instead of rebuilding catalog entries from a Swift mirror.
5. Leave runtime MCP registration and `dispatch(_:)` unchanged; execution-layer gating is a follow-on slice, not part of this planning-visibility patch.

## Canon anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md §12`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §6`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §22.1`

## Workcard match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md card: Card 10 - Hermes Gateway Directness`
- Deviation: This is the Omega planning-schema complement to Core/MAS Tool Surface Policy PR1, not a Hermes runtime/provider adapter.

## Failure-proof guardrails (post-merge)
- grep: `rg -n 'surfacedTools\\(distribution|planningSchemas\\(distribution|catalogJson\\(distribution|planningPromptBlock\\(distribution|builtinCatalogJson\\(distribution' Epistemos/Omega/MCPBridge.swift EpistemosTests/OmegaToolSchemaGrammarTests.swift`
- log: `** TEST SUCCEEDED **`
- test: `EpistemosTests/ToolSchemaGrammarTests`

## Fleet evidence packet
- `docs/fusion/fleet/omega-tool-registry-core-planning-pr1/aggregator.md`
- `docs/fusion/fleet/omega-tool-registry-core-planning-pr1/claude-red-team/attacks.md`

## Usefulness
usefulness: +1
usefulness_reason: Applies the newly closed ToolSurfacePolicy guard to Omega planning JSON and prompt surfaces.
