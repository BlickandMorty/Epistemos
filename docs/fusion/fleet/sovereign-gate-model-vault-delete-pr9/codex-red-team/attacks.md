---
role: codex-red-team
slice: sovereign-gate-model-vault-delete-pr9
brief: docs/fusion/deliberation/sovereign_gate_model_vault_delete_pr9_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 2
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: No blocking attack; the findings become source-guard requirements.
---

## Attacks

### A1 - Alert target must be captured before async authorization [P2]
**Surface:** `ModelVaultsSidebarSection.swift` alert delete flow.
**Attack:** If the code rereads mutable selection or pending state after `await`, a user could change selection and delete the wrong file/folder.
**Evidence:** Card 9 PR7/PR8 already hardened captured destructive targets.
**Mitigation proposed:** Pass the concrete `ModelVaultDeleteTarget` into `requestDeleteAuthorization(_:)` and call `delete(target)` only with that captured value after `.allowed`.

### A2 - No local biometric APIs in the view [P2]
**Surface:** `ModelVaultsSidebarSection.swift`.
**Attack:** A tempting patch could import `LocalAuthentication` in the view and create a parallel prompt, violating the one-gate invariant.
**Evidence:** `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md §3.2`.
**Mitigation proposed:** Source guard must prove the view contains no `LocalAuthentication`, `LAContext`, `canEvaluatePolicy`, or `evaluatePolicy` references.

## Brief Verdict

Approve the brief. Keep the patch to the model-vault sidebar plus focused SovereignGate tests and docs.
