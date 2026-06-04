---
state: candidate-canon
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source_prompt: user request for deeper Axiom/math-AI juxtaposition, sparse routing, sparse attention, small SSM selectors, proper weight/KV/neuron/page choice, and robust fast-weight adaptation
status: architecture doctrine; no product promotion without verifier-calibrated baselines, wake budgets, fast-weight rollback, trace proof, and falsifiers
---

# Verifier-Calibrated Sparse Route Compiler - 2026-06-01

## Thesis

The next plausible breakthrough is not "wake a bigger model." It is:

> **Use a tiny verifier-calibrated scout to choose the smallest substrate route
> worth waking, then let proof, tests, citations, and trace deltas update the
> chooser.**

Epistemos already has the right spine: Eidos, NeuralImportanceAtlas,
ActiveAssembly, SemanticWorkingSetPlan, AppColdStore, CacheLineage,
SubstrateTraceObservatory, SCOPE-Rex, RunEventLog, and AnswerPacket. The new
piece is a small route compiler that learns which weights, KV pages, adapters,
verifier lanes, source pages, and tool routes are likely useful before a heavy
LLM wakes.

This is how Axiom/Axplorer, Axiomatic AI AxProver, OProver, UlamAI,
Harmonic Aristotle, OpenGauss, sparse attention, RouteLLM, LayerSkip,
Mixture-of-Depths, Titans, TTT, Mamba-2, PowerInfer, DejaVu, and Quest-style
KV selection should be juxtaposed with Epistemos:

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

The app should not ask the main LLM to decide everything. The main LLM is too
expensive and too opaque for first-pass routing. A tiny always-hot scout should
make a cheap, typed, abstention-capable proposal; verifiers and traces should
correct it.

## What this supersedes

This does not replace `NeuralImportanceAtlas`, `Constructive Residency`,
`Semantic Working-Set Compiler`, or `Substrate Trace Observatory`.
`docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md` adds the offline
construction-tournament layer above this compiler: it discovers elite resident
assembly motifs and distills them into route-scout/layout priors before live
wake decisions.

It supersedes only the weak assumption that importance prediction is a single
saliency score. Importance must become a **verified sparse route policy**:

- route family first, not raw parameter identity first;
- two-stage selection, not one monolithic all-knowing router;
- query-aware KV/page selection before dense attention;
- joint layer/KV/page leases, not independent gates that fight each other;
- construction/search tournaments for rare high-value plans;
- proof-pressure and compiler-error traces as first-class labels;
- verifier-regret updates after each run;
- quarantined session-local fast weights for route adaptation;
- durable promotion only after held-out wins and rollback proof.

## External systems translated into Epistemos

| External pattern | What it proves | Epistemos interpretation |
|---|---|---|
| Axiom Axplorer / PatternBoost | Alternate between local search, training on best constructions, model sampling, scoring, selecting best, and increasing exploration when duplicates appear. | Use `ConstructionSearchTournament` for route plans, not just math objects: generate many sparse wake proposals, repair invalid ones, score by verifier/cost, keep winners. |
| Axiom AXLE | Proof verification and manipulation can be exposed as reusable primitives for provers. | `VerifierBudgetAuction` can wake Lean/AXLE-style verifier lanes only when proof value exceeds cost. |
| Axiomatic AI AxProverBase | A small agentic Lean loop can propose proof code, compile it, review statement preservation, and write a concise memory of failed attempts. | Use `ProofPressureSignal` and `RouteDistillationTournament` labels: failed routes are not waste, they are training examples for the scout. |
| OProver | Agentic proving traces, compiler feedback, retrieved verified proofs, repair trajectories, and unresolved hard cases can be recycled into training and RL loops. | Build `ShadowWakeOracle` datasets from full-wake/proof attempts, then distill them into small route policies before live use. |
| UlamAI | LLM proposals, retrieval, search, caching, replay, Lean checking, and review can be combined in a truth-first CLI. | `ProofSearchSignal` and `LeanReplayTrace` should be first-class route feedback, not after-the-fact logs. |
| Harmonic Aristotle | High-end math claims need public Lean artifacts and replayable proof code. | Major reasoning claims need `SparseWakeCertificate` plus proof/test/citation witness. |
| OpenGauss | Proof/draft/review/checkpoint/refactor/golf/autoformalize are explicit project-scoped agent workflows. | Route phases should be explicit and cancelable: prove, review, refactor, golf, formalize, checkpoint. |
| RouteLLM | A small router can select cheaper or stronger models with calibrated cost-quality tradeoffs. | Epistemos needs a `RouteScoutSSM` that predicts when to stay small, wake local Qwen, wake proof tools, wake KV pages, or abstain. |
| Quest / SparQ / MInference | Attention/KV/history access can be sparse, query-aware, and pattern-aware rather than full-cache by default. | `KVPageSketchIndex` and `QueryAwareKVSelector` choose KV/page candidates before long attention. |
| DejaVu / PowerInfer | Contextual sparsity and activation locality can be predicted and exploited. | Neural units need a route-conditioned `WakeBudgetAuction`, not global saliency. |
| LayerSkip / Mixture-of-Depths | Dynamic depth and early exit can reduce compute when token or layer confidence is high. | `DepthLease` wakes deeper layers only when verifier margin, uncertainty, or route policy asks for it. |
| Titans / TTT / fast weights | Session-time memory and test-time adaptation can help long-context behavior. | Use `VerifierRegretFastWeights`: ephemeral route/scout updates derived from surprise and verifier results, never silent base-weight mutation. |
| Mamba-2 / SSD | SSMs and attention are connected through structured semiseparable matrix views, and Mamba-2 gives a faster selective-state primitive. | The always-hot scout can be an SSM-style controller, but only for route state and summaries, not hidden proof authority. |

## Source links

- X bookmark intake, Axiom Axplorer thread:
  `https://x.com/axiommathai/status/2037182556811256095`
- X bookmark intake, Axiom sample/improve/keep-winners loop:
  `https://x.com/axiommathai/status/2037182559516590502`
- X bookmark intake, Axplorer blog/repo pointer:
  `https://x.com/axiommathai/status/2037182564172276204`
- X bookmark intake, UlamAI repo pointer:
  `https://x.com/prz_chojecki/status/2037187008372593115`
- Axiom Axplorer: `https://github.com/AxiomMath/Axplorer`
- PatternBoost: `https://arxiv.org/abs/2411.00566`
- Lattice Deduction Transformers: `https://arxiv.org/abs/2605.08605`
- Axiom AXLE / Lean engine: `https://github.com/AxiomMath/axiom-lean-engine`
- Axiomatic AI AxProverBase: `https://github.com/Axiomatic-AI/ax-prover-base`
- Ax-Prover paper: `https://arxiv.org/abs/2510.12787`
- OProver: `https://arxiv.org/abs/2605.17283`
- UlamAI: `https://github.com/ulamai/ulamai`
- Ulam website: `https://www.ulam.ai/`
- Harmonic IMO 2025 Lean artifacts: `https://github.com/harmonic-ai/IMO2025`
- Aristotle paper: `https://arxiv.org/abs/2510.01346`
- OpenGauss: `https://github.com/math-inc/OpenGauss`
- Gauss: `https://www.math.inc/gauss`
- RouteLLM: `https://arxiv.org/abs/2406.18665`,
  `https://github.com/lm-sys/RouteLLM`
- Quest: `https://arxiv.org/abs/2406.10774`,
  `https://github.com/mit-han-lab/Quest`
- SparQ Attention: `https://arxiv.org/abs/2312.04985`
- MInference: `https://arxiv.org/abs/2407.02490`,
  `https://github.com/microsoft/MInference`
- DejaVu contextual sparsity: `https://arxiv.org/abs/2310.17157`
- PowerInfer activation locality: `https://arxiv.org/abs/2312.12456`
- LayerSkip: `https://arxiv.org/abs/2404.16710`,
  `https://github.com/facebookresearch/LayerSkip`
- Mixture-of-Depths: `https://arxiv.org/abs/2404.02258`
- Titans: `https://arxiv.org/abs/2501.00663`
- Learning to Learn at Test Time:
  `https://arxiv.org/abs/2407.04620`
- Mamba-2 / structured state-space duality:
  `https://arxiv.org/abs/2405.21060`

## Second-pass breakthrough lock: verifier-pressure route distillation

The deeper synthesis is not "the app controls neurons directly." That phrase
becomes rigorous only after translation into addressable software objects:

- **weights/params** mean immutable weight pages, adapter deltas, expert shards,
  verifier tools, and route-local policy deltas named by digest or UAS address;
- **KV/brain state** means KV pages, prefix units, cache summaries, and
  compatibility fences selected by query-aware sketches;
- **neurons/features** mean observed activation units, coactivation tiles, SAE
  handles, or mechanistic feature priors that must survive ablation;
- **reasoning depth** means a lease over layers, passes, tools, verifiers, and
  repair loops;
- **fast weights** mean bounded selector-policy deltas, not base checkpoint
  mutation.

The new route doctrine is therefore:

```text
full/proof/oracle traces
  + failed proof attempts
  + compiler errors
  + citation/test failures
  + cold-miss and KV-miss traces
  -> RouteDistillationTournament
  -> TwoStageRouteScout
  -> BudgetedUncertaintyEscalator
  -> ShadowWakeOracle
  -> FastWeightQuarantine
  -> live promotion only after falsifiers
```

This fuses the best parts of the researched systems:

| Breakthrough | Imported proof idea | Epistemos lock |
|---|---|---|
| Verifier-pressure labels | AXLE, AxProverBase, OProver, UlamAI, OpenGauss, and Aristotle all show proof/checker feedback is valuable structure, not just pass/fail. | Every proof/test/citation/build failure becomes a route label with a failure signature, repair hint, and budget trace. |
| Route distillation tournament | Axplorer/PatternBoost trains on elite constructions after local search and duplicate-aware exploration. | Generate many route plans, repair invalid ones, score by verifier/cost/latency/bytes, keep winners, and distill the winners into the tiny scout. |
| Query-page first, model later | Quest and MInference show KV/cache/attention work can be selected before dense attention. | The scout first chooses page and pattern families; only then does ActiveAssembly wake cold model material. |
| Depth/KV coupling | LayerSkip and MoD show depth can be conditional; Quest shows KV pages are query-conditional. | `LayerKVJointLease` chooses extra layers and KV pages together because a shallow route with wrong pages is false economy. |
| Contextual neuron locality | DejaVu and PowerInfer show contextual sparsity and hot/cold activation locality can be predicted. | Neural importance is route-conditioned and measured by ablation, not a global saliency superstition. |
| Quarantined fast weights | Titans/TTT show useful test-time memory/adaptation, but their risk is uncontrolled drift. | Fast weights update only selector thresholds and priors inside `FastWeightQuarantine` until held-out and rollback gates pass. |

### Mathematical control objective

For a candidate support unit or bundle `b`:

```text
RouteUtility(b) =
  E[Delta verified_quality | b, mission, trace]
  + E[Delta proof/citation/test repair | b]
  + E[Delta saved_prefill + Delta avoided_cold_miss | b]
  - lambda_bytes * active_bytes(b)
  - lambda_latency * p95_latency(b)
  - lambda_interference * interference_risk(b)
  - lambda_privacy * privacy_risk(b)
  - lambda_drift * fast_weight_drift(b)
```

The selection problem is a budgeted, uncertainty-aware maximum-utility problem:

```text
select B subject to
  sum(active_bytes(B)) <= byte_budget
  sum(kv_bytes(B)) <= kv_budget
  p95_latency(B) <= latency_budget
  verifier_coverage(B) >= required_coverage
  rollback(B) exists
```

If calibrated uncertainty is high, `BudgetedUncertaintyEscalator` must abstain,
run a shadow/full route, or request a verifier instead of pretending the cheap
scout knows.

## L17-Candidate: Verifier-Calibrated Sparse Wake Law

A substrate unit should wake only when a small scout predicts that its expected
verified marginal utility exceeds hot-byte, KV-byte, latency, interference,
and rollback cost, and the prediction improves under trace-backed verifier
regret.

```text
WakeScore(u | mission, state) =
  E[VerifierDelta(u)]
  + E[CitationValidityDelta(u)]
  + E[TestPassDelta(u)]
  + E[SavedPrefillOrColdIo(u)]
  + E[ConstructionSearchLift(u)]
  - HotBytes(u)
  - KVBytes(u)
  - WakeLatency(u)
  - InterferenceRisk(u)
  - PrivacyRisk(u)
  - RollbackCost(u)
```

Promotion condition:

- the scout is smaller and cheaper than the model route it controls;
- it can abstain and escalate instead of guessing;
- each wake proposal names units by UAS address or pinned runtime identity;
- the proposal reports expected hot/KV/cold bytes and verifier need;
- the scout can prove when it abstained, escalated, or used an oracle label;
- verifier/test/citation/trace outcome updates regret;
- session fast weights are bounded, local, inspectable, and resettable;
- durable learned policies beat static, embedding-only, recency-only, and
  full-wake baselines on held-out tasks; and
- AnswerPacket exposes the route decision and uncertainty.

## Primitive set

### `RouteScoutSSM`

Tiny always-hot selector for route family, proof need, KV/page need, depth
need, and escalation.

```text
RouteScoutSSM {
  task_signature
  source_features
  cache_features
  trace_features
  verifier_features
  hidden_state
  route_logits
  abstain_score
  escalation_score
}
```

### `TwoStageRouteScout`

Cheap scout split that prevents one tiny model from pretending to solve the
whole route problem.

```text
TwoStageRouteScout {
  stage_a_route_family
  stage_a_abstain
  stage_b_selector_kind: kv | depth | proof | adapter | cold_page | full_wake
  stage_b_candidate_units
  stage_b_uncertainty
  escalation_reason
}
```

Stage A chooses the family: stay local, wake Qwen, wake proof tools, wake
retrieval/KV, wake cold model pages, or abstain. Stage B only runs the selector
for that family. This keeps the always-hot footprint small and makes each
selector easier to test.

### `BudgetedUncertaintyEscalator`

Conformal-style guardrail for cheap selectors.

```text
BudgetedUncertaintyEscalator {
  scout_ref
  calibration_set_ref
  uncertainty
  coverage_target
  byte_budget_remaining
  latency_budget_remaining
  escalation_target
  abstain_reason
}
```

It is better for the scout to say "I do not know, wake a verifier/full route"
than to cheaply choose the wrong pages or layers with false confidence.

### `SparseWakeProposal`

The scout's candidate wake plan.

```text
SparseWakeProposal {
  proposal_id
  mission_id
  selected_units
  rejected_units
  expected_verifier_delta
  expected_quality_delta
  expected_hot_bytes
  expected_kv_bytes
  expected_cold_io
  expected_latency
  fallback_route
  uncertainty
}
```

### `VerifierBudgetAuction`

Budgeted competition among candidate units.

```text
VerifierBudgetAuction {
  candidates
  budget_vector
  verifier_need
  bid_score
  selected_bundle
  rejected_bundle
  abstain_reason
}
```

### `KVPageSketchIndex`

Page-level summary for query-aware KV/history selection.

```text
KVPageSketchIndex {
  page_id
  uas_address
  min_key_sketch
  max_key_sketch
  semantic_tags
  recency
  hit_count
  miss_count
  byte_count
  compatibility_fence
}
```

### `KVPageBloomSketch`

Very cheap negative filter for KV/page candidate sets.

```text
KVPageBloomSketch {
  sketch_id
  source_page_ref
  compatibility_fence
  feature_hashes
  false_positive_budget
  false_negative_policy: forbidden_for_required_evidence
  page_candidates
}
```

Bloom-like sketches are allowed to over-include pages but not silently drop
required evidence pages. Negative filtering is disabled for proof-critical or
privacy-critical evidence unless a falsifier proves coverage.

### `QueryAwareKVSelector`

Quest/SparQ/MInference-inspired selector that fetches only likely-critical
history pages.

```text
QueryAwareKVSelector {
  query_vector
  candidate_page_sketches
  top_k_pages
  dropped_pages
  expected_attention_error
  fallback_full_attention
}
```

### `LayerKVJointLease`

One lease that couples dynamic depth with selected KV/history pages.

```text
LayerKVJointLease {
  token_or_phase_ref
  selected_kv_pages
  selected_layers_or_passes
  shallow_exit_allowed
  verifier_margin
  expected_attention_error
  max_extra_layers
  full_depth_fallback
}
```

Depth and KV selection must be joint because the wrong history can make shallow
exit look confident. The lease declares both sides of the decision.

### `ConstructionSearchTournament`

PatternBoost/Axplorer-style loop for sparse wake plans.

```text
ConstructionSearchTournament {
  seed_plans
  generated_plans
  local_repair_steps
  score_function
  selected_plans
  duplicate_rate
  exploration_temperature
  next_training_set
}
```

### `RouteDistillationTournament`

Offline/shadow tournament that converts expensive full routes into tiny scout
training data.

```text
RouteDistillationTournament {
  full_route_traces
  proof_failure_traces
  generated_route_plans
  repaired_route_plans
  score_components
  selected_elites
  distilled_scout_labels
  held_out_split
}
```

This is the direct Axplorer/PatternBoost transfer: search widely under a
verifier, keep only routes that improve quality-per-byte, then distill those
route labels into a cheap scout.

### `ProofSearchSignal`

Lean/proof route result as a routing feature.

```text
ProofSearchSignal {
  theorem_or_claim_id
  premise_refs
  proof_state_hash
  tactic_trace_ref
  verifier_status
  failure_signature
  repair_hint
}
```

### `ProofPressureSignal`

Richer proof/compiler feedback signal for nontrivial reasoning tasks.

```text
ProofPressureSignal {
  claim_ref
  statement_preservation_score
  compiler_error_kind
  tactic_state_entropy
  missing_premise_refs
  verified_proof_neighbors
  failed_attempt_memory_ref
  route_pressure: retrieve | repair | deeper_model | verifier | abstain
}
```

Proof pressure is how formal systems teach routing. A failed proof can say the
app needs different premises, a different verifier lane, a deeper model pass, or
no answer yet.

### `VerifierRegretFastWeights`

Session-local fast weights for the scout/router, updated by verifier regret and
trace surprise.

```text
VerifierRegretFastWeights {
  scope: session | document | project
  base_policy_digest
  fast_weight_delta
  update_rule
  verifier_regret
  drift_bound
  ttl
  reset_handle
  consolidation_candidate
}
```

### `FastWeightQuarantine`

Admission cage for any session-time selector update.

```text
FastWeightQuarantine {
  proposed_delta_ref
  affected_policy_fields
  drift_bound
  ttl
  shadow_only_until
  reset_handle
  held_out_result_ref
  promotion_status
}
```

Fast weights first affect shadow routes only. They can touch route logits,
page thresholds, depth thresholds, verifier-prior tables, and tournament
exploration temperature. They cannot mutate base model weights or silently
change user-visible policy.

### `DepthLease`

Visible dynamic-depth contract.

```text
DepthLease {
  token_or_phase_ref
  shallow_exit_allowed
  deeper_layers_requested
  verifier_margin
  uncertainty
  max_extra_layers
  rollback_or_full_depth_check
}
```

### `ShadowWakeOracle`

Counterfactual route label source used before live routing changes.

```text
ShadowWakeOracle {
  mission_ref
  cheap_route_trace
  full_wake_trace
  proof_or_test_result
  unit_credit_assignment
  byte_latency_delta
  oracle_label
}
```

The oracle is not a runtime dependency. It is an evaluation and distillation
source that says which route the tiny scout should have chosen.

### `AblationShadowRun`

Cheap counterfactual for whether a unit mattered.

```text
AblationShadowRun {
  baseline_trace
  candidate_trace
  removed_unit
  quality_delta
  verifier_delta
  latency_delta
  byte_delta
  decision
}
```

### `AxiomAxiomaticSourceDistinction`

Source-card guard that keeps external formal-math/prover/company/tooling
motifs distinct before route-source claims can cite them.

```text
AxiomAxiomaticSourceDistinction {
  source_card
  source_class
  motif_class
  false_merge_negative
  stale_overclaim_guard
  route_impact = source_prior_only
  admission
  rollback
  run_event_log
  answer_packet
}
```

This is a metadata-only L1 witness. It does not integrate AXLE, Axplorer,
AxProver, OProver, UlamAI, Harmonic, Math Inc/OpenGauss, or Lean tooling as
live authority.

### `SparseRouteNoHiddenAuthority`

PASS metadata-only on 2026-06-04. It proves source priors, proof traces,
oracle labels, PatternBoost motifs, fast-weight deltas, scout proposals, and
sparse wake certificates stay visible proposal-only evidence; byte wake,
policy/base-weight/fast-weight/cache mutation, SCOPE-Rex/SovereignGate
override, AnswerPacket suppression, hidden chain/cloud, runtime/model bytes,
and high-uncertainty non-abstention reject. Current active cursor moves to
`F-ColdStream-NoHiddenAuthority`.

### `SparseWakeCertificate`

The visible proof that a sparse route was not just a guess.

```text
SparseWakeCertificate {
  proposal_ref
  selected_units
  budget_vector
  verifier_results
  citation_results
  test_results
  trace_refs
  uncertainty
  fallback
  rollback
}
```

## Execution bridge

The route compiler sits between Eidos and execution:

```text
MissionPacket
  -> Eidos evidence + SourceSignalGraph
  -> TaskSignature
  -> TwoStageRouteScout / RouteScoutSSM
  -> BudgetedUncertaintyEscalator
  -> SparseWakeProposal
  -> VerifierBudgetAuction
  -> QueryAwareKVSelector / KVPageBloomSketch
  -> ConstructionSearchTournament / RouteDistillationTournament
  -> LayerKVJointLease / DepthLease
  -> SemanticWorkingSetPlan
  -> ResidencyPageTable / PrefetchWindow
  -> RuntimeRouter / ActiveAssembly
  -> verifiers / tests / citations / trace observatory
  -> ShadowWakeOracle / FastWeightQuarantine
  -> VerifierRegretFastWeights
  -> RunEventLog + AnswerPacket
```

## Fast-weight discipline

Fast weights are allowed only for small selector and memory policies, not for
silent model-base mutation.

Allowed:

- session-local route scout updates;
- document/project-local verifier-regret priors;
- KV/page selection thresholds;
- layer/KV lease thresholds;
- proof-route preference tables;
- source/citation route priors;
- exploration temperature and tournament policy.

Not allowed:

- hidden base model weight mutation;
- durable fast-weight consolidation without held-out evidence;
- live route control before quarantine and shadow wins;
- user-visible claims based on private chain-of-thought;
- policy updates that bypass SCOPE-Rex/SovereignGate;
- updates without reset, TTL, drift bound, and AnswerPacket witness.

## Product plan

First implementation should be a dry-run artifact, not a live model hook:

1. build a tiny fixture corpus of tasks: rewrite, source answer, code question,
   proof question, long-context recall, and note mutation;
2. hand-label expected route family and verifier need;
3. implement `SparseWakeProposal` fixtures without waking model bytes;
4. add `ShadowWakeOracle` labels from full-route/proof/test traces;
5. run a tiny `RouteDistillationTournament` and hold out tasks before training;
6. compare scout choices against static baseline, embedding-only baseline, and
   "wake local Qwen for everything";
7. verify `BudgetedUncertaintyEscalator` abstains on out-of-distribution tasks;
8. emit `SparseWakeCertificate` into AnswerPacket mock data;
9. only then consider Core ML/ANE/SSM/linear scout implementation.

## Canonical read rule

Read this file when a session touches Axiom/Axplorer/PatternBoost, Axiomatic
AI AxProver, OProver, proof construction loops, Lean route selection, sparse
attention, query-aware KV selection, RouteLLM-style routing,
DejaVu/PowerInfer-style contextual sparsity, LayerSkip/Mixture-of-Depths dynamic
compute, Titans/TTT fast weights, Mamba/SSM route scouts, route distillation
tournaments, proof-pressure labels, "proper weights/KV/neurons/params for the
task", or any plan to reduce heavy LLM wakes through a small chooser.
