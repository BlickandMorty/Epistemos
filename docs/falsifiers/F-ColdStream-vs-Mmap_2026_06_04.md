---
state: passed-metadata-witness
created_on: 2026-06-04
falsifier_id: F-ColdStream-vs-Mmap
artifact: artifacts/falsifiers/coldstream_vs_mmap/result.json
scope: metadata-only benchmark-plan witness; no live mmap/pread/ColdStream benchmark
---

# F-ColdStream-vs-Mmap - 2026-06-04

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Result

`Tools/falsifiers/f_coldstream_vs_mmap.sh` emits and validates
`artifacts/falsifiers/coldstream_vs_mmap/result.json` as a metadata-only
primary witness.

L1 advanced at landing. The architecture cursor moved from `coldstream_vs_mmap`
to `slab_arena_copy_count`; downstream `F-SlabArena-CopyCount` now passes
metadata-only, so the regenerated current cursor is `metal_io_feature_gate`.

L2 did not advance to product-green. The capability kernel remains
`overall_pass=false`, route status
`vault_research_route_with_packetized_mitigation`, and current next bottleneck
`metal_io_feature_gate`.

L3 did not change. No UI/runtime path, live ColdStream transport, live mmap or
pread benchmark, live Metal I/O, live SSD stress, KV-Direct 128K route, live
sparse 70B route, or product-facing route capability is promoted.

## What Passed

The witness proves a same-fixture benchmark-plan table exists before any live
transport claim can promote:

- 3 fixtures and 9 baseline rows bind `mmap_fault`, `naive_pread`, and
  `coldstream_plan` rows on identical fixture IDs.
- Every fixture binds `benchmark_plan`, `AnswerPacket`, `RunEventLog`,
  rollback, admission, SCOPE-Rex, SovereignGate, compatibility fence,
  cancellation group, and visible fallback refs.
- The synthetic ColdStream plan rows beat mmap-fault and naive pread rows on
  p95/p99 stall and read amplification inside the metadata table:
  min mmap stall win `5384` bps, min pread stall win `4285` bps, min mmap read
  amplification win `3777` bps, min pread read amplification win `2000` bps.
- Official-source refs are bound for Apple `mmap`, Apple `fcntl`/cache
  controls, Apple Dispatch I/O, and Apple Metal resource loading.
- ProductBuild is Pro and ProStatus is `ResearchCandidate`; route authority is
  `benchmark_plan_only`.
- Runtime bytes loaded and model bytes loaded are both zero.

## What Rejected

The primitive and falsifier reject empty fixtures, empty surfaces, duplicate
fixtures, duplicate surfaces, duplicate AnswerPackets, duplicate baseline rows,
missing mmap/pread/ColdStream rows, missing benchmark-plan refs, missing
AnswerPacket or RunEventLog proof, missing rollback/admission/SCOPE-Rex/
SovereignGate/fence/cancellation/fallback refs, missing official source refs,
missing required visible markers, forbidden visible claims, missing L1/L2/L3
separation, invisible summaries, p99 below p95, zero bytes, invalid read
amplification, copy-budget overflow, missing cancellation, unbeaten mmap or
pread baselines, fixture ID mismatch, hidden route authority, route-policy
mutation, SCOPE-Rex/SovereignGate bypass, AnswerPacket suppression, hidden
chain, hidden cloud, SSD-as-RAM copy, MAS or Live promotion, live benchmark
attempts, runtime/model bytes, unbeaten baselines, and metadata overflow.

## Scope Caveat

This is not a runtime performance result. It proves the comparison contract and
invalid fixtures before later platform-gated benchmarks. `F-SlabArena-CopyCount`,
`F-MetalIO-FeatureGate`, live cache-pollution/cancellation/fallback checks, and
any real mmap/pread/ColdStream measurements remain separate gates.
