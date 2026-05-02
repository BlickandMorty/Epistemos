# GraphEvent Visibility PR2 Deliberation - 2026-05-01

## Gate

Approved action: add bounded, read-only Settings diagnostics for durable
`graph_events`.

PR1 closed the durable EventStore mapping. PR2 must not project graph events into
the live graph, Halo, Theater, retrieval, Rust OpLog, or repair UI. This slice is
visibility only.

## Repo Evidence

- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
  Card 8 marks PR1 durable mapping closed and requires future projection slices
  to name exact files and focused tests.
- `docs/fusion/deliberation/graph_event_durable_mapping_pr1_deliberation_2026_05_01.md`
  records `DurableGraphEvent`, `graph_events`, and bounded EventStore save/load/list
  APIs as the canonical source.
- `docs/fusion/deliberation/eventstore_oplog_projection_visibility_pr3d_deliberation_2026_05_01.md`
  is the precedent for read-only EventStore diagnostics mounted in Settings.
- `SettingsView` is the canonical Settings mount point. This commit must stage
  only the self-contained GraphEvent mount and must not absorb unrelated
  uncommitted diagnostic rows.

## Decision

Add the smallest diagnostics path:

- Add `EventStore.GraphEventDiagnostics` with total row count, distinct mutation
  count, latest graph event, and last event kind.
- Add `EventStore.graphEventDiagnostics()` as a bounded, synchronous read.
- Add `GraphEventVisibilityRow` to Settings diagnostics.
- Mount the row in `SettingsView` without depending on unrelated uncommitted
  Settings diagnostics work.
- Add focused tests for diagnostics counts/latest event and read-only Settings
  mounting.

## Files Approved

- `Epistemos/State/EventStore.swift`
- `Epistemos/Views/Settings/GraphEventVisibilityRow.swift`
- `Epistemos/Views/Settings/SettingsView.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/graph_event_visibility_pr2_deliberation_2026_05_01.md`

## Files Forbidden

- `Epistemos/Views/Graph/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `epistemos-shadow/**`
- `agent_core/**`
- OpLog workers, Rust OpLog FFI, PipelineService, ChatCoordinator, Omega, hooks,
  protected note editor files, generated bindings, generated libraries, Xcode
  project files, entitlements, DerivedData, `.xcresult`, stashes, branches, or
  destructive git operations.

## Implementation Contract

- Read-only only: no repair, retry, projection trigger, graph mutation, or live
  graph/Halo/Theater wiring.
- EventStore remains the source of truth.
- Queries must tolerate empty databases and cap any row reads.
- The Settings row must refresh on appear only; no timers, polling loops, or
  background workers.
- Do not rename `DurableGraphEvent` or change `MutationEnvelope` wire format.

## Tests

Red/green focused Swift command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
```

Expected focused assertions:
- empty diagnostics return zero counts and no latest event
- saved graph events produce total and distinct mutation counts
- latest event and last kind follow `occurred_at DESC, id DESC`
- Settings mounts `GraphEventVisibilityRow`
- row is read-only and does not call graph/event mutation APIs or timers

Guardrails:

```bash
git diff --check -- Epistemos/State/EventStore.swift Epistemos/Views/Settings/GraphEventVisibilityRow.swift Epistemos/Views/Settings/SettingsView.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion
/usr/bin/grep -nE "Timer|DispatchSourceTimer|repeatForever|while true|saveGraphEvent|saveMutationEnvelope|graphEvents\\(" Epistemos/Views/Settings/GraphEventVisibilityRow.swift Epistemos/Views/Settings/SettingsView.swift
git diff --name-only -- Epistemos/Views/Graph Epistemos/Graph graph-engine epistemos-shadow agent_core Epistemos/Views/Notes build-rust
```

## Acceptance

- Wired: Settings diagnostics includes a GraphEvent visibility row.
- Reachable: EventStore exposes bounded diagnostics without a graph renderer,
  vault, or Rust handle.
- Visible: diagnostics surface graph-event count, distinct mutation count, last
  event kind, and latest event metadata.

## Rollback

Remove the EventStore diagnostics value/API, the Settings row file, the
SettingsView mount, tests, and this deliberation document. PR1 durable
GraphEvent persistence remains intact.

## Stop Triggers

- Any need to touch graph renderer/controller/editor/Rust files.
- Any need for repair/mutation UI.
- Any unbounded scan, polling loop, or live projection.
- Any change to `MutationEnvelope` or `DurableGraphEvent` wire shape.

## Closeout - 2026-05-01

Status: closed after red/green focused verification.

Implementation:

- Added `EventStore.GraphEventDiagnostics` with total row count, distinct
  mutation count, latest event, and `lastKind`.
- Added `EventStore.graphEventDiagnostics()` plus a bounded latest-event read.
- Added read-only `GraphEventVisibilityRow`, refreshed on appear only.
- Mounted `GraphEventVisibilityRow()` in Settings diagnostics without staging
  unrelated uncommitted diagnostic rows.
- Added focused Swift Testing coverage for empty/non-empty diagnostics and the
  read-only Settings mount.

Evidence:

- Red log: `/tmp/epistemos-graph-event-visibility-pr2-red-20260501.log`.
  Expected failures included missing `graphEventDiagnostics()` before the
  production API existed.
- Green log: `/tmp/epistemos-graph-event-visibility-pr2-green-20260501.log`.
  `EventStore Cognitive Tables` passed 29 tests in 1 suite.
- Final confirmation log:
  `/tmp/epistemos-graph-event-visibility-pr2-final-20260501.log`.
  `EventStore Cognitive Tables` again passed 29 tests in 1 suite after the
  final row cleanup.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_23-14-42--0500.xcresult`.
- Final result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_23-22-28--0500.xcresult`.
- Xcode still printed inherited SwiftLint package-plugin failures for
  CodeEditSourceEditor and CodeEditTextView after `** TEST SUCCEEDED **`;
  those are outside this PR2 slice.

Guardrails run for closeout:

```bash
git diff --check -- Epistemos/State/EventStore.swift Epistemos/Views/Settings/GraphEventVisibilityRow.swift Epistemos/Views/Settings/SettingsView.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion/deliberation/graph_event_visibility_pr2_deliberation_2026_05_01.md
/usr/bin/grep -nE "Timer|DispatchSourceTimer|repeatForever|while true|saveGraphEvent|saveMutationEnvelope|graphEvents\\(" Epistemos/Views/Settings/GraphEventVisibilityRow.swift Epistemos/Views/Settings/SettingsView.swift
git diff --name-only -- Epistemos/Views/Graph Epistemos/Graph graph-engine epistemos-shadow agent_core Epistemos/Views/Notes build-rust
```
