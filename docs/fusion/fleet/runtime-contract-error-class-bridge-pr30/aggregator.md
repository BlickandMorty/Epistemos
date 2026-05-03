---
role: aggregator
source_fleet: codex-own
slice: runtime-contract-error-class-bridge-pr30
date: 2026-05-03
detectives_consumed:
  - detectives/runtime-contract-error-class-bridge.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none (Claude side-fleet did not return before Codex verified the slice)
canon_gaps_opened:
  - none
conflicts: []
drift_signals:
  - Current green logs expose a runtime-contract cleanup gap that canon already staged as follow-up.
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none
ready_for_pipeline_builder: true
missing_artifacts: []
input_usefulness_rollup:
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts repeated runtime cleanup drift into a narrow PR30 contract slice.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §8 and §9 anchor this streaming/local runtime contract slice.
- The repeated `Can't lift flat errors` line is caused by carrying a UniFFI flat error type inside generated record payloads and non-throwing input payloads.
- The correct fix is not log suppression; it is an FFI payload boundary correction.
- Thrown errors must remain typed `RuntimeContractError`; record fields and non-throwing inputs should carry bounded raw labels.

## Recommended Slice Shape

Authorize one Core-only runtime-contract PR: red-test failed/cancelled terminal events with error-class payloads, convert record payload and non-throwing input `error_class` values to strings in Rust/UDL, update Swift mapping, regenerate bindings via `build-epistemos-core.sh`, and prove the focused backend runtime contract test passes without `Can't lift flat errors`.

## Failure-Proof Guardrails

- grep: `string? error_class` appears in `epistemos-core/uniffi/epistemos_core.udl`
- grep: `string error_class` appears for `finish_failed` in `epistemos-core/uniffi/epistemos_core.udl`
- grep: `Option<String>` appears for runtime generation `error_class` fields in `epistemos-core/src/runtime_contract.rs`
- log: no `Can't lift flat errors` in the PR30 green log
- test: `BackendRuntimeContractTests`
