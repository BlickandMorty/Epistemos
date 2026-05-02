# GraphEvent Projection Visibility PR5 Deliberation - 2026-05-02

## Decision

Approved for a narrow read-only Settings diagnostic slice.

## Goal

Surface the existing `EventStore.graphEventProjectionSnapshot(limit:)` read-only
consumer in `GraphEventVisibilityRow` so the durable graph projection is wired,
reachable, and visibly inspectable without touching live graph, retrieval, Halo,
Theater, Rust, OpLog, mutation, repair, or polling paths.

## Authority Read First

- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `Epistemos/Views/Settings/GraphEventVisibilityRow.swift`
- `Epistemos/State/EventStore.swift`
- `Epistemos/Models/MutationEnvelope.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`

## Allowed Write Set

- `Epistemos/Views/Settings/GraphEventVisibilityRow.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/graph_event_projection_visibility_pr5_deliberation_2026_05_02.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`

## Forbidden Write Set

- `Epistemos/Views/Graph/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- OpLog workers or Rust OpLog FFI
- PipelineService, ChatCoordinator, Omega, hooks, retrieval, Halo, Theater, or
  protected note editor files
- Generated bindings, generated libraries, Xcode project files, entitlements,
  DerivedData, `.xcresult`, staging, commits, stashes, or branch operations
  outside the exact accepted files

## Implementation Contract

- Use the existing `EventStore.graphEventProjectionSnapshot(limit:)` API.
- Add only a bounded read-only diagnostic row.
- Do not introduce timers, `.task` loops, repair buttons, mutation calls, Rust
  calls, graph renderer updates, retrieval updates, Halo updates, or Theater
  updates.
- If there is no shared EventStore, render the empty projection fold through the
  existing pure `DurableGraphEventProjection.snapshot(from: [])` path.

## Tests And Logs

- Red:
  `/tmp/epistemos-graph-event-projection-visibility-pr5-red-20260502.log`
- Green:
  `/tmp/epistemos-graph-event-projection-visibility-pr5-green-20260502.log`
- Focused command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/OpLogFFIBoundaryGuardTests test`
- Guardrails:
  `git diff --check`
  implementation forbidden-path grep
  protected-path staged diff scan

## Acceptance

- `GraphEventVisibilityRow` displays durable GraphEvent diagnostics plus a
  bounded projection snapshot count.
- The row remains read-only and does not poll.
- The focused `OpLogFFIBoundaryGuardTests` suite executes the source guard
  requiring the projection snapshot consumer and passes.

## Stop Triggers

- The slice needs live graph/retrieval/Halo/Theater mutation.
- The slice needs Rust, OpLog, generated bindings, or protected editor files.
- The row requires polling or repair semantics.
