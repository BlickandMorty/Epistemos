# Verification Blocker Repair Deliberation - 2026-04-30

## Verdict

Approved: **minimal repair slice only**.

This is not approval for broad feature work, raw worktree merge, protected editor/graph edits, staging, or committing.

## Why This Slice

The build/test floor found one dominant mechanical blocker: Swift tests that depend on `NoteFileStorage` fail while the bridge logs a UniFFI contract mismatch. The generated `epistemos_core` Swift binding now expects contract version `29`, while the hand-written `NoteFileStorage` bridge still checks `26`.

Two additional failures are clear source-guard drifts:

- `ArtifactKind` preserves numeric IDs but accidentally uses numeric `Codable` wire output where provenance tests require lower-snake-case strings.
- release profile tests reject stale `lto = "thin"` text and test-only `catch_unwind` scanning.

## Approved Edits

Allowed files:

- `Epistemos/Sync/NoteFileStorage.swift`
- `Epistemos/Models/ArtifactKind.swift`
- `agent_core/Cargo.toml`
- `EpistemosTests/CargoReleaseProfileTests.swift`

Allowed changes:

- update the hand-written `epistemos_core` UniFFI contract check from `26` to the generated binding contract version `29`
- implement custom `ArtifactKind` `Codable` that encodes `snakeCaseString` and decodes both string names and legacy numeric IDs
- remove/replace the `lto = "thin"` PGO override text in `agent_core/Cargo.toml`
- update the catch-unwind source audit so test-only code does not force release crates into `panic = "unwind"`

## Forbidden

- no edits to `Epistemos/Views/Notes/ProseEditor*.swift`
- no edits to `Epistemos/Views/Graph/MetalGraphView.swift`
- no edits to `Epistemos/Views/Graph/HologramController.swift`
- no raw worktree merges
- no staging
- no commits
- no destructive cleanup of test artifacts, DerivedData, vault data, or user files
- no broad refactors around vault sync, search, model routing, landing UI, or Kimi docs

## Required Verification

Run focused tests after the slice:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/NoteFileStorageTests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ArtifactProvenanceParityTests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CargoReleaseProfileTests
```

If the focused tests pass, rerun the full Swift test floor before approving any implementation beyond this slice.

## Stop Triggers

- contract mismatch persists after the constant update
- `ArtifactKind` string encoding breaks legacy numeric decoding
- focused tests introduce new protected-path diffs
- working-tree dirty counts jump unexpectedly outside the approved files
