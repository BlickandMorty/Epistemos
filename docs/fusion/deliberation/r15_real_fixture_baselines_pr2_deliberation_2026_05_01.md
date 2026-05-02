# R15 Real Fixture Baselines PR2 Deliberation - 2026-05-01

Approved action: **test-only deterministic fixture baseline writer**.

This gate follows R15 PR1, which created the JSON benchmark recorder. PR2 adds a
small focused fixture runner that writes machine-readable baseline reports from
real local work, not placeholder sleeps. It remains benchmark/test-only and does
not approve graph-engine optimization, BoltFFI migration, renderer changes,
editor migration, production FFI replacement, generated binding edits, or
manual long-running benchmark claims.

## Evidence

- `docs/plan/03_EXECUTION_MAP.md` R15 requires benchmark results emitted as JSON
  to `benchmarks/results/<date>.json`, but also marks R15 as test-only.
- `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md` requires payload size,
  frequency, allocation shape, Swift main-thread time, Rust marshalling time,
  end-to-end latency, and copy/memory data where measurable before any hot-path
  migration.
- `docs/architecture/EPISTEMOS_RESEARCH_SYNTHESIS_AND_ACTION_PLAN.md` says no
  migration, editor work, or BoltFFI prototype should start until baseline
  instrumentation exists.
- R15 PR1 added `BenchmarkRunRecorder`, but the existing manual benchmark
  suites still include placeholder sleeps/proxies and are disabled by default.
- `benchmarks/` does not currently exist in the worktree, so PR2 should create
  the non-shipping result path only through this benchmark gate.

## Allowed Write Set

- `EpistemosTests/Benchmarks/BenchmarkFixtureBaselines.swift` (new)
- `EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`
- `benchmarks/results/**`
- Docs under `docs/fusion/**`

## Forbidden Write Set

- `graph-engine/**`
- `epistemos-shadow/**`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- Production graph, editor, FFI, model, retrieval, or runtime code
- Generated Swift/header bindings, generated libraries, Xcode project files,
  entitlements, DerivedData, `.xcresult`, staging, commits, stashes, branch
  operations, or destructive git operations

## Implementation Contract

- Add a test-only fixture runner with deterministic fixture definitions and
  finite measured samples.
- Reports must be written through `BenchmarkRunRecorder` so they use the PR1
  schema.
- Fixture metadata must identify `baseline_kind`, payload size/count where
  relevant, fixture status, and why it is safe to cite as a PR2 fixture
  baseline.
- The runner must not call `Task.sleep`, use placeholder status strings, or
  depend on manual Instruments.
- The focused test should write to a temp directory by default. When
  `EPISTEMOS_BENCHMARK_RESULTS_DIR` is set, the same focused test may write
  stable JSON reports to `benchmarks/results/`.
- Do not enable the disabled long-running benchmark suites in CI.
- Do not claim R15 complete for MLX thermal, sqlite-vec 100k KNN, full graph
  FFI, editor shell, or UniFFI callback throughput; those remain later fixture
  gates.

## Tests And Logs

Red first:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/BenchmarkFixtureBaselineTests -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test
```

Green:

```bash
EPISTEMOS_BENCHMARK_RESULTS_DIR=/Users/jojo/Downloads/Epistemos/benchmarks/results xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/BenchmarkFixtureBaselineTests -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test
```

Guardrails:

```bash
git diff --check -- EpistemosTests/Benchmarks/BenchmarkFixtureBaselines.swift EpistemosTests/BenchmarkHarnessSourceGuardTests.swift benchmarks/results docs/fusion
rg -n "Task\\.sleep|placeholder|Manual benchmark" EpistemosTests/Benchmarks/BenchmarkFixtureBaselines.swift
git diff --name-only -- graph-engine epistemos-shadow Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseEditorView.swift Epistemos/Views/Notes/ProseTextView2.swift
```

## Acceptance

- Red-first tests fail before the fixture runner exists.
- Focused green tests pass and write finite JSON baseline files under
  `benchmarks/results/` when the environment override is set.
- JSON reports decode through `BenchmarkRunReport`, include non-placeholder
  metadata, and contain real measured samples.
- Source guard proves the new fixture runner is not disabled, not sleep-based,
  and not a placeholder rebrand.
- No protected path, graph-engine, production runtime, generated binding,
  project, entitlement, stash, branch, stage, or commit operation is touched.

## Stop Triggers

- The fixture runner needs graph-engine or protected graph/editor edits.
- A benchmark body uses sleeps, static fake samples, or placeholder metadata.
- The test becomes long-running enough to be unsafe for focused verification.
- Xcode requires project-file mutation to discover the new test.
- The slice starts optimizing code instead of recording baselines.

## Closeout - 2026-05-01

Gate status: **passed and closed**.

Implemented:

- Added `BenchmarkFixtureBaselineRunner`, a test-only fixture baseline writer
  with three real local work surfaces: Swift graph payload construction,
  markdown parser FFI, and code-token parser FFI.
- Added focused Swift Testing coverage that decodes the emitted JSON through
  `BenchmarkRunReport`, checks finite samples, confirms fixture metadata, and
  rejects invalid iteration counts.
- Extended the benchmark source guard so the new fixture runner must stay
  enabled, non-sleep-based, and visibly marked as `fixture_pr2_real`.
- Wrote three deterministic JSON baseline reports under `benchmarks/results/`
  through `BenchmarkRunRecorder`.

Generated baseline reports:

- `benchmarks/results/2026-05-01t00-00-00-000z-r15-fixture-baselines-graph_payload_construction_750_nodes.json`
- `benchmarks/results/2026-05-01t00-00-00-000z-r15-fixture-baselines-markdown_parser_160_sections.json`
- `benchmarks/results/2026-05-01t00-00-00-000z-r15-fixture-baselines-code_token_parser_1200_lines.json`

Red-first evidence:

- `/tmp/epistemos-r15-real-fixture-pr2-red-xcode-20260501.log`
- `/tmp/epistemos-r15-real-fixture-pr2-red-xcode-20260501-r2.log`
- Expected final red: source guard failed because
  `EpistemosTests/Benchmarks/BenchmarkFixtureBaselines.swift` did not exist.

Green evidence:

- `/tmp/epistemos-r15-real-fixture-pr2-green-xcode-20260501-r2.log`
- `/tmp/epistemos-r15-real-fixture-pr2-green-xcode-20260501-r3.log`
- Result: `5` focused tests across `BenchmarkFixtureBaselineTests` and
  `BenchmarkHarnessSourceGuardTests` passed.
- Xcode reported `** TEST SUCCEEDED **`; inherited SwiftLint package-plugin
  noise for `CodeEditSourceEditor` and `CodeEditTextView` still appeared after
  the success marker.

Guardrails:

- `git diff --check -- EpistemosTests/Benchmarks/BenchmarkFixtureBaselines.swift EpistemosTests/BenchmarkHarnessSourceGuardTests.swift benchmarks/results docs/fusion`
  passed.
- `rg -n "Task\\.sleep|placeholder|Manual benchmark" EpistemosTests/Benchmarks/BenchmarkFixtureBaselines.swift`
  returned no matches.
- `rg -n "[ \\t]+$" EpistemosTests/Benchmarks/BenchmarkFixtureBaselines.swift EpistemosTests/BenchmarkHarnessSourceGuardTests.swift benchmarks/results docs/fusion/deliberation/r15_real_fixture_baselines_pr2_deliberation_2026_05_01.md`
  returned no matches.
- Protected-path scan still reports inherited dirty `graph-engine/**` and
  `epistemos-shadow/**` files from the broader branch; PR2 did not edit those
  surfaces.

Not closed by this slice:

- MLX thermal fixture baselines.
- sqlite-vec 100k KNN fixture baselines.
- Full graph FFI fixture baselines.
- Editor shell fixture baselines.
- UniFFI callback throughput fixture baselines.
- Any production graph-engine, renderer, editor, model, retrieval, generated
  binding, project, entitlement, branch, stage, stash, or commit work.
