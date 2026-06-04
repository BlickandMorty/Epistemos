# F-BudgetedUncertaintyEscalator — Witness

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## 2026-06-03 Result

- Status: PASS, metadata-only.
- Script: `Tools/falsifiers/f_budgeted_uncertainty_escalator.sh`
- Artifact: `artifacts/falsifiers/budgeted_uncertainty_escalator/result.json`
- L1 next cursor at landing: `F-SparseWakeProposal-Budget`; current cursor after the 2026-06-04 `F-RouteDistillationTournament` witness is `F-ProofSearchSignal-RouteFeedback`
- L2 product route: still `vault_research_route_with_packetized_mitigation`
- L3 user-facing/runtime: unchanged; no live route authority promoted.

## What Passed

The witness proves a metadata-only BudgetedUncertaintyEscalator fixture where cheap route selectors cannot choose a wrong low-cost path when uncertainty, calibration, OOD, byte budget, latency budget, evidence coverage, or verifier coverage says to abstain or escalate. The fixture includes 2 training rows, 8 held-out rows, 7 escalation cases, and 3 allowed cheap-route cases. The escalator reaches `10000` bps decision success against a cheap-route baseline at `2500` bps and an always-escalate baseline at `3750` bps, while active metadata stays under `1048576` bytes and runtime/model bytes loaded remain zero.

The witness binds task signatures, mission IDs, upstream TwoStageRouteScout refs, calibration refs, coverage targets, byte and latency budgets, verifier coverage requirements, rollback handles, RunEventLog refs, AnswerPacket refs, deterministic UAS address, and shadow-only route authority. It rejects duplicate tasks, missing calibration/scout/coverage/budget/latency/escalation/abstain fields, high-uncertainty cheap allowance, missing-calibration cheap allowance, OOD cheap allowance, byte/latency/evidence/verifier coverage shortfall cheap allowance, unbeaten cheap and always-escalate baselines, missing rollback/log/AnswerPacket, hidden live authority, live policy mutation, hidden-chain exposure, cloud routes, and over-budget escalators.

## Scope Guard

This advances L1 only. It does not make RouteScoutSSM, TwoStageRouteScout, or BudgetedUncertaintyEscalator a live router, does not promote sparse wake execution, and does not change MAS/Pro product copy. `F-SparseWakeProposal-Budget`, `F-VerifierBudgetAuction`, `F-KVPageSketchIndex`, and `F-KVPageBloomSketch-Coverage` now pass as metadata-only evidence; `F-SparseWakeCertificate-AnswerPacket` now passes metadata-only evidence; the `F-LayerKVJointLease` now passes metadata-only evidence; the current architecture unit is `F-FastWeightQuarantine`, which must prove fast-weight deltas remain quarantined and shadow-only until drift, held-out, rollback, TTL, reset, RunEventLog, and AnswerPacket gates pass.
