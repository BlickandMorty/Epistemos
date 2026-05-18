---
falsifier: F-ControllerKernelPack
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: PARTIAL SUBSTRATE, NOT FULLY PASSED
---

# F-ControllerKernelPack

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove the V6.2 controller-plane packed micro-kernel file matches the reference semantics for all controller primitives before it is trusted as a fused dispatch surface. |
| Current status | PARTIAL SUBSTRATE, NOT FULLY PASSED. `agent_core/src/helios/controller_pack.rs` provides the Rust CPU reference, and `Epistemos/Shaders/ControllerKernelPack.metal` contains six Metal kernels, but the shader header says it is not yet wired by a Swift dispatcher. No M2 Pro artifact harness or T23B script exists. |
| Input fixture | Reference fixtures for scalar add, scalar multiply, max, argmax, copy, and zero-fill over empty, single-element, 1,024-element, NaN-containing, tie-breaking, and length-mismatch inputs. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: all six kernels are reference-equivalent to the Rust/Swift oracle under fp32 tolerance, threadgroup memory stays within the V6.2 controller budget, and any unsupported empty/reduction behavior is explicit in the artifact. |
| Failure meaning | Controller-plane utility work would be faster in design only; mismatched reductions or hidden empty-input behavior could corrupt admission, routing, norm, or safety controller state. |
| Fallback route | Keep the Rust CPU controller reference authoritative; call plain CPU helpers or unfused Metal kernels until the packed shader is wired and artifact-proven. |
| Product lane | MAS-safe Tier-1 candidate after M2 Pro reference-equivalence artifact. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_controller_kernel_pack.sh` |
| Expected artifact | `artifacts/falsifiers/controller_kernel_pack/result.json` with per-kernel fixture results, fp32 max-diff table, unsupported-case ledger, and shader pipeline metadata. |

## Canon Anchors

- MASTER_FUSION: [§3 claim 15 typed buffers/shared memory](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock), because controller kernels must stay as typed numeric surfaces with replayable reference semantics.
- Unified Active Substrate Canon: [§2 row 6 V6.2 falsifier order](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#2-the-6-canonical-surfaces), where ControllerKernelPack is a V6.2 target-only kernel until M2 Pro evidence exists.

## Failure Criterion

This falsifier fails if any of the six kernels differs from the Rust/Swift oracle outside fp32 tolerance, if empty or reduction behavior is hidden, if threadgroup memory exceeds the V6.2 controller budget, or if no M2 Pro 16 GB UMA artifact exists.

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `per_kernel_equivalence`, `fp32_max_diff`, `threadgroup_budget`, and `unsupported_case_ledger`.
