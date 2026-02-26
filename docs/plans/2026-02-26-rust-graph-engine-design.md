# Rust Graph Engine Design

**Date**: 2026-02-26
**Status**: Approved
**Replaces**: 2026-02-25-knowledge-graph-design.md (SpriteKit approach, abandoned)

## Context

Three attempts at a Swift-native knowledge graph failed due to Swift 6's strict concurrency model. SKScene inherits `@MainActor` from NSResponder, making it impossible to run physics on a background thread without fighting the compiler. All approaches (actor, @MainActor class, @unchecked Sendable) produced either 5fps rendering or build errors.

## Decision

Build the entire graph engine in Rust, compiled to a static library. Swift feeds data in, forwards mouse events, and displays the Metal output. Rust owns threading — no Swift concurrency involved.

**Restore point**: Git commit `111aefe` (pre-graph, ends at Writer Mode). All SpriteKit graph code is removed; Rust engine is built fresh.

## Architecture

```
SwiftUI Shell (GraphWindowView, filters, context menus)
    │
    ▼
MetalGraphView (NSViewRepresentable → MTKView)
    │
    ▼ C FFI boundary (extern "C" functions)
    │
    ▼
Rust graph-engine crate (libgraph_engine.a)
├── Data Model (nodes, edges, types)
├── Physics (Barnes-Hut, alpha decay, SIMD via glam)
├── Renderer (metal-rs, instanced drawing)
├── Camera (2D ortho, pan/zoom transforms)
└── Threading (physics on dedicated OS thread)
```

## C FFI Contract

```c
// Lifecycle
GraphEngine* graph_engine_create(void* metal_device, void* metal_layer);
void graph_engine_destroy(GraphEngine* engine);
void graph_engine_resize(GraphEngine* engine, uint32_t w, uint32_t h);

// Data loading
void graph_engine_clear(GraphEngine* engine);
void graph_engine_add_nodes(GraphEngine* engine, const CNode* nodes, size_t count);
void graph_engine_add_edges(GraphEngine* engine, const CEdge* edges, size_t count);
void graph_engine_commit(GraphEngine* engine);

// Render (called every frame by MTKViewDelegate)
void graph_engine_render(GraphEngine* engine);

// Input events (Swift NSView → Rust)
void graph_engine_mouse_down(GraphEngine* engine, float x, float y, uint8_t button);
void graph_engine_mouse_dragged(GraphEngine* engine, float x, float y);
void graph_engine_mouse_up(GraphEngine* engine);
void graph_engine_scroll(GraphEngine* engine, float dx, float dy);
void graph_engine_magnify(GraphEngine* engine, float scale, float cx, float cy);

// Callbacks (Rust → Swift)
typedef void (*NodeCallback)(const char* node_id, void* context);
void graph_engine_set_on_node_selected(GraphEngine* engine, NodeCallback cb, void* ctx);
void graph_engine_set_on_node_right_clicked(GraphEngine* engine, NodeCallback cb, void* ctx);
```

## C FFI Structs

```c
typedef struct {
    const char* id;       // UUID string from SwiftData
    float x, y;           // initial position (0,0 for auto-layout)
    uint8_t node_type;    // maps to GraphNodeType enum
    float weight;         // connection count / importance
    const char* label;    // display name
} CNode;

typedef struct {
    const char* source_id;
    const char* target_id;
    uint8_t edge_type;    // maps to GraphEdgeType enum
    float weight;
} CEdge;
```

## Rust Internals

### Data Model
- `Node`: id (u32), position (Vec2), velocity (Vec2), node_type (u8), weight (f32), label (String)
- `Edge`: source (u32), target (u32), edge_type (u8), weight (f32)
- Internal u32 IDs for fast HashMap; UUID strings mapped at FFI boundary

### Physics (dedicated OS thread)
- Barnes-Hut O(n log n) repulsion via quad tree
- Edge spring attraction (Hooke's law)
- Centering force toward origin
- Alpha decay: alpha *= (1 - 0.05) per tick, sleeps below 0.001
- Damping: velocity *= 0.4 per tick
- SIMD via `glam` crate (ARM NEON on Apple Silicon)
- Double-buffered positions: physics writes, renderer reads (lock-free)

### Renderer (main thread, metal-rs)
- Instanced circle drawing: one draw call for all nodes
- Bezier curve edges via compute shader or tessellation
- Orthographic 2D camera with pan/zoom matrix
- LOD bands based on camera zoom level
- Node type → color mapping (same 13 types as before)
- Text labels: Swift pre-renders via CoreText, passes texture atlas to Rust

### Threading
```
Main thread:    MTKViewDelegate.draw() → graph_engine_render() → Metal GPU submit
Physics thread: loop { tick(); write_buffer(); sleep(16ms); }
                Spawned by Rust via std::thread::spawn
```

## Swift Integration

### New Files
- `MetalGraphView.swift`: NSViewRepresentable wrapping MTKView, event forwarding
- `GraphMTKView.swift`: MTKView subclass, mouse/trackpad event → FFI calls
- `GraphBridge.swift`: Swift wrapper around C FFI for ergonomic API

### Retained Files (from pre-graph codebase)
- All SwiftData models, views, and app infrastructure
- GraphWindowView.swift rebuilt to host MetalGraphView instead of SpriteKit

### Removed Files (via git restore to 111aefe)
- All SpriteKit graph code (KnowledgeGraphScene, GraphNodeSprite, etc.)
- ForceSimulation.swift, PositionBuffer.swift
- All graph-related Swift models (SDGraphNode, SDGraphEdge)

## Project Structure

```
Epistemos/
├── Epistemos/                  (Swift app)
│   └── Views/Graph/
│       ├── GraphWindowView.swift
│       ├── MetalGraphView.swift
│       └── GraphBridge.swift
├── graph-engine/               (Rust crate)
│   ├── Cargo.toml
│   ├── build.rs
│   └── src/
│       ├── lib.rs              (FFI exports)
│       ├── engine.rs           (main engine struct)
│       ├── types.rs            (node/edge data model)
│       ├── physics.rs          (force simulation + quad tree)
│       ├── renderer.rs         (Metal rendering pipeline)
│       └── camera.rs           (2D camera + input handling)
├── graph-engine-bridge/
│   └── graph_engine.h          (C bridging header)
└── build-rust.sh               (cargo build --release --target aarch64-apple-darwin)
```

## Build Integration

1. Xcode build phase: Run Script runs `build-rust.sh`
2. Script runs `cargo build --release --target aarch64-apple-darwin`
3. Copies `libgraph_engine.a` to a known path
4. Xcode links the static library
5. C bridging header provides type declarations to Swift

## Key Dependencies (Rust)

- `metal` (metal-rs): Direct Metal API bindings
- `glam`: SIMD math (Vec2, Mat4)
- `parking_lot`: Fast mutexes for double-buffer
- `rustc-hash`: Fast HashMap for node lookup

## Risk Mitigation

- **Text rendering**: Delegated to Swift/CoreText. Rust receives a texture atlas, no font rendering in Rust.
- **FFI complexity**: Kept minimal — flat C structs, no nested pointers, callbacks use function pointer + void* context.
- **Debug cycle**: `cargo build` is fast (~2s incremental). Xcode build phase adds minimal overhead.
- **Metal debugging**: Xcode's Metal debugger works on metal-rs output since it's the same Metal API.
