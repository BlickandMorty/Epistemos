---
role: claude-red-team
slice: graph-event-audit-visibility-pr8
brief: docs/fusion/deliberation/graph_event_audit_visibility_pr8_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 1
p0_attacks: 0
p1_attacks: 0
p2_attacks: 0
p3_attacks: 1
verdict: brief-approved
usefulness: +1
usefulness_reason: Surfaced one guard-hardening issue, fixed before commit.
---

## Attacks

### A1 - Source guard did not scan delegated service [P3]

**Surface:** `EpistemosTests/CognitiveSubstrateTests.swift:2648`

**Attack:** The row source guard originally scanned `GraphEventVisibilityRow.swift`
only. Since PR8 delegates to `GraphEventAuditProjectionService()`, a future
mutation or timer inside that service could bypass the row-only read-only guard.

**Evidence:** `GraphEventVisibilityRow.swift:61` delegates to the service.
`GraphEventAuditProjectionService.swift:43` currently calls only
`graphEventProjectionSnapshot(limit:)`.

**Mitigation proposed:** Extend the existing source guard to load
`GraphEventAuditProjectionService.swift`, require its bounded snapshot call, and
forbid `saveGraphEvent`, `saveMutationEnvelope`, `graphEvents(`, `Timer`, and
`DispatchSourceTimer`.

## Brief verdict

No P0/P1 attacks. Brief approved after the P3 guard-hardening mitigation landed.
