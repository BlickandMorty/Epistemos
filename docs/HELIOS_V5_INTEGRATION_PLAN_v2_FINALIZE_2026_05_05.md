---
state: canon (architectural decisions) + candidate (implementation slices)
finalized_on: 2026-05-05
covers: HELIOS V5 v2 plan FINALIZATION — closes coverage gaps + fixes PCF mapping per user audit ordering + adds anti-drift + benchmarks discipline + answers "what local files do I need"
companion_to: docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md (which this finalizes)
---

# HELIOS V5 Integration Plan v2 — **FINALIZE** addendum

> **Purpose:** v2 of the integration plan locked the architecture
> (Q1=C / Q2=optimal-combination / Q3=C) but had coverage gaps the
> user flagged: explicit E1–E7 + H1–H17 mapping, 8 cognitive
> functions, 4 killer demos, SCOPE-Rex full promotion path,
> six-tier memory, WBO, the 7-doc set, R0 archive structure, plus
> a PCF mapping correction (my v2 §2 used the wrong correspondence).
> Plus the user's new asks: anti-drift discipline during build +
> benchmarks/tests strategy + decision on in-app benchmarking.
>
> This addendum closes those gaps. After this lands, the v2 plan
> + this finalization = the complete integration canon, ready for
> per-slice implementation under sign-off discipline.

---

## §A — Coverage audit (what's covered, what wasn't, where it lives now)

| Research theme | v2 plan section | Coverage in v2 | Closed by this finalization? |
|---|---|---|---|
| Q1/Q2/Q3 ballot lock | §0 + §1 | ✅ complete | (was complete) |
| W1–W26 PR-ready wiring | §3 | ✅ complete | (was complete) |
| L1–L5 lanes | §1 + §5 | ✅ complete | (was complete) |
| Three-tier MAS rule | §1 | ✅ complete | (was complete) |
| Verified Floor `ac8c6d28` | §7 | ✅ pinned | (was complete) |
| Citation drifts (Bodnar, Wang) | §4 + §9 | ✅ complete | (was complete) |
| Dependency drift (tower-lsp) | §4 | ✅ complete | (was complete) |
| Goodfire VPD UPGRADED to verified | §2 + §9 | ✅ complete | (was complete) |
| **PCF-1…PCF-10 mapping** | §2 | ⚠️ wrong correspondence (number-by-number to T25-T34) | **FIXED in §B below** per user audit authoritative ordering |
| **E1–E7 Epistemos Core Theorems** | metadata only | ❌ no per-theorem mapping | **ADDED in §C below** |
| **H1–H17 Helios Operational Claims (incl. WBO)** | metadata only | ❌ no per-theorem mapping | **ADDED in §D below** |
| **8 cognitive functions (Memory/Routing/Planning/Verification/Working/Tools/Schema/Learning)** | not present | ❌ missing | **ADDED in §E below** |
| **4 killer demos (Quality/Efficiency/Reliability/Capability)** | not present | ❌ missing | **ADDED in §F below** |
| **SCOPE-Rex full surface (τ+π+λ Core / +δ+ρ Pro / +κ+η Research)** | §1 mentions Core only | ⚠️ partial | **ADDED full promotion path in §G below** |
| **Six-tier memory L0–L_SE** | §1 mentions briefly | ⚠️ partial | **ADDED in §H below** |
| **KV-Direct gate substrate (Helios v3 W0)** | W8 mentions | ⚠️ partial | **ADDED in §I below** |
| **The 7-doc set + INDEX (DOC 0–7)** | §0 §6 mention | ⚠️ partial | **ADDED in §J below** |
| **R0 Raw Research Archive structure** | metadata + closing | ⚠️ named, not structured | **ADDED in §K below** |
| **HELIOS v4 source_docs cross-reference (21 docs)** | §0 cross-refs section | ❌ generic refs only | **ADDED in §L below** (per-doc inline) |
| **Ternary lane / ACS / CMS-X / ODSC²/OSFT-PSOFT-coSO** | not present | ❌ missing | **ADDED in §M below** |
| **Anti-drift mechanisms during build (USER NEW ASK)** | not present | ❌ missing | **ADDED in §N below** |
| **Benchmarks + tests strategy + in-app benchmarking decision (USER NEW ASK)** | W23-W25 partially | ⚠️ partial | **ADDED in §O below** |

**Net:** all 22 research themes are now mapped; 14 of them gain explicit detail in this finalization. Zero local files required from the user (everything I needed was in v5.2 + v4.2 source canons + the HELIOS v4 preservation package which is already on disk).

---

## §B — PCF-1…PCF-10 mapping CORRECTED (user audit authoritative ordering)

My v2 §2 mapped T25→PCF-1, T26→PCF-2, etc. by number — **WRONG**. The user's audit gives a different correspondence. Authoritative mapping:

| PCF | Concept (audit-authoritative) | Maps to v5.2 T-number | Lane | Insertion site (current layout) |
|---|---|---|---|---|
| **PCF-1** | **ParamAnchor** (VPD extraction → frozen anchor library) | conceptually parent of T25 (Parameter Assembly Extraction) + T27 (Cortical-Packet Lift) | L3 | `crates/epistemos-research/src/vpd/anchor.rs` |
| **PCF-2** | **QKEdgeAnchor** (attention edge per W_QK^h decomposition) | T26 | L3 | `crates/epistemos-research/src/vpd/qk_edge.rs` |
| **PCF-3** | **ParamAttributionGraph** (graph over parameter components) | (no direct T-equivalent; new artifact) | L3 | `crates/epistemos-research/src/vpd/attribution_graph.rs` |
| **PCF-4** | **ComponentRoute** (route inference through component subset) | (no direct T-equivalent; new artifact) | L3 | `crates/epistemos-research/src/vpd/component_route.rs` |
| **PCF-5** | **ActiveRankOneExecution** (runtime per-step component activation) | T33 (Active Rank-One Execution) | **L5 Vault** | `crates/epistemos-vault/src/runtime/active_rank_one.rs` (gated `vault` feature) |
| **PCF-6** | **ModelSurgeryEnvelope** (offline edit + retrain-free distillation envelope) | conceptually wraps T29 (Component Edit Safety Bound) + parts of T34 | **L5 Vault** | `crates/epistemos-vault/src/surgery/envelope.rs` |
| **PCF-7** | **DualConnectomeTrace** (parameter-space + activation-space joint traces) | T31 (Dual Decomposition Completeness) | L3 | `crates/epistemos-research/src/vpd/dual_trace.rs` |
| **PCF-8** | **Parameter Connectome Sheaf Consistency** | T32 | L3 (ties to E2 sheaf substrate) | `crates/epistemos-research/src/vpd/connectome_sheaf.rs` |
| **PCF-9** | **Connectome Distillation** | T34 | **L5 Vault** | `crates/epistemos-vault/src/distill/connectome.rs` (alternate model file output may eventually ship Tier-2 in MAS after fresh §2.5.2 audit) |
| **PCF-10** | **Interpretability-to-Runtime Transfer** | T28 | **L5 Vault** | `crates/epistemos-vault/src/runtime/transfer.rs` |

**T-numbers absorbed but not directly mapped:**

- **T27 Parameter-to-Cortical-Packet Lift** — folded into PCF-1 ParamAnchor (cell-assembly is the cortical-packet manifestation of a parameter anchor cluster). Buzsáki 2010 cell-assembly theory cited under PCF-1, not standalone.
- **T29 Component Edit Safety Bound** — folded into PCF-6 ModelSurgeryEnvelope (the safety-bound is the envelope's correctness predicate).
- **T30 Component Cluster Compression** — folded into PCF-9 Connectome Distillation (cluster compression is the distillation mechanism).

Goodfire VPD specifics UPGRADED to `[VERIFIED-WEB-2026-05-05]` apply across all 10 PCF entries.

---

## §C — E1–E7 Epistemos Core Theorems (substrate-foundational)

Per user audit namespace hardening, the v2.0 hardened Seven-Theorem Ship Document remains the substrate-foundational anchor. **E1–E7 are sacred.** Each maps to current Epistemos code:

| E | Statement (one-liner) | Current substrate? | SCOPE-Rex hook | Lane |
|---|---|---|---|---|
| **E1 Density Theorem** | A_Morph(X) is uniformly dense in C(X, ℂ) over the 12-plane bundle X = A_1 × ⋯ × A_6 ⊂ ℂ⁶ (v2.1 patch: product, NOT disjoint union). Stone-Weierstrass via coordinates + conjugation + constant. | Conceptual; no `Chart6` type exists. | `on_chart_promotion` budget 80 µs | L3 (research falsifier) → L1 invariant when Chart6 lands |
| **E2 Ultrametric-Sheaf Gluing** | For finite patch graph G_q (≤128 nodes, ≤256 edges, stalk dim ≤8) cellular sheaf F_q, locally compatible patch states are exactly Γ(G_q, F_q) = H⁰(G_q, F_q) = ker δ⁰. | NO sheaf type in main; doctrine §A.13 references but no `CellularSheaf`. | `on_cross_tier_read` budget 200 µs | L3 → eventually L1 when sheaf substrate lands |
| **E3 Storage-Disaggregated Morph Field** | M_resident(t) ≤ M_core + M_state + M_active(t) + M_cache(t) + M_glue(t); resident scales with active patches not total archive size. | YES partial — `Epistemos/App/EpistemosApp.swift` `RuntimeDiagnosticsMonitor` tracks RSS via `mach_task_basic_info`; `agent_core/src/shared_memory.rs` ShmPool TTL eviction enforces bound. | `on_inference_step` budget 5 µs | L1 (ON in MAS) |
| **E4 UST-1.5 / WBO-7 Master Inequality** | (A) Pre-softmax: ‖Δz‖_∞ ≤ T_LWZ + T_K + T_R + T_TTR + T_SE + T_DAG + T_num. (B) Post-softmax: ½ contraction (Nair 2510.23012). T_S handled correctly per v2.1 patch. | Partial — `agent_core/src/prompt_caching.rs` tracks token quantization; no formal envelope check yet. | `on_eps_transition` budget 1 ms (sampled at 1/100) | L1 (ON in MAS, sampled) |
| **E5 Duplex Fusion** | ε_ℓ^fused ≤ (1−ρ_ℓ*)·ε_ℓ⁰ + ρ_ℓ*·ε_ℓ¹ + ‖ρ_ℓ − ρ_ℓ*‖_∞·‖P_{1,ℓ} − P_{0,ℓ}‖_∞. Architecture-level not Mamba-specific. | Partial — `Epistemos/LocalAgent/{LocalAgentLoop,ConfidenceRouter}.swift` route between paths but no formal η·Δ bound. | `on_router_emit` budget 100 µs | L2 (Pro) |
| **E6 Error-Enriched Convergence (Epi_ε)** | Five source formalisms admit structure-preserving embeddings into Epi_ε. NOT metaphysical identity. | Conceptual only. | docs-only, no runtime invariant | L3 (foundational language for E7) |
| **E7 Autogenous Kernel Identity** | For each template T_i, c_W ≃_{α, K_i · 2 ULP} c_C in Epi_ε. ULP-bounded kernel-vs-controller equivalence. v2.1 patch: equality in Epi_ε, not raw Para(Lens(Smooth)). | Partial — `Epistemos/Engine/MetalRuntimeManager.swift` ships precompiled Metal kernels; no ULP oracle harness. | `on_kernel_promote` budget 5 ms (spot-check ≥1024 random inputs) | L2 (Pro) → L1 attenuated |

**E-tier load-bearing:** if any E1–E7 fails its falsifier, the substrate is broken — HALT severity per v5.2 §H. CI gate B5 (HELIOS theorem-invariant smoke) enforces.

**Source docs (HELIOS v4 preservation package) for E1–E7:**
- `EPISTEMOS_FINAL_SEVEN_THEOREMS_v2_HARDENED.md` — primary source for E1–E7
- `EPISTEMOS_GRAND_MASTER_v3.md` — pre-hardening v3 wording
- `epistemos_helios_v3_master_canon_v2_1.md` — v2.1 patch source

---

## §D — H1–H17 Helios Operational Claims (build/canon claims)

Per user audit, the v5 operational theorem canon is H1–H17. **H1 is WBO-7 Master Inequality** — same mathematical content as E4 but viewed as an operational invariant for the build, not a substrate theorem. Mapping:

| H | Concept | Same as v5.2 T-number | Current substrate? | Lane / Tier |
|---|---|---|---|---|
| **H1** | **WBO-7 Master Inequality** (operational invariant — same content as E4 but build-checked) | T4 in v5.2 | partial | L1 sampled invariant |
| **H2** | **Half-softmax post-not-pre** rewrite | T5 in v5.2 | partial — `Epistemos/Engine/MLXInferenceService.swift` | L1 (W7 slice) |
| **H3** | **Active-Support Atlas** indexing | T1 in v5.2 (post-collision-resolution) | NEW — `agent_core/src/scope_rex/metal/asa_index.rs` per W6 | L1 (W6 slice) |
| **H4** | **LatticeCoder / Babai quantization** (Chen et al. 2507.18553 v3 ICLR 2026) | embedded in T4 components | NO — substrate doesn't exist | L2 |
| **H5** | **Morph DSL determinism** | embedded in T7 | NO — Morph DSL doesn't exist | L2 |
| **H6** | **TestTimeRegressor unification** (Wang-Shi-Fox 2501.12352) | T11 in v5.2 | NO | L3 |
| **H7** | **Six-tier memory L0–L_SE** | T1 area in v5.2 | partial — see §H below | L1 (Core L0–L3 + L7) → L2 (L4–L5) → L3 (L6 opt-in) |
| **H8** | **OSPC operators** (8 cognitive functions per Buzsáki) | T8 area in v5.2 | conceptual | L3 |
| **H9** | **Cortical Packet Runtime** | T8 in v5.2 (PARN/CAFTI) | NO | L3 |
| **H10** | **Bilaminar Substrate** (Julia oracle) | preserved in Lane 4 | NO; Julia oracle in `helios-oracle/` Cargo target NOT in main | L4 (never product per v5.2 §B.4) |
| **H11** | **Sheaf-Hodge spectral gap** (Seely 2025 / Bodnar 2202.04579 / Borgi 2512.00242) | T11 in v5.2 | NO | L3 |
| **H12** | **Berry-Phase routing holonomy** (Berry 1984 / Simon 1983) | T12 in v5.2 | NO | L3 |
| **H13** | **Information-Geometric KL Bridge** (Amari / Fisher metric) | T13 in v5.2 | NO | L3 (advisory monitor in L2) |
| **H14** | **Apollonian curvature constraint** (Graham-Lagarias-Mallows-Wilks-Yan 2003 + Rickards-Stange 2023's local-global FALSITY) | T14 in v5.2 | NO | L3 |
| **H15** | **Mādhava-style accelerated KL series** (Krishnachandran 2405.11134) | T15 in v5.2 | NO | L3 (init-only check) |
| **H16** | **CRT-based storage routing** | T16 in v5.2 | NO | L3 (init-only) |
| **H17** | **Modern Hopfield associative recall** (Ramsauer 2008.02217) | T17 in v5.2 | NO; new Metal kernel `hopfield_modern_update.metal` per v5.2 §B.2 | L2 (W15 slice; advisory monitor in L1) |

**H-tier severity ladder per v5.2 §H:**
- H1–H7 operational invariants: HALT or QUARANTINE
- H8–H10 substrate operators: QUARANTINE or DEGRADE
- H11–H17 cross-tradition: WARN

---

## §E — 8 cognitive functions (D.1–D.8 from v5.2 §D)

Per v5.2 §D, the 8 cognitive functions split deterministic/ML by contract:

| # | Function | Determinism contract | Current substrate | Lane |
|---|---|---|---|---|
| **D.1** | **Memory** | Six-tier P (E1 / Lean-formalized). HNSW cached as TypedArtifacts; ML-assists query routing. MemOS-style MemCube as TypedArtifact specialization. | YES partial — `agent_core/src/storage/vault.rs` (tantivy + bge-small) + `Epistemos/Sync/SearchIndexService.swift` (FTS5) + `epistemos-shadow` (HNSW). MemCube specialization NEW. | L1 |
| **D.2** | **Routing** | Gate3 ternary + bitset popcount + top-k inhibition fully P. LLM hidden states feature only — never load-bearing. | YES partial — `Epistemos/LocalAgent/ConfidenceRouter.swift`. Gate3 NEW. | L1 |
| **D.3** | **Planning** | Typed task DAG + Lean 4 obligations P. LLM proposes via MutationEnvelope. | Conceptual — `agent_core/src/cognitive_dag/` is the typed substrate. AlphaProof-style proposer NEW. | L2/L3 |
| **D.4** | **Verification** | Schema validation + sheaf consistency + ClaimGraph contradiction + Lean fully P. ML advisory only via H11 sheaf-Laplacian at WARN. | YES partial — `agent_core/src/cognitive_dag/storage.rs` capability binding (CD-005) + `agent_core/src/provenance/replay.rs` BLAKE3 chain. Sheaf substrate NEW. | L1 |
| **D.5** | **Working memory** | SDR D=10000 + Modern Hopfield + phase binding (Mamba-3) + HDC/VSA per Frady-Kleyko-Sommer 2009.06734 — all P. Capacity bounded per Clarkson-Ubaru-Yang 2301.10352. | NO — entirely new substrate. | L2 (Pro) |
| **D.6** | **Tool use** | Tool Court 100% deterministic + MCP integration. LLM proposes under DOMINO (no free-form). | YES — `omega-mcp/` crate (143 tests) + `agent_core/src/tools/registry.rs`. DOMINO grammar binding NEW (W1). | L1 |
| **D.7** | **Schema** | TypedArtifact + DOMINO grammar-constrained decoding (Beurer-Kellner ICML 2024 2403.06988). GBNF for AnswerPacket. | YES partial — `Epistemos/Models/MutationEnvelope.swift` + `agent_core/src/mutations/envelope.rs`. AnswerPacket + GBNF NEW (W1). | L1 |
| **D.8** | **Learning** | Three-factor Hebbian (Frémaux-Gerstner PMC4717313 2016) + SEAL self-edits (Zweiger 2506.10943) wrapped in MutationEnvelope. Active dendrites (Iyer-Grewal 2201.00042) for catastrophic-forgetting. | NO — entirely new substrate (Lane 3 SEAL stays research-only per v5.2). | L3 (research only) |

---

## §F — 4 killer demos (D.1–D.4 from v5.2 §E)

Per v5.2 §E:

| Demo | Claim | Mechanism | Acceptance |
|---|---|---|---|
| **Demo 1: Quality** | App + Qwen3-8B-bitnet beats Qwen3-32B-FP16 on 7-theorem corpus 200 questions | Structural verification through E1–E7 invariants makes small model more accurate where invariants apply (D.4-style structural lift, NOT raw scaling) | F1 lead ≥ 10pp on the corpus |
| **Demo 2: Efficiency** | 10× memory advantage, ≥3× latency advantage, ≥10× energy advantage | T-MAC arXiv 2407.00088: 71 tok/s M2-Ultra BitNet-3B, 70% energy reduction. Lipshitz arXiv 2510.06957: 5.98× sparse ternary GEMM on M-series. Profile per arXiv 2508.08531. | Per-metric thresholds per the 7-theorem corpus |
| **Demo 3: Reliability** | ≤1% out-of-corpus hallucination, ≥99% citation accuracy, ≥95% contradiction detection | **STRUCTURAL** (not empirical) via DOMINO-masked decoding bound to EvidenceLedger. Caveat: Wang 2025 arXiv 2508.18893 was withdrawn 2025-12-05 — Cybenko 1989 stands per user audit Patch 4. | The structural guarantee REPLACES the universal-approximation hope |
| **Demo 4: Capability** | Multi-day project tracking. "What changed since last week" — native LLMs structurally cannot do this | Externalized EvidenceLedger (E10/T10 cognitive externalization). Pairs with D.4 Verification + Cognitive DAG mirror coverage. | A/B against native LLM on multi-day task stream |

Note: I had T10 in my v2 §2 mapping under H/T-canon. With the user's audit namespace hardening, T10 Cognitive Externalization is no longer in H1–H17 explicitly — it's the **D.4 Capability demo** mechanism. Adjusted.

---

## §G — SCOPE-Rex full surface (Core / Pro / Research promotion path)

The user's question "scope rex wasn't sure if we have working" — here's the complete promotion path:

### SCOPE-Rex Core (τ + π + λ) — SHIPPED in main today

| Component | Code path | Doctrine anchor |
|---|---|---|
| **τ Kleene K3 truth** | `agent_core/src/resonance/tau.rs` | doctrine §4.1 invariant 1: "no token with τ = -1 ever reaches the user" |
| **π 9-claim classification** (equation, inequality, causal, definition, empirical, codeInvariant, prime, composite, gap) | `agent_core/src/resonance/pi.rs` | doctrine §4.1 |
| **λ residency target** (L0–L7) | `agent_core/src/resonance/lambda.rs` | doctrine §4.1 + §A.3 7-level residency hierarchy |
| **Swift mirror** | `Epistemos/Engine/ResonanceService.swift` | full Swift consumer + UI rendering of Σ-core signatures |
| **Module entry** | `agent_core/src/resonance/mod.rs` | (compose τ + π + λ) |

### SCOPE-Rex Pro (+δ + ρ) — NOT YET WIRED

| Component | Status | Insertion site |
|---|---|---|
| **δ 5 directional operators** (upward generalization, downward specialization, lateral resonance, etc.) | NEW | `agent_core/src/resonance/delta.rs` (NEW) |
| **ρ resonance** (claim-graph propagation) | NEW | `agent_core/src/resonance/rho.rs` (NEW) |
| **Pro-tier wiring** | NEW | extend `agent_core/src/resonance/mod.rs` to compose Core + δ + ρ when `pro-build` feature enabled |

**Promotion gate Core → Pro:** the Pro tier δ + ρ require the cognitive DAG sheaf substrate to be operational (E2 Ultrametric Sheaf Gluing in this finalization). Implementation slice depends on E2 substrate landing first.

### SCOPE-Rex Research (+κ + η) — NOT YET WIRED

| Component | Status | Insertion site |
|---|---|---|
| **κ KAM** (KAM-stability of routing trajectories under perturbation) | NEW | `agent_core/src/resonance/kappa.rs` (NEW) |
| **η evidence** (evidence-supremacy protocol; flags "edge" claims for VRM) | NEW | `agent_core/src/resonance/eta.rs` (NEW) |
| **Research-tier wiring** | NEW | extend `agent_core/src/resonance/mod.rs` to compose Core + Pro + κ + η when `research` feature enabled |

**Promotion gate Pro → Research:** the Research tier κ + η depend on the L6 residency tier being implemented (six-tier memory §H below) and on the H11 Sheaf-Hodge spectral substrate operational.

### Σ signature (full Resonance Gate output)

```
Σ(x) = [τ truth, δ direction, π prime/composite/gap, ρ resonance, κ KAM, η evidence, λ residency]
```

Currently Σ shipped = `[τ, π, λ]` (3 of 7 components). Pro promotion brings to 5. Research promotion brings to 7.

**Source docs (HELIOS v4 preservation package):**
- `epistemos_resonance_gate.md` — Resonance Gate primary source
- `scope_rex_omega.md` — SCOPE-Rex Omega witnessed governance/provenance spine

---

## §H — Six-tier memory L0–L_SE (per HELIOS v3 + doctrine §A.3)

| Tier | Name | What | Current substrate | Lane |
|---|---|---|---|---|
| **L0** | Register / SIMD | CPU register file + SIMD lanes | implicit (compiler-managed) | L1 |
| **L1** | L1 cache | per-core L1 | implicit | L1 |
| **L2** | L2 cache | per-cluster L2 | implicit | L1 |
| **L3** | L3 SLC (System Level Cache) | shared SLC on Apple Silicon | implicit | L1 |
| **L_DRAM** | Unified memory | UMA pool (8 GB working budget on M2 Max 16 GB; up to 192 GB on M2 Ultra) | YES — `Epistemos/Engine/MetalRuntimeManager.swift` `storageModeShared` MTLBuffer pattern (37+ sites per CLAUDE.md) | L1 (zero-copy invariant per doctrine §2.2 #1) |
| **L_SSD** | mmap'd cold tier | tantivy + sqlite mmap + memmap2 + tree-sitter | YES partial — `agent_core/src/arena/mod.rs` MmapMut + `Epistemos/Sync/SearchIndexService.swift` PRAGMA mmap_size = 256 MiB. mmap audit doc: `docs/MMAP_UTILIZATION_AUDIT_2026_05_05.md`. | L1 |
| **L_SE** | Secure Enclave / sealed archive | Touch ID-bound encrypted cold | YES partial — `Epistemos/Security/CapabilityBridge.swift` SovereignGate scaffolding. L_SE mode NEW. | L1 (Sovereign Gate gates access) |
| **L4** | Engram / compressed episodic | medium-term compressed memory (Pro) | NEW | L2 (Pro) |
| **L5** | Adapters / LoRA store | per-skill adapter cache (Pro) | partial — `Epistemos/KnowledgeFusion/MoLoRA/MoLoRAInferenceService.swift` (subprocess; B2 wants ported) | L2 (Pro) |
| **L6** | Forbidden tier (opt-in) | Research tier; user must explicitly opt-in to crossing | NEW | L3 (Research opt-in) |
| **L7** | Quarantine | poisoned artifacts; flagged but not deleted | YES — doctrine §A.3 + `agent_core/src/storage/vault.rs` quarantine path | L1 |

**KV-Direct gate (Helios v3 W0):** `agent_core/src/scope_rex/kv/direct_gate.rs` (NEW per W8 slice). Gates: D_KL ≈ 0 between residual-patched and original output on Qwen3-8B-MLX-4bit at 128k context. **THE preflight per HELIOS v4 README** ("the cheaper, faster preflight; F1/F7a is the more expensive Metal kernel work"). If KV-Direct fails, re-evaluate Helios v3 substrate before touching Metal kernels.

---

## §I — KV-Direct gate substrate (Helios v3 W0)

Status anchor per HELIOS v4 README: this IS the Monday-Move equivalent for the substrate side. Ship `crates/morph-kernel/tests/ulp_oracle.rs` Monday — **BUT ONLY AFTER** KV-Direct gate returns D_KL ≈ 0 on Qwen3-8B-MLX-4bit at 128k.

**Source:** Qasim et al. arXiv 2603.19664 (residual stream is bit-identical sufficient: D_KL = 0 between residual-patched and original output across six models, four families).

**Implementation slice:** W8 (Tier-1 path only when provably equivalent to existing cache; Tier-2 otherwise).

---

## §J — The 7-doc set + INDEX (DOC 0–7 from v5.2 §C)

Per v5.2 §C, the canon container is "7-doc set + INDEX = 8 files." Mapping to current `docs/` layout:

| DOC | Purpose | Current Epistemos doc that covers this |
|---|---|---|
| **DOC 0** [INDEX.md](http://INDEX.md) | top-level navigation, status table for every theorem, lane summary, reading order, SHA-256 hashes | `docs/fusion/ALL_DOCS_INDEX_2026_05_02.md` (existing master index; needs HELIOS v5 entries appended) |
| **DOC 1** LANE_1_SHIP_MAS.md | full Lane 1 spec; AnswerPacket schemas; E1–E7 MAS-compatible runtime invariants; 6-month roadmap | this v2 plan §1 + §3 (W1–W15 are the Lane 1 slices) |
| **DOC 2** LANE_2_ENGINEERING_MAX.md | full Lane 2 spec; 8 cognitive functions implementations; 20+ Metal kernels; 12-week roadmap | this v2 plan §3 (W6–W8 Tier-1 + W12–W15 Tier-2) + this finalization §E |
| **DOC 3** LANE_3_RESEARCH_FRONTIER.md | full Lane 3 spec; H1–H17 + PCF-1…PCF-10 Lean elaboration; 12-week formal verification | this finalization §C + §D (E1–E7 + H1–H17) + §B (PCF-1…PCF-10) |
| **DOC 4** LANE_4_SUBSTRATE_INDEPENDENT.md | Lane 4 spec; BZ rig; sandpile; Julia oracle; Bilaminar Substrate (H10) | NEW — needs creation if user wants Lane 4 active |
| **DOC 5** LANE_5_SPECULATIVE_VAULT.md | Lane 5 vault spec; every dropped/preserved branch with re-promotion falsifier | `docs/fusion/PRESERVED_RESEARCH_LEDGER.md` (HELIOS v4 preservation package) — already exists; needs HELIOS v5 entries appended |
| **DOC 6** THEOREM_CANON_V5.md | master theorem doc; per-theorem (E + H + PCF) precise statement / Lean / falsifier / attack / collision / runtime invariant / lane | NEW — would consolidate §C + §D + §B from this finalization into one doc; **substantial new doc** |
| **DOC 7** FINAL_SYNTHESIS_CHAT.md | the "why" of v5; 5-lane discipline as design philosophy; lock phrase; Monday move | this v2 plan §10 + this finalization §Q |

**Recommendation:** treat the v2 plan + this finalization as DOC 1+2+3+7 (combined). DOC 0 (INDEX) and DOC 5 (Vault) extend existing docs. DOC 4 (Lane 4) and DOC 6 (Theorem Canon) are NEW and held for sign-off as discrete create-the-doc slices.

---

## §K — HELIOS v4 preservation package — 21 source docs cross-reference

Per the v4 README, source docs classify Core (8) / Pro (9) / Research (5). All exist on disk at `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/source_docs/`:

**Core (load-bearing through-line, canonical reference):**

1. `helios_v3.md` — memory/inference capstone (PRCDA, WBO-6, six-tier memory, KV-Direct gate, 5 pillars). Anchors §H + §I above.
2. `scope_rex_omega.md` — witnessed governance/provenance spine (TypedArtifact pipeline). Anchors §G above + the Cognitive DAG mirror substrate already in main. **Note:** the source doc references "Hermes Agent containment" as historical context — that subprocess was removed 2026-05-05 and is NOT part of the v5 integration; the v5 integration uses `agent_core::agent_runtime` + Cognitive DAG, never the removed Hermes subprocess.
3. `ternary_kernel.md` — ternary research lane. Anchors §M ternary lane below.
4. `epistemos_helios_v3_master_canon_v2_1.md` — v2.1 immediate predecessor with all patches applied.
5. `epistemos_preservation_ledger_v2_1.json` — prior preservation ledger (machine-readable; cross-ref source for R0 archive structure).
6. `EPISTEMOS_FINAL_SEVEN_THEOREMS_v2_HARDENED.md` — **PRIMARY SOURCE for E1–E7** (§C above).
7. `EPISTEMOS_GRAND_MASTER_v3.md` — pre-hardening v3 grand master (Helios + Epistemos + Seven).
8. `Helios_third_.md` — final verification audit that gated v4 (publication calendar, hardware SKU, MSL empirical-only).

**Pro (extends and refines canon, v1-relevant):**

- `eml_engineering_brainstorm.md`, `eml_formal_synthesis.md` — EML primitive notes (preserved per Lane 5 vault re-promotion path; A.1 EML-alone density)
- `epistemos_definitive_master.md` — pre-v4 architectural master
- `epistemos_resonance_gate.md` — Resonance Gate primary source (anchors §G)
- `helios_shadow_memory.md` — shadow-memory architecture (related to `epistemos-shadow` crate already in main)
- `helios_v2.md` — v2 capstone
- `hermes.md` — **R0-archive-only** (Hermes orchestrator subprocess REMOVED 2026-05-05; user explicitly excluded Hermes from all forward work 2026-05-05; this doc is preserved in R0 historical archive ONLY, never extended, never referenced as a forward target)
- `mac_store_edition.md` — Mac App Store distribution discipline (anchors L1 §1 above)
- `XPC.md` — XPC architecture notes (the trust spine landed at `Epistemos/XPC/XPCTrust.swift`)

**Research (research lanes preserved):**

- `CMS_v2_Final_Definitive.md` — CMS-X constitutive field (anchors §M ACS/CMS-X below)
- `compass_artifact_wf-42f25075-c0fc-4bbd-bd73-cf78ac1af797_text_markdown.md` — compass artifact (research-only)
- `epistenos_build_prompt.md` — early build prompt (R0 raw archive)
- (plus EML deep work + ODSC² + deep research reports per README's "5 Research" classification)

**Plus:**
- `RAW_PROMPTS_FULL.md` (5.6 MB) + 107 individual files in `raw_prompts/` — **THE R0 raw research archive** per §K below.
- `manifests/MASTER_MANIFEST.csv` — SHA-256 audit entry point.

---

## §L — Ternary lane / ACS / CMS-X / ODSC² / OSFT-PSOFT-coSO

Per v4 README + source docs:

| Research lane | Source doc | Status | v5.2 lane assignment |
|---|---|---|---|
| **Ternary Kernel Lane** (Gate3 / BitNet / T-MAC) | `source_docs/ternary_kernel.md` | preserved in v4; v5.2 promotes T-MAC + BitNet b1.58 + Sparse Ternary GEMM to Tier-2 flagged kernels | L1 Tier-2 (W12–W14) |
| **ACS / CMS-X v3** (constitutive field on top of Helios) | `source_docs/CMS_v2_Final_Definitive.md` | preserved in v4 with cleared lit-validation | L3 (Research) |
| **ODSC² / OSFT-PSOFT-coSO** | preserved in v4 §7 of canon | research lane preserved; doctrine A.5 explicitly DROPS OSFT/PSOFT/coSO with QLoRA (4-bit incompatibility) and uses QOFT/QDoRA/QPiSSA for production | L3 (research) / L5 (vault) |

**Doctrine alignment:** doctrine §A.5 already covers the QOFT/QDoRA/QPiSSA replacement of OSFT/PSOFT/coSO — preserved in current main.

---

## §M — R0 Raw Research Archive structure

Per user audit: "R0 — Raw Research Archive. Append-only. Contains all raw prompts, pasted drafts, Helios v3, Helios v4, SCOPE-Rex docs, Julia brainstorms, brain architecture brainstorms, Goodfire/VPD notes, and every speculative math branch. Rule: nothing gets deleted. Bad claims get tagged, not erased."

**R0 substrate already exists at:**

`/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/`

**Contents:**

- `RAW_PROMPTS_FULL.md` (5.6 MB) — aggregated 107 raw prompts with TOC + SHA-256
- `raw_prompts/` directory — 107 individual files
- `source_docs/` — 21 final-synthesis docs (per §K)
- `manifests/MASTER_MANIFEST.csv` — SHA-256 audit manifest

**Recommended R0 extension for HELIOS v5+:**

Append a `raw_prompts_v5/` subdirectory + `helios_v5_audit_2026_05_05.md` (the user's audit verdict pasted) + `helios_v5_definitive_lock_v2_2026_05_05.md` (the full v5.2 canon pasted) + `helios_v5_integration_brief_2026_05_05.md` (this v2 plan + finalization). All append-only. Update `manifests/MASTER_MANIFEST.csv` with new SHA-256s.

**Verification protocol (already in v4 README):**

```bash
cd EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/
python3 -c "[verify-script per README]"
```

**No deletion policy:** demoted branches get tagged `[DEMOTED-FROM-CANON-v5-2026-05-05]` in `PRESERVED_RESEARCH_LEDGER.md` with the re-promotion falsifier; the original source stays in R0 untouched.

---

## §N — Anti-drift mechanisms during build (USER NEW ASK)

User asked: *"i want to make sure it does not drift when building."*

The canon-hardening protocol installed today (`docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`) is the prospective discipline. The mechanisms below operationalize it FOR BUILD TIME:

### N.1 Per-slice WRV proof + rollback

Every W1–W26 slice has an explicit WRV (Wired/Reachable/Visible) proof + rollback procedure per v2 plan §3. **Anti-drift mechanism:** a slice cannot promote from `state: candidate` to `state: canon` without exercising the rollback. CI gate B5 enforces.

### N.2 Verified Floor pinning

`ac8c6d28` is the floor. Every commit since is `not-yet-shipped` until Codex verifies. **Anti-drift:** if any commit regresses against the Verified Floor, the Codex verification handoff catches it and the offending slice rolls back.

### N.3 Doctrine linter (B1) + replay verification (B2) on every push

- B1 `epistemos_doctrine_lint` enforces §5.1–§5.4 cognitive DAG doctrine gates per `agent_core/src/bin/epistemos_doctrine_lint.rs`.
- B2 `epistemos_trace verify-replay` against deterministic `.epbundle` fixture catches drift in wire format / BLAKE3 chain / DAG merkle root / storage / signature / capability paths.

**Anti-drift:** any PR that breaks doctrine §5.1–§5.4 OR breaks `.epbundle` parity fails CI before merge.

### N.4 Source-text guard tests (TK1 / Sig / EpdocVisibility / new XPCSmoke pattern)

Existing pattern in `EpistemosTests/`: tests that `loadMirroredSourceTextFile(...)` and assert exact substring presence in canonical source files. Catches refactor drift the unit tests miss.

**Anti-drift extension for HELIOS v5:** every E1–E7 + H1–H17 + PCF-1…PCF-10 invariant gets a source-text guard test asserting the canonical Rust file path + theorem-id docstring presence.

### N.5 Sorry-budget tracker (W24)

Per v5.2 §F: Lean repo `epikernel-theorems/` with sorry-budget tracked in CI. **Anti-drift:** if any E1–E7 EV theorem accumulates a sorry, OR any PCF-1…PCF-10 sorry-budget exceeds 7, escalate to mathlib4 contributor review before next CI green.

### N.6 No-date-gates rule (per canon-hardening protocol §3)

Only six valid gate types: capability / verification / distribution / entitlement / licensing / doctrine. **Anti-drift:** date strings as gates are non-canonical. Every gate decision must reduce to one of the six.

### N.7 Per-mirror caveat-narrowed dispatch capabilities (A2 already landed)

The dispatch layer signs each mirror's edge under a Caveat::ScopePrefix-narrowed macaroon (skills / procedural / provenance/evidence / provenance/claim / companions). **Anti-drift:** a stolen or replayed capability cannot sign edges outside its scope. Doctrine §1.2 contract.

### N.8 Aggregate ≤ 5 ms invariant budget per inference (sampled)

Per v5.2 §F: T1–T17 EV theorems sample at 1/100; PCF-1…PCF-10 sample at 1/10. **Anti-drift:** if aggregate amortized per-inference cost exceeds 5 ms, sampling rates tighten or invariants drop sampled tier per WARN→DEGRADE→QUARANTINE→HALT taxonomy.

### N.9 SHA-256 hash table in INDEX.md

Per v5.2 §F: every content doc gets a SHA-256 hash stored in INDEX.md. **Anti-drift:** CI fails if any content doc's hash changes without a corresponding INDEX update.

### N.10 W26 §2.5.2 compliance audit per release

Per v5.2 §4 W26: enumerate every bundled artifact + assert no runtime download path + assert all Tier-2 toggles default OFF. **Anti-drift:** audit runs on every TestFlight build before App Store promotion.

---

## §O — Benchmarks + tests strategy + in-app benchmarking decision

User asked: *"create valid benchmarks and tests to proovd everythng oike i want to engineering somethng in my app that benchmarks or idk try a goodway to benchmark if i need that but if i dont need it then no but yea."*

### O.1 Existing benchmarks substrate (already in main)

| Surface | What | Where |
|---|---|---|
| **R15 benchmark recorder** | per-PR criterion + os_signpost baselines | `benchmarks/results/*.json` (the 7 dirty ones in current `git status` are local re-runs; CD-009 says don't commit) |
| **Wave 2.6 morning-session bench** | runtime budget measurement | `scripts/run-morning-session.sh` (CI step) |
| **Perf budgets** | declarative budget enforcement | `scripts/check-perf-budgets.sh` + `docs/perf-budgets.toml` (CI step) |
| **Bundle size gate** | Patch 9: 600 MB ceiling on Epistemos.app | CI step in `.github/workflows/ci.yml:206-230` |
| **Graph FFI baseline bench** | criterion + os_signpost | `graph-engine/benches/graph_ffi_baselines.rs` |
| **Editor shell baselines** | R15 PR7 fixtures | `benchmarks/results/2026-05-01t*-r15-editor-shell-baselines-*.json` |

### O.2 Recommendation: NO new in-app benchmarking surface needed

The user's question "i want to engineering somethng in my app that benchmarks" — **answer: probably not.** Reasoning:

1. **Existing `benchmarks/results/*.json` + `scripts/check-perf-budgets.sh` is a CI-time benchmark.** This is the right shape for proving theorem invariants — you want the benchmark to run in CI on every push, not in the user-facing app.
2. **In-app benchmarking would compete with the user's actual workload.** Apple Silicon thermal budget is shared between the user's chat session and any benchmark task. Running benchmarks in-app would either degrade UX or give noisy results.
3. **The Diagnostic surface that DOES belong in-app** is observability of the existing invariants firing: Search Fusion health row + Editor bundle health row + Cognitive DAG stats panel (all already in `Epistemos/Views/Settings/`). These are NOT benchmarks; they're live readouts.

**Specific recommendation:** add a "Performance budget snapshot" row in Settings → Diagnostics that shows the most recent CI benchmark JSON contents (read at app boot from `Resources/perf-budgets-runtime.json` bundled at build time). The user sees the benchmark result without the app running it.

### O.3 What to add per W1–W26 (theorem-driven benchmarks)

| W slice | Bench/test required |
|---|---|
| W1 AnswerPacket emission | Grammar conformance ≥ 99% on 1k-question dev set; per-emission latency budget ≤ 5 ms |
| W2 ClaimKind 5-arm | Backward-compat replay test: existing v1 ClaimLedger replays under v2 schema with no drift |
| W6 Active-Support Atlas indexing (E1/H3) | ULP-equality test vs reference matmul over 10⁴ prompts; 5–18% latency improvement target on M2 Max |
| W7 Half-softmax post-not-pre (E4/H2) | ≤ 2 ULP drift over 10⁴ random vectors; equivalence Lean proof |
| W8 KV-Direct gate (E3/H7) | Round-trip equality on 10³ generation traces vs paged-attention reference |
| W12 T-MAC LUT (Tier-2 bundled) | Matches T-MAC reference output to FP16 tolerance on 100 prompts |
| W13 BitNet b1.58 (Tier-2 bundled) | End-to-end perplexity within 0.5 of reference on Lambada subset |
| W14 Sparse Ternary GEMM (Tier-2 bundled) | ≥ 4× speedup vs TCSC baseline on M2 Max at 50% sparsity (ETH paper claims 5.98×; verify on local hardware) |
| W17–W19 Lane 3 PCF | Each PCF passes its hardware falsifier on M2 Max with deterministic pass thresholds |
| W25 Hardware falsifier rig | Nightly on dev rig: runs every E1–E7 + H1–H17 + PCF-1…PCF-10 falsifier; posts results to ClaimLedger as TypedArtifacts |

### O.4 Test taxonomy

| Test type | Purpose | Where they live |
|---|---|---|
| **Unit tests** | per-function correctness | `agent_core/src/**/tests` (cargo test --lib) |
| **Integration tests** | cross-module behavior | `agent_core/tests/` (cargo test) |
| **Source-text guard tests** | catches refactor drift | `EpistemosTests/*.swift` (`loadMirroredSourceTextFile` pattern) |
| **Property tests** | invariant verification under random inputs | `agent_core/src/**/tests` using `proptest` (already used per `Cargo.toml`) |
| **Replay tests** | wire-format + Merkle parity | `agent_core/tests/epistemos_trace_e2e.rs` (CI gate B2) |
| **Doctrine tests** | §5.1–§5.4 gates | `agent_core/src/bin/epistemos_doctrine_lint.rs` (CI gate B1) |
| **Theorem falsifier tests** | E/H/PCF hardware falsifier on M2 Max | `tools/falsifier/` (W25; nightly dev rig) |
| **App Review compliance tests** | §2.5.2 audit | `tools/app-review-audit/` (W26; per-release gate) |
| **Perf budget tests** | runtime latency / memory bounds | `scripts/check-perf-budgets.sh` (CI step) |

---

## §P — What local files I need (answer: none for the architecture, possibly some for verification)

**Architecture finalization:** I needed nothing beyond what's already on disk. v5.2 + v4.2 + v5 source files in `/Users/jojo/Downloads/`, the HELIOS v4 preservation package in iCloud, and the user audit pasted in chat — that was sufficient.

**For specific verification work, I would need (in priority order):**

1. **Goodfire May 5, 2026 "Interpreting Language Model Parameters" page** — verified via your audit, but the URL or local copy would let me cross-reference exact page text vs the Q1-2026 web verification. Per your audit Patch 2 it's `[VERIFIED-WEB-2026-05-05]`; if you have the page locally, paste the URL or save as `~/Downloads/goodfire_2026_05_05.html` and I'll cross-reference.

2. **The `goodfire-ai/param-decomp` repo README** — if you've cloned it locally, point me at the path. Web search confirmed the repo exists per your audit; local clone would let me verify the exact 67M / 38912 / 9972 / 205 numbers against the README's experimental-setup section.

3. **The Bodnar et al. arXiv 2202.04579 PDF** — if you have it downloaded, the Bodnar Section 2 sheaf-Laplacian definition would let me write a more precise H11 Sheaf-Hodge spectral gap falsifier than the one in v5.2 §5.

4. **Any local notes on M5 Ultra / WWDC 2026 expectations** — v5.2 §I notes M5 Ultra as a placeholder. If you have notes on Apple's 2025-12 / 2026-Q1 announcements relevant to GPU Neural Accelerators or `_ANEClient` opening, those would let me sharpen the Lane 3 ANE direct-access risk language.

5. **(REMOVED per user instruction 2026-05-05)** ~~Hermes-3 Function Calling notes~~ — the user has explicitly excluded Hermes from all forward integration work. D.7 Schema (DOMINO + GBNF AnswerPacket) wiring uses DOMINO upstream + hand-written GBNF grammar ONLY. Any "local agent prompt builder" work for v5 W1–W26 lands in NEW non-Hermes-named code paths (see §R below). The 18 existing `Epistemos/LocalAgent/Hermes*.swift` files are flagged for separate-slice rename consideration in §R.

**None of these are blocking.** v2 plan + this finalization can pass canon lock without them. They would sharpen specific theorems (H11 / D.7) if available.

---

## §R — No Hermes anywhere (USER INSTRUCTION 2026-05-05)

**User instruction (verbatim):** *"no more hermes agent im not using hermes anymore at all so male sure that does not bleedinto what im doing."*

**Rule for HELIOS V5 integration:** Hermes is excluded from ALL forward work. This extends the prior 2026-05-05 Hermes subprocess removal to cover the entire Hermes namespace — the model-format prefix, the gateway-policy naming, the prompt-builder naming, ALL of it. Going forward:

- **No new code uses the Hermes prefix.** W1–W26 slices that need a local-agent prompt builder, gateway policy, capability registry, or command dispatch use a NEW non-Hermes name (e.g. `LocalAgentPromptBuilder`, `LocalAgentGatewayPolicy`, etc.).
- **No new doctrine references Hermes.** §A–§Q above scrubbed for forward-target references; only R0 historical-archive entries retain the Hermes name (per archive append-only rule).
- **No new tests reference `HermesPromptBuilder` / `HermesGatewayPolicy` / `Hermes*Command` / `Hermes*Registry`** as a substrate to extend. Existing tests against those files keep passing during the transition; new test work goes against the renamed substrate.
- **The "local agent" path remains canonical** — the path is what's load-bearing; the Hermes prefix is incidental. v5's D.7 Schema (DOMINO + GBNF AnswerPacket) lands as `agent_core/src/scope_rex/answer_packet.rs` + new Swift bridge, NEVER as an extension of `HermesPromptBuilder.swift`.

### 18 existing Hermes-prefixed files flagged for separate-slice rename (sign-off-gated)

The following 18 files in `Epistemos/LocalAgent/` still carry the Hermes prefix from when "Hermes" referred to the Hermes-3 model format. Per the canon promotion protocol, a multi-file rename is a destructive action that needs explicit sign-off — flagging here for a discrete rename slice rather than touching them in any HELIOS V5 W-slice:

| Current name | Proposed rename (sign-off needed) |
|---|---|
| `HermesPromptBuilder.swift` | `LocalAgentPromptBuilder.swift` |
| `HermesGatewayPolicy.swift` | `LocalAgentGatewayPolicy.swift` |
| `HermesCommandDispatcher.swift` | `LocalAgentCommandDispatcher.swift` |
| `HermesCapabilityRegistry.swift` | `LocalAgentCapabilityRegistry.swift` |
| `HermesPersonaCommands.swift` | `LocalAgentPersonaCommands.swift` |
| `HermesNotebookCommands.swift` | `LocalAgentNotebookCommands.swift` |
| `HermesUIDisplayCommands.swift` | `LocalAgentUIDisplayCommands.swift` |
| `HermesTodoCommand.swift` | `LocalAgentTodoCommand.swift` |
| `HermesThinkCommand.swift` | `LocalAgentThinkCommand.swift` |
| `HermesCalcCommand.swift` | `LocalAgentCalcCommand.swift` |
| `HermesCostCommand.swift` | `LocalAgentCostCommand.swift` |
| `HermesStatusCommand.swift` | `LocalAgentStatusCommand.swift` |
| `HermesTokensCommand.swift` | `LocalAgentTokensCommand.swift` |
| `HermesParsedCommand.swift` | `LocalAgentParsedCommand.swift` |
| (3 more `Hermes*` files in LocalAgent — full list at next sign-off slice) | (corresponding LocalAgent renames) |

**Rename slice scope (sign-off-gated separate from HELIOS V5):**

1. `git mv` each of the 18 files to its `LocalAgent`-prefixed name
2. `sed`-style rename of every `Hermes` symbol to `LocalAgent` equivalent in each file's contents (class names, struct names, enum cases, doc comments)
3. Update every importer + consumer in `Epistemos/` to use the renamed types
4. Update `EpistemosTests/` source-text guard tests (the `loadMirroredSourceTextFile` pattern) to point at renamed files
5. Update `CLAUDE.md` FILE MAP entries (currently says "HermesPromptBuilder.swift and HermesGatewayPolicy.swift in Epistemos/LocalAgent/ are canonical local-agent path")
6. Update any auto-memory references (the existing `feedback_hermes_is_real_agent.md` memory is already marked SUPERSEDED 2026-05-05; extend to cover the rename)
7. CI gate B5 + full xcodebuild test must pass after rename
8. Single commit OR sequence of small commits — choose at sign-off time

**Estimated scope:** 18 files renamed + ~40-60 import sites updated + ~10-15 test sites updated + 1-2 doc updates + auto-memory update. ~3-5 hours of careful work; substantial but bounded.

**Held for explicit sign-off** — do NOT execute as part of HELIOS V5 W-slices. The integration plan's W1–W26 do not depend on the rename; both can proceed in parallel without interference. Sign-off question: rename now (clean slate before HELIOS V5 W1 lands), rename in parallel (during W1–W26), or rename after (accept Hermes-prefix legacy for one more cycle)?

### Auto-memory update (companion to this rule)

The existing `feedback_hermes_is_real_agent.md` memory + `project_hermes_removal_2026_05_05.md` memory are extended by adding `feedback_no_hermes_anywhere.md` — codifying the user's 2026-05-05 instruction that Hermes is excluded from ALL forward work, not just the subprocess. Memory update committed as a separate slice immediately after this doc.

---

## §Q — Final lock confirmation

**HELIOS V5 Canon Lock v2 is sealed (architecturally) after namespace hardening.**

The raw archive is preserved as **R0** (append-only, at `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/`).

**Theorem canon (locked):**

- **E1–E7** Epistemos Core Theorems (§C above) — substrate-foundational
- **H1–H17** Helios Operational Claims (§D above) — build/canon claims; H1 is WBO-7 Master Inequality
- **PCF-1…PCF-10** Parameter Connectome Family (§B above) — Goodfire VPD integration

**Lanes (locked):** L1 MAS-add, L2 Pro-tier, L3 Research, L4 Substrate-independent (Reserved), L5 Vault. 11th classifier `helios` locked.

**Three-tier MAS rule (locked):** Tier 1 ULP-equivalent ON; Tier 2 model-file-changing FLAGGED OFF; Tier 3 runtime-mutating Vault-only.

**Work slices (state: candidate, held for sign-off):** W1–W26 with WRV proof + rollback per slice (§3 of v2 plan).

**Cognitive functions (D.1–D.8, §E above):** all 8 functions lane-assigned.

**Killer demos (§F above):** 4 demos with structural acceptance criteria.

**SCOPE-Rex full surface (§G above):** Core (τ + π + λ) SHIPPED; Pro (+δ + ρ) and Research (+κ + η) are NEW per their respective implementation slices.

**Six-tier memory (§H above):** L0–L7 + L_DRAM + L_SSD + L_SE; Core L0–L3 + L7 covered; L4–L5 Pro NEW; L6 Research opt-in NEW.

**Anti-drift mechanisms (§N above):** 10 mechanisms operationalize the canon promotion protocol for build time.

**Benchmarks + tests (§O above):** existing CI substrate is the right shape; recommend NO new in-app benchmarking surface (existing Diagnostics readouts are sufficient); per-W-slice bench/test requirements specified.

**Verified Floor:** `ac8c6d28`. Lock phrase: *"Five lanes, three tiers, seven-plus-three-plus-seven, one Monday."*

**Status:** architectural decisions = `state: canon`. Implementation slices = `state: candidate`, awaiting per-slice sign-off + WRV proof + rollback procedure exercised. Goodfire VPD substrate `[VERIFIED-WEB-2026-05-05]`; runtime acceleration (PCF-4 + PCF-9) stays candidate-only until kernels beat dense fallback.

**Local files needed from user: NONE for canon lock** (5 optional files in §P would sharpen specific theorems but are not blocking).

**Per-slice implementation work begins ONLY after explicit sign-off** per the canon promotion protocol (`docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`). The user's parallel-Claude engineering review can pressure-test §N anti-drift mechanisms + §O benchmark strategy independently. Codex verification can sign off W26 §2.5.2 compliance audit + W25 falsifier rig outputs.

*Lock sealed. Five lanes, three tiers, seven-plus-three-plus-seven, one Monday. Verified Floor: `ac8c6d28`. Architecture decided. Build held for sign-off.*

---

## Cross-references

- **PRIMARY SOURCE OF TRUTH (persisted in repo, both source-of-truth):**
  - `docs/fusion/helios v5 first.md` — 754-line v5 DEFINITIVE CANON LOCK with VERIFIED-AGAINST-RESEARCH-DOCS tags, validates the integration brief's substrate-presence assertions
  - `docs/fusion/helios v5 updated.md` — 625-line v5.2 TRULY FINAL with VERIFIED-WEB-Q1-2026 tags + 2 citation drifts caught + 10 PCF candidates + audit verdict
- **v2 plan (which this finalizes):** `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md`
- **v1 plan (superseded by v2):** `docs/HELIOS_V5_INTEGRATION_PLAN_2026_05_05.md`
- **v5.2 source canon (also at user-pasted message 2026-05-05):** content matches `docs/fusion/helios v5 updated.md`
- **v4.2 theorem hunt (also at /Users/jojo/Downloads/helios v4 updated.md):** content matches v4.2 sections in `docs/fusion/helios v5 first.md`
- **HELIOS v4 preservation package:** `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/` (21 source docs + 107 raw prompts; this IS the R0 archive)
- **Existing SCOPE-Rex Core (τ + π + λ):** `agent_core/src/resonance/{tau,pi,lambda,mod}.rs` + `Epistemos/Engine/ResonanceService.swift`
- **Existing Cognitive DAG:** `agent_core/src/cognitive_dag/{node,edge,storage,merkle,companions,macaroons,migration,dispatch,resonance}.rs`
- **Existing Monday-Move primitives (4 of 5):** `Epistemos/Models/MutationEnvelope.swift` + `agent_core/src/mutations/envelope.rs` + `agent_core/src/provenance/ledger.rs`
- **Doctrine:** `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`
- **Canon promotion protocol:** `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`
- **mmap audit:** `docs/MMAP_UTILIZATION_AUDIT_2026_05_05.md`
- **Codex Full Handoff:** `docs/CODEX_FULL_HANDOFF_2026_05_05.md`
- **Verified Floor commit:** `ac8c6d28` (views(anyview): doctrine §6 #6 enforcement — replace 16 AnyView violations with typed view-builders)
