# R15 Editor Shell Fixture Baseline PR3 Deliberation - 2026-05-01

Approved action: **test-only editor shell fixture baseline writer**.

This follows R15 PR1/PR2. PR1 added `BenchmarkRunRecorder`; PR2 added real
fixture baselines for Swift graph payload construction, markdown parser FFI,
and code-token parser FFI. PR3 adds a focused editor-shell baseline that
measures raw AppKit/TextKit editor substrate work without touching the
production note editor bridge.

## Scope

Allowed write set:

- `EpistemosTests/Benchmarks/EditorShellFixtureBaselineTests.swift`
- `EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`
- `benchmarks/results/**`
- `docs/fusion/deliberation/r15_editor_shell_fixture_baseline_pr3_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_056_2026_05_01.md`

Forbidden write set:

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`
- `Epistemos/Views/Graph/**`
- `graph-engine/**`
- `epistemos-shadow/**`
- production editor, graph, FFI, model, retrieval, runtime, generated binding,
  project, entitlement, stash, branch, or destructive git changes

## Implementation Contract

- Keep this benchmark test-only and deterministic.
- Use `BenchmarkRunRecorder` and the existing JSON schema.
- Measure real AppKit/TextKit work: shell mount/layout, batch insert, and
  viewport attribute application.
- Do not import or instantiate production `ProseEditor*` or `ProseTextView2`
  types in the new benchmark.
- Do not use sleeps, static fake samples, manual Instruments dependency, random
  fixture data, or broad production instrumentation.
- Do not claim full editor-performance readiness. This is a substrate baseline,
  not a user-perceived latency guarantee.

## Red First

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test
```

Expected red:

- `BenchmarkHarnessSourceGuardTests` fails because
  `EpistemosTests/Benchmarks/EditorShellFixtureBaselineTests.swift` does not
  exist yet.

## Green

```bash
EPISTEMOS_BENCHMARK_RESULTS_DIR=/Users/jojo/Downloads/Epistemos/benchmarks/results xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EditorShellFixtureBaselineTests -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test
```

Expected green:

- Editor shell fixture tests write finite decodable JSON reports.
- Source guard proves the runner exists, uses real AppKit/TextKit symbols, and
  has no sleep/fake-sample marker.
- Existing PR1/PR2 benchmark source guards remain green.

## Guardrails

```bash
git diff --check -- EpistemosTests/Benchmarks/EditorShellFixtureBaselineTests.swift EpistemosTests/BenchmarkHarnessSourceGuardTests.swift benchmarks/results docs/fusion/deliberation/r15_editor_shell_fixture_baseline_pr3_deliberation_2026_05_01.md docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_056_2026_05_01.md
rg -n "Task\\.sleep|placeholder|Manual benchmark|ProseEditor|ProseTextView2|graph-engine|epistemos-shadow" EpistemosTests/Benchmarks/EditorShellFixtureBaselineTests.swift
git diff --name-only -- Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseEditorView.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph graph-engine epistemos-shadow
```

## Kimi Advisory

Kimi CLI read-only advisory:

- `/tmp/epistemos-r15-editor-shell-kimi-advisory-20260501.log`

Verdict:

- Good next slice when scoped to raw editor substrate work.
- Do not treat it as full production editor fidelity.
- Keep each metric single-variable, deterministic, JSON-recorder backed, and
  free of production editor/graph/Rust dependencies.

## Acceptance

- Wired: `EditorShellFixtureBaselineRunner` writes JSON through
  `BenchmarkRunRecorder`.
- Reachable: focused Swift Testing suite runs from `xcodebuild test` without
  project-file edits.
- Visible: `benchmarks/results/` contains editor-shell JSON baseline reports.
- Safe: no protected production editor, graph, Rust, generated, project, or
  entitlement paths are modified.

## Closeout

Gate status: **passed and closed**.

Implemented:

- Added `EditorShellFixtureBaselineRunner`, a test-only AppKit/TextKit fixture
  baseline writer.
- Measured three real local editor-shell surfaces:
  `editor_shell_mount_layout_1800_lines`,
  `editor_shell_batch_insert_96_lines`, and
  `editor_shell_viewport_attribute_220_lines`.
- Extended `BenchmarkHarnessSourceGuardTests` so the editor-shell runner must
  stay real AppKit/TextKit work and cannot regress to sleep/fake samples.

Generated baseline reports:

- `benchmarks/results/2026-05-01t00-00-00-000z-r15-editor-shell-baselines-editor_shell_mount_layout_1800_lines.json`
- `benchmarks/results/2026-05-01t00-00-00-000z-r15-editor-shell-baselines-editor_shell_batch_insert_96_lines.json`
- `benchmarks/results/2026-05-01t00-00-00-000z-r15-editor-shell-baselines-editor_shell_viewport_attribute_220_lines.json`

Red evidence:

- `/tmp/epistemos-r15-editor-shell-pr3-red-xcode-20260501.log`
- Expected failure: source guard failed because
  `EditorShellFixtureBaselineTests.swift` did not exist yet.

Green evidence:

- `/tmp/epistemos-r15-editor-shell-pr3-green-xcode-20260501-r2.log`
- Result: `6` tests across `BenchmarkHarnessSourceGuardTests` and
  `EditorShellFixtureBaselineTests` passed.
- Xcode reported `** TEST SUCCEEDED **`; inherited SwiftLint package-plugin
  noise for `CodeEditSourceEditor` and `CodeEditTextView` still appeared after
  the success marker.

Guardrails:

- `/tmp/epistemos-r15-editor-shell-pr3-diff-check-20260501-r2.log` passed.
- `/tmp/epistemos-r15-editor-shell-pr3-source-scan-20260501-r2.log` passed
  with no matches for sleeps, fake marker text, production `ProseEditor`,
  `ProseTextView2`, graph-engine, or shadow backend imports.

Not closed by this slice:

- MLX thermal fixture baselines.
- sqlite-vec 100k KNN fixture baselines.
- Full graph FFI fixture baselines.
- UniFFI callback throughput fixture baselines.
- Full production editor latency or manual runtime readiness claims.
