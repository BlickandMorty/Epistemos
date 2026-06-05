---
state: passed-metadata-witness
created_on: 2026-06-05
falsifier_id: F-CodecStage-Latency
artifact: artifacts/falsifiers/codec_stage_latency/result.json
script: Tools/falsifiers/f_codec_stage_latency.sh
scope: metadata-only codec latency witness; no live codec benchmark, transport bytes, model bytes, or product promotion
---

# F-CodecStage-Latency

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Result

`Tools/falsifiers/f_codec_stage_latency.sh` emits and validates
`artifacts/falsifiers/codec_stage_latency/result.json` as a metadata-only
ColdStream codec witness.

L1 architecture cursor advanced from `codec_stage_latency` to
`transport_cancellation`.

L2 did not advance to product-green. The capability kernel remains
`overall_pass=false`, route status `vault_research_route_with_packetized_mitigation`,
with next bottleneck `transport_cancellation`.

L3 did not change. No live codec benchmark, live ColdStream transport, live
Metal I/O, KV-Direct 128K route, sparse 70B route, provider route, or
user-facing product runtime was promoted.

## What Passed

The witness proves decode/conversion work is not hidden inside file-read timing:

- `3` codec stages, `2` visible surfaces, `3` AnswerPacket refs, and `3`
  RunEventLog refs are bound.
- File-read traces (`read_trace:*`) and codec latency traces
  (`codec_latency:*`) are separate for every stage.
- Each stage binds codec name, input page run, CPU/Metal kernel ref, output
  CPU slab or MetalBufferLease ref, checksum-after-decode, rollback,
  SCOPE-Rex/SovereignGate admission, compatibility fence, cancellation group,
  and visible caveat.
- Max codec-stage latency is `12 ms`; max observed and expected copy count are
  both `1`; runtime/model/transport bytes loaded are all `0`.
- Deterministic address:
  `uas:codec-stage-latency:sha256:e0b55d880875986ce203b5f5eb3887c214a217814b1dd5fef05ab3cdccb9c4f8`.

## Hardening

Invalid fixtures reject empty stages/surfaces, duplicates, duplicate
AnswerPackets, missing codec/input/read trace/codec latency trace/kernel/output
slab/checksum/proof refs, zero input or decoded bytes, missing decode or
conversion latency, mixed read/decode timing, copy count overrun, over-budget
copy expectations, missing visible caveats, missing L1/L2/L3 separation,
forbidden hidden/live/cloud/SSD-as-RAM markers, hidden route authority, route
mutation, gate bypass, AnswerPacket suppression, hidden chain/cloud,
MAS/Live promotion, live benchmark attempts, runtime/model/transport bytes,
unbeaten baselines, and metadata overflow.

## Scope

This is not a live codec-performance result and not a transport replacement
claim. It is the L1 proof that codec work has its own witness channel before
ColdStream can be considered for live hot-path promotion.
