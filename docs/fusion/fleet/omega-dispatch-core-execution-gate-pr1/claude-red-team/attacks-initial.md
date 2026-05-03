---
role: claude-red-team
slice: omega-dispatch-core-execution-gate-pr1
brief: docs/fusion/deliberation/omega_dispatch_core_execution_gate_pr1_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 4
p0_attacks: 0
p1_attacks: 1
p2_attacks: 2
p3_attacks: 1
verdict: brief-revise
usefulness: +1
usefulness_reason: Gate logic and protected-path discipline are correct; one execution-coverage gap is a genuine stop-trigger miss.
---

## Attacks

### A1 — `tools/call` deny tested only for `run_command` [P1]
**Surface:** `EpistemosTests/OmegaToolSchemaGrammarTests.swift`
**Attack:** The `tools/list` test asserts all five disallowed names disappear, but `tools/call` denial only proves `run_command`. If `run_persistent`, `get_ui_tree`, `see`, or `click` diverged from the list path, they could return `pending`.
**Evidence:** The brief stop trigger explicitly names `run_command`, `run_persistent`, `get_ui_tree`, `see`, and `click`.
**Mitigation proposed:** Parameterize the deny test over all five names.

### A2 — Pro/Research `tools/list` test validates Rust dispatcher output, not Swift gate invariant [P2]
**Surface:** `omegaProResearchDispatchListPreservesFullRegisteredTools`
**Attack:** For `.proResearch`, the gate returns `nil` and the Rust dispatcher handles `tools/list`. The test checks Rust output against Swift registry count, which is useful but indirect.
**Evidence:** `policyGateResponse` falls through when `visibleNames == allNames`.
**Mitigation proposed:** Keep as parity coverage or add explicit gate-path observability later.

### A3 — `tools/list` silent passthrough if Core surfaced tools accidentally equals full set [P2]
**Surface:** `MCPBridge.policyGateResponse`
**Attack:** If Core policy accidentally returns the full set, `visibleNames == allNames` would fall through and expose full Rust `tools/list`.
**Evidence:** The first implementation used `guard visibleNames != allNames else { return nil }` for all distributions.
**Mitigation proposed:** Make Pro/Research passthrough explicit and have Core/current-build return the policy-filtered response.

### A4 — Fallback JSON-RPC error hardcodes `id: null` [P3]
**Surface:** `serializeJsonRpc`
**Attack:** The fallback is unreachable in practice but would lose request correlation if JSON serialization failed.
**Evidence:** The fallback string includes `"id":null`.
**Mitigation proposed:** Non-blocking; leave unless the serializer becomes externally reachable with arbitrary values.

## Brief verdict
The protected-path and registration-preservation constraints are satisfied: only allowed Swift files were touched, and Rust dispatcher plus `registerBuiltinTools()` remain unchanged. The gate logic is sound, but the call-level deny test must cover all stop-trigger tool names before approval.

CLAUDE-RETURN: role=RED-TEAM | slice=omega-dispatch-core-execution-gate-pr1 | round=41 | artifact=docs/fusion/fleet/omega-dispatch-core-execution-gate-pr1/claude-red-team/attacks.md | usefulness=+1 | p0=0 | p1=1
