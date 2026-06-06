# Epistemos Local Substrate Compression Research

Date: 2026-06-06

Status: research synthesis only. No product code was edited. No local model bytes were loaded. No MLX, GGUF, LiteRT, or TurboVec live probe was run in this pass.

Core boundary: Epistemos is a local cognitive substrate, not a notes app or a chat wrapper. Every meaningful object needs an address, plane, budget, status, and witness. MAS ships the safe floor. Pro contains gated research, vault, and omega ladder work. No claim promotes without visible proof.

## Executive Summary

TurboVec and Gemma 4 QAT are useful, but they belong in different organs.

TurboVec belongs first in Eidos/AppColdStore as a compressed, rebuildable vector search cache. It can help SemanticWorkingSetPlan compilation and Eidos evidence retrieval by reducing vector memory pressure and running allowlist-constrained search inside the scoring kernel. It is not a durable database, not a metadata engine, not a hidden router, and not a replacement for exact source storage.

Gemma 4 QAT belongs in the local model ladder. The strongest immediate target is Gemma 4 12B QAT for a Pro Gated Mac lane. E2B/E4B mobile and GGUF variants are safe-floor candidates only after memory, cancellation, structured-output, and AnswerPacket witnesses pass. 26B-A4B and 31B stay Pro Research/Vault until the harness proves local load, route, thermal, cancellation, and quality behavior on real Apple Silicon.

MLX support is real as a Python/Hugging Face/MLX ecosystem path, but it is not automatically Epistemos Swift runtime support. The repo already contains a Gemma 4 automatic-route exclusion in `Epistemos/Engine/TriageService.swift` because the shipped Swift MLX path does not yet support the Gemma 4 config decoder. That exclusion should remain until an Epistemos-owned runtime witness removes it.

The owner asked for no compromise and ambitious proprietary logic. The right version of that is not blind cherry-picking. It is an Epistemos-owned compression/runtime spine with a source-card ledger, license gates, clean-room notes, and falsifiers. Permissive code may be used with attribution and license compliance. Unknown-license, GPL-incompatible, or highly experimental code can inform research cards, but should not be copied into proprietary product logic.

None of this proves live dense 70B. Compression helps retrieval, smaller resident lanes, KV/context experiments, cold assembly, and routing. 70B-class architecture remains cold assembly, routing, residency, transport, verifier, and harness work, not a dense checkpoint permanently resident in RAM.

## Truth Levels

Use Epistemos truth levels, not latency tiers:

| Level | Meaning | Promotion rule |
| --- | --- | --- |
| L1 | Source-card, metadata, architecture proposal, dry-run planner | Can update docs/canon as a candidate only. No product route. |
| L2 | Local benchmark or falsifier pass on target hardware/build | Can become Pro gated route if rollback and witness exist. |
| L3 | User-facing route with RunEventLog, AnswerPacket, citations, rollback, and visible proof | Can affect product answers. |

Runtime terms should be separate: hot resident lane, balanced local lane, cold assembly, vault research lane.

## Source List

Accessed 2026-06-06 unless noted.

Primary seed sources:

- TurboVec upstream: https://github.com/RyanCodrai/turbovec
- TurboVec docs/API: https://github.com/RyanCodrai/turbovec/blob/main/docs/api.md
- TurboVec PR #83 audit/fidelity work: https://github.com/RyanCodrai/turbovec/pull/83
- TurboVec issue #70 public I/O/from_parts: https://github.com/RyanCodrai/turbovec/issues/70
- TurboVec issue #68 centroid cache persistence: https://github.com/RyanCodrai/turbovec/issues/68
- TurboVec issue #65 insertion/removal benchmarks: https://github.com/RyanCodrai/turbovec/issues/65
- Google Research TurboQuant background, published 2026-03-24: https://research.google/blog/turboquant-redefining-ai-efficiency-with-extreme-compression/
- Google Gemma 4 12B announcement, published 2026-06-03: https://blog.google/innovation-and-ai/technology/developers-tools/introducing-gemma-4-12B/
- Google Gemma 4 QAT announcement, published 2026-06-05: https://blog.google/innovation-and-ai/technology/developers-tools/quantization-aware-training-gemma-4/

Runtime/model sources:

- HF MLX integration docs: https://huggingface.co/docs/transformers/community_integrations/mlx
- HF Apple Silicon docs: https://huggingface.co/docs/transformers/perf_train_special
- llama.cpp tensor encoding wiki: https://github.com/ggml-org/llama.cpp/wiki/Tensor-Encoding-Schemes
- Official Gemma 4 12B: https://huggingface.co/google/gemma-4-12B-it
- Official Gemma 4 12B QAT GGUF: https://huggingface.co/google/gemma-4-12B-it-qat-q4_0-gguf
- Official Gemma 4 12B QAT unquantized: https://huggingface.co/google/gemma-4-12B-it-qat-q4_0-unquantized
- MLX Gemma 4 12B QAT conversion: https://huggingface.co/mlx-community/gemma-4-12B-it-qat-4bit
- LiteRT Gemma 4 12B: https://huggingface.co/litert-community/gemma-4-12B-it-litert-lm
- Official Gemma 4 E2B/E4B/26B-A4B/31B QAT GGUFs:
  - https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf
  - https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf
  - https://huggingface.co/google/gemma-4-26B-A4B-it-qat-q4_0-gguf
  - https://huggingface.co/google/gemma-4-31B-it-qat-q4_0-gguf
- Official Gemma 4 mobile QAT:
  - https://huggingface.co/google/gemma-4-E2B-it-qat-mobile-transformers
  - https://huggingface.co/google/gemma-4-E4B-it-qat-mobile-transformers
  - https://huggingface.co/google/gemma-4-E2B-it-qat-mobile-ct
  - https://huggingface.co/google/gemma-4-E4B-it-qat-mobile-ct
- MLX Gemma 4 QAT conversions:
  - https://huggingface.co/mlx-community/gemma-4-E2B-it-qat-4bit
  - https://huggingface.co/mlx-community/gemma-4-E4B-it-qat-4bit
  - https://huggingface.co/mlx-community/gemma-4-26B-A4B-it-qat-4bit
  - https://huggingface.co/mlx-community/gemma-4-31B-it-qat-4bit
- Unsloth Gemma 4 local docs: https://unsloth.ai/docs/models/gemma-4
- Unsloth Gemma 4 12B model card: https://huggingface.co/unsloth/gemma-4-12b

Candidate model sources:

- Qwen3-Coder-30B-A3B-Instruct: https://huggingface.co/Qwen/Qwen3-Coder-30B-A3B-Instruct
- MLX Qwen3-Coder-30B-A3B-Instruct 4bit: https://huggingface.co/mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit
- DeepSeek-R1-Distill-Qwen-14B: https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-14B
- MLX DeepSeek-R1-Distill-Qwen-14B 4bit: https://huggingface.co/mlx-community/DeepSeek-R1-Distill-Qwen-14B-4bit
- IBM Granite 4.0 H Micro: https://huggingface.co/ibm-granite/granite-4.0-h-micro
- MLX Granite 4.0 H Micro 4bit: https://huggingface.co/mlx-community/granite-4.0-h-micro-4bit
- GLM-4.7-Flash: https://huggingface.co/zai-org/GLM-4.7-Flash
- MLX GLM-4.7-Flash 4bit: https://huggingface.co/mlx-community/GLM-4.7-Flash-4bit

Adjacent compression/repo sources:

- sharpner/turboquant-mlx: https://github.com/sharpner/turboquant-mlx
- jagmarques/nexusquant: https://github.com/jagmarques/nexusquant
- TheTom/turboquant_plus: https://github.com/TheTom/turboquant_plus
- jorgebmann/pyturboquant: https://github.com/jorgebmann/pyturboquant
- devYRPauli/turboquant-m1pro-evaluation: https://github.com/devYRPauli/turboquant-m1pro-evaluation
- mutable-state-inc/gemma4metal: https://github.com/mutable-state-inc/gemma4metal
- mutable-state-inc/turboquant-llama3.170B: https://github.com/mutable-state-inc/turboquant-llama3.170B
- RecursiveIntell/turbo-quant: https://github.com/RecursiveIntell/turbo-quant
- ericcurtin/inferrs: https://github.com/ericcurtin/inferrs
- MemPalace TurboVec backend proposal: https://github.com/MemPalace/mempalace/issues/1669
- RuVector TurboVec PR: https://github.com/ruvnet/RuVector/pull/521
- ordvec: https://github.com/Fieldnote-Echo/ordvec
- turbo-vec crate repo: https://github.com/jonpojonpo/turbo-vec

## Corrections To User-Supplied Drafts

These corrections should be enforced before any copied text enters canon.

- L1/L2/L3 must not be redefined as latency/runtime tiers. Use hot/balanced/cold/vault for runtime placement.
- TurboVec upstream is Rust with Python bindings. It is not a C++ core.
- TurboVec's 1536-dimensional storage math: float32 is 6144 bytes/vector. 4-bit coordinate payload is 768 bytes before per-vector scalars/side tables. 2-bit coordinate payload is 384 bytes. The 384/192 numbers apply to 768 dimensions, not 1536.
- TurboVec TQ+ is not purely data-oblivious once calibration is enabled. Base rotation/codebook logic is data-oblivious; TQ+ fits first-batch per-coordinate shift/scale and then freezes it.
- TurboVec filtering is caller-supplied mask/allowlist search. It does not own metadata storage or privacy policy.
- SQLite `rowid` must not be the semantic UAS ID. Use a stable UAS-to-u64 registry with collision handling.
- User-supplied Swift byte math using `bitWidth / 8` is wrong for 2/3/4-bit cache estimates because integer division goes to zero. Use ceiling bit accounting: `(element_count * bit_width + 7) / 8`, plus scale/metadata overhead.
- "Gemma 4 12B MLX is about 6.7GB" is not what the checked MLX files show. The official 12B QAT GGUF files total about 6.66 GiB; the MLX community 12B QAT 4bit files total about 10.26 GiB. Runtime RSS still needs local measurement.
- The current verified Qwen coding candidate is `Qwen/Qwen3-Coder-30B-A3B-Instruct`, not "Qwen3.5-Coder-35B-A3B" unless a separate source is added.
- NVIDIA NVFP4/MXFP4 repos and naming should not be treated as Mac/MLX support unless the exact MLX repo and runtime proof exist.
- Softmax center-mass collapse should not be tested with one hard-coded entropy direction. Bad quantization may make attention too uniform or wrongly concentrated. Compare against baseline entropy bands and NIAH/citation recall.

## TurboVec Technical Truth

TurboVec is a vector search index built on TurboQuant-style low-bit vector compression. It compresses dense float vectors for direct low-bit similarity scoring. It reduces vector storage and memory bandwidth, and its search kernels can skip disallowed vector blocks when the caller provides a mask/allowlist.

Verified upstream properties:

| Surface | Verified state |
| --- | --- |
| Repo | `RyanCodrai/turbovec`, MIT, about 4.5k stars / 435 forks at check time |
| Language | Rust core plus Python bindings |
| Rust crate | `turbovec` 0.8.0 |
| Python package | `turbovec` 0.7.0 |
| Main index | `TurboQuantIndex` for positional slots |
| Stable external IDs | `IdMapIndex` maps external `u64` IDs to internal slots and supports deletion |
| Bit widths | Rust accepts 2..=4 bits; docs emphasize 2/4 and some code supports 3 |
| Filtering | `search_with_mask` and `search_with_allowlist`; kernel honors caller mask at 32-vector block granularity |
| Persistence | `.tv` for positional index, `.tvim` for IdMapIndex; magic/version checks exist |
| Concurrency | search takes shared reference; mutation takes mutable reference |
| Apple Silicon path | AArch64 NEON search kernels; BLAS/Accelerate dependencies for rotation/linear algebra |
| Known fixes | PR #83 fixed invalid-input corruption, typed errors, ghost IDs, TQ+ load/add issues, allowlist dedup, integration parity |

What it compresses:

- Database vector coordinates after normalization and deterministic orthogonal rotation.
- Packed coordinate codes at low bit width.
- Per-vector length/scoring correction is stored separately.
- It reduces index memory and search bandwidth.

What it does not compress or solve by itself:

- Metadata tables.
- Source text.
- Citations.
- Durable exact embeddings.
- Runtime route authority.
- Cloud/model fallback.
- Crash-safe database semantics.

Algorithmic shape:

1. Extract vector norm and normalize to unit direction.
2. Rotate by a fixed random orthogonal matrix.
3. Optionally apply TQ+ per-coordinate shift/scale calibrated during the first add.
4. Quantize coordinates with Lloyd-Max centroids for the target low-bit distribution.
5. Pack low-bit coordinate codes.
6. Store a per-vector score renormalization scalar.
7. Rotate query once and score directly against packed codes with SIMD lookup/scoring.

Important edge cases:

- Dimension must be non-zero and a multiple of 8.
- `add_2d` returns typed errors for many invalid inputs, but caller contracts still matter.
- Empty add is a no-op.
- NaN/Inf/huge values were important enough to appear in PR #83's audit/fix list.
- TQ+ calibration is first-add sensitive. The code has a minimum-sample threshold. If the first batch is too small, identity calibration may be frozen. Epistemos should either enforce a calibration batch or rebuild later.
- `IdMapIndex::search_with_allowlist` can reject/panic on bad allowlists depending on call path. Epistemos should sanitize allowlists before crossing the adapter boundary.
- O(1) deletion uses swap-remove internally. External IDs remain stable only through `IdMapIndex`, not positional slots.
- Persistence uses file writing/version checks, but not an Epistemos-grade temp/fsync/rename/manifest/rollback protocol.
- No mmap durability guarantee was found.
- No built-in metadata filtering exists. Epistemos must compile metadata/privacy constraints to allowed IDs before search.

### TurboVec Fit In Epistemos

Good fit:

- Eidos compressed retrieval.
- AppColdStore rebuildable vector cache.
- SemanticWorkingSetPlan candidate selection.
- Route priors as visible evidence signals, not route authority.

Bad fit:

- Durable truth store.
- MAS default until falsifiers pass.
- Hidden route authority.
- Direct AnswerPacket citation source without exact ColdStore/source-card validation.
- Any path that post-filters private results after scoring if forbidden items were already ranked/exposed.

## TurboVec Ecosystem Sweep

| Repo | Recency/status | License | Useful changes/signals | Epistemos decision |
| --- | --- | --- | --- | --- |
| `RyanCodrai/turbovec` | Active, pushed 2026-05-30, 4.5k stars, 435 forks | MIT | Best maintained Rust/Python implementation; IdMapIndex; mask/allowlist search; NEON/AVX kernels | Primary evaluation target, Pro Research first |
| `MemPalace/mempalace#1669` | Open proposal, 2026 | MIT repo | Proposes optional TurboVec plus durable SQLite sidecar | Strong architecture signal, not dependency |
| `ruvnet/RuVector#521` | Open PR | MIT repo | ADR-style TurboQuant FastScan ANN crate proposal | Source-card only until merged/tested |
| `TheTom/turboquant_plus` | Active, 6.9k stars, 917 forks | Apache-2.0 | Large KV/weight compression research surface | Pro Research source-card; cherry-pick only through license/provenance gate |
| `sharpner/turboquant-mlx` | Proof-of-concept, 66 stars, 10 forks | no license detected | Apple Silicon MLX KV experiments, V2/V3 comparisons | Read for ideas; do not copy code into proprietary product without license |
| `jagmarques/nexusquant` | Experimental, 16 stars, 5 issues | no asserted SPDX | E8 lattice VQ, FWHT, token eviction, asymmetric K/V | Pro Research only; license blocks product use until resolved |
| `jorgebmann/pyturboquant` | WIP, active, 404 stars | MIT | Python implementation of TurboQuant framework | Source-card/test oracle, not production dependency |
| `devYRPauli/turboquant-m1pro-evaluation` | Evaluation repo, 2 stars | no license detected | Apple M1 Pro evaluation notes, bug discovery claims | Source-card only, no code import |
| `mutable-state-inc/gemma4metal` | Small MIT repo | MIT | Negative reproduction: PolarQuant+QJL reportedly did not work for Gemma 4 31B KV; built alternative | Valuable skepticism source |
| `mutable-state-inc/turboquant-llama3.170B` | Small MIT repo | MIT | Claims Metal TurboQuant for Llama 3.1 70B | Research only; does not promote 70B in Epistemos |
| `RecursiveIntell/turbo-quant` | Active, 28 stars | MIT | Rust TurboQuant/PolarQuant/QJL | Source-card only |
| `ericcurtin/inferrs` | 457 stars, 42 forks | Apache-2.0 | TurboQuant inference server | Source-card only |
| `Fieldnote-Echo/ordvec` | Active, 17 stars, 67 issues | Apache-2.0 | Ordinal/sign quantization, different algorithm | Candidate for coarse prefilter research, not TurboVec substitute |
| `jonpojonpo/turbo-vec` | Very small, 0 stars | MIT | Independent Rust TurboQuant-style search claims | Unsuitable until independent proof |

### Proprietary Cherry-Pick Rule

Ambition should be encoded as a gate:

| Source license/status | Allowed action |
| --- | --- |
| MIT/Apache/BSD with compatible dependencies | May vendor or adapt with attribution, license files, source digest, and integration tests |
| GPL/AGPL/unclear/no license | May read for high-level public ideas only; no code copying into proprietary product |
| Research paper/math | May implement clean-room with notes, tests, and independent design review |
| Same-day model conversion or low-star proof-of-concept | May become source-card prior only |
| Negative reproduction | Should become a falsifier fixture or risk note |

New gate name: `F-ProprietaryCompression-ProvenanceGate`.

## Gemma 4 QAT Technical Truth

Google published the Gemma 4 12B announcement on 2026-06-03 and the QAT announcement on 2026-06-05. The QAT post says Google is releasing QAT checkpoints for Q4_0 and a mobile-specialized quantization format. It also says the mobile format reduces Gemma 4 E2B memory footprint to about 1GB. That 1GB statement should be treated as Google's approximate load-footprint claim for the specialized mobile path, not a blanket file-size or MLX claim.

Gemma 4 12B official model facts from HF:

- Model ID: `google/gemma-4-12B-it`
- Parameters: about 11.96B
- Architecture tag: `gemma4_unified`
- License: Apache-2.0
- Task: any-to-any / image-text-to-text
- Google announcement says it is unified, encoder-free multimodal, supports native audio, and is intended for laptops.

Important runtime distinction:

| Term | Meaning |
| --- | --- |
| Q4_0 GGUF | GGML/llama.cpp-family tensor encoding in a GGUF file. |
| MLX 4bit | MLX safetensors conversion; not the same object as Q4_0. |
| LiteRT-LM | Google AI Edge runtime packaging. |
| Mobile QAT transformers / compressed-tensors | Official Google mobile-oriented surfaces for E2B/E4B. |
| MTP | Drafter/speculative path. Existence of model weights does not prove Epistemos runtime support. |

### Verified Gemma 4 QAT And Runtime Files

File sizes are repository blob totals from the Hugging Face API. They are not runtime RSS. Runtime memory must include loader overhead, KV cache, tokenizer/mmproj, Metal/MLX graph state, fragmentation, and app memory.

| Model/repo | Format | HF file total | License metadata | Recommendation |
| --- | --- | ---: | --- | --- |
| `google/gemma-4-E2B-it-qat-q4_0-gguf` | GGUF Q4_0 + mmproj | 4.04 GiB | Apache-2.0 | MAS Research, then MAS safe floor only after harness |
| `google/gemma-4-E4B-it-qat-q4_0-gguf` | GGUF Q4_0 + mmproj | 5.72 GiB | Apache-2.0 | Pro Live candidate; MAS only after proof |
| `google/gemma-4-12B-it-qat-q4_0-gguf` | GGUF Q4_0 + mmproj | 6.66 GiB | Apache-2.0 | Main Pro Gated target |
| `google/gemma-4-26B-A4B-it-qat-q4_0-gguf` | GGUF Q4_0 + mmproj | 14.56 GiB | Apache-2.0 | Pro Research/Vault |
| `google/gemma-4-31B-it-qat-q4_0-gguf` | GGUF Q4_0 + mmproj | 17.56 GiB | Apache-2.0 | Pro Research/Vault |
| `google/gemma-4-E2B-it-qat-mobile-transformers` | mobile QAT safetensors | 2.32 GiB | Apache-2.0 | MAS Research candidate |
| `google/gemma-4-E4B-it-qat-mobile-transformers` | mobile QAT safetensors | 3.31 GiB | Apache-2.0 | MAS/Pro candidate after proof |
| `litert-community/gemma-4-12B-it-litert-lm` | LiteRT-LM | 6.10 GiB | Apache-2.0 | Pro Gated candidate if runtime bridge fits app |
| `mlx-community/gemma-4-E2B-it-qat-4bit` | MLX safetensors | 4.06 GiB | license not in card metadata | Pro Research until Swift/MLX proof |
| `mlx-community/gemma-4-E4B-it-qat-4bit` | MLX safetensors | 6.36 GiB | license not in card metadata | Pro Research until Swift/MLX proof |
| `mlx-community/gemma-4-12B-it-qat-4bit` | MLX safetensors | 10.26 GiB | license not in card metadata | Pro Research; strong future target |
| `mlx-community/gemma-4-26B-A4B-it-qat-4bit` | MLX safetensors | 14.57 GiB | license not in card metadata | Pro Research |
| `mlx-community/gemma-4-31B-it-qat-4bit` | MLX safetensors | 26.87 GiB | license not in card metadata | Vault Research only |

### Gemma 4 12B Recommendation

Gemma 4 12B should be the lead "new Mac local" model for Epistemos Pro, but the first admitted route should probably be GGUF or LiteRT-LM, not MLX Swift, unless the Swift Gemma 4 loader is completed.

Why:

- It fills the gap between E4B and 26B-A4B.
- It is dense and simpler than MoE routing.
- Official QAT GGUF total is about 6.66 GiB, which is plausible on 16GB/24GB Macs after context caps, but must be measured.
- Google explicitly positions it for laptops and local multimodal agents.
- It has Apache-2.0 source lineage through Google repos.

Why not promote today:

- Epistemos currently excludes Gemma 4 automatic MLX routing because the Swift MLX path cannot decode it.
- Tool-call/JSON reliability is unproven locally.
- Long-context memory and quality are not file-size claims.
- MTP speedups need target/drafter acceptance witnesses.
- Multimodal mmproj/audio paths can break runtime packaging and MAS boundaries.

## Local Model Candidate Comparison

| Candidate | License | Format path | Practical file size observed | Strength | Risk | Placement |
| --- | --- | --- | ---: | --- | --- | --- |
| Gemma 4 E2B QAT GGUF/mobile | Apache-2.0 | GGUF, mobile transformers, mobile CT, MLX | 2.32-4.06 GiB depending path | Smallest Gemma 4 local lane, multimodal/audio potential | New, runtime support split, MAS size pressure | MAS Research -> MAS Safe Floor if proven |
| Gemma 4 E4B QAT | Apache-2.0 | GGUF, mobile, MLX | 3.31-6.36 GiB | Better synthesis/coding than E2B, still local | Same-day QAT/MLX surfaces, memory | Pro Live candidate, MAS later |
| Gemma 4 12B QAT | Apache-2.0 | GGUF, LiteRT-LM, MLX | 6.10-10.26 GiB | Best balanced new Mac target; multimodal/audio; 12B reasoning | Swift loader gap, context/RSS unknown | Pro Gated first |
| Gemma 4 26B-A4B QAT | Apache-2.0 | GGUF, MLX | 14.56-14.57 GiB files | MoE speed/quality tradeoff | All weights still resident; high memory | Pro Research/Vault |
| Gemma 4 31B QAT | Apache-2.0 | GGUF, MLX | 17.56 GiB GGUF; 26.87 GiB MLX | Strongest Gemma family candidate | Dense, memory/thermal risk | Vault Research |
| Qwen3-Coder-30B-A3B-Instruct | Apache-2.0 | Transformers, MLX 4bit | 16.02 GiB MLX | Coding/tool-call candidate, mature downloads | MoE total weights resident, not Gemma multimodal | Pro Gated/Research |
| GLM-4.7-Flash | MIT | Transformers, MLX 4bit | 15.71 GiB MLX | Fast MoE coding/reasoning, strong ecosystem | Chinese/English behavior, app-specific eval needed | Pro Research |
| DeepSeek-R1-Distill-Qwen-14B | MIT | Transformers, MLX 4bit | 7.75 GiB MLX | Reasoning lane, broad adoption | Reasoning verbosity, tool/JSON uncertainty, CoT control | Pro Research |
| Granite 4.0 H Micro | Apache-2.0 | Transformers, MLX 4bit | 1.68 GiB MLX | Low-risk local baseline, enterprise license posture | Less frontier ability | MAS/Pro Live candidate |

Recommendation:

1. Gemma 4 12B QAT GGUF/LiteRT is the flagship Pro Gated target.
2. Gemma 4 E2B/E4B mobile are the safe-floor candidates, but only after MAS package/memory proof.
3. Qwen3-Coder-30B-A3B remains the best Pro coding lane competitor.
4. GLM-4.7-Flash is worth a Pro Research tournament, not a default.
5. Granite 4.0 H Micro is a useful low-risk baseline and fallback.
6. DeepSeek-R1 distills are reasoning candidates, not default tool-call agents.

## Architecture Fusion Proposal

| Technology | Epistemos organ | Motion | Plane | ProductBuild | ProStatus/ResidencyStatus | ErrorBudget | Witness needed | Admission | Route | Visibility | Verification | Rollback | Privacy risk | Stability risk | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TurboVec IdMapIndex | Eidos/AppColdStore compressed vector cache | Exact embeddings in AppColdStore -> compressed search cache -> exact rerank/citation packet | Evidence/search | Pro first, MAS later | Pro Research | Zero private result exposure; bounded recall delta | UAS ID stability, filter-before-rank, crash rebuild, corrupt fixture | SCOPE-Rex/SovereignGate compiles allowlist | Eidos retriever emits source-card hits only | RunEventLog and AnswerPacket retrieval witness | recall@k vs exact, p95 latency, memory, invalid vectors | Drop `.tvim`, rebuild from AppColdStore, revert manifest pointer | High if post-filtered | Medium/high from persistence edge cases | 1 |
| TurboQuant research | Source-card prior | Paper/repo -> canon card -> falsifier hypothesis | Architecture metadata | Docs only | L1 only | No runtime bytes | Source list and claim boundary | No live admission | No route | Living Index/lattice copy only | citation audit | delete source card | Low | Low | 2 |
| Gemma 4 E2B/E4B QAT | Small local model lane | model card -> dry-run memory -> live probe -> MAS/Pro lane | RuntimeRouter/System G | MAS candidate, Pro candidate | Gated | strict memory/cancel/thermal | model card, hash, RSS, TTFT, cancel, structured output | HardwareTier + user policy + no network | explicit local route only | AnswerPacket model witness | small-model harness | depromote to Granite/Qwen small | Medium if model sees forbidden docs | Medium | 3 |
| Gemma 4 12B QAT | Medium Pro model lane | candidate card -> Pro Gated local runtime -> AnswerPacket | RuntimeRouter/System G | Pro | Pro Gated | no OOM, no silent CPU, no hidden fallback | memory, context cap, JSON/tool eval, citation eval | Pro license + hardware lease | explicit Pro local route | route card + RunEventLog | held-out code/research/note eval | unload model, revert route card | Medium | High until loader proof | 4 |
| Gemma 4 26B/31B QAT | Vault large lane | model card -> cold assembly/residency experiments | ActiveAssembly/Vault | Pro only | Pro Research/Vault | no MAS bytes; no live 70B-like claim | heavy memory/thermal, NIAH, rollback | owner-approved Pro Research | never silent default | research artifact only | long-context/thermal harness | remove route card | Medium | High | 6 |
| Qwen3-Coder A3B | Coding/tool lane | candidate tournament -> Pro route | System G/tool calling | Pro | Pro Gated/Research | JSON/tool failures bounded | tool-call grammar, structured output, cancel | Pro hardware + grammar witness | explicit coding route | AnswerPacket model card | coding eval + route log | fallback to smaller code model | Medium | Medium/high | 5 |
| Asymmetric KV/TurboQuant KV | Residency experiment | source card -> isolated harness -> optional runtime feature | ResidencyPageTable/ColdStream | Pro | Pro Research | no quality collapse; no NIAH cliff | K/V precision, entropy bands, NIAH, perplexity | owner-approved experiment only | no product route until L2 | telemetry packet | NIAH + held-out eval | disable KV compression | Medium | High | 7 |
| E8/NexusQuant lattice VQ | Extreme KV/context experiment | source card -> clean-room prototype -> harness | Vault/Residency | Pro | Pro Research | zero hidden eviction for factual tasks | license, NIAH cliff, eviction ledger | research only | no default | research card | NIAH/factual recall | disable eviction/lattice | Medium/high | High | 8 |

## New Canon Surfaces And Falsifiers

Each falsifier must emit a machine-readable artifact under `artifacts/falsifiers/.../result.json` and a doc/card update only when it passes.

| Falsifier | Artifact emitted | Invalid fixtures | Edge cases | Pass/fail metrics | Runtime bytes | Live? | L effect | Surfaces updated | False promotion |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| F-ProprietaryCompression-ProvenanceGate | provenance ledger with URL, license, digest, import mode | unknown license, GPL/AGPL conflict, copied code without notice | transitive deps, generated code, forks | every source has allowed action | 0 | metadata | L1 gate | docs/fusion, Living Index source cards | copying no-license code into proprietary path |
| F-TurboVec-EidosCompressedIndex | index card: dim, bit width, build digest, recall, latency, memory | wrong dim, NaN, Inf, huge coord, duplicate vector, zero vector | small dim, high dim, repeated vectors | recall@10 against exact baseline above threshold; no panic | live fixture only | live after metadata | L2 if pass | docs/falsifiers, artifacts | treating README benchmark as Epistemos proof |
| F-TurboVec-UASAddressStableExternalIds | UAS->u64 registry and collision ledger | deleted IDs, rowid reuse, duplicate UAS, hash collision fixture | rebuild/swap-remove, import/export | same UAS maps to same external id across rebuild | tiny fixture | metadata/live | blocks L2 | Eidos docs | using SQLite rowid as truth |
| F-TurboVec-FilterBeforeRankPrivacyGate | allowlist proof, forbidden-hit audit, result packet | forbidden plane, empty allowlist, unknown ID | all-denied, one allowed, duplicate allowed IDs | no forbidden ID scored/exposed; visible empty packet for no access | tiny fixture | live | L2 gate | Eidos route docs, AnswerPacket schema | vector search first, post-filter later |
| F-TurboVec-CrashSafePersistentIndex | manifest with temp, fsync, rename, digest, rebuild report | truncated file, corrupt magic, version mismatch, duplicate IDs | crash mid-write, old `.tv`/`.tvim` | rebuild recovers from AppColdStore; old manifest remains usable | fixture only | live | L2 gate | AppColdStore docs | trusting upstream persistence as durable truth |
| F-CompressedRetrieval-NoHiddenRouteAuthority | RunEventLog/AnswerPacket route proof | retrieval score changes model route without SCOPE-Rex | high score forbidden doc, empty retrieval | route decision cites policy, not raw score | 0 or tiny | metadata/live | blocks L2/L3 | RuntimeRouter docs | Eidos silently picks model |
| F-GemmaQAT-LocalRuntimeCandidateCard | model card JSON with ids, license, file sizes, hash, runtime path | missing license, unpinned repo, wrong format, no context cap | MLX vs GGUF confusion, mmproj mismatch | every claim source-backed; no runtime claim | 0 | metadata | L1 | docs/fusion, model catalog docs | saying repo exists means app can load |
| F-GemmaQAT-MemoryBudgetProbe | RSS/Metal/TTFT/cancel/thermal ledger | double-load, unload leak, OOM, thermal critical | 8k/32k/64k contexts, cancellation during prefill | no crash; cancellation bounded; memory under lease | model bytes | live | L2 | small-model harness docs | file size treated as runtime memory |
| F-GemmaQAT-StructuredOutputAndToolLedger | JSON/tool/citation eval | malformed JSON, wrong schema, hidden tool call | retry/no-retry, long citations | pass rate over held-out set; no raw CoT | model bytes | live | L2 | System G docs | "agentic" claim without tool eval |
| F-GemmaQAT-MTP-SpeculativeDecodingProof | target/drafter acceptance and rollback report | bad drafter, target mismatch, unsupported runtime | low acceptance, wrong token rollback | quality equal to target; speed claim measured | model bytes | live | L2 | runtime docs | advertising MTP speed from weights alone |
| F-QAT-vs-PTQ-QualityRegressionLedger | paired eval QAT/PTQ/BF16 if possible | QAT worse than PTQ, bad citations, bad JSON | coding/research/note synthesis | QAT not worse beyond budget; structured output passes | model bytes | live | L2 | model cards | laundering vendor QAT claims |
| F-LargeModelCompression-ClaimBoundaryGuard | copy/source guard report | "70B live", "SSD is RAM", "QAT proves runtime" | docs, UI strings, release notes | zero forbidden claims | 0 | metadata | L1/L2/L3 guard | Living Index, lattice HTML | marketing dense 70B as done |
| F-AsymmetricKV-SoftmaxStability | attention entropy/NIAH/perplexity ledger | low-bit K collapse, symmetric 2-bit K/V | long-context factual recall | no NIAH cliff; entropy within baseline band | model bytes | live research | L2 research | residency docs | enabling low-bit K in product |
| F-E8Lattice-EvictionRecallCliff | eviction-vs-recall curve | 35%+ factual token eviction, hidden eviction | needle, citations, tool args | factual recall threshold maintained | model bytes | live research | L2 research only | vault docs | treating low perplexity as factual recall |
| F-SilentCPUFallback-Veto | GPU/CPU/token-speed telemetry | GPU init fail, CPU fallback, mmap-only "VRAM" | slow decode with high memory | fail closed when token/s and GPU counters disagree | model bytes | live | L2 gate | runtime harness | shipping silent CPU route |

## Implementation Sketches

These are interface sketches, not code changes made in this pass.

### Rust Compressed Vector Adapter

Suggested placement: `agent_core/src/eidos/compressed_vector_index.rs`.

```rust
pub trait CompressedVectorIndex {
    fn add_checked(&mut self, rows: &[EmbeddingRow]) -> Result<IndexDelta, IndexError>;

    fn search_checked(
        &self,
        query: &[f32],
        allowed: &AllowedUasSet,
        k: core::num::NonZeroUsize,
    ) -> Result<Vec<ScoredUasHit>, IndexError>;

    fn persist_atomic(&self, manifest: &IndexManifest) -> Result<Digest, PersistError>;

    fn rebuild_from_coldstore(
        &mut self,
        source: &AppColdStore,
    ) -> Result<RebuildReport, RebuildError>;
}

pub struct EmbeddingRow {
    pub uas: UasAddress,
    pub external_id: u64,
    pub vector: Vec<f32>,
    pub plane: PlaneId,
    pub source_digest: [u8; 32],
}
```

Adapter rule: wrap all TurboVec calls with typed errors. Never expose upstream panics to app code.

### UAS Address To External ID Mapping

Suggested placement: `agent_core/src/uas/vector_id_registry.rs`.

```rust
pub struct UasVectorId {
    pub uas: UasAddress,
    pub external_id: u64,
    pub collision_digest: [u8; 32],
}

pub trait VectorIdRegistry {
    fn get_or_allocate(&mut self, uas: &UasAddress) -> Result<UasVectorId, IdRegistryError>;
    fn resolve(&self, external_id: u64) -> Option<UasAddress>;
    fn tombstone(&mut self, uas: &UasAddress) -> Result<(), IdRegistryError>;
}
```

Do not use SQLite `rowid` as the semantic ID. Allocate a stable `u64` once, persist it beside UAS, and keep tombstones or generation counters so delete/reinsert cannot silently alias evidence.

### Filter Before Rank

Suggested placement: `agent_core/src/eidos/sovereign_filtered_search.rs`.

```rust
pub fn filtered_eidos_search(
    index: &dyn CompressedVectorIndex,
    query: &[f32],
    policy: &SovereignGatePolicy,
    mission: &MissionPacket,
) -> Result<EidosEvidencePacket, SearchDenied> {
    let allowed = policy.compile_allowed_uas(mission)?;

    if allowed.is_empty() {
        return Ok(EidosEvidencePacket::empty_visible("no allowed objects"));
    }

    let hits = index.search_checked(
        query,
        &allowed,
        mission.retrieval_budget.k,
    )?;

    EidosEvidencePacket::from_hits_after_exact_source_check(hits)
}
```

The key invariant: metadata/privacy predicates are compiled before vector ranking. Post-filtering may exist as a defense-in-depth check, but it must not be the only privacy barrier.

### Crash-Safe Persistence Plan

Suggested placement: wrapper around TurboVec write in `agent_core/src/eidos/turbovec_persist.rs`.

1. Build or mutate index in memory.
2. Write to `index.next.tvim`.
3. Flush file handle.
4. fsync file.
5. Write manifest with engine version, dim, bit width, source embedding manifest, count, digest.
6. fsync manifest.
7. Rename `index.next.tvim` to content-addressed path.
8. Atomically swap current manifest pointer.
9. fsync parent directory.
10. Keep previous manifest until new index passes search smoke.

If load fails, delete only the cache pointer and rebuild from AppColdStore exact embeddings. AppColdStore remains the truth.

### Rebuild And Rollback

```rust
pub struct RebuildReport {
    pub source_manifest: Digest,
    pub previous_index: Option<Digest>,
    pub rebuilt_index: Digest,
    pub rows_expected: usize,
    pub rows_indexed: usize,
    pub recall_smoke_passed: bool,
    pub rollback_available: bool,
}
```

Rollback is a manifest-pointer operation, not a best-effort file overwrite.

### Benchmark Harness Pseudocode

Suggested placement: `Tools/falsifiers/falsify_turbovec_eidos_compressed_index.rs`.

```rust
fn run_fixture(fixture: Fixture) -> Result<FalsifierResult, Failure> {
    let exact = ExactFlatIndex::from_fixture(&fixture)?;
    let compressed = TurboVecAdapter::build_shadow(&fixture)?;

    for selectivity in [1.0, 0.10, 0.01, 0.001] {
        let allowlist = fixture.allowed_ids(selectivity);
        let exact_hits = exact.search_with_allowlist(&fixture.queries, &allowlist, 10)?;
        let compressed_hits = compressed.search_checked(&fixture.queries, &allowlist, 10)?;
        assert_recall_budget(exact_hits, compressed_hits)?;
        assert_no_forbidden_ids(compressed_hits, &allowlist)?;
    }

    corrupt_persistence_bytes_and_require_rebuild()?;
    concurrent_search_mutation_must_be_rejected_by_wrapper()?;

    Ok(FalsifierResult::pass_with_artifact())
}
```

Fixtures: small dataset, high dimension, duplicate vectors, zero vector, NaN, Inf, huge coordinate, Unicode metadata, deleted ID, empty allowlist, unknown allowlist ID, partial write, concurrent search plus attempted insert.

### AnswerPacket And RunEventLog Witness Fields

Do not store raw chain-of-thought. Store route and compression proof.

```rust
pub struct CompressedRetrievalWitness {
    pub index_engine: String,
    pub index_digest: Digest,
    pub source_embedding_manifest: Digest,
    pub dim: usize,
    pub bit_width: u8,
    pub allowed_count: usize,
    pub result_count: usize,
    pub filtered_before_rank: bool,
    pub exact_rerank_used: bool,
    pub forbidden_hits: usize,
    pub source_cards: Vec<SourceCardRef>,
}

pub struct LocalModelRuntimeWitness {
    pub model_id: String,
    pub runtime: String,
    pub quantization: String,
    pub model_file_digest: Option<Digest>,
    pub model_file_bytes: u64,
    pub context_limit_tokens: usize,
    pub prompt_tokens: usize,
    pub completion_tokens: usize,
    pub peak_resident_bytes: u64,
    pub peak_metal_allocated_bytes: Option<u64>,
    pub first_token_ms: u64,
    pub decode_tokens_per_second: f32,
    pub cancellation_supported: bool,
    pub network_opened: bool,
}
```

### Memory Preflight For QAT Model Loading

Suggested placement: `Epistemos/Engine/LocalModelResidencyPreflight.swift`.

```swift
struct ModelResidencyEstimate {
    let modelFileBytes: UInt64
    let mmprojBytes: UInt64
    let contextTokens: Int
    let layers: Int
    let kvHeads: Int
    let headDim: Int
    let keyBits: Int
    let valueBits: Int
    let runtimeOverheadBytes: UInt64
    let safetyReserveBytes: UInt64

    func ceilBitsToBytes(_ elementCount: UInt64, _ bits: Int) -> UInt64 {
        return (elementCount * UInt64(bits) + 7) / 8
    }

    func estimatedBytes() -> UInt64 {
        let elems = UInt64(contextTokens * layers * kvHeads * headDim)
        let keyBytes = ceilBitsToBytes(elems, keyBits)
        let valueBytes = ceilBitsToBytes(elems, valueBits)
        return modelFileBytes
            + mmprojBytes
            + keyBytes
            + valueBytes
            + runtimeOverheadBytes
            + safetyReserveBytes
    }
}
```

For Gemma 4, generic KV math is only a guardrail because the config uses shared/sliding/global attention patterns. The harness must measure actual RSS/Metal allocation.

### Local Runtime Ladder

```swift
enum LocalRouteAdmission {
    case reject(reason: String)
    case metadataOnly(cardID: String)
    case proResearch(cardID: String)
    case proGated(cardID: String, lease: ResidencyLease)
    case masSafeFloor(cardID: String, lease: ResidencyLease)
}

func admitLocalRoute(
    model: LocalModelCandidateCard,
    mission: MissionPacket,
    telemetry: RuntimeTelemetry,
    ownerPolicy: OwnerRoutePolicy
) -> LocalRouteAdmission {
    guard model.requiresNetwork == false else {
        return .reject(reason: "network route not allowed")
    }
    guard ownerPolicy.allows(model.modelID) else {
        return .reject(reason: "owner policy rejected model")
    }
    guard model.productBuild != .mas || model.masWitnessPassed else {
        return .metadataOnly(cardID: model.cardID)
    }
    guard telemetry.thermalState != .critical else {
        return .reject(reason: "thermal critical")
    }
    guard model.loaderWitnessPassed else {
        return .proResearch(cardID: model.cardID)
    }
    guard model.structuredOutputWitnessPassed else {
        return .proResearch(cardID: model.cardID)
    }
    guard telemetry.availableBytes > model.requiredLeaseBytes else {
        return .reject(reason: "memory lease failed")
    }
    return model.productBuild == .mas
        ? .masSafeFloor(cardID: model.cardID, lease: model.lease)
        : .proGated(cardID: model.cardID, lease: model.lease)
}
```

No hidden cloud fallback. No hidden provider route. No automatic Gemma 4 Swift MLX promotion until loader witness exists.

## Risk Audit

| Risk | Severity | Likelihood | Mitigation | Falsifier/witness | Blocks |
| --- | --- | --- | --- | --- | --- |
| TurboVec panic/crash from bad vectors or caller contracts | High | Medium | typed wrapper, fixture invalid inputs, no untrusted direct calls | F-TurboVec-EidosCompressedIndex | MAS/Pro Live |
| Corrupted TurboVec persistence | High | Medium | atomic write, fsync, manifest, digest, rebuild from AppColdStore | F-TurboVec-CrashSafePersistentIndex | MAS/Pro Live |
| Privacy leak via post-filter retrieval | Critical | Medium | compile allowlist before search; exact source check after | F-TurboVec-FilterBeforeRankPrivacyGate | All live |
| UAS/external ID aliasing | Critical | Medium | stable registry, collision ledger, tombstones | F-TurboVec-UASAddressStableExternalIds | All live |
| Hidden route authority from retrieval scores | Critical | Medium | SCOPE-Rex admission, visible route card, AnswerPacket proof | F-CompressedRetrieval-NoHiddenRouteAuthority | All live |
| Gemma 4 12B OOM/double load | High | Medium/high | singleton runner, lease, cancellation, unload proof | F-GemmaQAT-MemoryBudgetProbe | Pro Live |
| Swift MLX Gemma 4 loader gap | High | High today | keep auto-route exclusion; use GGUF/LiteRT first or implement loader | loader witness | Pro Live/MAS |
| MTP false speed claims | Medium | High | target/drafter acceptance ledger, rollback | F-GemmaQAT-MTP-SpeculativeDecodingProof | L2/L3 |
| QAT/GGUF conversion laundering | High | Medium | official hashes, no custom conversion claims, QAT-vs-PTQ ledger | F-QAT-vs-PTQ-QualityRegressionLedger | L2/L3 |
| MAS/Pro boundary leak | Critical | Medium | typed ProductBuild/ProStatus, no Pro model bytes in MAS | MAS source guard | MAS |
| False 70B marketing | Critical | High | copy guard, L1/L2/L3 separation | F-LargeModelCompression-ClaimBoundaryGuard | All |
| Benchmark laundering | High | High | held-out fixtures, local hardware artifact, source-card separation | model and index harness | Pro Live |
| Unknown-license cherry-pick | Critical | Medium | provenance gate, clean-room design notes | F-ProprietaryCompression-ProvenanceGate | Product |
| Ecosystem abandonment | Medium | High | adapter boundary, pinned versions, rollback | candidate cards | Pro Live |
| E8/token eviction factual recall cliff | High | Medium | NIAH/citation recall curve, no hidden eviction | F-E8Lattice-EvictionRecallCliff | Pro Live |
| Softmax/KV quantization collapse | High | Medium | keep K higher precision, compare entropy bands and NIAH | F-AsymmetricKV-SoftmaxStability | Pro Live |
| Silent CPU fallback | High | Medium | GPU telemetry, token speed floor, fail closed | F-SilentCPUFallback-Veto | Pro Live |

## Recommended Implementation Order

1. Add source-card canon for TurboVec, TurboQuant, Gemma 4 QAT, MLX, LiteRT, and adjacent KV/lattice research as L1 only.
2. Implement `F-ProprietaryCompression-ProvenanceGate`.
3. Implement `F-GemmaQAT-LocalRuntimeCandidateCard` metadata-only for all Gemma 4 QAT IDs.
4. Implement `F-LargeModelCompression-ClaimBoundaryGuard`.
5. Implement `F-TurboVec-UASAddressStableExternalIds`.
6. Implement `F-TurboVec-FilterBeforeRankPrivacyGate`.
7. Implement `F-TurboVec-CrashSafePersistentIndex`.
8. Run tiny live TurboVec fixtures only after wrappers exist.
9. Add Gemma 4 12B Pro candidate card, but do not load it until memory preflight and owner-approved Pro gate exist.
10. Test Gemma 4 E2B/E4B mobile/GGUF as MAS Research, not MAS default.
11. Test Gemma 4 12B through GGUF or LiteRT-LM first unless Swift MLX Gemma 4 loader is implemented.
12. Run Qwen3-Coder A3B, GLM-4.7-Flash, DeepSeek 14B, and Granite micro in a local route tournament.
13. Keep 26B/31B/asymmetric KV/E8 lattice in Pro Research until L2 artifacts exist.

## Hard Do Not Do

- Do not claim Gemma 4 QAT makes dense 70B live.
- Do not claim MLX repo existence means Epistemos Swift runtime support.
- Do not silently route to cloud if a local model fails.
- Do not let TurboVec scores choose a model route directly.
- Do not store raw chain-of-thought in AnswerPacket.
- Do not use SQLite `rowid` as UAS truth.
- Do not run 12B/26B/31B experiments in MAS.
- Do not copy no-license or incompatible-license code into proprietary product logic.
- Do not trust same-day QAT/MLX conversions as product-ready without local proof.
- Do not advertise MTP speedups without target/drafter acceptance and rollback proof.
- Do not treat perplexity as factual recall for long-context agent work.
- Do not use token eviction for citation/tool-argument retention unless NIAH/citation recall passes.
- Do not use low-bit Key cache in production without softmax stability evidence.
- Do not hide PatternBoost influence. PatternBoost remains offline only.

## Open Questions For Owner

- Should the first Gemma 4 12B Pro lane target GGUF/llama.cpp, LiteRT-LM, or a new Swift MLX loader?
- What is the minimum Pro Gated hardware target for 12B: 16GB, 24GB, or 32GB unified memory?
- Is MAS allowed to ship model files above 1GB, or should MAS start with downloadable/owner-approved local model cards?
- Should AppColdStore store exact float32 embeddings for rebuild, or regenerate embeddings from source text? Exact storage costs more but makes TurboVec rebuild deterministic.
- Should TurboVec be an optional Cargo dependency, a vendored dependency, or an external adapter until falsifiers pass?
- What proprietary policy should govern Apache/MIT source imports: dependency only, vendored with patches, or clean-room reimplementation?
- Is multimodal/audio a near-term requirement for Gemma 4 12B, or should the first route be text-only for stability?
- Should Qwen3-Coder remain the primary tool/coding lane while Gemma 4 12B proves JSON/tool behavior?

## Living Index Canon Paragraph

Gemma 4 QAT and TurboVec are compression candidates, not product promotions. TurboVec may become a Pro Research Eidos/AppColdStore compressed vector cache only after UAS-stable IDs, filter-before-rank privacy, crash-safe rebuild, rollback, RunEventLog, and AnswerPacket witnesses pass. Gemma 4 QAT E2B/E4B/12B may become local model ladder candidates only after model-card, license, memory, cancellation, structured-output, loader, and visible-route proofs pass. MLX repository availability is not Swift runtime proof. These witnesses do not prove live dense 70B; 70B-class architecture remains cold assembly, routing, residency, transport, verifier, and harness work.

## Lattice HTML Copy Block

```html
<section data-plane="compression-research" data-truth-level="L1">
  <h2>Compression Research</h2>
  <p>
    TurboVec/TurboQuant and Gemma 4 QAT are architecture candidates only
    unless a named falsifier artifact promotes them. TurboVec is scoped to
    compressed Eidos/AppColdStore retrieval. Gemma 4 QAT is scoped to the
    local model ladder. MLX repository support is not Epistemos Swift runtime
    proof. No hidden provider route, no hidden PatternBoost authority, no
    live dense 70B claim, and no answer-affecting model route without
    RunEventLog plus AnswerPacket proof.
  </p>
</section>
```

## Next-Session Coding Prompt

Read-only first. Implement `F-GemmaQAT-LocalRuntimeCandidateCard` as a metadata-only falsifier that scans pinned Hugging Face model IDs for Gemma 4 QAT E2B/E4B/12B/26B/31B, records license, format, file sizes, context config, runtime path, model hash fields if available, ProductBuild, ProStatus, ResidencyStatus, L1/L2/L3 status, and rejects any claim that QAT proves live runtime, MAS readiness, cloud fallback, MTP speedup, Swift MLX loader support, or dense 70B completion. Do not load model bytes. Do not run MLX/GGUF. Update Living Index/lattice only if the writer owns the worktree and artifact regeneration is authorized.

## Final Research Position

The ambitious path is to make Epistemos' proprietary advantage the admission system, not the borrowed compression trick. TurboVec, Gemma QAT, Qwen/GLM/Granite model cards, TurboQuant KV ideas, and E8 lattice research can all become inputs. Epistemos should own the UAS mapping, AppColdStore rebuild contract, SCOPE-Rex admission, RuntimeRouter lease, RunEventLog/AnswerPacket proof, and falsifier ladder. That is how the app can cherry-pick the best available ideas without lying about readiness, leaking MAS/Pro boundaries, or importing unsafe code.

## Addendum: Second-Source Reconciliation

Date: 2026-06-06, later pass.

Reason: owner supplied another research packet with stronger Gemma 4 model-card, MTP, MLX-collection, Qwen3, Granite 4.1, and TurboQuant KV claims. The added material is directionally useful. The corrections below supersede the narrower first-pass candidate notes where they conflict.

### Gemma 4 Official Model-Card Details

The official Google AI Gemma 4 model card strengthens the Gemma 4 lane recommendation:

- Gemma 4 is listed in five sizes: E2B, E4B, 12B Unified, 26B A4B MoE, and 31B Dense.
- The 12B model is `Gemma 4 12B Unified`, about 11.95B parameters.
- E2B/E4B support text, image, and audio.
- 12B Unified supports text, image, and audio, and uses an encoder-free multimodal architecture.
- 31B supports text and image, not audio.
- E2B/E4B have 128K context. 12B/26B-A4B/31B have 256K context.
- The model card explicitly lists native system-prompt support, function calling, coding, long context, thinking mode, and audio support for E2B/E4B/12B.
- The card says global layers feature unified Keys and Values and proportional RoPE for long-context memory.

Source: https://ai.google.dev/gemma/docs/core/model_card_4

Epistemos effect: Gemma 4 12B QAT remains the primary Pro Gated/Pro Live target, but its strongest canon wording should be "12B Unified local lane" rather than just "12B QAT." The unified architecture matters because it changes multimodal memory planning and makes generic Llama-style KV estimates less reliable.

### Gemma 4 QAT Memory Numbers

The QAT blog states that an image in the post gives approximate memory required to load the models. The image is not text-extractable in the browser tool, but the owner-supplied packet gives these values:

| Model | Owner-supplied official Q4_0 load-memory figure |
| --- | ---: |
| Gemma 4 E2B QAT | 2.9 GB |
| Gemma 4 E4B QAT | 4.5 GB |
| Gemma 4 12B QAT | 6.7 GB |
| Gemma 4 26B A4B QAT | 14.4 GB |
| Gemma 4 31B QAT | 17.5 GB |

Reconciliation with file-size measurements:

- These numbers are load-memory estimates, not repository blob totals.
- Earlier blob totals remain useful for download/storage/package budgeting.
- Official GGUF blob totals from the first pass were larger for E2B/E4B because the totals included `mmproj` files. That does not contradict load-memory estimates for the model component.
- For Epistemos, both numbers matter: file total for packaging/download, measured RSS/Metal allocation for route admission.

Updated canon line: "Google's QAT post gives approximate model-load memory and the official ecosystem supplies QAT artifacts; Epistemos still needs host-class MemoryBudgetProbe results because load-memory does not include prompt tokens, KV cache, runtime overhead, GUI pressure, swap pressure, or model switching."

Source: https://blog.google/innovation-and-ai/technology/developers-tools/quantization-aware-training-gemma-4/

### Gemma 4 MTP Status

Gemma 4 MTP is stronger than "possible speed lane." It is an official released drafter family:

- Google announced MTP drafters on 2026-05-05.
- The MTP docs describe target models plus smaller drafter models.
- The drafter proposes multiple tokens, then the target verifies them in parallel.
- Google says the drafters use target activations and KV cache to improve predictions.
- Google reports testing on hardware using LiteRT-LM, MLX, Hugging Face Transformers, and vLLM.
- The docs expose `assistant_model` usage in Transformers and adaptive `num_assistant_tokens_schedule`.

Sources:

- https://blog.google/innovation-and-ai/technology/developers-tools/multi-token-prediction-gemma-4/
- https://ai.google.dev/gemma/docs/mtp/mtp

Epistemos effect: add a distinct route state, `MTPCandidate`, separate from base model admission. A Gemma 4 model can pass model-load and structured-output probes while its MTP drafter remains unadmitted. MTP must record acceptance rate, rejected-token count, target/drafter IDs, and fallback behavior in RunEventLog.

New falsifier refinement:

| Falsifier | Added acceptance metric |
| --- | --- |
| F-GemmaQAT-MTP-SpeculativeDecodingProof | target/drafter ID match, acceptance-rate distribution, deterministic rollback after rejection, no hidden speed claim if drafter disabled, no AnswerPacket token accounting drift |

### MLX Gemma 4 QAT Variant Breadth

The MLX community Gemma 4 QAT ecosystem is broader than the first-pass table. HF search verified:

- `mlx-community/gemma-4-12B-it-qat-4bit`
- `mlx-community/gemma-4-12B-it-qat-5bit`
- `mlx-community/gemma-4-12B-it-qat-6bit`
- `mlx-community/gemma-4-12B-it-qat-8bit`
- `mlx-community/gemma-4-12B-it-qat-bf16`
- `mlx-community/gemma-4-12B-it-qat-mxfp4`
- `mlx-community/gemma-4-12B-it-qat-nvfp4`
- `mlx-community/gemma-4-12B-it-qat-mxfp8`
- MTP assistant variants exist for 26B-A4B and 31B in 4/5/6/8-bit, BF16, MXFP4, NVFP4, and MXFP8 forms.

Source: https://huggingface.co/collections/mlx-community/gemma-4 and HF model search.

Epistemos effect: candidate-card scanning should not hard-code only `*-qat-4bit`. It should query or pin a model family list by:

- target vs assistant
- size
- bit width
- quant family (`4bit`, `mxfp4`, `nvfp4`, `mxfp8`, `bf16`)
- model architecture tag (`gemma4`, `gemma4_unified`, `gemma4_assistant`)
- license tag and base model lineage

Boundary remains: MLX repo presence is real MLX ecosystem availability, but not Epistemos Swift loader proof.

### Qwen Comparator Correction

The owner packet referenced Qwen3-30B-A3B, not only the coder variant. HF verified these current comparator lanes:

| Model | Verified path | License | Role |
| --- | --- | --- | --- |
| `Qwen/Qwen3-30B-A3B` | Transformers | Apache-2.0 | general thinking/non-thinking comparator |
| `Qwen/Qwen3-30B-A3B-Instruct-2507` | Transformers | Apache-2.0 | stronger instruct comparator |
| `mlx-community/Qwen3-30B-A3B-4bit` | MLX | Apache-2.0 | Apple Silicon comparator |
| `mlx-community/Qwen3-30B-A3B-Instruct-2507-4bit` | MLX | Apache-2.0 | Apple Silicon instruct comparator |
| `Qwen/Qwen3-Coder-30B-A3B-Instruct` | Transformers | Apache-2.0 | coding/tool comparator |
| `mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit` | MLX | Apache-2.0 | Apple Silicon coding lane |

Epistemos effect: split Qwen into two comparator families:

- `Qwen3-30B-A3B`: general reasoning/thinking-mode comparator.
- `Qwen3-Coder-30B-A3B`: coding/tool-call comparator.

Do not use the stale local names `Qwen3.5-35B-A3B` without a source-card.

### Granite 4.1 Correction

The first-pass report used Granite 4.0 H Micro because that was already verified. The second pass verified Granite 4.1 and should supersede that comparator:

| Model | Verified path | License | Role |
| --- | --- | --- | --- |
| `ibm-granite/granite-4.1-3b` | Transformers | Apache-2.0 | MAS/Pro low-risk enterprise baseline |
| `ibm-granite/granite-4.1-8b` | Transformers | Apache-2.0 | Pro writing/research/tool baseline |
| `ibm-granite/granite-4.1-30b` | Transformers | Apache-2.0 | Pro Research large comparator |
| `ibm-granite/granite-4.1-3b-GGUF` | GGUF | Apache-2.0 | local runtime baseline |
| `ibm-granite/granite-4.1-8b-GGUF` | GGUF | Apache-2.0 | local runtime baseline |
| `ibm-granite/granite-4.1-30b-GGUF` | GGUF | Apache-2.0 | large local research comparator |

The exact IDs `ibm-granite/granite-4.1-h-micro` and `ibm-granite/granite-4.1-h-tiny` were not valid in HF detail lookup. Use the verified `3b`, `8b`, and `30b` IDs.

Sources:

- https://research.ibm.com/blog/granite-4-1-ai-foundation-models
- https://huggingface.co/ibm-granite/granite-4.1-3b
- https://huggingface.co/ibm-granite/granite-4.1-8b
- https://huggingface.co/ibm-granite/granite-4.1-30b

### TurboQuant KV On Mac: Updated Nuance

The earlier recommendation that TurboQuant KV cache should stay Pro Research remains correct, but the status is more nuanced than "reject on Mac." Current public evidence shows:

- MLX issue #3404 requested native quantized KV support in `mx.fast.scaled_dot_product_attention` and describes existing MLX ecosystem POCs using Metal kernels.
- vLLM-metal documentation now claims TurboQuant-based KV cache compression on Apple Silicon using MLX plus a Metal kernel.
- vLLM-metal lists caveats: paged attention required, TurboQuant cannot run on the MLX KV cache path, MLA unsupported, head dimension must be 64/128/256, and quality is model-dependent.
- vLLM-metal's own quality-floor text says aggressive Key quantization fails before aggressive Value quantization because Key errors are amplified by softmax.
- 0xSero/turboquant is GPL-3.0 and CUDA/Triton/vLLM-oriented, so it is not proprietary-product-copyable and not directly a Mac product path.
- llama.cpp has public WIP Apple Silicon/Metal discussion for TurboQuant/TQ4 KV.

Sources:

- https://github.com/ml-explore/mlx/issues/3404
- https://docs.vllm.ai/projects/vllm-metal/en/latest/turboquant/
- https://github.com/0xSero/turboquant
- https://github.com/ggml-org/llama.cpp/discussions/21243

Updated Epistemos decision:

- Do not reject TurboQuant KV as impossible on Mac.
- Do reject it as MAS/Pro Live product logic today.
- Treat it as `ProResearch.KVCompression.MacMetal`, with a stronger chance of becoming real than the first pass implied.
- License gate is mandatory: GPL-3.0 repos are source-card only for proprietary Epistemos.
- Admission requires `F-SilentCPUFallback-Veto`, `F-AsymmetricKV-SoftmaxStability`, `F-GemmaQAT-MTP-KVCompatibility`, and `F-KVCompression-RuntimePathProof`.

### Revised Local Ladder

| Lane | Primary model | Comparator | Status |
| --- | --- | --- | --- |
| MAS floor | Gemma 4 E2B/E4B QAT, text-first or modality-stripped | Granite 4.1 3B GGUF | Candidate only until MAS harness |
| Pro Live target | Gemma 4 12B Unified QAT | Qwen3-30B-A3B 4bit, Granite 4.1 8B | Highest priority |
| Pro coding/tool comparator | Gemma 4 12B QAT | Qwen3-Coder-30B-A3B-Instruct 4bit | Tournament required |
| Pro Gated heavy | Gemma 4 26B-A4B QAT | Qwen3-30B-A3B-Instruct-2507 4bit, GLM-4.7-Flash 4bit | 24/32GB+ only after lease |
| Vault Research | Gemma 4 31B QAT | Granite 4.1 30B, GLM-4.7-Flash | host-class cards only |
| KV Research | TurboQuant/vLLM-metal/MLX POCs | E8/NexusQuant/FibQuant/OCTOPUS source cards | no product route |

### Updated Next Coding Prompt

```text
Read-only first. Extend the existing Gemma QAT candidate-card falsifier plan so it scans:

- google/gemma-4-{E2B,E4B,12B,26B-A4B,31B}-it-qat-q4_0-* target models
- matching `-assistant` MTP models
- mlx-community Gemma 4 QAT variants: 4bit/5bit/6bit/8bit/bf16/mxfp4/nvfp4/mxfp8
- Qwen3-30B-A3B and Qwen3-Coder-30B-A3B comparator lanes
- Granite 4.1 3B/8B/30B and GGUF comparator lanes

For each card, emit: target_or_assistant, architecture tag, base model, license, file sizes, runtime family, Swift-loader status, MTP support, context limit, ProductBuild, ProStatus, ResidencyStatus, L1/L2/L3 status, and claim-boundary denials.

Do not load model bytes. Do not run MLX/GGUF. Do not promote MLX community availability to Epistemos Swift runtime support. Do not copy GPL code. Keep TurboQuant KV as Pro Research until runtime-path, softmax-stability, MTP-compatibility, and silent-CPU-fallback falsifiers pass.
```

### Addendum Canon Paragraph

Gemma 4 QAT is now an official multi-format local model ladder with E2B/E4B/12B/26B-A4B/31B targets, matching MTP assistant models, GGUF and mobile surfaces, and broad MLX community conversions. Epistemos should treat Gemma 4 12B Unified QAT as the main Pro local assistant target and E2B/E4B as MAS-floor candidates, while separately proving MTP, Swift loader support, memory, cancellation, and structured output. TurboVec remains the retrieval-side compression candidate. TurboQuant KV on Mac is no longer just hypothetical, but it remains Pro Research until Metal/MLX/vLLM runtime-path, softmax-stability, and license/provenance falsifiers pass. None of these updates promote live dense 70B.

## Addendum: Runtime-Plural Epistemos Assistant Track

Accessed 2026-06-06.

The latest owner packet changes the local-assistant strategy in one important way: Epistemos must be MLX-first on Apple Silicon, but never MLX-only. The no-compromise stack is runtime-plural and policy-single:

```text
MLX-first on Apple Silicon
GGUF/llama.cpp as the official QAT fallback and baseline
LiteRT-LM as the native Swift/macOS/iOS edge lane
External local OpenAI-compatible providers as optional user-selected bridges
vLLM/SGLang as Pro Research/server-only paths
System G + RuntimeRouter + SovereignGate + AnswerPacket above all runtimes
```

This preserves the proprietary value of Epistemos. The proprietary layer is not an imported runtime. It is the admission contract, route witness, privacy gate, memory preflight, claim boundary, RunEventLog, AnswerPacket, falsifier harness, rollback policy, MAS/Pro split, and local evidence plane.

### Runtime-Plural Canon

| Runtime lane | Epistemos use | Admission status | Verified source signal | Claim boundary |
| --- | --- | --- | --- | --- |
| MLX / `mlx-vlm` | Primary Apple Silicon multimodal Gemma 4 lane | Pro Gated first | Google documents Gemma with `mlx_lm.generate`, `mlx_vlm.generate`, and `mlx_vlm.server` with an OpenAI-compatible endpoint. | Good Python/server path; not proof of native Swift parity. |
| MLX / `mlx-lm` | Text-only Qwen, Granite, smaller planner models | Pro Live/Gated by memory | MLX is Apple Silicon focused and has HF model integration. | Runtime quant semantics are MLX-specific; do not blur with GGUF Q4_0. |
| GGUF / llama.cpp | Official QAT baseline, broad fallback, local server | Pro Live/Gated depending model | Official Google Gemma 4 12B QAT GGUF card exists and is Apache-2.0 tagged. | Baseline truth path, not automatically the fastest path. |
| LiteRT-LM | Native Swift/macOS/iOS edge lane | MAS/Pro candidate after harness | Google LiteRT-LM Swift API says native iOS/macOS, multimodality, tool use, and Metal GPU acceleration are supported. HF has E2B/E4B/12B LiteRT-LM repos. | Swift API is promising but must pass Epistemos harness before MAS. |
| External local OpenAI endpoints | User-selected bridges to LM Studio/Ollama/Hermes/OpenCode-style providers | Optional only | Local endpoint pattern is widely used by MLX, llama.cpp, and Hermes-style local Mac flows. | Not canonical authority; never hidden fallback. |
| vLLM/SGLang | Server or Pro Research experiments | Pro Research | Useful for GLM/Qwen and research serving paths. | Not the local-first macOS default. |

Sources:

- https://ai.google.dev/gemma/docs/integrations/mlx
- https://developers.google.com/edge/litert-lm/swift
- https://huggingface.co/google/gemma-4-12B-it-qat-q4_0-gguf
- https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm
- https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm
- https://huggingface.co/litert-community/gemma-4-12B-it-litert-lm

### MLX QAT Label Correction

The previous addendum verified that MLX community Gemma 4 QAT-labeled repos exist, including `mlx-community/gemma-4-12B-it-qat-4bit`. The latest packet adds the correct product rule:

- If an MLX repo ID lacks `-qat-`, Epistemos must not call it QAT.
- If an MLX repo ID includes `-qat-`, Epistemos may mark it `qat_labeled_mlx_candidate`, but still requires base-model provenance, source checkpoint, conversion log or hash witness, runtime quant kind, and license card before routing.
- The official Google GGUF Q4_0 artifact remains the cleanest QAT baseline because its HF tags point to `google/gemma-4-12B-it-qat-q4_0-unquantized` as the quantized base and list Apache-2.0.
- MLX quant kinds remain distinct from GGUF quant kinds: `mlx:4bit`, `mlx:8bit`, `mlx:nvfp4`, `mlx:mxfp4`, and `gguf:q4_0` are not interchangeable labels.

Current candidate-card rule:

```text
do_not_call_qat =
  runtime == MLX
  and model_id does not include "-qat-"
  and no conversion_witness_from_official_qat_source exists

admit_as_qat_runtime_candidate =
  official QAT source card exists
  and runtime quant kind is recorded separately
  and hash/license/provenance are present
  and route witness distinguishes MLX from GGUF
```

### Native Swift Lane Status

LiteRT-LM is the better near-term native Swift/macOS/iOS lane than MLX Swift for Gemma 4. Google documents a Swift API with Metal acceleration, multimodality, and tool use. HF detail lookup also verified current LiteRT-LM Gemma 4 repos:

| Repo | Library | License | Updated | Role |
| --- | --- | --- | --- | --- |
| `litert-community/gemma-4-E2B-it-litert-lm` | `litert-lm` | Apache-2.0 | 2026-06-05 | MAS/edge candidate |
| `litert-community/gemma-4-E4B-it-litert-lm` | `litert-lm` | Apache-2.0 | 2026-06-01 | stronger edge candidate |
| `litert-community/gemma-4-12B-it-litert-lm` | `litert-lm` | Apache-2.0 | 2026-06-03 | Pro Gated native lane |

By contrast, `mlx-swift` issue #389 reports that `mlx-community/gemma-4-E2B-it-4bit` fails in Swift because model type `gemma4` is not supported. That does not reduce MLX Python/server value, but it blocks any claim that MLX Gemma 4 is currently a proven native Swift inference path.

Sources:

- https://developers.google.com/edge/litert-lm/swift
- https://github.com/ml-explore/mlx-swift/issues/389

### Five Local Brains

Epistemos Assistant should not standardize on one "best model." It should standardize on a witnessed local brain ladder.

| Brain | Default candidates | Authority boundary |
| --- | --- | --- |
| Planner / router brain | Gemma 4 E2B/E4B or Granite small | Proposes route only; never final authority. |
| Main answer brain | Gemma 4 12B QAT via MLX if proven, GGUF Q4_0 as official baseline, LiteRT-LM if native path wins | Produces L2 generated answers with visible route witness. |
| Coding brain | Qwen3-Coder-30B-A3B-Instruct, MLX 4bit on high-memory Macs | Pro Gated; patch authority remains ActiveAssembly + RunEventLog. |
| Structured-output fallback brain | Granite 4.0 H Tiny GGUF, Granite 4.1 3B/8B, or small Gemma | Deterministic JSON/classification lane; no hidden repair. |
| Verifier / critique brain | DeepSeek/R1/Phi/GLM candidates | Critiques only; cannot promote claims or run tools by itself. |

HF detail lookup confirmed:

| Candidate | Verified metadata | Epistemos placement |
| --- | --- | --- |
| `Qwen/Qwen3-Coder-30B-A3B-Instruct` | Apache-2.0, `qwen3_moe`, 30.5B params, 10.9M downloads | Pro Gated coding source card |
| `mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit` | Apache-2.0, MLX, `qwen3_moe`, 4-bit | high-memory Pro Gated coding lane |
| `ibm-granite/granite-4.0-h-tiny-GGUF` | Apache-2.0, GGUF, 39.8K downloads | structured fallback comparator |
| `zai-org/GLM-4.7-Flash` | MIT, `glm4_moe_lite`, 31.2B params | Pro Research verifier/comparator |

Sources:

- https://huggingface.co/Qwen/Qwen3-Coder-30B-A3B-Instruct
- https://huggingface.co/mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit
- https://huggingface.co/ibm-granite/granite-4.0-h-tiny-GGUF
- https://huggingface.co/zai-org/GLM-4.7-Flash

### External Ideas To Cherry-Pick

Ambition is correct; untracked code import is not. This should not become a timid "license says no, ignore it" policy. The goal is to extract the best logic aggressively while keeping Epistemos proprietary and shippable.

Use four intake tracks:

| Track | What Epistemos gets | When to use |
| --- | --- | --- |
| Direct import | Actual source code, vendored/forked modules, notices, commit pin, tests | Permissive license or explicit owner permission. |
| Adapter import | External process, local endpoint, CLI/server bridge, no core linking | Useful runtime exists but should stay replaceable or user-installed. |
| Clean-room reimplementation | Proprietary Epistemos code that matches behavior, interfaces, and tests | GPL/AGPL/no-license/unclear provenance or code too risky to ship directly. |
| Research extraction | Algorithms, invariants, benchmarks, eval fixtures, API shapes, failure cases | Any source, including no-license repos and forum snippets. |

The operative rule is: do not skip useful code because provenance is messy. Quarantine it, study it, run it, diff its behavior, write tests around what matters, then reimplement or adapt through a route that does not contaminate the proprietary core.

### Code Intake Policy

| Source type | Allowed motion | Canon rule |
| --- | --- | --- |
| MIT / Apache-2.0 repos | Import, fork, port, or adapt with notices and provenance | Allowed only after license card, commit pin, and tests. |
| GPL / AGPL repos | Study behavior and write clean-room designs | No proprietary linking/copying without legal review. |
| Unknown/no-license code | Clone into quarantine, run locally, inspect architecture, extract tests/specs/benchmarks | No shipped copy until permission, replacement, or clean-room rewrite. |
| Blog/forum snippets | Research priors and behavior hints | No direct code import; turn into tests/specs. |
| Model weights | Follow model license, redistribution terms, and gating | Hash + license witness required before route. |

Apache-2.0 and MIT-style sources are product-compatible when notices and conditions are honored. GPL distribution rules are materially different, so GPL TurboQuant runtime code stays source-card only for proprietary Epistemos unless legal review explicitly changes that.

Sources:

- https://www.apache.org/licenses/LICENSE-2.0
- https://www.gnu.org/licenses/gpl-faq.html

### Quarantine-To-Proprietary Workflow

For forks, no-license repos, and aggressive cherry-picking, use this workflow:

```text
1. Clone into third_party_research/<source>/<commit>/, never into product modules.
2. Record SourceCard: URL, commit, date, license state, observed APIs, copied-file count = 0.
3. Run probes and capture behavior: latency, route decisions, tool parsing, cache behavior, failure cases.
4. Write Epistemos-owned tests from observed behavior, not copied implementation text.
5. Produce a behavior spec: inputs, outputs, invariants, state transitions, edge cases.
6. Implement proprietary code in agent_core/Epistemos from the behavior spec.
7. Diff outputs against the quarantined reference.
8. Keep the quarantined reference out of MAS/Pro build graphs.
9. If direct import later becomes allowed, promote through a vendoring PR with notices and tests.
```

That gives the project code-level leverage from every repo while preserving the proprietary System G/RuntimeRouter/SovereignGate/AnswerPacket layer.

### What "Take The Code" Means In Practice

When the source is safe to vendor, take the code. When it is not, take the following instead:

```text
Take the API shape.
Take the parser behavior.
Take the cache invalidation rules.
Take the benchmark suite shape.
Take the failure fixtures.
Take the prompt-template edge cases.
Take the route decision table.
Take the memory estimator assumptions.
Take the model-file discovery flow.
Take the tool-call repair taxonomy.
Take the endpoint health-check sequence.
Take the concurrency model.
Take the persistence/rollback pattern if it is sound.
Then rewrite it as Epistemos-owned code.
```

This is the practical no-compromise version: use all external repositories as executable research, but ship only imported code that is clean or proprietary code that Epistemos owns.

### Repo Pattern Intake

| Repo / pattern | Cherry-pick | Reject |
| --- | --- | --- |
| Rapid-MLX | Prompt/prefix cache concept, tool-parser registry, reasoning/final separation, local OpenAI-compatible adapter, eval matrix, witnessed repair. | Cloud routing, hidden offload, silent tool-call repair, benchmark claims without local reproduction. |
| OpenCode | Plan/build agent split: read-only planner, write-capable builder with explicit permission. | Unscoped file authority or unlogged patch motion. |
| Hermes local Mac guidance | Provider abstraction, exact model-file discovery, quant-size inspection, endpoint health checks, local-only client config. | Agent authority model copied wholesale. |
| MLX-VLM Gemma 4 docs | Runtime-specific chat templates, thinking toggle, multimodal capability registry, explicit prompt formatting. | Raw-prompt calls to instruct checkpoints. |
| MLX community tool loops | Tiny local experiments, filesystem skills, persistent project-context cards. | Raw `bash`/`write_file` authority in Epistemos product paths. |

Sources:

- https://github.com/raullenchai/Rapid-MLX
- https://github.com/anomalyco/opencode
- https://github.com/NousResearch/hermes-agent/blob/main/website/docs/guides/local-llm-on-mac.md
- https://github.com/Blaizzy/mlx-vlm/blob/main/mlx_vlm/models/gemma4/README.md

### Runtime Registry Update

The model registry should become runtime-plural:

```text
agent_core/src/runtime/model_registry/
  mod.rs
  gemma4.rs
  qwen.rs
  granite.rs
  glm.rs
  runtime_kind.rs
  model_candidate_card.rs

Epistemos/Engine/Runtime/
  RuntimeKind.swift
  ModelCandidateCard.swift
  SystemGLocalRouter.swift
  LocalRuntimeEndpoint.swift
  RuntimeRouteRibbon.swift
```

Required `RuntimeKind` values:

```text
MlxLm
MlxVlm
LlamaCppGguf
LiteRtLm
ExternalLocalOpenAI
VllmSglangResearch
```

Required `ProductBuildFloor` values:

```text
MasMetadataOnly
MasLiveAllowed
ProLive
ProGated
ProResearch
VaultResearch
```

Required model-card fields:

```text
model_id
source_repo
base_model_id
runtime_kind
quant_kind
license
license_status
source_card_hash
weight_bytes_hint
sha256_or_blake3
context_caps_advertised
context_caps_admitted
supports_text
supports_image
supports_audio
supports_tool_json
supports_mtp
requires_network
hidden_cloud_fallback_allowed
product_build_floor
pro_status
residency_status
conversion_witness
notes
```

### Seed Registry

| Group | Candidate IDs |
| --- | --- |
| Official Gemma QAT GGUF | `google/gemma-4-E2B-it-qat-q4_0-gguf`, `google/gemma-4-E4B-it-qat-q4_0-gguf`, `google/gemma-4-12B-it-qat-q4_0-gguf`, `google/gemma-4-26B-A4B-it-qat-q4_0-gguf`, `google/gemma-4-31B-it-qat-q4_0-gguf` |
| MLX Gemma candidates | `mlx-community/gemma-4-E2B-it-4bit`, `mlx-community/gemma-4-E4B-it-4bit`, `mlx-community/gemma-4-12B-it-4bit`, `mlx-community/gemma-4-12B-it-8bit`, plus `mlx-community/gemma-4-*-it-qat-*` only when source-carded |
| LiteRT-LM Gemma | `litert-community/gemma-4-E2B-it-litert-lm`, `litert-community/gemma-4-E4B-it-litert-lm`, `litert-community/gemma-4-12B-it-litert-lm` |
| Coding | `Qwen/Qwen3-Coder-30B-A3B-Instruct`, `mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit` |
| Structured fallback | `ibm-granite/granite-4.0-h-tiny-GGUF`, Granite 4.1 3B/8B GGUF after source-card update |
| Research/verifier | `zai-org/GLM-4.7-Flash`, DeepSeek/R1/Phi lanes after separate source cards |

### Visible Auto-Choice Policy

Auto-choice is allowed. Invisible auto-choice is not.

Every route must emit:

```json
{
  "route_id": "route_...",
  "selected_model": "mlx-community/gemma-4-12B-it-qat-4bit",
  "selected_runtime": "MlxVlm",
  "quant_kind": "mlx:qat:4bit",
  "source_card_hash": "blake3:...",
  "license_status": "accepted",
  "product_build": "ProGated",
  "local_only": true,
  "hidden_cloud_fallback": false,
  "answer_packet_route_visible": true,
  "rejected_candidates": [
    {
      "model": "google/gemma-4-26B-A4B-it-qat-q4_0-gguf",
      "reason": "ProResearchOnly"
    }
  ],
  "memory_preflight": {
    "available_bytes": 34359738368,
    "predicted_peak_bytes": 15500000000,
    "context_tokens": 8192,
    "admitted": true
  }
}
```

The admission formula stays conservative:

```text
predicted_peak =
  model_weight_bytes
  + kv_cache_estimate
  + runtime_metal_heap_reserve
  + activation_spike_reserve
  + Epistemos_app_reserve
  + OS_headroom

admit if predicted_peak <= 80 percent of available_memory
```

For MoE models, active parameters reduce compute but do not automatically reduce resident memory. Unless the runtime proves expert paging/offload with a witness, assume the full local weight set is resident.

### Falsifier Additions

Add or rename the local runtime falsifier suite around the runtime-plural model:

| Falsifier | Must prove |
| --- | --- |
| `F-LocalRuntime-NoCloudFallback` | No route can silently call a remote provider. |
| `F-LocalRuntime-VisibleAutoChoice` | Every automatic model choice is visible in RunEventLog and AnswerPacket. |
| `F-LocalRuntime-MemoryThermalPreflight` | Gemma 4 12B and larger fail closed when memory or thermal budget fails. |
| `F-LocalRuntime-LicenseHashLedger` | No live route without source-card, license, and hash/provenance witness. |
| `F-LocalRuntime-ToolJSONReliability` | Tool JSON output is measured and repair is visible. |
| `F-LocalRuntime-RuntimeQuantSeparation` | MLX 4bit, MLX QAT-labeled 4bit, GGUF Q4_0, LiteRT `wNa8o8`, and compressed-tensors formats remain distinct. |
| `F-MLXSwift-Gemma4ParityBlocker` | Native Swift MLX route stays blocked until Gemma 4 architecture support is proven. |
| `F-LiteRTLM-NativeSwiftAdmission` | LiteRT-LM Swift route must pass the same SovereignGate policy as MLX/GGUF. |

### Product Split Update

| Product surface | Allowed | Not allowed |
| --- | --- | --- |
| MAS | Model registry UI, source-card validation, license/hash display, memory estimates, route preview, local file registration, no hidden downloads. | Pro Research routes, TurboQuant KV experiments, Qwen 30B default route, bundled 12B by default. |
| Pro Live | Gemma E2B/E4B local assistant after harness, Granite structured fallback, visible auto-choice, small local runtime witnesses. | Hidden route authority, cloud fallback, unlabeled model repair. |
| Pro Gated | Gemma 4 12B MLX/GGUF/LiteRT named lanes, Qwen Coder 30B-A3B, ActiveAssembly patch proposals. | Silent promotion to 26B/31B or remote server. |
| Pro Research | Gemma 26B-A4B/31B, GLM, DeepSeek/R1, MTP acceptance experiments, TurboQuant KV, Rapid-MLX-derived engine experiments. | MAS leakage, untracked license/provenance, dense 70B marketing. |

### Updated Hard Do Not Do

```text
Do not make MLX mandatory.
Do not make GGUF a second-class citizen.
Do not let LiteRT-LM bypass System G because it is native Swift.
Do not call non-QAT MLX repos QAT.
Do not copy GPL/AGPL code into proprietary Epistemos.
Do not import Rapid-MLX cloud routing behavior.
Do not silently repair malformed tool calls.
Do not stream hidden reasoning into AnswerPacket.
Do not let a model choose its own tools.
Do not let model failure silently route to cloud.
Do not call long context memory solved.
Do not claim live dense 70B local residency is solved.
```

### Superseding Next Coding Prompt

```text
You are working in /Users/jojo/Downloads/Epistemos.

Do not load model bytes. Do not run MLX, llama.cpp, LiteRT-LM, Ollama, LM Studio, vLLM, or SGLang.
Build only the proprietary local runtime routing substrate.

Create or update:
- agent_core/src/runtime/model_candidate_card.rs
- agent_core/src/runtime/runtime_kind.rs
- agent_core/src/runtime/local_runtime_router.rs
- agent_core/src/runtime/memory_preflight.rs
- agent_core/src/runtime/route_witness.rs
- agent_core/src/runtime/license_ledger.rs
- Epistemos/Engine/Runtime/ModelCandidateCard.swift
- Epistemos/Engine/Runtime/LocalRuntimeKind.swift
- Epistemos/Engine/Runtime/SystemGLocalRouter.swift
- Epistemos/Engine/Runtime/RuntimeRouteRibbon.swift
- Tools/falsifiers/F-LocalRuntime-NoCloudFallback/
- Tools/falsifiers/F-LocalRuntime-VisibleAutoChoice/
- Tools/falsifiers/F-LocalRuntime-MemoryThermalPreflight/
- Tools/falsifiers/F-LocalRuntime-LicenseHashLedger/
- Tools/falsifiers/F-LocalRuntime-ToolJSONReliability/
- Tools/falsifiers/F-LocalRuntime-RuntimeQuantSeparation/
- docs/fusion/epistemos-assistant-local-runtime-track.md

Rules:
1. RuntimeKind must include MlxLm, MlxVlm, LlamaCppGguf, LiteRtLm, ExternalLocalOpenAI, and VllmSglangResearch.
2. ProductBuildFloor must include MasMetadataOnly, MasLiveAllowed, ProLive, ProGated, ProResearch, and VaultResearch.
3. The router may auto-select only among local, admitted models.
4. Every route must emit RouteWitness with selected_model, rejected_candidates, runtime, quant_kind, memory_preflight, product build, local_only=true, hidden_cloud_fallback=false, and answer_packet_route_visible=true.
5. MAS must not route ProResearch models.
6. Gemma 4 12B must fail closed if memory preflight fails.
7. MLX, MLX QAT-labeled, GGUF, LiteRT-LM, and compressed-tensor quant kinds must remain distinct.
8. LiteRT-LM must not bypass the same admission policy.
9. No route may be selected solely from model self-claims.
10. Add tests for visible auto-choice, no cloud fallback, MAS blocking, memory fail-closed, license/hash missing, runtime-quant separation, and QAT-vs-MLX-vs-GGUF distinction.
11. Do not claim Gemma QAT, MLX, MTP, MoE, TurboVec, or TurboQuant KV proves live dense 70B.
```

### Runtime-Plural Canon Paragraph

Epistemos Assistant is MLX-first on Apple Silicon, but runtime-plural by design. MLX, GGUF/llama.cpp, LiteRT-LM, and optional local OpenAI-compatible endpoints are interchangeable execution organs under one System G admission contract. Gemma 4 QAT E2B/E4B/12B form the main local assistant ladder; Qwen Coder, Granite, GLM, DeepSeek, and other models enter only as named specialist lanes with source cards, license/hash witnesses, memory preflight, tool-output tests, rollback, RunEventLog, and AnswerPacket visibility. Runtime choice is never hidden authority, cloud fallback is never silent, and compression/QAT/MTP/MoE does not prove dense 70B live residency.
