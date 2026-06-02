---
falsifier: F-UAS-ACS-MmapResidency
created_on: 2026-05-28
artifact: artifacts/falsifiers/uas_acs_mmap_residency/result.json
command: Tools/falsifiers/f_uas_acs_mmap_residency.sh
status: primary_witness
scope: file-backed UAS / AcsAnchor residency slice
---

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

# F-UAS-ACS-MmapResidency

> **Namespace note:** the falsifier ID and artifact path are preserved for
> continuity. Current prose reads this as **UAS/AcsAnchor mmap residency**.
> It does not mean Active Cold Storage, and it is not an admission gate.

## Purpose

This falsifier proves one concrete piece of the no-compromise UAS / AcsAnchor
ambition on the M2 Pro floor: a cold file-backed byte region is mapped with
`mmap`, addressed as a `UasKind::KvPage`, linked to a `UasKind::ModelComponent`,
leased through `ResidencyLease`, and resolved through AcsAnchor projection lookup
without tracked hot-path copies.

It is deliberately not a 70B model benchmark. It does not prove MLX token
generation, KV residual patching, NF4 SSD spill, live sparse runtime, or a
frontier-model replacement route. Those remain gated by `F-KV-Direct-Gate`,
`F-Agent-Local-Model-Runtime-Bridge`, and `F-70B-Local-Cocktail-Lite`.

## Current Result

| Field | Value |
|---|---|
| Overall pass | `true` |
| Artifact kind | `primary_witness` |
| Fallback tier | `Primary` |
| Fixture | `uas_acs_mmap_residency_16mb_v1` |
| Backing size | `16 MiB` |
| Artifact | `artifacts/falsifiers/uas_acs_mmap_residency/result.json` |

## Required Axes

| Axis | Meaning |
|---|---|
| `mmap_backed_bytes` | The mapped byte length is at least the deterministic backing-file length. |
| `file_len_matches_mmap` | The file length and mapped length agree. |
| `uas_address_round_trip` | The KV-page UAS address parses back to the same address. |
| `acs_projection_lookup` | Legacy axis name; AcsAnchor projection lookup returns the anchored object without field loss. |
| `residency_lease_round_trip` | The residency lease names the same address and remains valid inside the test window. |
| `sampled_page_checksum_match` | Sampled mmap pages match the deterministic page oracle. |
| `invalid_offset_rejection` | Out-of-range access is rejected instead of silently aliasing. |
| `hot_path_tracked_copies` | The sampled read path records zero copy-counter events. |
| `hot_path_data_copy_bytes` | The sampled read path records zero data-copy bytes. |

## Non-Drift Rule

This witness upgrades UAS / AcsAnchor from metadata-only evidence to a real
file-backed mmap residency proof. It still stops below the live model boundary.
Agents may cite it as:

```text
UAS/AcsAnchor mmap residency works for a deterministic file-backed KV-page slice.
```

Agents may not cite it as:

```text
70B local inference works.
KV-Direct 128K works.
SSD and RAM are transparently one zero-cost model memory pool.
MLX generation is zero-copy through mmap.
```

The next honest promotion path is to attach this residency proof to
`F-KV-Direct-Gate` spill traces and then to `F-70B-Local-Cocktail-Lite` prompt
metrics.
