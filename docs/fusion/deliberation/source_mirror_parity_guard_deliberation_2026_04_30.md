# Source Mirror Parity Guard Deliberation - 2026-04-30

## Evidence

- Full Swift floor after the stale-guard slice paused at `ArtifactKindParityTests.rustEnumCoversCanonicalVariants`.
- Sample `/tmp/epistemos-full-after-stale-sample.txt` shows `ArtifactKindParityTests.loadText(_:)` blocked in `_fcntl_overlay_open` / `open` while reading a repo source path.
- The same runtime-read wedge was already reproduced and fixed in `PGOAndArenasTests` by switching to the existing `SourceMirrorTestSupport` bundle helper.

## Decision

Approved for a narrow test-harness repair only:

- Convert `EpistemosTests/ArtifactKindParityTests.swift` from direct repo source reads to `loadMirroredSourceTextFile` / `sourceMirrorURL`.
- Apply the same conversion to adjacent cross-language parity guards that use the same direct repo-read pattern:
  - `EpistemosTests/ArtifactProvenanceParityTests.swift`
  - `EpistemosTests/MutationEnvelopeParityTests.swift`
- Preserve all ArtifactKind parity assertions and canonical variant expectations.
- Do not edit production code, Rust code, project files, protected editor/graph files, staging, commits, or branch state.

## Verification

- Focused `ArtifactKindParityTests` must pass.
- Protected-path diff audit must stay empty.
- Full Swift floor must be rerun afterward.
