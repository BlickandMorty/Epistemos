---
state: passed
created_on: 2026-06-04
falsifier_id: F-ShadowWakeOracle
artifact: artifacts/falsifiers/shadow_wake_oracle/result.json
scope: metadata-only architecture witness
---

# F-ShadowWakeOracle

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

- Result: PASS as a metadata-only primary witness on 2026-06-04.
- Script: `Tools/falsifiers/f_shadow_wake_oracle.sh`
- Artifact: `artifacts/falsifiers/shadow_wake_oracle/result.json`
- L1 next cursor: `F-AblationShadowRun`
- L2 product route: unchanged, `vault_research_route_with_packetized_mitigation`; next bottleneck `ablation_shadow_run`
- L3 user-facing/runtime route: unchanged; no shadow oracle, PatternBoost, lattice, Eidos, proof, test, citation, SCOPE-Rex, or SovereignGate path becomes hidden live route authority.

## What It Proves

The witness proves a metadata-only `ShadowWakeOracle` fixture where full-wake traces, proof/test results, unit-credit assignments, byte/latency deltas, oracle labels, route labels, scout features, proof refs, test refs, citation refs, SCOPE-Rex refs, SovereignGate refs, rollback handles, RunEventLogs, AnswerPacket refs, compatibility fences, privacy classes, and held-out splits are bound before oracle traces can train route labels.

The fixture includes 2 oracle fixtures and 6 oracle records across 6 source kinds and 6 route labels. It keeps 2 train cases and 4 held-out cases, held-out success is `9080` bps, label agreement is `9180` bps, calibration error is `710` bps, trace tokens stay within budget, metadata stays below budget, and cheap-route, full-wake-everything, and no-oracle-label baselines are beaten. The deterministic address is `uas:shadow-wake-oracle:sha256:77d162a7e6a455b5a614713dc68a7d815d6e09fbb868021b6b56d683ea89794c`. Runtime/model bytes loaded remain zero.

## Hardening

The falsifier rejects empty fixtures; duplicate fixture or oracle IDs; missing fixture ID, oracle record, oracle ID, mission, upstream DepthLeaseCheckpoint ref, upstream RouteDistillationTournament ref, cheap route trace, full wake trace, proof/test result, credit assignment, byte/latency delta, oracle label, route label, scout feature, proof ref, test ref, citation ref, SCOPE-Rex ref, SovereignGate ref, rollback, RunEventLog, AnswerPacket, or split; invalid split; missing held-out split; incompatible fence; invalid privacy; hidden live dependency; hidden truth authority; verifier/test/citation/SCOPE-Rex/SovereignGate bypass; base-weight, route-policy, or cache mutation; hidden route authority; hidden-chain exposure; cloud source; runtime-byte load; model-byte load; unbeaten baselines; low label agreement; high calibration error; missing source or route-label diversity; trace-token overflow; and metadata-budget overflow.

## Scope

This advances L1 only. It does not make the oracle a live router, does not let oracle labels override SCOPE-Rex or SovereignGate, does not expose hidden chain-of-thought, does not mutate route policy, cache, or base model weights, does not load local model bytes, does not promote the 70B track to product runtime, and does not change MAS/Pro user copy. The next architecture unit is `F-AblationShadowRun`, which must prove claimed useful units survive counterfactual remove-one-unit comparison before any route-importance claim can promote.
