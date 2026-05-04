# Stateful Rotor Implementation Reference: Swift 6 / Rust FFI PKM with Local + Cloud AI

**Fused knowledge base for implementing Epistemos — the cognitive exoskeleton.**

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  Swift 6 UI Layer (macOS native, strict concurrency) │
├─────────────────────────────────────────────────────┤
│  C-FFI Boundary (narrow, well-typed, async-safe)     │
├─────────────────────────────────────────────────────┤
│  Rust Core Engine                                    │
│  ┌───────────────┐ ┌──────────────┐ ┌─────────────┐ │
│  │ Stateful Rotor│ │ Meta-Memory  │ │ Inference    │ │
│  │ (VecDB +      │ │ Index (MMR)  │ │ Engine       │ │
│  │  Quantization)│ │              │ │ (MLX/Metal)  │ │
│  └───────┬───────┘ └──────┬───────┘ └──────┬──────┘ │
│          │                │                │         │
│  ┌───────┴────────────────┴────────────────┴──────┐  │
│  │         Concurrency Lattice                     │  │
│  │  (crossbeam-epoch + segment MVCC +              │  │
│  │   read-temperature scheduling)                  │  │
│  └─────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────┐  │
│  │  Storage Layer (io_uring async NVMe I/O)        │  │
│  └─────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

---

## 2. Quantization Pipeline — Step-by-Step Build Guide

### Phase 1: Ingestion (Target: instant, <1ms)

**What happens when a vector enters the system:**

1. Embedding arrives from Swift UI (via FFI) as `[f32; D]` where D=128–1536
2. Sensitivity profiler tags vector:
   - KVTuner-style attention pattern analysis → "retrieval head" or "streaming head"
   - ThinKV thought-stage classification → reasoning / execution / transition
3. Vector enters at FP16 (16-bit) in the mutable growing segment
4. TurboQuant fallback compression applied immediately for searchability:
   - Apply random orthogonal rotation Q (via QR decomposition of Gaussian matrix)
   - Coordinates follow Beta distribution → apply precomputed Lloyd-Max quantizer
   - Zero calibration time. Immediately searchable.

**Rust implementation pattern:**
```rust
// Ingestion path — must be lock-free on the read side
pub async fn ingest_vector(&self, raw: &[f32], metadata: VectorMeta) -> VectorId {
    let turbo_compressed = turbo_quant::compress(raw, &self.lloyd_max_codebook);
    let id = self.growing_segment.write().await.append(turbo_compressed, metadata);
    self.background_tx.send(BackgroundTask::SpectralCheck(id)).ok();
    id
}
```

### Phase 2: Correlation-Aware Preprocessing (Background, async)

**Spectral check triggers selectively:**

1. Background thread runs CEV (Collaboratively Evaluated Value) heuristic on new clusters
2. If inter-dimensional correlation is LOW → skip rotation, proceed to subspace PQ at O(ND)
3. If correlation is HIGH → schedule learned rotation

**Rotation options (choose based on latency budget):**

| Method | Complexity | Parameters | Quality (2-bit LLaMA-2-7B PPL) | Training |
|--------|-----------|------------|-------------------------------|----------|
| Random Hadamard | O(d log d) | 0 | ~22.1 | None |
| ButterflyQuant | O(d log d) | (d log d)/2 | 15.4 | ~500 steps |
| SpinQuant (Cayley SGD) | O(d²) | d² | Best | ~1000 steps |
| RotorQuant (Clifford) | O(d log d) | d/44 fewer | Good | ~500 steps |
| FlatQuant (Kronecker) | O(d√d) | 2×(√d)² | <1% gap from FP16 | ~20 min |

**Recommendation for Epistemos:** ButterflyQuant as default (O(d log d), good quality, fast convergence). FlatQuant for high-importance clusters where you can afford 20 minutes of background compute.

**Implementation:**
```rust
// ButterflyQuant rotation — Givens angle parameterization
pub struct ButterflyRotation {
    angles: Vec<f32>,  // (d * log2(d)) / 2 learnable parameters
    depth: usize,      // log2(d) butterfly stages
}

impl ButterflyRotation {
    pub fn apply(&self, x: &mut [f32]) {
        for stage in 0..self.depth {
            let stride = 1 << stage;
            for i in (0..x.len()).step_by(2 * stride) {
                for j in 0..stride {
                    let idx = self.angle_index(stage, i, j);
                    let (cos, sin) = (self.angles[idx].cos(), self.angles[idx].sin());
                    let a = x[i + j];
                    let b = x[i + j + stride];
                    x[i + j] = cos * a - sin * b;
                    x[i + j + stride] = sin * a + cos * b;
                }
            }
        }
    }
}
```

### Phase 3: Two-Stage Quantization

1. Apply learned rotation R to correlated cluster
2. MSE-optimal scalar quantization per subspace at target bit-width
3. Compute residual: `r = x - Q_inv(Q(x))`
4. 1-bit QJL transform on residual (sign bits + L2 norm)
5. Store: `[quantized_base | qjl_residual | l2_norm | scale | zero_point]`

**Unbiased inner-product estimation:**
```
<y, x_hat> = <y, Q_inv(Q(x))> + ||r||_2 * <y, QJL(r)>
```

### Phase 4: Progressive Precision Downgrade (Background, async)

**PM-KVQ Equivalent Right Shift:**

When memory budget approaches limit:
1. Identify least-sensitive slabs via KVTuner MOO policy
2. Execute bit-width reduction: 16→8→4→2
3. Mathematical operation: `floor((2^{2b} - 2^b + 1)(X_{2b} + 2^{b-1})) >> 3b`
4. Zero-point invariant: `Z_b = Z_{2b}`
5. Scale adjustment: `S_b = (2^b + 1) * S_{2b}`

**Implementation as yield-aware coroutine:**
```rust
pub async fn progressive_downgrade(&self, slab_id: SlabId, target_bits: u8) {
    let slab = self.sealed_segments.get(slab_id);
    let chunk_size = 1024; // vectors per yield

    for chunk in slab.vectors.chunks(chunk_size) {
        for vec in chunk {
            vec.right_shift_precision(target_bits);
        }
        tokio::task::yield_now().await; // yield to query handler
    }

    self.slab_metadata.update_precision(slab_id, target_bits);
}
```

---

## 3. Mixed-Precision SIMD Solutions

### The Kitty Two-Tensor Decomposition

**Problem:** Mixed bit-widths destroy SIMD parallelism.

**Solution:** Decompose any mixed-precision vector into two UNIFORM tensors.

For a vector with channels at {2-bit, 4-bit}:
- Tensor A (base): all channels at 2-bit (uniform, SIMD-friendly)
- Tensor B (boost): additional precision bits for 4-bit channels, packed as 2-bit (uniform)

Dequantization:
```
value_2bit = unpack_2bit(tensor_a[i]) * scale_a + zero_a
value_4bit = unpack_2bit(tensor_a[i]) * scale_a + unpack_2bit(tensor_b[i]) * scale_b + zero_a
```

### Slab-Based Memory Layout

```
Memory Layout:
┌──────────────────┐
│ Slab 0: 8-bit    │ ← cognitive anchors, retrieval heads
│ (uniform kernel)  │
├──────────────────┤
│ Slab 1: 4-bit    │ ← active reasoning context
│ (uniform kernel)  │
├──────────────────┤
│ Slab 2: 2-bit    │ ← compressed peripheral data
│ (uniform kernel)  │
├──────────────────┤
│ Growing segment   │ ← new data, TurboQuant compressed
│ (uniform kernel)  │
└──────────────────┘
```

Each slab dispatches its own dequantization kernel. No branching. No divergence.

### Metal Kernel Reference (from MLX)

Key MLX kernel patterns to reference:
- `QuantizedBlockLoader`: template-specialized per bit-width at compile time
- `qvm_split_k`: quantized vector-matrix multiply with split-K reduction
- `qmv_quad`: 4-element vectorized quantized matvec

Metal threadgroup memory loads: 128-bit (16-byte) granularity.

For Rust + metal-rs:
```rust
// Zero-copy UMA buffer creation
let buffer = device.new_buffer_with_data(
    data.as_ptr() as *const _,
    data.len() as u64,
    MTLResourceOptions::StorageModeShared, // UMA — no copy!
);
```

---

## 4. Concurrency Model — Complete Specification

### Epoch-Based Reclamation (crossbeam-epoch)

```rust
use crossbeam_epoch::{self as epoch, Atomic, Owned, Shared};

pub struct RotationState {
    rotation: Atomic<ButterflyRotation>,
    codebook: Atomic<Codebook>,
}

impl RotationState {
    pub fn read(&self) -> (&ButterflyRotation, &Codebook) {
        let guard = epoch::pin();
        let rot = self.rotation.load(Ordering::Acquire, &guard);
        let cb = self.codebook.load(Ordering::Acquire, &guard);
        unsafe { (rot.deref(), cb.deref()) }
    }

    pub fn swap(&self, new_rot: ButterflyRotation, new_cb: Codebook) {
        let guard = epoch::pin();
        let old_rot = self.rotation.swap(
            Owned::new(new_rot), Ordering::AcqRel, &guard
        );
        let old_cb = self.codebook.swap(
            Owned::new(new_cb), Ordering::AcqRel, &guard
        );
        // Old versions freed after all readers advance past this epoch
        unsafe {
            guard.defer_destroy(old_rot);
            guard.defer_destroy(old_cb);
        }
    }
}
```

### Segment-Level MVCC

```rust
pub struct SegmentManager {
    sealed: Vec<Arc<SealedSegment>>,    // immutable, versioned
    growing: RwLock<GrowingSegment>,     // mutable, single writer
    version_map: AtomicU64,              // monotonically increasing
}

pub struct SealedSegment {
    vectors: MmapBuffer,
    rotation_version: u64,
    precision: BitWidth,
    access_temperature: AtomicU32,       // read-temperature tracking
}

impl SegmentManager {
    pub async fn query(&self, q: &[f32], k: usize) -> Vec<SearchResult> {
        let current_version = self.version_map.load(Ordering::Acquire);
        let mut results = Vec::new();

        // Query each sealed segment with appropriate inverse rotation
        for seg in &self.sealed {
            let inv_rot = self.get_rotation(seg.rotation_version);
            let seg_results = seg.search(q, k, &inv_rot);
            seg.access_temperature.fetch_add(1, Ordering::Relaxed);
            results.extend(seg_results);
        }

        // Query growing segment (TurboQuant compressed)
        let growing = self.growing.read().await;
        results.extend(growing.search(q, k));

        // Merge and rank
        results.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap());
        results.truncate(k);
        results
    }
}
```

### Read-Temperature Scheduling

```rust
pub async fn background_reencoding_loop(&self) {
    loop {
        // Sort segments by access temperature (hot first)
        let mut segments: Vec<_> = self.sealed.iter()
            .filter(|s| s.rotation_version < self.current_rotation_version())
            .collect();
        segments.sort_by_key(|s|
            std::cmp::Reverse(s.access_temperature.load(Ordering::Relaxed))
        );

        for seg in segments {
            self.reencode_segment(seg).await;
            tokio::task::yield_now().await;
        }

        tokio::time::sleep(Duration::from_secs(30)).await;
    }
}
```

---

## 5. Meta-Memory Retrieval (MMR) Implementation

### Data Structure

```rust
pub struct MetaMemoryIndex {
    // TurboQuant-compressed retrieval pattern history
    patterns: Vec<CompressedPattern>,
    lloyd_max_codebook: Codebook,       // precomputed, static
    random_rotation: OrthogonalMatrix,   // data-oblivious
}

pub struct CompressedPattern {
    query_hash: u64,                     // locality-sensitive hash of query
    accessed_vectors: BitVec,            // which vectors were accessed
    attention_distribution: [u8; 32],    // compressed attention pattern
    engagement_signal: u8,               // did user engage with results?
    timestamp: u32,                      // compact timestamp
}
```

### Predictive Pre-Staging

```rust
impl MetaMemoryIndex {
    pub fn predict_needed_vectors(&self, query: &[f32], top_k: usize) -> Vec<VectorId> {
        // 1. TurboQuant-compress the query for meta-index search
        let rotated = self.random_rotation.apply(query);
        let compressed = turbo_quant::compress(&rotated, &self.lloyd_max_codebook);

        // 2. Find similar historical retrieval patterns
        let similar_patterns = self.ann_search(&compressed, 10);

        // 3. Aggregate accessed vectors weighted by engagement
        let mut vector_scores: HashMap<VectorId, f32> = HashMap::new();
        for pattern in similar_patterns {
            let weight = pattern.engagement_signal as f32 / 255.0;
            for vid in pattern.accessed_vectors.iter_ones() {
                *vector_scores.entry(vid).or_default() += weight;
            }
        }

        // 4. Return top-k predicted vectors for pre-staging
        let mut predictions: Vec<_> = vector_scores.into_iter().collect();
        predictions.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
        predictions.into_iter().take(top_k).map(|(id, _)| id).collect()
    }
}
```

---

## 6. Apple Silicon Optimization Notes

### Memory Budget Planning (M2 Pro, 16GB)

| Component | Size | Notes |
|-----------|------|-------|
| macOS + apps | ~4GB | System overhead |
| GPU VRAM allocation | ~12GB | 75% default, adjustable via `sysctl iogpu.wired_limit_mb` |
| 7B Q4 model weights | ~3.5GB | In GPU VRAM via UMA |
| KV cache (2K context, FP16) | ~500MB | Grows with context |
| Vector index (1M, 4-bit avg) | ~64MB | Stateful Rotor primary |
| Meta-memory index (1M, 2-bit) | ~32MB | MMR predictive layer |
| **Remaining** | **~3.9GB** | Room for growth |

### Critical Profiling Findings (Benazir & Lin, Aug 2025)

- **Crossover point on M2 Pro:** dequantization overhead exceeds bandwidth savings at batch_size ≈ 32
- **Implication:** For prefill (batch), prefer FP16 or Q8. For decode (single query), prefer Q4 or Q2.
- **Strategy:** Minimize dequantization path heterogeneity. Use only 2-bit and 4-bit (not spanning 1–8 bit) for best Metal ALU utilization.

### AMX Exploitation

- 2 AMX units on M2 Pro, 32×32 compute grids
- Access via Accelerate framework BLAS routines (transparent)
- Use for: CPU-side rotation matrix application, codebook lookups
- Reference: Zhou MIT CSAIL thesis (Sep 2025) — in-place GEMM outperforming Accelerate

### Metal GPU Patterns

- Template-specialize kernels per bit-width at compile time (MLX pattern)
- Threadgroup memory loads: 128-bit (16-byte) granularity
- Use `MTLResourceOptions::StorageModeShared` for zero-copy UMA buffers
- Reference implementations: herbert-rs (hand-written Metal shaders), bitnet-metal (AMX integration)

---

## 7. Swift 6 FFI Bridge Pattern

```swift
// Swift side — strict concurrency safe
@MainActor
final class EpistemosEngine: Sendable {
    private let rustHandle: UnsafeMutableRawPointer

    init() throws {
        rustHandle = epistemos_engine_create()
    }

    func search(query: String, topK: Int = 10) async throws -> [SearchResult] {
        try await withCheckedThrowingContinuation { continuation in
            epistemos_search_async(
                rustHandle,
                query.utf8CString,
                Int32(topK),
                { resultsPtr, count, error in
                    if let error { continuation.resume(throwing: FFIError(error)) }
                    else { continuation.resume(returning: SearchResult.from(resultsPtr, count)) }
                }
            )
        }
    }

    func ingest(text: String, metadata: [String: String]) async throws -> VectorId {
        // ... similar async FFI pattern
    }

    deinit { epistemos_engine_destroy(rustHandle) }
}
```

```rust
// Rust FFI exports
#[no_mangle]
pub extern "C" fn epistemos_engine_create() -> *mut c_void {
    let engine = Box::new(EpistemosEngine::new());
    Box::into_raw(engine) as *mut c_void
}

#[no_mangle]
pub extern "C" fn epistemos_search_async(
    handle: *mut c_void,
    query: *const c_char,
    top_k: i32,
    callback: extern "C" fn(*const SearchResultFFI, i32, *const c_char),
) {
    let engine = unsafe { &*(handle as *const EpistemosEngine) };
    let query = unsafe { CStr::from_ptr(query) }.to_str().unwrap();

    engine.runtime.spawn(async move {
        match engine.search(query, top_k as usize).await {
            Ok(results) => callback(results.as_ptr(), results.len() as i32, std::ptr::null()),
            Err(e) => callback(std::ptr::null(), 0, CString::new(e.to_string()).unwrap().as_ptr()),
        }
    });
}
```

---

## 8. Build Best Practices

### Crate Dependencies (Cargo.toml essentials)

**CRITICAL: metal-rs is OFFICIALLY DEPRECATED.** Use `objc2-metal` instead (part of the `objc2` project by madsmtm). Full Metal API coverage with proper safety semantics.

```toml
[dependencies]
# FFI
uniffi = "0.29"              # proc-macro approach, NOT UDL files
# Metal (NOT metal-rs — deprecated!)
objc2-metal = "0.3"          # full Metal API: MTLBuffer, MTLTexture, MTLComputePipelineState
objc2 = "0.6"                # Objective-C runtime bindings
# Database
rusqlite = { version = "0.31", features = ["bundled"] }  # SQLite
tantivy = "0.25.0"           # FTS engine (2x Lucene, 6.5x Elasticsearch)
# Async & Concurrency
tokio = { version = "1", features = ["full"] }
crossbeam-epoch = "0.9"      # lock-free epoch reclamation
crossbeam-utils = "0.8"
parking_lot = "0.12"         # faster Mutex/RwLock than std
# Memory & Performance
mimalloc = { version = "0.1", default-features = false }  # global allocator (excellent on UMA)
half = "2.3"                 # f16 support
bitvec = "1"
rayon = "1.8"                # parallel iterators for batch ops
memmap2 = "0.9"              # memory-mapped I/O
# Serialization & Logging
serde = { version = "1", features = ["derive"] }
bincode = "1"                # high-performance serialization
tracing = "0.1"              # structured logging

[profile.release]
opt-level = 3
lto = "fat"
codegen-units = 1

[build]
# Apply to ALL Apple Silicon generations
rustflags = ["-C", "target-cpu=apple-m1"]
```

### Swift-Side Dependencies

```
// Package.swift or SPM
GRDB v7.10.0       // SQLite with extension loading (critical for sqlite-vec)
MLXSwift            // In-process MLX inference
mlx-swift-structured // Constrained JSON decoding (MacPaw)
```

### FFI Strategy (Critical Decision)

**Default path:** UniFFI v0.29.x proc-macros for all non-performance-critical FFI.
- Known limitations: async doesn't fully conform to Swift 6 `Sendable` (issue #2448)
- Mitigation: `@preconcurrency import` for UniFFI modules
- Design pattern: COARSE-GRAINED ops (`search(query, filters, limit) → [Result]`), NOT chatty APIs

**Performance-critical path:** Manual C FFI for Metal buffer sharing.
- Zero-copy UMA: Swift creates MTLBuffer(.storageModeShared) → extracts contents() pointer → passes to Rust via FFI → Rust wraps as &mut [u8] → processes in-place
- Use swift-bridge v0.1.36 for zero-copy design if C FFI too raw

**1Password architecture model:** Rust core → "invocation" pattern → Swift sends serialized requests through channels → Rust processes on tokio → calls back with results. Use `typeshare` crate to generate matching Swift types from Rust structs.

### Performance Targets

| Operation | Target Latency | Notes |
|-----------|---------------|-------|
| Single vector search (1M index) | <5ms | Including MMR pre-staging |
| Vector ingestion | <1ms | TurboQuant immediate |
| Background rotation update (1K vectors) | <100ms | Yield-aware, non-blocking |
| Progressive downgrade (1K vectors) | <50ms | Integer shift operations |
| Rotation matrix swap | <1μs | Atomic pointer swap |
| Full re-encoding (1M vectors) | <60s | Background, segment-by-segment |

---

## 9. Hybrid Search Pipeline — Complete Specification

### Architecture

```
Query
  │
  ├── [Parallel] tantivy BM25 → top-100
  ├── [Parallel] Stateful Rotor vector search → top-100
  └── [Parallel] Entity extraction → SQLite graph traversal → related chunks
  │
  ▼
Reciprocal Rank Fusion: score(d) = Σ 1/(60 + rank_r(d))
  │  weighted 0.5 FTS / 0.5 vector
  ▼
Cross-encoder reranking (ms-marco-MiniLM-L-6-v2, 22MB) → top-50 → top-10
  │
  ▼
Parent document expansion: indexed at 200-400 tokens, returned at 1,000-2,000 tokens
```

### Latency Targets

| Stage | Target | Engine |
|-------|--------|--------|
| Embedding generation | <20ms | nomic-embed-text v1.5 (ONNX Runtime, CPU) |
| FTS query | <2ms | tantivy (Rust, NEON-accelerated) |
| Vector search (100K) | <10ms | Stateful Rotor (quantized) |
| Vector search (500K+) | <10ms | USearch HNSW or LanceDB supplement |
| RRF fusion | <1ms | Rust, in-memory |
| Cross-encoder rerank | <20ms | ms-marco-MiniLM-L-6-v2 |
| **Total pipeline** | **<50ms** | |

### Contextual Retrieval (Index-Time)

**Single highest-impact innovation.** At index time, for each chunk:
1. Call local 4B router model with full document context
2. Generate 50-100 token situating prefix: "This chunk discusses X in the context of Y document about Z"
3. Prepend prefix to chunk before embedding
4. Reduces retrieval failures by 67% when combined with hybrid search + reranking

### Embedding Strategy

- Model: nomic-embed-text v1.5 (137M params, outperforms OpenAI ada-002)
- Generate at 768 dimensions
- Store at 384 dimensions (Matryoshka truncation, 67% savings, <2% quality drop)
- Use 128 dimensions for initial shortlisting if needed
- Runs on CPU via ONNX Runtime (~300MB resident)

### Knowledge Graph (Lightweight)

```sql
-- SQLite schema
CREATE TABLE entities (id INTEGER PRIMARY KEY, name TEXT, type TEXT, chunk_id INTEGER);
CREATE TABLE relationships (src_id INTEGER, dst_id INTEGER, relation TEXT);
CREATE INDEX idx_entity_name ON entities(name);

-- Traversal via recursive CTE
WITH RECURSIVE related AS (
    SELECT dst_id, 1 AS depth FROM relationships WHERE src_id = ?
    UNION ALL
    SELECT r.dst_id, related.depth + 1
    FROM relationships r JOIN related ON r.src_id = related.dst_id
    WHERE related.depth < 3
)
SELECT DISTINCT chunk_id FROM entities WHERE id IN (SELECT dst_id FROM related);
```

---

## 10. Multi-Model Inference Orchestration

### Memory Residency Hierarchy (M2 Pro, 16GB)

| Component | Memory | Policy |
|-----------|--------|--------|
| macOS + App UI | ~4GB | Always resident |
| Qwen 3 4B Router (4-bit, in-process MLX-Swift) | ~3GB | **Pinned hot** — every interaction gateway |
| nomic-embed-text v1.5 (ONNX Runtime) | ~0.3GB | Resident — continuous embedding |
| KV cache budget | ~2-3GB | Managed via rotating 4K window |
| DeepSeek-R1-Distill-8B Reasoner (sidecar) | ~5-6GB | Cold-loaded with TTL eviction |

### Router Design (Critical)

```swift
// Router output schema — constrained JSON via mlx-swift-structured
struct RouterOutput: Codable {
    let intent: Intent          // .search, .reason, .create, .chat, .summarize
    let reasoningDepth: Depth   // .shallow, .moderate, .deep
    // NEVER outputs target_model — orchestrator decides based on memory snapshot
}

// Orchestrator logic
func route(_ query: String) async throws -> Response {
    let routerOutput = try await router.generate(query, schema: RouterOutput.self)

    switch routerOutput.reasoningDepth {
    case .shallow:
        return try await router.respond(query, context: retrievedChunks)
    case .moderate:
        return try await router.respond(query, context: retrievedChunks)
    case .deep:
        if memoryAvailable(for: .reasoner) {
            return try await loadAndRunReasoner(query, context: retrievedChunks)
        } else if userOptedInToCloud {
            return try await cloudFallback(query, context: retrievedChunks)
        } else {
            return try await router.respond(query, context: retrievedChunks, extended: true)
        }
    }
}
```

### Key Constraints

- **RAG > long context** on 16GB. Retrieve top-12 chunks, fit in 2-4K context. Context >8K causes throughput collapse.
- **Speculative decoding NOT recommended** for 8B main models on 16GB. Draft model overhead outweighs benefits at this scale.
- **Keep context ≤4-8K tokens** for interactive speed (45-58 tok/s on MLX).

---

## 11. Product Architecture — Composable Primitives

### Progressive Depth Ladder

| Timeline | Layer | What Unlocks |
|----------|-------|-------------|
| Day 1 | Simple notes | Create, write, save, markdown |
| Week 1 | Linked notes | `[[backlinks]]`, backlinks panel, basic search |
| Month 1 | Graph exploration | Visual knowledge graph, clusters, orphan detection |
| Month 2-3 | Custom queries | Dataview-style querying, dynamic dashboards, templates |
| Month 3-6 | Automation | Dynamic templates, periodic notes, web clipping |
| Month 6+ | AI-augmented research | Semantic search, AI connections, synthesis, gap detection |

### Command Palette (Most Important UX Primitive)

- Available everywhere via single shortcut (⌘K or ⌘P)
- Centralizes ALL commands — never split across multiple palettes
- Fuzzy matching + synonyms
- Keyboard shortcuts displayed next to every item
- Every UI action is also a palette command

### AI Interaction Pattern

Default: **ExtendAI** (user reasons first, AI augments) — NOT RecommendAI (AI decides).
Epistemos AI is a Socratic interlocutor: surfaces connections, asks "did you consider...?", finds reasoning gaps.

---

## 12. Research Paper Quick-Reference

**Must-re-read before each session (big-picture restorers):**
1. `vector quant.md` — Full 50+ paper synthesis, all math formulations
2. `Cognitive Exoskeleton Research Blueprint 3.docx` — Stateful Rotor architecture spec
3. This document — Implementation patterns and code templates

**Rotation papers:** SpinQuant, ButterflyQuant, FlatQuant, WUSH, RotorQuant
**KV cache papers:** KVTuner, PM-KVQ, ThinKV, Kitty, MixKVQ
**Concurrency papers:** crossbeam-epoch docs, Milvus MVCC, Ada-IVF, SPFresh, Quake
**Apple Silicon papers:** Benazir & Lin profiling, Zhou MIT AMX thesis, MLX benchmarks
**Meta-Memory foundation:** TurboQuant, QINCo2, CoDEQ
