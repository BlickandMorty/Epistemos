# Sovereign Gate Settings Reset Everything PR14 Deliberation — 2026-05-02

## Slice
- Name: `sovereign-gate-settings-reset-everything-pr14`
- Tier: Core
- Workcard: `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9 — future confirmation-surface migration.
- Surface: `Epistemos/Views/Settings/SettingsView.swift`.

## Report Before Code
- The existing General settings "Reset Everything" flow shows a SwiftUI destructive alert and then calls `AppBootstrap.shared?.resetAllData()` directly.
- This is broader than the previously gated RootView recovery reset because it intentionally clears all saved app data, conversations, local model state, and settings.
- `SettingsView.swift` already contains unrelated dirty diagnostics changes. This slice may edit the file, but staging must include only the reset-everything hunk.
- Canon anchor `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` requires `SovereignGate.swift` to remain the single `LocalAuthentication` entrypoint.

## Allowed Files
- `Epistemos/Views/Settings/SettingsView.swift` only for the reset-everything gate hunk
- `EpistemosTests/SovereignGateTests.swift`
- `docs/fusion/fleet/sovereign-gate-settings-reset-everything-pr14/**`
- `docs/fusion/deliberation/sovereign_gate_settings_reset_everything_pr14_deliberation_2026_05_02.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `docs/fusion/fleet/REGISTRY.md`

## Forbidden Files
- `Epistemos/Sovereign/SovereignGate.swift`
- unrelated `SettingsView.swift` diagnostics/key-clear/vault-disconnect hunks
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`
- `Epistemos/Views/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- `epistemos-core/**`
- `Epistemos.xcodeproj`
- entitlements, generated bindings, generated libraries, DerivedData, `.xcresult`

## Sovereign Gate Touchpoint
- Type: migrating-existing.
- Requirement: `.deviceOwnerAuthentication`.
- Denial behavior: do nothing; leave the alert flow dismissed as today.
- Unavailable shared gate behavior: deny via `?? .denied(.authenticationFailed)`.
- LocalAuthentication confinement: unchanged; no `LocalAuthentication`, `LAContext`, `LAError`, `LABiometryType`, `LAPolicy`, `canEvaluatePolicy`, or `evaluatePolicy` in `SettingsView.swift`.

## Implementation Order
1. Add failing `SovereignGateTests` guards for `SettingsViewDestructiveActionSovereignGate` mapping and alert routing.
2. Add a tiny `SettingsViewDestructiveActionSovereignGate` mapping in `SettingsView.swift`.
3. Route the alert destructive reset button through `requestResetEverythingAuthorization()`.
4. Preserve the existing `resetAllData()` call only after `.allowed`.
5. Run focused `SovereignGateTests` and invariant greps.
6. Partial-stage only the PR14 `SettingsView.swift` hunk, not the pre-existing diagnostics hunk.

## Acceptance
- Reset Everything maps to `.deviceOwnerAuthentication`.
- The alert destructive reset button no longer calls `resetAllData()` directly.
- Existing reset execution happens only after shared `SovereignGate` returns `.allowed`.
- Denied/unavailable auth performs no reset.
- The slice does not duplicate `LocalAuthentication`, touch protected graph/editor/Rust/generated files, or stage unrelated `SettingsView` diagnostics changes.

## Canon Anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2`
- `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §4.2`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9

## Workcard Match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 9 — Sovereign Gate Core Authorization.
- Deviation: exact partial staging is required because `SettingsView.swift` was dirty before this slice.

## Failure-Proof Guardrails (post-merge)
- grep: `rg -n 'LocalAuthentication|LAContext|LAError|LABiometryType|LAPolicy|canEvaluatePolicy|evaluatePolicy' Epistemos/Views/Settings/SettingsView.swift` should return no matches.
- log: `/tmp/epistemos-sovereign-gate-settings-reset-pr14-green-20260502.log` should contain `** TEST SUCCEEDED **`.
- test: `EpistemosTests/SovereignGateTests`.

## Fleet Evidence Packet
- `docs/fusion/fleet/sovereign-gate-settings-reset-everything-pr14/aggregator.md`
- `docs/fusion/fleet/sovereign-gate-settings-reset-everything-pr14/codex-red-team/attacks.md`

## Usefulness
usefulness: +1
usefulness_reason: Closes the broadest remaining Core destructive Settings reset path.
