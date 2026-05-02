# Sovereign Gate RootView Destructive PR8 Deliberation - 2026-05-02

Slice: Sovereign Gate RootView Destructive PR8 - database reset and vault disconnect surfaces
Tier: Core
Owner: Codex
Status: implemented and verified after red-team revision

## Report Before Code

PR8 migrates two existing `RootView` destructive controls through the shared Core `SovereignGate`: the database error alert's "Reset Database" action and the vault recovery overlay's "Disconnect Vault" action. This is a two-surface follow-through slice under `MASTER_RESEARCH_INDEX_2026_05_02.md` §3.2 and Card 9.

## Scope

Allowed files:
- `/Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/sovereign_gate_rootview_destructive_pr8_deliberation_2026_05_02.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/sovereign-gate-rootview-destructive-pr8/**`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/REGISTRY.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`

Forbidden files/subsystems:
- `Epistemos/Sovereign/SovereignGate.swift`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`
- `Epistemos/Views/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- generated UniFFI bindings, Xcode project files, entitlements, database reset semantics, vault recovery state semantics, Rust transport, Omega, ChatCoordinator

## Implementation Order

1. Add a failing mapper/source-guard test in `SovereignGateTests` proving RootView database reset and vault disconnect map to `.deviceOwnerAuthentication`.
2. Add `RootViewDestructiveActionSovereignGate` beside `RootView`.
3. Change only the existing "Reset Database" destructive alert button to call `requestDatabaseResetAuthorization()`.
4. Change only the existing "Disconnect Vault" destructive overlay button to call `requestVaultDisconnectAuthorization()`.
5. Preserve the original `onResetDatabase?()` and `disconnectAction()` closures, invoking them only after `outcome == .allowed`.

## Acceptance

- The focused red test fails before implementation because `RootViewDestructiveActionSovereignGate` does not exist.
- The focused green test passes in `EpistemosTests/SovereignGateTests`.
- Source guards prove the "Reset Database" button calls `requestDatabaseResetAuthorization()` and no longer calls `onResetDatabase?()` directly.
- Source guards prove the "Disconnect Vault" button calls `requestVaultDisconnectAuthorization()` and no longer calls `disconnectAction()` directly.
- Source guards prove both async gate paths call `AppBootstrap.shared?.sovereignGate.confirm(...)`, guard `outcome == .allowed`, and then call the original destructive closure.
- Source guards prove denied/cancelled database-reset auth restores the database error alert while `databaseError` remains present.
- Source guards prove vault disconnect has an in-flight guard and disables the button while device-owner auth is pending.
- Source grep confirms no new `LocalAuthentication` / `LAContext` outside `Epistemos/Sovereign/SovereignGate.swift`.
- Diff-only invariant grep has no hits for hot-path copy, subprocess, private/managed Metal storage, or solver-on-hot-path symbols.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §3.2
- `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.2
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 9 - Sovereign Gate Core Authorization
- Deviation: none. This is a future confirmation-surface migration with two exact existing destructive surfaces named.

## Failure-proof guardrails (post-merge)

- grep: `rg -n "RootViewDestructiveActionSovereignGate|requestDatabaseResetAuthorization|requestVaultDisconnectAuthorization|Reset Database|Disconnect Vault" Epistemos/App/RootView.swift EpistemosTests/SovereignGateTests.swift`
- log: `Test Suite 'Sovereign Gate' passed`
- test: `EpistemosTests/SovereignGateTests`

## Verification

- Red log: `/tmp/epistemos-sovereign-gate-rootview-pr8-red-20260502.log` failed before implementation because `RootViewDestructiveActionSovereignGate` did not exist.
- Green log: `/tmp/epistemos-sovereign-gate-rootview-pr8-green-20260502.log` passed 17/17 focused Sovereign Gate tests.
- Post-red-team green log: `/tmp/epistemos-sovereign-gate-rootview-pr8-green-r2-20260502.log` passed 17/17 focused Sovereign Gate tests after addressing red-team P2/P3 findings.
- Red-team findings addressed: denied reset auth now reopens the database recovery alert, and vault disconnect now has an in-flight auth guard.
- Guardrails: `git diff --check`, source grep proving `LocalAuthentication` / `LAContext` confinement, and diff-only invariant grep all passed before staging.

## Fleet evidence packet

- `docs/fusion/fleet/sovereign-gate-rootview-destructive-pr8/aggregator.md`
- `docs/fusion/fleet/sovereign-gate-rootview-destructive-pr8/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Converts two remaining Core destructive RootView controls into a contained tested gate migration.
