---
role: claude-red-team
slice: graph-event-trace-inspector-projection-pr9
brief: docs/fusion/deliberation/graph_event_trace_inspector_projection_pr9_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 6
p0_attacks: 0
p1_attacks: 2
p2_attacks: 2
p3_attacks: 2
verdict: brief-revise
usefulness: +1
usefulness_reason: Found two real refresh-path risks before commit: possible main-actor DB work and stale concurrent refresh wins.
---

## Attacks

### A1 - Synchronous audit report could stall the main actor [P1]
**Surface:** `Epistemos/Views/Capture/TraceInspectorView.swift`
**Attack:** The first draft refreshed `GraphEventAuditProjectionService().auditReport(limit: 100)` synchronously from the `@MainActor` view model. If the service touched SQLite, the debug sheet could block the UI thread.
**Evidence:** `TraceInspectorViewModel` default provider and Claude return line in `/tmp/epistemos-graph-event-trace-inspector-pr9-claude-red-team.out`.
**Mitigation proposed:** Move report generation into the detached utility snapshot path and make `GraphEventAuditProjectionService` explicitly `nonisolated` / `@unchecked Sendable`.
**Status:** addressed.

### A2 - Concurrent refreshes could write stale trace snapshots [P1]
**Surface:** `Epistemos/Views/Capture/TraceInspectorView.swift`
**Attack:** The first draft spawned untracked utility tasks from both `onAppear` and manual refresh. A slower earlier task could overwrite the newer snapshot.
**Evidence:** `TraceInspectorView.loadTraces()` call sites and Claude return line in `/tmp/epistemos-graph-event-trace-inspector-pr9-claude-red-team.out`.
**Mitigation proposed:** Store a `Task<Void, Never>?`, cancel the previous task on every refresh, and guard cancellation before committing state.
**Status:** addressed.

### A3 - Source-text guard needs non-empty source assertion [P2]
**Surface:** `EpistemosTests/GraphEventAuditProjectionTests.swift`
**Attack:** If the mirrored-source helper returned an empty string, string-presence guards could mislead future audits.
**Evidence:** Claude attack packet A3.
**Mitigation proposed:** Add `#require(!source.isEmpty)` and include the service source in the same guard.
**Status:** addressed.

### A4 - Re-instantiating the projection service every refresh needs a cheap-init contract [P2]
**Surface:** `Epistemos/Engine/GraphEventAuditProjectionService.swift`
**Attack:** Re-instantiation is acceptable only if the service remains a thin closure holder over the bounded EventStore snapshot.
**Evidence:** Claude attack packet A4.
**Mitigation proposed:** Keep service init side-effect-free and prove it can run in the detached utility path.
**Status:** addressed by `nonisolated final class GraphEventAuditProjectionService: @unchecked Sendable`.

### A5 - `graph_write_attempted` trace rows could be misread as write coupling [P3]
**Surface:** `Epistemos/Views/Capture/TraceInspectorView.swift`
**Attack:** Existing trace display includes historical write-attempt records. That is still read-only, but future reviewers should not confuse display with mutation.
**Evidence:** Existing Trace Inspector filter.
**Mitigation proposed:** Keep the source guard forbidding `saveGraphEvent`, `saveMutationEnvelope`, and `graphEvents(` in the Trace Inspector.
**Status:** accepted as read-only.

### A6 - Dirty worktree could cross-contaminate verification [P3]
**Surface:** worktree state.
**Attack:** This repo has many unrelated dirty files. Focused tests must be paired with exact staging and protected-path diff checks.
**Evidence:** `git status --short` during round 37.
**Mitigation proposed:** Stage only PR9 files and run protected-path staged guards before commit.
**Status:** pending final stage guard.

## Brief Verdict

Revised after Red Team: approve only with the nonisolated projection service, detached utility snapshot, task cancellation guard, non-empty source assertions, and exact staging/protected-path checks.
