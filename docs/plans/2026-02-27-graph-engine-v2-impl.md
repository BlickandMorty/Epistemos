# Graph Engine V2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add cluster physics, fix/enhance GPU labels, add cursor attractor, fix chat glitch, and optimize performance (FPS + CPU).

**Architecture:** Rust graph engine (forces, simulation, renderer) + Swift bridge (FFI) + SwiftUI controls. All physics and rendering in Rust, orchestration in Swift. TDD with `cargo test` and `xcodebuild test`.

**Tech Stack:** Rust (forces, simulation, renderer, Metal shaders), Swift (GraphState, GraphForceSettings, MetalGraphView, NodeInspectorState, HologramNodeInspector), Metal Shading Language (MSDF labels).

---

## Task 1: Performance — Reduce Physics Hz and Fix Settled Detection

**Files:**
- Modify: `graph-engine/src/engine.rs:26-28` (PHYSICS_HZ and SETTLED_SLEEP_MS constants)
- Modify: `graph-engine/src/simulation.rs:210-231` (tick settled detection)
- Test: `graph-engine/src/simulation.rs` (existing tests module)

**Step 1: Write failing test for velocity-based settled detection**

In `graph-engine/src/simulation.rs` tests module, add:

```rust
#[test]
fn warmth_does_not_prevent_settling_when_velocities_zero() {
    let graph = make_test_graph(5, true);
    let mut sim = Simulation::new();
    sim.load_from_graph(&graph);
    sim.params.warmth = 0.5; // Would previously prevent settling

    // Run until velocities are negligible.
    for _ in 0..600 {
        sim.tick();
    }

    // Check all velocities are near zero.
    let max_vel = sim.vx.iter().zip(sim.vy.iter())
        .map(|(vx, vy)| vx.abs().max(vy.abs()))
        .fold(0.0f32, f32::max);

    assert!(max_vel < 1.0, "velocities should be near zero, max was {}", max_vel);
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test warmth_does_not_prevent_settling -- --nocapture`
Expected: FAIL — warmth keeps alpha above alpha_min, simulation never fully settles.

**Step 3: Fix settled detection**

In `graph-engine/src/simulation.rs`, modify the `tick()` method's alpha decay and settling logic (lines ~217-232):

```rust
// 1. Alpha decay (with warmth floor — keeps graph gently alive)
self.params.alpha +=
    (self.params.alpha_target - self.params.alpha) * self.params.alpha_decay;

let warmth = self.params.warmth;
let alpha_floor = warmth * 0.03;
if self.params.alpha < self.params.alpha_min.max(alpha_floor) {
    if warmth > 0.0 {
        self.params.alpha = alpha_floor;
    } else {
        self.is_settled = true;
        return;
    }
}

// Even with warmth, check if velocities are negligible.
// This prevents burning CPU when the graph is effectively still.
let max_vel = self.vx.iter().zip(self.vy.iter())
    .map(|(vx, vy)| vx.abs().max(vy.abs()))
    .fold(0.0f32, f32::max);
if max_vel < 0.05 && self.params.alpha <= alpha_floor + 0.001 {
    self.is_settled = true;
    return;
}
self.is_settled = false;
```

**Step 4: Reduce physics Hz and increase settled sleep**

In `graph-engine/src/engine.rs`, change:

```rust
const PHYSICS_HZ: f64 = 60.0;       // was 120.0 — physics doesn't need ProMotion rates
const SETTLED_SLEEP_MS: u64 = 200;   // was 100 — longer sleep when idle
```

**Step 5: Run tests to verify they pass**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test`
Expected: ALL PASS (including the new test and all existing tests).

**Step 6: Commit**

```bash
git add graph-engine/src/engine.rs graph-engine/src/simulation.rs
git commit -m "perf: reduce physics to 60Hz, fix settled detection with velocity check"
```

---

## Task 2: Performance — Render Frame Skipping When Idle

**Files:**
- Modify: `graph-engine/src/engine.rs` (render method — add idle frame counter)

**Step 1: Add idle frame skip logic**

In `graph-engine/src/engine.rs`, add a field to the `Engine` struct:

```rust
/// Counts consecutive frames where the engine reported "no more frames needed."
/// Used to throttle render calls when idle.
idle_frame_count: u32,
```

Initialize to 0 in `Engine::new()`.

In the `render()` method, after computing `needs_frame`:

```rust
if !needs_frame {
    self.idle_frame_count += 1;
    // After 3 idle frames, return 0 immediately without redrawing.
    // This avoids redundant GPU work when nothing is changing.
    if self.idle_frame_count > 3 {
        return 0;
    }
} else {
    self.idle_frame_count = 0;
}
```

Also, in methods that should wake the engine from idle (mouse_down, mouse_moved, scroll, magnify, set_force_params, etc.), reset `idle_frame_count = 0`.

**Step 2: Run tests**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test`
Expected: ALL PASS.

**Step 3: Commit**

```bash
git add graph-engine/src/engine.rs
git commit -m "perf: skip redundant render frames when graph is idle"
```

---

## Task 3: Fix GPU Labels — Debug and Enhance Existing Pipeline

**Files:**
- Modify: `graph-engine/src/renderer.rs` (upload_labels — fix the y-axis label offset and enhance fade logic)
- Test: `graph-engine/src/msdf.rs` (existing tests + new)

**Step 1: Write test for label position below node**

In `graph-engine/src/renderer.rs`, the `upload_labels` function places labels at `[node.x, node.y + node.radius + LABEL_GAP]`. In the Epistemos coordinate system, positive Y is down. The shader flips Y with `float2(1, -1)`, so labels should appear BELOW nodes.

Add test in `graph-engine/src/msdf.rs`:

```rust
#[test]
fn layout_label_position_offset_preserved() {
    let atlas = FontAtlas::load();
    let instances = atlas.layout_label("Test", [100.0, 200.0], 10.0, 1.0, [1.0, 1.0, 1.0, 1.0]);
    assert!(!instances.is_empty());
    // All glyphs should have position = the anchor point passed in.
    for inst in &instances {
        assert_eq!(inst.position, [100.0, 200.0], "glyph position should match anchor");
    }
}
```

**Step 2: Run test**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test layout_label_position -- --nocapture`
Expected: PASS (confirms existing behavior is correct).

**Step 3: Enhance label visibility — increase font size and add tunable fade params**

In `graph-engine/src/renderer.rs`, modify `upload_labels` to use configurable label params instead of hardcoded constants:

Add to `Renderer`:

```rust
// Label rendering settings (tunable from Swift)
pub label_fade_start: f32,  // screen radius below which labels are invisible (default 6)
pub label_fade_end: f32,    // screen radius above which labels are fully opaque (default 18)
pub label_font_size: f32,   // base font size in world units (default 12)
pub labels_enabled: bool,   // master toggle (default true)
```

Initialize defaults in `Renderer::new()`:
```rust
label_fade_start: 6.0,
label_fade_end: 18.0,
label_font_size: 12.0,
labels_enabled: true,
```

Update `upload_labels` to use these fields instead of the hardcoded `MIN_SCREEN_RADIUS` and `FONT_SIZE` constants. Remove the `MAX_LABELS: 40` cap (GPU handles thousands of glyphs fine).

Replace the alpha computation:
```rust
let screen_radius = node.radius * zoom;
if screen_radius < self.label_fade_start { continue; }
let size_alpha = ((screen_radius - self.label_fade_start) / (self.label_fade_end - self.label_fade_start)).clamp(0.0, 1.0);
```

**Step 4: Run all tests**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test`
Expected: ALL PASS.

**Step 5: Commit**

```bash
git add graph-engine/src/renderer.rs graph-engine/src/msdf.rs
git commit -m "fix: enhance GPU label rendering with tunable fade params"
```

---

## Task 4: Label Settings FFI Bridge

**Files:**
- Modify: `graph-engine/src/engine.rs` (add set_label_params method)
- Modify: `graph-engine/src/lib.rs` (add FFI function)
- Modify: `graph-engine-bridge/graph_engine.h` (add C declaration)
- Modify: `Epistemos/Graph/GraphState.swift` (add label settings properties)
- Modify: `Epistemos/Views/Graph/GraphForceSettings.swift` (add Labels section)
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift` (push label params)

**Step 1: Add Rust-side set_label_params**

In `graph-engine/src/engine.rs`, add to `Engine`:

```rust
pub fn set_label_params(&mut self, fade_start: f32, fade_end: f32, font_size: f32, enabled: bool) {
    self.renderer.label_fade_start = fade_start;
    self.renderer.label_fade_end = fade_end;
    self.renderer.label_font_size = font_size;
    self.renderer.labels_enabled = enabled;
}
```

**Step 2: Add FFI function**

In `graph-engine/src/lib.rs`:

```rust
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_label_params(
    engine: *mut Engine,
    fade_start: f32,
    fade_end: f32,
    font_size: f32,
    enabled: u8,
) {
    let engine = unsafe { &mut *engine };
    engine.set_label_params(fade_start, fade_end, font_size, enabled != 0);
}
```

**Step 3: Add C header declaration**

In `graph-engine-bridge/graph_engine.h`, add in the Display Settings section:

```c
/// Set label rendering parameters.
/// @param fade_start Screen radius below which labels are invisible.
/// @param fade_end   Screen radius above which labels are fully opaque.
/// @param font_size  Base font size in world units.
/// @param enabled    1 to show labels, 0 to hide.
void graph_engine_set_label_params(Engine* engine, float fade_start, float fade_end, float font_size, uint8_t enabled);
```

**Step 4: Add Swift-side GraphState properties**

In `Epistemos/Graph/GraphState.swift`, add after the `orbital` property:

```swift
// ── Labels ──
var labelsEnabled: Bool = true
var labelFadeStart: Float = 6.0
var labelFadeEnd: Float = 18.0
var labelFontSize: Float = 12.0

var labelConfigVersion: Int = 0

func pushLabelChange() {
    labelConfigVersion += 1
}
```

**Step 5: Add label sliders to GraphForceSettings**

In `Epistemos/Views/Graph/GraphForceSettings.swift`, add a new "Labels" section after the Advanced section:

```swift
Divider().opacity(0.3)
labelSection(gs: $gs)
```

With:

```swift
private func labelSection(gs: Bindable<GraphState>) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        sectionHeader("Labels", icon: "textformat")

        Toggle("Show Labels", isOn: gs.labelsEnabled)
            .font(.system(size: 11))
            .onChange(of: graphState.labelsEnabled) { graphState.pushLabelChange() }

        if graphState.labelsEnabled {
            forceSlider(
                label: "Fade Start",
                value: gs.labelFadeStart,
                range: 2...30,
                format: "%.0f px",
                subtitle: "Zoom level where labels appear",
                onChange: { graphState.pushLabelChange() }
            )

            forceSlider(
                label: "Fade End",
                value: gs.labelFadeEnd,
                range: 5...50,
                format: "%.0f px",
                subtitle: "Zoom level for full opacity",
                onChange: { graphState.pushLabelChange() }
            )

            forceSlider(
                label: "Label Size",
                value: gs.labelFontSize,
                range: 6...24,
                format: "%.0f",
                onChange: { graphState.pushLabelChange() }
            )
        }
    }
}
```

**Step 6: Push label params from MetalGraphView**

In `Epistemos/Views/Graph/MetalGraphView.swift`, add to `MetalGraphNSView`:

```swift
var lastLabelConfigVersion: Int = 0

func pushLabelParams() {
    guard let engine, let graphState else { return }
    graph_engine_set_label_params(
        engine,
        graphState.labelFadeStart,
        graphState.labelFadeEnd,
        graphState.labelFontSize,
        graphState.labelsEnabled ? 1 : 0
    )
}
```

In `renderFrame()`, add after the extended force params sync:

```swift
if let graphState, lastLabelConfigVersion != graphState.labelConfigVersion {
    lastLabelConfigVersion = graphState.labelConfigVersion
    pushLabelParams()
}
```

**Step 7: Run tests**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test`
Run: `cd /Users/jojo/Epistemos && xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests 2>&1 | tail -30`
Expected: ALL PASS.

**Step 8: Commit**

```bash
git add graph-engine/src/engine.rs graph-engine/src/lib.rs graph-engine-bridge/graph_engine.h \
  Epistemos/Graph/GraphState.swift Epistemos/Views/Graph/GraphForceSettings.swift \
  Epistemos/Views/Graph/MetalGraphView.swift
git commit -m "feat: add tunable label settings with FFI bridge"
```

---

## Task 5: Cluster Physics — Louvain Community Detection

**Files:**
- Create: `graph-engine/src/cluster.rs`
- Modify: `graph-engine/src/lib.rs` (add module)

**Step 1: Write failing tests for Louvain**

Create `graph-engine/src/cluster.rs`:

```rust
//! Louvain community detection for cluster physics.
//! Detects densely connected subgraphs and assigns cluster IDs.

/// Detect communities using a simplified Louvain method.
/// Returns a Vec<u32> where result[i] = cluster_id for node i.
/// Only operates on the provided edge list (simulation indices).
pub fn detect_communities(
    n: usize,
    edges: &[(usize, usize)],
) -> Vec<u32> {
    if n == 0 { return Vec::new(); }
    if edges.is_empty() {
        // No edges: each node is its own cluster.
        return (0..n as u32).collect();
    }

    // Initialize: each node in its own community.
    let mut community: Vec<u32> = (0..n as u32).collect();

    // Build adjacency for quick neighbor lookup.
    let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
    for &(u, v) in edges {
        if u < n && v < n {
            adj[u].push(v);
            adj[v].push(u);
        }
    }

    // Simplified Louvain: iterate until no improvement.
    // For each node, move to the neighbor's community that maximizes modularity gain.
    let total_edges = edges.len() as f64;
    if total_edges == 0.0 { return community; }

    // Degree of each node.
    let degree: Vec<usize> = adj.iter().map(|a| a.len()).collect();

    let mut improved = true;
    let mut iterations = 0;
    while improved && iterations < 10 {
        improved = false;
        iterations += 1;

        for i in 0..n {
            let current_comm = community[i];

            // Count edges to each neighboring community.
            let mut comm_edges: std::collections::HashMap<u32, usize> = std::collections::HashMap::new();
            for &j in &adj[i] {
                *comm_edges.entry(community[j]).or_default() += 1;
            }

            // Find best community (most edges into it).
            let mut best_comm = current_comm;
            let mut best_count = comm_edges.get(&current_comm).copied().unwrap_or(0);

            for (&comm, &count) in &comm_edges {
                if count > best_count || (count == best_count && comm < best_comm) {
                    best_comm = comm;
                    best_count = count;
                }
            }

            if best_comm != current_comm {
                community[i] = best_comm;
                improved = true;
            }
        }
    }

    // Renumber communities to be contiguous (0, 1, 2, ...).
    let mut renumber: std::collections::HashMap<u32, u32> = std::collections::HashMap::new();
    let mut next_id = 0u32;
    for c in &mut community {
        let new_id = renumber.entry(*c).or_insert_with(|| {
            let id = next_id;
            next_id += 1;
            id
        });
        *c = *new_id;
    }

    community
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_graph() {
        let result = detect_communities(0, &[]);
        assert!(result.is_empty());
    }

    #[test]
    fn no_edges_each_node_own_cluster() {
        let result = detect_communities(5, &[]);
        assert_eq!(result.len(), 5);
        // Each node should be in a unique cluster.
        let unique: std::collections::HashSet<u32> = result.into_iter().collect();
        assert_eq!(unique.len(), 5);
    }

    #[test]
    fn two_cliques_detected() {
        // Two triangles connected by a single edge.
        let edges = vec![
            (0, 1), (1, 2), (0, 2),  // clique A
            (3, 4), (4, 5), (3, 5),  // clique B
            (2, 3),                    // bridge
        ];
        let result = detect_communities(6, &edges);
        assert_eq!(result.len(), 6);
        // Nodes 0,1,2 should share a cluster; nodes 3,4,5 should share another.
        assert_eq!(result[0], result[1]);
        assert_eq!(result[1], result[2]);
        assert_eq!(result[3], result[4]);
        assert_eq!(result[4], result[5]);
        assert_ne!(result[0], result[3], "two cliques should be different clusters");
    }

    #[test]
    fn single_component_one_cluster() {
        // Fully connected 4 nodes.
        let edges = vec![(0,1),(0,2),(0,3),(1,2),(1,3),(2,3)];
        let result = detect_communities(4, &edges);
        // All should be in the same cluster.
        assert!(result.iter().all(|&c| c == result[0]));
    }

    #[test]
    fn ring_graph() {
        // Ring of 6 nodes — should be one or two clusters.
        let edges = vec![(0,1),(1,2),(2,3),(3,4),(4,5),(5,0)];
        let result = detect_communities(6, &edges);
        assert_eq!(result.len(), 6);
        // Clusters should be contiguous.
        let max_cluster = *result.iter().max().unwrap();
        assert!(max_cluster <= 5); // At most 6 clusters.
    }
}
```

**Step 2: Register module**

In `graph-engine/src/lib.rs`, add:

```rust
pub mod cluster;
```

**Step 3: Run tests**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test cluster`
Expected: ALL PASS.

**Step 4: Commit**

```bash
git add graph-engine/src/cluster.rs graph-engine/src/lib.rs
git commit -m "feat: add Louvain community detection for cluster physics"
```

---

## Task 6: Cluster Force + Center Mode

**Files:**
- Modify: `graph-engine/src/forces.rs` (add force_cluster)
- Modify: `graph-engine/src/simulation.rs` (add cluster_ids, cluster_strength, center_mode to ForceParams; call force_cluster in tick)

**Step 1: Write failing test for cluster force**

In `graph-engine/src/forces.rs` tests:

```rust
#[test]
fn cluster_force_pulls_toward_centroid() {
    // Two clusters: nodes 0,1 in cluster 0 at left; nodes 2,3 in cluster 1 at right.
    let x = vec![-100.0, -80.0, 80.0, 100.0];
    let y = vec![0.0, 20.0, 0.0, 20.0];
    let mut vx = vec![0.0; 4];
    let mut vy = vec![0.0; 4];
    let cluster_ids = vec![0u32, 0, 1, 1];

    force_cluster(&x, &y, &mut vx, &mut vy, &cluster_ids, 0.5, 1.0);

    // Node 0 at (-100, 0), centroid of cluster 0 is (-90, 10).
    // Should be pulled rightward and downward.
    assert!(vx[0] > 0.0, "node 0 should move right toward centroid");
    assert!(vy[0] > 0.0, "node 0 should move down toward centroid");
}
```

**Step 2: Implement force_cluster**

In `graph-engine/src/forces.rs`, add:

```rust
/// Cluster cohesion force: pulls nodes toward their cluster centroid.
/// Creates "bubble" effect where densely connected groups stick together.
/// `cluster_ids[i]` = cluster index for node i.
/// `strength` = how tightly nodes pull toward cluster center (0 = off, 1 = strong).
pub fn force_cluster(
    x: &[f32],
    y: &[f32],
    vx: &mut [f32],
    vy: &mut [f32],
    cluster_ids: &[u32],
    strength: f32,
    alpha: f32,
) {
    if strength < 0.001 || x.is_empty() { return; }

    let n = x.len();
    if cluster_ids.len() != n { return; }

    // Compute cluster centroids.
    let max_cluster = cluster_ids.iter().copied().max().unwrap_or(0) as usize;
    let mut cx = vec![0.0f32; max_cluster + 1];
    let mut cy = vec![0.0f32; max_cluster + 1];
    let mut counts = vec![0u32; max_cluster + 1];

    for i in 0..n {
        let c = cluster_ids[i] as usize;
        cx[c] += x[i];
        cy[c] += y[i];
        counts[c] += 1;
    }

    for c in 0..=max_cluster {
        if counts[c] > 0 {
            cx[c] /= counts[c] as f32;
            cy[c] /= counts[c] as f32;
        }
    }

    // Pull each node toward its cluster centroid.
    let effective = strength * 0.05 * alpha; // Gentle — 0.05 scaling factor.
    for i in 0..n {
        let c = cluster_ids[i] as usize;
        if counts[c] <= 1 { continue; } // Skip singleton clusters.
        vx[i] += (cx[c] - x[i]) * effective;
        vy[i] += (cy[c] - y[i]) * effective;
    }
}
```

**Step 3: Add center_mode enum and cluster fields to ForceParams**

In `graph-engine/src/simulation.rs`, add:

```rust
/// Center force mode: attract toward center, repel from center, or off.
#[derive(Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum CenterMode {
    Attract = 0,
    Off = 1,
    Repel = 2,
}

impl CenterMode {
    pub fn from_u8(v: u8) -> Self {
        match v {
            1 => Self::Off,
            2 => Self::Repel,
            _ => Self::Attract,
        }
    }
}
```

Add to `ForceParams`:

```rust
pub cluster_strength: f32,   // 0-1, default 0.0 (off)
pub center_mode: CenterMode, // default Attract
```

Default: `cluster_strength: 0.0, center_mode: CenterMode::Attract`.

Add to `Simulation`:

```rust
pub cluster_ids: Vec<u32>,
```

Initialize as empty in `Simulation::new()`.

**Step 4: Integrate into simulation tick**

In `Simulation::tick()`, after the center force and before orbital drift, add:

```rust
// Cluster cohesion force.
if self.params.cluster_strength > 0.001 && !self.cluster_ids.is_empty() {
    forces::force_cluster(
        &self.x, &self.y, &mut self.vx, &mut self.vy,
        &self.cluster_ids, self.params.cluster_strength, alpha,
    );
}
```

For center force, modify to respect center_mode:

```rust
let center_str = match self.params.center_mode {
    CenterMode::Attract => self.params.center_strength,
    CenterMode::Off => 0.0,
    CenterMode::Repel => -self.params.center_strength,
};
if center_str.abs() > 0.0001 {
    forces::force_center(
        &self.x, &self.y, &mut self.vx, &mut self.vy,
        cx, cy, center_str, alpha,
    );
}
```

**Step 5: Run cluster detection on commit**

In `graph-engine/src/engine.rs`, in the `commit()` method, after `sim.load_from_graph(&self.graph)`, add:

```rust
// Detect communities for cluster force.
let cluster_ids = crate::cluster::detect_communities(sim.x.len(), &sim.edges);
sim.cluster_ids = cluster_ids;
```

**Step 6: Run all tests**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test`
Expected: ALL PASS.

**Step 7: Commit**

```bash
git add graph-engine/src/forces.rs graph-engine/src/simulation.rs graph-engine/src/engine.rs
git commit -m "feat: add cluster cohesion force with Louvain detection + center mode"
```

---

## Task 7: Cluster + Center Mode FFI Bridge and Settings UI

**Files:**
- Modify: `graph-engine/src/engine.rs` (add set_cluster_params, set_center_mode)
- Modify: `graph-engine/src/lib.rs` (add FFI functions)
- Modify: `graph-engine-bridge/graph_engine.h` (add C declarations)
- Modify: `Epistemos/Graph/GraphState.swift` (add cluster/center properties)
- Modify: `Epistemos/Views/Graph/GraphForceSettings.swift` (add Cluster section + Center Mode picker)
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift` (push cluster params)

**Step 1: Add Rust-side methods**

In `graph-engine/src/engine.rs`:

```rust
pub fn set_cluster_params(&mut self, cluster_strength: f32) {
    let mut sim = self.sim.lock();
    sim.params.cluster_strength = cluster_strength;
    sim.reheat();
}

pub fn set_center_mode(&mut self, mode: u8) {
    let mut sim = self.sim.lock();
    sim.params.center_mode = crate::simulation::CenterMode::from_u8(mode);
    sim.reheat();
}
```

**Step 2: Add FFI functions**

In `graph-engine/src/lib.rs`:

```rust
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_cluster_params(engine: *mut Engine, cluster_strength: f32) {
    let engine = unsafe { &mut *engine };
    engine.set_cluster_params(cluster_strength);
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_center_mode(engine: *mut Engine, mode: u8) {
    let engine = unsafe { &mut *engine };
    engine.set_center_mode(mode);
}
```

**Step 3: Add C declarations**

In `graph-engine-bridge/graph_engine.h`:

```c
/// Set cluster cohesion strength (0 = off, 1 = strong bubbles).
void graph_engine_set_cluster_params(Engine* engine, float cluster_strength);

/// Set center force mode: 0 = attract, 1 = off, 2 = repel.
void graph_engine_set_center_mode(Engine* engine, uint8_t mode);
```

**Step 4: Add Swift properties and settings UI**

In `Epistemos/Graph/GraphState.swift`:

```swift
// ── Cluster ──
var clusterStrength: Float = 0.0
var centerMode: UInt8 = 0  // 0=attract, 1=off, 2=repel

var clusterConfigVersion: Int = 0
func pushClusterChange() { clusterConfigVersion += 1 }
```

In `Epistemos/Views/Graph/GraphForceSettings.swift`, add cluster section in the advanced area:

```swift
Divider().opacity(0.2)
sectionHeader("Clustering", icon: "circle.grid.3x3")

forceSlider(
    label: "Cluster Bubbles",
    value: gs.clusterStrength,
    range: 0...1,
    format: "%.2f",
    subtitle: "Groups connected nodes together",
    onChange: { graphState.pushClusterChange() }
)

HStack {
    Text("Center Force")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
    Spacer()
    Picker("", selection: gs.centerMode) {
        Text("Attract").tag(UInt8(0))
        Text("Off").tag(UInt8(1))
        Text("Repel").tag(UInt8(2))
    }
    .pickerStyle(.segmented)
    .frame(width: 180)
    .onChange(of: graphState.centerMode) { graphState.pushClusterChange() }
}
```

**Step 5: Push from MetalGraphView**

In `MetalGraphView.swift`:

```swift
var lastClusterConfigVersion: Int = 0

func pushClusterParams() {
    guard let engine, let graphState else { return }
    graph_engine_set_cluster_params(engine, graphState.clusterStrength)
    graph_engine_set_center_mode(engine, graphState.centerMode)
}
```

In `renderFrame()`:

```swift
if let graphState, lastClusterConfigVersion != graphState.clusterConfigVersion {
    lastClusterConfigVersion = graphState.clusterConfigVersion
    pushClusterParams()
}
```

**Step 6: Run all tests**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test`
Run: `cd /Users/jojo/Epistemos && xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests 2>&1 | tail -30`
Expected: ALL PASS.

**Step 7: Commit**

```bash
git add graph-engine/src/engine.rs graph-engine/src/lib.rs graph-engine-bridge/graph_engine.h \
  Epistemos/Graph/GraphState.swift Epistemos/Views/Graph/GraphForceSettings.swift \
  Epistemos/Views/Graph/MetalGraphView.swift
git commit -m "feat: cluster settings UI with center mode toggle (attract/off/repel)"
```

---

## Task 8: Cursor Attractor Force

**Files:**
- Modify: `graph-engine/src/forces.rs` (add force_attract)
- Modify: `graph-engine/src/simulation.rs` (add attract fields)
- Modify: `graph-engine/src/engine.rs` (add attract methods, wire into tick)
- Modify: `graph-engine/src/lib.rs` (add FFI functions)
- Modify: `graph-engine-bridge/graph_engine.h` (add C declarations)

**Step 1: Write failing test for attract force**

In `graph-engine/src/forces.rs` tests:

```rust
#[test]
fn attract_pulls_selected_nodes_toward_target() {
    let x = vec![0.0, 100.0, 200.0];
    let y = vec![0.0, 0.0, 0.0];
    let mut vx = vec![0.0; 3];
    let mut vy = vec![0.0; 3];
    let attracted = vec![true, false, true]; // Only nodes 0 and 2.

    force_attract(&x, &y, &mut vx, &mut vy, &attracted, 50.0, 50.0, 0.5, 1.0);

    // Node 0: at (0,0), target at (50,50) → should move rightward and downward.
    assert!(vx[0] > 0.0, "attracted node 0 should move toward target x");
    assert!(vy[0] > 0.0, "attracted node 0 should move toward target y");
    // Node 1: not attracted → should not move.
    assert_eq!(vx[1], 0.0, "non-attracted node 1 should not move");
    // Node 2: at (200,0), target at (50,50) → should move leftward.
    assert!(vx[2] < 0.0, "attracted node 2 should move toward target x");
}
```

**Step 2: Implement force_attract**

```rust
/// Cursor attractor force: pulls selected nodes toward a target point.
/// `attracted[i]` = whether node i should be attracted.
/// Strength falls off with distance to prevent yanking from far away.
pub fn force_attract(
    x: &[f32],
    y: &[f32],
    vx: &mut [f32],
    vy: &mut [f32],
    attracted: &[bool],
    target_x: f32,
    target_y: f32,
    strength: f32,
    alpha: f32,
) {
    if strength < 0.001 { return; }
    let n = x.len();
    if attracted.len() != n { return; }

    let effective = strength * 0.1 * alpha;
    for i in 0..n {
        if !attracted[i] { continue; }
        let dx = target_x - x[i];
        let dy = target_y - y[i];
        let dist = (dx * dx + dy * dy).sqrt().max(1.0);
        // Falloff: force decreases at long range.
        let falloff = 1.0 / (1.0 + dist * 0.002);
        vx[i] += dx / dist * effective * falloff * dist.min(200.0);
        vy[i] += dy / dist * effective * falloff * dist.min(200.0);
    }
}
```

**Step 3: Add attract state to Simulation**

In `graph-engine/src/simulation.rs`, add to `Simulation`:

```rust
pub attract_target: Option<[f32; 2]>,
pub attracted_nodes: Vec<bool>,  // per simulation-index
pub attract_strength: f32,
```

Initialize: `attract_target: None, attracted_nodes: Vec::new(), attract_strength: 0.5`.

In `tick()`, after cluster force:

```rust
// Attractor force.
if let Some([tx, ty]) = self.attract_target {
    if !self.attracted_nodes.is_empty() {
        forces::force_attract(
            &self.x, &self.y, &mut self.vx, &mut self.vy,
            &self.attracted_nodes, tx, ty, self.attract_strength, alpha,
        );
    }
}
```

**Step 4: Add Engine methods + FFI**

In `graph-engine/src/engine.rs`:

```rust
pub fn set_attract_target(&mut self, x: f32, y: f32) {
    let mut sim = self.sim.lock();
    sim.attract_target = Some([x, y]);
    if sim.is_settled { sim.reheat(); }
}

pub fn set_attracted_nodes(&mut self, uuids: &[&str]) {
    let mut sim = self.sim.lock();
    sim.attracted_nodes = vec![false; sim.x.len()];
    for uuid in uuids {
        if let Some(&id) = self.graph.uuid_to_id.get(*uuid) {
            if let Some(&gi) = self.graph.id_to_index.get(&id) {
                // Find sim index for this graph index.
                if let Some(si) = sim.graph_indices.iter().position(|&g| g == gi) {
                    sim.attracted_nodes[si] = true;
                }
            }
        }
    }
}

pub fn clear_attract(&mut self) {
    let mut sim = self.sim.lock();
    sim.attract_target = None;
    sim.attracted_nodes.clear();
}

pub fn set_attract_strength(&mut self, strength: f32) {
    let mut sim = self.sim.lock();
    sim.attract_strength = strength;
}
```

In `graph-engine/src/lib.rs`:

```rust
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_attract_target(engine: *mut Engine, x: f32, y: f32) {
    let engine = unsafe { &mut *engine };
    engine.set_attract_target(x, y);
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_attracted_nodes(
    engine: *mut Engine, uuids: *const *const c_char, count: u32,
) {
    let engine = unsafe { &mut *engine };
    let uuid_strs: Vec<&str> = (0..count as usize)
        .filter_map(|i| unsafe { CStr::from_ptr(*uuids.add(i)).to_str().ok() })
        .collect();
    engine.set_attracted_nodes(&uuid_strs);
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_clear_attract(engine: *mut Engine) {
    let engine = unsafe { &mut *engine };
    engine.clear_attract();
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_attract_strength(engine: *mut Engine, strength: f32) {
    let engine = unsafe { &mut *engine };
    engine.set_attract_strength(strength);
}
```

In `graph-engine-bridge/graph_engine.h`:

```c
/// Set the attractor target point in world coordinates.
void graph_engine_set_attract_target(Engine* engine, float x, float y);

/// Set which nodes are attracted (by UUID array).
void graph_engine_set_attracted_nodes(Engine* engine, const char** uuids, uint32_t count);

/// Clear the attractor (disable).
void graph_engine_clear_attract(Engine* engine);

/// Set attractor force strength (0-1).
void graph_engine_set_attract_strength(Engine* engine, float strength);
```

**Step 5: Run all tests**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test`
Expected: ALL PASS.

**Step 6: Commit**

```bash
git add graph-engine/src/forces.rs graph-engine/src/simulation.rs graph-engine/src/engine.rs \
  graph-engine/src/lib.rs graph-engine-bridge/graph_engine.h
git commit -m "feat: add cursor attractor force with FFI bridge"
```

---

## Task 9: Attractor Swift UI — Search + Manual Mode

**Files:**
- Modify: `Epistemos/Graph/GraphState.swift` (add attractor state)
- Modify: `Epistemos/Views/Graph/GraphFloatingControls.swift` (add attract input)
- Modify: `Epistemos/Views/Graph/GraphForceSettings.swift` (add attract strength slider)
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift` (forward mouse position for attract)

**Step 1: Add attractor state to GraphState**

```swift
// ── Attractor ──
enum AttractMode: String, CaseIterable {
    case off = "Off"
    case ai = "AI"
    case manual = "Manual"
}

var attractMode: AttractMode = .off
var attractQuery: String = ""
var attractStrength: Float = 0.5
var attractedNodeIds: [String] = []
```

**Step 2: Add attract search input to GraphFloatingControls**

Add a compact search field in the floating controls bar. When the user types a concept, use `SearchIndexService` (FTS5) to find matching node labels, and send the matching UUIDs to the Rust engine.

**Step 3: Forward mouse position for attractor**

In `MetalGraphView.swift`'s `mouseMoved(with:)`, when attract mode is active, convert screen coords to world coords and call `graph_engine_set_attract_target`.

Since world coord conversion requires the camera state (which is in Rust), add an FFI function `graph_engine_screen_to_world` or replicate the math in Swift:

```swift
func screenToWorld(_ screenPt: CGPoint) -> (Float, Float) {
    guard let graphState else { return (0, 0) }
    let scale = metalLayer?.contentsScale ?? 2.0
    let sx = Float(screenPt.x * scale)
    let sy = Float((bounds.height - screenPt.y) * scale)
    let w = Float(bounds.width * scale)
    let h = Float(bounds.height * scale)
    // This replicates the Rust engine's screen_to_world.
    // But we need camera_offset and camera_zoom from the engine...
    // For now, pass screen coords to a new FFI function.
    return (sx, sy)
}
```

Actually, the simplest approach: pass the screen coordinates to a new FFI function that does the conversion internally:

```rust
// In engine.rs:
pub fn set_attract_target_screen(&mut self, screen_x: f32, screen_y: f32) {
    let (wx, wy) = self.screen_to_world(screen_x, screen_y);
    self.set_attract_target(wx, wy);
}
```

Add corresponding FFI:

```rust
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_attract_target_screen(engine: *mut Engine, sx: f32, sy: f32) {
    let engine = unsafe { &mut *engine };
    engine.set_attract_target_screen(sx, sy);
}
```

**Step 4: Run all tests**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test`
Run: `cd /Users/jojo/Epistemos && xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests 2>&1 | tail -30`
Expected: ALL PASS.

**Step 5: Commit**

```bash
git add Epistemos/Graph/GraphState.swift Epistemos/Views/Graph/GraphFloatingControls.swift \
  Epistemos/Views/Graph/GraphForceSettings.swift Epistemos/Views/Graph/MetalGraphView.swift \
  graph-engine/src/engine.rs graph-engine/src/lib.rs graph-engine-bridge/graph_engine.h
git commit -m "feat: attractor UI with AI search + manual mode"
```

---

## Task 10: Fix Chat Glitch on Node Inspector

**Files:**
- Modify: `Epistemos/Views/Graph/NodeInspectorState.swift` (fix state ordering)
- Modify: `Epistemos/Views/Graph/HologramNodeInspector.swift` (fix missing else, add placeholder)

**Step 1: Fix state ordering in NodeInspectorState.selectNode**

In `Epistemos/Views/Graph/NodeInspectorState.swift`, modify `selectNode()`:

```swift
func selectNode(_ node: GraphNodeRecord?, store: GraphStore, modelContext: ModelContext) {
    guard let node, node.id != selectedNodeId else {
        if node == nil { clearSelection() }
        return
    }

    // Set loading state BEFORE setting selectedNode —
    // this ensures the spinner is ready when the panel animates in.
    isSummarizing = true
    chatMessages = []
    chatInput = ""
    isChatStreaming = false

    // Now set selection (triggers panel animation).
    selectedNodeId = node.id
    selectedNode = node
    summaryText = ""

    summarizeNode(node, store: store, modelContext: modelContext)
}
```

The key change: `isSummarizing = true` is set BEFORE `selectedNode`, so when SwiftUI evaluates the panel transition, the spinner is already ready.

**Step 2: Fix missing else branch in HologramNodeInspector**

In `Epistemos/Views/Graph/HologramNodeInspector.swift`, modify the summary section:

```swift
private var summarySection: some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Label("Summary", systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if inspectorState.isSummarizing {
                ProgressView()
                    .controlSize(.mini)
            }
        }

        if inspectorState.summaryText.isEmpty {
            // Always show spinner when no text yet (covers both
            // "summarizing" and the brief gap before summarization starts).
            if inspectorState.isSummarizing {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 40)
            } else {
                Text("No summary available.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
        } else {
            ScrollView {
                Text(inspectorState.summaryText)
                    .font(.callout)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .transaction { $0.animation = nil } // Prevent layout jumps during streaming
            }
        }
    }
    .padding(16)
    .frame(maxHeight: 180)
}
```

**Step 3: Run Swift tests**

Run: `cd /Users/jojo/Epistemos && xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests 2>&1 | tail -30`
Expected: ALL PASS.

**Step 4: Commit**

```bash
git add Epistemos/Views/Graph/NodeInspectorState.swift Epistemos/Views/Graph/HologramNodeInspector.swift
git commit -m "fix: chat inspector glitch — pre-set loading state before panel animation"
```

---

## Task 11: Final Test Run — Comprehensive Verification

**Files:** All modified files from Tasks 1-10.

**Step 1: Run all Rust tests**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test 2>&1`
Expected: ALL PASS (88+ existing tests + ~15 new tests).

**Step 2: Run all Swift tests**

Run: `cd /Users/jojo/Epistemos && xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests 2>&1 | tail -50`
Expected: ALL PASS (165+ tests).

**Step 3: Build release to verify compilation**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo build --release 2>&1`
Expected: Compiles cleanly with no warnings.

Run: `cd /Users/jojo/Epistemos && xcodebuild build -project Epistemos.xcodeproj -scheme Epistemos -configuration Release -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED.

**Step 4: Commit any test fixes**

If any tests failed, fix them and create a separate commit for each fix.

**Step 5: Final commit message**

```bash
git add -A
git commit -m "test: verify all tests pass after graph engine v2 features"
```
