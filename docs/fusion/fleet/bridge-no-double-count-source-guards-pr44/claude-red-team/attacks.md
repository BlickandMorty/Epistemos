---
role: codex-red-team
slice: bridge-no-double-count-source-guards-pr44
brief: docs/fusion/deliberation/bridge_no_double_count_source_guards_pr44_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 1
p0_attacks: 0
p1_attacks: 0
p2_attacks: 1
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Confirms the slice is test-only and has no production tier leakage.
---

## Attacks

### A1 — Source guards can become stale if source mirror is missing [P2]

**Surface:** `EpistemosTests/AgentEventBridgeNoDoubleCountSourceGuardTests.swift`
**Attack:** The test depends on `SourceMirror` resources. If the source mirror generation breaks, the test fails before asserting the intended invariant.
**Evidence:** Existing source-guard suites use `loadMirroredSourceTextFile`, so this is an accepted test-target pattern.
**Mitigation proposed:** Keep the focused xcodebuild test in the post-merge guard list; if mirror generation regresses, fix the shared source-mirror fixture rather than weakening this test.

## Brief verdict

Ship the brief. No P0/P1 attack blocks the test-only slice.
