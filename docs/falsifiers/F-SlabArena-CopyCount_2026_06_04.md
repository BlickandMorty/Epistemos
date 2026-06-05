# F-SlabArena-CopyCount - 2026-06-04

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as a metadata-only L1 architecture witness.

- Command: `Tools/falsifiers/f_slab_arena_copy_count.sh`
- Artifact: `artifacts/falsifiers/slab_arena_copy_count/result.json`
- Falsifier ID: `F-SlabArena-CopyCount`
- Scope: ColdStream CPU slab preallocation/copy-count evidence only
- L1 cursor advanced to: `metal_io_feature_gate`
- L2 product route: still `vault_research_route_with_packetized_mitigation`
- L3 user-facing route: unchanged; no product runtime promotion

## What This Proves

`F-SlabArena-CopyCount` proves the CPU slab side of ColdStream can be described as preallocated, leased, visibly copied, and allocation-stable before any Metal I/O or live transport claim promotes.

The witness binds 2 slab plans, 4 leases, 6 copy events, 4 allocation samples, 2 visible surfaces, rollback handles, RunEventLog refs, AnswerPacket refs, SCOPE-Rex/SovereignGate admission refs, compatibility fences, cancellation groups, purge policies, and fallback refs. The max copy count is 1, per-token allocation delta is 0, runtime bytes loaded are 0, and model bytes loaded are 0.

## What This Does Not Prove

This does not prove live ColdStream transport, live mmap replacement, live pread/Dispatch I/O/Metal timings, Metal I/O availability, cache-pollution behavior, SSD stress safety, MLX runtime throughput, local 70B runtime, or any user-facing product capability. Architecture cursor advanced; product capability and user surface did not.

## Hardening

The Rust primitive and falsifier reject empty plans, duplicate plans, duplicate leases, duplicate copy events, duplicate allocation samples, duplicate surfaces, duplicate AnswerPacket refs, zero capacity, bad alignment, lease overflows, overlapping leases, unknown lease refs, copy-count overruns, copied-byte overruns, allocation during copy events, per-token allocation spikes, missing lease tables, missing purge policy, missing rollback, missing RunEventLog, missing AnswerPacket, missing admission, missing compatibility fence, missing cancellation, missing fallback, hidden route authority, route mutation, gate bypass, AnswerPacket suppression, hidden chain/cloud, SSD-as-RAM claims, live benchmarks, runtime/model bytes, MAS/Live product promotion, unbeaten baselines, metadata overflow, and nondeterministic address formation.

## Next Link

Downstream Metal I/O feature-gate, codec-stage latency, transport cancellation,
cache-policy, cold-panic fallback, ProductRouteReview, small-model harness
safety-plan, dry-run, owner-approved, and abortable-runtime witnesses now pass
metadata-only. The regenerated guard reports
`next_existing_work=small_model_runtime_harness_product_answer_packet_live_probe` after downstream `F-SmallModelRuntimeHarnessProductWrvProbe`; L2
remains `vault_research_route_with_packetized_mitigation`, and L3
user-facing/product runtime is unchanged.
