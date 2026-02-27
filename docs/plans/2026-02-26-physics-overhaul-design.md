# Obsidian-Style Physics Overhaul — Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Make heavy/connected nodes create "force fields" that naturally space the graph, prevent overlapping, and produce Obsidian-style clustering.

**Architecture:** Three targeted changes to `physics.rs` — radius-aware repulsion, collision resolution, and degree-boosted mass. No new files, no FFI changes, no Swift changes.

**Tech Stack:** Rust (physics.rs, types.rs changes only)

---

## Context

The current physics engine uses Barnes-Hut quad tree repulsion with Verlet integration. However, all nodes are treated as dimensionless points — their visual radius is ignored by the simulation. This causes:
- Small tags overlapping large folder nodes
- Hub nodes (many connections) not claiming enough space
- No collision prevention → visual mess at high density

Obsidian solves this with radius-proportional repulsion zones and overlap resolution.

---

## Task 1: Add Radii to PhysicsState

**Files to modify:**
- `graph-engine/src/physics.rs` — add `radii: Vec<f32>` field
- `graph-engine/src/physics.rs` — populate in `load_from_graph()` and `load_from_graph_filtered()`

**Changes:**

1. Add `pub radii: Vec<f32>` to `PhysicsState` struct (after `masses`)
2. Initialize in `PhysicsState::new()`: `radii: Vec::new()`
3. In `load_from_graph()`: push `node.radius` for each node, add `radii.clear()` + `radii.reserve(n)`
4. In `load_from_graph_filtered()`: same, push `node.radius` for visible nodes only
5. Update `make_verlet_state` test helper to include `radii: vec![8.0; n]`

**Tests:**
- `radii_loaded_from_graph` — verify radii match node radius values after load

---

## Task 2: Radius-Aware Repulsion ("Force Fields")

**Files to modify:**
- `graph-engine/src/physics.rs` — modify `QTNode::compute_force()` and repulsion loop in `tick()`

**Design:**

The current repulsion is: `F = repulsion * mass / dist²`

New repulsion with radius awareness:
```
effective_dist = max(dist - radius_a - radius_b, MIN_GAP)
F = repulsion * mass / effective_dist²
```

Where `MIN_GAP = 1.0` prevents division by zero. This means:
- Two nodes that visually touch (dist = radius_a + radius_b) get maximum repulsion
- Large nodes naturally push further because their combined radii is larger
- The "force field" boundary is exactly the visual edge of each node

**Implementation approach:**

The Barnes-Hut tree approximation makes per-pair radius difficult (it aggregates nodes). Two options:

**Option A — Radius in leaf force only:** When `compute_force` hits a leaf node (single body), subtract the sum of radii. When it uses the far-field approximation (center of mass of a cluster), use the querying node's radius as a soft offset. This preserves O(n log n) while getting 90% of the benefit.

**Option B — Hybrid:** Use Barnes-Hut for far-field repulsion (unchanged), but add a separate close-range collision pass (Task 3) that handles radius-aware separation for nearby nodes. This is cleaner separation of concerns.

**Chosen: Option B** — keep Barnes-Hut repulsion simple, add collision pass for close-range radius awareness. This is cleaner and the collision pass handles overlap more reliably than force-based separation.

However, we still enhance Barnes-Hut with a radius offset for the querying node's leaf interactions:

In `tick()` step 3, change the repulsion loop:
```rust
// Pass this node's radius so leaf-level forces account for visual size
accelerations[i] += tree.compute_force(
    self.positions[i],
    self.radii[i],    // NEW: this node's radius
    self.config.repulsion
) / self.masses[i];
```

In `QTNode::compute_force()`, add radius parameter:
```rust
fn compute_force(&self, pos: Vec2, radius: f32, repulsion: f32) -> Vec2 {
    // ... existing far-field check ...

    // For leaf nodes, account for visual radius
    let effective_dist = (dist - radius).max(1.0);
    let force_mag = repulsion * self.total_mass / (effective_dist * effective_dist);
    // ...
}
```

**Tests:**
- `large_node_repels_more` — node with radius 22 pushes further than radius 8

---

## Task 3: Collision Resolution Pass

**Files to modify:**
- `graph-engine/src/physics.rs` — add collision step after Verlet integration in `tick()`

**Design:**

After step 7 (Verlet integration), add step 7.5:

```rust
// ── 7.5. Collision resolution — prevent visual overlap ──────────
let min_gap = 4.0; // Minimum gap between node edges in world units
for i in 0..n {
    for j in (i+1)..n {
        let diff = self.positions[j] - self.positions[i];
        let dist = diff.length();
        let min_dist = self.radii[i] + self.radii[j] + min_gap;
        if dist < min_dist && dist > 0.001 {
            let overlap = (min_dist - dist) * 0.5;
            let push = diff.normalize_or_zero() * overlap;
            self.positions[i] -= push;
            self.positions[j] += push;
        }
    }
}
```

**Performance note:** This is O(n²) which is acceptable for n < 500 (our target). For larger graphs, we'd use the quad tree for neighbor queries, but YAGNI for now.

**Optimization:** Only run collision pass when `alpha > 0.01` (active simulation). Once settled, nodes shouldn't overlap.

**Tests:**
- `overlapping_nodes_separated` — two nodes at same position with radius 10 → moved apart to distance ≥ 20+gap
- `non_overlapping_nodes_unchanged` — two far-apart nodes unaffected by collision pass

---

## Task 4: Degree-Boosted Mass

**Files to modify:**
- `graph-engine/src/physics.rs` — boost mass after edge loading in `load_from_graph()` and `load_from_graph_filtered()`

**Design:**

After loading edges, count degree per node and boost mass:
```rust
// Boost mass based on connectivity (hub nodes claim more space)
let mut degree = vec![0u32; self.positions.len()];
for &(src, tgt, _) in &self.edges {
    degree[src as usize] += 1;
    degree[tgt as usize] += 1;
}
for i in 0..self.masses.len() {
    self.masses[i] *= 1.0 + (degree[i] as f32).sqrt() * 0.3;
}
```

A node with 25 connections gets mass × 2.5 (1 + sqrt(25) × 0.3). This naturally makes hub nodes "heavier" — they resist being pushed around and create larger exclusion zones via the repulsion formula.

**Tests:**
- `hub_node_has_boosted_mass` — node with 10 edges has higher mass than isolated node
- `degree_boost_increases_spacing` — hub node pushes neighbors further after several ticks

---

## Task 5: Tune Default Parameters

**Files to modify:**
- `graph-engine/src/physics.rs` — update `ForceConfig::default()`
- `Epistemos/Views/Graph/GraphPhysicsSettings.swift` — sync Swift defaults + adjust slider ranges

**Design:**

Current mismatch: Rust defaults (repulsion=2500) vs Swift defaults (repulsion=600). The Swift values always override. Sync them to good Obsidian-style values:

```
center_strength: 0.003     // Slightly stronger to prevent drift
repulsion: 800.0           // Lower base (radius-aware repulsion does the heavy lifting now)
attraction: 0.010          // Slightly weaker springs
link_distance: 150.0       // Tighter base distance (radii provide extra spacing)
damping: 0.85              // Keep existing
velocity_decay: 0.55       // Keep existing
alpha_decay: 0.012         // Slightly slower settling for smoother animation
```

Update Swift `resetToDefaults()` and initial values to match.

Adjust slider ranges:
- Repel Force: `0...2000` → `0...3000` (radius-aware repulsion is more effective at lower values)

**Tests:**
- Existing tests still pass with new defaults

---

## Verification

1. `cargo test` — all existing tests + ~6 new tests pass
2. `cargo build --release` — clean
3. `xcodebuild -scheme Epistemos build` — clean
4. **Visual:** Run app, verify:
   - Large nodes (folders, concepts with many connections) have visible "breathing room"
   - Small nodes don't overlap large ones
   - Connected clusters naturally group together
   - Hub nodes (tags with many connections) sit at center of their cluster
5. **Interaction:** Drag a hub node — neighbors follow but maintain spacing
6. **Performance:** 500 nodes still at 60fps (collision is O(n²) but n≤500 → 125K ops, trivial at 120Hz)

---

## Key Files Reference

| File | Role |
|------|------|
| `graph-engine/src/physics.rs` | **PRIMARY** — all physics changes |
| `graph-engine/src/types.rs` | Node struct (radius, weight) — read only |
| `Epistemos/Views/Graph/GraphPhysicsSettings.swift` | Sync defaults + slider ranges |
