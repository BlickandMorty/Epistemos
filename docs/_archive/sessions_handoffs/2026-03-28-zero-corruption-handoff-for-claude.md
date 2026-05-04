# Zero-Corruption Handoff For Claude

> **Index status**: SUPERSEDED-HISTORICAL — Older plan tree predecessor of `docs/plan/`; superseded by MASTER_FUSION.md + V1_5_IMPLEMENTATION_TRACKER.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



## Current Status

This repo is materially safer than it was at the start of the zero-corruption push, but it is still **not fully compliant** with the master spec.

The work completed so far is real and tested in focused slices. The biggest remaining gaps are still architectural: Merkle/root verification, document-hash storage in a primary database path, bundled SQLite/fullfsync strategy, and application WAL/replay.

## What Is Already Fixed

### 0. Hosted macOS test bootstrapping is stable again

Files:
- `build-epistemos-core.sh`
- `project.yml`
- `Epistemos.xcodeproj/project.pbxproj`
- `EpistemosTests/RuntimeValidationTests.swift`
- `EpistemosTests/ThemePairTests.swift`

What changed:
- the app no longer relies on `PackageFrameworks/libepistemos_core.dylib` at runtime
- the app no longer carries a `$(PROJECT_DIR)/build-rust` runtime search path
- the build script now removes stale `PackageFrameworks/libepistemos_core.dylib` copies before launchable bundles are assembled
- the signed `Contents/Frameworks/libepistemos_core.dylib` copy is now the only intended runtime load target
- source guards were updated so the build graph keeps enforcing the bundle-local runpath setup

Impact:
- the prior hosted `xcodebuild test` bootstrap crash (`EXC_BAD_ACCESS` / code-signature-invalid against `libepistemos_core.dylib`) is no longer the active story for this branch
- full hosted macOS test passes are completing again

### 1. Note body storage is hardened

Files:
- `Epistemos/Sync/NoteFileStorage.swift`
- `Epistemos/Sync/VaultIndexActor.swift`
- `EpistemosTests/NoteFileStorageTests.swift`

What changed:
- note bodies now write through an atomic temp-file + rename + parent-directory `F_FULLFSYNC` path
- reads verify integrity before returning bytes
- corrupted note bodies are quarantined under `.quarantine/`
- integrity sidecars use `.integrity`
- legacy `.blake3` sidecars are still accepted
- note files also get a secondary `com.epistemos.content_hash` xattr
- missing sidecars can be backfilled during verified reads

### 2. Rust durability / FFI surface was hardened

Files:
- `epistemos-core/src/uniffi_exports.rs`
- `epistemos-core/Cargo.toml`
- `graph-engine/Cargo.toml`
- `omega-mcp/Cargo.toml`
- `omega-ax/Cargo.toml`
- `omega-mcp/src/uniffi_exports.rs`
- `omega-mcp/src/state.rs`

What changed:
- raw `libc::fsync` fallback was removed from the exported full-sync path
- recall-index access no longer uses `lock().unwrap()` on the exported path
- release profiles use `panic = "abort"`
- `omega-mcp` startup DB path was hardened with WAL + `synchronous=FULL` + integrity check

### 3. SQLite stores are now opened in a safer configuration

Files:
- `Epistemos/State/EventStore.swift`
- `Epistemos/Sync/SearchIndexService.swift`
- `EpistemosTests/WorkspaceSnapshotTests.swift`
- `EpistemosTests/SearchIndexServiceIntegrationTests.swift`

What changed:
- both stores now enforce:
  - `PRAGMA journal_mode = WAL`
  - `PRAGMA synchronous = FULL`
  - `PRAGMA wal_autocheckpoint = 1000`
  - `PRAGMA foreign_keys = ON`
  - `PRAGMA integrity_check`
- both stores now explicitly verify that WAL mode actually stuck instead of assuming the pragma succeeded
- live `.sqlite`, `-wal`, and `-shm` files are excluded from Time Machine
- database directories get `.metadata_never_index`

### 4. Mutable `@unchecked Sendable` usage was removed from the production code touched in this effort

Files include:
- `Epistemos/State/EventStore.swift`
- `Epistemos/Graph/GraphBuilder.swift`
- `Epistemos/Graph/GraphState.swift`
- `Epistemos/Engine/LLMService.swift`
- `Epistemos/KnowledgeFusion/MoLoRA/MoLoRAInferenceService.swift`
- `Epistemos/Models/BrandedTypes.swift`
- `Epistemos/Omega/Distribution/AppStoreHelper.swift`
- `Epistemos/Views/Notes/NoteImageProcessor.swift`
- `Epistemos/Sync/SearchIndexService.swift`
- `Epistemos/State/ActivityTracker.swift`
- `Epistemos/State/CognitiveSubstrateTypes.swift`

Status:
- repo sweep for real `@unchecked Sendable` usage in the production/test-helper surfaces touched by this push is clean
- remaining hits are source-validation assertion strings in tests

### 5. Startup integrity now blocks automatic restore on verified local corruption

Files:
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/RootView.swift`
- `EpistemosTests/WorkspaceSnapshotTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`

What changed:
- startup integrity samples managed note bodies and verifies them through `NoteFileStorage`
- corrupted sampled note bodies are quarantined and block automatic vault restore
- the report is cached and surfaced through `StartupIntegrityReport`
- the initial implementation ran from `RootView` before later being moved into the dedicated launch gate

### 6. Startup integrity now also validates the saved vault bookmark before automatic restore

Files:
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Sync/VaultSyncService.swift`
- `EpistemosTests/WorkspaceSnapshotTests.swift`
- `EpistemosTests/VaultSyncServiceAuditTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`

What changed:
- startup integrity now includes bookmark readiness
- stale / unreadable / unresolvable bookmark states block automatic restore
- `VaultSyncService` now has a shared bookmark-resolution helper so startup validation and restore don’t drift

### 7. Recovery snapshots no longer hot-copy live SQLite files

Files:
- `Epistemos/Sync/VaultSyncService.swift`
- `EpistemosTests/VaultSyncServiceAuditTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`

What changed:
- destructive recovery snapshots now:
  - copy safe Application Support contents
  - skip live SQLite side files
  - create consistent `event-store.sqlite` and `search.sqlite` backups with `sqlite3_backup`
- retention pruning now keeps only the 20 most recent recovery snapshots
- pruning runs both after snapshot creation and on launch restore

### 8. Idle maintenance now checkpoints the search index WAL

Files:
- `Epistemos/Sync/SearchIndexService.swift`
- `Epistemos/State/NightBrainService.swift`
- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/SearchIndexServiceIntegrationTests.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`

What changed:
- `SearchIndexService` now has a `passiveCheckpoint()` maintenance hook backed by GRDB's WAL checkpoint API
- `NightBrainService` now includes a `search_index_passive_checkpoint` idle-maintenance job
- `AppBootstrap` wires Night Brain to the live search index service so passive checkpoints happen through the existing idle scheduler
- focused tests cover the checkpoint hook and the updated idle-maintenance job list

### 9. Text sanitization now fails explicitly instead of using an empty-string sentinel

Files:
- `epistemos-core/src/uniffi_exports.rs`
- `epistemos-core/uniffi/epistemos_core.udl`
- `Epistemos/Sync/NoteFileStorage.swift`
- `EpistemosTests/RuntimeValidationTests.swift`

What changed:
- `sanitize_and_normalize` now returns `Result<String, TextNormalizationError>` instead of collapsing rejection into `""`
- the Rust layer now rejects:
  - null bytes
  - replacement characters
  - mid-string BOMs
- `NoteFileStorage` now calls the generated throwing Swift wrapper instead of the old manual checksum-based low-level sanitize bridge
- source guards now verify that the exported sanitize path stays throwing and that `NoteFileStorage` keeps using the generated wrapper

### 10. Generated UniFFI Swift bindings are patched for Swift 6 default MainActor isolation

Files:
- `patch-uniffi-bindings.py`
- `Epistemos.xcodeproj/project.pbxproj`
- `Epistemos/KnowledgeFusion/DataIngestion/VaultParser.swift`
- `EpistemosTests/RuntimeValidationTests.swift`

What changed:
- the generated binding patcher now normalizes Swift declarations so UniFFI output can compile under this repo's Swift 6 `MainActor` default isolation
- the patcher now explicitly handles:
  - `LocalizedError.errorDescription`
  - file/type/helper/function/init declarations that need `nonisolated`
  - top-level mutable globals that need `nonisolated(unsafe)`
  - the generated object-pointer field
- generated binding source entries in the Xcode project now also carry a per-file `-default-isolation=nonisolated` compiler flag as a belt-and-suspenders safeguard
- `VaultParser` no longer bounces `classifyDocument` / `filterBoilerplate` through `MainActor.run`; those helpers are now called directly
- source guards now verify the patcher and the direct `VaultParser` call path

### 11. Startup integrity now gates the real app UI before `RootView` is mounted

Files:
- `Epistemos/App/EpistemosApp.swift`
- `Epistemos/App/RootView.swift`
- `EpistemosTests/RuntimeValidationTests.swift`

What changed:
- `EpistemosApp` now wraps the main app content in `LaunchIntegrityGateView`
- the gate runs `performStartupIntegrityCheck()` before `RootView` is mounted
- automatic vault restore now happens from the gate instead of `RootView.onAppear`
- setup-sheet presentation and the existing `RootView` startup work now wait until the integrity gate finishes

### 12. APFS safety snapshots are now requested through `tmutil`

Files:
- `Epistemos/Sync/VaultSyncService.swift`
- `EpistemosTests/VaultSyncServiceAuditTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`

What changed:
- `snapshotLocalState()` now attempts a `tmutil localsnapshot` before destructive local-state recovery work
- app-created APFS snapshots are tracked in `apfs-snapshot-manifest.json` under the recovery root
- launch-time pruning now also prunes tracked APFS snapshots with `tmutil deletelocalsnapshots`
- helper coverage exists for snapshot-id parsing, manifest persistence, and 20-snapshot retention

Important caveat:
- APFS safety snapshots are currently best-effort; failure logs do not abort the app-level recovery snapshot path

## Verification Evidence

### Build evidence

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build` passed during the hardening work
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build-for-testing` passed after the bookmark-validation + recovery-snapshot changes
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build-for-testing` also passed after the WAL-verification + search-checkpoint maintenance changes
- `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build-for-testing` passed again after the sanitize-contract + generated-binding isolation fixes
- `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build-for-testing` passed again after the pre-UI launch gate + APFS safety-snapshot pass
- `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-release-fix1 build-for-testing` passed after the dylib/runpath fix
- `git diff --check` is clean

### Rust evidence

- `cd epistemos-core && cargo test` passed in the latest sanitize-contract pass: `120 passed, 0 failed`
- `cd graph-engine && cargo test` passed: `2441 passed, 0 failed, 8 ignored`
- `cd omega-mcp && cargo test` passed: `89 passed, 0 failed`
- `cd omega-ax && cargo test` passed: `12 passed, 0 failed`

### Focused macOS test evidence

These `test-without-building` passes succeeded after the latest changes:

- startup bookmark validation:
  - `VaultSyncServiceAuditTests/startupBookmarkValidationRejectsStaleBookmarks`
  - `VaultSyncServiceAuditTests/startupBookmarkValidationAcceptsReadableResolvedBookmarks`
- startup integrity report:
  - `WorkspaceSnapshotTests/startupIntegrityReportBlocksAutomaticVaultRestoreAfterBookmarkValidationFailures`
  - `RuntimeValidationTests/startupIntegrityCheckRunsBeforeAutomaticVaultRestore`
- recovery snapshot hardening:
  - `VaultSyncServiceAuditTests/destructiveStopSnapshotsSQLiteStateViaConsistentBackups`
  - `VaultSyncServiceAuditTests/recoverySnapshotPruningKeepsOnlyTwentyMostRecentSnapshots`
  - `RuntimeValidationTests/vaultRecoverySnapshotsUseSQLiteBackupsAndPruneOldSnapshots`
- latest SQLite maintenance slice:
  - `SearchIndexServiceIntegrationTests/databaseUsesDurablePragmasAndBackupExclusion`
  - `SearchIndexServiceIntegrationTests/passiveCheckpointKeepsIndexedContentReadable`
  - `EventStoreTests/eventStoreUsesDurablePragmasAndProtectsLiveFiles`
  - `NightBrainCheckpointResumeTests/resumeSkipsCheckpointedJobs`
  - `RuntimeValidationTests/remainingProductionConcurrencyWrappersNarrowUnsafeStateInsteadOfUncheckedSendable`
  - `RuntimeValidationTests/nightBrainCheckpointsSearchIndexDuringIdleMaintenance`

### Full hosted macOS verification evidence

Three consecutive full hosted Swift passes completed with no code changes between them:

- `/tmp/epistemos-release-pass5.xcresult`
  - result: `Passed`
  - total tests: `2665`
  - failed tests: `0`
- `/tmp/epistemos-release-pass6.xcresult`
  - result: `Passed`
  - total tests: `2665`
  - failed tests: `0`
- `/tmp/epistemos-release-pass7.xcresult`
  - result: `Passed`
  - total tests: `2665`
  - failed tests: `0`

Those passes happened only after fixing the host-bootstrap dylib/runpath issue and the follow-on regressions exposed by the first full run:

- `VaultSyncService` recovery snapshots now tolerate stale non-SQLite files by falling back to a plain file copy when the source is not a real SQLite database
- `PipelineService` now preserves emitted visible text in `DualMessage.rawAnalysis` instead of completing with an empty analysis payload
- runtime validation expectations now match the real UniFFI patcher regexes used by the build
- startup sampling expectations were aligned with the app's deterministic lexicographic sampler

## Important Caveat About Release Readiness

The hosted Swift automation story is much healthier now than it was during the earlier bootstrap-crash window. However, that does **not** mean the full zero-corruption spec is complete or that a direct-release ship call is fully closed from the terminal alone.

What is now true:

- hosted Swift tests are passing again
- the repo has three consecutive full green hosted passes after the latest code changes
- the recent hardening changes are backed by both focused tests and full-suite verification

What is **not** yet true:

- the master zero-corruption spec is fully implemented
- fresh interactive runtime verification has been re-run in this exact end state
- sanitizer / fuzz / property-test closure has been achieved for the full edge-case matrix

## Highest-Priority Remaining Spec Gaps

### 1. No Merkle manifest / root verification yet

Still missing:
- per-vault Merkle tree over document hashes
- persisted root hash
- root verification on launch / sync completion / migration
- subtree localization on mismatch

### 2. Dual-location hash storage is still incomplete at the architecture level

Current state:
- note-body files have sidecar + xattr coverage

Still missing:
- primary hash storage in a required database column like `content_hash BLOB NOT NULL`
- app-wide document read path that verifies against a primary DB hash before state admission
- consistent document-hash ownership model across all persisted user documents

### 3. SQLite fullfsync strategy is still unresolved

Still missing:
- explicit final decision and implementation for:
  - bundled SQLite with `SQLITE_HAVE_FULLFSYNC=1`
  - or documented acceptance of system SQLite barrier semantics with compensating controls

### 4. No application-level WAL / replay layer yet

Still missing:
- append-only operation log
- per-entry checksum
- durable WAL flush ordering
- replay on restart

### 5. No CRDT / CloudKit zero-loss sync architecture yet

Still missing:
- deterministic conflict handling
- local-first sync WAL
- iCloud-drive-bypass safety model from the spec

### 6. Edge-case matrix is still far from complete

Still missing:
- sanitizer runs
- fuzz targets
- property tests
- many explicit failure-mode tests from the master checklist

## Suggested Next Implementation Order

1. Add a real document-hash primary store and a single verified document read/write actor path.
2. Build the Merkle manifest/root layer and hook it into startup integrity.
3. Decide and implement the SQLite fullfsync strategy.
4. Add the application-level WAL + replay path.
5. Expand failure-mode tests from the edge-case matrix.

## Suggested First Files To Reopen

- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/RootView.swift`
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Sync/NoteFileStorage.swift`
- `Epistemos/State/EventStore.swift`
- `Epistemos/Sync/SearchIndexService.swift`
- `EpistemosTests/WorkspaceSnapshotTests.swift`
- `EpistemosTests/VaultSyncServiceAuditTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`

## Honest Bottom Line

This branch now contains meaningful zero-corruption hardening, not paper compliance:

- verified note-body quarantine + integrity enforcement
- safer SQLite openings
- startup restore blocking on verified corruption
- startup restore blocking on invalid/stale bookmarks
- consistent SQLite recovery snapshots instead of hot-copied live files

But the repo is still **not** at the full master-spec target of provable `< 1 in 10^9` undetected corruption per operation.
