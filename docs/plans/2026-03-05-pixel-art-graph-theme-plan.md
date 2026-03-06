# Pixel Art Graph Theme + ECS Refactor — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebuild the graph engine as an ECS for 100K+ node performance, then add a pixel art "Voxel Pixel" theme with two-pass rendering, square blocks with pixel glare, and jagged edges.

**Architecture:** Foundation-first ECS refactor. Port all existing graph data to SoA (Structure of Arrays) layout with spatial hash grid for O(n) neighbor queries. Then build two-pass pixel art renderer alongside adapted classic renderer, both reading from the same ECS World. Theme selection via FFI + SwiftUI toolbar toggle.

**Tech Stack:** Rust (2024 edition), Metal (via `metal` crate 0.31), `rustc-hash` for FxHashMap, `parking_lot` for threading. No new dependencies needed.

**Design Doc:** `docs/plans/2026-03-05-pixel-art-graph-theme-design.md`

---

## Phase 1: ECS Foundation

### Task 1.1: Create ECS Module with Component Types

**Files:**
- Create: `graph-engine/src/ecs/mod.rs`
- Create: `graph-engine/src/ecs/components.rs`
- Modify: `graph-engine/src/lib.rs` (add `mod ecs;`)

**Step 1: Write failing test for component creation**

In `graph-engine/src/ecs/mod.rs`:
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_world_add_entity() {
        let mut world = World::new();
        let e = world.spawn(TransformComponent { x: 1.0, y: 2.0, scale: 1.0 });
        assert_eq!(world.entities.len(), 1);
        assert_eq!(world.transform[e as usize].x, 1.0);
    }

    #[test]
    fn test_world_remove_entity() {
        let mut world = World::new();
        let e1 = world.spawn(TransformComponent { x: 1.0, y: 2.0, scale: 1.0 });
        let e2 = world.spawn(TransformComponent { x: 3.0, y: 4.0, scale: 1.0 });
        world.despawn(e1);
        assert_eq!(world.entities.len(), 1);
        assert_eq!(world.transform[0].x, 3.0);
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test test_world_add_entity -- --nocapture`
Expected: FAIL — module not found

**Step 3: Create component types**

In `graph-engine/src/ecs/components.rs`:
```rust
/// All components use #[repr(C)] for FFI compatibility with Metal shaders.

#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
pub struct TransformComponent {
    pub x: f32,
    pub y: f32,
    pub scale: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
pub struct VelocityComponent {
    pub vx: f32,
    pub vy: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct HierarchyComponent {
    pub depth: u32,
    pub parent: u32,       // u32::MAX = no parent
    pub node_type: u8,
    pub link_count: u32,
}

impl Default for HierarchyComponent {
    fn default() -> Self {
        Self { depth: 0, parent: u32::MAX, node_type: 0, link_count: 0 }
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum BlockType {
    Core = 0,      // Folder — 16px, red, full glare
    Primary = 1,   // Note — 12px, black/white, subtle glare
    Secondary = 2, // Source, Idea — 10px, dark gray
    Tertiary = 3,  // Chat, Quote — 8px, medium gray
    Leaf = 4,      // Tag, Block — 6px, teal/light gray
}

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct RenderComponent {
    pub block_type: u8,
    pub color_override: [f32; 4],  // [0,0,0,0] = use default
    pub has_glare: bool,
}

impl Default for RenderComponent {
    fn default() -> Self {
        Self { block_type: BlockType::Primary as u8, color_override: [0.0; 4], has_glare: false }
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum AIState {
    Idle = 0,
    Swimming = 1,
    AvoidingCursor = 2,
    TrailingParent = 3,
    Excited = 4,
    Sleeping = 5,
}

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct AIComponent {
    pub state: u8,
    pub personality_seed: u32,
    pub breath_phase: f32,
    pub breath_freq: f32,
    pub wander_radius: f32,
    pub speed: f32,
}

impl Default for AIComponent {
    fn default() -> Self {
        Self {
            state: AIState::Idle as u8,
            personality_seed: 0,
            breath_phase: 0.0,
            breath_freq: 0.5,
            wander_radius: 5.0,
            speed: 1.0,
        }
    }
}
```

**Step 4: Create World struct with SoA storage**

In `graph-engine/src/ecs/mod.rs`:
```rust
pub mod components;

use rustc_hash::FxHashMap;
pub use components::*;

pub type Entity = u32;

pub struct World {
    // Identity
    pub entities: Vec<Entity>,
    pub entity_to_index: FxHashMap<u32, usize>,
    next_entity_id: u32,

    // SoA components
    pub transform: Vec<TransformComponent>,
    pub velocity: Vec<VelocityComponent>,
    pub hierarchy: Vec<HierarchyComponent>,
    pub render: Vec<RenderComponent>,
    pub ai: Vec<AIComponent>,
}

impl World {
    pub fn new() -> Self {
        Self {
            entities: Vec::new(),
            entity_to_index: FxHashMap::default(),
            next_entity_id: 0,
            transform: Vec::new(),
            velocity: Vec::new(),
            hierarchy: Vec::new(),
            render: Vec::new(),
            ai: Vec::new(),
        }
    }

    pub fn with_capacity(cap: usize) -> Self {
        Self {
            entities: Vec::with_capacity(cap),
            entity_to_index: FxHashMap::with_capacity_and_hasher(cap, Default::default()),
            next_entity_id: 0,
            transform: Vec::with_capacity(cap),
            velocity: Vec::with_capacity(cap),
            hierarchy: Vec::with_capacity(cap),
            render: Vec::with_capacity(cap),
            ai: Vec::with_capacity(cap),
        }
    }

    /// Spawn a new entity with the given transform. Other components get defaults.
    pub fn spawn(&mut self, transform: TransformComponent) -> Entity {
        let id = self.next_entity_id;
        self.next_entity_id += 1;
        let idx = self.entities.len();
        self.entities.push(id);
        self.entity_to_index.insert(id, idx);
        self.transform.push(transform);
        self.velocity.push(VelocityComponent::default());
        self.hierarchy.push(HierarchyComponent::default());
        self.render.push(RenderComponent::default());
        self.ai.push(AIComponent::default());
        id
    }

    /// Remove an entity via swap-remove to maintain contiguous arrays.
    pub fn despawn(&mut self, entity: Entity) {
        if let Some(&idx) = self.entity_to_index.get(&entity) {
            let last = self.entities.len() - 1;
            if idx != last {
                // Swap with last element
                let last_entity = self.entities[last];
                self.entity_to_index.insert(last_entity, idx);
                self.entities.swap(idx, last);
                self.transform.swap(idx, last);
                self.velocity.swap(idx, last);
                self.hierarchy.swap(idx, last);
                self.render.swap(idx, last);
                self.ai.swap(idx, last);
            }
            self.entities.pop();
            self.transform.pop();
            self.velocity.pop();
            self.hierarchy.pop();
            self.render.pop();
            self.ai.pop();
            self.entity_to_index.remove(&entity);
        }
    }

    pub fn len(&self) -> usize {
        self.entities.len()
    }

    pub fn index_of(&self, entity: Entity) -> Option<usize> {
        self.entity_to_index.get(&entity).copied()
    }
}
```

**Step 5: Register module in lib.rs**

Add `pub mod ecs;` to `graph-engine/src/lib.rs`.

**Step 6: Run tests to verify they pass**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test ecs::tests -- --nocapture`
Expected: PASS

**Step 7: Commit**

```bash
cd /Users/jojo/Epistemos
git add graph-engine/src/ecs/
git add graph-engine/src/lib.rs
git commit -m "feat(ecs): add ECS World with SoA component storage

Foundation for pixel art graph theme. Entity = u32, components stored
in contiguous Vec<T> arrays for cache-friendly iteration. Swap-remove
despawn maintains contiguity."
```

---

### Task 1.2: Spatial Hash Grid

**Files:**
- Create: `graph-engine/src/ecs/spatial_grid.rs`
- Modify: `graph-engine/src/ecs/mod.rs` (add module + integrate into World)

**Step 1: Write failing tests**

```rust
#[test]
fn test_spatial_grid_insert_query() {
    let mut grid = SpatialGrid::new(50.0);
    grid.insert(0, 10.0, 10.0);
    grid.insert(1, 15.0, 15.0);
    grid.insert(2, 200.0, 200.0);
    let near = grid.query(12.0, 12.0, 50.0);
    assert!(near.contains(&0));
    assert!(near.contains(&1));
    assert!(!near.contains(&2));
}

#[test]
fn test_spatial_grid_rebuild() {
    let mut grid = SpatialGrid::new(50.0);
    let positions = vec![
        TransformComponent { x: 0.0, y: 0.0, scale: 1.0 },
        TransformComponent { x: 100.0, y: 100.0, scale: 1.0 },
    ];
    grid.rebuild(&positions);
    assert_eq!(grid.query(0.0, 0.0, 10.0).len(), 1);
}
```

**Step 2: Run to verify failure**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test test_spatial_grid -- --nocapture`

**Step 3: Implement SpatialGrid**

In `graph-engine/src/ecs/spatial_grid.rs`:
```rust
use rustc_hash::FxHashMap;
use super::TransformComponent;

pub struct SpatialGrid {
    cell_size: f32,
    inv_cell_size: f32,
    cells: FxHashMap<(i32, i32), Vec<u32>>,
}

impl SpatialGrid {
    pub fn new(cell_size: f32) -> Self {
        Self {
            cell_size,
            inv_cell_size: 1.0 / cell_size,
            cells: FxHashMap::default(),
        }
    }

    fn cell_key(&self, x: f32, y: f32) -> (i32, i32) {
        ((x * self.inv_cell_size).floor() as i32, (y * self.inv_cell_size).floor() as i32)
    }

    pub fn clear(&mut self) {
        for cell in self.cells.values_mut() {
            cell.clear();
        }
    }

    pub fn insert(&mut self, entity: u32, x: f32, y: f32) {
        let key = self.cell_key(x, y);
        self.cells.entry(key).or_insert_with(|| Vec::with_capacity(8)).push(entity);
    }

    pub fn rebuild(&mut self, transforms: &[TransformComponent]) {
        self.clear();
        for (i, t) in transforms.iter().enumerate() {
            self.insert(i as u32, t.x, t.y);
        }
    }

    /// Query all entities within radius of (x, y).
    /// Returns SoA indices, not entity IDs.
    pub fn query(&self, x: f32, y: f32, radius: f32) -> Vec<u32> {
        let r_sq = radius * radius;
        let cells_to_check = (radius * self.inv_cell_size).ceil() as i32;
        let center = self.cell_key(x, y);
        let mut results = Vec::with_capacity(16);

        for dx in -cells_to_check..=cells_to_check {
            for dy in -cells_to_check..=cells_to_check {
                if let Some(cell) = self.cells.get(&(center.0 + dx, center.1 + dy)) {
                    results.extend(cell.iter().copied());
                }
            }
        }
        results
    }

    /// Query neighbors efficiently — only checks ±1 cells (for cell_size = perception_radius).
    pub fn query_neighbors(&self, x: f32, y: f32) -> Vec<u32> {
        let center = self.cell_key(x, y);
        let mut results = Vec::with_capacity(16);
        for dx in -1..=1 {
            for dy in -1..=1 {
                if let Some(cell) = self.cells.get(&(center.0 + dx, center.1 + dy)) {
                    results.extend(cell.iter().copied());
                }
            }
        }
        results
    }
}
```

**Step 4: Add to World and register module**

Add `pub mod spatial_grid;` to `ecs/mod.rs`, add `pub spatial_grid: SpatialGrid` field to World.

**Step 5: Run tests**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test spatial_grid -- --nocapture`
Expected: PASS

**Step 6: Commit**

```bash
git add graph-engine/src/ecs/spatial_grid.rs graph-engine/src/ecs/mod.rs
git commit -m "feat(ecs): add spatial hash grid for O(n) neighbor queries

Cell-based spatial partitioning. Rebuild from transforms each frame.
query_neighbors checks 9 cells (center + 8 adjacent). Enables 100K+
node simulations by replacing O(n²) brute-force distance checks."
```

---

### Task 1.3: Graph-to-ECS Bridge

**Files:**
- Create: `graph-engine/src/ecs/bridge.rs`
- Test: inline in `bridge.rs`

**Purpose:** Convert the existing `Graph` (from `types.rs`) into ECS World format. This is the migration path — existing code populates a `Graph`, bridge converts it to `World`.

**Step 1: Write failing test**

```rust
#[test]
fn test_graph_to_world_conversion() {
    let mut graph = Graph::new();
    // Add two nodes and an edge
    graph.add_node(1, NodeType::Note, "Test Note".to_string(), 0, None, None, None);
    graph.add_node(2, NodeType::Folder, "Test Folder".to_string(), 0, None, None, None);
    graph.add_edge(1, 2, EdgeType::Reference);

    let world = World::from_graph(&graph);
    assert_eq!(world.len(), 2);
    // Folder should be BlockType::Core, Note should be BlockType::Primary
}
```

**Step 2: Implement `World::from_graph()`**

Maps NodeType to BlockType:
- `Folder` → `Core` (has_glare = true)
- `Note` → `Primary` (has_glare = true, subtle)
- `Source | Idea` → `Secondary`
- `Chat | Quote` → `Tertiary`
- `Tag | Block` → `Leaf`

Copies positions from existing `Simulation` data if available, otherwise random placement.

**Step 3: Test, then commit**

```bash
git commit -m "feat(ecs): add Graph → World bridge for ECS migration"
```

---

## Phase 2: Physics Port

### Task 2.1: ECS-Compatible Force Systems

**Files:**
- Create: `graph-engine/src/ecs/systems.rs`
- Reference: `graph-engine/src/forces.rs` (existing force implementations)
- Reference: `graph-engine/src/simulation.rs` (existing simulation loop)

**Step 1: Write failing test for force application on SoA data**

```rust
#[test]
fn test_repulsion_system() {
    let mut world = World::with_capacity(2);
    world.spawn(TransformComponent { x: 0.0, y: 0.0, scale: 1.0 });
    world.spawn(TransformComponent { x: 5.0, y: 0.0, scale: 1.0 });

    let params = ForceParams::default();
    systems::apply_repulsion(&mut world, &params);

    // Nodes should have been pushed apart
    assert!(world.velocity[0].vx < 0.0);
    assert!(world.velocity[1].vx > 0.0);
}
```

**Step 2: Implement force systems operating on SoA arrays**

Key systems to port from `forces.rs` → `ecs/systems.rs`:
1. `apply_repulsion(world, params)` — charge repulsion using spatial grid
2. `apply_links(world, edges, params)` — link attraction
3. `apply_center(world, params)` — centering force
4. `apply_collision(world, params)` — collision resolution
5. `integrate(world, params, dt)` — velocity Verlet integration

Each system iterates `world.transform` and `world.velocity` directly — no indirection.

**Step 3: Write test for full tick**

```rust
#[test]
fn test_full_tick_produces_stable_layout() {
    let mut world = /* populate with 10 nodes */;
    for _ in 0..100 {
        systems::tick(&mut world, &params, 1.0/60.0);
    }
    // Verify nodes spread out and don't overlap
}
```

**Step 4: Run all tests**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test ecs::systems -- --nocapture`

**Step 5: Commit**

```bash
git commit -m "feat(ecs): port force-directed physics to ECS systems

Repulsion, link attraction, centering, collision, and Verlet integration
operating directly on SoA arrays. Spatial grid for O(n) neighbor queries.
Functionally equivalent to existing Simulation + forces modules."
```

---

### Task 2.2: Replace Simulation with ECS in Engine

**Files:**
- Modify: `graph-engine/src/engine.rs`
- Modify: `graph-engine/src/renderer.rs` (read positions from World)

**Step 1: Add World to Engine**

Add `world: World` field to `Engine`. The existing `sim: Arc<Mutex<Simulation>>` stays temporarily as a compatibility layer.

**Step 2: Wire physics thread to use ECS tick**

Modify the physics thread closure to call `ecs::systems::tick()` on the World instead of `sim.tick()`.

**Step 3: Wire renderer to read from World**

Modify `Renderer::build_node_instances()` and `Renderer::build_edge_instances()` to read from `World.transform` / `World.render` instead of the Simulation's position arrays.

**Step 4: Run full test suite**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test`
Expected: ALL existing tests pass — behavior is identical.

**Step 5: Build Swift project to verify no regressions**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`

**Step 6: Commit**

```bash
git commit -m "refactor(engine): wire Engine to ECS World for physics + rendering

Physics thread now ticks ECS systems. Renderer reads from World SoA arrays.
Old Simulation stays as compatibility layer until fully removed."
```

---

### Task 2.3: Remove Old Simulation Layer

**Files:**
- Modify: `graph-engine/src/engine.rs` (remove `sim: Arc<Mutex<Simulation>>`)
- May modify: `graph-engine/src/lib.rs` (update FFI functions)

**Step 1: Remove Simulation from Engine, redirect all reads to World**

**Step 2: Run full test suite + build**

Run: `cargo test && xcodebuild build`

**Step 3: Commit**

```bash
git commit -m "refactor(engine): remove old Simulation, ECS World is sole data source"
```

---

## Phase 3: Pixel Art Renderer

### Task 3.1: Theme Enum + Palette Types

**Files:**
- Modify: `graph-engine/src/types.rs`
- Modify: `graph-engine/src/ecs/components.rs`

**Step 1: Add Theme enum and VoxelPalette to types.rs**

```rust
#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Theme {
    Classic = 0,
    VoxelPixel = 1,
}

impl Theme {
    pub fn from_u8(v: u8) -> Self {
        match v { 1 => Self::VoxelPixel, _ => Self::Classic }
    }
}

#[derive(Clone, Copy, Debug)]
pub struct VoxelPalette {
    pub background: [f32; 4],
    pub core: [f32; 4],
    pub primary: [f32; 4],
    pub secondary: [f32; 4],
    pub tertiary: [f32; 4],
    pub leaf: [f32; 4],
    pub edge: [f32; 4],
}

impl VoxelPalette {
    pub fn light() -> Self { /* values from design doc */ }
    pub fn dark() -> Self { /* values from design doc */ }
}
```

**Step 2: Test, commit**

```bash
git commit -m "feat(types): add Theme enum and VoxelPalette for pixel art mode"
```

---

### Task 3.2: Two-Pass Rendering Pipeline

**Files:**
- Modify: `graph-engine/src/renderer.rs`

This is the largest single task. The renderer needs:
1. An offscreen `MTLTexture` for low-res rendering
2. A nearest-neighbor `MTLSamplerState`
3. An upscale pipeline (full-screen quad shader)
4. Theme-conditional rendering path

**Step 1: Add offscreen texture and sampler to Renderer**

```rust
// In Renderer struct:
offscreen_texture: Option<metal::Texture>,
offscreen_width: u32,
offscreen_height: u32,
nearest_sampler: Option<metal::SamplerState>,
upscale_pipeline: Option<metal::RenderPipelineState>,
pixel_scale: u8,  // default 8
```

**Step 2: Write offscreen texture creation**

```rust
fn create_offscreen_texture(&mut self, device: &metal::Device, w: u32, h: u32) {
    let desc = metal::TextureDescriptor::new();
    desc.set_width(w as u64);
    desc.set_height(h as u64);
    desc.set_pixel_format(metal::MTLPixelFormat::BGRA8Unorm);
    desc.set_usage(MTLTextureUsage::RenderTarget | MTLTextureUsage::ShaderRead);
    desc.set_storage_mode(metal::MTLStorageMode::Private);
    self.offscreen_texture = Some(device.new_texture(&desc));
    self.offscreen_width = w;
    self.offscreen_height = h;
}
```

**Step 3: Write nearest-neighbor sampler**

```rust
fn create_nearest_sampler(&mut self, device: &metal::Device) {
    let desc = metal::SamplerDescriptor::new();
    desc.set_min_filter(metal::MTLSamplerMinMagFilter::Nearest);
    desc.set_mag_filter(metal::MTLSamplerMinMagFilter::Nearest);
    desc.set_mip_filter(metal::MTLSamplerMipFilter::NotMipmapped);
    self.nearest_sampler = Some(device.new_sampler_state(&desc));
}
```

**Step 4: Write upscale shader (Metal string)**

```metal
// Full-screen quad vertex shader
vertex VertexOut upscale_vertex(uint vid [[vertex_id]]) {
    float2 positions[4] = { {-1,-1}, {1,-1}, {-1,1}, {1,1} };
    float2 uvs[4] = { {0,1}, {1,1}, {0,0}, {1,0} };
    VertexOut out;
    out.position = float4(positions[vid], 0, 1);
    out.uv = uvs[vid];
    return out;
}

// Nearest-neighbor upscale fragment shader
fragment float4 upscale_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> scene [[texture(0)]],
    sampler nearest [[sampler(0)]]
) {
    return scene.sample(nearest, in.uv);
}
```

**Step 5: Modify render() to branch on theme**

```rust
pub fn render(&mut self, ...) {
    match self.theme {
        Theme::Classic => self.render_classic(encoder, ...),
        Theme::VoxelPixel => self.render_voxel(encoder, ...),
    }
}

fn render_voxel(&mut self, ...) {
    // 1. Ensure offscreen texture exists at correct size
    let target_w = viewport_w / self.pixel_scale as u32;
    let target_h = viewport_h / self.pixel_scale as u32;
    if self.offscreen_width != target_w || self.offscreen_height != target_h {
        self.create_offscreen_texture(device, target_w, target_h);
    }

    // 2. Pass 1: Render to offscreen
    //    - Clear to palette.background
    //    - Draw edges (jagged)
    //    - Draw nodes (squares with glare)

    // 3. Pass 2: Upscale to display
    //    - Full-screen quad sampling offscreen with nearest sampler
}
```

**Step 6: Test with cargo test (shader compilation verified separately at runtime)**

Run: `cd /Users/jojo/Epistemos/graph-engine && cargo test`

**Step 7: Commit**

```bash
git commit -m "feat(renderer): add two-pass pixel art rendering pipeline

Offscreen texture at view_size/pixel_scale, nearest-neighbor upscale.
Theme-conditional render path: Classic = direct, VoxelPixel = two-pass."
```

---

### Task 3.3: Pixel Art Node Shader

**Files:**
- Modify: `graph-engine/src/renderer.rs` (add voxel node shader)

**Step 1: Write VoxelNodeInstance struct**

```rust
#[repr(C)]
struct VoxelNodeInstance {
    position: [f32; 2],     // integer-snapped
    size: f32,              // block size in offscreen pixels
    color: [f32; 4],        // base color from palette
    highlight: [f32; 4],    // glare highlight color
    shadow: [f32; 4],       // glare shadow color
    has_glare: u32,         // 1 = render 3-tone glare
}
```

**Step 2: Write voxel node vertex shader (pixel snapping)**

```metal
vertex VertexOut voxel_node_vertex(
    uint vid [[vertex_id]],
    uint iid [[instance_id]],
    constant VoxelNodeInstance* nodes [[buffer(0)]],
    constant Uniforms& u [[buffer(1)]]
) {
    VoxelNodeInstance node = nodes[iid];

    // Quad vertices: 4 corners of the square
    float2 corners[4] = { {-0.5,-0.5}, {0.5,-0.5}, {-0.5,0.5}, {0.5,0.5} };
    float2 local = corners[vid] * node.size;

    // CRITICAL: Snap position to integer grid
    float2 pixel_pos = floor(node.position);

    // Camera transform
    float2 screen = (pixel_pos + local - u.camera_offset) * u.camera_zoom;
    float2 ndc = screen / (u.viewport_size * 0.5) * float2(1, -1);

    VertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.uv = corners[vid] + 0.5;  // 0..1 UV for glare
    return out;
}
```

**Step 3: Write voxel node fragment shader (flat square + 3-tone glare)**

```metal
fragment float4 voxel_node_fragment(
    VertexOut in [[stage_in]],
    constant VoxelNodeInstance& node [[buffer(0)]]
) {
    // No SDF, no AA — the quad IS the pixel boundary
    float4 color = float4(node.color);

    if (node.has_glare) {
        // 3-tone pixel glare
        // Top-left quadrant: highlight
        // Bottom-right quadrant: shadow
        // Center: base color
        float2 uv = in.uv;  // 0..1 across the square

        if (uv.x < 0.3 && uv.y < 0.3) {
            color = float4(node.highlight);     // top-left highlight
        } else if (uv.x > 0.7 && uv.y > 0.7) {
            color = float4(node.shadow);        // bottom-right shadow
        }
        // Else: base color (no change)
    }

    return color;  // 100% opaque, no alpha blending
}
```

**Step 4: Wire up instance buffer building for voxel nodes**

In `build_voxel_node_instances()`, iterate World components and build `VoxelNodeInstance` array:
- Map `BlockType` → size (16, 12, 10, 8, 6)
- Map `BlockType` → palette color (using `VoxelPalette::light()` or `::dark()`)
- Compute highlight = base color + 0.3 luminance, shadow = base color - 0.3 luminance

**Step 5: Test compilation, commit**

```bash
git commit -m "feat(renderer): add pixel art node shader with 3-tone glare

Instanced square quads, integer-snapped positions, hard edges.
3-tone pixel glare: top-left highlight, center base, bottom-right shadow.
No anti-aliasing, no smoothstep — pure pixel art."
```

---

### Task 3.4: Pixel Art Edge Shader (Jagged Lines)

**Files:**
- Modify: `graph-engine/src/renderer.rs`

**Step 1: Write voxel edge fragment shader**

```metal
fragment float4 voxel_edge_fragment(
    FragmentIn in [[stage_in]],
    constant VoxelEdgeUniforms& u [[buffer(0)]]
) {
    // SDF distance to line segment
    float2 pa = in.frag_coord - u.p0;
    float2 ba = u.p1 - u.p0;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float dist = length(pa - ba * h);

    // Angle compensation for uniform thickness
    float angle_factor = abs(dot(normalize(ba), float2(1, 0)));
    float threshold = (u.thickness - 1.0 + angle_factor) * 0.5;

    // HARD binary — pixel ON or OFF. NO smoothstep.
    bool on_line = (dist <= threshold);
    if (!on_line) discard_fragment();

    return u.color;  // 100% opaque
}
```

**Step 2: Add per-frame jitter**

In the Rust code that builds edge instances, add deterministic jitter:
```rust
// Deterministic jitter from edge index + frame count
let jitter_seed = (edge_idx as u32).wrapping_mul(frame_count);
let jx = ((jitter_seed & 0xFF) as f32 / 255.0 - 0.5) * 2.0; // ±1px
let jy = ((jitter_seed >> 8 & 0xFF) as f32 / 255.0 - 0.5) * 2.0;
```

Apply jitter to the midpoint of each edge segment to create living stair-step variance.

**Step 3: Test, commit**

```bash
git commit -m "feat(renderer): add jagged edge shader with per-frame jitter

SDF line segment with hard boolean cutoff — no smoothstep, no AA.
Angle-compensated thickness for uniform perceived weight. Deterministic
1-2px jitter per frame creates 'living' stair-step edges."
```

---

### Task 3.5: Pixel Crawl Prevention

**Files:**
- Modify: `graph-engine/src/renderer.rs` (vertex shader)

**Step 1: Implement velocity-aware snapping**

In the voxel node vertex shader, replace simple `floor()` with slope interpolation:

```metal
// Velocity-aware integer snapping prevents pixel crawl
float2 velocity = node.velocity;
float2 pixel_pos;

if (abs(velocity.x) > abs(velocity.y)) {
    pixel_pos.x = round(node.position.x);
    pixel_pos.y = round(node.position.y + (pixel_pos.x - node.position.x) * velocity.y / velocity.x);
} else {
    pixel_pos.y = round(node.position.y);
    pixel_pos.x = round(node.position.x + (pixel_pos.y - node.position.y) * velocity.x / velocity.y);
}

// Fallback to simple round for stationary nodes
if (length(velocity) < 0.01) {
    pixel_pos = round(node.position);
}
```

**Step 2: Add velocity to VoxelNodeInstance**

Add `velocity: [f32; 2]` field and populate from `World.velocity`.

**Step 3: Test, commit**

```bash
git commit -m "feat(renderer): velocity-aware pixel snapping prevents crawl

Diagonal movement follows consistent stair-step pattern instead of
random jittering. Stationary nodes use simple round() fallback."
```

---

## Phase 4: Classic Renderer Adapter

### Task 4.1: Adapt Classic Renderer to Read from ECS

**Files:**
- Modify: `graph-engine/src/renderer.rs`

**Step 1: Modify `build_node_instances()` to read from World**

Replace reading from `Simulation` positions with reading from `World.transform` + `World.hierarchy` + `World.render`.

**Step 2: Modify `build_edge_instances()` similarly**

**Step 3: Run full test suite + build**

Run: `cargo test && xcodebuild build`
Expected: ALL tests pass, classic rendering looks identical.

**Step 4: Commit**

```bash
git commit -m "refactor(renderer): classic renderer reads from ECS World

Same visual output as before. Instance buffers built from World SoA
components instead of Simulation position arrays."
```

---

## Phase 5: Theme System + UI

### Task 5.1: FFI Bridge for Theme

**Files:**
- Modify: `graph-engine/src/lib.rs`
- Modify: `graph-engine-bridge/graph_engine.h`

**Step 1: Add FFI functions**

In `lib.rs`:
```rust
#[no_mangle]
pub extern "C" fn graph_engine_set_theme(engine: *mut Engine, theme: u8) {
    ffi_engine!(engine).set_theme(Theme::from_u8(theme));
}

#[no_mangle]
pub extern "C" fn graph_engine_set_pixel_scale(engine: *mut Engine, scale: u8) {
    ffi_engine!(engine).set_pixel_scale(scale.max(2).min(16));
}

#[no_mangle]
pub extern "C" fn graph_engine_set_node_type_color(
    engine: *mut Engine, node_type: u8,
    r: f32, g: f32, b: f32, a: f32
) {
    ffi_engine!(engine).set_node_type_color(node_type, [r, g, b, a]);
}
```

In `graph_engine.h`:
```c
void graph_engine_set_theme(Engine* engine, uint8_t theme);
void graph_engine_set_pixel_scale(Engine* engine, uint8_t scale);
void graph_engine_set_node_type_color(Engine* engine, uint8_t node_type,
                                       float r, float g, float b, float a);
```

**Step 2: Implement Engine methods**

```rust
impl Engine {
    pub fn set_theme(&mut self, theme: Theme) {
        self.renderer.theme = theme;
    }
    pub fn set_pixel_scale(&mut self, scale: u8) {
        self.renderer.pixel_scale = scale;
    }
    pub fn set_node_type_color(&mut self, node_type: u8, color: [f32; 4]) {
        self.renderer.node_type_color_overrides[node_type as usize] = Some(color);
    }
}
```

**Step 3: Build to verify FFI compiles**

Run: `xcodebuild build`

**Step 4: Commit**

```bash
git commit -m "feat(ffi): add theme, pixel scale, and node color FFI functions"
```

---

### Task 5.2: Swift Theme Enum + GraphState

**Files:**
- Modify: `Epistemos/Graph/GraphState.swift`
- Modify: `Epistemos/Theme/EpistemosTheme.swift`

**Step 1: Add GraphVisualTheme enum**

In `EpistemosTheme.swift`:
```swift
enum GraphVisualTheme: UInt8, CaseIterable, Codable {
    case classic = 0
    case voxelPixel = 1

    var displayName: String {
        switch self {
        case .classic:    "Classic"
        case .voxelPixel: "Pixel Blocks"
        }
    }
}
```

**Step 2: Add theme properties to GraphState**

```swift
// In GraphState:
var visualTheme: GraphVisualTheme = .classic {
    didSet { themeVersion += 1 }
}
var themeVersion: Int = 0

var pixelScale: UInt8 = 8 {
    didSet { pixelScaleVersion += 1 }
}
var pixelScaleVersion: Int = 0
```

**Step 3: Build**

Run: `xcodebuild build`

**Step 4: Commit**

```bash
git commit -m "feat(swift): add GraphVisualTheme enum and state tracking"
```

---

### Task 5.3: Sync Theme to Rust in Render Loop

**Files:**
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift`

**Step 1: Add version tracking to MetalGraphNSView**

```swift
// In MetalGraphNSView:
private var lastThemeVersion: Int = -1
private var lastPixelScaleVersion: Int = -1
```

**Step 2: Add sync in renderFrame()**

```swift
// In renderFrame():
if lastThemeVersion != graphState.themeVersion {
    lastThemeVersion = graphState.themeVersion
    graph_engine_set_theme(engine, graphState.visualTheme.rawValue)
}
if lastPixelScaleVersion != graphState.pixelScaleVersion {
    lastPixelScaleVersion = graphState.pixelScaleVersion
    graph_engine_set_pixel_scale(engine, graphState.pixelScale)
}
```

**Step 3: Build and test theme toggle**

Run: `xcodebuild build`
Test: Toggle theme in debugger by setting `graphState.visualTheme = .voxelPixel`.

**Step 4: Commit**

```bash
git commit -m "feat(render): sync GraphVisualTheme to Rust via version-tracked FFI"
```

---

### Task 5.4: Theme Toggle UI

**Files:**
- Modify: `Epistemos/Views/Graph/GraphFloatingControls.swift`

**Step 1: Add segmented control for theme**

```swift
// Add alongside existing quality preset controls:
Picker("Theme", selection: Binding(
    get: { graphState.visualTheme },
    set: { graphState.visualTheme = $0 }
)) {
    ForEach(GraphVisualTheme.allCases, id: \.self) { theme in
        Text(theme.displayName).tag(theme)
    }
}
.pickerStyle(.segmented)
```

**Step 2: Add pixel scale slider (visible only in voxel mode)**

```swift
if graphState.visualTheme == .voxelPixel {
    HStack {
        Text("Pixel Scale")
        Slider(value: Binding(
            get: { Double(graphState.pixelScale) },
            set: { graphState.pixelScale = UInt8($0) }
        ), in: 2...16, step: 1)
        Text("\(graphState.pixelScale)")
    }
}
```

**Step 3: Build and test UI**

Run: `xcodebuild build`
Test: Open graph, verify theme toggle appears, verify pixel scale slider shows/hides.

**Step 4: Commit**

```bash
git commit -m "feat(ui): add theme toggle and pixel scale slider to graph toolbar"
```

---

## Phase 6: Polish + Testing

### Task 6.1: Pixel Crawl Tuning

- Adjust velocity threshold for slope interpolation
- Test with slow diagonal movement at various pixel scales
- Verify no shimmering artifacts

### Task 6.2: Edge Jitter Calibration

- Tune jitter magnitude (currently ±1-2px)
- Test at different pixel scales
- Ensure jitter is subtle, not distracting

### Task 6.3: Performance Profiling

Run with increasing node counts:
```bash
# Rust-side timing
cargo test -- --nocapture benchmark_10k_nodes
cargo test -- --nocapture benchmark_50k_nodes
cargo test -- --nocapture benchmark_100k_nodes
```

Verify:
- ECS physics tick < 3ms at 100K nodes
- Instance buffer build < 2ms
- Two-pass render < 5ms
- Total frame < 16ms (60fps)

### Task 6.4: Edge Cases

Test and fix:
- Empty graph (0 nodes, 0 edges)
- Single node, no edges
- Graph with only edges (shouldn't happen but guard)
- Theme toggle during physics animation
- Pixel scale change during animation
- Window resize (offscreen texture must recreate)

### Task 6.5: Comprehensive Test Suite

Write tests covering:
- ECS spawn/despawn at scale
- Spatial grid correctness with edge cases
- Force system equivalence with old simulation
- Theme switching doesn't crash
- Color overrides persist correctly

**Final commit:**

```bash
git commit -m "test: comprehensive pixel art theme + ECS test suite"
```

---

## Verification Checklist

Before marking complete, verify:

- [ ] `cargo test` — all Rust tests pass
- [ ] `xcodebuild test` — all Swift tests pass
- [ ] Classic theme looks identical to before
- [ ] Pixel art theme renders square blocks (not circles)
- [ ] Pixel art edges are jagged (no smoothstep)
- [ ] Pixel glare visible on Folder and Note blocks
- [ ] Theme toggle works in toolbar
- [ ] Pixel scale slider adjusts chunkiness
- [ ] Dark mode inverts correctly
- [ ] No pixel crawl during slow movement
- [ ] 60fps sustained at 1K nodes in pixel art mode
- [ ] No regressions in classic mode
