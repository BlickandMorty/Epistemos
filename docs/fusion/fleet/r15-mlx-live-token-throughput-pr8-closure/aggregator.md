---
role: aggregator
source_fleet: codex-own
slice: r15-mlx-live-token-throughput-pr8-closure
date: 2026-05-03
detectives_consumed:
  - detectives/r15-mlx-live-token-throughput.md
web_consumed: []
claude_side_fleet_consumed:
  - none
canon_gaps_opened: []
conflicts: []
drift_signals: []
tier: Pro
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none
ready_for_pipeline_builder: false
missing_artifacts:
  - Sufficient-memory live MLX benchmark JSON artifact
input_usefulness_rollup:
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Prevents a false tok/s closure and frees the queue to continue elsewhere.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §9 anchors this slice to the local model / MLX evidence lane.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:985` says live MLX token throughput remains the last code-safe R15 specialized baseline.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:333` says PR8 has no tok/s JSON artifact yet.
- `EpistemosTests/Benchmarks/MLXThermalBenchTests.swift:215` still contains the real opt-in live token-throughput harness.
- `Epistemos/Engine/MLXInferenceService.swift:1621` still blocks insufficient-memory loads before model execution.

## Recommended Slice Shape

No implementation order should be issued for R15 PR8 in this round. The only safe outcome is to leave PR8 open and continue to the next autonomous code-safe lane. A future R15 PR8 closure can resume from this artifact when available memory is sufficient and should then run the existing opt-in harness, inspect the generated JSON, and only then update `R15BenchmarkEvidenceLedgerTests.swift`.

## Failure-Proof Guardrails

- grep: `rg -n "r15-mlx-live-token-throughput-baseline-mlx_live_token_throughput_deepseek7b_32" EpistemosTests/Benchmarks/R15BenchmarkEvidenceLedgerTests.swift`
- log: `available_gib_floor=4 required_gib=12 headroom_gib=6 decision=block`
- test: `EpistemosTests/R15BenchmarkEvidenceLedgerTests`
