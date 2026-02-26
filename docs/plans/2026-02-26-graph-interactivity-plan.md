# Graph Interactivity & Visual Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add node selection, Rust→Swift callbacks, filter integration, camera commands, text labels, and thick anti-aliased edges to the existing Rust graph engine.

**Architecture:** All interactive state lives in Rust (selected/hovered node, visibility flags, camera targets). Swift forwards mouse events via C FFI and receives callbacks (function pointer + void* context) for UI updates. Text labels rendered via CATextLayer overlay on top of MTKView. Edges upgraded from 1px hairlines to quad-strip triangles with SDF anti-aliasing.

**Tech Stack:** Rust 2024, metal-rs, glam, parking_lot, Swift 6, MetalKit, Core Animation (CATextLayer)

**Design Doc:** `docs/plans/2026-02-26-graph-interactivity-design.md`

---

### Task 0: Fix Per-Frame GPU Buffer Allocation (Critical C4)

**Goal:** Stop re-creating Metal buffers every frame. Pre-allocate on commit, memcpy positions each frame.

**Why first:** Every subsequent task adds more GPU data. If we don't fix this now, quad-strip edges (6x the vertices) will cause severe memory churn.

**Files:**
- Modify: `graph-engine/src/renderer.rs:140-324` (Renderer struct + upload_graph)
- Modify: `graph-engine/src/engine.rs:147-156` (render method)

**Step 1: Add pre-allocated buffer fields to Renderer**

In `renderer.rs`, replace the buffer fields (lines 146-156) with capacity-tracked pre-allocated buffers:

```rust
pub struct Renderer {
    device: Device,
    command_queue: CommandQueue,
    layer: MetalLayer,
    node_pipeline: RenderPipelineState,
    edge_pipeline: RenderPipelineState,
    // Pre-allocated GPU buffers (sized on commit, reused every frame)
    node_instance_buf: Option<Buffer>,
    node_instance_capacity: usize,
    edge_position_buf: Option<Buffer>,
    edge_color_buf: Option<Buffer>,
    edge_capacity: usize,        // Max edges the buffers can hold
    uniform_buf: Buffer,
    // Camera state
    pub camera_offset: Vec2,
    pub camera_zoom: f32,
    // Cached counts (updated per frame)
    node_count: usize,
    edge_vertex_count: usize,
}
```

**Step 2: Split upload_graph into allocate_buffers + update_positions**

Add two new methods. `allocate_buffers` is called once after commit. `update_positions` is called every frame and only memcpys position data into existing buffers.

```rust
/// Pre-allocate GPU buffers for the given graph size. Called once after commit().
pub fn allocate_buffers(&mut self, graph: &Graph) {
    let node_count = graph.nodes.len();
    let edge_count = graph.edges.len();

    // Node buffer
    if node_count > self.node_instance_capacity || self.node_instance_buf.is_none() {
        let capacity = (node_count * 3 / 2).max(64); // 50% headroom
        let size = (capacity * std::mem::size_of::<NodeInstance>()) as u64;
        self.node_instance_buf = Some(self.device.new_buffer(size, MTLResourceOptions::StorageModeShared));
        self.node_instance_capacity = capacity;
    }

    // Edge position buffer (2 vertices per edge for now; Task 6 changes to 6)
    let edge_verts = edge_count * 2;
    if edge_count > self.edge_capacity || self.edge_position_buf.is_none() {
        let capacity = (edge_count * 3 / 2).max(64);
        let vert_capacity = capacity * 2;
        let pos_size = (vert_capacity * std::mem::size_of::<[f32; 2]>()) as u64;
        let col_size = (vert_capacity * std::mem::size_of::<[f32; 4]>()) as u64;
        self.edge_position_buf = Some(self.device.new_buffer(pos_size, MTLResourceOptions::StorageModeShared));
        self.edge_color_buf = Some(self.device.new_buffer(col_size, MTLResourceOptions::StorageModeShared));
        self.edge_capacity = capacity;
    }

    // Do initial full upload
    self.upload_graph(graph);
}

/// Update GPU buffers with current positions. Called every frame.
/// Only copies position data — colors and radii are unchanged.
pub fn update_positions(&mut self, graph: &Graph) {
    self.node_count = graph.nodes.len();
    if self.node_count == 0 { return; }

    // Update node positions in-place
    if let Some(buf) = &self.node_instance_buf {
        let ptr = buf.contents() as *mut NodeInstance;
        for (i, node) in graph.nodes.iter().enumerate() {
            if i >= self.node_instance_capacity { break; }
            unsafe {
                let inst = &mut *ptr.add(i);
                inst.position = [node.pos.x, node.pos.y];
            }
        }
    }

    // Update edge endpoint positions in-place
    let mut edge_vert_idx = 0usize;
    if let Some(pos_buf) = &self.edge_position_buf {
        let pos_ptr = pos_buf.contents() as *mut [f32; 2];
        for edge in &graph.edges {
            let si = graph.id_to_index.get(&edge.source);
            let ti = graph.id_to_index.get(&edge.target);
            if let (Some(&si), Some(&ti)) = (si, ti) {
                let src = &graph.nodes[si];
                let tgt = &graph.nodes[ti];
                unsafe {
                    *pos_ptr.add(edge_vert_idx) = [src.pos.x, src.pos.y];
                    *pos_ptr.add(edge_vert_idx + 1) = [tgt.pos.x, tgt.pos.y];
                }
                edge_vert_idx += 2;
            }
        }
    }
    self.edge_vertex_count = edge_vert_idx;
}
```

**Step 3: Update engine.rs render method**

Change `engine.rs` render() to call `update_positions` instead of `upload_graph`:

```rust
pub fn render(&mut self) {
    self.sync_positions();
    if let Some(renderer) = &mut self.renderer {
        renderer.update_positions(&self.graph);
        renderer.draw(self.width, self.height);
    }
}
```

And add a call to `allocate_buffers` after commit. In `lib.rs` `graph_engine_commit`, after `engine.start_physics()`:

```rust
if let Some(renderer) = &mut engine.renderer {
    renderer.allocate_buffers(&engine.graph);
}
```

**Step 4: Build and verify**

```bash
cd /Users/jojo/Epistemos/graph-engine && cargo build --release --target aarch64-apple-darwin 2>&1 | tail -5
```

Expected: Compiles with at most warnings.

```bash
cd /Users/jojo/Epistemos && xcodebuild -scheme Epistemos build 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add graph-engine/src/renderer.rs graph-engine/src/engine.rs graph-engine/src/lib.rs
git commit -m "perf: pre-allocate GPU buffers, memcpy positions per frame

Eliminates per-frame Metal buffer allocation. Buffers are pre-allocated
with 50% headroom on commit and reused via pointer writes each frame."
```

---

### Task 1: Add Visible Field to Node + Visibility FFI

**Goal:** Add `visible: bool` to Node, wire up `graph_engine_set_visibility` FFI, exclude invisible nodes from rendering and physics.

**Files:**
- Modify: `graph-engine/src/types.rs:64-73` (Node struct)
- Modify: `graph-engine/src/types.rs:134-147` (add_node — set visible = true)
- Modify: `graph-engine/src/lib.rs` (add FFI function)
- Modify: `graph-engine/src/physics.rs:235-314` (skip invisible in tick)
- Modify: `graph-engine/src/renderer.rs` (skip invisible in update_positions)
- Modify: `graph-engine-bridge/graph_engine.h` (add declaration)

**Step 1: Add `visible` field to Node**

In `types.rs`, add to Node struct after `radius`:

```rust
pub struct Node {
    pub id: u32,
    pub uuid: String,
    pub pos: Vec2,
    pub vel: Vec2,
    pub node_type: NodeType,
    pub weight: f32,
    pub label: String,
    pub radius: f32,
    pub visible: bool,
}
```

In `add_node`, set `visible: true` in the Node constructor.

**Step 2: Add FFI function in lib.rs**

```rust
/// Set node visibility from a flat byte array (0 = hidden, nonzero = visible).
/// Array indices match node insertion order.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_visibility(
    ptr: *mut c_void,
    visible: *const u8,
    count: usize,
) {
    let Some(engine) = get_engine(ptr) else { return };
    if visible.is_null() || count == 0 { return; }

    let slice = unsafe { std::slice::from_raw_parts(visible, count) };
    for (i, node) in engine.graph.nodes.iter_mut().enumerate() {
        node.visible = if i < slice.len() { slice[i] != 0 } else { true };
    }

    // Rebuild physics with only visible nodes
    {
        let mut phys = engine.shared.physics.lock();
        phys.load_from_graph_filtered(&engine.graph);
    }

    // Re-upload buffers with only visible nodes
    if let Some(renderer) = &mut engine.renderer {
        renderer.upload_graph(&engine.graph);
    }
}
```

**Step 3: Add `load_from_graph_filtered` to PhysicsState**

In `physics.rs`, add a method that only loads visible nodes:

```rust
/// Load physics state from graph, skipping invisible nodes.
/// Maintains a mapping from physics index → graph index for write-back.
pub fn load_from_graph_filtered(&mut self, graph: &crate::types::Graph) {
    let visible_count = graph.nodes.iter().filter(|n| n.visible).count();
    self.positions.clear();
    self.velocities.clear();
    self.masses.clear();
    self.edges.clear();
    self.graph_indices.clear();

    self.positions.reserve(visible_count);
    self.velocities.reserve(visible_count);
    self.masses.reserve(visible_count);
    self.graph_indices.reserve(visible_count);

    // Map from node.id → physics index
    let mut id_to_phys: rustc_hash::FxHashMap<u32, usize> = rustc_hash::FxHashMap::default();

    for (graph_idx, node) in graph.nodes.iter().enumerate() {
        if !node.visible { continue; }
        let phys_idx = self.positions.len();
        id_to_phys.insert(node.id, phys_idx);
        self.positions.push(node.pos);
        self.velocities.push(node.vel);
        self.masses.push(node.weight.max(1.0));
        self.graph_indices.push(graph_idx);
    }

    // Only include edges where both endpoints are visible
    self.edges.reserve(graph.edges.len());
    for edge in &graph.edges {
        if let (Some(&si), Some(&ti)) = (id_to_phys.get(&edge.source), id_to_phys.get(&edge.target)) {
            self.edges.push((si as u32, ti as u32, edge.weight));
        }
    }

    self.config.alpha = 0.3; // Gentle reheat on filter change
    self.is_settled = false;
}
```

Add `graph_indices` field to PhysicsState:

```rust
pub struct PhysicsState {
    pub positions: Vec<Vec2>,
    pub velocities: Vec<Vec2>,
    pub masses: Vec<f32>,
    pub graph_indices: Vec<usize>,  // maps physics index → graph node index
    pub edges: Vec<(u32, u32, f32)>,
    pub config: ForceConfig,
    pub is_settled: bool,
}
```

Initialize it in `new()` and `load_from_graph` as well.

**Step 4: Update renderer to skip invisible nodes**

In `upload_graph` and `update_positions`, add `if !node.visible { continue; }` before pushing node instances. Same for edges where either endpoint is invisible.

**Step 5: Update C header**

In `graph_engine.h`, add:

```c
void graph_engine_set_visibility(GraphEngine* engine, const uint8_t* visible, size_t count);
```

**Step 6: Build and verify**

```bash
cd /Users/jojo/Epistemos/graph-engine && cargo build --release --target aarch64-apple-darwin 2>&1 | tail -5
cd /Users/jojo/Epistemos && xcodebuild -scheme Epistemos build 2>&1 | tail -3
```

**Step 7: Commit**

```bash
git add graph-engine/src/ graph-engine-bridge/graph_engine.h
git commit -m "feat: add node visibility flag and FFI bitmask

Invisible nodes excluded from physics tree, force computation,
and GPU upload. Prevents ghost forces from warping visible topology."
```

---

### Task 2: Wire Swift FilterEngine → Rust Visibility

**Goal:** When Swift FilterEngine changes, push visibility bitmask to Rust engine.

**Files:**
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift` (Coordinator: add pushVisibility, store node order)
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift` (updateNSView: detect filter changes)

**Step 1: Store node insertion order in Coordinator**

Add to Coordinator:

```swift
/// Node IDs in the order they were sent to Rust. Used for visibility bitmask alignment.
var nodeInsertionOrder: [String] = []
```

In `loadGraphData`, after the node loop, capture the order:

```swift
nodeInsertionOrder = store.nodes.values.map(\.id)
```

Wait — `store.nodes.values` is a dictionary and has no guaranteed order. We need to capture the ACTUAL order we iterated. Change the node loop to:

```swift
var orderedIds: [String] = []
for node in store.nodes.values {
    orderedIds.append(node.id)
    node.id.withCString { uuidPtr in
        // ... existing FFI call ...
    }
}
nodeInsertionOrder = orderedIds
```

**Step 2: Add pushVisibility method to Coordinator**

```swift
func pushVisibility(engine: UnsafeMutableRawPointer, filter: FilterEngine, store: GraphStore) {
    guard !nodeInsertionOrder.isEmpty else { return }
    var mask = [UInt8](repeating: 0, count: nodeInsertionOrder.count)
    for (i, nodeId) in nodeInsertionOrder.enumerated() {
        if let node = store.nodes[nodeId], filter.isNodeVisible(node) {
            mask[i] = 1
        }
    }
    mask.withUnsafeBufferPointer { ptr in
        graph_engine_set_visibility(engine, ptr.baseAddress, ptr.count)
    }
}
```

**Step 3: Track filter version for change detection**

Add to Coordinator:

```swift
/// Tracks the last filter state hash to avoid redundant pushes.
var lastFilterHash: Int = 0
```

In `updateNSView`, after the existing resize block, add filter sync:

```swift
// Push visibility when filter changes
if coordinator.hasLoadedData, let engine = coordinator.engine {
    let currentHash = graphState.filter.activeNodeTypes.hashValue
        ^ (graphState.filter.focusedNodeId?.hashValue ?? 0)
        ^ graphState.filter.hiddenNodeIds.hashValue
        ^ (graphState.filter.timelineDate?.hashValue ?? 0)
    if currentHash != coordinator.lastFilterHash {
        coordinator.lastFilterHash = currentHash
        coordinator.pushVisibility(engine: engine, filter: graphState.filter, store: graphState.store)
    }
}
```

**Step 4: Build and verify**

```bash
cd /Users/jojo/Epistemos && xcodebuild -scheme Epistemos build 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Epistemos/Views/Graph/MetalGraphView.swift
git commit -m "feat: wire Swift FilterEngine to Rust visibility bitmask

Pushes uint8_t visibility array on each filter change. Tracks
node insertion order and filter state hash for change detection."
```

---

### Task 3: Node Selection & Hit Testing

**Goal:** Add mouse_down/up/moved FFI, screen→world transform, linear-scan hit test, selected/hovered state in Rust.

**Files:**
- Modify: `graph-engine/src/engine.rs` (add selected_node_id, hovered_node_id, mouse handlers, screen_to_world)
- Modify: `graph-engine/src/lib.rs` (add FFI exports)
- Modify: `graph-engine-bridge/graph_engine.h` (add declarations)
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift` (GraphMTKView: wire mouse events)

**Step 1: Add interaction state and methods to Engine**

In `engine.rs`, add fields to Engine:

```rust
pub struct Engine {
    pub graph: Graph,
    pub width: u32,
    pub height: u32,
    pub shared: Arc<SharedState>,
    pub renderer: Option<Renderer>,
    physics_running: Arc<AtomicBool>,
    physics_handle: Option<std::thread::JoinHandle<()>>,
    // Interaction state
    pub selected_node_id: Option<u32>,
    pub hovered_node_id: Option<u32>,
    is_dragging_node: bool,
    drag_node_id: Option<u32>,
}
```

Initialize all as `None`/`false` in `new()`.

Add the screen-to-world transform:

```rust
fn screen_to_world(&self, screen_x: f32, screen_y: f32) -> Vec2 {
    let renderer = match &self.renderer {
        Some(r) => r,
        None => return Vec2::new(screen_x, screen_y),
    };
    let vp_w = self.width as f32;
    let vp_h = self.height as f32;
    let zoom = renderer.camera_zoom;
    let offset = renderer.camera_offset;

    Vec2::new(
        screen_x / zoom + offset.x - vp_w / (2.0 * zoom),
        screen_y / zoom + offset.y - vp_h / (2.0 * zoom),
    )
}
```

Add hit testing:

```rust
fn hit_test(&self, world_pos: Vec2) -> Option<u32> {
    let mut best: Option<(u32, f32)> = None;
    for node in &self.graph.nodes {
        if !node.visible { continue; }
        let dist = (world_pos - node.pos).length();
        let hit_radius = node.radius * 1.5; // 50% padding for touch targets
        if dist < hit_radius {
            if best.is_none() || dist < best.unwrap().1 {
                best = Some((node.id, dist));
            }
        }
    }
    best.map(|(id, _)| id)
}
```

Add mouse handlers:

```rust
pub fn mouse_down(&mut self, x: f32, y: f32, button: u8) {
    let world = self.screen_to_world(x, y);
    let hit = self.hit_test(world);

    if button == 0 { // Left click
        self.selected_node_id = hit;
        // TODO: fire on_node_selected callback (Task 4)
    } else if button == 1 { // Right click
        if hit.is_some() {
            // TODO: fire on_node_right_clicked callback (Task 4)
        }
    }
}

pub fn mouse_up(&mut self, _x: f32, _y: f32) {
    self.is_dragging_node = false;
    self.drag_node_id = None;
}

pub fn mouse_moved(&mut self, x: f32, y: f32) {
    let world = self.screen_to_world(x, y);
    let hit = self.hit_test(world);

    if hit != self.hovered_node_id {
        self.hovered_node_id = hit;
        // TODO: fire on_node_hovered callback (Task 4)
    }
}
```

**Step 2: Add FFI exports in lib.rs**

```rust
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_mouse_down(ptr: *mut c_void, x: f32, y: f32, button: u8) {
    if let Some(engine) = get_engine(ptr) {
        engine.mouse_down(x, y, button);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_mouse_up(ptr: *mut c_void, x: f32, y: f32) {
    if let Some(engine) = get_engine(ptr) {
        engine.mouse_up(x, y);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_mouse_moved(ptr: *mut c_void, x: f32, y: f32) {
    if let Some(engine) = get_engine(ptr) {
        engine.mouse_moved(x, y);
    }
}
```

**Step 3: Update C header**

```c
// Input — mouse events
void graph_engine_mouse_down(GraphEngine* engine, float x, float y, uint8_t button);
void graph_engine_mouse_up(GraphEngine* engine, float x, float y);
void graph_engine_mouse_moved(GraphEngine* engine, float x, float y);
```

**Step 4: Wire Swift mouse events in GraphMTKView**

Replace the current mouseDown/mouseDragged/mouseUp in `GraphMTKView`:

```swift
override func mouseDown(with event: NSEvent) {
    guard let engine else { return }
    let loc = convert(event.locationInWindow, from: nil)
    let button: UInt8 = event.type == .rightMouseDown ? 1 : 0
    graph_engine_mouse_down(engine, Float(loc.x), Float(bounds.height - loc.y), button)
    // Store for drag detection
    isDragging = false
    lastDragPoint = loc
}

override func rightMouseDown(with event: NSEvent) {
    guard let engine else { return }
    let loc = convert(event.locationInWindow, from: nil)
    graph_engine_mouse_down(engine, Float(loc.x), Float(bounds.height - loc.y), 1)
}

override func mouseDragged(with event: NSEvent) {
    guard let engine else { return }
    let point = convert(event.locationInWindow, from: nil)
    let dx = Float(point.x - lastDragPoint.x)
    let dy = Float(point.y - lastDragPoint.y)

    if !isDragging {
        // Small threshold before starting pan (allows click-without-drag)
        if abs(dx) + abs(dy) < 3 { return }
        isDragging = true
    }

    graph_engine_pan(engine, dx, -dy)
    lastDragPoint = point
}

override func mouseUp(with event: NSEvent) {
    guard let engine else { return }
    let loc = convert(event.locationInWindow, from: nil)
    graph_engine_mouse_up(engine, Float(loc.x), Float(bounds.height - loc.y))
    isDragging = false
}

override func mouseMoved(with event: NSEvent) {
    guard let engine else { return }
    let loc = convert(event.locationInWindow, from: nil)
    graph_engine_mouse_moved(engine, Float(loc.x), Float(bounds.height - loc.y))
}

// Enable mouse moved events
override func updateTrackingAreas() {
    super.updateTrackingAreas()
    trackingAreas.forEach { removeTrackingArea($0) }
    let area = NSTrackingArea(
        rect: bounds,
        options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
        owner: self,
        userInfo: nil
    )
    addTrackingArea(area)
}
```

Note: Y is flipped (`bounds.height - loc.y`) because AppKit Y is up, viewport Y is down.

**Step 5: Build and verify**

```bash
cd /Users/jojo/Epistemos/graph-engine && cargo build --release --target aarch64-apple-darwin 2>&1 | tail -5
cd /Users/jojo/Epistemos && xcodebuild -scheme Epistemos build 2>&1 | tail -3
```

**Step 6: Commit**

```bash
git add graph-engine/src/ graph-engine-bridge/ Epistemos/Views/Graph/MetalGraphView.swift
git commit -m "feat: add node selection and hit testing via mouse events

Screen-to-world transform, linear-scan hit test, selected/hovered
state in Rust. Swift forwards mouse_down/up/moved through FFI."
```

---

### Task 4: Rust→Swift Callbacks

**Goal:** Implement function pointer + void* callback system for node_selected, node_right_clicked, node_hovered, and labels_updated.

**Files:**
- Modify: `graph-engine/src/engine.rs` (add callback storage, fire callbacks)
- Modify: `graph-engine/src/lib.rs` (add registration FFI functions + LabelPosition struct)
- Modify: `graph-engine-bridge/graph_engine.h` (add callback typedefs and registration)
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift` (register callbacks in makeNSView, implement handlers)

**Step 1: Define callback types in engine.rs**

```rust
use std::ffi::{c_char, CString};

// Callback function pointer types
type NodeCallback = extern "C" fn(*const c_char, *mut c_void);
type NodeScreenCallback = extern "C" fn(*const c_char, f32, f32, *mut c_void);
type HoverCallback = extern "C" fn(*const c_char, *mut c_void); // null = no hover
type LabelsCallback = extern "C" fn(*const LabelPosition, usize, *mut c_void);

/// Pre-calculated screen position for a visible node label.
#[repr(C)]
pub struct LabelPosition {
    pub uuid: *const c_char,
    pub screen_x: f32,
    pub screen_y: f32,
    pub radius: f32,
    pub alpha: f32,
}

struct CallbackSlot<F> {
    func: F,
    context: *mut c_void,
}

// Mark Send — the void* context is an Unmanaged Swift object whose lifecycle
// is guaranteed by the Coordinator (which outlives the engine).
unsafe impl<F> Send for CallbackSlot<F> {}
```

Add callback fields to Engine:

```rust
pub struct Engine {
    // ... existing fields ...
    // Callbacks
    on_node_selected: Option<CallbackSlot<NodeCallback>>,
    on_node_right_clicked: Option<CallbackSlot<NodeScreenCallback>>,
    on_node_hovered: Option<CallbackSlot<HoverCallback>>,
    on_labels_updated: Option<CallbackSlot<LabelsCallback>>,
    // Cached CStrings for callback UUID delivery (avoids per-frame allocation)
    uuid_cache: Vec<CString>,
}
```

**Step 2: Wire callbacks into mouse handlers**

Update `mouse_down` to fire callbacks:

```rust
pub fn mouse_down(&mut self, x: f32, y: f32, button: u8) {
    let world = self.screen_to_world(x, y);
    let hit = self.hit_test(world);

    if button == 0 {
        self.selected_node_id = hit;
        self.fire_node_selected(hit);
    } else if button == 1 {
        if let Some(node_id) = hit {
            self.fire_node_right_clicked(node_id, x, y);
        }
    }
}

fn fire_node_selected(&self, node_id: Option<u32>) {
    let Some(cb) = &self.on_node_selected else { return };
    match node_id {
        Some(id) => {
            if let Some(node) = self.graph.nodes.iter().find(|n| n.id == id) {
                let cstr = CString::new(node.uuid.as_str()).unwrap_or_default();
                (cb.func)(cstr.as_ptr(), cb.context);
            }
        }
        None => {
            (cb.func)(std::ptr::null(), cb.context);
        }
    }
}

fn fire_node_right_clicked(&self, node_id: u32, screen_x: f32, screen_y: f32) {
    let Some(cb) = &self.on_node_right_clicked else { return };
    if let Some(node) = self.graph.nodes.iter().find(|n| n.id == node_id) {
        let cstr = CString::new(node.uuid.as_str()).unwrap_or_default();
        (cb.func)(cstr.as_ptr(), screen_x, screen_y, cb.context);
    }
}
```

Update `mouse_moved`:

```rust
pub fn mouse_moved(&mut self, x: f32, y: f32) {
    let world = self.screen_to_world(x, y);
    let hit = self.hit_test(world);
    if hit != self.hovered_node_id {
        self.hovered_node_id = hit;
        self.fire_node_hovered(hit);
    }
}

fn fire_node_hovered(&self, node_id: Option<u32>) {
    let Some(cb) = &self.on_node_hovered else { return };
    match node_id {
        Some(id) => {
            if let Some(node) = self.graph.nodes.iter().find(|n| n.id == id) {
                let cstr = CString::new(node.uuid.as_str()).unwrap_or_default();
                (cb.func)(cstr.as_ptr(), cb.context);
            }
        }
        None => {
            (cb.func)(std::ptr::null(), cb.context);
        }
    }
}
```

**Step 3: Fire labels_updated every frame in render()**

Add to Engine after sync_positions, before renderer draw:

```rust
pub fn render(&mut self) {
    self.sync_positions();
    self.fire_labels_updated();  // Project visible node positions to screen
    if let Some(renderer) = &mut self.renderer {
        renderer.update_positions(&self.graph);
        renderer.draw(self.width, self.height);
    }
}

fn fire_labels_updated(&mut self) {
    let Some(cb) = &self.on_labels_updated else { return };
    let renderer = match &self.renderer {
        Some(r) => r,
        None => return,
    };
    let zoom = renderer.camera_zoom;
    let offset = renderer.camera_offset;
    let vp_w = self.width as f32;
    let vp_h = self.height as f32;

    // Rebuild UUID cache if needed
    if self.uuid_cache.len() != self.graph.nodes.len() {
        self.uuid_cache = self.graph.nodes.iter()
            .map(|n| CString::new(n.uuid.as_str()).unwrap_or_default())
            .collect();
    }

    let mut positions: Vec<LabelPosition> = Vec::new();
    for (i, node) in self.graph.nodes.iter().enumerate() {
        if !node.visible { continue; }

        // World → screen
        let sx = (node.pos.x - offset.x) * zoom + vp_w * 0.5;
        let sy = (node.pos.y - offset.y) * zoom + vp_h * 0.5;

        // Skip if off-screen (with generous margin)
        if sx < -100.0 || sx > vp_w + 100.0 || sy < -100.0 || sy > vp_h + 100.0 {
            continue;
        }

        // LOD alpha based on weight
        let base_alpha = if node.weight > 5.0 {
            1.0
        } else if node.weight > 2.0 {
            0.5
        } else {
            0.0
        };
        // Fade all labels at far zoom
        let alpha = base_alpha * (zoom * 2.0).min(1.0);
        if alpha < 0.01 { continue; }

        positions.push(LabelPosition {
            uuid: self.uuid_cache[i].as_ptr(),
            screen_x: sx,
            screen_y: sy,
            radius: node.radius * zoom,
            alpha,
        });
    }

    (cb.func)(positions.as_ptr(), positions.len(), cb.context);
}
```

**Step 4: Add FFI registration functions in lib.rs**

```rust
pub use crate::engine::LabelPosition;

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_on_node_selected(
    ptr: *mut c_void,
    cb: extern "C" fn(*const c_char, *mut c_void),
    ctx: *mut c_void,
) {
    if let Some(engine) = get_engine(ptr) {
        engine.on_node_selected = Some(CallbackSlot { func: cb, context: ctx });
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_on_node_right_clicked(
    ptr: *mut c_void,
    cb: extern "C" fn(*const c_char, f32, f32, *mut c_void),
    ctx: *mut c_void,
) {
    if let Some(engine) = get_engine(ptr) {
        engine.on_node_right_clicked = Some(CallbackSlot { func: cb, context: ctx });
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_on_node_hovered(
    ptr: *mut c_void,
    cb: extern "C" fn(*const c_char, *mut c_void),
    ctx: *mut c_void,
) {
    if let Some(engine) = get_engine(ptr) {
        engine.on_node_hovered = Some(CallbackSlot { func: cb, context: ctx });
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_on_labels_updated(
    ptr: *mut c_void,
    cb: extern "C" fn(*const LabelPosition, usize, *mut c_void),
    ctx: *mut c_void,
) {
    if let Some(engine) = get_engine(ptr) {
        engine.on_labels_updated = Some(CallbackSlot { func: cb, context: ctx });
    }
}
```

**Step 5: Update C header**

```c
// Callback types
typedef void (*GraphNodeCallback)(const char* uuid, void* context);
typedef void (*GraphNodeScreenCallback)(const char* uuid, float screen_x, float screen_y, void* context);
typedef void (*GraphHoverCallback)(const char* uuid_or_null, void* context);

typedef struct {
    const char* uuid;
    float screen_x;
    float screen_y;
    float radius;
    float alpha;
} LabelPosition;

typedef void (*GraphLabelsCallback)(const LabelPosition* positions, size_t count, void* context);

// Callback registration
void graph_engine_set_on_node_selected(GraphEngine* engine, GraphNodeCallback cb, void* ctx);
void graph_engine_set_on_node_right_clicked(GraphEngine* engine, GraphNodeScreenCallback cb, void* ctx);
void graph_engine_set_on_node_hovered(GraphEngine* engine, GraphHoverCallback cb, void* ctx);
void graph_engine_set_on_labels_updated(GraphEngine* engine, GraphLabelsCallback cb, void* ctx);
```

**Step 6: Register callbacks in Swift Coordinator**

In `MetalGraphView.swift`, add static C-callable functions and register them in `makeNSView`:

```swift
// In makeNSView, after engine creation:
let ctx = Unmanaged.passUnretained(context.coordinator).toOpaque()
graph_engine_set_on_node_selected(context.coordinator.engine, { uuid, ctx in
    guard let ctx else { return }
    let coord = Unmanaged<Coordinator>.fromOpaque(ctx).takeUnretainedValue()
    let id: String? = uuid != nil ? String(cString: uuid!) : nil
    DispatchQueue.main.async { coord.handleNodeSelected(id) }
}, ctx)

graph_engine_set_on_node_right_clicked(context.coordinator.engine, { uuid, sx, sy, ctx in
    guard let ctx, let uuid else { return }
    let coord = Unmanaged<Coordinator>.fromOpaque(ctx).takeUnretainedValue()
    let id = String(cString: uuid)
    DispatchQueue.main.async { coord.handleRightClick(id, screenX: CGFloat(sx), screenY: CGFloat(sy)) }
}, ctx)

graph_engine_set_on_node_hovered(context.coordinator.engine, { uuid, ctx in
    guard let ctx else { return }
    let coord = Unmanaged<Coordinator>.fromOpaque(ctx).takeUnretainedValue()
    let id: String? = uuid != nil ? String(cString: uuid!) : nil
    DispatchQueue.main.async { coord.handleHover(id) }
}, ctx)
```

Add handlers to Coordinator:

```swift
/// Reference to graphState for publishing selection changes.
weak var graphStateRef: GraphState?

@MainActor
func handleNodeSelected(_ uuid: String?) {
    graphStateRef?.selectNode(uuid)
}

@MainActor
func handleRightClick(_ uuid: String, screenX: CGFloat, screenY: CGFloat) {
    // TODO: Show context menu (can be wired later)
}

@MainActor
func handleHover(_ uuid: String?) {
    // Update cursor
    if uuid != nil {
        NSCursor.pointingHand.set()
    } else {
        NSCursor.arrow.set()
    }
}
```

Pass graphState reference in makeCoordinator:

```swift
func makeCoordinator() -> Coordinator {
    let coord = Coordinator()
    coord.graphStateRef = graphState
    return coord
}
```

**Step 7: Build and verify**

```bash
cd /Users/jojo/Epistemos/graph-engine && cargo build --release --target aarch64-apple-darwin 2>&1 | tail -5
cd /Users/jojo/Epistemos && xcodebuild -scheme Epistemos build 2>&1 | tail -3
```

**Step 8: Commit**

```bash
git add graph-engine/src/ graph-engine-bridge/ Epistemos/Views/Graph/MetalGraphView.swift
git commit -m "feat: add Rust→Swift callbacks for selection, hover, and labels

Function pointer + void* context pattern. Callbacks fire from render
thread, Swift dispatches to main queue. Labels projected to screen
coordinates with weight-based LOD alpha."
```

---

### Task 5: Highlight Rings for Selected/Hovered Nodes

**Goal:** Render a visual highlight ring around selected and hovered nodes in the Metal pipeline.

**Files:**
- Modify: `graph-engine/src/renderer.rs` (add highlight instances to node draw)

**Step 1: Add highlight rendering to upload/update methods**

After uploading regular node instances, append highlight ring instances for selected and hovered nodes. A highlight ring is a slightly larger circle with lower alpha and a stroke-like appearance.

In `update_positions` (or a new `update_highlights` method), after the main node loop:

```rust
/// Append highlight ring instances after the regular nodes.
/// These are rendered with the same circle SDF shader but larger radius and different color.
fn append_highlights(&self, graph: &Graph, selected: Option<u32>, hovered: Option<u32>, buf: &Buffer, base_count: usize) {
    let ptr = buf.contents() as *mut NodeInstance;
    let mut idx = base_count;

    // Selected ring
    if let Some(sel_id) = selected {
        if let Some(node) = graph.nodes.iter().find(|n| n.id == sel_id && n.visible) {
            let color = node.node_type.color();
            unsafe {
                *ptr.add(idx) = NodeInstance {
                    position: [node.pos.x, node.pos.y],
                    radius: node.radius + 4.0,
                    _pad: 0.0,
                    color: [color[0], color[1], color[2], 0.4],
                };
            }
            idx += 1;
        }
    }

    // Hovered ring (only if different from selected)
    if let Some(hov_id) = hovered {
        if Some(hov_id) != selected {
            if let Some(node) = graph.nodes.iter().find(|n| n.id == hov_id && n.visible) {
                unsafe {
                    *ptr.add(idx) = NodeInstance {
                        position: [node.pos.x, node.pos.y],
                        radius: node.radius + 2.0,
                        _pad: 0.0,
                        color: [1.0, 1.0, 1.0, 0.2],
                    };
                }
                idx += 1;
            }
        }
    }
}
```

Ensure `node_instance_capacity` accounts for +2 extra instances. Update `draw()` to use `node_count + highlight_count`.

**Step 2: Pass selected/hovered state to renderer**

In `engine.rs` `render()`:

```rust
pub fn render(&mut self) {
    self.sync_positions();
    self.fire_labels_updated();
    if let Some(renderer) = &mut self.renderer {
        renderer.update_positions(&self.graph);
        renderer.set_highlights(self.selected_node_id, self.hovered_node_id, &self.graph);
        renderer.draw(self.width, self.height);
    }
}
```

**Step 3: Build, verify, commit**

```bash
cd /Users/jojo/Epistemos/graph-engine && cargo build --release --target aarch64-apple-darwin 2>&1 | tail -5
git add graph-engine/src/
git commit -m "feat: render highlight rings for selected and hovered nodes

Selected: +4px radius, 40% alpha. Hovered: +2px, 20% white glow.
Both use existing circle SDF shader."
```

---

### Task 6: Camera Commands with Frame-Rate Independent Animation

**Goal:** Add reset_camera, center_on_node, fit_all FFI functions with `dt`-based exponential damping.

**Files:**
- Modify: `graph-engine/src/renderer.rs` (add target_offset, target_zoom, last_frame_time, update_camera)
- Modify: `graph-engine/src/engine.rs` (add camera command methods)
- Modify: `graph-engine/src/lib.rs` (add FFI exports)
- Modify: `graph-engine-bridge/graph_engine.h` (add declarations)
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift` (handle pendingResetView, pendingCenterNodeId)

**Step 1: Add camera animation state to Renderer**

```rust
pub struct Renderer {
    // ... existing fields ...
    // Camera animation (frame-rate independent)
    pub target_offset: Vec2,
    pub target_zoom: f32,
    pub is_animating: bool,
    last_frame_time: std::time::Instant,
}
```

Initialize in `new()`:
```rust
target_offset: Vec2::ZERO,
target_zoom: 1.0,
is_animating: false,
last_frame_time: std::time::Instant::now(),
```

**Step 2: Implement frame-rate independent camera update**

```rust
const CAMERA_LAMBDA: f32 = 8.0;

pub fn update_camera(&mut self) {
    let now = std::time::Instant::now();
    let dt = (now - self.last_frame_time).as_secs_f32().min(0.1);
    self.last_frame_time = now;

    if !self.is_animating { return; }

    let t = 1.0 - (-CAMERA_LAMBDA * dt).exp();

    self.camera_offset = self.camera_offset.lerp(self.target_offset, t);
    self.camera_zoom = self.camera_zoom + (self.target_zoom - self.camera_zoom) * t;

    let offset_diff = (self.target_offset - self.camera_offset).length();
    let zoom_diff = (self.target_zoom - self.camera_zoom).abs();
    if offset_diff < 0.1 && zoom_diff < 0.001 {
        self.camera_offset = self.target_offset;
        self.camera_zoom = self.target_zoom;
        self.is_animating = false;
    }
}
```

Call `update_camera()` at the start of `draw()`.

**Step 3: Add camera commands to Engine**

```rust
pub fn reset_camera(&mut self) {
    if let Some(r) = &mut self.renderer {
        r.target_offset = Vec2::ZERO;
        r.target_zoom = 1.0;
        r.is_animating = true;
    }
}

pub fn center_on_node(&mut self, uuid: &str) {
    let node_id = self.graph.uuid_to_id.get(uuid).copied();
    let node_idx = node_id.and_then(|id| self.graph.id_to_index.get(&id).copied());
    if let Some(idx) = node_idx {
        let node = &self.graph.nodes[idx];
        if let Some(r) = &mut self.renderer {
            r.target_offset = node.pos;
            if r.camera_zoom < 1.5 {
                r.target_zoom = 2.0;
            }
            r.is_animating = true;
        }
    }
}

pub fn fit_all(&mut self) {
    let visible: Vec<&crate::types::Node> = self.graph.nodes.iter().filter(|n| n.visible).collect();
    if visible.is_empty() { return; }

    let mut min_x = f32::MAX;
    let mut min_y = f32::MAX;
    let mut max_x = f32::MIN;
    let mut max_y = f32::MIN;
    for n in &visible {
        min_x = min_x.min(n.pos.x);
        min_y = min_y.min(n.pos.y);
        max_x = max_x.max(n.pos.x);
        max_y = max_y.max(n.pos.y);
    }

    let bbox_w = (max_x - min_x).max(100.0);
    let bbox_h = (max_y - min_y).max(100.0);
    let center = Vec2::new((min_x + max_x) * 0.5, (min_y + max_y) * 0.5);

    let vp_w = self.width as f32;
    let vp_h = self.height as f32;
    let zoom_x = vp_w * 0.8 / bbox_w;
    let zoom_y = vp_h * 0.8 / bbox_h;
    let zoom = zoom_x.min(zoom_y).clamp(0.1, 5.0);

    if let Some(r) = &mut self.renderer {
        r.target_offset = center;
        r.target_zoom = zoom;
        r.is_animating = true;
    }
}
```

**Step 4: Add FFI exports and update C header**

```rust
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_reset_camera(ptr: *mut c_void) {
    if let Some(engine) = get_engine(ptr) { engine.reset_camera(); }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_center_on_node(ptr: *mut c_void, uuid: *const c_char) {
    let Some(engine) = get_engine(ptr) else { return };
    if uuid.is_null() { return; }
    let uuid_str = unsafe { CStr::from_ptr(uuid) }.to_string_lossy();
    engine.center_on_node(&uuid_str);
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_fit_all(ptr: *mut c_void) {
    if let Some(engine) = get_engine(ptr) { engine.fit_all(); }
}
```

C header additions:

```c
void graph_engine_reset_camera(GraphEngine* engine);
void graph_engine_center_on_node(GraphEngine* engine, const char* uuid);
void graph_engine_fit_all(GraphEngine* engine);
```

**Step 5: Wire Swift triggers**

In `MetalGraphView updateNSView`, add:

```swift
// Camera commands
if graphState.pendingResetView, let engine = coordinator.engine {
    graph_engine_reset_camera(engine)
    graphState.pendingResetView = false
}
if let nodeId = graphState.pendingCenterNodeId, let engine = coordinator.engine {
    nodeId.withCString { ptr in
        graph_engine_center_on_node(engine, ptr)
    }
    graphState.pendingCenterNodeId = nil
}
```

In `loadGraphData`, after `graph_engine_commit`:

```swift
graph_engine_fit_all(engine)
```

**Step 6: Build, verify, commit**

```bash
cd /Users/jojo/Epistemos/graph-engine && cargo build --release --target aarch64-apple-darwin 2>&1 | tail -5
cd /Users/jojo/Epistemos && xcodebuild -scheme Epistemos build 2>&1 | tail -3
git add graph-engine/src/ graph-engine-bridge/ Epistemos/Views/Graph/
git commit -m "feat: add camera commands with frame-rate independent animation

reset_camera, center_on_node, fit_all with continuous exponential
damping (lambda=8.0, dt-based). Identical speed on 60Hz and 120Hz."
```

---

### Task 7: Text Label Overlay (Swift CATextLayer)

**Goal:** Create GraphLabelOverlay NSView with CATextLayer pool, positioned by on_labels_updated callback.

**Files:**
- Create: `Epistemos/Views/Graph/GraphLabelOverlay.swift`
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift` (register labels callback, create overlay)
- Modify: `Epistemos/Views/Graph/GraphWindowView.swift` (add overlay as sibling)

**Step 1: Create GraphLabelOverlay.swift**

```swift
import AppKit
import QuartzCore

/// Transparent NSView overlaid on MTKView. Owns a pool of CATextLayer instances
/// positioned every frame by the Rust engine's on_labels_updated callback.
final class GraphLabelOverlay: NSView {
    private var layerPool: [String: CATextLayer] = [:]
    private var activeUUIDs: Set<String> = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.isGeometryFlipped = true  // Match MTKView Y-down coordinate system
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Called every frame from the Rust callback (dispatched to main queue).
    func updateLabels(positions: [(uuid: String, x: CGFloat, y: CGFloat, radius: CGFloat, alpha: Float)]) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var newActive = Set<String>()

        for pos in positions {
            newActive.insert(pos.uuid)
            let layer = getOrCreateLayer(uuid: pos.uuid)
            layer.position = CGPoint(x: pos.x, y: pos.y + pos.radius + 4)
            layer.opacity = pos.alpha
        }

        // Hide layers not in the current set
        for uuid in activeUUIDs.subtracting(newActive) {
            layerPool[uuid]?.opacity = 0
        }
        activeUUIDs = newActive

        CATransaction.commit()
    }

    /// Rebuild layer pool from scratch (called on data reload).
    func rebuildPool(labels: [(uuid: String, text: String)]) {
        // Remove all existing layers
        layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        layerPool.removeAll()
        activeUUIDs.removeAll()

        for (uuid, text) in labels {
            let textLayer = makeTextLayer(text: text)
            textLayer.opacity = 0
            layer?.addSublayer(textLayer)
            layerPool[uuid] = textLayer
        }
    }

    private func getOrCreateLayer(uuid: String) -> CATextLayer {
        if let existing = layerPool[uuid] { return existing }
        let textLayer = makeTextLayer(text: "")
        layer?.addSublayer(textLayer)
        layerPool[uuid] = textLayer
        return textLayer
    }

    private func makeTextLayer(text: String) -> CATextLayer {
        let tl = CATextLayer()
        let truncated = text.count > 20 ? String(text.prefix(20)) + "..." : text
        tl.string = truncated
        tl.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        tl.fontSize = 11
        tl.foregroundColor = NSColor.white.cgColor
        tl.shadowColor = NSColor.black.withAlphaComponent(0.6).cgColor
        tl.shadowOffset = CGSize(width: 0, height: 1)
        tl.shadowRadius = 2
        tl.shadowOpacity = 1
        tl.alignmentMode = .center
        tl.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        tl.bounds = CGRect(x: 0, y: 0, width: 150, height: 16)
        tl.anchorPoint = CGPoint(x: 0.5, y: 0) // Anchor at top-center
        return tl
    }
}
```

**Step 2: Wire labels callback in MetalGraphView Coordinator**

Add label overlay reference to Coordinator:

```swift
var labelOverlay: GraphLabelOverlay?
```

Register the callback in `makeNSView` alongside the other callbacks:

```swift
graph_engine_set_on_labels_updated(context.coordinator.engine, { positions, count, ctx in
    guard let ctx, count > 0, let positions else { return }
    let coord = Unmanaged<Coordinator>.fromOpaque(ctx).takeUnretainedValue()
    // Convert to Swift array (copy data before crossing thread boundary)
    var labels: [(uuid: String, x: CGFloat, y: CGFloat, radius: CGFloat, alpha: Float)] = []
    labels.reserveCapacity(count)
    for i in 0..<count {
        let pos = positions[i]
        guard let uuidPtr = pos.uuid else { continue }
        labels.append((
            uuid: String(cString: uuidPtr),
            x: CGFloat(pos.screen_x),
            y: CGFloat(pos.screen_y),
            radius: CGFloat(pos.radius),
            alpha: pos.alpha
        ))
    }
    DispatchQueue.main.async {
        coord.labelOverlay?.updateLabels(positions: labels)
    }
}, ctx)
```

In `loadGraphData`, after commit, rebuild the label pool:

```swift
// Pre-allocate label layers
let labels = store.nodes.values.map { (uuid: $0.id, text: $0.label) }
labelOverlay?.rebuildPool(labels: labels)
```

**Step 3: Add overlay to GraphWindowView**

In `GraphWindowView.swift`, wrap the MetalGraphView in an overlay:

```swift
// Replace the plain MetalGraphView with:
MetalGraphView(graphState: graphState)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay {
        GraphLabelOverlayRepresentable(graphState: graphState)
            .allowsHitTesting(false)
    }
```

Create `GraphLabelOverlayRepresentable` as an NSViewRepresentable that creates the GraphLabelOverlay and passes a reference to the MetalGraphView Coordinator. (The exact wiring depends on how you coordinate between the two NSViewRepresentable — the simplest approach is to store the overlay reference on GraphState.)

**Step 4: Build, verify, commit**

```bash
cd /Users/jojo/Epistemos && xcodebuild -scheme Epistemos build 2>&1 | tail -3
git add Epistemos/Views/Graph/
git commit -m "feat: add CATextLayer label overlay with per-frame positioning

Labels positioned by Rust callback, updated inside CATransaction
with disabled actions. Weight-based LOD alpha. SF Pro 11pt with shadow."
```

---

### Task 8: Thick Anti-Aliased Quad-Strip Edges

**Goal:** Replace 1px hairline edges with instanced quad-strip triangles and SDF anti-aliasing in the fragment shader.

**Files:**
- Modify: `graph-engine/src/renderer.rs` (new EdgeQuadVertex, new shaders, new pipeline, new upload/draw)

**Step 1: Define new edge vertex struct**

Replace `EdgeVertex` with:

```rust
#[repr(C)]
#[derive(Clone, Copy)]
struct EdgeQuadVertex {
    endpoint_a: [f32; 2],
    endpoint_b: [f32; 2],
    perp_sign: f32,     // -1.0 or +1.0
    edge_coord: f32,    // 0.0 (at endpoint) or 1.0 (at other endpoint)
    color: [f32; 4],
}
```

**Step 2: Write new Metal shaders**

Replace the edge shader section in `SHADER_SOURCE`:

```metal
// ── Edge shaders (quad strips with SDF anti-aliasing) ─────────────────

struct EdgeQuadVertex {
    float2 endpoint_a;   // offset 0
    float2 endpoint_b;   // offset 8
    float  perp_sign;    // offset 16: -1.0 or +1.0
    float  edge_coord;   // offset 20: interpolated across width
    float4 color;        // offset 24
};

struct EdgeVertexOut {
    float4 position [[position]];
    float4 color;
    float  edge_coord;   // For AA: -1 to +1 across line width
};

vertex EdgeVertexOut edge_vertex(
    uint vertex_id [[vertex_id]],
    constant EdgeQuadVertex* verts [[buffer(0)]],
    constant Uniforms& u [[buffer(1)]]
) {
    EdgeQuadVertex v = verts[vertex_id];

    // Transform both endpoints to NDC
    float2 a_screen = (v.endpoint_a - u.camera_offset) * u.camera_zoom;
    float2 b_screen = (v.endpoint_b - u.camera_offset) * u.camera_zoom;
    float2 a_ndc = a_screen / (u.viewport_size * 0.5) * float2(1, -1);
    float2 b_ndc = b_screen / (u.viewport_size * 0.5) * float2(1, -1);

    // Direction and perpendicular in screen space
    float2 dir = b_ndc - a_ndc;
    float len = length(dir);
    float2 norm_dir = len > 0.0001 ? dir / len : float2(0, 1);
    float2 perp = float2(-norm_dir.y, norm_dir.x);

    // Thickness: 1.5px base, in NDC units
    float thickness_px = clamp(1.5, 0.5, 3.0);
    float2 offset = perp * v.perp_sign * thickness_px / u.viewport_size;

    // Pick base position: edge_coord 0.0 = endpoint A, 1.0 = endpoint B
    float2 base_ndc = mix(a_ndc, b_ndc, v.edge_coord);

    EdgeVertexOut out;
    out.position = float4(base_ndc + offset, 0.0, 1.0);
    out.color = v.color;
    out.edge_coord = v.perp_sign; // -1 to +1 across width
    return out;
}

fragment float4 edge_fragment(EdgeVertexOut in [[stage_in]]) {
    // SDF anti-aliasing: smooth falloff at edges
    float dist = abs(in.edge_coord);
    float aa_alpha = 1.0 - smoothstep(0.7, 1.0, dist);
    return float4(in.color.rgb, in.color.a * aa_alpha);
}
```

**Step 3: Update edge buffer allocation and upload**

Change from 2 vertices per edge to 6 vertices per edge (2 triangles). Each edge becomes a quad strip:

```rust
// 6 vertices per edge: two triangles forming a quad
// Triangle 1: A-left, A-right, B-left
// Triangle 2: B-left, A-right, B-right
fn build_edge_quad_vertices(a: [f32; 2], b: [f32; 2], color: [f32; 4]) -> [EdgeQuadVertex; 6] {
    [
        EdgeQuadVertex { endpoint_a: a, endpoint_b: b, perp_sign: -1.0, edge_coord: 0.0, color },
        EdgeQuadVertex { endpoint_a: a, endpoint_b: b, perp_sign:  1.0, edge_coord: 0.0, color },
        EdgeQuadVertex { endpoint_a: a, endpoint_b: b, perp_sign: -1.0, edge_coord: 1.0, color },
        EdgeQuadVertex { endpoint_a: a, endpoint_b: b, perp_sign: -1.0, edge_coord: 1.0, color },
        EdgeQuadVertex { endpoint_a: a, endpoint_b: b, perp_sign:  1.0, edge_coord: 0.0, color },
        EdgeQuadVertex { endpoint_a: a, endpoint_b: b, perp_sign:  1.0, edge_coord: 1.0, color },
    ]
}
```

Update `allocate_buffers` to account for 6 vertices per edge. Update `upload_graph` and `update_positions` to use the new vertex format. Edge color comes from source node type at 40% opacity.

Change `draw()` to use `MTLPrimitiveType::Triangle` instead of `MTLPrimitiveType::Line`.

**Step 4: Build, verify, commit**

```bash
cd /Users/jojo/Epistemos/graph-engine && cargo build --release --target aarch64-apple-darwin 2>&1 | tail -5
cd /Users/jojo/Epistemos && xcodebuild -scheme Epistemos build 2>&1 | tail -3
git add graph-engine/src/renderer.rs
git commit -m "feat: thick anti-aliased quad-strip edges with SDF fragment shader

Replaces 1px hairline edges with 6-vertex quad strips. Perpendicular
expansion in clip space for zoom-invariant thickness. Smoothstep AA
in fragment shader. Edge color from source node type at 40% opacity."
```

---

### Task 9: Integration Test — Full Pipeline Verification

**Goal:** Verify the complete pipeline works end-to-end: load data, render, interact, filter, animate camera.

**Files:**
- Test manually: run app, verify graph renders with thick edges, click nodes, toggle filters, reset camera

**Step 1: Build everything clean**

```bash
cd /Users/jojo/Epistemos/graph-engine && cargo build --release --target aarch64-apple-darwin 2>&1 | tail -5
cd /Users/jojo/Epistemos && xcodebuild -scheme Epistemos clean build 2>&1 | tail -5
```

**Step 2: Run the Rust test suite**

```bash
cd /Users/jojo/Epistemos/graph-engine && cargo test 2>&1
```

Expected: All physics tests pass (two_nodes_repel, connected_nodes_attract, simulation_settles, reheat_restarts_simulation).

**Step 3: Verify no memory leaks in GPU allocation**

Run with Metal validation:
```bash
METAL_DEVICE_WRAPPER_TYPE=1 xcodebuild -scheme Epistemos build 2>&1 | tail -5
```

**Step 4: Commit any fixes**

If any issues found, fix and commit individually.

**Step 5: Final commit**

```bash
git add -A
git commit -m "chore: integration verification — all interactive features wired"
```

---

## Task Dependency Graph

```
Task 0 (GPU buffers) ──┬── Task 1 (visibility) ──── Task 2 (Swift filter wire)
                       │
                       ├── Task 3 (hit testing) ──── Task 4 (callbacks) ──── Task 5 (highlights)
                       │                                       │
                       │                                       └── Task 7 (labels)
                       │
                       ├── Task 6 (camera commands)
                       │
                       └── Task 8 (thick edges)

                       All ──── Task 9 (integration test)
```

Tasks 1, 3, 6, 8 can be parallelized after Task 0. Tasks 2, 4, 5, 7 have sequential dependencies.
