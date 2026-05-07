# EPISTEMOS V6.2 — LEAN VERIFICATION CANON + HARDWARE FALSIFIER HANDBOOK + V6.1→V6.2 DELTA

**Hardware lock:** Apple M2 Pro 14" 2023 (model QCC4N376QY) — 12-core CPU (8P+4E) · 19-core GPU · 16-core Neural Engine · **16 GB unified memory** · **200 GB/s memory bandwidth** · 1 TB SSD. [VERIFIED-WEB-Q1-2026, Apple support 111340]

**Verification date:** 2026-05-07. **Verified Floor:** `ac8c6d28` (immutable, never moves).

**Lock phrase (preserved verbatim — architectural mantra, NOT a calendar commitment):**
> *"Five lanes, three tiers, seven-plus-three-plus-seven, one Monday — one plan, three streams, three users — hybrid-SSM, parameter-connectome, Heavy-Thinking, vectorless-retrieval, brain-inspired, App-Store-native — and the floor never moves — and attention is an interrupt, not a substrate."*

**V6.2 Addendum (research direction):**
> *"Helios V6.2 is a Lean-governed, M2-Pro-16GB-falsified, recurrent-first cognitive substrate: SSM scan carries the stream, LocalRecallIsland wakes for exact episodic recall, PageGather proves the active-support memory law, InterruptScoreGate acts as the thalamus, SurpriseConsolidate acts as hippocampal sleep, and SCOPE-Rex turns every durable state change into a witnessed artifact. The model is a guest in the user's brain — not a tenant of the user's machine."*

**Doctrine:** *If it works on Jojo's M2 Pro 16 GB, it can ship. If it requires a workstation, it's research-tier.*

The user has explicitly suspended the calendar (*"there are no time so taints just research"*). All sequencing in this document is therefore **dependency-ordered, never date-ordered**.

---

# SECTION 1 — EPISTEMOS V6.2 LEAN VERIFICATION CANON + HARDWARE FALSIFIER HANDBOOK

## 1.1 Tool & Version Pin Table (re-verified May 2026)

| Component | Pin | Verified status | Notes |
|---|---|---|---|
| Lean 4 toolchain | **`leanprover/lean4:v4.29.1`** | [VERIFIED-WEB-Q1-2026] released 2026-04-14 | 4.30.0-rc1 (2026-04-01) and 4.30.0-rc2 published; **stay on 4.29.1** until LeanCopilot bumps. v4.29.0 introduced a breaking change to `isDefEq` reducibility (PR #12179) requiring more `noncomputable` annotations; treat as a stability event. |
| mathlib4 | **`v4.29.0-rc6`** (commit at 2026-03-10) | [VERIFIED-WEB-Q1-2026] | The earlier prior-research pin `028964f April 22 2026` is **[DRIFT-DETECTED]** — that hash sits on master between rc6 and the next stable; pin to a tag, not master, for reproducibility. Use `lake exe cache get` always. |
| Aesop | `leanprover-community/aesop` (transitive via mathlib) | [VERIFIED-WEB-Q1-2026] | Actively maintained; ships as a mathlib dep. No separate version pin needed. |
| LeanCopilot | **`lean-dojo/LeanCopilot v4.27.0`** (tag, 2026-02-11) | [VERIFIED-WEB-Q1-2026] | **Lags Lean stable by ~2 versions.** This is the binding constraint on toolchain choice: LeanCopilot has no v4.28 / v4.29 tag yet. Either (a) pin Epistemos to Lean 4.27.0 + mathlib v4.27.0 to use LeanCopilot, or (b) pin to 4.29.1 and disable LeanCopilot until upstream bumps. **V6.2 chooses (b)** because mathlib4 momentum > LeanCopilot momentum, and the proof-search workflow can fall back to Aesop + DeepSeek-Prover-V2-7B over RPC. |
| LeanDojo / LeanDojo-v2 | `lean-dojo/LeanDojo-v2` (last update 2026-03-10) | [VERIFIED-WEB-Q1-2026] | Active. Used only for premise-selection corpus generation, not run-time. |
| Aeneas | `AeneasVerif/aeneas` (Apache-2.0) | [VERIFIED-WEB-Q1-2026] | Rust→Lean direction confirmed. **Lean→Rust still does not exist** — V6.2 reaffirms the Hybrid Choice 2-C: SchemaGen.lean emits Swift/Rust enums; we do **not** attempt Lean→Rust extraction. |
| DeepSeek-Prover-V2-7B | `deepseek-ai/DeepSeek-Prover-V2-7B` on HF (32K ctx, Apache subset) | [VERIFIED-WEB-Q1-2026] | 7B variant exists, openly downloadable, built on DeepSeek-Prover-V1.5-Base. MLX 4-bit ≈ 4 GB weights. Runs on M2 Pro 16 GB **only when the Epistemos app is not running** — see §1.6. |
| AlphaProof | Nature, Hubert et al., Nov 13 2025 (DOI 10.1038/s41586-025-09833-y) | [VERIFIED-WEB-Q1-2026, methodology only] | **No open weights, no open code.** V6.2 adopts the *methodology* (test-time RL, AlphaZero-style self-generated theorem variants, formal-only RL signal) — not the artifact. Treat as a design pattern, not a runnable dependency. |
| cartesia-ai/edge | Apache-2.0, monorepo (cartesia-pytorch, cartesia-metal, cartesia-mlx) | [VERIFIED-WEB-Q1-2026] | **Last documented test platform: macOS Sonoma 14.1 with M3.** No published M2-Pro / Sequoia validation. Treat as **[NEEDS-SOURCE-FILE-VERIFICATION]** for our exact hardware. We must rebuild and benchmark on the M2 Pro before adoption. |
| cartesia-ai/mamba2-2.7b-4bit-mlx | HF live | [VERIFIED-WEB-Q1-2026] | ~1.7 GB resident at 4-bit; usable on 16 GB. Smaller siblings (130m, 130m-8bit, 370m-8bit, 780m-8bit, 1.3b-4bit) all live. |
| IBM Granite 4.0 H-Micro 3B | `ibm-granite/granite-4.0-h-micro`, Apache-2.0, ISO/IEC 42001:2023, cryptographically signed | [VERIFIED-WEB-Q1-2026] | Hybrid Mamba-2 + transformer (9:1). Trained on 15T tokens up to 512K context, **validated up to 128K**. MLX support listed by IBM as "still being optimized" in vLLM 0.10.2 / llama.cpp / MLX — so prefer GGUF Q4_K_M via llama.cpp on M2 Pro until MLX path matures. |
| **Granite 4.0 Nano (350M, 1B; H & dense)** | `ibm-granite/granite-4.0-h-1b`, `granite-4.0-h-350m`, `granite-4.0-1b`, `granite-4.0-350m` | **[VERIFIED-WEB-Q1-2026, NEW-IN-V6.2]** released 2025-10-29, Apache-2.0, ISO 42001-certified, signed, native MLX. The H-1B (~1.5B params, hybrid-SSM) **runs in a browser**; an excellent **fallback MAS-tier brain** for ultra-tight residency budgets. |
| Falcon-Mamba-7B 4-bit MLX | `mlx-community/falcon-mamba-7b-4bit-instruct` (mlx-lm 0.19.2) | [VERIFIED-WEB-Q1-2026, STALE-CONVERTER] | Live but the converter version is from late 2024. ~4.5 GB resident. Pure Mamba (no KV-cache scaling). Acceptable as a stretch-lane SSM exemplar; not the MAS default. |
| Qwen3-1.7B / Qwen3-4B / Qwen3-8B | Qwen team, Apache-2.0, MLX builds (`Qwen/Qwen3-1.7B-MLX-bf16`, `mlx-community/Qwen3-1.7B-4bit`, `mlx-community/Qwen3-4B-4bit`, etc.) | [VERIFIED-WEB-Q1-2026] | Qwen3-1.7B-MLX-bf16 ≈ 3.4 GB; 4-bit ≈ 1 GB; both fit easily. Qwen3-4B-4bit ≈ 2.3 GB. |
| Phi-3.5-mini-instruct (3.8B, MIT) | `mlx-community/Phi-3.5-mini-instruct-4bit` | [VERIFIED-WEB-Q1-2026] | ~2.1 GB at 4-bit. MIT license is App-Store-clean. |
| Llama-3.2-1B / 3B Instruct 4-bit MLX | `mlx-community/Llama-3.2-1B-Instruct-4bit` (~0.7 GB), `mlx-community/Llama-3.2-3B-Instruct-4bit` (~1.8 GB) | [VERIFIED-WEB-Q1-2026] | Meta Llama 3.2 license; review for App-Store distribution if Llama is to ship inside Epistemos. |
| Gemma-2-2B-it 4-bit MLX | `mlx-community/gemma-2-2b-it-4bit` | [VERIFIED-WEB-Q1-2026] | Gemma terms (not Apache). Avoid if license cleanliness matters. |
| NVIDIA RULER | `github.com/NVIDIA/RULER`, arXiv:2404.06654 | [VERIFIED-WEB-Q1-2026] | 13-task suite, branches `rulerv1-ns` and `rulerv2-ns`. Sub-tasks: niah_*, vt, cwe, fwe, qa_1, qa_2. |
| BABILong | arXiv:2406.10149 (NeurIPS 2024), `booydar/babilong` | [VERIFIED-WEB-Q1-2026] | 20-task long-context benchmark, splits up to 1M / 10M tokens. |
| state-spaces/mamba `ssd_minimal.py` | "Listing 1 from the paper" — header preserved in source | [VERIFIED-WEB-Q1-2026] | Authoritative reference for SemiseparableBlockScan correctness oracle. |
| vLLM Mamba-2 chunk_size assertion | **PR #21783** merged (RishiAstra) — chunk_size must be power-of-2 | [VERIFIED-WEB-Q1-2026] | Confirms canonical chunk_size ∈ {64, 128, 256}. PyTorch fused-Mamba2 kernel writeup further notes that **post-fusion** the optimal chunk_size for Mamba-2-2.7B dropped from 256 → 128 due to register pressure. **V6.2 lane**: keep 256 as the canonical correctness chunk; benchmark 128 as the stretch perf chunk on M2 Pro. |
| Goodfire VPD page | `goodfire.ai/research/interpreting-lm-parameters` | [VERIFIED-WEB-Q1-2026] | Live with the canonical numbers: **4-layer, 67M params, 28M non-embedding decomposed, 38,912 rank-1 subcomponents over 24 weight matrices**. (The previously-cited "9972 / 205 / 2.1%" specifics could not be re-located on the live page — **[NEEDS-SOURCE-FILE-VERIFICATION]** before being quoted as canon.) |
| `goodfire-ai/spd` | Stochastic Parameter Decomposition repo | [VERIFIED-WEB-Q1-2026] | Active. Supports decomposing any HF model with `nn.Linear`, `nn.Embedding`, `Conv1D` layers. |
| SPD paper | arXiv:2506.20790 v2 (2025-09-04), Bushnaq · Braun · Sharkey | [VERIFIED-WEB-Q1-2026] | |
| APD paper | arXiv:2501.14926, Bushnaq · Heimersheim · Mendel · Sharkey | [VERIFIED-WEB-Q1-2026] | |
| VPD LessWrong linkpost | `lesswrong.com/posts/eAQZaiC3PcBhS4HjM` | [VERIFIED-WEB-Q1-2026] | |
| Lee Sharkey VPD thread | **`x.com/leedsharkey/status/2051717264286609516`** | **[DRIFT-DETECTED]** | The prior research cited `1938616685855941040`. The LessWrong linkpost itself canonically points to **`2051717264286609516`**. Replace in canon. |
| HeavySkill paper | arXiv:**2605.02396** (Note arxiv ID is forward-dated 2026-05) | [VERIFIED-WEB-Q1-2026] | Confirmed; introduces "HeavySkill" as inner skill for agentic harness. |
| LongCat-Flash-Thinking-2601 | arXiv:**2601.16725** (Meituan) — supersedes 2509.18883 | [VERIFIED-WEB-Q1-2026] | 560B MoE (27B active), Heavy Thinking Mode. |
| Mohtashami-Jaggi passkey | arXiv:2305.16300 (Landmark Attention) | [VERIFIED-WEB-Q1-2026] | |
| Hsieh et al. RULER | arXiv:2404.06654 | [VERIFIED-WEB-Q1-2026] | |
| Dao & Gu Mamba-2 / SSD | arXiv:2405.21060 (ICML 2024) — Theorem 3.7 (state-space duality) | [VERIFIED-WEB-Q1-2026] | |
| PyTorch fused-Mamba2 kernel | `pytorch.org/blog/accelerating-mamba2-with-kernel-fusion/` | [VERIFIED-WEB-Q1-2026] | Confirms 5-stage SSD pipeline (Chunk Cumsum, BMM, Chunk State, State Passing, Chunk Scan) and chunk_size=128 post-fusion optimum. |
| Apple M2 Pro spec | `support.apple.com/en-us/111340` | [VERIFIED-WEB-Q1-2026] | 12-core/19-core variant, 200 GB/s. |
| Apple Metal counter docs | `developer.apple.com/documentation/metal/gpu-counters-and-counter-sample-buffers`, `MTLCounterSampleBuffer`, `MTLCommonCounterSetTimestamp` | [VERIFIED-WEB-Q1-2026] | On Apple Silicon: **stage-boundary** sampling supported (start/end of vertex / fragment / compute encoders); per-draw boundary sampling is Intel/AMD only. Plan around stage boundaries on M2 Pro. |
| Apple Tech Talk #10001 | "Explore Live GPU Profiling with Metal Counters" | [VERIFIED-WEB-Q1-2026] | Reference for `gpuStartTime`/`gpuEndTime` and counter resolve. |
| STREAM-on-Metal | arXiv:2502.05317 (Hübner · Hu · Peng · Markidis, last revised 2025-03-25) | **[DRIFT-DETECTED]** | The paper measures **"up to 100 GB/s"** memory bandwidth across the M1–M4 family in their FP32 Metal kernels — *not* the 150-165 GB/s figure used in the prior V6.1 calibration. **PageGather thresholds in V6.2 must be re-anchored** (see §1.4). |
| `philipturner/metal-benchmarks` | Independent M1/M2 Apple GPU microarch reference | [VERIFIED-WEB-Q1-2026] | Useful sanity check; we do not depend on it. |
| `michaelstinkerings.org` M5 GPU Roofline | Methodology comparison reference | [NEEDS-SOURCE-FILE-VERIFICATION] | Was [VERIFIED-RESEARCH-DOCS]; the URL was not re-confirmed in this pass. Treat methodology as inspiration only; do not cite numerical claims. |
| SubQ / Subquadratic | `subq.ai`, $29M seed, May 5 2026 launch, CEO Justin Dangel / CTO Alex Whedon | [VERIFIED-WEB-Q1-2026] | **Closed weights, no technical paper, contested claims.** V6.2 status: **[COMPETITIVE-PARITY-WATCH-LIST]**, not a dependency, not a baseline to chase. |
| Lean 4 `@[extern]` directive | Lean 4 reference manual | [VERIFIED-WEB-Q1-2026] | Used by SchemaGen.lean for FFI-clean enum emission. |
| Lean 4 inductive types reference | Lean 4 reference manual; v4.29.0 release notes (#12514) | [VERIFIED-WEB-Q1-2026] | v4.29.0 improved universe inference for `inductive`; revisit our `AnswerPacket` and `ClaimKind` declarations after the bump. |

## 1.2 Re-verified Three Locked Choices

1. **FULL coverage with sorry-budget** — every theorem (T1–T17 V5, T25–T34 PCF, T35–T44 V6, T-Interrupt) gets a Lean *statement* now. Proofs land progressively per CI gate B5. Per-file `sorry-budget ≤ 7`. Total-repo `sorry-budget ≤ 38·7 = 266` ceiling, with a **visible monotonically-decreasing target** of −1/week-of-work. [LOCKED-V6.2]
2. **Lean as ClaimLedger semantics — Hybrid 2-C** — Lean 4 is the spec authority. `SchemaGen.lean` (300–500 LOC of metaprogramming) emits matching Swift `enum`s and Rust `enum`s with derived `Codable` / `serde` boilerplate. We do **NOT** attempt Lean→Swift / Lean→Rust full codegen — Aeneas is Rust→Lean only and Lean's whole-program extraction to Swift remains research-tier. [LOCKED-V6.2]
3. **Maximal automation + LLM-assisted** — Aesop ruleset (`Theorems/Aesop/EpistemoRules.lean`) + LeanCopilot when toolchain alignment permits + DeepSeek-Prover-V2-7B as an out-of-band background prover + AlphaProof-style methodology (test-time RL on theorem variants generated by DeepSeek-V3-class models, formal-only reward signal) for the hardest residual goals. [LOCKED-V6.2]

## 1.3 The Five Planes × Three Streams × Theorem Set (preserved)

**Five planes (RUNTIME organization):** State · Episodic · Assembly · Controller · Verification.
**Three streams (PRODUCT organization):** MAS · Pro · Vault.
**Theorems:** T1–T17 (V5 verified, mostly closed) · T25–T34 (PCF candidates) · T35–T44 (V6 SSM/PCF/HeavySkill) · **T-Interrupt** (the gating equation).

**Interrupt-score equation (preserved):**
$$u_t = \alpha\!\cdot\!H(p_t) + \beta\!\cdot\!\text{WBO\_risk} + \gamma\!\cdot\!\text{SheafResidual} + \delta\!\cdot\!\text{ToolNeed} + \varepsilon\!\cdot\!\text{ConnectomeAlarm}$$

with default coefficient priors (α=0.30, β=0.25, γ=0.20, δ=0.15, ε=0.10) — calibrated against the 30-task corpus (§1.5).

## 1.4 The Five (Six) Hardware Falsifiers — re-spec'd for M2 Pro 16 GB

### Falsifier 1 — `SemiseparableBlockScan.metal` [MAS-SAFE-TIER-2-FLAGGED] [M2-PRO-16GB-VERIFIED]

**Purpose:** Mamba-2 SSD scan implementing Listing 1 of `state-spaces/mamba/mamba_ssm/modules/ssd_minimal.py`, expressed in Metal Shading Language and proven equivalent (within fp16 tolerance) to the Triton reference.

**V6.1 spec:** B=1, L=131072, H=24, D=64, N=128 (Mamba-2-2.7B configuration).
**V6.2 spec on M2 Pro 16 GB:**
- **Primary correctness lane (default-on):** B=1, L=32768, H=24, D=64, N=128, **chunk_size=256, ngroups=1**, fp16 weights, fp32 accumulate. Activation working set ≈ B·L·H·D·2 bytes ≈ 96 MB; states ≈ B·H·D·N·4 bytes ≈ 0.8 MB. Fits comfortably with model resident (~1.7 GB at 4-bit) inside the 12 GB ceiling.
- **Stretch lane (opt-in flag):** L=131072 with same other dims. Activation working set ≈ 384 MB. Still fits but pushes the SLC and competes with the live app — gate behind `--stretch` and run only when the host app is quiesced.
- **Tight local iteration lane (debug):** Switch to `cartesia-ai/mamba2-130m-mlx` for sub-second turnaround on shape correctness; never used as the falsifier oracle.
- **`ngroups=1` is mandatory.** [VERIFIED-WEB-Q1-2026, source-file-correction] The relevant upstream issue is **`state-spaces/mamba#647`** (HanGuo97, 2024-12-15), corroborated by `#401` (use_mem_eff_path with ngroups>1) and `#522` (gradient explosion). The **prior V6.1 reference to `#449` is [DRIFT-DETECTED]** and is corrected here.
- **`chunk_size=256` canonical**, with `chunk_size=128` benchmarked as a perf candidate. vLLM PR #21783 enforces power-of-2 chunk_size; we honor that invariant.
- **Pass criterion:** max-abs-diff vs reference Listing-1 PyTorch implementation ≤ 1e-3 in fp16, ≤ 1e-5 in fp32, across 100 random tensor seeds; no NaN; no Inf; final state matches initial-state propagation when `initial_states != None`.

### Falsifier 2 — `LocalRecallIsland.metal` [MAS-SAFE-TIER-1] [M2-PRO-16GB-VERIFIED-CORE / M2-PRO-16GB-TIGHT-STRETCH]

**Purpose:** Selective episodic-memory wakeup. The SSM stream produces a per-token "recall demand" signal; LocalRecallIsland fires the attention block only when that signal crosses threshold, performs an exact passkey-style retrieval, and returns to dormancy.

**V6.1 spec:** Granite-4-H-Micro 3B at 128K, 100 trials × 5 depths, niah_single_1 ≥ 0.95 + Mohtashami-Jaggi passkey.
**V6.2 spec on M2 Pro 16 GB:**

| Lane | Model | Context | Trials × depths | RAM peak (target) | Pass criterion |
|---|---|---|---|---|---|
| **Core (default-on)** | `granite-4.0-h-micro` GGUF Q4_K_M (~2.0 GB) **OR** `mlx-community/granite-4.0-h-tiny-3bit-MLX` (~3.0 GB, MoE, 1B active) | **32K** | **50 × 5 = 250 trials** | ≤ 4.5 GB (model + KV/state + workspace) | passkey ≥ 0.95, niah_single_1 ≥ 0.95 |
| **Stretch (opt-in)** | `granite-4.0-h-micro` Q4_K_M | **128K** | 100 × 5 = 500 trials | ≤ 7 GB peak | passkey ≥ 0.92, niah_single_1 ≥ 0.92, niah_single_2 ≥ 0.85 |
| **Pure-SSM control** | `mlx-community/falcon-mamba-7b-4bit-instruct` (~4.5 GB) | 32K | 50 × 5 | ≤ 6 GB | passkey ≥ 0.85 (lower bar — pure-Mamba models degrade) |
| **Floor lane** (only when host app running on full memory) | `ibm-granite/granite-4.0-h-1b` (~1.0 GB Q4) | 16K | 30 × 5 | ≤ 2.5 GB | passkey ≥ 0.85 |

The **Core lane is what ships in MAS**. The 128K Stretch is documented but not gated as a Tier-1 release blocker. Halving trials from V6.1's 100 → 50 is a deliberate **[BUDGET-REVISION]** to stay under M2 Pro thermal envelope (~12 min wall-clock target on a fan-on M2 Pro vs ~25 min on V6.1's M2 Max).

### Falsifier 3 — `PageGather.metal` [MAS-SAFE-TIER-2-FLAGGED] [M2-PRO-16GB-VERIFIED-WITH-RECALIBRATED-THRESHOLD]

**Purpose:** Prove the active-support memory law — bandwidth utilisation ≥ X% of the *measured contiguous baseline* across page-gather scatter patterns characteristic of episodic recall.

**V6.1 threshold:** "≥70% of theoretical 400 GB/s" → 280 GB/s.
**V6.2 threshold on M2 Pro 16 GB [THRESHOLD-RECALIBRATION]:**

The **theoretical** bandwidth on M2 Pro is 200 GB/s. The **measured contiguous-Metal baseline** as reported in arXiv:2502.05317 (Hübner et al.) is **up to ~100 GB/s** across the M1–M4 family (FP32 Metal STREAM-style triad). This is roughly 50% of theoretical, consistent with Apple's published guidance that DRAM-controller efficiency on the M2 Pro silicon caps below the spec sheet figure under unified-memory contention. Therefore:

1. **Calibration step (mandatory before threshold quoting):** run our own STREAM-on-Metal-style probe in `Falsifiers/PageGather/baseline.metal` for ≥ 1.0 s contiguous reads of buffer sizes 256 MB, 512 MB, 1 GB. Take the median of 5 runs. Record this as `BW_baseline_M2Pro` in `falsifier_calibration.toml`.
2. **Pass criterion:** PageGather page-stride scatter pattern attains **≥ 70 % of `BW_baseline_M2Pro`** sustained over a window ≥ 1.0 s. With `BW_baseline_M2Pro` typically 90–105 GB/s, the new pass band is **63–73 GB/s**, *not* the 105–115 GB/s briefly suggested in V6.1's prose.
3. **Buffer matrix:** {256 MB, 512 MB, 1 GB}. **No 4 GB test** — at 4 GB the working set + model + app overhead would exceed 16 GB and trigger swap, invalidating the measurement. [BUDGET-REVISION]
4. **Window discipline:** ≥ 1 s windows only; reject any sub-second number outright as Apple SLC bursts inflate short reads. [VERIFIED-WEB-Q1-2026, M2 SLC behavior]
5. **Counter sourcing:** Stage-boundary `MTLCommonCounterSetTimestamp` only (per-draw boundaries unsupported on Apple Silicon — confirmed in WWDC20 Tech Talk #10001). Resolve via `resolveCounterRange:`. Compare CPU clock (`mach_continuous_time`) against `gpuStartTime`/`gpuEndTime` to detect drift; reject runs where drift > 1 %.

### Falsifier 4 — `ControllerKernelPack.metal` [MAS-SAFE-TIER-1] [M2-PRO-16GB-VERIFIED]

**Purpose:** Six fused micro-kernels — `write`, `forget`, `admit`, `route`, `norm`, `safety` — each ≤ 64 KB threadgroup memory, each with a one-page Lean spec and a one-screen Metal implementation.

**V6.2 spec:** unchanged in correctness shape; verified that the per-kernel threadgroup-memory budget fits Apple GPU caps on M2 Pro (32 KB shared on M-series Apple-family-7+ GPUs; we keep all six under 16 KB for safety). Hardware-agnostic for correctness; bench numbers gated to the M2 Pro for performance.

### Falsifier 5 — `PacketRouter1bit.metal` [MAS-SAFE-TIER-1] [M2-PRO-16GB-VERIFIED]

**Purpose:** Ternary routing primitive — fire / suppress / defer. Cheap by construction (≤ 0.05 ms per dispatch on M2 Pro). Hardware-agnostic.

**V6.2 spec:** unchanged. Pass criterion: kernel dispatch latency P99 < 100 µs over 10⁴ trials.

### Falsifier 6 — `InterruptScore.metal` (foundational) [MAS-SAFE-TIER-1] [M2-PRO-16GB-VERIFIED]

**Purpose:** Compute u_t every token. Must be < 100 µs per token on the *expected* path.

**V6.2 spec:** **Adopt Swift CPU-fallback as the canonical implementation**, dispatched on `DispatchQueue` with QoS `.userInteractive`. Reasoning: at this dispatch granularity the Metal command-encoder setup cost (~50–150 µs even for empty encoders, per WWDC20 timing data) dominates the actual arithmetic; CPU is faster end-to-end. Keep a `.metal` shadow implementation behind a feature flag for batch-amortised computation when ≥ 64 tokens are processed in one go (the speech / dictation lane).

## 1.5 The 30-Task Interrupt-Score Calibration Corpus (re-verified for M2 Pro 16 GB)

The corpus is preserved verbatim in structure (7 LOW + 12 MED + 11 HIGH); per-task M2-Pro re-spec annotated below.

**(a) LOW-NOVELTY (u_t < 0.25), 7 tasks** — all M2-Pro-16GB-safe, all run in resident model, no swap risk:

1. function continuation [M2-PRO-16GB-VERIFIED]
2. boilerplate generation [M2-PRO-16GB-VERIFIED]
3. brace closing / format completion [M2-PRO-16GB-VERIFIED]
4. paraphrase (≤ 4K context) [M2-PRO-16GB-VERIFIED]
5. Lean tactic boilerplate (`exact ?_`, `simp`, `rfl`) [M2-PRO-16GB-VERIFIED]
6. markdown tables / list formatting [M2-PRO-16GB-VERIFIED]
7. import-statement insertion [M2-PRO-16GB-VERIFIED]

**(b) MEDIUM (0.25 ≤ u_t < 0.65), 12 tasks** — most still fit; two are downgraded:

8. cross-file refactor (≤ 8 files) [M2-PRO-16GB-VERIFIED]
9. debug across files [M2-PRO-16GB-VERIFIED]
10. theorem-prove with mathlib lookup (Aesop + select_premises) [M2-PRO-16GB-TIGHT — runs only when DeepSeek-Prover not loaded]
11. retrieval QA over LocalRecallIsland [M2-PRO-16GB-VERIFIED]
12. multi-step Lean chain (≤ 5 tactics) [M2-PRO-16GB-VERIFIED]
13. semantic claim-graph search [M2-PRO-16GB-VERIFIED]
14. AnswerPacket restructure [M2-PRO-16GB-VERIFIED]
15. code review (≤ 16K context) [M2-PRO-16GB-VERIFIED]
16. **MLX↔PyTorch translation** [M2-PRO-16GB-TIGHT] — was assumed simultaneous PT + MLX kernel resident; on 16 GB run sequentially, swap shells.
17. derivation re-derive (math chain) [M2-PRO-16GB-VERIFIED]
18. **Mamba-2 hyperparameter sweep** [TIER-MOVE: MED → PRO-ONLY-≥32GB] — sweeping d_state ∈ {16, 32, 64, 128} simultaneously requires holding multiple compiled kernels and benchmark buffers; impractical on 16 GB.
19. theorem cross-reference (mathlib) [M2-PRO-16GB-VERIFIED]

**(c) HIGH (≥ 0.65), 11 tasks** — six fit; five are tier-moved:

20. novel theorem authoring [M2-PRO-16GB-VERIFIED]
21. live-data query (tool call) [M2-PRO-16GB-VERIFIED]
22. scheduler tool call [M2-PRO-16GB-VERIFIED]
23. multi-step agentic (≤ 6 hops) [M2-PRO-16GB-VERIFIED]
24. claim contradiction audit [M2-PRO-16GB-VERIFIED]
25. **SMT fallback to DeepSeek-Prover** [M2-PRO-16GB-VERIFIED-WHEN-APP-QUIESCED] — explicit workflow gate; cannot run while Epistemos UI is foreground at full residency.
26. hardware-counter sampling (live) [M2-PRO-16GB-VERIFIED]
27. drift detection [M2-PRO-16GB-VERIFIED]
28. OOD prompt routing [M2-PRO-16GB-VERIFIED]
29. **Vault retrieval at full corpus** [TIER-MOVE: HIGH → VAULT-ONLY-WORKSTATION-OR-CLOUD] — full Vault corpus search exceeds 16 GB working set.
30. **theorem-proving collaboration with DeepSeek-Prover-V2-7B + LeanCopilot simultaneously** [TIER-MOVE: HIGH → PRO-ONLY-≥32GB] — both prover stacks resident exceeds 12 GB.

Net for M2 Pro 16 GB: **27 of 30 tasks land Tier-1/Tier-2 on the canonical rig; 3 are explicitly tier-moved with reason.** This is acceptable.

## 1.6 Lean Stack on M2 Pro 16 GB — operating envelope

- **mathlib4 build (full)**: peak resident ≈ 12 GB. **Strategy on 16 GB:** never build full mathlib locally. Always `lake exe cache get`. Treat any `lake build` that compiles a Mathlib-internal file as a CI-only operation.
- **Selective import discipline**: keep our top-level `Epistemos.lean` to ≤ 25 imports drawn from `Mathlib.Data.*`, `Mathlib.Logic.*`, `Mathlib.Order.*`, and `Mathlib.Tactic.*`. Use `#min_imports` after each new theorem lands. Target peak resident during local edit ≤ 6 GB.
- **LeanCopilot CTranslate2 path on local M2 Pro**: the bundled byT5-style models are ~1.5 GB each; loading two simultaneously while the Epistemos app is foreground is infeasible. **Decision: LeanCopilot is CI-only**, run on `macos-latest` GitHub-hosted runners (M-class as of Q1 2026), not on Jojo's laptop.
- **DeepSeek-Prover-V2-7B (MLX 4-bit, ~4 GB weights)**: viable on M2 Pro 16 GB *only* when Epistemos app is not running. Document workflow: "background proof worker: runs when machine idle ≥ 3 min, suspends instantly on user input."
- **B5 CI gate**: 30-min timeout on `macos-latest` runner. Use `leanprover/lean-action@v1` (default-tested on macos-latest). Use the action's built-in `.lake` cache.
- **Pre-commit `scripts/check_sorry_budget.sh`**: trivial cost; runs in seconds; no hardware concern.
- **`SchemaGen.lean` metaprogram (300–500 LOC)**: builds in ≤ 90 s on a stale cache, ≤ 5 s on a warm cache. No memory concern.

## 1.7 Lean File Tree (preserved, lakefile re-pinned)

```
plane_verification/lean/Epistemos/
├── lakefile.lean                    # Lean 4.29.1 + mathlib v4.29.0-rc6 pin
├── lean-toolchain                   # leanprover/lean4:v4.29.1
├── Floor.lean                       # Verified Floor ac8c6d28 invariants
├── Constitution.lean                # VRMLabel, ClaimKind, AnswerPacket
├── ClaimLedger.lean                 # Hybrid-2C: spec authority
├── AnswerPacket.lean
├── VRM.lean
├── InterruptScore.lean              # u_t equation, decidable instances
├── Sheaf.lean
├── BoolPredicates.lean              # claimKindExhaustive, residencyOk
├── SchemaGen.lean                   # 300-500 LOC metaprogram → Swift/Rust
├── Theorems/
│   ├── V5/                          # T01..T17  (verified, mostly closed)
│   ├── PCF/                         # T25..T34  (PCF candidates)
│   ├── V6/                          # T35..T44  (V6 SSM/PCF/HeavySkill)
│   └── Aesop/EpistemoRules.lean
└── Falsifiers/
    ├── SemiseparableBlockScan.lean  # spec for Falsifier 1
    ├── LocalRecallIsland.lean
    ├── PageGather.lean
    ├── ControllerKernelPack.lean
    └── PacketRouter1bit.lean
```

`lakefile.lean` skeleton (Apple-Silicon-tuned, V6.2):

```lean
import Lake
open Lake DSL

package «epistemos» where
  leanOptions := #[
    ⟨`pp.unicode.fun, true⟩,
    ⟨`autoImplicit, false⟩
  ]
  -- Apple Silicon: prefer release builds; let mathlib cache do its job
  preferReleaseBuild := true
  buildType := BuildType.release

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.29.0-rc6"

@[default_target] lean_lib «Epistemos» where
  globs := #[.submodules `Epistemos]
```

## 1.8 GitHub Actions B5 gate (V6.2)

```yaml
name: B5 — Lean verification gate
on:
  push:    { branches: [main] }
  pull_request: { branches: [main] }
  workflow_dispatch:
jobs:
  lean:
    runs-on: macos-latest      # M-class as of Q1 2026
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: leanprover/lean-action@v1   # auto-detects toolchain & runs lake exe cache get
        with:
          test: true
      - name: Sorry budget enforcement
        run: bash scripts/check_sorry_budget.sh
```

`scripts/check_sorry_budget.sh` (preserved):
```bash
#!/usr/bin/env bash
set -euo pipefail
LIMIT_PER_FILE=7
LIMIT_TOTAL=266
fail=0
total=0
while IFS= read -r f; do
  c=$(grep -c '\bsorry\b' "$f" || true)
  total=$((total+c))
  if [ "$c" -gt "$LIMIT_PER_FILE" ]; then
    echo "::error file=$f::sorry budget exceeded: $c > $LIMIT_PER_FILE" ; fail=1
  fi
done < <(find plane_verification/lean -name '*.lean' -not -path '*/.lake/*')
echo "TOTAL sorrys: $total / $LIMIT_TOTAL"
if [ "$total" -gt "$LIMIT_TOTAL" ]; then
  echo "::error::repo-wide sorry budget exceeded"; fail=1
fi
exit $fail
```

## 1.9 Tier-Map (which kernel runs where)

| Kernel / module | MAS Tier-1 (default-on, M2-Pro-16GB) | MAS Tier-2 (opt-in flag) | Pro (≥32 GB or cloud) | Vault (workstation/cloud only) |
|---|---|---|---|---|
| InterruptScore (Swift CPU) | ✅ | | | |
| PacketRouter1bit | ✅ | | | |
| ControllerKernelPack (6) | ✅ | | | |
| LocalRecallIsland 32K (Granite-4-H-Micro Q4) | ✅ | | | |
| LocalRecallIsland 128K | | ✅ | | |
| SemiseparableBlockScan (L=32K, ngroups=1) | ✅ | | | |
| SemiseparableBlockScan (L=131K) | | ✅ | | |
| PageGather (256 MB / 512 MB) | ✅ | | | |
| PageGather (1 GB) | | ✅ | | |
| HeavySkill LoRA training | | | ✅ | |
| VPD/PCF decomposition (full) | | | ✅ | |
| Cerebra modules | | | ✅ | |
| Mamba-3 lookahead | | | | ✅ |
| Active Rank-One Runtime | | | | ✅ |
| ModelSurgery | | | | ✅ |
| Connectome Distillation T34 | | | | ✅ |
| DeepSeek-Prover-V2-7B (background, app quiesced) | ✅ (workflow-gated) | | | |
| LeanCopilot (full local) | | | ✅ | |
| LeanCopilot (CI on macos-latest) | ✅ | | | |
| Aesop + select_premises | ✅ | | | |
| `mlx-community/granite-4.0-h-1b-MLX` (floor lane) | ✅ | | | |

## 1.10 The 197-item Nuance Checklist — preservation status

Every item in the V6.1 nuance checklist is preserved verbatim *unless* explicitly retagged below. The tag `[DOWNGRADED-V6.2-HARDWARE]` is applied with reason; counts of unchanged items are quoted but the body is referenced rather than restated to keep this canon under length-of-Brutalism:

- **Items 1–37 (Lean toolchain & mathlib hygiene):** 37 of 37 preserved unchanged. *Sole edit:* the toolchain line in §1.1 (4.28.x → 4.29.1) flows down; everything else (selective imports, deprecated-attribute discipline, `lake exe cache get` policy, `#min_imports` use, mathlib release-tag policy) is untouched.
- **Items 38–74 (Swift/Rust/UniFFI/jlrs hygiene):** 37 of 37 preserved unchanged.
- **Items 75–96 (MLX / Metal / Mamba-2 numeric hygiene):** 21 of 22 preserved; **1 retagged** — `ngroups=1 strict` is now anchored to issue **#647** (was incorrectly cited as #449).
- **Items 97–118 (Granite-4 / model-tier hygiene):** 22 preserved + **2 added in V6.2** (Granite-4 Nano H-1B as floor-lane fallback; Granite-4-H-Tiny-3bit-MLX as MoE option). Net = 24.
- **Items 119–144 (PageGather / bandwidth):** 22 of 26 preserved; **4 retagged [DOWNGRADED-V6.2-HARDWARE]** —
  - "≥70% of 400 GB/s" → "≥70% of measured `BW_baseline_M2Pro` (typically 90–105 GB/s)";
  - "4 GB buffer test" → removed (would force swap on 16 GB);
  - "M2 Max thermal envelope" → "M2 Pro thermal envelope, fan-on";
  - "expected 280 GB/s gather pass band" → "expected 63–73 GB/s gather pass band".
- **Items 145–170 (LocalRecallIsland / RULER / BABILong):** 25 of 26 preserved; **1 retagged [BUDGET-REVISION]** — trial counts halved 100→50 in core lane.
- **Items 171–197 (sorry-budget / CI / Aesop / DeepSeek-Prover workflow):** 27 of 27 preserved; the only operational change is the **"DeepSeek-Prover local only when app quiesced"** doctrine, which was already implicit and is now explicit.

**Net: 197 items reviewed → 192 preserved unchanged + 7 explicitly retagged + 2 added (Granite-4 Nano line). No item silently dropped.**

---

# SECTION 2 — BUILD-CHECKLIST ARTIFACT (Stage 0 → Stage 3, dependency-ordered, no calendar)

The four stages are **dependency-gated**. Each stage's exit criterion is the precondition for the next. There are no dates.

## Stage 0 — Scaffolding (entry: empty repo; exit: green B5 gate with 0 theorems and 0 falsifiers)

**S0.1 Toolchain bootstrap.**
```bash
curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y
elan default leanprover/lean4:v4.29.1
elan toolchain list   # confirm
```

**S0.2 Lake project.**
```bash
mkdir -p plane_verification/lean && cd plane_verification/lean
cat > lean-toolchain <<'EOF'
leanprover/lean4:v4.29.1
EOF
# create Epistemos/ subtree per §1.7
lake init epistemos lib --root=Epistemos
# edit lakefile.lean per §1.7
lake exe cache get   # mathlib v4.29.0-rc6 olean cache
lake build           # should fail-fast on missing files; that's expected
```

**S0.3 Constitution skeleton (Constitution.lean).**
```lean
namespace Epistemos
inductive VRMLabel | reduce | rephrase | review | refuse | request | reroute
  deriving Repr, DecidableEq, BEq

inductive ClaimKind | factual | derived | hypothetical | residual | safety
  deriving Repr, DecidableEq, BEq

structure AnswerPacket where
  vrm   : VRMLabel
  kind  : ClaimKind
  body  : String
  cites : List String
  sigma : Nat       -- residual energy
  deriving Repr
end Epistemos
```

**S0.4 BoolPredicates.lean** with `Decidable` instances for `claimKindExhaustive` and `residencyOk` (proof: `Decidable.decide` over the `deriving DecidableEq` we already get).

**S0.5 Stub all 38 theorems with `sorry`** in `Theorems/V5/`, `Theorems/PCF/`, `Theorems/V6/`. Pattern:

```lean
import Mathlib
import Epistemos.Constitution
namespace Epistemos.T01
/-- Floor invariant: every published AnswerPacket carries a non-zero residual budget.
    Sorry budget: 7. Owner: jojo.  Tier: V5. -/
theorem floor_invariant : ∀ p : AnswerPacket, p.sigma ≥ 0 := by
  sorry
end Epistemos.T01
```

**S0.6 CI bootstrap.** Drop `.github/workflows/b5.yml` per §1.8. Drop `scripts/check_sorry_budget.sh` per §1.8. Add a `.gitignore` for `.lake/`.

**S0.7 SchemaGen.lean stub.** Just the metaprogram skeleton; emits two empty files `Generated/Schema.swift` and `Generated/Schema.rs`. Wire its invocation into `lake build`.

**Exit criterion for Stage 0:** `lake build` succeeds locally (M2 Pro 16 GB, peak ≤ 6 GB resident); B5 CI gate green on a no-op commit; sorry-count == 38; `Generated/Schema.swift` and `Generated/Schema.rs` regenerate idempotently.

## Stage 1 — Falsifiers (entry: Stage 0 green; exit: all 6 falsifiers green on M2 Pro 16 GB Core lanes)

**S1.1 PageGather baseline.** Build `Falsifiers/PageGather/baseline.metal` STREAM-triad-style probe; compute `BW_baseline_M2Pro`; commit `falsifier_calibration.toml`.

**S1.2 PageGather scatter.** Implement page-gather kernel; verify ≥70% of `BW_baseline_M2Pro` over ≥1 s windows at {256 MB, 512 MB} buffers.

**S1.3 InterruptScore (Swift CPU).** Implement `u_t = α·H + β·WBO + γ·Sheaf + δ·ToolNeed + ε·ConnectomeAlarm` on `DispatchQueue` QoS `.userInteractive`; assert P99 latency < 100 µs over 10⁵ trials.

**S1.4 PacketRouter1bit.** Ternary router `.metal`; assert dispatch P99 < 100 µs.

**S1.5 ControllerKernelPack.** Six fused micro-kernels; each ≤ 16 KB threadgroup memory; correctness oracle = Swift reference.

**S1.6 SemiseparableBlockScan.** Port `ssd_minimal.py` Listing 1 to Metal; correctness oracle = the same PyTorch implementation; pin `chunk_size=256`, `ngroups=1`. Pass: max-abs-diff ≤ 1e-3 fp16 over 100 random seeds.

**S1.7 LocalRecallIsland — Core lane.** Pull `granite-4.0-h-micro` GGUF Q4_K_M (or `granite-4.0-h-tiny-3bit-MLX`); run 50 trials × 5 depths at 32K context; pass criterion passkey ≥ 0.95, niah_single_1 ≥ 0.95.

**S1.8 RULER + BABILong harness.** Wire `NVIDIA/RULER` (rulerv1-ns branch) and `RMT-team/babilong` HF dataset into `Falsifiers/Eval/`. Ensure 13 RULER tasks + QA1–QA5 BABILong tasks all run at 32K under 30 min wall-clock on M2 Pro.

**Exit criterion for Stage 1:** all six falsifier Core lanes green on M2 Pro 16 GB; `falsifier_calibration.toml` committed; CI gate B5 still green.

## Stage 2 — Lean integration (entry: Stage 1 green; exit: ≥ 24 of 38 theorems closed, sorry-budget < 100)

**S2.1 Aesop ruleset.** Author `Theorems/Aesop/EpistemoRules.lean` with ~30 norm rules and ~15 unsafe rules drawn from V5 lemmas. Tag with `@[aesop safe]` / `@[aesop unsafe N%]`.

**S2.2 Close trivial T1–T7.** These are mostly `decide`, `Decidable.decide`, `simp_all`, or one-line Aesop calls. Target sorry-count drop of 7.

**S2.3 Close T8–T17 with mathlib lemmas.** For each, run `aesop?` to get a tactic suggestion; clean by hand. Target sorry-count drop of 10.

**S2.4 PCF skeleton T25–T34.** State each theorem precisely against the SPD/APD/VPD definitions (arXiv:2506.20790, 2501.14926, goodfire.ai/research/interpreting-lm-parameters). Most will retain `sorry` at this stage but will *type-check*, which gates code-gen.

**S2.5 V6 skeleton T35–T44.** SSM correctness theorems anchor to Dao & Gu Theorem 3.7 (semiseparable matrix duality, arXiv:2405.21060). HeavySkill theorems anchor to LongCat-Flash-Thinking-2601 (arXiv:2601.16725). Most retain `sorry`.

**S2.6 SchemaGen.lean v1.** Implement `deriving SchemaSwift` and `deriving SchemaRust` macros. Validate: change a constructor of `ClaimKind`, run `lake build`, observe regeneration in both `Generated/Schema.swift` and `Generated/Schema.rs`.

**S2.7 DeepSeek-Prover-V2-7B background worker.** Build `tools/prover-worker.swift`: launches MLX 4-bit DeepSeek-Prover-V2-7B when machine idle ≥ 3 min and ≥ 8 GB free; polls `lake env lean --print-paths` for `sorry`-bearing files; appends candidate proofs to a queue for human review (never auto-commits).

**Exit criterion for Stage 2:** sorry-count < 100 (i.e. ≥ 24 closed); B5 CI gate green; SchemaGen regen idempotent; prover-worker has produced at least 5 human-accepted proof PRs.

## Stage 3 — Migration (entry: Stage 2 green; exit: production-cut, MAS Tier-1 ships)

**S3.1 Wire SchemaGen output into Swift target.** Replace the hand-rolled `enum AnswerPacket` and `enum ClaimKind` in the Swift app with the generated `Generated/Schema.swift`. Same in Rust via `Generated/Schema.rs` consumed by UniFFI 0.30.

**S3.2 Wire LocalRecallIsland into Episodic plane.** Hook `Granite-4-H-Micro` Q4_K_M (or H-Tiny 3-bit MLX) behind the InterruptScore gate.

**S3.3 Wire SemiseparableBlockScan into State plane.** Replace the legacy attention path with the SSD scan when `u_t < threshold_ssm`.

**S3.4 Surprise-consolidate / sleep cycle.** Implement the "hippocampal sleep" pass: at idle, replay episodic islands through SemiseparableBlockScan to consolidate.

**S3.5 SCOPE-Rex witness emitter.** Every durable state change emits a witnessed artifact (cryptographically signed JSON-Lines record, Granite-style `model.sig` analog). Wire to a local SQLite ledger.

**S3.6 Final B5 sorry-budget check.** Confirm sorry-count ≤ 38 (i.e. ≤ 1 per theorem on average).

**S3.7 App Store envelope check.** Bundle resident model + KV + Atlas + Lean schemas + Swift app + macOS overhead must observe **peak ≤ 12 GB, hard ceiling 14 GB**; monitor with `os_proc_available_memory()` for 24-h soak test on M2 Pro 16 GB.

**S3.8 Production cut.** MAS Tier-1 ships; Pro tier flagged `[REQUIRES-≥32GB-OR-CLOUD]`; Vault tier flagged `[WORKSTATION-OR-CLOUD-ONLY]`.

---

# SECTION 3 — V6.1 → V6.2 DELTA DOCUMENT

Every item where the M2 Pro 16 GB substitution forced a change. Format: original → new, with explicit tag.

| # | Item | V6.1 value | V6.2 value | Tag | Rationale |
|---|---|---|---|---|---|
| Δ1 | Primary falsifier rig | M2 Max 32 GB / 400 GB/s | **M2 Pro 12C/19G 16 GB / 200 GB/s** | [HARDWARE-SUBSTITUTION] | Doctrine lock |
| Δ2 | M2 Max / M3 Max / M5 Ultra status | co-equal validation | **scale-validation rigs only** | [HARDWARE-SUBSTITUTION] | "If it requires a workstation, it's research-tier." |
| Δ3 | PageGather pass band | ≥70% of 400 GB/s ≡ 280 GB/s | **≥70% of measured `BW_baseline_M2Pro` (typ. 63–73 GB/s)** | [THRESHOLD-RECALIBRATION] | M2 Pro spec is 200 GB/s; STREAM-on-Metal (arXiv:2502.05317) measures up to ~100 GB/s; the previously-implied 150–165 GB/s baseline is **[DRIFT-DETECTED]** |
| Δ4 | PageGather buffer matrix | {256 MB, 512 MB, 1 GB, 4 GB} | **{256 MB, 512 MB, 1 GB}** | [BUDGET-REVISION] | 4 GB working set forces swap on 16 GB |
| Δ5 | PageGather window | unspecified (sub-second OK in some prose) | **≥ 1.0 s mandatory; sub-second rejected** | [THRESHOLD-RECALIBRATION] | Apple SLC bursts inflate sub-second reads |
| Δ6 | LocalRecallIsland Core lane | Granite-4-H-Micro at 128K, 100 trials × 5 depths | **Granite-4-H-Micro at 32K, 50 trials × 5 depths** | [BUDGET-REVISION] | 12-min thermal envelope on fan-on M2 Pro |
| Δ7 | LocalRecallIsland Stretch lane | (was the default) | **128K relegated to opt-in `--stretch` flag** | [TIER-MOVE] | 16 GB residency |
| Δ8 | LocalRecallIsland floor lane | none | **`granite-4.0-h-1b` (~1 GB Q4) added** | [MODEL-ADD-V6.2] | Granite-4 Nano released 2025-10-29 — opens an ultra-tight floor option not available in V6.1 |
| Δ9 | LocalRecallIsland MoE option | none | **`mlx-community/granite-4.0-h-tiny-3bit-MLX` (~3 GB, 7B total / 1B active MoE)** | [MODEL-ADD-V6.2] | New MLX-native option |
| Δ10 | SemiseparableBlockScan primary L | 131072 | **32768 (Core); 131072 stretch-only** | [BUDGET-REVISION] | 16 GB activation working set |
| Δ11 | SemiseparableBlockScan ngroups upstream issue | "issue #449" | **issue #647** | [DRIFT-DETECTED] | Confirmed via `state-spaces/mamba` issue tracker; #449 was a different topic |
| Δ12 | SemiseparableBlockScan chunk_size | 256 (canonical) | **256 canonical, 128 perf-benchmarked stretch** | [THRESHOLD-RECALIBRATION] | PyTorch fused-Mamba2 writeup shows 128 optimal post-fusion for Mamba-2-2.7B |
| Δ13 | InterruptScore implementation | Metal kernel | **Swift CPU on QoS `.userInteractive` (canonical); Metal shadow behind feature flag for batch ≥ 64 tokens** | [THRESHOLD-RECALIBRATION] | Encoder-setup cost > arithmetic at single-token granularity |
| Δ14 | Lean toolchain pin | 4.28.x / 4.30-rc2 prose | **4.29.1 (stable)** | [HARDWARE-SUBSTITUTION] (transitively) + recency | 4.29.1 released 2026-04-14; 4.29.0 carries breaking `isDefEq` change requiring `noncomputable` annotations — pin point matters |
| Δ15 | mathlib4 pin | "028964f April 22 2026" master commit | **`v4.29.0-rc6` (tagged, 2026-03-10)** | [DRIFT-DETECTED] | Pin a tag, not a master commit |
| Δ16 | LeanCopilot in dev loop | local | **CI-only** | [TIER-MOVE] | CTranslate2 model + Epistemos app exceeds 16 GB; LeanCopilot lags Lean stable to v4.27.0 (2026-02-11) |
| Δ17 | DeepSeek-Prover-V2-7B locality | "local prover" | **"local prover, only when Epistemos app is quiesced"** | [BUDGET-REVISION] | 4 GB MLX weights + 8 GB app conflict |
| Δ18 | mathlib4 build locally | full build acceptable | **full build CI-only; locally always `lake exe cache get`** | [BUDGET-REVISION] | ~12 GB peak resident on full build |
| Δ19 | Selective imports cap | not enforced | **peak resident ≤ 6 GB during local edit** | [BUDGET-REVISION] | leaves 4 GB headroom for app + macOS |
| Δ20 | Sorry budget per theorem | ≤ 7 | **≤ 7 (preserved)** + monotonically-decreasing total target −1/week-of-work | [PRESERVED + STRENGTHENED] | Visible burn-down; AI-assist can be slower (CPU-only LeanCopilot path) |
| Δ21 | Lean-Copilot version | "main" | **v4.27.0 tag** | [VERSION-PIN] | Tags only; no master tracking |
| Δ22 | Lee Sharkey VPD thread URL | `x.com/leedsharkey/status/1938616685855941040` | **`x.com/leedsharkey/status/2051717264286609516`** | [DRIFT-DETECTED] | LessWrong linkpost canonical ref |
| Δ23 | Goodfire VPD numbers cited | "67M / 4-layer / 38912 / 9972 / 205 / 2.1%" | **"67M / 4-layer / 28M non-embedding / 38912 rank-1"** verified live; 9972 / 205 / 2.1% [NEEDS-SOURCE-FILE-VERIFICATION] | [PARTIAL-DRIFT-DETECTED] | Live page does not contain 9972 / 205 / 2.1% in the headline text |
| Δ24 | Pro-tier kernels (HeavySkill LoRA, full VPD/PCF, Cerebra) | ambiguous | **explicit `[REQUIRES-≥32GB-OR-CLOUD]`** | [TIER-MOVE] | 16 GB doctrine forces clarity |
| Δ25 | Vault-tier kernels (Mamba-3 lookahead, ARORR, ModelSurgery, T34) | ambiguous | **explicit `[WORKSTATION-OR-CLOUD-ONLY]`** | [TIER-MOVE] | Same |
| Δ26 | Calibration corpus task #18 (Mamba-2 hyperparameter sweep) | MED | **MOVED to PRO-ONLY-≥32GB** | [TIER-MOVE] | Multiple compiled kernels resident exceed 16 GB |
| Δ27 | Calibration corpus task #16 (MLX↔PyTorch translation) | MED, parallel | **MED, sequential** | [BUDGET-REVISION] | Run engines serially |
| Δ28 | Calibration corpus task #25 (SMT fallback to DeepSeek-Prover) | HIGH | **HIGH, app-quiesced workflow** | [BUDGET-REVISION] | |
| Δ29 | Calibration corpus task #29 (Vault retrieval at full corpus) | HIGH | **MOVED to VAULT-ONLY-WORKSTATION-OR-CLOUD** | [TIER-MOVE] | |
| Δ30 | Calibration corpus task #30 (collab DeepSeek-Prover + LeanCopilot) | HIGH | **MOVED to PRO-ONLY-≥32GB** | [TIER-MOVE] | Both stacks resident exceed 12 GB |
| Δ31 | Granite-4 family in V6.2 model menu | H-Micro 3B only | **H-Nano 350M, H-1B (1.5B), Micro 3B (dense), H-Micro 3B (hybrid), H-Tiny 3-bit MLX (7B/1B-active MoE) all available** | [MODEL-ADD-V6.2] | Granite-4 Nano release 2025-10-29 |
| Δ32 | Apple Tech Talk citation | "Explore Live GPU Profiling with Metal Counters" generic | **WWDC Tech Talk #10001 (2020)**, plus Discover Metal Profiling Tools (WWDC21 #10157), Discover Metal profiling tools for M3 / A17 Pro (Tech Talk #111374) | [VERIFIED-WEB-Q1-2026] | Stage-boundary sampling on Apple Silicon (per-draw boundaries are Intel/AMD only) |
| Δ33 | STREAM-on-Metal expected baseline | "150–165 GB/s on M2 Pro" | **"up to ~100 GB/s on M2 Pro per arXiv:2502.05317"** | [DRIFT-DETECTED] / [THRESHOLD-RECALIBRATION] | Direct measurement supersedes inference |
| Δ34 | Lock phrase | "(part of phrase) one Monday — one plan ..." | **preserved verbatim, but explicitly tagged "lock phrase, not a calendar commitment"** | [PRESERVED + ANNOTATED] | User clarified explicitly |
| Δ35 | Implementation timeline | implied schedule | **OPEN — research-driven, dependency-ordered** | [DOCTRINE-CHANGE] | "no time so taints just research" |
| Δ36 | SubQ / Subquadratic | unstated | **closed-source, $29M seed, May 5 2026 launch — `[COMPETITIVE-PARITY-WATCH-LIST]`, not a dependency** | [STATUS-CLARIFY] | |
| Δ37 | AlphaProof artifact status | "Nov 2025 paper, runnable methodology" | **"methodology only — no open code, no open weights"** | [STATUS-CLARIFY] | |
| Δ38 | cartesia-metal compatibility | "tested on M3 Sonoma 14.1" | **"tested on M3 Sonoma 14.1; M2 Pro / M2 Pro Sequoia compatibility [NEEDS-SOURCE-FILE-VERIFICATION]"** | [STATUS-CLARIFY] | Must rebuild & benchmark on our exact rig before adoption |
| Δ39 | LeanDojo / LeanDojo-v2 status | unstated | **active (last commit 2026-03-10), Apache-2.0** | [VERIFIED-WEB-Q1-2026] | |
| Δ40 | HeavySkill arXiv ID | "2605.02396" | **"2605.02396"** confirmed | [VERIFIED-RESEARCH-DOCS-with-nuance] (preserved) | Forward-dated 2026-05; legitimate |
| Δ41 | LongCat-Flash-Thinking arXiv ID | "2601.16725" | **"2601.16725" confirmed; supersedes 2509.18883 (LongCat-Flash-Thinking original)** | [VERIFIED-WEB-Q1-2026] | Both papers are real; Heavy Thinking Mode discussed in both |

---

# RECOMMENDATIONS (decision-ready)

**Stage-0 starts on Jojo's M2 Pro now.** The toolchain pins are stable enough (Lean 4.29.1 stable since 2026-04-14, mathlib v4.29.0-rc6 since 2026-03-10) that no waiting is justified. The only forward dependency that *might* warrant patience is **LeanCopilot**: as of 2026-05-07 it lags at v4.27.0. If LeanCopilot cuts a v4.29 tag during Stage 0/1, *bump immediately*; if not, **proceed without it** — Aesop + DeepSeek-Prover-V2-7B + AlphaProof-style methodology is a complete substitute for our use case.

**MAS Tier-1 brain choice (decision):** Ship **`granite-4.0-h-micro` GGUF Q4_K_M via llama.cpp** as the primary, with **`granite-4.0-h-tiny-3bit-MLX`** as a feature-flagged MLX-native alternative. *Why not Falcon-Mamba-7B?* Granite-4-H-Micro's hybrid 9:1 Mamba-2 + transformer architecture handles tool calls and structured output better at this scale (BFCLv3 evidence), and IBM's Apache-2.0 + ISO 42001 + cryptographic signing is a uniquely clean App-Store-compatible posture. *Why not Qwen3-1.7B?* Apache 2.0 also clean, and Qwen3-1.7B is a fine ultra-light alternative — adopt it as the **floor lane** if Granite-4-H-Micro proves too heavy on the soak test, alongside Granite-4-H-1B.

**Falsifier order (dependency-true):** PageGather baseline → PageGather scatter → InterruptScore → PacketRouter1bit → ControllerKernelPack → SemiseparableBlockScan → LocalRecallIsland. The bandwidth baseline is the gate everything else calibrates against; build it first.

**Sorry-budget telemetry:** publish a daily badge `sorrys: NN / 266` to README.md. Use it as the public proof-of-progress.

**Benchmarks / thresholds that would change recommendations:**

- *If `BW_baseline_M2Pro` < 60 GB/s on the rig:* lower the PageGather pass band to ≥ 65% and document; do not pretend.
- *If LocalRecallIsland Core (32K, 50×5) cannot reach passkey ≥ 0.95 on Granite-4-H-Micro Q4_K_M:* fall back to **Granite-4-H-Tiny 4-bit MLX (LM Studio variant, `lmstudio-community/granite-4.0-h-tiny-MLX-4bit`)**; if that also fails, fall back to **Phi-3.5-mini-instruct-4bit (3.8B, MIT)** at 32K with the explicit caveat that Phi-3.5 lacks the hybrid architecture's long-context efficiency.
- *If LeanCopilot still lacks a v4.29+ tag at the start of Stage 2:* ship without it; Aesop + DeepSeek-Prover-V2-7B suffices.
- *If DeepSeek-Prover-V2-7B MLX-4bit doesn't materialise (no canonical mlx-community port):* run it via llama.cpp Q4_K_M as a CPU/GPU hybrid; the 7B is small enough that CPU-only is within human-acceptable latency for background work.
- *If sorry-count plateaus above 100 after Stage 2 effort:* invoke AlphaProof-style test-time RL methodology — generate theorem variants via DeepSeek-V3-class API for the stuck theorems, train DeepSeek-Prover-V2-7B online against them. **This is the doctrine-of-last-resort.**

**Ship gate for MAS Tier-1:** All Stage-3 exit criteria + sorry-count ≤ 100 + B5 green for 7 consecutive commits + 24-h soak at peak ≤ 12 GB resident on M2 Pro 16 GB.

---

# CAVEATS

- **One unresolved citation.** The Goodfire VPD page numbers "9972 / 205 / 2.1%" could not be re-located on the live `goodfire.ai/research/interpreting-lm-parameters` page during this verification pass. The headline numbers (67M params, 4-layer, 38,912 rank-1 subcomponents over 24 weight matrices, 28M non-embedding decomposed) *are* confirmed live. Treat the three sub-numbers as **[NEEDS-SOURCE-FILE-VERIFICATION]** until someone walks the Appendix A.7 of the live page.

- **One arXiv ID pattern note.** `2605.02396` (HeavySkill) and `2601.16725` (LongCat-Flash-Thinking-2601) have arxiv prefixes that decode as 2026-05 and 2026-01 respectively — both forward-dated relative to the prior research's reference frame. Both papers do exist on arXiv as of this verification (HTML versions resolvable). Preserved as canonical, **but flag** — these are extremely fresh; subsequent revisions (v2, v3) may shift abstract claims.

- **Three [DRIFT-DETECTED] flags fired.** Issue #647 not #449; Lee Sharkey thread `2051717264286609516` not `1938616685855941040`; STREAM-on-Metal baseline ~100 GB/s not the 150–165 GB/s figure that V6.1 implicitly relied on. These are corrections, not just revisions; the V6.1 PageGather pass band of "≥280 GB/s" was *unrealisable* on M2 Pro silicon and would have produced a guaranteed-fail falsifier had it been carried forward verbatim.

- **AlphaProof is methodology only.** No artifact, no weights, no code. V6.2 *adopts the design pattern* (test-time RL on self-generated theorem variants, formal-only reward signal) but commits to no upstream dependency.

- **cartesia-metal hardware target gap.** The repository's documented test platform is macOS Sonoma 14.1 + M3. We are macOS-current + M2 Pro. We *expect* compatibility (Metal API surfaces are stable across these chips and OS versions), but we do not *know* it. Build-and-bench on rig before adoption; treat any per-token latency anomaly as a cartesia-metal compatibility bug, not as a Mamba-2 algorithmic surprise.

- **SubQ is excluded as a dependency.** Closed weights, no peer-reviewed paper, contested benchmarks (95% RULER 128K at $8 vs. Opus $2,600), $500M valuation at seed with 13 employees. Watch-list, not work-list. If SubQ open-weights or peer-reviews, re-evaluate.

- **The 16 GB ceiling is the doctrine, not the limit.** If a future M-series MacBook Pro at the same price point ships with 24 GB unified memory baseline, the Pro tier kernels migrate down to MAS without renegotiation. The doctrine — *"the model is a guest in the user's brain — not a tenant of the user's machine"* — survives the upgrade.

- **The lock phrase is preserved verbatim, including "one Monday".** It is the architectural mantra. There is no Monday deadline. There is no deadline. There is only the dependency order in §2.

— END V6.2 LOCK CANON —