# Epistemos Master Session Prompt

**Copy this into Claude Code at the start of every new session to restore full context.**

---

## SYSTEM CONTEXT

You are building **Epistemos** — a cognitive exoskeleton PKM (Personal Knowledge Management) application. It is a macOS-native app written in **Swift 6** (UI) with a **Rust** core engine connected via C-FFI. The app provides sub-5ms semantic memory retrieval, local + cloud LLM chat, and agentic AI capabilities — all running primarily on Apple Silicon (M2 Pro target).

**This is not a toy project.** This is engineered to be the most technically sophisticated PKM ever built. Every architectural decision is backed by 50+ research papers from 2024–2026. The goal is a billion-dollar tool that researchers, programmers, and knowledge workers use as a cognitive extension.

---

## BEFORE YOU WRITE ANY CODE

**Read these reference documents first** to restore big-picture context:

1. **`harness-engineering-thesis.md`** — PhD-level analysis of the full architecture, the Harness Engineering thesis, and Meta-Memory Retrieval. Covers the WHY.
2. **`stateful-rotor-implementation-reference.md`** — Fused implementation guide with code templates, performance targets, concurrency patterns, and Apple Silicon optimization notes. Covers the HOW.
3. **`vector quant.md`** (in uploads or project root) — Complete 50+ paper research synthesis covering rotation matrices, KV cache compression, Apple Silicon profiling, and async re-indexing. Covers the WHAT (research foundation).

If any of these files are not in the current directory, ask me to provide them.

---

## THE ARCHITECTURE (Quick Reference)

### Stateful Rotor Engine (Rust Core)
The vector database is a *living mathematical structure* that continuously reshapes itself:

- **Adaptive Subspace Partitioning**: CRISP-style spectral check → selective learned rotation (ButterflyQuant O(d log d)) only on correlated clusters
- **Progressive Mixed-Precision Quantization**: KVTuner MOO + PM-KVQ right-shift + ThinKV thought-adaptive → semantic gravity controller
- **Kitty Two-Tensor Decomposition**: Mixed-precision vectors decomposed into uniform-bitwidth tensors for Metal SIMD compatibility
- **Meta-Memory Retrieval (MMR)**: TurboQuant-compressed index of retrieval patterns for predictive pre-staging
- **Concurrency Lattice**: crossbeam-epoch (lock-free rotation swaps) + segment MVCC (progressive re-encoding) + read-temperature scheduling (Ada-IVF-style hot-first)

### Swift 6 UI Layer
- Strict concurrency (`@MainActor`, `Sendable`)
- Thin FFI bridge to Rust engine via `extern "C"` functions
- Native macOS — not Electron, not web views

### Inference Engine
- Local: MLX or metal-rs with hand-written Metal compute shaders
- Cloud: Optional, user-opt-in only, for tasks exceeding local capacity
- Agentic layer: Autonomous agents that traverse knowledge base, find gaps, propose syntheses

---

## KEY MATHEMATICAL FORMULATIONS

**Cayley SGD (rotation learning):** `R(t+1) = R(t) · exp(η · A)`, A skew-symmetric
**ButterflyQuant:** O(d log d) via Givens angles, (d log d)/2 parameters
**PM-KVQ Right Shift:** `floor((2^{2b} - 2^b + 1)(X_{2b} + 2^{b-1})) >> 3b`
**KVTuner MOO:** `min_c [Memory(c), -Accuracy(c)]`
**TurboQuant:** Random rotation → Beta distribution → precomputed Lloyd-Max quantizer, ~2.7× info-theoretic bound
**MMR Unbiased Estimator:** `<y, x̃> = <y, Q⁻¹(Q(x))> + ||r||₂ · <y, QJL(r)>`

---

## PERFORMANCE TARGETS

| Operation | Target | Priority |
|-----------|--------|----------|
| Single vector search (1M index) | <5ms | P0 |
| Vector ingestion | <1ms | P0 |
| Rotation matrix swap | <1μs | P0 |
| Background rotation update (1K vecs) | <100ms | P1 |
| Progressive downgrade (1K vecs) | <50ms | P1 |
| Full re-encoding (1M vecs) | <60s | P2 |

---

## MEMORY BUDGET (M2 Pro, 16GB)

- System overhead: ~4GB
- 7B Q4 model weights: ~3.5GB
- KV cache (2K context, FP16): ~500MB
- Vector index (1M, 4-bit avg): ~64MB
- Meta-memory index (1M, 2-bit): ~32MB
- **Remaining: ~3.9GB for growth**

---

## CRITICAL IMPLEMENTATION RULES

1. **Rust owns all data.** Swift borrows through FFI. Never duplicate state.
2. **Lock-free reads always.** Use crossbeam-epoch for all shared mutable state.
3. **Yield-aware background tasks.** Every heavy operation must yield after processing small chunks.
4. **Slab-based memory layout.** Group same-bitwidth vectors into contiguous slabs. Dispatch uniform kernels per slab.
5. **Two-tensor decomposition for mixed precision.** Never pass heterogeneous bitwidths through a single SIMD kernel.
6. **TurboQuant fallback for all new data.** Every vector must be immediately searchable upon ingestion.
7. **Metal StorageModeShared for UMA.** Zero-copy buffer creation. No unnecessary copies between CPU and GPU.
8. **Minimize dequantization heterogeneity.** Prefer {2-bit, 4-bit} over spanning {1-8 bit} for Metal ALU utilization.
9. **Profile before optimizing.** Dequantization overhead can negate bandwidth savings at batch_size > 32 on M2 Pro.
10. **Privacy first.** Local by default. Cloud is opt-in. No telemetry without consent.

---

## RESEARCH QUICK-REFERENCE

### Rotation Evolution
OPQ → QuIP → QuIP# → QuaRot → **SpinQuant** → OSTQuant → **FlatQuant** → **ButterflyQuant** → WUSH → RotorQuant

### KV Cache Compression
KIVI → KVQuant → ZipCache → GEAR → QServe → **KVTuner** → **PM-KVQ** → **ThinKV** → Kitty → MixKVQ

### Vector Search
FAISS/OPQ → FreshDiskANN → SPFresh → **Ada-IVF** → QINCo2 → **Quake** → **TurboQuant** → CoDEQ → CRISP

### Apple Silicon
Benazir & Lin profiling → MLX benchmarks → Zhou MIT AMX thesis → Orion ANE → metal-rs / herbert-rs / bitnet-metal

---

## THREE OPEN PROBLEMS (Be aware of these)

1. **Rotation-Quantization Freshness Interaction**: No formal analysis of concurrent rotation re-learning + precision shifting error surface interaction
2. **Metal Kernel Fusion**: No fully fused dequantize→scale→rotate→accumulate Metal kernel exists yet
3. **Neural Engine Integration**: ANE blocked for dynamic mixed-precision workloads (undocumented constraints)

---

## HOW TO USE THIS PROMPT

1. Paste this at session start
2. Read the three reference documents listed above
3. Ask me what we're working on today
4. Build with the architecture in mind — every function, every struct, every kernel should trace back to the research foundation

**The north star: a kid in his bedroom should be able to run AGI-tier cognitive tools on a laptop. That's what we're building.**
