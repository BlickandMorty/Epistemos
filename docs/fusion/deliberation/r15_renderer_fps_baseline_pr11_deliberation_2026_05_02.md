# R15 Renderer FPS Baseline PR11 Deliberation

Date: 2026-05-02
Branch: feature/landing-liquid-wave
Scope: R15 benchmark harness only

## Report Before Code

Slice:          R15 renderer FPS baseline PR11
Tier:           Both
Files touched:
- `EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift`
- `EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`
- `EpistemosTests/Benchmarks/R15BenchmarkEvidenceLedgerTests.swift`
- `benchmarks/results/2026-05-02t00-00-00-000z-r15-renderer-fps-baseline-renderer_fps_thermal_soak.json`
- `docs/fusion/**` round artifacts
Protected paths:
- `graph-engine/**`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `Epistemos/Graph/GraphEngine.swift`
- generated bindings/libraries
Gate:           SovereignGate touchpoint? none
Risks:          P1 if the harness claims five-minute/manual thermal soak; P0 if it edits production renderer/graph-engine paths.
Verification:   focused red/green `xcodebuild` logs under `/tmp/epistemos-r15-renderer-fps-pr11-*.log`
Rollback:       revert the PR11 benchmark/test/docs/result artifact only.
Stop triggers:
- The implementation needs `graph-engine/**`, `MetalGraphView.swift`, `GraphEngine.swift`, generated bindings, project files, or entitlements.
- The benchmark cannot produce finite positive FPS samples from `GraphEngine.render(width:height:)`.
- The metadata omits `thermal_soak_status=not_five_min_thermal_soak`.

## Gate

Close the remaining code-safe R15 renderer evidence gap with a test-owned offscreen live renderer frame-rate fixture. This is a benchmark gate before optimization, not a renderer optimization, product-runtime claim, manual runtime claim, or five-minute thermal-soak readiness claim.

## Approved

- Add `GraphRendererFPSBaselineRunner` under `EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift`.
- Reuse/extract deterministic GraphEngine fixture setup already present in PR7 rather than copy-pasting setup logic.
- Add source guards proving PR11 calls `GraphEngine.render(width:height:)` and records honest metadata.
- Add a JSON artifact only after the opt-in live renderer test writes finite positive FPS samples.
- Update R15 ledger/current-state/workcard/post-merge guard docs.

## Explicitly Not Approved

- `graph-engine/**` source changes.
- `Epistemos/Views/Graph/MetalGraphView.swift`.
- `Epistemos/Views/Graph/HologramController.swift`.
- `Epistemos/Graph/GraphEngine.swift`.
- Physics tuning, renderer optimization, or BoltFFI migration.
- MLX/live model benchmarking.
- Xcode project, entitlements, generated bindings/libraries.

## Acceptance

- Focused red test fails before the runner exists.
- Focused green test passes with finite positive FPS samples when the opt-in
  sentinel `/tmp/epi-renderer-fps-benchmark` is enabled.
- Ledger names the renderer artifact as closed only with honest metadata: `fixture_status=live_graph_renderer_frame_rate_fixture`, `render_status=live_render_frame_rate`, `layer_status=offscreen_cAMetalLayer_drawable`, and `thermal_soak_status=not_five_min_thermal_soak`.
- Protected-path scan shows no staged production renderer/graph-engine changes.

## Verification Evidence

- Red log: `/tmp/epistemos-r15-renderer-fps-pr11-red-20260502.log` failed first on the new source guard before `GraphRendererFPSBaselineRunner` existed.
- Green log: `/tmp/epistemos-r15-renderer-fps-pr11-green-20260502.log` passed the focused benchmark/source-guard/ledger suite.
- Artifact log: `/tmp/epistemos-r15-renderer-fps-pr11-artifact-suite-20260502.log` ran the opt-in renderer benchmark and passed 5 tests in the `GraphFFIBenchmarkTests` suite.
- Artifact: `benchmarks/results/2026-05-02t00-00-00-000z-r15-renderer-fps-baseline-renderer_fps_thermal_soak.json` records 5 finite positive samples, p50 `119.65399546442954` fps, p95 `119.8709496648827` fps, and `thermal_soak_status=not_five_min_thermal_soak`.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §10
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 3
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` Safe Next Build Order §1

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 3 - R15 Benchmark Harness Foundation
- Deviation: none. This is a later real fixture gate for the open renderer-FPS surface, with no production renderer edits.

## Failure-proof guardrails (post-merge)

- grep: `rg -n "GraphRendererFPSBaselineRunner|renderer_fps_thermal_soak|live_graph_renderer_frame_rate_fixture|GraphEngine\\.render" EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift EpistemosTests/BenchmarkHarnessSourceGuardTests.swift EpistemosTests/Benchmarks/R15BenchmarkEvidenceLedgerTests.swift`
- log: `✔ Test "renderer FPS baseline writes finite decodable report when explicitly enabled" passed`
- test: `EpistemosTests/GraphFFIBenchmarkTests`

## Fleet evidence packet

- `docs/fusion/fleet/r15-renderer-fps-baseline-pr11/aggregator.md`
- `docs/fusion/fleet/r15-renderer-fps-baseline-pr11/claude-red-team/attacks.md` (added after Red Team returns)

## Usefulness

usefulness: +1
usefulness_reason: Turns the remaining renderer-FPS baseline from an open claim into a measurable, test-owned artifact without touching production renderer code.
