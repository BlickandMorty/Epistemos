# F-TwoStageRouteScout-Abstain — Witness

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## 2026-06-03 Result

- Status: PASS, metadata-only.
- Script: `Tools/falsifiers/f_two_stage_route_scout_abstain.sh`
- Artifact: `artifacts/falsifiers/two_stage_route_scout_abstain/result.json`
- L1 next cursor at landing: `F-BudgetedUncertaintyEscalator`; current cursor after the 2026-06-04 `F-RouteDistillationTournament` witness is `F-ProofSearchSignal-RouteFeedback`.
- L2 product route: still `vault_research_route_with_packetized_mitigation`
- L3 user-facing/runtime: unchanged; no live route authority promoted.

## What Passed

The witness proves a two-stage route scout fixture where Stage A chooses only route family/escalation and Stage B chooses only the family-specific selector. The fixture includes 2 training rows, 7 held-out rows, 7 route families, and 2 abstention cases. The two-stage route reaches `10000` bps route success against a best baseline of `7142` bps, reaches `10000` bps abstention accuracy, and stays under a `4194304` byte metadata budget while loading zero model/runtime bytes.

The witness binds task signatures, mission IDs, source and verifier features, Stage A refs, Stage B refs, rollback handles, RunEventLog refs, AnswerPacket refs, deterministic UAS address, and shadow-only route authority. It rejects duplicate tasks, missing Stage A/B refs, Stage A selector leakage, family/selector mismatch, irrelevant selector choice, missing abstain threshold, high-uncertainty non-abstention, verifier-conflict non-abstention, unbeaten all-in-one/static/no-abstain baselines, missing rollback/log/AnswerPacket, hidden live authority, live policy mutation, hidden-chain exposure, cloud routes, over-budget two-stage routes, and routes not cheaper than the heavy path.

## Scope Guard

This advances L1 only. It does not make RouteScoutSSM or TwoStageRouteScout a live router, does not promote sparse wake execution, and does not change MAS/Pro product copy. `F-BudgetedUncertaintyEscalator`, `F-SparseWakeProposal-Budget`, `F-VerifierBudgetAuction`, `F-KVPageSketchIndex`, and `F-KVPageBloomSketch-Coverage` now pass as metadata-only evidence; `F-SparseWakeCertificate-AnswerPacket` now passes metadata-only evidence; the `F-LayerKVJointLease` now passes metadata-only evidence; the current architecture unit is `F-FastWeightQuarantine`, which must prove fast-weight deltas remain quarantined and shadow-only until drift, held-out, rollback, TTL, reset, RunEventLog, and AnswerPacket gates pass.
