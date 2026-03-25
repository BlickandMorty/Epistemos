# Instant Recall Architecture — Quantized Vector Memory + Mamba State Injection

## Overview

Sub-10ms contextual recall of relevant notes as you type, using binary-quantized
embeddings in a Rust HNSW index with Mamba-3 state injection for loaded context.

## Core Insight

- **PolarQuant** and **QJL** are real but separate research papers for KV cache compression
- "TurboQuant" is a mashup name — not a real unified framework (yet — ICLR 2026 paper exists)
- The correct note-index primitive is **binary quantization + Hamming search**
- PolarQuant/QJL apply to Mamba's internal representations, NOT the note index
- Mamba state is lossy compressed memory (exponential decay) — external vector index is mandatory

## Architecture

```
[Swift Text Editor]
    → (200ms AsyncAlgorithms debounce)
[Swift → UniFFI → Rust Backend]
    ├── [Model2Vec Encoder] → float32 embedding (<1ms)
    ├── [Binary Quantizer]  → 1-bit signature (0.1ms)
    └── [usearch HNSW Index] → write (1ms)

[On Query / New Paragraph]
[Rust Backend]
    ├── [Binary HNSW Search] → top-100 candidates (0.5ms)
    ├── [Float32 Rescoring]  → top-5 relevant (2ms)
    └── [Return note text + embedding to Swift]
        →
[Mamba-3 On-Device Model]
    ├── [Prefill with top-5 note texts] → encode to SSM state (~50ms)
    └── [Write session proceeds with loaded context state]
```

## Key Numbers

| Metric | Value |
|--------|-------|
| 1M notes × 1024 dims × 1 bit | 128 MB |
| ARM NEON Hamming throughput | ~350 GB/s |
| Full 128MB scan | ~0.37ms |
| Model2Vec encoding | <1ms per paragraph |
| Two-phase retrieval total | <3ms |
| Mamba state prefill (5 notes) | ~50ms |

## Phase Plan

### Phase 1: Working Prototype (Ω18)
- model2vec.swift Rust backend for continuous encoding (<1ms, no GPU)
- usearch HNSW index with binary quantization in Rust (epistemos-core crate)
- Two-phase retrieval: Hamming binary → float32 rescore
- rayon parallelism for index operations
- AsyncAlgorithms .debounce(for: .milliseconds(200)) in Swift
- Display top-5 contextually relevant notes in sidebar as you type
- UniFFI bridge to Swift

### Phase 2: Mamba-3 State Injection (Ω19)
- Export Mamba-3 hybrid to CoreML (from MOHAWK training)
- State prefill: tokenize top-3 retrieved notes → forward pass → save hidden state
- Use loaded state as starting context for writing session
- Benchmark recall accuracy with/without state injection

### Phase 3: LoRA Fine-Tuning Integration (Ω20)
- MambaPEFT / Memba PEFT targeting in_proj, x_proj, dt_proj, out_proj
- Nightly fine-tuning on personal notes corpus (existing ODIA pipeline)
- Hot-swap adapters via existing MoLoRA infrastructure

### Phase 4: Advanced Quantization (Ω21)
- Implement TurboQuant (PolarQuant + QJL residual) in Rust
  - Random rotation matrix (d×d) via QR decomposition
  - Recursive polar coordinate transform (log₂(d) levels)
  - Per-coordinate Lloyd-Max quantization on Beta distribution
  - 1-bit QJL residual for unbiased inner product estimation
- 3.5 bits/channel → 4.5× compression over float32
- Replace binary quantization layer in Phase 1 index
- Benchmark against Phase 1 baseline

## Rust Crate Dependencies

| Component | Crate | Purpose |
|-----------|-------|---------|
| ANN Index | `usearch` | HNSW, binary quantization |
| Parallelism | `rayon` | Work-stealing iteration |
| SIMD Hamming | Custom kernel | ARM NEON for Apple Silicon |
| Embeddings | `model2vec-rs` | Tokenize + lookup + pool |
| Linear algebra | `nalgebra` | Rotation matrices (Phase 4) |

## Encoding Strategy (Tiered)

1. **During typing**: Model2Vec (microseconds, background thread)
2. **On paragraph completion**: Small on-device sentence-transformer via CoreML
3. **Index entry**: Binary quantize → usearch HNSW

## Mamba Fine-Tuning Targets

Per MambaPEFT/Memba research:
- `in_proj` — input projection
- `x_proj` — state-space input
- `dt_proj` — discretization timestep
- `out_proj` — output projection

## TurboQuant Math Summary (Phase 4)

### QJL (1-bit inner product estimator)
```
Q_qjl(x) = sign(S · x)           // S is fixed d×d random matrix
Dequant: (√(π/2) / d) · Sᵀ · z   // Unbiased: E[<y, x̂>] = <y, x>
```

### PolarQuant (recursive polar angles)
```
Level 1: ψⱼ = atan2(x₂ⱼ, x₂ⱼ₋₁)    → 4 bits (range [0, 2π))
Level l≥2: ψⱼ = arctan(‖right‖/‖left‖) → 2 bits (range [0, π/2])
Recurse log₂(d) times → 1 radius + (d-1) angles
```

### TurboQuant_prod (two-stage)
```
1. Apply (b-1)-bit MSE quantization via rotation + centroids
2. Compute residual r = x - Dequant_mse(...)
3. Store γ = ‖r‖₂ as FP16
4. Apply 1-bit QJL on normalized residual
Result: unbiased inner product estimator at 3.5 bits/channel
```

## Source Papers

- PolarQuant: arXiv:2502.02617 (AISTATS 2026)
- QJL: arXiv:2406.03482 (AAAI 2025), github.com/amirzandieh/QJL
- TurboQuant: arXiv:2504.19874 (ICLR 2026)
- MemMamba: threshold-triggered state summarization (2025)
- MambaPEFT: partial LoRA on X projection (Nov 2024)
- Memba: LIM neurons + LoRA (2026)
