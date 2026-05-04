# Epistenos Build Plan — All 6 Phases, Deepest Level

## Architecture Synthesis (from 15 research phases + 9 source documents)

**Core thesis:** Deterministic superintelligence via physics-inspired, mathematically-governed, locally-sovereign intelligence on Apple Silicon.

**Stack:** Rust (spine) + MLX (tensor runtime) + Metal (kernels) + Swift (UI) + UniFFI (bridge)

**Key constraints from source docs:**
- KV-Direct is THE binary gate (Qasim et al. arXiv:2603.19664) — residual stream reconstructs KV exactly
- WBO-5 is publishable base; WBO-6 is extension once T_SE instrumented
- Ternary: decode-first optimization, NOT full-stack. 3 layers: numerical {-1,0,+1}, epistemic {fits/waiting/falls}, operational {promote/hold/reject}
- Residual islands: embeddings/lm_head/norm stay dense; Q/K/V/O and MLP projections go ternary first
- Self-evolving: Titans-compatible interface, TTT-Linear core first, SEAL/DoRA nightly consolidation
- MAS-safe: XPC services + App Group + entitlements + security-scoped bookmarks
- Hermes: XPC cloud boundary (NOT child process), SMAppService for Pro
- Tool ladders: A→B→C→D variant fallthrough, GBNF-constrained, defer preferred over wrong action
- Hybrid MD+JSON memory with schema versioning

## Workspace Structure

```
epistenos/
├── Cargo.toml                    # workspace root
├── README.md
├── DESIGN.md                     # cross-crate API contracts
├── crates/
│   ├── helios-core/              # Phase 1: Pure Rust math
│   ├── helios-metal/             # Phase 2a: MSL kernels + dispatch
│   ├── helios-mlx/               # Phase 2b: Memory substrate (MLX integration)
│   ├── helios-runtime/           # Phase 3: Agent orchestration + Resonance Gate
│   ├── helios-models/            # Phase 4: Qwen3-8B + Mamba-2 + TTT
│   ├── helios-bench/             # Phase 6: Benchmarks + KV-Direct gate
│   └── helios-ffi/               # Phase 5: UniFFI bridge
└── swift/
    ├── EpistenosApp/             # SwiftUI app
    ├── EpistenosKit/             # Shared Swift code
    └── EpistenosXPC/             # XPC services (Hermes + Agent)
```

## Stage 1: Workspace Scaffold (Orchestrator)
- Create all directories
- Write root Cargo.toml with workspace members
- Write each crate's Cargo.toml with correct dependencies
- Write DESIGN.md with API contracts
- Write shared build configuration

## Stage 2: Parallel Crate Implementation (Sub-agents)

### Agent A: helios-core (Phase 1 — Core Math)
**Files:** lattice.rs, sketch.rs, prcda.rs, inequality.rs, types.rs, lib.rs
**Requirements:**
- lattice.rs: E8/Leech VQ codebooks, Babai nearest-plane algorithm, G(E8)=0.0717, G(Leech)=0.0658
- sketch.rs: CountSketch table + sparse JL + FRP basis (Hayase-Collins-Inoue), update/query, merge
- prcda.rs: Sherry 1.25-bit codec for residual streams (with NF4 fallback path), pack/unpack, block scales
- inequality.rs: WBO-6 term measurement — ‖Δlogits‖ ≤ ½·[T_W + T_K + T_R + T_Q + T_S + T_SE]
- types.rs: Type-state machine for tier transitions (L0→L1→L2→L3→L4→L_SE), TokenId, LayerId, secure newtypes
- All hot-path code REAL, no placeholder math

### Agent B: helios-metal (Phase 2a — Metal Kernels)
**Files:** All .metal files + Rust dispatch code
**Metal kernels (REAL code):**
1. `eml_softmax_lse.metal` — eml(x,y)=exp(x)-ln(y) fused softmax with log-sum-exp
2. `sherry_pack.metal` — 1.25-bit weight packing (16 weights → 10 bits + 6-bit scale)
3. `ternary_gemv.metal` — Packed trit GEMV (2 bits per trit, 16 trits per u32)
4. `ternary_proj_residual.metal` — Fused ternary projection + residual island add
5. `count_sketch_update.metal` — Streaming sketch table update
6. `kv_fingerprint.metal` — Ternary KV fingerprint shadow (sign + zero bucket + scale)
7. `surprise_grad_step.metal` — Titans-MAC online surprise gradient step
8. `dora_apply.metal` — SEAL DoRA low-rank adapter apply

**Rust dispatch:** device.rs, pipeline.rs, heaps.rs, profiler.rs

### Agent C: helios-mlx (Phase 2b — Memory Substrate)
**Files:** attention.rs, kv_direct.rs, pages.rs, residency.rs, shadow.rs, lib.rs
**Requirements:**
- attention.rs: Shadow-first attention (sketch-guided page selection before full attention), KV-Direct reconstruction
- kv_direct.rs: Qasim KV-Direct implementation — residual checkpoints, exact KV reconstruction, 5KB vs 136KB per token
- pages.rs: 6-tier allocator (L0 exact hot, L1 compressed residual, L2 sketch, L3 SSD mmap, L4 Hermes cascade, L_SE self-evolving)
- residency.rs: MTLResidencySet management for hot/cold pages
- shadow.rs: CountSketch shadows for retrieval routing

### Agent D: helios-runtime (Phase 3 — Runtime)
**Files:** agent.rs, orchestrator.rs, gate.rs, self_tuning.rs, scope_rex.rs, ladder.rs, lib.rs
**Requirements:**
- agent.rs: VaultGatedSwarm agent with Markdown frontmatter definition, biometrics-gated
- orchestrator.rs: Multi-agent orchestration with SCOPE-Rex Omega 8-state vector
- gate.rs: Resonance Gate 8-field signature (τ, δ, π, ρ, κ, η, λ, learning_mode)
- self_tuning.rs: Titans-MAC online surprise + SEAL nightly DoRA consolidation, base weights NEVER change
- scope_rex.rs: SCOPE-Rex Omega (h_t, z_t, g_t, p_t, m_t, w_t, ℓ_t, u_t), SemanticDelta, WitnessedState, event sourcing
- ladder.rs: Tool variant ladder A→B→C→D with circuit breakers, retry budgets, GBNF constraints

### Agent E: helios-models (Phase 4 — Models)
**Files:** transformer.rs, ssm.rs, bitnet.rs, ttt.rs, lib.rs
**Requirements:**
- transformer.rs: Qwen3-8B inference with Helios memory tiers, KV-Direct, shadow attention
- ssm.rs: Mamba-2 track with same Helios harness (cross-architecture validation)
- bitnet.rs: Ternary weight loading (BitNet format), residual island configuration
- ttt.rs: Test-Time Training Linear layer integration

### Agent F: helios-bench (Phase 6 — Testing + KV-Direct Gate)
**Files:** g1_kv_direct.rs, g2_recall.rs, g3_memory.rs, g4_determinism.rs, g5_self_tuning.rs, g6_vault_security.rs, lib.rs, main.rs
**Requirements:**
- g1_kv_direct.rs: WEEK-1 GATE EXPERIMENT — Qwen3-8B-MLX-4bit at 128k context, measure KL drift, RAM, tok/s
- g2_recall.rs: RULER long-context recall tests
- g3_memory.rs: Memory budget validation across 6 tiers
- g4_determinism.rs: Seeded replay determinism tests
- g5_self_tuning.rs: Titans-MAC coherence tests
- g6_vault_security.rs: Touch ID gate, HMAC token tests

### Agent G: helios-ffi + Swift (Phase 5 — Integration)
**Files:** api.udl, lib.rs (Rust), VaultManager.swift, AgentDashboard.swift, ResonanceGateView.swift, BiometricGate.swift, TernaryControlRoomView.swift, HermesXPCService.swift
**Requirements:**
- UniFFI bridge exposing core types to Swift
- VaultManager: Multi-vault with security-scoped bookmarks
- AgentDashboard: Live agent status, memory tier visualization
- ResonanceGateView: 8-field signature visualization, claim state colors
- BiometricGate: Touch ID / Face ID gate for write operations
- TernaryControlRoomView: Backend selector, metrics panel, implant control
- HermesXPCService: XPC cloud boundary (NOT child process)

## Stage 3: Verification Pass
- Compile-check all crates
- Verify API consistency across crate boundaries
- Check test coverage
- Verify KV-Direct gate harness is runnable

## Stage 4: Fix Pass
- Address compilation errors
- Fix API mismatches
- Add missing tests

## Code Fidelity Rules

**Hot-path (REAL implementation required):**
- All mathematical kernels (lattice, sketch, inequality, eml)
- Metal shader code (all .metal files)
- KV-Direct reconstruction logic
- Resonance Gate state machine
- Trit packing/unpacking
- Sherry codec pack/unpack
- CountSketch update/query

**Glue code (stubbed with TODO markers):**
- MLX model loading integration (stub around expected mlx-rs API)
- Full Swift UI navigation and chrome
- Network/cloud dispatch in Hermes
- Procedural memory migration
- A-MEM nightly evolution pass
- LSFS full implementation

## Deliverables
- 42+ source files across 7 crates + Swift layer
- All Cargo.toml with correct dependencies
- DESIGN.md with cross-crate contracts
- KV-Direct gate experiment runnable
- WBO-6 measurement instrumentation
- Ternary kernel suite (8 Metal kernels)
- Resonance Gate implementation
- SCOPE-Rex Omega event sourcing
- Biometric vault gating
