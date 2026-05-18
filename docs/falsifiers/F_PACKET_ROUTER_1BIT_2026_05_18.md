---
falsifier: F-PacketRouter1bit
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: NOT IMPLEMENTED
---

# F-PacketRouter1bit

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove the V6.2 assembly-plane 1-bit packet router can split and reassemble a 100k-element batch fast enough for sparse-active dispatch. |
| Current status | NOT IMPLEMENTED as a hardware gate. `agent_core/src/helios/packet_router.rs` provides the CPU reference and semantic tests; `docs/ACCEPTANCE_PROOFS_V6_1_2026_05_16.md` classifies the five Helios kernels as scaffolding only, with hardware validation still separate. No M2 Pro timing artifact or T23B script exists. |
| Input fixture | 100,000 `f32` payloads with balanced, 95/5 skewed, degenerate all-zero, degenerate all-one, alternating, and random bit masks; include round-trip reconstruction and lane-balance telemetry. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: P99 dispatch latency < 100 us, reconstruction is byte-identical to input order, and degenerate/skewed masks are reported rather than hidden. |
| Failure meaning | Sparse-active assembly routing is not physically cheap enough, or the router silently loses ordering; active-packet, controller-pack, and local-recall claims cannot inherit the 1-bit dispatch path. |
| Fallback route | Keep `packet_router` as CPU reference/scaffolding only; use ordinary contiguous batching or static routing until the M2 Pro P99 artifact exists. |
| Product lane | Vault/Research now; V2 assembly-plane feature-gated after hardware proof. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_packet_router_1bit.sh` |
| Expected artifact | `artifacts/falsifiers/packet_router_1bit/result.json` with p50/p95/p99, mask-class breakdown, reconstruction digest, and lane-balance report. |

## Canon Anchors

- MASTER_FUSION: [§3 claim 15 typed buffers/shared memory](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock), because packet routing must preserve numeric buffers without JSON hot-path payloads.
- Unified Active Substrate Canon: [§2 row 6 V6.2 falsifier order](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#2-the-6-canonical-surfaces), where PacketRouter1bit is one of the target-only V6.2 hardware gates.

## Failure Criterion

This falsifier fails if P99 dispatch latency is at least 100 us on the 100,000-element fixture, if reconstruction is not byte-identical in original order, if degenerate/skewed masks are not separately reported, or if the M2 Pro artifact is absent.

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `p99_latency_us`, `reconstruction_digest`, `mask_class_breakdown`, and `lane_balance_report`.
