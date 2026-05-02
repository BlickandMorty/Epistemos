# GraphEvent Halo Projection PR7 Deliberation - 2026-05-02

## Slice

Card 8 PR7 closes the first live Halo consumer of the durable GraphEvent
projection spine. `HaloController` refreshes a bounded
`GraphEventAuditProjectionReport` through `GraphEventAuditProjectionService`
when the panel opens, and `ShadowPanelContent` displays event/node/edge counts
as a read-only ribbon.

## Gate

Allowed write set for this slice:

- `Epistemos/Engine/GraphEventAuditProjectionService.swift`
- `Epistemos/Engine/HaloController.swift`
- `Epistemos/Views/Halo/ShadowPanelContent.swift`
- `EpistemosTests/HaloControllerTests.swift`
- `EpistemosTests/HaloUITests.swift`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/deliberation/graph_event_halo_projection_pr7_deliberation_2026_05_02.md`

Forbidden for this slice:

- Graph renderer, retrieval, Theater, OpLog, Rust, generated bindings, EventStore
  schema, mutation, repair, polling, timer, projection-worker, Xcode project,
  entitlement, and generated-library changes.
- Any attempt to rename `DurableGraphEvent` or collapse it into the FFI
  `GraphEvent` ring-event type.

## Evidence

- Red: `/tmp/epistemos-graph-event-halo-projection-pr7-red-20260502.log`.
  The focused Halo tests failed before the Halo controller had an injectable
  GraphEvent projection report provider and before the panel exposed a
  read-only projection ribbon.
- Green: `/tmp/epistemos-graph-event-halo-projection-pr7-green-20260502.log`.
  The focused HaloController/HaloUI Swift Testing suites passed 40 tests. Xcode
  still printed the known vendored CodeEdit SwiftLint package-plugin failures
  after `TEST SUCCEEDED`; those are not acceptance blockers for this slice.

## Decision

Approved exactly as scoped. PR7 is a bounded read-only Halo projection consumer:
it refreshes on explicit panel open, displays existing projection counts, and
does not introduce live graph mutation, projection repair, renderer coupling,
retrieval coupling, Theater coupling, Rust coupling, polling, or timer behavior.
