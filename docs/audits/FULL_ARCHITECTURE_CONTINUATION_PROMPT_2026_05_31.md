# Epistemos Full Architecture Continuation Prompt

Use this prompt when continuing full-architecture work in
`/Users/jojo/Downloads/Epistemos`.

You are working on Epistemos, a local cognitive substrate. Do not reduce it to
a chatbot, notes app, model wrapper, MLX demo, or EML-only system. The spine is:

```text
Intent
  -> MissionPacket / CognitivePacket
  -> UAS/OAS address resolution
  -> ColdStore / AppColdStore residency candidates
  -> ActiveAssembly minimal waking set
  -> Eidos evidence and route-prior validation
  -> SCOPE-Rex / SovereignGate governance
  -> RuntimeRouter / System G execution
  -> Eidos post-validation and repair
  -> RunEventLog + AnswerPacket visible proof
```

## Non-Negotiable Architecture Locks

- UAS is the primitive identity fabric.
- OAS is semantic meaning/state over UAS addresses.
- ColdStore is dormant residency. Do not abbreviate it as ACS.
- `AcsAnchor` remains the coordinate/provenance anchor name.
- SCOPE-Rex and SovereignGate own admission, verdicts, and action governance.
- ActiveAssembly wakes the smallest useful set for the task.
- Eidos is evidence/search/citation selection and can now emit route priors.
- EML is one Primitive-IR chart for elementary functions; it is not the whole
  substrate.
- MLX is one execution runtime lane; it is not the architecture.
- Helios is lineage/umbrella language; product truth names the concrete organ.
- MAS and Pro are the only distributable builds.
- Research, Vault, Omega, heavy runtime, and future model-substrate work are
  Pro statuses, not separate app builds.

## Current Build Grammar

```text
ProductBuild = MAS | Pro
ProStatus =
  Live
  | Gated
  | ResearchCandidate
  | VaultPreserved
  | Omega
  | Blocked
  | TargetOnly
  | Superseded
```

Every architecture PR or doc claim must state:

```text
Motion, Organ, Identity, Plane, ProductBuild, ProStatus/ResidencyStatus,
ErrorBudget, Witness, Admission, Route, Visibility, Verification, Rollback.
```

## Local Frontier Ambition Lock

Do not assume the 16 GB consumer-hardware route is impossible just because a
literal dense resident frontier model does not fit. Preserve the architectural
hypothesis:

```text
cold trillion, hot five billion, active minimum
```

The app-owned SSD/AppColdStore atlas can hold much more addressable cognition
than RAM. The runtime wins by choosing the right cold pieces before they become
hot: notes, graph neighborhoods, KV pages, prompt caches, adapters, weight
pages, verifier tools, primitive-IR kernels, and future parameter components.

## Rigor Lock

Do not claim SSD is RAM. UAS makes cold bytes addressable and routable; it does
not erase latency. Promotion requires:

- packed AppColdStore layout;
- cache and prewarm strategy;
- active-byte accounting;
- peak UMA, SSD read, and copy-count measurements;
- Eidos evidence/citation validity;
- route cards with rollback;
- verifier-guided repair;
- RunEventLog and AnswerPacket visibility;
- falsifier artifacts.

## Concurrency, Isolation, And Crash-Safety Lock

Performance is architecture, but optimization must preserve Swift 6 actor
isolation, Rust/FFI safety, and machine stability.

- Swift UI state remains `@MainActor @Observable`.
- Heavy work leaves the main actor only through typed snapshots, Sendable value
  packets, dedicated actors, detached utility tasks, Rust/Tokio workers, or
  MLX/Metal lanes with explicit ownership.
- `nonisolated(unsafe)` is a narrow compatibility escape hatch for known
  AppKit/FFI edges. It is not a general performance tool.
- MLX/GGUF/model/KV state must use a serialized executor, dedicated thread, or
  route-specific actor when the underlying object is not safely Sendable.
- Hot paths must declare caller actor, worker actor/thread, cancellation,
  debounce/coalescing, backpressure, copy-count expectation, and witness
  visibility when user output is affected.
- Kernel-panic-class unsafe testing is Pro Research/Omega only. Any probe that
  could panic macOS, wedge GPU/Metal, overpressure UMA, thrash mmap/SSD, corrupt
  a live model/KV store, or destabilize the machine must stay behind a
  crash-safe falsifier harness with dry-run witnesses and rollback. Do not run
  those probes from ordinary app work or the unattended loop.

## Eidos Neural Importance Bridge

Eidos can feed NeuralImportanceAtlas, but it must not become a hidden model
self-router.

```text
EidosContextPacket
  -> EidosRoutePrior
  -> TaskSignatureEmbedding
  -> NeuralImportanceAtlas lookup
  -> ParamRouteCard / AppColdStoreRouteCard
  -> ActiveAssembly support set
  -> RuntimeRouter execution
  -> RunEventLog + AnswerPacket
```

Eidos supplies evidence hits, `why_matched`, citation need, contradiction
hints, domain tags, and likely verifier/adapter/KV families. UAS/AppColdStore
binds candidate bytes. SCOPE-Rex/SovereignGate admits the route. Nothing wakes
model bytes without a route card.

Dynamic compute is allowed only as visible checkpoints:

- `EarlyExitCheckpoint`
- `SelfSpeculativeCheckpoint`
- `DepthBudgetGate`
- `KVRestoreCheckpoint`
- `AdapterSwapCheckpoint`
- `EidosInterruptCheckpoint`
- `VerifierRepairCheckpoint`
- `ControllerSSMCheckpoint`

No silent mid-kernel pause, hidden retry, or base-weight mutation.

## Promotion Gates

Relevant falsifiers:

- `F-Eidos-NeuralRoute-Prior`
- `F-ParamRouteCard-Admission`
- `F-DynamicCompute-Checkpoint`
- `F-NeuralImportanceAtlas`
- `F-HotRent-Stability`
- `F-Eidos-PostValidation-Repair`
- `F-AppColdStore-Layout`
- `F-UAS-CopyCount`
- `F-KV-Direct-Gate`
- `F-ActiveAssembly-Minimal`
- `F-PageGather-M2Pro`
- `F-70B-Local-Cocktail`

The local-frontier promotion rule is A/B/C/D:

```text
A = raw local model
B = conventional RAG
C = memory-optimized baseline
D = full Epistemos substrate route
```

`D` must beat `A`, `B`, and `C` on quality, evidence validity, active bytes,
latency, and visible proof before a local-frontier claim promotes.

## Work Order

1. Read `AGENTS.md`.
2. Read the Living Index and Master Research Index.
3. Read:
   - `docs/fusion/LOCAL_FRONTIER_PLAYBOOK_16GB_2026_05_31.md`
   - `docs/fusion/FRONTIER_LOCAL_REASONING_16GB_ARCHITECTURE_2026_05_31.md`
   - `docs/fusion/NEURAL_IMPORTANCE_ROUTING_ATLAS_2026_05_31.md`
   - `docs/fusion/EIDOS_NEURAL_IMPORTANCE_BRIDGE_2026_05_31.md`
   - `docs/audits/ARCHITECTURE_AUTOPILOT_PROMPT_2026_05_30.md`
4. Verify current code truth before changing anything.
5. Pick one small buildable unit.
6. Prefer code and falsifier surfaces over doctrine-only work.
7. If code is unsafe because another agent is touching it, update prompt/docs
   with exact scope and do not clobber.
8. Run focused verification.
9. Commit only your own scoped changes.

## Hard No-Drift Rules

- Do not create `AgentSearch`, `AgentMemory`, `AgentEvidence`, or
  `AgentCitation` as new authorities. Adapters must call Eidos/VaultRecall,
  UAS/AppColdStore, ActiveAssembly, SCOPE-Rex/SovereignGate, RunEventLog, and
  AnswerPacket.
- Do not mint a top-level architecture organ from a research phrase.
- Do not promote a feature because a doc says it exists.
- Do not claim arbitrary parameter control, live 1T execution, comfortable 70B
  on 16 GB, hidden cloud fallback, arbitrary ANE kernels, or SSD-as-RAM.
- Do preserve ambition as Pro Research / Pro Gated when it is falsifier-shaped.
- Do make user-visible proof the promotion threshold.

## End Report

Finish every session with:

```text
Inspected:
Changed:
Skipped:
Verification:
Commit:
Next:
```
