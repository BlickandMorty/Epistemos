# B-Prime UAS/AcsAnchor Artifact Gates - 2026-05-26

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

Status: recovered as a focused Settings health-row slice from `stash@{0}`.

Source: `stash@{0}` (`b-prime-uncommitted-followup-2026-05-26`) and draft
preservation PR #82.

Recovery rule: no stash was popped, dropped, checked out, or bulk-applied. The
stash was inspected as a donor patch; only the durable UAS/AcsAnchor gate behavior was
ported onto current `main`.

## What Was Recovered

- `UasAcsHealthRow` now reads the measured `F-UAS-CopyCount` artifact at
  `artifacts/falsifiers/uas_copy_count/result.json`.
- `UasAcsHealthRow` now reads the measured `F-ACS-AnchorLookup` artifact at
  `artifacts/falsifiers/acs_anchor_lookup/result.json`.
- The row renders those gates as detail rows and can open the artifact or
  fallback falsifier doc.
- The production adapter remains explicitly non-green until the MAS runtime
  actually routes through `anchor_registry.rs`.

## What Was Not Recovered Raw

The wider `stash@{0}` settings diff also contains broad surface and ambient
settings work. That remains queued as separate recovery slices. This slice does
not bulk-restore the stale draft branch, because that branch predates newer
HTML Workspace, Runtime Router, Landing Wave, and recovery-ledger work on
`main`.

## Verification Target

- `EpistemosTests/SubstrateHealthPanelTests.swift`
- `Epistemos/Views/Settings/UasAcsHealthRow.swift`
