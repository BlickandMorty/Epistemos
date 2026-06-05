---
state: candidate-falsifier-bundle
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source: docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md
status: backlog gates; no live routing promotion without fixtures and baselines
---

# Falsifier Bundle - Verifier-Calibrated Sparse Route Compiler

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Purpose

These gates keep the sparse-route compiler from becoming a hidden model router
or a wishful "wake fewer neurons" claim. A sparse wake route promotes only when
it is cheaper than the route it controls, trace-visible, verifier-calibrated,
and better than simple baselines.

## Candidate falsifiers

| Falsifier | Must prove | Minimum artifact |
|---|---|---|
| `F-RouteScoutSSM-Baseline` | PASS metadata-only witness on 2026-06-03: a small scout predicts route family/verifier need better than static, random, recency, and embedding-only baselines with rollback, RunEventLog, AnswerPacket, calibration, and no-hidden-authority guards. | `artifacts/falsifiers/route_scout_ssm_baseline/result.json`; live routing remains unpromoted. |
| `F-TwoStageRouteScout-Abstain` | PASS metadata-only witness on 2026-06-03: Stage A chooses only route family/escalation, Stage B chooses only family-specific selectors, high uncertainty/conflict abstains, all-in-one/static/no-abstain baselines are beaten, and rollback/RunEventLog/AnswerPacket/no-hidden-authority guards hold. | `artifacts/falsifiers/two_stage_route_scout_abstain/result.json`; live routing remains unpromoted. |
| `F-BudgetedUncertaintyEscalator` | PASS metadata-only witness on 2026-06-03: high uncertainty, byte/latency budget exhaustion, missing calibration, OOD, evidence coverage shortfall, or verifier-coverage shortfall causes visible abstain/escalate rather than a cheap wrong route; cheap and always-escalate baselines are beaten with rollback, RunEventLog, AnswerPacket, and no-hidden-authority guards. | `artifacts/falsifiers/budgeted_uncertainty_escalator/result.json`; live routing remains unpromoted. |
| `F-SparseWakeProposal-Budget` | PASS metadata-only witness on 2026-06-04: wake proposals name selected/rejected UAS units, hot/KV/cold byte budgets, fallback, uncertainty, verifier need, rollback, RunEventLog, and AnswerPacket before any live wake request; wake-all/static/Qwen-everything baselines are beaten and no runtime/model bytes load. | `artifacts/falsifiers/sparse_wake_proposal_budget/result.json`; live routing remains unpromoted. |
| `F-VerifierBudgetAuction` | PASS metadata-only witness on 2026-06-04: candidate units compete under verifier, byte, latency, privacy, interference, and rollback budgets; over-budget, low-verifier, hidden-authority, cloud, hidden-chain, live-mutation, and unbeaten-baseline cases reject before execution. | `artifacts/falsifiers/verifier_budget_auction/result.json`; live routing remains unpromoted. |
| `F-KVPageSketchIndex` | PASS metadata-only witness on 2026-06-04: KV/page sketches bind UAS address, byte count, compatibility fence, min/max sketches, semantic tags, hits, misses, required-evidence coverage, privacy class, rollback, RunEventLog, AnswerPacket, and shadow-only authority; stale/incompatible pages, missing evidence, hidden authority, cloud sources, and unbeaten baselines reject before selection. | `artifacts/falsifiers/kv_page_sketch_index/result.json`; live KV restore and query-aware selection remain unpromoted. |
| `F-KVPageBloomSketch-Coverage` | PASS metadata-only witness on 2026-06-04: bloom-like page filters may over-include but cannot drop required proof/privacy evidence; proof-critical and privacy-critical negative filtering rejects, and rollback/RunEventLog/AnswerPacket/no-hidden-authority guards hold. | `artifacts/falsifiers/kv_page_bloom_sketch_coverage/result.json`; live KV restore and query-aware selection remain unpromoted. |
| `F-QueryAwareKVSelector` | PASS metadata-only witness on 2026-06-04: query-aware KV/page selection consumes sketch/Bloom evidence, beats random, recency-only, file-order, and Bloom-only baselines, and stays rollback/RunEventLog/AnswerPacket-bound with zero runtime bytes. | `artifacts/falsifiers/query_aware_kv_selector/result.json`. |
| `F-SparseWakeCertificate-AnswerPacket` | PASS metadata-only witness on 2026-06-04: selected sparse/KV units, budgets, verifier/citation/test results, traces, uncertainty, fallback, and rollback are exposed in an AnswerPacket-bound certificate; no live sparse route authority promotes. | `artifacts/falsifiers/sparse_wake_certificate_answer_packet/result.json`. |
| `F-LayerKVJointLease` | PASS metadata-only witness: dynamic depth and KV/page selection are leased together with expected attention error, verifier margin, full-depth fallback, rollback, RunEventLog, AnswerPacket, and zero runtime bytes. | `artifacts/falsifiers/layer_kv_joint_lease/result.json`; live dynamic depth and KV restore remain unpromoted. |
| `F-ConstructionSearchTournament` | PASS metadata-only witness on 2026-06-04: offline generate-repair-score-select improves sparse wake plans over random, greedy, and unrepaired baselines under fixed budget with rollback, RunEventLog, AnswerPacket, and zero runtime bytes. | `artifacts/falsifiers/construction_search_tournament/result.json`; PatternBoost remains offline/shadow-only. |
| `F-RouteDistillationTournament` | PASS metadata-only witness on 2026-06-04: expensive full/proof/oracle/compiler/failure traces produce held-out route labels that improve the small scout over direct heuristics. | `artifacts/falsifiers/route_distillation_tournament/result.json`; route distillation remains offline/shadow-only. |
| `F-ProofSearchSignal-RouteFeedback` | PASS metadata-only witness on 2026-06-04: Lean/proof pass/fail/repair/abstain outcomes produce route features without hidden truth or verifier/test/citation/SCOPE-Rex/SovereignGate/AnswerPacket bypass. | `artifacts/falsifiers/proof_search_signal_route_feedback/result.json`; proof feedback remains offline/shadow-only. |
| `F-ProofPressureSignal` | PASS metadata-only witness on 2026-06-04: compiler errors, tactic-state entropy, missing premises, verified proof neighbors, and failed-attempt memory produce explicit route-pressure labels without hidden truth, statement mutation, governance bypass, or runtime/model bytes. | `artifacts/falsifiers/proof_pressure_signal/result.json`; proof pressure remains offline/shadow-only. |
| `F-VerifierRegretFastWeights` | PASS metadata-only witness on 2026-06-04: fast-weight updates are bounded, session/document/project scoped, resettable, TTL-limited, shadow-only, rollback-bound, AnswerPacket-visible, and improve held-out route choice before consolidation without base-weight mutation or runtime/model bytes. | `artifacts/falsifiers/verifier_regret_fast_weights/result.json`; fast weights remain offline/shadow-only. |
| `F-FastWeightQuarantine` | PASS metadata-only witness on 2026-06-04: fast-weight deltas remain quarantined, session-local, resettable, TTL-limited, rollback-bound, AnswerPacket-visible, mutation-safe, shadow-only, and reject live-control authority before held-out release. | `artifacts/falsifiers/fast_weight_quarantine/result.json`; quarantine remains offline/shadow-only and advances L1 only. |
| `F-DepthLease-Checkpoint` | PASS metadata-only witness on 2026-06-04: dynamic-depth decisions declare shallow exit, deeper wake, verifier margin, maximum extra layers, full-depth fallback, checkpoint/resume token, rollback, RunEventLog, AnswerPacket fields, mutation-safety fence, and no silent promotion. | `artifacts/falsifiers/depth_lease_checkpoint/result.json`; live dynamic depth remains unpromoted and advances L1 only. |
| `F-ShadowWakeOracle` | PASS metadata-only witness on 2026-06-04: full-wake/proof/test oracle traces create route labels, bind unit-credit and byte/latency deltas, beat cheap/full-wake/no-oracle baselines, and cannot become a hidden live runtime dependency. | `artifacts/falsifiers/shadow_wake_oracle/result.json`; oracle labels remain offline/shadow-only and advance L1 only. |
| `F-AblationShadowRun` | PASS metadata-only witness on 2026-06-04: claimed useful units survive counterfactual remove-one-unit comparison on quality, verifier, latency, and bytes while shadow-only, rollback-bound, RunEventLog-bound, AnswerPacket-visible, and barred from live route promotion. | `artifacts/falsifiers/ablation_shadow_run/result.json`; downstream `F-AxiomAxiomatic-SourceDistinction` now passes metadata-only; L2 remains `vault_research_route_with_packetized_mitigation`. |
| `F-SparseWakeCertificate-AnswerPacket` | PASS metadata-only witness: sparse route answers expose selected units, budgets, verifier/citation/test results, traces, uncertainty, fallback, and rollback. | AnswerPacket fixture plus UI summary. |
| `F-AxiomAxiomatic-SourceDistinction` | PASS metadata-only witness on 2026-06-04: Axiom AXLE/Axplorer construction motifs, Axiomatic AxProver/OProver proof-agent motifs, Harmonic artifacts, UlamAI, Lean tooling, and Math Inc/OpenGauss workflows remain distinct source classes and source-prior-only. | `artifacts/falsifiers/axiom_axiomatic_source_distinction/result.json`; downstream SparseRoute now passes metadata-only; L2 remains `vault_research_route_with_packetized_mitigation`. |
| `F-SparseRoute-NoHiddenAuthority` | PASS metadata-only witness on 2026-06-04: source priors, proof traces, oracle labels, PatternBoost motifs, fast-weight deltas, scout proposals, and sparse wake certificates stay visible proposal-only evidence; byte wake, policy/base-weight/fast-weight/cache mutation, SCOPE-Rex/SovereignGate override, AnswerPacket suppression, hidden chain/cloud, runtime/model bytes, and high-uncertainty non-abstention reject. | `artifacts/falsifiers/sparse_route_no_hidden_authority/result.json`; downstream ColdStream, large-model deferral, ProviderRoute copy-source guard, TransportTrace AnswerPacket, SSD wear-budget, ColdStream-vs-mmap, SlabArena copy-count, Metal I/O feature-gate, CodecStage latency, TransportCancellation, and CachePolicy witnesses now pass metadata-only; L2 remains `vault_research_route_with_packetized_mitigation` with `next_bottleneck=small_model_runtime_harness_safety_plan` after `F-ProductRouteReview`. |
| `F-ColdStream-NoHiddenAuthority` | PASS metadata-only witness on 2026-06-04: ColdStream transport manifests bind SemanticWorkingSetPlan, ResidencyPageTable, byte ranges, checksums, destination/priority/cache lanes, leases, cancellation, fallback, SCOPE-Rex/SovereignGate admission, rollback, RunEventLog, AnswerPacket, and proposal-only authority while rejecting hidden byte wake, route-policy mutation, admission override, hidden chain/cloud, runtime/model bytes, stale slabs, invisible traces, and unbeaten baselines. | `artifacts/falsifiers/coldstream_no_hidden_authority/result.json`; downstream large-model deferral, ProviderRoute copy-source guard, TransportTrace AnswerPacket, SSD wear-budget, ColdStream-vs-mmap, SlabArena copy-count, Metal I/O feature-gate, CodecStage latency, TransportCancellation, and CachePolicy witnesses now pass; current cursor is `small_model_runtime_harness_safety_plan` after `F-ProductRouteReview`; L2/L3 remain unchanged. |
| `F-LargeModelProviderReference-DeferredByMlxRoute` | PASS metadata-only witness on 2026-06-04: provider/fp16 prompt-level reference, KV-Direct 128K shard work, dense 70B runtime, and live sparse 70B runtime remain deferred by the practical MLX route while cold-assembly architecture stays preserved. | `artifacts/falsifiers/large_model_provider_reference_deferred_by_mlx_route/result.json`; downstream ProviderRoute copy-source guard, TransportTrace AnswerPacket, SSD wear-budget, ColdStream-vs-mmap, SlabArena copy-count, Metal I/O feature-gate, CodecStage latency, TransportCancellation, and CachePolicy witnesses now pass; current cursor is `small_model_runtime_harness_safety_plan` after `F-ProductRouteReview`; L2 remains `vault_research_route_with_packetized_mitigation` with `next_bottleneck=small_model_runtime_harness_safety_plan` after `F-ProductRouteReview`; L3 is unchanged. |
| `F-ProviderRoute-CopySourceGuard` | PASS metadata-only witness on 2026-06-04: Living Index and lattice HTML copy keep provider-reference, KV-Direct 128K, dense 70B, live sparse 70B, and practical MLX routing source-only, with no provider calls, prompt manifests, source laundering, hidden cloud fallback, route-policy mutation, hidden authority, runtime/model bytes, or L2/L3 promotion. | `artifacts/falsifiers/provider_route_copy_source_guard/result.json`; downstream TransportTrace AnswerPacket, SSD wear-budget, ColdStream-vs-mmap, SlabArena copy-count, Metal I/O feature-gate, CodecStage latency, TransportCancellation, and CachePolicy now pass; current cursor is `small_model_runtime_harness_safety_plan` after `F-ProductRouteReview`; L2 remains `vault_research_route_with_packetized_mitigation`; L3 is unchanged. |

## Promotion rule

A sparse selector can affect live routing only when:

1. the scout is cheaper than the heavy route it controls;
2. it can abstain and escalate;
3. all selected units are addressable and budgeted;
4. uncertainty is calibrated against held-out fixtures;
5. verifier/test/citation/proof-pressure traces feed regret;
6. fast weights are quarantined, bounded, resettable, and TTL-limited;
7. held-out tasks beat simple baselines;
8. failures are visible in RunEventLog and AnswerPacket; and
9. rollback exists for route, policy, fast-weight, cache, and layout changes.

## Companion gates

- Residency PatternBoost bundle:
  `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`
- Semantic working-set compiler bundle:
  `docs/falsifiers/F-SEMANTIC-WORKING-SET-COMPILER-BUNDLE_2026_06_01.md`
- Constructive residency bundle:
  `docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md`
