---
state: passed
created_on: 2026-06-04
falsifier_id: F-ProofSearchSignal-RouteFeedback
artifact: artifacts/falsifiers/proof_search_signal_route_feedback/result.json
scope: metadata-only architecture witness
---

# F-ProofSearchSignal-RouteFeedback

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

- Result: PASS as a metadata-only primary witness on 2026-06-04.
- Script: `Tools/falsifiers/f_proof_search_signal_route_feedback.sh`
- Artifact: `artifacts/falsifiers/proof_search_signal_route_feedback/result.json`
- L1 next cursor at landing: `F-ProofPressureSignal`; current cursor after the 2026-06-04 VerifierRegretFastWeights witness: `F-FastWeightQuarantine`
- L2 product route: unchanged, `vault_research_route_with_packetized_mitigation`; current next bottleneck `fast_weight_quarantine`
- L3 user-facing/runtime route: unchanged; no proof feedback live route authority, live sparse routing, local model-byte load, 70B runtime claim, autogenous-kernel mutation, or UI claim is promoted.

## What It Proves

The witness proves a metadata-only `ProofSearchSignal` fixture where proof pass, fail, repair, and abstain outcomes become explicit route features without becoming hidden truth authority. Each signal binds premise refs, proof-state hash, tactic trace ref, verifier status, failure signature, repair hint, route feature label, test/citation refs, SCOPE-Rex ref, SovereignGate ref, rollback, RunEventLog, AnswerPacket ref, deterministic UAS address, compatibility fence, privacy class, and shadow-only route authority.

The fixture includes 2 proof-signal fixtures, 12 signals, 6 train cases, 6 held-out cases, 4 verifier statuses, and 5 route feature labels. Held-out route success is `9000` bps, verifier alignment is `9200` bps, AnswerPacket coverage is `10000` bps, and calibration error is bounded at `700` bps. The deterministic address is `uas:proof-search-signal:sha256:92ce3093f4c141f53f65a656d161a6edd7fcd6f2a0786261c9218746baf92539`. Runtime/model bytes loaded remain zero.

## Hardening

The falsifier rejects empty fixtures; duplicate fixtures; duplicate signals; missing premise refs, proof-state hashes, tactic traces, verifier statuses, failure signatures, repair hints, route feature labels, test refs, citation refs, SCOPE-Rex refs, SovereignGate refs, rollback, RunEventLog, or AnswerPacket evidence; invalid verifier status; hidden truth authority; verifier, test, citation, SCOPE-Rex, or SovereignGate bypass; hidden live route authority; live policy promotion; hidden-chain exposure; cloud sources; runtime-byte load; model-byte load; incompatible fences; invalid privacy classes; unbeaten proof-feature, route-distillation-only, or no-proof-feedback baselines; high calibration error; missing status diversity; missing route-feature diversity; metadata over budget; and proof-token overflow.

## Scope

This advances L1 only. It does not make proof feedback a live router, does not allow a proof assistant to bypass tests, citations, SCOPE-Rex, SovereignGate, RunEventLog, or AnswerPacket, does not promote sparse wake execution, does not load local model bytes, does not promote the 70B track to product runtime, and does not change MAS/Pro user copy. `F-ProofPressureSignal` now passes as metadata-only evidence; the current architecture unit is `F-FastWeightQuarantine`, which must prove fast-weight deltas remain quarantined and shadow-only until drift, held-out, rollback, TTL, reset, RunEventLog, and AnswerPacket gates pass.
