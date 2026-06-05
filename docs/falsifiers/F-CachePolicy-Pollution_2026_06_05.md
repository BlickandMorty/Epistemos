---
state: passed-metadata-witness
created_on: 2026-06-05
falsifier_id: F-CachePolicy-Pollution
artifact: artifacts/falsifiers/cache_policy_pollution/result.json
script: Tools/falsifiers/f_cache_policy_pollution.sh
scope: metadata-only cache policy pollution witness; no live transport benchmark, model bytes, runtime bytes, or product promotion
---

# F-CachePolicy-Pollution

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Result

`Tools/falsifiers/f_cache_policy_pollution.sh` emits and validates
`artifacts/falsifiers/cache_policy_pollution/result.json` as a metadata-only
ColdStream cache-policy witness.

L1 architecture cursor advanced from `cache_policy_pollution` to
`cold_panic_fallback`.

L2 did not advance to product-green. The capability kernel remains
`overall_pass=false`, route status `vault_research_route_with_packetized_mitigation`,
with next bottleneck `cold_panic_fallback`.

L3 did not change. No live ColdStream transport, live mmap replacement, live
pread/Dispatch I/O/Metal I/O, KV-Direct 128K route, sparse 70B route, provider
route, or user-facing product runtime was promoted.

## What Passed

The witness proves cache policy cannot silently pollute repeated hot routes:

- `3` policy trials and `2` visible surfaces are bound.
- The three policy lanes are present: streaming no-cache, hot reuse, and
  metadata-only.
- Every trial binds cache policy, hot-route, repeated-probe, transport trace,
  transport-cancellation, rollback, RunEventLog, AnswerPacket,
  SCOPE-Rex/SovereignGate admission, and compatibility-fence refs.
- Minimum repeated probes are `5`; minimum reuse horizon is `30000` ms.
- Max hot-route regression is `120` bps and max cache pollution is `430` bps.
- Cache policy success is `9520` bps, beating the no-explicit-policy,
  always-cache, hidden-policy, and live-authority baselines.
- Runtime/model/transport bytes loaded are all `0`.
- Deterministic address:
  `uas:cache-policy-pollution:sha256:5dab5398979530c7453e09f9c0712db36d6a0f6ca212d906ac983be33bf32f3b`.

## Hardening

Invalid fixtures reject empty trials/surfaces, duplicate trials/surfaces,
duplicate AnswerPackets, missing cache policy, missing hot route, missing
repeated probe, missing transport trace or cancellation evidence, missing
rollback, missing RunEventLog, missing AnswerPacket, missing admission,
missing compatibility fence, missing visible caveats, zero cold bytes, zero
probe counts, p99 below p95, policy-lane mismatch, non-explicit policy
decisions, hot-route regression overflow, cache-pollution overflow, read
amplification overflow, missing reuse horizon, missing L1/L2/L3 separation,
hidden route authority, route-policy mutation, gate bypass, AnswerPacket
suppression, hidden chain/cloud, SSD-as-RAM claims, MAS/Live promotion, live
benchmark attempts, runtime/model/transport bytes, unbeaten baselines, and
metadata overflow.

## Scope

This is not a live cache benchmark and not a ColdStream promotion. It is the L1
proof that every future transport cache decision has a visible policy lane,
repeated hot-route regression budget, rollback path, RunEventLog, AnswerPacket,
and product-status caveat before live hot-path work can proceed.
