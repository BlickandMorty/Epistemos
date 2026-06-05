---
state: passed
created_on: 2026-06-04
falsifier_id: F-ConstructionSearchTournament
artifact: artifacts/falsifiers/construction_search_tournament/result.json
scope: metadata-only architecture witness
---

# F-ConstructionSearchTournament

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

- Result: PASS as a metadata-only primary witness on 2026-06-04.
- Script: `Tools/falsifiers/f_construction_search_tournament.sh`
- Artifact: `artifacts/falsifiers/construction_search_tournament/result.json`
- L1 next cursor at landing: `F-RouteDistillationTournament`; current cursor after the 2026-06-04 RouteDistillationTournament witness is `F-ProofSearchSignal-RouteFeedback`
- L2 product route: unchanged, `vault_research_route_with_packetized_mitigation`; current next bottleneck `small_model_runtime_harness_logged_runtime_smoke` after downstream `F-SmallModelRuntimeHarnessAbortableRuntimeProbe`
- L3 user-facing/runtime route: unchanged; no PatternBoost live route authority, live sparse routing, local model-byte load, 70B runtime claim, autogenous-kernel mutation, or UI claim is promoted.

## What It Proves

The witness proves a metadata-only `ConstructionSearchTournament` fixture where an offline PatternBoost/Axplorer-style generate-repair-score-select loop improves sparse wake plans under a fixed budget. Each tournament binds mission family, upstream LayerKVJointLease evidence, generation policy, repair policy, scoring policy, selection policy, random seed, exploration budget, held-out split, rollback, RunEventLog, AnswerPacket reference, deterministic tournament address, and shadow-only route authority.

The fixture includes 2 tournaments, 10 candidates, 8 repaired candidates, 4 selected winners, 6 held-out cases, and at least 4 diversity buckets. Tournament success is `9400` bps and held-out success is `8900` bps while random generation, greedy, and unrepaired baselines stay below the selected winners. Repair failure is bounded at `2000` bps. Runtime/model bytes loaded remain zero.

## Hardening

The falsifier rejects empty fixtures; duplicate tournaments; duplicate candidates; missing generation, repair, scoring, or selection policies; missing candidates; unrepaired or invalid selected winners; over-budget selected winners; missing rollback, RunEventLog, or AnswerPacket evidence; hidden live route authority; live route promotion; hidden-chain exposure; cloud sources; runtime-byte load; metadata over budget; unbeaten random, greedy, or unrepaired baselines; insufficient diversity; and exploration-budget overflow.

## Scope

This advances L1 only. It does not make `ConstructionSearchTournament` a live router, does not allow PatternBoost to become hidden live route authority, does not promote sparse wake execution, does not load local model bytes, does not promote the 70B track to product runtime, and does not change MAS/Pro user copy. `F-RouteDistillationTournament` now passes metadata-only evidence; the next architecture unit is `F-ProofSearchSignal-RouteFeedback`, which must prove Lean/proof outcomes become route features without hidden truth, verifier bypass, or AnswerPacket omission.
