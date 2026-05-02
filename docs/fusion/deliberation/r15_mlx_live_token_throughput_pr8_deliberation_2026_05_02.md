# R15 MLX Live Token Throughput - PR8 Deliberation

Date: 2026-05-02
Branch: feature/landing-liquid-wave
Scope: R15 benchmark harness only

## Gate

Add an opt-in benchmark harness for live local MLX token-throughput measurement
through the actual Epistemos local runtime. This gate may prove reachability and
record blocked-run evidence, but it may not claim tok/s unless a real live run
writes a finite JSON artifact.

## Approved

- `EpistemosTests/Benchmarks/MLXThermalBenchTests.swift`
- `EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`
- This deliberation record
- R15 current-state/workcard docs

## Explicitly Not Approved

- Production `MLXInferenceService` changes
- `LocalMLXClient` production behavior changes
- `LocalPackages/mlx-swift-lm/**` changes
- Thermal-policy changes
- Five-minute thermal-soak release claims
- Generated bindings/libraries
- Xcode project or entitlement changes
- Graph-engine, graph renderer, or note editor changes

## Evidence

Red:
`/tmp/epistemos-r15-mlx-live-token-pr8-red-20260502.log`

The new source guard failed against the previous MLX benchmark file because it
lacked `MLXLiveTokenThroughputBaselineRunner`, `MLXInferenceService(snapshot:)`,
`LocalMLXClient(`, `live_mlx_token_throughput_fixture`,
`EPISTEMOS_RUN_LIVE_MLX_TOKEN_BENCHMARK`, and
`not_five_min_thermal_soak`.

Gated green:
`/tmp/epistemos-r15-mlx-live-token-pr8-gated-green-2-20260502.log`

Focused command:

```bash
set -o pipefail
EPISTEMOS_BENCHMARK_RESULTS_DIR="$(mktemp -d /tmp/epistemos-pr8-results.XXXXXX)" xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests -only-testing:EpistemosTests/MLXThermalBenchTests test 2>&1 | tee /tmp/epistemos-r15-mlx-live-token-pr8-gated-green-2-20260502.log
```

Result: `TEST SUCCEEDED`; 15 Swift Testing tests passed across 2 suites.
Existing SwiftLint package-plugin lines appeared after success, same as earlier
R15 slices.

Live env attempt:
`/tmp/epistemos-r15-mlx-live-token-pr8-live-green-20260502.log`

The environment-variable opt-in did not reach the hosted Swift Testing process;
the live writer test returned without running the model path.

Live sentinel attempt:
`/tmp/epistemos-r15-mlx-live-token-pr8-live-sentinel-20260502.log`

The sentinel opt-in reached the live path, installed model discovery succeeded,
and `MLXInferenceService`/`LocalMLXClient` began the stream path. The run then
stopped at the canonical memory preflight with
`.insufficientMemory(modelID: "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit", requiredGB: 12, availableGB: 4)`.

## Runtime Claim

The harness is wired to the real local runtime:
`InferenceState` selects the installed DeepSeek R1 7B MLX model,
`MLXInferenceService(snapshot:)` owns the runtime, and `LocalMLXClient.stream`
is the token path. The opt-in switch is explicit:
`EPISTEMOS_RUN_LIVE_MLX_TOKEN_BENCHMARK=1` or
`/tmp/epi-live-mlx-token-benchmark`.

This gate does not claim live MLX tok/s, five-minute thermal soak, model-loader
readiness under pressure, or release fitness. There is no PR8 throughput JSON
artifact yet because the only true live attempt was blocked by memory preflight.

## Follow-Up

Run the same harness under sufficient-memory conditions, then promote the
result only if the test writes a finite `tokens_per_second` JSON report through
`BenchmarkRunRecorder`. The later release floor still needs a five-minute
thermal soak with temperature, power, and throttling evidence.
