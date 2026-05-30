---
state: candidate_intake
created_on: 2026-05-30
source_kit: /Users/jojo/Downloads/AETHERLINK_APPLICATION_KIT_FULL/AETHERLINK_APPLICATION_PROJECT
purpose: Fold the AetherLink / OAS / AletheiaFS research kit into Epistemos without diluting the current large-model capability-ceiling route or promoting aerospace/speculative claims into product canon.
priority: preserve the 70B-class UAS/ACS residency ambition; use AetherLink as a proof-carrying runtime lens, not as a replacement roadmap.
---

# AetherLink / OAS Canon Intake - 2026-05-30

## 0. Verdict

The AetherLink kit is aligned with the strongest Helios/Epistemos doctrine:

> Models propose. The runtime verifies. The ledger remembers. Unsafe or
> unsupported claims are quarantined.

Companion intake:

```text
docs/fusion/AETHERLINK_ERDOS_PARAMETER_GOLF_INTAKE_2026_05_30.md
```

Use the companion when AetherLink work touches Research Construction Engine,
ShadowProjection, Erdos/unit-distance motifs, Parameter Golf, compression
search, or 70B local cocktail planning.

It should be ingested as a **Research Construction / proof-carrying runtime
addendum**, not as a new product direction that displaces the large-model
substrate work. The current Epistemos priority remains:

```text
large model capability ceiling
  = UAS/ACS mmap residency
  + weight/KV/component addresses
  + active assembly routing
  + lattice / ternary / NF4 compression
  + WBO drift checks
  + AnswerPacket / SCOPE-Rex verification
  + rollback to dense/reference path
```

AetherLink sharpens the language for this: it calls the same thing a
proof-carrying coordinate-state runtime.

## 1. Local Kit Inventory

Source directory:

```text
/Users/jojo/Downloads/AETHERLINK_APPLICATION_KIT_FULL/AETHERLINK_APPLICATION_PROJECT
```

Load-bearing files:

| Kit file | Intake role |
|---|---|
| `README.md` | public-safe thesis: proof-carrying coordinate kernel |
| `AETHERLINK_MASTER_PACKET.md` | master synthesis and application packet |
| `docs/02_ARCHITECTURE_SPEC.md` | module map: coordinate addressing, SMC, field maps, certificates, gate, ledger |
| `docs/04_CLAIM_LEDGER.md` | status discipline and speculative-physics quarantine |
| `docs/06_SPECULATIVE_PHYSICS_QUARANTINE.md` | DROP boundary for antigravity / zero-latency / perfect optimality |
| `schemas/aether_packet.schema.json` | candidate packet ABI related to AnswerPacket |
| `schemas/control_certificate.schema.json` | candidate control-certificate ABI |
| `src/aether_runtime.py` | tiny packet verifier / quarantine demo |
| `src/l_kernel_smc.py` | toy SMC proposal-kernel falsifier |
| `kernels/*.metal` | candidate kernels for particle weighting and sparse routing |
| `formal/AetherLink.lean` | proof-obligation skeleton |

Do not vendor these into app targets yet. Mine motifs, then reimplement through
Epistemos's existing UAS / ACS / AnswerPacket / SCOPE-Rex surfaces.

Light local smoke, 2026-05-30:

```text
python3 src/aether_runtime.py examples/aether_packet_demo.json
=> ok=true, errors=[], warnings=[]

python3 src/l_kernel_smc.py
=> bootstrap_ess=401.36, lkernel_ess=440.32,
   bootstrap_mse_proxy=0.1975, lkernel_mse_proxy=0.2226
```

Nuance: the toy proposal improved effective sample size in this run, but the
MSE proxy worsened. Therefore the grounded claim is "proposal kernels can be
benchmarked for degeneracy/latency/error," not "the L-kernel is already better
on every metric."

## 2. Term Mapping

| AetherLink / OAS term | Epistemos home | Status |
|---|---|---|
| Ontological Address Space / OAS | UAS address + SCOPE-Rex state + ACS admission proof | canon-aligned target |
| AletheiaFS sidecar | Vault / Live Files / UAS index sidecar over normal files | Research Construction candidate |
| AetherPacket | AnswerPacket / ClaimKind / RunEventLog packet specialization | candidate ABI |
| Control certificate | Proof-carrying AnswerPacket / verifier report | candidate ABI |
| SMC L-kernel | estimator/router motif for active assembly and state prediction | EB; demo-gated |
| Implicit field map / INR | Geometry-IR / Scan-IR / coordinate chart motif | EB; not product |
| HJ/HJB layer | simulator/control research motif | EV/EB externally; not app runtime |
| Safety-weighted regret curriculum | WBO-prioritized falsifier repair loop | canon-aligned motif |
| SCOPE-Rex proof gate | existing `agent_core/src/scope_rex` and AnswerPacket verification plane | canon |
| seL4 | external high-assurance precedent only | EV precedent; not a dependency |

## 3. What This Changes For The Large-Model Route

The user's priority is not "make a normal RAG index." The priority is the
addressable neural substrate:

```text
SSD cold model bytes
  -> UAS WeightBlockAddress / KvPageAddress / ModelComponentAddress
  -> ACS admission and residency lease
  -> active assembly selector
  -> lattice / ternary / NF4 decode route
  -> dense/reference drift check
  -> AnswerPacket provenance
```

AetherLink's OAS language adds a missing middle artifact:

```text
WeightBlockManifest
  model_id
  file_uri
  byte_range
  content_hash
  encoding: dense | nf4 | ternary | sherry | leech | residual_island
  uas_address
  residency_class: hot_uma | warm_compressed_uma | cold_mmap_ssd
  residency_tier: verified_floor | capability_ceiling
  ir_chart: eml | geometry | scan | operator | info | opaque_with_witness
  wbo_budget
  verifier
  rollback_reference
```

This is the next safe build surface before any more 65K/128K/70B probes. It
lets the app prove that a candidate active set would fit the 16 GB floor before
touching the crash-prone Metal path.

Initial ABI landed in:

```text
agent_core/src/uas/weight_block.rs
```

The first version is intentionally non-executing: it validates byte ranges,
hashes model bytes, emits a `UasKind::ModelComponent` address, records encoding
and residency class, stores WBO/verifier/rollback metadata, and refuses empty or
unbounded manifests. It does not decode weights or claim live 70B inference.

## 4. What Fine-Tuning Can And Cannot Do

Fine-tuning is useful, but it is not the bridge.

| Layer | Owned by runtime | Learned / tuned model may help |
|---|---:|---:|
| file hashes, byte ranges, model-weight manifests | yes | no |
| UAS addresses and ACS admission | yes | no |
| schema validation and packet shape | yes | no |
| state contracts and memory commits | yes | no |
| claim extraction / labels / summaries | maybe | yes |
| local-model rendering | no | yes |
| final truth decision | yes | no |

Correct doctrine:

> Engineer truth into the runtime. Fine-tune obedience into the model. Use
> schemas as the ABI between them.

For the large-model route, this means LoRA/QLoRA can teach a model to speak
AnswerPacket/OAS/WeightBlockManifest fluently, but only the runtime may commit
addresses, state transitions, safety gates, or verifier results.

## 5. Public-Research Grounding

These sources support the grounded parts of the AetherLink kit. They do not
validate speculative propulsion claims.

| Motif | Source | Intake stance |
|---|---|---|
| Learned safety certificates | [Dawson, Gao, Fan, arXiv:2202.11762](https://arxiv.org/abs/2202.11762) | EV/EB for control research; demo-gated locally |
| Adaptive SMC proposal kernels | [Cornebise, Moulines, Olsson, arXiv:1108.2836](https://arxiv.org/abs/1108.2836) | EV/EB for estimator motif; no "99%" claim without local measurement |
| Neural HJB approximation | [Jiang, Chou, Chen, Tomlin, arXiv:1611.03158](https://arxiv.org/abs/1611.03158) | EV/EB for bounded simulation; no exact/zero-latency claim |
| High-assurance microkernel precedent | [seL4 Verification](https://sel4.org/Verification/) and [seL4 Proofs](https://sel4.systems/Verification/proofs.html) | EV precedent; proof scope depends on platform/configuration/assumptions |

## 6. DROP / Quarantine Boundary

The following stay out of product claims and application copy:

- antigravity
- gravitophoton propulsion
- cosmological geodesic synchronizer
- zero-copy spacetime interface
- zero latency
- infinite precision
- perfect optimal control
- flight-critical readiness

They may exist only as speculative notebook entries with `DROP` or `C` status,
never as MAS / Pro / SpaceX-facing claims.

## 7. Build Order Integration

Do not move AetherLink ahead of the current capability ceiling cursor. It
changes the shape of the next safe slice:

1. Preserve the current 32K heavy-run guard.
2. Extend `WeightBlockManifest` into a `ResidencyPlan` simulator over local
   model files.
3. Add a simulator/falsifier that reads local model metadata and proves a
   proposed active set fits under the 16 GB memory floor without launching the
   model.
4. Connect manifest rows to existing UAS kinds:
   `ModelComponent`, `KvPage`, and future `WeightBlock` if added.
5. Only then revisit KV-Direct or GGUF/Metal 128K probes.

## 8. Canon Check For Agents

Any future PR touching AetherLink / OAS / AletheiaFS must answer:

```text
AetherLink/OAS check:
- What addressable object is being added: file, chunk, claim, KV page, weight block, model component, control proposal?
- What UAS kind identifies it?
- What floor state does it start in?
- What contract can promote it?
- What verifier rejects it?
- What ledger event records it?
- What model, if any, is only a proposer/renderer?
- What falsifier proves the local claim?
- What rollback keeps the current app safe?
```

Missing answers mean the work is not canon-preserving.
