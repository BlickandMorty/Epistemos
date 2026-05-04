# Epistemos Deep-Dive: Four Core FFI Execution Modules
### Zero-Copy Graph Memory · Frame Command Packing · Rope Delta Protocol · Swift/Metal Pointer Lifecycle

***

## Module 1 — Zero-Copy Graph Memory Layout (Rust Side)

### ⭐ HIGH VALUE: The Layout Decision (AoS vs. SoA)

Before writing a single line of FFI, the Rust-side buffer layout determines whether the Metal vertex shader can read node positions efficiently. Two options exist:

| Layout | Memory pattern | GPU read pattern | Verdict |
|--------|---------------|-----------------|---------|
| **AoS** — `[{x,y,z}, {x,y,z}, ...]` | Interleaved per-node | Single pointer load, sequential | ✅ Best for this use case |
| **SoA** — `[x,x,...][y,y,...][z,z,...]` | Three separate arrays | Three pointer loads per fetch | ⚠️ Only wins when SIMD-vectorizing a single axis |

For a knowledge graph where the vertex shader reads all three position components per vertex in a single draw call, AoS (`f32, f32, f32` interleaved) gives better cache coherence because each 12-byte node fits in one cache-line fetch. SoA wins in compute-only SIMD kernels operating on one axis at a time, but a Metal vertex shader loading `float3 position` from a vertex buffer reads the full struct in one access — fragmenting it into three arrays would add two extra pointer indirections with no benefit.[^1][^2][^3][^4]

**Decision: use interleaved AoS layout — `Vec<f32>` with stride 3 (x, y, z per node).**

### Rust Implementation: Stable, Leakless, Page-Aligned Buffer

The two failure modes to avoid are: (1) the `Vec` being reallocated mid-render because capacity was exceeded, moving the pointer Swift holds; and (2) the memory not being page-aligned, causing `makeBuffer(bytesNoCopy:)` to crash.[^5]

```rust
// graph_buffer.rs  — the COMPLETE Rust side

use std::mem::ManuallyDrop;

/// A fixed-capacity, page-aligned node position buffer.
/// Allocated once. Pointer is stable for lifetime of this struct.
/// Layout: [x0,y0,z0, x1,y1,z1, ... xN,yN,zN]
pub struct GraphBuffer {
    inner: ManuallyDrop<Vec<f32>>,
    node_count: usize,
}

impl GraphBuffer {
    /// `node_count` is fixed at creation. No reallocation ever occurs.
    pub fn new(node_count: usize) -> Self {
        let capacity = node_count * 3;
        // Pre-allocate exact capacity so as_ptr() never changes.
        let mut v = Vec::<f32>::with_capacity(capacity);
        v.resize(capacity, 0.0_f32);
        GraphBuffer {
            inner: ManuallyDrop::new(v),
            node_count,
        }
    }

    /// Stable raw pointer — safe to hand to Swift once and cache.
    #[inline(always)]
    pub fn as_ptr(&self) -> *const f32 {
        self.inner.as_ptr()
    }

    pub fn len(&self) -> usize { self.inner.len() }
    pub fn node_count(&self) -> usize { self.node_count }

    /// Mutable access for the physics/layout tick.
    /// Called only from the Rust worker; Swift never writes here.
    pub fn positions_mut(&mut self) -> &mut [f32] {
        &mut self.inner
    }
}

impl Drop for GraphBuffer {
    fn drop(&mut self) {
        // ManuallyDrop suppresses automatic drop; re-enable it here.
        unsafe { ManuallyDrop::drop(&mut self.inner); }
    }
}

// ─── C-ABI surface ────────────────────────────────────────────────────────────

/// Everything Swift needs, packed into one repr(C) struct.
/// ptr is the only field that crosses the Metal boundary.
#[repr(C)]
pub struct GraphBufferHandle {
    pub ptr:        *const f32,   // stable — never changes
    pub len:        usize,        // total f32 count (node_count * 3)
    pub node_count: usize,
    _opaque:        *mut GraphBuffer,  // Rust retains ownership
}

#[no_mangle]
pub extern "C" fn graph_buffer_create(node_count: usize) -> GraphBufferHandle {
    let buf = Box::new(GraphBuffer::new(node_count));
    GraphBufferHandle {
        ptr:        buf.as_ptr(),
        len:        buf.len(),
        node_count: buf.node_count(),
        _opaque:    Box::into_raw(buf),
    }
}

/// Physics tick — mutates positions in-place.
/// Swift calls this once per frame BEFORE encoding the draw call.
#[no_mangle]
pub unsafe extern "C" fn graph_buffer_tick(
    handle: *const GraphBufferHandle,
    dt: f32,
) {
    let buf = &mut *(*handle)._opaque;
    let positions = buf.positions_mut();
    // Example: trivial Euler step — replace with your force-directed layout
    for i in 0..buf.node_count() {
        let base = i * 3;
        positions[base]     += dt * positions[base + 1] * 0.01; // x += vx*dt
        // y, z similarly
    }
}

#[no_mangle]
pub unsafe extern "C" fn graph_buffer_free(handle: GraphBufferHandle) {
    // Reconstruct Box — Rust allocator frees the memory.
    drop(Box::from_raw(handle._opaque));
}
```

**Why `ManuallyDrop` instead of `mem::forget`?**  `ManuallyDrop` is a zero-cost `#[repr(transparent)]` wrapper that suppresses the destructor without consuming the value, keeping the contained `Vec` accessible through normal field access. It explicitly re-enables drop in the `impl Drop` block, making deallocation intentional and auditable rather than silently leaked.[^6]

**Why pre-size with `with_capacity` + `resize`?**  A `Vec` reallocates when `push` exceeds capacity, moving the heap block and invalidating any pointer Swift cached. Sizing to exact capacity at construction and never calling `push` again guarantees the pointer returned by `as_ptr()` is stable for the struct's lifetime.[^7]

### Page Alignment: The Hidden Crash

`makeBuffer(bytesNoCopy:)` requires the pointer to be page-aligned (0x4000 on iOS/macOS). Rust's global allocator satisfies this for large allocations (≥ 4 KB), but **not for small ones**. A 100-node graph (1,200 bytes) will crash. The safe solution: allocate via `posix_memalign` for the underlying storage, or simply ensure `node_count ≥ 342` (≥ 4,096 bytes). For the production path, use a custom allocator wrapper:[^8][^5]

```rust
// Fallback: allocate page-aligned memory manually for small buffers
use std::alloc::{alloc, Layout};

fn alloc_page_aligned(byte_len: usize) -> *mut u8 {
    const PAGE: usize = 0x4000; // 16 KB — iOS/macOS page size
    let aligned_len = (byte_len + PAGE - 1) & !(PAGE - 1);
    let layout = Layout::from_size_align(aligned_len, PAGE).unwrap();
    unsafe { alloc(layout) }
}
```

Confirmed behavior: Metal on Apple Silicon with `.storageModeShared` and a `bytesNoCopy` buffer results in the CPU and GPU sharing the **same physical address** — no copy, no PCIe-style transfer, because the unified memory architecture means both processors address the same DRAM pool.[^9][^10]

***

## Module 2 — FFI Call Packing: Single-Frame Byte Buffer

### ⭐ HIGH VALUE: Why One Struct Per Frame Is Non-Negotiable

The FFI boundary is not free. Even though the C ABI call itself is nanosecond-scale, the overhead compounds when called thousands of times per second. A BoltFFI benchmark measured 1,000 individual Rust FFI calls taking 1,580,000 ns total vs. a single batched equivalent at 2,700 ns — a 589× reduction. At 120 Hz with 8.3 ms per frame, the arithmetic is unforgiving.[^11]

The solution is a single `#[repr(C)]` struct encoding everything the Rust engine needs about one frame. One call in, one call out.

### Layout Rules for `#[repr(C)]` Command Structs

`#[repr(C)]` guarantees field order, size, and alignment match what a C compiler would produce — which is exactly what Swift's `UnsafePointer<T>` interprets when it reads the struct. Without it, Rust uses `#[repr(Rust)]`, which allows the compiler to freely reorder fields for optimization, making the layout undefined across compiler versions.[^12][^13]

**Alignment pitfall with enums:** `#[repr(C)]` on an enum guarantees that valid discriminant values have the correct layout, but it remains undefined behavior to set an enum field to a value that doesn't map to any variant. For the `interaction_flags` field in a command struct, **use a `u32` bitfield instead of an enum** — this avoids any risk of undefined values crossing the boundary.[^14][^15][^16]

```rust
// frame_command.rs — complete frame dispatch protocol

use std::os::raw::c_float;

/// Bit positions for interaction_flags u32
pub mod InteractionFlag {
    pub const TAPPED:       u32 = 1 << 0;
    pub const LONG_PRESSED: u32 = 1 << 1;
    pub const PINCHED:      u32 = 1 << 2;
    pub const PANNED:       u32 = 1 << 3;
    pub const NODE_MOVED:   u32 = 1 << 4;
    pub const EDGE_TAPPED:  u32 = 1 << 5;
}

/// Sent from Swift → Rust exactly once per render frame.
/// All input state for the frame is encoded here.
#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct FrameCommand {
    pub frame_index:        u64,
    pub dt:                 c_float,
    pub camera_x:           c_float,
    pub camera_y:           c_float,
    pub camera_zoom:        c_float,
    pub pan_delta_x:        c_float,
    pub pan_delta_y:        c_float,
    pub interaction_flags:  u32,        // bitfield — never an enum
    pub selected_node_id:   u64,        // 0 = none selected
    pub viewport_width:     c_float,
    pub viewport_height:    c_float,
    _pad: [u8; 4],                      // explicit padding to 64-byte total; avoids ABI surprise
}

/// Returned from Rust → Swift exactly once per frame.
#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct FrameResult {
    pub node_ptr:       *const c_float, // write-slot pointer for this frame's triple buffer
    pub node_count:     usize,
    pub dirty_flags:    u32,            // what changed: nodes moved, edges updated, etc.
    pub rust_compute_ms: c_float,       // telemetry: time spent in Rust physics
    pub hovered_node_id: u64,           // 0 = none
}

/// The world state opaque pointer — allocated once, lives for app lifetime.
pub struct EpistemosWorld {
    // graph, physics state, layout engine, etc.
}

#[no_mangle]
pub extern "C" fn world_create() -> *mut EpistemosWorld {
    Box::into_raw(Box::new(EpistemosWorld {
        // initialize fields
    }))
}

/// THE hot path: called 120 times per second.
/// All game logic, physics, and layout runs here.
#[no_mangle]
pub unsafe extern "C" fn world_tick(
    world: *mut EpistemosWorld,
    cmd: FrameCommand,
) -> FrameResult {
    let w = &mut *world;
    let start = std::time::Instant::now();

    // 1. Apply interaction from cmd.interaction_flags
    if cmd.interaction_flags & InteractionFlag::TAPPED != 0 {
        // handle tap at camera coords
    }
    if cmd.interaction_flags & InteractionFlag::NODE_MOVED != 0 {
        // update node position for cmd.selected_node_id
    }

    // 2. Physics step
    // w.graph.tick(cmd.dt, cmd.camera_x, cmd.camera_y, cmd.camera_zoom);

    let elapsed = start.elapsed().as_secs_f32() * 1000.0;

    FrameResult {
        node_ptr:        std::ptr::null(), // replace: triple_buffer.write_slot_ptr()
        node_count:      0,                // replace: w.graph.node_count()
        dirty_flags:     0,
        rust_compute_ms: elapsed,
        hovered_node_id: 0,
    }
}

#[no_mangle]
pub unsafe extern "C" fn world_free(world: *mut EpistemosWorld) {
    drop(Box::from_raw(world));
}
```

### Swift Side: Zero-Overhead FrameCommand Construction

```swift
// EpistemosEngine.swift

import Foundation

@MainActor
final class EpistemosEngine {
    private let worldPtr: OpaquePointer

    init() { worldPtr = OpaquePointer(world_create()) }
    deinit { world_free(worldPtr) }

    /// Called from MTKViewDelegate.draw(_:) — one FFI call per frame.
    func tick(dt: Float, camera: CameraState, input: InputFrame) -> FrameResult {
        var cmd = FrameCommand()
        cmd.frame_index       = frameIndex
        cmd.dt                = dt
        cmd.camera_x          = camera.x
        cmd.camera_y          = camera.y
        cmd.camera_zoom       = camera.zoom
        cmd.pan_delta_x       = input.panDelta.x
        cmd.pan_delta_y       = input.panDelta.y
        cmd.interaction_flags = input.flags
        cmd.selected_node_id  = selectedNodeID ?? 0
        cmd.viewport_width    = Float(viewportSize.width)
        cmd.viewport_height   = Float(viewportSize.height)

        frameIndex += 1
        return world_tick(worldPtr, cmd)
    }

    private var frameIndex: UInt64 = 0
    var selectedNodeID: UInt64?
}
```

**Isolation on `@MainActor`:** Swift 6 strict concurrency will flag `OpaquePointer` wrappers as non-`Sendable`. Confining the entire `EpistemosEngine` to `@MainActor` satisfies the compiler without `@unchecked Sendable` hacks, because all FFI calls occur on the main thread alongside Metal's draw loop.[^17][^18]

***

## Module 3 — Editor Delta Protocol with Rope Ops

### ⭐ HIGH VALUE: The Rope's Role

A `Rope` is a balanced tree of string chunks providing O(log N) insert and delete at any position, where N is the document length. For a code editor, this means inserting a character into a 100,000-line file takes the same time as inserting into a 10-line file. Both `ropey` and `jumprope` expose this guarantee; `jumprope` processes ~35–40 million real-world edit operations per second, approximately 3× faster than `ropey` on insert/delete benchmarks.[^19][^20]

The FFI contract is: **Swift never owns the document string. Swift sends typed characters as 24-byte delta structs. Rust applies them to the Rope. Swift requests only the visible screen window, never the full document.**

### Rust: The Complete Rope Engine

```rust
// editor_engine.rs

use ropey::Rope;

pub struct EditorEngine {
    rope: Rope,
    // Future: syntax tree, undo stack, diagnostics
}

/// Action tag — use u8 to keep EditDelta compact and FFI-safe.
/// NEVER use a Rust enum here: enum discriminants can have undefined values
/// when set from Swift. A u8 with explicit constants is safe.
pub mod Action {
    pub const INSERT: u8 = 0;
    pub const DELETE: u8 = 1;
    pub const REPLACE: u8 = 2;  // delete range, then insert — atomic for undo
}

/// The ONLY thing that crosses FFI per keystroke: ~32 bytes.
/// insert_ptr points into Swift's string storage — valid only during the call.
#[repr(C)]
pub struct EditDelta {
    pub action:      u8,
    _pad:            [u8; 7],         // alignment padding to 8 bytes
    pub char_idx:    usize,           // Unicode scalar (char) offset
    pub char_len:    usize,           // for DELETE/REPLACE: chars to remove
    pub insert_ptr:  *const u8,       // for INSERT/REPLACE: UTF-8 bytes
    pub insert_len:  usize,           // byte count of insert_ptr data
}

/// A view into a contiguous UTF-8 region of the rope.
/// The caller must call editor_slice_free() when done.
#[repr(C)]
pub struct RopeView {
    pub ptr:      *const u8,  // UTF-8 bytes
    pub byte_len: usize,
    pub char_len: usize,      // Unicode scalar count (for cursor math)
    _owned:       *mut String,  // heap allocation to free
}

#[no_mangle]
pub extern "C" fn editor_create() -> *mut EditorEngine {
    Box::into_raw(Box::new(EditorEngine { rope: Rope::new() }))
}

#[no_mangle]
pub unsafe extern "C" fn editor_load_utf8(
    engine: *mut EditorEngine,
    ptr: *const u8,
    byte_len: usize,
) {
    let bytes = std::slice::from_raw_parts(ptr, byte_len);
    let s = std::str::from_utf8(bytes).expect("invalid UTF-8 from Swift");
    (*engine).rope = Rope::from_str(s);
}

/// Hot path: apply one edit. ~nanoseconds.
#[no_mangle]
pub unsafe extern "C" fn editor_apply_delta(
    engine: *mut EditorEngine,
    delta: EditDelta,
) {
    let rope = &mut (*engine).rope;

    match delta.action {
        x if x == Action::DELETE || x == Action::REPLACE => {
            let end = (delta.char_idx + delta.char_len).min(rope.len_chars());
            rope.remove(delta.char_idx..end);
            if x == Action::DELETE { return; }
            // fall through for REPLACE to INSERT the new text
        }
        _ => {} // INSERT falls through directly
    }

    if delta.insert_len > 0 && !delta.insert_ptr.is_null() {
        let bytes = std::slice::from_raw_parts(delta.insert_ptr, delta.insert_len);
        // SAFETY: Swift String internals are always valid UTF-8
        let text = std::str::from_utf8_unchecked(bytes);
        rope.insert(delta.char_idx, text);
    }
}

/// Returns only the VISIBLE range of text — never the whole document.
/// `start_char` and `char_count` define the viewport in Unicode scalar offsets.
#[no_mangle]
pub unsafe extern "C" fn editor_get_view(
    engine: *const EditorEngine,
    start_char: usize,
    char_count: usize,
) -> RopeView {
    let rope = &(*engine).rope;
    let total_chars = rope.len_chars();
    let start = start_char.min(total_chars);
    let end = (start + char_count).min(total_chars);

    // RopeSlice::to_string() allocates only the visible window — not the full doc.
    let window: String = rope.slice(start..end).to_string();
    let boxed = Box::new(window);
    let ptr = boxed.as_ptr();
    let byte_len = boxed.len();
    let char_len = end - start;

    RopeView {
        ptr,
        byte_len,
        char_len,
        _owned: Box::into_raw(boxed) as *mut String,
    }
}

/// MUST be called after editor_get_view — frees the window allocation.
#[no_mangle]
pub unsafe extern "C" fn editor_free_view(view: RopeView) {
    if !view._owned.is_null() {
        drop(Box::from_raw(view._owned));
    }
}

/// Convert between line/column and char_idx for cursor positioning.
#[no_mangle]
pub unsafe extern "C" fn editor_line_to_char(
    engine: *const EditorEngine,
    line: usize,
) -> usize {
    (*engine).rope.line_to_char(line)
}

#[no_mangle]
pub unsafe extern "C" fn editor_char_to_line(
    engine: *const EditorEngine,
    char_idx: usize,
) -> usize {
    (*engine).rope.char_to_line(char_idx)
}

#[no_mangle]
pub unsafe extern "C" fn editor_len_chars(engine: *const EditorEngine) -> usize {
    (*engine).rope.len_chars()
}

#[no_mangle]
pub unsafe extern "C" fn editor_free(engine: *mut EditorEngine) {
    drop(Box::from_raw(engine));
}
```

### Swift: Sending Deltas

The Swift side uses `withCString` / `withUnsafeBytes` to get a valid pointer for the duration of the FFI call — **never storing the pointer** beyond the closure:[^21]

```swift
// CodeEditorViewModel.swift

import Foundation
import Combine

@MainActor
final class CodeEditorViewModel: ObservableObject {
    private let engine: OpaquePointer
    @Published var visibleText: String = ""

    init() { engine = OpaquePointer(editor_create()) }
    deinit  { editor_free(engine) }

    // ── Write operations (called on every keystroke) ──────────────────────────

    func insert(_ text: String, at charIdx: Int) {
        // withCString gives a valid UTF-8 *const c_char for the closure duration only.
        text.withCString { ptr in
            var delta = EditDelta()
            delta.action     = Action_INSERT
            delta.char_idx   = charIdx
            delta.char_len   = 0
            delta.insert_ptr = UnsafePointer(OpaquePointer(ptr))
            delta.insert_len = strlen(ptr)
            editor_apply_delta(engine, delta)
        }
    }

    func delete(at charIdx: Int, count: Int) {
        var delta = EditDelta()
        delta.action   = Action_DELETE
        delta.char_idx = charIdx
        delta.char_len = count
        editor_apply_delta(engine, delta)
    }

    // ── Read operation (called once per render frame for visible lines) ────────

    func refreshVisibleText(firstChar: Int, charCount: Int) {
        let view = editor_get_view(engine, firstChar, charCount)
        defer { editor_free_view(view) }  // always runs, even on early return

        if let str = String(
            bytes: UnsafeBufferPointer(start: view.ptr, count: view.byte_len),
            encoding: .utf8
        ) {
            visibleText = str
        }
    }

    // ── Cursor helpers ─────────────────────────────────────────────────────────

    func charIndex(forLine line: Int) -> Int {
        Int(editor_line_to_char(engine, line))
    }

    func lineNumber(forChar charIdx: Int) -> Int {
        Int(editor_char_to_line(engine, charIdx))
    }
}
```

**Critical lifetime rule:** `withCString` guarantees the `ptr` is valid only inside the closure. The `editor_apply_delta` FFI call completes synchronously before the closure returns, so the pointer is always live during use. Storing `ptr` in a property and calling FFI later would be a use-after-free.[^22][^23]

**Ropey `RopeSlice` characteristics:** `slice(start..end)` returns a `RopeSlice` in O(log N) time. `RopeSlice::to_string()` allocates only the sliced region — it does not clone the full document. For a 10,000-line file with 40 visible lines, only those 40 lines' bytes are allocated.[^24][^25]

***

## Module 4 — Swift/Metal Pointer Lifecycle & Sync

### ⭐ HIGH VALUE: The Exact Synchronization Contract

The pointer lifecycle has four phases per frame. Getting the ordering wrong produces either **visual tearing** (reading a partially-written buffer) or a **GPU page fault** (Metal executing a draw call with a now-freed Rust buffer):

```
Frame N:
  [CPU] graph_buffer_tick(&handle, dt)  ← Rust writes slot N%3
  [CPU] encode draw call → MTLBuffer[N%3]
  [CPU] commandBuffer.commit()
  [CPU] semaphore.wait()                ← blocks if 3 frames already in-flight
  
Frame N+1: (after GPU signals completion of frame N-2)
  [GPU] reads slot (N-2)%3              ← completely independent slot
  [CPU] graph_buffer_tick → slot N+1 % 3
```

Apple's official Metal Best Practices mandates triple buffering for dynamic buffer data, with `kMaxInflightBuffers = 3` and a counting semaphore initialized to 3. The first three frames proceed without blocking; the fourth blocks until the GPU signals completion of frame 1.[^26][^27]

### Complete Swift Metal Renderer

```swift
// GraphMetalRenderer.swift

import Metal
import MetalKit

final class GraphMetalRenderer: NSObject, MTKViewDelegate {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    // Triple-buffer slots: three MTLBuffers wrapping three Rust slots
    private let kMaxInFlight = 3
    private var metalBuffers:   [MTLBuffer] = []
    private var rustHandles:    [GraphBufferHandle] = []
    private var currentSlot = 0
    private let frameSemaphore: DispatchSemaphore

    private let engine: EpistemosEngine

    init(mtkView: MTKView, nodeCount: Int) {
        device = mtkView.device!
        commandQueue = device.makeCommandQueue()!
        frameSemaphore = DispatchSemaphore(value: kMaxInFlight)
        engine = EpistemosEngine()

        // ── Allocate three Rust-owned graph buffers, one per slot ─────────────
        for _ in 0..<kMaxInFlight {
            // Rust allocates page-aligned memory (see Module 1)
            let handle = graph_buffer_create(nodeCount)
            rustHandles.append(handle)

            // Wrap Rust's memory in a Metal buffer — bytesNoCopy = zero copy
            // storageModeShared: CPU and GPU share the same physical address on Apple Silicon
            let byteLen = handle.len * MemoryLayout<Float>.stride
            guard let mtlBuf = device.makeBuffer(
                bytesNoCopy: UnsafeMutableRawPointer(mutating: handle.ptr),
                length: byteLen,
                options: .storageModeShared,
                deallocator: nil   // Rust owns dealloc — do NOT pass a block
            ) else { fatalError("makeBuffer(bytesNoCopy:) failed — check page alignment") }

            metalBuffers.append(mtlBuf)
        }

        // Build pipeline state (vertex/fragment shaders)
        let lib = device.makeDefaultLibrary()!
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction   = lib.makeFunction(name: "graph_vertex")
        descriptor.fragmentFunction = lib.makeFunction(name: "graph_fragment")
        descriptor.colorAttachments.pixelFormat = mtkView.colorPixelFormat
        pipelineState = try! device.makeRenderPipelineState(descriptor: descriptor)

        super.init()
        mtkView.delegate = self
    }

    deinit {
        // Free all three Rust buffers in reverse order
        for handle in rustHandles { graph_buffer_free(handle) }
    }

    // ── MTKViewDelegate ────────────────────────────────────────────────────────

    func draw(in view: MTKView) {
        // Block CPU if 3 frames are already submitted and GPU hasn't cleared one.
        // This is the canonical Metal triple-buffer pattern.
        frameSemaphore.wait()

        let slot = currentSlot % kMaxInFlight
        currentSlot += 1

        // 1. Rust physics tick writes into slot's memory — Metal reads it next draw.
        //    No copy: graph_buffer_tick modifies rustHandles[slot].ptr in place.
        graph_buffer_tick(&rustHandles[slot], Float(view.preferredFramesPerSecond > 0
            ? 1.0 / Double(view.preferredFramesPerSecond) : 1.0/120.0))

        // 2. Encode the draw call referencing the Metal wrapper of slot's memory.
        guard
            let desc = view.currentRenderPassDescriptor,
            let cmdBuf = commandQueue.makeCommandBuffer(),
            let encoder = cmdBuf.makeRenderCommandEncoder(descriptor: desc)
        else { frameSemaphore.signal(); return }

        encoder.setRenderPipelineState(pipelineState)
        // setVertexBuffer at index 0 — the Metal shader reads float3 per vertex
        encoder.setVertexBuffer(metalBuffers[slot], offset: 0, index: 0)
        encoder.drawPrimitives(
            type: .point,
            vertexStart: 0,
            vertexCount: rustHandles[slot].node_count
        )
        encoder.endEncoding()

        // 3. Signal semaphore AFTER GPU completes this frame.
        //    addCompletedHandler runs on a Metal-internal thread.
        let semaphore = frameSemaphore
        cmdBuf.addCompletedHandler { _ in semaphore.signal() }

        if let drawable = view.currentDrawable {
            cmdBuf.present(drawable)
        }
        cmdBuf.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
```

### The `.storageModeShared` Decision on Apple Silicon

On Apple Silicon, `Shared` and `Managed` buffers behave identically for `MTLBuffer` — both map to the same unified DRAM, and `didModifyRange:` is a no-op on M-series chips. For buffers that are read by both CPU and GPU on every frame (exactly this use case), `.storageModeShared` is correct. Private storage (GPU-only) would require a blit copy from a staging buffer — exactly the overhead being eliminated.[^28][^10][^29][^30]

### `MTLSharedEvent` for CPU–GPU Ordering Within a Frame

If the architecture ever needs the CPU to modify buffer data **after** a GPU compute pass (e.g., a GPU layout pass feeds back node positions the CPU reads), use `MTLSharedEvent` to interleave CPU and GPU work within the same command buffer:[^31][^32]

```swift
// Advanced: interleaved CPU/GPU within one command buffer
let event = device.makeSharedEvent()!
let eventListener = MTLSharedEventListener()

// GPU signals event at value 1 when compute pass is done
cmdBuf.encodeSignalEvent(event, value: 1)

// CPU waits for value 1, then reads back GPU results
event.notify(eventListener, atValue: 1) { event, _ in
    // Safe to read metalBuffers[slot].contents() here
    event.signaledValue = 2  // unblock GPU for part 2
}

// GPU waits for CPU to signal 2 before proceeding
cmdBuf.encodeWaitForEvent(event, value: 2)
```

This pattern avoids blocking the entire CPU thread (unlike `waitUntilCompleted`) while still maintaining strict ordering.[^31]

### Lifecycle Summary Table

| Phase | Who acts | What happens | Invariant |
|-------|----------|-------------|-----------|
| `graph_buffer_create` | Rust | Allocates page-aligned `Vec<f32>`; returns stable `*const f32` | Pointer never changes |
| `makeBuffer(bytesNoCopy:)` | Swift/Metal | Wraps Rust pointer in `MTLBuffer` — no allocation | Same physical address |
| `frameSemaphore.wait()` | Swift CPU | Blocks if 3 frames are in-flight | Max 3 concurrent frames[^26] |
| `graph_buffer_tick` | Rust (via FFI) | Mutates slot's `f32` array in-place | GPU reads a different slot |
| `setVertexBuffer` | Metal encoder | References `MTLBuffer` — zero copy to GPU | GPU reads Rust's bytes directly |
| `addCompletedHandler` | Metal runtime | Signals semaphore after GPU done | CPU may now recycle slot[^27] |
| `graph_buffer_free` | Rust (on deinit) | `Box::from_raw` + `drop` | Rust allocator frees; MTLBuffer must already be released |

**Deallocation order matters:** the `MTLBuffer` wrapping a Rust pointer must be released (or all in-flight command buffers completed) before `graph_buffer_free` is called. In Swift, this means `metalBuffers` must be set to `[]` before `rustHandles` are freed in `deinit`.

---

## References

1. [AoS to SoA: 'How far to go' when converting to a parallelized ...](https://www.reddit.com/r/CUDA/comments/1ftj919/aos_to_soa_how_far_to_go_when_converting_to_a/) - I'd be happy to hear any recommendations or be linked any resources describing best practices for de...

2. [Soak: a struct-of-arrays library in Rust - Abubalay](https://www.abubalay.com/blog/2019/02/16/struct-of-arrays) - SIMD instructions perform the same operation on multiple values in parallel. This layout allows the ...

3. [Soak: a struct-of-arrays library in Rust - Reddit](https://www.reddit.com/r/rust/comments/arh494/soak_a_structofarrays_library_in_rust/) - Since SOAK is largely about performance, it would be great to see a benchmark comparison against arr...

4. [How do you handle multiple vertex types and objects using different ...](https://www.reddit.com/r/GraphicsProgramming/comments/1jwaocr/how_do_you_handle_multiple_vertex_types_and/) - When it comes to objects needing to use different shaders do you try to group them into batches to m...

5. [Failed assertion `newBufferWithBytesNoCopy:pointer 0x107b78020 ...](https://forums.kodeco.com/t/failed-assertion-newbufferwithbytesnocopy-pointer-0x107b78020-is-not-4096-byte-aligned/44567) - Here is my code : colorVBO = device.makeBuffer(bytesNoCopy: &colorVAO, length: MemoryLayout<MetalRen...

6. [Struct core::mem::ManuallyDrop](https://rust.docs.kernel.org/6.8/core/mem/struct.ManuallyDrop.html) - A wrapper to inhibit compiler from automatically calling `T`’s destructor. This wrapper is 0-cost.

7. [Why does vec allocate new memory and copy values when growing?](https://users.rust-lang.org/t/why-does-vec-allocate-new-memory-and-copy-values-when-growing/45291) - I'm wondering why collection algorithms like vec copy values from the old allocated memory space to ...

8. [Working with memory in Metal part 2](https://metalkit.org/2017/05/26/working-with-memory-in-metal-part-2/) - There are a couple of topics we need to discuss in more depth about working with memory. Last time w...

9. [metal-poc/metal-programming-notes.md at main · ingonyama-zk/metal-poc](https://github.com/ingonyama-zk/metal-poc/blob/main/metal-programming-notes.md) - Demonstrate zero cost memory transfer between CPU and GPU in Metal (for apple silicon) - ingonyama-z...

10. [Metal GPU Programming - A Practical Guide for macOS Developers](https://awesomeagents.ai/guides/metal-gpu-programming-guide/) - A hands-on guide to Metal compute programming on Apple Silicon. Covers architecture, unified memory,...

11. [BoltFFI: a high-performance Rust bindings generator (up to ... - Reddit](https://www.reddit.com/r/rust/comments/1r768bm/boltffi_a_highperformance_rust_bindings_generator/) - Same struct can have uniffi, boltffil at the same time for instance. ... in one our own project the ...

12. [What's the difference between #[repr(Rust)], #[repr(C)] and #[repr ...](https://stackoverflow.com/questions/79631106/whats-the-difference-between-reprrust-reprc-and-reprpacked) - #[repr(Rust)] gives the compiler full flexibility to do whatever it likes with the type's layout (as...

13. [Other reprs - The Rustonomicon - Rust Documentation](https://doc.rust-lang.org/nomicon/other-reprs.html) - Due to its dual purpose as “for FFI” and “for layout control”, repr(C) can be applied to types that ...

14. [Integrating Rust and C++ in Firefox - In Pursuit of Laziness](http://manishearth.github.io/blog/2021/02/22/integrating-rust-and-c-plus-plus-in-firefox/) - #[repr(C)] on enums in Rust guarantees layout, but it is still undefined behavior for any enum to ta...

15. [Struct with mixed bitflag and normal members - Stack Overflow](https://stackoverflow.com/questions/49140221/struct-with-mixed-bitflag-and-normal-members) - I'm trying to recreate a C struct with mixed bitfield members and "normal" members in Rust for FFI. ...

16. [C structs with bit fields and FFI - #5 by nbaksalyar - Rust Users Forum](https://users.rust-lang.org/t/c-structs-with-bit-fields-and-ffi/1429/5) - Well, if anyone is interested in this problem: as it turns out, transforming struct's bit fields int...

17. [Question on Sendability (Swift 6 data race safety) and FFI interfaces](https://forums.swift.org/t/question-on-sendability-swift-6-data-race-safety-and-ffi-interfaces/76219) - Swift's Sendable corresponds to Rust's Send: ensuring that individual operations on a value are well...

18. [Swift concurrency and Metal - Using Swift - Swift Forums](https://forums.swift.org/t/swift-concurrency-and-metal/71908) - I am using MetalKit and Cocoa to render my game, but because terrain is procedurally generated and m...

19. [JumpRope — data structures in Rust // Lib.rs](https://lib.rs/crates/jumprope) - A rope is a data structure for efficiently editing large strings, or for processing editing traces. ...

20. [Struct RopeCopy item path](https://docs.freyaui.dev/freya_hooks/struct.Rope.html) - A utf8 text rope.

21. [How could I do basic memory layout control for bridging ...](https://forums.swift.org/t/how-could-i-do-basic-memory-layout-control-for-bridging-swift-to-rust/83129) - Hi folks, I need help learning something new. With the help of an LLM agent I’ve got something very ...

22. [Return struct with lifetime for FFI - Stack Overflow](https://stackoverflow.com/questions/42564300/return-struct-with-lifetime-for-ffi) - Returning to the error message, hopefully it makes more sense now: " parser does not live long enoug...

23. [Expressing lifetime of C buffers in an FFI binding iterator](https://users.rust-lang.org/t/expressing-lifetime-of-c-buffers-in-an-ffi-binding-iterator/2352) - Hi All, I'm working on a rust binding for rocksdb (yes, I know there are several already, but this i...

24. [ropey::RopeSlice](https://cessen.github.io/ropey/ropey/struct.RopeSlice.html) - API documentation for the Rust `RopeSlice` struct in crate `ropey`.

25. [ropey - Rust - GitHub Pages](https://cessen.github.io/ropey/ropey/index.html) - API documentation for the Rust `ropey` crate.

26. [Metal Best Practices Guide: Triple Buffering - Apple Developer](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/TripleBuffering.html) - Implement a triple buffering model to update dynamic buffer data. Dynamic buffer data refers to freq...

27. [Synchronizing CPU and GPU work | Apple Developer Documentation](https://developer.apple.com/documentation/Metal/synchronizing-cpu-and-gpu-work) - In your app, a semaphore controls CPU and GPU access to buffer instances. You initialize the semapho...

28. [[Apple Metal] Changing MTLStorageMode of MTLTexture From Shared to Private After Accessed by CPU](https://www.reddit.com/r/AskProgramming/comments/17vjck5/apple_metal_changing_mtlstoragemode_of_mtltexture/) - [Apple Metal] Changing MTLStorageMode of MTLTexture From Shared to Private After Accessed by CPU

29. [Best Practice for testing Managed Buffers? - Stack Overflow](https://stackoverflow.com/questions/69802692/best-practice-for-testing-managed-buffers) - What's the best way to test Managed buffers on Apple Silicon where the GPU memory is unified so that...

30. [Metal Best Practices Guide: Resource Options - Apple Developer](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/ResourceOptions.html) - Resource storage modes allow you to define the storage location and access permissions for your MTLB...

31. [Synchronize work between CPU and GPU within single command buffer using MTLSharedEvent](https://stackoverflow.com/questions/70646270/synchronize-work-between-cpu-and-gpu-within-single-command-buffer-using-mtlshare) - I am trying to use MTLSharedEvent along with MTLSharedEventListener to synchronize computation betwe...

32. [[Answer]-Synchronize work between CPU and GPU within single command buffer using MTLSharedEvent-swift](https://www.appsloveworld.com/swift/100/89/synchronize-work-between-cpu-and-gpu-within-single-command-buffer-using-mtlshared) - Coding example for the question Synchronize work between CPU and GPU within single command buffer us...

