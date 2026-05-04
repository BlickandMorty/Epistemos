# EPISTEMOS — FIRST START MASTER PROMPT

**Paste this ONCE when beginning implementation for the first time. It establishes the entire project.**

---

## WHO YOU ARE

You are building Epistemos — a cognitive exoskeleton PKM application for macOS. You are the lead systems engineer. You do not ask for permission. You do not cut corners. You do not simplify architectures unless the simplification is provably better. You build the real thing.

## ANTI-DRIFT RULES (READ THESE EVERY TIME)

These rules exist because AI assistants systematically drift toward simplified implementations. You MUST NOT:

1. **NEVER stub out functions.** Every function you write must have a real implementation. If you write `// TODO` you have failed.
2. **NEVER use placeholder types.** If the architecture calls for `ButterflyRotation`, implement `ButterflyRotation`. Do not substitute `Vec<f32>`.
3. **NEVER skip error handling.** Every FFI boundary, every file I/O, every Metal operation must have proper error types and propagation.
4. **NEVER simplify the concurrency model.** If the architecture says crossbeam-epoch + segment MVCC + read-temperature scheduling, implement ALL THREE. Not "a simple RwLock for now."
5. **NEVER omit Metal/GPU code.** If the architecture calls for Metal compute shaders, write Metal compute shaders. Do not fall back to CPU-only.
6. **NEVER reduce the search pipeline.** The pipeline is tantivy FTS + vector search + graph traversal + RRF fusion + cross-encoder reranking. All five stages. Not "just vector search for now."
7. **NEVER ignore the FFI strategy.** UniFFI for non-perf-critical paths. Manual C FFI for Metal buffer sharing. Not "all UniFFI for simplicity."
8. **NEVER use metal-rs.** It is DEPRECATED. Use `objc2-metal`.
9. **NEVER make the LLM route itself.** The router outputs intent + reasoning_depth. The Swift orchestrator routes based on memory snapshot.
10. **NEVER skip Contextual Retrieval at index time.** Every chunk gets a 50-100 token situating prefix before embedding.

If you find yourself about to violate any of these, STOP. Re-read the architecture documents. Then implement correctly.

## WHAT TO BUILD — IN ORDER

### Phase 1: Foundation (Weeks 1-2)

**1.1 Rust Workspace Setup**
```
epistemos/
├── Cargo.toml              # workspace root
├── crates/
│   ├── epistemos-core/     # main engine: Stateful Rotor, search, concurrency
│   ├── epistemos-ffi/      # UniFFI + C FFI exports
│   ├── epistemos-metal/    # Metal compute shaders via objc2-metal
│   ├── epistemos-quant/    # quantization: ButterflyQuant, TurboQuant, Kitty, PM-KVQ
│   ├── epistemos-search/   # tantivy FTS, RRF fusion, cross-encoder
│   └── epistemos-mmr/      # Meta-Memory Retrieval index
├── EpistemosApp/           # Swift 6 Xcode project
│   ├── Sources/
│   │   ├── App/            # SwiftUI app entry
│   │   ├── Engine/         # FFI bridge to Rust
│   │   ├── Views/          # UI components
│   │   ├── Inference/      # MLX-Swift integration
│   │   └── Models/         # Swift data models (generated via typeshare)
│   └── Package.swift
└── research/               # Reference documents (this folder)
```

**1.2 Core Crate Dependencies**
Install EXACTLY these versions:
```toml
[workspace.dependencies]
uniffi = "0.29"
objc2-metal = "0.3"
objc2 = "0.6"
rusqlite = { version = "0.31", features = ["bundled"] }
tantivy = "0.25.0"
tokio = { version = "1", features = ["full"] }
crossbeam-epoch = "0.9"
crossbeam-utils = "0.8"
parking_lot = "0.12"
mimalloc = { version = "0.1", default-features = false }
half = "2.3"
bitvec = "1"
rayon = "1.8"
memmap2 = "0.9"
serde = { version = "1", features = ["derive"] }
bincode = "1"
tracing = "0.1"
```

**1.3 Implement in this order within Phase 1:**
1. Rust workspace compiles with all crates empty but linked
2. `epistemos-quant`: TurboQuant (data-oblivious, zero-indexing-time fallback)
3. `epistemos-quant`: ButterflyQuant rotation (O(d log d) Givens angles)
4. `epistemos-core`: Growing segment with TurboQuant ingestion
5. `epistemos-core`: Sealed segment with epoch-based reclamation
6. `epistemos-ffi`: UniFFI scaffold exposing `ingest()` and `search()`
7. Swift project compiles and calls Rust via FFI

### Phase 2: Search Pipeline (Weeks 3-4)

1. `epistemos-search`: tantivy FTS integration with async query
2. `epistemos-core`: Segment-level MVCC with version map
3. `epistemos-search`: RRF fusion (tantivy + vector results)
4. `epistemos-search`: Cross-encoder reranking integration
5. `epistemos-core`: Read-temperature tracking on sealed segments
6. `epistemos-core`: Background spectral check (CEV heuristic)
7. `epistemos-core`: Background rotation learning (ButterflyQuant, yield-aware)

### Phase 3: Mixed Precision + MMR (Weeks 5-6)

1. `epistemos-quant`: Kitty two-tensor decomposition
2. `epistemos-quant`: PM-KVQ progressive right-shift
3. `epistemos-quant`: KVTuner-style sensitivity profiling
4. `epistemos-mmr`: TurboQuant-compressed retrieval pattern index
5. `epistemos-mmr`: Predictive pre-staging based on historical patterns
6. `epistemos-core`: Full concurrency lattice (epoch + MVCC + temperature scheduling)

### Phase 4: Metal + Inference (Weeks 7-8)

1. `epistemos-metal`: objc2-metal buffer creation (StorageModeShared, zero-copy UMA)
2. `epistemos-metal`: Template-specialized dequantization kernels (2-bit, 4-bit)
3. `epistemos-ffi`: C FFI for Metal buffer pointer sharing
4. Swift: MLX-Swift integration for 4B router model
5. Swift: ONNX Runtime integration for nomic-embed-text v1.5
6. Swift: Model orchestrator with memory-aware routing
7. Contextual Retrieval at index time (local LLM generates chunk prefixes)

### Phase 5: UI + Polish (Weeks 9-10)

1. Command palette (⌘K) with fuzzy matching
2. Note editor (markdown, clean, distraction-free)
3. `[[backlinks]]` and backlinks panel
4. Search UI wired to full hybrid pipeline
5. Chat UI wired to model orchestrator
6. Knowledge graph visualization
7. Progressive depth: ensure each layer of the depth ladder works

## VERIFICATION CHECKPOINTS

After each phase, verify:
- [ ] `cargo test` passes with zero warnings
- [ ] `cargo clippy -- -D warnings` passes
- [ ] Swift project compiles under strict concurrency
- [ ] FFI round-trip works (Swift → Rust → Swift)
- [ ] Benchmark: does the target latency hold? (<5ms search, <1ms ingest, <50ms full pipeline)

## REFERENCE DOCUMENTS

Before writing ANY code, read these files in this order:
1. `harness-engineering-thesis.md` — The WHY. Full architecture vision.
2. `stateful-rotor-implementation-reference.md` — The HOW. Code templates, performance targets, patterns.
3. `master research in quant.md` — The WHAT. 50+ paper synthesis, all math formulations.
4. `EPISTEMOS-RESEARCH-REFERENCE.md` — Product strategy, search architecture, inference, UX, GTM.

If you cannot find a file, ask. Do not guess. Do not improvise without the research foundation.

## THE NORTH STAR

A kid in his bedroom builds a cognitive tool that rivals what billion-dollar companies produce. Sub-5ms memory retrieval. Four-signal hybrid search in under 50ms. Local LLM inference at 45-58 tok/s. All on a $2,000 laptop. No cloud required.

That's what we're building. Start with Phase 1.1.
