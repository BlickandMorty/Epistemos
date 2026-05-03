---
role: codex-red-team
slice: sovereign-gate-custom-tool-delete-pr10
brief: docs/fusion/deliberation/sovereign_gate_custom_tool_delete_pr10_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 2
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: No blocking attack; findings become source-guard requirements if Claude CLI cannot return a packet.
---

## Attacks

### A1 - Custom tool identity must be captured before async authorization [P2]
**Surface:** `AgentControlSettingsView.swift` custom-tool delete button.
**Attack:** If the authorization method reads mutable UI state after `await`, the user could change selection or vault context before deletion. This would mirror the destructive-target race closed in earlier Sovereign Gate slices.
**Evidence:** `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9 PR7-PR9 captured destructive targets before async auth.
**Mitigation proposed:** Pass `tool.name` and `vaultPath` as values into `requestCustomToolDeleteAuthorization(named:vaultPath:)` and call `deleteCustomTool(named:vaultPath:)` only with those values after `.allowed`.

### A2 - No local biometric APIs in Settings view [P2]
**Surface:** `AgentControlSettingsView.swift`.
**Attack:** A tempting patch could import `LocalAuthentication` in Settings and create a parallel prompt, violating the one-gate invariant.
**Evidence:** `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md §3.2`.
**Mitigation proposed:** Source guard must prove the file contains no `LocalAuthentication`, `LAContext`, `canEvaluatePolicy`, or `evaluatePolicy` references.

## Brief Verdict

Approve the brief. Keep the patch to the Agent Control settings view plus focused SovereignGate tests and docs.
