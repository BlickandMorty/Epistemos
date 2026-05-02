# R15 Benchmark Evidence Ledger - PR9 Deliberation

Date: 2026-05-02
Branch: feature/landing-liquid-wave
Scope: R15 benchmark harness only

## Gate

Add a test-only evidence ledger that names the R15 benchmark artifacts that are
actually closed and keeps still-open live benchmark claims impossible to list as
closed by accident.

## Approved

- `EpistemosTests/Benchmarks/R15BenchmarkEvidenceLedgerTests.swift`
- This deliberation record
- R15 current-state/workcard docs

## Explicitly Not Approved

- Production benchmark runner changes
- `BenchmarkRunRecorder` schema changes
- `benchmarks/results/*.json` edits
- Graph renderer, graph physics, or production FFI edits
- Live MLX tok/s, renderer FPS, or true Rust callback-loop claims
- Generated bindings/libraries
- Xcode project or entitlement changes

## Evidence

Red:
The first focused test run failed because `R15BenchmarkEvidenceLedger` did not
exist yet. That established the expected compile-time red path before the guard
was implemented.

Green:
`/tmp/epistemos-r15-evidence-ledger-pr9-green-20260502.log`

Focused command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/R15BenchmarkEvidenceLedgerTests test
```

Result: `TEST SUCCEEDED`; 2 Swift Testing tests passed in the focused suite.
The known SwiftLint package-plugin build-command lines appeared after the test
success marker, matching earlier R15 focused runs.

Standalone artifact probe:
`/tmp/epistemos-r15-evidence-ledger-pr9-artifact-probe-20260502.log`

The standalone probe decodes the ten committed JSON reports under
`benchmarks/results/` and verifies the three open artifact filenames are absent.
The Xcode-hosted test deliberately does not enumerate the repo results
directory, because direct app-hosted filesystem enumeration hung during audit
runs. The hosted test keeps the contract explicit; the standalone probe checks
the physical artifacts.

## Closed Ledger

Closed artifacts:

- `2026-05-01t00-00-00-000z-r15-fixture-baselines-graph_payload_construction_750_nodes.json`
- `2026-05-01t00-00-00-000z-r15-fixture-baselines-markdown_parser_160_sections.json`
- `2026-05-01t00-00-00-000z-r15-fixture-baselines-code_token_parser_1200_lines.json`
- `2026-05-01t00-00-00-000z-r15-editor-shell-baselines-editor_shell_mount_layout_1800_lines.json`
- `2026-05-01t00-00-00-000z-r15-editor-shell-baselines-editor_shell_viewport_attribute_220_lines.json`
- `2026-05-01t00-00-00-000z-r15-editor-shell-baselines-editor_shell_batch_insert_96_lines.json`
- `2026-05-01t00-00-00-000z-r15-sqlite-vec-knn-sqlite_vec_knn_100k_32d.json`
- `2026-05-02t00-00-00-000z-r15-uniffi-callback-baseline-uniffi_callback_handle_roundtrip_10000.json`
- `2026-05-02t00-00-00-000z-r15-mlx-thermal-policy-baseline-mlx_thermal_policy_snapshot_1000.json`
- `2026-05-02t00-00-00-000z-r15-graph-ffi-bridge-baseline-graph_ffi_bridge_fixture_250.json`

Explicitly still open:

- `2026-05-02t00-00-00-000z-r15-mlx-live-token-throughput-baseline-mlx_live_token_throughput_deepseek7b_32.json`
- `2026-05-02t00-00-00-000z-r15-renderer-fps-baseline-renderer_fps_thermal_soak.json`
- `2026-05-02t00-00-00-000z-r15-true-rust-callback-loop-baseline-true_rust_callback_loop.json`

## Runtime Claim

This gate closes only the evidence-ledger guard. It does not add a benchmark,
retire any open R15 surface, or assert a runtime performance result. Future
optimization cards must cite a real closed artifact plus its metadata before
they claim a baseline.

## Follow-Up

Run PR8 under sufficient-memory conditions to write a finite live MLX tok/s JSON
artifact, add a real renderer FPS/thermal-soak gate, and add the true
Rust-to-Swift callback-loop export baseline when that export exists.
