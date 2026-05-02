# R15 Benchmark Harness JSON Results PR1 Deliberation - 2026-05-01

## Gate

Approved action: **benchmark-harness result recording foundation**.

This gate does not approve graph-engine optimization, BoltFFI migration,
renderer changes, production FFI replacement, MLX model wiring, sqlite-vec
fixture generation, or CI long-running benchmark execution. It only makes the
existing manual benchmark harness emit machine-readable JSON results to the
non-shipping `benchmarks/results/` path and adds source guards so future
optimization slices cannot claim a benchmark baseline without that output.

## Repo Evidence

- `docs/plan/03_EXECUTION_MAP.md` R15 requires benchmark results emitted as JSON
  to `benchmarks/results/<date>.json`.
- `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md` says graph/FFI migration must
  first record payload size, frequency, allocation, Swift main-thread time, Rust
  marshalling time, end-to-end latency, peak memory/copy count where measurable,
  and user-visible symptom where applicable.
- Existing manual Swift benchmark files already live under
  `EpistemosTests/Benchmarks/` and are disabled by default.
- Existing benchmark files currently emit `os_signpost` timings, but do not
  write a shared machine-readable result artifact.

## Decision

Add a test-only benchmark recorder and require the current R15 manual Swift
benchmark suites to call it.

This is intentionally a foundation slice:

- It creates the JSON result path and schema.
- It does not replace placeholder-heavy benchmarks with real MLX/KNN/UniFFI
  fixtures.
- It does not claim R15 complete.
- It gives future graph/FFI/MLX/retrieval work a durable place to write
  baselines before optimization.

## Files Approved

- `EpistemosTests/Benchmarks/BenchmarkRunRecorder.swift`
- `EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift`
- `EpistemosTests/Benchmarks/AFMGenerableBenchTests.swift`
- `EpistemosTests/Benchmarks/MLXThermalBenchTests.swift`
- `EpistemosTests/Benchmarks/SQLiteVecKNNBenchTests.swift`
- `EpistemosTests/Benchmarks/UniFFICallbackThroughputTests.swift`
- `EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`
- `docs/fusion/deliberation/r15_benchmark_harness_json_results_pr1_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_039_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`

## Files Forbidden

- `graph-engine/**`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- production FFI replacement code
- generated Swift/header bindings
- generated libraries
- Xcode project files
- entitlements
- DerivedData, `.xcresult`
- stash, branch, staging, commit, or destructive git operations

## Implementation Contract

- Benchmark suites remain disabled/manual-only by default.
- The recorder writes JSON under `benchmarks/results/`.
- The JSON includes schema version, generated timestamp, suite, measurement,
  unit, finite samples, p50, p95, p99, min, max, sample count, and metadata.
- Empty or non-finite sample sets must not produce successful baseline files.
- This slice must not edit production graph/FFI/hot-path code.
- Placeholder benchmark bodies must not be rebranded as real baselines; they may
  only become machine-readable scaffolding until later fixture gates replace
  them.

## Tests

Red/green source-guard command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test
```

Optional compile smoke for manual benchmark files:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/GraphFFIBenchmarkTests test
```

Guardrails:

```bash
git diff --check -- EpistemosTests/Benchmarks EpistemosTests/BenchmarkHarnessSourceGuardTests.swift docs/fusion
git diff --name-only -- graph-engine Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift Epistemos/Views/Notes/ProseEditor\*.swift
```

## Rollback

Revert only the benchmark recorder, benchmark-file recorder calls, source guard,
and docs for this slice. Existing benchmark files may remain as they were before
PR1.

## Stop Triggers

- Any need to touch graph-engine, renderer/controller, protected editor files,
  generated bindings/libraries, project files, entitlements, stashes, branches,
  staging, or commits.
- Any attempt to claim graph/FFI optimization without running real manual
  benchmark baselines.
- Any benchmark result writer that can silently accept empty or non-finite data.
