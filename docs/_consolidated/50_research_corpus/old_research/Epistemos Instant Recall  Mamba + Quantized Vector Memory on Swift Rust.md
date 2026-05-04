# Epistemos Instant Recall: Mamba + Quantized Vector Memory on Swift/Rust

## Executive Summary

The "TurboQuant Latent Memory Index" vision described in your informant's brief is directionally sound but contains several significant technical inaccuracies that could derail your build if followed literally. This report corrects the record, validates what *is* real from the research literature, and gives you a precise, implementable architecture for instant-recall in Epistemos using Mamba-2/3, quantized vector search, and your Swift/Rust/UniFFI stack. The core idea — compressing note embeddings into tiny binary or polar-coded signatures and scanning them in milliseconds — is fully achievable on Apple Silicon. The devil is in the details.

***

## Part 1: Fact-Checking "TurboQuant"

### What PolarQuant Actually Is

PolarQuant is a real, peer-reviewed quantization method published by Google Research (arXiv 2502.02617, accepted NeurIPS 2025). It is a **KV cache quantization technique designed for Transformer attention**, not a general embedding search library. The method works by:[^1][^2]

1. Applying a random rotation matrix (Johnson-Lindenstrauss preconditioning) to key vectors, which causes the resulting polar-coordinate angles to concentrate in a predictable, analytically derivable distribution[^3]
2. Recursively transforming the preconditioned Cartesian vectors into polar coordinates — grouping pairs of coordinates, computing radii and angles at each recursion level[^3]
3. Quantizing angles with **4 bits at the first recursion level and 2 bits at all remaining levels**, resulting in ~3.5 bits per value average — *not* a flat "3 bits for angle, 1 bit for length"[^4]

The critical NeurIPS 2025 finding: **allocating fewer than 3 bits to angles causes a significant quality drop** — this is not a soft tradeoff. PolarQuant achieves 4.2x KV cache compression while maintaining downstream task quality.[^5][^4]

### What QJL Actually Is

QJL (Quantized Johnson-Lindenstrauss) is a separate, independently published research piece from the same research ecosystem. It applies a JL transform as a preconditioner and then quantizes to a **single sign bit (1-bit)** per coordinate, providing an *unbiased estimator* for inner products between query and key embeddings. This is not "error correction" — it is a probabilistic inner-product estimator. The method was validated on Llama-2 and Llama-3, achieving 3-bit effective compression (vs. 16 bits) with maintained accuracy.[^6][^7]

### The "TurboQuant" Problem

**"TurboQuant" combining PolarQuant + QJL does not exist as a named paper, codebase, or `cargo` crate.** These are two separate research contributions, both designed for KV cache in Transformer models. There is no off-the-shelf implementation, no `cargo add turbo_quant`, and no single unified formula you can paste into Rust. Your informant was correct that you will need to read the actual mathematical formulas from each paper and implement custom Rust kernels. However, applying these methods to Mamba or to a note-embedding index requires additional architectural adaptation, because SSMs do not *have* KV caches.

***

## Part 2: Mamba-2/3 — The Real Memory Architecture

### What the State Space Actually Does

Mamba-2's core innovation is its Structured State Space Duality (SSD) layer, which uses a scalar-times-identity structure on matrix **A** to allow much larger state dimensions (N=64 to N=256+) while being 2–8x faster to train than Mamba-1. At inference time, Mamba processes tokens recurrently, maintaining a **fixed-size hidden state** \( h_t \in \mathbb{R}^{P \times N} \) where P is head dimension and N is state size.[^8][^9]

This fixed-size state is both its superpower and its fundamental constraint. Unlike Transformer KV caches that grow linearly with sequence length, Mamba's state is constant regardless of input length — Mamba-2 can process up to 220,000 tokens within 24GB of memory on a single GPU, while comparably-sized Transformers hit out-of-memory errors around 73,000 tokens. This is the true architectural advantage for Epistemos.[^10][^11]

### The Memory Decay Problem (Not Mentioned in the Brief)

Your informant's framing of the SSM state as "instant RAM" is misleading in one critical way. Research has formally characterized that **early token information decays exponentially** during both intra-layer recursion and inter-layer propagation in Mamba. The update parameter \( \Delta_t \) controls this: a larger \( \Delta_t \) forgets faster and up-weights the current token; a smaller \( \Delta_t \) retains the state with minimal current-token contribution. The SSM state acts as *lossy* compressed memory, not a perfect lossless cache.[^12][^13]

This is exactly why a separate vector index is necessary — the SSM state cannot reliably "remember" a note you wrote 50,000 tokens ago. MemMamba (2025) addresses this architectural gap by augmenting Mamba with a threshold-triggered state summarization mechanism and cross-layer attention, achieving 48% inference speedup while dramatically improving long-range passkey retrieval. For Epistemos, this pattern — external vector index + SSM state injection — is the correct mental model.[^14][^15][^12]

### State Injection as Memory Seeding

There is an important, underexplored capability in Mamba: the ability to initialize or modify the SSM hidden state `ssm_state` and `conv_state` programmatically. In Transformers, this is analogous to prefix-tuning or KV cache injection. An active GitHub discussion on the official Mamba repo (Issue #101, Issue #258) confirms that "differentiable initial states is a critical feature" and that developers are actively working on state initialization APIs.[^16]

The conceptual paradigm described in the literature: "run the model over specialized data to create a state; share that state as a starting point for new inference" — this is real and is called **state swapping**. For Epistemos, this translates to: retrieve the top-k most relevant notes via the vector index, prefill a Mamba-2/3 model with those notes to encode them into an initial state, and then use that loaded state for your current writing context. This is fundamentally different from a cloud RAG pipeline — it integrates retrieval directly into the model's recurrent state.[^17]

### Mamba-3 (March 2026): Now the Better Choice

Mamba-3, released March 2026, introduces three core upgrades over Mamba-2:[^18][^13][^19]

- **Exponential-trapezoidal discretization** for more expressive recurrences
- **Complex-valued SSM states** for richer state tracking
- **MIMO (multi-input, multi-output) SSMs** that run multiple SSMs in parallel, improving accuracy without increasing decode latency

Crucially, Mamba-3 achieves "significant gains across retrieval, state-tracking, and downstream language modeling tasks" over Mamba-2, which directly addresses the memory-fidelity problem for Epistemos. It also maintains constant memory footprint and no KV cache growth, making it more practical for edge/on-device deployment.[^20][^21][^19]

***

## Part 3: The Vector Index — What Actually Works

### Binary Quantization: The Realistic "TurboQuant"

For a personal note search index, the most practical and well-documented approach is **binary quantization**, which converts float32 embeddings to 1-bit per dimension (sign of the value). This gives a 32x memory reduction and enables Hamming distance search:[^22]

- **Qdrant** reports up to 40x retrieval speed gain with binary quantization[^23]
- **Meilisearch** can fit 480 million 1024-dimension embeddings in 64GB of RAM using binary quantization[^24]
- Binary quantization achieves a **24.76x average search speedup** over float32 in documented benchmarks[^22]
- Hamming distance can be computed in approximately 2 CPU cycles per comparison[^22]

For personal note scale: 1 million notes × 1024 dimensions × 1 bit = **128 MB** — this fits comfortably in RAM and validates the "~150MB for 1M notes" claim in the brief. The sub-10ms search claim is also validated: with ARM NEON-optimized Hamming distance achieving ~350 GB/s throughput, scanning 128MB takes approximately **0.37ms**.[^25][^24][^22]

The key caveat your informant omitted: pure binary search sacrifices recall. Production systems use a **two-phase pipeline** — binary ANN search for a candidate pool (e.g., top 100), then float32 or int8 dot-product rescoring on those 100 candidates. This 2-phase approach gives you sub-millisecond first-pass search *and* high-precision final ranking.[^26][^22]

### Where PolarQuant/QJL Actually Apply in Your Stack

PolarQuant and QJL are relevant to Epistemos, just not where the brief described. They apply to **quantizing the Mamba model's internal representations during inference**, not the note index. Specifically:

- If Mamba-3 is run with KV-cache-like mechanisms (hybrid SSM+attention variants like MemMamba), PolarQuant would apply to the attention key cache
- For pure Mamba-3, the equivalent is state quantization — quantizing the hidden state \( h_t \) to reduce memory during long context processing
- The QJL 1-bit inner product estimator is directly applicable to fast dot-product scoring during the rescoring phase of your two-phase retrieval pipeline

The accurate framing: these are inference optimization tools for the *model*, not the index. Your vector index should use standard binary quantization (well-supported in Rust crates).

### The Right Rust Crates

| Component | Crate | What It Does |
|---|---|---|
| ANN Index | `usearch` | HNSW index, supports binary quantization, GPU-friendly[^27] |
| ANN Index (alt) | `hnswlib-rs` | Pure Rust HNSW, lightweight, no C++ deps[^28] |
| Parallelism | `rayon` | Work-stealing parallel iteration over index shards[^29] |
| SIMD Hamming | Custom kernel | ARM NEON for Apple Silicon, AVX-512 for x86[^25][^30] |
| Embeddings | `model2vec-rs` | Tokenize + lookup + pool — 100–400x faster than transformer forward pass on CPU[^31] |

The `usearch` crate is documented to benchmark favorably with float16, bfloat, int8, and 1-bit quantization using both HNSW and full-scan modes. It is the closest thing to a production-ready "instant note recall" index in Rust.[^32]

***

## Part 4: The Embedding Model Problem

### You Need a Fast Encoder, Not Just Mamba

The brief states "use a Fast-Mamba-Embedder" without specifying what this means. In practice, running a full Mamba-2 forward pass on every paragraph as you type is too slow for real-time continuous encoding. The correct architecture separates the encoder from the reasoning model:

**Model2Vec** is the ideal continuous encoder for Epistemos. It reduces sentence embedding to: tokenize + lookup (table) + pool, with no neural forward pass at all. The token embedding table for 32K tokens at 256 dimensions is only 32.7 MB. A native `model2vec.swift` package exists that wraps a Rust backend (using HuggingFace's `safetensors` and `tokenizers` crates) and is callable from Swift.[^31][^33]

**Google EmbeddingGemma** (308M parameters) is a stronger alternative for higher-quality embeddings — designed specifically for on-device RAG with no internet connection required.[^34]

**Apple's NLContextualEmbedding** (available via NaturalLanguage framework) provides sentence-level embeddings using Apple's on-device transformer, with no model download required for macOS/iOS users.[^35]

For Epistemos, the recommended approach is a tiered encoder:
1. **During typing**: Model2Vec (microseconds, ultra-low latency, background thread)
2. **On paragraph completion**: A small on-device BERT/sentence-transformer via CoreML for higher quality embeddings
3. **Index entry**: Binary quantize the higher-quality embedding and store in the usearch HNSW index

***

## Part 5: Mamba Fine-Tuning on Personal Notes

### PEFT Methods for Mamba

Fine-tuning Mamba on your personal notes is well-supported. MambaPEFT (Nov 2024) systematically evaluated all major PEFT methods and found that **Partial LoRA on the X projection** (`LoRA_p(X)`) achieves the best performance-to-parameter ratio. The key layers to target are `in_proj`, `x_proj`, `dt_proj`, and `out_proj`.[^36]

Memba (2026), a newer PEFT method specifically designed for Mamba, combines LIM neurons with LoRA on input/output projections, achieving superior performance to MambaPEFT with fewer trainable parameters. This is likely the right starting point for fine-tuning on your personal note corpus.[^37]

### Fine-Tuning vs. State-Based Personalization

There is an important architectural choice here. Fine-tuning updates the model weights to reflect your writing style and domain vocabulary — useful for generation. State injection provides context-specific recall for a specific session or topic. For Epistemos, both are valuable but serve different purposes:

| Approach | What It Achieves | When to Use |
|---|---|---|
| LoRA fine-tuning on notes | Model learns your vocabulary, style, domain | Offline, nightly batch process |
| State injection (vector recall → prefill) | Model "sees" your most relevant past notes | Real-time, every writing session |
| MemMamba state summarization | Model maintains compressed long-term memory | During a single long session |

The most realistic and highest-impact first step is the **state injection pipeline** (no training required), with LoRA fine-tuning added later as an offline improvement pass.

***

## Part 6: The Real Implementation Plan

### Architecture Diagram (Text Form)

```
[Swift Text Editor] 
    ↓ (200ms AsyncAlgorithms debounce)
[Swift → UniFFI → Rust Backend]
    ├── [Model2Vec Encoder] → float32 embedding (32ms)
    ├── [Binary Quantizer] → 1-bit signature (0.1ms)
    └── [usearch HNSW Index] → write to index (1ms)

[On Query / New Paragraph]
    ↓
[Rust Backend]
    ├── [Binary HNSW Search] → top-100 candidates (0.5ms)
    ├── [Float32 Rescoring] → top-5 relevant notes (2ms)
    └── [Return note text + embedding to Swift]
        ↓
[Mamba-3 On-Device Model]
    ├── [Prefill with top-5 note texts] → encode to SSM state (~50ms)
    └── [Write session proceeds with loaded context state]
```

### Swift: Async Debounce (2026 Best Practice)

The correct modern Swift pattern is **AsyncAlgorithms**, not Combine. The Combine approach requires managing publishers, subscribers, and cancellables; Swift Async Algorithms exposes `.debounce()` directly on async sequences:[^38][^39]

```swift
// Swift 6 / AsyncAlgorithms approach
for await text in textStream.debounce(for: .milliseconds(200)) {
    await rustBackend.encodeAndIndex(text)
}
```

This is cleaner, uses native async/await, and avoids the publisher lifecycle management overhead.[^38]

### Rust: The Two-Phase Search Kernel

The recommended approach for the Rust vector search backend:

```rust
// Phase 1: Binary HNSW - get 100 candidates fast
let candidates = index.search_binary(&quantize(&query_embedding), 100);

// Phase 2: Float32 dot product rescore - get top 5 accurate
let top_k = candidates.iter()
    .map(|id| (id, dot_product(&query_embedding, &full_embeddings[*id])))
    .sorted_by(|a, b| b.1.partial_cmp(&a.1).unwrap())
    .take(5)
    .collect();
```

The Hamming distance in Phase 1 can be further accelerated with ARM NEON intrinsics using the exact pattern shown in the TopK benchmarking research, achieving ~350 GB/s throughput.[^25]

### UniFFI Bridge Setup

The Swift/Rust integration uses Mozilla UniFFI, which automatically converts Rust types to Swift types (Rust enums → Swift enums, snake_case → camelCase). The build pipeline is:[^40]

```bash
cargo build --release --target aarch64-apple-darwin
cargo run --bin uniffi-bindgen generate \
  --library ./target/release/libepistemos_core.dylib \
  --language swift \
  --out-dir ./bindings
xcodebuild -create-xcframework ...
```

This produces Swift bindings that look like native Swift APIs — no manual C bridge layer required.[^41][^42][^40]

### Metal / Apple Neural Engine Integration

For the Mamba-3 model itself, the recommended inference path on Apple Silicon is CoreML conversion, which automatically routes compute to the Apple Neural Engine for supported operations. Apple's own on-device 3B model uses **2-bit quantization-aware training** and runs at low latency on M-series chips — this is your proof of concept that multi-bit quantized SSMs work on Apple Silicon.[^43][^44][^45]

For custom GPU-accelerated operations in Swift (such as the float32 rescoring dot products or any matrix ops), `MPSGraph` provides Metal-accelerated linear algebra without writing custom Metal shaders.[^46][^47][^48]

***

## Part 7: Critical Corrections and Reality Checks

### What the Brief Got Right

| Claim | Verdict |
|---|---|
| PolarQuant and QJL are real research | ✅ Correct[^1][^6] |
| 3-bit quantization is the stability floor | ✅ Confirmed by NeurIPS 2025[^4] |
| ~150MB for 1M note fragments | ✅ Accurate for 1-bit/1024-dim[^24][^22] |
| Sub-10ms search is achievable | ✅ NEON Hamming is ~0.37ms exhaustive[^25] |
| No off-the-shelf cargo crate | ✅ Must implement from papers |
| Continuous encoding as-you-type is the goal | ✅ Architecturally sound[^49] |

### What the Brief Got Wrong

| Claim | Correction |
|---|---|
| "TurboQuant = PolarQuant + QJL" is a real named method | ❌ These are two separate papers; no combined framework exists[^1][^6] |
| PolarQuant stores "angle in 3 bits, length in 1 bit" | ❌ PolarQuant uses 4 bits (first level) and 2 bits (remaining levels); the 1-bit-per-coordinate is QJL, not PolarQuant[^3][^6] |
| QJL provides "error correction" | ❌ QJL is a probabilistic inner-product estimator via sign-bit quantization — not error correction[^6] |
| PolarQuant/QJL should go in the note index | ❌ These are inference optimizations for the model's internal representations (KV cache analog), not the external note vector index[^1][^6] |
| Mamba SSM = "active RAM" with no loss | ❌ Mamba exhibits exponential memory decay over long sequences; an external index is necessary precisely because the state is lossy[^12][^17] |
| Hamming search operates on "3-bit signatures" | ❌ Hamming distance is a bitwise operation designed for 1-bit (binary) vectors; 3-bit vectors are searched with table lookups, not raw Hamming[^25][^30][^50] |

### The "Hard Truth" Is Harder Than Stated

The brief warns about complexity. The actual complexity spike is deeper:

1. **Mamba inference on Apple Silicon** requires either a CoreML export pipeline or custom Metal kernels. There is no mature Swift-native Mamba inference library as of March 2026.
2. **State injection** (the "load memory into Mamba's hidden state") requires modifying the Mamba inference loop, not just the tokenizer prompt. The API for programmatic state initialization is still community-contributed, not in the mainline official release.[^16]
3. **Model2Vec** or a small sentence transformer is required as a *separate* encoding step — Mamba-3 as the reasoning model is not designed to serve double-duty as a fast chunk encoder.
4. **PolarQuant from scratch in Rust** means implementing recursive polar coordinate transforms, random rotation matrix generation, and a custom quantization codebook — this is roughly 1–2 weeks of focused systems programming even with the paper in hand.[^3]

***

## Part 8: Prioritized Build Sequence

The following sequence moves from achievable-this-week to research-grade, letting Epistemos work end-to-end before tackling advanced compression.

### Phase 1: Working Prototype (Weeks 1–3)
- Swift text editor with `AsyncAlgorithms` 200ms debounce → Rust backend via UniFFI[^40][^38]
- `model2vec.swift` for continuous encoding (no GPU required, <1ms per paragraph)[^31]
- `usearch` HNSW index with float32 storage in Rust[^27]
- Binary quantization of stored embeddings using sign function (trivial: `embedding.map(|x| x > 0)`)[^22]
- Two-phase retrieval (Hamming binary search → float32 rescore) with `rayon` parallelism[^29]
- Display top-5 contextually relevant notes in sidebar as you type

### Phase 2: Mamba-3 Integration (Weeks 4–6)
- Export a small Mamba-3 model (~400M parameters) to CoreML or use `candle`/`burn` Rust inference
- Implement basic state prefill: tokenize top-3 retrieved notes → run Mamba-3 forward pass → save hidden state
- Use loaded state as the starting context for each new writing session
- Benchmark: note recall accuracy with and without state injection

### Phase 3: LoRA Fine-Tuning (Weeks 7–10)
- Export your notes corpus to a training-compatible format
- Apply Memba PEFT (LIM neurons + LoRA_p(X)) to a pre-trained Mamba-3 checkpoint[^37]
- Fine-tune overnight on a MacBook Pro / M-series chip
- Re-export to CoreML and replace Phase 2 base model

### Phase 4: Advanced Quantization (Weeks 11+)
- Implement PolarQuant encoder in Rust from the arXiv 2502.02617 paper[^3]
- Apply to the float32 embeddings stored in Phase 1 to reduce index size 4.2x further
- If using a hybrid Mamba-Transformer (MemMamba-style), apply QJL to the attention key cache
- Benchmark memory and latency against Phase 1 baseline

***

## Conclusion

The "Latent Memory Index" vision is technically sound and achievable on your Swift/Rust/Apple Silicon stack — but the real architecture diverges from the brief in meaningful ways. PolarQuant and QJL are model-level KV cache optimizations, not index-level note compression tools; binary quantization with Hamming search is the correct note index primitive. Mamba-3's constant memory footprint and state injection capability are the genuine on-device advantages over Transformer-based cloud RAG. The fastest path to a working system combines Model2Vec continuous encoding, `usearch` binary HNSW, UniFFI Swift/Rust bridging, and standard CoreML-based Mamba-3 inference — with PolarQuant deferred to Phase 4 as an engineering stretch goal rather than a Phase 1 dependency.

---

## References

1. [PolarQuant: Quantizing KV Caches with Polar Transformation](https://research.google/pubs/polarquant-quantizing-kv-caches-with-polar-transformation/) - This work introduces PolarQuant, a novel quantization method employing random preconditioning and po...

2. [PolarQuant: Quantizing KV Caches with Polar Transformation - arXiv](https://arxiv.org/abs/2502.02617) - This work introduces PolarQuant, a novel quantization method employing random preconditioning and po...

3. [PolarQuant: Quantizing KV Caches with Polar Transformation - arXiv](https://arxiv.org/html/2502.02617v1) - This work introduces PolarQuant, a novel quantization method employing random preconditioning and po...

4. [PolarQuant: Leveraging Polar Transformation for Key Cache ...](https://neurips.cc/virtual/2025/poster/118745) - Observation 1: Angle quantization is more sensitive to bitwidth. Allocating fewer than 3 bits to ang...

5. [Daily Papers - Hugging Face](https://huggingface.co/papers?q=random+preconditioning) - The long-context evaluation demonstrates that PolarQuant compresses the KV cache by over x4.2 while ...

6. [GitHub - amirzandieh/QJL: QJL: 1-Bit Quantized JL transform for KV ...](https://github.com/amirzandieh/QJL) - It applies a Johnson-Lindenstrauss (JL) transform as a preconditioner to the embedding vectors in th...

7. [Quantized Johnson-Lindenstrauss transform for LLMs - LinkedIn](https://www.linkedin.com/posts/amir-zandieh-phd-323a13a9_github-amirzandiehqjl-qjl-1-bit-quantized-activity-7223408478327840769-RzQe) - QJL leverages the Johnson-Lindenstrauss (JL) transform as a preconditioner to the embedding vectors ...

8. [State Space Duality (Mamba-2) Part I - The Model | Goomba Lab](https://goombalab.github.io/blog/2024/mamba2-part1-model/) - The main point of the Mamba-2 paper is what we call structured state space duality (SSD), which refe...

9. [Transformers are SSMs: Generalized Models and Efficient ... - arXiv](https://arxiv.org/abs/2405.21060) - State-space models (SSMs) such as Mamba have recently been shown to match or outperform Transformers...

10. [Characterizing State Space Model (SSM) and SSM-Transformer ...](https://arxiv.org/html/2507.12442v2) - Transformer-based LLMs rely on the KV cache [36] for inference acceleration to store and reuse repre...

11. [Characterizing State Space Model and Hybrid Language ... - arXiv](https://arxiv.org/html/2507.12442v4) - We present comprehensive memory footprint analysis of Transformer, SSM, and hybrid models for extrem...

12. [MemMamba: Rethinking Memory Patterns in State Space Model](https://arxiv.org/html/2510.03279v1) - MemMamba achieves significant improvements over existing Mamba variants and Transformers on long-seq...

13. [Mamba-3: Improved Sequence Modeling using State Space Principles](https://arxiv.org/html/2603.15569v1) - Guided by an inference-first perspective, we introduce three core methodological improvements inspir...

14. [MemMamba: Rethinking Memory Patterns in State Space Model](https://arxiv.org/abs/2510.03279) - Inspired by how humans distill and retain salient information when reading long documents, we propos...

15. [MemMamba: Rethinking Memory Patterns in State Space Model](https://huggingface.co/papers/2510.03279) - Abstract. MemMamba, a novel architecture integrating state summarization and cross-attention, improv...

16. [using ssm_state and conv_state during training · Issue #101 - GitHub](https://github.com/state-spaces/mamba/issues/101) - Are there any convenient ways to set up the initial state for mamba? I wanna use TBPTT to train mamb...

17. [Mamba Explained - The Gradient](https://thegradient.pub/mamba-explained/) - Mamba enjoys fast inference and linear scaling in sequence length, and its performance improves on r...

18. [Mamba-3 - Together AI](https://www.together.ai/blog/mamba-3) - Meet Mamba-3: the SSM built for inference. Faster than Transformers at decode, stronger than Mamba-2...

19. [Mamba-3: Improved Sequence Modeling using State Space Principles](https://www.emergentmind.com/papers/2603.15569) - Mamba-3 introduces principled developments in linear-time sequence models through a state-space mode...

20. [What Is Mamba 3? The State Space Model That Challenges ...](https://www.mindstudio.ai/blog/what-is-mamba-3-state-space-model-2) - Mamba 3 uses a state space model instead of transformers, maintaining a compact internal state for f...

21. [What Is Mamba 3? The State Space Model Architecture ... - MindStudio](https://www.mindstudio.ai/blog/what-is-mamba-3-state-space-model) - Mamba 3 uses state space model architecture instead of transformers, making it faster and cheaper fo...

22. [Binary and Scalar Embedding Quantization for Significantly Faster ...](https://huggingface.co/blog/embedding-quantization) - We introduce the concept of embedding quantization and showcase their impact on retrieval speed, mem...

23. [Binary Quantization - Vector Search, 40x Faster - Qdrant](https://qdrant.tech/articles/binary-quantization/) - In exchange for reducing our 32 bit embeddings to 1 bit embeddings we can see up to a 40x retrieval ...

24. [Meilisearch Indexes Embeddings 7x Faster with Binary Quantization](https://github.com/Kerollmops/blog/issues/16) - It processes raw bytes corresponding to a 1-bit quantized embedding, converting them into a properly...

25. [Binary Vector Search at 350GB/s using ARM NEON - TopK](https://www.topk.io/blog/binary-vector-search-arm-neon) - Optimizing binary vector search using ARM NEON instructions to achieve 350GB/s throughput.

26. [Binary Quantization: the 1-bit trick that turns terabytes of vectors into ...](https://dev.to/abhishek_gautam-01/binary-quantization-the-1-bit-trick-that-turns-terabytes-of-vectors-into-pocket-sized-fingerprints-1e0j) - Binary Quantization keeps only the sign bit of every dimension (+1 or –1) + the original L2 norm. Sa...

27. [usearch - Rust - Docs.rs](https://docs.rs/usearch) - §USearch Crate for Rust. usearch is a high-performance library for Approximate Nearest Neighbor (ANN...

28. [hnswlib-rs - crates.io: Rust Package Registry](https://crates.io/crates/hnswlib-rs) - Pure-Rust HNSW (Hierarchical Navigable Small World) graph for approximate nearest-neighbor search, i...

29. [Parallelism, choosing between or combining Rayon and SIMD](https://users.rust-lang.org/t/parallelism-choosing-between-or-combining-rayon-and-simd/46700) - Rayon vs SIMD is not an exclusive choice. For fast algorithms you're going to need both at the same ...

30. [Unleashing Intel AVX-512 for binary vector performance - AWS](https://aws.amazon.com/blogs/big-data/save-big-on-opensearch-unleashing-intel-avx-512-for-binary-vector-performance/) - The Hamming distance between two binary vectors is defined as the difference in the number of bits b...

31. [model2vec.swift: Sentence Embeddings for iOS/macOS Apps - GitHub](https://github.com/shubham0204/model2vec.swift) - On-Device RAG. A fast sentence-embedding model can be useful in RAG applications where semantic simi...

32. [Bang for the Buck: Vector Search on Cloud CPUs - arXiv](https://arxiv.org/html/2505.07621v1) - In this study, we show that CPU microarchitectures available in the cloud perform significantly diff...

33. [Introducing model2vec.swift: Fast, static, on-device sentence ...](https://www.reddit.com/r/iOSProgramming/comments/1l6f9za/introducing_model2vecswift_fast_static_ondevice/) - model2vec.swift is a Swift package that allows developers to produce a fixed-size vector (embedding)...

34. [Generate Embeddings with Sentence Transformers | Gemma](https://ai.google.dev/gemma/docs/embeddinggemma/inference-embeddinggemma-with-sentence-transformers) - EmbeddingGemma is a lightweight, open embedding model designed for fast, high-quality retrieval on e...

35. [On-Device Text Embeddings in React Native with Apple NLP ...](https://www.callstack.com/blog/on-device-ai-introducing-apple-embeddings-in-react-native) - NLContextualEmbedding is a modern, sentence-based transformer model. Instead of looking at words in ...

36. [MambaPEFT: Exploring Parameter-Efficient Fine-Tuning for Mamba](https://arxiv.org/html/2411.03855v1) - In this paper, we conduct an exploratory analysis of PEFT methods for Mamba. We investigate the effe...

37. [Memba: Membrane-driven Parameter-Efficient Fine-Tuning for Mamba](https://arxiv.org/html/2506.18184v2) - Our approach combines LIM neurons with strategically placed LoRA on input and output projections, cr...

38. [Debounce in Swift: Ditch Combine for This One Simple Loop](https://dev.to/arshtechpro/debounce-in-swift-ditch-combine-for-this-one-simple-loop-2h6p) - ... Combine becomes a single readable for await loop. Next time you reach for Combine just to deboun...

39. [Yielding and debouncing in Swift Concurrency](https://swiftwithmajid.com/2025/02/18/yielding-and-debouncing-in-swift-concurrency/) - Swift concurrency language features provide us with two simple but very powerful functions: yield an...

40. [Multiplatform with Rust on iOS - by Tjeerd in 't Veen](https://mobilesystemdesign.substack.com/p/multiplatform-with-rust-on-ios-2c4) - Creating a UniFFI bindgen binary. UniFFI examines our Rust code and generates bridging code for Swif...

41. [Building an iOS App with Rust Using UniFFI - DEV Community](https://dev.to/almaju/building-an-ios-app-with-rust-using-uniffi-200a) - Set 4: Import the library in Xcode. Create a new iOS app in Xcode. Import both the XCFramework Mobil...

42. [Integrating with Xcode - The UniFFI user guide](https://mozilla.github.io/uniffi-rs/latest/swift/xcode.html) - It is possible to generate Swift bindings at compile time for Xcode projects and incorporate them al...

43. [Updates to Apple's On-Device and Server Foundation Language ...](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates) - The on-device model is optimized for efficiency and tailored for Apple silicon, enabling low-latency...

44. [Apple Intelligence Foundation Language Models Tech Report 2025](https://machinelearning.apple.com/research/apple-foundation-models-tech-report-2025) - We introduce two multilingual, multimodal foundation language models that power Apple Intelligence f...

45. [AWS re:Invent 2025 - Supercharge ML and Inference on ... - YouTube](https://www.youtube.com/watch?v=-nOYLs77aKc) - Take your machine learning workflows to the next level with EC2 Mac instances powered by Apple silic...

46. [Accelerate machine learning with Metal - WWDC24 - Videos](https://developer.apple.com/videos/play/wwdc2024/10218/) - We'll also cover how to improve your model's compute bandwidth and quality, and visualize it in the ...

47. [Accelerate machine learning with Metal Performance Shaders Graph](https://developer.apple.com/videos/play/wwdc2021/10152/) - Metal Performance Shaders Graph is a compute engine that helps you build, compile, and execute custo...

48. [Custom function evaluation on the GPU with MPSGraph](https://nilcoalescing.com/blog/FunctionsOnYourGPU) - MPSGraph enables us to run math on the GPU without needing to write C++ based Metal shaders. We can ...

49. [Demystifying On-Device Intelligent Search Using RAG Architecture](https://infohub.delltechnologies.com/p/demystifying-on-device-intelligent-search-using-rag-architecture/) - The Retrieval-Augmented Generation (RAG) pipeline is a powerful solution for extracting and synthesi...

50. [Hamming Distance: A Comprehensive Guide for 2025 - Shadecoder](https://www.shadecoder.com/topics/hamming-distance-a-comprehensive-guide-for-2025) - Hamming distance is a simple idea with far-reaching impact - from error-correcting codes to similari...

