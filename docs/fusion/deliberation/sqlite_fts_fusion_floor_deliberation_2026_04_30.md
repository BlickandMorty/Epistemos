# SQLite FTS Fusion Floor Deliberation - 2026-04-30

## Gate

Approved for a narrow test-floor repair only.

## Evidence

- Full Swift test floor `/tmp/epistemos-full-test-after-cargo-mirror-20260430.log` fails the RRF/SearchIndex fusion cluster because this test host's SQLite build reports `no such module: fts5`.
- Production `SearchIndexService` already probes FTS5 availability and logs `fts5_pages=false fts5_blocks=false` in this environment.
- `SearchIndexServiceFusionTests.seedDoc` still inserts `content` and `position` into `readable_blocks`, but the canonical schema now stores `body` and no `position`.
- `RRFFusionQueryTests.kRRFConstantParityWithRustSource` still reads the repo checkout directly instead of the test source mirror, which breaks the source-guard rule repaired in the previous gate.

## Decision

Do not change production search behavior for this slice. The direct RRF fusion suites are FTS5-specific by design, so they should run where FTS5 is available and be explicitly disabled where the linked SQLite lacks FTS5. Keep the Rust parity test active because it does not depend on SQLite.

## Approved Edits

- Add a small GRDB-backed FTS5 probe helper in the test target.
- Add `.enabled(if:)` guards to FTS-dependent fusion suites/tests.
- Update the SearchIndex fixture to use `ReadableBlocksIndex.insert` and canonical `ArtifactKind`.
- Update the Rust RRF constant parity test to read `epistemos-shadow/src/backend/rrf.rs` from the bundled source mirror.

## Forbidden Edits

- No changes to production RRF SQL.
- No changes to `SearchIndexService` FTS fallback semantics.
- No edits to protected note editor, graph rendering, hologram, or graph-engine internals.
- No staging, committing, or branch operations.

## Verification

- Focused Swift Testing run:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/RRFFusionQueryTests -only-testing:EpistemosTests/SearchIndexServiceFusionTests test`
- Protected path diff audit after edits.
- If focused passes/skips as expected, rerun the full Swift test floor.
