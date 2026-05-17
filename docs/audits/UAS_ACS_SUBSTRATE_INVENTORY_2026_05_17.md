---
state: audit
created_on: 2026-05-17
terminal: T3 — UAS-ACS Canonical Architecture (deep dynamic kernel)
branch: codex/t3-uasacs-2026-05-16
scope: Phase A.1 — first-pass no-loss inventory of every previously-scattered concept under the UAS-ACS umbrella, classified by hierarchy layer + residency tier + current file + falsifier dependency.
authority: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G (hierarchy LOCK, residency-tier LOCK, falsifier-ladder LOCK).
---

# UAS-ACS Substrate Inventory — 2026-05-17

> Phase A.1 deliverable per §4.G mission step 3. This is the no-loss audit register that backstops the upcoming
> `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` doctrine doc. **Every concept that appeared in ≥ 1
> doctrine doc gets exactly one row** (name · layer · residency tier · current file · falsifier · status). Never delete a
> prior name; if the name has migrated, list both forms with an `aka` arrow.

## Top-level finding

The §4.G work is **less greenfield than the umbrella name suggests**. The substrate already exists, scattered across
nine modules in `agent_core/src/` and three Lane-segregated workspace crates (`epistemos-research`, `epistemos-shadow`,
`epistemos-vault`). The §4.G mission is **reconciliation**, not new construction:

- **Verified-Floor kernels already CPU-scaffolded** in `agent_core/src/helios/` for §4.G falsifier stages 1-8
  (page_gather · packet_router · controller_pack · ssd_block_scan · local_recall_island · long_context_harness).
  Total 2,450 LOC. Metal driver-side dispatch lives in Swift.
- **SCOPE-Rex Tier-1 surface** already landed at `agent_core/src/scope_rex/` (answer_packet · residency governor ·
  btm_semantic · metal::asa_index · kv::direct_gate · feature_observatory · witnessed_state · ontology · retrieval).
- **Shadow Memory taxonomy** lives at `epistemos-research/src/shadow_memory.rs` (Lane 3 research-only); active
  `ShmPool` at `agent_core/src/shared_memory.rs` implements L0 ExactHot only, with a drift gate locking the L1-L4 gap.
- **The genuine gaps** (Phase B targets): `agent_core/src/uas/` (does not exist), `agent_core/src/research/
  active_assembly/` (does not exist), Metal-driver wiring for PageGather scatter on M2 Pro 16 GB measured-bandwidth
  baseline (page_gather.rs ships scalar CPU reference + Metal stub only).

The work is naming-discipline, drift-gate placement, and Metal-driver landing — not scaffolding from zero.

## §4.G hierarchy (LOCK — verbatim from driver prompt §4.G)

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

**Anti-drift lock**: Never collapse layers into each other. UAS ≠ SSD Oracle. ACS ≠ Active Assembly. KV-Direct ≠ PageGather.

## §4.G residency tiers (LOCK — verbatim from driver prompt §4.G)

| Tier | Meaning | Examples |
|---|---|---|
| **Current App (MAS-ship)** | live in current user-facing build | Halo/Shadow search · vault retrieval · prepared local Qwen lane · graph retrieval · provenance plane · MLX idle-unload |
| **Verified Floor (gated)** | substrate primitive, ships after its falsifier passes on M2 Pro 16 GB | F-UAS-ZeroCopy-Spine · F-ACS-Anchor-Addressing · F-ShadowFirst-PageEscalation · F-PageGather-M2Pro · F-ActiveAssembly-Minimal · F-VaultRecall-50 (§4.H) · F-KV-Direct-Gate · F-ULP-Oracle |
| **Capability Ceiling (research)** | research lane, not user-facing until composition passes | F-70B-Local-Cocktail · ternary inference path · BitNet/T-MAC kernels · Goodfire VPD runtime acceleration · Mamba-3 lookahead · model surgery · connectome distillation |

**Anti-drift lock**: SCOPE-Rex `Residency` enum (9-variant cognitive-state taxonomy at
`agent_core/src/scope_rex/residency.rs::Residency`) is **NOT** the same as the three §4.G residency tiers
(substrate-shipping-policy tiers). They occupy different axes:

- **§4.G tier**: "is this concept shipped / gated / research-only?" (shipping policy)
- **SCOPE-Rex `Residency`**: "where does this claim live after the Governor processes it?"
  (TransientContext / RetrievalMemory / FeatureRule / HarnessRule / GrpoPrior / PsoftAdapter / OsftCore /
  CloudDistilled / Quarantine — cognitive-state placement)

Confusing the two is exactly the kind of layer collapse §4.G forbids. The canonical doc must keep both vocabularies
explicit and never silently swap them.

## §4.G falsifier ladder (LOCK — verbatim from driver prompt §4.G)

Each gate's pass is the entry ticket to the next:

1. **F-VaultRecall-50** (§4.H) — first user-facing proof. Owned by T4.
2. **F-UAS-ZeroCopy-Spine** — Rust ↔ MLX-Swift ↔ Swift UI hot buffers do not re-serialize. Zero copy on hot path. **(T3 — Phase B.G.B2)**
3. **F-ACS-Anchor-Addressing** — typed anchor round-trips through agent runtime + lookup + audit + projection without silent loss. **(T3 — Phase B.G.B3)**
4. **F-ShadowFirst-PageEscalation** — HeliosPage sketch → residual → exact-SSD escalation. KL/token ≤ 0.06. **(T3 — Phase B.G.B4)**
5. **F-PageGather-M2Pro** — Metal page-sketch scoring ≥ 70% of MEASURED M2 Pro streaming bandwidth (NOT theoretical 200 GB/s spec). 256/512/1024 MB buffers, 1 s+ windows. **(T3 — Phase B.G.B5)**
6. **F-ActiveAssembly-Minimal** — synthetic packet graph + active-pull selector preserves output within bound. **(T3 — Phase B.G.B6)**
7. **F-KV-Direct-Gate** — Qwen 3 8B at 128k, peak RAM < 13 GB on 16 GB rig, KL/token under threshold, decode ≥ 10 tok/s. **(T3 — Phase C.G.C2)**
8. **F-SemiseparableBlockScan-Correctness** — Mamba-2 / SSD scan matches reference on 100 seeds, max-abs-diff ≤ 1e-3 fp16. **(T3 — Phase C)**
9. **F-LocalRecallIsland-32K** — 50 trials × 5 depths passkey ≥ 0.95 under sketch-heavy routing. **(T3 — Phase C)**
10. **F-PacketRouter1bit-Dispatch** — p99 dispatch latency < 100 µs on M2 Pro. **(T3 — Phase C)**
11. **F-ControllerKernelPack** — 6 fused micro-kernels correctness + perf on M2 Pro. **(T3 — Phase C)**
12. **F-70B-Local-Cocktail-Composition** — research-only composition study (ternary + Mamba-2 + KV-Direct + PageGather + active assembly + speculative decode + cloud cascade). Memory stays under budget; identifies bottleneck. **(T3 — Phase C, research-only)**

**Anti-drift lock**: No silent skips. A falsifier failing means its dependency cap stays closed; the work below it gets a
STALLED status row in the canonical doctrine doc.

---

## §A. Concept-reconciliation register (no-loss, one row per scattered name)

This is the table the §4.G canonical doctrine doc inherits. Every scattered name in the user's research corpus gets
exactly ONE row. Status semantics: `landed` (in code, drift-gated), `scaffolded` (CPU reference exists, Metal/wire-up
pending), `not yet` (target — Phase B/C work), `taxonomy-only` (research-tier doctrine, no active analog yet).

| # | Concept (canonical name) | aka / scattered names | UAS-ACS Layer | Residency Tier | Current file(s) | Falsifier dependency | Status |
|---|---|---|---|---|---|---|---|
| 1 | **UasAddress** | Unified Address Space identity | UAS (BODY) | Verified Floor | `agent_core/src/uas/` (does not exist yet) | F-UAS-ZeroCopy-Spine, F-ACS-Anchor-Addressing | **not yet** — Phase B.G.B1 target |
| 2 | **ResidencyLease** | substrate-tier lease handle | UAS (BODY) | Verified Floor | `agent_core/src/uas/` (does not exist yet) | F-UAS-ZeroCopy-Spine | **not yet** — Phase B.G.B1 target |
| 3 | **UasKind** | substrate-typed identity tag | UAS (BODY) | Verified Floor | `agent_core/src/uas/` (does not exist yet) | F-UAS-ZeroCopy-Spine | **not yet** — Phase B.G.B1 target (T1 coordinates on UasKind types) |
| 4 | **AnswerPacket** | HELIOS V5 W1 Monday-Move primitive | SCOPE-Rex + WBO + Sheaf/Glue (VERIFICATION SPINE) | Current App | `agent_core/src/scope_rex/answer_packet.rs` (W1 landed) | F-UAS-ZeroCopy-Spine | **landed** |
| 5 | **ACS Anchor** | typed anchor (theorem tag · plane coord · residency tier · source hash · active packet id) | ACS (COORDINATE SYSTEM) | Verified Floor | `agent_core/src/research/acs/` (taxonomy: autopoiesis · governance · kuramoto · notch_delta · vsm) + promotion target `agent_core/src/research/acs/anchor.rs` | F-ACS-Anchor-Addressing | **scaffolded** — Phase B.G.B3 promotes anchor.rs |
| 6 | **Active-Support Atlas (ASA)** | W6 sparse-mask matmul index | Kernels (MUSCLE) | Current App (W6 landed) | `agent_core/src/scope_rex/metal/asa_index.rs` + `agent_core/src/scope_rex/pro_joint.rs` (Pro-tier T-MAC joint) | drift gate on W6 | **landed** |
| 7 | **Shadow Memory** | Shadow paging research-tier taxonomy | Shadow-first paging (SENSORY FILTER) | Capability Ceiling (research-tier doctrine) | `epistemos-research/src/shadow_memory.rs` (5-tier ladder: L0-L4) + `agent_core/src/shared_memory.rs` (L0 ExactHot only, drift gate locked) | F-ShadowFirst-PageEscalation | **taxonomy-only** — L0 active, L1-L4 are doctrine targets |
| 8 | **HeliosPage** | sketch + residual + exact escalation | Shadow-first paging (SENSORY FILTER) | Verified Floor | (new harness needed) | F-ShadowFirst-PageEscalation | **not yet** — Phase B.G.B4 target |
| 9 | **Page Oracle** / **Unified Page Oracle** | Helios page-gather kernel name (V3 era) | Kernels (MUSCLE) | Verified Floor (CPU ref landed) | `agent_core/src/helios/page_gather.rs` (CPU scalar reference, 342 LOC) | F-PageGather-M2Pro | **scaffolded** — Metal driver + bandwidth harness pending (Phase B.G.B5) |
| 10 | **PageGather** | canonical kernel name (V6.2 era) | Kernels (MUSCLE) | Verified Floor | `agent_core/src/helios/page_gather.rs` | F-PageGather-M2Pro | **scaffolded** — same kernel as #9 (name migration V3→V6.2) |
| 11 | **L3 SSD Oracle** | KV-cache spill to SSD long-memory path | KV-Direct / L3 SSD (LONG-TERM MEMORY) | Capability Ceiling | (no active code path yet — see #12 for the W8 gate) | F-KV-Direct-Gate | **not yet** — Phase C.G.C2 target |
| 12 | **KV-Direct Gate** | HELIOS V5 W8 Tier-1 KV-direct path | KV-Direct / L3 SSD | Verified Floor (W8 landed) | `agent_core/src/scope_rex/kv/direct_gate.rs` | F-KV-Direct-Gate | **landed** (Tier-1 gate); Phase C wires the SSD spill |
| 13 | **70B Cocktail** | composition target (ternary + Mamba-2 + KV-Direct + PageGather + active assembly + speculative + cloud cascade) | Composition (all kernels) | Capability Ceiling (research-only) | (not yet) | F-70B-Local-Cocktail-Composition | **not yet** — Phase C.G.C3 research-only doc + harness |
| 14 | **Ternary lane** | BitNet b1.58 · `{-1, 0, +1}` weights | Kernels (MUSCLE) | Capability Ceiling (research) | `agent_core/src/research/ternary/` (10 sub-modules) + `agent_core/src/scope_rex/kernels/bitnet.rs` + `epistemos-research/src/ternary_kernel.rs` | F-PacketRouter1bit (downstream), F-70B-Local-Cocktail | **landed** (research-tier kernels); MLX-Swift wire-in pending (§4.E C.8) |
| 15 | **LocalRecallIsland** | 32K Core passkey-retrieval substrate | Kernels (MUSCLE) | Verified Floor | `agent_core/src/helios/local_recall_island.rs` (CPU substrate, 418 LOC) | F-LocalRecallIsland-32K | **scaffolded** — Metal kernel + live model integration pending |
| 16 | **SemiseparableBlockScan** | Mamba-2 SSD selective-state scan | Kernels (MUSCLE) | Verified Floor | `agent_core/src/helios/ssd_block_scan.rs` (CPU scalar ref, 385 LOC) | F-SemiseparableBlockScan-Correctness | **scaffolded** — Metal kernel + per-channel parallelization pending |
| 17 | **PacketRouter1bit** | 1-bit dispatch (MoE-style binary specialization) | Kernels (MUSCLE) | Verified Floor | `agent_core/src/helios/packet_router.rs` (CPU ref, 439 LOC) | F-PacketRouter1bit-Dispatch | **scaffolded** — Metal stub at `Epistemos/Shaders/PacketRouter1bit.metal`; p99 latency harness pending |
| 18 | **ControllerKernelPack** | 6 fused micro-kernels (scalar_add · scalar_mul · max_reduce · argmax · copy_range · zero_fill) | Kernels (MUSCLE) | Verified Floor | `agent_core/src/helios/controller_pack.rs` (CPU ref, 343 LOC) | F-ControllerKernelPack | **scaffolded** — Metal kernel pack pending |
| 19 | **Morph** | Morph DSL evaluator kernel (`morph_dsl_dispatch.metal` V5 → `morph_eval_reduced.metal v0.1` V6.1) | Kernels (MUSCLE) + AAR (ternary-morph cortex role) | Verified Floor | **Code path Phase B target**: `Epistemos/Shaders/morph_eval_reduced.metal v0.1` (not shipped per V6.1 intake). **Doctrine canonicals** found post-iter-1 in `docs/fusion/helios v5 first.md` DOC 6 §T5 + `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` §"W1 F-ULP Oracle". | **F-ULP-Oracle** (W1; ≤ 2 ULP fp16 in [0.5, 2.0]) | **taxonomy-only** — V6.1 doctrine landed; kernel + harness Phase B pending. RESOLUTION DOC: `docs/audits/UAS_ACS_MORPH_DEEP_DIVE_2026_05_17.md` (iter 14). Iter-1 "NOT FOUND" was a grep-scope error (limited to agent_core/src/{helios,scope_rex,research}). |
| 20 | **ACS/CMS-X** | Compute/Memory Stack v2 constitutive field | ACS/CMS-X (ADMISSION FIELD) | Verified Floor (doctrine) | `epistemos-research/src/cms_v2.rs` (research-tier doctrine, no active analog yet) | (no falsifier — drift gate only) | **taxonomy-only** |
| 21 | **SCOPE-Rex** | HELIOS V5 full Σ-signature (τ + π + λ Core; +δ +ρ Pro; +κ +η Research) | SCOPE-Rex + WBO + Sheaf/Glue (VERIFICATION SPINE) | Current App (Core landed) | `agent_core/src/scope_rex/` (12 modules) + `agent_core/src/resonance/` (τ/π/λ Core) | (drift gates) | **landed** (Core); Pro tier behind `pro-build` cargo feature |
| 22 | **WBO-6** | 6-term hot-path drift budget (T_W · T_Q · T_C · T_R · T_S · T_M) | SCOPE-Rex + WBO + Sheaf/Glue | Current App | `agent_core/src/wbo6/` + canonical doc `docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md` | (drift gates) | **landed** |
| 23 | **Glue / Sheaf** | Sheaf-gluing theorem E2 | SCOPE-Rex + WBO + Sheaf/Glue | Verified Floor (research) | `epistemos-research/src/theorems/e2_sheaf_gluing.rs` + V6.1 §5 | (Lean proof status — see theorem_status.rs) | **research-tier** |
| 24 | **Five planes** | State / Episodic / Assembly / Controller / Verification | meta-substrate (cross-cuts all layers) | Current App (provenance plane wired) | `epistemos-research/src/five_planes.rs` + `agent_core/src/provenance/` (Episodic + Verification roles locked 2026-05-12) | (drift gate `provenance_storage_in_episodic_audit_in_verification`) | **landed** |
| 25 | **Active Assembly Runtime (AAR)** | active-pull selector for packets / components / model mechanisms | AAR (NERVOUS SYSTEM) | Verified Floor | `agent_core/src/research/active_assembly/` (does not exist yet) | F-ActiveAssembly-Minimal | **not yet** — Phase B.G.B6 target |
| 26 | **AutopoieticCS (ACS Wave J5)** | recursive self-governance multi-scale (transistor → cell → tissue → organ → organism → ecosystem) | ACS (COORDINATE SYSTEM, doctrine layer) | Capability Ceiling (research) | `agent_core/src/research/acs/` (kuramoto + governance + vsm + autopoiesis + notch_delta) | F-ACS-Anchor-Addressing (downstream) | **landed** (research-tier substrate-floor primitives) |
| 27 | **Continual Learning Stack (J3)** | 7-layer "Never Retrain" stack (base · adaptation · protection · memory · history · governance · quantization) | ACS (constraint surface on adaptation) | Capability Ceiling (research) | `agent_core/src/research/continual_learning/` (ewc · oftv2 · seal_dora · titans_mac · dsc · stack) | (research-tier drift gates) | **landed** (research-tier) |
| 28 | **Cognition Observatory (J2)** | KVCacheImplanter · WeightPatcher · ActivationInterceptor · SAE inspection | ACS (introspection surface) | Capability Ceiling (research) | `agent_core/src/research/cognition_observatory/` (kv_implant · weight_patcher · sae · glass_pipe · pipeline) | (research-tier) | **landed** (research-tier) |
| 29 | **Hyper-Dynamic Schemas (J6)** | self-repairing meta-schemas (axiom widening preserves theorems) | ACS (typed-anchor schema layer) | Capability Ceiling (research) | `agent_core/src/research/hyperdynamic_schemas/` (diff · repair) | (research-tier) | **landed** (research-tier) |
| 30 | **Sherry Lattice (J7)** | 1.25-bit ternary quantization (3:4 sparse + E8/Leech lattice VQ) | Kernels (MUSCLE) | Capability Ceiling (research) | `agent_core/src/research/sherry_lattice/` (codebook · e8 · leech · sparse_ternary) | (research-tier) | **landed** (research-tier substrate) |
| 31 | **RULER + BABILong harness (Helios stage 8)** | long-context acceptance harness (32K, 30-min wall-clock) | meta — falsifier ladder support | Verified Floor (CPU scaffold) | `agent_core/src/helios/long_context_harness.rs` (455 LOC) | F-LocalRecallIsland-32K (composition target) | **scaffolded** |
| 32 | **Cognitive DAG (Phase 8.A-8.G)** | typed nodes (10 NodeKind) + edges (10 EdgeKind) + Merkle root + resonance propagation + companion lifecycle + DagMirror trait | UI / notes / graph / agent (USER-FACING SURFACE backed by ACS) | Current App | `agent_core/src/cognitive_dag/` (11 modules) | (drift gates + doctrine-lint binary) | **landed** |
| 33 | **Lattice (E8 / Leech / Cubic)** | hot-path quantization surface, WBO-6 T_Q term contributor | meta-substrate (T_Q budget term feeder) | Current App | `agent_core/src/lattice/mod.rs` + `epistemos-research/src/wbo_generations.rs` | (drift gate via WBO-6 T_Q) | **landed** |
| 34 | **Provenance Ledger + ReplayBundle** | ClaimLedger (Episodic) + ReplayBundle (Verification) per V6.1 5-plane formalism | meta — Verification plane | Current App | `agent_core/src/provenance/ledger.rs` + `agent_core/src/provenance/replay.rs` + `agent_core/src/bin/epistemos_trace.rs` | (drift gate `provenance_storage_in_episodic_audit_in_verification`) | **landed** |
| 35 | **epistemos-shadow (Halo Contextual Shadows)** | Tantivy BM25 + usearch HNSW + RRF fusion (k=60) — currently user-facing app-level Halo | Shadow-first paging (USER-FACING SURFACE side) | Current App (W8.4 / W8.7 landed) | `epistemos-shadow/src/` (lib · state · honest_handle · error + backend/{embedder · lexical_index · vector_index · rrf}) | F-VaultRecall-50 (§4.H) — owned by T4 | **landed** |
| 36 | **epistemos-vault (HCache/KVCrush + Active Rank-One + Connectome Distillation + Model Surgery)** | Lane 5 SPECULATIVE_VAULT path (W20/W21/W22) | KV-Direct / L3 SSD + ACS introspection | Capability Ceiling (Pro / Lane 5) | `epistemos-vault/src/` (cache/{hcache, kvcrush} · distill/connectome · runtime/{active_rank_one, transfer} · surgery/envelope) | (Pro-only burn-in; no Verified-Floor falsifier) | **landed** (Lane 5 substrate) — T3 does not edit per scope lock (vault.rs is T4 territory) |
| 37 | **VPD substrate (Goodfire-style)** | ParamAnchor + AttentionGraph + ComponentRoute + dual SPD/SAE trace + sheaf consistency | ACS introspection surface | Capability Ceiling (research-only) | `epistemos-research/src/vpd/` (anchor · attribution_graph · component_route · connectome_sheaf · dual_trace · extract · qk_edge) | (research-tier) | **landed** (research-tier) |
| 38 | **ULP-Oracle** | sign-correct ULP distance for numerical-equivalence drift detection | meta — Verification plane | Verified Floor (per §4.G ladder) | `agent_core/src/research/eml/ulp_oracle.rs` (T7 scope — DO NOT EDIT per T3 scope lock) + `epistemos-research/src/ulp_compare.rs` | F-ULP-Oracle (named in §4.G residency-tier examples) | **landed** (research-tier oracle) — T7 owns active extension |
| 39 | **Scan-IR** | kernel-doctrine substrate for SSMs (Mamba-2, RWKV-7, Jamba) | Kernels (MUSCLE — IR surface) | Verified Floor (per §4.I) | `agent_core/src/research/scan_ir/` (does not exist yet — coordinate with T5 per T3 scope lock) | F-SemiseparableBlockScan-Correctness (downstream) | **not yet** — T5 ownership; T3 coordinates |
| 40 | **HeliosPage three-stage (sketch · residual · exact)** | Shadow-Memory canon: INT8 sketch + Metal scoring + top-k + exact decode | Shadow-first paging | Verified Floor | (new harness needed; CPU scaffold could derive from `epistemos-shadow/src/backend/`) | F-ShadowFirst-PageEscalation | **not yet** — Phase B.G.B4 target |

## §B. Module-by-module audit (research crate scan)

This subsection mirrors the format of `docs/audits/HELIOS_SUBSTRATE_INVENTORY_2026_05_12.md` but scoped to the
UAS-ACS umbrella. Each row maps a current `agent_core/src/research/` or `epistemos-*` source file to its UAS-ACS
hierarchy layer + the §4.G residency tier.

### B.1 — `agent_core/src/helios/` (Helios kernel pack — Verified-Floor CPU substrate)

| # | File | Layer | Residency tier | LOC | Falsifier | Notes |
|---|---|---|---|---|---|---|
| 1 | `page_gather.rs` | Kernels | Verified Floor | 342 | F-PageGather-M2Pro | CPU scalar gather + scatter; Metal stub at `Epistemos/Shaders/PageGather.metal` |
| 2 | `local_recall_island.rs` | Kernels | Verified Floor | 418 | F-LocalRecallIsland-32K | passkey-retrieval substrate; live-model integration pending |
| 3 | `ssd_block_scan.rs` | Kernels | Verified Floor | 385 | F-SemiseparableBlockScan-Correctness | scalar Mamba-2 SSD reference (per-channel Metal parallelization pending) |
| 4 | `packet_router.rs` | Kernels | Verified Floor | 439 | F-PacketRouter1bit-Dispatch | 1-bit dispatch CPU ref; Metal stub at `Epistemos/Shaders/PacketRouter1bit.metal` |
| 5 | `controller_pack.rs` | Kernels | Verified Floor | 343 | F-ControllerKernelPack | 6 fused micro-kernels CPU ref |
| 6 | `long_context_harness.rs` | meta — falsifier scaffold | Verified Floor | 455 | F-LocalRecallIsland-32K (composition) | RULER + BABILong substrate-floor scaffold |
| 7 | `mod.rs` | meta — module head | — | 68 | — | 8-stage falsifier order doc + re-exports |

### B.2 — `agent_core/src/scope_rex/` (SCOPE-Rex Tier-1 surface — Verification Spine)

| # | File | Layer | Residency tier | Notes |
|---|---|---|---|---|
| 1 | `answer_packet.rs` | Verification Spine | Current App | HELIOS V5 W1 — 5th Monday-Move primitive |
| 2 | `residency.rs` | Verification Spine (cognitive-state placement) | Current App (W4 landed) | 9-variant `Residency` enum (NOT same as §4.G three residency tiers — see anti-drift lock above) |
| 3 | `btm_semantic.rs` | Verification Spine | Current App (W5 landed) | Semantic Brain Time Machine V1.5 |
| 4 | `metal/asa_index.rs` | Kernels | Current App (W6 landed) | Active-Support Atlas indexing |
| 5 | `metal/softmax.rs` | Kernels | Current App | softmax substrate primitive |
| 6 | `kv/direct_gate.rs` | KV-Direct / L3 SSD | Current App (W8 landed) | Tier-1 KV-direct path |
| 7 | `pro_joint.rs` | Kernels | Capability Ceiling (Pro tier, `pro-build` feature) | T-MAC + ASA joint path |
| 8 | `kernels/bitnet.rs` | Kernels | Capability Ceiling (research) | BitNet b1.58 substrate |
| 9 | `kernels/sparse_ternary_gemm.rs` | Kernels | Capability Ceiling (research) | sparse ternary GEMM |
| 10 | `kernels/t_mac.rs` | Kernels | Capability Ceiling (Pro) | T-MAC table-lookup low-bit GEMM |
| 11 | `witnessed_state.rs` | Verification Spine | Current App | SCOPE-Rex Omega 8-tuple `S_t` |
| 12 | `ontology.rs` | Verification Spine | Current App | V(a) ontology-violation cost |
| 13 | `feature_observatory.rs` | ACS introspection | Current App | Qwen-Scope-style SAE inspection + steering |
| 14 | `retrieval/hopfield.rs` | Shadow-first paging | Current App | Hopfield-style associative retrieval |
| 15 | `produce.rs` | Verification Spine | Current App | V6.2 production caller for AnswerPacket |

### B.3 — `agent_core/src/research/acs/` (Wave J5 Autopoietic Cognitive Stack)

| # | File | Layer | Residency tier | Notes |
|---|---|---|---|---|
| 1 | `mod.rs` | ACS | Capability Ceiling (research) | umbrella |
| 2 | `kuramoto.rs` | ACS | Capability Ceiling (research) | phase-coupling primitive |
| 3 | `governance.rs` | ACS | Capability Ceiling (research) | governance pattern |
| 4 | `vsm.rs` | ACS | Capability Ceiling (research) | Viable System Model |
| 5 | `autopoiesis.rs` | ACS | Capability Ceiling (research) | autopoietic pattern |
| 6 | `notch_delta.rs` | ACS | Capability Ceiling (research) | Notch-Delta signaling analog |
| 7 | `anchor.rs` | ACS | **Verified Floor (Phase B.G.B3 target)** | **DOES NOT EXIST YET** — promoted anchor type |

### B.4 — `agent_core/src/research/ternary/` (Wave J1 Ternary core)

10 sub-modules (activation_tap · backend · fused_rmsnorm · gemv · kernel_kind · kv_fingerprint · pack · residual_island · steering · trit). All Capability Ceiling (research). Falsifier downstream: F-PacketRouter1bit + F-70B-Local-Cocktail.

### B.5 — `agent_core/src/research/sherry_lattice/` (Wave J7 Sherry 1.25-bit + lattice-VQ)

5 sub-modules (codebook · e8 · leech · sparse_ternary · mod). All Capability Ceiling (research).

### B.6 — `agent_core/src/research/continual_learning/` (Wave J3)

7 sub-modules (dsc · ewc · oftv2 · seal_dora · stack · titans_mac · mod). All Capability Ceiling (research).

### B.7 — `agent_core/src/research/cognition_observatory/` (Wave J2)

5 sub-modules (glass_pipe · kv_implant · pipeline · sae · weight_patcher). All Capability Ceiling (research).

### B.8 — `agent_core/src/research/hyperdynamic_schemas/` (Wave J6)

3 sub-modules (diff · repair · mod). All Capability Ceiling (research).

### B.9 — `epistemos-research/src/` (Lane 3 RESEARCH_FRONTIER — 39 files)

See `docs/audits/HELIOS_SUBSTRATE_INVENTORY_2026_05_12.md` for the prior module-by-module audit of this crate. The
UAS-ACS classification is layered on top:

- `shadow_memory.rs` → Shadow-first paging (Capability Ceiling research-tier; L0 active via `ShmPool`, L1-L4 doctrine)
- `kv_direct_gate.rs` → KV-Direct (Verified Floor; W8 Tier-1 path landed in scope_rex)
- `cms_v2.rs` → ACS/CMS-X constitutive field (Capability Ceiling research-tier)
- `five_planes.rs` → meta cross-cuts (Current App via provenance plane)
- `gate_action.rs` → Verification Spine (Capability Ceiling research-tier 6-variant; 3-arm subset locked via drift gate to active `ApprovalDecision`)
- `ulp_compare.rs` → meta — Verification (Verified Floor; F-ULP-Oracle)
- `ternary_kernel.rs` → Kernels (Capability Ceiling research)
- `mas_capability_lattice.rs` → meta — substrate-shipping policy (locked via drift gate)
- `hardware_profile.rs` → meta — substrate-shipping policy (M2 Pro 16 GB ship target)
- `vpd/*.rs` → ACS introspection (Capability Ceiling research-only)
- `theorems/{e1..e7,mod}.rs` → meta — Lean theorem status (E1-E7 Foundational Seven)
- All other files: Capability Ceiling research-tier (taxonomy / proof substrate)

### B.10 — `epistemos-shadow/src/` (Wave 8 Halo — Current-App user-facing)

9 files. All Current App (W8.4 / W8.7 landed). RRF (k=60) fusion + Tantivy BM25 + usearch HNSW. Backstop falsifier:
F-VaultRecall-50 (§4.H — T4 owns).

### B.11 — `epistemos-vault/src/` (Lane 5 SPECULATIVE_VAULT — Pro / Capability Ceiling)

11 files. All Capability Ceiling (Pro tier, `vault` feature). HCache/KVCrush + Active Rank-One + Connectome
Distillation + Model Surgery. **T3 scope lock: DO NOT EDIT** — `agent_core/src/storage/vault.rs` + this crate are T4
territory.

---

## §C. Gap list (Phase B / Phase C targets)

These are the files/modules that do NOT exist on disk but must land per §4.G mission steps:

| Gap | Phase | Target | Falsifier |
|---|---|---|---|
| `agent_core/src/uas/` — `UasAddress` + `ResidencyLease` + `UasKind` | B.G.B1 | typed identity system | F-UAS-ZeroCopy-Spine + F-ACS-Anchor-Addressing |
| F-UAS-ZeroCopy-Spine `#[test]` harness — copy count > 0 fails | B.G.B2 | hot-path zero-copy proof | F-UAS-ZeroCopy-Spine |
| `agent_core/src/research/acs/anchor.rs` — promoted typed anchor | B.G.B3 | ACS typed anchor object | F-ACS-Anchor-Addressing |
| F-ShadowFirst-PageEscalation harness — HeliosPage sketch/residual/exact pipeline | B.G.B4 | KL drift ≤ 0.06 | F-ShadowFirst-PageEscalation |
| `agent_core/src/research/page_gather/` — Metal kernel + Swift driver | B.G.B5 | ≥ 70% MEASURED M2 Pro bandwidth | F-PageGather-M2Pro |
| `agent_core/src/research/active_assembly/` — synthetic packet graph + active-pull selector | B.G.B6 | first runtime proof | F-ActiveAssembly-Minimal |
| `agent_core/src/research/local_recall_island/` — Metal kernel + live model integration | C | 50 trials × 5 depths passkey ≥ 0.95 | F-LocalRecallIsland-32K |
| `agent_core/src/research/scan_ir/` — Scan-IR kernel-doctrine substrate | C | SSM kernel doctrine (coord with T5) | F-SemiseparableBlockScan-Correctness |
| `docs/falsifiers/F-*.md` (12 docs) | B | pass/fail recipe + M2 Pro budget + methodology + fallback | each gate |
| `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` | A.2 (next iter) | no-loss canonical register doc | (cross-link MASTER_FUSION §3.x) |
| **Morph** kernel — concept appears in §4.G hierarchy but NOT in code | clarification | (TBD) | (TBD) |

---

## §D. Verification trace (§5.0 reconciliation gate)

Per driver-prompt §0 immutable rules + §5.0 reconciliation gate: every claim in this doc is grep-verifiable against
the current code state on `codex/t3-uasacs-2026-05-16` (which is at parity with `main`, 0 commits ahead — verified
via `git rev-list --count main..HEAD = 0` at 2026-05-17 audit start).

```
# Helios kernel CPU substrate files exist
$ wc -l agent_core/src/helios/*.rs
     343 agent_core/src/helios/controller_pack.rs
     418 agent_core/src/helios/local_recall_island.rs
     455 agent_core/src/helios/long_context_harness.rs
      68 agent_core/src/helios/mod.rs
     439 agent_core/src/helios/packet_router.rs
     342 agent_core/src/helios/page_gather.rs
     385 agent_core/src/helios/ssd_block_scan.rs
    2450 total

# SCOPE-Rex Tier-1 surface modules exist
$ find agent_core/src/scope_rex -type f -name '*.rs' | sort
agent_core/src/scope_rex/answer_packet.rs
agent_core/src/scope_rex/btm_semantic.rs
agent_core/src/scope_rex/feature_observatory.rs
agent_core/src/scope_rex/kernels/bitnet.rs
agent_core/src/scope_rex/kernels/mod.rs
agent_core/src/scope_rex/kernels/sparse_ternary_gemm.rs
agent_core/src/scope_rex/kernels/t_mac.rs
agent_core/src/scope_rex/kv/direct_gate.rs
agent_core/src/scope_rex/kv/mod.rs
agent_core/src/scope_rex/metal/asa_index.rs
agent_core/src/scope_rex/metal/mod.rs
agent_core/src/scope_rex/metal/softmax.rs
agent_core/src/scope_rex/mod.rs
agent_core/src/scope_rex/ontology.rs
agent_core/src/scope_rex/pro_joint.rs
agent_core/src/scope_rex/produce.rs
agent_core/src/scope_rex/residency.rs
agent_core/src/scope_rex/retrieval/hopfield.rs
agent_core/src/scope_rex/retrieval/mod.rs
agent_core/src/scope_rex/witnessed_state.rs

# UAS module does NOT exist yet
$ ls agent_core/src/uas 2>&1
ls: agent_core/src/uas: No such file or directory

# Active-Support Atlas grep
$ grep -rn "Active-Support Atlas" agent_core/src | head -5
agent_core/src/scope_rex/pro_joint.rs:1:HELIOS V5 W16 — Pro-tier T-MAC + Active-Support Atlas joint path.
agent_core/src/scope_rex/metal/mod.rs:11:- [asa_index] — W6 Active-Support Atlas indexing
agent_core/src/scope_rex/metal/asa_index.rs:9:HELIOS V5 W6 — Active-Support Atlas indexing (Tier-1 ULP-equivalent).

# Shadow Memory taxonomy lives in research crate; ShmPool is L0 active
$ grep -rn "shadow_memory" agent_core/src epistemos-research/src | head -5
agent_core/src/shared_memory.rs:230:HELIOS canon (in `epistemos-research/src/shadow_memory.rs::MemoryTier`,
agent_core/src/shared_memory.rs:250:`epistemos-research/src/shadow_memory.rs::tests::active_app_shmpool_implements_l0_exact_hot_only`
epistemos-research/src/shadow_memory.rs:1:HELIOS V5 — Helios Shadow Memory (Lane 3 RESEARCH-ONLY).

# Morph: NOT FOUND in code as of 2026-05-17
$ grep -rn "Morph" agent_core/src/helios agent_core/src/scope_rex agent_core/src/research
(zero matches that are not test scaffolding or unrelated)

# Active Assembly: NOT FOUND
$ grep -rn "Active Assembly\|active_assembly\|ActiveAssembly" agent_core/src
(zero matches)

# epistemos-* crates exist
$ find . -maxdepth 2 -type d -name 'epistemos-*'
./epistemos-shadow
./epistemos-core
./epistemos-code-index
./epistemos-research
./epistemos-vault
```

---

## §E. Next-iter targets

This is Phase A iter 1 of Terminal T3. The remaining Phase A iters 2-20 fan out:

- **iter 2**: write `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` — the no-loss canonical doctrine doc.
  Carries the same concept-reconciliation register but with full primary-source citations + cross-links to
  `docs/fusion/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md §3.x` rows.
- **iter 3-12**: write the 12 `docs/falsifiers/F-*_2026_05_17.md` docs (one per gate; pass/fail recipe + M2 Pro budget
  + measurement methodology + fallback if fails). Per §4.G mission step 2.
- **iter 13-15**: deep-dive audit of any concept marked **gap** above (especially `Morph` — open question:
  is this a deprecated name, an unimplemented kernel, or a different naming for `controller_pack` /
  `sparse_ternary_gemm` / something else?).
- **iter 16-20**: cross-link from MASTER_FUSION §3.x; coordinate with T1/T4/T5/T7 owners on UasKind / vault retrieval /
  Scan-IR / EML boundaries.

After Phase A acceptance: Phase B (iters 21-80) — falsifier docs + first implementations (G.B1..G.B6).

---

## §F. Open questions for the user / cross-terminal coordination

1. **Morph kernel** — **RESOLVED 2026-05-17 (Phase A iter 14)**. Morph is the Morph DSL evaluator kernel at
   `Epistemos/Shaders/morph_eval_reduced.metal v0.1` (formerly `morph_dsl_dispatch.metal`), per
   `docs/fusion/helios v5 first.md` DOC 6 §T5 (Morph DSL Determinism + WBO-7 controller) +
   `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` §"W1 F-ULP Oracle". Gated by
   **F-ULP-Oracle** (W1 in V6.1 foundation sequence). Iter-1 "NOT FOUND" was a grep-scope error (limited to
   `agent_core/src/{helios,scope_rex,research}`). Full resolution: `docs/audits/UAS_ACS_MORPH_DEEP_DIVE_2026_05_17.md`.
2. **T1 coordination** — RESOLVED 2026-05-17 (iter 17). Full handshake protocol + initial UasKind variant set + iter-21 commit-message blocker pattern documented in `docs/audits/UAS_ACS_T_TERMINAL_COORDINATION_2026_05_17.md` §2. T3 produces enum surface; T1 contributes variants for tri-fusion content blocks.
3. **T5 coordination** — RESOLVED 2026-05-17 (iter 17). Scan-IR consumer + producer protocol in coord doc §4. Phase C dependency; mitigation if T5 lags = use `agent_core/src/helios/ssd_block_scan.rs` as de facto Scan-IR primitive.
4. **T7 coordination** — RESOLVED 2026-05-17 (iter 17). F-ULP-Oracle handshake protocol in coord doc §5. T7 owns `oxieml::EmlTree::eval_real`; T3 owns the Metal kernel + harness. V6.1 stage 1 (oxieml vendored read-only) assumed live; T3 verify before consuming.
5. **§4.G residency-tier vs SCOPE-Rex `Residency` enum** — flagged in this doc, but should also land as an explicit
   tail comment on `scope_rex/residency.rs::Residency` and on the future `uas/residency_tier.rs` (Phase B.G.B1) to
   prevent silent collapse. Filed as Phase B.G.B1 sub-step.
