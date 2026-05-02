# R16 Model-Derived Badge PR3G Deliberation - 2026-05-01

## Decision

Approved for a narrow R16 PR3G slice that makes already xattr-marked
AFM/model-derived note sidecars visible while editing, without touching the
protected TextKit editor bridge.

## Scope

- Add a read-only helper that resolves a note source file to its canonical
  `.epistemos.json` sidecar and reports whether
  `com.epistemos.modelDerived` is set to `true`.
- Cache that result in `NoteDetailWorkspaceView` state for the active page so
  the editor footer can render a small `Model-derived` badge without per-frame
  filesystem or xattr reads.
- Refresh the cached badge state on note appearance, page changes, and managed
  body refresh notifications.
- Add focused tests for positive and negative model-derived detection and a
  source guard that proves the workspace renders the explicit badge copy.

## Explicit Non-Scope

- No ETL production worker drain or queue completion semantics.
- No AFM sidecar generation changes.
- No ProseEditor/TextKit bridge edits.
- No graph renderer/controller, Rust, generated binding, entitlement, project,
  or plist edits.
- No full R16 WRV claim; ETL worker execution remains open.

## Rationale

`docs/plan/03_EXECUTION_MAP.md` requires AFM-generated sidecars to be
`xattr`-marked and visible in the editor with a `model-derived` badge. PR3C and
W10.12 already created the explicit xattr marker. This slice closes the
visibility gap by displaying that marker in the note workspace chrome rather
than inside the protected editing engine.

## Files

- `Epistemos/Engine/EpistemosSidecar.swift`
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
- `EpistemosTests/EpistemosSidecarTests.swift`
- `EpistemosTests/ModelVaultBrowserTests.swift`
- Fusion docs for results and oversight.

## Acceptance

- Red-first focused tests fail before implementation.
- Green focused tests pass after implementation.
- The badge is driven only by the existing canonical xattr marker.
- The UI path does not call `EpistemosSidecarStore.isModelDerived` directly from
  SwiftUI body recomputation loops.
- Source audit shows no protected editor, graph renderer/controller, Rust,
  generated binding, entitlement, project, or plist edits were added.

## Stop Triggers

- The implementation needs `ProseEditor*.swift` or TextKit mutation paths.
- The badge requires generating or mutating sidecars.
- The implementation adds polling, timers, or per-frame disk/xattr reads.
- The implementation implies R16 ETL worker execution is complete.
