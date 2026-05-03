# Sovereign Gate Notes Vault Disconnect PR11 Deliberation - 2026-05-02

## Tier

Core. This migrates an existing destructive Notes Sidebar vault-disconnect action through the shared native Sovereign Gate.

Gate: SovereignGate touchpoint? migrating-existing.

## Slice

Route `VaultConnectionButton`'s `Disconnect Vault` menu action in `NotesSidebar.swift` through `AppBootstrap.shared?.sovereignGate.confirm(...)` before executing the existing `VaultConnectionActions.disconnect(notesUI:vaultSync:)` body.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` - Sovereign Gate.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §17` - approval/modal surfaces and tool/capability gates.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9 - Sovereign Gate Core Authorization.
- `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md §3.2` - Sovereign Gate touchpoint check.

## Current Code Truth

- `Epistemos/Views/Notes/NotesSidebar.swift` has `VaultConnectionButton`, which exposes `Button("Disconnect Vault", role: .destructive)`.
- The current button calls `VaultConnectionActions.disconnect(notesUI:vaultSync:)` directly.
- `VaultConnectionActions.disconnect` clears the current vault, persisted vault selection, UI state, and window state.
- RootView recovery vault disconnect is already gated by PR8, but this normal sidebar vault menu action is separate.

## Allowed Files/Subsystems

- `Epistemos/Views/Notes/NotesSidebar.swift`
- `EpistemosTests/SovereignGateTests.swift`
- Deliberation/fleet/current-state/workcard docs under `docs/fusion/**`.

## Forbidden Files/Subsystems

- `Epistemos/Sovereign/SovereignGate.swift`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`
- `Epistemos/Views/Graph/**`
- `Epistemos/Graph/**`
- `Epistemos/Sync/VaultSyncService.swift`
- `agent_core/**`
- `graph-engine/**`
- Generated bindings, entitlements, Xcode project files, DerivedData, `.xcresult`

## Implementation Contract

- Do not import `LocalAuthentication` or instantiate `LAContext` outside `Epistemos/Sovereign/SovereignGate.swift`.
- Do not change `VaultConnectionActions.disconnect(notesUI:vaultSync:)` semantics.
- Capture the exact `vaultURL` before async authorization; denied or unavailable auth must not disconnect.
- Denied, unavailable, or missing `AppBootstrap.shared` auth must not disconnect; the nil-gate fallback is `.denied(.authenticationFailed)`.
- After auth, verify the current vault URL still matches the captured URL before disconnecting, and keep that verification on the main actor.
- Add an in-flight guard for this menu action so repeated taps cannot start concurrent auth prompts or duplicate disconnect attempts.
- Add focused tests first: mapper requirement/reason and source guard proving the button routes through `requestVaultDisconnectAuthorization`.

## Acceptance

- Notes Sidebar vault disconnect maps to `.deviceOwnerAuthentication` and a human-readable reason string.
- The `Disconnect Vault` menu button routes to `requestVaultDisconnectAuthorization(vaultURL:)` instead of directly calling `VaultConnectionActions.disconnect(notesUI:vaultSync:)`.
- `requestVaultDisconnectAuthorization(vaultURL:)` calls the shared app `SovereignGate`, denies safely by default, verifies the captured vault URL is still current on the main actor, and only then calls the existing disconnect action.
- Re-entrant taps are guarded by an in-flight flag and the menu item is disabled while authorization is in progress.
- Source guard proves no duplicate biometric APIs appear in this file.

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 9 - Sovereign Gate Core Authorization.
- Deviation: none. This is a future confirmation-surface migration with the exact surface named.

## Failure-Proof Guardrails (Post-Merge)

- grep: `case vaultDisconnect(name: String)`
- grep: `requestVaultDisconnectAuthorization(vaultURL:)`
- forbidden grep: `LocalAuthentication|LAContext|canEvaluatePolicy|evaluatePolicy` outside `Epistemos/Sovereign/SovereignGate.swift`
- log: `Notes sidebar vault disconnect maps to destructive Sovereign Gate requirements`
- test: `SovereignGateTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/sovereign-gate-notes-vault-disconnect-pr11/detectives/sovereign-gate-notes-vault-disconnect.md`
- `docs/fusion/fleet/sovereign-gate-notes-vault-disconnect-pr11/aggregator.md`
- `docs/fusion/fleet/sovereign-gate-notes-vault-disconnect-pr11/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Migrates the normal Notes Sidebar vault-disconnect destructive control through the shared Sovereign Gate without changing vault teardown semantics.
