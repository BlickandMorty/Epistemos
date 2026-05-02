# R15 sqlite-vec Swift Placeholder Retirement PR5 Deliberation - 2026-05-01

## Scope

Retire the stale sleep-based Swift sqlite-vec benchmark body now that PR4 has a
real Rust `vec0` KNN fixture baseline and committed JSON report.

## Evidence

- PR4 committed `epistemos-core/tests/sqlite_vec_knn_baseline.rs`.
- PR4 committed
  `benchmarks/results/2026-05-01t00-00-00-000z-r15-sqlite-vec-knn-sqlite_vec_knn_100k_32d.json`.
- `EpistemosTests/Benchmarks/SQLiteVecKNNBenchTests.swift` still contained a
  `Task.sleep` body and placeholder metadata, which can mislead later agents.

## Decision

Keep the Swift suite disabled/manual, but make it verify the committed PR4 JSON
report instead of producing fake timing samples. Add a source guard proving the
Swift benchmark references the real PR4 fixture and contains no sleep or
placeholder text.

## Allowed Files

- `EpistemosTests/Benchmarks/SQLiteVecKNNBenchTests.swift`
- `EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`
- `docs/fusion/deliberation/r15_sqlite_vec_swift_placeholder_retirement_pr5_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_058_2026_05_01.md`

## Forbidden Files

- Production Swift storage/search paths
- `graph-engine/**`
- `epistemos-shadow/**`
- Generated bindings
- Xcode project files

## Red Evidence

Command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test
```

Result:

- Failed because the Swift KNN benchmark did not contain the PR4 measurement
  name or real fixture metadata.
- Failed because the Swift KNN benchmark still contained `Task.sleep` and
  placeholder text.
- Log:
  `/tmp/epistemos-r15-sqlite-vec-swift-placeholder-pr5-red-xcode-20260501.log`

## Green Plan

Run the same focused source guard after replacing the Swift KNN body with a
report-backed check.

## Green Evidence

Command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test
```

Result:

- `5` tests in `R15 Benchmark Harness Source Guards` passed.
- Xcode reported `** TEST SUCCEEDED **`.
- The inherited CodeEdit SwiftLint command failures still appeared after test
  success; this is not caused by this PR5 slice.
- Log:
  `/tmp/epistemos-r15-sqlite-vec-swift-placeholder-pr5-green-xcode-20260501.log`

## Rollback

Restore the previous Swift benchmark body and remove the new source guard.

## Stop Triggers

- The Swift benchmark tries to run a fake timing loop.
- The slice needs production GRDB/search wiring.
- Any protected or generated file changes.
