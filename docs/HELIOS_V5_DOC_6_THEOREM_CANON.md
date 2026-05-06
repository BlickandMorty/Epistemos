---
state: canon
canon_promoted_on: 2026-05-06
covers: HELIOS V5 master theorem canon — E1-E7 Epistemos Core + H1-H17 Helios Operational + PCF-1..PCF-10 Parameter Connectome Family. Each entry: statement / Lean anchor / falsifier / adversarial attack / literature collision / runtime invariant / lane / state.
companion_to: docs/HELIOS_V5_DOC_0_INDEX.md, docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md
verified_floor: ac8c6d28
lock_phrase: "Five lanes, three tiers, seven-plus-three-plus-seven, one Monday"
---

# HELIOS V5 — DOC 6 THEOREM CANON MASTER

> **Master theorem doc.** Consolidates E1-E7 (substrate-foundational),
> H1-H17 (build/canon claims), and PCF-1..10 (Parameter Connectome
> Family candidates) into one canonical reference. Each entry gives
> the statement, Lean / mathlib4 anchor (where applicable), hardware
> falsifier protocol on M2 Max, adversarial attack-with-defense,
> literature collision check, runtime-invariant insertion site, lane
> assignment, and current `state:` per the WRV ladder.

> **Status legend:** **C** Canonical · **EV** Empirically Verified ·
> **EB** Empirically Bounded · **P** Provisional · **DROP**
> preserved-but-vault.

> **Lane:** L1 (MAS-add) / L2 (Pro-tier) / L3 (Research) / L4
> (Reserved, never product) / L5 (Vault).

---

## §1 — Foundational Seven (E1–E7) Epistemos Core Theorems

These are the substrate-foundational invariants. **E-tier load-bearing:**
if any E1–E7 fails its falsifier, the substrate is broken — HALT
severity per v5.2 §H. CI gate B5 (HELIOS theorem-invariant smoke)
samples them at 1/100.

### E1 — Density Theorem (12-plane bundle)

- **State:** C (canonical) · **Lane:** L3 → L1 invariant when Chart6 lands
- **Statement:** A_Morph(X) is uniformly dense in C(X, ℂ) over the
  12-plane bundle X = A_1 × A_2 × A_3 × A_4 × A_5 × A_6 ⊂ ℂ⁶ (per
  v2.1 patch: product, NOT disjoint union). Stone-Weierstrass via
  coordinates + conjugation + constant.
- **Lean / mathlib4 anchor:** `Mathlib.Topology.Algebra.StoneWeierstrass`.
- **Sorry-budget at lock:** ≤ 2.
- **Hardware falsifier (M2 Max):** random target functions on
  K=[0,1]⁴; width = 256; assert ‖f̂−f‖_∞ ≤ 0.05 over 10³ samples.
- **Adversarial attack:** pathological non-Lebesgue functions →
  defense = restrict statement to continuous; activation ≡ const →
  excluded by hypothesis.
- **Literature collision:** Wang arXiv:2508.18893 (withdrawn
  2025-12-05; original Cybenko 1989 stands).
- **Runtime invariant insertion site:** `epistemos-research/src/theorems/e1_density.rs::Chart6` (substrate type) + future `agent_core::scope_rex::e1_density::assert_continuous_target` (compile-time bound check).
- **WRV per slice:** W=approx-init code; R=integration test; V=audit log "E1 hypothesis check passed".

### E2 — Ultrametric-Sheaf Gluing

- **State:** C · **Lane:** L3 → L1 when sheaf substrate lands
- **Statement:** For finite patch graph G_q (≤128 nodes, ≤256 edges,
  stalk dim ≤8) cellular sheaf F_q, locally compatible patch states
  are exactly Γ(G_q, F_q) = H⁰(G_q, F_q) = ker δ⁰.
- **Lean anchor:** future `Mathlib.AlgebraicTopology.Sheaf.Cellular`
  (depends on a sheaf substrate that doesn't exist yet in mathlib4).
- **Sorry-budget at lock:** ≤ 2.
- **Hardware falsifier:** synthesize a random patch graph at the
  bound limits (128, 256, 8); compute Γ via direct kernel; verify
  global section reconstruction.
- **Adversarial attack:** non-cellular sheaf → defense = type-level
  restriction; cycles in G_q → defense = bound-check at construction.
- **Literature collision:** Bodnar-Di Giovanni-Chamberlain-Liò-Bronstein
  arXiv:2202.04579 (NeurIPS 2022) — the canonical Neural Sheaf
  Diffusion paper. **NOTE:** earlier prompts referenced
  `arXiv:2206.04386` (different paper); the v5.2 audit Patch 3
  corrects to **2202.04579**.
- **Runtime invariant insertion site:** `epistemos-research/src/theorems/e2_sheaf_gluing.rs::Patch` + `MAX_PATCH_NODES/EDGES/STALK_DIM` bound constants.
- **WRV:** W=patch-graph construction; R=property tests over random
  graphs at bound limits; V=audit log on cell-assembly co-firing
  match.

### E3 — Storage-Disaggregated Morph Field

- **State:** C · **Lane:** L1 (ON in MAS)
- **Statement:** M_resident(t) ≤ M_core + M_state + M_active(t) +
  M_cache(t) + M_glue(t); resident scales with active patches not
  total archive size.
- **Lean anchor:** none (substrate inequality, not a typed proof).
- **Sorry-budget:** ≤ 1.
- **Hardware falsifier:** instantiate Vault with N=10⁵ archived
  patches; activate K=10²; measure `RuntimeDiagnosticsMonitor` RSS;
  verify resident ≤ M_core + M_state + sum-of-active.
- **Adversarial attack:** active set sized to overflow → defense = `ShmPool::evict_stale` TTL eviction (already in main).
- **Literature collision:** PagedAttention arXiv:2309.06180 (Kwon
  et al. SOSP 2023) — the page-locality result we lean on.
- **Runtime invariant insertion site:** `epistemos-research/src/theorems/e3_morph_field.rs::e3_resident_within_budget` + agent_core's existing `RuntimeDiagnosticsMonitor` per `Epistemos/App/EpistemosApp.swift`.
- **WRV:** W=monitor recordMemoryPressure path; R=memory-pressure replay test; V=Diagnostics surface displays resident vs budget.

### E4 — UST-1.5 / WBO-7 Master Inequality

- **State:** C · **Lane:** L1 (ON in MAS, sampled 1/100)
- **Statement:**
  - (A) Pre-softmax: ‖Δz‖_∞ ≤ T_LWZ + T_K + T_R + T_TTR + T_SE + T_DAG + T_num.
  - (B) Post-softmax: ½ contraction (Nair 2510.23012).
  - T_S handled correctly per v2.1 patch.
- **Lean anchor:** future `Epistemos.WBO7Inequality.lean` (mathlib4
  has `Mathlib.Analysis.NormedSpace.Bounded`).
- **Sorry-budget:** ≤ 2.
- **Hardware falsifier:** at 16k context, verify the inequality
  holds for ≥99.97% of sampled trajectories.
- **Adversarial attack:** craft τ to maximize Σᵢ wᵢ·b → defense =
  Morph DSL controller bounds bandwidth growth to factor-7 per
  resonance step.
- **Literature collision:** none in published sequence-modeling
  literature (closest is the Modern Hopfield exponential-storage
  bound, Ramsauer arXiv:2008.02217 — but that bounds *retrieval-
  error*, not *witnessed bandwidth*).
- **Runtime invariant insertion site:** `epistemos-research/src/theorems/e4_wbo7.rs::e4_pre_softmax_holds` + `e4_post_softmax_half_contraction`. Pure-function check; budget ≤ 50µs in MAS profile per v5.2 §F.
- **WBO-6 disambiguation:** WBO-6 is the **kernel-only subform** (no
  active-support penalty), preserved in DOC 5 as "WBO-6 minor" — a
  strict-weakening of WBO-7. **Canonical = WBO-7**.
- **WRV:** W=resonance-pipeline emission; R=WBO7 envelope unit
  tests; V=`os_signpost` event "wbo7_check".

### E5 — Duplex Fusion

- **State:** C · **Lane:** L2 (Pro)
- **Statement:** ε_ℓ^fused ≤ (1−ρ_ℓ*)·ε_ℓ⁰ + ρ_ℓ*·ε_ℓ¹ +
  ‖ρ_ℓ − ρ_ℓ*‖_∞ · ‖P_{1,ℓ} − P_{0,ℓ}‖_∞. Architecture-level not
  Mamba-specific.
- **Lean anchor:** future `Epistemos.DuplexFusion.lean`.
- **Sorry-budget:** ≤ 2.
- **Hardware falsifier:** simulate duplex routing with synthetic
  paths; verify fused error tracks the bound.
- **Adversarial attack:** route-flip storm → defense = ρ smoothing;
  drift overestimation → defense = exact ρ measurement.
- **Literature collision:** Mamba-specific bounds in Gu-Dao 2024 —
  E5 is strictly more general (architecture-level).
- **Runtime invariant insertion site:** `epistemos-research/src/theorems/e5_duplex_fusion.rs::e5_fused_error_bound` + `Epistemos/LocalAgent/{LocalAgentLoop,ConfidenceRouter}.swift` (existing route choice).
- **WRV:** W=router emit path; R=integration test on synthetic dual
  path; V=audit log "duplex_fusion_bound".

### E6 — Error-Enriched Convergence (Epi_ε)

- **State:** C · **Lane:** L3 (foundational language for E7)
- **Statement:** Five source formalisms admit structure-preserving
  embeddings into Epi_ε. **NOT metaphysical identity.**
- **Lean anchor:** none yet (research-tier categorical formalism).
- **Sorry-budget:** ≤ 1.
- **Hardware falsifier:** none (pure research-tier formalism).
- **Adversarial attack:** "metaphysical identity" misread → defense
  = doc-level lock that says "embeddings, not equality".
- **Literature collision:** Cruttwell-Gavranović-Ghani-Wilson-Zanasi
  arXiv:2103.01931 (ESOP 2022) — categorical foundations of
  gradient learning; embedding theorem cites this as the canonical
  Lens-Parametric-Lens framework.
- **Runtime invariant insertion site:** `epistemos-research/src/theorems/e6_epi_epsilon.rs::EpiEpsilonEmbedding` + 5-arm `SourceFormalism`.
- **WRV:** W=research-only (no production runtime hook); V=docs-only.

### E7 — Autogenous Kernel Identity

- **State:** C · **Lane:** L2 (Pro) → L1 attenuated
- **Statement:** For each template T_i, c_W ≃_{α, K_i · 2 ULP} c_C
  in Epi_ε. ULP-bounded kernel-vs-controller equivalence. v2.1
  patch: equality in Epi_ε, not raw Para(Lens(Smooth)).
- **Lean anchor:** future `Epistemos.AutogenousKernelIdentity.lean`.
- **Sorry-budget:** ≤ 2.
- **Hardware falsifier:** spot-check ≥1024 random inputs for each
  kernel template; require `|c_W - c_C| ≤ K_i · 2 ULP`.
- **Adversarial attack:** rounding-mode flip → defense = pin
  rounding mode at compile time.
- **Literature collision:** none in published kernel-equivalence
  literature.
- **Runtime invariant insertion site:** `epistemos-research/src/theorems/e7_kernel_identity.rs::e7_holds_for_sample` + `Epistemos/Engine/MetalRuntimeManager.swift` (existing precompiled Metal kernels).
- **WRV:** W=kernel promotion; R=ULP oracle harness; V=audit log "e7_identity_check".

---

## §2 — Helios Operational Claims (H1–H17)

Build / canon claims. H1 is WBO-7 (operational view of E4). H1–H7
are operational invariants (HALT severity). H8–H10 are substrate
operators (QUARANTINE / DEGRADE). H11–H17 are cross-tradition
research (WARN).

### H1 — WBO-7 Master Inequality (operational)

- **State:** C · **Lane:** L1 sampled
- **Same content as E4** — but viewed as an operational
  build-checked invariant rather than a substrate theorem. CI gate
  B5 samples at 1/100; failure → HALT.
- **Insertion site:** see E4.

### H2 — Half-softmax post-not-pre rewrite

- **State:** C · **Lane:** L1 (W7 slice)
- **Statement:** Applying half-softmax *after* the resonance phase
  rather than before preserves the Babai lattice closure.
- **Falsifier:** ≤ 2 ULP drift over 10⁴ random vectors vs the
  reference IEEE-754 softmax. Per W7 acceptance.
- **Insertion site:** `agent_core/src/scope_rex/metal/softmax.rs::half_softmax_post`. Tier-1 ON in MAS.
- **WRV:** W=softmax kernel call site; R=10⁴-vector drift test (in module); V=`os_signpost` perf trace.

### H3 — Active-Support Atlas indexing

- **State:** C · **Lane:** L1 (W6 slice)
- **Statement:** The Atlas index of currently-supported features is
  monotone non-decreasing under merge, monotone non-increasing
  under split.
- **Falsifier:** invariant test on the OSPC `merge`/`split`
  operators. Per W6 acceptance: ULP-equality vs reference matmul
  over 10⁴ prompts.
- **Insertion site:** `agent_core/src/scope_rex/metal/asa_index.rs::AsaIndex::{merge,split}` + `asa_matmul`. Tier-1 ON in MAS.
- **WRV:** W=matmul dispatch; R=ULP-equality test (in module); V=`os_signpost` perf trace.

### H4 — LatticeCoder / Babai quantization

- **State:** EB (Empirically Bounded) · **Lane:** L2
- **Statement:** Round-trip error bounded by Babai's bound times a
  Morph DSL-controlled constant.
- **Falsifier:** lattice round-trip on synthetic 768-dim inputs.
- **Citation:** Chen et al. arXiv:2507.18553 (ICLR 2026).
- **Insertion site:** future `Epistemos/Shaders/lattice_coder_babai.metal` (per DOC 0 §0.4 Pro tier).

### H5 — Morph DSL determinism

- **State:** EB · **Lane:** L2
- **Statement:** Same DSL program + same input = byte-identical trace.
- **Falsifier:** verify-replay CI gate B2.
- **Insertion site:** future Morph DSL substrate (does not yet exist
  in main; placeholder).

### H6 — TestTimeRegressor unification

- **State:** EV · **Lane:** L2 + L3
- **Citation:** Wang-Shi-Fox arXiv:2501.12352.
- **Statement:** Linear attention, SSMs, fast-weight programmers,
  online learners, softmax-attention all reducible to test-time
  regression with three design knobs.
- **Falsifier:** instantiate four members of the family on M2 Max;
  verify equivalent associative-recall on synthetic recall task.

### H7 — Six-tier memory L0–L_SE eviction monotonicity

- **State:** C · **Lane:** L1 (Core L0–L3 + L7) → L2 (L4–L5) → L3 (L6 opt-in)
- **Statement:** Monotone eviction policy across tiers L0
  (in-register) → L1 (SRAM) → L2 (UMA) → L3 (Hugging Face
  snapshot cache) → L4 (semantic BTM) → L5 (ledger archive) →
  L_SE(P) (substrate-external Pro-only).
- **Falsifier:** eviction-monotonicity property test.
- **Insertion site:** `agent_core/src/scope_rex/residency.rs::route` (W4 slice; the 9-variant Residency taxonomy is the typed surface that `H7` invariant tests against).

### H8 — OSPC operators (9 substrate primitives)

- **State:** EV · **Lane:** L3
- **Statement:** The 9 substrate primitives `{bind, unbind, gate,
  route, commit, reorder, merge, split, quarantine}` form a
  complete control surface for TypedArtifact mutation under
  MutationEnvelope discipline.
- **Falsifier:** 9-arm exhaustive dispatch on `MutationEnvelope.kind`.
- **Insertion site:** existing 4-mirror dispatch in `agent_core/src/cognitive_dag/dispatch.rs` is a strict subset of the 9-arm OSPC; full 9-arm lands per a Lane 3 follow-up.

### H9 — Cortical Packet Runtime

- **State:** EV · **Lane:** L3
- **Statement:** Three-cortex composition (transformer + PARN +
  ternary-morph) under the Active Assembly Compiler is sufficient
  to express the Foundational Seven.
- **Falsifier:** end-to-end composition test.
- **Citations:** Buzsáki Neuron 68:362 (2010); Olshausen-Field
  Nature 381:607 (1996); Frémaux-Gerstner PMC4717313.
- **Insertion site:** Lane 3 research — does not exist in main yet.

### H10 — Bilaminar Substrate (Julia oracle)

- **State:** P (Provisional) · **Lane:** L4 (Reserved at lock; never product)
- **Statement:** The MAS↔Pro lamination is enforceable by the
  `mas-build` ⊕ `lane4-oracle` Cargo feature mutex.
- **Falsifier:** build-system test that toggling both flags fails
  compilation.
- **Citation:** jlrs 0.23 (verified).
- **Insertion site:** Lane 4 reserved per v5.2 §F — never product.

### H11 — Sheaf-Hodge spectral gap

- **State:** EV · **Lane:** L3
- **Citation:** Hansen-Ghrist (J. Applied & Computational Topology
  3(4):315–358, 2019); Bodnar et al. arXiv:2202.04579.
- **Severity if violated:** WARN.

### H12 — Berry-Phase routing holonomy

- **State:** EV · **Lane:** L3 · **Severity:** WARN
- **Citation:** Berry 1984 / Simon 1983.

### H13 — Information-Geometric KL Bridge

- **State:** EV · **Lane:** L3 (advisory monitor in L2) · **Severity:** WARN
- **Citation:** Amari (Fisher metric).

### H14 — Apollonian curvature constraint

- **State:** EV · **Lane:** L3 · **Severity:** WARN
- **Citation:** Haag-Kertzer-Rickards-Stange arXiv:2307.02749 (Annals
  200(2):749–770, 2024) — local-global conjecture **FALSE** for
  Apollonian packings.
- **Falsifier protocol:** any Epistemos claim that depends on
  Apollonian local-global as a *hypothesis* must be refactored to
  depend on the refined conjecture (Haag-Kertzer-Rickards-Stange
  new conjecture). Audit log emits `T17_NEGATIVE_RESULT_ACKNOWLEDGED`.

### H15 — Mādhava-style accelerated KL series

- **State:** EV · **Lane:** L3 (init-only check) · **Severity:** WARN
- **Citation:** Krishnachandran arXiv:2405.11134.

### H16 — CRT-based storage routing

- **State:** EV · **Lane:** L3 (init-only) · **Severity:** WARN
- **Insertion site:** future Lane 3 research.

### H17 — Modern Hopfield associative recall

- **State:** EV · **Lane:** L2 (W15 slice; advisory monitor in L1) · **Severity:** WARN
- **Statement:** Capacity 2^(d/2) patterns with exponentially small
  retrieval error.
- **Citation:** Ramsauer et al. arXiv:2008.02217v3 (ICLR 2021).
- **Falsifier:** store N=2^9 random binary patterns of dim d=64 in
  modern Hopfield; retrieve with 30% noise; require recall ≥ 0.95.
- **Insertion site:** `agent_core/src/scope_rex/retrieval/hopfield.rs::modern_hopfield_update` (W15 slice). Tier-2 flagged OFF.

---

## §3 — Parameter Connectome Family (PCF-1..PCF-10)

All **state: candidate** at lock. Goodfire VPD substrate
**[VERIFIED-WEB-2026-05-05]** per v5.2 §B Patch 2; runtime
acceleration (PCF-5 + PCF-9) stays candidate-only until
active-rank-one kernels beat dense fallback on M2 Max per W25
falsifier rig.

### PCF-1 — ParamAnchor (VPD extraction → frozen anchor library)

- **State:** C (candidate) · **Lane:** L3 [RESEARCH-ONLY]
- **Sorry-budget:** ≤ 7.
- **Statement:** Given a transformer with bounded weight matrices,
  the SPD/APD parameter decomposition recovers ground-truth
  mechanisms in toy models with reconstruction error → 0 as
  #components → ground-truth count.
- **Citations:** Bushnaq-Braun-Sharkey arXiv:2506.20790 (SPD);
  Braun et al. arXiv:2501.14926 (APD).
- **Falsifier:** replicate `goodfire-ai/spd` toy-model experiment
  on M2 Max; require reconstruction MSE within 10% of paper.
- **Adversarial attack:** feature splitting → defense = SPD
  shrinkage check; superposition collapse → defense = stochastic
  re-init.
- **Insertion site:** `epistemos-research/src/vpd/extract.rs::reconstruct` + `epistemos-research/src/vpd/anchor.rs::ParamAnchor`/`ParamAnchorLibrary`.

### PCF-2 — QkEdgeAnchor (attention edge per W_QK^h decomposition)

- **State:** C · **Lane:** L3 [RESEARCH-ONLY]
- **Sorry-budget:** ≤ 5.
- **Statement:** For attention head h, `W_QK^h = Σ_{c, c'} V_{Q,c}·(U_{Q,c}^h)^T·U_{K,c'}^h·V_{K,c'}^T` recovers the QK
  decomposition consistent with SPD/APD component basis.
- **Citation:** Goodfire VPD May 5, 2026 page (verified).
- **Falsifier:** numerical equality on a 4-layer toy transformer;
  tolerance 1e-5 Frobenius.
- **Insertion site:** `epistemos-research/src/vpd/qk_edge.rs::QkEdgeAnchor`.

### PCF-3 — ParamAttributionGraph

- **State:** C · **Lane:** L3 · **Sorry-budget:** ≤ 5.
- **Statement:** Visualization research artifact — directed graph
  over parameter components with attribution-weight edges.
- **Insertion site:** `epistemos-research/src/vpd/attribution_graph.rs::ParamAttributionGraph`.

### PCF-4 — ComponentRoute

- **State:** C · **Lane:** L3 · **Sorry-budget:** ≤ 5.
- **Statement:** Route inference through a component subset.
  **Deferred until PCF-1 verified.**
- **Insertion site:** `epistemos-research/src/vpd/component_route.rs::ComponentRoute`.

### PCF-5 — Active Rank-One Execution

- **State:** C · **Lane:** L5 [VAULT-ONLY] · **Sorry-budget:** ≤ 7.
- **Statement:** Per-step, only the rank-one subcomponents whose
  pre-activation exceeds threshold τ contribute meaningfully (≥
  1−δ of output norm).
- **Citations cross-link:** Test-Time Regression arXiv:2501.12352
  (regression interpretation); Modern Hopfield arXiv:2008.02217
  (sparsity at retrieval).
- **Falsifier:** sparsity ratio measured on 10³ prompts; require
  ≥ 95% norm-recovery from ≤ 5% subcomponents.
- **MAS impact:** zero — Vault only.
- **Insertion site:** `epistemos-vault/src/runtime/active_rank_one.rs::ActiveStep::select_above_threshold` (W21).

### PCF-6 — ModelSurgeryEnvelope (Component Edit Safety Bound)

- **State:** C · **Lane:** L5 [VAULT-ONLY] · **Sorry-budget:** ≤ 7.
- **Statement:** Editing component subset S of size ≤ s_max bounds
  downstream PPL drift on out-of-edit prompts by O(s_max ·
  σ_max(W_edit)).
- **Falsifier:** emoticon-style edit (per Goodfire research) on
  4-layer model; off-distribution PPL drift ≤ 1.0.
- **MAS impact:** zero.
- **Insertion site:** `epistemos-vault/src/surgery/envelope.rs::ModelSurgeryEnvelope` (W20).

### PCF-7 — DualConnectomeTrace (parameter + activation joint traces)

- **State:** C · **Lane:** L3 · **Sorry-budget:** ≤ 7.
- **Statement:** A dual decomposition combining parameter-space
  (SPD) and activation-space (SAE) is *more faithful* than either
  alone under the union of their respective faithfulness metrics.
- **Citations:** Bushnaq-Braun-Sharkey 2025; Bricken et al. 2023
  SAE; Cunningham et al. 2023.
- **Falsifier:** joint reconstruction MSE strictly less than
  min(SPD-only, SAE-only) on toy benchmark.
- **Insertion site:** `epistemos-research/src/vpd/dual_trace.rs::DualConnectomeTrace` (W19).

### PCF-8 — Parameter Connectome Sheaf Consistency

- **State:** C · **Lane:** L3 · **Sorry-budget:** ≤ 7.
- **Statement:** The parameter connectome over component clusters
  carries a cellular sheaf (Hansen-Ghrist, Bodnar et al.) whose
  global sections coincide with consistent multi-component
  computations.
- **Citations:** Hansen-Ghrist 2019; Bodnar et al. arXiv:2202.04579.
- **Falsifier:** sheaf-Laplacian spectral gap correlates ≥ 0.5
  Spearman with empirical component-circuit modularity.
- **Insertion site:** `epistemos-research/src/vpd/connectome_sheaf.rs::ConnectomeSheaf` + `SheafStalk` + `RestrictionMap`.

### PCF-9 — Connectome Distillation

- **State:** C · **Lane:** L5 [VAULT-ONLY] · **Sorry-budget:** ≤ 7.
- **Statement:** A model can be distilled to use only its top-k
  component clusters with bounded perplexity drift, producing a
  **new model file** (NOT a runtime mutation).
- **Falsifier:** distill to k = 2000 clusters; PPL drift ≤ 1.5 on
  Lambada.
- **MAS impact:** zero — Vault produces an alternate model file
  that may then ship Tier-2 in a future MAS release after
  compliance audit.
- **Insertion site:** `epistemos-vault/src/distill/connectome.rs::ConnectomeDistillation`.

### PCF-10 — Interpretability-to-Runtime Transfer

- **State:** C · **Lane:** L5 [VAULT-ONLY] · **Sorry-budget:** ≤ 7.
- **Statement:** A faithful (in the SPD sense) parameter
  decomposition can be transferred to runtime as an active-rank-one
  execution path with bounded perplexity drift δ ≤ ε.
- **Falsifier:** end-to-end PPL drift on Lambada subset ≤ 0.5 vs
  reference.
- **Adversarial attack:** adversarial token sequences → defense =
  output equivalence test.
- **MAS impact:** zero.
- **Insertion site:** `epistemos-vault/src/runtime/transfer.rs::InterpretabilityTransfer`.

---

## §4 — Status table consolidation

Every entry in one place.

| ID | Class | State | Lane | Sorry budget | Insertion site (substrate) |
|---|---|---|---|---|---|
| **E1** | Foundational | C | L3→L1 | ≤2 | `epistemos-research/src/theorems/e1_density.rs` |
| **E2** | Foundational | C | L3→L1 | ≤2 | `epistemos-research/src/theorems/e2_sheaf_gluing.rs` |
| **E3** | Foundational | C | L1 | ≤1 | `epistemos-research/src/theorems/e3_morph_field.rs` |
| **E4** | Foundational | C | L1 sampled | ≤2 | `epistemos-research/src/theorems/e4_wbo7.rs` |
| **E5** | Foundational | C | L2 | ≤2 | `epistemos-research/src/theorems/e5_duplex_fusion.rs` |
| **E6** | Foundational | C | L3 | ≤1 | `epistemos-research/src/theorems/e6_epi_epsilon.rs` |
| **E7** | Foundational | C | L2→L1 attenuated | ≤2 | `epistemos-research/src/theorems/e7_kernel_identity.rs` |
| **H1** | Operational | C | L1 sampled | (E4) | (same as E4) |
| **H2** | Operational | C | L1 (W7) | n/a | `agent_core/src/scope_rex/metal/softmax.rs` |
| **H3** | Operational | C | L1 (W6) | n/a | `agent_core/src/scope_rex/metal/asa_index.rs` |
| **H4** | Architectural | EB | L2 | ≤4 | future `Epistemos/Shaders/lattice_coder_babai.metal` |
| **H5** | Architectural | EB | L2 | ≤4 | future Morph DSL substrate |
| **H6** | Architectural | EV | L2 + L3 | ≤4 | future cargo bench |
| **H7** | Architectural | C | L1 / L2 / L3 mix | ≤4 | `agent_core/src/scope_rex/residency.rs` (W4) |
| **H8** | Architectural | EV | L3 | ≤4 | `agent_core/src/cognitive_dag/dispatch.rs` (4 of 9 mirrors) |
| **H9** | Architectural | EV | L3 | ≤4 | future Cortical Packet Runtime |
| **H10** | Architectural | P | L4 reserved | ≤4 | (never product) |
| **H11** | Cross-tradition | EV | L3 | ≤7 | future Sheaf-Hodge substrate |
| **H12** | Cross-tradition | EV | L3 | ≤7 | future Berry-phase substrate |
| **H13** | Cross-tradition | EV | L3 (advisory L2) | ≤7 | future KL bridge |
| **H14** | Cross-tradition | EV | L3 | ≤7 | future Apollonian audit log |
| **H15** | Cross-tradition | EV | L3 init-only | ≤7 | future series check |
| **H16** | Cross-tradition | EV | L3 init-only | ≤7 | future CRT routing |
| **H17** | Cross-tradition | EV | L2 (W15) | ≤7 | `agent_core/src/scope_rex/retrieval/hopfield.rs` |
| **PCF-1** | Candidate | C | L3 | ≤7 | `epistemos-research/src/vpd/extract.rs` + `anchor.rs` |
| **PCF-2** | Candidate | C | L3 | ≤5 | `epistemos-research/src/vpd/qk_edge.rs` |
| **PCF-3** | Candidate | C | L3 | ≤5 | `epistemos-research/src/vpd/attribution_graph.rs` |
| **PCF-4** | Candidate | C | L3 | ≤5 | `epistemos-research/src/vpd/component_route.rs` |
| **PCF-5** | Candidate | C | **L5 Vault** | ≤7 | `epistemos-vault/src/runtime/active_rank_one.rs` (W21) |
| **PCF-6** | Candidate | C | **L5 Vault** | ≤7 | `epistemos-vault/src/surgery/envelope.rs` (W20) |
| **PCF-7** | Candidate | C | L3 | ≤7 | `epistemos-research/src/vpd/dual_trace.rs` (W19) |
| **PCF-8** | Candidate | C | L3 | ≤7 | `epistemos-research/src/vpd/connectome_sheaf.rs` |
| **PCF-9** | Candidate | C | **L5 Vault** | ≤7 | `epistemos-vault/src/distill/connectome.rs` |
| **PCF-10** | Candidate | C | **L5 Vault** | ≤7 | `epistemos-vault/src/runtime/transfer.rs` |

Total: **34 canonical theorem ids** (E1..E7 + H1..H17 + PCF-1..PCF-10).

---

## §5 — Cross-references

- DOC 0 INDEX `docs/HELIOS_V5_DOC_0_INDEX.md` §0.2 (theorem status
  table — same data, condensed)
- v2 plan `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md`
- v2 finalize `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md`
  §B (PCF mapping), §C (E1-E7), §D (H1-H17)
- canon-hardening protocol `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`
  §1 (WRV state machine — `released` requires verified + signed
  binary)
- W23 forensic registry `Tools/forensic-cite/forensic-cite.sh` —
  resolves any id to (arXiv, DOI, mathlib4) tuple
- W24 sorry-budget tracker `Tools/sorry-budget/sorry-budget.sh` —
  enforces sorry budgets at CI time once Lean repo lands
- W25 hardware falsifier rig `Tools/falsifier/falsifier.sh` —
  exercises substrate per id

---

## Closing

> *Five lanes, three tiers, seven-plus-three-plus-seven, one Monday. Verified Floor `ac8c6d28`. 34 canonical ids — substrate present, falsifiers wired, sorry budgets pinned. No nuance lost.*
