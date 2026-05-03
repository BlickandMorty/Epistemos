---
role: aggregator
source_fleet: codex-own
slice: r15-renderer-fps-baseline-pr11
date: 2026-05-02
detectives_consumed:
  - detectives/r15-renderer-fps-baseline.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts: []
drift_signals: []
tier: Both
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
usefulness_reason: Converts the open R15 renderer-FPS evidence gap into an exact test/docs-only build slice.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §10 and Card 3 agree that graph renderer internals are protected until baselines exist.
- PR7 already reaches live `GraphEngine`/C FFI but explicitly does not claim frame rate; PR11 should reuse that fixture shape and add only render calls.
- No external web validation is needed because this is a local test harness over existing `GraphEngine.render(width:height:)`.

## Recommended slice shape
Add a `GraphRendererFPSBaselineRunner` beside the existing Graph FFI benchmark runner. It should create a live `GraphEngine` with `CAMetalLayer`, populate the deterministic fixture, warm up a few frames, measure finite FPS samples over repeated `render(width:height:)` calls, and record the reserved JSON artifact through `BenchmarkRunRecorder`. Update source guards and the R15 evidence ledger with explicit `thermal_soak_status=not_five_min_thermal_soak`.

## Failure-proof guardrails
- grep: `rg -n "GraphRendererFPSBaselineRunner|renderer_fps_thermal_soak|live_graph_renderer_frame_rate_fixture|GraphEngine\\.render" EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift EpistemosTests/BenchmarkHarnessSourceGuardTests.swift EpistemosTests/Benchmarks/R15BenchmarkEvidenceLedgerTests.swift`
- log: `TEST SUCCEEDED`
- test: `EpistemosTests/GraphFFIBenchmarkTests`
