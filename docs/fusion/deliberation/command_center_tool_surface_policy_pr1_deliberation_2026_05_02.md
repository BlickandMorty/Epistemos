# Command Center Tool Surface Policy PR1 Deliberation — 2026-05-02

Slice:          Distribution-aware Core/MAS context-provider visibility for Agent Command Center.
Tier:           Core
Files touched:
- `/Users/jojo/Downloads/Epistemos/Epistemos/State/AgentCommandCenterState.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/AgentCommandCenterStateTests.swift`
Protected paths:
- `Epistemos/Omega/**`
- `Epistemos/Engine/**`
- `Epistemos/Views/**`
- `graph-engine/**`
- `agent_core/**`
- generated Swift/header bindings, entitlements, project files.
Gate:           SovereignGate touchpoint? none
Risks:          P1 if Core/App Store still advertises Terminal/Automation/Safari agent mentions; P1 if Pro/Research loses those agent mentions; P1 if catalog filtering is only cosmetic.
Verification:   `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AgentCommandCenterStateTests test`, final log `/tmp/epistemos-command-center-tool-surface-pr1-green-r3-20260502.log`.
Rollback:       Revert the two Swift files and this slice's fusion artifacts.
Stop triggers:
- Any execution, provider routing, Omega dispatch, Rust, entitlement, project, graph, protected editor, or generated-binding change appears.
- The patch removes Notes/Files/vault/open-note context providers from Core.
- Claude Red Team returns an unaddressed P0/P1.

## Plan
1. Add failing tests proving `.coreAppStore` hides Safari, Terminal, and Automation built-in agent mentions while preserving Notes and Files.
2. Add a matching Pro/Research test proving all existing built-in agent mentions remain visible.
3. Add failing tests proving `.coreAppStore` filters loaded tool catalogs, enabled toggles, and `mcpToolsByAgent` when a loader returns Pro gateway tools, while `.proResearch` preserves them.
4. Add a constructor-injected `ToolSurfacePolicy.Distribution`, defaulting to `.currentBuild`, to avoid changing production call sites.
5. Filter the loaded tool catalog at the single `rebuildToolCatalog` fan-in and filter the built-in ACC agent context-provider list.
6. Add parser coverage proving manually typed `@Terminal` does not resolve when Core/App Store hides that provider.
7. Do not alter CommandInputParser internals, Omega, Rust, chat execution, UI wiring, providers, entitlements, project files, or generated bindings.

## Canon anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md §12`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §6`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §22.1`

## Workcard match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md card: Card 10 - Hermes Gateway Directness`
- Deviation: This is a follow-on Core/MAS visible-surface audit for the dormant Agent Command Center context-provider list, after ToolSurfacePolicy and Omega runtime dispatch are closed.

## Failure-proof guardrails (post-merge)
- grep: `rg -n 'toolSurfaceDistribution|isBuiltInAgentContextProviderVisible|coreAppStoreRefreshToolCatalogFiltersInjectedExternalTools|coreAppStoreManualExternalMentionDoesNotResolve' Epistemos/State/AgentCommandCenterState.swift EpistemosTests/AgentCommandCenterStateTests.swift`
- log: `** TEST SUCCEEDED **`
- test: `EpistemosTests/AgentCommandCenterStateTests`

## Fleet evidence packet
- `docs/fusion/fleet/command-center-tool-surface-policy-pr1/aggregator.md`
- `docs/fusion/fleet/command-center-tool-surface-policy-pr1/claude-red-team/attacks.md`

## Usefulness
usefulness: +1
usefulness_reason: Closes the remaining ACC context-provider visibility leak without touching execution or provider routing.
