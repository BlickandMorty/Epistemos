---
state: candidate-canon
created_on: 2026-05-31
source_prompt: frontier-style reasoning on 16 GB hardware with Epistemos
status: architecture doctrine; requires falsifier evidence before product claims
---

# Frontier-Style Reasoning On 16 GB Hardware

## The correction

The target is not a literal trillion-parameter dense model resident inside
16 GB system memory. Current evidence does not support that claim.

The target is:

> **Cold trillion, hot five billion, active minimum.**

Epistemos should be able to address a very large cold atlas of parameters,
adapters, KV pages, evidence, notes, graph islands, theorem artifacts, and
tool plans while keeping only the smallest sufficient working set hot. The
local model is one organ in that substrate. The substrate decides which bytes
deserve residency.

Companion routing source:
`docs/fusion/NEURAL_IMPORTANCE_ROUTING_ATLAS_2026_05_31.md` defines how the
system predicts which weights, heads, MLP blocks, adapters, KV pages, kernels,
and verifiers deserve to wake for each task.

Companion working-set compiler source:
`docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md` defines how source
signals, Eidos route priors, KV lineage, neural importance, and constructive
residency compile into a `SemanticWorkingSetPlan`, `ResidencyPageTable`,
`PrefetchWindow`, `ColdFaultTrace`, `MmapResidencyFence`, and
`KVByteBudgetCard`. This is the new L15 bridge: a huge cold atlas matters only
when each mission can predict, budget, prefetch, observe, and learn from the
working set it actually used.

Companion trace-observatory source:
`docs/fusion/SUBSTRATE_TRACE_OBSERVATORY_2026_06_01.md` defines how the
frontier-local route becomes debuggable. `CognitiveTraceGraph`,
`RouteMicroscopeFrame`, `AttentionKVTrace`, `TraceComparisonDeck`,
`TelemetryToWorkingSetPatch`, and `VisualProofCapsule` make each selected
page, cache, model route, source, verifier, tool action, and cold fault
replayable and AnswerPacket-visible.

Companion residency source:
`docs/fusion/CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01.md` defines how the
70B cocktail becomes a proof-carrying `ColdAssemblyPlan`, not a dense resident
blob. Its implementation vocabulary is `ResidencyConstructionGraph`,
`CoactivationTile`, `LatticeStateController`, `ProofCarryingResidencyLease`,
`ReasoningStateContinuityCard`, and `ColdMissLedger`.

Companion cache-lineage source:
`docs/fusion/CACHE_LINEAGE_AUTORESEARCH_PARADIGM_2026_06_01.md` defines how
persistent KV/prefix units, compatibility fences, cache admission, execution
traces, and Pareto tournaments become active cold-state feedback rather than
hidden runtime leftovers.

Companion note/editor math source:
`docs/fusion/MATH_AND_PORTABLE_NOTE_SYSTEMS_INTAKE_2026_06_01.md` defines how
editor deltas, projection digests, incremental parse forests, differential
views, FSRS review, constrained decoding, Git lineage, and Markdown sidecars
keep the evidence substrate portable and fast.

Companion engineering-logic source:
`docs/fusion/ENGINEERING_LOGIC_ARCHITECTURE_INTAKE_2026_06_01.md` defines how
each ambitious route becomes a DecisionRecord, InvariantLedger,
BoundaryContract, BudgetVector, FailureEnvelope, ObservabilityProbe, rollback,
and falsifier before it claims live authority.

Companion sparse-route compiler source:
`docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md`
defines how a tiny `RouteScoutSSM` proposes `SparseWakeProposal`s,
`VerifierBudgetAuction` keeps them under budget, `QueryAwareKVSelector`
selects history pages, and `VerifierRegretFastWeights` improves the scout
only through proof/test/citation/trace regret. This is the L17 bridge from
"which model brain region?" to a measured sparse wake policy.

Companion Residency PatternBoost source:
`docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md` defines how
offline/idle construction tournaments over `UASAssemblyGenome`s discover,
repair, fingerprint, archive, and distill reusable resident assembly motifs.
This is the L20 bridge from one-off route guesses to a library of held-out
winners that a live scout can use or abstain from without claiming dense 70B
hot residency.

Companion ColdStream transport source:
`docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md` defines how
predicted cold bytes move through `TransportRunManifest`,
`PageRunScheduler`, `SlabArena`, `MetalBufferLease`, `CodecStage`,
`TransportTrace`, and `ColdPanicFallback` instead of surprise mmap faults.
This is the L18 bridge from cold addressability to token-safe transport.

This preserves the original no-compromise ambition but makes it physically
honest: SSD and mmap do not become RAM; they become a cold semantic address
space whose useful pages are predicted, promoted, verified, and evicted.

The stronger storage interpretation is `AppColdStore`: keep durable model
snapshots, packed weight pages, adapter banks, KV seeds, route cards, and cache
manifests in Epistemos-managed Application Support / App Group storage, while
using purgeable cache roots only for regenerable warm packs. The speed gain is
layout, locality, prewarm, and copy control; it is not a claim that app storage
changes NVMe latency.

## Hardware arithmetic

The M2 Pro 16 GB floor is bandwidth-rich but memory-tight. Apple Silicon UMA
helps with copy avoidance, not total capacity.

Approximate weight-only storage:

| Model size | 4-bit weight storage | 1.58-bit weight storage | 16 GB implication |
|---|---:|---:|---|
| 5B | ~2.5 GB | ~0.99 GB | Plausible hot active set. |
| 10B | ~5 GB | ~1.98 GB | Plausible only with tight KV/runtime budgets. |
| 32B | ~16 GB | ~6.32 GB | On the cliff edge at 4-bit before KV/cache/app overhead. |
| 70B | ~35 GB | ~13.83 GB | Not comfortable as a resident 16 GB dense path. |
| 1T | ~500 GB | ~197.5 GB | Cold-addressable only, not resident. |

Therefore the design question is not "can a trillion parameters fit?" It is:

1. What is the smallest active parameter/state set for this task?
2. Which cold pages/adapters/KV blocks should be promoted before they are
   needed?
3. Which verifier proves the selected path preserved enough behavior?
4. Which rollback path reverts the selection when it fails?

### Constructive residency overlay

The stronger 70B route is constructive, not merely offloaded. Epistemos should
search for a resident assembly that earns its bytes:

```text
MissionPacket
  -> Eidos evidence + TaskSignature
  -> PrefixReuseRouter / KVCompatibilityFence
  -> ResidencyConstructionGraph
  -> CoactivationTile / ReasoningStateContinuityCard / KVPrefixUnit candidates
  -> ColdAssemblyPlan
  -> ProofCarryingResidencyLease
  -> ActiveAssembly + NeuralImportanceAtlas
  -> SCOPE-Rex / SovereignGate
  -> RuntimeRouter
  -> ExecutionTraceCapsule
  -> RunEventLog + AnswerPacket
  -> ColdMissLedger / ParetoResidencyTournament
```

The source signals are Axplorer/PatternBoost for iterative construction
search, Lattice Deduction Transformers for tiny lattice-state control, SwiftLM
for Apple Silicon SSD expert streaming and KV compression motifs, Letta for
stateful continuity, and Apple LLM in a Flash / PowerInfer / vLLM / LMCache /
KTransformers for cold layout, activation locality, paging, and cache reuse.

This adds L11-Candidate, the Constructive Residency Law: local capability
scales with the quality of the selected resident assembly, not with the
largest parameter count simultaneously hot.

### Cache-lineage and editor-math overlay

The active-cold route must learn from what the app already did:

```text
Note edit / source update
  -> EditorDeltaMonoid
  -> ReadableProjectionFunctor
  -> DifferentialKnowledgeView
  -> Eidos evidence
  -> CacheAdmissionCard and ColdAssemblyPlan updates
```

This adds L12-Candidate, the Cache-Lineage Law: persistent state is useful
only when saved prefill/cold I/O and continuity exceed staleness,
incompatibility, privacy, storage-wear, and verification cost.

It also adds L13-Candidate, the Delta Projection Law: every visible view should
be maintained as the smallest verified delta from a durable source, not by
rebuilding the whole document, graph, index, or model context.

It also adds L14-Candidate, the Engineering Logic Law: a mechanism enters
architecture only when its invariant, owner, state transition, budget, failure
mode, witness, and rollback are explicit.

## Research synthesis

### 1. Capacity and active parameters separate

Sparse and MoE work separates total capacity from active parameters. That
supports Epistemos's ColdStore / ActiveAssembly doctrine, but it does not by
itself solve 16 GB residency. Even a large sparse model can have too many
active bytes when KV cache, activations, app overhead, and runtime buffers are
counted.

Architecture consequence:

- Avoid claiming "local frontier MoE" from total parameter count.
- Track `total_addressable`, `hot_resident`, and `active_executed` separately.
- Every large-model route must report active bytes, hot bytes, cold bytes, KV
  bytes, and verifier cost.

### 2. KV/state is the hidden local-reasoning tax

PagedAttention, KIVI, ShadowKV, StreamingLLM, MLA, TransMLA, and MHA2MLA all
point toward the same lesson: long reasoning is often blocked by runtime
state, not only checkpoint size.

Architecture consequence:

- Treat KV pages as first-class UAS objects.
- Prefer MLA-style latent KV, 2-bit/asymmetric KV, paged KV, attention-sink
  anchoring, and key/value asymmetry before launching bigger dense models.
- `F-KV-Direct-Gate` and `F-Qwen3-8B-128K-GGUF-Route` are not side quests;
  they are central architecture gates.

### 3. Offloading works only when scheduled

FlexGen-style GPU/CPU/disk hierarchy and PowerInfer-style activation locality
support the intuition that cold model material can remain outside hot memory.
They do not support token-by-token SSD thrashing.

Architecture consequence:

- ColdStore must promote pages at block/expert/adapter/KV granularity, not
  per-token desperation reloads.
- `ResidencyPlan` must include reuse horizon, prefetch window, eviction policy,
  and rollback.
- A route fails if its cold pages become synchronous token-latency blockers.

### 4. Adapters are the first practical growth mechanism

QLoRA, DoRA, X-LoRA, Mixture-of-LoRA, and S-LoRA-like serving patterns support
the idea that Epistemos can grow through versioned specialist adapters without
mutating the always-hot base model.

Architecture consequence:

- Successful repair traces should become candidate adapter data, not silent
  weight mutation.
- Adapters must be content-addressed artifacts with UAS address, domain,
  training/eval manifest, rollback, and SCOPE-Rex admission status.
- Adapter selection is an ActiveAssembly decision.

### 5. Reasoning quality comes from loop + verifier, not only size

DeepSeek-R1, s1, self-consistency, decoding-time verification, and related
test-time scaling work support a system-level inference policy: generate
multiple candidate paths, retrieve evidence, run verifiers, repair failures,
then emit an AnswerPacket.

Architecture consequence:

- The Hyperdynamic Repair Loop is the real reasoner.
- The model is a proposer, planner, compressor, or critic inside a governed
  loop.
- The verifier must be strong enough; weak verifiers do not magically turn
  small models into frontier systems.

### 6. Fast weights stay research, not first proof

Mamba-2, TTT, Titans, and other test-time memory/state mechanisms are strong
canon matches for the self-evolving-kernel intuition. They should remain in
Pro Research until a bounded local harness proves benefit under the 16 GB
budget.

Architecture consequence:

- Fast-weight / learned-state memory belongs behind explicit Pro Research
  falsifiers.
- Parameter Connectome execution remains a ceiling, not a live product claim.
- Use Mamba/SSM/low-KV models first as controller/runtime candidates, not as
  proof that a giant model is locally solved.

## New candidate law

### L9-Candidate: Cold-Atlas Working-Set Law

For a local cognitive substrate on 16 GB hardware, capability scales with the
quality of the selected working set, verifier loop, and residency policy more
than with simultaneously resident parameter count.

Informal form:

```text
Capability ≈ f(controller, active_support, cold_atlas, verifier, repair_loop)
subject to:
hot_bytes + kv_bytes + runtime_bytes + app_bytes <= safe_memory_budget
```

Promotion condition:

- A local Epistemos route beats a baseline local dense model on deep research,
  note reasoning, code, or math tasks at lower hot/resident bytes.
- The route emits citations, repair logs, active-set manifest, and rollback.
- The win survives held-out prompts and does not depend on hidden cloud calls.

## Breakthrough simulation: the 16 GB hard-gate game

This section is deliberately hypothetical. It is a design-game for what would
have to be true to make consumer hardware feel frontier-style without violating
physics.

### Game board

The machine has a hard 16 GB system-memory gate. The app, OS, graphics,
editor, graph, vault, buffers, Metal workspace, model runtime, and KV/cache
state all compete for that same pool. The breakthrough route must therefore
act like a cockpit, not a warehouse:

```text
Always-hot cockpit:
  controller model
  schemas / routers / verifier stubs
  active note/evidence patch
  current KV/state strip
  tiny adapter mix

Warm runway:
  prefetched KV pages
  likely adapter/expert blocks
  candidate evidence bundles
  precompiled kernels

Cold atlas:
  model blocks
  adapter bank
  parameter anchors
  archived KV/state pages
  note corpus
  citation corpus
  theorem/falsifier artifacts
```

The game is won only if the hot cockpit stays small while the cold atlas feels
intelligently reachable.

### Winning budget

A plausible 16 GB breakthrough target should reserve memory before it dreams:

| Bucket | Target ceiling |
|---|---:|
| OS + app + SwiftUI/AppKit/Metal surfaces | 2.5-3.5 GB |
| Always-hot controller | 2.0-5.0 GB |
| KV/state working strip | 1.0-3.0 GB |
| Active evidence / graph / note patch | 0.5-1.5 GB |
| Adapter/expert active mix | 0.25-1.5 GB |
| Metal/runtime/workspace buffers | 1.0-2.0 GB |
| Safety margin | 2.0+ GB |

This implies a brutal rule: any route that cannot explain its memory budget
before execution is not allowed to execute.

### The simulated breakthrough

The breakthrough is not one trick. It is a stacked maneuver:

1. **Low-KV controller.** A small dense, hybrid SSM/Transformer, or MLA-like
   controller stays hot. It is trained or prompted to route, compress,
   plan, verify, and repair, not to contain all knowledge.
2. **Semantic page table.** Every note, vector, KV page, adapter, model block,
   theorem artifact, citation, and tool plan has a UAS address and cold/hot
   residency record.
3. **Predictive active support.** Before generation, ActiveAssembly builds a
   support set: which evidence, which adapters, which KV/state pages, which
   kernels, which verifier tools, and which route budget.
4. **KV first, model second.** Long-context pressure is attacked with latent
   KV, quantized KV, paged KV, attention-sink anchors, and state summaries
   before increasing model size.
5. **Adapter as memory.** Durable learning becomes a versioned adapter or
   route policy, not a silent mutation to the base weights.
6. **Verifier as second brain.** The model proposes. The harness tests,
   retrieves, proves, rejects, repairs, and emits an AnswerPacket.
7. **No synchronous cold panic.** Cold pages must be warmed ahead of the next
   expensive step or skipped. A cold miss is a planning failure, not a reason
   to stall every token.

If these seven moves work together, a 7B-10B hot controller can behave larger
than itself because it does not have to remember, verify, and specialize
alone.

### The four missing inventions

#### 1. The neural page table

The system needs a `NeuralPageTable` that treats model state as addressable
substrate:

```text
NeuralPage {
  uas_address
  artifact_kind: weight_block | kv_page | adapter | expert | state_summary
  byte_range_or_blob_hash
  codec
  expected_reuse_horizon
  promotion_cost
  verifier
  rollback_ref
}
```

This is the bridge from "model file" to "active neural substrate." Without it,
ColdStore is just storage. With it, ColdStore becomes a memory hierarchy the
reasoner can plan over.

#### 2. The active-set compiler

The system needs an `ActiveSetCompiler` that compiles a user request into a
bounded execution patch:

```text
MissionPacket
  -> EvidencePatch
  -> AdapterPatch
  -> KVStatePatch
  -> KernelPatch
  -> VerifierPatch
  -> ActiveSetManifest
```

The compiler's job is not to find everything relevant. Its job is to find the
smallest support set that can survive verification.

#### 3. The reasoning escrow

The system needs a `ReasoningEscrow`: a temporary chamber where candidate
answers, tool calls, retrieved evidence, adapter suggestions, and note
mutations can exist before they are allowed to touch durable state.

This is how the app becomes powerful without becoming reckless. Nothing
becomes memory until SCOPE-Rex/SovereignGate admits it with a witness.

#### 4. The adapter distillery

The system needs an `AdapterDistillery` that turns repeated verified repairs
into tiny specialist artifacts:

```text
repair traces
  -> cleaned training packet
  -> adapter candidate
  -> eval manifest
  -> rollback pointer
  -> Pro Research status
  -> Pro Gated only after repeated wins
```

This is the "app grows" mechanism. The base stays stable; the user's verified
life/research/work accretes into small, inspectable deltas.

### The impossible things that remain impossible

The simulation does not permit these shortcuts:

- SSD latency disappears.
- 1T dense weights are resident on 16 GB.
- 70B dense 4-bit is comfortable on 16 GB.
- A weak verifier makes weak reasoning strong.
- A cold atlas counts as intelligence unless selected pages are used and
  measured.
- Parameter-connectome claims become product claims without rollback and
  falsifier evidence.

### The actual breakthrough sentence

If this works, the consumer laptop does not become a frontier datacenter. It
becomes a **frontier-style reasoning instrument**: a small hot controller with
a huge cold atlas, a verified memory system, a repair loop, and a habit of
turning successful reasoning into reusable specialist structure.

That is the category difference. Not "bigger model locally." Instead:

> **local cognition by governed active support.**

## Simulated execution trace

User asks a hard neuroscience/math research question.

1. `MissionPacket` classifies it as deep-research + possible math proof.
2. UAS resolves candidate notes, papers, claims, prior contradictions, and
   theorem artifacts.
3. ActiveAssembly builds a 400 MB evidence patch instead of loading the whole
   vault.
4. The controller requests three reasoning traces under `ReasoningBudget`.
5. KV/state policy keeps only the active strip hot; older context becomes
   compressed summaries or paged state.
6. Adapter policy selects a neuroscience-reading adapter and a math-proof
   adapter, each tiny and rollbackable.
7. Eidos checks citations and claim kinds.
8. Lean/schema/code verifiers run only on the claims that require them.
9. The repair loop rejects one trace, repairs one trace, and keeps one trace
   as a candidate.
10. SCOPE-Rex admits only the final AnswerPacket and any proposed note
    mutation.
11. Accepted repair traces are logged for possible adapter distillation.

The result feels smarter than the hot controller because the controller is
not acting alone. It is acting with memory, tools, citations, adapters, and
verifiers as one governed substrate.

## Required architecture objects

Any PR invoking this doctrine must name each object below:

| Object | Required fields |
|---|---|
| `ColdParameterAtlas` | model/expert/adapter/KV/block IDs, byte ranges, hashes, codec, license, source, retention |
| `ActiveSetManifest` | hot weights, hot KV, hot adapters, selected evidence, selected tools, active bytes |
| `ResidencyPlan` | prefetch order, reuse horizon, eviction, peak RSS estimate, fallback route |
| `ReasoningBudget` | max traces, max tokens, verifier calls, wall-clock bound, energy/memory ceiling |
| `VerifierStack` | tests, Lean/schema checks, citation checks, code execution, human approval if needed |
| `AdapterRegistry` | adapter lineage, training/eval data, SCOPE-Rex admission, rollback pointer |
| `AppColdStoreRouteCard` | durable/warm/hot storage placement, byte ranges, codecs, prewarm, cache rebuild, rollback |

## Falsifier additions

### F-ColdAtlas-WorkingSet

Passes only if a cold-atlas route:

- reports `total_addressable_bytes`, `hot_resident_bytes`, `active_executed_bytes`,
  `kv_bytes`, `adapter_bytes`, and `peak_rss_bytes`;
- keeps peak RSS under the declared M2 Pro 16 GB ceiling;
- performs no synchronous token-by-token cold reload loop;
- beats a declared local dense baseline on a held-out task suite; and
- emits `AnswerPacket`, `ActiveSetManifest`, `ResidencyPlan`, and rollback.

### F-KV-State-First

Passes only if a KV/state compression or paging route improves long-context
throughput or maximum context under equal quality constraints, while preserving
paired-logit or task-level parity against a dense/reference path within an
explicit WBO budget.

### F-Adapter-Growth-Loop

Passes only if accepted repairs or verified traces can produce a candidate
adapter artifact with source data, evals, rollback, and no silent mutation of
the base model.

### F-AppColdStore-Layout

Passes only if Epistemos-managed packed storage improves measured route cost
over raw installed model snapshots while preserving checksum, WBO, rebuild, and
rollback guarantees.

## Build placement

| Piece | Build/status |
|---|---|
| 7B-10B controller with conservative KV/runtime budget | MAS candidate only after soak/falsifier gates |
| 32B dense local path | Pro Gated, likely ≥32 GB or explicit opt-in |
| 70B dense local path | Pro Vault-Preserved / Pro Research until measured |
| Cold trillion atlas | Pro Vault-Preserved / Pro Research; addressable, not resident |
| KV/state compression | Pro Gated once verified; MAS only when safe/default behavior is proven |
| Adapter registry | Pro Research -> Pro Gated after rollback/eval gates |
| Parameter Connectome execution | Pro Vault-Preserved / Pro Omega until falsified upward |

## Source handles

Primary/public source handles to verify or cite when implementing:

- Switch Transformer / sparse trillion-parameter capacity
- DeepSeek-V2 / DeepSeek-V3 MLA and active-parameter separation
- DeepSeek-R1, s1, self-consistency, decoding-time verification
- PagedAttention / vLLM, KIVI, ShadowKV, StreamingLLM
- TransMLA / MHA2MLA
- FlexGen, PowerInfer, MoE offloading systems
- GPTQ, AWQ, BitNet
- QLoRA, DoRA, X-LoRA, Mixture-of-LoRA, S-LoRA
- Mamba-2, TTT, Titans
- Axiom Axplorer / PatternBoost and Lattice Deduction Transformers for
  offline resident assembly tournaments and lattice-state abstention gates

Verified spot-checks during intake:

- `arXiv:2502.07864` TransMLA claims MLA conversion and 93% KV compression
  on LLaMA-2-7B with reported 10.6x speedup at 8K.
- `arXiv:2502.14837` MHA2MLA frames MLA as KV-cache compression into latent
  vectors and proposes data-efficient transition from MHA/GQA to MLA.
- `arXiv:2303.06865` FlexGen explicitly aggregates GPU, CPU, and disk memory
  and reports OPT-175B on a 16 GB GPU at low throughput for batched/offline use.
- `arXiv:2402.02750` KIVI is a tuning-free asymmetric 2-bit KV-cache
  quantization method.
- `arXiv:2501.12948` DeepSeek-R1 supports the claim that reasoning can be
  improved through RL/test-time behavior rather than parameter count alone.
- `arXiv:2402.07148` X-LoRA supports dynamic mixing of LoRA adapter experts.

## Final sentence

Epistemos should not try to be a tiny machine pretending to hold a giant
brain. It should be a small always-hot controller over a huge cold
parameter-and-memory atlas, where reasoning quality comes from active support,
retrieval, verification, repair, and continual specialization.
