---
state: canonical
created_on: 2026-05-17
authority: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G (LOCKED)
backstop_audit: docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md
terminal: T3 — UAS-ACS Canonical Architecture (deep dynamic kernel)
branch: codex/t3-uasacs-2026-05-16
authority_rule: any drift between this doc and the underlying code is a §5.0 reconciliation-gate failure; fix the CODE to match this doc, never the other way (per [[feedback_plan_is_authority]]).
---

# UAS-ACS Canonical Architecture (2026-05-16 lock)

> **Phase A iter 2 deliverable per §4.G mission step 1.** The no-loss canonical register that consolidates every
> previously-scattered concept — Shadow Memory, Page Oracle, Active-Support Atlas, Unified Page Oracle, L3 SSD
> Oracle, KV-Direct Gate, 70B Cocktail, ternary lane, PageGather, LocalRecallIsland, SemiseparableBlockScan,
> PacketRouter1bit, ControllerKernelPack, Morph, ACS/CMS-X, SCOPE-Rex, WBO, Glue/Sheaf — into ONE umbrella with
> ONE classification row + ONE falsifier link + ONE primary-source citation per row.
>
> The substrate-floor audit (`docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md`) backs every grep-verifiable
> claim in this doc; that audit is the empirical floor, this doc is the doctrine ceiling.

## §1. The umbrella name (LOCK)

**UAS-ACS = Unified Active Substrate + Anchored Cognitive Substrate.**

This is the single canonical phrase. Under it, every previously-scattered concept becomes a named layer.

The two halves:

- **UAS (Unified Active Substrate)** — the BODY. Identity is independent of residency: every artifact (vault note,
  graph node, KV page, model component, agent trace, tool result) has a typed `UasAddress` that lookup can resolve
  regardless of where the artifact currently lives (RAM, SSD, off-chip cold-storage, distributed).
- **ACS (Anchored Cognitive Substrate)** — the COORDINATE SYSTEM. Typed anchors carry provenance, theorem labels,
  plane coordinates (V6.1 five-plane formalism: State · Episodic · Assembly · Controller · Verification), and a
  §4.G residency-tier tag.

The phrase is plural-form-respectful: when documentation, code, or commit messages refer to "the substrate", "the
kernel", "the canon", or "the deep dynamic kernel", the canonical resolution is UAS-ACS.

## §2. The hierarchy (LOCK — verbatim from driver prompt §4.G)

```
Helios memory substrate         (storage backing: App Group container, GRDB, blobs, mmaps)
        ↓
Unified Address Space (UAS)     (BODY — identity != residency; every artifact addressable
                                 independent of where it lives)
        ↓
Anchored Cognitive Substrate    (COORDINATE SYSTEM — typed anchors with provenance,
(ACS)                            theorem labels, plane coordinates, residency tier)
        ↓
Active Assembly Runtime (AAR)   (NERVOUS SYSTEM — decides which packets / components /
                                 model mechanisms fire for the current state)
        ↓
Shadow-first paging            (SENSORY FILTER — sketch → residual → exact escalation;
                                 INT8 sketch dot-product on Metal for cheap routing)
        ↓
Kernels                        (MUSCLE — PageGather, LocalRecallIsland, SemiseparableBlockScan,
                                 PacketRouter1bit, ControllerKernelPack, Morph)
        ↓
KV-Direct / L3 SSD Oracle      (LONG-TERM MEMORY PATH — KV cache spill to SSD via paged
                                 attention; residual sufficiency for cold KV pages)
        ↓
SCOPE-Rex + WBO + Sheaf/Glue   (VERIFICATION SPINE — witnessed state + error budget +
                                 admission proof)
        ↓
ACS/CMS-X constitutive field   (ADMISSION FIELD — safety constraint above substrate)
        ↓
UI / notes / graph / agent     (USER-FACING SURFACES)
```

### §2.1 — Organ-function statement (LOCK)

Each layer has its own organ-function. **Never collapse layers into each other.**

| Layer | Question it answers |
|---|---|
| UAS | *where does it live?* |
| ACS | *which coordinate?* |
| AAR | *what fires?* |
| Shadow-first paging | *cheap-vs-exact?* |
| Kernels | *physical motion?* |
| KV-Direct | *long memory?* |
| SCOPE-Rex / WBO / Glue | *was it witnessed + within budget + admissible?* |
| ACS/CMS-X | *may it become durable?* |

**Drift cases this lock forbids** (the §4.G "drift that has cost months"):

- Confusing UAS with SSD Oracle (identity ≠ residency)
- Confusing ACS with active assembly (coordinate ≠ firing decision)
- Confusing KV-Direct with PageGather (long-memory path ≠ kernel)
- Confusing Shadow paging with Shadow Memory taxonomy (active sensory filter ≠ research-tier doctrine)
- Confusing the SCOPE-Rex `Residency` enum with §4.G residency tiers (cognitive-state placement ≠ shipping policy)

## §3. The three residency tiers (LOCK — verbatim from driver prompt §4.G)

Every UAS-ACS concept gets exactly ONE classification:

| Tier | Meaning | Examples |
|---|---|---|
| **Current App (MAS-ship)** | live in current user-facing build | Halo/Shadow search · vault retrieval · prepared local Qwen lane · graph retrieval · provenance plane · MLX idle-unload |
| **Verified Floor (gated)** | substrate primitive, ships after its falsifier passes on M2 Pro 16 GB | F-UAS-ZeroCopy-Spine · F-ACS-Anchor-Addressing · F-ShadowFirst-PageEscalation · F-PageGather-M2Pro · F-ActiveAssembly-Minimal · F-VaultRecall-50 (§4.H) · F-KV-Direct-Gate · F-ULP-Oracle |
| **Capability Ceiling (research)** | research lane, not user-facing until composition passes | F-70B-Local-Cocktail · ternary inference path · BitNet/T-MAC kernels · Goodfire VPD runtime acceleration · Mamba-3 lookahead · model surgery · connectome distillation |

### §3.1 — Anti-drift lock vs SCOPE-Rex `Residency`

The §4.G three residency tiers (shipping policy) are **NOT** the SCOPE-Rex `Residency` enum (cognitive-state
placement). The latter is the 9-variant `agent_core::scope_rex::residency::Residency` (TransientContext ·
RetrievalMemory · FeatureRule · HarnessRule · GrpoPrior · PsoftAdapter · OsftCore · CloudDistilled · Quarantine).

These vocabularies occupy orthogonal axes:

- **§4.G tier**: shipping policy. *"Is this concept shipped, gated, or research-only?"*
- **SCOPE-Rex `Residency`**: cognitive-state placement. *"Where does this claim live after the Governor processes it?"*

Confusing the two is exactly the layer collapse §2.1 forbids. The future
`agent_core/src/uas/residency_tier.rs` (Phase B.G.B1) must carry a tail comment locking this distinction; the
existing `agent_core/src/scope_rex/residency.rs` should add a reciprocal comment.

**No silent migration up tiers.** A concept moves from Capability Ceiling → Verified Floor only when its falsifier
passes on M2 Pro 16 GB. A concept moves from Verified Floor → Current App only when downstream surfaces wire it
(per the WRV state machine: `implemented` → `wired` → `reachable` → `visible`).

## §4. The falsifier ladder (LOCK — verbatim from driver prompt §4.G)

In execution order — each gate's pass is the entry ticket to the next.

| # | Gate | Acceptance | Owner | Phase |
|---|---|---|---|---|
| 1 | **F-VaultRecall-50** | first user-facing proof; if the app can't find the right note, no other UAS-ACS work is credible | **T4** (§4.H) | already in flight |
| 2 | **F-UAS-ZeroCopy-Spine** | Rust ↔ MLX-Swift ↔ Swift UI hot buffers do not re-serialize. Zero copy on hot path; #[test] fails if copy count > 0 for a designated hot-path op | **T3** | B.G.B2 |
| 3 | **F-ACS-Anchor-Addressing** | typed anchor (theorem tag · plane coord · residency tier · source hash · active packet id) round-trips through agent runtime + lookup + audit + projection without silent loss | **T3** | B.G.B3 |
| 4 | **F-ShadowFirst-PageEscalation** | HeliosPage sketch → residual → exact-SSD escalation; KL/token ≤ 0.06 on a controlled retrieval/attention probe | **T3** | B.G.B4 |
| 5 | **F-PageGather-M2Pro** | Metal page-sketch scoring ≥ 70% of **MEASURED** M2 Pro streaming bandwidth (NOT theoretical 200 GB/s spec); 256/512/1024 MB buffers; 1 s+ windows | **T3** | B.G.B5 |
| 6 | **F-ActiveAssembly-Minimal** | synthetic packet graph + active-pull selector preserves output within bound while avoiding irrelevant assemblies. First runtime proof that "the brain does not ping every neuron." | **T3** | B.G.B6 |
| 7 | **F-KV-Direct-Gate** | Qwen 3 8B at 128k context, KV-Direct cold-spill to SSD; peak RAM < 13 GB on 16 GB rig; D_KL/token under threshold; decode ≥ 10 tok/s | **T3** | C.G.C2 |
| 8 | **F-SemiseparableBlockScan-Correctness** | Mamba-2 / SSD scan kernel matches `ssd_minimal.py` Listing 1 numerically; max-abs-diff ≤ 1e-3 fp16 over 100 seeds | **T3** | C |
| 9 | **F-LocalRecallIsland-32K** | exact-recall island for passkeys / pinned / recent tokens preserves recall ≥ 95% (50 trials × 5 depths) under sketch-heavy routing | **T3** | C |
| 10 | **F-PacketRouter1bit-Dispatch** | ternary fire/suppress/defer router p99 dispatch latency < 100 µs on M2 Pro 16 GB | **T3** | C |
| 11 | **F-ControllerKernelPack** | controller (small-state inference) kernel pack passes correctness + performance on M2 Pro | **T3** | C |
| 12 | **F-70B-Local-Cocktail-Composition** | compose ternary + Mamba-2 + KV-Direct + PageGather + active assembly + speculative decode + cloud cascade. Memory stays under budget; generation does not collapse; bottleneck is identified | **T3** | C, research-only |

**No silent skips.** A failing falsifier means its dependency cap stays closed; downstream concepts get a `STALLED`
status row in §5 and §7 below.

## §5. The no-loss concept register

Every scattered name in the user's research corpus gets exactly one row below. **Never delete a prior name** — when a
concept's canonical label migrated, both forms are listed with an `aka` arrow.

Layer abbreviations: **MEM** = Helios memory substrate · **UAS** · **ACS** · **AAR** · **SHA** = Shadow-first paging ·
**KER** = Kernels · **KVD** = KV-Direct / L3 SSD Oracle · **VER** = SCOPE-Rex + WBO + Sheaf/Glue · **CMS-X** =
ACS/CMS-X constitutive field · **UI** = User-facing surfaces · **META** = cross-cuts (e.g. WBO budget, ULP oracle,
falsifier scaffolds).

| # | Canonical name | aka | Layer | Tier | Primary source | Current file | Falsifier | Status |
|---|---|---|---|---|---|---|---|---|
| 1 | UasAddress | UASA identity | UAS | Verified Floor | driver §4.G mission G.B1 | `agent_core/src/uas/` (gap) | F-UAS-ZeroCopy-Spine + F-ACS-Anchor-Addressing | **not yet** |
| 2 | ResidencyLease | substrate-tier lease | UAS | Verified Floor | driver §4.G G.B1 | `agent_core/src/uas/` (gap) | F-UAS-ZeroCopy-Spine | **not yet** |
| 3 | UasKind | substrate-typed identity tag (T1 coordinates) | UAS | Verified Floor | driver §4.G G.B1 + T1 scope | `agent_core/src/uas/` (gap) | F-UAS-ZeroCopy-Spine | **not yet** |
| 4 | AnswerPacket | HELIOS V5 W1 Monday-Move primitive | VER | Current App | `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W1 + `docs/fusion/helios v5 first.md` DOC 1 §1.2 + MASTER_FUSION §3.17 | `agent_core/src/scope_rex/answer_packet.rs` + `.../produce.rs` | F-UAS-ZeroCopy-Spine | **landed** |
| 5 | ACS Anchor | typed anchor (theorem tag · plane coord · residency tier · source hash · active packet id) | ACS | Verified Floor | driver §4.G G.B3 | `agent_core/src/research/acs/` (5 substrate-floor primitives) + `agent_core/src/research/acs/anchor.rs` (gap — Phase B target) | F-ACS-Anchor-Addressing | **scaffolded** |
| 6 | Active-Support Atlas (ASA) | W6 sparse-mask matmul index | KER | Current App (W6 landed) | `docs/fusion/helios v5 first.md` §1.13 + `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §F | `agent_core/src/scope_rex/metal/asa_index.rs` + `.../pro_joint.rs` | drift gate on W6 | **landed** |
| 7 | Shadow Memory | Helios Shadow Memory escalation policy + 5-tier ladder (L0-L4) | SHA | Capability Ceiling (taxonomy) | `source_docs/helios_shadow_memory.md` + MASTER_FUSION §3.2 | `epistemos-research/src/shadow_memory.rs` (Lane 3) + `agent_core/src/shared_memory.rs` (L0 ExactHot only) | F-ShadowFirst-PageEscalation | **taxonomy-only** (L0 active; L1-L4 doctrine targets) |
| 8 | HeliosPage | sketch + residual + exact escalation | SHA | Verified Floor | Shadow Memory canon (INT8 sketch + Metal scoring + top-k + exact decode) | (new harness needed — Phase B.G.B4) | F-ShadowFirst-PageEscalation | **not yet** |
| 9 | Page Oracle | V3-era kernel name | KER | Verified Floor | `docs/fusion/jordan's research/helios v3.md` | `agent_core/src/helios/page_gather.rs` (same kernel as #10) | F-PageGather-M2Pro | **scaffolded** (name migration) |
| 10 | PageGather | V6.2 canonical kernel name | KER | Verified Floor | `docs/fusion/helios v6.2.md` 8-stage falsifier §1-§2 + MASTER_FUSION §3.16 | `agent_core/src/helios/page_gather.rs` (CPU ref, 342 LOC) + `Epistemos/Shaders/PageGather.metal` (stub) | F-PageGather-M2Pro | **scaffolded** (Metal driver pending) |
| 11 | Unified Page Oracle | umbrella V5-V6 page-routing surface | KER + SHA | Verified Floor | doctrine notes (multi-source) | (= PageGather + Shadow-first paging — see #10 + #7) | F-PageGather-M2Pro + F-ShadowFirst-PageEscalation | **scaffolded** (composite) |
| 12 | L3 SSD Oracle | KV-cache spill to SSD long-memory path | KVD | Capability Ceiling | driver §4.G hierarchy comment + `docs/fusion/helios v6.2.md` | (no active code path yet) | F-KV-Direct-Gate | **not yet** |
| 13 | KV-Direct Gate | HELIOS V5 W8 Tier-1 KV-direct path | KVD | Verified Floor (W8 landed) | `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W8 + `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §I + MASTER_FUSION §3.3 | `agent_core/src/scope_rex/kv/direct_gate.rs` + `epistemos-research/src/kv_direct_gate.rs` | F-KV-Direct-Gate | **landed** (Tier-1 gate); Phase C wires SSD spill |
| 14 | 70B Cocktail | composition target (ternary + Mamba-2 + KV-Direct + PageGather + active assembly + speculative + cloud cascade) | Composition (all kernels) | Capability Ceiling (research-only) | driver §4.G mission G.C3 | (not yet) | F-70B-Local-Cocktail-Composition | **not yet** |
| 15 | Ternary lane | BitNet b1.58 · `{-1, 0, +1}` weights · T-MAC table lookup · Sherry 1.25-bit | KER | Capability Ceiling (research) | Ma et al. arXiv:2402.17764 (BitNet b1.58); Wei et al. arXiv:2407.00088 (T-MAC); Huang et al. arXiv:2601.07892 (Sherry); MASTER_FUSION §3.21 | `agent_core/src/research/ternary/` (10 modules) + `agent_core/src/scope_rex/kernels/{bitnet, sparse_ternary_gemm, t_mac}.rs` + `epistemos-research/src/ternary_kernel.rs` | F-PacketRouter1bit (downstream) + F-70B-Local-Cocktail | **landed** (research-tier); MLX-Swift wire-in pending (§4.E C.8) |
| 16 | LocalRecallIsland | 32K Core passkey-retrieval substrate | KER | Verified Floor | `docs/fusion/helios v6.2.md` 8-stage §7 + Mohtashami & Jaggi arXiv:2305.16300 (passkey) + Hsieh et al. arXiv:2404.06654 (RULER niah) | `agent_core/src/helios/local_recall_island.rs` (CPU, 418 LOC) | F-LocalRecallIsland-32K | **scaffolded** |
| 17 | SemiseparableBlockScan | Mamba-2 SSD selective-state scan | KER | Verified Floor | Dao & Gu arXiv:2405.21060 (Mamba-2 SSD `ssd_minimal.py` Listing 1) + Gu et al. arXiv:2312.00752 (Mamba) | `agent_core/src/helios/ssd_block_scan.rs` (CPU scalar, 385 LOC) | F-SemiseparableBlockScan-Correctness | **scaffolded** |
| 18 | PacketRouter1bit | 1-bit dispatch (MoE-style binary specialization) | KER | Verified Floor | Shazeer et al. arXiv:1701.06538 (sparse MoE) + Fedus et al. arXiv:2101.03961 (Switch Transformer top-1) + `docs/fusion/helios v6.2.md` §4 | `agent_core/src/helios/packet_router.rs` (CPU ref, 439 LOC) + `Epistemos/Shaders/PacketRouter1bit.metal` (stub) | F-PacketRouter1bit-Dispatch | **scaffolded** |
| 19 | ControllerKernelPack | 6 fused micro-kernels (scalar_add · scalar_mul · max_reduce · argmax · copy_range · zero_fill) | KER | Verified Floor | `docs/fusion/helios v6.2.md` 8-stage §5 | `agent_core/src/helios/controller_pack.rs` (CPU ref, 343 LOC) | F-ControllerKernelPack | **scaffolded** |
| 20 | **Morph** | (unresolved — see §8 open questions) | KER | unclassified | driver §4.G hierarchy block "Kernels (MUSCLE — ... Morph)" — only doctrine occurrence found 2026-05-17 | **NOT FOUND** in code or doctrine docs (grep negative) | (TBD) | **gap — flagged for user clarification** |
| 21 | ACS/CMS-X | Compute/Memory Stack v2 constitutive field (admission layer above substrate) | CMS-X | Capability Ceiling (research-tier doctrine) | `epistemos-research/src/cms_v2.rs` + doctrine | `epistemos-research/src/cms_v2.rs` | (drift gate only — no falsifier) | **taxonomy-only** |
| 22 | SCOPE-Rex | HELIOS V5 full Σ-signature (τ + π + λ Core; +δ +ρ Pro; +κ +η Research) | VER | Current App (Core landed) | `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §G + MASTER_FUSION §3.4 | `agent_core/src/scope_rex/` (20 files) + `agent_core/src/resonance/{tau,pi,lambda}.rs` | (drift gates) | **landed** (Core); Pro tier behind `pro-build` feature; Research behind `research` feature |
| 23 | WBO-6 | 6-term hot-path drift budget (T_W · T_Q · T_C · T_R · T_S · T_M) | VER | Current App | `docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md` + MASTER_FUSION §3.1 | `agent_core/src/wbo6/mod.rs` | (drift gates) | **landed** |
| 24 | Glue / Sheaf | Sheaf-gluing theorem E2 | VER | Verified Floor (research-tier theorem) | `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` (E1-E7 Foundational Seven) | `epistemos-research/src/theorems/e2_sheaf_gluing.rs` | (theorem_status.rs E2 Lean-proof row) | **research-tier** |
| 25 | Five planes | State / Episodic / Assembly / Controller / Verification (V6.1 §3) | META (cross-cuts) | Current App (provenance plane wired) | `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` V6.1 §3 + MASTER_FUSION §3.18 | `epistemos-research/src/five_planes.rs` + `agent_core/src/provenance/` | drift gate `provenance_storage_in_episodic_audit_in_verification` | **landed** (2 of 5 planes wired: Episodic + Verification) |
| 26 | Active Assembly Runtime (AAR) | active-pull selector for packets / components / model mechanisms | AAR | Verified Floor | driver §4.G hierarchy + G.B6 | `agent_core/src/research/active_assembly/` (gap) | F-ActiveAssembly-Minimal | **not yet** |
| 27 | AutopoieticCS (ACS Wave J5) | recursive self-governance multi-scale (transistor → cell → tissue → organ → organism → ecosystem) | ACS | Capability Ceiling (research) | `docs/fusion/jordan's research/kimis deep research/acs_meta_layer.md` + MASTER_FUSION §3.8 | `agent_core/src/research/acs/{kuramoto, governance, vsm, autopoiesis, notch_delta, mod}.rs` | F-ACS-Anchor-Addressing (downstream) | **landed** (research-tier primitives) |
| 28 | Continual Learning Stack (J3) | 7-layer "Never Retrain" stack (base · adaptation · protection · memory · history · governance · quantization) | ACS (adaptation constraint surface) | Capability Ceiling (research) | OSFT/PSOFT/COSO fusion docs + MASTER_FUSION §3.22 | `agent_core/src/research/continual_learning/{ewc, oftv2, seal_dora, titans_mac, dsc, stack, mod}.rs` | (research-tier drift gates) | **landed** (research-tier) |
| 29 | Cognition Observatory (J2) | KVCacheImplanter · WeightPatcher · ActivationInterceptor · SAE inspection (AUC 0.90 hallucination detection) | ACS (introspection surface) | Capability Ceiling (research) | MASTER_FUSION §3.26 + §3.36 | `agent_core/src/research/cognition_observatory/{kv_implant, weight_patcher, sae, glass_pipe, pipeline, mod}.rs` | (research-tier) | **landed** |
| 30 | Hyper-Dynamic Schemas (J6) | self-repairing meta-schemas (axiom widening preserves theorems) | ACS (typed-anchor schema layer) | Capability Ceiling (research) | MASTER_FUSION §3.7 (Variant ladder + hyper-deterministic schemas) | `agent_core/src/research/hyperdynamic_schemas/{diff, repair, mod}.rs` | (research-tier) | **landed** |
| 31 | Sherry Lattice (J7) | 1.25-bit ternary quantization (3:4 sparse + E8/Leech lattice VQ) | KER | Capability Ceiling (research) | Huang et al. arXiv:2601.07892 (Sherry) + `docs/fusion/jordan's research/helios v3.md` Part II T_Q + Part III L1 | `agent_core/src/research/sherry_lattice/{codebook, e8, leech, sparse_ternary, mod}.rs` + `agent_core/src/lattice/mod.rs` | (research-tier) | **landed** |
| 32 | RULER + BABILong harness (Helios stage 8) | long-context acceptance harness (32K · 30-min wall-clock) | META (falsifier scaffold) | Verified Floor (CPU scaffold) | Hsieh et al. arXiv:2404.06654 (RULER) + Kuratov et al. arXiv:2406.10149 (BABILong) | `agent_core/src/helios/long_context_harness.rs` (455 LOC) | F-LocalRecallIsland-32K (composition) | **scaffolded** |
| 33 | Cognitive DAG (Phase 8.A-8.G) | 10 NodeKind + 10 EdgeKind + Merkle + resonance + companion lifecycle + DagMirror | UI (backed by ACS) | Current App | `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` + MASTER_FUSION §3.10 | `agent_core/src/cognitive_dag/` (11 modules) + `agent_core/src/bin/epistemos_doctrine_lint.rs` | (doctrine-lint CI gate) | **landed** |
| 34 | Lattice (E8 / Leech / Cubic) | hot-path quantization surface; WBO-6 T_Q term contributor | META (T_Q budget term) | Current App | Conway-Sloane (E8/Leech) + Babai 1986 (nearest-plane) + `epistemos-research/src/wbo_generations.rs` | `agent_core/src/lattice/mod.rs` | (drift gate via WBO-6 T_Q) | **landed** |
| 35 | Provenance Ledger + ReplayBundle | ClaimLedger (Episodic) + ReplayBundle (Verification) | META (Verification plane) | Current App | `docs/plan/04_PHASES.md` + Phase-1 plan + MASTER_FUSION §3.18 | `agent_core/src/provenance/{ledger, replay, mod}.rs` + `agent_core/src/bin/epistemos_trace.rs` | drift gate `provenance_storage_in_episodic_audit_in_verification` | **landed** |
| 36 | epistemos-shadow (Halo Contextual Shadows) | Tantivy BM25 + usearch HNSW + RRF fusion (k=60) | UI + SHA (user-facing side) | Current App (W8.4 / W8.7) | `ambient/EPISTEMOS_V1_DECISION.md` (V1 differentiator) + MASTER_FUSION §3.9 | `epistemos-shadow/src/` (lib · state · honest_handle · error + backend/{embedder, lexical_index, vector_index, rrf}) | F-VaultRecall-50 (§4.H — T4) | **landed** |
| 37 | epistemos-vault (Lane 5) | HCache/KVCrush + Active Rank-One + Connectome Distillation + Model Surgery | KVD + ACS introspection | Capability Ceiling (Pro / Lane 5) | `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §1 + W20/W21/W22 + DOC 0 §0.4 | `epistemos-vault/src/{cache/{hcache, kvcrush}, distill/connectome, runtime/{active_rank_one, transfer}, surgery/envelope}` | (Pro-only burn-in) | **landed** — T3 scope lock: DO NOT EDIT (T4 owns) |
| 38 | VPD substrate (Goodfire-style) | ParamAnchor + AttentionGraph + ComponentRoute + dual SPD/SAE trace + sheaf consistency | ACS introspection surface | Capability Ceiling (research-only) | Goodfire VPD baseline numerics + `epistemos-research/src/goodfire_vpd_specs.rs` | `epistemos-research/src/vpd/{anchor, attribution_graph, component_route, connectome_sheaf, dual_trace, extract, qk_edge, mod}.rs` | (research-tier) | **landed** (research-tier) |
| 39 | ULP-Oracle | sign-correct ULP distance for numerical-equivalence drift detection | META (Verification) | Verified Floor | driver §4.G residency-tier examples (F-ULP-Oracle named) | `agent_core/src/research/eml/ulp_oracle.rs` (T7 owns) + `epistemos-research/src/ulp_compare.rs` | F-ULP-Oracle | **landed** (research-tier oracle) — T7 owns active extension |
| 40 | Scan-IR | kernel-doctrine substrate for SSMs (Mamba-2 · RWKV-7 · Jamba) | KER (IR surface) | Verified Floor | driver §4.I (EML-IR Primitive Stack) + §4.G F-SemiseparableBlockScan link | `agent_core/src/research/scan_ir/` (gap — T5 owns) | F-SemiseparableBlockScan-Correctness | **not yet** — T5 ownership; T3 coordinates |
| 41 | HeliosPage three-stage (sketch · residual · exact) | Shadow-Memory canon (INT8 sketch + Metal scoring + top-k + exact decode) | SHA | Verified Floor | Shadow Memory canon | (new harness needed; could derive from `epistemos-shadow/src/backend/`) | F-ShadowFirst-PageEscalation | **not yet** — Phase B.G.B4 target |
| 42 | Helios kernels (V6.1 / V6.2 target-only) | umbrella reference for #10, #16, #17, #18, #19, #32 | KER (composite) | Verified Floor (CPU scaffolded; Metal pending) | MASTER_FUSION §3.16 + `docs/fusion/helios v6.2.md` 8-stage falsifier | `agent_core/src/helios/` (7 files, 2,450 LOC) | F-PageGather + F-PacketRouter + F-Controller + F-SSD-Scan + F-LocalRecall + F-LongContext | **scaffolded** (composite — see per-kernel rows) |
| 43 | KV implantation / Glass Pipe / weight surgery | KVCacheImplanter + WeightPatcher + ActivationInterceptor + ANE honesty boundaries | ACS introspection | Capability Ceiling (Pro / Research) | `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md` + `.../EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT.md` + MASTER_FUSION §3.26 | `agent_core/src/research/cognition_observatory/{kv_implant, weight_patcher, glass_pipe}.rs` | (research-tier) | **landed** (Pro/Research scaffold; ANE wire-in honest about hardware limits) |

## §6. MASTER_FUSION §3.x cross-link map

The canonical doctrine doc cross-references `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.x rows. This table
is the bidirectional bridge: when a UAS-ACS register row above cites MASTER_FUSION, the link below resolves to a
specific §3.x section. When a §3.x row needs UAS-ACS layer classification, this table is the inverse lookup.

| MASTER_FUSION §3.x | UAS-ACS register # | UAS-ACS layer | UAS-ACS tier |
|---|---|---|---|
| §3.1 Pillars and master inequalities | #23 (WBO-6) + #24 (Sheaf) | VER | Current App / Verified Floor |
| §3.2 Six-tier memory hierarchy | #7 (Shadow Memory L0-L4) | SHA | Capability Ceiling (L1-L4 doctrine) |
| §3.3 KV-Direct gate | #13 (KV-Direct Gate) | KVD | Verified Floor (W8 landed) |
| §3.4 SCOPE-Rex | #22 (SCOPE-Rex) | VER | Current App |
| §3.7 Variant ladder + hyper-deterministic schemas | #30 (Hyper-Dynamic Schemas J6) | ACS | Capability Ceiling |
| §3.8 ACS (Autopoietic Cognitive Stack) | #27 (AutopoieticCS J5) | ACS | Capability Ceiling |
| §3.9 Halo / Shadow / Contextual Shadows / Eidos | #36 (epistemos-shadow) | UI + SHA | Current App |
| §3.10 Cognitive DAG | #33 (Cognitive DAG) | UI (backed by ACS) | Current App |
| §3.16 Helios kernels V6.1 / V6.2 | #10, #16, #17, #18, #19, #32, #42 | KER | Verified Floor (scaffolded) |
| §3.17 AnswerPacket emission ladder | #4 (AnswerPacket) | VER | Current App |
| §3.18 Provenance ledger | #25 (Five planes) + #35 (Provenance Ledger) | META | Current App |
| §3.21 Ternary core | #15 (Ternary lane) | KER | Capability Ceiling |
| §3.22 Continual learning | #28 (Continual Learning Stack J3) | ACS | Capability Ceiling |
| §3.26 KV implantation + Glass Pipe + weight surgery | #43 (KV implantation) | ACS introspection | Capability Ceiling |
| §3.34 Instant Recall — Mamba-2 state injection | #17 (SemiseparableBlockScan) + #26 (AAR) | KER + AAR | Verified Floor (gap on AAR) |
| §3.36 SAE Cognition Observatory | #29 (Cognition Observatory J2) | ACS | Capability Ceiling |

Rows in MASTER_FUSION §3.x not yet mapped here (because they sit above the UAS-ACS line — e.g. UI/UX, vault doctrine,
brand): §3.5 · §3.6 · §3.11 · §3.12 · §3.13 · §3.14 · §3.15 · §3.19 · §3.20 · §3.23 · §3.24 · §3.25 · §3.27 ·
§3.28 · §3.29 · §3.30 · §3.31 · §3.32 · §3.33 · §3.35 · §3.37 · §3.38 · §3.39 · §3.41.

## §7. Status posture (ship-claim vs gated vs research-only)

Per the §4.G acceptance bar: *"The doctrine doc explicitly says which capabilities are ship-claimed, which are gated,
which are research-only. **No silent gap between doctrine and code.**"*

### §7.1 Ship-claimed (Current App, user-facing today)

These are surfaced in the MAS build and visible to the user:

- #4 AnswerPacket emission · #6 Active-Support Atlas (W6) · #13 KV-Direct Gate (Tier-1) · #22 SCOPE-Rex Core
  (τ + π + λ) · #23 WBO-6 · #25 Five planes (Episodic + Verification wired) · #33 Cognitive DAG ·
  #34 Lattice (E8/Leech) · #35 Provenance Ledger + ReplayBundle · #36 epistemos-shadow (Halo).

### §7.2 Verified Floor (gated; ship after falsifier passes on M2 Pro 16 GB)

Substrate primitives that exist as CPU scaffolds or research-tier and need their falsifier to pass before MAS-ship:

- **CPU-scaffolded, Metal pending**: #10 PageGather · #16 LocalRecallIsland · #17 SemiseparableBlockScan ·
  #18 PacketRouter1bit · #19 ControllerKernelPack · #32 RULER+BABILong harness · #42 Helios kernels (composite).
- **Not yet in code (Phase B/C targets)**: #1 UasAddress · #2 ResidencyLease · #3 UasKind · #5 ACS Anchor (promotion) ·
  #8 HeliosPage · #11 Unified Page Oracle (composite) · #26 Active Assembly Runtime · #40 Scan-IR (T5) · #41 HeliosPage three-stage.
- **Falsifier infrastructure missing**: #5 (F-ACS-Anchor-Addressing has no harness yet) · #1-3 (F-UAS-ZeroCopy-Spine has no harness yet) · #8/41 (F-ShadowFirst-PageEscalation pipeline missing) · #10 (F-PageGather-M2Pro bandwidth measurement pending).

### §7.3 Capability Ceiling (research-only; not user-facing until composition passes)

Lane 3 / Lane 5 research-tier substrate. **Never ship to MAS without an explicit decision to promote**, per the
canon-hardening protocol:

- #14 70B Cocktail · #15 Ternary lane · #27 AutopoieticCS · #28 Continual Learning Stack · #29 Cognition
  Observatory · #30 Hyper-Dynamic Schemas · #31 Sherry Lattice · #37 epistemos-vault (Lane 5) · #38 VPD substrate ·
  #43 KV implantation / Glass Pipe / weight surgery.
- **Doctrine-only (no active code analog yet)**: #12 L3 SSD Oracle · #21 ACS/CMS-X.

### §7.4 Unresolved (open question — not silently absorbed)

- #20 **Morph** — named in §4.G hierarchy "Kernels (MUSCLE — PageGather, LocalRecallIsland, SemiseparableBlockScan,
  PacketRouter1bit, ControllerKernelPack, **Morph**)" but **NOT FOUND** in code or doctrine docs as of 2026-05-17 grep
  (see audit §D verification trace). Filed for user clarification in §8 below.

## §8. Open questions (user-decision escalation candidates)

Per driver §9 escalation channels, these are filed for the user but do not block continued execution:

1. **Morph kernel definition.** §4.G hierarchy lists Morph as the 6th MUSCLE-layer kernel alongside PageGather,
   LocalRecallIsland, SemiseparableBlockScan, PacketRouter1bit, ControllerKernelPack. No current code path, no
   doctrine doc, no primary-source citation found in 2026-05-17 substrate-floor grep. Three plausible resolutions:
   - **(a)** "Morph" is a future-target kernel (e.g. morphological / morpheme-aware token reshape; or an
     in-flight assembly that *morphs* one assembly state into another). Substantiate with a primary-source spec.
   - **(b)** "Morph" is a deprecated alias for an existing kernel (candidates: `sparse_ternary_gemm` for weight-morph,
     `ssd_block_scan` for state-morph, or `controller_pack::copy_range`/`zero_fill` for buffer-morph). Pick one.
   - **(c)** "Morph" was a doctrine-doc placeholder that should be deleted. Update §4.G hierarchy to remove it.
   - **Recommendation**: hold a `STALLED` row in §5 for #20 Morph until clarified. Phase B implementation can
     proceed on the other five MUSCLE kernels without blocking.

2. **§4.G three residency tiers vs SCOPE-Rex `Residency` enum disambiguation surface**. Should the future
   `agent_core/src/uas/residency_tier.rs` (Phase B.G.B1) live alongside or refactor with the existing
   `agent_core/src/scope_rex/residency.rs`? Two options:
   - **(a)** Keep both modules; add reciprocal tail comments documenting the axis distinction (recommended; matches
     existing drift-gate pattern).
   - **(b)** Rename `scope_rex::residency::Residency` → `scope_rex::residency::CognitiveStatePlacement` to remove
     the literal name collision.
   - **Recommendation**: (a) — the name `Residency` is already cited in W4 doctrine `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W4 + helios v5 first.md §1.13; renaming would force doctrine-doc rev. Tail comments are cheaper.

3. **T-terminal coordination handles for Phase B.** T3 owns `agent_core/src/uas/` (new) and extensions to
   `agent_core/src/research/acs/`. Phase B.G.B1's `UasKind` enum surface must coordinate with T1's tri_fusion work.
   Filed as a Phase B blocker if T1 has not published UasKind requirements by iter 21.

## §9. Anti-drift discipline

Per `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §0 immutable rules + §5.0 reconciliation gate + the
[[feedback_plan_is_authority]] memory:

1. **This doc is authority** for the §4.G layer hierarchy, residency tiers, and falsifier ladder. If a future code
   change introduces a UAS-ACS concept not listed in §5 above, **fix the doc first** (add a row), then land the code.
2. **Never delete a prior name.** Migration is recorded with `aka` in the register row.
3. **Never collapse layers.** §2.1 lists the forbidden drift cases.
4. **No silent migration up residency tiers.** A Capability-Ceiling concept moves to Verified Floor only after its
   falsifier passes on M2 Pro 16 GB; a Verified-Floor concept moves to Current App only after WRV `wired` →
   `reachable` → `visible` is recorded.
5. **No silent gap between doctrine and code.** When iter cadence detects drift (a §5 row says `landed` but the
   cited file is missing, or vice versa), file a §5.0 reconciliation-gate failure in the next commit's `BLOCKER:`
   message. The substrate-floor audit at `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md` is the empirical
   floor; this doc must remain consistent with it.

## §10. Authority and cross-references

- **Driver authority**: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.G (lines 676-781).
- **Backstop audit**: `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md` (Phase A iter 1).
- **MASTER_FUSION cross-link**: `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.x (see §6 above).
- **V6.1 foundation**: `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` + `Epistemos V6_1 — Final Synthesis Lock
  (Attention as Interrupt).pdf` (Foundational Seven E1-E7 + 5-plane formalism + WBO inequality).
- **V6.2 delta**: `docs/fusion/helios v6.2.md` (8-stage falsifier order: PageGather baseline → scatter → InterruptScore →
  PacketRouter1bit → ControllerKernelPack → SemiseparableBlockScan → LocalRecallIsland → RULER+BABILong).
- **HELIOS lineage**: `docs/fusion/helios v5 first.md` + `helios v5 updated.md` + `helios v6.2.md` (full Helios canon).
- **WBO-6 budget**: `docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md`.
- **Cognitive DAG**: `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md`.
- **Five-plane formalism**: `epistemos-research/src/five_planes.rs` (Plane numbers 1..5 LOCK from V6.1 §3).
- **Provenance**: `docs/plan/04_PHASES.md` Phase-1 ledger plan.

This doc is the canonical UAS-ACS register. All future UAS-ACS code and doc changes must reference it.
