# Graph Engine Interactivity & Visual Polish Design

**Date**: 2026-02-26
**Status**: Approved
**Builds on**: Rust graph engine core (Tasks 0-5 completed)
**Scope**: Node selection, callbacks, filters, camera, labels, thick edges, LOD

## Context

The core Rust graph engine is complete: Barnes-Hut physics, instanced Metal rendering, C FFI data pipeline, pan/zoom input. This design covers the remaining interactive features needed for a polished, production-quality graph experience.

A reference paper ("High-Performance Interoperability and Rendering Architectures") was consulted and its corrections are integrated below.

---

## Section 1: Node Selection & Hit Testing

### New FFI Functions

```c
void graph_engine_mouse_down(GraphEngine* engine, float x, float y, uint8_t button);
void graph_engine_mouse_up(GraphEngine* engine, float x, float y);
void graph_engine_mouse_moved(GraphEngine* engine, float x, float y);
```

- `button`: 0 = left click, 1 = right click
- Coordinates are in AppKit screen space (origin bottom-left)

### Screen-to-World Transform

Direct algebraic mapping (O(1), no matrix inversion):

```
world_x = screen_x / zoom + camera_offset.x - viewport_w / (2 * zoom)
world_y = screen_y / zoom + camera_offset.y - viewport_h / (2 * zoom)
```

### Hit Testing Algorithm

Linear scan over all visible nodes:

```rust
fn hit_test(&self, world_pos: Vec2) -> Option<u32> {
    let mut best: Option<(u32, f32)> = None;
    for node in &self.graph.nodes {
        if !node.visible { continue; }
        let dist = (world_pos - node.pos).length();
        if dist < node.radius * 1.5 {  // 50% padding for touch targets
            if best.is_none() || dist < best.unwrap().1 {
                best = Some((node.id, dist));
            }
        }
    }
    best.map(|(id, _)| id)
}
```

- O(n) but cache-friendly (contiguous Vec<Node>)
- Acceptable for <50K nodes on Apple Silicon (<1ms)
- Future: reuse Barnes-Hut quadtree for O(log n) queries

### State in Rust

```rust
// In Engine struct:
selected_node_id: Option<u32>,
hovered_node_id: Option<u32>,
```

### Visual Feedback

- Selected node: highlight ring (radius + 4px, brighter color, 2px stroke)
- Hovered node: subtle glow (radius + 2px, 30% opacity ring)
- Both rendered as additional instanced circles in the node draw call

### Interaction Flow

1. `mouse_down(x, y, 0)` → screen→world → hit test → if hit: set selected, fire `on_node_selected` callback
2. `mouse_down(x, y, 1)` → screen→world → hit test → if hit: fire `on_node_right_clicked` callback (with screen coords for NSMenu positioning)
3. `mouse_moved(x, y)` → screen→world → hit test → if changed: update hovered, fire `on_node_hovered` callback
4. `mouse_down` with no hit → clear selection, fire callback with null UUID
5. `mouse_down` + drag (left button, no hit) → pan (existing behavior)

### Swift Side

- `on_node_selected`: Coordinator receives UUID, publishes to `@Observable GraphState` for Info panel
- `on_node_right_clicked`: Coordinator receives UUID + screen coords, shows NSMenu via `NSEvent.mouseLocation`
- `on_node_hovered`: Coordinator updates cursor (arrow vs pointingHand)

---

## Section 2: Rust-to-Swift Callbacks

### Callback Slots

Four function-pointer + void* context pairs stored on Engine:

```rust
type NodeCallback = extern "C" fn(*const c_char, *mut c_void);
type NodeScreenCallback = extern "C" fn(*const c_char, f32, f32, *mut c_void);
type HoverCallback = extern "C" fn(*const c_char, *mut c_void);  // null = no hover
type LabelsCallback = extern "C" fn(*const LabelPosition, usize, *mut c_void);
```

### FFI Registration Functions

```c
void graph_engine_set_on_node_selected(GraphEngine* e, NodeCallback cb, void* ctx);
void graph_engine_set_on_node_right_clicked(GraphEngine* e, NodeScreenCallback cb, void* ctx);
void graph_engine_set_on_node_hovered(GraphEngine* e, HoverCallback cb, void* ctx);
void graph_engine_set_on_labels_updated(GraphEngine* e, LabelsCallback cb, void* ctx);
```

### LabelPosition Struct

```rust
#[repr(C)]
pub struct LabelPosition {
    pub uuid: *const c_char,   // Pointer to null-terminated UUID
    pub screen_x: f32,
    pub screen_y: f32,
    pub radius: f32,           // Screen-space radius for positioning below node
    pub alpha: f32,            // LOD alpha (0.0 = hidden, 1.0 = fully visible)
    pub is_cluster: u8,        // 1 if this represents a cluster
    pub cluster_count: u16,    // Number of nodes in cluster (1 if not clustered)
    pub _pad: u8,              // Alignment padding
}
```

### Callback Timing

- `on_node_selected` / `on_node_right_clicked`: fire from mouse_down handler (synchronous in render thread)
- `on_node_hovered`: fire from mouse_moved (throttled to state-change only)
- `on_labels_updated`: fire every frame after position sync + camera transform

### Swift Context Recovery

```swift
// Registration (in makeNSView):
let ctx = Unmanaged.passUnretained(coordinator).toOpaque()
graph_engine_set_on_node_selected(engine, onNodeSelected, ctx)

// C callback (static function):
let onNodeSelected: @convention(c) (UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void = { uuid, ctx in
    guard let ctx, let uuid else { return }
    let coord = Unmanaged<Coordinator>.fromOpaque(ctx).takeUnretainedValue()
    let id = String(cString: uuid)
    DispatchQueue.main.async { coord.handleNodeSelected(id) }
}
```

### Thread Safety Note

Callbacks fire from the render thread (MTKView display link). Use `DispatchQueue.main.async` (not `Task { @MainActor in }`) for lighter scheduling overhead at 60-120Hz callback rates.

---

## Section 3: Filter Integration

### FFI Function

```c
void graph_engine_set_visibility(GraphEngine* engine, const uint8_t* visible, size_t count);
```

- `visible`: flat array of 0/1 bytes, one per node in insertion order
- Called from Swift whenever FilterEngine state changes

### Rust Side

```rust
// In Node struct:
pub visible: bool,  // default true

// In graph_engine_set_visibility:
fn set_visibility(engine: &mut Engine, visible: &[u8]) {
    for (i, node) in engine.graph.nodes.iter_mut().enumerate() {
        node.visible = if i < visible.len() { visible[i] != 0 } else { true };
    }
    engine.mark_visibility_dirty();
}
```

### Physics Exclusion (Critical — per reference paper Section 3)

Invisible nodes are EXCLUDED from:
1. **Barnes-Hut tree construction** — prevents "ghost" repulsive forces warping visible topology
2. **Force computation** — no position/velocity updates
3. **GPU instance buffer** — not uploaded to Metal
4. **Edge rendering** — edges with either endpoint invisible are skipped
5. **on_labels_updated callback** — only visible nodes reported

### Swift Side

```swift
// In MetalGraphView Coordinator, called on filter change:
func pushVisibility(engine: UnsafeMutableRawPointer, store: GraphStore, filter: FilterEngine) {
    let nodes = store.orderedNodes  // Same order as original add_nodes
    var mask = [UInt8](repeating: 0, count: nodes.count)
    for (i, node) in nodes.enumerated() {
        mask[i] = filter.isNodeVisible(node) ? 1 : 0
    }
    mask.withUnsafeBufferPointer { ptr in
        graph_engine_set_visibility(engine, ptr.baseAddress, ptr.count)
    }
}
```

### Memory Efficiency

100K nodes = 100KB bitmask. Fits in L2 cache. Negligible FFI overhead.

---

## Section 4: Camera Commands

### FFI Functions

```c
void graph_engine_reset_camera(GraphEngine* engine);
void graph_engine_center_on_node(GraphEngine* engine, const char* uuid);
void graph_engine_fit_all(GraphEngine* engine);
```

### Behavior

1. **reset_camera**: target_offset = (0, 0), target_zoom = 1.0
2. **center_on_node(uuid)**: look up node position, set target_offset so node is at screen center. Optionally zoom to 2.0 if currently zoomed out further.
3. **fit_all**: compute bounding box of all visible nodes, set target_offset and target_zoom so graph fills 80% of viewport:
   ```
   zoom_x = viewport_w * 0.8 / bbox_width
   zoom_y = viewport_h * 0.8 / bbox_height
   zoom = min(zoom_x, zoom_y)
   ```

### Frame-Rate Independent Animation (Critical Fix — per reference paper Section 4)

The original "15% per frame" approach is frame-rate dependent. A 120Hz ProMotion display reaches the target 2x faster than a 60Hz external monitor.

**Corrected approach**: continuous-time exponential damping.

```rust
// In Renderer:
last_frame_time: std::time::Instant,
target_offset: Vec2,
target_zoom: f32,
is_animating: bool,

const CAMERA_LAMBDA: f32 = 8.0;  // Snappy but smooth

fn update_camera(&mut self) {
    if !self.is_animating { return; }

    let now = std::time::Instant::now();
    let dt = (now - self.last_frame_time).as_secs_f32().min(0.1); // Cap at 100ms
    self.last_frame_time = now;

    let t = 1.0 - (-CAMERA_LAMBDA * dt).exp();

    self.camera_offset = self.camera_offset.lerp(self.target_offset, t);
    self.camera_zoom = lerp(self.camera_zoom, self.target_zoom, t);

    // Stop animating when close enough
    let offset_diff = (self.target_offset - self.camera_offset).length();
    let zoom_diff = (self.target_zoom - self.camera_zoom).abs();
    if offset_diff < 0.1 && zoom_diff < 0.001 {
        self.camera_offset = self.target_offset;
        self.camera_zoom = self.target_zoom;
        self.is_animating = false;
    }
}
```

This produces identical animation speed on 30Hz, 60Hz, and 120Hz displays.

### Swift Triggers

- Space key or toolbar button → `graph_engine_reset_camera`
- Info panel "Focus" button → `graph_engine_center_on_node`
- After `graph_engine_commit` → `graph_engine_fit_all` (auto-frame initial view)
- Toolbar "Fit All" button → `graph_engine_fit_all`

---

## Section 5: Text Labels (Swift Overlay)

### Architecture

A `GraphLabelOverlay` (NSView subclass) sits directly on top of the MTKView in the same frame. It owns a pool of `CATextLayer` instances — one per node.

### Label Positioning Flow

1. Rust `render()` syncs positions, applies camera transform, computes screen coords for each visible node
2. Rust fires `on_labels_updated(positions, count, ctx)` with pre-calculated screen coordinates
3. Swift Coordinator receives array of `LabelPosition` structs
4. Swift repositions CATextLayers using the screen coords

### CATransaction Synchronization (Critical — per reference paper Section 5)

Core Animation implicitly animates property changes with a 0.25s default duration. At 60fps this causes catastrophic lag.

```swift
func updateLabels(_ positions: UnsafeBufferPointer<LabelPosition>) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    for i in 0..<positions.count {
        let pos = positions[i]
        let layer = getOrCreateLayer(for: pos.uuid)
        layer.position = CGPoint(x: CGFloat(pos.screen_x), y: CGFloat(pos.screen_y) + CGFloat(pos.radius) + 4)
        layer.opacity = pos.alpha
    }

    // Hide layers not in the current set
    hideUnusedLayers()

    CATransaction.commit()
}
```

### LOD Alpha Strategy

Rust computes alpha per node based on weight (connection count):
- weight > 5 (hub nodes): alpha = 1.0
- weight > 2 (medium nodes): alpha = 0.5 (semi-transparent)
- weight <= 2 (leaf nodes): alpha = 0.0 (hidden)

At far zoom levels (zoom < 0.5), further reduce: multiply alpha by `min(1.0, zoom * 2.0)`.

**Performance ceiling**: Keep concurrently opaque labels below ~3,000 per reference paper benchmarks. The LOD system naturally enforces this for typical knowledge graphs.

### Styling

- Font: SF Pro, 11pt, system weight
- Color: white with 60% black shadow (NSShadow on CATextLayer)
- Truncation: 20 characters max with ellipsis
- Position: centered below node, 4pt gap below radius

---

## Section 6: Thick Anti-Aliased Edges

### Architecture Change

Replace current 1px `MTLPrimitiveType::Line` with quad-strip triangles (2 triangles = 6 vertices per edge).

### Vertex Layout

```rust
#[repr(C)]
struct EdgeQuadVertex {
    position_a: [f32; 2],    // Endpoint A (world space)
    position_b: [f32; 2],    // Endpoint B (world space)
    perpendicular_sign: f32, // -1.0 or +1.0
    alpha_edge: f32,         // 0.0 (outer edge) or 1.0 (center)
    color: [f32; 4],
}
```

6 vertices per edge: corners (A-left, A-right, B-left) + (B-left, A-right, B-right)

### Vertex Shader — Clip-Space Expansion (Critical — per reference paper Section 6)

Perpendicular offset MUST be computed in NDC/clip space, not world space. Otherwise zoom changes distort line width.

```metal
vertex EdgeVertexOut edge_quad_vertex(
    uint vertex_id [[vertex_id]],
    constant EdgeQuadVertex* edges [[buffer(0)]],
    constant Uniforms& u [[buffer(1)]]
) {
    EdgeQuadVertex e = edges[vertex_id];

    // Transform both endpoints to NDC
    float2 a_screen = (e.position_a - u.camera_offset) * u.camera_zoom;
    float2 b_screen = (e.position_b - u.camera_offset) * u.camera_zoom;
    float2 a_ndc = a_screen / (u.viewport_size * 0.5) * float2(1, -1);
    float2 b_ndc = b_screen / (u.viewport_size * 0.5) * float2(1, -1);

    // Direction and perpendicular in NDC
    float2 dir = normalize(b_ndc - a_ndc);
    float2 perp = float2(-dir.y, dir.x);

    // Thickness in NDC pixels: base 1.5px, clamped [0.5, 3.0]
    float thickness_px = clamp(1.5, 0.5, 3.0);
    float2 offset = perp * e.perpendicular_sign * thickness_px / u.viewport_size;

    // Pick which endpoint this vertex belongs to
    float2 base_ndc = (e.alpha_edge > 0.5) ? a_ndc : b_ndc;

    EdgeVertexOut out;
    out.position = float4(base_ndc + offset, 0.0, 1.0);
    out.color = e.color;
    out.edge_coord = e.perpendicular_sign;  // For AA in fragment shader
    return out;
}
```

### Fragment Shader — Smoothstep Anti-Aliasing

```metal
fragment float4 edge_quad_fragment(EdgeVertexOut in [[stage_in]]) {
    // SDF-style 1px soft edge
    float dist = abs(in.edge_coord);  // 0.0 at center, 1.0 at edge
    float aa_alpha = 1.0 - smoothstep(0.7, 1.0, dist);
    return float4(in.color.rgb, in.color.a * aa_alpha);
}
```

### Edge Color

Each edge inherits its source node's type color at 40% opacity:
```rust
let base_color = source_node.node_type.color();
let edge_color = [base_color[0], base_color[1], base_color[2], 0.4];
```

---

## Section 7: Spatial Clustering LOD (Deferred to v2)

### Concept

At far zoom levels (zoom < 0.3), nearby nodes merge into cluster bubbles with count badges. This prevents visual clutter and GPU overload.

### Algorithm (when implemented)

1. Compute merge distance: `threshold = 40.0 / camera_zoom` world units
2. Build spatial hash grid with cell size = threshold
3. Same-cell nodes → same cluster. Highest-weight node = representative.
4. Clusters with 1 node → render normally. 2+ → render enlarged bubble.

### Visual Treatment

- Cluster radius: `max(representative.radius, sqrt(count) * 8.0)`
- Color: weighted blend of contained node types
- Label: "x{count}" badge via `is_cluster` flag in LabelPosition

### Dissolve Behavior

As user zooms in past threshold, clusters dissolve with alpha fade — no discrete mode switch.

### Why Deferred

Spatial clustering adds complexity to the rendering and interaction pipeline. The base interactivity (Sections 1-6) must be solid and profiled first. Spatial clustering becomes necessary only when graphs exceed ~5,000 visible nodes at far zoom.

---

## Critical Corrections Summary

These corrections were identified by cross-referencing the reference paper against our original design:

| ID | Issue | Original | Corrected |
|---|---|---|---|
| C1 | Camera animation frame-rate dependent | 15% per frame | `1 - exp(-lambda * dt)` continuous damping |
| C2 | Edge thickness distorted by zoom | World-space perpendicular | Clip-space perpendicular expansion |
| C3 | CATextLayer implicit animation lag | Direct property update | `CATransaction.setDisableActions(true)` |
| C4 | GPU buffer re-created every frame | `new_buffer_with_data` per frame | Pre-allocate, memcpy positions only |

---

## Performance Budget

| Component | Target | Constraint |
|---|---|---|
| Hit testing (linear scan) | <1ms | 50K nodes on Apple Silicon |
| Visibility push (bitmask) | <100us | 100KB for 100K nodes |
| Label overlay (CATextLayer) | <3000 concurrent | LOD alpha enforced |
| Edge rendering (quad strips) | 6 vertices/edge | Single instanced draw call |
| Camera animation | Frame-rate independent | `dt`-based exponential damping |
| Physics tick | ~8ms at 120Hz | Barnes-Hut O(n log n) |

---

## Render Order

1. Clear to dark background (#121217)
2. Draw edges (quad strips, alpha blended)
3. Draw nodes (instanced circles, opaque core + AA edge)
4. Draw selection/hover rings (additional instanced circles)
5. Swift overlay: position CATextLayers via callback

---

## New Files (Rust)

No new Rust source files — all additions go into existing modules:
- `engine.rs`: selected/hovered state, callbacks, mouse handlers, visibility
- `renderer.rs`: highlight rings, quad-strip edge pipeline, camera animation, label projection
- `lib.rs`: new FFI exports
- `types.rs`: `visible` field on Node

## New Files (Swift)

- `GraphLabelOverlay.swift`: NSView subclass with CATextLayer pool
- Modifications to `MetalGraphView.swift`: mouse event forwarding, callback registration
- Modifications to `GraphMTKView.swift`: mouseDown/mouseUp/mouseMoved event handlers
- Modifications to `graph_engine.h`: new FFI declarations

## Modified Files (Swift)

- `GraphWindowView.swift`: add label overlay as sibling view to MetalGraphView
- `GraphState.swift`: expose selectedNodeId, respond to callbacks
