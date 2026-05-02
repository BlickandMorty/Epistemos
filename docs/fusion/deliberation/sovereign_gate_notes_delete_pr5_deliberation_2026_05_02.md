# Sovereign Gate Notes Delete PR5 Deliberation - 2026-05-02

```text
Slice:          Sovereign Gate Notes Delete PR5 - Notes Sidebar destructive delete surface
Tier:           Core
Files touched:
- Epistemos/Views/Notes/NotesSidebar.swift
- EpistemosTests/SovereignGateTests.swift
- docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
- docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
- docs/fusion/deliberation/sovereign_gate_notes_delete_pr5_deliberation_2026_05_02.md
Protected paths:
- Epistemos/Sovereign/SovereignGate.swift
- Epistemos/Views/Notes/ProseEditor*.swift
- Epistemos/Views/Notes/ProseTextView2.swift
- Epistemos/Views/Graph/**
- graph-engine/**
- agent_core/** beyond already-closed PR4
- generated UniFFI bindings / generated libraries
Gate:           SovereignGate touchpoint? additional existing confirmation surface
Risks:          P0 if delete can proceed after failed auth; P0 if this duplicates LAContext; P1 if pending delete state is lost or deletion semantics change.
Verification:   red/green focused Swift logs; source guard for no LocalAuthentication outside the single gate; exact-file diff scan.
Rollback:       Revert NotesSidebar delete authorization helper/button wiring, the focused test, and PR5 doc/status lines.
```

## Authority

Doctrine §4.2 classifies permanent destructive actions as Destructive: every
time, no grace, biometric plus passcode through the single Swift
`SovereignGate.confirm` presenter. Notes Sidebar page and folder delete alerts
currently call `performPageDelete()` / `performFolderDelete()` directly after
the normal SwiftUI destructive button.

## Approved

- Gate only the existing Notes Sidebar permanent page/folder delete buttons.
- Use `AppBootstrap.shared?.sovereignGate.confirm(.deviceOwnerAuthentication, reason: ...)`.
- If auth is denied or unavailable, clear the pending delete request and do not
  delete anything.
- Add a small mapping helper plus focused tests proving page/folder delete
  requirements and reason strings.

## Explicitly Not Approved

- `SovereignGate.swift` edits.
- Additional popup migrations.
- Delete semantics changes.
- Folder/page planner changes.
- Vault disconnect, reset database/everything, model deletion, graph preset
  deletion, Settings destructive actions, generated transport, Rust, graph,
  editor, Xcode project, entitlements, Omega, ChatCoordinator, or tool policy.

## Verification

Red:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/SovereignGateTests test 2>&1 | tee /tmp/epistemos-sovereign-gate-notes-delete-pr5-red-20260502.log
```

Green:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/SovereignGateTests test 2>&1 | tee /tmp/epistemos-sovereign-gate-notes-delete-pr5-green-20260502.log
```

Guardrails:

```bash
git diff --check -- Epistemos/Views/Notes/NotesSidebar.swift EpistemosTests/SovereignGateTests.swift docs/fusion
git diff -- Epistemos/Views/Notes/NotesSidebar.swift EpistemosTests/SovereignGateTests.swift | rg -n 'LAContext|LocalAuthentication|evaluatePolicy|canEvaluatePolicy|Process\(\)|std::process::Command|memcpy|memmove|copyMemory|storageModeManaged|storageModePrivate|z3|kani|kissat|lean|cvc5|alloy' || true
git diff --name-only -- Epistemos/Sovereign Epistemos/Views/Notes/ProseEditor*.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph graph-engine agent_core epistemos-core Epistemos.xcodeproj
```

## Acceptance

- Wired: Notes Sidebar page/folder delete buttons ask the shared Sovereign Gate
  for device-owner authentication before deletion.
- Reachable: focused tests prove the helper maps both surfaces to destructive
  auth and non-empty destructive reasons.
- Boundary: no LocalAuthentication duplication, no `SovereignGate.swift` edit,
  no delete planner change, no generated/Rust/UI-broad migration.

## Stop Triggers

- Tests need real Touch ID.
- Delete behavior changes beyond the auth preflight.
- Any additional confirmation surface is pulled into this PR.

## Closeout

Status: closed on 2026-05-02.

Implementation:
- Added `NotesSidebarDeletionSovereignGate` as a tiny mapping helper for the
  existing Notes Sidebar permanent page/folder delete surfaces.
- Replaced the two destructive alert button actions with shared
  `SovereignGate.confirm(.deviceOwnerAuthentication, reason: ...)` preflights.
- Captured the pending delete target before async authentication so SwiftUI
  alert dismissal cannot erase the authorized page/folder item.
- Denied or unavailable authentication clears pending delete state and performs
  no delete.

Evidence:
- Red: `/tmp/epistemos-sovereign-gate-notes-delete-pr5-red-20260502.log`
  failed on the missing `NotesSidebarDeletionSovereignGate` symbol.
- Green: `/tmp/epistemos-sovereign-gate-notes-delete-pr5-green-20260502.log`
  passed `SovereignGateTests` with 12 Swift Testing tests in 1 suite.
- The green log prints `** TEST SUCCEEDED **`; the trailing vendored
  CodeEdit SwiftLint build-command report is the known selected-test quirk and
  did not fail the focused Swift Testing run.

Guardrails:
- `git diff --check -- Epistemos/Views/Notes/NotesSidebar.swift EpistemosTests/SovereignGateTests.swift docs/fusion`
  passed.
- Diff-only forbidden-token scan over the PR5 Swift/test diff produced no
  `LAContext`, `LocalAuthentication`, subprocess, solver, or tensor-copy hits.

Boundary:
- No `SovereignGate.swift` edit.
- No duplicated `LocalAuthentication` / `LAContext`.
- No delete planner semantic change.
- No additional confirmation-surface migration.
- No generated transport, Rust, graph, editor, Omega, ChatCoordinator, Xcode
  project, or entitlement changes.
