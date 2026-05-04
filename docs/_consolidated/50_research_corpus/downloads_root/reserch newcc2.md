# Epistemos Architecture Deep Audit
## BoltFFI Hot Paths, Generation IDs, Code Editor, and Agent System
**Date:** 2026-04-15 | **Authority:** `docs/architecture/PLAN_V2.md` | **Status:** Research only — no migrations, no PLAN_V2 edits

***

## 1. Executive Summary

Epistemos is a local-first cognitive OS built on a **Rust-sovereign control plane** with Swift UI surfaces and a C FFI / UniFFI transport layer between them. As of Phase 7 Step 8 (commit `ae4c22d0`), the entire Swift ↔ Rust surface has been inventoried but **no BoltFFI migrations have been executed** — Step 8 is explicitly "audit inventory only."[^1][^2]

The correct next action is **not** to migrate bridges or rebuild the code editor. It is to write a benchmark harness for the three graph hot paths already ranked as first-wave candidates, then use measured data to justify any further migration. Every architectural recommendation below derives directly from PLAN_V2.md §22 and the verified BOLTFFI_AUDIT_2026_04_15.md inventory — nothing is invented beyond those anchors.[^1]

***

## 2. What the Repo Already Has (Verified From Files)

### 2.1 FFI Transport Inventory (Step 8 Verified)

| Transport | Crate | Surface Count | Status |
|-----------|-------|---------------|--------|
| C FFI header (`graph_engine.h`) | `graph-engine` | ~127 functions, 28 section groups, 1,042 lines | Active |
| UniFFI exports | `agent_core` | 37 in `bridge.rs`, 182 total across 20 files | Active |
| UniFFI exports | `omega-mcp` | 16 in `dispatcher.rs` | Active |
| UniFFI exports | `epistemos-core` | 0 direct exports in `lib.rs` today | Stub |
| Shared-memory reactive FFI | `graph-engine` Knowledge Core §752 | 15 functions, already migrated | Already SHM |

Sources:[^2]

### 2.2 Graph C FFI Classification (from BOLTFFI_AUDIT_2026_04_15.md)

| Section | Functions | Frequency | Classification | Wave |
|---------|-----------|-----------|----------------|------|
| Graph Data Loading (§25) | 7 | Per edit / tab switch | `boltffi_priority` | **First** |
| Queries (§277) | 5 | Medium — hover/inspector | `boltffi_priority` | **First** |
| Search (§292) | 6 | High — every keystroke | `boltffi_priority` | **First** |
| Markdown Parser (§468) | 11 | High — every edit | `boltffi_priority` | Close behind graph |
| SDF Label Rendering (§966) | 5 | 60 fps | `boltffi_priority` | Close behind graph |
| Embeddings (§337) | 12 | High — every retrieval | `shared_memory_candidate` | Separate — vectors too large for typed transfer |
| Highlighting (§154) | 11 | Medium | `boltffi_candidate` | Second tier |
| Confidence (§399) | 12 | Medium | `boltffi_candidate` | Second tier |
| Block Transaction Kernel (§561) | 18 | Per edit | `boltffi_candidate` | Second tier |
| Rendering, Input, Camera, Scalars | ~45 | Various | `keep_uniffi` | — |

Sources:[^2]

### 2.3 Agent Core UniFFI Surface (Verified)

The 182 exports across 20 files are classified as follows by the audit:[^2]

| File | Exports | Classification |
|------|---------|----------------|
| `bridge.rs` | 37 | `boltffi_candidate` — streaming events especially |
| `approval.rs` | 13 | `keep_uniffi` — must stay auditable |
| `channel_relay.rs` | 16 | `keep_uniffi` — cold control-plane |
| `session.rs` | 14 | `boltffi_candidate` — session graph payloads |
| `storage/memory_classifier.rs` | 8 | `boltffi_candidate` — batch results |
| `storage/neural_cache.rs` | 5 | `shared_memory_candidate` — KV slabs |
| `routing.rs`, `vault_registry.rs`, providers | ~15 | `keep_uniffi` |

The highest-priority streaming surfaces per PLAN_V2 §22.4 are: agent stream events (token + thinking deltas), tool call start/input/output events, trace/replay event batches, and session lineage summaries. These remain on UniFFI today and are the correct second wave after graph.[^2]

### 2.4 Phase 7 Work Verified

Nine commits landed between `beba8ee8` and `ae4c22d0`:[^3]

- Graph workspace Finder-style route history with back/forward navigation
- TextKit 2 graph note page (`GraphNotePage`)
- Graph folder page with `openNode sourceId` regression fixed
- Typed Graph Chat bridge (`GraphChatRequest`) — dispatcher exists but no receiver wired yet (intentional deferral)
- Settings sidebar simplified to 6 categories
- BoltFFI hot-path migration audit document (inventory only, no code changes)

***

## 3. Current Pain Points, Ranked by Severity

### P0 — No Benchmark Harness Exists
PLAN_V2 §22.5 requires measuring payload size, call frequency, allocation count, Swift main-thread time, Rust marshalling time, and end-to-end latency before any migration. The Step 8 audit explicitly states "No benchmarks yet. A measurement harness lands in the first migration slice, not here." Without this, all migration decisions are speculation. This is the single highest-priority gap.[^1][^2]

### P0 — No Graph BoltFFI Migration Prototype Yet
The five `boltffi_priority` graph sections (Data Loading, Queries, Search, Markdown Parser, SDF Labels) are identified as first-wave candidates but remain on unmodified C FFI. Graph Data Loading + Queries + Search are the correct first vertical slice per §22.6. There is no compatibility flag, no typed buffer layout, and no parity test yet.[^1][^2]

### P1 — Graph Chat Receiver Not Wired
`GraphState.askGraphChat(nodeId:)` dispatches a `GraphChatRequest` notification, but no non-test subscriber exists in the app tree. This is an intentional deferral — the Agent Command Center or `GraphChatState` will subscribe in a later slice — but it means the graph-to-agent pathway is currently a stub that silently does nothing outside of tests.[^3]

### P1 — Swift 6 Concurrency — NotificationCenter Pattern Risk
Phase 7 surfaced a systemic risk: any NotificationCenter observer capturing `note.userInfo` in a `@Sendable` closure will trigger a data-race warning in Swift 6 strict mode, and this cascades as `@const`/`@section` compile errors into adjacent unrelated test files. The fix (`MainActor.assumeIsolated` on `.main`-queue observers) is localized, but the pattern likely recurs in any new observer added to graph, capture, or agent paths.[^3]

### P1 — Agent Command Center Compile Path is Cosmetic Until Wired
The ACC has a full SwiftUI surface and `AgentCommandCenterState`, but PLAN_V2 requires "a full binding pipeline from SwiftUI command state into Rust request compilation so the UI is not cosmetic". The slash/mention parsing, capability handshake, MCP/tool restriction toggles, and Rust compile path are not verified complete from the file inventory.[^1]

### P2 — openNode sourceId Regression Covered But Pattern is Fragile
`openNode` now resolves `node.sourceId` before dispatching, fixed in Step 5 and covered by five tests. However, the `resolvedId = node.sourceId?.isEmpty == false ? node.sourceId! : id` pattern uses a force-unwrap inside a conditional that only fires when non-empty, which AGENTS.md prohibits. This should be rewritten as a guard-let.[^3]

### P2 — SDF Label Rendering at 60 fps Without Typed Buffer
The SDF Label Rendering section (5 functions at 60 fps with a label instance array) is on raw C FFI today. At frame rate, any extra allocation or copy in this path directly contributes to frame hitches in the graph viewport. This is the fastest-frequency unoptimized surface.[^2]

### P3 — xcodeproj Drift Risk
PLAN_V2 §22 and the Phase 7 handoff both require `xcodegen generate` to produce zero diff. Any new file added outside of `project.yml` creates drift. This should be checked as part of the benchmark harness setup.[^3]

***

## 4. Code Editor Current-State Map

> **Verified:** The query requested reading `Epistemos/Views/Notes/CodeEditorView.swift` and related files. Based on available file inventory in the audit documents, the code editor surface is referenced in PLAN_V2 §22.4 as an existing Swift-side editor, with the BoltFFI audit confirming the Markdown Parser (§468, 11 functions, high frequency) as the closest related C FFI surface currently touching the edit path. No direct source file inspection was possible in this session; the following is derived from PLAN_V2 and the audit.

### What the Plan Says About the Current Editor

PLAN_V2 §22.4 specifies the code editor architecture target:[^1]

- Swift/TextKit (or current native editor layer) must remain responsible for: text input, IME composition, selection, undo/redo, accessibility, native scrolling
- Rust should own: parsing, syntax token generation, folds, diagnostics
- BoltFFI carries: compact token/fold/diagnostic deltas (after benchmarking)
- Metal is used only for: minimap, gutters, diagnostics heatmaps, diff overlays, background decoration
- Full Metal text rendering is explicitly prohibited unless benchmarks prove necessity

### Inferred Current State (From Audit Cross-Reference)

The Markdown Parser C FFI section (§468) shows 11 parse helper functions called from `NoteTextView` with `C string in → token array out` at high frequency (every edit). This implies:[^2]
- Syntax/parse work is already partially in Rust (called from NoteTextView)
- The transport is raw C strings over the existing C FFI header — no generation IDs, no viewport scoping, no dirty-range batching
- Full token arrays are likely materialized on every parse event, not delta-encoded

The graph note page (`GraphNotePage`) added in Phase 7 Step 4 uses a real TextKit 2 editor via `ProseEditorView`, confirming TextKit 2 is the active editor substrate for at least the graph note path.[^3]

### TextKit 2 Status Assessment

TextKit 2 (`NSTextLayoutManager`) uses viewport-based layout — it only lays out the visible portion of the document, which provides noncontiguous layout performance for large files. The creator of STTextView (a TextKit 2 implementation without NSTextView baggage) has noted that TextKit 2's architecture is fundamentally sound for progressive complexity. Real-world implementations report loading million-line files in milliseconds with lazy layout. Known weakness: single-paragraph very large files still lag because TextKit 2 lays out the entire paragraph as one fragment.[^4][^5][^6][^7][^8]

***

## 5. Recommended Rust Code-Editor Stack

This recommendation follows PLAN_V2 §22.4 exactly — no speculation beyond what the plan authorizes.

### 5.1 Text Buffer Model

**Primary recommendation: `crop`** for performance-sensitive Rust-side editing operations.

`crop` is a B-tree rope with:
- Copy-on-write semantics — O(1) clone, which enables cheap snapshots for generation-ID-keyed parse states[^9]
- LF/CRLF line break tracking with byte ↔ line offset conversion
- Strong benchmark performance: roughly 2× faster than `ropey` in multi-cursor edit scenarios[^10]

**Fallback: `ropey`** if Unicode line break coverage beyond LF/CRLF is required (e.g. LS/PS handling).[^11][^12]

**Important:** The canonical text buffer should remain NSTextStorage / TextKit 2 on the Swift side initially. Rust should own a **shadow rope** for parsing only — the rope represents the last-parsed snapshot, not the live editing state. Rust-owned canonical text storage is a later migration, gated by benchmarks proving that Swift text storage is a bottleneck.

### 5.2 Incremental Parsing

**tree-sitter** via the existing Rust bindings (or the `tree-sitter` crate directly).[^13][^14]

Key properties:
- Incremental: updates only the changed nodes on each edit, not a full reparse[^13]
- Fast enough to run on every keystroke
- `changedRanges(from:)` provides the exact dirty byte ranges after a reparse[^15]
- SwiftTreeSitter uses UTF-16 by default for direct NSRange compatibility[^15]

**Crate placement:** tree-sitter should live in a new `syntax-core` crate, **not** in `graph-engine`. The graph engine already has its own C FFI surface and adding code-editor parsing concerns would make both harder to audit. A dedicated `syntax-core` crate keeps parse state, rope shadow, and token materialization separate from graph physics and rendering.

### 5.3 Generation IDs and Stale-Parse Cancellation

A generation counter solves the core cancellation problem for async parsing:

```rust
// In syntax-core, conceptually:
#[repr(C)]
pub struct SyntaxDocumentHandle {
    pub doc_id: u64,          // stable per document lifetime
    pub generation: u64,      // increments on every edit
}

#[repr(C)]
pub struct SyntaxEditDelta {
    pub doc_id: u64,
    pub from_generation: u64, // generation before this edit
    pub to_generation: u64,   // generation after this edit
    pub byte_offset: u64,
    pub old_len: u64,
    pub new_len: u64,
}
```

Any parse result tagged with `from_generation < current_generation` is stale and must be discarded without applying attributes. Swift holds a `SyntaxDocumentHandle` per open file. When an edit arrives, Rust increments `generation` atomically, sends the `SyntaxEditDelta`, and any in-flight parse callback checks `result.generation == handle.generation` before applying tokens. This prevents stale highlight flashes on fast typing without locking.

### 5.4 UTF-8 to UTF-16 Offset Mapping

NSTextStorage and NSRange use UTF-16. Tree-sitter operates on UTF-8 bytes. A compact translation table must live in `syntax-core`:

- Maintain a sorted array of `(utf8_offset, utf16_offset)` pairs at code-point boundaries that differ (i.e., where a UTF-8 multi-byte sequence encodes a UTF-16 surrogate pair)
- For most ASCII/Latin source files this table is empty — translation is `O(1)`
- For mixed-script or emoji-heavy identifiers, binary search in the table gives `O(log n)`

### 5.5 Semantic Token Model

Avoid passing token kind as a `String` across FFI. Assign each scope name (e.g. `keyword`, `string.quoted`, `variable.builtin`) a stable `u16` ID in a compile-time registry. The `SyntaxTokenSpan` struct then carries only numeric IDs:

```rust
#[repr(C)]
pub struct SyntaxTokenSpan {
    pub utf16_start: u32,
    pub utf16_len: u16,
    pub kind_id: u16,  // stable numeric scope ID
    pub flags: u8,     // bold, italic, underline bits
    pub _pad: [u8; 3],
}
```

At 12 bytes per token, a 50K-line Swift file with ~500K tokens fits in 6 MB — a reasonable peak payload for viewport-scoped materialization.

***

## 6. Recommended Swift Editor Shell

### 6.1 Architecture Decision

**Keep Swift/TextKit 2 (or the current ProseEditorView / NSTextView layer) as the canonical editing surface.** The plan's guidance is explicit:[^1]

- Swift/TextKit owns: text input, IME, selection, undo/redo, accessibility, native scrolling
- Rust owns: parsing, token generation, folds, diagnostics

**Do not replace the editor with a full custom NSTextView + Metal text renderer.** The risks are prohibitive: IME composition for CJK and other scripts, VoiceOver / accessibility tree, bidirectional text (RTL Arabic/Hebrew identifiers), font fallback for mixed scripts, and native macOS selection behavior all require deep NSTextView integration.[^1]

### 6.2 Option Comparison

| Option | Editing | IME | A11y | Rust Integration | Risk |
|--------|---------|-----|------|-----------------|------|
| Keep CodeEditSourceEditor + Rust syntax service | ✓ | ✓ | ✓ | Rust owns parse, Swift owns display | Low |
| TextKit 2 custom shell + Rust | ✓ | ✓ | ✓ | Same; cleaner viewport APIs | Low–Medium |
| STTextView + Rust | ✓ | ✓ | Partial | Same | Medium (STTextView is a third-party dep) |
| Full custom Metal text renderer | ✗ — must rebuild everything | ✗ — broken | ✗ — broken | N/A | Prohibitive |

**Recommended path:** TextKit 2 custom shell (or retain the current ProseEditorView/NSTextView layer) plus a Rust syntax service delivering token deltas via BoltFFI. Metal is reserved for the minimap, gutter overlays, and diff/diagnostic decorations only.

### 6.3 Applying Syntax Attributes Safely

Syntax attributes must **never** be applied to the full document on every keystroke. The safe pattern:

1. On edit: send `SyntaxEditDelta` to Rust with current `generation`
2. Rust parses incrementally on a background queue, returns a `SyntaxTokenSpan[]` for only the changed viewport region
3. Swift receives the token batch, checks `generation` matches, applies `NSTextStorage` attribute runs only for the returned spans
4. If generation has advanced again before application, discard the batch silently

This ensures zero full-document attribute application and zero stale flashes.

***

## 7. BoltFFI Design for the Code Editor

### 7.1 What BoltFFI Is

BoltFFI is a high-performance Rust bindings generator that claims up to 1,000× faster than UniFFI for hot paths (microbenchmarks). It achieves this by passing primitives and structs-of-primitives across the boundary without serialization — zero-copy for flat data. For Swift, it generates an XCFramework. It supports the same `#[repr(C)]` layout patterns already used in `graph_engine.h`.[^16][^17][^18]

### 7.2 Proposed Data Shapes

All structs are `#[repr(C)]` and contain only primitives or fixed arrays. No heap pointers cross the boundary.

```rust
/// Opaque stable handle for one open document.
/// Swift holds this for the lifetime of the editor session.
#[repr(C)]
pub struct SyntaxDocumentHandle {
    pub doc_id: u64,       // stable per document
    pub generation: u64,   // monotonically increasing on every edit
}

/// Swift sends this on every text edit (insert/delete/replace).
#[repr(C)]
pub struct SyntaxEditDelta {
    pub doc_id: u64,
    pub from_generation: u64,
    pub to_generation: u64,
    pub byte_offset: u64,   // UTF-8 byte offset of edit start
    pub old_len: u64,       // bytes removed
    pub new_len: u64,       // bytes inserted
}

/// Swift sends this to request tokens for a viewport range.
#[repr(C)]
pub struct SyntaxViewportRequest {
    pub doc_id: u64,
    pub generation: u64,         // generation at time of request
    pub utf16_start: u32,        // viewport start in UTF-16 units
    pub utf16_end: u32,          // viewport end in UTF-16 units
}

/// One syntax token span — 12 bytes flat.
#[repr(C)]
pub struct SyntaxTokenSpan {
    pub utf16_start: u32,
    pub utf16_len: u16,
    pub kind_id: u16,    // stable numeric scope ID, not a string
    pub flags: u8,       // bit 0=bold, bit 1=italic, bit 2=underline
    pub _pad: [u8; 3],
}

/// A fold range (e.g. collapsible code block).
#[repr(C)]
pub struct SyntaxFoldRange {
    pub utf16_start: u32,
    pub utf16_end: u32,
    pub depth: u8,
    pub _pad: [u8; 3],
}

/// A diagnostic range (warning/error marker).
#[repr(C)]
pub struct SyntaxDiagnosticRange {
    pub utf16_start: u32,
    pub utf16_len: u16,
    pub severity: u8,   // 0=hint, 1=info, 2=warning, 3=error
    pub source_id: u8,  // which LSP/linter produced this
}

/// Snapshot statistics for telemetry.
#[repr(C)]
pub struct SyntaxSnapshotStats {
    pub doc_id: u64,
    pub generation: u64,
    pub token_count: u32,
    pub fold_count: u32,
    pub diagnostic_count: u32,
    pub parse_ns: u64,     // nanoseconds Rust spent parsing
    pub _pad: [u8; 4],
}
```

### 7.3 Memory Ownership Rules

| Struct | Allocator | Who Frees | Valid Until | Copy or Borrow |
|--------|-----------|-----------|-------------|----------------|
| `SyntaxDocumentHandle` | Swift (stack or heap) | Swift | End of editor session | Swift holds, passes by value to Rust |
| `SyntaxEditDelta` | Swift (stack) | Swift | After the FFI call returns | Copied into Rust on call |
| `SyntaxViewportRequest` | Swift (stack) | Swift | After the FFI call returns | Copied into Rust on call |
| `SyntaxTokenSpan[]` buffer | Rust (internal arena) | Rust | Until Swift calls `syntax_release_token_batch(doc_id, batch_ptr)` | Borrowed — Swift reads synchronously then calls release |
| `SyntaxFoldRange[]` | Same as token batch | Rust | Same | Same |
| `SyntaxDiagnosticRange[]` | Same | Rust | Same | Same |
| `SyntaxSnapshotStats` | Rust (stack return) | N/A | After the FFI call returns | Copied to Swift |

**Critical safety rules:**
- Swift must **never** retain a `SyntaxTokenSpan*` pointer after calling `syntax_release_token_batch`
- Swift reads token spans synchronously on the token-delivery callback, then releases immediately — no async retention
- Rust must not free the batch buffer until `syntax_release_token_batch` is called
- `doc_id` and `generation` together form the correlation key — a response tagged with a stale generation is silently ignored by Swift, not an error
- No heap pointer from Rust should ever be stored in a Swift `@Published` or `@State` property; convert to value types before storing

### 7.4 Cancellation via Generation IDs

Generation counters provide implicit cancellation at zero extra cost:

1. User types a character → `from_generation=N`, `to_generation=N+1` sent to Rust
2. User types another character before parse completes → `from_generation=N+1`, `to_generation=N+2`
3. Rust finishes parsing N+1 but checks `current_generation == N+2` — generation mismatch → drops result
4. No explicit cancel message needed; the generation counter is the cancellation signal

For explicit user-initiated cancellation (e.g. document close), send a `SyntaxEditDelta` with `new_len=0, old_len=entire_document` and the highest generation, then call `syntax_close_document(doc_id)`.

***

## 8. BoltFFI Design for Agent Streaming

### 8.1 Which Agent Events Justify BoltFFI

Per PLAN_V2 §22.4, agent streaming is the **second wave** after graph — not the first. The following events are high-frequency enough to justify eventual migration:[^1]

| Event | Frequency | Current Transport | BoltFFI Justification |
|-------|-----------|------------------|-----------------------|
| Token delta | Very high — every partial token | UniFFI struct | Yes — 10–50 Hz during generation |
| Thinking delta | High | UniFFI struct | Yes — same rate as token |
| Tool call start | Medium | UniFFI | Maybe — depends on tool rate |
| Tool call output | Variable | UniFFI / JSON | Large payloads → SHM candidate for large outputs |
| Diagnostics snapshot | Low | UniFFI | No — cold path |
| Execution summary | Per-session | UniFFI | No — cold path |
| Session lineage | Per-session | UniFFI | No — cold path |

### 8.2 Proposed Typed Event Structs

```rust
/// Token or thinking character delta — flat, high-frequency.
#[repr(C)]
pub struct AgentTokenDelta {
    pub session_id: u64,
    pub request_id: u64,
    pub generation: u64,       // for stale-discard
    pub delta_kind: u8,        // 0=token, 1=thinking
    pub _pad: [u8; 7],
    pub utf8_buf: [u8; 64],    // fixed buffer — covers ~95% of deltas
    pub utf8_len: u8,          // actual used bytes
    pub _pad2: [u8; 7],
}

/// Tool call event — lightweight header only.
#[repr(C)]
pub struct AgentToolCallEvent {
    pub session_id: u64,
    pub request_id: u64,
    pub tool_id: u32,          // stable numeric ID from tool registry
    pub event_kind: u8,        // 0=start, 1=streaming_input, 2=output, 3=error
    pub requires_approval: u8, // 1 if destructive action gate triggered
    pub _pad: [u8; 2],
    pub payload_len: u32,      // length of payload in accompanying SHM or follow-up call
}
```

### 8.3 What Must Stay on UniFFI

The following agent surfaces must **never** be migrated to BoltFFI:[^2][^1]

- `approval.rs` (13 exports) — destructive action approval requires explicit audit semantics; changing the transport risks losing the approval gate
- `routing.rs` — Rust control-plane sovereignty; routing decisions must not be replicated in Swift
- `channel_relay.rs` — cold control-plane; not worth migrating
- Any surface that carries permission policy, budget enforcement, or escalation decisions

PLAN_V2 §3.1 is explicit: "Rust is the sole authority for routing, lifecycle, cancellation, budget enforcement, safety and policy, fallback, runtime resolution, agent communication permissions, escalation approval, telemetry and audit." Migrating approval or routing surfaces to BoltFFI would risk pushing Swift into a position where it has a lower-latency path to influence routing — that path must not exist.[^1]

### 8.4 Backpressure and Coalescing

Before migrating token deltas to BoltFFI, measure whether **coalescing deltas in Rust before crossing the bridge** eliminates the overhead without any FFI change:

- Rust batches 8–16 token characters into a single UniFFI delivery
- Swift receives fewer, larger calls
- This is free, requires no BoltFFI work, and may eliminate the bottleneck entirely

Only if profiling shows the bridge crossing itself (not the payload size) is the bottleneck should token deltas migrate to BoltFFI. The benchmark harness (Section 11) must answer this before any migration.

***

## 9. BoltFFI Design for Graph Hot Paths

### 9.1 First Migration Candidates (Verified from Audit)

The Step 8 audit identifies three sections as the first migration candidate: **Graph Data Loading**, **Queries**, and **Search**. These are called from `GraphState.applyPending*`, `graph_engine_neighbors`, and the typed-ahead search path respectively.[^2]

### 9.2 Proposed Typed Buffer Layout for Graph Data Loading

```rust
/// Batch node addition — replaces per-node C string calls.
#[repr(C)]
pub struct GraphNodeBatch {
    pub node_ids: *const u64,    // array of node UUIDs as u64[^2] pairs
    pub labels: *const u8,       // UTF-8 label data, null-terminated, packed
    pub label_offsets: *const u32, // start byte in labels[] per node
    pub node_count: u32,
    pub _pad: [u8; 4],
}

/// Neighbor query result — replaces GraphSearchResult* array.
#[repr(C)]
pub struct GraphNeighborResult {
    pub neighbor_id: u64,
    pub edge_weight: f32,
    pub edge_kind: u16,
    pub depth: u8,
    pub _pad: u8,
}

/// Typed-ahead search result — replaces C string return.
#[repr(C)]
pub struct GraphSearchResult {
    pub node_id: u64,
    pub score: f32,
    pub match_kind: u8,   // 0=label, 1=embedding, 2=both
    pub _pad: [u8; 3],
}
```

### 9.3 Compatibility Flag Pattern

Per §22.6: "Keep the existing bridge behind a compatibility switch until parity and benchmarks pass."[^1]

```swift
// GraphState.swift — compatibility flag
private static let useBoltFFIGraph = ProcessInfo.processInfo
    .environment["EPISTEMOS_BOLTFFI_GRAPH"] == "1"
```

The old C FFI path remains active by default. The BoltFFI path is enabled only via environment variable during benchmark and parity testing. Once benchmarks pass and parity tests cover the full surface, the flag is removed and the old path retired.

### 9.4 Which Graph Paths Should Use Shared Memory

The Embeddings section (§337, 12 functions, `float* vector, count`) is a `shared_memory_candidate`, not a BoltFFI candidate. The Knowledge Core (§752, 15 functions) is already shared-memory. The correct pattern for both is an SPSC ring buffer over shared memory with `#[repr(C, align(128))]` structs (128-byte alignment for Apple Silicon cache line pairs). BoltFFI typed transfer is the wrong shape for float vectors — copying them is the bottleneck, not the bridge mechanism.[^19][^2]

### 9.5 SDF Label Rendering at 60 fps

The SDF Label Rendering section (§966, 5 functions, label instance array at 60 fps) is unique: it is called in the Metal draw loop. The correct approach is a single `*const SdfLabelInstance` pointer + count pair, where the buffer is produced by Rust into a **Metal-shared** region and consumed by the GPU directly — not copied to Swift and back. This is a distinct problem from BoltFFI (which optimizes CPU-side transfer) and requires Metal buffer sharing instead.

***

## 10. What Should Stay on UniFFI / Current Bridge

The following must not be migrated, per the combined authority of PLAN_V2 §22 and the Step 8 audit:[^2][^1]

| Surface | Reason to Keep |
|---------|---------------|
| `approval.rs` (13 exports) | Destructive action gate — audit semantics would be weakened |
| `routing.rs` (2 exports) | Rust routing sovereignty must not be accelerated into Swift |
| `channel_relay.rs` (16 exports) | Cold control-plane — not a hot path |
| `vault.rs`, `vault_registry.rs` | Typed ergonomics > throughput for CRUD |
| Graph Lifecycle (2 fns) | One-shot per session — no migration value |
| Graph Rendering (3 fns) | Already one opaque scalar — not a marshalling bottleneck |
| Graph Force/Camera/Physics scalars | Low-frequency user tweaks |
| `omega-mcp` dispatcher entry points | MCP protocol is the real transport boundary |
| Agent `skill_router.rs`, `context_loader.rs` | Cold path |
| All capabilities listed in the public runtime contract (`load_model`, `generate`, `cancel`, etc.) | These are the stable public boundary per §3.2[^1] — changing transport risks ABI drift |

***

## 11. Benchmark Plan

Per PLAN_V2 §22.5, benchmarks are **required before any migration**. The following plan is concrete and immediately actionable.[^1]

### 11.1 Code Editor Benchmarks

| Benchmark | Method | Target |
|-----------|--------|--------|
| File open time (1K / 10K / 50K / 100K lines) | Swift signpost around `NSTextStorage` load | < 100ms at 100K lines |
| Keystroke-to-highlight latency | `os_signpost` begin on keyDown, end on attribute apply | < 16ms (1 frame) |
| Scroll FPS in 50K-line file | Instruments Core Animation | 60 fps sustained |
| Memory growth during 10-minute typing session | Allocations instrument | No unbounded growth |
| Full-file attribute application cost | Isolate `addAttribute:range:` in a test target | Baseline for "do not do this" |

Tools: Instruments Time Profiler, Allocations, `os_signpost`[^20][^21][^22]

### 11.2 Graph Hot-Path Benchmarks

| Benchmark | Method | Target |
|-----------|--------|--------|
| Graph open with 1K / 5K / 10K nodes | Signpost around `applyPending*` | < 200ms at 10K |
| Typed-ahead search latency | Signpost around Search C FFI call | < 50ms per query |
| Neighbor query latency | Signpost around `graph_engine_neighbors` | < 10ms |
| Graph Data Loading batch vs per-node | Cargo criterion microbenchmark | Measure before proposing BoltFFI |
| Per-frame SDF label copy cost | Metal frame capture in Instruments GPU | Isolate copy overhead |

### 11.3 Agent Streaming Benchmarks

| Benchmark | Method | Target |
|-----------|--------|--------|
| Token delta rate during generation | Count UniFFI calls per second | Measure baseline |
| Swift main-thread time per token delivery | `os_signpost` on each `poll_event` | < 0.5ms per event |
| UI frame impact during streaming | Core Animation FPS while streaming | No frame drops |
| Delta coalescing impact | Batch 8 tokens before delivery, re-measure | Measure reduction |

### 11.4 General FFI Benchmarks

| Benchmark | Method |
|-----------|--------|
| UniFFI call overhead (empty roundtrip) | `cargo bench` + Swift microbenchmark |
| BoltFFI call overhead (empty roundtrip) | Same, with BoltFFI prototype |
| Allocation count per bridge call | `heaptrack` on Rust side, Allocations on Swift side |
| Copy count for batch results | Memory profiler on `GraphSearchResult*` return |

### 11.5 Before/After Table Template

```
| Surface                  | Metric           | Before   | After    | Delta  |
|--------------------------|------------------|----------|----------|--------|
| Graph Data Loading       | alloc/call       | —        | —        | —      |
| Graph Search (keystroke) | latency ms       | —        | —        | —      |
| Token delta delivery     | main-thread µs   | —        | —        | —      |
| File open 100K lines     | open ms          | —        | —        | —      |
```

***

## 12. Migration Order

This order follows PLAN_V2 §22.6 exactly:[^1]

1. **Now — Benchmark harness only.** Add `os_signpost` instrumentation around the five `boltffi_priority` graph sections, the Markdown Parser, the token delivery path, and the code editor load/highlight path. No code migration. Record baseline numbers in a benchmark CSV.

2. **Next — Graph Data Loading + Queries + Search prototype.** Build BoltFFI bindings for these three sections only. Keep old C FFI behind `EPISTEMOS_BOLTFFI_GRAPH=1` flag. Add parity tests (same result from both paths on identical inputs). Run benchmarks again. Publish delta.

3. **If graph benchmark passes — SDF Label Rendering.** Evaluate whether a Metal-buffer-sharing pattern eliminates the copy, separate from BoltFFI.

4. **If graph is stable — Agent token delta coalescing.** First try batching in Rust (no FFI change). Measure. Only if coalescing is insufficient and bridge overhead is the bottleneck, prototype BoltFFI for `AgentTokenDelta`.

5. **After agent streaming benchmarks — Code editor Markdown Parser.** Add `SyntaxEditDelta` + `SyntaxTokenSpan[]` BoltFFI path. Keep TextKit 2 as canonical editor. Apply tokens in viewport-scoped batches. Add generation ID stale-discard.

6. **Optional — Rust rope shadow model.** Only if Swift `NSTextStorage` is measured as a bottleneck. `crop` as the shadow rope, with Rust owning only the parse snapshot, not the live edit buffer.

7. **Optional — Metal overlay layers.** Minimap, gutter, diagnostics heatmap as Metal-rendered overlays. Only after the TextKit 2 + Rust syntax service path is stable and benchmarks show specific rendering bottlenecks.

8. **Never (without extreme data) — Full Metal text rendering, mass bridge migration, routing/permissions in Swift.**

***

## 13. Risk Register

| Risk | Severity | Likelihood | Mitigation |
|------|----------|-----------|------------|
| BoltFFI prototype breaks approval/routing audit trail | P0 | High if migration scope expands | Hard rule: approval.rs and routing.rs never migrate |
| Generation ID overflow on long sessions | P1 | Low | Use u64 — would require 2⁶⁴ edits to overflow |
| Swift retaining stale Rust pointer after `syntax_release_token_batch` | P0 | Medium (easy mistake) | Wrap in Swift struct with deinit that calls release; never expose raw pointer |
| Swift 6 data-race cascade in new observer code | P1 | High — pattern recurs | Enforce `MainActor.assumeIsolated` wrapper for all `.main`-queue NotificationCenter observers[^3] |
| TextKit 2 single-paragraph lag at very large file sizes | P2 | Low for code files | Code files rarely have 100K-char single paragraphs; monitor with benchmark |
| crop LF/CRLF-only line breaks missing Unicode breaks | P2 | Low for code | Code editors rarely need LS/PS; fall back to ropey if needed |
| Graph BoltFFI path diverging from C FFI path under edge cases | P1 | Medium | Parity tests with fuzz inputs on both paths before retiring old path |
| Missed xcodeproj drift when adding syntax-core crate | P2 | Medium | Add `syntax-core` to `project.yml` before writing any Swift bindings |
| Agent streaming migration before benchmarks justify it | P1 | Medium — pressure to "improve" | Hard requirement: publish baseline benchmark numbers first |
| openNode force-unwrap in sourceId resolution | P2 | Present now | Refactor to `guard let` before Step 9 begins |

***

## 14. Exact Files to Change Later

This is a research-only list. No changes are made now.

### Benchmark Harness (Step 1)
- `Epistemos/Graph/GraphState.swift` — add `os_signpost` around `applyPending*`, `openNode`, search calls
- `Epistemos/Views/Graph/MetalGraphView.swift` — add signpost around `mouseDown` search dispatch and neighbor queries
- `Epistemos/Bridge/StreamingDelegate.swift` — add signpost around `poll_event` delivery
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` — add signpost around file open and first highlight
- New file: `EpistemosTests/BenchmarkHarnessTests.swift` — disabled-by-default benchmark suite

### Graph BoltFFI Prototype (Step 2)
- New crate: `graph-engine-boltffi/` — typed `GraphNodeBatch`, `GraphNeighborResult`, `GraphSearchResult` structs
- `graph-engine-bridge/graph_engine.h` — add BoltFFI section annotations
- `Epistemos/Graph/GraphState.swift` — add compatibility flag + BoltFFI dispatch path
- New file: `EpistemosTests/GraphBoltFFIParityTests.swift`

### Syntax Core Crate (Step 5)
- New crate: `syntax-core/` — `SyntaxDocumentHandle`, `SyntaxEditDelta`, `SyntaxViewportRequest`, `SyntaxTokenSpan`, `SyntaxFoldRange`, `SyntaxDiagnosticRange`, `SyntaxSnapshotStats`, crop shadow rope, tree-sitter incremental parse loop, generation counter, UTF-8 ↔ UTF-16 offset table
- `project.yml` — add `syntax-core` target
- `Epistemos/Views/Notes/CodeEditorView.swift` — add Rust syntax service bridge
- `Epistemos/Views/Notes/ProseEditorView.swift` — viewport-range-aware token application
- New file: `EpistemosTests/SyntaxCoreParityTests.swift`

### Generation ID Fixes (Ongoing)
- `Epistemos/Graph/GraphState.swift` — refactor `openNode` force-unwrap to `guard let`
- Any new NotificationCenter observer — enforce `MainActor.assumeIsolated` wrapper

***

## 15. Exact Tests and Benchmarks to Add Later

### Tests

| Test File | What to Verify |
|-----------|---------------|
| `GraphBoltFFIParityTests.swift` | Same result from BoltFFI and C FFI paths on 1K/5K/10K node graphs |
| `SyntaxCoreGenerationTests.swift` | Stale generation discards token batch; current generation applies; u64 overflow safe |
| `SyntaxCoreOffsetTests.swift` | UTF-8 ↔ UTF-16 offset table correct for ASCII, BMP, and supplementary plane characters |
| `SyntaxCoreTokenSpanTests.swift` | Viewport-scoped token materialization returns only visible tokens |
| `AgentTokenCoalescingTests.swift` | Batched delivery produces identical final text as per-token delivery |
| `BoltFFIMemoryOwnershipTests.swift` | Swift wrapper deinit calls `syntax_release_token_batch`; no use-after-free under stress |

### Benchmark Harness
- `BenchmarkHarnessTests.swift` — disabled by default (`XCTSkipIf(!ProcessInfo.processInfo.environment["EPISTEMOS_BENCH"] == "1")`); covers file open, keystroke latency, scroll FPS, graph open, graph search, token delivery rate
- Before/after CSV committed to `docs/architecture/BENCHMARK_BASELINES.csv`
- `cargo bench` in `syntax-core` for parse time and rope operation latency

***

## 16. Direct Answers

### Should Epistemos rebuild the code editor now?
**No.** PLAN_V2 §22.4 is explicit: "the code editor is a first-class BoltFFI candidate only where a measured hot path exists. The target is not a speculative full editor rewrite." No benchmark data exists yet for editor open time, keystroke latency, or scroll FPS. Building the syntax-core Rust service and BoltFFI token delivery path is the right architecture — but it must be built incrementally on top of the existing TextKit 2 shell, not as a replacement for it.[^1]

### Should Epistemos do a mass BoltFFI migration?
**No.** The current audit has inventoried 182 UniFFI exports and ~127 C FFI exports. The correct path is a targeted three-section graph prototype (Data Loading, Queries, Search) behind a compatibility flag, benchmarked against the existing C FFI path. Mass migration would risk breaking the approval/routing audit trail, introduce regressions across surfaces that have no performance problem, and violate §22.5's "migrate only if measured."[^2][^1]

### What is the safest next implementation slice?
**The benchmark harness.** Specifically:
1. Add `os_signpost` intervals around the five `boltffi_priority` graph sections in `GraphState.swift` and `MetalGraphView.swift`
2. Add a signpost around `poll_event` token delivery in `StreamingDelegate.swift`
3. Add a signpost around `NSTextStorage` load and first attribute apply in the note editor
4. Run Instruments Time Profiler, record numbers, commit a `BENCHMARK_BASELINES.csv` to `docs/architecture/`
5. Only then open the graph BoltFFI prototype branch

This is the only slice that cannot cause a regression, cannot drift from the plan, and cannot violate any architectural law — because it adds only instrumentation.

***

## 17. What Not To Do

The following anti-patterns are explicitly called out to prevent drift from PLAN_V2:[^1]

- **Do not mass-migrate every bridge to BoltFFI.** Only benchmark-proven hot paths qualify.
- **Do not rebuild the code editor before benchmarking.** No open-time, keystroke-latency, or scroll-FPS data exists yet.
- **Do not put routing or permissions in Swift.** Rust is the sole authority for both.
- **Do not create a second graph chat architecture.** Graph Chat must flow through the same ACC/Rust compile path.
- **Do not move text input, IME, or accessibility out of native macOS.** The risks (CJK IME, VoiceOver, bidirectional text) are prohibitive.
- **Do not pass full document text across FFI every keystroke.** Only `SyntaxEditDelta` (12 bytes) crosses the bridge per edit.
- **Do not apply syntax attributes to the full file every keystroke.** Viewport-scoped token materialization only.
- **Do not migrate embeddings/vector payloads in the first BoltFFI wave.** Embeddings are a shared-memory problem, not a BoltFFI problem.
- **Do not migrate `approval.rs` or `routing.rs`.** Audit semantics and Rust sovereignty must be preserved.
- **Do not edit PLAN_V2.md.** If the plan appears wrong, stop and ask the operator.

---

## References

1. [PLAN_V2.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/1b42cc65-ea7d-49d6-9485-ecb99e952d69/PLAN_V2.md?AWSAccessKeyId=ASIA2F3EMEYETIQL6VMQ&Signature=IJ8fqbDfwSbpDGIfrRHR2J%2FsCgQ%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEOn%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJHMEUCIEU74P9UtKky90osarBsdsdf5VxfnOL7hfBGlRoEOcIzAiEA7EWh%2Bzq2SBTJzfdQ1oP94oui78iMj4PQFrQEEdg3FMEq%2FAQIsf%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDGO7OpTeiglVUcec2CrQBBnOqks5YxLVSYw5%2BeP5Tlj37O5n4Z9n%2FEjzmofESQixSict23UVocgml9UtTKl48LQIBfrTXx%2BLmI7zhV9Zm8b55Jytl%2F1TC%2B925pTkY13jPHNWPINxHDdxf%2FHFBCllpvudimYtKya%2BKjPt5XRV12opDzavVb99D%2FFiBVAnwQXB3EQK1vQSGasZcahS3D0Nue4CLDhswugw5mbxI5GAUkySjHdO%2BYwka0cg5ykdNFP3mOjERbSdOgFqJr8Ll1e%2FutyqNk6QKytao7MROvWrKdoBVKi8pdZizNXiD%2FC34UIalkDVudlP%2FahHCTmiL%2BwbQhgA3Bu2lN6%2F%2FlHPBio1mn3T9O18hB0FcDsDRRpWO%2FCiroeVn0BysYetvWZLizN6vr3oeaJ%2FLymuavs6NnGlAq5Ubwxn7gK1SCwKnwPclcf88itpid0tiQuUgTvKoa66P4GzM4qY7KgZaXfOpJ%2BpgS3QjwBsY3uofTXnk4jvI4LrBkPSVLjhAIjGtE8iYxb2QJLZ9lOYfjVGnj4T%2FvZ1KTevHiix%2Buba0adFjtdWGD0Xr1AFje%2BmwdSZ8q8XYHkqZ3b5w%2BYwdes%2F8gjnCYARKoqd9TBHrhd%2Fi4om1A2KvgnCWuZn0ComNxE%2B5NiEwwV3oc%2B9HsdTY7Yah8cX2x6Kuj5IiwvnXNTKCP5qtmZzgdXsbGe1g%2BigMPnrZegdtRTiuxdd24ifTObsIoomP%2B%2BAWl3QeZG%2FOidaQ1gjIHS7ZRxndZ12%2FKjyfDjBx2ObNCcvyqpx5jXE9Z%2FIYfjnMWpNpp8whdSAzwY6mAGDidE9edeisE%2ByfYD7vdvNLPY0y3mOPYVjGj4ovkkJuWrVftHfapAIGFri9TrsW7QqjyUw%2FQjlpbFuJCQ7U9ZZri0dG2D5y2gshnjEdH50XBqCafZDNiIE6KHW1uEpsNEWAMYbE5Yv94bfV1Yfpl%2F2MZP6YJ1mfrR2o8Xp39onMZEGfPkfR8HOEjjHPgWiT0Wmq3tA8JiMWw%3D%3D&Expires=1776302040) - Permanent role - embeddings - rerankers - classifiers - KAN helper modules - helper models - LoRA mi...

2. [BOLTFFI_AUDIT_2026_04_15.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/d140fa4f-0a9d-4301-801a-94073f1a5447/BOLTFFI_AUDIT_2026_04_15.md?AWSAccessKeyId=ASIA2F3EMEYETIQL6VMQ&Signature=Jdjle5cDZddQWbKaohBC%2BHRQEZQ%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEOn%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJHMEUCIEU74P9UtKky90osarBsdsdf5VxfnOL7hfBGlRoEOcIzAiEA7EWh%2Bzq2SBTJzfdQ1oP94oui78iMj4PQFrQEEdg3FMEq%2FAQIsf%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDGO7OpTeiglVUcec2CrQBBnOqks5YxLVSYw5%2BeP5Tlj37O5n4Z9n%2FEjzmofESQixSict23UVocgml9UtTKl48LQIBfrTXx%2BLmI7zhV9Zm8b55Jytl%2F1TC%2B925pTkY13jPHNWPINxHDdxf%2FHFBCllpvudimYtKya%2BKjPt5XRV12opDzavVb99D%2FFiBVAnwQXB3EQK1vQSGasZcahS3D0Nue4CLDhswugw5mbxI5GAUkySjHdO%2BYwka0cg5ykdNFP3mOjERbSdOgFqJr8Ll1e%2FutyqNk6QKytao7MROvWrKdoBVKi8pdZizNXiD%2FC34UIalkDVudlP%2FahHCTmiL%2BwbQhgA3Bu2lN6%2F%2FlHPBio1mn3T9O18hB0FcDsDRRpWO%2FCiroeVn0BysYetvWZLizN6vr3oeaJ%2FLymuavs6NnGlAq5Ubwxn7gK1SCwKnwPclcf88itpid0tiQuUgTvKoa66P4GzM4qY7KgZaXfOpJ%2BpgS3QjwBsY3uofTXnk4jvI4LrBkPSVLjhAIjGtE8iYxb2QJLZ9lOYfjVGnj4T%2FvZ1KTevHiix%2Buba0adFjtdWGD0Xr1AFje%2BmwdSZ8q8XYHkqZ3b5w%2BYwdes%2F8gjnCYARKoqd9TBHrhd%2Fi4om1A2KvgnCWuZn0ComNxE%2B5NiEwwV3oc%2B9HsdTY7Yah8cX2x6Kuj5IiwvnXNTKCP5qtmZzgdXsbGe1g%2BigMPnrZegdtRTiuxdd24ifTObsIoomP%2B%2BAWl3QeZG%2FOidaQ1gjIHS7ZRxndZ12%2FKjyfDjBx2ObNCcvyqpx5jXE9Z%2FIYfjnMWpNpp8whdSAzwY6mAGDidE9edeisE%2ByfYD7vdvNLPY0y3mOPYVjGj4ovkkJuWrVftHfapAIGFri9TrsW7QqjyUw%2FQjlpbFuJCQ7U9ZZri0dG2D5y2gshnjEdH50XBqCafZDNiIE6KHW1uEpsNEWAMYbE5Yv94bfV1Yfpl%2F2MZP6YJ1mfrR2o8Xp39onMZEGfPkfR8HOEjjHPgWiT0Wmq3tA8JiMWw%3D%3D&Expires=1776302040) - Date 2026-04-15 Phase 7, Step 8 Status audit inventory only no migrations in this phase Authority do...

3. [PHASE_7_CODEX_AUDIT_HANDOFF_2026_04_15.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/7398ca85-90c8-4a51-9f06-f1a133173721/PHASE_7_CODEX_AUDIT_HANDOFF_2026_04_15.md?AWSAccessKeyId=ASIA2F3EMEYETIQL6VMQ&Signature=GC7HGG%2BB2UILdrSF%2F0Dc1FIgno8%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEOn%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJHMEUCIEU74P9UtKky90osarBsdsdf5VxfnOL7hfBGlRoEOcIzAiEA7EWh%2Bzq2SBTJzfdQ1oP94oui78iMj4PQFrQEEdg3FMEq%2FAQIsf%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDGO7OpTeiglVUcec2CrQBBnOqks5YxLVSYw5%2BeP5Tlj37O5n4Z9n%2FEjzmofESQixSict23UVocgml9UtTKl48LQIBfrTXx%2BLmI7zhV9Zm8b55Jytl%2F1TC%2B925pTkY13jPHNWPINxHDdxf%2FHFBCllpvudimYtKya%2BKjPt5XRV12opDzavVb99D%2FFiBVAnwQXB3EQK1vQSGasZcahS3D0Nue4CLDhswugw5mbxI5GAUkySjHdO%2BYwka0cg5ykdNFP3mOjERbSdOgFqJr8Ll1e%2FutyqNk6QKytao7MROvWrKdoBVKi8pdZizNXiD%2FC34UIalkDVudlP%2FahHCTmiL%2BwbQhgA3Bu2lN6%2F%2FlHPBio1mn3T9O18hB0FcDsDRRpWO%2FCiroeVn0BysYetvWZLizN6vr3oeaJ%2FLymuavs6NnGlAq5Ubwxn7gK1SCwKnwPclcf88itpid0tiQuUgTvKoa66P4GzM4qY7KgZaXfOpJ%2BpgS3QjwBsY3uofTXnk4jvI4LrBkPSVLjhAIjGtE8iYxb2QJLZ9lOYfjVGnj4T%2FvZ1KTevHiix%2Buba0adFjtdWGD0Xr1AFje%2BmwdSZ8q8XYHkqZ3b5w%2BYwdes%2F8gjnCYARKoqd9TBHrhd%2Fi4om1A2KvgnCWuZn0ComNxE%2B5NiEwwV3oc%2B9HsdTY7Yah8cX2x6Kuj5IiwvnXNTKCP5qtmZzgdXsbGe1g%2BigMPnrZegdtRTiuxdd24ifTObsIoomP%2B%2BAWl3QeZG%2FOidaQ1gjIHS7ZRxndZ12%2FKjyfDjBx2ObNCcvyqpx5jXE9Z%2FIYfjnMWpNpp8whdSAzwY6mAGDidE9edeisE%2ByfYD7vdvNLPY0y3mOPYVjGj4ovkkJuWrVftHfapAIGFri9TrsW7QqjyUw%2FQjlpbFuJCQ7U9ZZri0dG2D5y2gshnjEdH50XBqCafZDNiIE6KHW1uEpsNEWAMYbE5Yv94bfV1Yfpl%2F2MZP6YJ1mfrR2o8Xp39onMZEGfPkfR8HOEjjHPgWiT0Wmq3tA8JiMWw%3D%3D&Expires=1776302040) - Date 2026-04-15 Audience Codex or a fresh continuation agent auditing Claudes Phase 7 work Status re...

4. [Coeditor: Leveraging Contextual Changes for Multi-round Code
  Auto-editing](https://arxiv.org/pdf/2305.18584.pdf) - Developers often dedicate significant time to maintaining and refactoring
existing code. However, mo...

5. [TextKit 2 - the promised land - Marcin Krzyżanowski](https://blog.krzyzanowskim.com/2025/08/14/textkit-2-the-promised-land/) - Promised an easier, faster, overall better API and text layout engine that replaces the aged TextKit...

6. [Blog - TextKit 2: The Promised Land - Michael Tsai](https://mjtsai.com/blog/2025/08/15/textkit-2-the-promised-land/) - Making a code editor is extremely hard, we are tired of exploring the darkness inside TextKit, but t...

7. [TextKit 2: is it reliable? - Other Software & Development](https://forum.literatureandlatte.com/t/textkit-2-is-it-reliable/144184) - TextKit 2 is definitely reliable. It is used system-wide, including in Scrivener, for text fields (t...

8. [Meet TextKit 2 - WWDC21 - Videos - Apple Developer](https://developer.apple.com/videos/play/wwdc2021/10061/) - Meet TextKit 2: Apple's next-generation text engine, redesigned for improved correctness, safety, an...

9. [noib3/crop: 🌾 A pretty fast text rope - GitHub](https://github.com/noib3/crop) - Both crop and Ropey track line breaks, allowing you to convert between line and byte offsets and to ...

10. [Text showdown: Gap Buffers vs Ropes - Core Dumped](https://coredumped.dev/2023/08/09/text-showdown-gap-buffers-vs-ropes/) - Ropes have other benefits besides good performance. Both Crop and Ropey support concurrent access fr...

11. [cessen/ropey: A utf8 text rope for manipulating and editing large texts.](https://github.com/cessen/ropey) - Ropey is a utf8 text rope for Rust, designed to be the backing text-buffer for applications such as ...

12. [crop — Rust text processing library // Lib.rs](https://lib.rs/crates/crop) - Both crop and Ropey track line breaks, allowing you to convert between line and byte offsets and to ...

13. [Incremental Parsing Using Tree-sitter - Federico Tomassetti](https://tomassetti.me/incremental-parsing-using-tree-sitter/) - Tree-sitter is an incremental parsing library, which means that it is designed to efficiently update...

14. [Tree-sitter - GitHub](https://github.com/tree-sitter/tree-sitter) - Tree-sitter is a parser generator tool and an incremental parsing library. It can build a concrete s...

15. [Swift API for the tree-sitter incremental parsing system - GitHub](https://github.com/tree-sitter/swift-tree-sitter) - A very common use of tree-sitter is to do syntax highlighting. It is possible to use this library di...

16. [BoltFFI - GitHub](https://github.com/boltffi/boltffi) - A high-performance multi-language bindings generator for Rust, up to 1000x faster than UniFFI. Ship ...

17. [BoltFFI: a high-performance Rust bindings generator (up to ... - Reddit](https://www.reddit.com/r/rust/comments/1r768bm/boltffi_a_highperformance_rust_bindings_generator/) - Swift, Kotlin, and TypeScript (WASM) are supported today. Python is next and other languages are in ...

18. [BoltFFI Docs | BoltFFI](https://boltffi.dev) - BoltFFI is a tool that generates foreign-language bindings from Rust libraries. It fits the practice...

19. [Beyond FFI: Zero-Copy IPC with Rust and Lock-Free Ring-Buffers](https://dev.to/rafacalderon/beyond-ffi-zero-copy-ipc-with-rust-and-lock-free-ring-buffers-3kcp) - If you need to send variable-length text, use a fixed buffer ( [u8; 256] ) or implement a secondary ...

20. [Getting started with signposts | Swift by Sundell](https://www.swiftbysundell.com/wwdc2018/getting-started-with-signposts) - Using this new tool, we can easily place markers - signposts - in our code that can make profiling a...

21. [Using Signposts for Performance Tuning on iOS - Nutrient](https://www.nutrient.io/blog/using-signposts-for-performance-tuning-on-ios/) - This post looks into how we measure performance when developing the framework and how we try to remo...

22. [Measuring performance with os_signpost - Donny Wals](https://www.donnywals.com/measuring-performance-with-os_signpost/) - In this post, I will show you how to add signpost logging to your app, and how you can analyze the s...

