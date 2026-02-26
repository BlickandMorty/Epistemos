# Rust Graph Engine Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a high-performance knowledge graph engine in Rust with direct Metal rendering, integrated into the Epistemos macOS app via C FFI.

**Architecture:** Rust static library (`libgraph_engine.a`) owns the graph data model, Barnes-Hut force simulation (dedicated OS thread), and Metal rendering. Swift passes data via C FFI, forwards mouse/trackpad events, and displays the Metal output through an MTKView.

**Tech Stack:** Rust 1.93, metal-rs, glam (SIMD math), parking_lot (mutexes), Swift 6, SwiftUI, MetalKit

**Design Doc:** `docs/plans/2026-02-26-rust-graph-engine-design.md`

---

### Task 0: Restore to Pre-Graph Codebase

**Goal:** Clean slate — remove all SpriteKit graph code by restoring to commit `111aefe`.

**Files:**
- Modify: entire working tree (git reset)

**Step 1: Create a new branch from the pre-graph commit**

```bash
git checkout -b feat/rust-graph-engine 111aefe
```

This creates a branch from the last commit before any graph code was added (Writer Mode toggle). All SpriteKit graph files, SDGraphNode/SDGraphEdge models, ForceSimulation, etc. are gone.

**Step 2: Verify clean state**

```bash
git log --oneline -3
```

Expected: Top commit is `111aefe feat(writer): wire Writer Mode toggle into note toolbar`

```bash
ls Epistemos/Graph/ 2>/dev/null || echo "No Graph directory — clean"
ls Epistemos/Views/Graph/ 2>/dev/null || echo "No Graph views — clean"
```

Expected: Both say "clean"

**Step 3: Verify the app builds**

```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`

**Step 4: Commit (no-op, just to mark the branch start)**

No commit needed — the branch already starts from the right point.

---

### Task 1: Scaffold Rust Crate and Build Integration

**Goal:** Create the `graph-engine` Rust crate, build script, C bridging header, and Xcode build phase so that `cargo build` runs as part of the Xcode build and the static library links correctly.

**Files:**
- Create: `graph-engine/Cargo.toml`
- Create: `graph-engine/src/lib.rs` (minimal FFI stub)
- Create: `graph-engine/src/engine.rs` (empty Engine struct)
- Create: `graph-engine-bridge/graph_engine.h` (C header)
- Create: `build-rust.sh`
- Modify: Xcode project (add build phase, bridging header, link library)

**Step 1: Create Cargo.toml**

Create `graph-engine/Cargo.toml`:

```toml
[package]
name = "graph-engine"
version = "0.1.0"
edition = "2024"

[lib]
crate-type = ["staticlib"]

[dependencies]
metal = "0.31"
glam = { version = "0.29", features = ["fast-math"] }
parking_lot = "0.12"
rustc-hash = "2.1"

[profile.release]
opt-level = 3
lto = "thin"
```

**Step 2: Create minimal lib.rs with FFI stub**

Create `graph-engine/src/lib.rs`:

```rust
mod engine;

use std::ffi::c_void;

/// Create a new graph engine. Returns an opaque pointer.
/// `metal_device` and `metal_layer` are raw pointers from Swift.
#[no_mangle]
pub extern "C" fn graph_engine_create(
    _metal_device: *mut c_void,
    _metal_layer: *mut c_void,
) -> *mut c_void {
    let engine = Box::new(engine::Engine::new());
    Box::into_raw(engine) as *mut c_void
}

/// Destroy the engine and free memory.
#[no_mangle]
pub extern "C" fn graph_engine_destroy(ptr: *mut c_void) {
    if !ptr.is_null() {
        unsafe { drop(Box::from_raw(ptr as *mut engine::Engine)) };
    }
}

/// Render one frame. Called by MTKViewDelegate.draw().
#[no_mangle]
pub extern "C" fn graph_engine_render(ptr: *mut c_void) {
    if ptr.is_null() { return; }
    let engine = unsafe { &mut *(ptr as *mut engine::Engine) };
    engine.render();
}

/// Resize the viewport.
#[no_mangle]
pub extern "C" fn graph_engine_resize(ptr: *mut c_void, width: u32, height: u32) {
    if ptr.is_null() { return; }
    let engine = unsafe { &mut *(ptr as *mut engine::Engine) };
    engine.resize(width, height);
}
```

**Step 3: Create minimal engine.rs**

Create `graph-engine/src/engine.rs`:

```rust
pub struct Engine {
    width: u32,
    height: u32,
}

impl Engine {
    pub fn new() -> Self {
        Self {
            width: 800,
            height: 600,
        }
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        self.width = width;
        self.height = height;
    }

    pub fn render(&mut self) {
        // Placeholder — Metal rendering comes in Task 5
    }
}
```

**Step 4: Create C bridging header**

Create `graph-engine-bridge/graph_engine.h`:

```c
#ifndef graph_engine_h
#define graph_engine_h

#include <stdint.h>
#include <stddef.h>

// Opaque engine handle
typedef void GraphEngine;

// Lifecycle
GraphEngine* graph_engine_create(void* metal_device, void* metal_layer);
void graph_engine_destroy(GraphEngine* engine);
void graph_engine_resize(GraphEngine* engine, uint32_t width, uint32_t height);

// Render
void graph_engine_render(GraphEngine* engine);

#endif /* graph_engine_h */
```

**Step 5: Create build script**

Create `build-rust.sh`:

```bash
#!/bin/bash
set -e

cd "$(dirname "$0")/graph-engine"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --target aarch64-apple-darwin
    LIB_PATH="target/aarch64-apple-darwin/debug/libgraph_engine.a"
else
    cargo build --release --target aarch64-apple-darwin
    LIB_PATH="target/aarch64-apple-darwin/release/libgraph_engine.a"
fi

# Copy to a stable path that Xcode can reference
mkdir -p ../build-rust
cp "$LIB_PATH" ../build-rust/libgraph_engine.a
```

```bash
chmod +x build-rust.sh
```

**Step 6: Build the Rust library manually to verify**

```bash
cd graph-engine && cargo build --release --target aarch64-apple-darwin 2>&1
```

Expected: Compiles successfully, produces `target/aarch64-apple-darwin/release/libgraph_engine.a`

```bash
ls -la target/aarch64-apple-darwin/release/libgraph_engine.a
```

Expected: File exists

```bash
cd ..
```

**Step 7: Configure Xcode project**

This step requires manual Xcode configuration or a script. The following must be done:

1. Add a "Run Script" build phase **before** "Compile Sources" that runs `"${SRCROOT}/build-rust.sh"`
2. Set the Objective-C Bridging Header build setting to `graph-engine-bridge/graph_engine.h`
3. Add `build-rust/libgraph_engine.a` to "Link Binary With Libraries" build phase
4. Add `build-rust/` to Library Search Paths (build setting `LIBRARY_SEARCH_PATHS`)
5. Add `graph-engine-bridge/` to Header Search Paths (build setting `HEADER_SEARCH_PATHS`)

Use a Ruby script with the `xcodeproj` gem to automate this:

```bash
ruby -e '
require "xcodeproj"
proj = Xcodeproj::Project.open("Epistemos.xcodeproj")
target = proj.targets.find { |t| t.name == "Epistemos" }

# 1. Add Run Script phase for Rust build
phase = target.new_shell_script_build_phase("Build Rust Engine")
phase.shell_script = "\"${SRCROOT}/build-rust.sh\""
# Move to before Compile Sources
compile_idx = target.build_phases.index { |p| p.is_a?(Xcodeproj::Project::Object::PBXSourcesBuildPhase) }
target.build_phases.move(phase, compile_idx)

# 2. Set bridging header
target.build_configurations.each do |config|
  config.build_settings["SWIFT_OBJC_BRIDGING_HEADER"] = "graph-engine-bridge/graph_engine.h"
  config.build_settings["LIBRARY_SEARCH_PATHS"] ||= ["$(inherited)"]
  config.build_settings["LIBRARY_SEARCH_PATHS"] << "$(SRCROOT)/build-rust"
  config.build_settings["HEADER_SEARCH_PATHS"] ||= ["$(inherited)"]
  config.build_settings["HEADER_SEARCH_PATHS"] << "$(SRCROOT)/graph-engine-bridge"
end

# 3. Add static library to link phase
lib_ref = proj.new_file("build-rust/libgraph_engine.a")
target.frameworks_build_phase.add_file_reference(lib_ref)

proj.save
'
```

**Step 8: Run the build script then build the full Xcode project**

```bash
bash build-rust.sh
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`. Rust library compiles and links with Swift.

**Step 9: Commit**

```bash
git add graph-engine/ graph-engine-bridge/ build-rust.sh
git add Epistemos.xcodeproj/project.pbxproj
git commit -m "feat(graph): scaffold Rust graph-engine crate with Xcode build integration"
```

---

### Task 2: Swift MetalGraphView Shell

**Goal:** Create the Swift side of the integration — an MTKView wrapped in NSViewRepresentable that creates the Rust engine, calls render() each frame, and forwards mouse/trackpad events.

**Files:**
- Create: `Epistemos/Views/Graph/MetalGraphView.swift`
- Create: `Epistemos/Views/Graph/GraphWindowView.swift`
- Modify: `Epistemos/App/EpistemosApp.swift` (add Graph window scene)
- Modify: Xcode project (register new files)

**Step 1: Create MetalGraphView.swift**

Create `Epistemos/Views/Graph/MetalGraphView.swift`:

```swift
import SwiftUI
import MetalKit

struct MetalGraphView: NSViewRepresentable {
    func makeNSView(context: Context) -> GraphMTKView {
        let view = GraphMTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        return view
    }

    func updateNSView(_ nsView: GraphMTKView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var engine: OpaquePointer?

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            if let engine {
                graph_engine_resize(engine, UInt32(size.width), UInt32(size.height))
            }
        }

        func draw(in view: MTKView) {
            // Create engine lazily on first draw (Metal device is guaranteed available)
            if engine == nil, let device = view.device,
               let layer = view.layer as? CAMetalLayer {
                let devicePtr = Unmanaged.passUnretained(device).toOpaque()
                let layerPtr = Unmanaged.passUnretained(layer).toOpaque()
                engine = OpaquePointer(graph_engine_create(devicePtr, layerPtr))

                let size = view.drawableSize
                graph_engine_resize(engine, UInt32(size.width), UInt32(size.height))
            }

            if let engine {
                graph_engine_render(engine)
            }
        }

        deinit {
            if let engine {
                graph_engine_destroy(OpaquePointer(engine))
            }
        }
    }
}

/// MTKView subclass that accepts first responder and forwards input events to Rust.
class GraphMTKView: MTKView {
    var engine: OpaquePointer? {
        (delegate as? MetalGraphView.Coordinator)?.engine
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    // Mouse / trackpad events forwarded to Rust — added in Task 6
}
```

**Step 2: Create GraphWindowView.swift**

Create `Epistemos/Views/Graph/GraphWindowView.swift`:

```swift
import SwiftUI

struct GraphWindowView: View {
    var body: some View {
        MetalGraphView()
            .frame(minWidth: 600, minHeight: 400)
    }
}
```

**Step 3: Add Graph window to EpistemosApp.swift**

Add a new Window scene to `EpistemosApp.swift`. Find the closing brace of the existing `body: some Scene` and add before it:

```swift
Window("Knowledge Graph", id: "graph") {
    GraphWindowView()
}
.defaultSize(width: 1000, height: 700)
```

**Step 4: Register new Swift files in Xcode project**

```bash
ruby -e '
require "xcodeproj"
proj = Xcodeproj::Project.open("Epistemos.xcodeproj")
target = proj.targets.find { |t| t.name == "Epistemos" }

# Find or create Views/Graph group
views_group = proj.main_group["Epistemos"]["Views"]
graph_group = views_group["Graph"] || views_group.new_group("Graph", "Views/Graph")

# Add files
%w[MetalGraphView.swift GraphWindowView.swift].each do |name|
  path = "Epistemos/Views/Graph/#{name}"
  ref = graph_group.new_reference(name)
  ref.set_source_tree("SOURCE_ROOT")
  ref.set_path(path)
  target.source_build_phase.add_file_reference(ref)
end

proj.save
'
```

**Step 5: Build and verify**

```bash
bash build-rust.sh
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`

**Step 6: Commit**

```bash
git add Epistemos/Views/Graph/MetalGraphView.swift
git add Epistemos/Views/Graph/GraphWindowView.swift
git add Epistemos.xcodeproj/project.pbxproj
git commit -m "feat(graph): add MetalGraphView shell with MTKView and graph window"
```

---

### Task 3: Rust Data Model and FFI Data Loading

**Goal:** Define the Rust graph data model (nodes, edges, types) and the C FFI for loading graph data from Swift.

**Files:**
- Create: `graph-engine/src/types.rs`
- Modify: `graph-engine/src/engine.rs` (add node/edge storage)
- Modify: `graph-engine/src/lib.rs` (add data loading FFI)
- Modify: `graph-engine-bridge/graph_engine.h` (add CNode, CEdge, loading functions)

**Step 1: Create types.rs**

Create `graph-engine/src/types.rs`:

```rust
use glam::Vec2;
use rustc_hash::FxHashMap;

/// Node type enum — mirrors Swift GraphNodeType (13 types)
#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum NodeType {
    Note = 0,
    Folder = 1,
    Idea = 2,
    BrainDump = 3,
    Chat = 4,
    Insight = 5,
    Thinker = 6,
    Paper = 7,
    Book = 8,
    Source = 9,
    Concept = 10,
    Tag = 11,
    Quote = 12,
}

impl NodeType {
    pub fn from_u8(v: u8) -> Self {
        match v {
            0 => Self::Note,
            1 => Self::Folder,
            2 => Self::Idea,
            3 => Self::BrainDump,
            4 => Self::Chat,
            5 => Self::Insight,
            6 => Self::Thinker,
            7 => Self::Paper,
            8 => Self::Book,
            9 => Self::Source,
            10 => Self::Concept,
            11 => Self::Tag,
            12 => Self::Quote,
            _ => Self::Note,
        }
    }

    /// RGBA color for this node type (matches the original SpriteKit colors).
    pub fn color(&self) -> [f32; 4] {
        match self {
            Self::Note =>     [0.39, 0.90, 0.85, 1.0], // systemMint
            Self::Folder =>   [0.64, 0.52, 0.37, 1.0], // systemBrown
            Self::Idea =>     [1.00, 0.84, 0.04, 1.0], // systemYellow
            Self::BrainDump =>[0.35, 0.34, 0.84, 1.0], // systemIndigo
            Self::Chat =>     [1.00, 0.62, 0.04, 1.0], // systemOrange
            Self::Insight =>  [0.69, 0.32, 0.87, 1.0], // systemPurple
            Self::Thinker =>  [1.00, 0.18, 0.33, 1.0], // systemPink
            Self::Paper =>    [0.20, 0.78, 0.35, 1.0], // systemGreen
            Self::Book =>     [0.25, 0.78, 0.76, 1.0], // systemTeal
            Self::Source =>   [0.56, 0.56, 0.58, 1.0], // systemGray
            Self::Concept =>  [0.39, 0.82, 1.00, 1.0], // systemCyan
            Self::Tag =>      [0.46, 0.46, 0.50, 1.0], // tertiaryLabel
            Self::Quote =>    [1.00, 0.84, 0.04, 1.0], // systemYellow
        }
    }
}

/// Internal node representation — u32 IDs for fast lookup.
#[derive(Clone)]
pub struct Node {
    pub id: u32,
    pub uuid: String,
    pub pos: Vec2,
    pub vel: Vec2,
    pub node_type: NodeType,
    pub weight: f32,
    pub label: String,
    pub radius: f32,
}

impl Node {
    pub fn radius_for_weight(weight: f32) -> f32 {
        if weight > 10.0 { 22.0 }
        else if weight > 3.0 { 14.0 }
        else { 8.0 }
    }
}

/// Internal edge representation.
#[derive(Clone)]
pub struct Edge {
    pub source: u32,
    pub target: u32,
    pub edge_type: u8,
    pub weight: f32,
}

/// The graph data store.
pub struct Graph {
    pub nodes: Vec<Node>,
    pub edges: Vec<Edge>,
    pub uuid_to_id: FxHashMap<String, u32>,
    pub id_to_index: FxHashMap<u32, usize>,
    next_id: u32,
}

impl Graph {
    pub fn new() -> Self {
        Self {
            nodes: Vec::new(),
            edges: Vec::new(),
            uuid_to_id: FxHashMap::default(),
            id_to_index: FxHashMap::default(),
            next_id: 0,
        }
    }

    pub fn clear(&mut self) {
        self.nodes.clear();
        self.edges.clear();
        self.uuid_to_id.clear();
        self.id_to_index.clear();
        self.next_id = 0;
    }

    pub fn add_node(&mut self, uuid: String, x: f32, y: f32, node_type: u8, weight: f32, label: String) {
        let id = self.next_id;
        self.next_id += 1;
        let radius = Node::radius_for_weight(weight);
        let node = Node {
            id,
            uuid: uuid.clone(),
            pos: Vec2::new(x, y),
            vel: Vec2::ZERO,
            node_type: NodeType::from_u8(node_type),
            weight,
            label,
            radius,
        };
        let index = self.nodes.len();
        self.uuid_to_id.insert(uuid, id);
        self.id_to_index.insert(id, index);
        self.nodes.push(node);
    }

    pub fn add_edge(&mut self, source_uuid: &str, target_uuid: &str, edge_type: u8, weight: f32) {
        if let (Some(&src), Some(&tgt)) = (self.uuid_to_id.get(source_uuid), self.uuid_to_id.get(target_uuid)) {
            self.edges.push(Edge { source: src, target: tgt, edge_type, weight });
        }
    }
}
```

**Step 2: Update engine.rs to hold the graph**

Replace `graph-engine/src/engine.rs`:

```rust
use crate::types::Graph;

pub struct Engine {
    pub graph: Graph,
    pub width: u32,
    pub height: u32,
}

impl Engine {
    pub fn new() -> Self {
        Self {
            graph: Graph::new(),
            width: 800,
            height: 600,
        }
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        self.width = width;
        self.height = height;
    }

    pub fn render(&mut self) {
        // Placeholder — Metal rendering comes in Task 5
    }
}
```

**Step 3: Add data loading FFI to lib.rs**

Add to `graph-engine/src/lib.rs` (after existing functions):

```rust
use std::ffi::CStr;

/// C-compatible node struct for FFI
#[repr(C)]
pub struct CNode {
    pub id: *const std::ffi::c_char,
    pub x: f32,
    pub y: f32,
    pub node_type: u8,
    pub weight: f32,
    pub label: *const std::ffi::c_char,
}

/// C-compatible edge struct for FFI
#[repr(C)]
pub struct CEdge {
    pub source_id: *const std::ffi::c_char,
    pub target_id: *const std::ffi::c_char,
    pub edge_type: u8,
    pub weight: f32,
}

fn get_engine(ptr: *mut c_void) -> Option<&'static mut engine::Engine> {
    if ptr.is_null() { return None; }
    Some(unsafe { &mut *(ptr as *mut engine::Engine) })
}

#[no_mangle]
pub extern "C" fn graph_engine_clear(ptr: *mut c_void) {
    if let Some(engine) = get_engine(ptr) {
        engine.graph.clear();
    }
}

#[no_mangle]
pub extern "C" fn graph_engine_add_nodes(ptr: *mut c_void, nodes: *const CNode, count: usize) {
    let Some(engine) = get_engine(ptr) else { return };
    let nodes = unsafe { std::slice::from_raw_parts(nodes, count) };
    for node in nodes {
        let uuid = unsafe { CStr::from_ptr(node.id) }.to_string_lossy().to_string();
        let label = unsafe { CStr::from_ptr(node.label) }.to_string_lossy().to_string();
        engine.graph.add_node(uuid, node.x, node.y, node.node_type, node.weight, label);
    }
}

#[no_mangle]
pub extern "C" fn graph_engine_add_edges(ptr: *mut c_void, edges: *const CEdge, count: usize) {
    let Some(engine) = get_engine(ptr) else { return };
    let edges = unsafe { std::slice::from_raw_parts(edges, count) };
    for edge in edges {
        let src = unsafe { CStr::from_ptr(edge.source_id) }.to_string_lossy();
        let tgt = unsafe { CStr::from_ptr(edge.target_id) }.to_string_lossy();
        engine.graph.add_edge(&src, &tgt, edge.edge_type, edge.weight);
    }
}

#[no_mangle]
pub extern "C" fn graph_engine_commit(ptr: *mut c_void) {
    if let Some(engine) = get_engine(ptr) {
        // Start physics simulation — implemented in Task 4
        let _ = engine;
    }
}
```

**Step 4: Update C bridging header**

Replace `graph-engine-bridge/graph_engine.h`:

```c
#ifndef graph_engine_h
#define graph_engine_h

#include <stdint.h>
#include <stddef.h>

typedef void GraphEngine;

typedef struct {
    const char* id;
    float x;
    float y;
    uint8_t node_type;
    float weight;
    const char* label;
} CNode;

typedef struct {
    const char* source_id;
    const char* target_id;
    uint8_t edge_type;
    float weight;
} CEdge;

// Lifecycle
GraphEngine* graph_engine_create(void* metal_device, void* metal_layer);
void graph_engine_destroy(GraphEngine* engine);
void graph_engine_resize(GraphEngine* engine, uint32_t width, uint32_t height);

// Data loading
void graph_engine_clear(GraphEngine* engine);
void graph_engine_add_nodes(GraphEngine* engine, const CNode* nodes, size_t count);
void graph_engine_add_edges(GraphEngine* engine, const CEdge* edges, size_t count);
void graph_engine_commit(GraphEngine* engine);

// Render
void graph_engine_render(GraphEngine* engine);

#endif
```

**Step 5: Build and verify**

```bash
cd graph-engine && cargo build --release --target aarch64-apple-darwin 2>&1 && cd ..
bash build-rust.sh
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`

**Step 6: Commit**

```bash
git add graph-engine/src/types.rs graph-engine/src/engine.rs graph-engine/src/lib.rs
git add graph-engine-bridge/graph_engine.h
git commit -m "feat(graph): add Rust graph data model and FFI data loading"
```

---

### Task 4: Force Simulation with Barnes-Hut

**Goal:** Port the force-directed layout to Rust. Barnes-Hut O(n log n) repulsion, edge attraction, centering force, alpha decay. Runs on a dedicated OS thread.

**Files:**
- Create: `graph-engine/src/physics.rs`
- Modify: `graph-engine/src/engine.rs` (start physics thread on commit)

**Step 1: Write physics tests**

Create `graph-engine/src/physics.rs` with tests at the bottom:

```rust
use glam::Vec2;
use parking_lot::Mutex;
use std::sync::Arc;

// -- Types used by physics --

pub struct PhysicsNode {
    pub pos: Vec2,
    pub vel: Vec2,
    pub weight: f32,
}

pub struct PhysicsEdge {
    pub source: usize,
    pub target: usize,
    pub weight: f32,
}

pub struct PhysicsConfig {
    pub repulsion_strength: f32,
    pub attraction_strength: f32,
    pub centering_strength: f32,
    pub damping: f32,
    pub max_force: f32,
    pub alpha_decay: f32,
    pub alpha_min: f32,
}

impl Default for PhysicsConfig {
    fn default() -> Self {
        Self {
            repulsion_strength: 2000.0,
            attraction_strength: 0.01,
            centering_strength: 0.008,
            damping: 0.4,
            max_force: 100.0,
            alpha_decay: 0.05,
            alpha_min: 0.001,
        }
    }
}

// -- Simulation --

pub struct Simulation {
    nodes: Vec<PhysicsNode>,
    edges: Vec<PhysicsEdge>,
    alpha: f32,
    sleeping: bool,
    config: PhysicsConfig,
}

impl Simulation {
    pub fn new(config: PhysicsConfig) -> Self {
        Self {
            nodes: Vec::new(),
            edges: Vec::new(),
            alpha: 1.0,
            sleeping: false,
            config,
        }
    }

    pub fn load(&mut self, nodes: Vec<PhysicsNode>, edges: Vec<PhysicsEdge>) {
        self.nodes = nodes;
        self.edges = edges;
        self.alpha = 1.0;
        self.sleeping = false;
    }

    pub fn is_sleeping(&self) -> bool {
        self.sleeping
    }

    pub fn positions(&self) -> Vec<Vec2> {
        self.nodes.iter().map(|n| n.pos).collect()
    }

    pub fn tick(&mut self) {
        if self.sleeping { return; }
        let n = self.nodes.len();
        if n < 2 {
            self.sleeping = true;
            return;
        }

        // Alpha decay
        self.alpha += (0.0 - self.alpha) * self.config.alpha_decay;
        if self.alpha < self.config.alpha_min {
            self.sleeping = true;
            for node in &mut self.nodes {
                node.vel = Vec2::ZERO;
            }
            return;
        }

        // Repulsion (Barnes-Hut for large graphs, direct for small)
        if n < 2000 {
            self.direct_repulsion();
        } else {
            self.quad_tree_repulsion();
        }

        // Edge attraction
        let alpha = self.alpha;
        let strength = self.config.attraction_strength;
        for edge in &self.edges {
            let delta = self.nodes[edge.target].pos - self.nodes[edge.source].pos;
            let force = delta * strength * edge.weight * alpha;
            self.nodes[edge.source].vel += force;
            self.nodes[edge.target].vel -= force;
        }

        // Centering
        let centroid: Vec2 = self.nodes.iter().map(|n| n.pos).sum::<Vec2>() / n as f32;
        let center_force = centroid * self.config.centering_strength * alpha;
        for node in &mut self.nodes {
            node.vel -= center_force;
        }

        // Apply velocities + damping
        let damping = self.config.damping;
        for node in &mut self.nodes {
            node.vel *= damping;
            node.pos += node.vel;
        }
    }

    fn direct_repulsion(&mut self) {
        let n = self.nodes.len();
        let strength = self.config.repulsion_strength * self.alpha;
        let max_f = self.config.max_force;

        for i in 0..n {
            for j in (i + 1)..n {
                let delta = self.nodes[i].pos - self.nodes[j].pos;
                let dist_sq = delta.length_squared().max(1.0);
                let magnitude = (strength / dist_sq).min(max_f);
                let force = delta.normalize_or_zero() * magnitude;
                self.nodes[i].vel += force;
                self.nodes[j].vel -= force;
            }
        }
    }

    fn quad_tree_repulsion(&mut self) {
        let positions: Vec<Vec2> = self.nodes.iter().map(|n| n.pos).collect();
        let tree = QuadTree::build(&positions);
        let strength = self.config.repulsion_strength * self.alpha;
        let theta: f32 = 0.8;

        for i in 0..self.nodes.len() {
            let force = tree.calculate_force(positions[i], theta, strength);
            self.nodes[i].vel += force;
        }
    }

    pub fn wake(&mut self) {
        self.alpha = 0.3;
        self.sleeping = false;
    }

    pub fn update_node_position(&mut self, index: usize, pos: Vec2) {
        if index < self.nodes.len() {
            self.nodes[index].pos = pos;
            self.nodes[index].vel = Vec2::ZERO;
            if self.sleeping {
                self.alpha = 0.1;
                self.sleeping = false;
            }
        }
    }
}

// -- Quad Tree (Barnes-Hut) --

struct QuadTree {
    bounds: Bounds,
    center_of_mass: Vec2,
    total_mass: f32,
    children: [Option<Box<QuadTree>>; 4],
    point: Option<Vec2>,
}

struct Bounds {
    min: Vec2,
    max: Vec2,
}

impl Bounds {
    fn width(&self) -> f32 { self.max.x - self.min.x }
    fn center(&self) -> Vec2 { (self.min + self.max) * 0.5 }
}

impl QuadTree {
    fn build(points: &[Vec2]) -> Self {
        if points.is_empty() {
            return Self::empty(Bounds { min: Vec2::ZERO, max: Vec2::ONE });
        }
        let mut min = Vec2::splat(f32::INFINITY);
        let mut max = Vec2::splat(f32::NEG_INFINITY);
        for &p in points {
            min = min.min(p);
            max = max.max(p);
        }
        let pad = Vec2::splat(10.0);
        let mut tree = Self::empty(Bounds { min: min - pad, max: max + pad });
        for &p in points {
            tree.insert(p);
        }
        tree
    }

    fn empty(bounds: Bounds) -> Self {
        Self {
            bounds,
            center_of_mass: Vec2::ZERO,
            total_mass: 0.0,
            children: [None, None, None, None],
            point: None,
        }
    }

    fn is_leaf(&self) -> bool {
        self.children.iter().all(|c| c.is_none())
    }

    fn insert(&mut self, point: Vec2) {
        self.total_mass += 1.0;
        self.center_of_mass = (self.center_of_mass * (self.total_mass - 1.0) + point) / self.total_mass;

        if self.is_leaf() && self.point.is_none() {
            self.point = Some(point);
            return;
        }

        if let Some(existing) = self.point.take() {
            self.insert_into_child(existing);
        }
        self.insert_into_child(point);
    }

    fn insert_into_child(&mut self, point: Vec2) {
        let mid = self.bounds.center();
        let idx = match (point.x < mid.x, point.y < mid.y) {
            (true, false) => 0,   // NW
            (false, false) => 1,  // NE
            (true, true) => 2,    // SW
            (false, true) => 3,   // SE
        };

        if self.children[idx].is_none() {
            let b = &self.bounds;
            let child_bounds = match idx {
                0 => Bounds { min: Vec2::new(b.min.x, mid.y), max: Vec2::new(mid.x, b.max.y) },
                1 => Bounds { min: mid, max: b.max },
                2 => Bounds { min: b.min, max: mid },
                _ => Bounds { min: Vec2::new(mid.x, b.min.y), max: Vec2::new(b.max.x, mid.y) },
            };
            self.children[idx] = Some(Box::new(Self::empty(child_bounds)));
        }
        self.children[idx].as_mut().unwrap().insert(point);
    }

    fn calculate_force(&self, point: Vec2, theta: f32, strength: f32) -> Vec2 {
        if self.total_mass == 0.0 { return Vec2::ZERO; }

        let delta = point - self.center_of_mass;
        let dist_sq = delta.length_squared().max(1.0);
        let dist = dist_sq.sqrt();

        if self.is_leaf() || self.bounds.width() / dist < theta {
            return delta.normalize_or_zero() * strength * self.total_mass / dist_sq;
        }

        let mut force = Vec2::ZERO;
        for child in &self.children {
            if let Some(child) = child {
                force += child.calculate_force(point, theta, strength);
            }
        }
        force
    }
}

// -- Thread-safe wrapper --

pub struct PhysicsThread {
    sim: Arc<Mutex<Simulation>>,
    /// Latest positions, updated by physics thread, read by renderer.
    pub positions: Arc<Mutex<Vec<Vec2>>>,
    handle: Option<std::thread::JoinHandle<()>>,
    running: Arc<std::sync::atomic::AtomicBool>,
}

impl PhysicsThread {
    pub fn new(config: PhysicsConfig) -> Self {
        Self {
            sim: Arc::new(Mutex::new(Simulation::new(config))),
            positions: Arc::new(Mutex::new(Vec::new())),
            handle: None,
            running: Arc::new(std::sync::atomic::AtomicBool::new(false)),
        }
    }

    pub fn load(&self, nodes: Vec<PhysicsNode>, edges: Vec<PhysicsEdge>) {
        let mut sim = self.sim.lock();
        sim.load(nodes, edges);
        *self.positions.lock() = sim.positions();
    }

    pub fn start(&mut self) {
        if self.running.load(std::sync::atomic::Ordering::Relaxed) {
            return;
        }
        self.running.store(true, std::sync::atomic::Ordering::Relaxed);

        let sim = Arc::clone(&self.sim);
        let positions = Arc::clone(&self.positions);
        let running = Arc::clone(&self.running);

        self.handle = Some(std::thread::spawn(move || {
            while running.load(std::sync::atomic::Ordering::Relaxed) {
                let sleeping = {
                    let mut s = sim.lock();
                    if s.is_sleeping() {
                        true
                    } else {
                        s.tick();
                        *positions.lock() = s.positions();
                        false
                    }
                };

                let sleep_ms = if sleeping { 50 } else { 16 };
                std::thread::sleep(std::time::Duration::from_millis(sleep_ms));
            }
        }));
    }

    pub fn stop(&mut self) {
        self.running.store(false, std::sync::atomic::Ordering::Relaxed);
        if let Some(handle) = self.handle.take() {
            let _ = handle.join();
        }
    }

    pub fn wake(&self) {
        self.sim.lock().wake();
    }

    pub fn update_node_position(&self, index: usize, pos: Vec2) {
        self.sim.lock().update_node_position(index, pos);
    }
}

impl Drop for PhysicsThread {
    fn drop(&mut self) {
        self.stop();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn separates_overlapping_nodes() {
        let mut sim = Simulation::new(PhysicsConfig::default());
        sim.load(
            vec![
                PhysicsNode { pos: Vec2::ZERO, vel: Vec2::ZERO, weight: 1.0 },
                PhysicsNode { pos: Vec2::new(1.0, 0.0), vel: Vec2::ZERO, weight: 1.0 },
            ],
            vec![],
        );
        for _ in 0..50 {
            sim.tick();
        }
        let dist = sim.nodes[0].pos.distance(sim.nodes[1].pos);
        assert!(dist > 10.0, "Nodes should be separated, got dist={dist}");
    }

    #[test]
    fn connected_nodes_attract() {
        let mut sim = Simulation::new(PhysicsConfig::default());
        sim.load(
            vec![
                PhysicsNode { pos: Vec2::new(-200.0, 0.0), vel: Vec2::ZERO, weight: 1.0 },
                PhysicsNode { pos: Vec2::new(200.0, 0.0), vel: Vec2::ZERO, weight: 1.0 },
            ],
            vec![PhysicsEdge { source: 0, target: 1, weight: 5.0 }],
        );
        let initial = 400.0f32;
        for _ in 0..100 {
            sim.tick();
        }
        let final_dist = sim.nodes[0].pos.distance(sim.nodes[1].pos);
        assert!(final_dist < initial, "Connected nodes should attract, got dist={final_dist}");
    }

    #[test]
    fn auto_sleeps_when_settled() {
        let mut sim = Simulation::new(PhysicsConfig::default());
        sim.load(
            vec![PhysicsNode { pos: Vec2::ZERO, vel: Vec2::ZERO, weight: 1.0 }],
            vec![],
        );
        for _ in 0..200 {
            sim.tick();
        }
        assert!(sim.is_sleeping(), "Simulation should sleep when settled");
    }

    #[test]
    fn wake_reactivates() {
        let mut sim = Simulation::new(PhysicsConfig::default());
        sim.load(
            vec![PhysicsNode { pos: Vec2::ZERO, vel: Vec2::ZERO, weight: 1.0 }],
            vec![],
        );
        for _ in 0..200 {
            sim.tick();
        }
        assert!(sim.is_sleeping());
        sim.wake();
        assert!(!sim.is_sleeping());
    }
}
```

**Step 2: Run tests**

```bash
cd graph-engine && cargo test 2>&1 && cd ..
```

Expected: All 4 tests pass.

**Step 3: Wire physics into engine.rs**

Update `graph-engine/src/engine.rs`:

```rust
use crate::types::Graph;
use crate::physics::{PhysicsThread, PhysicsConfig, PhysicsNode, PhysicsEdge};

pub struct Engine {
    pub graph: Graph,
    pub physics: PhysicsThread,
    pub width: u32,
    pub height: u32,
}

impl Engine {
    pub fn new() -> Self {
        Self {
            graph: Graph::new(),
            physics: PhysicsThread::new(PhysicsConfig::default()),
            width: 800,
            height: 600,
        }
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        self.width = width;
        self.height = height;
    }

    pub fn commit(&mut self) {
        // Convert graph nodes/edges to physics format
        let nodes: Vec<PhysicsNode> = self.graph.nodes.iter().map(|n| {
            PhysicsNode { pos: n.pos, vel: n.vel, weight: n.weight }
        }).collect();
        let edges: Vec<PhysicsEdge> = self.graph.edges.iter().map(|e| {
            let src_idx = self.graph.id_to_index[&e.source];
            let tgt_idx = self.graph.id_to_index[&e.target];
            PhysicsEdge { source: src_idx, target: tgt_idx, weight: e.weight }
        }).collect();

        self.physics.load(nodes, edges);
        self.physics.start();
    }

    pub fn render(&mut self) {
        // Read latest positions from physics thread
        let positions = self.physics.positions.lock().clone();
        for (i, pos) in positions.iter().enumerate() {
            if i < self.graph.nodes.len() {
                self.graph.nodes[i].pos = *pos;
            }
        }
        // Metal rendering — Task 5
    }
}
```

**Step 4: Update lib.rs commit function**

In `graph-engine/src/lib.rs`, update `graph_engine_commit`:

```rust
#[no_mangle]
pub extern "C" fn graph_engine_commit(ptr: *mut c_void) {
    if let Some(engine) = get_engine(ptr) {
        engine.commit();
    }
}
```

**Step 5: Add `mod physics;` to lib.rs**

At the top of `graph-engine/src/lib.rs`:

```rust
mod engine;
mod types;
mod physics;
```

**Step 6: Build and run tests**

```bash
cd graph-engine && cargo test 2>&1 && cd ..
bash build-rust.sh
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
```

Expected: Tests pass, build succeeds.

**Step 7: Commit**

```bash
git add graph-engine/src/physics.rs graph-engine/src/engine.rs graph-engine/src/lib.rs
git commit -m "feat(graph): add Barnes-Hut force simulation with dedicated physics thread"
```

---

### Task 5: Metal Renderer

**Goal:** Implement the Metal rendering pipeline — instanced circle drawing for nodes, bezier curve edges, with a 2D orthographic camera. This is the biggest task.

**Files:**
- Create: `graph-engine/src/renderer.rs`
- Create: `graph-engine/src/camera.rs`
- Modify: `graph-engine/src/engine.rs` (initialize Metal, call renderer)
- Modify: `graph-engine/src/lib.rs` (pass Metal pointers to engine)

**Step 1: Create camera.rs**

Create `graph-engine/src/camera.rs`:

```rust
use glam::{Mat4, Vec2};

pub struct Camera {
    pub position: Vec2,
    pub scale: f32,
    pub viewport_size: Vec2,
}

impl Camera {
    pub fn new() -> Self {
        Self {
            position: Vec2::ZERO,
            scale: 1.0,
            viewport_size: Vec2::new(800.0, 600.0),
        }
    }

    /// Orthographic projection: world coords → clip coords [-1, 1]
    pub fn view_projection(&self) -> Mat4 {
        let half_w = self.viewport_size.x * 0.5 * self.scale;
        let half_h = self.viewport_size.y * 0.5 * self.scale;
        let left = self.position.x - half_w;
        let right = self.position.x + half_w;
        let bottom = self.position.y - half_h;
        let top = self.position.y + half_h;
        Mat4::orthographic_rh(left, right, bottom, top, -1.0, 1.0)
    }

    pub fn pan(&mut self, dx: f32, dy: f32) {
        self.position.x += dx * self.scale;
        self.position.y += dy * self.scale;
    }

    pub fn zoom(&mut self, factor: f32, focus: Vec2) {
        let old_scale = self.scale;
        self.scale = (self.scale * factor).clamp(0.05, 5.0);
        let scale_change = self.scale / old_scale;
        // Zoom toward focus point
        self.position += (focus - self.position) * (1.0 - scale_change);
    }

    /// Convert screen coordinates to world coordinates
    pub fn screen_to_world(&self, screen: Vec2) -> Vec2 {
        let ndc = Vec2::new(
            (screen.x / self.viewport_size.x) * 2.0 - 1.0,
            1.0 - (screen.y / self.viewport_size.y) * 2.0, // flip Y
        );
        let half_w = self.viewport_size.x * 0.5 * self.scale;
        let half_h = self.viewport_size.y * 0.5 * self.scale;
        Vec2::new(
            self.position.x + ndc.x * half_w,
            self.position.y + ndc.y * half_h,
        )
    }
}
```

**Step 2: Create renderer.rs**

Create `graph-engine/src/renderer.rs`:

This file creates Metal pipeline states, vertex buffers, and draws nodes as instanced circles and edges as line segments. This is the most complex file.

```rust
use metal::*;
use glam::{Vec2, Mat4};
use crate::types::{Graph, Node};
use crate::camera::Camera;

/// GPU-side per-instance node data
#[repr(C)]
#[derive(Clone, Copy)]
struct NodeInstance {
    position: [f32; 2],
    radius: f32,
    color: [f32; 4],
}

/// GPU-side edge vertex
#[repr(C)]
#[derive(Clone, Copy)]
struct EdgeVertex {
    position: [f32; 2],
    color: [f32; 4],
}

/// Uniform buffer for camera transform
#[repr(C)]
#[derive(Clone, Copy)]
struct Uniforms {
    view_projection: [[f32; 4]; 4],
}

const CIRCLE_SEGMENTS: usize = 24;

pub struct Renderer {
    device: Device,
    command_queue: CommandQueue,
    layer: MetalLayer,
    node_pipeline: RenderPipelineState,
    edge_pipeline: RenderPipelineState,
    circle_vertex_buffer: Buffer,
    node_instance_buffer: Option<Buffer>,
    edge_vertex_buffer: Option<Buffer>,
    uniform_buffer: Buffer,
    node_count: usize,
    edge_vertex_count: usize,
}

impl Renderer {
    pub fn new(device_ptr: *mut std::ffi::c_void, layer_ptr: *mut std::ffi::c_void) -> Self {
        let device = unsafe { Device::from_ptr(device_ptr as *mut metal::MTLDevice) };
        let layer = unsafe { MetalLayer::from_ptr(layer_ptr as *mut metal::CAMetalLayer) };

        layer.set_device(&device);
        layer.set_pixel_format(MTLPixelFormat::BGRA8Unorm);
        layer.set_framebuffer_only(true);

        let command_queue = device.new_command_queue();

        // Compile shaders
        let library = device.new_library_with_source(SHADER_SOURCE, &CompileOptions::new())
            .expect("Failed to compile Metal shaders");

        // Node pipeline (instanced circles)
        let node_vert = library.get_function("node_vertex", None).unwrap();
        let node_frag = library.get_function("node_fragment", None).unwrap();
        let node_desc = RenderPipelineDescriptor::new();
        node_desc.set_vertex_function(Some(&node_vert));
        node_desc.set_fragment_function(Some(&node_frag));
        node_desc.color_attachments().object_at(0).unwrap()
            .set_pixel_format(MTLPixelFormat::BGRA8Unorm);
        // Enable alpha blending
        let attachment = node_desc.color_attachments().object_at(0).unwrap();
        attachment.set_blending_enabled(true);
        attachment.set_source_rgb_blend_factor(MTLBlendFactor::SourceAlpha);
        attachment.set_destination_rgb_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
        attachment.set_source_alpha_blend_factor(MTLBlendFactor::One);
        attachment.set_destination_alpha_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);

        let node_pipeline = device.new_render_pipeline_state(&node_desc).unwrap();

        // Edge pipeline (lines)
        let edge_vert = library.get_function("edge_vertex", None).unwrap();
        let edge_frag = library.get_function("edge_fragment", None).unwrap();
        let edge_desc = RenderPipelineDescriptor::new();
        edge_desc.set_vertex_function(Some(&edge_vert));
        edge_desc.set_fragment_function(Some(&edge_frag));
        edge_desc.color_attachments().object_at(0).unwrap()
            .set_pixel_format(MTLPixelFormat::BGRA8Unorm);
        let edge_attachment = edge_desc.color_attachments().object_at(0).unwrap();
        edge_attachment.set_blending_enabled(true);
        edge_attachment.set_source_rgb_blend_factor(MTLBlendFactor::SourceAlpha);
        edge_attachment.set_destination_rgb_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
        edge_attachment.set_source_alpha_blend_factor(MTLBlendFactor::One);
        edge_attachment.set_destination_alpha_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);

        let edge_pipeline = device.new_render_pipeline_state(&edge_desc).unwrap();

        // Circle vertices (unit circle, instanced per node)
        let circle_verts = Self::generate_circle_vertices();
        let circle_vertex_buffer = device.new_buffer_with_data(
            circle_verts.as_ptr() as *const _,
            (circle_verts.len() * std::mem::size_of::<[f32; 2]>()) as u64,
            MTLResourceOptions::StorageModeShared,
        );

        let uniform_buffer = device.new_buffer(
            std::mem::size_of::<Uniforms>() as u64,
            MTLResourceOptions::StorageModeShared,
        );

        Self {
            device,
            command_queue,
            layer,
            node_pipeline,
            edge_pipeline,
            circle_vertex_buffer,
            node_instance_buffer: None,
            edge_vertex_buffer: None,
            uniform_buffer,
            node_count: 0,
            edge_vertex_count: 0,
        }
    }

    fn generate_circle_vertices() -> Vec<[f32; 2]> {
        let mut verts = Vec::with_capacity(CIRCLE_SEGMENTS * 3);
        for i in 0..CIRCLE_SEGMENTS {
            let a0 = (i as f32 / CIRCLE_SEGMENTS as f32) * std::f32::consts::TAU;
            let a1 = ((i + 1) as f32 / CIRCLE_SEGMENTS as f32) * std::f32::consts::TAU;
            verts.push([0.0, 0.0]); // center
            verts.push([a0.cos(), a0.sin()]);
            verts.push([a1.cos(), a1.sin()]);
        }
        verts
    }

    pub fn update_graph(&mut self, graph: &Graph, camera: &Camera) {
        // Build node instance buffer
        self.node_count = graph.nodes.len();
        if self.node_count > 0 {
            let instances: Vec<NodeInstance> = graph.nodes.iter().map(|node| {
                NodeInstance {
                    position: [node.pos.x, node.pos.y],
                    radius: node.radius,
                    color: node.node_type.color(),
                }
            }).collect();

            let size = (instances.len() * std::mem::size_of::<NodeInstance>()) as u64;
            self.node_instance_buffer = Some(self.device.new_buffer_with_data(
                instances.as_ptr() as *const _,
                size,
                MTLResourceOptions::StorageModeShared,
            ));
        }

        // Build edge vertices (line segments with subdivided curves)
        let mut edge_verts: Vec<EdgeVertex> = Vec::new();
        for edge in &graph.edges {
            if let (Some(&src_idx), Some(&tgt_idx)) =
                (graph.id_to_index.get(&edge.source), graph.id_to_index.get(&edge.target))
            {
                let src = &graph.nodes[src_idx];
                let tgt = &graph.nodes[tgt_idx];
                let color = {
                    let mut c = src.node_type.color();
                    c[3] = 0.3; // edge alpha
                    c
                };

                // Simple line segment (can upgrade to bezier later)
                edge_verts.push(EdgeVertex { position: [src.pos.x, src.pos.y], color });
                edge_verts.push(EdgeVertex { position: [tgt.pos.x, tgt.pos.y], color });
            }
        }

        self.edge_vertex_count = edge_verts.len();
        if !edge_verts.is_empty() {
            let size = (edge_verts.len() * std::mem::size_of::<EdgeVertex>()) as u64;
            self.edge_vertex_buffer = Some(self.device.new_buffer_with_data(
                edge_verts.as_ptr() as *const _,
                size,
                MTLResourceOptions::StorageModeShared,
            ));
        }

        // Update uniforms
        let vp = camera.view_projection();
        let uniforms = Uniforms {
            view_projection: vp.to_cols_array_2d(),
        };
        unsafe {
            let ptr = self.uniform_buffer.contents() as *mut Uniforms;
            *ptr = uniforms;
        }
    }

    pub fn draw(&self) {
        let drawable = match self.layer.next_drawable() {
            Some(d) => d,
            None => return,
        };

        let desc = RenderPassDescriptor::new();
        let color = desc.color_attachments().object_at(0).unwrap();
        color.set_texture(Some(drawable.texture()));
        color.set_load_action(MTLLoadAction::Clear);
        color.set_clear_color(MTLClearColor::new(0.07, 0.07, 0.09, 1.0));
        color.set_store_action(MTLStoreAction::Store);

        let cmd_buffer = self.command_queue.new_command_buffer();
        let encoder = cmd_buffer.new_render_command_encoder(desc);

        // Draw edges first (behind nodes)
        if self.edge_vertex_count > 0 {
            if let Some(ref edge_buf) = self.edge_vertex_buffer {
                encoder.set_render_pipeline_state(&self.edge_pipeline);
                encoder.set_vertex_buffer(0, Some(edge_buf), 0);
                encoder.set_vertex_buffer(1, Some(&self.uniform_buffer), 0);
                encoder.draw_primitives(
                    MTLPrimitiveType::Line,
                    0,
                    self.edge_vertex_count as u64,
                );
            }
        }

        // Draw nodes (instanced circles)
        if self.node_count > 0 {
            if let Some(ref instance_buf) = self.node_instance_buffer {
                encoder.set_render_pipeline_state(&self.node_pipeline);
                encoder.set_vertex_buffer(0, Some(&self.circle_vertex_buffer), 0);
                encoder.set_vertex_buffer(1, Some(instance_buf), 0);
                encoder.set_vertex_buffer(2, Some(&self.uniform_buffer), 0);
                encoder.draw_primitives_instanced(
                    MTLPrimitiveType::Triangle,
                    0,
                    (CIRCLE_SEGMENTS * 3) as u64,
                    self.node_count as u64,
                );
            }
        }

        encoder.end_encoding();
        cmd_buffer.present_drawable(&drawable);
        cmd_buffer.commit();
    }
}

// Metal Shading Language source — compiled at runtime.
const SHADER_SOURCE: &str = r#"
#include <metal_stdlib>
using namespace metal;

// === Uniforms ===
struct Uniforms {
    float4x4 viewProjection;
};

// === Node Shaders (instanced circles) ===
struct NodeInstance {
    float2 position;
    float radius;
    float4 color;
};

struct NodeVertexOut {
    float4 position [[position]];
    float4 color;
    float2 localPos; // for anti-aliased circle
};

vertex NodeVertexOut node_vertex(
    uint vid [[vertex_id]],
    uint iid [[instance_id]],
    const device float2* circleVerts [[buffer(0)]],
    const device NodeInstance* instances [[buffer(1)]],
    const device Uniforms& uniforms [[buffer(2)]]
) {
    NodeInstance inst = instances[iid];
    float2 localPos = circleVerts[vid];
    float2 worldPos = inst.position + localPos * inst.radius;

    NodeVertexOut out;
    out.position = uniforms.viewProjection * float4(worldPos, 0.0, 1.0);
    out.color = inst.color;
    out.localPos = localPos;
    return out;
}

fragment float4 node_fragment(NodeVertexOut in [[stage_in]]) {
    float dist = length(in.localPos);
    float alpha = 1.0 - smoothstep(0.85, 1.0, dist);
    return float4(in.color.rgb, in.color.a * alpha);
}

// === Edge Shaders (lines) ===
struct EdgeVertex {
    float2 position;
    float4 color;
};

struct EdgeVertexOut {
    float4 position [[position]];
    float4 color;
};

vertex EdgeVertexOut edge_vertex(
    uint vid [[vertex_id]],
    const device EdgeVertex* verts [[buffer(0)]],
    const device Uniforms& uniforms [[buffer(1)]]
) {
    EdgeVertex v = verts[vid];
    EdgeVertexOut out;
    out.position = uniforms.viewProjection * float4(v.position, 0.0, 1.0);
    out.color = v.color;
    return out;
}

fragment float4 edge_fragment(EdgeVertexOut in [[stage_in]]) {
    return in.color;
}
"#;
```

**Step 3: Wire renderer into engine.rs**

Update `graph-engine/src/engine.rs`:

```rust
use crate::types::Graph;
use crate::physics::{PhysicsThread, PhysicsConfig, PhysicsNode, PhysicsEdge};
use crate::renderer::Renderer;
use crate::camera::Camera;

pub struct Engine {
    pub graph: Graph,
    pub physics: PhysicsThread,
    pub camera: Camera,
    pub renderer: Option<Renderer>,
    pub width: u32,
    pub height: u32,
}

impl Engine {
    pub fn new() -> Self {
        Self {
            graph: Graph::new(),
            physics: PhysicsThread::new(PhysicsConfig::default()),
            camera: Camera::new(),
            renderer: None,
            width: 800,
            height: 600,
        }
    }

    pub fn init_metal(&mut self, device_ptr: *mut std::ffi::c_void, layer_ptr: *mut std::ffi::c_void) {
        self.renderer = Some(Renderer::new(device_ptr, layer_ptr));
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        self.width = width;
        self.height = height;
        self.camera.viewport_size = glam::Vec2::new(width as f32, height as f32);
    }

    pub fn commit(&mut self) {
        let nodes: Vec<PhysicsNode> = self.graph.nodes.iter().map(|n| {
            PhysicsNode { pos: n.pos, vel: n.vel, weight: n.weight }
        }).collect();
        let edges: Vec<PhysicsEdge> = self.graph.edges.iter().map(|e| {
            let src_idx = self.graph.id_to_index[&e.source];
            let tgt_idx = self.graph.id_to_index[&e.target];
            PhysicsEdge { source: src_idx, target: tgt_idx, weight: e.weight }
        }).collect();

        self.physics.load(nodes, edges);
        self.physics.start();
    }

    pub fn render(&mut self) {
        // Read latest positions from physics thread
        let positions = self.physics.positions.lock().clone();
        for (i, pos) in positions.iter().enumerate() {
            if i < self.graph.nodes.len() {
                self.graph.nodes[i].pos = *pos;
            }
        }

        if let Some(ref mut renderer) = self.renderer {
            renderer.update_graph(&self.graph, &self.camera);
            renderer.draw();
        }
    }
}
```

**Step 4: Update lib.rs to pass Metal pointers**

Update `graph_engine_create` in `graph-engine/src/lib.rs`:

```rust
mod engine;
mod types;
mod physics;
mod renderer;
mod camera;

use std::ffi::{c_void, CStr};

#[no_mangle]
pub extern "C" fn graph_engine_create(
    metal_device: *mut c_void,
    metal_layer: *mut c_void,
) -> *mut c_void {
    let mut engine = Box::new(engine::Engine::new());
    engine.init_metal(metal_device, metal_layer);
    Box::into_raw(engine) as *mut c_void
}
```

**Step 5: Build and verify**

```bash
cd graph-engine && cargo build --release --target aarch64-apple-darwin 2>&1 && cd ..
bash build-rust.sh
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`

**Step 6: Commit**

```bash
git add graph-engine/src/renderer.rs graph-engine/src/camera.rs
git add graph-engine/src/engine.rs graph-engine/src/lib.rs
git commit -m "feat(graph): add Metal renderer with instanced nodes and edge lines"
```

---

### Task 6: Input Handling (Mouse, Trackpad, Zoom)

**Goal:** Forward mouse/trackpad events from Swift to Rust, implement hit-testing, node dragging, camera pan/zoom.

**Files:**
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift` (add event forwarding)
- Modify: `graph-engine/src/lib.rs` (add input FFI)
- Modify: `graph-engine/src/engine.rs` (handle input)
- Modify: `graph-engine-bridge/graph_engine.h` (add input declarations)

**Step 1: Add input FFI to lib.rs**

Add to `graph-engine/src/lib.rs`:

```rust
#[no_mangle]
pub extern "C" fn graph_engine_mouse_down(ptr: *mut c_void, x: f32, y: f32, button: u8) {
    if let Some(engine) = get_engine(ptr) {
        engine.mouse_down(x, y, button);
    }
}

#[no_mangle]
pub extern "C" fn graph_engine_mouse_dragged(ptr: *mut c_void, x: f32, y: f32) {
    if let Some(engine) = get_engine(ptr) {
        engine.mouse_dragged(x, y);
    }
}

#[no_mangle]
pub extern "C" fn graph_engine_mouse_up(ptr: *mut c_void) {
    if let Some(engine) = get_engine(ptr) {
        engine.mouse_up();
    }
}

#[no_mangle]
pub extern "C" fn graph_engine_scroll(ptr: *mut c_void, dx: f32, dy: f32) {
    if let Some(engine) = get_engine(ptr) {
        engine.scroll(dx, dy);
    }
}

#[no_mangle]
pub extern "C" fn graph_engine_magnify(ptr: *mut c_void, scale: f32, cx: f32, cy: f32) {
    if let Some(engine) = get_engine(ptr) {
        engine.magnify(scale, cx, cy);
    }
}

// Callbacks
type NodeCallback = extern "C" fn(*const std::ffi::c_char, *mut c_void);

#[no_mangle]
pub extern "C" fn graph_engine_set_on_node_selected(
    ptr: *mut c_void,
    callback: NodeCallback,
    context: *mut c_void,
) {
    if let Some(engine) = get_engine(ptr) {
        engine.on_node_selected = Some((callback, context));
    }
}

#[no_mangle]
pub extern "C" fn graph_engine_set_on_node_right_clicked(
    ptr: *mut c_void,
    callback: NodeCallback,
    context: *mut c_void,
) {
    if let Some(engine) = get_engine(ptr) {
        engine.on_node_right_clicked = Some((callback, context));
    }
}
```

**Step 2: Add input handling to engine.rs**

Add fields and methods to `Engine`:

```rust
use glam::Vec2;
use std::ffi::{c_void, CString};

type NodeCallback = extern "C" fn(*const std::ffi::c_char, *mut c_void);

pub struct Engine {
    pub graph: Graph,
    pub physics: PhysicsThread,
    pub camera: Camera,
    pub renderer: Option<Renderer>,
    pub width: u32,
    pub height: u32,
    // Interaction state
    dragged_node: Option<usize>,
    selected_node: Option<usize>,
    last_mouse: Vec2,
    // Callbacks
    pub on_node_selected: Option<(NodeCallback, *mut c_void)>,
    pub on_node_right_clicked: Option<(NodeCallback, *mut c_void)>,
}

// Add to new():
// dragged_node: None,
// selected_node: None,
// last_mouse: Vec2::ZERO,
// on_node_selected: None,
// on_node_right_clicked: None,

impl Engine {
    // ... existing methods ...

    pub fn mouse_down(&mut self, x: f32, y: f32, button: u8) {
        let screen = Vec2::new(x, y);
        let world = self.camera.screen_to_world(screen);
        self.last_mouse = screen;

        if let Some(idx) = self.hit_test(world) {
            if button == 0 {
                // Left click — select and start drag
                self.dragged_node = Some(idx);
                self.selected_node = Some(idx);
                self.fire_node_selected(idx);
            } else if button == 1 {
                // Right click
                self.fire_node_right_clicked(idx);
            }
        } else {
            self.selected_node = None;
        }
    }

    pub fn mouse_dragged(&mut self, x: f32, y: f32) {
        let screen = Vec2::new(x, y);
        if let Some(idx) = self.dragged_node {
            let world = self.camera.screen_to_world(screen);
            self.graph.nodes[idx].pos = world;
            self.physics.update_node_position(idx, world);
        } else {
            // Pan camera
            let dx = screen.x - self.last_mouse.x;
            let dy = screen.y - self.last_mouse.y;
            self.camera.pan(-dx, dy); // flip Y for screen coords
        }
        self.last_mouse = screen;
    }

    pub fn mouse_up(&mut self) {
        self.dragged_node = None;
    }

    pub fn scroll(&mut self, dx: f32, dy: f32) {
        self.camera.pan(-dx, dy);
    }

    pub fn magnify(&mut self, scale: f32, cx: f32, cy: f32) {
        let focus = self.camera.screen_to_world(Vec2::new(cx, cy));
        self.camera.zoom(1.0 - scale, focus);
    }

    fn hit_test(&self, world_pos: Vec2) -> Option<usize> {
        // Find closest node within its radius
        let mut best: Option<(usize, f32)> = None;
        for (i, node) in self.graph.nodes.iter().enumerate() {
            let dist = node.pos.distance(world_pos);
            if dist <= node.radius * 1.5 { // slight tolerance
                if best.is_none() || dist < best.unwrap().1 {
                    best = Some((i, dist));
                }
            }
        }
        best.map(|(i, _)| i)
    }

    fn fire_node_selected(&self, idx: usize) {
        if let Some((cb, ctx)) = self.on_node_selected {
            let uuid = CString::new(self.graph.nodes[idx].uuid.as_str()).unwrap();
            cb(uuid.as_ptr(), ctx);
        }
    }

    fn fire_node_right_clicked(&self, idx: usize) {
        if let Some((cb, ctx)) = self.on_node_right_clicked {
            let uuid = CString::new(self.graph.nodes[idx].uuid.as_str()).unwrap();
            cb(uuid.as_ptr(), ctx);
        }
    }
}
```

**Step 3: Update C header**

Add to `graph-engine-bridge/graph_engine.h`:

```c
// Input events
void graph_engine_mouse_down(GraphEngine* engine, float x, float y, uint8_t button);
void graph_engine_mouse_dragged(GraphEngine* engine, float x, float y);
void graph_engine_mouse_up(GraphEngine* engine);
void graph_engine_scroll(GraphEngine* engine, float dx, float dy);
void graph_engine_magnify(GraphEngine* engine, float scale, float cx, float cy);

// Callbacks
typedef void (*NodeCallback)(const char* node_id, void* context);
void graph_engine_set_on_node_selected(GraphEngine* engine, NodeCallback callback, void* context);
void graph_engine_set_on_node_right_clicked(GraphEngine* engine, NodeCallback callback, void* context);
```

**Step 4: Add event forwarding to MetalGraphView.swift**

Add to the `GraphMTKView` class in `MetalGraphView.swift`:

```swift
override func mouseDown(with event: NSEvent) {
    guard let engine else { return }
    let loc = convert(event.locationInWindow, from: nil)
    graph_engine_mouse_down(engine, Float(loc.x), Float(bounds.height - loc.y), 0)
}

override func rightMouseDown(with event: NSEvent) {
    guard let engine else { return }
    let loc = convert(event.locationInWindow, from: nil)
    graph_engine_mouse_down(engine, Float(loc.x), Float(bounds.height - loc.y), 1)
}

override func mouseDragged(with event: NSEvent) {
    guard let engine else { return }
    let loc = convert(event.locationInWindow, from: nil)
    graph_engine_mouse_dragged(engine, Float(loc.x), Float(bounds.height - loc.y))
}

override func mouseUp(with event: NSEvent) {
    guard let engine else { return }
    graph_engine_mouse_up(engine)
}

override func scrollWheel(with event: NSEvent) {
    guard let engine else { return }
    if event.modifierFlags.contains(.option) || event.phase == [] {
        // Option+scroll or mouse wheel = zoom
        let loc = convert(event.locationInWindow, from: nil)
        graph_engine_magnify(engine, Float(-event.deltaY * 0.02), Float(loc.x), Float(bounds.height - loc.y))
    } else {
        // Trackpad two-finger scroll = pan
        graph_engine_scroll(engine, Float(event.scrollingDeltaX), Float(event.scrollingDeltaY))
    }
}

override func magnify(with event: NSEvent) {
    guard let engine else { return }
    let loc = convert(event.locationInWindow, from: nil)
    graph_engine_magnify(engine, Float(-event.magnification), Float(loc.x), Float(bounds.height - loc.y))
}
```

**Step 5: Build and verify**

```bash
cd graph-engine && cargo build --release --target aarch64-apple-darwin 2>&1 && cd ..
bash build-rust.sh
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`

**Step 6: Commit**

```bash
git add graph-engine/src/lib.rs graph-engine/src/engine.rs
git add graph-engine-bridge/graph_engine.h
git add Epistemos/Views/Graph/MetalGraphView.swift
git commit -m "feat(graph): add mouse/trackpad input handling with hit-testing and camera"
```

---

### Task 7: SwiftData Graph Models and Structural Builder

**Goal:** Re-create the SwiftData graph node/edge models and the structural builder that extracts graph topology from notes, folders, ideas, chats, and tags.

**Files:**
- Create: `Epistemos/Models/SDGraphNode.swift`
- Create: `Epistemos/Models/SDGraphEdge.swift`
- Create: `Epistemos/Models/GraphTypes.swift`
- Create: `Epistemos/Graph/StructuralGraphBuilder.swift`
- Modify: `Epistemos/App/AppBootstrap+Persistence.swift` (add graph models to schema)

**Note:** These files are re-created from the git history. Use `git show 28c14a5:Epistemos/Models/SDGraphNode.swift` etc. to recover the original implementations, then adapt as needed.

**Step 1: Recover graph models from git history**

```bash
git show 28c14a5:Epistemos/Models/SDGraphNode.swift > Epistemos/Models/SDGraphNode.swift
git show 28c14a5:Epistemos/Models/SDGraphEdge.swift > Epistemos/Models/SDGraphEdge.swift
git show 28c14a5:Epistemos/Models/GraphTypes.swift > Epistemos/Models/GraphTypes.swift
git show 28c14a5:Epistemos/Graph/StructuralGraphBuilder.swift > Epistemos/Graph/StructuralGraphBuilder.swift
```

**Step 2: Remove any SpriteKit-specific references from recovered files**

Check each recovered file for references to SpriteKit, ForceSimulation, GraphStore, FilterEngine, KnowledgeGraphScene, or GraphNodeSprite. Remove any such references. The graph models (SDGraphNode, SDGraphEdge, GraphTypes) should be pure data — no rendering dependencies. StructuralGraphBuilder should only depend on SwiftData models and GraphTypes.

**Step 3: Create Graph directory if needed and register in Xcode project**

```bash
mkdir -p Epistemos/Graph
```

Register all new files in the Xcode project using ruby script.

**Step 4: Add graph models to the SwiftData schema**

In `Epistemos/App/AppBootstrap+Persistence.swift`, find the `Schema` definition and add `SDGraphNode.self` and `SDGraphEdge.self` to the model types array.

**Step 5: Build and verify**

```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`

**Step 6: Commit**

```bash
git add Epistemos/Models/SDGraphNode.swift Epistemos/Models/SDGraphEdge.swift
git add Epistemos/Models/GraphTypes.swift Epistemos/Graph/StructuralGraphBuilder.swift
git add Epistemos.xcodeproj/project.pbxproj
git commit -m "feat(graph): re-add SwiftData graph models and structural builder"
```

---

### Task 8: Wire GraphWindowView to Rust Engine

**Goal:** Connect the SwiftUI GraphWindowView to the Rust engine — load graph data from SwiftData, pass it through FFI, and display the rendered graph.

**Files:**
- Modify: `Epistemos/Views/Graph/GraphWindowView.swift` (add data loading)
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift` (add data loading bridge)
- Modify: `Epistemos/App/EpistemosApp.swift` (ensure graph window has model context)

**Step 1: Create GraphBridge helper**

Create `Epistemos/Views/Graph/GraphBridge.swift` — a Swift wrapper that converts SwiftData models to C structs and calls the FFI:

```swift
import Foundation
import SwiftData

struct GraphBridge {
    static func loadGraph(engine: OpaquePointer, context: ModelContext) {
        graph_engine_clear(engine)

        // Query all graph nodes
        let nodeDescriptor = FetchDescriptor<SDGraphNode>()
        guard let nodes = try? context.fetch(nodeDescriptor) else { return }

        // Convert to C structs
        var cNodes: [CNode] = []
        for node in nodes {
            node.id.utf8CString.withUnsafeBufferPointer { idBuf in
                node.label.utf8CString.withUnsafeBufferPointer { labelBuf in
                    // We need the pointers to stay valid — use a different approach
                }
            }
        }

        // Use withExtendedLifetime approach for stable C string pointers
        let idStrings = nodes.map { $0.id }
        let labelStrings = nodes.map { $0.label }

        idStrings.withContiguousCStrings { idPtrs in
            labelStrings.withContiguousCStrings { labelPtrs in
                var cNodes: [CNode] = []
                for (i, node) in nodes.enumerated() {
                    cNodes.append(CNode(
                        id: idPtrs[i],
                        x: 0, y: 0, // auto-layout
                        node_type: node.type.rawValue,
                        weight: Float(node.weight),
                        label: labelPtrs[i]
                    ))
                }
                cNodes.withUnsafeBufferPointer { buf in
                    graph_engine_add_nodes(engine, buf.baseAddress, buf.count)
                }
            }
        }

        // Query and add edges
        let edgeDescriptor = FetchDescriptor<SDGraphEdge>()
        if let edges = try? context.fetch(edgeDescriptor) {
            let srcStrings = edges.map { $0.sourceNodeId }
            let tgtStrings = edges.map { $0.targetNodeId }

            srcStrings.withContiguousCStrings { srcPtrs in
                tgtStrings.withContiguousCStrings { tgtPtrs in
                    var cEdges: [CEdge] = []
                    for (i, edge) in edges.enumerated() {
                        cEdges.append(CEdge(
                            source_id: srcPtrs[i],
                            target_id: tgtPtrs[i],
                            edge_type: edge.type.rawValue,
                            weight: Float(edge.weight)
                        ))
                    }
                    cEdges.withUnsafeBufferPointer { buf in
                        graph_engine_add_edges(engine, buf.baseAddress, buf.count)
                    }
                }
            }
        }

        graph_engine_commit(engine)
    }
}

// Helper extension for passing arrays of Swift strings as C string arrays
extension Array where Element == String {
    func withContiguousCStrings<R>(_ body: ([UnsafePointer<CChar>]) throws -> R) rethrows -> R {
        let cStrings = self.map { $0.utf8CString }
        return try cStrings.withUnsafeBufferPointers { buffers in
            let ptrs = buffers.map { $0.baseAddress! }
            return try body(ptrs)
        }
    }
}

// Helper for nested buffer access
extension Array where Element == ContiguousArray<CChar> {
    func withUnsafeBufferPointers<R>(_ body: ([UnsafeBufferPointer<CChar>]) throws -> R) rethrows -> R {
        var buffers: [UnsafeBufferPointer<CChar>] = []
        // This requires a recursive approach or manual pin
        // Simplified: just use the strings directly
        return try withExtendedLifetime(self) {
            let ptrs = self.map { arr -> UnsafePointer<CChar> in
                arr.withUnsafeBufferPointer { $0.baseAddress! }
            }
            return try body(self.map { $0.withUnsafeBufferPointer { $0 } })
        }
    }
}
```

**Note:** The C string bridging is tricky. The implementing engineer should test this carefully and may need to simplify the approach — for example, by allocating `strdup` copies and freeing them after the FFI call. The exact approach will depend on what compiles cleanly in Swift 6.

**Step 2: Update MetalGraphView to accept and load data**

Add a `modelContext` parameter or use `.environment(\.modelContext)` to get the SwiftData context, and call `GraphBridge.loadGraph()` after the engine is created.

**Step 3: Update GraphWindowView**

```swift
struct GraphWindowView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        MetalGraphView()
            .frame(minWidth: 600, minHeight: 400)
    }
}
```

**Step 4: Build and verify**

```bash
bash build-rust.sh
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`

**Step 5: Commit**

```bash
git add Epistemos/Views/Graph/GraphBridge.swift
git add Epistemos/Views/Graph/GraphWindowView.swift
git add Epistemos/Views/Graph/MetalGraphView.swift
git commit -m "feat(graph): wire SwiftData graph data to Rust engine via FFI"
```

---

### Task 9: End-to-End Verification

**Goal:** Build the full app, run all tests, verify the graph window opens and renders nodes.

**Step 1: Run Rust tests**

```bash
cd graph-engine && cargo test 2>&1 && cd ..
```

Expected: All physics tests pass.

**Step 2: Build the full app**

```bash
bash build-rust.sh
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`

**Step 3: Run Swift tests**

```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' test 2>&1 | tail -20
```

Expected: All existing tests pass (graph-specific Swift tests will come in a follow-up).

**Step 4: Manual verification checklist**

- [ ] Launch app
- [ ] Open Knowledge Graph window (Cmd+G or menu)
- [ ] Nodes render as colored circles
- [ ] Edges render as lines between nodes
- [ ] Nodes animate into position (physics simulation)
- [ ] Simulation settles (stops moving after a few seconds)
- [ ] Click and drag a node — it moves
- [ ] Two-finger trackpad scroll — camera pans
- [ ] Pinch to zoom — camera zooms
- [ ] Option+scroll — camera zooms
- [ ] Performance: 60fps, GPU active, low CPU usage

**Step 5: Commit and tag**

```bash
git add -A
git commit -m "feat(graph): complete Rust graph engine integration

Rust-powered knowledge graph with:
- Barnes-Hut force simulation on dedicated OS thread
- Direct Metal rendering (instanced nodes, edge lines)
- Camera with pan/zoom via trackpad gestures
- SwiftData integration via C FFI"
```

---

## Summary

| Task | Description | Estimated Effort |
|------|-------------|-----------------|
| 0 | Restore to pre-graph codebase | 5 min |
| 1 | Scaffold Rust crate + Xcode build integration | 30 min |
| 2 | Swift MetalGraphView shell | 20 min |
| 3 | Rust data model + FFI data loading | 20 min |
| 4 | Force simulation with Barnes-Hut + physics thread | 30 min |
| 5 | Metal renderer (instanced nodes, edges, camera) | 45 min |
| 6 | Input handling (mouse, trackpad, zoom) | 25 min |
| 7 | SwiftData graph models + structural builder | 15 min |
| 8 | Wire GraphWindowView to Rust engine | 25 min |
| 9 | End-to-end verification | 15 min |
