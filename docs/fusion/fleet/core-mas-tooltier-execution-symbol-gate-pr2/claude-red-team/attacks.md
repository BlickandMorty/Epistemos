---
role: claude-red-team
slice: core-mas-tooltier-execution-symbol-gate-pr2
brief: docs/fusion/deliberation/core_mas_tooltier_execution_symbol_gate_pr2_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 2
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Codex fallback red-team found guardrail risks but no blocker if the patch stays in ToolTierBridge/tests only.
---

## Attacks

### A1 - Broadening the Core allow-list would invert the slice [P2]
**Surface:** `ToolSurfacePolicy.coreAppStoreAllowedToolNames`
**Attack:** The fix must not add Pro-only tool names to the Core allow-list just to make tests pass. That would turn an execution guard into a capability leak.
**Evidence:** `Epistemos/Bridge/ToolTierBridge.swift`
**Mitigation proposed:** Tests should assert representative Pro-only names are denied in Core/App Store and preserve the existing allow-list.

### A2 - Denying after FFI is too late [P2]
**Surface:** `ToolTierBridge.executeToolCallBridged`
**Attack:** If the policy check occurs after `executeToolCall` or `executeToolCallFiltered`, stale model-emitted tool names can still reach Rust. The gate has to happen before any `#if canImport(agent_coreFFI)` execution call.
**Evidence:** `Epistemos/Bridge/ToolTierBridge.swift`
**Mitigation proposed:** Put the `ToolSurfacePolicy.isSurfacedToolName` guard at the top of the bridged execution helper and test it in no-bindings unit-test builds.

## Brief Verdict

Ship the brief if the implementation stays two-file, test-first, and fail-closed. No P0/P1 attacks remain.
