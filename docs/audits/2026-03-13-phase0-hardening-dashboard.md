# Phase 0 Hardening Dashboard

Date: March 13, 2026
Checkpoint tag: `checkpoint/phase0-baseline-prepass-2026-03-13`
Plan: `docs/plans/2026-03-13-deep-hardening-cycle-plan.md`

## Purpose

This file is the baseline ledger for the hardening cycle. It tracks the command
matrix, the signposted spans now present in the app, and the measurements that
must be captured before deeper refactors land.

## Command Matrix

- Swift build:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
- Swift tests:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test`
- Rust tests:
  `cd graph-engine && cargo test`
- Rust graph benchmark matrix:
  `cargo test benchmark_graph_phase1_matrix --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml -- --nocapture`
- Rust race regression:
  `cd graph-engine && cargo test hardened_race_tests -- --nocapture`

Thread Sanitizer:
- pending dedicated scheme

## Signpost Coverage

### App

- `bootstrapInit`
- `migrateBodiesToFileStorage`

### Graph

- `ensureOverlay`
- `loadGraph`
- `loadGraphAsync`
- `refreshStructuralData`
- `refreshStructuralDataAsync`
- `revealPage`
- `buildStructuralGraph`
- `commitGraphData`
- `recomputeDepthColors`

### Vault

- `restoreVaultFromBookmark`
- `startWatching`
- `initialVaultImport`
- `initialVaultDiffSync`
- `rebuildIndex`
- `syncFromVault`
- `saveAllDirtyPages`

### Notes

- `pageSwap`

## Baseline Capture Table

| Flow | Command / Tool | Status | Notes |
|---|---|---|---|
| app cold launch | Instruments + signposts | pending | capture `bootstrapInit` |
| body migration | launch with migration enabled | pending | capture `migrateBodiesToFileStorage` |
| graph cold-open | graph overlay open flow | pending | capture `ensureOverlay`, `loadGraphAsync`, `commitGraphData` |
| graph structural rebuild | graph refresh flow | pending | capture `refreshStructuralDataAsync`, `buildStructuralGraph` |
| vault restore from bookmark | launch with attached vault | pending | capture `restoreVaultFromBookmark`, `startWatching`, `initialVaultImport` |
| vault sync from external edits | `syncFromVault()` path | pending | capture `syncFromVault` |
| vault export of dirty pages | save all / autosave path | pending | capture `saveAllDirtyPages` |
| note page swap | notes workspace navigation | pending | capture `pageSwap` |
| search index rebuild | Settings rebuild action | pending | capture `rebuildIndex` |

## Current Phase 0 Deliverables

- checkpoint tag created before implementation work
- baseline command matrix recorded
- missing signposts added to boot, vault, graph-load, and note page-swap paths

## Not In Scope For Phase 0

- parser replacement
- storage-engine migration
- graph engine data-structure rewrite
- environment injection redesign
- renderer architecture changes
