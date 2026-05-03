---
role: claude-red-team
slice: omega-dispatch-core-execution-gate-pr1
brief: docs/fusion/deliberation/omega_dispatch_core_execution_gate_pr1_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 2
p0_attacks: 0
p1_attacks: 0
p2_attacks: 1
p3_attacks: 1
verdict: brief-approved
usefulness: +1
usefulness_reason: P1 from round 41 is closed; guard logic correction also sealed the list fail-open concern.
---

## Attacks

### A2 — Pro/Research `tools/list` test does not assert gate path taken [P2]
**Surface:** `omegaProResearchDispatchListPreservesFullRegisteredTools`
**Attack:** The test verifies that Pro/Research sees the full tool list, which passes whether the response comes from Swift or Rust. This is observability debt rather than a correctness failure because both paths expose the same full list in Pro/Research.
**Evidence:** The gate falls through when `resolvedDistribution == .proResearch` and `visibleNames == allNames`.
**Mitigation proposed:** Add future instrumentation if gate-path observability becomes important.

### A4 — Fallback `serializeJsonRpc` hardcodes `"id":null` [P3]
**Surface:** `MCPBridge.serializeJsonRpc`
**Attack:** If JSON serialization failed, the fallback response would lose request correlation. The path is effectively unreachable for current serializable dictionaries.
**Evidence:** The fallback literal contains `"id":null`.
**Mitigation proposed:** None required for this slice.

## Brief verdict
Both stop-trigger constraints are met: `tools/call` denial is exercised for all five blocked tool names, and the `tools/list` guard uses `resolvedDistribution` so Core/App Store does not fall through to Rust when filtering is active. The `resolvedDistribution` visibility change is minimal, Rust dispatcher registration and execution remain untouched, and no P0/P1 attacks remain.

CLAUDE-RETURN: role=RED-TEAM | slice=omega-dispatch-core-execution-gate-pr1 | round=41 | artifact=docs/fusion/fleet/omega-dispatch-core-execution-gate-pr1/claude-red-team/attacks.md | usefulness=+1 | p0=0 | p1=0
