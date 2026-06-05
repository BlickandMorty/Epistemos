---
state: passed-metadata-witness
created_on: 2026-06-05
falsifier_id: F-TransportCancellation
artifact: artifacts/falsifiers/transport_cancellation/result.json
script: Tools/falsifiers/f_transport_cancellation.sh
scope: metadata-only transport cancellation witness; no live transport benchmark, model bytes, runtime bytes, or product promotion
---

# F-TransportCancellation

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Result

`Tools/falsifiers/f_transport_cancellation.sh` emits and validates
`artifacts/falsifiers/transport_cancellation/result.json` as a metadata-only
ColdStream cancellation witness.

L1 architecture cursor advanced from `transport_cancellation` to
`cache_policy_pollution`.

L2 did not advance to product-green. The capability kernel remains
`overall_pass=false`, route status `vault_research_route_with_packetized_mitigation`,
with next bottleneck `cache_policy_pollution`.

L3 did not change. No live ColdStream transport, live mmap replacement, live
pread/Dispatch I/O/Metal I/O, KV-Direct 128K route, sparse 70B route, provider
route, or user-facing product runtime was promoted.

## What Passed

The witness proves route changes cannot leave stale cold bytes in an executable
state:

- `3` cancellation runs and `2` visible surfaces are bound.
- One current route is allowed to enter execution, one obsolete in-flight read
  is cancelled before execution, and one stale slab is rejected before
  execution.
- Every run binds route epoch, page run, read trace, slab, cancellation group,
  cancellation token, route-change ref, lease ref, scheduler ref, rollback,
  RunEventLog, AnswerPacket, SCOPE-Rex/SovereignGate admission, compatibility
  fence, and visible caveat.
- Total scheduled bytes are `98304`; total cancelled bytes are `24576`;
  runtime/model/transport bytes loaded are all `0`.
- Deterministic address:
  `uas:transport-cancellation:sha256:284685cb61fb59dfe1b5c532d40665068039e711a981aff2593049ffc6a018cd`.

## Hardening

Invalid fixtures reject empty runs/surfaces, duplicates, duplicate
AnswerPackets, missing page run/read trace/slab/cancellation group/cancellation
token/route change/lease/scheduler/proof refs, zero route epochs, zero
scheduled bytes, cancelled obsolete reads entering execution, stale slabs
entering execution, missing obsolete-read or stale-slab rejection, current
routes carrying cancelled bytes, missing required run classes, missing visible
caveats, missing L1/L2/L3 separation, forbidden hidden/live/cloud/SSD-as-RAM
markers, hidden route authority, route mutation, gate bypass, AnswerPacket
suppression, hidden chain/cloud, MAS/Live promotion, live benchmark attempts,
runtime/model/transport bytes, unbeaten baselines, and metadata overflow.

## Scope

This is not a live transport-performance result and not a mmap/pread
replacement claim. It is the L1 proof that cancellation and stale-slab
rejection have their own witness channel before ColdStream can be considered
for live hot-path promotion.
