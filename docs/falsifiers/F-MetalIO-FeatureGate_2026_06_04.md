---
state: passed-metadata-only
created_on: 2026-06-04
falsifier_id: F-MetalIO-FeatureGate
artifact: artifacts/falsifiers/metal_io_feature_gate/result.json
script: Tools/falsifiers/f_metal_io_feature_gate.sh
scope: L1 architecture cursor only; no live Metal I/O transport or product runtime promotion
---

# F-MetalIO-FeatureGate

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Result

PASS as a metadata-only primary witness on 2026-06-04.

`Tools/falsifiers/f_metal_io_feature_gate.sh` emits and validates
`artifacts/falsifiers/metal_io_feature_gate/result.json`. The artifact proves
three feature decisions: one supported Metal feature may name a
`MetalBufferLease`, one unsupported feature must use CPU slab fallback, and one
unknown feature must also use CPU slab fallback. Every decision binds rollback,
RunEventLog, AnswerPacket, SCOPE-Rex/SovereignGate admission, compatibility
fence, cancellation group, fallback slab, and visible caveat.

## L1 / L2 / L3

- L1 architecture cursor advanced from `metal_io_feature_gate` to
  `codec_stage_latency`.
- L2 product route remains
  `vault_research_route_with_packetized_mitigation`; next bottleneck is
  `transport_cancellation`.
- L3 user-facing/product runtime is unchanged.

## Hardening

Rejected fixtures cover empty/duplicate decisions and surfaces, duplicate
AnswerPackets, missing device/GPU-family/feature-query/requested-feature refs,
missing MetalBufferLease on supported Metal, unexpected MetalBufferLease on CPU
fallback, missing CPU slab fallback, missing proof refs, unsupported/unknown
feature selecting Metal, supported feature selecting fallback, hidden route
authority, route-policy mutation, gate bypass, AnswerPacket suppression, hidden
chain/cloud, SSD-as-RAM claims, MAS/Live promotion, live benchmark attempts,
runtime/model/Metal bytes, unbeaten baselines, and metadata overflow.

## Non-Promotion

This witness does not prove live Metal I/O performance, live ColdStream
transport, live mmap replacement, cache policy, codec latency, SSD stress
safety, KV-Direct 128K, live sparse 70B, dense 70B residency, or product runtime
capability. It only proves the platform feature-gate and CPU fallback contract
is addressable, visible, rollback-bound, and schema-validated.
