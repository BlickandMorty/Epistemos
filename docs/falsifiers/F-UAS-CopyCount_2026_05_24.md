---
falsifier: F-UAS-CopyCount
created_on: 2026-05-24
hardware_floor: M2 Pro 16 GB UMA
status: PASS - SCHEMA NORMALIZED 2026-05-28
artifact: artifacts/falsifiers/uas_copy_count/result.json
---

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

# F-UAS-CopyCount

## Result

PASS on one measured run. The artifact is now in the shared
`FalsifierArtifact` schema shape and validates with `falsifier_validator`.

Command:

```bash
Tools/falsifiers/f_uas_copy_count.sh
```

Measured artifact:

- `tensor_copy_count`: 0
- `data_copy_bytes`: 0
- hot-path labels: Swift shared buffer, Rust slice view, Metal shared buffer,
  MLX KV view, HNSW vector view
- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`

## Scope Note

This harness measures the T14 UAS copy counter over the shared-backing hot-path
fixture. It does not claim the full MLX production generation loop is copy-free;
that remains covered by the broader F-UAS-ZeroCopy-Spine path.

## Acceptance

The falsifier passes iff the measured hot path records zero tensor/data copies
after the shared backing is created. Metadata and JSON artifact serialization
happen after the measured region and are recorded separately in the artifact.
