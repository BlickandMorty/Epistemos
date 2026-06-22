# HELIOS-Era IP Archaeology — Where Did the Substrate / scope_rex / Dual-Brain IP Go? (2026-06-22)

**Owner question:** The "Helios era" (v1→v5/v6, also "Epistemos 6.2") produced a large body of substrate /
architecture IP — `scope_rex`, a full substrate, a "dual-brain" architecture — much of it originally tied to a
**70B large local model stack**. (A) Where is all that IP now? (B) Was it superseded / did it drift+orphan / is
it live? (C) Which parts are worth **hardening + finishing + infusing into System G / the IP brain**, EXCLUDING
anything that requires the 70B / from-scratch new model (HARD OFF-LIMITS per owner 2026-06-22)?

**Anti-hallucination discipline:** every row is grounded in a file read or grep this session and labeled **[V]**
VERIFIED (path/line read) or **[I]** INFERRED. Where IP is gone, this says so. Do NOT commit.

**Authority cross-refs (all VERIFIED present this session):**
- `docs/research/THE_BIG_IDEA_GRAND_CONVERGENCE_2026_06_22.md` (commit 018498d9e) — owner's "ONE brain, two
  faculties, 70B EXCLUDED" finalization. **This is the governing decision on the 70B exclusion.**
- `docs/research/ARCHITECTURE_UNIFICATION_SYSTEMG_2026_06_22.md` (commit f624e5a69) — the System G unification
  verdict (LAYERS not rivals).
- `docs/audits/HELIOS_SUBSTRATE_INVENTORY_2026_05_12.md` — the prior module-by-module audit of `epistemos-research`.
- `docs/HELIOS_V5_DOC_0_INDEX.md` + `docs/fusion/helios v6.2.md` + `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` — the canon lineage docs.

---

## 0. TL;DR (where the IP went)

1. **The Helios IP is NOT gone and NOT lost.** It split cleanly into **three buckets**, all present on disk:
   - **(a) PROMOTED-LIVE into the product** — the `scope_rex` full surface + the `resonance` (SCOPE-Rex Core
     τ+π+λ) module are **live, compiled, FFI-bridged Rust modules** in `agent_core/`. **[V]**
   - **(b) PRESERVED as the doctrine-target research crate** — `epistemos-research/` (39+ `.rs` files) holds the
     theorem/kernel/memory-tier doctrine, **hermetically isolated behind `--features research`**, intentionally
     NOT linked into the app. It is preserved, not orphaned. **[V]**
   - **(c) RESEARCH/DESIGN DOCS** — `docs/fusion/` holds the Helios v2→v6.2 lineage as authored research +
     verification canon. Preserved as history. **[V]**
2. **"Dual-brain" was SUPERSEDED, not lost.** Two different "dual-brain" meanings exist (see §2). The original
   **70B-tied dual-brain** (a big reasoning model + small device model) is **EXCLUDED** per owner. The surviving
   **GPU/ANE DualBrainRouter** is **retired/orphaned Swift code** (compiles, near-zero live callers). The CURRENT
   "two brains" language means **two FACULTIES (coordination + knowledge) of ONE brain** — a rename/reconception,
   not the old model-pair. **[V]**
3. **The 70B was the load-bearing assumption of Helios v1; by v2 it was already abandoned.** Helios v2's own
   verdict says the "center of gravity shifted" off the 70B/new-KV-theory toward residual-first + small/mid
   local models on MLX. So the 70B dependency was dropped *inside the Helios research line itself*, long before
   the owner's 2026-06-22 hard exclusion. **[V]**
4. **The highest-value salvage is already underway**, framed as the System G unification: SCOPE-Rex/AnswerPacket,
   the resonance gate, the provenance ledger, cognitive_dag, and Eidos are the "knowledge brain" being wired to
   one attach point. Everything beneficial is **additive and 70B-free**.

---

## 1. Inventory table — each component, where it is now, state, 70B-tie

State legend: **LIVE** (compiled + wired into product) · **RESEARCH-CRATE** (in `epistemos-research`, gated, by
design) · **ORPHANED** (compiles but ~no live callers) · **DOC-ONLY** (design doc, no impl) ·
**SUPERSEDED-RENAMED** (became X) · **GONE** (not present).

| Component | Where now (path) | State | 70B-tied? | Evidence |
|---|---|---|---|---|
| **SCOPE-Rex full surface** (AnswerPacket W1, Residency Governor W4, Semantic BTM V1.5 W5, Active-Support Atlas W6) | `agent_core/src/scope_rex/` (answer_packet.rs, residency.rs, btm_semantic.rs, witnessed_state.rs, admission_proof.rs, ontology.rs, pro_joint.rs, produce.rs, kernels/, kv/, metal/, retrieval/) | **LIVE** | No | [V] `lib.rs:83 pub mod scope_rex`; dir listed |
| **SCOPE-Rex Core resonance gate** (τ truth / π classify / λ residency) | `agent_core/src/resonance/{mod,tau,pi,lambda}.rs` + Swift `Epistemos/Engine/ResonanceService.swift` | **LIVE** | No | [V] FFI `compute_signature_core` `bridge.rs:1616`; Swift mirror reads it |
| **SCOPE-Rex Pro extension** (δ direction/Koopman, ρ resonance/Laplace–Beltrami) | `agent_core/src/resonance/{delta,rho}.rs` | **LIVE (gated `pro-build`)** | No | [V] `resonance/mod.rs:37-40 #[cfg(feature="pro-build")]` |
| **SCOPE-Rex Research extension** (κ KAM/Diophantine, η evidence/Engram) | `agent_core/src/resonance/{kappa,eta}.rs` | **LIVE (gated `research`)** | No | [V] `resonance/mod.rs:44-47 #[cfg(feature="research")]` |
| **AnswerPacket (Monday-Move 5th primitive)** | `agent_core/src/scope_rex/answer_packet.rs` + `Epistemos/Models/AnswerPacket.swift` | **LIVE** | No | [V] Swift mirror header `// mirror scope_rex/answer_packet.rs` |
| **Residency Governor** (9 residency variants) | `agent_core/src/scope_rex/residency.rs` + Swift `AnswerPacket.swift:247` mirror | **LIVE** | No | [V] |
| **WBO-6 / WBO-7 master inequality** | `agent_core/src/wbo6/mod.rs` (consumes `ResonanceSignatureCore`) + `epistemos-research/src/wbo_generations.rs` | **LIVE (wbo6) + RESEARCH-CRATE (generations)** | No | [V] `wbo6/mod.rs:9` |
| **Six-tier memory L0–L_SE** | `epistemos-research/src/{shadow_memory.rs (MemoryTier L0-L4), self_evolving_l_se.rs}`; **L0 ExactHot active** = `agent_core::shared_memory::ShmPool` | **RESEARCH-CRATE (L1-L4 doctrine) + LIVE (L0 only)** | No | [V] inventory §A4; L0=ShmPool TTL evict |
| **Five planes** (State/Episodic/Assembly/Controller/Verification) | `epistemos-research/src/five_planes.rs`; anchored onto provenance ledger via drift gate | **RESEARCH-CRATE (+ doctrine cross-ref into provenance)** | No | [V] inventory §A3 |
| **HardwareProfile budgets** (M2Pro16Gb 10.5 GB ceiling) | `epistemos-research/src/hardware_profile.rs`; active analog `Epistemos/Omega/Inference/HardwareTierManager.swift` | **RESEARCH-CRATE (+ drift-gate alignment to Swift)** | No | [V] inventory §S1 |
| **Interrupt score gate** ("attention is an interrupt") | `epistemos-research/src/interrupt_score.rs` (oracle) + `Epistemos/Engine/InterruptScoreCpu.swift` (Swift canonical per V6.2) | **RESEARCH-CRATE oracle + LIVE Swift CPU** | No | [V] inventory #13; InterruptScoreCpu.swift present |
| **KV-Direct gate** | `epistemos-research/src/kv_direct_gate.rs` (doctrine) — direct gate wired in MLX lane | **RESEARCH-CRATE doctrine (MLX path live)** | No | [V] inventory #14 |
| **Ternary kernel (BitNet b1.58)** | `epistemos-research/src/ternary_kernel.rs` + `agent_core/src/research/ternary/gemv.rs` | **RESEARCH-CRATE (shader exists)** | No | [V] grep ternary/gemv.rs |
| **ACS (Anchored/Active Capacity Substrate)** | `epistemos-research/src/acs.rs` (doctrine); admission field landed in `agent_core/src/uas/` + Swift `ACSAdmissionHealthRow.swift` | **RESEARCH-CRATE doctrine + LIVE admission slice** | No | [V] uas/ dir + health row |
| **UAS (Unified Agent Substrate)** | `agent_core/src/uas/` (gemma_direct_harness…, namespace source guard tests) | **LIVE (slice)** | No | [V] grep uas/ |
| **Engram (static-knowledge table)** | `epistemos-research/src/engram.rs` | **RESEARCH-CRATE** ("NEVER ships in MAS" per module) | No | [V] inventory #10 |
| **MAS capability lattice** | `epistemos-research/src/mas_capability_lattice.rs`; cross-ref to `ToolTier` | **RESEARCH-CRATE (+ coverage drift gate)** | No | [V] inventory B6 |
| **GateAction taxonomy** | `epistemos-research/src/gate_action.rs`; partial map to `ApprovalDecision` | **RESEARCH-CRATE (+ drift gate)** | No | [V] inventory A5 |
| **CMS-X / CMS v2 (Compute/Memory Stack)** | `epistemos-research/src/cms_v2.rs` | **RESEARCH-CRATE** | No | [V] inventory #4 |
| **Theorems E1–E7 / H1–H17 / PCF / EML** | `epistemos-research/src/{theorem_status,mathematical_pillars,v6_1*,v6_2,wbo_generations}.rs` + `theorems/` + `vpd/`; `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` | **RESEARCH-CRATE + DOC** | No | [V] dir listing |
| **PCF runtime acceleration (rank-1 surgery, connectome distillation)** | `epistemos-vault/src/...` (PCF-5,6,9,10 per DOC 0 §0.2) — Vault crate | **RESEARCH-CRATE (Vault tier)** | **Partial — training/surgery pipeline** | [V] DOC 0 §0.2 insertion sites |
| **Donor distillation / SEAL-DoRA / LearningMode** | `epistemos-research/src/{donor_distillation,learning_modes}.rs` | **RESEARCH-CRATE** (training pipeline; no active analog) | **Yes — training pipeline** | [V] inventory B7 |
| **M2 Max GPU kernels** (SemiseparableBlockScan, LocalRecallIsland, PageGather, ControllerKernelPack, PacketRouter1bit) | `epistemos-research/src/m2_max_kernels.rs` (`KERNEL_IMPLEMENTATION_POSTURE = canonical_target_not_implemented_here`) | **RESEARCH-CRATE (doctrine-only, NOT implemented)** | Partial (SSM-model kernels) | [V] inventory #17 |
| **Lane-4 / Bilaminar / Julia oracle (substrate-independence)** | `epistemos-research/src/lane4_falsifier.rs`; H10 "reserved, never product" | **RESEARCH-CRATE (reserved, never product)** | No | [V] DOC 0 H10 |
| **"Dual-brain" — original 70B reasoning + small device pair** | only in docs (`EPISTEMOS-NORTH-STAR.md`, training/research docs) | **SUPERSEDED / EXCLUDED** | **Yes (the 70B half)** | [V] grep dual-brain in docs |
| **"Dual-brain" — GPU(reasoning)/ANE(device-action) `DualBrainRouter`** | `Epistemos/Omega/Inference/DualBrainRouter.swift` + `HybridRouter.swift` + `HardwareTierManager.swift` | **ORPHANED (retired; compiles, ~no live callers)** | No | [V] AppBootstrap.swift:2291 "retired dual-brain"; callers only self+shadow |
| **"Dual-brain" — CURRENT meaning: two FACULTIES of one brain** | `docs/research/THE_BIG_IDEA_GRAND_CONVERGENCE_2026_06_22.md` | **SUPERSEDED-RENAMED (this is the live concept)** | No | [V] BIG_IDEA §"ONE brain, TWO faculties" |
| **substrate-core / substrate-rt crates** | `substrate-core/` (entity store + AppAction log), `substrate-rt/` (zero-copy SPSC event ring) | **LIVE crates (NOT Helios — deterministic-perf-plan carve-out)** | No | [V] Cargo.toml descriptions; no "helios" in src |
| **Helios v2/v3/v5/v6.1/v6.2 research corpus** | `docs/fusion/` + `docs/fusion/jordan's research/` + `docs/HELIOS_V5_*` | **DOC-ONLY (preserved history/canon)** | mixed | [V] file listing |
| **iCloud R0 raw research archive** | `~/Library/Mobile Documents/.../EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/` | **EXTERNAL ARCHIVE (referenced, not in repo)** | n/a | [V] DOC 0 §0.5 #9 (not verified on disk this session — [I] presumed present) |

**Net finding:** **nothing load-bearing is GONE.** The Helios IP is (a) promoted-live (`scope_rex` + `resonance` +
`wbo6` + `uas` + L0/InterruptScoreCpu), (b) preserved-by-design in the gated `epistemos-research` crate, or (c)
preserved as research/canon docs. The only "drifted/orphaned" code is the GPU/ANE `DualBrainRouter` (explicitly
retired), and the only EXCLUDED IP is the 70B/new-model layer the owner has put hard off-limits.

---

## 2. Lineage — Helios v1→v6.2 → "dual-brain" → today

**Verified chain** (frontmatter + verdicts in the lineage docs):

- **Helios v1 (implicit):** a from-scratch local inference substrate centered on a **70B large local model** +
  novel lossy-KV theory. This is the era whose 70B assumption the owner now excludes. **[I]** (v1 itself not a
  distinct doc; reconstructed from v2's "center of gravity has shifted" framing).
- **Helios v2** (`docs/fusion/jordan's research/helios v2.md`): explicitly records the **pivot OFF the 70B/new-KV
  moonshot** → toward **residual-first computation** (Babai/GPTQ static weights, residual-stream coding, sketch
  tier only where it helps), Rust+MLX+Metal, KV-Direct result. **[V]** This is where the 70B dependency was first
  dropped *within the research line.*
- **Helios v3** (`helios v3.md`): "FINAL FINAL SYNTHESIS" — locks **WBO-6 inequality + six-tier memory L0–L_SE +
  five mathematical pillars**; KV-Direct gate as the single binary action; CMS-X as a constitutive field *on top
  of* the substrate. **[V]**
- **Helios v5** (`docs/HELIOS_V5_DOC_0_INDEX.md` + `helios v5 first/updated.md`): the **canon lock** — five lanes,
  three tiers (collapsed later to MAS+Pro), E1–E7 / H1–H17 / PCF theorem canon, **SCOPE-Rex full surface
  (τ+π+λ Core / +δ+ρ Pro / +κ+η Research)**, W1–W26 PR-ready wiring map. **This is where SCOPE-Rex got its W1–W6
  shipping slices** (AnswerPacket/Residency/BTM/Atlas). **[V]**
- **Helios V6.1** (`EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md`): sharpening, not rename — EML-IR
  arithmetic floor, F-ULP-Oracle as W1, AnswerPacket freeze behind the ULP oracle, five planes formalized
  (State/Episodic/Assembly/Controller/Verification). **[V]**
- **Helios V6.2 = "Epistemos 6.2"** (`docs/fusion/helios v6.2.md`): **Lean-governed, M2-Pro-16GB-falsified,
  recurrent-first** cognitive substrate. Hardware lock = M2 Pro 16 GB. Doctrine: *"If it works on Jojo's M2 Pro
  16 GB, it can ship; if it needs a workstation, it's Pro Vault-Preserved / Pro Research"* — i.e. **the workstation
  / 70B path was already demoted to Vault here.** Swift-CPU InterruptScore canonical; six hardware falsifiers. **[V]**
- **2026-06-01 PATTERNBOOST bridge:** every Helios/UAS/ACS/70B doc got a header redirecting active-architecture
  claims to the Residency/PatternBoost/SemanticWorkingSet/ColdStream fusion docs. **The Helios docs were
  reclassified to "legacy/witness" with falsifier-gated promotion** — this is the formal "research → canon" valve.
  **[V]** (header present verbatim on every Helios doc read).
- **2026-06-22 (today): the GRAND CONVERGENCE** — the owner collapses everything to **ONE brain, TWO faculties**
  (Coordination = System G + TRINITY + RuntimeRouter; Knowledge = Eidos/DAG/provenance/honesty/prompts) on **ONE
  model-agnostic substrate**, and **HARD-EXCLUDES the 70B / from-scratch new model** entirely (no slot, no future
  track). **[V]**

**What absorbed into System G / substrate vs what drifted:**
- **Absorbed (renamed/promoted):** SCOPE-Rex → `scope_rex` + `resonance` modules (live). AnswerPacket → the
  contract every System G run emits (`agent_runtime_v2` flow `…→ MutationEnvelope → RunEventLog → AnswerPacket`).
  Five-plane Episodic/Verification → provenance ledger anchors. L0 memory → ShmPool. Interrupt-score → Swift CPU.
  The "dual-brain" *concept* → "two faculties of one brain."
- **Preserved-not-absorbed (gated research crate):** theorems, M2 Max kernels, six-tier L1–L4, CMS-X, Engram,
  donor distillation, PCF runtime surgery — all `state: candidate`, promotable only via WRV proof.
- **Genuinely drifted/orphaned:** the GPU/ANE `DualBrainRouter` (retired). See §4.

---

## 3. SALVAGE verdict — beneficial IP to HARDEN + FINISH + infuse into System G / the brain (70B-free)

These are additive, safe (won't break the hardened Osaurus/OpenCode clones — they live in `agent_core`/research,
not in the engine lanes), and attach to the current one-brain/one-substrate. Ranked by ROI.

### Tier S — finish what's already promoted (lowest risk, highest leverage)
1. **Eidos closed-citation retriever → wire the REAL module into the run.** This is the "knowledge faculty" prize
   and it's already in the plan (BIG_IDEA GAP 2 + UNIFICATION UNIFY-4). The live `eidos.query` tool **bypasses**
   the real `eidos/` module and hits VaultBackend ("Eidos-in-name-only", `tools/knowledge.rs:244`). **[V]**
   *Attaches:* route `eidos.query` through `agent_core/src/eidos/` (make VaultBackend its lexical backend);
   surface the citation gate (`ChatCoordinator+EidosCitationGate.swift` currently zero callers). **Additive,
   70B-free, finishable behind `EPISTEMOS_EIDOS_V0`.**
2. **Provenance ledger driven BY the run (not just CLI replay).** `ClaimLedger` (retraction propagation, depth
   ≤16) + `ReplayBundle` are built/tested but the global ledger is observe-only — no loop calls `commit_*`. **[V]**
   *Attaches:* System G's AnswerPacket finalize writes claims to the ledger. **Additive.**
3. **`confidence_floor.rs` → resurrect as the honesty-gate scalar.** Owner IP, fully orphaned (zero consumers).
   **[V]** *Attaches:* the brain attach point gates the AnswerPacket confidence (T1≥0.85/T2≥0.75/T3≥0.70).
   **Additive; the alternative is delete — recommend resurrect.**
4. **AnswerPacket / Residency Governor / Witnessed-State — harden the existing live surface.** Already LIVE in
   `scope_rex`; finish making every System G run emit a witnessed, residency-tagged AnswerPacket. **Additive.**

### Tier A — promote a doctrine module that has a clean active analog
5. **Six-tier memory eviction (L1–L4) → extend ShmPool / recall tiers.** L0 ExactHot is live (ShmPool TTL). The
   L1–L4 ladder is doctrine with a drift gate already locking names. **[V]** *Attaches:* recall/Eidos working-set
   eviction policy. 70B-free (it's a memory-tier policy, model-agnostic). Larger lift; promote one tier at a time
   via WRV.
6. **Interrupt-score gate → use the Swift `InterruptScoreCpu` as a live thalamus signal.** Canonical Swift CPU
   impl + Rust oracle exist. **[V]** *Attaches:* RuntimeRouter / System G "when to escalate / wake recall."
   Model-agnostic. Additive.
7. **HardwareProfile budgets → align HardwareTierManager to the M2-Pro-16GB doctrine ceiling.** Drift gate already
   documents the divergence; this is a 0–1 commit decision. **[V]** Additive, 70B-free (the workstation profiles
   are the only 70B-adjacent rows — keep them Vault).
8. **ACS admission field → finish the Diagnostics/health surface.** UAS/ACS admission slice + `ACSAdmissionHealthRow`
   exist. **[V]** *Attaches:* the substrate health panel. Additive.

### Tier B — naming/contract hardening (cheap, prevents future drift)
9. **Five-plane vocabulary, GateAction↔ApprovalDecision, MAS-capability↔ToolTier** — already have doctrine
   cross-references + drift gates from the 2026-05-12 inventory. Keep the gates green; no further code needed
   unless either side moves. **[V]**
10. **WBO-6/7 master inequality** — `wbo6/` is live and consumes the resonance signature; keep it as the
    invariant sampled in the answer path. Additive.

### EXCLUDED from salvage (70B / new-model / training-pipeline dependent — owner hard off-limits)
- M2 Max GPU kernels (SemiseparableBlockScan/LocalRecallIsland/PageGather/ControllerKernelPack/PacketRouter1bit) —
  doctrine-only, tied to the SSM/new-model substrate. **Leave in research crate.**
- PCF runtime acceleration (ActiveRankOneExecution, ModelSurgeryEnvelope, Connectome Distillation, Transfer) —
  Vault-tier model surgery. **Leave in `epistemos-vault`.**
- Donor distillation / SEAL-DoRA / LearningMode — training pipeline; no active analog. **Leave in research crate.**
- Lane-4 / Bilaminar / Julia oracle — "reserved, never product." **Leave.**
- The original **70B reasoning + small device "dual-brain"** model pair — **EXCLUDED entirely** (BIG_IDEA §EXCLUDED).

---

## 4. Honest losses / drift (and recoverability)

1. **GPU/ANE `DualBrainRouter` + `HybridRouter` — ORPHANED/RETIRED.** `AppBootstrap.swift:2291` comment literally
   says "the retired dual-brain". **[V]** Callers are only themselves + the observe-only `RuntimeRouterShadow`.
   - *Loss?* Mild — the *intent* (route reasoning vs device-action to different compute) is **superseded** by
     RuntimeRouter (per-task model selection) and the device-agent path, which are the live forward direction.
   - *Recoverable?* Yes — it's compiled Swift still on disk; nothing is lost. **Recommendation: do NOT resurrect
     the GPU/ANE pair** (it presumes a model-pair posture); fold its routing intent into RuntimeRouter promotion
     (UNIFY-2). Delete only after RuntimeRouter is authoritative.
2. **The full SCOPE-Rex W7–W26 wiring map** (half-softmax rewrite W7, Active-Support Atlas W6 full, Tier-2 flagged
   kernels W9–W15, tooling W23–W26) — **partially landed.** AnswerPacket/Residency/BTM (W1/W4/W5) are live; the
   GPU-kernel-side slices (W6–W8 Tier-1 kernel paths, W9–W15) are doctrine/flagged. **[V]** (DOC 0 §0.8). This is
   "unfinished" not "lost" — the specs + drift gates are intact; promotion needs WRV proof. Many of the unfinished
   slices are the **SSM-kernel** ones that lean toward the excluded new-model substrate — skip those.
3. **iCloud R0 raw archive** — referenced as the primary E1–E7 source but **NOT verified on disk this session**
   (it's outside the repo). **[I]** If recovery of the deepest theorem provenance is ever needed, that path
   (`~/Library/Mobile Documents/.../EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/`) is the place; confirm it
   still exists.
4. **No code deletions found.** Per the PRESERVATION_FIRST policy + PATTERNBOOST bridge headers, Helios material
   was reclassified (legacy/witness), never deleted. Git history (`git log --all | grep helios`) shows a long
   chain of `test(helios):` + `docs(t09-ledger)` commits — full provenance is recoverable from git regardless.

---

## 5. PLAN ADDITIONS (paste-ready)

```
[HELIOS-SALVAGE-0] DOCTRINE: The Helios-era IP is NOT lost. It lives in 3 buckets:
  (a) PROMOTED-LIVE in agent_core (scope_rex, resonance τ+π+λ+δ+ρ+κ+η, wbo6, uas, L0/InterruptScoreCpu);
  (b) PRESERVED in epistemos-research/ (gated, doctrine-target; promote only via WRV);
  (c) DOCS (docs/fusion Helios v2→v6.2 canon, PATTERNBOOST-bridged to legacy/witness).
  The 70B / from-scratch new model is EXCLUDED ENTIRELY (owner 2026-06-22) — do not promote
  any research-crate module that depends on it (M2 Max kernels, PCF surgery, donor distillation, Lane-4).

[HELIOS-SALVAGE-1] (= UNIFY-4) Wire the REAL eidos/ retriever + provenance ClaimLedger +
  resurrected confidence_floor into the ONE System G brain attach point. Route eidos.query
  THROUGH eidos/ (VaultBackend = its lexical backend). Give the citation gate real callers.
  Accept: a live run emits an AnswerPacket whose citations are eidos source_ids, whose claims
  are in the ledger, whose confidence passes the floor. Behind EPISTEMOS_EIDOS_V0. 70B-free.

[HELIOS-SALVAGE-2] Harden the live SCOPE-Rex surface: every System G run emits a witnessed,
  residency-tagged AnswerPacket; wbo6 invariant sampled in the answer path. Additive.

[HELIOS-SALVAGE-3] (Tier A, larger lift, per-tier WRV) Promote six-tier memory L1 over ShmPool's
  live L0 as the recall/Eidos working-set eviction policy; keep the drift gate green. Model-agnostic.

[HELIOS-SALVAGE-4] Use Swift InterruptScoreCpu as a live escalation/recall-wake signal feeding
  RuntimeRouter / System G (the "thalamus"). Validate against the Rust oracle. Additive.

[HELIOS-SALVAGE-5] Align HardwareTierManager to the M2-Pro-16GB doctrine ceiling (0-1 commit;
  decision already documented by the drift-gate alignment table). Keep workstation profiles Vault.

[HELIOS-SALVAGE-6 / CLEANUP] DualBrainRouter + HybridRouter (GPU/ANE) are retired/orphaned —
  do NOT resurrect the model-pair posture; fold routing intent into RuntimeRouter promotion
  (UNIFY-2), then delete after RuntimeRouter is authoritative. Confirm iCloud R0 archive still
  exists for deepest theorem provenance.
```

---

## 6. Open questions (owner decision)

1. **Six-tier memory promotion (SALVAGE-3):** worth the lift to promote L1–L4 over ShmPool, or is L0 + Eidos
   recall sufficient for the product? (It's model-agnostic and 70B-free, but it's the largest item here.)
2. **InterruptScore as live thalamus (SALVAGE-4):** do you want a live "when to escalate/wake recall" gate driving
   RuntimeRouter, or keep escalation heuristic for now?
3. **`confidence_floor.rs`:** resurrect as the honesty-gate scalar (owner IP) or delete? (BIG_IDEA + UNIFICATION
   both recommend resurrect.)
4. **DualBrainRouter:** confirm OK to delete once RuntimeRouter is authoritative — or preserve as a witness?
5. **iCloud R0 archive:** should I verify it still exists on disk and re-anchor the SHA-256 table, or leave the
   external archive untouched?
6. **HardwareProfile 16 GB divergence (SALVAGE-5):** align Swift's 60% formula to the 10.5 GB doctrine ceiling,
   or keep the documented divergence?

---

*Grounded against files read 2026-06-22. Key paths: `agent_core/src/{scope_rex/,resonance/,wbo6/,uas/,eidos/,
cognitive_dag/,provenance/,confidence_floor.rs,shared_memory.rs}`, `epistemos-research/src/*`,
`substrate-core/`, `substrate-rt/`, `Epistemos/Omega/Inference/{DualBrainRouter,HybridRouter,HardwareTierManager}.swift`,
`Epistemos/Engine/{ResonanceService,InterruptScoreCpu}.swift`, `Epistemos/Models/AnswerPacket.swift`,
`Epistemos/App/AppBootstrap.swift:2291`. Docs: `docs/HELIOS_V5_DOC_0_INDEX.md`, `docs/fusion/helios v{2,3,5,6.2}.md`,
`docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md`, `docs/audits/{PRE_HELIOS_FEATURE_AUDIT,
HELIOS_SUBSTRATE_INVENTORY}_*.md`, `docs/research/{THE_BIG_IDEA_GRAND_CONVERGENCE,ARCHITECTURE_UNIFICATION_SYSTEMG}_2026_06_22.md`.*
