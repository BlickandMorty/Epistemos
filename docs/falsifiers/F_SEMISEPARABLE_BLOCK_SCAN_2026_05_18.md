---
falsifier: F-SemiseparableBlockScan
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: PARTIAL SUBSTRATE, NOT FULLY PASSED
---

# F-SemiseparableBlockScan

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove the V6.2 state-plane Mamba-2 SSD block scan matches the canonical semiseparable reference before any long-context state-kernel claim ships. |
| Current status | PARTIAL SUBSTRATE, NOT FULLY PASSED. `agent_core/src/helios/ssd_block_scan.rs` provides the scalar CPU reference, and `Epistemos/Shaders/SemiseparableBlockScan.metal` contains a correctness-first Metal substrate floor marked not yet wired. No 100-seed M2 Pro falsifier artifact or T23B script exists. |
| Input fixture | PyTorch `ssd_minimal.py` Listing 1 oracle, Rust scalar oracle, Metal `ssdScanScalar`, 100 random seeds, fp16 inputs, empty/length-mismatch cases, stable/unstable `a[t]` sequences, `chunk_size=256`, `ngroups=1`, Core `L=32,768`, and Stretch `L=131,072` recorded separately. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: Core lane max-abs-diff <= 1e-3 fp16 over 100 random seeds versus the PyTorch oracle, final state included in the diff, `chunk_size=256` and `ngroups=1` are enforced, and Stretch results are labeled non-Core unless independently measured. |
| Failure meaning | The state-plane kernel is numerically untrusted; Mamba-2/SSD long-context and LocalRecallIsland downstream claims cannot cite semiseparable acceleration. |
| Fallback route | Keep the Rust scalar reference and ordinary model path authoritative; do not promote Metal SSD acceleration or 128K stretch until the 32K Core artifact passes. |
| Product lane | MAS-safe Tier-1/Core only after 32K M2 Pro proof; 128K Stretch remains Research until measured. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_semiseparable_block_scan.sh` |
| Expected artifact | `artifacts/falsifiers/semiseparable_block_scan/result.json` with seed-wise max-diff, final-state diff, chunk/ngroups metadata, Core-vs-Stretch labels, and oracle commit/source reference. |

## Canon Anchors

- MASTER_FUSION: [§3 claim 15 typed buffers/shared memory](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock), because the state-kernel witness must stay numeric, typed, and replayable.
- Unified Active Substrate Canon: [§2 row 6 V6.2 falsifier order](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#2-the-6-canonical-surfaces), where SemiseparableBlockScan is target-only until M2 Pro correctness evidence exists.

## Failure Criterion

This falsifier fails if Core `L=32,768` max-abs-diff exceeds 1e-3 fp16, if final-state diff is omitted, if `chunk_size=256` or `ngroups=1` is not enforced, if Stretch results are presented as Core proof, or if no M2 Pro 16 GB UMA artifact exists.

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `core_max_abs_diff`, `final_state_diff`, `chunk_size`, `ngroups`, and `stretch_labeling`.
