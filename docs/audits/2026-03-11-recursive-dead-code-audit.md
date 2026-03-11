# 2026-03-11 Recursive Dead Code Audit

## Scope

- Baseline checkpoint commit: `a6c11b28347815469f9645248e07ec59f9dbaf4e`
- Audit target: dead code, unused compiler noise, and low-risk internal cleanup
- Primary area touched: `/Users/jojo/Epistemos/graph-engine/src`

## What Changed

This pass focused on compiler-verified dead code and unused warning cleanup, not behavior changes.

- Ran `cargo fix --tests --allow-dirty` in `graph-engine` to remove machine-applicable unused imports, locals, and mutability noise.
- Manually removed remaining dead items in engine/runtime code:
  - unused renderer constants and helper payload
  - unused engine helper method
  - unused fluid constant
  - unused `SpatialGrid` field
  - final leftover unused test locals

## Quantified Improvements

### Compiler Warning Reduction

- `cargo test` warning lines: `463 -> 0` (`-463`, `100%` reduction)
- `cargo test` unused-variable warning lines: `444 -> 0`
- `cargo test` dead-code / never-read warning lines: `8 -> 0`
- `xcodebuild build` total warning lines: `19 -> 3` (`-16`, `84.2%` reduction)
- `xcodebuild build` code warning lines only: `16 -> 0` (`100%` reduction)

Remaining `xcodebuild` warnings are not code warnings:

1. destination selection warning from the generic `platform=macOS` CLI target
2. legacy headermap project warning
3. Rust build-phase output-path warning

### Diff Size vs Checkpoint

- Files changed: `14`
- Insertions: `453`
- Deletions: `526`
- Net line reduction: `-73`

### Verification Stability

Three uninterrupted verification passes completed without code changes between passes:

1. `cargo test` -> pass, `0` warnings
2. `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build` -> pass, `3` non-code warnings
3. Repeated twice more with the same results

Pass timings were captured, but they were cache-sensitive and not stable enough to use as honest performance claims. This audit improves code hygiene and build noise materially; it does not prove a runtime speedup.

## Files With Meaningful Cleanup

- `/Users/jojo/Epistemos/graph-engine/src/comprehensive_spatial_tests.rs`
- `/Users/jojo/Epistemos/graph-engine/src/renderer.rs`
- `/Users/jojo/Epistemos/graph-engine/src/engine.rs`
- `/Users/jojo/Epistemos/graph-engine/src/simulation.rs`
- `/Users/jojo/Epistemos/graph-engine/src/ecs/spatial_grid.rs`
- `/Users/jojo/Epistemos/graph-engine/src/graph_tests.rs`
- `/Users/jojo/Epistemos/graph-engine/src/theme_ecs_tests.rs`

## What I Deliberately Did Not Claim

- No runtime FPS improvement claim
- No app-launch speedup claim
- No interaction-latency claim

Those would require Instruments or targeted benchmarks, not compiler-warning cleanup alone.
