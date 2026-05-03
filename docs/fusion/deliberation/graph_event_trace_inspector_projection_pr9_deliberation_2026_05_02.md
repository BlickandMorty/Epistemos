# GraphEvent Trace Inspector Projection PR9 Deliberation - 2026-05-02

Slice: `graph-event-trace-inspector-projection-pr9`

Tier: Core

## Decision

Approved: add a read-only GraphEvent projection summary to the existing Capture
Trace Inspector DEBUG sheet. The summary consumes the existing bounded
`GraphEventAuditProjectionService` report and displays event/node/edge/latest
counts beside the existing trace list.

## Allowed Files

- `Epistemos/Views/Capture/TraceInspectorView.swift`
- `Epistemos/Engine/GraphEventAuditProjectionService.swift`
- `EpistemosTests/GraphEventAuditProjectionTests.swift`
- `docs/fusion/fleet/graph-event-trace-inspector-projection-pr9/**`
- `docs/fusion/deliberation/graph_event_trace_inspector_projection_pr9_deliberation_2026_05_02.md`
- `docs/fusion/oversight/PREFLIGHT_37_2026_05_02.md`
- Canon status/guard docs after verification.

## Forbidden Files

- `Epistemos/Views/Graph/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- `epistemos-core/**`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Settings/**`
- `Epistemos/Engine/HaloController.swift`
- `Epistemos/State/EventStore.swift`
- `Epistemos/Models/MutationEnvelope.swift`
- Rust OpLog FFI, generated bindings, Xcode project files, entitlements, DerivedData, and `.xcresult`.

## Implementation

- `TraceInspectorViewModel` caches a `GraphEventAuditProjectionReport`.
- The report provider defaults to `GraphEventAuditProjectionService().auditReport(limit: 100)`.
- `loadTraces()` refreshes the projection report inside the detached utility snapshot path, then commits only if the current load task has not been cancelled.
- `GraphEventAuditProjectionService` is explicitly `nonisolated` / `@unchecked Sendable` so the bounded report can be produced off the main actor.
- `TraceInspectorView` displays a compact "Graph projection" summary line.
- No GraphEvent writes, mutation-envelope writes, timers, polling loops, repair, rollback, graph renderer state, retrieval, Halo, Settings, OpLog, Rust, or generated bindings are introduced.

## Verification

- Red log: `/tmp/epistemos-graph-event-trace-inspector-pr9-red-20260502.log`
- Green log: `/tmp/epistemos-graph-event-trace-inspector-pr9-green-20260502.log`
- Focused command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/GraphEventAuditProjectionTests test`
- Result: `✔ Test run with 4 tests in 1 suite passed` and `** TEST SUCCEEDED **`.
- Note: Xcode still printed the known CodeEdit package SwiftLint script-phase footer after success; the process exited 0 and the selected Swift Testing suite passed.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §4
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §10

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 8 - Durable GraphEvent Mutation Mapping
- Deviation: none. This is the new exact live/read-only consumer gate required after PR8.

## Failure-Proof Guardrails (post-merge)

- grep: `rg -n "graphProjectionReport|refreshGraphProjectionReport\\(\\)|GraphEventAuditProjectionService\\(\\)\\.auditReport\\(limit: 100\\)|Graph projection" Epistemos/Views/Capture/TraceInspectorView.swift`
- forbidden grep: `rg -n "saveGraphEvent|saveMutationEnvelope|graphEvents\\(|MutationOpLog|OpLog|HaloController|GraphEventVisibilityRow|Timer|DispatchSourceTimer|repeatForever|while !Task\\.isCancelled" Epistemos/Views/Capture/TraceInspectorView.swift` returns no matches.
- service grep: `rg -n "nonisolated final class GraphEventAuditProjectionService: @unchecked Sendable" Epistemos/Engine/GraphEventAuditProjectionService.swift`
- log: `✔ Test "trace inspector exposes read-only GraphEvent projection summary" passed`
- test: `GraphEventAuditProjectionTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/graph-event-trace-inspector-projection-pr9/aggregator.md`
- `docs/fusion/fleet/graph-event-trace-inspector-projection-pr9/claude-red-team/attacks.md`

## Usefulness

usefulness: +1

usefulness_reason: Adds a small real user-visible diagnostic consumer for the durable GraphEvent projection while preserving the protected graph/Rust boundary.
