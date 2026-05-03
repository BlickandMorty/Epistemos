# Sovereign Gate Authority Reset PR12 Deliberation — 2026-05-02

## Slice
- Name: `sovereign-gate-authority-reset-pr12`
- Tier: Core
- Workcard: `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9 — future confirmation-surface migration.
- Surface: `Epistemos/Views/Settings/AuthoritySettingsView.swift`.

## Report Before Code
- Current code has two batch authority-policy mutation paths: Quick Setup buttons call `applyPreset(preset)` directly, and the footer "Reset to defaults" button calls `store.reset()` directly.
- Canon anchor `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` requires Sovereign Gate's single Swift entrypoint to remain `Epistemos/Sovereign/SovereignGate.swift`.
- Doctrine anchor `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §4.2` explicitly includes Settings footers and permission gates in the one-gate rule.
- This slice is a migration of an existing Settings surface only; it does not change the Rust action-class matrix, generated transport, individual picker semantics, authority persistence, or the approval modal.

## Allowed Files
- `Epistemos/Views/Settings/AuthoritySettingsView.swift`
- `EpistemosTests/SovereignGateTests.swift`
- `docs/fusion/fleet/sovereign-gate-authority-reset-pr12/**`
- `docs/fusion/deliberation/sovereign_gate_authority_reset_pr12_deliberation_2026_05_02.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `docs/fusion/fleet/REGISTRY.md`

## Forbidden Files
- `Epistemos/Sovereign/SovereignGate.swift`
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
- Denial behavior: do nothing; do not reset or apply a preset.
- Unavailable shared gate behavior: deny via `?? .denied(.authenticationFailed)`.
- LocalAuthentication confinement: unchanged; no `LocalAuthentication`, `LAContext`, `LAError`, `LABiometryType`, `LAPolicy`, `canEvaluatePolicy`, or `evaluatePolicy` in `AuthoritySettingsView.swift`.

## Implementation Order
1. Add failing `SovereignGateTests` guards for `AuthoritySettingsSovereignGate` mapping and source routing.
2. Add a tiny `AuthoritySettingsSovereignGate` mapping in `AuthoritySettingsView.swift`.
3. Route Quick Setup buttons through `requestQuickSetupAuthorization(_:)`.
4. Route "Reset to defaults" through `requestResetToDefaultsAuthorization()`.
5. Preserve the existing reset/apply logic in private post-auth helpers.
6. Run the focused `SovereignGateTests` suite and invariant greps.

## Acceptance
- Batch Authority settings reset maps to `.deviceOwnerAuthentication`.
- Batch Quick Setup presets map to `.deviceOwnerAuthentication`.
- Quick Setup buttons no longer call `applyPreset(preset)` directly from the button action.
- The footer reset button no longer calls `store.reset()` directly from the button action.
- Existing store mutation logic runs only after the shared `SovereignGate` returns `.allowed`.
- Denied/unavailable auth performs no policy mutation.
- The slice does not duplicate `LocalAuthentication` or touch protected graph/editor/Rust/generated files.

## Canon Anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2`
- `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §4.2`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9

## Workcard Match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 9 — Sovereign Gate Core Authorization.
- Deviation: none; this is an exact future confirmation-surface migration under the Card 9 lane.

## Failure-Proof Guardrails (post-merge)
- grep: `rg -n 'LocalAuthentication|LAContext|LAError|LABiometryType|LAPolicy|canEvaluatePolicy|evaluatePolicy' Epistemos/Views/Settings/AuthoritySettingsView.swift` should return no matches.
- log: `/tmp/epistemos-sovereign-gate-authority-reset-pr12-green-20260502.log` should contain `** TEST SUCCEEDED **`.
- test: `EpistemosTests/SovereignGateTests`.

## Fleet Evidence Packet
- `docs/fusion/fleet/sovereign-gate-authority-reset-pr12/aggregator.md`
- `docs/fusion/fleet/sovereign-gate-authority-reset-pr12/claude-red-team/attacks.md`

## Usefulness
usefulness: +1
usefulness_reason: Closes an actual Settings authority-policy batch mutation path under the one-gate rule.
