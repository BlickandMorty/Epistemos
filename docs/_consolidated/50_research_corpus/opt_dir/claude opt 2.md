# Deterministic Performance Architectures for Epistemos

**A research report for Jojo (Jordan), solo developer, Epistemos PKM/cognitive augmentation app**
**~137K Swift / ~94K Rust • Swift 6 • UniFFI • Metal • MLX-Swift • GRDB • M2 Pro / 18 GB UMA target**

---

## 0. A Note on Repository Access

The repo at `https://github.com/BlickandMorty/Epistemos` returned a permissions error to my fetcher and was not in any search index I could query. I therefore cannot speak to the *specific* file structure, module boundaries, or in-flight refactors. Every concrete recommendation below is grounded in the architecture you described (Swift 6 + Rust-via-UniFFI, Metal graph at 120 fps, GRDB, MLX-Swift, M2 Pro / 18 GB) and in published reference implementations from Zed, Ghostty, TigerBeetle, the Rust ecosystem, and Apple's own platform documentation. Where I make assumptions about your code, I flag them. **You should treat this report as a peer review of your six-path brainstorm plus a wider survey, not as an audit.**

---

## 1. Executive Summary — The Top Five Wins, Ranked by ROI

If you have only six months and one solo developer, do these five things, in this order. Everything else in this report supports or extends them.

1. **Replace the UniFFI hot path with a `repr(C)` shared-memory ring buffer (SPSC) for high-frequency, fixed-size events; keep UniFFI for cold/control APIs.** UniFFI's published architecture explicitly serializes complex types into a `RustBuffer` (Vec\<u8\>) with an *ad-hoc fixed-width format* and exchanges that bytewise across the FFI on every call ([UniFFI internals](https://mozilla.github.io/uniffi-rs/latest/internals/lifting_and_lowering.html); [issue #244 acknowledges the overhead](https://github.com/mozilla/uniffi-rs/issues/244)). The boltffi project explicitly markets itself as "up to 1,000× faster than UniFFI" by passing primitives raw and structs as pointers ([boltffi README](https://github.com/boltffi/boltffi)). Cloudflare's `mmap-sync` ships this exact pattern in production, using rkyv + a wait-free state file for "extremely fast, low-overhead data sharing between processes" ([cloudflare/mmap-sync](https://github.com/cloudflare/mmap-sync)). The architectural model is Ghostty's: a C-ABI `libghostty` core with Swift/AppKit consuming it ([ghostty.org/docs/about](https://ghostty.org/docs/about)). This is the single largest, most obvious win available to you.

2. **Pre-compile your Metal pipeline state objects offline into a `.metallib` + `MTLBinaryArchive` and ship them in the bundle.** Apple's own WWDC22 session "Target and optimize GPU binaries with Metal 3" describes offline binary generation specifically to eliminate "stutters or frame rate drops, due to runtime compilation… without the memory or CPU cost of pre-warming frames" ([WWDC22 10102](https://developer.apple.com/videos/play/wwdc2022/10102/)). The WWDC20 talk introducing Binary Archives is unambiguous that this avoids "the runtime cost of compiling source code to AIR" ([WWDC20 10615](https://developer.apple.com/videos/play/wwdc2020/10615/)). Your hunch is correct: this *is* a 30–100 ms first-frame win, and on a graph that targets 120 fps with 10K+ nodes it eliminates a hitch class entirely.

3. **Rebuild the entity store as a slotmap with `repr(C)` `u64` keys and structure-of-arrays component columns.** This is the deterministic foundation that makes paths #1 and #5 of your original brainstorm cheap. `slotmap` is the production-quality crate (twice as fast as `generational-arena`, supports secondary-map ECS-style components) ([slotmap discussion](https://github.com/fitzgen/generational-arena/issues/13)). Andrew Kelley's "Practical DoD" talk on the Zig compiler — a directly comparable workload — walks through using *integer handles instead of pointers* and SoA layouts, achieving real measured wins on a real compiler ([Andrew Kelley DoD talk transcript](https://www.josherich.me/podcast/andrew-kelley-practical-data-oriented-design-dod)). This change is the prerequisite for triple-buffered graph rendering, lock-free Swift↔Rust handoff, and O(1) routing — your other paths assume it.

4. **Compile every "registry"-shaped lookup into a `phf` perfect-hash map at build time.** MCP tool registry, file-type → SwiftUI view bindings, edge-type semantics, slash commands, settings keys — these are all read-mostly string-keyed dispatch tables. `rust-phf` generates 100K-entry maps in ~0.4 s of build time and the resulting maps have zero collisions and faster-than-`HashMap` lookup ([rust-phf README](https://github.com/rust-phf/rust-phf)); the conduit-mime-types case study reports the parsing/initialization cost going to "essentially zero" ([Mainmatter writeup](https://mainmatter.com/blog/2022/06/23/the-perfect-hash-function/)). On the Swift side, `quickphf` is even faster (~2× lookup, 10× construction) ([quickphf docs](https://docs.rs/quickphf/latest/quickphf/)). This is the deterministic formalism your own paths 1 and 3 are reaching for.

5. **Tune SQLite/GRDB once, correctly, and don't tune it again.** WAL + `synchronous=NORMAL` + a generous `mmap_size` (256 MB–1 GB on a machine with 18 GB UMA) + `temp_store=MEMORY` + persistent prepared statements is the canonical fast-path read/write configuration ([phiresky's tuning guide](https://phiresky.github.io/blog/2020/sqlite-performance-tuning/); [Stephen Margheim's Rails-on-SQLite series](https://fractaledmind.com/2023/09/07/enhancing-rails-sqlite-fine-tuning/)). On macOS you also want `fullfsync=OFF` (default; APFS is well-behaved) — phiresky's HN follow-up is explicit on this. With `mmap_size` set to the working-set size, SQLite returns BLOBs and rows close to zero-copy via `xFetch()` ([SQLite mmap.html](https://www.sqlite.org/mmap.html)). GRDB exposes all of these via `Configuration` and supports a built-in `publicStatementArguments`-style prepared cache.

These five wins are roughly orthogonal, all measurable, all reversible, and all stay within your existing technology commitments (Swift 6, Rust, Metal, GRDB, MLX). The remainder of this report unpacks each, evaluates your six original paths against them, and casts wider.

---

## 2. Critical Evaluation of Your Six Original Paths

### Path 1 — Artifact Ontology as static UI routing (compile-time SwiftUI view binding)

**Verdict: Right idea, wrong language-level mechanism. Refine.**

A bare `switch` statement over an enum *is* deterministic dispatch and SwiftUI does the right thing with it: an `enum Route` with associated values plus a `@ViewBuilder` resolver gives you compile-time exhaustiveness and zero runtime registry lookup ([Edoardo Briggs, "Building a Type-Safe Routing System for SwiftUI"](https://edoardo.fyi/blog/2025/07/swiftui-routing/)). Alexey Naumov's well-known Clean Architecture for SwiftUI piece makes the deeper point: "the hierarchy is static and all the possible navigations are defined and fixed at compile time" — SwiftUI is *already* a compile-time-routed system, and adding a runtime registry actively fights its grain ([nalexn.github.io](https://nalexn.github.io/clean-architecture-swiftui/)).

What I would push back on: a hand-maintained mega-`switch` is a refactor liability across 137K lines of Swift. The right mechanism for a project your size is a **Swift macro** (Swift 5.9+, attached `MemberMacro` or `PeerMacro`) that takes an `@ArtifactView` annotation on each view and synthesizes the `switch` at compile time. Apple's own `#Preview` macro is the precedent ([WWDC23 "Write Swift macros"](https://developer.apple.com/videos/play/wwdc2023/10166/)); the Swift-Macros community list shows a half-dozen routing/registry macros doing exactly this ([krzysztofzablocki/Swift-Macros](https://github.com/krzysztofzablocki/Swift-Macros)). Build-time codegen, runtime is a single `switch`. This is your path 1, made maintainable.

Concrete pattern (Swift):

```swift
// ArtifactKind is an enum, generated or hand-rolled
enum ArtifactKind: UInt32, CaseIterable, Sendable {
    case rawThought, note, tweet, paper, code, image, audio, derived
}

// Compile-time exhaustive dispatch. No registry, no Any, no AnyView.
@MainActor
@ViewBuilder
func view(for artifact: ArtifactRef) -> some View {
    switch artifact.kind {
    case .rawThought: RawThoughtView(id: artifact.id)
    case .note:       NoteView(id: artifact.id)
    case .tweet:      TweetView(id: artifact.id)
    case .paper:      PaperView(id: artifact.id)
    case .code:       CodeView(id: artifact.id)
    case .image:      ImageView(id: artifact.id)
    case .audio:      AudioView(id: artifact.id)
    case .derived:    DerivedArtifactView(id: artifact.id)
    }
}
```

The `some View` opaque return is critical: SwiftUI's diffing only works efficiently when the return type is statically resolvable. `AnyView` erases this and forces SwiftUI into worst-case re-layout — a documented 120 fps killer on infinite-feed views ([Jacob's Tech Tavern, "SwiftUI Scroll Performance: The 120FPS Challenge"](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps)).

### Path 2 — Graph edges as deterministic pre-fetching

**Verdict: Strong idea, but be honest that "deterministic pre-fetching" is still speculation. Refine.**

Pre-fetching driven by typed edges (`derived_from`, `generated_by`, `cites`) is genuinely different from blind LRU caching: the edge *type* is a strong prior on the next access. This maps to a well-studied technique in CPU architecture literature called *speculative precomputation*, which uses idle compute to "pre-compute future memory accesses… and prefetch these data" ([Speculative Precomputation, ISCA '01](https://dl.acm.org/doi/abs/10.1145/384285.379248)).

Push-back, in two parts:

- **Call it speculation, not determinism.** Determinism in TigerBeetle's sense means *given the same input, the same physical path* ([TigerBeetle ARCHITECTURE.md](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/ARCHITECTURE.md)). Your typed-edge prefetching is closer to a *predictable* heuristic. The win is real, but the model is "the user is likely to request a 1-hop neighborhood; pre-warm it." You should budget the speculation: cap pre-fetch to ≤2 hops, ≤N nodes, ≤K MB, and *measure* the hit rate. Jim Nielsen's piece on speculative pre-fetching is a useful sanity check on the failure modes ([blog.jim-nielsen.com](https://blog.jim-nielsen.com/2021/speculative-prefetching/)).

- **The right mechanism is a tiered cache, not a query.** Pre-fetched neighborhoods belong in a small in-process arena (a `bumpalo::Bump` reset on selection change) holding rkyv-archived nodes. The SQLite mmap'd page cache is your second tier; the OS page cache is the third. Treat each tier deterministically: a fixed budget, a fixed eviction policy, and an os_signpost interval around `cache_miss` so you can see when the speculation is paying.

### Path 3 — Local MCP tool registry as compile-time static structs

**Verdict: Correct. This is the highest-leverage application of `phf`/`quickphf` in the codebase.**

MCP tool schemas are read-only, finite, and known at build time. JSON-parsing them at startup is pure waste. `phf_codegen` in a `build.rs` is the canonical path:

```rust
// build.rs
fn main() {
    let mut tools = phf_codegen::Map::<&'static str>::new();
    // Walk a tools/ directory of .toml schema files at build time
    for tool in ToolSchema::load_all("tools/") {
        tools.entry(tool.name, &format!("&Tool {{ \
            name: \"{name}\", \
            schema: &SCHEMA_{idx}, \
            handler: handlers::{handler}, \
        }}", name = tool.name, idx = tool.idx, handler = tool.handler));
    }
    writeln!(out, "static TOOLS: phf::Map<&'static str, &'static Tool> = {};",
             tools.build()).unwrap();
}
```

At runtime, `TOOLS.get(name)` is two memory loads and a comparison. The Mainmatter case study reports going from "JSON parse on startup" to "essentially zero" startup cost via this exact pattern ([mainmatter.com](https://mainmatter.com/blog/2022/06/23/the-perfect-hash-function/)). `quickphf` is the higher-performance variant if you measure `phf` lookup as a bottleneck (it's ~2× faster on lookup and uses PTHash) ([docs.rs/quickphf](https://docs.rs/quickphf/latest/quickphf/)).

The schema validation should be done against a static `&'static SchemaNode` tree (also build.rs-emitted) — never against a parsed JSON Schema at runtime.

### Path 4 — Rust-Swift FFI as zero-copy shared memory

**Verdict: This is the single largest possible win. Do it. But scope it carefully — this is also where your project gets messy.**

Your instinct is right and the published evidence supports it strongly. Three independent data points:

1. **UniFFI's wire format is documented as serialization-by-default.** Complex types are written to a byte buffer (`RustBuffer`) on each call ([Lifting and Lowering](https://mozilla.github.io/uniffi-rs/latest/internals/lifting_and_lowering.html)). A maintainer-acknowledged issue from years ago lists "serialization across the boundary," `ConcurrentHandleMap` locking, and `Vec<T>` round-trips as the unnecessary overhead sources ([uniffi-rs#244](https://github.com/mozilla/uniffi-rs/issues/244)).

2. **boltffi's benchmarks claim "up to 1,000× faster than UniFFI"** by passing primitives as raw values and `#[data]`-marked structs as pointers ([boltffi/boltffi](https://github.com/boltffi/boltffi)). 1,000× is a marketing number; even at 10–50× it's enormous.

3. **Apple Silicon's Unified Memory Architecture is the perfect substrate.** A pointer the CPU writes is the same physical memory the GPU reads via `MTLDevice.makeBuffer(bytesNoCopy:length:)`. The Driftwood writeup verified pointer identity (`mmap` ptr == `MTLBuffer.contents()` ptr) and a 0.03 MB RSS delta on a 16 MB region versus 16.78 MB for the copy path ([abacusnoir.com](https://abacusnoir.com/2026/04/18/zero-copy-gpu-inference-from-webassembly-on-apple-silicon/)). Apple's own `MTLStorageMode.shared` documentation confirms "the CPU and GPU share access to the resource, allocated in system memory" ([developer.apple.com](https://developer.apple.com/documentation/metal/mtlstoragemode/shared)).

**Format comparison, with what I actually believe.** Kolinski's well-known benchmarks (the rkyv author's, so read with appropriate skepticism) show rkyv winning across access, read, and deserialize against FlatBuffers, Cap'n Proto, bincode, prost, postcard, and serde_json, with one important caveat: FlatBuffers had "very poor serialization performance on highly-structured data" and Cap'n Proto "failed pretty miserably on the mesh size benchmarks" ([david.kolo.ski/blog/rkyv-is-faster-than/](https://david.kolo.ski/blog/rkyv-is-faster-than/)). The Hacker News response correctly notes rkyv lacks schema evolution by default — important if you intend to persist these messages, irrelevant if they're transient FFI messages ([HN discussion](https://news.ycombinator.com/item?id=26428812)).

For Epistemos, **the right answer is layered**:

| Boundary | Format | Why |
|---|---|---|
| Hot, fixed-size events (logs, cursor updates, edit deltas, MCP results) | `repr(C)` POD struct in an SPSC ring buffer | Zero serialization, zero allocation. Rafael Calderon's "Beyond FFI" piece is the canonical Rust + Apple-Silicon-aware pattern ([dev.to](https://dev.to/rafacalderon/beyond-ffi-zero-copy-ipc-with-rust-and-lock-free-ring-buffers-3kcp)). |
| Variable-size, in-process, control-flow (graph snapshot for render) | rkyv archive in shared memory | True zero-copy reads on the Swift side via a small C shim. Cloudflare ships this in `mmap-sync` ([github.com/cloudflare/mmap-sync](https://github.com/cloudflare/mmap-sync)). |
| GPU buffers (positions, edges, uniforms) | `MTLBuffer` with `.storageModeShared`, written from Rust through `bytesNoCopy` | UMA gives this for free. This is your Metal triple-buffer. |
| Cold, infrequent, schema-evolving control APIs (settings, commands) | Keep UniFFI | The 137K-line Swift codebase is already paying this overhead at "user types" cadence. The pain isn't here. |
| Cross-process (if you ever add an XPC service for indexing) | IOSurface for textures, mach-port-wrapped memory objects for data | Apple's documented zero-copy IPC surfaces. Russ Bishop's writeup is canonical ([russbishop.net](http://www.russbishop.net/cross-process-rendering)). |

The repr(C) ring-buffer pattern looks like this (the key is cache-line padding to avoid false sharing):

```rust
// crate: substrate-core
use std::sync::atomic::{AtomicU64, Ordering};
use std::cell::UnsafeCell;
use std::mem::MaybeUninit;

const CACHE_LINE: usize = 128; // M-series prefetches in 128-byte pairs
const RING_SIZE: usize = 1 << 14; // 16384 slots, must be power of two

// SAFETY: must be POD. No String, no Vec, no Box.
#[repr(C)]
#[derive(Copy, Clone)]
pub struct GraphEvent {
    pub kind:      u32,             // discriminant
    pub _pad0:     u32,
    pub entity:    u64,             // slotmap key (gen << 32 | idx)
    pub edge:      u64,
    pub timestamp: u64,
    pub payload:   [u8; 32],        // inline payload
}
const _: () = assert!(std::mem::size_of::<GraphEvent>() == 64);

#[repr(C, align(128))]
pub struct EventRing {
    _pad0: [u8; CACHE_LINE],
    head:  AtomicU64, // producer (Rust) writes; consumer (Swift) reads
    _pad1: [u8; CACHE_LINE - std::mem::size_of::<AtomicU64>()],
    tail:  AtomicU64, // consumer writes; producer reads
    _pad2: [u8; CACHE_LINE - std::mem::size_of::<AtomicU64>()],
    slots: [UnsafeCell<MaybeUninit<GraphEvent>>; RING_SIZE],
}

#[no_mangle]
pub unsafe extern "C" fn epi_ring_new() -> *mut EventRing { /* mmap-anon, zero-init, return */ unimplemented!() }
#[no_mangle]
pub unsafe extern "C" fn epi_ring_push(r: *mut EventRing, ev: *const GraphEvent) -> bool { /* CAS head, copy 64 bytes */ unimplemented!() }
#[no_mangle]
pub unsafe extern "C" fn epi_ring_pop(r: *mut EventRing, out: *mut GraphEvent) -> bool { /* read tail, copy 64 bytes, advance */ unimplemented!() }
```

On the Swift side you import this as a C struct (via the existing UniFFI-emitted module-map or a small hand-written `module.modulemap`):

```swift
import EpistemosCore // your existing module wrapping libsubstrate

@inline(__always)
func drainEvents(_ ring: UnsafeMutablePointer<EventRing>, into sink: inout EventSink) {
    var ev = GraphEvent()
    while withUnsafeMutablePointer(to: &ev, { epi_ring_pop(ring, $0) }) {
        sink.consume(ev)   // dispatch on ev.kind via a phf-style switch
    }
}
```

The published reference implementations are `rtrb` ("a wait-free single-producer single-consumer ring buffer for Rust," whose code originated in a never-merged crossbeam PR — [github.com/mgeier/rtrb](https://github.com/mgeier/rtrb)) and `ringbuf` (lock-free, supports non-`Copy` items via direct slot access — [github.com/agerasev/ringbuf](https://github.com/agerasev/ringbuf)). For Epistemos's hot path I'd hand-roll the buffer (it's ~150 lines) so you control layout exactly; for everything else, depend on `rtrb`.

**Tradeoff honesty.** Replacing UniFFI on the hot path costs you: (a) the `unsafe` audit surface grows, (b) you lose Mozilla's mature error-mapping and panic-catch wrapper, (c) you must hand-write the C ABI side. The mitigation is the layered approach above: keep UniFFI for the 95% of API surface that runs at human cadence, and only carve out a small `substrate-rt` crate that exposes the ring + a few `repr(C)` views.

### Path 5 — Tree-Sitter AST byte-offset caching for synchronous scroll rendering

**Verdict: Yes, but you're describing the standard tree-sitter design. Use the design fully.**

Tree-sitter is *already* an incremental parser whose API is byte-offset–native: `tree.edit(start_byte, old_end_byte, new_end_byte, …)` then `parser.parse(text, &old_tree)` reuses unchanged subtrees ([tree-sitter docs](https://github.com/tree-sitter/tree-sitter)). Helix's switch to its own `tree-house` crate plus their own incremental highlighter is instructive: their 25.07 release notes explicitly diagnose the *original* `tree-sitter-highlight` crate as not incremental enough ("Creating a new highlight iterator means fully re-parsing the document as well as re-analyzing the queries") and explain why they wrote their own ([Helix 25.07 notes](https://helix-editor.com/news/release-25-07-highlights/)).

Concrete moves:

1. **Cache the parsed `Tree` per buffer in Rust, never on the Swift side.** Swift sees only byte ranges and style indices.
2. **Pre-compute a flat `Vec<HighlightSpan>` (struct-of-arrays: parallel `Vec<u32>` for start, end, style) on every parse, sorted by start_byte.** Scroll rendering becomes `binary_search_by(viewport_start)` then a linear walk. This is the byte-offset cache you want.
3. **Push the spans across the FFI as a slice of `repr(C)` structs (the ring is overkill here; a `&[HighlightSpan]` exposed via a C function is enough).** No serialization, no allocation per frame.
4. **Use `TreeCursor::goto_first_child_for_byte(viewport_start)` to drill into the tree only when you need semantic information beyond highlights** (e.g., for "fold this section"). The cursor API is byte-aware ([CRAN treesitter help](https://cran.r-project.org/web/packages/treesitter/refman/treesitter.html)).

### Path 6 — Raw Thoughts fast-path: direct Rust→file streams, tail-read UI bypass

**Verdict: Right shape. Use mmap'd append-only with a fixed-size record header. This is also TigerBeetle-shaped.**

The core mechanism: a single mmap'd file with `MAP_SHARED`, fixed-size 128- or 256-byte record headers (timestamp, length, kind, hash), and an in-Rust `AtomicU64` write-cursor. Writers `memcpy` into the next slot and bump the cursor with release semantics. The UI tails by reading from a saved cursor with acquire semantics. No syscalls per write (pages flush via the OS at its pace), no SQLite involvement, no UI-thread serialization.

This is the same shape as TigerBeetle's WAL: an mmap'd region where "every operation is durably stored… in at least a quorum of replicas' Write-Ahead Logs (WAL)" ([tigerbeetle.com/concepts/safety](https://docs.tigerbeetle.com/concepts/safety/)). For Epistemos you don't need quorum, but you do want the discipline: hash each record (xxhash3 is fine), keep a periodic snapshot/checkpoint, and *never* delete from the live file.

`memmap2` is the go-to crate ([docs.rs/memmap2](https://docs.rs/memmap2/latest/memmap2/struct.Mmap.html)). For the wait-free version with reader/writer separation, Cloudflare's `mmap-sync` is a directly applicable production reference ([github.com/cloudflare/mmap-sync](https://github.com/cloudflare/mmap-sync)).

The UI side reads via a mmap'd view of the *same file* — no IPC, no FFI call per record, just memory:

```swift
// Swift, conceptually:
let fd = open(rawThoughtsPath, O_RDONLY)
let mapped = mmap(nil, size, PROT_READ, MAP_SHARED, fd, 0)!
// Snapshot the writer's cursor (one atomic read across FFI):
let head = epi_raw_thoughts_head()
// Walk records from saved tail to head with binary layout, build view models.
```

One subtle thing: on macOS, durability of `mmap` writes is tied to `msync()` or process exit. For "write at the speed of thought, never lose a thought" you want a periodic background `msync(MS_ASYNC)` every ~1 s, plus on-app-resign-active `msync(MS_SYNC)`. SQLite's behavior under WAL is the model here ([sqlite.org/mmap.html](https://www.sqlite.org/mmap.html)).

---

## 3. New Deterministic Paths You Did Not List

These are the wins outside your six. I rank them by leverage for Epistemos specifically.

### 3.1 Pre-compiled Metal pipelines (`.metallib` + `MTLBinaryArchive`)

Already discussed in §1 #2. The mechanics:

```bash
# Offline compilation — run once at build time, ship the result in your bundle
xcrun -sdk macosx metal -O3 -ffast-math GraphShaders.metal -o GraphShaders.air
xcrun -sdk macosx metallib GraphShaders.air -o GraphShaders.metallib

# Generate a Metal pipelines script (JSON) describing every PSO you actually use,
# then bake binary archive offline:
xcrun -sdk macosx metal-tt --pipelines pipelines.mtlp --output GraphShaders.metalbinary
```

At runtime:

```swift
let url = Bundle.main.url(forResource: "GraphShaders", withExtension: "metalbinary")!
let archive = try device.makeBinaryArchive(descriptor: {
    let d = MTLBinaryArchiveDescriptor()
    d.url = url
    return d
}())

let pipeDesc = MTLRenderPipelineDescriptor()
pipeDesc.binaryArchives = [archive]
// PSO creation now hits the archive, not the compiler.
let pso = try device.makeRenderPipelineState(descriptor: pipeDesc, options: [])
```

This is documented Apple guidance ([WWDC22 10102](https://developer.apple.com/videos/play/wwdc2022/10102/), [MTLBinaryArchive reference](https://developer.apple.com/documentation/metal/mtlbinaryarchive)). For a 10K-node graph with multiple shader variants, you eliminate the entire Pipeline State Object compilation phase from the hot path.

### 3.2 Argument buffers + bindless rendering for the graph

Argument buffers (Tier 2, available on Apple GPU family 6+ which includes M1/M2) let you bind a single buffer that references all your scene resources ([WWDC21 "Explore bindless rendering in Metal"](https://developer.apple.com/videos/play/wwdc2021/10286/)). For a graph view with 10K nodes, the traditional binding model would have 10K+ draw calls each binding their own resources. With argument buffers, one buffer holds an array of `NodeData { color, glyph_atlas_idx, position, … }` and one draw call indexes into it. Apple's WWDC22 update made writing argument buffers in Metal 3 dramatically simpler (no separate encoder object) ([WWDC22 10101](https://developer.apple.com/videos/play/wwdc2022/10101/)).

GPU-driven force-directed layout is the next step — research like the GraphWaGu paper shows full Fruchterman-Reingold on the GPU at interactive rates ([GraphWaGu, 2022](https://stevepetruzza.io/pubs/graphwagu-2022.pdf)). For 10K nodes on an M2 Pro, this is well within reach using `MTLComputeCommandEncoder` and a Barnes-Hut quadtree built on-device. This is a Phase II win, not a Phase I one.

### 3.3 Profile-Guided Optimization (PGO) for the Rust crate

`cargo-pgo` (by Jakub Beránek, who did the rustc PGO work) wraps the LLVM PGO flow in a single-command UX ([github.com/Kobzol/cargo-pgo](https://github.com/Kobzol/cargo-pgo)):

```bash
cargo install cargo-pgo
cargo pgo build                    # instrumented build
./target/.../substrate-bench       # run a representative workload (e.g. open
                                   # 1000 artifacts, scroll the graph 60s,
                                   # run an MCP tool 100x)
cargo pgo optimize build           # final, profile-optimized build
```

Real Rust binaries see **10%+ wall-clock improvements** in the published cases ([Rust Performance Book on PGO](https://nnethercote.github.io/perf-book/build-configuration.html)). The trick is having a representative workload — for Epistemos, the right workload is "your typical morning session." Record it once with os_signpost, replay it as a benchmark, train PGO on it. BOLT (post-link optimizer) stacks on top of PGO for another few percent on instruction-cache-bound code; `cargo pgo bolt` automates it but BOLT itself is fragile on macOS today (see §6 caveat).

### 3.4 Link-Time Optimization (LTO) + abort-on-panic + symbol stripping

Cheap, deterministic, and you should already have these in your release profile:

```toml
# Cargo.toml
[profile.release]
lto = "fat"           # whole-program inlining across crates
codegen-units = 1     # required for LTO to actually work
panic = "abort"       # smaller binary, no unwind tables
strip = "symbols"     # smaller binary, faster load
opt-level = 3
debug = false
```

The boehs.org tutorial walks through this and reports a 31 MB → 7.1 MB binary reduction for a sample UniFFI library ([boehs.org/node/uniffi](https://boehs.org/node/uniffi)). Smaller binary = faster page-in = faster cold start.

### 3.5 Bumpalo arena per render frame / per request

For per-frame (rendering) and per-MCP-call (tool execution) workloads, a `bumpalo::Bump` arena that's reset rather than freed cuts allocation cost to ~11 instructions per allocation ([fitzgen/bumpalo](https://github.com/fitzgen/bumpalo); [Vorner's "If you want performance, cheat!"](https://vorner.github.io/2020/09/03/performance-cheating.html)). The DeepWiki for bumpalo notes that `Vec::extend_from_slice_copy` is "~80× faster than standard extend for Copy types via single memcpy" — directly applicable to your highlight-span and edge-fetch hot paths ([deepwiki.com/fitzgen/bumpalo](https://deepwiki.com/fitzgen/bumpalo)).

```rust
// Per-frame arena, reset every frame, never freed
pub struct FrameCtx {
    arena: bumpalo::Bump,
}
impl FrameCtx {
    pub fn new() -> Self { Self { arena: Bump::with_capacity(16 * 1024 * 1024) } }
    pub fn begin_frame(&mut self) { self.arena.reset(); } // O(1)
    pub fn alloc_spans(&self, count: usize) -> &mut [HighlightSpan] {
        self.arena.alloc_slice_fill_default(count)
    }
}
```

### 3.6 Slotmap entity store + structure-of-arrays components

This is the foundation that makes paths 1, 4, and 5 of your brainstorm cheap, and it earned its own #3 in §1. The slotmap discussion thread explains why slotmap beats `generational-arena`: it stores the generation tag in a single LSB of the slot descriptor instead of in a separate enum variant, giving a more compact and cache-friendly layout ([fitzgen/generational-arena#13](https://github.com/fitzgen/generational-arena/issues/13)). For an Epistemos-shaped graph, you want:

```rust
slotmap::new_key_type! { pub struct ArtifactKey; }   // u64-sized; safe to expose as repr(C) u64

pub struct Substrate {
    // The store; gives you O(1) insert/remove/get with stale-handle detection
    artifacts: SlotMap<ArtifactKey, ArtifactCore>,

    // SoA component columns (Andrew Kelley DoD style)
    kinds:       SecondaryMap<ArtifactKey, ArtifactKind>,
    titles:      SecondaryMap<ArtifactKey, SmolStr>,
    embeddings:  SecondaryMap<ArtifactKey, Box<[f32; 768]>>,
    // Edges live in their own slotmap with typed adjacency
    edges:       SlotMap<EdgeKey, Edge>,
    out_edges:   SecondaryMap<ArtifactKey, SmallVec<[EdgeKey; 8]>>,
}
```

The SoA layout pays off whenever you iterate "all titles" or "all embeddings" — iterating embeddings as a contiguous `&[Box<[f32; 768]>]` saturates the memory bus the way an Array-of-Structures cannot. This is Mike Acton's CppCon 2014 thesis ("if you don't understand the data, you don't understand the problem" — [isocpp.org](https://isocpp.org/blog/2015/01/cppcon-2014-data-oriented-design-and-c-mike-acton)) and Andrew Kelley's whole DoD talk applied to a knowledge graph instead of a compiler ([transcript](https://www.josherich.me/podcast/andrew-kelley-practical-data-oriented-design-dod)).

Across the FFI, the key is exposed as a single `u64`:

```rust
#[repr(C)]
#[derive(Copy, Clone)]
pub struct EpiArtifactRef(pub u64); // generation in upper 32, idx in lower 32

#[no_mangle]
pub extern "C" fn epi_artifact_kind(r: EpiArtifactRef) -> u32 {
    let key = ArtifactKey::from_raw(r.0);
    SUBSTRATE.read().kinds.get(key).copied().unwrap_or(ArtifactKind::Unknown) as u32
}
```

Stale references are detected by the generation mismatch; you get use-after-free safety across the FFI without `Arc` indirection.

### 3.7 GRDB / SQLite tuning (concrete pragmas)

Apply these once on every connection (GRDB exposes them via `Configuration.prepareDatabase`):

```swift
var config = Configuration()
config.prepareDatabase { db in
    try db.execute(sql: """
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;
        PRAGMA temp_store = MEMORY;
        PRAGMA mmap_size = 1073741824;        -- 1 GB on a 18 GB machine
        PRAGMA cache_size = -65536;            -- 64 MB page cache (negative = KB)
        PRAGMA page_size = 4096;               -- match APFS block; set BEFORE first write
        PRAGMA foreign_keys = ON;
        PRAGMA wal_autocheckpoint = 1000;
        PRAGMA optimize;                       -- run on close, also periodically
    """)
}
let pool = try DatabasePool(path: dbPath, configuration: config)
```

The reasoning for each value is well-documented: WAL + NORMAL avoids `fsync` per write while remaining corruption-safe in WAL mode ([sqlite.org/pragma.html](https://www.sqlite.org/pragma.html)); `temp_store = MEMORY` keeps temp B-trees off disk; `mmap_size` enables near-zero-copy reads via `xFetch()` ([sqlite.org/mmap.html](https://www.sqlite.org/mmap.html)); a 1 GB mmap on a 18 GB machine is well within proportion ([phiresky's tuning piece is the canonical reference](https://phiresky.github.io/blog/2020/sqlite-performance-tuning/)). Stephen Margheim's Rails-on-SQLite series adds the operational nuance: 64 MB page cache is a sensible default ([fractaledmind.com](https://fractaledmind.com/2023/09/07/enhancing-rails-sqlite-fine-tuning/)).

GRDB's own performance benchmarks (latest version compared to FMDB, SQLite.swift, Core Data, Realm) are public; on the M-series MBP it generally lies between SwiftData and raw SQLite C API, which is the right place ([github.com/groue/GRDB.swift/wiki/Performance](https://github.com/groue/GRDB.swift/wiki/Performance)). One reported case showed Core Data actually beating GRDB on a "BEGINSWITH 7-prefix" query — so, when in doubt, *measure* before swapping ([GRDB issue #981](https://github.com/groue/GRDB.swift/issues/981)).

**Prepared statement caching.** GRDB does not cache `sqlite3_stmt` across distinct SQL strings by default; you should `cachedStatement(sql:)` for any query in a hot path. The C-level `SQLITE_PREPARE_PERSISTENT` flag (sqlite3_prepare_v3) tells SQLite the statement is long-lived ([sqlite forum thread](https://sqlite.org/forum/forumpost/a422f1ccc4407513)) — useful when you go below GRDB to its `Database.makeStatement(sql:)` for the truly hot statements.

### 3.8 macOS event loop: kqueue + dispatch sources, not io_uring

io_uring does not exist on macOS. The native equivalent is **kqueue**, optionally wrapped by **Grand Central Dispatch's `DispatchSource`/`dispatch_io_t`**. Mitchell Hashimoto's `libxev` (used by Ghostty) is the cleanest published abstraction over both, exposing a proactor API on top of io_uring on Linux and kqueue on macOS, with **zero runtime allocations** ([github.com/mitchellh/libxev](https://github.com/mitchellh/libxev)). TigerBeetle's "friendly abstraction over io_uring and kqueue" piece is the canonical design discussion ([tigerbeetle.com/blog/...](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/)).

For Epistemos's needs, you almost certainly do not need to write your own kqueue layer. `tokio` on macOS uses kqueue under `mio`; for *file* I/O you should rely on `dispatch_io_t` (Apple's own async file I/O, used by every native macOS tool) which is wrapped by Foundation's `FileHandle`/`DispatchIO` and has proper zero-copy `dispatch_data_t` semantics. For *raw thoughts* path 6, `dispatch_data_t` is the Swift-side companion to your mmap'd writer.

### 3.9 Lock-free structures from `crossbeam` and friends

You said you're already familiar; the concrete crate selections that matter:

- `crossbeam-epoch` for any pointer-based concurrent structure (you have this).
- `crossbeam::queue::ArrayQueue` for bounded MPMC where you need it.
- `rtrb` / `ringbuf` for SPSC.
- `arc-swap` for hot-swappable read-mostly shared state (e.g., the published graph snapshot).
- `parking_lot::RwLock` instead of `std::sync::RwLock` (consistently faster on macOS).
- `dashmap` *only* if you must — perfect-hash + `arc-swap` is usually better.

### 3.10 os_signpost from day one

This is your measurement substrate. Build it in *now*. Apple's WWDC18 session is the foundation ([WWDC18 405](https://developer.apple.com/videos/play/wwdc2018/405/)); the modern API is `OSSignposter` (iOS 15+, macOS 12+):

```swift
import os.signpost

enum Sig {
    static let render = OSSignposter(subsystem: "io.epistemos.core", category: "render")
    static let mcp    = OSSignposter(subsystem: "io.epistemos.core", category: "mcp")
    static let graph  = OSSignposter(subsystem: "io.epistemos.core", category: "graph")
    static let ffi    = OSSignposter(subsystem: "io.epistemos.core", category: "ffi")
}

@inline(__always)
func renderFrame(_ scene: Scene) {
    let id = Sig.render.makeSignpostID()
    let state = Sig.render.beginInterval("frame", id: id, "nodes=\(scene.nodes.count)")
    defer { Sig.render.endInterval("frame", state) }
    // ...
}
```

In Rust, expose a tiny shim that calls `os_signpost_emit_with_name_and_type` via a `dlopen`'d `libsystem_trace.dylib` reference, or simpler: have Rust write to your event ring with a kind tag, and emit signposts on the Swift side at consumption time. The MEGA team's writeup is a useful end-to-end walkthrough including the custom Instruments `.instrpkg` ([medium.com/@mega-blog](https://medium.com/@mega-blog/profiling-performance-by-os-signpost-and-customized-instruments-package-in-mega-ios-0e123f126b0e)). The point: every optimization in this report needs a signpost, and *no optimization should ship without a regression test that checks its signpost interval*.

### 3.11 Tagged pointers / NaN-boxing — *probably skip*

These show up in dynamically-typed VMs (V8, JavaScriptCore, Lua) where you want `Value` to fit in 8 bytes regardless of whether it's a float, int, ptr, or bool. Bun gets a chunk of its perf from inheriting JavaScriptCore's NaN-boxing ([github.com/oven-sh/bun discussion #994](https://github.com/oven-sh/bun/discussions/994)). For Epistemos, your value graph is *statically typed Rust enums* — the niche optimizations the Rust compiler already does (`Option<&T>` is one pointer, `Result<u64, ()>` is one register) cover essentially all the same ground without the unsafety. There's a published `boxing` crate for when you really need it ([docs.rs/boxing](https://docs.rs/boxing)), but I would bet against you needing it.

### 3.12 Compile-time SQL — *yes, via macros*

The `sqlx` crate is the wrong fit (designed for Postgres/MySQL with live database connectivity at compile time), but the *idea* is right: validate SQL and bind types at compile time. The pragmatic approach for Epistemos is:

1. Keep all SQL in `.sql` files in a `queries/` directory.
2. A `build.rs` step parses each file with `sqlite3_prepare_v2` against a schema-only DB (`PRAGMA schema_version = X; CREATE TABLE …`) and fails the build if any query is invalid.
3. Generate a Rust function per query with the right argument and return types.

This is what the Pointfree.co `SQLiteData` library does on the Swift side ([pointfree.co](https://www.pointfree.co/blog/posts/168-sharinggrdb-a-swiftdata-alternative)), and the same pattern transposes to Rust trivially. End result: a syntactically invalid query is a build error, not a runtime panic.

### 3.13 Bloom filters for negative lookups

For "does this artifact exist?", "is this URL already cited?", "have we already embedded this string?", a Bloom filter in front of SQLite saves the round-trip on the negative case. `bloomfilter`, `growable-bloom`, or `cuckoofilter` (better for delete) are the production crates. Sized for 10M items at 1% FPR, a Bloom filter is ~12 MB — fits easily in your 18 GB.

### 3.14 Deterministic frame budget enforcement

The 120 fps target on ProMotion is **8.33 ms per frame, of which you realistically get 5 ms** for app work after compositor/system overhead ([Jacob's Tech Tavern, "120FPS Challenge"](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps)). Concretely:

- Use `CADisplayLink` or `MTKView`'s `preferredFramesPerSecond = 120` and `CAMetalDisplayLink` (macOS 14+) to align rendering with vsync.
- Keep a `FrameBudget` struct that tracks "ms used so far this frame" via a deadline `mach_absolute_time()` reading. If a deferred task would push you past 4 ms, defer it to the *next* frame.
- Triple-buffer your uniforms exactly as Apple's "Choosing a resource storage mode for Apple GPUs" docs prescribe ([developer.apple.com](https://developer.apple.com/documentation/metal/choosing-a-resource-storage-mode-for-apple-gpus)). With UMA and `.storageModeShared`, this is just three regions in the same `MTLBuffer` and a frame-index modulo.

### 3.15 Things I considered and decided **not** to recommend

- **NUMA-aware allocation.** Apple Silicon UMA is single-domain. Not applicable.
- **`io_uring`.** Doesn't exist on macOS. Use kqueue/dispatch.
- **SIMD by hand.** The Rust compiler vectorizes well; explicit `std::simd` only earns you anything in measured hot loops (your 768-d embedding similarity might qualify; nothing else likely does).
- **Custom allocator (jemalloc/mimalloc).** macOS's native allocator is competitive on M-series and `mimalloc` regresses on some Apple workloads. Measure before swapping.
- **GPU-driven rendering / Work Graphs.** Work Graphs are D3D12 only ([Microsoft DirectX-Specs](https://microsoft.github.io/DirectX-Specs/d3d/WorkGraphs.html)); Metal's nearest equivalent is indirect command buffers, which are useful but a Phase II item for you.
- **BOLT on macOS.** Possible via Docker/Linux cross-build for the Rust dylib, but the macOS-native BOLT story is rough as of late 2025/early 2026. Defer.

---

## 4. Production-Ready Code Patterns

Pulled together from §2 and §3, here are the specific code patterns to drop into Phase I.

### 4.1 The substrate-core C ABI surface (minimal viable)

```rust
// crates/substrate-core/src/abi.rs
use std::sync::OnceLock;
use parking_lot::RwLock;

static SUBSTRATE: OnceLock<RwLock<Substrate>> = OnceLock::new();

#[repr(C)]
pub struct EpiResult { pub code: i32, pub data: u64 }

#[no_mangle]
pub unsafe extern "C" fn epi_init(db_path: *const std::ffi::c_char) -> i32 {
    let path = std::ffi::CStr::from_ptr(db_path).to_str().unwrap();
    match Substrate::open(path) {
        Ok(s) => { SUBSTRATE.set(RwLock::new(s)).ok(); 0 }
        Err(_) => -1,
    }
}

#[no_mangle]
pub unsafe extern "C" fn epi_artifact_get(key: u64, out: *mut EpiArtifactView) -> i32 {
    let key = ArtifactKey::from_raw(key);
    let g = SUBSTRATE.get().unwrap().read();
    match g.view(key) {
        Some(v) => { *out = v.into_repr_c(); 0 }
        None    => -2,
    }
}

#[no_mangle]
pub unsafe extern "C" fn epi_event_ring(out: *mut *mut EventRing) {
    *out = SUBSTRATE.get().unwrap().read().event_ring_ptr();
}
```

Swift consumes this through a single `module.modulemap` you check into the repo:

```
// Sources/EpistemosCore/module.modulemap
module EpistemosCore {
    header "substrate.h"
    export *
}
```

This is exactly the Ghostty pattern: `libghostty` is "a cross-platform, C-ABI compatible library" that the Swift app links against and consumes via standard C interop ([ghostty.org/docs/about](https://ghostty.org/docs/about)). You keep UniFFI for the rest of the API.

### 4.2 phf-backed view dispatch (build.rs side)

```rust
// substrate-core/build.rs
use std::{env, fs::File, io::{BufWriter, Write}, path::Path};

fn main() {
    let out = Path::new(&env::var("OUT_DIR").unwrap()).join("dispatch.rs");
    let mut f = BufWriter::new(File::create(&out).unwrap());

    let mut tools = phf_codegen::Map::<&'static str>::new();
    for tool in load_tools_from("tools/") {
        tools.entry(tool.name,
            &format!("&Tool {{ name: \"{}\", schema: &SCHEMA_{}, handler: handlers::{} }}",
                     tool.name, tool.idx, tool.handler_fn));
    }
    writeln!(f, "static TOOLS: phf::Map<&'static str, &'static Tool> = {};",
             tools.build()).unwrap();

    let mut edge_kinds = phf_codegen::Map::<&'static str>::new();
    for ek in &["derived_from", "generated_by", "cites", "annotates", "contradicts"] {
        edge_kinds.entry(ek, &format!("EdgeKind::{}", camel_case(ek)));
    }
    writeln!(f, "pub static EDGE_KINDS: phf::Map<&'static str, EdgeKind> = {};",
             edge_kinds.build()).unwrap();
}
```

### 4.3 Triple-buffered Metal uniform pool on UMA

```swift
final class TripleUniforms<T> {
    private let buffer: MTLBuffer
    private let semaphore = DispatchSemaphore(value: 3)
    private var index = 0
    private let stride: Int

    init(device: MTLDevice) {
        stride = (MemoryLayout<T>.stride + 255) & ~255  // 256-byte align for Metal
        buffer = device.makeBuffer(length: stride * 3,
                                   options: .storageModeShared)!  // UMA: zero-copy
    }
    func write(_ value: T, completion: MTLCommandBuffer) -> (MTLBuffer, Int) {
        semaphore.wait()
        let off = index * stride
        buffer.contents().advanced(by: off)
              .assumingMemoryBound(to: T.self).pointee = value
        completion.addCompletedHandler { [sem = semaphore] _ in sem.signal() }
        index = (index + 1) % 3
        return (buffer, off)
    }
}
```

### 4.4 mmap'd raw-thought log on the Rust side

```rust
use memmap2::{MmapMut, MmapOptions};
use std::fs::OpenOptions;
use std::sync::atomic::{AtomicU64, Ordering};

#[repr(C)]
pub struct RawThought {
    pub timestamp_ns: u64,
    pub kind:         u32,
    pub len:          u32,
    pub xxh3:         u64,
    pub bytes:        [u8; 232],   // 256 - 24 header
}
const _: () = assert!(std::mem::size_of::<RawThought>() == 256);

pub struct RawLog {
    map:  MmapMut,
    head: &'static AtomicU64,    // backed by the first 8 bytes of `map`
}
impl RawLog {
    pub fn open(path: &std::path::Path, size_mb: usize) -> std::io::Result<Self> {
        let f = OpenOptions::new().read(true).write(true).create(true).open(path)?;
        f.set_len((size_mb * 1024 * 1024) as u64)?;
        let map = unsafe { MmapOptions::new().map_mut(&f)? };
        // SAFETY: we keep `map` alive for the program's lifetime
        let head: &AtomicU64 = unsafe {
            &*(map.as_ptr().cast::<AtomicU64>())
        };
        Ok(Self { map, head: unsafe { std::mem::transmute(head) } })
    }
    pub fn append(&self, t: &RawThought) {
        let off = self.head.fetch_add(256, Ordering::AcqRel) as usize + 8;
        unsafe {
            let dst = self.map.as_ptr().add(off) as *mut RawThought;
            std::ptr::write(dst, *t);
        }
    }
}
```

The Swift UI tails this same file via `mmap()` directly — *no FFI call per record*. Only the head cursor crosses the boundary, atomic-loaded via a tiny C function.

---

## 5. Six-Month Implementation Roadmap

I'm assuming you're a single developer with a parallel 24-week MoE inference roadmap; that means ~half your engineering time. I've sequenced this so that *every milestone is independently shippable* and so that nothing depends on a chain of >2 prior items.

### Month 1 — Measurement & GRDB hardening (foundation)
- **Week 1.** Wire `OSSignposter` into every Rust→Swift call site (one signpost per UniFFI function), every render frame, every MCP invocation, every GRDB query. Build a `Performance.instrpkg` with custom modeler.
- **Week 2.** Apply the SQLite/GRDB pragma block (§3.7). Convert all hot queries to `cachedStatement(sql:)`. Measure before/after.
- **Week 3.** Cargo release profile: `lto = "fat"`, `codegen-units = 1`, `panic = "abort"`, `strip = "symbols"`. Measure binary size and cold-start.
- **Week 4.** Establish performance budgets: cold start < 800 ms, frame < 8.3 ms p99, MCP tool invocation < 2 ms p99 for in-process tools, query < 1 ms p99 for indexed reads. Wire CI to fail on regressions using a synthetic workload.

**Stabilization checkpoint A.** If you stop here, you have measurement, GRDB tuning, and binary hygiene. That alone is a 20–40% perceived-perf win.

### Month 2 — Slotmap + SoA migration (substrate-core foundation)
- **Week 5.** Introduce `slotmap` and `SecondaryMap` for the artifact store and edge store. Keep the old store in parallel behind a feature flag.
- **Week 6.** Migrate read paths to slotmap. Convert at least the title and kind components to SecondaryMap (SoA).
- **Week 7.** Migrate write paths. Run differential testing: every operation goes to both stores, results compared.
- **Week 8.** Remove the old store. Expose `ArtifactKey::data() -> u64` as the FFI-stable handle.

**Stabilization checkpoint B.** O(1) entity ops with stale-handle safety, exposed across the FFI as `u64`. This makes everything below cheap.

### Month 3 — phf registries + Swift macro view router
- **Week 9.** Add `phf_codegen` to `build.rs`. Migrate the MCP tool registry, edge-kind enum, and slash-command parser to compile-time PHF maps.
- **Week 10.** Write the `@ArtifactView` Swift macro. Migrate the existing artifact-view dispatch to the macro-generated `switch`.
- **Week 11.** Write a `@MCPSchema` macro on the Rust side (proc-macro) that generates the schema and registers the handler — eliminates the JSON-schema parse entirely.
- **Week 12.** Audit the codebase for `[String: Any]` and `as? AnyView` patterns; replace with macro-driven enums.

**Stabilization checkpoint C.** No string-keyed dispatch on hot paths. No JSON parse on startup. Every view-binding error is a Swift compile error.

### Month 4 — Metal pre-compilation + bindless graph
- **Week 13.** Move Metal shader compilation offline. Ship `GraphShaders.metallib` in the bundle.
- **Week 14.** Generate `MTLBinaryArchive` for every PSO at build time using `metal-tt --pipelines pipelines.mtlp`. Verify with Instruments that the GPU "compile" track is empty on launch.
- **Week 15.** Convert the graph renderer to argument buffers: one buffer of `NodeRecord` and one buffer of `EdgeRecord`, both `repr(C)` shared between Rust and Metal.
- **Week 16.** Move force-directed layout to a compute shader (Barnes-Hut quadtree on GPU). Validate against the existing CPU implementation on layouts of 100, 1K, 10K nodes.

**Stabilization checkpoint D.** Cold-start time should be down by 30–100 ms; the graph should hit 120 fps at 10K nodes on M2 Pro.

### Month 5 — Zero-copy FFI ring + raw thoughts
- **Week 17.** Carve out `substrate-rt` crate with the `repr(C)` event ring (§4.1). Add `module.modulemap` so Swift sees it without UniFFI.
- **Week 18.** Migrate the highest-volume UniFFI events (cursor moves, edit deltas, layout updates, MCP streaming chunks) to the ring. Keep UniFFI for control plane.
- **Week 19.** Implement the mmap'd raw-thoughts log (§4.4). Hook the UI's tail-reader.
- **Week 20.** Differential testing + signpost-driven A/B: prove latency drop with measurements, not vibes.

**Stabilization checkpoint E.** Median FFI hot-path latency below 1 µs (was likely 20–100 µs through UniFFI). Raw thoughts capture is sub-millisecond, end-to-end.

### Month 6 — PGO + tree-sitter fast path + polish
- **Week 21.** Set up `cargo-pgo` workflow. Record a 60-second representative workload as the training profile. Optimize.
- **Week 22.** Tree-sitter SoA highlight cache (§2 path 5). Expose as a `repr(C)` slice.
- **Week 23.** Pre-touched memory pools: at app launch, allocate (and `mlock` if reasonable) the bumpalo arenas, the event ring, the GPU buffers, and the MTL binary archive. No allocation in the first frame.
- **Week 24.** Final pass: regression tests, Instruments traces archived, performance budgets in CI.

### Stabilize / De-Scope Path

If anything goes sideways, here is the explicit "still wins, easy to keep" minimum:

1. Keep §3.7 (GRDB pragmas) — no architectural risk, ~1 day to implement.
2. Keep §3.4 (LTO/strip/abort) — ~10 lines of TOML.
3. Keep §3.10 (os_signpost) — pure win, no architectural risk.
4. Keep Path 5 / §3.6 (slotmap) but skip the SoA SecondaryMaps if scope is tight. Slotmap alone is a drop-in `HashMap` replacement.
5. Drop the `repr(C)` ring buffer entirely if it's destabilizing. UniFFI overhead is real but not catastrophic at moderate event rates.
6. Drop bindless rendering. Binary archives alone (§3.1) are 80% of the Metal win at 10% of the engineering cost.

In other words: **if you must, ship items 1–4 of §1 and skip item 5 and bindless rendering. You will still have a noticeably faster app.**

---

## 6. Theoretical Grounding & References

These are the sources I'd put in a Phase I reading list, ordered for solo-dev efficiency.

**Mandatory:**
- Mike Acton, "Data-Oriented Design and C++", CppCon 2014 — [YouTube](https://www.youtube.com/watch?v=rX0ItVEVjHc). The talk that named the field. One hour, watch twice.
- Andrew Kelley, "Practical Data Oriented Design", Handmade Seattle 2021 — [transcript](https://www.josherich.me/podcast/andrew-kelley-practical-data-oriented-design-dod). DoD applied to a real compiler, with measurements.
- TigerBeetle ARCHITECTURE.md and TIGER_STYLE.md — [github.com/tigerbeetle/tigerbeetle](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/ARCHITECTURE.md) and [TIGER_STYLE.md](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md). Determinism as a load-bearing engineering principle.
- Apple WWDC22 "Target and optimize GPU binaries with Metal 3" — [developer.apple.com/videos/play/wwdc2022/10102](https://developer.apple.com/videos/play/wwdc2022/10102/). The how-to for path 4.
- David Koloski, "rkyv is faster than {bincode, capnp, cbor, flatbuffers, ...}" — [david.kolo.ski/blog/rkyv-is-faster-than/](https://david.kolo.ski/blog/rkyv-is-faster-than/). Published benchmarks for the FFI format choice.

**Strongly recommended:**
- Casey Muratori, "Performance-Aware Programming" series — [computerenhance.com](https://www.computerenhance.com/p/table-of-contents). The ground-truth explanation of cycles, IPC, memory hierarchy.
- Mitchell Hashimoto, "Talk: Introducing Ghostty and Some Useful Zig Patterns" — [mitchellh.com/writing/ghostty-and-useful-zig-patterns](https://mitchellh.com/writing/ghostty-and-useful-zig-patterns). The architecture you should partially copy.
- Will Bond (Sublime Text), "Building a High Performance Text Editor" — [wbond.net/thoughts/building_a_high_performance_text_editor](https://wbond.net/thoughts/building_a_high_performance_text_editor). The "do less" philosophy.
- Sublime HQ, "Faster Rendering Using Hardware Acceleration" — [sublimetext.com/blog/articles/hardware-accelerated-rendering](https://www.sublimetext.com/blog/articles/hardware-accelerated-rendering). Real numbers on glyph batching wins.
- Phiresky, "SQLite performance tuning" — [phiresky.github.io/blog/2020/sqlite-performance-tuning/](https://phiresky.github.io/blog/2020/sqlite-performance-tuning/). The canonical pragma reference.
- Jakub Beránek, "Optimizing Rust programs with PGO and BOLT using cargo-pgo" — [kobzol.github.io/rust/cargo/2023/07/28/rust-cargo-pgo.html](https://kobzol.github.io/rust/cargo/2023/07/28/rust-cargo-pgo.html). The PGO workflow.
- Cloudflare, `mmap-sync` — [github.com/cloudflare/mmap-sync](https://github.com/cloudflare/mmap-sync). Production zero-copy IPC pattern with rkyv.
- Russ Bishop, "Cross-process Rendering" — [russbishop.net/cross-process-rendering](http://www.russbishop.net/cross-process-rendering). IOSurface / Mach ports / MTLSharedTextureHandle, definitively.

**Worth knowing exists:**
- Apple WWDC18 "Measuring Performance Using Logging" (os_signpost) — [WWDC18 405](https://developer.apple.com/videos/play/wwdc2018/405/).
- Apple WWDC21 "Explore bindless rendering in Metal" — [WWDC21 10286](https://developer.apple.com/videos/play/wwdc2021/10286/).
- Apple WWDC23 "Write Swift macros" — [WWDC23 10166](https://developer.apple.com/videos/play/wwdc2023/10166/).
- Jonathan Blow, JAI compile-time execution demos — the conceptual ceiling for "everything known at build time" ([JaiPrimer](https://github.com/BSVino/JaiPrimer/blob/master/JaiPrimer.md), [Jonathan Blow keynote summary](https://recapio.com/digest/jonathan-blow-jai-demo-and-design-explanation-keynote-updated-by-lambdaconf)). Watch for inspiration; you can't actually use JAI today.
- Apple Machine Learning Research, "Exploring LLMs with MLX and the Neural Accelerators in the M5 GPU" — [machinelearning.apple.com](https://machinelearning.apple.com/research/exploring-llms-mlx-m5). Confirms MLX-Swift remains the right inference choice on Apple Silicon.

---

## 7. Honest Tradeoff Analysis: Where Determinism Breaks Down

This is the section your "concerned about scope getting messy" instinct deserves.

**Where dynamic dispatch is actually correct:**
- **User-installed plugins / MCP servers from the network.** You cannot phf-compile what you do not know at build time. The right model is: a *built-in* phf table for first-party tools, and a runtime registry (BTreeMap) for network MCP servers. The two coexist without contradiction.
- **The settings system.** Setting keys are read once on launch and on user change. Even a dictionary is fine. Don't macro this.
- **Anything with reasonable schema evolution requirements.** rkyv famously lacks schema evolution out of the box ([HN response](https://news.ycombinator.com/item?id=26428812)). For *persisted* data you should keep SQLite + GRDB or use FlatBuffers/Cap'n Proto whose schema evolution is a feature. rkyv is for transient FFI/IPC, not long-term storage.

**Where you might be over-engineering:**
- **Replacing UniFFI everywhere.** UniFFI's overhead is on the order of microseconds per call. If a call is invoked 60 times per frame (like a graph hit-test), it's a real cost. If it's invoked when the user opens a settings sheet, it's invisible. Don't migrate the whole API.
- **Bindless rendering for 10K nodes.** 10K is not many. A naïve renderer can draw 10K instanced quads on M2 Pro at 120 fps without breaking a sweat. Bindless wins big at 100K+. Do the binary archive (huge, easy) before the bindless conversion (modest, complex).
- **NaN-boxing and tagged pointers.** Almost certainly not worth it for a statically-typed Rust core.
- **Hand-rolled SIMD.** Compiler vectorization is good. Profile first.

**Where I am uncertain:**
- **The right cutover line for the FFI ring.** "Hot path" is a measurement, not an opinion. The honest answer is: instrument with os_signpost, find the calls that take >0.5% of frame time or fire >100 Hz, and migrate exactly those.
- **PGO's actual win on your workload.** Published wins are 5–15%. Your workload might be more or less amenable. Run cargo-pgo, measure, decide.
- **Whether GRDB or raw `rusqlite` is the better long-term bet.** GRDB is excellent and Swift-native; if you ever decide you want SQL prepared at Rust build time (§3.12), the path of least resistance is to move SQL into Rust crate(s) and have GRDB only for *Swift-side* convenience queries (settings, sync state). This is a Phase II decision, not a Phase I one.

---

## 8. The Researcher's Ranked Architectural Recommendation

You asked for my own take, compared to yours and Gemini's. Here it is:

**My ranking, by ROI / risk:** (1) Measure first (os_signpost), (2) Tune SQLite, (3) Slotmap+SoA, (4) Pre-compiled Metal, (5) phf registries + Swift macro routing, (6) `repr(C)` ring buffer for the FFI hot path, (7) mmap raw thoughts, (8) Tree-sitter SoA spans, (9) PGO/LTO, (10) Bindless rendering. Items 1–5 are low-risk and high-ROI; 6–8 are higher-risk and high-ROI; 9 is icing; 10 is a Phase II treat.

**Where I differ from your six paths:**

- Your **Path 1** (artifact ontology → static UI) is correct in spirit; my refinement is to do it via Swift macros, not a hand-maintained `switch`. SwiftUI is *already* a compile-time-routed system; lean into that, don't fight it.
- Your **Path 2** (graph edges → pre-fetching) I would re-frame as "deterministic *cache warming*" rather than "deterministic pre-fetching." It's still speculation, just well-priored speculation. Budget it.
- Your **Path 3** (MCP tool registry → static structs) is the canonical phf use case and you're right.
- Your **Path 4** (zero-copy FFI) is the biggest single win and you're right; the format that wins on benchmarks is **rkyv for variable-size, repr(C) raw structs for fixed-size**, with **MTLBuffer.shared for GPU-visible** data thanks to UMA. I would keep UniFFI for the control plane.
- Your **Path 5** (tree-sitter byte-offset cache) — already how tree-sitter wants to be used. Yes, do it; just lean fully into the tree-sitter API and SoA the spans for cache locality.
- Your **Path 6** (raw-thought direct streams) is correct; I added that the right mechanism is mmap'd append-only with Swift tailing the same file (no FFI per record), and that os_signpost should bracket every flush.

**Where I would push back on Gemini's likely framing** (inferred — you described it as "elaborated"):
- Beware framings that recommend a *single* zero-copy format ("just use FlatBuffers" or "just use Cap'n Proto"). The published benchmarks are clear that no single format dominates; the right answer is layered.
- Beware framings that conflate "bindless rendering" with "more performance." Binary archives are the easy win; bindless is the complex win that helps mostly at scales bigger than yours today.
- Beware framings that don't carve out an explicit stabilize/de-scope path. Ambitious determinism plans regress to chaos when the developer is one human with finite time.

**The fundamental claim of this report:** Determinism for Epistemos isn't about replacing every dynamic system. It's about identifying the four or five places where *you genuinely know more than you're telling the compiler*, and surfacing that knowledge as build-time data — phf tables, repr(C) layouts, pre-compiled metallibs, slotmap handles, mmap'd logs. Each of those moves takes real but bounded engineering. None of them require rewriting the app. All of them compose. And every one of them is reversible if the measurement says it didn't pay.

That's the philosophy that Ghostty, Zed, TigerBeetle, the Zig compiler, and Sublime Text all share, and it's the shape Epistemos should take: a deterministic core with a dynamic shell, not the other way around.

Ship it in the order above, measure with os_signpost, and the next time someone uses Epistemos they will say what people say about Zed: "my god, how can it be this fast" ([agmazon.com](https://agmazon.com/blog/articles/technology/202603/zed-ide-complete-guide-en.html)).