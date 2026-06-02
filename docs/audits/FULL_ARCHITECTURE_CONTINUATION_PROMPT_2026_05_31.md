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

Engineering logic overlay:

```text
DecisionRecord
  -> InvariantLedger
  -> StateMachineCard / BoundaryContract
  -> BudgetVector / HotPathProofCard
  -> FailureEnvelope / ObservabilityProbe
  -> MigrationRail / ImportGateCard when needed
  -> falsifier artifact
```

Semantic working-set overlay:

```text
SourceSignalGraph
  + EidosRoutePrior
  + KVLineageGraph
  + NeuralImportanceAtlas
  + ResidencyConstructionGraph
  -> TaskWorkingSetQuery
  -> SemanticWorkingSetPlan
  -> ResidencyPageTable
  -> PrefetchWindow
  -> RuntimeRouter execution
  -> ColdFaultTrace
  -> LayoutPatch / RoutePatch
```

Verifier-calibrated sparse-route overlay:

```text
TaskSignature
  + SourceSignalGraph
  + proof/citation/code/test need
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
```

ColdStream transport overlay:

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

## Semantic Working-Set Compiler

Read `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md` when a
session touches semantic working sets, UAS/AppColdStore, active cold storage,
70B cocktail, mmap residency, prefetch, page tables, KV-byte accounting,
source/bookmark/research trace routing, cache-derived layout patches, or "SSD
brain" claims.

Preserve the ambition: a large cold cognitive atlas can behave like a small,
fast active brain when each mission compiles to the right working set.

Preserve the rigor: SSD and mmap are addressability and layout tools, not RAM.
The plan must report selected units, active/hot/warm/cold/KV bytes,
compatibility fences, cold faults, fallback, rollback, and AnswerPacket proof.

The working-set primitive family is:

```text
SourceSignalGraph
TaskWorkingSetQuery
SemanticWorkingSetPlan
ResidencyPageTable
PrefetchWindow
WorkingSetOracleCard
ColdFaultTrace
LayoutPatch
MmapResidencyFence
KVByteBudgetCard
SourceToResidencyPatch
```

## Verifier-Calibrated Sparse Route Compiler

Read `docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md`
when a session touches Axiom/Axplorer/PatternBoost, Axiomatic AI AxProver,
OProver, proof construction loops, proof-pressure labels, sparse attention,
query-aware KV, RouteLLM-style routing,
DejaVu/PowerInfer-style contextual sparsity, LayerSkip/Mixture-of-Depths
dynamic compute, Titans/TTT fast weights, SSM route scouts, dynamic depth,
route-distillation tournaments, fast-weight quarantine, or "proper
weights/KV/neurons/params for the task."

Preserve the ambition: the app can learn to wake the right tiny support set
instead of treating the whole model as the decision maker.

Preserve the rigor: the scout must be cheaper than the route it controls, able
to abstain, budget every selected unit, learn only through bounded verifier
regret, and expose uncertainty, fallback, and rollback in AnswerPacket.

The sparse-route primitive family is:

```text
RouteScoutSSM
TwoStageRouteScout
BudgetedUncertaintyEscalator
SparseWakeProposal
VerifierBudgetAuction
KVPageSketchIndex
KVPageBloomSketch
QueryAwareKVSelector
LayerKVJointLease
ConstructionSearchTournament
RouteDistillationTournament
ProofSearchSignal
ProofPressureSignal
VerifierRegretFastWeights
FastWeightQuarantine
DepthLease
ShadowWakeOracle
AblationShadowRun
SparseWakeCertificate
```

## ColdStream Residency Transport

Read `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md` when a
session touches mmap, AppColdStore transport, SSD hot paths, page faults, cold
I/O, prefetch windows, Metal I/O, Dispatch I/O, file-backed KV/model pages,
page-run packing, copy-count claims, or claims that UAS/AppColdStore can move
cold model material fast enough for reasoning.

Preserve the ambition: ColdStore can be more than a passive file store if
predicted cold bytes move through explicit, cancelable, measured transport
before the hot path asks for them.

Preserve the rigor: mmap remains a useful addressability/fallback/baseline
tool. It is not counted as residency or token-safe throughput unless p95/p99
stall, read amplification, copy count, cache policy, cancellation, feature
gates, and fallback are measured.

The transport primitive family is:

```text
TransportRunManifest
PageRun
PageRunScheduler
SlabArena
MetalBufferLease
CodecStage
TransportTrace
ColdPanicFallback
```

## Mmap Replacement and Hot-Path Cure Atlas

Read `docs/fusion/MMAP_REPLACEMENT_AND_HOTPATH_CURE_ATLAS_2026_06_01.md`
when a session touches mmap replacement, SSD hot paths, cold I/O,
copy-count claims, "zero-copy" wording, graph render/physics state movement,
PageGather/KV page transport, Rust/Swift/Metal FFI records, hot JSON traces,
streaming buffers, note-editor performance, SHM/cache boundary materialization,
protocol JSON, or lattice/geometric execution alignment.

Preserve the ambition: backend compute, transport, proof, model/KV, trace,
search, and artifact hot paths can be made dramatically tighter by replacing
surprise faults and hidden copies with geometry-aware page runs, slabs, shared
rings, packet streams, and binary witness records.

Preserve the caveat: zero-copy is not a blanket UI rule. Multiple graph
surfaces, multiple editor surfaces, undo-safe TextKit storage, visual variants,
snapshots, previews, and user artifacts may keep intentional copies unless a
falsifier proves that copy is a compute/transport/proof hot-path fault.

Second-pass lock: Geometry-Aligned Execution. Keep mmap when it is a simple
addressability view or baseline; fence it when alignment, truncation,
mutation, resident-byte, fault, copied-byte, or cache-policy claims could be
misleading; replace it only when `HotPathCensus`, `MmapHazardFence`,
`ReadPlanMatrix`, `GeometryAlignedPageTable`, `CopyBudgetVector`,
`UnsafeBoundaryProofCard`, `ShmMaterializationWaiver`, `StreamFrameArena`,
`SpatialDirtyWindow`, and `ProtocolEdgeJsonWaiver` give the route a measured
plan, proof boundary, rollback, and intentional-copy waiver.

The hot-path primitive family is:

```text
IntentionalCopyWaiver
CopyClass
MmapKeepVsReplace
GeometricPageRunPlanner
GraphNodeStateRingPromotion
HotTraceBinarySummary
EventRingActivationCard
CopyCausalGraph
LayoutObjective
ProofHarnessCard
```

## Substrate Trace Observatory

Read `docs/fusion/SUBSTRATE_TRACE_OBSERVATORY_2026_06_01.md` when a session
touches trace observability, LLM/transformer visualization, attention or KV
visualization, mechanistic probes, heuristic neurons, model-route debugging,
route microscopy, agent action replay, source-grounded research UI, visual
proof, cold-fault diagnosis, or trace-derived policy/layout patches.

Preserve the ambition: Epistemos should let humans and future agents inspect
the actual route by which a local cognitive substrate selected sources, pages,
caches, tools, proof lanes, and model-state units.

Preserve the rigor: a visualization is not proof. Promotion requires
redaction, replay, diagnosis, byte/token/cost fields, rollback, RunEventLog,
AnswerPacket linkage, and falsifiers.

The observatory primitive family is:

```text
CognitiveTraceGraph
RouteMicroscopeFrame
AttentionKVTrace
AlgorithmicFailureProbe
HeuristicNeuronCard
SourceReasoningOverlay
AgentActionFrame
TraceComparisonDeck
TelemetryToWorkingSetPatch
VisualProofCapsule
HumanDebugHandle
```

Route them through existing organs only:

```text
MissionPacket
  -> Eidos / SourceSignalGraph
  -> SemanticWorkingSetPlan
  -> ResidencyPageTable / PrefetchWindow
  -> RuntimeRouter / System G
  -> model/cache/verifier/tool/editor/browser/graph events
  -> CognitiveTraceGraph
  -> RouteMicroscopeFrame / VisualProofCapsule
  -> TelemetryToWorkingSetPatch
  -> SCOPE-Rex / SovereignGate
  -> RunEventLog + AnswerPacket
```

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

## Formal Math / Lean External Intake

Read `docs/fusion/FORMAL_MATH_COMPANY_AND_LEAN_INTAKE_2026_06_01.md` when a
session touches Axiom, Axplorer, AxiomProver, Axiomatic AI Ax-Prover,
OProver, AXLE, UlamAI, Harmonic Aristotle, Math Inc Gauss/OpenGauss,
LeanSearch, Pantograph, lean4-skills, Neuronpedia, Goodfire, construction
search, formal proof, proof pressure, proof golf, or "best LLM brain region"
routing.

Preserve the ambition: the modern formal-math loop is
`construct/search -> Lean or kernel verifier -> refactor/golf/repair -> human
explanation -> replayable artifact`. Epistemos should mine that loop.

Preserve the rigor: do not create a new `FormalMathAgent` or claim Epistemos
has AxiomProver, Ax-Prover, OProver, Aristotle, or Gauss. Route the work
through existing organs:

```text
ProblemCard
  -> ConstructionGraph
  -> EidosRoutePrior
  -> NeuralImportanceAtlas / ActiveAssembly
  -> LeanProofRouteCard or ConstructionSearchRouteCard
  -> SCOPE-Rex / SovereignGate
  -> RunEventLog + AnswerPacket
```

Public code from Axplorer, UlamAI, OpenGauss, Harmonic, LeanSearch,
Pantograph, or lean4-skills is source-mined only until a license/setup/vendor
PR and local tests exist.

## Meta-Breakthrough Control Surfaces

Read `docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md` when a
session touches proof-carrying execution, model routing, multiple local
brains, feature atlases, activation steering, embeddings as route priors,
KV/page selection, adapter swapping, dynamic depth, helper SSMs, or "best LLM
brain region" claims.

Preserve the ambition: small controls compound. A proof route, premise card,
feature handle, KV page policy, adapter selection, or brain route can be tiny
and still unlock a large reasoning gain if it is selected at the right time.

Preserve the rigor: "neural control" means address, observe, select,
intervene, measure, and roll back a bounded model-state unit. Anything less is
a route prior.

The new card family is:

```text
ProofCarryingRouteCard
PremiseGraph / SourceCard
BrainRouteCard
FeatureAtlasCard
FeatureInterventionCard
KVPageControlCard
VerifierRegretLedger
```

Route them through existing organs only:

```text
MissionPacket
  -> Eidos evidence and PremiseGraph retrieval
  -> BrainRouteCard
  -> NeuralImportanceAtlas
  -> ProofCarryingRouteCard / ParamRouteCard / KVPageControlCard
  -> ActiveAssembly
  -> SCOPE-Rex / SovereignGate
  -> RuntimeRouter
  -> verifier / Lean / tests / citations
  -> RunEventLog + AnswerPacket
  -> VerifierRegretLedger
```

No base-weight mutation, hidden activation steering, silent KV eviction,
unlogged multi-model committee, or SSD-as-RAM claim.

## Constructive Residency Paradigm

Read `docs/fusion/CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01.md` when a
session touches UAS, AppColdStore, ColdStore layout, 70B cocktail, SSD or MoE
expert streaming, model-page routing, KV continuity, preserved reasoning
state, Letta-style stateful memory, SwiftLM source mining, LDT-style
controllers, or "SSD brain" claims.

Preserve the ambition: a very large addressable local brain can become useful
through many small resident assemblies. A coactivation tile, KV continuity
card, adapter slice, verifier lane, or proof-carrying lease can be small and
still shift the quality of a whole run.

Preserve the rigor: SSD is not RAM. The claim is addressable, schedulable,
prewarmable, layout-controlled, and measurable cold residency. A 70B cocktail
promotes only as a `ColdAssemblyPlan` that reports active/cold bytes, cold
misses, verifier deltas, fallback, rollback, and AnswerPacket proof.

The residency primitive family is:

```text
ResidencyConstructionGraph
CoactivationTile
ColdAssemblyPlan
LatticeStateController
ProofCarryingResidencyLease
ReasoningStateContinuityCard
ColdMissLedger
```

Route them through existing organs only:

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
  -> ColdMissLedger
```

No dense-resident 70B claim, hidden cold wake, chain-of-thought exposure,
unlicensed code import, or source-mining shortcut may bypass source cards,
falsifiers, rollback, and visible proof.

## Cache-Lineage Autoresearch Paradigm

Read `docs/fusion/CACHE_LINEAGE_AUTORESEARCH_PARADIGM_2026_06_01.md` when a
session touches persistent KV, prefix caching, context caching, cache reuse,
AppColdStore cache admission, execution/browser traces, CDP/DOM trace intake,
autoresearch, GEPA-style prompt/policy evolution, oMLX/TurboQuant motifs,
DeepSeek-style context caching, or MLX overnight research.

Preserve the ambition: active cold storage can remember useful prefixes,
runtime state, trace evidence, and route winners so the next resident assembly
is cheaper, more continuous, and more correct.

Preserve the rigor: cached KV is not proof, traces are not truth, and
autoresearch cannot mutate production policy without baseline, patch,
ablation, held-out result, rollback, and AnswerPacket visibility.

The cache-lineage primitive family is:

```text
KVPrefixUnit
KVLineageGraph
KVCompatibilityFence
CacheAdmissionCard
ExecutionTraceCapsule
ParetoResidencyTournament
CacheMutationPatch
PrefixReuseRouter
TraceToPlanLearner
```

## Math And Portable Note Systems Intake

Read `docs/fusion/MATH_AND_PORTABLE_NOTE_SYSTEMS_INTAKE_2026_06_01.md` when a
session touches note editor architecture, Markdown vault portability, `.epdoc`
projection, sidecars, ProseMirror/Tiptap/Milkdown/CodeMirror/Lexical motifs,
Tree-sitter parsing, CRDT/local-first sync, Git vault history, FSRS review,
Datalog/differential graph views, semantic entropy, constrained decoding, or
repo code import.

Preserve the ambition: the note system can absorb modern editor/math ideas
from Tolaria, Noteriv, ProseMirror, Tiptap, CodeMirror, Lexical, Tree-sitter,
Automerge/Yjs, Differential Dataflow, Datafrog, FSRS, semantic entropy,
PICARD, HNSW, and information bottleneck.

Preserve the rigor: the macOS build remains native Swift/AppKit/TextKit unless
a later architecture vote changes it. Tauri apps are source motifs, not shell
replacement. AGPL sources are source-mine-only unless a deliberate license
strategy exists.

The portable-math primitive family is:

```text
EditorDeltaMonoid
ReadableProjectionFunctor
DeltaSemilatticeSync
DifferentialKnowledgeView
IncrementalParseForest
RetentionPotentialField
SemanticEntropyGate
ConstrainedMutationDecode
GitVaultLineage
FrontmatterTypeLens
RateDistortionSidecarBudget
```

## Engineering Logic Architecture Intake

Read `docs/fusion/ENGINEERING_LOGIC_ARCHITECTURE_INTAKE_2026_06_01.md` when a
session touches architecture decisions, subsystem boundaries, state machines,
invariants, performance budgets, concurrency, migration, source imports, hot
paths, rollback, observability, or new services/managers.

Preserve the ambition: future agents should not begin by assuming UAS,
AppColdStore, active model-state selection, dynamic compute, or the 70B
cocktail is impossible. They should first write the mechanism that would make
the claim true.

Preserve the rigor: no mechanism promotes unless its invariant, owner, state
transition, budget, failure mode, witness, and rollback are explicit.

The engineering-logic primitive family is:

```text
DecisionRecord
InvariantLedger
StateMachineCard
BoundaryContract
BudgetVector
HotPathProofCard
FailureEnvelope
ObservabilityProbe
MigrationRail
ImportGateCard
SimplicityBudget
```

## Promotion Gates

Relevant falsifiers:

- `F-DecisionRecord-Completeness`
- `F-InvariantLedger-Completeness`
- `F-StateMachineCard-TransitionSafety`
- `F-BoundaryContract-SendableOwnership`
- `F-BudgetVector-HotPath`
- `F-HotPathProofCard-NoAllocationSpike`
- `F-FailureEnvelope-Rollback`
- `F-ObservabilityProbe-Threshold`
- `F-MigrationRail-KillSwitch`
- `F-ImportGateCard-LicenseSetup`
- `F-SimplicityBudget-NoIndirection`
- `F-EngineeringLogic-NoHiddenAuthority`
- `F-SourceSignalGraph-Intake`
- `F-TaskWorkingSetQuery-Determinism`
- `F-SemanticWorkingSetPlan-Budget`
- `F-ResidencyPageTable-Addressability`
- `F-PrefetchWindow-ColdMiss`
- `F-ColdFaultTrace-Learning`
- `F-MmapResidencyFence-CopyCount`
- `F-KVByteBudgetCard`
- `F-WorkingSetOracle-Baseline`
- `F-SourceToResidency-NoPoison`
- `F-70B-Cocktail-WorkingSet-Lite`
- `F-RouteScoutSSM-Baseline`
- `F-TwoStageRouteScout-Abstain`
- `F-BudgetedUncertaintyEscalator`
- `F-SparseWakeProposal-Budget`
- `F-VerifierBudgetAuction`
- `F-KVPageSketchIndex`
- `F-KVPageBloomSketch-Coverage`
- `F-QueryAwareKVSelector`
- `F-LayerKVJointLease`
- `F-ConstructionSearchTournament`
- `F-RouteDistillationTournament`
- `F-ProofSearchSignal-RouteFeedback`
- `F-ProofPressureSignal`
- `F-VerifierRegretFastWeights`
- `F-FastWeightQuarantine`
- `F-DepthLease-Checkpoint`
- `F-ShadowWakeOracle`
- `F-AblationShadowRun`
- `F-SparseWakeCertificate-AnswerPacket`
- `F-AxiomAxiomatic-SourceDistinction`
- `F-SparseRoute-NoHiddenAuthority`
- `F-TransportRunManifest-Completeness`
- `F-PageRun-Coalescing`
- `F-ColdStream-vs-Mmap`
- `F-SlabArena-CopyCount`
- `F-MetalIO-FeatureGate`
- `F-CodecStage-Latency`
- `F-TransportCancellation`
- `F-CachePolicy-Pollution`
- `F-ColdPanicFallback`
- `F-TransportTrace-AnswerPacket`
- `F-SSD-WearBudget`
- `F-ColdStream-NoHiddenAuthority`
- `F-HotPathCopyScope-IntentionalCopyWaiver`
- `F-HotPathCensus-Coverage`
- `F-MmapKeepVsReplace`
- `F-MmapHazardFence-Truncation`
- `F-ReadPlanMatrix-Coalescing`
- `F-ColdStream-vs-Mmap-HotPath`
- `F-PageRunGeometry-Locality`
- `F-GeometryAlignedPageTable-Affinity`
- `F-CopyBudgetVector-Enforced`
- `F-UnsafeBoundaryProofCard`
- `F-ShmMaterializationWaiver`
- `F-GraphNodeStateRing-NoLegacyPositionFerry`
- `F-GpuNBody-NoPositionCopyRegression`
- `F-EditorIncrementalParse-NoFullDocReparse`
- `F-StreamingChunkBuffer-CopyBound`
- `F-StreamFrameArena-CopyBound`
- `F-VaultRecallHotTrace-NoJSON`
- `F-ProtocolEdgeJsonWaiver`
- `F-EventRingActivation-NoPerEventAlloc`
- `F-SQLiteMmapBudget`
- `F-SpatialDirtyWindow`
- `F-UIIdleTick-Gate`
- `F-ProofHarness-RustLean-StateMachine`
- `F-CopyCausalGeometry-Ablation`
- `F-NoHiddenZeroCopyOverreach`
- `F-CognitiveTraceGraph-Completeness`
- `F-RouteMicroscopeFrame-Replay`
- `F-AttentionKVTrace-ByteBinding`
- `F-AlgorithmicFailureProbe`
- `F-HeuristicNeuronCard-Ablation`
- `F-AgentActionFrame-ToolReplay`
- `F-SourceReasoningOverlay-Citation`
- `F-TraceComparisonDeck-Regression`
- `F-TelemetryToWorkingSetPatch`
- `F-VisualProofCapsule-AnswerPacket`
- `F-TracePrivacyRedaction`
- `F-ObservableSubstrate-NoHiddenAuthority`
- `F-KVPrefixUnit-Lineage`
- `F-KVCompatibilityFence`
- `F-PrefixReuseRouter`
- `F-CacheAdmissionCard`
- `F-PersistentKV-ParkResume`
- `F-ExecutionTraceCapsule`
- `F-ParetoResidencyTournament`
- `F-CacheMutationPatch-Rollback`
- `F-TraceToPlanLearner`
- `F-CacheLineage-NoPoison`
- `F-EditorDeltaMonoid`
- `F-ProjectionFunctor-Digest`
- `F-MarkdownSidecar-Portability`
- `F-IncrementalParseForest`
- `F-DifferentialKnowledgeView`
- `F-CRDTVaultConflict`
- `F-GitVaultLineage`
- `F-FSRSNoteReview`
- `F-SemanticEntropyGate`
- `F-ConstrainedMutationDecode`
- `F-LicensePortabilityGate`
- `F-ResidencyConstructionGraph`
- `F-CoactivationTile-Prefetch`
- `F-ProofCarryingResidencyLease`
- `F-ColdAssemblyPlan-70B-Lite`
- `F-LatticeStateController`
- `F-ReasoningStateContinuity`
- `F-ColdMissLedger`
- `F-SwiftLM-SourceIntake`
- `F-MetaBreakthrough-CardRegistry`
- `F-ProofCarryingRouteCard`
- `F-RustRouteKernel-ModelCheck`
- `F-BrainRouteCard-MultiModel`
- `F-KVPageControl-QueryAware`
- `F-NeuralControlCard-Ablation`
- `F-VerifierRegretLedger`
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
- `F-AssemblyCandidatePool-Diversity`
- `F-UASAssemblyGenome-Determinism`
- `F-ConstraintRepairKernel-Validity`
- `F-SparseAssemblyFingerprint-Collision`
- `F-AssemblyTournamentTrace-Replay`
- `F-EliteAssemblyArchive-HeldOut`
- `F-ResidencyPatternDistiller-RouteWin`
- `F-LatticeAbstentionGate-Soundness`
- `F-ComputeResumeLease-Compatibility`
- `F-ColdRoutePolicyPatch-Rollback`
- `F-AssemblyMotifLibrary-LicenseScope`
- `F-PatternBoostedResidency-Ablation`
- `F-70B-AssemblyPattern-Lite`
- `F-NoOfflineOracleLeak`
- `F-ResidencyPatternBoost-NoHiddenAuthority`

## Residency PatternBoost Discovery

Read `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md` whenever a
session touches offline route search, resident assembly selection,
AppColdStore layout learning, 70B cocktail plausibility, UAS assembly archives,
route motif distillation, pause/resume compute, Axplorer/PatternBoost-style
search, Lattice Deduction Transformer intake, or proper weights/KV/neurons/
params selection.

Lock: do not make the live heavy route discover everything from scratch.
Search, repair, sparsely fingerprint, verify, archive, and distill resident
assemblies offline or during idle time. Live routing may use the distilled
motif only when held-out wins, `ComputeResumeLease`, byte/transport proof,
rollback, RunEventLog, and AnswerPacket surface exist.

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
   - `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`
   - `docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md`
   - `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`
   - `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`
   - `docs/fusion/MMAP_REPLACEMENT_AND_HOTPATH_CURE_ATLAS_2026_06_01.md`
   - `docs/fusion/CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01.md`
   - `docs/fusion/CACHE_LINEAGE_AUTORESEARCH_PARADIGM_2026_06_01.md`
   - `docs/fusion/MATH_AND_PORTABLE_NOTE_SYSTEMS_INTAKE_2026_06_01.md`
   - `docs/fusion/ENGINEERING_LOGIC_ARCHITECTURE_INTAKE_2026_06_01.md`
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
