---
state: canon
canon_promoted_on: 2026-05-02
frontmatter_added_on: 2026-05-06
covers: load-bearing concept index across 7 worktrees + 5 unindexed Downloads research roots + Quick Capture standalone canon + ~60 external research files
---

# Master Research Index — 2026-05-02

> **NEW DOC — created 2026-05-02.** Filename: `MASTER_RESEARCH_INDEX_2026_05_02.md`. Search by name if older session indexes don't list it. Sister docs: `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`, `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md`, `WORKTREE_INSIGHT_SALVAGE_2026_05_02.md`, `CANON_GAPS_AND_ADDENDA_2026_05_02.md`, `CODEX_DELIBERATION_PROMPT_2026_05_02.md`, `ALL_DOCS_INDEX_2026_05_02.md`. Next-session execution bootstrap: `NEXT_SESSION_PROMPT_2026_05_04.md` (loads context, treats dirty files as active work surface, and drives the full canonical plan forward). Mirrored into the active worktree.

> **Purpose.** When Codex hits any concept, feature, mini-task, or term — look it up here. This index maps every load-bearing concept to (a) its canonical source on disk, (b) supporting / cross-reference docs, (c) code anchors with absolute paths, (d) tier classification, and (e) one load-bearing claim quoted verbatim. **Compiled from 8 parallel deep-scans** of all 7 worktrees + 5 unindexed Downloads research roots + the Quick Capture standalone canon (~470 KB) + ~60 external research files.
>
> **The user's instruction:** "It must research my disk in my laptop for research related to any concept or mini task it runs into… should be accurate." Use this index to find what's on disk. Open the canonical source first. Cross-reference only when the canonical doesn't answer.

> **2026-06-01 full-thread lock.** The complete June 1 research/canon thread is
> recoverable with `JUNE1-CANON-FUSION-LOCK` and the paste-ready handoff
> `docs/audits/CODEX_JUNE1_FULL_THREAD_CANON_REINTEGRATION_PROMPT_2026_06_01.md`.
> This includes formal math company intake, meta-breakthrough controls,
> constructive residency, cache lineage, portable note systems, engineering
> logic, semantic working sets, substrate trace observability, sparse route
> verification, ColdStream transport, mmap/hot-path cure, Residency
> PatternBoost, lattice HTML, drift sweeps, and build preservation.

---

## 0. Honest Discoveries (read first — these correct prior canon)

These are findings the deep-scan surfaced that **contradict or sharpen** earlier docs. Codex should treat these as authoritative over older claims.

| # | Finding | Source | Why it matters |
|---|---|---|---|
| H1 | **Lane A is NOT "mostly merged."** It has **601 unmerged commits** ahead of main, all on the N1 Prompt Tree track, including a 270-line `PROMPT_AS_DATA_SPEC.md` and full PTF (Prompt Tree Format) implementation behind `EPISTEMOS_PROMPT_TREE=1` flag. The fusion review's "mostly merged" classification was incorrect. | `git log $(git merge-base lane-A main)..lane-A \| wc -l` confirmed 601; 2026-05-04 recheck found current main now declares `agent_core/src/session_insights.rs` but still differs from Lane A in `ChatCoordinator`, Rust bridge/provider telemetry, and docs | Phase R/N1 planning must compare Lane A deltas before any prompt-as-data closure claim |
| H2 | **Hermes-parity uses plain markdown prompts, NOT NousResearch ChatML XML.** `agent_core/src/prompts.rs` opens with `BASE_SYSTEM_PROMPT = r#"You are Epistemos…"#` — no `<\|im_start\|>` markers. | `worktree:hermes-parity/agent_core/src/prompts.rs` lines 53-57 | Doctrine Annex A.12's reference to NousResearch ChatML applies to **future** Pro Hermes subprocess work, not current code |
| H3 | **Apple Intelligence fallback is real, not placeholder.** Multiple Swift services (`AppleIntelligenceService.swift`, `InferenceState.swift`, `CloudKnowledgeDistillationService.swift`) reference `apple_intelligence` / `apple-intelligence` as a real provider variant. | `worktree:hermes-parity/Epistemos/Engine/AppleIntelligenceService.swift` | When TriageService recommends fallback to Apple Intelligence, it's a real path |
| H4 | **Error classifier IS wired into agent_loop** (earlier worry that it might be dead code is unfounded). `worktree:hermes-parity/agent_core/src/error_classifier.rs` is imported by `agent_loop.rs` line 10. 100+ patterns active. | `worktree:hermes-parity/agent_core/src/agent_loop.rs:10` | Salvage §2.4 risk is closed |
| H5 | **Quick Capture standalone canon has 5 monster docs totaling ~430 KB**, not just `PLAN.md` + `FINAL_SYNTHESIS.md`. Three previously-unindexed: `BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md`, `LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md`, `OBSCURA_BROWSER_ADDENDUM.md`. Plus BUILDER_PROMPT, CATCHUP_PROMPT, AUDIT_PROMPT, INDEX, README. | `/Users/jojo/Documents/Epistemos-QuickCapture/` | Codex must read FINAL_SYNTHESIS first; it corrects PLAN.md and rewrites Wave 6 sequencing |
| H6 | **Six v1.6 `AgentEvent` variants are NOT yet in main's enum.** They are documented in simulation worktree's DOCTRINE.md §11 v1.6 + IMPLEMENTATION.md but the Rust enum at `worktree:simulation/agent_core/src/events.rs` only enumerates the original 32 variants. The six new ones (`SteerRequested`, `SummaryStarted/Delta/Completed`, `VaultCreated`, `VaultArchived`) are forward-references for S6 patches. | `worktree:simulation/agent_core/src/events.rs` lines 272–499 | Pro tier sidebar dispatch + multi-vault UI need these added before they ship |
| H7 | **W9.21 PR4 honest-handle is "claimed shipped" but Swift still binds legacy surface.** `RustShadowFFIClient.swift:39` uses legacy `shadow_open_at` returning `Int32`, not the new handle FFI. The honest_handle.rs module is orphan scaffolding. | `worktree:agent-a0550f9c` audit pass #1 finding | The pattern is correct; the wiring is incomplete. Don't claim it shipped. |
| H8 | **D-series doctrine primitives D1, D3, D11 are absent from codebase.** D1 BLAKE3 chain, D3 A2UI catalog, D11 epistemos-trace CLI are all specified in canonical audit log but not implemented. W9.27 OpLog schema is missing `prev_hash BLAKE3` column AND missing `PRAGMA journal_mode = WAL` + `fcntl(F_FULLFSYNC)`. | `worktree:agent-a0550f9c/docs/CANONICAL_AUDIT_LOG.md` | Salvage map's "OpLog Merkle chain shipped" needs verification — chain may be partial |
| H9 | **CODE_EDITOR_FEATURE_AUDIT.md found drift on every editor feature.** Minimap reverted (line 1232 comment "Minimap removed — outline navigator replaces it"), search bar UI exists but `performSearch()` is stub, semantic sidebar code exists but gated to false (line 291 never visible), status bar replaced by EditorBreadcrumbBar, persisted prefs 5/6 active. | `worktree:inspiring-heisenberg-ea9dc3/CODE_EDITOR_FEATURE_AUDIT.md` | Editor work must verify against live code; doc claims drift fast |
| H10 | **Quick Capture worktree LEGACY_TO_V2_ALIASES has ~56 entries, ~54 conversions remaining.** Only `TodoHandler` (Phase 2G-4a canary) is converted. The rest (24 files, ~54 `impl ToolHandler` blocks) need the macro from Phase 2G-4d. No standalone migration guide exists — pattern lives only in commit messages. | `worktree:vigorous-goldberg-3a2d35/agent_core/src/tools/registry.rs` | Stay-stellar #1; needs `agent_core/docs/TOOL_MIGRATION_STATUS.md` |

## 0A. 2026-05-24 Candidate Addendum — Shadow Projection + Research Construction

**New builder-facing source:** `docs/fusion/SHADOW_PROJECTION_AND_RESEARCH_CONSTRUCTION_2026_05_24.md`.

**Online intake source:** `docs/fusion/ONLINE_RESEARCH_INTAKE_SHADOW_PROJECTION_2026_05_24.md`.

**Why it exists.** The Erdős unit-distance result and OpenAI Parameter Golf sharpen the same substrate lesson: search for a better coordinate chart, not merely a bigger model or a larger context window. The addendum reduces the architecture to one invariant and three motions:

1. **Lift / Ingest** — surface to substrate.
2. **Project / Compress / Recall** — substrate to useful surface.
3. **Mutate / Promote** — substrate to substrate, under SCOPE-Rex/SovereignGate + witness + rollback.

**Status discipline.** The addendum is `state: candidate`. It does **not** silently promote L8, E8, E9, `ShadowProjection<H,L>`, T28, W-Lift-N, or `F-Erdos-Lift-Optimality` to canon. Agents must treat those as candidate work until local falsifiers and WRV caller chains exist.

**Agent rule.** Any Phase 2+ PR that invokes "unified cognitive substrate," "lattice," "shadow projection," "auto fine-tuning," "best neuron group," or "Research Construction Engine" must cite the addendum and include a No-Orphan check: motion, UAS address, plane, ProductBuild, ProStatus/ResidencyStatus, WBO/error policy, witness, falsifier, rollback.

**Public-research rule.** Any Phase 2+ PR that cites Parameter Golf, the Erdős unit-distance result, EML forks, arXiv papers, GitHub PRs/forks, or forum-derived ideas must also cite the online intake source and classify each source by credibility rank. Public code is mined for motifs, never raw-merged, unless a separate vendor/setup PR is explicitly approved.

---

## 0B. 2026-05-24 Canon Target — Addressable Neural Substrate

**New no-compromise source:** `docs/fusion/ADDRESSABLE_NEURAL_SUBSTRATE_CANON_2026_05_24.md`.

**Why it exists.** This preserves the original endgame so agents do not collapse the architecture into ordinary RAG, ordinary MoE, ordinary subquadratic attention, or generic MLX inference. The target is:

> Epistemos turns a dense model into an addressable neural substrate. An SSM/state router selects active assemblies of layers, rank-one components, KV pages, adapters, residual islands, and kernels; the residency governor pages only that working set into UMA; verification proves the selected path preserves dense/reference behavior within a budget.

**Canonical distinction.** This is canon as the target architecture and vocabulary. ACS (Anchored Cognitive Substrate) naming remains scoped to AcsAnchor lineage and related legacy witness IDs. This is **not** a production claim until the falsifiers pass: `F-Sparse-Runtime-Split`, `F-KV-Direct-Gate`, `F-UAS-CopyCount`, `F-UAS-ACS-MmapResidency`, `F-ActiveAssembly-Minimal`, `F-ULP-Oracle`, `F-Agent-Local-Model-Runtime-Bridge`, and `F-70B-Local-Cocktail`. Current nuance: `F-UAS-ACS-MmapResidency` is a legacy-named witness that proves file-backed UAS plus AcsAnchor/ColdStore-style residency for one deterministic mmap slice; it does not prove live MLX generation or 70B local inference.

**Agent rule.** Any Phase 2+ PR touching local inference, model routing, ActiveAssembly, KV/cache residency, adapters, EML kernels, or "large local model" claims must cite this source and include a Neural Substrate check: addressed unit, UAS address, plane, residency, router, dense/reference verifier, falsifier, and rollback.

---

## 0C. 2026-05-30 Candidate Intake — AetherLink / OAS / AletheiaFS

**New candidate-intake source:** `docs/fusion/AETHERLINK_OAS_CANON_INTAKE_2026_05_30.md`.

**Cleanup companion:** `docs/audits/AETHERLINK_KIT_AND_WORKTREE_CANON_CHECK_2026_05_30.md`.

**Source kit:** `/Users/jojo/Downloads/AETHERLINK_APPLICATION_KIT_FULL/AETHERLINK_APPLICATION_PROJECT`.

**Why it exists.** The AetherLink kit sharpens the existing doctrine into a
proof-carrying coordinate-state runtime: models propose, the runtime verifies,
and the ledger remembers. This is canon-aligned with Helios / SCOPE-Rex /
System G / AcsAnchor / UAS, but it is an intake addendum, not a new product route.

**Large-model impact.** AetherLink's Ontological Address Space language adds
the missing large-model bridge artifact: a `WeightBlockManifest` /
`ResidencyPlan` over model file byte ranges, UAS addresses, lattice/ternary/NF4
encodings, WBO budgets, dense/reference rollback, and verifier witnesses. Build
that manifest/simulator before launching more 65K/128K/70B probes.

**Status discipline.** Antigravity, gravitophoton propulsion, zero-latency,
infinite precision, and perfect optimal control remain `DROP` for public/product
claims. seL4, SMC, neural HJB, and learned certificates are external grounding
sources only; they do not make AetherLink flight-ready or product-ready.

**Agent rule.** Any Phase 2+ PR touching AetherLink, OAS, AletheiaFS, cognitive
file-system sidecars, WeightBlock manifests, or SpaceX-facing application
materials must cite this source and include an AetherLink/OAS check: addressed
object, UAS kind, floor state, promotion contract, verifier, ledger event,
model role, falsifier, and rollback.

## 0D. 2026-05-30 Candidate Intake — Erdos / Parameter Golf / Construction Engine

**New candidate-intake source:** `docs/fusion/AETHERLINK_ERDOS_PARAMETER_GOLF_INTAKE_2026_05_30.md`.

**Non-runtime audit companion:** `docs/audits/NON_RUNTIME_FEATURE_WORKTREE_CHECK_2026_05_30.md`.

**Why it exists.** Live research intake found that the Erdos unit-distance
ecosystem is currently small and mostly reproduction/explanation/formalization,
while Parameter Golf is the large runnable fork ecosystem. Therefore agents
should mine Erdos for the lift/search/project/witness doctrine and Parameter
Golf for the reproducible compression/search discipline.

**Canonical build implication.** Do not launch more heavy 128K/70B probes until
the non-executing planner layer exists: bounded `WeightBlockManifest` range
hash -> `ResidencyPlan` -> `LargeModelConstructionCard` -> local
budget/falsifier gate. This keeps the no-compromise 70B/UAS/ColdStore ambition alive
without crashing the laptop.

**First planner witness.** `F-ResidencyPlan-DryRun` now emits
`artifacts/falsifiers/residency_plan_dry_run/result.json`: a dry-run
model-shaped plan with `72 GiB` cold addressed bytes, `872,415,232` active
runtime bytes, zero model bytes loaded, deterministic plan address, Sherry /
Leech codec labels, and missing-rollback rejection. Scope guard: this is not
live 70B inference.

**Safe hardening.** The planner layer now includes bounded 64 KiB chunked range
hashing, known-hash manifests for externally precomputed model byte ranges, and
`F-WeightBlockRangeHash-DryRun`, which proves over-limit range rejection,
short-reader rejection, known-hash parity, and no model-file access on a tiny
fixture. `ConstructionCard` binds ProblemCard / LiftChart / ProjectionPacket /
Witness / Budget / Falsifier / Rollback to a passed `ResidencyPlan` and records
the upstream `F-WeightBlockRangeHash-DryRun` -> `F-ResidencyPlan-DryRun` proof
chain.
`ProviderReferenceManifest` now guards the next bottleneck by requiring row-root
artifact refs, sha256 digests, replay permission, local-vs-hosted
retention/data-class discipline, prompt-suite digest binding, retained replay
files that exist and match their declared hashes, and an evidence scope that
distinguishes `shape_only_fixture` from `prompt_level_comparison` before a
fp16/cloud/local reference can count. Prompt-level references also require at
least 50 prompts.
The 70B preflight consumes the range-hash artifact as
`weight_block_range_hash_dry_run_available=true`, then the planner artifact as
`residency_plan_dry_run_available=true`, and remains red research evidence
until prompt-level comparison evidence exists. That provider-reference lane is
not the default architecture cursor while the app is routed through practical
MLX local inference. `F-ProviderReferencePromptLevel-Readiness` still audits the
exact blocker when the heavy/provider-reference lane is explicitly re-enabled;
shape-only fixtures remain barred from satisfying prompt-level reference
evidence.

**Agent rule.** Any Phase 2+ PR or terminal invoking Erdos, Parameter Golf,
Research Construction Engine, ShadowProjection, OAS, ColdStore, AcsAnchor, or the 70B local
cocktail must include a Construction check: ProblemCard, LiftChart,
ProjectionPacket, Witness, Budget, Falsifier, Rollback, ProductBuild, and
ProStatus/ResidencyStatus.

---

## 0E. 2026-05-30 Namespace Patch — ColdStore Versus ACS

**New drift-control source:** `docs/audits/ACS_NAMESPACE_RECONCILIATION_2026_05_30.md`.

**Correction.** Do not abbreviate Active Cold Storage as ACS. Use
**ColdStore** or **Cold Residency Layer** for the dormant-but-addressable
memory/model substrate: note atoms, graph islands, vector pages, KV pages,
model shards, adapters, rank-one components, parameter anchors, and circuit
candidates that stay cold until selected.

**ACS namespace.** Existing `AcsAnchor` / `AcsAnchorRegistry` / F-ACS anchor
lookup source truth remains the Anchored Cognitive Substrate coordinate and
provenance lineage. Legacy ACS/Kuramoto cellular resonance is renamed forward
to **KuramotoSync** / **ResonanceSync**, a Pro Research phase/coherence
candidate under ActiveAssembly. Admission/verdict behavior is named SCOPE-Rex
Admission, SovereignGate, or AdmissionGate; older `acs_admission` paths are
migration debt.

**Correct flow.**

```text
User intent
  -> Intent Intake / MissionPacket classifies the task
  -> OAS/UAS resolves what exists and where it lives
  -> ColdStore / ResidencyGovernor surfaces cold candidates
  -> ActiveAssembly selects the waking set
  -> Eidos pre-validates candidate evidence
  -> SCOPE-Rex / SovereignGate admits the mission and route
  -> Runtime Router chooses local model / MLX / Apple Intelligence / tool / kernel
  -> Executor runs under policy
  -> Eidos post-validates output, citations, and mutations
  -> SCOPE-Rex / SovereignGate admits or rejects user-impacting mutations
  -> RunEventLog + AnswerPacket make it visible
```

Short doctrine: Intent -> Address -> Awaken -> Assemble -> Verify -> Govern ->
Execute -> Verify -> Witness. SCOPE-Rex/SovereignGate wraps the whole mission
and must gate cloud calls, external tools, shell actions, file writes, memory
updates, and durable mutations rather than appearing only at the end.

**Agent rule.** Future work must use UAS as the primitive identity fabric and
ColdStore for Active Cold Storage. EML is one elementary-function chart inside
the substrate, not the substrate identity primitive. Any stale doc using ACS
for cold residency, admission, KV spill, or ActiveAssembly is superseded by
this namespace patch for future naming.

---

## 0F. 2026-05-30 Namespace Patch — Helios As Lineage, Not A Spine Step

**Builder-facing source:** `docs/audits/AGENT_MANAGEABLE_ARCHITECTURE_CANON_2026_05_30.md`.

**Correction.** Helios is the substrate-runtime research lineage underneath
Epistemos, not an operational step in the live product spine. The operational
spine remains:

```text
Intent -> Address -> Awaken -> Assemble -> Verify -> Govern -> Execute -> Verify -> Witness
```

When a doc says "Helios does X", agents must translate it into the concrete
organ before editing or claiming progress:

| Legacy/umbrella phrasing | Concrete organ |
|---|---|
| Helios memory hierarchy | ColdStore / ResidencyGovernor / WBO |
| Helios kernels | RuntimeRouter-owned Metal/kernel routes and ActiveAssembly mechanisms |
| Helios WBO / lattice doctrine | LatticeBudget / compression accounting |
| Helios SCOPE-Rex lineage | SCOPE-Rex verifier / ClaimGraph / WitnessedState |
| Helios model tracks | local model runtime candidates behind gates |
| Helios scanner language | AetherLink / OAS candidate language |

**Agent rule.** Do not add a product step called Helios. Product truth should
name the concrete wired organ, caller chain, gate, test/falsifier, and visible
surface. Helios can remain the research umbrella only if the product claim uses
the actual organ names.

---

## 0G. 2026-05-31 Build/Tier Supersession — MAS + Pro With Internal Pro Bands

**Builder-facing source:** `docs/audits/AGENT_MANAGEABLE_ARCHITECTURE_CANON_2026_05_30.md`.

**Correction.** Epistemos has exactly two distributable builds:

1. **MAS Build** - App Store-safe public floor.
2. **Pro Build** - direct-distribution power build.

There is no separate Research build and no separate Vault build. Research,
Vault, Omega, heavy runtime, future substrate work, old ambitious mechanisms,
and speculative theorems are internal Pro statuses, not app builds.

**Pro internal status bands.**

| Pro status | Meaning |
|---|---|
| Pro Live | Advanced feature is implemented, visible, tested, and safe for Pro users. |
| Pro Gated | Implemented or partial, behind explicit opt-in, rollback, warning, or policy. |
| Pro Research | Promising/runnable/document-backed; requires falsifier evidence before promotion. |
| Pro Vault-Preserved | Preserved ambition, branch, theorem, or mechanism with no runtime authority. |
| Pro Omega | Deepest private experimental substrate work; never silently enabled, never MAS-bound, always witnessed and reversible. |

**Supersession rule.** New docs should not describe "five lanes, three tiers"
as the distributable architecture. Use "two builds plus Pro internal tier
ladder." Historical branch text can keep older names when describing what the
branch was called at the time, but active planning must declare ProductBuild
and ProStatus/ResidencyStatus.

**Nested map.**

```text
Epistemos
  -> MAS Build: public safe floor
  -> Pro Build
     -> Pro Live
     -> Pro Gated
     -> Pro Research
     -> Pro Vault-Preserved
     -> Pro Omega
  -> substrate organs
     -> UAS/OAS/AcsAnchor
     -> ColdStore/ResidencyGovernor
     -> ActiveAssembly
     -> Eidos/VaultRecall/Halo/Shadow
     -> SCOPE-Rex/SovereignGate
     -> RuntimeRouter/System G
     -> WBO/LatticeBudget/Primitive IR
     -> RunEventLog/MutationEnvelope/AnswerPacket
```

## 0H. 2026-05-31 Research / AI Intake Discipline

**Builder-facing source:** `docs/audits/AGENT_MANAGEABLE_ARCHITECTURE_CANON_2026_05_30.md`.

**Correction.** Generated syntheses, donor docs, papers, forum claims, and
research metaphors are useful intake, but they are not architecture authority by
themselves. Agents must extract implementation motifs into existing organs:

| Research motif | Route through |
|---|---|
| semantic search, source grounding, reranking, citations | Eidos / VaultRecall / Halo / Shadow |
| retry logic, tool persistence, self-correction | System G / RuntimeRouter / RunEventLog / AnswerPacket |
| adapters, KV pages, experts, rank-one components, model internals | Parameter Connectome / ColdStore with UAS, WBO, verifier, rollback |
| EML or primitive math | Primitive IR chart work with Lean/schema/falsifier witnesses |
| unverifiable terms or broad metaphors | Pro Research or Pro Vault-Preserved until sourced and falsified |

**EML lock.** EML is one elementary-function/proof chart inside the Primitive
IR stack. It is not the substrate identity primitive, not the retrieval engine,
not a runtime router, and not a product proof of physics or intelligence.

**Agent rule.** Before turning research into code, declare the organ, motion,
ProductBuild, ProStatus/ResidencyStatus, witness, source/falsifier, and
rollback. If the source was not verified from local code/logs or a primary
source, mark it as intake/unverified.

---

## 0I. 2026-05-31 Frontier Local Reasoning On 16 GB

**New candidate-canon source:** `docs/fusion/FRONTIER_LOCAL_REASONING_16GB_ARCHITECTURE_2026_05_31.md`.

**Correction.** Do not frame the 16 GB target as "resident trillion-parameter
frontier model." The supported architecture is:

> **Cold trillion, hot five billion, active minimum.**

The system may preserve a huge cold atlas of model blocks, adapters, KV pages,
evidence, notes, graph islands, theorem artifacts, and tool plans, but only the
smallest sufficient working set is hot. SSD/mmap remains slower than RAM; the
win is predictive active-support scheduling, not pretending storage latency
vanishes.

**Architecture impact.** The local model is not the whole intelligence. A
small always-hot controller routes over UAS/OAS, ColdStore, ActiveAssembly,
KV/state pages, adapter banks, verifier tools, Eidos, and SCOPE-Rex. Reasoning
quality comes from retrieval, verifier-guided search, repair, and continual
specialization as much as from resident parameter count.

**New candidate law.** `L9-Candidate: Cold-Atlas Working-Set Law`:
capability on 16 GB hardware scales with the quality of the selected working
set, verifier loop, and residency policy more than with simultaneously
resident parameter count.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-ColdAtlas-WorkingSet` | Measures total-addressable vs hot-resident vs active-executed bytes, peak RSS, baseline win, and rollback. |
| `F-KV-State-First` | Proves KV/state compression or paging improves long-context throughput or capacity at equal quality/WBO. |
| `F-Adapter-Growth-Loop` | Proves accepted repairs can become versioned adapter artifacts without silent base-model mutation. |

**Agent rule.** Any Phase 2+ PR touching "frontier local reasoning," 70B,
1T, MoE, MLA, KV compression, adapter banks, fast weights, or local reasoning
quality must cite this source and declare: active bytes, hot bytes, cold bytes,
KV bytes, runtime/app overhead, verifier stack, fallback, and rollback.

---

## 0J. 2026-05-31 Neural Importance Routing Atlas

**New candidate-canon source:** `docs/fusion/NEURAL_IMPORTANCE_ROUTING_ATLAS_2026_05_31.md`.

**Why it exists.** The 16 GB architecture needs a way to decide which
parameters, heads, MLP blocks, adapter slices, KV pages, evidence packets,
kernels, and verifiers are worth waking for each task. Static saliency alone
is not enough.

**New candidate law.** `L10-Candidate: Counterfactual Utility Law`:
a neural unit should be hot only when its expected verifier-improving marginal
utility is greater than its memory, latency, drift, and interference cost.

**Architecture impact.** Epistemos gets a `NeuralImportanceAtlas` plus
`ActivationSketch`, `ParamRouteCard`, `HotRentLedger`, and
`InterferenceLedger`. This reframes "better than MoE" as whole-substrate
support routing: not just which expert processes a token, but which complete
support set makes the task correct under the hardware budget.

**Apple Silicon split.** ANE/Core ML is a compiled scout/router/classifier
lane. Metal/MLX is the custom KV, PageGather, block-scan, quantized matmul, and
weight-page lane. Rust owns residency scheduling, UAS addresses, and zero-copy
discipline. Lean owns route-card schemas, theorem statuses, and proof artifacts
outside the latency-critical token path.

**Storage split.** The candidate storage primitive is `AppColdStore`: durable
model snapshots, packed weight pages, adapter banks, KV seeds, route cards, and
manifests live in Epistemos-managed Application Support / App Group storage;
only regenerable warm packs live in purgeable caches. The claim is better
layout/locality/prewarm/copy control, not faster SSD physics.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-NeuralImportanceAtlas` | Proves the atlas beats random/static saliency active sets under the same memory budget. |
| `F-ActiveSet-Utility` | Measures verifier score per active hot byte against naive/dense local baselines. |
| `F-KV-Importance-Parity` | Proves KV page retention/eviction preserves recall/citation/reasoning outcomes under WBO. |
| `F-AppleSilicon-RouteSplit` | Proves ANE scout + Rust scheduler + MLX/Metal execution beats simpler local baselines after dispatch/copy overhead. |
| `F-AppColdStore-Layout` | Proves app-owned packed storage beats raw snapshot layout while preserving checksum/WBO/rebuild guarantees. |

**Agent rule.** Any Phase 2+ PR touching important weights, parameter
selection, adapter routing, KV eviction, ANE scouting, Apple hardware routing,
AppColdStore layout, or "better than MoE" claims must cite this source and
declare: selected unit, importance signal, active/hot/cold bytes, Apple lane,
storage tier, verifier, fallback, rollback, and interference risk.

---

## 0K. 2026-05-31 Eidos Neural Importance Bridge

**New candidate-canon source:** `docs/fusion/EIDOS_NEURAL_IMPORTANCE_BRIDGE_2026_05_31.md`.

**Why it exists.** Eidos is the evidence selector. The new bridge makes Eidos
also produce route priors for model-state selection: evidence hits,
`why_matched`, citation need, domain tags, contradiction hints, and likely
verifier families can guide the `NeuralImportanceAtlas` before any neural unit
wakes.

**Architecture impact.**

```text
EidosContextPacket
  -> EidosRoutePrior
  -> TaskSignatureEmbedding
  -> NeuralImportanceAtlas lookup
  -> ParamRouteCard / AppColdStoreRouteCard
  -> ActiveAssembly support set
  -> RuntimeRouter execution
```

This is the route by which search/semantic lookup upgrades the local model
substrate. Notes, graph hits, KV pages, adapters, weight blocks, tools, and
kernels all remain UAS-addressed substrate objects. The app owns route
selection; the model does not silently choose its own hidden brain.

**Dynamic compute checkpoints.** The bridge admits early exit,
self-speculation, depth-budget gates, KV restore, adapter swap, Eidos
interrupt, verifier repair, and helper-SSM controller checkpoints only as
visible `RunEventLog` events. No hidden mid-kernel pause, silent retry, or
durable model mutation is allowed.

**Research handles.** The current intake map points to Deja Vu, PowerInfer,
Apple `LLM in a Flash`, H2O, Quest, SparQ Attention, MInference, LayerSkip,
Mixture-of-Depths, Mamba-2, and Titans as buildable mechanism sources. They
are not product proof until local falsifiers pass.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-Eidos-NeuralRoute-Prior` | Proves Eidos-derived route priors beat random/task-label/embedding-only priors for adapter/KV/weight-page support prediction. |
| `F-ParamRouteCard-Admission` | Proves neural route cards bind UAS addresses, active bytes, verifier stack, rollback, ProductBuild, ProStatus, and witness before units wake. |
| `F-DynamicCompute-Checkpoint` | Proves early exit/self-speculation/depth gating/Eidos interrupts improve quality-cost and are visible in RunEventLog. |
| `F-Eidos-PostValidation-Repair` | Proves bounded retries improve citation/schema/test validity without latency spirals or hidden mutation. |

**Agent rule.** Any PR touching Eidos search, embeddings, route priors,
dynamic compute, helper SSMs, parameter routing, KV page selection, adapter
swaps, or "the app can pick the right region of the LLM brain" must cite this
source and declare: Eidos evidence source, selected neural unit family, UAS
address, active bytes, checkpoint event, verifier, fallback, rollback, and
visible surface.

---

## 0K.1. 2026-06-01 External Formal-Math / Lean Company Intake

**New candidate-canon source:** `docs/fusion/FORMAL_MATH_COMPANY_AND_LEAN_INTAKE_2026_06_01.md`.

**Why it exists.** Chrome/X bookmark intake and web validation found the
current formal-math company pattern around Axiom, Axiomatic AI, OProver,
UlamAI, Harmonic, and Math Inc: construction search, Lean/kernel verification,
proof-pressure feedback, refactor/golf/repair, and human-readable publication
or replayable proof artifacts.

**Architecture impact.** This does not create a new top-level math organ. The
route is:

```text
ProblemCard
  -> ConstructionGraph
  -> EidosRoutePrior
  -> NeuralImportanceAtlas / ActiveAssembly
  -> LeanProofRouteCard or ConstructionSearchRouteCard
  -> SCOPE-Rex / SovereignGate
  -> RunEventLog + AnswerPacket
```

External handles include Axiom AXLE/Axplorer/AxiomProver, Axiomatic AI
Ax-Prover/AxProverBase, OProver, UlamAI, Harmonic Aristotle/IMO2025, Math Inc
Gauss/OpenGauss, LeanSearch, Pantograph, lean4-skills, Neuronpedia, and
Goodfire. Public code is source-mined for
motifs only until a license/setup/vendor PR and local tests exist.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-FormalMath-SourceIntake` | Proves source cards store URL, license/usage note, digest, credibility, and product status without overclaiming. |
| `F-LeanProof-RouteCard` | Proves a proof route binds theorem, environment, route, timeout, rollback, artifact, and AnswerPacket witness. |
| `F-ConstructionSearch-Loop` | Proves bounded construction search improves against random/static baselines with replay and budget accounting. |
| `F-Eidos-FormalMath-Prior` | Proves Eidos selects Lean/proof/construction verifier families better than static or embedding-only baselines. |
| `F-FeatureAtlas-Prior` | Proves SAE/feature handles can be route priors without arbitrary neuron-control claims. |
| `F-ProofPressureSignal` | Proves compiler feedback and failed-attempt memory become explicit route labels without hidden authority. |
| `F-AxiomAxiomatic-SourceDistinction` | Proves Axiom, Axiomatic AI, OProver, Harmonic, UlamAI, and Math Inc motifs remain distinct source classes. |

**Agent rule.** Any PR touching Lean, formal proof, construction search,
Axplorer/PatternBoost, Axiomatic AI/Ax-Prover/OProver proof pressure, UlamAI,
AxiomProver/AXLE, Harmonic Aristotle, Gauss, OpenGauss, LeanSearch, Pantograph,
mechanistic feature atlases, or "best LLM brain region" routing must cite this
source and declare: source card, problem card, route card, verifier, active
bytes if model-state routing is involved, fallback, rollback, and visible
AnswerPacket witness.

---

## 0K.2. 2026-06-01 Meta-Breakthrough Control Surfaces

**New candidate-canon source:** `docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md`.

**Why it exists.** The research pattern behind Lean/proof execution,
mechanistic interpretability, KV-cache paging, and multi-model routing is not a
single giant breakthrough. It is a set of small control surfaces that compound:
route cards, premise cards, feature cards, KV page cards, brain route cards,
and verifier-regret ledgers.

**Architecture impact.** "Control of neurons" now has a product definition:
address, observe, select, intervene, measure, and roll back a bounded
model-state unit. Anything less is a route prior, not a control claim.

The fused route is:

```text
Intent
  -> MissionPacket
  -> Eidos evidence and PremiseGraph retrieval
  -> TaskSignatureEmbedding
  -> BrainRouteCard
  -> NeuralImportanceAtlas
  -> ProofCarryingRouteCard / ParamRouteCard / KVPageControlCard
  -> ActiveAssembly minimal support set
  -> SCOPE-Rex / SovereignGate admission
  -> RuntimeRouter execution
  -> verifier / Lean / tests / citation checks
  -> RunEventLog + AnswerPacket
  -> VerifierRegretLedger update
```

**External handles.** This source validates against LeanSearch, Pantograph,
Rust-to-Lean/Aeneas/hax, Verus/Kani, RouteLLM, FrugalGPT, Mixture-of-Agents,
LLM-Blender, Anthropic/Goodfire/Neuronpedia/SAELens/TransformerLens/NNsight,
PagedAttention/vLLM, H2O, Quest, StreamingLLM, SnapKV, PyramidKV, KIVI, and
MInference.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-MetaBreakthrough-CardRegistry` | PASS metadata-only witness on 2026-06-03. Proves every meta-control card binds UAS address, source, budget, rollback, proof/falsifier state, AnswerPacket visibility, and shadow-only route authority before future route policy can cite it. Artifact: `artifacts/falsifiers/meta_breakthrough_card_registry/result.json`. |
| `F-ProofCarryingRouteCard` | PASS metadata-only witness on 2026-06-03. Proves route cards reject missing preconditions, missing postconditions, missing rollback, missing artifact refs, unpinned proof/toolchain versions, missing AnswerPacket refs, budget increases, and hidden live mutations. Artifact: `artifacts/falsifiers/proof_carrying_route_card/result.json`. |
| `F-RustRouteKernel-ModelCheck` | Checks bounded route-state and unsafe/FFI invariants with Kani/Verus/Aeneas/hax-style routes where appropriate. |
| `F-BrainRouteCard-MultiModel` | Proves learned/task-shaped routing beats static routing on quality, evidence validity, latency, and active-byte cost. |
| `F-KVPageControl-QueryAware` | Proves query-aware page selection beats recency-only and random page policies under active-byte and quality budgets. |
| `F-FeatureAtlas-Prior` | Proves feature handles improve route selection as priors without arbitrary neuron-control claims. |
| `F-NeuralControlCard-Ablation` | Proves a bounded feature/activation intervention improves target behavior versus baseline and ablation without unacceptable side effects. |
| `F-VerifierRegretLedger` | Proves route utility updates change later route selection and reduce verifier regret over a held-out prompt/task set. |

**Agent rule.** Any PR touching proof-carrying execution, model routing,
multiple brains, feature atlases, activation steering, embeddings as route
priors, KV/page selection, adapter swapping, dynamic depth, helper SSMs, or
"best LLM brain region" claims must cite this source and declare: control card
kind, addressed unit, source/evidence, budget, verifier, selection or
intervention action, baseline, rollback, falsifier, and AnswerPacket surface.

---

## 0K.3. 2026-06-01 Constructive Residency Paradigm

**New candidate-canon source:** `docs/fusion/CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01.md`.

**Why it exists.** Recursive Chrome/X bookmark intake plus primary web
validation found a shared pattern across Axplorer/PatternBoost, Lattice
Deduction Transformers, SwiftLM, Letta stateful agents, PowerInfer, Apple LLM
in a Flash, vLLM/PagedAttention, LMCache, KTransformers, and Qwen3.6 preserve
thinking: the breakthrough is not a bigger resident blob. It is better
construction of the right resident support set.

**Architecture impact.** The 70B cocktail is now defined as a
proof-carrying `ColdAssemblyPlan` over UAS/AppColdStore, not as SSD-as-RAM or
an always-hot dense model. UAS names the bytes. AppColdStore controls layout.
ActiveAssembly wakes the smallest sufficient support set. Eidos, Lean/tests,
SCOPE-Rex/SovereignGate, RunEventLog, and AnswerPacket keep it honest.

The fused residency route is:

```text
MissionPacket
  -> Eidos evidence + TaskSignature
  -> ResidencyConstructionGraph
  -> CoactivationTile / ReasoningStateContinuityCard candidates
  -> ColdAssemblyPlan
  -> ProofCarryingResidencyLease
  -> ActiveAssembly + NeuralImportanceAtlas
  -> SCOPE-Rex / SovereignGate
  -> RuntimeRouter
  -> RunEventLog + AnswerPacket
  -> ColdMissLedger update
```

**New primitive set.** `ResidencyConstructionGraph`, `CoactivationTile`,
`ColdAssemblyPlan`, `LatticeStateController`, `ProofCarryingResidencyLease`,
`ReasoningStateContinuityCard`, and `ColdMissLedger`.

**Backlog falsifier bundle:** `docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md`.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-ResidencyConstructionGraph` | PASS metadata-only dry-run witness on 2026-06-03. Proves candidate assemblies can be scored under memory/I/O/verifier constraints and invalid plans are rejected. Artifact: `artifacts/falsifiers/residency_construction_graph/result.json`. |
| `F-CoactivationTile-Prefetch` | PASS metadata-only dry-run witness on 2026-06-03. Proves tile packing and prefetch beat original file order or random page fetch under cold-miss and latency budgets. Artifact: `artifacts/falsifiers/coactivation_tile_prefetch/result.json`. |
| `F-ProofCarryingResidencyLease` | PASS metadata-only dry-run witness on 2026-06-03. Proves no cold byte wakes without UAS address, reason, byte cost, verifier/proof reference, expiry, fallback, and rollback. Artifact: `artifacts/falsifiers/proof_carrying_residency_lease/result.json`. |
| `F-ColdAssemblyPlan-70B-Lite` | PASS metadata-only dry-run witness on 2026-06-03. Proves a small-hot plus cold-selected assembly beats dense-local, RAG-only, and static-route baselines without hidden cloud, dense-resident overclaim, or runtime/model-byte load. Artifact: `artifacts/falsifiers/cold_assembly_plan_70b_lite/result.json`. |
| `F-LatticeStateController` | PASS metadata-only witness on 2026-06-03. Proves a small recurrent/lattice controller improves route decisions versus static, random, and always-retrieve baselines; abstains under high uncertainty/conflict; rejects hidden live route authority, hidden-chain exposure, missing rollback, missing AnswerPacket, and unbeaten static-policy baselines. Artifact: `artifacts/falsifiers/lattice_state_controller/result.json`. |
| `F-ReasoningStateContinuity` | PASS metadata-only witness on 2026-06-03. Proves visible, privacy-scoped resumable state improves continuity/cache utility versus no-state, naive-cache, and static-summary baselines; rejects hidden-chain exposure, verifier bypass, stale-state reuse, missing purge policy, incompatible compatibility fence, missing AnswerPacket, and unbeaten naive-cache baselines. Artifact: `artifacts/falsifiers/reasoning_state_continuity/result.json`. |
| `F-ColdMissLedger` | PASS metadata-only witness on 2026-06-03. Proves repeated route-level cold misses bind missed UAS units, stall/cold-I/O costs, fallback, verifier delta, next prefetch policy, rollback, run log, AnswerPacket, and a shadow ColdRoutePolicyPatch; held-out misses and repeated stalls improve while one-miss, no-improvement, missing rollback, missing policy patch, zero-stall, high-wear, and live-mutation cases reject. Artifact: `artifacts/falsifiers/cold_miss_ledger/result.json`. |
| `F-SwiftLM-SourceIntake` | PASS metadata-only witness on 2026-06-03. Proves SwiftLM SSD expert streaming, KV compression, persistent-buffer, and prefetch motifs are captured as source cards with license/setup notes, benchmark caveats, route affinities, and local test plans before any implementation import, product dependency, route mutation, or model-byte load. Artifact: `artifacts/falsifiers/swiftlm_source_intake/result.json`. |

**Agent rule.** Any PR touching UAS, AppColdStore, ColdStore layout, 70B
cocktail, model page selection, MoE/expert streaming, KV continuity,
Letta-style stateful memory, LDT-style controllers, SwiftLM source mining, or
"SSD brain" claims must cite this source and declare: source card,
active/cold bytes, assembly plan, lease, verifier, cold-miss policy, fallback,
rollback, falsifier, and AnswerPacket surface.

---

## 0K.4. 2026-06-01 Cache-Lineage Autoresearch Paradigm

**New candidate-canon source:** `docs/fusion/CACHE_LINEAGE_AUTORESEARCH_PARADIGM_2026_06_01.md`.

**Why it exists.** A second recursive Chrome/X bookmark pass found a useful
cluster around persistent KV, tiered RAM/SSD cache, DeepSeek-style context
caching, oMLX/TurboQuant motifs, browser trace capture, Karpathy-style
autoresearch, and GEPA-style Pareto prompt evolution. Primary validation came
from oMLX, TurboQuant, Tutti, KVDrive/Swarm, AWS managed tiered KV cache,
DeepSeek context caching/V4 preview docs, Browserbase skills, Karpathy
autoresearch, and GEPA.

**Architecture impact.** Constructive residency decides what should wake.
Cache-lineage autoresearch decides what state, prefix, trace, and route
evidence should survive so the next assembly is cheaper, more continuous, and
more correct. KV/prefix caches, prompt-cache units, execution traces, browser
traces, profiler traces, and route outcomes are now UAS-addressed substrate
objects with lineage, compatibility fences, privacy class, purge policy,
admission cards, rollback, and AnswerPacket visibility when they affect a user
answer.

The fused cache-lineage route is:

```text
MissionPacket
  -> Eidos evidence + TaskSignature
  -> PrefixReuseRouter
  -> KVLineageGraph / KVCompatibilityFence
  -> CacheAdmissionCard
  -> ResidencyConstructionGraph
  -> ColdAssemblyPlan / ProofCarryingResidencyLease
  -> RuntimeRouter
  -> ExecutionTraceCapsule
  -> ParetoResidencyTournament
  -> CacheMutationPatch
  -> RunEventLog + AnswerPacket
```

**New primitive set.** `KVPrefixUnit`, `KVLineageGraph`,
`KVCompatibilityFence`, `CacheAdmissionCard`, `ExecutionTraceCapsule`,
`ParetoResidencyTournament`, `CacheMutationPatch`, `PrefixReuseRouter`, and
`TraceToPlanLearner`.

**Backlog falsifier bundle:** `docs/falsifiers/F-CACHE-LINEAGE-AUTORESEARCH-BUNDLE_2026_06_01.md`.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-KVPrefixUnit-Lineage` | Proves prefix/KV units bind model, tokenizer, adapter set, prompt digest, token range, codec, privacy, purge, and byte accounting. |
| `F-KVCompatibilityFence` | Proves incompatible or stale cache units are rejected with named reasons before restore. |
| `F-PrefixReuseRouter` | Proves compatible prefix reuse beats repeated prefill and naive reuse on latency, active bytes, and correctness. |
| `F-CacheAdmissionCard` | Proves persist/compress/evict/purge decisions account for reuse, privacy, storage wear, rollback, and byte cost. |
| `F-PersistentKV-ParkResume` | Proves parked compatible KV/prefix state can resume without exposing hidden chain-of-thought. |
| `F-ExecutionTraceCapsule` | Proves app/browser/runtime traces are captured with redaction, integrity, and replayable failure signatures. |
| `F-ParetoResidencyTournament` | Proves trace-derived policies are selected by Pareto metrics, not one greedy score. |
| `F-CacheMutationPatch-Rollback` | Proves every prompt/cache/layout/route mutation has baseline, patch, ablation, held-out result, rollback, and promotion status. |
| `F-TraceToPlanLearner` | Proves slow/failing traces create bounded candidate plans without mutating production policy directly. |
| `F-CacheLineage-NoPoison` | Proves privacy, stale-source, prompt-injection, and incompatible-cache cases cannot promote reusable state. |

**Agent rule.** Any PR touching persistent KV, prefix caching, context caching,
cache reuse, AppColdStore cache admission, execution/browser traces, CDP/DOM
trace intake, autoresearch, GEPA-style prompt/policy evolution, MLX overnight
research, oMLX/TurboQuant motifs, or DeepSeek-style context caching must cite
this source and declare: source card, UAS address, compatibility fence, privacy
class, purge policy, admission card, baseline, patch/ablation when relevant,
rollback, falsifier, RunEventLog, and AnswerPacket surface.

---

## 0K.5. 2026-06-01 Math And Portable Note Systems Intake

**New candidate-canon source:** `docs/fusion/MATH_AND_PORTABLE_NOTE_SYSTEMS_INTAKE_2026_06_01.md`.

**Why it exists.** User direction asked for more beneficial math and portable
note/editor systems that could be ported or source-mined, including
Tolaria-style Markdown vaults and Tauri/non-Tauri markdown apps. Primary
validation covered Tolaria, Noteriv, Lumark, ProseMirror, Tiptap, Milkdown,
CodeMirror, Lexical, Tree-sitter, Yjs/y-crdt, Automerge, Differential
Dataflow, Datafrog, FSRS, semantic entropy, PICARD, HNSW, and information
bottleneck/rate-distortion.

**Architecture impact.** The live macOS app remains Swift/AppKit/TextKit
Opulent. The portable breakthrough is mathematical: editor transactions
compose, derived views update by delta, CRDT merges need witnesses, backlinks
and graph views should be maintained incrementally, parse trees should update
by changed ranges, note resurfacing should follow a memory model, structured
model output should be parsed while decoding, and lossy sidecars/projections
must pay rate-distortion budget.

The fused note-system route is:

```text
Editor edit / external file change
  -> EditorDeltaMonoid
  -> ReadableProjectionFunctor
  -> IncrementalParseForest
  -> DifferentialKnowledgeView
  -> GitVaultLineage / DeltaSemilatticeSync where needed
  -> RetentionPotentialField
  -> SemanticEntropyGate / ConstrainedMutationDecode for AI edits
  -> RunEventLog + AnswerPacket
```

**New primitive set.** `EditorDeltaMonoid`, `ReadableProjectionFunctor`,
`DeltaSemilatticeSync`, `DifferentialKnowledgeView`,
`IncrementalParseForest`, `RetentionPotentialField`, `SemanticEntropyGate`,
`ConstrainedMutationDecode`, `GitVaultLineage`, `FrontmatterTypeLens`, and
`RateDistortionSidecarBudget`.

**Backlog falsifier bundle:** `docs/falsifiers/F-MATH-NOTE-SYSTEMS-PORTABILITY-BUNDLE_2026_06_01.md`.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-EditorDeltaMonoid` | Proves editor transactions compose, preserve selection/scroll metadata, and carry undo inverse or reason absent. |
| `F-ProjectionFunctor-Digest` | Proves derived Markdown/search/plain/graph views bind source digest, projection version, loss budget, and output digest. |
| `F-MarkdownSidecar-Portability` | Proves notes remain readable as Markdown with additive sidecars and no proprietary-only required data. |
| `F-IncrementalParseForest` | Proves parse updates touch only changed ranges under long-note and rapid-edit fixtures. |
| `F-DifferentialKnowledgeView` | Proves backlinks/graph/review projections update by delta and beat full rebuild under held-out changes. |
| `F-CRDTVaultConflict` | Proves concurrent edits merge or emit conflict witnesses without silent data loss. |
| `F-GitVaultLineage` | Proves file/frontmatter/body/sidecar changes bind to commit history and restore refs. |
| `F-FSRSNoteReview` | Proves note/concept resurfacing improves recall or usefulness versus recency-only and random surfacing. |
| `F-SemanticEntropyGate` | Proves high semantic uncertainty routes to abstain/verify rather than unsupported confidence. |
| `F-ConstrainedMutationDecode` | Proves model-authored edits/tool args are accepted only when incremental parse/schema checks pass. |
| `F-LicensePortabilityGate` | Proves repo motifs are classified as importable, source-mine-only, or rejected before any code import. |

**Agent rule.** Any PR touching note editor architecture, Markdown vault
portability, `.epdoc` projection, sidecars, ProseMirror/Tiptap/Milkdown/
CodeMirror/Lexical motifs, Tree-sitter parsing, CRDT/local-first sync, Git
vault history, FSRS review, Datalog/differential graph views, semantic entropy,
constrained decoding, or repo code import must cite this source and declare:
source of truth, transaction/delta model, projection digest, loss budget,
license status, latency budget, rollback, falsifier, RunEventLog, and
AnswerPacket surface.

---

## 0K.6. 2026-06-01 Engineering Logic Architecture Intake

**New candidate-canon source:** `docs/fusion/ENGINEERING_LOGIC_ARCHITECTURE_INTAKE_2026_06_01.md`.

**Why it exists.** User direction asked to emphasize engineering logic so the
architecture can keep its ambition while becoming easier for current and
future agents to assist. The missing layer was not another organ. It was a
builder grammar for turning any ambitious mechanism into invariants,
contracts, state machines, budgets, failure envelopes, observability probes,
rollback, and falsifiers.

**Architecture impact.** Before a mechanism governs live behavior, mutates
user data, wakes cold model state, imports source code, or makes a product
claim, it must pass through:

```text
Architecture idea / bug / research motif / PR
  -> DecisionRecord
  -> InvariantLedger
  -> StateMachineCard or BoundaryContract
  -> BudgetVector and HotPathProofCard
  -> FailureEnvelope and ObservabilityProbe
  -> MigrationRail or ImportGateCard when needed
  -> falsifier artifact
  -> RunEventLog + AnswerPacket when user-visible
```

**New candidate law.** `L14-Candidate: Engineering Logic Law`: a mechanism may
enter the architecture only when its invariant, owner, state transition,
budget, failure mode, witness, and rollback are explicit.

**New primitive set.** `DecisionRecord`, `InvariantLedger`,
`StateMachineCard`, `BoundaryContract`, `BudgetVector`, `HotPathProofCard`,
`FailureEnvelope`, `ObservabilityProbe`, `MigrationRail`, `ImportGateCard`,
and `SimplicityBudget`.

**Backlog falsifier bundle:** `docs/falsifiers/F-ENGINEERING-LOGIC-ARCHITECTURE-BUNDLE_2026_06_01.md`.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-DecisionRecord-Completeness` | Proves a change names the problem, chosen option, rejected options, constraints, affected organs, source refs, falsifier refs, and rollback. |
| `F-InvariantLedger-Completeness` | Proves owner organ, source of truth, preconditions, postconditions, forbidden states, witness, and falsifier exist. |
| `F-StateMachineCard-TransitionSafety` | Proves allowed, forbidden, terminal, and rollback transitions are finite and guarded. |
| `F-BoundaryContract-SendableOwnership` | Proves actor, FFI, model, storage, or tool boundaries declare ownership, sendability/thread rule, cancellation, backpressure, error type, and privacy. |
| `F-BudgetVector-HotPath` | Proves hot-path claims carry latency, active bytes, cold bytes, copy count, allocations, actor hops, disk I/O, and verifier cost where relevant. |
| `F-FailureEnvelope-Rollback` | Proves known failures have detection, visibility, retry/fallback, data-loss classification, and rollback before mutation. |
| `F-ObservabilityProbe-Threshold` | Proves each important claim has a metric, log, signpost, artifact, or AnswerPacket field with pass/fail threshold. |
| `F-ImportGateCard-LicenseSetup` | Proves external source motifs pass license/setup/dependency/security/maintenance classification before import. |
| `F-SimplicityBudget-NoIndirection` | Proves added complexity buys reduced duplication, value, performance, or testability without wrapper drift. |
| `F-EngineeringLogic-NoHiddenAuthority` | Proves new components route through existing organs and visible proof surfaces. |

**Agent rule.** Any PR touching architecture decisions, subsystem boundaries,
state machines, invariants, performance budgets, concurrency, migration,
source imports, hot paths, rollback, observability, or new services/managers
must cite this source and declare: owner organ, invariant, state transition or
boundary contract, BudgetVector, FailureEnvelope, ObservabilityProbe,
rollback, falsifier, and AnswerPacket/RunEventLog surface when user-visible.

---

## 0K.7. 2026-06-01 Semantic Working-Set Compiler

**New candidate-canon source:** `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`.

**Why it exists.** A deeper browser/bookmark/X pass and primary-source
validation found the missing bridge across Denning working sets,
PagedAttention/vLLM, LMCache, DeepSeek context caching, FlexGen, PowerInfer,
KTransformers, KIVI, Karpathy autoresearch, Kimi CLI, ResearchRabbit,
Consensus, NotebookLM, Lean/Mathlib, and DeepSeek-Prover: UAS/AppColdStore
becomes plausible when each mission compiles to a predicted semantic working
set, not when SSD is treated as RAM.

**Architecture impact.** The 70B cocktail is now shaped by:

```text
TaskSignature
  + SourceSignalGraph
  + EidosRoutePrior
  + KVLineageGraph
  + NeuralImportanceAtlas
  + ResidencyConstructionGraph
  -> SemanticWorkingSetPlan
  -> ResidencyPageTable
  -> PrefetchWindow
  -> RuntimeRouter execution
  -> ColdFaultTrace
  -> LayoutPatch / RoutePatch
```

This preserves the no-compromise target while making the mechanism concrete:
source/bookmark traces rank motifs, Eidos selects evidence, cache lineage
offers reusable prefixes, NeuralImportanceAtlas proposes useful units,
constructive residency admits the assembly, and the working-set compiler emits
the page table and prefetch window. Cold misses are not merely I/O failures;
they are failed predictions that must update future layout and routing.

**New candidate law.** `L15-Candidate: Semantic Working-Set Law`: a cold
cognitive atlas becomes useful only when each mission compiles to a predicted,
budgeted, prefetchable, observable working set whose misses update future
layout and routing.

**New primitive set.** `SourceSignalGraph`, `TaskWorkingSetQuery`,
`SemanticWorkingSetPlan`, `ResidencyPageTable`, `PrefetchWindow`,
`WorkingSetOracleCard`, `ColdFaultTrace`, `LayoutPatch`,
`MmapResidencyFence`, `KVByteBudgetCard`, and `SourceToResidencyPatch`.

**Backlog falsifier bundle:** `docs/falsifiers/F-SEMANTIC-WORKING-SET-COMPILER-BUNDLE_2026_06_01.md`.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-SourceSignalGraph-Intake` | Proves bookmark/repo/paper/X sources become source cards with digest, credibility, license/usage note, privacy, and no-poison status. |
| `F-TaskWorkingSetQuery-Determinism` | Proves the same mission emits the same bounded query, privacy class, and budget. |
| `F-SemanticWorkingSetPlan-Budget` | Proves over-budget hot/KV/cold-I/O selections are rejected before execution. |
| `F-ResidencyPageTable-Addressability` | Proves every selected unit binds UAS address, byte range, tier, checksum, codec, and compatibility fence. |
| `F-PrefetchWindow-ColdMiss` | Proves compiled prefetch beats random, recency, and file-order baselines. |
| `F-ColdFaultTrace-Learning` | Proves cold misses create bounded layout/route patches and improve held-out routes. |
| `F-MmapResidencyFence-CopyCount` | Proves mmap, touching, resident estimate, faults, and copy count are not conflated. |
| `F-KVByteBudgetCard` | Proves KV bytes, hit/miss tokens, codec, and quality caveat are reported separately from weight bytes. |
| `F-WorkingSetOracle-Baseline` | Proves the oracle beats simple baselines or abstains. |
| `F-SourceToResidency-NoPoison` | Proves poison, stale, private, corrupted, and license-blocked sources cannot promote residency patches. |
| `F-70B-Cocktail-WorkingSet-Lite` | Proves a small-hot compiled plan beats dense-local, RAG-only, and static-route baselines without hidden cloud or dense-resident overclaim. |

**Agent rule.** Any PR touching semantic working sets, UAS/AppColdStore,
active cold storage, 70B cocktail, mmap residency, prefetch, page tables,
KV-byte accounting, source/bookmark/research trace routing, cache-derived
layout patches, or "SSD brain" claims must cite this source and declare:
source signal, working-set query, selected units, active/hot/warm/cold/KV
bytes, residency page table, prefetch window, compatibility fence, cold-fault
policy, fallback, rollback, falsifier, RunEventLog, and AnswerPacket surface.

---

## 0K.8. 2026-06-01 Substrate Trace Observatory

**New candidate-canon source:** `docs/fusion/SUBSTRATE_TRACE_OBSERVATORY_2026_06_01.md`.

**Why it exists.** The deeper Chrome/Arc/X bookmark pass surfaced a second
cluster distinct from residency itself: LLM visualizations, transformer
explainers, Data Processing Club arithmetic/sorting analyses, ThePrimeagen/99,
Kimi Code/Kimi CLI, ResearchRabbit/Consensus/NotebookLM, and X KV-cache
threads. Primary validation against OpenTelemetry, Langfuse, Phoenix,
mechanistic arithmetic work, computational-graph reasoning verification, and
low-rank logit structure shows the missing organ: Epistemos must make each
selected substrate unit visible, replayable, comparable, and diagnosable.

**Architecture impact.** The 70B cocktail and active cold storage are now
debuggable only through a trace microscope:

```text
MissionPacket
  -> Eidos / SourceSignalGraph
  -> SemanticWorkingSetPlan
  -> ResidencyPageTable / PrefetchWindow
  -> RuntimeRouter / System G
  -> model, cache, verifier, tool, editor, browser, graph events
  -> CognitiveTraceGraph
  -> RouteMicroscopeFrame / VisualProofCapsule
  -> TelemetryToWorkingSetPatch
  -> SCOPE-Rex / SovereignGate promotion
  -> RunEventLog + AnswerPacket
```

The observatory does not become a new router. It proves what woke, why it woke,
what it cost, whether it helped, what failed, and what patch may be considered
next. It also keeps visualization honest: visual proof is route/evidence/span
visibility, not hidden chain-of-thought exposure.

**New candidate law.** `L16-Candidate: Observable Substrate Law`: a local
cognitive substrate becomes engineerable only when every selected source, page,
cache, model route, tool action, proof lane, and failure mode emits a
replayable trace frame dense enough for a human or agent to debug.

**New primitive set.** `CognitiveTraceGraph`, `RouteMicroscopeFrame`,
`AttentionKVTrace`, `AlgorithmicFailureProbe`, `HeuristicNeuronCard`,
`SourceReasoningOverlay`, `AgentActionFrame`, `TraceComparisonDeck`,
`TelemetryToWorkingSetPatch`, `VisualProofCapsule`, and `HumanDebugHandle`.

**Backlog falsifier bundle:** `docs/falsifiers/F-SUBSTRATE-TRACE-OBSERVATORY-BUNDLE_2026_06_01.md`.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-CognitiveTraceGraph-Completeness` | Proves a mission trace contains required span classes or explicit waivers. |
| `F-RouteMicroscopeFrame-Replay` | Proves a visible frame can reopen the underlying span, selected unit, budget, latency, reason, and answer ref. |
| `F-AttentionKVTrace-ByteBinding` | Proves KV bytes, hit/miss tokens, codec, compatibility, and caveat are separate from weight bytes. |
| `F-AlgorithmicFailureProbe` | Proves arithmetic/sorting/task probes distinguish correct, incorrect, heuristic, and abstain cases on fixtures. |
| `F-HeuristicNeuronCard-Ablation` | Proves claimed neuron/feature handles carry hook identity, fixture, ablation delta, caveat, and privacy class. |
| `F-AgentActionFrame-ToolReplay` | Proves tool/editor/browser/shell actions have capability scope, side-effect class, cancellation, and rollback. |
| `F-SourceReasoningOverlay-Citation` | Proves cited, unsupported, and contradicted claims trace back to source and retrieval/rerank spans. |
| `F-TraceComparisonDeck-Regression` | Proves route/prompt/cache/layout candidates compare against baselines on quality, evidence, verifier, bytes, latency, and failures. |
| `F-TelemetryToWorkingSetPatch` | Proves trace-derived patches name diagnosed layer, patch type, expected delta, held-out fixture, rollback, and promotion gate. |
| `F-VisualProofCapsule-AnswerPacket` | Proves visible-proof answers link route frames, source overlays, verifier refs, KV traces, cold faults, and user-visible limits. |
| `F-TracePrivacyRedaction` | Proves private bookmark, browser, note, prompt, credential, and account data are redacted or local-only before durable research use. |
| `F-ObservableSubstrate-NoHiddenAuthority` | Proves the observatory cannot wake bytes, mutate policy, or override SCOPE-Rex/SovereignGate. |

**Agent rule.** Any PR touching trace observability, LLM visualization,
attention/KV visualization, mechanistic probes, heuristic neurons, model-route
debugging, agent action replay, source-grounded research UI, visual proof,
cold-fault diagnosis, or trace-derived policy/layout patches must cite this
source and declare trace schema, privacy/redaction class, replay fixture,
diagnosed layer, rollback, falsifier, RunEventLog, and AnswerPacket surface.

---

## 0K.9. 2026-06-01 Verifier-Calibrated Sparse Route Compiler

**New candidate-canon source:** `docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md`.

**Why it exists.** X bookmark intake surfaced the Axiom/Axplorer thread around
PatternBoost, sparse encodings, construction search, and the
sample/improve/keep-winners loop. Primary validation against Axplorer,
PatternBoost, Axiom AXLE, Axiomatic AI AxProver, OProver, UlamAI, Harmonic
Aristotle, OpenGauss, RouteLLM, Quest, SparQ, MInference, DejaVu, PowerInfer,
LayerSkip, Mixture-of-Depths, Titans, TTT, and Mamba-2 sharpens the
route-selection claim: the breakthrough is not waking more model. It is waking
the smallest verified route with a cheap scout, using proof pressure and
full-wake/oracle traces to distill better scout labels, and letting tests,
proofs, citations, and traces teach only bounded route policy.

**Architecture impact.** This is the bridge between Axiom-style construction
loops and Epistemos model-state routing:

```text
TaskSignature
  + SourceSignalGraph
  + proof/citation/code/test need
  + query vector
  + cache lineage
  + trace history
  -> TwoStageRouteScout / RouteScoutSSM
  -> BudgetedUncertaintyEscalator
  -> SparseWakeProposal
  -> VerifierBudgetAuction
  -> LayerKVJointLease
  -> SemanticWorkingSetPlan
  -> RuntimeRouter / ActiveAssembly
  -> verifier/test/citation/trace result
  -> FastWeightQuarantine
  -> VerifierRegretFastWeights
  -> updated scout priors
```

The compiler does not become a hidden router. Eidos, NeuralImportanceAtlas,
SemanticWorkingSetPlan, ActiveAssembly, SCOPE-Rex/SovereignGate, RunEventLog,
and AnswerPacket remain the authority path.

**New candidate law.** `L17-Candidate: Verifier-Calibrated Sparse Wake Law`: a
substrate unit should wake only when a small scout predicts that its expected
verified marginal utility exceeds hot-byte, KV-byte, latency, interference,
and rollback cost, and the prediction improves under trace-backed verifier
regret.

**New primitive set.** `RouteScoutSSM`, `TwoStageRouteScout`,
`BudgetedUncertaintyEscalator`, `SparseWakeProposal`,
`VerifierBudgetAuction`, `KVPageSketchIndex`, `KVPageBloomSketch`,
`QueryAwareKVSelector`, `LayerKVJointLease`, `ConstructionSearchTournament`,
`RouteDistillationTournament`, `ProofSearchSignal`, `ProofPressureSignal`,
`VerifierRegretFastWeights`, `FastWeightQuarantine`, `DepthLease`,
`ShadowWakeOracle`, `AblationShadowRun`, and `SparseWakeCertificate`.

**Backlog falsifier bundle:** `docs/falsifiers/F-VERIFIER-CALIBRATED-SPARSE-ROUTE-BUNDLE_2026_06_01.md`.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-RouteScoutSSM-Baseline` | Proves a small scout predicts route family/verifier need better than static, random, recency, and embedding-only baselines. |
| `F-TwoStageRouteScout-Abstain` | Proves route-family choice and family-specific selection are separate, cheap, and abstention-capable. |
| `F-BudgetedUncertaintyEscalator` | Proves high uncertainty or budget exhaustion escalates instead of choosing a cheap wrong route. |
| `F-SparseWakeProposal-Budget` | Proves wake proposals name selected/rejected units, expected hot/KV/cold bytes, fallback, uncertainty, and verifier need. |
| `F-VerifierBudgetAuction` | Proves candidate units compete under a budget and over-budget bundles are rejected before execution. |
| `F-KVPageSketchIndex` | Proves page sketches bind UAS address, byte count, compatibility fence, sketches/tags, hits, misses, and privacy class. |
| `F-KVPageBloomSketch-Coverage` | Proves cheap page filters do not drop required proof/citation evidence under the declared coverage target. |
| `F-QueryAwareKVSelector` | Proves query-aware page selection beats random, recency-only, and file-order baselines on held-out long-context fixtures. |
| `F-LayerKVJointLease` | Proves dynamic depth and KV/page choice are leased together with error and fallback accounting. |
| `F-ConstructionSearchTournament` | Proves PatternBoost/Axplorer-style generate-repair-score-select improves sparse wake plans over random generation under fixed budget. |
| `F-RouteDistillationTournament` | Proves expensive full/proof/oracle traces improve the small scout on held-out route choices. |
| `F-ProofSearchSignal-RouteFeedback` | Proves Lean/proof outcomes become route features without becoming hidden truth or bypassing AnswerPacket. |
| `F-ProofPressureSignal` | Proves compiler errors, missing premises, tactic-state entropy, and failed attempt memory become explicit route-pressure labels. |
| `F-VerifierRegretFastWeights` | Proves fast-weight updates are bounded, local, resettable, TTL-limited, and useful on held-out route choices. |
| `F-FastWeightQuarantine` | Proves fast-weight deltas remain shadow-only until drift, held-out, rollback, TTL, and AnswerPacket gates pass. |
| `F-DepthLease-Checkpoint` | Proves dynamic-depth choices declare shallow exit, deeper wake, verifier margin, maximum extra layers, and full-depth fallback. |
| `F-ShadowWakeOracle` | Proves full-wake/proof/test oracle traces provide labels without becoming a live runtime dependency. |
| `F-AblationShadowRun` | Proves claimed useful units survive counterfactual remove-one-unit comparison. |
| `F-SparseWakeCertificate-AnswerPacket` | Proves sparse route answers expose selected units, budgets, verifier/citation/test results, traces, uncertainty, fallback, and rollback. |
| `F-AxiomAxiomatic-SourceDistinction` | Proves Axiom, Axiomatic AI, Harmonic, UlamAI, and Math Inc motifs stay source-distinct instead of being blurred into one authority. |
| `F-SparseRoute-NoHiddenAuthority` | Proves the compiler cannot wake bytes, mutate policy, consolidate fast weights, or override SCOPE-Rex/SovereignGate alone. |

**Agent rule.** Any PR touching Axiom/Axplorer/PatternBoost, Axiomatic
AI/AxProver/OProver, proof construction loops, proof-pressure labels, sparse
attention, query-aware KV, RouteLLM-style routing, DejaVu/PowerInfer-style
contextual sparsity, LayerSkip/Mixture-of-Depths, Titans/TTT fast weights,
Mamba/SSM route scouts, route-distillation tournaments, dynamic depth, or
"proper weights/KV/neurons/params for the task" must cite this source and
declare: source signal, scout input, selected and rejected units, budget vector,
uncertainty/abstention rule, verifier need, expected hot/KV/cold bytes,
fallback, rollback, falsifier, RunEventLog, and AnswerPacket surface.

---

## 0K.10. 2026-06-01 ColdStream Residency Transport

**New candidate-canon source:** `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`.

**Why it exists.** User direction asked for a better-than-mmap architecture if
SSD/page faults become the bottleneck. Primary validation against Apple
`mmap(2)`, `fcntl(2)`, file-system performance guidance, Dispatch I/O, Metal
resource loading, and 2026 Metal feature tables shows the right distinction:
`mmap` is useful addressability and fallback. It is not a route-aware
token-critical scheduler.

**Architecture impact.** ColdStream is an invented Epistemos transport layer:
an app-owned page-run conveyor that moves predicted cold bytes into leased
CPU/Metal/MLX-ready slabs before decode, proof, search, or render needs them.

```text
SemanticWorkingSetPlan
  -> ResidencyPageTable
  -> TransportRunManifest
  -> PageRunScheduler
  -> DispatchIO / pread / Metal IO lane
  -> CodecStage
  -> SlabLease / MetalBufferLease
  -> RuntimeRouter / ActiveAssembly
  -> TransportTrace
  -> RunEventLog + AnswerPacket
```

ColdStream does not deny UAS. It makes UAS more physical: every range,
destination, codec, checksum, copy, stall, cancellation, fallback, and caveat
is explicit.

**New candidate law.** `L18-Candidate: Explicit Residency Transport Law`: a
cold substrate route becomes token-safe only when its predicted cold bytes
move through explicit, measured, cancelable transport into leased execution
buffers before they can block the hot path.

**New primitive set.** `TransportRunManifest`, `PageRun`,
`PageRunScheduler`, `SlabArena`, `MetalBufferLease`, `CodecStage`,
`TransportTrace`, and `ColdPanicFallback`.

**Backlog falsifier bundle:** `docs/falsifiers/F-COLDSTREAM-RESIDENCY-TRANSPORT-BUNDLE_2026_06_01.md`.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-TransportRunManifest-Completeness` | Proves every run names byte ranges, codec, checksum, destination, priority, lease, fallback, and cancellation group. |
| `F-PageRun-Coalescing` | Proves coalescing reduces read amplification without reading too many useless bytes. |
| `F-ColdStream-vs-Mmap` | Proves ColdStream beats mmap-fault and naive read baselines on p95/p99 stall and read amplification. |
| `F-SlabArena-CopyCount` | Proves CPU slabs preallocate buffers and report actual copies with no per-token allocation spikes. |
| `F-MetalIO-FeatureGate` | Proves Metal I/O is platform-gated and falls back to CPU slabs with visible caveat. |
| `F-CodecStage-Latency` | Proves decompression/conversion latency and copies are measured separately from file read time. |
| `F-TransportCancellation` | Proves route changes cancel obsolete in-flight reads and reject stale slabs. |
| `F-CachePolicy-Pollution` | Proves cache policy is measured against repeated hot-route performance. |
| `F-ColdPanicFallback` | Proves missed deadlines degrade visibly instead of blocking token-time execution silently. |
| `F-TransportTrace-AnswerPacket` | Proves cold-transport-dependent answers link to bytes, stalls, copies, fallback, and caveats. |
| `F-SSD-WearBudget` | Proves repeated transport plans report read/write volume and reject over-budget wear or energy loops. |
| `F-ColdStream-NoHiddenAuthority` | Proves transport cannot wake bytes or change route policy without SemanticWorkingSetPlan, admission, and rollback. |

**Agent rule.** Any PR touching mmap, AppColdStore transport, SSD hot paths,
page faults, cold I/O, prefetch windows, Metal I/O, Dispatch I/O,
file-backed KV/model pages, page-run packing, copy-count claims, or any claim
that UAS/AppColdStore can move cold model material fast enough for reasoning
must cite this source and declare: transport manifest, selected byte ranges,
destination lease, cache policy, copy count, stall metric, fallback,
rollback, falsifier, RunEventLog, and AnswerPacket surface.

---

## 0K.11. 2026-06-01 Mmap Replacement and Hot-Path Cure Atlas

**New candidate-canon source:** `docs/fusion/MMAP_REPLACEMENT_AND_HOTPATH_CURE_ATLAS_2026_06_01.md`.

**Why it exists.** User direction clarified that zero-copy must cure backend,
compute, transport, model/KV, proof, trace, search, and artifact hot paths
without deleting intentional product copies for multiple graph/editor surfaces,
visual variants, undo safety, previews, snapshots, or user-visible artifacts.
Primary validation against Apple mmap/file-I/O/Metal docs, Rust `memmap2`,
`zerocopy`, `bytemuck`, `bytes`, Lean/Rust verification tools, sparse
attention, and Hilbert locality work sharpens the rule: mmap is an address
view, not the hidden control plane for token-time execution.

**Architecture impact.** The new doctrine is **Copy-Causal Geometry**:
represent hot paths as typed graphs of byte movement, ownership, state
transition, and proof obligations; then reorder layout and execution so the
verified working set moves through contiguous page runs, preallocated slabs,
shared Metal/Rust rings, packet streams, or binary witness records instead of
surprise page faults, JSON hot loops, per-frame rebuilds, or unmeasured copies.
Second-pass lock: **Geometry-Aligned Execution** keeps `mmap` for simple
addressability and baselines, fences it where residency or truncation could be
overclaimed, and replaces it only when the route already knows byte ranges,
deadline, codec, destination, cancellation group, fallback, copy budget, and
proof boundary.

**New candidate law.** `L19-Candidate: Copy-Causal Geometry Law`: a hot path
becomes substrate-grade only when its copies, allocations, faults, actor hops,
layout transforms, and proof obligations are explicit enough to be reordered,
bounded, measured, or waived.

**New primitive set.** `IntentionalCopyWaiver`, `CopyClass`,
`MmapKeepVsReplace`, `GeometricPageRunPlanner`,
`GraphNodeStateRingPromotion`, `HotTraceBinarySummary`,
`EventRingActivationCard`, `CopyCausalGraph`, `LayoutObjective`, and
`ProofHarnessCard`, plus second-pass execution primitives:
`HotPathCensus`, `MmapHazardFence`, `ReadPlanMatrix`,
`GeometryAlignedPageTable`, `CopyBudgetVector`, `UnsafeBoundaryProofCard`,
`ShmMaterializationWaiver`, `StreamFrameArena`, `SpatialDirtyWindow`, and
`ProtocolEdgeJsonWaiver`.

**Backlog falsifier bundle:** `docs/falsifiers/F-MMAP-REPLACEMENT-HOTPATH-CURE-BUNDLE_2026_06_01.md`.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-HotPathCopyScope-IntentionalCopyWaiver` | Proves zero-copy claims classify copies and preserve intentional UI/editor/artifact copies. |
| `F-HotPathCensus-Coverage` | Proves a cure starts from a census of file, mmap, SHM, cache, JSON, string, actor, FFI, Metal/GPU, and UI-surface movement. |
| `F-MmapKeepVsReplace` | Proves mmap is kept only where it beats or matches explicit read/slab alternatives under the right workload. |
| `F-MmapHazardFence-Truncation` | Proves mapped routes separate alignment, size, mutation/truncation risk, cache policy, mapped/touched/resident/fault/copied bytes. |
| `F-ReadPlanMatrix-Coalescing` | Proves explicit read/slab/SHM/Metal candidates beat the right baseline before replacing mmap. |
| `F-PageRunGeometry-Locality` | Proves block/Morton/Hilbert/coactivation ordering beats submitted scatter on selected fixtures. |
| `F-GeometryAlignedPageTable-Affinity` | Proves semantic/page/cache/GPU/proof adjacency improves locality without breaking order or ownership. |
| `F-CopyBudgetVector-Enforced` | Proves copy bytes, allocation bytes, actor hops, materializations, and waivers fail closed when over budget. |
| `F-ShmMaterializationWaiver` | Proves POSIX SHM or mmap readback materialization is explicit, measured, owned, and cleaned up. |
| `F-GraphNodeStateRing-NoLegacyPositionFerry` | Proves the full NodeState shared ring removes redundant graph position ferry or proves position-only is better. |
| `F-EditorIncrementalParse-NoFullDocReparse` | Proves long-note edits avoid full-document reparse unless correctness requires it. |
| `F-VaultRecallHotTrace-NoJSON` | Proves active routing does not depend on JSON decode in a token/per-frame hot path. |
| `F-StreamFrameArena-CopyBound` | Proves long streams/traces can use chunk/rope/packet arenas without regressing final surface correctness. |
| `F-ProtocolEdgeJsonWaiver` | Proves JSON stays at protocol/UI/artifact edges and not as hidden internal active-route authority. |
| `F-EventRingActivation-NoPerEventAlloc` | Proves event-ring activation drains production event classes without per-event allocation. |
| `F-SpatialDirtyWindow` | Proves graph/editor dirty-window updates refine to the same result as full rebuild for affected regions. |
| `F-ProofHarness-RustLean-StateMachine` | Proves at least one route/slab/event state machine invariant with Lean/Verus/Kani/Aeneas-style tooling. |
| `F-CopyCausalGeometry-Ablation` | Proves the geometric schedule/layout itself caused the measured improvement. |
| `F-NoHiddenZeroCopyOverreach` | Proves docs and AnswerPackets do not imply intentional product copies are forbidden or mmap equals residency. |

**Agent rule.** Any PR touching mmap replacement, SSD hot paths, cold I/O,
copy-count claims, "zero-copy" wording, graph render/physics state movement,
PageGather/KV page transport, Rust/Swift/Metal FFI records, hot JSON traces,
streaming buffers, note-editor performance, or lattice/geometric execution
alignment must cite this source and declare: copy class, hot-path owner,
baseline, candidate cure, measured copy/allocation/stall budget, intentional
copy waiver when relevant, proof harness or reason it is not proof-suitable,
fallback, rollback, falsifier, RunEventLog, and AnswerPacket caveat.

---

## 0K.12. 2026-06-01 Residency PatternBoost Discovery

**New candidate-canon source:** `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`.

**Why it exists.** A fresh read-only X bookmark pass surfaced the AxiomProver
publication thread, Lattice Deduction Transformers, Axplorer/PatternBoost, and
nearby lattice/SageMath source signals. Primary validation against Axplorer,
PatternBoost, Lattice Deduction Transformers, UlamAI, Letta, PagedAttention,
LMCache, PowerInfer, Apple LLM in a Flash, and MInference sharpens the next
plausibility bridge: Epistemos should not discover the right resident assembly
from scratch during live token-time execution. It should run offline or idle
construction tournaments over UAS-addressed assembly genomes, repair invalid
candidates, sparsely fingerprint them, keep held-out winners, and distill the
winners into small route/layout policies.

**Architecture impact.** This adds an offline discovery layer above the
working-set compiler, sparse wake compiler, ColdStream, and Copy-Causal
Geometry:

```text
SourceSignalGraph
  + CacheLineageGraph
  + ColdFaultTrace
  + proof/test/citation failures
  + successful full-wake or shadow routes
  -> AssemblyCandidatePool
  -> ConstraintRepairKernel
  -> SparseAssemblyFingerprint
  -> AssemblyTournamentTrace
  -> EliteAssemblyArchive
  -> ResidencyPatternDistiller
  -> ColdRoutePolicyPatch
  -> RouteScoutSSM / SemanticWorkingSetPlan
```

The 70B cocktail becomes more plausible as a library of proven resident
assembly motifs, not a dense model claimed hot in RAM. UAS makes bytes
addressable and comparable; Residency PatternBoost amortizes search and layout
learning before the live path wakes expensive model material.

**New candidate law.** `L20-Candidate: Pattern-Boosted Residency Law`: a cold
cognitive atlas becomes practically usable when high-utility resident
assemblies are searched, repaired, sparsely fingerprinted, verified, archived,
and distilled into reusable route and layout policies before live execution.

**New primitive set.** `ResidencyPatternBoost`, `AssemblyCandidatePool`,
`UASAssemblyGenome`, `ConstraintRepairKernel`, `SparseAssemblyFingerprint`,
`EliteAssemblyArchive`, `AssemblyTournamentTrace`,
`ResidencyPatternDistiller`, `LatticeAbstentionGate`, `ComputeResumeLease`,
and `ColdRoutePolicyPatch`.

**Backlog falsifier bundle:** `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`.

**Drift sweep:** `docs/audits/RESIDENCY_PATTERNBOOST_DRIFT_SWEEP_2026_06_01.md`
records the exhaustive prompt/canon/research-reference sweep and classifies
remaining older local-model, mmap, ACS, AppColdStore, and 70B references as
provenance unless reactivated through this June 2026 canon.

**New falsifier targets.**

| Falsifier | Purpose |
|---|---|
| `F-AssemblyCandidatePool-Diversity` | Proves candidate generation creates diverse resident assembly genomes under fixed seed and mission family. |
| `F-UASAssemblyGenome-Determinism` | Proves a genome serializes selected units, transport, fallback, and rollback deterministically. |
| `F-ConstraintRepairKernel-Validity` | Proves invalid genomes are repaired or rejected before route admission. |
| `F-SparseAssemblyFingerprint-Collision` | Proves compact fingerprints cluster useful motifs without hiding too many distinct invalid assemblies. |
| `F-AssemblyTournamentTrace-Replay` | Proves generation, repair, scoring, selection, ablation, and distillation replay. |
| `F-EliteAssemblyArchive-HeldOut` | Proves elite assemblies improve held-out missions, not only source traces. |
| `F-ResidencyPatternDistiller-RouteWin` | Proves distilled features improve a small route scout or working-set plan. |
| `F-LatticeAbstentionGate-Soundness` | Proves wake/retrieve/continue/pause/resume/verify choices either improve declared state or abstain. |
| `F-ComputeResumeLease-Compatibility` | Proves pause/resume compute cannot corrupt KV, depth, verifier, or source state. |
| `F-ColdRoutePolicyPatch-Rollback` | Proves tournament-derived policy patches are scoped, reversible, and kill-switchable. |
| `F-PatternBoostedResidency-Ablation` | Proves repair, archive, fingerprinting, and distillation each contribute to held-out wins. |
| `F-70B-AssemblyPattern-Lite` | Proves the doctrine helps a 70B-cocktail-lite fixture without claiming dense 70B residency. |
| `F-NoOfflineOracleLeak` | Proves full-wake/proof-oracle labels remain training-only and do not become live hidden dependencies. |
| `F-ResidencyPatternBoost-NoHiddenAuthority` | Proves the loop cannot wake bytes, mutate live policy, bypass admission, or override RuntimeRouter alone. |

**Agent rule.** Any PR touching offline route search, resident assembly
selection, AppColdStore layout learning, 70B cocktail plausibility, UAS
assembly archives, route motif distillation, pause/resume compute, Lattice
Deduction Transformer intake, Axplorer/PatternBoost-style search, or "proper
weights/KV/neurons/params" selection must cite this source and declare:
candidate genome, generation seed, repair kernel, fingerprint,
verifier/test/citation score, byte budget, transport plan, held-out baseline,
distilled policy, rollback, falsifier, RunEventLog, and AnswerPacket surface.

---

## 0L. 2026-05-31 Full Architecture Continuation Prompt

**Reusable session prompt:** `docs/audits/FULL_ARCHITECTURE_CONTINUATION_PROMPT_2026_05_31.md`.

**Why it exists.** The architecture now has enough correct names that future
agents need one concise entry point for continuing full-stack work without
reintroducing drift.

**Locks carried by the prompt.**

- UAS remains the primitive identity fabric.
- MAS and Pro are the only distributable builds.
- ColdStore/AppColdStore is dormant/app-owned residency; `AcsAnchor` remains
  coordinate/provenance; SCOPE-Rex/SovereignGate owns admission.
- Eidos can emit `EidosRoutePrior` into `NeuralImportanceAtlas`, but no neural
  bytes wake without a route card and visible witness.
- Sparse wake decisions run through `RouteScoutSSM`, verifier budgets,
  query-aware KV/page selection, bounded fast weights, and
  `SparseWakeCertificate`; the main model does not choose hidden brain regions
  without proof.
- Cold model/page bytes run through explicit ColdStream-style transport
  manifests, leases, copy-count/stall traces, and fallbacks before claiming
  token-safe residency.
- The 16 GB direction preserves the ambition of a huge SSD/AppColdStore atlas
  while keeping the rigor rule that SSD is not RAM.
- Dynamic compute can only run through explicit checkpoints and RunEventLog
  visibility.

**Agent rule.** When continuing full architecture work, paste or read the
continuation prompt first, then verify current code truth and pick one small
buildable unit with falsifier-shaped verification.

---

## 1. Truth-Router and Authority Order

**Authority hierarchy (when sources disagree):**

| Order | Layer | Canonical files |
|---|---|---|
| 1 | Current code + passing logs | `git log`, test outputs, `/tmp/epistemos-*-test-*.log` |
| 2 | Repo authority docs | `/Users/jojo/Downloads/Epistemos/AGENTS.md`, `CLAUDE.md`, `docs/architecture/PLAN_V2.md`, `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md`, `docs/_consolidated/00_canonical_authority/{MASTER_FUSION, MASTER_BUILD_PLAN, RESEARCH_INDEX_BY_FEATURE, EDITOR_VERDICT_TIPTAP_VS_APPFLOWY, CODEX_VERIFIED_STATE_2026_04_25, MASTER_HARDENING_AND_HARNESS_PLAN, IMPLEMENTATION_PLAN_FROM_ADVICE, ANTI_DRIFT_SYSTEM, 00_AUTHORITY_AND_ANTI_DRIFT, 01_DOCTRINE, 02_BUILD_MATRIX, 03_EXECUTION_MAP, NEXT_SESSION_BOOTSTRAP, ambient_V1_DECISION}.md`, `docs/APP_ISSUES_AUTO_FIX.md`, `docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` |
| 3 | April 30 fusion canon | `docs/fusion/{README_START_HERE, CANONICAL_SOURCE_MAP_AND_GATE_REGISTER, BUILDER_EXECUTION_PROMPT, CODEX_ACTIVE_OVERSEER_KIMI_PROMPT, FUSED_IMPLEMENTATION_QUEUE, KIMI_*}_2026_04_30.md` + `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` |
| 4 | May 2 doctrine packet | `docs/fusion/{EPISTEMOS_FINAL_DOCTRINE_2026_05_01, CODEX_FINAL_EXECUTION_PROMPT_2026_05_01, WORKTREE_INSIGHT_SALVAGE_2026_05_02, CANON_GAPS_AND_ADDENDA_2026_05_02, CODEX_DELIBERATION_PROMPT_2026_05_02, ALL_DOCS_INDEX_2026_05_02, MASTER_RESEARCH_INDEX_2026_05_02}.md` |
| 4.25 | Jordan executive-add + V6.1 Foundation / V6.2 falsifier canon | `docs/fusion/JORDANS_RESEARCH_INDEX_2026_05_03.md`, `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md`, `docs/fusion/EPISTEMOS_V6_2_CANON_INTAKE_2026_05_07.md`, `docs/fusion/jordan's research/{helios v3.md, helios v6.2.md, mac store edition.md, hermes.md, deterministicapp.md, scope rex omega.md}` |
| 4.5 | Quick Capture standalone canon | `/Users/jojo/Documents/Epistemos-QuickCapture/{FINAL_SYNTHESIS, PLAN, OBSCURA_BROWSER_ADDENDUM, LIVE_FILES_AND_SUBSTRATE_ADDENDUM, BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM, INDEX, README, BUILDER_PROMPT, CATCHUP_PROMPT, AUDIT_PROMPT}.md` (FINAL_SYNTHESIS wins conflicts) |
| 5 | Kimi research depth (donor) | `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/` (88 files) |
| 5.5 | External research depth | `/Users/jojo/Downloads/{ambient, final, final v2, final v3, Advice}/`, `/Users/jojo/Downloads/Pasted markdown.md` |
| 6 | Worktree code | donor only, never raw-merge |

---

## 2. Substrate Spine and Architectural Invariants

### Substrate spine
**Canonical:** `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` — current code truth for every spine layer.

```
TypedArtifact → MutationEnvelope → RunEventLog / AgentEvent / GraphEvent → Halo / Graph / Theater / Audit projections
```

**Code anchors:**
- `Epistemos/Models/MutationEnvelope.swift` (Swift, includes `Sensitivity` enum line 88, field line 293)
- `agent_core/src/mutations/envelope.rs` (Rust mirror)
- `EpistemosTests/MutationEnvelopeParityTests.swift` (parity tests)
- `Epistemos/Engine/TextCapturePipeline.swift` (vertical slice)

### Architectural invariants (every tier)
**Canonical:** `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §2.2.

1. Zero-copy unified memory (Apple Silicon UMA, `MTLBuffer.storageModeShared`, IOSurface)
2. Single-binary in-process substrate (UniFFI hop pattern; subprocess for inference forbidden)
3. Markov blanket via Rust ownership (borrow checker = organizational closure)
4. Tiered determinism (state transitions logged + hashed, not every byte of inference)
5. (pending merge per `CANON_GAPS_AND_ADDENDA` C5) Canonical state is the only source of truth — visuals project, never invent

**Honest-handle FFI doctrine (canonical pattern):**
- `worktree:agent-a0550f9c/epistemos-shadow/src/honest_handle.rs` lines 73-100 — `Arc::into_raw` discipline + `panic::catch_unwind(AssertUnwindSafe(...))` panic safety
- `worktree:agent-a0550f9c/Epistemos/Engine/RustShadowFFIClient.swift` (clean 321-line consumer; but legacy line 39 still bound — see H7)

### Two-build ship model
**Supersedes older three-tier wording.** Active planning uses exactly two
distributable builds: `MAS` (App Store-safe public floor) and `Pro`
(Developer ID / direct distribution). Research, Vault, Omega, heavy runtime,
and private framework loading are internal Pro statuses or gates, not separate
app builds. Older branch/docs may still say `Core`/`Pro`/`Research` when they
describe the state of that historical branch; new work must declare
ProductBuild plus ProStatus/ResidencyStatus.

### WRV doctrine (Wired + Reachable + Visible + Verified)
**Status:** staged in `docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md` C1. Not yet in doctrine. Mentioned across `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md` ("init-time gate GREEN; 4k-line runtime fluidity unproven") and `docs/fusion/KIMI_FUSION_REVIEW_2026_04_30.md` ("recommended first three slices").

### Swift RRF Cross-Index Fusion
**Canonical:** `docs/RRF_FUSION_PROMPT.md` + `docs/RRF_FUSION_DESIGN.md` + `CLAUDE.md` "Swift RRF Cross-Index Fusion".

**Load-bearing claim:** "wire it into every site in the app where unified search is currently fragmented."

**Code anchors:**
- `Epistemos/Sync/RRFFusionQuery.swift` - feature flag, `FusionWeights`, `FusedResult`, single SQL query, metrics.
- `Epistemos/Sync/SearchIndexService.swift` - `fusedSearch(query:weights:now:)` and `fusedSearchAsync(query:weights:now:)`.
- `Epistemos/Sync/VaultSyncService.swift` - flag-aware `searchFull`, `searchFullAsync`, and `searchIndex`.
- `Epistemos/Engine/QueryRuntime.swift` - Phase 4 site 3, flag-aware `.all` full-text fused path for Epdoc slash menu / at-mention block-link autocomplete.
- `Epistemos/Models/QueryTypes.swift` - `.all` full-text reactive dependency includes `searchReadable`.
- `Epistemos/Sync/ReadableBlocksIndex.swift` - readable-block projection mutations publish `.searchReadable` invalidation.
- `EpistemosTests/RRFFusionQueryTests.swift` - k=60, bm25 sign, EXPLAIN plan, and SQL invariant tests.
- `EpistemosTests/SearchIndexServiceFusionTests.swift` - real file-backed DB fusion integration tests.
- `EpistemosTests/QueryRuntimeTests.swift` - QueryRuntime consumer guard tests.

**Build/status:** MAS by default when flag-off; Pro Gated / Pro Research /
dev-dogfood when `EPISTEMOS_RRF_FUSION_V1=1` until Phase 6 runtime dogfood
flips defaults.

**Search aliases:** RRF, fused search, cross-index fusion, Search Fusion Health, readable blocks, universal projection, Epdoc slash, at-mention autocomplete, block-link autocomplete, one SQL query, `EPISTEMOS_RRF_FUSION_V1`.

### SCOPE-Rex / Rex naming
**Canonical:** doctrine §4.1 Annex A.1. `Epistemos` = product, `Rex` = Rust kernel (`agent_core` becoming Rex), `SCOPE-Rex` = full runtime (Sparse-feature, Claim-graph, Ontology, Proof, Execution).

**Donor research:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/scope_rex_final_architecture.md` (definitive architecture, 31 research dimensions).

### Legacy ACS five-layer recursion
**Historical canonical source:** doctrine Annex A.4 (Cell → Tissue → Organ → Organism → Ecosystem with tier mapping).
**Current namespace status:** superseded for active naming by `docs/audits/ACS_NAMESPACE_RECONCILIATION_2026_05_30.md`. Do not use ACS for Active Cold Storage or admission in new work. Map legacy recursion/coherence language to KuramotoSync / ResonanceSync when it means phase/coherence research, to AcsAnchor when it means anchored coordinate/provenance, and to SCOPE-Rex/SovereignGate when it means admission.
**Donor research:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/acs_meta_layer.md`.

---

## 3. The Three Killer Features

### 3.1 Resonance Gate (Σ signature)
**Canonical:** doctrine §4.1.
**Donor research:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/epistemos_resonance_gate.md`.

7-field Σ signature: `Σ(x) = [τ truth, δ direction, π prime/composite/gap, ρ resonance, κ KAM, η evidence, λ residency]`. Target <100µs/token.

**Code dependencies (canonical sources Codex must import):**
| Σ component | Source |
|---|---|
| δ direction | `worktree:vigorous-goldberg-3a2d35/agent_core/src/capture/routing/` (Phases 3A–3F) — GBNF + centroid + canonicalizer |
| η evidence | `worktree:vigorous-goldberg-3a2d35/agent_core/src/heal/` — Try-Heal-Retry + 30-case eval |
| Provenance | `worktree:vigorous-goldberg-3a2d35/agent_core/src/effect/{dispatcher,receipt,*_applier}.rs` |
| Σ event taxonomy | `worktree:inspiring-heisenberg-ea9dc3/Epistemos/Engine/Log.swift` (`Log.agentStreaming` signposts) + `Bridge/StreamingDelegate.swift` |
| Σ batching | doctrine Annex A.2 (T0–T2 hot path) + `worktree:inspiring-heisenberg-ea9dc3/docs/architecture/PLAN_V2.md` §24 (16ms coalescing) |
| Audit trail | `worktree:simulation/agent_core/src/audit/origin.rs` (three-class AuditOrigin enum) |
| 9 claim types | doctrine §4.1: `Equation, Inequality, Causal, Definition, Empirical, CodeInvariant, Prime, Composite, Gap` |
| 5 directional operators | doctrine §4.1: `upward, downward, sideways, inward, on-itself` |

### 3.2 Sovereign Gate (Touch ID, biometric)
**Canonical:** doctrine §4.2 + Annex A.7.
**Donor research:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/EPISTEMOS_RESEARCH_LANDSLIDE.md` Part I §1.1 (LAContext snippet); `/Users/jojo/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` §1 (Wave 9 biometric authority via Secure Enclave).

**Action-class matrix:** Trivial / Reversible / Sensitive (15-min grace) / Destructive (every time + passcode) / Sovereign (every time + Secure Enclave seal). Current Rust seed: `agent_core/src/sovereign/mod.rs`; generated requirement transport remains open.

**Capability enum (Codex must import, do not redesign):**
- `worktree:vigorous-goldberg-3a2d35/agent_core/src/effect/receipt.rs` lines 44–54: `Capability::BiometricSession { ttl_secs }` ALREADY EXISTS as canonical type.

**Auth routes:** MacBook Touch ID + Magic Keyboard + iPhone-as-key + Apple Watch unlock — all native via `LocalAuthentication.LAContext`.

**Single entrypoint (must be):** `Epistemos/Sovereign/SovereignGate.swift` (new file). NEVER duplicate `LAContext` calls elsewhere.

### 3.3 Freeform Pulse + Residency Rail
**Canonical:** doctrine §4.3 + Annex A.3 (L0–L7 residency).
**Halo dependency:** doctrine §7 build-order; current state: V0 mounted, V1 awaiting protected-path gate.

**Code:** `Epistemos/Engine/HaloController.swift` (debounce machinery), `HaloEditorBridge.swift`, `ShadowSearchService.swift`.

**Halo V1 stack reference:** doctrine §4.3 (now in canon gaps C6) — 6-state FSM + Model2Vec + usearch + Tantivy + RRF + non-activating NSPanel + 25ms latency budget. Stack rationale at `docs/_consolidated/00_canonical_authority/ambient_V1_DECISION.md` and `docs/fusion/KIMI_FUSION_REVIEW_2026_04_30.md`.
**Donor research:** `/Users/jojo/Downloads/ambient/EPISTEMOS_V1_DECISION.md`, `/Users/jojo/Downloads/ambient/claude ambient.md` (THE implementation bible — 100+ code stubs, hard performance targets), `/Users/jojo/Downloads/ambient/HaloController.swift` (reference impl), `/Users/jojo/Downloads/ambient/epistemos_shadow.rs` (Rust retrieval engine).

---

## 4. Quick Capture / Substrate Runtime (50+ commits, 470 KB canon)

**Worktree:** `vigorous-goldberg-3a2d35`. **Standalone canon:** `/Users/jojo/Documents/Epistemos-QuickCapture/`.

### Reading order (Codex)
1. `/Users/jojo/Documents/Epistemos-QuickCapture/FINAL_SYNTHESIS.md` (52 KB, **wins all conflicts**) — 8 corrections, two breakthroughs (Live File Compiler + Reflective Loop), four-tier weight class system, 10-state machine, 7-layer privacy stack, corrected wave sequencing
2. `/Users/jojo/Documents/Epistemos-QuickCapture/PLAN.md` (244 KB, canonical for Waves 0–5 only)
3. Per-wave addendum (skip if not active wave):
   - `OBSCURA_BROWSER_ADDENDUM.md` (62 KB, Wave 6)
   - `LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` (67 KB, Waves 7–8)
   - `BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` (44 KB, Waves 9–11)

### Stay-stellar substrate (must salvage)
| Concept | Code anchor | Lines / structure |
|---|---|---|
| Tool trait + execute_v2 + 56 aliases | `worktree:vigorous-goldberg-3a2d35/agent_core/src/tools/registry.rs` | LEGACY_TO_V2_ALIASES table; ~54 conversions remaining |
| ExecutionReceipt + Capability enum | `worktree:vigorous-goldberg-3a2d35/agent_core/src/effect/receipt.rs` | ULID call_id, plan_hash, input_hash, output_hash, Ed25519 placeholder, Capability::{VaultPath, NetworkHost, BiometricSession, Other} |
| IntentDispatcher + sub-appliers | `…/agent_core/src/effect/{dispatcher, concept_applier, memory_applier, vault_applier}.rs` | Single entry routing intent → sub-applier; short-circuits noop/abort |
| Heal loop + Try-Heal-Retry + 30-case eval | `…/agent_core/src/heal/{mod.rs (29KB), log.rs (20KB), breaker.rs}` + `…/agent_core/src/bin/heal_eval.rs` | Diagnostician trait; circuit-breaker pattern; test fixtures embedded |
| Universal undo log + TTL classes | `…/agent_core/src/undo/mod.rs` (350 lines) | DEFAULT_TTL=24h; AUTO_RESEARCH_TTL=7d; lazy eviction; pre-computed inverse; WAL+synchronous=NORMAL |
| Semantic cache | `…/agent_core/src/cache/mod.rs` (350 lines) | Exact match (SHA256) + semantic (cosine ≥0.97 over N=256); per-tool TTL: capture=60s, search=5min, summarize=24h, default=60s |
| Capture routing classifier (GBNF + centroid + canonicalizer) | `…/agent_core/src/capture/routing/` Phases 3A-3F + `…/agent_core/src/format/capture.rs` | Variant A (centroid ≥0.85) → B (GBNF closed-vocab ≥0.75) → C (concept-anchored) → D (defer); intents: `place \| merge \| create_folder \| defer` |
| Concept canonicalizer | `…/agent_core/src/route/concept_alias.rs` | Deterministic; alias table |
| Skill discovery (Phase 12.5) | `…/agent_core/src/skill_discovery/mod.rs` | Three conditions (novel, ≤8s latency, no undo within 24h) + 4 repeats/week threshold + `proposed_skills/` drafts |
| BrowserEngine trait | `…/agent_core/src/browser_engine/mod.rs` (16KB) | WebKit (MAS) / Obscura (Pro experimental) / Mock (test) / Remote (fallback) — see OBSCURA_BROWSER_ADDENDUM.md for full design |
| NightBrain idle scheduler | `epistemos-core/src/scheduler/nightbrain.rs` (200 lines) | Every 30 min; eligibility = flagged notes + plugged in + no agent + 1–5 AM + ≥12h cooldown |
| Model Workspace Protocol | commit `a6683f8e` | Numbered folders + Markdown step files as filesystem-as-substrate state machine |

### New concepts from FINAL_SYNTHESIS.md (corrections to PLAN.md)
| Concept | Section | Description |
|---|---|---|
| **Live File Compiler** (BREAKTHROUGH) | §1 | Markdown → Parser → Intent → LivePlan.v1 (YAML) → Policy/Capability validation → Signed plan → Runner. The compiled, signed plan executes, NEVER the markdown. |
| **Reflective Loop** (NEW) | §2 | 7-layer substrate cycle: Reflex → Attention → Executive → Immune → Motor → Memory → Metabolism. Each layer has defined input/output/verification gate. Layer 7 (NightBrain) runs overnight against accumulated Layer 6 trace. |
| **Cognitive Weight class system** | §3 | 4-tier: `soft_memory [0–0.30]` / `preferred_context [0.31–0.60]` / `strong_project_anchor [0.61–0.85]` / `policy_grade [0.86–1.00]`. Only policy-grade can constrain tools, gated by schema + capability + diff + signed plan hash + revocation path. *"Semantic Gravity pulls attention; Policy Authority controls action."* |
| **10-state Live File state machine** | §4 | Static → LiveCandidate → Compiled → Eligible → Running → {Paused \| Completed \| Quarantined} → Suspended. Each is a different execution authority. |
| **Privacy stack (7 layers)** | §5 | Reflex (local cache) / Attention (Eidos in-process) / Executive (local compile) / Immune (deterministic local auth) / Motor (in-process/sandboxed browser) / Memory (encrypted RunEventLog) / Metabolism (differentially-private aggregates). Moat: one process = one trust boundary. |
| **Corrected wave sequencing** | §6 | Wave 5 stabilize → Wave 6 substrate (Eidos + BrowserEngine + deno_core) → Wave 7 Live Files (boring) → Wave 8 auto-research (safe mutation). Out of order = fragile. |
| **Stateful Rotor** | LIVE_FILES §1 | Sub-5ms event-driven scheduling with thermal/battery/budget gating |
| **Vector Universe manifold** | LIVE_FILES §4 | Dense vectors + sparse lexical + schema AST + task queue + conditions + permissions + citations + freshness decay |
| **Eidos Plus deliberation engine** | LIVE_FILES §8 | Wave 8 deliberation with model teams (optimistic/pessimist/neutral panels) + research jury + Karpathy-style overnight loops |

### Pro-only (Obscura / deno_core / Eidos)
**Canonical source:** `/Users/jojo/Documents/Epistemos-QuickCapture/OBSCURA_BROWSER_ADDENDUM.md` (62 KB, 12 sections).

| Concept | Section | Description |
|---|---|---|
| BrowserEngine trait | §1, §3 | Polymorphic adapter: WebKit baseline (MAS, Apple-native sandboxed), Obscura (Pro Rust-native V8 stealth, ephemeral spawn), Mock (tests), RemoteBrowser (fallback). NEVER single-vendor. |
| deno_core for Pro JS | §4 | NOT Deno binary or Node.js — deno_core in-process library with capability-gated ops (no subprocess, unrestricted FS/network/shell/AppleScript/launchctl). Playwright/Puppeteer compat via in-bundle shim. |
| Eidos search engine | §6 | Agent-native search: vault HNSW index + Metal-accelerated cosine kernel (~31× CPU at scale) + speculative crawl + closed result schema. Returns *control vectors* (typed authority annotations from Live Files), not just chunks. |
| Stealth posture | §8 | Anti-fingerprinting + 3,520-domain telemetry blackhole |

### Biometric / Tamagotchi / Brain Export (Waves 9–11)
**Canonical:** `/Users/jojo/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md`.

| Concept | Section | Description |
|---|---|---|
| Biometric authority via Secure Enclave | §1 | Scope-bounded, TTL-bounded session-authority token. Required for: irreversible actions, system-prompt edits, capability changes, low-conf reset, Brain Artifact load, Pro Research / Pro Omega unlock, policy-grade promotion, Cloud-Off override |
| Confidence Meter + 70% re-learn | §2 | Biometric-triggered diagnose-first re-learn pattern |
| Tamagotchi Pixel/Tactical mode duality | §3 | Same agent, two visual modes: Pixel (avatar + animation + emote) or Tactical (info-dense pills). Sub-agent capability inheritance is *narrowing only*, never inflation. A2A "phone" channel between agents. |
| Cloud-as-Teacher Distillation Lab | §4 | PII sluice gate + catastrophic-forgetting eval gate. Prevents model memorization of user data. |
| Brain Export | §5 | Signed Brain Artifact bundle: weights + compiled scaffold + test report + license keying. Continued Epistemos subscription = "stay in app" lock-in. |

---

## 5. Halo / Contextual Shadows / Recall

### Status (current code truth)
- **V0:** production-mounted with `ShadowSearchService` backend route. Tests at `EpistemosTests/HaloUITests.swift`, `ContextualShadowsStateTests.swift`.
- **V1:** open behind protected-path gate. Code exists but not mounted.

### Code anchors
- `Epistemos/Engine/HaloController.swift` (@MainActor @Observable, 6-state FSM)
- `Epistemos/Engine/HaloEditorBridge.swift` (NSTextView delegate)
- `Epistemos/Engine/ShadowSearchService.swift` (ShadowFFI search wrapper)
- `epistemos-shadow/` crate (45 tests, 7 clippy warnings post-hardening)
- `Epistemos/KnowledgeFusion/InstantRecallService.swift` (Swift fallback)

### Stack reference (canonical)
6-state FSM `dormant → watching → encoding → searching → available → open` + trailing-edge debounce (200ms) + Model2Vec potion-retrieval-32M + usearch HNSW with bf16 + Tantivy BM25 + weighted RRF (k=60, lex_weight=1.2) + non-activating NSPanel + Metal display-link + 25ms end-to-end recall latency budget.

### Authoritative docs
| Doc | Path | Role |
|---|---|---|
| Halo V1 decision | `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/ambient_V1_DECISION.md` AND `/Users/jojo/Downloads/ambient/EPISTEMOS_V1_DECISION.md` | Architectural verdict, performance budget |
| Implementation bible | `/Users/jojo/Downloads/ambient/claude ambient.md` (63 KB) | 100+ code stubs, hard performance targets, library validation |
| Reference Halo controller | `/Users/jojo/Downloads/ambient/HaloController.swift` (21 KB) | @Observable, debounce, NSPanel non-activating, @Query cascade avoidance |
| Reference Rust shadow | `/Users/jojo/Downloads/ambient/epistemos_shadow.rs` (23 KB) | ShadowSearchService actor, usearch lifecycle, Tantivy BM25, RRF |
| Wiring audit | `/Users/jojo/Downloads/Epistemos/docs/audits/AMBIENT_RECALL_WIRING_PLAN.md` | V0 surface proof + gap analysis |
| Halo Master Plan | `worktree:agent-a0550f9c/docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md` (2026-04-24, design-locked, execution-blocked on Phase R) | "Ship one feature so well it feels inevitable" |
| Honest gaps | `/Users/jojo/Downloads/Pasted markdown.md` Part 1 (C1-C4) + `/Users/jojo/Downloads/ambient/deep-research-report (2).md` | C1: editor → debounce → encode → Rust HNSW → sidebar UI is THE missing connector |
| Gemini parallel design | `/Users/jojo/Downloads/ambient/gemini ambient.txt` (41 KB) | Validation of claude ambient claims; agent-routing additions |

---

## 6. Hermes / Pro Tunnels / MCP

### Status
**Worktree:** `hermes-parity` (HEAD `465a3c30`). 28 tools registered (22 Hermes-parity + 6 PKM-specific). Provider chain delegated to Swift TriageService. Session persistence with FTS5. Credential rotation pool. Error classifier with 100+ patterns.

### 28 tools (canonical list)
22 Hermes-parity (Phase 1-2): file_ops, web_fetch, memory, skills, todo, clarify, code_execution, computer_use (Swift-delegate stub), think, chunk_reduce, workspace_search, process_registry, vault_search, vault_read, vault_write, bash_execute, web_search, delegate_task, error_classifier, title_generator, rate_limit_tracker, workflow_executor.

6 PKM-specific (Phase 7): graph_query, note_template, note_linker, research_digest, citation_extractor, markdown_table.

### Code anchors
| Subsystem | Path |
|---|---|
| Tool registry | `worktree:hermes-parity/agent_core/src/tools/registry.rs` |
| Note tools | `worktree:hermes-parity/agent_core/src/tools/note_tools.rs` |
| Graph query tool | `worktree:hermes-parity/agent_core/src/tools/graph_query.rs` |
| Computer-use stub | `worktree:hermes-parity/agent_core/src/tools/computer_use.rs` |
| Session persistence | `worktree:hermes-parity/agent_core/src/session_persistence.rs` |
| Credential pool | `worktree:hermes-parity/agent_core/src/credential_pool.rs` |
| Error classifier | `worktree:hermes-parity/agent_core/src/error_classifier.rs` |
| Rate limit tracker | `worktree:hermes-parity/agent_core/src/rate_limit_tracker.rs` |
| Prompts (plain markdown, NOT ChatML) | `worktree:hermes-parity/agent_core/src/prompts.rs` lines 53-57 |
| Bridge (provider-failed callback) | `worktree:hermes-parity/agent_core/src/bridge.rs` lines 82-128 |

### Design docs
| Doc | Status |
|---|---|
| `worktree:hermes-parity/docs/PHASE_I_IMPLEMENTATION_GUIDE.md` (800 lines) | Canonical implementation spec for Rust agent runtime |
| `worktree:hermes-parity/PHASE9_AUDIT.md` | **Canonical** honest gap assessment (B+ grade, 3 HIGH issues) |
| `worktree:hermes-parity/CODEX_REVIEW_REPORT.md` | **Canonical** v2 audit post-Phase 8 |
| `worktree:hermes-parity/docs/HERMES_PARITY_REPORT.md` | Superseded by Phase 8-9 work |
| `worktree:hermes-parity/docs/sprint-sessions/sprint-agent-3-mcp.md` | MCP integration plan, **not yet complete** |
| `worktree:hermes-parity/docs/DECISIONS.md` | Architecture decisions log (D-001 through D-013) |

### Session persistence schema
```sql
CREATE TABLE checkpoints (
  session_id TEXT NOT NULL,
  turn_number INTEGER NOT NULL,
  messages_json TEXT NOT NULL,
  usage_json TEXT NOT NULL,
  created_at TEXT DEFAULT (datetime('now')),
  active_provider TEXT,
  active_key_index INTEGER,
  PRIMARY KEY (session_id, turn_number)
);
```
+ FTS5 virtual table over `messages_json` with INSERT/UPDATE/DELETE triggers. **Better than Hermes flat JSONL.** `active_provider` + `active_key_index` enable resuming with different API key pool state.

### MCP / omega-mcp crate
- `omega-mcp/` (131 tests, 13 clippy warnings)
- JSON-RPC over stdio + Streamable HTTP
- MCP discovery, tool advertisement, capability negotiation
- **Stub for execution**: `agent_core/src/tools/registry.rs` line 815: `// TODO: Load server config and establish connection`
- Sprint plan at `worktree:hermes-parity/docs/sprint-sessions/sprint-agent-3-mcp.md`: make `omega-mcp` authoritative; add `vault_search`, `vault_read`, `vault_write`, `vault_graph_query`; harden AX-first computer-use; close execution seam for DeviceAgentService

### External research
- `/Users/jojo/Downloads/final/EPISTEMOS_HERMES_MANIFESTO.md` (paradigm-setter)
- `/Users/jojo/Downloads/final/Episdemo Master Architecture Brief + Claude Brainstorm Prompt.md` (provider architecture)
- `/Users/jojo/Downloads/final/Building Epistemos x Hermes Hackathon.txt` (D1-D10 dossier, rmcp + base62 + tokio broadcast)
- `/Users/jojo/Downloads/final/executive sumaries/epistemos-rival-doctrine.md` (provenance-first correction)
- `/Users/jojo/Downloads/Advice/{claude advice, Gpt paper, Perplexity paper}.md` (multi-provider architecture)
- `docs/_consolidated/20_canonical_research/HERMES_INTEGRATION_RESEARCH.md` (10-file Fast Pack + 30-file Deep Pack curated)
- `docs/_consolidated/20_canonical_research/FUSED_AGENT_ENGINEERING_REPORT.md` (root-cause: tool-load failures via silent check_fn returning False)

---

## 7. Code Editor / TextKit / syntax-core

### §23-§27 PLAN_V2 architectural law
**Canonical:** `worktree:inspiring-heisenberg-ea9dc3/docs/architecture/PLAN_V2.md` §23-§27.

| Section | Coverage |
|---|---|
| §23 | Code Editor Architecture Truth + Syntax Data Plane. CodeEditSourceEditor 0.15.2, O(n) string binding ≤100KB acceptable. Prose editor better-architected. syntax-core crate (tree-sitter 0.25 + ropey 1.6 OR crop). Viewport-scoped tokenization mandatory. **Metal prohibited for text rendering** unless benchmarks prove otherwise. |
| §24 | Agent Streaming Data Plane. **16ms token coalescing is FIRST optimization, not transport change.** Reduce 100-300 events/sec → ~60/sec. Never coalesce errors / approvals / completions. SPSC ring buffer or pull-based polling at frame boundaries. |
| §25 | Graph Zero-Copy Rendering. Triple-buffered MTLBuffer with `.storageModeShared`. Struct-of-Arrays. **Deferred until Session 3 typed-buffer proves copy is bottleneck.** |
| §26 | Implementation Sessions. Sessions 0-6 done. Sessions 7+ gated on benchmarks. |
| §27 | **Anti-Pattern Register — 15 prohibitions verbatim.** Most load-bearing: "Do not optimize features that only exist in documentation. Verify code first, then optimize." |

### syntax-core crate (Pro-tier scaffolding)
**Path:** `worktree:inspiring-heisenberg-ea9dc3/syntax-core/`. Tests pass; **no FFI exports to Swift yet**.

**FFI data shapes (`#[repr(C)]`, all compile-time size-asserted):**
```rust
SyntaxDocumentHandle  16B  doc_id:u64 + generation:u64
SyntaxEditDelta       48B  doc_id, from_gen, to_gen, byte_offset, old_len, new_len
SyntaxViewportRequest 24B  doc_id, generation, utf16_start, utf16_end
SyntaxTokenSpan       12B  utf16_start:u32, utf16_len:u16, kind_id:u16, flags:u8, _pad:[3]
SyntaxFoldRange       24B  byte_start, byte_end, kind_id:u16, _pad:[6]
SyntaxDiagnosticRange 24B  byte_start, byte_end, severity:u8, _pad:[7]
SyntaxSnapshotStats   --   doc_id, gen, node_count, error_count, parse_time_us
```

**Files:**
- `syntax-core/src/lib.rs` — public API surface
- `syntax-core/src/rope_bridge.rs` — ropey ↔ tree-sitter `TSInput` integration via `parser.parse_with_options` + chunk-by-chunk reading
- `syntax-core/src/token_registry.rs` — capture-name → u16 kind ID via `FxHashMap`
- `syntax-core/src/generation.rs` — `AtomicU64` counter for stale-parse cancellation
- `syntax-core/benches/parse_baselines.rs` — initial parse 50K-line Rust file <100ms; reparse single-char <1ms

### Code editor doc-truth audit
**Canonical:** `worktree:inspiring-heisenberg-ea9dc3/CODE_EDITOR_FEATURE_AUDIT.md`. See H9 above for drift table.

### Other code anchors
- `Epistemos/Views/Notes/CodeEditorView.swift` (CodeEditSourceEditor host)
- `Epistemos/Views/Notes/CodeLineGutter.swift`
- `Epistemos/Engine/SwiftTreeSitterLiveHighlighter.swift` (15 language bindings)
- `Epistemos/Views/Notes/ProseEditor*.swift` — **PROTECTED PATH**, do not edit
- `Epistemos/Engine/EpdocDocument.swift` (NSDocument subclass for `.epdoc`)

### .epdoc / Documents / Readable Blocks
- `Epistemos/Engine/EpdocDocument.swift`
- `Epistemos/Sync/ReadableBlocksProjector.swift`
- `Epistemos/Sync/ReadableBlocksIndex.swift`
- Verdict: TextKit 2 + Tiptap-in-WKWebView locked per `docs/_consolidated/00_canonical_authority/EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md`

---

## 8. Streaming / FFI / BoltFFI

### §24 Agent Streaming Data Plane
See §7 above. 16ms coalescing is the first optimization.

### Honest-handle FFI pattern (canonical doctrine)
- `worktree:agent-a0550f9c/epistemos-shadow/src/honest_handle.rs` (770 lines) — `Arc::into_raw` + `Arc::increment_strong_count` + `Arc::decrement_strong_count` + `panic::catch_unwind(AssertUnwindSafe(...))` panic→null translation
- `worktree:agent-a0550f9c/Epistemos/Engine/RustShadowFFIClient.swift` (321 lines) — Swift consumer wrapping raw handle in `final class`; `init` takes ownership via `shadow_handle_open_at`; `deinit` releases via `shadow_handle_release`

### FFI opportunity matrix (8 boundaries audited)
**Canonical:** `worktree:agent-a0550f9c/FFI_OPPORTUNITY_MATRIX.md`.

| Boundary | Verdict | Reason |
|---|---|---|
| Graph control/render | KEEP | Tiny payloads, work-dominated |
| Rust graph label search | KEEP | |
| BTK subscription | BATCH | Zero-copy transport but row-by-row materialize |
| BTK queries | TUNE | Newline-separated IDs; could switch to typed buffer |
| Block edit | KEEP | |
| Markdown parser | KEEP | |
| Embedding push | KEEP | |
| Knowledge-core shadow ring | ZERO-COPY (after live UI consumes) | Currently shadow-only |

### BoltFFI typed-buffer prototype
**Path:** `worktree:inspiring-heisenberg-ea9dc3/graph-engine/src/bolt_bridge.rs` behind `bolt-graph` feature flag. **Never benchmarked vs C FFI in production.**

```rust
#[repr(C)]
pub struct BoltNodeRecord {
  id_ptr: *const u8, id_len: u32,
  label_ptr: *const u8, label_len: u32,
  node_type: u8,
  x: f32, y: f32,
  size: f32,
  color_rgba: u32,
}
#[repr(C)]
pub struct BoltEdgeRecord {
  source_idx: u32, target_idx: u32,
  edge_type: u8, weight: f32,
}
```

Functions: `bolt_graph_load_nodes`, `bolt_graph_load_edges`, `bolt_graph_query_positions`. All wrapped in `panic::catch_unwind`. String extraction via `bolt_str(ptr, len)` returns `""` on null/invalid UTF-8.

### Streaming instrumentation (Session 6)
**Canonical:** `worktree:inspiring-heisenberg-ea9dc3/Epistemos/Engine/Log.swift` line 71.
```swift
static let agentStreaming = OSSignposter(subsystem: "com.epistemos", category: "agent-streaming")
```
Plus categories: `appPerf`, `notesPerf`, `vaultPerf`, `graphPerf`, `ffiPerf`.

`StreamingDelegate` (`Epistemos/Bridge/StreamingDelegate.swift`) signposts: `onThinkingDelta`, `onTextDelta`, `onToolInputDelta`, `onToolStarted`, `onToolCompleted`, `onSubagentSpawned`, `onPermissionRequired`, `onContextCompacting`, `onContextCompacted`, `onTurnStarted`, `onComplete`, `onError`.

`AgentStreamEvent` enum: 12 cases at `StreamingDelegate.swift:144-156`.

### Local-stream truncation/flush fix (preservation watch)
- `Epistemos/LocalAgent/IncrementalToolCallDetector.swift` (main + 3 worktrees)
- `EpistemosTests/IncrementalToolCallDetectorTests.swift`
- Fix prevents premature EOF / token truncation on local-stream path during tool-call detection. Per CANON_GAPS C12 — preserve through any agent_loop refactor.

---

## 9. Local Model / MLX Inference

### Stack
- **Local text generation:** GGUF primary
- **Helper / embeddings / adaptation / Apple-native auxiliary:** MLX (mlx-swift, mlx-swift-lm)
- **Cloud:** Anthropic (URLSession + thinking blocks preserved on `tool_use`), OpenAI (URLSession), Perplexity (Sonar Pro)
- **Apple:** Foundation Models (AFM) when available + AFMSessionPool warm pool (800ms→140ms, 5.7× cut)

### Mamba-2 SSM (already wired)
- `Epistemos/Engine/MetalRuntimeManager.swift` — Mamba-2 GPU compute
- `Epistemos/Shaders/Mamba2/{direct_conv, elementwise_ssm_helpers, inter_chunk_scan, segsum_stable}.metal` — Q=128 chunks, 32KB threadgroup, no Decoupled Lookback
- Phase 1A complete: save/load/resume/staleness wired (per project memory)

### KIVI KV cache
**Status:** opt-in, blocked on MLX metallib runtime. Unit tests pass.

### Local model safety (DEFERRED, per release hardening §1.3)
**Canonical:** `worktree:agent-a0550f9c/docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md` §1.3.
> "Do not merely hide big models from the picker and call it fixed. The user must get an honest 'this model cannot load safely on this machine right now' error."
- Unified `ModelSupervisor` actor: admission control before load, eviction on memory pressure, explicit refusal instead of swap death
- Files to touch: `MLXInferenceService`, `InferenceState`, app shell memory-pressure listener

### Faculty roster fallback (D4)
**Canonical:** `worktree:agent-a0550f9c` commit `4c0c7e17`.
- Hermes 4.3 36B → demoted to ≥32GB opt-in (memory budget violation)
- Qwen 3 8B → safe fallback for 16GB Macs
- Hermes 3.x 8B (~3.5 GB Q4_K_M) — primary local target per dossier

### ConfidenceRouter
**Path:** `Epistemos/LocalAgent/ConfidenceRouter.swift`. Routes between Claude Haiku 4.5 (fast helper, default) and Qwen3-4B (local fallback). Cost recorded in `reasoning_metrics`.

### Helper-model summariser (simulation §3.4.5)
Helper model produces one-line live summary for active agent in dispatch panel. Cadence: every 2s while streaming + on animation transitions; stops on Idle; 30s cache.

### Continual learning
**Canonical:** doctrine Annex A.5 + `docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md`.

| Method | QLoRA | Continual learning | Status |
|---|---|---|---|
| **QOFT (OFTv2)** | ✅ native | ✅ orthogonal | **Recommended production** |
| **QDoRA** | ✅ native | ✅ high | Practical deployments |
| **QPiSSA** | ✅ convert | ✅ high | Best accuracy |
| OSFT | ❌ | ✅ ~20-task | Pro R&D only |
| PSOFT | ❌ | ❌ single-task only | Pro R&D only |
| coSO | ❌ | ✅ no LLM yet | Pro R&D only |

Adapter capacity 128GB MacBook ~3,100 at r=8; switching <1ms.

**Donor research:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/osft_psoft_coso_fusion.md`.

---

## 10. Graph Engine and Motion

### Status
`graph-engine/` crate — **2,508 tests** (largest crate). 12 modified files in main's dirty diff = **HIGH RISK** (`graph-engine/src/knowledge_core/store.rs` +808 lines, force/edge_trim/motion/curl/waves/engine/bolt_bridge/simulation/types/renderer/lib.rs).

### Code anchors
- `graph-engine/src/knowledge_core/store.rs` (massive new store impl, unaudited)
- `graph-engine/src/{forces, edge_trim, motion/{curl, waves}, engine, simulation, types, renderer, lib}.rs`
- `graph-engine/benches/graph_ffi_baselines.rs` (criterion baselines: 100/500/1000/5000 nodes)
- `Epistemos/Views/Graph/MetalGraphView.swift` — **PROTECTED PATH**
- `Epistemos/Views/Graph/HologramController.swift` — **PROTECTED PATH**

### Graph motion overlay
**Canonical:** `docs/_consolidated/20_canonical_research/GRAPH_WAVES_AUDIT.md` (2026-04-24, second-pass synthesis vs `graph-engine/`).

Edge trimming (r0 + gap), velocity inheritance EMA α=0.72, WaveEvent rings (Gaussian shell, 8-cap, 1/√r falloff, oldest-evict), temporal envelope retire <5%, 16px origin clamp, mass formula, semi-implicit Euler.

### Three runtime fixes (Session 6 worktree)
**Canonical:** `worktree:inspiring-heisenberg-ea9dc3/docs/APP_ISSUES_AUTO_FIX.md`.

| Issue | Root cause | Fix |
|---|---|---|
| ISSUE-2026-04-06-002 Beach ball (P1) | `recompute_semantic_neighbors` O(n²×768) on main, ~2s for 1131 nodes | Move to `Task.detached(.utility)` + `parking_lot::Mutex<Vec<(u32,u32,f32)>>` |
| ISSUE-2026-04-04-001 Vec drop crash (P0) | `Vec::from_raw_parts(ptr, count, count)` allocator mismatch on `graph_engine_free_prepared_retrieval_candidates` | `into_boxed_slice` + `Box::into_raw` / `Box::from_raw` symmetry |
| ISSUE-2026-04-06-001 Pinned inspector freeze (P2) | Idle skip stops `update_camera()` after 3 frames; pinned panel reads stale `node_screen_pos()` | Added `force_alive` flag; bypass idle skip when pinned panels exist |

---

## 11. Simulation / Theater (Pro Design DNA — FROZEN)

**Worktree:** `simulation` — frozen per user directive. Pro-tier donor only. **Highest design density.**

### DOCTRINE.md v1.6 (17 sections, 148 KB)
**Path:** `worktree:simulation/docs/simulation-mode/DOCTRINE.md`.

Sections covered:
- §1 13 Non-Negotiable Invariants (I-1 to I-15 + I-16 bit-perfect pixel rendering contract)
- §3 Three-Placement Companion System (Landing Farm + Graph Live Theater + Notes Sidebar = projection of single CompanionRegistry)
  - §3.2 Landing Farm: 6 visual states (Active/Recent/Dormant/Parked/Just-acquired/Errored), per-companion ±32px walking with seeded PRNG
  - §3.3 Graph Live Theater: hysteresis, 30s idle exit, multi-room viewport tiling, overview vs drill-in
  - §3.4 Notes Sidebar: knowledge-brick design language (typography NY/SF Pro/SF Compact Rounded, density 12pt/22pt/32pt, motion 220ms/180ms/140ms), multi-vault hierarchy
- §5 Body Grammar: Block (parameterized: aspect/legs/antennae/eye_treatment) / Sage (tall humanoid) / Orb (spherical) / Snake (Hermes-only)
- §7 Adapter Gift-Box (`.epbox` package: manifest.json + content/ + preview/ + provenance.json; 9 box types; honesty-bound unwrap timing)
- §8 Hermes graph faculty + opulent landing ritual (7-phase, 4.4s, NousResearch canonical assets, gold halo, ASCII portrait, snake coil)
- §9 Honesty rules (3-class allowed-animation: event-driven / cosmetic-idle / state-transition)
- §10 Atlas pipeline (Character DNA → AI concept → Aseprite refinement → auto-slice → CI validation; LobeHub provider icons; pixel-art vs smooth-vector split)
- §11 Event Schema (32-variant `AgentEvent` enum + **6 new v1.6 variants forward-referenced**: `SteerRequested`, `SummaryStarted`, `SummaryDelta`, `SummaryCompleted`, `VaultCreated`, `VaultArchived` — H6)
- §12 Performance Budgets (≤5ms p99 Metal frame, ≤1ms reducer, ≤50µs UniFFI, ≤5µs ring buffer, ≤10ms FTS5 p95, ≤300MB idle, ≤6GB active, ≤50MB VRAM, ≤500ms Fast-tier inference p95)
- §13 App Store / Pro Profile Distinction (`#if EPISTEMOS_PROFILE_PRO` gates)
- §14 Anti-Drift Rules (15 forbidden code patterns + 5 forbidden doc patterns)

### IMPLEMENTATION.md v1.6
**Path:** `worktree:simulation/docs/simulation-mode/IMPLEMENTATION.md`.

Slices S0-S11 all committed:
- S0: perf-gate substrate
- S1: CompanionRegistry + activity hysteresis (Active/Recent/Dormant/Parked)
- S2: AgentEvent normalization + replay infrastructure
- S3: Honesty audit ledger (`AuditOrigin` enum at `worktree:simulation/agent_core/src/audit/origin.rs`)
- S4: Theater Metal renderer (placeholder geometry, perf baseline)
- S5: Landing Farm placement
- S5.6: Provider Brand Icon System (LobeHub `@lobehub/icons-static-svg` + 18 providers + dual-source Hermes)
- S6: Notes Sidebar (knowledge-brick + multi-toggle + multi-vault + helper-model summariser)
- S7: Graph Live Theater (multi-room viewport tiling)
- S8: Companion creation flow (8 atomic steps)
- S9: Hermes graph faculty + opulent landing ritual
- S10: Animated raster atlas pipeline (V1 sprites; bit-perfect I-16 enforced)
- S11: Adapter gift-box `.epbox` + Mailroom

### Code anchors
- `worktree:simulation/agent_core/src/companions/registry.rs` (CompanionRegistry, 350+ lines)
- `worktree:simulation/agent_core/src/audit/origin.rs` (three-class AuditOrigin)
- `worktree:simulation/agent_core/src/adapters/epbox.rs` (gift-box parser, 400+ lines)
- `worktree:simulation/agent_core/src/events.rs` lines 272-499 (32 variants; 6 new v1.6 NOT YET in code — H6)

### Character DNA docs
- `worktree:simulation/docs/simulation-mode/character-dna/{block_compact, block_wide, hermes_snake, orb, sage}.md`

### I-16 bit-perfect contract (pixel-art only)
- `MTLSamplerMinMagFilter.nearest` (both)
- Integer scale only (1×, 2×, 3×, 4×)
- Snap-to-pixel in vertex shader
- MSAA off
- SVG paths orthogonal only (M, L, H, V, Z) — no Bezier/arc/circle/ellipse
- Halos as separate additive-blend quads with pre-rasterized textures (never Gaussian blur)
- LobeHub smooth-vector brand icons exempt from I-16 (different category)

### 2026-05-04 T6 Tamagotchi specificity correction
**Canonical user correction:** Simulation/Companion Farm means actual
Tamagotchi-style companion creatures, not SF Symbols, generic orbs, or static
cards. The Landing Farm needs small styleable avatar bodies that can
idle-walk/roam deterministically inside bounded paths; the Graph Live Theater
later projects companion presence from the same registry.

**Current code truth to verify before every T6 slice:**
- `Epistemos/Views/Landing/Farm/CompanionView.swift` still needs native
  Canvas/SVG-style body rendering if it references `systemImageName`.
- `Epistemos/Views/Landing/Farm/LandingFarmView.swift` needs a deterministic
  roaming layer before T6 can be called visually canonical.
- `Epistemos/Views/Graph/` has no companion-presence layer yet; graph work must
  not touch protected graph internals until a graph-specific deliberation.

**Search expansion for this concept:** `tamagotchi`, `companion`, `farm`,
`avatar`, `creature`, `pet`, `body grammar`, `walk`, `roam`, `wander`,
`Landing Farm`, `Graph Live Theater`, `Notes Sidebar Skin`, `CompanionView`,
`Character DNA`, `Hermes Snake`.

**Quick Capture Wave 10 productization detail:** Pixel mode is "Pixel art,
animated walking sprites, emotes, color-per-agent"; Tactical mode is
information-equivalent and enterprise-safe. Exit bar includes 50 Tamagotchi
sprites, 24 emotes, and smooth 60 FPS walking on M-series.

**Canon artifact:** `docs/fusion/fleet/t6-tamagotchi-body-grammar/T6_TAMAGOTCHI_BODY_GRAMMAR_RECOVERY_2026_05_04.md`.

---

## 12. App Store Release / Phase R / Phase S

### Canonical tracker
**Path:** `/Users/jojo/Downloads/Epistemos/docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` (also at `docs/_consolidated/30_canonical_operational/`).

App Store profile: bounded execution only — chat, bounded agent, local MLX, Apple Intelligence, user-key cloud, vault/search/note tools. NO shell, Bash, Docker, CLI, iMessage, background agents.

Pro: full autonomy; shared code profile-gated not forked. Per-build entitlement matrix.

### Resource Runtime / grants / verified writes (Phase R)
**Status:** lives on `codex/runtime-input-audit` branch — **324 commits ahead of main, NEVER MERGED**. Per WORKTREE_INSIGHT_SALVAGE §6, recommended cherry-pick now.

Specifically: `47fd03fe` "fix(release): expose writable attachment paths"; vault write authorization pipeline; attachment path exposure; sandbox grant seeding; CODE_EDITOR_FEATURE_AUDIT.md (single source of truth on what's verified live vs planned vs reverted — minimap gone, outline navigator live).

### PromptTree / N1 (Lane A)
**Status:** **601 unmerged commits** on `lane-A` (H1).

**2026-05-04 update:** Current main already contains the Prompt Tree foundation
files and declares `agent_core/src/session_insights.rs`. Lane A is still active
because it has reconciliation deltas in `ChatCoordinator`, `agent_core/src/bridge.rs`,
`agent_core/src/providers/claude.rs`, `session_insights.rs`, and
`docs/PROMPT_AS_DATA_SPEC.md`. See
`docs/fusion/PROMPT_TREE_LANE_A_BRIDGE_2026_05_04.md`.

- `/Users/jojo/Downloads/Epistemos-laneA/docs/PROMPT_AS_DATA_SPEC.md` (270 lines) — JSPF (JSON-Schema Prompt Format) + PTF (Prompt Tree Format) at `<vault>/.epistemos/prompts/<session>/<turn>/`. Anthropic prompt-cache 4 breakpoints, 90% discount, 5-min TTL, 1024-token min. Relocation Trick: 7%→84% cache-hit rate.
- `Epistemos/Views/Cost/CostDashboardView.swift` (NEW, 317 lines, W9.6) — `cached_tokens_share` counter
- `Epistemos/Views/Approval/ApprovalModalView.swift` (NEW, 162 lines, W9.8) — SwiftUI tool approval flow
- New Swift files: `PromptTree.swift`, `PromptRenderer.swift`, `PromptCache.swift`, `PromptTreePersister.swift`
- **Former substrate blocker:** `agent_core/src/session_insights.rs` is no
  longer orphaned in current main, but the Lane A telemetry/bridge deltas still
  need comparison before default-on Prompt Tree work.

### Pre-release evidence package (CANON_GAPS C11, staged)
Workflow matrix + regression suite + App Store metadata + manual dogfood + submission checklist + Phase R closure + Phase S closure (TestFlight / metadata / submission).

### MAS hardening canonical state
**Canonical:** `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md` (2026-04-28). Sections 16-23 cover: MAS privacy/computer-use boundary (BLOCKER), Contextual Shadows V0 (HIGH), Instant Recall large-vault p95 (MEDIUM), Raw Thoughts default-on UI (HIGH), Code editor 4k-line fluidity (HIGH), Derived index staleness (HIGH), Deterministic mutation envelopes (HIGH).

---

## 13. Privacy / Telemetry / Security

### Privacy stack (7 layers per FINAL_SYNTHESIS §5)
Reflex (local cache) → Attention (Eidos in-process) → Executive (local compile) → Immune (deterministic local auth) → Motor (in-process/sandboxed browser) → Memory (encrypted RunEventLog) → Metabolism (differentially-private aggregates).

**Moat:** one process = one trust boundary.

### Security / threat scanning
- `agent_core/src/security.rs` — 75+ regex rules from Hermes + OpenClaw; `ThreatCategory` (6 classes), `ApprovalScope` (Auto/Once/Session/Always/Deny), Severity levels
- `Epistemos/Omega/CSISafeguard.swift`
- App Store privacy: `docs/audits/PRIVACY_APP_STORE_AUDIT.md`

### TCC / sandbox
- `Epistemos/Omega/TCCPermissionState.swift`
- `Epistemos/Omega/OmegaPermissions.swift`
- `Epistemos/AppStoreComputerUseStubs.swift`

### Telemetry policy (CANON_GAPS C13, staged)
- Captured (allowed): timestamps, modifier states, anonymized event types, failure categories, aggregate latency, feature flag enablement, OS/app version, hardware class
- Forbidden: typed text content, note bodies, code, message bodies, file contents, file paths (paths leak structure), search query strings, vault content, screenshots, AX tree contents, microphone audio
- Retention: local-only ring buffer (7 days runtime, 30 days crash logs)
- Cloud upload: explicit per-channel opt-in; default OFF

### Secrets
- API keys in macOS Keychain (`SecItemAdd` / `SecItemCopyMatching`), NEVER UserDefaults
- Per CANON_GAPS C2/C3: BYOK cloud OFF by default + no silent cloud fallback / escalation

---

## 14. Multi-Agent / Legacy ACS Ecosystem

### NeMoCLAW / OpenCLAW
**Canonical:** doctrine Annex A.8.

Sub-agents called "claws" each control specific app/domain. Coordination via resonance-based orchestration (each claw reports Σ signature; orchestrator routes by direction + KAM stability), explicitly avoiding self-attribution bias.

REP mesh + CRDT synchronization make claws horizontally distributable across processes / devices / users (Pro Research only — legacy ACS ecosystem layer).

**Single-claw in MAS. Multi-claw + REP mesh in Pro Research.** Multi-agent on M4 Max tops out at ~10–15 concurrent 7B agents via work-stealing.

### Honest scheduling stack (Annex A.4)
| Mechanism | Latency | Use case | Percentage |
|---|---|---|---|
| Work-stealing (Rayon/Tokio) | ~10-100 ns | Default hot path | **99%** |
| Priority queue | 50-100 ns | User-facing | 0.9% |
| Competitive allocation | 1-100 ms | Agent role selection (NOT per-task) | 0.1% |

Notch-Delta lateral inhibition is **10¹²× too slow** for actual task routing.

### Symphony OS / KIVI / KV virtualization
**Canonical:** doctrine Annex A.9. KV cache as virtualized file system with per-conversation namespace and snapshot/restore semantics. KIVI = project's existing partial implementation, opt-in, blocked on MLX metallib runtime.

### Deep Deliberation jury (Pro)
**Canonical:** `/Users/jojo/Documents/Epistemos-QuickCapture/LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` §8 (Eidos Plus deliberation engine).

---

## 15. Ternary Substrate / Research Tier

### Sherry 1.25-bit packing (verified)
**Canonical:** doctrine Annex A.5.
**Donor:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/{ternary_spectral_architecture, ternary_code_scaffolds, ternary_reconceptualization}.md`.

Hong Huang et al. (City University of Hong Kong, Tencent, McGill), January 2026. Code at `github.com/Tencent/AngelSlim`. 3:4 fine-grained sparsity within every block of 4 weights. Each 4-weight block packs into 5 bits (4-bit index + 1-bit sign) = 1.25 bits per weight. 1B LLaMA-3.2: zero accuracy loss, 25% bit savings, 10% speedup.

### BitNet b1.58 (verified)
Microsoft, 2B params, production. {-1, 0, +1} weights. 58.5% information density gain vs binary.

### Wave J1 kernel portfolio — Rust (PORTFOLIO CLOSED 7/7; verified 2026-05-16, Terminal C iter 73 + 81)
**Source branch:** `run-b-post-v1-research` (not yet merged to `codex/research-snapshot-2026-05-08` as of iter 81).
**Substrate floor (iter 73 audit, 382 LOC total, 13 tests):**
- `agent_core/src/research/mod.rs` (17 LOC) — Wave J umbrella; cites `helios v3.md` capstone.
- `agent_core/src/research/ternary/mod.rs` (49 LOC at floor; 82 LOC at portfolio close) — paper-style README, decode-first invariant, kernel-portfolio roadmap; cites Ma et al. arXiv:2402.17764 (BitNet b1.58).
- `agent_core/src/research/ternary/trit.rs` (69 LOC, 3 tests) — `Trit` enum + canonical 2-bit encoding (`00=-1, 01=0, 10=+1, 11=reserved`); cites `ternary kernel.md` §"Ternary packing and unpacking".
- `agent_core/src/research/ternary/pack.rs` (118 LOC, 6 tests) — 16-trits-per-`u32` pack/unpack with reserved-pattern detection.
- `agent_core/src/research/ternary/backend.rs` (129 LOC at floor; 4409 bytes at portfolio close, 4 tests) — `BackendKind` + `TernaryBackend` trait + 3 stub backends (DenseMlx baseline · BitnetReference truth-source · TernaryMetal breakthrough).

**Kernel portfolio (iter 81 audit, audit-of-audit #9; 60 additional tests; PORTFOLIO CLOSED):**
| # | Kernel | File | Commit | Bytes | Tests |
|---|---|---|---|---|---|
| #2 | Block-scaled ternary GEMV (CPU reference + Metal stub) | `gemv.rs` | `1c6a7020a` | 13384 | 13 |
| #3 | Fused ternary projection with residual island add | `residual_island.rs` | `fbfa381f1` | 9864 | 7 |
| #4 | Fused RMSNorm + ternary projection | `fused_rmsnorm.rs` | `7201a7a79` | 8350 | 9 |
| #5 | Ternary KV fingerprint | `kv_fingerprint.rs` | `9451077d5` | 9864 | 12 |
| #6 | Live activation capture (FIFO ring) | `activation_tap.rs` | `af5fdd6c0` | 6701 | 8 |
| #7 | Steering delta apply | `steering.rs` | `cf85b3d4a` | 8120 | 11 |

**Metal shader sidecar:** `Epistemos/Shaders/ternary_gemv.metal` (added with kernel #2; M2 Pro 16 GB hardware-budget target with 16-trit block size, bandwidth-bound at ~200 GB/s per kernel #2 commit message).

**Portfolio totals:** **73 tests** (floor 13 + kernels 60) across the `feature = "research"` lane. Gated behind `agent_core/Cargo.toml:22 research = []`.

**Donor research (citations resolve on disk):**
- Ma et al., arXiv:2402.17764 — "The Era of 1-bit LLMs" (BitNet b1.58).
- Microsoft `bitnet.cpp` reference implementation.
- Wei et al., arXiv:2407.00088 (T-MAC).
- `docs/fusion/jordan's research/ternary kernel.md` (donor — present on disk; kernel order matches its §"What I would actually build").
- `docs/fusion/jordan's research/helios v3.md` (capstone — present on disk).

**Roadmap status (per `ternary kernel.md`):** block-scaled GEMV ✅ → fused projection + residual island ✅ → fused RMSNorm ✅ → KV fingerprint ✅ → activation tap ✅ → steering delta ✅. **ALL KERNELS LANDED** as of audit-of-audit #9 close (iter 81). Pending forward-work: backend `is_available()` flipping to `true` for `TernaryMetal` once Metal kernels graduate from stubs to wired implementations; cross-bound integration with `agent_core/src/cognitive_dag/` for Companion lifecycle (Phase 8 already SHIPPED); benchmark suite against `mlx-swift-examples`.

### Wave J2 Cognition Observatory portfolio — Rust (PORTFOLIO CLOSED 4/4 kernels + umbrella; verified 2026-05-16, Terminal C audit-of-audit #12 iter 88)
**Source branch:** `run-b-post-v1-research` (not yet merged to `codex/research-snapshot-2026-05-08`).
**Substrate (43 tests across kernels; gated behind `feature = "research"`):**
| Slice | File | Bytes | Tests | Commit |
|---|---|---|---|---|
| Umbrella | `agent_core/src/research/cognition_observatory/mod.rs` | 2378 | 0 | `c9ad21183` |
| #1 KV implantation | `agent_core/src/research/cognition_observatory/kv_implant.rs` | 12106 | 10 | `c9ad21183` |
| #2 Glass Pipe — atomic-write-index ring | `agent_core/src/research/cognition_observatory/glass_pipe.rs` | 7257 | 9 | `8b91a424f` |
| #3 Weight Surgery — 9-target WeightPatcher | `agent_core/src/research/cognition_observatory/weight_patcher.rs` | 13677 | 11 | `e1918cb20` |
| #4 SAE Observatory — AUC 0.90 doctrine pin | `agent_core/src/research/cognition_observatory/sae.rs` | 10900 | 13 | `fb688e065` |

**Portfolio totals:** 5 files / ~46.3 KB / **43 tests** across kernels (0 in umbrella).

**Donor research (citations resolve on disk):**
- MASTER_FUSION §3.26 (KV implantation + Glass Pipe + weight surgery, Pro Research status) — at line 401.
- MASTER_FUSION §3.36 (SAE Cognition Observatory — AUC 0.90 acceptance pin) — at line 529.
- Cunningham et al., arXiv:2309.08600 — "Sparse Autoencoders Find Highly Interpretable Features in Language Models" (SAE methodology).
- Bricken et al., 2023 Anthropic transformer-circuits.pub — "Towards Monosemanticity: Decomposing Language Models" (SAE-on-residual-stream construction).
- Hanley & McNeil 1982 — AUC trapezoidal-integration definition.
- `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md` lines 419-510 (KVCacheImplanter Swift spec) + lines 588-637 (WeightPatcher Swift spec).
- `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT.md` (ANE honesty boundaries).

**Architecture (per MASTER_FUSION §3.26):** GlassPipe is the control-room reader half (fixed-size circular fp32 buffer with atomic write index); Metal compute-kernel write half lives in Swift/Metal (forward-staged). WeightPatcher is the LoRA-delta envelope with 9-target enum {QProj, KProj, VProj, OProj, Gate, Up, Down, Embed, LmHead} + caller-owned snapshot/revert. SAE module implements AUC 0.90 doctrine pin from MASTER_FUSION §3.36.

**Pending forward-work:** Metal compute-kernel write half for Glass Pipe; backend wiring for actual MLX-Rust integration of WeightPatcher; per-vault SAE validation set construction + AUC measurement to clear the 0.90 doctrine acceptance threshold.

### Wave J3 Continual Learning suite — Rust (umbrella + EWC substrate floor; verified 2026-05-16, Terminal C audit-of-audit #12 iter 88)
**Source branch:** `run-b-post-v1-research`.
**Substrate (14 tests in EWC; first of N kernels; gated behind `feature = "research"`):**
| Slice | File | Bytes | Tests | Commit |
|---|---|---|---|---|
| Umbrella | `agent_core/src/research/continual_learning/mod.rs` | 2736 | 0 | `50da364ae` |
| #1 EWC — Elastic Weight Consolidation | `agent_core/src/research/continual_learning/ewc.rs` | 9156 | 14 | `50da364ae` |

**Donor research (citations resolve on disk):**
- Kirkpatrick et al., PNAS 2017, arXiv:1612.00796 — canonical EWC equation 3 (Fisher-weighted quadratic penalty anchoring θ to θ*).
- `docs/fusion/jordan's research/kimis deep research/research/continual_learning_online.md` §8 "Never Retrain" architecture + §8.3 open questions (unified EWC+LoRA+FastWeights proof gap; Fisher threshold τ_prime heuristic; ANE backward-pass unavailable).
- `osft_psoft_coso_fusion.md` (OSFT/PSOFT/COSO lane reference).
- Driver J3 row "Continual learning suite — OFTv2 + DSC + Titans-MAC + SEAL-DoRA + Never Retrain".

**EWC is the §8.1 "Protection" layer** of the Never Retrain stack. The Fisher-information matrix at the optimum of task A weights the quadratic penalty anchoring θ to θ*; this prevents catastrophic forgetting when subsequent tasks update θ.

**Pending forward-work (driver J3 row roadmap):** OFTv2 · DSC · Titans-MAC · SEAL-DoRA. All NOT-STARTED at iter 88.

### Engram O(1) hash recall (partial)
DeepSeek V4 Preview (April 24, 2026). Hashed N-gram embeddings for static knowledge with O(1) recall. Sparsity Allocation Law: 20-25% to memory, 75-80% to compute.

### Birkhoff Polytope mHC (UNVERIFIED)
Theoretical conjecture. No literature found. Treat as Forbidden tier.

### "3059× speedup" claim (UNVERIFIED)
Sherry actually achieves 10-18% over other ternary baselines on CPU. The 3059× figure is unsupported (likely vs unoptimized FP32 CPU baseline).

### iPhone 17 Pro Max benchmarks (PROJECTIONS, not measured)
iPhone 17 doesn't exist yet. The numbers in Kimi research are projections.

### 6 mathematical pillars (doctrine Annex A.2 + §4.1)
Kleene K3 ternary logic / Laplace-Beltrami spectral geometry / rate-distortion / Koopman operator / resonance eigenvector / KAM stability.

---

## 16. ANE Direct Path / KV Implantation (Research only)

### Direct ANE access
**Canonical:** doctrine Annex A.11.
**Donor:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT.md`.

`AppleNeuralEngine.framework` is private but loadable via `cs.disable-library-validation` (NOT `com.apple.private`):
1. `dlopen` or `NSBundle` load
2. Method swizzling / direct message send to `_ANEClient`, `_ANECompiler`, `_ANEInMemoryModelDescriptor`
3. MIL (Machine Learning Intermediate Language) compilation to E5 binaries
4. IOSurface-based zero-copy I/O between GPU and ANE

ANE per-core state is not exposed — best telemetry: power/frequency via IOKit/SMC channels.

### KV cache implantation
**Canonical:** doctrine Annex A.10.
**Donor:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md`.

`MTLBuffer(options: .storageModeShared)` + `buffer.contents()` gives direct `UnsafeMutableRawPointer`. Enables: raw memory hex dump of GPU tensor, live weight patching, KV cache pre-loading (implant), attention mask manipulation, activation interception, command buffer inspection.

NOT enabled: ANE silicon internals (still black box), kernel-level paging (SIP), in-place MLX ops (MLX avoids by design).

### Activation steering (Anthropic 2024 SAE research)
SAE (Sparse Autoencoder) features for "Golden Gate Bridge", "sycophantic praise", "deceptive language". Pro Research Glass Ball / Executive Console.

---

## 17. UX Posture and Surfaces

### One composer, two modes (CANON_GAPS C4, staged)
- Chat mode + Agent mode share same input affordance
- Effort axis (fast / thinking / research / agent / liveAgent) separate from mode
- Tools = capabilities at agent layer (Sovereign Gate gates them), NOT a third UX mode

### Tamagotchi Pixel/Tactical mode duality (Pro)
**Canonical:** `/Users/jojo/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` §3.

### Inline thinking UI (DEFERRED)
Per `worktree:agent-a0550f9c/docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md` §1.5 + §2 Deferred. Current: `ThinkingPopoverView` detached. Target: inline, in-bubble, auto-expand during thinking, auto-collapse on first answer token.

### ApprovalModalView (W9.8, Lane A)
SwiftUI sheet modal for tool approval flow. Wired to StreamingDelegate → PendingApproval → RustAgentBridge.resolveApproval callback.

### Knowledge-brick design language
**Canonical:** simulation DOCTRINE.md §3.4.3. Pro-tier sidebar UX. NY semibold title, SF Pro Text picker, SF Compact Rounded agent leaves; 12pt indent / 22pt row / 32pt agent leaf / 28pt model header; 220ms spring expand / 180ms pulse / 140ms toggle.

### EditorBreadcrumbBar
Replaces removed status bar (per H9 audit).

---

## 18. Codex Branches (UNMERGED — easiest to forget)

| Branch | Commits ahead | Status | Top insight | Action |
|---|---|---|---|---|
| **`codex/runtime-input-audit`** | 324 | DIVERGED, 2026-04-24 | App Store input validation + vault write authorization + CODE_EDITOR_FEATURE_AUDIT.md | Bridge docs promoted; code deltas require current-main check |
| **`codex/runtime-memory-hardening`** | 750 commits | 2026-04-03 | **5 Laws** (measure before cut / new crate not refactor / identity first / UniFFI until profiled / Python out-of-process) + Phase I Rust agent migration lens + zero-copy mmap vault search | `FIVE_LAWS_AND_PHASE_I` promoted; code deltas require current-main check |
| **`codex/release-stabilization-and-runtime-hardening`** | 669 commits | 2026-03-28 | RunPod modernization, ODIA training corpus sync, EventStore cleanup | Release-audit skill/docs already in main; bridge promoted for Stage F |
| **`codex/post-audit-feature-work`** | 762 commits | 2026-04-04 | **`recipe_cache`** (commit `c217b266`): SQLite tool result caching, SHA-256 keying, TTL=7d, LRU=10K | Code already in main; bridge promoted for cache-policy/provenance wiring |

**Inspection:** `git log codex/<branch> --oneline -30 main..codex/<branch>` from main checkout root.

---

## 19. Operational Prompts and Indices

| Doc | Path | Role |
|---|---|---|
| Truth-router (NEW) | `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` | Three-tier ship model + killer features + invariants |
| Codex overseer (NEW) | `docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md` | Tier-aware / killer-feature / biometric work |
| Codex fleet protocol (NEW) | `docs/fusion/CODEX_AGENT_FLEET_PROMPT_2026_05_02.md` | Parallel local/web/Claude research fleet, red-team brief gate, heartbeat, live registry |
| Fleet live registry (NEW) | `docs/fusion/fleet/REGISTRY.md` | Durable record of spawned/running/returned fleet agents and long-running processes |
| Worktree salvage (NEW) | `docs/fusion/WORKTREE_INSIGHT_SALVAGE_2026_05_02.md` | 10 stay-stellar items + per-worktree state |
| Canon gaps (NEW) | `docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md` | 15 gaps + 3 bonus findings + pre-drafted addenda |
| Codex deliberation prompt (NEW) | `docs/fusion/CODEX_DELIBERATION_PROMPT_2026_05_02.md` | Non-interrupting deliberation request |
| All docs index (NEW) | `docs/fusion/ALL_DOCS_INDEX_2026_05_02.md` | 91+ absolute-path links |
| Master research index (THIS DOC) | `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` | Concept → canonical source mapping |
| April 30 builder | `docs/fusion/BUILDER_EXECUTION_PROMPT_2026_04_30.md` | Phase 0 + deliberation template |
| April 30 source map | `docs/fusion/CANONICAL_SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md` | What each source can decide |
| April 30 fused queue | `docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` | 9-item queue |
| April 30 Kimi prompts | `docs/fusion/KIMI_RESEARCH_AND_FUSION_PROMPT_2026_04_30.md` + `KIMI_SESSION_CONTEXT_2026_04_30.md` | Kimi session inputs |
| Kimi review output | `docs/fusion/KIMI_FUSION_REVIEW_2026_04_30.md` (+ ADDENDUM) | Kimi's audit |
| Worktree inventory | `docs/fusion/WORKTREE_INVENTORY_2026_04_30.md` | Branch/dirty/lane info (note: Lane A "mostly merged" claim is wrong — H1) |
| Build/test floor | `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md` | Phase 0 floor results |
| Codex Manifesto | `docs/_consolidated/30_canonical_operational/CODEX_MANIFESTO.md` | **Verbose Doc-First Protocol** — two-tier corpus search (~/Downloads/ Tier 1 raw research, docs/ Tier 2 distilled). Doc-first searches; CODEX_PROMPT_CHAIN sections; VISION_BACKLOG; phase implementations |

---

## 20. By-Worktree Quick Reference

| Worktree | Branch | Purpose | Top docs |
|---|---|---|---|
| **main** (`/Users/jojo/Downloads/Epistemos`) | `feature/landing-liquid-wave` | Active substrate spine + Halo V0 + R15/R16 closures + landing wave | All `docs/`; `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` |
| **Lane A** (`/Users/jojo/Downloads/Epistemos-laneA`) | `lane-A` | **N1 Prompt Tree (601 unmerged commits — H1)** | `docs/PROMPT_AS_DATA_SPEC.md`, `docs/plan/prompts/N1_prompt_tree.md` |
| **agent-a0550f9c** (locked) | `worktree-agent-a0550f9c` | Audit pass #3 + W9.21-W9.27 hardening | `docs/CANONICAL_AUDIT_LOG.md`, `docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md`, `FFI_OPPORTUNITY_MATRIX.md`, `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md`, `HANDOFF_SESSION_2026-04-07.md` |
| **hermes-parity** | `worktree-hermes-parity` | 28-tool Hermes parity + provider chain + session/credential | `docs/PHASE_I_IMPLEMENTATION_GUIDE.md`, `PHASE9_AUDIT.md`, `CODEX_REVIEW_REPORT.md`, `docs/DECISIONS.md`, `docs/sprint-sessions/sprint-agent-3-mcp.md` |
| **inspiring-heisenberg-ea9dc3** | `claude/inspiring-heisenberg-ea9dc3` | §23-§27 PLAN_V2 + benchmark harness + syntax-core + Sessions 0-6 + 3 runtime fixes | `docs/architecture/PLAN_V2.md` §23-§27, `CODE_EDITOR_FEATURE_AUDIT.md`, `docs/APP_ISSUES_AUTO_FIX.md`, `syntax-core/` crate |
| **simulation** (FROZEN) | `worktree-simulation` | Pro design DNA — DOCTRINE v1.6 + IMPLEMENTATION v1.6 + S0-S11 | `docs/simulation-mode/DOCTRINE.md`, `docs/simulation-mode/IMPLEMENTATION.md`, `docs/simulation-mode/character-dna/*.md` |
| **vigorous-goldberg-3a2d35** | `claude/vigorous-goldberg-3a2d35` | Quick Capture phases 0-12.5 (50+ commits) | `docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md` + `/Users/jojo/Documents/Epistemos-QuickCapture/` (separate canon) |
| **quirky-pascal-135a98** (THIS) | `claude/quirky-pascal-135a98` | Current Claude session — fusion canon work | `docs/fusion/` (mirror of main's fusion folder) |

---

## 21. External Research Roots Quick Reference

| Folder | Verdict | Entry point | Top docs (load-bearing) |
|---|---|---|---|
| `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/` (88 files) | High-value research depth | scope_rex / acs_meta_layer / resonance_gate | EPISTEMOS_NO_COMPROMISE_ARCHITECTURE, EPISTEMOS_RESEARCH_LANDSLIDE, epistemos_resonance_gate, EPISTEMOS_MASTER_ARCHITECTURE, scope_rex_final_architecture, acs_meta_layer, ternary_spectral_architecture, ternary_code_scaffolds, osft_psoft_coso_fusion, EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT, EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM, uasa_memory_breakthrough |
| `/Users/jojo/Downloads/ambient/` (6 core files) | **High-value canon donor** | EPISTEMOS_V1_DECISION.md (performance budget) | claude ambient.md (THE implementation bible, 63 KB), gemini ambient.txt, HaloController.swift, epistemos_shadow.rs, deep-research-report (2).md |
| `/Users/jojo/Downloads/final/` (14 docs) | Partial value (manifestos + early planning) | EPISTEMOS_HERMES_MANIFESTO.md (paradigm) | Episdemo Master Architecture Brief, Building Epistemos x Hermes Hackathon.txt, executive sumaries/epistemos-rival-doctrine.md |
| `/Users/jojo/Downloads/final v2/` (6 docs) | Partial value; superseded by v3 | (defer to v3) | App Moats AI Integration Master Plan.txt, Epistemos Hackathon Deep Research Plan.txt |
| `/Users/jojo/Downloads/final v3/` (7 docs) | **High-value MASTER REFERENCE** | EPISTEMOS_MOAT_AND_OPTIMIZATION_MASTER.md (shipped moats) | Epistemos AI Cognitive Partner Analysis.txt, deep-research-report (4).md (latest audit) |
| `/Users/jojo/Downloads/Advice/` (5 docs) | Cross-cutting validation | claude advice.md (architecture layers) | Gpt paper.md, Perplexity paper.md, claudy research.md |
| `/Users/jojo/Downloads/Pasted markdown.md` | High-value canvas (honest gaps) | Part 1 (C1-C4 critical, P1-P7 partial) | C1: editor → debounce → encode → Rust HNSW → sidebar UI is THE missing connector |
| `/Users/jojo/Documents/Epistemos-QuickCapture/` (10 files) | **Standalone canon for Quick Capture** | FINAL_SYNTHESIS.md (wins conflicts) | PLAN.md (244 KB Waves 0-5), OBSCURA_BROWSER_ADDENDUM.md (62 KB Wave 6), LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md (67 KB Waves 7-8), BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md (44 KB Waves 9-11) |

---

## 22. How to Use This Index (operating rule)

When Codex hits a concept or term:

1. **Ctrl-F this doc first.** Concepts are organized by domain (§2 substrate / §3 killer features / §4 Quick Capture / §5 Halo / §6 Hermes / §7 editor / §8 streaming / etc.).
2. **Read the canonical source** named for that concept. Don't read everything — read what's named "Canonical."
3. **Cross-reference** only when canonical doesn't answer. Each entry lists "Donor research" / "External research" pointers.
4. **Trust the Honest Discoveries (§0)** over older docs they correct.
5. **Verify against current code.** Authority order §1: code wins over docs. If a doc claims X is shipped and grep says no, doc is wrong (see H7, H8).
6. **For per-worktree material**, use §20 quick reference. For external research, use §21.
7. **Don't read everything.** The user explicitly said "should be accurate" not exhaustive. Time-box to what the slice needs.

If you hit a concept this index doesn't list: surface it in `docs/fusion/oversight/CODEX_DELIBERATION_RESPONSE_2026_05_02.md` so the index can be extended in the next merge pass.

### 22.1 Research-first validation protocol

The user's research corpus is presumed high-signal and architecturally
intentional. This is not a "big design only" ritual. For every concept, task,
deliberation, build card, refactor, reroute/reduction, bug fix, dependency
choice, deletion, simplification, or "simple" code change:

1. Search local canon first: this master index, then the canonical source it
   names, then `rg` over `docs/`, `docs/_consolidated/`,
   `docs/fusion/`, relevant worktree docs, and external research roots only
   when the index points there.
2. Use semantic expansion, not only literal terms. Example: "zero-copy" also
   means Apple Silicon UMA, `MTLBuffer.storageModeShared`, IOSurface,
   in-process, single-binary, no hot-path subprocess, no tensor copies,
   deterministic/provenance-linked state transitions, direct/bare-metal path,
   and "as complex as a brain, as simple as an app, as fast as a jet."
   Treat these as philosophy terms as much as implementation terms: they point
   to the shortest safe path from intent to execution, not merely a memory API.
3. If local docs give a structured approach, follow it unless current code/logs
   disprove it.
4. If local docs do not answer, or if a coding task depends on current API,
   package, OS, model, security, App Store, or framework behavior, do a targeted
   web validation pass using primary/official sources where possible. The web
   pass validates or updates the local plan; it does not replace the local
   canon.
5. Match depth to risk: simple edits get a quick local pass, while
   architecture, security, performance, agent-routing, substrate, or release
   work gets deeper local retrieval before coding.
6. Delegated Claude/Kimi/Codex handoffs must include the relevant local canon
   paths, semantic search terms, and any unresolved external-validation need.
   Use `LOCAL_CANON_FIRST_SPECIFICITY_PROTOCOL_2026_05_04.md` for the reusable
   root list, feature-specific search expansions, and brief fields.
7. Run a **specificity recovery pass** for every phase/wave: search the user's
   exact words plus semantic siblings across `docs/fusion/`, `docs/`, relevant
   worktree docs, and named external research roots. High-specificity product
   intent (for example "Tamagotchi-like companions roaming on Landing/Graph")
   must be carried into the brief even if the final plan only uses a compressed
   abstraction such as "body grammar."
8. If the final/substrate plan names a feature abstractly but the research
   roots describe concrete UX/assets/behavior, update the fusion canon before
   coding or stage a canon gap. Do not let compressed doctrine erase the
   user's concrete artifact intent. Do not hand an agent a generic task if the
   user's research already gives the map.
9. Keep it useful: search smartly, quote only the load-bearing claim or path,
   and stop reading once the slice has enough evidence to act safely.

---

## 23. Substrate Unification Doctrine — Cognitive Kernel + Cognitive DAG (added 2026-05-03)

**Two-stage Substrate-foundational unification.** Both stages ride underneath
every feature lane in this index — they're not feature work, they're the
structural collapse that makes everything else simpler. Vocabulary: the
project as a whole is **"the Substrate"** (canonical term, capitalized).

### §23.1 Stage 1 — Cognitive Kernel doctrine (Phases 1-7, current target)

**Canonical:** `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md`

Collapses five fragmented agent loops (Swift `LocalAgentLoop`, Rust
`agent_core::agent_loop`, Python `hermes-agent` subprocess, omega-mcp
dispatcher, AgentXPC/ProviderXPC) into ONE Rust cognitive kernel. Architecture:
kernel + renderer + syscall + sandbox-exec + capability layers (Linux
analogy). Five rules: one agent loop, one memory store, one provenance ledger,
one skill registry, one privilege boundary.

**Phase ordering** (kernel doctrine §11):
- Phase 1 — Audit fragmentation (`COGNITIVE_KERNEL_AUDIT_2026_05_03.md` deliverable)
- Phase 2 — Hermes-in-Rust (kills Python subprocess; ports prompt format + function-call + skills + procedural memory + self-evolution to `agent_core::hermes`)
- Phase 3 — WASM exec via wasmtime + Pyodide / QuickJS (opens MAS for code execution)
- Phase 4 — In-process bundled MCP servers (kills omega-mcp subprocess for bundled servers)
- Phase 5 — Pro→Core migration matrix (`PRO_TO_CORE_MIGRATION_2026_05_03.md` deliverable)
- Phase 6 — Capability lattice consolidation
- Phase 7 — Doctrine doc finalization

### §23.2 Stage 2 — Cognitive DAG doctrine (Phase 8 — successor, AFTER kernel sprint stabilizes)

**Canonical:** `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md`

Collapses the kernel's seven internal subsystems (agent loop, skills,
procedural memory, provenance, resonance, capabilities, companions) into ONE
typed content-addressed cognitive DAG with 10 node types and 10 edge types.
Each subsystem becomes a traversal pattern over the DAG, not a separate
store. Sub-phases 8.A through 8.H over ~10 weeks.

**Single sentence:** Epistemos is a typed cognitive DAG running in one
binary, where every node is content-addressed, every edge is capability-
gated, every truth value is continuously re-evaluated, every action is
provenance-witnessed, and every personality is a lightweight deformation of
one shared substrate.

### §23.3 Process audit ground truth

**Canonical:** `docs/fusion/PROCESSES_AND_RUNTIMES_AUDIT_2026_05_03.md`

Live grep audit as of 2026-05-03 (commit `dc103236`). Inventory:
- 11 in-tree Rust crates (agent_core, omega-mcp, epistemos-shadow,
  graph-engine, epistemos-core, epistemos-code-index, substrate-core,
  substrate-rt, omega-ax, syntax-core, bench)
- 14 Rust subprocess spawn sites in agent_core (12 are Pro-tier; 2 migrate
  to in-process via WASM + bundled MCP)
- 2 Swift `Process()` sites (one is `LSPServerProcess.swift` — should
  migrate to in-process Rust LSP; other is test harness)
- 13 Metal kernels (4 UI, 4 Mamba2 SSM, 6 Helios kernels already at
  `agent_core/metal/` — wired-or-orphan verification needed)
- Runtime Python: only the hermes-agent subprocess (Phase 2 removes it)

**Three audit findings to verify in Phase 1:**
- (a) The 6 Helios kernels in `agent_core/metal/` (`dora_apply`,
  `eml_softmax_lse`, `count_sketch_update`, `ternary_proj_residual`,
  `ternary_gemv`, `kv_fingerprint`) — wired or orphan?
- (b) `Epistemos/KnowledgeFusion/MoLoRA/molora_inference.py` — runtime or
  build-time? Runtime Python is a MAS sandbox blocker.
- (c) `agent_core::wbo6`, `agent_core::lattice`, `agent_core::sketch` —
  canonical Epistemos implementations or Kimi/GPT mockups pulled wholesale?

### §23.4 Codex DAG-on-radar handoff

**Canonical:** `docs/fusion/CODEX_DAG_RADAR_HANDOFF_2026_05_03.md`

Additive handoff that puts Phase 8 (Cognitive DAG) on Codex's radar without
disrupting current sprint work. Three small forward-compat disciplines for
Phases 1-7 (serializable AgentEvent variants, namespaced skill ids,
byte-stable tool outputs). Acknowledged via one-line append to
`CANON_GAPS_AND_ADDENDA_2026_05_02.md` after Codex reads.

### §23.5 Why ship in this order

Implementing the DAG before the seven subsystems are unified into one Rust
kernel means refactoring across Swift + Python + parallel-Rust simultaneously
— too many variables changing at once. The kernel doctrine collapses to one
Rust kernel. THEN the DAG collapses the seven subsystems inside that kernel.
Two compositions, one direction.

> First one binary. Then one DAG inside that binary. Then publish the paper.

### §23.6 Hackathon priority interaction (2026-05-03)

User pivoted on 2026-05-03 to prioritize hackathon: Hermes XPC + multi-CLI
integration AND Simulation Mode v1.6 with full assets (Companion creation/
delete/restore, adapter UI per Invariant I-11, Landing Farm = home window,
Notes Sidebar Skin). The Substrate-foundational sprint (Phases 1-7 + Phase 8)
is paused until the hackathon ships. Codex paused at clean stopping point.
The four §23 docs are sitting on disk for resumption after hackathon.

### §23.7 Substrate Track Register (canonical feature register)

**Canonical:** `docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md`

16 tracks across 4 zones — every feature in the Substrate captured exactly
once with status, tier, hackathon priority, and pointer to its master-index
section. Vocabulary discipline: "Track" T0-T15 = feature areas; "Lane A/B"
= git branches (existing master-index convention, unchanged). Substrate-
total roll-up: ~30% by milestone weight as of 2026-05-03.

Zones:
- **Zone A (Foundation):** T0 Substrate Unification, T1 Foundation, T2 Provenance + Sovereign, T3 Hardening
- **Zone B (Killer Features):** T4 Resonance Gate, T5 Hermes [BLOCK A], T6 Simulation [BLOCK B]
- **Zone C (Surface):** T7 Local MLX, T8 Halo, T9 Editor, T10 Graph, T11 UX
- **Zone D (Deployment + Research):** T12 App Store / Phase R+S, T13 Multi-Agent, T14 Ternary Research, T15 ANE Direct

---

## 24. XPC Mastery Doctrine — Defense in Depth for MAS (added 2026-05-03)

**Canonical:** `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md`

The doctrine for how the unified Rust kernel ships across XPC service
boundaries with Apple-grade defense-in-depth posture. Three goals:
maximum MAS coverage via least-privilege per-service entitlements; maximum
native + safe + trust via per-service code-signature attestation and
capability-token IPC; maximum private + audited via AgentEvent logging
across boundaries (becoming typed DAG edges in Phase 8).

### §24.1 Five-service decomposition

| Service | Trust class | Entitlements (only) |
|---|---|---|
| Main App | UI + in-process MLX inference (per CLAUDE.md NO SIDECAR) + Sovereign Gate | `app-sandbox`, `application-groups`, `files.user-selected.read-write`, `files.bookmarks.app-scope` |
| VaultXPC | Filesystem | `app-sandbox`, `application-groups`, `files.bookmarks.app-scope` |
| AgentXPC | Kernel runtime (agent_core, tools, Hermes, skills, procedural memory, provenance, resonance, search) | `app-sandbox` only |
| ProviderXPC | Cloud network | `app-sandbox`, `network.client` only |
| WASMExecXPC | Sandboxed user code execution (wasmtime + Pyodide + QuickJS) | `app-sandbox`, `cs.allow-jit` (isolated to this service), additional `sandbox_init()` profile inside |

### §24.2 Ten masterclass patterns

1. Five services with per-service entitlements files (least-privilege architecture reviewers approve fast)
2. `SecStaticCodeCheckValidity` trust attestation in every listener (rejects fake peer connections)
3. Capability-token IPC (every cross-service call gates on typed signed scoped expiring token)
4. Sandbox-within-sandbox for WASM (App Sandbox + wasmtime sandbox + sandbox_init() profile = three lines of defense for arbitrary user code)
5. Cross-XPC AgentEvent audit trail (every boundary crossing logged to canonical provenance ledger)
6. Hardware-attested capability tokens via Secure Enclave key requiring biometric per-use
7. Process recycling on hygiene timer (4 hours uptime / 10K messages default)
8. IOSurface zero-copy for high-frequency paths (60-1000+ msg/sec inference streaming over XPC)
9. Cognitive DAG integration (Phase 8 forward — XPC crossings become typed Merkle-signed edges)
10. Per-service test harness (smoke + integration + stress per service)

### §24.3 Phase placement

Phases X.1-X.5 fold INTO kernel doctrine Phases 1-7, not as a separate
sprint. ~3-4 weeks of work distributed across the 7-week kernel sprint.
XPC mastery is woven into the kernel doctrine work, not deferred to V2.

### §24.4 Reference architecture

Apple's own apps to study: Safari (`WebContent.xpc`, `Networking.xpc`,
`GPU.xpc`), Mail (per-protocol XPC), Notes (CloudKit XPC isolation),
Xcode (SourceKit-LSP as XPC). All implement varying degrees of the
patterns above; Epistemos implements all 10.

### §24.5 Open questions

- InferenceXPC explicitly NOT created — MLX-Swift stays in Main App per CLAUDE.md NO SIDECAR (perf > isolation for inference)
- HermesOrchestratorXPC may start physically co-located with AgentXPC, but the Hermes trust contract stays named, tested, provenance-visible, and ready to split when provider/cloud planning needs a separate boundary
- Secure Enclave key device-bound — migration UX for a new Mac is required product work, not a downgraded security compromise
- JIT entitlement App Review risk → ship Pulley interpreter fallback baked in (10-50× slower) so binary still works if Apple rejects allow-jit
- launchd-managed vs bundled: bundled `Contents/XPCServices/` is the default MAS-safe trust spine; LaunchAgents / daemons are additive only for outlive-app, other-client, root, or system-extension requirements

### §24.6 No-compromise XPC research intake

**Canonical sidecar:** `docs/fusion/XPC_RESEARCH_INTAKE_2026_05_04.md`

The user's latest XPC / sandbox / ExtensionKit / System Extensions / biometrics
research is adopted as a required sidecar to XPC Mastery. It is not a date gate
or V1 shortcut. Future XPC/Hermes/native-integration briefs must preserve:

- bundled XPC trust spine under `Contents/XPCServices/`
- symmetric `setCodeSigningRequirement(_:)` before `resume()`
- `NSXPCInterface.setClasses` / schema whitelists and payload size caps
- no PID-based trust decisions
- coordinated App Group naming, provisioning, signing, and built-entitlement verification
- MAS / Pro compile-time separation without weakening MAS peer validation
- Secure Enclave / `.biometryCurrentSet` vault-key semantics
- ExtensionKit / App Intents / Spotlight / Quick Look / Credential Provider as clients of the same capability boundary

---

## 25. Schema-First GenUI Doctrine — One Pipeline, Many Views (added 2026-05-03)

**Canonical:** `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md`

The fourth sub-track of T0 Substrate Unification (alongside Cognitive
Kernel, Cognitive DAG, XPC Mastery). Every command, tool, agent
response, mutation, and external system event in Epistemos produces a
typed `GenUIPayload`; the `GenUIDispatcher` routes payload schemas to
registered renderers; renderers know nothing about producers and
producers know nothing about renderers. **No more per-command UI code.**

### §25.1 Why this lives in canon now

The Four-Model Advice Council (2026-04-22) consensus included
"schema-first GenUI" as Substrate-foundational work. Three sessions
later, no GenUIDispatcher exists — every new producer keeps writing
per-call-site UI code because the dispatcher is "still doctrine-target".
This doc breaks that cycle by giving the work an explicit place in the
Track Register, a 24-day cost ceiling, a six-phase plan (G.1–G.6), and
a deferral-list discipline (§9 of the doctrine doc) that catches every
new producer that bypasses the dispatcher.

### §25.2 What's already there (partial implementation)

`Epistemos/Models/Artifact.swift` (`ChatArtifactKind` 7-variant enum +
`Artifact` struct) + `Epistemos/Views/Chat/ArtifactBlockView.swift` +
`Epistemos/Engine/ArtifactExtractor.swift` already implement the
pipeline for **cloud model response content blocks**. This is the seed.
The G phases generalize it to all producers and all renderers.

### §25.3 What's missing

- `GenUIDispatcher` static registry mapping schemas to renderer types
- Schema set generalized beyond chat-block kinds (need `keyValueTable`,
  `commandReceipt`, `actionPanel`, `errorReport`, `progressIndicator`,
  `capabilityList`, `searchResultSet`, `provenanceTrace`)
- Producers outside cloud-response path don't emit payloads
- Cross-runtime payload serialization (Rust agent_core ↔ Swift)
- Doctrine linter to enforce that new producers go through the dispatcher

### §25.4 Phase plan (G.1–G.6, 24-day hard ceiling)

1. **G.1** — Generalize the schema (1-3 days)
2. **G.2** — Build the dispatcher (1-3 days)
3. **G.3** — Migrate existing producers (3-7 days; priority order:
   Hermes Expert Mode → Approval Modal → Provenance Console → Daily Brief / Welcome Back)
4. **G.4** — Cross-runtime payload serialization via UniFFI (2-5 days)
5. **G.5** — Cognitive DAG integration (1-3 days, after Phase 8 ships)
6. **G.6** — Doctrine linter Rust crate (1-3 days)

### §25.5 Deferral discipline (THIS is what kept it from getting lost)

Every PR that adds a per-command renderer must include either:
- A `GenUIDispatcher` migration alongside it (preferred), OR
- A `// GENUI-DEFER:` comment + a row appended to the deferral list
  in §9 of `COGNITIVE_GENUI_DOCTRINE_2026_05_03.md`

The Hermes Expert Mode work (slices 1-8 / 2026-05-03) added per-command
renderers under explicit `GENUI-DEFER: hackathon-2026-05-03` per this
discipline; those renderers migrate to the dispatcher when G.3 lands.

The current deferral list (canonical at `COGNITIVE_GENUI_DOCTRINE` §9):

| Surface | Migration phase |
|---|---|
| Hermes Expert Mode renderers (`HermesExpertModeRunner.swift`) | G.3 priority 1 |
| Approval Modal payload | G.3 priority 2 |
| Provenance Console (when shipped) | G.3 day-1 |
| Daily Brief render path | G.3 priority 4 |
| Welcome Back render path | G.3 priority 4 |
| All Phase X.1-X.5 XPC service responses | G.4 day-1 |

---

## 26. MAS-First Focus Doctrine — Pro Stays In The Plan, Not On The Critical Path (added 2026-05-03)

**Canonical:** `docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md`

**Adopted 2026-05-03 by explicit user instruction.** The active surface
is MAS-shippable only; the Pro/Developer-ID build is part of the plan
but on hold; the architecture stays Pro-ready via feature-gated stubs.

### §26.1 The active surface (every agent works on these)

Hermes XPC bridge, sandboxed XPC services (AgentXPC / VaultXPC /
ProviderXPC / WASMExecXPC), biometric stack (Sovereign Gate / Secure
Enclave / capability tokens), Apple FoundationModels, MLX-Swift
in-process inference, cognitive substrate (T0: Kernel + DAG + XPC
Mastery + GenUI), Simulation Mode v1.6 / Companion Farm, Provenance
Console, Vault, Halo, Resonance Gate.

### §26.2 The deferred surface (PART OF THE PLAN, NOT ON THE CRITICAL PATH)

Endpoint Security extension, NEAppProxy / NetworkExtension,
Authorization Plugin, native CLI passthrough (claude/codex/gemini/kimi),
native shell, Docker, native Python/Node subprocess, external user-
installed MCP servers, iMessage osascript bridge, /run, /shell, /kill,
/execute Hermes commands.

**These remain in canon.** Listed in `HermesCapabilityRegistry.all`
with `tier: .pro`. Captured in `PRO_TO_CORE_MIGRATION_2026_05_03.md`.
WILL ship — just not now.

### §26.3 The build-flag pattern (mandatory)

- **Rust:** `#[cfg(feature = "pro-build")]` blocks; default cargo
  build = `--no-default-features --features mas-build`
- **Swift:** `#if PRO_BUILD` blocks; OTHER_SWIFT_FLAGS=-DPRO_BUILD
  only in the (deferred) Release-Pro Xcode configuration
- **Xcode:** System extension targets exist in pbxproj, unchecked in
  the MAS scheme's Build action
- **Entitlements:** `Epistemos-AppStore.entitlements` +
  `Epistemos-Pro.entitlements` live as separate files; never merge

### §26.4 The discipline

When you encounter a Pro-only surface during a refactor: do not delete,
do not "clean up." Add the gate, add the descriptive comment, leave the
geometry. PRs that want to REMOVE Pro-only code require explicit user
sign-off — never a quiet delete.

### §26.5 The phrase

> *"Part of the plan, not on the critical path."*

Use this when an agent or a future session asks whether to work on a
deferred surface. The answer is no — but the geometry stays.

### §26.6 The agent instruction (paste verbatim into Codex / handoff prompts)

See `MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md` §4 for the full text.

---

## 27. Canonical Recovery Plan — No-Compromises Sequence (added 2026-05-03)

**Canonical:** `docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md`

**Adopted 2026-05-03 by explicit user instruction** when the
hackathon push was abandoned: *"i give up on the hackathon ngl so
lets just continue with the real stuff... i want to make sure
whatever cut corner we did to buy time need to be canonical back to
no compromises."*

The recovery doc names every shortcut taken during the hackathon
push (Hermes UI ships without a real Hermes runtime; Simulation uses
SF Symbols where DOCTRINE specifies custom-drawn body grammars;
adapter UI animates a gift box but no LoRA actually swaps; etc.)
and maps each one to its canonical destination phase in the existing
doctrine docs. **The shortcuts are symptoms of canon-debt; the
recovery is to ship the canon in its doctrinally-correct order.**

### §27.1 Recovery sequence (no compromises)

- **Stage A — Foundation** (must ship first)
  - A.1 = `COGNITIVE_KERNEL_DOCTRINE` Phase 1 audit (the first move)
  - A.2 = `COGNITIVE_GENUI_DOCTRINE` Phase G.1 (generalize schema)
  - A.3 = `COGNITIVE_GENUI_DOCTRINE` Phase G.2 (build dispatcher)
  - A.4 = `COGNITIVE_GENUI_DOCTRINE` Phase G.3 priority 1
          (migrate Hermes Expert Mode renderers — biggest unwind)
- **Stage B — Hermes runtime in Rust**
  - B.1 = `COGNITIVE_KERNEL_DOCTRINE` Phase 2 (Hermes-in-Rust)
  - B.2 = Apple FoundationModels integration
  - B.3 = `COGNITIVE_KERNEL_DOCTRINE` Phase 6 (capability lattice)
- **Stage C — XPC services** (deferred until paid Apple Developer Team)
  - C.1-C.3 = `XPC_MASTERY_DOCTRINE` Phases X.1-X.3
- **Stage D — Cognitive DAG**
  - D.1-D.3 = `COGNITIVE_DAG_DOCTRINE` Phases 8.A, 8.B, 8.D
- **Stage E — Simulation assets**
  - E.1 = author `SIMULATION_ASSETS_DOCTRINE_2026_05_XX.md`
  - E.2 = implement custom-drawn body renderers (Canvas + Metal)
- **Stage F — Restore App Group + ship MAS** (after paid team added)

### §27.2 The five-question PR discipline

Every PR from this point on declares: Stage / GenUI route /
Sovereign / Pro impact / TEMP-FREE-TIER. Five honest answers or it
doesn't ship.

### §27.3 The TEMP-FREE-TIER + GENUI-DEFER lists are canonical

Recovery plan §3 + §4 maintain the single source of truth for what
gets restored / migrated when their gating prerequisites land
(paid Developer Team for App Group; G.2 dispatcher for GENUI-DEFER).
`grep -rn 'TEMP-FREE-TIER'` and `grep -rn 'GENUI-DEFER'` MUST
return exactly the items in those lists.

### §27.4 What stays as-is

Recovery plan §6 names the canon-compliant work that survived the
hackathon push (Sovereign Gate routing, AgentEvent provenance via
canonical recorder, HermesCommandDispatcher.parseCore, Cargo
features pattern, all four T0 doctrine docs, DeterministicPRNG
seeding, CompanionState + CompanionModel SwiftData spine, Sovereign
Gate routing in CompanionDeleteSheet/RestoreSheet). Each gets a
`// CANON-COMPLIANT 2026-05-03` marker comment.

### §27.5 The first move

Stage A.1 — Cognitive Kernel Phase 1 audit. Doc work, ~2-4 focused
hours, produces `COGNITIVE_KERNEL_AUDIT_2026_05_XX.md`. Without it
every subsequent stage risks duplicating or missing existing canon.

### §27.6 The single sentence

> *"The hackathon shortcuts were a symptom; the canon-debt is the
> cause; the recovery is to ship the canon in its doctrinally-
> correct order — A.1 audit, A.2-A.4 GenUI, B.1 Hermes-in-Rust,
> C XPC, D DAG, E assets, F MAS — and the symptoms unwind on their
> own."*

No compromises. No shortcuts. Stay canonical with the build docs.

---

## 28. Canonical Unification Inventory — Worktrees + Non-Fusion Promoted (added 2026-05-04)

**Canonical:** `docs/fusion/CANONICAL_UNIFICATION_INVENTORY_2026_05_04.md`

**Adopted 2026-05-04 by explicit user instruction** to scan all
worktrees + non-fusion canon and unify into the fusion folder.

### §28.1 Today's promotions (now in `docs/fusion/`)

`docs/fusion/simulation/`:
- `DOCTRINE.md` — 1,982-line canonical Simulation Mode v1.6 doctrine
  with **16 invariants** (I-1 through I-16; I-15 prohibits AnyView in
  hot paths; I-16 is bit-perfect pixel rendering for pixel-art only)
- `IMPLEMENTATION.md` — 2,597-line slice-by-slice build plan with
  FFI three-tier strategy + Metal rendering (instanced quads +
  texture array + IOSurface + bit-perfect)
- `SESSION_KICKOFF.md` — session-start protocol
- `character-dna/` — five Character DNA files (`block_compact`,
  `block_wide`, `orb`, `sage`, `hermes_snake`) with per-frame
  animation specs and 13-state per-companion state machines

### §28.2 Pointed-at (canonical, lives outside fusion)

- `docs/_consolidated/00_canonical_authority/` — **23 TOP CANON files**
  including `PLAN_V2.md`, `MASTER_BUILD_PLAN.md`,
  `IMPLEMENTATION_PLAN_FROM_ADVICE.md`, `KNOWN_ISSUES_REGISTER.md`,
  `MASTER_HARDENING_AND_HARNESS_PLAN.md`, `SKILL_IMPLEMENTATION_PLAN.md`,
  `ambient_V1_DECISION.md`
- `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md` — Halo V1 stack canon (T8)
- `/Users/jojo/Downloads/EPISTEMOS-HERMES-PARITY-PLAN.md` — Hermes
  parity canonical implementation map (already pointed-at from
  CODEX_RECOVERY_HANDOFF)
- 5 worktrees beyond simulation carry per-worktree deltas; map in
  `CANONICAL_UNIFICATION_INVENTORY` §2.5

### §28.3 Critical doctrinal findings from the unification

- **GenUIDispatcher uses `AnyView` — violates Simulation DOCTRINE I-15
  in hot paths.** Needs typed-render variant or cold-path-only
  classification.
- **Body grammar is parameterized** (Block has compact + wide variants
  per §5.1), not the fixed 4-case enum the hackathon Companion Farm
  shipped.
- **Hermes Snake is the graph faculty** (DOCTRINE §8.1, hovers above
  graph plane z+1), not a Companion Farm citizen — current
  implementation is doctrinally misplaced.
- **Hermes references "canonical NousResearch SVG art"** explicitly
  (`character-dna/hermes_snake.md`) with Epistemos-fallback
  substitution allowance per §8.2.1 — confirms HERMES_BRAND_DOCTRINE
  intent.

### §28.4 Updated recovery estimates

- **Stage E.1 collapses to 0 days** — Simulation doctrine already
  exists and is now in fusion
- **Stage E.2 grows to 3-5 weeks** — implementation spec is richer
  than estimated (instanced Metal quads + per-companion 13-state
  animation + sprite atlas + bit-perfect rendering)
- **GenUIDispatcher I-15 fix** added as 1-2 day item

### §28.5 The phrase

> *"Canon found, not authored — it was on disk; we just hadn't
> looked hard enough yet."*

### §28.6 Worktree prototype canon queue

**Canonical:** `docs/fusion/WORKTREE_PROTOTYPE_CANON_FUSION_QUEUE_2026_05_04.md`

Added after the user's clarification that every worktree should be treated as
high-value research/prototype authority until inspected. The queue keeps the
anti-bulk-copy rule, but upgrades worktree handling from "consult only" to a
Track-mapped promotion list:

- Tools V2 alias/dispatch anchor and migration status
- ExecutionReceipt + Sovereign Gate capability mapping
- Capture routing classifier + Resonance Gate direction component
- Heal-loop 30-case fixture extraction
- Honest-handle FFI doctrine
- PLAN_V2 sections 23-27 architectural-law recovery
- AgentEvent v1.6 variants
- Prompt Tree Lane A bridge
- Five Laws + Phase I Rust agent migration
- Recipe cache branch bridge
- Release-stabilization branch bridge
- Worktree fusion brainstorm / selective-port strategy

The first live code anchor is `agent_core/docs/TOOL_MIGRATION_STATUS.md` plus
`ToolRegistry::execute_v2` compatibility dispatch. Two bridge docs now preserve
the next Quick Capture contracts before implementation:
`agent_core/docs/EXECUTION_RECEIPT_DOCTRINE_MAPPING.md` and
`agent_core/docs/CAPTURE_ROUTING_CLASSIFIER.md`. The first heal-loop fixture
bridge is `agent_core/tests/heal_loop_fixtures.md`; it preserves the donor
30-case corpus while recording the donor exit-gate contradiction. The first
D-series FFI promotion is
`docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md`, which names the
refcounted opaque-handle ownership rule already partly live in main.
`docs/fusion/PLAN_V2_SECTIONS_23_27_RECOVERY_2026_05_04.md` preserves the
editor truth audit, 16ms agent-stream coalescing, graph typed-buffer/zero-copy
gate, and anti-pattern register while superseding PLAN_V2's old Box-owned
syntax handle detail with honest-handle ownership.
`docs/fusion/AGENT_EVENT_VARIANTS_V16_2026_05_04.md` records the six
Simulation v1.6 forward variants already present in Swift provenance and the
remaining Rust `agent_core::events` gap.
`docs/fusion/PROMPT_TREE_LANE_A_BRIDGE_2026_05_04.md` records that
`/Users/jojo/Downloads/Epistemos-laneA` is an active 601-commit N1
prompt-as-data worktree whose foundation files are present in current main but
whose `ChatCoordinator`/Rust bridge/provider telemetry deltas still require
reconciliation before any "merged" or "default-on" claim.
`docs/fusion/FIVE_LAWS_AND_PHASE_I_2026_05_04.md` preserves the
`codex/runtime-memory-hardening` branch's Five Laws, substrate sprints, and
Phase I Rust-agent migration lens while subordinating its older phase order to
current fusion recovery. `docs/fusion/CODE_EDITOR_FEATURE_TRUTH_2026_05_04.md`
and `docs/fusion/RESOURCE_RUNTIME_PHASE_R_BRIDGE_2026_05_04.md` promote the
runtime-input-audit branch's editor truth and Phase R resource/verified-write
contracts. `docs/fusion/RECIPE_CACHE_RECOVERY_BRIDGE_2026_05_04.md` records
that `agent_core/src/storage/recipe_cache.rs` is already present in main and
needs cache-policy/provenance wiring rather than a branch cherry-pick.
`docs/fusion/RELEASE_STABILIZATION_BRANCH_BRIDGE_2026_05_04.md` records that
the release-audit skill and March closure prompts are already present in main
and should feed Stage F only. `docs/fusion/WORKTREE_FUSION_BRAINSTORM_2026_05_04.md`
is the selective-port strategy for turning salvaged worktree prototypes into
current-main code without raw merges. Full native `Tool` trait migration remains
staged; do not raw-copy `v2_catalog/`.
