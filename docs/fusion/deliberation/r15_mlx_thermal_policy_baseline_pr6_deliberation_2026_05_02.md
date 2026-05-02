# R15 MLX Thermal Policy Baseline PR6 Deliberation - 2026-05-02

## Gate

Approved action: replace the disabled/sleep-based MLX thermal benchmark
placeholder with an honest test-only fixture baseline over the production
thermal policy decision point available today.

This does not claim live MLX inference token throughput under thermal soak. The
baseline measures `PowerGate.deferSnapshot` policy decisions used for MLX
dispatch backpressure, and the report metadata must say that directly.

## Authority Evidence

- Card 3 keeps R15 benchmark work test-only until real fixture gates exist.
- `EpistemosTests/Benchmarks/MLXThermalBenchTests.swift` was a disabled manual
  placeholder and used `Task.sleep`, so it was not an authoritative baseline.
- `PowerGate.deferSnapshot` already exposes the production policy decision for
  low-power, thermal, battery, and memory-pressure deferral.
- Live MLX model loading, token generation, and thermal soak require a later
  explicit gate.

## Files Approved

- `EpistemosTests/Benchmarks/MLXThermalBenchTests.swift`
- `EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`
- `benchmarks/results/2026-05-02t00-00-00-000z-r15-mlx-thermal-policy-baseline-mlx_thermal_policy_snapshot_1000.json`
- `docs/fusion/deliberation/r15_mlx_thermal_policy_baseline_pr6_deliberation_2026_05_02.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`

## Files Forbidden

- `Epistemos/KnowledgeFusion/MLXInferenceBridge.swift`
- `Epistemos/Engine/MLXInferenceService.swift`
- `LocalPackages/mlx-swift-lm/**`
- `agent_core/**`
- generated Swift/header bindings
- generated libraries
- `graph-engine/**`
- `Epistemos/Views/Graph/**`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- production FFI replacement code
- Xcode project files, entitlements, DerivedData, `.xcresult`, stashes, or
  branch operations. Exact-file staging/commit by the overseer is allowed only
  under the user's active commit-as-you-go instruction.

## Implementation Contract

- Remove the disabled placeholder status from `MLXThermalBenchTests`.
- Remove sleep-based timing from the benchmark.
- Use `BenchmarkRunRecorder` and the existing machine-readable JSON schema.
- Exercise real `PowerGate.deferSnapshot` decisions across canonical policy
  scenarios.
- Metadata must explicitly say this is not live MLX inference tok/s.
- Keep this out of production hot paths.

## Tests And Logs

Red:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test
```

Log:

- `/tmp/epistemos-r15-mlx-thermal-pr6-red-20260502.log`

Expected red reason: the new source guard detects the existing disabled
sleep-based placeholder in `MLXThermalBenchTests.swift`.

Green:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/MLXThermalBenchTests -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test
```

Log:

- `/tmp/epistemos-r15-mlx-thermal-pr6-green-20260502.log`

Guardrails:

```bash
git diff --check -- EpistemosTests/Benchmarks/MLXThermalBenchTests.swift EpistemosTests/BenchmarkHarnessSourceGuardTests.swift docs/fusion benchmarks/results
rg -n "Task\\.sleep|placeholder|@Suite\\(\"MLX thermal-pressure inference\", \\.disabled|Manual long-running benchmark|try\\? BenchmarkRunRecorder" EpistemosTests/Benchmarks/MLXThermalBenchTests.swift
git diff --cached --name-only | rg '^(graph-engine/|agent_core/|build-rust/|Epistemos\\.xcodeproj/|Epistemos/Views/Notes/ProseEditor|Epistemos/Views/Graph/MetalGraphView|Epistemos/Views/Graph/HologramController|.*DerivedData|.*\\.xcresult)'
```

## Acceptance

- Wired: the MLX thermal benchmark suite is an enabled Swift Testing suite.
- Reachable: the focused test writes one deterministic JSON baseline report.
- Visible: report metadata distinguishes `mlx_thermal_policy_fixture` from live
  MLX inference token throughput.

## Stop Triggers

- Live MLX model loading or token generation is required to satisfy this PR.
- Any MLX runtime package, generated binding, graph-engine, or production FFI
  edit becomes necessary.
- The fixture cannot produce finite repeatable samples.
- The slice starts touching graph/editor/production inference files.

## Closeout - 2026-05-02

Closed as implemented and verified.

Artifacts:

- `benchmarks/results/2026-05-02t00-00-00-000z-r15-mlx-thermal-policy-baseline-mlx_thermal_policy_snapshot_1000.json`
- p50: `206.375` ns/decision
- p95: `229.9998` ns/decision
- p99: `235.46635999999998` ns/decision
- samples: `9`
- decisions per sample: `1000`

Verification:

- Red source guard failed as expected before implementation.
- Green focused run passed 10 Swift Testing tests across
  `BenchmarkHarnessSourceGuardTests` and `MLXThermalBenchTests`.
- `git diff --check` passed for the approved docs, test, and result paths.
- Source guard grep returned no forbidden placeholder/sleep/disabled strings.
- Xcode printed the existing SwiftLint package-plugin failures after
  `TEST SUCCEEDED`; the focused command exited 0.

Boundary:

This closes only the MLX thermal policy/backpressure fixture over
`PowerGate.deferSnapshot`. Live MLX token throughput under thermal soak remains
open for a later explicit runtime gate.
