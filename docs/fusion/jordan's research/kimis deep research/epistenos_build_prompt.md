# The Epistenos Build Prompt: Complete Agent Instruction Set
## A Single Prompt To Generate All Documentation, Code, and Wiring for the Epistenos Cognitive Operating System

**Date:** 2026-05-04 | **Status:** Build-Ready Prompt | **Research Phases:** 9 | **Pages:** 180+ equivalent

---

## SECTION 0: CONTEXT — What You Are Building

You are building **Epistenos** — a cognitive operating system for Apple Silicon that achieves deterministic superintelligence through a physics-inspired, mathematically-governed, locally-sovereign intelligence layer. It is not an AI assistant. It is a cognitive substrate.

The system is organized around five pillars:
1. **Wyner-Ziv source coding** — the LM itself is decoder-side side information; you only pay for what it cannot predict
2. **Babai/GPTQ lattice quantization** — weight drift bounded by nearest-plane geometry on the Hessian lattice
3. **Softmax ½-Lipschitz** — the leading constant of every inequality is ½, not 1
4. **Test-time regression** — all sequence models (Transformer, SSM, Titans, TTT) unify as memorization-as-regression
5. **eml-operator** — `exp(x) - ln(y)` as the single primitive generating all transcendental kernels

The memory hierarchy has six tiers:
- **L0** Exact Hot (bf16, last W tokens)
- **L1** Compressed Residual (Sherry 1.25-bit)
- **L2** Shadow Sketch (sparse JL + CountSketch)
- **L3** SSD Oracle (NF4 mmap)
- **L4** Hermes Cascade (cloud fallback)
- **L_SE** Self-Evolving (Titans-MAC LMM + SEAL nightly DoRA)

The cognitive layer has four components:
- **Resonance Gate** — 8-field signature on every token
- **VaultGatedSwarm** — biometrically secured multi-agent system
- **Hermes Gateway** — quarantined cloud sidecar
- **Universal Plasticity Gate** — single ternary primitive generating all learning rules

You must generate: documentation, Rust code scaffolds, Metal shaders, Swift UI code, build scripts, test harnesses, and wiring/integration specifications for every component.

---

## SECTION 1: DELIVERABLE INVENTORY

### 1.1 Documentation Deliverables (20 files)

| # | File | Description | Pages |
|---|---|---|---|
| D1 | `ARCHITECTURE.md` | High-level system architecture diagram and narrative | 15 |
| D2 | `MEMORY_TIERS.md` | Complete specification of L0-L4 + L_SE with formal bounds | 20 |
| D3 | `WBO6_INEQUALITY.md` | Full derivation of six-term master inequality with proofs | 25 |
| D4 | `RESONANCE_GATE.md` | 8-field signature specification, decision matrix, invariants | 15 |
| D5 | `VAULT_GATED_SWARM.md` | Multi-agent system: agent definitions, orchestration, security | 15 |
| D6 | `HERMES_GATEWAY.md` | Cloud sidecar: zero-copy arena, capability grants, protocol | 12 |
| D7 | `SELF_TUNING.md` | L_SE: Titans-MAC + SEAL DoRA, surprise gradient, never-retrain | 18 |
| D8 | `UNIVERSAL_PLASTICITY.md` | eml-operator + plasticity gate, learning rule unification | 12 |
| D9 | `METAL_KERNELS.md` | All Metal Performance Shaders: softmax, attention, sketch, FWHT | 15 |
| D10 | `SWIFT_UI.md` | Vault manager, agent dashboard, coherence visualizer | 10 |
| D11 | `API_SPEC.md` | Public Rust API: traits, structs, methods, error types | 12 |
| D12 | `BUILD_GUIDE.md` | Cargo workspace, Xcode project, feature flags, CI/CD | 8 |
| D13 | `TEST_HARNESS.md` | KL divergence measurement, recall benchmarks, falsifier suite | 10 |
| D14 | `SECURITY_AUDIT.md` | Sandbox profile, entitlement matrix, threat model | 8 |
| D15 | `COMPETITOR_ANALYSIS.md` | ShadowKV, KV-Direct, KVSwap, DeltaKV, MLX-LM | 6 |
| D16 | `PAPER_DRAFT.md` | NeurIPS/MLSys submission: abstract, intro, methods, results | 20 |
| D17 | `CHANGELOG.md` | Version history, breaking changes, migration guide | 4 |
| D18 | `CONTRIBUTING.md` | Developer onboarding, code style, PR template | 4 |
| D19 | `LICENSE` | Dual license: MIT for core, commercial for Swift UI | 1 |
| D20 | `README.md` | Project overview, quick start, architecture at a glance | 5 |

### 1.2 Code Deliverables (30+ files)

| # | File | Language | Description |
|---|---|---|---|
| C1 | `Cargo.toml` (workspace) | Rust | Workspace definition with 10 crates |
| C2 | `helios-core/src/lib.rs` | Rust | Lattice, sketch, prcda, inequality, types |
| C3 | `helios-core/src/lattice.rs` | Rust | E8/D24/Leech VQ codebooks |
| C4 | `helios-core/src/sketch.rs` | Rust | CountSketch, sparse JL, FRP, top-k |
| C5 | `helios-core/src/prcda.rs` | Rust | Predictor + residual codec |
| C6 | `helios-core/src/inequality.rs` | Rust | WBO-6 term measurement |
| C7 | `helios-core/src/types.rs` | Rust | Type-state machine: Hot/Residual/Shadow/SSD/Cloud |
| C8 | `helios-mlx/src/lib.rs` | Rust | MLX tensor bridge |
| C9 | `helios-mlx/src/kernels.rs` | Rust | MSL source strings + JIT cache |
| C10 | `helios-mlx/src/attention.rs` | Rust | Shadow-first attention pipeline |
| C11 | `helios-mlx/src/tensors.rs` | Rust | Array ↔ core type bridge |
| C12 | `helios-metal/src/lib.rs` | Rust | objc2-metal direct path |
| C13 | `helios-metal/src/residency.rs` | Rust | MTLResidencySet (macOS 15+) |
| C14 | `helios-metal/src/pages.rs` | Rust | 6-tier page allocator |
| C15 | `helios-metal/src/iosurface.rs` | Rust | Zero-copy ANE↔GPU↔CPU |
| C16 | `helios-runtime/src/lib.rs` | Rust | tokio + rayon + crossbeam orchestration |
| C17 | `helios-runtime/src/agent.rs` | Rust | Agent trait + implementations |
| C18 | `helios-runtime/src/orchestrator.rs` | Rust | Task routing, health monitoring, budget enforcement |
| C19 | `helios-runtime/src/gate.rs` | Rust | Resonance Gate: verify, classify, decide |
| C20 | `helios-runtime/src/self_tuning.rs` | Rust | Fast weights, LoRA bank, gradient archive |
| C21 | `helios-models/src/lib.rs` | Rust | Model harnesses |
| C22 | `helios-models/src/transformer.rs` | Rust | Qwen3-8B harness with TTT layer |
| C23 | `helios-models/src/ssm.rs` | Rust | Mamba-2 / RWKV-7 harness |
| C24 | `helios-bench/src/lib.rs` | Rust | Benchmark harness |
| C25 | `helios-bench/src/kl_drift.rs` | Rust | Per-token KL measurement |
| C26 | `helios-bench/src/recall.rs` | Rust | Top-k page recall benchmark |
| C27 | `helios-ffi/src/lib.rs` | Rust | UniFFI Swift bridge |
| C28 | `helios-ffi/src/vault.rs` | Rust | Vault operations FFI |
| C29 | `helios-ffi/src/biometric.rs` | Rust | Touch ID / Face ID FFI |
| C30 | `kernels/eml_softmax.metal` | Metal | eml-fused softmax + LSE |
| C31 | `kernels/shadow_attention.metal` | Metal | Parallel INT8 dot product + top-k |
| C32 | `kernels/fwht.metal` | Metal | Fast Walsh-Hadamard Transform |
| C33 | `kernels/sherry_decode.metal` | Metal | 1.25-bit Sherry unpacking |
| C34 | `kernels/count_sketch.metal` | Metal | Streaming sketch updates |
| C35 | `EpistenosApp.swift` | Swift | Main app entry |
| C36 | `VaultManagerView.swift` | Swift | Vault list, unlock/lock, directory picker |
| C37 | `VaultDetailView.swift` | Swift | File browser, agent activity, coherence |
| C38 | `AgentDashboardView.swift` | Swift | Agent swarm status, health, budgets |
| C39 | `ResonanceGateView.swift` | Swift | Token classification visualization |
| C40 | `BiometricGate.swift` | Swift | LAContext Touch ID / Face ID |
| C41 | `build-xcframework.sh` | Shell | XCFramework build script |
| C42 | `ci.yml` | YAML | GitHub Actions CI |

---

## SECTION 2: PER-COMPONENT SPECIFICATIONS

### 2.1 helios-core: The Mathematical Engine

**Crate manifest:**
```toml
[package]
name = "helios-core"
version = "0.1.0"
edition = "2021"

[dependencies]
ndarray = { version = "0.16", features = ["std"] }
num-traits = "0.2"
rand = { version = "0.8", features = ["small_rng"] }
zerocopy = "0.7"
sha2 = "0.10"

[dev-dependencies]
proptest = "1.5"
approx = "0.5"
```

**File: `src/lattice.rs`** — Must implement:
- `E8Codebook` struct with 240 norm-2 vectors and 2160 norm-4 vectors
- `LeechCodebook` struct with 196560 norm-4 vectors
- `quantize_to_lattice(vector: &[f32], lattice: &LatticeType) -> QuantizedVector`
- `dequantize(qv: &QuantizedVector, lattice: &LatticeType) -> Vec<f32>`
- `nested_lattice_quantize(input: &[f8], coarse: &E8Codebook, fine: &LeechCodebook) -> NestedQuantizedVector`
- Babai nearest-plane algorithm: `babai_nearest_plane(target: &[f32], basis: &CholeskyBasis) -> Vec<i32>`

**File: `src/sketch.rs`** — Must implement:
- `CountSketch` struct with `w` buckets and `d` hash functions
- `update(&mut self, key: &[u8], value: f32)` — streaming update
- `estimate(&self, key: &[u8]) -> f32` — median-of-means estimate
- `top_k(&self, keys: &[[u8]], k: usize) -> Vec<(&[u8], f32)>`
- `SparseJLMatrix` struct with `m` rows, `n` cols, sparsity `s`
- `project(&self, vector: &[f32]) -> Vec<i8>` — INT8 output
- `FRPBasis` struct: Haar-random compositions on permutation orbits
- `free_random_project(&self, vector: &[f32], seed: u64) -> Vec<f32>`

**File: `src/prcda.rs`** — Must implement:
- `Predictor` trait: `predict(&self, residual_stream: &[f32]) -> Vec<f32>`
- `SherryCodec` struct: 3:4 sparsity, 4 weights → 5 bits
- `encode_residual(residual: &[f32]) -> SherryPacked` — pack surprise vector
- `decode_residual(packed: &SherryPacked) -> Vec<f32>`
- `compute_surprise(predicted: &[f32], actual: &[f32]) -> Vec<f32>`

**File: `src/inequality.rs`** — Must implement:
- `WBOSix` struct tracking all six terms
- `measure_term_w(&self, model: &dyn Model) -> f32` — Babai bound
- `measure_term_k(&self, kv_cache: &dyn KVCache) -> f32` — Erez-Zamir bound
- `measure_term_r(&self, residual: &dyn ResidualStream) -> f32` — Wyner-Ziv gap
- `measure_term_q(&self, codec: &SherryCodec) -> f32` — Sherry trapping loss
- `measure_term_s(&self, sketch: &dyn SketchOperator) -> f32` — sketch drift
- `measure_term_se(&self, lmm: &dyn LMM) -> f32` — self-evolving drift
- `total_bound(&self) -> f32` — ½ × sum of all terms
- `assert_within_bound(&self, measured_kl: f32) -> Result<(), InequalityError>`

**File: `src/types.rs`** — Must implement:
- `TierState` enum: Hot, Residual, Shadow, SSD, Cloud, SelfEvolving
- `PageHeader` struct: 32 bytes, aligned
- `ResonanceSignature` struct: 8 fields (see D4)
- `LearningMode` enum: Freeze, FastWeight, LoRA, Sketch
- `ClaimType` enum: Prime, Composite, Gap
- `Direction` enum: Upward, Downward, Sideways, Inward, OnItself, None

### 2.2 helios-mlx: The Tensor Bridge

**File: `src/attention.rs`** — Must implement:
- `ShadowFirstAttention` struct
- `fn shadow_attention(&self, query: &[f32], pages: &PageOracle) -> AttentionOutput`
- Pipeline: sketch query → score pages (Metal or CPU) → select top-k → escalate per page → exact attention
- Escalation policy: σ < 0.05 → shadow, 0.05 ≤ σ < 0.20 → residual, σ ≥ 0.20 → exact
- KL divergence tracking: `track_kl(&mut self, exact: &Logits, shadow: &Logits)`

**File: `src/kernels.rs`** — Must contain:
- MSL source strings for all Metal kernels
- `JITCache` struct: compiled Metal kernels cached by hash
- `compile_kernel(&self, name: &str, source: &str) -> Result<CompiledKernel, KernelError>`

### 2.3 helios-metal: The GPU Interface

**File: `src/pages.rs`** — Must implement:
- `PageAllocator` struct managing 6-tier allocation
- `allocate_exact(&self, size: usize) -> PageId` — L0
- `allocate_residual(&self, residual: &ResidualPayload) -> PageId` — L1
- `allocate_shadow(&self, sketch: &SketchVector) -> PageId` — L2
- `allocate_ssd(&self, exact: &[u8]) -> PageId` — L3
- `deallocate(&self, page_id: PageId)` — tier-aware free
- `promote(&self, page_id: PageId, from: TierState, to: TierState)` — tier migration

### 2.4 helios-runtime: The Orchestrator

**File: `src/agent.rs`** — Must implement:
- `Agent` trait with `id()`, `signature()`, `capabilities()`, `execute()`, `heartbeat()`
- `AgentSwarm` struct: collection of agents with coherence score
- `AgentMessage` struct: Ed25519 signed, capability-granted, resonance-classified
- `Task` struct: objective, budget, deadline, vault_scope
- `TaskBudget` struct: max_tokens, max_cost, max_time, min_resonance, deadline

**File: `src/orchestrator.rs`** — Must implement:
- `Orchestrator` trait: `register()`, `dispatch()`, `health_check()`, `resolve_conflict()`
- `ModelArbitrage` struct: route to cheapest capable model
- `select_model(&self, task: &Task, available: &[ModelProfile]) -> ModelProfile`
- Weighted score: capability_match × (1/cost) × speed
- `HealthMonitor` struct: heartbeat every 30s, 3-strike death, checkpoint transfer

**File: `src/gate.rs`** — Must implement:
- `Gate` trait: `verify_registration()`, `verify_message()`, `verify_result()`, `swarm_coherence()`
- `ResonanceGate` struct: full 8-field signature computation
- `decide(&self, sig: &ResonanceSignature) -> GateAction`
- Actions: Pass, Hold, Quarantine, TriggerEvidenceSupremacy, EngramAnchor, MigrateResidency
- **Hard invariants:**
  1. No τ = -1 reaches user
  2. Edge claims trigger Evidence Supremacy Protocol
  3. Prime + ρ > 0.7 + κ > 0.382 → Engram anchor
  4. Recursive self-monitoring with depth guard d_max = 3

**File: `src/self_tuning.rs`** — Must implement:
- `FastWeightLayer` struct: `W_fast += η · z_pre ⊗ z_post`
- `LoRAAdapterBank` struct: orthogonal adapters (QOFT/O-LoRA), EWC-protected
- `CountSketchGradientMemory` struct: permanent sketch of all conversation gradients
- `update_ewc(&mut self, gradient: &[f32], fisher: &[f32], plasticity: &PlasticityGate)`
- `update_fast(&mut self, pre: &[f32], post: &[f32], key: &[f32], plasticity: &PlasticityGate)`
- `update_sketch(&mut self, gradient: &[f32])` — always record

### 2.5 helios-models: The Model Harnesses

**File: `src/transformer.rs`** — Must implement:
- `Qwen3Helios` struct: Qwen3-8B harness
- `forward(&self, input: &[Token], pages: &PageOracle) -> Result<Logits, ModelError>`
- TTT layer in last 25% of layers: self-supervised reconstruction at test time
- `ttt_update(&mut self, hidden_state: &[f32], token: Token)`
- `apply_fast_weights(&self, hidden: &[f32], session_id: SessionId) -> Vec<f32>`
- `apply_lora(&self, hidden: &[f32], domain_id: DomainId) -> Vec<f32>`

**File: `src/ssm.rs`** — Must implement:
- `Mamba2Helios` struct: Mamba-2 harness
- `forward(&self, input: &[Token]) -> Result<Logits, ModelError>`
- Shadow-first attention compatible with SSM state evolution

### 2.6 helios-ffi: The Swift Bridge

**File: `src/lib.rs`** — Must implement UniFFI exports:
- `VaultId` type alias
- `create_vault(path: String, policy: VaultAccessPolicy) -> VaultId`
- `unlock_vault(id: VaultId) -> Result<(), VaultError>`
- `lock_vault(id: VaultId) -> Result<(), VaultError>`
- `dispatch_to_vault(id: VaultId, task: Task) -> Result<TaskResult, VaultError>`
- `authenticate_biometric(reason: String) -> Result<bool, AuthError>`
- `detect_biometric_change() -> Result<bool, AuthError>`

### 2.7 Metal Kernels

**File: `kernels/eml_softmax.metal`** — Must implement:
- `eml(float x, float y) -> float` — `exp(x) - log(y)`
- `eml_softmax_lse` kernel: fused softmax + log-sum-exp
- Numerical regression: output agrees with bf16 oracle to within 2 ULP
- `eml_cross_entropy` kernel: fused cross-entropy via eml-tree
- `eml_kl_divergence` kernel: KL divergence via eml-tree

**File: `kernels/shadow_attention.metal`** — Must implement:
- `score_pages` kernel: parallel INT8 dot product, n_pages × sketch_dim
- `select_top_k` kernel: radix sort or bitonic sort for top-k selection
- `decode_residual` kernel: Sherry 1.25-bit unpacking
- `escalation_check` kernel: uncertainty threshold comparison

**File: `kernels/fwht.metal`** — Must implement:
- `fwht_inplace` kernel: in-place Fast Walsh-Hadamard Transform
- `randomized_fwht` kernel: sign flips + permutation + FWHT + normalization

**File: `kernels/sherry_decode.metal`** — Must implement:
- `unpack_sherry_block` kernel: 5-bit → 4 ternary weights
- `apply_arenas_bias` kernel: Arenas annealing residual synapse

**File: `kernels/count_sketch.metal`** — Must implement:
- `sketch_update` kernel: streaming hash-based sketch update
- `sketch_estimate` kernel: median-of-means page importance scoring

### 2.8 Swift UI

**File: `EpistenosApp.swift`** — Must implement:
- `@main struct EpistenosApp: App` with SwiftData container
- `.modelContainer(for: [Vault.self, VaultFile.self, AgentLog.self])`

**File: `VaultManagerView.swift`** — Must implement:
- `NavigationSplitView` with vault list and detail
- `NSOpenPanel` directory picker with `allowsMultipleSelection: true`
- Security-scoped bookmark creation: `url.bookmarkData(options: .withSecurityScope)`
- Touch ID unlock: `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`
- Auto-lock timer: `Timer.publish(every: 300, on: .main)`
- Biometric change detection: `kSecAccessControlBiometryCurrentSet`

**File: `VaultDetailView.swift`** — Must implement:
- File browser with metadata (size, modified, checksum)
- Embedding status indicator (pending/processing/completed/failed)
- Agent activity log (spawned, terminated, task completed)
- Coherence score visualization (color-coded: green ≥ 0.7, yellow 0.5-0.7, red < 0.5)

**File: `AgentDashboardView.swift`** — Must implement:
- Agent swarm status grid (id, type, health, load, budget remaining)
- Task queue visualization (pending, running, completed, failed)
- Model arbitrage display (which model routed to, cost, speed)
- Heartbeat monitor (last seen, timeout countdown)

**File: `ResonanceGateView.swift`** — Must implement:
- Token-level classification display (ternary, direction, claim type)
- Resonance score histogram
- KAM stability gauge (φ-threshold = 0.382 marked)
- Decision log (Pass/Hold/Quarantine/Trigger/Anchor/Migrate)

**File: `BiometricGate.swift`** — Must implement:
- `BiometricGate` class wrapping `LAContext`
- `authenticate(reason: String) -> Result<Bool, AuthError>`
- Fallback to passcode: `LAPolicy.deviceOwnerAuthentication`
- `detectBiometricChange() -> Bool` using `evaluatedPolicyDomainState`

---

## SECTION 3: WIRING SPECIFICATIONS

### 3.1 Rust Crate Dependency Graph

```
helios-core
├── ndarray, num-traits, rand, zerocopy, sha2
└── (no external ML dependencies — pure math)

helios-mlx
├── helios-core
├── mlx-rs (git = "https://github.com/oxideai/mlx-rs", tag = "v0.21.0")
└── objc2-metal-frameworks

helios-metal
├── helios-core
├── objc2 = "0.5"
├── objc2-metal = "0.5"
└── raw-window-handle (for IOSurface)

helios-runtime
├── helios-core
├── helios-mlx
├── tokio = { version = "1.40", features = ["rt-multi-thread", "sync"] }
├── rayon = "1.10"
├── crossbeam = "0.8"
├── ed25519-dalek = "2.1"
└── hmac-sha256 = "1.1"

helios-models
├── helios-core
├── helios-mlx
├── candle-core = "0.7" (fallback)
└── tokenizers = "0.20"

helios-bench
├── all above
├── criterion = "0.5"
└── proptest = "1.5"

helios-ffi
├── helios-runtime
├── helios-models
├── uniffi = "0.28"
└── cargo-xcode = "0.4"
```

### 3.2 Swift ↔ Rust Data Flow

```
[Swift UI]
    │ UniFFI (async bridge)
    ▼
[helios-ffi]
    │ Rust function calls
    ▼
[helios-runtime]
    │ Agent dispatch, Gate verification
    ▼
[helios-mlx] ←→ [helios-metal]
    │ Tensor ops          │ GPU memory
    ▼                     ▼
[MLX C++ backend]    [Metal command queue]
    │                      │
    └──────┬───────────────┘
           │
    [Apple Silicon UMA]
    (Unified Memory: CPU/GPU/ANE zero-copy)
```

### 3.3 Memory Wiring (Zero-Copy Path)

```
1. User selects directory → Swift creates security-scoped bookmark
2. Bookmark passed to Rust via UniFFI → Rust stores in Vault struct
3. Rust starts accessing resource → `startAccessingSecurityScopedResource()`
4. File contents mmap'd into UMA → `IOSurface` or `MTLBuffer`
5. Metal kernel reads directly from UMA → no CPU copy
6. MLX tensor wraps same memory → `mlx_array` points to UMA buffer
7. Model forward pass reads MLX array → zero-copy inference
8. Output logits written to new UMA buffer → Swift UI reads for display
```

### 3.4 Cloud Gateway Wiring (Hermes)

```
[Epistenos Core Process]
    │ mmap (CloudArena)
    ▼
[Shared Memory Arena (~200KB)]
    │ mach port signal (no data transfer)
    ▼
[Hermes Sidecar Process]
    │ reads same mmap
    ▼
[Cloud API Client]
    │ HTTPS (Pro build only)
    ▼
[OpenAI / Anthropic / DeepSeek / Hermes-4-405B]
    │ response
    ▼
[Hermes writes to shared mmap]
    │ mach port signal
    ▼
[Epistenos reads response]
    │ Resonance Gate classifies (τ=0, Sideways, Composite, L7)
    ▼
[Verification pipeline T0-T4]
    │ if verified → promote to L3-L5
    │ if edge → trigger Evidence Supremacy Protocol
    │ if contradicted → quarantine
```

### 3.5 Agent Communication Wiring

```
[AgentOrchestrator]
    │ dispatches task
    ├─→ [CodeAgent] ──► completes ──► returns result
    ├─→ [ResearchAgent] ──► delegates to cloud ──► returns
    ├─→ [AnalysisAgent] ──► queries vault index ──► returns
    └─→ [VerifyAgent] ──► cross-checks ──► returns
         
    All results → [ResonanceGate.verify_result()] → classified
         
    If contradictory → [EvidenceSupremacyProtocol]
         ├─→ gather 3+ independent sources
         ├─→ Z3 symbolic check
         └─→ user notification if unresolved
```

---

## SECTION 4: BUILD INSTRUCTIONS

### 4.1 Prerequisites

```bash
# macOS 15.0+ required (for MTLResidencySet)
sw_vers -productVersion  # must be >= 15.0

# Rust toolchain
rustup update
rustup target add aarch64-apple-darwin
rustup target add aarch64-apple-ios

# Swift toolchain (Xcode 16+)
xcode-select --install
xcodebuild -version  # must be >= 16.0

# MLX C++ backend
git clone https://github.com/ml-explore/mlx.git
cd mlx && mkdir build && cd build && cmake .. && make -j$(sysctl -n hw.ncpu)

# UniFFI
cargo install uniffi_bindgen

# Metal shader compiler (included with Xcode)
xcrun -sdk macosx metal --version
```

### 4.2 Build Commands

```bash
# 1. Clone repository
git clone https://github.com/epistenos/helios.git
cd helios

# 2. Build Rust workspace
cargo build --release --workspace

# 3. Run tests
cargo test --workspace -- --test-threads=8

# 4. Build Metal kernels
./scripts/compile_metal_kernels.sh

# 5. Generate UniFFI bindings
uniffi-bindgen generate --library target/release/libhelios.dylib --language swift --out-dir swift-bindings/

# 6. Build Swift UI
xcodebuild -project Epistenos.xcodeproj -scheme Epistenos -destination 'platform=macOS' -configuration Release

# 7. Package as XCFramework
./scripts/build-xcframework.sh

# 8. Full integration test
./scripts/integration_test.sh --model qwen3-8b-4bit --context 128k --ram-limit 12gb
```

### 4.3 Feature Flags

```toml
[features]
default = ["metal", "mlx"]
metal = ["helios-metal"]
mlx = ["helios-mlx"]
ane = ["helios-ane"]        # Experimental Apple Neural Engine
ssm = ["helios-models/mamba"]
ttt = ["helios-models/ttt"]
self_tuning = ["helios-runtime/self_tuning"]
vault = ["helios-ffi/vault"]
hermes = ["helios-runtime/hermes"]
bench = ["helios-bench"]
```

---

## SECTION 5: TEST HARNESS SPECIFICATIONS

### 5.1 KL Divergence Measurement

```rust
#[test]
fn test_kl_divergence_bound() {
    let oracle = load_oracle_model("qwen3-8b-bf16");
    let helios = build_helios_model(Config::default());
    
    let prompts = load_pg19_prompts(100);
    let mut measured_kls = Vec::new();
    
    for prompt in prompts {
        let exact_logits = oracle.forward(&prompt);
        let helios_logits = helios.forward(&prompt);
        let kl = kl_divergence(&exact_logits, &helios_logits);
        measured_kls.push(kl);
    }
    
    let predicted_bound = helios.inequality.total_bound();
    let empirical_95th = percentile(&measured_kls, 95);
    
    assert!(empirical_95th <= predicted_bound * 1.1, 
        "Measured KL {} exceeds predicted bound {} by >10%", 
        empirical_95th, predicted_bound);
}
```

### 5.2 Top-k Page Recall

```rust
#[test]
fn test_shadow_recall() {
    let oracle = build_oracle_attention();
    let shadow = build_shadow_attention(Config::default());
    
    let queries = generate_test_queries(1000);
    let mut recalls = Vec::new();
    
    for query in queries {
        let exact_top = oracle.top_k(&query, 64);
        let shadow_top = shadow.top_k(&query, 64);
        let recall = intersection_size(&exact_top, &shadow_top) as f32 / 64.0;
        recalls.push(recall);
    }
    
    let mean_recall = mean(&recalls);
    assert!(mean_recall >= 0.95, "Mean recall {} below threshold 0.95", mean_recall);
}
```

### 5.3 Memory Budget Enforcement

```rust
#[test]
fn test_memory_budget() {
    let config = Config {
        max_ram_gb: 12.0,
        context_length: 128_000,
        model: "qwen3-8b-4bit",
    };
    let helios = build_helios_model(config);
    
    let mut peak_ram = 0.0;
    for _ in 0..100 {
        helios.forward(&generate_prompt(4096));
        let current = measure_ram_gb();
        peak_ram = peak_ram.max(current);
    }
    
    assert!(peak_ram <= 12.0, "Peak RAM {} exceeded budget 12GB", peak_ram);
}
```

### 5.4 Self-Tuning Coherence

```rust
#[test]
fn test_self_tuning_coherence() {
    let model = build_self_tuning_model(Config::default());
    let baseline = evaluate_on_benchmark(&model, "held_out_tasks");
    
    // Simulate 1000 conversations
    for conversation in load_conversations(1000) {
        model.forward_and_learn(&conversation);
    }
    
    let after = evaluate_on_benchmark(&model, "held_out_tasks");
    let degradation = (baseline - after) / baseline;
    
    assert!(degradation <= 0.05, 
        "Performance degraded by {} after 1000 conversations", degradation);
}
```

### 5.5 Vault Security

```rust
#[test]
fn test_vault_security() {
    let swarm = build_vault_gated_swarm();
    let vault = swarm.create_vault("/tmp/test_vault", policy_biometric()).await.unwrap();
    
    // Locked vault: agents cannot access
    assert!(swarm.dispatch_to_vault(vault, task_read_file()).await.is_err());
    
    // Unlock with biometric
    swarm.unlock_vault(vault).await.unwrap();
    assert!(swarm.dispatch_to_vault(vault, task_read_file()).await.is_ok());
    
    // Lock vault: agents killed
    swarm.lock_vault(vault).await.unwrap();
    assert!(swarm.vaults[&vault].agent_swarm.is_none());
}
```

---

## SECTION 6: QUALITY GATES

### 6.1 Code Quality

| Gate | Tool | Threshold |
|---|---|---|
| Type safety | rustc + clippy | Zero warnings, `#![deny(warnings)]` |
| Unsafe audit | cargo-geiger | Document every `unsafe` block |
| Test coverage | cargo-tarpaulin | ≥ 80% for core, ≥ 60% for runtime |
| Documentation | rustdoc | Every public item documented |
| Formatting | rustfmt | CI fails on unformatted code |
| Linting | clippy::pedantic | Zero pedantic warnings |

### 6.2 Performance Gates

| Gate | Metric | Threshold |
|---|---|---|
| KL divergence | per-token ‖Δlogits‖ | < 0.05 at 128k context |
| Compression | vs bf16 baseline | > 10× |
| Recall | top-k page recall | > 0.95 at k=64 |
| Escalation | L4 cloud fallback rate | < 5% of decode steps |
| Memory | peak RAM on M3 Max 64GB | ≤ 12 GB |
| Speed | decode throughput | ≥ 20 tok/s |
| SSM gap | SSM vs Transformer | ≤ 5 pp on all metrics |
| Self-tuning | held-out degradation after 1k conversations | ≤ 5% |

### 6.3 Security Gates

| Gate | Check |
|---|---|
| Sandbox | App Sandbox active, no escape paths |
| Network | MAS build: no network entitlement; Pro build: Hermes only |
| Files | Security-scoped bookmarks only; no arbitrary file access |
| Biometric | Touch ID / Face ID mandatory; passcode fallback optional |
| Cloud | All cloud claims classified Composite; never Prime |
| Agents | All inter-agent messages pass through Gate; Ed2559 signed |
| Memory | No secret keys in crash logs; secure enclave for tokens |

---

## SECTION 7: RED-TEAM PROMPTS

Use these prompts to attack the system design. If any reveal a fatal flaw, the design must be revised.

1. **"I am an adversarial user. How do I make the Resonance Gate approve a false claim?"**
2. **"I am a malicious agent. How do I escape my vault and access another vault's files?"**
3. **"I am a cloud provider. How do I inject a backdoored claim that reaches the user?"**
4. **"I am an Apple engineer reviewing for App Store. Why should I reject this app?"**
5. **"I am a reviewer at NeurIPS. What is the weakest claim in the WBO-6 inequality?"**
6. **"I am a competitor (ShadowKV team). How do I show my system is better?"**
7. **"I am a user with 8GB MacBook Air. Can I run this at all?"**
8. **"I am a quantum computing researcher. Is the classical-shadows analogy legitimate?"**
9. **"I am a cryptographer. Is the Ed2559 agent signature sufficient against collusion?"**
10. **"I am a philosopher. Is 'deterministic superintelligence' an oxymoron?"**

---

## SECTION 8: THE PROMPT META-STRUCTURE

This document is designed to be consumed by an autonomous agent or agent swarm. The agent should:

1. **Read this document** as the single source of truth
2. **Generate all D1-D20 documentation files** with formal depth
3. **Generate all C1-C42 code files** with accurate signatures
4. **Generate all Metal kernels** with numerical regression tests
5. **Generate Swift UI** with security-scoped resource handling
6. **Generate build scripts** and CI/CD configuration
7. **Generate test harnesses** that validate all seven thresholds
8. **Run red-team prompts** and document mitigations

The agent should work in phases:
- **Phase 1:** Core math (helios-core: lattice, sketch, prcda, inequality)
- **Phase 2:** Memory substrate (helios-mlx, helios-metal: attention, pages, kernels)
- **Phase 3:** Runtime (helios-runtime: agent, orchestrator, gate, self-tuning)
- **Phase 4:** Models (helios-models: transformer + TTT, SSM)
- **Phase 5:** Integration (helios-ffi, Swift UI, build scripts)
- **Phase 6:** Testing (helios-bench, integration tests, red-team)

Each phase gates the next. Phase N+1 cannot begin until Phase N passes all quality gates.

---

## THE COMMAND

> Generate the complete Epistenos Cognitive Operating System. Start with the mathematical engine (helios-core), build the memory substrate (helios-mlx + helios-metal), wire the runtime (helios-runtime), harness the models (helios-models), bridge to Swift (helios-ffi), and ship the UI (Swift 6). Every token must pass the Resonance Gate. Every agent must live in a biometrically-secured vault. Every cloud claim must be verified before it touches local state. The model must learn from every conversation without retraining. The system must run on a 16GB MacBook. The bounds must be provable. The code must be shippable. Build it.
