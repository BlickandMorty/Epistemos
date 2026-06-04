---
state: passed
created_on: 2026-06-04
falsifier_id: F-LayerKVJointLease
artifact: artifacts/falsifiers/layer_kv_joint_lease/result.json
scope: metadata-only architecture witness
---

# F-LayerKVJointLease

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

- Result: PASS as a metadata-only primary witness on 2026-06-04.
- Script: `Tools/falsifiers/f_layer_kv_joint_lease.sh`
- Artifact: `artifacts/falsifiers/layer_kv_joint_lease/result.json`
- L1 next cursor at landing: `F-ConstructionSearchTournament`; current cursor after the 2026-06-04 RouteDistillationTournament witness is `F-ProofSearchSignal-RouteFeedback`
- L2 product route: unchanged, `vault_research_route_with_packetized_mitigation`; current next bottleneck `proof_search_signal_route_feedback`
- L3 user-facing/runtime route: unchanged; no live dynamic-depth route, live KV restore, sparse selector promotion, local model-byte load, 70B runtime claim, or UI claim is promoted.

## What It Proves

The witness proves a metadata-only `LayerKVJointLease` fixture where dynamic depth and selected KV/page choices are leased together, not independently. Each lease binds mission, AnswerPacket, upstream SparseWakeCertificate, route-card, joint decision, shallow/full-depth plan, selected layers, checkpoint refs, selected UAS KV pages, compatibility fences, privacy classes, attention-error estimate, verifier margin, byte budgets, latency budget, full-depth fallback, rollback, RunEventLog, deterministic lease address, and shadow-only route authority.

The fixture includes 2 joint leases, 6 selected KV pages, 4 required-evidence pages, and 4 depth checkpoints. Lease success is `9500` bps while depth-only, KV-only, independent-greedy, and shallow-wrong-page baselines stay below the joint lease. Runtime/model bytes loaded remain zero.

## Hardening

The falsifier rejects empty fixtures; duplicate leases; duplicate KV pages; missing depth plans; missing selected KV pages; missing or uncoupled joint decisions; stale selected pages; incompatible depth/page fences; invalid privacy classes; hot/KV/cold/latency/extra-layer budget breaches; attention-error overflow; verifier-margin underflow; missing full-depth fallback; missing rollback, RunEventLog, or AnswerPacket fields; hidden live authority; live route promotion; hidden-chain exposure; cloud sources; runtime-byte load; metadata over budget; shallow-wrong-page acceptance; and unbeaten baselines.

## Scope

This advances L1 only. It does not make `LayerKVJointLease` a live router, does not restore live KV pages, does not permit hidden PatternBoost/lattice/Eidos route authority, does not load local model bytes, does not promote the 70B track to product runtime, and does not change MAS/Pro user copy. `F-ConstructionSearchTournament` now passes as metadata-only evidence; the current architecture unit is `F-ProofSearchSignal-RouteFeedback`, which must prove Lean/proof outcomes become route features without hidden truth, verifier bypass, or AnswerPacket omission.
