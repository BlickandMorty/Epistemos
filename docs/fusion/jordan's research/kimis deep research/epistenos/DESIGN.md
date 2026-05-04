# Epistenos Cross-Crate API Contracts

## Design Philosophy

**One binary. One substrate. Three envelopes. Zero forks.**

The architecture separates:
- **Intent** (what the LLM wants to do) → typed, schema-validated
- **Effect** (what Rust actually does) → deterministic, transactional, reversible
- **State** (what Swift observes) → `@Observable`, read-only from Swift's perspective

## Crate Dependency Graph

```
helios-core (no deps)
    ↑
helios-metal (depends on: helios-core)
    ↑
helios-mlx (depends on: helios-core, helios-metal)
    ↑
helios-models (depends on: helios-core, helios-mlx)
    ↑
helios-runtime (depends on: helios-core, helios-mlx, helios-models)
    ↑
helios-ffi (depends on: helios-runtime, uniffi)
    ↑
Swift layer (depends on: helios-ffi)
```

helios-bench depends on all crates.

## Core Type Contracts (helios-core)

### Lattice Types
```rust
pub struct E8Codebook { /* 240 vectors, G=0.0717 */ }
pub struct LeechCodebook { /* 196560 vectors, G=0.0658 */ }
pub fn babai_nearest_plane(target: &[f32], basis: &LatticeBasis) -> Vec<i32>;
pub fn gptq_as_babai(hessian: &Hessian, weights: &[f32]) -> QuantizedWeights;
```

### Sketch Types
```rust
pub struct CountSketch<const W: usize, const D: usize> { /* D rows of W buckets */ }
pub struct FreeRandomProjection { /* Hayase-Collins-Inoue basis */ }
pub fn sketch_vector(cs: &mut CountSketch, vector: &[f32], seed: u64);
pub fn sketch_query(cs: &CountSketch, vector: &[f32]) -> Vec<f32>;
pub fn merge_sketches(a: &CountSketch, b: &CountSketch) -> CountSketch;
```

### PRCDA (Sherry) Types
```rust
pub struct SherryBlock { /* 1.25-bit packed weights + 6-bit scale */ }
pub fn sherry_pack(weights: &[f32], block_size: usize) -> Vec<SherryBlock>;
pub fn sherry_unpack(blocks: &[SherryBlock], out: &mut [f32]);
pub fn sherry_nf4_fallback(weights: &[f32]) -> Vec<u8>; // if Sherry fails on activations
```

### Inequality Types (WBO-6)
```rust
pub struct Wbo6Terms {
    pub t_w: f32, // Wyner-Ziv weight quantization
    pub t_k: f32, // KV cache approximation (now: residual reconstruction error)
    pub t_r: f32, // Residual stream coding
    pub t_q: f32, // Quantization / rounding
    pub t_s: f32, // Sketch / sampling error
    pub t_se: f32, // Self-evolving online adaptation
}
pub fn measure_wbo6(terms: &Wbo6Terms) -> f32;
pub const WBO6_COEFFICIENT: f32 = 0.5;
```

### Type-State Tier Machine
```rust
pub struct TokenState<Tier> { pub tier: PhantomData<Tier> }
pub struct L0; pub struct L1; pub struct L2; pub struct L3; pub struct L4; pub struct L_SE;
pub fn promote_l0_to_l1(state: TokenState<L0>) -> TokenState<L1>;
pub fn demote_l1_to_l2(state: TokenState<L1>) -> TokenState<L2>;
// Tier transitions are compile-time verified
```

## Metal Kernel Contracts (helios-metal)

All kernels compiled from MSL source at runtime via `MTLDevice.makeLibrary(source:options:)`.

Kernel naming convention: `<domain>_<operation>_<variant>.metal`
- `eml_softmax_lse.metal` — fused softmax using eml operator
- `sherry_pack.metal` — parallel weight packing
- `ternary_gemv.metal` — matrix-vector with packed trits
- `ternary_proj_residual.metal` — fused projection + residual add
- `count_sketch_update.metal` — streaming sketch update
- `kv_fingerprint.metal` — ternary fingerprint for KV
- `surprise_grad_step.metal` — Titans-MAC gradient step
- `dora_apply.metal` — DoRA adapter apply

Rust dispatch contract:
```rust
pub struct MetalKernel {
    pub name: &'static str,
    pub pipeline_state: MTLComputePipelineState,
    pub threadgroup_size: MTLSize,
}
pub fn dispatch_kernel(k: &MetalKernel, buffers: &[&MTLBuffer], threadgroups: MTLSize);
```

## MLX Memory Contracts (helios-mlx)

### 6-Tier Memory Allocator
```rust
pub enum MemoryTier {
    L0ExactHot,           // Full precision, resident
    L1CompressedResidual, // Sherry 1.25-bit or NF4 fallback
    L2ShadowSketch,       // CountSketch + sparse JL
    L3SSDOracle,          // memmap NF4 checkpoints
    L4HermesCascade,      // Cloud escalation buffer
    LSESelfEvolving,      // Titans-MAC online + SEAL DoRA
}
pub struct TieredAllocator {
    pub l0_capacity: usize,
    pub l1_capacity: usize,
    pub l2_capacity: usize,
    pub l3_path: PathBuf,
    pub l4_buffer: HermesBuffer,
    pub lse_module: T TitansMAC,
}
```

### KV-Direct Contract
```rust
pub struct KVDirect {
    pub residual_checkpoints: Vec<Tensor>, // sparse checkpoints
}
pub fn kv_direct_reconstruct(kv: &KVDirect, layer: LayerId, token: TokenId) -> (K, V);
// Returns exact K,V by projecting from residual stream
// 5KB per token vs 136KB standard
```

## Runtime Contracts (helios-runtime)

### Resonance Gate (8-field signature)
```rust
pub struct ResonanceSignature {
    pub tau: TernaryState,        // -1, 0, +1
    pub delta: Direction,         // promote / demote / hold
    pub pi: Primality,            // prime (fundamental) vs composite (derived)
    pub rho: f32,                 // resonance strength [0,1]
    pub kappa: f32,               // KAM stability [0,1]
    pub eta: f32,                 // evidence mass [0,1]
    pub lambda: Residency,        // L0-L4, L_SE
    pub learning_mode: LearningMode, // SGD / Hebbian / EWC / Fast / Meta
}
```

### SCOPE-Rex Omega (8-state vector)
```rust
pub struct ScopeRexState {
    pub h_t: ModelState,      // hidden state vector
    pub z_t: SparseFeatures,  // activated sparse features
    pub g_t: ClaimGraph,      // epistemic claim graph
    pub p_t: ProofTree,       // proof obligations
    pub m_t: MemoryRoot,      // Merkle root of memory
    pub w_t: ToolLedger,      // tool invocation ledger
    pub l_t: LossLedger,      // loss / drift ledger
    pub u_t: AuthState,       // biometric auth state
}
pub struct SemanticDelta { /* event-sourced state diff */ }
pub struct WitnessedState { /* materialized checkpoint */ }
```

### Tool Ladder
```rust
pub struct VariantLadder<T: Tool> {
    pub variants: Vec<Box<dyn Variant<T>>>,
    pub budget: RetryBudget,
    pub breaker: CircuitBreaker,
}
pub enum RouteVariant { Centroid, LLMClassify, ConceptSearch, Defer }
```

## Model Contracts (helios-models)

### Transformer Track
```rust
pub struct Qwen3Helios {
    pub base: Qwen3Config,
    pub memory: TieredAllocator,
    pub kv_direct: KVDirect,
    pub resonance_gate: ResonanceGate,
}
```

### SSM Track
```rust
pub struct Mamba2Helios {
    pub base: Mamba2Config,
    pub memory: TieredAllocator,
    pub ssm_state: SSMState, // test-time regression shared
}
```

## FFI Contracts (helios-ffi)

UniFFI UDL exposes:
- `TernaryRunConfig` (backend, max_tokens, freeform, live_draft)
- `TernaryMetrics` (prompt_ms, decode_tok_s, peak_bytes, deterministic)
- `run_ternary_prompt(prompt, config) -> Result<TernaryMetrics, String>`
- `VaultSnapshot` (path, notes, memory_tiers)
- `AgentStatus` (name, state, resonance_signature)

## Build Invariants

1. **No std::process::Command in MAS builds** — use XPC services instead
2. **All memory writes biometrically gated** — Touch ID / Face ID
3. **All tool outputs schema-validated** — JSON Schema before return
4. **All state changes event-sourced** — SemanticDelta logged
5. **Base weights immutable** — online learning only in L_SE module
6. **Deterministic by default** — seeded RNG, reproducible kernels
7. **Defer preferred over wrong** — confidence thresholds enforced
