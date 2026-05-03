---
role: codex-red-team
slice: runtime-contract-error-class-bridge-pr30
brief: docs/fusion/deliberation/runtime_contract_error_class_bridge_pr30_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 1
p0_attacks: 0
p1_attacks: 0
p2_attacks: 1
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Confirms the slice is safe if generated bindings are handled deliberately.
---

## Attacks

### A1 - Generated binding drift [P2]

**Surface:** Allowed files and acceptance.
**Attack:** The brief changes the UDL shape, so the generated Swift binding can change. If the generated binding is not regenerated and staged intentionally, Swift may compile against stale payload types or future Xcode builds may recreate a different diff.
**Evidence:** `build-epistemos-core.sh` regenerates `build-rust/swift-bindings/epistemos_core.swift` from `epistemos-core/uniffi/epistemos_core.udl`.
**Mitigation proposed:** Run the existing epistemos-core build path or the focused Xcode test that invokes it, then inspect and stage only the generated epistemos-core binding files that actually changed.

## Brief Verdict

Approved. No P0/P1 issues if the implementation keeps thrown API errors typed as `RuntimeContractError`, changes record and non-throwing input payloads to strings, and verifies absence of `Can't lift flat errors` in the focused green log.
