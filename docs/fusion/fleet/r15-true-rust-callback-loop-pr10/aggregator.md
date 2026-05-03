---
role: aggregator
source_fleet: codex-own
slice: r15-true-rust-callback-loop-pr10
date: 2026-05-03
detectives_consumed:
  - detectives/r15-true-rust-callback-loop.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts: []
drift_signals: []
tier: All
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
usefulness_reason: Converts the open R15 callback-loop baseline into a test-first implementation gate.
---

## Reconciled findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §8` and Card 3 both treat FFI/benchmark evidence as measurement scaffolding before optimization.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:941` says PR5 is generated UniFFI callback-handle evidence only, not true Rust callback-loop evidence.
- `EpistemosTests/Benchmarks/R15BenchmarkEvidenceLedgerTests.swift:158` currently forbids the true Rust callback-loop JSON filename from the closed ledger, so PR10 must update the ledger only after a real JSON result exists.
- `agent_core/src/bridge.rs:83` gives the existing callback interface; a benchmark-only export can reuse it without altering `run_agent_session`.

## Recommended slice shape

Add one benchmark-only UniFFI export in `agent_core/src/bridge.rs`, add Swift benchmark coverage in `EpistemosTests/Benchmarks/UniFFICallbackThroughputTests.swift`, update source guards and the R15 evidence ledger, and generate a deterministic JSON result under `benchmarks/results/`.

## Failure-proof guardrails

- grep: `run_r15_true_rust_callback_loop_benchmark|true_rust_callback_loop|rust_loop_status`
- log: `TEST SUCCEEDED`
- test: `EpistemosTests/UniFFICallbackThroughputTests`
