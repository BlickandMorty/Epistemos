---
role: codex-red-team
slice: oplog-replay-bundle-production-visibility-pr7
brief: docs/fusion/deliberation/oplog_replay_bundle_production_visibility_pr7_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 3
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 1
verdict: brief-approved
usefulness: +1
usefulness_reason: "Approves the slice only if implementation remains read-only and raw ABI-free in Settings."
---

## Attacks

### A1 - Settings must not own raw OpLog ABI [P2]
**Surface:** `OpLogProjectionHealthRow`.
**Attack:** A visibility row that calls `oplog_*` directly would violate the existing ABI confinement. It must call a Swift report/service abstraction or pure bundle summary only.
**Evidence:** `RustOpLogFFIClient.swift` owns raw `oplog_*` symbols.
**Mitigation proposed:** Add source guards proving `OpLogProjectionHealthRow.swift` contains no raw ABI symbol names.

### A2 - Visibility must not become repair/export UI [P2]
**Surface:** Settings diagnostics.
**Attack:** Production visibility is read-only; adding buttons or export actions would expand scope into product UX/manual verification and possibly privacy review.
**Evidence:** Card 6 forbids repair UI and mutation behavior in follow-up gates unless explicitly named.
**Mitigation proposed:** Source guard for no `Button(`, repair methods, mutation calls, timers, or `.task` loops in the row.

### A3 - Counts must not imply full replay verification [P3]
**Surface:** User-visible row copy.
**Attack:** Bundle counts are evidence of export visibility, not proof of complete product replay readiness or live trace verification.
**Evidence:** Current state still leaves deeper audit/repair and production replay UX open.
**Mitigation proposed:** Keep row wording to counts/latest id and docs to PR7 visibility only.

## Brief verdict
Ship the brief if implementation/test changes stay inside the named files and keep visibility read-only.
