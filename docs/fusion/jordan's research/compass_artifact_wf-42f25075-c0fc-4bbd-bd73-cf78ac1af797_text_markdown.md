# Helios Shadow Memory — Final Consensus Document (v1.0)

*Reconciliation pass across seven synthesis turns. Load-bearing reference. No new architecture.*
*Author of record: Jordan ("Jojo"). Voice: Architect-Artisan.*
*Date of consolidation: 3 May 2026.*

---

## TL;DR

- **What you have, in one sentence.** Helios is a five-tier, predictive-residual KV memory hierarchy for Apple Silicon whose compression bound is governed by a now-five-term Master Inequality, every term of which is anchored to a published 2025–2026 result; the architecture is a *classical* re-interpretation of quantum oracle sketching, the lattice-quantization term is exactly Babai/GPTQ, the softmax-Lipschitz constant tightens to 1/2, and the "side information" is provably the residual stream itself.
- **What's load-bearing vs marketing.** Load-bearing: WBO Master Inequality, residual-stream-as-KV-projection, GPTQ≡Babai, softmax-1/2-Lipschitz, Sherry 1.25-bit (real, ACL 2026), Free Random Projection (real, but published for in-context RL not KV — engineering bet on transfer), CountSketch/Achlioptas/Kane-Nelson sparse JL (canonical). Marketing: "VaultGatedSwarm," "Engram Index," "Hermes Cascade" (the last is just a routing policy to NousResearch/Hermes-4 — real model, not Jordan's).
- **The single sharpest next move.** Before writing one line of L2/L3 sketch code, run the **KV-Direct baseline** (Qasim et al. 2603.19664) on Qwen3-8B-MLX-4bit at 128k context and measure peak RAM, KL divergence, and tokens/sec against full cache. If KV-Direct's bit-identical residual checkpointing already lands inside Helios's 12 GB / KL<0.05 / 10× compression envelope, **the lossy WBO story is fighting for marginal gains over a stronger free baseline** and the program needs to pivot to "KV-Direct + Sherry-on-residual + Shadow tier for query routing" rather than to a new lossy KV codec. That measurement is binary, takes one weekend, and reorients the entire 24-month plan.

---

## A. Verified Claim Register

Status legend: **P** = Proven (theorem in a peer-reviewed or arXiv-posted paper), **EV** = Empirically Validated (you or the cited paper measured it), **EB** = Engineering Bet (design principle with a stated falsifier), **C** = Conjecture (clearly marked).

### A.1 Mathematical foundations

| # | Claim | Status | Anchor | Notes / falsifier |
|---|---|---|---|---|
| 1 | GPTQ (back-to-front) is mathematically identical to Babai's nearest-plane algorithm on the lattice defined by the input Hessian; inherits Babai's worst-case error bound when no clipping occurs. | **P** | Chen, Shabanzadeh, Crnčević, Hoefler, Alistarh, **arXiv:2507.18553** (ICLR 2026, OpenReview NFB4QGGS65). | This is *the* lattice-quantization term in your Master Inequality. The bound is `‖Bz − y‖ ≤ (1/2)·√(Σ‖b̃ᵢ‖²)`, with `b̃ᵢ` the Gram-Schmidt basis of the Hessian lattice. |
| 2 | Softmax is 1/2-Lipschitz uniformly across all ℓₚ norms (p≥1); attained at p=1 and p=∞, supremum-only at intermediate p. Empirically validated on Qwen3-8B. | **P** + **EV** | Pravin Nair, IIT Madras, **arXiv:2510.23012**, 27 Oct 2025. | Replaces the loose "Lipschitz ≤ 1" bound assumed in earlier KV-error→logit-error analyses. Halves the propagated error term. Note: Newhouse's commentary observes that the relevant induced norm for transformers may not be ℓ₂; this affects the *interpretation* of the constant, not its truth. |
| 3 | KV at every transformer layer is a *deterministic, bit-identical* linear projection of the residual stream; recomputing K, V from the residual incurs zero reconstruction error (verified on six models, 135M–4B, four families). KV-Direct holds 42 MB peak vs 103 MB for full cache over 20 turns on Gemma-3-4B; 5 KB/token vs 136 KB/token. | **P** + **EV** | Qasim, Zhang, Shaheen, Alharith, Zhang, **arXiv:2603.19664** (KV-Direct). | This is the strongest result in your stack and the most dangerous to your story: it implies the "compressed-residual" tier (L1) is not an approximation but a refactor. Treat L1 as residual checkpoints, not lossy keys. |
| 4 | Wyner-Ziv coding with Gaussian source and side-information at the decoder achieves no rate loss; nested-lattice (Erez-Zamir) constructions approach this bound; Slepian-Wolf-coded nested lattice (SWC-NQ) closes the boundary-gain gap. | **P** | Zamir-Shamai-Erez (IEEE Trans. IT 2002, 2004); Liu-Cheng-Xiong (SWC-NQ); Zamir, *Lattice Coding for Signals and Networks* (Cambridge). | The "Wyner-Ziv residual" term in the Master Inequality is anchored here. The LM is the side information. |
| 5 | Test-time regression unifies softmax attention, linear attention, SSMs (incl. Mamba-2), DeltaNet, RWKV-7, and fast-weight programmers as variants of memorization-as-regression with three design choices (regression weights, regressor class, optimizer). | **P** | Wang, Shi, Fox, **arXiv:2501.12352** (2025). | Justifies generalizing PRCDA from Transformer KV to Mamba-2 SSM state and RWKV-7 — the regularity conditions for the WBO theorem are stated in the same vocabulary as TTR's `(W, F, Opt)` triple. Falsifier for the "transfer" claim: SSM track within 5 pp of Transformer track on the same compression envelope. |
| 6 | Sparse Johnson-Lindenstrauss / CountSketch preserves pairwise ℓ₂ distances with sparsity `s = O(ε⁻¹·log(1/δ))` per column at embedding dimension `m = O(ε⁻²·log n)`. | **P** | Achlioptas, *J. Comput. Syst. Sci.* 2003 (database-friendly RP, ±1/0 entries); Kane & Nelson, *J. ACM* 61(1), 2014 (Sparser Johnson-Lindenstrauss Transforms / SJLT, sparsity Θ(ε⁻¹ log(1/δ)), tight per Nelson-Nguyên FOCS 2013); Charikar-Chen-Farach-Colton 2002 (CountSketch). | **The user's term "CountSparse JL" is not canonical.** It is a real method under three names. Use **Kane-Nelson SJLT** as the citation; CountSketch (1 nonzero per column) is a special case suboptimal for subspace embedding but optimal for streaming heavy hitters, which is what L2 actually needs. **Recommendation:** call it "sparse JL (Kane-Nelson 2014) for residual sketching, CountSketch (Charikar 2002) for top-k page-id selection." Two distinct uses, two distinct sparsity regimes. |
| 7 | Free Random Projection: random orthogonal matrices built from compositions of Haar-distributed unitaries on permutation orbits, asymptotically free in Voiculescu's sense; hierarchical structure emerges in the orbital graph. | **P** | Hayase, Collins, Inoue, **arXiv:2504.06983** (April 2025, v2 June 2025). | **Real paper. Real method.** But: published *for in-context reinforcement learning*, not KV compression. Theorems about free independence (Voiculescu 1992; Mingo-Speicher 2017) and strong asymptotic freeness of Haar unitaries (Magee-de la Salle 2024) carry over, but the *empirical* claim that hierarchy emerges usefully *inside a KV sketch* is an **engineering bet**, not a theorem. Falsifier: replace FRP with a Gaussian random orthogonal matrix at L2 and measure top-k recall delta. If Δ < 1 pp, FRP is decoration. |
| 8 | Sherry 1.25-bit ternary quantization: 3:4 fine-grained sparsity, packs 4 weights into 5 bits, hardware-aligned (power-of-two SIMD). Matches Tequila SOTA at 1B/3B with 25% bit savings. ACL 2026. | **P** + **EV** | Hong Huang, Decheng Wu et al. (CityU HK, Tencent, McGill), **arXiv:2601.07892**. Reference impls: `tencent/Hy-MT1.5-1.8B-1.25bit`, `MoraxGeo/Sherry-3B-1.25bit-per-channel`. Code: `Tencent/AngelSlim`. | **Real paper, name verified.** Designed for *weight* quantization, not residual/KV. Using it as the residual codec is an **engineering bet**. Falsifier: KL divergence on a calibration set < 0.05 when residuals are Sherry-packed and re-projected to K, V. If KL > 0.10, fall back to **NF4 (QLoRA)** or **3-bit groupwise (KVQuant)** for residuals. |

### A.2 Quantum-classical bridge

| # | Claim | Status | Anchor | Notes |
|---|---|---|---|---|
| 9 | Quantum oracle sketching: a polylog-size quantum computer can do large-scale classification & dimension reduction on classical data; classical machines need exponentially more space, super-polynomially more samples. Validated on scRNA-seq and movie-review sentiment with <60 logical qubits. | **P** | Zhao, Zlokapa, Neven, Babbush, Preskill, McClean, Huang, **arXiv:2604.07639**, 8 Apr 2026. Code: `github.com/haimengzhao/quantum-oracle-sketching`. | **Confirmed correct ID, authors, and date.** The paper's exponential separation is in *space* under the streaming model (per Aram Harrow's clarification on SciRate). |
| 10 | The classical transfer of (9) to a Mac is the streaming-sketch + on-the-fly compaction template; the *quantum advantage* does **not** transfer. | **EB** | Same paper; explicit framing in turns 3 and 6. | This is correctly demarcated in the prior synthesis. The Helios brief must say "*inspired by*", never "*classical instance of*". |
| 11 | Classical shadows (Huang-Kueng-Preskill, *Nat. Phys.* 2020; arXiv:2002.08953): O(log M) random measurements suffice to predict M observables of a quantum state, saturating info-theoretic lower bounds. | **P** | Huang, Kueng, Preskill, *Nat. Phys.* 16, 1050 (2020). | **Naming caution:** "Shadow" in classical-shadows-tomography ≠ "Shadow" in ShadowKV (Bytedance, ICML 2025) ≠ your "Shadow tier." Three distinct uses of the same word. The prior synthesis used "Shadow" loosely; the consensus document keeps it because it has now metastasized, but **flag the collision in any external write-up**. |

### A.3 Engineering-stack claims

| # | Claim | Status | Anchor |
|---|---|---|---|
| 12 | `mlx-rs` (oxideai) is a usable Rust binding to MLX, MIT/Apache-2.0, MSRV 1.82–1.83, current 0.21.0 (Dec 2025), 170+ stars, active. | **EV** | `github.com/oxideai/mlx-rs`; `crates.io/crates/mlx-rs/0.21.0`. |
| 13 | `cartesia-ai/mamba2-2.7b-4bit-mlx` exists on Hugging Face; requires `cartesia-metal` + `cartesia-mlx`; tested on macOS 14.1 / M3. | **EV** | `huggingface.co/cartesia-ai/mamba2-2.7b-4bit-mlx`. |
| 14 | ANEMLL provides the only practical open-source path to the Apple Neural Engine for LLMs; supports Llama 3.1/3.2, Qwen 2.5/3, Gemma 3, DeepSeek R1 8B; v0.3.5 beta as of late 2025. Direct ANE programming via private `_ANEClient`/`_ANECompiler` APIs is feasible (Orion, arXiv:2603.06728) but unsanctioned. | **EV** | `github.com/Anemll/Anemll`; Kumaresan, *Orion*, arXiv:2603.06728. |
| 15 | NousResearch/Hermes-4 (14B/70B/405B; Aug 2025; tech report arXiv:2508.18255) is a real frontier-class hybrid-reasoning open-weight family. Hermes-4.3 is a ByteDance Seed-36B fine-tune. | **EV** | `huggingface.co/NousResearch/Hermes-4-{14B,70B,405B}`; `hermes4.nousresearch.com`. |

### A.4 Conjectures (clearly marked)

- **C1.** That FRP's hierarchical-emergence property at L2 yields measurably better top-k recall than a Haar-orthogonal or Gaussian baseline *for KV/residual sketching* (the published evidence is for ICRL only). **Falsifier:** ablation in week 4–6.
- **C2.** That the Sherry 1.25-bit ternary codec, designed for *weights*, transfers to *residual-stream* encoding without catastrophic KL inflation. **Falsifier:** KL on long-context wiki-103 calibration > 0.05.
- **C3.** That a single sketch dimension `d_S` works across both Transformer KV and Mamba-2 SSM state without tier-specific tuning. **Falsifier:** SSM track requires `d_S` > 1.5× the Transformer track for matched recall.
- **C4 (load-bearing for the elevator pitch).** That a 5-tier streaming hierarchy on a 64–96 GB Mac Studio M3 Ultra can serve 1M-token contexts at >20 tok/s with KL<0.05 vs full attention, while staying below 12 GB peak resident. **Falsifier:** the two-track validation harness ships and misses any one of {KL, throughput, RAM} by >20%.

---

## B. Reconciliations

### B.1 4-tier vs. 5-tier hierarchy — **canonical: 5-tier**.

The capstone document's L0/L1/L2/L3/L4 supersedes the earlier 4-tier sketch. The 4-tier version collapsed L4 (cloud fallback) into "escalation policy"; this hid a real architectural seam (network boundary, billing boundary, privacy boundary). Keep five.

**Canonical naming:**

| Tier | Name | Substrate | Codec | What lives here |
|---|---|---|---|---|
| **L0** | Exact Hot | Unified RAM | bf16 / fp16 | Last `W` tokens, full K/V; attention sinks. |
| **L1** | Compressed Residual | Unified RAM | **Sherry 1.25-bit on the residual stream** (Qasim 2603.19664: K,V are bit-identical projections of residual) + per-channel scales | Mid-window tokens. |
| **L2** | Shadow Sketch | Unified RAM (or IOSurface-backed Metal heap) | **Sparse JL (Kane-Nelson 2014) over an FRP basis (Hayase-Collins-Inoue 2504.06983)**; CountSketch (Charikar 2002) over page IDs for top-k routing | Pages older than W·k tokens; queryable. |
| **L3** | SSD Oracle | NVMe via `objc2-metal` IOSurface + `mmap` | **NF4 or 3-bit groupwise** residual checkpoints (KVQuant-style) | Cold pages; episode log. |
| **L4** | Hermes Cascade | Network → Hermes-4-405B | (none; raw prompt) | Reasoning escalations when L0–L3 confidence < τ. |

"VaultGatedSwarm" and "Engram Index" remain Epistemos-level product nouns; they are **not** load-bearing in the Helios kernel. Keep them out of the MLSys submission.

### B.2 4-term vs. 5-term Master Inequality — **canonical: 5-term**.

The Wyner-Babai Operator inequality bounding logit error `‖Δlogits‖` is now:

```
‖Δlogits‖ ≤ (1/2) · [ T_W + T_K + T_R + T_Q + T_S ]                (WBO-5)
```

with the leading `1/2` from softmax-Lipschitz (Nair 2510.23012, claim #2), and:

| Term | Name | Bound | Anchor |
|---|---|---|---|
| `T_W` | Weight (Babai/GPTQ) | `(1/2)·√(Σ‖b̃ᵢ‖²)` over Hessian-lattice Gram-Schmidt basis | Chen-Hoefler-Alistarh 2507.18553 |
| `T_K` | KV-lattice (Erez-Zamir nested lattice) | `G(Λ)·σ²·2^(−2R)` with `G(Λ)` the lattice's normalized second moment (E₈: 0.0717, Leech: 0.0658) | Zamir-Shamai-Erez |
| `T_R` | Wyner-Ziv residual rate-distortion gap | `≤ 0.5 bit/sample` for arbitrary sources under MSE (Zamir's gap theorem) | Zamir 1996 |
| `T_Q` | LUT/codec precision (Sherry on residual) | `O(2^−1.25 · ‖r‖)` per token for ternary 3:4-sparse pack | Huang et al. 2601.07892 |
| `T_S` | **Sketch error (the new fifth term)** | `C_S · (ε² · 𝔼[attn] + ρ_miss · D_KL^page)` where `ε` is the JL distortion, `ρ_miss` the miss rate against L2's top-k, `D_KL^page` the page-replacement KL | Kane-Nelson 2014 (ε² rate); Charikar (miss rate) |

The Shadowed Associative State Theorem (turn 4) carries through with three regularity conditions, all of which now have explicit anchors:
1. **JL preservation:** sparse-JL with sparsity `s ≥ Θ(ε⁻¹ log(1/δ))` and width `m ≥ Θ(ε⁻² log n)` (Kane-Nelson tight bound, Nelson-Nguyên 2013 conjecture).
2. **Sparse active set:** at any decoding step the active KV set has size ≤ `k_active = O(√T)` for T-token context (empirical, from RetrievalAttention 1–3% access rate; engineering-bet for the precise constant).
3. **Confidence calibration:** `ρ_miss` measurable online via reservoir-sampled cosine similarities, used for L4 escalation gating.

### B.3 12-week vs. 24-month roadmap — **harmonized as front-end / full program**.

```
Months  0 ── 3 ───────── 12 ──────────────── 24
Weeks  ├─ 12-week build path ─┤
        │                     │
        │  L0+L1 ship          │  L2 sketch + harness   │  MLSys submission
        │  Two-track on Qwen3  │  Two-track on Mamba-2  │  Hermes Cascade gating
        │  WBO-5 verified      │  SSM-Transformer parity│  Public Rust crate
        │  KL<0.05@128k        │  Falsifier closed      │  ANE path or pivot
```

The 12-week plan is **months 0–3**, ending at "Benchmark on long-context Qwen3-8B + optimization" — i.e., L0+L1 shipped, L2 prototype, two-track harness running, WBO-5 measured. Months 3–12 add the SSM track + L3 SSD Oracle. Months 12–24 add Hermes Cascade routing, write the MLSys paper, and either bring up the ANE path (via ANEMLL or Orion-style private API) or formally drop it.

### B.4 ε default — **canonical: ε = 0.05** (with two reserved overrides).

The literature ranges 0.025 to 0.05; the choice is a triple trade-off (sketch dimension, miss rate, throughput). Pick **ε = 0.05** as default because:
- JL width `m = O(ε⁻² log n)` — at ε=0.05 with n=10⁶ tokens, `m ≈ 5524`; at ε=0.025, `m ≈ 22095`. The former fits comfortably in unified memory; the latter does not for batch>1.
- Empirical: ShadowKV and RetrievalAttention both operate in the 1–5% access regime; ε=0.05 lands you there.
- Sherry's bit-budget at 1.25 bits already absorbs ~ε=0.03 distortion before downstream KL inflation; doubling sketch precision is wasted.

**Reserved overrides:**
- `ε = 0.025` for *reasoning-critical* layers (the last 25% of the stack, where logit error compounds into chain-of-thought drift).
- `ε = 0.10` for *attention-sink* layers (first 2 layers and any head with ≥80% mass on a single token), where coarse sketching is harmless.

---

## C. Consolidated Technical Map

### C.1 The single diagram (whiteboard form)

```
                ┌─────────────────────────────────────────────┐
                │  USER PROMPT  →  Qwen3-8B-MLX-4bit (Tx)     │
                │                  Mamba-2.7B-4bit-mlx (SSM)  │
                └──────────────┬──────────────────────────────┘
                               │ residual stream (the side info)
                  ┌────────────┴──────────────┐
                  ▼                            ▼
      ┌────────────────────┐         ┌──────────────────────┐
      │ L0: Exact Hot      │         │ "Side info" = LM     │
      │ bf16, last W toks  │         │ KV ≡ projection of   │
      │ (Qasim 2603.19664) │         │ residual (bit-exact) │
      └─────────┬──────────┘         └──────────┬───────────┘
                ▼                                │
      ┌────────────────────┐                     │
      │ L1: Compressed     │                     │
      │ Residual           │←── Sherry 1.25b ────┘
      │ (2601.07892)       │    on residual not KV
      └─────────┬──────────┘
                ▼
      ┌─────────────────────────────────────────┐
      │ L2: Shadow Sketch                       │
      │   FRP basis (2504.06983)                │
      │   ⊕ Sparse JL k–v sketch (Kane-Nelson)  │
      │   ⊕ CountSketch on page IDs (Charikar)  │
      │   queryable, top-k recall ≥0.95         │
      └─────────┬───────────────────────────────┘
                ▼
      ┌────────────────────┐
      │ L3: SSD Oracle     │   IOSurface + mmap (objc2-metal)
      │ NF4 / 3-bit grpwise│   Episode log
      └─────────┬──────────┘
                ▼   confidence < τ
      ┌────────────────────┐
      │ L4: Hermes Cascade │   → NousResearch/Hermes-4-405B
      │ (cloud fallback)   │   (real model; this is a router, not arch)
      └────────────────────┘

  Bound on logit error (one inequality, five terms):
   ‖Δlogits‖ ≤ ½ · [ T_W + T_K + T_R + T_Q + T_S ]
              │      │     │     │     │     │
              │      │     │     │     │     └─ Sketch (Kane-Nelson + CountSketch)
              │      │     │     │     └─────── Codec/LUT (Sherry 1.25b)
              │      │     │     └───────────── Wyner-Ziv gap (≤0.5 bit, Zamir)
              │      │     └─────────────────── Erez-Zamir nested lattice
              │      └───────────────────────── Babai/GPTQ (Chen-Hoefler-Alistarh)
              └──────────────────────────────── Softmax 1/2-Lipschitz (Nair 2510.23012)
```

### C.2 The Cargo workspace (one)

```
helios/
├─ crates/
│  ├─ helios-core/         # WBO-5 invariants, tier traits, residual algebra
│  ├─ helios-mlx/          # mlx-rs wrappers; quantize, gemm, attention kernels
│  ├─ helios-metal/        # objc2-metal: IOSurface, MTLHeap, residency mgmt
│  ├─ helios-sketch/       # FRP, sparse-JL (Kane-Nelson), CountSketch
│  ├─ helios-codec/        # Sherry 1.25b residual pack/unpack; NF4 fallback
│  ├─ helios-tier/         # L0..L3 lifecycle, eviction, compaction
│  ├─ helios-route/        # L4 Hermes Cascade gating; confidence τ
│  ├─ helios-bench/        # two-track harness (Qwen3 / Mamba-2)
│  └─ helios-ffi/          # UniFFI → Swift; mistral.rs read-only ref
└─ kernels/
   ├─ sherry_pack.metal    # 3:4 sparsity, 4→5-bit pack
   ├─ frp_apply.metal      # Haar-composition orbital projection
   ├─ jl_sketch.metal      # SJLT, sparsity Θ(ε⁻¹ log 1/δ)
   └─ topk_route.metal     # CountSketch heavy-hitter routing
```

AMX is feature-gated. ANE path is **post-month-12** via ANEMLL; do not let the ANE block the front of the program. CubeCL is not load-bearing in 2026 and stays out of the build graph. Burn-mlx is contingency only (kept warm; not on the critical path).

### C.3 The validation harness (one)

| Metric | Threshold | Measured at | Falsifier |
|---|---|---|---|
| KL(p_full ‖ p_helios) | < 0.05 | every 1k tokens at 128k context | > 0.10 → drop ε to 0.025 in reasoning layers |
| Compression ratio (vs full bf16 KV) | > 10× | end of context | < 8× → revisit Sherry bit-budget |
| Top-k recall (k=64) | > 0.95 | per layer, per head | < 0.90 → increase sketch width m |
| L4 escalation rate | < 5% | per turn | > 10% → confidence τ miscalibrated |
| Peak resident RAM | ≤ 12 GB | M3 Max 64 GB target | > 16 GB → L1 not actually compressing |
| Tokens/sec (decode) | ≥ 20 @ 128k | Qwen3-8B-4bit | < 12 → kernel-level Metal profile |
| **SSM-Transformer gap** | **≤ 5 pp on every metric above** | Mamba-2.7B vs Qwen3-8B | **> 5 pp ⇒ TTR-based generalization fails; PRCDA does not transfer** |

---

## D. The Real Consensus — what you actually have

### D.1 Mathematically

You have **one inequality with five terms**, every term anchored to a 2025–2026 result you can cite by arXiv ID. The leading constant is not 1 (the textbook softmax bound) but 1/2 (Nair, Oct 2025) — this is genuinely new and tightens every downstream argument by 2×. The most powerful single result you're standing on, paradoxically, is not yours but Qasim et al.'s *KV-Direct* (March 2026): **the KV cache is not state, it is a deterministic projection of residual stream**. This means your L1 is not "compressed K,V" but "compressed residual, K,V recomputed." That refactor is *clarifying*, not threatening, but it has to be reflected in the diagram and the write-up.

### D.2 Engineering-wise

You have a **defensible Apple-Silicon-native Rust stack** (`mlx-rs` 0.21.0, `objc2-metal`, UniFFI to Swift). You have **two actually-downloadable benchmark models** (`Qwen3-8B-MLX-4bit` and `cartesia-ai/mamba2-2.7b-4bit-mlx`). You have a **harness skeleton** with seven measurable thresholds and one binary falsifier (the SSM-Transformer 5 pp gap). You have a **realistic L4** because Hermes-4-405B exists and is open-weight. You do **not** yet have any Metal kernels written, any sketch code measured, or any KL number on real long-context input.

### D.3 What's testable when

| Horizon | Single concrete deliverable | Pass/fail |
|---|---|---|
| **7 days** | KV-Direct baseline (Qasim's reference impl, github.com/Kaleemullahqasim/KV-Direct, ported to MLX) on Qwen3-8B at 32k and 128k. Measure peak RAM, KL, tok/s. | If KV-Direct alone hits {KL<0.05, RAM<12 GB, ≥20 tok/s}, the lossy-sketch story is in trouble — pivot. If it misses any one, Helios has clear room. |
| **12 weeks** | L0+L1 shipped in Rust+MLX; WBO-5 measured term-by-term; two-track harness running; Sherry-on-residual KL ablation done. | All seven thresholds in C.3 above. SSM-Transformer gap measured. |
| **24 months** | MLSys paper accepted; public `helios-core` crate; either ANE bring-up (via ANEMLL/Orion) or formal pivot to "GPU-only on Mac" with a written rationale. | Reviewer accepts the WBO-5 inequality without major revisions; one external lab reproduces the KL<0.05 number. |

### D.4 Marketing vs. load-bearing

**Load-bearing** (cite in any external write-up): WBO-5, residual-as-side-info, GPTQ≡Babai, softmax-1/2-Lipschitz, Sherry 1.25-bit, FRP, sparse-JL, Wyner-Ziv nested-lattice, classical-shadows-inspired streaming sketch, test-time regression for SSM transfer.

**Marketing** (keep out of MLSys, fine for a fundraise deck): "VaultGatedSwarm," "Engram Index," "Hermes Cascade" as a brand name (the underlying *Hermes-4* model is real; the *Cascade* word is yours). "Helios" itself is fine as a product name but **collides with ShadowKV and KV-Direct in the literature** — see red-team below.

---

## E. Honest Red-Team Pass

### E.1 Where you embarrass yourself at MLSys

1. **Naming collision.** "Shadow" appears in (a) classical shadow tomography (HKP 2020), (b) Bytedance's **ShadowKV** (ICML 2025, arXiv:2410.21465 — *low-rank K cache, value offload, landmarks-and-outliers*; this is **already 80% of your L0–L2 boundary**), (c) your tier name. A reviewer will notice in 90 seconds. **Mitigation:** rename L2 to **"Sketch Tier"** in the paper; keep "Shadow Memory" as the program/product name; explicitly cite ShadowKV in related work and contrast on (i) residual-stream substrate, (ii) WBO-5 bound, (iii) SSM transfer.
2. **"Five-term Master Inequality" looks like reviewer bait.** If any one term cannot be measured cleanly term-by-term, the bound is not falsifiable. **Mitigation:** in §3 of the paper, *measure each term independently* on a held-out calibration set and show their sum upper-bounds observed `‖Δlogits‖`. If you cannot, drop the weakest term to a remark.
3. **FRP transfer is uncited for KV.** The paper is for in-context RL. A reviewer who reads carefully will see this. **Mitigation:** explicitly mark the FRP-for-KV claim as an *engineering bet* in the paper, with the ablation against Haar-orthogonal as the empirical justification.
4. **Sherry was designed for weights, not activations/residuals.** Same mitigation: ablate against NF4 and KVQuant 3-bit; report KL.
5. **The classical-shadows analogy is decorative unless you make it precise.** The HKP guarantee (O(log M) measurements) is for *quantum* states under *Haar-random Clifford* unitaries. Your sketch is *classical* under *FRP (free-orthogonal)*. Do not claim the HKP sample complexity. Cite the inspiration; do not borrow the bound.

### E.2 Where the architecture is most fragile

- **L1↔L2 boundary:** moving a token from "compressed residual" to "sketched only" is the eviction event. If the sketch loses information that residual still had, you get a *silent* quality drop that won't show in average KL but will show on retrieval-heavy benchmarks (RULER-N-MK2, NIAH multi-key). This is the same failure mode that kills InfiniGen and that ShadowKV explicitly designed around with landmarks + outliers. **You need a landmark-equivalent.** Likely candidate: keep the top-`k_outlier` (= 256?) channels of each token's residual at L1 precision even after L2 eviction.
- **L3 SSD path on macOS:** APFS + `mmap` + IOSurface is workable but not battle-tested for hot-path inference. If page-in latency exceeds budget, the L4 escalation rate spikes and your serving cost balloons.
- **Mamba-2 has no KV cache.** The "shadow" of an SSM is its recurrent state, not a key/value pair. The TTR framing (Wang-Shi-Fox 2501.12352) gives you the vocabulary but does not give you a free transfer. The two-track harness must measure SSM state-compression error in TTR's `(W, F, Opt)` triple, not by analogy.

### E.3 Who ships first

| Competitor | What they have | When they ship | Threat level |
|---|---|---|---|
| **Bytedance ShadowKV** | Low-rank K + offload V; ICML 2025; production-grade. CPU↔GPU, not Mac unified-memory. | Already shipped. | **HIGH** — same name family, overlapping mechanism. |
| **Microsoft RetrievalAttention** | ANNS over CPU-resident KV; 1–3% access rate. | Already shipped (NeurIPS 2024). | MEDIUM — orthogonal mechanism, similar promise. |
| **Microsoft RetroInfer (2505.02922)** | Wave-index attention-aware vector store. | 2025. | MEDIUM. |
| **KVSwap (2511.11907)** | Disk-aware KV offload; explicitly targets on-device long-context. | Nov 2025. | **HIGH** — on-device thesis overlaps yours. |
| **vLLM + FlashInfer** | FP8 KV-cache + FP8 attention; production default on B200/H100 in vLLM 2026.04 release. | Already shipped. | LOW for Mac, HIGH for the broader narrative. |
| **Apple itself (MLX-LM)** | KV in unified memory; no published lossy compression yet. | Could ship at any WWDC. | **EXTINCTION-LEVEL if WWDC '26 ships KV compression.** |
| **KV-Direct (Qasim 2603.19664)** | Bit-identical residual checkpointing; reference Python impl on GitHub. | Already shipped (March 2026). | **HIGH** — strictly stronger on quality; weaker on throughput (memory-bandwidth bound). Your differentiation is throughput + sketching for retrieval. |
| **DeltaKV (2602.08005)** | Residual-based KV compression with learned MLP projections. | Feb 2026. | MEDIUM. |
| **KV cache transform coding (2511.01815)** | Information-theoretic transform coding for KV. | Nov 2025. | MEDIUM — closest in *spirit* to your Wyner-Ziv framing. |

### E.4 Single biggest risk that collapses the 24-month plan

**Apple ships first-class lossy KV compression in MLX-LM at WWDC 2026.** If `mlx-lm` adds a `kv_compression="sketch"` or `="residual"` option, the Mac-native differentiation evaporates overnight and you are reduced to "the Rust version of MLX-LM with extra theory." You cannot prevent this, but you can hedge: (i) get the WBO-5 paper on arXiv *before* WWDC 2026 to establish priority on the inequality (the result is yours regardless of who ships the code); (ii) make sure the SSM track is real, because Apple has shown no interest in Mamba-2.

---

## F. What You Have — the four forms

### F.1 Two-line tweet

> Helios: a 5-tier KV memory hierarchy for Apple Silicon whose error is bounded by one inequality with five terms, every term a published 2025–26 result. Wyner-Ziv with the LM as side info; Babai = GPTQ; softmax = 1/2-Lipschitz; residual stream = the cache.

### F.2 The 30-second whiteboard pitch

> The KV cache is not state — Qasim et al. proved this March 2026. It's a deterministic projection of the residual stream. So we don't compress KV, we compress *residual*, with Sherry 1.25-bit, and recompute K,V on the fly. Above that we put a sparse-JL sketch over a Free-Random-Projection basis — that's our queryable "Shadow" tier — and below that an NF4 SSD oracle. The whole thing is bounded by a five-term Wyner-Babai inequality whose leading constant just got tightened from 1 to 1/2 by Nair's softmax-Lipschitz paper. We validate on two tracks: Qwen3-8B Transformer and Mamba-2 SSM, with a single falsifier — if SSM is more than 5 percentage points off Transformer on the same envelope, the test-time-regression generalization fails and we go back to the drawing board.

### F.3 One-paragraph summary for a hostile reviewer

> Helios Shadow Memory is a five-tier streaming memory hierarchy for long-context LLM inference on Apple Silicon. We model the KV cache as Wyner-Ziv source coding with the language model itself as the decoder-side information (Wyner-Ziv 1976; Erez-Zamir 2004). We replace the standard "softmax is 1-Lipschitz" assumption with the recent tight 1/2-Lipschitz bound (Nair, arXiv:2510.23012, October 2025), which immediately halves the propagated logit error in any KV-compression analysis. We treat weight quantization as Babai's nearest-plane algorithm on the input-Hessian lattice (Chen-Hoefler-Alistarh, ICLR 2026, arXiv:2507.18553), which gives a worst-case error bound rather than a heuristic. The information substrate is the residual stream, not K and V, leveraging the bit-identical reconstruction result of Qasim et al. (arXiv:2603.19664, March 2026). Compression at the residual level uses Sherry 1.25-bit ternary packing (Huang et al., ACL 2026, arXiv:2601.07892). The sketch tier uses sparse Johnson-Lindenstrauss embeddings (Kane-Nelson, *J. ACM* 2014) over a Free Random Projection basis (Hayase-Collins-Inoue, arXiv:2504.06983) and CountSketch (Charikar et al. 2002) for top-k page routing. Generalization to state-space models is via the Test-Time Regression framework (Wang-Shi-Fox, arXiv:2501.12352, 2025). The architecture is *inspired by* — but does not claim — the exponential quantum advantage of Zhao-Zlokapa-Neven-Babbush-Preskill-McClean-Huang's quantum oracle sketching (arXiv:2604.07639, April 2026); the quantum-classical separation does not transfer to a Mac, and the brief is explicit about this. The kernel is in Rust on `mlx-rs` + `objc2-metal`. The validation harness ships with a single binary falsifier: if the Mamba-2 track is more than 5 percentage points off the Qwen3-8B track on any of {KL, compression, top-k recall, RAM, throughput}, the generalization claim fails.

### F.4 The whiteboard sketch

See §C.1.

---

## G. Interdisciplinary Anchors (where they cut)

These are kept because they tighten claims, not because they decorate.

- **Predictive coding ↔ Wyner-Ziv.** The brain's residual error encoding (Rao-Ballard 1999; Friston 2010) is the same shape as encoding `r_t − f_θ(context)` and using `f_θ` as decoder side info. The LM *is* the predictive-coding cortex; KV residual *is* the prediction error. This is not analogy; it is the same diagram with different labels.
- **Hippocampal pattern separation ↔ L2 sketch.** Marr's CA3/dentate-gyrus model (1971) and McClelland-McNaughton-O'Reilly (1995) — sparse, high-dimensional codes for distinctive retrieval — are the biological precedent for sparse-JL with FRP-induced orthogonality. Aliasing rate `ρ_miss` is the pattern-completion error.
- **Classical shadows ↔ randomized measurements ↔ Bayesian inference.** HKP's median-of-means recovery is structurally a robust Bayesian estimator. Helios's L2 query is the classical analog: median-of-means over CountSketch buckets when reading a page.
- **AdS/CFT holographic dimension ↔ sketch dimension.** The Ryu-Takayanagi area law gives entanglement entropy as boundary area; the JL lemma gives sketch dimension as `O(ε⁻² log n)`. Both say "to preserve correlations, you need polynomial-in-log resources." The analogy is suggestive, not load-bearing — *do not put this in the paper*.

---

## H. The Single Sharpest Next Move

**Run the KV-Direct baseline on Qwen3-8B-MLX-4bit at 128k context this weekend.**

Specifically:
1. `git clone https://github.com/Kaleemullahqasim/KV-Direct`
2. Port the residual-checkpoint hot loop to MLX on `mlx-community/Qwen3-8B-4bit` (the bit-identical-reconstruction result is architecture-agnostic; only the `recompute_kv(residual, layer)` call needs MLX-style autograd-free ops).
3. Run on a 128k-token RULER NIAH-multi-key prompt. Measure: peak resident RAM, KL vs full-cache reference, decode tok/s.

**Why this is the move.** Every other path you could take this weekend (writing a Sherry kernel, sketching FRP in Metal, drafting the MLSys outline) is a bet on a story whose outcome you can settle empirically in 48 hours. KV-Direct is, mathematically, *the strongest possible* lossy-zero baseline for Helios's L0+L1: it gives you bit-identical output at ~5 KB/token instead of 136 KB/token (27× memory reduction on Gemma-3-4B; will be similar on Qwen3-8B). If KV-Direct alone meets your 12 GB / KL<0.05 / ≥20 tok/s envelope at 128k, then the WBO-5 *lossy* compression story has nowhere to go for memory and must reposition entirely around (a) throughput (the sketch tier accelerates retrieval, not memory) and (b) the SSM track (where there is no residual stream and the analysis is genuinely new). That's still a real paper, but it is a *different* paper than the one you've been writing.

**Binary outcome.**

- **CONTINUE (the WBO-5 lossy compression story stands)** if any one of: peak RAM > 12 GB, KL > 0.05, or tok/s < 20. Then Helios has clear differentiation: KV-Direct is bandwidth-bound at long context; your sketch tier removes the recomputation by serving from L2 directly.
- **PIVOT (story restructures around sketch+SSM, not lossy compression)** if KV-Direct alone hits all three thresholds. Then the pitch becomes: "Helios uses KV-Direct as L0+L1, adds a queryable sketch tier above it, and is the first system to prove the same bound carries over from Transformer to Mamba-2 via test-time regression." That's still publishable, still load-bearing, still yours — but it is not what the prior seven turns built.

Either way, you will know by Monday.

---

## Caveats

- **Date sensitivity.** Several anchor papers (Qasim 2603.19664; the quantum oracle sketching paper 2604.07639; KVSwap 2511.11907; HeteroCache 2601.13684; Sherry 2601.07892) are from late 2025 / early 2026 and have arXiv IDs in the 2511-2604 range. They are real and verified, but the literature is moving every week; before submission, re-pull the latest versions.
- **The "Hermes Cascade" naming.** "Hermes" is NousResearch's trademark in the open-weight LLM space. If you ship a product literally named "Hermes Cascade," you are inviting a trademark conversation. Use it internally; rename for any commercial release.
- **"Helios" itself.** No conflicting AI-systems trademark surfaced in this pass, but the name is generic enough that a clearance check is warranted before any logo work.
- **Free Random Projection's KV transfer is unproven.** The paper is rigorous; its application to KV/residual sketching is not in the literature. Mark this as engineering-bet C1 in every external document.
- **Apple Neural Engine path is contingent.** ANEMLL is beta; Orion uses private APIs. Do not commit to ANE on any month-12-or-earlier slide.
- **The five-term inequality has not been jointly verified term-by-term in code.** Each term is anchored to a paper; the *sum* bounding observed `‖Δlogits‖` is the empirical claim that has to be measured in the 12-week harness. Until then, treat WBO-5 as a *theorem about its terms*, not yet a *measured upper bound*.
- **ShadowKV name collision is real and unmitigated until you rename L2.** Do this before any fundraise deck or arXiv preprint.
- **One-author limitation.** This consensus document was assembled by a single research pass over the open web; it has not been adversarially reviewed by an independent reader. The next move (the KV-Direct measurement) is itself the first adversarial review.

---

*End of consensus document. Read at 3am. Build accordingly.*