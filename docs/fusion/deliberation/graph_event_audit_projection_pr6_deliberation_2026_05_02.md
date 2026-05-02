# GraphEvent Audit Projection PR6 Deliberation - 2026-05-02

## Slice

Card 8 Durable GraphEvent PR6 adds a read-only audit consumer for the existing
durable graph projection snapshot.

## Gate

Add a small production service that consumes the existing
`EventStore.graphEventProjectionSnapshot(limit:)` API and returns a bounded
audit report with event count, node count, edge count, latest event id, node ids,
edge ids, and generation time.

## Boundaries

No graph renderer, `Epistemos/Graph/**`, `Epistemos/Views/Graph/**`, retrieval,
Halo, Theater, OpLog, Rust, generated-binding, EventStore schema, mutation,
repair, polling, timer, or UI changes. This slice does not create another graph
projection algorithm; it consumes the already approved EventStore consumer.

## Files

- `Epistemos/Engine/GraphEventAuditProjectionService.swift`
- `EpistemosTests/GraphEventAuditProjectionTests.swift`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/deliberation/graph_event_audit_projection_pr6_deliberation_2026_05_02.md`

## Evidence

- Red log: `/tmp/epistemos-graph-event-audit-projection-pr6-red-20260502.log`
- Green focused Swift Testing: `/tmp/epistemos-graph-event-audit-projection-pr6-green-20260502.log`
- Note: the focused behavior suite passed 2 tests with `TEST SUCCEEDED`; Xcode
  still printed known SwiftLint package-plugin noise after success.

## Approval

Approved for this exact PR6 only.
