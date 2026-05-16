# Master Fusion Backlog — No-Compromise, No-Drift
**Date:** 2026-05-13
**Author:** Claude (Opus 4.7, 1M context) for Jordan
**Status:** **CANON-CANDIDATE** — promote to floor after one Codex verification pass
**Scope:** Single congregated doc covering every concept across deterministicapp, Helios v2/v3/v5/v6.1/v6.2, SCOPE-Rex, ACS, Halo, Quick Capture, hybrid deterministic schemas, EML, ternary, Kimi deep research, GPT research, and every doctrine doc — pointing to each source so nothing drifts away again.
**Pair file:** `docs/CODEX_HANDOFF_2026_05_13_CHAT_TOOL_PARITY.md` — read after this one.

---

## 0. Why this doc exists

Jordan's complaint, verbatim: *"things get drifted once I have AI try to take resources from a bunch of different places and didn't congregate one Doc."*

This is that one doc. Every named pillar / kernel / operator / falsifier / doctrine / phase / track / theorem / invariant / state / verb / class / tier / signature / primitive across the research corpus is named here with:
- the **research doc(s) it came from** (so a future agent can re-read context),
- the **status today** against current `main` (MATCHES / DRIFTED / PARTIAL / DEFERRED / NOT-STARTED / SUPERSEDED),
- the **code anchor** if shipped, and
- the **next concrete move** if not.

No compromises. No collapsing similar-sounding things ("Shadow" appears 3 ways; "Helios" appears 5 ways — disambiguated below). No silent deferrals — every deferral has a row and a trigger.

---

## 1. Immutable rules of engagement (apply to Codex and every future agent)

1. **No drift via compression.** A compressed plan label is never enough. Always search the user's literal phrases AND semantic siblings before coding — per `LOCAL_CANON_FIRST_SPECIFICITY_PROTOCOL_2026_05_04.md`.
2. **The graph is protected.** Per Jordan 2026-05-13: *"graph looks stunning, it should be a protected part of the app, the most perfect thing in the app literally."* Chat code inside the graph inspector is in-bounds; rendering, layout, edges, hologram visuals are not.
3. **Tool ladders are first-class.** No tool route is canon-compliant unless its variant ladder honors `COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` (Deterministic Rust → Embedding → Classical → Small LLM → Mid LLM → Cloud).
4. **Defer is a first-class outcome.** Per `deterministicapp.md` §1.1 and `COGNITIVE_VARIANT_LADDER_DOCTRINE` §6. Returning "not found" / "low confidence" / "needs your input" is never a bug.
5. **Hot path is deterministic.** Z3 / Lean / SMT / LLM never run on the hot path. T0 type / T1 µs / T2 ms / T3 100ms / T4 background — per `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` Annex A.4.
6. **Capability lattice, not architecture fork.** One binary, three compile targets (`mas-build` / `pro-build` / `research`). Pro features are `#[cfg(feature = "pro-build")]` stubs in MAS, not deleted code. Per `MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md`.
7. **WRV is the ship test.** Wired + Reachable + Visible + Verified. Audit-register "PATCHED" is not enough.
8. **TEMP-FREE-TIER markers stay until $99 Apple Developer subscription clears.** App Groups, SMAppService, signing, etc.

---

## 2. Authority order (re-stated to lock against drift)

| Rank | Layer | Where |
|---|---|---|
| 1 | Current main + passing logs | `git log origin/main..HEAD`, build/test outputs |
| 2 | Repo authority | `CLAUDE.md`, `AGENTS.md`, `docs/MAS_RELEASE_MANIFEST_2026_05_13.md` |
| 3 | **This doc** + `docs/CODEX_HANDOFF_2026_05_13_CHAT_TOOL_PARITY.md` | new fusion floor |
| 4 | April 30 / May 1 fusion canon | `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`, `BUILDER_EXECUTION_PROMPT_2026_04_30.md` |
| 4.1 | May 2 fusion packet | `MASTER_RESEARCH_INDEX_2026_05_02.md` (1440L), `CANON_GAPS_AND_ADDENDA_2026_05_02.md`, `ALL_DOCS_INDEX_2026_05_02.md` |
| 4.2 | May 3 doctrines | `COGNITIVE_KERNEL_DOCTRINE`, `COGNITIVE_DAG_DOCTRINE`, `COGNITIVE_GENUI_DOCTRINE`, `MAS_FIRST_FOCUS_DOCTRINE`, `CANONICAL_RECOVERY_PLAN`, `EPISTEMOS_RECONCEPTUALIZATION` |
| 4.25 | Jordan executive-add (May 3) | `helios v3.md`, `mac store edition.md`, `hermes.md`, `deterministicapp.md`, `scope rex omega.md`, `ternary kernel.md` |
| 4.3 | May 4 doctrines + audits | `COGNITIVE_VARIANT_LADDER_DOCTRINE`, `COGNITIVE_WEIGHT_CLASS_DOCTRINE`, `HONEST_HANDLE_FFI_DOCTRINE`, `LIVE_FILE_COMPILER_DOCTRINE`, `HERMES_BRAND_DOCTRINE` (superseded), `LOCAL_CANON_FIRST_SPECIFICITY_PROTOCOL`, `CANONICAL_DRIFT_AUDIT`, `CANON_COMPLETENESS_AUDIT`, `CANONICAL_UNIFICATION_INVENTORY`, `POST_RECOVERY_SUBSTRATE_V2_PLAN`, `FIVE_LAWS_AND_PHASE_I` |
| 4.4 | Helios versions | `helios v5 first.md`, `helios v5 updated.md`, `helios v6.2.md`, `EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md`, `EPISTEMOS_V6_2_CANON_INTAKE_2026_05_07.md` |
| 4.5 | Quick Capture canon | `/Users/jojo/Documents/Epistemos-QuickCapture/PLAN.md`, `FINAL_SYNTHESIS.md`, `docs/fusion/salvage/from-vigorous-goldberg/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md` |
| 5 | Kimi research depth | `docs/fusion/jordan's research/kimis deep research/**` (donor depth) |
| 5.1 | Kimi-latest | `docs/fusion/research/kimi-latest/**` |
| 5.5 | External research depth | `docs/fusion/research/COMPASS_ARTIFACT_2026_04_26.md`, `compass_artifact_wf-*.md` |
| 6 | GPT Research | `docs/fusion/jordan's research/GPT Research/` (Cargo workspace skeleton + 24 .md) |
| 7 | User-authored | `docs/fusion/research/user-authored/{deterministicapp,helios v2/v3,scope rex,scope rex omega,ternary kernel,hermes,mac store edition,SCOPE_REX_GATE_REGISTER,CODEX_SCOPE_REX_SUBSTRATE_PROMPT}.md` |
| 8 | Worktree code | `~/Epistemos-laneA/` (601 commits), `~/Epistemos-RETRO/`, `inspiring-heisenberg`, `vigorous-goldberg`, `agent-a0550f9c`, `simulation` |

---

## 3. Concept Atlas — every named primitive (no drift commitment)

The atlas is the no-drift contract. If a concept appears in research and is missing here, this doc itself is wrong and needs a row.

### 3.1 Pillars and master inequalities

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **Five Pillars** (Wyner-Ziv side info / Babai-GPTQ / Nair ½-Lipschitz / Wang-Shi-Fox test-time-regression / Odrzywolek eml-operator) | `helios v3.md` §1, `epistemos_definitive_master.md` | DOCTRINE | `epistemos-research/src/v6_1_foundation.rs`, `v6_2.rs` |
| **WBO-6 master inequality** ‖Δlogits‖ ≤ ½·(T_W+T_K+T_R+T_Q+T_S+T_SE) | `helios v3.md`, `epistemos_capstone_unified.md` | DOCTRINE (target-only) | research substrate |
| **WBO-5 (compass) / WBO-7 reserved (v5)** — escalation ladder, kernel-only subform | `compass_artifact_wf-*.md`, `helios v5 first.md` | doc | — |
| **The Koan**: residual stream = prediction error = surprise gradient = Koopman mode = free-probability cumulant | `helios v3.md` §closing | doctrine | — |
| **SSM A-matrix as discrete-time Koopman operator (B2-M8) — Wang-Liang ICLR 2025 MamKO** | `helios v3.md` §VII.2 "Koopman operator theory" lines 132-142 | doctrine (NOT-STARTED in code) | — |
| **4 mechanical consequences of the SSM↔Koopman lift (B2-M8)** — see helios v3 §VII.2 lines 139-142 | (1) Pillar IV unification gains a Koopman reading — test-time-regression's regressor function class = Koopman observable basis choice; SSMs use polynomial/HiPPO bases · transformers use learned implicit basis induced by softmax attention. (2) WBO-6 bounds Koopman-eigenvalue drift under quantization (EV) — quantizing SSM A-matrix shifts Koopman eigenvalues; spectral perturbation bounded by Bauer-Fike applied to the Babai bound (clean composition of Pillars II and IV). (3) Attention sinks have Koopman-spectral characterization (C) — Cancedda 2024 (`arXiv:2402.09221`) shows sinks live in tail of unembedding spectrum = sink mode is eigenvector of attention-Koopman operator with largest absolute eigenvalue; Streaming-LLM (Xiao 2023 `arXiv:2309.17453`) preserves this mode and Helios L0 must too. (4) L_SE surprise gradient is a Koopman-mode update (C) — Titans inner-loop `‖M_{t-1} k_t - v_t‖²` is Koopman residual at observable `g=k_t`; gradient step is single-mode rank-1 update; **Titans IS streaming DMD (dynamic mode decomposition) of associative memory**. | `helios v3.md §VII.2` + Wang-Liang MamKO (ICLR 2025 spotlight, OpenReview `hNjCVVm0EQ`) + "Bilinear Input Modulation for Mamba" (`arXiv:2604.17221`) + Cancedda 2024 + Streaming-LLM | doctrine (NOT-STARTED in code) | — |
| **Seven canon thresholds** (KL<0.05, compression>10×, top-k>0.95, L4<5%, RAM≤12GB, ≥20 tok/s, SSM↔Tx≤5pp) | `helios v3.md`, `epistemos_definitive_master.md` | falsifier | — |
| **EML(x,y) = exp(x) − ln(y)** + grammar S → 1 \| eml(S,S) + terminal 1 required | `deterministicapp.md`, `eml_universal_operator.md`, `epistemos_definitive_master.md`, `EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` | NOT-STARTED (W1 floor work) | `epistemos-research/src/v6_1_foundation.rs` |
| **F-ULP-Oracle** (412 k log-sampled + 2,048 stress points, ≤2 ULP fp16, ≤90 s on M2 Pro) | `EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` | NOT-STARTED | gates `morph_eval_reduced.metal v0.1` |
| **eml-lean / oxieml** vendored read-only | same | NOT-STARTED | floor sequence |

### 3.2 Six-tier memory hierarchy

**Residency Governor (Layer 3: Compression Governance) — every residency decision is a compression decision.** The Governor assigns each capability / feature / cached state to a substrate tier (L0 → L_SE below) by solving the rate-distortion objective:

> **min**<sub>g, Z</sub> &nbsp; **E**[ *d*( X, g(Z) ) ] &nbsp;&nbsp;**s.t.**&nbsp;&nbsp; **I**(Z; X) ≤ R

where **X** is the source (vault embedding · session trace · model activation · KV row · provenance edge), **Z** is the tier-compressed representation, **g** is the reconstruction operator, ***d*** is task-relevant distortion, and **R** is the channel budget for the target tier (RAM bytes for L0/L1 · sketch bytes for L2 · SSD bytes for L3 · network tokens for L4 · adapter parameters for L_SE). This is the **Information Bottleneck** frame (Tishby 1999 *The Information Bottleneck Method*; Achille & Soatto 2018 *Emergence of Invariance and Disentanglement in Deep Representations*, arXiv:1706.01350): the optimal Z minimizes **I(Z; X) − β · I(Z; Y)** where **Y** is the downstream task signal. β tunes the compression / task-fidelity trade-off — small β = aggressive compression (push to L3/L4), large β = preserve fidelity (keep on L0/L1).

The six-tier table below is the **solution space** — each tier is a different (R, *d*) operating point on the rate-distortion curve. **Routing rule:** at residency time, compute the objective for each viable tier and pick the lowest-cost tier whose distortion stays under the downstream-task tolerance.

| Source                       | Typical X (size · variety)                                | Default tier under Governor |
|------------------------------|-----------------------------------------------------------|------------------------------|
| Active turn KV               | 1.5 GB at 32k ctx · model-specific                         | L0 (Exact Hot)               |
| Recent-session compressed KV | ~400 MB / hour · per-model                                  | L1 (Compressed Residual)     |
| Vault lexical+vector index   | ~80 MB / 5K notes · indexable                              | L2 (Shadow Sketch / Halo)    |
| Cold session traces          | ~10 MB / session · rare reuse                              | L3 (SSD Oracle)              |
| Cross-model knowledge        | ~10 KB / query · low-frequency                             | L4 (Network Cascade)         |
| LoRA / OFTv2 deltas          | ~5–50 MB per adapter · per-domain                          | L_SE (Self-Evolving)         |

**Why this row is load-bearing:** "Residency" appears 3× in this doc and elsewhere as a name-drop without the decision frame. Adding the objective function here routes every post-V1 eviction / tiering / cache-replacement / cloud-fallback decision through one objective rather than ad-hoc rules. Wave 9+ uses this Governor as the single dispatcher for KIVI/MiniKV/TurboQuant tier choices, NightBrain compaction decisions, and Live File compile-vs-evict choices. Source: `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_MASTER_ARCHITECTURE.md` §1 "Layer 3: Compression Governance"; PASS 2 gap audit B2-4 (resolved 2026-05-16).

| Tier | Name | Source | Status |
|---|---|---|---|
| **L0** | Exact Hot (KV in MTLBuffer storageModeShared) | `helios v3.md`, `helios_shadow_memory.md` | partial (live KV via MLX) |
| **L1** | Compressed Residual (Sherry 1.25-bit 3:4 sparsity, Huang arXiv:2601.07892) | same | NOT-STARTED |
| **L2** | Shadow Sketch (JL + CountSketch + FWHT, classical-shadow inspired) | `compass_artifact_wf-*.md`, `helios_shadow_memory.md`, `epistemos_capstone_unified.md` | PARTIAL — Halo Shadow shipped (Tantivy BM25 + usearch HNSW + RRF k=60), but **sketch ≠ shadow-sketch attention**; lexical shadow shipped, KV-shadow not |
| **L3** | SSD Oracle (NF4 IOSurface mmap, file-backed) | `helios v3.md` | NOT-STARTED |
| **L4** | Network Cascade (Hermes-4-405B style cloud) | `helios v3.md`, `hermes_gateway_architecture.md` | PARTIAL — cloud providers wired via URLSession; full cascade routing NOT-STARTED |
| **L_SE** | Self-Evolving (Titans-MAC + SEAL-DoRA nightly) | `epistemos_definitive_master.md` | NOT-STARTED |

### 3.3 The KV-Direct gate (Week-0 binary experiment)

| Concept | Source | Status |
|---|---|---|
| **KV-Direct** (Qasim et al. arXiv:2603.19664) — residual stream is bit-identical sufficient | `helios v3.md` "single sharpest move", `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` | NOT-STARTED — gate experiment (D_KL=0 / token_match=100% / RAM≥8× lower); collapses L2 to optional if passes |
| `Epistemos/Shaders/kv_direct_gate.metal` | filesystem confirms shader file exists | shader present, harness NOT-STARTED |

### 3.4 SCOPE-Rex (Sparse-feature · Claim-graph · Ontology · Proof · Execution + State Witness)

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **8-component acronym**: S+C+O+P+E + Rex kernel + State Witness Layer | `scope rex omega.md`, `scope rex.md`, `scope_rex_final_architecture.md` | PARTIAL | `agent_core/src/scope_rex/{answer_packet,btm_semantic,feature_observatory,ontology,produce,residency,witnessed_state,kernels/,kv/,metal/,retrieval/}.rs` |
| **State vector** S_t = (h_t, z_t, g_t, p_t, m_t, w_t, ℓ_t, u_t) | `scope rex omega.md` §2 | doctrine | — |
| **Constrained action objective**: argmin [λ_v V + λ_p P + λ_d D + λ_c C − λ_i I − λ_f F] | same | doctrine | — |
| **Sinkhorn-projected routing matrix** B* ∈ Birkhoff_n | same | NOT-STARTED | — |
| **Three-layer memory** (Working / Semantic active / Durable event history) | same | PARTIAL | OpLog + EventStore + AgentEvent live; semantic active layer partial via Halo + ClaimLedger |
| **Brain(τ) reconstruction rule** from materialized checkpoint + semantic deltas | same | NOT-STARTED | — |
| **4 product modes**: Verified Research Mode / Observatory Mode / Brain Time Machine / Harness Evolution | same | VRM canon-doctrine; Observatory partial; Brain Time Machine NOT-STARTED |

### 3.5 Resonance Gate / Resonance Signature

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **Σ-signature 7 fields {τ, δ, π, ρ, κ, η, λ}** | `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`, `hermes_gateway_architecture.md`, every Resonance doc | MATCHES — full Rust seam | `agent_core/src/resonance/{tau,pi,lambda,delta,rho,kappa,eta,mod}.rs` (8 files all present) |
| **τ ternary state** (-1 contradicted / 0 pending / +1 verified) | resonance docs | MATCHES | `tau.rs` |
| **τ Kleene K3 truth-table operators — `Truth::{not,and,or}` (B2-M7)** | `agent_core/src/resonance/tau.rs:27-65` + doctrine §4.1 pillar 1 + `docs/fusion/jordan's research/kimis deep research/ternary_spectral_architecture.md` §2.2 | MATCHES — full K3 operators shipped (`not` complements, `and` False-absorbing + Unknown-propagating, `or` True-absorbing + Unknown-propagating) | `tau.rs:27-65` |
| **Kleene K3 epistemic-honesty invariant — Unknown is load-bearing, never collapses to bool (B2-M7)** | `tau.rs:1-8` doctrine note: "Unknown is load-bearing — collapsing to bool would lose the distinction between 'we have evidence against' (False) and 'we haven't accumulated evidence yet' (Unknown), which downstream consumers (Evidence Supremacy Protocol, Sovereign Gate) depend on." | MATCHES — invariant enforced by enum shape (no `From<Truth> for bool` impl) | `tau.rs` |
| **Belnap FDE 4-valued extension — research-tier (Both/Contradictory beyond K3)** | Belnap 1977 *A Useful Four-Valued Logic*; ternary_spectral_architecture §2.2 footnote — handles concurrent-contradictory evidence by promoting Unknown to Both rather than collapsing to False | NOT-STARTED (V1 ships K3 only; Belnap is research-tier extension when concurrent-contradictory evidence stream is operationalized) | — |
| **π Kleene K3 claim classifier (9 classes)** | `helios v5 first.md` (Verified-Empirical/Mathematical/CodeInvariant, Plausible-Empirical/Causal, Speculative, Refuted-Empirical/Mathematical, Blocked-Safety) | PARTIAL (5-arm shipped, 9-arm doctrine target) | `pi.rs` |
| **λ residency band** | `scope rex.md` Orthogonal Residency | PARTIAL | `lambda.rs` |
| **5 directional operators** (Up/Down/Sideways/Inward/OnItself) on the claim graph | `ternary_reconceptualization.md`, `eml_universal_operator.md` | NOT-STARTED | — |
| **No τ=-1 reaches the user** invariant (cognitive immune system) | resonance docs | MATCHES — Resonance Gate principle |
| **Resonance Gate FFI** (compute_signature_core) | `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §2.2 (commits 06230e8d + 07e33fed) | MATCHES | `agent_core/src/bridge.rs::compute_signature_core` |
| **Verified Research Mode** UI labels (Verified / Plausible-but-unverified / Speculative / Blocked) | `helios v5 first.md` §1.5, `EPISTEMOS_FINAL_DOCTRINE` Annex A.13 | MATCHES (VRMLabelView + LatestAnswerPacketSink chip wiring) | `Epistemos/Views/Chat/VRMLabelView.swift`, `Epistemos/Models/AnswerPacket.swift` |

### 3.6 Sovereign Gate (action capability ladder)

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **5 action classes**: Trivial / Reversible / Sensitive / Destructive / Sovereign | `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.4 | MATCHES | `Epistemos/Engine/SovereignGate.swift` |
| **Single LAContext owner** (no per-call LAContext leak) | same | MATCHES | SovereignGate singleton |
| **Session Authority Token** (5 verdicts) | same | MATCHES | SovereignGate state machine |
| **`kSecAccessControlBiometryCurrentSet`** required (CVE-2025-31191 mitigation) | `macos_vault_system.md` | MATCHES | Keychain bridges |
| **LAContext + Touch/Face ID + Secure Enclave** layering | `macos_vault_system.md`, `EPISTEMOS_RESEARCH_LANDSLIDE.md` | MATCHES | SovereignGate.swift |

### 3.7 Variant ladder / No-LLM-First / hyper-deterministic schemas (Jordan's pre-Helios research)

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **Variant ladder A→B→C→D + Defer terminal** | `deterministicapp.md` §1 + §2 | DRIFTED + PARTIAL (Drift C) — route-capture only | `agent_core/src/route/variant_{a,b,c,b_classifiers,c_providers}.rs` |
| **Typed `VariantLadder<I,O>` + `LadderTier` + `LadderVariant` + `LadderError::OutOfOrder`** generalized seam | `COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` §5 | **ORPHAN** — seam exists, **zero live callers** | `agent_core/src/variant_ladder/mod.rs` (303 LOC) |
| **6-tier escalation**: Deterministic Rust → Embedding → Classical (NLI/BERT/distilled) → Small LLM 1.5-3B → Mid LLM 7-8B → Cloud | same doctrine | DRIFTED | — |
| **Confidence floors** FLOOR_T1 / T2 / T3 (≥0.85 / ≥0.75 / ≥0.70) | `deterministicapp.md` §2.0 | NOT-STARTED | — |
| **escalate_on_empty flag** (default false) | doctrine §6 | NOT-STARTED | — |
| **LadderLog → Provenance Console** | doctrine §5 | NOT-STARTED | — |
| **GBNF-constrained local SLM** as deterministic JSON producer | `deterministicapp.md` §1 | PARTIAL | `Epistemos/LocalAgent/LocalToolGrammar.swift` + MLXStructured + CMLXStructured + JSONSchema; soft-guidance fallback always-on |
| **Per-tool `gbnf()` at registration** | `deterministicapp.md` §2.0 | DRIFTED-but-equivalent — compiled per call instead of `&'static str` | `LocalToolGrammar.buildToolCallingPlan` |
| **`Tool` trait** with `Input: JsonSchema` + `Output: JsonSchema` | `deterministicapp.md` §2.0 | DRIFTED — `ToolSchema` carries JSON Schema but not via schemars macro | `agent_core/src/types.rs`, `agent_core/src/tools/registry.rs` |
| **`reasoning` field ≤256 tokens BEFORE answer field (Brief Is Better, Qwen 7B)** | `deterministicapp.md` §1, `helios v3.md` | NOT-ENFORCED | — |
| **Hybrid MD+JSON memory** with typed YAML/JSON frontmatter | `deterministicapp.md` §5 | PARTIAL — Epdoc + MutationEnvelope cover part; `epistemos.soul.v1`/`epistemos.skill.v1`/`epistemos.episode.v1`/`epistemos.semantic.v1` schemas NOT-STARTED |
| **Schema-validated writes + migration registry** | same | PARTIAL — MutationEnvelope validates; migration registry NOT-STARTED |
| **Hyper-Dynamic Schemas (Meta-Schemas that repair themselves)** | `acs_meta_layer.md` | NOT-STARTED | — |

### 3.8 ACS (Autopoietic Cognitive Stack)

| Concept | Source | Status |
|---|---|---|
| **7-scale recursion**: transistor → neuron → cell (SCOPE-Rex) → tissue → organ → organism → ecosystem | `acs_meta_layer.md`, `EPISTEMOS_MASTER_ARCHITECTURE.md` | doctrine only |
| **VSM S1-S5 recursion** (Operations / Coordination / Control / Intelligence / Policy) | same | doctrine |
| **Four homeostatic loops**: Reactive / Predictive (allostatic) / Adaptive (plastic) / Regenerative (autopoietic) | `acs_meta_layer.md`, `meta_homeostasis.md` | doctrine |
| **Kuramoto coupling** for agent sync (SiliconSwarm: 6.31× on 6 Mac Minis) | `acs_meta_layer.md`, `meta_resonance.md`, `redteam_discrete_continuous.md` | NOT-STARTED — red-team prefers discrete-time Kuramoto + gossip |
| **Markov blanket** as computational boundary; **ViableSystem** trait | `acs_meta_layer.md` | NOT-STARTED |
| **HealingAction** struct (diagnosis / prescription / prognosis / rollback / Z3 proof obligation) | `acs_meta_layer.md` | NOT-STARTED |
| **MAPE-K loop**, MRAC, STR, Lyapunov certificate, Control Barrier Function | `meta_homeostasis.md` | doctrine; some maps to OverseerProtocol |
| **Three-factor plasticity** (pre × post × modulator) as universal learning rule analog of EML | `eml_universal_operator.md`, `meta_homeostasis.md` | research-tier |

### 3.9 Halo / Shadow / Contextual Shadows / Eidos

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **Halo V1 stack** — 6-state FSM (dormant → watching → encoding → searching → available → open) | `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.3, `POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md` V2.2 | PARTIAL (full FSM not in code) | `Epistemos/Engine/HaloController.swift` |
| **Tantivy 0.22 BM25 + usearch 2.24 HNSW + RRF k=60** | `EPISTEMOS_FINAL_DOCTRINE` §4.3 | MATCHES | `epistemos-shadow` crate; `RustShadowFFIClient` honest-handle FFI |
| **Model2Vec encoder** | `EPISTEMOS_FINAL_DOCTRINE` §4.3 | NOT-STARTED | — |
| **Non-activating NSPanel surface** | doctrine §4.3 | NOT-STARTED | — |
| **Helios Shadow Memory** (sketch / residual / exact ShadowPage; Shadow-First Attention) — DIFFERENT from Halo Shadow | `helios_shadow_memory.md`, `epistemos_capstone_unified.md`, `compass_artifact_wf-*.md` | NOT-STARTED — KV-side shadow not the lexical search shadow |
| **Eidos** companion (paired with Halo per FINAL_DOCTRINE §4.3) | `EPISTEMOS_FINAL_DOCTRINE` Annex A | NOT-STARTED | — |
| **Contextual Shadows V0** (the original simpler surface) | `EPISTEMOS_FINAL_DOCTRINE` §2.2 floor | MATCHES (shipped 2026-04-28) | `RustShadowFFIClient.openAt`, `ShadowVaultBootstrapper` |

### 3.10 Cognitive DAG (Phase 8 — V2.1)

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **10 NodeKinds**: Note, Claim, Evidence, Skill, Tool, Procedure, Event, Companion, Capability, Model | `COGNITIVE_DAG_DOCTRINE_2026_05_03.md` | MATCHES (schema) | `agent_core/src/cognitive_dag/node.rs` |
| **10 EdgeKinds**: DerivesFrom, Contradicts, Invokes, WitnessedBy, AuthorizedBy, RecordedBy, OwnedBy, Deforms, Caches, AnnotatedBy | same | MATCHES (schema) | `edge.rs` |
| **BLAKE3 content addressing + Merkle root** | same | MATCHES | `merkle.rs` |
| **redb backend** (not SQLite/RocksDB) | same | MATCHES | `redb_store.rs`, `storage.rs` |
| **Phase 8.A scaffold → 8.B resonance propagation → 8.C macaroons → 8.D LoRA-light companions → 8.E migration → 8.F replay → 8.G linter → 8.H ship+paper** | same | 8.A-8.G LANDED (per CLAUDE.md FILE MAP), 8.H pending | `migration.rs`, `dispatch.rs`, `resonance.rs`, `macaroons.rs`, `companions.rs` |
| **Macaroon-style capabilities** (Birgisson NDSS 2014) | `helios v5 first.md`, doctrine | LANDED (orphan until Phase 8.H wires dispatch) | `macaroons.rs` |
| **LoRA-light companions** (50 × 50 MB LoRA + 1 × 4 GB base = 6.5 GB) | doctrine | LANDED (estimates) | `companions.rs` |
| **`.epbundle` replay verification** | doctrine | LANDED | `epistemos_trace verify-replay` CLI (`agent_core/src/bin/epistemos_trace.rs`) |
| **`epistemos-doctrine-lint` CLI** (DAG doctrine §5.1-§5.4 gates) | doctrine | LANDED | `agent_core/src/bin/epistemos_doctrine_lint.rs` |
| **4 DagMirrors** (Skills / Procedural / Provenance / Companion) | doctrine | LANDED | `migration.rs` |

### 3.11 Cognitive Kernel (Phases 1-7 — V1)

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **5 rules**: one agent loop / one memory store / one provenance ledger / one skill registry / one privilege boundary | `COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` | MATCHES | — |
| **`agent_core::agent_runtime`** (renamed from `hermes/` 2026-05-05) — skills + procedural_memory + self_evolution + tool-call parsing | doctrine + memory | MATCHES | `agent_core/src/agent_runtime/` |
| **WASM exec (Phase 3)** — wasmtime + Pyodide-WASM + QuickJS-WASM in `Resources/Wasm/` (~16 MB) | doctrine §6 | NOT-STARTED | — |
| **In-process bundled MCP (Phase 4)** — `omega-mcp::inproc::*` | doctrine §7 | PARTIAL | `omega-mcp` crate exists; inproc namespace pending |
| **Pro→Core migration matrix** (Hermes runtime / skills / procedural / WASM / bundled MCP / in-proc LSP all migrate Pro→Core; shell/Docker/native CLI stay Pro) | doctrine §10 | MATCHES (geometry) | Cargo features + `#[cfg(feature="pro-build")]` |
| **In-process LSP (V2.3)** — tower-lsp + tree-sitter | `POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md` V2.3 | LANDED 2026-05-05 | `agent_core/src/lsp_runtime/`, `Epistemos/Engine/RustLSPTransport.swift` |
| **`Tier { Core, Pro, Research, Both, All }` + `PolicyProfile { AppStore, Pro, Research }`** | doctrine | MATCHES | `agent_core/src/tools/registry.rs` |

### 3.12 GenUI dispatcher (T0 sub-track 4)

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **Schema-first dispatcher**: producer → typed `GenUIPayload` → static registry → renderer | `COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` | MATCHES (Stage A.4 2026-05-04) | `Epistemos/GenUI/` |
| **Schemas**: json, yaml, csv, codeBlock, table, markdown, fileEdit, keyValueTable, commandReceipt, actionPanel, errorReport, progressIndicator, capabilityList, searchResultSet, provenanceTrace | doctrine | PARTIAL — 7 base shipped, 8 new partial |
| **Determinism contracts**: content-based equality (id+createdAt excluded), sorted-keys canonical JSON, exhaustive `GenUISchema.allCases` test | doctrine §7.1 | MATCHES (Stage A.2 2026-05-04) | — |
| **`GENUI-DEFER:` markers** | doctrine §6 | MATCHES (0 markers today) | — |
| **G.1-G.6 phases** | doctrine | G.1-G.4 LANDED, G.5 (DAG integration) + G.6 (doctrine linter) pending |

### 3.13 Cognitive Weight Class (W1 → W2 Wave 7)

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **4 tiers**: Soft memory (0.00-0.30 trailing) / Preferred context (0.31-0.60 inline) / Strong project anchor (0.61-0.85 above-fold, advisory) / Policy-grade control vector (0.86-1.00 immutable system, ENFORCED) | `COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` | DRIFTED (Halo + RRF cover Semantic Gravity only; Policy Authority gone) | `agent_core/src/cognitive_weight/mod.rs` (seam only) |
| **5 gates to promote to policy_grade**: schema validation / capability subset / user-visible diff / signed plan hash / `cmd-shift-R` revocation | doctrine §3 | NOT-STARTED | — |
| **W1 (read-only metadata) → W2 (Wave 7 enforcement)** | doctrine | W1 partial; W2 awaits Wave 7 |
| **Semantic Gravity vs Policy Authority** boundary rule | doctrine §1 | NOT-ENFORCED |

### 3.14 Live File Compiler (Wave 7)

| Concept | Source | Status |
|---|---|---|
| **5 invariants**: `is_live` = intent not authority / capabilities from LivePlan not markdown / schema-gated / Compile-Verify-Mint G1-G4 / event-driven only | `LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md` | NOT-STARTED |
| **10-state machine**: Static → LiveCandidate → Compiled (signed) → Eligible → Running → {Paused/Completed/Quarantined} → Suspended → Eligible; Revoked = kill switch | doctrine §4 | NOT-STARTED |
| **LivePlan.v1 schema** (livefile_id BLAKE3, plan_hash signed local key, cognitive_weight block, triggers, eligibility, intent, prompt_for_changes) | doctrine §5 | NOT-STARTED |
| **Kani formal verification on state machine** | doctrine acceptance | NOT-STARTED |
| **NightBrain Wave 8 integration** | doctrine | NIGHTBRAIN partial — 10 task names registered, bodies NoOp |

### 3.15 Honest Handle FFI

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **Opaque refcounted Arc<T> handles + retain/release** (NEVER Box::into_raw + prose contract) | `HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md` | MATCHES | `epistemos-shadow`, `substrate-core`, `syntax-core` |
| **Live handles**: ShadowEngineHandle / StoreHandle / EventRingHandle / SyntaxDocumentHandle | doctrine | MATCHES | live |
| **`rustPanic` typed error mapping** | doctrine | MATCHES | — |

### 3.16 Helios kernels (V6.1 / V6.2 target-only)

| Kernel | Source | Status |
|---|---|---|
| `SemiseparableBlockScan.metal` (L=32K Core / 128K Stretch, chunk_size=256 canonical, ngroups=1 mandatory per state-spaces/mamba #647) | `helios v6.2.md` §1.4 Falsifier 1 | NOT-STARTED (file missing; target-only) |
| `LocalRecallIsland.metal` (32K Core 50 trials × 5 depths passkey ≥0.95) | §1.4 Falsifier 2 | NOT-STARTED |
| `PageGather.metal` baseline (BW_baseline_M2Pro ≈ 63-73 GB/s sustained on M2 Pro per arXiv:2502.05317; 70% of measured) | §1.4 Falsifier 3 | NOT-STARTED |
| `ControllerKernelPack.metal` (6 micro-kernels: write/forget/admit/route/norm/safety; ≤16 KB threadgroup each) | §1.4 Falsifier 4 | NOT-STARTED |
| `PacketRouter1bit.metal` (ternary router, P99 <100 µs dispatch) | §1.4 Falsifier 5 | NOT-STARTED |
| `InterruptScore.metal` (foundational; Swift CPU canonical in V6.2, Metal shadow for batches ≥64) | §1.4 Falsifier 6 | Swift CPU LANDED 2026-05-12 (`InterruptScoreCpu.swift`); Metal shadow NOT-STARTED |
| `morph_eval_reduced.metal v0.1` (gated by F-ULP-Oracle) | V6.1 intake | NOT-STARTED |
| **Interrupt-score equation** u_t = αH + β·WBO + γ·SheafResidual + δ·ToolNeed + ε·ConnectomeAlarm (0.30/0.25/0.20/0.15/0.10) | `helios v6.2.md` §1.4 | LANDED — Swift CPU; all 3 substrate observers wired |
| `WBOSubstrateObserver`, `SheafResidualSubstrateObserver`, `ConnectomeAlarmSubstrateObserver` | V6.2 progress | LANDED 2026-05-12 | `Epistemos/Engine/InterruptScoreCpu.swift` |
| **30-task calibration corpus** (7 LOW + 12 MED + 11 HIGH) | `helios v6.2.md` §1.5 | NOT-STARTED |
| **5 planes × 3 streams × theorem set**: State / Episodic / Assembly / Controller / Verification × MAS / Pro / Vault × T1-T17 / T25-T34 / T35-T44 / T-Interrupt | `helios v6.2.md` §1.3 | doctrine; PRESERVED |
| **Lean stack**: 4.29.1 + mathlib v4.29.0-rc6 + LeanCopilot CI-only + `lake exe cache get` always + sorry-budget ≤7/file, ≤266 total | `helios v6.2.md`, V6.1 intake | NOT-STARTED |
| **SchemaGen.lean** (Lean → Swift/Rust enum codegen, Hybrid 2-C; never full Lean→Rust extraction) | `helios v6.2.md` §S2.6 + §S3.1 | NOT-STARTED |
| **DeepSeek-Prover-V2-7B background worker** (app-quiesced ≥3 min idle + ≥8 GB free) | §S2.7 | NOT-STARTED |
| **Hardware lock M2 Pro 16 GB** (USER_ACTUAL_TARGET = M2Pro16Gb; M2 Max = scale-validation only) | V6.2 canon intake | MATCHES | `epistemos-research/hardware_profile.rs` |
| **HardwareProfile budget — INTENTIONAL divergence between HELIOS doctrine and Swift formula (B2-M5)** | HELIOS V6.2 doctrine + `Epistemos/Omega/Inference/HardwareTierManager.swift:101-102` | DIVERGENT-BY-DESIGN (drift-gate landed; alignment-decision V1.1) | `epistemos-research/src/hardware_profile.rs` `helios_swift_dual_budget_alignment_table` test |

> **§3.16 Hardware-profile divergence note (B2-M5, recorded 2026-05-16).** HELIOS V6.2 doctrine prescribes per-profile RAM ceilings (e.g. `M2Pro16Gb` → 10.5 GB "doctrine sweet-spot"). Swift's `HardwareTierManager.computeDualModelBudget` at `Epistemos/Omega/Inference/HardwareTierManager.swift:101-102` uses a uniform `tier.memoryGB * 0.60` formula → 9.6 GB on the V1 ship rig. The divergence is **intentional on `M2Pro16Gb`** (doctrine 10.5 GB > Swift 9.6 GB by ~1 GB) and is **gated by a fail-loud test** at `epistemos-research/src/hardware_profile.rs::helios_swift_dual_budget_alignment_table` (landed 2026-05-12) — the table breaks the build if either side changes silently. The Step-2 alignment decision (align Swift to doctrine vs keep divergence documented as canonical) is V1.1, NOT V1: loosening the budget on 16 GB rigs from 9.6 to 10.5 GB is a release-quality empirical-validation question, not a drive-by patch. **V1 ships the divergence as-canonical; V1.x decides alignment after 16 GB-rig memory-pressure telemetry from production.** See `docs/audits/HELIOS_SUBSTRATE_INVENTORY_2026_05_12.md §Tier S item #1` for the original drift-discovery + drift-gate landing context. See MAS_COMPLETE_FUSION §10 Compromises Recorded B2-M5 row for the V1/V1.1 alternatives the user can override to.

### 3.17 AnswerPacket emission ladder (V6.2 §S3.5)

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **AnswerPacket schema** (vrm, kind, body, cites, sigma) — schema frozen behind F-ULP-Oracle gate per V6.1 intake | `helios v6.2.md` §S3.5, V6.1 intake | LANDED (Swift) | `Epistemos/Models/AnswerPacket.swift` |
| **Rust production caller** `agent_core::scope_rex::produce::produce_turn_completion_packet` | V6.2 progress | LANDED 2026-05-12 | `agent_core/src/scope_rex/produce.rs` |
| **`bridge::produce_answer_packet_json` FFI** | V6.2 progress | LANDED | — |
| **`LatestAnswerPacketSink` + per-bubble `VRMLabelView` chip** | V6.2 progress | LANDED | `Epistemos/Views/Chat/MessageBubble.swift` line 477 |
| **State ladder**: implemented → emitted → populated → rendered → canonical-product-surface | V6.2 progress | rendered (chip lookups via sink) |
| **WitnessedState + SemanticDelta + ClaimKind (5-arm) + ClaimGraph** | `helios v5 first.md` | PARTIAL — 5-arm shipped; full SemanticDelta layer PARTIAL |
| **Cryptographically signed JSON-Lines `model.sig` analog** (V6.2 §S3.5) | `helios v6.2.md` | NOT-STARTED |

### 3.18 Provenance ledger (Phase 1)

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **ClaimLedger** (in-memory, retraction propagation, bounded-walk ≤16, deterministic BTreeSet) | `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §6, CLAUDE.md FILE MAP | MATCHES | `agent_core/src/provenance/ledger.rs` |
| **ReplayBundle + LedgerSnapshot + DagSnapshot** (schema v1 / v2) | same | MATCHES | `agent_core/src/provenance/replay.rs` |
| **MutationEnvelope** end-to-end | `EPISTEMOS_FINAL_DOCTRINE` §2.2, Drift Audit | MATCHES | `agent_core/src/mutations/{envelope,types,mod}.rs` + `Epistemos/Models/MutationEnvelope.swift` |
| **`LedgerEvent::RetractionPropagated`** | Drift Audit | MATCHES (commit c78deb17) | — |
| **Provenance Console** | `EPISTEMOS_FINAL_DOCTRINE` §4, audit reconciliation | MATCHES | `Epistemos/Views/Provenance/`, `ProvenanceConsoleProjectionService.swift` |
| **`epistemos_trace verify | verify-replay`** | CLAUDE.md | MATCHES | `agent_core/src/bin/epistemos_trace.rs` |

### 3.19 Capability lattice + XPC Mastery (V2.4 — paid-team-gated)

| Concept | Source | Status |
|---|---|---|
| **5-service XPC decomposition** (Main + VaultXPC + AgentXPC + ProviderXPC + WASMExecXPC) per-service entitlements + trust attestation + capability-token IPC | `mac store edition.md`, project memory project_xpc_mastery_doctrine | NOT-STARTED (paid-team-gated) |
| **Capability HMAC-SHA256 tokens** with bitflags (TOOL_USE etc.) + time-limited + caveat narrowing | `hermes_gateway_architecture.md` | NOT-STARTED |
| **Sandbox-within-sandbox WASM** (cs.allow-jit + Winch single-pass + pulley-interpreter fallback) | `COGNITIVE_KERNEL_DOCTRINE` §6 | NOT-STARTED |
| **Secure Enclave attested capabilities** | XPC doctrine | NOT-STARTED |
| **IOSurface zero-copy** | XPC doctrine | NOT-STARTED |
| **App Group `group.com.epistemos.shared`** | `Epistemos-AppStore.entitlements` header | TEMP-FREE-TIER REMOVED (paid-team-gated restoration) |
| **`arena.dat` file-backed mmap in App Group container** | `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md`, `plan.md` | NOT-STARTED |

### 3.20 NeMoCLAW / OpenCLAW multi-claw (research-tier MAS)

| Concept | Source | Status |
|---|---|---|
| **6-factor agent model**: Loop / Tools / Memory / Context / Governance / Orchestration | `mas_architecture_research.md`, `epistemos_mas_release.md` | doctrine |
| **4 orchestration topologies**: Orchestrator-Worker / Hub-and-Spoke / Mesh / Pipeline | same | doctrine |
| **Trust tiers**: Cloud / Specialist / Local / Verified | same | doctrine |
| **Markdown-frontmatter agent definitions** (Claude Code pattern) | same | NOT-STARTED |
| **GodMode workflows** (NewFeature / BugFix; dual-gate via git worktrees) | same | NOT-STARTED |
| **Evidence Supremacy Protocol** (inter-agent + cloud conflict resolution) | `mas_gate_upgrade.md`, `epistemos_capstone_unified.md` | NOT-STARTED |
| **Arbiter Agent Selection** | `mas_gate_upgrade.md` | NOT-STARTED |
| **Echo Chamber Prevention** | `mas_gate_upgrade.md` | NOT-STARTED |
| **Resonance Gate (multi-agent)** — agent registration score (40% success + 30% contradiction win + 20% peer attestation + 10% uptime) | `mas_gate_upgrade.md` | NOT-STARTED |
| **Workflow templates**: Research / Implement / Refactor | same | NOT-STARTED |
| **Capability-grant HMAC tokens + zero-copy arena IPC + mach-port signaling** | `hermes_gateway_architecture.md`, `plan.md` | NOT-STARTED |
| **VaultGatedSwarm** (vault unlock spawns agents; lock kills all) | `epistemos_mas_release.md`, `epistemos_capstone_unified.md` | NOT-STARTED |

### 3.21 Ternary core (research-tier V3)

| Concept | Source | Status |
|---|---|---|
| **Three backends parallel**: DenseMlxBackend (baseline) / BitnetReferenceBackend (truth) / TernaryMetalBackend (breakthrough) | `ternary kernel.md`, `ternary_spectral_architecture.md` | NOT-STARTED |
| **Decode-first ternary** (optimize token-by-token first; prefill after) | `ternary kernel.md` | NOT-STARTED |
| **Three-layer ternarity**: Numerical {-1,0,+1} weights / Epistemic {falls,waiting,fits} claim states / Operational {promote,hold,reject} action gates | `ternary_reconceptualization.md` | doctrine |
| **Kernel portfolio order**: ternary_pack → block-scaled ternary GEMV → fused ternary_proj_residual → fused RMSNorm+proj → ternary KV fingerprint → live activation tap → steering delta apply | `ternary kernel.md` | NOT-STARTED |
| **Go/no-go bar**: decode tok/s ≥1.5× dense / peak mem ≥2× reduction / ≤5% PPL regression / 0 silent corruption / rollback <250 ms / freeform median <120 ms | same | falsifier |
| **Sherry 1.25-bit 3:4 sparsity** (Huang arXiv:2601.07892) | `helios v3.md` | NOT-STARTED |
| **NestQuant / Leech_24 / E_8 lattice second-moment G** (G(E8)=0.0717, G(Leech)=0.0658) | `helios v3.md`, `epistenos_build_plan.md` | NOT-STARTED |
| **Free Random Projection** (Hayase-Collins-Inoue arXiv:2504.06983) | `helios v3.md` | NOT-STARTED |
| **Live Freeform** (debounced 50-100 ms ghost-layer evolving gist) | `ternary kernel.md` | NOT-STARTED |
| **TernaryControlRoomView / TensorHexView / KernelTimelineView / ImplantPanelView** | `ternary kernel.md` | NOT-STARTED |
| **"Fragile parameters stay dense"** (embeddings, lm_head, norm scales, attention softmax, rope/trig, steering deltas, safety side channels) | same | doctrine |
| **BiometricWriteGate** | `ternary kernel.md` | NOT-STARTED |

### 3.22 Continual learning (corrected OSFT / PSOFT / coSO / DSC + QDoRA path)

| Concept | Source | Status |
|---|---|---|
| **OSFT** (Sculpting Subspaces; SVD top-k preserved + complementary trainable; sequential SVD recompute; ~20 tasks before saturation) | `osft_deep_research.md`, `osft_psoft_coso_fusion.md`, `EPISTEMOS_FINAL_DOCTRINE` Annex A.6 | research-tier; NOT-COMPATIBLE with 4-bit/8-bit (use **OFTv2** for 4-bit NF QLoRA path) |
| **PSOFT** (Principal Subspace OFT; Cayley parameterization; r(r-1)/2 + 2r params; bf16/bf32 only) | `psoft_deep_research.md`, `osft_psoft_coso_fusion.md` | research-tier |
| **coSO** (Continuous Subspace Optimization; Frequent Directions sketching; replaces 60-120 s SVD recompute) | `coso_deep_research.md`, `osft_psoft_coso_fusion.md` | research-tier |
| **OFTv2** (4-bit NF QLoRA-compatible orthogonal fine-tuning) — the real path for QLoRA | `osft_psoft_coso_fusion.md` | research-tier |
| **QDoRA / LoftQ / QA-LoRA / PiSSA** (red-team alternatives) | `redteam_qlora_alternatives.md` | research-tier |
| **DSC (Dynamic Subspace Composition)** (magnitude-gated simplex over PSOFT_k) | `osft_psoft_coso_fusion.md` | research-tier |
| **Forensic correction**: Annex A.6 of `EPISTEMOS_FINAL_DOCTRINE` says "use QOFT/QDoRA/QPiSSA, NOT OSFT/PSOFT/coSO with QLoRA" | doctrine | DOCTRINE |
| **HCache** (1.93× TTFT, 5.73× vs recompute) + **KVCrush** (4× cache, <1% accuracy drop) + **MiniKV** (2-bit, 86% compression, >98.5% accuracy) + **TurboQuant** (≥6× KV reduction, 3-bit no-train) | `scope_rex_final_architecture.md`, `scope rex.md` | research-tier |
| **MLA (Multi-Head Latent Attention) + TransMLA retrofit** — DeepSeek's low-rank KV compression with **decoupled RoPE**. Projects K/V to a much smaller latent space `c_kv` (typically 4-16× compression vs full K/V cache), then reconstructs per-head K/V via per-head down-projections at attention time. Decoupled RoPE = positional encoding stays on the un-projected query path so latent K/V is rotation-invariant and reusable across positions. **TransMLA retrofit** = the technique for converting an existing MHA / GQA / MQA model to MLA via QK-OV decomposition without full retraining (paper-cited as "TransMLA"). Composes orthogonally with KIVI/MiniKV/TurboQuant — those compress the cache *values*, MLA changes the *representation* the cache stores. **Apple Silicon implication**: 4-16× KV reduction enables longer context windows within the V1 16GB hardware lock without per-step quantize/dequantize cost. **NOT-STARTED in code** — `rg "MLA|TransMLA|MultiHeadLatentAttention"` returns zero hits across `agent_core/src/` + `Epistemos/`. Source: `docs/fusion/jordan's research/uasa.agent.final.md §3.3` + PASS 1 H-8. | `uasa.agent.final.md §3.3` + PASS 1 H-8 | research-tier (NOT-STARTED) |
| **Titans-MAC** + **SEAL-DoRA** + immutable Qwen3-8B base | `helios v3.md` | research-tier |
| **Universal Plasticity Gate** Δw = η · sgn(z_pre) · relu_θ(z_post) · sgn(δ) | `epistemos_final_master_specification.md` | research-tier |
| **Never Retrain** framework (frozen base + Fast Weights + LoRA bank + CountSketch gradient archive) | `continual_learning_online.md` | research-tier |
| **GRPO (Group-Relative Policy Optimization)** — local RL training path with **rule-based rewards** on Apple Silicon. Per `docs/fusion/jordan's research/uasa.agent.final.md §6.2.3`: groups multiple sampled trajectories per prompt, scores each against a rule-based reward function (no human-preference dataset needed), computes group-relative advantages, updates via policy gradient. MLX-Swift pseudocode in the source spec. **Pairs with OFTv2 QLoRA path** (line 352) — OFTv2 provides the parameter-efficient adapter, GRPO provides the rule-based-reward signal that drives the adapter updates. Distinct from supervised fine-tuning (no labeled targets) and from RLHF (no reward model). Currently name-dropped at `agent_core/src/scope_rex/residency.rs:81` as a "GRPO prior distilled into the policy gradient" but **NOT-STARTED in actual training infra**. PASS 1 H-7. | `uasa.agent.final.md §6.2.3` + scope_rex residency.rs:81 + PASS 1 H-7 | research-tier (NOT-STARTED) |

### 3.23 Skill / procedural memory / self-evolution

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **Voyager skill library** (executable code + NL descriptions) | `deterministicapp.md`, `landslide_dim05_self_modification.md` | LANDED | `agent_core/src/agent_runtime/` |
| **A-MEM atomic notes** + memory-evolution link-walk (arXiv:2502.12110) | `deterministicapp.md` | NOT-STARTED |
| **`corrections.jsonl`** user-correction training signal | `deterministicapp.md` | NOT-STARTED |
| **Background nightly re-routing pass** | `deterministicapp.md` | NOT-STARTED |
| **CoALA trichotomy**: episodic / semantic / procedural | `deterministicapp.md` §2.3 | doctrine |

### 3.24 NightBrain (10 canonical tasks — Wave 8)

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **10 task names registered** (per Drift Audit) | `LIVE_FILE_COMPILER_DOCTRINE` integration; CANONICAL_DRIFT_AUDIT row | PARTIAL — bodies are NoOp placeholders | `agent_core/src/nightbrain/live.rs`, `Epistemos/.../NightBrainLiveRegistry` |

### 3.25 A2UI catalog (~25 components)

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **NoteCard seed (1 of ~25)** | Drift Audit | PARTIAL | `Epistemos/A2UI/Catalog.swift`, `Components/`, `Validator.swift` |
| **schemars-derived Rust JSON Schema + closed_catalog_component_names + A2UICatalogTests** | Drift Audit | MATCHES |
| **24 components NOT-STARTED** (e.g., Table, Markdown, Chart, ProgressBar, KeyValueGrid, CapabilityChip, ProvenanceTrace, etc.) | Drift Audit | NOT-STARTED |

### 3.26 KV implantation + Glass Pipe + weight surgery (Pro / Research tier)

| Concept | Source | Status |
|---|---|---|
| **UMA-direct memory inspection** (MTLBuffer storageModeShared zero-copy CPU/GPU/ANE) | `EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md` | NOT-STARTED |
| **KVCacheImplanter / KVCacheSnapshot / LayerKVSnapshot** | same | NOT-STARTED |
| **AttentionManipulator** (force/forbid via shared-memory logits) | same | NOT-STARTED |
| **WeightPatcher** (qProj/kProj/vProj/oProj/gate/up/down/embed/lmHead) | same | NOT-STARTED |
| **ActivationInterceptor "Glass Pipe"** (injected Metal compute kernel + ring buffer + atomic write index) | same | NOT-STARTED |
| **Hex-dump viewer + xctrace Metal System Trace pipeline** | same | NOT-STARTED |
| **Honest boundaries**: cannot see ANE SRAM / per-core / instruction trace / firmware | `EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT.md` | DOCTRINE |
| **SAE-based Cognition Observatory** (real Glass Ball — encoder-only forward pass via MPSMatrixMultiplication; ActiveConcept stream) | same | NOT-STARTED |
| **ANE telemetry** (IOKit/SMC via `macmon`/`asitop` channels; power/freq/derived-utilization) | same | NOT-STARTED |

### 3.27 Simulation Mode v1.6 → v1.7+ (Stage E + V2.5)

| Concept | Source | Status | Anchor |
|---|---|---|---|
| **3 placements**: Landing Farm (default) / Graph Live Theater / Notes Sidebar Skin | `docs/fusion/simulation/DOCTRINE.md` (1982L) | partial UI; LandingFarmView LANDED per `SIMULATION_MODE_V16_SUMMARY.md` |
| **Body grammars**: block_compact / block_wide / sage / orb / Hermes Snake (graph faculty, z+1 plane, NOT a citizen) | character-dna/*.md | doctrine |
| **13-state animation machine**: idle / walk / think / speak / tool / spawn / handoff_give / handoff_receive / retrieve / error / recover / success / sleep | DOCTRINE.md | doctrine |
| **16 invariants** I-1 to I-16 (I-15 = production hot path no AnyView no string-keyed dispatch; I-16 = bit-perfect pixel rendering, no smoothing ever) | DOCTRINE.md, CANONICAL_UNIFICATION_INVENTORY | DOCTRINE |
| **Tamagotchi specificity-recovery**: 50 sprites / 24 emotes / 60 FPS on M-series; deterministic idle-walk; reduce-motion static pose | `CANON_COMPLETENESS_AUDIT_2026_05_04.md` | doctrine |
| **CompanionModel lifecycle**: create / delete / restore wizard with cosmetic config + breathing animation; @MainActor @Observable | `SIMULATION_MODE_V16_SUMMARY.md` | LANDED v1.6 Slice 3 (~3,084 LOC, 9 Swift files) |
| **TimelineView(.periodic) 30 Hz breathing** (not Timer.publish().autoconnect — pauses when offscreen) | same | LANDED |
| **AgentProvenanceEvent vocabulary** | same | LANDED PR34 |
| **App Group JSON** persistence | same | TEMP-FREE-TIER blocked |

### 3.28 Hermes (positioning, not brand)

| Concept | Source | Status |
|---|---|---|
| **L7 Cloud Gateway Agent**, non-authoritative; Epistemos owns durable memory/permissions/provenance/planning/trust | `hermes.md`, `hermes_gateway_architecture.md`, `EPISTEMOS_FINAL_DOCTRINE` Annex A.8 | doctrine |
| **Control plane (typed XPC messages) vs data plane (xpc_shmem / IOSurface / FD / mmap)** | `hermes.md` | NOT-STARTED |
| **Zero-copy mmap CloudArena** (16 req / 16 resp slots, ~200 KB; CloudRequest 4.2KB / CloudResponse 8.2KB) | `hermes_gateway_architecture.md`, `epistemos_capstone_unified.md` | NOT-STARTED |
| **Mandatory low-trust signature on cloud claims** (τ=0 Pending / δ=Sideways / π=Composite / ρ≤0.3 / κ≤0.1 / η=Edge / λ=L7) — never Prime | `hermes_gateway_architecture.md` | NOT-STARTED |
| **CapabilityGrant** HMAC-signed time-limited tokens | same | NOT-STARTED |
| **Pro Tunnel isolation** (sidecar binary only in Pro build) | same | NOT-STARTED |
| **Hermes UI overlay** | `HERMES_BRAND_DOCTRINE_2026_05_04.md` | SUPERSEDED 2026-05-05 — fully purged |
| **InterVariable + JetBrains Mono OFL** font tokens | doctrine | InterVariable lookup survives |

### 3.29 Quick Capture (standalone canon)

| Concept | Source | Status |
|---|---|---|
| **Single intake surface** with progressive disclosure | `deterministicapp.md`, `/Users/jojo/Documents/Epistemos-QuickCapture/PLAN.md`, `FINAL_SYNTHESIS.md`, `docs/fusion/salvage/from-vigorous-goldberg/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md` | partial (Quick Capture view LANDED; ~6 OTHER salvage subdirs untriaged per memory) |
| **Variant ladder for routing** (centroid → LLMClassify → ConceptSearch → Defer) | `deterministicapp.md` §3 + QC IMPLEMENTATION_PLAN §1.4 | DRIFTED (route-capture reference impl only) |
| **`vault.quick_capture` 4-variant ladder** | `deterministicapp.md` §2.1 | NOT-STARTED |
| **Variant Ladder Tier-1 backstops** (`agent_core/src/route/variant_b_classifiers.rs::keyword_overlap_picks_best_match` + `keyword_overlap_defers_below_floor` reference pattern) | doctrine §4.2 | MATCHES |
| **25 Quick Capture salvage files (5,656 LOC)** triaged into Tier A/B/C/D per memory project_quick_capture_salvage_triage | memory | partial (Tier A integration-ready; Tier C DAG-blocked; Tier D Pro-only) |

### 3.30 Vault doctrine

| Concept | Source | Status |
|---|---|---|
| **LocalAuthentication LARight + LAContext** (single owner) + Touch ID + Secure Enclave | `macos_vault_system.md`, FINAL_DOCTRINE §4.4 | MATCHES |
| **`kSecAccessControlBiometryCurrentSet`** | `macos_vault_system.md` | MATCHES |
| **Security-scoped bookmarks** (.withSecurityScope; CVE-2025-31191 mitigation) | same | MATCHES |
| **Two-tier cache**: biometric → vault master key → per-file ephemeral | `macos_vault_system.md` | NOT-STARTED |
| **Bookmark integrity SHA-256 monitoring** | same | NOT-STARTED |
| **NSCoreDataCoreSpotlightDelegate / Spotlight integration** | same | MATCHES | `SpotlightIndexer.swift` |
| **ModelActor for background indexing** | same | MATCHES (`@ModelActor actor VaultIndexActor`) |
| **SwiftData `#Index` macro** | same | partial |

### 3.31 UI / UX / Brand (V2.6)

| Concept | Source | Status |
|---|---|---|
| **One composer / two modes (Chat + Agent) / separate Effort axis / Tools-as-capabilities** | `EPISTEMOS_FINAL_DOCTRINE` §4.0 | MATCHES |
| **Pixel-vs-Tactical posture** | same | doctrine |
| **Cognitive Weight slider** | same | NOT-STARTED |
| **Freeform Pulse + Residency Rail** | same | NOT-STARTED |
| **Provenance Console** | same | MATCHES (shipped 2026-05-04 at ad6280cf per memory) |
| **NousResearch SVG art + Inter + JetBrains Mono OFL fonts** | `HERMES_BRAND_DOCTRINE` (superseded but fonts survive) | InterVariable only |
| **8-setting irreducible-minimum UX** | `deterministicapp.md` | NOT-STARTED |
| **Landing greeting hero loop** (Greetings/Researcher ↔ Click anywhere/to start a conversation) | MAS Release Manifest | MATCHES |
| **Per-theme identity fonts**: Classic = CoralPixels/RetroGaming, Platinum = MatrixTypeDisplay, Ember = ColorBasic-Regular + ChonkyPixels H1-H3 + MatrixType caption | MAS Release Manifest | MATCHES |

### 3.32 Code-side hardening floor

| Concept | Source | Status |
|---|---|---|
| **`harden_cli_subprocess` + 10-var allowlist + 24-vector denylist + kill_on_drop + process_group(0)** | `agent_core/src/security.rs` | MATCHES |
| **`mas_runtime_preflight`** (forbids bash/terminal/process/cron + bounds mutating tools to memory + ssm_resume) | `agent_core/src/tools/registry.rs` | MATCHES |
| **API keys in macOS Keychain** (SecItemAdd / SecItemCopyMatching), NEVER UserDefaults | CLAUDE.md | MATCHES |
| **Sandbox entitlement minimal MAS set** (app-sandbox / allow-jit / network.client / files.user-selected.read-write / files.bookmarks.app-scope) | `Epistemos-AppStore.entitlements` | MATCHES |
| **MAS bundle leak audits**: ZERO subprocess strings + ZERO Pro symbols | `docs/MAS_RELEASE_MANIFEST_2026_05_13.md` §3 | MATCHES (verified 2026-05-13) |
| **Subprocess hardening on 10+ sites** | CLAUDE.md FILE MAP | MATCHES |

### 3.33 Artifact Identity + Provenance Block (Wave 3.2 cognitive-artifact spine)

| Concept | Source | Status |
|---|---|---|
| **`ArtifactKind` 7-variant enum** (ProseNote=1 · Document=2 · RawThought=3 · Source=4 · Code=5 · Run=6 · Output=7) — `#[repr(u8)]` + snake_case serde + stable numeric ids + `from_id`/`as_str`/`ALL` static slice | `agent_core/src/artifacts/kind.rs:29-110` per `COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §2 + `T+4_cognitive_artifact_spine_deliberation_20260427.md` §E | MATCHES — landed; `cargo test --lib artifacts` => 19 passed |
| **`ArtifactHeader`** (`id` opaque ULID/UUID-decided by caller · `kind` · `schema_version: u32` · `created_at`/`updated_at` u-ms · `title` · `content_hash` BLAKE3 hex with optional `"blake3:"` / `"sha256:"` prefix · `provenance: ProvenanceBlock` · optional `metadata: BTreeMap<String,String>` for forward-compat) — mirrors Swift `EpdocManifest` byte-equal via `JSONEncoder.outputFormatting = .sortedKeys` + drift gate `EpistemosTests/ArtifactProvenanceParityTests.swift` | `agent_core/src/artifacts/header.rs:34-112` + Swift mirror at `Epistemos/Models/EpdocManifest.swift:92` | MATCHES |
| **`ProvenanceBlock`** (`producer: Producer` enum {`Human` / `Agent { run_id, agent_id }` / `Imported { origin }`} · `derived_from: Vec<ArtifactRef>` for graph lineage · convenience constructors `::human()`/`::agent()`) + **`ArtifactRef`** (artifact-id + kind + optional title, for cross-artifact references) — re-exported from `mod.rs:42` | `agent_core/src/artifacts/provenance.rs:88-145` | MATCHES |
| **Test parity**: 19 unit tests across `kind` + `header` + `provenance` (round-trip · wire-format · variant exhaustiveness · `from_id` rejection of unknown ids · ProvenanceBlock human + agent variants · derived_from chain) | `agent_core/src/artifacts/{kind,header,provenance}.rs::tests` | MATCHES |
| **FFI exports**: deferred — Swift mirror lives independently in `Epistemos/Models/EpdocManifest.swift`, parity enforced by `ArtifactProvenanceParityTests.swift`. UniFFI surface lands when Swift needs to construct artifacts on the Rust side (no current caller). The audit's "+ FFI exports" requirement is downgraded to "parity-test-gated mirror" per current architectural choice — not a regression. | `agent_core/src/artifacts/mod.rs` + parity test | DEFERRED — by design, not by omission |
| **Why it matters**: Raw Thoughts (Slice 1, 80% done) and `.epdoc` packages need stable artifact identity so sessions reference artifacts by id rather than file path. Re-indexing must not break lineage. ProvenanceBlock makes "who/what produced this and from what?" answerable for every artifact in the graph. | PASS 2 gap audit B2-2 §1 | MATCHES |

### 3.34 Instant Recall — binary-HNSW + Mamba-2 state injection (Wave 9.33+ / Phase R+)

Sub-3ms contextual recall across the full vault via three layered moves: binary-quantized embeddings · ARM-NEON Hamming HNSW · Mamba-2 hybrid state prefill of the writing-session model. Distinct from the L2 Shadow Sketch (vault search) and L4 Engram (B2-M12 static-fact hash) — this is the **typing-cursor companion**: while the user types, the top-5 contextually-relevant notes surface in the sidebar within 3ms, and on the first agent turn the relevant top-3 are prefilled as Mamba hidden state (~50ms) so the model opens with the user's context already loaded.

| Concept | Source | Status |
|---|---|---|
| **Binary quantization (1 bit / dimension)** + ARM NEON Hamming search — `usearch` HNSW with binary distance · custom NEON kernel ~350 GB/s · full 128 MB scan ~0.37 ms · two-phase Hamming → float32 rescore ≤3 ms total | `docs/_consolidated/60_deferred_research/INSTANT_RECALL_ARCHITECTURE.md` §"Key Numbers" + Phase 1 (Ω18) | NOT-STARTED |
| **Model2Vec encoder** — Rust backend, no GPU, <1 ms per paragraph; ties into Halo lexical/embedding pipeline without touching the canonical `vault.search` ladder | source §Phase 1 + §"Encoding Strategy (Tiered)" | NOT-STARTED |
| **Mamba-2 hybrid state injection** — tokenize top-3 retrieved notes → forward pass → save hidden state → use as starting context for writing-session model · ~50 ms prefill on M2 Pro · benchmarks accuracy with/without state load | source §Phase 2 (Ω19) + `epistemos_resonance_gate.md` Mamba-2 hybrid story | NOT-STARTED |
| **LoRA on Mamba projection layers (`in_proj` / `x_proj` / `dt_proj` / `out_proj`)** — nightly fine-tune on personal notes corpus via existing ODIA pipeline; hot-swap adapters via MoLoRA infrastructure. **MambaPEFT** ([arXiv:2411.03855](https://arxiv.org/abs/2411.03855), Sony) is the broader PEFT taxonomy for Mamba blocks — its headline contributions are **Affix-tuning** and **Additional-scan** rather than projection-targeted LoRA specifically. The four-projection LoRA targeting is the broader Mamba PEFT design space; pick the technique inside that space when this slice lands. | source §Phase 3 (Ω20) + MambaPEFT paper | NOT-STARTED |
| **TurboQuant (Phase 4 Ω21)** — PolarQuant + QJL residual; QR-derived random rotation; recursive polar coord transform (log₂(d) levels); per-coord Lloyd-Max quantization on Beta distribution; 1-bit QJL residual for unbiased inner-product estimation. 3.5 bits/channel → 4.5× compression over fp32. Replaces Phase 1 binary quantization once accuracy gates pass. | source §Phase 4 + §"TurboQuant Math Summary" | NOT-STARTED |
| **Storage budget**: 1M notes × 1024 dims × 1 bit = **128 MB**. Fits L0-L1 working budget comfortably; does not push into L3 SSD Oracle. | source §"Key Numbers" | NOT-STARTED |
| **Differentiation from existing primitives**: NOT a replacement for `vault.search` Variant Ladder (T3 RRF stays canonical for agent-callable retrieval) · NOT a replacement for Halo Shadow Sketch (lexical+vector fusion for cross-app search) · NOT a replacement for L4 Engram (B2-M12 hash-recall for static facts) · IS the typing-cursor pre-fetch + prompt-prefix state-injection layer. | reconciliation against §3.2 L2 Shadow Sketch · §3.7 Variant Ladder · PASS 2 B2-M12 Engram | doctrine boundary |
| **Why this row is load-bearing**: closes the user-perception gap "the model knows what I'm typing about" — by the time the agent's first token streams, the Mamba state already carries the writing-session's nearest 3 vault neighbors. Without this row, the sidebar's relevance signal arrives 50-200 ms slower (via the longer T3 RRF path) and the model's first-token context lacks vault-aware prefill. | PASS 2 gap audit B2-H3 | reframes Wave 9.33+ memory architecture |
| **Source papers**: MemMamba ([arXiv:2510.03279](https://arxiv.org/abs/2510.03279), Wang et al. 2025 — threshold-triggered state summarization · audit-of-audit #2 verified citation) · [Model2Vec](https://github.com/MinishLab/model2vec) (paragraph-level fast embed) · TurboQuant ([arXiv:2504.19874](https://arxiv.org/abs/2504.19874), PolarQuant + QJL residual, Google Research ICLR 2026) · MambaPEFT ([arXiv:2411.03855](https://arxiv.org/abs/2411.03855), Sony — Affix-tuning + Additional-scan, broader PEFT taxonomy for Mamba blocks) | source §"Source Papers" + audit-of-audit #2 citation verification | reference |

### 3.35 Golden-ratio scheduling — KAM-stable cadence for NightBrain + distillation

| Concept | Source | Status |
|---|---|---|
| **Schedule formula** `t_n = φ^n · T` (n = 0, 1, 2, …; φ ≈ 1.6180339887…). Tasks fire at t = T · 1, T · φ, T · φ², T · φ³, … The minimum spacing between any two task firings is maximized because φ is the worst-approximable irrational. | PASS 2 gap audit B2-H8 · `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_MASTER_ARCHITECTURE.md` "Layer 4: Golden Scheduling" | NOT-STARTED |
| **Why φ?** Continued-fraction expansion `[1; 1, 1, 1, …]` (all 1s — slowest possible convergent decay) makes φ the **last KAM torus to collapse** under perturbation in the dynamical-systems sense. Per **Hurwitz 1891** "On the approximation of irrational numbers by rationals" the bound `\|α − p/q\| < 1/(√5 q²)` is tight at α = φ. Iter-10 audit-of-audit verified this online citation. | Hurwitz 1891 + audit-of-audit Task 4 verification | reference |
| **NightBrain integration shape** — replace fixed-interval task firing in `agent_core::nightbrain::CANONICAL_TASK_NAMES` (currently 10 tasks per `nightbrain/mod.rs:11`) with φ-spaced cadence. Pseudocode: `let t_n = base_interval * f64::powi(PHI, n);`. Prevents the all-tasks-fire-on-the-same-tick resonance pattern where `maintenance_log` · `search_index_passive_checkpoint` · `event_store_checkpoint_vacuum` · `workspace_snapshot_compaction` all land in the same idle window and compete for the same I/O budget. | Atlas Drift Log row 1 (the 10-canonical-tasks list) + audit row B2-H8 | NOT-STARTED |
| **Distillation cadence integration** — `cloud_knowledge_distillation` task (§13.5.7 Per-model Knowledge Vault compilation) and `memory_distillation` task (per-model vault refresh) MUST run on different φ^n offsets so they don't share I/O windows. Same rule for `skill_evolution_analysis` and `session_graph_generation` if they ever land real bodies. | §13.5.7 cross-link + Atlas Drift Log | NOT-STARTED |
| **Why this matters operationally** — observation lanes already in `agent_core::nightbrain::ObservationTask` ([B.9 4/10](#)) bucket all observation logs into the same `OBSERVATION_LANE_RING` capacity (256). When multiple observation tasks fire on the same tick, they race for ring slots and the diagnostic join key for cross-task drift detection becomes ambiguous. φ-spacing makes the timestamps unique to nanosecond resolution under any reasonable base interval. | `agent_core/src/nightbrain/*.rs` ObservationTask substrate | NOT-STARTED |
| **Scope explicitly NOT covered** — (a) Fibonacci-time hashing for cache eviction (related but distinct from task scheduling); (b) golden-angle UI layouts (visual rather than temporal); (c) KAM theory beyond the φ-as-most-irrational property — the broader Kolmogorov-Arnold-Moser stability theory is research-tier deep, this row lands only the operational scheduling rule. | doctrine boundary | reference |
| **V1 scope** — **research-tier, NOT V1**. The current NightBrain runs at ~36 fires/day per task with no resonance pressure observed yet. φ-spacing becomes load-bearing when the 6 NoOp task bodies (dedupe_artifacts · memory_distillation · cloud_knowledge_distillation · session_graph_generation · skill_evolution_analysis · ssm_state_pruning) ship real bodies AND start sharing I/O budgets. Wave 9+ integration target. | Implementation Log B.9 history + cadence projection | NOT-STARTED |

### 3.36 SAE Cognition Observatory — hallucination detection AUC 0.90

| Concept | Source | Status |
|---|---|---|
| **Sparse-autoencoder feature monitoring on model internals** — train an SAE on the residual stream (or attention output) of a target model, monitor which features fire per turn, flag the turn as low-confidence when a known "hallucination signature" feature pattern appears. | PASS 2 gap audit B2-H11 + `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_MASTER_ARCHITECTURE.md` SCOPE-Rex Core Components table + existing Wave J2 reference at §6 line 680 | NOT-STARTED |
| **Doctrine acceptance bar: AUC 0.90 on a held-out factual subset.** This is the **pin** that distinguishes the SAE Cognition Observatory from generic "SAE name-drop" — the row only counts as shipped when an SAE actually achieves AUC ≥ 0.90 on a vault-domain validation set. Below 0.90 = research, not gate. | source §SCOPE-Rex Core | NOT-STARTED |
| **Complementary to B2-H7 LapEigvals** (Hermes 2.0 §13.5.8) — LapEigvals achieves AUROC 88.9% via Laplacian eigenvalues of attention maps; SAE achieves AUC 0.90 via sparse-autoencoder features. The two detectors use **different mechanisms** on **different signals** (attention spectrum vs feature activation), so they can stack: if either fires below confidence threshold, the turn is flagged. Composite acceptance bar = max(LapEigvals AUROC, SAE AUC) ≥ 0.90, with the lower-AUC detector providing redundant signal for the cases the higher-AUC one misses. | Hermes 2.0 §13.5.8 + Wave J2 | NOT-STARTED |
| **Distinct from name-drops elsewhere in canon** — `MASTER_FUSION §6 Wave J2` and `SCOPE-Rex Core Components` table both reference "SAE Cognition Observatory" without pinning the AUC threshold. This row IS the pin. Future doc edits that name SAE without citing AUC ≥ 0.90 are drift. | reconciliation against §6 Wave J2 line 680 + PASS 2 audit | doctrine boundary |
| **V1 scope** — research-tier, NOT V1. Requires SAE training on a chosen model's residual stream (local-only models exclusive — Claude/GPT residuals not accessible). Per-step SAE forward-pass adds non-trivial latency. Wave 9+ integration target, paired with B2-H7 spectral detection. | doctrine boundary | NOT-STARTED |
| **Why this row is load-bearing** — pinning the AUC threshold turns "SAE Cognition Observatory" from a vague capability claim into a falsifiable engineering target. The team that picks up Wave J2 must achieve AUC ≥ 0.90 or the slice fails. Without this pin, any SAE that fires under any circumstance could claim to be the Cognition Observatory. | PASS 2 audit framing | reference |

### 3.37 N1 Prompt Tree — JSPF + PTF + Relocation Trick (SHIPPED)

| Concept | Source | Status |
|---|---|---|
| **JSPF (JSON-Schema Prompt Format)** — typed, Codable, Sendable, Hashable `Prompt` struct composed deterministically from typed inputs. Single representation flows through Anthropic Messages, OpenAI Responses, Apple AFM @Generable, MLX local-grammar via `PromptRenderer` | `Epistemos/Engine/PromptTree.swift:42-101` (Prompt root type) + `PromptRenderer.swift` | **SHIPPED** (commit `7316f86bd` "n1(prompt-tree): JSPF + PTF foundation + ChatCoordinator first-turn wire") |
| **PTF (Prompt Tree Format)** — on-disk directory representation. `Prompt` flattens to `PromptNode` directory tree at `<vault>/.epistemos/prompts/<session>/<turn>/manifest.json`. Lossless round-trip JSPF ↔ PTF for replay + audit + cache parity verification. | `Epistemos/Engine/PromptTree.swift:256-298` (PromptNode) + `PromptTreePersister.swift` | SHIPPED |
| **CacheHints** with `.chatDefault` preset — `Codable` struct flagging `stableSubtrees` + `applyRelocationTrick` so `PromptRenderer` knows which subtrees to mark as Anthropic prompt-cache breakpoints. Default chat preset hints the 3-4 most stable subtrees (system + recent persistent memory + tool registry) within the **4-breakpoint Anthropic cap** verified by audit-of-audit #1. | `Epistemos/Engine/PromptTree.swift:217-241` + audit-of-audit #1 Task 4 (Anthropic 4-cap confirmed) | SHIPPED |
| **PromptComposer.compose** — deterministic builder taking typed inputs and producing the JSPF `Prompt`. Replaces ad-hoc string concatenation. | `Epistemos/Engine/PromptTree.swift:300+` | SHIPPED |
| **PromptRenderer** — single dispatch point that renders one JSPF `Prompt` into provider-specific wire format (Anthropic Messages `system` prefix + cache `cache_control` blocks · OpenAI Responses · AFM Generable · MLX grammar). | `Epistemos/Engine/PromptRenderer.swift:57` | SHIPPED |
| **`EPISTEMOS_PROMPT_TREE=1` env var** for CI parity tests on the persisted PTF round-trip. | `Epistemos/Engine/PromptTreePersister.swift:30` | SHIPPED |
| **Relocation Trick (90% token-cost reduction)** — moving frequently-reused subtrees (system prompt · stable memory · tool registry) to the prompt prefix so Anthropic prompt cache amortizes them across turns. Combined with the 4-breakpoint cap, gives ~90% input-token cost reduction on long-running conversations. | source `PROMPT_AS_DATA_SPEC.md` §"Relocation Trick" + audit-of-audit #2 Task 4 verification | SHIPPED via `CacheHints.applyRelocationTrick` |
| **Why this row is canon, not just code** — PASS 2 B2-H12 framed N1 as "not yet shipped." §5.0 reconciliation gate caught the stale framing — code WAS shipped, audit-row tracked aspirational doctrine. This MASTER_FUSION row is the pointer-to-code from canon, so future readers find N1 from the atlas, not just by grepping Engine/. | PASS 2 B2-H12 + commit `7316f86bd` | doctrine reconciliation |

### 3.38 Graph Engine — 42 locked architectural decisions (Phase A SHIPPED · Phase B/C queued)

| Concept | Source | Status |
|---|---|---|
| **Canonical plan doc** — `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` (565 LOC; converged synthesis of 7 deep-research drops; verdict CONVERGED, ready for execution; supersedes prior graph plans). Lives in MASTER_FUSION canon from this row forward — earlier name-drops were not authoritative anchors. | `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` + PASS 2 B2-H15 | DOCTRINE |
| **Architecture sentence** — Rust-orchestrated, Metal-resident force layout. Rust owns topology + reveal order + clustering + control plane; Metal owns positions/velocities/forces + per-frame physics; Swift orchestrates command buffers + camera. Buffers are Metal-allocated `.storageModeShared`; Rust writes through a Swift-bound pointer. | source §"Executive summary" | LANDED (Phase A) |
| **Ship bar** — 10k nodes @ 60-120 fps on M2 Pro · sub-1s cold open · fluid Obsidian-style reveal · causal-atmosphere sleep with visual-equivalence test passing · 50k feasible · 100k feasible with cluster-first semantic zoom at full zoom-out. | source §"Executive summary" | acceptance bar |
| **42 locked decisions (highlights)** — uniform-grid + cell aggregation (NOT Barnes-Hut first); GraphPOPE-lite warm-start with 8/16/32 anchors; causal-atmosphere sleep with 24-frame hysteresis @ 120Hz; Idle → Seeding → Ramping → Settling → Steady reveal FSM; sleep disabled until Steady phase; FFI `NonNull<T>` foreign-Metal-pointer discipline; freshness honesty via `materialized_through_seq` / `local_head_seq` / `stale_ops`; repulsion via uniform grid not Barnes-Hut; graph-engine lives in shared `graph-engine` Rust crate consumed by both current Epistemos and any future v2 shell. | source §"Locked architectural decisions" + §"Phase A — CPU foundation + zero-copy" | LANDED (Phase A) |
| **Phase A — CPU foundation + zero-copy** — 4-week target. Per PASS 2 B2-H15 + audit-of-audit #3 (iter 30) verification re-check: **Phase A algorithmic deliverables SHIPPED** on this branch (`codex/research-snapshot-2026-05-08`) — Rust orchestrates topology and writes positions/velocities into Metal-allocated `.storageModeShared` buffers; uniform-grid repulsion + GraphPOPE-lite warm-start + reveal FSM all live in CPU code. 2629 graph-engine lib tests + 8 integration tests pass, 0 regressions. **Engine-integration pass queued as Phase B prerequisite** — warmstart → integrator wiring, atmosphere → integrator wiring, RevealController → app shell wiring all land before Phase B GPU work begins. Phrasing tightened in audit #3 to avoid overstating "Phase A shipped" without the integration-pass caveat. | source §"Phase A" lines 90-96 + audit-of-audit #3 (iter 30) Task 5 citation re-check | **algorithmic deliverables LANDED · engine-integration pass queued** |
| **Phase B — GPU compute** — 8-week target, queued. Move per-frame physics loop into Metal compute kernels; Rust stays as topology/reveal/control plane; ship-bar 60-120 fps @ 10k nodes is the gate. | source §"Phase B" | NOT-STARTED |
| **Phase C — cluster + 50k+** — 4-week target, queued after Phase B. Cluster-first semantic zoom at full zoom-out enables 100k+ nodes by drawing cluster blobs rather than individual nodes when zoomed out. | source §"Phase C" | NOT-STARTED |
| **Graph-protection rule (loop §8 #12)** — applies to every line of this row: no camera / renderer / layout / edges / physics / hologram changes without scoped user approval. Phase B/C are explicitly the kind of work that needs scoped approval per §0 immutable rule 1 of `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md`. | `MAS_COMPLETE_FUSION §0` rule 1 + loop §8 #12 | doctrine boundary |
| **Why this row is canon, not just code** — Phase A is shipped but `MASTER_FUSION` had no doctrine anchor pointing at `CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md`. Future readers needed to either grep `MetalGraphView` or stumble on the plan doc. This row is the pointer. PASS 2 B2-H15 also closes the "42 decisions need to be in canon" framing — they're now anchored here with the Phase B/C queued status explicit. | PASS 2 B2-H15 + reconciliation | doctrine reconciliation |

### 3.39 Adaptation Subsystem + Compute Steering — schema-first adapter dispatch (Adaptation SHIPPED · Compute Steering NOT-STARTED)

**Source:** PASS 1 gap audit H-5 + `docs/fusion/research/ADAPTATION_SUBSYSTEM_SPEC_v1.md` + `COMPUTE_STEERING_SPEC_v1.md`.

Two related-but-distinct halves: **Adaptation Subsystem** is the session-scoped, delta-only LoRA training surface for MLX helper models. **Compute Steering** is the per-call expert-budget / KV-allocation dispatch policy. §5.0 reconciliation gate split this audit row: Adaptation is shipped end-to-end (Rust FFI + Swift executor); Compute Steering is NOT-STARTED.

| Concept | Source | Status |
|---|---|---|
| **Adaptation Subsystem Swift executor** — `AdaptationExecutor` (`Epistemos/Engine/AdaptationExecutor.swift`) drives bounded LoRA adaptation on MLX **helper models only** (never the primary GGUF chat backbone) under Rust session governance. Lifecycle: `beginSession(adapterID, modelID, runtimeKind=.mlx, isHelperModel=true, maxUpdates=50, minChunkTokens=256)` → accumulate training signals → execute gradient steps (delegated to MLX LoRA training infra) → `canary validation` after each update → `AdapterCheckpoint` for rollback → `endSession`. | `Epistemos/Engine/AdaptationExecutor.swift:22-60` + `Epistemos/Engine/SSMMemorySidecar.swift:25-33` | **SHIPPED** (V1) |
| **Rust `AdaptationSubsystem` FFI** — Rust-side session governance the Swift executor talks to (`subsystem.hasActiveSession()`, `subsystem.activeSessionAdaptationState()`). Enforces session-scope + delta-only + helper-only invariants from the Rust side so the Swift side cannot silently widen scope. | `Epistemos/Engine/AdaptationExecutor.swift:34` + Rust FFI bridge | **SHIPPED** (V1) |
| **`AdaptationStabilizer`** — stabilization layer that tracks `anchorWeightNorms` + `baselineCanaryLoss` to detect adapter drift relative to the base model. Pairs with the canary loop. | `Epistemos/Engine/AdaptationExecutor.swift:27` | **SHIPPED** (V1) |
| **Non-negotiable invariants** (from `AdaptationExecutor.swift:15-20`): helper-model only (never primary chat backbone) · MLX-only execution · session-scoped (no persistent silent learning) · delta-only (base weights immutable) · fail-closed on any safety-check failure. These are doctrine, enforced in code. | `AdaptationExecutor.swift:15-20` | doctrine + code-enforced |
| **Compute Steering — schema spec** (`compute_budget`, `compute_profile`, expert-budget dispatch, per-call KV allocation, canary validation harness pre-deployment, micro-TTT loops). NOT shipped — `rg "compute_budget|compute_profile|MicroTTT|ComputeSteering"` across `agent_core/src/` + `Epistemos/` returns **zero hits**. Gap is doctrine + scaffold spec. | source `COMPUTE_STEERING_SPEC_v1.md` + §5.0 reconciliation gate verification | **NOT-STARTED** |
| **What "Adaptation" vs "Compute Steering" means in this row.** Adaptation = *fine-tuning a helper model's deltas in a bounded session* (training-side, post-V1 polish, partially shipped). Compute Steering = *deciding which adapter / KV-cache slice / expert-budget to dispatch per call at inference time* (inference-side, NOT shipped). They compose: Compute Steering picks which adapter Adaptation produced to apply to a given turn, but they ship at different times. | doctrine boundary | reference |
| **V1 scope.** V1 ships the Adaptation Subsystem half (already in main). Compute Steering is research-tier post-V1; do NOT touch in V1 work per loop §8 #11 ("No Helios architecture changes" — Compute Steering is V6.1+ substrate adjacent). | loop §8 #11 + V1 scope | research-tier post-V1 |
| **Why this row is canon, not just code** — PASS 1 H-5 framed both halves as missing from canon. §5.0 reconciliation showed half is shipped + half is genuinely not. Splitting the row here keeps the framing honest and prevents future agents from re-implementing the Adaptation half OR claiming Compute Steering is partial. | PASS 1 H-5 + §5.0 reconciliation gate | doctrine reconciliation |

### 3.41 Nano Model Training Recipe — 75/25 Mamba-2/Attention hybrid + MOHAWK distillation (B2-M3)

**Source:** `docs/_consolidated/20_canonical_research/NANO-MASTER-TRAINING-GUIDE.md` §1 (Pillar 1 Architecture + Distillation) + §2 (Pillar 2 App-specific Meta-Training) + §3 (Pillar 3 General macOS Device Control). PASS 2 audit row B2-M3.

This row is the **training-recipe canonical row** for the Epistemos nano model. Distinct from §3.22 (which covers post-training continual-learning algorithms — GRPO + MLA + TransMLA + OSFT/PSOFT/coSO/DSC) and §3.34 (which covers inference-time Mamba-2 state injection for Instant Recall). §3.41 is the **base-model build recipe**.

**The 75/25 hybrid architecture (validated; cliff-edge ratio — do not change without 150M-proxy ablation):**

| Layers | Type | Role |
|---|---|---|
| 1–4 | Mamba-2 | Initial sequence compression |
| 5 | Attention | Early retrieval anchor |
| 6–10 | Mamba-2 | Mid-level context integration |
| 11 | Attention | Schema enforcement (JSON structure) |
| 12–17 | Mamba-2 | Deep context distillation |
| 18–19 | Attention | Final retrieval (current AX state + app identity) |
| 20–24 | Mamba-2 | Output formation |

Six attention layers exist for three things no SSM variant can do: (1) exact AX-tree token retrieval · (2) JSON-schema enforcement at layer 11 · (3) multi-turn context anchoring at layers 18–19.

**MOHAWK distillation hyperparameters (validated, NOT-STARTED in code):**

```
Learning rate:    ≤ 2e-4   (4e-4 triggers NaN — gradient explosion at d_model=1024)
Optimizer:        AdamW β=(0.9, 0.98)
Precision:        BF16 training, FP32 parameter storage  (AMP-style)
Gradient clip:    norm 1.0
Warmup:           500 steps
Schedule:         WSD (Warmup-Stable-Decay, NOT cosine)
  Stable phase:   80% of total steps at peak LR
  Decay phase:    20% — inject highest-quality macOS + Epistemos traces here
Stage 3 loss:     α=1.0 · KL(teacher, student)  +  β=0.1 · CE(student, labels)
Token budget:     ~8B tokens   (D:N ratio = 8 per nanochat finding)
Δ-bias init:      NEVER zero-initialize (post-init hook reset is a known silent failure mode)
Conv init:        identity-initialized; gate biases = 1.0
Layer replacement: SMART (Sensitivity Measure-Aware Replacement, Zebra-Llama) — measure attention output distribution shift, replace least-sensitive layers first
```

**WSD advantage** (why not cosine): pre-decay checkpoints are reusable. When new Epistemos app traces arrive, training continues from any stable-phase checkpoint without cold restart. This is what makes the **Doc-to-LoRA Instant Adapter on App Ship** workflow (Pillar 2 §2.5) tractable.

**Hybrid-aware mixed-precision quantization (no existing tool handles this — must configure manually per MambaQuant ICLR 2025):**

| Component | Precision | Why |
|---|---|---|
| Mamba-2 SSM (A, B, C, dt) | FP16 | Scattered activation outliers · cumulative-product stability |
| Mamba-2 conv1d kernel | FP16 | Small relative to projections · critical for accuracy |
| Mamba-2 in_proj, out_proj | INT4 | High redundancy · primary memory savings |
| Attention Q, K, V | INT4 | Standard aggressive quant |
| MLP gate/up/down | INT4 | Standard |
| Output logit layer | FP16 | Accuracy-critical |
| Embedding table | FP16 | Lookup precision |

Apply **KLT-Enhanced rotation** (beyond Hadamard) for weight projection matrices — Mamba output projections have up to 40% flush-to-zero rates at FP4 without it.

**Deployment: MLX GPU only, NEVER ANE.** Mamba-2 selective-scan's sequential state dependency conflicts with ANE's parallelizable-operation requirement. ANEMLL has zero SSM support. Target hardware perf: 1B 4-bit on M4 Max → 70–95 tok/s generation (sufficient for sub-200ms-per-action interactive agent use). ANE is reserved for: the 100ms visual-verification loop (screenshot classification) · Model2Vec text embedding · the 50M intent classifier.

**Mamba-2 → Mamba-3 migration (March 2026 plan):** 75/25 ratio + the 6 attention layers stay regardless of Mamba generation. Mamba-3 (Gu & Dao, ICLR 2026) fixes state-tracking via complex-valued dynamics + exponential-trapezoidal discretization; at 1.5B matches Mamba-2 perplexity with half the state size (64 vs 128 hidden state). Migration is a config swap (`mamba2_layer` → `mamba3_layer`), NOT an architecture rewrite. **Discipline:** keep the layer abstraction parameterized today so the swap stays a config change tomorrow. Trigger: community validation of Mamba-3 distillation in the `state-spaces/mamba` repo + GoombaLab blog + MLX training support.

**The 3 concurrent pillars (training data composition):**

1. **Pillar 1 — Architecture + Distillation** (this row). 75/25 hybrid + MOHAWK + quantization + MLX deployment.
2. **Pillar 2 — App-Specific Meta-Training** (the reflexive core; canonical guide §2.1–2.6). Code Graph Model from `agent_core` + Xcode Symbol Graph → QA pairs · AX Atlas with differential snapshots · SFT → RLAIF agentic recipe · **Doc-to-LoRA instant-adapter on app ship** · version-aware adapter lifecycle.
3. **Pillar 3 — General macOS Device Control** (canonical guide §3.1–3.4). Validated training-data composition ratios · tool-calling fine-tuning · AX tree representation · approved data sources.

Pillar 4 (Reinforcement Learning, GRPO) is covered separately by **§3.22 Continual learning** row (landed `4b509eb6e` iter 33).

**§5.0 reconciliation against existing rows — what this row does NOT duplicate:**

- **§3.22 Continual learning** has the GRPO + MLA + TransMLA + OSFT/PSOFT/coSO/DSC + OFTv2 QLoRA path. Those are *post-training* algorithms (apply to a trained base model). §3.41 is the *base model build recipe* — they compose, not overlap. GRPO trains the LoRA adapter; MOHAWK builds the base the LoRA attaches to.
- **§3.34 Instant Recall** has Mamba-2 hidden-state injection at *inference time* (~50 ms prefill of top-3 retrieved notes before agent's first turn). §3.41 covers the *training* of the Mamba-2 layers themselves. Composes, not overlaps.
- **§3.4 SCOPE-Rex** governs runtime; orthogonal.
- **§3.16 Helios kernels (V6.1/V6.2)** are Metal compute-shader kernels; orthogonal.

**Status:** NOT-STARTED in code. `rg "MOHAWK|mohawk|hybrid_ratio|75.*25" agent_core/src/` returns zero hits. Currently no training infra in main; the nano model lands post-V1 via MLX-LM v0.31.1+ (which supports Mamba-1/Mamba-2/Nemotron-H/Jamba natively). Doctrine row freezes the recipe shape so when training spins up post-V1, the hyperparameters + layer placement + quant table + ANE-vs-GPU rule are not redrifted.

**V1 / Pro / Post-V1 boundary:** No V1 dependency. Pillar 2 instant-adapter workflow (Doc-to-LoRA on app ship) is the user-visible benefit and lands once the nano base model exists. Pro tier may surface the LoRA adapter training in-UI; MAS tier ships frozen adapters bundled with the app.

**Cross-references:**
- `docs/_consolidated/20_canonical_research/NANO-MASTER-TRAINING-GUIDE.md` — canonical guide (4 Pillars, 28 subsections); consult for full detail rather than re-pasting here.
- §3.22 Continual learning (GRPO + MLA composition).
- §3.34 Instant Recall (inference-time Mamba-2 use).
- PASS 2 audit B2-M3.
- B2-M2 Control Plane API (Skills UI object will surface the LoRA-adapter lifecycle once trained).

---

### 3.40 Run Ledger — per-token cryptographic attestation (NOT-STARTED, distinct from 4 existing provenance primitives)

| Concept | Source | Status |
|---|---|---|
| **Run Ledger — per-token/per-thought cryptographic attestation lineage**. Each output token (or thinking-block boundary) is signed and chained into a hash-linked sequence so any later consumer can verify (a) which model produced which token, (b) under which capabilities, (c) at which decode position, (d) with which provider+adapter combination. Finer-grained than all four existing provenance primitives. Source: `docs/fusion/jordan's research/uasa.agent.final.md §1.3` + PASS 1 H-9. | `uasa.agent.final.md §1.3` + PASS 1 H-9 | NOT-STARTED |
| **Explicit disambiguation from the 4 existing provenance primitives** (all already shipped — see `agent_core/src/scope_rex/answer_packet.rs:26-30` doctrine note): (1) **ClaimLedger** ≡ EvidenceLedger — per-claim provenance (`agent_core/src/provenance/ledger.rs`); (2) **ExecutionReceipt** §5.1 — per-tool-call signed receipt (`agent_core/src/effect/receipt.rs`, B2-H13 catch #6); (3) **RunEventLog** ≡ provenance/ledger — per-run-event log (already in main); (4) **`.epbundle`** — snapshot of all four at a session boundary (provenance ledger snapshot per `agent_core/src/provenance/replay.rs`). **Run Ledger fills the gap between RunEventLog (per-event) and `.epbundle` (per-snapshot) at the per-TOKEN granularity** — events are coarser than tokens, snapshots are at session boundary, ClaimLedger is at claim granularity, ExecutionReceipt is at tool-call granularity. | scope_rex/answer_packet.rs:26-30 + PASS 1 H-9 §"distinct from ClaimLedger and .epbundle" | doctrine boundary |
| **Naming-collision warning.** Existing main carries "RunEventLog" as a name. Adding "Run Ledger" creates name proximity but **different concept** — RunEventLog = per-event log, Run Ledger = per-token attestation chain. Doctrine prefers the finer-grained name be **`TokenAttestationLedger`** or **`PerTokenLedger`** when implemented, to avoid the RunEventLog collision. Doc keeps "Run Ledger" as the audit's framing for cross-referencing PASS 1 H-9 but operationally the type name will be more specific. | naming convention + audit reference | reference |
| **Why this row is canon, not just code** — H-9 is a genuine new primitive on the provenance ladder (per-token granularity below ExecutionReceipt's per-call). Without the explicit disambiguation against the 4 already-shipped primitives, a future implementer might either (a) re-implement RunEventLog under the "Run Ledger" name and break existing callers, OR (b) skip the per-token granularity entirely thinking the existing primitives cover it. Doctrine boundary written into this row prevents both failure modes. | §5.0 reconciliation gate + audit ladder | doctrine reconciliation |
| **Apple Silicon implication + scope.** Per-token attestation has non-trivial signing cost (every token = one HMAC or Ed25519 op). MAS V1 doesn't ship — research-tier post-V1 only. Likely Pro V1.x trigger: when `.epbundle` cross-machine replay needs token-level verification rather than just event-level. Until then, the existing 4 primitives suffice. | hardware-cost analysis | research-tier post-V1 |

---

## 4. Cross-document disambiguations (do not confuse)

| Term | 3+ distinct meanings — never collapse |
|---|---|
| **Shadow** | (a) Classical Shadows tomography (Huang/Kueng/Preskill 2020); (b) ShadowKV (Bytedance ICML 2025); (c) Helios L2 Shadow Sketch (random-sketch KV residency); (d) Halo Shadow vault search (Tantivy + usearch lexical) |
| **Helios** | (a) Helios architecture canon (v2/v3/v5/v6.1/v6.2 — Jordan's executive-add); (b) ShadowKV/KV-Direct/Helios-Shadow-Memory literature; (c) the GPT-research Helios crate workspace skeleton; (d) Lane 5 "helios" classifier in v5; (e) `HELIOSInvariantSourceGuard` shipping component |
| **Hermes** | (a) Hermes Function Calling fine-tunes (NousResearch); (b) Hermes-4-405B cloud model identity; (c) Hermes gateway agent (the architectural positioning in `hermes.md`); (d) Hermes UI overlay brand (PURGED 2026-05-05); (e) `agent_core::agent_runtime` (renamed from hermes/ 2026-05-05) |
| **Holographic** | (a) HRR-Sealed Memory (Plate 1995 revival) — Helios v3 §CMS-X audit rename; (b) Boneh-Sahai-Waters 2011 Holographic Functional Encryption (DO NOT CONFLATE) |
| **WBO-5 / WBO-6 / WBO-7** | escalation ladder: 5-term (compass artifact) → 6-term (helios v3) → 7-term reserved (helios v5 kernel-only subform) — same ½ across all |
| **Residency** | (a) L0-L7 7-level residency ladder (`scope rex.md` Orthogonal Residency); (b) λ field in Resonance Signature; (c) 9 Residency variants in helios v5 (Transient/Retrieval/Feature/Harness/Grpo/Psoft/Osft/Cloud/Quarantine); (d) MTLResidencySet Metal — never confuse |
| **Variant Ladder** | (a) `deterministicapp.md` A→B→C→D→Defer (single tool); (b) doctrine 6-tier escalation (Deterministic → Cloud); (c) route-capture `variant_{a,b,c}.rs` (specific route domain) — the doctrine is the canon |
| **VRM / Verified Research Mode** | (a) the product mode (helios v5 §1.5 vertical slice); (b) the 4 UI labels chip (`VRMLabelView`); (c) ρ value in Resonance Signature ≠ VRM label |
| **EML** | (a) Odrzywolek operator eml(x,y) = exp(x) − ln(y) (universal arithmetic); (b) EML Neuron (Universal Plasticity Gate proposal — different paper analogy); (c) eml-lean Lean 4 vendored crate; (d) EML-IR W1 floor work — disambiguate per context |
| **Tier** | (a) ToolTier (None/ChatLite/ChatPro/Agent/Full — chat-mode tool exposure); (b) DeploymentTier (MasCore/Pro/Research); (c) LadderTier (Deterministic/Embedding/Classical/SmallLLM/MidLLM/Cloud); (d) verification tier T0-T4 — never collapse |

---

## 5. Implementation Status Matrix — Atlas Rollup

| Pillar | Status | Items shipped | Items deferred | Items NOT-STARTED |
|---|---|---|---|---|
| **Five Pillars + WBO-6** | DOCTRINE | research substrate compiles | WBO ledger | full inequality enforcement |
| **EML floor (V6.1 W1)** | NOT-STARTED | — | — | oxieml vendored / eml-lean / F-ULP-Oracle / morph_eval_reduced.metal v0.1 |
| **6-tier memory** | PARTIAL | L0 KV (MLX) | L_SE | L1 Sherry, L2 Shadow-KV, L3 SSD oracle, L4 cascade |
| **KV-Direct gate** | NOT-STARTED | shader file present | — | Week-0 harness |
| **SCOPE-Rex** | PARTIAL | answer_packet / produce / residency / witnessed_state / btm_semantic / feature_observatory / ontology / kernels/kv/metal/retrieval scaffolds | — | constrained action objective / Sinkhorn routing / Brain Time Machine / Observatory full UI |
| **Resonance Gate / Σ-signature** | MATCHES | full 7-field Rust seam (τ/π/λ/δ/ρ/κ/η/mod) + FFI + VRM chip | — | 9-arm Kleene K3 classifier / 5 directional operators / Knowledge Sieve / Gap Winner Rule |
| **Sovereign Gate** | MATCHES | 5 action classes + single LAContext + Session Authority Token + biometric Keychain | — | broader Core action coverage |
| **Variant Ladder (No-LLM-First)** | DRIFTED+PARTIAL | route-capture impl + typed seam (orphan) + doctrine | — | **dispatcher.rs adoption** / 6-tier across all tool routes / FLOOR_T1-T3 thresholds / LadderLog → Provenance / escalate_on_empty gate |
| **GBNF / structured output** | PARTIAL | LocalToolGrammar + MLXStructured + JSONSchema + soft-guidance fallback | — | per-tool `&'static str` GBNF / Tool trait JsonSchema macro / ≤256 reasoning enforcement |
| **Hybrid MD+JSON memory** | PARTIAL | MutationEnvelope + Epdoc + ClaimLedger | — | epistemos.soul.v1 / .skill.v1 / .episode.v1 / .semantic.v1 / migration registry |
| **ACS** | NOT-STARTED | — | research-tier | 4 homeostatic loops / VSM S1-S5 / HealingAction / Markov blanket / Hyper-Dynamic Schemas |
| **Halo V1** | PARTIAL | HaloController + Shadow{Search,Indexing}Service + Tantivy+usearch+RRF | — | 6-state FSM / Model2Vec / non-activating NSPanel / Eidos pairing |
| **Helios Shadow Memory (KV-side)** | NOT-STARTED | — | — | ShadowPage triple-rep / Shadow-First Attention / Metal sketch scoring |
| **Cognitive DAG (Phase 8)** | LANDED 8.A-8.G | 10×NodeKind + 10×EdgeKind + BLAKE3 Merkle + redb store + macaroons + companions + 4 DagMirrors + dispatch + epbundle CLI + doctrine-lint CLI | — | 8.H (ship + paper) |
| **Cognitive Kernel (Phases 1-7)** | MATCHES | agent_runtime + ToolTier + PolicyProfile + 5-rules + LSP V2.3 | — | WASM exec (Phase 3) / bundled in-proc MCP (Phase 4) |
| **GenUI dispatcher** | PARTIAL | G.1-G.4 + Stage A.2/A.4 determinism + 7 base schemas + 0 GENUI-DEFER markers | — | G.5 DAG integration / G.6 doctrine linter / 8 new schemas full |
| **Cognitive Weight Class** | DRIFTED | seam at `cognitive_weight/mod.rs` | — | W1 metadata enforcement / W2 Wave 7 policy_grade ENFORCED |
| **Live File Compiler (Wave 7)** | NOT-STARTED | seam at `live_files/mod.rs` | indefinite (post V2.7) | full state machine + LivePlan.v1 + G1-G4 / kani verification |
| **Honest Handle FFI** | MATCHES | epistemos-shadow + substrate-core + syntax-core | — | substrate-rt donor merge |
| **Helios kernels (6)** | NOT-STARTED | InterruptScore Swift CPU LANDED + 3 substrate observers LANDED | research-tier target-only | 5 Metal kernels (SemiseparableBlockScan / LocalRecallIsland / PageGather / ControllerKernelPack / PacketRouter1bit) |
| **AnswerPacket ladder** | LANDED rendered | Swift schema + Rust producer + FFI + bubble chip + 3 observers | — | populated→canonical (signed JSON-Lines) |
| **Provenance ledger** | MATCHES | ClaimLedger + ReplayBundle + Merkle + retraction propagation + epbundle CLI | — | per-tool authority verification |
| **Capability lattice + XPC** | NOT-STARTED (paid-team-gated) | Cargo features + Xcode configs + entitlements split (TEMP-FREE-TIER) | until $99 Apple Developer | 5-service decomposition + App Group restoration + IOSurface zero-copy + capability HMAC tokens |
| **NeMoCLAW / OpenCLAW MAS** | NOT-STARTED | — | research-tier | 6-factor agent model + 4 orchestration topologies + GodMode workflows + Evidence Supremacy Protocol + multi-claw |
| **Ternary core** | NOT-STARTED | research-tier | research-tier (V3.1) | 3 backends + decode-first kernel portfolio + control room UI |
| **Continual learning** | NOT-STARTED | research-tier | research-tier | OSFT/PSOFT/coSO/DSC corrected stack + OFTv2 4-bit path + HCache / KVCrush / Titans-MAC / SEAL-DoRA / Never Retrain |
| **Skill / procedural / self-evolution** | LANDED | agent_runtime ships all three | — | A-MEM atomic notes + corrections.jsonl + background re-routing |
| **NightBrain** | PARTIAL | 10 task names registered | — | task bodies (NoOp placeholders today) |
| **A2UI catalog** | PARTIAL | NoteCard seed (1 of ~25) | — | 24 other components |
| **KV implantation / Glass Pipe / Weight Surgery** | NOT-STARTED | — | research-tier (V3.2) | full memory control room |
| **Simulation v1.6 → v1.7+** | PARTIAL | v1.6 Slice 3 LANDED (LandingFarm + Companion lifecycle + AgentProvenanceEvent + EventStore + biometric SovereignGate) | post V2.5 | full 13-state machine / sprite atlas / IOSurface / LoRA hot-swap |
| **Hermes positioning** | DOCTRINE | architectural positioning preserved | UI overlay PURGED 2026-05-05 | full L7 Cloud Gateway + capability HMAC tokens (XPC) |
| **Quick Capture** | PARTIAL | QC view + 25-file salvage triaged | — | 4-variant routing ladder / 6 OTHER salvage subdirs |
| **Vault doctrine** | MATCHES | LAContext + Secure Enclave + bookmarks + Spotlight + ModelActor | — | two-tier cache + bookmark integrity SHA-256 |
| **UI / UX / Brand** | PARTIAL | one composer + two modes + Provenance Console + landing hero + per-theme fonts | V2.6 | Cognitive Weight slider / Freeform Pulse + Rail / 8-setting irreducible-minimum |
| **Hardening floor** | MATCHES | harden_cli_subprocess + mas_runtime_preflight + Keychain + entitlements + MAS leak audits ZERO | — | XPC service contracts (paid-team-gated) |

---

## 6. The New Backlog — Codex-Actionable

Order respects: (a) **ship MAS first** per `MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md`; (b) **No-LLM-First** generalization clears the biggest doctrine debt; (c) every item links its source research doc(s).

### Wave A — Doctrine compliance retrofit (no Apple Developer subscription required)

| # | Task | Sources | Acceptance |
|---|---|---|---|
| A1 | **Wire `VariantLadder<I,O>` into `dispatcher.rs`** for one tool route end-to-end as proof-of-concept. Pick `vault.search` (existing FTS5 + embedding + RRF + LLM ladder). | `deterministicapp.md` §2.1, `COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` §5+§4.2 | Live caller in dispatcher; LadderLog row writes to Provenance Console; source-guard test pattern shipped per doctrine §4.2 |
| A2 | **Retrofit each existing tool route to declare its ladder** in the PR `## Variant Ladder` section per doctrine §4.1, even if the impl is unchanged. Append `CANONICAL_DRIFT_AUDIT` "Drift C" row → RESOLVED. | doctrine §4.1, Drift Audit | All ~30 tools in `ToolSurfacePolicy.coreAppStoreAllowedToolNames` carry a `## Variant Ladder` doc block |
| A3 | **Enforce `escalate_on_empty: false` default** + add `// VARIANT-LADDER-DEFER:` markers for any route that escalates Tier 4+ without user opt-in. | doctrine §6 | grep `VARIANT-LADDER-DEFER:` matches every Tier 4+ escalation OR PR rejected |
| A4 | **Add `reasoning` field ≤256 tokens before answer** — per-tier cap enforced at GBNF compile (Qwen 7B = 32 token "Brief Is Better"; bigger models = 256). | `deterministicapp.md` §1, `helios v3.md` | Grammar compile-time check; test covers Qwen 7B 32-tok + 7B 256-tok ceiling |
| A5 | **Add hybrid MD+JSON schemas**: `epistemos.soul.v1`, `epistemos.skill.v1`, `epistemos.episode.v1`, `epistemos.semantic.v1`. Schema-validated writes via existing MutationEnvelope; migration registry. | `deterministicapp.md` §5 | schemas pass schemars round-trip; MutationEnvelope rejects malformed |
| A6 | **Promote Cognitive Weight Class W1** from doctrine to live read-only metadata. Halo + composer expose 4-tier badge. | `COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` W1 acceptance bar | 4-tier badge renders on every loaded resource; policy_authority silently downgraded (W1 §6) |
| A7 | **Knowledge Sieve + Gap Winner Rule + No-Later-Simpler-Composite curriculum** for ClaimLedger ranking. | `ternary_reconceptualization.md`, `EPISTEMOS_FINAL_DOCTRINE` Annex A.11 | RRF k=60 fusion query gains "prime-composite-gap" boost; tests pin determinism |
| A8 | **`clarify` tool surface** — `clarify.ask` schema + UI card. The model emits a typed clarify request; user sees a dedicated card not a generic message. | `deterministicapp.md` §2.10, MAS Release Manifest | GenUI `clarify` schema + dispatcher + renderer; agent loop honors `clarify.ask` over open-ended message |
| A9 | **NightBrain task bodies** for the 10 registered names (replace NoOp). At minimum: `vault_consolidate`, `claim_evidence_decay`, `procedural_curate`, `companion_refresh`, `provenance_compact`. | NightBrain row in Drift Audit | each task has 1 deterministic test + 1 source-guard pinning the canonical name |

### Wave B — V6.1 floor work (precedes V6.2 kernel ladder)

| # | Task | Sources | Acceptance |
|---|---|---|---|
| B1 | **Vendor `oxieml` read-only crate** + `eml-lean` (verify zero sorry/admit). | V6.1 intake stage 1-2 | `cargo build` + `lake build` green; oxieml::EmlTree::eval_real is reference oracle |
| B2 | **Land `morph_eval_reduced.metal v0.1`** behind F-ULP-Oracle gate. | V6.1 intake stage 3 | shader file commits with no compile errors |
| B3 | **F-ULP-Oracle harness**: 412 k log-sampled + 2,048 stress points × ≤2 ULP fp16 × ≤90 s wall-clock on M2 Pro 16 GB. | V6.1 intake stage 4 | Rust integration test passes against `oxieml::EmlTree::eval_real`; fails morph_eval_reduced.metal if drift |
| B4 | **Freeze AnswerPacket schema (V6.1 §S3.5)** behind F-ULP-Oracle gate. | V6.1 intake stage 5 | schema version pin in Rust + Swift; round-trip parity test |
| B5 | **Pin Lean toolchain** to 4.29.1 + mathlib v4.29.0-rc6 + LeanCopilot CI-only. Sorry-budget ≤7/file, ≤266 total. | V6.1 intake stage 6 + helios v6.2 §S2 | CI gate; sorry-count README badge |

### Wave C — V6.2 kernel ladder (post V6.1 floor + paid Apple Developer for some)

Run in `V6_2_FALSIFIER_ORDER` exact dependency order. Each gate is a Metal kernel + falsifier harness.

| # | Task | Sources |
|---|---|---|
| C1 | **`PageGather.metal` baseline** STREAM-on-Metal probe → `BW_baseline_M2Pro` typically 63-73 GB/s sustained on M2 Pro 16 GB | `helios v6.2.md` §S1.1 |
| C2 | **`PageGather.metal` scatter** ≥70% of measured baseline over ≥1 s windows at {256 MB, 512 MB} buffers | §S1.2 |
| C3 | **Swift CPU `InterruptScore`** P99 <100 µs over 10⁵ trials | §S1.3 — **LANDED 2026-05-12**, verify still green |
| C4 | **`PacketRouter1bit.metal`** dispatch P99 <100 µs | §S1.4 |
| C5 | **`ControllerKernelPack.metal`** (6 fused micro-kernels) reference-equivalent vs Swift | §S1.5 |
| C6 | **`SemiseparableBlockScan.metal`** correctness vs PyTorch `ssd_minimal.py` Listing 1 (max-abs-diff ≤1e-3 fp16, 100 seeds) | §S1.6 |
| C7 | **`LocalRecallIsland.metal` 32K Core** 50 trials × 5 depths passkey ≥0.95, niah_single_1 ≥0.95 | §S1.7 |
| C8 | **RULER + BABILong harness** at 32K under 30 min wall-clock on M2 Pro 16 GB | §S1.8 |

### Wave D — Halo V1 closure + Eidos (V2.2)

| # | Task | Sources |
|---|---|---|
| D1 | **6-state Halo FSM** (dormant → watching → encoding → searching → available → open) — promote `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md` | `POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md` V2.2, `EPISTEMOS_FINAL_DOCTRINE` §4.3 |
| D2 | **Model2Vec encoder integration** | doctrine §4.3 |
| D3 | **Non-activating NSPanel surface** | doctrine §4.3 |
| D4 | **Eidos companion pairing** | doctrine + CANON_GAPS_AND_ADDENDA C9 |

### Wave E — SCOPE-Rex V2 hardening (post V6.2 falsifiers)

| # | Task | Sources |
|---|---|---|
| E1 | **Constrained action objective** argmin over (V/P/D/C/I/F) terms | `scope rex omega.md` §3 |
| E2 | **Sinkhorn-projected routing matrix** B* ∈ Birkhoff_n | same §4 |
| E3 | **Brain(τ) reconstruction rule** from checkpoint + semantic deltas | same §6 |
| E4 | **5 directional operators on claim graph** (Up/Down/Sideways/Inward/OnItself) | `ternary_reconceptualization.md`, `eml_universal_operator.md` |
| E5 | **9-arm Kleene K3 claim classifier** in `pi.rs` (currently 5-arm) | `helios v5 first.md` §1.5 |
| E6 | **Verified Research Mode UI labels** wired to label producer (currently `LatestAnswerPacketSink` chip read-only) | helios v5, FINAL_DOCTRINE Annex A.13 — **PARTIAL** (chip live, label producer is `AnswerPacketEmitter`) |

### Wave F — XPC Mastery (PAID-TEAM-GATED)

Unblocks when $99 Apple Developer Program subscription clears.

| # | Task | Sources |
|---|---|---|
| F1 | **Pay $99 Apple Developer Program** | `CANONICAL_RECOVERY_PLAN_2026_05_03.md` F.1 |
| F2 | **Restore App Group entitlement** `group.com.epistemos.shared` + restore App-Group-shared `arena.dat` | F.2, `Epistemos-AppStore.entitlements` header |
| F3 | **5-service XPC decomposition** (Main + VaultXPC + AgentXPC + ProviderXPC + WASMExecXPC) | `mac store edition.md`, XPC doctrine, V2.4 |
| F4 | **CapabilityGrant** HMAC-SHA256 + bitflags + time-limited + caveat narrowing | `hermes_gateway_architecture.md` |
| F5 | **mach-port signaling + xpc_shmem / IOSurface / FD passing** zero-copy data plane | `hermes.md`, `mac store edition.md` |
| F6 | **WASM exec service** (Wasmtime + Pyodide-WASM + QuickJS-WASM, ~16 MB, Winch + pulley-interpreter fallback) | `COGNITIVE_KERNEL_DOCTRINE` §6 |
| F7 | **In-process bundled MCP** `omega-mcp::inproc::*` for vault_ops / search / fetch / think / todo / calc | §7 |

### Wave G — Simulation v1.7+ (V2.5)

| # | Task | Sources |
|---|---|---|
| G1 | **Full 13-state animation machine** | `docs/fusion/simulation/DOCTRINE.md` |
| G2 | **Sprite atlas + instanced Metal quads** (16 invariants, especially I-15 + I-16) | DOCTRINE.md |
| G3 | **Tamagotchi specificity-recovery**: 50 sprites / 24 emotes / 60 FPS / deterministic idle-walk / reduce-motion static pose | `CANON_COMPLETENESS_AUDIT_2026_05_04.md` |
| G4 | **Hermes Snake as Graph Faculty (z+1 plane)** — NOT a Companion Farm citizen | CANONICAL_UNIFICATION_INVENTORY §4.3 |
| G5 | **LoRA hot-swap research spike** (50 × 50 MB LoRA per companion) | DAG doctrine §6 cost |

### Wave H — UI / UX V2.6

| # | Task | Sources |
|---|---|---|
| H1 | **Cognitive Weight slider** | `EPISTEMOS_FINAL_DOCTRINE` §4.0 |
| H2 | **Freeform Pulse + Residency Rail** | same |
| H3 | **8-setting irreducible-minimum UX** | `deterministicapp.md` §1 |
| H4 | **NousResearch SVG art** (licensing-gated; via `Epistemos/Hermes/` fallback per CANONICAL_UNIFICATION_INVENTORY §4.5) | HERMES_BRAND_DOCTRINE (superseded but assets remain valid for future use) |
| H5 | **Inter + JetBrains Mono OFL fonts** bundled | doctrine |

### Wave I — A2UI catalog expansion (24 remaining components)

| # | Task | Sources |
|---|---|---|
| I1-I24 | **24 components** (Table, Markdown, Chart, ProgressBar, KeyValueGrid, CapabilityChip, ProvenanceTrace, etc.) with schemars-derived schemas + Swift mirrors + Validator tests | Drift Audit A2UI row, `Epistemos/A2UI/` |

### Wave J — Research tier (V3, awaits "RESUME RESEARCH TIER")

J1 Ternary core (3 backends + decode-first kernel portfolio) · J2 KV implantation + Glass Pipe + Weight Surgery + SAE Cognition Observatory · J3 Continual learning suite (OFTv2 + DSC + Titans-MAC + SEAL-DoRA + Never Retrain) · J4 NeMoCLAW / OpenCLAW multi-claw MAS · J5 Hyper-Dynamic Schemas (Meta-Schemas that repair themselves) · J6 ACS recursive self-governance · J7 Sherry 1.25-bit + E8/Leech lattice VQ · J8 ANE Direct (`_ANEClient` via disable-library-validation) · J9 MLSys / NeurIPS papers.

All sources: `helios v3.md` / `EPISTEMOS_RESEARCH_LANDSLIDE.md` / `EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md` / `EPISTEMOS_NO_COMPROMISE_ARCHITECTURE.md` / `acs_meta_layer.md` / `ternary kernel.md` / `osft_psoft_coso_fusion.md` / `continual_learning_online.md` / `mas_architecture_research.md` / `mas_gate_upgrade.md` / kimi-latest definitive/capstone/mas_release / GPT Research Cargo workspace.

---

## 7. Acceptance bar for every PR in this backlog

Five-question discipline from `CANONICAL_RECOVERY_PLAN_2026_05_03.md` extended:

1. **Stage / Wave**: which Wave A-J does this PR target?
2. **GenUI route**: does this PR introduce a new renderer? If yes, must go through `GenUIDispatcher` per `COGNITIVE_GENUI_DOCTRINE` §6 (else `// GENUI-DEFER:` + audit row).
3. **Sovereign**: any destructive action class? Must route through canonical Sovereign Gate.
4. **Pro impact**: feature-gated via `#[cfg(feature = "pro-build")]` / `#if PRO_BUILD`? MAS build symbol-clean per `docs/MAS_RELEASE_MANIFEST_2026_05_13.md` §3?
5. **TEMP-FREE-TIER**: does this PR rely on App Groups / SMAppService / paid signing? If yes, add TEMP-FREE-TIER comment per `MAS_FIRST_FOCUS_DOCTRINE` §4.5.

**Plus three new questions for this floor:**

6. **Variant Ladder**: new tool route? PR includes `## Variant Ladder` section per `COGNITIVE_VARIANT_LADDER_DOCTRINE` §4.1.
7. **Atlas update**: PR adds / changes a concept named in §3 of this doc? PR appends a row.
8. **Disambiguation**: PR uses a polysemous term ("Shadow", "Helios", "Hermes", "Residency", "Tier", "WBO", "EML")? PR cites which §4 sense.

**Local-Canon-First protocol (`LOCAL_CANON_FIRST_SPECIFICITY_PROTOCOL_2026_05_04.md`) applies retroactively to every brief**: search user's literal phrases AND semantic siblings AND code symbol names AND donor/research roots BEFORE coding.

---

## 8. Complete research source index (Codex must consult per item)

### A. Top-floor doctrines (`docs/fusion/`)
EPISTEMOS_FINAL_DOCTRINE_2026_05_01 · EPISTEMOS_RECONCEPTUALIZATION_2026_05_03 · CANONICAL_RECOVERY_PLAN_2026_05_03 · POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04 · MAS_FIRST_FOCUS_DOCTRINE_2026_05_03 · COGNITIVE_KERNEL_DOCTRINE_2026_05_03 · COGNITIVE_DAG_DOCTRINE_2026_05_03 · COGNITIVE_GENUI_DOCTRINE_2026_05_03 · COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04 · COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04 · HONEST_HANDLE_FFI_DOCTRINE_2026_05_04 · LIVE_FILE_COMPILER_DOCTRINE_2026_05_04 · LOCAL_CANON_FIRST_SPECIFICITY_PROTOCOL_2026_05_04 · HERMES_BRAND_DOCTRINE_2026_05_04 (SUPERSEDED) · FIVE_LAWS_AND_PHASE_I_2026_05_04

### B. Audit / drift / canon-completeness
CANONICAL_DRIFT_AUDIT_2026_05_04 · CANON_COMPLETENESS_AUDIT_2026_05_04 · CANON_GAPS_AND_ADDENDA_2026_05_02 · CANONICAL_UNIFICATION_INVENTORY_2026_05_04 · CANONICAL_AUDIT_RECONCILIATION_2026_05_04 · MASTER_RESEARCH_INDEX_2026_05_02 · JORDANS_RESEARCH_INDEX_2026_05_03 · ALL_DOCS_INDEX_2026_05_02 · PRE_V2_FULL_AUDIT_2026_05_04 · PRE_V2_GAP_CLOSURE_SUMMARY_2026_05_04

### C. Helios canon chain
helios v2.md · helios v3.md · helios v5 first.md · helios v5 updated.md · helios v6.2.md · EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07 · EPISTEMOS_V6_2_CANON_INTAKE_2026_05_07 · HELIOS_V5_INTEGRATION_PLAN_2026_05_05 · HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05 · HELIOS_V5_DOC_0_INDEX · HELIOS_V5_DOC_6_THEOREM_CANON · HELIOS_KV_DIRECT_GATE_RUNBOOK_2026_05_03 · HELIOS_METAL_KERNELS_2026_05_03 · HELIOS_WBO6_BUDGET_2026_05_03

### D. Jordan's executive-add research (`docs/fusion/jordan's research/`)
deterministicapp.md (977L — the hyper-deterministic / variant ladder / GBNF / hybrid MD+JSON canon) · helios v2/v3.md · helios v5 first/updated.md · helios v6.2.md · mac store edition.md · hermes.md · scope rex omega.md · scope rex.md · ternary kernel.md · compass_artifact_wf-42f25075-...md · `Epistemos V6_1 — Final Synthesis Lock (Attention as Interrupt).pdf`

### E. Kimi deep research (`docs/fusion/jordan's research/kimis deep research/`)
EPISTEMOS_NO_COMPROMISE_ARCHITECTURE.md · EPISTEMOS_MASTER_ARCHITECTURE.md (7-layer cognitive substrate diagram) · EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md · EPISTEMOS_GAP_ANALYSIS.md · EPISTEMOS_RESEARCH_LANDSLIDE.md · EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT.md · EPISTEMOS_THIS_IS_WHERE_YOU_ARE.md · scope_rex_final_architecture.md · hermes_gateway_architecture.md · acs_meta_layer.md · osft_psoft_coso_fusion.md · ternary_spectral_architecture.md · ternary_code_scaffolds.md · ternary_reconceptualization.md · epistenos_build_plan.md · epistemos_capstone_unified.md · epistemos_definitive_master.md · epistemos_final_master_specification.md · epistemos_mas_release.md · helios_shadow_memory.md · plan.md · SIMULATION_MODE_V16_SUMMARY.md · VERIFICATION_REPORT_2026_05_03.md

### F. Kimi deep research / `research/` subdir
eml_universal_operator.md (EML stuff Jordan asked about) · meta_homeostasis.md · meta_resonance.md · osft_deep_research.md · psoft_deep_research.md · coso_deep_research.md · self_tuning_llms.md · continual_learning_online.md · plan_memory_breakthrough.md · mas_architecture_research.md · mas_gate_upgrade.md · macos_vault_system.md · landslide_dim01–dim10.md (speculative decoding / KV+prefix caching / biometric control / token cost / self-modification / multimodal ANE / neural editing / Apple Silicon / monetization / executive UI) · uasa_dim01–dim17.md + uasa_sec00–11.md (Universal Adaptive Sparse Architecture — deterministic substrate research) · recon_dim01-05 + redteam_{discrete_continuous, qlora_alternatives, scheduling, staged_verification, svd_acceleration, z3_overhead}.md · resonance_formal_impl.py · math_compression_structure.md · tequila.pdf · tsar.pdf · fairyfuse.pdf · hello_sme.pdf · eth_sparse_ternary.pdf

### G. Kimi-latest (`docs/fusion/research/kimi-latest/`)
epistemos_capstone_unified.md · epistemos_definitive_master.md · epistemos_final_master_specification.md · epistemos_mas_release.md · helios_shadow_memory.md · hermes_gateway_architecture.md · SIMULATION_MODE_V16_SUMMARY.md

### H. GPT Research (`docs/fusion/jordan's research/GPT Research/`)
Cargo workspace skeleton with crates / kernels / xpc / verification / bench + 24 .md (ARCHITECTURE, MEMORY_TIERS, CHANGELOG, SOURCE_INDEX, SELF_TUNING, API_SPEC, UNIVERSAL_PLASTICITY, RESONANCE_GATE, PAPER_DRAFT, SWIFT_UI, TEST_HARNESS, BUILD_GUIDE, CONTRIBUTING, WBO6_INEQUALITY, VAULT_GATED_SWARM, HERMES_GATEWAY, METAL_KERNELS, SECURITY_AUDIT, COMPETITOR_ANALYSIS, PLATFORM_GATES, VERIFICATION_REPORT, fusion/CONVERGENCE_AUDIT_2026_05_03, bench/G1_KV_DIRECT_GATE)

### I. User-authored research (`docs/fusion/research/user-authored/`)
CODEX_SCOPE_REX_SUBSTRATE_PROMPT_2026_05_01 · SCOPE_REX_GATE_REGISTER_2026_05_01 · deterministicapp.md · helios v2/v3.md · hermes.md · mac store edition.md · scope rex.md · scope rex omega.md · ternary kernel.md

### J. Compass artifacts + Quick Capture canon
COMPASS_ARTIFACT_2026_04_26.md · compass_artifact_wf-42f25075-c0fc-4bbd-bd73-cf78ac1af797_text_markdown.md · `/Users/jojo/Documents/Epistemos-QuickCapture/PLAN.md` · same dir `FINAL_SYNTHESIS.md` · `docs/fusion/salvage/from-vigorous-goldberg/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md`

### K. Simulation canon
`docs/fusion/simulation/DOCTRINE.md` (1982L; 16 invariants) · `docs/fusion/simulation/IMPLEMENTATION.md` (2597L) · `docs/fusion/simulation/SESSION_KICKOFF.md` · `docs/fusion/simulation/character-dna/{block_compact,block_wide,orb,sage,hermes_snake}.md`

### L. Salvage subdirs
`docs/fusion/salvage/from-vigorous-goldberg/` (Quick Capture canon) · `docs/fusion/salvage/from-codex-runtime-input-audit/` · `docs/fusion/salvage/from-agent-a0550f9c/` · `docs/fusion/salvage/from-lane-a/` · `docs/fusion/salvage/from-hermes-parity/` · `docs/fusion/salvage/from-simulation/` · `docs/fusion/salvage/from-stashes/`

### M. Recursive audit register + Codex prompt
`docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` (14,680L) · `docs/audits/CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md` (430L) · `docs/audits/codebase-verbatim-packets-2026-05-09/00_INDEX.md` + 22 packets · `docs/audits/V6_2_SESSION_PROGRESS_2026_05_12.md` · `docs/audits/V6_2_LAPTOP_MANUAL_AUDIT_CHECKLIST_2026_05_07.md` · `docs/audits/V6_2_PER_BUBBLE_BINDING_RESEARCH_2026_05_12.md` · `docs/audits/V1_RELEASE_AUDIT_2026_05_07.md` · `docs/audits/V1_DEEP_INTERACTION_AUDIT_2026_05_08.md` · `docs/audits/PERFORMANCE_CONCURRENCY_AUDIT.md` · `docs/audits/PRIVACY_APP_STORE_AUDIT.md` · `docs/audits/USER_WIRING_CAPABILITY_MAP.md` · `docs/audits/DATA_PERSISTENCE_INDEXING_AUDIT.md` · `docs/audits/PRE_HELIOS_FEATURE_AUDIT_2026_05_06.md` · `docs/CLI_CONFIG_COMPILATION_RESEARCH.md` · `docs/future-work-audit.md`

### N. Existing handoffs
`docs/CODEX_HANDOFF_2026_05_13_CHAT_TOOL_PARITY.md` (this session's chat-tool-parity handoff — read after this doc)

---

## 9. Codex acceptance bar

Codex's job on this doc:

1. **Read top-to-bottom** before starting any Wave A item.
2. **Confirm the Atlas (§3)** against current `main` — append any drift to a `## Atlas Drift` section at the bottom of this doc.
3. **Pick one Wave A item** to start (recommended: A1 — Variant Ladder dispatcher retrofit, because it clears Drift C with the highest ROI).
4. **For each Wave item shipped**, append a row to `## Implementation Log` at the bottom of this doc with: commit hash · file paths · acceptance evidence · WRV status.
5. **Run the §7 PR discipline (8 questions)** for every PR.
6. **Honor the protected surface (§1 rule 2)** — graph rendering / layout / edges / hologram visuals stay untouched.
7. **No silent compromises.** If a constraint forces a deferral, add a row to `## Compromises Recorded` at the bottom with: source doc / what was deferred / trigger to revisit.

---

## Implementation Log

(Codex appends rows here as Wave items ship)

| Date | Wave # | Commit | Acceptance evidence | WRV status |
|---|---|---|---|---|
| — | — | — | — | — |

## Compromises Recorded

(Codex appends here only when a constraint forces deferral — never silent)

| Date | Item | Source doc | Compromise | Trigger to revisit |
|---|---|---|---|---|
| — | — | — | — | — |

## Atlas Drift

(Codex appends here if §3 falls out of sync with `main`)

| Date | Atlas row | Stated status | Actual status | Action |
|---|---|---|---|---|
| — | — | — | — | — |

---

*— End of Master Fusion Backlog. Every named concept across the corpus is referenced in §3 with status, source, and code anchor. Every deferred concept has a row. Every collision has a §4 disambiguation. Every PR uses the §7 discipline. No drift.*
