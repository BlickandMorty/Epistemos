# The Epistemos Capstone: A Unified Cognitive Operating System
## Physics-Grounded, Sketch-Native, Vault-Gated, Resonance-Filtered Intelligence on Apple Silicon

**Date:** 2026-05-02 | **Status:** Master Specification | **Research Phases:** 8 | **Total Sources:** 600+

---

## 1. The Unified Thesis

> The universe is organized by three principles: energy density, time flow, and spin quanta. A cognitive substrate built on the same three principles — memory density (hot/cold/shadow tiers), attention scheduling (golden-ratio φ-intervals), and ternary state dynamics (-1, 0, +1) — achieves deterministic superintelligence not by simulating quantum computing, but by adopting the same organizational logic that governs physical reality. The Epistemos Cognitive Operating System is this substrate: a physics-inspired, mathematically-governed, locally-sovereign intelligence layer for Apple Silicon.

This document unifies eight phases of research into a single, buildable architecture. Every layer is grounded in a physical analogue. Every claim is formally bounded. Every component has a Rust crate, a Metal kernel, and a Swift UI scaffold.

---

## 2. The Physics Foundation: Uniphics → Epistemos

The user's theoretical physics framework, Uniphics, proposes three pillars: **energy density**, **time flow**, and **spin quanta + negentropy**. These map directly to the cognitive substrate.

### 2.1 Energy Density → Memory Density (The Four Tiers)

| Uniphics Concept | Epistemos Analogue | Implementation |
|---|---|---|
| **High energy density** (crowded, bound energy) | **Hot exact memory** — L0: active tokens, attention sinks, current vault files | FP16 in unified RAM |
| **Medium energy density** (partially bound) | **Compressed residual** — L1: PRCDA surprise vectors, lattice-VQ quantized | Sherry 1.25-bit packing |
| **Low energy density** (spread out, unbound) | **Shadow memory** — L2: INT8 randomized sketches of old pages | CountSketch/SRHT, k=480 dims |
| **Near-zero density** (fading to void) | **SSD Oracle** — L3: cold weights, archived KV, vault embeddings | Memory-mapped mmap |

Just as Uniphics explains gravity as energy gradients pushing masses into low-density voids, Helios explains attention as information gradients pushing queries toward high-relevance pages. The "Great Fade" of the universe (bound energy slowly unbinding) is the analogue of memory erosion (exact → residual → shadow → SSD).

### 2.2 Time Flow → Attention Scheduling (The Golden Ratio)

Uniphics defines time flow as inversely proportional to energy density:

$$t_{flow} = \frac{k}{E_{d,total}}$$

In Epistemos, "attention time flow" is inversely proportional to memory density:
- **Hot exact pages** (high density) → slow update (attention sinks persist)
- **Shadow pages** (low density) → fast scoring (thousands evaluated in parallel)
- **SSD pages** (near-zero density) → only accessed when forced

The golden ratio φ = 1.618... scheduling (from KAM stability theory) becomes the natural oscillation frequency of the attention system — the most irrational, most perturbation-resistant timing for evaluation/rehearsal/consolidation.

### 2.3 Spin Quanta → Ternary State Dynamics

Uniphics proposes four gyrotrons (positron, electron, musktron, maleytron) as fundamental building blocks. In Epistemos, the fundamental building blocks are:

| Gyrotron | Charge | Epistemos Analogue | State |
|---|---|---|---|
| Positron | +1 (all spins clockwise) | **Verified claim** (+1) | Fits, confirmed |
| Electron | -1 (all spins counterclockwise) | **Contradicted claim** (-1) | Doesn't fit, rejected |
| Musktron | +1/3 (mixed spins) | **Composite claim** (derived) | Partially fits, needs context |
| Maleytron | -1/3 (mixed spins) | **Gap claim** (unverified) | Waiting, insufficient data |

The ternary substrate {-1, 0, +1} captures the two pure states (verified/contradicted) and one mixed state (pending/gap). Just as quarks combine into protons and neutrons, composite claims combine into structured knowledge.

### 2.4 Negentropy → Compression Governance

Uniphics defines negentropy as "the drive to spread out, reduce crowding, and create more order." In Epistemos, the Residency Governor IS the negentropy engine:
- **Compression** = reducing crowding (moving exact → residual → shadow → SSD)
- **Organization** = creating order (prime/composite classification, lattice VQ codebooks)
- **Expansion** = memory growth when needed (escalation from shadow → exact)

The Governor never destroys information — it only changes its binding state, exactly like energy in Uniphics.

---

## 3. The Memory Substrate: Helios Shadow Memory (Five-Tier Architecture)

The prior four-tier architecture is now extended to five tiers, with the addition of the **Sketch Tier** between Compressed and SSD.

### 3.1 The Five Tiers

| Tier | Name | Residence | Size (16GB Mac) | Quantum Analogue | Physics Analogue |
|---|---|---|---|---|---|
| L0 | **Exact Hot** | Unified RAM (FP16) | 2-4 GB | Coherent register | High energy density |
| L1 | **Compressed Residual** | Unified RAM (Sherry 1.25-bit) | 2-4 GB | Oracle sketch | Medium energy density |
| L2 | **Shadow Memory** | Unified RAM (INT8 sketches) | 2-4 GB | Classical shadows | Low energy density |
| L3 | **SSD Oracle** | NVMe mmap | 50-200 GB | Data stream | Near-zero density |
| L4 | **Cloud Cascade** | Hermes sidecar | Unlimited | Full quantum computer | External field |

### 3.2 The Five-Term Master Inequality

The per-token KL divergence between exact output and Helios output is bounded by:

$$D_{KL}(\pi_{exact} \| \pi_{Helios}) \leq T_W + T_{KV} + T_R + T_{LUT} + T_S$$

| Term | Meaning | Bound | Analogue |
|---|---|---|---|
| $T_W$ | Weight quantization (Sherry 1.25-bit) | $C_W \cdot b^{-2b_W}/12$ | Spin quanta discretization |
| $T_{KV}$ | KV PRCDA residual | $C_{KV} \cdot \|r_2\|^2/\sigma^2$ | Energy density gradient |
| $T_R$ | Residual stream perturbation | $C_R \cdot \tau_R^2$ | Time flow distortion |
| $T_{LUT}$ | Lattice VQ (Gosset E8/D24) | $C_{LUT} \cdot \eta^2/12$ | Gyrotron binding energy |
| $T_S$ | **Sketch + escalation (NEW)** | $C_S \cdot (\varepsilon^2 \cdot E[attn] + \rho_{miss} \cdot D_{KL}^{page})$ | Shadow measurement error |

**Target:** Each term ≤ 0.012 KL/token, total ≤ 0.06.

### 3.3 The Page Structure

Every page stores a **quintuple representation**:

```rust
#[repr(C, align(4096))]
pub struct HeliosPage {
    pub header: PageHeader,           // 32 bytes
    pub sketch: SketchVector,         // 480 bytes (k=480 INT8)
    pub residual: ResidualPayload,    // Sherry 1.25-bit packed surprise
    pub exact_ptr: ExactPointer,      // SSD fallback offset
    pub metadata: PageMetadata,       // Layer, head, sequence span
}
```

**Page scoring:** For query $q$, compute sketch-space probe $\phi(q)$, then:

$$\tilde{a}_i(q) = \langle \phi(q), y_i \rangle$$

Select top-k pages. Only then decode residual or load exact.

### 3.4 The Shadow-First Attention Pipeline

```
1. Sketch query: q̂ = R(q)                    // SRHT, 480-dim INT8
2. Score all pages via Metal kernel:       // Parallel INT8 dot product
   s_i = q̂ · y_i  for i ∈ [1, n_pages]
3. Select top-k (k=64-256)                 // Radix sort on GPU
4. Escalation decision per selected page:
   - σ < 0.05  → use sketch only
   - 0.05 ≤ σ < 0.20 → decode residual
   - σ ≥ 0.20 → load exact from SSD
5. Run exact attention on decoded pages + L0 hot memory
6. Track KL divergence; adjust thresholds if drift > 0.06
```

---

## 4. The Cognitive Layer: Resonance Gate + VaultGatedSwarm

### 4.1 The Resonance Gate (Unified Filter)

Every token, claim, file, and agent action receives a **7-field Resonance Signature**:

$$\Sigma(x) = [\tau(x), \delta(x), \pi(x), \rho(x), \kappa(x), \eta(x), \lambda(x)]$$

| Field | Values | Physical Analogue |
|---|---|---|
| $\tau$ (ternary) | +1 (verified), 0 (pending), -1 (contradicted) | Gyrotron spin direction |
| $\delta$ (direction) | up/down/sideways/inward/on-itself | Energy gradient direction |
| $\pi$ (prime/comp) | Prime (irreducible), Composite (derived), Gap | Quark combination state |
| $\rho$ (resonance) | [0, 1] — clarity × color × centrality | Standing wave coherence |
| $\kappa$ (KAM) | Diophantine stability score | Time flow stability |
| $\eta$ (evidence) | Anchored / Edge / Pending | Binding strength |
| $\lambda$ (residency) | L0-L7 | Energy density tier |

**Decision matrix:**
- $\tau = -1$ → Quarantine (L7)
- $\eta = \text{Edge}$ → Trigger Evidence Supremacy Protocol
- $\pi = \text{Prime} \land \rho > 0.7 \land \kappa > 0.382$ → Engram anchor
- $\kappa \leq 0.382$ → Migrate residency (KAM breakdown)

### 4.2 VaultGatedSwarm (Multi-Agent System)

The **one stable feature** that wraps the entire philosophy: **VaultGatedSwarm**.

A Vault is a user-selected directory, biometrically secured (Touch ID / Face ID). Once unlocked, it exposes files to a specialized agent swarm scoped exclusively to that vault. Lock the vault — all agents on it die instantly.

```rust
pub struct VaultGatedSwarm {
    pub vaults: HashMap<VaultId, Vault>,
    pub orchestrator: Arc<dyn Orchestrator>,
    pub gate: Arc<dyn Gate>,
    pub biometric: BiometricGate,
}

impl VaultGatedSwarm {
    pub async fn unlock_vault(&self, id: VaultId) -> Result<()> {
        // 1. Touch ID authentication
        // 2. Start security-scoped resource access
        // 3. Spawn agent swarm scoped to vault
        // 4. Set state to Unlocked
    }
    
    pub async fn lock_vault(&self, id: VaultId) -> Result<()> {
        // 1. Kill all agents (KAM torus destruction)
        // 2. Stop security-scoped access
        // 3. Set state to Locked
    }
}
```

**Agent definitions** (Markdown frontmatter, Claude Code pattern):
```markdown
---
name: code-architect
trust_tier: specialist
vault_scope: any
capabilities:
  - skill: code_review
    proficiency: 0.95
model_profile:
  backend: local
  model: qwen3-8b-sherry
---
```

**Workflow templates** (GodMode pattern):
- NewFeature: researcher → architect → builder → parallel(validator, tester) → scribe
- BugFix: debugger → builder → parallel(validator, tester)

---

## 5. The Cloud Layer: Hermes Gateway

Hermes is the L7 Cloud Claw — a quarantined sidecar that mediates all external interaction.

### 5.1 Zero-Copy Shared Memory

No JSON-RPC. No sockets. Typed `mmap` arena with cache-line alignment:

```rust
#[repr(C, align(4096))]
pub struct CloudArena {
    pub sequence: AtomicU64,
    pub write_idx: AtomicU64,
    pub read_idx: AtomicU64,
    pub requests: [CloudRequest; 16],   // 4.2KB each
    pub responses: [CloudResponse; 16], // 8.2KB each
}
```

**Zero-copy semantics:** Epistemos writes request → signals via mach port → Hermes reads same memory → processes → writes response → signals back.

### 5.2 Mandatory Low-Trust Signature

All Hermes outputs are classified:
- $\tau = 0$ (Pending)
- $\delta =$ Sideways
- $\pi =$ Composite
- $\rho \leq 0.3$
- $\kappa \leq 0.1$
- $\eta =$ Edge
- $\lambda =$ L7

**Hard invariant:** Cloud claims can become Verified and Anchored, but **never Prime**.

### 5.3 Capability Grant System

```rust
pub struct CapabilityGrant {
    pub permissions: CapFlags,       // WEB_SEARCH | CODE_EXEC | API_CALL | ...
    pub expires_at: UnixTimestamp,
    pub signature: [u8; 32],         // HMAC-SHA256
    pub max_tokens: u32,
    pub allowed_providers: ProviderSet,
}
```

No ambient authority. Every action requires explicit, signed, time-limited capability.

---

## 6. The Rust Stack: Crate Architecture

```
helios/
├── Cargo.toml
├── crates/
│   ├── helios-core/          # no_std, pure Rust math
│   │   ├── lattice/          # E8/D24/Leech VQ
│   │   ├── sketch/           # CountSketch, SRHT, FJL
│   │   ├── prcda/            # Predictor + residual coding
│   │   ├── inequality/       # Five-term bound verifier
│   │   └── types/            # Type-state state machine
│   ├── helios-mlx/           # MLX tensor bridge
│   │   ├── kernels/          # MSL source strings + JIT cache
│   │   ├── attention/        # Shadow + sparse + paged
│   │   └── tensors/          # Array ↔ core type bridge
│   ├── helios-metal/         # objc2-metal direct path
│   │   ├── residency/        # MTLResidencySet (macOS 15+)
│   │   ├── pages/            # 5-tier page allocator
│   │   └── iosurface/        # Zero-copy ANE↔GPU↔CPU
│   ├── helios-amx/           # CPU coprocessor (feature-gated)
│   ├── helios-ane/           # CoreML/ANEMLL bridge (tier-4)
│   ├── helios-runtime/       # tokio + rayon + crossbeam
│   ├── helios-models/
│   │   ├── transformer/      # Qwen3-8B harness
│   │   └── ssm/              # Mamba-2 / RWKV-7 harness
│   ├── helios-bench/         # KL drift, recall, latency
│   └── helios-ffi/           # UniFFI Swift binding
├── kernels/*.metal
└── scripts/build-xcframework.sh
```

**Rule:** Rust orchestrates. MLX graphs. Metal executes.

---

## 7. The Swift UI: Vault Manager

```swift
struct VaultManagerView: View {
    @Query(sort: \Vault.createdAt) private var vaults: [Vault]
    
    var body: some View {
        NavigationSplitView {
            List(vaults) { vault in
                VaultRow(vault: vault,
                    onUnlock: { unlockWithTouchID(vault) },
                    onLock: { lockVault(vault) })
            }
            .toolbar {
                Button("Add Vault...") { showDirectoryPicker() }
            }
        } detail: {
            if let vault = selectedVault, vault.state == .unlocked {
                VaultDetailView(vault: vault)
            }
        }
    }
}
```

**Security:**
- `kSecAccessControlBiometryCurrentSet` invalidates on fingerprint change
- Security-scoped bookmarks for persistent sandbox access
- `com.apple.security.files.user-selected.read-write` entitlement
- Auto-lock after 5 minutes inactivity

---

## 8. The Build Path: 24-Month Roadmap

| Phase | Months | Deliverable | Threshold |
|---|---|---|---|
| **Stage 0** | Now | 7-day move: E8 round-trip + CountSketch + MLX boot + MSL kernel + PRCDA layer + Shadow tier + UniFFI demo | Day-7 working seam |
| **Stage 1** | 1-6 | `helios-core` + `helios-mlx`. Tier-2 (PRCDA) production-ready. | Four-term inequality within 10% |
| **Stage 2** | 6-12 | Tier-3 (Shadow) shipped. Escalation policy. Five-term inequality validated. | 10× compression, KL < 0.05, >25 tok/s |
| **Stage 3** | 12-18 | SSM track (Mamba-2). Comparative analysis. VaultGatedSwarm + Resonance Gate integration. | 5pp falsifier passes |
| **Stage 4** | 18-24 | AMX/ANE feature gating. Performance hardening. MLSys/NeurIPS submission. | Paper accepted or independently reproduced |

---

## 9. The Falsifier Discipline

Four predictions that must hold, or the spec is revised:

1. **Five-term inequality:** Measured per-token KL stays under predicted bound at 95% empirical probability across 100 PG-19 prompts.
2. **Shadow recall:** Top-k page recall ≥ 0.95 at k=64 across all measured layers.
3. **Cross-architecture unity:** SSM-track shadow recall within 5 pp of Transformer-track on equivalent workload.
4. **Memory budget:** Peak RAM ≤ 12 GB on 16 GB MacBook for 4K-token Qwen3-8B run.

---

## 10. Summary: The One Philosophy

> **Do not store the world. Sketch what you need to ask. Escalate only when uncertainty forces you.**

This principle, abstracted from quantum oracle sketching and grounded in the physics of energy density, time flow, and spin quanta, is the organizing doctrine of Epistemos. Every component — from the Helios memory tiers to the Resonance Gate to the VaultGatedSwarm to the Hermes cloud boundary — embodies it.

The binary stack was a local optimum. The ternary stack was better. The **sketch-native, lattice-quantized, vault-gated, resonance-filtered, physics-grounded stack** is the global optimum.

Build it.
