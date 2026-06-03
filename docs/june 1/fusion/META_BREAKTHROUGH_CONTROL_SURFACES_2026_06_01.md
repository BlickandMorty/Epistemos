---
state: candidate-canon
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source_prompt: user request for meta-breakthroughs, Lean/proof execution, neural control, KV pages, embeddings, and multi-brain routing
status: architecture doctrine; no product promotion without falsifiers, route cards, rollback, and visible proof
---

# Meta-Breakthrough Control Surfaces - 2026-06-01

## Thesis

A meta-breakthrough is a small control surface that compounds. It is not one
giant new model. It is a tiny piece of executable structure that makes the next
piece easier to select, verify, replay, and improve.

For Epistemos, the breakthrough class is:

```text
small typed control
  + addressable substrate unit
  + verifier or measurement
  + rollback
  + accumulated regret/utility evidence
  -> larger reasoning gain than the part looks like by itself
```

This preserves the architectural ambition. The app can grow toward real control
over model-state routes, feature priors, KV pages, adapters, proof tools, and
multi-model assemblies. The rigor lock is equally important: "control of
neurons" means address, observe, intervene, measure, and roll back a bounded
unit. It does not mean arbitrary hidden mutation of base weights or mystical
access to every parameter.

Engineering logic is the companion grammar for these small breakthroughs. The
source `docs/fusion/ENGINEERING_LOGIC_ARCHITECTURE_INTAKE_2026_06_01.md`
requires each breakthrough candidate to carry a DecisionRecord,
InvariantLedger, state machine or boundary contract, BudgetVector,
FailureEnvelope, ObservabilityProbe, rollback, and falsifier before it becomes
live architecture.

Semantic working-set compilation is the companion execution planner. The
source `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md` requires
small controls to enter a `SemanticWorkingSetPlan`, `ResidencyPageTable`,
`PrefetchWindow`, `ColdFaultTrace`, `MmapResidencyFence`, and
`KVByteBudgetCard` before they can claim to make active cold storage or the
70B cocktail faster.

Substrate trace observability is the companion proof surface. The source
`docs/fusion/SUBSTRATE_TRACE_OBSERVATORY_2026_06_01.md` requires small
controls to emit `CognitiveTraceGraph`, `RouteMicroscopeFrame`,
`AttentionKVTrace`, `AlgorithmicFailureProbe`, `SourceReasoningOverlay`,
`AgentActionFrame`, `TraceComparisonDeck`, `TelemetryToWorkingSetPatch`, and
`VisualProofCapsule` artifacts before they can claim to make model-state
control, KV/page selection, or multi-brain routing engineerable.

Residency PatternBoost is the companion discovery loop. The source
`docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md` searches,
repairs, sparsely fingerprints, archives, and distills reusable resident
assembly motifs before live routing uses them. A "small control" can become a
live route prior only after held-out wins, `ComputeResumeLease`, rollback,
RunEventLog, and AnswerPacket proof.

## Canonical Product Definition Of Neural Control

Epistemos may use "neural control" internally only when the control satisfies
this ladder:

| Level | Name | Requirement | Product status |
|---|---|---|---|
| 0 | Address | The unit has a stable model/layer/hook/page/adapter/UAS address. | Indexable. |
| 1 | Observe | The runtime can log activation, KV, adapter, or route evidence for the unit. | Research-visible. |
| 2 | Select | ActiveAssembly can choose the unit under budget, verifier, and rollback. | Route-card gated. |
| 3 | Intervene | The runtime can apply a bounded activation, feature, adapter, KV, or depth action. | Pro Research until falsified. |
| 4 | Measure | Baseline versus intervention is compared on quality, evidence validity, latency, active bytes, and failure mode. | Candidate only with artifacts. |
| 5 | Persist | A learned route, feature prior, adapter, or KV policy is saved with rollback and regret evidence. | Pro Gated. |

If a route cannot be observed, measured, and rolled back, it is not neural
control. It is at most a prior.

## Meta-Breakthrough Cards

These cards are intentionally small. Each is a possible implementation unit,
falsifier target, and future UI/proof surface.

### 1. ProofCarryingRouteCard

Purpose: make execution better by requiring important routes to carry a typed
contract and, where possible, a Lean/kernel-checked proof or model-checking
witness.

Fields:

```text
route_id
mission_id
preconditions
postconditions
budget_invariants
state_transition
allowed_mutations
rollback_handle
proof_artifact_or_model_check_artifact
kernel_or_toolchain_version
answer_packet_ref
```

What Lean can prove:

- route schemas are complete;
- admission states are monotonic or explicitly reversible;
- active-byte budgets cannot silently increase;
- rollback handles exist before mutation;
- AnswerPacket fields required by the route are present;
- selected proof objects typecheck in the pinned Lean environment.

What Lean cannot prove by itself:

- that an LLM answer is true;
- that an SAE feature has the intended real-world meaning;
- that an activation intervention improves reasoning across distributions;
- that SSD access has RAM latency.

External grounding:

- LeanSearch v2 / LeanSearch for premise retrieval: `https://arxiv.org/abs/2605.13137`, `https://leansearch.net/`, `https://github.com/frenzymath/LeanSearch-v2`
- Pantograph machine interface for Lean 4: `https://github.com/stanford-centaur/PyPantograph`, `https://arxiv.org/abs/2410.16429`
- Rust-to-Lean verification pipeline: `https://arxiv.org/abs/2605.30106`
- Aeneas and hax Rust extraction routes: `https://github.com/AeneasVerif/aeneas`, `https://github.com/cryspen/hax`
- Verus and Kani as proof/model-check complements for Rust surfaces: `https://verus-lang.github.io/verus/guide/`, `https://github.com/model-checking/kani`

### 2. PremiseGraph / SourceCard

Purpose: make proof and reasoning search executable instead of vague.
The lesson from LeanSearch/Pantograph-style work is that theorem proving needs
premise retrieval, machine-readable proof state, and replay. Epistemos needs the
same pattern for notes, papers, code, model features, and proof obligations.

Fields:

```text
source_id
source_url_or_path
license_or_usage_note
credibility_rank
digest
claim_type
premise_embedding
symbolic_terms
known_failures
route_affinities
```

Architecture hook:

```text
Eidos evidence hit
  -> PremiseGraph / SourceCard
  -> EidosRoutePrior
  -> ProofCarryingRouteCard or BrainRouteCard
```

### 3. BrainRouteCard

Purpose: route across multiple "brains" without turning the stack into a hidden
committee. A brain can be a local model, Apple Intelligence route, verifier,
tool, embedding engine, adapter family, proof assistant, or future specialist
model. The route is chosen by task shape and measured regret, not vibes.

Fields:

```text
task_signature
candidate_brains
selected_brain_or_stack
expected_quality
expected_latency
expected_active_bytes
privacy_class
evidence_need
verifier_need
fallback_brain
regret_update_key
```

External grounding:

- RouteLLM learned routing: `https://arxiv.org/abs/2406.18665`, `https://github.com/lm-sys/RouteLLM`
- FrugalGPT cascade/routing economics: `https://arxiv.org/abs/2305.05176`
- Mixture-of-Agents layered multi-LLM assembly: `https://arxiv.org/abs/2406.04692`, `https://github.com/togethercomputer/MoA`
- LLM-Blender ranking/fusion: `https://arxiv.org/abs/2306.02561`, `https://github.com/yuchenlin/LLM-Blender`

Product lock: multi-model routes promote only when they beat the simpler route
on quality, evidence validity, active bytes, latency, and visible proof.

### 4. FeatureAtlasCard

Purpose: turn interpretability work into a disciplined source of route priors.
SAEs and feature maps can name useful internal handles, but they remain priors
until an intervention is measured.

Fields:

```text
feature_id
model_id
layer_or_hook
sae_release
feature_description
source_examples
activation_threshold
known_ambiguities
risk_tags
route_affinities
```

External grounding:

- Anthropic feature/SAE mapping: `https://www.anthropic.com/research/mapping-mind-language-model/`
- Goodfire reasoning-model SAE/steering work: `https://www.goodfire.ai/research/under-the-hood-of-a-reasoning-model`
- Neuronpedia SAE identifiers and feature registry pattern: `https://docs.neuronpedia.org/sparse-autoencoder`
- SAELens: `https://github.com/decoderesearch/SAELens`
- TransformerLens hooks/caches/interventions: `https://github.com/TransformerLensOrg/TransformerLens`
- NNsight local/remote intervention API: `https://nnsight.net/`
- Representation engineering: `https://arxiv.org/abs/2310.01405`
- Activation Addition: `https://arxiv.org/abs/2308.10248`

Product lock: a feature atlas is not authority. It is a route prior whose
effect must survive ablation, baseline comparison, and rollback.

### 5. FeatureInterventionCard

Purpose: define the smallest safe unit of activation or representation
steering.

Fields:

```text
intervention_id
feature_or_direction_id
model_id
layer_or_hook
token_range
strength
start_condition
stop_condition
expected_effect
baseline_run
intervention_run
ablation_run
rollback
failure_signature
```

Rules:

- Never mutate base weights.
- Never run hidden steering without RunEventLog visibility.
- Never persist an intervention without baseline, intervention, and ablation
  evidence.
- Oversteering, route-around behavior, and feature ambiguity are expected
  failure modes, not surprises.

### 6. KVPageControlCard

Purpose: make "brain pages" concrete. KV cache is not vague memory; it is an
addressable runtime state with pages, criticality, eviction, restoration, and
budget.

Fields:

```text
kv_policy_id
model_id
layer_range
token_page_range
page_digest
criticality_signal
query_dependence
sink_or_heavy_hitter_flag
retention_decision
eviction_decision
restore_decision
active_bytes
quality_delta
latency_delta
```

External grounding:

- PagedAttention / vLLM KV paging: `https://arxiv.org/abs/2309.06180`, `https://github.com/vllm-project/vllm`
- H2O heavy-hitter KV retention: `https://arxiv.org/abs/2306.14048`, `https://github.com/FMInference/H2O`
- Quest query-aware KV page selection: `https://arxiv.org/abs/2406.10774`, `https://github.com/mit-han-lab/Quest`
- StreamingLLM attention sinks: `https://arxiv.org/abs/2309.17453`
- SnapKV: `https://arxiv.org/abs/2404.14469`
- PyramidKV: `https://arxiv.org/abs/2406.02069`
- KIVI KV quantization: `https://arxiv.org/abs/2402.02750`
- MInference sparse long-context attention: `https://arxiv.org/abs/2407.02490`, `https://github.com/microsoft/MInference`

Product lock: KV control can page, select, compress, retain, evict, or restore.
It does not make cold SSD bytes equivalent to hot RAM. It can still be a huge
win because the right page restored at the right token is a tiny intervention
with large reasoning impact.

### 7. ColdAssemblyPlan / ProofCarryingResidencyLease

Purpose: turn UAS/AppColdStore and cold model bytes into an admitted resident
assembly instead of an SSD-as-RAM claim. The assembly can include KV pages,
weight pages, MoE experts, adapters, evidence bundles, verifier lanes, tool
plans, and controller state, but each cold wake needs a reason, byte cost,
proof/falsifier reference, expiry, and rollback.

Fields:

```text
mission_id
residency_construction_graph_ref
active_tiles
warm_tiles
cold_tiles
hot_bytes
warm_bytes
cold_bytes
kv_bytes
peak_rss_estimate
prefetch_order
proof_carrying_residency_leases
verifier_stack
fallback_route
rollback
cold_miss_policy
answer_packet_ref
```

External grounding:

- SwiftLM Apple Silicon SSD expert streaming and KV compression motifs: `https://github.com/SharpAI/SwiftLM`
- Apple LLM in a Flash flash-aware bundling: `https://machinelearning.apple.com/research/efficient-large-language`
- PowerInfer activation-locality split: `https://arxiv.org/abs/2312.12456`
- vLLM/PagedAttention and LMCache KV paging/reuse: `https://arxiv.org/abs/2309.06180`, `https://github.com/LMCache/LMCache`
- KTransformers expert offload/runtime motifs: `https://github.com/kvcache-ai/ktransformers`
- Lattice Deduction Transformers as a tiny lattice-state controller signal: `https://arxiv.org/abs/2605.08605`
- Axplorer/PatternBoost as construction-search signal: `https://github.com/AxiomMath/axplorer`, `https://arxiv.org/abs/2411.00566`
- Letta stateful agents as explicit continuity-state signal: `https://docs.letta.com/guides/core-concepts/stateful-agents/`

Product lock: no cold page, expert, adapter, or KV continuity artifact wakes
silently. No 70B route promotes unless the assembly beats simpler baselines on
quality, evidence validity, active bytes, hot bytes, cold misses, latency, and
visible proof.

### 8. KVLineageGraph / CacheAdmissionCard / ExecutionTraceCapsule

Purpose: turn cache and trace state into a learning substrate without letting
hidden runtime leftovers become authority. Prefix/KV reuse, browser traces,
runtime traces, and prompt/cache policy mutations must be addressable,
compatible, redacted, reversible, and measured.

Fields:

```text
kv_prefix_units
compatibility_fence
cache_admission_card
execution_trace_capsules
pareto_residency_tournament
cache_mutation_patches
prefix_reuse_router
trace_to_plan_learner
privacy_class
purge_policy
rollback
```

External grounding:

- oMLX: `https://github.com/solatticus/omlx`
- TurboQuant: `https://ar5iv.org/abs/2504.19874`
- Tutti: `https://arxiv.org/abs/2605.03375`
- AWS managed tiered KV cache: `https://aws.amazon.com/about-aws/whats-new/2025/11/sagemaker-hyperpod-managed-tiered-kv-cache/`
- DeepSeek context caching: `https://api-docs.deepseek.com/guides/kv_cache`
- Browserbase skills: `https://github.com/browserbase/skills`
- Karpathy autoresearch: `https://github.com/karpathy/autoresearch`
- GEPA: `https://github.com/gepa-ai/gepa`

Product lock: cache reuse is not proof and trace learning is not authority.
No persistent KV, prefix reuse, trace-derived prompt, route policy, or cold
layout mutation promotes without compatibility fence, privacy/purge policy,
baseline, ablation when relevant, rollback, falsifier, and AnswerPacket
visibility.

### 9. EditorDelta / Projection / Portable Vault Cards

Purpose: make the note system's math explicit. Editor changes, Markdown files,
rich `.epdoc` documents, sidecars, backlinks, graph edges, review queues, and
AI-authored mutations should move as typed deltas and derived projections, not
whole-document refreshes.

Fields:

```text
editor_delta_monoid
readable_projection_functor
source_digest
projection_version
loss_budget
incremental_parse_forest
differential_knowledge_view
git_vault_lineage
retention_potential_field
constrained_mutation_decode
license_status
rollback
```

External grounding:

- Tolaria: `https://github.com/refactoringhq/tolaria`
- ProseMirror: `https://github.com/ProseMirror/prosemirror`
- CodeMirror: `https://codemirror.net/docs/guide/`
- Lexical: `https://github.com/facebook/lexical`
- Tree-sitter: `https://github.com/tree-sitter/tree-sitter`
- Automerge: `https://github.com/automerge/automerge`
- Differential Dataflow: `https://github.com/TimelyDataflow/differential-dataflow`
- FSRS: `https://github.com/open-spaced-repetition/fsrs4anki`

Product lock: Tauri note apps are source motifs, not the macOS shell. AGPL
sources are source-mine-only unless a deliberate license strategy exists.
Derived Markdown/search/plain/graph views must name source digest, projection
version, and loss budget.

### 10. VerifierRegretLedger

Purpose: make every small control learn from whether it helped.

Fields:

```text
unit_id
route_id
task_signature
baseline_score
intervention_score
verifier_delta
evidence_validity_delta
latency_delta
active_byte_delta
failure_mode
regret_update
next_policy
```

Architecture hook:

```text
RunEventLog
  -> verifier result
  -> VerifierRegretLedger
  -> NeuralImportanceAtlas / BrainRouteCard / KVPageControlCard update
```

The ledger is the antidote to delusion. It lets the architecture stay
ambitious while refusing to promote a route that did not earn its keep.

## Fused Runtime Loop

The updated architecture loop is:

```text
Intent
  -> MissionPacket
  -> EditorDeltaMonoid / ReadableProjectionFunctor when notes or docs changed
  -> Eidos evidence and PremiseGraph retrieval
  -> TaskSignatureEmbedding
  -> PrefixReuseRouter / KVLineageGraph / CacheAdmissionCard
  -> BrainRouteCard
  -> NeuralImportanceAtlas
  -> ResidencyConstructionGraph
  -> ColdAssemblyPlan / ProofCarryingResidencyLease
  -> ProofCarryingRouteCard / ParamRouteCard / KVPageControlCard
  -> ActiveAssembly minimal support set
  -> SCOPE-Rex / SovereignGate admission
  -> RuntimeRouter execution
  -> ExecutionTraceCapsule
  -> verifier / Lean / tests / citation checks
  -> RunEventLog + AnswerPacket
  -> VerifierRegretLedger / ParetoResidencyTournament update
  -> CacheMutationPatch candidate, never direct production mutation
```

This makes "multiple brains" and "inside the brain" the same problem at
different scales. A whole model, a proof tool, an adapter, a KV page, and a
feature direction are all routable support units. They differ in risk,
latency, proofability, and rollback.

## What To Build First

1. `MetaBreakthroughCardRegistry`

   A small registry that stores card kind, UAS address, source, proof state,
   budget, rollback, and falsifier state. This prevents every future feature
   from inventing its own route metadata.

2. `ProofCarryingRouteCard`

   Start with schema and model-checkable invariants before real Lean proof
   generation. Kani/Verus can cover bounded Rust route-state logic; Lean can
   cover typed route contracts and theorem artifacts.

3. `KVPageControlCard`

   Start as a dry-run policy over synthetic pages and real prompt traces. The
   first win is not speed; it is visible accounting of which pages would wake,
   which stay cold, and why.

4. `ColdAssemblyPlan` / `ProofCarryingResidencyLease`

   Start as a dry-run route over synthetic tiles and existing route metadata.
   The first win is proving that no cold byte wakes without address, reason,
   byte cost, verifier/proof reference, expiry, fallback, rollback, and
   AnswerPacket visibility.

5. `BrainRouteCard`

   Route between the existing Apple Intelligence/local Qwen/proof/tool lanes
   with explicit quality-cost-evidence measurements. Expand to multi-model
   stacks only after the two-brain route beats static routing.

6. `FeatureAtlasCard`

   Store SAE/feature handles as route priors. Do not steer live app answers
   until baseline/intervention/ablation artifacts exist.

7. `VerifierRegretLedger`

   Persist every route's quality-cost-verifier delta. The atlas should learn
   from regret before it learns from confidence.

8. `KVPrefixUnit` / `KVCompatibilityFence` / `CacheAdmissionCard`

   Start as synthetic fixtures for prefix reuse and cache admission. The first
   win is rejecting stale or incompatible state with named reasons.

9. `EditorDeltaMonoid` / `ReadableProjectionFunctor`

   Start over current note and `.epdoc` fixtures. The first win is proving
   source digest, projection version, loss budget, selection/scroll metadata,
   and undo behavior without whole-document refresh.

## New Falsifier Targets

| Falsifier | Purpose |
|---|---|
| `F-MetaBreakthrough-CardRegistry` | Proves every meta-control card binds UAS address, source, budget, rollback, proof/falsifier state, and AnswerPacket visibility. |
| `F-ProofCarryingRouteCard` | Proves route cards reject missing preconditions, missing rollback, missing artifact refs, or unpinned proof/toolchain versions. |
| `F-RustRouteKernel-ModelCheck` | Uses Kani/Verus/Aeneas/hax path where appropriate to check bounded route-state and unsafe/FFI invariants. |
| `F-ResidencyConstructionGraph` | Proves candidate assemblies can be scored under memory/I/O/verifier constraints and invalid plans are rejected. |
| `F-CoactivationTile-Prefetch` | Proves tile packing and prefetch beat original file order or random page fetch under cold-miss and latency budgets. |
| `F-ProofCarryingResidencyLease` | Proves no cold byte wakes without UAS address, reason, byte cost, verifier/proof reference, expiry, and rollback. |
| `F-ColdAssemblyPlan-70B-Lite` | Proves a small-hot plus cold-selected assembly beats static local baselines without hidden cloud or dense-resident overclaim. |
| `F-LatticeStateController` | PASS metadata-only witness on main, 2026-06-03. Proves a small recurrent/lattice controller improves route decisions versus static, random, and always-retrieve baselines; abstains under high uncertainty/conflict; rejects hidden live route authority, hidden-chain exposure, missing rollback, missing AnswerPacket, and unbeaten static-policy baselines. Artifact: `artifacts/falsifiers/lattice_state_controller/result.json`. |
| `F-ReasoningStateContinuity` | PASS metadata-only witness on 2026-06-03. Proves visible, privacy-scoped resumable state improves continuity/cache utility versus no-state, naive-cache, and static-summary baselines; rejects hidden-chain exposure, verifier bypass, stale-state reuse, missing purge policy, incompatible compatibility fence, missing AnswerPacket, and unbeaten naive-cache baselines. Artifact: `artifacts/falsifiers/reasoning_state_continuity/result.json`. |
| `F-ColdMissLedger` | PASS metadata-only witness on 2026-06-03. Proves repeated route-level cold misses bind missed UAS units, stall/cold-I/O costs, fallback, verifier delta, next prefetch policy, rollback, run log, AnswerPacket, and a shadow ColdRoutePolicyPatch; held-out misses and repeated stalls improve while one-miss, no-improvement, missing rollback, missing policy patch, zero-stall, high-wear, and live-mutation cases reject. Artifact: `artifacts/falsifiers/cold_miss_ledger/result.json`. |
| `F-SwiftLM-SourceIntake` | PASS metadata-only witness on 2026-06-03. Proves SwiftLM SSD streaming, KV compression, persistent-buffer, and prefetch motifs are source-carded with license/setup notes, benchmark caveats, route affinities, and local test plans before implementation import or product dependency. Artifact: `artifacts/falsifiers/swiftlm_source_intake/result.json`. |
| `F-BrainRouteCard-MultiModel` | Proves learned/task-shaped routing beats static routing on quality, evidence validity, latency, and active-byte cost. |
| `F-KVPageControl-QueryAware` | Proves query-aware page selection beats recency-only and random page policies under active-byte and quality budgets. |
| `F-KVPrefixUnit-Lineage` | Proves prefix/KV units bind model, tokenizer, adapter set, prompt digest, token range, codec, privacy, purge, and byte accounting. |
| `F-KVCompatibilityFence` | Proves incompatible or stale cache units are rejected with named reasons before restore. |
| `F-ExecutionTraceCapsule` | Proves app/browser/runtime traces are captured with redaction, integrity, and replayable failure signatures. |
| `F-ParetoResidencyTournament` | Proves trace-derived candidates are selected by Pareto metrics rather than one greedy score. |
| `F-EditorDeltaMonoid` | Proves editor transactions compose, preserve selection/scroll metadata, and carry undo inverse or reason absent. |
| `F-ProjectionFunctor-Digest` | Proves derived Markdown/search/plain/graph views bind source digest, projection version, loss budget, and output digest. |
| `F-DifferentialKnowledgeView` | Proves backlinks/graph/review projections update by delta and beat full rebuild under held-out changes. |
| `F-LicensePortabilityGate` | Proves repo motifs are classified as importable, source-mine-only, or rejected before any code import. |
| `F-FeatureAtlas-Prior` | Proves feature handles improve route selection as priors without claiming arbitrary neuron control. |
| `F-NeuralControlCard-Ablation` | Proves a bounded feature/activation intervention improves target behavior versus baseline and ablation without unacceptable side effects. |
| `F-VerifierRegretLedger` | Proves route utility updates change later route selection and reduce verifier regret over a held-out prompt/task set. |
| `F-RouteScoutSSM-Baseline` | Proves a tiny scout predicts route family/verifier need better than static, random, recency, and embedding-only baselines. |
| `F-SparseWakeCertificate-AnswerPacket` | Proves a sparse route exposes selected units, budgets, verifier/citation/test results, traces, uncertainty, fallback, and rollback. |
| `F-ColdStream-vs-Mmap` | Proves explicit cold-byte transport beats mmap-fault and naive read baselines on the selected hot-path fixture. |
| `F-TransportTrace-AnswerPacket` | Proves cold-transport-dependent answers link bytes, stalls, copies, fallback, and caveats to visible proof. |

## 2026-06-01 companion breakthrough: scout + transport

The small cumulative breakthrough pattern now has two more control surfaces:

- `Verifier-Calibrated Sparse Route Compiler` makes `BrainRouteCard`,
  `KVPageControlCard`, `FeatureAtlasCard`, and proof routes cheaper by adding
  `RouteScoutSSM`, `SparseWakeProposal`, `VerifierBudgetAuction`,
  `QueryAwareKVSelector`, `DepthLease`, and `VerifierRegretFastWeights`.
- `ColdStream Residency Transport` makes cold control physical by adding
  `TransportRunManifest`, `PageRunScheduler`, `SlabArena`,
  `MetalBufferLease`, `CodecStage`, `TransportTrace`, and
  `ColdPanicFallback`.

Together they define the current software-side bet: a tiny scout chooses the
minimum useful route, verifiers measure whether it helped, and explicit
transport ensures cold bytes do not masquerade as free residency.

## Hard No-Overclaim Rules

- Do not claim base-weight mutation unless the system actually trains and
  persists weights under a training/provenance gate.
- Do not claim "control of neurons" for a prompt, route hint, or feature name.
- Do not treat interpretability labels as truth; they are hypotheses.
- Do not use multi-model committees when a simpler route wins.
- Do not call SSD "same as RAM." Say addressable, routable, prewarmable,
  cacheable, and measurable.
- Do not wake cold model pages, experts, adapters, or preserved reasoning state
  without a lease, fallback, rollback, cold-miss policy, and AnswerPacket
  surface.
- Do not let proof tools become a new top-level authority. They are verifier
  lanes under SCOPE-Rex/SovereignGate and AnswerPacket visibility.
- Do not let cache hits, browser traces, editor traces, or autoresearch
  candidates mutate production policy without compatibility, privacy, baseline,
  ablation where relevant, rollback, and visible proof.
- Do not replace the native macOS editor with a Tauri/web shell because an
  external note repo is useful. Source-mine the math and motifs first.
- Do not copy AGPL source into product paths without a deliberate license
  strategy.
- Do preserve the huge ambition as long as every layer has a card, witness,
  rollback, and falsifier.

## Backlog Codewords

- `RESUME META BREAKTHROUGH CARDS`
- `RESUME PROOF CARRYING ROUTES`
- `RESUME RUST ROUTE MODEL CHECK`
- `RESUME NEURAL CONTROL CARD`
- `RESUME FEATURE ATLAS PRIOR`
- `RESUME KV PAGE CONTROL`
- `RESUME VERIFIER CALIBRATED SPARSE WAKE`
- `RESUME COLDSTREAM TRANSPORT`
- `RESUME CONSTRUCTIVE RESIDENCY`
- `RESUME CACHE LINEAGE AUTORESEARCH`
- `RESUME EDITOR DELTA PROJECTION`
- `RESUME MULTI BRAIN ROUTER`
- `RESUME VERIFIER REGRET LEDGER`

## Agent Rule

Any PR or doc touching Lean/proof execution, model routing, multiple local
brains, feature atlases, activation steering, embeddings as route priors,
KV/page selection, adapter swapping, dynamic depth, helper SSMs, UAS,
AppColdStore, ColdStore layout, verifier-calibrated sparse wake, ColdStream
transport, SSD/MoE/expert streaming, preserved reasoning state, 70B cocktail
routes, persistent KV, prefix/context caching,
execution/browser traces, autoresearch, note editor architecture, Markdown
vault portability, `.epdoc` projection, Tree-sitter, CRDT/local-first sync,
FSRS, constrained decoding, repo import, or "best LLM brain region" claims
must cite this source and declare:

```text
control card kind
addressed unit
source/evidence
budget
verifier
intervention or selection action
assembly plan or residency lease when cold bytes wake
route scout proposal or transport manifest when selection/byte movement changes
compatibility fence or projection digest when cache/editor state is involved
baseline
rollback
falsifier
AnswerPacket surface
```

The stance is deliberately ambitious: assume the architecture can work. The
execution rule is deliberately strict: every extraordinary control becomes a
small typed card before it becomes a product claim.
