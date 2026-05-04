# Graph Physics Performance Plan

> **Index status**: SUPERSEDED-HISTORICAL — Older plan tree predecessor of `docs/plan/`; superseded by MASTER_FUSION.md + V1_5_IMPLEMENTATION_TRACKER.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



## Goal
Keep the graph fluid at 1k+ nodes without destabilizing the current Rust + Metal stack.

This is a rewrite of the older optimization doc. The old version mixed already-finished
work with speculative work. This one only tracks the remaining high-value performance
tasks still worth doing.

## What Is Already Done

- Barnes-Hut theta tuning landed: `THETA = 0.8` in `graph-engine/src/quadtree.rs`
- Background graph loading landed via `BackgroundGraphActor`
- Swift FFI wrapper landed via `Epistemos/Graph/GraphEngine.swift`
- Highlight updates are already cheap: Rust rebuilds N-byte highlight flags instead of
  re-uploading full graph geometry
- Viewport-scoped physics already exists in `graph-engine/src/engine.rs` and
  `graph-engine/src/simulation.rs`
- Incremental node/edge additions already exist in `MetalGraphView` for some graph edits
- SIMD velocity integration already exists in `graph-engine/src/simulation.rs`

## Current Bottlenecks

### 1. Full Structural Recommit Is Still Expensive

The slow path is still alive:

- `MetalGraphView.commitGraphData()` clears the Rust engine
- Swift re-adds every node and edge
- Rust rebuilds simulation state, search index, spatial grid, and render buffers

This is still correct, but it is too expensive for structural changes that could be
expressed as diffs.

### 2. Renderer Buffer Rebuilds Still Scale With Visible Graph Size

Rust is already better than before, but classic-mode buffer rebuilds are still a real
cost during:

- graph recommit
- large camera moves
- viewport changes
- cluster proxy recalculation

### 3. Physics Scope Still Does More Work Than Necessary

Viewport-scoped physics exists, but there is still cleanup work left:

- reduce temporary scratch churn in active-mask building
- tighten the visible + neighbor activation rules
- avoid doing expensive work when the graph is effectively idle

### 4. There Is No Tight Benchmark Loop

The repo has lots of tests, but there is still no single small benchmark workflow that
answers:

- commit time at 1k / 5k / 10k nodes
- steady-state frame cost
- physics-thread cost
- pan/zoom cost

Without that, performance work is too guess-driven.

## Non-Goals

Do not spend time here on:

- GPU compute physics
- renderer redesign
- theme work
- query / BTK performance
- visual polish that does not move frame time

## Phase 1: Add a Small Benchmark Baseline

**Goal:** Make performance measurable before changing behavior.

### Work

- Add a tiny benchmark matrix for:
  - graph commit time
  - one second of steady-state simulation
  - pan/zoom refresh cost
  - search highlight cost
- Standardize three graph sizes: 1k, 5k, 10k nodes
- Record the numbers in this file after each phase

### Files

- `graph-engine/src/bench_tests.rs`
- optionally `EpistemosTests/GraphPerformanceTests.swift` if Swift-side commit costs need coverage

### Done When

- One command gives comparable before/after numbers
- We can tell whether a change helped commit, render, or physics separately

### Phase 1 Baseline (2026-03-12)

Command:

```bash
cargo test benchmark_graph_phase1_matrix --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml -- --nocapture
```

Current debug-test baseline from the new headless matrix in `graph-engine/src/bench_tests.rs`:

| Nodes | Commit Core Total | 1s Steady-State Sim | Viewport Refresh | Search Highlight | Notes |
|---|---:|---:|---:|---:|---|
| 1k | 755,622 us | 141,615 us | 28,867 us | 12,728 us | 60 physics ticks |
| 5k | 5,109,054 us | 327,189 us | 57,637 us | 64,146 us | 30 physics ticks, warm-start still active |
| 10k | 163,942 us | 1 us | 73,169 us | 130,363 us | crosses `Simulation` static-layout threshold (`> 9000`), so steady-state physics is effectively disabled by design |

Interpretation:
- `commit core` is headless commit work: simulation load/warm-start, cluster assignment, world rebuild, and search-index build.
- `viewport refresh` is 120 pan/zoom cull steps using the same spatial-grid + bounds intersection path the renderer uses before GPU upload.
- `search highlight` is 80 passes of the current linear label-scan highlight path.
- These numbers are for relative before/after comparison in `cargo test`, not release-build FPS claims.

### Safe Optimization Applied (2026-03-12)

Implemented:
- bounded `Simulation::warm_start()` for large graphs with an explicit iteration + time budget
- regression guard in `graph-engine/src/simulation.rs` so mid-size graphs stay capped

Measured after the warm-start cap:

| Nodes | Commit Core Before | Commit Core After | Delta |
|---|---:|---:|---:|
| 1k | 755,622 us | 44,087 us | -94.2% |
| 5k | 5,109,054 us | 132,704 us | -97.4% |
| 10k | 163,942 us | 159,083 us | -3.0% |

Notes:
- This directly confirms the previous hotspot: mid-size full recommits were spending most of their time inside simulation warm-start.
- `10k` remains mostly unchanged because it was already crossing the static-layout threshold and bypassing active physics.
- Follow-up cost centers are now clearer: search highlight still scales linearly, and viewport refresh is now easier to isolate without warm-start dominating the graph.

### Safe Optimization Applied (2026-03-12, cull + highlight path)

Implemented:
- fast dense-entity lookup in `graph-engine/src/ecs/mod.rs` so renderer culling does not pay a hash lookup for the common `entity == index` graph world
- direct node-ID highlight collection in `graph-engine/src/search.rs` and `graph-engine/src/engine.rs`, which removes UUID-to-ID hash lookups from search highlight
- shorter `Simulation` lock scope in `Engine::sync_all_positions()` so spatial-grid rebuild work no longer holds the simulation mutex

Measured against the immediately previous headless matrix:

| Nodes | Viewport Refresh Before | Viewport Refresh After | Delta | Search Highlight Before | Search Highlight After | Delta |
|---|---:|---:|---:|---:|---:|---:|
| 1k | 27,942 us | 22,108 us | -20.9% | 9,088 us | 8,664 us | -4.7% |
| 5k | 55,152 us | 36,691 us | -33.5% | 45,062 us | 43,945 us | -2.5% |
| 10k | 71,672 us | 45,291 us | -36.8% | 93,158 us | 88,720 us | -4.8% |

Notes:
- The culling win is the larger result here because viewport refresh was paying repeated `entity -> index` hash lookups on every visible candidate.
- The search-highlight win is smaller because the expensive part is still the linear contains scan; this pass only removed the extra UUID mapping and per-query allocation churn.
- The shorter simulation lock scope is a smoothness fix more than a benchmark headline. It reduces render-thread contention against the physics thread during active motion.

### Safe Optimization Applied (2026-03-12, search-index build path)

Implemented:
- removed the `label -> Vec<entry index>` reverse map from `graph-engine/src/search.rs`
- replaced it with sorted entry-index bookkeeping so FST duplicate-label expansion still works without building a second large hash structure during commit
- preserved duplicate-label exact and typo behavior with focused regression tests

Measured against the immediately previous headless matrix:

| Nodes | Search Index Build Before | Search Index Build After | Delta | Commit Core Total Before | Commit Core Total After | Delta |
|---|---:|---:|---:|---:|---:|---:|
| 1k | 11,826 us | 11,835 us | +0.1% | 44,326 us | 46,070 us | +3.9% |
| 5k | 55,322 us | 52,801 us | -4.6% | 130,275 us | 127,728 us | -2.0% |
| 10k | 117,946 us | 107,405 us | -8.9% | 162,157 us | 151,454 us | -6.6% |

Notes:
- The improvement is real at the sizes that matter, but smaller than the viewport/culling win because FST construction still dominates the high end.
- `1k` is within debug-benchmark noise, so I do not treat that row as a meaningful regression signal by itself.
- This was still worth landing because it removes duplicate build-time bookkeeping and keeps the same search semantics for duplicate labels.

## Phase 2: Kill More Full Recommits

**Goal:** Reserve full `clear -> add all -> commit` for true rebuilds only.

### Work

- Add missing incremental FFI for structural updates that still force recommit:
  - remove node
  - remove edge
  - update node visibility / metadata if needed
- Move Swift call sites away from `requestRecommit()` when the graph topology change is local
- Keep full recommit only for bulk rebuild or graph-schema refresh

### Primary Targets

- `Epistemos/Graph/GraphState.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `graph-engine/src/lib.rs`
- `graph-engine/src/engine.rs`

### Done When

- Single-node and single-edge edits do not clear and rebuild the whole engine
- Manual graph edits stay visually immediate on large graphs

## Phase 3: Tighten Renderer Rebuild Discipline

**Goal:** Rebuild less geometry on pan/zoom and on low-signal visual changes.

### Work

- Audit every path that marks camera or viewport rebuild dirty
- Keep highlight, filter, and camera updates on the lightweight path whenever possible
- Reuse scratch buffers aggressively in classic buffer rebuilds
- Verify cluster-proxy mode does not re-do unnecessary work during small camera changes

### Primary Targets

- `graph-engine/src/engine.rs`
- `graph-engine/src/renderer.rs`

### Done When

- Pan/zoom frame cost is stable at 5k visible nodes
- Small visual state changes do not behave like mini-recommits

## Phase 4: Tighten Physics Scope and Idle Behavior

**Goal:** Spend less CPU when the user is zoomed in, panning slowly, or not interacting.

### Work

- Remove avoidable temporary allocations in viewport activity calculation
- Reuse active-mask scratch instead of cloning where possible
- Add a stricter idle path when alpha is low and camera is still
- Verify off-screen work stays bounded during deep zoom

### Primary Targets

- `graph-engine/src/simulation.rs`
- `graph-engine/src/engine.rs`

### Done When

- Physics-thread CPU drops in zoomed-in workflows
- No visible wake/sleep artifacts at viewport boundaries

## Phase 5: Diff-Sync the Swift Graph Load Path

**Goal:** Stop treating every structural refresh like a cold start.

### Work

- Compare current `GraphStore` records to last-committed engine state
- Send only adds/removes/updates when reloading after a structural refresh
- Keep full load only for first open and hard reset

### Primary Targets

- `Epistemos/Graph/GraphState.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Graph/GraphEngine.swift`

### Done When

- Refreshing the graph after ordinary vault changes no longer feels like a cold boot

## Verification Loop

Run after each phase:

```bash
cd /Users/jojo/Epistemos/graph-engine && cargo test
cd /Users/jojo/Epistemos/graph-engine && cargo build --release
cp /Users/jojo/Epistemos/graph-engine/target/release/libgraph_engine.a /Users/jojo/Epistemos/build-rust/
xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
```

Manual checks:

- open a dense graph
- pan aggressively
- zoom deep into a cluster
- toggle highlight/search/filter states
- add and remove a few manual nodes/edges

## Priority Order

1. Benchmark baseline
2. Full recommit reduction
3. Renderer rebuild discipline
4. Physics scope cleanup
5. Diff-sync reload path

Anything beyond that is lower value than BTK/query work and the agent system backlog.
