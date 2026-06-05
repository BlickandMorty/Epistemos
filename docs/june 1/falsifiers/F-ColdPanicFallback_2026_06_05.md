---
state: landed
falsifier_id: F-ColdPanicFallback
artifact: artifacts/falsifiers/cold_panic_fallback/result.json
script: Tools/falsifiers/f_cold_panic_fallback.sh
landed_on: 2026-06-05
scope: metadata-only
---

# F-ColdPanicFallback

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

`Tools/falsifiers/f_cold_panic_fallback.sh` emits and validates
`artifacts/falsifiers/cold_panic_fallback/result.json` as a metadata-only
ColdStream panic-fallback primary witness.

L1 architecture cursor advanced from `cold_panic_fallback` to
`ready_for_product_route_review`.

L2 did not promote. The capability kernel remains `overall_pass=false`, route
status `vault_research_route_with_packetized_mitigation`, with next bottleneck
`ready_for_product_route_review`.

L3 did not promote. No user-facing runtime, live ColdStream transport, live
mmap replacement, live pread/Dispatch I/O/Metal I/O benchmark, live sparse 70B,
dense 70B, or KV-Direct 128K route changed.

## What Passed

- 3 missed-deadline fallback runs and 2 visible surfaces.
- 3 fallback routes: hot degraded route, cached summary, and background repair queue.
- Max token block: `2` ms under the `16` ms metadata budget.
- Max fallback latency: `24` ms under the `64` ms metadata budget.
- Cold panic success: `9610` bps, beating wait-forever, hidden-caveat, stale-slab, and live-authority baselines.
- Rollback, RunEventLog, AnswerPacket, SCOPE-Rex/SovereignGate admission, compatibility fence, cancellation, cache policy, and transport trace refs are bound.
- Runtime bytes loaded: `0`; model bytes loaded: `0`; transport runtime bytes loaded: `0`.

## Hardening

The primitive and witness reject empty runs/surfaces, duplicate runs/surfaces,
duplicate AnswerPackets, missing missed-run/deadline/trace/cache/cancellation/
fallback/rollback/log/packet/admission/fence evidence, missing caveats, missing
L1/L2/L3 separation, zero deadlines, non-missed deadlines, zero cold bytes,
token-block overflow, fallback-latency overflow, un-aborted cold wakes, stale
slab execution, invisible fallback, missing background repair, hidden route
authority, route mutation, gate bypass, AnswerPacket suppression, hidden
chain/cloud, SSD-as-RAM claims, MAS/Live promotion, live benchmark attempts,
runtime/model/transport bytes, unbeaten baselines, and metadata overflow.

## Scope Warning

This is L1 architecture evidence only. It proves missed ColdStream deadlines
must degrade visibly instead of silently blocking token-time execution. It does
not prove live transport performance or product runtime readiness.
