# Cargo Release Profile Source Mirror Deliberation - 2026-04-30

## Evidence

- Full Swift floor `/tmp/epistemos-full-test-after-parity-mirror-20260430.log` stopped advancing at `CargoReleaseProfileTests.every crate ships the canonical release profile fields`.
- Sample `/tmp/epistemos-full-parity-cargo-sample.txt` shows `CargoReleaseProfileTests.loadCargoToml(crate:)` blocked in Foundation file read / `_fcntl_overlay_open` at `CargoReleaseProfileTests.swift:62`.
- The same direct repo-source read wedge already appeared in `PGOAndArenasTests` and Artifact parity guards, and the existing `SourceMirrorTestSupport` path has passed focused verification.
- The current SourceMirror build phase copies `agent_core`, `graph-engine`, `epistemos-core`, and `syntax-core`, but `CargoReleaseProfileTests` also audits `omega-ax`, `omega-mcp`, `substrate-core`, `substrate-rt`, `epistemos-shadow`, and `epistemos-code-index`.

## Decision

Approved for a narrow test-harness repair only:

- Convert `EpistemosTests/CargoReleaseProfileTests.swift` from direct repo source reads to `SourceMirrorTestSupport`.
- Extend the `Bundle Test Source Mirror` build phase in `Epistemos.xcodeproj/project.pbxproj` to copy the remaining audited Rust crate roots.
- Preserve all release-profile, panic-mode, and `catch_unwind` assertions.
- Do not edit production Swift, Rust source, protected editor/graph files, staging, commits, or branch state.

## Verification

- Focused `CargoReleaseProfileTests` must pass.
- Protected-path diff audit must stay empty.
- Full Swift floor must be rerun afterward.
