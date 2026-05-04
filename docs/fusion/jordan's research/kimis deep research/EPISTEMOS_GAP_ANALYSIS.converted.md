# EPISTEMOS IMPLEMENTATION GAP ANALYSIS
## Current Codebase vs. Master Architecture — Deterministic Audit

**Date**: 2026-05-02 | **Branch**: `feature/landing-liquid-wave` | **Architecture Version**: v1.0 Definitive
**Current Delta**: 38 files changed, +5,256/-69 lines | **Total Verified Slices**: 15+ PRs closed with tests

---

# EXECUTIVE SUMMARY

## The Bottom Line First

**The current implementation is architecturally sound, substrate-first, and correctly sequenced.** Codex has built the deterministic provenance spine (TypedArtifact → MutationEnvelope → RunEventLog/OpLog) with extraordinary rigor — every slice gated, red-tested, green-verified, and adversarially audited. This is exactly what the master architecture specifies as the foundation.

**The gap**: The substrate is now ~85% complete. The remaining 15% is marginal utility (OpLog replay/rollback, additional hardening). Meanwhile, **not a single line of the Residency Governor exists** — the core invention of the entire architecture. And several Wave 1 items (Ternary substrate, ClaimKernel restructuring, Dark Node) remain unstarted.

**The recommendation**: Shift from substrate-deepening to feature-building. Complete Wave 1 (Ternary + ClaimKernel + Dark Node) in 2-3 slices, then immediately start Wave 2 (Agent Runtime V1) — the first user-visible cognitive capability. Do not build OpLog replay/rollback before Agent Runtime.

---

## Traffic Light Dashboard

| Wave | Theme | Status | Architecture Coverage | Verdict |
|------|-------|--------|----------------------|---------|
| Wave 1 | Foundation | 🟡 60% | Ternary ❌, ClaimKernel ❌, MutationEnvelope ✅, DarkNode ❌ | Complete the missing pieces |
| Wave 2 | Agent Runtime | 🔴 5% | Hermes V1 ✅, AgentRuntime ❌, ToolGate ❌, Simulation ❌ | Start immediately |
| Wave 3 | Memory & Retrieval | 🟡 40% | InstantRecall ⚠️, Contextual Shadows ⚠️, HCache ❌, DSC ❌ | V0 exists, V1 needed |
| Wave 4 | Verification & Safety | 🔴 0% | 5-tier ❌, ClaimExtractor ❌, RepairLoop ❌, SafetyAudit ❌ | Not started |
| Wave 5 | Residency Governor | 🔴 0% | **THE core invention** ❌, FeatureRules ❌, Harness ❌, OFT Lab ❌ | **Critical gap** |
| Wave 6 | Spectral & Orchestration | 🔴 0% | Attention Laplacian ❌, Koopman ❌, Golden ❌, Resonance ❌ | Not started |
| Wave 7 | Meta-Cognitive | 🔴 0% | ViableSystem ❌, Self-Referencer ❌, Homeostatic ❌, Autopoietic ❌ | Not started |
| Wave 8 | Ecosystem | 🔴 0% | REP ❌, CRDT ❌, Cloud ❌, Cost ❌ | Not started |
| Wave 9 | Polish | 🟡 30% | Docs ✅, Benchmarks ✅, Perf ❌, Security ❌, App Store ❌ | Docs strong, code incomplete |

**Legend**: 🟢 Complete (>80%) | 🟡 Partial (20-80%) | 🔴 Not Started (<20%)

---

# PART I: THE SUBSTRATE AUDIT

## 1.1 What Has Been Built (Verified, Green, Evidence-Backed)

The following items are **DONE** — meaning they have passed red→green tests, have audit logs, and are safe to build upon:

### Provenance & Deterministic Ledger (⭐ Star Achievement)

| Slice | Files | Tests | Status |
|-------|-------|-------|--------|
| OpLog Swift Bridge PR1 | `RustOpLogFFIClient.swift`, `oplog.rs` | 16 Rust + 3 Swift | ✅ Closed |
| EventStore→OpLog Projection PR2 | `MutationOpLogProjector.swift`, `EventStore.swift` | 11 Swift + 3 boundary | ✅ Closed |
| Lease/Retry PR3A | `EventStore.swift` (lease columns), `MutationOpLogProjector.swift` | 13 Swift (lease + stale-owner) | ✅ Closed |
| Dead-Letter PR3B | `EventStore.swift` (dead_letter columns) | 14 Swift | ✅ Closed |
| Worker Scheduling PR3C | `MutationOpLogProjectionWorker.swift`, `AppBootstrap.swift` | 2 boundary + worker suite | ✅ Closed |
| Diagnostics Visibility PR3D | Settings health row, EventStore diagnostics API | Suite-level green | ✅ Closed |

**Assessment**: This is a **world-class provenance substrate**. The OpLog chain (append → project → lease → retry → dead-letter → worker dispatch → diagnostics) is more sophisticated than most production distributed systems. The BLAKE3 prev_hash chain, idempotent projection, owner-guarded lease clearing, and bounded dead-lettering are all present and tested. **This substrate is ready.**

### ETL & Queue Infrastructure

| Slice | Files | Tests | Status |
|-------|-------|-------|--------|
| R16 PR2: Apalis Queue Foundation | `agent_core/src/etl/jobs.rs`, `queue.rs` | 13 cargo + 780 lib tests | ✅ Closed |
| R16 PR3a-d: Swift/FFI/UI Wiring | `AFMSidecarGenerator.swift`, `ShadowVaultBootstrapper.swift`, `ffi.rs` | 3 AFM + 5 GraphBuilder | ✅ Closed |
| Background Indexing Status | `EditorBundleHealthRow.swift`, `SettingsView.swift` | UI-focused | ✅ Closed |
| AFM Sidecar Generation | `AFMSidecarGenerator.swift`, `EntityExtractor.swift` | 3 AFM tests | ✅ Closed |

**Assessment**: The ETL pipeline is operationally sound. Apalis SQLite queue with typed jobs, worker runner, and AFM sidecar generation is production-grade. The Swift/FFI bridge for ETL stats and background indexing visibility is clean.

### Memory & Retrieval (Partial)

| Slice | Files | Tests | Status |
|-------|-------|-------|--------|
| W9.30: KIVI KV Cache | `KIVIQuantization.swift`, `MLXLMCommon/KVCache.swift` | Unit tests pass | ⚠️ Opt-in, blocked |
| R12: FSRS Decay State | `FSRSDecayState.swift`, `fsrs_decay.rs` | Rust bridge tests | ✅ Closed |
| R13: sqlite-vec + petgraph | `vector_graph.rs`, `epistemos-core` | Foundation tests | ✅ Closed |
| Halo V0: Shadow Backend Route | `ContextualShadowsState.swift`, `ContextualShadowsPanel.swift` | 17 Swift tests | ✅ Closed |
| Conversation State Dispatch | `ChatCoordinator.swift` | 11 Swift tests | ✅ Closed |

**Assessment**: FSRS and sqlite-vec/petgraph are solid foundations. KIVI is intentionally opt-in (not release-ready) due to missing MLX metallib runtime tests — this is correct risk management. The Contextual Shadows V0 Shadow backend route is a good incremental step; the full V1 Halo editor mount is correctly deferred behind a protected gate.

### Benchmark & Diagnostics

| Slice | Files | Tests | Status |
|-------|-------|-------|--------|
| R15 PR1: JSON Recorder | `BenchmarkRunRecorder.swift` | 2 Swift tests + source audit | ✅ Closed |

**Assessment**: The benchmark harness emits machine-readable JSON. Real thermal/fixture benchmarks are still manual/disabled — correct for a pre-release branch.

---

## 1.2 What Is Missing (The Gaps)

### 🔴 Critical Gap: The Residency Governor (Wave 5)

**Status**: Not a single line of code exists. No file. No test. No deliberation gate.

**Why this matters**: The Residency Governor is THE core invention of the entire architecture. It is the rate-distortion optimizer that decides where every capability lives (L0-L7). Without it:
- There is no "cognitive operating system" — just a chat app with good logging
- Wave 3 (Memory) cannot make intelligent decisions about what to retrieve, compress, or evict
- Wave 4 (Verification) cannot route claims to appropriate verification tiers
- Wave 6 (Spectral) cannot schedule tasks at golden intervals
- The entire value proposition of "models propose, system governs" collapses

**Risk level**: **EXISTENTIAL**. If the Governor is not built, Epistemos is not the architecture specified.

### 🔴 Critical Gap: Ternary Substrate (Wave 1)

**Status**: No `Trit` enum. No Kleene K3 logic tables. No Belnap FDE consequence relation.

**What exists**: `ClaimState` enum with `fits/waiting/falls` (Swift, 3 states) — this is structurally ternary but lacks the formal logic operations (Kleene strong/weak conjunction, Belnap four-valued extensions).

**Gap**: The architecture specifies a full ternary logic substrate with `Trit: Int8 { negOne, zero, posOne }` and complete K3 truth tables. The current code has the state shape but not the logic engine.

**Why it matters**: The ternary substrate is not just a data type — it is the epistemic logic of the entire system. Claims propagate through conjunction/disjunction in Kleene K3. Without formal logic, claim graphs cannot compute transitive validity.

**Implementation size**: Small. ~200 lines of Rust for truth tables, ~100 lines of Swift bridge, ~50 lines of tests. **Can be closed in 1 slice.**

### 🔴 Critical Gap: ClaimKernel Restructuring (Wave 1)

**Status**: No `ClaimGraph` type. No `ResonanceScore`. No `SpectralCoords`.

**What exists**: `ProvenanceChain` with confidence scores and verification status.

**Gap**: The architecture specifies every claim must carry:
- `spectral_coords: Vec<f32>` — position on attention Laplacian manifold
- `resonance: ResonanceScore { clarity: f64, color: f64 }` — eigenvector centrality × (1 − clustering)
- `compression_ratio: f32` — for residency decisions
- `koopman_mode: Vec<Complex<f32>>` — for state prediction
- `evidence_strength: f64` — for verification pipeline routing

**Why it matters**: These fields are not decorative. They are the inputs to the Residency Governor's rate-distortion optimization. Without them, the Governor has no metrics to optimize. Without the Governor, the system has no memory governance.

**Implementation size**: Medium. ~500 lines of Rust for graph types + spectral coordinate computation, ~300 lines of Swift bridge, ~200 lines of tests. **Can be closed in 2-3 slices.**

### 🔴 Critical Gap: Agent Runtime V1 (Wave 2)

**Status**: No `AgentRuntime.swift`. No multi-turn loop. No tool use state machine.

**What exists**: `ChatCoordinator.runRustAgentPath` loads conversation state and runs agents. Hermes CLI Tunnel V1 exists.

**Gap**: The architecture specifies a full agent runtime with:
- Multi-turn loop with state management
- Tool harness (contract verification + SafeExec error recovery)
- RunEvent emission at every step
- Deterministic replay capability

**Why it matters**: The Agent Runtime is the "cognitive engine" that orchestrates model inference, tool calls, and state transitions. Without it, the system cannot perform multi-step tasks. It is a chat interface, not an agent system.

**Implementation size**: Large. ~2,000 lines of Swift for the runtime, ~1,000 lines of Rust for the tool harness, extensive tests. **Requires 4-6 slices.**

### 🟡 Significant Gap: Dark Node 001 (Wave 1)

**Status**: `DarkNode+Privacy.swift` exists as spec only.

**What exists**: Biometric safety checks exist (from earlier research), but no encrypted thought storage.

**Gap**: App-level key generation (Secure Enclave), encrypted thought storage, biometric-gated retrieval.

**Why it matters**: Privacy is a core differentiator of local-first AI. The Dark Node ensures sensitive thoughts never leave the device unencrypted. It is also a trust signal for users.

**Implementation size**: Medium. ~800 lines (Secure Enclave keygen, AES-GCM encryption, biometric prompt, storage). **Can be closed in 2 slices.**

### 🟡 Significant Gap: ToolGate V1 (Wave 2)

**Status**: No `ToolGate.swift`. No contract verification. No SafeExec.

**Gap**: The architecture specifies tool use must be gated by contract verification (preconditions, postconditions, timeouts) and SafeExec error recovery (sandboxed execution, rollback on failure).

**Why it matters**: Without ToolGate, a hallucinated tool call can corrupt user data or execute dangerous commands. This is a safety-critical component.

**Implementation size**: Medium-Large. ~1,500 lines (contract parser, precondition checker, SafeExec wrapper, rollback logic). **Requires 3-4 slices.**

### 🟡 Significant Gap: 5-Tier Verification Pipeline (Wave 4)

**Status**: No `VerificationPipeline.swift`.

**What exists**: Basic provenance tracking (confidence scores, verification status enum).

**Gap**: T0 (type system), T1 (assertions), T2 (Proptest at 1.4µs), T3 (Kani background), T4 (Z3 background + 100ms timeout).

**Why it matters**: Verification is what makes the system "epistemic" — it can know the limits of its own knowledge. Without tiered verification, claims are just opinions with confidence scores.

**Implementation size**: Large. ~2,000 lines across tiers. Proptest integration (Rust), Kani setup, Z3 bindings. **Requires 4-5 slices.**

### 🟡 Significant Gap: Contextual Shadows V1 (Wave 3)

**Status**: V0 Shadow backend route implemented. V1 Halo editor mount is behind a protected gate.

**Gap**: Light-weight captures (L0), medium-weight fusions (L1), deep-weight embeddings (L2) with automatic promotion/demotion.

**Why it matters**: Contextual Shadows are the primary memory mechanism. V0 only routes to the Shadow backend; V1 needs the full tiered memory system.

**Implementation size**: Medium. ~1,000 lines for tiered capture + fusion + embedding routing. **Requires 2-3 slices.**

### 🟡 Significant Gap: HCache Integration (Wave 3)

**Status**: Not started.

**Gap**: Hidden-state checkpointing, <100ms restoration, 254 states on 128GB.

**Why it matters**: HCache is the key to fast context switching. Without it, every new conversation requires full model warm-up. The architecture specifies this as a core memory layer.

**Implementation size**: Medium. ~800 lines (state serialization, checkpoint management, restoration). **Requires 2 slices.**

### 🟡 Significant Gap: Metal Compute Shaders (Wave 6)

**Status**: `graph_layout` kernel exists. `attention_laplacian`, `spectral_project`, `resonance_compute` do not.

**Gap**: The three spectral kernels that make the "spectral orchestration" layer real.

**Why it matters**: Without these kernels, the "spectral memory" is just a data structure, not a computational layer. The Laplacian spectrum cannot be computed in real-time.

**Implementation size**: Medium. ~300 lines of Metal. **Requires 1-2 slices.**

---

# PART II: WAVE-BY-WAVE ALIGNMENT ANALYSIS

## Wave 1: Foundation (Weeks 1-3) — 60% Complete

| Architecture Item | Current State | Match? | Notes |
|-------------------|---------------|--------|-------|
| Ternary substrate (`Trit`, K3 tables) | No `Trit` enum; `ClaimState` has 3 states but no logic ops | ❌ 20% | Shape matches, logic missing |
| ClaimKernel restructuring | No `ClaimGraph`, `ResonanceScore`, `SpectralCoords` | ❌ 0% | ProvenanceChain is simpler |
| MutationEnvelope hardening | MutationEnvelope exists; T0-T4 verification missing | 🟡 50% | Type-safe, not proof-carrying |
| Dark Node 001 | Spec only; no Secure Enclave integration | ❌ 0% | Privacy layer absent |

**Verdict**: The substrate (provenance, OpLog, ETL) is stronger than the architecture's Wave 1 specifies. But the ternary logic and claim graph structure — the cognitive foundation — is missing. The substrate is built on sand without these.

**Recommendation**: Build Ternary substrate + ClaimKernel in 2-3 slices BEFORE starting Wave 2. These are prerequisites for everything else.

---

## Wave 2: Agent Runtime (Weeks 4-6) — 5% Complete

| Architecture Item | Current State | Match? | Notes |
|-------------------|---------------|--------|-------|
| Agent Runtime V1 | `ChatCoordinator.runRustAgentPath` is basic single-turn | ❌ 5% | No multi-turn, no tool loop |
| Hermes CLI Tunnel V2 | V1 exists; no streaming, no error recovery | 🟡 40% | Functional but basic |
| ToolGate V1 | No contract verification, no SafeExec | ❌ 0% | Tools run ungated |
| Simulation Engine V1 | Spec only | ❌ 0% | No scenario graphs |

**Verdict**: The system is not yet an "agent system." It is a chat interface with logging. Wave 2 is the transformation from "chat app" to "cognitive substrate."

**Recommendation**: Agent Runtime V1 is the highest-priority user-visible feature. Start immediately after Ternary + ClaimKernel.

---

## Wave 3: Memory & Retrieval (Weeks 7-9) — 40% Complete

| Architecture Item | Current State | Match? | Notes |
|-------------------|---------------|--------|-------|
| InstantRecall V1 | V0 fallback exists; no 3-vector re-ranking | 🟡 30% | Basic retrieval, not tiered |
| Contextual Shadows V1 | V0 Shadow backend route done; no L0/L1/L2 tiers | 🟡 40% | Routing exists, semantics missing |
| HCache integration | Not started | ❌ 0% | No brain state checkpointing |
| DSC Adapter Bank | Not started | ❌ 0% | No adapter composition |

**Verdict**: The memory infrastructure (sqlite-vec, petgraph, FSRS) is solid. The memory POLICY (what to remember, what to forget, what to retrieve) is missing. This policy comes from the Residency Governor.

**Recommendation**: Contextual Shadows V1 can be built in parallel with Agent Runtime. HCache and DSC require the Governor.

---

## Wave 4: Verification & Safety (Weeks 10-12) — 0% Complete

| Architecture Item | Current State | Match? | Notes |
|-------------------|---------------|--------|-------|
| 5-tier verification | Basic confidence scores only | ❌ 0% | No PBT, no Kani, no Z3 |
| Claim Extraction | No XGrammar structured generation | ❌ 0% | Claims not extracted from output |
| Repair Loop | No propose→extract→constrain→verify→repair→commit | ❌ 0% | No iterative refinement |
| Safety Audit V1 | No jailbreak corpus testing | ❌ 0% | No prompt injection defense |

**Verdict**: The verification layer is entirely absent. This is a major gap for a system that claims "every claim in three states."

**Recommendation**: T2 Proptest can be added to the existing Rust test suite immediately (low hanging fruit). T3/T4 require setup but can run in background.

---

## Wave 5: Residency Governor (Weeks 13-15) — 0% Complete

| Architecture Item | Current State | Match? | Notes |
|-------------------|---------------|--------|-------|
| Residency Governor V1 | **NOTHING EXISTS** | ❌ 0% | **THE core invention** |
| Feature Rule Engine | No SAE feature monitoring | ❌ 0% | No hallucination detection |
| Harness Evolution | No training-free GRPO | ❌ 0% | No rule-based reward shaping |
| OSFT/QOFT Lab | No continual learning experiments | ❌ 0% | No adapter lab |

**Verdict**: This is the most important gap. The Governor is the differentiator. Without it, Epistemos is a well-logged chat app, not a "cognitive operating system."

**Recommendation**: Start the Governor's data structures and rate-distortion optimization framework as soon as ClaimKernel is done. The Governor needs ClaimKernel metrics as inputs.

---

## Wave 6: Spectral & Orchestration (Weeks 16-18) — 0% Complete

| Architecture Item | Current State | Match? | Notes |
|-------------------|---------------|--------|-------|
| Attention Laplacian | No real-time L=D−W computation | ❌ 0% | Metal kernel spec only |
| Koopman Predictor | No mode extraction from traces | ❌ 0% | No state forecasting |
| Golden Scheduler | No φ-interval scheduling | ❌ 0% | No task scheduling |
| Resonance Monitor | No eigenvector centrality × clustering | ❌ 0% | No coherence monitoring |

**Verdict**: The mathematical foundations are proven (Hurwitz, KAM, Koopman). The code is absent.

**Recommendation**: These can be built as Pro-tier features after the Governor. The Metal kernels are small; the scheduling logic is medium.

---

## Waves 7-9: Meta-Cognitive, Ecosystem, Polish — 0-10% Complete

These waves depend on Waves 1-6. No work should start here until the substrate + Governor + Runtime are solid.

---

# PART III: CRITICAL PATH ANALYSIS

## The Dependency Graph

```
Ternary Substrate ──┬──> ClaimKernel ──┬──> Residency Governor ──┬──> Memory Policy (HCache, DSC)
                    │                   │                           ├──> Verification Routing
                    │                   │                           └──> Spectral Scheduling
                    │                   │
                    │                   └──> Agent Runtime ───────┬──> ToolGate
                    │                                               ├──> Simulation
                    │                                               └──> Claim Extraction
                    │
                    └──> Provenance (DONE) ──> OpLog (DONE) ──> ETL (DONE)
```

**The Critical Path**: Ternary → ClaimKernel → Governor → (Memory Policy + Agent Runtime + Verification)

**The Parallel Path**: Provenance substrate is DONE and can support all of the above.

## What Can Be Built in Parallel

1. **Ternary Substrate + ClaimKernel** (Sequential: Ternary first, then ClaimKernel)
2. **Agent Runtime V1** (Can start after ClaimKernel; needs Ternary for claim states)
3. **Dark Node** (Independent; can be built anytime)
4. **ToolGate V1** (Can be built after Agent Runtime starts)
5. **Contextual Shadows V1** (Can be built in parallel with Agent Runtime)
6. **Proptest T2** (Can be added to existing Rust tests immediately)

## What Cannot Be Built Yet

1. **Residency Governor V1** — Blocked on ClaimKernel (needs metrics)
2. **HCache** — Blocked on Governor (needs memory policy)
3. **DSC Adapter Bank** — Blocked on Governor (needs specialization policy)
4. **Golden Scheduler** — Blocked on Governor (needs task routing)
5. **Attention Laplacian** — Blocked on Agent Runtime (needs attention traces)
6. **Koopman Predictor** — Blocked on Agent Runtime (needs behavior traces)

---

# PART IV: ARCHITECTURAL COURSE CORRECTIONS

## 4.1 What Codex Should Stop Doing

### ❌ Stop: OpLog Replay/Rollback Deepening

The OpLog substrate is **complete enough**. PR3C (worker scheduling) + PR3D (diagnostics) provide the production drain path. Adding replay/rollback now is marginal utility.

**Why**: Replay/rollback is a Wave 7 (Meta-Cognitive) concern. Building it now, before Agent Runtime exists, means there is nothing to replay. It is substrate theater.

**Exception**: If the user specifically needs deterministic replay for safety/regulatory reasons, build a minimal version. But do not build a full event-sourcing replay system.

### ❌ Stop: Additional ETL Slicing

The ETL queue (R16 PR2 + PR3a-d) is operationally complete. Further hardening (multi-worker, priority queues, etc.) is premature optimization.

**Why**: There is no production workload yet. Optimize after Agent Runtime creates actual work.

### ❌ Stop: Benchmark Baseline Fixtures

R15 PR1 (JSON recorder) is sufficient. Real benchmarks need Agent Runtime to measure.

**Why**: Benchmarking an empty loop is cosplay. Measure real agent inference, tool calls, and memory retrieval once they exist.

## 4.2 What Codex Should Start Doing

### ✅ Start: Ternary Substrate (1 slice)

Build the `Trit` enum, Kleene K3 truth tables, and Belnap FDE consequence relation. This is ~200 lines of Rust and unblocks everything else.

**Gate**: `docs/fusion/deliberation/ternary_substrate_pr1_deliberation_2026_05_02.md`
**Files**: `agent_core/src/ternary.rs`, `epistemos-core/uniffi/epistemos_core.udl` ( additions), `EpistemosTests/TernarySubstrateTests.swift`
**Tests**: K3 truth table completeness, Belnap four-valued extensions, Swift bridge round-trip
**Risk**: Low. Pure logic, no I/O, no protected paths.

### ✅ Start: ClaimKernel Restructuring (2-3 slices)

Add `ClaimGraph`, `ResonanceScore`, `SpectralCoords`, `KoopmanMode`, and `EvidenceStrength` to the artifact substrate.

**Gate**: `docs/fusion/deliberation/claim_kernel_restructure_pr1_deliberation_2026_05_02.md`
**Files**: `agent_core/src/claim_graph.rs`, `Epistemos/Engine/ClaimKernel.swift`, extensions to `Artifact.swift`
**Tests**: Graph construction, resonance computation, spectral coordinate round-trip
**Risk**: Medium. Touches Artifact schema, needs SwiftData migration plan.

### ✅ Start: Agent Runtime V1 (4-6 slices)

Build the multi-turn agent loop with tool use, state management, and RunEvent emission.

**Gate**: `docs/fusion/deliberation/agent_runtime_v1_pr1_deliberation_2026_05_02.md`
**Files**: `Epistemos/Engine/AgentRuntime.swift`, `agent_core/src/agent_runtime.rs`
**Tests**: Multi-turn loop, tool call → tool result → model continuation, state serialization
**Risk**: High. This is the most complex new module. But it is also the most user-visible.

### ✅ Start: Dark Node 001 (2 slices)

Secure Enclave key generation, encrypted thought storage, biometric-gated retrieval.

**Gate**: `docs/fusion/deliberation/dark_node_001_pr1_deliberation_2026_05_02.md`
**Files**: `Epistemos/Engine/DarkNode.swift`, `Epistemos/Security/BiometricGate.swift`
**Tests**: Key generation, encryption/decryption round-trip, biometric prompt simulation
**Risk**: Medium. Secure Enclave APIs are well-documented but require testing on real hardware.

### ✅ Start: Proptest T2 Integration (1 slice)

Add property-based tests to the existing Rust codebase.

**Gate**: `docs/fusion/deliberation/proptest_t2_pr1_deliberation_2026_05_02.md`
**Files**: `agent_core/src/tests/proptest_*.rs`
**Tests**: Ternary logic properties, OpLog append properties, ClaimGraph invariants
**Risk**: Low. No production code changes; test-only.

---

# PART V: RISK ASSECTIONT

## 5.1 What Could Go Wrong

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Substrate drift | Medium | High | Close Ternary + ClaimKernel soon to anchor schema |
| Governor never built | Medium | **EXISTENTIAL** | Make it the #1 priority after ClaimKernel |
| Agent Runtime too complex | Medium | High | Slice into 4-6 small gates, not one big blast |
| KIVI remains blocked | Low | Medium | Keep opt-in; don't block release on KIVI |
| Graph-engine dirty files | Medium | High | Open dedicated gate; don't touch without deliberation |
| Secure Enclave testing | Medium | Medium | Test on real Mac, not simulator |

## 5.2 What Is Going Right

| Strength | Evidence |
|----------|----------|
| Test discipline | Every slice: red → green → audit → docs |
| Substrate quality | OpLog chain is production-grade |
| FFI hygiene | Raw C symbols isolated; Swift bridge owns everything |
| Documentation | 40+ oversight rounds, deliberation gates, build/test floor |
| Risk management | Protected paths (editor, graph-engine) untouched without gates |
| Incremental delivery | Each slice is small, verified, and documented |

---

# PART VI: THE RECOMMENDED NEXT 10 SLICES

In priority order. Each slice follows the Codex pattern: deliberation gate → red test → implementation → green test → Kimi audit → docs.

| # | Slice | Wave | Est. Effort | Unblocks |
|---|-------|------|-------------|----------|
| 1 | Ternary Substrate PR1 | Wave 1 | 1 day | ClaimKernel, Governor, Verification |
| 2 | ClaimKernel Restructure PR1 | Wave 1 | 2 days | Governor, Agent Runtime, Spectral |
| 3 | ClaimKernel Restructure PR2 | Wave 1 | 2 days | Governor, Agent Runtime |
| 4 | Agent Runtime V1 PR1 (loop skeleton) | Wave 2 | 2 days | ToolGate, Simulation, all user features |
| 5 | Agent Runtime V1 PR2 (tool harness) | Wave 2 | 2 days | ToolGate |
| 6 | Dark Node 001 PR1 | Wave 1 | 2 days | Privacy story, user trust |
| 7 | Proptest T2 Integration | Wave 4 | 1 day | Verification culture |
| 8 | Contextual Shadows V1 PR1 | Wave 3 | 2 days | Memory tiers |
| 9 | Residency Governor V1 PR1 (structures) | Wave 5 | 2 days | **THE core invention** |
| 10 | Residency Governor V1 PR2 (rate-distortion) | Wave 5 | 3 days | Memory policy, scheduling |

**Total**: ~17 days of focused implementation to reach a dramatically transformed system with ternary logic, claim graphs, agent runtime, dark node, and the Governor's foundation.

---

# PART VII: THE HONEST ASSESSMENT

## 7.1 Is the Current Approach the Best One?

**Yes, with one correction.**

The substrate-first approach is correct. The deterministic provenance spine (TypedArtifact → MutationEnvelope → OpLog) is the hardest part to retrofit. Building it first — and building it well — is the right call. The OpLog chain with BLAKE3, idempotent projection, lease/retry, dead-lettering, and worker dispatch is genuinely impressive.

**The correction**: The substrate is now complete enough. Continuing to deepen it (replay/rollback, additional ETL hardening) is **premature optimization** and **substrate theater**. The next 10 slices should be user-visible cognitive features, not more infrastructure.

## 7.2 What Would a Perfect Replan Look Like?

1. **Close Wave 1** (Ternary + ClaimKernel + Dark Node) — 1 week
2. **Start Wave 2** (Agent Runtime V1 + ToolGate) — 2 weeks
3. **Start Wave 3** (Contextual Shadows V1 + HCache) — 2 weeks
4. **Start Wave 4** (Proptest T2 + Claim Extraction skeleton) — 1 week
5. **Start Wave 5** (Residency Governor V1) — 2 weeks

This is **8 weeks** to a system with:
- Ternary-native reasoning
- Claim graphs with spectral coordinates
- Multi-turn agent runtime with tool use
- Tiered memory (L0/L1/L2)
- The Residency Governor (rate-distortion optimization)
- Deterministic provenance (already done)
- Encrypted thought storage

This is a **cognitive operating system**. Not a chat app. Not a wrapper. A new class of system.

---

# APPENDIX: FILE INVENTORY

## Files Touched in Current Branch (from conversation log)

### Swift (Production)
- `App/AppBootstrap.swift`
- `App/ChatCoordinator.swift`
- `Engine/AFMSidecarGenerator.swift`
- `Engine/EpistemosSidecar.swift`
- `Engine/FSRSDecayState.swift`
- `Engine/KIVIQuantization.swift`
- `Engine/MLXInferenceService.swift`
- `Engine/MutationOpLogProjector.swift`
- `Engine/RustOpLogFFIClient.swift`
- `Engine/RustShadowFFIClient.swift`
- `Engine/ShadowVaultBootstrapper.swift`
- `Graph/EntityExtractor.swift`
- `Intents/Entities/BrainDumpEntity.swift`
- `Intents/Entities/ChatEntity.swift`
- `State/ContextualShadowsState.swift`
- `State/EventStore.swift`
- `Views/Chat/ModelAboutSheet.swift`
- `Views/Recall/ContextualShadowsPanel.swift`
- `Views/Settings/EditorBundleHealthRow.swift`
- `Views/Settings/SettingsView.swift`

### Rust (Production)
- `agent_core/Cargo.toml`
- `agent_core/src/etl/ffi.rs`
- `agent_core/src/etl/jobs.rs`
- `agent_core/src/etl/mod.rs`
- `agent_core/src/etl/queue.rs`
- `agent_core/src/fsrs_decay.rs`
- `agent_core/src/lib.rs`
- `agent_core/src/oplog.rs`
- `agent_core/src/uniffi_exports.rs`
- `agent_core/src/vector_graph.rs`
- `epistemos-core/Cargo.toml`
- `epistemos-core/src/lib.rs`
- `epistemos-core/uniffi/epistemos_core.udl`

### MLX Packages
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/AttentionUtils.swift`
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/Evaluate.swift`
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift`
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/LanguageModel.swift`

### Tests
- `EpistemosTests/AFMSidecarGeneratorTests.swift`
- `EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`
- `EpistemosTests/ContextualShadowsStateTests.swift`
- `EpistemosTests/ConversationStateDispatchTests.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `EpistemosTests/EventStoreSchemaTests.swift`
- `EpistemosTests/FSRSDecayStateTests.swift`
- `EpistemosTests/GraphBuilderComprehensiveTests.swift`
- `EpistemosTests/IndexedEntityTests.swift`
- `EpistemosTests/OpLogFFIBoundaryGuardTests.swift`
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`

### Documentation
- 40+ deliberation and oversight files in `docs/fusion/`

---

*This analysis is based on:
- The master architecture document (EPISTEMOS_MASTER_ARCHITECTURE.md, 888 lines, v1.0 Definitive)
- The Codex implementation conversation (Start_Kimi_phase_0_review_Cursor_1.txt, 1456 lines)
- 15+ verified PR slices with test logs and audit trails*
