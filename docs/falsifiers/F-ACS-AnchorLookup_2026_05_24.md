---
falsifier: F-ACS-AnchorLookup
created_on: 2026-05-24
hardware_floor: M2 Pro 16 GB UMA
status: PASS - SCHEMA NORMALIZED 2026-05-28
artifact: artifacts/falsifiers/acs_anchor_lookup/result.json
---

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

# F-ACS-AnchorLookup

## Result

PASS on one measured run over 10,000 claims. The artifact is now in the shared
`FalsifierArtifact` schema shape and validates with `falsifier_validator`.

Command:

```bash
Tools/falsifiers/f_acs_anchor_lookup.sh
```

Measured artifact:

- `claim_count`: 10000
- `found_count`: 10000
- `avg_lookup_ns`: latest generated artifact currently reports 443 ns
- threshold: `< 1000 ns`
- invalid theorem id rejection: true
- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`

## Scope Note

The harness measures the MAS-safe `agent_core::uas::AcsAnchorRegistry` lookup
path. It validates that ACS (Anchored Cognitive Substrate) anchors retain
theorem, plane, residency, source, packet, compatibility, and salience fields,
and that invalid theorem ids fail closed.

## Acceptance

The falsifier passes iff all 10,000 claim anchors resolve, average lookup
latency is below 1 microsecond, projection fields survive lookup, and an
invalid theorem id is rejected.
