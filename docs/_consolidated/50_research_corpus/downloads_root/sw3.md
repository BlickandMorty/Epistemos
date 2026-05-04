# Swift–Rust FFI Performance Playbook for a 120Hz Knowledge Graph and an Editor-Grade Text Core

## High-value deliverables for a coding agent

The fastest way to “perfect performance” is to reduce the problem into **a small number of hard contracts** (FFI ABI, memory ownership, update cadence) and then instrument everything until the numbers prove you’re done.

These are the **high-value parts** that unlock most of the speedup with the least thrash:

1) **One stable, shared memory contract for hot data** (graph buffers, editor scratch buffers): avoid bridging into Swift `Array`/`String` unless you explicitly want a copy. Swift standard-library collections are value types and use copy-on-write; turning foreign memory into a Swift-owned collection is where copying tends to creep in. citeturn4search22turn4search2

2) **A single “once-per-frame” batched FFI entrypoint** (plus a couple of cold-path calls): the call cost is rarely the bottleneck; the churn from frequent marshaling, allocations, and conversions is. (You can keep a few cold-path calls for file open/close, initial graph load, etc.)

3) **Metal-friendly graph buffer wiring**: choose one of two zero-copy patterns (Swift-owned `MTLBuffer` that Rust writes into, or Rust-owned page-aligned memory wrapped by `makeBuffer(bytesNoCopy:...)`). The performance difference is usually smaller than the correctness difference—pick the one you can make bulletproof. citeturn5search1turn4search1turn5search9

4) **Editor protocol in deltas + viewport pulls**: treat the Rust rope as source-of-truth and only move **edits** and **visible slices** across the boundary. Rope-based backends are explicitly designed for editor-style random inserts/deletes on large texts. citeturn2search3turn2search35turn2search40

5) **Index/encoding strategy written down as a spec**: most “mysterious editor slowness” comes from Unicode/index conversion loops and accidental substring retention, not from your rope itself. Swift strings are grapheme-cluster-based; Cocoa text ranges are UTF‑16 code units; and LSP historically defaulted to UTF‑16 (with negotiation options in newer protocol versions). citeturn2search0turn2search4turn10view1turn9search9

## A precise mental model of where FFI time goes

The tension: you can make an FFI call “as low-level as C”, and still get wrecked.

The mechanism: **ABI calls are cheap; “making data safe/usable” is expensive**.

### The call boundary is the easy part
On the Rust side, `extern "C"` is literally “use the platform C ABI,” which is why it’s the standard interoperability surface. citeturn0search26turn1view3  
Swift imports C functions as Swift globals, so the calling side can be very direct. citeturn11search6

### Marshaling is the real tax
You pay big when you cross into **Swift-owned** types:

- **Arrays**: `Array` is a value type with copy-on-write; copies are deferred, but any step that materializes a Swift-owned array from foreign memory implies copying or ownership transfer, and later mutations trigger copies. citeturn4search22turn4search2  
- **Pointers**: Swift’s pointer APIs are designed to keep pointer lifetimes bounded. The pointer you get in `withUnsafePointer` / `withUnsafeBytes(of:)` is only valid during the closure. If you need a pointer that lives across frames, you must allocate/own it explicitly. citeturn0search9turn4search7turn4search15  
- **Strings**: Swift `String` is a collection of extended grapheme clusters (user‑visible characters), while `NSString` is defined in terms of UTF‑16 code units; conversions can be nontrivial and are rarely O(1). citeturn2search1turn2search4turn2search0

### The practical resolution
Your “hot path” should cross the boundary carrying only:

- **Plain-old-data structs** (`repr(C)` on Rust, fixed layout; no heap pointers unless paired with explicit ownership rules),
- **Borrowed slices** (pointer + length),
- **Preallocated output buffers** (Swift provides memory, Rust fills it).

This retains the “C ABI speed” benefit while avoiding collection/string bridging.

## The 120Hz knowledge graph with Metal: truly zero-copy, not “looks zero-copy”

The tension: you want Rust to update positions every frame, and Metal to read them without repeated copies.

The mechanism: Metal already gives you a real shared-memory path—**if you select the right storage mode and sync discipline**.

The resolution: choose one of two patterns and commit to its constraints.

### Pattern A: Swift owns `MTLBuffer`, Rust writes into it
This is often the most robust first implementation.

1) Swift allocates an `MTLBuffer` with CPU-visible storage (commonly `shared` on iOS / Apple silicon).
2) Swift calls `buffer.contents()` to get a raw pointer.
3) Swift passes that pointer to Rust once (bind step).
4) Rust writes updated floats into that memory each tick; Metal reads it as a vertex/instance buffer.

Key facts to bake into your contract:

- `MTLBuffer.contents()` returns **a pointer to the shared copy of the buffer data**, and it is **NULL for private storage mode**. So your plan must select a CPU-visible mode if Rust writes directly. citeturn5search1turn5search26  
- In `shared` mode, CPU and GPU share memory, but you are responsible for synchronizing access (don’t write while GPU is using it). Documentation explicitly calls out that you must handle synchronization. citeturn5search12turn5search23  
- On macOS `managed` storage, if you write from CPU you must call `didModifyRange` so the GPU sees updates. citeturn0search10

**Why this is high value:** it avoids dealing with page-aligned allocations and custom Metal deallocators, and it stays zero-copy in the sense that the GPU reads the same bytes Rust wrote. citeturn5search1turn5search12

### Pattern B: Rust owns memory, Swift wraps it using `makeBuffer(bytesNoCopy:...)`
This gives maximal control but has stricter requirements.

- `makeBuffer(bytes:length:options:)` copies data into a new Metal allocation. citeturn5search9  
- `makeBuffer(bytesNoCopy:length:options:deallocator:)` wraps an existing allocation, but **the pointer must be page-aligned and the length must define a page-aligned region**. citeturn4search1turn4search5  
- The allocator choice matters: if you page-align with `posix_memalign`, the alignment must be a power of two and a multiple of `sizeof(void*)`, and the result can be passed to `free`. citeturn4search0turn4search20

**Why this is high value:** it’s the cleanest “no hidden copies” story when you also want Rust to control the buffer’s allocation strategy. But it’s also where most teams introduce rare, catastrophic bugs (misalignment, early free, resizing). citeturn4search1turn4search0

### Buffer layout details that matter at 120Hz
A lot of “mysterious GPU bugs” are actually layout/alignment issues.

- If you pack per-node data into structs, align to common GPU expectations. For example, `float4` alignment commonly requires 16‑byte boundaries, and padding is often the simplest fix. citeturn5search17  
- Don’t use `setBytes` for large per-frame data. Apple’s feature-set tables show a **maximum inlined buffer length using `setBytes` of 4 KB**; anything bigger should be a buffer resource. citeturn7view0

### The performance “perfection” move: remove CPU↔GPU contention
Even with shared memory, you can lose time by stalling.

Use **double or triple buffering**: two/three `MTLBuffer`s (or two/three regions in one buffer) and an atomic index/version. Rust writes into “next,” Swift encodes GPU commands reading “current,” then swap at a known boundary (e.g., once the command buffer is committed). This matches the reality that coherency is strongest at command-buffer boundaries. citeturn5search23turn14search1

## The code editor: delta protocol + rope backend + encoding discipline

The tension: you want “per-keystroke” updates without reallocating or transcoding the whole document.

The mechanism: most UI text systems and language tooling traffic in **ranges + replacement text**, not whole strings.

The resolution: do the same across Swift↔Rust, and make encoding/index semantics explicit.

### Rope backend as the source of truth
A rope is a well-known editor buffer structure because it makes inserts/removes efficient for large texts. citeturn2search40turn2search3  
`ropey` is explicitly positioned as a UTF‑8 editor buffer, operating in Unicode scalar (`char`) indices and providing efficient queries and conversions between byte/char/line indices. citeturn2search3turn2search35

That naturally supports:

- Apply an edit (insert/remove) in near-log time,
- Pull only visible lines for rendering,
- Maintain line index metadata without rescanning the whole file each time.

### Your hardest editor decision: what “index” crosses the boundary?
Swift and language tooling disagree about what a “character” is:

- Swift `String` models text as **extended grapheme clusters** (user-visible characters). citeturn2search0turn2search1  
- `NSString` is UTF‑16 code units; its indexes/ranges are defined that way. citeturn2search4  
- LSP historically defined positions as UTF‑16 offsets, and as of 3.17 allows negotiating UTF‑8/UTF‑16/UTF‑32, with UTF‑16 mandatory for backward compatibility. citeturn10view1turn10view0

**Executable recommendation:** define your FFI edit ranges in one of these two ways and never mix them:

- **Option 1 (UI-friendly):** `(startLine, startUTF16Col, endLine, endUTF16Col, replacementUTF8Bytes)`  
  - Pro: maps cleanly to Cocoa/UI ranges and default LSP conventions. citeturn2search4turn10view1  
  - Con: Rust must convert a UTF‑16 column into a byte/char index for the specific line content (but that’s localized work, not whole-file work). LSP itself notes conversion is best done where the file content is available (often the server side). citeturn10view1  

- **Option 2 (backend-friendly):** `(startByteOffsetUTF8, endByteOffsetUTF8, replacementUTF8Bytes)`  
  - Pro: simplest for a UTF‑8 rope.  
  - Con: Swift/UI must compute UTF‑8 byte offsets, which is easy to get wrong when you’re handed grapheme-cluster indices from UI components. citeturn2search0turn2search1  

If you plan to integrate LSP-like features, Option 1 tends to reduce integration friction because LSP explicitly standardizes position encoding negotiation and defaults. citeturn10view1turn10view0

### Viewport pulls: don’t ship whole files, ship slices
A practical pattern:

- Swift sends edits (deltas) to Rust immediately.
- Rust applies edits to the rope.
- Swift requests **only the visible region** (e.g., ~200–400 lines, or a byte cap like 64 KB), and Rust writes into a Swift-provided output buffer.

This matches the “never store giant substrings” warning: Swift substrings can keep the entire original storage alive, which can look like leaking when you hold onto them accidentally. citeturn9search9turn9search2

### Fast syntax highlighting and diagnostics: batch spans, not strings
Once you have a stable indexing scheme, send arrays like:

- `TokenSpan { startLine, startCol, endLine, endCol, tokenType }`
- `DiagnosticSpan { ... messageOffsetOrId ... }`

The important piece is: these are **small POD arrays**, so they can cross FFI cheaply, and they don’t force Swift to rebuild huge attributed strings each keystroke.

## The FFI surface: ownership, batching, and “don’t crash the process” rules

The tension: you want to go “unsafe enough” for speed without making the whole app fragile.

The mechanism: FFI errors usually come from **lifetime**, **alignment**, and **unwinding** violations.

The resolution: put guardrails at the boundary and keep the inside fast.

### A minimal, high-performance ABI shape (Rust side)
The following patterns are deliberately boring because boring is fast and testable.

- Use opaque handles for Rust state.
- Pass slices as `(ptr, len)`.
- Return status codes, not panics.

Key Rust constraints worth turning into explicit checks:

- `slice::from_raw_parts` is UB if pointer alignment/validity rules are violated; the pointer must be non-null and properly aligned, and it must point to `len` initialized values. citeturn3search1  
- Even empty slices have tricky invariants in Rust references; don’t blindly create references from null pointers. citeturn3search1turn3search17  

**Executable approach:** in extern functions, treat `(ptr == null && len == 0)` as allowed by your ABI, and avoid creating a Rust slice reference in that case; only create `from_raw_parts` when `len > 0`. This keeps Swift-side ergonomics (empty arrays often produce nil pointers) without invoking UB.

### Panic/unwind safety: NEVER let a Rust panic cross the boundary
Rust is explicit about unwind behavior around FFI boundaries:

- Unwinding rules vary by ABI string; `extern "C"` is treated as “no unwind,” and if a Rust panic would cross it, the runtime is guaranteed to abort the process. citeturn1view3  
- If you need to convert panics into error returns, you should `catch_unwind` at the boundary. citeturn1view3turn0search8  

**High-value guardrail:** wrap every exported function in `catch_unwind` and translate to an error code (or set a last-error string). This prevents “one rare panic” from becoming “the whole app vanished.” citeturn1view3

### Swift-side pointer lifetime rules you can’t wish away
If Swift forms a pointer to an existing value via `withUnsafePointer` / `withUnsafeBytes`, that pointer is valid only during the closure. Storing it for later is incorrect by design. citeturn0search9turn4search7turn4search15  
So, for persistent shared memory, either:

- Allocate memory explicitly (Metal buffer, `malloc`/aligned allocation, etc.), or
- Keep all pointer use inside the closure and copy immediately (fine for small deltas, deadly for per-frame megabytes).

### One batched “frame call” beats a thousand tiny calls
If you do nothing else, do this: build a single per-frame command buffer.

A common shape:

- `frame_update(handle, command_bytes_ptr, command_len, out_event_bytes_ptr, out_cap, out_len_out) -> Status`

Swift does one call per frame, Rust does one parse per frame, and you control allocation by reusing buffers across frames. This directly attacks the “1,000 crossings for 1,000 updates” failure mode.

## Build + packaging + profiling: make it shippable and measurable

The tension: you want a setup a coding agent can build today, and you want proof it’s faster tomorrow.

The mechanism: codegen for headers reduces ABI drift; XCFramework/SwiftPM packaging makes consumption repeatable; profiling detects regressions early.

The resolution: standardize the pipeline.

### Header generation
Use `cbindgen` to generate C headers from your Rust public C API, reducing layout/ABI mismatches vs hand-written headers. citeturn3search2turn3search14

### Apple platform packaging (XCFramework + SwiftPM binary target)
To distribute as a Swift package in binary form, Apple’s guidance is: create an XCFramework bundle artifact and then vend it via SwiftPM. citeturn3search3turn3search19  
When distributing a binary framework as a Swift package, Apple’s docs explicitly instruct computing the SHA-256 checksum with `swift package compute-checksum` on the zipped XCFramework. citeturn12search3turn12search7

On the Rust side, use the platform support docs as the “truth” for target requirements: iOS targets are cross-compiled and require the iOS SDK from Xcode. citeturn15search0turn15search1

### Profiling that actually answers “did it get faster?”
For Metal-heavy workloads:

- Apple’s Metal developer workflows highlight that **Metal System Trace in Instruments** provides a timeline of CPU/GPU parallelism and memory usage. citeturn14search1turn14search16  
- Apple’s performance analysis docs describe launching Instruments via Product > Profile, which is the standard entrypoint for repeatable profiling runs. citeturn14search0turn14search4  
- For memory churn, Apple documents the Allocations instrument tracking heap and VM allocations. citeturn14search2  

For Rust microbenchmarks (rope edits, graph math kernels), `criterion` is the standard statistical microbenchmark tool; it’s designed to detect performance regressions with confidence. citeturn14search3turn14search5

### A minimal “performance acceptance test” you can automate
Make the performance target explicit, then measure it continuously:

- Graph: maximum allowed time per `frame_update`, maximum allocations per second, and no GPU stalls above a threshold (from Metal System Trace).
- Editor: maximum time to apply a single-character insertion at random positions in a large file, plus maximum bytes transferred per keystroke (should be bounded near viewport size, not file size).

This converts “we think it’s fast” into “we have a budget and the trace proves it.”

## TL;DR  
FFI calls can be near-C-cost, but **collection/string bridging and pointer-lifetime violations** are where real apps lose performance and stability; the winning design is **shared hot buffers + delta edits + one batched frame call**, instrumented with Metal System Trace and allocation tracking. citeturn4search22turn0search9turn14search1turn2search3

Did you already pick your editor indexing contract (UTF‑16 ranges vs UTF‑8 byte offsets), or do you want a concrete recommendation based on your UI stack (TextKit/AppKit vs SwiftUI custom text)?