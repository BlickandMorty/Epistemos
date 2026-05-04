# Mixed-precision SIMD on Apple Silicon is hard, not fatal

**The critique that naive mixed-precision decoding is 1.2–1.5× slower than uniform 4-bit is correct — but five independent lines of evidence now demonstrate the penalty is an engineering problem with known solutions, not a fundamental architectural limitation.** Kitty's two-tensor decomposition eliminates SIMD divergence by construction, T-MAC's lookup-table approach bypasses dequantization entirely, BitDecoding's software-pipelined architecture hides the overhead behind Tensor Core execution, RotorQuant's fused Metal kernel achieves 9–31× speedup over BLAS baselines on M4, and AlphaEvolve-style automated search has already produced measurable Metal kernel improvements. The naive approach fails; the engineered approaches recover full throughput or better.

## Kitty proves two-tensor decomposition eliminates divergence by design

The Kitty paper (arXiv:2511.18643, November 2025) directly addresses the mixed-precision SIMD divergence problem for KV cache quantization. Its core insight: rather than processing mixed 2-bit/4-bit channels in a single pass, **decompose each mixed-precision page into two uniform 2-bit tensors** — a dense matrix and a structured sparse matrix stored separately. Both tensors process through identical 2-bit unpacking kernels with no scattered reads, no hard-coded masks, and no branch divergence.

The benchmark results on NVIDIA A100 show **2.1–4.1× throughput improvement** over FP16 baselines for Qwen3-8B generating 8192 tokens, with up to **8× batch size** under the same memory budget. The paper explicitly claims the system "preserves coalescing and avoids divergence." Kitty-Pro (25% of channels boosted to 4-bit) achieves near-parity with FP16 accuracy while using ~8× less KV memory. On long-context benchmarks at 32K tokens, Kitty narrows the accuracy gap versus FP16 to **3–4 points**, compared to 13 points for naive 2-bit quantization.

The Triton kernels are described as proof-of-concept, and per-kernel microsecond timings were not published — the throughput gains come primarily from enabling larger batches through memory savings. However, the architectural principle transfers directly: **any mixed-precision stream can be decomposed into uniform-precision tensors that map cleanly to SIMD lanes**. The two-tensor trick converts the mixed-precision scheduling problem from a runtime branching problem into a compile-time data layout problem.

## T-MAC's lookup tables bypass dequantization entirely

T-MAC (arXiv:2407.00088, EuroSys 2025) takes the most radical approach to the SIMD divergence problem: **eliminate dequantization altogether**. Instead of converting low-bit weights back to FP16 before multiplication, T-MAC decomposes any n-bit multiplication into n one-bit lookup passes. A group of 4 one-bit weights has only 16 possible bit patterns, so all partial sums are precomputed into a 16-entry lookup table that fits in ARM NEON registers. The `tbl` instruction performs 16 simultaneous lookups per cycle.

This fundamentally restructures the computation. Different bit-widths (1, 2, 3, 4-bit) use the **exact same kernel logic** — they differ only in the number of lookup passes. There is no data-type-dependent branching, no mixed-width unpacking, and no SIMD lane divergence. On Apple M2-Ultra specifically, T-MAC achieves kernel-level speedups up to **6.6× over llama.cpp** (average 3.6×), with **71 tok/s** for BitNet-3B on 8 cores. The most striking result: T-MAC's throughput **scales linearly** as bit-width decreases from 4-bit to 1-bit, while traditional dequantize-then-multiply shows flat or degraded performance below 4-bit. Energy consumption drops **70%** versus llama.cpp on M2-Ultra.

T-MAC's limitation is single-token decode throughput — the "scalar LUT" paradigm achieves less than 40% bandwidth utilization for multi-token parallel inference, which Vec-LUT (arXiv:2512.06443) addresses with a shared vector LUT design claiming **4.2× prefill and 3.2× parallel decoding** acceleration. Microsoft's bitnet.cpp, built directly on T-MAC's methodology, runs 100B BitNet models at human reading speed on a single Apple M2. The LUT paradigm represents a genuine alternative computational model where the SIMD divergence critique simply does not apply.

## BitDecoding's software pipeline hides dequantization behind matrix execution

BitDecoding (arXiv:2503.18773, accepted HPCA 2026) demonstrates the most impressive raw numbers: **3–9× speedup** over FP16 FlashDecoding-v2 across RTX 4090, A100, and H100, with up to **4.3× over QServe** (the prior state-of-the-art low-bit system). The key innovation is a three-stage software pipeline that overlaps dequantization on CUDA cores with matrix multiplication on Tensor Cores and memory prefetching on load/store units — all executing concurrently within the same kernel.

While BitDecoding targets NVIDIA hardware, its architectural principle maps directly to Apple Silicon. The **BitFusion scheme** automatically induces hardware-compatible layouts for arbitrary low-bit formats, eliminating the global reshape that causes naive approaches to stall. The paper shows that dequantization overhead becomes minimal because low-bit data reduces memory bandwidth pressure, shifting the kernel from memory-bound to compute-bound — exactly the regime where pipelining is most effective. End-to-end on LLaMA-3.1-8B at 128K sequence length, BitDecoding reduces decode latency by **3×** with only **0.2% accuracy loss**.

Apple Silicon's `simdgroup_matrix` operations in Metal serve an analogous role to Tensor Cores. A Metal adaptation would overlap dequantization on standard ALUs with matrix operations on simdgroup hardware — the same producer-consumer pipeline, different instruction set. No port exists yet, but the principle that software pipelining can fully hide dequantization cost is now proven at the kernel level.

## RotorQuant's fused Metal kernel delivers 9–31× on M4

RotorQuant (March 2026, scrya.com/rotorquant) provides the most direct evidence for Apple Silicon specifically. Its fused dequantize+rotate Metal kernel processes the entire pipeline — embed, rotor sandwich product, Lloyd-Max quantization, inverse sandwich, extraction — in a **single kernel dispatch** with all intermediate values held in registers.

The benchmark numbers on Mac Mini M4 are striking:

| Vectors | TurboQuant (MPS) | RotorQuant Metal | Speedup |
|---------|-----------------|-----------------|---------|
| 1,024 | 764 µs | 471 µs | **1.6×** |
| 4,096 | 6.02 ms | 650 µs | **9.3×** |
| 16,384 | 21.94 ms | 1.12 ms | **19.6×** |
| 65,536 | 86.46 ms | 2.76 ms | **31.3×** |

The speedup increases with batch size because kernel launch overhead amortizes while the per-vector compute advantage compounds. The arithmetic reduction is fundamental: Clifford rotors in Cl(3,0) have only **4 non-zero components** out of 8, reducing the full sandwich product to ~56 FMAs per group versus **16,384 FMAs** for TurboQuant's dense 128×128 matmul — a **160× reduction** in raw arithmetic. RotorQuant handles heterogeneous bit-widths through grade-aware quantization, where different algebraic grades (scalar, vector, bivector) receive independent Lloyd-Max codebooks, plus ecosystem support for asymmetric K/V cache configurations at different precisions per layer.

Caveats are significant: RotorQuant is a non-peer-reviewed technical report co-authored with an AI assistant, its block-diagonal rotation cannot fully decorrelate across groups (worse synthetic MSE than TurboQuant), and a potential sign error in the inverse sandwich was flagged in PR #34. The successor IsoQuant (arXiv:2603.28430) achieves **4.5–4.7× further speedup** using quaternion SO(4) rotations that align cleanly with SIMD float4 patterns.

## mlx-optiq traces the optimization journey from 47% slower to 2%

The mlx-optiq project documents perhaps the most instructive trajectory for the counter-argument. Initial naive mixed-precision KV cache quantization was **47% slower than FP16** — squarely in the range the critique predicts. Through incremental dequantization, custom Metal kernels, and rotated-space attention (rotating the query once at O(d²) instead of every key at O(seq_len × d²)), the penalty shrank to **just 2%**.

Fused Metal kernels by contributor arozanov achieved **2.7× faster quantization** by collapsing 6+ separate kernel launches into a single dispatch with 128 threads per vector, shared memory for Walsh-Hadamard Transform, and parallel tree reduction. An incremental decode buffer delivered **14× improvement** at 16K context length. TurboQuant V2 4-bit using `mx.quantized_matmul` (Apple's hardware-accelerated Metal kernel) runs at **near-native speed** — 188 tok/s versus 208 tok/s for standard FP16 at 512-token context on M4 Max. V2 3-bit with rotation+QJL actually **beats FP16 quality** on Gemma 3 (perplexity 12.05 vs 12.18) while compressing KV cache 5.5×. The lesson: the naive penalty is real but the optimization path is well-understood and produces results within weeks, not years.

## AlphaEvolve opens the door to automated Metal kernel discovery

Google DeepMind's AlphaEvolve (May 2025) has already demonstrated that automated evolutionary search can optimize compute kernels beyond human expert capability. The confirmed achievements — **48 multiplications** for 4×4 complex matrix multiplication (first improvement over Strassen in 56 years), **0.7% worldwide compute recovery** in Google's Borg scheduler (deployed over a year), **32.5% FlashAttention kernel speedup** via XLA IR optimization, and **23% Gemini training kernel speedup** — establish that automated kernel optimization produces production-grade results.

More directly relevant: **OpenEvolve has already been applied to Metal kernels** on Apple Silicon. Targeting Qwen3-0.6B's grouped query attention, it achieved **12.5% average decode speed improvement** and **14.4% prefill improvement** over MLX's production-grade `scaled_dot_product_attention`, with a peak **106% decode speed improvement** on specific workloads — all while maintaining 100% numerical accuracy. The system autonomously discovered that 8-element vectors optimally match Apple Silicon's SIMD width for 128-dimensional attention heads, fused three-pass softmax into two passes, and exploited Qwen3's 40:8 head structure for coalesced memory access. This demonstrates that the mixed-precision kernel optimization problem is amenable to automated search, reducing the engineering effort from months of expert tuning to days of compute.

## Slab-based allocation remains theoretical but has strong analogs

No production vector database (Milvus, Qdrant, FAISS) currently implements precision-aware slab allocation for mixed-precision vectors. All use **uniform quantization per index** — the SIMD divergence problem is avoided by simply not mixing precisions within a single index structure. This is an honest gap in the counter-argument.

However, strong analogs exist in adjacent domains. FAISS's **PQ Fast Scan** groups vectors for SIMD-efficient batch processing of PQ codes using `pshufb`, achieving **4–6× speedup**. Intel's optimized FAISS performs PQ code relayout for better cache hit rates. TurboMind's offline weight packing resolves memory and computation inefficiencies across arbitrary precision formats. FLUTE's offline weight reordering ensures dequantized weights align with SIMD execution expectations. An arXiv paper on SIMD-aware weight packing for ARM (2501.00032) achieves **~2× throughput** through memory layout optimization. The PDX paper (2503.04422) proposes a vertical/columnar layout for vector similarity search enabling dimension-wise SIMD execution. The engineering principles exist; the specific application to mixed-precision vector databases awaits implementation.

## The Claude Code architecture reveals production-grade context entropy management

The March 31, 2026 exposure of Claude Code's source (version 2.1.88, ~1,900 TypeScript files, **512K+ lines**) was caused by a `cli.js.map` source map file shipped in the npm package. The architecture reveals Anthropic's solution to "context entropy" — the tendency for AI agents to degrade as sessions grow complex — through a three-layer memory system: a **MEMORY.md index** (kept under 200 lines, always loaded), **topic files** (fetched on demand), and **transcripts** (never read directly, only grep'd).

The "Self-Healing Memory" operates through the **autoDream** consolidation process, which runs in a forked subagent when both 24 hours and 5+ sessions have elapsed since last consolidation. It merges observations, removes contradictions, converts relative references to absolute facts, and aggressively prunes stale information. "**Strict Write Discipline**" requires writing to file before updating the index, preventing context pollution from failed attempts. **KAIROS**, referenced over 150 times in the source, is an autonomous daemon mode gated behind compile-time feature flags that maintains append-only daily logs. The system treats memory as "a hint, not truth" — every fact must be verified against the actual codebase before use. Code-derived facts are never stored in memory; they're always re-derived from source.

## The counter-argument in five sentences

The naive mixed-precision critique is technically correct: mixing bit-widths in a continuous SIMD stream causes branch divergence, register pressure, and occupancy loss. But five proven techniques defeat this: **decompose** mixed-precision into uniform-precision tensors (Kitty), **replace** dequantization with lookup tables (T-MAC), **pipeline** dequantization behind matrix execution (BitDecoding), **fuse** the entire dequantize+transform pipeline into a single register-local kernel dispatch (RotorQuant on Metal), or **automate** the kernel search itself (AlphaEvolve/OpenEvolve). These are not theoretical — T-MAC ships in Microsoft's bitnet.cpp, Kitty's Triton kernels run on A100, RotorQuant's Metal kernel benchmarks at 31× on M4, and OpenEvolve has already optimized production Metal attention kernels. The 1.2–1.5× penalty describes the starting point of optimization, not the ceiling.