# Benchmark Harness And Graph-Engine Quarantine Deliberation

Date: 2026-04-30
Queue item: 8
Classification: Both, benchmark infrastructure only
Decision: Audit and run the existing benchmark/test baseline. Do not edit graph-engine implementation or protected graph render paths.

## Repo Evidence

- `docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` marks current `graph-engine/` dirty diff as high risk and says graph-engine implementation remains blocked.
- `graph-engine/benches/graph_ffi_baselines.rs` already exists and benchmarks graph data loading, search, simulation tick, and markdown parsing.
- `EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift` already exists as a disabled-by-default `os_signpost` benchmark suite for graph FFI surfaces.
- `docs/architecture/BENCHMARK_BASELINES.csv` already exists with Rust baseline numbers and Swift rows that require manual/Instruments runs.
- Current dirty graph scope includes `graph-engine/src/renderer.rs`, physics/motion/force files, and graph UI files; these are not approved for modification in this slice.

## Donor Evidence

- Inspiring-Heisenberg contains the same benchmark scaffold family:
  - `.claude/worktrees/inspiring-heisenberg-ea9dc3/graph-engine/benches/graph_ffi_baselines.rs`
  - `.claude/worktrees/inspiring-heisenberg-ea9dc3/EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift`
  - `.claude/worktrees/inspiring-heisenberg-ea9dc3/docs/architecture/BENCHMARK_BASELINES.csv`
- Diff against main shows only small drift in call spelling and benchmark signpost label interpolation. No raw donor merge is needed.
- Inspiring-Heisenberg also contains `graph-engine/src/bolt_bridge.rs` and `graph-engine-bridge/graph_engine_bolt.h`; those are explicitly out of scope for this slice.

## Research And Plan Evidence

- `docs/architecture/PLAN_V2.md` sections 22.2, 22.5, and 22.6 require before/after benchmarks and parity tests before any hot-path FFI migration.
- `docs/architecture/PLAN_V2.md` section 26.2 describes the benchmark harness as the first authorized step and forbids changing FFI signatures, Rust logic, or UI behavior.
- `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md` classifies graph data loading, queries, search, markdown parsing, and SDF labels as the first measurement targets.
- `docs/plan/03_EXECUTION_MAP.md` still labels broad BoltFFI claims as unverified and mandates independent measurement before integration.

## Alternatives Considered

- Raw-merge donor BoltFFI prototype: rejected because the branch is dirty, graph internals are protected, and no parity delta has been approved.
- Add new benchmark harness files: rejected for now because the main worktree already has the expected Rust and Swift benchmark scaffolds.
- Update production graph-engine code before benchmark: rejected by the queue stop trigger.
- Run only existing baseline checks and document results: accepted.

## Files Likely Touched

- `docs/fusion/deliberation/benchmark_harness_graph_engine_quarantine_deliberation_2026_04_30.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Protected And Forbidden Files

- Do not edit `graph-engine/src/renderer.rs`.
- Do not edit physics, force, simulation, or motion internals.
- Do not edit `Epistemos/Views/Graph/MetalGraphView.swift`.
- Do not edit `Epistemos/Views/Graph/HologramController.swift`.
- Do not edit generated `.rlib`, DerivedData, `.xcresult`, or build outputs.
- Do not enable the production BoltFFI switch.

## Tests And Logs

Planned commands:

```bash
cargo test --manifest-path graph-engine/Cargo.toml
cargo bench --manifest-path graph-engine/Cargo.toml --bench graph_ffi_baselines -- --sample-size 10 --measurement-time 1
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/GraphFFIBenchmarkTests test
```

The Swift benchmark suite is disabled by design, so the xcodebuild command should compile/discover the suite but skip execution unless the suite design has changed.

## Manual Verification

- Graph runtime under a realistic vault remains deferred by user request.
- Instruments/os_signpost capture remains deferred until manual verification is approved.

## Rollback

- Revert this deliberation doc and the fusion floor-log append.
- No source rollback should be needed because this slice does not edit production graph or benchmark code.

## Stop Triggers

- Any attempt to fix graph-engine dirty implementation files before benchmark/parity proof.
- Any attempt to enable BoltFFI in production.
- Benchmark harness fails to compile.
- Existing graph benchmark baseline is missing or cannot be run.
- Protected graph render files show new diffs from this slice.

## Gate Decision

Approved for benchmark/test execution and documentation only. Not approved for graph-engine implementation, production BoltFFI adoption, or protected graph render edits.
