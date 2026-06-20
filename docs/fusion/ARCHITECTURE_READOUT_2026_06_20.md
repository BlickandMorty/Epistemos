# Epistemos — Consolidated Architecture Readout (2026-06-20)

> **NON-AUTHORITY consolidation doc.** Companion to `docs/fusion/RESEARCH_LOOP_LEDGER_2026_06_20.md`
> (passes 1–11) + `RESEARCH_INTENT_AND_QUERY_LOG_2026_06_20.md` (owner queries Q1–Q26). Does NOT modify
> authority docs (Living Index, lattice explainer, `MASTER_*`). Honesty per the Architecture Tier
> Promotion Canon: **T0**=ambition/research · **T1**=L1 metadata/spec proof · **T2**=admitted route ·
> **T3**=WRV surface · **T4**=build-green · **T5**=full substrate. "Green" reserved for T4+.
>
> **SPINE FRAMING (the one-sentence picture):** *Epistemos is a **dual-brain** system — the **model**
> (brain 1: an SSM-spine generator) emits signals, the **app** (brain 2: typed authority + deliberation)
> decides and signals back, and **Rust is the fast bus** between them that makes interrupting and
> co-working cheap.* model = generation · app = authority · Rust = the low-latency interrupt substrate.
>
> **Original term (PASS-14):** the owner's older name for brain-2 authority was **"controller plane"**
> (routing / ACS-admission / runtime decisions); the genesis thesis is the V6.1 *"attention is an interrupt"*
> doc (May 6 2026). "dual-brain" in code = the model↔**model** DualBrainRouter (GPU reasoning + ANE action),
> a different axis; "split-brain" is a BUG term, not this split.
>
> **S-UAS-COMPUTE optimization map (PASS-14):** the architecture is compute-light by design — replace dense
> matmul with integer add/sub, memory lookup, or zero-copy pointers, each gated by a correctness falsifier:
> U1 FFN→Engram lookup · U2 FMA→ternary add/sub · U3 full-attn→SSM+interrupt · U4 KV-recompute→KV-Direct ·
> U5 2nd-index→W-51 shadow recall · U6 serialization→zero-copy · U7 dense-routing→1-bit/sparse+FlashMoE ·
> U8 weight-VQ→lattice (only if Metal-coalesced; else ternary wins) · U9 verify-recompute→DAG replay.
> None "free" until its falsifier passes. (Full table: ledger PASS-14 §2.)

---

## 0. The picture in one diagram

```text
        ┌───────────────────────── BRAIN 1: MODEL (generation/spine) ─────────────────────────┐
        │  Mamba-3 SSM default lane  ──(attention sinks: 4 sink toks + sliding window)──►       │
        │  per-token InterruptScore u_t  ──►                                                    │
        │  ternary/quant lane (Bauer-Fike-bounded)   Engram lookup plane   KV-Direct (UMA)      │
        └───────────────┬───────────────────────────────────────────────────────────▲─────────┘
                        │ DOWNLINK (scalars only)                        UPLINK (scalars/enums)
                        │ InterruptScore/token, AnswerPacket/turn                    │
        ┌───────────────▼─────────── RUST BUS: signal_bus.rs (the fast substrate) ───┴─────────┐
        │  SPSC downlink ring (drop-oldest telemetry) · SPSC uplink ring (single-writer)        │
        │  apply-at-token-boundary (O(ns) atomic) · seqlock AnswerPacket · generation-id        │
        │  GATES: M0 F-Interrupt-Moves-Loss · M1 InterruptInvariant + Bauer-Fike WBO-6          │
        │  D1-COMMS hardened: 10 downlink falsifiers + 6 uplink falsifiers                       │
        └───────────────┬───────────────────────────────────────────────────────────▲─────────┘
                        │ evidence/commands                                           │ signals
        ┌───────────────▼─────────── BRAIN 2: APP (authority/deliberation) ──────────┴─────────┐
        │  RuntimeRouter (authority; no-hidden-authority) · active_assembly (nervous system:    │
        │  which mechanisms fire) · Model Cockpit (uplink controls + downlink telemetry) ·       │
        │  W-51 shadow recall (warm BM25+HNSW+RRF k=60) · Cognitive DAG/verify · Never-Retrain  │
        │  AnswerPacket · RunEventLog · LatticeAbstentionGate · ComputeResumeLease               │
        └───────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. BRAIN 1 — the MODEL (generation/spine)

| Segment | What it is | Where | Honest tier |
|---|---|---|---|
| **Mamba-3 SSM spine** | inference-first SSM (exp-trapezoidal discretization · complex-valued state · MIMO); Pareto front — comparable quality at **½ the state size** (arXiv:2603.15569) | spine candidate; `research/mamba3.rs` + `scan_ir` hold SSM substrate; **no shipped Metal selective-scan kernel** | **T0/T1** — substrate + IR built; **Mamba-3 deferred to B3** (its complex state is what M1 Bauer-Fike governs + B3 kernel targets). **M0 uses a VANILLA state-tracking-weak SSM** (PASS-15) so the interrupt is the clean single variable. Grounding: Jamba ablation — pure Mamba fails ICL, sparse attention fixes it (arXiv:2403.19887); B'MOJO/Priming distill-from-Transformer (arXiv:2605.08301) |
| **Attention-sinks default lane** | 4 permanent sink tokens + sliding window stabilize the linear/SSM lane between interrupts (StreamingLLM, arXiv:2309.17453) | `research/attention_sinks.rs` (`detect_sinks`, `sink_strength`) + Koopman-spectral reading | **T1** — math/verdict surface; not wired to a live attention kernel |
| **Interrupt gate (`u_t`)** | per-token score; if `> τ` switch next K tokens to full attention; AUROC≥0.85 bar (Youden-J) | `research/interrupt_calibration.rs` + `interrupt_score.rs` | **T1** — calibration math + bar; **M0 still open** (does it move loss at toy scale?) |
| **Ternary / quant lane** | low-bit weights; safety = Bauer-Fike eigenvalue bound (WBO-6); kernel refs: **bitnet.cpp v2** (2026-01, I2_S/TL1/TL2, +1.15–2.1×, NPU coming), **Litespark** (arXiv:2605.06485 — NEON SDOT on Apple Silicon M1–M5, 18–97× tput / 6× mem), **BitDistill** (distill→1.58-bit, 10× mem, the feasible single-box path) | `research/ternary/*` (trit/pack/gemv/backend) + `H4.lean` Babai bound | **T0/T1** — kernels research; gated behind **M1** Bauer-Fike proof (concrete Apple-Silicon kernel refs now exist) |
| **Engram / Lookup plane** | O(1) hashed N-gram conditional-memory lookup (DRAM table), 20–25% sparse-budget optimum (DeepSeek, arXiv:2601.07372) | `epistemos-research/src/engram.rs` (Lane-3 type surface only) | **T0→T1** — concept + typed surface; mechanism not built; 20–25% now primary-source-validated |
| **KV-Direct (UMA)** | KV/weights in unified memory, no CPU↔GPU copy | `MLXInferenceService` UMA sizing; `falsify_uas_zero_copy_spine.rs` | **T1** (Rust spine copy-count=0) — Swift/Metal paths unmeasured; **no zero-copy text→KV API** (honest) |

**Honest brain-1 status:** the math substrate for every organ exists (T1), but **no end-to-end model is
shipped** — the spine is research-tier until M0 proves the interrupt and a Metal scan kernel lands (B3).

---

## 2. RUST BUS — the fast interrupt substrate (the spine that makes dual-brain cheap)

| Segment | What it is | Honest tier |
|---|---|---|
| **`signal_bus.rs`** (proposed) | SPSC downlink ring (runtime→app: InterruptScore/token, AnswerPacket/turn — drop-oldest telemetry) + SPSC uplink ring (app→runtime: τ/lease/abstain/route — single-writer, apply-at-boundary) | **T0 spec** (PASS-4/5/9) — not built; the seam is fully specified |
| **M0 gate — `F-Interrupt-Moves-Loss`** | toy CPU SSM + interrupt; 3 arms (always-SSM / always-attn / gated); 4 axes: moves-loss · beats-random · AUROC≥0.85 · efficient (≥½ gap at ≤25% fire-rate) | **T0 spec** (PASS-6), build-ready on green-light; **the gate that unblocks everything** |
| **M1 gate — InterruptInvariant** | every AnswerPacket: `attention_mode ∈ {dynamic, static_fallback, unavailable}`; static_fallback ⟺ StaticFallbackAcknowledged claim | **T1** — already a coded Rust predicate (`answer_packet.rs`); Lean lift spec'd (provable sorry-free by enumeration) |
| **M1 gate — Bauer-Fike WBO-6** | quantizing the SSM A shifts Koopman eigenvalues by ≤ κ(V)·‖ΔA‖ — the ternary-lane safety bound | **T0/T1** — `H4.lean` scaffold (sorry); proof strategy spec'd (mathlib port / finite-dim case, budget ≤4) |
| **D1-COMMS hardened contract** | 10 downlink failure modes (`F-Bus-Backpressure`…`F-Generation-Skew`) + 6 uplink controls (`F-Tau-Apply`…`F-Abstain-Policy`) | **T0/T1 spec** (PASS-9/10) — **Model Cockpit end-to-end falsifier-covered** |

**Why Rust is the spine:** decode is bandwidth-bound (~10–50 ms/token on the 200 GB/s M2 Pro); the bus must
add **<1%** (`F-Signal-Bus-Overhead`). Scalars/enums only cross the control plane; tensors/KV stay in UMA.
This is what makes interrupting + co-working *cheap* — the whole dual-brain idea hinges on it.

---

## 3. BRAIN 2 — the APP (authority/deliberation)

| Segment | What it is | Where | Honest tier |
|---|---|---|---|
| **RuntimeRouter / authority** | route/lane adjudication (intra-lane chooser: mlx/gguf/cloud/stub; NOT the model-id picker); **no-hidden-authority** (model REQUESTS, app DECIDES — owner's Codex axiom) | `RuntimeRouter.swift` `route()` 0 live callers, BUT `RuntimeRouterShadow.swift` is a built STAGE-1 shadow scaffold behind `EPISTEMOS_RUNTIMEROUTER_LIVE_V0`; `routeProfiles()` rehosted | **T1 — dead on live path but SCAFFOLDED**; gap is PROMOTION (STAGE 1b→4), not greenfield wiring. `F-RuntimeRouter-Live` (parity/authoritative/honest-nil/no-hidden-authority) retires it. The cockpit route control (S-PANEL) binds here |
| **active_assembly (nervous system)** | decides which mechanisms/experts/cold-assembly units FIRE; MarginAnchoredGreedyPull; 4-bit Hamming + cost<0.40 + firing<0.50 | `research/active_assembly/*` + `F-ActiveAssembly-Minimal` | **T1** — brain-2's executive (core primitive) |
| **Model Cockpit** | S-PANEL: uplink controls (τ/route/residency/ternary/fast-weight TTL/abstention) + downlink telemetry (InterruptScore sparkline + AnswerPacket feed) | read-half EXISTS (`ProvenanceConsoleView`); write-half spec'd | **T0/T1** — read-half built; uplink spec'd + falsifier-covered |
| **W-51 shadow recall** | unify model recall onto the warm `epistemos-shadow` BM25+HNSW+RRF k=60 (kills the duplicate colder VaultStore index). **Embedding-parity invariant (PASS-12):** index + query must use the SAME embedder — manifest stamp (`embedder_id/dim/norm/tokenizer_hash`) enforced, mismatch abstains (never silently wrong) | `eidos/` (ShadowBackedSemanticIndex spec'd; `produce_eidos_context_packet` seam exists) | **T0/T1 spec** — NOT-STARTED in code; build-plan + `falsify_shadow_recall_parity` + `F-Shadow-Embedding-Parity` ready |
| **Cognitive DAG / verification** | 10 NodeKind/10 EdgeKind, resonance, provenance ledger; the verification + claim graph | `cognitive_dag/*`, `provenance/ledger.rs` | **T1+** — substantial real code (per CLAUDE.md) |
| **Never-Retrain / continual-learning** | EWC + OFTv2 + DSC + Titans-MAC + SEAL-DoRA; fast-weights gated by quarantine + NeverRetrain invariant | `research/continual_learning/*` | **T1** — all 5 sub-features + envelope landed; adapter-scale feasible on 16 GB |
| **InstantRecall (S-APP-FAST)** | <3 ms binary-quant vector index, provenanced, cancellation-aware | `KnowledgeFusion/InstantRecallService.swift` | **T1+ shipped** — real, hardened |
| **DualBrainRouter (prior art)** | model↔**model** split (GPU reasoning + ANE device-action) — DISTINCT from model↔app S-SPLIT | `Omega/Inference/DualBrainRouter.swift` + `HardwareTierManager` | **T1+ shipped** — complementary axis; ANE reachable via Core ML |

---

## 4. THE SIGNAL CONTRACT (model emits → app deliberates → app signals back)

- **Downlink (model→app):** per-token `InterruptScore` (cheap scalar) + per-turn `AnswerPacket`
  (`claims`, `residency_signals`, `ui_label`, `attention_mode`, `witnessed_state_ref`). Streamed, never buffered.
- **App deliberation (brain 2):** RuntimeRouter adjudicates routes; active_assembly picks the firing set;
  Cognitive DAG / W-51 recall ground + verify; LatticeAbstentionGate + Belnap `Neither→defer` decide abstain.
- **Uplink (app→model):** `τ` · `ComputeResumeLease` (grant/revoke heavy lane) · abstain · route/lane ·
  residency budget · ternary toggle · fast-weight TTL. Applied at the next safe **token boundary**.
- **Where the interrupt lives:** the **score** is computed model-internally (brain 1); the **threshold τ +
  the decision to honor/wake/abstain** are app-side authority (brain 2); Rust carries both directions.
- **Typed primitives (existing):** `AnswerPacket` (implemented, no caller yet), `InterruptScore`/calibration,
  `LatticeAbstentionGate`, `ComputeResumeLease`, `ColdAssemblyPlan`, `InterruptInvariant`, `RunEventLog`.

---

## 5. THE BUILD ORDER (M0 → M1 → heavy lanes; built vs spec'd vs ambition)

```text
M0  F-Interrupt-Moves-Loss   [T0 spec]  ← prove the interrupt moves loss at toy scale (CPU). GATE.
M1  InterruptInvariant       [T1, Lean lift spec'd]  +  Bauer-Fike WBO-6 [T0/T1] ← formal honesty + ternary safety
B1  sliding-window cache + row-col bundling   [T1, app-only — buildable now, rides Helios]
B2  pre-attention predictive prefetch (DejaVu/PowerInfer)  [T1]
B3  SelectiveScan.metal bit-exact vs Mamba-3   [T2]  ← blueprint Week-1 kernel, RE-ORDERED to here
B4  ReLU² activation-sparsity spine + SpQt zigzag (arXiv:2511.04477, Apple-Silicon 1.55×)  [T0→T2]
B5  Engram/MoLKV lookup plane + first-class Lookup plane  [T0→T1]
B6  HeavySkill deliberation loop (halt→K trajectories→verify→inject→resume)  [T2→T3]
```
**Rule:** M0 → M1 → app-systems (B1/B2) → kernels (B3) → model-arch (B4/B5) → deliberation (B6). Nothing
dropped; the blueprint's kernel-first sequence is re-ordered behind the M0/M1 gate.

**Decode acceleration (PASS-12, optional B-phase add-on, gated behind base-route equivalence):**
**MLX-native speculative decoding** (mlx-lm 0.21 draft-and-verify) is the *practical* Apple-Silicon lane
[T1-available]; **ANE drafting** (DFlash-style) stays **T0/hard** (precision mismatch + heterogeneous
draft/target pipelines). Per CLAUDE.md MTP canon: an acceleration packet only after the base route exists +
target verification preserves the answer digest + rollback.

- **Already BUILT (T1+):** InstantRecall, DualBrainRouter+HardwareTierManager, Cognitive DAG, the research
  substrate (interrupt calibration, ternary, Koopman, scan_ir, active_assembly, continual_learning, Eidos
  in-memory backends, Lean theorem scaffolds), AnswerPacket type, ProvenanceConsole (cockpit read-half).
- **SPEC'd (T0/T1, build-ready on green-light):** M0, M1, signal_bus.rs, D1-COMMS contract, S-PANEL uplink,
  W-51 ShadowBackedSemanticIndex, the 7 blueprint items.
- **AMBITION (T0):** the shipped end-to-end Mamba-3 model, the live Metal scan/ternary kernels, single-box
  training (only adapters/QAT feasible on 16 GB — full retrain is NOT).

---

## 6. THE PRIMITIVE FAMILY (S-PRIM) roll-up

| Primitive | Role | Side | Tier |
|---|---|---|---|
| **EML** | ULP arithmetic floor / oracle gating AnswerPacket | app-side verification | T1 |
| **Geometry-IR** | Clifford rotor = SO(n)/RoPE-family orthogonal op (gradient-norm-preserving) | model-internal + app | T1 |
| **Koopman** | SSM-as-operator; Bauer-Fike bound → ternary-lane safety | model-internal | T1 |
| **Belnap FDE** | 4-valued claim truth; `Neither→abstain`, `Both→contradiction` | app-side deliberation | T1 |
| **E2 (Ultrametric-Sheaf Gluing)** | glue locally-consistent evidence → global section; conflict → abstain | app-side | T1 |
| **scan_ir** | selective-scan IR with bit-exactness certificate (M0/B3 compiles from it) | model-internal | T1 |
| **active_assembly (AAR)** | the nervous system — which mechanisms fire (brain-2 executive) | app-side (core) | T1 |
| **continual_learning** | Never-Retrain fast-weights stack (EWC/OFTv2/DSC/Titans-MAC/SEAL-DoRA) | both, quarantine-gated | T1 |
| **Tropical** | exact theory of the ReLU² spine (tropical region-count ↔ activation sparsity) | model-internal theory | T1 |
| **hybrid_memory** | MD+JSON memory store (soul/skill/episode/semantic.v1) | app-side memory format | T1 |
| **substrate_independence** | cross-backend agreement harness (same answer ≤ tolerance) — the proof behind ternary/M0 CPU-canonical | cross-cutting verification | T1 |
| *Kuramoto* | speculative consensus-`r` abstention candidate (kill-switch falsifier) | app-side (candidate) | T1 (speculative) |
| *acs* | governance framing (recursive residency envelope + closure validator beneficial; 6-scale doctrine not a model organ) | app-side governance | T1 (framing) |
| *info_ir/operator_ir* | verification IRs (certificate substrate), not model spine | app-side verification | T1 |
| *H14 (Apollonian)* | advisory fence (local-global conjecture FALSE) — NOT a beneficial primitive | — | T0 advisory |

**S-PRIM inventory status: COMPLETE for the research/ tree** (EML/Geometry/Koopman/Belnap/E2/scan_ir/
active_assembly/continual_learning/Tropical/hybrid_memory/substrate_independence evaluated; Kuramoto/acs/
info_ir/operator_ir/H14 recorded with honest caveats). No forced inclusions.

---

## 7. HONEST GAPS + the single recommended next action

**Honest gaps (cycle 3):**
1. **No end-to-end model exists** — every brain-1 organ is T1 substrate; nothing generates tokens yet.
2. **M0 is unproven** — the entire thesis rests on "the interrupt moves loss," which has NOT been measured.
3. **The bus is unbuilt** — `signal_bus.rs` is a spec; AnswerPacket has no production caller (PASS-15 spec'd
   the first-caller: `StreamingDelegate` emits one per end-of-turn with honest `attention_mode`,
   `F-AnswerPacket-Emitted`, flag `EPISTEMOS_ANSWERPACKET_EMIT_V0`, promotes implemented→wired); RuntimeRouter
   `route()` has 0 live callers — but it is **SCAFFOLDED** (PASS-13): `RuntimeRouterShadow.swift` STAGE-1
   observe-only machinery is built behind `EPISTEMOS_RUNTIMEROUTER_LIVE_V0`, `routeProfiles()` rehosted; the
   gap is PROMOTION (STAGE 1b→4), not greenfield wiring. (keystone #1, status upgraded.)
4. **Spine choice unsettled** — Mamba-3 is the candidate but the M0 toy + B3 kernel target it only on paper.
5. **W-51 NOT-STARTED** — the highest-value bespoke win is a build-plan, not code.

**THE SINGLE RECOMMENDED NEXT ACTION (when the owner lifts the `docs_first` hold):**
> **Build M0 (`F-Interrupt-Moves-Loss`)** — the CPU-canonical toy that proves the interrupt moves loss.
> It is cheap (seconds, no GPU), it is the gate every downstream milestone depends on, and a PASS/FAIL
> result either justifies the whole dual-brain investment or honestly kills it. Everything else (kernels,
> ternary, cold lane, cockpit wiring) is correctly sequenced *behind* it.

Until then: the architecture is a **coherent, honestly-tiered, falsifier-covered SPEC** — a real plan, not
a shipped system. That distinction is the point of this readout.

---

*This readout consolidates loop passes 1–11. It is append-superseded: future passes update it in place or
note deltas in the ledger. Last updated: 2026-06-20 (PASS 11; Code-Readiness Audit added post-PASS-15).*

---

## 8. CODE-READINESS AUDIT (2026-06-20, post-PASS-15 — research STOPPED, deliberation mode)

### 8.1 Completeness — owner directives Q1–Q30 all reflected (4 honest thin spots)
Every directive Q1–Q30 (intent log) maps to a ledger pass / readout segment (cross-checked). **Thin/partial
(none code-blocking):** (1) **PARS architecture** (Q4) named once, never explicitly resolved; (2) the
**full dropped-idea register** (Q10 "hosts of many theoretical ones") — several revived (E2, lattice, EML,
cold-assembly, fast-weights) but no exhaustive standalone register in the durable docs; (3) **phrase-named
Downloads folders** (Q8) surveyed (PASS-1) but not all deep-mined (mostly pre-consolidation); (4) the
**full E/H/F/K/W theorem catalog** (Q10) — only the load-bearing theorems (E2, H4/Bauer-Fike, H14,
InterruptInvariant) rolled into the readout; the rest live in `HELIOS_V5_DOC_6_THEOREM_CANON.md`.
**By-design deferrals (NOT gaps):** Living Index + lattice-explainer updates (Q10) are authority-doc
write-plans, correctly NOT edited. Inventory complete: 15 S-PRIM primitives, M0/M1 + 16 cockpit + segment
falsifiers, Codex/Claude mining concluded (genesis = V6.1 "Attention as Interrupt" doc), Gemini eval folded.

### 8.2 Adversarial probe — tensions RESOLVED
- **ternary-needs-QAT vs single-box training:** resolved — ternary uses a QAT'd/**distilled** model
  (BitDistill 10× mem) acquired off-box; only adapters/QAT/distill are 16 GB-feasible, full pretrain is NOT.
- **ATLAS (model owns compute control) vs app-owns-authority:** deliberate fork — Epistemos keeps allocation
  authority app-side; cost is low because only the **threshold τ + lease** are app-side (cheap), the
  per-token **score** is model-side. Defensible, not a contradiction.
- **lattice-VQ vs ternary on M2 Pro:** resolved — ternary (Litespark NEON / bitnet.cpp) is default; lattice
  VQ stays research unless it proves Metal-coalesced decode (U8).
- **Mamba-3 vs vanilla-SSM for M0:** resolved (PASS-15) — vanilla at M0, Mamba-3 at B3.
- **THE soundness key:** the bus is **policy-async, NOT decision-sync** — the app sets τ + grants a
  `ComputeResumeLease` budget AHEAD of time; the model applies the gate + spends the lease LOCALLY per
  token; the app revokes async if exceeded. So brain-2 authority never blocks token *t* to decide token
  *t* → the <1% bus-overhead target is achievable and the split is deadlock-free (SPSC per direction).

### 8.3 Verdict: **GO for M0** (conditional on owner green-light)
The architecture is a coherent, honestly-tiered, falsifier-covered SPEC. The first artifact is unambiguous.

**FIRST ARTIFACT — `falsify_interrupt_moves_loss` (M0):**
- *File:* `agent_core/src/bin/falsify_interrupt_moves_loss.rs` (feature `research`, CPU-only, no Metal/MLX/
  download). *Helpers:* `agent_core::falsifier_artifacts` (ArtifactBuilder/axes/Measurement/write_artifact);
  reuse `research::interrupt_calibration::auc_roc` + the SSM substrate in `research::mamba3`/`scan_ir`.
- *Backbone (LOCKED PASS-15):* a **vanilla state-tracking-weak linear SSM** (~2 layers, d_model 64–128,
  pure-Rust f64) — NOT Mamba-3. Deterministic seed.
- *3 arms:* always-SSM · always-attention · interrupt-gated. *Task:* synthetic copy/associative-recall
  spans the SSM fails + ground-truth `interrupt_needed` labels.
- *4 pass/fail axes:* `axis_moves_loss` (loss_delta_vs_ssm > ε) · `axis_beats_random` (gated < random-gate
  at equal fire-rate) · `axis_calibrated` (interrupt_auroc ≥ 0.85) · `axis_efficient` (recovery ≥ 0.5 at
  fire-rate ≤ 0.25). `overall_pass = all four`; exit 1 + name failing axis on fail.
- *result.json:* `artifacts/falsifiers/interrupt_moves_loss/result.json` — `{falsifier_id, fixture_id,
  command, created_utc, overall_pass, axes{...}, measurements[...], fallback_tier, notes}` (mirrors
  `falsify_70b_local_cocktail_lite.rs`).

**BUILD ORDER after M0 (entry criteria):** M0 PASS → **M1** (close InterruptInvariant + Bauer-Fike Lean
`sorry`; entry: M0 green) → **AnswerPacket emit** (`StreamingDelegate`, flag `EPISTEMOS_ANSWERPACKET_EMIT_V0`;
entry: M1 InterruptInvariant discharged) → **RuntimeRouter promotion** (STAGE 1b parity → 2 authoritative;
entry: shadow parity passes) → **W-51 shadow recall** (+ embedding-parity; entry: independent, anytime) →
**B1** sliding-window+bundling → **B2** prefetch → **B3** SelectiveScan.metal (Mamba-3) → **B4** ternary+SpQt
→ **B5** Engram → **B6** HeavySkill.

### 8.4 Decisions that need the OWNER before coding
1. **Lift the `docs_first` hold** (Q10b) — M0/M1 crafting is explicitly held; nothing is built without this.
2. **Spine commitment** for B3 (Mamba-3 vs a B'MOJO-style SSM+SWA hybrid) — NOT needed for M0 (vanilla),
   needed before B3.
3. **Workspace-path change** (noted 2026-06-20) — confirm the build env (xcodebuild scheme / `cargo
   --manifest-path agent_core/Cargo.toml`) still resolves from the new workspace root; files remain at
   absolute `/Users/jojo/Downloads/Epistemos/`.
4. **Build-scope confirm** — M0 is a Pro/research-tier Rust falsifier binary (not MAS); confirm that target.

### 8.5 Completeness closure — the 4 thin spots RESOLVED (post-PASS-15)
1. **PARS (Q4) = the Parameter Connectome Family (PCF-1..10)** — Goodfire VPD (SPD arXiv:2506.20790 + APD
   2501.14926), `epistemos-research/src/vpd/*`; the "parameter-connectome" lane of the V6.1 five-lanes.
   Role: model-internal mechanistic-interpretability / parameter-graph (understand + surgically edit the
   model's own weights). Tier T1 candidate (L3 research-only). NOT lost; now mapped. Not an M0 blocker.
2. **Dropped-idea register** (ledger FINAL CLOSURE §2) — 15 entries with revive/skip: REVIVED (ternary/one-bit,
   PCF, hyper-deterministic→selective-determinism, EML-with-fence, Hopfield-recall); ABSORBED (1B Hybrid
   Mamba-2 device agent, seven theorems→E1-E7, zero-copy, Koopman, Helios organs); KEEP-Pro (TurboQuant);
   SKIP (SOAR, cognitive-friction, Apollonian).
3. **Phrase-named Downloads folders** — deep-surveyed; confirmed predominantly pre-consolidation (2026-03→05)
   app-feature/training specs; architecture-relevant content already captured; **no new idea surfaced**.
4. **Full theorem catalog** — E1–E7 (Foundational Seven) · H1–H17 (Helios) · PCF-1–10 (Parameter Connectome)
   indexed in the ledger (id · proof state · lane · insertion site). None are product-green (T4); L1–L3
   research/architectural. Detail in `HELIOS_V5_DOC_6_THEOREM_CANON.md` (NOT edited).

**Nothing material is left out.** Verdict UNCHANGED: **GO for M0** on owner green-light; the 4 owner
decisions (lift docs_first · B3 spine commitment · build-env/workspace-path · M0 Pro/research scope) stand.

*Bottom line: the research+design phase is COMPLETE and audited. Ready to code M0 on green-light.*
