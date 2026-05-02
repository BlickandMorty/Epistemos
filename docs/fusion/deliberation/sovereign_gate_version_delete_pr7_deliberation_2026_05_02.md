# Sovereign Gate Version Delete PR7 Deliberation - 2026-05-02

Slice: Sovereign Gate Version Delete PR7 - DiffSheet destructive version delete surface
Tier: Core
Owner: Codex
Status: implemented and verified after red-team revision

## Report Before Code

PR7 migrates the existing `DiffSheetView` "Delete This Version" destructive menu action through the shared Core `SovereignGate`. This is a one-surface follow-through slice under `MASTER_RESEARCH_INDEX_2026_05_02.md` §3.2 and doctrine §4.2.

## Scope

Allowed files:
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/DiffSheetView.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/sovereign_gate_version_delete_pr7_deliberation_2026_05_02.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/sovereign-gate-version-delete-pr7/**`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/REGISTRY.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`

Forbidden files/subsystems:
- `Epistemos/Sovereign/SovereignGate.swift`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`
- `Epistemos/Views/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- generated UniFFI bindings, Xcode project files, entitlements, vault reset/disconnect actions, Rust transport, Omega, ChatCoordinator

## Implementation Order

1. Add a failing mapper test in `SovereignGateTests` proving DiffSheet version delete maps to `.deviceOwnerAuthentication` with an explicit permanent-delete reason.
2. Add `DiffSheetVersionDeletionSovereignGate` beside `DiffSheetView`.
3. Change only the existing `Delete This Version` menu action to call `requestSelectedVersionDeleteAuthorization()`.
4. Capture the exact `SDPageVersion` before awaiting auth and delete that captured version after `.allowed`, so changing selection during auth cannot delete a different version.
5. Preserve `deleteSelectedVersion()` rollback semantics so the existing runtime validation source test remains valid.

## Acceptance

- The focused red test fails before implementation because `DiffSheetVersionDeletionSovereignGate` does not exist.
- The focused green test passes in `EpistemosTests/SovereignGateTests`.
- The existing source-level DiffSheet runtime validation still sees `modelContext.insert(version)` in the delete section.
- A source guard proves the `Delete This Version` menu action calls `requestSelectedVersionDeleteAuthorization()` and does not call `deleteSelectedVersion()` directly.
- A source guard proves the async gate path calls `deleteSelectedVersion(version)` on the captured version only after `outcome == .allowed`.
- Source grep confirms no new `LocalAuthentication` / `LAContext` outside `Epistemos/Sovereign/SovereignGate.swift`.
- Diff-only invariant grep has no hits for hot-path copy, subprocess, private/managed Metal storage, or solver-on-hot-path symbols.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §3.2
- `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.2
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 9 - Sovereign Gate Core Authorization
- Deviation: none. This is a future confirmation-surface migration with the exact existing surface named.

## Failure-proof guardrails (post-merge)

- grep: `rg -n "DiffSheetVersionDeletionSovereignGate|requestSelectedVersionDeleteAuthorization|Delete This Version" Epistemos/Views/Notes/DiffSheetView.swift EpistemosTests/SovereignGateTests.swift`
- log: `Test Suite 'Sovereign Gate' passed`
- test: `EpistemosTests/SovereignGateTests`

## Verification

- Red log: `/tmp/epistemos-sovereign-gate-version-delete-pr7-red-20260502.log` failed before implementation because `DiffSheetVersionDeletionSovereignGate` did not exist.
- Green logs: `/tmp/epistemos-sovereign-gate-version-delete-pr7-green-20260502.log`
  and `/tmp/epistemos-sovereign-gate-version-delete-pr7-green-final-20260502.log`
  passed 15/15 focused Sovereign Gate tests.
- Red-team P1s addressed: the authorized version is captured before async auth, and source guards prove the menu no longer calls direct deletion.

## Fleet evidence packet

- `docs/fusion/fleet/sovereign-gate-version-delete-pr7/aggregator.md`
- `docs/fusion/fleet/sovereign-gate-version-delete-pr7/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Converts one remaining Core destructive confirmation surface into a contained tested gate migration.
