# Sovereign Gate Model Vault Delete PR9 Deliberation - 2026-05-02

## Tier

Core. This migrates an existing destructive local model-vault file/folder delete confirmation through the shared native Sovereign Gate.

Gate: SovereignGate touchpoint? migrating-existing.

## Slice

Route `ModelVaultsSidebarSection` destructive file/folder delete alerts through `AppBootstrap.shared?.sovereignGate.confirm(...)` before executing the existing `delete(_:)` body.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` - Sovereign Gate.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §17` - approval/modal surfaces.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9 - Sovereign Gate Core Authorization.
- `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md §3.2` - Sovereign Gate touchpoint check.

## Current Code Truth

- `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` has `pendingDeleteTarget`, destructive "Delete Folder" / "Delete File" context menu actions, an alert primary delete button, and `delete(_:)` cleanup logic.
- The current alert primary action calls `delete(target)` directly.
- `EpistemosTests/SovereignGateTests.swift` already contains PR5-PR8 mapping/source guard tests for Notes Sidebar, Chat Sidebar, DiffSheet, and RootView destructive migrations.

## Allowed Files/Subsystems

- `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift`
- `EpistemosTests/SovereignGateTests.swift`
- Deliberation/fleet/current-state/workcard docs under `docs/fusion/**`.

## Forbidden Files/Subsystems

- `Epistemos/Sovereign/SovereignGate.swift`
- Any other `Epistemos/Views/Notes/**` file
- `Epistemos/Views/Graph/**`
- `Epistemos/Graph/**`
- `agent_core/**`
- `graph-engine/**`
- Generated bindings, entitlements, Xcode project files, DerivedData, `.xcresult`

## Implementation Contract

- Do not import `LocalAuthentication` or instantiate `LAContext` outside `Epistemos/Sovereign/SovereignGate.swift`.
- Do not change `delete(_:)` semantics except to move execution behind an allowed Sovereign Gate outcome.
- Capture the exact delete target before async authorization; denied or unavailable auth must not delete.
- Keep the existing alert, context menus, workspace-page cleanup, selected-file cleanup, and refresh behavior.
- Add focused tests first: mapper requirement/reason and source guard proving the alert routes through `requestDeleteAuthorization`.

## Acceptance

- Model vault file/folder delete targets map to `.deviceOwnerAuthentication` and human-readable reason strings.
- The alert primary button routes to `requestDeleteAuthorization(target)` instead of `delete(target)`.
- `requestDeleteAuthorization(_:)` calls the shared app `SovereignGate`, denies safely by default, and calls `delete(target)` only after `.allowed`.
- Source guard proves no duplicate biometric APIs appear in this file.

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 9 - Sovereign Gate Core Authorization.
- Deviation: none. This is a future confirmation-surface migration with the exact surface named.

## Failure-Proof Guardrails (Post-Merge)

- grep: `enum ModelVaultDeletionSovereignGate`
- grep: `requestDeleteAuthorization`
- forbidden grep: `LocalAuthentication|LAContext|canEvaluatePolicy|evaluatePolicy` outside `Epistemos/Sovereign/SovereignGate.swift`
- log: `Model vault deletes map to destructive Sovereign Gate requirements`
- test: `SovereignGateTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/sovereign-gate-model-vault-delete-pr9/detectives/sovereign-gate-model-vault-delete.md`
- `docs/fusion/fleet/sovereign-gate-model-vault-delete-pr9/aggregator.md`
- `docs/fusion/fleet/sovereign-gate-model-vault-delete-pr9/codex-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Migrates a clean destructive Core confirmation surface through the shared Sovereign Gate without entering manual/runtime or dirty graph/provenance lanes.
