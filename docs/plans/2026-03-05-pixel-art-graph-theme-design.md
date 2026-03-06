# Pixel Art Graph Theme + ECS Refactor — Design Document

**Date:** 2026-03-05
**Status:** Approved
**Scope:** Full ECS refactor of graph-engine + pixel art "Voxel Pixel" theme

---

## Vision

Transform the knowledge graph engine from OOP Rust structs into a Data-Oriented ECS (Entity Component System) with SoA (Structure of Arrays) storage for 100K+ node performance. Add a pixel art "Voxel Pixel" theme as a toggleable alternative to the existing classic SDF circle theme. Both themes read from the same ECS data layer.

The pixel art aesthetic: **square blocks** with 3-tone pixel glare shading, **jagged stair-stepped edges** with subtle per-frame jitter, all rendered pixel-perfect through a **two-pass offscreen pipeline** with nearest-neighbor upscaling. No anti-aliasing, no smoothstep — every pixel is either ON or OFF.

---

## Architecture

### Current State

- Nodes: SDF circles with sphere shading (3 quality levels)
- Edges: Smooth 1.5px feathered lines
- Data: Traditional Rust structs (heap-scattered)
- Shaders: Embedded Metal strings in `renderer.rs`
- Colors: `light_mode: bool` selects between two palettes in `types.rs`
- Physics: O(n²) brute-force force-directed layout

### Target State

- Data: ECS with SoA component storage + spatial hash grid
- Physics: O(n) neighbor queries via spatial partitioning
- Rendering: Theme-selectable — Classic (existing) or Voxel Pixel (new)
- Pixel Art: Two-pass pipeline (low-res offscreen → nearest-neighbor upscale)
- Colors: Per-node-type customizable, 5-tier hierarchy defaults
- FFI: New functions for theme, pixel scale, node type colors

### Layer Diagram

```
SwiftUI Controls (GraphFloatingControls)
    ↓ theme toggle, pixel scale slider
GraphState (@Observable) — visualTheme, themeVersion
    ↓ version-tracked sync in render loop
FFI Bridge (graph_engine_set_theme, set_pixel_scale, set_node_type_color)
    ↓
Rust Engine (engine.rs) — owns World + Renderer
    ↓
ECS World (ecs/mod.rs) — SoA components, spatial grid
    ↓
Theme Router → Classic Renderer | Pixel Art Renderer
    ↓                              ↓
Direct to drawable              Pass 1: Low-res offscreen
                                Pass 2: Nearest-neighbor upscale
```

---

## ECS Data Architecture

### World Struct

```rust
pub type Entity = u32;

pub struct World {
    pub entities: Vec<Entity>,
    pub entity_to_index: HashMap<u32, usize>,

    // SoA Components
    pub transform: Vec<TransformComponent>,
    pub velocity: Vec<VelocityComponent>,
    pub hierarchy: Vec<HierarchyComponent>,
    pub render: Vec<RenderComponent>,
    pub ai: Vec<AIComponent>,

    // Spatial acceleration
    pub spatial_grid: SpatialGrid,

    // Global state
    pub theme: Theme,
    pub light_mode: bool,
}
```

### Components

| Component | Fields | Purpose |
|---|---|---|
| `TransformComponent` | `x: f32, y: f32, scale: f32` | World position + breathing scale |
| `VelocityComponent` | `vx: f32, vy: f32` | Movement for Boids/swimming (Phase 2) |
| `HierarchyComponent` | `depth: u32, parent: Option<Entity>, node_type: u8` | Determines block tier |
| `RenderComponent` | `block_type: BlockType, color_override: Option<[f32; 4]>, has_glare: bool` | Visual properties |
| `AIComponent` | `state: AIState, personality_seed: u32, breath_phase: f32` | FSM + animation (Phase 2) |

### BlockType Enum

```rust
#[repr(u8)]
pub enum BlockType {
    Core = 0,      // Folder — 16×16 offscreen px, red, full 3-tone glare
    Primary = 1,   // Note — 12×12, black/white, subtle 2-tone glare
    Secondary = 2, // Source, Idea — 10×10, dark gray, optional glare
    Tertiary = 3,  // Chat, Quote — 8×8, medium gray, no glare
    Leaf = 4,      // Tag, Block — 6×6, teal/light gray, no glare
}
```

### Spatial Hash Grid

```rust
pub struct SpatialGrid {
    cell_size: f32,  // = perception radius
    cells: HashMap<(i32, i32), Vec<Entity>>,
}
```

Rebuilt every frame from transform data. O(1) neighbor lookups.

---

## Node Visual Hierarchy (Pixel Art Mode)

| Tier | Size (offscreen) | Screen Size (@8x) | Default Light | Default Dark | Glare |
|---|---|---|---|---|---|
| Core (Folder) | 16×16 | 128×128 | Red | Red | Full 3-tone |
| Primary (Note) | 12×12 | 96×96 | Black | White | Subtle 2-tone |
| Secondary (Source, Idea) | 10×10 | 80×80 | Dark gray | Light gray | Optional |
| Tertiary (Chat, Quote) | 8×8 | 64×64 | Medium gray | Medium gray | No |
| Leaf (Tag, Block) | 6×6 | 48×48 | Teal/Light gray | Teal/Dark gray | No |

All colors user-overridable per node type via `graph_engine_set_node_type_color()`.

---

## Two-Pass Pixel Art Rendering Pipeline

### Pass 1: Scene Render (offscreen)

- **Resolution**: `view_size / scale_factor` (default scale = 8, configurable)
- **Clear color**: White (light mode) / Black (dark mode)
- **Draw order**: Edges first (behind), then nodes on top
- **Coordinate snapping**: All positions `floor()` to integer grid before projection
- **Anti-aliasing**: NONE. Hard boolean: pixel ON or OFF.

#### Node Rendering
- Instanced axis-aligned quads (single quad mesh, `drawPrimitives:instanceCount:`)
- Fragment shader: flat fill with 3-tone pixel glare overlay
- Glare: top-left 25% → highlight, center 50% → base color, bottom-right 25% → shadow
- Shadow/highlight colors derived from base color (±30% luminance shift)

#### Edge Rendering
- SDF line segment evaluation in fragment shader
- Hard boolean cutoff: `dist <= threshold ? color : discard`
- Angle-compensated thickness: `threshold = (thickness - 1.0 + angle_factor) * 0.5`
- Per-frame jitter: ±1-2px stair-step variance using deterministic hash of (edge_id + frame_count)

#### Pixel Crawl Prevention
```metal
// Velocity-aware integer snapping
if (abs(velocity.x) > abs(velocity.y)) {
    pixel_pos.x = round(position.x);
    pixel_pos.y = round(position.y + (pixel_pos.x - position.x) * velocity.y / velocity.x);
} else {
    pixel_pos.y = round(position.y);
    pixel_pos.x = round(position.x + (pixel_pos.y - position.y) * velocity.x / velocity.y);
}
```

### Pass 2: Upscale (display)

- Full-screen quad sampling offscreen texture
- Sampler: `MTLSamplerMinMagFilterNearest` — crisp block upscaling
- Each offscreen pixel becomes an `scale_factor × scale_factor` block on screen

### Classic Theme Bypass

When `theme == Classic`, the renderer skips the offscreen texture and draws directly to the display drawable using existing SDF circle + smooth line shaders reading from the same ECS data.

---

## Theme System

### Rust

```rust
#[repr(u8)]
pub enum VisualTheme {
    Pixel = 0,   // Default — pixel art blocks
    Classic = 1, // Legacy SDF circles
}
```

> **Note:** Values inverted from original design. See "Implementation Deviations" section.

### Swift

```swift
enum GraphVisualTheme: UInt8, CaseIterable, Codable {
    case pixel = 0
    case classic = 1

    var displayName: String {
        switch self {
        case .pixel:   "Pixel"
        case .classic: "Classic"
        }
    }
}
```

### FFI Bridge Additions

```c
void graph_engine_set_theme(Engine* engine, uint8_t theme);
void graph_engine_set_pixel_scale(Engine* engine, uint8_t scale);
void graph_engine_set_node_type_color(Engine* engine, uint8_t node_type,
                                       float r, float g, float b, float a);
```

### UI: Theme Toggle

Segmented control in `GraphFloatingControls.swift` toolbar:
```
[Classic] [Pixel Blocks]
```
Pixel scale slider (visible only in Pixel Blocks mode):
```
Pixel Scale: [●○○○○○○○] 8
```

Follows the existing quality-level toggle pattern: `GraphState.themeVersion` incremented on change, `MetalGraphNSView.renderFrame()` detects version change and calls `graph_engine_set_theme()`.

---

## Color Palettes

### Voxel Pixel — Light Mode

```rust
VoxelPalette {
    background: [1.0, 1.0, 1.0, 1.0],     // Pure white
    core:       [0.9, 0.2, 0.2, 1.0],      // Red (folders)
    primary:    [0.15, 0.15, 0.15, 1.0],   // Near-black (notes)
    secondary:  [0.35, 0.35, 0.35, 0.9],   // Gray (source, idea)
    tertiary:   [0.55, 0.55, 0.55, 0.8],   // Medium gray (chat, quote)
    leaf:       [0.39, 0.70, 0.65, 0.7],   // Teal (tag, block)
    edge:       [0.0, 0.0, 0.0, 0.4],      // Dark jagged lines
}
```

### Voxel Pixel — Dark Mode

```rust
VoxelPalette {
    background: [0.0, 0.0, 0.0, 1.0],      // Pure black
    core:       [1.0, 0.25, 0.25, 1.0],     // Brighter red (folders)
    primary:    [0.9, 0.9, 0.9, 1.0],       // Near-white (notes)
    secondary:  [0.6, 0.6, 0.6, 0.9],       // Light gray (source, idea)
    tertiary:   [0.45, 0.45, 0.45, 0.8],    // Medium gray (chat, quote)
    leaf:       [0.35, 0.55, 0.50, 0.7],    // Muted teal (tag, block)
    edge:       [1.0, 1.0, 1.0, 0.4],       // Light jagged lines
}
```

---

## Implementation Phases

### Phase 1: ECS Foundation
- `World` struct with SoA storage
- Entity management (create, destroy, lookup)
- `SpatialGrid` for O(n) neighbor queries
- Component types with `#[repr(C)]` for FFI

### Phase 2: Physics Port
- Migrate force-directed layout to ECS systems
- Repulsion, gravity, damping as batch operations on SoA arrays
- Spatial grid integration for neighbor queries
- Verify: existing graph behavior identical post-migration

### Phase 3: Pixel Art Renderer
- Two-pass pipeline: offscreen texture + nearest-neighbor upscale
- Node square shader with pixel glare (3-tone shading)
- Edge jagged line shader (SDF + hard cutoff + jitter)
- Pixel-snap vertex shader with velocity-aware interpolation
- Offscreen resolution: view_size / configurable scale factor

### Phase 4: Classic Renderer Adapter *(DEFERRED)*
- Adapt existing SDF circle + smooth line shaders to read from ECS
- Both themes share identical data path, diverge only at shader selection
- **Status:** Deferred. Classic continues using legacy path. See "Implementation Deviations".

### Phase 5: Theme System + UI
- `GraphVisualTheme` enum (Swift + Rust)
- FFI functions: `set_theme`, `set_pixel_scale`, `set_node_type_color`
- Toolbar segmented control + pixel scale slider
- ~~Per-node-type color overrides in UserDefaults~~ *(Deferred — FFI exists, no Swift UI yet)*
- Version-tracked sync in render loop

### Phase 6: Polish
- Pixel crawl tuning (velocity threshold calibration)
- Edge jitter intensity calibration
- Performance profiling at 10K, 50K, 100K nodes
- Edge case handling (empty graph, single node, no edges)

---

## Files to Create/Modify

| File | Action |
|---|---|
| `graph-engine/src/ecs/mod.rs` | **New** — World, Entity, component types |
| `graph-engine/src/ecs/spatial_grid.rs` | **New** — Hash grid for spatial queries |
| `graph-engine/src/ecs/systems.rs` | **New** — Physics systems on SoA data |
| `graph-engine/src/renderer.rs` | **Modify** — Add pixel art render path + two-pass |
| `graph-engine/src/types.rs` | **Modify** — Theme, BlockType, VoxelPalette |
| `graph-engine/src/lib.rs` | **Modify** — New FFI functions |
| `graph-engine/src/engine.rs` | **Modify** — Integrate ECS World |
| `graph-engine-bridge/graph_engine.h` | **Modify** — Declare new FFI functions |
| `Epistemos/Graph/GraphState.swift` | **Modify** — Add visualTheme + version tracking |
| `Epistemos/Views/Graph/MetalGraphView.swift` | **Modify** — Sync theme in render loop |
| `Epistemos/Views/Graph/GraphFloatingControls.swift` | **Modify** — Theme toggle + scale slider |
| `Epistemos/Theme/EpistemosTheme.swift` | **Modify** — GraphVisualTheme enum |

---

## Performance Budget

| System | Target | Optimization |
|---|---|---|
| ECS physics (100K nodes) | < 3ms | Spatial grid O(n) queries |
| Instance buffer build | < 2ms | Direct memcpy from SoA |
| Render pass 1 (offscreen) | < 4ms | Low-res target, instanced draw |
| Render pass 2 (upscale) | < 1ms | Single full-screen quad |
| Total frame budget | < 16ms | 60fps sustained |

---

## Implementation Deviations (Updated 2026-03-05)

The following intentional changes were made during implementation:

### Theme Enum Values Inverted
- **Design**: `Classic = 0, VoxelPixel = 1`
- **Implemented**: `Pixel = 0, Classic = 1`
- **Rationale**: Pixel art is the new default experience. Making it `0` means new installs and fresh UserDefaults both default to the pixel theme without explicit migration logic.

### Phase 4 (Classic Renderer Adapter) — Partial Migration
- **Design**: "Both themes share identical data path, diverge only at shader selection"
- **Implemented**: Both `draw()` and `draw_pixel()` now accept `&World` + `&Graph`. Pixel reads positions from World SoA; Classic still reads from Graph AoS but has the unified signature. Per-node `color_override` works on both themes via `Graph.Node.color_override` (Classic) and `World.render[i].color_override` (Pixel).
- **Blocking full migration**: Classic's hot path needs `visible`, `radius`, `confidence` which aren't in ECS components. Also `sync_sim_to_world()` bails when visibility filter makes `world.len() != sim.len()`. These are Phase 4 prerequisites.
- **Performance note**: For instance-building loops that touch 5+ fields per entity, AoS vs SoA cache benefit is negligible. The GPU draw calls are the actual bottleneck. Full Classic→ECS migration is an architecture win (one source of truth), not a performance win.

### Per-Node Color Overrides: End-to-End Plumbing Complete
- **Design**: "Per-node-type color overrides in UserDefaults" with UI
- **Implemented**: Two FFI functions: `graph_engine_set_node_type_color` (palette-level, by block tier) and `graph_engine_set_node_color_override` (per-node, by UUID). Both Classic and Pixel renderers check `color_override` (alpha > 0 = active). Engine method `set_node_color_override` writes to both Graph.Node and ECS RenderComponent.
- **Not yet built**: Swift UI (color picker), UserDefaults persistence, override preservation across light/dark mode toggle.

---

## Future Work (Post-Ship)

- **Phase 4 completion**: Add `visible`, `radius`, `confidence` to ECS; fix `sync_sim_to_world` for partial visibility; migrate Classic inner loop to read from World
- **Edge migration**: Move edge data into ECS (currently in `Graph`)
- **Per-node color UI**: Swift color picker + UserDefaults persistence for `set_node_type_color` and `set_node_color_override`
- **Boids steering**: Separation/Alignment/Cohesion + parent gravitational pull
- **IK tentacle edges**: Multi-segment CCD chains replacing static lines
- **Node FSM**: Idle → Swimming → AvoidingCursor → Excited → Sleeping
- **Procedural breathing**: Sin-wave scale with deterministic phase per entity
- **Dithered bloom**: Bayer matrix ordered dithering for red core glow effect
- **Isometric theme**: True 3D isometric block projection (third theme option)
