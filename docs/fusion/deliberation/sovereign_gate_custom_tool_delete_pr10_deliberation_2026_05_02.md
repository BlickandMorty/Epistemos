# Sovereign Gate Custom Tool Delete PR10 Deliberation - 2026-05-02

## Tier

Core. This migrates an existing destructive local custom-tool spec delete action through the shared native Sovereign Gate.

Gate: SovereignGate touchpoint? migrating-existing.

## Slice

Route `AgentControlSettingsView` custom-tool delete actions through `AppBootstrap.shared?.sovereignGate.confirm(...)` before executing the existing `deleteCustomTool(named:vaultPath:)` body.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` - Sovereign Gate.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §6` - Hermes / Pro tunnels / MCP; custom tools are external-capability adjacent and must not bypass the control membrane.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9 - Sovereign Gate Core Authorization.
- `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md §3.2` - Sovereign Gate touchpoint check.

## Current Code Truth

- `Epistemos/Views/Settings/AgentControlSettingsView.swift` has a custom-tool `Button("Delete")` that calls `deleteCustomTool(named:vaultPath:)` directly.
- `deleteCustomTool(named:vaultPath:)` sends a sorted JSON action payload to `tool_manage` and refreshes custom tools after success.
- `EpistemosTests/SovereignGateTests.swift` already contains PR5-PR9 mapping/source-guard tests for existing destructive migrations.

## Allowed Files/Subsystems

- `Epistemos/Views/Settings/AgentControlSettingsView.swift`
- `EpistemosTests/SovereignGateTests.swift`
- Deliberation/fleet/current-state/workcard docs under `docs/fusion/**`.

## Forbidden Files/Subsystems

- `Epistemos/Sovereign/SovereignGate.swift`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`
- `Epistemos/Views/Graph/**`
- `Epistemos/Graph/**`
- `agent_core/**`
- `graph-engine/**`
- Generated bindings, entitlements, Xcode project files, DerivedData, `.xcresult`

## Implementation Contract

- Do not import `LocalAuthentication` or instantiate `LAContext` outside `Epistemos/Sovereign/SovereignGate.swift`.
- Do not change `deleteCustomTool(named:vaultPath:)` semantics except to move execution behind an allowed Sovereign Gate outcome.
- Capture the exact tool name and vault path before async authorization; denied or unavailable auth must not delete.
- Keep existing create/edit/load/refresh/status behavior unchanged.
- Add focused tests first: mapper requirement/reason and source guard proving the button routes through `requestCustomToolDeleteAuthorization`.

## Acceptance

- Custom-tool delete targets map to `.deviceOwnerAuthentication` and human-readable reason strings.
- The custom-tool delete button routes to `requestCustomToolDeleteAuthorization(named:vaultPath:)` instead of directly calling `deleteCustomTool(named:vaultPath:)`.
- `requestCustomToolDeleteAuthorization(named:vaultPath:)` calls the shared app `SovereignGate`, denies safely by default, and calls `deleteCustomTool(named:vaultPath:)` only after `.allowed`.
- Source guard proves no duplicate biometric APIs appear in this file.

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 9 - Sovereign Gate Core Authorization.
- Deviation: none. This is a future confirmation-surface migration with the exact surface named.

## Failure-Proof Guardrails (Post-Merge)

- grep: `enum AgentControlSettingsDeletionSovereignGate`
- grep: `requestCustomToolDeleteAuthorization`
- forbidden grep: `LocalAuthentication|LAContext|canEvaluatePolicy|evaluatePolicy` outside `Epistemos/Sovereign/SovereignGate.swift`
- log: `Agent control custom tool deletes map to destructive Sovereign Gate requirements`
- test: `SovereignGateTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/sovereign-gate-custom-tool-delete-pr10/detectives/sovereign-gate-custom-tool-delete.md`
- `docs/fusion/fleet/sovereign-gate-custom-tool-delete-pr10/aggregator.md`
- `docs/fusion/fleet/sovereign-gate-custom-tool-delete-pr10/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Migrates a clean destructive Core custom-tool surface through the shared Sovereign Gate without touching Hermes/runtime routing or dirty graph/provenance lanes.
