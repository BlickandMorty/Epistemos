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

---

## Cycle 2 — DEEP MODULE + SUBDIRECTORY + THEOREM + EXTERNAL-CORPUS SWEEP

Same exclusion + anti-hallucination rules as Cycle 1. **[V]** = file read this cycle, **[I]** = inferred from
verified facts. This cycle reads the actual code (`agent_core/src/research/` ~40 modules + `epistemos-research/`
crate), the fusion SUBDIRECTORIES (~1,340 files), the Helios theorem catalog cross-checked against its code
encodings, and the EXTERNAL `~/Downloads` Helios-lineage corpus (read-only, owner-granted).

### 2A. `agent_core/src/research/` per-module classification (Region 2)

**Gating [V]:** the entire `research/` subtree is behind `feature = "research"` — declared `pub mod research;`
at `agent_core/src/lib.rs:69` under the research cfg, with `research = []` an empty opt-in feature at
`agent_core/Cargo.toml:25`; bins/examples set `required-features = ["research"]`. No per-module cfg needed;
nothing here compiles into the MAS/Pro hot path unless explicitly opted in. **So everything below is research-
tier by construction** — "USEFUL" means a salvage *candidate* to wire forward, not a live app invariant.

Classes: **EXCLUDED** (70B/new-model spine, off-limits) · **USEFUL** (app-side verification/authority/substrate
salvage) · **THEORETICAL** (research-only math, no near-term app attach) · **SUPERSEDED** (shim/duplicate).

| Module | What it is | Class | 70B? | Attach-point (if USEFUL) | Cited |
|---|---|---|---|---|---|
| `eml/` + `eml_integration/` + `fulp_oracle/` | `eml(x,y)=exp−ln` primitive + AnswerPacket-freeze gate + fp16 ULP oracle; `fulp_oracle` is FFI-wired to Swift `FUlpHealthRow` | **USEFUL** (strongest) | No | AnswerPacket arithmetic-floor freeze gate (= GUS-2); already partly live via Swift health row | [V] `research/{eml,eml_integration,fulp_oracle}/mod.rs` |
| `confidence_floors.rs` | T1/T2/T3 floor ladder (0.85/0.75/0.70) + LadderLog + escalate-on-empty | **USEFUL** | No | AnswerPacket confidence gating + escalate-to-human (= UNIFY-5b confidence_floor resurrection) | [V] |
| `belnap.rs` | 4-valued FDE bilattice (T/F/Both/Neither) + 5 directional ops | **USEFUL** | No | Claim-graph truth composition consumed by `resonance`/`cognitive_dag` (= GUS-2 Belnap abstain) | [V] |
| `info_ir/` | Exponential-family inference + Bregman/KL projection | **USEFUL** | No | `KlProjection` → AnswerPacket.confidence labeling | [V] |
| `run_ledger.rs` | Per-token attestation hash-chain (prev-hash linked) | **USEFUL** | No | Token-level generation attestation; complements claim-level `provenance` ledger | [V] |
| `biometric_gate.rs` | Two-tier (mount + per-op) biometric write gate, two kill switches | **USEFUL** | No | High-stakes write-authority admission (Touch-ID-gated edit/commit) | [V] |
| `substrate_independence.rs` | Cross-backend (CPU/GPU/ANE/Mock) divergence checker + per-pair table | **USEFUL** | No | "Same-answer-across-substrate" falsifier / numeric-tolerance audit harness | [V] |
| `hybrid_memory.rs` + `hyperdynamic_schemas/` | MD+JSON memory parser (soul/skill/episode/semantic) + self-repairing meta-schemas | **USEFUL** | No | Memory-file persistence/validation + schema-repair on validation failure | [V] |
| `a2ui/` | 24-component render-schema catalog + per-component validators | **USEFUL** | No | Validate answer-render envelopes before display (Swift A2UI dispatcher) | [V] |
| `paper_registry/` + `ane_direct/` | arXiv citation registry across J1-J8; ANE telemetry types (IOKit/SMC) | **USEFUL** (UI) | No | Control-room "papers implemented?" / "ANE busy?" telemetry surfaces | [V] |
| `nightbrain_tasks.rs` | 6 NightBrain task bodies | **USEFUL (mixed)** | mostly No | 5/6 are app-maintenance (dedupe/distill/session-graph/skill-evolution); only `ssm_state_pruning` is spine. Attach `agent_core/src/nightbrain/live.rs` | [V] |
| `compute_steering.rs` + `page_gather/` + `brain_routing.rs` + `attention_sinks.rs` | per-call budget/early-stop; shadow-first paging; Sinkhorn→Birkhoff routing; attention-sink detection | **USEFUL/THEORETICAL (borderline)** | borderline | Policy *types* salvageable only if decoupled from the excluded runtime; their real consumers are model-internal | [V] |
| `acs/` + `active_assembly/` + `action_to_eml.rs` + `geometry_ir/` + `operator_ir/` + `para_lens.rs` + `tropical.rs` | Kuramoto/Notch-Delta VSM governance; packet-DAG selector; Euler-Lagrange demo; Clifford rotor; DeepONet/FNO; categorical backprop; tropical max-plus | **THEORETICAL** | No | — (primitive-IR / formalism; no app decision path) | [V] |
| `cognition_observatory/` | KV-implant / Glass-Pipe / weight-surgery / SAE hallucination probe | **EXCLUDED (mostly)** | **YES** | only the read-only SAE AUC-0.90 hallucination probe is salvageable; intervention probes mutate inference = spine | [V] |
| `mamba3.rs`, `rwkv7.rs`, `scan_ir/`, `ternary/`, `sherry_lattice/`, `koopman.rs`, `test_time_regression.rs`, `interrupt_calibration.rs`, `m0_interrupt_harness.rs`, `nano_training_recipe.rs`, `continual_learning/` | SSM/RWKV spine refs, scan/SSM-IR, BitNet ternary kernels, 1.25-bit lattice VQ, Koopman/Bauer-Fike quant bound, model-arch unification, M0-interrupt calibration+harness, MOHAWK distillation recipe, EWC/SEAL never-retrain weight updates | **EXCLUDED** | **YES** | — (these ARE brain-1: SSM/quant/training spine, owner Cursor domain) | [V] |
| `eml_ir/` ; `tropical_ir/` | research-island EML-IR sibling (zero external callers, KEEP-BOTH per `docs/audits/T12_EML_IR_VS_FULP_ORACLE_DECISION_2026_05_23.md`); `tropical_ir` is a `pub use super::tropical::*` shim | **SUPERSEDED/shim** | No | — | [V] |

**2A headline [I]:** ~13 modules are squarely EXCLUDED (the SSM/RWKV/ternary/scan/Koopman/interrupt/training
cluster = brain-1). ~16 are USEFUL app-side salvage — but they are **the SAME organs cycle 1 already named**
(EML/fulp/Belnap/confidence/provenance/biometric), now confirmed AT THE CODE LEVEL with concrete attach-points.
The genuinely-new code-level findings are the *secondary* verification primitives: **`substrate_independence`,
`run_ledger` (token attestation), `info_ir` KL labeling, `hyperdynamic_schemas`** — additive-safe honesty
layers, not new engines. No new EXCLUDED surface beyond the known spine cluster.

### 2B. `epistemos-research/` crate confirmation (Region 3)

**[V]** `epistemos-research/src/lib.rs:1-3` self-declares: *"HELIOS V5 Lane 3 (RESEARCH_FRONTIER) workspace
member."* Its own feature gate is `research = []` (`epistemos-research/Cargo.toml [features]`), crate-type
`rlib`. It carries the E1-E7 theorem substrate (`theorems/`), the Goodfire VPD/PCF arm (`vpd/`), `acs`,
`shadow_memory` (explicitly *"NEVER inherits the quantum advantage"*), `cms_v2` (Constitutive Moral Substrate),
`ternary_kernel`, `theorem_status`, `donor_distillation`, `engram`, `interrupt_score`, `kv_direct_gate`,
`m2_max_kernels`, `five_planes`, the `v6_1*`/`v6_2` lineage, `self_evolving_l_se`, `lane4_falsifier`. **Confirmed:
this crate is the `--features research` Lane-3 preservation home.** It is a MIXED crate, not purely brain-1:
the `theorems/` + `vpd/` arm is app-side verification substrate (salvageable, see 2C); the `ternary_kernel` +
`donor_distillation` + `engram` + `kv_direct_gate` + `m2_max_kernels` + `five_planes` arm is brain-1/model-spine
(**EXCLUDED**). **The `--features research` doctrine is preserved exactly as Cycle 1 described — nothing here is
on the MAS hot path; nothing surfaces to the user without opt-in.** No NEW salvage emerges from the crate itself
beyond what 2C (theorems) covers.

### 2C. Helios theorem catalog E1-E7 / H1-H17 / PCF-1-10 (Region 4)

Cross-checked `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` against code in `epistemos-research/src/theorems/`,
`epistemos-research/src/vpd/`, `epistemos-vault/src/`, and `agent_core/src/scope_rex/`. "LIVE INVARIANT" =
executable Rust function + falsifier-shaped `#[test]` assertions.

| Family | LIVE INVARIANTS (code + falsifier, cited) | THEORETICAL (doc-only) | App-side vs EXCLUDED |
|---|---|---|---|
| **E1-E7** | **E3** (`e3_morph_field.rs` `e3_resident_within_budget()`), **E4** (`e4_wbo7.rs` pre/post-softmax checks), **E5** (`e5_duplex_fusion.rs` `e5_fused_error_bound()`), **E7** (`e7_kernel_identity.rs` `e7_holds_for_sample()` ULP) | E6 (type marker; canon itself says "Hardware falsifier: none"); E1/E2 partial (type substrate + bound test, empirical falsifier doc-only) | **App-side / model-agnostic** (Stone-Weierstrass, sheaf, memory-budget, softmax-bandwidth, ULP). E4/E7 attach to Swift Metal/resonance pipeline. NOT excluded. | [V] |
| **H1-H17** | **H1**(=E4), **H2** (`scope_rex/metal/softmax.rs` half_softmax ≤2-ULP drift), **H3** (`scope_rex/metal/asa_index.rs` merge-monotone + ULP-equality), **H17** (`scope_rex/retrieval/hopfield.rs` recall — gated OFF) ; **H7** partial (`scope_rex/residency.rs` route falsifiers live, full eviction-monotonicity doc-only) | H4,H5,H6,H8,H9,H11-H16 doc-only (future shaders/substrate); **H8** canon claims "4-of-9 OSPC mirrors" but `cognitive_dag/dispatch.rs` only mirrors ledger commits — the 9-arm MutationEnvelope is NOT there → effectively THEORETICAL (canon-vs-code DRIFT [I]) | H2/H3/H17 are **app-side, model-agnostic** (Metal numeric rewrites + associative recall — the only H-invariants that are agent_core hot-path-adjacent). **H10 = Lane-4 "never-product" (EXCLUDED-reserved).** | [V] |
| **PCF-1-10** | **PCF-6** (`epistemos-vault/.../envelope.rs` `validate()`), **PCF-9** (`.../distill/connectome.rs` `passes_acceptance()`) | PCF-1,2,3,4,7,8 partial (`vpd/` substrate types + tests, empirical falsifier doc-only); PCF-5,10 partial | **vpd/ arm (PCF-1,2,3,4,7,8) = app-side interpretability/verification, salvageable.** **vault/ arm (PCF-5,6,9,10) = model-runtime/surgery; PCF-9 produces a NEW MODEL FILE → EXCLUDED**; PCF-5/10 are runtime exec paths (EXCLUDED-adjacent). | [V] |

**2C tallies [V]:** 10 fully-live invariants (E3,E4,E5,E7,H1,H2,H3,H17,PCF-6,PCF-9); 11 partial-live; 13 doc-only-
theoretical; EXCLUDED = H10 + PCF-5/6/9/10 (vault model-runtime/surgery). **2C verdict:** the theorem catalog is
*mostly* substrate-math, NOT model spine — and **the live app-side invariants (E4/E7 ULP, H2/H3 Metal-numeric,
H17 recall, the `vpd/` interpretability arm) are exactly the verification/honesty discipline already named in
GUS-2/UNIFY-6.** They are SUPERSEDED-into-the-verification-layer, not new salvage. The one actionable NEW finding
is a **doc-fix:** H8's "4-of-9 OSPC mirrors live" canon claim is not backed by `dispatch.rs` (drift to record).

### 2D. fusion SUBDIRECTORIES (~1,340 files, Region 1-deep)

| Subdir | Verdict | Note (cited) |
|---|---|---|
| `salvage/from-vigorous-goldberg/` | **USEFUL+RELEVANT — net-new cluster** | A near-complete app-side `agent_core` IP tree (Quick-Capture Waves 0-5): deterministic, no-LLM-first, attaches to `agent_core` w/o model spine. Source of GUS-6..13 below. [V] |
| `salvage/from-lane-a/` | **MOSTLY PROCESS (DROP) + 1 keeper** | ~95 audits/handoffs/GO_NO_GO = DROP; the two `CLAUDE.md` are STALE pre-Hermes-purge (SUPERSEDED, do not resurface); `EPISTEMOS-NORTH-STAR.md` = historical doctrine (provenance only). [V] |
| `salvage/from-simulation/` | **MIXED → mostly SUPERSEDED** | `reference-code/*.rs` (compaction/prompt_caching/security/think) already shipped in `agent_core`; Hermes-UI Swift = cosmetic sim views. DROP unless building Simulation Mode UI. [V] |
| `salvage/{from-hermes-parity,from-codex-runtime-input-audit,from-stashes,from-agent-*}/` | **PROCESS (DROP)** | parity/diff/WIP-patch logs. Not IP. [V] |
| `research/` | **USEFUL+RELEVANT (net-new specs)** | net-new governance/substrate specs (see GUS-14..16); `FINAL_SYNTHESIS.md` = reconciling canon; `cms-doctrine/` + `user-authored/` lean model-spine/SCOPE-Rex (70B-TIED or superseded). [V] |
| `jordan's research/` (457) | **MIXED; mostly EXCLUDED** | `GPT Research/**` + `kimis deep research/epistenos/**` = full from-scratch SSM/Mamba/BitNet/ternary/KV-direct model builds = **70B-TIED EXCLUDED**; `helios v2-v6`/`ternary kernel`/`scope rex` = spine EXCLUDED; minority kimi docs are app-side governance (GUS-17); `research/math_*`/`meta_*` = THEORETICAL-DROP. [V sampled] |
| `pasted/` (2) | **70B-TIED (EXCLUDED)** | both files = Gemini "70B Local Cocktail" blueprint+eval (SSM spine, M-Limb interrupt, Engram LUTs, ternary, model-weight Residency Governor). Already fenced T0 NON-AUTHORITY. DROP. [V] |
| `deliberation/` (175) | **PROCESS (DROP)** | per-PR gate/approval records PR0-PR45. [V] |
| `oversight/` (115) | **PROCESS (DROP)** | `CODEX_KIMI_OVERSIGHT_ROUND_NNN` advisory verdict logs. [V] |
| `fleet/` (274) | **PROCESS (DROP)** | per-PR worktree/handoff fleet folders. [V] |
| `agent-build-scaffolding/` (2) | **PROCESS (DROP)** | build workcards/lane assignments. [V] |
| `simulation/` (8) | **USEFUL but already-known** | `DOCTRINE.md` v1.6 = canonical Simulation Mode spec (deterministic visual projection = the "felt moat"); self-declares LEGACY/bridged. Not net-new; keep as authority IF Sim-Mode UI is built. [V] |

### 2E. EXTERNAL `~/Downloads` Helios-lineage corpus (Region 5, read-only)

**Bottom line [V via repo grep]:** the Helios lineage (v3→v4→v5→v6.1→v6.2) is **already comprehensively
absorbed** into the repo — several source files are carried VERBATIM under `docs/fusion/` + `docs/fusion/jordan's
research/`, each with a 2026-05-07 intake doc + a 2026-06-01 PATTERNBOOST-LOCK legacy banner. Per-doc:

| External doc | Class | Note |
|---|---|---|
| `helios v4 updated.md`, `Helios third .md`, `helios v5*.md`, `helios v6.2.md` | **SUPERSEDED (verbatim in repo) + model-TIED** | v5 files present in repo `docs/fusion/`; v6.2 falsifiers are `.metal` spine kernels (EXCLUDED); theorem canon already in `HELIOS_V5_DOC_6_THEOREM_CANON.md` |
| `EPISTEMOS_GRAND_MASTER_v3.md` | **SUPERSEDED + model-TIED** | PRCDA/WBO/six-tier/UST-1.5/DAG/SCOPE-Rex/7-theorems all confirmed in-repo (resonance τ/π/λ/δ/ρ/κ/η kernels grep-VERIFIED) |
| `EPISTEMOS_FINAL_SEVEN_THEOREMS{,_v2_HARDENED}.md` | **SUPERSEDED** | = `HELIOS_V5_DOC_6_THEOREM_CANON.md`; kernel-pack parts are spine |
| `EPISTEMOS_V6_1_FINAL_SYNTHESIS_LOCK.md` | **SUPERSEDED (PDF in repo) + heavily model-TIED** | five-plane/interrupt-score/donor-distillation/Goodfire-VPD already intaken; most content is EXCLUDED spine |
| `deep-research-report (6)/(7).md`, `compass_artifact_*.md` | **SUPERSEDED / THEORETICAL-DROP / model-TIED** | preservation memos + V5-canon-lock duplicates + a model-spine build manifest |
| `Pasted markdown (1)-(4).md` | **INFERRED SUPERSEDED** | not opened (time budget); size/date cluster with the V5/V6 lock set — one remaining spot-check gap |

**NET-NEW from external corpus (1 real item):**
- **Four-gate tool-adoption discipline** — `~/Downloads/EPISTEMOS_HELIOS_v4_1_AMENDMENTS.md §A3.3` [V; grep-
  VERIFIED ABSENT in repo]. A formal rubric to admit any external tool into canon: **Substrate** (native Apple
  Silicon), **Containment** (no cloud/net for MAS), **Direction** (sovereign-local), **Discipline** (emits
  SCOPE-Rex TypedArtifact/MutationEnvelope/RunEventLog headers natively), scored 4/4=canon · 3/4=research ·
  2/4=reference · 1/4=reject. Pure app-side *process* IP, model-agnostic → not excluded. (A weak 2nd item — a
  public-vs-internal theorem taxonomy as UI copy over `VRMLabelView.swift` — is marginal/INFERRED, noted only.)

**3-dir characterization [V via ls/README]:**
- `Epistemos-cursor/` — a full working Epistemos checkout (Swift+`agent_core`+Lean+Metal+`docs/fusion/`); it
  already contains the Helios v5/v6.2 source verbatim + intakes. It is effectively the absorption *target*, not
  an external corpus to salvage *from*.
- `openclaw-main/` — third-party MIT "OpenClaw" personal-AI-assistant monorepo (pnpm/TS+Docker+Fly.io). Generic
  agent infra, unrelated to Helios; no Epistemos-specific app IP.
- `AETHERLINK_APPLICATION_KIT_FULL/` — a self-contained grant/application packet for "Project AetherLink"
  (proof-carrying coordinate kernels for edge autonomy). Spin-off pitch artifact; repo already has two AetherLink
  intake docs (Erdos-Parameter-Golf, OAS canon) → already triaged (cycle-1 T7, TOO-THEORETICAL/DROP).

### 2F. NEW salvage items (GUS-6+, additive-safe, EXCLUDING 70B)

All app-side, model-agnostic, behind existing flags/gates; sequenced after the P0 priorities. Sourced from
`docs/fusion/salvage/from-vigorous-goldberg/` and `docs/fusion/research/` unless noted. **Caveat [I]:** the
`from-vigorous-goldberg` modules predate the 2026-05-05 Hermes purge — grep current `agent_core/src/` for
already-shipped equivalents (esp. `tools::breaker`, compaction, security) before promoting; Intent→Effect, undo,
NightBrain-scheduler and skill_discovery appear genuinely un-promoted.

```
[GUS-6] INTENT→EFFECT typed apply pattern. salvage/from-vigorous-goldberg/agent_core_src/effect/
  {mod,dispatcher,vault_applier,concept_applier,memory_applier}.rs — typed Intent→Effect with a
  PRE-COMPUTED Inverse, distinct from the Cognitive DAG. Attach: agent_core runtime apply path.
  (PLAN §8 / FINAL_SYNTHESIS §2 layer 6.) Net-new vs cycle 1.

[GUS-7] SIGNED EXECUTION RECEIPT. salvage/.../effect/receipt.rs — per-Effect Ed25519-shaped signed
  proof-of-execution (call_id/plan_hash/input_hash/output_hash/capabilities_used/signature) + a SigningKey
  trait for Keychain keys. Sits BESIDE agent_core::provenance::ClaimLedger (which does claim-retraction, NOT
  signed per-call receipts). Attach: agent_core::provenance. (FINAL_SYNTHESIS §5.5.)

[GUS-8] UNIVERSAL UNDO LOG. salvage/.../undo/mod.rs — ⌘Z-within-24h reversal via the GUS-6 pre-computed
  inverse Effects (undo_events.sqlite). Attach: agent_core + the apply path. (PLAN §8.5.)

[GUS-9] NIGHTBRAIN IDLE SCHEDULER (shell only). salvage/.../nightbrain/mod.rs — thermal/battery/idle-gated
  overnight maintenance worker pool, checkpoint-resumable. The APP-SIDE scheduler shell (NOT the excluded
  nightly model fine-tune). Pairs with research/nightbrain_tasks.rs's 5 app-maintenance task bodies. Attach:
  agent_core lifecycle/idle_monitor. (PLAN §7.1, FINAL_SYNTHESIS layer 7 "Metabolism.")

[GUS-10] SKILL DISCOVERY / PROMOTION. salvage/.../skill_discovery/mod.rs — auto-draft .skill.json/.md on
  novel+accepted+in-budget tool-sequence compositions (tool-sequence-hash novelty + no-⌘Z acceptance window),
  user-confirmed promotion. Attach: agent_core::agent_runtime skills. (PLAN §11 Phase 12.5.)

[GUS-11] DETERMINISTIC CONCEPT CANONICALIZER. salvage/.../canon/{mod,alias}.rs — no-LLM canonical-name
  pipeline (lemmatize + sort multi-word) feeding the Cognitive DAG + search. (PLAN §3.7; one documented
  spec-vs-example divergence note to resolve on import.)

[GUS-12] SELF-HEAL Try-Heal-Retry + CircuitBreaker. salvage/.../heal/{mod,breaker,log}.rs — app-side
  resilience loop (heal_events.sqlite). VERIFY-FIRST: heal/breaker re-exports tools::breaker which may already
  ship — dedup before importing. (FINAL_SYNTHESIS §5.2.)

[GUS-13] FOUR-VARIANT capture router (typed). salvage/.../route/{mod,variant_a,variant_b,variant_c}.rs —
  typed Rust A/B/C/D capture ladder with JSON schemas + floor constants (relates to Swift ConfidenceRouter;
  this is the typed Rust impl). Lower priority — overlaps GUS-2/confidence_floors; assess for dedup.

[GUS-14] OVERSEER / AGENT-HIERARCHY policy doc. docs/fusion/research/OVERSEER_AND_AGENT_HIERARCHY.md —
  "overseer is a ROLE, not a model family"; hierarchical (not swarm) coordination with review/critique/budget/
  safety/intervention responsibilities. Model-agnostic → NOT excluded. Attach: MAS-tier orchestration policy.

[GUS-15] ADAPTATION SUBSYSTEM governance spec. docs/fusion/research/ADAPTATION_SUBSYSTEM_SPEC_v1.md —
  bounded/reversible/helper-model-FIRST adaptation: explicit allow/deny, NO base-weight mutation, NO silent
  chat learning, adapter/session entities + canary/rollback. This is APP-SIDE GOVERNANCE OF adaptation (the
  guardrail), NOT the excluded model spine. Attach: a governance doc + the LoRA/helper-adaptation boundary.

[GUS-16] COMPUTE-STEERING policy spec. docs/fusion/research/COMPUTE_STEERING_SPEC_v1.md — policy-driven
  selection of helper modules/masks/expert+execution budgets/KV policy/sidecar activation under telemetry,
  kept deliberately model-agnostic. Aligns with System G / RuntimeRouter canon. Attach: RuntimeRouter compute-
  profile layer. (Pairs with research/compute_steering.rs.)

[GUS-17] FOUR-GATE TOOL-ADOPTION discipline (EXTERNAL → import as governance doc). From ~/Downloads/
  EPISTEMOS_HELIOS_v4_1_AMENDMENTS.md §A3.3 (grep-VERIFIED absent in repo). Substrate/Containment/Direction/
  Discipline gates, 4/4=canon→1/4=reject scoring, with an optional CI/source-guard lint flagging new deps that
  lack the four-gate attestation. Pure app-side process IP. Attach: a docs/fusion governance doc + source-guard.

[GUS-18] DOC-FIX — record the H8 OSPC drift: HELIOS_V5_DOC_6_THEOREM_CANON.md claims H8 has "4 of 9 OSPC
  mirrors" live in agent_core/src/cognitive_dag/dispatch.rs, but dispatch.rs only mirrors ledger commits — the
  9-arm {bind,unbind,gate,route,commit,reorder,merge,split,quarantine} MutationEnvelope is NOT there (those
  refs live in unrelated agent_runtime_v2). Mark H8 THEORETICAL. Zero behavior change; prevents over-claiming.
```

**Confirmed SUPERSEDED / THEORETICAL (cycle 2):** the entire deliberation/oversight/fleet/agent-build-scaffolding
subdir mass (~566 files) = PROCESS scaffolding, not IP; `pasted/` + `jordan's research/GPT|kimis-epistenos` =
70B/new-model EXCLUDED; the Helios external lineage = absorbed-verbatim-in-repo (SUPERSEDED) save GUS-17; the
theorem catalog's live invariants (E4/E7/H2/H3/H17/vpd-arm) = SUPERSEDED-into-the-verification-layer (= GUS-2/
UNIFY-6, not new); `epistemos-research/` = the `--features research` Lane-3 preservation home, confirmed intact.

### 2G. Regions left for Cycle 3

The high-value seams (code modules, theorem catalog, salvage/ + research/ subdirs, external lineage) are now
swept. Remaining low-probability regions, for completeness:

1. **`from-vigorous-goldberg` dedup verification** — before any GUS-6..13 import, grep current `agent_core/src/`
   for already-shipped equivalents (the one explicit caveat carried into cycle 3). Likely the highest-value
   cycle-3 action — it converts candidates into confirmed-net-new or confirmed-superseded.
2. **The 4 `~/Downloads/Pasted markdown (N).md` files** — not opened this cycle (INFERRED superseded by size/date
   cluster). One spot-check closes the last external gap.
3. **`docs/research/SS-*` slices** (58 per RESEARCH_FINALIZATION_INDEX) — confirm none hide further substrate IP
   (cycle 1 deferred; low probability — they are code-grounded analysis slices, not raw IP).
4. **`epistemos-vault/` crate full read** — cycle 2 touched it only via the PCF theorems; confirm it is entirely
   the model-surgery/runtime (EXCLUDED) Lane-5 domain with no app-side spillover.

**CONVERGENCE STATUS: NOT YET — but NEAR.** Cycle 2 found a real net-new cluster (GUS-6..18, concentrated in
`salvage/from-vigorous-goldberg/` + `research/` specs + one external four-gate rubric) and confirmed no new
EXCLUDED surface beyond the known brain-1 spine. Cycle 3's job is mostly *confirmation* (dedup the goldberg
modules, spot-check the Pasted files, glance at SS-* + epistemos-vault); if cycle 3 finds the goldberg modules
already shipped and the residual regions empty, the sweep CONVERGES. **The salvage opportunity remains small,
additive-safe, and entirely app-side — exactly as cycle 1 predicted, now with code-level attach-points.**

---

*Cycle 2 grounded against files read 2026-06-22: `agent_core/src/research/` (all ~40 modules via mod.rs/head +
`lib.rs:69`, `Cargo.toml:25`), `epistemos-research/src/lib.rs` + `Cargo.toml`, `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md`
cross-checked against `epistemos-research/src/{theorems,vpd}/`, `epistemos-vault/src/`, `agent_core/src/scope_rex/`;
the fusion subdirs `salvage/`, `research/`, `jordan's research/`, `pasted/`, `deliberation/`, `oversight/`,
`fleet/`, `simulation/`, `agent-build-scaffolding/`; and the external read-only corpus `~/Downloads/{helios v4
updated, Helios third, helios v5*, helios v6.2, EPISTEMOS_HELIOS_v4_1_AMENDMENTS, EPISTEMOS_GRAND_MASTER_v3,
EPISTEMOS_FINAL_SEVEN_THEOREMS{,_v2_HARDENED}, EPISTEMOS_V6_1_FINAL_SYNTHESIS_LOCK, deep-research-report (6)/(7),
compass_artifact_*}.md` + ls of `Epistemos-cursor/`, `openclaw-main/`, `AETHERLINK_APPLICATION_KIT_FULL/`. NOT
committed (per the sweep directive). Next: cycle 3 = dedup-verify GUS-6..13 against live agent_core + close the
residual regions; declare convergence if nothing new.*

---

## Cycle 3 — DEDUP + RESIDUAL-REGION CONFIRMATION → CONVERGENCE CALL

Same exclusion + anti-hallucination rules. **[V]** = file/dir read or grepped this cycle, **[I]** = inferred from
verified facts. This is the convergence cycle: it (1) dedups GUS-6..13 against live `agent_core/src/` — the one
explicit caveat carried from cycle 2 — (2) spot-checks the `~/Downloads/Pasted markdown` files, (3) scans the
`docs/research/SS-*` slices, (4) confirms `epistemos-vault/` is fully EXCLUDED, and (5) issues the convergence call.

### 3A. DEDUP — GUS-6..13 vs live `agent_core/src/` (HIGHEST VALUE)

**Headline finding [V]:** the `from-vigorous-goldberg` modules are **ALREADY SHIPPED LIVE** in `agent_core/src/`.
The live tree has every goldberg directory 1:1 (`effect/`, `undo/`, `nightbrain/`, `canon/`, `heal/`, `route/`,
`skill_discovery/`) plus `confidence_floor.rs` + `circuit_breaker.rs`, **all unconditionally compiled** (NOT
`--features research`-gated — verified: none appear under any `cfg` in `agent_core/src/lib.rs:1-98`). Cycle 2's
caveat ("Intent→Effect, undo, NightBrain-scheduler and skill_discovery appear genuinely un-promoted") is **REFUTED
by the live code** — they were promoted. Per-item:

| GUS | Capability | Live path(s) | Status | Verified signature / wiring | Cited |
|---|---|---|---|---|---|
| **GUS-6** | Intent→Effect typed apply + pre-computed Inverse | `agent_core/src/effect/{mod,dispatcher,vault_applier,concept_applier,memory_applier}.rs` | **ALREADY-LIVE (shipped, wired)** | `dispatcher.rs:47` `async fn apply(&self, intent) -> Result<(Effect, Option<PriorState>), ApplyError>`; tested by `tests/effect_salvage.rs`; **wired** into `agent_runtime_v2/mission_run.rs` + `heal/{mod,log}.rs` | [V] |
| **GUS-7** | Signed ExecutionReceipt (Ed25519-shaped) | `agent_core/src/effect/receipt.rs` | **ALREADY-LIVE — but crypto is HMAC-SHA256, not Ed25519 (one real residual gap)** | `receipt.rs:75-112` carries `plan_hash/input_hash(impl)/output_hash/capabilities_used/signature` + `sign<K>()`/`verify<K>()` over a `SigningKey` trait; concrete impl is `HmacSha256SigningKey` (`:138-189`). **No `ed25519`/`dalek` dep anywhere** (`Cargo.toml` grep empty). Wired into `mission_run.rs` + `acs_admission/*`. | [V] |
| **GUS-8** | ⌘Z universal undo log (24h, inverse-driven) | `agent_core/src/undo/mod.rs` | **ALREADY-LIVE (shipped) — but NOT runtime-wired (orphaned)** | `undo/mod.rs:9` rusqlite (`undo_events.sqlite`), `:33` `DEFAULT_TTL = 24h`, `:34` `AUTO_RESEARCH_TTL = 7d`, `inverse` column/field; tested by `tests/undo_salvage.rs`. **No production caller** outside its own module + the salvage test → the ⌘Z surface is not hooked into the apply path yet. | [V] |
| **GUS-9** | NightBrain idle scheduler (app-side shell) | `agent_core/src/nightbrain/{mod,live.rs}` | **ALREADY-LIVE (shipped, wired)** | `mod.rs:42-44` `idle_for`/`thermal_nominal`/`on_ac_or_battery_above_50`, `:12-13` checkpoint task ids, `:150-186` idle-threshold gating; 13 tests. **Wired** into `bridge.rs` (FFI) + `session.rs`. App-side only (no model fine-tune). | [V] |
| **GUS-10** | Skill discovery / promotion (tool-seq-hash novelty) | `agent_core/src/skill_discovery/mod.rs` | **ALREADY-LIVE (shipped) — partial wiring (test/CLI-driven, not in live runtime path)** | `:71-90` `sequence_hash()` + novelty check, `:106` `existing_sequence_hashes` map, `.skill.json/.md` draft (`:6-11`); 8 tests + exercised across many `tests/*_bridge.rs`. No non-test production caller found → promotion path is built+tested but not yet invoked by the live loop. | [V] |
| **GUS-11** | Deterministic concept canonicalizer | `agent_core/src/canon/{mod,alias.rs}` | **ALREADY-LIVE (shipped, wired)** | `mod.rs:27` `pub fn canonicalize()`, `:50` `stems.sort()` (lemmatize+sort), `alias.rs` `AliasTable`/`classify_alias_cosine`/`ALIAS_V1_ID`; tested by `tests/canon_salvage.rs`. **Wired** into `route/variant_c*.rs` + `effect/concept_applier.rs`. | [V] |
| **GUS-12** | Self-heal Try-Heal-Retry + CircuitBreaker | `agent_core/src/heal/{mod,breaker,log.rs}` + `agent_core/src/circuit_breaker.rs` | **ALREADY-LIVE (shipped, wired) — dedup CONFIRMED** | `heal/breaker.rs:1` is a `pub use crate::circuit_breaker::{...}` re-export (the cycle-2 "dedup before importing" caveat resolved: breaker already lives at top-level `circuit_breaker.rs`, heal re-exports it — no duplicate). `heal/mod.rs:32-57` `HealLoop` w/ breaker + `max_heal_steps`; 16 tests; `heal_events` via `log.rs`. Wired via `effect`. | [V] |
| **GUS-13** | Four-variant typed capture router | `agent_core/src/route/{mod,variant_a,variant_b,variant_b_classifiers,variant_c,variant_c_providers}.rs` | **ALREADY-LIVE (shipped, wired) — and richer than the salvage stub** | `route/mod.rs:19-31` floor consts `VARIANT_A_FLOOR=0.85`/`B=0.75`/`C=0.70` + merge/cluster gates; JSON-schema ids `:16-17`; 15 tests. Live impl adds `variant_b_classifiers`/`variant_c_providers` beyond the goldberg source. Consumes GUS-11 canon. | [V] |

**3A verdict [V]:** **GUS-6, 9, 11, 12, 13 = fully SHIPPED + WIRED → DOWNGRADE to SUPERSEDED/done (not build work).**
GUS-7, 8, 10 = **SHIPPED but with a residual gap each** (the only real cycle-3 work, all tiny/additive):
- **GUS-7-gap:** ExecutionReceipt signs with **HMAC-SHA256, not Ed25519**. The spec said "Ed25519-shaped"; the trait
  seam (`SigningKey`) is correct and an Ed25519 impl would drop in behind it, but the asymmetric-signature property
  (public verifiability without the secret) is NOT yet there. Real, small: add an `Ed25519SigningKey: SigningKey`
  (Keychain-backed) impl. [V]
- **GUS-8-gap:** undo log is built+tested but **not runtime-wired** — no production caller hooks ⌘Z into the apply
  path. Real, small: call `UndoLog::record` from the `effect` apply site + expose a reverse FFI. [V]
- **GUS-10-gap:** skill_discovery is built+tested but **only test/bridge-driven** — the live agent loop doesn't yet
  invoke the novelty→draft→promote path. Real, small: call it from `agent_runtime` post-accepted-composition. [V]

So of the eight cycle-2 GUS-6..13 "salvage build items," **five are already done** and **three reduce to a one-function
wiring/crypto-swap each** — i.e. the goldberg cluster is ~90% shipped, contradicting cycle 2's "genuinely un-promoted"
inference. This is the single most load-bearing cycle-3 correction.

### 3B. Spot-check `~/Downloads/Pasted markdown` files (closes the last external gap)

**[V]** Opened all five (bare `Pasted markdown.md` + `(1)`–`(4)`), grepped distinctive phrases against the repo:

| File | Date/topic | Verdict | Key proof |
|---|---|---|---|
| `Pasted markdown.md` | Apr-24 V1 ship-audit + "instant recall" voice-note | **SUPERSEDED** | the requested Contextual-Shadows live-recall button is shipped (`Epistemos/Views/Recall/ContextualShadowsPanel.swift`, `epistemos-core/src/instant_recall/`) [V] |
| `(1)` | May-4 "Bow-Tie / Morph / eml★" (note: stale "Episten**o**s" spelling) | **SUPERSEDED** | `research/eml_ir/`, `theorems/e3_morph_field.rs`, `Shaders/morph_eval_reduced.metal` [V] |
| `(2)` | May-4 fullest Morph-substrate synthesis | **SUPERSEDED** | tri-plane DAG + WBO-8 + Lean obligations all in `epistemos-research/` + `cognitive_dag/` [V] |
| `(3)` | May-4 DAG+EML "final synthesis" (lighter dup of (2)) | **SUPERSEDED** | same signatures [V] |
| `(4)` | May-11 HELIOS graph-engine prompt + V6.1 substrate inlined verbatim | **SUPERSEDED** | verbatim consts `RHO_MAX_T35_V6_1=0.20`, `ENGRAM_KAPPA_THRESHOLD=0.382`, kernel names in `epistemos-research/tests/canonical_consistency.rs`; file's own Part-1 is a self-audit of the repo's `epistemos-research` crate [V] |

**3B bottom line [V]:** all five are pre-absorption research **drafts**, every distinctive concept already in-repo
in more mature form. **No net-new IP. No 70B/excluded spec** (they explicitly say "do NOT make EML the whole model").
Cycle 2's INFERRED-superseded was **correct** — now VERIFIED by opening them.

### 3C. `docs/research/SS-*` slice scan

**[V]** **72** SS-* slices (more than the index's "~58" — the P0/doctrine wave SS-CHATMODEL/SS-CHATPICKER/
SS-AUTONOMOUS-VERIFY/SS-PROVEN-DONE etc. pushed the count up). Read 24 in body (every slice whose name suggested
substrate/brain/memory/eidos/dag/acs/uas/governance), title-triaged the rest. Result: **none hide owner-IP outside
GUS-1..18 or the active 194-item ledger queue.** [V] Categories:
- substrate/brain-named slices are **SUPERSEDED or already mapped** — `SS-LI` IS the source for GUS-1; `SS-SUB`/`SS-SH`
  = substrate-health surfacing (GUS-1-class); `SS-UMA`/`SS-IR` fold into Eidos (GUS-3/UNIFY-5); `SS-Y`/`SS-AL` are
  chat-engine plumbing already queued.
- ~50 slices are **app-feature/UI/UX/bug-fix** (settings, crashes, themes, Epdoc, pickers, voice/PDF, perf, redaction)
  — ledger-queue work, not salvage IP.
- governance-adjacent (`SS-AD` adapter-UX, `SS-LS` LoRA-studio, `SS-XR`) stay inside the GUS-15 adaptation-governance
  fence; propose no new substrate engine.

**3C bottom line [V]:** SS-* region is **empty of un-salvaged substrate/brain IP** — exactly the cycle-2 §2G prediction.

### 3D. `epistemos-vault/` exclusion confirmation

**[V]** Read every `.rs` + `Cargo.toml`. The crate self-declares **HELIOS V5 Lane 5 (SPECULATIVE_VAULT)**,
`publish = false`, **every module `#[cfg(feature = "vault")]`-gated** (`src/lib.rs:31-41`; `default = []`), deps are
only `serde`/`serde_json`/`thiserror` — **no app crates, no FFI, no `no_mangle`/UniFFI, no file-IO/UI/search/ledger.**
Modules are all model-weight surgery: `surgery::envelope` (PCF-6 weight edit), `runtime::active_rank_one` (PCF-5 infer-path
mod), `runtime::transfer` (PCF-10), `distill::connectome` (PCF-9 — verbatim *"producing a NEW model file"*, carries
`output_model_sha256`), `cache::{hcache,kvcrush}` (KV-cache compression). The three app-IP grep "hits" were benign
substring false-positives (an `author: String` "provenance" field, a `verified: bool` flag, a "build later" comment).

**3D bottom line [V]:** `epistemos-vault` is **fully EXCLUDED (model-surgery/PCF Lane-5, vault-gated) with ZERO
app-side spillover.** No salvage hides here. Cycle-2 finding verified.

---

## CONVERGENCE — sweep complete

**CONVERGED: YES.** Cycle 3 found **no new USEFUL+RELEVANT salvage item and no new EXCLUDED surface.** Every region
flagged for cycle 3 came back either *already-shipped* (the goldberg cluster) or *empty* (Pasted files, SS-*, vault).
The only residual work is three tiny one-function gaps inside *already-shipped* modules — additive, not new IP. The
two cycles before this already drove the salvage set to a small, concentrated, app-side, additive-safe set; cycle 3
confirms it and closes it.

### FINAL SALVAGE SET — REAL build work vs already-shipped (definitive)

**ALREADY-SHIPPED / SUPERSEDED (no build work — downgrade these out of the salvage queue):**
- **GUS-6, GUS-9, GUS-11, GUS-12, GUS-13** — Intent→Effect apply, NightBrain idle scheduler, concept canonicalizer,
  self-heal+circuit-breaker, four-variant router: **all live, wired, tested** in `agent_core/src/{effect,nightbrain,
  canon,heal,route}` (unconditionally compiled). [V]
- **The brain-2 organs** (Cognitive DAG, Eidos, provenance ledger, EML/Belnap/confidence verification primitives,
  UAS/ACS) — already the substrate / already the existing UNIFY-4/5/6 targets. [V cycles 1-2]
- **All Helios theorem live-invariants** (E3/E4/E5/E7, H1/H2/H3/H17, PCF-6/9) — SUPERSEDED-into-verification-layer. [V c2]

**REAL (small, additive) build work that survives convergence:**
- **GUS-7-gap** — add an `Ed25519SigningKey: SigningKey` (Keychain-backed) behind the existing `effect::receipt`
  trait seam; today the receipt signs with HMAC-SHA256 (symmetric, not publicly verifiable). One impl. [V]
- **GUS-8-gap** — wire the (built, tested) `undo` log into the `effect` apply path + a reverse FFI for ⌘Z; today it
  has no production caller. One call-site + one FFI. [V]
- **GUS-10-gap** — invoke the (built, tested) `skill_discovery` novelty→draft→promote path from the live
  `agent_runtime` loop; today it is only test/bridge-driven. One call-site. [V]
- **GUS-1..5, GUS-14..18** — unchanged from cycles 1-2: living-index status panel (GUS-1), EML/Belnap/confidence
  *wiring* into the AnswerPacket gate (GUS-2), TurboVec Eidos backend (GUS-3, Pro-gated), UAS/ACS harden-to-doc
  (GUS-4), the exclusion + H8-drift doc-fixes (GUS-5/GUS-18), and the three governance docs (overseer GUS-14,
  adaptation GUS-15, compute-steering GUS-16, four-gate tool-adoption GUS-17). All additive, behind existing gates.

### Where all the IP landed — the definitive one-paragraph close

The owner's entire local-research corpus resolves into three destinations and nothing is lost. (1) **The model
half — the from-scratch SSM/Mamba-3 spine, signal_bus, M0/M1 interrupt, ternary/QAT runtime, Engram, KV-direct,
attention-sinks, the 70B, and the whole `epistemos-vault` PCF/model-surgery Lane-5 — is EXCLUDED by owner directive**
and lives in the owner's Cursor domain + the `--features research`/`--features vault` preservation crates
(`agent_core/src/research/`, `epistemos-research/`, `epistemos-vault/`), compiled out of the product. (2) **The app
half — "brain-2": authority, deliberation, memory, and verification — is already the live substrate**: the Cognitive
DAG, Eidos recall, provenance ledger, Halo/Shadow RRF index, the EML/Belnap/confidence honesty primitives, UAS/ACS,
and the now-confirmed-shipped goldberg cluster (Intent→Effect + signed receipts + undo + NightBrain + canonicalizer
+ self-heal + four-variant router) — all in `agent_core/src/`, unconditionally compiled, and matching the
`ARCHITECTURE_UNIFICATION_SYSTEMG` "one brain, two faculties, one substrate" verdict. (3) **What remains as genuine,
finishable, additive-safe work is a short tail** — three one-function wirings inside already-shipped modules (Ed25519
receipt, ⌘Z undo wiring, skill-discovery loop hook) plus the GUS-1..5/14..18 panels, gate-wirings, and governance
docs — every item app-side, model-agnostic, behind existing flags, and incapable of touching the hardened
Osaurus(act)/OpenCode(work) clones or the excluded model spine. **The grand unification sweep is CONVERGED: the IP
is fully located and classified, the excluded model half is fenced, the app half is largely shipped, and the salvage
remainder is small, safe, and enumerated.**

---

*Cycle 3 grounded against files read/grepped 2026-06-22: live `agent_core/src/lib.rs` (mod table, cfg check) +
`agent_core/src/{effect/*,undo/mod.rs,nightbrain/{mod,live}.rs,canon/{mod,alias}.rs,heal/{mod,breaker,log}.rs,
route/mod.rs,skill_discovery/mod.rs,circuit_breaker.rs,confidence_floor.rs}` vs the goldberg source
`docs/fusion/salvage/from-vigorous-goldberg/agent_core_src/*`; wiring greps across `agent_core/src/` + `agent_core/tests/`;
`~/Downloads/Pasted markdown{,(1),(2),(3),(4)}.md` (opened, repo-grep-verified superseded); `docs/research/SS-*`
(72 slices, 24 read in body); `epistemos-vault/{Cargo.toml,src/**/*.rs}` (full read, EXCLUDED confirmed). NOT committed
(per the sweep directive). CONVERGENCE DECLARED — no further cycle required.*
