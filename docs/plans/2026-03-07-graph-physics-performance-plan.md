# Graph Physics Performance Optimization Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Unlock fluid graph physics at high node counts (1000+) through 5 phases of optimization, each independently verifiable.

**Architecture:** The graph engine (Rust + Metal) uses a Barnes-Hut quadtree for N-body repulsion, spatial-hash collision, and spring link forces on a physics thread at 40Hz. Positions sync to the renderer via `Arc<Mutex<Simulation>>`. Each phase targets a specific bottleneck: approximation quality, adaptive throttling, viewport-scoped physics, SIMD vectorization, and GPU compute offload.

**Tech Stack:** Rust (graph-engine crate), Metal Shading Language (MSL), metal-rs bindings

**Verification between each phase:**
```bash
cd /Users/jojo/Epistemos/graph-engine && cargo test
cd /Users/jojo/Epistemos/graph-engine && cargo build --release
cp target/release/libgraph_engine.a /Users/jojo/Epistemos/build-rust/
xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
```

---

## Phase 1: Barnes-Hut Theta Tuning (5 min)

**Why:** THETA=0.5 means the quadtree traverses deeper than necessary for visual layout. Bumping to 0.8 uses far-field approximation more aggressively — fewer tree traversals per node, ~2-3x faster N-body calculation. Visual difference is imperceptible for force-directed layout (this isn't astrophysics).

**Files:**
- Modify: `graph-engine/src/quadtree.rs:12`
- Modify: `graph-engine/src/quadtree.rs:798-799` (test assertion)

### Step 1: Update THETA constant

In `graph-engine/src/quadtree.rs:12`, change:
```rust
pub const THETA: f32 = 0.5;
```
to:
```rust
pub const THETA: f32 = 0.8;
```

### Step 2: Update the test assertion

In `graph-engine/src/quadtree.rs`, find the `theta_constant_value` test:
```rust
fn theta_constant_value() {
    assert_eq!(THETA, 0.5);
}
```
Change to:
```rust
fn theta_constant_value() {
    assert_eq!(THETA, 0.8);
}
```

### Step 3: Run tests

```bash
cd /Users/jojo/Epistemos/graph-engine && cargo test
```
Expected: All 2269 tests pass.

### Step 4: Audit

Run the full verification sequence. Visually confirm the graph still converges to a reasonable layout — nodes should spread out and settle, not clump or explode.

---

## Phase 2: Adaptive Tick Rate by Node Count (10 min)

**Why:** At 40Hz × 2000 nodes, the physics thread is doing 80,000 force calculations per second. Nodes at high counts move slowly anyway — the eye can't track individual motion. Scaling tick rate down with node count gives proportional CPU savings.

**Files:**
- Modify: `graph-engine/src/engine.rs` (physics_loop function, ~line 1487)

### Step 1: Replace fixed PHYSICS_HZ with adaptive function

In `graph-engine/src/engine.rs`, add a function above `physics_loop`:
```rust
/// Adaptive physics tick rate: fewer ticks when many nodes (diminishing visual returns).
fn adaptive_physics_hz(node_count: usize) -> f64 {
    match node_count {
        0..=500 => 40.0,
        501..=1500 => 25.0,
        1501..=3000 => 15.0,
        _ => 10.0,
    }
}
```

### Step 2: Use adaptive rate in physics_loop

In `physics_loop`, the current code is:
```rust
let target_dt = Duration::from_secs_f64(1.0 / PHYSICS_HZ);
```

Change the loop to read node count and adapt:
```rust
fn physics_loop(sim: Arc<Mutex<Simulation>>, stop: Arc<AtomicBool>) {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let slow_dt = Duration::from_secs_f64(1.0 / 30.0);

        while !stop.load(Ordering::Relaxed) {
            let start = Instant::now();

            let (settled, alpha, node_count) = {
                let mut sim = sim.lock();
                sim.tick();
                (sim.is_settled, sim.params.alpha, sim.x.len())
            };

            let target_dt = Duration::from_secs_f64(1.0 / adaptive_physics_hz(node_count));

            if settled {
                if stop.load(Ordering::Relaxed) {
                    break;
                }
                std::thread::sleep(Duration::from_millis(SETTLED_SLEEP_MS));
                continue;
            }

            let frame_dt = if alpha < 0.01 { slow_dt.max(target_dt) } else { target_dt };
            let elapsed = start.elapsed();
            if elapsed < frame_dt {
                std::thread::sleep(frame_dt - elapsed);
            }
        }
    }));
    // ... existing panic handler unchanged
```

Note: `PHYSICS_HZ` constant can be removed or kept for reference.

### Step 3: Run tests

```bash
cargo test
```
Expected: All tests pass.

### Step 4: Audit

Build release, copy lib, build Swift. Test with a graph that has 500+ nodes — confirm physics still runs smoothly but CPU usage is lower (Activity Monitor).

---

## Phase 3: Reduce Collision Iterations (2 min)

**Why:** `collision_iterations` is currently 2, meaning the spatial-hash collision resolution runs twice per tick. At high node counts this is expensive. Dropping to 1 halves the cost — overlap correction is gradual anyway and converges over multiple ticks.

**Files:**
- Modify: `graph-engine/src/simulation.rs:109`
- Modify: tests that assert `collision_iterations == 2` (lines ~1076, ~1564)

### Step 1: Change default collision_iterations

In `graph-engine/src/simulation.rs:109`:
```rust
collision_iterations: 2,
```
Change to:
```rust
collision_iterations: 1,
```

### Step 2: Update test assertions

Find all tests asserting `collision_iterations == 2` and change to 1:
- Line ~1076: `assert_eq!(p.collision_iterations, 2);` → `assert_eq!(p.collision_iterations, 1);`
- Line ~1564: `assert_eq!(p.collision_iterations, 2);` → `assert_eq!(p.collision_iterations, 1);`

### Step 3: Run tests

```bash
cargo test
```

### Step 4: Audit

Visually confirm nodes don't overlap excessively. Some minor transient overlap is acceptable — it resolves within a few frames.

---

## Phase 4: Viewport-Only Physics (1 session)

**Why:** When zoomed in, off-screen nodes still have full force calculations. Viewport-scoped physics freezes off-screen nodes, only simulating forces for visible nodes + a 1-hop neighbor buffer. This scales physics cost with viewport, not total graph size.

**Files:**
- Modify: `graph-engine/src/simulation.rs` (tick function)
- Modify: `graph-engine/src/engine.rs` (pass viewport bounds to simulation)
- Create: `graph-engine/src/tests/viewport_physics_tests.rs`

### Step 1: Add viewport bounds to Simulation

In `graph-engine/src/simulation.rs`, add fields to `Simulation`:
```rust
/// Viewport bounds in world space. When set, only nodes inside (+ neighbor buffer)
/// receive force updates. None = simulate all nodes (zoomed-to-fit / global view).
pub viewport_bounds: Option<[f32; 4]>,  // [min_x, min_y, max_x, max_y]
```

Initialize to `None` in the constructor.

### Step 2: Add viewport check to force loops

In `tick()`, before the force application section, build an `active_mask: Vec<bool>` where each node is `true` if:
- It's inside the viewport bounds (with padding of 200 world units), OR
- Any of its edges connect to a node inside the viewport (1-hop buffer)

If `viewport_bounds` is `None`, all nodes are active.

Then gate the velocity/position update loop (step 3 of tick) — only update `vx[i], vy[i], x[i], y[i]` for active nodes. Barnes-Hut and link forces still run on all nodes (their output just gets discarded for inactive nodes via the mask).

### Step 3: Pass viewport from engine to simulation

In `engine.rs`, inside the render function before the `sync_all_positions()` call, compute viewport bounds from the camera and pass them:
```rust
let vp = viewport_bounds(
    self.renderer.camera_offset,
    self.renderer.camera_zoom,
    [width as f32, height as f32],
    200.0,  // padding in world units
);
self.sim.lock().viewport_bounds = Some([vp.min_x, vp.min_y, vp.max_x, vp.max_y]);
```

When zoom-to-fit is active or zoom is very low (< 0.3), set `viewport_bounds = None` to simulate all.

### Step 4: Write tests

Test that:
- Nodes inside viewport have updated positions after tick
- Nodes outside viewport retain their positions
- Nodes connected to viewport nodes (1-hop) also update
- `viewport_bounds = None` updates all nodes

### Step 5: Audit

Build, test visually. Pan around the graph — off-screen nodes should appear to "wake up" as they enter the viewport. Check there's no jitter at viewport edges.

---

## Phase 5: SIMD Vectorization for Force Loops (1 session)

**Why:** The velocity integration loop (decay, clamp, add) processes x and y separately in scalar. SIMD processes 4-8 floats simultaneously. The link force inner loop also has SIMD potential. Expected 2-4x speedup for these hot loops.

**Files:**
- Modify: `graph-engine/src/simulation.rs` (velocity integration loop)
- Modify: `graph-engine/src/forces.rs` (link force inner loop)
- Add: SIMD feature gate in `graph-engine/Cargo.toml`

### Step 1: SIMD velocity integration

Replace the scalar velocity integration loop in `simulation.rs` (the `for i in 0..n` loop at ~line 782) with a two-pass approach:

**Pass 1 — bulk SIMD for non-pinned nodes:**
Process `vx` and `vy` arrays in chunks of 4 using `std::simd::f32x4` (nightly) or manual `unsafe` pointer arithmetic with `_mm_mul_ps` / `_mm_add_ps` via `std::arch::aarch64` NEON intrinsics (stable on ARM).

For ARM (Apple Silicon), the intrinsics are:
```rust
use std::arch::aarch64::*;

// Process 4 velocities at once
unsafe {
    let decay_vec = vdupq_n_f32(decay);
    let max_vel = vdupq_n_f32(MAX_VELOCITY);
    let neg_max_vel = vdupq_n_f32(-MAX_VELOCITY);

    for chunk_start in (0..n).step_by(4) {
        let end = (chunk_start + 4).min(n);
        if end - chunk_start < 4 { break; } // handle remainder scalar

        let vx_ptr = self.vx.as_mut_ptr().add(chunk_start);
        let x_ptr = self.x.as_mut_ptr().add(chunk_start);

        let mut v = vld1q_f32(vx_ptr);
        v = vmulq_f32(v, decay_vec);
        v = vminq_f32(v, max_vel);
        v = vmaxq_f32(v, neg_max_vel);
        vst1q_f32(vx_ptr, v);

        let pos = vld1q_f32(x_ptr);
        let new_pos = vaddq_f32(pos, v);
        vst1q_f32(x_ptr, new_pos);
    }
}
```

**Pass 2 — scalar remainder and pinned nodes:**
Handle the last `n % 4` nodes and any pinned nodes (those with `fx[i].is_some()`) with the existing scalar code.

### Step 2: SIMD link force

In `forces.rs`, the link force inner loop computes `dx = x[ti] - x[si]`, `dy = y[ti] - y[si]`, `dist = sqrt(dx*dx + dy*dy)`, then applies spring forces. This processes one edge at a time.

Batch 4 edges and compute all 4 distances simultaneously:
```rust
// Load 4 source positions, 4 target positions
let sx = vld1q_f32(&x[src_indices[0]..]);  // need gather, so manual load
// ... (gather is not available in NEON, so load 4 scalars into vector)
```

Note: NEON doesn't have gather instructions, so the link force SIMD benefit is limited. Focus on the velocity integration loop where data is contiguous.

### Step 3: Feature gate

Add to `Cargo.toml`:
```toml
[features]
simd = []
```

Gate SIMD code behind `#[cfg(target_arch = "aarch64")]` so it compiles on all platforms but only uses intrinsics on ARM.

### Step 4: Benchmark

Add a benchmark test that runs 1000 ticks with 2000 nodes and measures wall time. Compare before/after SIMD.

### Step 5: Audit

Run full test suite. Verify positions converge to same layout as scalar (within floating-point tolerance).

---

## Phase 6: Metal Compute Shaders for N-Body (2-3 sessions)

**Why:** The Barnes-Hut N-body force is O(N log N) on CPU but still the single most expensive operation. GPU can run a simpler O(N²) brute-force algorithm and still be 10-50x faster because it parallelizes across thousands of threads. For N < 10,000, brute-force on GPU beats Barnes-Hut on CPU.

**Files:**
- Modify: `graph-engine/src/renderer.rs` (add compute pipeline, position/velocity buffers)
- Create: compute shader MSL source (inline in renderer.rs, same pattern as SHADER_SOURCE)
- Modify: `graph-engine/src/engine.rs` (route N-body to GPU when available)
- Modify: `graph-engine/src/simulation.rs` (skip CPU N-body when GPU is active)

### Step 1: Design the compute shader

MSL kernel that runs one thread per node. Each thread:
1. Reads its own position from a `device float2* positions` buffer
2. Loops over ALL other nodes, accumulating repulsion force (brute-force O(N))
3. Writes force delta to a `device float2* forces` buffer

```metal
kernel void nbody_repulsion(
    device const float2* positions [[buffer(0)]],
    device float2* forces [[buffer(1)]],
    constant uint& node_count [[buffer(2)]],
    constant float& charge_strength [[buffer(3)]],
    constant float& alpha [[buffer(4)]],
    constant float& distance_max_sq [[buffer(5)]],
    uint tid [[thread_position_in_grid]])
{
    if (tid >= node_count) return;

    float2 pos = positions[tid];
    float2 force = float2(0.0);

    for (uint j = 0; j < node_count; j++) {
        if (j == tid) continue;
        float2 d = positions[j] - pos;
        float dist_sq = dot(d, d);
        if (dist_sq > distance_max_sq || dist_sq < 1.0) continue;
        float dist = sqrt(dist_sq);
        float w = charge_strength * alpha / dist_sq;
        force += (d / dist) * w;
    }

    forces[tid] = force;
}
```

### Step 2: Create compute pipeline in renderer

In `renderer.rs`, during initialization:
1. Compile the compute shader from inline MSL source
2. Create `MTLComputePipelineState`
3. Allocate `position_buf` and `force_buf` as shared Metal buffers

```rust
// In Renderer struct:
compute_pipeline: Option<ComputePipelineState>,
compute_position_buf: Option<Buffer>,
compute_force_buf: Option<Buffer>,
```

### Step 3: Add GPU N-body dispatch function

```rust
pub fn dispatch_gpu_nbody(&mut self, world: &World, charge_strength: f32, alpha: f32, distance_max: f32) -> Option<Vec<[f32; 2]>> {
    let pipeline = self.compute_pipeline.as_ref()?;
    let n = world.len();
    if n == 0 { return None; }

    // Upload positions to GPU buffer
    // ... (write world.transform x,y as float2 array)

    // Dispatch compute
    let cmd_buf = self.command_queue.new_command_buffer();
    let encoder = cmd_buf.new_compute_command_encoder();
    encoder.set_compute_pipeline_state(pipeline);
    encoder.set_buffer(0, Some(&pos_buf), 0);
    encoder.set_buffer(1, Some(&force_buf), 0);
    // ... set uniforms
    let threads_per_group = 256;
    let thread_groups = (n + threads_per_group - 1) / threads_per_group;
    encoder.dispatch_thread_groups(/* ... */);
    encoder.end_encoding();
    cmd_buf.commit();
    cmd_buf.wait_until_completed();

    // Read back forces
    // ... return Vec<[f32; 2]>
}
```

### Step 4: Route N-body to GPU in engine

In `engine.rs`, before the physics tick:
- If GPU is available and node count > threshold (e.g., 200), dispatch GPU N-body
- Pass resulting forces to the simulation's velocity arrays
- Tell simulation to skip its CPU Barnes-Hut pass

Add a flag to Simulation: `pub skip_cpu_nbody: bool`

### Step 5: Write tests

- Test that GPU forces match CPU forces within tolerance (< 5% error for layout purposes)
- Test fallback to CPU when GPU unavailable
- Benchmark: compare 1000-tick convergence time GPU vs CPU at 500, 1000, 2000, 5000 nodes

### Step 6: Audit

Full test suite. Visual comparison of final layout GPU vs CPU. Performance profiling with Instruments to confirm GPU utilization.

---

## Summary

| Phase | Change | Expected Speedup | Risk |
|-------|--------|-------------------|------|
| 1 | THETA 0.5→0.8 | 2-3x N-body | None |
| 2 | Adaptive Hz (40→10 by count) | 2-4x at 1000+ nodes | None |
| 3 | Collision iterations 2→1 | 2x collision | Low (minor overlap) |
| 4 | Viewport-only physics | Proportional to zoom | Medium (edge jitter) |
| 5 | SIMD velocity integration | 2-4x integration loop | Low (float tolerance) |
| 6 | Metal compute N-body | 10-50x N-body | Medium (GPU sync) |

Phases 1-3 are quick wins (< 20 minutes total). Phase 4-5 are medium effort (1 session each). Phase 6 is the big architectural addition (2-3 sessions).
