# Omega Dispatch Core Execution Gate PR1 Deliberation — 2026-05-02

Slice:          Distribution-aware Swift gate for Omega JSON-RPC dispatch.
Tier:           Core
Files touched:
- `/Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ToolTierBridge.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/MCPBridge.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/OmegaToolSchemaGrammarTests.swift`
Protected paths:
- `Epistemos/Views/**`
- `Epistemos/Engine/**`
- `graph-engine/**`
- `agent_core/**`
- `omega-mcp/**`
Gate:           SovereignGate touchpoint? none
Risks:          P1 if runtime tool registration is changed; P1 if Core still dispatches terminal/automation/computer-use tool calls.
Verification:   `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ToolSchemaGrammarTests test` and `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ToolSurfacePolicyTests test`; logs `/tmp/epistemos-omega-dispatch-core-execution-gate-pr1-green-r2-20260502.log` and `/tmp/epistemos-omega-dispatch-core-execution-gate-pr1-tool-surface-green-20260502.log`.
Rollback:       Revert the three Swift files and this slice's fusion artifacts.
Stop triggers:
- Any Rust, project, entitlement, graph, engine, view, provider, or generated-binding file appears in the diff.
- `registerBuiltinTools()` or `McpDispatcher` registration semantics change.
- Core/App Store `tools/call` can still return pending for `run_command`, `run_persistent`, `get_ui_tree`, `see`, or `click`.
- Claude Red Team returns an unaddressed P0/P1.

## Plan
1. Add failing tests proving `.coreAppStore` dispatch hides Pro gateway tools from `tools/list`, denies `run_command`, and still allows `read_file`.
2. Add a distribution-aware overload/default parameter to `MCPBridge.dispatch`.
3. Expose `ToolSurfacePolicy.resolvedDistribution(_:)` to avoid duplicating Core/App Store detection.
4. Parse only JSON-RPC `tools/list` and `tools/call` for policy gating; let malformed/unknown requests continue to the Rust dispatcher.
5. Keep full runtime registration and Pro/Research dispatch behavior unchanged.

## Canon anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md §6`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §12`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §22.1`

## Workcard match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md card: Card 10 - Hermes Gateway Directness`
- Deviation: This is the runtime-dispatch complement to Omega Tool Registry Core Planning PR1.

## Failure-proof guardrails (post-merge)
- grep: `rg -n 'dispatch\\(_ requestJson: String, distribution:|policyGateResponse|jsonRpcError|resolvedDistribution' Epistemos/Bridge/ToolTierBridge.swift Epistemos/Omega/MCPBridge.swift EpistemosTests/OmegaToolSchemaGrammarTests.swift`
- log: `** TEST SUCCEEDED **`
- test: `EpistemosTests/ToolSchemaGrammarTests`
- test: `EpistemosTests/ToolSurfacePolicyTests`

## Fleet evidence packet
- `docs/fusion/fleet/omega-dispatch-core-execution-gate-pr1/aggregator.md`
- `docs/fusion/fleet/omega-dispatch-core-execution-gate-pr1/claude-red-team/attacks.md`

## Usefulness
usefulness: +1
usefulness_reason: Closes the runtime dispatch follow-on left by the approved Omega planning-surface slice.
