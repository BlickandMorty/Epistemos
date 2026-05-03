# Sovereign Gate Settings Vault Disconnect PR16 Deliberation - 2026-05-02

## Summary

Route the existing Settings > Vault `Disconnect` destructive button through the shared `AppBootstrap` `SovereignGate` before calling `VaultConnectionActions.disconnect(notesUI:vaultSync:)`.

## Tier

Core. Disconnecting the active local vault mutates local app state and should use the existing Core `SovereignGate` `.deviceOwnerAuthentication` requirement.

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
- Generated Swift/header bindings, generated libraries, Xcode project files, entitlements, DerivedData, `.xcresult`, unrelated Settings diagnostics sections, Omega, ChatCoordinator, Rust/generated transport.

## Sovereign Gate touchpoint check

This is `migrating-existing`. The slice must not import `LocalAuthentication`, instantiate `LAContext`, or make Swift own the action-class matrix. `SettingsView` may only supply an externally chosen `SovereignGateRequirement` and reason to the already-shared gate.

## Killer-feature dependency check

- Resonance Gate: no.
- Sovereign Gate: yes.
- Freeform Pulse: no.
- Residency Rail: no.

## Proposed implementation

1. Add `SettingsViewDestructiveActionSovereignGate.Target.vaultDisconnect(name:)`.
2. Map vault disconnect to `.deviceOwnerAuthentication`.
3. Change the Settings Vault `Disconnect` button to `Task { @MainActor in await requestVaultDisconnectAuthorization(vaultURL: url) }`.
4. Add an in-flight authorization state so rapid clicks do not stack prompts.
5. Add `requestVaultDisconnectAuthorization(vaultURL:)` that calls the shared gate, returns on denial/unavailable auth, rechecks that `vaultSync.vaultURL` still matches the captured URL, then calls the existing disconnect helper.
6. Add focused Swift Testing source guards in `SovereignGateTests`.

## Acceptance

- Failing test first proves current Settings vault disconnect bypasses `SovereignGate`.
- Focused green test proves vault disconnect maps to `.deviceOwnerAuthentication`.
- Focused green test proves the button calls `requestVaultDisconnectAuthorization(vaultURL:)` rather than `VaultConnectionActions.disconnect(notesUI:vaultSync:)` directly.
- Source guard proves `SettingsView.swift` still has no `LocalAuthentication`, `LAContext`, `canEvaluatePolicy`, or `evaluatePolicy`.
- Source guard proves the authorized path safely denies when the gate is unavailable and rechecks the active vault URL after approval.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2`
- `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §4.2`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 9 - Sovereign Gate Core Authorization.
- Deviation: none; this is one exact additional destructive Settings surface with focused tests.

## Failure-proof guardrails (post-merge)

- grep: `vaultDisconnect\\(name:`
- grep: `requestVaultDisconnectAuthorization\\(vaultURL:`
- grep: `guard vaultSync.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL else { return }`
- log: `/tmp/epistemos-sovereign-gate-settings-vault-disconnect-pr16-green-20260502-rerun.log`
- test: `SovereignGateTests`

## Fleet evidence packet

- `docs/fusion/fleet/sovereign-gate-settings-vault-disconnect-pr16/aggregator.md`
- `docs/fusion/fleet/sovereign-gate-settings-vault-disconnect-pr16/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Closes a real ungated Core destructive Settings action without changing SovereignGate internals.
