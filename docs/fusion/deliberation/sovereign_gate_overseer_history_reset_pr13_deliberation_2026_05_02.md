# Sovereign Gate Overseer History Reset PR13 Deliberation — 2026-05-02

## Slice
- Name: `sovereign-gate-overseer-history-reset-pr13`
- Tier: Core
- Workcard: `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9 — future confirmation-surface migration.
- Surface: `Epistemos/Views/Settings/OverseerSettingsView.swift`.

## Report Before Code
- The visible Overseer Settings footer clears recent route/audit history with `audit.clear()` directly.
- `OverseerAuditState.clear()` is also used for lifecycle/workspace hygiene, so this slice gates only the user-facing Settings footer and does not alter the state type.
- Canon anchor `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` requires `SovereignGate.swift` to remain the single `LocalAuthentication` entrypoint.
- Doctrine anchor `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §4.2` explicitly includes Settings footers in the one-gate rule.

## Allowed Files
- `Epistemos/Views/Settings/OverseerSettingsView.swift`
- `EpistemosTests/SovereignGateTests.swift`
- `docs/fusion/fleet/sovereign-gate-overseer-history-reset-pr13/**`
- `docs/fusion/deliberation/sovereign_gate_overseer_history_reset_pr13_deliberation_2026_05_02.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `docs/fusion/fleet/REGISTRY.md`

## Forbidden Files
- `Epistemos/Sovereign/SovereignGate.swift`
- `Epistemos/State/OverseerAuditState.swift`
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
- Denial behavior: do nothing; do not clear audit history.
- Unavailable shared gate behavior: deny via `?? .denied(.authenticationFailed)`.
- LocalAuthentication confinement: unchanged; no `LocalAuthentication`, `LAContext`, `LAError`, `LABiometryType`, `LAPolicy`, `canEvaluatePolicy`, or `evaluatePolicy` in `OverseerSettingsView.swift`.

## Implementation Order
1. Add failing `SovereignGateTests` guards for `OverseerSettingsSovereignGate` mapping and source routing.
2. Add a tiny `OverseerSettingsSovereignGate` mapping in `OverseerSettingsView.swift`.
3. Route "Reset history" through `requestHistoryResetAuthorization()`.
4. Keep `audit.clear()` in a private post-auth helper.
5. Run focused `SovereignGateTests` and invariant greps.

## Acceptance
- Overseer history reset maps to `.deviceOwnerAuthentication`.
- The "Reset history" button no longer calls `audit.clear()` directly from the button closure.
- Existing audit clearing happens only after the shared `SovereignGate` returns `.allowed`.
- Denied/unavailable auth performs no audit clear.
- The slice does not duplicate `LocalAuthentication` or touch protected graph/editor/Rust/generated files.

## Canon Anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2`
- `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §4.2`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9

## Workcard Match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 9 — Sovereign Gate Core Authorization.
- Deviation: none; this is an exact future confirmation-surface migration under the Card 9 lane.

## Failure-Proof Guardrails (post-merge)
- grep: `rg -n 'LocalAuthentication|LAContext|LAError|LABiometryType|LAPolicy|canEvaluatePolicy|evaluatePolicy' Epistemos/Views/Settings/OverseerSettingsView.swift` should return no matches.
- log: `/tmp/epistemos-sovereign-gate-overseer-history-pr13-green-20260502.log` should contain `** TEST SUCCEEDED **`.
- test: `EpistemosTests/SovereignGateTests`.

## Fleet Evidence Packet
- `docs/fusion/fleet/sovereign-gate-overseer-history-reset-pr13/aggregator.md`
- `docs/fusion/fleet/sovereign-gate-overseer-history-reset-pr13/claude-red-team/attacks.md`

## Usefulness
usefulness: +1
usefulness_reason: Closes an actual Settings footer that deletes read-only route/audit evidence.
