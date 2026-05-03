# R15 True Rust Callback Loop PR10 Deliberation

Slice: `r15-true-rust-callback-loop-pr10`
Tier: All, benchmark/test-only
Workcard: Card 3 - R15 Benchmark Harness Foundation
Status: approved-for-red-team, not yet approved-for-code

## Intent

Close the R15 open callback-loop evidence gap with a real Rust-to-Swift callback-loop benchmark. PR5 currently measures generated callback handle lowering/lifting from Swift and explicitly does not claim a Rust loop. PR10 should add a narrow Rust UniFFI export that loops inside Rust and calls the existing `AgentEventDelegate.on_text_delta` callback, then record a deterministic JSON baseline through the existing benchmark recorder.

## Allowed Files

- `agent_core/src/bridge.rs` for one benchmark-only UniFFI export and one small return record.
- `EpistemosTests/Benchmarks/UniFFICallbackThroughputTests.swift`
- `EpistemosTests/Benchmarks/R15BenchmarkEvidenceLedgerTests.swift`
- `EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`
- `benchmarks/results/2026-05-02t00-00-00-000z-r15-true-rust-callback-loop-baseline-true_rust_callback_loop.json`
- Round 43 docs under `docs/fusion/**`

## Forbidden Files

- `graph-engine/src/renderer.rs`
- Graph physics internals
- `Epistemos/Views/Graph/MetalGraphView.swift`
- Production MLX inference behavior
- Production provider/session routing behavior
- Hand-edited generated Swift bindings unless the build system cannot regenerate them and the red-team approves the generated-transport scope.

## Implementation Plan

1. Red test: extend `UniFFICallbackThroughputTests` with a `TrueRustCallbackLoopBaselineRunner` that calls a not-yet-existing `runR15TrueRustCallbackLoopBenchmark(...)` export and asserts `rust_loop_status == true_rust_to_swift_loop`.
2. Rust export: add `R15TrueRustCallbackLoopBenchmarkFFI` and `run_r15_true_rust_callback_loop_benchmark(...)` in `agent_core/src/bridge.rs`. The function must be benchmark-only, panic-guarded, and must not mutate session/provider/runtime state.
3. Green test: record `true_rust_callback_loop` JSON using `BenchmarkRunRecorder` with finite samples, expected callback count, emitted byte count, and checksum.
4. Ledger: move the true Rust callback-loop filename from forbidden-open to closed-baseline expectations only after the JSON report exists.
5. Guards: prove generated-handle PR5 remains honest, PR10 carries distinct metadata, and protected graph/renderer paths were not touched.

## Acceptance

- Focused Swift benchmark/source-guard/evidence-ledger tests pass.
- The JSON result exists and decodes.
- PR5 metadata still says `not_true_rust_to_swift_loop`.
- PR10 metadata says `true_rust_to_swift_loop`.
- No production graph renderer, MLX runtime, provider, or UI path changes.
- Any existing dirty hunks in `agent_core/src/bridge.rs` remain unstaged unless they are separately committed by their owner.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §8`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §22`
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:917`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:247`

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 3 - R15 Benchmark Harness Foundation
- Deviation: This gate reopens the "generated transport" callback-loop item named as later work while still keeping production generated artifacts hand-edit forbidden. The normal build phase may regenerate bindings; source control should stage only intentional source/test/docs/result changes.

## Failure-proof guardrails (post-merge)

- grep: `rg -n "run_r15_true_rust_callback_loop_benchmark|true_rust_callback_loop|true_rust_to_swift_loop" agent_core/src/bridge.rs EpistemosTests/Benchmarks EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`
- log: `TEST SUCCEEDED`
- test: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/UniFFICallbackThroughputTests -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests -only-testing:EpistemosTests/R15BenchmarkEvidenceLedgerTests test`

## Fleet evidence packet

- `docs/fusion/fleet/r15-true-rust-callback-loop-pr10/aggregator.md`
- `docs/fusion/fleet/r15-true-rust-callback-loop-pr10/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Closes the open non-manual R15 callback-loop measurement gap before optimization work.
