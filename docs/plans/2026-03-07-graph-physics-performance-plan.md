# Graph Physics Performance Plan

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
