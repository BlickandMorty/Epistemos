---
state: passed
created_on: 2026-06-04
falsifier_id: F-DepthLease-Checkpoint
artifact: artifacts/falsifiers/depth_lease_checkpoint/result.json
scope: metadata-only architecture witness
---

# F-DepthLease-Checkpoint

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

- Result: PASS as a metadata-only primary witness on 2026-06-04.
- Script: `Tools/falsifiers/f_depth_lease_checkpoint.sh`
- Artifact: `artifacts/falsifiers/depth_lease_checkpoint/result.json`
- L1 next cursor at landing: `F-ShadowWakeOracle`; current L1 cursor after `F-ShadowWakeOracle` is `F-AblationShadowRun`.
- L2 product route: unchanged, `vault_research_route_with_packetized_mitigation`; current next bottleneck `small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe` after downstream `F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditZeroFailProbe`
- L3 user-facing/runtime route: unchanged; no adaptive-depth live route authority, hidden full-depth fallback, cache mutation, route-policy mutation, base-weight mutation, model-byte load, 70B runtime claim, autogenous-kernel mutation, or UI claim is promoted.

## What It Proves

The witness proves a metadata-only `DepthLeaseCheckpoint` fixture where adaptive-depth decisions must expose shallow exit, deeper wake, verifier margin, maximum extra layers, full-depth fallback, checkpoint reference, ComputeResumeLease token, rollback, RunEventLog, AnswerPacket fields, mutation-safety fence, compatibility fence, privacy class, and held-out split before dynamic-depth policy can cite savings.

The fixture includes 2 depth-checkpoint fixtures, 6 checkpoints, 4 held-out checkpoints, 6 shallow exits, 6 deeper wakes, 6 full-depth fallbacks, 6 resume tokens, 6 rollback handles, 6 RunEventLogs, and 6 AnswerPackets. Minimum verifier margin is `1690` bps, max extra layers is `10`, max depth delta is `8`, max latency is `178` ms under a `240` ms ceiling, lease success is `9248` bps, AnswerPacket coverage is `10000` bps, and silent-promotion rejection is `10000` bps. The deterministic address is `uas:depth-lease-checkpoint:sha256:0ad452207decf973d1c3106b8ca2ec8d5c163847fecb70ac55797f9c491b0671`. Runtime/model bytes loaded remain zero.

## Hardening

The falsifier rejects empty fixtures; duplicate fixture or checkpoint IDs; missing fixture ID, depth checkpoint policy, checkpoint record, mission, upstream LayerKVJointLease ref, upstream FastWeightQuarantine ref, route card, depth policy, shallow exit, deeper wake, full-depth declaration, checkpoint ref, resume token, verifier margin, full-depth fallback, rollback, RunEventLog, AnswerPacket, AnswerPacket fields, mutation-safety fence, or held-out split; invalid depth ordering, extra-layer budget overflow, verifier-margin underflow, latency overflow, disabled fallback, incompatible fence, invalid privacy class, invalid split, silent depth promotion, live route authority, base-weight mutation, route-policy mutation, cache mutation, hidden-chain exposure, cloud source, runtime-byte load, model-byte load, metadata over budget, and unbeaten shallow-only/hidden-depth/no-checkpoint/no-fallback baselines.

## Scope

This advances L1 only. It does not make adaptive depth a live router, does not hide full-depth fallback, does not mutate cache, route policy, or base model weights, does not allow hidden PatternBoost/lattice/Eidos authority, does not load local model bytes, does not promote the 70B track to product runtime, and does not change MAS/Pro user copy. `F-ShadowWakeOracle` now passes as a metadata-only successor witness; the current architecture unit is `F-AblationShadowRun`, which must prove claimed useful units survive counterfactual remove-one-unit comparison before route-importance claims can promote.
