---
state: passed
created_on: 2026-06-04
falsifier_id: F-FastWeightQuarantine
artifact: artifacts/falsifiers/fast_weight_quarantine/result.json
scope: metadata-only architecture witness
---

# F-FastWeightQuarantine

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

- Result: PASS as a metadata-only primary witness on 2026-06-04.
- Script: `Tools/falsifiers/f_fast_weight_quarantine.sh`
- Artifact: `artifacts/falsifiers/fast_weight_quarantine/result.json`
- L1 next cursor: `F-DepthLease-Checkpoint`
- L2 product route: unchanged, `vault_research_route_with_packetized_mitigation`; next bottleneck `depth_lease_checkpoint`
- L3 user-facing/runtime route: unchanged; no fast-weight live route authority, base-weight mutation, route-policy mutation, hidden PatternBoost/lattice/Eidos authority, model-byte load, 70B runtime claim, autogenous-kernel mutation, or UI claim is promoted.

## What It Proves

The witness proves a metadata-only `FastWeightQuarantine` fixture where verifier-regret fast-weight deltas are admitted into a quarantine ledger only as shadow evidence. Each quarantine record binds an upstream VerifierRegretFastWeights update, source update ref, delta ref, session/document/project scope, base policy digest, quarantine policy ref, quarantine state, admission gate, drift gate, held-out replay ref, rollback handle, TTL, reset handle, RunEventLog, AnswerPacket, replay trace, release decision, write barrier, mutation-safety fence, compatibility fence, privacy class, and explicit live-control rejection.

The fixture includes 2 quarantine fixtures, 6 quarantine records, 3 scopes, 3 quarantine states, 3 release decisions, 4 held-out replays, 6 blocked live-control attempts, 6 reset handles, and 6 rollback handles. Held-out replay success is `10000` bps, shadow replay success is `9500` bps, AnswerPacket coverage is `10000` bps, live-control rejection is `10000` bps, max observed drift is `620` bps under an `850` bps bound, TTLs range from `12000` to `90000` ms, and unquarantined/live-promotion/stale/no-AnswerPacket baselines are all beaten. The deterministic address is `uas:fast-weight-quarantine:sha256:8338507976a3ce76968681efc79e65068436bb3b13255decabe72c42f549eb95`. Runtime/model bytes loaded remain zero.

## Hardening

The falsifier rejects empty fixtures; duplicate fixture or quarantine IDs; missing fixture ID, upstream fast-weight ref, quarantine policy, quarantine record, source update ref, delta ref, scope, base policy digest, quarantine state, admission gate, drift gate, held-out replay, rollback, TTL, reset handle, RunEventLog, AnswerPacket, replay trace, release decision, write barrier, mutation-safety fence, or held-out split; invalid scope, quarantine state, release decision, split, compatibility fence, or privacy class; held-out replay failure; expired TTL; drift overflow; live-control authority; unblocked live-control attempts; consolidation promotion; base-weight mutation; route-policy mutation; hidden route authority; hidden-chain exposure; cloud source; runtime-byte load; model-byte load; unbeaten unquarantined/live-promotion/stale/no-AnswerPacket baselines; and metadata-budget overflow.

## Scope

This advances L1 only. It does not make quarantined fast weights a live router, does not consolidate policy, does not mutate base model weights or route policy, does not allow hidden PatternBoost/lattice/Eidos route authority, does not load local model bytes, does not promote the 70B track to product runtime, and does not change MAS/Pro user copy. The next architecture unit is `F-DepthLease-Checkpoint`, which must prove adaptive depth checkpoints before dynamic-depth or runtime promotion can claim live authority.
