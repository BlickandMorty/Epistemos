---
state: passed
created_on: 2026-06-04
falsifier_id: F-VerifierRegretFastWeights
artifact: artifacts/falsifiers/verifier_regret_fast_weights/result.json
scope: metadata-only architecture witness
---

# F-VerifierRegretFastWeights

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

- Result: PASS as a metadata-only primary witness on 2026-06-04.
- Script: `Tools/falsifiers/f_verifier_regret_fast_weights.sh`
- Artifact: `artifacts/falsifiers/verifier_regret_fast_weights/result.json`
- L1 next cursor at landing: `F-FastWeightQuarantine`; current cursor after the ShadowWakeOracle witness: `F-AblationShadowRun`
- L2 product route: unchanged, `vault_research_route_with_packetized_mitigation`; current next bottleneck `small_model_runtime_harness_fresh_product_runtime_answer_packet_probe` after downstream `F-SmallModelRuntimeHarnessFreshProductRuntimeLiveProbe`
- L3 user-facing/runtime route: unchanged; no fast-weight live route authority, base-weight mutation, live policy promotion, model-byte load, 70B runtime claim, autogenous-kernel mutation, or UI claim is promoted.

## What It Proves

The witness proves a metadata-only `VerifierRegretFastWeights` fixture where verifier-regret and trace-surprise updates can produce bounded shadow selector-policy deltas without mutating base weights or changing live routing. Each update binds a session/document/project scope, base policy digest, delta ref, update rule, verifier-regret ref, trace-surprise ref, affected policy fields, drift bound, TTL, reset handle, rollback handle, RunEventLog, AnswerPacket, held-out result, consolidation candidate, compatibility fence, privacy class, and shadow-only route authority.

The fixture includes 2 fast-weight fixtures, 10 updates, 3 scopes, 5 affected policy fields, and 6 held-out cases. Held-out route success is `9050` bps, route-regret reduction is `1100` bps, AnswerPacket coverage is `10000` bps, max observed drift is `520` bps under an `850` bps bound, TTLs range from `18000` to `75000` ms, and static/no-fast-weight/stale/unbounded baselines are all beaten. The deterministic address is `uas:verifier-regret-fast-weights:sha256:84dbd29d96a41ef031a4cbeef312d37a2639d7097c05b70d612d838174eff3b0`. Runtime/model bytes loaded remain zero.

## Hardening

The falsifier rejects empty fixtures; duplicate fixtures; missing fixture ID, upstream ProofPressureSignal ref, shadow policy, updates, update ID, scope, base policy digest, delta ref, update rule, verifier-regret ref, trace-surprise ref, affected policy fields, drift bound, TTL, reset handle, rollback, RunEventLog, AnswerPacket, held-out result, consolidation candidate, or held-out split; invalid scope, policy field, split, compatibility fence, or privacy class; route-logit/page-threshold/depth-threshold/verifier-prior/tournament-temperature delta overflow; drift overflow; expired TTL; consolidation promotion; base-weight mutation; live policy promotion; hidden route authority; hidden-chain exposure; cloud source; runtime-byte load; model-byte load; unbeaten static/no-fast/stale/unbounded baselines; and metadata-budget overflow.

## Scope

This advanced L1 only at landing. It does not make verifier-regret fast weights a live router, does not consolidate policy, does not mutate base model weights, does not allow hidden PatternBoost/lattice/Eidos route authority, does not load local model bytes, does not promote the 70B track to product runtime, and does not change MAS/Pro user copy. The downstream `F-FastWeightQuarantine` and `F-DepthLease-Checkpoint` witnesses now pass metadata-only evidence, so the current architecture unit is `F-AblationShadowRun`.
