---
state: canon-target
created_on: 2026-05-24
purpose: Canonical statement of the no-compromise local-AI endgame: run larger, smarter, dense agentic models by making model internals addressable substrate objects and routing verified active neural assemblies instead of treating the LLM as an opaque language-only reasoner.
production_status: Not a production claim. This canonizes the target architecture and vocabulary. Runtime activation of neural/component routing requires the falsifiers listed below.
local_anchors:
  - docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md
  - docs/fusion/SHADOW_PROJECTION_AND_RESEARCH_CONSTRUCTION_2026_05_24.md
  - docs/fusion/AETHERLINK_OAS_CANON_INTAKE_2026_05_30.md
  - docs/fusion/AETHERLINK_ERDOS_PARAMETER_GOLF_INTAKE_2026_05_30.md
  - docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md
  - docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md
  - epistemos-research/src/five_planes.rs
  - epistemos-research/src/goodfire_vpd_specs.rs
  - agent_core/src/uas/mod.rs
  - agent_core/src/uas/kind.rs
  - agent_core/src/helios/packet_router.rs
---

# Addressable Neural Substrate Canon — 2026-05-24

## 0. The crux

The no-compromise endgame is not "use a better prompt," "use MoE," or "use subquadratic attention."

It is:

> **Epistemos turns a dense model into an addressable neural substrate. An SSM/state router selects active assemblies of layers, rank-one components, KV pages, adapters, residual islands, and kernels; the residency governor pages only that working set into UMA; verification proves the selected path preserves dense/reference behavior within a budget.**

This is the user's "dormant brain neuron pull" architecture made explicit in the index.

## 1. What the app is calling

The app is not merely calling an opaque LLM endpoint. In the target architecture it calls a governed substrate packet:

```text
MissionPacket
  + ActiveAssemblyPacket
  + NeuralSubstrateAddressSet
  + ResidencyPlan
  + KernelRoute
  + Claim/AnswerPacket schema
  + SCOPE-Rex/SovereignGate admission proof
  + falsifier budget
```

The LLM remains present, but it is no longer the sole reasoning engine. It is one substrate operator among:

- SSM state router
- dense model residual path
- KV/cache page store
- parameter-connectome / component atlas
- adapters
- EML / Geometry / Scan / Operator / Info IR
- Metal kernels
- vault / graph / vector memory
- SCOPE-Rex/SovereignGate + WBO + AnswerPacket verification

## 1A. AetherLink / OAS sharpening

The AetherLink application kit adds a useful name for the same substrate
movement: **Ontological Address Space**. In Epistemos terms, OAS is not a
replacement for UAS. It is the semantic/control layer on top of UAS:

```text
UAS = where the addressed bytes/state live.
OAS = what the addressed thing means, what floor state it starts in, and what
      contract may promote it.
ColdStore / ResidencyGovernor = whether the thing may become resident or active.
SCOPE-Rex / SovereignGate = whether the claim, route, or state transition is
      witnessed, permitted, and allowed to commit.
```

This matters for the large-model route because "SSD holds the model" is not
enough. The model must be broken into addressed cognitive/runtime units:

```text
WeightBlockManifest
  + UAS address
  + byte range / content hash
  + lattice / ternary / NF4 / residual-island encoding
  + residency tier
  + active-assembly selector key
  + WBO drift budget
  + dense/reference rollback
```

AetherLink therefore reinforces the current build order: create the
manifest/residency simulator before launching another full 128K or 70B probe.

The Erdos / Parameter Golf intake adds the construction rule for that
simulator:

```text
lift the model into addressed weight/KV/component charts
  -> search a budgeted active set
  -> project to an executable active assembly
  -> carry WBO/copy/memory witnesses and dense rollback
```

Agents must not treat "SSD holds the model" as a proof. The proof surface is a
`ResidencyPlan` with a falsifier-backed memory/copy/WBO budget.

Range-hash prerequisite:

```text
F-WeightBlockRangeHash-DryRun
  artifact: artifacts/falsifiers/weight_block_range_hash_dry_run/result.json
  result: bounded fixture range hashed, over-limit rejected before read,
          short-reader rejected, known-hash manifest valid, no model file touched
```

First planner witness:

```text
F-ResidencyPlan-DryRun
  artifact: artifacts/falsifiers/residency_plan_dry_run/result.json
  result: 72 GiB cold addressed bytes, 872,415,232 active runtime bytes,
          zero runtime model bytes loaded, overall_pass=true
```

Scope guard: this proves budgeted active-set planning only. It does not prove
live KV-Direct, MLX/Metal execution, or 70B generation.

Hardening landed with the first witness:

- bounded model-range hashing (`from_reader_range`) uses 64 KiB chunks and a
  caller-provided max byte limit;
- known-hash range manifests (`from_known_hash_hex`) allow precomputed model
  range hashes without loading the range into RAM;
- `F-WeightBlockRangeHash-DryRun` proves the range-hash ABI on a tiny fixture:
  over-limit ranges reject before read, short readers fail closed, and no
  model file is touched;
- `ConstructionCard` turns ProblemCard / LiftChart / ProjectionPacket /
  Witness / Budget / Falsifier / Rollback into a checked UAS object tied to a
  passed `ResidencyPlan` and records the upstream
  `F-WeightBlockRangeHash-DryRun` -> `F-ResidencyPlan-DryRun` proof chain.
- `ProviderReferenceManifest` makes the next 70B comparison gate replayable:
  local fp16 references must stay local-only under the 70B row root, hosted
  receipts must use zero-retention request/redaction digests, and a mere path
  existing on disk no longer counts as a reference. It also separates
  `shape_only_fixture` from `prompt_level_comparison`, requires prompt-suite
  digest binding, and requires at least 50 prompts for prompt-level references,
  so retained ABI fixtures cannot accidentally satisfy the real 70B reference
  gate.

## 2. The addressable units

"Neuron cluster" should be implemented as a typed addressable unit, not a vague metaphor.

| Unit | Practical meaning | UAS kind / home | Current posture |
|---|---|---|---|
| Layer block | transformer or SSM block, including fragile dense layers that must not be quantized | State plane | target |
| Rank-one component | Goodfire/VPD-style decomposed model feature or subcomponent | `UasKind::ModelComponent` / Assembly plane | atlas evidence; runtime candidate |
| KV page | attention cache region, hot/warm/cold | `UasKind::KvPage` / L3 SSD Oracle | file-backed mmap residency witness passes; live KV-Direct harness still red |
| Weight block | file-backed model byte range, possibly compressed/lattice-coded | future `WeightBlockManifest` over `UasKind::ModelComponent` / `KvPage` until a dedicated kind exists | next safe build surface |
| Adapter delta | LoRA/DoRA/Titans-MAC/L_SE small mutable specialization | L_SE research lane | research construction |
| Residual island | dense islands preserved inside otherwise ternary/quantized route | State plane | research target |
| Activation mask | selected active subset for current pass | Assembly plane | candidate |
| Kernel route | MLX, Metal, Rust, Scan-IR, EML kernel, ternary GEMM | Controller plane | mixed |
| Evidence/proof surface | AnswerPacket, RunEventLog, WBO, Lean/EML certificate | Verification plane | partially wired |

## 2A. LLM-address granularity ladder

This ladder is canon for how precise an agent may be when it says Epistemos "addresses the model." Builders must name the exact row they touch.

| Granularity | What the substrate addresses | Status today | Build/status |
|---|---|---|---|
| Whole-model call | model identity: MLX, GGUF, Apple Intelligence, explicit provider, local SSM lane | live default | MAS / Pro Live |
| Output schema | allowed shapes emitted by the model: JSON schema, tool grammar, AnswerPacket schema | partial | MAS / Pro Live |
| KV cache page | short-term model memory addressed as hot/warm/cold page | substrate exists; harness pending | Pro Gated |
| Weight-bit layout | Sherry/Leech, ternary, NF4, dense residual island | research / promotion candidate | Pro Research |
| Adapter delta | LoRA/DoRA/Titans-MAC/L_SE specialization over base model | research | Pro Research; Pro Gated only after rollback/eval gate |
| MoE expert | expert route inside a model that already ships MoE | model-internal; substrate observes/chooses model lane | MAS or Pro Live only when provider/runtime exposes it honestly |
| Active assembly | cross-cutting slice of model + KV + context + adapters + tools + kernels | research target | Pro Research |
| Attention head / SSM state | specific attention-head, QK slice, or recurrent scan-state region | research target | Pro Research |
| Parameter anchor | stable parameter subset or rank-one component address | research target | Pro Vault-Preserved / Pro Research |
| Cross-layer circuit | attribution circuit spanning multiple layers/components | research target | Pro Vault-Preserved / Pro Omega |

Do not claim a finer row than the code actually touches. If a PR routes a whole model, call it whole-model routing. If a PR pages KV, call it KV-page routing. If a PR manipulates rank-one components or circuits, it belongs in research until the matching falsifier passes.

## 3. The five-plane execution path

This is the canonical route for large local models:

```text
User intent
  -> State plane
       SSM / hybrid-SSM semantic spine predicts whether normal decode is enough
  -> Assembly plane
       Gate3 / PacketRouter1bit / connectome anchors select active neural assembly
  -> Episodic plane
       vault, graph, KV pages, theorem witnesses, tool traces, claim ledgers load exact support
  -> Controller plane
       ACS admits route, tool calls, mutation, kernel promotion, and fallback
  -> Verification plane
       WBO, AnswerPacket, ClaimKind, RunEventLog, falsifier artifacts, Lean/EML proof check drift
```

The SSM is the language/state router the user remembered. It is not just a faster sequence model; it is the low-cost recurrent spine that decides when to fire attention, retrieval, tool use, connectome lookup, adapter route, or dense fallback.

## 4. Why this can run larger dense models

The architecture tries to beat the local-memory wall through **working-set activation**, not by pretending the model is small.

The dense model's identity may still be large. What becomes small per step is:

- resident weight/component set
- active KV pages
- active context
- active adapters
- active kernels
- proof/citation surface

Canonical memory stack:

```text
L0  RAM hot          current active assembly
L1  RAM compressed   Sherry / ternary / residual-compressed blocks
L3  SSD Oracle       mmap-backed NF4 / KV / cold model pages
L5  Network Cascade  rare outlier fallback
L_SE Self-Evolving   bounded adapter deltas, never blind base-model mutation
```

The target is a dense 70B-class model whose cold substrate can live on SSD while the current active assembly behaves like a small model in RAM.

## 5. Difference from MoE and subquadratic attention

| Technique | What it changes | What Epistemos changes |
|---|---|---|
| MoE | model architecture has trained experts | runtime makes dense model internals addressable and selectively resident |
| Subquadratic attention | attention algorithm cost | whole substrate working set: model state, KV, context, tools, kernels, proof |
| RAG | retrieves documents | retrieves and verifies typed substrate support, including model/KV/component state |
| Quantization | compresses weights | compresses with WBO, residency, rollback, and dense/reference drift checks |
| Speculative decoding | drafts tokens faster | becomes one route in a governed assembly with verifier and fallback |

Epistemos can use all of these, but the master idea is above them: **address, route, page, execute, verify**.

## 6. EML's exact role

EML is critical but not the whole ontology.

Correct statement:

> **EML is the formal elementary-function/proof chart inside the substrate. UAS is the address space. PCF/connectome is the neural-component atlas. WBO is the error ledger. SCOPE-Rex/SovereignGate is the admission layer. ColdStore/ResidencyGovernor owns cold residency. AcsAnchor owns anchored coordinate/provenance. ShadowProjection is the lift/project contract.**

EML can certify:

- EML-IR lowering
- elementary-function kernels
- morph/eval witnesses
- math-lab/self-proving derivations
- parts of kernel correctness where the domain is formalizable
- eligible weight/layer transforms when they can be lowered into elementary
  charts or certified typed shadows

No-compromise reading of "EML is everything":

> Every substrate operation should expose a canonical IR chart when possible.
> EML is the elementary-function chart; Geometry-IR and Scan-IR are co-equal
> charts for metric/connection and recurrent-state structure. A model layer,
> weight block, KV page, or neural component is therefore either an EML tree,
> a Geometry/Scan/Operator shadow, or an explicitly opaque object with a UAS
> address, residency plan, WBO budget, and witness.

EML does not make every pixel, vector, KV page, or model component literally an EML tree today. Those objects become "the same data" because they share UAS addressing, plane placement, residency, WBO policy, and witnesses, and because every eligible transform is pushed toward EML/Geometry/Scan lowering instead of being left as an untyped blob.

## 7. Verification gates

This target architecture is canonical, but runtime activation is gated:

| Gate | Meaning | Required before claiming |
|---|---|---|
| `F-Sparse-Runtime-Split` | selected sparse/active assembly reproduces dense execution within bounded drift | neural assembly routing works |
| `F-KV-Direct-Gate` | SSD/mmap/residual KV path matches full hot KV reference | L3 SSD Oracle works |
| `F-UAS-CopyCount` | no hidden tensor copies across Swift/Rust/Metal/MLX hot paths | zero-copy substrate works |
| `F-UAS-ACS-MmapResidency` | deterministic file-backed mmap bytes round-trip through UAS address, residency lease, and AcsAnchor projection lookup | Legacy-named witness proving one file-backed UAS + AcsAnchor/ColdStore-style residency slice |
| `F-WeightBlockRangeHash-DryRun` | explicit model byte ranges can be fingerprinted within a caller-provided bound and fail closed | future large-model manifests cannot hash/load huge ranges accidentally |
| `F-ResidencyPlan-DryRun` | active model-shaped weight blocks fit memory/WBO/rollback budgets before runtime | large-model probes are pre-gated instead of crash-first |
| `F-ActiveAssembly-Minimal` | selected support is small but sufficient | active routing is useful |
| `F-ULP-Oracle` | EML/Metal arithmetic floor is within tolerance | proof/kernels safe enough |
| `F-70B-Local-Cocktail` | 70B-class local run meets quality, RAM, latency budget | the capability ceiling is real |

Until these pass, this is a canonical target and research program, not a shipped capability.

Current nuance: `F-UAS-ACS-MmapResidency` is green as a Verified Floor slice,
but `F-KV-Direct-Gate` and `F-70B-Local-Cocktail` remain red. The SSD/RAM
ambition is preserved; it is not yet a live model-generation claim.

## 8. Agent rule

Any agent touching local inference, model routing, Active Assembly, KV, adapters, EML kernels, or "large local model" claims must cite this doc and answer:

```text
Neural substrate check:
- What model unit is addressed? layer | component | KV page | adapter | residual island | activation mask | kernel route
- What UAS address pattern identifies it?
- What plane owns it?
- What residency tier stores it?
- What router selects it?
- What dense/reference path verifies it?
- What falsifier gates the claim?
- What rollback path restores dense/MLX baseline?
```

Missing answers mean the PR is not preserving the no-compromise architecture.

## 9. Stopped-terminal resume addendum

The existing seven production terminals A-G keep their original ownership, but each must carry this neural-substrate lens:

| Terminal | Motion classification | Required extra field |
|---|---|---|
| A — Eidos | Lift vault source into citation substrate; project citation back to chat | witness coordinate per citation |
| B — VaultRecall + AnswerPacket | Project substrate trace into visible chat row | lift coordinate carried on every provenance card |
| C — System G | Mutate/Promote mission into AnswerPacket | `construction_space_radius` remains candidate until real run path is stable |
| D — Substrate Health | Project substrate state into Settings | chip flips consume T0 honesty signal only |
| E — ACS Admission | Mutate/Promote verdict on every durable action | verdict distinguishes `lift_allowed`, `lift_denied`, `lift_quarantined` when RCE arrives |
| F — Falsifiers | Project measurement into artifact | include F-Sparse-Runtime-Split, F-KV-Direct-Gate, F-UAS-CopyCount, F-UAS-ACS-MmapResidency, and F-70B-Local-Cocktail in planning |
| G — T14 UAS bridge | all three motions | owns UAS fields for `ShadowProjection` and neural substrate address sets |

This addendum prevents the old A-G prompts from drifting while allowing T0/T1/S/H/R/X to extend the deck around them.
