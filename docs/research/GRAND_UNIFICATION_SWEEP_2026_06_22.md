# GRAND UNIFICATION SWEEP — Epistemos local-research IP (2026-06-22)

Multi-cycle sweep authorized by the owner (OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md §"GRAND UNIFICATION
SWEEP"). Goal: locate + classify + map ALL of the owner's local-research IP toward unifying the beneficial
parts into the current architecture (System G / the IP brain / the model-agnostic substrate). Runs cycle
after cycle until a cycle finds nothing new.

**Authority:** PLAN_V2 / the addendum is authority — fix code to match plan, never the reverse. This is a
research/spec artifact. Do NOT commit (per the owner's sweep directive — findings fold into the plan, the
doc grows each cycle).

**Anti-hallucination:** every claim is grounded in a file read this session and tagged **[V]** VERIFIED
(path/line read) or **[I]** INFERRED (reasoned from verified facts). Paths are absolute-relative to the repo
root `/Users/jojo/Downloads/Epistemos/`.

**Hard exclusion (owner 2026-06-22, addendum §"70B STAYS OUT, PERIOD"):** the from-scratch NEW MODEL
(SSM/Mamba-3, M0 interrupt, signal_bus, lattice-WBO, ternary/QAT model-runtime) and the **70B** are HARD
OFF-LIMITS and EXCLUDED from the convergence — NOT a future track, NO reserved slot, NOT a decision to
revisit. Anything tagged **70B-TIED** below is recorded for completeness only and is NOT a salvage target.

---

## Cycle 1 — BASELINE + highest-value regions

### 1A. The DUAL-BRAIN baseline (the most up-to-date PRUNING of the architecture)

**The dual-brain docs are the owner's freshest consolidation** (dated 2026-06-20, the newest files in
`docs/fusion/`), so they are the BASELINE of what was already pruned/kept before this sweep. Located **[V]**:

- `docs/fusion/ARCHITECTURE_READOUT_2026_06_20.md` — the consolidated dual-brain architecture readout (the
  spine diagram + per-segment honest-tier tables). **This is the baseline document.**
- `docs/fusion/RESEARCH_LOOP_LEDGER_2026_06_20.md` + `docs/fusion/RESEARCH_INTENT_AND_QUERY_LOG_2026_06_20.md`
  — the 22-pass research ledger + owner-query log behind the readout (referenced; not yet fully read — cycle 2).
- `docs/fusion/SESSION_CHECKPOINT_2026_06_20.md` — the resume anchor (referenced).
- Ledger entry `docs/OWNER_REQUESTS_LEDGER_2026_06_18.md:3921-3942` — the coordination directive: dual-brain
  is the OWNER's Cursor domain, the build-loop must NEVER touch the dual-brain files (`research/*.rs`
  mamba3/attention_sinks/interrupt_*/engram, `signal_bus.rs`, `answer_packet.rs`, `epistemos-research/*`,
  `active_assembly/*`, anything M0/M1/bus).

**What the dual-brain baseline says it is [V] (`ARCHITECTURE_READOUT` §0/§1-§3):**
the spine framing is *"Epistemos is a **dual-brain** system — the **model** (brain 1: an SSM-spine generator)
emits signals, the **app** (brain 2: typed authority + deliberation) decides and signals back, and **Rust is
the fast bus** between them that makes interrupting and co-working cheap."*

- **BRAIN 1 = the MODEL (generation/spine)** [V `§1`]: Mamba-3 SSM spine, attention-sinks default lane,
  interrupt gate `u_t`, ternary/quant lane (Bauer-Fike WBO-6 safety), KV residency (KIVI 2-bit), Engram
  lookup plane, KV-Direct (UMA). **Honest status: all T0/T1 research substrate; NO end-to-end model is
  shipped.**
- **RUST BUS = signal_bus.rs** [V `§2`]: SPSC downlink/uplink rings, M0 gate (`F-Interrupt-Moves-Loss`),
  M1 gates (InterruptInvariant + Bauer-Fike), D1-COMMS contract. **Status: T0 spec, not built.**
- **BRAIN 2 = the APP (authority/deliberation)** [V `§3`]: RuntimeRouter (authority/no-hidden-authority),
  active_assembly (nervous system), Model Cockpit, W-51 shadow recall, Cognitive DAG/verification,
  Never-Retrain/continual-learning, InstantRecall (shipped), DualBrainRouter (shipped, a model↔model axis).

**CRITICAL CLASSIFICATION OF THE BASELINE (the load-bearing cycle-1 finding):**
The dual-brain doc predates the owner's 2026-06-22 "70B/new-model STAYS OUT, PERIOD" correction. Re-reading
the baseline through that lens splits it cleanly:

- **BRAIN 1 + the RUST BUS + M0/M1 + ternary-model-runtime = 70B-TIED / new-model-EXCLUDED.** [I, grounded
  in addendum §"70B STAYS OUT" + ledger `:3929-3933` scope boundary] Mamba-3 spine, signal_bus, interrupt
  gate, M0 `falsify_interrupt_moves_loss`, ternary kernels, KIVI KV, Engram, attention-sinks — these ARE
  the from-scratch new-model brain-1. They are the owner's Cursor domain and are EXCLUDED from this
  convergence. **Do not salvage. Do not attach to System G.** (The readout's own §5 build-order M0→M1→B3
  Mamba-3 kernel confirms this is the new-model track.)
- **BRAIN 2 (the APP/authority faculty) OVERLAPS the live substrate and IS the salvage zone.** [V] Its named
  organs — RuntimeRouter, Cognitive DAG, provenance ledger, Eidos/W-51 recall, InstantRecall, active_assembly
  (as a brain-2 *governance/router* concept, not the model nervous-system), DualBrainRouter — map 1:1 onto
  the ARCHITECTURE_UNIFICATION_SYSTEMG verdict's "FACULTY 2 = KNOWLEDGE/MEMORY" + "FACULTY 1 = COORDINATION."
  These are exactly THE_BIG_IDEA's "one brain, two faculties, one substrate."

**Baseline verdict:** the dual-brain doc is **half-superseded-into-today's-architecture (brain 2 = the
substrate + the unification verdict) and half-EXCLUDED (brain 1 = the new model).** The owner's pruning
already separated generation (model) from authority (app); the 2026-06-22 exclusion finishes the cut by
removing the entire generation/model half. **What remains as the baseline-of-record for THIS sweep is
brain-2.** That is already captured by `ARCHITECTURE_UNIFICATION_SYSTEMG_2026_06_22.md` +
`THE_BIG_IDEA_GRAND_CONVERGENCE_2026_06_22.md` — so the dual-brain baseline is **largely already absorbed**
into the current direction, with the model half excluded. No NEW salvage target emerges from brain-1.

---

### 1B. The `docs/fusion/` theme map (primary local-research corpus)

`docs/fusion/` top-level holds ~136 IP docs (the full tree is 1,476 files incl. subdirs research/deliberation/
oversight/fleet/salvage — those are cycle-2+). A recurring **JUNE1-PATTERNBOOST-LOCK** banner on older docs
marks them LEGACY and redirects active work to four June-1 anchors. Major themes (all paths [V] verified to
exist; classifications [I] from doc headers/state-tags + cross-ref to live code):

| # | Theme | Representative docs (cited) | What the IP is |
|---|-------|----------------------------|----------------|
| T1 | **INDEX / CANON GOVERNANCE** | `MASTER_RESEARCH_INDEX_2026_05_02.md` (474KB, `state:canon`, concept→source→code-anchor map, appended through Pass 233 / 2026-06-09); `ALL_DOCS_INDEX_2026_05_02.md`; `ARCHITECTURE_TIER_PROMOTION_CANON_2026_06_06.md` (`state:canon`, defines "green"=T4+); `CANONICAL_SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md`; the `CANONICAL_*` audit set | The map + the rules: concept→source lookup, path lookup, the T0→T5 promotion ladder, decision-rights register. **LIVE/authoritative** (cited by CLAUDE.md). |
| T2 | **COGNITIVE / brain doctrines** | `COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` (canon, "one kernel one binary"); `COGNITIVE_DAG_DOCTRINE_2026_05_03.md` (canon, typed content-addressed Merkle DAG); `COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` (schema-first GenUI, PARTIAL); `COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` (no-LLM-first); `COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` (semantic-gravity vs policy-authority) | How agent cognition collapses into one schema/kernel/DAG. **DAG is LIVE in code** (`agent_core/src/cognitive_dag/` — node/edge/storage/merkle/resonance/macaroons/redb_store [V]); GenUI/variant-ladder/weight-class PARTIAL. |
| T3 | **EIDOS / recall / neural-substrate** | `ADDRESSABLE_NEURAL_SUBSTRATE_CANON_2026_05_24.md` (`canon-target`); `EIDOS_NEURAL_IMPORTANCE_BRIDGE_2026_05_31.md` (`candidate-canon`); `COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`; `CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01.md`; June-1 quartet (`RESIDENCY_PATTERNBOOST_DISCOVERY`, `SEMANTIC_WORKING_SET_COMPILER`, `VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER`) | Two layers: (a) **Eidos closed-citation recall** = LIVE-but-fragmented IP (`agent_core/src/eidos/` exists [V]); (b) the **model-state residency endgame** (page model internals into UMA) = theoretical AND mostly **70B-TIED** (it's about fitting/lifting a large model's working set). |
| T4 | **Helios / V6 lineage** | `EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md`; `EPISTEMOS_V6_2_CANON_INTAKE_2026_05_07.md`; `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`; `FIVE_LAWS_AND_PHASE_I_2026_05_04.md` | Version-history spine. **LEGACY** — the master index explicitly notes "Helios as lineage, not a spine step." Preserved as provenance; superseded for active work. |
| T5 | **EML / IR / lattice math** | `PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md`; `EML_INTEGRATION_DOCTRINE_2026_05_17.md`; `CROSS_IR_COMPOSITION_EXAMPLES_2026_05_17.md`; `CROSS_IR_LATTICE_STATUS_2026_05_17.md` (LIVE HEAD tracker) | Typed primitive-IR / cross-IR composition math beneath the runtime. **PARTIALLY LIVE** — `agent_core/src/research/eml/` + `eml_ir/`, `info_ir/`, `geometry_ir/`, `operator_ir/`, `tropical_ir/` all exist [V] under `--features research`. These are app-side VERIFICATION primitives, NOT model spine. |
| T6 | **Model / runtime / compression** | `TURBOVEC_QAT_RUNTIME_AGNOSTIC_INTAKE_2026_06_06.md` (`canon_candidate`, cited by CLAUDE.md); `MLX_QAT_TURBOVEC_LOCAL_SUBSTRATE_RESEARCH_2026_06_06.md`; `FRONTIER_LOCAL_REASONING_16GB_ARCHITECTURE_2026_05_31.md`; `LARGE_MODEL_BREAKTHROUGH_RESEARCH_LOOP_2026_06_07.md`; `DEEP_RESEARCH_BREAKTHROUGH_SYNTHESIS_2026_06_06.md` | TurboVec (compressed retrieval for Eidos/AppColdStore) + TurboQuant + Gemma-4-QAT + runtime-plural lanes. **SPLIT:** TurboVec-as-Eidos-retrieval-compression = potentially salvage-relevant; the large-model/frontier-16GB/70B-cocktail parts = **70B-TIED, EXCLUDED.** |
| T7 | **AetherLink / OAS / formal-math / Lean** | `AETHERLINK_OAS_CANON_INTAKE_2026_05_30.md` (`candidate_intake`); `AETHERLINK_ERDOS_PARAMETER_GOLF_INTAKE_2026_05_30.md`; `FORMAL_MATH_COMPANY_AND_LEAN_INTAKE_2026_06_01.md`; `MATH_AND_PORTABLE_NOTE_SYSTEMS_INTAKE_2026_06_01.md` | External research kits (proof-carrying coordinate-state runtime; Erdos lift/project/witness; Lean formal-math). **TOO-THEORETICAL / DROP** for now (antigravity/propulsion claims explicitly DROP per the doc itself); the lift/project/witness *discipline* is already absorbed by the tier-promotion + falsifier method. |
| T8 | **UAS / ACS substrate coherence** | `UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` (`state:canonical`, LOCKED, "fix CODE to match this doc"); `UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md`; `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` | The single no-loss register unifying every Unified-Address-Space / Anchored-Cognitive-Substrate surface. **LIVE-binding doctrine** (`agent_core/src/research/acs/` + `uas/` exist [V]); the UAS-ACS-admission field is referenced as a substrate component in THE_BIG_IDEA. |
| T9 | **CODEX_* / KIMI_* / WORKTREE_* process** | `CODEX_AGENT_FLEET_PROMPT_2026_05_02.md`; the `CODEX_*_HANDOFF_*` set; `KIMI_*`; `WORKTREE_*` salvage docs | Agent-fleet dispatch + worktree salvage scaffolding. **NOT IP — DROP** (historical process; skip unless provenance needed). |
| T10 | **Standalone feature doctrines** | `PROVENANCE_CONSOLE_DOCTRINE_2026_05_04.md`; `BIOMETRIC_LOCK_DOCTRINE_2026_05_17.md`; `LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md`; `LOCAL_AGENT_EXCELLENCE_DOCTRINE_2026_05_17.md`; `VAULT_CONTEXT_CONTRACT_2026_05_17.md` | Narrow single-feature IP. **MIXED** — several already shipped (ProvenanceConsole read-half [V `ARCHITECTURE_READOUT §3`]); vault-context-contract is live-relevant; assess per-doc in cycle 2. |

**Theme-map headline [I]:** the fusion corpus splits into (a) a LIVE/canon governance + brain-2 spine (T1,
T2, T5-partial, T8) that is already the substrate, (b) a large THEORETICAL/EXCLUDED model-state-residency +
large-model cluster (most of T3, T6, T7) that is 70B-TIED or research-only, and (c) PROCESS scaffolding (T9)
that is not IP. **The salvage opportunity is small and concentrated** because the brain-2 organs are already
the targets of the existing UNIFICATION verdict.

---

### 1C. Living-index + lattice-explainer chronicle assessment

**These are CHRONICLE / aspirational-doctrine documents, NOT live IP.** Fully assessed by the prior
code-grounded research doc `docs/research/SS-LI_LIVING_INDEX_LATTICE_2026_06_19.md` [V], which this sweep
confirms and adopts:

- **`docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`** (8,587 lines [V]) = a large **Markdown chronicle doc**
  tracking the build over time. It is a doc artifact, **NOT a `LivingIndex` type / engine** — there is no
  `LivingIndex` code (verified by SS-LI). It is the "living index" the owner names as a chronicle.
- **`artifacts/lattice-coordinate-explainer/index.html`** (707KB) = a standalone HTML visualization of the
  system's own coordinate/ambition map — **doc artifact only, zero Swift refs, NOT in-app** [V via SS-LI].
- **False friends (do not conflate) [V via SS-LI]:** `LatticeWBO` (`Epistemos/LatticeWBO/LatticeWBOWiring.swift`
  + `agent_core/src/oplog.rs:522`) is an oplog write-budget accountant, NOT a UI lattice; "EML / episodic-memory-
  lattice" is the math primitive `eml(x,y)=exp(x)−ln(y)`, not a memory lattice. `sherry_lattice/` in
  `agent_core/src/research/` exists [V] but is research-tier.

**What the lattice/living-index IP actually IS vs is meant to be [V via SS-LI]:**
- **The SUBSTRATE for a "living index" already exists + is LIVE:** the Halo Shadow index (tantivy BM25 +
  usearch HNSW + RRF k=60, incrementally updating on a 500ms debounce + vault file-watcher) + the Cognitive
  DAG (resonance propagation, library-complete but NOT yet live-driven) + `CognitiveDagVisualizerPanel.swift`
  (the embryonic status surface). **This is SUPERSEDED-into-substrate.**
- **What does NOT exist (the genuine open frontier):** a unified `LivingIndex` orchestrator, a concept-
  lattice/FCA engine (objects×attributes → concept lattice — NO impl, only N3 doctrine), a navigable
  lattice-explorer UI. **This is TOO-THEORETICAL** — the owner himself scoped it as the "absolutely last,
  indefinite" non-terminating item.

**Living-index/lattice verdict:** the chronicle docs are **provenance/build-history, not salvage IP.** The
"living" capability is already in the substrate (shadow index + DAG). The only beneficial, finishable,
additive-safe salvage is the **bounded read-only "Living Index status" panel** (surface what's already living
— see PLAN ADDITION GUS-1). The lattice/FCA engine + explorer UI is TOO-THEORETICAL/DROP for the convergence
(it does not attach to System G; it is a research frontier the owner explicitly sequenced last).

---

## Cycle-1 CLASSIFICATION TABLE

Classes: **USEFUL+RELEVANT** (unify/harden/infuse into System G/brain/substrate) · **SUPERSEDED** (already
absorbed into today's substrate — cited where) · **TOO-THEORETICAL/DROP** (research-only) · **70B-TIED**
(EXCLUDED). "Additive-safe?" = won't break the hardened Osaurus(act)/OpenCode(work) clones.

| Component / theme | Path(s) | Class | 70B? | Salvage attach-point (if USEFUL) | Cited |
|---|---|---|---|---|---|
| Dual-brain BRAIN-2 faculty (authority/deliberation) | `docs/fusion/ARCHITECTURE_READOUT_2026_06_20.md §3` | SUPERSEDED → it IS the unification verdict's Faculty-2 | No | Already = `ARCHITECTURE_UNIFICATION_SYSTEMG_2026_06_22.md` brain attach point | [V] |
| Dual-brain BRAIN-1 (Mamba-3 spine, attention-sinks, interrupt gate, Engram, KIVI-KV) | `agent_core/src/research/{mamba3,attention_sinks,interrupt_calibration,scan_ir,ternary}.rs`; readout §1 | 70B-TIED (EXCLUDED) | **YES** | — (do not attach) | [V] |
| Rust BUS / signal_bus / M0 / M1 | `signal_bus.rs` (spec), `m0_interrupt_harness.rs`, readout §2 | 70B-TIED (EXCLUDED) | **YES** | — (owner Cursor domain, never touch per ledger :3929) | [V] |
| Cognitive DAG doctrine + code | `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md`; `agent_core/src/cognitive_dag/` | USEFUL+RELEVANT (live, observe-only from Swift) | No | System G brain attach (UNIFY-4): drive DAG writes from the run, flip resonance to authority at Phase 8.H | [V] |
| Cognitive Kernel "one kernel/binary" | `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` | SUPERSEDED → = the "one orchestrator/one chokepoint" verdict | No | Already in UNIFICATION verdict §4 (System G = single orchestrator) | [V] |
| Eidos closed-citation recall | `docs/fusion/EIDOS_NEURAL_IMPORTANCE_BRIDGE_2026_05_31.md`; `agent_core/src/eidos/` | USEFUL+RELEVANT (the "real prize" — fragmented) | No | UNIFY-4/UNIFY-5: route `eidos.query` THROUGH the real `eidos/` module; wire retriever into System G decision path | [V] |
| Eidos→neural-importance routing (model-state) | `EIDOS_NEURAL_IMPORTANCE_BRIDGE`; `NEURAL_IMPORTANCE_ROUTING_ATLAS_2026_05_31.md` | 70B-TIED (model-internal weight routing) | **YES** | — | [V] |
| Addressable Neural Substrate / residency endgame | `ADDRESSABLE_NEURAL_SUBSTRATE_CANON_2026_05_24.md`; `COLDSTREAM_RESIDENCY_TRANSPORT`; `CONSTRUCTIVE_RESIDENCY_PARADIGM`; June-1 quartet | 70B-TIED (EXCLUDED — "fit/lift a large model's working set") | **YES** | — | [V] |
| EML / cross-IR lattice math primitives | `docs/fusion/{EML_INTEGRATION,PRIMITIVE_IR_STACK,CROSS_IR_*}_DOCTRINE_2026_05_17.md`; `agent_core/src/research/{eml,eml_ir,info_ir,geometry_ir,operator_ir,tropical_ir}/` | USEFUL+RELEVANT (app-side VERIFICATION primitives, live under `--features research`) | No (verification, not spine) | Brain attach as honesty/verification layer (Belnap abstain, EML oracle gating AnswerPacket per readout §6) — additive, gated | [V] |
| UAS/ACS canonical architecture | `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` (LOCKED); `agent_core/src/research/{acs,uas}/` | USEFUL+RELEVANT (substrate doctrine, code-must-match) | No | Substrate component (THE_BIG_IDEA names uas/ACS-admission as substrate); harden, don't rebuild | [V] |
| Halo/Shadow living index + RRF | `Engine/{ShadowSearchService,ShadowIndexingService,ShadowVaultBootstrapper}.swift`; `epistemos-shadow/`; `Sync/RRFFusionQuery.swift` | SUPERSEDED (= the live "living index" substrate) | No | Already live; surface via GUS-1 status panel | [V via SS-LI] |
| Provenance ledger | `agent_core/src/provenance/`; `PROVENANCE_CONSOLE_DOCTRINE_2026_05_04.md` | USEFUL+RELEVANT (CLI-live/observe-only) | No | UNIFY-4: drive `commit_*`/`retract_*` from the live run | [V] |
| TurboVec compressed retrieval (Eidos/AppColdStore) | `docs/fusion/TURBOVEC_QAT_RUNTIME_AGNOSTIC_INTAKE_2026_06_06.md` | USEFUL+RELEVANT (retrieval compression, NOT model runtime) | No (per CLAUDE.md: "Eidos/AppColdStore compressed retrieval, not durable truth or route authority") | Eidos retrieval backend optimization; Pro-gated/research per CLAUDE.md until witnesses land | [V] |
| TurboQuant / Gemma-4-QAT model runtime / frontier-16GB / 70B-cocktail | `MLX_QAT_TURBOVEC_*`; `FRONTIER_LOCAL_REASONING_16GB_*`; `LARGE_MODEL_BREAKTHROUGH_*` | 70B-TIED (EXCLUDED) | **YES** | — | [V] |
| Helios / V6 lineage canon | `docs/fusion/{EPISTENOS_HELIOS_V6_1,EPISTEMOS_V6_2_CANON,EPISTEMOS_FINAL_DOCTRINE,FIVE_LAWS}_*.md` | SUPERSEDED (lineage, not a spine step — per master index §0F) | Partial (V6 carried the new-model thesis) | — (provenance only) | [V] |
| AetherLink / OAS / Erdos / Lean / formal-math intake | `docs/fusion/{AETHERLINK_OAS,AETHERLINK_ERDOS,FORMAL_MATH_COMPANY_AND_LEAN}_*.md` | TOO-THEORETICAL / DROP (lift/project/witness discipline already absorbed) | No | — | [V] |
| Living-index chronicle doc | `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md` | TOO-THEORETICAL/DROP as IP (it is a build chronicle) | No | — (provenance/history) | [V] |
| Lattice-coordinate-explainer HTML | `artifacts/lattice-coordinate-explainer/index.html` | TOO-THEORETICAL/DROP (doc artifact, not in-app) | No | — | [V via SS-LI] |
| Concept-lattice / FCA engine + explorer UI | aspirational only (`EXPLORATION_SPECTRUM_N3.md`) | TOO-THEORETICAL/DROP (no impl; owner-scoped "last/indefinite") | No | — | [V via SS-LI] |
| CODEX_* / KIMI_* / WORKTREE_* process docs | `docs/fusion/CODEX_*`, `KIMI_*`, `WORKTREE_*` | DROP (process scaffolding, not IP) | No | — | [V] |
| Cognitive GenUI / Variant-Ladder / Weight-Class | `docs/fusion/COGNITIVE_{GENUI,VARIANT_LADDER,WEIGHT_CLASS}_DOCTRINE_*.md` | USEFUL+RELEVANT (PARTIAL — assess deeper cycle 2) | No | Candidate brain-2 routing/UI infusion; tentative | [V] |

---

## REGIONS STILL TO SWEEP IN LATER CYCLES (so cycle 2 knows what's left)

1. **`docs/fusion/` deep read** — only headers/index were read this cycle. Full-read the LIVE canon set:
   `MASTER_RESEARCH_INDEX_2026_05_02.md` (474KB, the concept→code map — likely surfaces more salvage anchors),
   the `RESEARCH_LOOP_LEDGER_2026_06_20.md` 22 passes (the dual-brain detail), `UNIFIED_ACTIVE_SUBSTRATE_CANON`
   + `UAS_ACS_CANONICAL_ARCHITECTURE` in full, the June-1 residency quartet (confirm 70B-TIED vs any app-side
   spillover), the T10 standalone feature doctrines (per-doc shipped-vs-not).
2. **`docs/fusion/` SUBDIRECTORIES (~1,340 files, untouched):** `research/`, `deliberation/`, `oversight/`
   (PREFLIGHT_* set), `agent-build-scaffolding/`, `simulation/`, `salvage/` (`from-lane-a/EPISTEMOS-NORTH-STAR.md`
   etc.), `jordan's research/`, `pasted/`, `fleet/`. Likely mostly process/scaffolding (DROP) but the
   `salvage/` + `jordan's research/` + `pasted/` dirs may hold un-promoted IP.
3. **The `agent_core/src/research/` tree (~40 modules)** — confirm which are 70B-TIED (mamba3/ternary/scan_ir/
   attention_sinks/interrupt — EXCLUDED) vs app-side verification primitives that could attach to the brain
   (eml*, info_ir, geometry_ir, operator_ir, tropical_ir, belnap, substrate_independence, hybrid_memory,
   confidence_floors, biometric_gate, run_ledger). Cross-check each against the EXCLUDED line.
4. **`epistemos-research/` crate** (named in the dual-brain scope boundary) — verify it is entirely the
   new-model/brain-1 domain (EXCLUDED) and surface nothing.
5. **Helios-era archaeology proper** — the owner folded `HELIOS_ERA_IP_ARCHAEOLOGY` into this sweep; locate
   that doc + `docs/_consolidated/` + `HELIOS_V5_DOC_6_THEOREM_CANON.md` (E1-E7/H1-H17/PCF-1-10 theorem
   catalog) and classify the theorems (research-only vs any app-side primitive).
6. **`docs/research/SS-*` slices not yet cross-referenced** to the substrate (58 slices per
   RESEARCH_FINALIZATION_INDEX) — confirm none hide additional brain/substrate IP.
7. **Convergence check** — re-run the classification once more; declare convergence when a cycle finds nothing
   new (no new USEFUL+RELEVANT salvage item, no new EXCLUDED surface).

---

## PLAN ADDITIONS (paste-ready) — USEFUL+RELEVANT salvage from Cycle 1

These are sequenced AFTER the P0 chat/model-selection + act/work priorities, all additive-safe (won't touch
the hardened Osaurus/OpenCode clones), all behind existing flags/gates. Most overlap the existing UNIFY-*
additions in `ARCHITECTURE_UNIFICATION_SYSTEMG_2026_06_22.md §5` — these EXTEND, not duplicate.

```
[GUS-1] LIVING-INDEX STATUS PANEL (bounded, read-only, additive-safe). Extend
  CognitiveDagVisualizerPanel.swift into a "Living Index status" surface showing
  (a) shadow-index liveness (last flush, pending queue, file-watcher active — data
  already in ShadowIndexingService + VaultSyncService.swift:3515-3520) and (b) DAG
  node/edge/merkle/resonance counts already mirrored. Surfaces what is ALREADY living
  as ONE panel BEFORE any lattice engine. Finite, T4-promotable, no new engine, no
  clone surface touched. (Supersedes the indefinite lattice loop with a finite first
  step.) Cross-ref SS-LI_LIVING_INDEX_LATTICE_2026_06_19.md.

[GUS-2] EML / verification-primitive INFUSION into the brain attach point (additive,
  --features research gated). Wire the app-side EML oracle (eml(x,y)=exp(x)−ln(y) ULP
  floor) + Belnap FDE 4-valued claim truth (Neither→abstain) as the honesty/abstention
  layer on the AnswerPacket the System G run emits — the same brain attach point as
  UNIFY-4. These already exist live (agent_core/src/research/{eml,belnap,info_ir}/);
  the salvage is WIRING them as the answer-gate scalar, not building them. Pairs with
  resurrecting confidence_floor (UNIFY-5b). NEVER on the model spine (that's EXCLUDED).

[GUS-3] TurboVec as the Eidos retrieval-compression backend (Pro-gated/research per
  CLAUDE.md). When UNIFY-5a routes eidos.query through the real eidos/ module, allow
  TurboVec compressed retrieval as a backend for Eidos/AppColdStore (NOT durable truth,
  NOT route authority — per CLAUDE.md TURBOVEC canon). Gated behind owner approval +
  no-hidden-fallback proof + RunEventLog + AnswerPacket + rollback + harness witnesses.
  Additive (a retrieval-path option), never the new-model runtime.

[GUS-4] UAS/ACS substrate HARDENING (code-must-match-doc, not rebuild). Treat
  UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md (LOCKED) as authority for the
  uas/ACS-admission substrate component named in THE_BIG_IDEA; audit agent_core/src/
  research/{uas,acs}/ for drift and fix CODE to match the doc. Additive/repair, behind
  the existing research gate. (Confirms the substrate, surfaces nothing new to the user.)

[GUS-5] DOC FIX — record in the plan that the DUAL-BRAIN baseline's BRAIN-1 half
  (Mamba-3 spine / signal_bus / M0 / M1 / ternary model runtime / Engram / residency
  endgame / Addressable-Neural-Substrate / large-model-frontier) is EXCLUDED per the
  2026-06-22 "70B STAYS OUT, PERIOD" correction, and BRAIN-2 (authority/deliberation)
  is ALREADY the unification verdict's Faculty-2. Prevents a future cycle from
  re-salvaging the excluded model half. Zero behavior change.
```

**Note on overlap:** GUS-1..5 are NEW (living-index panel, EML infusion, TurboVec backend, UAS/ACS harden,
exclusion doc-fix). The brain-unification itself (eidos.query through the real module, ledger driven by the
run, confidence_floor resurrection) is already captured as UNIFY-4/UNIFY-5 in
`ARCHITECTURE_UNIFICATION_SYSTEMG_2026_06_22.md §5` — cycle 1 confirms those are the right targets and adds
no contradiction.

---

*Cycle 1 grounded against files read 2026-06-22: `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md`,
`docs/research/{ARCHITECTURE_UNIFICATION_SYSTEMG,THE_BIG_IDEA_GRAND_CONVERGENCE,SS-LI_LIVING_INDEX_LATTICE,
RESEARCH_FINALIZATION_INDEX}_2026_06_*.md`, `docs/fusion/ARCHITECTURE_READOUT_2026_06_20.md`,
`docs/OWNER_REQUESTS_LEDGER_2026_06_18.md:3918-3978`, plus `docs/fusion/` top-level header survey + the live
code module trees `agent_core/src/{research/,cognitive_dag/,eidos/,provenance/}`. Next: cycle 2 sweeps the
fusion deep-read + subdirectories + research/ module classification per the "regions still to sweep" list.*
