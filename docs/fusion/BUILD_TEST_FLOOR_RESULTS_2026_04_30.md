# Build/Test Floor Results - 2026-04-30

## 2026-05-01 Addendum - R16 ETL Worker Execution PR3H

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/r16_etl_worker_execution_pr3h_deliberation_2026_05_01.md`

Change:

- Added a Rust ETL validation worker that only reports success after re-reading
  the queued file, checking it is still a regular file, matching the queued
  byte length, matching the queued input kind, and recomputing the same
  path-plus-content fingerprint used at enqueue time.
- Added the bounded raw C ABI `etl_run_worker_json(queue_path, max_jobs)` with
  JSON counts for requested, attempted, succeeded, failed, and post-run queue
  stats.
- Added Swift decoding and `RustEtlQueueWorkerClient.run(queuePath:maxJobs:)`.
- Wired the existing off-main Shadow/ETL bootstrap path to run the worker after
  ETL enqueue, only when `PowerGate.deferSnapshot()` does not request deferral.
- Missing or stale queued files are counted as worker failures and do not
  become fake `done` jobs.

Verification:

- Red Rust log:
  `/tmp/epistemos-r16-etl-worker-pr3h-red-cargo-20260501.log`.
  Expected failure: missing `etl_run_worker_json`.
- Red Swift log:
  `/tmp/epistemos-r16-etl-worker-pr3h-red-xcode-20260501.log`.
  Expected failure: missing `RustEtlQueueWorkerClient`.
- Red summary:
  `/tmp/epistemos-r16-etl-worker-pr3h-red-summary-20260501.log`.
- Green Rust FFI worker log:
  `/tmp/epistemos-r16-etl-worker-pr3h-green-cargo-20260501.log`.
  Result: `2` ETL FFI worker tests passed.
- Green Rust validation log:
  `/tmp/epistemos-r16-etl-worker-pr3h-green-cargo-worker-20260501.log`.
  Result: `3` ETL validation tests passed.
- Green Rust full ETL filter log:
  `/tmp/epistemos-r16-etl-worker-pr3h-green-cargo-etl-full-20260501.log`.
  Result: `25` ETL tests passed.
- Green Swift focused log:
  `/tmp/epistemos-r16-etl-worker-pr3h-green-xcode-20260501.log`.
  Result: `12` tests in `ShadowVaultBootstrapper (Wave 8.7)` passed.
- Green summary:
  `/tmp/epistemos-r16-etl-worker-pr3h-green-summary-20260501.log`.
- Xcode reported `** TEST SUCCEEDED **` and exited `0`.

Guardrails:

- `cargo fmt --manifest-path agent_core/Cargo.toml -- --check` passed.
- `nm -gU build-rust/libagent_core.dylib` showed `_etl_run_worker_json`.
- AppBootstrap grep confirmed the worker call appears after
  `RustEtlQueueDispatchClient.enqueueVaultWalk` and after
  `PowerGate.deferSnapshot()`.
- Xcode still reports inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains existing plugin/lint debt and not a PR3H blocker.

Non-claims:

- No Rust-to-Swift callback was added.
- No AFM sidecar generation, sidecar schema, queue schema, MAS bookmark policy,
  protected editor, protected graph, generated binding, project, or entitlement
  behavior was changed.
- This validates ETL worker completion semantics; it is not a full R16 manual
  runtime ship claim.

## 2026-05-01 Addendum - GraphEvent Durable Mapping PR1

Gate status: **closed**.

Deliberation gate:
`docs/fusion/deliberation/graph_event_durable_mapping_pr1_deliberation_2026_05_01.md`

Change:

- Added `DurableGraphEvent`, `DurableGraphEventKind`, and
  `DurableGraphEventRelation` for persisted mutation-derived graph provenance.
  The model avoids the existing 64-byte FFI `GraphEvent` ring-event type in
  `EventDrain.swift`.
- Added the EventStore `graph_events` table with unique `event_id` and indexes
  for mutation, trace, entity, and kind queries.
- Added EventStore `saveGraphEvent(_:)`, `loadGraphEvent(eventID:)`, and
  `graphEvents(mutationID:limit:)` APIs.
- Committed graph-affecting `MutationEnvelope`s now persist deterministic
  graph-event rows in the same SQLite transaction as the envelope and mutation
  projection outbox row.
- Pending graph-affecting mutation envelopes do not create graph-event rows.
- No graph renderer/controller, graph engine, OpLog worker, PipelineService,
  ChatCoordinator, Omega, hooks, protected editor, Rust, generated binding,
  project, or entitlement change was made.

Verification:

- Red log: `/tmp/epistemos-graph-event-pr1-red-20260501.log`.
  Expected failure: the tests resolved to the existing FFI `GraphEvent` type and
  proved the missing durable model/API/table surface.
- Green log: `/tmp/epistemos-graph-event-pr1-green-20260501-r1.log`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_17-49-57--0500.xcresult`.
- Result: `28` tests in `EventStore Cognitive Tables` passed.
- Xcode reported `** TEST SUCCEEDED **` and exited `0`.

Kimi:

- `/tmp/epistemos-graph-event-pr1-kimi-audit-20260501-r1.log` produced no
  output and was terminated, so PR1 closes on Codex red/green evidence and
  guardrails rather than Kimi approval.

Guardrails:

- `git diff --check` emitted no findings for the allowed files and docs.
- Forbidden-symbol grep on implementation files emitted no output.
- A broader grep over `CognitiveSubstrateTests.swift` still sees inherited
  OpLog tests already present in the dirty branch; PR1 did not edit OpLog,
  graph renderer/controller, graph engine, Omega, ChatCoordinator,
  PipelineService, generated bindings, project, entitlement, branch, stash,
  stage, or commit state.
- Xcode still reports inherited SwiftLint plugin command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains existing plugin/lint debt and not a PR1 blocker.

## 2026-05-01 Addendum - AgentEvent Tool Provenance PR1

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/agent_event_tool_provenance_pr1_deliberation_2026_05_01.md`

Change:

- Added `AgentProvenanceEvent` as the durable Swift model for AgentEvent/tool
  provenance. The model name avoids a collision with the generated UniFFI
  `AgentEvent` struct.
- Added typed actor, event-kind, status, and tool-provenance payloads using
  lower-snake-case JSON wire keys.
- Added the EventStore `agent_events` table with unique `event_id` and indexed
  `run_id`, `trace_id`, and `tool_name`.
- Added EventStore save/load/list APIs for bounded AgentEvent persistence.
- No live chat, Omega, hook, approval, tool-execution, UI, Rust, OpLog, graph,
  or generated-binding wiring was added.

Verification:

- Red log: `/tmp/epistemos-agent-event-pr1-red-20260501.log`.
  Expected failure: the first implementation shape collided with generated
  UniFFI `AgentEvent` and proved the missing durable API surface.
- Green log: `/tmp/epistemos-agent-event-pr1-green-20260501.log`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_16-12-26--0500.xcresult`.
- Result: `21` tests in `EventStore Cognitive Tables` passed.
- Xcode reported `** TEST SUCCEEDED **` and exited `0`.

Guardrails:

- `git diff --check` emitted no findings for approved tracked files and docs.
- Direct whitespace audit emitted no findings for the new
  `AgentProvenanceEvent.swift` file.
- Source grep found only existing `oplog_seq` references in `EventStore`, not
  new production chat/Omega/hook/GraphEvent/ReplayBundle wiring.
- Protected-path scan reported inherited branch drift outside this PR1 slice.
- Xcode still reports inherited SwiftLint plugin command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains existing plugin/lint debt and not a PR1 blocker.

## 2026-05-01 Addendum - EventStore OpLog Replay Snapshot PR4A

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/eventstore_oplog_replay_snapshot_pr4a_deliberation_2026_05_01.md`

Change:

- Added Swift-only `MutationOpLogReplay` for projected mutation provenance.
- Replay folds decoded `OpLogEntry` values in deterministic sequence order,
  supports `upToSeq` logical rollback cutoff views, records duplicate
  projections, and counts ignored non-projection entries.
- Added `RustOpLogFFIClient.replayMutationProjections(upToSeq:)` as a
  convenience wrapper around existing `iterateAll()`.
- No Rust ABI, EventStore schema, worker, UI, graph, editor, project, or
  entitlement change was made for PR4A.

Verification:

- Red log: `/tmp/epistemos-oplog-replay-pr4a-red-20260501.log`.
  Expected failure: missing replay API and bridge convenience method.
- Green log: `/tmp/epistemos-oplog-replay-pr4a-green-20260501.log`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_15-52-07--0500.xcresult`.
- xcresult action status: `succeeded`; tests count: `4`.
- Xcode command exited `0`.

Guardrails:

- `git diff --check` emitted no findings for PR4A files and docs.
- `git diff --no-index --check` emitted no whitespace findings for the new
  replay file and gate doc.
- Source grep found no raw OpLog ABI, projection mutators, timers,
  `DispatchQueue`, `repeatForever`, or `while true` in the replay file.
- Protected-path scan only reported older dirty `EventStore`, `agent_core`,
  `epistemos-shadow`, and `graph-engine` files outside this PR4A slice.
- Kimi advisory:
  `/tmp/epistemos-oplog-replay-pr4a-kimi-advisory-20260501.log`.

## 2026-05-01 Addendum - EventStore OpLog Visibility PR3D

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/eventstore_oplog_projection_visibility_pr3d_deliberation_2026_05_01.md`

Change:

- Added bounded EventStore diagnostics for mutation projection outbox health:
  total, projected, pending, leased, dead-lettered, and latest dead-letter row.
- Added a read-only `OpLogProjectionHealthRow` to Settings diagnostics.
- Mounted the row in `SettingsView`.
- No repair button, projection trigger, raw OpLog ABI call, timer, or polling
  loop was added.

Verification:

- Initial compile-tightening log:
  `/tmp/epistemos-oplog-visibility-pr3d-focused-20260501.log`.
- Green focused log:
  `/tmp/epistemos-oplog-visibility-pr3d-focused-2-20260501.log`.
- Result: `20` tests in `2` suites passed.
- Xcode reported `** TEST SUCCEEDED **` and exited `0`.

Guardrails:

- `git diff --check` emitted no findings for approved PR3D files and docs.
- `git diff --no-index --check` emitted no whitespace findings for the new
  Settings row and gate doc.
- Source grep found no raw OpLog ABI, projection mutator calls, timers,
  `repeatForever`, `DispatchSourceTimer`, or `while true` in the Settings
  diagnostics files.
- Protected-path scan only reported older dirty `agent_core`,
  `epistemos-shadow`, and `graph-engine` files outside this PR3D slice.
- Kimi advisory:
  `/tmp/epistemos-oplog-dead-letter-visibility-kimi-advisory-2-20260501.log`.

## 2026-05-01 Addendum - EventStore OpLog Worker PR3C

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/eventstore_oplog_projection_worker_pr3c_deliberation_2026_05_01.md`

Change:

- Added `MutationOpLogProjectionWorker` as the finite, coalesced scheduler shell
  for projecting committed `MutationEnvelope` outbox rows into the Rust OpLog.
- AppBootstrap now creates the worker when EventStore is available and schedules
  one deferred runtime-service drain outside tests.
- Projection semantics remain in `MutationOpLogProjector`; raw C ABI access
  remains confined to `RustOpLogFFIClient`.

Verification:

- Red log: `/tmp/epistemos-oplog-worker-pr3c-red-20260501.log`.
- Green worker log:
  `/tmp/epistemos-oplog-worker-pr3c-green-20260501.log`.
  Result: `16` tests in `EventStoreSchemaTests` passed.
- Boundary/source guard log:
  `/tmp/epistemos-oplog-worker-pr3c-boundary-20260501.log`.
  Result: `2` tests in `OpLogFFIBoundaryGuardTests` passed.
- Both focused Xcode runs reported `** TEST SUCCEEDED **` and exited `0`.

Guardrails:

- `git diff --check` emitted no findings for approved tracked files and docs.
- `git diff --no-index --check` emitted no whitespace findings for new PR3C
  files.
- Scheduler grep found the intended finite `Task.detached` worker and
  AppBootstrap `scheduleDrain(reason: "deferred_runtime_services")` call, with
  no timer, `DispatchSourceTimer`, `repeatForever`, or `while true` in the new
  worker.
- Protected-path dirty files in `EventStore.swift`, `agent_core`,
  `epistemos-shadow`, and `graph-engine` predate this PR3C slice and were not
  edited for PR3C.
- Xcode still reports inherited SwiftLint plugin command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains existing plugin/lint debt and not a PR3C blocker.

## Scope

Verification run from the approved build/test floor gate:

- `git status --short -uall`
- protected-path diff audit for `ProseEditor*`, `MetalGraphView`, `HologramController`
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test`
- `cargo test` in `graph-engine`
- `cargo test` in `agent_core`

## Landing Wave Stash Preservation Audit Results

Gate status: **passed preservation audit**.

Deliberation gate:
`docs/fusion/deliberation/landing_wave_stash_preservation_deliberation_2026_04_30.md`

Scope:

- Inspected `stash@{1}` (`codex-wip-parallel-during-landing-wave-session`) read-only.
- Audited current Landing Wave call sites.
- Verified focused Landing Wave helper/choreography/policy/glyph tests.
- Did not apply, pop, drop, branch-extract, checkout, or cherry-pick any stash content.
- Did not edit production Landing, graph, note editor, Rust, generated artifact, project, entitlement, branch, staging, or commit state.

Decision:

- No Landing Wave rescue from `stash@{1}` is needed right now.
- Current branch production code uses the newer inline `LiquidGreeting` search path, with `LandingWaveOverlay` as the full-surface Metal wave/scrim and `landingSearchControlsRow` for action controls.
- `LandingWaveSearchBar.swift` exists, but no current production call site mounts `LandingWaveSearchBar`.
- Non-Landing stash contents remain deferred to separate gates.

Read-only evidence:

```bash
git stash show --stat 'stash@{1}'
rg -n "LandingWaveSearchBar|LiquidGreeting|landingSearchControlsRow|LandingWaveOverlay\\(" Epistemos/Views/Landing -S
git status --short -- Epistemos/Views/Landing EpistemosTests/LandingWaveChoreographyTests.swift EpistemosTests/LandingWaveGlyphAtlasTests.swift EpistemosTests/LandingOptimizationTests.swift EpistemosTests/LandingWavePerformancePolicyTests.swift
```

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/LandingWaveChoreographyTests -only-testing:EpistemosTests/LandingWavePerformancePolicyTests -only-testing:EpistemosTests/LandingWaveGlyphAtlasTests -only-testing:EpistemosTests/LandingOptimizationTests test
```

- Log: `/tmp/epistemos-landing-wave-preservation-focused-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_20-34-15--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `18` tests passed
  - `4` suites passed

Post-slice guardrails:

- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.
- Kimi was not invoked for this read-only preservation slice.
- `stash@{1}` remains intact.

## W9.8 Approval Modal Production Wire Results

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/w98_approval_modal_production_wire_deliberation_2026_04_30.md`

Change:

- Added `ChatApprovalResolution` and `@MainActor @Observable final class ChatApprovalQueue` beside the existing approval modal.
- Extended `ApprovalModalView` to carry summary/category metadata, guard double resolution, preserve `Less Interruptions`, and continue using `TimelineView` instead of `Timer.publish().autoconnect()`.
- Mounted the queue-backed approval sheet from `HomeSceneRootContent` using `.sheet(item:)` with `.interactiveDismissDisabled(true)`.
- Injected `bootstrap.chatApprovalQueue` through centralized `withAppEnvironment`.
- Replaced the production `ChatCoordinator.promptUserForToolApproval(...)` `NSAlert` path with `bootstrap.chatApprovalQueue.enqueue(...)`.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/AuditFixRegressionTests test
```

- Log: `/tmp/epistemos-w98-approval-modal-red-20260430.log`
- Exit code `65`.
- Expected failure: `agent tool approvals route through SwiftUI queue instead of NSAlert` failed with `18` source-guard issues.

Intermediate verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/AuditFixRegressionTests test
```

- Log: `/tmp/epistemos-w98-approval-modal-green-20260430.log`
- Exit code `0` from `xcodebuild`, but Swift Testing still failed the suite.
- Result: W9.8 source guard passed; older approval prompt vocabulary guard failed because the exact `Always Allow \(authorityCategory.displayName)` and `Use Less Interruptions` strings had moved out of `ChatCoordinator`.

Focused green verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/AuditFixRegressionTests test
```

- Log: `/tmp/epistemos-w98-approval-modal-green-2-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_21-15-55--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `25` tests passed
  - `1` suite passed

Post-slice guardrails:

- `git diff --check` passed for the approved W9.8 files and docs.
- Source-regression audit log: `/tmp/epistemos-w98-approval-modal-source-regression-20260430.log`
  - Size: `0` bytes.
  - No matches for `let alert = NSAlert(`, `beginSheetModal`, `runModal()`, legacy shadow global Swift bindings, or no-arg `RustShadowFFIClient()`.
- Protected-path diff audit log: `/tmp/epistemos-w98-approval-modal-protected-diff-audit-20260430.log`
  - Reports `graph-engine/src/renderer.rs` as dirty outside this W9.8 write scope.
  - This slice did not edit protected graph/editor files and did not apply/revert that protected diff.
- No stash apply, stash pop, stash drop, branch extraction, checkout, staging, commit, project edit, entitlement edit, generated `.rlib`/`.d` edit, or manual app verification was performed.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.

## Halo / Contextual Shadows Audit-Defer Results

Gate status: **passed automated/source audit; V1/backend rewiring deferred**.

Deliberation gate:
`docs/fusion/deliberation/halo_contextual_shadows_audit_defer_deliberation_2026_04_30.md`

Scope:

- Audited current Contextual Shadows and Halo wiring without editing production Halo, panel, editor, graph, or test files.
- Confirmed V0 Contextual Shadows is production-mounted in app bootstrap/app environment, notes, chat, and editor recall scheduling.
- Confirmed V0 still routes through `InstantRecallService`.
- Confirmed V1 Halo scaffold coverage exists and remains not silently mounted in production views.
- Did not perform manual app verification because the user explicitly deferred manual testing for now.

Source evidence:

```bash
rg -n "ContextualShadowsState|scheduleContextualShadowsRecall|ContextualShadowsPanel|ContextualShadowsButton|HaloController\\(|HaloEditorBridge\\(|HaloButton\\(" Epistemos/Views/Notes/NoteDetailWorkspaceView.swift Epistemos/Views/Chat/ChatInputBar.swift Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/App/AppBootstrap.swift Epistemos/App/AppEnvironment.swift Epistemos/Views/Halo Epistemos/Engine/HaloController.swift Epistemos/Engine/HaloEditorBridge.swift
```

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/HaloControllerTests -only-testing:EpistemosTests/HaloEditorBridgeTests -only-testing:EpistemosTests/HaloUITests -only-testing:EpistemosTests/ContextualShadowsStateTests test
```

- Log: `/tmp/epistemos-halo-contextual-shadows-audit-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_21-22-33--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `54` tests passed
  - `4` suites passed

Post-slice guardrails:

- V1 Halo production mounting, V0 backend switching to `ShadowSearchService`, and any `ProseEditor*` integration remain blocked behind a fresh implementation gate.
- Existing dirty files under `Epistemos/Views/Halo`, `Epistemos/Views/Recall/ContextualShadowsPanel.swift`, `EpistemosTests/HaloUITests.swift`, and `EpistemosTests/ContextualShadowsStateTests.swift` were not edited by this audit checkpoint.
- Protected-path dirty file `graph-engine/src/renderer.rs` remains outside this scope and was not edited or reverted.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.

## W10.1 Ontology Classifier Reachability Results

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/w101_ontology_classifier_reachability_deliberation_2026_04_30.md`

Change:

- Made `OntologyClassifier` reachable from `EntityExtractor.scanVault(...)` through an injectable `OntologyClassifying` protocol.
- Classified only changed notes with sidecar-eligible `filePath` values; source-code files remain ineligible and are not routed to the classifier.
- Kept model readiness, empty text, ineligible sources, and classifier errors nonfatal so graph scans still complete when AFM is unavailable or produces an error.
- Added structured `child_concept` sidecar storage and bumped `EpistemosSidecar.currentSchemaVersion` to `2`.
- Corrected `ontology_node` registry metadata from a SwiftData/node-row claim to the current graph-scan sidecar enrichment surface.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/GraphBuilderNoteDerivedEntityTests test
```

- Log: `/tmp/epistemos-w101-ontology-red-20260430.log`
- Exit code `65`.
- Expected failures:
  - `Cannot find type 'OntologyClassifying' in scope`
  - `Extra argument 'ontologyClassifier' in call`

Focused graph-scan green verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/GraphBuilderNoteDerivedEntityTests test
```

- Log: `/tmp/epistemos-w101-ontology-green-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_21-39-45--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `5` tests passed
  - `1` suite passed

Sidecar compatibility verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EpistemosSidecarTests test
```

- Log: `/tmp/epistemos-w101-sidecar-green-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_21-42-25--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `12` tests passed
  - `1` suite passed

Post-slice guardrails:

- `git diff --check` passed for the W10.1 touched files and docs.
- Source audit log: `/tmp/epistemos-w101-ontology-source-audit-20260430.log`
  - No stale node-row emission claim remains.
  - `OntologyClassifier.shared`, `OntologyClassifying`, and `child_concept` references are limited to the approved graph/sidecar/test/doc surfaces plus existing intake commentary.
- Protected-path diff audit log: `/tmp/epistemos-w101-protected-diff-audit-20260430.log`
  - Reports `graph-engine/src/renderer.rs` as dirty outside this W10.1 write scope.
  - This slice did not edit protected graph/editor files and did not apply/revert that protected diff.
- No Kimi code edits, stash apply, stash pop, stash drop, branch extraction, checkout, staging, commit, project edit, entitlement edit, generated artifact edit, or manual app verification was performed.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.

## W10.11 Brain Dump Intent Quick Capture Results

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/w1011_brain_dump_intent_quick_capture_deliberation_2026_04_30.md`

Change:

- `CaptureBrainDumpIntent` now opens the existing Quick Capture sheet when the body is empty, so the user can dictate instead of getting a silent no-op.
- Non-empty brain dumps remain in `QuarantineArchive` as raw thoughts, but now preserve the active note anchor first, active chat anchor second, and fall back to unanchored quarantine only when no active context exists.
- The intent now returns `ProvidesDialog` messages for both dictation handoff and completed raw-thought capture.
- Added source-mirror tests for the empty-body Quick Capture handoff and active-context anchoring.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests test
```

- Log: `/tmp/epistemos-w1011-brain-dump-intent-red-20260430.log`
- Result: `** TEST FAILED **`
- Expected failures:
  - `Brain Dump intent with no body opens Quick Capture for dictation`
  - `Brain Dump intent anchors raw thoughts to the active note or chat`

Focused green verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests test
```

- Log: `/tmp/epistemos-w1011-brain-dump-intent-green-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_21-53-49--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `41` tests passed
  - `1` suite passed

Post-slice guardrails:

- Tracked-source `git diff --check` passed for the W10.11 source/test files.
- Touched-file whitespace audit passed for W10.11 source/test/docs.
- Source audit log: `/tmp/epistemos-w1011-brain-dump-intent-source-audit-20260430.log`
  - Confirms `CaptureBrainDumpIntent`, `.showQuickCapture`, `activeContextAnchor`, `bootstrap.notesUI.activePageId`, `bootstrap.chatState.activeChatId`, and `anchor: Self.activeContextAnchor()` are present on the approved surfaces.
- Protected-path diff audit log: `/tmp/epistemos-w1011-protected-diff-audit-20260430.log`
  - Reports `graph-engine/src/renderer.rs` as dirty outside this W10.11 write scope.
  - This slice did not edit protected graph/editor files and did not apply/revert that protected diff.
- No Kimi code edits, stash apply, stash pop, stash drop, branch extraction, checkout, staging, commit, project edit, entitlement edit, generated artifact edit, or manual app verification was performed.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.

## W9.21 Honest Handle Swift Cutover Results

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/w921_honest_handle_swift_cutover_deliberation_2026_04_30.md`

Scope:

- Inspected `stash@{0}` (`session-stash-2026-04-27: W9.21 PR4 (X salvaged) + W9.8 wire-up partial; restart-fresh per user`) read-only.
- Implemented only the W9.21 PR4 honest-handle cutover.
- Did not apply, pop, drop, branch-extract, checkout, cherry-pick, stage, or commit the stash.
- Deferred W9.8 approval-modal wiring because the stashed donor references `ChatApprovalQueue` and `ChatApprovalResolution`, but current source defines neither type.
- Did not touch generated `syntax-core/target` artifacts, `agent_core/Cargo.lock`, `docs/CRITIQUE_LOG.md`, protected note-editor files, protected graph files, project files, entitlements, staging, branch, or commit state.

Change:

- `epistemos-shadow/src/honest_handle.rs`: added panic-safe `shadow_handle_*` exports for open, retain, release, search, insert, remove, flush, stats, and free-string.
- `Epistemos/Engine/RustShadowFFIClient.swift`: cut production Swift over to an owned shadow handle with `init(path:)` and `deinit` release.
- `Epistemos/App/AppBootstrap.swift`: constructs `RustShadowFFIClient(path: shadowRoot.path)` directly for the vault shadow root.
- `EpistemosTests/ShadowServicesTests.swift`: added source guards for the Swift handle consumer and complete Rust handle export surface.

Focused verification:

```bash
cargo test --manifest-path epistemos-shadow/Cargo.toml --lib
```

- Log: `/tmp/epistemos-w921-epistemos-shadow-lib-20260430.log`
- Exit code `0`.
- Result: `45 passed`, `0 failed`, `5 ignored`.

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ShadowHonestHandleSourceGuardTests test
```

- Red log: `/tmp/epistemos-w921-honest-handle-red-20260430.log`
- Green log: `/tmp/epistemos-w921-honest-handle-green-20260430.log`
- Green exit code `0`.
- Green result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_20-52-28--0500.xcresult`
- Green Swift Testing result:
  - `2` tests passed
  - `1` suite passed
- Result: `** TEST SUCCEEDED **`

Post-slice audits:

```bash
nm -gU build-rust/libepistemos_shadow.dylib 2>/dev/null | rg "shadow_handle_|shadow_search_json|shadow_open_at"
```

- Log: `/tmp/epistemos-w921-honest-handle-symbols-20260430.log`
- Result: all nine `shadow_handle_*` symbols exported.
- Compatibility note: `_shadow_open_at` and `_shadow_search_json` remain exported.

```bash
rg -n "@_silgen_name\\(\"shadow_search_json\"\\)|RustShadowFFIClient\\.openAt|RustShadowFFIClient\\(\\)" Epistemos/Engine/RustShadowFFIClient.swift Epistemos/App/AppBootstrap.swift
```

- Log: `/tmp/epistemos-w921-honest-handle-source-regression-20260430.log`
- Result: no matches.

Post-slice guardrails:

- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.
- Kimi was not invoked for this implementation slice.
- `stash@{0}` remains intact.

## OpLog No-Swift-Bridge Guard Results

Gate status: **passed tests-only verification**.

Deliberation gate:
`docs/fusion/deliberation/oplog_no_swift_bridge_guard_deliberation_2026_04_30.md`

Change:

- Added SourceMirror guards in `EpistemosTests/CognitiveSubstrateTests.swift`.
- The guard proves the Rust OpLog raw C ABI export set remains explicit and bounded to four symbols.
- The guard proves Swift production source under `Epistemos/` still does not call raw `oplog_*` symbols before a future bridge approval.
- No production code, Rust code, generated bindings, project files, protected graph/editor files, staging, stash, branch, or commit action was taken.

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/OpLogFFIBoundaryGuardTests test
```

- Log: `/tmp/epistemos-oplog-no-swift-bridge-guard-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_20-27-03--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `2` tests passed
  - `1` suite passed

Post-slice guardrails:

- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.
- Kimi was not invoked for this small tests-only guard. The previous Kimi advisory verdict for the OpLog boundary remains in force: no Swift bridge without a fresh ownership/runtime deliberation.

## Result

Current gate status: **passed** as of the final 2026-04-30 rerun.

The repo builds, the full Swift test floor is green, and the Rust unit floors are green. Earlier blocked snapshots are retained below because they explain the repair sequence that moved the floor from red to green.

## Evidence

### Working tree

- Before and after verification, dirty counts remained `503 M` and `793 ??`.
- Protected surfaces stayed clean:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`
- Existing dirty Rust surfaces remain high-risk donor work, not approved for broad merge:
  - `agent_core/`
  - `graph-engine/`

### Build

Command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
```

Result:

- Process exited `0`.
- Xcode reported `** BUILD SUCCEEDED **`.
- Output also reported SwiftLint command failures for `CodeEditTextView` and `CodeEditSourceEditor`; record as build-warning debt, not a compile blocker.
- Sendable warnings remain in `Epistemos/Engine/EpistemosSpeechAnalyzer.swift`.

### Swift test floor

Command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
```

Result:

- Exit code `65`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_14-28-17--0500.xcresult`
- Result metrics:
  - tests discovered: `6232`
  - failed tests: `74`
  - skipped tests: `21`
  - warnings: `8`
  - final CLI summary: `5021 tests in 563 suites failed after 209.416 seconds with 100 issues`

Largest failure clusters:

- `NoteFileStorageTests`: 25 issues
- `VaultSyncServiceAuditTests`: 17 issues
- `SearchIndexServiceFusionTests`: 9 issues
- `VaultIndexActorTests`: 8 issues
- `RRFFusionQueryTests`: 6 issues
- `CloudKnowledgeDistillationTests`: 6 issues

Observed root signals:

- `NoteFileStorageBridge` repeatedly logged `sanitize_and_normalize bridge failed: unavailable("UniFFI contract version mismatch")`.
- Generated `build-rust/swift-bindings/epistemos_core.swift` uses UniFFI contract version `29`; `Epistemos/Sync/NoteFileStorage.swift` hardcodes `26`.
- `ArtifactProvenanceParityTests.artifactRefFullFields` shows Swift `ArtifactKind` encoding as numeric `2` instead of `"document"`.
- `CargoReleaseProfileTests.everyCrateHasCanonicalReleaseProfile` rejects `agent_core/Cargo.toml` retaining `lto = "thin"` in the manual PGO profile.
- `CargoReleaseProfileTests.catchUnwindAuditMatchesSplit` flags `omega-mcp/src/arena.rs` test-only `catch_unwind` even though release code still uses `panic = "abort"`.

### Rust floors

Command:

```bash
cd graph-engine && cargo test
```

Result:

- `2522 passed`
- `0 failed`
- `8 ignored`

Command:

```bash
cd agent_core && cargo test
```

Result:

- library tests: `774 passed`, `0 failed`
- bin/e2e/doc-test set: all passed, doc-tests `2 ignored`

## Gate Decision

Do not open broad implementation.

Approved next slice is a narrow verification-blocker repair:

1. Align the `NoteFileStorage` UniFFI contract constant with generated `epistemos_core` bindings.
2. Restore string wire encoding for `ArtifactKind` while tolerating legacy numeric decode.
3. Remove the forbidden thin-LTO text from `agent_core/Cargo.toml`.
4. Make the release-profile catch-unwind scan ignore test-only `#[cfg(test)]` modules so `omega-mcp` can remain `panic = "abort"` for release.

Everything else remains deferred until focused verification proves this first slice moves the floor.

## Focused Repair Results

Repair slice status: **passed focused verification**.

Applied within the approved file set:

- `Epistemos/Sync/NoteFileStorage.swift`: aligned the hand-written `epistemos_core` contract check to generated UniFFI contract version `29`.
- `Epistemos/Models/ArtifactKind.swift`: restored lower-snake-case string encoding and kept legacy numeric decode compatibility.
- `agent_core/Cargo.toml`: removed the manual `release-pgo` `lto = "thin"` override so release-like profiles inherit the canonical release contract.
- `EpistemosTests/CargoReleaseProfileTests.swift`: excluded test-only `#[cfg(test)] mod tests` blocks from the release `catch_unwind` scan.

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/NoteFileStorageTests
```

- Exit code `0`.
- Swift Testing: `25` tests in `1` suite passed.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_14-46-24--0500.xcresult`

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ArtifactProvenanceParityTests
```

- Exit code `0`.
- Swift Testing: `12` tests in `1` suite passed.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_14-49-57--0500.xcresult`

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CargoReleaseProfileTests -parallel-testing-enabled NO
```

- Exit code `0`.
- Swift Testing: `4` tests in `1` suite passed.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_15-03-52--0500.xcresult`
- Note: the first Cargo profile run wedged in the Xcode test host while reading the first `Cargo.toml`; it was sampled, gently terminated, independently corroborated with a shell audit, and then rerun successfully with parallel testing disabled.

Cargo shell corroboration:

- Independent Ruby audit of the same Cargo profile and `catch_unwind` assertions passed:
  `PASS: Cargo release profile shell audit matches CargoReleaseProfileTests assertions.`

Post-repair guardrails:

- Protected-path diff audit remained empty for:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`
- No staging or commits were performed.

Next gate:

- Rerun the full Swift test floor before approving any broader implementation. The focused repair slice removed the four clear verification blockers, but release readiness remains blocked until the full suite is green or remaining failures are separately deliberated.

## Full Swift Rerun After Focused Repair

Gate status: **still blocked, improved**.

Command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
```

Execution note:

- Output was captured to `/tmp/epistemos-full-test-after-focused-repair-20260430.log`.
- The shell wrapper used `status=$?`, which is a read-only zsh parameter, so the wrapper itself exited `1` after `xcodebuild` completed. The Xcode log is intact and contains the authoritative result.

Result:

- Xcode result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_15-07-45--0500.xcresult`
- Swift Testing summary:
  `5021` tests in `563` suites failed after `252.065` seconds with `30` issues.
- Previous full floor was `100` issues, so the focused repair reduced the Swift floor by `70` issues.
- The original repaired blockers did not recur:
  - no `NoteFileStorageTests` UniFFI contract mismatch cluster
  - no `ArtifactProvenanceParityTests.artifactRefFullFields` numeric kind failure
  - no `CargoReleaseProfileTests` thin-LTO or test-only `catch_unwind` failure

Remaining failure clusters:

- `AgentCommandCenterStateTests`: `deepseek` still exposes `.agent` where an always-thinking brain should expose only `.thinking`.
- `GRDBPragmaTests`: runtime SQLite pragmas are below canonical expectations (`mmap_size` `268435456` vs `1073741824`, `cache_size` `-8192` vs `-65536`).
- `HarnessSubsystemTests`: bootstrap packet environment-context rendering drift.
- `LocalModelInfrastructureTests`: local agent mode availability conflicts with `LocalToolGrammar.supportsStructuredToolCalling == true`.
- `NonAgentPruningValidationTests`: setup/sidebar source guards still detect retired/non-agent pruning drift.
- `PGOAndArenasTests`: stale expectation still requires `[profile.release-pgo]` `lto = "thin"`, conflicting with the canonical release-profile contract.
- `RRFFusionQueryTests`: SQLite test database has no `fts5` module.
- `RuntimeValidationTests`: graph inspector/pinned inspector source guards and model-vault visible-model alignment still fail.
- `SearchIndexServiceFusionTests`: readable block fusion fixtures are out of sync with the current `readable_blocks` schema and FTS table setup.
- `ThemePairTests`: Rust bridge project wiring and liquid greeting source guards still fail.
- `TriageServiceTests`: low-power local runtime unload delay is `6s` where the test expects at least `10s`.

Next gate:

- Do not approve broad implementation.
- Create a second narrow deliberation for the remaining full-floor blockers, split by independent clusters. Favor source-guard/test-alignment repairs only where the product behavior is already intentionally changed; otherwise fix runtime code with focused tests first.

## Source-Guard And Cargo Mirror Repair Results

Gate status: **passed focused verification**.

Additional narrow repairs were approved through deliberation docs under `docs/fusion/deliberation/`:

- Cargo release-profile source guards now read Rust source from the bundled test source mirror instead of the live checkout.
- The Xcode project now bundles the Rust audit source mirror used by those guards.
- Runtime/source-guard tests were realigned to current behavior for harness rendering, setup/sidebar pruning, graph inspector logging, model-vault provider wiring, Rust bridge link flags, and the liquid greeting task identity.
- `CloudKnowledgeDistillationService` now receives a live main-actor model-vault target provider instead of a stale startup snapshot.

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/HarnessSubsystemTests -only-testing:EpistemosTests/NonAgentPruningValidationTests -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/ThemePairTests test
```

- Log: `/tmp/epistemos-source-guard-focused-2-20260430.log`
- Exit code `0`.
- Swift Testing: `392` tests passed.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_16-38-50--0500.xcresult`

## SQLite FTS Fusion Repair Results

Gate status: **passed focused verification**.

The RRF/SearchIndex fusion tests now distinguish host SQLite capability from product behavior:

- FTS5-specific tests are enabled only when the linked SQLite supports `fts5`.
- The Rust RRF constant parity test still runs everywhere and reads from the bundled source mirror.
- `SearchIndexServiceFusionTests` fixtures now use `ReadableBlocksIndex.insert` and canonical `ArtifactKind` values instead of the stale `content`/`position` columns.

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/RRFFusionQueryTests -only-testing:EpistemosTests/SearchIndexServiceFusionTests test
```

- Log: `/tmp/epistemos-rrf-fts-focused-3-20260430.log`
- Exit code `0`.
- Swift Testing: `16` tests in `2` suites passed; FTS5-only cases skipped on this host, Rust parity passed.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_16-52-58--0500.xcresult`

## Final Full Floor

Gate status: **passed**.

Swift full floor:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
```

- Log: `/tmp/epistemos-full-test-after-rrf-fts-20260430.log`
- Exit code `0`.
- Swift Testing: `5021` tests in `563` suites passed after `380.956` seconds.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_16-56-20--0500.xcresult`
- Xcode still reports SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains build-script/lint debt, not a test-floor blocker.

Rust floors:

```bash
cd graph-engine && cargo test
```

- Log: `/tmp/epistemos-graph-engine-cargo-after-rrf-fts-20260430.log`
- Result: `2522 passed`, `0 failed`, `8 ignored`; doc-tests `0 passed`, `0 failed`.

```bash
cd agent_core && cargo test
```

- Log: `/tmp/epistemos-agent-core-cargo-after-rrf-fts-20260430.log`
- Result: library `774 passed`, `0 failed`; bins/e2e passed; doc-tests `2 ignored`.

Post-floor guardrails:

- Protected-path diff audit remained empty for:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`
- No staging or commits were performed.

Next gate:

- The build/test floor is now green, so the fusion queue may move to the next implementation item.
- Kimi remains source-edit locked until a specific implementation deliberation gate is written and approved.

## Halo/Contextual Tests-Only Evidence

Gate status: **passed after serial full-floor corroboration**.

This slice was approved by:

- `docs/fusion/deliberation/halo_live_loop_tests_deliberation_2026_04_30.md`

Files changed:

- `EpistemosTests/ContextualShadowsStateTests.swift`
- `EpistemosTests/HaloUITests.swift`

No production files were edited. No protected files were edited. No staging or commits were performed.

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/HaloControllerTests -only-testing:EpistemosTests/HaloEditorBridgeTests -only-testing:EpistemosTests/HaloUITests -only-testing:EpistemosTests/ContextualShadowsStateTests -only-testing:EpistemosTests/ShadowServicesTests -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test
```

- Log: `/tmp/epistemos-halo-contextual-tests-only-20260430.log`
- Exit code `0`.
- Swift Testing: `72` tests in `6` suites passed after `4.453` seconds.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_17-28-50--0500.xcresult`
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains build-script/lint debt, not a focused test blocker.

Guardrails after focused verification:

- `git diff --check` returned clean for the changed test/doc scope.
- Protected-path diff audit remained empty for:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`

Default full Swift rerun:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
```

- Log: `/tmp/epistemos-full-test-after-halo-contextual-tests-20260430.log`
- Exit code `65`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_17-32-39--0500.xcresult`
- Xcode log included `Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches.`
- `xcresulttool` summary:
  - result: `Failed`
  - total tests: `5024`
  - failed tests: `2`
  - passed tests: `4986`
  - skipped tests: `36`
- Reported failures:
  - `GraphWorkspaceRouteNotificationTests/notificationOnPush`: expectation `await probe.matched()` failed.
  - `HarnessLifecycleTests/resetAndRestart`: test host crashed with signal trap.

Focused repro for the two full-run failures:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/GraphWorkspaceRouteNotificationTests -only-testing:EpistemosTests/HarnessLifecycleTests test
```

- Log: `/tmp/epistemos-full-rerun-failures-focused-20260430.log`
- Exit code `0`.
- Swift Testing: `7` tests in `2` suites passed after `0.045` seconds.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_17-40-43--0500.xcresult`

Serial full Swift corroboration:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO test
```

- Log: `/tmp/epistemos-full-test-serial-after-halo-contextual-tests-20260430.log`
- Exit code `0`.
- Swift Testing log summary: `5024` tests in `563` suites passed after `215.970` seconds.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_17-44-07--0500.xcresult`
- `xcresulttool` summary:
  - result: `Passed`
  - total tests: `5024`
  - failed tests: `0`
  - passed tests: `4988`
  - skipped tests: `36`
  - device-level expanded passed tests: `6199`
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains build-script/lint debt, not a serial full-floor blocker.

Interpretation:

- The Halo/Contextual tests-only slice is green.
- The two default full-run failures did not reproduce in isolation or in the serial full suite.
- Treat the default full-run failure as suite-order/test-host instability unless it recurs in a later full run.
- Product readiness is not claimed. Manual/runtime Halo and Contextual Shadows verification is still required before any user-facing claim.

Kimi Phase 0 audit:

- `docs/fusion/KIMI_FUSION_REVIEW_2026_04_30.md` exists and includes the requested source map, superseded sources, nuance, worktree salvage map, builder risks, missing evidence, first three slices, and red lines.
- Audit finding: `CLAUDE.md` exists, but Kimi did not list it in the required read set. Any further Kimi steering must first correct this omission and ask Kimi to reconcile the review with `CLAUDE.md`.
- Audit finding: Kimi's review predates the later green and blocked build-floor logs, so its build-status statements are stale. Current raw logs in this file supersede the Kimi review.
- Codex created `docs/fusion/KIMI_FUSION_REVIEW_ADDENDUM_2026_04_30.md` to fold in `CLAUDE.md` and the current raw evidence after a supervised Kimi correction attempt wrote a forbidden `/Users/jojo/.kimi/plans/...` plan file and was stopped.
- Kimi remains blocked from code edits until a fresh implementation deliberation gate is approved.

Quick Capture typed artifact slice:

- Deliberation gate:
  `docs/fusion/deliberation/quick_capture_typed_artifact_deliberation_2026_04_30.md`
- Scope:
  - Added committed `MutationEnvelope` output to `CaptureResult`.
  - Added `mutation_envelope_committed` capture trace event.
  - Created the envelope only after note persistence and graph write attempt.
  - Kept the slice Core/MAS-safe and did not touch protected editor or graph-render files.
- Red test log:
  `/tmp/epistemos-quick-capture-envelope-red-20260430.log`
- Red result:
  - Exit code `0` from `xcodebuild` process was not reached because build failed at Swift compile.
  - Expected compile failures proved the test was ahead of implementation:
    - `CaptureResult` had no `mutationEnvelope`.
    - `mutationEnvelopeCommitted` trace type did not exist yet.
- Green command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests -only-testing:EpistemosTests/MutationEnvelopeParityTests test
```

- Green log:
  `/tmp/epistemos-quick-capture-envelope-green-20260430.log`
- Exit code `0`.
- Swift Testing: `49` tests in `2` suites passed after `0.521` seconds.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_18-15-45--0500.xcresult`
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains build-script/lint debt, not a focused test blocker.

Guardrails after Quick Capture slice:

- `git diff --check` returned clean for:
  - `Epistemos/Engine/TextCapturePipeline.swift`
  - `Epistemos/Harness/TraceCollector.swift`
  - `EpistemosTests/TextCapturePipelineTests.swift`
  - `docs/fusion/deliberation/quick_capture_typed_artifact_deliberation_2026_04_30.md`
- Protected-path diff audit remained empty for:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`

Interpretation:

- The text-first Quick Capture path now returns a typed committed mutation envelope for the created note artifact and records it in the capture trace stream.
- Full append-only `RunEventLog` / Rust BLAKE3 chain integration remains a separate Raw Thoughts / Provenance Spine slice, not part of this Quick Capture V1 extraction.
- Manual/runtime capture verification remains deferred by user request.

Mutation Envelope EventStore durability slice:

- Deliberation gate:
  `docs/fusion/deliberation/mutation_envelope_eventstore_deliberation_2026_04_30.md`
- Scope:
  - Added a dedicated `mutation_envelopes` table to `EventStore`.
  - Added synchronous `saveMutationEnvelope(_:traceId:)` and `loadMutationEnvelope(mutationID:)`.
  - Stored full sorted `MutationEnvelope` JSON plus indexed trace/artifact/status/integrity columns.
  - Added `TextCapturePipeline` `EventStore` provider injection.
  - Added `CaptureResult.mutationEnvelopePersisted`.
  - Kept the slice Swift-only and did not touch dirty `agent_core`, `graph-engine`, protected editor, or protected graph-render paths.
- Red command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests -only-testing:EpistemosTests/MutationEnvelopeParityTests test
```

- Red log:
  `/tmp/epistemos-mutation-envelope-eventstore-red-20260430.log`
- Red result:
  - Expected compile failures proved the test was ahead of implementation:
    - `extra argument 'eventStoreProvider' in call`
    - `Value of type 'EventStore' has no member 'loadMutationEnvelope'`
- Green command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests -only-testing:EpistemosTests/MutationEnvelopeParityTests test
```

- Green log:
  `/tmp/epistemos-mutation-envelope-eventstore-green-20260430.log`
- Exit code `0`.
- Swift Testing: `50` tests in `2` suites passed after `0.530` seconds.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_18-25-30--0500.xcresult`
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains build-script/lint debt, not a focused test blocker.

Guardrails after Mutation Envelope EventStore slice:

- `git diff --check` returned clean for:
  - `Epistemos/State/EventStore.swift`
  - `Epistemos/Engine/TextCapturePipeline.swift`
  - `EpistemosTests/TextCapturePipelineTests.swift`
  - `docs/fusion/deliberation/mutation_envelope_eventstore_deliberation_2026_04_30.md`
  - `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- Protected-path diff audit remained empty for:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`

Interpretation:

- The Quick Capture mutation envelope is now durable in the app-level EventStore before the pipeline claims `mutationEnvelopePersisted == true`.
- This intentionally stops short of Rust `RunEventLog` / BLAKE3 chain work because the Rust provenance substrate is currently dirty/untracked and needs its own gate.
- Manual/runtime capture verification remains deferred by user request.

Raw Thoughts / Provenance Spine audit:

- Queue item 5 was treated as audit-only because the relevant Rust substrate is already dirty/untracked and must not be rewritten without a separate gate.
- Observed substrate:
  - `agent_core/src/mutations/`
  - `agent_core/src/provenance/`
  - `agent_core/src/bin/epistemos_trace.rs`
  - `agent_core/tests/epistemos_trace_e2e.rs`
  - `agent_core/src/oplog.rs`
- Root command from the queue failed because the repository root has no Cargo workspace manifest:

```bash
cargo test -p agent_core
```

- Corrected command:

```bash
cd agent_core && cargo test
```

- Log: `/tmp/epistemos-agent-core-provenance-audit-20260430.log`
- Exit code `0`.
- Result:
  - library tests: `774 passed`, `0 failed`
  - `epistemos_channel_relay`: `2 passed`
  - `epistemos_channel_worker`: `5 passed`
  - `epistemos_trace_e2e`: `6 passed`
  - doc-tests: `0 passed`, `2 ignored`

```bash
cd agent_core && cargo fmt --check
```

- Log: `/tmp/epistemos-agent-core-provenance-fmt-check-20260430.log`
- Exit code `0`.

Interpretation:

- The Rust mutation/provenance substrate currently verifies cleanly under `agent_core`.
- Codex made no Rust source edits in this queue item.
- Swift Quick Capture durability remains app-level `EventStore` durability only; any append-only Rust `RunEventLog`/BLAKE3 chain integration still requires a new deliberation gate.

Code Editor and `.epdoc` guardrail verification:

- Queue item 6 was treated as tests/docs-first because the active architecture is to preserve TextKit 2 notes, the live code-editor stack, and Tiptap `.epdoc`; broad editor replacement remains forbidden.
- No production files were edited. No protected editor or graph-render files were edited.

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO \
-only-testing:EpistemosTests/SwiftTreeSitterLiveHighlighterTests \
-only-testing:EpistemosTests/SyntaxCoreLiveHighlighterTests \
-only-testing:EpistemosTests/LiveCodeEditorControllerTests \
-only-testing:EpistemosTests/CodeFileServiceTests \
-only-testing:EpistemosTests/CodeArtifactTests \
-only-testing:EpistemosTests/EpdocPackageTests \
-only-testing:EpistemosTests/EpdocDocumentTests \
-only-testing:EpistemosTests/EpdocEditorBridgeTests \
-only-testing:EpistemosTests/EpdocEndToEndSmokeTests \
-only-testing:EpistemosTests/EpdocInfoPlistTests \
-only-testing:EpistemosTests/EpdocGraphProjectorTests \
-only-testing:EpistemosTests/EpdocGraphRenderingMapperTests \
-only-testing:EpistemosTests/EpdocPropertyTests \
-only-testing:EpistemosTests/EpdocDatabaseTests \
-only-testing:EpistemosTests/EpdocQueryTests \
-only-testing:EpistemosTests/EpdocQueryParserTests \
-only-testing:EpistemosTests/EpdocEditorToolbarTests \
-only-testing:EpistemosTests/EpdocSlashMenuViewTests \
-only-testing:EpistemosTests/EpdocComplexityCalculatorTests \
-only-testing:EpistemosTests/EpdocPasteClassifierTests \
-only-testing:EpistemosTests/EpdocBlockContextMenuTests \
test
```

- Log: `/tmp/epistemos-code-epdoc-guardrail-20260430.log`
- Exit code `0`.
- Swift Testing: `234` tests in `21` suites passed after `0.520` seconds.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_18-32-29--0500.xcresult`
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains build-script/lint debt, not a focused test blocker.

Guardrails after Code Editor / `.epdoc` verification:

- `git diff --check` returned clean for the touched docs and active Quick Capture/EventStore source scope.
- Protected-path diff audit remained empty for:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`

Interpretation:

- The current code-editor and `.epdoc` direction is verified by the focused shell test slice.
- Manual/runtime note editor, code editor, and `.epdoc` checks remain deferred by user request.
- The next queue item is the Pro-only Hermes / CLI / MCP gate audit.

Pro-only Hermes / CLI / MCP gate audit:

- Queue item 7 was treated as a gate audit, not an implementation merge, because the requirement is to keep Hermes, CLI, MCP, subprocess, browser/computer-use, Docker, and similar agentic capabilities out of the Core/MAS build unless explicitly direct-distribution/Pro gated.
- No production files were edited for this item.
- Manual UI verification of visible Pro controls remains deferred by user request.

Target and scheme inventory:

```bash
xcodebuild -list -project Epistemos.xcodeproj
```

- Targets include:
  - `Epistemos`
  - `Epistemos-AppStore`
  - `EpistemosTests`
  - `EpistemosWidgets`
  - `NightBrainHelper`
- Schemes include both `Epistemos` and `Epistemos-AppStore`.

Source and project audit:

```bash
rg "Hermes|MCP|stdio|subprocess|docker|cli_passthrough" .
rg "Hermes|MCP|stdio|subprocess|docker|cli_passthrough" Epistemos EpistemosTests agent_core omega-mcp graph-engine graph-engine-bridge *.xcodeproj
```

- Logs:
  - `/tmp/epistemos-pro-cli-mcp-audit-20260430.log`
  - `/tmp/epistemos-pro-cli-mcp-source-audit-20260430.log`
- Key observations:
  - `agent_core/src/lib.rs` gates Pro-only modules with `#[cfg(not(feature = "mas-sandbox"))]`, including `cli_passthrough`, `stdio_mcp`, `browser`, `computer_use`, `custom_tools`, and `delegate_task`.
  - `agent_core/src/bridge.rs` registers discovered stdio MCP tools only under `#[cfg(not(feature = "mas-sandbox"))]`.
  - `agent_core/src/tools/registry.rs` keeps MAS runtime deny/preflight protection and excludes `bash_execute`, `claude_code`, and `codex` registration under `mas-sandbox`.
  - `omega-mcp/src/lib.rs` gates `osascript` and `pty` modules under `#[cfg(not(feature = "mas-sandbox"))]`.
  - `omega-mcp/src/uniffi_exports.rs` preserves stable UniFFI symbols in MAS while returning `unavailable_in_mas_sandbox` stubs for forbidden operations.
  - `build-agent-core.sh` passes `--features mas-sandbox` for `TARGET_NAME=Epistemos-AppStore` or the App Store bundle id.
  - `build-omega-mcp.sh` passes `--features mas-sandbox` when `MAS_SANDBOX=1`.
  - `Epistemos.xcodeproj/project.pbxproj` gives the App Store target `MAS_SANDBOX` and `EPISTEMOS_APP_STORE` compilation conditions.
  - `Epistemos/KnowledgeFusion/PythonEnvironmentManager.swift`, `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift`, `Epistemos/Vault/VaultChatMutator.swift`, and chat/settings UI paths include App Store defense-in-depth gates for subprocess or shell-adjacent capabilities.

App Store build:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS' build
```

- Log: `/tmp/epistemos-appstore-gate-build-20260430.log`
- Exit code `0`.
- Result: `** BUILD SUCCEEDED **`
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after the successful build; this remains build-script/lint debt, not a MAS gate blocker.
- The build also reported the existing `AVAudioPCMBuffer` Sendable warning in `EpistemosSpeechAnalyzer`.

Direct/Pro build:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' build
```

- Log: `/tmp/epistemos-direct-gate-build-20260430.log`
- Exit code `0`.
- Result: `** BUILD SUCCEEDED **`
- The same SwiftLint command failures were emitted after the successful build.

MAS symbol audit:

```bash
nm -gU build-rust/libagent_core.dylib | rg "(pty_|bash_execute|claude_code|codex|stdio_mcp|register_discovered_stdio_mcp_tools|cli_passthrough)" || true
nm -gU build-rust/libomega_mcp.dylib | rg "(pty_|tool_run_command|openpty|forkpty|osascript|Command)" || true
strings build-rust/libagent_core.dylib | rg "(claude_code|codex exec|register_discovered_stdio_mcp_tools|stdio MCP|bash_execute)" || true
strings build-rust/libomega_mcp.dylib | rg "(pty_spawn_session|pty_execute_command|unavailable_in_mas_sandbox|tool_run_command)" || true
```

- `libagent_core.dylib` retained denylist/preflight strings for forbidden tool names, but no exported CLI handler symbols were observed by the audit command.
- `libomega_mcp.dylib` retained stable UniFFI symbol names for `pty_*` and `tool_run_command`; the corresponding MAS strings include `unavailable_in_mas_sandbox`, matching the source-level stub design.
- This symbol shape is acceptable only because the source audit confirms the MAS implementation stubs the forbidden operations instead of executing them.

Direct/Pro symbol audit after direct build:

```bash
nm -gU build-rust/libagent_core.dylib | rg "(pty_|register_discovered_stdio_mcp_tools|cli_passthrough|agent_core_policy_profile)" || true
strings build-rust/libagent_core.dylib | rg "(claude_code|codex exec|register_discovered_stdio_mcp_tools|stdio MCP|bash_execute)" | head -n 80 || true
nm -gU build-rust/libomega_mcp.dylib | rg "(pty_|tool_run_command)" || true
strings build-rust/libomega_mcp.dylib | rg "(pty_spawn_session|pty_execute_command|unavailable_in_mas_sandbox|tool_run_command)" | head -n 80 || true
```

- Direct/Pro `libagent_core.dylib` exposes the expected Pro-only CLI/MCP capability surface.
- Direct/Pro `libomega_mcp.dylib` exposes expected `pty_*` and `tool_run_command` UniFFI symbols.

Rust MAS feature verification:

```bash
cd omega-mcp && cargo test --features mas-sandbox
```

- Log: `/tmp/epistemos-omega-mcp-mas-sandbox-cargo-20260430.log`
- Exit code `0`.
- Result: `109` tests passed, `0` failed, `1` doc-test ignored.

```bash
cd agent_core && cargo test --features mas-sandbox
```

- Log: `/tmp/epistemos-agent-core-mas-sandbox-cargo-20260430.log`
- Result caveat:
  - library/bin/E2E tests passed, but the full command hit a rustdoc dependency-path issue during doc-tests.
  - Because the shell command did not use `pipefail`, this first log is treated as non-authoritative for full cargo outcome.
  - The visible doc-test issue involved a missing `libtantivy` rlib path plus an ambiguous `doc` import in `src/storage/vault.rs`.

Authoritative non-doctest rerun:

```bash
cd agent_core && cargo test --features mas-sandbox --lib --bins --tests
```

- Log: `/tmp/epistemos-agent-core-mas-sandbox-nondoctest-20260430.log`
- Exit code `0`.
- Result:
  - library tests: `648 passed`, `0 failed`
  - `epistemos_channel_relay`: `2 passed`
  - `epistemos_channel_worker`: `5 passed`
  - `epistemos_trace`: `0` tests
  - `epistemos_trace_e2e`: `6 passed`

Interpretation:

- The current Core/MAS gate has source-level, build-level, and Rust-feature evidence that Pro-only CLI/MCP/subprocess capabilities are excluded or stubbed in the App Store path.
- Direct/Pro retains the expected capability surface.
- Remaining verification gap is manual UI confirmation that Pro controls are not visible/reachable in the MAS app; this is intentionally deferred by user request.
- The next queue item is Benchmark Harness and Graph-Engine Quarantine.

Benchmark Harness and Graph-Engine Quarantine:

- Deliberation gate:
  `docs/fusion/deliberation/benchmark_harness_graph_engine_quarantine_deliberation_2026_04_30.md`
- Scope:
  - Treated queue item 8 as benchmark/test/doc-only.
  - Did not edit `graph-engine` production implementation.
  - Did not edit protected graph render paths.
  - Confirmed existing benchmark harnesses are already present:
    - `graph-engine/benches/graph_ffi_baselines.rs`
    - `EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift`
    - `docs/architecture/BENCHMARK_BASELINES.csv`
  - Compared the Inspiring-Heisenberg donor harness against main; no raw donor merge was needed.

Rust graph-engine test floor:

```bash
cargo test --manifest-path graph-engine/Cargo.toml
```

- Log: `/tmp/epistemos-graph-engine-quarantine-cargo-test-20260430.log`
- Exit code `0`.
- Result:
  - `2522` passed
  - `0` failed
  - `8` ignored
  - doc-tests: `0` tests, `0` failed

Rust graph FFI Criterion baseline:

```bash
cargo bench --manifest-path graph-engine/Cargo.toml --bench graph_ffi_baselines -- --sample-size 10 --measurement-time 1
```

- Log: `/tmp/epistemos-graph-ffi-baselines-cargo-bench-20260430.log`
- Exit code `0`.
- Current short-sample medians:
  - `graph_data_loading/add_100_nodes_and_edges`: `57.413 µs`
  - `graph_data_loading/add_500_nodes_and_edges`: `412.64 µs`
  - `graph_data_loading/add_1000_nodes_and_edges`: `1.1407 ms`
  - `graph_data_loading/add_5000_nodes_and_edges`: `18.597 ms`
  - `search/build_index_1000`: `166.92 µs`
  - `search/search_exact_1000`: `1.2200 ms`
  - `search/search_fuzzy_1000`: `920.31 µs`
  - `search/search_no_match_1000`: `277.16 µs`
  - `simulation_tick/tick_100_nodes`: `89.935 ns`
  - `simulation_tick/tick_500_nodes`: `433.53 ns`
  - `simulation_tick/tick_1000_nodes`: `829.93 ns`
  - `markdown_parse/small_50bytes`: `94.194 ns`
  - `markdown_parse/medium_10KB`: `13.260 µs`
  - `markdown_parse/large_50KB`: `75.403 µs`
- Interpretation:
  - The current dirty graph-engine state benchmarks faster than the older 2026-04-15 Criterion baseline in every measured Rust category.
  - This is evidence only. It does not approve graph-engine implementation edits or BoltFFI production adoption.

Swift graph FFI benchmark-suite check:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/GraphFFIBenchmarkTests test
```

- Log: `/tmp/epistemos-graph-ffi-benchmark-suite-xcode-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_18-53-56--0500.xcresult`
- Result:
  - `** TEST SUCCEEDED **`
  - The `Graph FFI Benchmarks` suite was skipped by design as `Manual benchmark suite — run via Instruments`.
  - Swift Testing reported `5` tests in `1` suite passed/skipped after `0.001` seconds.
  - Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains build-script/lint debt, not a graph benchmark blocker.

Guardrail interpretation:

- Baseline benchmark infrastructure exists before any graph-engine or BoltFFI work.
- Graph-engine implementation remains quarantined.
- `git diff --check` returned clean for the item 8 fusion docs.
- Protected Swift graph/editor path audit remained empty for:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`
- Graph-engine protected internals are not clean, but those diffs were pre-existing quarantine scope and were not edited for item 8:
  - `graph-engine/src/renderer.rs`
  - `graph-engine/src/forces.rs`
  - `graph-engine/src/simulation.rs`
  - `graph-engine/src/motion/curl.rs`
  - `graph-engine/src/motion/waves.rs`
- Runtime graph view and Instruments/os_signpost capture remain deferred by user request.
- The next queue item is App Store / Direct Distribution Release Split.

App Store / Direct Distribution Release Split:

- Deliberation gate:
  `docs/fusion/deliberation/app_store_direct_release_split_deliberation_2026_04_30.md`
- Release-audit skill status:
  - The Epistemos Release Audit skill was applied for this queue item.
  - This is not a final ship call because manual/runtime UI verification is explicitly deferred by user request.
  - Do not claim App Store or direct-distribution release readiness from this slice alone.
- Scope:
  - Shell/config/build audit only.
  - Did not edit `Epistemos.xcodeproj/project.pbxproj`.
  - Did not edit App Store, direct, or debug entitlements.
  - Did not edit `Epistemos-AppStore-Info.plist` or `Epistemos-Info.plist`.

Build-setting split:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -showBuildSettings
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -showBuildSettings
```

- Logs:
  - `/tmp/epistemos-release-split-appstore-settings-20260430.log`
  - `/tmp/epistemos-release-split-direct-settings-20260430.log`
- App Store settings:
  - `PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.appstore`
  - `INFOPLIST_FILE = Epistemos-AppStore-Info.plist`
  - `CODE_SIGN_ENTITLEMENTS = Epistemos/Epistemos-AppStore.entitlements`
  - `SWIFT_ACTIVE_COMPILATION_CONDITIONS` includes `EPISTEMOS_APP_STORE` and `MAS_SANDBOX`
  - `OTHER_LDFLAGS` omits `-lomega_ax`
  - `ENABLE_APP_SANDBOX = NO` in build settings, while the embedded signed entitlements audit below shows `com.apple.security.app-sandbox = true`; this mismatch should be reviewed before any final release claim.
- Direct settings:
  - `PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.app`
  - `INFOPLIST_FILE = Epistemos-Info.plist`
  - `CODE_SIGN_ENTITLEMENTS = Epistemos/Epistemos-Debug.entitlements`
  - `SWIFT_ACTIVE_COMPILATION_CONDITIONS` does not include `EPISTEMOS_APP_STORE` or `MAS_SANDBOX`
  - `OTHER_LDFLAGS` includes `-lomega_ax`

Source plist/entitlement/privacy manifest audit:

```bash
plutil -p Epistemos/Epistemos-AppStore.entitlements
plutil -p Epistemos/Epistemos.entitlements
plutil -p Epistemos/Epistemos-Debug.entitlements
plutil -p Epistemos/Resources/PrivacyInfo.xcprivacy
plutil -p Epistemos-AppStore-Info.plist
plutil -p Epistemos-Info.plist
```

- App Store entitlements are sandboxed and limited to app sandbox, network client, user-selected read/write files, app-scope bookmarks, and JIT.
- Direct entitlements include broader direct-distribution capabilities: Apple Events, unsigned executable memory, disabled library validation, document-scope bookmarks, and an accessibility mach-lookup temporary exception.
- Debug entitlements are not App Store sandboxed.
- `PrivacyInfo.xcprivacy` is bundled and declares accessed API categories for file timestamp, system boot time, disk space, and user defaults; it declares no collected data and no tracking domains.
- App Store Info.plist uses `com.epistemos.appstore`, version `1.0.0` build `1`, export compliance `false`, and only the queried microphone/speech sensitive usage strings.
- Direct Info.plist uses `com.epistemos.app` and includes direct-only Accessibility, Apple Events, and Screen Capture usage strings.

App Store build and embedded audit:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS' build
codesign -d --entitlements :- <Debug/Epistemos.app>
plutil -p <Debug/Epistemos.app/Contents/Info.plist>
find <Debug/Epistemos.app/Contents> -maxdepth 3 \( -name '*omega_ax*' -o -name '*omega_mcp*' -o -name '*agent_core*' -o -name '*PrivacyInfo.xcprivacy' \) -print
otool -L <Debug/Epistemos.app/Contents/MacOS/Epistemos.debug.dylib>
```

- Build log: `/tmp/epistemos-release-split-appstore-build-20260430.log`
- Exit code `0`.
- Result: `** BUILD SUCCEEDED **`
- Embedded app entitlements observed:
  - app sandbox: `true`
  - JIT: `true`
  - app-scope bookmarks: `true`
  - user-selected read/write files: `true`
  - network client: `true`
  - no Apple Events entitlement
  - no disable-library-validation entitlement
  - no unsigned executable memory entitlement
- Build log compiled with `-DEPISTEMOS_APP_STORE` and `-DMAS_SANDBOX`.
- App Store bundle contained `libagent_core.dylib`, `libomega_mcp.dylib`, and `PrivacyInfo.xcprivacy`.
- App Store bundle/link audit found no `omega_ax`.
- App Store `Epistemos.debug.dylib` linked `libomega_mcp`, `libepistemos_core`, `libagent_core`, `libepistemos_shadow`, and `llama.framework`, but not `libomega_ax`.
- MAS `libagent_core` still contains forbidden tool-name strings only as denylist/preflight text; `nm` did not show exported forbidden handler symbols.
- MAS `libomega_mcp` retains stable UniFFI `pty_*` / `tool_run_command` symbol names, but source/string audits from queue item 7 confirm these are MAS stubs returning `unavailable_in_mas_sandbox`.

Direct build and embedded audit:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' build
codesign -d --entitlements :- <Debug/Epistemos.app>
plutil -p <Debug/Epistemos.app/Contents/Info.plist>
find <Debug/Epistemos.app/Contents> -maxdepth 3 \( -name '*omega_ax*' -o -name '*omega_mcp*' -o -name '*agent_core*' -o -name '*PrivacyInfo.xcprivacy' \) -print
otool -L <Debug/Epistemos.app/Contents/MacOS/Epistemos.debug.dylib>
```

- Build log: `/tmp/epistemos-release-split-direct-build-20260430.log`
- Exit code `0`.
- Result: `** BUILD SUCCEEDED **`
- Embedded direct entitlements observed:
  - app sandbox: `false`
  - JIT: `true`
  - unsigned executable memory: `true`
  - disable library validation: `true`
  - get-task-allow: `true`
- Direct Info.plist audit observed:
  - bundle identifier: `com.epistemos.app`
  - version `1.0.0`, build `1`
  - export compliance `false`
  - Accessibility, Apple Events, Screen Capture, Microphone, and Speech usage descriptions present.
- Direct bundle contained:
  - `libagent_core.dylib`
  - `libomega_ax.dylib`
  - `libomega_mcp.dylib`
  - `PrivacyInfo.xcprivacy`
- Direct `Epistemos.debug.dylib` linked `libomega_mcp`, `libomega_ax`, `libepistemos_core`, `libagent_core`, `libepistemos_shadow`, and `llama.framework`.

Full Swift test attempt:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO test
```

- Log: `/tmp/epistemos-release-split-full-xcode-test-20260430.log`
- Hang sample: `/tmp/epistemos-full-test-hang-sample-33021.txt`
- Outcome: interrupted after hang; no full-suite pass claimed.
- Evidence:
  - Test host launched and reached live Swift Testing execution.
  - Many suites passed before interruption, including `AI Partner`, `Adaptation`, `AgentChatState`, `Concurrency Stress`, and `Confidence Router`.
  - The run blocked at `Contextual Shadows V0 is the production-mounted recall surface`.
  - Process sample showed the main thread inside `ContextualShadowsStateTests.contextualShadowsProductionMountsArePresent()` while `String(contentsOf:)` was blocked in kernel `open()` at `ContextualShadowsStateTests.swift:208`.
  - Because the repo is under `/Users/jojo/Downloads`, this is treated as an environment/source-file access hang until proven otherwise, not as a failed assertion.
  - The wedged `xcodebuild`/test-host process was terminated with `kill -TERM`; the log ends with `** BUILD INTERRUPTED **`.

Known release-split gaps and follow-up:

- Manual/runtime release verification is deferred:
  - no MAS app launch inspection
  - no direct app launch inspection
  - no UI confirmation that Pro controls are hidden/unreachable in MAS
  - no runtime log correlation against visible behavior
- Review before final release:
  - App Store `ENABLE_APP_SANDBOX = NO` build setting versus embedded sandbox entitlement `true`.
  - Full-suite source guard hang from `Downloads` path.
  - Existing SwiftLint plugin command failures after successful builds for `CodeEditSourceEditor` and `CodeEditTextView`.
  - Existing `AVAudioPCMBuffer` Sendable warnings in `EpistemosSpeechAnalyzer`.

Interpretation:

- The split has strong shell/build/config evidence:
  - App Store path uses MAS compile flags, sandboxed embedded entitlements, MAS Info.plist, no `omega_ax` link/bundle, and MAS-stubbed Rust capability surfaces.
  - Direct path preserves direct-only entitlements, direct Info.plist usage strings, and `omega_ax` linkage/bundling.
- The branch is not release-ready from this item because full-suite test did not complete and manual/runtime verification is intentionally deferred.

Contextual Shadows source-mirror repair:

- Deliberation gate:
  `docs/fusion/deliberation/contextual_shadows_source_mirror_deliberation_2026_04_30.md`
- Red evidence:
  - `/tmp/epistemos-release-split-full-xcode-test-20260430.log`
  - `/tmp/epistemos-full-test-hang-sample-33021.txt`
  - Full-suite run blocked at `Contextual Shadows V0 is the production-mounted recall surface`.
  - Sample showed `ContextualShadowsStateTests.contextualShadowsProductionMountsArePresent()` blocked in `String(contentsOf:)` / kernel `open()` while reading source from `/Users/jojo/Downloads/Epistemos`.
- Change:
  - Updated `EpistemosTests/ContextualShadowsStateTests.swift` to read source guards through `loadMirroredSourceTextFile(_:)` instead of a `#filePath`-derived live repo path.
  - Preserved the existing Contextual Shadows V0 mount/backend assertions.
  - Did not edit production Contextual Shadows, Halo, note editor, graph, project, entitlements, or plists.

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ContextualShadowsStateTests test
```

- Log: `/tmp/epistemos-contextual-shadows-source-mirror-20260430.log`
- Exit code `0`.
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `13` tests passed
  - `1` suite passed
  - Previously wedged source guard passed in `0.009` seconds.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt.

Full Swift floor after source-mirror repair:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO test
```

- Log: `/tmp/epistemos-full-after-contextual-source-mirror-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_19-22-02--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `5027` tests passed
  - `563` suites passed
  - test runtime `211.485` seconds
- The former `ContextualShadowsStateTests` source-read hang did not recur.
- The run emitted a Thread Performance Checker warning during `Phase R.9 — Canonical Resource Runtime Regressions` while `agent_core` waited on a Tantivy commit; the relevant test passed and the suite continued to completion.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker in this run.

## Mutation Projection Outbox Slice Results

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/mutation_projection_outbox_deliberation_2026_04_30.md`

Change:

- Added a durable `mutation_projection_outbox` table to `EventStore`.
- `saveMutationEnvelope(_:traceId:)` now writes committed-envelope outbox rows in the same SQLite transaction as the envelope upsert.
- Projection rows are idempotent by `mutation_id UNIQUE` and use a sorted JSON payload containing mutation id, trace id, status, artifact id/kind, event kind, and integrity hash.
- Pending envelopes remain stored but do not enter the projection outbox.
- No UI projection, notification bus, graph pulse, Rust schema, editor, graph, project, entitlement, or generated-file changes were made.

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/CognitiveSubstrateTests/EventStoreSchemaTests -only-testing:EpistemosTests/TextCapturePipelineTests -only-testing:EpistemosTests/MutationEnvelopeParityTests test
```

- Log: `/tmp/epistemos-mutation-projection-outbox-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_19-37-54--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `50` tests passed
  - `2` suites passed
  - `MutationEnvelope cross-language parity (T+4.8)`
  - `TextCapturePipeline`
- Selector note: the `EpistemosTests/CognitiveSubstrateTests/EventStoreSchemaTests` selector did not match the Swift Testing suite, so it was rerun directly below.

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
```

- Log: `/tmp/epistemos-mutation-projection-outbox-schema-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_19-40-40--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `8` tests passed
  - `1` suite passed
  - new pending-envelope no-outbox guard passed.

Post-slice guardrails:

- `git diff --check` passed for the touched EventStore/test/deliberation/results files.
- Protected-path diff audit remained empty for:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker in these runs.

## Mutation Projection Outbox Pending Reader Results

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/mutation_projection_outbox_pending_reader_deliberation_2026_04_30.md`

Change:

- Added `EventStore.pendingMutationProjectionOutboxRows(limit:)`.
- The reader is bounded, read-only, and ordered by outbox insertion id.
- Non-positive limits return no rows; positive limits are clamped internally.
- The reader does not mark rows processed, add queue lifecycle state, call Rust, emit AgentEvent/GraphEvent, or wire UI.
- Shared outbox row decoding now backs both the mutation-specific audit read and pending-reader path.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
```

- Log: `/tmp/epistemos-outbox-pending-reader-red-20260430.log`
- Exit code `65`.
- Expected failure:
  - `Value of type 'EventStore' has no member 'pendingMutationProjectionOutboxRows'`

Schema verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
```

- Log: `/tmp/epistemos-outbox-pending-reader-schema-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_19-53-15--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `9` tests passed
  - `1` suite passed

Final focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests -only-testing:EpistemosTests/TextCapturePipelineTests -only-testing:EpistemosTests/MutationEnvelopeParityTests test
```

- Log: `/tmp/epistemos-outbox-pending-reader-final-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_19-59-11--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `59` tests passed
  - `3` suites passed
  - `EventStore Cognitive Tables`: `9` tests passed.
  - `MutationEnvelope cross-language parity (T+4.8)`: `13` tests passed.
  - `TextCapturePipeline`: `37` tests passed.

Post-slice guardrails:

- `git diff --check` passed for the touched EventStore/test/deliberation files.
- Protected-path diff audit remained empty for:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`
- No Rust, graph-engine, protected note editor, protected graph renderer, project, entitlement, generated-file, stash, branch, staging, or commit action was taken.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.

## W10.12 Sidecar Interpretation Directive Results

Gate status: **passed focused automated verification**.

Deliberation gate:
`docs/fusion/deliberation/w1012_sidecar_interpretation_directive_deliberation_2026_04_30.md`

Change:

- Added optional `interpretationDirective` to `EpistemosSidecar`, encoded as additive snake-case `interpretation_directive`.
- Bumped current sidecar schema to `3` while preserving decode compatibility for v2 sidecars without the new optional field.
- Added opt-in `EpistemosSidecarStore.write(..., modelDerived:)`, defaulting to `false` so generic/user writes are not mislabeled.
- Marked explicit model-derived writes with `com.epistemos.modelDerived = true`.
- Wired `OntologyClassifier.classifyAndPersist(...)` to write the additive directive and use `modelDerived: true` for AFM/classifier sidecars.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EpistemosSidecarTests test
```

- Log: `/tmp/epistemos-w1012-sidecar-directive-red-20260430.log`
- Exit code `65`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_22-04-46--0500.xcresult`
- Expected failures:
  - `EpistemosSidecar` had no `interpretationDirective`.
  - `EpistemosSidecarStore` had no `modelDerivedAttributeName`.
  - `EpistemosSidecarStore.write` had no `modelDerived` argument.

Focused green verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EpistemosSidecarTests test
```

- Log: `/tmp/epistemos-w1012-sidecar-directive-green-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_22-08-29--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `16` tests passed
  - `1` suite passed

Post-slice audits:

- Source audit log: `/tmp/epistemos-w1012-sidecar-directive-source-audit-20260430.log`
- Tracked-source diff check log: `/tmp/epistemos-w1012-diff-check-20260430.log` (`0` bytes).
- Touched-file whitespace audit log: `/tmp/epistemos-w1012-whitespace-audit-20260430.log` (`0` bytes).
- Protected diff audit log: `/tmp/epistemos-w1012-protected-diff-audit-20260430.log`
- Protected diff audit reports pre-existing dirty graph-engine internals:
  - `graph-engine/src/forces.rs`
  - `graph-engine/src/motion/curl.rs`
  - `graph-engine/src/motion/waves.rs`
  - `graph-engine/src/renderer.rs`
  - `graph-engine/src/simulation.rs`
- This slice did not edit those protected graph-engine files, note editor files, graph renderer/controller files, project files, entitlements, generated artifacts, stash state, branch state, staging, or commits.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.

## OpLog FFI Boundary Audit Results

Gate status: **passed read-only boundary audit**.

Deliberation gate:
`docs/fusion/deliberation/oplog_ffi_boundary_audit_deliberation_2026_04_30.md`

Kimi advisory:

- Kimi was invoked read-only from `/tmp`.
- Kimi accepted the slice as a documentation-and-symbol audit only.
- Kimi highlighted that raw pointer ownership, allocator/freeing, nullability, and runtime Swift correctness remain future bridge risks.
- Resume id: `14011cf1-9ebc-470d-80d5-0aba060ee74b`

Symbol verification:

```bash
nm -gU build-rust/libagent_core.dylib | rg 'oplog_(open_at|iter_after_json|release|free_string)'
lipo -archs build-rust/libagent_core.dylib
nm -arch arm64 -gU build-rust/libagent_core.dylib | rg 'oplog_(open_at|iter_after_json|release|free_string)'
nm -arch x86_64 -gU build-rust/libagent_core.dylib | rg 'oplog_(open_at|iter_after_json|release|free_string)'
```

- `build-rust/libagent_core.dylib` is universal: `x86_64 arm64`.
- Both `arm64` and `x86_64` exports include:
  - `_oplog_free_string`
  - `_oplog_iter_after_json`
  - `_oplog_open_at`
  - `_oplog_release`

Integration absence check:

```bash
rg -n 'oplog_open_at|oplog_iter_after_json|oplog_release|oplog_free_string|\boplog_' build-rust/swift-bindings/agent_coreFFI.h build-rust/swift-bindings/agent_coreFFI/agent_coreFFI.h build-rust/swift-bindings/agent_coreFFI.modulemap build-rust/swift-bindings/agent_core.swift Epistemos EpistemosTests --glob '!**/SourceMirror/**'
```

- Exit code `1`.
- Expected result: no generated binding, Swift app, or Swift test call sites for raw `oplog_*` symbols.

Rust focused verification:

```bash
cargo test --manifest-path agent_core/Cargo.toml oplog --lib
```

- Log: `/tmp/epistemos-agent-core-oplog-boundary-20260430.log`
- Exit code `0`.
- Result: `14` `oplog` tests passed; `760` tests filtered out.

Boundary note:

- This proves raw Rust symbol availability and absence of current Swift integration.
- This does not implement Swift `OpLogFFIClient`, RunEventLog integration, AgentEvent, GraphEvent, graph projection, or UI visibility.
- A future implementation must get a separate bridge deliberation with ownership, nullability, allocator, and runtime tests.

Post-slice guardrails:

- No source edits were made in this audit pass.
- No Rust, graph-engine, protected note editor, protected graph renderer, project, entitlement, generated-file, stash, branch, staging, or commit action was taken.

## Full Floor Source Guard And Model Vault Provider Results

Gate status: **passed focused verification without additional source edits**.

Deliberation gate:
`docs/fusion/deliberation/full_floor_source_guard_and_model_vault_provider_deliberation_2026_04_30.md`

Current source state:

- `AppBootstrap.cloudKnowledgeDistillationService` already captures `let inferenceState = self.inferenceState`.
- The `targetsProvider` closure calls `inferenceState.modelVaultTargets()`, preserving current model-vault visibility for rebuilds instead of freezing a launch snapshot.
- The previously stale source guards now match current source behavior.

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/HarnessSubsystemTests -only-testing:EpistemosTests/NonAgentPruningValidationTests -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/ThemePairTests test
```

- Log: `/tmp/epistemos-source-guard-focused-post-qc-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_20-16-53--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `392` tests passed
  - `3` suites passed

Post-slice guardrails:

- No source edits were made in this closeout pass.
- No Rust, graph-engine, protected note editor, protected graph renderer, project, entitlement, generated-file, stash, branch, staging, or commit action was taken.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.

## Quick Capture Durable Success Results

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/quick_capture_durable_success_deliberation_2026_04_30.md`

Change:

- Quick Capture sheet text submission now requires `result.mutationEnvelopePersisted` before presenting success.
- Quick Capture audio submission now requires `result.mutationEnvelopePersisted` before presenting success.
- Quick Capture App Intent now requires `result.mutationEnvelopePersisted` before opening the note and returning a success dialog.
- Added source-mirror tests to prevent success surfaces from bypassing the durable mutation-envelope signal.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests test
```

- Log: `/tmp/epistemos-quick-capture-durable-success-red-20260430.log`
- Exit code `65`.
- Expected failures:
  - Quick Capture sheet did not contain two `guard result.mutationEnvelopePersisted else` checks.
  - Quick Capture intent did not contain `guard result.mutationEnvelopePersisted else` before `NoteWindowManager.shared.open(pageId: noteId)`.

Focused green verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests test
```

- Log: `/tmp/epistemos-quick-capture-durable-success-green-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_20-08-47--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `39` tests passed
  - `1` suite passed

Final focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests -only-testing:EpistemosTests/MutationEnvelopeParityTests test
```

- Log: `/tmp/epistemos-quick-capture-durable-success-final-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_20-11-37--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `52` tests passed
  - `2` suites passed
  - `TextCapturePipeline`: `39` tests passed.
  - `MutationEnvelope cross-language parity (T+4.8)`: `13` tests passed.

Post-slice guardrails:

- `git diff --check` passed for the touched Quick Capture, intent, test, deliberation, and results files.
- Protected-path diff audit remained empty for:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`
- No Rust, graph-engine, protected note editor, protected graph renderer, project, entitlement, generated-file, stash, branch, staging, or commit action was taken.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.

## W10.8 Cognitive Depth Overlay Results

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/w1008_cognitive_depth_overlay_deliberation_2026_04_30.md`

Change:

- Added focused `CognitiveDepthOverlayTests` coverage for missing sidecars, sidecar-backed depth, pending preview overrides, corrupt-sidecar fallback, and visualization hierarchy.
- Fixed `CognitiveDepthOverlay.depth(for:)` so pending preview overrides win over cached sidecar depth until discarded.
- Updated the overlay source-of-truth comment to match runtime precedence.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/CognitiveDepthOverlayTests test
```

- Log: `/tmp/epistemos-w1008-cognitive-depth-overlay-red-20260430.log`
- Result: `** TEST FAILED **`
- Expected failure: `Pending preview override wins over cached sidecar until discarded` returned cached `.surface` instead of pending `.coreBelief`.

Green verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/CognitiveDepthOverlayTests test
```

- Log: `/tmp/epistemos-w1008-cognitive-depth-overlay-green-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_22-19-13--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `5` tests passed in `1` suite.

Post-slice guardrails:

- Source audit log: `/tmp/epistemos-w1008-cognitive-depth-overlay-source-audit-20260430.log`
- Tracked-source diff check log: `/tmp/epistemos-w1008-diff-check-20260430.log`
- Touched-file whitespace audit log: `/tmp/epistemos-w1008-whitespace-audit-20260430.log`
- Protected diff audit log: `/tmp/epistemos-w1008-protected-diff-audit-20260430.log`
- Protected diff audit reports only pre-existing dirty graph-engine internals in the protected pattern:
  - `graph-engine/src/forces.rs`
  - `graph-engine/src/motion/curl.rs`
  - `graph-engine/src/motion/waves.rs`
  - `graph-engine/src/renderer.rs`
  - `graph-engine/src/simulation.rs`
- No protected graph-engine internals, protected note editor paths, protected graph renderer/controller paths, project files, entitlements, generated artifacts, stash state, branch state, staging, or commits were changed by this slice.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.

## W10.15 Ambient Retrieval Toggle Persistence Results

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/w1015_ambient_retrieval_toggle_persistence_deliberation_2026_04_30.md`

Change:

- Added focused `AmbientRetrievalToggleTests`.
- Persisted `AmbientRetrievalToggle.defaultForNewConversations` to a namespaced `UserDefaults` key.
- Persisted explicit per-conversation ambient retrieval overrides to a namespaced `UserDefaults` map.
- Added DEBUG-only defaults injection/reload/reset hooks so tests use isolated defaults suites and do not pollute user defaults.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/AmbientRetrievalToggleTests test
```

- Log: `/tmp/epistemos-w1015-ambient-toggle-red-20260430.log`
- Result: `** TEST FAILED **`
- Expected failures:
  - missing `resetForTesting`;
  - missing `setUserDefaultsForTesting`;
  - missing `reloadFromUserDefaultsForTesting`.

Green verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/AmbientRetrievalToggleTests test
```

- Log: `/tmp/epistemos-w1015-ambient-toggle-green-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_22-29-47--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `2` tests passed in `1` suite.

Post-slice guardrails:

- Source audit log: `/tmp/epistemos-w1015-ambient-toggle-source-audit-20260430.log`
- Tracked-source diff check log: `/tmp/epistemos-w1015-diff-check-20260430.log`
- Touched-file whitespace audit log: `/tmp/epistemos-w1015-whitespace-audit-20260430.log`
- Protected diff audit log: `/tmp/epistemos-w1015-protected-diff-audit-20260430.log`
- Protected diff audit reports only pre-existing dirty graph-engine internals in the protected pattern:
  - `graph-engine/src/forces.rs`
  - `graph-engine/src/motion/curl.rs`
  - `graph-engine/src/motion/waves.rs`
  - `graph-engine/src/renderer.rs`
  - `graph-engine/src/simulation.rs`
- `QuarantineArchive.swift` had unrelated pre-existing dirty sliding-window archive changes before this persistence slice; this section claims only ambient toggle persistence.
- No protected graph-engine internals, protected note editor paths, protected graph renderer/controller paths, project files, entitlements, generated artifacts, stash state, branch state, staging, or commits were changed by this slice.
- Kimi provided read-only advisory only, from `/tmp` with pasted context. It did not edit code or control the repo.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.


## W10.16 ConversationState Dispatch Read-Site Repair

Slice: AR2/W10.16 read-site repair in `ChatCoordinator.runRustAgentPath`.

Changes:
- `Epistemos/App/ChatCoordinator.swift` — added `deriveConversationStateId` and `effectiveConversationHistory` helpers; wired stable `conversationStateId` into load, prompt compaction, system-prompt injection, save, and in-memory classifier state.
- `EpistemosTests/ConversationStateDispatchTests.swift` — 11 source-guard tests proving stable-key derivation, whitespace normalization, history compaction, stable-key load/save source wiring, and state-backed objective construction.

Failing verification (stubs):

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ConversationStateDispatchTests test
```

- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_22-50-17--0500.xcresult`
- Result: `** TEST FAILED **`
- Swift Testing result: `6` issues in `1` suite (expected — stubs returned per-run `sessionId` and un-compacted history).

Green verification (implementation):

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ConversationStateDispatchTests test
```

- Log: `/tmp/epistemos-w1016-conversation-state-dispatch-green-20260430.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_23-11-43--0500.xcresult`
- Exit code `0`.
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `11` tests passed in `1` suite.

Post-slice guardrails:

- Source audit log: `/tmp/epistemos-w1016-source-audit-20260430.log`
- Tracked-source diff check log: `/tmp/epistemos-w1016-diff-check-20260430.log`
- Touched-file whitespace audit log: `/tmp/epistemos-w1016-whitespace-audit-20260430.log`
- Protected diff audit log: `/tmp/epistemos-w1016-protected-diff-audit-20260430.log`
- Protected diff audit reports pre-existing dirty `graph-engine/**` files in the protected pattern; this slice did not edit them.
- `ChatCoordinator.swift` already contained unrelated dirty approval-modal queue wiring before this slice; this section claims only the W10.16 ConversationState read-site repair.
- No protected note editor files (`ProseEditor*`) changed.
- No protected graph renderer/controller files (`MetalGraphView`, `HologramController`) changed.
- No `graph-engine/**` Rust edits were made by this slice.
- No xcodeproj, entitlements, generated artifacts, branch, stash, staging, or commit edits.
- Kimi edited inside the approved lane; Codex then removed a production force unwrap, added whitespace normalization, replaced a hanging custom source loader with the repo source mirror helper, and reran verification.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.


## R9 Chat + BrainDump Indexed Entities

Slice: App Intents `IndexedEntity` scaffolding for chat threads and brain-dump quarantine entries.

Deliberation gate:
`docs/fusion/deliberation/r9_chat_brain_dump_indexed_entities_deliberation_2026_05_01.md`

Oversight record:
`docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_019_2026_05_01.md`

Changes:
- `Epistemos/Intents/Entities/ChatEntity.swift` - new `ChatEntity` AppEntity/IndexedEntity, bounded `ChatEntityQuery`, title/type/linked-page/message-preview matching, and `SDChat.toChatEntity(...)`.
- `Epistemos/Intents/Entities/BrainDumpEntity.swift` - new `BrainDumpEntity` AppEntity/IndexedEntity, bounded/recent-first `BrainDumpEntityQuery`, anchor-aware matching, and `QuarantineEntry.toBrainDumpEntity()`.
- `EpistemosTests/IndexedEntityTests.swift` - new focused Swift Testing suite covering entity properties, IndexedEntity attribute sets, conversion helpers, and bounded query result surfaces.

Verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/IndexedEntityTests test
```

- Log: `/tmp/epistemos-r9-indexed-entities-codex-green-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_00-32-03--0500.xcresult`
- Exit code `0`.
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `9` tests passed in `1` suite.

Post-slice guardrails:
- Tracked-source diff check log: `/tmp/epistemos-r9-diff-check-20260501.log`
- New-code/doc ASCII audit log: `/tmp/epistemos-r9-ascii-audit-20260501.log`
- Source anti-pattern audit log: `/tmp/epistemos-r9-source-anti-pattern-audit-20260501.log`
- No protected note editor files (`ProseEditor*`) changed.
- No protected graph renderer/controller files (`MetalGraphView`, `HologramController`) changed.
- No `graph-engine/**` Rust edits were made by this slice.
- No `project.yml`, `.xcodeproj`, entitlements, generated artifacts, branch, stash, staging, or commit edits.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; the R9 focused process exited `0`, and this remains existing package-plugin noise rather than an R9 failure.


## R12a FSRS GRDB Persistence

Slice: durable GRDB persistence for the existing Swift `FSRSDecayStore` contract.

Deliberation gate:
`docs/fusion/deliberation/r12a_fsrs_grdb_persistence_deliberation_2026_05_01.md`

Oversight record:
`docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_020_2026_05_01.md`

Changes:
- `Epistemos/Engine/FSRSDecayState.swift` - added `FSRSDecayDatabase`, idempotent `fsrs_state` migration, GRDB row mapping, explicit persistence configuration, mutation persistence, and reset deletion.
- `EpistemosTests/FSRSDecayStateTests.swift` - added focused GRDB tests for migration idempotency, persisted reload, review persistence, and reset deletion while preserving existing math/store coverage.

Verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/FSRSDecayStateTests test
```

- Log: `/tmp/epistemos-r12a-fsrs-grdb-green-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_00-49-58--0500.xcresult`
- Exit code `0`.
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `10` tests passed in `1` suite.

Post-slice guardrails:
- Tracked-source diff check log: `/tmp/epistemos-r12a-diff-check-20260501.log`
- Touched-file trailing whitespace audit log: `/tmp/epistemos-r12a-trailing-whitespace-audit-20260501.log`
- Source anti-pattern audit log: `/tmp/epistemos-r12a-source-anti-pattern-audit-20260501.log`
- Source line audit log: `/tmp/epistemos-r12a-source-audit-20260501.log`
- Protected diff audit log: `/tmp/epistemos-r12a-protected-diff-audit-20260501.log`
- No protected note editor files (`ProseEditor*`) changed.
- No protected graph renderer/controller files (`MetalGraphView`, `HologramController`) changed.
- No `graph-engine/**` Rust edits were made by this slice.
- No `epistemos-core/**`, `agent_core/**`, generated bindings, project files, entitlements, branch, stash, staging, or commit edits.
- App bootstrap DB wiring and the Rust `fsrs = "5.2.0"` algorithm bridge remain R12b scope.
- Kimi was not used for code edits in this round; Codex kept the schema-risk slice local and verified it directly.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; the R12a focused process exited `0`, and this remains existing package-plugin noise rather than an R12a failure.


## R12b FSRS Rust Bridge

Slice: Rust `fsrs = "5.2.0"` scheduler bridge in `epistemos-core`.

Deliberation gate:
`docs/fusion/deliberation/r12b_fsrs_rust_bridge_deliberation_2026_05_01.md`

Oversight record:
`docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_021_2026_05_01.md`

Changes:
- `epistemos-core/Cargo.toml` / `Cargo.lock` - added `fsrs = "5.2.0"` and resolved dependency graph.
- `epistemos-core/src/fsrs_decay.rs` - new stateless FSRS bridge with row/memory/outcome structs, validation, current retrievability, row-current retrievability, and review scheduling.
- `epistemos-core/src/lib.rs` - exported the new module and UniFFI-visible types.
- `epistemos-core/src/uniffi_exports.rs` - added free functions for the FSRS bridge.
- `epistemos-core/uniffi/epistemos_core.udl` - added dictionaries, error enum, and function declarations.

Verification:

```bash
cd epistemos-core && cargo test fsrs_decay --lib
```

- Log: `/tmp/epistemos-r12b-fsrs-rust-bridge-green-20260501.log`
- Result: `7` tests passed; `0` failed.

```bash
cd epistemos-core && cargo test --lib
```

- Log: `/tmp/epistemos-r12b-epistemos-core-lib-test-20260501.log`
- Result: `373` tests passed; `0` failed.

```bash
cd epistemos-core && cargo fmt -- --check
```

- Log: `/tmp/epistemos-r12b-cargo-fmt-check-20260501.log`
- Result: clean.

```bash
cd epistemos-core && cargo clippy --lib -- -D warnings
```

- Log: `/tmp/epistemos-r12b-cargo-clippy-20260501.log`
- Result: blocked by pre-existing unrelated warnings in `skill_engine`, `vault_analyzer`, and existing `ssm_save_state`; no `fsrs_decay` findings.

Post-slice guardrails:
- Tracked-source diff check log: `/tmp/epistemos-r12b-diff-check-20260501.log`
- Touched-file trailing whitespace audit log: `/tmp/epistemos-r12b-trailing-whitespace-audit-20260501.log`
- Source anti-pattern audit log: `/tmp/epistemos-r12b-source-anti-pattern-audit-20260501.log`
- Source line audit log: `/tmp/epistemos-r12b-source-audit-20260501.log`
- Protected diff audit log: `/tmp/epistemos-r12b-protected-diff-audit-20260501.log`
- Kimi read-only advisory log: `/tmp/epistemos-r12b-kimi-readonly-advisory-20260501.log`
- No protected note editor files (`ProseEditor*`) changed.
- No protected graph renderer/controller files (`MetalGraphView`, `HologramController`) changed.
- No `graph-engine/**` edits were made by this slice.
- No Swift app bootstrap, FSRS UI, project file, entitlement, generated binding, branch, stash, staging, or commit edits.
- Swift call-site wiring remains the next R12 follow-up.


## R12c FSRS Swift/Rust Scheduler Wiring

Slice: `FSRSDecayStore.recordReview` now consumes the Rust FSRS scheduler bridge.

Deliberation gate:
`docs/fusion/deliberation/r12c_fsrs_swift_rust_scheduler_wiring_deliberation_2026_05_01.md`

Oversight record:
`docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_022_2026_05_01.md`

Changes:
- `Epistemos/Engine/FSRSDecayState.swift` - conditionally imports `epistemos_coreFFI`, converts Swift FSRS rows to generated R12b bridge rows, calls `fsrsScheduleReview(...)`, and preserves the previous Swift placeholder update as fallback.
- `EpistemosTests/FSRSDecayStateTests.swift` - added focused coverage proving bridge-backed review updates memory stability away from the initial placeholder.

Verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/FSRSDecayStateTests test
```

- Log: `/tmp/epistemos-r12c-fsrs-swift-rust-wiring-green-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_01-11-14--0500.xcresult`
- Exit code `0`.
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `11` tests passed in `1` suite.

Post-slice guardrails:
- Tracked-source diff check log: `/tmp/epistemos-r12c-diff-check-20260501.log`
- Touched-file trailing whitespace audit log: `/tmp/epistemos-r12c-trailing-whitespace-audit-20260501.log`
- Source anti-pattern audit log: `/tmp/epistemos-r12c-source-anti-pattern-audit-20260501.log`
- Source line audit log: `/tmp/epistemos-r12c-source-audit-20260501.log`
- Protected diff audit log: `/tmp/epistemos-r12c-protected-diff-audit-20260501.log`
- No generated UniFFI bindings were checked in.
- No app bootstrap database wiring or FSRS UI changed.
- No protected note editor files (`ProseEditor*`) changed.
- No protected graph renderer/controller files (`MetalGraphView`, `HologramController`) changed.
- No `graph-engine/**` edits were made by this slice.
- No project file, entitlement, branch, stash, staging, or commit edits.


## R12d FSRS Rust Current-Retrievability Surfacing

Slice: `FSRSRetrievability.current(for:now:)` now prefers the Rust FSRS current-retrievability bridge when generated bindings are available, with the Swift approximation retained as fallback.

Deliberation gate:
`docs/fusion/deliberation/r12d_fsrs_rust_current_retrievability_deliberation_2026_05_01.md`

Oversight record:
`docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_024_2026_05_01.md`

Changes:
- `Epistemos/Engine/FSRSDecayState.swift` - added `FSRSRustSchedulerBridge.currentRetrievability(row:now:)`, routed `FSRSRetrievability.current` through the generated `fsrsRowCurrentRetrievability(...)` bridge when importable, and kept the Swift fallback for non-bridge builds or bridge errors.
- `EpistemosTests/FSRSDecayStateTests.swift` - added coverage proving the Rust FSRS-6 power curve is used when `epistemos_coreFFI` is importable, updated threshold fixtures for the slower Rust curve, and preserved fallback expectations.
- `docs/fusion/deliberation/r12d_fsrs_rust_current_retrievability_deliberation_2026_05_01.md` - recorded the gate and result.

Verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/FSRSDecayStateTests test
```

- Log: `/tmp/epistemos-r12d-fsrs-rust-current-green-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_01-46-07--0500.xcresult`
- Exit code `0`.
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `12` tests passed in `1` suite.

Post-slice guardrails:
- Tracked-source diff check log: `/tmp/epistemos-r12d-diff-check-20260501.log`
- Touched-file trailing whitespace audit log: `/tmp/epistemos-r12d-trailing-whitespace-audit-20260501.log`
- Source anti-pattern audit log: `/tmp/epistemos-r12d-source-anti-pattern-audit-20260501.log`
- Source line audit log: `/tmp/epistemos-r12d-source-audit-20260501.log`
- Protected diff audit log: `/tmp/epistemos-r12d-protected-diff-audit-20260501.log`
- Antigravity scratch audit log: `/tmp/epistemos-r12d-antigravity-scratch-audit-20260501.log`
- No generated UniFFI bindings were checked in.
- No app bootstrap database wiring or FSRS UI changed.
- No protected note editor files (`ProseEditor*`) changed.
- No protected graph renderer/controller files (`MetalGraphView`, `HologramController`) changed.
- No `graph-engine/**` edits were made by this slice.
- No project file, entitlement, branch, stash, staging, or commit edits.
- Xcode still reported SwiftLint command failures for `CodeEditTextView` and `CodeEditSourceEditor` after `** TEST SUCCEEDED **`; the focused process exited `0`, and this remains existing package-plugin noise rather than an R12d failure.
- `topAtRisk` still uses the existing Swift retrievability formula; Rust power-curve surfacing remains a separate behavior/audit slice.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; the R12c focused process exited `0`, and this remains existing package-plugin noise rather than an R12c failure.


## R13 sqlite-vec + petgraph Foundation

Slice: `epistemos-core` vector-search/graph foundation without Swift/GRDB runtime wiring.

Deliberation gate:
`docs/fusion/deliberation/r13_sqlite_vec_petgraph_foundation_deliberation_2026_05_01.md`

Oversight record:
`docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_023_2026_05_01.md`

Changes:
- `epistemos-core/Cargo.toml` / `Cargo.lock` - added `petgraph = "=0.8.2"`, `rusqlite = "0.32"`, and `sqlite-vec = "=0.1.9"`.
- `epistemos-core/src/vector_graph.rs` - new foundation module with validated vec0 schema rendering, best-effort sqlite-vec auto-extension registration, verified direct per-connection sqlite-vec loading for Rust-owned `rusqlite::Connection`s, and `StableDiGraph` projection.
- `epistemos-core/src/lib.rs` - exported the vector graph module and UniFFI-visible types.
- `epistemos-core/src/uniffi_exports.rs` - added free functions for sqlite-vec registration, vec0 schema rendering, and stable graph projection.
- `epistemos-core/uniffi/epistemos_core.udl` - added dictionaries, error enum, and R13 function declarations.

Important sqlite-vec finding:
- Local upstream `sqlite-vec` 0.1.9 auto-extension test failed with `no such function: vec_version`.
- Log: `/tmp/sqlite-vec-crate-rusqlite-auto-extension-20260501.log`
- R13 does not claim process-level auto-extension is reliable on this machine. The helper is guarded, and the proven path is direct per-connection initialization for Rust-owned `rusqlite::Connection`s.
- Swift/GRDB handle-level loading remains a later deliberated slice.

Verification:

```bash
cd epistemos-core && cargo test vector_graph --lib
```

- Log: `/tmp/epistemos-r13-vector-graph-foundation-green-20260501.log`
- Result: `5` tests passed; `0` failed.

```bash
cd epistemos-core && cargo test --lib
```

- Log: `/tmp/epistemos-r13-epistemos-core-lib-test-20260501.log`
- Result: `378` tests passed; `0` failed.

```bash
cd epistemos-core && cargo fmt -- --check
```

- Log: `/tmp/epistemos-r13-cargo-fmt-check-20260501.log`
- Result: clean.

```bash
cd epistemos-core && cargo clippy --lib -- -D warnings
```

- Log: `/tmp/epistemos-r13-cargo-clippy-20260501.log`
- Result: blocked by pre-existing unrelated lint backlog.
- R13-specific check: no `vector_graph` or `fsrs_decay` findings remain in the clippy log.

Post-slice guardrails:
- Diff check log: `/tmp/epistemos-r13-diff-check-20260501.log`
- Source anti-pattern audit log: `/tmp/epistemos-r13-source-anti-pattern-audit-20260501.log`
- Unsafe safety audit log: `/tmp/epistemos-r13-unsafe-safety-audit-20260501.log`
- Source line audit log: `/tmp/epistemos-r13-source-audit-20260501.log`
- Protected diff audit log: `/tmp/epistemos-r13-protected-diff-audit-20260501.log`
- Kimi read-only advisory log: `/tmp/epistemos-r13-kimi-sqlite-vec-advisory-20260501.log`
- No generated UniFFI bindings were checked in.
- No Swift/GRDB runtime wiring changed.
- No protected note editor files (`ProseEditor*`) changed.
- No protected graph renderer/controller files (`MetalGraphView`, `HologramController`) changed.
- No `graph-engine/**` edits were made by this slice; protected diff audit shows pre-existing graph-engine dirty files only.
- No project file, entitlement, branch, stash, staging, or commit edits.


## W9.30 KIVI KV Cache PR2

Slice: Real opt-in KIVI KV cache plumbing for the local MLX stack, without making KIVI default-on or claiming release-ready model quality.

Deliberation gate:
`docs/fusion/deliberation/w930_kivi_kv_cache_pr2_deliberation_2026_05_01.md`

Oversight record:
`docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_025_2026_05_01.md`

Changes:
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/Evaluate.swift` - added `KVQuantScheme` and `GenerateParameters.kvScheme`, defaulting to `.affine`.
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/LanguageModel.swift` - selects `KIVIKVCache` only when `.kivi` is requested and no rotating cache is active.
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift` - added `KIVIKVCache` with transposed grouped key quantization, grouped value quantization, full-precision residual windows, and prompt-cache save/load dispatch; fixed an app-runtime edge where exact residual-window flushes could serialize an empty residual key tensor; tightened the KIVI-only causal mask fill so masked future residual keys receive a negative sentinel logit instead of a near-zero score.
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/AttentionUtils.swift` - routes `KIVIKVCache` through its asymmetric attention path before the existing affine quantized path.
- `LocalPackages/mlx-swift-lm/Tests/MLXLMTests/KVCacheTests.swift` - added default-scheme and KIVI state/serialization coverage.
- `Epistemos/Engine/KIVIQuantization.swift` - kept KIVI opt-in via `EPISTEMOS_KV_KIVI=1` and made the preference helpers nonisolated for Swift 6 default actor isolation.
- `Epistemos/Engine/MLXInferenceService.swift` - switches to `.kivi`, 2-bit KV, 32-token groups, and no rotating cache only when the opt-in flag and context threshold are satisfied.
- `Epistemos/Views/Chat/ModelAboutSheet.swift` - surfaces the active local KV scheme.
- `EpistemosTests/KIVIKVCacheRuntimeTests.swift` - added app-bundled MLX runtime coverage for grouped/residual state, prompt-cache serialization, and causal masking over residual keys.

Kimi oversight:
- First Kimi read-only advisory hit the step limit: `/tmp/epistemos-w930-kimi-deliberation-20260501.log`.
- Second Kimi read-only advisory suggested an approximation without residual windows: `/tmp/epistemos-w930-kimi-feasibility-20260501.log`.
- Codex rejected the approximation and implemented the stricter paper/reference-aligned path from the deliberation gate.
- Antigravity scratch Cargo files remain outside the Epistemos repo under `/Users/jojo/.gemini/antigravity/scratch/rex/` and were not touched.

Verification:

```bash
swift build --package-path LocalPackages/mlx-swift-lm
```

- Log: `/tmp/epistemos-w930-kivi-mlx-build-final3-20260501.log`
- Result: build complete.

```bash
swift test --package-path LocalPackages/mlx-swift-lm --filter testGenerateParametersDefaultToAffineKVScheme
```

- Log: `/tmp/epistemos-w930-kivi-generateparams-after-runtime-fix-20260501.log`
- Result: `1` Swift Testing test passed.

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/KIVIKVCacheRuntimeTests test
```

- First app-harness runtime log: `/tmp/epistemos-w930-kivi-app-runtime-20260501.log`
- First app-harness result: failed because `save_safetensors` cannot serialize an empty residual key tensor (`0.6`); this exposed the exact residual-window flush bug fixed in `KIVIKVCache`.
- Final app-harness runtime log: `/tmp/epistemos-w930-kivi-app-runtime-final3-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_09-04-55--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `3` tests passed in `1` suite.
- Xcode still reported SwiftLint build-tool plugin failures for `CodeEditSourceEditor` and `CodeEditTextView` after the test success banner; lint itself found `0` violations, then failed on the existing package-plugin `Output` folder issue.

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ChatPresentationTests test
```

- Log: `/tmp/epistemos-w930-chatpresentation-3-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_02-16-51--0500.xcresult`
- Exit code `0`.
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `55` tests passed in `1` suite.

Known verification limits:
- SwiftPM package runtime KIVI tests remain blocked by local MLX resource loading: `Failed to load the default metallib`.
- Log: `/tmp/epistemos-w930-kivi-package-runtime-after-fix-2-20260501.log`
- The app-bundled Xcode harness now validates KIVI grouped/residual state, prompt-cache serialization, and causal masking with bundled MLX resources.
- KIVI remains explicit opt-in and not release-ready/default-on until deterministic attention tolerance coverage and a real Qwen-family perplexity/quality gate are completed.

Post-slice guardrails:
- Diff check log: `/tmp/epistemos-w930-diff-check-final3-20260501.log`
- Source audit log: `/tmp/epistemos-w930-source-audit-final3-20260501.log`
- Protected diff audit log: `/tmp/epistemos-w930-protected-diff-audit-final3-20260501.log`
- No protected note editor files (`ProseEditor*`) were edited by this slice.
- No protected graph view/controller files (`MetalGraphView`, `HologramController`) were edited by this slice.
- No `graph-engine/**` edits were made by this slice; protected diff audit still shows pre-existing dirty `graph-engine/**` work.
- No project file, entitlement, branch, stash, staging, commit, generated `.rlib`, DerivedData, or `.xcresult` edits were made.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this matches prior focused runs and did not block the test command exit code.


## W9.30 KIVI Attention Tolerance Follow-Up

Slice: deterministic app-harness coverage for the KIVI mixed grouped/residual attention path, without production routing changes, default-on behavior, or model-quality claims.

Deliberation gate:
`docs/fusion/deliberation/w930_kivi_attention_tolerance_deliberation_2026_05_01.md`

Oversight record:
`docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_026_2026_05_01.md`

Changes:
- `EpistemosTests/KIVIKVCacheRuntimeTests.swift` - added deterministic tensor helpers, an explicit full-precision attention reference, and a focused tolerance test after grouped KIVI flush.
- `docs/fusion/deliberation/w930_kivi_attention_tolerance_deliberation_2026_05_01.md` - recorded the tests-only gate, Kimi advisory, red/green results, and remaining limits.
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_026_2026_05_01.md` - recorded final oversight for the follow-up.

Kimi oversight:
- Kimi was used as read-only advisory only.
- Log: `/tmp/epistemos-w930-kivi-quality-kimi-advisory-20260501.log`
- Codex accepted the safe advice to use an explicit full-precision reference and supported MLX group sizes.
- Kimi did not edit files, run tools, stage, or commit.

Initial red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/KIVIKVCacheRuntimeTests test
```

- Log: `/tmp/epistemos-w930-kivi-attention-tolerance-20260501.log`
- Result: failed because MLX rejected quantization group size `4`; supported group sizes are `32`, `64`, and `128`.
- Fix: the deterministic fixture now uses group size `32` with a `32`-dimension head.

Final verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/KIVIKVCacheRuntimeTests test
```

- Log: `/tmp/epistemos-w930-kivi-attention-tolerance-final2-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_09-25-49--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `4` tests passed in `1` suite.
- Xcode still reported SwiftLint build-tool plugin failures for `CodeEditSourceEditor` and `CodeEditTextView` after the success banner; this matches prior focused runs and did not block the command exit code.

Known verification limits:
- This validates arithmetic tolerance on small deterministic tensors only.
- It does not validate Qwen-family perplexity or model-level quality.
- It does not justify enabling KIVI by default.
- SwiftPM package runtime KIVI tests remain blocked by local MLX `default.metallib` loading; the app-bundled Xcode harness remains the validated runtime path.

Post-slice guardrails:
- Diff check log: `/tmp/epistemos-w930-kivi-attention-diff-check-docfinal-20260501.log`
- Touched-file trailing whitespace audit log: `/tmp/epistemos-w930-kivi-attention-trailing-whitespace-docfinal-20260501.log`
- Source anti-pattern audit log: `/tmp/epistemos-w930-kivi-attention-source-antipattern-docfinal-20260501.log`
- Protected diff audit log: `/tmp/epistemos-w930-kivi-attention-protected-diff-docfinal-20260501.log`
- No protected note editor files (`ProseEditor*`) were edited by this slice.
- No protected graph view/controller files (`MetalGraphView`, `HologramController`) were edited by this slice.
- No `graph-engine/**` edits were made by this slice; protected diff audit still shows pre-existing dirty `graph-engine/**` work.
- No project file, entitlement, branch, stash, staging, commit, generated `.rlib`, DerivedData, or `.xcresult` edits were made.


## R16 ETL Apalis Queue PR2

Slice: Rust-only ETL queue/job runner foundation inside `agent_core/src/etl/`.
This does not claim the full R16 product feature, Swift AFM sidecar generation,
FFI exports, Background Indexing UI, MAS bookmark enforcement, xattr marking, or
WRV.

Deliberation gate:
`docs/fusion/deliberation/r16_etl_apalis_queue_pr2_deliberation_2026_05_01.md`

Oversight record:
`docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_027_2026_05_01.md`

Changes:
- `agent_core/Cargo.toml` - added exact pins for `apalis` and `apalis-sqlite`
  `1.0.0-rc.7`.
- `agent_core/Cargo.lock` - resolved the Apalis SQLite stack and existing dirty
  dependency state.
- `agent_core/src/etl/mod.rs` - registered queue/job modules and re-exports.
- `agent_core/src/etl/jobs.rs` - added typed serde ETL ingest jobs for markdown,
  PDF, and plain-text inputs.
- `agent_core/src/etl/queue.rs` - added SQLite queue opening, enqueue helpers,
  and a WorkerBuilder-backed worker runner.

Kimi oversight:
- Kimi was used read-only only.
- Kimi advisory attempts hit step limits without a useful final answer:
  `/tmp/epistemos-r16-pr2-kimi-advisory-20260501.log`.
- Kimi diff review log:
  `/tmp/epistemos-r16-pr2-kimi-diff-review-20260501.log`.
- Codex adjudicated Kimi's missing-file/test-gap findings as stale because the
  reviewed plain `git diff` omitted untracked `jobs.rs` and `queue.rs`.
- Kimi did not edit files, run repo tools, stage, or commit.

Initial red verification:

```bash
cargo test --manifest-path agent_core/Cargo.toml etl --lib
```

- Log: `/tmp/epistemos-r16-pr2-etl-cargo-test-20260501.log`
- Result: compile failed on a test helper lifetime (`E0597`).
- Fix: clone the drained jobs vector after releasing the mutex guard.

Behavioral red verification:

```bash
cargo test --manifest-path agent_core/Cargo.toml etl --lib
```

- Log: `/tmp/epistemos-r16-pr2-etl-cargo-test-final-20260501.log`
- Result: one test failed because it assumed insertion-order draining.
- Fix: compare drained jobs by stable fingerprint/path ordering.

Focused final verification:

```bash
cargo test --manifest-path agent_core/Cargo.toml etl --lib
```

- Log: `/tmp/epistemos-r16-pr2-etl-cargo-test-final2-20260501.log`
- Result: `13` ETL tests passed, `0` failed.

Full Rust verification:

```bash
cargo test --manifest-path agent_core/Cargo.toml
```

- Log: `/tmp/epistemos-r16-pr2-agent-core-cargo-test-20260501.log`
- Result: `780` lib tests, `7` bin tests, `6` integration tests, and doc-tests
  passed; `0` failures.

Dependency verification:
- `/tmp/epistemos-r16-pr2-cargo-tree-apalis-sqlite-20260501.log`
- `/tmp/epistemos-r16-pr2-cargo-tree-apalis-sql-20260501.log`
- `/tmp/epistemos-r16-pr2-cargo-tree-sqlx-postgres-20260501.log`
- `/tmp/epistemos-r16-pr2-cargo-tree-sqlx-mysql-20260501.log`

Post-slice guardrails:
- Cargo fmt check log:
  `/tmp/epistemos-r16-pr2-cargo-fmt-check-final-20260501.log`
- Diff check log:
  `/tmp/epistemos-r16-pr2-diff-check-final-20260501.log`
- New-source anti-pattern log:
  `/tmp/epistemos-r16-pr2-source-antipattern-final-20260501.log`
- New-file trailing whitespace log:
  `/tmp/epistemos-r16-pr2-trailing-whitespace-final-20260501.log`
- Protected diff name-only log:
  `/tmp/epistemos-r16-pr2-protected-diff-name-only-20260501.log`
- No protected note editor files (`ProseEditor*`) were edited by this slice.
- No protected graph view/controller files (`MetalGraphView`, `HologramController`) were edited by this slice.
- No `graph-engine/**` edits were made by this slice; the protected audit still
  lists pre-existing `graph-engine/**` dirty files.
- No Swift, FFI, UI, project file, entitlement, branch, stash, staging, commit,
  generated `.rlib`, DerivedData, or `.xcresult` edits were made.

## R16 PR3A - Background Indexing Visible Status - 2026-05-01

Scope:
- Make the existing shadow vault bootstrap crawl visible in Settings ->
  General -> Diagnostics.
- Record only the existing `ShadowVaultBootstrapper.progress` states:
  unavailable, scanning, indexing, complete, and failed.
- Do not claim AFM sidecar generation, Rust ETL FFI, xattr sidecar marking,
  security-scoped bookmark changes, or editor badges.

Files changed by this slice:
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Views/Settings/EditorBundleHealthRow.swift`
- `Epistemos/Views/Settings/SettingsView.swift`
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`
- `docs/fusion/deliberation/r16_background_indexing_visible_status_pr3a_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_028_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Deliberation gate:
- `docs/fusion/deliberation/r16_background_indexing_visible_status_pr3a_deliberation_2026_05_01.md`

Kimi oversight:
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_028_2026_05_01.md`
- Kimi was not invoked for edits because this was a small bounded slice and the
  user explicitly asked to move into building without overdoing process.

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test
```

- Log: `/tmp/epistemos-r16-pr3a-background-indexing-xcode-test-20260501.log`
- Result: `ShadowVaultBootstrapper (Wave 8.7)` ran `6` tests, `0` failures.
- Xcode printed known CodeEdit SwiftLint script noise after `** TEST SUCCEEDED **`;
  the command exited `0`.

Post-slice guardrails:
- Diff check log:
  `/tmp/epistemos-r16-pr3a-diff-check-20260501.log`
- Trailing whitespace log:
  `/tmp/epistemos-r16-pr3a-trailing-whitespace-20260501.log`
- Source anti-pattern log:
  `/tmp/epistemos-r16-pr3a-source-antipattern-20260501.log`
- Touched-file scope log:
  `/tmp/epistemos-r16-pr3a-touched-file-scope-20260501.log`
- Protected diff name-only log:
  `/tmp/epistemos-r16-pr3a-protected-diff-name-only-20260501.log`

Guardrail notes:
- No protected note editor files (`ProseEditor*`) were edited by this slice.
- No protected graph view/controller files (`MetalGraphView`, `HologramController`)
  were edited by this slice.
- The protected-path scan lists inherited dirty `graph-engine/**` files already
  present on the branch; PR3A did not edit them.
- No project file, entitlement, generated binding, staging, commit, stash,
  DerivedData, or `.xcresult` edits were made by this slice.

## R16 PR3A.1 - Background Indexing Page Refresh - 2026-05-01

Scope:
- Reuse the full vault crawl Shadow document id for targeted page-save updates.
- On `.vaultPageChanged(pageId:)`, enqueue the changed note into the existing
  `ShadowIndexingService` when a Shadow backend is already open.
- Keep this as a narrow bridge slice only: no FSEvents watcher, AFM sidecars,
  ETL FFI counters, xattr marking, security-scoped bookmark changes, or
  deletion reconciliation.

Files changed by this slice:
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Engine/ShadowVaultBootstrapper.swift`
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`
- `docs/fusion/deliberation/r16_background_indexing_page_refresh_pr3a1_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_029_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Deliberation gate:
- `docs/fusion/deliberation/r16_background_indexing_page_refresh_pr3a1_deliberation_2026_05_01.md`

Kimi oversight:
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_029_2026_05_01.md`
- Kimi was not invoked for edits because this was a small bounded follow-on
  slice and the user explicitly asked to keep building without overdoing
  process.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test
```

- Log: `/tmp/epistemos-r16-pr3a1-shadow-docid-red-xcode-test-20260501.log`
- Result: failed as expected because `ShadowVaultBootstrapper` did not yet
  expose `vaultRelativeDocId(for:vaultRoot:)`.

Focused final verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test
```

- Log: `/tmp/epistemos-r16-pr3a1-shadow-page-refresh-xcode-test-20260501.log`
- Result: `ShadowVaultBootstrapper (Wave 8.7)` ran `7` tests, `0` failures.
- Xcode printed known CodeEdit SwiftLint script noise after `** TEST SUCCEEDED **`;
  the command exited `0`.

Post-slice guardrails:
- Diff check log:
  `/tmp/epistemos-r16-pr3a1-diff-check-final-20260501.log`
- Trailing whitespace log:
  `/tmp/epistemos-r16-pr3a1-trailing-whitespace-final-20260501.log`
- Source anti-pattern log:
  `/tmp/epistemos-r16-pr3a1-source-antipattern-final-20260501.log`
- Protected diff name-only log:
  `/tmp/epistemos-r16-pr3a1-protected-diff-name-only-final-20260501.log`

Guardrail notes:
- No protected note editor files (`ProseEditor*`) were edited by this slice.
- No protected graph view/controller files (`MetalGraphView`, `HologramController`)
  were edited by this slice.
- The protected-path scan lists inherited dirty `graph-engine/**` files already
  present on the branch; PR3A.1 did not edit them.
- No project file, entitlement, generated binding, staging, commit, stash,
  DerivedData, or `.xcresult` edits were made by this slice.

## R16 PR3B.0 - ETL Queue Stats Counters - 2026-05-01

Scope:
- Add live counter snapshots to the existing `agent_core::etl::EtlQueue`
  Apalis SQLite queue foundation.
- Keep the slice Rust-only. No Swift UI, no FFI bridge, no generated bindings,
  no AFM sidecar generation, and no ShadowVaultBootstrapper ETL dispatch.

Files changed by this slice:
- `agent_core/src/etl/queue.rs`
- `agent_core/src/etl/mod.rs`
- `docs/fusion/deliberation/r16_etl_queue_stats_pr3b0_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_030_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Deliberation gate:
- `docs/fusion/deliberation/r16_etl_queue_stats_pr3b0_deliberation_2026_05_01.md`

Kimi oversight:
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_030_2026_05_01.md`
- Kimi was invoked through the terminal CLI but hit its max-step limit before
  producing a final implementation. Codex audited the partial state and made
  the bounded Rust patch directly.

Focused verification:

```bash
cargo test --manifest-path agent_core/Cargo.toml etl --lib
```

- Log: `/tmp/epistemos-r16-pr3b0-etl-stats-cargo-test-20260501.log`
- Result: `16` ETL tests passed, `0` failed.

Full Rust verification:

```bash
cargo test --manifest-path agent_core/Cargo.toml
```

- Log: `/tmp/epistemos-r16-pr3b0-agent-core-full-cargo-test-20260501.log`
- Result: `783` library tests, `7` bin tests, `6` integration tests, and
  doc-tests passed; `0` failures.

Post-slice guardrails:
- Cargo fmt check:
  `/tmp/epistemos-r16-pr3b0-cargo-fmt-check-20260501.log`
- Diff check:
  `/tmp/epistemos-r16-pr3b0-diff-check-20260501.log`
- Trailing whitespace:
  `/tmp/epistemos-r16-pr3b0-trailing-whitespace-20260501.log`
- Protected diff name-only log:
  `/tmp/epistemos-r16-pr3b0-protected-diff-name-only-final-20260501.log`

Guardrail notes:
- No Swift, Settings UI, FFI, project file, entitlement, generated binding,
  generated `.rlib`, DerivedData, `.xcresult`, staging, commit, stash, or branch
  operation was part of this slice.
- The protected-path scan lists inherited dirty `graph-engine/**` and
  `epistemos-shadow/**` files already present on the branch; PR3B.0 did not
  edit them.

## R16 PR3B.1 - ETL Stats C ABI Bridge - 2026-05-01

Scope:
- Expose the PR3B.0 ETL queue stats through a raw Rust C ABI JSON endpoint.
- Keep this Rust-only: no Swift UI, no generated UniFFI binding changes, no AFM
  sidecars, and no ShadowVaultBootstrapper ETL dispatch.
- Missing queue database paths report `available = false` and do not create a
  database solely for diagnostics.

Files changed by this slice:
- `agent_core/src/etl/ffi.rs`
- `agent_core/src/etl/queue.rs`
- `agent_core/src/etl/mod.rs`
- `docs/fusion/deliberation/r16_etl_stats_c_abi_pr3b1_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_031_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Deliberation gate:
- `docs/fusion/deliberation/r16_etl_stats_c_abi_pr3b1_deliberation_2026_05_01.md`

Kimi oversight:
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_031_2026_05_01.md`
- Kimi was not invoked for edits on this slice because the prior adjacent
  terminal-Kimi attempt hit its max-step limit without a usable final patch.

Focused verification:

```bash
cargo test --manifest-path agent_core/Cargo.toml etl --lib
```

- Log: `/tmp/epistemos-r16-pr3b1-etl-stats-cabi-cargo-test-final2-20260501.log`
- Result: `19` ETL tests passed, `0` failed.

Full Rust verification:

```bash
cargo test --manifest-path agent_core/Cargo.toml
```

- Log: `/tmp/epistemos-r16-pr3b1-agent-core-full-cargo-test-final-20260501.log`
- Result: `786` library tests, `7` bin tests, `6` integration tests, and
  doc-tests passed; `0` failures.

Post-slice guardrails:
- Cargo fmt check:
  `/tmp/epistemos-r16-pr3b1-cargo-fmt-check-final3-20260501.log`
- Diff check:
  `/tmp/epistemos-r16-pr3b1-diff-check-final3-20260501.log`
- Trailing whitespace:
  `/tmp/epistemos-r16-pr3b1-trailing-whitespace-final3-20260501.log`
- Protected diff name-only log:
  `/tmp/epistemos-r16-pr3b1-protected-diff-name-only-20260501.log`

Guardrail notes:
- No Swift, Settings UI, generated UniFFI binding, project file, entitlement,
  generated `.rlib`, DerivedData, `.xcresult`, staging, commit, stash, or branch
  operation was part of this slice.
- The protected-path scan lists inherited dirty `graph-engine/**` and
  `epistemos-shadow/**` files already present on the branch; PR3B.1 did not
  edit them.

## R16 PR3B.2 - Swift ETL Stats Diagnostics Reader - 2026-05-01

Scope:
- Add a Swift reader for the raw Rust `etl_queue_stats_json` /
  `etl_queue_free_string` C ABI endpoint.
- Record ETL queue counters in the existing background indexing diagnostic
  snapshot shown by Settings health rows.
- Refresh counters from `AppBootstrap` for
  `<vault>/.epcache/etl/queue.sqlite` without creating the queue database from
  Swift.
- No generated UniFFI binding changes, no AFM sidecars, no ETL dispatch, and no
  project file edits.

Files changed by this slice:
- `Epistemos/Engine/RustShadowFFIClient.swift`
- `Epistemos/Views/Settings/EditorBundleHealthRow.swift`
- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`
- `docs/fusion/deliberation/r16_etl_stats_swift_diagnostics_pr3b2_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_032_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Deliberation gate:
- `docs/fusion/deliberation/r16_etl_stats_swift_diagnostics_pr3b2_deliberation_2026_05_01.md`

Kimi oversight:
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_032_2026_05_01.md`
- Kimi was not invoked for edits on this slice because the prior adjacent
  terminal-Kimi attempt hit its max-step limit without a usable final patch.

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test
```

- Log: `/tmp/epistemos-r16-pr3b2-swift-diagnostics-xcode-test-20260501.log`
- Result: `8` tests in `ShadowVaultBootstrapperTests` passed, `0` failed.
- Note: the Xcode log reports `** TEST SUCCEEDED **` and exits successfully, but
  still prints inherited SwiftLint plugin failure lines for CodeEdit package
  targets after the selected suite pass.

Post-slice guardrails:
- Diff check:
  `/tmp/epistemos-r16-pr3b2-diff-check-20260501.log`
- Trailing whitespace:
  `/tmp/epistemos-r16-pr3b2-trailing-whitespace-20260501.log`
- Source anti-pattern scan:
  `/tmp/epistemos-r16-pr3b2-antipattern-scan-20260501.log`
- Protected diff name-only log:
  `/tmp/epistemos-r16-pr3b2-protected-diff-name-only-20260501.log`

Guardrail notes:
- No generated UniFFI binding, AFM sidecar, ETL dispatch, project file,
  entitlement, generated `.rlib`, DerivedData, `.xcresult`, staging, commit,
  stash, or branch operation was part of this slice.
- The protected-path scan lists inherited dirty `graph-engine/**` and
  `epistemos-shadow/**` files already present on the branch; PR3B.2 did not
  edit them.

## R16 PR3C - AFM Sidecar Generation - 2026-05-01

Scope:
- Add Swift-side AFM generated sidecar payload support for changed eligible
  notes.
- Reuse `AFMSessionPool`, `EpistemosSidecarStore`, and the existing ontology
  classifier instead of creating a parallel classification system.
- Persist generated summaries, retrieval tags, entities, and suggested links
  through optional sidecar fields with `com.epistemos.modelDerived = true`.
- Keep Rust ETL dispatch, battery/thermal pause UI, MAS bookmark enforcement,
  editor badge UI, generated bindings, and protected editor/graph paths out of
  scope.

Files changed by this slice:
- `Epistemos/Engine/EpistemosSidecar.swift`
- `Epistemos/Engine/AFMSidecarGenerator.swift`
- `Epistemos/Graph/EntityExtractor.swift`
- `EpistemosTests/AFMSidecarGeneratorTests.swift`
- `EpistemosTests/GraphBuilderComprehensiveTests.swift`
- `docs/fusion/deliberation/r16_afm_sidecar_generation_pr3c_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_033_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Deliberation gate:
- `docs/fusion/deliberation/r16_afm_sidecar_generation_pr3c_deliberation_2026_05_01.md`

Kimi oversight:
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_033_2026_05_01.md`
- Kimi advised using a narrow `AFMSidecarGenerator` with `AFMSessionPool` and
  `EpistemosSidecarStore`, avoiding duplicate ontology logic.
- Kimi cautioned against schema churn. Codex found no live strict Rust sidecar
  decoder in the current app path, so the PR3C fields are additive optional
  Swift-side fields. Any future Rust sidecar mirror or schema migration must
  explicitly handle `summary`, `tags`, `entities`, and `suggested_links`.

Focused generator verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/AFMSidecarGeneratorTests test
```

- Log: `/tmp/epistemos-r16-pr3c-afm-sidecar-generator-xcode-test-final3-20260501.log`
- Result: `3` tests in `AFM Sidecar Generator` passed, `0` failed.
- Xcode reported `** TEST SUCCEEDED **`.

Focused graph/entity verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/GraphBuilderNoteDerivedEntityTests test
```

- Log: `/tmp/epistemos-r16-pr3c-graph-note-derived-xcode-test-20260501.log`
- Result: `5` tests in `GraphBuilder - Note Derived Sources` passed, `0`
  failed.
- Xcode reported `** TEST SUCCEEDED **`.
- Note: the filename-level selector
  `-only-testing:EpistemosTests/GraphBuilderComprehensiveTests` returned
  `** TEST SUCCEEDED **` but executed `0` tests, so it was not counted as
  evidence.

Post-slice guardrails:
- Diff check:
  `/tmp/epistemos-r16-pr3c-diff-check-20260501.log`
- New-file diff checks:
  `/tmp/epistemos-r16-pr3c-new-afm-generator-diff-check-20260501.log`,
  `/tmp/epistemos-r16-pr3c-new-afm-tests-diff-check-20260501.log`,
  `/tmp/epistemos-r16-pr3c-new-oversight-diff-check-20260501.log`,
  `/tmp/epistemos-agent-workcards-diff-check-20260501.log`
- Trailing whitespace scan:
  `/tmp/epistemos-r16-pr3c-trailing-whitespace-20260501.log`
- Source anti-pattern scan:
  `/tmp/epistemos-r16-pr3c-antipattern-scan-20260501.log`
- Protected diff name-only log:
  `/tmp/epistemos-r16-pr3c-protected-diff-name-only-20260501.log`

Guardrail notes:
- `git diff --check` produced no output for the PR3C touched files and docs.
- `git diff --check --no-index` produced no output for the new Swift and doc
  files.
- The anti-pattern scan produced no output for the new generator/test files.
- The raw trailing whitespace scan reports pre-existing whitespace in
  `EpistemosTests/GraphBuilderComprehensiveTests.swift`; PR3C did not add a
  new diff-check whitespace failure.
- The protected-path scan lists inherited dirty `agent_core/**`,
  `epistemos-shadow/**`, and `graph-engine/**` paths already present on the
  branch; PR3C did not edit protected editor, graph renderer/controller, Rust
  ETL, `epistemos-shadow`, project, entitlement, generated binding, generated
  library, DerivedData, `.xcresult`, staging, commit, stash, or branch state.

Remaining R16 gaps:
- ShadowVaultBootstrapper ETL dispatch is not implemented by this slice.
- Battery/thermal/memory-pressure pause UI is not implemented by this slice.
- MAS bookmark enforcement is not implemented by this slice.
- Editor badge visibility for model-derived sidecars remains blocked behind a
  protected note-editor gate.

## R16 PR3D ShadowVaultBootstrapper ETL Dispatch Results

Gate status: **passed focused PR3D verification**.

Change:

- Added raw Rust C ABI `etl_enqueue_vault_walk_json(vault_path, queue_path)`.
- Reused existing ETL walker/job/queue code to enqueue supported vault files
  after Shadow bootstrap.
- Added Swift `RustEtlQueueDispatchClient` and dispatch snapshot decoding.
- Wired `AppBootstrap.initializeShadowBackendIfReady()` to call ETL dispatch
  after Shadow bootstrap and `flushNow()`, unless `PowerGate.shouldDefer()`
  pauses background work.
- Added paused Settings diagnostics for battery, thermal, and low-power
  deferral.
- Added an in-flight same-vault guard to avoid duplicate Shadow/ETL dispatch
  on rapid vault events.

Files changed by this slice:

- `agent_core/src/etl/ffi.rs`
- `Epistemos/Engine/RustShadowFFIClient.swift`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Views/Settings/EditorBundleHealthRow.swift`
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`
- `docs/fusion/deliberation/r16_bootstrapper_etl_dispatch_pr3d_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_034_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Deliberation gate:
- `docs/fusion/deliberation/r16_bootstrapper_etl_dispatch_pr3d_deliberation_2026_05_01.md`

Kimi oversight:
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_034_2026_05_01.md`
- Kimi found no PR3D gate violations.
- Kimi flagged a possible ETL parent-directory risk; Codex confirmed
  `EtlQueue::open_at` creates the parent directory and the enqueue test covers
  a missing `.epcache/etl` parent path.
- Kimi flagged a real rapid same-vault duplicate-dispatch risk; Codex added an
  in-flight same-vault guard and reran focused Swift verification.

Rust ETL verification:

```bash
cargo test --manifest-path agent_core/Cargo.toml etl --lib
```

- Log: `/tmp/epistemos-r16-pr3d-etl-cargo-test-20260501.log`
- Result: `20` tests passed, `0` failed.

Focused Swift verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test
```

- Final log:
  `/tmp/epistemos-r16-pr3d-shadow-bootstrapper-xcode-test-final-20260501.log`
- Result: `10` tests in `ShadowVaultBootstrapper (Wave 8.7)` passed, `0`
  failed.
- Xcode reported `** TEST SUCCEEDED **`.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor`
  and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains inherited
  plugin/lint noise and not a PR3D compile/test blocker.

Post-slice guardrails:
- Cargo fmt check:
  `/tmp/epistemos-r16-pr3d-cargo-fmt-check-final3-20260501.log`
- Diff check:
  `/tmp/epistemos-r16-pr3d-diff-check-final-20260501.log`
- Trailing whitespace scan:
  `/tmp/epistemos-r16-pr3d-trailing-whitespace-final-20260501.log`
- New Swift diff anti-pattern scan:
  `/tmp/epistemos-r16-pr3d-new-swift-antipattern-diff-scan-final-20260501.log`
- Rust anti-pattern scan:
  `/tmp/epistemos-r16-pr3d-rust-antipattern-scan-final-20260501.log`
- Protected diff name-only log:
  `/tmp/epistemos-r16-pr3d-protected-diff-name-only-final-20260501.log`

Guardrail notes:
- Cargo fmt, `git diff --check`, trailing whitespace, new Swift diff
  anti-pattern, and Rust anti-pattern scans produced no output for PR3D.
- The protected-path scan lists inherited dirty `graph-engine/**` and
  `epistemos-shadow/**` paths already present on the branch; PR3D did not edit
  protected note editor, graph renderer/controller, `graph-engine`,
  `epistemos-shadow`, project, entitlement, generated binding, generated
  library, DerivedData, `.xcresult`, staging, commit, stash, or branch state.
- Pre-existing untracked ETL foundation files under `agent_core/src/etl/`
  remain present; PR3D's FFI entrypoint builds on that existing foundation.

Remaining R16 gaps:
- ETL worker execution is not implemented by this slice.
- MAS bookmark enforcement is not implemented by this slice.
- Editor badge visibility for model-derived sidecars remains blocked behind a
  protected note-editor gate.

## R16 PR3E Memory Pressure Pause Results

Gate status: **passed focused PR3E verification**.

Change:

- Added canonical `PowerGate.DeferSnapshot` and `PowerGate.DeferReason` support
  for low-power, thermal, battery, and memory-pressure defer decisions.
- Wired `RuntimeIssueMonitor` memory-pressure enter/recovery transitions into
  `PowerGate` using the app's existing `DispatchSourceMemoryPressure` listener.
- Replaced AppBootstrap's local pause-reason duplication with canonical
  `PowerGate` snapshot mapping for Shadow/ETL dispatch.
- Proved Background Indexing diagnostics can display
  `Paused - memory pressure`.
- Preserved the existing low-power, thermal, and low-battery ordering.

Files changed by this slice:

- `Epistemos/State/PowerGate.swift`
- `Epistemos/App/EpistemosApp.swift`
- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/ResourceExhaustionTests.swift`
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`
- `docs/fusion/deliberation/r16_memory_pressure_pause_pr3e_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_052_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`

Deliberation gate:

- `docs/fusion/deliberation/r16_memory_pressure_pause_pr3e_deliberation_2026_05_01.md`

Kimi oversight:

- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_052_2026_05_01.md`
- Kimi found no blocking findings and agreed the PR3E gate is satisfied.
- Kimi's non-blocking concerns were recorded: single-reason precedence can mask
  memory pressure in combined states, and monitor stop clears the pressure flag
  as lifecycle cleanup.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ResourceMemoryPressureTrackingTests -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test
```

- Log:
  `/tmp/epistemos-r16-memory-pressure-pr3e-red-xcode-20260501.log`
- Expected failure before implementation: missing `PowerGate.deferSnapshot`,
  `PowerGate.recordMemoryPressureActive`, `PowerGate.isMemoryPressureActive`,
  and `RuntimeIssueMonitor.publishPowerGateMemoryPressure`.

Focused Swift verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ResourceMemoryPressureTrackingTests -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test
```

- Log:
  `/tmp/epistemos-r16-memory-pressure-pr3e-green-xcode-20260501.log`
- Summary:
  `/tmp/epistemos-r16-memory-pressure-pr3e-green-summary-20260501.log`
- Result: `17` tests across `2` Swift Testing suites passed.
- Xcode reported `** TEST SUCCEEDED **` and exited `0`.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains package-plugin/lint noise and not a PR3E blocker.

Guardrail notes:

- `git diff --check` passed for approved PR3E files and `docs/fusion`.
- Memory-source scan found the only `DispatchSourceMemoryPressure` and
  `DispatchSource.makeMemoryPressureSource` entries in
  `Epistemos/App/EpistemosApp.swift`; PR3E did not add a second source.
- Protected-path scan still lists inherited dirty `graph-engine/**` and
  `epistemos-shadow/**` paths already present on the branch; PR3E did not edit
  protected note editor, graph renderer/controller, `graph-engine`,
  `epistemos-shadow`, `agent_core`, project, entitlement, generated binding,
  generated library, DerivedData, `.xcresult`, staging, commit, stash, or branch
  state.

Remaining R16 gaps:

- ETL worker execution is not implemented by this slice.
- MAS bookmark enforcement is not implemented by this slice.
- Editor badge visibility for model-derived sidecars remains blocked behind a
  protected note-editor gate.

## AgentEvent Live Tool Provenance PR2 Results

Gate status: **closed**.

Change:

- Added a best-effort `AgentToolProvenanceRecorder` for typed
  `AgentProvenanceEvent` lifecycle rows.
- Instrumented `PipelineService.observedToolExecutor(...)` so observed local
  tool execution persists requested, approved/denied, started, and
  completed/failed events.
- Preserved existing approval, execution, result JSON, UI event, streaming, and
  routing semantics.
- Left ChatCoordinator Rust stream loops, Omega, hooks, GraphEvent, OpLog
  AgentEvent projection, Halo, Theater, and ReplayBundle untouched for future
  gates.

Files changed by this slice:

- `Epistemos/Engine/AgentToolProvenanceRecorder.swift`
- `Epistemos/Engine/PipelineService.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `EpistemosTests/PipelineServiceTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`
- `docs/fusion/deliberation/agent_event_live_tool_provenance_pr2_deliberation_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_047_2026_05_01.md`

Deliberation gate:
- `docs/fusion/deliberation/agent_event_live_tool_provenance_pr2_deliberation_2026_05_01.md`

Kimi oversight:
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_047_2026_05_01.md`
- Kimi recommended the PipelineService observed-tool chokepoint over
  ChatCoordinator/Rust-stream instrumentation for PR2 because it is narrow,
  reachable, and testable with the existing EventStore.

Raw logs:
- Red:
  `/tmp/epistemos-agent-event-pr2-red-20260501.log`
- Kimi advisory:
  `/tmp/epistemos-agent-event-pr2-kimi-advisory-20260501.log`
- Final green:
  `/tmp/epistemos-agent-event-pr2-combined-green-20260501-r3.log`

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests -only-testing:EpistemosTests/PipelineServiceTests -only-testing:EpistemosTests/RuntimeValidationTests test
```

- Result: `304` tests in `3` suites passed.
- Xcode reported `** TEST SUCCEEDED **`.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains package-plugin/lint noise and not a PR2 failure.

Guardrail notes:
- `git diff --check` passed on the PR2 allowed files and `docs/fusion`.
- Whitespace/CRLF audit passed on PR2 code and test files.
- Runtime code forbidden-symbol scan found only an existing PipelineService
  doc-comment mention of `ChatCoordinator`; no PR2 runtime dependency was
  introduced on OpLog, GraphEvent, ReplayBundle, hooks, editor/graph protected
  files, or generated bindings.
- Broad diff scans still report earlier approved OpLog projection/replay work
  already present on the dirty branch; that work was not changed by PR2.

Remaining AgentEvent gaps:
- Omega/hook/broader agent runtime lifecycle events remain unwired.
- AgentEvents are not projected into OpLog, GraphEvent, Halo, Theater, or
  ReplayBundle.
- Trace id remains nil at the PipelineService PR2 boundary until a canonical
  trace id is exposed there.

## AgentEvent Rust Stream PR3 Results

Gate status: **closed**.

Change:

- Instrumented both `ChatCoordinator` Rust `AgentStreamEvent` consumers:
  Command Center and managed chat.
- Persisted best-effort `AgentProvenanceEvent` tool lifecycle rows for exposed
  `.permissionRequired`, `.toolStarted`, and `.toolCompleted` stream events.
- Preserved existing approval decisions, delegate resolution, chat UI state,
  diagnostics, verified-vault-read enforcement, message persistence, tool result
  JSON, routing, Rust bindings, OpLog, GraphEvent, Omega, hooks, and generated
  files.

Files changed by this slice:

- `Epistemos/App/ChatCoordinator.swift`
- `EpistemosTests/RuntimeValidationTests.swift`
- `docs/fusion/deliberation/agent_event_rust_stream_pr3_deliberation_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_048_2026_05_01.md`

Deliberation gate:
- `docs/fusion/deliberation/agent_event_rust_stream_pr3_deliberation_2026_05_01.md`

Raw logs:
- Initial misplaced red attempt:
  `/tmp/epistemos-agent-event-pr3-red-20260501.log`
- Valid red:
  `/tmp/epistemos-agent-event-pr3-red-20260501-r2.log`
- Green:
  `/tmp/epistemos-agent-event-pr3-green-20260501-r1.log`
- Kimi audit attempt:
  `/tmp/epistemos-agent-event-pr3-kimi-audit-20260501-r1.log` produced no
  output after several minutes and was terminated.

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/RuntimeValidationTests test
```

- Result: `253` tests in `1` suite passed.
- Xcode reported `** TEST SUCCEEDED **`.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains package-plugin/lint noise and not a PR3 failure.

Guardrail notes:
- `git diff --check` passed on the PR3 allowed files and `docs/fusion`.
- Runtime forbidden-symbol scan on `ChatCoordinator.swift` found no OpLog,
  GraphEvent, ReplayBundle, or hook dependency introduced by PR3.
- The broad protected-path name-only scan still reports earlier dirty branch
  edits under PipelineService, Omega, Views, `agent_core`, `graph-engine`, and
  `epistemos-shadow`; PR3 did not edit those protected surfaces.

Remaining AgentEvent gaps:
- Omega/hook/broader agent runtime lifecycle events remain unwired.
- AgentEvents are not projected into OpLog, GraphEvent, Halo, Theater, or
  ReplayBundle.
- Trace id remains nil at the PipelineService PR2 and ChatCoordinator PR3
  boundaries until canonical trace ids are exposed there.

## EventStore OpLog Projection Dead-Letter PR3B Results

Gate status: **passed focused red/green verification**.

Deliberation gate:
`docs/fusion/deliberation/eventstore_oplog_projection_dead_letter_pr3b_deliberation_2026_05_01.md`

Change:

- Added nullable `dead_lettered_at` and `dead_letter_reason` metadata to
  `mutation_projection_outbox`.
- Excluded dead-lettered rows from pending and claim APIs.
- Extended owner-scoped failure recording with an optional max-attempt threshold
  that dead-letters poison rows instead of retrying forever.
- Kept `last_error` bounded to 512 characters.
- Cleared dead-letter metadata on explicit projection mark/repair.
- Wired `MutationOpLogProjector` to pass a bounded default max-attempt value
  when recording failures.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
```

- Log: `/tmp/epistemos-oplog-dead-letter-pr3b-red-20260501.log`
- Exit code: `65`.
- Expected failures: missing `maxAttempts`, `deadLetteredAt`, and
  `deadLetterReason`.

Focused green verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
```

- Log: `/tmp/epistemos-oplog-dead-letter-pr3b-green-20260501.log`
- Final rerun log after projector max-attempt range tightening:
  `/tmp/epistemos-oplog-dead-letter-pr3b-green-2-20260501.log`
- Exit code: `0`.
- Result: `** TEST SUCCEEDED **`
- Swift Testing result:
  - `14` tests passed
  - `1` suite passed

Post-slice guardrails:

- `git diff --check` passed for the approved files and docs.
- Scheduler grep found only the existing EventStore serial queue and queue-key
  guard; no worker, timer, detached task, UI, AgentEvent, GraphEvent, replay,
  or rollback feature was added.
- Protected-path diff scan still reports preexisting dirty graph/shadow/oplog
  files on the branch; this PR3B slice did not edit those paths.
- Kimi read-only audit produced no output and was terminated:
  `/tmp/epistemos-oplog-dead-letter-pr3b-kimi-advisory-20260501.log`.
  Before/after status diff was empty, so Kimi did not edit files.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains plugin/lint noise and not a PR3B blocker.

Remaining provenance gaps:

- Background projection worker scheduling is still open.
- Replay/rollback semantics are still open.
- `AgentEvent`/tool provenance and `GraphEvent` durable mutation mapping are
  still open.
- Inspector/audit visibility for dead-lettered projection rows is still open.

## EventStore OpLog Projection Lease/Retry PR3A Results

Gate status: **passed focused verification**.

Deliberation gate:
`docs/fusion/deliberation/eventstore_oplog_projection_lease_retry_pr3a_deliberation_2026_05_01.md`

Change:

- Extended `mutation_projection_outbox` with deterministic lease/retry state:
  `lease_owner`, `lease_until`, `attempt_count`, and bounded `last_error`.
- Added claim and failure APIs so workers can claim only unprojected,
  unleased, or expired rows and retry failures after a deadline.
- Updated `MutationOpLogProjector` to claim rows before projection and record a
  retryable failure before rethrowing projection errors.
- Hardened projection marking with an owner guard so stale lease owners cannot
  clear a newer worker's active claim.
- Kept this slice free of background worker scheduling, timers, UI integration,
  AgentEvent, GraphEvent, replay/rollback, Rust ABI changes, generated binding
  changes, protected editor work, and protected graph work.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/CognitiveSubstrateTests test
```

- Log: `/tmp/epistemos-oplog-lease-retry-pr3a-red-20260501.log`
- Exit code: `65`.
- Expected failure: missing lease/retry outbox APIs and row metadata.

Owner-guard red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
```

- Log: `/tmp/epistemos-oplog-lease-retry-pr3a-owner-red-20260501.log`
- Exit code: `65`.
- Expected failure: missing owner-scoped projection mark API.

Focused green verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
```

- Log: `/tmp/epistemos-oplog-lease-retry-pr3a-green-20260501.log`
- Result: `13` tests in `EventStore Cognitive Tables` passed, `0` failed.
- Xcode reported `** TEST SUCCEEDED **` and exited `0`.

Kimi oversight:

- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_041_2026_05_01.md`
- Read-only advisory log:
  `/tmp/epistemos-oplog-lease-retry-pr3a-kimi-advisory-20260501.log`
- Kimi found no P0/P1 blockers and approved PR3A to close.

Guardrail notes:

- `git diff --check` passed for approved files and `docs/fusion`.
- Scheduler grep found no new `Timer`, `Task.detached`, or `Task {`; only the
  preexisting `EventStore` serial `DispatchQueue` and queue-key check matched.
- Protected-path diff scan continued to show inherited dirty `agent_core`,
  `graph-engine/**`, and `epistemos-shadow/**` files from outside this gate;
  this slice did not edit them.
- `build-rust` had no tracked status after Xcode build scripts ran.
- Kimi before/after status diff was empty; Kimi made no file changes.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains plugin/lint noise and not an EventStore test failure.

Remaining provenance gaps:

- Background projection worker scheduling is not implemented by this slice.
- Max-attempt/dead-letter handling remains a future worker hardening gate.
- Configurable lease/retry durations remain a future bootstrap/config gate.
- Replay/rollback, AgentEvent/tool provenance, GraphEvent mapping, and
  audit/inspector visibility remain separate gates.

## OpLog Swift Bridge PR1 Results

Gate status: **passed foundation slice**.

Change:

- Extended Rust OpLog C ABI with append-payload-JSON and chain-tip-hex
  functions.
- Added `RustOpLogFFIClient` as the only Swift owner of raw OpLog symbols.
- Added Swift bridge tests for open, append, chain-tip read, reopen, append
  continuation, and tail iteration.
- Added boundary tests proving raw OpLog symbols remain explicit and absent
  from production call sites outside the bridge.
- Added a Rust hardening test proving legacy wire `Op` JSON without
  `prev_hash` defaults to the genesis hash.
- Documented Swift `actorID` reopen behavior.

Files changed by this slice:

- `agent_core/src/oplog.rs`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/oplog_swift_bridge_pr1_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_037_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`

Deliberation gate:

- `docs/fusion/deliberation/oplog_swift_bridge_pr1_deliberation_2026_05_01.md`

Kimi oversight:

- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_037_2026_05_01.md`
- Final Kimi fallback log:
  `/tmp/epistemos-oplog-swift-bridge-pr1-kimi-advisory-fallback-20260501.log`
- Kimi found no P0/P1 blockers.

Focused Rust verification:

```bash
cargo test --manifest-path agent_core/Cargo.toml oplog --lib
```

- Log:
  `/tmp/epistemos-oplog-swift-bridge-pr1-cargo-test-final-20260501.log`
- Result: `16` OpLog tests passed, `0` failed.

Focused Swift verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/OpLogSwiftBridgeTests -only-testing:EpistemosTests/OpLogFFIBoundaryGuardTests test
```

- Log:
  `/tmp/epistemos-oplog-swift-bridge-pr1-final2-xcode-20260501.log`
- Result: `3` tests in `2` suites passed, `0` failed.
- Xcode reported `** TEST SUCCEEDED **`.

Guardrail notes:

- `cargo fmt --manifest-path agent_core/Cargo.toml --check` passed.
- `git diff --check -- agent_core/src/oplog.rs Epistemos/Engine/RustOpLogFFIClient.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion` passed.
- Production-call-site grep found no raw OpLog symbols outside
  `Epistemos/Engine/RustOpLogFFIClient.swift`.
- No protected note editor, graph renderer/controller, `graph-engine/**`,
  `epistemos-shadow/**`, project, entitlement, generated-binding, stash,
  staging, commit, or branch operation was performed by this slice.
- Existing dirty `graph-engine/**` paths remain inherited worktree state and
  were not edited by this slice.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains plugin/lint noise and not an OpLog test failure.

Remaining provenance gaps:

- At PR1 closeout, no production EventStore or MutationEnvelope call site wrote
  to OpLog yet; PR2 below supersedes this gap with a narrow projection
  foundation.
- At this PR1 closeout point, AgentEvent/tool provenance and GraphEvent
  durable mutation mapping still remained separate gates; later sections close
  their durable foundation slices.
- No UI or inspector surface depends on this bridge yet.

## EventStore To OpLog Projection PR2 Results

Gate status: **passed foundation slice**.

Change:

- Added Rust `oplog_iter_all_json` and Swift
  `RustOpLogFFIClient.iterateAll()` so duplicate detection can include seq `0`.
- Extended `mutation_projection_outbox` with nullable `oplog_seq` and
  `projected_at` metadata.
- Added `EventStore.markMutationProjectionOutboxProjected(...)`.
- Added `MutationOpLogProjector`, a narrow production-safe projector that reads
  pending committed `MutationEnvelope` outbox rows, appends missing projection
  payloads to OpLog, and marks rows with the assigned sequence.
- Added recovery behavior for append-before-mark retry: if a matching
  `mutation_projection` payload already exists in OpLog, the row is marked
  without appending a duplicate.

Files changed by this slice:

- `agent_core/src/oplog.rs`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- `Epistemos/Engine/MutationOpLogProjector.swift`
- `Epistemos/State/EventStore.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/eventstore_oplog_projection_pr2_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_038_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`

Deliberation gate:

- `docs/fusion/deliberation/eventstore_oplog_projection_pr2_deliberation_2026_05_01.md`

Kimi oversight:

- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_038_2026_05_01.md`
- Final Kimi advisory log:
  `/tmp/epistemos-eventstore-oplog-projection-kimi-final-advisory-20260501.log`
- Kimi found no P0/P1 blockers.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
```

- Log:
  `/tmp/epistemos-eventstore-oplog-projection-red-20260501.log`
- Expected failure before implementation included missing
  `MutationOpLogProjector`, missing `opLogSeq` / `projectedAt` fields, and
  missing `RustOpLogFFIClient.iterateAll()`.

Focused Rust verification:

```bash
cargo test --manifest-path agent_core/Cargo.toml oplog --lib
```

- Log:
  `/tmp/epistemos-eventstore-oplog-projection-cargo-test-post-kimi-20260501.log`
- Result: `16` OpLog tests passed, `0` failed.

Focused Swift EventStore verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test
```

- Log:
  `/tmp/epistemos-eventstore-oplog-projection-green-suite-post-kimi-20260501.log`
- Result: `11` tests in `EventStore Cognitive Tables` passed, `0` failed.
- Xcode reported `** TEST SUCCEEDED **`.

Focused Swift bridge/boundary verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/OpLogSwiftBridgeTests -only-testing:EpistemosTests/OpLogFFIBoundaryGuardTests test
```

- Log:
  `/tmp/epistemos-eventstore-oplog-projection-bridge-boundary-post-kimi-20260501.log`
- Result: `3` tests in `2` suites passed, `0` failed.
- Xcode reported `** TEST SUCCEEDED **`.

Guardrail notes:

- `cargo fmt --manifest-path agent_core/Cargo.toml --check` passed.
- `git diff --check -- agent_core/src/oplog.rs Epistemos/Engine/RustOpLogFFIClient.swift Epistemos/Engine/MutationOpLogProjector.swift Epistemos/State/EventStore.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion` passed.
- Production-call-site grep found no raw OpLog symbols outside
  `Epistemos/Engine/RustOpLogFFIClient.swift`.
- The protected-path scan lists inherited dirty `graph-engine/**` paths already
  present on the branch; this slice did not edit protected note editor files,
  graph renderer/controller files, `graph-engine/**`, `epistemos-shadow/**`,
  project files, entitlement files, generated bindings/libraries, stash,
  staging, commit, or branch state.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains plugin/lint noise and not an OpLog projection test failure.

Remaining provenance gaps:

- No background worker, lease, retry scheduler, launch bootstrap, or UI/inspector
  surface depends on OpLog projection yet.
- OpLog replay/rollback semantics remain a separate gate.
- At this PR2 closeout point, AgentEvent/tool provenance and GraphEvent
  durable mutation mapping still remained separate gates; later sections close
  their durable foundation slices.

## R15 Benchmark Harness JSON Results PR1 - 2026-05-01

Gate status: **passed foundation slice**.

Change:

- Added `BenchmarkRunRecorder`, a test-only JSON result writer for manual
  benchmark suites.
- Added `BenchmarkHarnessSourceGuardTests` to prove the JSON schema, percentile
  calculations, sorted sample output, timestamp determinism, metadata round
  trip, and empty/non-finite sample rejection.
- Updated the existing disabled manual benchmark suites to call the recorder
  without turning placeholder bodies into authoritative baselines.

Files changed by this slice:

- `EpistemosTests/Benchmarks/BenchmarkRunRecorder.swift`
- `EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`
- `EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift`
- `EpistemosTests/Benchmarks/AFMGenerableBenchTests.swift`
- `EpistemosTests/Benchmarks/MLXThermalBenchTests.swift`
- `EpistemosTests/Benchmarks/SQLiteVecKNNBenchTests.swift`
- `EpistemosTests/Benchmarks/UniFFICallbackThroughputTests.swift`
- `docs/fusion/deliberation/r15_benchmark_harness_json_results_pr1_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_039_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`

Deliberation gate:

- `docs/fusion/deliberation/r15_benchmark_harness_json_results_pr1_deliberation_2026_05_01.md`

Kimi oversight:

- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_039_2026_05_01.md`
- Final Kimi advisory log:
  `/tmp/epistemos-r15-benchmark-json-kimi-advisory-20260501.log`
- Kimi found no P0/P1 blockers and agreed this PR1 foundation can close while
  real benchmark baselines remain open.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test
```

- Log: `/tmp/epistemos-r15-benchmark-json-red-20260501.log`
- Expected failure before implementation: missing
  `EpistemosTests/Benchmarks/BenchmarkRunRecorder.swift`.

Focused Swift verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test
```

- Log: `/tmp/epistemos-r15-benchmark-json-green-20260501.log`
- Result: `2` tests in `R15 Benchmark Harness Source Guards` passed, `0`
  failed.
- Xcode reported `** TEST SUCCEEDED **`.

Source audit:

```bash
for path in EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift EpistemosTests/Benchmarks/AFMGenerableBenchTests.swift EpistemosTests/Benchmarks/MLXThermalBenchTests.swift EpistemosTests/Benchmarks/SQLiteVecKNNBenchTests.swift EpistemosTests/Benchmarks/UniFFICallbackThroughputTests.swift; do
  /usr/bin/grep -q "BenchmarkRunRecorder.record(" "$path"
  /usr/bin/grep -q ".disabled(" "$path"
done
```

- Log: `/tmp/epistemos-r15-benchmark-json-source-audit-20260501.log`
- Result: all five manual benchmark suites remain disabled and call
  `BenchmarkRunRecorder.record(...)`.

Guardrail notes:

- `git diff --check -- EpistemosTests/Benchmarks EpistemosTests/BenchmarkHarnessSourceGuardTests.swift docs/fusion` passed.
- `/usr/bin/grep -n "result of 'try?' is unused" /tmp/epistemos-r15-benchmark-json-green-20260501.log` returned no matches after warning cleanup.
- Kimi before/after status comparison was empty; Kimi made no file changes.
- The protected-path scan still lists inherited dirty `graph-engine/**` paths
  already present on the branch. This R15 slice did not edit graph-engine,
  graph renderer/controller files, protected note editor files, production FFI,
  generated bindings/libraries, project files, entitlement files, stash,
  staging, commit, or branch state.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains plugin/lint noise and not a benchmark-recorder test failure.

Remaining R15 gaps:

- Real graph/FFI, AFM, MLX thermal, sqlite-vec KNN, and Rust callback baselines
  remain separate gates.
- Placeholder sleep/proxy benchmark bodies are scaffolding only.
- Kimi P2 follow-ups for PR2: replace `try?` with `try` once suites become real
  authoritative baselines, add a CI/scheme-controlled results directory when
  needed, and promote suites individually as their fixture gates land.

## Halo V0 Shadow Backend Route PR1 - 2026-05-01

Gate status: **passed V0 backend-route slice**.

Change:

- Kept the existing production-mounted Contextual Shadows V0 state, button, and
  panel as the shipped recall surface.
- Added an injectable `ShadowSearchServicing` route to
  `ContextualShadowsState`, preferring the configured per-vault Shadow backend
  when ready and preserving `InstantRecallService` fallback.
- Added source provenance to `RecallHit` and rendered it in the V0 panel and
  accessibility label.
- Configured `ShadowSearchService` from `AppBootstrap` only after the active
  vault Shadow backend is successfully opened and indexed.
- Hardened vault-switch behavior so stale Shadow backend init and stale page
  reindex tasks cannot install search state or write final progress for the
  wrong vault.

Files changed by this slice:

- `Epistemos/State/ContextualShadowsState.swift`
- `Epistemos/Views/Recall/ContextualShadowsPanel.swift`
- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/ContextualShadowsStateTests.swift`
- `docs/fusion/deliberation/halo_v0_shadow_backend_route_pr1_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_040_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`

Deliberation gate:

- `docs/fusion/deliberation/halo_v0_shadow_backend_route_pr1_deliberation_2026_05_01.md`

Kimi oversight:

- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_040_2026_05_01.md`
- Initial advisory:
  `/tmp/epistemos-halo-v0-shadow-route-kimi-advisory-20260501.log`
- Delta advisory:
  `/tmp/epistemos-halo-v0-shadow-route-kimi-delta-advisory-20260501.log`
- Final advisory:
  `/tmp/epistemos-halo-v0-shadow-route-kimi-final-advisory-20260501.log`
- Kimi found no P0/P1 blockers and approved closing PR1. Its stale-vault and
  stale-page-reindex concerns were addressed before final approval.

Red verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ContextualShadowsStateTests test
```

- Log: `/tmp/epistemos-halo-v0-shadow-route-red-20260501.log`
- Expected failure before implementation: missing source provenance,
  Shadow-backend route, and AppBootstrap stale-vault guards.

Focused Swift verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ContextualShadowsStateTests test
```

- Log: `/tmp/epistemos-halo-v0-shadow-route-green-20260501.log`
- Result: `17` tests in `ContextualShadowsState` passed, `0` failed.
- Xcode reported `** TEST SUCCEEDED **`.

Source audit and guardrails:

```bash
git diff --check -- Epistemos/State/ContextualShadowsState.swift Epistemos/Views/Recall/ContextualShadowsPanel.swift Epistemos/App/AppBootstrap.swift EpistemosTests/ContextualShadowsStateTests.swift docs/fusion
/usr/bin/grep -n "loadBody()" Epistemos/State/ContextualShadowsState.swift Epistemos/Views/Recall/ContextualShadowsPanel.swift Epistemos/App/AppBootstrap.swift
/usr/bin/grep -n "HaloController" Epistemos/State/ContextualShadowsState.swift
```

- `git diff --check` passed.
- `loadBody()` grep returned no matches in the touched route path.
- `HaloController` grep returned no matches in `ContextualShadowsState.swift`,
  proving the V0 state did not silently mount the V1 controller.
- Kimi before/after status comparison was empty; Kimi made no file changes.

Guardrail notes:

- Protected-path scan still lists inherited dirty `graph-engine/**` paths
  already present on the branch. This Halo route slice did not edit
  graph-engine, protected editor files, protected graph view/controller files,
  production FFI replacement code, generated bindings/libraries, project files,
  entitlement files, stash, staging, commit, or branch state.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains plugin/lint noise and not a Contextual Shadows test failure.

Remaining Halo gaps:

- Full V1 Halo editor mounting remains a separate protected-path gate.
- Manual runtime verification remains required before any product-ready recall
  claim.
- Future P2 instrumentation can measure Shadow versus InstantRecall hit-rate
  split when the V0 flag goes wide.

## Quick Capture Typed Artifact Current-State Results

Gate status: **Card 4 closes as already-current**.

Change:

- Created a current-state closeout for the Quick Capture typed artifact slice.
- Confirmed the sheet, audio, and App Intent paths already route through
  `TextCapturePipeline`.
- Confirmed user-visible success/opening requires both a persisted note id and
  durable `MutationEnvelope` persistence.
- Confirmed `TextCapturePipeline` creates a committed prose-note
  `MutationEnvelope`, persists it through `EventStore.saveMutationEnvelope`, and
  records trace/outbox evidence.
- Confirmed no Quick Capture donor worktree raw merge is needed for the minimal
  typed-artifact vertical slice.

Files changed by this closeout:

- `docs/fusion/deliberation/quick_capture_typed_artifact_current_state_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_036_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Key code evidence:

- `Epistemos/Views/Capture/QuickCaptureView.swift:500-511` routes sheet text
  capture through `pipeline.run(...)` and guards on persisted note plus durable
  mutation envelope before success.
- `Epistemos/Views/Capture/QuickCaptureView.swift:532-540` routes audio capture
  through `pipeline.runFromAudio(...)` and applies the same guards.
- `Epistemos/Intents/Custom/NoteActionIntents.swift:38-48` routes shortcut
  capture through `bootstrap.textCapturePipeline.run(...)` and guards before
  opening the note.
- `Epistemos/Engine/TextCapturePipeline.swift:335-362` creates, saves, and
  traces the mutation envelope.
- `Epistemos/State/EventStore.swift:1391-1445` writes the mutation projection
  outbox row with trace/artifact/integrity metadata.

Deliberation gate:

- `docs/fusion/deliberation/quick_capture_typed_artifact_current_state_deliberation_2026_05_01.md`

Kimi oversight:

- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_036_2026_05_01.md`
- Kimi read-only advisory log:
  `/tmp/epistemos-quick-capture-typed-artifact-kimi-advisory-20260501.log`
- Kimi resume id: `7ce7fd42-0d78-469f-91bb-1c1006cce956`
- Kimi independently agreed that Card 4's minimal criteria are already met.

Focused Quick Capture verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests test
```

- Log:
  `/tmp/epistemos-quick-capture-typed-artifact-text-capture-tests-20260501.log`
- Result: `41` tests in `1` suite passed.
- Xcode reported `** TEST SUCCEEDED **`.

Focused mutation envelope parity verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/MutationEnvelopeParityTests test
```

- Log:
  `/tmp/epistemos-quick-capture-typed-artifact-mutation-envelope-parity-tests-20260501.log`
- Result: `13` tests in `1` suite passed.
- Xcode reported `** TEST SUCCEEDED **`.

Guardrail notes:

- This closeout changed docs only.
- No protected note editor files, graph renderer/controller files,
  `graph-engine/**`, generated artifacts, project files, entitlements, branch
  state, stash state, staging, or commits were changed.
- Inherited dirty `graph-engine/**` paths remain present on the branch; this
  closeout did not edit them.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains plugin/lint noise and not a Quick Capture blocker.

Remaining gaps:

- Manual runtime verification of the sheet and shortcut remains deferred by the
  user for this phase.
- Rust OpLog chain verification has since closed as PR4B; incremental replay,
  ReplayBundle export, and mutating repair/rollback remain separate provenance
  hardening slices.
- Donor Quick Capture ideas such as universal undo, route capture, and heal
  loops remain future candidates behind separate gates.

## R16 Sidecar Schema Mirror Audit Results

Gate status: **passed docs-only mirror audit**.

Change:

- Created a docs-only Card 2 gate for the sidecar schema mirror audit.
- Confirmed no active Rust reader or writer mirrors the Swift note sidecar
  contract at `<note-stem>.epistemos.json`.
- Confirmed unrelated Rust sidecar surfaces are not note sidecar mirrors:
  `.epcode.json` code sidecars, raw-thought sidecars, vector/index sidecars,
  and retrieval-index aliases.
- Confirmed no stale Rust `deny_unknown_fields` decoder was present.
- Recorded future-contract requirements for any later Rust note sidecar mirror.

Files changed by this slice:

- `docs/fusion/deliberation/r16_sidecar_schema_mirror_audit_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_035_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Deliberation gate:
- `docs/fusion/deliberation/r16_sidecar_schema_mirror_audit_deliberation_2026_05_01.md`

Kimi oversight:
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_035_2026_05_01.md`
- Kimi independently found no active Rust note-sidecar mirror, no stale strict
  decoder, and recommended closing Card 2 as docs-only without inventing a
  Rust mirror.

Search/audit logs:
- Broad mirror audit:
  `/tmp/epistemos-r16-sidecar-mirror-rg-audit-20260501.log`
- Rust targeted audit:
  `/tmp/epistemos-r16-sidecar-mirror-rust-targeted-audit-20260501.log`
- Swift targeted audit:
  `/tmp/epistemos-r16-sidecar-mirror-swift-targeted-audit-20260501.log`
- Kimi advisory:
  `/tmp/epistemos-r16-sidecar-mirror-kimi-advisory-20260501.log`

Focused Swift sidecar verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EpistemosSidecarTests test
```

- Log:
  `/tmp/epistemos-r16-sidecar-mirror-swift-sidecar-tests-20260501.log`
- Result: `16` tests in `EpistemosSidecar (Phase 12)` passed, `0` failed.
- Xcode reported `** TEST SUCCEEDED **`.

Focused AFM sidecar verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/AFMSidecarGeneratorTests test
```

- Log:
  `/tmp/epistemos-r16-sidecar-mirror-afm-sidecar-tests-20260501.log`
- Result: `3` tests in `AFM Sidecar Generator` passed, `0` failed.
- Xcode reported `** TEST SUCCEEDED **`.

Guardrail notes:
- This slice changed docs only.
- The Card 2 stop trigger was honored: no Rust note sidecar mirror was created.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains plugin/lint noise and not a sidecar-contract test failure.

Remaining R16 gaps:
- ETL worker execution is not implemented by this slice.
- Memory-pressure-specific pause is now closed by R16 PR3E.
- MAS bookmark enforcement is not implemented by this slice.
- Editor badge visibility for model-derived sidecars remains blocked behind a
  protected note-editor gate.

## OpLog Chain Verification PR4B Results

Gate status: **passed and closed**.

Change:

- Added read-only Rust `OpLogChainVerificationReport` and
  `OpLog::verify_chain(...)` to validate contiguous sequence numbers,
  persisted `prev_hash` continuity from genesis, recomputed/stored chain-tip
  parity, and optional expected-tip anchoring.
- Added bounded raw ABI `oplog_verify_chain_json`, returning JSON through the
  existing `oplog_free_string` contract.
- Added Swift `OpLogChainVerificationReport` plus
  `RustOpLogFFIClient.verifyChain(expectedTipHex:)`; raw symbols remain private
  to `RustOpLogFFIClient`.
- Added red-first Rust and Swift coverage for valid verification, persisted
  tamper detection, expected-tip mismatch, Swift bridge decoding, and raw ABI
  ownership.

Files changed by this slice:

- `agent_core/src/oplog.rs`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/oplog_chain_verification_pr4b_deliberation_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_050_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Deliberation gate:

- `docs/fusion/deliberation/oplog_chain_verification_pr4b_deliberation_2026_05_01.md`

Focused Rust verification:

```bash
cargo test --manifest-path agent_core/Cargo.toml oplog --lib
```

- Red log:
  `/tmp/epistemos-oplog-chain-verify-pr4b-red-cargo-20260501.log`
- Green log:
  `/tmp/epistemos-oplog-chain-verify-pr4b-green-cargo-20260501-r1.log`
- Result: `19` focused OpLog tests passed, `0` failed.

Focused Swift verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/OpLogSwiftBridgeTests -only-testing:EpistemosTests/OpLogFFIBoundaryGuardTests test
```

- Red log:
  `/tmp/epistemos-oplog-chain-verify-pr4b-red-xcode-20260501.log`
- Green log:
  `/tmp/epistemos-oplog-chain-verify-pr4b-green-xcode-20260501-r1.log`
- Result: `8` focused Swift tests passed across `OpLogFFIBoundaryGuardTests`
  and `OpLogSwiftBridgeTests`.
- Xcode reported `** TEST SUCCEEDED **`.

Guardrails:

- `cargo fmt --manifest-path agent_core/Cargo.toml --check` passed.
- `git diff --check -- agent_core/src/oplog.rs Epistemos/Engine/RustOpLogFFIClient.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion`
  passed.
- Raw OpLog symbol grep outside `RustOpLogFFIClient.swift` returned no Swift
  production matches.
- `nm -gU build-rust/libagent_core.dylib | rg 'oplog_verify_chain_json'`
  confirmed `_oplog_verify_chain_json` is exported.
- Protected-path name-only scan still reports inherited dirty
  `graph-engine/**` and `epistemos-shadow/**` paths from the broader branch;
  this slice did not edit those paths.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains plugin/lint noise and not an OpLog verification blocker.

Kimi oversight:

- Kimi was not invoked for PR4B because recent read-only Kimi audits for PR3B,
  AgentEvent PR3, and GraphEvent PR1 produced no output and were terminated.
  PR4B closes on Codex red/green tests, source audit, symbol export evidence,
  and guardrails.

Remaining gaps:

- PR4B is read-only verification only. It does not add repair, rollback
  execution, ReplayBundle export, incremental replay, Settings UI controls, or
  live graph/retrieval/audit projections.

## R15 Real Fixture Baselines PR2 Results

Gate status: **passed and closed**.

Change:

- Added a test-only `BenchmarkFixtureBaselineRunner` for three real local work
  surfaces: Swift graph payload construction, markdown parser FFI, and
  code-token parser FFI.
- Added focused Swift Testing coverage that decodes the reports through
  `BenchmarkRunReport`, checks finite samples and fixture metadata, and rejects
  invalid iteration counts.
- Extended the benchmark source guard so the fixture baseline runner must stay
  enabled, non-sleep-based, and marked as `fixture_pr2_real`.
- Wrote deterministic PR2 JSON reports through `BenchmarkRunRecorder` under
  `benchmarks/results/`.

Files changed by this slice:

- `EpistemosTests/Benchmarks/BenchmarkFixtureBaselines.swift`
- `EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`
- `benchmarks/results/2026-05-01t00-00-00-000z-r15-fixture-baselines-graph_payload_construction_750_nodes.json`
- `benchmarks/results/2026-05-01t00-00-00-000z-r15-fixture-baselines-markdown_parser_160_sections.json`
- `benchmarks/results/2026-05-01t00-00-00-000z-r15-fixture-baselines-code_token_parser_1200_lines.json`
- `docs/fusion/deliberation/r15_real_fixture_baselines_pr2_deliberation_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_051_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Deliberation gate:

- `docs/fusion/deliberation/r15_real_fixture_baselines_pr2_deliberation_2026_05_01.md`

Focused Swift verification:

```bash
EPISTEMOS_BENCHMARK_RESULTS_DIR=/Users/jojo/Downloads/Epistemos/benchmarks/results xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/BenchmarkFixtureBaselineTests -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test
```

- Red logs:
  `/tmp/epistemos-r15-real-fixture-pr2-red-xcode-20260501.log`
  and `/tmp/epistemos-r15-real-fixture-pr2-red-xcode-20260501-r2.log`
- Green logs:
  `/tmp/epistemos-r15-real-fixture-pr2-green-xcode-20260501-r2.log`
  and `/tmp/epistemos-r15-real-fixture-pr2-green-xcode-20260501-r3.log`
- Result: `5` focused tests passed across `BenchmarkFixtureBaselineTests` and
  `BenchmarkHarnessSourceGuardTests`.
- Xcode reported `** TEST SUCCEEDED **`.

Baseline report summary:

- `graph_payload_construction_750_nodes`: `750` nodes, `749` edges,
  `7` samples, p50 `0.002015417` seconds.
- `markdown_parser_160_sections`: `20,522` payload bytes, `160` sections,
  `7` samples, p50 `0.001964417` seconds.
- `code_token_parser_1200_lines`: `33,892` payload bytes, `1,200` lines,
  `7` samples, p50 `0.015254584` seconds.

Guardrails:

- `git diff --check -- EpistemosTests/Benchmarks/BenchmarkFixtureBaselines.swift EpistemosTests/BenchmarkHarnessSourceGuardTests.swift benchmarks/results docs/fusion`
  passed.
- `rg -n "Task\\.sleep|placeholder|Manual benchmark" EpistemosTests/Benchmarks/BenchmarkFixtureBaselines.swift`
  returned no matches.
- `rg -n "[ \\t]+$" EpistemosTests/Benchmarks/BenchmarkFixtureBaselines.swift EpistemosTests/BenchmarkHarnessSourceGuardTests.swift benchmarks/results docs/fusion/deliberation/r15_real_fixture_baselines_pr2_deliberation_2026_05_01.md`
  returned no matches.
- Protected-path name-only scan still reports inherited dirty
  `graph-engine/**` and `epistemos-shadow/**` paths from the broader branch;
  this slice did not edit those paths.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains plugin/lint noise and not an R15 PR2 test failure.

Remaining R15 gaps:

- MLX thermal fixture baselines.
- sqlite-vec 100k KNN fixture baselines.
- Full graph FFI fixture baselines.
- Editor shell fixture baselines.
- UniFFI callback throughput fixture baselines.
- Any production optimization remains blocked behind a new fixture gate.

## R16 MAS Bookmark Enforcement PR3F Results

Gate status: **passed and closed**.

Change:

- Added a MAS/sandbox vault-access policy in `VaultSyncService` that requires
  security-scoped bookmarks for the App Store/sandbox build.
- Preserved direct-distribution behavior: plain bookmark fallback remains
  allowed when the sandbox policy is not active.
- Rejected plain bookmark fallback under MAS policy, blocked automatic restore
  for plain resolved bookmarks under MAS policy, and added a shared watch-start
  policy that refuses unscoped starts when sandbox security scope is required.
- Added focused Swift Testing coverage for strict MAS policy plus existing
  direct fallback behavior.

Files changed by this slice:

- `Epistemos/Sync/VaultSyncService.swift`
- `EpistemosTests/VaultSyncServiceAuditTests.swift`
- `docs/fusion/deliberation/r16_mas_bookmark_enforcement_pr3f_deliberation_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_053_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Deliberation gate:

- `docs/fusion/deliberation/r16_mas_bookmark_enforcement_pr3f_deliberation_2026_05_01.md`

Focused Swift verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/VaultSyncServiceAuditTests test
```

- Red summary:
  `/tmp/epistemos-r16-mas-bookmark-pr3f-red-summary-20260501.log`
- Green log:
  `/tmp/epistemos-r16-mas-bookmark-pr3f-green-xcode-20260501-r2.log`
- Green summary:
  `/tmp/epistemos-r16-mas-bookmark-pr3f-green-summary-20260501.log`
- Result: `44` focused tests passed in `VaultSyncService Audit`.
- Xcode reported `** TEST SUCCEEDED **`.

Guardrails:

- `git diff --check -- Epistemos/Sync/VaultSyncService.swift EpistemosTests/VaultSyncServiceAuditTests.swift docs/fusion/deliberation/r16_mas_bookmark_enforcement_pr3f_deliberation_2026_05_01.md`
  passed.
- Diff policy grep found the intended bookmark/security-scope policy symbols
  and no `run_worker` or `etl_` additions.
- Targeted protected-path name-only scan found no protected editor, graph,
  `graph-engine/**`, `epistemos-shadow/**`, project, entitlement, or plist
  paths in this slice.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains plugin/lint noise and not an R16 PR3F test failure.

Remaining R16 gaps:

- ETL worker execution remains open. Do not implement a no-op queue drain.
- Model-derived sidecar badge visibility is closed later by R16 PR3G below.
- Full R16 WRV remains open until worker execution is reachable.

## R16 PR3G Model-Derived Sidecar Badge Results

Deliberation gate:

- `docs/fusion/deliberation/r16_model_derived_badge_pr3g_deliberation_2026_05_01.md`

Code/test changes:

- Added `EpistemosSidecarStore.isModelDerived(for:)`, a fail-closed read-only
  detector for the existing `com.epistemos.modelDerived = true` xattr on the
  canonical `.epistemos.json` sidecar.
- Added cached note-workspace footer state in `NoteDetailWorkspaceView` so
  Markdown notes with model-derived sidecars show a small `Model-derived` badge
  while editing without calling xattr/file I/O from SwiftUI body recomputation.
- Added focused sidecar tests for positive model-derived xattr detection and
  fail-closed missing/ineligible sidecars.
- Added a source guard proving the note workspace contains the badge copy and
  cached refresh path.

Focused Swift verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EpistemosSidecarTests -only-testing:EpistemosTests/ModelVaultBrowserTests test
```

- Red log:
  `/tmp/epistemos-r16-model-derived-badge-pr3g-red-xcode-20260501.log`
- Red summary:
  `/tmp/epistemos-r16-model-derived-badge-pr3g-red-summary-20260501.log`
- Green log:
  `/tmp/epistemos-r16-model-derived-badge-pr3g-green-xcode-20260501.log`
- Green summary:
  `/tmp/epistemos-r16-model-derived-badge-pr3g-green-summary-20260501.log`
- Result: `40` focused tests passed in `2` suites:
  `EpistemosSidecar (Phase 12)` and `Model Vault Browser`.
- Xcode reported `** TEST SUCCEEDED **`.

Guardrails:

- `git diff --check -- Epistemos/Engine/EpistemosSidecar.swift Epistemos/Views/Notes/NoteDetailWorkspaceView.swift EpistemosTests/EpistemosSidecarTests.swift EpistemosTests/ModelVaultBrowserTests.swift docs/fusion/deliberation/r16_model_derived_badge_pr3g_deliberation_2026_05_01.md`
  passed.
- Targeted protected editor/graph path scan found no `ProseEditor*.swift`,
  `MetalGraphView.swift`, or `HologramController.swift` edits in this slice.
- No Rust, generated binding, entitlement, project, plist, staging, commit, or
  branch operation was performed for PR3G.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains plugin/lint noise and not an R16 PR3G test failure.

Remaining R16 gaps:

- ETL worker execution remains open. Do not implement a no-op queue drain.
- Full R16 WRV remains open until worker execution has a real completion
  contract and focused verification.
