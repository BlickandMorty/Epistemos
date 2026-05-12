---
state: canonical
created_on: 2026-05-11
updated_on: 2026-05-11 (refinements from final research synthesis)
scope: Epistemos graph engine upgrade — synthesis of 7 deep-research drops + verified code state
verdict: CONVERGED; ready for execution
supersedes: prior graph-engine planning docs
---

# Canonical Graph Engine Plan — Epistemos on M2 Pro 16GB

## Status

This document is the **canonical plan** for upgrading the Epistemos graph engine. It is the converged synthesis of seven independent deep-research drops (April–May 2026), reconciled against the actual codebase (verified at `Epistemos/Views/Graph/MetalGraphView.swift`, `graph-engine/src/*`, `agent_core/src/oplog.rs`). All major architectural decisions are locked. Further research will produce refinements, not pivots.

Where this document and earlier graph plans differ, this document wins.

## Executive summary

Build a **Rust-orchestrated, Metal-resident force layout** in three phases. Rust owns topology, reveal order, clustering metadata, and the control plane. Metal owns positions, velocities, forces, and the per-frame physics loop. Swift orchestrates command buffers and the camera. Buffers are **Metal-allocated `.storageModeShared`**; Rust writes into them through a Swift-bound pointer. Sleep is **disabled until Steady phase**. Repulsion uses **uniform grid + cell aggregation**, not Barnes-Hut. The graph engine lives in the shared `graph-engine` Rust crate consumed by both current Epistemos and any future v2 shell.

**Ship bar**: 10k nodes at 60-120 fps on M2 Pro, sub-1s cold open, fluid Obsidian-style reveal, causal-atmosphere sleep with visual-equivalence test passing. 50k feasible. 100k feasible with cluster-first semantic zoom at full zoom-out.

**Estimated effort**: 4 weeks Phase A (CPU + shared buffer), 8 weeks Phase B (GPU compute), 4 weeks Phase C (cluster + 50k+). All in shared crate.

## Locked architectural decisions

| # | Decision | Locked value | Source |
|--:|---|---|---|
| 1 | Buffer ownership | Metal allocates `.storageModeShared`, `contents()` pointer bound into Rust via FFI | Drops 3, 4, 6 + existing code |
| 2 | Buffer ring depth | 3-slot ring (writable / cpuWriting / gpuReading), recycled via `addCompletedHandler` | Drops 4, 6 + existing code |
| 3 | NodeState struct layout | 64-byte aligned, single cache line | Drops 5, 6 |
| 4 | Render decoupled from sleep | `RENDERABLE` flag independent of `AWAKE`/`WARMING`/`SLEEPING` | All drops |
| 5 | Sleep activation | Disabled globally until Steady phase | All drops (architectural law) |
| 6 | Reveal state machine | Idle → Seeding → Ramping → Settling → Steady | All drops |
| 7 | Reveal styles | Chronological / Connected / Random / AllAtOnce | All drops |
| 8 | "All at once" semantics | Skips batching, still uses warm-start + Settling | Drops 4, 5, 6 |
| 9 | Warm-start primitive | GraphPOPE-lite (anchor distances → 2D projection) | Drops 4, 5, 6 (drop 3 dissented) |
| 10 | Warm-start anchor count | 8 (N<5k), 16 (5k-50k), 32 (>50k) | Drop 5 |
| 11 | Warm-start anchor selection | 50% top-degree + 25% PageRank/closeness + 25% farthest-point sampling | Drop 6 |
| 12 | Reveal curve | Capped exponential: `S(u) = (1 - exp(-4u)) / (1 - exp(-4))` | Drops 3, 4, 5, 6 |
| 13 | Reveal formulas | Frame-rate-aware (`F/60` scaling factor) | Drop 5 |
| 14 | FA2 adaptive speed | Swinging/traction reduction, multiply global speed by reveal `alpha_target` | Drops 4, 5, 6 |
| 15 | FA2 speed tolerance buckets | Gephi defaults: 0.1 (N<5k) / 1.0 (N<50k) / 10.0 (N≥50k) | Drop 4 + verified |
| 16 | Repulsion strategy | Uniform grid + cell mass aggregation, NOT Barnes-Hut first | Drops 3, 4, 5, 6 |
| 17 | First GPU kernel | Node-parallel CSR spring gather (no atomics) | Drops 3, 5, 6 |
| 18 | GPU pass order | Activation → grid bin → cell reduce → repulsion → springs → adaptive speed → integrate+sleep → compact → indirect draw → render | Drops 3, 5, 6 |
| 19 | Far-field repulsion | Cell aggregation now; GPU Barnes-Hut/FMM deferred until measured need | All drops |
| 20 | Sleep velocity threshold | `\|v\| < 0.002 * ideal_edge_length_per_frame` | Drops 4, 5, 6 |
| 21 | Sleep force threshold | `\|F\| < 0.01 * repulsion_scale` | Drops 4, 5, 6 |
| 22 | Sleep frame count | 24 consecutive @ 120Hz, 12 @ 60Hz | Drops 4, 6 |
| 23 | Atmosphere radius | `r_i = max(radius, 0.5*median_rest_length, world_2px) * mult + \|v\|*dt*L + heat*0.25*L` | Drop 5 |
| 24 | Predictive lookahead | `L = clamp(ceil(3 + \|v\|/(L0*dt*F)), 3, 12)`, ×2 during drag | Drop 5 |
| 25 | Hub wake budget | `min(256, ceil(0.02 * degree))`, `pending_heat` decay 0.85/frame | Drop 5 |
| 26 | Drag-no-sleep window | 250 ms post-release | Drop 5 |
| 27 | Awake-fraction collapse threshold | >20% sustained for >1s = sleep system collapsed | Drop 5 |
| 28 | Warm-zone smoothing | Smootherstep: `λ = x³(x(x·6 − 15) + 10)`, C¹ continuous | Drops 3, 5 |
| 29 | Render target | `CAMetalLayer` directly, not `MTKView` | Drops 3, 4, 6 |
| 30 | Command queue strategy | Single queue for compute + render initially; split only with deliberate fences | Drops 5, 6 |
| 31 | Cluster-first multilevel | YES at full zoom-out for 50k+, NOT a separate existence policy | Drops 2, 4, 5, 6 |
| 32 | Visual equivalence test | Mean SSIM ≥ 0.995, min ≥ 0.990, p99 visible-node position error < 2 px | All drops |
| 33 | Zoom-in regression test | Open at max zoom, every frustum node draws within 1 frame | All drops |
| 34 | Sync (CRDT) | Deferred to v2+; op-log single-writer is canonical v1 | Drop 2 + existing code |
| 35 | Markdown stance | Primary user surface; SwiftData runtime mirror | Existing product |
| 36 | v1/v2 architecture | Shared `graph-engine` crate consumed by both shells | All drops + existing structure |
| 37 | FFI panic safety | Every `extern "C"` Rust export wrapped in `catch_unwind(AssertUnwindSafe(...))` OR FFI crate compiled with `panic = "abort"` | Drop 7 (correctness requirement) |
| 38 | Foreign pointer storage in Rust | Bound Metal pointers stored as `NonNull<T>` + explicit `len_bytes` + `stride`; never reconstituted as `Vec`/`Box<[T]>` | Drop 7 (allocator-identity safety) |
| 39 | Query freshness honesty | All query responses carry `materialized_through_seq`, `local_head_seq`, and `stale_ops` fields; UI surfaces lag rather than silently lying | Drop 7 |
| 40 | Three latency classes | Subsystems explicitly classified as Immediate (same frame), Near-real-time (0-250 ms), or Heavy (50 ms - 60 s); query path merges base + delta overlay | Drop 7 |
| 41 | `cpuCacheModeWriteCombined` | Opt-in only, not default; revisit only if Rust CPU read path becomes irrelevant in Phase B | Drop 7 |
| 42 | Dual-buffer ping-pong as alternative | Named fallback if Phase B Week 1 finds in-place integration awkward; not the default | Drop 7 |

## Rejected paths (with reasoning)

- **Rust-owned `bytesNoCopy` buffer wrapping** — rejected. Drops 1, 5 recommended this; drops 3, 4, 6 + existing code recommend Metal-owned. Page-alignment and lifetime are your problem with `bytesNoCopy`. Metal-owned + `contents()` cannot have those bugs by construction.
- **GPU Barnes-Hut as first GPU kernel** — rejected. Trees are cache-hostile on Apple GPUs; grid + cell aggregation is the right Apple-silicon primitive. Defer Barnes-Hut/FMM until measured need.
- **IOSurface-backed `MTLBuffer`** — rejected. Apple's IOSurface is for textures, not the dynamic-buffer path. Not a real Apple-silicon technique for buffers.
- **MTKView in place of CAMetalLayer** — rejected. No performance evidence; you have explicit drawable-loop control reasons to keep `CAMetalLayer`.
- **CRDT sync (Yjs/Automerge) in v1** — rejected. Your op-log explicitly chose single-writer scope ("NOT automerge/yrs/diamond-types — single-writer scope keeps the CRDT merge complexity unnecessary for V1"). Multi-device sync is v2+.
- **FastRP as default warm-start** — rejected. GraphPOPE-lite is the canonical layout-seeding primitive. FastRP is fallback for vaults with very tight open budgets above 50k.
- **Markdown as import/export only** — rejected. Your product depends on Markdown as user-facing source of truth.
- **Building all V6.1 GPU kernels (5 kernels + InterruptScore) before shipping anything** — rejected. Those are HELIOS doctrine targets (`KERNEL_IMPLEMENTATION_POSTURE = "canonical_target_not_implemented_here"`). Graph engine ships independently.
- **Mesh shaders / rasterization rate map / variable shading rate** — deferred. Not the first dollar; revisit only after Phase B ships.
- **ForceAtlas3** — UNVERIFIED across all 6 drops. No public primary source. Do not anchor on it.

## Phase A — CPU foundation + zero-copy (4 weeks)

**Goal**: Make the graph feel premium at 10k nodes on CPU physics. Lay all foundations the GPU phase will build on. Ship as v1.1.

**Status (2026-05-12)**: Algorithmic deliverables for Weeks 1-4 shipped on `codex/research-snapshot-2026-05-08`:
- Week 1 (shared-buffer foundation): `d2d91da18` flipped the default + `913c7329f` shipped synthetic vault generator
- Week 2 (NodeState + slot scheduler): `bad7943b5`/`e83073d0c`/`75536ae27` shipped `GraphNodeState`, 5 FFI bind methods, `GraphSlotScheduler`, RENDERABLE invariant mirrors
- Week 3 (GraphPOPE-lite warm-start + RevealController): `57a59222f` shipped `warmstart.rs` (706 lines, 15 tests) + `reveal.rs` (455 lines, 15 tests)
- Week 4 (causal-atmosphere sleep): `11714ff37` shipped `atmosphere.rs` (476 lines, 19 tests); `c3ed09a8c` shipped `tests/visual_equivalence.rs` (343 lines, 8 tests) — pure-data harness only, pixel-SSIM half pending Metal-render feature gate
- Engine-integration pass (warmstart → integrator wiring, atmosphere → integrator wiring, RevealController → app shell) is queued as Phase B prerequisite work
- 2629 graph-engine lib tests pass, 8 integration tests pass, 0 regressions
- HELIOS V5 anchor-table parity restored alongside (`bdc579315`)

### Week 1: Shared-buffer foundation

**Deliverables**:
- Set `EPISTEMOS_USE_SHARED_GRAPH_BUFFERS=1` as default (single config change)
- Extend Swift `NodeState` struct to full layout (drop 5 + 6 verbatim):

```rust
#[repr(C, align(64))]
pub struct GraphNodeState {
    pub pos: [f32; 2],
    pub vel: [f32; 2],
    pub force: [f32; 2],
    pub prev_force: [f32; 2],
    pub flags: u32,
    pub sleep_count: u32,
    pub warm: f32,
    pub radius: f32,
}
```

- Six new FFI methods (drop 6 verbatim):
  - `graph_engine_bind_node_state_slot(engine, slot, ptr, len_bytes, stride)`
  - `graph_engine_set_write_target(engine, slot, version)`
  - `graph_engine_step_into_bound_slot(engine, dt)`
  - `graph_engine_bind_activation_mask_slot(engine, slot, ptr, len_bytes)`
  - `graph_engine_export_topology_views(engine, ...)`
  - `graph_engine_resize_bound_slots(engine, new_capacity)`
- `GraphSlotScheduler` in Swift with explicit `writable`/`cpuWriting`/`gpuReading` states
- `addCompletedHandler` recycles slots
- Delete `graph_engine_read_positions` from hot path (keep for debug only)

**Exit gate**:
- Synthetic 5k vault opens and renders identically to before the change
- Instruments confirms `graph_engine_read_positions` is NOT in per-frame hot path
- 3 buffers allocated, ring rotates correctly under semaphore
- No race conditions detected by Metal validation

### Week 2: Synthetic vault benchmark generator

**Deliverables**:
- Rust binary `agent_core/src/bin/synth_vault.rs`
- Generates 1k / 5k / 10k / 50k / 100k node vaults
- PKM-realistic characteristics:
  - Average degree 3-8 (median 4)
  - Power-law degree distribution (most notes 2-4 links, ~1% hubs with 20+ links)
  - Time-clustering (recent notes link to recent notes 3-5× more than to old notes)
  - Connected components (some isolated notes, some major clusters)
- Output: SwiftData-compatible vault for direct app import

**Exit gate**:
- All 5 vault sizes import without error
- Synthetic edge density matches PKM measurements (`mean_degree ∈ [3, 8]`)
- App opens each synthetic vault without crash

### Week 3: GraphPOPE-lite warm-start + RevealController

**Deliverables**:
- New module `graph-engine/src/warmstart.rs`:
  - GraphPOPE-lite recipe:
    1. Split graph into connected components
    2. Choose `A` anchors per component (drop 5):
       - `A = 8` if N < 5k
       - `A = 16` if 5k ≤ N < 50k
       - `A = 32` if N ≥ 50k
    3. Anchor selection (drop 6 verbatim):
       - 50% highest degree
       - 25% approximate PageRank or closeness
       - 25% farthest-point sampling
    4. Run BFS from each anchor; build `z_i[a] = 1 / (1 + d(i, a))`
    5. Standardize columns
    6. Project `Z ∈ R^{N×A}` to 2D via:
       - Deterministic two-vector random projection (simplest), or
       - 2-pass PCA / power iteration (prettier)
    7. Normalize to world-space box
  - Reveal placement: new node = weighted centroid of visible neighbors + jitter; fallback to warm-start if no visible neighbors

- New module `graph-engine/src/reveal.rs`:
  - 5-phase state machine (`Idle → Seeding → Ramping → Settling → Steady`)
  - Three reveal styles (`Chronological` / `Connected` / `Random` / `AllAtOnce`)
  - Drop 5's frame-aware formulas (verbatim):
    ```
    T_reveal(N) = clamp(1.2 + 1.1 * sqrt(N / 5000), 1.2, 9.0) * user_duration_scale
    R = round(T_reveal * F)
    k_initial = clamp(round(1 + sqrt(N) / 14), 2, 12)
    B_min = clamp(round(16 * sqrt(N / 1000) * F / 60), 16, 128)
    B_max = clamp(round(96 * sqrt(N / 1000) * F / 60), 96, 1600)
    u = frame_in_reveal / max(R, 1)
    S(u) = (1 - exp(-4u)) / (1 - exp(-4))
    batch(frame) = round(B_min + (B_max - B_min) * S(u))
    hold_frames = 1 if N < 20000 else 2
    alpha_target(batch, N) = clamp(0.035 + 0.16 * sqrt(batch / max(N, 1)), 0.04, 0.16)
    
    settle_frames = clamp(round(F * (1.0 + 0.00004 * N)), F, 5*F)
    alpha_decay = 1 - pow(0.001 / max(alpha_current, 0.001), 1 / settle_frames)
    ```
  - Settings UI: `reveal.style` enum + `reveal.target_duration_seconds`

**Exit gate**:
- Warm-start reduces "violent first frames" by ≥3× vs random init (drop 6 target)
- Reveal animation feels fluid on 5k synthetic vault by human observation
- All 4 reveal styles work; `AllAtOnce` skips batching but keeps warm-start + Settling
- Phase transition predicates fire correctly under stress

### Week 4: Causal-atmosphere sleep + visual-equivalence test

**Deliverables**:
- New module `graph-engine/src/atmosphere.rs`:
  - Atmosphere radius per node (drop 5 formula):
    ```
    r_i = max(radius_i + collide_radius,
              0.5 * median_incident_rest_length,
              world_size_of_2px) * atmosphere_multiplier
    r_i += |v_i| * dt * lookahead_frames
    r_i += heat_i * 0.25 * median_incident_rest_length
    ```
  - Predictive lookahead:
    ```
    L = clamp(ceil(3 + |v| / (median_rest_length * dt * F)), 3, 12)
    L_drag = L * 2
    ```
  - Hub wake budget:
    ```
    max_edge_wake_proposals_per_frame(i) = min(256, ceil(0.02 * degree(i)))
    pending_heat[i] decays by 0.85 per frame
    ```
  - Smootherstep warm-zone:
    ```
    x = clamp((front_radius - d) / warm_width, 0, 1)
    λ = x*x*x*(x*(x*6 - 15) + 10)
    dt_eff = mix(0, dt, λ)
    force_scale = mix(0.25, 1.0, λ)
    ```
  - Wake conditions:
    1. Atmosphere overlap (both wake)
    2. Predictive capsule overlap (sleeping → Warming)
    3. Edge propagation with score = parent_heat * edge_weight * clamp(extension/rest, 0, 4)
    4. User wake-front from click/drag/search-focus
  - Drag-no-sleep window: 250 ms post-release
  - Awake-fraction failure threshold: >20% sustained for >1s → degrade to full simulation, log telemetry

- Visual-equivalence test harness (`graph-engine/tests/visual_equivalence.rs`):
  - Deterministic 10-second interaction corpus: open, idle, pan, zoom-in, drag hub, search-pulse, zoom-out
  - Run baseline (full physics) vs candidate (causal sleep)
  - Metrics:
    - Mean SSIM ≥ 0.995
    - Min SSIM ≥ 0.990
    - p99 visible-node position error < 2 px
    - p99 visible-edge endpoint error < 2 px
    - Zero "wake misses" (sleeping node fails to react for >2 frames after wake-front passes)
  - Zoom-in regression test: open at max zoom on 100 random camera positions in 10k vault, every frustum node draws within 1 frame

**Exit gate**:
- Visual-equivalence test passes on 1k / 5k / 10k synthetic vaults
- Awake-fraction during idle interactions < 5% on 10k vault
- Zoom-in regression test passes (zero invisible nodes)
- Drag wave propagates more than one hop and feels fluid

### Phase A acceptance criteria (v1.1 ship bar)

- 1k vault: cold open ≤ 200 ms, time-to-fluid ≤ 500 ms, steady 120 fps
- 5k vault: cold open ≤ 600 ms, time-to-fluid ≤ 1.2 s, steady 90-120 fps
- 10k vault: cold open ≤ 1.4 s, time-to-fluid ≤ 2 s, steady 60-120 fps
- 50k vault: cold open ≤ 4 s, time-to-fluid ≤ 5 s, full zoom-out fps best-effort (Phase B's job to make great)
- Memory residency at 10k: ≤ 400 MB (synthesized between drops 5 and 6)
- Zoom-in invisibility regression test passes
- Visual-equivalence test passes
- No regression in existing 2,570 graph-engine tests
- App builds and codesigns cleanly

## Phase B — Metal compute (8 weeks)

**Status (2026-05-12)**: Algorithmic CPU references for Weeks 1-6 shipped on `codex/research-snapshot-2026-05-08`. The MSL `.metal` translations + engine wiring land on top of these references; the references pin the math so the kernel pass is a translation rather than a fresh design.

- Week 1-2 (spring forces + integration kernel): `dec54aa3b` shipped `force_kernels.rs` (462 lines, 16 tests). Node-parallel CSR gather + symplectic Euler integrator. Includes the locked-decision #4 RENDERABLE ⊥ SLEEPING guard. Output bit-equivalent to edge-parallel reference within 1e-5.
- Week 3-4 (uniform grid + repulsion): `c7ad79e01` shipped `grid_kernels.rs` (372 lines, 14 tests). Five-kernel pipeline: `grid_build_kernel` / `grid_scan_kernel` / `grid_scatter_kernel` / `cell_reduce_kernel` / `repulsion_kernel`. Cell-size formula matches drop 6 (`2 * median(atmosphere_radius)` capped at `world_size/32`).
- Week 5-6 (FA2 adaptive speed + wake propagation): `7de49ee89` shipped `adaptive_kernels.rs` (242 lines, 14 tests). Gephi-tolerance bucket schedule (0.1/1.0/10.0), zero-swing protection, multi-front wake propagation.
- Week 7-8 (visibility compaction + indirect draw) is rendering-surface work and lands once the integrator + renderer consume the kernel records.

**Goal**: Push to 50k nodes at 30-60 fps. Move force computation to GPU. All physics state lives in Metal-visible memory; CPU stops walking the node array.

### Week 1-2: Spring forces kernel + integration kernel

**Deliverables**:
- New file `Epistemos/Shaders/Graph/spring_forces.metal`:
  - Node-parallel CSR gather (no atomics)
  - Threadgroup size = `threadExecutionWidth * 4`, start at 128 or 256
  - Drop 6 sketch is paste-ready

- New file `Epistemos/Shaders/Graph/integrate.metal`:
  - Reads `NodeState`, applies forces, updates velocity + position
  - Honors RENDERABLE / AWAKE / WARMING / SLEEPING flag semantics
  - Warm-zone uses warm-zone smoothstep for damped force scaling
  - Drop 5 sketch is paste-ready

- Wire kernels into existing frame loop
- Keep CPU Barnes-Hut path live in parallel; A/B switchable behind flag

**Exit gate**:
- GPU spring kernel produces bit-equivalent forces to CPU baseline (within 1e-5)
- 10k vault at full physics on GPU runs at ≥ baseline CPU fps
- No race conditions under Metal API validation

### Week 3-4: Uniform grid broadphase + repulsion

**Deliverables**:
- `Epistemos/Shaders/Graph/grid_build.metal`: hash node positions into uniform grid cells
- `Epistemos/Shaders/Graph/grid_scan.metal`: exclusive prefix sum over cell counts
- `Epistemos/Shaders/Graph/grid_scatter.metal`: scatter node indices into contiguous cell lists
- `Epistemos/Shaders/Graph/cell_reduce.metal`: per-cell mass + center-of-mass
- `Epistemos/Shaders/Graph/repulsion.metal`:
  - Near-field: exact repulsion against 3×3 (or 5×5) neighbor cells
  - Far-field: approximate from cell-aggregate masses
- Cell size = `2 * median(atmosphere_radius)`, capped at `world_size / 32`

**Exit gate**:
- GPU repulsion produces visually-equivalent output to CPU Barnes-Hut on 5k / 10k / 50k synthetic vaults (visual-equivalence test passes)
- 50k vault hits ≥ 30 fps at full zoom-out

### Week 5-6: FA2 adaptive speed + GPU sleep

**Deliverables**:
- `Epistemos/Shaders/Graph/adaptive_speed.metal`:
  - Per-node swinging = `length(F - F_prev)`
  - Per-node traction = `0.5 * length(F + F_prev)`
  - Threadgroup reduction → global swing, global traction
  - Gephi tolerance bucket selection: 0.1 / 1.0 / 10.0 by N
  - Global speed = `tol(N) * global_traction / max(global_swing, eps)`
  - Multiply by reveal `alpha_target` so phases cooperate
- `Epistemos/Shaders/Graph/wake_propagation.metal`:
  - Wake-front sphere expansion at `v_max * dt` per frame
  - Smootherstep warm zone
  - Hub budget enforcement
- `Epistemos/Shaders/Graph/sleep_update.metal`:
  - Calm-frame counter per node
  - Sleep transition with K-frame threshold (24 @ 120Hz, 12 @ 60Hz)

**Exit gate**:
- Awake-fraction during idle drops to 1-3% on 50k vault
- FA2 adaptive speed prevents oscillation under sustained drag
- Visual-equivalence test still passes on 50k vault

### Week 7-8: Visibility compaction + indirect draw

**Deliverables**:
- `Epistemos/Shaders/Graph/compact_visible.metal`: frustum cull, output visible node + edge ID lists
- `Epistemos/Shaders/Graph/build_indirect_args.metal`: write `MTLDrawPrimitivesIndirectArguments` to a private buffer
- Switch render encoder to `drawPrimitivesIndirect` for nodes + edges
- CPU stops iterating node array entirely; only camera + UI run on CPU

**Exit gate**:
- 100k vault renders at ≥ 18 fps at full zoom-out with cluster LOD (deferred to Phase C if not met)
- Per-frame CPU time on render thread drops to < 2 ms
- No regression at 10k

### Phase B acceptance criteria (v1.2 ship bar)

- 1k: ≤ 80 ms cold open, 120 fps everywhere
- 5k: ≤ 220 ms cold open, 90-120 fps
- 10k: ≤ 500 ms cold open, 60-90 fps zoom-out, 90-120 fps zoom-in
- 50k: ≤ 1.5 s cold open, 30-60 fps steady, drag ≥ 30 fps
- 100k: feasible but Phase C is needed for fluid feel at full zoom-out
- Memory residency at 50k: ≤ 1 GB; at 100k: ≤ 2 GB
- All Phase A tests still pass
- Metal validation clean

## Phase C — Cluster-first multilevel for 50k+ (4 weeks)

**Status (2026-05-12)**: Algorithmic prep for Week 1-2 shipped on `codex/research-snapshot-2026-05-08`. Base Louvain has been in `cluster.rs` since the engine's first revision; this commit adds the hierarchy + centroid + incremental-update layer.

- Week 1-2 (Louvain + hierarchy + centroids): `c396e93b3` shipped `cluster_hierarchy.rs` (270 lines, 9 tests). `build_leaf_clusters` → `build_next_level` → `build_hierarchy` chain; `incremental_edge_update` short-circuits on intra-cluster edges; member-count-weighted centroids at every level. Engine FFI surface (`graph_engine_get_cluster_hierarchy`) lands during engine wiring.
- Weeks 3-4 (LOD renderer + benchmark harness) need engine + renderer wiring and land separately.

**Goal**: Make 100k-node vaults feel genuinely usable. Adopt cluster-first semantic zoom (the "philosophical" trade — full zoom-out shows cluster centroids, not literal node-per-note).

### Week 1-2: Louvain (or Leiden) clustering

**Deliverables**:
- Rust module `graph-engine/src/clustering.rs`
- Choose simpler-first: connected components + recursive bisection; upgrade to Louvain or Leiden only if A/B testing shows boundary instability
- Cluster recomputation on graph mutation (incremental, not full)
- Output: `clusters` (Vec<ClusterId>), `cluster_parent` (parent in hierarchy), `cluster_centroid` (Vec<float2>)
- FFI: `graph_engine_get_cluster_hierarchy(engine)`

**Exit gate**:
- Clustering completes in < 200 ms for 50k vault, < 1 s for 100k
- Clusters stable under incremental note addition (< 5% boundary churn per 100 notes added)

### Week 3: LOD-aware renderer

**Deliverables**:
- `MetalGraphView` checks camera zoom level
- At full zoom-out: render cluster centroids only (per-cluster sprite at COM)
- At mid zoom: render cluster centroids + leaf nodes in frustum
- At zoom-in: render all leaf nodes in frustum (existing path)
- Leaf positions ALWAYS valid (never lost when not rendered)
- Smooth transition between LOD levels (alpha cross-fade over 200 ms)

**Exit gate**:
- 100k vault renders at 30-45 fps at full zoom-out using cluster centroids
- Zoom-in to a cluster shows individual nodes within 1 frame of crossing threshold
- No invisible-node regression

### Week 4: 50k / 100k performance validation + benchmark harness

**Deliverables**:
- Run synthetic vault benchmarks at 1k / 5k / 10k / 50k / 100k
- Record: cold open, time-to-fluid, steady fps zoom-out, steady fps zoom-in, drag fps, search-pulse fps, memory residency, awake-fraction during typical use
- Profile with Instruments: Metal System Trace, Time Profiler, Memory Allocations
- File any failures against Phase B exit criteria

**Exit gate**:
- 50k vault hits final targets across all scenarios
- 100k vault hits targets WITH cluster-first zoom-out enabled
- Benchmark suite is automated and runnable from CI

### Phase C acceptance criteria (v1.3 ship bar)

| Nodes | Cold open | Time-to-fluid | Steady zoom-out | Steady zoom-in | Pan | Drag | Memory | Awake % |
|------:|----------:|--------------:|----------------:|---------------:|----:|-----:|-------:|--------:|
| 1k    | ≤ 80 ms   | 0.4-0.8 s     | 120             | 120            | 120 | 120  | ≤ 100 MB | 1-5% |
| 5k    | ≤ 140 ms  | 0.8-1.4 s     | 90-120          | 120            | 90-120 | 75-110 | ≤ 200 MB | 1-6% |
| 10k   | ≤ 220 ms  | 1.2-2.0 s     | 60-90           | 90-120         | 60-90  | 55-80  | ≤ 400 MB | 1-8% |
| 50k   | ≤ 650 ms  | 2.5-4.5 s     | 45-60           | 60-90          | 45-60  | 35-55  | ≤ 1.2 GB | 2-10% |
| 100k  | ≤ 1.4 s   | 4.5-8.0 s     | 30-45 (cluster) | 45-60          | 30-45  | 24-40  | ≤ 2.5 GB | 3-15% |

## Crash hardening checklist (apply throughout all phases)

| Failure mode | Detection | Hardening |
|---|---|---|
| `bytesNoCopy` misalignment | `makeBuffer` returns nil | Metal-owned default; if Rust must own, page-align with posix_memalign |
| Rust pointer invalidation | Intermittent SIGSEGV | Fixed-capacity buffers, no reallocation, Rust owns lifetime |
| CPU/GPU race on shared slot | Torn positions, NaN | 3-slot ring + completion handler recycling, never write to in-flight slot |
| Per-frame allocation churn | Frame spikes | Preallocate persistent heaps, no per-frame buffer creation |
| Quadtree/grid allocator churn | CPU spikes during open/pan | Arena allocator, reserve capacity once |
| Atomic hot spots on hub edges | GPU time inflated on dense subgraphs | Edge-force scratch + CSR gather, two-stage reduce |
| Edge buffer capacity overflow | Crash at medium vault sizes | Checked arithmetic, geometric growth, hysteresis |
| State machine thrash Settling↔Steady | Reveal never finishes | Monotonic phase IDs, debounced predicates, one-way latches |
| Sleeping node renders with stale visibility | Pop / vanish at zoom | Culling derived from current position buffer every frame |
| Multi-queue sync bug | Race only on real hardware | Single queue for compute+render initially; split with fences only deliberately |
| Validation-only bugs hidden in release | Crashes on user hardware | CI lane with Metal validation + Shader Validation on |
| Memory pressure / drawable starvation | App appears frozen | ≤ 2-3 frames in flight, late drawable acquisition, log wait time |
| NaN / Inf propagation | Wild vertices, invisible nodes | Clamp distances, isfinite check post-integrate, reset bad nodes |
| Cold-start pipeline compilation hitch | Only first open is bad | MTLBinaryArchive for pipeline state cache |
| Reveal state reentrancy | Phase oscillation | Single authoritative state machine, queued event transitions |
| Wrong allocator for deallocation | ASan flags invalid free | Pair `posix_memalign` with `free`; never mix with `Box::from_raw`/`Vec::from_raw_parts` |
| Rust panic across `extern "C"` boundary | Reproduce by injecting panic in exported function | Wrap every export in `catch_unwind` OR compile FFI crate with `panic = "abort"` |
| Stack-lifetime pointer through FFI | ASan reports use-of-deallocated-stack-memory | Never bind stack memory or temporary Swift arrays as persistent FFI backing; only `MTLBuffer.contents()` or long-lived heap slabs |
| GPU runtime error swallowed without triage | Crash reports say only "command buffer failed" | On `commandBuffer.status == .error` in `addCompletedHandler`, always inspect `.error`, `.logs`, and encoder-info before returning |
| `cpuCacheModeWriteCombined` used when CPU also reads | Strange cache behavior, poor CPU-side read perf | Use write-combined only for write-mostly buffers; default to plain `.storageModeShared` for now |
| Managed-resource semantics applied to shared path | `synchronize(resource:)` or `didModifyRange` calls misfire | Reserve those APIs for managed-storage code paths only; shared resources on Apple Silicon use shared mode + epoch ownership |
| Untracked heap resources without explicit sync | Corruption only after introducing heaps or aliasing | Stay in tracked mode initially; if you later disable, add `MTLFence` / `useResource` explicitly |

## Test harness (4-layer, applies to all phases)

| Layer | Frequency | What it proves |
|---|---|---|
| Rust unit tests | Every PR | ABI layout (`#[repr(C)]` + stride/size asserts), epoch state machine, `catch_unwind` wrappers fire correctly |
| Swift integration tests | Every PR | Bind shared buffer, Rust patches it, submit tiny compute+render command buffer, completion handler fires, no validation errors |
| Stress tests | Nightly | 10k-100k synthetic graphs, random topology diffs, forced reveal bursts, no write-after-read hazards under load, no NaN propagation, no buffer overrun |
| Sanitizer + validation runs | Nightly + release candidates | ASan + TSan on Rust side; Metal API Validation + Shader Validation on Swift side via dedicated **GraphValidation** Xcode scheme |

**Status (2026-05-12)**: Rows 1 and 3 are fully populated for the canonical-plan modules shipped this session.
- Row 1 (Rust unit tests): each algorithmic module ships with its own `#[cfg(test)]` block (warmstart 15, reveal 15, atmosphere 22 (+3 NaN guards), force_kernels 20 (+4 NaN guards), grid_kernels 16 (+2 NaN guards), adaptive_kernels 21, cluster_hierarchy 9, benchmark_harness 11, visibility_kernels 16 (+2 NaN guards), node_state 8, slot scheduler 7). 2726 lib tests total.
- Row 3 (Stress tests): `tests/phase_a_stress.rs` (9 tests), `tests/phase_b_stress.rs` (7 tests), `tests/phase_c_stress.rs` (7 tests), `tests/visual_equivalence.rs` (8 tests). All 10k-node fixtures. 2757 tests passing across the session arc, 0 regressions.
- Row 2 (Swift integration tests) needs the FFI bindings for the new modules; lands during engine wiring.
- Row 4 (Sanitizer + validation runs) needs the GraphValidation Xcode scheme; lands during engine wiring.

The GraphValidation scheme is a separate Xcode scheme with both API Validation and Shader Validation always enabled, run via `xcodebuild test` on a macOS CI runner. Maintain it as a hard CI lane; release candidates must pass it before any tag.

Failure cases to make deterministically reproducible:
- Bind a wrong stride and assert the engine rejects it cleanly
- Mutate the shared buffer after `commit()` in a debug-only test and assert the epoch guard catches it before the GPU does
- Pass a non-page-aligned `bytesNoCopy` slab and assert wrap failure
- Free a Rust-owned `bytesNoCopy` slab early in a controlled test and verify ASan catches it
- Inject NaN/Inf into integration scratch and verify the kernel quarantines bad state instead of propagating
- Grow an internal `Vec` after mistakenly exporting its pointer; make the crash deterministic so the pattern doesn't get repeated

## Query freshness contract (applies to all materialized views)

Every materialized view (CSR shards, cluster pyramid, layout cache, search index) carries a `through_seq` watermark. Every query response merges base + delta:

```rust
struct QueryReply<T> {
    hits: Vec<T>,
    materialized_through_seq: u64,  // base view watermark
    local_head_seq: u64,             // current local op-log head
    stale_ops: u64,                  // = local_head_seq - materialized_through_seq
}
```

If `stale_ops > 0`, the UI may surface "indexing N changes" rather than pretending freshness. This is the operational analogue of "sleep ≠ invisible": never silently lie about state. The graph view's progressive renderer can use this to decide whether to recompute its visible-edge cache or trust the base shards.

Three latency classes (subsystem-classified):

| Class | Subsystems | Target freshness |
|---|---|---|
| Immediate | Local editor, canonical graph rows, sync ack | Same frame |
| Near-real-time | Neighborhood expand, reverse links, recent-text overlay | 0-250 ms |
| Heavy | Full-text base index, HNSW, CSR shards, cluster pyramid, overview layout | 50 ms - 60 s depending on subsystem |

Implementation: when a builder publishes a new immutable artifact, it atomically swaps a manifest pointer. Readers never block on builders; they observe either the previous or the new snapshot.

## What gets deferred and why

- **GPU Barnes-Hut / FMM** — Phase B uses grid + cell aggregation; revisit only after measured need at 100k+.
- **Multi-device CRDT sync** — v2+; v1's op-log is explicitly single-writer.
- **SQLCipher full-DB encryption** — v2+; only needed when DB leaves device.
- **CRDT for graph topology** — v2+; OR-Set + Yjs/Automerge integration is a separate substrate.
- **HELIOS V6.1 GPU kernels (SemiseparableBlockScan, LocalRecallIsland, PageGather, ControllerKernelPack, PacketRouter1bit)** — these are doctrine targets in the research substrate, NOT graph-engine work. They live in `epistemos-research` behind `--features research` and remain `KERNEL_IMPLEMENTATION_POSTURE = "canonical_target_not_implemented_here"`.
- **Cosmograph-style fully-GPU texture pipeline** — defer until Phase C ships. Architecture is open for it but not committed.
- **Mesh shaders, rasterization rate maps, MTLRasterizationRateMap** — defer; revisit after Phase B.
- **Density-field / FFT / PPPM repulsion** — research-tier; UNVERIFIED public Metal implementation.

## Open uncertainties

1. **Real-user vault degree distribution** — all targets assume PKM-like (avg degree 3-8, ~1% hubs). If actual user vaults are denser, constants will need tuning. Resolve by measuring once real users ship.

2. **Cluster algorithm choice** — Louvain vs Leiden vs simpler connected-components. Will A/B test in Phase C Week 1.

3. **Memory residency at scale** — drop 5 says ≤2.5 GB at 100k; drop 6 says 300-700 MB. Real number is somewhere between. Will measure in Phase C Week 4.

4. **Whether GPU Barnes-Hut is ever needed** — grid+cluster aggregation might be enough through 100k. Decide post-Phase-C.

5. **HELIOS substrate binding for graph events** — the HELIOS-native graph ontology prompt I wrote earlier proposes mapping V6.1 substrate (RuntimePlane, InterruptScore, GateAction, NodeKind, EdgeKind, ProductStream) into graph engine concepts. That work is separable from this plan and tracked in `docs/audits/HELIOS_NATIVE_GRAPH_RESEARCH_REQUEST.md`.

## Verification against existing code (2026-05-11)

- ✅ `Epistemos/Views/Graph/MetalGraphView.swift:634` — Metal-owned `.storageModeShared` buffer exists, behind `EPISTEMOS_USE_SHARED_GRAPH_BUFFERS=1` flag
- ✅ `agent_core/src/oplog.rs` — 1,614-line append-only op-log with BLAKE3 chain, single-writer scope
- ✅ `graph-engine/src/*` — simulation.rs (4,640 lines), types.rs, spatial.rs, ECS modules; 2,570 lib tests passing
- ✅ `Epistemos/Models/SDPage.swift` — SwiftData primary; Markdown vault as source of truth
- ❌ Zero graph-specific `.metal` files — Phase B will add them in `Epistemos/Shaders/Graph/`
- ❌ Zero warm-start implementation in graph-engine — Phase A Week 3 adds it
- ❌ Zero causal-atmosphere sleep — Phase A Week 4 adds it
- ❌ Zero clustering — Phase C Week 1-2 adds it

## Confidence and provenance

- Architecture: 6 independent research drops + verified code state. Convergence is real.
- Specific formulas: cited inline per source drop. Where drops disagreed, the resolution is logged in "Rejected paths" or "Locked architectural decisions" above.
- Performance targets: synthesized from drops 3, 4, 5, 6 with honest upper bounds. Memory targets between drop 5 (conservative) and drop 6 (optimistic).
- This plan supersedes prior graph-engine planning. If you find a contradiction with an earlier doc, this one wins.

## Single first action

If you want to start tonight without thinking: change `EPISTEMOS_USE_SHARED_GRAPH_BUFFERS` default from `env-flag` to `true` in `Epistemos/Views/Graph/MetalGraphView.swift:619`. Run the existing test suite. If it passes, you've shipped Phase A Week 1's first deliverable in one line. Tomorrow you can plan the rest.

## Graph-related issues absorbed into this plan (2026-05-12 backlog sweep)

When closing out v1 polish before kicking off this plan, the following graph-specific issues were filed and explicitly deferred here for resolution during the corresponding phase. They are not standalone work items; they should be checked off as side effects of the phase deliverables.

| Issue | Backlog ID | Phase | How this plan resolves it |
|---|---|---|---|
| Graph full-screen performance regression after pixel-node work | `ISSUE-2026-05-08-020` | Phase A Week 1 + Phase B | Shared-buffer flip removes the per-frame ferry; GPU compute kernels remove residual CPU bottleneck |
| Graph node-type filters and selected-neighbor expansion missing | `ISSUE-2026-05-11-002` | Phase B Week 5-6 + Phase C | New `Filters` section in `GraphForceSettingsSection`; selected-edge length modification in the integrate kernel |
| Graph `pauseEngine()` only sets a bool, doesn't release memory | `ISSUE-2026-05-12-005` | Phase A Week 2 | Extend `pauseEngine()` to call `MetalRuntimeManager.deepUnload()` + drop the NodeState ring buffers when entering Low Memory mode. Required for the two-axis Idle Memory Mode setting (`ISSUE-2026-05-12-007`) to work correctly |
| First-note-open graph hang on cold cache | `ISSUE-2026-05-12-008` | Phase A Week 3 + Week 4 | GraphPOPE-lite warm-start + causal-atmosphere sleep wake the local neighborhood instantly without re-laying-out the whole graph |
| Notes sidebar + graph slow to open every time | `ISSUE-2026-05-12-009` | Phase C Week 1-2 + cross-cutting `ProjectionCache` | Cluster pyramid persistence + graph snapshot in `ProjectionCache` (non-graph component) means cold launch reads positions from disk instead of running physics from scratch |
| 2GB idle memory regression — graph engine contribution | `ISSUE-2026-04-21-004` (graph slice) | Phase A Week 2 | When `pauseEngine()` is upgraded to truly release MTLBuffers + Metal heap scratch, the graph engine's idle contribution drops from ~500MB-1GB to ~50MB (clusters + last-frame positions cached) |

All six issues are checked off when their owning phase's exit gate passes. Do not fix them in isolation — they're already in the plan.
