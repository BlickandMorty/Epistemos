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
| `F-SparseWakeProposal-Budget` | Current active cursor: wake proposals name selected/rejected units, expected hot/KV/cold bytes, fallback, uncertainty, and verifier need. | JSON fixture plus negative missing-field cases. |
| `F-VerifierBudgetAuction` | Candidate units compete under a budget and the auction rejects over-budget bundles before execution. | Budgeted selection fixture with over-budget negative. |
| `F-KVPageSketchIndex` | KV/page sketches bind UAS address, byte count, compatibility fence, min/max or semantic sketches, hits, misses, and privacy class. | Sketch-index fixture plus stale/incompatible rejection. |
| `F-KVPageBloomSketch-Coverage` | Bloom-like page filters may over-include but must not drop required proof/citation evidence under the declared coverage target. | Required-evidence fixture plus false-negative regression. |
| `F-QueryAwareKVSelector` | Query-aware KV/page selection beats full-random, recency-only, and file-order baselines on held-out long-context fixtures. | Long-context fixture plus recall/latency table. |
| `F-LayerKVJointLease` | Dynamic depth and KV/page selection are decided together, with expected attention error, verifier margin, and full-depth fallback. | Joint lease fixture plus shallow-wrong-page negative. |
| `F-ConstructionSearchTournament` | PatternBoost/Axplorer-style generate-repair-score-select improves sparse wake plans over random generation under a fixed budget. | Tiny tournament fixture plus duplicate/exploration metrics. |
| `F-RouteDistillationTournament` | Expensive full/proof/oracle traces produce held-out route labels that improve the small scout over direct heuristics. | Trace-to-label dataset plus train/held-out split and baseline comparison. |
| `F-ProofSearchSignal-RouteFeedback` | Lean/proof outcomes produce route features without becoming hidden truth or bypassing AnswerPacket. | Proof trace fixture with pass/fail/repair cases. |
| `F-ProofPressureSignal` | Compiler errors, tactic-state entropy, missing premises, and failed attempt memory produce explicit route-pressure labels. | Proof-pressure fixture plus statement-preservation and missing-premise cases. |
| `F-VerifierRegretFastWeights` | Fast-weight updates are bounded, session/local scoped, resettable, TTL-limited, and improve held-out route choice before consolidation. | Drift-bound test plus reset and held-out regression. |
| `F-FastWeightQuarantine` | Fast-weight deltas remain shadow-only until drift, held-out, rollback, TTL, and AnswerPacket gates pass. | Quarantine state machine plus live-control rejection case. |
| `F-DepthLease-Checkpoint` | Dynamic-depth decisions declare shallow exit, deeper wake, verifier margin, maximum extra layers, and full-depth fallback. | Depth-lease fixture plus invalid silent-depth negative. |
| `F-ShadowWakeOracle` | Full-wake/proof/test oracle traces create route labels without becoming a live runtime dependency. | Oracle-label fixture plus no-runtime-dependency static check. |
| `F-AblationShadowRun` | Claimed useful units survive a counterfactual remove-one-unit comparison on quality, verifier, latency, and bytes. | Baseline/candidate traces plus decision record. |
| `F-SparseWakeCertificate-AnswerPacket` | Sparse route answers expose selected units, budgets, verifier/citation/test results, traces, uncertainty, fallback, and rollback. | AnswerPacket fixture plus UI summary. |
| `F-AxiomAxiomatic-SourceDistinction` | Axiom AXLE/Axplorer construction motifs, Axiomatic AxProver/OProver proof-agent motifs, Harmonic artifacts, and Math Inc/OpenGauss workflows remain distinct source classes. | Source-card fixture plus false-merge negative. |
| `F-SparseRoute-NoHiddenAuthority` | The compiler cannot wake bytes, mutate policy, consolidate fast weights, or override SCOPE-Rex/SovereignGate alone. | Static architecture check plus negative route fixture. |

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
