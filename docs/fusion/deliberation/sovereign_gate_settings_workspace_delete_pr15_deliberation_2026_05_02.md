# Sovereign Gate Settings Workspace Delete PR15 Deliberation - 2026-05-02

## Summary

Route the existing General Settings saved-workspace destructive delete button through the shared `AppBootstrap` `SovereignGate` before calling `workspaceService.deleteWorkspace(workspace)`.

## Tier

Core. Saved workspaces are local app state, and destructive deletion should use the existing Core `SovereignGate` `.deviceOwnerAuthentication` requirement.

## Allowed files/subsystems

- `Epistemos/Views/Settings/SettingsView.swift`
- `EpistemosTests/SovereignGateTests.swift`
- `docs/fusion/**`

## Forbidden files/subsystems

- `Epistemos/Sovereign/SovereignGate.swift`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`
- `Epistemos/Views/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- Generated Swift/header bindings, generated libraries, Xcode project files, entitlements, DerivedData, `.xcresult`, unrelated Settings sections, Omega, ChatCoordinator, Rust/generated transport.

## Sovereign Gate touchpoint check

This is `migrating-existing`. The slice must not import `LocalAuthentication`, instantiate `LAContext`, or make Swift own the action-class matrix. `SettingsView` may only supply an externally chosen `SovereignGateRequirement` and reason to the already-shared gate.

## Killer-feature dependency check

- Resonance Gate: no.
- Sovereign Gate: yes.
- Freeform Pulse: no.
- Residency Rail: no.

## Proposed implementation

1. Add `SettingsViewDestructiveActionSovereignGate.Target.savedWorkspace(name:)`.
2. Map saved-workspace delete to `.deviceOwnerAuthentication`.
3. Change the Saved Workspaces trash button to `Task { @MainActor in await requestSavedWorkspaceDeleteAuthorization(workspace) }`.
4. Add `requestSavedWorkspaceDeleteAuthorization(_:)` that captures the workspace value, calls the shared gate, returns on denial/unavailable auth, then calls a tiny `deleteSavedWorkspace(_:)` helper preserving the existing delete + refresh behavior.
5. Add focused Swift Testing source guards in `SovereignGateTests`.

## Acceptance

- Failing test first proves current Settings workspace delete bypasses `SovereignGate`.
- Focused green test proves saved-workspace delete maps to `.deviceOwnerAuthentication`.
- Focused green test proves the button calls `requestSavedWorkspaceDeleteAuthorization(workspace)` rather than `workspaceService.deleteWorkspace(workspace)` directly.
- Source guard proves `SettingsView.swift` still has no `LocalAuthentication`, `LAContext`, `canEvaluatePolicy`, or `evaluatePolicy`.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2`
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` Sovereign Gate PR14 status
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 9 - Sovereign Gate Core Authorization.
- Deviation: none; this is one exact additional destructive Settings surface with focused tests.

## Failure-proof guardrails (post-merge)

- grep: `savedWorkspace\\(name:`
- grep: `requestSavedWorkspaceDeleteAuthorization\\(`
- log: `/tmp/epistemos-sovereign-gate-settings-workspace-pr15-green-20260502.log`
- test: `SovereignGateTests`

## Fleet evidence packet

- `docs/fusion/fleet/sovereign-gate-settings-workspace-delete-pr15/aggregator.md`
- `docs/fusion/fleet/sovereign-gate-settings-workspace-delete-pr15/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Closes a real ungated Core destructive Settings action without changing SovereignGate internals.
