# CODEX/KIMI Oversight Round 054 - R16 Model-Derived Badge PR3G

## Scope

R16 PR3G closes user-visible disclosure for already xattr-marked
AFM/model-derived note sidecars.

## Kimi Input

No new Kimi build task was needed for this narrow slice. Codex used the prior
R16 worker-design advisory to keep ETL worker execution out of scope and avoid
any no-op queue drain.

## Change Summary

- Added `EpistemosSidecarStore.isModelDerived(for:)`, a fail-closed read-only
  detector for the existing `com.epistemos.modelDerived = true` sidecar xattr.
- Added cached `NoteDetailWorkspaceView` state and a refresh task so the note
  footer can show `Model-derived` without xattr/file I/O in SwiftUI body loops.
- Refreshed the cached badge state on note appearance, file-path changes, and
  managed body refresh notifications.
- Added focused tests for positive model-derived detection, fail-closed missing
  or ineligible sidecars, and the note-workspace source guard.

## Evidence

Red-first focused suite:

- `/tmp/epistemos-r16-model-derived-badge-pr3g-red-xcode-20260501.log`
- `/tmp/epistemos-r16-model-derived-badge-pr3g-red-summary-20260501.log`

Green focused Swift suite:

- `/tmp/epistemos-r16-model-derived-badge-pr3g-green-xcode-20260501.log`
- `/tmp/epistemos-r16-model-derived-badge-pr3g-green-summary-20260501.log`

Result:

- `40` tests in `2` suites passed:
  `EpistemosSidecar (Phase 12)` and `Model Vault Browser`.
- Xcode reported `** TEST SUCCEEDED **`.

Guardrails:

- `git diff --check` passed for the PR3G code/test/gate files.
- Targeted protected editor/graph scan found no `ProseEditor*.swift`,
  `MetalGraphView.swift`, or `HologramController.swift` edits in this slice.
- No Rust, generated binding, entitlement, project, plist, staging, commit, or
  branch operation was performed.

## Non-Claims

- No ETL production worker execution is added.
- No queue drain or job completion semantics are claimed.
- No AFM sidecar generation behavior is changed.
- No ProseEditor/TextKit bridge path is touched.
- No manual runtime ship claim is made.

## Remaining R16 Work

- ETL worker execution remains open and must use a real completion contract.
  Do not implement a no-op drain.
- Full R16 WRV is still open until worker execution is reachable and verified.
