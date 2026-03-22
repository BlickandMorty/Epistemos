# Before / After Benchmarks

## Scope

This file separates:

1. measured benchmark results from this audit pass
2. deterministic latency-budget reductions from code-path changes
3. still-unmeasured areas that need app-level profiling

It does not claim app-wide wins where the repo does not yet have a runnable benchmark.

## Measured Rust / Bridge Results

### 1. Knowledge-Core Summary Accessor

Command:
- `cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml benchmark_knowledge_core_payload_summary_accessor -- --ignored --nocapture`

Result:
- before: `22969 ns/decode`
- after: `3800 ns/decode`
- speedup: `6.04x`

Meaning:
- the staged summary accessor is materially better than scalar field-by-field decoding
- this is a staged bridge win, not yet a production UI win

### 2. Knowledge-Core Batched Row Accessor

Command:
- `cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml benchmark_knowledge_core_payload_rows_batch_accessor -- --ignored --nocapture`

Result:
- before: `16973 ns/payload`
- after: `5335 ns/payload`
- speedup: `3.18x`

Meaning:
- batching row access beats per-row accessor churn
- this validates the “batch before shared-memory expansion” rule

### 3. Knowledge-Core Incremental Outline Refresh

Command:
- `cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml benchmark_knowledge_core_incremental_outline_refresh -- --ignored --nocapture`

Result:
- incremental: `88008 ns/tx`
- full rerun: `14740287 ns/tx`
- speedup: `167.49x`

Meaning:
- dependency-aware staged watcher refresh is real
- this is one of the strongest proofs that incremental invalidation matters more than transport cleverness

### 4. BTK Property Subscription Incremental Refresh

Command:
- `cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml benchmark_property_subscription_incremental_refresh -- --ignored --nocapture`

Result:
- incremental: `15662401 ns/tx`
- full rerun: `19416815 ns/tx`
- speedup: `1.24x`

Meaning:
- the live BTK property watcher improves, but only modestly
- there is still too much surrounding materialization / broad invalidation overhead

### 5. Knowledge-Core Parser Throughput

Command:
- `cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml benchmark_knowledge_core_parser_markdown_large_document -- --ignored --nocapture`

Result:
- `58476982 ns/parse`
- `1.33 MB/s`

Meaning:
- the staged parser is not yet performance-competitive enough to justify a broader migration
- parser architecture needs more work before it can be sold as a hot-path win

## Measured Build / Verification Results

### App Build

Command:
- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`

Result:
- `BUILD SUCCEEDED`

### Targeted Query Test Invocation

Command:
- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/QueryRuntimeTests CODE_SIGNING_ALLOWED=NO`

Result:
- build failed before running the target test because unrelated `EpistemosTests` files still do not compile under Swift 6

Primary blockers:
- `ConcurrencyEdgeCaseTests.swift`
- `ConcurrencyStressTests.swift`
- stale `PipelineState` API assumptions in unrelated tests

Meaning:
- the new query invalidation test is present, but the repo still lacks a green targeted Swift test run because the test bundle compiles as a whole

## Deterministic Live-Path Latency Budget Reduction

### Reactive Query Invalidation Floor

Before:
- `GraphStore.notifyChange()` delayed notifications by `50ms`
- `ReactiveQuery` added another `100ms`
- effective scheduled floor: about `150ms` before a re-run could even happen

After:
- `GraphStore.notifyChange()` posts immediately
- `ReactiveQuery` now owns the only debounce at `35ms`
- effective scheduled floor: about `35ms`

Budget reduction:
- from `150ms` to `35ms`
- reduction: about `76.7%`

Why this counts:
- this is not a synthetic estimate; it is a direct consequence of the live code path
- it is still separate from a full app-level benchmark because the Swift test target is not green

## Live Body-Hydration Reductions

These are code-path reductions, not yet timed benchmarks.

### Daily Brief Prompt Builder

Files:
- `Epistemos/State/DailyBriefState.swift`

Before:
- each retained note could call `loadBody()` twice:
  - once during the non-empty filter
  - once again for the snippet

After:
- each retained note body is loaded once via `loadBody(mapped: true)`
- snippet extraction uses the already-loaded body

Meaning:
- fewer disk/String reads in a visible context-building path
- still needs app-level timing to quantify the user-visible gain

### Backlinks Scan

Files:
- `Epistemos/Views/Notes/NoteBacklinksPanel.swift`

Before:
- scanned all note bodies with plain `loadBody()`

After:
- scans with `loadBody(mapped: true)`

Meaning:
- lower-cost bulk reads for a whole-vault scan path
- still unmeasured at the UI level

## Still Unmeasured

These remain missing and should not be claimed as wins yet:

1. startup/open latency
2. note open latency
3. graph interaction latency
4. Swift-side BTK payload apply cost
5. search latency under large-vault load
6. sync merge latency
7. memory footprint before/after the live query invalidation fix
8. allocation churn in note-context and query UI paths
