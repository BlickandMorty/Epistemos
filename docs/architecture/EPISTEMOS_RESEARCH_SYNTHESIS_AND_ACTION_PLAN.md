# Epistemos Research Synthesis and Action Plan

**Date:** 2026-04-15
**Author:** Architecture research synthesis across 5 independent deep-research sessions + 3-model council (GPT-5.4, Claude Opus 4.6, Gemini 3.1 Pro)
**Authority:** PLAN_V2.md §22 remains canonical. This document proposes *additions* to PLAN_V2, not overrides.
**Status:** Brainstorm → actionable slices, ready for Claude Code / Codex handoff

---

## Part 1: What All Research Agrees On (High Confidence)

Every research document and every model in the council converged on these points. These are settled and should drive immediate action.

### 1.1 Benchmark Harness Is The Absolute First Step

No migration, no editor work, no BoltFFI prototype until instrumentation exists. The benchmark harness is the only slice that cannot cause a regression, cannot drift from the plan, and cannot violate any architectural law — because it adds only instrumentation.

**What to build:**

The harness lives in two places — Swift and Rust — and wraps every FFI call site that touches a `boltffi_priority` surface.

**Swift side (`os_signpost`):**

Wrap the five `boltffi_priority` graph C FFI sections with signpost intervals. The signpost subsystem is `com.epistemos.ffi` and each interval gets a descriptive name. The key files to instrument are:

- `GraphState.swift` — every call into `graph_engine_add_nodes_batch`, `graph_engine_load_graph_data`, and the other Data Loading §25 functions. Wrap each call site with `OSSignposter.beginInterval` / `endInterval`. Record the node count and byte count as signpost metadata.
- `GraphState.swift` or wherever graph search is called — the Search §292 functions (`graph_engine_search_*`). Wrap with signpost. Record query length and result count.
- `MetalGraphView.swift` — the SDF Label Rendering §966 calls. Wrap the label instance array transfer with signpost. Record label count.
- `StreamingDelegate.swift` — wrap the `poll_event` token delivery path. Record event type and payload size.
- The note editor path (wherever `NoteTextView` calls the Markdown Parser §468 C FFI functions) — wrap each parse call. Record input length and token count returned.

The signpost instrumentation code pattern is:

```swift
import os

private let signposter = OSSignposter(subsystem: "com.epistemos.ffi", category: "graph")

// At each FFI call site:
let state = signposter.beginInterval("graph_search", id: signposter.makeSignpostID())
// ... existing FFI call ...
signposter.endInterval("graph_search", state)
```

**Rust side (`divan` or `criterion`):**

Add a `benches/` directory to `graph-engine` with benchmarks for:

- `graph_add_nodes_batch` with 1K, 5K, 10K synthetic nodes
- `graph_search` with realistic query strings against a 10K-node synthetic graph
- `graph_neighbors` query latency
- Markdown parse helpers with 1K, 10K, 50K character inputs

Use `divan` over `criterion` — it has a simpler API, tracks allocation counts via `AllocProfiler`, and produces cleaner output. Add `divan = "0.1"` to `[dev-dependencies]` in the relevant Cargo.toml files.

**Deliverables:**

- `EpistemosTests/FFIBenchmarkBaselines.swift` — disabled-by-default XCTest suite with `measure {}` blocks
- `graph-engine/benches/graph_ffi_baselines.rs` — divan benchmarks
- `docs/architecture/BENCHMARK_BASELINES.csv` — committed baseline numbers after first Instruments run
- A one-paragraph summary in each file header explaining what it measures and why

**Target metrics to capture:**

| Metric | What It Tells You |
|--------|-------------------|
| Payload size (bytes) per call | How much data crosses the bridge |
| Call frequency (calls/sec under load) | Whether this is a real hot path or a cold one |
| Allocation count per call | Whether the bridge allocates heap memory |
| Swift main-thread time per call (µs) | How much frame budget this consumes |
| Rust marshalling time per call (µs) | How much time Rust spends packing/unpacking |
| End-to-end latency (µs) | Total round-trip cost |
| Peak memory delta | Whether the bridge leaks or grows |

### 1.2 First BoltFFI Migration: Graph Data Loading + Queries + Search

After the benchmark harness captures baselines, the first real migration slice is these three graph sections — they share a common payload shape (node/edge batches, neighborhoods, search hits) and a single typed buffer layout covers all three.

**The migration follows this exact sequence:**

1. Design the `#[repr(C)]` buffer layout for `GraphNodeBatch` and `GraphEdgeBatch` and `GraphSearchResult`. These are flat structs of primitives only — no heap pointers, no strings.
2. Add the new BoltFFI (or raw C FFI typed buffer) functions *alongside* the existing C FFI functions. Both paths coexist.
3. Add a runtime compatibility flag: `EPISTEMOS_USE_BOLT_GRAPH` (defaults to `false`).
4. Wire the new path in `GraphState.swift` behind the flag.
5. Run the benchmark harness with both paths. Capture before/after CSVs.
6. Run the existing Phase 7 test suites to verify parity (no coordinate drift, no visual regression).
7. Only flip the flag to `true` after parity + benchmark delta pass.
8. Retire the old callers only after the new path is proven.

**Proposed struct shapes (consensus across all research):**

```rust
#[repr(C)]
pub struct GraphNodeBuffer {
    pub id_hash: u64,        // stable node identifier (hash of UUID to avoid string passing)
    pub x: f32,
    pub y: f32,
    pub z: f32,
    pub radius: f32,
    pub color_rgba: u32,     // packed RGBA
    pub flags: u16,          // pinned, selected, hovered, filtered bits
    pub _pad: u16,
}
// Size: 32 bytes, naturally aligned on arm64

#[repr(C)]
pub struct GraphEdgeBuffer {
    pub source_hash: u64,
    pub target_hash: u64,
    pub weight: f32,
    pub edge_type: u8,
    pub _pad: [u8; 3],
}
// Size: 24 bytes

#[repr(C)]
pub struct GraphSearchHit {
    pub node_hash: u64,
    pub score: f32,
    pub label_offset: u32,   // offset into a separate label string buffer
    pub label_len: u16,
    pub _pad: u16,
}
// Size: 20 bytes
```

**Memory ownership:**

- Rust allocates the contiguous batch buffer internally (a `Vec<GraphNodeBuffer>` behind the scenes).
- Rust passes `(*const GraphNodeBuffer, count: u32)` to Swift via FFI.
- Swift reads synchronously (one thread, one call, no async retention).
- Swift calls `graph_release_batch(batch_ptr)` immediately after reading.
- Rust frees the buffer on release.

This matches the Knowledge Core SHM pattern already proven in the codebase.

### 1.3 Do Not Rebuild the Code Editor

Every research source, every model, and PLAN_V2 itself agree: no editor rebuild before benchmarks exist and no full Metal text rendering under any circumstances. The editor gets a Rust syntax data plane *only* after the graph BoltFFI slice is proven and editor-specific benchmarks show a measured hot path.

### 1.4 Do Not Mass-Migrate to BoltFFI

Only benchmark-proven hot paths qualify. Everything else stays on UniFFI or current C FFI. The specific surfaces that must *not* move are:

- `approval.rs` (13 exports) — security-critical, must stay auditable
- `routing.rs` (2 exports) — Rust sovereignty
- `channel_relay.rs` (16 exports) — cold control-plane
- `vault_registry.rs`, `vault.rs` — typed ergonomics matter more than throughput
- All settings, permissions, telemetry surfaces
- Embeddings and vector payloads (shared-memory candidate, not BoltFFI)

---

## Part 2: What To Add to PLAN_V2

The following are concrete additions that should be appended to PLAN_V2.md to incorporate the research findings. These do not override existing sections — they extend them with implementation-level detail that was missing.

### Addition 1: New Section §23 — Code Editor Syntax Data Plane

**Proposed text to add after §22:**

```
## 23. Code Editor Syntax Data Plane

### 23.1 Architecture

The code editor uses a hybrid architecture:
- Swift/TextKit 2 (or current native editor layer) owns: text input, IME, 
  selection, undo/redo, accessibility, native scrolling
- Rust owns: incremental parsing, syntax token generation, fold extraction,
  diagnostic ranges
- The FFI bridge carries: compact token/fold/diagnostic deltas scoped to
  the visible viewport
- Metal is used only for: minimap, gutter decorations, diagnostics heatmaps,
  diff overlays

Full Metal text rendering is prohibited unless benchmarks prove the native
TextKit path cannot meet interaction targets (< 16ms keystroke-to-highlight).

### 23.2 Rust syntax stack

The Rust syntax engine lives in a new `syntax-core` crate, separate from
`graph-engine`. It must not share tree-sitter dependencies with graph-engine
to avoid coupling parse state with graph physics.

Components:
- tree-sitter (latest stable, currently 0.26.x) for incremental parsing
- A rope data structure for the Rust-side shadow buffer:
  - Primary candidate: ropey (1.6.x) — built-in UTF-16 code unit conversion
    via char_to_utf16_cu() in O(log N), proven in Helix editor, COW clone
    for cheap snapshots
  - Alternative: crop — faster raw edits, byte-indexed, but requires manual
    UTF-16 mapping
  - Decision gated by benchmarks comparing UTF-16 conversion cost vs edit speed
- Numeric token kind IDs (u16) mapped from tree-sitter capture indices at
  query compilation time — no strings cross the FFI boundary
- Generation counter (AtomicU64) for stale-parse cancellation

### 23.3 Text ownership model

Initially, Swift NSTextStorage remains the canonical text buffer. Rust
maintains a shadow rope that receives edit deltas and is used exclusively
for parsing. The shadow rope is not the source of truth — it is a parse-only
replica.

Migration to Rust-owned canonical text is a later phase, gated by benchmarks
proving Swift text storage is a measured bottleneck for files > 50K lines.

### 23.4 Viewport-scoped token materialization

Syntax tokens are generated only for the visible viewport plus a configurable
margin (default: 50 lines above and below). Full-document token generation
is prohibited on every keystroke.

The flow:
1. Swift captures keystroke → calculates edit delta → sends SyntaxEditDelta
   to Rust (12 bytes, no allocation)
2. Rust applies delta to shadow rope
3. Rust triggers tree-sitter incremental reparse (< 1ms for single-char edits)
4. Swift sends SyntaxViewportRequest with current visible range and generation
5. Rust executes tree-sitter QueryCursor with byte_range restriction
6. Rust fills preallocated token buffer with SyntaxTokenSpan structs
7. Swift reads buffer synchronously, applies NSAttributedString attributes
   only for returned spans, then releases
8. If generation has advanced, result is silently discarded

### 23.5 FFI data shapes

All structs are #[repr(C)] with compile-time size assertions:

- SyntaxDocumentHandle: doc_id (u64) + generation (u64) = 16 bytes
- SyntaxEditDelta: doc_id + from_gen + to_gen + byte_offset + old_len + new_len = 48 bytes
- SyntaxViewportRequest: doc_id + generation + utf16_start + utf16_end = 24 bytes
- SyntaxTokenSpan: utf16_start (u32) + utf16_len (u16) + kind_id (u16) + flags (u8) + pad = 12 bytes
- SyntaxFoldRange: utf16_start (u32) + utf16_end (u32) + depth (u8) + pad = 12 bytes
- SyntaxDiagnosticRange: utf16_start (u32) + utf16_len (u16) + severity (u8) + source_id (u8) = 8 bytes
- SyntaxSnapshotStats: doc_id + generation + counts + parse_ns = 40 bytes

### 23.6 Swift editor shell decision

The Swift-side editor component is not yet decided. Three viable options exist:

Option A: Keep current CodeEditSourceEditor + add Rust syntax service
  - Lowest risk, smallest change surface
  - Risk: CodeEditSourceEditor README states "not ready for production use"
  - Decision: acceptable if current usage is stable and benchmarked

Option B: TextKit 2 custom NSTextView shell + Rust syntax service
  - Most conservative native path
  - Risk: TextKit 2 has documented bugs (scrollbar jitter, custom backing
    store limitations, IME edge cases)
  - Decision: acceptable with STTextView-style workarounds

Option C: STTextView + Rust syntax service
  - Most battle-tested TextKit 2 implementation (4+ years, Marcin Krzyżanowski)
  - Risk: GPL license requires commercial license for proprietary use
  - Decision: evaluate license terms before adoption

The decision is deferred until after the benchmark harness captures editor-
specific metrics. The current editor shell is treated as a risk register item
to be benchmarked, not replaced speculatively.

### 23.7 Metal overlay architecture

Metal overlays compose alongside the text view for non-text rendering:

- Minimap: Metal instanced colored quads (thousands of tiny rectangles)
- Gutter decorations: Metal batch rendering (coverage, blame, breakpoints)
- Diagnostics heatmap: Metal fragment shader gradient
- Diff overlays: Metal alpha-blended quad strips
- Background decorations: Metal layer below text (scope coloring, indent guides)

Metal views are sibling NSView subclasses with CAMetalLayer, positioned via
zPosition. Use isPaused = true on MTKView for on-demand rendering.
Use presentsWithTransaction = true on CAMetalLayer for scroll sync.

### 23.8 Benchmarks required before any editor migration

- Editor open time: 1K, 10K, 50K, 100K-line files
- Keystroke-to-highlight latency (keyDown → drawRect)
- Scroll FPS and frame hitches in large syntax-highlighted files
- Memory growth during continuous typing (10 minutes simulated)
- NSTextStorage attribute application time for viewport-sized batches

Target: < 16ms keystroke-to-highlight, < 500ms open for 50K lines,
stable 60fps scroll, no unbounded memory growth.
```

### Addition 2: New Section §24 — Agent Streaming Data Plane

**Proposed text:**

```
## 24. Agent Streaming Data Plane

### 24.1 Migration scope

Only high-frequency streaming events justify BoltFFI migration:
- Token deltas (100-300 events/sec during LLM streaming)
- Thinking/reasoning deltas (same frequency)
- Tool-call progress events (variable, up to 50/sec)

Cold control-plane calls stay on UniFFI:
- Tool permission gates
- Destructive-action approval
- Session lifecycle
- Telemetry and audit logs
- Cancellation commands

### 24.2 Token coalescing

Individual token delivery across the FFI boundary is an anti-pattern.
Rust must coalesce tokens into frame-aligned batches:

- Collect incoming LLM tokens in a buffer for 16ms (one 60Hz frame)
- After 16ms window closes, deliver the coalesced batch to Swift
- Swift reads the contiguous text block, appends to UI in one operation
- This reduces FFI crossing frequency from ~100/sec to ~60/sec

### 24.3 Backpressure

If Swift's main thread is congested, token consumption slows. The Rust
side must respect this via one of:
- SPSC lock-free ring buffer (rtrb crate) — producer pauses when full
- Pull-based polling from Swift at frame boundaries
- Shared AtomicBool pause flag

### 24.4 Cancellation

Swift sets a shared AtomicBool cancellation flag. Rust checks on each token
and initiates clean shutdown. Ordering::Relaxed suffices — cancellation is
a hint, not a synchronization point. Rust owns the actual teardown: dropping
the HTTP connection, cleaning up memory, emitting the cancellation telemetry
event.

### 24.5 Benchmarks required

- Token streaming event rate vs main-thread CPU utilization
- UI frame impact during rapid LLM generation
- Backpressure behavior under simulated Swift congestion
- Memory growth during sustained 60-second streaming sessions

Target: < 5% main thread utilization during streaming, zero frame drops,
no unbounded memory growth.

### 24.6 Execution order

Agent streaming BoltFFI is the second wave, after graph data-plane is proven.
Do not prototype agent streaming until graph benchmarks are committed.
```

### Addition 3: New Section §25 — Graph Zero-Copy Rendering

**Proposed text:**

```
## 25. Graph Zero-Copy Rendering via Shared MTLBuffer

### 25.1 Architecture

For the knowledge graph with 10K+ nodes, the position data bandwidth is
~80KB per frame (10K × 2 floats × 4 bytes) at 60fps. Copying this data
every frame is wasteful on Apple Silicon's unified memory.

The zero-copy solution: triple-buffered MTLBuffer with .storageModeShared.

### 25.2 Implementation

Swift creates three MTLBuffer instances and passes the contents() pointer
to Rust via FFI. Rust writes node positions directly into Metal-visible
memory. Swift encodes the buffer into a render command with zero intermediate
copies.

A DispatchSemaphore(value: 3) prevents CPU from writing to a buffer the GPU
is still reading.

### 25.3 Layout

Use Struct-of-Arrays for GPU upload: separate contiguous arrays for positions
([f32]), sizes ([f32]), and colors ([u32]), matching Metal vertex buffer
expectations. Adjacency data (edge source/target index pairs) changes
infrequently and is uploaded once, updated on mutation.

### 25.4 When to implement

This is a Phase 2 optimization within the graph BoltFFI slice. The first
graph migration uses typed buffers with synchronous copy. Zero-copy shared
MTLBuffer is introduced only after typed buffers prove the copy is a measured
bottleneck.
```

### Addition 4: Rope Library Decision Framework (add to §23.2)

```
Rope library decision framework:

If the primary bottleneck is UTF-16 ↔ UTF-8 conversion cost:
  → Use ropey (built-in O(log N) char_to_utf16_cu)

If the primary bottleneck is raw edit throughput on very large files:
  → Use crop (3-4× faster edits than ropey, 16-byte clone)

If both matter equally:
  → Use ropey (larger ecosystem, proven tree-sitter integration in Helix,
    Send+Sync with O(1) clone for background parsing snapshots)

The decision is deferred until editor benchmarks exist. For the initial
shadow-rope prototype, use ropey as the conservative default. Crop can
replace it later if benchmarks show edit throughput is the bottleneck.
```

---

## Part 3: Concrete Action Items In Priority Order

This is the task list you hand to Claude Code or Codex. Each item is a self-contained session.

### Session 1: Benchmark Harness (No Risk, No Migration)

**Goal:** Instrument all `boltffi_priority` FFI surfaces with `os_signpost` on the Swift side and `divan` on the Rust side. Commit baseline numbers.

**Files to create:**
- `EpistemosTests/GraphFFIBenchmarkTests.swift`
- `graph-engine/benches/graph_ffi_baselines.rs`
- `docs/architecture/BENCHMARK_BASELINES.csv`

**Files to modify (instrumentation only):**
- `Epistemos/Graph/GraphState.swift` — add signpost intervals around Data Loading, Queries, Search calls
- `Epistemos/Views/Graph/MetalGraphView.swift` — add signpost around SDF Label Rendering calls
- `Epistemos/Bridge/StreamingDelegate.swift` — add signpost around `poll_event` delivery
- The note editor file that calls Markdown Parser C FFI — add signpost around parse calls

**Verification:**
- Open Instruments → Time Profiler → filter by `com.epistemos.ffi`
- Confirm signpost intervals appear for all five priority sections
- Run Instruments for 30 seconds with a 10K-node vault loaded
- Export data, commit as `BENCHMARK_BASELINES.csv`
- All existing tests still pass
- `xcodegen generate` produces zero diff

**What NOT to do:**
- Do not change any FFI function signatures
- Do not add any new FFI functions
- Do not change any Rust code except adding benchmark files
- Do not change any UI behavior

### Session 2: Graph BoltFFI Typed Buffer Prototype

**Goal:** Design and implement the typed buffer layout for graph node/edge batch transfer. Both old and new paths coexist.

**Prerequisites:** Session 1 baselines committed.

**Files to create:**
- `graph-engine/src/bolt_bridge.rs` — new typed buffer FFI functions alongside existing C FFI
- `graph-engine-bridge/graph_engine_bolt.h` — new C header for typed buffer functions (generated by cbindgen or manual)

**Files to modify:**
- `graph-engine/Cargo.toml` — add feature flag `bolt-graph`
- `Epistemos/Graph/GraphState.swift` — add new call path behind `EPISTEMOS_USE_BOLT_GRAPH` flag
- `project.yml` — register new header if needed

**Verification:**
- Feature flag defaults to `false` — app behavior is identical to baseline
- With flag `true`: graph loads, displays, navigates identically to old path
- Run benchmark harness: capture before/after CSV comparison
- All Phase 7 test suites pass with both flag states
- No coordinate drift (pixel-compare screenshots if possible)

### Session 3: Graph Chat Receiver Wiring

**Goal:** Wire the `GraphChatRequest` notification to a real subscriber so graph-to-agent chat works end-to-end.

**Context from research:** `GraphState.askGraphChat(nodeId:)` dispatches a `GraphChatRequest` notification, but no non-test subscriber exists. This is flagged as P1 pain point. The receiver must route through the ACC → Rust compile path per PLAN_V2 §4.1 (Graph Chat must not create a competing chat architecture).

**Files to modify:**
- `Epistemos/App/ChatCoordinator.swift` or a new `GraphChatState.swift` — subscribe to `GraphChatRequest`
- Ensure the subscriber extracts graph context (node id, source id, node type, label, workspace route) and compiles it into a proper ACC request
- Ensure the receiver is idempotent and lifecycle-safe (no duplicate observers, no leaked notification tokens)

**Verification:**
- Double-click a graph node → graph note page opens (existing)
- Right-click a graph node → "Ask about this" → ACC opens with graph context pre-filled
- The request flows through Rust compile path, not a separate chat architecture
- Repeated navigation and workspace switches do not register duplicate observers

### Session 4: Swift 6 Concurrency Hardening

**Goal:** Fix the NotificationCenter pattern risk and other Swift 6 strict concurrency violations.

**Context:** Phase 7 surfaced that any NotificationCenter observer capturing `note.userInfo` in a `@Sendable` closure triggers data-race warnings in Swift 6 strict mode. The fix is `MainActor.assumeIsolated` on `.main`-queue observers.

**Files to audit and fix:**
- Every `NotificationCenter.default.addObserver` call in the codebase
- Every `@Published` property that might be set from a non-main thread
- The `openNode` force-unwrap pattern (`node.sourceId!`) → rewrite as `guard let`
- Any `try!` or `!` force unwrap → replace with proper error handling
- Any `Int(float)` without `isFinite` check → add guard
- Any `page.loadBody()` inside a SwiftUI `body` property → hoist to Task

**Verification:**
- Build with `-strict-concurrency=complete` (or whatever the Swift 6 flag is)
- Zero data-race warnings in the build output
- All tests pass

### Session 5: syntax-core Crate Scaffolding

**Goal:** Create the new `syntax-core` crate with tree-sitter + ropey, but do NOT wire it to the editor yet. This is scaffolding only.

**Files to create:**
- `syntax-core/Cargo.toml` — depends on `tree-sitter`, `ropey`, `tree-sitter-rust`, `tree-sitter-swift`, `tree-sitter-markdown` (and other grammars as needed)
- `syntax-core/src/lib.rs` — public API surface: `SyntaxDocumentHandle`, `SyntaxEditDelta`, `SyntaxViewportRequest`, `SyntaxTokenSpan`, `SyntaxFoldRange`, `SyntaxDiagnosticRange`, `SyntaxSnapshotStats`
- `syntax-core/src/rope_bridge.rs` — ropey ↔ tree-sitter TSInput integration
- `syntax-core/src/token_registry.rs` — compile-time mapping of tree-sitter capture names → u16 kind IDs
- `syntax-core/src/generation.rs` — AtomicU64 generation counter + cancellation flag
- `syntax-core/benches/parse_baselines.rs` — divan benchmarks for parse latency on 1K/10K/50K line files

**What this session does NOT do:**
- Does not wire syntax-core to the Swift editor
- Does not add any FFI exports yet
- Does not change any existing crate
- Does not touch CodeEditorView.swift

**Verification:**
- `cargo build -p syntax-core` succeeds
- `cargo test -p syntax-core` passes with basic parse tests
- `cargo bench -p syntax-core` runs and produces baseline numbers
- Tree-sitter can parse a 50K-line Rust file in < 100ms (initial parse)
- Tree-sitter can reparse after a single-char edit in < 1ms

### Session 6: Agent Streaming Instrumentation

**Goal:** Instrument the agent token streaming path with signposts and establish baselines, but do NOT migrate to BoltFFI yet.

**Files to modify:**
- `Epistemos/Bridge/StreamingDelegate.swift` — add signpost intervals around every event type
- `agent_core/src/bridge.rs` — add timing instrumentation around token emission

**Deliverables:**
- Baseline data for: events/sec during streaming, main-thread CPU%, frame impact
- Committed to `docs/architecture/AGENT_STREAM_BASELINES.csv`

---

## Part 4: What NOT To Do (Anti-Pattern Register)

These are explicitly called out across all research documents. Violating any of these is a drift from PLAN_V2.

1. **Do not mass-migrate every bridge to BoltFFI.** Only benchmark-proven hot paths qualify.
2. **Do not rebuild the code editor before benchmarking.** No open-time, keystroke-latency, or scroll-FPS data exists yet.
3. **Do not put routing or permissions in Swift.** Rust is the sole authority for both.
4. **Do not create a second graph chat architecture.** Graph Chat must flow through the same ACC/Rust compile path.
5. **Do not move text input, IME, or accessibility out of native macOS.** The risks (CJK IME, VoiceOver, bidirectional text) are prohibitive.
6. **Do not pass full document text across FFI every keystroke.** Only `SyntaxEditDelta` crosses the bridge per edit.
7. **Do not apply syntax attributes to the full file every keystroke.** Viewport-scoped token materialization only.
8. **Do not migrate embeddings/vector payloads in the first BoltFFI wave.** Embeddings are a shared-memory problem, not a BoltFFI problem.
9. **Do not migrate `approval.rs` or `routing.rs`.** Audit semantics and Rust sovereignty must be preserved.
10. **Do not replace the editor shell before benchmarking the current one.** The shell decision (CodeEditSourceEditor vs TextKit 2 custom vs STTextView) is deferred until metrics exist.
11. **Do not use crop without benchmarking against ropey first.** The research is split on this — crop is faster for edits but ropey has native UTF-16 conversion. Let data decide.
12. **Do not bundle tree-sitter in graph-engine.** It belongs in a separate `syntax-core` crate.

---

## Part 5: Research Disagreements and How to Resolve Them

These are the open questions where the research sources disagree. Each has a resolution strategy.

### 5.1 Ropey vs Crop

**GPT-5.4 / Claude Opus:** Prefer ropey — built-in UTF-16 support, proven in Helix, conservative default.
**Gemini / Research Report 1:** Prefer crop — 3-4× faster edits, 16-byte clone, byte-indexed (maps to Rust native).

**Resolution:** Start with ropey for the syntax-core shadow rope. It has the critical `char_to_utf16_cu()` method that bridges Rust UTF-8 ↔ Apple UTF-16 in O(log N) without auxiliary data structures. If benchmarks later show edit throughput is the bottleneck (unlikely for a shadow rope that only receives deltas), switch to crop with a manual UTF-16 offset table.

### 5.2 CodeEditSourceEditor vs STTextView vs Custom TextKit 2

**GPT-5.4:** Keep CodeEditSourceEditor unless it blocks features.
**Claude Opus:** Be ready to drop it — it's flagged "not ready for production use."
**Gemini:** Either works; choose whichever makes viewport-only highlighting easiest.

**Resolution:** Do not change the editor shell now. Benchmark the current shell first. Treat CodeEditSourceEditor's production-readiness disclaimer as a risk register item, not an immediate action. If benchmarks show the current shell meets targets (< 16ms keystroke-to-highlight, stable 60fps scroll), keep it. If it doesn't, evaluate STTextView (check GPL license terms) or a custom TextKit 2 NSTextView.

### 5.3 Where tree-sitter lives (graph-engine vs new crate)

**All sources agree** it should be in a new crate, but disagree on whether to reuse graph-engine's existing tree-sitter dependencies.

**Resolution:** Create `syntax-core` as an independent crate. Do not depend on graph-engine. If graph-engine currently uses tree-sitter for something (e.g., the Markdown Parser), evaluate whether that usage should migrate to syntax-core or remain separate. The key constraint is: syntax-core must not create a build-time dependency between the editor and the graph physics engine.

### 5.4 BoltFFI vs Raw C FFI for the typed buffer prototype

Some research assumes BoltFFI (the specific toolchain) is used; others recommend raw `#[repr(C)]` + cbindgen.

**Resolution:** For the first graph prototype, use raw `#[repr(C)]` structs with a hand-written or cbindgen-generated C header. This is what the existing graph_engine.h already uses — it's proven, understood, and doesn't introduce a new build dependency. BoltFFI (the specific tool) can be evaluated later if the manual approach becomes maintenance-heavy across many surfaces. The *concept* of zero-copy typed buffers is what matters, not the specific toolchain.

---

## Part 6: Summary Timeline

| Priority | Session | What | Risk | Depends On |
|----------|---------|------|------|------------|
| **NOW** | 1 | Benchmark Harness | Zero — instrumentation only | Nothing |
| **Next** | 4 | Swift 6 Concurrency Hardening | Low — bug fixes | Nothing |
| **After baselines** | 2 | Graph BoltFFI Typed Buffer Prototype | Medium — behind flag | Session 1 |
| **After graph works** | 3 | Graph Chat Receiver Wiring | Low | Session 2 (soft) |
| **Parallel** | 5 | syntax-core Crate Scaffolding | Zero — no wiring | Nothing |
| **After graph proven** | 6 | Agent Streaming Instrumentation | Zero — instrumentation only | Session 2 |
| **Future** | — | Editor syntax bridge via syntax-core | Medium | Sessions 1, 2, 5 |
| **Future** | — | Agent streaming BoltFFI prototype | Medium | Sessions 2, 6 |
| **Future, conditional** | — | Rope canonical ownership migration | High | Editor benchmarks proving need |
| **Future, conditional** | — | Metal overlays (minimap, gutter) | Medium | Editor shell decision |

---

## Part 7: Context Pack for Claude Code Sessions

When starting a Claude Code session for any of the above, include this context:

```
Authority: PLAN_V2.md §22 — benchmark first, migrate only proven hot paths,
keep Rust sovereign, no silent behavior.

Current state: Phase 7 Step 8 complete. BoltFFI audit inventory done (no
migrations). 9 commits landed. Graph workspace navigation works. Graph note
page uses TextKit 2. Graph chat bridge dispatches but has no receiver.

FFI surface: 127 C FFI functions in graph_engine.h, 182 UniFFI exports in
agent_core, 16 in omega-mcp. Knowledge Core already uses shared memory.

Five boltffi_priority graph sections: Data Loading (7 functions), Queries (5),
Search (6), Markdown Parser (11), SDF Labels (5).

Non-negotiables:
- Rust owns routing, permissions, cancellation, audit
- No silent backend switching or cloud escalation
- No full Metal text rendering
- No mass BoltFFI migration
- Benchmark before migrate
- Compatibility flag for all migrations
- Parity tests before flipping flags
```
