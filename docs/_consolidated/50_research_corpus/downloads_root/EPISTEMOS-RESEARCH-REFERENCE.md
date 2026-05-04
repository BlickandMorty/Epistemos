# Epistemos Research Reference — Complete Knowledge Base

**This document preserves ALL research for Claude to re-read at session start.**

---

## 1. Product Strategy Intelligence

### What separates billion-dollar tools from $10M tools

**Speed as identity.** Linear: $35K total marketing → $1.25B valuation. Profitable since 2021 (~$100M revenue). The speed delta vs Jira is visceral — users become evangelists. Raycast: sub-100ms launcher. Cursor: $0 marketing → $500M ARR by May 2025, fastest SaaS ever, 36% free-to-paid (industry avg: 2-5%).

**Extensibility as moat.** Obsidian: 2,700+ plugins, 18-person bootstrapped team. Raycast: 1,500+ extensions. Roam: zero extensibility → stagnation. Platforms beat features. Notion ($100B) built composable blocks. Roam (~$200M, stalled) built bidirectional linking.

**PLG purity.** If product is transcendent, marketing is unnecessary. Cursor proves this definitively.

**Multiplayer gate.** Must come AFTER single-player is transcendent. Notion: collab as core DNA → $100B.

**AI as core, not feature.** Cursor = AI-native → unprecedented growth. Timing a paradigm shift is everything.

**Counter-model:** DevonThink — 23 years, ~6 employees, zero VC, $99-$199 one-time. Proves sustainable business without unicorn status.

### Go-to-Market

- Target: PhD researchers + ML/AI engineers first
- Price: Free tier → $79/yr Pro → $9/mo → $199 Lifetime → $39/yr Education
- Distribution: OUTSIDE Mac App Store (avoid 30% + sandboxing). Lemon Squeezy for payments. Sparkle 2 for updates. DMG format.
- Launch: Tuesday-Thursday window — Product Hunt, HN Show HN, Twitter/X thread, r/macapps, Indie Hackers
- Community: Discord primary, GitHub Discussions, blog
- Critical integration: Zotero (BibTeX, PDF annotation import)
- Plugin ecosystem from day one — Obsidian's moat

---

## 2. Academic Research (CHI 2025 + Frontiers)

### AI + Cognition Findings

- CHI 2025 "Tools for Thought" Workshop (MS Research, Harvard, CMU, Stanford): 56 researchers, 34 papers
- **Key finding:** Users self-report REDUCED critical thinking with generative AI. Confidence in AI inversely related to critical engagement.
- **Design pattern:** ExtendAI (user reasons first, AI augments) > RecommendAI (AI decides). Validated in controlled experiments at Microsoft.
- **Implication:** Epistemos defaults to Socratic interlocution, not answer generation.

### Ready-for-Production Innovations

- **NoTeeline** (Sep 2024): LLM-enhanced micronotes, 93.2% factual correctness, 47% less text written
- **LECTOR** (2025): LLM-assessed semantic similarity for spaced repetition, 90.2% success rate
- **Zettelkasten + spaced repetition**: First controlled validation (HSE University 2024) shows significant learning improvement
- **GraphRAG** (Microsoft): 72-83% comprehensiveness vs traditional RAG, 3.4x accuracy

### Emerging Tools to Watch

- Tana: supertag system (typed objects + AI auto-classification)
- Heptabase: spatial whiteboards
- Mem 2.0: zero-friction capture + agentic AI
- Google NotebookLM: AI-as-synthesis-partner, Audio Overview

---

## 3. Rust FFI on Apple Silicon

### Critical: metal-rs is DEPRECATED → use `objc2-metal`

### UniFFI v0.29.x

- Proc-macros recommended over UDL files
- Async doesn't fully conform to Swift 6 `Sendable` (issue #2448)
- `async_runtime="tokio"` broken on trait async methods (issue #2576)
- No built-in cancellation support
- Serialization overhead: `Record` types cross via binary serialization
- **Mitigation:** Batching/command pattern — coarse-grained ops, not chatty APIs

### Zero-Copy UMA Pattern

1. Swift creates `MTLBuffer` with `.storageModeShared`
2. Swift extracts `contents()` pointer
3. Pointer + length passed to Rust via C FFI
4. Rust wraps as `&mut [u8]` slice, processes in-place
5. Zero copies — CPU and GPU share same physical memory

### 1Password Architecture Model

Rust core → all business logic, crypto, database. Thin native UI (SwiftUI) → "invocation" pattern. Swift sends serialized requests through channels → Rust processes on tokio → calls back. `typeshare` crate generates matching Swift types.

### Swift 6 Concurrency Mapping

- Swift `Sendable` on value types → Rust `Send`
- Swift `Sendable` on reference types → Rust `Sync`
- Wrap mutable state in `Arc<RwLock<T>>`
- Use `@preconcurrency import` for UniFFI modules

### Battle-Tested Crate Stack

`uniffi 0.29` · `objc2-metal` · `rusqlite 0.31+` · `tantivy 0.25.0` · `tokio 1.x` · `crossbeam 0.8+` · `parking_lot 0.12+` · `mimalloc` · `serde + bincode` · `tracing`

Compile: `target-cpu=apple-m1`, `opt-level=3`, `lto="fat"`, `codegen-units=1`

### Swift-Side

GRDB v7.10.0 (Feb 2026): supports loading SQLite extensions → critical for sqlite-vec.
Hybrid search: tantivy in Rust (UniFFI async) + sqlite-vec via GRDB in Swift + RRF in Rust.

---

## 4. Local Inference Architecture

### MLX vs llama.cpp

MLX outperforms by 20-30% on Apple Silicon. M2 Pro 16GB: Qwen 8B Q4_K_M = 45-58 tok/s (MLX) vs 38-48 (llama.cpp). Ollama 0.19 now MLX-powered on Apple Silicon.

### Memory Residency Hierarchy (16GB)

| Component | Memory | Policy |
|-----------|--------|--------|
| macOS + UI | ~4GB | Always |
| Qwen 3 4B Router (4-bit, MLX-Swift) | ~3GB | Pinned hot |
| nomic-embed-text v1.5 (ONNX) | ~0.3GB | Resident |
| KV cache | ~2-3GB | Rotating 4K window |
| DeepSeek-R1-8B Reasoner | ~5-6GB | Cold-loaded, TTL eviction |

### Critical Design Decisions

- Router outputs intent + reasoning_depth, NOT target_model. Orchestrator routes based on memory snapshot.
- Use `mlx-swift-structured` (MacPaw) for constrained JSON decoding.
- Speculative decoding NOT recommended at this scale (decreases speed from 38 to 33.9 tok/s).
- RAG > long context. Top-12 chunks in 2-4K context. Keep ≤4-8K tokens.
- nomic-embed-text v1.5: 137M params, 768-dim (store at 384 via Matryoshka), outperforms ada-002, 8192 token context.
- Audio: FluidAudio CoreML, 0.19s via Neural Engine.

---

## 5. Search Architecture

### Four Retrieval Signals

1. **tantivy FTS**: BM25, ~2x Lucene, sub-ms latency, NEON-accelerated
2. **Vector search**: Stateful Rotor primary. sqlite-vec for <100K (68ms brute-force, 3.97ms quantized). USearch or LanceDB for >500K.
3. **Knowledge graph**: NER → SQLite entities + relationships → recursive CTE traversal
4. **Cross-encoder reranking**: ms-marco-MiniLM-L-6-v2 (22MB), top-50 → top-10

### Fusion

RRF: `score(d) = Σ 1/(60 + rank_r(d))`, weighted 0.5 FTS / 0.5 vector.

### Contextual Retrieval

At index time: LLM generates 50-100 token situating prefix per chunk before embedding. Reduces retrieval failures by 67%.

### Latency Budget

Embedding <20ms + FTS <2ms + vector <10ms + RRF <1ms + reranking <20ms = **<50ms total**

### Embedding Dimensions (Matryoshka)

Generate 768 → store 384 (67% savings, <2% quality drop) → shortlist at 128 if needed.

---

## 6. UX Design Patterns

### Progressive Depth Ladder

Day 1: notes → Week 1: links → Month 1: graph → Month 2-3: queries → Month 3-6: automation → Month 6+: AI research

### Command Palette (Most Important Primitive)

Single shortcut, ALL commands, fuzzy matching, synonyms, keyboard shortcuts displayed. Every UI action = palette command.

### Flow Channel

Staircase learning curve: quick payoff → plateau → "aha moment" → new plateau → repeat.
Multiple entry points: visual handles (beginners) + keyboard shortcuts (experts). Never remove either.

### AI Interaction: ExtendAI Pattern

User reasons first, AI augments. Socratic interlocutor, not answer machine. Surface connections, ask "did you consider...?", find gaps.

---

## 7. Quantization Research (Summary of 50+ Papers)

### Rotation Evolution

OPQ (2014) → QuIP (NeurIPS 2023) → QuIP# (ICML 2024) → QuaRot (NeurIPS 2024) → **SpinQuant** (ICLR 2025) → OSTQuant (ICLR 2025) → **FlatQuant** (ICML 2025) → **ButterflyQuant** (Sep 2025) → WUSH (Nov 2025) → RotorQuant (Mar 2026)

**Key formulations:**
- SpinQuant Cayley SGD: `R(t+1) = R(t) · exp(η · A)`, A skew-symmetric
- ButterflyQuant: O(d log d), (d log d)/2 learnable Givens angles, 15.4 PPL at 2-bit
- FlatQuant: Kronecker-decomposed affine transforms, <1% gap from FP16
- WUSH: Closed-form optimal blockwise transforms, +2.8 avg points

### KV Cache Compression

KIVI → KVQuant → ZipCache → GEAR → QServe → **KVTuner** → **PM-KVQ** → **ThinKV** → Kitty → MixKVQ

**Key formulations:**
- KVTuner MOO: `min_c [Memory(c), -Accuracy(c)]`, 3.25-bit avg nearly lossless
- PM-KVQ: `floor((2^{2b} - 2^b + 1)(X_{2b} + 2^{b-1})) >> 3b`
- ThinKV: thought-adaptive, 3.4-bit avg with superior accuracy
- Kitty: two-tensor decomposition, uniform 2-bit base + boost tensor

### Vector Search

FAISS/OPQ → FreshDiskANN → SPFresh → **Ada-IVF** → QINCo2 → **Quake** → **TurboQuant** → CoDEQ → CRISP

**TurboQuant:** Random rotation → Beta distribution → precomputed Lloyd-Max → ~2.7× info-theoretic bound, zero indexing time

### Apple Silicon

- M2 Pro UMA: 200 GB/s shared bandwidth
- Crossover: dequantization overhead > bandwidth savings at batch_size ≈ 32
- MLX: ~230 tok/s (M2 Ultra), template-specialized kernels
- AMX: 32×32 compute grids, 2 units on M2 Pro, accessed via Accelerate BLAS
- ANE: 38 TOPS (M4) but blocked for dynamic mixed-precision (undocumented constraints)

### Concurrency

- crossbeam-epoch: lock-free rotation swaps, epoch-based reclamation
- Segment MVCC (Milvus-style): sealed + growing segments, version map
- Ada-IVF read-temperature: hot-first re-encoding, 2-5× throughput over SPFresh
- Online OPQ SVD-Updating: incremental rotation via low-rank SVD

### Open Problems

1. No formal analysis of rotation-quantization freshness interaction during concurrent updates
2. No fully fused Metal kernel for dequantize→scale→rotate→accumulate
3. ANE blocked for dynamic mixed-precision workloads

---

*This document is the complete research foundation for Epistemos. Claude should re-read relevant sections at the start of every session to maintain architectural coherence.*
