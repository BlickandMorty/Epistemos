# GraphEvent Audit Visibility PR8 Deliberation - 2026-05-02

## Slice

Card 8 Durable GraphEvent PR8 exposes the already-closed PR6 audit projection
report inside the already-mounted Settings `GraphEventVisibilityRow`.

## Gate

Allowed write set for this slice:

- `Epistemos/Views/Settings/GraphEventVisibilityRow.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/deliberation/graph_event_audit_visibility_pr8_deliberation_2026_05_02.md`
- `docs/fusion/fleet/graph-event-audit-visibility-pr8/**`
- `docs/fusion/fleet/REGISTRY.md`

Forbidden for this slice:

- `Epistemos/Views/Settings/SettingsView.swift`
- `Epistemos/Views/Graph/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- `Epistemos/State/EventStore.swift`
- `Epistemos/Engine/GraphEventAuditProjectionService.swift`
- Halo, Theater, retrieval, OpLog workers, Rust OpLog FFI, generated bindings,
  EventStore schema, mutation, repair, polling, timers, projection workers,
  Xcode project, entitlement, generated-library, staging, stash, or branch
  changes.

## Evidence

- Red source guard: `grep -q 'GraphEventAuditProjectionService' Epistemos/Views/Settings/GraphEventVisibilityRow.swift` exited 1 before implementation.
- Focused test evidence inside full Xcode run:
  `/tmp/epistemos-graph-event-audit-visibility-pr8-green-20260502.log`
  contains `✔ Test "GraphEvent visibility row is read-only and mounted in Settings" passed after 0.002 seconds.`
- Red Team guard-hardening:
  `/tmp/epistemos-graph-event-audit-visibility-pr8-source-guard-r2-20260502.log`
  contains `GraphEvent audit visibility hardened source guard passed` after the
  existing test was extended to scan `GraphEventAuditProjectionService.swift`.
- Full Xcode run note: the relevant source-guard test passed, then the wider
  suite stalled later on an unrelated test process and was terminated after no
  new log output.
- Build:
  `/tmp/epistemos-graph-event-audit-visibility-pr8-build-20260502.log`
  contains `** BUILD SUCCEEDED **`; Xcode still printed the known vendored
  CodeEdit SwiftLint package-plugin footer after success.
- Test bundle compile:
  `/tmp/epistemos-graph-event-audit-visibility-pr8-build-for-testing-20260502.log`
  contains `** TEST BUILD SUCCEEDED **`; the same known CodeEdit SwiftLint
  package-plugin footer appeared after success.

## Decision

Approved exactly as scoped. Red Team returned no P0/P1 attacks, and its one P3
guard-hardening recommendation was fixed before commit. PR8 is a bounded
read-only Settings visibility slice: it refreshes the existing PR6
`GraphEventAuditProjectionService` report on appear/refresh, displays
event/node/edge/latest-event counts, and adds no mutation, repair, renderer,
retrieval, Halo, Theater, OpLog, Rust, generated-binding, polling, timer,
projection-worker, or Settings mount behavior.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §2`
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:321`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:1036`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:1099`

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 8 - Durable GraphEvent Mutation Mapping
- Deviation: none. This is the new deliberation gate required by Card 8 for a future GraphEvent consumer projection, scoped to the existing Settings row and source guard.

## Failure-proof guardrails (post-merge)

- grep: `GraphEventAuditProjectionService().auditReport(limit: 100)`
- grep: `graphEventProjectionSnapshot(limit:)`
- forbidden grep: `saveGraphEvent|saveMutationEnvelope|graphEvents\(|Timer|DispatchSourceTimer`
- log: `✔ Test "GraphEvent visibility row is read-only and mounted in Settings" passed`
- test: `GraphEvent visibility row is read-only and mounted in Settings`

## Fleet evidence packet

- `docs/fusion/fleet/graph-event-audit-visibility-pr8/aggregator.md`
- `docs/fusion/fleet/graph-event-audit-visibility-pr8/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Adds visible audit projection status to Settings without widening the durable GraphEvent substrate.
