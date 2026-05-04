# Three architectural upgrades for Epistemos

Epistemos can achieve sub-millisecond vector search, zero-cost theme rendering, and O(N) snapshot diffing through three targeted upgrades: replacing brute-force ANN with usearch's HNSW index, pre-computing theme values into cached structs with `let` properties, and unifying diff logic via Dictionary+Set algebra. Each upgrade eliminates an entire class of redundant computation. What follows is implementation-grade guidance — complete with code, benchmarks, and pitfalls — for all three.

---

## Part 1: Unifying TimeMachineService diff logic into a single O(N) pass

The core insight for the TimeMachineService refactor is that **two code paths (fallback and full) become one when "no previous state" is modeled as an empty array**. Feed `old = []` into the same Dictionary+Set diff helper, and every item appears as "added" — no special-casing required. The `else` branch that previously returned early now simply doesn't exist.

### Dictionary indexing eliminates O(N²) comparisons

The naive approach — `oldItems.first(where: { $0.id == new.id })` inside a loop — performs **O(N × M) comparisons**. At 10,000 snapshots, that's 100 million equality checks. Building a dictionary first reduces this to O(N + M) total:

```swift
// O(N) build, O(1) per lookup — total diff is O(N + M)
let oldIndex = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
let newIndex = Dictionary(uniqueKeysWithValues: new.map { ($0.id, $0) })
```

`Dictionary(uniqueKeysWithValues:)` is the correct initializer here (not `grouping:by:`) because snapshot IDs are unique. It will trigger a **runtime `preconditionFailure`** on duplicate keys — a useful safety net during development. Swift's `Dictionary` uses **open addressing with linear probing** and SipHash, guaranteeing amortized O(1) lookups when hash quality is high (auto-synthesized `Hashable` for structs qualifies).

### Set algebra categorizes changes in three operations

Once dictionaries exist for O(1) value retrieval, Set operations on the key spaces classify every item:

```swift
let oldIDs = Set(oldIndex.keys)    // O(N)
let newIDs = Set(newIndex.keys)    // O(M)

let addedIDs   = newIDs.subtracting(oldIDs)   // present in new, absent in old
let removedIDs = oldIDs.subtracting(newIDs)   // present in old, absent in new
let commonIDs  = oldIDs.intersection(newIDs)  // present in both — check for modifications
```

All three Set operations run in **O(N + M)** time. Swift's `Set` shares the same hash table implementation as `Dictionary`. The `commonIDs` intersection then requires one equality check per item to separate "modified" from "unchanged" — still O(1) per item via the dictionary lookups.

### The unified diff helper

This single method handles both initial load (`old = []`) and subsequent comparisons identically:

```swift
struct DiffResult<T> {
    let added: [T]
    let removed: [T]
    let modified: [(old: T, new: T)]
    var isEmpty: Bool { added.isEmpty && removed.isEmpty && modified.isEmpty }
}

private func computeDiff<T: Identifiable & Equatable>(
    old: [T], new: [T]
) -> DiffResult<T> {
    let oldIndex = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
    let newIndex = Dictionary(uniqueKeysWithValues: new.map { ($0.id, $0) })
    
    let oldIDs = Set(oldIndex.keys)
    let newIDs = Set(newIndex.keys)
    
    let added   = newIDs.subtracting(oldIDs).map { newIndex[$0]! }
    let removed = oldIDs.subtracting(newIDs).map { oldIndex[$0]! }
    let modified = oldIDs.intersection(newIDs).compactMap { id -> (old: T, new: T)? in
        let o = oldIndex[id]!, n = newIndex[id]!
        return o != n ? (old: o, new: n) : nil
    }
    
    return DiffResult(added: added, removed: removed, modified: modified)
}
```

The calling code collapses both branches into two lines:

```swift
func detectChanges(current: [Snapshot]) -> DiffResult<Snapshot> {
    let old = previousSnapshots ?? []   // nil → empty array: everything "added"
    let diff = computeDiff(old: old, new: current)
    previousSnapshots = current
    return diff
}
```

When `old` is empty, `oldIDs` is empty, so `subtracting` yields nothing removed, `intersection` yields nothing modified, and every new item appears as added. No branching, no fallback path.

### Performance characteristics and pitfalls

**Memory overhead** for the temporary dictionaries and sets is approximately **4× the collection size** — two dictionaries (keys + values) plus two sets (keys only). For 10,000 snapshots at ~200 bytes each, expect ~8 MB of transient allocation. Swift's copy-on-write semantics ensure no unnecessary copies when these temporaries are `let`-bound.

**Set results are unordered.** If deterministic ordering of added/removed items matters for UI updates, sort the results after computation. **String-keyed lookups** hash the full string — UUID strings are fixed-length (36 characters), making this effectively constant time. For a checksum-first fast path, compare checksums before full `Equatable` comparison to short-circuit unchanged items in the intersection.

Note that Swift's built-in `difference(from:)` (SE-0240, Swift 5.1+) uses Myers' algorithm for ordered sequences and **cannot detect modifications** — only insertions and removals. It is unsuitable for unordered, ID-identified snapshot diffing.

---

## Part 2: ResolvedTheme caching eliminates per-frame switch evaluation

SwiftUI's render loop re-evaluates every computed property every time `body` executes. A theme system built on computed properties — each containing a `switch` over the current theme — executes that switch **once per property, per view, per render frame**. With 20 theme tokens across 100 views, that's 2,000 switch evaluations per frame. The ResolvedTheme pattern reduces this to zero.

### Why computed properties are invisible to SwiftUI's diffing engine

SwiftUI compares views using **reflection-based structural comparison** of stored properties. When a view struct has only `let` properties of `Equatable` types, SwiftUI can determine whether the view changed by comparing those stored values directly — a fast memcmp-like operation. If all properties match, **`body` is never called**.

Computed properties don't participate in this comparison. They are re-evaluated only when `body` runs, and they run unconditionally. Airbnb's engineering team confirmed this architecture in their detailed write-up on SwiftUI performance, reporting a **15% reduction in scroll hitches** after making their views properly diffable through stored properties and `@Equatable` conformance.

Apple's WWDC 2023 session "Demystify SwiftUI Performance" (session 10160) reinforces this: "Make sure to check for expensive string interpolation or operations like data filtering and other work inside of body. It's important that body itself is as cheap as possible."

### The ResolvedTheme struct

All theme values become `let` stored properties on a single `Equatable` struct:

```swift
struct ResolvedTheme: Equatable {
    let primaryColor: Color
    let backgroundColor: Color
    let surfaceColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    let accentColor: Color
    let borderColor: Color
    let headingFont: Font
    let bodyFont: Font
    let captionFont: Font
    let cornerRadius: CGFloat
    let spacing: CGFloat
    // ... every design token as a stored let
}
```

Because every field is `let` and `Equatable`, SwiftUI can compare two `ResolvedTheme` instances field-by-field without invoking any computation. When the theme hasn't changed, this comparison short-circuits and prevents body re-evaluation entirely.

### Static dictionary cache with dispatch_once semantics

The cache pre-computes all themes at first access and never recomputes:

```swift
enum AppTheme: String, CaseIterable {
    case light, dark, ocean, forest
    
    // Thread-safe, lazily initialized exactly once (dispatch_once semantics)
    private static let cache: [AppTheme: ResolvedTheme] = {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.resolve()) })
    }()
    
    var resolved: ResolvedTheme { Self.cache[self]! }
    
    private func resolve() -> ResolvedTheme {
        switch self {
        case .light:
            return ResolvedTheme(
                primaryColor: Color(hex: "007AFF"),
                backgroundColor: .white,
                surfaceColor: Color(hex: "F2F2F7"),
                textColor: .primary,
                // ... all tokens
            )
        case .dark:
            return ResolvedTheme(
                primaryColor: Color(hex: "0A84FF"),
                backgroundColor: Color(hex: "1C1C1E"),
                // ...
            )
        // ... other themes
        }
    }
}
```

Swift guarantees that **`static let` properties are lazily initialized on first access, exactly once, thread-safely** — equivalent to `dispatch_once`. After initialization, reads are zero-synchronization. The `var resolved` accessor performs a single O(1) dictionary lookup to return the pre-built struct.

### Environment injection and the pointer-swap effect

Inject the resolved theme through SwiftUI's environment:

```swift
extension EnvironmentValues {
    @Entry var resolvedTheme: ResolvedTheme = AppTheme.light.resolved
}

// At the root of the view hierarchy:
ContentView()
    .environment(\.resolvedTheme, currentTheme.resolved)

// In any themed view:
struct ThemedCard: View {
    let title: String
    @Environment(\.resolvedTheme) private var theme
    
    var body: some View {
        Text(title)
            .font(theme.bodyFont)
            .foregroundStyle(theme.textColor)
            .padding(theme.spacing)
            .background(theme.surfaceColor)
            .cornerRadius(theme.cornerRadius)
    }
}
```

**Theme switching becomes a single value swap.** When `currentTheme` changes from `.light` to `.ocean`, one dictionary lookup returns the pre-cached `ResolvedTheme` for ocean. SwiftUI then compares the old and new `ResolvedTheme` structs field-by-field. Only views whose theme-derived values actually differ will re-render. No switch statements execute during the render pass — the switch ran once, at app launch, during cache initialization.

### Memory cost is negligible

Each `ResolvedTheme` instance stores ~20–30 properties of small value types (`Color`, `Font`, `CGFloat`). **Total cache size for four themes is well under 1 KB.** This is a one-time allocation that persists for the app's lifetime.

### Profiling tools for validation

Use `Self._printChanges()` inside a view's `body` to log why re-evaluation occurred (debug builds only — remove before submission). Xcode's Debug → View Debugging → Highlight SwiftUI Updates shows re-rendering visually. The new SwiftUI instrument in Instruments 26 (WWDC 2025, session 306) provides an "Update Groups" lane showing exactly when and why SwiftUI performs work.

### Key pitfalls to avoid

Do not use `@EnvironmentObject` with a class-based theme manager that publishes individual color changes — this causes over-invalidation across the entire view hierarchy. Do not put `resolve()` switch statements inside view bodies. Prefer value types for environment values; `@Entry` with reference types can trigger unexpected instance creation during environment preparation. Adding explicit `Equatable` conformance to views receiving `ResolvedTheme` enables SwiftUI's fastest comparison path, bypassing reflection.

---

## Part 3: HNSW vector search via usearch delivers sub-millisecond queries

At **10,000 vectors with 384 dimensions, usearch's HNSW index achieves ~50–100μs per query** — roughly 10–40× faster than brute-force linear scan and two orders of magnitude under the 10ms target. The real payoff comes as the corpus grows: HNSW's O(log N) scaling means 100K or 1M vectors remain fast, while brute force degrades linearly.

### usearch Cargo.toml setup and index creation

```toml
[dependencies]
usearch = "2.24.0"  # Latest as of February 2026; uses CXX for C++ FFI
```

The crate wraps Unum Cloud's C++ core via `cxx`. Build requires a C++ compiler and takes ~60 seconds. The API surface is clean:

```rust
use usearch::{Index, IndexOptions, MetricKind, ScalarKind};

let options = IndexOptions {
    dimensions: 384,                // MiniLM embedding size
    metric: MetricKind::Cos,        // Cosine similarity
    quantization: ScalarKind::F16,  // Half-precision: 50% memory, near-zero recall loss
    connectivity: 16,               // M parameter: bidirectional links per node
    expansion_add: 128,             // ef_construction: beam width during building
    expansion_search: 64,           // ef_search: beam width during query (tunable at runtime)
};

let index = Index::new(&options).expect("Failed to create index");
index.reserve(10_000).expect("Must reserve before adding");

// Add vectors (keys are u64 identifiers)
for (id, embedding) in document_embeddings.iter() {
    index.add(*id, embedding).expect("Failed to add vector");
}

// Search returns keys and distances sorted by proximity
let results = index.search(&query_vector, 10).unwrap();
for (key, distance) in results.keys.iter().zip(results.distances.iter()) {
    println!("Document {}: distance {:.4}", key, distance);
}
```

### How HNSW achieves O(log N) search

HNSW constructs a **multi-layer navigable graph** resembling a probabilistic skip list. The bottom layer contains all vectors with dense local connections. Higher layers contain exponentially fewer nodes serving as "express lanes." Search starts at the top layer, greedily hops to the nearest neighbor, then descends — visiting O(log N) layers with a small constant number of hops per layer.

The three critical parameters map directly to usearch's `IndexOptions`:

- **`connectivity` (M)**: Maximum bidirectional links per node per layer. Higher values improve recall but increase memory (~M × 8–10 bytes per vector overhead). **16 is optimal for embedding search at 384–768 dimensions.**
- **`expansion_add` (ef_construction)**: Beam width during graph construction. Higher values build a better graph but take longer. **128 is the standard production default.**
- **`expansion_search` (ef_search)**: Beam width during queries, tunable at runtime via `index.change_expansion_search(n)`. Higher values increase recall at the cost of latency. **64 delivers >95% recall at 10K scale; increase to 100–200 for 100K+ vectors.**

### Recommended configurations for common embedding models

For **384-dimensional MiniLM** embeddings (Epistemos's current model), F16 quantization cuts memory in half with negligible recall impact:

```rust
IndexOptions {
    dimensions: 384,
    metric: MetricKind::Cos,
    quantization: ScalarKind::F16,  // 768 bytes/vector vs 1536 for F32
    connectivity: 16,
    expansion_add: 128,
    expansion_search: 64,
}
```

For **768-dimensional BERT** embeddings (if upgrading models later), increase connectivity to compensate for the curse of dimensionality:

```rust
IndexOptions {
    dimensions: 768,
    metric: MetricKind::Cos,
    quantization: ScalarKind::I8,   // 384 bytes/vector; "almost no quantization loss"
    connectivity: 24,
    expansion_add: 200,
    expansion_search: 100,
}
```

I8 quantization at 768 dimensions can actually **outperform F16** on hardware without native half-precision support, because it reduces memory bandwidth pressure.

### Zero-copy FFI between Rust and Swift

The critical performance path — passing embedding vectors across the FFI boundary — can be zero-copy. Swift arrays are contiguous in memory, and `withUnsafeBufferPointer` exposes the raw pointer for the duration of a function call:

**Rust FFI surface:**
```rust
#[no_mangle]
pub unsafe extern "C" fn index_search(
    query: *const f32,
    dims: u32,
    k: u32,
    out_keys: *mut u64,
    out_distances: *mut f32,
) -> u32 {
    let index = INDEX.get().expect("Index not initialized");
    let q = std::slice::from_raw_parts(query, dims as usize);
    match index.search(q, k as usize) {
        Ok(results) => {
            let n = results.keys.len();
            std::ptr::copy_nonoverlapping(results.keys.as_ptr(), out_keys, n);
            std::ptr::copy_nonoverlapping(results.distances.as_ptr(), out_distances, n);
            n as u32
        }
        Err(_) => 0,
    }
}
```

**Swift caller:**
```swift
func search(query: [Float], k: Int) -> [(key: UInt64, distance: Float)] {
    var keys = [UInt64](repeating: 0, count: k)
    var distances = [Float](repeating: 0, count: k)

    let count = query.withUnsafeBufferPointer { qBuf in
        keys.withUnsafeMutableBufferPointer { kBuf in
            distances.withUnsafeMutableBufferPointer { dBuf in
                index_search(
                    qBuf.baseAddress!, UInt32(query.count), UInt32(k),
                    kBuf.baseAddress!, dBuf.baseAddress!
                )
            }
        }
    }
    return (0..<Int(count)).map { (keys[$0], distances[$0]) }
}
```

The query vector is passed as a raw `*const f32` pointer — **no allocation, no copy**. Results are written directly into pre-allocated Swift arrays. The only copies are the output keys and distances, which are small (k × 12 bytes for k=10).

### Persistence and loading `.f32` files

usearch supports three persistence modes:

```rust
index.save("embeddings.usearch")?;          // Full save to file
index.load("embeddings.usearch")?;          // Full load into RAM
index.view("embeddings.usearch")?;          // Memory-mapped: serves from disk, no RAM copy
```

For Epistemos's `.f32` files on disk, the migration workflow is: read the raw f32 data, build the HNSW index, save it as a `.usearch` file alongside the source data, and load the index at startup. Rebuilding from scratch on data changes is fast — **10,000 vectors at 384 dimensions builds in ~100–500ms**.

### Expected latency at target scale

| Metric | Brute force (10K × 384-dim) | HNSW usearch |
|---|---|---|
| **Single query latency** | ~0.5–2ms | **~50–100μs** |
| **Index build time** | N/A | ~100–500ms |
| **Memory (F16)** | 7.4 MB (raw vectors) | ~12–18 MB (vectors + graph) |
| **Recall at ef=64** | 100% (exact) | >95% |

At 10K vectors, even brute force meets the 10ms target — but HNSW provides **10–20× headroom** for growth. At 100K vectors, brute force would take ~5–20ms per query while HNSW stays under 1ms.

### Gotchas specific to usearch in Rust

**You must call `reserve()` before `add()`.** The index requires pre-allocated capacity. Failing to reserve triggers errors. **Duplicate keys are allowed by default** — usearch supports multiple vectors per label. Call `index.count(key)` to check. **Thread safety is guaranteed in v2.24.0** (`Send + Sync` are implemented), but earlier versions required manual unsafe wrappers. For parallel insertion, use `add_in_thread(key, vector, thread_id)` to avoid thread-local allocation contention.

The `view_from_buffer()` method is **explicitly unsafe** — it stores a pointer to external memory, creating a use-after-free risk if the buffer is dropped while the index is alive. Stick to `save()`/`load()` for standard persistence.

### Why usearch over pure-Rust alternatives

The strongest pure-Rust competitor is **`hnsw_rs`** (~20K monthly downloads, active maintenance, multi-threaded via parking_lot). It avoids the C++ build dependency but lacks usearch's SimSIMD acceleration, built-in quantization, and memory-mapped serving. **`instant-distance`** is minimal (~826 lines) and immutable after construction — no incremental updates. **`hora`** appears unmaintained since 2021. For Epistemos's performance-critical use case where a C++ compiler is already available (building for macOS/iOS), **usearch's SIMD-optimized C++ core delivers the best raw performance** and its cross-platform index format means the same `.usearch` file could be read by Swift-native bindings if the architecture evolves.

---

## Conclusion

These three upgrades target distinct performance bottlenecks but share a common principle: **move computation from per-query/per-frame hot paths to one-time initialization.** The Dictionary+Set diff computes O(N) work once instead of O(N²) per comparison. The ResolvedTheme cache resolves switch statements once at startup instead of thousands of times per frame. The HNSW index builds a navigable graph once instead of scanning all vectors per query. Together, they transform Epistemos from an application that re-derives answers on every cycle to one that pre-structures its data for instant retrieval — the architectural foundation for the sub-10ms responsiveness target.